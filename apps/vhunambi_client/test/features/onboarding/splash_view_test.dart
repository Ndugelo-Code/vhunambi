import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/constants/app_assets.dart';
import 'package:vhunambi_client/features/onboarding/presentation/views/splash_view.dart';

void main() {
  group('SplashView Widget Tests (Phase 68.5 Cinema Splash)', () {
    testWidgets(
      'renders blended emblem, 3-word motto without duplicate VHUNAMBI text, progress sweep, and compact Madoni attribution',
      (WidgetTester tester) async {
        expect(
          AppAssets.madoniSoftwareLogo,
          equals('assets/branding/madonisoftware/madoni_logo.png'),
        );

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: SplashView(
                duration: Duration(seconds: 10),
              ),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 500));

        // Duplicate 'VHUNAMBI' text removed because splash_hero backdrop carries the wordmark
        expect(find.text('VHUNAMBI'), findsNothing);
        expect(find.byKey(const Key('splash_brand_emblem')), findsOneWidget);
        expect(find.text('Music • Create • Socialize'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(
          find.byKey(const Key('splash_madoni_attribution')),
          findsOneWidget,
        );
        expect(find.text('A PRODUCT OF'), findsOneWidget);
        expect(find.byKey(const Key('splash_madoni_logo')), findsOneWidget);

        final madoniLogo = tester.widget<Image>(
          find.byKey(const Key('splash_madoni_logo')),
        );
        expect(madoniLogo.height, lessThanOrEqualTo(48));

        // Clean up by pumping past the timer
        await tester.pump(const Duration(seconds: 11));
      },
    );

    testWidgets('invokes onFinished callback when timer completes', (
      WidgetTester tester,
    ) async {
      bool finishedCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: SplashView(
              duration: const Duration(milliseconds: 100),
              onFinished: () {
                finishedCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.pump();
      expect(finishedCalled, isFalse);

      await tester.pump(const Duration(milliseconds: 150));
      expect(finishedCalled, isTrue);
    });
  });
}
