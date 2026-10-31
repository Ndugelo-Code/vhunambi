import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_mobile_bottom_nav.dart';

void main() {
  group('VhunambiMobileBottomNav Widget Tests', () {
    testWidgets('Renders all 5 tabs with semantic labels, keys, and Phosphor icons', (tester) async {
      int tappedIndex = -1;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            bottomNavigationBar: VhunambiMobileBottomNav(
              currentIndex: 1, // Explore active
              onTap: (index) => tappedIndex = index,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify all 5 tab keys exist
      expect(find.byKey(const Key('mobile_nav_tab_0')), findsOneWidget);
      expect(find.byKey(const Key('mobile_nav_tab_1')), findsOneWidget);
      expect(find.byKey(const Key('mobile_nav_tab_2')), findsOneWidget);
      expect(find.byKey(const Key('mobile_nav_tab_3')), findsOneWidget);
      expect(find.byKey(const Key('mobile_nav_tab_4')), findsOneWidget);

      // Verify labels
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Explore'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);
      expect(find.text('Market'), findsOneWidget);

      // Verify zero flash glow: InkResponse has transparent splashColor and highlightColor
      final inkResponses = tester.widgetList<InkResponse>(find.byType(InkResponse));
      expect(inkResponses.length, equals(5));
      for (final ink in inkResponses) {
        expect(ink.splashColor, equals(Colors.transparent));
        expect(ink.highlightColor, equals(Colors.transparent));
      }

      // Tap Home tab (index 0)
      await tester.tap(find.byKey(const Key('mobile_nav_tab_0')));
      expect(tappedIndex, equals(0));

      // Tap Market tab (index 4)
      await tester.tap(find.byKey(const Key('mobile_nav_tab_4')));
      expect(tappedIndex, equals(4));
    });

    testWidgets('Tapping the already active tab invokes onReselect without invoking onTap', (tester) async {
      int tappedIndex = -1;
      int reselectedIndex = -1;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            bottomNavigationBar: VhunambiMobileBottomNav(
              currentIndex: 1, // Explore active
              onTap: (index) => tappedIndex = index,
              onReselect: (index) => reselectedIndex = index,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap active tab (index 1)
      await tester.tap(find.byKey(const Key('mobile_nav_tab_1')));
      expect(tappedIndex, equals(-1)); // Not invoked
      expect(reselectedIndex, equals(1)); // Reselected invoked
    });
  });
}

