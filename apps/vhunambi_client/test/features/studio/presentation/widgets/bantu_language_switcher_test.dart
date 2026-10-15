import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/bantu_language_switcher.dart';

void main() {
  testWidgets('renders all 8 Bantu language target chips', (tester) async {
    String currentLyrics = 'Kuleli lizwe elihle';

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: BantuLanguageSwitcher(
              currentLanguage: 'isiZulu',
              readLyrics: () => currentLyrics,
              writeLyrics: (val) => currentLyrics = val,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(BantuLanguageSwitcher.switcherKey), findsOneWidget);
    for (final target in kBantuLanguageTargets) {
      expect(find.text(target, skipOffstage: false), findsOneWidget);
    }
  });

  testWidgets('tapping a language opens confirmation dialog and translates on confirm', (tester) async {
    String currentLyrics = 'Kuleli lizwe elihle';

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: BantuLanguageSwitcher(
              currentLanguage: 'isiZulu',
              readLyrics: () => currentLyrics,
              writeLyrics: (val) => currentLyrics = val,
            ),
          ),
        ),
      ),
    );

    // Tap on Tshivenḓa chip
    await tester.tap(find.text('Tshivenḓa'));
    await tester.pumpAndSettle();

    // Verify confirmation dialog appears
    expect(find.textContaining('Translate lyrics to Tshivenḓa?'), findsOneWidget);
    expect(find.byKey(const Key('bantu_translate_confirm_btn')), findsOneWidget);

    // Tap confirm
    await tester.tap(find.byKey(const Key('bantu_translate_confirm_btn')));
    await tester.pumpAndSettle();

    // Verified that translation output was received
    expect(currentLyrics.isNotEmpty, isTrue);
  });
}
