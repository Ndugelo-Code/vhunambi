# Tasks: Phase 29
## V4.1 Social Explore Redesign (TikTok Search & Reel Tabs + Facebook Stories Rail, Compact Discovery Drawer & Creator Music Feed)

> **Document ID:** `TASKS-PHASE-29-EXPLORE`  
> **Status:** 🟡 SPECIFICATION  
> **Prerequisites:** `blueprint.md`, `requirements.md`, `design.md`

---

## 1. Pre-Flight Verification Checklist

Before starting implementation:
- [ ] Working tree clean (`git status`).
- [ ] Static analysis baseline (`cmd /c "cd apps\vhunambi_client && dart analyze lib test"` returns 0 issues).
- [ ] Backend test baseline (`cmd /c "cd apps\vhunambi_api && pnpm test"` passes 11/11 suites).
- [ ] Client test baseline (`flutter test test/features/explore test/features/social` passes).

---

## 2. Sequenced Implementation Tracks

### Track A: Domain Models & Riverpod Providers
- [ ] **Task 29.1 (Domain Models)**:
  - Create `apps/vhunambi_client/lib/features/explore/domain/models/social_music_post.dart` declaring `@immutable class SocialMusicPost` with relative time, copyWith, equality, and seed posts.
  - Update `apps/vhunambi_client/lib/features/explore/domain/models/explore_models.dart` to export `ReelFeedTab` and `ExploreSearchCategory`.
- [ ] **Task 29.2 (Riverpod Providers)**:
  - Add `activeReelTabProvider`, `filteredReelsByTabProvider`, `followingCreatorIdsProvider`, `socialFeedPostsProvider`, and `recentSearchesProvider` to `lib/features/explore/presentation/providers/explore_providers.dart`.

---

### Track B: Minimalist Top Bar, Transient 4-Second Title & 1-Step Mobile Navigation
- [ ] **Task 29.3 (`explore_top_bar.dart` Redesign)**:
  - Remove permanent inline `TextField` from `MobileExploreTopBar`.
  - Remove orange Studio `+` button from `MobileExploreTopBar`.
  - Implement `_TransientExploreTitlePill` (`Key('explore_transient_title_pill')`): displays `"Explore"` for 4.0 seconds, then collapses via `AnimatedOpacity` and `AnimatedSize`.
  - Expose `resetExploreTitleFade(WidgetRef ref)` to reset/re-show the title whenever the Explore tab is selected in `RootShell`'s `IndexedStack`. Cancel `Timer? _fadeTimer` safely in `dispose()`.
  - Add trailing icon triad:
    1. `_DiscoveryDrawerButton` (`Key('explore_open_discovery_drawer_btn')`).
    2. `_SearchIconButton` (`Key('explore_open_search_view_btn')`).
    3. `_NotificationBellButton` (`Key('explore_open_notifications_btn')`): On mobile, navigates directly to `NotificationsView` (from `package:vhunambi_client/features/notifications/presentation/views/notifications_view.dart`) in 1 step!
- [ ] **Task 29.4 (Header Clutter Elimination)**:
  - Remove redundant static header in `ExploreView` (`ExploreHeaderSection`).

---

### Track C: Dedicated Full-Screen TikTok Search View (`ExploreSearchView`)
- [ ] **Task 29.5 (`explore_search_view.dart`)**:
  - Create `apps/vhunambi_client/lib/features/explore/presentation/views/explore_search_view.dart`.
  - Implement auto-focused search bar (`Key('explore_search_input')`) with back arrow (`Key('explore_search_back_btn')`) and clear action (`Key('explore_search_clear_btn')`).
  - Render **Recent Searches** with `Key('explore_recent_clear_all')` and per-item remove.
  - Render **"You May Like" African Trending Queries** (`#Amapiano2026`, `Tshivenḓa log drum`, etc.).
  - Render tabbed category results (`Top`, `Songs`, `Reels`, `Creators`).

---

### Track D: Facebook Stories-Style Kinetic Reels Rail with Card #0 `[ ➕ Post Reel ]`
- [ ] **Task 29.6 (`trending_reels_shelf.dart` Upgrade & Closing FINDING-EXP-005)**:
  - Remove multi-line text clutter above the shelf in favor of sleek micro-header and compact genre pills.
  - Render **`Key('explore_post_kinetic_reel_card')` as Card #0 on the far left** of the horizontal ListView.
  - Style Card #0 with user avatar/placeholder + `+` badge in `AppColors.brandPrimary` + `"Post Reel"`.
  - Tapping Card #0 opens quick track picker modal to launch `PublishClipModal` / `ContentStudioDockView`.
  - In `PublishClipModal`, ensure publishing a reel automatically adds a corresponding `SocialMusicPost` to `socialFeedPostsProvider.notifier.addPost(...)` so user creations appear at the top of the Explore Social Feed immediately.

---

### Track E: TikTok-Style Top Filter Tabs Inside `KineticReelsModal`
- [ ] **Task 29.7 (`kinetic_reels_modal.dart` Upgrade & Token Safety)**:
  - Add translucent top bar (`Key('reels_modal_top_bar')`) with 4 filter tabs:
    - `Trending` (`Key('reels_modal_tab_trending')`)
    - `For You` (`Key('reels_modal_tab_for_you')`)
    - `Following` (`Key('reels_modal_tab_following')`)
    - `Newest` (`Key('reels_modal_tab_newest')`)
  - **Token Safety Rule**: For active tab text on the dark translucent bar, strictly use `AppColors.textPrimary` (white) with `AppColors.brandPrimary` (`#F97316`) underline indicator. NEVER use `AppColors.brandContrast` (which is `#000000` black)!
  - Add search icon on the trailing side (`Key('reels_modal_search_btn')`) routing to `ExploreSearchView`.
  - Connect creator `@handle` and avatar taps to open `ArtistProfileView`.

---

### Track F: Facebook-Style Compact Discovery Drawer (`ExploreDiscoveryDrawerSheet`)
- [ ] **Task 29.8 (`explore_discovery_drawer_sheet.dart`)**:
  - Create `apps/vhunambi_client/lib/features/explore/presentation/widgets/explore_discovery_drawer_sheet.dart`.
  - Render structured grid shortcuts:
    - `Key('drawer_item_charts')`: 📈 African Music Charts.
    - `Key('drawer_item_radio')`: 📻 12-Genre Radio Stations.
    - `Key('drawer_item_rising')`: 🚀 Rising MP3 Tracks.
    - `Key('drawer_item_streak')`: 🔥 Listening Streak & DNA.
    - `Key('drawer_item_creators')`: 👑 Top Creators Directory.

---

### Track G: Unified Creator Music Social Feed (`ExploreSocialPostCard` in `ExploreView`)
- [ ] **Task 29.9 (`explore_social_post_card.dart`)**:
  - Create `apps/vhunambi_client/lib/features/explore/presentation/widgets/explore_social_post_card.dart`.
  - Header: Creator avatar, name, handle, verified badge, and direct follow button (`Key('social_post_follow_${post.id}')`).
  - Caption text.
  - Embedded playable MP3 card with cover, title, metadata badge, 16-bar waveform visualizer, and play/pause button (`Key('social_post_play_btn_${post.id}')`).
  - Action bar: Like (`Key('social_post_like_btn_${post.id}')`), Comment (`Key('social_post_comment_btn_${post.id}')`), Remix in Studio (`Key('social_post_remix_btn_${post.id}')`), Tip (`Key('social_post_tip_btn_${post.id}')`), Share.
- [ ] **Task 29.10 (`explore_view.dart` Feed Integration & Zero-Skip Interleaving)**:
  - Mount `TrendingReelsShelf` at the top.
  - Mount feed switcher pills (`For You`, `Following`, `All Songs`, `🧭 Discovery Drawer`).
  - Render `SliverList` of `ExploreSocialPostCard` with zero-skip 5-slot stride interleaving:
    - `final isCarouselSlot = (idx + 1) % 5 == 0;`
    - `final postIndex = idx - (idx ~/ 5);`
    - Ensures exactly 4 `ExploreSocialPostCard`s render before each interleaved carousel (12-Genre Radio, Rising MP3s) and zero posts are skipped.

---

### Track H: Verification & Quality Gate
- [ ] **Task 29.11 (Integration Tests & Legacy Test Realignment)**:
  - Realign legacy assertions in `test/features/explore/explore_view_test.dart` that tested the old static header and inline textfield.
  - Create `apps/vhunambi_client/test/features/explore/phase29_social_explore_test.dart` testing:
    - Top bar transient 4s title fade & timer cancellation.
    - 1-step mobile notifications navigation.
    - Search icon opening `ExploreSearchView`.
    - Card #0 `➕ Post Reel` launching picker.
    - TikTok tabs in `KineticReelsModal` re-sorting clips.
    - Discovery drawer shortcuts.
    - Social post play/pause, like, follow, and remix actions.
- [ ] **Task 29.12 (Static Analysis & Monorepo Test Run)**:
  - Run `dart analyze lib test` $\rightarrow$ 0 issues found.
  - Run `flutter test test/features/explore test/features/social` $\rightarrow$ 100% passing.
  - Run backend `pnpm test` $\rightarrow$ 11/11 suites passing.

---

## 3. Potential Pitfalls & Traps Warnings

> [!CAUTION]
> **Timer Leak Warning**: The 4-second `"Explore"` title fade timer must be stored in a `Timer? _fadeTimer;` and cancelled inside `dispose()`. Never use an unhandled `Future.delayed` without checking `mounted`, as this causes widget test timer leaks!

> [!WARNING]
> **Keyboard Refocus Bug**: Do NOT include any hidden or transparent `TextField`s in `MobileExploreTopBar`. The search text field belongs strictly inside `ExploreSearchView`. When navigating back from full-screen dialogs, focus must remain on the canvas, not a text input.

> [!IMPORTANT]
> **Touch Target Bounds**: All top bar icons (`🧭`, `🔍`, `🔔`), reel filter tabs, and social post buttons must explicitly enforce `minWidth: 44, minHeight: 44` to maintain Apple HIG compliance.

