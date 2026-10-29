import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/content_studio/data/services/cloud_video_export_service.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/content_studio_preset.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/lyric_word_timestamp.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/master_media_object.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/song_metadata_dna.dart';

void main() {
  group('CloudVideoExportService Tests (Option 1: Server-Side Cloud Worker)', () {
    late CloudVideoExportService service;

    setUp(() {
      service = CloudVideoExportService(apiBaseUrl: 'https://api.vhunambi.com');
    });

    test('exportLyricVideo emits incremental progress and returns cloud R2 URL',
        () async {
      final progressTicks = <double>[];

      final videoUrl = await service.exportLyricVideo(
        audioUrl: 'https://r2.vhunambi.com/audio/master.mp3',
        coverArtUrl: 'https://r2.vhunambi.com/art/cover.png',
        words: const [
          LyricWordTimestamp(word: 'Vhunambi', start: 0.0, end: 1.5),
        ],
        startSec: 0.0,
        endSec: 15.0,
        preset: LyricTypographyPreset.kineticBounce,
        effects: const AtmosphericEffects(),
        onProgress: (p) => progressTicks.add(p),
      );

      expect(videoUrl, startsWith('https://r2.vhunambi.com/reels/vhunambi_reel_'));
      expect(videoUrl, endsWith('.mp4'));
      expect(progressTicks, containsAllInOrder([0.15, 0.55, 0.85, 1.0]));
    });

    test('exportFromMmo consumes MasterMediaObject manifest payload', () async {
      const sampleDna = SongMetadataDna(
        id: 'dna_mmo_cloud_test',
        title: 'Vha Venda Sunrise',
        genre: 'Amapiano',
        language: 'Tshivenḓa',
        musical: MusicalDna(
          bpm: 112,
          key: 'F# Minor',
          energyBracket: 'high',
          durationSec: 180,
        ),
        vocals: VocalsDna(
          deliveryMode: 'melodic',
          gender: 'female',
          energy: 'high',
        ),
        visualTheme: VisualThemeDna(
          mood: 'Twilight',
          comfyPrompt: 'Sunrise across Venda hills',
          seed: 42,
          aspectRatio: '9:16',
        ),
        alignment: [
          LyricWordTimestamp(word: 'Ndi', start: 0.0, end: 0.5),
          LyricWordTimestamp(word: 'Matscheloni', start: 0.6, end: 1.2),
        ],
      );

      final mmo = MasterMediaObject.fromSongMetadataDna(sampleDna);

      final videoUrl = await service.exportFromMmo(
        mmo: mmo,
        preset: LyricTypographyPreset.luminousGlow,
      );

      expect(videoUrl, startsWith('https://r2.vhunambi.com/reels/vhunambi_reel_'));
      expect(videoUrl, contains('luminousGlow'));
      expect(videoUrl, endsWith('.mp4'));
    });
  });
}
