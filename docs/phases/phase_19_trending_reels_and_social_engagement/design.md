# Phase 19 · Design — Trending Reels Discovery & TikTok Community Engagement

> **Phase:** 19  
> **Codename:** `trending-reels-and-social-engagement`  
> **Status:** 🟡 SPECIFICATION  
> **Target App:** `apps/vhunambi_client`  
> **Architecture Standard:** Dual-Agent Pair Programming Standard ([`docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md))  

---

## 1. Domain Models & Entities

### 1.1 `ReelComment` Entity
```dart
// lib/features/social/domain/models/reel_comment.dart

import 'package:flutter/foundation.dart';

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
  
  /// Number of times this commenter loved the reel (honest community badge).
  final int userReelLoves;
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
    required this.createdAt,
  });

  ReelComment copyWith({
    int? likeCount,
    bool? isLikedByMe,
    int? userReelLoves,
  }) {
    return ReelComment(
      id: id,
      clipId: clipId,
      userId: userId,
      username: username,
      displayName: displayName,
      avatarUrl: avatarUrl,
      isCreator: isCreator,
      text: text,
      likeCount: likeCount ?? this.likeCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      userReelLoves: userReelLoves ?? this.userReelLoves,
      createdAt: createdAt,
    );
  }
}
```

### 1.2 `PublishedClip` Enhancements
Add `userReactionCount` to `PublishedClip` (default 0) to represent how many times the current logged-in user has loved the reel.
```dart
// Added to PublishedClip:
final int userReactionCount;
```

---

## 2. Riverpod State Providers

### 2.1 `ReelsCommentsNotifier` & Provider
```dart
// lib/features/social/presentation/providers/reels_comments_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/reel_comment.dart';

class ReelsCommentsState {
  /// Map of clipId -> List of comments
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

class ReelsCommentsNotifier extends StateNotifier<ReelsCommentsState> {
  ReelsCommentsNotifier() : super(const ReelsCommentsState()) {
    _seedDefaultComments();
  }

  List<ReelComment> getComments(String clipId) =>
      state.commentsByClipId[clipId] ?? [];

  void addComment({
    required String clipId,
    required String text,
    int userReelLoves = 0,
  }) {
    final newComment = ReelComment(
      id: 'c_${DateTime.now().millisecondsSinceEpoch}',
      clipId: clipId,
      userId: 'user_current',
      username: 'ndugelo_musician',
      displayName: 'Ndugelo Musician',
      text: text,
      userReelLoves: userReelLoves,
      createdAt: DateTime.now(),
    );

    final existing = state.commentsByClipId[clipId] ?? [];
    state = state.copyWith(
      commentsByClipId: {
        ...state.commentsByClipId,
        clipId: [newComment, ...existing],
      },
    );
  }

  void toggleCommentLike(String clipId, String commentId) {
    final existing = state.commentsByClipId[clipId] ?? [];
    final updated = [
      for (final c in existing)
        if (c.id == commentId)
          c.copyWith(
            isLikedByMe: !c.isLikedByMe,
            likeCount: c.likeCount + (c.isLikedByMe ? -1 : 1),
          )
        else
          c,
    ];

    state = state.copyWith(
      commentsByClipId: {
        ...state.commentsByClipId,
        clipId: updated,
      },
    );
  }
}
```

### 2.2 `TrendingReelsNotifier` & Provider
```dart
// lib/features/social/presentation/providers/trending_reels_provider.dart

final trendingReelsGenreProvider = StateProvider<String>((ref) => 'All');

final trendingReelsProvider = Provider<List<PublishedClip>>((ref) {
  final feedState = ref.watch(socialFeedProvider);
  final activeGenre = ref.watch(trendingReelsGenreProvider);

  var clips = feedState.clips;
  if (activeGenre != 'All') {
    clips = clips.where((c) => c.genre.toLowerCase() == activeGenre.replaceAll('#', '').toLowerCase()).toList();
  }
  return clips;
});
```

---

## 3. Presentation Layer & Widgets

### 3.1 `ReelsCommentSheet`
- Route: Opened via `showModalBottomSheet(context: context, isScrollControlled: true, ...)` from `KineticReelsModal`.
- Key Elements:
  - Drag handle at top.
  - Header: `"Comments (${comments.length})"` and close `X` button.
  - Top Supporter highlight if any user loved the reel >= 3 times.
  - Scrollable `ListView.separated` of comment cards.
  - Cultural emoji pill row: `🔥`, `👑`, `🇿🇦`, `🎹`, `🐐`, `❤️`.
  - Quick praise chips row: `"This log drum hits different! 🎹"`, `"Makhado sunrise vibe 🌅"`.
  - Floating bottom composer with text field and send arrow button.

### 3.2 `TrendingReelsShelf`
- Reusable sliver or box widget for `ExploreView` and `HomeDashboardView`.
- Horizontal scroll view of `TrendingReelCard` widgets.
- Genre filter chips: `All`, `#Amapiano`, `#Gqom`, `#Maskandi`, `#AfroHouse`.
- Tapping a card opens `KineticReelsModal` centered on that reel.

### 3.3 Multi-Tap Love Bursts in `KineticReelsModal`
- In `_ActionRail`:
  - Heart icon displays filled red / brandPrimary with tap counter.
  - Tapping calls `recordLove(clipId)`.
  - Animated floating heart particle overlay bursts on tap.
