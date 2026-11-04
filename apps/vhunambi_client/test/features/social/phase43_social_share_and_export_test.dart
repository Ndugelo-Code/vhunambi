import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/content_studio/presentation/widgets/export_action_sheet.dart';
import 'package:vhunambi_client/features/landing/presentation/widgets/landing_footer.dart';
import 'package:vhunambi_client/features/landing/presentation/widgets/legal_transparency_modal.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_enums.dart';
import 'package:vhunambi_client/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:vhunambi_client/features/social/domain/models/video_export_job.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/video_export_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testJob = const VideoExportJob(
    id: 'job_43_test',
    title: 'Venda Midnight Groove',
    creatorHandle: 'makhadzi',
    genre: 'Afro-House',
    audioPath: '/audio/test.mp3',
  );

  group('Phase 43: Universal Social Share, Gallery Export & Legal Transparency', () {
    testWidgets('REQ-LEGAL-01 & 02: LegalTransparencyModal renders 85% royalty split and Bantu protections', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: LegalTransparencyModal(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('legal_transparency_modal')), findsOneWidget);
      expect(find.textContaining('85% Creator Sovereign Royalties'), findsOneWidget);
      expect(find.textContaining('Bantu Heritage & Voice Attribution Protections'), findsOneWidget);
      expect(find.textContaining('Direct South African Banking (SARB Compliant)'), findsOneWidget);
      expect(find.byKey(const Key('legal_modal_acknowledge_btn')), findsOneWidget);
    });

    testWidgets('REQ-LEGAL-01: LandingFooter triggers LegalTransparencyModal on legal link tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: LandingFooter(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final termsLink = find.byKey(const Key('footer_link_terms_of_service'));
      expect(termsLink, findsOneWidget);

      await tester.tap(termsLink);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('legal_transparency_modal')), findsOneWidget);
    });

    testWidgets('REQ-VID-01 & 02: VideoExportModal renders Phosphor syndication buttons and logs notification on share', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: VideoExportModal(job: testJob),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('export_render_btn')), findsOneWidget);

      // Render video
      await tester.tap(find.byKey(const Key('export_render_btn')));
      await tester.pumpAndSettle();

      // Verify share buttons exist
      expect(find.byKey(const Key('share_tiktok_btn')), findsOneWidget);
      expect(find.byKey(const Key('share_instagramReels_btn')), findsOneWidget);
      expect(find.byKey(const Key('share_youtubeShorts_btn')), findsOneWidget);
      expect(find.byKey(const Key('share_cameraRoll_btn')), findsOneWidget);

      // Tap TikTok share
      await tester.tap(find.byKey(const Key('share_tiktok_btn')));
      await tester.pumpAndSettle();

      final notifs = container.read(notificationsProvider);
      expect(
        notifs.any((n) =>
            n.title == 'Video Export Shared' &&
            n.category == NotificationCategory.creatorActivity &&
            n.message.contains('TikTok')),
        isTrue,
      );
    });

    testWidgets('REQ-EXP-01: ExportActionSheet notifies on share to socials', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: ExportActionSheet(
                isExporting: false,
                progress: 1.0,
                exportedFilePath: '/vault/reels/makhadzi_reel_1080p.mp4',
                onDismiss: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('export_share_to_socials_btn')), findsOneWidget);

      // Tap Share to Socials
      await tester.tap(find.byKey(const Key('export_share_to_socials_btn')));
      await tester.pumpAndSettle();

      final notifs = container.read(notificationsProvider);
      expect(
        notifs.any((n) =>
            n.title == 'Reel Shared to Socials' &&
            n.category == NotificationCategory.creatorActivity),
        isTrue,
      );
    });

    testWidgets('REQ-EXP-02: ExportActionSheet notifies on save to device', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: ExportActionSheet(
                isExporting: false,
                progress: 1.0,
                exportedFilePath: '/vault/reels/makhadzi_reel_1080p.mp4',
                onDismiss: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('export_save_to_device_btn')), findsOneWidget);

      // Tap Save to Device
      await tester.tap(find.byKey(const Key('export_save_to_device_btn')));
      await tester.pumpAndSettle();

      final notifs = container.read(notificationsProvider);
      expect(
        notifs.any((n) =>
            n.title == 'Reel Saved to Gallery' &&
            n.category == NotificationCategory.creatorActivity),
        isTrue,
      );
    });
  });
}
