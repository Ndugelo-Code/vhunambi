# Phase 70 Functional & Non-Functional Requirements Specification

- **Document ID:** `VHUNAMBI-SPEC-P70-REQUIREMENTS-V1`
- **Phase:** `Phase 70` (`phase_70_song_cockpit_and_visitor_profile_glass_overhaul`)
- **Upstream Blueprint:** [blueprint.md](./blueprint.md)
- **Conventions:** EARS (`WHEN`, `WHILE`, `IF ... THEN`, `WHERE`) + RFC-2119 (`SHALL`, `MUST`, `SHALL NOT`).

---

## 1. Document Scope & Naming Standards

This specification defines every verifiable behavioral, visual, privacy, performance, and wire-schema requirement across **Overhaul Pass 1 (`M70.1`–`M70.2`)** and **Overhaul Pass 2 (`M70.3`–`M70.4`)**.

- **Package Root:** `package:vhunambi_client/...`
- **Iconography Standard (`STD-UIUX-001`):** `PhosphorIcon(PhosphorIconsRegular.* / PhosphorIconsFill.* / PhosphorIconsBold.*)` or `AppIcons.*`. Zero stock Material `Icons.*` and zero raw Unicode emojis in UI widgets or badges.
- **Dual-Theme Standard:** Every background, border, icon, and text foreground MUST adapt dynamically to `Theme.of(context).brightness` via `AppColors.*Of(context)` or `VhunambiGlassSurface` so Light Mode ("Warm African Daylight") and Dark Mode ("Obsidian Studio") both meet WCAG AA `>= 4.5:1` contrast.

---

## 2. Pass 1 Core Primitives Requirements (`M70.1`)

### 2.1 Glass Surface & Ambient Mesh (`REQ-P70-GLASS-*`)
- **`REQ-P70-GLASS-01` (Dual-Theme Frosted Surface):** `VhunambiGlassSurface` (`Key` pass-through supported) SHALL render translucent linear gradients and `1.0px` specular borders tuned for `Brightness.light` (`#FFFFFF` @ `0.78` -> `#FAF8F5` @ `0.62`, border `#DFDBD0` + top `#FFFFFF` highlight) and `Brightness.dark` (`#1B1B22` @ `0.74` -> `#141418` @ `0.58`, border `#2D2D38` + top `#FFFFFF` @ `0.12`).
- **`REQ-P70-GLASS-02` (60 FPS Android Blur Guardrail):** `VhunambiGlassSurface` SHALL default to `enableLiveBlur = false` so scrolling lists and grids incur zero `BackdropFilter` offscreen render-target allocations. WHERE `enableLiveBlur == true`, blur sigma SHALL be clamped to `<= 16.0` and enclosed inside `RepaintBoundary` + `ClipRRect`.
- **`REQ-P70-GLASS-03` (Ambient Mesh Backdrop):** `VhunambiAmbientMeshBackdrop` SHALL paint subtle genre/brand radial gradient orbs over `AppColors.surfaceCanvasOf(context)` inside a `RepaintBoundary` so vertical scroll events never trigger shader re-rasterization.

### 2.2 Canonical `VhunambiMood` Registry (`REQ-P70-MOOD-*`)
- **`REQ-P70-MOOD-01` (6-Mood Wire Taxonomy):** `VhunambiMood` SHALL define exactly six canonical wire IDs: `'uplifting'`, `'soulful'`, `'energetic'`, `'chill'`, `'hypnotic'`, and `'romantic'`, each carrying immutable `moodId`, `label`, `icon` (`IconData` from `PhosphorIconsFill`), and `accentColor`.
- **`REQ-P70-MOOD-02` (Lossless Legacy Normalization):** `VhunambiMood.normalize(String? raw)` SHALL deterministically map all legacy strings across Studio, Explore, Design Enums, and `edge_persistence_bridge.ts` (`'Joyful'`, `'Vibrant'` -> `uplifting`; `'Soulful & Nostalgic'`, `'Nostalgic'`, `'Melancholic'`, `'Warm'` -> `soulful`; `'Party'`, `'Electrifying'` -> `energetic`; `'Peaceful'`, `'Calm'` -> `chill`; `'Deep'`, `'Dark'`, `'Atmospheric'` -> `hypnotic`; `'Romantic'` -> `romantic`; unknown/null -> `uplifting`).
- **`REQ-P70-MOOD-03` (Backward Compatibility with `enum Mood`):** `VhunambiMood` SHALL expose `fromLegacyMood(Mood)` and `toLegacyMood()` so existing onboarding widgets (`MoodColorChip`) remain 100% compilable without breaking imports.

### 2.3 Deterministic `ViewerRole` Policy (`REQ-P70-ROLE-*`)
- **`REQ-P70-ROLE-01` (Canonical Owner Resolution):** `resolveViewerRole({required String? ownerCreatorId, String? ownerHandle, required String activeCreatorId, String? activeHandle})` SHALL canonicalize identifiers via `EP-P61-IDENTITY-UTILS` (`canonicalizeCreatorId` / `extractRawCreatorId`) and return `ViewerRole.owner` ONLY when canonical creator IDs or non-empty normalized handles match.
- **`REQ-P70-ROLE-02` (Fail-Closed Non-Owner Protection):** IF `ownerCreatorId` belongs to another creator (e.g., `'lerato_prod'`, `'creator_lerato'`, `'fifi'`, `'creator_makhadzi'`) while `activeCreatorId` is `'creator_cern'` or `'creator_ndugelo'`, THEN `resolveViewerRole` SHALL return `ViewerRole.visitor`. Blank or missing `ownerCreatorId` SHALL fail closed to `ViewerRole.visitor`.

### 2.4 `MiniPlayerHost` Pushed-Route Suppression (`REQ-P70-MINI-*`)
- **`REQ-P70-MINI-01` (Track Detail Inline Suppression):** WHILE `TrackDetailView` is mounted (and displays its inline `WaveformScrubber`), `trackDetailInlinePlayerMountedProvider` SHALL increment (> 0) and `MiniPlayerHost` SHALL return `SizedBox.shrink()` to prevent floating playback overlap.
- **`REQ-P70-MINI-02` (Pushed Full-Screen Profile Clearance):** WHILE `ArtistProfileView` is mounted on a pushed route without `RootShell`'s `56dp` bottom navigation bar, `pushedFullScreenOverlayCountProvider` SHALL increment (> 0) and `MiniPlayerHost` SHALL either dock cleanly above `bottomSafeArea + 12dp` (never mid-screen at `56dp` phantom offset) or suppress while full-screen modal/profile overlays request clearance, while keeping `mini_player_host_test.dart` and `phase33_adaptive_mini_player_test.dart` 100% green.

---

## 3. Pass 1 Role-Aware Song Cockpit Requirements (`M70.2`)

### 3.1 Extended `TrackDetailEntity` & Hydration (`REQ-P70-TRACK-*`)
- **`REQ-P70-TRACK-01` (Structured Metadata Fields):** `TrackDetailEntity` SHALL include `coverUrl` (`String?`), `description` (`String`), `createdAt` (`DateTime?`), `bpm` (`int`), `musicalKey` (`String`), `moodId` (`String`), and `allowOpenStemsRemix` (`bool`, default `false`), all preserved through `copyWith`.
- **`REQ-P70-TRACK-02` (Multi-Source Hydration):** `TrackDetailNotifier._lookupInitialTrack` SHALL hydrate `coverUrl`, `description`, `bpm`, `musicalKey`, `moodId` (normalized via `VhunambiMood.normalize`), and `createdAt` from `libraryTracksProvider`, `exploreTracksProvider`, and `seededTrackDetails`.

### 3.2 Role-Gated Sovereignty Surfaces (`REQ-P70-GATE-*`)
- **`REQ-P70-GATE-01` (Provenance vs. Ownership Deed):**
  - WHERE `viewerRole == ViewerRole.visitor`, `TrackHeroSection` SHALL render `Key('track_visitor_provenance_pill')` displaying `"Created by @<handle> · All Rights Reserved"` (or `"Created by @<handle> · Open Stems Allowed"` when `allowOpenStemsRemix == true`) and SHALL NOT render `Key('track_owner_deed_card')`, `"Personal Use"`, or `"owned by you"`.
  - WHERE `viewerRole == ViewerRole.owner`, `TrackHeroSection` SHALL render `Key('track_owner_deed_card')` with the creator's license badge and ownership confirmation.
- **`REQ-P70-GATE-02` (Creator Studio Tool Isolation):**
  - WHERE `viewerRole == ViewerRole.visitor`, `TrackDetailView` SHALL NOT mount `StemSeparationLab`, `TrackLivingBiomePreviewCard`, `Key('track_open_mixer_btn')` (`StemMixerDeck` / `'List in Beatstore'`), `Key('track_detail_open_mastering_btn')`, `PromptAttributionCard`, or owner-only `UtilityToolDock` buttons (`Download`, `Export Reel`, `Variation`).
  - WHERE `viewerRole == ViewerRole.visitor` AND `track.allowOpenStemsRemix == true`, `TrackDetailView` SHALL render a dedicated `Key('track_visitor_open_stems_remix_btn')` pill permitting authorized remix entry.
  - WHERE `viewerRole == ViewerRole.owner`, `TrackDetailView` SHALL mount the complete Studio Cockpit suite (`UtilityToolDock`, `StemSeparationLab`, `TrackLivingBiomePreviewCard`, `Key('track_open_mixer_btn')`, `Key('track_detail_open_mastering_btn')`, `PromptAttributionCard`).

### 3.3 Song Cockpit Visuals, Light-Mode Contrast & Threaded Discussion (`REQ-P70-SCUX-*`)
- **`REQ-P70-SCUX-01` (Unified Artwork):** `TrackHeroSection` and `MoreLikeThisShelf` SHALL render `VhunambiTrackArtwork` (`EP-P68-TRACK-ARTWORK`) using `track.coverUrl`, `track.genre`, and `track.id`.
- **`REQ-P70-SCUX-02` (Light-Mode Safe Actions Bar):** `TrackActionsBar` (`Key('track_like_pill')`) SHALL render inside `VhunambiGlassSurface` using `AppColors.textPrimaryOf(context)` (and `AppColors.brandPrimary` when active) — NEVER hardcoded `Colors.white` on `AppColors.surfaceElevated`.
- **`REQ-P70-SCUX-03` (Compact Horizontal Phosphor Reaction Rail):** `EmojiReactionDeck` SHALL render a single-row horizontally scrollable strip (`SizedBox(height: 40)`) of frosted glass reaction chips using `PhosphorIcon` glyphs and zero raw Unicode emojis.
- **`REQ-P70-SCUX-04` (Song Description & Sonic Telemetry Glass Card):** `TrackDetailView` SHALL render `Key('track_sonic_telemetry_card')` inside `VhunambiGlassSurface` showing `Song Description`, `Genre`, `BPM`, `Musical Key`, `Language`, `Duration`, `Released` date, and an interactive `Key('track_mood_chip')` pill powered by `VhunambiMood.normalize(track.moodId)`.
- **`REQ-P70-SCUX-05` (Threaded Discussion Integration):** `TrackDetailView` SHALL mount `ThreadedCommentsSection` + sticky `StudioReactionComposerBar` (`EP-P69-THREADED-COMMENTS`) keyed by `track.id` with `contentCreatorId: track.creatorId` and `contentCreatorHandle: track.creatorHandle`, replacing legacy `CommentsSection`.
- **`REQ-P70-SCUX-06` (Zero Stock Icons / Zero Raw Emojis in `features/track/`):** Every file in `features/track/` touched in Pass 1 SHALL contain zero stock `Icons.*` and zero raw Unicode emojis (`STD-UIUX-001`).

---

## 4. Pass 2 Public Visitor Creator Profile Requirements (`M70.3`)

### 4.1 Glass Header, Contrast & Instant Optimistic Follow (`REQ-P70-PROF-*`)
- **`REQ-P70-PROF-01` (High-Contrast Following Pill):** `ProfileBannerHeader` (`Key('profile_follow_btn')`) SHALL render `'Follow'` with `AppColors.brandPrimary` fill + `AppColors.brandContrast` text, and `'Following'` with `AppColors.surfaceSecondaryOf(context)` fill + `AppColors.borderActive` border + `AppColors.textPrimaryOf(context)` text so Light Mode and Dark Mode both maintain crisp readability.
- **`REQ-P70-PROF-02` (Zero Blocking Modal on Follow):** Tapping `Follow` / `Following` in `ArtistProfileView` SHALL NOT display a full-screen `LoadingOverlay`. State transitions SHALL apply immediately via `ProfileOperationNotifier.toggleFollow()` optimistic state, reverting only on error with a non-blocking `SnackBar`.
- **`REQ-P70-PROF-03` (Inline Social Proof & Overflow Menu):** `ArtistProfileView` SHALL replace the 5-card `ProfileStatsGrid` (and hide private `Day Streak`) with a single compact inline social proof strip (`Key('visitor_profile_inline_stats')` displaying `Followers · Monthly Listeners · Songs · Plays`). Standalone Share & Report flag icon buttons SHALL be consolidated into a single `[ ••• ]` glass button (`Key('visitor_profile_overflow_btn')`) opening a bottom sheet with `Share Profile`, `Copy @handle`, and `Report Creator`.

### 4.2 Privacy Hardening & 5-Tab Facebook-Benchmark Structure (`REQ-P70-PTAB-*`)
- **`REQ-P70-PTAB-01` (Private Studio Scrub):** `ArtistProfileView` SHALL NOT render `ArtistVoiceShowcaseCard` (`Zero-Shot AI Clone`) or `CreatorDnaProfileCard` (`Open 3D DNA Lab`).
- **`REQ-P70-PTAB-02` (5 Visitor Tabs, Default Index `0` = `Overview`):** `ArtistProfileView` SHALL configure `DefaultTabController(length: 5, initialIndex: 0)` with tabs:
  - `0: Overview` (`Key('visitor_tab_overview')`) — Bio, Featured Anthem, Top Songs (`VhunambiTrackArtwork`), Latest Kinetic Post preview (navigating to `KineticPostFocusView` `EP-P69-KPOST-FOCUS-ROUTE`), and public Genre & Mood Affinity pills.
  - `1: Songs` (`Key('visitor_tab_songs')`) — Live creator discography dynamically projected from `exploreTracksProvider` + `libraryTracksProvider` matching canonical `creatorId` / handle (zero hardcoded `'seed-01'`, `'Ndo Mufuna Matibe'`, or `'Fifi'`).
  - `2: Posts & Reels` (`Key('visitor_tab_posts_reels')`) — Creator's Kinetic Posts (opening `KineticPostFocusView`) and Published Clips with visitor-appropriate empty copy (`"@<handle> hasn't shared any posts or reels yet."`).
  - `3: Beats` (`Key('visitor_tab_beats')`) — Live producer beats powered by `EP-P58-MKT-VERIFY-PRODUCER` + de-emojified `TopSupportersLeaderboard`.
  - `4: About` (`Key('visitor_tab_about')`) — Creator archetype, primary genres, languages, heritage/region, verification badge, and tipping availability.
- **`REQ-P70-PTAB-03` (Zero Stock Icons / Zero Raw Emojis in Visitor Profile):** `artist_profile_view.dart`, `profile_banner_header.dart`, `top_supporters_leaderboard.dart`, and visitor getters in `profile_models.dart` SHALL contain zero stock `Icons.*` and zero raw medal/coin/bolt Unicode emojis.

---

## 5. Pass 2 Backend & Producer Beats Wiring Requirements (`M70.4`)

- **`REQ-P70-API-01` (Consume `EP-P58-MKT-VERIFY-PRODUCER`):** `IMarketplaceRepository` and `HttpMarketplaceRepository` SHALL implement `Future<List<BeatListingEntity>> getProducerBeats(String producerId)` calling `GET /api/marketplace/producers/:producerId/beats` (`marketplace_routes.ts#L202-L206`), with graceful fallback to local cached/seeded beats when offline or in test mode without custom `Dio`.
- **`REQ-P70-API-02` (Supabase & SQLite Track Metadata Parity):** Migration `supabase/migrations/20261119000001_phase70_track_mood_and_metadata.sql` SHALL idempotently add `mood_id TEXT NOT NULL DEFAULT 'uplifting'`, `description TEXT NOT NULL DEFAULT ''`, and `allow_open_stems_remix BOOLEAN NOT NULL DEFAULT false` to `public.explore_tracks` (with index on `mood_id`), mirrored in `vhunambi_db.ts`, `edge_persistence_bridge.ts`, and `explore_routes.ts` via canonical `normalizeVhunambiMoodId`.

---

## 6. Non-Functional Requirements (`REQ-P70-NFR-*`)

- **`REQ-P70-NFR-01` (60 FPS Android Frame Budget):** Scrolling `TrackDetailView` and `ArtistProfileView` SHALL keep frame rasterization `<= 16.6ms` by enforcing `enableLiveBlur: false` on all repeating list/grid cards and wrapping `VhunambiAmbientMeshBackdrop` in `RepaintBoundary`.
- **`REQ-P70-NFR-02` (Zero Cross-Pass Breakage):** Pass 1 (`M70.1`–`M70.2`) MUST compile and pass `flutter analyze` + Pass 1 tests cleanly before any Pass 2 file is modified.
- **`REQ-P70-NFR-03` (44x44dp Touch Targets):** Every interactive button, overflow icon, reaction chip, and tab target SHALL satisfy minimum `44x44dp` tap geometry.
- **`REQ-P70-NFR-04` (Bounded Widget Tests):** All new Flutter widget tests MUST complete within `--timeout=60s` using bounded `pump` loops when animated widgets are mounted (never hanging `pumpAndSettle()`).

---

## 7. Requirement-to-Test Traceability Matrix

| Requirement ID | Target File / Class | Verification Test Case |
|---|---|---|
| `REQ-P70-GLASS-01..03` | `VhunambiGlassSurface`, `VhunambiAmbientMeshBackdrop` | `phase70_song_cockpit_and_glass_test.dart`: light/dark token + zero default `BackdropFilter` |
| `REQ-P70-MOOD-01..03` | `VhunambiMood` | `phase70_song_cockpit_and_glass_test.dart`: normalizes all 16 legacy mood strings & `Mood` enum |
| `REQ-P70-ROLE-01..02` | `resolveViewerRole` | `phase70_song_cockpit_and_glass_test.dart`: `@lerato` vs `@cern` -> `visitor`; owner match -> `owner` |
| `REQ-P70-MINI-01..02` | `MiniPlayerHost`, `navigation_providers.dart` | `phase70_song_cockpit_and_glass_test.dart` + `mini_player_host_test.dart` + `phase33_adaptive_mini_player_test.dart` |
| `REQ-P70-GATE-01..02` | `TrackDetailView`, `TrackHeroSection` | `phase70_song_cockpit_and_glass_test.dart`: visitor hides Stem/Mixer/Master/Prompt/Deed; owner shows all |
| `REQ-P70-SCUX-01..06` | `TrackActionsBar`, `EmojiReactionDeck`, `TrackDetailView` | `phase70_song_cockpit_and_glass_test.dart`: light-mode non-white contrast, telemetry card, threaded comments |
| `REQ-P70-PROF-01..03` | `ProfileBannerHeader`, `ArtistProfileView` | `phase70_visitor_profile_and_producer_beats_test.dart`: light contrast `Following`, zero `LoadingOverlay`, `[ ••• ]` sheet |
| `REQ-P70-PTAB-01..03` | `ArtistProfileView`, `TopSupportersLeaderboard` | `phase70_visitor_profile_and_producer_beats_test.dart`: default `Overview`, no Voice Clone/DNA Lab, live songs & posts |
| `REQ-P70-API-01..02` | `HttpMarketplaceRepository`, `mood_taxonomy.ts`, `explore_routes.ts` | `phase70_visitor_profile_and_producer_beats_test.dart` + `apps/vhunambi_api/test/phase70_mood_and_producer_beats.test.ts` |
