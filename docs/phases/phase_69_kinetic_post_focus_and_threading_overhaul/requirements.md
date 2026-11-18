# Phase 69 — Kinetic Post Focus Domain, Threaded Replies & Feed Card Refinement Requirements

> **Document ID:** `VHUNAMBI-SPEC-P69-REQUIREMENTS-V1`  
> **Specification Format:** EARS (Easy Approach to Requirements Syntax) & RFC-2119 (`SHALL` / `SHALL NOT`)  
> **UI/UX & Theme Governance:** `STD-UIUX-001` (100% Phosphor Iconography, Zero Raw Unicode Emojis, Dynamic `*Of(context)` Dual-Theme Adaptation, Minimum `44x44dp` Touch Targets)

---

## 1. Scope, Standards & Conventions

This document defines the normative functional, cross-boundary API/schema, and non-functional requirements for **Phase 69: Kinetic Post Focus Domain, Threaded Replies & Feed Card Refinement**, structured across **Overhaul Pass 1 (`M69.1` – `M69.2`)** and **Overhaul Pass 2 (`M69.3` – `M69.4`)**.

1. **EARS Syntax Conventions:**
   - **Ubiquitous (`SHALL`):** Holds across all viewports, themes, and runtime states.
   - **Event-Driven (`WHEN ... SHALL ...`):** Triggered immediately by a user gesture, provider mutation, or HTTP/sync event.
   - **State-Driven (`WHILE ... SHALL ...`):** Active throughout a continuous state condition.
   - **Conditional (`IF ... THEN SHALL ...`):** Applies under explicit fallback, offline, or edge conditions.
2. **Global Invariants:**
   - **Zero Dead-Tap Post Law:** Every non-button surface of a Kinetic Post card (caption, card body, media canvas, and engagement summary strip) SHALL navigate into `KineticPostFocusView`.
   - **Sticky Non-Occluding Composer Law:** Inside `KineticPostFocusView`, the comment composer bar SHALL dock at the bottom of the screen above `MediaQuery.viewInsetsOf(context).bottom` while the post header, caption, artwork, sonic pill, and comment thread scroll freely above it.
   - **Zero Raw Unicode Emoji Law (`STD-UIUX-001`):** No raw Unicode emoji characters (`🔥`, `👑`, `🇿🇦`, `🎹`, `🐐`, `❤️`, `🌅`, `🚀`) or stock Material `Icons.*` SHALL appear in `ExploreSocialPostCard`, `KineticPostFocusView`, `ReelsCommentSheet`, `ExploreView`, or `ExploreDiscoveryDrawerSheet`.

---

## 2. Overhaul Pass 1 Requirements (`M69.1` – `M69.2`): Feed Card Refinement, Repost Identity, Threaded Comments & `KineticPostFocusView`

### 2.1 Repost & Composer Identity Resolution (`M69.1`)
- **`REQ-P69-ID-01` (Authentic Repost Creator Identity):**  
  **WHEN** a user submits a repost or quote-post in `RepostKineticPostSheet`, the created `SocialMusicPost` SHALL resolve `creatorId`, `creatorName`, `creatorHandle`, `creatorAvatarUrl`, and `isCreatorVerified` from `ownerProfileProvider` and `authSessionProvider` (falling back to `'creator_cern'` / `'Cern'` / `'@cern'` only when both are uninitialized), and SHALL NEVER hardcode `'current_user'`, `'You'`, or `'@current_user'`.
- **`REQ-P69-ID-02` (Live Composer Bar Avatar):**  
  `KineticPostComposerBar` SHALL be a `ConsumerWidget` watching `ownerProfileProvider` and rendering `SafeNetworkAvatar` (with `owner.avatarUrl` and `owner.displayName` fallback monogram) instead of hardcoded `'CE'`.

### 2.2 `ExploreSocialPostCard` Visual Hierarchy & Engagement Summary Strip (`M69.1`)
- **`REQ-P69-CARD-01` (Compact Header Provenance & Follow Layout):**  
  `ExploreSocialPostCard` SHALL integrate the provenance badge (`Key('post_provenance_badge_${post.id}')`) cleanly alongside the creator metadata header so it does not consume a separate vertical row between the header and caption, while preserving `Key('social_post_creator_${post.id}')`, `Key('social_post_own_badge_${post.id}')`, and `Key('social_post_follow_${post.id}')`.
- **`REQ-P69-CARD-02` (Normalized Media Canvas with `VhunambiTrackArtwork`):**  
  **WHEN** `post.hasVisuals` is true, `ExploreSocialPostCard` SHALL normalize every attachment URL via `AppConstants.normalizeCloudMediaUrl` and fall back to `VhunambiTrackArtwork(coverUrl: post.track.coverUrl, genre: post.track.genre, trackId: post.track.id)` on network/asset decode errors.
- **`REQ-P69-CARD-03` (Compact Remix Lineage & Co-Sign Strip):**  
  `ExploreSocialPostCard` SHALL render the Remix Lineage pill (`Key('post_remix_tree_btn_${post.id}')`) and Co-Sign pill (`Key('post_cosign_btn_${post.id}')`) in a compact single row below the media canvas / sonic pill, using `PhosphorIcon(PhosphorIconsFill.fire)` with zero raw `'🔥'` emoji prefix in the label text (`'Graduated · ${post.cosignCount}'` or `'Co-Sign · ${post.cosignCount}/25'`).
- **`REQ-P69-CARD-04` (Facebook-Benchmark Engagement Summary Strip):**  
  Above the bottom action rail, `ExploreSocialPostCard` SHALL render `Key('social_post_engagement_strip_${post.id}')` displaying live formatted counts (`Likes`, `Comments`, `Reposts`, `Remixes`) separated by subtle dot dividers, and a `1px` `AppColors.borderSubtleOf(context)` divider line.
- **`REQ-P69-CARD-05` (100% Dynamic `*Of(context)` Theme Adaptation):**  
  `ExploreSocialPostCard` and `KineticPostSonicPill` SHALL resolve all card surfaces, inset pills, borders, and text colors through `AppColors.surfaceElevatedOf(context)`, `surfaceSecondaryOf(context)`, `borderSubtleOf(context)`, `textPrimaryOf(context)`, and `textSecondaryOf(context)`.

### 2.3 Threaded Comment Domain, Reply State, Sorting & `STD-UIUX-001` Reaction Chips (`M69.1` – `M69.2`)
- **`REQ-P69-THREAD-01` (`ReelComment` Threading Fields & Serialization):**  
  `ReelComment` SHALL include optional `final String? parentCommentId;` and `final String? replyToHandle;` fields (with `bool get isReply => parentCommentId != null && parentCommentId!.isNotEmpty`), persisted in `toJson()` / `fromJson()` and backward-compatible with legacy flat JSON records.
- **`REQ-P69-THREAD-02` (`CommentSortOrder` & `CommentThreadNode` Grouping):**  
  `ReelsCommentsNotifier` SHALL expose `CommentSortOrder` (`mostRelevant`, `newest`) and `List<CommentThreadNode> threadsForClip(String clipId)` where each `CommentThreadNode` groups a root comment (`parentCommentId == null`) with its chronological child replies (`parentCommentId == parent.id`), ranked by $S_{\text{rel}}(r)$ under `mostRelevant` or `createdAt DESC` under `newest`.
- **`REQ-P69-THREAD-03` (Interactive `Reply` Tap & Active Reply Banner):**  
  - Every comment and child reply tile SHALL render an interactive `Reply` control (`Key('comment_reply_btn_${comment.id}')`, minimum `44x44dp` hit target).
  - **WHEN** tapped, `ReelsCommentsNotifier.setActiveReplyTarget` SHALL set the active reply target to `(parentCommentId: rootParentId, replyToCommentId: comment.id, replyToHandle: '@${comment.username}')`, display the dismissible `"Replying to @${comment.username}"` banner (`Key('comment_active_reply_banner')` with close button `Key('comment_cancel_reply_btn')`), and focus `Key('comment_input')`.
- **`REQ-P69-THREAD-04` (`View N replies` / `Hide replies` Thread Expansion):**  
  - **WHEN** a root comment has $\ge 1$ child replies, `ThreadedCommentsSection` SHALL render `Key('comment_toggle_replies_${parent.id}')` (`'View ${replies.length} ${replies.length == 1 ? 'reply' : 'replies'}'` when collapsed, `'Hide replies'` when expanded) and indent expanded child replies by `36dp` with a vertical thread guide line.
  - **WHEN** the current user submits a new reply to `parent.id`, that parent thread SHALL automatically expand so the newly posted reply is immediately visible.
- **`REQ-P69-THREAD-05` (`Author` Badge Auto-Detection & Live Post Comment Counter Sync):**  
  - **WHEN** a comment or reply is authored by the creator of the parent `SocialMusicPost` or `PublishedClip` (matching `creatorId` or handle), `isCreator` SHALL evaluate to `true` and render the `'Author'` / `'Creator'` badge (`Key('comment_author_badge_${comment.id}')`).
  - **WHEN** `ReelsCommentsNotifier.addComment` adds a comment or reply to a Kinetic Post ID, it SHALL call `socialFeedPostsProvider.notifier.incrementCommentCount(clipId)` and emit a post-aware notification (`targetRoute: '/post/$clipId'`).
- **`REQ-P69-THREAD-06` (Seeded Threaded Discussions for `post_001`–`post_005`):**  
  `ReelsCommentsNotifier._seedComments()` SHALL seed realistic multi-turn South African creator discussions (including nested replies and creator responses) for `post_001`, `post_001_remix_fifi`, `post_002`, `post_003`, `post_004`, and `post_005`, and align `seedSocialPosts()` initial `commentCount` values with the seeded comment counts so card counters and focus threads match 1:1 on cold boot.
- **`REQ-P69-STD-01` (Phosphor Studio Reaction Chips in Composer):**  
  `StudioReactionComposerBar` (used in both `KineticPostFocusView` and `ReelsCommentSheet`) SHALL replace raw Unicode emoji chips (`🔥`, `👑`, `🇿🇦`, `🎹`, `🐐`, `❤️`) with `STD-UIUX-001` Phosphor studio reaction chips (`Key('comment_reaction_chip_fire')`, `Key('comment_reaction_chip_crown')`, `Key('comment_reaction_chip_log_drum')`, `Key('comment_reaction_chip_soul')`, `Key('comment_reaction_chip_vocals')`, `Key('comment_reaction_chip_sa_vibe')`) and clean praise phrase chips (`'Hits different!'`, `'Makhado sunrise'`, `'Top tier production'`, `'Proudly SA'`).
- **`REQ-P69-STD-02` (Complete Material `Icons.*` & Raw Emoji Purge in Explore/Social):**  
  All stock `Icons.*` and raw emojis in `reels_comment_sheet.dart`, `explore_social_post_card.dart`, `explore_view.dart`, and `explore_discovery_drawer_sheet.dart` SHALL be replaced with `PhosphorIcon(AppIcons.* / PhosphorIconsRegular.* / PhosphorIconsFill.*)`.

### 2.4 Full-Screen `KineticPostFocusView` & Universal Post Navigation (`M69.2`)
- **`REQ-P69-FOCUS-01` (1-Tap Card, Caption & Media Navigation into `KineticPostFocusView`):**  
  **WHEN** a user taps the card body (`Key('social_post_card_tap_${post.id}')`), caption (`Key('social_post_caption_tap_${post.id}')`), media canvas (`Key('social_post_media_tap_${post.id}')`), or engagement summary strip (`Key('social_post_engagement_strip_${post.id}')`) on `ExploreSocialPostCard`, the client SHALL push `KineticPostFocusView(postId: post.id, initialPost: post)` via `Navigator.of(context).push(...)`.
- **`REQ-P69-FOCUS-02` (Comment Action Button Opens Focus View with Composer Focus):**  
  **WHEN** a user taps `Key('social_post_comment_btn_${post.id}')` on `ExploreSocialPostCard`, the client SHALL push `KineticPostFocusView(postId: post.id, initialPost: post, autofocusComposer: true)`.
- **`REQ-P69-FOCUS-03` (Inline Sonic Pill Play Button Isolation):**  
  **WHEN** a user taps `Key('social_post_play_btn_${post.id}')` inside `KineticPostSonicPill`, the client SHALL toggle audio playback inline via `playerStateProvider` without triggering navigation into `KineticPostFocusView`.
- **`REQ-P69-FOCUS-04` (`KineticPostFocusView` Full-Screen Architecture & Multi-Image Counter Badge):**  
  `KineticPostFocusView` (`Key('kinetic_post_focus_view_${post.id}')`) SHALL render:
  1. Top navigation bar with `Key('kpost_focus_back_btn')` (`< Post`), creator handle title (`@${handle}'s Post`), `Key('kpost_focus_tip_btn')` (launching `CreatorTippingSheet`), and `Key('kpost_focus_share_btn')`.
  2. Scrollable `CustomScrollView` containing the complete creator header, full untruncated caption, full-bleed interactive image carousel (with top-right counter badge `Key('kpost_focus_image_counter_${post.id}')` rendering `'${_currentImageIndex + 1}/${images.length}'` whenever `images.length > 1`, or `VhunambiTrackArtwork` + `KineticPostSonicPill`), Remix Lineage & Co-Sign telemetry strip, Engagement Summary Strip, 4-button Focus Action Bar (`Like`, `Comment`, `Repost`, `Remix`), and the integrated `ThreadedCommentsSection`.
  3. Sticky bottom `StudioReactionComposerBar` docked above `MediaQuery.viewInsetsOf(context).bottom` so typing a comment or reply never covers the scrollable post above it.
- **`REQ-P69-FOCUS-05` (`/post/:id` Deep-Link Routing in `NotificationDeepLinkRouter`):**  
  **WHEN** `NotificationDeepLinkRouter.navigateDirect` receives a notification with `effectiveRoute` starting with `'/post/'`, it SHALL resolve the target `SocialMusicPost` from `socialFeedPostsProvider` (or synthesize a fallback post from notification metadata) and push `KineticPostFocusView(postId: postId)`.

---

## 3. Overhaul Pass 2 Requirements (`M69.3` – `M69.4`): `ReelsCommentSheet` Unification & Backend `/api/v1/explore/posts*` Persistence

### 3.1 `ReelsCommentSheet` Modal Threading Unification (`M69.3`)
- `ReelsCommentSheet` (`reels_comment_sheet.dart`) SHALL delegate its comment list and reply-aware composer to the shared `ThreadedCommentsSection` and `StudioReactionComposerBar` widgets (`REQ-P69-THREAD-01` .. `REQ-P69-THREAD-06`, `REQ-P69-STD-01`, `REQ-P69-STD-02`) so Reels bottom-sheet comments and Kinetic Post Focus discussions share 100% identical nested reply threading, sorting, and `STD-UIUX-001` reaction chips.

### 3.2 Backend `/api/v1/explore/posts*` REST Endpoints, Schema Migration & Sync Repair (`M69.4`)
- **`REQ-P69-API-01` (Explore Kinetic Posts & Threaded Comments REST Surface):**  
  `explore_routes.ts` (mounted at `/api/explore` and `/api/v1/explore`) SHALL expose:
  1. `GET /posts/:id` — returns a single Kinetic Post by ID (`404` if not found).
  2. `POST /posts` — creates/upserts a Kinetic Post (`201 Created`).
  3. `POST /posts/:id/like` — toggles per-actor like (`post_like` in `social_interactions`) and updates `kinetic_posts.like_count` (`200 OK` `{ liked, likeCount }`).
  4. `POST /posts/:id/repost` — increments `repost_count` on `:id` and, when a repost payload is provided, inserts the new repost record into `kinetic_posts` (`200 OK`).
  5. `GET /posts/:id/comments?sort=relevant|newest` — returns all comments and replies for post `:id` (`200 OK` `{ postId, comments, total }`).
  6. `POST /posts/:id/comments` — validates `{ text, parentCommentId?, replyToHandle?, userId?, username?, displayName?, avatarUrl?, userReelLoves? }`, inserts into `reel_comments` (supporting both `kinetic_posts` and `published_clips` targets), and increments `kinetic_posts.comment_count` (`201 Created`).
  7. `POST /comments/:id/like` — toggles `comment_like` for the authenticated actor and updates `likeCount` (`200 OK` `{ liked, likeCount }`).
- **`REQ-P69-API-02` (`social_routes.ts` & `social_service.ts` Threading & Post Fallback Parity):**  
  `CreateCommentSchema` in `social_routes.ts` and `addComment` in `social_service.ts` SHALL accept optional `parentCommentId` and `replyToHandle`, and if `clipId` is not found in `published_clips` but exists in `kinetic_posts`, `addComment` / `getComments` SHALL transparently service the Kinetic Post rather than returning `404`.
- **`REQ-P69-DB-01` (SQLite, Edge Isolate & Supabase Schema Parity):**  
  - `kinetic_posts` SHALL include `like_count INTEGER NOT NULL DEFAULT 0` and `comment_count INTEGER NOT NULL DEFAULT 0` across `vhunambi_db.ts`, `edge_persistence_bridge.ts`, and `supabase/migrations/20261118000001_phase69_kinetic_posts_and_threaded_comments.sql`.
  - `reel_comments` SHALL include `parent_comment_id TEXT` and `reply_to_handle TEXT` (plus index `idx_reel_comments_parent`) across all three layers.
- **`REQ-P69-DB-02` (`applyMutationsBatch` Counter & Entity ID Repair):**  
  In both `vhunambi_db.ts` and `edge_persistence_bridge.ts`, `applyMutationsBatch` SHALL:
  1. Resolve `entityId` as `m.payload?.id || m.payload?.postId || m.payload?.originalPostId || m.payload?.certificateId || 'gen_' + Date.now()`.
  2. When `m.entityType === 'post'` and `m.action === 'like'`, increment `like_count` (NEVER `cosign_count`).
  3. When `m.entityType === 'post'` and `m.action === 'cosign'`, increment `cosign_count`.
  4. When `m.entityType === 'post'` and `m.action === 'repost'`, increment `repost_count` on `originalPostId ?? entityId` and upsert `m.payload.repost` if present.
  5. When `m.entityType === 'comment'` and `m.action === 'create'`, insert the comment via `insertReelComment` and increment the parent post/clip `comment_count`.

---

## 4. Non-Functional Requirements (`REQ-P69-NFR-*`)

| ID | Category | Normative Requirement |
| :--- | :--- | :--- |
| **`REQ-P69-NFR-01`** | **60 FPS Scroll & Keyboard Ergonomics** | `KineticPostFocusView` SHALL use a single `CustomScrollView` above a docked composer container so soft-keyboard transitions (`MediaQuery.viewInsetsOf(context).bottom`) animate at 60 FPS without covering or unmounting the post canvas. |
| **`REQ-P69-NFR-02`** | **Compact Mobile (`360dp`) Overflow Safety** | `ExploreSocialPostCard`, `KineticPostFocusView`, and `ThreadedCommentsSection` (including 36dp-indented child replies and reaction chips) SHALL render with zero `RenderFlex` overflow at `360x780` mobile portrait and `1280x800` desktop viewports. |
| **`REQ-P69-NFR-03`** | **`workerd` V8 Isolate Compatibility** | All new database methods in `vhunambi_db.ts` SHALL have 1:1 equivalents in `EdgeIsolateDatabaseEngine` (`edge_persistence_bridge.ts`) with non-blocking `mirrorWriteThrough` to `SupabaseCloudDriver`. |
| **`REQ-P69-NFR-04`** | **Async Lifecycle & Test Safety** | All Riverpod notifiers (`SocialFeedPostsNotifier`, `ReelsCommentsNotifier`) SHALL guard post-`await` state mutations with `if (!mounted) return;` and execute headless tests in `< 60s` without infinite animations. |

---

## 5. Granular Requirement-to-Test Traceability Matrix

| Requirement ID | Primary Target Class / File | Verification Test Suite & Case |
| :--- | :--- | :--- |
| `REQ-P69-ID-01`, `REQ-P69-ID-02` | `RepostKineticPostSheet`, `KineticPostComposerBar` | `phase69_kinetic_post_focus_and_threading_test.dart` $\to$ `'RepostKineticPostSheet uses ownerProfileProvider identity instead of @current_user'` |
| `REQ-P69-CARD-01` .. `REQ-P69-CARD-05` | `ExploreSocialPostCard`, `KineticPostSonicPill` | `phase69_kinetic_post_focus_and_threading_test.dart` $\to$ `'ExploreSocialPostCard renders Engagement Summary Strip, Phosphor Co-Sign pill without raw emoji, and dual-theme tokens'` |
| `REQ-P69-FOCUS-01` .. `REQ-P69-FOCUS-05` | `KineticPostFocusView`, `NotificationDeepLinkRouter` | `phase69_kinetic_post_focus_and_threading_test.dart` $\to$ `'Tapping caption, media, or comment button opens KineticPostFocusView and /post/:id deep-links route cleanly'` |
| `REQ-P69-THREAD-01` .. `REQ-P69-THREAD-06` | `ReelComment`, `ReelsCommentsNotifier`, `ThreadedCommentsSection` | `phase69_kinetic_post_focus_and_threading_test.dart` $\to$ `'Tapping Reply activates banner, submits nested child reply, expands thread, toggles Most Relevant/Newest sort, and increments post commentCount'` |
| `REQ-P69-STD-01`, `REQ-P69-STD-02` | `StudioReactionComposerBar`, `ReelsCommentSheet`, `ExploreView` | `reels_comment_sheet_test.dart` & `phase69_kinetic_post_focus_and_threading_test.dart` $\to$ `'Studio reaction chips insert text and zero raw emojis or stock Material Icons exist'` |
| `REQ-P69-API-01`, `REQ-P69-API-02`, `REQ-P69-DB-01`, `REQ-P69-DB-02` | `explore_routes.ts`, `vhunambi_db.ts`, `edge_persistence_bridge.ts` | `apps/vhunambi_api/test/phase69_kinetic_posts_and_threading.test.ts` $\to$ `'persists kinetic post likes, reposts, and nested comment replies across SQLite and simulated Edge Isolate modes'` |
