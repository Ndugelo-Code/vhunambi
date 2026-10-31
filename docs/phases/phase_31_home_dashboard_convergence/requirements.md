# Phase 31: V4.1 Creator Home Dashboard Convergence — Requirements
**Phase:** 31  
**Status:** Approved & Ready for Execution  

---

## 1. Functional Requirements

### Track A: Header, Economy & Momentum
- **REQ-HOME-HDR-01**: Top bar streak pill MUST be bound to `ref.watch(ownerProfileProvider).dayStreak`, rendering `'🔥 $dayStreak'` and tagged with `Key('home_streak_pill')`.
- **REQ-HOME-HDR-02**: Top bar currency chip MUST be bound to `ref.watch(creatorWalletProvider).userCoinsBalance`, rendering `'🪙 $coins Coins'` and tagged with `Key('home_coins_pill')`. Tapping it MUST trigger `SubscriptionUpgradeModal.show(context)` to preserve existing test Pin #8.
- **REQ-HOME-HDR-03**: Top bar MUST include a 1-step Notification Bell button (`Key('home_notifications_btn')`, touch target $\ge 44 \times 44\text{dp}$) navigating directly to `NotificationsView`.
- **REQ-HOME-HDR-04**: Top bar greeting layout MUST use flexible text wrapping so that indigenous greetings in any South African language do not cause RenderFlex overflows on a 360dp mobile viewport.
- **REQ-HOME-HDR-05**: When `generationProgressProvider` reports `isGenerating == true`, the home dashboard MUST render a conditional in-flight generation banner (`Key('home_inflight_generation_banner')`) displaying track title and progress percent, tapping to `onNavigateToStudio`.

### Track B: Personal Vault "Jump Back In"
- **REQ-HOME-VAULT-01**: The "Jump Back In" card MUST watch `libraryTracksProvider` (filtering out trashed tracks `!t.isTrashed`).
- **REQ-HOME-VAULT-02**: If the user has library tracks, the card MUST display the most recent personal track, showing title, creator name, genre, duration, and genre gradient.
- **REQ-HOME-VAULT-03**: The card play button MUST invoke `ref.read(playerStateProvider.notifier).playTrack(track)` (satisfying test Pin #9).
- **REQ-HOME-VAULT-04**: The card MUST expose a "Polish / Stems" action (`Key('home_jump_back_master_btn')`) that opens `MobileQuickMasterSheet` (on mobile) or `DesktopMasteringStudioView` (on desktop).
- **REQ-HOME-VAULT-05**: If the user library is empty, the card MUST fall back gracefully to `exploreTracks.first` (or a default track) without throwing exceptions.

### Track C: Responsive 6-Tool Creation Hub
- **REQ-HOME-HUB-01**: The Quick Actions section MUST render a 2-Row × 3-Column Grid on mobile (`< 768dp`) and a 6-Column Row on desktop (`\ge 768dp`).
- **REQ-HOME-HUB-02**: The Hub MUST present 6 distinct tools:
  1. `AI Studio` (`Key('home_hub_ai_studio')`) → calls `onNavigateToStudio`.
  2. `Voice Clone` (`Key('home_hub_voice_clone')`) → opens `VocalIdentityPickerSheet.show(context)`.
  3. `Sketchpad` (`Key('home_hub_melody_sketchpad')`) → opens `MelodySketchpadModal.show(context)`.
  4. `Stem Lab` (`Key('home_hub_stem_master')`) → opens `MobileQuickMasterSheet` or `DesktopMasteringStudioView`.
  5. `Beats Market` (`Key('home_hub_beats_market')`) → calls `onNavigateToMarket`.
  6. `Asset Vault` (`Key('home_hub_asset_vault')`) → calls `onNavigateToLibrary`.
- **REQ-HOME-HUB-03**: All 6 tiles MUST have touch targets satisfying Apple HIG $\ge 44 \times 44\text{dp}$.

### Track D: Indigenous Rhythm Matrix & Genre Scoping
- **REQ-HOME-RHYTHM-01**: Implement `AfricanRhythmSpotlight` and `AfricanRhythmMatrix` mapping Monday (1) through Sunday (7) to the 7 canonical regional African genres (Amapiano, Gqom, Malonde, Maskandi, Kwaito, Afro-Tech, Gospel).
- **REQ-HOME-RHYTHM-02**: The active rhythm spotlight MUST accept an optional injected weekday (defaulting to `DateTime.now().weekday`) for deterministic testing.
- **REQ-HOME-RHYTHM-03**: Tapping "Try Rhythm" (`Key('home_try_rhythm_btn')`) MUST inject genre, BPM, scale, and sample prompt into `studioFormProvider` and `melodySketchpadProvider`, then invoke `onNavigateToStudio`.
- **REQ-HOME-GENRE-01**: "Trending in Your Genres" MUST filter `exploreTracks` using the creator's `onboardingState.selectedGenres`. If no genres are selected or no tracks match, it MUST fall back to the full catalog.

---

## 2. Backward Compatibility & Test Constraints

- **REQ-HOME-TEST-01**: All 10 test pins from `home_dashboard_view_test.dart` must pass unchanged:
  1. `Key('home_avatar_btn')`
  2. `Key('home_greeting_text')`
  3. String `'What are you feeling today?'`
  4. String `'Create ✨'`
  5. String `'AI Studio'`
  6. String `'Beats Market'`
  7. String `'Asset Vault'`
  8. String `'Jump Back In'`
  9. Tapping play on "Jump Back In" starts playback in `playerStateProvider`
  10. Tapping credit/coin chip opens `SubscriptionUpgradeModal`
- **REQ-HOME-TEST-02**: Static analysis with `dart analyze lib test` MUST report 0 issues.

