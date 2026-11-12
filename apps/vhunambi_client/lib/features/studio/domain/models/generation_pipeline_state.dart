import 'package:flutter/foundation.dart';
import '../../../track/domain/models/track_entity.dart';

/// Step labels within the 4-stage audio synthesis pipeline.
///
/// Deliberately distinct from `GenerationPhase` in `studio_form_state.dart`:
/// that enum drives the studio *form* FSM, this one drives the live pipeline
/// card (T10.1).
enum PipelineStep { startingUp, writingLyrics, producingBeat, ready, failed }

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
    final generationId =
        (json['generation_id'] ?? json['generationId']) as String? ?? '';
    final rawStepObj = json['step'] ?? json['status'];
    final rawStep = rawStepObj as String? ?? '';
    final step = stepFromString(rawStep);

    final rawProgress = json['progress_percent'] ?? json['progressPct'];
    var progressPercent = (rawProgress as num?)?.toDouble() ?? 0.0;
    if (progressPercent > 1.0) {
      progressPercent = (progressPercent / 100.0).clamp(0.0, 1.0);
    }

    final explicitError = (json['error'] ?? json['errorMessage']) as String?;
    final hasStepOrError = rawStepObj != null || explicitError != null;

    final rawStepIndex = (json['step_index'] as num?)?.toInt();
    final stepIndex =
        rawStepIndex ??
        (!hasStepOrError
            ? 0
            : switch (step) {
                PipelineStep.startingUp => 1,
                PipelineStep.writingLyrics => 2,
                PipelineStep.producingBeat => 3,
                PipelineStep.ready => 4,
                PipelineStep.failed => 0,
              });

    final explicitMessage =
        (json['status_message'] ?? json['message']) as String?;
    final statusMessage =
        explicitMessage ??
        (!hasStepOrError
            ? ''
            : switch (step) {
                PipelineStep.startingUp => 'Starting synthesis pipeline...',
                PipelineStep.writingLyrics =>
                  'Composing authentic dialect lyrics...',
                PipelineStep.producingBeat =>
                  'Rendering African rhythm and audio stems...',
                PipelineStep.ready => 'Studio Master Ready',
                PipelineStep.failed => explicitError ?? 'Synthesis failed.',
              });

    TrackEntity? completedTrack;
    final rawTrack = json['completed_track'] ?? json['completedTrack'];
    if (rawTrack is Map) {
      completedTrack = TrackEntity.fromJson(
        Map<String, dynamic>.from(rawTrack),
      );
    } else if (step == PipelineStep.ready) {
      final masterUrl =
          (json['masterMp3Url'] ?? json['master_mp3_url'] ?? json['audio_url'])
              as String? ??
          '';
      if (masterUrl.isNotEmpty) {
        completedTrack = TrackEntity.fromJson(<String, dynamic>{
          'id': generationId.isNotEmpty ? generationId : 'gen_ready',
          'title': json['trackTitle'] ?? json['title'] ?? 'Studio Master',
          'genre': json['genre'] ?? 'Amapiano',
          'language': json['language'] ?? 'English',
          'master_mp3_url': masterUrl,
          'stems_url': json['stemsZipUrl'] ?? json['stems_zip_url'],
          'stem_urls': json['stemUrls'] ?? json['stem_urls'],
          'cover_url': json['coverUrl'] ?? json['cover_url'],
          'lyrics': json['lyrics'],
          'duration_seconds': json['durationSec'] ?? 180,
        });
      }
    }

    return PipelineSocketEvent(
      generationId: generationId,
      step: step,
      stepIndex: stepIndex,
      progressPercent: progressPercent,
      statusMessage: statusMessage,
      generatedLyrics:
          (json['generated_lyrics'] ??
                  json['generatedLyrics'] ??
                  json['lyrics'])
              as String?,
      completedTrack: completedTrack,
      error: explicitError,
    );
  }

  /// Wire-format step names → [PipelineStep] (`default → failed`).
  static PipelineStep stepFromString(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'starting_up' || 'queued' || 'in_queue' => PipelineStep.startingUp,
      'writing_lyrics' => PipelineStep.writingLyrics,
      'producing_beat' ||
      'synthesizing' ||
      'running' ||
      'processing' ||
      'separating_stems' ||
      'uploading' ||
      'mastering' ||
      'in_progress' => PipelineStep.producingBeat,
      'ready' || 'completed' || 'succeeded' => PipelineStep.ready,
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
