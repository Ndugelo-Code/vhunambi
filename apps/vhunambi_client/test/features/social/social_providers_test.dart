import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/song_metadata_dna.dart';
import 'package:vhunambi_client/features/content_studio/presentation/providers/content_studio_provider.dart';
import 'package:vhunambi_client/features/social/domain/models/published_clip.dart';
import 'package:vhunambi_client/features/social/presentation/providers/creator_clips_provider.dart';
import 'package:vhunambi_client/features/social/presentation/providers/social_feed_provider.dart';

ProviderContainer makeContainer() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

SongMetadataDna testDna() => SongMetadataDna(
      id: 'dna_test_pub',
      title: 'Makhado Nights',
      genre: 'Amapiano',
      language: 'Tshivenḓa',
      musical: const MusicalDna(
        bpm: 114,
        key: 'Am',
        energyBracket: 'mid',
        durationSec: 200,
      ),
      vocals: const VocalsDna(
        deliveryMode: 'melodic',
        gender: 'female',
        energy: 'mid',
      ),
      visualTheme: const VisualThemeDna(
        mood: 'Cinematic',
        comfyPrompt: 'amapiano night drive',
        seed: 7,
        aspectRatio: '9:16',
      ),
    );

void main() {
  group('SocialFeedNotifier', () {
    test('seeds a non-empty feed with unique clip ids', () {
      final container = makeContainer();
      final clips = container.read(socialFeedProvider).clips;
      expect(clips.length, greaterThanOrEqualTo(4));
      expect(clips.map((c) => c.id).toSet().length, clips.length,
          reason: 'clip ids must be unique');
      expect(clips.every((c) => c.dna.musical.bpm > 0), isTrue,
          reason: 'every seeded clip carries a compiled DNA');
    });

    test('prependClip injects at the head of the feed', () {
      final container = makeContainer();
      final before = container.read(socialFeedProvider).clips.length;

      final clip = PublishedClip(
        id: 'clip_test_head',
        trackId: 'track_head',
        creatorId: 'creator_makhadzi',
        creatorUsername: 'makhadzi',
        creatorDisplayName: 'Makhadzi',
        title: 'Head Clip',
        genre: 'Amapiano',
        audioUrl: 'https://cdn/head.mp3',
        coverUrl: 'https://cdn/head.jpg',
        dna: testDna(),
        publishedAt: DateTime.now(),
      );
      container.read(socialFeedProvider.notifier).prependClip(clip);

      final after = container.read(socialFeedProvider).clips;
      expect(after.length, before + 1);
      expect(after.first.id, 'clip_test_head');
    });

    test('toggleLike flips state and adjusts the count optimistically', () {
      final container = makeContainer();
      final target = container.read(socialFeedProvider).clips.first;
      final startLiked = target.isLikedByMe;
      final startCount = target.likeCount;

      container.read(socialFeedProvider.notifier).toggleLike(target.id);
      var current = container
          .read(socialFeedProvider)
          .clips
          .firstWhere((c) => c.id == target.id);
      expect(current.isLikedByMe, !startLiked);
      expect(current.likeCount, startCount + (startLiked ? -1 : 1));

      container.read(socialFeedProvider.notifier).toggleLike(target.id);
      current = container
          .read(socialFeedProvider)
          .clips
          .firstWhere((c) => c.id == target.id);
      expect(current.isLikedByMe, startLiked);
      expect(current.likeCount, startCount);
    });

    test('clipById resolves a seeded clip', () {
      final container = makeContainer();
      final first = container.read(socialFeedProvider).clips.first;
      final resolved =
          container.read(socialFeedProvider.notifier).clipById(first.id);
      expect(resolved?.id, first.id);
      expect(container.read(socialFeedProvider.notifier).clipById('nope'),
          isNull);
    });
  });

  group('creatorClipsFamilyProvider', () {
    test('filters the feed to a single creator', () {
      final container = makeContainer();
      final makhadzi =
          container.read(creatorClipsFamilyProvider('creator_makhadzi'));
      expect(makhadzi, isNotEmpty);
      expect(makhadzi.every((c) => c.creatorId == 'creator_makhadzi'), isTrue);

      final fifi = container.read(creatorClipsFamilyProvider('creator_fifi'));
      expect(fifi.every((c) => c.creatorId == 'creator_fifi'), isTrue);
      expect(
        fifi.map((c) => c.id).toSet().intersection(
              makhadzi.map((c) => c.id).toSet(),
            ),
        isEmpty,
      );
    });

    test('reacts to a newly prepended clip for that creator', () {
      final container = makeContainer();
      final before =
          container.read(creatorClipsFamilyProvider('creator_makhadzi')).length;
      container.read(socialFeedProvider.notifier).prependClip(
            PublishedClip(
              id: 'clip_reactive',
              trackId: 'track_reactive',
              creatorId: 'creator_makhadzi',
              creatorUsername: 'makhadzi',
              creatorDisplayName: 'Makhadzi',
              title: 'Reactive Clip',
              genre: 'Gqom',
              audioUrl: 'https://cdn/r.mp3',
              coverUrl: 'https://cdn/r.jpg',
              dna: testDna(),
              publishedAt: DateTime.now(),
            ),
          );
      final after =
          container.read(creatorClipsFamilyProvider('creator_makhadzi'));
      expect(after.length, before + 1);
    });
  });

  group('ContentStudioNotifier.publishClipToProfile', () {
    test('builds a clip, injects it into the feed, and exposes a share URL',
        () {
      final container = makeContainer();
      final studio = container.read(contentStudioProvider.notifier);
      studio.initializeWithDna(
        dna: testDna(),
        audioUrl: 'https://cdn/makhado-nights.mp3',
        coverArtUrl: 'https://cdn/makhado-nights.jpg',
      );

      final feedBefore = container.read(socialFeedProvider).clips.length;
      final clip = studio.publishClipToProfile(
        caption: 'Late-night session from Makhado 🔥',
        tags: const ['Amapiano', 'Tshivenḓa'],
      );

      expect(clip, isNotNull);
      expect(clip!.title, 'Makhado Nights');
      expect(clip.genre, 'Amapiano');
      expect(clip.tags, contains('Amapiano'));
      expect(clip.shareUrl, contains('/reels/'));

      final feedAfter = container.read(socialFeedProvider).clips;
      expect(feedAfter.length, feedBefore + 1);
      expect(feedAfter.first.id, clip.id);

      expect(container.read(contentStudioProvider).publishedShareUrl,
          clip.shareUrl);
    });

    test('returns null and flags an error when the session has no DNA', () {
      final container = makeContainer();
      final studio = container.read(contentStudioProvider.notifier);
      final clip = studio.publishClipToProfile(caption: 'orphan', tags: const []);
      expect(clip, isNull);
      expect(container.read(contentStudioProvider).errorMessage, isNotNull);
    });
  });
}

