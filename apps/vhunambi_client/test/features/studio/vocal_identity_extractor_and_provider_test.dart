import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/mastering/domain/models/stem_mastering_recipe.dart';
import 'package:vhunambi_client/features/mastering/presentation/providers/mastering_session_provider.dart';
import 'package:vhunambi_client/features/studio/domain/models/vocal_identity_models.dart';
import 'package:vhunambi_client/features/studio/domain/services/i_voice_calibration_recorder.dart';
import 'package:vhunambi_client/features/studio/domain/services/phonetic_calibration_extractor.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/vocal_identity_provider.dart';

void main() {
  group('Phase 26 — Regional Voice Catalog & Phonetic Extractor', () {
    test('kRegionalVoiceCatalog exposes 24 unique African voice archetypes', () {
      expect(kRegionalVoiceCatalog.length, 24);
      final ids = kRegionalVoiceCatalog.map((e) => e.id).toSet();
      expect(ids.length, 24);

      final regions = kRegionalVoiceCatalog.map((e) => e.region).toSet();
      expect(regions, containsAll(AfricanVoiceRegion.values));
    });

    test(
        'PhoneticCalibrationExtractor.scoreLine ranks Bantu diacritics & clusters above plain lines',
        () {
      const vendaLine =
          'Ndaa! Mbilu yanga i khou tshimbila kha ṋaledzi na ḓuvha ḽa muṱa';
      const plainLine = 'Walking down the road in the morning';

      final vendaScore = PhoneticCalibrationExtractor.scoreLine(vendaLine);
      final plainScore = PhoneticCalibrationExtractor.scoreLine(plainLine);

      expect(vendaScore.score, greaterThan(plainScore.score + 10.0));
      expect(vendaScore.highlightedTokens, isNotEmpty);
    });

    test(
        'PhoneticCalibrationExtractor.extractScript selects top 3 lines and pads short lyrics',
        () {
      const lyrics = '''
[Verse 1]
Simple line one
Ndaa! Mbilu yanga i khou tshina kha ngoma dza Vhunambi
Another simple line
[Chorus]
Yebo! Hlala phansi ulalele isigqi saseThekwini
Ahee! Kha vha ḓe ri ṱangane tshilombe tsha Amapiano
''';

      final script = PhoneticCalibrationExtractor.extractScript(
        lyrics,
        language: 'Tshivenḓa',
      );
      expect(script.lines.length, 3);
      expect(
        script.lines[0].phoneticScore,
        greaterThanOrEqualTo(script.lines[1].phoneticScore),
      );
      expect(
        script.lines[1].phoneticScore,
        greaterThanOrEqualTo(script.lines[2].phoneticScore),
      );

      // Short lyrics fallback test
      final shortScript = PhoneticCalibrationExtractor.extractScript(
        'Only one line',
        language: 'isiZulu',
      );
      expect(shortScript.lines.length, 3);
    });

    test(
        'DeterministicVoiceCalibrationRecorder synthesizes valid RIFF WAVE header & timbre embedding',
        () async {
      final recorder = DeterministicVoiceCalibrationRecorder();
      final script = PhoneticCalibrationExtractor.extractScript(
        '',
        language: 'Tshivenḓa',
      );

      expect(recorder.isRecording, isFalse);
      await recorder.startRecording(script);
      expect(recorder.isRecording, isTrue);

      final result = await recorder.stopRecording();
      expect(recorder.isRecording, isFalse);
      expect(result.wavBytes.length, greaterThan(44));
      // Verify "RIFF" ASCII magic bytes
      expect(result.wavBytes[0], 0x52);
      expect(result.wavBytes[1], 0x49);
      expect(result.wavBytes[2], 0x46);
      expect(result.wavBytes[3], 0x46);
      expect(result.timbreEmbeddingPreview.length, 8);
      expect(result.clarityScore, greaterThan(0.9));

      recorder.dispose();
    });
  });

  group('Phase 26 — VocalIdentityNotifier & Mastering Synergy', () {
    test('filters 24-voice catalog by region, gender, style, and search query',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(vocalIdentityProvider.notifier);
      expect(container.read(vocalIdentityProvider).filteredCatalog.length, 24);

      notifier.setRegionFilter(AfricanVoiceRegion.westAfrica);
      final west = container.read(vocalIdentityProvider).filteredCatalog;
      expect(west, isNotEmpty);
      expect(
        west.every((v) => v.region == AfricanVoiceRegion.westAfrica),
        isTrue,
      );

      notifier.setGenderFilter(VocalGender.female);
      final westFemale = container.read(vocalIdentityProvider).filteredCatalog;
      expect(westFemale, isNotEmpty);
      expect(
        westFemale.every((v) => v.gender == VocalGender.female),
        isTrue,
      );

      notifier.clearAllFilters();
      expect(container.read(vocalIdentityProvider).filteredCatalog.length, 24);

      notifier.setSearchQuery('Soweto');
      final soweto = container.read(vocalIdentityProvider).filteredCatalog;
      expect(soweto.length, 1);
      expect(soweto.first.id, 'vox_soweto_soul_soprano');
    });

    test(
        'records 3-line voice clone, updates activeClonedProfile, and syncs VocalCleanseFlavor to masteringSessionProvider',
        () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(vocalIdentityProvider.notifier);
      notifier.prepareCalibrationFromLyrics(
        'Ndaa! Mbilu yanga i khou tshina kha ngoma dza Vhunambi',
        language: 'Tshivenḓa',
      );

      await notifier.startCalibrationRecording();
      expect(container.read(vocalIdentityProvider).isRecording, isTrue);

      final profile = await notifier.finalizeVoiceClone(
        creatorName: 'Ndugelo Lead Vocal',
        nativeLanguage: 'Tshivenḓa',
      );

      final state = container.read(vocalIdentityProvider);
      expect(state.isRecording, isFalse);
      expect(state.isUsingClonedVoice, isTrue);
      expect(state.activeClonedProfile?.id, profile.id);
      expect(state.clonedProfiles.length, 1);
      expect(
        state.activeVoiceDisplayLabel,
        contains('Ndugelo Lead Vocal (Cloned DNA)'),
      );

      // Allow microtask to sync VocalCleanseFlavor.studioClean into masteringSessionProvider
      await Future<void>.delayed(Duration.zero);
      final masteringRecipe = container.read(masteringSessionProvider).recipe;
      expect(
        masteringRecipe.vocals.flavor,
        VocalCleanseFlavor.studioClean,
      );

      // Deleting the cloned profile reverts to the catalog archetype
      await notifier.deleteClonedProfile(profile.id);
      expect(container.read(vocalIdentityProvider).isUsingClonedVoice, isFalse);
      expect(container.read(vocalIdentityProvider).clonedProfiles, isEmpty);
    });
  });
}

