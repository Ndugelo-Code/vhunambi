# Phase 10 · Design — Audio Generation Pipeline Real-Time WebSocket Bridge & Result Panel

> **Phase:** 10  
> **Format:** Class signatures, interface contracts, provider wiring, and widget API surface  
> All paths relative to `apps/vhunambi_client/lib/`

---

## T10.1 — Domain Models

### `features/studio/domain/models/generation_pipeline_state.dart`

```dart
import 'package:flutter/foundation.dart';
import '../../../track/domain/models/track_entity.dart';

/// Step labels within the 4-stage audio synthesis pipeline.
/// Distinct from [GenerationPhase] in studio_form_state.dart.
enum PipelineStep {
  startingUp,
  writingLyrics,
  producingBeat,
  ready,
  failed,
}

/// Parsed representation of a single WebSocket `pipeline_event` frame.
@immutable
class PipelineSocketEvent {
  final String generationId;
  final PipelineStep step;
  final int stepIndex;
  final double progressPercent;
  final String statusMessage;
  final String? generatedLyrics;
  final TrackEntity? completedTrack;
  final String? error;

  const PipelineSocketEvent({
    required this.generationId,
    required this.step,
    required this.stepIndex,
    required this.progressPercent,
    required this.statusMessage,
    this.generatedLyrics,
    this.completedTrack,
    this.error,
  });

  factory PipelineSocketEvent.fromJson(Map<String, dynamic> json) {
    return PipelineSocketEvent(
      generationId: json['generation_id'] as String,
      step: _stepFromString(json['step'] as String),
      stepIndex: json['step_index'] as int,
      progressPercent: (json['progress_percent'] as num).toDouble(),
      statusMessage: json['status_message'] as String,
      generatedLyrics: json['generated_lyrics'] as String?,
      completedTrack: json['completed_track'] != null
          ? TrackEntity.fromJson(json['completed_track'] as Map<String, dynamic>)
          : null,
      error: json['error'] as String?,
    );
  }

  static PipelineStep _stepFromString(String raw) {
    return switch (raw) {
      'starting_up'    => PipelineStep.startingUp,
      'writing_lyrics' => PipelineStep.writingLyrics,
      'producing_beat' => PipelineStep.producingBeat,
      'ready'          => PipelineStep.ready,
      _                => PipelineStep.failed,
    };
  }

  PipelineSocketEvent copyWith({
    String? generationId,
    PipelineStep? step,
    int? stepIndex,
    double? progressPercent,
    String? statusMessage,
    String? generatedLyrics,
    TrackEntity? completedTrack,
    String? error,
  }) {
    return PipelineSocketEvent(
      generationId: generationId ?? this.generationId,
      step: step ?? this.step,
      stepIndex: stepIndex ?? this.stepIndex,
      progressPercent: progressPercent ?? this.progressPercent,
      statusMessage: statusMessage ?? this.statusMessage,
      generatedLyrics: generatedLyrics ?? this.generatedLyrics,
      completedTrack: completedTrack ?? this.completedTrack,
      error: error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PipelineSocketEvent &&
          generationId == other.generationId &&
          step == other.step &&
          stepIndex == other.stepIndex &&
          progressPercent == other.progressPercent;

  @override
  int get hashCode => Object.hash(generationId, step, stepIndex, progressPercent);
}

/// Riverpod-managed state for the live generation pipeline card.
@immutable
class GenerationProgressState {
  final String generationId;
  final String trackTitle;
  final String genre;
  final PipelineStep currentStep;
  final String statusMessage;
  final double progressPercent;
  final String? generatedLyrics;
  final TrackEntity? completedTrack;
  final String? errorMessage;

  const GenerationProgressState({
    required this.generationId,
    required this.trackTitle,
    required this.genre,
    this.currentStep = PipelineStep.startingUp,
    this.statusMessage = 'Allocating GPU synthesis worker...',
    this.progressPercent = 0.1,
    this.generatedLyrics,
    this.completedTrack,
    this.errorMessage,
  });

  bool get isGenerating =>
      currentStep != PipelineStep.ready && currentStep != PipelineStep.failed;
  bool get isReady => currentStep == PipelineStep.ready;
  bool get hasFailed => currentStep == PipelineStep.failed;

  GenerationProgressState copyWith({
    String? generationId,
    String? trackTitle,
    String? genre,
    PipelineStep? currentStep,
    String? statusMessage,
    double? progressPercent,
    String? generatedLyrics,
    TrackEntity? completedTrack,
    String? errorMessage,
  }) {
    return GenerationProgressState(
      generationId: generationId ?? this.generationId,
      trackTitle: trackTitle ?? this.trackTitle,
      genre: genre ?? this.genre,
      currentStep: currentStep ?? this.currentStep,
      statusMessage: statusMessage ?? this.statusMessage,
      progressPercent: progressPercent ?? this.progressPercent,
      generatedLyrics: generatedLyrics ?? this.generatedLyrics,
      completedTrack: completedTrack ?? this.completedTrack,
      errorMessage: errorMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GenerationProgressState &&
          generationId == other.generationId &&
          currentStep == other.currentStep &&
          progressPercent == other.progressPercent &&
          statusMessage == other.statusMessage;

  @override
  int get hashCode =>
      Object.hash(generationId, currentStep, progressPercent, statusMessage);
}
```

---

## T10.2 — WebSocket Service

### `features/studio/domain/services/i_generation_socket_service.dart`

```dart
import '../models/generation_pipeline_state.dart';

abstract class IGenerationSocketService {
  /// Opens a WebSocket connection for [generationId] and returns a broadcast stream.
  Stream<PipelineSocketEvent> connect(String generationId);

  /// Gracefully closes the socket (code 1000).
  Future<void> disconnect();

  /// Whether the socket is currently connected.
  bool get isConnected;
}
```

### `features/studio/data/services/generation_socket_service.dart`

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../domain/models/generation_pipeline_state.dart';
import '../../domain/services/i_generation_socket_service.dart';

class GenerationSocketService implements IGenerationSocketService {
  static const _baseUrl = 'wss://api.vhunambi.com/ws/generation';
  static const _pingInterval = Duration(seconds: 25);
  static const _pongTimeout = Duration(seconds: 10);
  static const _maxAttempts = 5;

  WebSocket? _socket;
  Timer? _pingTimer;
  Timer? _pongTimer;
  final StreamController<PipelineSocketEvent> _controller =
      StreamController<PipelineSocketEvent>.broadcast();

  String? _activeGenerationId;
  int _reconnectAttempts = 0;

  @override
  bool get isConnected => _socket?.readyState == WebSocket.open;

  @override
  Stream<PipelineSocketEvent> connect(String generationId) {
    _activeGenerationId = generationId;
    _reconnectAttempts = 0;
    _doConnect(generationId);
    return _controller.stream;
  }

  Future<void> _doConnect(String generationId) async {
    try {
      _socket = await WebSocket.connect('$_baseUrl?id=$generationId');
      _startHeartbeat();
      _socket!.listen(
        _onFrame,
        onError: _onError,
        onDone: () => _scheduleReconnect(generationId),
        cancelOnError: false,
      );
    } catch (e) {
      _scheduleReconnect(generationId);
    }
  }

  void _onFrame(dynamic raw) {
    _resetPongTimer();
    if (raw is! String) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['type'] == 'pipeline_event') {
        _controller.add(PipelineSocketEvent.fromJson(json));
      } else if (json['type'] == 'PONG') {
        _pongTimer?.cancel();
      }
    } catch (_) { /* malformed frame — discard */ }
  }

  void _onError(Object error) {
    if (_activeGenerationId != null) {
      _scheduleReconnect(_activeGenerationId!);
    }
  }

  void _startHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      _socket?.add(jsonEncode({'type': 'PING'}));
      _resetPongTimer();
    });
  }

  void _resetPongTimer() {
    _pongTimer?.cancel();
    _pongTimer = Timer(_pongTimeout, () {
      _socket?.close();
      if (_activeGenerationId != null) {
        _scheduleReconnect(_activeGenerationId!);
      }
    });
  }

  void _scheduleReconnect(String generationId) {
    _reconnectAttempts++;
    if (_reconnectAttempts > _maxAttempts) {
      _controller.addError(Exception('MaxReconnectAttemptsExceeded'));
      return;
    }
    final delay = Duration(seconds: 1 << (_reconnectAttempts - 1)); // exponential
    Future.delayed(delay, () => _doConnect(generationId));
  }

  @override
  Future<void> disconnect() async {
    _pingTimer?.cancel();
    _pongTimer?.cancel();
    _activeGenerationId = null;
    await _socket?.close(WebSocket.normalClosure);
  }
}
```

### `features/studio/data/services/fake_generation_socket_service.dart` (test double)

```dart
import 'dart:async';
import '../../domain/models/generation_pipeline_state.dart';
import '../../domain/services/i_generation_socket_service.dart';

class FakeGenerationSocketService implements IGenerationSocketService {
  final Duration stepDelay;
  bool _connected = false;

  FakeGenerationSocketService({this.stepDelay = const Duration(milliseconds: 200)});

  @override
  bool get isConnected => _connected;

  @override
  Stream<PipelineSocketEvent> connect(String generationId) async* {
    _connected = true;
    final steps = [
      (PipelineStep.startingUp,    1, 0.15, 'Allocating GPU synthesis worker...'),
      (PipelineStep.writingLyrics, 2, 0.40, 'Writing lyrics in your chosen language...'),
      (PipelineStep.producingBeat, 3, 0.72, 'Laying down the drums... feel it building 🥁'),
      (PipelineStep.ready,         4, 1.00, 'Your song is ready!'),
    ];
    for (final (step, idx, progress, msg) in steps) {
      await Future.delayed(stepDelay);
      yield PipelineSocketEvent(
        generationId: generationId,
        step: step,
        stepIndex: idx,
        progressPercent: progress,
        statusMessage: msg,
      );
    }
    _connected = false;
  }

  @override
  Future<void> disconnect() async => _connected = false;
}
```

---

## T10.3 — Riverpod Provider Layer

### `features/studio/presentation/providers/generation_pipeline_providers.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/generation_pipeline_state.dart';
import '../../domain/services/i_generation_socket_service.dart';
import '../../data/services/generation_socket_service.dart';
import '../../../notifications/domain/models/notification_entity.dart';
import 'stem_download_provider.dart';

/// Injectable socket service — override in tests with FakeGenerationSocketService.
final socketServiceProvider = Provider<IGenerationSocketService>(
  (ref) => GenerationSocketService(),
);

/// Nullable: null = no active generation; non-null = pipeline in progress or done.
final generationProgressProvider =
    StateNotifierProvider<GenerationPipelineNotifier, GenerationProgressState?>(
  (ref) => GenerationPipelineNotifier(ref),
);

/// Flat list of in-app notifications (newest first).
final notificationsProvider =
    StateProvider<List<NotificationEntity>>((ref) => []);

class GenerationPipelineNotifier
    extends StateNotifier<GenerationProgressState?> {
  final Ref _ref;
  GenerationPipelineNotifier(this._ref) : super(null);

  Future<void> startGeneration({
    required String generationId,
    required String trackTitle,
    required String genre,
  }) async {
    state = GenerationProgressState(
      generationId: generationId,
      trackTitle: trackTitle,
      genre: genre,
    );

    final socket = _ref.read(socketServiceProvider);
    socket.connect(generationId).listen(
      _applyEvent,
      onError: (Object err) {
        state = state?.copyWith(
          currentStep: PipelineStep.failed,
          errorMessage: err.toString(),
        );
      },
    );
  }

  void _applyEvent(PipelineSocketEvent event) {
    state = state?.copyWith(
      currentStep: event.step,
      statusMessage: event.statusMessage,
      progressPercent: event.progressPercent,
      generatedLyrics: event.generatedLyrics,
      completedTrack: event.completedTrack,
      errorMessage: event.error,
    );

    if (event.step == PipelineStep.ready && event.completedTrack != null) {
      _onGenerationComplete(event.completedTrack!);
    }

    if (event.step == PipelineStep.failed) {
      state = state?.copyWith(
        errorMessage: event.error ?? 'Generation failed. Please try again.',
      );
    }
  }

  void _onGenerationComplete(TrackEntity track) {
    // 1. Trigger stem download
    _ref.read(stemDownloadServiceProvider).downloadMaster(track.masterMp3Url);

    // 2. Append notification (newest first)
    final notification = NotificationEntity(
      id: track.id,
      title: 'Your song "${track.title}" is ready!',
      message: '${track.genre} • ${track.formattedDuration}',
      targetTrackId: track.id,
      createdAt: DateTime.now(),
    );
    _ref.read(notificationsProvider.notifier).update(
      (list) => [notification, ...list],
    );
  }

  void reset() => state = null;

  @override
  void dispose() {
    _ref.read(socketServiceProvider).disconnect();
    super.dispose();
  }
}
```

---

## T10.4 — Widget API Surface Change (`GenerationPipelineCard`)

`GenerationPipelineCard` is refactored from `StatefulWidget` + manual props to `ConsumerStatefulWidget`:

```dart
// BEFORE (Phase 3 static props):
class GenerationPipelineCard extends StatefulWidget {
  final String title;
  final String genre;
  final int currentStep;
  final String statusMessage;
  final VoidCallback? onNewSong;
  ...
}

// AFTER (Phase 10 live binding):
class GenerationPipelineCard extends ConsumerStatefulWidget {
  final VoidCallback? onNewSong;
  const GenerationPipelineCard({super.key, this.onNewSong});
  @override
  ConsumerState<GenerationPipelineCard> createState() => _GenerationPipelineCardState();
}
```

**Key internal changes:**
- `ref.watch(generationProgressProvider)` replaces all manual props.
- `_equalizerController` ticks only when `state?.isGenerating == true`.
- A null state renders a `_PipelineSkeletonLoader` (pulsing placeholder rows).
- `state?.hasFailed` renders an `_ErrorBanner` widget with a Retry CTA.
- `state?.generatedLyrics != null` controls visibility of the `Show lyrics` toggle.

---

## T10.5 — Stem Download Service

### `features/studio/domain/services/i_stem_download_service.dart`

```dart
import '../models/stem_download_progress.dart';

abstract class IStemDownloadService {
  Stream<StemDownloadProgress> downloadMaster(String url);
  Stream<StemDownloadProgress> downloadStems(String url);
  Future<void> cancelDownload(String url);
}
```

### `features/studio/domain/models/stem_download_progress.dart`

```dart
import 'package:flutter/foundation.dart';

@immutable
class StemDownloadProgress {
  final String url;
  final int receivedBytes;
  final int totalBytes;
  final String? localPath;
  final String? error;

  const StemDownloadProgress({
    required this.url,
    required this.receivedBytes,
    required this.totalBytes,
    this.localPath,
    this.error,
  });

  double get progress => totalBytes > 0 ? receivedBytes / totalBytes : 0.0;
  bool get isComplete => localPath != null;
  bool get hasError => error != null;

  StemDownloadProgress copyWith({
    int? receivedBytes,
    int? totalBytes,
    String? localPath,
    String? error,
  }) {
    return StemDownloadProgress(
      url: url,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      localPath: localPath,
      error: error,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StemDownloadProgress &&
          url == other.url &&
          receivedBytes == other.receivedBytes &&
          totalBytes == other.totalBytes;

  @override
  int get hashCode => Object.hash(url, receivedBytes, totalBytes);
}
```

### Provider

```dart
// features/studio/presentation/providers/stem_download_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/services/i_stem_download_service.dart';
import '../../data/services/stem_download_service.dart';

final stemDownloadServiceProvider = Provider<IStemDownloadService>(
  (ref) => StemDownloadService(),
);
```

---

## T10.6 — Notification Entity

### `features/notifications/domain/models/notification_entity.dart`

```dart
import 'package:flutter/foundation.dart';

@immutable
class NotificationEntity {
  final String id;
  final String title;
  final String message;
  final String? targetTrackId;
  final DateTime createdAt;
  final bool isRead;

  const NotificationEntity({
    required this.id,
    required this.title,
    required this.message,
    this.targetTrackId,
    required this.createdAt,
    this.isRead = false,
  });

  NotificationEntity copyWith({
    String? id,
    String? title,
    String? message,
    String? targetTrackId,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return NotificationEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      targetTrackId: targetTrackId ?? this.targetTrackId,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationEntity && id == other.id && isRead == other.isRead;

  @override
  int get hashCode => Object.hash(id, isRead);
}
```
