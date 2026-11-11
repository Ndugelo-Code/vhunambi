# Phase 63: End-to-End Studio-to-Cloud Execution Loop, `workerd` Persistence Bridge, PayFast & Vision Live Wiring, and 5-Pillar Preflight Cockpit — Execution Tasks & Verification Plan

> **Document ID:** `VHUNAMBI-SPEC-P63-TASKS-V1`
> **Phase:** `63 — End-to-End Studio-to-Cloud Execution Loop, workerd Persistence Bridge, PayFast & Vision Live Wiring, and 5-Pillar Preflight Cockpit`
> **Engineering Standard:** `All-Gemini Engineering Standard`
> **Status:** `HARDENED SPECIFICATION SUITE — READY FOR STAGE 4 EXECUTION`
> **Audit Foundation:** `docs/audits/PHASE63_E2E_CLOUD_PIPELINE_AND_PREFLIGHT_AUDIT.md`

---

## 1. Master Milestone Roadmap & Dependency Graph (`M63.1` – `M63.5`)

```text
+----------------------------------------------------------------------------------------------------------+
|                         PHASE 63 EXECUTION ROADMAP (`M63.1` -> `M63.5`)                                  |
+----------------------------------------------------------------------------------------------------------+
|  [M63.1] Cloudflare `workerd` Edge Persistence Bridge, 6-Table Schema Normalizers & `PUT /r2/:key` Proxy |
|     |                                                                                                    |
|     +---> [M63.2] Studio -> R2 Pre-Gen Upload -> RunPod -> Dual-Dialect DO WS -> 4-Stem & 3D Biome Loop  |
|     |        |                                                                                           |
|     |        +---> [M63.3] Live PayFast ZAR Checkout, `sandbox-settle` & Wallet `userCoinsBalance` Sync  |
|     |                 |                                                                                  |
|     +-----------------+---> [M63.4] Cloud Vision R2 Ingestion & Content Studio Async Video Export        |
|                                |                                                                         |
|                                v                                                                         |
|                       [M63.5] 5-Pillar Preflight Probe (`GET /api/system/preflight`),                    |
|                               `CloudStackDiagnosticCard` HUD & Full-Stack Verification Suites            |
+----------------------------------------------------------------------------------------------------------+
```

| Milestone ID | Milestone Name | Target Package(s) | Verification Gate |
| :--- | :--- | :--- | :--- |
| **`M63.1`** | **Cloudflare `workerd` Edge Persistence Bridge, 6-Table Schema Normalizers & `PUT /r2/:key` Proxy** | `apps/vhunambi_api` | `G-63-01`, `G-63-02` |
| **`M63.2`** | **Studio $\to$ R2 Pre-Gen Upload $\to$ RunPod $\to$ `WS /ws/generation` $\to$ 4-Stem, MMO, Library & 3D Biome Loop** | `apps/vhunambi_api`, `tools/zr-studio-gpu`, `apps/vhunambi_client` | `G-63-03` |
| **`M63.3`** | **Live PayFast ZAR Checkout, `sandbox-settle` & Wallet `userCoinsBalance` Sync** | `apps/vhunambi_api`, `apps/vhunambi_client` | `G-63-04` |
| **`M63.4`** | **Cloud Vision R2 Ingestion & Content Studio Async Video Export** | `apps/vhunambi_api`, `apps/vhunambi_client` | `G-63-05` |
| **`M63.5`** | **5-Pillar Preflight Probe (`GET /api/system/preflight`), `CloudStackDiagnosticCard` & Full-Stack Verification** | `apps/vhunambi_api`, `apps/vhunambi_client` | `G-63-06` |

---

## 2. Granular Implementation Tasks (`63.1.1` – `63.5.4`)

### Milestone `M63.1`: Cloudflare `workerd` Edge Persistence Bridge, Schema Normalization & `PUT /r2/:key` Proxy
- [x] **Task `63.1.1` (`supabase_cloud_driver.ts`)**: Upgrade `apps/vhunambi_api/src/db/supabase_cloud_driver.ts` with `insertRow`, `upsertRow`, `patchRows`, `deleteRows`, and the 6 SQLite $\leftrightarrow$ PostgreSQL schema & sign normalizers (`normalizeWalletLedgerRow`, `computeWalletTotalsFromLedgerRows`, `normalizeBeatLicenseRow`, `normalizeLibrarySyncRow`, `normalizeSyncMutationRow`, `normalizePlaylistRow`, `normalizeMarketplaceAssetRow`).
- [x] **Task `63.1.2` (`edge_persistence_bridge.ts` & `vhunambi_db.ts`)**:
  1. Create `apps/vhunambi_api/src/db/edge_persistence_bridge.ts` implementing `EdgeIsolateDatabaseEngine`, `getEdgeIsolateDatabaseEngine()`, and `EdgePersistenceBridge`.
  2. Update `apps/vhunambi_api/src/db/vhunambi_db.ts` to export `setSimulateEdgeIsolateMode(enabled: boolean)`, update `isNodeSqliteAvailable()` to respect `_simulateEdgeIsolateMode`, and route `getDefaultVhunambiDb()` to `getEdgeIsolateDatabaseEngine()` whenever `isNodeSqliteAvailable() === false` so all 14 route modules work in `workerd` with zero `SQLITE_UNAVAILABLE_IN_EDGE_ISOLATE` crashes.
  3. Remove the zero-balance / no-op `!isNodeSqliteAvailable()` short-circuits in `payment_routes.ts`, `auth_routes.ts`, `auth_middleware.ts`, `social_service.ts`, `marketplace_service.ts`, `job_store.ts`, and `voice_catalog.ts` so they delegate through `vhunambiDb`.
- [x] **Task `63.1.3` (`r2_storage.ts`, `server.ts`, `runpod_adapter.ts`, `mock_worker.ts`, `comfyui_adapter.ts`)**:
  1. Add `uploadBytesToR2` and `getInMemoryR2Object` in `apps/vhunambi_api/src/modules/synthesis/r2_storage.ts`.
  2. Mount `PUT /r2/:key{.*}` in `apps/vhunambi_api/src/server.ts` and update `GET /r2/:key{.*}` to check `VHUNAMBI_VAULT` -> `getInMemoryR2Object` -> `fetchR2S3Object`.
  3. Propagate `cOrEnv` in `runpod_adapter.ts` (preserving `stemUrls` & `manifestUrl` in `checkRunPodJobStatus` and `generation_routes.ts`), `comfyui_adapter.ts`, and `mock_worker.ts` (with `waitUntil` and `broadcastGenerationEventToDo`).

### Milestone `M63.2`: Studio $\to$ R2 Pre-Gen Upload $\to$ RunPod $\to$ `WS /ws/generation` $\to$ Multi-Stem & 3D Biome Loop
- [x] **Task `63.2.1` (`generation_routes.ts`, `melody_routes.ts`, `generation_session_do.ts`)**:
  1. Extend `SubmitGenerationSchema` in `apps/vhunambi_api/src/routes/generation_routes.ts` to accept `referenceAudioUrl`, `pregenStemLocks`, and `lockedStemsPayload`, and forward `stemUrls` / `manifestUrl` during RunPod polling.
  2. Update `POST /v1/melodies/render-reference` in `apps/vhunambi_api/src/routes/melody_routes.ts` to synthesize RIFF/PCM WAV bytes and store them in R2 via `uploadBytesToR2`.
  3. Upgrade `apps/vhunambi_api/src/modules/realtime/generation_session_do.ts` with `buildDualDialectPipelineEventFrame` emitting both camelCase and snake_case (`generation_id`, `step_index`, `progress_percent`, `status_message`, `completed_track`) fields.
- [x] **Task `63.2.2` (`tools/zr-studio-gpu/handler.py` & `seed_vc_worker.py`)**:
  1. Update `tools/zr-studio-gpu/handler.py` to consume `melody_conditioning` from `job_input`.
  2. Update `tools/zr-studio-gpu/seed_vc_worker.py` to resolve `voiceId` / `archetype_id` / `cloned_profile_id` and download `r2_reference_url` when HTTP(S) reference audio is provided.
- [x] **Task `63.2.3` (`studio_action_bar.dart`, `generation_pipeline_state.dart`, `generation_pipeline_providers.dart`, `http_generation_submission_service.dart`)**:
  1. Fix `StudioActionBar._handleGenerate` (`studio_action_bar.dart`) so instrumental and custom-lyrics modes invoke `generationProgressProvider.notifier.submitAndStartGeneration(...)`, and forward `tempoBpm` / `musicalKey` in `lyrics_review_modal.dart` and `song_dna_node_tree_modal.dart`.
  2. Upgrade `PipelineSocketEvent.fromJson` and `stepFromString` in `generation_pipeline_state.dart` to decode both camelCase DO frames and snake_case frames without mapping `'queued'`, `'synthesizing'`, or `'separating_stems'` to `PipelineStep.failed`.
  3. Upgrade `GenerationPipelineNotifier._onGenerationComplete` in `generation_pipeline_providers.dart` to normalize R2 URLs, add the completed track to `libraryTracksProvider`, hydrate `masterMediaObjectProvider`, load 4 stems into `stemMixerProvider` and `multiStemEngineProvider`, and reconcile `myceliumBiomeGraphProvider`.

### Milestone `M63.3`: Live PayFast ZAR Checkout, `sandbox-settle` & Wallet Coin Sync
- [x] **Task `63.3.1` (`payment_routes.ts`)**: Add `GET /payfast/packs` and `POST /payfast/sandbox-settle/:checkoutId` (gated by `PAYFAST_SANDBOX === true` + `sovereignAuthMiddleware` + `assertTenantCreatorAccess`) in `apps/vhunambi_api/src/routes/payment_routes.ts`.
- [x] **Task `63.3.2` (`creator_wallet.dart`, `i_social_repository.dart`, `http_social_repository.dart`, `creator_wallet_provider.dart`, `subscription_upgrade_modal.dart`)**:
  1. Add `final int? balanceCoins` to `CreatorWallet` (`creator_wallet.dart`) and sync `userCoinsBalance` inside `CreatorWalletNotifier.loadWallet()` (`creator_wallet_provider.dart`).
  2. Add PayFast checkout/status/sandbox-settle helpers to `ISocialRepository` and `HttpSocialRepository`.
  3. Update `SubscriptionUpgradeModal` (`subscription_upgrade_modal.dart`) to use the canonical `500 / R55`, `1500 / R150`, and `5000 / R450` SKUs and replace raw emoji `'🪙'` with `PhosphorIconsBold.coins` (`STD-UIUX-001`).

### Milestone `M63.4`: Cloud Vision R2 Ingestion & Content Studio Async Video Export
- [x] **Task `63.4.1` (`vision_routes.ts` & `comfyui_adapter.ts`)**: Pass `c` into `dispatchComfyUIVisionJob`, store rendered video / completed ComfyUI PNGs via `uploadBytesToR2` in `vision_routes.ts`, and return normalized R2 URLs.
- [x] **Task `63.4.2` (`cloud_video_export_service.dart`, `content_studio_provider.dart`, `video_export_provider.dart`, `content_studio_dock_view.dart`, `create_kinetic_post_sheet.dart`, `generation_pipeline_card.dart`)**: Wire `CloudVideoExportService.exportLyricVideo` to `POST /v1/vision/render-video` with offline test fallback, bind `videoExportServiceProvider` to `CloudVideoExportService`, and normalize media URLs via `AppConstants.normalizeCloudMediaUrl(...)`.

### Milestone `M63.5`: 5-Pillar Cloud Stack Preflight Probe & `CloudStackDiagnosticCard` + Verification Suites
- [x] **Task `63.5.1` (`system_routes.ts` & `server.ts`)**: Create `apps/vhunambi_api/src/routes/system_routes.ts` implementing `GET /preflight` across all 6 subsystems (`supabase`, `r2Vault`, `runpodAudio`, `runpodVision`, `paymentAndLlm`, `webhookCallback`) and mount at `/api/system`, `/api/v1/system`, and `/v1/system` in `server.ts`.
- [x] **Task `63.5.2` (`cloud_stack_diagnostic_card.dart` & `profile_settings_drawer.dart`)**: Create `apps/vhunambi_client/lib/features/profile/presentation/widgets/cloud_stack_diagnostic_card.dart` (`cloudPreflightProvider` + `CloudStackDiagnosticCard`) and mount it inside `ProfileSettingsDrawer`.
- [x] **Task `63.5.3` (`phase63_e2e_cloud_pipeline_and_preflight.test.ts` & `package.json`)**: Create `apps/vhunambi_api/test/phase63_e2e_cloud_pipeline_and_preflight.test.ts` verifying `workerd` simulated isolate mode across all 7 route modules, `SupabaseCloudDriver` CRUD/normalizers, `PUT /r2/:key`, `POST /v1/melodies/render-reference` R2 WAV upload, `GenerationSessionDO` dual-dialect frames, `POST /api/payments/payfast/sandbox-settle/:checkoutId`, Vision R2 ingestion, and `GET /api/system/preflight`.
- [x] **Task `63.5.4` (`phase63_e2e_cloud_pipeline_test.dart`)**: Create `apps/vhunambi_client/test/core/network/phase63_e2e_cloud_pipeline_test.dart` verifying `StudioActionBar` instrumental/custom-lyrics submission, `PipelineSocketEvent.fromJson` camelCase+snake_case decoding, `_onGenerationComplete` 4-stem/MMO/Library/Biome hydration, PayFast `500/1500/5000` SKUs & `userCoinsBalance` sync, `CloudVideoExportService`, and `CloudStackDiagnosticCard`.

---

## 3. Stage 4 Execution Verification Checklist (`vhunambi-executioner`)

- [x] **1. Zero `workerd` SQLite Crashes (`G-63-01`)**: `setSimulateEdgeIsolateMode(true)` passes 100% of Explore, Library, Playlists, Sync, Wallet, Marketplace, Social, Auth, Jobs, and PayFast tests.
- [x] **2. Zero Raw Emojis (`STD-UIUX-001`)**: `subscription_upgrade_modal.dart` and `cloud_stack_diagnostic_card.dart` contain zero raw Unicode emojis.
- [x] **3. Anti-Hang Widget Test Discipline**: Every `flutter test` invocation runs with `--timeout=60s` and zero unguarded periodic timers or real network sockets on widget mount.
- [x] **4. Full Verification Commands**:
  - `cd apps/vhunambi_api; npm run build; npm test`
  - `python -m py_compile tools/zr-studio-gpu/handler.py tools/zr-studio-gpu/seed_vc_worker.py`
  - `cd apps/vhunambi_client; flutter analyze` (`0 issues`)
  - `cd apps/vhunambi_client; flutter test test/core/network/phase63_e2e_cloud_pipeline_test.dart --timeout=60s`

