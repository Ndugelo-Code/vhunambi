import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_mobile_bottom_nav.dart';
import 'package:vhunambi_client/features/home/presentation/views/home_dashboard_view.dart';
import 'package:vhunambi_client/main.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 34: Mobile Bottom Navigation & Phosphor Iconography Convergence', () {
    testWidgets(
      'Finding NAV-001: VhunambiMobileBottomNav eliminates Material InkResponse highlight & splash flash glows',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              bottomNavigationBar: VhunambiMobileBottomNav(
                currentIndex: 1,
                onTap: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. All 5 tabs exist with explicit test keys
        expect(find.byKey(const Key('mobile_nav_tab_0')), findsOneWidget);
        expect(find.byKey(const Key('mobile_nav_tab_1')), findsOneWidget);
        expect(find.byKey(const Key('mobile_nav_tab_2')), findsOneWidget);
        expect(find.byKey(const Key('mobile_nav_tab_3')), findsOneWidget);
        expect(find.byKey(const Key('mobile_nav_tab_4')), findsOneWidget);

        // 2. InkResponse splash and highlight colors are strictly transparent (No "cracked screen" flash glow)
        final inkList = tester.widgetList<InkResponse>(
          find.byType(InkResponse),
        );
        expect(inkList.length, equals(5));
        for (final ink in inkList) {
          expect(ink.splashColor, equals(Colors.transparent));
          expect(ink.highlightColor, equals(Colors.transparent));
          expect(ink.hoverColor, equals(Colors.transparent));
        }
      },
    );

    testWidgets(
      'Finding NAV-002: Tapping tabs invokes onTap with the correct index',
      (tester) async {
        int selectedIndex = 1;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: StatefulBuilder(
              builder: (context, setState) {
                return Scaffold(
                  bottomNavigationBar: VhunambiMobileBottomNav(
                    currentIndex: selectedIndex,
                    onTap: (index) => setState(() => selectedIndex = index),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Home tab (index 0)
        await tester.tap(find.byKey(const Key('mobile_nav_tab_0')));
        await tester.pumpAndSettle();
        expect(selectedIndex, equals(0));

        // Tap Market tab (index 4)
        await tester.tap(find.byKey(const Key('mobile_nav_tab_4')));
        await tester.pumpAndSettle();
        expect(selectedIndex, equals(4));

        // Tap Create tab (index 2)
        await tester.tap(find.byKey(const Key('mobile_nav_tab_2')));
        await tester.pumpAndSettle();
        expect(selectedIndex, equals(2));
      },
    );

    testWidgets(
      'Finding NAV-003: Tapping active tab triggers onReselect without firing onTap',
      (tester) async {
        int tapCount = 0;
        int reselectCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              bottomNavigationBar: VhunambiMobileBottomNav(
                currentIndex: 1, // Explore active
                onTap: (_) => tapCount++,
                onReselect: (_) => reselectCount++,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap already active tab (Explore index 1)
        await tester.tap(find.byKey(const Key('mobile_nav_tab_1')));
        await tester.pumpAndSettle();

        expect(tapCount, equals(0));
        expect(reselectCount, equals(1));
      },
    );

    testWidgets(
      'Finding NAV-004: Center hero Create orb renders elevated gradient capsule with Phosphor sparkle',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              bottomNavigationBar: VhunambiMobileBottomNav(
                currentIndex: 0,
                onTap: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final createTab = find.byKey(const Key('mobile_nav_tab_2'));
        expect(createTab, findsOneWidget);

        // Verify sparkle icon is rendered inside Create tab
        final sparkleFinder = find.descendant(
          of: createTab,
          matching: find.byType(PhosphorIcon),
        );
        expect(sparkleFinder, findsOneWidget);
        final phosphorWidget = tester.widget<PhosphorIcon>(sparkleFinder);
        expect(phosphorWidget.icon, equals(AppIcons.navCreate));
      },
    );

    testWidgets(
      'Finding NAV-005: RootShell in main.dart hosts VhunambiMobileBottomNav and manages tab navigation',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: RootShell())),
        );
        await tester.pumpAndSettle();

        // RootShell mounts VhunambiMobileBottomNav
        expect(find.byType(VhunambiMobileBottomNav), findsOneWidget);

        // Boots on Explore tab (index 1)
        expect(find.byKey(const Key('mobile_nav_tab_1')), findsOneWidget);

        // Switch to Home tab (index 0)
        await tester.tap(find.byKey(const Key('mobile_nav_tab_0')));
        await tester.pumpAndSettle();

        // Home dashboard is visible
        expect(find.byType(HomeDashboardView), findsOneWidget);
      },
    );

    testWidgets(
      'Finding ICON-001: AppIcons design tokens provide soft, rounded Phosphor glyphs',
      (tester) async {
        expect(AppIcons.navHome, equals(PhosphorIconsRegular.house));
        expect(AppIcons.navHomeActive, equals(PhosphorIconsFill.house));
        expect(AppIcons.flame, equals(PhosphorIconsFill.flame));
        expect(AppIcons.coin, equals(PhosphorIconsFill.coin));
        expect(AppIcons.sparkle, equals(PhosphorIconsFill.sparkle));
        expect(AppIcons.songs, equals(PhosphorIconsFill.musicNotes));
        expect(AppIcons.releases, equals(PhosphorIconsFill.disc));
        expect(AppIcons.beatstore, equals(PhosphorIconsFill.slidersHorizontal));
      },
    );

    testWidgets(
      'Finding ICON-002: HomeDashboardView renders AppIcons vector tokens in streak and coin pills',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: Scaffold(body: HomeDashboardView())),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Streak pill renders flame vector icon
        final streakPill = find.byKey(const Key('home_streak_pill'));
        expect(streakPill, findsOneWidget);
        final flameIcon = find.descendant(
          of: streakPill,
          matching: find.byType(PhosphorIcon),
        );
        expect(flameIcon, findsOneWidget);

        // 2. Coins pill renders coin vector icon
        final coinsPill = find.byKey(const Key('home_coins_pill'));
        expect(coinsPill, findsOneWidget);
        final coinIcon = find.descendant(
          of: coinsPill,
          matching: find.byType(PhosphorIcon),
        );
        expect(coinIcon, findsOneWidget);
      },
    );

    testWidgets(
      'Finding NAV-006: Compact 360x800 mobile viewport renders VhunambiMobileBottomNav without RenderFlex overflows',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              bottomNavigationBar: VhunambiMobileBottomNav(
                currentIndex: 0,
                onTap: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(VhunambiMobileBottomNav), findsOneWidget);
        for (int i = 0; i < 5; i++) {
          final tabRect = tester.getRect(find.byKey(Key('mobile_nav_tab_$i')));
          expect(tabRect.height, greaterThanOrEqualTo(44.0));
          expect(tabRect.width, greaterThan(50.0));
        }
      },
    );
  });
}
