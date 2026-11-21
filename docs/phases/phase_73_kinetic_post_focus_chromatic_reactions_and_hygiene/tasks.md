# VHUNAMBI PHASE 73 EXECUTION TASKS — TWO-PASS DETERMINISTIC MILESTONE PLAN

**Document ID:** `VHUNAMBI-SPEC-P73-TASKS-V1`  
**Phase:** Phase 73 (`phase_73_kinetic_post_focus_chromatic_reactions_and_hygiene`)  
**Paired Design Reference:** [`design.md`](./design.md) (`VHUNAMBI-SPEC-P73-DESIGN-V1`)

---

## 1. Master Two-Pass Roadmap & Dependency Graph

```text
╔═══════════════════════════════════════════════════════════════════════════════════╗
║ PASS 1: CLOUD SPINE + THEME PURGE + CHROMATIC ENGINE + SOCIAL HYGIENE            ║
║  ┌───────────────────────────────────┐    ┌───────────────────────────────────┐  ║
║  │ M73.1: Backend Multi-Reactions,   │    │ M73.2: Global Input Border Purge, │  ║
║  │ Comment Media & GIF Search Proxy  │───►│ 3-Tier Chromatic Engine & Social  │  ║
║  │ (SQL + TS + 29/29 tsx Suites)     │    │ Hygiene (SOC-02/03/07/08/09/10)   │  ║
║  └───────────────────────────────────┘    └───────────────────────────────────┘  ║
║    GATE P1: tsc --noEmit (0) | npm test (29/29) | flutter analyze --no-pub (0)   ║
╠═══════════════════════════════════════════════════════════════════════════════════╣
║ PASS 2: FOCUS V2 + TACTILE REACTIONS + GIF/STICKER COMPOSER + VERIFICATION       ║
║  ┌───────────────────────────────────┐    ┌───────────────────────────────────┐  ║
║  │ M73.3: KineticReaction Models,    │    │ M73.4: GifStickerPickerSheet,     │  ║
║  │ ReactionTrayOverlay, Focus Bar v2 │───►│ Sovereign Stickers, Comment Media │  ║
║  │ & Optimistic Multi-Reaction Wire  │    │ & Full Verification + Memory Sleep│  ║
║  └───────────────────────────────────┘    └───────────────────────────────────┘  ║
║    GATE P2: flutter analyze (0) | All P73 + P69 + MiniPlayer + Storage Tests     ║
╚═══════════════════════════════════════════════════════════════════════════════════╝
```

| Milestone | Pass | Primary Deliverables | Independent Compile Gate |
| :--- | :---: | :--- | :--- |
| **`M73.1`** | Pass 1 | Supabase migration, SQLite/Edge Bridge 1:1 reaction & media methods, `explore_routes.ts` & `social_routes.ts` endpoints, `phase73_reactions_gifs_and_comment_media.test.ts` (`29/29`) | `.\node_modules\.bin\tsc.cmd --noEmit` + `npm test` |
| **`M73.2`** | Pass 1 | `app_theme.dart` + 11 focus border sites, `post_chromatic_palette_resolver.dart`, `profile_navigation_helper.dart`, `@current_user` purge, `splash_view.dart` + `main.dart`, `create_kinetic_post_sheet.dart`, `explore_providers.dart` + `explore_search_view.dart` | `flutter analyze --no-pub` (0 issues) |
| **`M73.3`** | Pass 2 | `kinetic_reaction.dart`, `reaction_tray_overlay.dart`, `SocialMusicPost` & `ReelComment` multi-reaction/media fields, `HttpExploreRepository` & `ISocialRepository`/`HttpSocialRepository`, `SocialFeedPostsNotifier` & `ReelsCommentsNotifier`, `KineticPostFocusView` v2 & `ExploreSocialPostCard` | `flutter analyze --no-pub` (0 issues) |
| **`M73.4`** | Pass 2 | `sovereign_sticker_pack.dart`, `gif_sticker_picker_sheet.dart`, `threaded_comments_section.dart` media composer & rendering, `phase73_kinetic_post_chromatic_reactions_test.dart`, regression verification, `memory.md` SLEEP consolidation | Full test gates + `consolidate_memory.mjs` |

---

## 2. Pass 1 — Milestone `M73.1`: Backend Multi-Reactions, Comment Media & GIF Search Proxy

### Task 1.1 — Supabase Migration & Worker Env Bindings
- **Target Files:**
  - `supabase/migrations/20261121000001_phase73_reactions_and_comment_media.sql` (CREATE)
  - `apps/vhunambi_api/src/types/cloudflare_worker_types.ts` (EDIT)
- **Actions:**
  1. Create idempotent SQL migration adding `reaction_counts_json` (`public.kinetic_posts`, `public.reel_comments`), `reaction_type` (`public.social_interactions`), and `gif_url`, `sticker_id`, `media_aspect_ratio` (`public.reel_comments`).
  2. Add optional `TENOR_API_KEY?: string;` and `GIPHY_API_KEY?: string;` to `VhunambiWorkerEnv`.
- **Acceptance:** Migration uses `ADD COLUMN IF NOT EXISTS`; `tsc.cmd --noEmit` passes.

### Task 1.2 — SQLite (`vhunambi_db.ts`) & Edge SWR (`edge_persistence_bridge.ts`) 1:1 Reaction/Media Engine
- **Target Files:**
  - `apps/vhunambi_api/src/db/vhunambi_db.ts` (EDIT)
  - `apps/vhunambi_api/src/db/edge_persistence_bridge.ts` (EDIT)
- **Actions:**
  1. Add idempotent `ALTER TABLE` schema upgrades in `vhunambi_db.ts` (`kinetic_posts.reaction_counts_json`, `reel_comments.reaction_counts_json/gif_url/sticker_id/media_aspect_ratio`, `social_interactions.reaction_type`).
  2. Implement `KineticReactionWire` (`'like' | 'love' | 'haha' | 'fire' | 'wow' | 'angry'`) and `reactToKineticPost`, `reactToKineticPostAsync`, `reactToComment`, `reactToCommentAsync` on `EdgeIsolateDatabaseEngine` AND identical 1:1 methods/proxies on `VhunambiDatabase`.
  3. Add `private socialInteractionReactions = new Map<string, KineticReactionWire>()` on `EdgeIsolateDatabaseEngine`, hydrate it in `hydrateSocialInteractionRows` & `syncExploreFromCloud` (fetching `social_interactions`), and return `reactionCounts` + `myReaction` in `getExploreFeed`, `getKineticPostById`, `getKineticPostComments`, and `mapReelCommentRow`.
  4. Extend `addKineticPostComment` / `insertReelComment` / `mapReelCommentRow` / `hydrateReelCommentRows` to store and return `gifUrl`, `stickerId`, `mediaAspectRatio`, `reactionCounts`, and `myReaction`.
- **Acceptance:** Zero TypeScript proxy mismatches (`tsc.cmd --noEmit` exits `0`).

### Task 1.3 — Worker REST Routes (`explore_routes.ts`, `social_routes.ts`) & GIF Proxy
- **Target Files:**
  - `apps/vhunambi_api/src/routes/explore_routes.ts` (EDIT)
  - `apps/vhunambi_api/src/routes/social_routes.ts` (EDIT)
- **Actions:**
  1. Add `POST /api/explore/posts/:id/react` and `POST /api/explore/comments/:id/react` calling `await vhunambiDb.reactToKineticPostAsync(...)` and `await vhunambiDb.reactToCommentAsync(...)`.
  2. Update `POST /api/explore/posts/:id/comments` to accept optional `gifUrl`, `stickerId`, `mediaAspectRatio` and allow empty `text` when `gifUrl` or `stickerId` is present; pass `viewerId` to `GET /api/explore/posts/:id` and `GET /api/explore/feed` so `myReaction` hydrates accurately.
  3. Add `POST /api/social/comments/:id/react`, `GET /api/social/gifs/search`, and `GET /api/social/gifs/trending` on `social_routes.ts`; relax `CreateCommentSchema` to `.refine((d) => Boolean(d.text.trim() || d.gifUrl?.trim() || d.stickerId?.trim()))`.
- **Acceptance:** Never leaks `TENOR_API_KEY` or `GIPHY_API_KEY`; returns HTTP `200` with `source: 'curated'` when keys are absent.

### Task 1.4 — Backend Verification Suite (`29/29`)
- **Target Files:**
  - `apps/vhunambi_api/test/phase73_reactions_gifs_and_comment_media.test.ts` (CREATE)
  - `apps/vhunambi_api/package.json` (EDIT — append suite to `"test"` script)
- **Actions:** Write standalone `tsx` test covering post/comment react toggle & switch, Supabase SWR rehydration across fresh `EdgeIsolateDatabaseEngine`, media-only comment persistence, and `/api/social/gifs/search` + `/trending`.
- **Acceptance:** `.\node_modules\.bin\tsc.cmd --noEmit` exits `0` AND `npm test` passes `29/29` suites.

---

## 3. Pass 1 — Milestone `M73.2`: Global Input Focus Purge, 3-Tier Chromatic Engine & Social Hygiene

### Task 2.1 — Global Focus Border Purge (`SOC-02`)
- **Target Files:**
  - `apps/vhunambi_client/lib/core/theme/app_theme.dart` (EDIT)
  - `apps/vhunambi_client/lib/features/social/presentation/widgets/threaded_comments_section.dart` (EDIT)
  - `apps/vhunambi_client/lib/features/explore/presentation/views/explore_search_view.dart` (EDIT)
  - `apps/vhunambi_client/lib/features/explore/presentation/widgets/create_kinetic_post_sheet.dart` (EDIT)
  - `apps/vhunambi_client/lib/features/explore/presentation/widgets/repost_kinetic_post_sheet.dart` (EDIT)
  - `apps/vhunambi_client/lib/features/studio/presentation/widgets/direct_daw_vocal_upload_sheet.dart` (EDIT)
  - `apps/vhunambi_client/lib/features/studio/presentation/widgets/prompt_input_box.dart` (EDIT)
  - `apps/vhunambi_client/lib/features/auth/presentation/widgets/sovereign_auth_sheet.dart` (EDIT)
  - `apps/vhunambi_client/lib/features/playlists/presentation/views/playlists_vault_view.dart` (EDIT)
  - `apps/vhunambi_client/lib/features/playlists/presentation/widgets/add_to_playlist_sheet.dart` (EDIT)
  - `apps/vhunambi_client/lib/features/profile/presentation/widgets/avatar_customization_modal.dart` (EDIT)
  - `apps/vhunambi_client/lib/features/content_studio/presentation/widgets/publish_clip_modal.dart` (EDIT)
- **Actions:** Implement subtle `1.0px` tonal `focusedBorder` in `AppTheme.darkTheme` & `lightTheme`, add explicit `focusedBorder: InputBorder.none` & `enabledBorder: InputBorder.none` on all 3 leak sites, and replace orange `focusedBorder` overrides across all 8 modal/sheet sites.
- **Acceptance:** Zero `AppColors.brandPrimary` references inside any `focusedBorder` across `apps/vhunambi_client/lib/`.

### Task 2.2 — 3-Tier Chromatic Synthesis Engine (`SOC-03`)
- **Target File:** `apps/vhunambi_client/lib/core/theme/post_chromatic_palette_resolver.dart` (CREATE)
- **Actions:** Implement `PostChromaticPalette`, `ChromaticSynthesisTier`, and `PostChromaticPaletteResolver` (`resolveSync` + `resolveAsync` using `VhunambiMood.tryNormalize`, `PaletteGenerator.fromImageProvider` with `150ms` timeout, LRU cache, `FLUTTER_TEST` deterministic bypass, and WCAG AA lightness normalizer).
- **Acceptance:** Compiles cleanly with zero `pubspec.yaml` changes; deterministic in headless Dart/Flutter tests.

### Task 2.3 — Social Identity Routing (`SOC-07`), Splash MiniPlayer Fix (`SOC-08`), Post Composer (`SOC-09`) & Real Hive Search (`SOC-10`)
- **Target Files:**
  - `apps/vhunambi_client/lib/core/navigation/profile_navigation_helper.dart` (CREATE)
  - `apps/vhunambi_client/lib/features/explore/presentation/widgets/explore_social_post_card.dart` (EDIT)
  - `apps/vhunambi_client/lib/features/explore/presentation/views/kinetic_post_focus_view.dart` (EDIT — routing hook)
  - `apps/vhunambi_client/lib/features/social/presentation/widgets/kinetic_reels_modal.dart` (EDIT — routing hook)
  - `apps/vhunambi_client/lib/features/track/presentation/views/track_detail_view.dart` (EDIT — routing hook)
  - `apps/vhunambi_client/lib/features/explore/presentation/views/explore_search_view.dart` (EDIT — routing + dynamic `"You May Like"`)
  - `apps/vhunambi_client/lib/features/explore/presentation/widgets/explore_discovery_drawer_sheet.dart` (EDIT — routing hook)
  - `apps/vhunambi_client/lib/features/notifications/presentation/utils/notification_deep_link_router.dart` (EDIT — routing hook)
  - `apps/vhunambi_client/lib/features/studio/presentation/widgets/direct_daw_vocal_upload_sheet.dart` (EDIT — purge `@current_user`)
  - `apps/vhunambi_client/lib/features/onboarding/presentation/views/splash_view.dart` (EDIT)
  - `apps/vhunambi_client/lib/main.dart` (EDIT — clear `isSplashActiveProvider` post-frame in `RootShell.initState`)
  - `apps/vhunambi_client/lib/features/explore/presentation/widgets/create_kinetic_post_sheet.dart` (EDIT)
  - `apps/vhunambi_client/lib/features/explore/presentation/providers/explore_providers.dart` (EDIT — empty initial recent searches)
- **Actions:** Implement all 4 hygiene fixes exactly per `design.md` §3.3–§3.6.
- **Acceptance (Pass 1 Exit Gate):** `flutter analyze --no-pub` reports `0 issues`!

---

## 4. Pass 2 — Milestone `M73.3`: KineticReaction Models, ReactionTrayOverlay, Focus Bar v2 & Multi-Reaction Wire

### Task 3.1 — Zero-Raw-Emoji Multi-Reaction Domain & Vector Badge Renderer (`SOC-04`)
- **Target Files:**
  - `apps/vhunambi_client/lib/features/social/domain/models/kinetic_reaction.dart` (CREATE)
  - `apps/vhunambi_client/lib/features/social/presentation/widgets/reaction_tray_overlay.dart` (CREATE)
- **Actions:** Implement `KineticReactionType`, `KineticReactionBadge` (glossy `CustomPainter` + `PhosphorIconsFill`, zero raw Unicode emojis), `ReactionClusterStack`, and `ReactionTrayOverlay` (frosted glass floating pill, drag-to-scrub `1.4x` hover magnification, `HapticFeedback.selectionClick()`).
- **Acceptance:** Zero raw Unicode emojis; all 6 orbs render cleanly in Light & Dark themes.

### Task 3.2 — Model, Repository & Riverpod Multi-Reaction + Comment Media Wiring
- **Target Files:**
  - `apps/vhunambi_client/lib/features/explore/domain/models/social_music_post.dart` (EDIT)
  - `apps/vhunambi_client/lib/features/social/domain/models/reel_comment.dart` (EDIT)
  - `apps/vhunambi_client/lib/features/explore/data/repositories/http_explore_repository.dart` (EDIT)
  - `apps/vhunambi_client/lib/features/social/domain/repositories/i_social_repository.dart` (EDIT)
  - `apps/vhunambi_client/lib/features/social/data/repositories/http_social_repository.dart` (EDIT)
  - `apps/vhunambi_client/lib/features/explore/presentation/providers/explore_providers.dart` (EDIT)
  - `apps/vhunambi_client/lib/features/social/presentation/providers/reels_comments_provider.dart` (EDIT)
- **Actions:** Add backward-compatible `reactionCounts` & `myReaction` on `SocialMusicPost` and `ReelComment` plus `gifUrl`, `stickerId`, `mediaAspectRatio` on `ReelComment`; add `reactToPost`, `reactToComment`, `searchGifs`, `getTrendingGifs`, and media-capable `addComment` / `addPostComment`.
- **Acceptance:** All existing call sites and `copyWith`/`fromJson`/`toJson` remain backward-compatible.

### Task 3.3 — `KineticPostFocusView` v2 & `ExploreSocialPostCard` Chromatic + Non-Wrapping Action Bar (`SOC-01`, `SOC-03`, `SOC-04`)
- **Target Files:**
  - `apps/vhunambi_client/lib/features/explore/presentation/views/kinetic_post_focus_view.dart` (EDIT)
  - `apps/vhunambi_client/lib/features/explore/presentation/widgets/explore_social_post_card.dart` (EDIT)
- **Actions:** Wrap `KineticPostFocusView` in `VhunambiAmbientMeshBackdrop` driven by `PostChromaticPaletteResolver`; replace summary row with `Wrap` + `ReactionClusterStack`; replace 4-button `TextButton.icon` row with non-wrapping vertical icon-over-label / `FittedBox` controls + long-press `ReactionTrayOverlay`; wire long-press `ReactionTrayOverlay` onto `ExploreSocialPostCard` react button.
- **Acceptance:** Zero mid-word wrapping or overflow at `320dp` & `360dp`; all Phase 69 widget keys preserved.

---

## 5. Pass 2 — Milestone `M73.4`: GIF & Sovereign Sticker Composer, Verification & Memory Sleep

### Task 4.1 — Sovereign Sticker Pack, `GifStickerPickerSheet` & `ThreadedCommentsSection` Media Support (`SOC-04`)
- **Target Files:**
  - `apps/vhunambi_client/lib/features/social/domain/models/sovereign_sticker_pack.dart` (CREATE)
  - `apps/vhunambi_client/lib/features/social/presentation/widgets/gif_sticker_picker_sheet.dart` (CREATE)
  - `apps/vhunambi_client/lib/features/social/presentation/widgets/threaded_comments_section.dart` (EDIT)
- **Actions:** Implement 8 vector studio stickers (`SovereignStickerPack` + `SovereignStickerGraphic`), segmented `GifStickerPickerSheet` (`Stickers` + `GIFs`), pending media preview chip & `[GIF]` button inside `StudioReactionComposerBar` (allowing media-only sends), inline GIF/Sticker rendering + long-press comment reactions inside `_ThreadedCommentTile`.
- **Acceptance:** Media-only comments/replies post and render cleanly; Phase 69 `StudioReactionComposerBar` keys preserved.

### Task 4.2 — Comprehensive Client Test Suite & Regression Alignment
- **Target Files:**
  - `apps/vhunambi_client/test/features/phase73_kinetic_post_chromatic_reactions_test.dart` (CREATE)
  - `apps/vhunambi_client/test/features/explore/phase29_social_explore_test.dart` (EDIT — realign line 115)
- **Actions:**
  1. Author widget & unit tests in `phase73_kinetic_post_chromatic_reactions_test.dart` covering all 8 requirements (`REQ-P73-INPUT`, `REQ-P73-CHROM`, `REQ-P73-SOC`, `REQ-P73-HYG`), including legacy `likeCount` preservation on first reaction (`1,840` likes + `'fire'` -> `1,841`).
  2. Realign `apps/vhunambi_client/test/features/explore/phase29_social_explore_test.dart#L115`: because `RecentSearchesNotifier._initialSearches()` now starts at `const <String>[]` on a clean install (`REQ-P73-HYG-04`), update line 115 from `expect(find.byKey(const Key('explore_recent_clear_all')), findsOneWidget)` on initial mount to assert `findsNothing` on clean install (or seed a recent query before asserting `explore_recent_clear_all`), while verifying `ignored_domains_persistence_test.dart`, `phase69_kinetic_post_focus_and_threading_test.dart`, `reels_comment_sheet_test.dart`, and `mini_player_host_test.dart` pass untouched.
- **Acceptance:** 100% green under `--timeout=60s`; `flutter analyze --no-pub` reports `0 issues`.

### Task 4.3 — Finalize `memory.md` & Run Connectome Sleep (Stage 4 Only)
- **Target File:** `docs/phases/phase_73_kinetic_post_focus_chromatic_reactions_and_hygiene/memory.md` (EDIT in Stage 4 only)
- **Actions:** Only after every verification command below passes with 0 errors, flip `"status": "completed"`, populate `completed_at`, verified breakthroughs/gotchas, and execute `node .agents/skills/vhunambi-memory/scripts/consolidate_memory.mjs`.

---

## 6. Stage 4 Verification Command Checklist

```powershell
# Pass 1 Backend Gate (M73.1)
cd apps/vhunambi_api
.\node_modules\.bin\tsc.cmd --noEmit
npm test

# Pass 1 & Pass 2 Client Static Gate (M73.2 -> M73.4)
cd ../vhunambi_client
flutter analyze --no-pub

# Pass 2 Client Test Gates (Anti-Hang --timeout=60s)
flutter test --no-pub --timeout=60s test/features/phase73_kinetic_post_chromatic_reactions_test.dart
flutter test --no-pub --timeout=60s test/features/explore/phase69_kinetic_post_focus_and_threading_test.dart
flutter test --no-pub --timeout=60s test/features/player/widgets/mini_player_host_test.dart
flutter test --no-pub --timeout=60s test/features/storage/ignored_domains_persistence_test.dart
flutter test --no-pub --timeout=60s test/features/explore/ test/features/social/

# Stage 4 Memory Sleep (ONLY AFTER ALL GATES PASS)
cd ../..
node .agents/skills/vhunambi-memory/scripts/consolidate_memory.mjs
```

### Anti-Trap Execution Checklist (Stage 4 Must Verify)
- [x] Zero raw OS Unicode emojis in any Phase 73 Dart file (`STD-UIUX-001`).
- [x] Zero `AppColors.brandPrimary` references inside any `focusedBorder` declaration.
- [x] 1:1 method parity between `VhunambiDatabase` (`vhunambi_db.ts`) and `EdgeIsolateDatabaseEngine` (`edge_persistence_bridge.ts`).
- [x] `PaletteGenerator` bypassed deterministically in `FLUTTER_TEST` so `FakeAsync` widget tests never hang.
- [x] `VhunambiGlassSurface` keeps `enableLiveBlur: false` on all repeating feed cards and comment tiles.
- [x] All Phase 69 widget keys (`comment_input`, `comment_send_btn`, `comment_reaction_chip_fire`, `threaded_comments_header_*`, etc.) preserved verbatim.
- [x] `isSplashActiveProvider` cleared post-frame in `RootShell.initState` (not before `SplashView`'s 420ms fade).
