import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/studio/domain/models/prompt_enhancement_result.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/prompt_intelligence_overlay.dart';

void main() {
  const testResult = PromptEnhancementResult(
    rawPrompt: 'A soulful maskandi song',
    enhancedPrompt: 'A soulful maskandi song with acoustic Zulu guitar and steady tempo',
    suggestedOverrides: {
      'genre': 'Maskandi',
      'language': 'isiZulu',
      'mood': 'Melancholic',
    },
  );

  testWidgets('renders overlay with enhanced prompt and detected suggestion chips', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: PromptIntelligenceOverlay(
            result: testResult,
            onApplyOverride: (field, val) {},
            onDismissSuggestion: (field) {},
            onApplyAll: () {},
            onDismiss: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(PromptIntelligenceOverlay.overlayKey), findsOneWidget);
    expect(find.text('AI refined your prompt'), findsOneWidget);
    expect(find.text(testResult.enhancedPrompt), findsOneWidget);
    expect(find.byKey(const Key('autofill_chip_genre')), findsOneWidget);
    expect(find.byKey(const Key('autofill_chip_language')), findsOneWidget);
    expect(find.byKey(const Key('autofill_chip_mood')), findsOneWidget);
    expect(find.byKey(const Key('prompt_intelligence_apply_all')), findsOneWidget);
  });

  testWidgets('tapping autofill chip triggers onApplyOverride callback', (tester) async {
    String? appliedField;
    Object? appliedValue;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: PromptIntelligenceOverlay(
            result: testResult,
            onApplyOverride: (field, val) {
              appliedField = field;
              appliedValue = val;
            },
            onDismissSuggestion: (field) {},
            onApplyAll: () {},
            onDismiss: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('autofill_chip_genre')));
    await tester.pumpAndSettle();

    expect(appliedField, 'genre');
    expect(appliedValue, 'Maskandi');
  });

  testWidgets('tapping autofill chip close button triggers onDismissSuggestion', (tester) async {
    String? dismissedField;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: PromptIntelligenceOverlay(
            result: testResult,
            onApplyOverride: (field, val) {},
            onDismissSuggestion: (field) => dismissedField = field,
            onApplyAll: () {},
            onDismiss: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('autofill_chip_dismiss_language')));
    await tester.pumpAndSettle();

    expect(dismissedField, 'language');
  });

  testWidgets('tapping Apply All triggers onApplyAll callback', (tester) async {
    var appliedAll = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: PromptIntelligenceOverlay(
            result: testResult,
            onApplyOverride: (field, val) {},
            onDismissSuggestion: (field) {},
            onApplyAll: () => appliedAll = true,
            onDismiss: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('prompt_intelligence_apply_all')));
    await tester.pumpAndSettle();

    expect(appliedAll, isTrue);
  });

  testWidgets('tapping close icon triggers onDismiss callback', (tester) async {
    var dismissed = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: PromptIntelligenceOverlay(
            result: testResult,
            onApplyOverride: (field, val) {},
            onDismissSuggestion: (field) {},
            onApplyAll: () {},
            onDismiss: () => dismissed = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('prompt_intelligence_dismiss')));
    await tester.pumpAndSettle();

    expect(dismissed, isTrue);
  });
}
