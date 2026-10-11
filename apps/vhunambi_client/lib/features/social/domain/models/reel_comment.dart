import 'package:flutter/foundation.dart';

/// A comment posted to a published kinetic reel in the Vhunambi social network.
///
/// Follows TikTok-familiar UX with commenter identity, comment text, comment-level
/// hearts, and the [userReelLoves] counter reflecting honest community participation
/// (e.g., "Loved this reel 5x ❤️"). Reference: REQ-COM-02.
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

  /// The number of times this commenter has reacted/loved the reel itself
  /// (honest community badge, e.g. 5x ❤️).
  final int userReelLoves;

  /// Optional cultural gift emoji attached to this comment (REQ-GFT-03).
  final String? giftEmoji;

  /// Optional cultural gift name attached to this comment (REQ-GFT-03).
  final String? giftName;

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
    this.userReelLoves = 0,
    this.giftEmoji,
    this.giftName,
    required this.createdAt,
  });

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
    int? userReelLoves,
    String? giftEmoji,
    String? giftName,
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
      userReelLoves: userReelLoves ?? this.userReelLoves,
      giftEmoji: giftEmoji ?? this.giftEmoji,
      giftName: giftName ?? this.giftName,
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
        'userReelLoves': userReelLoves,
        if (giftEmoji != null) 'giftEmoji': giftEmoji,
        if (giftName != null) 'giftName': giftName,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ReelComment.fromJson(Map<String, dynamic> json) {
    return ReelComment(
      id: json['id'] as String,
      clipId: json['clipId'] as String,
      userId: json['userId'] as String,
      username: json['username'] as String,
      displayName: json['displayName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      isCreator: (json['isCreator'] as bool?) ?? false,
      text: json['text'] as String,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      isLikedByMe: (json['isLikedByMe'] as bool?) ?? false,
      userReelLoves: (json['userReelLoves'] as num?)?.toInt() ?? 0,
      giftEmoji: json['giftEmoji'] as String?,
      giftName: json['giftName'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Formatted relative timestamp (e.g., '2m ago', '3h ago', '2d ago').
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${createdAt.day}/${createdAt.month}';
  }
}
