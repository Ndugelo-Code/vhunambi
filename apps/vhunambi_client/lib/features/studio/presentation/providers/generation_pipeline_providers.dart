import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';

import '../../../content_studio/domain/models/master_media_object.dart';
import '../../../content_studio/presentation/providers/master_media_object_provider.dart';
import '../../../creator_dna/domain/models/behavior_event.dart';
import '../../../creator_dna/presentation/providers/creator_dna_provider.dart';
import '../../../library/domain/models/library_models.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../../notifications/domain/models/notification_entity.dart';
import '../../../player/domain/models/stem_mixer_state.dart';
import '../../../player/presentation/providers/multi_stem_audio_provider.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../player/presentation/providers/stem_mixer_provider.dart';
import '../../../track/domain/models/track_entity.dart';
import '../../data/services/generation_socket_service.dart';
import '../../data/services/http_generation_submission_service.dart';
import '../../domain/models/studio_form_state.dart';
import '../../domain/services/i_generation_socket_service.dart';
import 'melody_sketchpad_provider.dart';
import 'mycelium_biome_provider.dart';
import 'stem_download_provider.dart';
import 'studio_form_provider.dart';
import 'studio_session_provider.dart';
import 'vocal_identity_provider.dart';

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
  (ref) => HttpGenerationSubmissionService(
    baseUrl: AppConstants.apiBaseUrl,
    authInterceptor: ref.watch(authDioInterceptorProvider),
  ),
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
  StreamSubscription<PipelineSocketEvent>? _wsSubscription;
  IGenerationSocketService? _activeSocket;
  final Set<String> _completedGenerationIds = <String>{};

  static bool get _isHeadlessTestEnv {
    if (const bool.fromEnvironment('FLUTTER_TEST')) return true;
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

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
    String? selectedVoiceId,
    String? clonedVoiceProfileId,
    Map<String, dynamic>? melodyPattern,
    String? melodyReferenceId,
    String? referenceAudioUrl,
    Map<String, String>? pregenStemLocks,
  }) async {
    final optimisticId = 'gen_${DateTime.now().millisecondsSinceEpoch}';
    _completedGenerationIds.remove(optimisticId);

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

    // Resolve Phase 63 cloud conditioning inputs from Studio providers when omitted
    var resolvedVoiceId = selectedVoiceId;
    var resolvedCloneId = clonedVoiceProfileId;
    var resolvedMelodyPattern = melodyPattern;
    var resolvedMelodyRefId = melodyReferenceId;
    var resolvedRefAudioUrl = referenceAudioUrl;
    var resolvedStemLocks = pregenStemLocks;
    var resolvedMusicalKey = musicalKey;

    try {
      final vocalState = _ref.read(vocalIdentityProvider);
      resolvedVoiceId ??= vocalState.activeArchetype.id;
      resolvedCloneId ??= vocalState.activeClonedProfile?.id;
    } catch (_) {}

    try {
      final sketchpadState = _ref.read(melodySketchpadProvider);
      if (sketchpadState.hasAttachedReference &&
          sketchpadState.attachedPattern != null) {
        resolvedMelodyPattern ??= sketchpadState.attachedPattern!.toJson();
        resolvedMelodyRefId ??= sketchpadState.lastRenderedReferenceId;
        resolvedRefAudioUrl ??= sketchpadState.lastRenderedR2Url;
        final sketchpadKey = sketchpadState.attachedPattern!.musicalKey.trim();
        if (sketchpadKey.isNotEmpty &&
            (resolvedMusicalKey == null ||
                resolvedMusicalKey == 'F# Minor')) {
          resolvedMusicalKey = sketchpadKey;
        }
      }
    } catch (_) {}

    StudioFormState? formSnapshot;
    try {
      final StudioFormState snap = _ref.read<StudioFormState>(studioFormProvider);
      formSnapshot = snap;
      if (resolvedRefAudioUrl == null &&
          snap.referenceAudioPath != null &&
          snap.referenceAudioPath!.trim().isNotEmpty) {
        final rawPath = snap.referenceAudioPath!.trim();
        if (rawPath.startsWith('http://') ||
            rawPath.startsWith('https://') ||
            rawPath.startsWith('/r2/') ||
            rawPath.startsWith('/mock-storage/')) {
          resolvedRefAudioUrl = AppConstants.normalizeCloudMediaUrl(rawPath);
        }
      }
      resolvedStemLocks ??= snap.branchStemLockModes.map(
        (key, mode) => MapEntry(key, mode.name),
      );
      resolvedMusicalKey ??= snap.toSongMetadataDna().musical.key;
    } catch (_) {}

    // 2. Submit to backend API
    final submissionService = _ref.read(generationSubmissionServiceProvider);
    final response = await submissionService.submitGeneration(
      trackTitle: trackTitle,
      genre: genre,
      language: language,
      lyrics: lyrics,
      isInstrumental: isInstrumental,
      tempoBpm: tempoBpm ?? formSnapshot?.tempo.defaultBpm,
      musicalKey: resolvedMusicalKey,
      selectedVoiceId: resolvedVoiceId,
      clonedVoiceProfileId: resolvedCloneId,
      melodyPattern: resolvedMelodyPattern,
      melodyReferenceId: resolvedMelodyRefId,
      referenceAudioUrl: resolvedRefAudioUrl,
      pregenStemLocks: resolvedStemLocks,
    );

    final realGenerationId =
        response['generationId'] as String? ?? optimisticId;
    _completedGenerationIds.remove(realGenerationId);

    // 3. Update state with real generation ID
    state = state?.copyWith(generationId: realGenerationId) ??
        GenerationProgressState(
          generationId: realGenerationId,
          trackTitle: trackTitle,
          genre: genre,
          currentStep: PipelineStep.startingUp,
        );

    // T6.8: Record generation telemetry for Creator DNA (REQ-DNA-CAP-03).
    // Phase 4 (M10) closes the bidirectional loop: the full studio form
    // state enriches the event payload so genre, language, tempo, vocal
    // energy, and mood all evolve the on-device taste vector.
    try {
      final StudioFormState formState =
          formSnapshot ?? _ref.read<StudioFormState>(studioFormProvider);
      _ref.read(creatorDnaProvider.notifier).recordEvent(
        BehaviorEvent.generationSubmit(
          genre: genre.isNotEmpty ? genre : formState.genre,
          language: language.isNotEmpty ? language : formState.language,
          tempo: musicalKey ?? formState.tempo.name,
          vocalEnergy: formState.vocalEnergy.name,
          mood: formState.mood,
        ),
      );
    } catch (_) {
      // Telemetry is best-effort; never block generation on provider failure.
    }

    // Ghost Session (M10 / REQ-SES-05): a successfully submitted generation
    // consumes the in-progress draft — clear it so the recovery banner never
    // resurfaces for a track that already shipped. Best-effort like telemetry.
    try {
      _ref.read(studioSessionProvider.notifier).clearSession();
    } catch (_) {
      // Session cleanup must never block the generation pipeline.
    }

    // 4. Stream live progress via Durable Object WebSocket + HTTP polling fallback
    unawaited(_subscription?.cancel());
    unawaited(_wsSubscription?.cancel());
    _subscription = null;
    _wsSubscription = null;
    _activeSocket = socket;

    if (socket.wsUrl != null || !_isHeadlessTestEnv) {
      try {
        _wsSubscription = socket.connect(realGenerationId).listen(
              _applyEvent,
              onError: (Object error) {
                debugPrint(
                  'GenerationPipelineNotifier DO WebSocket warning (HTTP poll active): $error',
                );
              },
            );
      } catch (error) {
        debugPrint('GenerationPipelineNotifier WS connect skipped: $error');
      }
    }

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
    _completedGenerationIds.remove(generationId);
    unawaited(_subscription?.cancel());
    unawaited(_wsSubscription?.cancel());
    _subscription = null;
    _wsSubscription = null;

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
      final completionKey = current.generationId.isNotEmpty
          ? current.generationId
          : (event.generationId.isNotEmpty
              ? event.generationId
              : event.completedTrack!.id);
      if (_completedGenerationIds.add(completionKey)) {
        _onGenerationComplete(event.completedTrack!);
      }
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

  /// Runs the post-render side effects: master download + R2 URL normalization +
  /// library vault + MMO manifest + 4-stem mixer + biome reconcile +
  /// in-app notification + persistent player load.
  void _onGenerationComplete(TrackEntity track) {
    final effectiveTitle = (state?.trackTitle.isNotEmpty ?? false)
        ? state!.trackTitle
        : track.title;

    // 1. Stream the rendered master onto the device (T10.5 — keep raw URL contract).
    unawaited(_startMasterDownload(track));

    // 1b. Normalize cloud R2 URLs for playback, Library Vault, MMO & Stem Mixer (Phase 63).
    final normalizedMasterUrl =
        AppConstants.normalizeCloudMediaUrl(track.masterMp3Url);
    final normalizedStemsZipUrl =
        (track.stemsUrl != null && track.stemsUrl!.isNotEmpty)
            ? AppConstants.normalizeCloudMediaUrl(track.stemsUrl!)
            : track.stemsUrl;
    final normalizedCoverUrl =
        (track.coverUrl != null && track.coverUrl!.isNotEmpty)
            ? AppConstants.normalizeCloudMediaUrl(track.coverUrl!)
            : track.coverUrl;
    Map<StemType, String>? normalizedStemUrls;
    if (track.stemUrls != null && track.stemUrls!.isNotEmpty) {
      normalizedStemUrls = <StemType, String>{
        for (final entry in track.stemUrls!.entries)
          if (entry.value.isNotEmpty)
            entry.key: AppConstants.normalizeCloudMediaUrl(entry.value),
      };
    }

    final normalizedTrack = track.copyWith(
      title: effectiveTitle,
      masterMp3Url: normalizedMasterUrl.isNotEmpty
          ? normalizedMasterUrl
          : track.masterMp3Url,
      stemsUrl: normalizedStemsZipUrl,
      stemUrls: normalizedStemUrls,
      coverUrl: normalizedCoverUrl,
    );

    // 2. Prepend the completion notification (newest first, T10.6).
    final notification = NotificationEntity.generationReady(
      trackId: normalizedTrack.id,
      trackTitle: effectiveTitle,
      message: '${normalizedTrack.genre} • ${normalizedTrack.formattedDuration}',
    );
    _ref.read(notificationsProvider.notifier).update(
          (list) => <NotificationEntity>[notification, ...list],
        );

    // 2b. Hydrate User Library Vault, MasterMediaObject, 4-Stem Mixer & Mycelium Biome.
    StudioFormState? formSnapshot;
    try {
      formSnapshot = _ref.read<StudioFormState>(studioFormProvider);
    } catch (_) {}

    try {
      final stemStringPaths = <String, String>{
        if (normalizedStemUrls != null)
          for (final entry in normalizedStemUrls.entries)
            stemTypeToWireString(entry.key): entry.value,
      };
      final libraryTrack = LibraryTrack(
        id: normalizedTrack.id,
        title: effectiveTitle,
        creatorName: 'AI Studio',
        genre: normalizedTrack.genre,
        language: normalizedTrack.language,
        durationSeconds: normalizedTrack.duration.inSeconds,
        remoteAudioUrl: normalizedTrack.masterMp3Url,
        coverImageUrl: normalizedTrack.coverUrl,
        createdAt: DateTime.now(),
        syncStatus: TrackSyncStatus.synced,
        isInstrumental: formSnapshot?.isInstrumental ?? false,
        lyrics: normalizedTrack.lyrics ?? formSnapshot?.customLyrics,
        stemPaths: stemStringPaths,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
      _ref.read(libraryTracksProvider.notifier).addTrack(libraryTrack);
    } catch (error) {
      debugPrint('GenerationPipelineNotifier library hydration failed: $error');
    }

    try {
      final dna = normalizedTrack.toSongMetadataDna();
      final mmo = MasterMediaObject.fromSongMetadataDna(
        dna,
        masterMp3Url: normalizedTrack.masterMp3Url,
        coverArtUrl: normalizedTrack.coverUrl,
        stemUrls: normalizedTrack.stemUrls,
      );
      unawaited(
        _ref.read(masterMediaObjectProvider(dna).notifier).updateManifest(mmo),
      );
    } catch (error) {
      debugPrint('GenerationPipelineNotifier MMO hydration failed: $error');
    }

    try {
      _ref.read(stemMixerProvider.notifier).loadMixForTrack(
            normalizedTrack.id,
            trackTitle: effectiveTitle,
          );
    } catch (error) {
      debugPrint('GenerationPipelineNotifier stem mixer load failed: $error');
    }

    if (normalizedTrack.stemUrls != null &&
        normalizedTrack.stemUrls!.isNotEmpty) {
      try {
        final engine = _ref.read(multiStemAudioEngineProvider);
        unawaited(
          engine
              .loadFromManifest(
                stemUrls: normalizedTrack.stemUrls!,
                masterUrl: normalizedTrack.masterMp3Url,
              )
              .catchError((Object error) {
            debugPrint(
              'GenerationPipelineNotifier multi-stem load skipped: $error',
            );
          }),
        );
      } catch (error) {
        debugPrint(
          'GenerationPipelineNotifier multi-stem provider failed: $error',
        );
      }
    }

    try {
      _ref.read(myceliumBiomeGraphProvider.notifier).reconcileWithCockpitState();
    } catch (error) {
      debugPrint('GenerationPipelineNotifier biome reconcile failed: $error');
    }

    // 3. Auto-play / load master in persistent player (Phase 15 Option A)
    if (_autoPlayOnComplete && normalizedTrack.masterMp3Url.isNotEmpty) {
      try {
        _ref
            .read(playerStateProvider.notifier)
            .playTrack(normalizedTrack.toTrack());
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
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _completedGenerationIds.clear();
    unawaited(_activeSocket?.disconnect());
    _activeSocket = null;
    state = null;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _wsSubscription?.cancel();
    _wsSubscription = null;
    unawaited(_activeSocket?.disconnect());
    _activeSocket = null;
    super.dispose();
  }
}
