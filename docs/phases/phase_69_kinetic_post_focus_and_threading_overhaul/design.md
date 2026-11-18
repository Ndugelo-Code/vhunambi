# Phase 69 — Kinetic Post Focus Domain, Threaded Replies & Feed Card Refinement Design Specification

> **Document ID:** `VHUNAMBI-SPEC-P69-DESIGN-V1`  
> **Architectural Target:** `apps/vhunambi_client` (`ExploreSocialPostCard`, `KineticPostFocusView`, `KineticPostSonicPill`, `RepostKineticPostSheet`, `KineticPostComposerBar`, `ReelComment`, `ReelsCommentsNotifier`, `ThreadedCommentsSection`, `StudioReactionComposerBar`, `ReelsCommentSheet`, `HttpExploreRepository`, `NotificationDeepLinkRouter`, `ExploreView`, `ExploreDiscoveryDrawerSheet`) + `apps/vhunambi_api` (`explore_routes.ts`, `social_routes.ts`, `social_service.ts`, `vhunambi_db.ts`, `edge_persistence_bridge.ts`) + `supabase/migrations/20261118000001_phase69_kinetic_posts_and_threaded_comments.sql`  
> **Argon Standard Compliance:** 100% Compilable Production Dart, TypeScript & SQL — Zero Placeholders, Zero Raw Emojis (`STD-UIUX-001`), Zero Stock `Icons.*`, 100% Dynamic `*Of(context)` Dual-Theme Tokens

---

## 1. Mathematical & Structural Contracts

### 1.1 Comment Thread Partitioning & Relevance Ranking ($S_{\text{rel}}$)
Given a flat list of `ReelComment` items $C(P)$ for post or clip $P$:
1. **Root Partition ($C_{\text{root}}$) & Child Map ($\text{Replies}(r)$):**
   - Root comments: $r \in C(P)$ where `r.parentCommentId == null || r.parentCommentId!.isEmpty` (or where `r.parentCommentId` does not match any existing comment ID in $C(P)$).
   - Child replies for root $r$: all $c \in C(P)$ with `c.parentCommentId == r.id`, sorted ascending by `c.createdAt` so conversation replies read top-to-bottom.
2. **Relevance Score ($S_{\text{rel}}(r)$):**
   $$S_{\text{rel}}(r) = 2.0 \cdot r.\text{likeCount} + 3.5 \cdot |\text{Replies}(r)| + 8.0 \cdot \mathbb{I}(r.\text{isCreator}) + 1.5 \cdot r.\text{userReelLoves} + \max\left(0.0,\, 12.0 - 0.25 \cdot \frac{t_{\text{now}} - r.\text{createdAt}}{3600\text{s}}\right)$$
   - `CommentSortOrder.mostRelevant`: sorts root nodes by $S_{\text{rel}}(r)$ descending, breaking ties by `r.createdAt` descending.
   - `CommentSortOrder.newest`: sorts root nodes strictly by `r.createdAt` descending.

### 1.2 Viewport & Touch-Target Geometry
- **Minimum Interactive Hit Target:** Every interactive pill, icon button, `Reply` button, `View N replies` toggle, sort selector, and reaction chip enforces `BoxConstraints(minWidth: 44, minHeight: 44)`.
- **Nested Reply Indentation:** `36.0dp` left indent with a `1.5dp` vertical connector line (`AppColors.borderSubtleOf(context)`) and `14.0dp` avatar radius (`28.0dp` diameter) vs `16.0dp` (`32.0dp` diameter) for root comments.
- **Sticky Composer Dock (`KineticPostFocusView`):** Positioned in `Scaffold.bottomNavigationBar` (or `Column` bottom child outside `Expanded(child: CustomScrollView)`), padded by `MediaQuery.viewInsetsOf(context).bottom` so the keyboard lifts the composer cleanly without covering the scrollable post media.

---

## 2. Pure Dart Domain Models (`ReelComment`, `CommentSortOrder`, `CommentThreadNode`, `ActiveReplyTarget`)

### 2.1 `apps/vhunambi_client/lib/features/social/domain/models/reel_comment.dart`
Complete replacement adding `parentCommentId`, `replyToHandle`, `isReply`, `CommentSortOrder`, `CommentThreadNode`, and `ActiveReplyTarget`:

```dart
import 'package:flutter/foundation.dart';

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
    this.userReelLoves = 0,
    this.giftEmoji,
    this.giftName,
    this.parentCommentId,
    this.replyToHandle,
    required this.createdAt,
  });

  /// True when this comment is a child reply to a top-level comment.
  bool get isReply => parentCommentId != null && parentCommentId!.isNotEmpty;

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
    return ReelComment(
      id: (json['id'] ?? '').toString(),
      clipId: (json['clipId'] ?? json['clip_id'] ?? json['postId'] ?? '').toString(),
      userId: (json['userId'] ?? json['user_id'] ?? 'u_listener').toString(),
      username: (json['username'] ?? 'listener')
          .toString()
          .replaceFirst(RegExp(r'^@+'), ''),
      displayName: (json['displayName'] ?? json['display_name'] ?? 'Listener').toString(),
      avatarUrl: json['avatarUrl'] as String? ?? json['avatar_url'] as String?,
      isCreator: (json['isCreator'] as bool?) ??
          (json['is_creator'] as bool?) ??
          false,
      text: (json['text'] ?? json['content'] ?? '').toString(),
      likeCount:
          (json['likeCount'] as num?)?.toInt() ??
          (json['likes_count'] as num?)?.toInt() ??
          0,
      isLikedByMe: (json['isLikedByMe'] as bool?) ?? false,
      userReelLoves:
          (json['userReelLoves'] as num?)?.toInt() ??
          (json['user_reel_loves'] as num?)?.toInt() ??
          0,
      giftEmoji: json['giftEmoji'] as String? ?? json['gift_emoji'] as String?,
      giftName: json['giftName'] as String? ?? json['gift_name'] as String?,
      parentCommentId:
          rawParent != null && rawParent.trim().isNotEmpty ? rawParent.trim() : null,
      replyToHandle: rawReplyHandle != null && rawReplyHandle.trim().isNotEmpty
          ? rawReplyHandle.trim()
          : null,
      createdAt: DateTime.tryParse(
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

  /// Relevance score $S_{\text{rel}}(r)$ used under [CommentSortOrder.mostRelevant].
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
```

---

## 3. Threaded Comments Provider & Seed Alignment (`ReelsCommentsNotifier`)

### 3.1 `apps/vhunambi_client/lib/features/social/presentation/providers/reels_comments_provider.dart`
Upgrades `ReelsCommentsState` and `ReelsCommentsNotifier` with:
- `sortOrdersByClipId` (`Map<String, CommentSortOrder>`)
- `activeReplyByClipId` (`Map<String, ActiveReplyTarget?>`)
- `expandedParentIdsByClipId` (`Map<String, Set<String>>`)
- `threadsForClip(String clipId)` implementing the exact $S_{\text{rel}}(r)$ and chronological reply tree projection
- `addComment` accepting `parentCommentId`, `replyToHandle`, `contentCreatorId`, `isKineticPost`, automatically setting `isCreator`, auto-expanding the replied-to parent thread, calling `socialFeedPostsProvider.notifier.incrementCommentCount(clipId)` for Kinetic Posts, and emitting a `/post/$clipId` notification
- Seeded multi-turn threads for `post_001`, `post_001_remix_fifi`, `post_002`, `post_003`, `post_004`, and `post_005` (with zero raw Unicode emojis in the new seeded post threads while keeping `clip_seed_01` / `clip_seed_02` intact for reel tests).

```dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_providers.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/sovereign_domain_repositories.dart';
import '../../../explore/presentation/providers/explore_providers.dart';
import '../../../notifications/domain/models/notification_entity.dart';
import '../../../notifications/domain/models/notification_enums.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/models/reel_comment.dart';
import '../../domain/repositories/i_social_repository.dart';
import 'social_repository_provider.dart';

/// State containing all comments, active reply targets, expanded threads, and sort modes (`REQ-P69-THREAD-02`).
class ReelsCommentsState {
  final Map<String, List<ReelComment>> commentsByClipId;
  final Map<String, CommentSortOrder> sortByClipId;
  final Map<String, ActiveReplyTarget?> activeReplyByClipId;
  final Map<String, Set<String>> expandedParentsByClipId;
  final bool isLoading;

  const ReelsCommentsState({
    this.commentsByClipId = const {},
    this.sortByClipId = const {},
    this.activeReplyByClipId = const {},
    this.expandedParentsByClipId = const {},
    this.isLoading = false,
  });

  CommentSortOrder sortOrderFor(String clipId) =>
      sortByClipId[clipId] ?? CommentSortOrder.mostRelevant;

  ActiveReplyTarget? activeReplyFor(String clipId) =>
      activeReplyByClipId[clipId];

  Set<String> expandedParentsFor(String clipId) =>
      expandedParentsByClipId[clipId] ?? const <String>{};

  /// Projects flat comments for [clipId] into sorted [CommentThreadNode] trees.
  List<CommentThreadNode> buildThreads(String clipId, {DateTime? now}) {
    final all = commentsByClipId[clipId] ?? const <ReelComment>[];
    if (all.isEmpty) return const <CommentThreadNode>[];

    final effectiveNow = now ?? DateTime.now();
    final sortOrder = sortOrderFor(clipId);
    final expandedSet = expandedParentsFor(clipId);

    final byId = <String, ReelComment>{for (final c in all) c.id: c};
    final rootComments = <ReelComment>[];
    final repliesByParentId = <String, List<ReelComment>>{};

    for (final c in all) {
      final parentId = c.parentCommentId;
      if (parentId != null &&
          parentId.isNotEmpty &&
          parentId != c.id &&
          byId.containsKey(parentId)) {
        // Resolve to top-most root if someone replied to a child ID
        final parentObj = byId[parentId]!;
        final rootId = (parentObj.parentCommentId != null &&
                parentObj.parentCommentId!.isNotEmpty &&
                byId.containsKey(parentObj.parentCommentId))
            ? parentObj.parentCommentId!
            : parentId;
        repliesByParentId.putIfAbsent(rootId, () => <ReelComment>[]).add(c);
      } else {
        rootComments.add(c);
      }
    }

    final nodes = <CommentThreadNode>[
      for (final root in rootComments)
        () {
          final children = List<ReelComment>.from(
            repliesByParentId[root.id] ?? const <ReelComment>[],
          )..sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return CommentThreadNode(
            parent: root,
            replies: children,
            isExpanded: expandedSet.contains(root.id),
          );
        }(),
    ];

    if (sortOrder == CommentSortOrder.newest) {
      nodes.sort((a, b) => b.parent.createdAt.compareTo(a.parent.createdAt));
    } else {
      nodes.sort((a, b) {
        final sA = a.computeRelevanceScore(effectiveNow);
        final sB = b.computeRelevanceScore(effectiveNow);
        final cmp = sB.compareTo(sA);
        if (cmp != 0) return cmp;
        return b.parent.createdAt.compareTo(a.parent.createdAt);
      });
    }

    return List<CommentThreadNode>.unmodifiable(nodes);
  }

  ReelsCommentsState copyWith({
    Map<String, List<ReelComment>>? commentsByClipId,
    Map<String, CommentSortOrder>? sortByClipId,
    Map<String, ActiveReplyTarget?>? activeReplyByClipId,
    Map<String, Set<String>>? expandedParentsByClipId,
    bool? isLoading,
  }) {
    return ReelsCommentsState(
      commentsByClipId: commentsByClipId ?? this.commentsByClipId,
      sortByClipId: sortByClipId ?? this.sortByClipId,
      activeReplyByClipId: activeReplyByClipId ?? this.activeReplyByClipId,
      expandedParentsByClipId:
          expandedParentsByClipId ?? this.expandedParentsByClipId,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ReelsCommentsNotifier extends StateNotifier<ReelsCommentsState> {
  final ISocialRepository? _repo;
  final Ref? _ref;

  ReelsCommentsNotifier([this._repo, this._ref])
      : super(const ReelsCommentsState()) {
    _seedComments();
    _hydrateFromStorage();
  }

  void _hydrateFromStorage() {
    if (!SovereignDomainStorageMode.canHydrateFromStorage(
      AppConstants.socialReelsBoxKey,
    )) {
      return;
    }
    final persisted = SocialReelsCacheRepository.loadAllReelComments();
    if (persisted.isEmpty) return;
    final nextMap = Map<String, List<ReelComment>>.from(state.commentsByClipId);
    for (final entry in persisted.entries) {
      try {
        nextMap[entry.key] = entry.value.map(ReelComment.fromJson).toList();
      } catch (_) {}
    }
    state = state.copyWith(commentsByClipId: nextMap);
  }

  void _persistCommentsForClip(String clipId, List<ReelComment> comments) {
    unawaited(
      SocialReelsCacheRepository.saveReelComments(
        clipId,
        comments.map((c) => c.toJson()).toList(),
      ),
    );
  }

  /// Synchronizes comments for a specific clip or Kinetic Post ID from backend.
  Future<void> syncCommentsForClip(
    String clipId, {
    bool isKineticPost = false,
  }) async {
    try {
      List<ReelComment> remote = const <ReelComment>[];
      if (isKineticPost && _ref != null) {
        remote = await _ref
            .read(exploreRepositoryProvider)
            .fetchPostComments(clipId);
      } else if (_repo != null) {
        remote = await _repo.getComments(clipId);
      }
      if (!mounted || remote.isEmpty) return;
      state = state.copyWith(
        commentsByClipId: {...state.commentsByClipId, clipId: remote},
      );
      _persistCommentsForClip(clipId, remote);
    } catch (_) {}
  }

  List<ReelComment> commentsForClip(String clipId) {
    return state.commentsByClipId[clipId] ?? const [];
  }

  List<CommentThreadNode> threadsForClip(String clipId) {
    return state.buildThreads(clipId);
  }

  void setSortOrder(String clipId, CommentSortOrder sortOrder) {
    state = state.copyWith(
      sortByClipId: {...state.sortByClipId, clipId: sortOrder},
    );
  }

  void setActiveReplyTarget(String clipId, ActiveReplyTarget? target) {
    state = state.copyWith(
      activeReplyByClipId: {...state.activeReplyByClipId, clipId: target},
    );
  }

  void clearActiveReplyTarget(String clipId) {
    setActiveReplyTarget(clipId, null);
  }

  void toggleThreadExpanded(String clipId, String parentCommentId) {
    final current = Set<String>.from(state.expandedParentsFor(clipId));
    if (current.contains(parentCommentId)) {
      current.remove(parentCommentId);
    } else {
      current.add(parentCommentId);
    }
    state = state.copyWith(
      expandedParentsByClipId: {
        ...state.expandedParentsByClipId,
        clipId: current,
      },
    );
  }

  /// Appends a new comment or nested reply optimistically and persists to cloud (`REQ-P69-THREAD-03..05`).
  Future<void> addComment({
    required String clipId,
    required String text,
    int userReelLoves = 0,
    String? username,
    String? displayName,
    String? giftEmoji,
    String? giftName,
    String? parentCommentId,
    String? replyToHandle,
    String? contentCreatorId,
    String? contentCreatorHandle,
    bool isKineticPost = false,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    final session = _ref?.read(authSessionProvider);
    final ownerProfile = _ref?.read(ownerProfileProvider);
    final resolvedUserId =
        session?.canonicalCreatorId ?? ownerProfile?.id ?? 'creator_cern';
    final resolvedUsername = (username ??
            (ownerProfile != null && ownerProfile.username.isNotEmpty
                ? ownerProfile.username
                : session?.rawUsername) ??
            'cern')
        .replaceFirst(RegExp(r'^@+'), '');
    final resolvedDisplayName = displayName ??
        (ownerProfile != null && ownerProfile.displayName.isNotEmpty
            ? ownerProfile.displayName
            : session?.displayName) ??
        'Cern';
    final resolvedAvatarUrl = ownerProfile?.avatarUrl;

    final activeReply = state.activeReplyFor(clipId);
    final effectiveParentId = parentCommentId ?? activeReply?.parentCommentId;
    final effectiveReplyHandle = replyToHandle ?? activeReply?.replyToHandle;

    final normalizedContentHandle =
        (contentCreatorHandle ?? '').replaceFirst(RegExp(r'^@+'), '').toLowerCase();
    final isAuthor = (contentCreatorId != null &&
            contentCreatorId.isNotEmpty &&
            (contentCreatorId == resolvedUserId ||
                contentCreatorId == ownerProfile?.id)) ||
        (normalizedContentHandle.isNotEmpty &&
            normalizedContentHandle == resolvedUsername.toLowerCase());

    final newComment = ReelComment(
      id: 'c_${DateTime.now().millisecondsSinceEpoch}',
      clipId: clipId,
      userId: resolvedUserId,
      username: resolvedUsername,
      displayName: resolvedDisplayName,
      avatarUrl: resolvedAvatarUrl,
      isCreator: isAuthor,
      text: cleanText,
      userReelLoves: userReelLoves,
      giftEmoji: giftEmoji,
      giftName: giftName,
      parentCommentId: effectiveParentId,
      replyToHandle: effectiveReplyHandle,
      createdAt: DateTime.now(),
    );

    final currentList = state.commentsByClipId[clipId] ?? const [];
    final updatedList = [newComment, ...currentList];

    final nextExpanded = Map<String, Set<String>>.from(
      state.expandedParentsByClipId,
    );
    if (effectiveParentId != null && effectiveParentId.isNotEmpty) {
      nextExpanded[clipId] = {
        ...state.expandedParentsFor(clipId),
        effectiveParentId,
      };
    }

    final nextReplyMap = Map<String, ActiveReplyTarget?>.from(
      state.activeReplyByClipId,
    )..[clipId] = null;

    state = state.copyWith(
      commentsByClipId: {...state.commentsByClipId, clipId: updatedList},
      expandedParentsByClipId: nextExpanded,
      activeReplyByClipId: nextReplyMap,
    );
    _persistCommentsForClip(clipId, updatedList);

    final looksLikePost = isKineticPost ||
        clipId.startsWith('post_') ||
        clipId.startsWith('kpost_');

    if (looksLikePost && _ref != null) {
      try {
        _ref
            .read(socialFeedPostsProvider.notifier)
            .incrementCommentCount(clipId);
      } catch (_) {}
    }

    if (giftName == null) {
      try {
        final routePrefix = looksLikePost ? '/post/' : '/reel/';
        final notifTitle = effectiveReplyHandle != null
            ? 'Replied to $effectiveReplyHandle'
            : (looksLikePost
                ? 'Commented on Kinetic Post'
                : 'Commented on Kinetic Reel');
        _ref?.read(notificationsProvider.notifier).addNotification(
              NotificationEntity(
                id: 'notif_comment_${newComment.id}',
                title: notifTitle,
                message: '"${newComment.text}" posted to the discussion thread.',
                category: NotificationCategory.social,
                priority: NotificationPriority.normal,
                subtype: 'comment',
                targetRoute: '$routePrefix$clipId',
                targetEntityId: clipId,
                ctaLabel:
                    looksLikePost ? 'Open Post Discussion' : 'Watch Kinetic Reel',
                createdAt: newComment.createdAt,
              ),
            );
      } catch (_) {}
    }

    if (looksLikePost && _ref != null) {
      try {
        await _ref.read(exploreRepositoryProvider).addPostComment(
              postId: clipId,
              text: cleanText,
              userId: resolvedUserId,
              username: resolvedUsername,
              displayName: resolvedDisplayName,
              avatarUrl: resolvedAvatarUrl,
              userReelLoves: userReelLoves,
              parentCommentId: effectiveParentId,
              replyToHandle: effectiveReplyHandle,
            );
        return;
      } catch (_) {}
    }

    if (_repo != null) {
      try {
        await _repo.addComment(
          clipId: clipId,
          text: cleanText,
          username: resolvedUsername,
          displayName: resolvedDisplayName,
          userReelLoves: userReelLoves,
          giftEmoji: giftEmoji,
          giftName: giftName,
          parentCommentId: effectiveParentId,
          replyToHandle: effectiveReplyHandle,
        );
      } catch (_) {}
    }
  }

  /// Toggles the current user's like on a specific comment or reply.
  void toggleCommentLike({required String clipId, required String commentId}) {
    final currentList = state.commentsByClipId[clipId];
    if (currentList == null) return;

    final updated = [
      for (final comment in currentList)
        if (comment.id == commentId)
          comment.copyWith(
            isLikedByMe: !comment.isLikedByMe,
            likeCount:
                (comment.likeCount + (comment.isLikedByMe ? -1 : 1)).clamp(0, 9999999),
          )
        else
          comment,
    ];

    state = state.copyWith(
      commentsByClipId: {...state.commentsByClipId, clipId: updated},
    );
    _persistCommentsForClip(clipId, updated);
    _repo?.toggleLikeComment(commentId);
  }
```

And inside `_seedComments()` in `reels_comments_provider.dart`, seed `post_001` (4 comments including 1 nested reply from `@makhadzi` with `isCreator: true`), `post_001_remix_fifi` (2 comments), `post_002` (3 comments including 1 nested reply), `post_003` (2 comments), `post_004` (2 comments), and `post_005` (2 comments), and update `seedSocialPosts()` in `social_music_post.dart` so `commentCount` matches (`post_001: 4`, `post_001_remix_fifi: 2`, `post_002: 3`, `post_003: 2`, `post_004: 2`, `post_005: 2`).

---

## 4. Repost Identity, Composer Bar & `ExploreSocialPostCard` Refinement (`M69.1`)

### 4.1 `apps/vhunambi_client/lib/features/explore/presentation/widgets/repost_kinetic_post_sheet.dart`
Replace `_submitRepost()` so it resolves the real creator identity from `ownerProfileProvider` and `authSessionProvider`:

```dart
  void _submitRepost() {
    HapticFeedback.mediumImpact();
    final quote = _commentController.text.trim();
    final now = DateTime.now();

    final owner = ref.read(ownerProfileProvider);
    final session = ref.read(authSessionProvider);
    final resolvedCreatorId = owner.id.isNotEmpty && owner.id != 'me'
        ? owner.id
        : (session.canonicalCreatorId.isNotEmpty
            ? session.canonicalCreatorId
            : 'creator_cern');
    final resolvedName = owner.displayName.isNotEmpty
        ? owner.displayName
        : (session.displayName.isNotEmpty ? session.displayName : 'Cern');
    final rawHandle = owner.handle.isNotEmpty
        ? owner.handle
        : (session.rawUsername.isNotEmpty ? session.rawUsername : 'cern');
    final resolvedHandle =
        rawHandle.startsWith('@') ? rawHandle : '@$rawHandle';

    final repost = SocialMusicPost(
      id: 'kpost_repost_${now.millisecondsSinceEpoch}',
      creatorId: resolvedCreatorId,
      creatorName: resolvedName,
      creatorHandle: resolvedHandle,
      creatorAvatarUrl: owner.avatarUrl,
      isCreatorVerified: owner.isVerified,
      publishedAt: now,
      caption: quote,
      quoteComment: quote.isNotEmpty ? quote : null,
      repostedFromPostId: widget.originalPost.id,
      repostedFromCreatorHandle: widget.originalPost.creatorHandle,
      track: widget.originalPost.track,
      imageAttachment: widget.originalPost.imageAttachment,
      imageAttachments: widget.originalPost.imageAttachments,
      audioAttachment: widget.originalPost.audioAttachment,
      location: 'South Africa',
    );
```

### 4.2 `apps/vhunambi_client/lib/features/explore/presentation/widgets/kinetic_post_composer_bar.dart`
Upgrade `KineticPostComposerBar` to a `ConsumerWidget` watching `ownerProfileProvider` and rendering `SafeNetworkAvatar` + dynamic `*Of(context)` tokens:

```dart
class KineticPostComposerBar extends ConsumerWidget {
  const KineticPostComposerBar({super.key});

  void _openComposer(BuildContext context, {int initialTab = 0}) {
    HapticFeedback.lightImpact();
    CreateKineticPostSheet.show(context, initialTab: initialTab);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(ownerProfileProvider);
    final fallbackLabel =
        owner.displayName.isNotEmpty ? owner.displayName : 'Cern';

    return Container(
      key: const Key('explore_create_kinetic_post_bar'),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevatedOf(context),
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtleOf(context)),
      ),
      child: Row(
        children: [
          SafeNetworkAvatar(
            key: const Key('kpost_composer_owner_avatar'),
            radius: 18,
            imageUrl: owner.avatarUrl,
            fallbackLabel: fallbackLabel,
            backgroundColor: AppColors.brandPrimary.withValues(alpha: 0.15),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: InkWell(
              onTap: () => _openComposer(context),
              borderRadius: AppRadius.pillBorder,
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondaryOf(context),
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(color: AppColors.borderSubtleOf(context)),
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  'Drop a groove, voice take, or beat story...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          IconButton(
            key: const Key('kpost_quick_photo_btn'),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: const PhosphorIcon(
              PhosphorIconsRegular.image,
              size: 20,
              color: AppColors.brandPrimary,
            ),
            tooltip: 'Add Photo',
            onPressed: () => _openComposer(context, initialTab: 1),
          ),
          IconButton(
            key: const Key('kpost_quick_vision_btn'),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: const PhosphorIcon(
              PhosphorIconsFill.sparkle,
              size: 20,
              color: AppColors.badgeCyan,
            ),
            tooltip: 'Vhunambi Vision AI',
            onPressed: () => _openComposer(context, initialTab: 2),
          ),
        ],
      ),
    );
  }
}
```

### 4.3 `apps/vhunambi_client/lib/features/explore/presentation/widgets/explore_social_post_card.dart`
Refines the feed card hierarchy toward the Facebook benchmark while preserving every existing `Key('...')`:
1. **Inline Header Provenance:** Places `_buildProvenanceBadge(context, post)` cleanly inside the Creator subtitle row (`${post.creatorHandle} • ${post.relativeTimeAgo}`) so it does not consume a standalone vertical block above the caption.
2. **1-Tap Focus Navigation (`_openPostFocus`):**
   - Wraps the card surface inside an outer `InkWell(key: Key('social_post_card_tap_${post.id}'), onTap: () => _openPostFocus(context, autofocusComposer: false), borderRadius: BorderRadius.circular(18), child: ...)` so tapping anywhere on the card body, caption (`Key('social_post_caption_tap_${post.id}')`), image canvas (`Key('social_post_media_tap_${post.id}')`), or Engagement Summary Strip (`Key('social_post_engagement_strip_${post.id}')`) opens `KineticPostFocusView.show(context, postId: post.id, initialPost: post, onRemixSuccess: widget.onRemixSuccess)`.
   - Tapping `Key('social_post_comment_btn_${post.id}')` opens `KineticPostFocusView.show(context, postId: post.id, initialPost: post, autofocusComposer: true, onRemixSuccess: widget.onRemixSuccess)`.
   ```dart
   void _openPostFocus(BuildContext context, {required bool autofocusComposer}) {
     HapticFeedback.selectionClick();
     KineticPostFocusView.show(
       context,
       postId: widget.post.id,
       initialPost: widget.post,
       autofocusComposer: autofocusComposer,
       onRemixSuccess: widget.onRemixSuccess,
     );
   }
   ```
3. **Emoji-Free Co-Sign Label (`_buildCosignButton`):**
   ```dart
            Text(
              isGraduated
                  ? 'Graduated · ${post.cosignCount}'
                  : 'Co-Sign · ${post.cosignCount}/25',
              style: AppTypography.caption.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: post.isCosigned
                    ? AppColors.brandPrimary
                    : AppColors.textPrimaryOf(context),
              ),
            ),
   ```
4. **Engagement Summary Strip (`_buildEngagementSummaryStrip`):**
   ```dart
  Widget _buildEngagementSummaryStrip(
    BuildContext context,
    SocialMusicPost post,
    int liveCommentCount,
  ) {
    final effectiveComments = liveCommentCount > post.commentCount
        ? liveCommentCount
        : post.commentCount;
    return InkWell(
      key: Key('social_post_engagement_strip_${post.id}'),
      onTap: () => _openPostFocus(context, autofocusComposer: false),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: PhosphorIcon(
                  AppIcons.heart,
                  size: 11,
                  color: AppColors.brandPrimary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${post.likeCount}',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondaryOf(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                '$effectiveComments ${effectiveComments == 1 ? 'comment' : 'comments'}'
                ' · ${post.repostCount} ${post.repostCount == 1 ? 'repost' : 'reposts'}'
                ' · ${post.remixCount} ${post.remixCount == 1 ? 'remix' : 'remixes'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
   ```

---

## 5. Full-Screen `KineticPostFocusView` & Deep-Link Router (`M69.2`)

### 5.1 `apps/vhunambi_client/lib/features/explore/presentation/views/kinetic_post_focus_view.dart`
Complete production implementation of the full-screen Post Focus destination (`< Post`):

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/safe_network_avatar.dart';
import '../../../../core/widgets/vhunambi_track_artwork.dart';
import '../../../notifications/domain/models/notification_entity.dart';
import '../../../notifications/domain/models/notification_enums.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../profile/presentation/views/artist_profile_view.dart';
import '../../../social/presentation/providers/reels_comments_provider.dart';
import '../../../social/presentation/widgets/creator_tipping_sheet.dart';
import '../../../social/presentation/widgets/open_verse_remix_cockpit_sheet.dart';
import '../../../social/presentation/widgets/remix_lineage_tree_sheet.dart';
import '../../../social/presentation/widgets/threaded_comments_section.dart';
import '../../domain/models/social_music_post.dart';
import '../providers/explore_providers.dart';
import '../widgets/kinetic_post_sonic_pill.dart';
import '../widgets/repost_kinetic_post_sheet.dart';

/// Full-screen Facebook-benchmark Post Focus Domain (`< Post`) (`REQ-P69-FOCUS-01..04`).
///
/// Combines complete creator attribution, full caption, interactive multi-image or
/// normalized track artwork canvas, `KineticPostSonicPill`, Stem/Co-Sign telemetry,
/// Engagement Summary Strip, nested threaded comments (`Most relevant` / `Newest`),
/// and a sticky bottom reply-aware `StudioReactionComposerBar`.
class KineticPostFocusView extends ConsumerStatefulWidget {
  final String postId;
  final SocialMusicPost? initialPost;
  final bool autofocusComposer;
  final VoidCallback? onRemixSuccess;

  const KineticPostFocusView({
    super.key,
    required this.postId,
    this.initialPost,
    this.autofocusComposer = false,
    this.onRemixSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required String postId,
    SocialMusicPost? initialPost,
    bool autofocusComposer = false,
    VoidCallback? onRemixSuccess,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => KineticPostFocusView(
          postId: postId,
          initialPost: initialPost,
          autofocusComposer: autofocusComposer,
          onRemixSuccess: onRemixSuccess,
        ),
      ),
    );
  }

  @override
  ConsumerState<KineticPostFocusView> createState() =>
      _KineticPostFocusViewState();
}

class _KineticPostFocusViewState extends ConsumerState<KineticPostFocusView> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _composerFocusNode = FocusNode();
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(reelsCommentsProvider.notifier)
          .syncCommentsForClip(widget.postId, isKineticPost: true);
      if (widget.autofocusComposer) {
        _composerFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _composerFocusNode.dispose();
    super.dispose();
  }

  SocialMusicPost? _resolvePost(List<SocialMusicPost> feedPosts) {
    for (final p in feedPosts) {
      if (p.id == widget.postId) return p;
    }
    return widget.initialPost;
  }

  void _handleShare(SocialMusicPost post) {
    Clipboard.setData(ClipboardData(text: post.track.audioUrl ?? ''));
    ref.read(notificationsProvider.notifier).addNotification(
          NotificationEntity(
            id: 'notif_share_${DateTime.now().millisecondsSinceEpoch}',
            title: 'Social Link Shared',
            message:
                'Shared "${post.track.title}" by ${post.creatorHandle} to your network.',
            createdAt: DateTime.now(),
            category: NotificationCategory.creatorActivity,
            targetRoute: '/post/${post.id}',
            targetEntityId: post.id,
            isRead: false,
          ),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Post link copied to clipboard!'),
        backgroundColor: AppColors.brandPrimary,
      ),
    );
  }

  void _submitComment(SocialMusicPost post) {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.mediumImpact();
    ref.read(reelsCommentsProvider.notifier).addComment(
          clipId: post.id,
          text: text,
          contentCreatorId: post.creatorId,
          contentCreatorHandle: post.creatorHandle,
          isKineticPost: true,
        );
    _commentController.clear();
    _composerFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final feedPosts = ref.watch(socialFeedPostsProvider);
    final post = _resolvePost(feedPosts);

    if (post == null) {
      return Scaffold(
        backgroundColor: AppColors.surfaceCanvasOf(context),
        appBar: AppBar(
          backgroundColor: AppColors.surfaceElevatedOf(context),
          leading: IconButton(
            key: const Key('kpost_focus_back_btn'),
            icon: PhosphorIcon(
              AppIcons.arrowLeft,
              color: AppColors.textPrimaryOf(context),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Post',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textPrimaryOf(context),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Center(
          child: Text(
            'Post not found',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondaryOf(context),
            ),
          ),
        ),
      );
    }

    final followingIds = ref.watch(followingCreatorIdsProvider);
    final isFollowing = followingIds.contains(post.creatorId);
    final ownerProfile = ref.watch(ownerProfileProvider);
    final isOwner =
        post.creatorHandle.toLowerCase() == ownerProfile.handle.toLowerCase() ||
        post.creatorId == ownerProfile.id ||
        post.creatorId == 'me';
    final comments = ref.watch(clipCommentsFamilyProvider(post.id));
    final effectiveCommentCount = comments.length > post.commentCount
        ? comments.length
        : post.commentCount;
    final images = post.allImageAttachments;
    final hasImages = images.isNotEmpty;

    return Scaffold(
      key: Key('kinetic_post_focus_view_${post.id}'),
      backgroundColor: AppColors.surfaceCanvasOf(context),
      appBar: AppBar(
        backgroundColor: AppColors.surfaceElevatedOf(context),
        elevation: 0,
        leading: IconButton(
          key: const Key('kpost_focus_back_btn'),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          icon: PhosphorIcon(
            AppIcons.arrowLeft,
            color: AppColors.textPrimaryOf(context),
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Text(
          '${post.creatorName}\'s Post',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimaryOf(context),
          ),
        ),
        actions: [
          IconButton(
            key: const Key('kpost_focus_tip_btn'),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            tooltip: 'Tip Creator',
            icon: const PhosphorIcon(
              AppIcons.coin,
              color: AppColors.coinGold,
              size: 20,
            ),
            onPressed: () => CreatorTippingSheet.show(
              context,
              clip: post.toPublishedClip,
            ),
          ),
          IconButton(
            key: const Key('kpost_focus_share_btn'),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            tooltip: 'Share Post',
            icon: PhosphorIcon(
              AppIcons.share,
              color: AppColors.textSecondaryOf(context),
              size: 20,
            ),
            onPressed: () => _handleShare(post),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    color: AppColors.surfaceElevatedOf(context),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (post.isRepost)
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.xs),
                            child: Row(
                              children: [
                                PhosphorIcon(
                                  PhosphorIconsRegular.repeat,
                                  size: 13,
                                  color: AppColors.textSecondaryOf(context),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Reposted from ${post.repostedFromCreatorHandle ?? 'creator'}',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondaryOf(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Creator Header
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => ArtistProfileView(
                                        artistId: post.creatorId,
                                      ),
                                    ),
                                  );
                                },
                                child: Row(
                                  children: [
                                    SafeNetworkAvatar(
                                      radius: 22,
                                      backgroundColor:
                                          AppColors.surfaceSecondaryOf(context),
                                      imageUrl: post.creatorAvatarUrl,
                                      fallbackLabel: post.creatorName,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  post.creatorName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: AppTypography
                                                      .titleSmall
                                                      .copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors
                                                        .textPrimaryOf(context),
                                                  ),
                                                ),
                                              ),
                                              if (post.isCreatorVerified) ...[
                                                const SizedBox(width: 4),
                                                const PhosphorIcon(
                                                  AppIcons.verified,
                                                  color: AppColors.brandPrimary,
                                                  size: 15,
                                                ),
                                              ],
                                            ],
                                          ),
                                          Text(
                                            '${post.creatorHandle} • ${post.relativeTimeAgo} • ${post.location}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style:
                                                AppTypography.caption.copyWith(
                                              color: AppColors.textSecondaryOf(
                                                context,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (!isOwner)
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 44,
                                  minWidth: 44,
                                ),
                                child: TextButton(
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    ref
                                        .read(
                                          followingCreatorIdsProvider.notifier,
                                        )
                                        .toggleFollow(post.creatorId);
                                  },
                                  child: Text(
                                    isFollowing ? 'Following' : '+ Follow',
                                    style: AppTypography.caption.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isFollowing
                                          ? AppColors.textPrimaryOf(context)
                                          : AppColors.brandPrimary,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (post.caption.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            post.caption,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textPrimaryOf(context),
                              height: 1.45,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        // Visual Media + Sonic Pill
                        if (hasImages)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: AspectRatio(
                              aspectRatio: post.effectiveAspectRatio.ratio,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  PageView.builder(
                                    itemCount: images.length,
                                    onPageChanged: (idx) {
                                      setState(() => _currentImageIndex = idx);
                                    },
                                    itemBuilder: (context, idx) {
                                      final normalizedUrl = AppConstants
                                          .normalizeCloudMediaUrl(
                                        images[idx].imageUrl,
                                      );
                                      return Image.network(
                                        normalizedUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            VhunambiTrackArtwork(
                                          coverUrl: post.track.coverUrl,
                                          genre: post.track.genre,
                                          trackId: post.track.id,
                                          borderRadius: BorderRadius.zero,
                                          showSubtleBorder: false,
                                        ),
                                      );
                                    },
                                  ),
                                  if (images.length > 1)
                                    Positioned(
                                      top: 10,
                                      right: 10,
                                      child: Container(
                                        key: Key(
                                          'kpost_focus_image_counter_${post.id}',
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.65),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${_currentImageIndex + 1}/${images.length}',
                                          style: AppTypography.caption.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    left: 10,
                                    right: 10,
                                    bottom: 10,
                                    child: KineticPostSonicPill(
                                      post: post,
                                      isOverlay: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          KineticPostSonicPill(post: post, isOverlay: false),
                        const SizedBox(height: AppSpacing.sm),
                        // Lineage & Co-Sign Row
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            InkWell(
                              onTap: () => RemixLineageTreeSheet.show(
                                context,
                                trackOrClipId: post.id,
                                clip: post.toPublishedClip,
                              ),
                              borderRadius: AppRadius.pillBorder,
                              child: Container(
                                constraints: const BoxConstraints(minHeight: 36),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.brandPrimary
                                      .withValues(alpha: 0.12),
                                  borderRadius: AppRadius.pillBorder,
                                  border: Border.all(
                                    color: AppColors.brandPrimary
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const PhosphorIcon(
                                      PhosphorIconsRegular.gitFork,
                                      size: 13,
                                      color: AppColors.brandPrimary,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      post.isRemix
                                          ? 'Remix of ${post.parentCreatorHandle} · 70/30 Split'
                                          : 'Open Stems · ${post.remixCount} Remixes',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.brandPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                ref
                                    .read(socialFeedPostsProvider.notifier)
                                    .cosignPost(post.id);
                              },
                              borderRadius: AppRadius.pillBorder,
                              child: Container(
                                constraints: const BoxConstraints(minHeight: 36),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: post.isCosigned
                                      ? AppColors.brandPrimary
                                          .withValues(alpha: 0.15)
                                      : AppColors.surfaceSecondaryOf(context),
                                  borderRadius: AppRadius.pillBorder,
                                  border: Border.all(
                                    color: post.isCosigned
                                        ? AppColors.brandPrimary
                                        : AppColors.borderSubtleOf(context),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    PhosphorIcon(
                                      PhosphorIconsFill.fire,
                                      size: 13,
                                      color: post.isCosigned
                                          ? AppColors.coinGold
                                          : AppColors.textSecondaryOf(context),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      post.cosignCount >= 25
                                          ? 'Graduated · ${post.cosignCount}'
                                          : 'Co-Sign · ${post.cosignCount}/25',
                                      style: AppTypography.caption.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: post.isCosigned
                                            ? AppColors.brandPrimary
                                            : AppColors.textPrimaryOf(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Divider(
                          height: 1,
                          color: AppColors.borderSubtleOf(context),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              const PhosphorIcon(
                                AppIcons.heart,
                                size: 14,
                                color: AppColors.brandPrimary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${post.likeCount} Likes',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondaryOf(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '$effectiveCommentCount Comments · ${post.repostCount} Reposts · ${post.remixCount} Remixes',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondaryOf(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: AppColors.borderSubtleOf(context),
                        ),
                        // Equal-width Action Bar
                        Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                key: Key('kpost_focus_like_btn_${post.id}'),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  ref
                                      .read(socialFeedPostsProvider.notifier)
                                      .toggleLike(post.id);
                                },
                                icon: PhosphorIcon(
                                  post.isLikedByMe
                                      ? AppIcons.heart
                                      : AppIcons.heartOutline,
                                  size: 16,
                                  color: post.isLikedByMe
                                      ? AppColors.brandPrimary
                                      : AppColors.textSecondaryOf(context),
                                ),
                                label: Text(
                                  'Like',
                                  style: AppTypography.caption.copyWith(
                                    color: post.isLikedByMe
                                        ? AppColors.brandPrimary
                                        : AppColors.textSecondaryOf(context),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextButton.icon(
                                key: Key('kpost_focus_comment_btn_${post.id}'),
                                onPressed: () =>
                                    _composerFocusNode.requestFocus(),
                                icon: PhosphorIcon(
                                  AppIcons.chat,
                                  size: 16,
                                  color: AppColors.textSecondaryOf(context),
                                ),
                                label: Text(
                                  'Comment',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondaryOf(context),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextButton.icon(
                                key: Key('kpost_focus_repost_btn_${post.id}'),
                                onPressed: () => RepostKineticPostSheet.show(
                                  context,
                                  originalPost: post,
                                ),
                                icon: PhosphorIcon(
                                  PhosphorIconsRegular.repeat,
                                  size: 16,
                                  color: AppColors.textSecondaryOf(context),
                                ),
                                label: Text(
                                  'Repost',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondaryOf(context),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextButton.icon(
                                key: Key('kpost_focus_remix_btn_${post.id}'),
                                onPressed: () {
                                  OpenVerseRemixCockpitSheet.show(
                                    context,
                                    clip: post.toPublishedClip,
                                  );
                                  widget.onRemixSuccess?.call();
                                },
                                icon: const PhosphorIcon(
                                  AppIcons.remix,
                                  size: 16,
                                  color: AppColors.brandPrimary,
                                ),
                                label: Text(
                                  'Remix',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.brandPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Integrated Threaded Discussion Section
                SliverToBoxAdapter(
                  child: ThreadedCommentsSection(
                    clipOrPostId: post.id,
                    contentCreatorId: post.creatorId,
                    contentCreatorHandle: post.creatorHandle,
                    onRequestReplyFocus: () =>
                        _composerFocusNode.requestFocus(),
                  ),
                ),
              ],
            ),
          ),
          // Sticky Reply-Aware Bottom Composer
          StudioReactionComposerBar(
            clipOrPostId: post.id,
            creatorHandle: post.creatorHandle,
            controller: _commentController,
            focusNode: _composerFocusNode,
            onSubmit: () => _submitComment(post),
          ),
        ],
      ),
    );
  }
}
```

### 5.2 `apps/vhunambi_client/lib/features/notifications/presentation/utils/notification_deep_link_router.dart`
Add `/post/:id` routing before the fallback `NotificationDetailBottomSheet`:

```dart
    if (route.startsWith('/post/')) {
      final postId = route.substring('/post/'.length).trim();
      if (postId.isNotEmpty) {
        final posts = ref.read(socialFeedPostsProvider);
        SocialMusicPost? matched;
        for (final p in posts) {
          if (p.id == postId) {
            matched = p;
            break;
          }
        }
        await KineticPostFocusView.show(
          context,
          postId: postId,
          initialPost: matched,
        );
        return;
      }
    }
```

---

## 6. Shared `ThreadedCommentsSection` & `StudioReactionComposerBar` (`M69.2` – `M69.3`)

### 6.1 `apps/vhunambi_client/lib/features/social/presentation/widgets/threaded_comments_section.dart`
Provides the complete, compilable reusable Facebook-benchmark threaded discussion view (`Most relevant ▾` / `Newest ▾` sort selector, honest community banner, parent comment tiles, `Reply` button with `>=44x44dp` target, `Author` badge, `View N replies` / `Hide replies` toggle, 36dp-indented child reply tree, and `StudioReactionComposerBar` with Phosphor studio reaction chips):

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/safe_network_avatar.dart';
import '../../domain/models/reel_comment.dart';
import '../providers/reels_comments_provider.dart';

/// Immutable descriptor for a `STD-UIUX-001` Phosphor studio reaction chip (`REQ-P69-STD-01`).
@immutable
class StudioReactionChipSpec {
  final String id;
  final String label;
  final String insertText;
  final IconData icon;
  final Color iconColor;

  const StudioReactionChipSpec({
    required this.id,
    required this.label,
    required this.insertText,
    required this.icon,
    required this.iconColor,
  });
}

const List<StudioReactionChipSpec> kStudioReactionChips = <StudioReactionChipSpec>[
  StudioReactionChipSpec(
    id: 'fire',
    label: 'Fire',
    insertText: 'Pure fire!',
    icon: AppIcons.flame,
    iconColor: AppColors.brandPrimary,
  ),
  StudioReactionChipSpec(
    id: 'crown',
    label: 'Crown',
    insertText: 'Royalty!',
    icon: AppIcons.crown,
    iconColor: AppColors.coinGold,
  ),
  StudioReactionChipSpec(
    id: 'log_drum',
    label: 'Log Drum',
    insertText: 'Heavy log drum!',
    icon: AppIcons.piano,
    iconColor: AppColors.badgeCyan,
  ),
  StudioReactionChipSpec(
    id: 'soul',
    label: 'Soul',
    insertText: 'Deep soul',
    icon: AppIcons.heart,
    iconColor: AppColors.accentElectric,
  ),
  StudioReactionChipSpec(
    id: 'vocals',
    label: 'Vocals',
    insertText: 'Vocal mastery',
    icon: AppIcons.vocals,
    iconColor: AppColors.success,
  ),
  StudioReactionChipSpec(
    id: 'sa_vibe',
    label: 'SA Vibe',
    insertText: 'Proudly SA sound',
    icon: AppIcons.navExploreActive,
    iconColor: AppColors.brandPrimary,
  ),
];

const List<String> kStudioPraisePhrases = <String>[
  'Hits different!',
  'Makhado sunrise',
  'Top tier production',
  'Proudly SA',
];

/// Reusable threaded comment discussion list used in both `KineticPostFocusView`
/// and `ReelsCommentSheet` (`REQ-P69-THREAD-02` .. `REQ-P69-THREAD-05`).
class ThreadedCommentsSection extends ConsumerWidget {
  final String clipOrPostId;
  final String? contentCreatorId;
  final String? contentCreatorHandle;
  final VoidCallback? onRequestReplyFocus;
  final EdgeInsetsGeometry padding;

  const ThreadedCommentsSection({
    super.key,
    required this.clipOrPostId,
    this.contentCreatorId,
    this.contentCreatorHandle,
    this.onRequestReplyFocus,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsState = ref.watch(reelsCommentsProvider);
    final notifier = ref.read(reelsCommentsProvider.notifier);
    final allComments =
        commentsState.commentsByClip[clipOrPostId] ?? const <ReelComment>[];
    final threads = notifier.threadsForClip(clipOrPostId);
    final sortOrder = commentsState.sortOrderFor(clipOrPostId);
    final normalizedCreatorHandle = contentCreatorHandle
        ?.trim()
        .toLowerCase()
        .replaceFirst(RegExp(r'^@'), '');

    ReelComment? topSupporter;
    for (final c in allComments) {
      if (c.userReelLoves >= 3) {
        if (topSupporter == null ||
            c.userReelLoves > topSupporter.userReelLoves) {
          topSupporter = c;
        }
      }
    }

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Comments Count + Most Relevant / Newest Sort Selector
          Row(
            key: Key('threaded_comments_header_$clipOrPostId'),
            children: [
              Text(
                'Comments (${allComments.length})',
                style: AppTypography.titleSmall.copyWith(
                  color: AppColors.textPrimaryOf(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              PopupMenuButton<CommentSortOrder>(
                key: const Key('comment_sort_toggle_btn'),
                initialValue: sortOrder,
                tooltip: 'Sort comments',
                color: AppColors.surfaceElevatedOf(context),
                onSelected: (selected) {
                  HapticFeedback.selectionClick();
                  notifier.setSortOrder(clipOrPostId, selected);
                },
                itemBuilder: (ctx) => [
                  for (final option in CommentSortOrder.values)
                    PopupMenuItem<CommentSortOrder>(
                      key: Key('comment_sort_option_${option.name}'),
                      value: option,
                      child: Row(
                        children: [
                          PhosphorIcon(
                            option == sortOrder
                                ? AppIcons.checkCircle
                                : PhosphorIconsRegular.circle,
                            size: 16,
                            color: option == sortOrder
                                ? AppColors.brandPrimary
                                : AppColors.textSecondaryOf(ctx),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            option.label,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textPrimaryOf(ctx),
                              fontWeight: option == sortOrder
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                child: Container(
                  constraints: const BoxConstraints(minHeight: 36),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondaryOf(context),
                    borderRadius: AppRadius.pillBorder,
                    border: Border.all(
                      color: AppColors.borderSubtleOf(context),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        sortOrder.label,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      PhosphorIcon(
                        AppIcons.caretDown,
                        size: 13,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (topSupporter != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _HonestSupporterBanner(supporter: topSupporter),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (threads.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PhosphorIcon(
                      AppIcons.chatOutline,
                      size: 32,
                      color: AppColors.textSecondaryOf(context)
                          .withValues(alpha: 0.45),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No comments yet. Start the studio conversation!',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final node in threads) ...[
              _ThreadedCommentTile(
                comment: node.parent,
                isCreatorOverride: _isCreatorComment(
                  node.parent,
                  contentCreatorId: contentCreatorId,
                  normalizedCreatorHandle: normalizedCreatorHandle,
                ),
                isChildReply: false,
                onReplyTap: () {
                  HapticFeedback.selectionClick();
                  notifier.setActiveReplyTarget(
                    clipOrPostId,
                    ActiveReplyTarget(
                      parentCommentId: node.parent.id,
                      replyToCommentId: node.parent.id,
                      replyToHandle: '@${node.parent.username}',
                      replyToDisplayName: node.parent.displayName,
                    ),
                  );
                  onRequestReplyFocus?.call();
                },
                onLikeTap: () {
                  HapticFeedback.lightImpact();
                  notifier.toggleCommentLike(clipOrPostId, node.parent.id);
                },
              ),
              if (node.replies.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 44, bottom: 4),
                  child: InkWell(
                    key: Key('comment_toggle_replies_${node.parent.id}'),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      notifier.toggleThreadExpanded(
                        clipOrPostId,
                        node.parent.id,
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 18,
                            height: 1.5,
                            color: AppColors.borderSubtleOf(context),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            node.isExpanded
                                ? 'Hide replies'
                                : 'View ${node.replyCount} ${node.replyCount == 1 ? 'reply' : 'replies'}',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.brandPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (node.isExpanded)
                  Padding(
                    padding: const EdgeInsets.only(left: 36, bottom: 6),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: AppColors.borderSubtleOf(context),
                            width: 1.5,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.only(left: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final reply in node.replies)
                            _ThreadedCommentTile(
                              comment: reply,
                              isCreatorOverride: _isCreatorComment(
                                reply,
                                contentCreatorId: contentCreatorId,
                                normalizedCreatorHandle:
                                    normalizedCreatorHandle,
                              ),
                              isChildReply: true,
                              onReplyTap: () {
                                HapticFeedback.selectionClick();
                                notifier.setActiveReplyTarget(
                                  clipOrPostId,
                                  ActiveReplyTarget(
                                    parentCommentId: node.parent.id,
                                    replyToCommentId: reply.id,
                                    replyToHandle: '@${reply.username}',
                                    replyToDisplayName: reply.displayName,
                                  ),
                                );
                                onRequestReplyFocus?.call();
                              },
                              onLikeTap: () {
                                HapticFeedback.lightImpact();
                                notifier.toggleCommentLike(
                                  clipOrPostId,
                                  reply.id,
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
        ],
      ),
    );
  }

  bool _isCreatorComment(
    ReelComment comment, {
    required String? contentCreatorId,
    required String? normalizedCreatorHandle,
  }) {
    if (comment.isCreator) return true;
    if (contentCreatorId != null &&
        contentCreatorId.isNotEmpty &&
        comment.userId == contentCreatorId) {
      return true;
    }
    if (normalizedCreatorHandle != null &&
        normalizedCreatorHandle.isNotEmpty &&
        comment.username
                .trim()
                .toLowerCase()
                .replaceFirst(RegExp(r'^@'), '') ==
            normalizedCreatorHandle) {
      return true;
    }
    return false;
  }
}

class _HonestSupporterBanner extends StatelessWidget {
  final ReelComment supporter;

  const _HonestSupporterBanner({required this.supporter});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.coinGold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.coinGold.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          const PhosphorIcon(
            AppIcons.flame,
            color: AppColors.coinGold,
            size: 15,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Honest Community: @${supporter.username} loved this ${supporter.userReelLoves}x',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: AppColors.textPrimaryOf(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadedCommentTile extends StatelessWidget {
  final ReelComment comment;
  final bool isCreatorOverride;
  final bool isChildReply;
  final VoidCallback onReplyTap;
  final VoidCallback onLikeTap;

  const _ThreadedCommentTile({
    required this.comment,
    required this.isCreatorOverride,
    required this.isChildReply,
    required this.onReplyTap,
    required this.onLikeTap,
  });

  @override
  Widget build(BuildContext context) {
    final showCreatorBadge = comment.isCreator || isCreatorOverride;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeNetworkAvatar(
            radius: isChildReply ? 14 : 16,
            imageUrl: comment.avatarUrl,
            fallbackLabel: comment.displayName.isNotEmpty
                ? comment.displayName
                : comment.username,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      '@${comment.username}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textPrimaryOf(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (showCreatorBadge)
                      Container(
                        key: Key('comment_author_badge_${comment.id}'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brandPrimary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color:
                                AppColors.brandPrimary.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'Author',
                          style: AppTypography.badge.copyWith(
                            color: AppColors.brandPrimary,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    if (comment.userReelLoves >= 2)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.coinGold.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const PhosphorIcon(
                              AppIcons.heart,
                              size: 9,
                              color: AppColors.coinGold,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Loved ${comment.userReelLoves}x',
                              style: AppTypography.badge.copyWith(
                                color: AppColors.coinGold,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Text(
                      comment.timeAgo,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondaryOf(context),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimaryOf(context),
                      height: 1.35,
                    ),
                    children: [
                      if (comment.replyToHandle != null &&
                          comment.replyToHandle!.isNotEmpty)
                        TextSpan(
                          text: '${comment.replyToHandle} ',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.brandPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      TextSpan(text: comment.text),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    InkWell(
                      key: Key('comment_reply_btn_${comment.id}'),
                      onTap: onReplyTap,
                      borderRadius: BorderRadius.circular(8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 36,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Reply',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondaryOf(context),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            key: ValueKey('comment_like_${comment.id}'),
            onTap: onLikeTap,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PhosphorIcon(
                    comment.isLikedByMe
                        ? AppIcons.heart
                        : AppIcons.heartOutline,
                    size: 16,
                    color: comment.isLikedByMe
                        ? AppColors.error
                        : AppColors.textSecondaryOf(context),
                  ),
                  if (comment.likeCount > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${comment.likeCount}',
                      style: AppTypography.caption.copyWith(
                        color: comment.isLikedByMe
                            ? AppColors.error
                            : AppColors.textSecondaryOf(context),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sticky bottom reply-aware comment composer bar with `STD-UIUX-001` Phosphor
/// studio reaction chips (`REQ-P69-STD-01`, `REQ-P69-THREAD-03`).
class StudioReactionComposerBar extends ConsumerWidget {
  final String clipOrPostId;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final ValueChanged<String> onAppendReactionText;

  const StudioReactionComposerBar({
    super.key,
    required this.clipOrPostId,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.onAppendReactionText,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsState = ref.watch(reelsCommentsProvider);
    final activeReply = commentsState.activeReplyFor(clipOrPostId);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: 8,
        bottom: bottomInset > 0 ? bottomInset + 8 : 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevatedOf(context),
        border: Border(
          top: BorderSide(color: AppColors.borderSubtleOf(context)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (activeReply != null)
              Container(
                key: const Key('comment_active_reply_banner'),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.brandPrimary.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const PhosphorIcon(
                      AppIcons.shareFat,
                      size: 14,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Replying to ${activeReply.replyToHandle}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    InkWell(
                      key: const Key('comment_cancel_reply_btn'),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(reelsCommentsProvider.notifier)
                            .clearActiveReplyTarget(clipOrPostId);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: PhosphorIcon(
                          AppIcons.close,
                          size: 15,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // STD-UIUX-001 Studio Reaction Chip Strip
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final spec in kStudioReactionChips)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        key: Key('comment_reaction_chip_${spec.id}'),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onAppendReactionText(spec.insertText);
                        },
                        borderRadius: AppRadius.pillBorder,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSecondaryOf(context),
                            borderRadius: AppRadius.pillBorder,
                            border: Border.all(
                              color: AppColors.borderSubtleOf(context),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PhosphorIcon(
                                spec.icon,
                                size: 13,
                                color: spec.iconColor,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                spec.label,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textPrimaryOf(context),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  for (final phrase in kStudioPraisePhrases)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onAppendReactionText(phrase);
                        },
                        borderRadius: AppRadius.pillBorder,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSecondaryOf(context),
                            borderRadius: AppRadius.pillBorder,
                            border: Border.all(
                              color: AppColors.borderSubtleOf(context),
                            ),
                          ),
                          child: Text(
                            phrase,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondaryOf(context),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Input Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondaryOf(context),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: AppColors.borderSubtleOf(context),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      key: const Key('comment_input'),
                      controller: controller,
                      focusNode: focusNode,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSubmit(),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimaryOf(context),
                      ),
                      decoration: InputDecoration(
                        hintText: activeReply != null
                            ? 'Reply to ${activeReply.replyToHandle}...'
                            : 'Write a studio comment...',
                        hintStyle: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondaryOf(context),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  key: const Key('comment_send_btn'),
                  onTap: onSubmit,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.brandPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: PhosphorIcon(
                        PhosphorIconsBold.arrowUp,
                        color: AppColors.brandContrast,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 7. Client Repository & Notifier Additions (`M69.3` – `M69.4`)

### 7.1 `SocialFeedPostsNotifier.incrementCommentCount` (`explore_providers.dart`)
Add inside `SocialFeedPostsNotifier`:

```dart
  /// Increments [commentCount] on [postId] when a comment or reply is added (`REQ-P69-THREAD-05`).
  void incrementCommentCount(String postId, {int delta = 1}) {
    state = [
      for (final post in state)
        if (post.id == postId)
          post.copyWith(
            commentCount: (post.commentCount + delta).clamp(0, 9999999),
          )
        else
          post,
    ];
    _persistPostsSnapshot();
  }
```

### 7.2 `HttpExploreRepository` Post & Comment Methods (`http_explore_repository.dart`)
Add to `HttpExploreRepository`:
- `Future<Map<String, dynamic>?> fetchPostById(String postId)` (`GET $_baseUrl/explore/posts/$postId`)
- `Future<Map<String, dynamic>?> publishPost(Map<String, dynamic> postJson)` (`POST $_baseUrl/explore/posts`)
- `Future<({bool liked, int likeCount})?> togglePostLike(String postId)` (`POST $_baseUrl/explore/posts/$postId/like`)
- `Future<List<ReelComment>> fetchPostComments(String postId, {String sort = 'relevant'})` (`GET $_baseUrl/explore/posts/$postId/comments?sort=$sort`)
- `Future<ReelComment?> addPostComment({required String postId, required String text, String? userId, String? username, String? displayName, String? avatarUrl, int? userReelLoves, String? parentCommentId, String? replyToHandle})` (`POST $_baseUrl/explore/posts/$postId/comments`)

---

## 8. Backend API, Database & Supabase Migration Specification (`M69.4`)

### 8.1 Supabase Migration: `supabase/migrations/20261118000001_phase69_kinetic_posts_and_threaded_comments.sql`

```sql
BEGIN;

-- 1. Add like_count to public.kinetic_posts (Phase 69 KP-03)
ALTER TABLE public.kinetic_posts
  ADD COLUMN IF NOT EXISTS like_count INTEGER NOT NULL DEFAULT 0;

-- 2. Add nested reply threading columns to public.reel_comments (Phase 69 KP-02 / KP-03)
ALTER TABLE public.reel_comments
  ADD COLUMN IF NOT EXISTS parent_comment_id TEXT,
  ADD COLUMN IF NOT EXISTS reply_to_handle TEXT;

CREATE INDEX IF NOT EXISTS idx_reel_comments_parent
  ON public.reel_comments (clip_id, parent_comment_id);

COMMIT;
```

### 8.2 `apps/vhunambi_api/src/routes/explore_routes.ts`
Extend `exploreRoutes` with full Kinetic Post & Threaded Comment endpoints:

```ts
// GET /api/explore/posts/:id — Single Kinetic Post lookup (Phase 69 REQ-P69-API-01)
exploreRoutes.get('/posts/:id', (c) => {
  const postId = c.req.param('id');
  const post = vhunambiDb.getKineticPostById(postId);
  if (!post) {
    return c.json({ error: 'Post not found', postId }, 404);
  }
  return c.json({ success: true, post });
});

// POST /api/explore/posts — Publish or upsert a Kinetic Post (Phase 69 REQ-P69-API-01)
exploreRoutes.post('/posts', async (c) => {
  try {
    const body = await c.req.json();
    const forbidden = assertTenantCreatorAccess(c, body?.creatorId);
    if (forbidden) return forbidden;
    const authUser = c.get('authUser');
    const post = vhunambiDb.upsertKineticPost({
      ...body,
      creatorId: authUser
        ? resolveEffectiveCreatorId(c, body?.creatorId, authUser.creatorId)
        : body?.creatorId,
      creatorHandle:
        body?.creatorHandle || (authUser ? authUser.handle : '@cern'),
    });
    return c.json({ success: true, post }, 201);
  } catch (err: any) {
    return c.json({ success: false, error: err?.message || 'Invalid JSON' }, 400);
  }
});

// POST /api/explore/posts/:id/like — Optimistic post like toggle (Phase 69 REQ-P69-API-01)
exploreRoutes.post('/posts/:id/like', async (c) => {
  const postId = c.req.param('id');
  let body: any = {};
  try {
    body = await c.req.json();
  } catch (_) {}
  const effectiveCreatorId = resolveEffectiveCreatorId(
    c,
    body?.creatorId,
    'creator_cern',
  );
  const result = vhunambiDb.likeKineticPost(postId, effectiveCreatorId);
  if (!result.success) {
    return c.json({ error: 'Post not found', postId }, 404);
  }
  return c.json(result);
});

// GET /api/explore/posts/:id/comments — Threaded comments for a Kinetic Post (Phase 69 REQ-P69-API-01)
exploreRoutes.get('/posts/:id/comments', (c) => {
  const postId = c.req.param('id');
  const sort = (c.req.query('sort') || 'relevant') as 'relevant' | 'newest';
  const viewerId = c.get('authUser')?.creatorId ?? 'creator_cern';
  const comments = vhunambiDb.getKineticPostComments(postId, viewerId, sort);
  return c.json({ postId, comments, total: comments.length }, 200);
});

// POST /api/explore/posts/:id/comments — Add top-level comment or nested reply (Phase 69 REQ-P69-API-01)
exploreRoutes.post('/posts/:id/comments', async (c) => {
  const postId = c.req.param('id');
  let body: any = {};
  try {
    body = await c.req.json();
  } catch (_) {
    return c.json({ error: 'INVALID_REQUEST' }, 400);
  }
  const text = String(body?.text ?? '').trim();
  if (!text) {
    return c.json({ error: 'INVALID_REQUEST', message: 'text is required' }, 400);
  }
  const authUser = c.get('authUser');
  const comment = vhunambiDb.addKineticPostComment(postId, {
    text,
    userId: body?.userId ?? authUser?.creatorId ?? 'creator_cern',
    username:
      body?.username ?? authUser?.handle?.replace(/^@/, '') ?? 'cern',
    displayName: body?.displayName ?? authUser?.displayName ?? 'Cern',
    avatarUrl: body?.avatarUrl,
    userReelLoves: Number(body?.userReelLoves ?? 0),
    parentCommentId: body?.parentCommentId,
    replyToHandle: body?.replyToHandle,
  });
  if (!comment) {
    return c.json({ error: 'NOT_FOUND', message: `Post ${postId} not found` }, 404);
  }
  return c.json(comment, 201);
});

// POST /api/explore/comments/:id/like — Like a comment on Explore (Phase 69 REQ-P69-API-01)
exploreRoutes.post('/comments/:id/like', (c) => {
  const commentId = c.req.param('id');
  const actorId = c.get('authUser')?.creatorId ?? 'creator_cern';
  const result = vhunambiDb.likeCommentById(commentId, actorId);
  if (!result) {
    return c.json({ error: 'NOT_FOUND', message: `Comment ${commentId} not found` }, 404);
  }
  return c.json(result, 200);
});
```

### 8.3 `vhunambi_db.ts` & `edge_persistence_bridge.ts` Parity Updates
1. **Schema Columns (`vhunambi_db.ts#initPragmasAndTables`):**
   ```ts
   try {
     this.db.exec('ALTER TABLE kinetic_posts ADD COLUMN like_count INTEGER DEFAULT 0;');
   } catch (_) {}
   try {
     this.db.exec('ALTER TABLE kinetic_posts ADD COLUMN comment_count INTEGER DEFAULT 0;');
   } catch (_) {}
   try {
     this.db.exec('ALTER TABLE reel_comments ADD COLUMN parent_comment_id TEXT;');
   } catch (_) {}
   try {
     this.db.exec('ALTER TABLE reel_comments ADD COLUMN reply_to_handle TEXT;');
   } catch (_) {}
   ```
2. **Repair `applyMutationsBatch` in both `vhunambi_db.ts` and `edge_persistence_bridge.ts`:**
   ```ts
   const entityId = String(
     m.payload?.id ||
       m.payload?.postId ||
       m.payload?.originalPostId ||
       m.payload?.certificateId ||
       `gen_${Date.now()}`,
   );
   ```
   - `m.entityType === 'post' && m.action === 'like'`: increments `like_count` on `kinetic_posts`.
   - `m.entityType === 'post' && m.action === 'cosign'`: calls `this.cosignPost(entityId, m.payload?.creatorId)`.
   - `m.entityType === 'post' && m.action === 'repost'`: calls `this.repostPost(String(m.payload?.originalPostId || entityId), m.payload?.repost)`.
   - `m.entityType === 'comment' && m.action === 'create'`: calls `this.addKineticPostComment(String(m.payload?.postId || m.payload?.clipId || entityId), m.payload)`.
3. **Add `getKineticPostById`, `upsertKineticPost`, `likeKineticPost`, `getKineticPostComments`, `addKineticPostComment`, and `likeCommentById`** in both `VhunambiDatabase` (`vhunambi_db.ts`) and `EdgeIsolateDatabaseEngine` (`edge_persistence_bridge.ts`) with non-blocking `mirrorWriteThrough` to `SupabaseCloudDriver`.
