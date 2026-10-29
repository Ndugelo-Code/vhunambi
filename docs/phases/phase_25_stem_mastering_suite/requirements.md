# Phase 25 Requirements: Stem Polisher, Adobe-Style Vocal Cleanse & Mobile/Desktop Mastering Suite

> **Phase:** 25 (`phase_25_stem_mastering_suite`)  
> **Standard:** RFC 2119 & EARS (Easy Approach to Requirements Syntax)  
> **Status:** `✅ COMPLETE`

---

## 1. Domain & Preset Requirements (`REQ-MST-DOM`)

- **REQ-MST-DOM-01 (Ubiquitous):** The system SHALL define an immutable `StemMasteringRecipe` contract shared identically between `apps/vhunambi_api` (TypeScript/Zod) and `apps/vhunambi_client` (Dart) containing `presetId`, `targetLufs` (`-9.5` or `-14.0`), and per-stem configurations for `vocals`, `bass`, `drums`, and `melodic`.
- **REQ-MST-DOM-02 (Ubiquitous):** The system SHALL provide 6 regional Genre Master Presets (`amapiano_club_knock`, `private_school_warmth`, `gqom_warehouse_sub`, `maskandi_acoustic_clarity`, `afro_house_horizon`, `kwaito_golden_tape`) and SHALL automatically resolve the default preset matching a track's `genre`.
- **REQ-MST-DOM-03 (Event-Driven):** WHEN a user selects a per-stem Character Flavor enum (`VocalCleanseFlavor`, `BassCharacterFlavor`, `DrumCharacterFlavor`, or `MelodicCharacterFlavor`), the system SHALL deterministically populate the corresponding underlying DSP parameters (`neuralDenoiseStrength`, `subHarmonicMix`, `knockDriveDb`, `sidechainDuckDb`, `transientAttackSnap`, `midVocalPocketCutDb`, `stereoWidthBoost`, and `StemEqBands`).
- **REQ-MST-DOM-04 (Event-Driven):** WHEN a user manually adjusts a continuous EQ or DSP slider on Desktop, the system SHALL update the stem's configuration and set `presetId` to `'custom'`.

---

## 2. Two-Tier Audition & Phase 24A Bridge Requirements (`REQ-MST-AUD`)

- **REQ-MST-AUD-01 (State-Driven):** WHILE `isMasteredPreviewActive` is `true` in `masteringSessionProvider`, the system SHALL apply real-time channel gain multipliers and `MasterBusDsp` overrides (`logDrumSaturation`, `vocalPlateReverb`, `sidechainCompression`, `stereoWidth`) to `stemMixerProvider` with zero network latency.
- **REQ-MST-AUD-02 (State-Driven):** WHILE `isMasteredPreviewActive` is `true`, `frameModulationSnapshotProvider` SHALL scale `effectiveBassEnergy`, `effectiveDrumsEnergy`, `effectiveMelodicEnergy`, `effectiveVocalGlow`, and `logDrumSnapZoom` according to the active `StemMasteringRecipe` so `KineticPreviewCanvas` immediately reflects the mastered audio dynamics at 60 FPS.
- **REQ-MST-AUD-03 (Event-Driven):** WHEN the user toggles the A/B Bypass control (`isMasteredPreviewActive = false`), the system SHALL immediately restore unity preview multipliers so the user can compare `[Raw AI]` against `[Studio Mastered]`.
- **REQ-MST-AUD-04 (State-Driven — Honest Master-Only Fallback):** WHILE `IMultiStemAudioEngine.hasRealStems` is `false`, the system SHALL still apply `MasterBusDsp` and `FrameModulationSnapshot` preview enhancements AND SHALL display a visible notice badge (`Key('mastering_master_only_notice')`) stating that full 4-stem neural isolation engages upon Cloud Studio Bake.

---

## 3. Backend API & Cloud GPU Worker Requirements (`REQ-MST-API`)

- **REQ-MST-API-01 (Event-Driven):** WHEN `POST /v1/generations/:id/master` is invoked with a valid `StemMasteringRecipe` body, `apps/vhunambi_api` SHALL validate the payload via Zod, enrich the job's `MasterMediaObjectManifest` modulation curves and mastered URLs (`masterMp3Url`, `masterWavUrl`), and return HTTP `200` with the updated manifest and mastering summary.
- **REQ-MST-API-02 (Unwanted/Error):** IF `POST /v1/generations/:id/master` is called with an unknown generation ID (outside deterministic `trk_` / `seed_` / `demo_` fallback IDs) or invalid schema, THEN `apps/vhunambi_api` SHALL return HTTP `404` or `400` respectively with structured error details.
- **REQ-MST-API-03 (Ubiquitous):** The Cloud GPU worker module `tools/zr-studio-gpu/stem_mastering_worker.py` SHALL implement `synthesize_sub_harmonic`, `apply_kick_sidechain_ducking` (driven by MMO `kick` transient timestamps), `apply_mid_side_vocal_pocket`, and `master_stems_with_recipe` calibrated via `pyloudnorm` and `pedalboard`.

---

## 4. Responsive Mobile & Desktop UI Requirements (`REQ-MST-UI`)

- **REQ-MST-UI-01 (State-Driven):** WHILE on a mobile viewport (`ResponsiveUtils.isMobile(context)`), tapping the Master Track trigger in `StemMixerDeck` or `TrackDetailView` SHALL open `MobileQuickMasterSheet` displaying the Genre Preset Rail, 4 Stem Character Pill selectors, A/B Bypass toggle, LUFS target selector, and Bake CTA.
- **REQ-MST-UI-02 (State-Driven):** WHILE on a desktop viewport (`ResponsiveUtils.isDesktop(context)`), tapping the Mastering Studio trigger SHALL open `DesktopMasteringStudioView` displaying the 4-Stem Sonar Console Rack with interactive 4-Band Parametric EQ curve graphs, Neural Vocal Cleanse sliders, Log-Drum Sub-Harmonic & Sidechain controls, M/S Stereo Width sliders, and LUFS / True-Peak meters.
- **REQ-MST-UI-03 (Ubiquitous — Touch & Token Discipline):** Every interactive pill, toggle, and button in `MobileQuickMasterSheet` and `DesktopMasteringStudioView` SHALL enforce a minimum `44×44dp` hit target (`minHeight: 44, minWidth: 44`) and SHALL use zero hardcoded hex colors or raw border radii.

---

## 5. Requirements Traceability Matrix

| Requirement ID | Target Files | Verification Type | Gate Command |
| :--- | :--- | :--- | :--- |
| `REQ-MST-DOM-01..04` | `stem_mastering_recipe.dart`, `mastering_types.ts`, `mastering_presets.ts` | Unit Tests | `flutter test test/features/mastering/stem_mastering_recipe_test.dart` |
| `REQ-MST-AUD-01..04` | `mastering_session_provider.dart`, `master_media_object_provider.dart` | Provider Unit Tests | `flutter test test/features/mastering/mastering_session_provider_test.dart` |
| `REQ-MST-API-01..03` | `generation_routes.ts`, `stem_mastering_worker.py`, `test/mastering.test.ts` | Backend API Tests | `pnpm test` (`apps/vhunambi_api`) |
| `REQ-MST-UI-01..03` | `mobile_quick_master_sheet.dart`, `desktop_mastering_studio_view.dart`, `stem_mixer_deck.dart`, `track_detail_view.dart` | Widget Tests | `flutter test test/features/mastering/` |

