import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import '../../../collections/domain/models/collection_entity.dart';
import '../../../content_studio/domain/models/content_studio_preset.dart';
import '../../../content_studio/domain/models/lyric_word_timestamp.dart';
import '../../../content_studio/domain/models/song_metadata_dna.dart';
import '../../../content_studio/domain/utils/lyric_karaoke_sanitizer.dart';
import 'kinetic_reaction.dart';
import 'stem_remix_context.dart';

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
  final String? videoUrl;
  final String mediaKind;
  final int audioStartMs;
  final int audioEndMs;
  final String effectPreset;
  final double effectIntensity;
  final String typographyPreset;
  final double speedRate;
  final String? stickerId;

  /// The immutable Song DNA powering zero-video vector canvas playback.
  final SongMetadataDna dna;

  final int playCount;
  final int likeCount;
  final int commentCount;
  final int remixCount;
  final bool isLikedByMe;
  final bool isSavedByMe;
  final Map<KineticReactionType, int> reactionCounts;
  final KineticReactionType? myReaction;

  /// The number of times the current user has loved this clip in multi-tap bursts.
  final int userReactionCount;

  /// Optional ID of the parent reel this clip was remixed from (REQ-RMX-03).
  final String? remixedFromClipId;

  /// Optional lineage attribution text (e.g., '🔁 Remixed from @makhadzi\'s "Makhado Sunrise"').
  final String? remixAttribution;

  /// Phase 37 Lineage & Co-Creation Fields (REQ-RMX-MODEL-01)
  final RemixCreationMode? remixMode;
  final String? parentClipId;
  final String? parentTrackTitle;
  final String? parentCreatorId;
  final String? parentCreatorHandle;
  final int remixGenerationDepth;
  final int remixChildrenCount;
  final List<SplitParticipant> coCreationSplits;

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
    this.videoUrl,
    this.mediaKind = 'artwork',
    this.audioStartMs = 0,
    this.audioEndMs = 30000,
    this.effectPreset = 'kinetic_gold',
    this.effectIntensity = 0.65,
    this.typographyPreset = 'kinetic_bounce',
    this.speedRate = 1.0,
    this.stickerId,
    required this.dna,
    this.playCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    this.remixCount = 0,
    this.isLikedByMe = false,
    this.isSavedByMe = false,
    this.reactionCounts = const <KineticReactionType, int>{},
    this.myReaction,
    this.userReactionCount = 0,
    this.remixedFromClipId,
    this.remixAttribution,
    this.remixMode,
    this.parentClipId,
    this.parentTrackTitle,
    this.parentCreatorId,
    this.parentCreatorHandle,
    this.remixGenerationDepth = 0,
    this.remixChildrenCount = 0,
    this.coCreationSplits = const [],
    required this.publishedAt,
  });

  /// Whether this clip was created as a remix of another creator's reel.
  bool get isRemix =>
      (remixedFromClipId != null && remixedFromClipId!.isNotEmpty) ||
      (parentClipId != null && parentClipId!.isNotEmpty);

  int get totalReactionCount {
    final sum = reactionCounts.values.fold<int>(
      0,
      (acc, v) => acc + (v > 0 ? v : 0),
    );
    return math.max(likeCount, sum);
  }

  PublishedClip copyWith({
    String? id,
    String? title,
    String? videoUrl,
    String? mediaKind,
    int? audioStartMs,
    int? audioEndMs,
    String? effectPreset,
    double? effectIntensity,
    String? typographyPreset,
    double? speedRate,
    String? stickerId,
    int? playCount,
    int? likeCount,
    int? commentCount,
    int? remixCount,
    bool? isLikedByMe,
    bool? isSavedByMe,
    Map<KineticReactionType, int>? reactionCounts,
    KineticReactionType? myReaction,
    bool clearMyReaction = false,
    int? userReactionCount,
    String? remixedFromClipId,
    String? remixAttribution,
    RemixCreationMode? remixMode,
    String? parentClipId,
    String? parentTrackTitle,
    String? parentCreatorId,
    String? parentCreatorHandle,
    int? remixGenerationDepth,
    int? remixChildrenCount,
    List<SplitParticipant>? coCreationSplits,
  }) {
    return PublishedClip(
      id: id ?? this.id,
      trackId: trackId,
      creatorId: creatorId,
      creatorUsername: creatorUsername,
      creatorDisplayName: creatorDisplayName,
      creatorAvatarUrl: creatorAvatarUrl,
      isCreatorVerified: isCreatorVerified,
      title: title ?? this.title,
      caption: caption,
      tags: tags,
      genre: genre,
      audioUrl: audioUrl,
      coverUrl: coverUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      mediaKind: mediaKind ?? this.mediaKind,
      audioStartMs: audioStartMs ?? this.audioStartMs,
      audioEndMs: audioEndMs ?? this.audioEndMs,
      effectPreset: effectPreset ?? this.effectPreset,
      effectIntensity: effectIntensity ?? this.effectIntensity,
      typographyPreset: typographyPreset ?? this.typographyPreset,
      speedRate: speedRate ?? this.speedRate,
      stickerId: stickerId ?? this.stickerId,
      dna: dna,
      playCount: playCount ?? this.playCount,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      remixCount: remixCount ?? this.remixCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      isSavedByMe: isSavedByMe ?? this.isSavedByMe,
      reactionCounts: reactionCounts ?? this.reactionCounts,
      myReaction: clearMyReaction ? null : (myReaction ?? this.myReaction),
      userReactionCount: userReactionCount ?? this.userReactionCount,
      remixedFromClipId: remixedFromClipId ?? this.remixedFromClipId,
      remixAttribution: remixAttribution ?? this.remixAttribution,
      remixMode: remixMode ?? this.remixMode,
      parentClipId: parentClipId ?? this.parentClipId,
      parentTrackTitle: parentTrackTitle ?? this.parentTrackTitle,
      parentCreatorId: parentCreatorId ?? this.parentCreatorId,
      parentCreatorHandle: parentCreatorHandle ?? this.parentCreatorHandle,
      remixGenerationDepth: remixGenerationDepth ?? this.remixGenerationDepth,
      remixChildrenCount: remixChildrenCount ?? this.remixChildrenCount,
      coCreationSplits: coCreationSplits ?? this.coCreationSplits,
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
    if (videoUrl != null) 'videoUrl': videoUrl,
    'mediaKind': mediaKind,
    'audioStartMs': audioStartMs,
    'audioEndMs': audioEndMs,
    'effectPreset': effectPreset,
    'effectIntensity': effectIntensity,
    'typographyPreset': typographyPreset,
    'speedRate': speedRate,
    if (stickerId != null) 'stickerId': stickerId,
    'dna': dna.toJson(),
    'playCount': playCount,
    'likeCount': likeCount,
    'commentCount': commentCount,
    'remixCount': remixCount,
    'isLikedByMe': isLikedByMe,
    'isSavedByMe': isSavedByMe,
    'reactionCounts': KineticReactionType.encodeCounts(reactionCounts),
    if (myReaction != null) 'myReaction': myReaction!.wireId,
    'userReactionCount': userReactionCount,
    if (remixedFromClipId != null) 'remixedFromClipId': remixedFromClipId,
    if (remixAttribution != null) 'remixAttribution': remixAttribution,
    if (remixMode != null) 'remixMode': remixMode!.wireValue,
    if (parentClipId != null) 'parentClipId': parentClipId,
    if (parentTrackTitle != null) 'parentTrackTitle': parentTrackTitle,
    if (parentCreatorId != null) 'parentCreatorId': parentCreatorId,
    if (parentCreatorHandle != null) 'parentCreatorHandle': parentCreatorHandle,
    'remixGenerationDepth': remixGenerationDepth,
    'remixChildrenCount': remixChildrenCount,
    'coCreationSplits': coCreationSplits.map((s) => s.toJson()).toList(),
    'publishedAt': publishedAt.toIso8601String(),
  };

  factory PublishedClip.fromJson(Map<String, dynamic> json) {
    final parentId =
        (json['parentClipId'] as String?) ??
        (json['remixedFromClipId'] as String?);
    final rawVideoUrl = (json['videoUrl'] ?? json['video_url'] ?? '')
        .toString()
        .trim();
    final normalizedVideoUrl = rawVideoUrl.isNotEmpty
        ? AppConstants.normalizeCloudMediaUrl(rawVideoUrl)
        : '';
    final parsedMyReaction = KineticReactionType.fromWire(
      json['myReaction'] ?? json['my_reaction'],
    );
    final parsedCounts = KineticReactionType.parseCounts(
      json['reactionCounts'] ??
          json['reaction_counts'] ??
          json['reaction_counts_json'],
    );
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
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [],
      genre: json['genre'] as String? ?? 'Amapiano',
      audioUrl: AppConstants.normalizeCloudMediaUrl(
        json['audioUrl'] as String? ?? '',
      ),
      coverUrl: AppConstants.normalizeCloudMediaUrl(
        json['coverUrl'] as String? ?? '',
      ),
      videoUrl: normalizedVideoUrl.isEmpty ? null : normalizedVideoUrl,
      mediaKind: (json['mediaKind'] ?? json['media_kind'] ?? 'artwork')
          .toString(),
      audioStartMs:
          ((json['audioStartMs'] ?? json['audio_start_ms']) as num?)?.toInt() ??
          0,
      audioEndMs:
          ((json['audioEndMs'] ?? json['audio_end_ms']) as num?)?.toInt() ??
          30000,
      effectPreset:
          (json['effectPreset'] ?? json['effect_preset'] ?? 'kinetic_gold')
              .toString(),
      effectIntensity:
          ((json['effectIntensity'] ?? json['effect_intensity']) as num?)
              ?.toDouble() ??
          0.65,
      typographyPreset:
          (json['typographyPreset'] ??
                  json['typography_preset'] ??
                  'kinetic_bounce')
              .toString(),
      speedRate:
          ((json['speedRate'] ?? json['speed_rate']) as num?)?.toDouble() ??
          1.0,
      stickerId: (json['stickerId'] ?? json['sticker_id']) as String?,
      dna: SongMetadataDna.fromJson(
        json['dna'] is Map
            ? Map<String, dynamic>.from(json['dna'] as Map)
            : const {},
      ),
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      remixCount: (json['remixCount'] as num?)?.toInt() ?? 0,
      isLikedByMe:
          ((json['isLikedByMe'] as bool?) ?? false) || parsedMyReaction != null,
      isSavedByMe: (json['isSavedByMe'] as bool?) ?? false,
      reactionCounts: parsedCounts,
      myReaction: parsedMyReaction,
      userReactionCount: (json['userReactionCount'] as num?)?.toInt() ?? 0,
      remixedFromClipId: parentId,
      remixAttribution: json['remixAttribution'] as String?,
      remixMode: json['remixMode'] != null
          ? RemixCreationMode.fromWire(json['remixMode'] as String?)
          : null,
      parentClipId: parentId,
      parentTrackTitle: json['parentTrackTitle'] as String?,
      parentCreatorId: json['parentCreatorId'] as String?,
      parentCreatorHandle: json['parentCreatorHandle'] as String?,
      remixGenerationDepth:
          (json['remixGenerationDepth'] as num?)?.toInt() ??
          (parentId != null ? 1 : 0),
      remixChildrenCount: (json['remixChildrenCount'] as num?)?.toInt() ?? 0,
      coCreationSplits: (json['coCreationSplits'] as List<dynamic>? ?? const [])
          .map(
            (s) =>
                SplitParticipant.fromJson(Map<String, dynamic>.from(s as Map)),
          )
          .toList(),
      publishedAt:
          DateTime.tryParse(json['publishedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Deep link to this clip on the public web (REQ-SOC-17).
  String get shareUrl => 'https://vhunambi.com/@$creatorUsername/reels/$id';

  /// Synchronized lyric word timestamps for 60 FPS `KineticPreviewCanvas` playback.
  ///
  /// Uses `dna.alignment` when populated; otherwise synthesizes rhythm-locked
  /// African karaoke stanzas from the track title and genre so every reel
  /// displays moving kinetic typography.
  List<LyricWordTimestamp> get effectiveLyrics {
    final sanitizedDna = LyricKaraokeSanitizer.sanitizeAlignment(dna.alignment);
    if (sanitizedDna.isNotEmpty) return sanitizedDna;

    final titleWords = title
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final tokens = <String>[
      'Woza',
      ...titleWords,
      'Vhunambi',
      genre,
      'Sgubhu',
      ...titleWords,
      'Ndi',
      'Mufunwa',
      'Vibe',
    ];

    const culturalSet = <String>{
      'woza',
      'vhunambi',
      'sgubhu',
      'ndo',
      'mufuna',
      'matibe',
      'mufunwa',
      'ndi',
      'venda',
      'makhado',
      'amapiano',
      'gqom',
      'maskandi',
    };

    final stepSec = (60.0 / dna.musical.bpm.clamp(80, 160)).clamp(0.42, 0.75);
    return List<LyricWordTimestamp>.generate(tokens.length, (i) {
      final start = double.parse((i * stepSec).toStringAsFixed(2));
      final end = double.parse(((i + 1) * stepSec - 0.04).toStringAsFixed(2));
      final word = tokens[i];
      final cleanLower = word
          .replaceAll(RegExp(r'[^a-zA-Zḓṋḽṱ]'), '')
          .toLowerCase();
      return LyricWordTimestamp(
        word: word,
        start: start,
        end: end,
        stanzaIndex: i ~/ 5,
        phoneticStress: (i % 2 == 0) ? 0.90 : 0.65,
        isCulturalIdiom: culturalSet.contains(cleanLower),
      );
    });
  }

  /// Genre-aware default typography preset for 60 FPS reel rendering.
  LyricTypographyPreset get effectiveTypographyPreset {
    final g = genre.toLowerCase();
    if (g.contains('amapiano')) return LyricTypographyPreset.luminousGlow;
    if (g.contains('gqom') || g.contains('drill')) {
      return LyricTypographyPreset.kineticBounce;
    }
    if (g.contains('maskandi') ||
        g.contains('venda') ||
        g.contains('traditional')) {
      return LyricTypographyPreset.bantuCalligraphy;
    }
    return LyricTypographyPreset.luminousGlow;
  }

  /// Genre-aware atmospheric shader configuration for 60 FPS reel rendering.
  AtmosphericEffects get effectiveAtmosphericEffects {
    final g = genre.toLowerCase();
    if (g.contains('gqom') || g.contains('drill')) {
      return const AtmosphericEffects(
        filmGrain: true,
        bassPulse: true,
        kenBurnsMotion: true,
      );
    }
    return const AtmosphericEffects(
      filmGrain: false,
      bassPulse: true,
      kenBurnsMotion: true,
    );
  }

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
