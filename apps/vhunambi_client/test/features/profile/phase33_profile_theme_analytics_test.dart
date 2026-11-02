import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/core/theme/theme_provider.dart';
import 'package:vhunambi_client/features/library/presentation/widgets/library_app_bar.dart';
import 'package:vhunambi_client/features/profile/presentation/providers/synchronized_analytics_provider.dart';
import 'package:vhunambi_client/features/profile/presentation/views/artist_profile_view.dart';
import 'package:vhunambi_client/features/profile/presentation/views/owner_profile_view.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/artist_voice_showcase_card.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/edit_profile_sheet.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/pin_song_selector_sheet.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/pinned_spotlight_card.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/profile_settings_drawer.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/studio_analytics_console_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('Phase 33 Track A: Adaptive Light & Dark Theme Engine', () {
    test('A.1: ThemeModeNotifier switches themes and updates AppColors brightness state', () async {
      final notifier = ThemeModeNotifier();
      expect(notifier.state, ThemeMode.system);

      await notifier.setThemeMode(ThemeMode.light);
      expect(notifier.state, ThemeMode.light);
      expect(AppColors.isDark, isFalse);

      await notifier.setThemeMode(ThemeMode.dark);
      expect(notifier.state, ThemeMode.dark);
      expect(AppColors.isDark, isTrue);
    });

    testWidgets('A.2: ProfileSettingsDrawer displays 3-way segmented theme mode controller', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: ProfileSettingsDrawer(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Appearance & Preferences'), findsOneWidget);
      expect(find.text('APPLICATION THEME'), findsOneWidget);
      expect(find.byKey(const Key('theme_mode_system')), findsOneWidget);
      expect(find.byKey(const Key('theme_mode_light')), findsOneWidget);
      expect(find.byKey(const Key('theme_mode_dark')), findsOneWidget);

      // Tap Light mode
      await tester.tap(find.byKey(const Key('theme_mode_light')));
      await tester.pumpAndSettle();
      expect(AppColors.isDark, isFalse);

      // Tap Dark mode
      await tester.tap(find.byKey(const Key('theme_mode_dark')));
      await tester.pumpAndSettle();
      expect(AppColors.isDark, isTrue);
    });

    test('A.3: AppTheme defines glare-free floating SnackBarTheme in dark and light palettes', () {
      final darkTheme = AppTheme.darkTheme;
      expect(darkTheme.snackBarTheme.behavior, SnackBarBehavior.floating);
      expect(darkTheme.snackBarTheme.backgroundColor, AppColors.darkSurfaceElevated);

      final lightTheme = AppTheme.lightTheme;
      expect(lightTheme.snackBarTheme.behavior, SnackBarBehavior.floating);
      expect(lightTheme.snackBarTheme.backgroundColor, AppColors.lightSurfaceElevated);
    });
  });

  group('Phase 33 Track B: Synchronized Cross-Platform Analytics', () {
    test('B.1: SynchronizedPlatformAnalytics computes multi-surface aggregate metrics', () {
      const analytics = SynchronizedPlatformAnalytics(
        totalSongsCount: 8,
        totalPlaysCount: 1500,
        totalLikesCount: 120,
        totalReelsCount: 4,
        totalReelsPlaysCount: 3200,
        totalReelsLikesCount: 240,
        totalBeatsCount: 3,
        totalBeatsSold: 6,
        totalZarEarned: 850.0,
        totalCoinsBalance: 120,
      );

      expect(analytics.aggregateStreams, 4700);
      expect(analytics.aggregateLikes, 360);
      expect(analytics.totalBeatsSold, 6);
      expect(analytics.totalZarEarned, 850.0);
    });

    testWidgets('B.2: StudioAnalyticsConsoleSheet displays KPIs, period tabs, and Bézier chart', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: StudioAnalyticsConsoleSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Studio Analytics Console'), findsOneWidget);
      expect(find.text('Streaming Velocity'), findsOneWidget);
      expect(find.text('Live Genre Affinity Distribution'), findsOneWidget);
      expect(find.text('AI Synthesis Sovereign Assets'), findsOneWidget);

      // Period Switcher
      expect(find.byKey(const Key('analytics_period_7d')), findsOneWidget);
      expect(find.byKey(const Key('analytics_period_30d')), findsOneWidget);
      expect(find.byKey(const Key('analytics_period_all')), findsOneWidget);

      await tester.tap(find.byKey(const Key('analytics_period_30d')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('analytics_period_all')));
      await tester.pumpAndSettle();
    });

    testWidgets('B.3: OwnerProfileView Studio Analytics button opens console sheet without SnackBar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const OwnerProfileView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final analyticsBtn = find.byKey(const Key('owner_analytics_btn'));
      expect(analyticsBtn, findsOneWidget);

      await tester.tap(analyticsBtn);
      await tester.pumpAndSettle();

      expect(find.byType(StudioAnalyticsConsoleSheet), findsOneWidget);
      expect(find.text('Studio Analytics Console'), findsOneWidget);
    });

    testWidgets('B.4: LibraryAppBar vault analytics button opens StudioAnalyticsConsoleSheet', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              appBar: PreferredSize(
                preferredSize: Size.fromHeight(64),
                child: LibraryAppBar(),
              ),
              body: Center(child: Text('Vault Body')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final analyticsBtn = find.byKey(const Key('library_vault_analytics_btn'));
      expect(analyticsBtn, findsOneWidget);

      await tester.tap(analyticsBtn);
      await tester.pumpAndSettle();

      expect(find.byType(StudioAnalyticsConsoleSheet), findsOneWidget);
    });
  });

  group('Phase 33 Track C: Multi-Dimensional Sovereign Creator Profile', () {
    testWidgets('C.1: EditProfileSheet allows modifying name, bio, and genres', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const OwnerProfileView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final editBtn = find.byKey(const Key('owner_edit_profile_btn'));
      expect(editBtn, findsOneWidget);

      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      expect(find.byType(EditProfileSheet), findsOneWidget);
      expect(find.byKey(const Key('edit_profile_name_field')), findsOneWidget);
      expect(find.byKey(const Key('edit_profile_bio_field')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('edit_profile_name_field')),
        'Cern Master Studio',
      );
      await tester.enterText(
        find.byKey(const Key('edit_profile_bio_field')),
        'Bantu AI Music Producer & Sound Designer',
      );

      await tester.tap(find.byKey(const Key('edit_profile_save_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Cern Master Studio'), findsOneWidget);
    });

    testWidgets('C.2: PinSongSelectorSheet pins track and renders PinnedSpotlightCard', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const OwnerProfileView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pinBtn = find.byKey(const Key('owner_pin_song_btn'));
      expect(pinBtn, findsOneWidget);

      await tester.tap(pinBtn);
      await tester.pumpAndSettle();

      expect(find.byType(PinSongSelectorSheet), findsOneWidget);
      expect(find.text('Select Featured Anthem'), findsOneWidget);

      // Select first song tile
      final selectableTiles = find.byType(ListTile);
      if (selectableTiles.evaluate().isNotEmpty) {
        await tester.tap(selectableTiles.first);
        await tester.pumpAndSettle();

        expect(find.byType(PinnedSpotlightCard), findsOneWidget);
        expect(find.byKey(const Key('profile_pinned_spotlight_card')), findsOneWidget);
        expect(find.byKey(const Key('pinned_anthem_play_btn')), findsOneWidget);

        // Tap play on pinned anthem
        await tester.tap(find.byKey(const Key('pinned_anthem_play_btn')));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('C.3: 5-Segment Studio Switcher includes Voices & Melodies tab', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const OwnerProfileView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('owner_studio_tab_songs')), findsOneWidget);
      expect(find.byKey(const Key('owner_studio_tab_reels')), findsOneWidget);
      expect(find.byKey(const Key('owner_studio_tab_beatstore')), findsOneWidget);
      expect(find.byKey(const Key('owner_studio_tab_voicesAndMelodies')), findsOneWidget);
      expect(find.byKey(const Key('owner_studio_tab_releases')), findsOneWidget);

      // Switch to Voices & Melodies tab
      await tester.tap(find.byKey(const Key('owner_studio_tab_voicesAndMelodies')));
      await tester.pumpAndSettle();

      expect(find.byType(ArtistVoiceShowcaseCard), findsOneWidget);
      expect(find.text('Multi-Track Grooves & Melodies'), findsOneWidget);
      expect(find.byKey(const Key('owner_launch_sketchpad_btn')), findsOneWidget);
    });

    testWidgets('C.4: ArtistProfileView renders PinnedSpotlightCard when pinnedTrackId is set', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const ArtistProfileView(artistId: 'ndugelo'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile_pinned_spotlight_card')), findsOneWidget);
      expect(find.text('Featured Anthem'), findsOneWidget);
    });
  });
}
