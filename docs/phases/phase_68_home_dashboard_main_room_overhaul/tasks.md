# Phase 68 — Home Dashboard "Main Room & Studio Utility" Overhaul Execution Tasks

> **Document ID:** `VHUNAMBI-SPEC-P68-TASKS-V1`  
> **Execution Standard:** Vhunambi Two-Pass Stage 4 Engine (`/vhunambi-executioner`)  
> **Pass Structure:** **Overhaul Pass 1 (`M68.1` – `M68.2`)** $\to$ **Overhaul Pass 2 (`M68.3` – `M68.4`)**

---

## 1. Master Milestone Roadmap & Dependency Graph

```
+---------------------------------------------------------------------------------------------------+
| OVERHAUL PASS 1: ARTWORK PIPELINE, DECLUTTER & MAIN ROOM FOUNDATION                               |
|                                                                                                   |
|  [M68.1] 10-Asset Registry, VhunambiTrackArtwork, Seeded Cover Backfill & Emoji-Free Greeting     |
|     |                                                                                             |
|     v                                                                                             |
|  [M68.2] Purge Fake Prompt/Reels/AI-Dup, *Of(context) Tokenization, Telemetry/DNA & Genre Shelf   |
+---------------------------------------------------------------------------------------------------+
                                                 |
                                                 v
+---------------------------------------------------------------------------------------------------+
| OVERHAUL PASS 2: LIVE QUOTA ENGINE, INLINE NOW-PLAYING, STUDIO STRIP & SPOTLIGHT SCRIM            |
|                                                                                                   |
|  [M68.3] CreatorAllowanceNotifier (`/api/wallet/allowance` + Hive), Header `10/10` Pill,         |
|          NowPlayingHomeCard (Zania Compact Player) & Tab-0 MiniPlayerHost Suppression             |
|     |                                                                                             |
|     v                                                                                             |
|  [M68.4] Create-in-Studio CTA + 4-Tool Strip, Editorial Spotlight Scrim, RootShell Tab 1 Wiring,  |
|          STD-UIUX-001 Cleanups (DNA/Synergy/Upgrade Modal) & Home/Player Test Realignment         |
+---------------------------------------------------------------------------------------------------+
```

| Milestone | Pass | Deliverable Summary | Verification Scope |
| :--- | :--- | :--- | :--- |
| **`M68.1`** | Pass 1 | `AppAssets` 10-artwork registry + `VhunambiTrackArtwork` + Explore/Library cover backfill + `AfricanGreetingResolver` emoji purge. | Unit test artwork resolver & greeting; zero unmapped assets. |
| **`M68.2`** | Pass 1 | `MainRoomHeader` + `TelemetryAndDnaBanner` + `HorizontalGenreTrackShelf` + purge fake prompt, `TrendingReelsShelf`, `seed-01` mock. | Widget render check in Light + Dark (`360dp`, `1280dp`). |
| **`M68.3`** | Pass 2 | `CreatorAllowanceState` / `CreatorAllowanceNotifier` + Header `10/10` pill + `NowPlayingHomeCard` + `MiniPlayerHost` Tab-0 suppression. | Unit quota sync + cache tests + `MiniPlayerHost` + `NowPlayingHomeCard` tests. |
| **`M68.4`** | Pass 2 | `CreationLaunchStrip` + `EditorialRhythmSpotlightCard` + `RootShell` Explore link + `STD-UIUX-001` modal cleanups + test suite realignment. | Full `flutter analyze` + bounded Home/Player/Notifications test run. |

---

## 2. Overhaul Pass 1 (`M68.1` – `M68.2`)

### Milestone `M68.1`: Unified Artwork Pipeline, Catalog Backfill & Emoji-Free Greeting

- [x] **Task `68.1.1` — Register Remaining Bundled Artworks & Mappers (`AppAssets`)**
  - **Target File:** `apps/vhunambi_client/lib/core/constants/app_assets.dart`
  - **Signatures:** Add `sunsetMelodiesCover`, `fiveVoicesCover`, `musicFeelEscapeCover`, `allBundledArtworkAssets`, `resolveGenreCoverAsset(String genre, {String? seedId})`, and `resolveTrackCoverSource({String? coverUrl, required String genre, String? seedId})` per `design.md` §2.1.
  - **Acceptance Criteria:** Every single one of the 10 PNGs inside `apps/vhunambi_client/assets/artwork/` is referenced cleanly with exact filename casing.

- [x] **Task `68.1.2` — Create Unified `VhunambiTrackArtwork` Widget**
  - **Target File:** `apps/vhunambi_client/lib/core/widgets/vhunambi_track_artwork.dart`
  - **Signatures:** `class VhunambiTrackArtwork extends StatelessWidget` per `design.md` §2.3.
  - **Acceptance Criteria:** Handles `http(s)://`, `asset:...`, direct `assets/...`, `null` -> deterministic genre artwork, and image decode errors via `AppGradients.forGenre` + `PhosphorIcon(PhosphorIconsFill.musicNotes)` badge. Uses `*Of(context)` border & canvas tokens.

- [x] **Task `68.1.3` — Backfill Seeded Track Artworks in Explore & Library**
  - **Target Files:**
    - `apps/vhunambi_client/lib/features/explore/presentation/providers/explore_providers.dart` (`_buildFallbackExploreCatalog`)
    - `apps/vhunambi_client/lib/features/library/presentation/providers/library_providers.dart` (`_buildStarterTracks`)
  - **Acceptance Criteria:** Every seeded `Track` in `_buildFallbackExploreCatalog` and every starter `LibraryTrack` carries a non-null `coverUrl` / `coverImageUrl` formatted as `'asset:${AppAssets.<assetConstant>}'`. Zero hardcoded HTTP placeholder images that 404 offline.

- [x] **Task `68.1.4` — Purge Emojis from `AfricanGreetingResolver`**
  - **Target File:** `apps/vhunambi_client/lib/features/home/presentation/utils/african_greeting_resolver.dart`
  - **Signatures:** Add `enum GreetingIconType`, `getGreetingIconType({DateTime? currentTime})`, `resolvePhosphorIcon({DateTime? currentTime})`, and replace emojis in `getTimeGlyph()` with emoji-free descriptors per `design.md` §2.2.
  - **Acceptance Criteria:** Zero unicode emojis (`✨`, `☀️`, `🌙`) anywhere in `african_greeting_resolver.dart`.

---

### Milestone `M68.2`: Declutter Home, Theme Tokenization & Main Room Skeleton

- [x] **Task `68.2.1` — Create `TelemetryAndDnaBanner` (Zone 1.5)**
  - **Target File:** `apps/vhunambi_client/lib/features/home/presentation/widgets/telemetry_and_dna_banner.dart`
  - **Signatures:** `class TelemetryAndDnaBanner extends ConsumerWidget` exposing `Key('home_inflight_generation_banner')` and `Key('home_dna_compact_strip')` per `design.md` §5.6.
  - **Acceptance Criteria:** Conditionally renders live generation telemetry when `generationProgressProvider != null`, otherwise displays slim `>=48dp` DNA calibration pill opening `CreatorDnaHelixLabSheet.show(context, profile: dna)` with `FocusManager.instance.primaryFocus?.unfocus()`.

- [x] **Task `68.2.2` — Create `HorizontalGenreTrackShelf` (Zone 3)**
  - **Target File:** `apps/vhunambi_client/lib/features/home/presentation/widgets/horizontal_genre_track_shelf.dart`
  - **Signatures:** `class HorizontalGenreTrackShelf extends ConsumerWidget` exposing `Key('home_trending_genres_shelf')`, `Key('home_trending_view_all_btn')`, and `Key('home_trending_track_${track.id}')` per `design.md` §5.3.
  - **Acceptance Criteria:** Renders `148x148` square `VhunambiTrackArtwork` cards inside a `200dp` horizontal `ListView.separated`, `48dp` `View all` button with `PhosphorIconsBold.caretRight`, and starts playback on card tap.

- [x] **Task `68.2.3` — Declutter `HomeDashboardView` Skeleton & Tokenize Light/Dark Mode**
  - **Target File:** `apps/vhunambi_client/lib/features/home/presentation/views/home_dashboard_view.dart`
  - **Acceptance Criteria:** Removes `_promptController`, *"What are you feeling today?"* prompt container, `TrendingReelsShelf()`, `seed-01 Ndo Mufuna Matibe`, `home_hub_ai_studio`, all hardcoded dark `AppColors.*` references, raw hex colors (`0xFF...`), and stock `Icon(...)` calls. Rebuilt using `AppColors.surfaceCanvasOf(context)` and responsive zones per `design.md` §5.7 (wiring starter header + Zone 1.5 + Zone 3 immediately; finalizing Zones 2, 4, 5 in Pass 2).

---

## 3. Overhaul Pass 2 (`M68.3` – `M68.4`)

### Milestone `M68.3`: Live Creator Allowance Engine, `NowPlayingHomeCard` & Tab-0 MiniPlayer Guard

- [x] **Task `68.3.1` — Create `CreatorAllowanceState` & `CreatorAllowanceNotifier`**
  - **Target Files:**
    - `apps/vhunambi_client/lib/features/home/domain/models/creator_allowance_state.dart`
    - `apps/vhunambi_client/lib/features/home/presentation/providers/creator_allowance_provider.dart`
  - **Signatures:** `CreatorAllowanceState`, `CreatorAllowanceNotifier`, `CreatorAllowanceNotifier.withInitial`, `creatorAllowanceProvider` per `design.md` §3.1–§3.2.
  - **Acceptance Criteria:** Hydrates cached quota immediately from `Hive.box(AppConstants.prefsBoxKey)` keyed by `creator_allowance_cache_<canonicalCreatorId>`, fetches `GET ${AppConstants.apiRestBaseUrl}/wallet/allowance` via `SovereignApiClient` when authenticated, handles offline/non-200 cleanly with `mounted` checks, and isolates per-tenant snapshots across account switches.

- [x] **Task `68.3.2` — Create `MainRoomHeader` with Live Quota Pill (`10/10 Free`)**
  - **Target File:** `apps/vhunambi_client/lib/features/home/presentation/widgets/main_room_header.dart`
  - **Signatures:** `class MainRoomHeader extends ConsumerWidget` per `design.md` §5.1 (responsive 2-tier mobile utility header eliminating `360dp` horizontal overflow while preserving single-row desktop layout).
  - **Acceptance Criteria:** Mounts `home_avatar_btn`, `home_greeting_text`, `home_theme_toggle_btn`, `home_streak_pill` (`<N> Streak`), `home_allowance_pill` (`10/10 Free` / `Pro`), `home_coins_pill` (`<N> Coins`), and `NotificationBellButton(key: Key('home_notifications_btn'))`. All pills have `>=48dp` tap height and open `SubscriptionUpgradeModal.show(context)`.

- [x] **Task `68.3.3` — Create Inline `NowPlayingHomeCard` & Guard `MiniPlayerHost` on Tab 0**
  - **Target Files:**
    - `apps/vhunambi_client/lib/core/navigation/navigation_providers.dart` (`homeInlineNowPlayingMountedProvider`)
    - `apps/vhunambi_client/lib/features/player/presentation/widgets/mini_player_host.dart` (`_shouldHide`)
    - `apps/vhunambi_client/lib/features/home/presentation/widgets/now_playing_home_card.dart`
  - **Acceptance Criteria:**
    - `NowPlayingHomeCard` renders `60x60` `VhunambiTrackArtwork`, `'Now Playing'` / `'Jump Back In'` eyebrow, scrub `Slider`, 48x48 `Prev`/`Play-Pause`/`Next`, `home_jump_back_master_btn` (`Polish`), and artwork tap opening `ExpandedCockpitModal.show(context)`.
    - Renders honest Empty State when both Library & Explore are empty (never `seed-01`).
    - Registers `homeInlineNowPlayingMountedProvider = true` on mount / `false` on dispose.
    - `MiniPlayerHost._shouldHide` hides ONLY when `activeTab == 0 && isHomeInlineMounted == true` (in addition to existing guards), keeping `mini_player_host_test.dart` and `phase33_adaptive_mini_player_test.dart` passing unmodified.

---

### Milestone `M68.4`: Studio Launch Strip, Scrimmed Spotlight, `STD-UIUX-001` Cleanups & Test Realignment

- [x] **Task `68.4.1` — Create `CreationLaunchStrip` & `EditorialRhythmSpotlightCard`**
  - **Target Files:**
    - `apps/vhunambi_client/lib/features/home/presentation/widgets/creation_launch_strip.dart`
    - `apps/vhunambi_client/lib/features/home/presentation/widgets/editorial_rhythm_spotlight_card.dart`
  - **Acceptance Criteria:**
    - `CreationLaunchStrip` mounts `home_create_studio_cta` + 4 non-duplicated tools (`home_hub_voice_clone`, `home_hub_melody_sketchpad`, `home_hub_beats_market`, `home_hub_asset_vault`) using only `*Of(context)` + `AppColors` tokens.
    - `EditorialRhythmSpotlightCard` paints bundled genre artwork + 3-stop dark editorial scrim (`0.48 -> 0.72 -> 0.90`) + `home_try_rhythm_btn` (`>=48dp`).

- [x] **Task `68.4.2` — Wire Complete `HomeDashboardView` & `RootShell` Explore Navigation**
  - **Target Files:**
    - `apps/vhunambi_client/lib/features/home/presentation/views/home_dashboard_view.dart`
    - `apps/vhunambi_client/lib/main.dart` (`RootShell` -> `onNavigateToExplore: () => _switchTab(1)`)
  - **Acceptance Criteria:** All 5 Main Room zones assemble cleanly on mobile (`<1025dp`) and 2-column desktop (`>=1025dp`), bottom padding uses `VhunambiBottomDockMetrics.scrollInset(hasActiveTrack: false)`, and `View all` routes cleanly to Tab 1 Explore.

- [x] **Task `68.4.3` — `STD-UIUX-001` Emoji & Icon Cleanup Across DNA, Synergy Deck & Upgrade Modal**
  - **Target Files:**
    - `apps/vhunambi_client/lib/features/creator_dna/presentation/widgets/dna_insight_card.dart`
    - `apps/vhunambi_client/lib/features/home/presentation/widgets/cross_module_synergy_deck.dart`
    - `apps/vhunambi_client/lib/features/home/presentation/widgets/subscription_upgrade_modal.dart`
  - **Acceptance Criteria:** Zero unicode emojis (`🧬`, `✨`, `🎯`), zero `Icons.close` / `Icons.check_circle_rounded`, zero `Icon(PhosphorIcons...)` calls (converted to `PhosphorIcon(...)`), and `>=48dp` close hit targets.

- [x] **Task `68.4.4` — Realign Existing Tests & Add Phase 68 Unit/Widget Suite**
  - **Target Files:**
    - Update `apps/vhunambi_client/test/features/home/home_dashboard_view_test.dart`: replace `'What are you feeling today?'` / `'Create ✨'` / `'AI Studio'` assertions with `home_create_studio_cta`, `home_allowance_pill`, `home_now_playing_card`, and `home_hub_beats_market`.
    - Update `apps/vhunambi_client/test/features/home/phase31_home_dashboard_convergence_test.dart`: realign Finding `HOME-003 & 004` (`home_hub_ai_studio` -> `home_create_studio_cta` + 4 tool cards) and Finding `HOME-006` (`findsWidgets` for filtered genre badge), keeping `HOME-001/002/005/007` green.
    - Update `apps/vhunambi_client/test/features/home/african_greeting_resolver_test.dart`: align celestial time test with emoji-free `getTimeGlyph()` & `GreetingIconType`.
    - Add `apps/vhunambi_client/test/features/home/phase68_main_room_overhaul_test.dart`:
      1. Artwork mapper covers all 10 `assets/artwork/` assets + `VhunambiTrackArtwork` fallback behavior.
      2. `CreatorAllowanceNotifier` HTTP 200 parse, offline resilience, and multi-tenant isolation.
      3. `NowPlayingHomeCard` scrub/play/pause/skip interactions + honest Empty State.
      4. `MiniPlayerHost` hides on Tab 0 when `homeInlineNowPlayingMountedProvider == true`, restores on Tab 1.
      5. Dual-theme Light ("Morning Mist") + Dark overflow-free rendering across `360x780`, `390x844`, and `1280x800` + `STD-UIUX-001` emoji-free greeting & Home tree check.

---

## 4. Stage 4 Anti-Trap Checklist & Verification Commands

### 4.1 Argon Anti-Trap Checklist (Verify Before Closing Stage 4)
- [x] Zero `TextField` widgets inside `HomeDashboardView` (no accidental soft-keyboard popup on Home).
- [x] Zero references to `seed-01`, `'Ndo Mufuna Matibe'`, or `'@Fifi'` fallback in Home.
- [x] `VhunambiTrackArtwork` uses `asset:` stripping cleanly and `AppAssets` lists exact 10 PNG filenames from `assets/artwork/`.
- [x] `NowPlayingHomeCard` keeps `'Jump Back In'` / `'Now Playing'` labels matching Finding `HOME-002` expectations.
- [x] `MainRoomHeader` uses 2-tier mobile pill row (`SingleChildScrollView(horizontal)`) preventing any `360dp` RenderFlex overflow while keeping `'5 Streak'` / `'250 Coins'` intact.
- [x] `MiniPlayerHost` requires BOTH `activeTab == 0 && homeInlineNowPlayingMountedProvider` so standalone player overlay tests remain 100% compatible.
- [x] Zero raw emojis (`✨`, `☀️`, `🌙`, `🎯`, `🧬`), zero `Icons.*`, zero `Icon(PhosphorIcons...)`, zero `AppTypography.labelSmall/labelMedium`.
- [x] Bounded test `pump(Duration)` steps only (no `pumpAndSettle()` loops around infinite shimmer/timers).

### 4.2 Stage 4 PowerShell Verification Commands (`--timeout=60s`)
```powershell
cd c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_client
flutter analyze
flutter test --timeout=60s test/features/home/home_dashboard_view_test.dart test/features/home/phase31_home_dashboard_convergence_test.dart test/features/home/phase68_main_room_overhaul_test.dart
flutter test --timeout=60s test/features/player/widgets/mini_player_host_test.dart test/features/player/phase33_adaptive_mini_player_test.dart
flutter test --timeout=60s test/features/notifications/
```
