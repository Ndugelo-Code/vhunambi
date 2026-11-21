# VHUNAMBI PHASE 73 REQUIREMENTS — KINETIC POST FOCUS V2, CHROMATIC SYNTHESIS, MULTI-REACTIONS, GIFS/STICKERS & SOCIAL HYGIENE

**Document ID:** `VHUNAMBI-SPEC-P73-REQUIREMENTS-V1`  
**Phase:** Phase 73 (`phase_73_kinetic_post_focus_chromatic_reactions_and_hygiene`)  
**Conventions:** EARS (`WHEN`, `WHILE`, `IF...THEN`, `WHERE`) & RFC-2119 (`SHALL`, `MUST`, `SHALL NOT`).  
**Design System Standard:** `STD-UIUX-001` (Zero Raw OS Unicode Emojis in UI code; authentic `AppColors`, `AppTypography`, and `package:phosphor_icons/phosphor_icons.dart`).

---

## 1. Document Scope & Pass Boundary Contract

Phase 73 closes all 8 Part-A hardware defects (`SOC-01`, `SOC-02`, `SOC-03`, `SOC-04`, `SOC-07`, `SOC-08`, `SOC-09`, `SOC-10`) audited in `AUDIT-SOC-073_074` across two strictly decoupled build passes:
- **Pass 1 (`M73.1`–`M73.2`):** Backend multi-reaction & GIF proxy persistence (`supabase/`, `apps/vhunambi_api/`), Global `InputDecorationTheme` focus border purge, 3-Tier `PostChromaticPaletteResolver`, and Social Hygiene (`SOC-07`–`SOC-10`). Must compile and pass `tsc.cmd --noEmit`, 29/29 backend tests, and `flutter analyze --no-pub` independently.
- **Pass 2 (`M73.3`–`M73.4`):** Client multi-reaction domain/repository/provider upgrades, tactile `ReactionTrayOverlay`, non-wrapping `KineticPostFocusView` v2, GIF & Sovereign Cultural Sticker picker + comment media rendering, and full verification tests.

---

## 2. Backend Multi-Reactions, Comment Media & GIF Proxy (`REQ-P73-BE-*`)

- **`REQ-P73-BE-01` (Supabase Schema Migration):** `supabase/migrations/20261121000001_phase73_reactions_and_comment_media.sql` SHALL idempotently add (`ADD COLUMN IF NOT EXISTS`):
  - `reaction_counts_json JSONB NOT NULL DEFAULT '{}'::jsonb` on `public.kinetic_posts` and `public.reel_comments`.
  - `reaction_type TEXT` on `public.social_interactions`.
  - `gif_url TEXT`, `sticker_id TEXT`, and `media_aspect_ratio DOUBLE PRECISION` on `public.reel_comments`.
- **`REQ-P73-BE-02` (SQLite & Edge SWR Parity):** Both `VhunambiDatabase` (`vhunambi_db.ts`) and `EdgeIsolateDatabaseEngine` (`edge_persistence_bridge.ts`) SHALL expose identical method signatures for `reactToKineticPost`, `reactToKineticPostAsync`, `reactToComment`, and `reactToCommentAsync`, preserving 1:1 proxy parity so `tsc.cmd --noEmit` succeeds cleanly.
- **`REQ-P73-BE-03` (Reaction Toggle & Switch Semantics):**
  - Canonical reaction keys SHALL be restricted to `'like' | 'love' | 'haha' | 'fire' | 'wow' | 'angry' | null`.
  - WHEN an actor submits a reaction equal to their currently active reaction OR `null`, the backend SHALL remove the interaction row from `social_interactions` (`interaction_type = 'post_react'` or `'comment_react'`), decrement the previous bucket (floored at `0`), set `myReaction = null`, and recompute `likeCount` as the sum of all non-zero reaction counts.
  - WHEN an actor switches from reaction `A` to reaction `B`, the backend SHALL atomically decrement `A` (floor `0`), increment `B`, update `social_interactions.reaction_type = B`, and persist via awaited Supabase write-through.
- **`REQ-P73-BE-04` (Multi-Isolate SWR Hydration):** `EdgeIsolateDatabaseEngine.syncExploreFromCloud()` SHALL also fetch `social_interactions` (with 3500ms timeout guard) and hydrate `socialInteractionReactions`, `kinetic_posts.reaction_counts_json`, and `reel_comments.{reaction_counts_json, gif_url, sticker_id, media_aspect_ratio}` so reactions and GIF/Sticker comments survive Worker isolate cold starts.
- **`REQ-P73-BE-05` (Media-Only Comments):** `POST /api/explore/posts/:id/comments` and `POST /api/social/clips/:id/comments` SHALL accept an empty `text` string IF `gifUrl` (non-empty HTTP/HTTPS URL) OR `stickerId` (non-empty string) is provided; IF all three (`text`, `gifUrl`, `stickerId`) are blank, the route SHALL return HTTP `400`.
- **`REQ-P73-BE-06` (Server-Side GIF Search Proxy):** `GET /api/social/gifs/search?q=...` and `GET /api/social/gifs/trending` SHALL read `TENOR_API_KEY` or `GIPHY_API_KEY` exclusively from Cloudflare Worker environment bindings (`VhunambiWorkerEnv`) or Node `process.env`, NEVER returning raw API keys to clients. WHEN neither key is configured or upstream times out, the route SHALL return HTTP `200` with `{ success: true, source: 'curated', items: [...] }` so clients never hit a 500 error.

---

## 3. Global Input Focus Border Purge (`REQ-P73-INPUT-*` / `SOC-02`)

- **`REQ-P73-INPUT-01` (Global Theme Hairline):** `AppTheme.darkTheme` (`app_theme.dart`) SHALL set `inputDecorationTheme.focusedBorder` to `OutlineInputBorder(borderRadius: AppRadius.inputBorder, borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.24), width: 1.0))` and `AppTheme.lightTheme` SHALL set `BorderSide(color: Colors.black.withValues(alpha: 0.18), width: 1.0)`. Neither theme SHALL use `AppColors.brandPrimary` (`#F97316`) for `focusedBorder`.
- **`REQ-P73-INPUT-02` (Borderless Leak Sealing):** `StudioReactionComposerBar` (`threaded_comments_section.dart`), `ExploreSearchView` (`explore_search_view.dart`), and `CreateKineticPostSheet` (`create_kinetic_post_sheet.dart`) SHALL explicitly declare `border: InputBorder.none`, `enabledBorder: InputBorder.none`, `focusedBorder: InputBorder.none`, and `disabledBorder: InputBorder.none`.
- **`REQ-P73-INPUT-03` (Explicit Widget Override Harmonization):** All 8 audited explicit `focusedBorder` override sites (`repost_kinetic_post_sheet.dart`, `direct_daw_vocal_upload_sheet.dart`, `prompt_input_box.dart`, `sovereign_auth_sheet.dart`, `playlists_vault_view.dart`, `add_to_playlist_sheet.dart`, `avatar_customization_modal.dart` x2, `publish_clip_modal.dart`) SHALL replace bright `#F97316` borders with subtle `1.0px` tonal hairlines (`AppColors.borderSubtleOf(context)` / subtle alpha ring).

---

## 4. 3-Tier Dynamic Chromatic World Synthesis (`REQ-P73-CHROM-*` / `SOC-03`)

- **`REQ-P73-CHROM-01` (3-Tier Resolution Order):** `PostChromaticPaletteResolver` SHALL resolve a `PostChromaticPalette` deterministically via:
  - **Tier 1 (Audio Attached + Cover Art):** `primaryGlow` derived from the song's `VhunambiMood.accentColor` (`VhunambiMood.tryNormalize(track.mood)` or live catalog lookup by `track.id`), and `secondaryGlow` extracted as dominant/vibrant color from the cover/attached artwork.
  - **Tier 2 (Artwork Only, No Audio/Mood):** `primaryGlow` extracted as dominant/vibrant color from the artwork, and `secondaryGlow` computed as its split-complementary HSL color (`(hue + 150.0) % 360.0`, saturation clamped to `[0.28, 0.65]`).
  - **Tier 3 (Neither Audio nor Artwork):** Fallback to `AppColors.brandPrimary` (`primaryGlow`) and `AppColors.accentElectric` (`secondaryGlow`).
- **`REQ-P73-CHROM-02` (WCAG AA Luminance Clamping):** For `Brightness.light`, resolved `accent` lightness SHALL be clamped to `<= 0.42` (guaranteeing `>= 4.5:1` contrast on `#F7F5F0` / `#FFFFFF` surfaces); for `Brightness.dark`, resolved `accent` lightness SHALL be clamped to `>= 0.62` (guaranteeing `>= 4.5:1` contrast on `#0A0A0C` / `#141418`).
- **`REQ-P73-CHROM-03` (Performance & Test Safety):** Palette extraction SHALL cache results in an in-memory LRU map (max `64` entries), enforce a `150ms` extraction timeout, support `asset:`, local file, and normalized HTTP image providers, and bypass async `PaletteGenerator.fromImageProvider` decoding in `FLUTTER_TEST` / headless environments via a deterministic seed-based color extractor so `FakeAsync` widget tests never stall.

---

## 5. Kinetic Post Focus v2, Multi-Reactions & GIF/Sticker Composer (`REQ-P73-SOC-*` / `SOC-01`, `SOC-04`)

- **`REQ-P73-SOC-01` (Non-Wrapping Focus Action Bar):** At viewport widths `320dp` and `360dp`, all 4 action controls (`Key('kpost_focus_like_btn_${post.id}')`, `Key('kpost_focus_comment_btn_${post.id}')`, `Key('kpost_focus_repost_btn_${post.id}')`, `Key('kpost_focus_remix_btn_${post.id}')`) SHALL render with `maxLines: 1`, `softWrap: false`, touch target height `>= 44.0dp`, and zero mid-word line breaks or `RenderFlex` overflow.
- **`REQ-P73-SOC-02` (Non-Truncating Engagement Summary):** The engagement summary (`Key('kpost_focus_summary_strip')`) SHALL use a `Wrap` layout rendering stacked top-3 `KineticReactionBadge` clusters + total reaction count alongside untruncated `Comments`, `Reposts`, and `Remixes` counters.
- **`REQ-P73-SOC-03` (Zero-Raw-Emoji Multi-Reaction Badges — `STD-UIUX-001`):** `KineticReactionBadge` SHALL render all 6 `KineticReactionType` reactions (`like`, `love`, `haha`, `fire`, `wow`, `angry`) exclusively via glossy custom vector `CustomPainter` + `PhosphorIconsFill` motifs. Zero raw OS Unicode emojis SHALL appear in Dart UI code.
- **`REQ-P73-SOC-04` (Long-Press `ReactionTrayOverlay` & Legacy Like Preservation):**
  - Long-pressing (`>= 350ms`) the react control on `KineticPostFocusView` (`Key('kpost_focus_like_btn_${post.id}')`), `ExploreSocialPostCard` (`Key('social_post_like_btn_${post.id}')`), or `_ThreadedCommentTile` (`ValueKey('comment_like_${comment.id}')`) SHALL open `ReactionTrayOverlay` (`Key('reaction_tray_overlay')`) containing 6 tactile reaction targets (`Key('reaction_tray_item_<name>')`) with drag-to-scrub `1.4x` hover magnification and `HapticFeedback.selectionClick()`.
  - Single-tapping the react control SHALL quick-toggle `KineticReactionType.love` (when `myReaction == null`) or clear `myReaction` (when already active).
  - WHEN a post or comment has `reactionCounts.isEmpty` and a legacy `likeCount > 0`, the reaction engine SHALL seed `counts[KineticReactionType.love] = likeCount` before applying the reaction delta so existing likes (e.g. `1,840`) are never wiped to `1`.
  - `ReactionTrayOverlay.dismiss()` SHALL be invoked in `dispose()` of `KineticPostFocusView`, `ExploreSocialPostCard`, and `ThreadedCommentsSection` to prevent orphaned root `OverlayEntry` instances.
- **`REQ-P73-SOC-05` (GIF & Sovereign Cultural Sticker Composer):**
  - `StudioReactionComposerBar` SHALL expose a media picker trigger (`Key('comment_media_picker_btn')`) opening `GifStickerPickerSheet` (`Key('gif_sticker_picker_sheet')`) with two tabs: **Stickers** (`Key('picker_tab_stickers')`, 8 bundled offline vector studio stickers) and **GIFs** (`Key('picker_tab_gifs')`, live search querying `GET /api/social/gifs/search`).
  - Selecting a GIF or Sticker SHALL populate an inline removable preview chip (`Key('composer_pending_media_chip')`) above the text input and enable submission (`Key('comment_send_btn')`) even when the text field is empty.
  - `_ThreadedCommentTile` SHALL render attached GIFs (`Key('comment_gif_media_<commentId>')`) and Stickers (`Key('comment_sticker_media_<commentId>')`) cleanly inside both root comments and nested replies.
- **`REQ-P73-SOC-06` (Phase 69 Test-Key Preservation):** All Phase 69 keys (`kpost_focus_like_btn_<id>`, `kpost_focus_comment_btn_<id>`, `kpost_focus_repost_btn_<id>`, `kpost_focus_remix_btn_<id>`, `social_post_like_btn_<id>`, `comment_like_<id>`, `threaded_comments_header_<id>`, `comment_toggle_replies_<id>`, `comment_author_badge_<id>`, `comment_reply_btn_<id>`, `comment_active_reply_banner`, `comment_reaction_chip_fire`, `comment_input`, `comment_send_btn`, `comment_sort_toggle_btn`, `comment_sort_option_newest`, `kpost_focus_image_counter_<id>`) SHALL remain 100% preserved.

---

## 6. Social Hygiene (`REQ-P73-HYG-*` / `SOC-07`, `SOC-08`, `SOC-09`, `SOC-10`)

- **`REQ-P73-HYG-01` (Unified Self-Aware Profile Routing — `SOC-07`):** `navigateToCreatorProfile(context, ref, creatorId: ..., creatorHandle: ...)` SHALL call `resolveViewerRole(...)` (`EP-P70-VIEWER-ROLE`) and push `const OwnerProfileView()` when `ViewerRole.owner`, or `ArtistProfileView(artistId: creatorId)` when `ViewerRole.visitor`. All 7 audited navigation call sites SHALL route through this helper, and zero hardcoded `'@current_user'` strings SHALL remain in `explore_social_post_card.dart` or `direct_daw_vocal_upload_sheet.dart`.
- **`REQ-P73-HYG-02` (Splash-to-RootShell MiniPlayer Suppression — `SOC-08`):** `SplashView` SHALL NOT clear `isSplashActiveProvider` prior to its `420ms` fade route completing. `RootShell.initState()` SHALL clear `isSplashActiveProvider` inside a post-frame callback once mounted (and `OnboardingView` SHALL keep it hidden until `RootShell` mounts). Standalone tests overriding `isSplashActiveProvider.overrideWith((ref) => false)` SHALL remain unaffected.
- **`REQ-P73-HYG-03` (`CreateKineticPostSheet` Fixes — `SOC-09`):**
  - Toggling aspect ratio chips (`1:1`, `4:5`, `16:9`) SHALL rewrite `aspectRatio` on all existing `_attachedImages` via `.copyWith(aspectRatio: ratio)` and preview images at the selected ratio.
  - Vision AI thumbnails SHALL render via `VhunambiTrackArtwork` with `AppConstants.normalizeCloudMediaUrl(...)`.
  - WHEN `_attachedImages.length >= 4`, both `+ Photo` and `AI Vision` add triggers SHALL be disabled (`onPressed: null` / muted visual state) and an inline `"4/4 Max images attached"` pill (`Key('kpost_max_images_badge')`) SHALL appear — with zero red error SnackBar.
- **`REQ-P73-HYG-04` (Clean Hive Recent Searches & Live Discovery — `SOC-10`):** `RecentSearchesNotifier._initialSearches()` SHALL return `const <String>[]` when Hive contains no saved entry (hiding the `"Recent Searches"` header completely when empty while retaining full Hive persistence on `addQuery` / `removeQuery` / `clearAll`). `"You May Like"` in `ExploreSearchView` SHALL derive suggestions dynamically from live `exploreTracksProvider` and `VhunambiMood.values` (with no hardcoded `'Kabza de Small log drum'` mock seed).

---

## 7. Non-Functional Requirements (`REQ-P73-NFR-*`)

- **`REQ-P73-NFR-01` (60 FPS Scrolling Glass Guardrail):** All repeating feed cards and comment tiles SHALL pass `enableLiveBlur: false` to `VhunambiGlassSurface`; opt-in live blur (`blurSigma <= 14.0`) is restricted strictly to static chrome (top app bar, sticky composer dock, floating `ReactionTrayOverlay`).
- **`REQ-P73-NFR-02` (Zero Added Dependencies / Zero APK Bloat):** Phase 73 SHALL add zero new packages to `pubspec.yaml` (reusing bundled `palette_generator: 0.3.3+7`, `phosphor_icons`, `cached_network_image`, `dio`, `hive_flutter`).
- **`REQ-P73-NFR-03` (Backend Runner Standard):** Backend verification SHALL execute via `.\node_modules\.bin\tsc.cmd --noEmit` and `npm test` (`tsx test/*.test.ts`), NEVER `vitest`.

---

## 8. Requirement-to-Test Traceability Matrix

```text
+--------------------+---------------------------------------------+----------------------------------------------------------+
| REQ ID             | Target Implementation                       | Verification Test Case                                   |
+--------------------+---------------------------------------------+----------------------------------------------------------+
| REQ-P73-BE-01..06  | 20261121000001 SQL, vhunambi_db.ts,         | phase73_reactions_gifs_and_comment_media.test.ts         |
|                    | edge_persistence_bridge.ts, explore/social  | (POST /react, SWR rehydrate, media comment, /gifs)       |
+--------------------+---------------------------------------------+----------------------------------------------------------+
| REQ-P73-INPUT-01..3| app_theme.dart + 11 audited TextField sites | phase73_kinetic_post_chromatic_reactions_test.dart       |
|                    |                                             | ("AppTheme focusedBorder is subtle, never #F97316")      |
+--------------------+---------------------------------------------+----------------------------------------------------------+
| REQ-P73-CHROM-01..3| post_chromatic_palette_resolver.dart        | phase73_kinetic_post_chromatic_reactions_test.dart       |
|                    |                                             | ("3-Tier Chromatic Resolver + WCAG AA bounds")           |
+--------------------+---------------------------------------------+----------------------------------------------------------+
| REQ-P73-SOC-01..06 | kinetic_reaction.dart, reaction_tray,       | phase73_kinetic_post_chromatic_reactions_test.dart +     |
|                    | gif_sticker_picker_sheet.dart, focus view   | phase69_kinetic_post_focus_and_threading_test.dart       |
+--------------------+---------------------------------------------+----------------------------------------------------------+
| REQ-P73-HYG-01     | profile_navigation_helper.dart + 7 sites    | phase73_kinetic_post_chromatic_reactions_test.dart       |
|                    |                                             | ("navigateToCreatorProfile routes owner vs visitor")     |
+--------------------+---------------------------------------------+----------------------------------------------------------+
| REQ-P73-HYG-02     | splash_view.dart, main.dart (RootShell)     | phase73_kinetic_post_chromatic_reactions_test.dart +     |
|                    |                                             | mini_player_host_test.dart                               |
+--------------------+---------------------------------------------+----------------------------------------------------------+
| REQ-P73-HYG-03     | create_kinetic_post_sheet.dart              | phase73_kinetic_post_chromatic_reactions_test.dart       |
|                    |                                             | ("CreateKineticPostSheet aspect propagation & 4/4 cap")  |
+--------------------+---------------------------------------------+----------------------------------------------------------+
| REQ-P73-HYG-04     | explore_providers.dart, explore_search_view | phase73_kinetic_post_chromatic_reactions_test.dart +     |
|                    |                                             | ignored_domains_persistence_test.dart                    |
+--------------------+---------------------------------------------+----------------------------------------------------------+
```
