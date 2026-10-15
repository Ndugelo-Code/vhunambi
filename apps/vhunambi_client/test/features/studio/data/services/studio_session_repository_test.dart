import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/studio/data/services/studio_session_repository.dart';
import 'package:vhunambi_client/features/studio/domain/models/studio_session_draft.dart';

void main() {
  group('StudioSessionRepository', () {
    late StudioSessionRepository repository;

    setUp(() {
      repository = StudioSessionRepository();
    });

    test('initial state has no saved session and returns null', () async {
      final hasSaved = await repository.hasSavedSession();
      final loaded = await repository.loadSession();

      expect(hasSaved, isFalse);
      expect(loaded, isNull);
    });

    test('saveSession stores draft and loadSession retrieves it accurately', () async {
      final draft = StudioSessionDraft(
        sessionId: 'sess_999',
        savedAt: DateTime.now(),
        prompt: 'South African deep house with warm rhodes',
        genre: 'Deep House',
        region: 'Johannesburg',
        language: 'English',
        isInstrumental: false,
        durationSeconds: 240,
        lyricsMode: 'aiWrite',
        mood: 'Chill',
        tempo: 'medium',
        vocalVoices: 'solo',
        vocalGender: 'female',
        vocalMode: 'melodic',
        vocalEnergy: 'mid',
        songStructure: 'standard',
        isAutoTitle: true,
        isPublic: true,
      );

      await repository.saveSession(draft);

      final hasSaved = await repository.hasSavedSession();
      final loaded = await repository.loadSession();

      expect(hasSaved, isTrue);
      expect(loaded, isNotNull);
      expect(loaded!.sessionId, 'sess_999');
      expect(loaded.prompt, 'South African deep house with warm rhodes');
      expect(loaded.genre, 'Deep House');
    });

    test('hasSavedSession returns false if draft has no meaningful content', () async {
      final emptyDraft = StudioSessionDraft(
        sessionId: 'sess_empty',
        savedAt: DateTime.now(),
        prompt: '',
        genre: 'Amapiano',
        region: 'South Africa',
        language: 'English',
        isInstrumental: false,
        durationSeconds: 30,
        lyricsMode: 'aiWrite',
        mood: 'Uplifting',
        tempo: 'medium',
        vocalVoices: 'solo',
        vocalGender: 'male',
        vocalMode: 'auto',
        vocalEnergy: 'mid',
        songStructure: 'standard',
        isAutoTitle: true,
        isPublic: true,
      );

      await repository.saveSession(emptyDraft);

      final hasSaved = await repository.hasSavedSession();
      expect(hasSaved, isFalse);
    });

    test('clearSession removes the persisted draft', () async {
      final draft = StudioSessionDraft(
        sessionId: 'sess_clear_me',
        savedAt: DateTime.now(),
        prompt: 'Vocal hook in Sepedi',
        genre: 'Amapiano',
        region: 'Limpopo',
        language: 'Sepedi',
        isInstrumental: false,
        durationSeconds: 60,
        lyricsMode: 'myOwn',
        customLyrics: 'Ke a go rata',
        mood: 'Romantic',
        tempo: 'medium',
        vocalVoices: 'duet',
        vocalGender: 'mixed',
        vocalMode: 'melodic',
        vocalEnergy: 'mid',
        songStructure: 'standard',
        isAutoTitle: true,
        isPublic: true,
      );

      await repository.saveSession(draft);
      expect(await repository.hasSavedSession(), isTrue);

      await repository.clearSession();
      expect(await repository.hasSavedSession(), isFalse);
      expect(await repository.loadSession(), isNull);
    });
  });
}
