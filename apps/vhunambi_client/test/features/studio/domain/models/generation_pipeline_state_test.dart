import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/studio/domain/models/generation_pipeline_state.dart';
import 'package:vhunambi_client/features/studio/domain/models/stem_download_progress.dart';

/// T10.1 — Generation pipeline domain model suite.
Map<String, dynamic> _startingUpJson() => <String, dynamic>{
      'type': 'pipeline_event',
      'generation_id': 'gen_abc123',
      'step': 'starting_up',
      'step_index': 1,
      'progress_percent': 0.15,
      'status_message': 'Allocating GPU synthesis worker...',
      'generated_lyrics': null,
      'completed_track': null,
      'error': null,
    };

Map<String, dynamic> _readyJson() => <String, dynamic>{
      'type': 'pipeline_event',
      'generation_id': 'gen_abc123',
      'step': 'ready',
      'step_index': 4,
      'progress_percent': 1.0,
      'status_message': 'Your song is ready!',
      'generated_lyrics': '[Verse 1]\nNight breaks...',
      'completed_track': <String, dynamic>{
        'id': 'trk_pipeline_001',
        'title': 'rave',
        'genre': 'Gqom',
        'language': 'Tshivenḓa',
        'duration_seconds': 209,
        'master_mp3_url': 'https://cdn.vhunambi.com/masters/trk_pipeline_001.mp3',
        'cover_url': 'https://cdn.vhunambi.com/covers/trk_pipeline_001.jpg',
        'lyrics': 'Night breaks...',
      },
      'error': null,
    };

void main() {
  group('PipelineSocketEvent', () {
    test('fromJson parses a starting_up frame', () {
      final event = PipelineSocketEvent.fromJson(_startingUpJson());

      expect(event.generationId, 'gen_abc123');
      expect(event.step, PipelineStep.startingUp);
      expect(event.stepIndex, 1);
      expect(event.progressPercent, 0.15);
      expect(event.statusMessage, 'Allocating GPU synthesis worker...');
      expect(event.generatedLyrics, isNull);
      expect(event.completedTrack, isNull);
      expect(event.error, isNull);
      expect(event.hasCompletedTrack, isFalse);
    });

    test('fromJson parses a ready frame with a completed track', () {
      final event = PipelineSocketEvent.fromJson(_readyJson());

      expect(event.step, PipelineStep.ready);
      expect(event.stepIndex, 4);
      expect(event.progressPercent, 1.0);
      expect(event.generatedLyrics, contains('Night breaks'));
      expect(event.hasCompletedTrack, isTrue);
      expect(event.completedTrack?.id, 'trk_pipeline_001');
      expect(event.completedTrack?.title, 'rave');
      expect(event.completedTrack?.genre, 'Gqom');
      expect(event.completedTrack?.duration.inSeconds, 209);
      expect(
        event.completedTrack?.masterMp3Url,
        'https://cdn.vhunambi.com/masters/trk_pipeline_001.mp3',
      );
      expect(event.completedTrack?.formattedDuration, '3:29');
    });

    test('fromJson maps unknown step strings to failed', () {
      final event = PipelineSocketEvent.fromJson(<String, dynamic>{
        'generation_id': 'gen_x',
        'step': 'summoning_log_drums',
        'step_index': 0,
        'progress_percent': 0.0,
        'status_message': 'Unknown',
      });

      expect(event.step, PipelineStep.failed);
    });

    test('fromJson tolerates a sparse frame', () {
      final event = PipelineSocketEvent.fromJson(<String, dynamic>{});

      expect(event.generationId, '');
      expect(event.step, PipelineStep.failed);
      expect(event.stepIndex, 0);
      expect(event.progressPercent, 0.0);
      expect(event.statusMessage, '');
    });

    test('stepFromString covers every wire name', () {
      expect(
        PipelineSocketEvent.stepFromString('starting_up'),
        PipelineStep.startingUp,
      );
      expect(
        PipelineSocketEvent.stepFromString('writing_lyrics'),
        PipelineStep.writingLyrics,
      );
      expect(
        PipelineSocketEvent.stepFromString('producing_beat'),
        PipelineStep.producingBeat,
      );
      expect(PipelineSocketEvent.stepFromString('ready'), PipelineStep.ready);
      expect(
        PipelineSocketEvent.stepFromString('anything_else'),
        PipelineStep.failed,
      );
    });

    test('copyWith replaces the step and keeps untouched fields', () {
      final event = PipelineSocketEvent.fromJson(_startingUpJson());
      final advanced = event.copyWith(
        step: PipelineStep.producingBeat,
        stepIndex: 3,
        progressPercent: 0.72,
      );

      expect(advanced.step, PipelineStep.producingBeat);
      expect(advanced.stepIndex, 3);
      expect(advanced.progressPercent, 0.72);
      expect(advanced.generationId, event.generationId);
      expect(advanced.statusMessage, event.statusMessage);
    });

    test('equality is keyed on id, step, index and progress', () {
      final event = PipelineSocketEvent.fromJson(_startingUpJson());
      final same = event.copyWith();

      expect(event, same);
      expect(event.hashCode, same.hashCode);
      expect(event, isNot(event.copyWith(progressPercent: 0.5)));
      expect(event.toString(), contains('startingUp'));
    });

    test('equality is false when progressPercent differs', () {
      final event = PipelineSocketEvent.fromJson(_startingUpJson());

      expect(event == event.copyWith(progressPercent: 0.16), isFalse);
    });
  });

  group('GenerationProgressState', () {
    test('isGenerating is true across the three synthesis steps', () {
      for (final step in const <PipelineStep>[
        PipelineStep.startingUp,
        PipelineStep.writingLyrics,
        PipelineStep.producingBeat,
      ]) {
        expect(_state(currentStep: step).isGenerating, isTrue, reason: '$step');
      }
    });

    test('isGenerating is false for ready and failed', () {
      expect(_state(currentStep: PipelineStep.ready).isGenerating, isFalse);
      expect(_state(currentStep: PipelineStep.failed).isGenerating, isFalse);
    });

    test('isReady is true only for ready', () {
      expect(_state(currentStep: PipelineStep.ready).isReady, isTrue);
      expect(_state(currentStep: PipelineStep.producingBeat).isReady, isFalse);
    });

    test('hasFailed is true only for failed', () {
      expect(_state(currentStep: PipelineStep.failed).hasFailed, isTrue);
      expect(_state(currentStep: PipelineStep.ready).hasFailed, isFalse);
    });

    test('stepNumber maps 1-4 and 0 when failed', () {
      expect(_state(currentStep: PipelineStep.startingUp).stepNumber, 1);
      expect(_state(currentStep: PipelineStep.writingLyrics).stepNumber, 2);
      expect(_state(currentStep: PipelineStep.producingBeat).stepNumber, 3);
      expect(_state(currentStep: PipelineStep.ready).stepNumber, 4);
      expect(_state(currentStep: PipelineStep.failed).stepNumber, 0);
    });

    test('defaults describe the first synthesis frame', () {
      const state = GenerationProgressState(
        generationId: 'gen_1',
        trackTitle: 'rave',
        genre: 'Gqom',
      );

      expect(state.currentStep, PipelineStep.startingUp);
      expect(state.statusMessage, 'Allocating GPU synthesis worker...');
      expect(state.progressPercent, 0.1);
      expect(state.generatedLyrics, isNull);
      expect(state.completedTrack, isNull);
      expect(state.errorMessage, isNull);
    });

    test('copyWith updates currentStep without altering other fields', () {
      final state = _state();
      final advanced = state.copyWith(
        currentStep: PipelineStep.producingBeat,
        progressPercent: 0.72,
        statusMessage: 'Laying down the drums...',
      );

      expect(advanced.currentStep, PipelineStep.producingBeat);
      expect(advanced.progressPercent, 0.72);
      expect(advanced.statusMessage, 'Laying down the drums...');
      expect(advanced.generationId, state.generationId);
      expect(advanced.trackTitle, state.trackTitle);
      expect(advanced.genre, state.genre);
    });

    test('copyWith clears the error message when omitted', () {
      final failed = _state(
        currentStep: PipelineStep.failed,
        errorMessage: 'boom',
      );

      expect(
        failed.copyWith(currentStep: PipelineStep.ready).errorMessage,
        isNull,
      );
    });

    test('equality is keyed on id, step, progress and message', () {
      final state = _state();

      expect(state, state.copyWith());
      expect(state.hashCode, state.copyWith().hashCode);
      expect(state, isNot(state.copyWith(currentStep: PipelineStep.ready)));
      expect(state.toString(), contains('gen_pipeline_001'));
    });
  });

  group('StemDownloadProgress', () {
    test('progress is 0.0 when the server sent no content length', () {
      const tick = StemDownloadProgress(
        url: 'u',
        receivedBytes: 512,
        totalBytes: 0,
      );

      expect(tick.progress, 0.0);
    });

    test('progress is received over total', () {
      const tick = StemDownloadProgress(
        url: 'u',
        receivedBytes: 25,
        totalBytes: 100,
      );

      expect(tick.progress, 0.25);
      expect(tick.isComplete, isFalse);
      expect(tick.hasError, isFalse);
    });

    test('isComplete is true once a local path is registered', () {
      const tick = StemDownloadProgress(
        url: 'u',
        receivedBytes: 100,
        totalBytes: 100,
        localPath: '/tmp/a.mp3',
      );

      expect(tick.isComplete, isTrue);
      expect(tick.progress, 1.0);
    });

    test('hasError is true when the transfer failed', () {
      const tick = StemDownloadProgress(
        url: 'u',
        receivedBytes: 0,
        totalBytes: 0,
        error: 'boom',
      );

      expect(tick.hasError, isTrue);
      expect(tick.isComplete, isFalse);
    });

    test('copyWith and equality', () {
      const tick = StemDownloadProgress(
        url: 'u',
        receivedBytes: 1,
        totalBytes: 4,
      );
      final done = tick.copyWith(receivedBytes: 4, localPath: '/tmp/a.mp3');

      expect(done.receivedBytes, 4);
      expect(done.isComplete, isTrue);
      expect(done.url, 'u');
      expect(tick.copyWith(), tick);
      expect(tick.hashCode, tick.copyWith().hashCode);
      expect(tick, isNot(done));
      expect(tick.toString(), contains('1/4'));
    });
  });
}

GenerationProgressState _state({
  PipelineStep currentStep = PipelineStep.startingUp,
  String? errorMessage,
}) {
  return GenerationProgressState(
    generationId: 'gen_pipeline_001',
    trackTitle: 'rave',
    genre: 'Gqom',
    currentStep: currentStep,
    errorMessage: errorMessage,
  );
}
