# Phase 47: Motion-Graphics Onboarding Engine, 3D Stacked Vector Cards & Double-Helix DNA Genesis

> **Document Type:** Execution Tasks & Sequenced Checklist (Revision 2.1 — Zero-Summarization Law)  
> **Status:** APPROVED FOR IMPLEMENTATION  
> **Target Package:** `apps/vhunambi_client`  
> **Target Release:** Vhunambi V4.7 (Phase 47)  

---

## Track A: Eradicate the 5 Onboarding Bugs Caught on Device

- [ ] **T47-A.1:** Suppress `MiniPlayerHost` during Splash and Onboarding.
  - In `apps/vhunambi_client/lib/features/onboarding/presentation/views/splash_view.dart`: define and update `isSplashActiveProvider` (defaults to `true`, set to `false` when `_onSplashComplete()` finishes).
  - In `apps/vhunambi_client/lib/features/player/presentation/widgets/mini_player_host.dart`: update `_shouldHide` to check `ref.watch(isSplashActiveProvider)` and `!ref.watch(onboardingStateProvider).hasCompletedOnboarding`.
- [ ] **T47-A.2:** Eradicate the 12× Duplicate `"Amapiano"` genre chips bug.
  - In `apps/vhunambi_client/lib/features/onboarding/domain/models/onboarding_models.dart`: define `AfricanGenreModel` and `kAfricanOnboardingGenres` (12 unique genres with distinct accent colors and regional descriptions).
  - Retire `_genreToEnum` and replace with `TactileGenreCard`.
- [ ] **T47-A.3:** Eradicate the 5× Duplicate `"Energetic"` mood chips bug and retire radio-button questionnaire.
  - Replace stacked radio buttons (`tempoOptions`, `energyOptions`) with the interactive `VibeEnergySlider`.
  - Provide 5 distinct mood pills (`Soulful`, `Acoustic`, `Energetic`, `Club Groove`, `Spiritual`).
- [ ] **T47-A.4:** Unify onboarding into one 4-Act experience and fix truncated CTA button on 360dp mobile viewports.
  - In `apps/vhunambi_client/lib/features/onboarding/presentation/views/onboarding_view.dart`: collapse 6 slides into 4 interactive acts (`Act 1: Showcase`, `Act 2: Identity Stack`, `Act 3: Roots Deck`, `Act 4: DNA Genesis`).
  - Set CTA width to `double.infinity` with generous vertical padding so `"Activate My Creator DNA"` never truncates.
- [ ] **T47-A.5:** Add `"Replay Interactive Onboarding"` in `ProfileSettingsDrawer`.
  - In `apps/vhunambi_client/lib/features/profile/presentation/widgets/profile_settings_drawer.dart`: add list tile with `Key('settings_replay_onboarding_btn')` navigating to `OnboardingView`.

---

## Track B: Living Procedural Canvas & Music Visualizer

- [ ] **T47-B.1:** Create `apps/vhunambi_client/lib/features/onboarding/presentation/widgets/onboarding_procedural_canvas.dart`.
  - Implement 60 FPS `CustomPainter` (`_ConstellationBackdropPainter`) driven by continuous `AnimationController`.
  - Render 4 orbiting chromatic nodes (Amber `#F97316`, Cyan `#06B6D4`, Emerald `#10B981`, Gold `#F59E0B`) that stretch into pill capsules along swipe velocity vectors.
  - Render satellite particle fission and retrograde fusion orbits.
  - Paint 6 drifting translucent Phosphor vector glyphs (`musicNotes`, `waveform`, `vinylRecord`, `microphoneStage`, `sparkle`, `dna`).
  - Paint concentric acoustic soundwave ripple rings on touch interaction.

---

## Track C: 3D Stacked Interactive Vector Cards (Acts 1–3)

- [ ] **T47-C.1:** Act 1 — Living Sonic Showcase (`Key('onboarding_act_1_showcase')`).
  - Pulsing Vhunambi central emblem with 4 orbiting world nodes (*AI Studio & Stems*, *Sovereign Voice DNA*, *5-Channel Groove*, *Kinetic Social & 85% ZAR Market*).
  - Interactive tap interaction expanding feature benefits.
- [ ] **T47-C.2:** Act 2 — 3D Stacked & Fanned Identity Tarot Deck (`interactive_identity_card_stack.dart`, `Key('onboarding_act_2_identity_deck')`).
  - 5 stacked physical cards for `Producer & Beatmaker`, `Natural Vocalist`, `DAW Master & Artist`, `Live Instrumentalist`, `Kinetic Creator & Curator`.
  - Programmatically painted vector art (`StepSequencerGridPainter`, `CondenserMicPainter`, `MultiFaderPainter`, `GuitarStringsPainter`, `TurntablePainter`). Zero raw emojis (`STD-UIUX-001`).
  - 3D matrix spring physics (`Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(...)..scale(...)`) on swipe or tap.
- [ ] **T47-C.3:** Act 3 — Tactile Genre Vinyl Cards & Interactive Vibe/Language Orbs (`Key('onboarding_act_3_roots_deck')`).
  - Top half: 12× `TactileGenreCard` with dancing 3-band equalizer bars.
  - Middle: `TactileVibeEnergySlider` (`Key('onboarding_vibe_slider')`) modulating canvas visualizer frequency.
  - Bottom half: 10× `IndigenousLanguageOrb` (`Tshivenḓa`, `isiZulu`, `isiXhosa`, `Sepedi`, etc.).

---

## Track D: Act 4 Finale — 3D Double-Helix Creator DNA & Particle Genesis

- [ ] **T47-D.1:** Create `apps/vhunambi_client/lib/features/onboarding/presentation/widgets/creator_dna_helix_finale.dart`.
  - 3D rotating Double-Helix DNA strand (`CreatorDnaHelixPainter`) with 14 rungs colored and textured with user's selected genres, tongues, and craft identity.
  - Touch-reactive spin and particle emission.
  - Prominent full-width glowing CTA button (`Key('onboarding_launch_studio_btn')`).
  - 400ms Particle Vortex / Portal Reveal on tap before navigating to `RootShell`.

---

## Track E: Verification Gates & Release Deployment

- [ ] **T47-E.1:** Verify backward compatibility with existing tests in `test/features/onboarding/onboarding_notifier_test.dart` and `test/features/onboarding/splash_view_test.dart`.
- [ ] **T47-E.2:** Author `apps/vhunambi_client/test/features/onboarding/phase47_motion_onboarding_and_dna_helix_test.dart`:
  - Test 1: Zero duplicate "Amapiano" or "Energetic" chips in the catalog.
  - Test 2: `MiniPlayerHost` is suppressed during Splash and incomplete onboarding.
  - Test 3: 3D Stacked Identity Deck updates `onboardingStateProvider.creativeRole`.
  - Test 4: Act 3 Genre Cards and Vibe Energy Slider update state without duplicate chips.
  - Test 5: Act 4 Double-Helix DNA Genesis renders and completes onboarding cleanly.
  - Test 6: `ProfileSettingsDrawer` renders `settings_replay_onboarding_btn` and triggers replay.
- [ ] **T47-E.3:** Run `dart analyze lib test` $\rightarrow$ 0 issues found.
- [ ] **T47-E.4:** Run full regression suite across all features $\rightarrow$ 100% green.
- [ ] **T47-E.5:** Compile ARM64 release APK (`flutter build apk --release --target-platform android-arm64 --no-pub`).
- [ ] **T47-E.6:** Stream-install to physical hardware `EPHUT20917014649`, launch app, update `AGENT_HANDOFF_BIBLE.md`, commit and push to Git.

