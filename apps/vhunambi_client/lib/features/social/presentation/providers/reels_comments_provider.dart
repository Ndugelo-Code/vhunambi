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
import '../../domain/models/kinetic_reaction.dart';
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
        // Resolve to top-most root if someone replied to a child ID.
        final parentObj = byId[parentId]!;
        final rootId =
            (parentObj.parentCommentId != null &&
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

/// Manages community comments, nested replies, sort modes, comment hearts,
/// and honest love badges for published kinetic reels and Kinetic Posts.
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

  /// Synchronizes comments for a specific clip or Kinetic Post ID from backend if available.
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

  /// Retrieves flat comments for a specific clip or post ID.
  List<ReelComment> commentsForClip(String clipId) {
    return state.commentsByClipId[clipId] ?? const [];
  }

  /// Retrieves hierarchical [CommentThreadNode] trees for [clipId] (`REQ-P69-THREAD-02`).
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

  /// Appends a new comment or nested reply optimistically and persists to cloud (`REQ-P69-THREAD-03..05`, `EP-P73-GIF-STICKER-MEDIA`).
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
    String? gifUrl,
    String? stickerId,
    double? mediaAspectRatio,
  }) async {
    final cleanText = text.trim();
    final cleanGifUrl = gifUrl?.trim();
    final cleanStickerId = stickerId?.trim();
    final hasGif = cleanGifUrl != null && cleanGifUrl.isNotEmpty;
    final hasSticker = cleanStickerId != null && cleanStickerId.isNotEmpty;
    if (cleanText.isEmpty && !hasGif && !hasSticker) return;

    final session = _ref?.read(authSessionProvider);
    final ownerProfile = _ref?.read(ownerProfileProvider);
    final resolvedUserId =
        session?.canonicalCreatorId ?? ownerProfile?.id ?? 'creator_cern';
    final resolvedUsername =
        (username ??
                (ownerProfile != null && ownerProfile.username.isNotEmpty
                    ? ownerProfile.username
                    : session?.rawUsername) ??
                'cern')
            .replaceFirst(RegExp(r'^@+'), '');
    final resolvedDisplayName =
        displayName ??
        (ownerProfile != null && ownerProfile.displayName.isNotEmpty
            ? ownerProfile.displayName
            : session?.displayName) ??
        'Cern';
    final resolvedAvatarUrl = ownerProfile?.avatarUrl;

    final activeReply = state.activeReplyFor(clipId);
    final effectiveParentId = parentCommentId ?? activeReply?.parentCommentId;
    final effectiveReplyHandle = replyToHandle ?? activeReply?.replyToHandle;

    final normalizedContentHandle = (contentCreatorHandle ?? '')
        .replaceFirst(RegExp(r'^@+'), '')
        .toLowerCase();
    final isAuthor =
        (contentCreatorId != null &&
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
      gifUrl: hasGif ? cleanGifUrl : null,
      stickerId: hasSticker ? cleanStickerId : null,
      mediaAspectRatio: (hasGif || hasSticker) ? mediaAspectRatio : null,
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

    final looksLikePost =
        isKineticPost ||
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
        _ref
            ?.read(notificationsProvider.notifier)
            .addNotification(
              NotificationEntity(
                id: 'notif_comment_${newComment.id}',
                title: notifTitle,
                message: cleanText.isNotEmpty
                    ? '"${newComment.text}" posted to the discussion thread.'
                    : 'Studio reaction media posted to the discussion thread.',
                category: NotificationCategory.social,
                priority: NotificationPriority.normal,
                subtype: 'comment',
                targetRoute: '$routePrefix$clipId',
                targetEntityId: clipId,
                ctaLabel: looksLikePost
                    ? 'Open Post Discussion'
                    : 'Watch Kinetic Reel',
                createdAt: newComment.createdAt,
              ),
            );
      } catch (_) {}
    }

    if (looksLikePost && _ref != null) {
      try {
        await _ref
            .read(exploreRepositoryProvider)
            .addPostComment(
              postId: clipId,
              text: cleanText,
              userId: resolvedUserId,
              username: resolvedUsername,
              displayName: resolvedDisplayName,
              avatarUrl: resolvedAvatarUrl,
              userReelLoves: userReelLoves,
              parentCommentId: effectiveParentId,
              replyToHandle: effectiveReplyHandle,
              gifUrl: hasGif ? cleanGifUrl : null,
              stickerId: hasSticker ? cleanStickerId : null,
              mediaAspectRatio:
                  (hasGif || hasSticker) ? mediaAspectRatio : null,
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
          gifUrl: hasGif ? cleanGifUrl : null,
          stickerId: hasSticker ? cleanStickerId : null,
          mediaAspectRatio: (hasGif || hasSticker) ? mediaAspectRatio : null,
        );
      } catch (_) {}
    }
  }

  /// Toggles the current user's like on a specific comment or reply.
  void toggleCommentLike({required String clipId, required String commentId}) {
    final currentList = state.commentsByClipId[clipId];
    if (currentList == null) return;
    final target = currentList.cast<ReelComment?>().firstWhere(
      (c) => c?.id == commentId,
      orElse: () => null,
    );
    if (target == null) return;
    final currentlyActive = target.myReaction != null || target.isLikedByMe;
    reactToComment(
      clipId: clipId,
      commentId: commentId,
      reaction: currentlyActive ? null : KineticReactionType.love,
    );
  }

  /// Applies, switches, or clears a multi-reaction on a comment/reply with legacy count preservation.
  void reactToComment({
    required String clipId,
    required String commentId,
    required KineticReactionType? reaction,
  }) {
    final currentList = state.commentsByClipId[clipId];
    if (currentList == null) return;

    KineticReactionType? effectiveNext;
    final updated = [
      for (final comment in currentList)
        if (comment.id == commentId)
          () {
            final counts = Map<KineticReactionType, int>.from(
              comment.reactionCounts,
            );
            final sum = counts.values.fold<int>(0, (a, b) => a + b);
            if (sum == 0 && comment.likeCount > 0) {
              counts[KineticReactionType.love] = comment.likeCount;
            }
            final prevReaction =
                comment.myReaction ??
                (comment.isLikedByMe ? KineticReactionType.love : null);
            if (prevReaction != null) {
              final nextPrev = (counts[prevReaction] ?? 0) - 1;
              if (nextPrev > 0) {
                counts[prevReaction] = nextPrev;
              } else {
                counts.remove(prevReaction);
              }
            }
            effectiveNext =
                (reaction != null &&
                    reaction == prevReaction &&
                    comment.myReaction != null)
                ? null
                : reaction;
            if (effectiveNext != null) {
              counts[effectiveNext!] = (counts[effectiveNext!] ?? 0) + 1;
            }
            final nextTotal = counts.values.fold<int>(0, (a, b) => a + b);
            return comment.copyWith(
              reactionCounts: Map<KineticReactionType, int>.unmodifiable(
                counts,
              ),
              myReaction: effectiveNext,
              clearMyReaction: effectiveNext == null,
              isLikedByMe: effectiveNext != null,
              likeCount: nextTotal,
            );
          }()
        else
          comment,
    ];

    state = state.copyWith(
      commentsByClipId: {...state.commentsByClipId, clipId: updated},
    );
    _persistCommentsForClip(clipId, updated);
    final isKineticPost =
        clipId.startsWith('post_') || clipId.startsWith('kpost_');
    if (isKineticPost && _ref != null) {
      unawaited(
        _ref
            .read(exploreRepositoryProvider)
            .reactToComment(commentId, effectiveNext),
      );
      return;
    }
    if (_repo != null) {
      unawaited(_repo.reactToComment(commentId, effectiveNext));
    }
  }

  void _seedComments() {
    final now = DateTime.now();

    final clip1Comments = [
      ReelComment(
        id: 'c_seed_101',
        clipId: 'clip_seed_01',
        userId: 'u_thabo',
        username: 'thabo_beats',
        displayName: 'Thabo Beats',
        text:
            'This log drum hits directly in the chest! 🎹🔥 Top tier production.',
        likeCount: 48,
        isLikedByMe: false,
        userReelLoves: 5,
        createdAt: now.subtract(const Duration(minutes: 18)),
      ),
      ReelComment(
        id: 'c_seed_102',
        clipId: 'clip_seed_01',
        userId: 'u_lerato',
        username: 'lerato_piano',
        displayName: 'Lerato Piano',
        text: 'Makhado sunrise vibe 🌅 Tshivenḓa lyrics sound incredible.',
        likeCount: 89,
        isLikedByMe: true,
        userReelLoves: 8,
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      ReelComment(
        id: 'c_seed_103',
        clipId: 'clip_seed_01',
        userId: 'creator_makhadzi',
        username: 'makhadzi',
        displayName: 'Makhadzi',
        isCreator: true,
        text:
            'Ndo livhuwa vhathu vhanga! (Thank you my people!) ❤️ New drop soon!',
        likeCount: 230,
        isLikedByMe: true,
        userReelLoves: 12,
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      ReelComment(
        id: 'c_seed_104',
        clipId: 'clip_seed_01',
        userId: 'u_kgothatso',
        username: 'kgothatso_sa',
        displayName: 'Kgothatso',
        text: 'Proudly South African 🇿🇦 Need this on Spotify ASAP.',
        likeCount: 15,
        isLikedByMe: false,
        userReelLoves: 2,
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
    ];

    final clip2Comments = [
      ReelComment(
        id: 'c_seed_201',
        clipId: 'clip_seed_02',
        userId: 'u_sibusiso',
        username: 'sbu_gqom',
        displayName: 'Sibusiso',
        text: 'Durban heavy bass kick! 🔥👑',
        likeCount: 34,
        isLikedByMe: false,
        userReelLoves: 3,
        createdAt: now.subtract(const Duration(minutes: 45)),
      ),
    ];

    final post001Comments = [
      ReelComment(
        id: 'c_post001_1',
        clipId: 'post_001',
        userId: 'u_thabo',
        username: 'thabo_beats',
        displayName: 'Thabo Beats',
        text: 'This log drum hits directly in the chest! Top tier production.',
        likeCount: 48,
        isLikedByMe: false,
        userReelLoves: 5,
        createdAt: now.subtract(const Duration(minutes: 42)),
      ),
      ReelComment(
        id: 'c_post001_2',
        clipId: 'post_001',
        userId: 'creator_makhadzi',
        username: 'makhadzi',
        displayName: 'Makhadzi',
        isCreator: true,
        parentCommentId: 'c_post001_1',
        replyToHandle: '@thabo_beats',
        text:
            'Ndo livhuwa! Wait until you hear Stem 2 in the open verse remix.',
        likeCount: 19,
        isLikedByMe: false,
        userReelLoves: 1,
        createdAt: now.subtract(const Duration(minutes: 25)),
      ),
      ReelComment(
        id: 'c_post001_3',
        clipId: 'post_001',
        userId: 'u_lerato',
        username: 'lerato_piano',
        displayName: 'Lerato Piano',
        text:
            'Makhado sunrise vibe. Tshivenḓa lyrics sound incredible over that sub.',
        likeCount: 89,
        isLikedByMe: true,
        userReelLoves: 8,
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      ReelComment(
        id: 'c_post001_4',
        clipId: 'post_001',
        userId: 'u_kgothatso',
        username: 'kgothatso_sa',
        displayName: 'Kgothatso',
        text:
            'Proudly South African sound. Already queued the stems for tonight!',
        likeCount: 15,
        isLikedByMe: false,
        userReelLoves: 2,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
    ];

    final post001RemixFifiComments = [
      ReelComment(
        id: 'c_post001_rmx_1',
        clipId: 'post_001_remix_fifi',
        userId: 'creator_makhadzi',
        username: 'makhadzi',
        displayName: 'Makhadzi',
        text:
            'That open verse vocal pocket fits the Limpopo bounce effortlessly.',
        likeCount: 24,
        userReelLoves: 4,
        createdAt: now.subtract(const Duration(minutes: 30)),
      ),
      ReelComment(
        id: 'c_post001_rmx_2',
        clipId: 'post_001_remix_fifi',
        userId: 'creator_fifi',
        username: 'fifi_vocals',
        displayName: 'Fifi Vocals',
        isCreator: true,
        parentCommentId: 'c_post001_rmx_1',
        replyToHandle: '@makhadzi',
        text:
            'Thank you queen! Kept the 70/30 split active for anyone else jumping on.',
        likeCount: 14,
        createdAt: now.subtract(const Duration(minutes: 15)),
      ),
    ];

    final post002Comments = [
      ReelComment(
        id: 'c_post002_1',
        clipId: 'post_002',
        userId: 'u_kabza',
        username: 'kabza_keys',
        displayName: 'Kabza Keys',
        text: 'F# Minor Rhodes voicing on the turnaround is pure Soweto soul.',
        likeCount: 31,
        userReelLoves: 4,
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      ReelComment(
        id: 'c_post002_2',
        clipId: 'post_002',
        userId: 'creator_sigwa',
        username: 'sigwa_inaf',
        displayName: 'Sigwa & Inaf',
        isCreator: true,
        parentCommentId: 'c_post002_1',
        replyToHandle: '@kabza_keys',
        text:
            'Recorded straight through the vintage preamp in Soweto this morning.',
        likeCount: 12,
        createdAt: now.subtract(const Duration(minutes: 35)),
      ),
      ReelComment(
        id: 'c_post002_3',
        clipId: 'post_002',
        userId: 'u_sbu',
        username: 'sbu_gqom',
        displayName: 'Sibusiso',
        text: 'Need this full stem pack in the beatstore ASAP.',
        likeCount: 9,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
    ];

    final post003Comments = [
      ReelComment(
        id: 'c_post003_1',
        clipId: 'post_003',
        userId: 'u_sbu',
        username: 'sbu_gqom',
        displayName: 'Sibusiso',
        text: '128 BPM Durban warehouse kick knocks hard on club monitors.',
        likeCount: 22,
        userReelLoves: 3,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      ReelComment(
        id: 'c_post003_2',
        clipId: 'post_003',
        userId: 'creator_djvibe',
        username: 'djvibe',
        displayName: 'DJ Vibe',
        isCreator: true,
        parentCommentId: 'c_post003_1',
        replyToHandle: '@sbu_gqom',
        text: 'Zero compression clipping on the sub bus - pure punch.',
        likeCount: 11,
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
    ];

    final post004Comments = [
      ReelComment(
        id: 'c_post004_1',
        clipId: 'post_004',
        userId: 'u_lerato',
        username: 'lerato_piano',
        displayName: 'Lerato Piano',
        text:
            'Tshikona horn cadence layered with log drum arpeggios is genius.',
        likeCount: 18,
        userReelLoves: 3,
        createdAt: now.subtract(const Duration(hours: 4)),
      ),
      ReelComment(
        id: 'c_post004_2',
        clipId: 'post_004',
        userId: 'creator_ndugelo',
        username: 'ndugelo',
        displayName: 'Ndugelo',
        isCreator: true,
        parentCommentId: 'c_post004_1',
        replyToHandle: '@lerato_piano',
        text:
            'Respect! Bridging Venda heritage crate roots with modern groove tools.',
        likeCount: 10,
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
    ];

    final post005Comments = [
      ReelComment(
        id: 'c_post005_1',
        clipId: 'post_005',
        userId: 'u_thabo',
        username: 'thabo_beats',
        displayName: 'Thabo Beats',
        text: 'Maboneng golden hour harmonies sound lush on this vocal stack.',
        likeCount: 16,
        userReelLoves: 2,
        createdAt: now.subtract(const Duration(hours: 6)),
      ),
      ReelComment(
        id: 'c_post005_2',
        clipId: 'post_005',
        userId: 'creator_fifi',
        username: 'fifi',
        displayName: 'Fifi',
        isCreator: true,
        parentCommentId: 'c_post005_1',
        replyToHandle: '@thabo_beats',
        text: 'Shoutout Soweto Youth Choir archetype for the warm chorus lift.',
        likeCount: 8,
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
    ];

    state = state.copyWith(
      commentsByClipId: {
        'clip_seed_01': clip1Comments,
        'clip_seed_02': clip2Comments,
        'post_001': post001Comments,
        'post_001_remix_fifi': post001RemixFifiComments,
        'post_002': post002Comments,
        'post_003': post003Comments,
        'post_004': post004Comments,
        'post_005': post005Comments,
      },
    );
  }
}

/// Global provider for kinetic reels comments.
final reelsCommentsProvider =
    StateNotifierProvider<ReelsCommentsNotifier, ReelsCommentsState>((ref) {
      ref.watch(currentCreatorIdProvider);
      final repo = ref.watch(socialRepositoryProvider);
      return ReelsCommentsNotifier(repo, ref);
    });

/// Family provider to observe comments for a single reel reactively.
final clipCommentsFamilyProvider = Provider.family<List<ReelComment>, String>((
  ref,
  clipId,
) {
  final state = ref.watch(reelsCommentsProvider);
  return state.commentsByClipId[clipId] ?? const [];
});
