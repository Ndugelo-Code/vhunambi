# Design Specification: Phase 29
## V4.1 Social Explore Redesign (TikTok Search & Reel Tabs + Facebook Stories Rail, Compact Discovery Drawer & Creator Music Feed)

> **Document ID:** `DESIGN-PHASE-29-EXPLORE`  
> **Status:** 🟡 SPECIFICATION  
> **Target Apps:** `apps/vhunambi_client`, `apps/vhunambi_api`

---

## 1. Domain Models & Immutable Entities

### 1.1 `SocialMusicPost` (Client Entity)
```dart
// lib/features/explore/domain/models/social_music_post.dart
import 'package:flutter/foundation.dart';
import '../../../../shared/models/track.dart';

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

  String get relativeTimeAgo {
    final diff = DateTime.now().difference(publishedAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

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
}
```

### 1.2 `ReelFeedTab` & `ExploreSearchCategory` Enums
```dart
// lib/features/explore/domain/models/explore_models.dart (additions)
enum ReelFeedTab {
  trending,
  forYou,
  following,
  newest,
}

enum ExploreSearchCategory {
  top,
  songs,
  reels,
  creators,
  beats,
}
```

---

## 2. Riverpod State Management & Providers

### 2.1 Top-Bar Transient Title Provider
```dart
// lib/features/explore/presentation/providers/explore_providers.dart (additions)

/// Controls the transient 4-second title pill visibility.
final exploreTitlePillVisibleProvider = StateProvider<bool>((ref) => true);

/// Helper to trigger / reset the transient 4s title pill whenever Tab 1 (Explore)
/// becomes the active visible tab in RootShell's IndexedStack.
void resetExploreTitleFade(WidgetRef ref) {
  ref.read(exploreTitlePillVisibleProvider.notifier).state = true;
}
```

### 2.2 Active Reel Feed Tab Provider (Inside `KineticReelsModal`)
```dart
final activeReelTabProvider = StateProvider<ReelFeedTab>((ref) => ReelFeedTab.trending);

/// Returns the reels stream sorted/filtered by activeReelTabProvider.
final filteredReelsByTabProvider = Provider<List<PublishedClip>>((ref) {
  final tab = ref.watch(activeReelTabProvider);
  final allClips = ref.watch(trendingReelsProvider);
  final following = ref.watch(followingCreatorIdsProvider);

  return switch (tab) {
    ReelFeedTab.trending => [...allClips]..sort((a, b) => b.likeCount.compareTo(a.likeCount)),
    ReelFeedTab.forYou => allClips, // Ranked via DNA
    ReelFeedTab.following => allClips.where((c) => following.contains(c.creatorId)).toList(),
    ReelFeedTab.newest => [...allClips]..sort((a, b) => b.publishedAt.compareTo(a.publishedAt)),
  };
});
```

### 2.3 Following Creators State Notifier
```dart
final followingCreatorIdsProvider = StateNotifierProvider<FollowingCreatorsNotifier, Set<String>>((ref) {
  return FollowingCreatorsNotifier();
});

class FollowingCreatorsNotifier extends StateNotifier<Set<String>> {
  FollowingCreatorsNotifier() : super({'creator_makhadzi'});

  void toggleFollow(String creatorId) {
    if (state.contains(creatorId)) {
      state = state.where((id) => id != creatorId).toSet();
    } else {
      state = {...state, creatorId};
    }
  }

  bool isFollowing(String creatorId) => state.contains(creatorId);
}
```

### 2.4 Social Music Posts Feed Provider
```dart
final socialFeedPostsProvider = StateNotifierProvider<SocialFeedPostsNotifier, List<SocialMusicPost>>((ref) {
  return SocialFeedPostsNotifier();
});

class SocialFeedPostsNotifier extends StateNotifier<List<SocialMusicPost>> {
  SocialFeedPostsNotifier() : super(_seedSocialPosts());

  void toggleLike(String postId) {
    state = [
      for (final post in state)
        if (post.id == postId)
          post.copyWith(
            isLikedByMe: !post.isLikedByMe,
            likeCount: post.isLikedByMe ? post.likeCount - 1 : post.likeCount + 1,
          )
        else
          post,
    ];
  }

  void addPost(SocialMusicPost post) {
    state = [post, ...state];
  }
}
```

### 2.5 Recent Searches Provider (Hive backed with In-Memory fallback)
```dart
final recentSearchesProvider = StateNotifierProvider<RecentSearchesNotifier, List<String>>((ref) {
  return RecentSearchesNotifier();
});

class RecentSearchesNotifier extends StateNotifier<List<String>> {
  RecentSearchesNotifier() : super(const [
    'Kabza de Small log drum',
    'Amapiano 2026 drops',
    'Makhadzi live vocals',
    'Gqom bass kick',
  ]);

  void addQuery(String query) {
    final clean = query.trim();
    if (clean.isEmpty) return;
    state = [clean, ...state.where((q) => q.toLowerCase() != clean.toLowerCase())].take(10).toList();
  }

  void removeQuery(String query) {
    state = state.where((q) => q != query).toList();
  }

  void clearAll() {
    state = const [];
  }
}
```

---

## 3. Widget Decomposition & Mandatory Keys

### 3.1 `explore_top_bar.dart` Redesign
* **Path:** `apps/vhunambi_client/lib/features/explore/presentation/widgets/explore_top_bar.dart`
* **Components:**
  - `_TransientExploreTitlePill`:
    - `Key('explore_transient_title_pill')`
    - Displays `"Explore"` with `AppColors.brandPrimary` dot.
    - Disposes timer cleanly on teardown.
  - `_DiscoveryDrawerButton`:
    - `Key('explore_open_discovery_drawer_btn')`
    - Icon: `Icons.grid_view_rounded` (44×44dp hit-box).
    - Opens `ExploreDiscoveryDrawerSheet`.
  - `_SearchIconButton`:
    - `Key('explore_open_search_view_btn')`
    - Icon: `Icons.search_rounded` (44×44dp hit-box).
    - Pushes `ExploreSearchView`.
  - `_NotificationBellButton`:
    - `Key('explore_open_notifications_btn')`
    - Icon: `Icons.notifications_rounded` + unread count badge.
    - On mobile, `Navigator.push` to `NotificationsView` (from `package:vhunambi_client/features/notifications/presentation/views/notifications_view.dart`) in 1 step!

### 3.2 `explore_search_view.dart`
* **Path:** `apps/vhunambi_client/lib/features/explore/presentation/views/explore_search_view.dart`
* **Components & Keys:**
  - `Key('explore_search_view')`: Full-screen scaffold.
  - `Key('explore_search_back_btn')`: Back arrow popping view.
  - `Key('explore_search_input')`: Auto-focused `TextField` with `searchHint`.
  - `Key('explore_search_clear_btn')`: Clears current text.
  - `Key('explore_recent_clear_all')`: Wipes search history.
  - `Key('explore_search_tab_top')`: 'Top' category tab.
  - `Key('explore_search_tab_songs')`: 'Songs' category tab.
  - `Key('explore_search_tab_reels')`: 'Kinetic Reels' tab.
  - `Key('explore_search_tab_creators')`: 'Creators' tab.

### 3.3 `trending_reels_shelf.dart` Stories-Style Upgrade
* **Path:** `apps/vhunambi_client/lib/features/social/presentation/widgets/trending_reels_shelf.dart`
* **Components & Keys:**
  - `Key('explore_post_kinetic_reel_card')`: Card #0 on far left.
    - Displays current user's avatar + elevated `+` badge in `AppColors.brandPrimary`.
    - Label: `"Post Reel"`.
    - Tapping opens track selection sheet (`_showPostReelSheet`).
  - `Key('trending_card_${clip.id}')`: Reel cards #1..N.

### 3.4 `kinetic_reels_modal.dart` TikTok Top Filter Tabs
* **Path:** `apps/vhunambi_client/lib/features/social/presentation/widgets/kinetic_reels_modal.dart`
* **Components & Keys:**
  - `Key('reels_modal_top_bar')`: Translucent glass top bar.
  - `Key('reels_modal_tab_trending')`: Trending filter tab.
  - `Key('reels_modal_tab_for_you')`: For You filter tab.
  - `Key('reels_modal_tab_following')`: Following filter tab.
  - `Key('reels_modal_tab_newest')`: Newest filter tab.
  - **Token Safety**: Active tab text MUST use `AppColors.textPrimary` (white) with `AppColors.brandPrimary` (`#F97316`) underline bar. NEVER use `AppColors.brandContrast` (which is `#000000` black) on the dark translucent bar!
  - `Key('reels_modal_search_btn')`: 🔍 icon button opening `ExploreSearchView`.
  - `Key('reels_modal_creator_link_${clip.id}')`: Creator handle tapping opens `ArtistProfileView`.

### 3.5 `explore_discovery_drawer_sheet.dart`
* **Path:** `apps/vhunambi_client/lib/features/explore/presentation/widgets/explore_discovery_drawer_sheet.dart`
* **Components & Keys:**
  - `Key('explore_discovery_drawer')`: Modal bottom sheet.
  - `Key('drawer_item_charts')`: 📈 African Music Charts shortcut (opens African Charts sheet/rankings).
  - `Key('drawer_item_radio')`: 📻 12-Genre Radio Stations shortcut (opens genre picker and launches continuous radio stream via `playExploreGenreRadio`).
  - `Key('drawer_item_rising')`: 🚀 Rising Tracks shortcut (opens 48h rising MP3s ranking modal).
  - `Key('drawer_item_streak')`: 🔥 Listening Streak & DNA shortcut (displays daily listening streak counter and cultural taste DNA archetype).
  - `Key('drawer_item_creators')`: 👑 Top Creators directory shortcut (opens verified African producers roster, deep-linking to `ArtistProfileView`).

### 3.6 `explore_social_post_card.dart`
* **Path:** `apps/vhunambi_client/lib/features/explore/presentation/widgets/explore_social_post_card.dart`
* **Components & Keys:**
  - `Key('social_post_card_${post.id}')`: Container.
  - `Key('social_post_creator_${post.id}')`: Avatar & name tap target (opens profile).
  - `Key('social_post_follow_${post.id}')`: Direct follow/unfollow toggle button.
  - `Key('social_post_play_btn_${post.id}')`: Play/Pause embedded MP3 track button.
  - `Key('social_post_like_btn_${post.id}')`: ❤️ Like button.
  - `Key('social_post_comment_btn_${post.id}')`: 💬 Comment button.
  - `Key('social_post_remix_btn_${post.id}')`: 🔁 Remix in Studio button.
  - `Key('social_post_tip_btn_${post.id}')`: 💸 Tip Creator button.
* **Interleaving & Stride Math in `ExploreView`**:
  - Interleave carousels every 5th slot: `final isCarouselSlot = (idx + 1) % 5 == 0;`
  - Map post indices cleanly: `final postIndex = idx - (idx ~/ 5);`
  - Guarantees exactly 4 `ExploreSocialPostCard`s render before each carousel, with zero skipped posts!
* **Closing `FINDING-EXP-005` (Creation-to-Feed Loop)**:
  - When a user publishes a clip in `PublishClipModal` (or via Card #0 `➕ Post Reel`), insert a corresponding `SocialMusicPost` into `socialFeedPostsProvider.notifier.addPost(...)` so newly published user releases appear at the top of the feed immediately.

---

## 4. Responsive Breakpoint Matrix

| View / Element | Mobile (< 768px) | Tablet (768–1024px) | Desktop (> 1024px) |
| :--- | :--- | :--- | :--- |
| **Top Bar** | Compact 56dp: Logo + 4s fade pill + 3 action icons | 68dp: Logo + wide search bar + icons | 68dp: Logo + 560px search with `Ctrl+K` + full credit badge |
| **Kinetic Reels Rail** | Height: 156dp (width: 110dp per card) | Height: 180dp (width: 130dp per card) | Height: 200dp (width: 145dp per card) |
| **Social Music Post** | Full width padding (16dp), embedded track card | Constrained max-width 640dp centered | Constrained max-width 680dp centered |
| **Discovery Drawer** | Bottom sheet modal sliding up to 65% height | Bottom sheet modal sliding up to 50% height | Popover card anchored to menu button |

---

## 5. Error Recovery & Test Resilience

1. **Timer Teardown**: The 4-second title fade timer uses a `Timer? _fadeTimer;` variable in `_TransientExploreTitlePillState` and invokes `_fadeTimer?.cancel()` inside `dispose()`.
2. **Offline Fallback**: `ExploreSearchView` queries local catalog and Hive cache if network is unavailable.
3. **Soft-Keyboard Pop-up Guard**: Removing the permanent inline `TextField` from `MobileExploreTopBar` completely eliminates the auto-focus glitch when returning from full-screen modals.

