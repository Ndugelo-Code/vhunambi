# Phase 31: V4.1 Creator Home Dashboard Convergence — Task Sequence
**Phase:** 31  
**Status:** Approved & Ready for Execution  

---

## Task Breakdown

### Track A: Domain Models & 7-Day Indigenous Rhythm Matrix
- [ ] **Task 31.1**: Create `lib/features/home/domain/models/african_rhythm_matrix.dart` with `AfricanRhythmSpotlight` and `AfricanRhythmMatrix.forWeekday([int? weekday])` covering the 7 regional genres.
- [ ] **Task 31.2**: Unit test `AfricanRhythmMatrix` in `test/features/home/african_rhythm_matrix_test.dart` verifying all 7 days of the week, default fallbacks, and scale/BPM parameters.

### Track B: Live Economy, Momentum & Overflow-Safe Header
- [ ] **Task 31.3**: In `home_dashboard_view.dart`, wire live state:
  - Streak pill bound to `ownerProfile.dayStreak` (`Key('home_streak_pill')`).
  - Coin pill bound to `creatorWallet.userCoinsBalance` (`Key('home_coins_pill')`), with tap opening `SubscriptionUpgradeModal.show`.
  - Notification bell action (`Key('home_notifications_btn')`) pushing `NotificationsView`.
  - 2-line adaptive greeting layout ensuring no RenderFlex overflows at 360dp width.
- [ ] **Task 31.4**: Add conditional in-flight generation progress banner (`Key('home_inflight_generation_banner')`) watching `generationProgressProvider`.

### Track C: True Personal Vault "Jump Back In"
- [ ] **Task 31.5**: Re-wire `_buildJumpBackInCard` in `home_dashboard_view.dart` to watch `libraryTracksProvider` (filtering `!t.isTrashed`).
- [ ] **Task 31.6**: Add `Key('home_jump_back_master_btn')` ("Polish / Stems") opening `MobileQuickMasterSheet` on mobile or `DesktopMasteringStudioView` on desktop with the track's metadata.

### Track D: Responsive 6-Tool Creation Hub
- [ ] **Task 31.7**: Replace the rigid 4-card `Row` in `home_dashboard_view.dart` with a responsive Creation Hub: 2-Row × 3-Column Grid on Mobile (`< 768px`) and 6-Column Row on Desktop (`\ge 768px`).
- [ ] **Task 31.8**: Mount all 6 tool cards preserving legacy keys/strings (`AI Studio`, `Beats Market`, `Asset Vault`, `Stem Lab`) and adding `Voice Clone` and `Sketchpad`.

### Track E: Dynamic Rhythm Spotlight & Genre Scoping
- [ ] **Task 31.9**: Wire "Daily Rhythm Spotlight" banner to `AfricanRhythmMatrix.forWeekday()`.
- [ ] **Task 31.10**: Wire "Try Rhythm" button (`Key('home_try_rhythm_btn')`) to inject genre, BPM, musical key, and sample prompt into `studioFormProvider` and `melodySketchpadProvider`, then invoke `onNavigateToStudio`.
- [ ] **Task 31.11**: Fix "Trending in Your Genres" ListView to filter `exploreTracks` by `onboardingState.selectedGenres`, falling back cleanly to the full catalog.

### Track F: Test Suite & End-to-End Verification
- [ ] **Task 31.12**: Update `test/features/home/home_dashboard_view_test.dart` to ensure all 10 legacy test pins continue to pass.
- [ ] **Task 31.13**: Create `test/features/home/phase31_home_dashboard_convergence_test.dart` verifying all Phase 31 requirements (`HOME-001` to `HOME-008`), including 360×800 viewport check.
- [ ] **Task 31.14**: Run full verification gates:
  - `dart analyze lib test` (0 issues found)
  - `flutter test test/features/home test/features/profile test/features/explore test/features/social test/features/marketplace`
  - `pnpm test` in `apps/vhunambi_api` (11/11 suites)

