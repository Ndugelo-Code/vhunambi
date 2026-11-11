import 'package:flutter/foundation.dart';
import '../../../../shared/models/track.dart';
import '../../../collections/domain/models/collection_entity.dart';
import '../../../content_studio/domain/models/song_metadata_dna.dart';
import '../../../social/domain/models/published_clip.dart';
import '../../../social/domain/models/stem_remix_context.dart';

/// Supported visual aspect ratios for Kinetic Posts (REQ-KPOST-ASPECT-01).
enum KineticPostAspectRatio {
  square1x1(1.0, '1:1 Square'),
  portrait4x5(4.0 / 5.0, '4:5 Portrait'),
  landscape16x9(16.0 / 9.0, '16:9 Wide');

  const KineticPostAspectRatio(this.ratio, this.label);
  final double ratio;
  final String label;
}

/// Static visual image attachment for Kinetic Posts (REQ-KPOST-IMAGE-01).
@immutable
class KineticPostImageAttachment {
  final String imageUrl;
  final bool isAiGeneratedVision;
  final String? visionPrompt;
  final KineticPostAspectRatio aspectRatio;

  const KineticPostImageAttachment({
    required this.imageUrl,
    this.isAiGeneratedVision = false,
    this.visionPrompt,
    this.aspectRatio = KineticPostAspectRatio.square1x1,
  });

  Map<String, dynamic> toJson() => {
    'imageUrl': imageUrl,
    'isAiGeneratedVision': isAiGeneratedVision,
    if (visionPrompt != null) 'visionPrompt': visionPrompt,
    'aspectRatio': aspectRatio.name,
  };

  factory KineticPostImageAttachment.fromJson(Map<String, dynamic> json) =>
      KineticPostImageAttachment(
        imageUrl: json['imageUrl'] as String,
        isAiGeneratedVision: json['isAiGeneratedVision'] as bool? ?? false,
        visionPrompt: json['visionPrompt'] as String?,
        aspectRatio: KineticPostAspectRatio.values.firstWhere(
          (e) => e.name == json['aspectRatio'],
          orElse: () => KineticPostAspectRatio.square1x1,
        ),
      );
}

/// Source type category for audio snippets attached to Kinetic Posts.
enum KineticAudioSourceType {
  librarySong('Song'),
  beatListing('Beat'),
  voiceSignature('Voice DNA'),
  sketchpadGroove('Groove');

  const KineticAudioSourceType(this.label);
  final String label;
}

/// Audio snippet attachment for Kinetic Posts (REQ-KPOST-AUDIO-01).
@immutable
class KineticPostAudioAttachment {
  final KineticAudioSourceType sourceType;
  final double clipStartSec;
  final double clipDurationSec;
  final String originalCreatorId;
  final String originalCreatorHandle;
  final bool allowSoundReuse;
  final bool allowRepost;

  const KineticPostAudioAttachment({
    this.sourceType = KineticAudioSourceType.librarySong,
    this.clipStartSec = 0.0,
    this.clipDurationSec = 30.0,
    required this.originalCreatorId,
    required this.originalCreatorHandle,
    this.allowSoundReuse = true,
    this.allowRepost = true,
  });

  Map<String, dynamic> toJson() => {
    'sourceType': sourceType.name,
    'clipStartSec': clipStartSec,
    'clipDurationSec': clipDurationSec,
    'originalCreatorId': originalCreatorId,
    'originalCreatorHandle': originalCreatorHandle,
    'allowSoundReuse': allowSoundReuse,
    'allowRepost': allowRepost,
  };

  factory KineticPostAudioAttachment.fromJson(Map<String, dynamic> json) =>
      KineticPostAudioAttachment(
        sourceType: KineticAudioSourceType.values.firstWhere(
          (e) => e.name == json['sourceType'],
          orElse: () => KineticAudioSourceType.librarySong,
        ),
        clipStartSec: (json['clipStartSec'] as num?)?.toDouble() ?? 0.0,
        clipDurationSec: (json['clipDurationSec'] as num?)?.toDouble() ?? 30.0,
        originalCreatorId: json['originalCreatorId'] as String? ?? '',
        originalCreatorHandle: json['originalCreatorHandle'] as String? ?? '',
        allowSoundReuse: json['allowSoundReuse'] as bool? ?? true,
        allowRepost: json['allowRepost'] as bool? ?? true,
      );
}

/// Strict media validation guard (REQ-KPOST-NO-MP4).
/// Rejects all video formats (.mp4, .mov, etc.) while allowing static image files.
bool isAllowedKineticPostMedia(String pathOrMime) {
  final lower = pathOrMime.toLowerCase();
  // Reject video formats outright
  if (lower.endsWith('.mp4') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.webm') ||
      lower.endsWith('.mkv') ||
      lower.startsWith('video/')) {
    return false;
  }
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp') ||
      lower.startsWith('image/');
}

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

  /// Phase 37 Lineage & Co-Creation Fields (REQ-RMX-MODEL-01)
  final RemixCreationMode? remixMode;
  final String? parentClipId;
  final String? parentTrackTitle;
  final String? parentCreatorId;
  final String? parentCreatorHandle;
  final int remixGenerationDepth;
  final List<SplitParticipant> coCreationSplits;

  /// Phase 38 Kinetic Posts & Visual-Sonic Attachments (REQ-KPOST-01..04)
  final KineticPostImageAttachment? imageAttachment;
  final List<KineticPostImageAttachment> imageAttachments;
  final KineticPostAudioAttachment? audioAttachment;
  final String? repostedFromPostId;
  final String? repostedFromCreatorHandle;
  final String? quoteComment;
  final int repostCount;
  final AudioProvenanceType provenanceType;
  final int cosignCount;
  final bool isCosigned;

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
    this.remixMode,
    this.parentClipId,
    this.parentTrackTitle,
    this.parentCreatorId,
    this.parentCreatorHandle,
    this.remixGenerationDepth = 0,
    this.coCreationSplits = const [],
    this.imageAttachment,
    this.imageAttachments = const [],
    this.audioAttachment,
    this.repostedFromPostId,
    this.repostedFromCreatorHandle,
    this.quoteComment,
    this.repostCount = 0,
    this.provenanceType = AudioProvenanceType.hybridCoCreation,
    this.cosignCount = 0,
    this.isCosigned = false,
  });

  /// Whether this post is a remix of another creator's work.
  bool get isRemix => parentClipId != null && parentClipId!.isNotEmpty;

  /// Whether this post is a repost/quote of another post.
  bool get isRepost =>
      repostedFromPostId != null && repostedFromPostId!.isNotEmpty;

  /// Whether this post has any static visual attachments.
  bool get hasVisuals => imageAttachments.isNotEmpty || imageAttachment != null;

  /// Unified list of all image attachments (handling both multi and single).
  List<KineticPostImageAttachment> get allImageAttachments {
    if (imageAttachments.isNotEmpty) return imageAttachments;
    if (imageAttachment != null) return [imageAttachment!];
    return const [];
  }

  /// Effective visual aspect ratio for rendering the Zone 3 canvas.
  KineticPostAspectRatio get effectiveAspectRatio =>
      allImageAttachments.isNotEmpty
      ? allImageAttachments.first.aspectRatio
      : KineticPostAspectRatio.square1x1;

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
    remixMode: remixMode,
    parentClipId: parentClipId,
    parentTrackTitle: parentTrackTitle,
    parentCreatorId: parentCreatorId,
    parentCreatorHandle: parentCreatorHandle,
    remixGenerationDepth: remixGenerationDepth,
    coCreationSplits: coCreationSplits,
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
    RemixCreationMode? remixMode,
    String? parentClipId,
    String? parentTrackTitle,
    String? parentCreatorId,
    String? parentCreatorHandle,
    int? remixGenerationDepth,
    List<SplitParticipant>? coCreationSplits,
    KineticPostImageAttachment? imageAttachment,
    List<KineticPostImageAttachment>? imageAttachments,
    KineticPostAudioAttachment? audioAttachment,
    String? repostedFromPostId,
    String? repostedFromCreatorHandle,
    String? quoteComment,
    int? repostCount,
    AudioProvenanceType? provenanceType,
    int? cosignCount,
    bool? isCosigned,
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
      remixMode: remixMode ?? this.remixMode,
      parentClipId: parentClipId ?? this.parentClipId,
      parentTrackTitle: parentTrackTitle ?? this.parentTrackTitle,
      parentCreatorId: parentCreatorId ?? this.parentCreatorId,
      parentCreatorHandle: parentCreatorHandle ?? this.parentCreatorHandle,
      remixGenerationDepth: remixGenerationDepth ?? this.remixGenerationDepth,
      coCreationSplits: coCreationSplits ?? this.coCreationSplits,
      imageAttachment: imageAttachment ?? this.imageAttachment,
      imageAttachments: imageAttachments ?? this.imageAttachments,
      audioAttachment: audioAttachment ?? this.audioAttachment,
      repostedFromPostId: repostedFromPostId ?? this.repostedFromPostId,
      repostedFromCreatorHandle:
          repostedFromCreatorHandle ?? this.repostedFromCreatorHandle,
      quoteComment: quoteComment ?? this.quoteComment,
      repostCount: repostCount ?? this.repostCount,
      provenanceType: provenanceType ?? this.provenanceType,
      cosignCount: cosignCount ?? this.cosignCount,
      isCosigned: isCosigned ?? this.isCosigned,
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
        other.isFollowingCreator == isFollowingCreator &&
        other.repostedFromPostId == repostedFromPostId &&
        other.repostCount == repostCount;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'creatorId': creatorId,
    'creatorName': creatorName,
    'creatorHandle': creatorHandle,
    'creatorAvatarUrl': creatorAvatarUrl,
    'isCreatorVerified': isCreatorVerified,
    'publishedAt': publishedAt.toIso8601String(),
    'location': location,
    'caption': caption,
    'trackId': track.id,
    'trackTitle': track.title,
    'track': track.toJson(),
    'likeCount': likeCount,
    'isLikedByMe': isLikedByMe,
    'commentCount': commentCount,
    'remixCount': remixCount,
    'tipCountCoins': tipCountCoins,
    'isFollowingCreator': isFollowingCreator,
    'remixMode': remixMode?.name,
    'parentClipId': parentClipId,
    'parentTrackTitle': parentTrackTitle,
    'parentCreatorId': parentCreatorId,
    'parentCreatorHandle': parentCreatorHandle,
    'remixGenerationDepth': remixGenerationDepth,
    'coCreationSplits': coCreationSplits.map((e) => e.toJson()).toList(),
    'imageAttachment': imageAttachment?.toJson(),
    'imageAttachments': imageAttachments.map((e) => e.toJson()).toList(),
    'audioAttachment': audioAttachment?.toJson(),
    'repostedFromPostId': repostedFromPostId,
    'repostedFromCreatorHandle': repostedFromCreatorHandle,
    'quoteComment': quoteComment,
    'repostCount': repostCount,
    'provenanceType': provenanceType.name,
    'cosignCount': cosignCount,
    'isCosigned': isCosigned,
  };

  factory SocialMusicPost.fromJson(Map<String, dynamic> json) {
    final rawTrack = json['track'];
    final resolvedTrack = rawTrack is Map
        ? Track.fromJson(Map<String, dynamic>.from(rawTrack))
        : Track(
            id: (json['trackId'] ?? json['id'] ?? '').toString(),
            title: (json['trackTitle'] ?? 'Untitled Track').toString(),
            creatorName: (json['creatorName'] ?? 'Vhunambi Creator').toString(),
            creatorHandle: json['creatorHandle'] as String?,
            genre: (json['genre'] ?? 'Amapiano').toString(),
            duration: const Duration(minutes: 3),
          );

    final rawImage = json['imageAttachment'];
    final rawImages = json['imageAttachments'] as List<dynamic>?;
    final rawAudio = json['audioAttachment'];
    final rawSplits = json['coCreationSplits'] as List<dynamic>?;
    final rawRemixMode = json['remixMode'] as String?;
    final rawProvenance = json['provenanceType'] as String?;

    return SocialMusicPost(
      id: (json['id'] ?? '').toString(),
      creatorId: (json['creatorId'] ?? '').toString(),
      creatorName: (json['creatorName'] ?? 'Creator').toString(),
      creatorHandle: (json['creatorHandle'] ?? '@creator').toString(),
      creatorAvatarUrl: json['creatorAvatarUrl'] as String?,
      isCreatorVerified: json['isCreatorVerified'] as bool? ?? false,
      publishedAt:
          DateTime.tryParse((json['publishedAt'] ?? '').toString()) ??
          DateTime.now(),
      location: json['location'] as String? ?? 'South Africa',
      caption: json['caption'] as String? ?? '',
      track: resolvedTrack,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      isLikedByMe: json['isLikedByMe'] as bool? ?? false,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      remixCount: (json['remixCount'] as num?)?.toInt() ?? 0,
      tipCountCoins: (json['tipCountCoins'] as num?)?.toInt() ?? 0,
      isFollowingCreator: json['isFollowingCreator'] as bool? ?? false,
      remixMode: rawRemixMode != null
          ? RemixCreationMode.fromWire(rawRemixMode)
          : null,
      parentClipId: json['parentClipId'] as String?,
      parentTrackTitle: json['parentTrackTitle'] as String?,
      parentCreatorId: json['parentCreatorId'] as String?,
      parentCreatorHandle: json['parentCreatorHandle'] as String?,
      remixGenerationDepth:
          (json['remixGenerationDepth'] as num?)?.toInt() ?? 0,
      coCreationSplits: rawSplits != null
          ? rawSplits
                .whereType<Map<dynamic, dynamic>>()
                .map(
                  (s) =>
                      SplitParticipant.fromJson(Map<String, dynamic>.from(s)),
                )
                .toList(growable: false)
          : const [],
      imageAttachment: rawImage is Map
          ? KineticPostImageAttachment.fromJson(
              Map<String, dynamic>.from(rawImage),
            )
          : null,
      imageAttachments: rawImages != null
          ? rawImages
                .whereType<Map<dynamic, dynamic>>()
                .map(
                  (e) => KineticPostImageAttachment.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList(growable: false)
          : const [],
      audioAttachment: rawAudio is Map
          ? KineticPostAudioAttachment.fromJson(
              Map<String, dynamic>.from(rawAudio),
            )
          : null,
      repostedFromPostId: json['repostedFromPostId'] as String?,
      repostedFromCreatorHandle: json['repostedFromCreatorHandle'] as String?,
      quoteComment: json['quoteComment'] as String?,
      repostCount: (json['repostCount'] as num?)?.toInt() ?? 0,
      provenanceType: rawProvenance != null
          ? AudioProvenanceType.values.firstWhere(
              (e) => e.name == rawProvenance,
              orElse: () => AudioProvenanceType.hybridCoCreation,
            )
          : AudioProvenanceType.hybridCoCreation,
      cosignCount: (json['cosignCount'] as num?)?.toInt() ?? 0,
      isCosigned: json['isCosigned'] as bool? ?? false,
    );
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
    repostedFromPostId,
    repostCount,
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
      imageAttachment: const KineticPostImageAttachment(
        imageUrl: 'https://cdn.vhunambi.com/covers/ndo-mufuna.jpg',
        aspectRatio: KineticPostAspectRatio.portrait4x5,
      ),
      audioAttachment: const KineticPostAudioAttachment(
        sourceType: KineticAudioSourceType.librarySong,
        clipStartSec: 30.0,
        clipDurationSec: 30.0,
        originalCreatorId: 'creator_makhadzi',
        originalCreatorHandle: '@makhadzi',
      ),
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
      repostCount: 14,
      tipCountCoins: 1250,
      isFollowingCreator: true,
    ),
    SocialMusicPost(
      id: 'post_001_remix_fifi',
      creatorId: 'creator_fifi',
      creatorName: 'Fifi Vocals',
      creatorHandle: '@fifi_vocals',
      isCreatorVerified: true,
      publishedAt: now.subtract(const Duration(minutes: 45)),
      location: 'Pretoria, Gauteng',
      caption:
          'Dropped my open verse on @makhadzi\'s Ndo Mufuna Matibe! Scale locked with Venda depressor guard 🔥 70/30 split active!',
      remixMode: RemixCreationMode.openVerseVocal,
      parentClipId: 'post_001',
      parentTrackTitle: 'Ndo Mufuna Matibe',
      parentCreatorId: 'creator_makhadzi',
      parentCreatorHandle: '@makhadzi',
      remixGenerationDepth: 1,
      coCreationSplits: const [
        SplitParticipant(
          name: 'Fifi Vocals',
          role: 'Vocalist (Remixer)',
          sharePercent: 70.0,
          creatorId: 'creator_fifi',
          handle: '@fifi_vocals',
        ),
        SplitParticipant(
          name: 'Makhadzi',
          role: 'Original Producer',
          sharePercent: 30.0,
          creatorId: 'creator_makhadzi',
          handle: '@makhadzi',
        ),
      ],
      imageAttachment: const KineticPostImageAttachment(
        imageUrl: 'https://cdn.vhunambi.com/covers/ndo-mufuna.jpg',
        aspectRatio: KineticPostAspectRatio.portrait4x5,
      ),
      audioAttachment: const KineticPostAudioAttachment(
        sourceType: KineticAudioSourceType.librarySong,
        clipStartSec: 0.0,
        clipDurationSec: 30.0,
        originalCreatorId: 'creator_fifi',
        originalCreatorHandle: '@fifi_vocals',
      ),
      track: const Track(
        id: 'exp_track_remix_001',
        title: 'Ndo Mufuna Matibe (Open Verse)',
        creatorName: 'Fifi Vocals ft. Makhadzi',
        creatorHandle: '@fifi_vocals',
        genre: 'Amapiano',
        language: 'isiZulu',
        duration: Duration(minutes: 2, seconds: 45),
        audioUrl: 'https://cdn.vhunambi.com/audio/ndo-mufuna-verse.mp3',
        coverUrl: 'https://cdn.vhunambi.com/covers/ndo-mufuna.jpg',
        likeCount: 620,
        playCount: 4310,
      ),
      likeCount: 620,
      commentCount: 28,
      remixCount: 5,
      repostCount: 3,
      tipCountCoins: 350,
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
      imageAttachment: const KineticPostImageAttachment(
        imageUrl: 'https://cdn.vhunambi.com/covers/grateful.jpg',
        aspectRatio: KineticPostAspectRatio.square1x1,
      ),
      audioAttachment: const KineticPostAudioAttachment(
        sourceType: KineticAudioSourceType.sketchpadGroove,
        clipStartSec: 15.0,
        clipDurationSec: 30.0,
        originalCreatorId: 'creator_sigwa',
        originalCreatorHandle: '@sigwa_inaf',
      ),
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
      repostCount: 8,
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
      imageAttachment: const KineticPostImageAttachment(
        imageUrl: 'https://cdn.vhunambi.com/covers/durban-bass.jpg',
        aspectRatio: KineticPostAspectRatio.landscape16x9,
      ),
      audioAttachment: const KineticPostAudioAttachment(
        sourceType: KineticAudioSourceType.beatListing,
        clipStartSec: 0.0,
        clipDurationSec: 45.0,
        originalCreatorId: 'creator_djvibe',
        originalCreatorHandle: '@djvibe',
      ),
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
      repostCount: 12,
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
      imageAttachment: null,
      imageAttachments: const [],
      audioAttachment: const KineticPostAudioAttachment(
        sourceType: KineticAudioSourceType.voiceSignature,
        clipStartSec: 0.0,
        clipDurationSec: 30.0,
        originalCreatorId: 'creator_ndugelo',
        originalCreatorHandle: '@ndugelo',
      ),
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
      repostCount: 5,
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
      imageAttachment: const KineticPostImageAttachment(
        imageUrl: 'https://cdn.vhunambi.com/covers/afro-sunset.jpg',
        aspectRatio: KineticPostAspectRatio.square1x1,
      ),
      audioAttachment: const KineticPostAudioAttachment(
        sourceType: KineticAudioSourceType.librarySong,
        clipStartSec: 20.0,
        clipDurationSec: 30.0,
        originalCreatorId: 'creator_fifi',
        originalCreatorHandle: '@fifi',
      ),
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
      repostCount: 2,
      tipCountCoins: 150,
      isFollowingCreator: false,
    ),
  ];
}
