import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/social/domain/models/video_export_job.dart';
import 'package:vhunambi_client/features/social/presentation/providers/video_export_provider.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/video_export_modal.dart';

VideoExportJob _job() => const VideoExportJob(
      id: 'job_test_1',
      title: 'Makhado Sunrise',
      creatorHandle: '@makhadzi',
      genre: 'Amapiano',
      audioPath: 'https://cdn/x.mp3',
    );

void main() {
  testWidgets('renders badge, resolution chips, and watermark switch',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(body: VideoExportModal(job: _job())),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Native Video Muxer'), findsOneWidget);
    expect(find.byKey(const Key('export_badge')), findsOneWidget);
    expect(find.byKey(const Key('res_vertical9x16')), findsOneWidget);
    expect(find.byKey(const Key('res_square1x1')), findsOneWidget);
    expect(find.byKey(const Key('watermark_switch')), findsOneWidget);
  });

  testWidgets('rendering runs the mux loop and reaches 100%', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(body: VideoExportModal(job: _job())),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('export_render_btn')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(container.read(videoExportProvider).isCompleted, isTrue);
    expect(find.byKey(const Key('export_progress')), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);

    // Social share rail appears post-render.
    expect(find.byKey(const Key('share_tiktok_btn')), findsOneWidget);
    expect(find.byKey(const Key('share_instagramReels_btn')), findsOneWidget);
    expect(find.byKey(const Key('share_youtubeShorts_btn')), findsOneWidget);
    expect(find.byKey(const Key('share_cameraRoll_btn')), findsOneWidget);
  });

  testWidgets('tapping a share button executes shareTo', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(body: VideoExportModal(job: _job())),
        ),
      ),
    );
    await tester.pump();

    // Render first so sharing is permitted.
    await tester.tap(find.byKey(const Key('export_render_btn')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    await tester.tap(find.byKey(const Key('share_tiktok_btn')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(container.read(videoExportProvider).lastSharedTarget,
        SocialShareTarget.tiktok);
    // Drain share SnackBar timer.
    await tester.pump(const Duration(seconds: 5));
  });
}
