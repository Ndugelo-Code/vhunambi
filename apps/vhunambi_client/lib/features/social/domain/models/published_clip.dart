import 'package:flutter/foundation.dart';
import '../../../content_studio/domain/models/song_metadata_dna.dart';

/// Immutable visibility of a published clip (REQ-SOC-02).
enum ClipVisibility { public, followers }

/// A song clip published to the Vhunambi social creator network.
///
/// Powers the zero-video [KineticReelsModal] feed and the creator profile
/// "Clips & Reels" grid. The [dna] field carries the immutable Song DNA that
/// drives native `KineticPreviewCanvas` playback — no MP4 is streamed in-house
/// (REQ-SOC-26).
///
/// Mirrors the backend `PublishedClipDto`
/// (`apps/vhunambi_api/src/modules/social/social_types.ts`).
@immutable
class PublishedClip {
  final String id;
  final String trackId;
  final String creatorId;
  final String creatorUsername;
  final String creatorDisplayName;
  final String? creatorAvatarUrl;
  final bool isCreatorVerified;

  final String title;
  final String caption;
  final List<String> tags;
  final String genre;
  final String audioUrl;
  final String coverUrl;

  /// The immutable Song DNA powering zero-video vector canvas playback.
  final SongMetadataDna dna;

  final int playCount;
  final int likeCount;
  final int commentCount;
  final int remixCount;
  final bool isLikedByMe;
  final bool isSavedByMe;

  final DateTime publishedAt;

  const PublishedClip({
    required this.id,
    required this.trackId,
    required this.creatorId,
    required this.creatorUsername,
    required this.creatorDisplayName,
    this.creatorAvatarUrl,
    this.isCreatorVerified = false,
    required this.title,
    this.caption = '',
    this.tags = const [],
    required this.genre,
    required this.audioUrl,
    required this.coverUrl,
    required this.dna,
    this.playCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    this.remixCount = 0,
    this.isLikedByMe = false,
    this.isSavedByMe = false,
    required this.publishedAt,
  });

  PublishedClip copyWith({
    int? playCount,
    int? likeCount,
    int? commentCount,
    int? remixCount,
    bool? isLikedByMe,
    bool? isSavedByMe,
  }) {
    return PublishedClip(
      id: id,
      trackId: trackId,
      creatorId: creatorId,
      creatorUsername: creatorUsername,
      creatorDisplayName: creatorDisplayName,
      creatorAvatarUrl: creatorAvatarUrl,
      isCreatorVerified: isCreatorVerified,
      title: title,
      caption: caption,
      tags: tags,
      genre: genre,
      audioUrl: audioUrl,
      coverUrl: coverUrl,
      dna: dna,
      playCount: playCount ?? this.playCount,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      remixCount: remixCount ?? this.remixCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      isSavedByMe: isSavedByMe ?? this.isSavedByMe,
      publishedAt: publishedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'trackId': trackId,
        'creatorId': creatorId,
        'creatorUsername': creatorUsername,
        'creatorDisplayName': creatorDisplayName,
        'creatorAvatarUrl': creatorAvatarUrl,
        'isCreatorVerified': isCreatorVerified,
        'title': title,
        'caption': caption,
        'tags': tags,
        'genre': genre,
        'audioUrl': audioUrl,
        'coverUrl': coverUrl,
        'dna': dna.toJson(),
        'playCount': playCount,
        'likeCount': likeCount,
        'commentCount': commentCount,
        'remixCount': remixCount,
        'isLikedByMe': isLikedByMe,
        'isSavedByMe': isSavedByMe,
        'publishedAt': publishedAt.toIso8601String(),
      };

  factory PublishedClip.fromJson(Map<String, dynamic> json) {
    return PublishedClip(
      id: json['id'] as String,
      trackId: json['trackId'] as String? ?? '',
      creatorId: json['creatorId'] as String? ?? '',
      creatorUsername: json['creatorUsername'] as String? ?? 'creator',
      creatorDisplayName: json['creatorDisplayName'] as String? ?? 'Creator',
      creatorAvatarUrl: json['creatorAvatarUrl'] as String?,
      isCreatorVerified: json['isCreatorVerified'] as bool? ?? false,
      title: json['title'] as String? ?? 'Untitled',
      caption: json['caption'] as String? ?? '',
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const [],
      genre: json['genre'] as String? ?? 'Amapiano',
      audioUrl: json['audioUrl'] as String? ?? '',
      coverUrl: json['coverUrl'] as String? ?? '',
      dna: SongMetadataDna.fromJson(json['dna'] as Map<String, dynamic>),
      playCount: json['playCount'] as int? ?? 0,
      likeCount: json['likeCount'] as int? ?? 0,
      commentCount: json['commentCount'] as int? ?? 0,
      remixCount: json['remixCount'] as int? ?? 0,
      isLikedByMe: json['isLikedByMe'] as bool? ?? false,
      isSavedByMe: json['isSavedByMe'] as bool? ?? false,
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Deep link to this clip on the public web (REQ-SOC-17).
  String get shareUrl =>
      'https://vhunambi.com/@$creatorUsername/reels/$id';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublishedClip &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          trackId == other.trackId &&
          creatorId == other.creatorId &&
          title == other.title &&
          genre == other.genre &&
          playCount == other.playCount &&
          likeCount == other.likeCount &&
          commentCount == other.commentCount &&
          remixCount == other.remixCount &&
          isLikedByMe == other.isLikedByMe &&
          isSavedByMe == other.isSavedByMe;

  @override
  int get hashCode => Object.hash(
        id,
        trackId,
        creatorId,
        title,
        genre,
        playCount,
        likeCount,
        isLikedByMe,
        isSavedByMe,
      );
}
