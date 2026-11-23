# Phase 78 Execution Plan (`tasks.md`)

**Phase ID:** `P78` — Vault, Explore & Profile Continuity, Real Audio/Video Uploads & Unified Glass Tabs  
**Execution Cadence:** Strictly two sequential passes (`Pass 1: M78.1–M78.2`, verify Pass 1 gates 100%, then `Pass 2: M78.3–M78.4`, verify full gates + `memory.md` SLEEP).

---

## 1. Master Milestone Roadmap

```text
PASS 1 (Stop-the-Bleeding Pipelines, Ownership & Overlay Containment)
 ├── M78.1: Real Audio Upload (Client + API WAV/AAC/OGG) & Real Camera/Gallery Video in Reels Studio
 └── M78.2: Kill SnackBar Storm, MiniPlayerHost Suppression/Dock, @aistudio Owner Rescue & Lyric Sanitizer
       │
       ▼ [PASS 1 GATE: dart analyze + tsc --noEmit + API tests + Pass 1 Flutter suites 100% GREEN]
       │
PASS 2 (Continuity Hub, Unified Glass Tabs & Explore/Profile Polish)
 ├── M78.3: Explore Index-0 Reel Pin, Library Reels Vault Tab, CreatorReelThumbnailCard Art & Tab Dedupe
 └── M78.4: Unified VhunambiGlassTabBar, Horizontal Mood Rail, TrackListTile Art, Polish Seams & Full Regression
       │
       ▼ [PASS 2 GATE: G78-01..G78-06 + memory.md "completed" + consolidate_memory.mjs (0 OPEN)]
```

---

## 2. Pass 1 — `M78.1`: Real Song Upload & Camera/Gallery Video Capture (`VA-02`)

- [x] **T78.1.1 — Extend Backend R2 Upload MIME Allowlist (`REQ-P78-UPL-03`)**
  - **Target:** `apps/vhunambi_api/src/routes/social_routes.ts` (+ unit test in `apps/vhunambi_api/test/`)
  - **Action:** Add `'audio/wav'`, `'audio/x-wav'`, `'audio/wave'`, `'audio/aac'`, and `'audio/ogg'` to `ALLOWED_SOCIAL_MEDIA_MIMES` and verify with a backend test.
  - **Acceptance:** `POST /api/social/media/upload` accepts WAV/AAC/OGG up to `25 MB` cleanly; `npx tsc --noEmit` and `npm test` pass 100%.

- [x] **T78.1.2 — Repair `DirectDawVocalUploadSheet` Real File Picking, Local/R2 Persist & Song Visibility (`REQ-P78-UPL-01..02`)**
  - **Target:** `apps/vhunambi_client/lib/features/studio/presentation/widgets/direct_daw_vocal_upload_sheet.dart`
  - **Action:** Wire interactive `Key('direct_upload_pick_file_btn')` with `FilePicker.platform.pickFiles` (+ `FLUTTER_TEST` stub), persist local audio copy, upload bytes via `socialRepositoryProvider.uploadReelMedia`, set `isInstrumental: false` for DAW/Vocal song uploads with active owner `creatorId`/`creatorHandle`, and route `Dance Reel` tab to `KineticReelStudioView.show(context, initialCameraMode: true)`.
  - **Acceptance:** Uploaded song lands immediately in `libraryTracksProvider` (`LibraryCategory.songs`) and `OwnerProfileView` (`Your Songs`) with valid local + R2 audio URLs.

- [x] **T78.1.3 — Add `PublishedClip.localVideoPath` & Real Camera/Gallery Video Recording + Stage 2 Playback (`REQ-P78-CAM-01..02`)**
  - **Target:** `apps/vhunambi_client/lib/features/social/domain/models/published_clip.dart`, `apps/vhunambi_client/lib/features/content_studio/presentation/views/kinetic_reel_studio_view.dart`, `apps/vhunambi_client/lib/features/content_studio/presentation/views/kinetic_reel_publish_view.dart`
  - **Action:** Add optional `localVideoPath` to `PublishedClip`; implement `startVideoRecording`/`stopVideoRecording` + recording indicator (`Key('reel_studio_recording_indicator')`) + Stage 2 `VideoPlayerController` (`Key('reel_studio_stage2_video_preview')`) and gallery photo preview (`Key('reel_studio_stage2_photo_preview')`); propagate `customMediaLocalPath` through publish into `PublishedClip`.
  - **Acceptance:** Camera recordings and picked gallery videos play visibly in Stage 2 Editor and carry both local and R2 paths into `PublishedClip`.

- [x] **T78.1.4 — Unobstruct Top Audio Pill in `KineticReelStudioView` (`REQ-P78-CAM-03`)**
  - **Target:** `apps/vhunambi_client/lib/features/content_studio/presentation/views/kinetic_reel_studio_view.dart`
  - **Action:** Keep only `Close`, centered wide `Key('reel_studio_audio_pill')` (`minWidth: 168`), and `Rail Side Flip` on top row; relocate `Flash`, `Speed`, and `Timer` buttons cleanly onto the vertical tool rail preserving every existing `Key`.
  - **Acceptance:** Track titles render cleanly on `360dp` mobile without crushing to `[🎵 U...]`, and all existing `phase74_reels_studio_and_playback_v4_test.dart` assertions stay green.

---

## 3. Pass 1 — `M78.2`: Ephemeral Reactions, `MiniPlayerHost` Discipline, `@aistudio` Ownership & Sanitizer (`VA-03`, `VA-05`, `VA-06`, `VA-09`)

- [x] **T78.2.1 — Kill `Loved 39x!` SnackBar Storm & Add Overlay Ref-Count + Artwork Base in `KineticReelsModal` (`REQ-P78-HUD-01..02`, `REQ-P78-UIUX-02`)**
  - **Target:** `apps/vhunambi_client/lib/features/social/presentation/widgets/kinetic_reels_modal.dart`
  - **Action:** Remove `ScaffoldMessenger.showSnackBar` in `_recordLove` and add in-place ephemeral `Key('reel_ephemeral_love_pill')` (`800ms` resettable timer); ref-count `pushedFullScreenOverlayCountProvider` in `initState`/`dispose`; support `localVideoPath` in `_ReelVideoBackingLayer` and render `VhunambiTrackArtwork` beneath until `_initialized == true`.
  - **Acceptance:** Zero SnackBars queued on 10+ rapid loves; `MiniPlayerHost` completely hidden during Reels playback; zero black-slab fallback frames.

- [x] **T78.2.2 — Auto-Dock Stranded `PlayerMode.manual` MiniPlayer on Tab Switch (`REQ-P78-HUD-02`)**
  - **Target:** `apps/vhunambi_client/lib/main.dart`
  - **Action:** Inside `RootShell._switchTab`, call `miniPlayerControllerProvider.notifier.resetToDock(MediaQuery.maybeSizeOf(context))` whenever `playerController.mode == PlayerMode.manual`.
  - **Acceptance:** Dragging the MiniPlayer mid-screen and switching to Library or Explore cleanly docks it at the bottom bar.

- [x] **T78.2.3 — Fix `@aistudio` Creator Lockout Across Generation, Lookup & Role Resolution (`REQ-P78-OWN-01`)**
  - **Target:** `apps/vhunambi_client/lib/features/studio/presentation/providers/generation_pipeline_providers.dart`, `apps/vhunambi_client/lib/features/track/domain/models/track_entity.dart`, `apps/vhunambi_client/lib/core/auth/viewer_role.dart`, `apps/vhunambi_client/lib/features/track/presentation/providers/track_providers.dart`, `apps/vhunambi_client/lib/features/profile/presentation/views/owner_profile_view.dart`
  - **Action:** Stamp authenticated creator `creatorId`, `creatorHandle`, and `creatorName` on newly generated `LibraryTrack`s; rescue legacy `'AI Studio'` / `@aistudio` / `creator_ai_studio` records to `ViewerRole.owner` and active creator handle.
  - **Acceptance:** Newly generated and legacy AI Studio local tracks open in `TrackDetailView` with `ViewerRole.owner` (Stem Lab + Mastering unlocked) and active handle.

- [x] **T78.2.4 — Harden `LyricKaraokeSanitizer` & `LyricsTeleprompter` + Normalize Legacy `@current_user` (`REQ-P78-OWN-02`, `REQ-P78-UIUX-02`)**
  - **Target:** `apps/vhunambi_client/lib/features/content_studio/domain/utils/lyric_karaoke_sanitizer.dart`, `apps/vhunambi_client/lib/features/track/presentation/widgets/lyrics_teleprompter.dart`, `apps/vhunambi_client/lib/features/explore/domain/models/social_music_post.dart`
  - **Action:** Strip balanced & unclosed parenthetical stage cues (`(Sacred drum;`, `(Li-ste-en`) in `cleanLyricTextForKaraoke`/`sanitizeAlignment`; add `cleanLyricsForPlayback` stripping `[INTRO]`/`[OUTRO]` while preserving `[Verse 1]`/`[Chorus]` for `LyricsTeleprompter`; normalize legacy `@current_user` in `SocialMusicPost.fromJson`.
  - **Acceptance:** Pass 1 Gate passes 100% (`dart analyze`, backend `tsc` + `npm test`, and Pass 1 Flutter suites).

---

## 4. Pass 2 — `M78.3`: Explore $\leftrightarrow$ Library $\leftrightarrow$ Owner Profile Continuity (`VA-01`)

- [x] **T78.3.1 — Pin Newly Published Reels to Index 0 in `trendingReelsProvider` (`REQ-P78-CONT-01`)**
  - **Target:** `apps/vhunambi_client/lib/features/social/presentation/providers/trending_reels_provider.dart`
  - **Action:** Partition freshly published non-seed / active-owner Reels ahead of virality-sorted clips (newest-first at index `0`) across `All` and matching genre filters.
  - **Acceptance:** Publishing a Reel immediately places it at index `0` of Explore's `Kinetic Reels` rail.

- [x] **T78.3.2 — Add `LibraryCategory.reels` & `ReelsVaultView` to Asset Vault (`REQ-P78-CONT-02`)**
  - **Target:** `apps/vhunambi_client/lib/features/library/domain/models/library_models.dart`, `apps/vhunambi_client/lib/features/social/presentation/providers/social_feed_provider.dart`, `apps/vhunambi_client/lib/features/library/presentation/providers/library_providers.dart`, `apps/vhunambi_client/lib/features/library/presentation/views/reels_vault_view.dart` (new), `apps/vhunambi_client/lib/features/library/presentation/views/library_view.dart`, `apps/vhunambi_client/lib/features/library/presentation/widgets/library_category_rail.dart`, `apps/vhunambi_client/lib/features/library/presentation/widgets/library_empty_state.dart`
  - **Action:** Add `LibraryCategory.reels`, `SocialFeedNotifier.deleteClip`, `ownerVaultReelsProvider`, and `ReelsVaultView` (`Key('library_reels_vault_view')`, `Key('library_reels_create_btn')`) with quick play, share, and delete.
  - **Acceptance:** Owner's published Reels appear immediately in `LibraryView` -> `Reels` tab with live count badge.

- [x] **T78.3.3 — Fix `CreatorReelThumbnailCard` Artwork & Deduplicate `OwnerProfileView` Tabs (`REQ-P78-CONT-03`)**
  - **Target:** `apps/vhunambi_client/lib/features/social/presentation/widgets/creator_reel_thumbnail_card.dart`, `apps/vhunambi_client/lib/features/profile/presentation/views/owner_profile_view.dart`
  - **Action:** Replace `_CoverArt` with `VhunambiTrackArtwork` and replace all 3 stock `Icons.*` with `PhosphorIcon`; remove duplicate `_OwnerReelsShelf()` from `OwnerStudioTab.songs`.
  - **Acceptance:** Zero blank orange boxes in `My Clips & Reels`, zero `Icons.*` in `CreatorReelThumbnailCard`, and zero duplicate Reels shelf under `Songs`.

---

## 5. Pass 2 — `M78.4`: Unified `VhunambiGlassTabBar`, Explore Polish, Regression Suite & Memory SLEEP (`VA-04`, `VA-09`)

- [x] **T78.4.1 — Create `VhunambiGlassTabBar` (`EP-P78-GLASS-TAB-BAR`) & Adopt Across 4 Surfaces (`REQ-P78-TAB-01`)**
  - **Target:** `apps/vhunambi_client/lib/core/widgets/vhunambi_glass_tab_bar.dart` (new), `apps/vhunambi_client/lib/features/profile/presentation/views/owner_profile_view.dart`, `apps/vhunambi_client/lib/features/profile/presentation/views/artist_profile_view.dart`, `apps/vhunambi_client/lib/features/explore/presentation/views/explore_view.dart`, `apps/vhunambi_client/lib/features/library/presentation/widgets/library_category_rail.dart`
  - **Action:** Implement `VhunambiGlassTabBar` + `VhunambiGlassTabBarHeaderDelegate` and migrate all 4 tab bars while preserving existing widget test `Key`s and Light/Dark WCAG AA contrast.
  - **Acceptance:** Unified frosted glass tab bar renders cleanly in Light & Dark modes across Owner Profile, Artist Profile, Explore, and Library.

- [x] **T78.4.2 — Upgrade Explore Mood Rail, `TrackListTile` Artwork, Tip Glass Pill & Vision Fallback (`REQ-P78-UIUX-01..02`)**
  - **Target:** `apps/vhunambi_client/lib/features/explore/presentation/widgets/catalog_filter_bar.dart`, `apps/vhunambi_client/lib/features/explore/presentation/widgets/track_list_tile.dart`, `apps/vhunambi_client/lib/features/explore/presentation/views/kinetic_post_focus_view.dart`, `apps/vhunambi_client/lib/features/explore/presentation/widgets/create_kinetic_post_sheet.dart`
  - **Action:** Replace vertical mood `Wrap` with horizontal `Key('catalog_mood_rail')` + `*Of(context)` tokens; migrate `TrackListTile` to `VhunambiTrackArtwork`; upgrade `Key('kpost_focus_tip_btn')` to a frosted `'Tip'` glass pill; diversify offline Vision AI cover fallbacks.
  - **Acceptance:** Compact single-row mood rail, real artwork in `Fastest Growing Tracks`, crisp `'Tip'` pill, and distinct offline Vision previews.

- [x] **T78.4.3 — Author Phase 78 Comprehensive Regression Suite & Run Full Gates (`G78-01` – `G78-05`)**
  - **Target:** `apps/vhunambi_client/test/features/phase78_vault_explore_continuity_uploads_glass_tabs_test.dart` (new)
  - **Action:** Add headless unit + widget tests covering every `REQ-P78-*` requirement (uploads, camera/video local path, audio pill, ephemeral love pill, MiniPlayer overlay & tab dock reset, `@aistudio` rescue, sanitizer unclosed `(` & `[INTRO]`, index-0 Reel pinning, `LibraryCategory.reels`, `CreatorReelThumbnailCard` artwork, `VhunambiGlassTabBar` Light/Dark, horizontal mood rail, `TrackListTile` artwork, Tip pill, `@current_user` normalization), and execute full verification gates (`G78-01`–`G78-05`).
  - **Acceptance:** `dart analyze` `0` issues, `STD-UIUX-001` `0` violations, backend + Flutter test suites 100% green.

- [x] **T78.4.4 — Finalize Phase 78 Memory & Consolidate Connectome (`G78-06` SLEEP)**
  - **Target:** `docs/phases/phase_78_vault_explore_continuity_uploads_and_glass_tabs/memory.md`
  - **Action:** Update `"status": "completed"`, `"completed_at"`, verified breakthroughs & gotchas ONLY after `G78-01`–`G78-05` pass 100%, then run `node .agents/skills/vhunambi-memory/scripts/consolidate_memory.mjs` confirming `0 OPEN` endpoints.

---

## 6. Stage 4 Verification Commands

```powershell
# G78-01: Client Static Analysis
Set-Location apps/vhunambi_client
dart analyze

# G78-02: Backend Typecheck & Tests
Set-Location ../vhunambi_api
npx tsc --noEmit
npm test

# G78-03: STD-UIUX-001 Scan
Set-Location ../vhunambi_client
$dirs = @('lib/core/widgets', 'lib/features/studio', 'lib/features/content_studio', 'lib/features/social', 'lib/features/library', 'lib/features/profile', 'lib/features/explore', 'lib/features/player', 'lib/features/track')
Select-String -Path (Get-ChildItem -Recurse $dirs -Filter *.dart) -Pattern "\bIcons\." -CaseSensitive
Select-String -Path (Get-ChildItem -Recurse $dirs -Filter *.dart) -Pattern "[\u2600-\u27BF]|[\uD83C-\uDBFF][\uDC00-\uDFFF]" | Where-Object { $_.Line -notmatch "^\s*//" }

# G78-04 & G78-05: Bounded Flutter Regression Suite
flutter test test/features/phase78_vault_explore_continuity_uploads_glass_tabs_test.dart test/features/studio test/features/content_studio test/features/social test/features/library test/features/profile test/features/explore test/features/player test/features/track --no-pub --timeout=60s

# G78-06: Memory SLEEP Consolidation
Set-Location c:\Users\Ndugelo\VHUNAMBI\monorepo
node .agents/skills/vhunambi-memory/scripts/consolidate_memory.mjs
```
