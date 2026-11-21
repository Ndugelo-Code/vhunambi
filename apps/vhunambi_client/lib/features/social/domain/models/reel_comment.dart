import 'package:flutter/foundation.dart';

import 'kinetic_reaction.dart';

/// Sort ordering for Kinetic Post and Reel comment threads (`REQ-P69-THREAD-02`).
enum CommentSortOrder {
  mostRelevant('Most relevant'),
  newest('Newest');

  const CommentSortOrder(this.label);
  final String label;
}

/// Active reply target state when a user taps `Reply` on a comment (`REQ-P69-THREAD-03`).
@immutable
class ActiveReplyTarget {
  /// ID of the top-level root comment that owns the thread.
  final String parentCommentId;

  /// ID of the specific comment or child reply that was tapped.
  final String replyToCommentId;

  /// Normalized `@handle` of the user being replied to.
  final String replyToHandle;

  /// Display name of the user being replied to.
  final String replyToDisplayName;

  const ActiveReplyTarget({
    required this.parentCommentId,
    required this.replyToCommentId,
    required this.replyToHandle,
    required this.replyToDisplayName,
  });
}

/// A comment or nested reply posted to a Kinetic Post or Kinetic Reel (`REQ-COM-02`, `REQ-P69-THREAD-01`).
@immutable
class ReelComment {
  final String id;
  final String clipId;
  final String userId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final bool isCreator;
  final String text;
  final int likeCount;
  final bool isLikedByMe;

  /// Breakdown of multi-reactions by type (`EP-P73-MULTI-REACTIONS-API`).
  final Map<KineticReactionType, int> reactionCounts;

  /// Current listener's active reaction on this comment, if any.
  final KineticReactionType? myReaction;

  /// Optional external GIF URL attached to this comment (`REQ-P73-GIF-01`).
  final String? gifUrl;

  /// Optional Sovereign Sticker identifier attached to this comment (`REQ-P73-GIF-02`).
  final String? stickerId;

  /// Aspect ratio (width / height) for [gifUrl] or [stickerId] media.
  final double? mediaAspectRatio;

  /// The number of times this commenter has reacted/loved the reel or post.
  final int userReelLoves;

  /// Optional cultural gift emoji/code attached to this comment (`REQ-GFT-03`).
  final String? giftEmoji;

  /// Optional cultural gift name attached to this comment (`REQ-GFT-03`).
  final String? giftName;

  /// Optional parent comment ID when this comment is a nested reply (`REQ-P69-THREAD-01`).
  final String? parentCommentId;

  /// Optional `@handle` of the user this reply is directed to (`REQ-P69-THREAD-01`).
  final String? replyToHandle;

  final DateTime createdAt;

  const ReelComment({
    required this.id,
    required this.clipId,
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.isCreator = false,
    required this.text,
    this.likeCount = 0,
    this.isLikedByMe = false,
    this.reactionCounts = const <KineticReactionType, int>{},
    this.myReaction,
    this.gifUrl,
    this.stickerId,
    this.mediaAspectRatio,
    this.userReelLoves = 0,
    this.giftEmoji,
    this.giftName,
    this.parentCommentId,
    this.replyToHandle,
    required this.createdAt,
  });

  /// True when this comment is a child reply to a top-level comment.
  bool get isReply => parentCommentId != null && parentCommentId!.isNotEmpty;

  /// True when this comment carries a GIF or Sovereign Sticker attachment.
  bool get hasMedia =>
      (gifUrl != null && gifUrl!.trim().isNotEmpty) ||
      (stickerId != null && stickerId!.trim().isNotEmpty);

  /// Total reaction count across all taxonomy types, preserving legacy likes.
  int get totalReactionCount {
    if (reactionCounts.isEmpty) return likeCount;
    final sum = reactionCounts.values.fold<int>(0, (a, b) => a + b);
    return sum > likeCount ? sum : likeCount;
  }

  ReelComment copyWith({
    String? id,
    String? clipId,
    String? userId,
    String? username,
    String? displayName,
    String? avatarUrl,
    bool? isCreator,
    String? text,
    int? likeCount,
    bool? isLikedByMe,
    Map<KineticReactionType, int>? reactionCounts,
    KineticReactionType? myReaction,
    bool clearMyReaction = false,
    String? gifUrl,
    String? stickerId,
    double? mediaAspectRatio,
    int? userReelLoves,
    String? giftEmoji,
    String? giftName,
    String? parentCommentId,
    String? replyToHandle,
    DateTime? createdAt,
  }) {
    return ReelComment(
      id: id ?? this.id,
      clipId: clipId ?? this.clipId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isCreator: isCreator ?? this.isCreator,
      text: text ?? this.text,
      likeCount: likeCount ?? this.likeCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      reactionCounts: reactionCounts ?? this.reactionCounts,
      myReaction: clearMyReaction ? null : (myReaction ?? this.myReaction),
      gifUrl: gifUrl ?? this.gifUrl,
      stickerId: stickerId ?? this.stickerId,
      mediaAspectRatio: mediaAspectRatio ?? this.mediaAspectRatio,
      userReelLoves: userReelLoves ?? this.userReelLoves,
      giftEmoji: giftEmoji ?? this.giftEmoji,
      giftName: giftName ?? this.giftName,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      replyToHandle: replyToHandle ?? this.replyToHandle,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'clipId': clipId,
    'userId': userId,
    'username': username,
    'displayName': displayName,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    'isCreator': isCreator,
    'text': text,
    'likeCount': likeCount,
    'isLikedByMe': isLikedByMe,
    'reactionCounts': KineticReactionType.encodeCounts(reactionCounts),
    if (myReaction != null) 'myReaction': myReaction!.wireId,
    if (gifUrl != null) 'gifUrl': gifUrl,
    if (stickerId != null) 'stickerId': stickerId,
    if (mediaAspectRatio != null) 'mediaAspectRatio': mediaAspectRatio,
    'userReelLoves': userReelLoves,
    if (giftEmoji != null) 'giftEmoji': giftEmoji,
    if (giftName != null) 'giftName': giftName,
    if (parentCommentId != null) 'parentCommentId': parentCommentId,
    if (replyToHandle != null) 'replyToHandle': replyToHandle,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ReelComment.fromJson(Map<String, dynamic> json) {
    final rawParent =
        (json['parentCommentId'] ?? json['parent_comment_id']) as String?;
    final rawReplyHandle =
        (json['replyToHandle'] ?? json['reply_to_handle']) as String?;
    final rawGif = (json['gifUrl'] ?? json['gif_url']) as String?;
    final rawSticker = (json['stickerId'] ?? json['sticker_id']) as String?;
    final parsedMyReaction = KineticReactionType.fromWire(
      json['myReaction'] ?? json['my_reaction'],
    );
    final parsedCounts = KineticReactionType.parseCounts(
      json['reactionCounts'] ??
          json['reaction_counts'] ??
          json['reaction_counts_json'],
    );
    final parsedLikeCount =
        (json['likeCount'] as num?)?.toInt() ??
        (json['likes_count'] as num?)?.toInt() ??
        0;
    final parsedLiked =
        (json['isLikedByMe'] as bool?) ?? (parsedMyReaction != null);
    return ReelComment(
      id: (json['id'] ?? '').toString(),
      clipId: (json['clipId'] ?? json['clip_id'] ?? json['postId'] ?? '')
          .toString(),
      userId: (json['userId'] ?? json['user_id'] ?? 'u_listener').toString(),
      username: (json['username'] ?? 'listener').toString().replaceFirst(
        RegExp(r'^@+'),
        '',
      ),
      displayName: (json['displayName'] ?? json['display_name'] ?? 'Listener')
          .toString(),
      avatarUrl: json['avatarUrl'] as String? ?? json['avatar_url'] as String?,
      isCreator:
          (json['isCreator'] as bool?) ??
          (json['is_creator'] as bool?) ??
          false,
      text: (json['text'] ?? json['content'] ?? '').toString(),
      likeCount: parsedLikeCount,
      isLikedByMe: parsedLiked,
      reactionCounts: parsedCounts,
      myReaction: parsedMyReaction,
      gifUrl: rawGif != null && rawGif.trim().isNotEmpty ? rawGif.trim() : null,
      stickerId: rawSticker != null && rawSticker.trim().isNotEmpty
          ? rawSticker.trim()
          : null,
      mediaAspectRatio:
          ((json['mediaAspectRatio'] ?? json['media_aspect_ratio']) as num?)
              ?.toDouble(),
      userReelLoves:
          (json['userReelLoves'] as num?)?.toInt() ??
          (json['user_reel_loves'] as num?)?.toInt() ??
          0,
      giftEmoji: json['giftEmoji'] as String? ?? json['gift_emoji'] as String?,
      giftName: json['giftName'] as String? ?? json['gift_name'] as String?,
      parentCommentId: rawParent != null && rawParent.trim().isNotEmpty
          ? rawParent.trim()
          : null,
      replyToHandle: rawReplyHandle != null && rawReplyHandle.trim().isNotEmpty
          ? rawReplyHandle.trim()
          : null,
      createdAt:
          DateTime.tryParse(
            (json['createdAt'] ?? json['created_at'] ?? '').toString(),
          ) ??
          DateTime.now(),
    );
  }

  /// Formatted relative timestamp (e.g., `'2m ago'`, `'3h ago'`, `'2d ago'`).
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${createdAt.day}/${createdAt.month}';
  }
}

/// Grouped parent comment node with its chronological child replies (`REQ-P69-THREAD-02`).
@immutable
class CommentThreadNode {
  final ReelComment parent;
  final List<ReelComment> replies;
  final bool isExpanded;

  const CommentThreadNode({
    required this.parent,
    this.replies = const <ReelComment>[],
    this.isExpanded = false,
  });

  int get replyCount => replies.length;

  /// Relevance score $S_{rel}(r)$ used under [CommentSortOrder.mostRelevant].
  double computeRelevanceScore(DateTime now) {
    final ageHours =
        now.difference(parent.createdAt).inMinutes.clamp(0, 999999) / 60.0;
    final recencyBonus = (12.0 - 0.25 * ageHours).clamp(0.0, 12.0);
    final creatorBonus = parent.isCreator ? 8.0 : 0.0;
    return (2.0 * parent.likeCount) +
        (3.5 * replies.length) +
        creatorBonus +
        (1.5 * parent.userReelLoves) +
        recencyBonus;
  }
}
