import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/features/onboarding/presentation/views/splash_view.dart';

void main() {
  group('SplashView Widget Tests', () {
    testWidgets('renders brand wordmark, logo, and Tshivenḓa motto',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SplashView(
              duration: Duration(seconds: 10), // Long duration so it stays on splash
            ),
          ),
        ),
      );

      // Trigger first animation frame
      await tester.pump();

      expect(find.text('VHUNAMBI'), findsOneWidget);
      expect(find.text('The talent to sing • Tshivenḓa'), findsOneWidget);
      expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Clean up by pumping past the timer
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('invokes onFinished callback when timer completes',
        (WidgetTester tester) async {
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
