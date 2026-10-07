import 'dart:async';

import '../../../track/domain/models/track_entity.dart';
import '../../domain/models/generation_pipeline_state.dart';
import '../../domain/services/i_generation_socket_service.dart';

/// Deterministic, network-free socket double used by every studio test and by
/// demo builds (T10.2 invariant #4).
///
/// Emits the four canonical pipeline frames in order:
/// `startingUp (0.15)` → `writingLyrics (0.40)` → `producingBeat (0.72)` →
/// `ready (1.00)`.
///
/// Deliberately free of `flutter_test` imports so it compiles into production
/// builds.
class FakeGenerationSocketService implements IGenerationSocketService {
  FakeGenerationSocketService({
    this.stepDelay = const Duration(milliseconds: 200),
    this.stepDelayForConnect,
    this.completedTrack,
    this.generatedLyrics,
    this.failAtStep,
  });

  /// Delay applied before each emitted step.
  final Duration stepDelay;

  /// Optional per-connection override (lets tests use a tiny delay).
  final Duration Function(String generationId)? stepDelayForConnect;

  /// Master attached to the terminal `ready` frame.
  final TrackEntity? completedTrack;

  /// Lyrics attached to the `writingLyrics` frame.
  final String? generatedLyrics;

  /// When set, the stream fails at this step instead of reaching `ready`.
  final PipelineStep? failAtStep;

  bool _connected = false;
  int connectCount = 0;
  final List<String> connectedGenerationIds = <String>[];
  Timer? _currentTimer;
  StreamController<PipelineSocketEvent>? _activeController;

  @override
  bool get isConnected => _connected;

  /// The four canonical frames for [generationId].
  static List<PipelineSocketEvent> canonicalSteps(
    String generationId, {
    TrackEntity? completedTrack,
    String? generatedLyrics,
  }) {
    return <PipelineSocketEvent>[
      PipelineSocketEvent(
        generationId: generationId,
        step: PipelineStep.startingUp,
        stepIndex: 1,
        progressPercent: 0.15,
        statusMessage: 'Allocating GPU synthesis worker...',
      ),
      PipelineSocketEvent(
        generationId: generationId,
        step: PipelineStep.writingLyrics,
        stepIndex: 2,
        progressPercent: 0.40,
        statusMessage: 'Writing lyrics in your chosen language...',
        generatedLyrics: generatedLyrics,
      ),
      PipelineSocketEvent(
        generationId: generationId,
        step: PipelineStep.producingBeat,
        stepIndex: 3,
        progressPercent: 0.72,
        statusMessage: 'Laying down the drums... feel it building 🥁',
      ),
      PipelineSocketEvent(
        generationId: generationId,
        step: PipelineStep.ready,
        stepIndex: 4,
        progressPercent: 1.00,
        statusMessage: 'Your song is ready!',
        completedTrack: completedTrack,
      ),
    ];
  }

  @override
  Stream<PipelineSocketEvent> connect(String generationId) {
    _currentTimer?.cancel();
    _currentTimer = null;
    if (_activeController != null && !_activeController!.isClosed) {
      _activeController!.close();
    }

    _connected = true;
    connectCount++;
    connectedGenerationIds.add(generationId);

    final delay = stepDelayForConnect?.call(generationId) ?? stepDelay;
    final events = canonicalSteps(
      generationId,
      completedTrack: completedTrack,
      generatedLyrics: generatedLyrics,
    );

    int nextIndex = 0;
    late final StreamController<PipelineSocketEvent> controller;

    void scheduleNext() {
      if (!_connected || controller.isClosed) return;
      if (nextIndex >= events.length) {
        _connected = false;
        controller.close();
        return;
      }

      final event = events[nextIndex++];
      _currentTimer = Timer(delay, () {
        _currentTimer = null;
        if (!_connected || controller.isClosed) return;

        if (failAtStep != null && event.step == failAtStep) {
          controller.add(
            event.copyWith(
              step: PipelineStep.failed,
              stepIndex: 0,
              progressPercent: 0.0,
              statusMessage: 'Generation failed. Please try again.',
              error: 'Synthesis worker crashed.',
            ),
          );
          _connected = false;
          controller.close();
          return;
        }

        controller.add(event);

        if (nextIndex >= events.length) {
          _connected = false;
          controller.close();
        } else {
          scheduleNext();
        }
      });
    }

    controller = StreamController<PipelineSocketEvent>(
      onListen: () {
        scheduleNext();
      },
      onCancel: () {
        _currentTimer?.cancel();
        _currentTimer = null;
        _connected = false;
      },
    );

    _activeController = controller;
    return controller.stream;
  }

  @override
  Future<void> disconnect() async {
    _currentTimer?.cancel();
    _currentTimer = null;
    _connected = false;
    if (_activeController != null && !_activeController!.isClosed) {
      await _activeController!.close();
    }
    _activeController = null;
  }
}
