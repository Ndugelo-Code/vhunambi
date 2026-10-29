# Phase 25 Tasks: Stem Polisher, Adobe-Style Vocal Cleanse & Mobile/Desktop Mastering Suite

> **Phase:** 25 (`phase_25_stem_mastering_suite`)  
> **Status:** `✅ COMPLETE`

---

## 1. Pre-Flight Verification Checklist
- [x] `docs/VHUNAMBI_V4_STUDIO_EVOLUTION_BLUEPRINT.md` authored and aligned with monorepo phase numbering.
- [x] Baseline `dart analyze .` in `apps/vhunambi_client` = `0 issues`.
- [x] Baseline `pnpm test` in `apps/vhunambi_api` = `7/7 suites passing`.

---

## 2. Sequenced Implementation Tracks

### Track A: Backend Mastering Module, API Endpoint & Cloud GPU Worker
- [x] **T1.1 (`apps/vhunambi_api/src/modules/mastering/mastering_types.ts`) (new):** Define Zod schemas and TypeScript interfaces for `VocalCleanseFlavor`, `BassCharacterFlavor`, `DrumCharacterFlavor`, `MelodicCharacterFlavor`, `StemEqBands`, and `StemMasteringRecipe`.
- [x] **T1.2 (`apps/vhunambi_api/src/modules/mastering/mastering_presets.ts`) (new):** Implement the 6 regional Genre Master Presets (`amapiano_club_knock`, `private_school_warmth`, `gqom_warehouse_sub`, `maskandi_acoustic_clarity`, `afro_house_horizon`, `kwaito_golden_tape`), `getMasteringPresetForGenre()`, and `enrichManifestWithMasteringRecipe()` to boost `Uint8` Base64 modulation curves on bake.
- [x] **T1.3 (`apps/vhunambi_api/src/routes/generation_routes.ts`) (modify):** Add `GET /v1/generations/mastering/presets` and `POST /v1/generations/:id/master` validating `StemMasteringRecipe`, updating job store assets & MMO manifest, and returning mastered URLs + enriched manifest.
- [x] **T1.4 (`tools/zr-studio-gpu/stem_mastering_worker.py` & `docs/RUNPOD_MMO_WORKER_SPEC.md`) (new/modify):** Implement `synthesize_sub_harmonic`, `apply_kick_sidechain_ducking`, `apply_mid_side_vocal_pocket`, and `master_stems_with_recipe` using `pedalboard` and `pyloudnorm`, and document in `RUNPOD_MMO_WORKER_SPEC.md`.
- [x] **T1.5 (`apps/vhunambi_api/test/mastering.test.ts` & `package.json`) (new/modify):** Author backend test suite (preset resolution, Zod validation, `POST /v1/generations/:id/master` curve boost & 400/404 handling) and wire into `pnpm test` (8/8 suites green).

### Track B: Client Domain Models & Preset Engine
- [x] **T2.1 (`apps/vhunambi_client/lib/features/mastering/domain/models/stem_mastering_recipe.dart`) (new):** Implement `VocalCleanseFlavor`, `BassCharacterFlavor`, `DrumCharacterFlavor`, `MelodicCharacterFlavor`, `StemEqBands`, per-stem config classes, `StemMasteringRecipe`, `GenreMasterPreset`, and the 6 regional presets with JSON serialization and flavor-to-DSP mapping.

### Track C: Riverpod State Management & Phase 23/24A Coupling
- [x] **T3.1 (`apps/vhunambi_client/lib/features/mastering/presentation/providers/mastering_session_provider.dart`) (new):** Implement `MasteringSessionState` and `MasteringSessionNotifier` with Tier A live preview coupling into `stemMixerProvider` (both `hasRealStems == true` and `hasRealStems == false` Master-Only fallback) and Tier B bake orchestration.
- [x] **T3.2 (`apps/vhunambi_client/lib/features/content_studio/presentation/providers/master_media_object_provider.dart`) (modify):** Couple `masteringSessionProvider` multipliers into `frameModulationSnapshotProvider` so `effectiveBassEnergy`, `effectiveVocalGlow`, and `logDrumSnapZoom` respond in real time to mastering changes and A/B bypass toggles.

### Track D: Responsive Mobile & Desktop Mastering UI Surfaces
- [x] **T4.1 (`apps/vhunambi_client/lib/features/mastering/presentation/widgets/mobile_quick_master_sheet.dart`) (new):** Build `MobileQuickMasterSheet` with Genre Preset Rail, Honest Master-Only notice badge (`Key('mastering_master_only_notice')`), 4 Stem Character Pill selectors (`44×44dp` touch targets), `[Raw AI]` $\leftrightarrow$ `[Studio Mastered]` A/B toggle, LUFS target selector, and `"✨ Bake Production Track"` CTA.
- [x] **T4.2 (`apps/vhunambi_client/lib/features/mastering/presentation/views/desktop_mastering_studio_view.dart`) (new):** Build `DesktopMasteringStudioView` Cakewalk/Sonar-style 4-stem console with interactive 4-Band Parametric EQ curve painters, Neural Vocal Cleanse sliders, Log-Drum Sub-Harmonic & Sidechain controls, M/S Stereo Width sliders, and LUFS / True-Peak meters.
- [x] **T4.3 (`stem_mixer_deck.dart` & `track_detail_view.dart`) (modify):** Wire `"✨ Master Track"` / `"🎚️ Mastering Studio"` entrypoints branching on `ResponsiveUtils.isDesktop(context)`.

### Track E: Automated Verification Suites
- [x] **T5.1 (`test/features/mastering/stem_mastering_recipe_test.dart`) (new):** Unit tests for `StemMasteringRecipe`, JSON round-tripping, genre auto-matching, and flavor-to-DSP parameter mapping.
- [x] **T5.2 (`test/features/mastering/mastering_session_provider_test.dart`) (new):** Provider tests for Tier A coupling with `stemMixerProvider`, `frameModulationSnapshotProvider`, A/B bypass toggle, Master-Only fallback, and Tier B bake completion.
- [x] **T5.3 (`test/features/mastering/mobile_quick_master_sheet_test.dart` & `desktop_mastering_studio_view_test.dart`) (new):** Widget tests verifying Mobile 1-Tap Character Pills, Honest Master-Only notice badge, A/B toggle, Desktop 4-stem console sliders, and entrypoint navigation.

