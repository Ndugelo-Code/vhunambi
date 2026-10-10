import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/studio/domain/models/studio_form_state.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/studio_form_provider.dart';

void main() {
  group('StudioFormNotifier Tests', () {
    late StudioFormNotifier notifier;

    setUp(() {
      notifier = StudioFormNotifier();
    });

    test('Initial state has correct production defaults', () {
      final state = notifier.state;
      expect(state.genre, 'Amapiano');
      expect(state.region, 'South Africa');
      expect(state.language, 'English');
      expect(state.isInstrumental, false);
      expect(state.durationSeconds, 30);
      expect(state.lyricsMode, LyricsMode.aiWrite);
      expect(state.mood, 'Uplifting');
      expect(state.tempo, TempoBracket.medium);
      expect(state.vocalVoices, VocalVoices.solo);
      expect(state.vocalGender, VocalGender.male);
      expect(state.vocalMode, VocalMode.auto);
      expect(state.vocalEnergy, VocalEnergy.mid);
      expect(state.songStructure, SongStructure.standard);
      expect(state.isAutoTitle, true);
      expect(state.isPublic, true);
      expect(state.phase, GenerationPhase.idle);
      expect(state.generationProgress, 0.0);
    });

    test('updatePrompt updates prompt text cleanly', () {
      notifier.updatePrompt('Log drum anthem with female vocals');
      expect(notifier.state.prompt, 'Log drum anthem with female vocals');
    });

    test('setGenre updates genre and setRegion updates region', () {
      notifier.setRegion('Africa');
      notifier.setGenre('Afrobeats');
      expect(notifier.state.region, 'Africa');
      expect(notifier.state.genre, 'Afrobeats');
    });

    test('setLanguage supports African indigenous languages (Tshivenḓa)', () {
      notifier.setLanguage('Tshivenḓa');
      expect(notifier.state.language, 'Tshivenḓa');
    });

    test('toggleInstrumental true sets lyricsMode to instrumental', () {
      notifier.toggleInstrumental(true);
      expect(notifier.state.isInstrumental, true);
      expect(notifier.state.lyricsMode, LyricsMode.instrumental);

      notifier.toggleInstrumental(false);
      expect(notifier.state.isInstrumental, false);
      expect(notifier.state.lyricsMode, LyricsMode.aiWrite);
    });

    test('setDurationSeconds updates duration', () {
      notifier.setDurationSeconds(120);
      expect(notifier.state.durationSeconds, 120);
    });

    test('applyPromptPreset populates prompt string', () {
      const preset = 'Late-night log drum session in Soweto';
      notifier.applyPromptPreset(preset);
      expect(notifier.state.prompt, preset);
    });

    test('inspireMe populates non-empty seed prompt', () {
      expect(notifier.state.prompt, isEmpty);
      notifier.inspireMe();
      expect(notifier.state.prompt, isNotEmpty);
    });

    test('triggerGeneration transitions to generatingLyrics for AI lyrics mode', () {
      notifier.triggerGeneration();
      expect(notifier.state.phase, GenerationPhase.generatingLyrics);
      expect(notifier.state.generationProgress, 0.25);
    });

    test('triggerGeneration transitions to queued for instrumental mode', () {
      notifier.toggleInstrumental(true);
      notifier.triggerGeneration();
      expect(notifier.state.phase, GenerationPhase.queued);
      expect(notifier.state.generationProgress, 0.1);
    });

    test('reset restores initial state', () {
      notifier.setGenre('Gqom');
      notifier.setLanguage('isiZulu');
      notifier.updatePrompt('Thumping kicks');
      notifier.reset();

      expect(notifier.state.genre, 'Amapiano');
      expect(notifier.state.language, 'English');
      expect(notifier.state.prompt, isEmpty);
    });

    test('toSongMetadataDna compiles lossless SongMetadataDna from wizard state', () {
      notifier.setGenre('Amapiano');
      notifier.setLanguage('Tshivenḓa');
      notifier.setMood('Soulful & Nostalgic');
      notifier.setTempo(TempoBracket.medium);
      notifier.setVocalEnergy(VocalEnergy.mid);
      notifier.setVocalGender(VocalGender.female);
      notifier.updatePrompt('Mbilu yanga anthem');

      final dna = notifier.state.toSongMetadataDna();
      expect(dna.title, equals('Mbilu yanga anthem'));
      expect(dna.genre, equals('Amapiano'));
      expect(dna.language, equals('Tshivenḓa'));
      expect(dna.musical.bpm, equals(112));
      expect(dna.vocals.deliveryMode, equals('melodic'));
      expect(dna.vocals.gender, equals('female'));
      expect(dna.visualTheme.aspectRatio, equals('9:16'));
    });

    test('4 DNA presets configure appropriate regional and musical parameters', () {
      notifier.applyDnaPresetPrivateSchoolPiano();
      expect(notifier.state.genre, equals('Amapiano'));
      expect(notifier.state.tempo, equals(TempoBracket.medium));
      expect(notifier.state.language, equals('Tshivenḓa'));

      notifier.applyDnaPresetDurbanDarkGqom();
      expect(notifier.state.genre, equals('Gqom'));
      expect(notifier.state.tempo, equals(TempoBracket.fast));
      expect(notifier.state.language, equals('isiZulu'));

      notifier.applyDnaPresetVendaTraditionalSoul();
      expect(notifier.state.genre, equals('Afro-Soul'));
      expect(notifier.state.tempo, equals(TempoBracket.slow));
      expect(notifier.state.vocalVoices, equals(VocalVoices.choir));

      notifier.applyDnaPresetLagosAfroPop();
      expect(notifier.state.genre, equals('Afrobeats'));
      expect(notifier.state.tempo, equals(TempoBracket.medium));
      expect(notifier.state.vocalVoices, equals(VocalVoices.duet));
    });
  });
}
