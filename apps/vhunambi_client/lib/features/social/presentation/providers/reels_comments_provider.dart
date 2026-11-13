import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_providers.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/sovereign_domain_repositories.dart';
import '../../domain/models/reel_comment.dart';
import '../../domain/repositories/i_social_repository.dart';
import 'social_repository_provider.dart';

/// State containing all comments grouped by clip ID (REQ-COM-01 / REQ-COM-02).
class ReelsCommentsState {
  final Map<String, List<ReelComment>> commentsByClipId;
  final bool isLoading;

  const ReelsCommentsState({
    this.commentsByClipId = const {},
    this.isLoading = false,
  });

  ReelsCommentsState copyWith({
    Map<String, List<ReelComment>>? commentsByClipId,
    bool? isLoading,
  }) {
    return ReelsCommentsState(
      commentsByClipId: commentsByClipId ?? this.commentsByClipId,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Manages community comments, TikTok-style comment hearts, and honest
/// love badges for published kinetic reels.
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

  /// Synchronizes comments for a specific clip ID from backend if available.
  Future<void> syncCommentsForClip(String clipId) async {
    if (_repo == null) return;
    try {
      final remote = await _repo.getComments(clipId);
      if (!mounted) return;
      if (remote.isNotEmpty) {
        state = state.copyWith(
          commentsByClipId: {...state.commentsByClipId, clipId: remote},
        );
        _persistCommentsForClip(clipId, remote);
      }
    } catch (_) {}
  }

  /// Retrieves comments for a specific clip ID.
  List<ReelComment> commentsForClip(String clipId) {
    return state.commentsByClipId[clipId] ?? const [];
  }

  /// Appends a new comment optimistically at the top of the thread.
  Future<void> addComment({
    required String clipId,
    required String text,
    int userReelLoves = 0,
    String? username,
    String? displayName,
    String? giftEmoji,
    String? giftName,
  }) async {
    if (text.trim().isEmpty) return;

    final session = _ref?.read(authSessionProvider);
    final resolvedUserId = session?.canonicalCreatorId ?? 'creator_cern';
    final resolvedUsername = username ?? session?.rawUsername ?? 'cern';
    final resolvedDisplayName =
        displayName ?? session?.displayName ?? 'cern';

    final newComment = ReelComment(
      id: 'c_${DateTime.now().millisecondsSinceEpoch}',
      clipId: clipId,
      userId: resolvedUserId,
      username: resolvedUsername,
      displayName: resolvedDisplayName,
      text: text.trim(),
      userReelLoves: userReelLoves,
      giftEmoji: giftEmoji,
      giftName: giftName,
      createdAt: DateTime.now(),
    );

    final currentList = state.commentsByClipId[clipId] ?? const [];
    final updatedList = [newComment, ...currentList];
    state = state.copyWith(
      commentsByClipId: {...state.commentsByClipId, clipId: updatedList},
    );
    _persistCommentsForClip(clipId, updatedList);

    if (_repo != null) {
      try {
        await _repo.addComment(
          clipId: clipId,
          text: text,
          username: resolvedUsername,
          displayName: resolvedDisplayName,
          userReelLoves: userReelLoves,
          giftEmoji: giftEmoji,
          giftName: giftName,
        );
      } catch (_) {}
    }
  }

  /// Toggles the current user's like on a specific comment (TikTok-style).
  void toggleCommentLike({required String clipId, required String commentId}) {
    final currentList = state.commentsByClipId[clipId];
    if (currentList == null) return;

    final updated = [
      for (final comment in currentList)
        if (comment.id == commentId)
          comment.copyWith(
            isLikedByMe: !comment.isLikedByMe,
            likeCount: comment.likeCount + (comment.isLikedByMe ? -1 : 1),
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

    state = state.copyWith(
      commentsByClipId: {
        'clip_seed_01': clip1Comments,
        'clip_seed_02': clip2Comments,
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
