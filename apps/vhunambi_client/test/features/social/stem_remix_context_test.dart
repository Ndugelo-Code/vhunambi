import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/song_metadata_dna.dart';
import 'package:vhunambi_client/features/social/domain/models/published_clip.dart';
import 'package:vhunambi_client/features/social/domain/models/stem_remix_context.dart';
import 'package:vhunambi_client/features/social/presentation/providers/stem_remix_provider.dart';

SongMetadataDna _buildTestDna(String id, String title) {
  return SongMetadataDna(
    id: id,
    title: title,
    genre: 'Amapiano',
    language: 'Tshivenḓa',
    musical: const MusicalDna(
      bpm: 112,
      key: 'F#m',
      energyBracket: 'mid',
      durationSec: 180,
    ),
    vocals: const VocalsDna(
      deliveryMode: 'melodic',
      gender: 'female',
      energy: 'mid',
    ),
    visualTheme: const VisualThemeDna(
      mood: 'Sunrise',
      comfyPrompt: 'makhado sunrise amapiano',
      seed: 12345,
      aspectRatio: '9:16',
    ),
  );
}

void main() {
  group('StemRemixContext Model', () {
    test('attributionLineage formats creator and track title properly', () {
      const context = StemRemixContext(
        parentClipId: 'clip_orig_101',
        parentCreatorUsername: 'makhadzi',
        parentCreatorDisplayName: 'Makhadzi',
        parentTrackTitle: 'Makhado Sunrise',
        parentCoverArtUrl: 'https://example.com/cover.jpg',
      );

      expect(context.attributionLineage,
          '🔁 Remixed from @makhadzi\'s "Makhado Sunrise"');
    });

    test('serializes and deserializes lossless JSON', () {
      const context = StemRemixContext(
        parentClipId: 'clip_orig_101',
        parentCreatorUsername: 'makhadzi',
        parentCreatorDisplayName: 'Makhadzi',
        parentTrackTitle: 'Makhado Sunrise',
        parentCoverArtUrl: 'https://example.com/cover.jpg',
      );

      final json = context.toJson();
      final fromJson = StemRemixContext.fromJson(json);

      expect(fromJson.parentClipId, context.parentClipId);
      expect(fromJson.parentCreatorUsername, context.parentCreatorUsername);
      expect(fromJson.parentTrackTitle, context.parentTrackTitle);
      expect(fromJson.attributionLineage, context.attributionLineage);
    });
  });

  group('PublishedClip Remix Lineage Extension', () {
    test('isRemix identifies remixed clips and preserves lineage', () {
      final originalClip = PublishedClip(
        id: 'clip_orig_101',
        trackId: 'trk_101',
        creatorId: 'c_makhadzi',
        creatorUsername: 'makhadzi',
        creatorDisplayName: 'Makhadzi',
        title: 'Makhado Sunrise',
        genre: 'Amapiano',
        audioUrl: 'https://example.com/audio.mp3',
        coverUrl: 'https://example.com/cover.jpg',
        dna: _buildTestDna('dna_101', 'Makhado Sunrise'),
        publishedAt: DateTime.now(),
      );

      expect(originalClip.isRemix, isFalse);
      expect(originalClip.remixedFromClipId, isNull);

      final remixedClip = originalClip.copyWith(
        id: 'clip_remix_202',
        title: 'Makhado Sunrise (Gqom Flip)',
        remixedFromClipId: 'clip_orig_101',
        remixAttribution: '🔁 Remixed from @makhadzi\'s "Makhado Sunrise"',
      );

      expect(remixedClip.isRemix, isTrue);
      expect(remixedClip.remixedFromClipId, 'clip_orig_101');
      expect(remixedClip.remixAttribution, contains('@makhadzi'));

      final json = remixedClip.toJson();
      final fromJson = PublishedClip.fromJson(json);
      expect(fromJson.isRemix, isTrue);
      expect(fromJson.remixedFromClipId, 'clip_orig_101');
      expect(fromJson.remixAttribution, remixedClip.remixAttribution);
    });
  });

  group('StemRemixNotifier & stemRemixProvider', () {
    test('initiateRemix sets active context and clearRemix resets to null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(stemRemixProvider), isNull);

      final clip = PublishedClip(
        id: 'clip_test_1',
        trackId: 'trk_1',
        creatorId: 'c_1',
        creatorUsername: 'sbu_gqom',
        creatorDisplayName: 'Sbu Gqom',
        title: 'Durban Storm',
        genre: 'Gqom',
        audioUrl: 'https://example.com/audio.mp3',
        coverUrl: 'https://example.com/cover.jpg',
        dna: _buildTestDna('dna_1', 'Durban Storm'),
        publishedAt: DateTime.now(),
      );

      container.read(stemRemixProvider.notifier).initiateRemix(clip);

      final state = container.read(stemRemixProvider);
      expect(state, isNotNull);
      expect(state!.parentClipId, clip.id);
      expect(state.parentCreatorUsername, 'sbu_gqom');
      expect(state.attributionLineage, contains('Durban Storm'));

      container.read(stemRemixProvider.notifier).clearRemix();
      expect(container.read(stemRemixProvider), isNull);
    });
  });
}
