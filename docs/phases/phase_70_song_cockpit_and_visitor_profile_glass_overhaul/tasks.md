# Phase 70 Master Execution Tasks & Two-Pass Verification Roadmap

- **Document ID:** `VHUNAMBI-SPEC-P70-TASKS-V1`
- **Phase:** `Phase 70` (`phase_70_song_cockpit_and_visitor_profile_glass_overhaul`)
- **Upstream Design & Requirements:** [blueprint.md](./blueprint.md) | [requirements.md](./requirements.md) | [design.md](./design.md)
- **Strict Pass Isolation Rule:** Overhaul Pass 1 (`M70.1`–`M70.2`) MUST compile cleanly, pass `flutter analyze` (`0 issues`), and pass all Pass 1 tests independently with zero references to Pass 2 (`M70.3`–`M70.4`) files.

---

## 1. Master Milestone Roadmap & Dependency Graph

```text
+===================================================================================+
|               OVERHAUL PASS 1 (M70.1 -> M70.2) — COMPILE GATE #1                  |
+===================================================================================+
| [M70.1] Core Glass, VhunambiMood, ViewerRole & MiniPlayerHost Route Policy        |
|   ├── Task 70.1.1: VhunambiGlassSurface + VhunambiAmbientMeshBackdrop             |
|   ├── Task 70.1.2: Canonical VhunambiMood (moodId) + normalize()                  |
|   ├── Task 70.1.3: Deterministic ViewerRole policy (EP-P61-IDENTITY-UTILS)        |
|   └── Task 70.1.4: MiniPlayerHost pushed-route suppression providers              |
|                                        |                                          |
|                                        v                                          |
| [M70.2] Role-Aware Song Cockpit (TrackDetailView) & Pass 1 Verification           |
|   ├── Task 70.2.1: Extend TrackDetailEntity + TrackDetailNotifier hydration       |
|   ├── Task 70.2.2: Role-gated TrackHeroSection, Light-Safe TrackActionsBar,       |
|   │                Compact EmojiReactionDeck & TrackSonicTelemetryCard            |
|   ├── Task 70.2.3: Role-gated TrackDetailView + EP-P69 ThreadedComments + Icons   |
|   └── Task 70.2.4: Pass 1 Tests (phase70_song_cockpit_and_glass_test.dart +       |
|                    track_detail_view_test.dart + mini_player_host_test.dart)      |
+===================================================================================+
                                         |
                                         v
+===================================================================================+
|               OVERHAUL PASS 2 (M70.3 -> M70.4) — COMPILE GATE #2                  |
+===================================================================================+
| [M70.3] Facebook-Benchmark Public Visitor Profile (ArtistProfileView)             |
|   ├── Task 70.3.1: Glass ProfileBannerHeader (Light contrast Following + [...])   |
|   ├── Task 70.3.2: Dynamic creatorCatalogTracks & creatorKineticPosts providers   |
|   │                + de-emojified TopSupportersLeaderboard & profile_models.dart  |
|   └── Task 70.3.3: 5-Tab ArtistProfileView (Overview default, privacy scrub,      |
|                    zero LoadingOverlay, zero stock Icons.*)                       |
|                                        |                                          |
|                                        v                                          |
| [M70.4] Wire EP-P58 Producer Beats, Backend moodId Parity & Full Verification     |
|   ├── Task 70.4.1: Consume EP-P58-MKT-VERIFY-PRODUCER in HttpMarketplaceRepo      |
|   │                + producerBeatsFamilyProvider wired into Visitor Beats tab     |
|   ├── Task 70.4.2: Supabase SQL migration + apps/vhunambi_api mood_taxonomy.ts,   |
|   │                vhunambi_db.ts, edge_persistence_bridge.ts & explore_routes.ts |
|   └── Task 70.4.3: Pass 2 Client & API Tests + Memory SLEEP Consolidation         |
+===================================================================================+
```

---

## 2. Overhaul Pass 1 — Milestone `M70.1`: Core Glass Primitives, `VhunambiMood`, `ViewerRole` & `MiniPlayerHost`

### [x] Task 70.1.1 — Implement `VhunambiGlassSurface` & `VhunambiAmbientMeshBackdrop`
- **Target Files:**
  - `apps/vhunambi_client/lib/core/widgets/vhunambi_glass_surface.dart` (NEW)
  - `apps/vhunambi_client/lib/core/widgets/vhunambi_ambient_mesh_backdrop.dart` (NEW)
- **Design Reference:** `design.md` §1 & §2 (`REQ-P70-GLASS-01..03`)
- **Acceptance Criteria:**
  - Warm African Daylight ("Morning Mist") and Obsidian Studio ("Obsidian Night") palettes resolve dynamically from `Theme.of(context).brightness`.
  - `enableLiveBlur` defaults to `false` (zero `BackdropFilter` on list/grid cards); opt-in clamps `blurSigma <= 16.0` inside `RepaintBoundary` + `ClipRRect`.
  - `VhunambiAmbientMeshBackdrop` wraps radial mesh orbs in `Positioned.fill(child: IgnorePointer(child: RepaintBoundary(...)))`.

### [x] Task 70.1.2 — Implement Canonical `VhunambiMood` (`moodId`) Registry
- **Target Files:**
  - `apps/vhunambi_client/lib/core/design_system/tokens/vhunambi_mood.dart` (NEW)
  - `apps/vhunambi_client/lib/features/explore/presentation/providers/explore_providers.dart` (SURGICAL UPDATE: normalize mood filter comparisons through `VhunambiMood.normalize`)
- **Design Reference:** `design.md` §3 (`REQ-P70-MOOD-01..03`)
- **Acceptance Criteria:**
  - Defines 6 canonical `moodId` slugs (`'uplifting'`, `'soulful'`, `'energetic'`, `'chill'`, `'hypnotic'`, `'romantic'`).
  - `VhunambiMood.normalize(String? raw)` losslessly maps all legacy strings from `design_enums.dart`, `StudioFormState`, `explore_providers.dart`, and `edge_persistence_bridge.ts`.
  - Backward-compatible `fromLegacyMood` / `toLegacyMood` keeps `MoodColorChip` 100% intact.

### [x] Task 70.1.3 — Implement Deterministic `ViewerRole` Policy
- **Target File:** `apps/vhunambi_client/lib/core/auth/viewer_role.dart` (NEW)
- **Design Reference:** `design.md` §4 (`REQ-P70-ROLE-01..02`)
- **Acceptance Criteria:**
  - Uses `EP-P61-IDENTITY-UTILS` (`canonicalizeCreatorId`, `extractRawCreatorId`).
  - Non-owner tracks (`@lerato_prod`, `@fifi`, `@makhadzi`, blank creatorId) fail closed to `ViewerRole.visitor` when active user is `@cern` / `@ndugelo`.

### [x] Task 70.1.4 — Generalize `MiniPlayerHost` Pushed-Route Suppression
- **Target Files:**
  - `apps/vhunambi_client/lib/core/navigation/navigation_providers.dart` (ADD `trackDetailInlinePlayerMountedProvider`, `pushedFullScreenOverlayCountProvider`)
  - `apps/vhunambi_client/lib/features/player/presentation/widgets/mini_player_host.dart` (UPDATE `_shouldHide`)
- **Design Reference:** `design.md` §5 (`REQ-P70-MINI-01..02`)
- **Acceptance Criteria:**
  - `MiniPlayerHost` hides cleanly whenever `trackDetailInlinePlayerMountedProvider > 0` or `pushedFullScreenOverlayCountProvider > 0`.
  - Existing `test/features/player/widgets/mini_player_host_test.dart` and `test/features/player/phase33_adaptive_mini_player_test.dart` remain 100% green without modification.

---

## 3. Overhaul Pass 1 — Milestone `M70.2`: Role-Aware Song Cockpit (`TrackDetailView`)

### [x] Task 70.2.1 — Extend `TrackDetailEntity` & Hydrate Metadata in `TrackDetailNotifier`
- **Target Files:**
  - `apps/vhunambi_client/lib/features/track/domain/models/track_detail_models.dart`
  - `apps/vhunambi_client/lib/features/track/presentation/providers/track_providers.dart`
- **Design Reference:** `design.md` §6 (`REQ-P70-TRACK-01..02`)
- **Acceptance Criteria:**
  - Adds `coverUrl`, `description`, `createdAt`, `bpm`, `musicalKey`, `moodId`, `allowOpenStemsRemix` with defaults and `copyWith`.
  - Purges raw Unicode emojis from `reactionGlyphs` and `licenseBadge`.
  - `_lookupInitialTrack` maps real fields from `libraryTracksProvider`, `exploreTracksProvider`, and `seededTrackDetails`.

### [x] Task 70.2.2 — Upgrade Song Cockpit Sub-Widgets & Zero-Emoji / Zero-Stock-Icon Sweep
- **Target Files:**
  - `apps/vhunambi_client/lib/features/track/presentation/widgets/track_hero_section.dart`
  - `apps/vhunambi_client/lib/features/track/presentation/widgets/track_actions_bar.dart`
  - `apps/vhunambi_client/lib/features/track/presentation/widgets/emoji_reaction_deck.dart`
  - `apps/vhunambi_client/lib/features/track/presentation/widgets/track_sonic_telemetry_card.dart` (NEW)
  - `apps/vhunambi_client/lib/features/track/presentation/widgets/more_like_this_shelf.dart`
  - `apps/vhunambi_client/lib/features/track/presentation/widgets/waveform_scrubber.dart`
  - `apps/vhunambi_client/lib/features/track/presentation/widgets/prompt_attribution_card.dart`
- **Design Reference:** `design.md` §7.1–§7.4 (`REQ-P70-GATE-01`, `REQ-P70-SCUX-01..04`, `REQ-P70-SCUX-06`)
- **Acceptance Criteria:**
  - `TrackHeroSection` renders `VhunambiTrackArtwork` (`EP-P68-TRACK-ARTWORK`), visitor Provenance Pill (`Key('track_visitor_provenance_pill')`) vs owner License Deed (`Key('track_owner_deed_card')`).
  - `TrackActionsBar` fixes Light-Mode white-on-white ghost pill (`AppColors.textPrimaryOf(context)` inside `VhunambiGlassSurface`).
  - `EmojiReactionDeck` renders compact single-row horizontal Phosphor glass rail (`44dp` height, zero raw emojis).
  - `TrackSonicTelemetryCard` displays Song Description, Genre, BPM, Key, Language, Duration, Date, and `VhunambiMood` pill (`Key('track_mood_chip')`).
  - Zero stock `Icons.*` and zero raw emojis remain across `features/track/`.

### [x] Task 70.2.3 — Wire Role-Gated `TrackDetailView` + `EP-P69-THREADED-COMMENTS`
- **Target File:** `apps/vhunambi_client/lib/features/track/presentation/views/track_detail_view.dart`
- **Design Reference:** `design.md` §7.5 (`REQ-P70-GATE-02`, `REQ-P70-SCUX-05`)
- **Acceptance Criteria:**
  - Suppresses `MiniPlayerHost` cleanly via `trackDetailInlinePlayerMountedProvider` on mount/dispose.
  - Strict `ViewerRole.owner` gate hides `UtilityToolDock`, `StemSeparationLab`, `TrackLivingBiomePreviewCard`, `track_open_mixer_btn` (`StemMixerDeck` / `List in Beatstore`), `track_detail_open_mastering_btn`, and `PromptAttributionCard` from visitors.
  - Mounts `ThreadedCommentsSection` + sticky `StudioReactionComposerBar` (`EP-P69-THREADED-COMMENTS`) in place of legacy `CommentsSection`.
  - Zero stock `Icons.*` and zero raw emojis in `track_detail_view.dart`.

### [x] Task 70.2.4 — Pass 1 Verification Suite & Legacy Track Test Realignment
- **Target Files:**
  - `apps/vhunambi_client/test/features/track/phase70_song_cockpit_and_glass_test.dart` (NEW)
  - `apps/vhunambi_client/test/features/track/track_detail_view_test.dart` (REALIGN assertions for role-gating & threaded comments while preserving owner-mode assertions)
  - `apps/vhunambi_client/test/features/track/track_detail_tip_split_integration_test.dart` (VERIFY green)
- **Pass 1 Gate Commands:**
  ```powershell
  cd c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_client
  flutter analyze
  flutter test --timeout=60s test/features/track/ test/features/player/widgets/mini_player_host_test.dart test/features/player/phase33_adaptive_mini_player_test.dart
  ```

---

## 4. Overhaul Pass 2 — Milestone `M70.3`: Facebook-Benchmark Public Visitor Creator Profile (`ArtistProfileView`)

### [x] Task 70.3.1 — High-Contrast Glass `ProfileBannerHeader` & `[ ••• ]` Overflow Sheet
- **Target File:** `apps/vhunambi_client/lib/features/profile/presentation/widgets/profile_banner_header.dart`
- **Design Reference:** `design.md` §8 (`REQ-P70-PROF-01..03`)
- **Acceptance Criteria:**
  - `'Following'` button uses `AppColors.surfaceSecondaryOf(context)` + `AppColors.textPrimaryOf(context)` + specular border (high contrast in Light & Dark modes).
  - Replaces standalone Share/Flag buttons with `[ ••• ]` (`Key('visitor_profile_overflow_btn')`) opening Share / Copy Handle / Report bottom sheet.
  - Zero stock `Icons.*` remain in `profile_banner_header.dart`.

### [x] Task 70.3.2 — Dynamic Creator Projections & De-Emojified Leaderboard/Models
- **Target Files:**
  - `apps/vhunambi_client/lib/features/profile/presentation/providers/profile_providers.dart`
  - `apps/vhunambi_client/lib/features/profile/presentation/widgets/top_supporters_leaderboard.dart`
  - `apps/vhunambi_client/lib/features/profile/domain/models/profile_models.dart`
- **Design Reference:** `design.md` §9 (`REQ-P70-PTAB-02..03`)
- **Acceptance Criteria:**
  - Adds `creatorCatalogTracksProvider` and `creatorKineticPostsProvider` resolving real creator tracks & Kinetic Posts by canonical creator ID / handle.
  - Removes raw medal/coin/bolt emojis from `SupporterEntity.rankBadge`, `TipRecordEntity.amountLabel`, and `TopSupportersLeaderboard` (`PhosphorIconsFill.medal` + `AppIcons.trophy`).

### [x] Task 70.3.3 — 5-Tab `ArtistProfileView` Overhaul & Privacy Hardening
- **Target File:** `apps/vhunambi_client/lib/features/profile/presentation/views/artist_profile_view.dart`
- **Design Reference:** `design.md` §10 (`REQ-P70-PROF-02..03`, `REQ-P70-PTAB-01..03`, `REQ-P70-MINI-02`)
- **Acceptance Criteria:**
  - Increments/decrements `pushedFullScreenOverlayCountProvider` safely on mount/dispose.
  - Removes blocking `LoadingOverlay` on follow toggles and removes `ProfileStatsGrid` (`Day Streak`), `ArtistVoiceShowcaseCard`, and `CreatorDnaProfileCard`.
  - Renders `VhunambiAmbientMeshBackdrop` + `VhunambiGlassSurface` inline stats strip (`Key('visitor_profile_inline_stats')`).
  - Defaults `DefaultTabController(length: 5, initialIndex: 0)` to `Overview`, with `Songs`, `Posts & Reels` (opening `KineticPostFocusView` `EP-P69-KPOST-FOCUS-ROUTE`), `Beats`, and `About`.
  - Zero hardcoded `'seed-01'`, `'Ndo Mufuna Matibe'`, `'Fifi'`, zero stock `Icons.*`, zero raw emojis.

---

## 5. Overhaul Pass 2 — Milestone `M70.4`: Wire `EP-P58-MKT-VERIFY-PRODUCER`, Backend `moodId` Parity & Full Verification

### [x] Task 70.4.1 — Wire `EP-P58-MKT-VERIFY-PRODUCER` (`GET /api/marketplace/producers/:producerId/beats`)
- **Target Files:**
  - `apps/vhunambi_client/lib/features/marketplace/domain/repositories/i_marketplace_repository.dart`
  - `apps/vhunambi_client/lib/features/marketplace/data/repositories/http_marketplace_repository.dart`
  - `apps/vhunambi_client/lib/features/marketplace/presentation/providers/marketplace_providers.dart`
  - `apps/vhunambi_client/lib/features/profile/presentation/views/artist_profile_view.dart` (Tab 3 `Beats` watches `producerBeatsFamilyProvider(profile.id)`)
- **Design Reference:** `design.md` §11 (`REQ-P70-API-01`)
- **Acceptance Criteria:**
  - `HttpMarketplaceRepository.getProducerBeats(producerId)` calls `GET $_baseUrl/producers/$producerId/beats` with graceful offline/test fallback.
  - `producerBeatsFamilyProvider` merges remote producer beats with local `creatorBeatsFamilyProvider`.

### [x] Task 70.4.2 — Supabase Migration & Dual-Engine Backend `moodId` / Metadata Parity
- **Target Files:**
  - `supabase/migrations/20261119000001_phase70_track_mood_and_metadata.sql` (NEW)
  - `apps/vhunambi_api/src/utils/mood_taxonomy.ts` (NEW)
  - `apps/vhunambi_api/src/db/vhunambi_db.ts` (ADD `mood_id`, `description`, `allow_open_stems_remix` parity)
  - `apps/vhunambi_api/src/db/edge_persistence_bridge.ts` (MIRROR `moodId`, `description`, `allowOpenStemsRemix` parity)
  - `apps/vhunambi_api/src/routes/explore_routes.ts` (SUPPORT canonical `mood` / `moodId` filtering on `GET /api/explore/tracks`)
- **Design Reference:** `design.md` §12 (`REQ-P70-API-02`)
- **Acceptance Criteria:**
  - `npx tsc --noEmit` exits `0`.
  - Both SQLite (`VhunambiDb`) and `EdgeIsolateDatabaseEngine` persist and return canonical `moodId`, `description`, and `allowOpenStemsRemix`.

### [x] Task 70.4.3 — Pass 2 Verification Suite, Legacy Profile Test Realignment & Memory SLEEP Consolidation
- **Target Files:**
  - `apps/vhunambi_client/test/features/profile/phase70_visitor_profile_and_producer_beats_test.dart` (NEW)
  - `apps/vhunambi_client/test/features/profile/artist_profile_view_test.dart` (REALIGN for 5-tab Facebook benchmark & removed `LoadingOverlay`/private cards)
  - `apps/vhunambi_client/test/features/profile/artist_profile_tabs_test.dart` (REALIGN for `Overview` | `Songs` | `Posts & Reels` | `Beats` | `About`)
  - `apps/vhunambi_client/test/features/profile/phase30_creator_profile_convergence_test.dart` (VERIFY green)
  - `apps/vhunambi_api/test/phase70_mood_and_producer_beats.test.ts` (NEW)
  - `docs/phases/phase_70_song_cockpit_and_visitor_profile_glass_overhaul/memory.md` (UPDATE `"status": "completed"` ONLY after all gates pass)
- **Final Stage 4 Verification Commands:**
  ```powershell
  cd c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_client
  flutter analyze
  flutter test --timeout=60s test/features/track/ test/features/profile/ test/features/player/widgets/mini_player_host_test.dart test/features/player/phase33_adaptive_mini_player_test.dart

  cd c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_api
  npx tsc --noEmit
  npm test

  cd c:\Users\Ndugelo\VHUNAMBI\monorepo
  node .agents/skills/vhunambi-memory/scripts/consolidate_memory.mjs
  ```

---

## 6. Stage 4 Anti-Trap Verification Checklist

- [x] **Zero Cross-Pass Breakage:** Pass 1 (`M70.1`–`M70.2`) verified with `flutter analyze` + tests before Pass 2 begins.
- [x] **Zero White-on-White Light Mode Defects:** Both `TrackActionsBar` (`track_like_pill`) and `ProfileBannerHeader` (`profile_follow_btn` when `'Following'`) verified under `ThemeData.light()`.
- [x] **Zero Creator IP Leakage:** Visitor opening `@lerato_prod`'s track never sees `StemSeparationLab`, `StemMixerDeck` / `'List in Beatstore'`, `Master Track`, raw `PromptAttributionCard`, or *"owned by you"*.
- [x] **Zero Private Studio Leakage on Visitor Profile:** `ArtistProfileView` never mounts `ArtistVoiceShowcaseCard`, `CreatorDnaProfileCard`, or `Day Streak`.
- [x] **Zero Stock `Icons.*` & Zero Raw Emojis (`STD-UIUX-001`):** Verified across all touched files in `features/track/` and `features/profile/`.
- [x] **60 FPS Blur Budget Honored:** `VhunambiGlassSurface` defaults to `enableLiveBlur: false`; `VhunambiAmbientMeshBackdrop` wrapped in `RepaintBoundary`.
- [x] **Connectome Promotion Verified:** `EP-P58-MKT-VERIFY-PRODUCER` promoted from `OPEN` to `CONNECTED_EXTENSIBLE` after `consolidate_memory.mjs` runs post-verification.
