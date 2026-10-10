import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/song_metadata_dna.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/content_studio_preset.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/lyric_word_timestamp.dart';
import 'package:vhunambi_client/features/content_studio/presentation/providers/content_studio_provider.dart';
import 'package:vhunambi_client/features/content_studio/data/services/local_video_export_service.dart';

void main() {
  group('ContentStudioNotifier', () {
    late ContentStudioNotifier notifier;
    late SongMetadataDna sampleDna;

    setUp(() {
      notifier = ContentStudioNotifier(LocalVideoExportService());
      sampleDna = const SongMetadataDna(
        id: 'dna_test_reel',
        title: 'Mbilu Yanga',
        genre: 'Amapiano',
        language: 'Tshivenḓa',
        musical: MusicalDna(bpm: 112, key: 'F# Minor', energyBracket: 'mid', durationSec: 180),
        vocals: VocalsDna(deliveryMode: 'melodic', gender: 'female', energy: 'mid'),
        visualTheme: VisualThemeDna(mood: 'Soulful sunset', comfyPrompt: 'Warm lighting', seed: 42),
        alignment: [
          LyricWordTimestamp(word: 'Ndi', start: 1.0, end: 1.4, stanzaIndex: 0),
          LyricWordTimestamp(word: 'mufunwa', start: 1.5, end: 2.1, stanzaIndex: 0),
        ],
      );
    });

    test('Initial state defaults are properly configured', () {
      final state = notifier.state;
      expect(state.dna, isNull);
      expect(state.typographyPreset, equals(LyricTypographyPreset.kineticBounce));
      expect(state.durationPreset, equals(DurationPreset.reel30s));
      expect(state.isPlaying, isFalse);
      expect(state.isExporting, isFalse);
    });

    test('initializeWithDna populates state and clamps bounds', () {
      notifier.initializeWithDna(
        dna: sampleDna,
        audioUrl: 'https://r2.vhunambi.com/audio.mp3',
        coverArtUrl: 'https://r2.vhunambi.com/cover_9_16.png',
      );

      expect(notifier.state.dna?.id, equals('dna_test_reel'));
      expect(notifier.state.audioUrl, equals('https://r2.vhunambi.com/audio.mp3'));
      expect(notifier.state.coverArtUrl, equals('https://r2.vhunambi.com/cover_9_16.png'));
      expect(notifier.state.words.length, equals(2));
      expect(notifier.state.startSeconds, equals(0.0));
      expect(notifier.state.endSeconds, equals(30.0));
      // Amapiano smart defaults
      expect(notifier.state.typographyPreset, equals(LyricTypographyPreset.luminousGlow));
      expect(notifier.state.effects.bassPulse, isTrue);
      expect(notifier.state.effects.kenBurnsMotion, isTrue);
    });

    test('initializeWithDna applies smart defaults for Gqom and Traditional Soul', () {
      final gqomDna = sampleDna.copyWith(genre: 'Durban Dark Gqom');
      notifier.initializeWithDna(
        dna: gqomDna,
        audioUrl: 'https://r2.vhunambi.com/audio.mp3',
        coverArtUrl: 'https://r2.vhunambi.com/cover_9_16.png',
      );
      expect(notifier.state.typographyPreset, equals(LyricTypographyPreset.kineticBounce));
      expect(notifier.state.effects.filmGrain, isTrue);
      expect(notifier.state.effects.bassPulse, isTrue);

      final soulDna = sampleDna.copyWith(genre: 'Tshivenḓa Traditional Soul');
      notifier.initializeWithDna(
        dna: soulDna,
        audioUrl: 'https://r2.vhunambi.com/audio.mp3',
        coverArtUrl: 'https://r2.vhunambi.com/cover_9_16.png',
      );
      expect(notifier.state.typographyPreset, equals(LyricTypographyPreset.bantuCalligraphy));
      expect(notifier.state.effects.kenBurnsMotion, isTrue);
    });

    test('setPreset updates typography animation style', () {
      notifier.setPreset(LyricTypographyPreset.luminousGlow);
      expect(notifier.state.typographyPreset, equals(LyricTypographyPreset.luminousGlow));
    });

    test('setDurationPreset updates duration bounds accurately', () {
      notifier.initializeWithDna(
        dna: sampleDna,
        audioUrl: 'https://r2.vhunambi.com/audio.mp3',
        coverArtUrl: 'https://r2.vhunambi.com/cover.png',
      );

      notifier.setDurationPreset(DurationPreset.hook15s);
      expect(notifier.state.endSeconds, equals(15.0));

      notifier.setDurationPreset(DurationPreset.fullTrack);
      expect(notifier.state.endSeconds, equals(180.0));
    });

    test('setTrimBounds properly clamps start and end seconds', () {
      notifier.initializeWithDna(
        dna: sampleDna,
        audioUrl: 'https://r2.vhunambi.com/audio.mp3',
        coverArtUrl: 'https://r2.vhunambi.com/cover.png',
      );

      notifier.setTrimBounds(10.0, 45.0);
      expect(notifier.state.startSeconds, equals(10.0));
      expect(notifier.state.endSeconds, equals(45.0));
    });

    test('toggleEffect toggles visual overlays', () {
      expect(notifier.state.effects.filmGrain, isTrue);
      notifier.toggleEffect(filmGrain: false);
      expect(notifier.state.effects.filmGrain, isFalse);
    });

    test('playback position and play/pause controls function correctly', () {
      notifier.initializeWithDna(
        dna: sampleDna,
        audioUrl: 'https://r2.vhunambi.com/audio.mp3',
        coverArtUrl: 'https://r2.vhunambi.com/cover.png',
      );

      expect(notifier.state.isPlaying, isFalse);
      notifier.togglePlayPause();
      expect(notifier.state.isPlaying, isTrue);

      notifier.seekTo(12.5);
      expect(notifier.state.playbackPositionSec, equals(12.5));
    });

    test('exportVideo runs export lifecycle and updates file path', () async {
      notifier.initializeWithDna(
        dna: sampleDna,
        audioUrl: 'https://r2.vhunambi.com/audio.mp3',
        coverArtUrl: 'https://r2.vhunambi.com/cover.png',
      );

      await notifier.exportVideo();
      expect(notifier.state.isExporting, isFalse);
      expect(notifier.state.exportProgress, equals(1.0));
      expect(notifier.state.exportedFilePath, contains('.mp4'));
    });
  });
}
