import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/features/studio/presentation/views/studio_view.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';

void main() {
  testWidgets('StudioView renders complete Studio Cockpit interface',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const StudioView(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Sticky Top Bar
    expect(find.text('Studio'), findsOneWidget);
    expect(find.text('10 left'), findsOneWidget);

    // Verify Top Prompt Input Section
    expect(find.text('Describe your song'), findsOneWidget);
    expect(find.text('Inspire Me'), findsOneWidget);

    // Verify Reference Audio Accordion
    expect(find.text('Reference Audio (optional)'), findsOneWidget);

    // Verify Genre & Multilingual Selector Accordions
    expect(find.text('Genre'), findsOneWidget);
    expect(find.text('Amapiano'), findsWidgets);
    expect(find.text('Language'), findsOneWidget);

    // Verify Advanced Options Accordion
    expect(find.text('Advanced Options'), findsOneWidget);

    // Verify Sticky Action Deck CTA
    expect(find.text('Write Lyrics First'), findsOneWidget);
    expect(find.text('Public'), findsOneWidget);
  });

  testWidgets('Inspire Me populates prompt TextField with scenario',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1024);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const StudioView(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap "Inspire Me"
    await tester.tap(find.text('Inspire Me'));
    await tester.pumpAndSettle();

    // The textfield should now have text
    final textField = tester.widget<TextField>(find.byType(TextField).first);
    expect(textField.controller?.text, isNotEmpty);
  });
}
