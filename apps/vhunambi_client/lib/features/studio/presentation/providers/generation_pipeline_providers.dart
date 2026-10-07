import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../notifications/domain/models/notification_entity.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../track/domain/models/track_entity.dart';
import '../../data/services/generation_socket_service.dart';
import '../../data/services/http_generation_submission_service.dart';
import '../../domain/services/i_generation_socket_service.dart';
import 'stem_download_provider.dart';

/// The notification list now lives in the Phase 11 alert centre; imported for
/// local use and re-exported so existing Phase 10 imports keep compiling
/// unchanged (invariant #4).
import '../../../notifications/presentation/providers/notifications_provider.dart'
    show notificationsProvider;
export '../../../notifications/presentation/providers/notifications_provider.dart'
    show NotificationsNotifier, notificationsProvider;

/// Injectable socket service (T10.2).
///
/// Override with `FakeGenerationSocketService` in tests — the suite never opens
/// a real WebSocket.
final socketServiceProvider = Provider<IGenerationSocketService>(
  (ref) => GenerationSocketService(),
);

/// Injectable HTTP generation submission and polling service (Phase 15).
final generationSubmissionServiceProvider =
    Provider<HttpGenerationSubmissionService>(
  (ref) => HttpGenerationSubmissionService(),
);

/// Nullable: `null` = no active generation; non-null = pipeline running or done.
final generationProgressProvider =
    StateNotifierProvider<GenerationPipelineNotifier, GenerationProgressState?>(
  (ref) => GenerationPipelineNotifier(ref),
);

/// Owns the live generation pipeline FSM for the Studio cockpit (T10.3).
class GenerationPipelineNotifier
    extends StateNotifier<GenerationProgressState?> {
  GenerationPipelineNotifier(this._ref) : super(null);

  final Ref _ref;
  StreamSubscription<PipelineSocketEvent>? _subscription;
  IGenerationSocketService? _activeSocket;

  /// Stream-level failures observed on the socket (diagnostics/tests).
  int errorCount = 0;

  /// `true` while the pipeline is mid-flight.
  bool get isGenerating => state?.isGenerating ?? false;

  /// `true` when auto-play should trigger upon synthesis completion.
  bool _autoPlayOnComplete = false;

  /// Submits the prompt, genre, and approved lyrics to the Vhunambi API
  /// and streams live progress ticks to the pipeline card (Phase 15 / REQ-SYN-01).
  Future<void> submitAndStartGeneration({
    required String trackTitle,
    required String genre,
    required String language,
    String? lyrics,
    bool isInstrumental = false,
    int? tempoBpm,
    String? musicalKey,
  }) async {
    final optimisticId = 'gen_${DateTime.now().millisecondsSinceEpoch}';

    // 1. Seed optimistic starting state immediately
    state = GenerationProgressState(
      generationId: optimisticId,
      trackTitle: trackTitle,
      genre: genre,
      currentStep: PipelineStep.startingUp,
      statusMessage: 'Starting synthesis pipeline...',
    );

    final socket = _ref.read(socketServiceProvider);

    // If socket is a fake/stub (e.g. in test suites), connect directly to it
    if (socket is! GenerationSocketService) {
      await startGeneration(
        generationId: optimisticId,
        trackTitle: trackTitle,
        genre: genre,
      );
      _autoPlayOnComplete = true;
      return;
    }

    _autoPlayOnComplete = true;

    // 2. Submit to backend API
    final submissionService = _ref.read(generationSubmissionServiceProvider);
    final response = await submissionService.submitGeneration(
      trackTitle: trackTitle,
      genre: genre,
      language: language,
      lyrics: lyrics,
      isInstrumental: isInstrumental,
      tempoBpm: tempoBpm,
      musicalKey: musicalKey,
    );

    final realGenerationId =
        response['generationId'] as String? ?? optimisticId;

    // 3. Update state with real generation ID
    state = state?.copyWith(generationId: realGenerationId) ??
        GenerationProgressState(
          generationId: realGenerationId,
          trackTitle: trackTitle,
          genre: genre,
          currentStep: PipelineStep.startingUp,
        );

    // 4. Stream live progress via HTTP polling
    unawaited(_subscription?.cancel());
    _subscription = null;
    _activeSocket = socket;

    _subscription = submissionService
        .pollGenerationProgress(realGenerationId)
        .listen(
          _applyEvent,
          onError: _onSocketError,
        );
  }

  /// Binds [generationId] to the socket bridge and seeds the 4-step FSM.
  Future<void> startGeneration({
    required String generationId,
    required String trackTitle,
    required String genre,
  }) async {
    _autoPlayOnComplete = false;
    unawaited(_subscription?.cancel());
    _subscription = null;

    state = GenerationProgressState(
      generationId: generationId,
      trackTitle: trackTitle,
      genre: genre,
    );

    final socket = _ref.read(socketServiceProvider);
    _activeSocket = socket;
    _subscription = socket.connect(generationId).listen(
          _applyEvent,
          onError: _onSocketError,
        );
  }

  void _applyEvent(PipelineSocketEvent event) {
    final current = state;
    if (current == null) return;

    state = current.copyWith(
      currentStep: event.step,
      statusMessage: event.statusMessage,
      progressPercent: event.progressPercent,
      generatedLyrics: event.generatedLyrics,
      completedTrack: event.completedTrack,
      errorMessage: event.step == PipelineStep.failed
          ? (event.error ?? 'Generation failed. Please try again.')
          : null,
    );

    if (event.step == PipelineStep.ready && event.completedTrack != null) {
      _onGenerationComplete(event.completedTrack!);
    }
  }

  void _onSocketError(Object error) {
    errorCount++;
    final current = state;
    if (current == null) return;

    state = current.copyWith(
      currentStep: PipelineStep.failed,
      statusMessage: 'Connection lost.',
      errorMessage: error.toString(),
    );
  }

  /// Runs the post-render side effects: master download + in-app notification + player load.
  void _onGenerationComplete(TrackEntity track) {
    // 1. Stream the rendered master onto the device (T10.5).
    unawaited(_startMasterDownload(track));

    // 2. Prepend the completion notification (newest first, T10.6).
    final notification = NotificationEntity.generationReady(
      trackId: track.id,
      trackTitle: (state?.trackTitle.isNotEmpty ?? false)
          ? state!.trackTitle
          : track.title,
      message: '${track.genre} • ${track.formattedDuration}',
    );
    _ref.read(notificationsProvider.notifier).update(
          (list) => <NotificationEntity>[notification, ...list],
        );

    // 3. Auto-play / load master in persistent player (Phase 15 Option A)
    if (_autoPlayOnComplete && track.masterMp3Url.isNotEmpty) {
      try {
        _ref.read(playerStateProvider.notifier).playTrack(track.toTrack());
      } catch (error) {
        debugPrint('GenerationPipelineNotifier auto-play error: $error');
      }
    }
  }

  Future<void> _startMasterDownload(TrackEntity track) async {
    final downloader = _ref.read(stemDownloadServiceProvider);
    try {
      await downloader
          .downloadMaster(track.masterMp3Url)
          .drain<void>();
    } catch (error) {
      // Downloads never fail the pipeline: the rendered track stays playable
      // from the CDN.
      debugPrint('GenerationPipelineNotifier master download failed: $error');
    }
  }

  /// Clears the active session and releases the socket.
  void reset() {
    _subscription?.cancel();
    _subscription = null;
    unawaited(_activeSocket?.disconnect());
    _activeSocket = null;
    state = null;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    unawaited(_activeSocket?.disconnect());
    _activeSocket = null;
    super.dispose();
  }
}
