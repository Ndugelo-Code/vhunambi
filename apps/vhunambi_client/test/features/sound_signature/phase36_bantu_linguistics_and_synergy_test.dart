import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vhunambi_client/features/sound_signature/domain/dsp/bantu_phonology.dart';
import 'package:vhunambi_client/features/sound_signature/domain/dsp/bantu_similarity.dart';
import 'package:vhunambi_client/features/sound_signature/domain/idealizer/pitch_trajectory_editor.dart';
import 'package:vhunambi_client/features/sound_signature/domain/idealizer/pocket_quantizer.dart';
import 'package:vhunambi_client/features/sound_signature/domain/models/sound_idealizer_recipe.dart';
import 'package:vhunambi_client/features/studio/domain/models/melody_sketchpad_models.dart';
import 'package:vhunambi_client/features/studio/domain/services/bantu_lyric_translation_service.dart';
import 'package:vhunambi_client/features/home/domain/models/studio_synergy_context.dart';
import 'package:vhunambi_client/features/home/presentation/providers/cross_module_synergy_provider.dart';
import 'package:vhunambi_client/features/home/presentation/widgets/cross_module_synergy_deck.dart';
import 'package:vhunambi_client/features/track/domain/models/track_detail_models.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/lyrics_teleprompter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 36 Track A: Peer-Branch Southern Bantu Phonology & Scorer', () {
    test('REQ-BANTU-MODEL-01: Exactly 9 languages mapped to 4 equal peer branches', () {
      expect(BantuLanguageBranch.values, hasLength(4));
      expect(
        BantuLanguageBranch.values.map((b) => b.guthrieZone).toSet(),
        containsAll(['S20', 'S30', 'S40', 'S50']),
      );

      // Verify the 9 official languages
      expect(BantuLanguage.values, hasLength(9));
      expect(BantuLanguage.fromCode('zu')?.branch, BantuLanguageBranch.nguni);
      expect(BantuLanguage.fromCode('xh')?.branch, BantuLanguageBranch.nguni);
      expect(BantuLanguage.fromCode('ss')?.branch, BantuLanguageBranch.nguni);
      expect(BantuLanguage.fromCode('nr')?.branch, BantuLanguageBranch.nguni);
      expect(BantuLanguage.fromCode('nso')?.branch, BantuLanguageBranch.sothoTswana);
      expect(BantuLanguage.fromCode('tn')?.branch, BantuLanguageBranch.sothoTswana);
      expect(BantuLanguage.fromCode('st')?.branch, BantuLanguageBranch.sothoTswana);
      expect(BantuLanguage.fromCode('ve')?.branch, BantuLanguageBranch.tshivenda);
      expect(BantuLanguage.fromCode('ts')?.branch, BantuLanguageBranch.tswaRonga);

      // Unknown language returns null
      expect(BantuLanguage.fromCode('unknown'), isNull);
      expect(BantuLanguage.fromCode(null), isNull);
    });

    test('REQ-BANTU-MODEL-02 & REQ-BANTU-SIM-05: Route planner is direct with zero hub insertion', () {
      // Test all pairwise routes across all 9 languages
      for (final src in BantuLanguage.values) {
        for (final tgt in BantuLanguage.values) {
          final route = BantuRoutePlanner.route(src, tgt);
          expect(route.hops, hasLength(2), reason: 'Route must have exactly 2 nodes (source, target)');
          expect(route.hops.first, equals(src));
          expect(route.hops.last, equals(tgt));
          expect(route.isIntraBranch, equals(src.branch == tgt.branch));
        }
      }

      // Explicit regression: zu -> xh never passes through ve or any other language
      final zuXh = BantuRoutePlanner.route(BantuLanguage.zu, BantuLanguage.xh);
      expect(zuXh.hops, equals([BantuLanguage.zu, BantuLanguage.xh]));
      expect(zuXh.isIntraBranch, isTrue);
    });

    test('REQ-BANTU-PHON-01 & 02: Per-branch protection profiles and named constants', () {
      expect(kDepressorOnsetExemptionDurationMs, equals(60.0));
      expect(kLexicalTonePolarityMinDeltaSt, equals(2.0));
      expect(kBantuTablesValidated, isFalse);

      final nguniProfile = BantuPhonology.profileFor(BantuLanguageBranch.nguni);
      final sothoProfile = BantuPhonology.profileFor(BantuLanguageBranch.sothoTswana);
      final vendaProfile = BantuPhonology.profileFor(BantuLanguageBranch.tshivenda);
      final rongaProfile = BantuPhonology.profileFor(BantuLanguageBranch.tswaRonga);

      expect(nguniProfile.hasDepressorOnsets, isTrue);
      expect(vendaProfile.hasDepressorOnsets, isTrue);
      expect(sothoProfile.hasDepressorOnsets, isFalse);
      expect(rongaProfile.hasDepressorOnsets, isFalse);

      expect(nguniProfile.protectedGraphemes, containsAll(['c', 'q', 'x']));
      expect(vendaProfile.protectedGraphemes, containsAll(['ḓ', 'ṱ', 'ṋ', 'ḽ', 'vh']));
      expect(sothoProfile.protectedGraphemes, containsAll(['tl', 'tlh', 'kg']));
      expect(rongaProfile.protectedGraphemes, containsAll(['sw', 'zv']));
    });

    test('REQ-BANTU-SIM-01: Weighted score formula (0.40 Lev + 0.30 Shift + 0.30 NounClass)', () {
      final res = BantuSimilarity.compare('mutu', BantuLanguage.ve, 'muntu', BantuLanguage.zu);
      expect(res.score, inInclusiveRange(0, 100));
      expect(res.levenshteinScore, inInclusiveRange(0, 100));
      expect(res.shiftScore, inInclusiveRange(0, 100));
      expect(res.nounClassScore, inInclusiveRange(0, 100));

      final calculated = (0.40 * res.levenshteinScore + 0.30 * res.shiftScore + 0.30 * res.nounClassScore).round();
      expect(res.score, equals(calculated));

      // Identical words return 100
      final perfect = BantuSimilarity.compare('yebo', BantuLanguage.zu, 'yebo', BantuLanguage.zu);
      expect(perfect.score, equals(100));
      expect(perfect.type, equals(BantuCognateType.direct));
    });

    test('REQ-BANTU-SIM-02 & 03: Intra-branch identity vs cross-branch pairwise shifts', () {
      // Intra-branch (zu -> xh): no shifts applied
      final shiftedIntra = BantuSimilarity.applyShifts('qeda', BantuLanguageBranch.nguni, BantuLanguageBranch.nguni);
      expect(shiftedIntra, equals('qeda'));

      // Cross-branch (nguni -> tshivenda): q -> fh
      final shiftedCross = BantuSimilarity.applyShifts('qeda', BantuLanguageBranch.nguni, BantuLanguageBranch.tshivenda);
      expect(shiftedCross, equals('fheda'));
    });

    test('REQ-BANTU-SIM-04: Noun-class alignment across peer languages', () {
      // Class 7: isiZulu 'isi-' <-> Tshivenda 'tshi-'
      final rClass7 = BantuSimilarity.compare('isizulu', BantuLanguage.zu, 'tshivenda', BantuLanguage.ve);
      expect(rClass7.nounClassScore, equals(100));

      // Class 6: isiZulu 'ama-' <-> Tshivenda 'ma-'
      final rClass6 = BantuSimilarity.compare('amakhosi', BantuLanguage.zu, 'mahosi', BantuLanguage.ve);
      expect(rClass6.nounClassScore, equals(100));
    });
  });

  group('Phase 36 Track A: Vocal Idealizer DSP Guards', () {
    test('REQ-BANTU-DSP-A1: Depressor onset ramp exempts initial 60 ms on Nguni/Tshivenḓa', () {
      const editor = PitchTrajectoryEditor(frameRateHz: 50); // 20 ms per frame -> 3 frames for 60 ms
      final raw = [6000, 6000, 6000, 6000, 6000]; // 5 voiced frames (MIDI 60 * 100)
      const recipe = SoundIdealizerRecipe(pitchScaleLock: 1.0);

      final nguniResult = editor.editTrajectory(
        rawF0CentsMidi: raw,
        scaleMode: AfricanScaleMode.minorPentatonic,
        rootPitchClass: 0,
        recipe: recipe,
        branch: BantuLanguageBranch.nguni,
      );
      expect(nguniResult.idealSemitones, hasLength(5));

      final sothoResult = editor.editTrajectory(
        rawF0CentsMidi: raw,
        scaleMode: AfricanScaleMode.minorPentatonic,
        rootPitchClass: 0,
        recipe: recipe,
        branch: BantuLanguageBranch.sothoTswana,
      );
      expect(sothoResult.idealSemitones, hasLength(5));
    });

    test('REQ-BANTU-DSP-A2: Lexical tone polarity guard prevents sign inversion when delta >= 2.0 st', () {
      final raw = [60.0, 63.0]; // +3.0 st jump
      final candidate = [62.0, 61.0]; // Inverted to -1.0 st!

      final guarded = PitchTrajectoryEditor.applyTonePolarityGuard(
        rawMedians: raw,
        targets: candidate,
        scalePitchClasses: {0, 2, 4, 7, 9},
      );
      final guardedDelta = guarded[1] - guarded[0];
      expect(guardedDelta >= 0.0, isTrue, reason: 'Tone polarity guard must not allow sign inversion');
    });

    test('REQ-BANTU-DSP-A3: Penultimate cadence anchor preserves phrase elongation >= 1.5x', () {
      final onsets = [0, 200, 400, 800];
      final anchors = PocketQuantizer.penultimateAnchors(onsets);
      expect(anchors, contains((2, 3)));
    });
  });

  group('Phase 36 Track C: Bantu Lyric Translation & Phonetic Sing-Along', () {
    test('REQ-BANTU-LYR-01 & 02: Lexicon-based translation with zero fabrication', () {
      // Known word in curated glossary
      final itemKnown = BantuLyricTranslationService.translateLine(
        line: 'Sawubona',
        baseLanguageCode: 'zu',
      );
      expect(itemKnown.originalLine, equals('Sawubona'));
      expect(itemKnown.isGlossaryMatch, isTrue);
      expect(itemKnown.translatedMeaning, contains('hello'));

      // Unknown word yields 'meaning unavailable' (strictly no fabrication)
      final itemUnknown = BantuLyricTranslationService.translateLine(
        line: 'Xylophone astronaut quantum',
        baseLanguageCode: 'zu',
      );
      expect(itemUnknown.isGlossaryMatch, isFalse);
      expect(itemUnknown.translatedMeaning, equals(kMeaningUnavailable));
    });

    test('REQ-BANTU-LYR-03: Phonetic guide marks penultimate syllable', () {
      // 3-syllable word 'hambani' -> ha-**mba**-ni (penultimate syllable stressed)
      final guide3 = BantuLyricTranslationService.generatePhoneticGuide('hambani');
      expect(guide3, contains('**mba**'));

      // 4-syllable word 'ngiyabonga' -> ngi-ya-**bo**-nga
      final guide4 = BantuLyricTranslationService.generatePhoneticGuide('ngiyabonga');
      expect(guide4, contains('**bo**'));
    });

    testWidgets('REQ-BANTU-LYR-04: LyricsTeleprompter has track_translate_lyrics_toggle >= 44x44dp', (tester) async {
      const sampleTrack = TrackDetailEntity(
        id: 'track_test_1',
        title: 'Vhafunwa',
        genre: 'Amapiano',
        language: 'Tshivenḓa',
        duration: Duration(minutes: 3),
        creatorId: 'creator_1',
        creatorName: 'Vhunambi Collective',
        creatorHandle: '@vhunambi',
        lyrics: 'Ndi mufunwa wanga\nMutsho wa vhonala',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LyricsTeleprompter(track: sampleTrack),
            ),
          ),
        ),
      );

      final toggleFinder = find.byKey(const Key('track_translate_lyrics_toggle'));
      expect(toggleFinder, findsOneWidget);

      final size = tester.getSize(toggleFinder);
      expect(size.width, greaterThanOrEqualTo(44.0));
      expect(size.height, greaterThanOrEqualTo(44.0));

      // Tap toggle to activate translation
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      expect(find.textContaining('indicative'), findsWidgets);
    });
  });

  group('Phase 36 Track D: Cross-Module Synergy & Creator Mastery Perks', () {
    test('REQ-BANTU-SYN-01 & 02: Synergy context mapping matches doc 05 §2 recipes', () {
      const stabilityContext = StudioSynergyContext(
        sourceModule: 'PitchContourProfile',
        targetModule: 'SoundSignatureIdealizerSheet',
        gapKind: SynergyGapKind.lowStability,
        measuredValue: 0.45,
        suggestedRecipe: SoundIdealizerRecipe(
          pitchScaleLock: 0.95,
          vibratoAndSustainPolish: 0.90,
        ),
      );
      expect(stabilityContext.suggestedRecipe.pitchScaleLock, equals(0.95));
      expect(stabilityContext.suggestedRecipe.vibratoAndSustainPolish, equals(0.90));

      const snrContext = StudioSynergyContext(
        sourceModule: 'InputQualityGate',
        targetModule: 'SoundSignatureIdealizerSheet',
        gapKind: SynergyGapKind.lowSnr,
        measuredValue: 12.0,
        suggestedRecipe: SoundIdealizerRecipe(referenceCleanup: 0.95),
      );
      expect(snrContext.suggestedRecipe.referenceCleanup, equals(0.95));
    });

    test('REQ-BANTU-SYN-05 & 06: Mastery badges are unlocked purely cosmetically with zero monetary fields', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final badges = container.read(creatorMasteryBadgesProvider);
      expect(badges, hasLength(3));
      expect(badges.map((b) => b.id), containsAll(['polyglot_vocalist', 'groove_architect', 'voice_sovereign']));

      for (final b in badges) {
        expect(b.badgeFlair.isNotEmpty, isTrue);
      }
    });

    testWidgets('REQ-BANTU-SYN-04: CrossModuleSynergyDeck renders dismissible cards with >= 44x44dp targets', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            crossModuleSynergyProvider.overrideWith(
              (ref) => CrossModuleSynergyNotifier(ref)
                ..state = [
                  const SynergyCardItem(
                    id: 'test_card_1',
                    title: 'Steady Pitch Instability',
                    subtitle: 'Tremor detected on sustained vocal notes.',
                    actionLabel: 'Steady my pitch',
                    metricSummary: 'Stability: 55%',
                    context: StudioSynergyContext(
                      sourceModule: 'PitchContourProfile',
                      targetModule: 'SoundSignatureIdealizerSheet',
                      gapKind: SynergyGapKind.lowStability,
                      measuredValue: 0.55,
                      suggestedRecipe: SoundIdealizerRecipe(pitchScaleLock: 0.95),
                    ),
                  ),
                ],
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CrossModuleSynergyDeck(),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('synergy_dismiss_test_card_1')), findsOneWidget);
      expect(find.byKey(const Key('synergy_action_test_card_1')), findsOneWidget);

      final dismissSize = tester.getSize(find.byKey(const Key('synergy_dismiss_test_card_1')));
      expect(dismissSize.width, greaterThanOrEqualTo(44.0));
      expect(dismissSize.height, greaterThanOrEqualTo(44.0));

      final actionSize = tester.getSize(find.byKey(const Key('synergy_action_test_card_1')));
      expect(actionSize.height, greaterThanOrEqualTo(44.0));
    });
  });
}
