import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/studio/domain/models/studio_form_state.dart';
import 'package:vhunambi_client/features/studio/domain/models/studio_session_draft.dart';

void main() {
  group('StudioSessionDraft', () {
    test('fromFormState creates draft with all state values', () {
      const form = StudioFormState(
        prompt: 'A soulful maskandi guitar melody',
        genre: 'Maskandi',
        region: 'KwaZulu-Natal',
        language: 'isiZulu',
        isInstrumental: false,
        durationSeconds: 120,
        lyricsMode: LyricsMode.myOwn,
        customLyrics: 'Ngiyazifela ngawe\nSthandwa sami',
        mood: 'Nostalgic',
        tempo: TempoBracket.slow,
        vocalVoices: VocalVoices.solo,
        vocalGender: VocalGender.male,
        vocalMode: VocalMode.melodic,
        vocalEnergy: VocalEnergy.soft,
        songStructure: SongStructure.standard,
        isAutoTitle: false,
        customTitle: 'Imbizo',
        isPublic: true,
      );

      final draft = StudioSessionDraft.fromFormState(form);

      expect(draft.prompt, 'A soulful maskandi guitar melody');
      expect(draft.genre, 'Maskandi');
      expect(draft.region, 'KwaZulu-Natal');
      expect(draft.language, 'isiZulu');
      expect(draft.isInstrumental, isFalse);
      expect(draft.durationSeconds, 120);
      expect(draft.lyricsMode, 'myOwn');
      expect(draft.customLyrics, 'Ngiyazifela ngawe\nSthandwa sami');
      expect(draft.mood, 'Nostalgic');
      expect(draft.tempo, 'slow');
      expect(draft.vocalVoices, 'solo');
      expect(draft.vocalGender, 'male');
      expect(draft.vocalMode, 'melodic');
      expect(draft.vocalEnergy, 'soft');
      expect(draft.songStructure, 'standard');
      expect(draft.isAutoTitle, isFalse);
      expect(draft.customTitle, 'Imbizo');
      expect(draft.isPublic, isTrue);
      expect(draft.sessionId.startsWith('session_'), isTrue);
      expect(draft.hasContent, isTrue);
    });

    test('toJson and fromJson round-trip perfectly', () {
      final now = DateTime.now();
      final original = StudioSessionDraft(
        sessionId: 'session_test_123',
        savedAt: now,
        prompt: 'Gqom banger with heavy bass kicks',
        genre: 'Gqom',
        region: 'Durban',
        language: 'isiZulu',
        isInstrumental: true,
        durationSeconds: 180,
        lyricsMode: 'instrumental',
        customLyrics: null,
        mood: 'Energetic',
        tempo: 'fast',
        vocalVoices: 'solo',
        vocalGender: 'male',
        vocalMode: 'auto',
        vocalEnergy: 'intense',
        songStructure: 'loop',
        isAutoTitle: true,
        customTitle: null,
        isPublic: false,
        referenceAudioPath: '/path/to/sample.wav',
        voiceProfileJson: const <String, dynamic>{'voiceId': 'sipho_01'},
        dialectInflectionJson: const <String, dynamic>{'vibrato': 0.8},
      );

      final json = original.toJson();
      final restored = StudioSessionDraft.fromJson(json);

      expect(restored.sessionId, original.sessionId);
      expect(restored.prompt, original.prompt);
      expect(restored.genre, original.genre);
      expect(restored.region, original.region);
      expect(restored.language, original.language);
      expect(restored.isInstrumental, original.isInstrumental);
      expect(restored.durationSeconds, original.durationSeconds);
      expect(restored.lyricsMode, original.lyricsMode);
      expect(restored.customLyrics, isNull);
      expect(restored.mood, original.mood);
      expect(restored.tempo, original.tempo);
      expect(restored.referenceAudioPath, '/path/to/sample.wav');
      expect(restored.voiceProfileJson, original.voiceProfileJson);
      expect(restored.dialectInflectionJson, original.dialectInflectionJson);
      expect(restored.hasContent, isTrue);
    });

    test('hasContent returns false on pristine default studio state', () {
      const defaultForm = StudioFormState();
      final draft = StudioSessionDraft.fromFormState(defaultForm);

      expect(draft.hasContent, isFalse);
    });

    test('hasContent returns true when prompt is non-empty', () {
      const form = StudioFormState(prompt: 'log drums');
      final draft = StudioSessionDraft.fromFormState(form);

      expect(draft.hasContent, isTrue);
    });

    test('hasContent returns true when genre is modified from default', () {
      const form = StudioFormState(genre: 'Afrobeats');
      final draft = StudioSessionDraft.fromFormState(form);

      expect(draft.hasContent, isTrue);
    });

    test('hasContent returns true when custom lyrics are provided', () {
      const form = StudioFormState(customLyrics: 'Some lyrics line');
      final draft = StudioSessionDraft.fromFormState(form);

      expect(draft.hasContent, isTrue);
    });
  });
}
