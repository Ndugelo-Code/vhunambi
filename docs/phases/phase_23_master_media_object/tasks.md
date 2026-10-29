# Phase 23 · Tasks & Implementation Sequence — The Executable Master Media Object (MMO v2.0)

> **Phase:** 23  
> **Codename:** `master-media-object-v2`  
> **Target Apps:** `apps/vhunambi_api`, `apps/vhunambi_client`  
> **Status:** Completed & Verified ✅  

---

## Pre-Flight Baseline Checks

- [x] **P1:** Verify backend test suite health: `pnpm test` in `apps/vhunambi_api` (Target: 6/6 suites passing).
- [x] **P2:** Verify client analyzer health: `dart analyze apps/vhunambi_client` (Target: No issues found!).
- [x] **P3:** Verify client test suite health: `flutter test` in `apps/vhunambi_client` (Target: 1030/1030 tests passing).

---

## Phase 23.1: Backend Schema & Manifest Compiler (`apps/vhunambi_api`)

- [x] **T1:** Update `src/modules/dna/dna_types.ts` with `StemRole`, `TransientEventType`, `TransientEvent`, `MpcPadSliceManifest`, `SongSectionBlueprint`, `LyricWordTimestampV2`, and `MasterMediaObjectManifest` (`REQ-MMO-01`, `REQ-MMO-02`, `REQ-MMO-06`).
- [x] **T2:** Implement `compileMasterMediaObjectManifest()` in `src/modules/dna/dna_compiler.ts` with deterministic BPM-locked 60 Hz quantized `Uint8` Base64 curves via 16-step genre beat-grids (Amapiano log-drum drop syncopation, Gqom broken beats, Maskandi guitar pulses), `transientEvents`, and the 8-pad role-stratified `mpcKitPads` array (`REQ-MMO-03`, `REQ-MMO-04`, `REQ-MMO-05`).
- [x] **T3:** Add route `GET /v1/generations/:id/manifest` in `src/routes/generation_routes.ts` returning the manifest with status 200, or 404 if not found (`REQ-MMO-07`).
- [x] **T4:** Update `src/routes/webhook_routes.ts` to accept optional `manifest_url` in the webhook payload (`REQ-MMO-08`).
- [x] **T5:** Create backend test suite `test/mmo.test.ts` and add to `package.json` `"test"` script, verifying curve serialization length ($\le 15\text{ KB}$), Base64 integrity, and route 200 response.
- [x] **T6:** Backend Verification Gate: Run `pnpm build && pnpm test` in `apps/vhunambi_api` (Target: 0 TS errors, 7/7 suites green).

---

## Phase 23.2: Client Domain Models & Persistence (`apps/vhunambi_client`)

- [x] **T7:** Add `mmoBoxKey = 'vhunambi_mmo_manifest_box'` to `lib/core/constants/app_constants.dart`.
- [x] **T8:** Update `LyricWordTimestamp` in `lib/features/content_studio/domain/models/lyric_word_timestamp.dart` with optional `phoneticStress` (`double`, default `0.5`) and `isCulturalIdiom` (`bool`, default `false`) (`REQ-MMO-06`).
- [x] **T9:** Create `lib/features/content_studio/domain/models/master_media_object.dart` with `MasterMediaObject`, `ModulationTelemetryBus`, `TransientEventEntity`, `MpcPadSliceManifest`, bidirectional wire-format mappers (`stemTypeFromWireString` / `transientTypeFromWireString`), O(1) curve sampling, and authentic 16-step beat-grid `fromSongMetadataDna()` fallback (`REQ-MMO-01`, `REQ-MMO-03`, `REQ-MMO-09`, `REQ-MMO-10`).
- [x] **T10:** Create `lib/features/content_studio/presentation/providers/master_media_object_provider.dart` with Hive cache, headless in-memory test fallback, Dart 3 Record `FrameModulationQuery`, and `frameModulationSnapshotProvider` coupled to all 4 channel gains in `stemMixerProvider` (`REQ-MMO-10`, `REQ-MMO-11`).
- [x] **T11:** Add unit test suite `test/features/content_studio/domain/models/master_media_object_test.dart` verifying Base64 decoding, O(1) sampling, transient impulse decay, and stem mixer weighting.

---

## Phase 23.3: Visual Choreography & Stem Coupling (`apps/vhunambi_client`)

- [x] **T12:** Update `KineticPreviewCanvas` in `lib/features/content_studio/presentation/widgets/kinetic_preview_canvas.dart` to receive optional `FrameModulationSnapshot`, applying camera snap-zoom on `logDrumDrop` impulses and vocal bloom shaders on `phoneticStress` and cultural idioms (`REQ-MMO-12`, `REQ-MMO-13`).
- [x] **T13:** Update `_AtmosphereOverlayPainter` to inject transient particle sparks on heavy bass transients (`REQ-MMO-12`).
- [x] **T14:** Add widget tests in `test/features/content_studio/presentation/widgets/kinetic_preview_canvas_mmo_test.dart` verifying frame modulation and zero timer leaks.

---

## Phase 23.4: Role-Stratified MPC Slicer Integration (`apps/vhunambi_client`)

- [x] **T15:** Update `MpcSlicerNotifier` in `lib/features/studio/presentation/providers/heritage_crate_provider.dart` with `loadFromManifestPads(List<MpcPadSliceManifest> pads)` to hydrate `state.pads` with stratified stem slices (`REQ-MMO-05`).
- [x] **T16:** Add unit test in `test/features/studio/mpc_slicer_mmo_test.dart` verifying 8-pad stratified loading.

---

## Final Verification Gate

- [x] **V1:** Backend: `pnpm build && pnpm test` in `apps/vhunambi_api` (7/7 suites green).
- [x] **V2:** Client Analysis: `dart analyze apps/vhunambi_client` (0 issues found!).
- [x] **V3:** Client Tests: `flutter test` in `apps/vhunambi_client` (1092/1092 tests passing, 0 regressions).
- [x] **V4:** Design System: 100% token compliance, 44×44px hit bounds verified.
