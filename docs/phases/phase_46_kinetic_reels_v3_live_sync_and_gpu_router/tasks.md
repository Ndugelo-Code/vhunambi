# Phase 46 Implementation Tasks: Kinetic Reels V3, Edge Sync Coordinator, RunPod GPU V2 Router & Video UI Sweeps

> **Target Workspaces:** `apps/vhunambi_client`, `apps/vhunambi_api`, `tools/zr-studio-gpu`  
> **Status:** 🟡 SEQUENCED TASK MATRIX  
> **Verification Gate:** 100% Green Unit/Widget Tests + 0 Analyzer Issues + Successful Streamed ADB APK Install

---

## 1. Pre-Flight Verification Checklist

- [x] Git branch: `fix/studio-cockpit-bugs-vh001-vh006` is clean (`git status`).
- [x] Baseline static analysis: `dart analyze lib test` reports `No issues found!`.
- [x] Baseline test count: 44/44 client tests passing (Phases 38–44) + 13/13 backend test suites green.
- [x] Physical test device: `EPHUT20917014649` connected via ADB.

---

## 2. Sequenced Implementation Tracks

### Track A: Residual Visual Bug Sweeps (`SVID_20261104_111526_1.mp4`)
- [ ] **T1.1 [MODIFY]** `apps/vhunambi_client/lib/features/profile/presentation/widgets/profile_banner_header.dart` & `artist_profile_view.dart`:
  - Bind `IconButton` style `foregroundColor` and icon `color` explicitly to `AppColors.textPrimaryOf(context)`.
  - Bind `side` border to `BorderSide(color: AppColors.borderSubtleOf(context))`.
  - In `artist_profile_view.dart`, replace `Icons.share_rounded` color `Colors.white` with `AppColors.textPrimaryOf(context)`.
- [ ] **T1.2 [MODIFY]** `apps/vhunambi_client/lib/features/explore/presentation/widgets/create_kinetic_post_sheet.dart`:
  - Upgrade the 80×80 attached image thumbnail `errorBuilder` to render a textured procedural Vhunambi Vision container: vibrant `AppColors.brandPrimary` to `badgeCyan` gradient, `AppAssets.heritageCrateCover` at low opacity, and centered Phosphor sparkle icon.
- [ ] **T1.3 [MODIFY]** `apps/vhunambi_client/lib/features/explore/presentation/widgets/explore_social_post_card.dart`:
  - Move `_buildCosignButton` (`Key('post_cosign_btn_${post.id}')`) out of the author header row into a dedicated `Wrap` row alongside `Open Stems · N Remixes` below the caption.

---

### Track B: Kinetic Reels V3 — Duets, Vision Stage & Stem Bar
- [ ] **T2.1 [MODIFY]** `apps/vhunambi_client/lib/features/social/presentation/widgets/kinetic_reels_modal.dart`:
  - Implement `VhunambiVisionAnimatedStage` layer: `AppAssets.heritageCrateCover` at 24% opacity + bass-reactive radial pulse ring driven by low-frequency MMO telemetry.
- [ ] **T2.2 [MODIFY]** `apps/vhunambi_client/lib/features/social/presentation/widgets/kinetic_reels_modal.dart`:
  - Implement `ReelDuetSplitStage` (`Key('reel_duet_split_stage_${clip.id}')`) rendered when `clip.parentCreatorHandle != null` or `clip.remixGenerationDepth > 0`: dual audio-reactive avatar rings and `70/30 Co-Creation Split` badge.
- [ ] **T2.3 [MODIFY]** `apps/vhunambi_client/lib/features/social/presentation/widgets/kinetic_reels_modal.dart`:
  - Implement `ReelStemToggleBar` (`Key('reel_stem_toggle_bar')`) with 4 interactive stem pills (`Vocals`, `Log-Drum`, `Drums`, `Chords`).
  - Wire tapping each pill to `ref.read(stemMixerProvider.notifier).toggleMute(type)` with visual muted/active states.

---

### Track C: Live Client $\leftrightarrow$ SQLite Delta Sync Coordinator
- [ ] **T3.1 [NEW]** `apps/vhunambi_client/lib/core/sync/edge_sync_coordinator.dart`:
  - Create `EdgeSyncCoordinator` (`StateNotifier<EdgeSyncState>`) with `syncNow()` method flushing mutations to `POST /api/v1/sync/mutations` and polling incremental server changes from `GET /api/v1/sync/delta?since_seq=<lastSeq>`.
  - Add offline exception handling so tests and airplane mode never fail.
- [ ] **T3.2 [MODIFY]** `apps/vhunambi_client/lib/features/social/presentation/providers/social_feed_provider.dart`, `apps/vhunambi_client/lib/features/profile/presentation/providers/profile_providers.dart`:
  - In `SocialFeedPostsNotifier.addPost`, `repostPost`, `cosignPost`, enqueue an idempotent `SyncMutationRecord`.
- [ ] **T3.3 [MODIFY]** `apps/vhunambi_client/lib/features/profile/presentation/widgets/profile_settings_drawer.dart`:
  - Add an interactive 1-tap `[ Sync Now ]` button (`Key('settings_sync_now_btn')`) inside `ProfileSettingsDrawer` calling `edgeSyncCoordinatorProvider.notifier.syncNow()`.

---

### Track D: Unified RunPod GPU V2 Master Pipeline Router
- [ ] **T4.1 [MODIFY]** `tools/zr-studio-gpu/handler.py`:
  - Implement 5-stage sequential orchestration with `stage_metrics: [{ name, executed, duration_ms, input_sha256, output_sha256 }]`:
    - Stage 1: `ace_step_synthesis`
    - Stage 2: `demucs_stem_separation`
    - Stage 3: `seed_vc_voice_conversion`
    - Stage 4: `stem_mastering_dsp`
    - Stage 5: `mmo_telemetry_extraction`
  - Package master audio, stems, stems.zip, and MMO v2.0 manifest to R2.
- [ ] **T4.2 [NEW]** `apps/vhunambi_api/test/phase46_gpu_pipeline_and_sync.test.ts`:
  - Author backend test suite verifying GPU bridge job submission and delta sync idempotency.

---

### Track E: Verification Gates & Hardware Deployment
- [ ] **T5.1 [NEW]** `apps/vhunambi_client/test/features/social/phase46_reels_v3_and_edge_sync_test.dart`:
  - Author widget/unit tests covering Tracks A, B, and C with clean ticker disposal.
- [ ] **T5.2 [TEST]** Run `flutter test test/features/social/phase46_reels_v3_and_edge_sync_test.dart` and regression tests.
- [ ] **T5.3 [TEST]** Run `dart analyze lib test` in `apps/vhunambi_client` (0 issues).
- [ ] **T5.4 [TEST]** Run `pnpm test` in `apps/vhunambi_api` (14/14 suites green).
- [ ] **T5.5 [BUILD]** Compile ARM64 release APK (`flutter build apk --release --target-platform android-arm64 --no-pub`).
- [ ] **T5.6 [DEPLOY]** Install to physical device `EPHUT20917014649` via ADB, launch, update `AGENT_HANDOFF_BIBLE.md`, and commit/push to Git.

---

## 3. Known Traps & Mitigations Matrix

| Trap | Root Cause | Mandatory Architectural Defense |
|---|---|---|
| Light Mode Share Button Invisibility | Relying on ambient theme inheritance for icon color inside styled `IconButton` | Explicitly bind both `foregroundColor` on `IconButton.styleFrom` and `color` on `PhosphorIcon` to `AppColors.textPrimaryOf(context)`. |
| Co-Sign Button Overflow on 360dp screens | Placing multi-element badge inside narrow creator title `Row` | Place `_buildCosignButton` inside an unconstrained horizontal `Wrap` alongside `Open Stems · N Remixes`. |
| Widget Test Timer Leak on `KineticReelsModal` | `frameModulationSnapshotProvider` periodic timer or pool audio player running | Cleanly call `poolNotifier.exitReelsSession()` and pump explicit frames in widget tests. |
| Hive Initialization in Test Sandbox | `SyncOutboxService` opening local disk box during headless unit tests | Pass `isInMemoryOnly: true` or fallback to in-memory queue when `Hive.init` has not been invoked. |
| Android Root Path Crash on Stem Bouncing | Passing relative or bare filename to `File()` | Always prefix relative paths with `Directory.systemTemp.path` and catch `FileSystemException` with base64 RAM fallback. |

