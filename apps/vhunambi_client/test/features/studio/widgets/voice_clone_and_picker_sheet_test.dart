import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/bantu_voice_deck.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/vocal_identity_picker_sheet.dart';
import 'package:vhunambi_client/features/studio/presentation/widgets/voice_clone_recorder_sheet.dart';

void main() {
  group('Phase 26 — VoiceCloneRecorderSheet & VocalIdentityPickerSheet Widgets', () {
    testWidgets(
        'VoiceCloneRecorderSheet displays 3 scored calibration lines and synthesizes Cloned Voice DNA',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 760,
                child: VoiceCloneRecorderSheet(
                  initialLyrics:
                      'Ndaa! Mbilu yanga i khou tshina kha ngoma dza Vhunambi\n'
                      'Yebo! Hlala phansi ulalele isigqi saseThekwini\n'
                      'Ahee! Kha vha ḓe ri ṱangane tshilombe tsha Amapiano',
                  language: 'Tshivenḓa',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('voice_clone_recorder_sheet')), findsOneWidget);
      expect(find.byKey(const Key('calibration_line_0')), findsOneWidget);
      expect(find.byKey(const Key('calibration_line_1')), findsOneWidget);
      expect(find.byKey(const Key('calibration_line_2')), findsOneWidget);

      // Enter custom voice clone name
      await tester.enterText(
        find.byKey(const Key('voice_clone_name_input')),
        'Thohoyandou Lead Clone',
      );
      await tester.pump();

      // Start recording
      await tester.tap(find.byKey(const Key('voice_clone_record_toggle_btn')));
      await tester.pump();
      expect(find.text('Stop Recording'), findsOneWidget);

      // Finalize voice clone DNA
      await tester.tap(find.byKey(const Key('voice_clone_finalize_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('voice_clone_ready_badge')), findsOneWidget);
      expect(find.textContaining('Thohoyandou Lead Clone'), findsWidgets);
    });

    testWidgets(
        'VocalIdentityPickerSheet filters 24-voice catalog and switches to My Cloned Voices tab',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 780,
                child: VocalIdentityPickerSheet(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vocal_identity_picker_sheet')), findsOneWidget);
      expect(find.text('Regional Catalog (24)'), findsOneWidget);
      expect(
        find.byKey(const Key('vocal_archetype_card_vox_venda_royal_alto')),
        findsOneWidget,
      );

      // Filter by West Africa region chip
      await tester.tap(find.byKey(const Key('vocal_region_filter_westAfrica')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('vocal_archetype_card_vox_lagos_island_cruiser')),
        findsOneWidget,
      );

      // Switch to My Cloned Voices tab
      await tester.tap(find.byKey(const Key('vocal_tab_cloned')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vocal_cloned_tab_new_btn')), findsOneWidget);
    });

    testWidgets(
        'BantuVoiceDeck displays active Vocal Identity badge and Phase 26 action buttons',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: BantuVoiceDeck(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('active_vocal_identity_badge')), findsOneWidget);
      expect(
        find.byKey(const Key('open_vocal_identity_catalog_btn')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('open_voice_clone_recorder_btn')),
        findsOneWidget,
      );
    });
  });
}

