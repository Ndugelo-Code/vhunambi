import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/song_metadata_dna.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/lyric_word_timestamp.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/content_studio_preset.dart';

void main() {
  group('SongMetadataDna', () {
    test('serializes and deserializes lossless JSON', () {
      final dna = SongMetadataDna(
        id: 'dna_test_001',
        title: 'Vhubvo Hanga',
        genre: 'Amapiano',
        language: 'Tshivenḓa',
        culturalContext: const CulturalContextDna(
          region: 'Vhembe, Limpopo',
          idioms: ['Mbilu ya muthu ndi thavha'],
          phoneticGuidelines: 'Soft aspirated consonants',
        ),
        musical: const MusicalDna(
          bpm: 112,
          key: 'F# Minor',
          energyBracket: 'mid',
          durationSec: 180,
        ),
        vocals: const VocalsDna(
          deliveryMode: 'melodic',
          gender: 'female',
          energy: 'mid',
          loras: [
            {'path': 'loras/venda_female.safetensors', 'weight': 0.8}
          ],
        ),
        visualTheme: const VisualThemeDna(
          mood: 'Soulful sunset over Thohoyandou',
          comfyPrompt: 'Warm golden hour lighting over Limpopo landscape',
          seed: 1234567,
          aspectRatio: '9:16',
        ),
        alignment: const [
          LyricWordTimestamp(word: 'Ndi', start: 1.0, end: 1.3, stanzaIndex: 0),
          LyricWordTimestamp(word: 'mufunwa', start: 1.35, end: 1.9, stanzaIndex: 0),
        ],
      );

      final json = dna.toJson();
      final revived = SongMetadataDna.fromJson(json);

      expect(revived.id, equals('dna_test_001'));
      expect(revived.title, equals('Vhubvo Hanga'));
      expect(revived.genre, equals('Amapiano'));
      expect(revived.language, equals('Tshivenḓa'));
      expect(revived.culturalContext?.region, equals('Vhembe, Limpopo'));
      expect(revived.culturalContext?.idioms.first, equals('Mbilu ya muthu ndi thavha'));
      expect(revived.musical.bpm, equals(112));
      expect(revived.musical.key, equals('F# Minor'));
      expect(revived.vocals.deliveryMode, equals('melodic'));
      expect(revived.visualTheme.seed, equals(1234567));
      expect(revived.visualTheme.aspectRatio, equals('9:16'));
      expect(revived.alignment.length, equals(2));
      expect(revived.alignment[0].word, equals('Ndi'));
      expect(revived.alignment[1].word, equals('mufunwa'));
      expect(revived, equals(dna));
    });

    test('supports copyWith mutation safely', () {
      const dna = SongMetadataDna(
        id: 'dna_002',
        title: 'Original Title',
        genre: 'Gqom',
        language: 'isiZulu',
        musical: MusicalDna(bpm: 126, key: 'C Minor', energyBracket: 'intense', durationSec: 120),
        vocals: VocalsDna(deliveryMode: 'rap', gender: 'male', energy: 'intense'),
        visualTheme: VisualThemeDna(mood: 'Dark Durban club', comfyPrompt: 'Neon lights', seed: 99),
      );

      final updated = dna.copyWith(title: 'Updated Title');
      expect(updated.title, equals('Updated Title'));
      expect(updated.genre, equals('Gqom'));
      expect(updated.id, equals('dna_002'));
    });

    test('fromTrackInfo compiles track info into complete DNA with auto-alignment', () {
      final dna = SongMetadataDna.fromTrackInfo(
        id: 'track_123',
        title: 'Thohoyandou Vibes',
        genre: 'Amapiano',
        language: 'Tshivenḓa',
        durationSec: 180,
        lyrics: 'Ndi mufunwa wanga ane a mpfuna zwihulu',
      );

      expect(dna.id, equals('track_123'));
      expect(dna.title, equals('Thohoyandou Vibes'));
      expect(dna.genre, equals('Amapiano'));
      expect(dna.musical.bpm, equals(113));
      expect(dna.visualTheme.mood, contains('Warm Sunset'));
      expect(dna.alignment.length, equals(7));
      expect(dna.alignment.first.word, equals('Ndi'));
      expect(dna.alignment.last.word, equals('zwihulu'));
    });
  });

  group('LyricWordTimestamp', () {
    test('serializes and deserializes word timestamps', () {
      const timestamp = LyricWordTimestamp(
        word: 'Zania',
        start: 2.15,
        end: 2.75,
        stanzaIndex: 1,
      );

      final json = timestamp.toJson();
      final revived = LyricWordTimestamp.fromJson(json);

      expect(revived.word, equals('Zania'));
      expect(revived.start, equals(2.15));
      expect(revived.end, equals(2.75));
      expect(revived.stanzaIndex, equals(1));
      expect(revived, equals(timestamp));
    });
  });

  group('ContentStudioPreset', () {
    test('has valid labels and target seconds', () {
      expect(LyricTypographyPreset.kineticBounce.label, equals('Kinetic Bounce'));
      expect(LyricTypographyPreset.luminousGlow.label, equals('Luminous Glow'));
      expect(LyricTypographyPreset.minimalSubtitle.label, equals('Minimal Subtitle'));
      expect(LyricTypographyPreset.bantuCalligraphy.label, equals('Bantu Calligraphy'));

      expect(DurationPreset.hook15s.targetSeconds, equals(15));
      expect(DurationPreset.reel30s.targetSeconds, equals(30));
      expect(DurationPreset.fullTrack.targetSeconds, equals(180));
    });

    test('AtmosphericEffects toggles correctly', () {
      const effects = AtmosphericEffects();
      expect(effects.filmGrain, isTrue);
      expect(effects.bassPulse, isTrue);
      expect(effects.kenBurnsMotion, isTrue);

      final toggled = effects.copyWith(filmGrain: false);
      expect(toggled.filmGrain, isFalse);
      expect(toggled.bassPulse, isTrue);
    });
  });
}
