import 'package:flutter/foundation.dart';
import '../../../track/domain/models/track_entity.dart';

/// Step labels within the 4-stage audio synthesis pipeline.
///
/// Deliberately distinct from `GenerationPhase` in `studio_form_state.dart`:
/// that enum drives the studio *form* FSM, this one drives the live pipeline
/// card (T10.1).
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

  /// 1-4 for the four synthesis stages (`0` when the pipeline failed early).
  final int stepIndex;

  /// `0.0` – `1.0`.
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

  /// Tolerant decoder — a malformed frame must never tear down the socket.
  factory PipelineSocketEvent.fromJson(Map<String, dynamic> json) {
    final rawTrack = json['completed_track'];
    return PipelineSocketEvent(
      generationId: json['generation_id'] as String? ?? '',
      step: stepFromString(json['step'] as String? ?? ''),
      stepIndex: (json['step_index'] as num?)?.toInt() ?? 0,
      progressPercent:
          (json['progress_percent'] as num?)?.toDouble() ?? 0.0,
      statusMessage: json['status_message'] as String? ?? '',
      generatedLyrics: json['generated_lyrics'] as String?,
      completedTrack: rawTrack is Map
          ? TrackEntity.fromJson(Map<String, dynamic>.from(rawTrack))
          : null,
      error: json['error'] as String?,
    );
  }

  /// Wire-format step names → [PipelineStep] (`default → failed`).
  static PipelineStep stepFromString(String raw) {
    return switch (raw) {
      'starting_up' => PipelineStep.startingUp,
      'writing_lyrics' => PipelineStep.writingLyrics,
      'producing_beat' => PipelineStep.producingBeat,
      'ready' => PipelineStep.ready,
      _ => PipelineStep.failed,
    };
  }

  /// `true` once the payload carries a finished master.
  bool get hasCompletedTrack => completedTrack != null;

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
          runtimeType == other.runtimeType &&
          generationId == other.generationId &&
          step == other.step &&
          stepIndex == other.stepIndex &&
          progressPercent == other.progressPercent;

  @override
  int get hashCode =>
      Object.hash(generationId, step, stepIndex, progressPercent);

  @override
  String toString() =>
      'PipelineSocketEvent($generationId, $step, $stepIndex, '
      '$progressPercent)';
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

  /// `true` while the four synthesis stages are still running.
  bool get isGenerating =>
      currentStep != PipelineStep.ready && currentStep != PipelineStep.failed;

  bool get isReady => currentStep == PipelineStep.ready;

  bool get hasFailed => currentStep == PipelineStep.failed;

  /// 1-4 card step position (`0` when the pipeline failed).
  ///
  /// Additive convenience mirroring [PipelineSocketEvent.stepIndex] so the
  /// pipeline card never has to duplicate the enum → index mapping.
  int get stepNumber => switch (currentStep) {
        PipelineStep.startingUp => 1,
        PipelineStep.writingLyrics => 2,
        PipelineStep.producingBeat => 3,
        PipelineStep.ready => 4,
        PipelineStep.failed => 0,
      };

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
          runtimeType == other.runtimeType &&
          generationId == other.generationId &&
          currentStep == other.currentStep &&
          progressPercent == other.progressPercent &&
          statusMessage == other.statusMessage;

  @override
  int get hashCode =>
      Object.hash(generationId, currentStep, progressPercent, statusMessage);

  @override
  String toString() =>
      'GenerationProgressState($generationId, $currentStep, '
      '$progressPercent)';
}
