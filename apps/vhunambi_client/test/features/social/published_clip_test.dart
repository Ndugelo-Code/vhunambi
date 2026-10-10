import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/song_metadata_dna.dart';
import 'package:vhunambi_client/features/social/domain/models/published_clip.dart';

SongMetadataDna _buildDna() {
  return SongMetadataDna(
    id: 'dna_test',
    title: 'Ndo Mufuna Matibe',
    genre: 'Amapiano',
    language: 'Tshivenḓa',
    musical: const MusicalDna(
      bpm: 113,
      key: 'Am',
      energyBracket: 'mid',
      durationSec: 198,
    ),
    vocals: const VocalsDna(
      deliveryMode: 'melodic',
      gender: 'female',
      energy: 'mid',
    ),
    visualTheme: const VisualThemeDna(
      mood: 'Cinematic',
      comfyPrompt: 'amapiano night drive',
      seed: 42,
      aspectRatio: '9:16',
    ),
  );
}

PublishedClip _buildClip() {
  return PublishedClip(
    id: 'clip_pub_1234',
    trackId: 'track_amapiano_101',
    creatorId: 'creator_makhadzi',
    creatorUsername: 'makhadzi',
    creatorDisplayName: 'Makhadzi',
    isCreatorVerified: true,
    title: 'Ndo Mufuna Matibe',
    caption: 'Late-night piano vibe',
    tags: const ['Amapiano', 'Tshivenḓa'],
    genre: 'Amapiano',
    audioUrl: 'https://cdn.vhunambi.com/social/track_amapiano_101.mp3',
    coverUrl: 'https://cdn.vhunambi.com/social/track_amapiano_101.jpg',
    dna: _buildDna(),
    playCount: 24500,
    likeCount: 1840,
    commentCount: 96,
    remixCount: 12,
    publishedAt: DateTime.utc(2026, 10, 10, 20, 0),
  );
}

/// Backend-normalized DNA JSON (social_service.normalizeDna output shape).
const Map<String, dynamic> _normalizedDnaJson = {
  'id': 'dna_venda_sunrise',
  'version': '1.0',
  'title': 'Venda Sunrise',
  'genre': 'Amapiano',
  'language': 'Tshivenḓa',
  'culturalContext': null,
  'musical': {
    'bpm': 112,
    'key': 'Am',
    'energyBracket': 'mid',
    'durationSec': 180,
  },
  'vocals': {
    'deliveryMode': 'melodic',
    'gender': 'male',
    'energy': 'mid',
    'loras': [],
  },
  'visualTheme': {
    'mood': 'Cinematic',
    'comfyPrompt': 'amapiano aesthetic',
    'negativePrompt': 'blurry',
    'seed': 42,
    'aspectRatio': '9:16',
  },
  'alignment': [],
};

void main() {
  group('PublishedClip domain model', () {
    test('constructs with documented defaults', () {
      final clip = PublishedClip(
        id: 'clip_1',
        trackId: 'track_1',
        creatorId: 'creator_1',
        creatorUsername: 'artist',
        creatorDisplayName: 'Artist',
        title: 'Song',
        genre: 'Gqom',
        audioUrl: 'https://cdn/1.mp3',
        coverUrl: 'https://cdn/1.jpg',
        dna: _buildDna(),
        publishedAt: DateTime.utc(2026, 10, 10, 20, 0),
      );
      expect(clip.tags, isEmpty);
      expect(clip.playCount, 0);
      expect(clip.likeCount, 0);
      expect(clip.isCreatorVerified, false);
      expect(clip.isLikedByMe, false);
      expect(clip.isSavedByMe, false);
    });

    test('copyWith toggles social counters while preserving identity', () {
      final clip = _buildClip();
      final liked = clip.copyWith(isLikedByMe: true, likeCount: 1841);
      expect(liked.isLikedByMe, true);
      expect(liked.likeCount, 1841);
      // Immutable fields preserved.
      expect(liked.id, clip.id);
      expect(liked.title, clip.title);
      expect(liked.dna, clip.dna);
      expect(liked.creatorUsername, clip.creatorUsername);
    });

    test('toJson -> fromJson round-trips losslessly', () {
      final clip = _buildClip();
      final restored = PublishedClip.fromJson(clip.toJson());
      expect(restored.id, clip.id);
      expect(restored.trackId, clip.trackId);
      expect(restored.title, clip.title);
      expect(restored.tags, clip.tags);
      expect(restored.genre, clip.genre);
      expect(restored.playCount, clip.playCount);
      expect(restored.likeCount, clip.likeCount);
      expect(restored.isLikedByMe, clip.isLikedByMe);
      expect(restored.dna.musical.bpm, clip.dna.musical.bpm);
      expect(restored.publishedAt, clip.publishedAt);
    });

    test('parses a backend-normalized DNA payload without throwing', () {
      final clip = PublishedClip.fromJson({
        'id': 'clip_pub_abc',
        'trackId': 'track_x',
        'creatorId': 'creator_makhadzi',
        'creatorUsername': 'makhadzi',
        'creatorDisplayName': 'Makhadzi',
        'title': 'Venda Sunrise',
        'genre': 'Amapiano',
        'audioUrl': 'https://cdn/x.mp3',
        'coverUrl': 'https://cdn/x.jpg',
        'dna': _normalizedDnaJson,
        'playCount': 0,
        'likeCount': 0,
        'publishedAt': '2026-10-10T20:00:00.000Z',
      });
      expect(clip.dna.musical.bpm, 112);
      expect(clip.dna.visualTheme.aspectRatio, '9:16');
      expect(clip.dna.vocals.deliveryMode, 'melodic');
    });

    test('shareUrl follows the /@username/reels/:id deep-link format', () {
      final clip = _buildClip();
      expect(clip.shareUrl, 'https://vhunambi.com/@makhadzi/reels/clip_pub_1234');
    });

    test('equality is keyed on identity + social counters', () {
      final a = _buildClip();
      final b = _buildClip();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.copyWith(playCount: 1), isNot(equals(a)));
    });
  });
}
