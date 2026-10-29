# 🚀 CLINE & ANTIGRAVITY HANDOFF: PHASE 23 — EXECUTABLE MASTER MEDIA OBJECT (MMO v2.0)

> **Document Purpose:** Complete execution handoff for implementing Phase 23 across `apps/vhunambi_api` and `apps/vhunambi_client`.  
> **Standard:** Vhunambi Dual-Agent Pair Programming Standard ([`docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md))  
> **Specification Suite:** [`docs/phases/phase_23_master_media_object/`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_23_master_media_object/)  
> - Blueprint: [`blueprint.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_23_master_media_object/blueprint.md)  
> - Requirements: [`requirements.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_23_master_media_object/requirements.md)  
> - Design: [`design.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_23_master_media_object/design.md)  
> - Tasks: [`tasks.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_23_master_media_object/tasks.md)  

---

## 1. Non-Negotiable Guardrails & Codebase Invariants

When writing or modifying code in this monorepo, you **MUST STRICTLY OBSERVE**:
1. **Brand Spelling:** Always use `vhunambi` with an **i** (from Tshivenḓa for *"the talent or ability to sing"*). Never use `vhunamba`.
2. **Zero Raw Hex Colors:** Never hardcode hex values (`#0A0A0C`, `#F97316`) or ad-hoc border radii. Always import tokens from `package:vhunambi_client/core/theme/`:
   - `AppColors.brandPrimary` (`#F97316`)
   - `AppColors.surfaceCanvas` (`#0A0A0C`)
   - `AppColors.surfaceElevated` (`#141418`)
   - `AppColors.surfaceSecondary` (`#1B1B22`)
   - `AppColors.borderSubtle` (`#2D2D38`)
   - `AppGradients.forGenre(genre)`
   - `AppTypography`, `AppRadius`, `AppSpacing`
3. **SDK Enum Collision Safety:** Never define or import an enum named `RepeatMode` (collides with Flutter 3.44 `repeating_animation_builder.dart`). Always use `AudioRepeatMode` and `PlaybackStatus`.
4. **Stem Enum Alignment:** In the client, reuse `StemType` (`vocals`, `drums`, `bass`, `melody`) from `package:vhunambi_client/features/player/domain/models/stem_mixer_state.dart`.
5. **Ergonomic Standards:** Minimum 44×44dp touch targets on all interactive controls (`Apple HIG` / `WCAG 2.5.5`).
6. **Headless & Offline Test Safety:** All Hive operations (`mmoBoxKey`) MUST gracefully degrade to in-memory maps during `flutter test`. No uncancelled timers.
7. **Dual-Provenance Honesty:** The manifest MUST include `provenance: 'synthesized' | 'measured'`. Synthesized manifests must never falsely claim microsecond zero-crossing accuracy.

---

## 2. Step-by-Step Implementation Sequence

### Step 1: Backend Manifest Compiler (`apps/vhunambi_api`)
1. In `src/modules/dna/dna_types.ts`:
   - Export `StemRole`, `TransientEventType`, `TransientEvent`, `MpcPadSliceManifest`, `SongSectionBlueprint`, `LyricWordTimestampV2`, and `MasterMediaObjectManifest`.
2. In `src/modules/dna/dna_compiler.ts`:
   - Implement `compileMasterMediaObjectManifest()`.
   - Synthesize 60 Hz quantized `Uint8` Base64 curves for `masterRms`, `vocals`, `drums`, `bass`, `melodic`.
   - Generate chronological `transientEvents` and the 8-pad role-stratified `mpcKitPads` array.
3. In `src/routes/generation_routes.ts`:
   - Add `generationRoutes.get('/:id/manifest')`. Return status 200 with manifest or 404 if not found.
4. In `src/routes/webhook_routes.ts`:
   - Accept optional `manifest_url` in the webhook payload.
5. In `test/mmo.test.ts`:
   - Add test suite verifying Base64 length ($\le 15\text{ KB}$), 8-pad stratification, and endpoint status 200. Add to `package.json` test script.
6. Run Backend Gate:
   ```powershell
   cd c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_api
   pnpm build
   pnpm test
   ```

### Step 2: Client Domain & Persistence (`apps/vhunambi_client`)
1. In `lib/core/constants/app_constants.dart`:
   - Add `static const String mmoBoxKey = 'vhunambi_mmo_manifest_box';`.
2. In `lib/features/content_studio/domain/models/lyric_word_timestamp.dart`:
   - Add optional `phoneticStress` (`double`, default 0.5) and `isCulturalIdiom` (`bool`, default false).
3. In `lib/features/content_studio/domain/models/master_media_object.dart`:
   - Implement `MasterMediaObject`, `ModulationTelemetryBus`, `TransientEventEntity`, `MpcPadSliceManifest`, bidirectional wire-format mappers (`stemTypeFromWireString` / `transientTypeFromWireString`), and authentic 16-step beat-grid `MasterMediaObject.fromSongMetadataDna()`.
4. In `lib/features/content_studio/presentation/providers/master_media_object_provider.dart`:
   - Implement `masterMediaObjectProvider` with Hive cache + headless fallback.
   - Implement `FrameModulationQuery = ({SongMetadataDna dna, int positionMs})` Dart 3 Record.
   - Implement `frameModulationSnapshotProvider` using `.autoDispose.family` combining MMO curves with all 4 channel gains in `stemMixerProvider` (`StemMixerState`).
5. In `test/features/content_studio/domain/models/master_media_object_test.dart`:
   - Create unit tests verifying Base64 decoding, O(1) sampling, and stem mixer weighting.

### Step 3: Visual Choreography in Kinetic Canvas
1. In `lib/features/content_studio/presentation/widgets/kinetic_preview_canvas.dart`:
   - Consume `FrameModulationSnapshot`.
   - Apply exponential camera snap-zoom on `logDrumSnapZoom` impulses.
   - Scale active word glow bloom with `effectiveVocalGlow` and `phoneticStress`.
   - Render words with `isCulturalIdiom == true` with `AppColors.brandPrimary`.
2. In `test/features/content_studio/presentation/widgets/kinetic_preview_canvas_mmo_test.dart`:
   - Add widget tests verifying 60 FPS frame modulation and zero timer leaks.

### Step 4: Role-Stratified MPC Slicer Integration
1. In `lib/features/studio/presentation/providers/heritage_crate_provider.dart`:
   - Add `loadFromManifestPads(List<MpcPadSliceManifest> pads)` to `MpcSlicerNotifier`.
2. In `test/features/studio/mpc_slicer_mmo_test.dart`:
   - Add tests verifying 8-pad stratified loading.

---

## 3. Mandatory Final Verification Gates

```powershell
# 1. Backend Verification
cd c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_api
pnpm build
pnpm test

# 2. Client Static Analysis
cd c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_client
dart analyze .

# 3. Client Test Suite Run
flutter test
```

Target: **0 issues found**, **100% green tests** ($\ge 1050$ tests), zero regressions.
