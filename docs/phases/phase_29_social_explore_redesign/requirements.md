# Requirements Specification: Phase 29
## V4.1 Social Explore Redesign (TikTok Search & Reel Tabs + Facebook Stories Rail, Compact Discovery Drawer & Creator Music Feed)

> **Document ID:** `REQ-PHASE-29-EXPLORE`  
> **Status:** 🟡 SPECIFICATION  
> **Standard:** RFC 2119 & EARS (Easy Approach to Requirements Syntax)  
> **Target Apps:** `apps/vhunambi_client`, `apps/vhunambi_api`

---

## 1. Executive Summary & RFC 2119 Imperatives

This document defines the formal, testable acceptance criteria for **Phase 29: V4.1 Social Explore Redesign**. All requirements are tagged with unique identifiers and categorized under functional groups. Every statement strictly complies with RFC 2119 imperatives (`MUST`, `SHALL`, `SHOULD`, `MAY`).

---

## 2. EARS Requirements Matrix

### Category 1: Minimalist Top Bar, Transient Title Pill & 1-Step Mobile Navigation

* **`REQ-EXP-TOPBAR-01` (Top Bar Chrome Simplification)**:
  The system SHALL render a minimalist 56dp mobile top bar (`MobileExploreTopBar`) and 68dp desktop top bar (`DesktopExploreTopBar`) on `/explore`. The system MUST NOT embed an inline, always-expanded `TextField` on the mobile top bar.
* **`REQ-EXP-TOPBAR-02` (Permanent Elimination of Studio '+' Button)**:
  The system MUST NOT render the orange `+` Studio Create button inside the Explore top bar, shifting creation entrypoints exclusively to the Stories Rail and Bottom Dock.
* **`REQ-EXP-TOPBAR-03` (Transient 4-Second "Explore" Title Pill)**:
  WHEN the user navigates to the Explore tab, the system SHALL render a transient `"Explore"` title pill (`Key('explore_transient_title_pill')`) adjacent to the brand logo. The system SHALL display this pill with full opacity for 4.0 seconds, after which it MUST automatically fade out and collapse its width to 0 via `AnimatedOpacity` and `AnimatedSize`.
* **`REQ-EXP-TOPBAR-04` (Timer Cancellation & Flakiness Guardrail)**:
  WHEN `MobileExploreTopBar` or `_TransientExploreTitlePill` is disposed, the system MUST cancel the 4-second fade timer immediately. The widget SHALL NOT leave active timers pending in widget test environments.
* **`REQ-EXP-TOPBAR-05` (Action Icon Triad)**:
  The system SHALL render three 44×44dp HIG-compliant icon buttons on the trailing side of `MobileExploreTopBar`:
  1. Discovery Drawer icon (`Icons.grid_view_rounded` or `Icons.explore_rounded`, `Key('explore_open_discovery_drawer_btn')`).
  2. Search icon (`Icons.search_rounded`, `Key('explore_open_search_view_btn')`).
  3. Notifications Bell icon (`Icons.notifications_rounded` with unread badge, `Key('explore_open_notifications_btn')`).
* **`REQ-EXP-TOPBAR-06` (1-Step Mobile Notifications Navigation)**:
  WHEN the user taps `Key('explore_open_notifications_btn')` on a mobile viewport (`ResponsiveUtils.isMobile(context)` is true), the system MUST navigate directly to `NotificationsView` in 1 step via `Navigator.push`. The system MUST NOT mount a desktop hover modal on mobile.
* **`REQ-EXP-TOPBAR-07` (Removal of Static Title & Subtitle Redundancy)**:
  The system SHALL NOT render the static multi-line header (`"Explore / Discover AI music from creators around the world"`) in `ExploreView`, allowing the Kinetic Reels rail to mount immediately beneath the top bar.

---

### Category 2: Dedicated Full-Screen TikTok-Style Search View

* **`REQ-EXP-SEARCH-01` (Full-Screen Dedicated View)**:
  WHEN the user taps `Key('explore_open_search_view_btn')`, the system SHALL push a dedicated full-screen `ExploreSearchView` (`Key('explore_search_view')`).
* **`REQ-EXP-SEARCH-02` (Auto-Focused Search Input & Safe Keyboard Exit)**:
  The `ExploreSearchView` SHALL feature an auto-focused search textfield (`Key('explore_search_input')`) with a leading back button (`Key('explore_search_back_btn')`) and a trailing clear button. WHEN the user taps back, the keyboard MUST dismiss and returning to `ExploreView` SHALL NOT re-focus any text input.
* **`REQ-EXP-SEARCH-03` (Persistent Recent Searches with Hive)**:
  The system SHALL display a "Recent Searches" history section in `ExploreSearchView`. The user SHALL be able to tap any recent query to re-execute it, tap `✕` on an individual item to remove it, or tap `"Clear all"` to wipe the query history.
* **`REQ-EXP-SEARCH-04` ("You May Like" African Trending Queries)**:
  The system SHALL display curated trending African music chips in `ExploreSearchView` (including `#Amapiano2026`, `Tshivenḓa log drum`, `Maskandi top 10`, `Gqom warehouse`, `Private School Rhodes`). Tapping a chip SHALL populate the query input and trigger search.
* **`REQ-EXP-SEARCH-05` (Multi-Dimensional Tabbed Results)**:
  WHEN query length $\ge 1$, the system SHALL render tabbed search results across 4 categories:
  - `Top` (unified blended matches).
  - `Songs (MP3)` (`TrackCard` / `TrackListTile`).
  - `Kinetic Reels` (9:16 video thumbnails).
  - `Creators` (`CreatorCard` / `ArtistProfileView` link).

---

### Category 3: Facebook Stories-Style Kinetic Reels Rail with Card #0 `[ ➕ Post Reel ]`

* **`REQ-EXP-REEL-RAIL-01` (Card #0 'Post Kinetic Reel')**:
  In `TrendingReelsShelf`, the system SHALL render `Key('explore_post_kinetic_reel_card')` as **Card #0 at the far left** of the horizontal scrollable reels list.
* **`REQ-EXP-REEL-RAIL-02` (Post Reel Visual Design)**:
  Card #0 MUST display the current user's profile avatar (or placeholder monogram), an elevated `+` action badge in `AppColors.brandPrimary`, and the label `"Post Reel"`.
* **`REQ-EXP-REEL-RAIL-03` (Post Reel Quick Launch)**:
  WHEN the user taps `Key('explore_post_kinetic_reel_card')`, the system SHALL open a bottom sheet modal allowing the user to select any track from their library vault to launch `PublishClipModal` / `ContentStudioDockView`.
* **`REQ-EXP-REEL-RAIL-04` (Clutter-Free Micro-Header)**:
  The system MUST NOT render redundant multi-line headers above the reels rail. The system SHALL render a single-line micro-header with compact genre filter pills (`All`, `Amapiano`, `Gqom`, `Afrobeat`, `Kwaito`, `Maskandi`).

---

### Category 4: TikTok-Style Filter Tabs Inside `KineticReelsModal`

* **`REQ-EXP-REEL-TABS-01` (Top Filter Navigation Bar)**:
  WHEN `KineticReelsModal` is displayed, the system SHALL render a translucent top bar featuring 4 filter tabs:
  - `Trending` (`Key('reels_modal_tab_trending')`)
  - `For You` (`Key('reels_modal_tab_for_you')`)
  - `Following` (`Key('reels_modal_tab_following')`)
  - `Newest` (`Key('reels_modal_tab_newest')`)
* **`REQ-EXP-REEL-TABS-02` (In-Stream Live Filtering)**:
  WHEN the user taps any filter tab inside `KineticReelsModal`, the system SHALL re-sort or filter the active video reel page view stream without closing the modal or stopping background audio ducking.
* **`REQ-EXP-REEL-TABS-03` (In-Reel Search Trigger)**:
  The system SHALL render a compact `🔍` search icon (`Key('reels_modal_search_btn')`) on the trailing side of the `KineticReelsModal` top bar, routing directly to `ExploreSearchView`.
* **`REQ-EXP-REEL-TABS-04` (Creator Profile Deep-Link)**:
  WHEN the user taps a creator's `@handle` or avatar inside `KineticReelsModal`, the system MUST navigate to `ArtistProfileView` (`/profile/:id`).

---

### Category 5: Facebook-Style Compact Discovery Drawer (`ExploreDiscoveryDrawerSheet`)

* **`REQ-EXP-DRAWER-01` (Drawer Sheet Trigger)**:
  WHEN the user taps `Key('explore_open_discovery_drawer_btn')`, the system SHALL mount a frosted bottom sheet (`ExploreDiscoveryDrawerSheet`).
* **`REQ-EXP-DRAWER-02` (Utility & Streaming Shortcuts)**:
  The drawer SHALL organize MP3 streaming and engagement features into high-contrast grid tiles:
  1. `📈 African Music Charts` (Top 50 regional rankings).
  2. `📻 12-Genre Radio Stations` (1-tap streaming launcher for Amapiano, Gqom, etc.).
  3. `🚀 Rising MP3 Tracks` (Fastest growing audio in 48 hours).
  4. `🔥 Listening Streak & Creator DNA` (Daily streak count and DNA profile badge).
  5. `👑 Top Creators Directory` (Directory of active verified African producers).

---

### Category 6: Unified Creator Music Social Feed (`ExploreSocialPostCard`)

* **`REQ-EXP-FEED-01` (Social Music Post Architecture)**:
  Below the Kinetic Reels rail, the primary scroll body SHALL render a vertical feed of `ExploreSocialPostCard` items representing social releases by African creators.
* **`REQ-EXP-FEED-02` (Creator Header & Direct Follow)**:
  Each post MUST display the creator's avatar, display name, verified checkmark (if verified), relative timestamp (e.g., `"2h ago"`), location/genre tag, and an interactive `[ + Follow ]` button (`Key('social_post_follow_${post.id}')`). Tapping the creator avatar or name SHALL open `ArtistProfileView`.
* **`REQ-EXP-FEED-03` (Embedded Playable MP3 Card & Waveform)**:
  Each post SHALL embed a playable audio card featuring:
  - Track cover art with genre gradient fallback.
  - Track title, genre, BPM, scale/key, and language.
  - Interactive play/pause button bound to `playerStateProvider`.
  - Animated 16-bar waveform visualizer indicating live playback.
* **`REQ-EXP-FEED-04` (Full Social Engagement Bar)**:
  Each post MUST provide 5 interactive touch actions meeting $\ge 44 \times 44\text{dp}$ touch bounds:
  - `❤️ Like` (optimistic toggle with counter).
  - `💬 Comment` (opens comments thread modal).
  - `🔁 Remix in Studio` (loads stem/scale/vocal DNA into Create Studio).
  - `💸 Tip` (opens cultural micro-tipping bottom sheet).
  - `↗️ Share` (system share sheet).
* **`REQ-EXP-FEED-05` (Interleaved Streaming Carousels)**:
  The social feed SHALL interleave horizontal discovery strips (`12-Genre Radio Stations`, `Rising MP3s`, or `African Charts`) every 5th slot (`(idx + 1) % 5 == 0`, `postIndex = idx - (idx ~/ 5)`), ensuring exactly 4 social music posts precede each carousel and zero posts are skipped.

---

### Category 7: Accessibility, Touch Compliance & Verification

* **`REQ-EXP-TOUCH-01` (Apple HIG / WCAG 44×44dp Mandate)**:
  Every interactive element in the top bar, reels rail, social post, and drawer MUST have a minimum bounding box of 44×44dp (`BoxConstraints(minWidth: 44, minHeight: 44)`).
* **`REQ-EXP-THEME-01` (Zero Raw Hex Rule)**:
  All colors, gradients, typography, and borders MUST reference design tokens from `AppColors`, `AppGradients`, `AppTypography`, `AppRadius`, and `AppSpacing`.

---

## 3. Requirements Traceability Matrix

| Requirement ID | Target File | Acceptance Test File | Verification Standard |
| :--- | :--- | :--- | :--- |
| `REQ-EXP-TOPBAR-01..07` | `explore_top_bar.dart` | `phase29_social_explore_test.dart` | Widget test verifying 56dp height, transient fade timer, 1-step notifs, and absence of inline textfield. |
| `REQ-EXP-SEARCH-01..05` | `explore_search_view.dart` | `phase29_social_explore_test.dart` | Widget test verifying full-screen push, recent searches, trending chips, and category filtering. |
| `REQ-EXP-REEL-RAIL-01..04` | `trending_reels_shelf.dart` | `phase29_social_explore_test.dart` | Widget test verifying Card #0 `➕ Post Reel` at index 0 and track picker modal opening. |
| `REQ-EXP-REEL-TABS-01..04` | `kinetic_reels_modal.dart` | `phase29_social_explore_test.dart` | Widget test verifying 4 top filter tabs, in-reel re-sorting, and profile deep-linking. |
| `REQ-EXP-DRAWER-01..02` | `explore_discovery_drawer_sheet.dart` | `phase29_social_explore_test.dart` | Widget test verifying drawer opening and shortcut navigation. |
| `REQ-EXP-FEED-01..05` | `explore_social_post_card.dart`, `explore_view.dart` | `phase29_social_explore_test.dart` | Widget test verifying social post cards, waveform play/pause, remix action, and interleaved carousels. |
| `REQ-EXP-TOUCH-01` | All Explore Widgets | `phase29_social_explore_test.dart` | Automated hit-test boundary check ($\ge 44 \times 44\text{dp}$). |

