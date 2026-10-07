import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/studio/data/services/fake_generation_socket_service.dart';
import 'package:vhunambi_client/features/studio/data/services/fake_stem_download_service.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/features/studio/domain/models/generation_pipeline_state.dart';
import 'package:vhunambi_client/features/studio/domain/services/i_generation_socket_service.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/generation_pipeline_providers.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/stem_download_provider.dart';
import 'package:vhunambi_client/features/track/domain/models/track_entity.dart';

/// T10.3 — Pipeline provider layer suite (socket + downloader always faked).
TrackEntity _track({String id = 'trk_pipeline_001', String title = 'rave'}) => TrackEntity(
      id: id,
      title: title,
      genre: 'Gqom',
      duration: const Duration(minutes: 3, seconds: 29),
      masterMp3Url: 'https://cdn.vhunambi.com/masters/$id.mp3',
    );

ProviderContainer _container({
  IGenerationSocketService? socket,
  FakeStemDownloadService? downloader,
}) {
  final container = ProviderContainer(
    overrides: <Override>[
      socketServiceProvider.overrideWithValue(
        socket ??
            FakeGenerationSocketService(
              stepDelay: Duration.zero,
              completedTrack: _track(),
              generatedLyrics: '[Verse 1]\nNight breaks through...',
            ),
      ),
      stemDownloadServiceProvider.overrideWithValue(
        downloader ?? FakeStemDownloadService(stepDelay: Duration.zero),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Socket that fails before delivering a single frame.
class _ErroringSocket implements IGenerationSocketService {
  @override
  bool get isConnected => false;

  @override
  Stream<PipelineSocketEvent> connect(String generationId) =>
      Stream<PipelineSocketEvent>.error(Exception('socket down'));

  @override
  Future<void> disconnect() async {}
}

Future<void> _start(ProviderContainer container, String id) {
  return container.read(generationProgressProvider.notifier).startGeneration(
        generationId: id,
        trackTitle: 'rave',
        genre: 'Gqom',
      );
}

void main() {
  test('initial state is null and notifications start empty', () {
    final container = _container();

    expect(container.read(generationProgressProvider), isNull);
    expect(container.read(notificationsProvider), isEmpty);
    expect(
      container.read(generationProgressProvider.notifier).isGenerating,
      isFalse,
    );
  });

  test('startGeneration seeds the first synthesis frame', () async {
    final container = _container();

    await _start(container, 'gen_abc123');

    final state = container.read(generationProgressProvider);
    expect(state, isNotNull);
    expect(state!.generationId, 'gen_abc123');
    expect(state.trackTitle, 'rave');
    expect(state.genre, 'Gqom');
    expect(state.currentStep, PipelineStep.startingUp);
    expect(state.isGenerating, isTrue);
  });

  test('walks the pipeline to ready and mirrors every frame', () async {
    final container = _container();

    await _start(container, 'gen_abc123');
    await _settle();

    final state = container.read(generationProgressProvider)!;
    expect(state.currentStep, PipelineStep.ready);
    expect(state.progressPercent, 1.0);
    expect(state.isReady, isTrue);
    expect(state.isGenerating, isFalse);
    expect(state.statusMessage, 'Your song is ready!');
    expect(state.generatedLyrics, contains('Night breaks'));
    expect(state.completedTrack?.id, 'trk_pipeline_001');
  });

  test('binds the socket with the requested generation id', () async {
    final socket = FakeGenerationSocketService(stepDelay: Duration.zero);
    final container = _container(socket: socket);

    await _start(container, 'gen_abc123');
    await _settle();

    expect(socket.connectedGenerationIds, <String>['gen_abc123']);
    expect(socket.connectCount, 1);
  });

  test('prepends a completion notification with the documented pattern',
      () async {
    final container = _container();

    await _start(container, 'gen_abc123');
    await _settle();

    final notifications = container.read(notificationsProvider);
    expect(notifications, hasLength(1));
    expect(notifications.single.title, 'Your song "rave" is ready!');
    expect(notifications.single.targetTrackId, 'trk_pipeline_001');
    expect(notifications.single.message, 'Gqom • 3:29');
    expect(notifications.single.isRead, isFalse);
  });

  test('starts the master download on completion', () async {
    final downloader = FakeStemDownloadService(stepDelay: Duration.zero);
    final container = _container(downloader: downloader);

    await _start(container, 'gen_abc123');
    await _settle();

    expect(
      downloader.downloadedUrls,
      <String>['https://cdn.vhunambi.com/masters/trk_pipeline_001.mp3'],
    );
  });

  test('keeps notifications newest-first across sessions', () async {
    final container = _container();

    await _start(container, 'gen_1');
    await _settle();
    await container.read(generationProgressProvider.notifier).startGeneration(
          generationId: 'gen_2',
          trackTitle: 'second',
          genre: 'Amapiano',
        );
    await _settle();

    final notifications = container.read(notificationsProvider);
    expect(notifications, hasLength(2));
    expect(notifications.first.title, 'Your song "second" is ready!');
  });

  test('a failed frame carries the error message into the state', () async {
    final container = _container(
      socket: FakeGenerationSocketService(
        stepDelay: Duration.zero,
        failAtStep: PipelineStep.producingBeat,
      ),
    );

    await _start(container, 'gen_fail');
    await _settle();

    final state = container.read(generationProgressProvider)!;
    expect(state.currentStep, PipelineStep.failed);
    expect(state.hasFailed, isTrue);
    expect(state.errorMessage, 'Synthesis worker crashed.');
    expect(container.read(notificationsProvider), isEmpty);
  });

  test('a socket stream error marks the pipeline failed and counts', () async {
    final container = _container(socket: _ErroringSocket());
    final notifier = container.read(generationProgressProvider.notifier);

    await _start(container, 'gen_err');
    await _settle();

    final state = container.read(generationProgressProvider)!;
    expect(state.currentStep, PipelineStep.failed);
    expect(state.statusMessage, 'Connection lost.');
    expect(state.errorMessage, contains('socket down'));
    expect(notifier.errorCount, 1);
  });

  test('reset clears the session and disconnects the socket', () async {
    final socket = FakeGenerationSocketService(stepDelay: Duration.zero);
    final container = _container(socket: socket);
    final notifier = container.read(generationProgressProvider.notifier);

    await _start(container, 'gen_abc123');
    await _settle();
    expect(socket.isConnected, isFalse);

    notifier.reset();

    expect(container.read(generationProgressProvider), isNull);
    expect(notifier.isGenerating, isFalse);
  });

  test('dispose disconnects the active socket', () async {
    final socket = FakeGenerationSocketService(
      stepDelay: const Duration(seconds: 5),
    );
    final container = _container(socket: socket);

    await _start(container, 'gen_abc123');
    expect(socket.isConnected, isTrue);

    container.dispose();

    expect(socket.isConnected, isFalse);
  });

  test('submitAndStartGeneration seeds optimistic state and auto-plays ready track', () async {
    final socket = FakeGenerationSocketService(
      stepDelay: Duration.zero,
      completedTrack: _track(id: 'trk_heritage_001', title: 'Heritage Anthem'),
    );
    final container = _container(socket: socket);
    final notifier = container.read(generationProgressProvider.notifier);

    await notifier.submitAndStartGeneration(
      trackTitle: 'Heritage Anthem',
      genre: 'Amapiano',
      language: 've',
      lyrics: '[Intro]\nNdi khou vha fhululedza',
    );
    await _settle();

    final state = container.read(generationProgressProvider)!;
    expect(state.currentStep, PipelineStep.ready);
    expect(state.isReady, isTrue);
    expect(state.completedTrack, isNotNull);

    // Verify auto-play loaded into persistent player
    final playerState = container.read(playerStateProvider);
    expect(playerState.currentTrack?.title, 'Heritage Anthem');
  });
}
