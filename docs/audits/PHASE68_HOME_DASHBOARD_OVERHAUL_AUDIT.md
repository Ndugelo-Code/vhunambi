# Phase 68: Home Dashboard Main-Room Utility Overhaul & Zania Explore Benchmark — Forensic Audit Report

**Document ID:** `AUDIT-HOME-068`  
**Date:** 2026-11-17  
**Branch:** `fix/studio-cockpit-bugs-vh001-vh006`  
**Audit Scope:** Read-only static & UI/UX forensic audit across `apps/vhunambi_client/lib/features/home/`, `apps/vhunambi_client/lib/features/player/`, `apps/vhunambi_client/lib/features/social/presentation/widgets/trending_reels_shelf.dart`, `apps/vhunambi_client/lib/core/`, and benchmark comparison against `C:\Users\Ndugelo\Zania-Explore-v2.5\Zania-Explore` (`app/globals.css`, `components/dashboard/`, `components/music/`, `hooks/`, `lib/music/`).  
**Related Specs & Audits:**  
- [`docs/audits/PHASE67_NOTIFICATIONS_CENTER_OVERHAUL_AUDIT.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/audits/PHASE67_NOTIFICATIONS_CENTER_OVERHAUL_AUDIT.md)  
- [`docs/phases/phase_67_notifications_center_two_pass_overhaul/tasks.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_67_notifications_center_two_pass_overhaul/tasks.md)  
- [`C:\Users\Ndugelo\Zania-Explore-v2.5\Zania-Explore\.kiro\specs\zania-music-platform-overhaul\design.md`](file:///C:/Users/Ndugelo/Zania-Explore-v2.5/Zania-Explore/.kiro/specs/zania-music-platform-overhaul/design.md)

---

## 1. Executive Summary & Headline Verdict

Forensic inspection of Vhunambi's current [`HomeDashboardView`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/home/presentation/views/home_dashboard_view.dart) alongside the dark-mode (`video_1.mp4`) and light-mode (`video_2.mp4`) physical recordings and Zania Explore's production web surfaces (`video_3.mp4`–`video_5.mp4`) confirms **why Vhunambi's landing tab reads like an oversized prototype wireframe rather than a focused Main-Room Music & Studio Utility**:

1. **~650dp of Vertical Above-the-Fold & Mid-Feed Bloat (`H-01`, `H-02`, `H-03`):** Over 450dp is consumed by redundant Studio tab switchers (an oversized ~190dp fake `"What are you feeling today?"` prompt box + a duplicate `AI Studio` tile inside the 2×3 tool grid), followed by ~260dp of `TrendingReelsShelf()` (`video_1.mp4 00:46–01:05`)—even though Kinetic Reels belong exclusively on Tab 1 (`Explore`).
2. **Flat Saturated Color Slabs & Cover-Art Void (`H-04`, `H-05`):** Even though Vhunambi already bundles 10 studio artwork assets inside [`apps/vhunambi_client/assets/artwork/`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/core/constants/app_assets.dart#L43-L67), every card in `Jump Back In`, `Trending in Your Genres`, `TrendingReelsShelf`, and `Daily Rhythm Spotlight` omits artwork completely—rendering flat `#D97706`/`#F59E0B` orange squares or harsh full-bleed `#FF6B00` / `#312E81`–`#4F46E5` royal-blue slabs.
3. **Disconnected Playback & Unscrubbable `Jump Back In` Tile (`H-06`):** `Jump Back In` (`home_dashboard_view.dart#L1062-L1161`) is a static row with a single play button that spawns an auto-morphing floating `MiniPlayerHost` pill (`main.dart#L293-L318`) overlapping scrolled content (`video_2.mp4 00:00–00:07`), lacking Zania Explore's embedded artwork-tinted Now Playing deck (`progress bar + ⏮ ⏸ ⏭ + ↗ expand`).
4. **Live Monthly Song Allowance Blindspot (`H-07`):** Backend Phase 67 `M67.4` already exposes `GET /api/wallet/allowance` (returning `{ planTier, freeMonthlySongsLimit: 10, freeMonthlySongsUsed, freeMonthlySongsRemaining, cycleResetAt }`), yet **zero client code** in `apps/vhunambi_client/lib/` fetches it; Home shows a generic static promo ad (`Up to 2,000 songs/mo`) instead of real creator quota utility (`10 / 10 Free Songs Left`).
5. **Theme-Adaptation & `STD-UIUX-001` Regressions (`H-08`, `H-09`):** `HomeDashboardView` uses static `AppColors.surfaceCanvas` / `AppColors.surfaceElevated` getters rather than contextual `*Of(context)` adapters, mixes stock `Icon(Icons.*)` / `Icon(icon)`, hardcodes `Color(0xFF...)` hexes, renders raw emojis (`'✨'`, `'☀️'`, `'🌙'`, `'🧬'`), and retains a legacy `'Ndo Mufuna Matibe'` by `'Fifi'` fallback at [`home_dashboard_view.dart#L155-L163`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/home/presentation/views/home_dashboard_view.dart#L155-L163).

---

### 1.1 Executive Root-Cause & Severity Matrix

| ID | Sev | Surface / Symptom (`video_1` & `video_2`) | Primary Root Cause | Exact File & Line Evidence |
| :--- | :---: | :--- | :--- | :--- |
| **`H-01`** | `P1` | **~190dp Fake Prompt Box (`What are you feeling today?`)** wastes top viewport | Oversized `TextField` + `'Create ✨'` button + chips merely write `studioFormProvider.updatePrompt(text)` and switch to Tab 2 (`Studio`) | [`home_dashboard_view.dart#L68-L75`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/home/presentation/views/home_dashboard_view.dart#L68-L75), [`#L448-L561`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/home/presentation/views/home_dashboard_view.dart#L448-L561) |
| **`H-02`** | `P1` | **Duplicate Studio Entry (`AI Studio` tile inside 2×3 Hub)** | `home_hub_ai_studio` invokes the exact same `widget.onNavigateToStudio?.call()` callback as the prompt card while occupying a 6-tile mobile grid | [`home_dashboard_view.dart#L885-L1008`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/home/presentation/views/home_dashboard_view.dart#L885-L1008) |
| **`H-03`** | `P1` | **Out-of-Place `Kinetic Reels` Shelf on Home (~260dp orange blocks)** | `TrendingReelsShelf()` is mounted directly inside `HomeDashboardView`'s `CustomScrollView`, duplicating Tab 1 (`Explore`) | [`home_dashboard_view.dart#L632-L634`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/home/presentation/views/home_dashboard_view.dart#L632-L634), [`trending_reels_shelf.dart#L18-L73`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/social/presentation/widgets/trending_reels_shelf.dart#L18-L73) |
| **`H-04`** | `P1` | **Flat Orange Squares across `Jump Back In` & `Trending in Your Genres`** | `_seedTracks()` in `explore_providers.dart` and `_seedTracks()` in `library_providers.dart` omit `coverUrl`, and Home cards never resolve `assets/artwork/*` | [`home_dashboard_view.dart#L1076-L1090`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/home/presentation/views/home_dashboard_view.dart#L1076-L1090), [`#L1179-L1192`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/home/presentation/views/home_dashboard_view.dart#L1179-L1192), [`explore_providers.dart#L469-L550`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/explore/presentation/providers/explore_providers.dart#L469-L550) |
| **`H-05`** | `P1` | **Harsh Solid `#FF6B00` / `#312E81` `Daily Rhythm Spotlight` Slab** | Container fills 100% background with un-scrimmed `AppGradients.forGenre(spotlight.genre)` instead of dark atmospheric artwork + vignette | [`home_dashboard_view.dart#L645-L650`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/home/presentation/views/home_dashboard_view.dart#L645-L650), [`app_gradients.dart#L22-L110`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/core/theme/app_gradients.dart#L22-L110) |
| **`H-06`** | `P1` | **Static `Jump Back In` vs Floating Pill Content Overlap** | `Jump Back In` lacks inline scrubbable progress, prev/next transport, and expand button; scrolling `>40px` morphs `MiniPlayerHost` into a floating pill over content | [`home_dashboard_view.dart#L1062-L1161`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/home/presentation/views/home_dashboard_view.dart#L1062-L1161), [`main.dart#L293-L318`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/main.dart#L293-L318) |
| **`H-07`** | `P1` | **Missing Live Monthly Song Quota (`10 / 10`) Telemetry on Client** | Backend `GET /api/wallet/allowance` exists (`wallet_routes.ts#L31-L40`), but Flutter client has zero HTTP/Riverpod provider consuming it; Home shows static `Upgrade` ad | [`home_dashboard_view.dart#L798-L853`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/home/presentation/views/home_dashboard_view.dart#L798-L853), [`apps/vhunambi_api/src/routes/wallet_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/wallet_routes.ts) |
| **`H-08`** | `P2` | **Theme Desync & Legacy `Fifi` Fallback on Home** | Static `AppColors.surfaceCanvas` / `surfaceElevated` getters used instead of `*Of(context)` adapters; hardcoded fallback `Ndo Mufuna Matibe` by `Fifi` | [`home_dashboard_view.dart#L155-L163`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/home/presentation/views/home_dashboard_view.dart#L155-L163), [`#L179`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/home/presentation/views/home_dashboard_view.dart#L179) |
| **`H-09`** | `P2` | **`STD-UIUX-001` Violations (Raw Emojis, Stock Icons, Hexes, `<44dp` Targets)** | Raw `'✨'`/`'☀️'`/`'🌙'`/`'🧬'`, stock `Icon(icon)` & `Icon(Icons.close)`, hardcoded `0xFFEC4899`/`0xFF8B5CF6`/`0xFF10B981`/`0xFF3B82F6`, un-constrained `ActionChip` | [`home_dashboard_view.dart#L534`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/home/presentation/views/home_dashboard_view.dart#L534), [`#L899-L1038`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/home/presentation/views/home_dashboard_view.dart#L899-L1038), [`dna_insight_card.dart#L26-L73`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/creator_dna/presentation/widgets/dna_insight_card.dart#L26-L73) |

---

### 1.2 Spatial Comparison: Legacy Vhunambi Home vs. Target Main Room

```
┌───────────────────────────────────────────────┬──────────────────────────────────────────────────────┐
│ CURRENT HOME DASHBOARD (video_1 & video_2)    │ PHASE 68 MAIN-ROOM UTILITY (ZANIA EXPLORE STANDARD)  │
├───────────────────────────────────────────────┼──────────────────────────────────────────────────────┤
│ 1. Header: Avatar + Greeting✨ + 🔥3 + 🪙5235 │ 1. Refined Header: Avatar + Greeting + [10/10 Songs] │
│    (NotificationBellButton now wired in M67.5)│    + Coins + Streak + NotificationBellButton         │
│ 2. DnaInsightCard (🧬 emoji + Icons.close)     │ 2. Compact Telemetry Strip (DNA %, Free Songs Left,  │
│    + CrossModuleSynergyDeck (when gaps exist) │    Coins, Vault Tracks) — dense 1–2 row command grid │
│ 3. ~190dp Bloated Hero Prompt Card ("What are │ 3. Sleek Create-in-Studio Hero CTA + 4-Tool Studio   │
│    you feeling today?") -> switches to Tab 2  │    Utility Dock (Voice, Sketchpad, Stem Lab, Vault)  │
│ 4. ~195dp 6-Tile Tool Grid (includes duplicate│    — zero redundant "AI Studio" tab-switch duplicate │
│    AI Studio tile + stock Icon(icon) + hexes) │ 4. Embedded Artwork-Tinted Now-Playing / Resume Deck │
│ 5. ~80dp Static "Jump Back In" (flat orange   │    (cover art, scrubbable slider, ⏮ ▶ ⏭, ↗ cockpit) │
│    square) + floating pill overlap on scroll  │    [Replaces static Jump Back In on Home]            │
│ 6. ~260dp Kinetic Reels Shelf (empty orange   │ 5. REMOVED FROM HOME (Reels stay exclusively on Tab  │
│    9:16 cards) — out of place on Main Room    │    1 Explore where the social feed lives)            │
│ 7. Harsh solid #FF6B00/#4F46E5 Daily Rhythm   │ 6. Atmospheric Cover-Art Spotlight Carousel (dark    │
│    Spotlight + flat orange "Trending" squares │    vignettes over real artwork + BPM/Key + Load/Play)│
│ 8. Bottom static "Upgrade to Pro" ad banner   │ 7. Cover-Art "Curated Picks & Genres" Shelf + Live   │
│    disconnected from real 10-song free quota  │    Plan & Monthly Allowance Status Card              │
└───────────────────────────────────────────────┴──────────────────────────────────────────────────────┘
```

---

## 2. Pillar-by-Pillar Forensic Findings (`apps/vhunambi_client/lib/features/home/`)

### 2.1 File Inventory & Composition in `RootShell`

`HomeDashboardView` is mounted at index `0` inside `RootShell._buildPages()` ([`main.dart#L210-L220`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/main.dart#L210-L220)) with three tab-switch callbacks (`onNavigateToStudio`, `onNavigateToMarket`, `onNavigateToLibrary`). Notice `RootShellState._currentIndex` still initializes to `1` (`ExploreView`) at [`main.dart#L155`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/main.dart#L155).

Files inside `apps/vhunambi_client/lib/features/home/`:
- `domain/models/african_rhythm_matrix.dart` (156 lines) — 7-day indigenous rhythm schedule
- `domain/models/studio_synergy_context.dart` — telemetry-driven recommendation models
- `presentation/providers/cross_module_synergy_provider.dart` — reactive gap scanner
- `presentation/utils/african_greeting_resolver.dart` (122 lines) — localized greetings + raw emoji helper
- `presentation/views/home_dashboard_view.dart` (1,214 lines) — monolithic scrollable view
- `presentation/widgets/cross_module_synergy_deck.dart` (260 lines) — actionable telemetry fix cards
- `presentation/widgets/subscription_upgrade_modal.dart` (506 lines) — billing/coin pack bottom sheet

---

### 2.2 Pillar A — Layout Bloat, Redundant Studio Entry Points & Out-of-Place Reels (`H-01`..`H-03`)

Every above-the-fold Zone in [`home_dashboard_view.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/home/presentation/views/home_dashboard_view.dart) exhibits vertical bloat and duplicated routing:

1. **Fake Prompt Box (`#L448-L561`, ~190dp height):**
   - Renders `'What are you feeling today?'`, a `TextField` (`'Describe a vibe, story, or melody...'`), an `'Create ✨'` `ElevatedButton`, and 3 horizontal `ActionChip` presets (`_buildPresetChip`, `#L862-L878`).
   - Submitting or tapping `'Create ✨'` or any chip simply calls `_submitQuickPrompt` (`#L68-L75`), which updates `studioFormProvider` and calls `widget.onNavigateToStudio?.call()` (switching to Tab 2 `Studio`). Keeping an inline `TextField` on Home also forces soft keyboard transitions right before an `IndexedStack` tab jump.
2. **Redundant 6-Tile Tool Hub (`#L563-L577` & `#L881-L1060`, ~195dp height on 360dp):**
   - Tile 1 (`Key('home_hub_ai_studio')`, `#L887-L893`) invokes `widget.onNavigateToStudio?.call()`—100% redundant with a primary `Create` action.
   - The remaining 5 tools launch distinct high-value workflows:
     - `Voice Clone` (`home_hub_voice_clone`) → `VocalIdentityPickerSheet.show(context)`
     - `Sketchpad` (`home_hub_melody_sketchpad`) → `MelodySketchpadModal.show(context)`
     - `Stem Lab` (`home_hub_stem_master`) → `_openMastering(context, trackId: latestVaultTrack?.id, ...)`
     - `Beats Market` (`home_hub_beats_market`) → `widget.onNavigateToMarket?.call()`
     - `Asset Vault` (`home_hub_asset_vault`) → `widget.onNavigateToLibrary?.call()`
3. **Out-of-Place `TrendingReelsShelf()` (`#L632-L634`, ~260dp–290dp height):**
   - `TrendingReelsShelf` ([`trending_reels_shelf.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/social/presentation/widgets/trending_reels_shelf.dart#L18-L73)) renders filter chips, `+ Post Reel`, and tall 9:16 cards using flat `AppGradients.forGenre(clip.genre)` orange rectangles when `clip.coverUrl` is empty or offline.
   - Its primary tests (`explore_view_test.dart#L54`, `phase29_social_explore_test.dart#L162`, `trending_reels_shelf_test.dart`) already verify it inside `ExploreView`. Removing it from `HomeDashboardView` eliminates ~275dp of off-mission clutter while preserving it on `Explore`.

---

### 2.3 Pillar B — Cover-Art Void, Saturated Slabs & Theme Desync (`H-04`, `H-05`, `H-08`)

A critical paradox emerged during asset inspection: **Vhunambi already bundles 10 rich studio artworks inside [`apps/vhunambi_client/assets/artwork/`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/core/constants/app_assets.dart#L43-L67)**, yet **zero Home widgets use them**:

| Artwork Asset on Disk | Currently Registered in `AppAssets`? | Used in `HomeDashboardView`? |
| :--- | :---: | :---: |
| `assets/artwork/heritage_crate_cover.png` | Yes (`heritageCrateCover`) | **No** |
| `assets/artwork/splash_hero.png` (`Vhunambi_ Music, Feel, Escape.png`) | Yes (`splashHero`) | **No** |
| `assets/artwork/timbre_elder.png` | Yes (`timbreElder`) | **No** |
| `assets/artwork/timbre_poet.png` | Yes (`timbrePoet`) | **No** |
| `assets/artwork/timbre_crooner.png` | Yes (`timbreCrooner`) | **No** |
| `assets/artwork/timbre_cantor.png` | Yes (`timbreCantor`) | **No** |
| `assets/artwork/timbre_producer.png` | Yes (`timbreProducer`) | **No** |
| `assets/artwork/Vhunambi_ African Sunset Melodies.png` | Raw file (unregistered constant) | **No** |
| `assets/artwork/Vhunambi_ Five Voices, One Vision.png` | Raw file (unregistered constant) | **No** |

Meanwhile:
- All 6 seeded tracks in [`explore_providers.dart#L469-L550`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/explore/presentation/providers/explore_providers.dart#L469-L550) (`exp_track_001`–`exp_track_006`) and all 4 seeded vault tracks in [`library_providers.dart#L501-L556`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/library/presentation/providers/library_providers.dart#L501-L556) (`lib_track_001`–`lib_track_004`) leave `coverUrl` / `coverImageUrl` as `null`.
- Consequently, `_buildJumpBackInCard` (`#L1076-L1089`) and `_buildHorizontalTrackCard` (`#L1180-L1192`) fall back identically to `gradient: AppGradients.forGenre(track.genre)`—painting adjacent Amapiano tracks as identical solid orange boxes!
- Worse, `Daily Rhythm Spotlight` (`#L645-L650`) applies `gradient: AppGradients.forGenre(spotlight.genre)` across an entire wide banner with bright white text: Monday (`Amapiano`, `#D97706 → #F59E0B`) produces an overwhelming neon-orange slab in `video_1.mp4`, while Tuesday (`Gqom`, `#312E81 → #4F46E5`) produces a harsh royal-blue slab in `video_2.mp4`.
- **Theme Token Bug (`H-08`):** `home_dashboard_view.dart` reads static `AppColors.surfaceCanvas` (`L179`), `AppColors.surfaceElevated` (`L345`, `L457`, `L801`, `L1025`, `L1070`, `L1172`), `AppColors.surfaceSecondary` (`L240`, `L497`, `L868`), and `AppColors.textPrimary` / `textSecondary` instead of `AppColors.surfaceCanvasOf(context)` / `AppColors.surfaceElevatedOf(context)` / `AppColors.textPrimaryOf(context)` / `AppColors.textSecondaryOf(context)`.

---

### 2.4 Pillar C — Disconnected `Jump Back In` & Floating Pill Overlap (`H-06`)

1. `PlayerNotifier` (`player_provider.dart#L58-L83`) ALREADY exposes full reactive playback state (`currentTrack`, `isPlaying`, `position`, `duration`, `progressRatio`, `formattedPosition`, `formattedDuration`, `queue`, `seek()`, `skipNext()`, `skipPrevious()`, `togglePlayPause()`).
2. Yet `HomeDashboardView._buildJumpBackInCard` (`#L1062-L1161`) ignores all transport controls except `playTrack(track)` (`#L1155`)—it has no live progress bar, no scrub gesture, no previous/next controls, and no expand-to-cockpit (`ExpandedCockpitModal.show`) trigger.
3. Worse, once the user taps Play on `Jump Back In`, `MiniPlayerHost` (`mini_player_host.dart#L85-L147`) overlays above the feed, and [`main.dart#L293-L318`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/main.dart#L293-L318) automatically morphs `PlayerForm.bar` into the `160px` floating `PlayerForm.pill` as soon as `pixels > 40`, partially occluding right-hand controls (`video_2.mp4 00:00–00:07`).

---

### 2.5 Pillar D — Exhaustive `STD-UIUX-001` & Legacy Copy Census (`H-09`)

| File & Line | Defect Category | Exact Offending Code | Required Remediation |
| :--- | :--- | :--- | :--- |
| [`african_greeting_resolver.dart#L101-L109`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/home/presentation/utils/african_greeting_resolver.dart#L101-L109) | Raw Unicode Emojis | `return '✨';`, `return '☀️';`, `return '🌙';` | Replace string emoji with Phosphor `IconData` (`AppIcons.sparkle` / `PhosphorIconsFill.sun` / `PhosphorIconsFill.moonStars`) rendered via `PhosphorIcon` |
| [`home_dashboard_view.dart#L155-L163`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/home/presentation/views/home_dashboard_view.dart#L155-L163) | Legacy `@fifi` Fallback | `Track(id: 'seed-01', title: 'Ndo Mufuna Matibe', creatorName: 'Fifi', ...)` | Use `validVaultTracks.first` → `exploreTracks.first` → sovereign studio default (`creatorName: 'Vhunambi Studio'`) |
| [`home_dashboard_view.dart#L534`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/home/presentation/views/home_dashboard_view.dart#L534) | Raw Unicode Emoji | `const Text('Create ✨', ...)` | Replace with `PhosphorIcon(AppIcons.sparkle)` + `'Create'` |
| [`home_dashboard_view.dart#L608`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/home/presentation/views/home_dashboard_view.dart#L608) | ASCII Arrow Text + `<44dp` Target | `minimumSize: Size.zero` + `Text('View all ->')` | Enforce `44x44` hit target + `PhosphorIcon(AppIcons.caretRight, size: 14)` |
| [`home_dashboard_view.dart#L899,L907,L915,L936`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/home/presentation/views/home_dashboard_view.dart#L899-L936) | Hardcoded Hex Colors | `Color(0xFFEC4899)`, `Color(0xFF8B5CF6)`, `Color(0xFF10B981)`, `Color(0xFF3B82F6)` | Map to `AppColors.accentElectric`, `AppColors.success`, `AppColors.badgeCyan`, `AppColors.coinGold`, `AppColors.brandPrimary` |
| [`home_dashboard_view.dart#L1038`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/home/presentation/views/home_dashboard_view.dart#L1038) | Stock `Icon(...)` Wrapper | `child: Icon(icon, color: color, size: 18)` | Replace with `PhosphorIcon(icon, color: color, size: 18)` |
| [`dna_insight_card.dart#L26-L27,L60,L73`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/creator_dna/presentation/widgets/dna_insight_card.dart#L26-L73) | Raw Emojis + Stock `Icons.close` | `'✨'`, `'🎯'`, `Text('🧬')`, `Icon(Icons.close)` | Replace with `PhosphorIcon(AppIcons.dna)` and `PhosphorIcon(AppIcons.close)` |
| [`cross_module_synergy_deck.dart#L46,L167,L208,L241`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/home/presentation/widgets/cross_module_synergy_deck.dart#L46-L241) | Raw `Icon(PhosphorIcons...)` Wrapper | Uses `Icon(...)` instead of `PhosphorIcon(...)` | Standardize on `PhosphorIcon` |
| [`subscription_upgrade_modal.dart#L80,L436-L437`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/home/presentation/widgets/subscription_upgrade_modal.dart#L80-L437) | Stock Material Icons | `Icons.close_rounded`, `Icons.check_circle_rounded` | Replace with `AppIcons.close`, `AppIcons.checkCircle` |

---

## 3. Zania Explore Benchmark Extraction (`C:\Users\Ndugelo\Zania-Explore-v2.5\Zania-Explore`)

Forensic inspection of Zania Explore's web Music (`video_3.mp4`) and Explorer Dashboard (`video_4.mp4`, `video_5.mp4`) reveals **5 concrete UI/UX and architectural primitives** directly portable into Flutter for Vhunambi's Main Room:

### 3.1 Palette, Vignette Scrims & Cover-Art Pipeline
- **Design Tokens ([`app/globals.css#L64-L246`](file:///C:/Users/Ndugelo/Zania-Explore-v2.5/Zania-Explore/app/globals.css#L64-L246)):** Contrast between `"Morning Mist"` light surfaces (`--background: oklch(0.985 0.01 240)` / `#f8f9fb`, pure white `--card: #ffffff`, Mountain Navy ink `#1a1f3a`) and `"Mountain Silhouette"` midnight dark surfaces (`--background: oklch(0.12 0.03 265)`, slightly lifted `--card: oklch(0.17 0.04 265)`, warm Horizon Gold primary `#d4842e`/`oklch(0.7 0.19 55)`).
- **Legibility Over Artwork ([`mobile-music-hero.tsx#L427-L429`](file:///C:/Users/Ndugelo/Zania-Explore-v2.5/Zania-Explore/components/music/mobile/mobile-music-hero.tsx#L427-L429), [`genre-card.tsx#L68`](file:///C:/Users/Ndugelo/Zania-Explore-v2.5/Zania-Explore/components/music/genres/genre-card.tsx#L68)):** Rather than dumping bright text directly onto flat bright gradients, Zania layers `object-cover` artwork (or per-genre gradient) underneath a dual directional dark scrim (`bg-gradient-to-t from-background via-background/90 to-background/60` and `from-black/70 via-black/20 to-transparent`).
- **3-Tier Cover-Art Resolution ([`lib/music/cover-art.ts#L29-L68`](file:///C:/Users/Ndugelo/Zania-Explore-v2.5/Zania-Explore/lib/music/cover-art.ts#L29-L68), [`genre-gradient.ts#L41-L101`](file:///C:/Users/Ndugelo/Zania-Explore-v2.5/Zania-Explore/components/music/shared/genre-gradient.ts#L41-L101)):** Explicitly distinguishes custom cover URLs from placeholder paths (`isPlaceholderCover`), falls back deterministically to curated artwork or genre-mapped gradients tinted against `--background` (`from-primary/35 via-primary/15 to-background` instead of 100% neon orange!).

### 3.2 Atmospheric Hero Spotlight Carousel (`MobileMusicHero`, [`mobile-music-hero.tsx#L365-L648`](file:///C:/Users/Ndugelo/Zania-Explore-v2.5/Zania-Explore/components/music/mobile/mobile-music-hero.tsx#L365-L648))
- **Compact Touch Height & Swipeable Deck:** `h-[360px]` mobile hero canvas with touch swipe (`minSwipeDistance = 50`), directional slide (`slideVariants`), bottom-anchored metadata hierarchy (uppercase accent eyebrow icon + label, bold 2-line title, artist subtitle, rounded pill tags for Genre & Year/BPM), primary `Play Now` / live-toggling `Playing` pill (`min-h-[44px]`), secondary `44x44` `+` save/action button, and `44x44` dot indicators.

### 3.3 Embedded Artwork-Tinted Inline Audio Deck (`MobileWidgetNowPlaying`, [`mobile-widget-now-playing.tsx#L45-L250`](file:///C:/Users/Ndugelo/Zania-Explore-v2.5/Zania-Explore/components/dashboard/mobile/mobile-widget-now-playing.tsx#L45-L250))
- Consumes [`useWidgetNowPlaying`](file:///C:/Users/Ndugelo/Zania-Explore-v2.5/Zania-Explore/hooks/dashboard/use-widget-now-playing.ts#L12-L75) (`currentTrack`, `isPlaying`, `progress`, `currentTime`, `duration`, `canGoPrev`, `canGoNext`, `handleSeek`, `handleTogglePlayPause`, `previousTrack`, `nextTrack`).
- **Adaptive Empty State (`#L75-L96`):** Compact `rounded-xl border` tile (`Nothing playing right now` + direct launch CTA) when no track is loaded.
- **Active Artwork-Tinted Deck (`#L99-L250`):** Extracts dominant/palette hue gradient (`linear-gradient(145deg, ...)`), renders spinning/pulsing `48dp` rounded cover thumbnail with live ping dot when playing, favorite heart + `44x44` expand icon (`↗` to open full-screen vinyl player), interactive **tap/scrubbable progress bar** (`0:21` / `3:48` tabular numbers), and centered `⏮ ⏸ ⏭` `44x44` transport buttons.

### 3.4 At-a-Glance Utility Telemetry & Compact Favorites/Best Picks Shelves
- **`DashboardQuickStats` & `MobileWidgetStats` ([`dashboard-quick-stats.tsx#L34-L143`](file:///C:/Users/Ndugelo/Zania-Explore-v2.5/Zania-Explore/components/dashboard/shared/dashboard-quick-stats.tsx#L34-L143), [`mobile-widget-stats.tsx#L73-L115`](file:///C:/Users/Ndugelo/Zania-Explore-v2.5/Zania-Explore/components/dashboard/mobile/mobile-widget-stats.tsx#L73-L115)):** Clean, dense telemetry tiles showing live user state (`Tier`, `Credits Balance`, `Saved Tracks`, `Progress %`) in a responsive wrap/grid above the fold without wasting full cards.
- **`BestPicksCard` & `GenreCard` ([`best-picks-card.tsx#L34-L100`](file:///C:/Users/Ndugelo/Zania-Explore-v2.5/Zania-Explore/components/music/best-picks/best-picks-card.tsx#L34-L100), [`genre-card.tsx#L38-L73`](file:///C:/Users/Ndugelo/Zania-Explore-v2.5/Zania-Explore/components/music/genres/genre-card.tsx#L38-L73)):** Square cover-art tiles (`144dp`/`160dp`) with dark scrims, active equalizer overlay (`EqualizerBars`), `min-h-[44px]` text footer, and explicit track count labels (`23 tracks`).

---

## 4. Vhunambi Main-Room Utility Target Blueprint & Two-Pass Overhaul Roadmap

### 4.1 Live Provider Readiness Inventory

| Vhunambi Provider / API | Current Data Already Available | Gap to Close in Phase 68 |
| :--- | :--- | :--- |
| `playerStateProvider` ([`player_provider.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/player/presentation/providers/player_provider.dart)) | `currentTrack`, `isPlaying`, `position`, `duration`, `progressRatio`, `seek`, `skipNext`, `skipPrevious` | Wire directly to an embedded `HomeNowPlayingDeck` widget replacing `Jump Back In` |
| `libraryTracksProvider` ([`library_providers.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/library/presentation/providers/library_providers.dart)) | Real generated/cached `LibraryTrack` items, `isFavorite`, `playCount`, `durationSeconds` | Assign deterministic artwork (`VhunambiArtworkResolver`) and surface inline Recent / Favorites chips |
| `exploreTracksProvider` ([`explore_providers.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/explore/presentation/providers/explore_providers.dart)) | Curated South African & Pan-African catalog (`Track` with genre, mood, language, likes) | Bind `VhunambiArtworkResolver` covers + genre counts (`Best Picks` & `Explore Genres` cards) |
| `creatorDnaProvider` & `creatorWalletProvider` | Live `strengthPercent` (`6%–10%+`), `userCoinsBalance`, `dayStreak` | Surface directly inside the compact 4-metric Home Telemetry Strip |
| **`GET /api/wallet/allowance`** ([`wallet_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/wallet_routes.ts)) | Live `{ planTier, freeMonthlySongsLimit: 10, freeMonthlySongsUsed, freeMonthlySongsRemaining }` | **New `creatorAllowanceProvider`**: fetch from worker API (with offline Hive cache & auto-refresh after Studio generation) |

---

### 4.2 Target Mobile Main-Room Layout (`360dp` Portrait)

```
┌──────────────────────────────────────────────────────────┐
│ [ND]  Madekwana    [🎵 10/10] [🪙 5235] [🔥 3] [🔔 3]    │ <- Compact Header w/ Live Free Songs + Bell Badge
├──────────────────────────────────────────────────────────┤
│ ┌────────────┬────────────┬────────────┬───────────────┐ │
│ │ DNA  8%    │ FREE 10/10 │ COINS 5235 │ VAULT  4 trks │ │ <- At-a-Glance Creator Utility Telemetry Strip
│ └────────────┴────────────┴────────────┴───────────────┘ │
├──────────────────────────────────────────────────────────┤
│ [ ✨ Create New Song in Studio                     › ]  │ <- Sleek Primary Studio Action + 4-Tool Dock Row:
│ [ 🎤 Voice ]  [ 🎹 Sketchpad ]  [ 🎚️ Stem Lab ] [ 🛍️ Market ]│    (Zero duplicate AI Studio tile / no fake text box)
├──────────────────────────────────────────────────────────┤
│ ▓▓▓ ARTWORK-TINTED NOW PLAYING / RESUME DECK ▓▓▓▓▓▓▓▓▓   │
│ │ [Art]  Grateful in the Light          [🎚️] [↗]      │ │ <- Replaces flat Jump Back In + adds scrub slider
│ │        Sigwa & Inaf • Amapiano                      │ │    + ⏮ ⏸ ⏭ transport + Expand to Full Cockpit
│ │ ━━━━━━━●────────────────────────────────  0:21 / 3:36 │ │
│ │               [⏮]    ( ⏸ )    [⏭]                    │ │
│ └──────────────────────────────────────────────────────┘ │
├──────────────────────────────────────────────────────────┤
│ ▓▓▓ ATMOSPHERIC SPOTLIGHT & DAILY RHYTHM CAROUSEL ▓▓▓▓   │ <- Cover Art + Dark Bottom Vignette (NO solid slab)
│ │ [DAY • WED]  Tshivenḓa Malende Pulse  (108 BPM • Gm) │ │    Swipeable: Daily Rhythm + Featured Studio Picks
│ │ [ ▶ Play / Preview ]   [ Load in Studio › ]    1 / 4 │ │
├──────────────────────────────────────────────────────────┤
│  Trending in Your Genres              [ Explore All › ]  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │ <- Real Cover Artwork + Dark Scrim + Play Equalizer
│  │ [Artwork] ▶ │  │ [Artwork] ▶ │  │ [Artwork] ▶ │       │    + Track Count / Duration / Genre Badges
│  │ Grateful... │  │ Soweto...   │  │ Durban...   │       │
│  └─────────────┘  └─────────────┘  └─────────────┘       │
│                                                          │
│  [ Creator Plan: Free Tier • 10/10 Songs Left • Upgrade ]│ <- Live Allowance Status Strip (replaces static ad)
└──────────────────────────────────────────────────────────┘
   *(Kinetic Reels completely removed from Home — lives on Explore Tab 1)*
```

---

### 4.3 Ordered Two-Pass Overhaul Plan (`M68.1` – `M68.4`)

#### **Overhaul Pass 1 (`M68.1` – `M68.2`): Main-Room Space Reclamation, Visual Hierarchy & Cover-Art System**
- **`M68.1` — Space Reclamation, Prompt Wrapper Purge, Studio Dock & Reels Removal (`H-01`, `H-02`, `H-03`, `H-09`):**
  1. Remove the ~190dp `"What are you feeling today?"` prompt box (`home_dashboard_view.dart#L448-L561`) and `_promptController`; replace with a compact primary **`Create in Studio`** CTA button + scrollable quick-start preset pills that prefill `studioFormProvider` and switch to Tab 2.
  2. Replace the redundant 6-tile grid (removing `home_hub_ai_studio`) with a tight 4/5-tool **Studio Utility Dock** (`Voice Clone`, `Sketchpad`, `Stem Lab`, `Beats Market`, `Asset Vault`) using `PhosphorIcon`, contextual `AppColors.*Of(context)`, zero hardcoded hexes, and $44 \times 44\text{dp}$ minimum touch targets.
  3. **Remove `TrendingReelsShelf()` completely from `HomeDashboardView`** (`#L632-L634`), reserving Kinetic Reels exclusively for Tab 1 (`Explore`).
  4. Migrate `AfricanGreetingResolver.getTimeGlyphIcon()` to return Phosphor `IconData` (`AppIcons` / `PhosphorIconsFill`), and eradicate `STD-UIUX-001` violations across `dna_insight_card.dart`, `cross_module_synergy_deck.dart`, and `subscription_upgrade_modal.dart`, plus remove the `'Fifi'` fallback in `home_dashboard_view.dart#L155-L163`.
- **`M68.2` — Deterministic Cover-Art System & Dark-Vignette Atmospheric Cards (`H-04`, `H-05`, `H-08`):**
  1. Create `VhunambiArtworkResolver` mapping genres/track IDs cleanly to the 10 bundled assets in `assets/artwork/` (`heritage_crate_cover.png`, `Vhunambi_ African Sunset Melodies.png`, `Vhunambi_ Five Voices, One Vision.png`, `splash_hero.png`, and 5 voice timbre portraits) combined with subtle obsidian-vignetted backdrops (`LinearGradient` bottom scrim) so zero flat orange squares or solid `#FF6B00` / `#4F46E5` slabs appear in either dark or light mode.
  2. Upgrade **`Daily Rhythm Spotlight`** into a sleek atmospheric cover-art hero card (obsidian surface + artwork backdrop + dark scrim + `BPM`/`Key` pills + `Load in Studio` action keeping `Key('home_try_rhythm_btn')`) and upgrade **`Trending in Your Genres`** / **`Curated Picks`** cards to render full-bleed square artwork, dark bottom scrims, active equalizer bars when playing, and duration/genre metadata.

#### **Overhaul Pass 2 (`M68.3` – `M68.4`): Embedded Now-Playing Deck, Live Telemetry Strip, `/api/wallet/allowance` & Full Verification**
- **`M68.3` — Embedded Artwork-Tinted Inline Audio Deck (`H-06`):**
  1. Replace the static `Jump Back In` row with **`HomeNowPlayingDeck`** modeled directly on Zania Explore's `MobileWidgetNowPlaying`: artwork-tinted gradient card (`VhunambiArtworkResolver`), `48dp` rounded cover thumbnail with spinning/live state, quick Stem Master button (`Key('home_jump_back_master_btn')`), expand `↗` button launching `ExpandedCockpitModal.show(context)`, interactive scrubbable `Slider`/progress bar (`formattedPosition / formattedDuration`), and `⏮` / `⏸` / `⏭` `44x44` transport buttons wired to `playerStateProvider`.
  2. Include a clean idle/resume state (`Ready to Play` pointing to latest `libraryTracksProvider` creation with one-tap `Play`) and a compact inline **Recent Creations / Favorites** quick-access strip.
- **`M68.4` — Live Creator Telemetry Strip, `creatorAllowanceProvider` (`/api/wallet/allowance`), Plan Card & Tests (`H-07`):**
  1. Implement `creatorAllowanceProvider` (`StateNotifierProvider`) synced with `GET /api/wallet/allowance` (persisted in Hive for instant cold-boot display and refreshed automatically when `generationProgressProvider` completes a song), surfacing live `freeMonthlySongsRemaining / freeMonthlySongsLimit` (`10 / 10`).
  2. Add the top **Creator Utility Telemetry Strip** (`Creator DNA %`, `Free Songs Left`, `Cultural Coins`, `Vault Tracks`) and header quota pill, and upgrade the bottom `Upgrade to Creator or Pro` card into a dynamic **Plan & Monthly Allowance Card** (`Free Tier • X / 10 Songs Left • Upgrade`).
  3. Update affected legacy Home tests (`home_dashboard_view_test.dart`, `phase31_home_dashboard_convergence_test.dart`) and add `phase68_home_overhaul_test.dart` running with `dart analyze` + `flutter test --timeout=60s`.

---

### 4.4 Stage 2 / Stage 4 Gate Commands (For Subsequent Turns)

```powershell
# Stage 4 Pass 1 & Pass 2 Verification Gates (Do not run during this audit turn)
cd apps/vhunambi_client
dart analyze lib/features/home lib/features/creator_dna lib/core/constants/app_assets.dart
flutter test test/features/home/ test/phase31_home_dashboard_convergence_test.dart test/phase34_bottom_nav_and_iconography_test.dart --timeout=60s
```
