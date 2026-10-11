import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/social/domain/models/video_export_job.dart';
import 'package:vhunambi_client/features/social/presentation/providers/video_export_provider.dart';

void main() {
  group('VideoExportNotifier & videoExportProvider', () {
    const testJob = VideoExportJob(
      id: 'job_01',
      title: 'Makhado Sunrise',
      creatorHandle: 'makhadzi',
      genre: 'Amapiano',
      audioPath: '/vault/bounces/master_mix_01.wav',
    );

    test('prepareJob synthesizes viral hashtags and creator attribution', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(videoExportProvider.notifier);
      notifier.prepareJob(testJob);

      final state = container.read(videoExportProvider);
      expect(state.activeJob, equals(testJob));
      expect(state.status, equals(VideoExportStatus.idle));
      expect(state.generatedCaption, contains('"Makhado Sunrise"'));
      expect(state.generatedCaption, contains('@makhadzi'));
      expect(state.generatedCaption, contains('#Amapiano'));
      expect(state.generatedCaption, contains('#Vhunambi'));
      expect(state.generatedCaption, contains('#LogDrum'));
    });

    test('resolution, FPS, and watermark mutators update active job', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(videoExportProvider.notifier);
      notifier.prepareJob(testJob);

      notifier.setResolution(VideoExportResolution.square1x1);
      expect(
        container.read(videoExportProvider).activeJob!.resolution,
        equals(VideoExportResolution.square1x1),
      );

      notifier.setFps(30);
      expect(
        container.read(videoExportProvider).activeJob!.fps,
        equals(30),
      );

      notifier.toggleWatermark(false);
      expect(
        container.read(videoExportProvider).activeJob!.includeHolographicWatermark,
        isFalse,
      );
    });

    test('startMuxing executes hardware rendering loop and sets outputPath', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(videoExportProvider.notifier);
      notifier.prepareJob(testJob);

      final path = await notifier.startMuxing();

      final state = container.read(videoExportProvider);
      expect(state.status, equals(VideoExportStatus.completed));
      expect(state.progress, equals(1.0));
      expect(path, isNotNull);
      expect(path, contains('/vault/videos/vhunambi_reel_'));
      expect(state.outputPath, equals(path));
    });

    test('startMuxing without active job sets failure status', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(videoExportProvider.notifier);
      final path = await notifier.startMuxing();

      final state = container.read(videoExportProvider);
      expect(path, isNull);
      expect(state.status, equals(VideoExportStatus.failed));
      expect(state.errorMessage, isNotNull);
    });

    test('shareTo requires completed video or flags error', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(videoExportProvider.notifier);
      notifier.prepareJob(testJob);

      // Attempt share before muxing
      final failedShare = await notifier.shareTo(SocialShareTarget.tiktok);
      expect(failedShare, isFalse);
      expect(container.read(videoExportProvider).errorMessage, isNotNull);

      // Now complete muxing
      await notifier.startMuxing();

      // Successful share
      final successShare = await notifier.shareTo(SocialShareTarget.instagramReels);
      expect(successShare, isTrue);
      expect(
        container.read(videoExportProvider).lastSharedTarget,
        equals(SocialShareTarget.instagramReels),
      );
    });
  });
}
