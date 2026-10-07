import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/studio/data/services/fake_generation_socket_service.dart';
import 'package:vhunambi_client/features/studio/data/services/generation_socket_service.dart';
import 'package:vhunambi_client/features/studio/domain/models/generation_pipeline_state.dart';
import 'package:vhunambi_client/features/track/domain/models/track_entity.dart';

/// T10.2 — WebSocket bridge suite.
///
/// The production service is only inspected through its pure configuration
/// surface: the suite never opens a real socket (Phase 10 invariant #4).
TrackEntity _track() => TrackEntity(
      id: 'trk_pipeline_001',
      title: 'rave',
      genre: 'Gqom',
      duration: const Duration(minutes: 3, seconds: 29),
      masterMp3Url: 'https://cdn.vhunambi.com/masters/trk_pipeline_001.mp3',
    );

void main() {
  group('GenerationSocketService configuration', () {
    test('targets the production wss endpoint with the documented timeouts', () {
      expect(
        GenerationSocketService.baseUrl,
        'wss://api.vhunambi.com/ws/generation',
      );
      expect(
        GenerationSocketService.pingInterval,
        const Duration(seconds: 25),
      );
      expect(GenerationSocketService.pongTimeout, const Duration(seconds: 10));
      expect(GenerationSocketService.maxAttempts, 5);
    });

    test('exponential backoff grows 1/2/4/8/16 seconds', () {
      expect(
        GenerationSocketService.backoffForAttempt(1),
        const Duration(seconds: 1),
      );
      expect(
        GenerationSocketService.backoffForAttempt(2),
        const Duration(seconds: 2),
      );
      expect(
        GenerationSocketService.backoffForAttempt(3),
        const Duration(seconds: 4),
      );
      expect(
        GenerationSocketService.backoffForAttempt(4),
        const Duration(seconds: 8),
      );
      expect(
        GenerationSocketService.backoffForAttempt(5),
        const Duration(seconds: 16),
      );
    });

    test('a fresh bridge reports disconnected and tears down safely', () async {
      final service = GenerationSocketService();

      expect(service.isConnected, isFalse);
      expect(service.activeGenerationId, isNull);
      expect(service.reconnectAttempts, 0);

      // No socket was ever opened: disconnect/dispose must be inert.
      await service.disconnect();
      await service.dispose();
      expect(service.isConnected, isFalse);
    });
  });

  group('FakeGenerationSocketService', () {
    test('emits the four canonical pipeline frames in order', () async {
      final fake = FakeGenerationSocketService(stepDelay: Duration.zero);

      final events = await fake.connect('gen_abc123').toList();

      expect(events, hasLength(4));
      expect(
        events.map((event) => event.step).toList(),
        <PipelineStep>[
          PipelineStep.startingUp,
          PipelineStep.writingLyrics,
          PipelineStep.producingBeat,
          PipelineStep.ready,
        ],
      );
      expect(
        events.map((event) => event.progressPercent).toList(),
        <double>[0.15, 0.40, 0.72, 1.00],
      );
      expect(
        events.every((event) => event.generationId == 'gen_abc123'),
        isTrue,
      );
      expect(events.last.statusMessage, 'Your song is ready!');
    });

    test('reports connected for the duration of the session', () async {
      final fake = FakeGenerationSocketService(stepDelay: Duration.zero);

      final subscription = fake.connect('gen_1').listen((_) {});
      expect(fake.isConnected, isTrue);

      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      await fake.disconnect();
      expect(fake.isConnected, isFalse);
    });

    test('carries the completed track and lyrics on the terminal frame',
        () async {
      final fake = FakeGenerationSocketService(
        stepDelay: Duration.zero,
        completedTrack: _track(),
        generatedLyrics: '[Verse 1]\nNight breaks...',
      );

      final events = await fake.connect('gen_1').toList();

      expect(events[1].generatedLyrics, contains('Night breaks'));
      expect(events.last.hasCompletedTrack, isTrue);
      expect(events.last.completedTrack?.id, 'trk_pipeline_001');
      expect(events.last.completedTrack?.masterMp3Url, contains('masters'));
    });

    test('can fail a session at a chosen step', () async {
      final fake = FakeGenerationSocketService(
        stepDelay: Duration.zero,
        failAtStep: PipelineStep.producingBeat,
      );

      final events = await fake.connect('gen_1').toList();

      expect(events, hasLength(3));
      expect(events.last.step, PipelineStep.failed);
      expect(events.last.progressPercent, 0.0);
      expect(events.last.error, 'Synthesis worker crashed.');
      expect(events.last.hasCompletedTrack, isFalse);
    });

    test('canonicalSteps exposes the deterministic sequence', () {
      final steps = FakeGenerationSocketService.canonicalSteps('gen_9');

      expect(steps, hasLength(4));
      expect(steps.first.stepIndex, 1);
      expect(steps.last.stepIndex, 4);
      expect(steps[2].step, PipelineStep.producingBeat);
    });

    test('a disconnect stops an in-flight session', () async {
      final fake = FakeGenerationSocketService(
        stepDelay: const Duration(milliseconds: 10),
      );

      final events = <PipelineSocketEvent>[];
      final subscription = fake.connect('gen_1').listen(events.add);

      await Future<void>.delayed(const Duration(milliseconds: 15));
      await fake.disconnect();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await subscription.cancel();

      expect(events.length, lessThan(4));
    });

    test('records every generation id it was asked to connect', () async {
      final fake = FakeGenerationSocketService(stepDelay: Duration.zero);

      await fake.connect('gen_alpha').toList();
      await fake.connect('gen_beta').toList();

      expect(fake.connectCount, 2);
      expect(fake.connectedGenerationIds, <String>['gen_alpha', 'gen_beta']);
    });
  });
}
