# Phase 49 Implementation Tasks: MMORPG Creator DNA Helix & Generation Onboarding

## Pre-Flight Baseline
- [x] Baseline: `dart analyze lib test` → 0 issues found!
- [x] Baseline: Phase 47 onboarding test suite green (6/6)
- [x] Baseline: Phase 48 sync test suite green (8/8)
- [x] Baseline: Backend tests green (15/15)

---

## Track A: Bouncy Typography & Backdrop Staging (Fixing 00:05–00:16)

### T1.1 Expressive Bouncy Display Typography
- [ ] Add `bouncyDisplayLarge`, `bouncyTitleLarge`, and `bouncyBadge` to `apps/vhunambi_client/lib/core/theme/app_typography.dart`.
- [ ] Utilize GoogleFonts (`Outfit` / `Plus Jakarta Sans`) with system font fallbacks.
- [ ] Wire entrance spring curves (`Curves.easeOutBack`) to `onboarding_act1_showcase.dart`.

### T1.2 Confine Backdrop Constellation Nodes & Add Vignette
- [ ] Update `apps/vhunambi_client/lib/features/onboarding/presentation/widgets/onboarding_procedural_canvas.dart`.
- [ ] Restrict primary constellation orbits to $Y \in [0.18H, 0.38H]$ centered around the Vhunambi crest.
- [ ] Paint a soft radial/vertical legibility vignette behind title and button zones.

---

## Track B: Opaque 3D Card Fan & Bleed Eradication (Fixing 00:17–00:26)

### T2.1 Solid Opaque Surface for Active Card
- [ ] In `apps/vhunambi_client/lib/features/onboarding/presentation/widgets/interactive_identity_card_stack.dart`, set active front card (`relativeDiff == 0`) background to 100% opaque surface (`AppColors.surfaceElevatedOf(context)` with `alpha: 1.0`).
- [ ] Layer with 14% accent color gradient and 2.0dp glowing border.

### T2.2 Suppress Body Content on Background Cards
- [ ] In `interactive_identity_card_stack.dart`, wrap inner card content in `Opacity(opacity: relativeDiff == 0 ? 1.0 : 0.0)`.
- [ ] Set background cards vertical offset to `translateY = -relativeDiff.abs() * 14.0dp` and scale `1.0 - relativeDiff.abs() * 0.055`.

### T2.3 Add Explicit Horizontal Navigation Arrows
- [ ] Add left and right arrow buttons (`Key('identity_stack_prev_btn')` & `Key('identity_stack_next_btn')`) to `interactive_identity_card_stack.dart` for accessibility on physical devices.

---

## Track C: Generation-Aware Roots Deck (Fixing 00:32–00:53)

### T3.1 Domain Models & Generation Era Enum
- [ ] In `apps/vhunambi_client/lib/features/onboarding/domain/models/onboarding_models.dart`, add `SonicGenerationEra` enum with `fromBirthYear(int year)` and `recommendedGenres`.
- [ ] Add `birthYear` (default 2002), `generationEra`, and `culturalHeritage` to `OnboardingState`.
- [ ] Add `setBirthYear(int year)` and `autotuneEraGenres()` to `OnboardingNotifier` in `onboarding_providers.dart`.

### T3.2 Redesign Act 3 (African Roots & Era)
- [ ] In `apps/vhunambi_client/lib/features/onboarding/presentation/widgets/onboarding_act3_roots_deck.dart`, remove the redundant `Vibe Energy & Tempo Feel` 4-box section.
- [ ] Implement Tier 1: Interactive Birth Year Dial (`Key('onboarding_birth_year_selector')`) + Generation Badge + 1-tap `[ Auto-Tune Era Genres ]` button (`Key('onboarding_autotune_era_btn')`).
- [ ] Implement Tier 2: Compact Language & Cultural Orbs (`Key('onboarding_culture_language_orbs')`).
- [ ] Implement Tier 3: Era-Recommended Genre Rail (`Key('onboarding_era_genre_deck')`) with glowing `"✨ Era Match"` tag on matching genres.

---

## Track D: MMORPG 3D DNA Helix & Main App Integration (Fixing 00:54–01:13)

### T4.1 Create `CreatorDnaNode` Model
- [ ] Create `apps/vhunambi_client/lib/features/profile/domain/models/creator_dna_node.dart` defining 8 genomic loci (4 unlocked in onboarding, 4 locked studio quests).

### T4.2 Upgrade `CreatorDnaHelixFinale` (Act 4)
- [ ] In `apps/vhunambi_client/lib/features/onboarding/presentation/widgets/creator_dna_helix_finale.dart`, render 8 discrete nodes on the 3D double-helix.
- [ ] Implement tap-to-inspect hit-testing within 28dp proximity.
- [ ] Render pulsating target halo on the active node.
- [ ] Render MMORPG Node Inspector Card (`Key('dna_node_inspector_card')`) at the bottom of the helix.
- [ ] Map `CreativeRole` to friendly title (e.g. `'Kinetic Creator & Curator'`) — NEVER raw `'MUSICLOVER'`.

### T4.3 Create `CreatorDnaHelixLabSheet`
- [ ] Create `apps/vhunambi_client/lib/features/profile/presentation/widgets/creator_dna_helix_lab_sheet.dart` for the full-screen interactive 3D DNA Lab modal.

### T4.4 Mount 3D DNA Lab in Main App
- [ ] Update `apps/vhunambi_client/lib/features/profile/presentation/widgets/creator_dna_profile_card.dart` to embed an interactive 3D Mini-Helix and a `[ 🧬 Open 3D DNA Lab ]` button (`Key('open_3d_dna_lab_btn')`) launching `CreatorDnaHelixLabSheet`.

---

## Track E: Verification Gates & Release Deployment

### T5.1 Author Phase 49 Test Suite
- [ ] Create `apps/vhunambi_client/test/features/onboarding/phase49_mmorpg_dna_and_generation_onboarding_test.dart` testing:
  - 100% opaque front card in `InteractiveIdentityCardStack`.
  - Birth Year Dial updates `SonicGenerationEra` and era-recommended genres.
  - Tapping DNA nodes opens `dna_node_inspector_card` with friendly titles and quest info.
  - Launching `CreatorDnaHelixLabSheet` via `open_3d_dna_lab_btn`.

### T5.2 Static Analysis & Test Verification Gates
- [ ] Run `dart analyze apps/vhunambi_client/lib apps/vhunambi_client/test` → 0 issues found!
- [ ] Run `flutter test test/features/onboarding/ test/features/profile/` → 100% green.

### T5.3 Physical Device Deployment & Documentation
- [ ] Build ARM64 release APK (`flutter build apk --release --target-platform android-arm64 --no-pub`).
- [ ] Stream-install via ADB to `EPHUT20917014649`.
- [ ] Launch application on device.
- [ ] Update `docs/AGENT_HANDOFF_BIBLE.md` with Section 25 (Phase 49).
- [ ] Git commit and push to `origin/fix/studio-cockpit-bugs-vh001-vh006`.

---

## Known Traps & Mitigations

| Trap | Root Cause | Mandatory Defense |
|---|---|---|
| Card Bleed Through | Background cards rendering text with translucent alpha | Set inner content opacity to 0.0 for cards at `relativeDiff != 0` and active card background to alpha 1.0 |
| Constellation Text Collision | Unbounded random particle coordinates | Constrain orbiters to central emblem stage $[0.18H, 0.38H]$ with radial vignette mask |
| 3D Touch Miss on Small Screens | Fixed coordinate raycasting | Use 28dp screen-space euclidean proximity formula + horizontal node pill carousel fallback |
| Infinite Loop on Repeated Animation | `AnimationController.repeat()` prevents `pumpAndSettle` | Use explicit duration pumps (`tester.pump(Duration(milliseconds: 100))`) in widget tests |
| Raw Enum String Exposure | Calling `.toString()` or `.name.toUpperCase()` on enums | Use dedicated `.title` or `.label` extensions for human-friendly copy |

