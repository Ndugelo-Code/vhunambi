import 'package:flutter/foundation.dart';
import '../../../../shared/models/track.dart';
import '../../../content_studio/domain/models/song_metadata_dna.dart';
import '../../../social/domain/models/published_clip.dart';

/// Represents a creator's social music post on the Explore feed (REQ-EXP-FEED-01).
/// Combines creator identity, context story caption, embedded playable audio,
/// and full social engagement metrics (like, comment, remix in studio, tip).
@immutable
class SocialMusicPost {
  final String id;
  final String creatorId;
  final String creatorName;
  final String creatorHandle;
  final String? creatorAvatarUrl;
  final bool isCreatorVerified;
  final DateTime publishedAt;
  final String location;
  final String caption;
  final Track track;
  final int likeCount;
  final bool isLikedByMe;
  final int commentCount;
  final int remixCount;
  final int tipCountCoins;
  final bool isFollowingCreator;

  const SocialMusicPost({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.creatorHandle,
    this.creatorAvatarUrl,
    this.isCreatorVerified = false,
    required this.publishedAt,
    this.location = 'South Africa',
    required this.caption,
    required this.track,
    this.likeCount = 0,
    this.isLikedByMe = false,
    this.commentCount = 0,
    this.remixCount = 0,
    this.tipCountCoins = 0,
    this.isFollowingCreator = false,
  });

  /// Human-readable relative publication timestamp.
  String get relativeTimeAgo {
    final diff = DateTime.now().difference(publishedAt);
    if (diff.inMinutes < 60) {
      final mins = diff.inMinutes;
      return mins <= 1 ? 'just now' : '${mins}m ago';
    }
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  /// Synthesizes a native [PublishedClip] entity to power comments, tipping,
  /// and interactive bottom sheets without duplicating code.
  PublishedClip get toPublishedClip => PublishedClip(
        id: id,
        trackId: track.id,
        creatorId: creatorId,
        creatorUsername: creatorHandle.replaceFirst('@', ''),
        creatorDisplayName: creatorName,
        creatorAvatarUrl: creatorAvatarUrl,
        isCreatorVerified: isCreatorVerified,
        title: track.title,
        caption: caption,
        genre: track.genre,
        audioUrl: track.audioUrl ?? '',
        coverUrl: track.coverUrl ?? '',
        dna: SongMetadataDna.fromTrackInfo(
          id: track.id,
          title: track.title,
          genre: track.genre,
          language: track.language,
          durationSec: track.duration.inSeconds,
        ),
        likeCount: likeCount,
        commentCount: commentCount,
        remixCount: remixCount,
        isLikedByMe: isLikedByMe,
        publishedAt: publishedAt,
      );

  SocialMusicPost copyWith({
    String? id,
    String? creatorId,
    String? creatorName,
    String? creatorHandle,
    String? creatorAvatarUrl,
    bool? isCreatorVerified,
    DateTime? publishedAt,
    String? location,
    String? caption,
    Track? track,
    int? likeCount,
    bool? isLikedByMe,
    int? commentCount,
    int? remixCount,
    int? tipCountCoins,
    bool? isFollowingCreator,
  }) {
    return SocialMusicPost(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      creatorHandle: creatorHandle ?? this.creatorHandle,
      creatorAvatarUrl: creatorAvatarUrl ?? this.creatorAvatarUrl,
      isCreatorVerified: isCreatorVerified ?? this.isCreatorVerified,
      publishedAt: publishedAt ?? this.publishedAt,
      location: location ?? this.location,
      caption: caption ?? this.caption,
      track: track ?? this.track,
      likeCount: likeCount ?? this.likeCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      commentCount: commentCount ?? this.commentCount,
      remixCount: remixCount ?? this.remixCount,
      tipCountCoins: tipCountCoins ?? this.tipCountCoins,
      isFollowingCreator: isFollowingCreator ?? this.isFollowingCreator,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SocialMusicPost &&
        other.id == id &&
        other.creatorId == creatorId &&
        other.creatorName == creatorName &&
        other.creatorHandle == creatorHandle &&
        other.creatorAvatarUrl == creatorAvatarUrl &&
        other.isCreatorVerified == isCreatorVerified &&
        other.publishedAt == publishedAt &&
        other.location == location &&
        other.caption == caption &&
        other.track == track &&
        other.likeCount == likeCount &&
        other.isLikedByMe == isLikedByMe &&
        other.commentCount == commentCount &&
        other.remixCount == remixCount &&
        other.tipCountCoins == tipCountCoins &&
        other.isFollowingCreator == isFollowingCreator;
  }

  @override
  int get hashCode => Object.hash(
        id,
        creatorId,
        creatorName,
        creatorHandle,
        creatorAvatarUrl,
        isCreatorVerified,
        publishedAt,
        location,
        caption,
        track,
        likeCount,
        isLikedByMe,
        commentCount,
        remixCount,
        tipCountCoins,
        isFollowingCreator,
      );
}

/// Seeded social music posts for the V4.1 Explore Social Feed.
List<SocialMusicPost> seedSocialPosts() {
  final now = DateTime.now();

  return [
    SocialMusicPost(
      id: 'post_001',
      creatorId: 'creator_makhadzi',
      creatorName: 'Makhadzi',
      creatorHandle: '@makhadzi',
      isCreatorVerified: true,
      publishedAt: now.subtract(const Duration(hours: 2)),
      location: 'Limpopo / Polokwane',
      caption:
          'Late night studio session testing the Venda Folk LoRA & sub-bass log drum slide 🔥 What do you think of this rhythm? Stems are open for remix!',
      track: const Track(
        id: 'exp_track_002',
        title: 'Ndo Mufuna Matibe',
        creatorName: 'Makhadzi',
        creatorHandle: '@makhadzi',
        genre: 'Amapiano',
        language: 'Tshivenḓa',
        duration: Duration(minutes: 3, seconds: 18),
        audioUrl: 'https://cdn.vhunambi.com/audio/ndo-mufuna-matibe.mp3',
        coverUrl: 'https://cdn.vhunambi.com/covers/ndo-mufuna.jpg',
        likeCount: 1840,
        playCount: 12450,
        trendingRank: 1,
      ),
      likeCount: 1840,
      commentCount: 96,
      remixCount: 42,
      tipCountCoins: 1250,
      isFollowingCreator: true,
    ),
    SocialMusicPost(
      id: 'post_002',
      creatorId: 'creator_sigwa',
      creatorName: 'Sigwa & Inaf',
      creatorHandle: '@sigwa_inaf',
      isCreatorVerified: true,
      publishedAt: now.subtract(const Duration(hours: 4)),
      location: 'Soweto, Gauteng',
      caption:
          'Morning prayer groove. Grateful for life and music. Tuned in F# Minor on Private School Rhodes keys 🎹',
      track: const Track(
        id: 'exp_track_001',
        title: 'Grateful in the Light',
        creatorName: 'Sigwa & Inaf',
        creatorHandle: '@sigwa_inaf',
        genre: 'Amapiano',
        language: 'English',
        duration: Duration(minutes: 3, seconds: 36),
        audioUrl: 'https://cdn.vhunambi.com/audio/grateful-in-the-light.mp3',
        coverUrl: 'https://cdn.vhunambi.com/covers/grateful.jpg',
        likeCount: 1002,
        playCount: 8430,
        isNew: true,
      ),
      likeCount: 1002,
      commentCount: 48,
      remixCount: 18,
      tipCountCoins: 480,
      isFollowingCreator: false,
    ),
    SocialMusicPost(
      id: 'post_003',
      creatorId: 'creator_djvibe',
      creatorName: 'DJ Vibe',
      creatorHandle: '@djvibe',
      isCreatorVerified: true,
      publishedAt: now.subtract(const Duration(hours: 7)),
      location: 'Durban, KwaZulu-Natal',
      caption:
          'Durban Midnight Bass! Raw 128 BPM Gqom energy straight out of the underground warehouse scene. Turn your bass up!',
      track: const Track(
        id: 'exp_track_004',
        title: 'Durban Midnight Bass',
        creatorName: 'DJ Vibe',
        creatorHandle: '@djvibe',
        genre: 'Gqom',
        language: 'Instrumental',
        duration: Duration(minutes: 2, seconds: 30),
        audioUrl: 'https://cdn.vhunambi.com/audio/durban-midnight-bass.mp3',
        coverUrl: 'https://cdn.vhunambi.com/covers/durban-bass.jpg',
        likeCount: 780,
        playCount: 5670,
        trendingRank: 3,
      ),
      likeCount: 780,
      commentCount: 31,
      remixCount: 25,
      tipCountCoins: 310,
      isFollowingCreator: false,
    ),
    SocialMusicPost(
      id: 'post_004',
      creatorId: 'creator_ndugelo',
      creatorName: 'Ndugelo',
      creatorHandle: '@ndugelo',
      isCreatorVerified: false,
      publishedAt: now.subtract(const Duration(hours: 12)),
      location: 'Venda, Limpopo',
      caption:
          'Tshikona rhythms blended with 8-step acoustic log drum arpeggios. Heritage crate roots meet modern AI synthesis.',
      track: const Track(
        id: 'exp_track_006',
        title: 'Maskandi Strings of Natal',
        creatorName: 'Ndugelo',
        creatorHandle: '@ndugelo',
        genre: 'Maskandi',
        language: 'isiZulu',
        duration: Duration(minutes: 3, seconds: 45),
        audioUrl: 'https://cdn.vhunambi.com/audio/maskandi-strings.mp3',
        coverUrl: 'https://cdn.vhunambi.com/covers/maskandi.jpg',
        likeCount: 654,
        playCount: 4320,
      ),
      likeCount: 654,
      commentCount: 27,
      remixCount: 14,
      tipCountCoins: 210,
      isFollowingCreator: false,
    ),
    SocialMusicPost(
      id: 'post_005',
      creatorId: 'creator_fifi',
      creatorName: 'Fifi',
      creatorHandle: '@fifi',
      isCreatorVerified: false,
      publishedAt: now.subtract(const Duration(days: 1)),
      location: 'Johannesburg',
      caption:
          'Sunset melodies inspired by the golden hour over Maboneng. Vocals generated with Soweto Youth Choir archetype 🌅',
      track: const Track(
        id: 'exp_track_007',
        title: 'Afro Sunset Melodies',
        creatorName: 'Fifi',
        creatorHandle: '@fifi',
        genre: 'Afro House',
        language: 'English',
        duration: Duration(minutes: 4, seconds: 12),
        audioUrl: 'https://cdn.vhunambi.com/audio/afro-sunset.mp3',
        coverUrl: 'https://cdn.vhunambi.com/covers/afro-sunset.jpg',
        likeCount: 432,
        playCount: 3120,
      ),
      likeCount: 432,
      commentCount: 19,
      remixCount: 8,
      tipCountCoins: 150,
      isFollowingCreator: false,
    ),
  ];
}
