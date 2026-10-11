# Phase 22 · Tasks — Heritage Crate Digging & Native Video Muxer

> **Phase:** 22  
> **Codename:** `heritage-crate-and-video-muxer`  
> **Status:** 🟡 READY FOR IMPLEMENTATION  
> **Target Apps:** `apps/vhunambi_client`  
> **Standard:** Dual-Agent Pair Programming Standard ([`docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md))  

---

## Pre-Flight Check Matrix

- [x] Baseline static analysis passes with 0 issues (`dart analyze apps/vhunambi_client`).
- [x] Baseline test suites pass 100% across existing player, social, studio, and content_studio features.
- [x] Working tree clean on `main` at `0e65fb1`.

---

## Sequenced Implementation Tasks

### T1: Foundation — Heritage Crate Domain & Riverpod Notifier (Architect)
- [x] Implement `HeritageCrateCategory`, `HeritageSampleEntity`, `HeritageCrateState` in `lib/features/studio/domain/models/heritage_crate_models.dart`.
- [x] Implement `HeritageCrateNotifier` and `heritageCrateProvider` in `lib/features/studio/presentation/providers/heritage_crate_provider.dart`.
- [x] Seed authentic indigenous samples: Mbira DzaVadzimu, Kora Griot Pluck, Talking Drum, Marimba, Uhadi Bow, Folk Chants.
- [x] **Verification**: Unit tests in `test/features/studio/heritage_crate_provider_test.dart` (5/5 tests passing).

### T2: Foundation — 8-Pad AI MPC Slicer Domain & Notifier (Architect)
- [x] Implement `MpcPadEntity`, `MpcSlicerState` in `lib/features/studio/domain/models/heritage_crate_models.dart`.
- [x] Implement `MpcSlicerNotifier` and `mpcSlicerProvider` in `lib/features/studio/presentation/providers/heritage_crate_provider.dart`.
- [x] Implement transient auto-slicing into 8 pads, semitone pitch shifting (−12..+12), reverse toggle, and DAW bounce bridge.
- [x] **Verification**: Unit tests in `test/features/studio/heritage_crate_provider_test.dart` (7/7 tests passing).

### T3: Foundation — Native Video Muxer Domain & Social Export Provider (Architect)
- [x] Implement `VideoExportResolution`, `SocialShareTarget`, `VideoExportStatus`, `VideoExportJob`, `VideoExportState` in `lib/features/social/domain/models/video_export_job.dart`.
- [x] Implement `VideoExportNotifier` and `videoExportProvider` in `lib/features/social/presentation/providers/video_export_provider.dart`.
- [x] Implement viral caption generator (`#Amapiano #Vhunambi #Afrobeats #LogDrum`), watermark toggle, and simulated background render loop.
- [x] **Verification**: Unit tests in `test/features/social/video_export_provider_test.dart` (5/5 tests passing).

### T4: UI Presentation — Heritage Crate Browser & 8-Pad MPC Slicer Deck (Cline)
- [ ] Implement `CrateBrowserDeck` in `lib/features/studio/presentation/widgets/crate_browser_deck.dart` (spinning vinyl disk, category pills, sample audition, chop trigger).
- [ ] Implement `MpcSlicerDeck` in `lib/features/studio/presentation/widgets/mpc_slicer_deck.dart` (4×2 tactile pads, pitch slider, reverse switch, "Send to Stem Mixer" / "Record into Studio" action buttons).
- [ ] Mount in `StudioView` drawer or tab.
- [ ] **Verification**: Widget tests in `test/features/studio/widgets/crate_browser_deck_test.dart` and `mpc_slicer_deck_test.dart`.

### T5: UI Presentation — Video Export Modal & Direct Social Share Rail (Cline)
- [ ] Implement `VideoExportModal` in `lib/features/social/presentation/widgets/video_export_modal.dart` (9:16 vs 1:1 selector, FPS toggle, render progress bar, viral caption copy box).
- [ ] Implement `SocialShareRail` with 1-tap buttons for TikTok, Instagram Reels, YouTube Shorts, and Save to Gallery.
- [ ] Mount trigger in `ContentStudioDockView` / `ExpandedCockpitModal`.
- [ ] **Verification**: Widget tests in `test/features/social/widgets/video_export_modal_test.dart`.

### T6: Quality Gates, Static Analysis & Documentation (Lead)
- [ ] Run `dart analyze apps/vhunambi_client` ensuring 0 issues (`No issues found!`).
- [ ] Run all targeted `flutter test` suites ensuring 100% pass rate.
- [ ] Update `docs/AGENT_HANDOFF_BIBLE.md` and `README.md`.
- [ ] Atomic git commit on `main`.
