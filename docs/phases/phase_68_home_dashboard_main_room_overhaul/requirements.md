# Phase 68 — Home Dashboard "Main Room & Studio Utility" Overhaul Requirements

> **Document ID:** `VHUNAMBI-SPEC-P68-REQUIREMENTS-V1`  
> **Specification Format:** EARS (Easy Approach to Requirements Syntax) & RFC-2119 (`SHALL` / `SHALL NOT`)  
> **UI/UX & Theme Governance:** `STD-UIUX-001` (100% Phosphor Icons, Zero Raw Unicode Emojis, Dynamic `*Of(context)` Dual-Theme Adaptation, Minimum `48dp` Touch Targets)

---

## 1. Scope, Standards & Conventions

This document defines the normative functional and non-functional requirements for **Phase 68: Home Dashboard "Main Room & Studio Utility" Overhaul**, executed in **Overhaul Pass 1 (`M68.1` – `M68.2`)** and **Overhaul Pass 2 (`M68.3` – `M68.4`)**.

1. **EARS Syntax:**
   - **Ubiquitous (`SHALL`):** Always holds across all viewports and states.
   - **Event-Driven (`WHEN ... SHALL ...`):** Triggered upon user interaction or state transition.
   - **State-Driven (`WHILE ... SHALL ...`):** Active throughout a continuous condition.
   - **Conditional (`IF ... THEN SHALL ...`):** Applies under explicit fallback or edge conditions.
2. **Global Invariants:**
   - **Keyboard-Free Home Law:** `HomeDashboardView` SHALL contain zero `TextField` / `TextFormField` widgets so Home never triggers soft-keyboard insets before switching tabs.
   - **Zero-Placeholder Art Law:** Seeded and active tracks rendered on Home SHALL resolve real bundled or remote artwork via `VhunambiTrackArtwork` rather than flat monochrome genre tiles.
   - **Zero-Speculation Quota Law:** Monthly song allowance displayed in Home (`10/10`) SHALL originate from `GET /api/wallet/allowance` (cached per `creatorId` in Hive), never fabricated locally as an infinite balance.

---

## 2. Overhaul Pass 1 Requirements (`M68.1` – `M68.2`): Artwork Foundation, Declutter & Main Room Skeleton

### 2.1 Bundled Artwork Registry & Unified Cover Renderer (`M68.1`)
- **`REQ-P68-ART-01` (All 10 Bundled Artworks Registered):**  
  `AppAssets` SHALL declare typed static constants for all 10 PNG files under `assets/artwork/` (`heritageCrateCover`, `splashHero`, `timbreElder`, `timbrePoet`, `timbreCrooner`, `timbreCantor`, `timbreProducer`, `sunsetMelodiesCover`, `fiveVoicesCover`, `musicFeelEscapeCover`) plus a deterministic `resolveGenreCoverAsset(String genre)` and `resolveTrackCoverAsset({String? coverUrl, String? genre, String? id})` mapper.
- **`REQ-P68-ART-02` (Unified `VhunambiTrackArtwork` Widget):**  
  `VhunambiTrackArtwork` SHALL render cover artwork across all square/editorial Home surfaces with deterministic fallback ordering:
  1. Valid `http://` or `https://` URL (rendered via `Image.network` with `BoxFit.cover`, shimmer/gradient placeholder, and `errorBuilder` falling back to step 2/3).
  2. `asset:...` prefixed path or direct `assets/...` path (rendered via `Image.asset` with `errorBuilder` falling back to step 3).
  3. Deterministic genre-matched asset via `AppAssets.resolveGenreCoverAsset(genre)`.
  4. Only in an explicit image decode failure without asset availability SHALL a branded gradient + `PhosphorIcon(PhosphorIconsFill.musicNotes)` badge be rendered.
- **`REQ-P68-ART-03` (Seeded Catalog & Library Artwork Backfill):**  
  Explore seeded catalog tracks (`explore_providers.dart`) and starter Library tracks (`library_providers.dart`) SHALL populate non-null `coverUrl` values using `asset:assets/artwork/...` URIs matching each track's cultural genre, and `HomeDashboardView` SHALL NEVER fall back to `'seed-01'` (`'Ndo Mufuna Matibe'` by `'Fifi'`).

### 2.2 Structural Declutter & Theme Tokenization (`M68.2`)
- **`REQ-P68-CLEAN-01` (Purge Fake Prompt Card):**  
  `HomeDashboardView` SHALL remove the `~190dp` *"What are you feeling today?"* prompt container, inline `TextField`, and `_promptController` from Home.
- **`REQ-P68-CLEAN-02` (Purge Redundant `AI Studio` Tile & `TrendingReelsShelf`):**  
  `HomeDashboardView` SHALL remove `TrendingReelsShelf()` from Home (preserving it exclusively inside Explore Tab 1) and remove the duplicate `home_hub_ai_studio` card in favor of a single `home_create_studio_cta` capsule (`Key('home_create_studio_cta')`).
- **`REQ-P68-CLEAN-03` (100% Dynamic Theme Tokenization):**  
  All Home containers, cards, borders, chips, and typography SHALL use `AppColors.surfaceCanvasOf(context)`, `surfaceElevatedOf(context)`, `surfaceSecondaryOf(context)`, `surfaceModalOf(context)`, `borderSubtleOf(context)`, `textPrimaryOf(context)`, and `textSecondaryOf(context)`. Hardcoded dark-only colors (`AppColors.surfaceCanvas`, `surfaceElevated`, `surfaceSecondary`, `textPrimary`, `textSecondary`) and raw hex literals (`Color(0xFF...)`) SHALL NOT appear in `home_dashboard_view.dart`, `now_playing_home_card.dart`, `creation_launch_strip.dart`, or `editorial_rhythm_spotlight_card.dart`.

### 2.3 Main Room Feed Zones — Header, Telemetry/DNA & Trending Genres (`M68.2`)
- **`REQ-P68-FEED-01` (Top Utility Header Zone 1):**  
  `MainRoomHeader` SHALL render compactly with zero horizontal overflow at `360dp` width:
  - Avatar button (`Key('home_avatar_btn')`) + time-aware authentic greeting (`Key('home_greeting_text')`, no emojis) + creator display name.
  - Interactive theme toggle (`Key('home_theme_toggle_btn')`), streak pill (`Key('home_streak_pill')`, displays `<N> Streak`), coins pill (`Key('home_coins_pill')`, displays `<N> Coins`), and `NotificationBellButton(key: Key('home_notifications_btn'))`.
- **`REQ-P68-FEED-02` (Conditional Pipeline / DNA Strip Zone 1.5):**  
  - **WHILE** `generationProgressProvider != null` and active (`isGenerating || isReady || hasFailed`), Zone 1.5 SHALL mount `Key('home_pipeline_progress_card')` with step indicator and one-tap navigation to Studio.
  - **WHILE** no generation pipeline banner is active, Zone 1.5 SHALL render a compact `<= 52dp` `CreatorDnaCompactStrip` (`Key('home_dna_compact_strip')`) showing current `strengthPercent%` calibrated with an accessible CTA opening `CreatorDnaHelixLabSheet.show(context)`.
- **`REQ-P68-FEED-03` (`Trending in Your Genres` Horizontal Square Artwork Rail Zone 3):**  
  `HorizontalGenreTrackShelf` (`Key('home_trending_genres_shelf')`) SHALL display up to 8 tracks filtered by `onboardingStateProvider.selectedGenres` (falling back cleanly to top trending tracks when no genre filter matches), rendered as `148dp` rounded square `VhunambiTrackArtwork` cards with genre pill, 1-line title, 1-line creator handle, and a `48dp`-tall `View all` button (`Key('home_trending_view_all_btn')`, `PhosphorIcon` trailing chevron) routing to Explore Tab 1.
- **`REQ-P68-FEED-04` (Single-Tap Shelf Playback):**  
  **WHEN** a user taps any card in `HorizontalGenreTrackShelf`, Home SHALL invoke `playerStateProvider.notifier.playTrack(track, queue: tracks)` immediately.

---

## 3. Overhaul Pass 2 Requirements (`M68.3` – `M68.4`): Live Quota, Inline Now-Playing, Studio Launch & Editorial Spotlight

### 3.1 Live Creator Monthly Quota (`GET /api/wallet/allowance`) (`M68.3`)
- **`REQ-P68-QUOTA-01` (`CreatorAllowanceNotifier` & Hive Persistence):**  
  `creatorAllowanceProvider` SHALL manage `CreatorAllowanceState` (`planTier`, `freeMonthlySongsLimit`, `freeMonthlySongsUsed`, `freeMonthlySongsRemaining`, `cycleResetAt`, `isLoading`, `isFromCache`):
  1. Hydrate immediately from `Hive.box(AppConstants.prefsBoxKey)` under per-tenant key `creator_allowance_cache_<canonicalCreatorId>` so cold starts show real persisted quota without UI flicker.
  2. When authenticated (`authSessionProvider.isAuthenticated`), fetch `GET ${AppConstants.apiRestBaseUrl}/wallet/allowance` via `SovereignApiClient` and overwrite cache with fresh counts.
  3. On network error or guest offline session, preserve last cached snapshot or default to starter quota (`10 / 10` free songs remaining, `planTier: 'free'`).
- **`REQ-P68-QUOTA-02` (Multi-Tenant Cache Sanitization):**  
  **WHEN** `currentCreatorIdProvider` changes, `CreatorAllowanceNotifier` SHALL reload only the active tenant's cached quota snapshot without leaking previous account allowance counts.
- **`REQ-P68-QUOTA-03` (Compact Header Quota Pill):**  
  `MainRoomHeader` SHALL render `Key('home_allowance_pill')` right beside `home_coins_pill`, displaying `<remaining>/<limit>` (e.g., `10/10`) for free tier or `Pro` for paid plans, with semantic warning tint when `remaining <= 2`. Tapping `home_allowance_pill` SHALL open `SubscriptionUpgradeModal.show(context)`.

### 3.2 Inline `NowPlayingHomeCard` & Tab-0 Floating MiniPlayer Suppression (`M68.3`)
- **`REQ-P68-PLAYER-01` (`NowPlayingHomeCard` Zone 2 Playback Deck):**  
  `NowPlayingHomeCard` (`Key('home_now_playing_card')`) SHALL replace the cluttered Jump Back In card with a Zania-inspired compact playback surface:
  - Priority Track Selection: (1) active `playerStateProvider.currentTrack`, else (2) most recent `libraryTracksProvider` track, else (3) first personalized `exploreTracksProvider` track.
  - **IF** all three sources are genuinely empty, THEN render a clean honest Empty State (`Create your first track` routing to Studio) instead of a fabricated mock track.
  - Renders `64x64` `VhunambiTrackArtwork`, track title, `creatorName * genre`, live `formattedPosition / formattedDuration`, interactive scrub `SliderTheme` + `Slider` (seeking via `playerStateProvider.notifier.seek(...)`), `48x48` accessible transport buttons (`home_player_prev_btn`, `home_player_play_pause_btn`, `home_player_next_btn`), and `home_jump_back_master_btn` (`Polish` / `Stems` opening `MobileQuickMasterSheet`).
  - Tapping the artwork or track title opens `ExpandedCockpitModal.show(context)` (when an active track is loaded, or plays the selected track first and opens the cockpit).
- **`REQ-P68-PLAYER-02` (Zero Double-Player Overlap on Mobile Home Tab 0):**  
  `MiniPlayerHost._shouldHide(...)` SHALL return `true` when `appNavigationTabProvider == 0 && ref.watch(homeInlineNowPlayingMountedProvider) == true`, preventing duplicate stacked players on Home while keeping `MiniPlayerHost` visible on Tabs 1, 3, and 4 AND preserving standalone `MiniPlayerHost` behavior in isolated overlay tests.
- **`REQ-P68-PLAYER-03` (Safe Scroll Bottom Inset):**  
  `HomeDashboardView` SHALL compute bottom scroll padding using `VhunambiBottomDockMetrics.scrollInset(hasActiveTrack: false)` on mobile (since `MiniPlayerHost` is suppressed on Tab 0) so bottom cards scroll cleanly above the floating bottom navigation capsule with zero excess dead whitespace.

### 3.3 Studio Launch Strip & Scrimmed Editorial Spotlight (`M68.4`)
- **`REQ-P68-HUB-01` (Direct Studio Launch Capsule + 4-Tool Studio Strip Zone 4):**  
  - A full-width compact (`48dp` height) capsule (`Key('home_create_studio_cta')`) SHALL open Tab 2 (Studio Cockpit) with zero intermediate `TextField`.
  - Directly below, `CreationLaunchStrip` SHALL render 4 distinct utility shortcuts (horizontal 4-up compact grid on mobile, 2x2 on desktop right column) with zero duplicates of AI Studio:
    1. `Key('home_hub_voice_clone')` — *Voice Clone* (`VocalIdentityPickerSheet`)
    2. `Key('home_hub_melody_sketchpad')` — *Sketchpad* (`MelodySketchpadModal`)
    3. `Key('home_hub_beats_market')` — *Beats Market* (`onNavigateToMarket`)
    4. `Key('home_hub_asset_vault')` — *Asset Vault* (`onNavigateToLibrary`)
- **`REQ-P68-SPOT-01` (Scrimmed Editorial `DailyRhythmSpotlight` Card Zone 5):**  
  `EditorialRhythmSpotlightCard` SHALL render `AppAssets.resolveGenreCoverAsset(spotlight.genre)` as background artwork overlaid by a 2-stop dark editorial scrim (`black 0.45 -> 0.88`), crisp high-contrast metadata (`DAILY RHYTHM SPOTLIGHT * <WEEKDAY>`, rhythm title, BPM & cultural notes), and `Key('home_try_rhythm_btn')` (`>=48dp` height) which pre-configures `studioFormProvider` + `melodySketchpadProvider` and routes to Studio.

### 3.4 `STD-UIUX-001` Emoji Purge & Minimum Touch Targets (`M68.4`)
- **`REQ-P68-STD-01` (100% Emoji Purge Across Home & Supporting Modals):**  
  Raw unicode emojis (`✨`, `☀️`, `🌙`, `🎯`, `🧬`) SHALL be purged from `african_greeting_resolver.dart`, `dna_insight_card.dart`, `home_dashboard_view.dart`, and `subscription_upgrade_modal.dart`.
- **`REQ-P68-STD-02` (100% Phosphor Iconography):**  
  Every icon in `home_dashboard_view.dart`, `now_playing_home_card.dart`, `creation_launch_strip.dart`, `editorial_rhythm_spotlight_card.dart`, `dna_insight_card.dart`, `cross_module_synergy_deck.dart`, and `subscription_upgrade_modal.dart` SHALL use `PhosphorIcon(PhosphorIcons*.*)`—zero stock Material `Icons.*` and zero `Icon(PhosphorIcons...)` mismatches.
- **`REQ-P68-STD-03` (`48dp` Interactive Hit-Target Floor):**  
  All interactive buttons, pills (`home_allowance_pill`, `home_streak_pill`, `home_coins_pill`), `View all`, close icons, and transport buttons SHALL provide at least `48dp` height (via `ConstrainedBox(minHeight: 48)` or `Material` + centered pill visual or `minimumSize: Size(48, 48)`).

---

## 4. Non-Functional & Resilience Requirements (`REQ-P68-NFR-*`)

| Requirement ID | Category | Normative Specification |
| :--- | :--- | :--- |
| **`REQ-P68-NFR-01`** | **Layout Stability & Performance** | `HomeDashboardView` SHALL use a single outer scrollable (`ListView` / `CustomScrollView`) + 1 bounded horizontal `ListView.separated` for Zone 3 (`198dp` fixed extent), maintaining `<= 16.6ms` frame times on ARM64 mobile with zero nested vertical scrollables and zero RenderFlex overflows across `360x780`, `390x844`, and `1280x800`. |
| **`REQ-P68-NFR-02`** | **Keyboard & Focus Discipline** | Opening notifications, allowance upgrade modal, DNA lab, or Studio tab transitions SHALL call `FocusManager.instance.primaryFocus?.unfocus()`, and Home SHALL contain zero focusable text inputs. |
| **`REQ-P68-NFR-03`** | **Async Lifecycle & Mounted Safety** | `CreatorAllowanceNotifier` SHALL check `mounted` before every `state = ...` assignment after `await` calls and handle network/JSON failures silently via cached/default fallback without throwing uncaught async exceptions in headless widget tests. |
| **`REQ-P68-NFR-04`** | **Headless & Bounded Testability** | All widget tests interacting with Home SHALL avoid infinite `pumpAndSettle()` hangs (especially during shimmer or live playback ticker states, using bounded `pump(...)` steps) and execute with `--timeout=60s`. |

---

## 5. Granular Requirement-to-Test Traceability Matrix

| Requirement ID | Target File / Class | Verification Assertion (`flutter test`) |
| :--- | :--- | :--- |
| `REQ-P68-ART-01`, `02`, `03` | `AppAssets`, `VhunambiTrackArtwork`, `explore_providers.dart`, `library_providers.dart` | `resolveGenreCoverAsset` covers all genres; `VhunambiTrackArtwork` renders `Image.asset` for `asset:` URLs & error fallback gradient; zero `'seed-01'` mock in Home. |
| `REQ-P68-CLEAN-01`, `02`, `03` | `HomeDashboardView` | Zero `TextField`, zero `'What are you feeling today?'`, zero `TrendingReelsShelf`, zero `home_hub_ai_studio`, light+dark pump passes without contrast/theme crashes. |
| `REQ-P68-FEED-01` .. `04` | `MainRoomHeader`, `TelemetryAndDnaBanner`, `HorizontalGenreTrackShelf` | Greeting text + Bell + Streak + Coins mount cleanly; `generationProgressProvider` toggles telemetry vs DNA strip; tapping trending track calls `playerStateProvider.playTrack`. |
| `REQ-P68-QUOTA-01` .. `03` | `CreatorAllowanceNotifier`, `MainRoomHeader` | `GET /api/wallet/allowance` mock 200 updates pill from `10/10` to server remaining; offline exception retains cached value; tenant switch isolates cache; tap opens `SubscriptionUpgradeModal`. |
| `REQ-P68-PLAYER-01` .. `03` | `NowPlayingHomeCard`, `MiniPlayerHost` | Card renders active/library/explore track + `Slider` seek + prev/play/next + `home_jump_back_master_btn`; Tab 0 suppresses `MiniPlayerHost` when inline mounted, Tab 1 restores it, standalone `mini_player_host_test.dart` passes unchanged. |
| `REQ-P68-HUB-01`, `SPOT-01` | `CreationLaunchStrip`, `EditorialRhythmSpotlightCard` | `home_create_studio_cta` + 4 tool keys trigger expected modals/callbacks; `home_try_rhythm_btn` configures `studioFormProvider` + `melodySketchpadProvider` (`Gqom`, `127 BPM`). |
| `REQ-P68-STD-01` .. `03` | `AfricanGreetingResolver`, `DnaInsightCard`, `CrossModuleSynergyDeck`, `SubscriptionUpgradeModal` | Regex scan across modified files confirms zero unicode emojis & zero `Icons.*`; interactive widgets have `>= 48dp` semantics/tap bounds. |
