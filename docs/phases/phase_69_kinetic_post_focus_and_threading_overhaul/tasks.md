# Phase 69 — Kinetic Post Focus Domain, Threaded Replies & Feed Card Refinement Execution Tasks

> **Document ID:** `VHUNAMBI-SPEC-P69-TASKS-V1`  
> **Execution Standard:** Vhunambi Two-Pass Stage 4 Engine (`/vhunambi-executioner`)  
> **Pass Structure:** **Overhaul Pass 1 (`M69.1` – `M69.2`)** $\to$ **Overhaul Pass 2 (`M69.3` – `M69.4`)**

---

## 1. Master Milestone Roadmap & Dependency Graph

```
+------------------------------------------------------------------------------------------------------+
| OVERHAUL PASS 1: FEED CARD REFINEMENT, THREADED COMMENTS & FULL-SCREEN KINETIC POST FOCUS VIEW       |
|                                                                                                      |
|  [M69.1] Repost & Composer Identity Fix (`ownerProfileProvider`), ReelComment & ReelsCommentsNotifier|
|          Threading Extensions, ExploreSocialPostCard Declutter, Engagement Summary Strip & Icon Purge|
|     |                                                                                                |
|     v                                                                                                |
|  [M69.2] ThreadedCommentsSection + StudioReactionComposerBar, Full-Screen KineticPostFocusView       |
|          (`< Post`), 1-Tap Card/Caption/Media Navigation & `/post/:id` NotificationDeepLinkRouter    |
+------------------------------------------------------------------------------------------------------+
                                                   |
                                                   v
+------------------------------------------------------------------------------------------------------+
| OVERHAUL PASS 2: REELS COMMENT SHEET UNIFICATION, BACKEND POSTS/COMMENTS API & SCHEMA MIGRATION      |
|                                                                                                      |
|  [M69.3] Unify ReelsCommentSheet (`reels_comment_sheet.dart`) onto ThreadedCommentsSection +         |
|          StudioReactionComposerBar and Realign Legacy Comment Sheet Tests                            |
|     |                                                                                                |
|     v                                                                                                |
|  [M69.4] Supabase/SQLite/Edge Migration (`like_count`, `parent_comment_id`, `reply_to_handle`),      |
|          `/api/v1/explore/posts*` REST Routes, `applyMutationsBatch` Fix & Full Test Gate            |
+------------------------------------------------------------------------------------------------------+
```

| Milestone | Pass | Deliverable Summary | Verification Scope |
| :--- | :--- | :--- | :--- |
| **`M69.1`** | Pass 1 | Fix `RepostKineticPostSheet` & `KineticPostComposerBar` identity; extend `ReelComment`, `ReelsCommentsNotifier`, `SocialFeedPostsNotifier.incrementCommentCount`, and `HttpExploreRepository` post/comment client methods + seeded `post_001`–`post_005` threads; refine `ExploreSocialPostCard` (`Key('social_post_card_tap_${post.id}')`, Engagement Summary Strip, `VhunambiTrackArtwork`, `*Of(context)` tokens) and `STD-UIUX-001` icon/emoji cleanups across `ExploreView` & `ExploreDiscoveryDrawerSheet`. | Analyzer + unit/widget tests for repost identity, threaded state, Engagement Summary Strip, and zero raw emojis. |
| **`M69.2`** | Pass 1 | Build `ThreadedCommentsSection` & `StudioReactionComposerBar` (`threaded_comments_section.dart`); build `KineticPostFocusView` (`< Post`, including `Key('kpost_focus_image_counter_${post.id}')`) with sticky bottom composer; wire 1-tap open from `ExploreSocialPostCard` card/caption/media/strip/comment button; wire `/post/:id` in `NotificationDeepLinkRouter`. | Widget navigation & threading tests for `KineticPostFocusView`, `Reply` banner, child replies, `Most relevant`/`Newest` sort, and `/post/:id` routing. |
| **`M69.3`** | Pass 2 | Refactor `ReelsCommentSheet` (`reels_comment_sheet.dart`) to consume `ThreadedCommentsSection` & `StudioReactionComposerBar`, purging all raw Unicode emojis and stock Material `Icons.*`, and update `reels_comment_sheet_test.dart`. | `flutter analyze` + `reels_comment_sheet_test.dart` (`--timeout=60s`). |
| **`M69.4`** | Pass 2 | Add `20261118000001_phase69_kinetic_posts_and_threaded_comments.sql`, `explore_routes.ts` & `social_routes.ts`/`social_service.ts` post/comment endpoints, and `applyMutationsBatch` fixes in `vhunambi_db.ts` & `edge_persistence_bridge.ts`; run full backend + client verification suites. | `npx tsc --noEmit`, `npm test` (`phase69_kinetic_posts_and_threading.test.ts`), and full Flutter test gate (`phase69_kinetic_post_focus_and_threading_test.dart`). |

---

## 2. Overhaul Pass 1 (`M69.1` – `M69.2`)

### Milestone `M69.1`: Repost Identity, Threaded Comment State & `ExploreSocialPostCard` Visual Polish

- [x] **Task `69.1.1` — Unify Repost & Composer Identity Resolution with `ownerProfileProvider`**
  - **Target Files:**
    - `apps/vhunambi_client/lib/features/explore/presentation/widgets/repost_kinetic_post_sheet.dart`
    - `apps/vhunambi_client/lib/features/explore/presentation/widgets/kinetic_post_composer_bar.dart`
  - **Signatures:** Update `_submitRepost()` in `RepostKineticPostSheet` and convert `KineticPostComposerBar` to `ConsumerWidget` per `design.md` §4.1–§4.2.
  - **Acceptance Criteria:** Submitting a repost uses `ownerProfileProvider` / `authSessionProvider` (`creatorId`, `creatorName`, `creatorHandle`, `creatorAvatarUrl`, `isCreatorVerified`) and never produces `'current_user'`, `'You'`, or `'@current_user'`. `KineticPostComposerBar` renders `SafeNetworkAvatar(key: Key('kpost_composer_owner_avatar'))`.

- [x] **Task `69.1.2` — Upgrade `ReelComment`, `ReelsCommentsNotifier`, `SocialFeedPostsNotifier.incrementCommentCount` & Client Repository Post/Comment Methods**
  - **Target Files:**
    - `apps/vhunambi_client/lib/features/social/domain/models/reel_comment.dart`
    - `apps/vhunambi_client/lib/features/social/presentation/providers/reels_comments_provider.dart`
    - `apps/vhunambi_client/lib/features/explore/presentation/providers/explore_providers.dart`
    - `apps/vhunambi_client/lib/features/explore/domain/models/social_music_post.dart`
    - `apps/vhunambi_client/lib/features/explore/data/repositories/http_explore_repository.dart`
    - `apps/vhunambi_client/lib/features/social/domain/repositories/i_social_repository.dart`
    - `apps/vhunambi_client/lib/features/social/data/repositories/http_social_repository.dart`
  - **Signatures:** Add `enum CommentSortOrder`, `class ActiveReplyTarget`, `class CommentThreadNode`, and `parentCommentId` / `replyToHandle` / `isReply` on `ReelComment` (`design.md` §2.1); upgrade `ReelsCommentsNotifier` (`design.md` §2.2); add `incrementCommentCount` to `SocialFeedPostsNotifier` (`design.md` §7.1); add `fetchPostById`, `publishPost`, `togglePostLike`, `fetchPostComments`, and `addPostComment` to `HttpExploreRepository` (`design.md` §7.2).
  - **Acceptance Criteria:**
    - `ReelComment` supports backward-compatible `toJson()` / `fromJson()` for both camelCase and snake_case keys.
    - `ReelsCommentsNotifier` exposes `threadsForClip`, `setSortOrder`, `setActiveReplyTarget`, `clearActiveReplyTarget`, `toggleThreadExpanded`, `syncCommentsForClip(..., isKineticPost: ...)`, and `addComment` (auto-setting `isCreator`, auto-expanding parent thread on reply, calling `socialFeedPostsProvider.notifier.incrementCommentCount(clipId)` for Kinetic Posts, and emitting `/post/$clipId` notifications).
    - Seeds multi-turn threads (including nested replies and creator `Author` replies) for `post_001`–`post_005` and aligns `seedSocialPosts()` `commentCount` values.

- [x] **Task `69.1.3` — Refine `ExploreSocialPostCard` & `KineticPostSonicPill` and Purge Stock Material `Icons.*` / Emojis in `ExploreView` & `ExploreDiscoveryDrawerSheet`**
  - **Target Files:**
    - `apps/vhunambi_client/lib/features/explore/presentation/widgets/explore_social_post_card.dart`
    - `apps/vhunambi_client/lib/features/explore/presentation/widgets/kinetic_post_sonic_pill.dart`
    - `apps/vhunambi_client/lib/features/explore/presentation/views/explore_view.dart`
    - `apps/vhunambi_client/lib/features/explore/presentation/widgets/explore_discovery_drawer_sheet.dart`
  - **Signatures:** Add outer card tap wrapper `Key('social_post_card_tap_${post.id}')` and `_buildEngagementSummaryStrip` (`Key('social_post_engagement_strip_${post.id}')`), integrate `_buildProvenanceBadge` into the creator header subtitle row, normalize image URLs via `AppConstants.normalizeCloudMediaUrl` with `VhunambiTrackArtwork` error fallback, remove raw `'🔥'` from `_buildCosignButton`, and replace static `AppColors.*` with `*Of(context)` per `design.md` §4.3.
  - **Acceptance Criteria:**
    - Preserves all existing keys (`social_post_card_${post.id}`, `social_post_creator_${post.id}`, `social_post_own_badge_${post.id}`, `social_post_follow_${post.id}`, `post_provenance_badge_${post.id}`, `post_remix_tree_btn_${post.id}`, `post_cosign_btn_${post.id}`, `kinetic_post_sonic_pill_${post.id}`, `social_post_play_btn_${post.id}`, `social_post_like_btn_${post.id}`, `social_post_comment_btn_${post.id}`, `social_post_repost_btn_${post.id}`, `social_post_remix_btn_${post.id}`, `social_post_tip_btn_${post.id}`, `social_post_share_btn_${post.id}`).
    - Replaces all `Icons.*` in `explore_view.dart` and `explore_discovery_drawer_sheet.dart` with `PhosphorIcon(AppIcons.* / PhosphorIconsRegular.*)` and removes `' 🚀'` from `'Fastest Growing Tracks'`.

---

### Milestone `M69.2`: `ThreadedCommentsSection`, Full-Screen `KineticPostFocusView` & Universal Post Navigation

- [x] **Task `69.2.1` — Create `ThreadedCommentsSection` & `StudioReactionComposerBar`**
  - **Target File:** `apps/vhunambi_client/lib/features/social/presentation/widgets/threaded_comments_section.dart`
  - **Signatures:** Implement `StudioReactionChipSpec`, `kStudioReactionChips`, `kStudioPraisePhrases`, `ThreadedCommentsSection`, `_HonestSupporterBanner`, `_ThreadedCommentTile`, and `StudioReactionComposerBar` per `design.md` §6.1.
  - **Acceptance Criteria:**
    - Interactive `Key('comment_reply_btn_${comment.id}')` (`>=44x36dp` hit target) activates `Key('comment_active_reply_banner')` (`'Replying to @handle'`) with cancel button `Key('comment_cancel_reply_btn')` and focuses `Key('comment_input')`.
    - Renders `Key('threaded_comments_header_$clipOrPostId')`, `Key('comment_sort_toggle_btn')` (`Most relevant` / `Newest`), `Key('comment_toggle_replies_${parent.id}')` (`'View N reply/replies'` / `'Hide replies'`), 36dp-indented child replies with vertical thread line, `Key('comment_author_badge_${comment.id}')`, and `Key('comment_reaction_chip_fire')` .. `Key('comment_reaction_chip_sa_vibe')`.

- [x] **Task `69.2.2` — Create Full-Screen `KineticPostFocusView` (`< Post`) & Wire 1-Tap Card/Caption/Media/Comment Navigation + `/post/:id` Deep-Link Router**
  - **Target Files:**
    - `apps/vhunambi_client/lib/features/explore/presentation/views/kinetic_post_focus_view.dart`
    - `apps/vhunambi_client/lib/features/explore/presentation/widgets/explore_social_post_card.dart`
    - `apps/vhunambi_client/lib/features/notifications/presentation/utils/notification_deep_link_router.dart`
  - **Signatures:** `class KineticPostFocusView extends ConsumerStatefulWidget` with static `KineticPostFocusView.show(BuildContext context, {required String postId, SocialMusicPost? initialPost, bool autofocusComposer = false, VoidCallback? onRemixSuccess})` per `design.md` §5.1–§5.2.
  - **Acceptance Criteria:**
    - Renders `< Post` back button (`Key('kpost_focus_back_btn')`), `@handle's Post` title, Tip (`Key('kpost_focus_tip_btn')`) and Share (`Key('kpost_focus_share_btn')`) actions, scrollable post header + caption + media (with `Key('kpost_focus_image_counter_${post.id}')` `'${_currentImageIndex + 1}/${images.length}'` badge when `images.length > 1`) + `KineticPostSonicPill` + Remix/Co-Sign strip + Engagement Summary + 4-button action bar + `ThreadedCommentsSection`, and sticky bottom `StudioReactionComposerBar` docked above `MediaQuery.viewInsetsOf(context).bottom`.
    - Tapping `Key('social_post_card_tap_${post.id}')`, `Key('social_post_caption_tap_${post.id}')`, `Key('social_post_media_tap_${post.id}')`, or `Key('social_post_engagement_strip_${post.id}')` opens `KineticPostFocusView(autofocusComposer: false)`.
    - Tapping `Key('social_post_comment_btn_${post.id}')` opens `KineticPostFocusView(autofocusComposer: true)`.
    - Tapping `Key('social_post_play_btn_${post.id}')` inside `KineticPostSonicPill` toggles audio inline without pushing `KineticPostFocusView`.
    - `NotificationDeepLinkRouter.navigateDirect` routes `/post/<id>` into `KineticPostFocusView`.
    - End of Pass 1 compiles cleanly under `flutter analyze` with zero unresolved imports or `unused_field` warnings.

---

## 3. Overhaul Pass 2 (`M69.3` – `M69.4`)

### Milestone `M69.3`: `ReelsCommentSheet` Threading & `STD-UIUX-001` Unification

- [x] **Task `69.3.1` — Refactor `ReelsCommentSheet` onto `ThreadedCommentsSection` & `StudioReactionComposerBar` and Update `reels_comment_sheet_test.dart`**
  - **Target Files:**
    - `apps/vhunambi_client/lib/features/social/presentation/widgets/reels_comment_sheet.dart`
    - `apps/vhunambi_client/test/features/social/reels_comment_sheet_test.dart`
  - **Acceptance Criteria:**
    - Replaces the legacy flat comment list and raw Unicode emoji strip (`🔥`, `👑`, `🇿🇦`, `🎹`, `🐐`, `❤️`, `🌅`) + stock Material `Icons.*` in `ReelsCommentSheet` with `ThreadedCommentsSection` and `StudioReactionComposerBar`.
    - Preserves `Key('comment_input')`, `Key('comment_send_btn')`, and `ValueKey('comment_like_${comment.id}')`, and updates `reels_comment_sheet_test.dart` to verify the Phosphor studio reaction chips and nested reply interactions.

---

### Milestone `M69.4`: Backend `/api/v1/explore/posts*` API, Schema Migration, Sync Fix & Verification Suite

- [x] **Task `69.4.1` — Create Phase 69 Supabase Migration & Upgrade SQLite / Edge Isolate Schemas**
  - **Target Files:**
    - `supabase/migrations/20261118000001_phase69_kinetic_posts_and_threaded_comments.sql`
    - `apps/vhunambi_api/src/db/vhunambi_db.ts`
    - `apps/vhunambi_api/src/db/edge_persistence_bridge.ts`
  - **Acceptance Criteria:** Adds `like_count` and `comment_count` to `kinetic_posts` and `parent_comment_id` and `reply_to_handle` to `reel_comments` across PostgreSQL, SQLite, and `EdgeIsolateDatabaseEngine`; implements `getKineticPostById`, `upsertKineticPost`, `likeKineticPost`, `getKineticPostComments`, `addKineticPostComment`, and `likeCommentById`; repairs `applyMutationsBatch` so `post.like` increments `like_count` (never `cosign_count`), `post.repost` increments `repost_count` + upserts repost, and `payload.postId` is resolved.

- [x] **Task `69.4.2` — Expose `/api/v1/explore/posts*` Routes & Update `social_routes.ts` / `social_service.ts`**
  - **Target Files:**
    - `apps/vhunambi_api/src/routes/explore_routes.ts`
    - `apps/vhunambi_api/src/routes/social_routes.ts`
    - `apps/vhunambi_api/src/modules/social/social_service.ts`
    - `apps/vhunambi_api/src/modules/social/social_types.ts`
  - **Acceptance Criteria:** Mounts `GET /posts/:id`, `POST /posts`, `POST /posts/:id/like`, `GET /posts/:id/comments`, `POST /posts/:id/comments`, and `POST /comments/:id/like` in `explore_routes.ts`; updates `social_service.ts` `addComment`/`getComments` to accept `parentCommentId`/`replyToHandle` and fall back to `kinetic_posts` when `clipId` is a Kinetic Post ID.

- [x] **Task `69.4.3` — Author Backend & Client Phase 69 Verification Suites**
  - **Target Files:**
    - `apps/vhunambi_api/test/phase69_kinetic_posts_and_threading.test.ts`
    - `apps/vhunambi_client/test/features/explore/phase69_kinetic_post_focus_and_threading_test.dart`
  - **Acceptance Criteria:**
    - Backend test suite verifies `POST /api/v1/explore/posts`, `/like`, `/repost`, `GET/POST /comments` (top-level + nested reply + sort), `/comments/:id/like`, and `POST /api/v1/sync/mutations` (`post.like`, `post.repost`, `comment.create`) in both SQLite and simulated Edge Isolate modes.
    - Client test suite verifies `ExploreSocialPostCard` Engagement Summary Strip, 1-tap navigation (`social_post_card_tap_*`, `social_post_caption_tap_*`, `social_post_media_tap_*`, `social_post_comment_btn_*`) into `KineticPostFocusView`, multi-image counter `kpost_focus_image_counter_*`, inline sonic pill playback isolation, `RepostKineticPostSheet` owner identity, interactive `Reply` banner + nested child reply creation + `View N replies` + `Most relevant`/`Newest` sorting, `/post/:id` notification deep-linking, and zero raw emojis / stock Material `Icons.*`.

---

## 4. Stage 4 Anti-Trap Execution Checklist & Verification Gates

```
+---------------------------------------------------------------------------------------------------+
| STAGE 4 EXECUTIONER ANTI-TRAP CHECKLIST                                                           |
+---------------------------------------------------------------------------------------------------+
| [x] 1. Zero Raw Unicode Emojis (`STD-UIUX-001`) in ExploreSocialPostCard, KineticPostFocusView,   |
|        ThreadedCommentsSection, StudioReactionComposerBar, ReelsCommentSheet, or ExploreView.     |
| [x] 2. Zero Stock Material `Icons.*` in modified Explore & Social widgets.                        |
| [x] 3. 100% `*Of(context)` Dynamic Theme Tokens across all cards, sheets, and focus views.        |
| [x] 4. All existing widget Keys on ExploreSocialPostCard, KineticPostSonicPill,                   |
|        RepostKineticPostSheet, KineticPostComposerBar, and ReelsCommentSheet preserved.           |
| [x] 5. `applyMutationsBatch` in BOTH `vhunambi_db.ts` and `edge_persistence_bridge.ts` resolves   |
|        `payload.postId` and maps `post.like` -> `like_count` (never `cosign_count`).              |
| [x] 6. All widget tests run with `--timeout=60s` and bounded `pump()` steps.                      |
+---------------------------------------------------------------------------------------------------+
```

```powershell
# 1. Backend TypeScript & Vitest Gate
cd apps/vhunambi_api
npx tsc --noEmit
npm test

# 2. Client Static Analyzer Gate
cd ../vhunambi_client
flutter analyze lib/features/explore lib/features/social lib/features/notifications

# 3. Client Bounded Unit & Widget Test Gate
flutter test test/features/explore/ test/features/social/reels_comment_sheet_test.dart --timeout=60s
```
