# Phase 63: End-to-End Studio-to-Cloud Execution Loop, `workerd` Persistence Bridge, PayFast & Vision Live Wiring, and 5-Pillar Preflight Cockpit — System Requirements

> **Document ID:** `VHUNAMBI-SPEC-P63-REQUIREMENTS-V1`
> **Phase:** `63 — End-to-End Studio-to-Cloud Execution Loop, workerd Persistence Bridge, PayFast & Vision Live Wiring, and 5-Pillar Preflight Cockpit`
> **Engineering Standard:** `All-Gemini Engineering Standard (EARS + RFC-2119 Formal Specification)`
> **Status:** `HARDENED SPECIFICATION SUITE — READY FOR STAGE 4 EXECUTION`
> **Audit Foundation:** `docs/audits/PHASE63_E2E_CLOUD_PIPELINE_AND_PREFLIGHT_AUDIT.md`

---

## 1. Document Scope & EARS / RFC-2119 Conventions

This specification defines the formal requirements for **Phase 63** across:
- **`apps/vhunambi_api`**: Cloudflare Workers (`workerd`) Edge Persistence Bridge, `SupabaseCloudDriver` full CRUD + 6-table SQLite $\leftrightarrow$ PostgreSQL schema/sign normalizers, `PUT /r2/:key{.*}` object upload proxy, per-request `c.env` adapter propagation, `GenerationSessionDO` dual-dialect WebSocket frames, PayFast `sandbox-settle` verifier, Vision R2 binary ingestion, and `GET /api/system/preflight`.
- **`tools/zr-studio-gpu`**: RunPod Serverless Python GPU `melody_conditioning` consumption and R2 vocal reference audio downloading (`handler.py`, `seed_vc_worker.py`).
- **`apps/vhunambi_client`**: Unified `StudioActionBar` / modal generation dispatch, pre-gen R2 upload wiring (`ReferenceAudioDropzone`, `SoundSignatureRepository`, `VocalIdentityNotifier`, `MelodySketchpadNotifier`), live WebSocket + adaptive HTTP polling, `_onGenerationComplete` 4-stem/MMO/Library/3D-Biome hydration, PayFast SKU alignment & sandbox checkout polling, `CloudVideoExportService` wiring, and `CloudStackDiagnosticCard` inside `ProfileSettingsDrawer`.

All requirements use **EARS** (`UBIQUITOUS`, `EVENT-DRIVEN`, `STATE-DRIVEN`, `UNWANTED-BEHAVIOR`) and **RFC-2119** keywords (`MUST`, `MUST NOT`, `SHALL`).

---

## 2. Pillar 1 Requirements: Cloudflare `workerd` Persistence Bridge, Schema Normalization & `PUT /r2/:key` (`REQ-P63-EDGE`)

### `REQ-P63-EDGE-01`: Zero `SQLITE_UNAVAILABLE_IN_EDGE_ISOLATE` Crashes Across All 14 Route Modules
- **Pattern:** `STATE-DRIVEN`
- **Statement:** **WHILE** `apps/vhunambi_api` executes inside a Cloudflare Worker V8 isolate (`isNodeSqliteAvailable() === false`) or when simulated edge-isolate mode (`setSimulateEdgeIsolateMode(true)`) is enabled, invoking any method on `vhunambiDb` or hitting any route in `explore_routes.ts`, `library_routes.ts`, `playlist_routes.ts`, `sync_routes.ts`, `wallet_routes.ts`, `marketplace_routes.ts`, `social_routes.ts`, `auth_routes.ts`, `payment_routes.ts`, `generation_routes.ts`, `vision_routes.ts`, `voice_routes.ts`, `melody_routes.ts`, or `webhook_routes.ts` **MUST NOT** throw `SQLITE_UNAVAILABLE_IN_EDGE_ISOLATE`.
- **Acceptance Criteria:**
  1. `vhunambi_db.ts` provides a complete in-isolate `EdgeIsolateMemoryEngine` fallback backing `getDefaultVhunambiDb()` whenever `isNodeSqliteAvailable() === false`, pre-seeded with the 7 sovereign creators (`creator_cern` with `1200` coins / `R 1,450.00`, `creator_makhadzi`, `creator_kabza`, `creator_focalistic`, `creator_tyla`, `creator_black_coffee`), 12 explore tracks, 6 marketplace beats, and SA banks.
  2. `EdgePersistenceBridge` (`apps/vhunambi_api/src/db/edge_persistence_bridge.ts`) synchronizes reads and writes with `SupabaseCloudDriver` whenever `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are configured in `resolveRuntimeEnv(c)`.

### `REQ-P63-EDGE-02`: `SupabaseCloudDriver` Full CRUD & 6-Table Schema/Sign Normalization
- **Pattern:** `UBIQUITOUS`
- **Statement:** `SupabaseCloudDriver` (`apps/vhunambi_api/src/db/supabase_cloud_driver.ts`) **MUST** implement `insertRow`, `upsertRow`, `patchRows`, and `deleteRows` over PostgREST, plus deterministic row mappers normalizing all 6 SQLite $\leftrightarrow$ PostgreSQL schema divergences (`wallet_ledger`, `beat_licenses`, `user_library_sync`, `sync_mutation_log`, `playlists`, `marketplace_assets`).
- **Acceptance Criteria:**
  1. `normalizeWalletLedgerRow` handles both SQLite (`data_json`, positive `amount_zar` for `type = 'payout'`) and PostgreSQL (`metadata_json`, negative `amount_zar` for `type = 'payout_withdrawal'`) so wallet balance computation never inverts payout signs.
  2. `normalizeBeatLicenseRow`, `normalizeLibrarySyncRow`, `normalizeSyncMutationRow`, `normalizePlaylistRow`, and `normalizeMarketplaceAssetRow` map snake_case Postgres columns (`amount_paid_coins`, `amount_paid_zar`, `cover_image_url`, `mutation_id`, `operation`, `updated_at BIGINT`) to the canonical DTOs expected by Flutter.

### `REQ-P63-EDGE-03`: `PUT /r2/:key{.*}` Object Upload Proxy & Per-Request `c.env` Propagation
- **Pattern:** `EVENT-DRIVEN`
- **Statement:** **WHEN** a client or worker uploads binary media via `PUT /r2/:key{.*}` (or via `uploadBytesToR2(objectKey, bytes, contentType, cOrEnv)`), `server.ts` **MUST** store the object in `c.env.VHUNAMBI_VAULT.put(cleanKey, bytes, { httpMetadata: { contentType } })` (and in a shared in-memory R2 fallback map when `VHUNAMBI_VAULT` is unbound in local dev/tests) so subsequent `GET /r2/:key{.*}` requests return the exact uploaded bytes and `Content-Type`. Furthermore, `runpod_adapter.ts`, `comfyui_adapter.ts`, and `mock_worker.ts` **MUST** accept and propagate `cOrEnv` and register background timers with `waitUntil`.
- **Acceptance Criteria:**
  1. `PUT /r2/signatures/test_sig.wav` with binary audio payload returns `200 OK` (`{ uploaded: true, key: 'signatures/test_sig.wav', url: ... }`), and `GET /r2/signatures/test_sig.wav` streams back the exact uploaded byte buffer.
  2. `checkRunPodJobStatus` preserves `stemUrls` (`stem_urls`), `manifestUrl` (`manifest_url`), and `masterWavUrl` (`master_wav_url`) in addition to `audioUrl` and `stemsZipUrl`.
  3. `simulateSynthesisPipeline(generationId, cOrEnv)` registers its async completion promise with `waitUntil` (when present) and broadcasts `pipeline_event` frames to `GenerationSessionDO`.

---

## 3. Pillar 2 Requirements: Studio $\to$ R2 $\to$ RunPod $\to$ `WS /ws/generation` $\to$ 4-Stem & 3D Biome Loop (`REQ-P63-STUDIO`)

### `REQ-P63-STUDIO-01`: Unified Studio Generation Trigger Across All Lyrics & Instrumental Modes
- **Pattern:** `EVENT-DRIVEN`
- **Statement:** **WHEN** a user taps the Generate button in `StudioActionBar` (`studio_action_bar.dart`) with `isInstrumental == true` OR `lyricsMode != LyricsMode.aiWrite`, or approves generation from `LyricsReviewModal` or `SongDnaNodeTreeModal`, the client **MUST** invoke `generationProgressProvider.notifier.submitAndStartGeneration(...)` forwarding `trackTitle`, `genre`, `language`, `lyrics`, `isInstrumental`, `tempoBpm`, `musicalKey`, `selectedVoiceId`, `clonedVoiceProfileId`, `melodyPattern`, `melodyReferenceId`, `referenceAudioUrl`, and `pregenStemLocks`.
- **Acceptance Criteria:**
  1. Tapping Generate in `StudioActionBar` when `isInstrumental == true` or `lyricsMode == LyricsMode.writeMyOwn` transitions `studioFormProvider` to `generating` AND invokes `generationProgressProvider.notifier.submitAndStartGeneration(...)` (zero silent skeleton stalls).
  2. `SubmitGenerationSchema` in `generation_routes.ts` accepts optional `referenceAudioUrl`, `pregenStemLocks`, and `lockedStemsPayload` and forwards them to `compileSongSpec`.

### `REQ-P63-STUDIO-02`: Pre-Gen R2 Upload Wiring & RunPod Conditioning (`melody_conditioning` & `r2_reference_url`)
- **Pattern:** `EVENT-DRIVEN`
- **Statement:** **WHEN** a creator attaches a reference audio file (`ReferenceAudioDropzone`), saves a sound signature (`SoundSignatureRepository`), clones a voice (`VocalIdentityNotifier`), or attaches a 16-step melody pattern (`MelodySketchpadNotifier`), the client and backend **MUST** persist the reference payload to R2 (`VHUNAMBI_VAULT`) and forward the resulting R2 URL to RunPod (`handler.py` and `seed_vc_worker.py`).
- **Acceptance Criteria:**
  1. `POST /v1/melodies/render-reference` synthesizes a deterministic RIFF/PCM WAV byte buffer for the 16-step pattern, stores it in R2 (`sketchpad-refs/${referenceId}.wav`) via `uploadBytesToR2`, and returns its resolved `r2ReferenceUrl`.
  2. `tools/zr-studio-gpu/handler.py` reads `melody_conditioning` from `job_input`, logs and merges conditioning cues (`r2_reference_url`, `transient_events`, `locked_stems`) into synthesis/MMO metadata, and `seed_vc_worker.py` downloads `r2_reference_url` when HTTP(S) reference audio is supplied.

### `REQ-P63-STUDIO-03`: Dual-Dialect `GenerationSessionDO` $\leftrightarrow$ `PipelineSocketEvent` & Live WebSocket Streaming
- **Pattern:** `EVENT-DRIVEN`
- **Statement:** **WHEN** `GenerationSessionDO` broadcasts a `pipeline_event` frame or `PipelineSocketEvent.fromJson` decodes a frame on `WS /ws/generation`, both camelCase (`generationId`, `progressPct`, `masterMp3Url`, `stemUrls`) and snake_case (`generation_id`, `progress_percent`, `step_index`, `status_message`, `completed_track`) fields **MUST** be emitted and decoded without mapping active synthesis steps to `PipelineStep.failed`.
- **Acceptance Criteria:**
  1. `PipelineSocketEvent.stepFromString` maps `'queued'` and `'starting_up'` to `PipelineStep.startingUp`, `'writing_lyrics'` to `PipelineStep.writingLyrics`, `'producing_beat'`, `'synthesizing'`, `'separating_stems'`, `'uploading'`, and `'mastering'` to `PipelineStep.producingBeat`, and `'ready'` / `'completed'` / `'succeeded'` to `PipelineStep.ready`.
  2. `PipelineSocketEvent.fromJson` accepts both `progress_percent` (`0.0..1.0`) and `progressPct` (`0..100`, automatically normalized to `0.0..1.0`), and synthesizes `completedTrack` from top-level `masterMp3Url` / `stemUrls` whenever `completed_track` is omitted.

### `REQ-P63-STUDIO-04`: Post-Completion Multi-Stem Engine, MMO, Library & 3D Mycelium Biome Hydration
- **Pattern:** `EVENT-DRIVEN`
- **Statement:** **WHEN** `GenerationPipelineNotifier._onGenerationComplete(TrackEntity track)` fires, it **MUST** normalize media URLs via `AppConstants.normalizeCloudMediaUrl`, add the track to `libraryTracksProvider`, fetch or synthesize the `MasterMediaObject` manifest to update `masterMediaObjectProvider`, load all 4 stems into `stemMixerProvider` (`loadMixForTrack`) and `JustAudioMultiStemEngine` (when stems are present), and trigger `myceliumBiomeGraphProvider.notifier.reconcileWithCockpitState()`.
- **Acceptance Criteria:**
  1. Completing a generation adds a `LibraryTrack` with matching `id`, `title`, `genre`, and normalized `remoteAudioUrl` into `libraryTracksProvider`.
  2. Completing a generation with `stemUrls` populates `stemMixerProvider` (`currentTrackId == track.id`) and reconciles `myceliumBiomeGraphProvider`.

---

## 4. Pillar 3 Requirements: Live PayFast ZAR Checkout, `sandbox-settle` & Wallet Sync (`REQ-P63-PAY`)

### `REQ-P63-PAY-01`: Edge-Persistent PayFast Checkouts & `POST /api/payments/payfast/sandbox-settle/:checkoutId`
- **Pattern:** `EVENT-DRIVEN`
- **Statement:** **WHEN** `POST /api/payments/payfast/checkout`, `POST /api/payments/payfast/itn`, `GET /api/payments/payfast/status/:checkoutId`, or `POST /api/payments/payfast/sandbox-settle/:checkoutId` is called in either Node SQLite or Cloudflare `workerd` mode, the backend **MUST** persist checkout state and credit the creator's `wallet_ledger` atomically so `GET /payfast/status/:checkoutId` returns accurate `walletBalanceCoins` and `walletBalanceZar`.
- **Acceptance Criteria:**
  1. `POST /api/payments/payfast/sandbox-settle/:checkoutId` requires `sovereignAuthMiddleware`, verifies tenant access to the checkout's `creatorId`, rejects requests with `403 SANDBOX_ONLY` when `PAYFAST_SANDBOX === false`, and settles the checkout atomically when `PAYFAST_SANDBOX === true`.
  2. In simulated `workerd` mode (`isNodeSqliteAvailable() === false`), settling a `pack_starter_500` checkout increments `walletBalanceCoins` by `+500` in `GET /api/payments/payfast/status/:checkoutId` and `GET /api/wallet/:creatorId`.

### `REQ-P63-PAY-02`: Flutter Coin Pack SKU Alignment, Zero Raw Emoji & `userCoinsBalance` Hydration
- **Pattern:** `UBIQUITOUS`
- **Statement:** `SubscriptionUpgradeModal` (`subscription_upgrade_modal.dart`) **MUST** use the canonical coin pack SKUs (`pack_starter_500`: `500` coins / `R55`, `pack_producer_1500`: `1500` coins / `R150`, `pack_mogul_5000`: `5000` coins / `R450`), render `PhosphorIconsBold.coins` instead of raw emoji `'🪙'` (`STD-UIUX-001`), initiate PayFast checkouts through `CreatorWalletNotifier` / `ISocialRepository`, and `CreatorWalletNotifier.loadWallet()` **MUST** synchronize `userCoinsBalance` when `remoteWallet.balanceCoins` is present.
- **Acceptance Criteria:**
  1. `subscription_upgrade_modal.dart` contains zero raw Unicode emojis (`'🪙'` removed) and exposes pack keys `Key('coin_topup_pack_500')`, `Key('coin_topup_pack_1500')`, and `Key('coin_topup_pack_5000')` (plus backward-compatible aliases if needed).
  2. `CreatorWallet.fromJson` parses `balanceCoins` (`int?`), and `CreatorWalletNotifier.loadWallet()` updates `state.userCoinsBalance` when `remoteWallet.balanceCoins != null`.

---

## 5. Pillar 4 Requirements: Cloud Vision R2 Ingestion & Content Studio Video Export (`REQ-P63-VIS`)

### `REQ-P63-VIS-01`: ComfyUI R2 Image Ingestion & Persistent Video Render Jobs (`vision_routes.ts`)
- **Pattern:** `EVENT-DRIVEN`
- **Statement:** **WHEN** `GET /v1/vision/:id` observes a completed ComfyUI image or `POST /v1/vision/render-video` dispatches a lyric reel export, `vision_routes.ts` **MUST** store/resolve the output asset in R2 (`vision/${id}.png` or `reels/${jobId}.mp4` via `resolveMediaUrl`) and persist job metadata through `job_store.ts` (`generation_jobs`).
- **Acceptance Criteria:**
  1. `dispatchComfyUIVisionJob` accepts `cOrEnv` and resolves mock/fallback URLs through `resolveMediaUrl(..., cOrEnv)` (never emitting raw `https://r2.vhunambi.com/...`).
  2. `POST /v1/vision/render-video` writes a deterministic MP4 header/artifact into R2 (`uploadBytesToR2`) and persists the job in `job_store` so `GET /v1/vision/render-video/:id` works across isolates.

### `REQ-P63-VIS-02`: `CloudVideoExportService` HTTP Wiring & Legacy URL Normalization
- **Pattern:** `EVENT-DRIVEN`
- **Statement:** **WHEN** `CloudVideoExportService.exportLyricVideo` is invoked, it **MUST** submit the render request to `POST /v1/vision/render-video` (and poll `GET /v1/vision/render-video/:id` when `status != 'completed'`), falling back cleanly to a normalized `AppConstants.normalizeCloudMediaUrl(...)` path when offline in headless widget tests.
- **Acceptance Criteria:**
  1. `videoExportServiceProvider` in `content_studio_provider.dart` provides `CloudVideoExportService` wired with `AppConstants.resolveApiRootUrl()` and `authDioInterceptorProvider`.
  2. `CloudVideoExportService`, `VideoExportNotifier`, `ContentStudioDockView`, `CreateKineticPostSheet`, and `GenerationPipelineCard` normalize all output/fallback media URLs through `AppConstants.normalizeCloudMediaUrl(...)`.

---

## 6. Pillar 5 Requirements: 5-Pillar Cloud Stack Preflight Probe & Diagnostic Cockpit (`REQ-P63-PRE`)

### `REQ-P63-PRE-01`: Backend Preflight Endpoint (`GET /api/system/preflight`, `/api/v1/system/preflight`, `/v1/system/preflight`)
- **Pattern:** `EVENT-DRIVEN`
- **Statement:** **WHEN** a client requests `GET /api/system/preflight` (or `/api/v1/system/preflight` or `/v1/system/preflight`), the backend **MUST** inspect and optionally probe all 6 hybrid cloud subsystems (`supabase`, `r2Vault`, `runpodAudio`, `runpodVision`, `paymentAndLlm`, `webhookCallback`) and return a structured readiness report without exposing any raw secret values.
- **Acceptance Criteria:**
  1. Returns HTTP `200` with `{ status: 'healthy' | 'degraded' | 'misconfigured', environment, persistenceEngine: 'node_sqlite' | 'supabase_cloud' | 'edge_isolate_memory', pillars: { supabase, r2Vault, runpodAudio, runpodVision, paymentAndLlm, webhookCallback }, timestamp }`.
  2. If `RUNPOD_API_KEY` is configured while `WEBHOOK_BASE_URL` points to `localhost` or `127.0.0.1`, `pillars.webhookCallback.status` is `'misconfigured'` with an explicit tunnel warning.

### `REQ-P63-PRE-02`: `CloudStackDiagnosticCard` in `ProfileSettingsDrawer`
- **Pattern:** `UBIQUITOUS`
- **Statement:** `ProfileSettingsDrawer` (`profile_settings_drawer.dart`) **MUST** mount `CloudStackDiagnosticCard` (`Key('cloud_stack_preflight_card')`) displaying the active API/Media origins, the 6 subsystem status badges, and an interactive `"Run 5-Pillar Probe"` button (`Key('cloud_stack_run_preflight_btn')`) using `AppColors`, `AppTypography`, and `PhosphorIcons` (`STD-UIUX-001` zero raw emojis).
- **Acceptance Criteria:**
  1. `CloudStackDiagnosticCard` renders deterministically in widget tests without spawning background timers on mount, and tapping `Key('cloud_stack_run_preflight_btn')` invokes `cloudPreflightProvider.notifier.runPreflightProbe()`.

---

## 7. Requirement-to-Test Traceability Matrix

| Requirement ID | Primary Target Files | Automated Verification Test Case | Gate |
| :--- | :--- | :--- | :--- |
| `REQ-P63-EDGE-01` | `vhunambi_db.ts`, `edge_persistence_bridge.ts`, 7 route files | `phase63_e2e_cloud_pipeline_and_preflight.test.ts` -> `'M63.1: workerd simulated isolate mode runs all 7 domain routes with 0 SQLite crashes'` | `G-63-01` |
| `REQ-P63-EDGE-02` | `supabase_cloud_driver.ts`, `edge_persistence_bridge.ts` | `phase63_e2e_cloud_pipeline_and_preflight.test.ts` -> `'M63.1: SupabaseCloudDriver CRUD & 6-table SQLite <-> Postgres normalizers preserve payout sign & DTOs'` | `G-63-01` |
| `REQ-P63-EDGE-03` | `server.ts`, `r2_storage.ts`, `runpod_adapter.ts`, `mock_worker.ts` | `phase63_e2e_cloud_pipeline_and_preflight.test.ts` -> `'M63.1: PUT /r2/:key stores binary payload in VHUNAMBI_VAULT and GET /r2/:key streams it back'` | `G-63-02` |
| `REQ-P63-STUDIO-01` | `studio_action_bar.dart`, `generation_routes.ts` | `phase63_e2e_cloud_pipeline_test.dart` -> `'M63.2: StudioActionBar instrumental & custom lyrics modes invoke submitAndStartGeneration'` | `G-63-03` |
| `REQ-P63-STUDIO-02` | `melody_routes.ts`, `handler.py`, `seed_vc_worker.py` | `phase63_e2e_cloud_pipeline_and_preflight.test.ts` -> `'M63.2: POST /v1/melodies/render-reference uploads WAV to R2 and returns downloadable URL'` | `G-63-03` |
| `REQ-P63-STUDIO-03` | `generation_session_do.ts`, `generation_pipeline_state.dart` | `phase63_e2e_cloud_pipeline_test.dart` -> `'M63.2: PipelineSocketEvent.fromJson decodes GenerationSessionDO camelCase & snake_case frames'` | `G-63-03` |
| `REQ-P63-STUDIO-04` | `generation_pipeline_providers.dart` | `phase63_e2e_cloud_pipeline_test.dart` -> `'M63.2: _onGenerationComplete hydrates Library, MMO, StemMixer, and 3D Mycelium Biome'` | `G-63-03` |
| `REQ-P63-PAY-01` | `payment_routes.ts` | `phase63_e2e_cloud_pipeline_and_preflight.test.ts` -> `'M63.3: POST /api/payments/payfast/sandbox-settle/:checkoutId credits wallet in SQLite and workerd modes'` | `G-63-04` |
| `REQ-P63-PAY-02` | `subscription_upgrade_modal.dart`, `creator_wallet_provider.dart` | `phase63_e2e_cloud_pipeline_test.dart` -> `'M63.3: SubscriptionUpgradeModal aligns 500/1500/5000 SKUs, zero raw emojis, and syncs userCoinsBalance'` | `G-63-04` |
| `REQ-P63-VIS-01..02` | `vision_routes.ts`, `cloud_video_export_service.dart` | `phase63_e2e_cloud_pipeline_and_preflight.test.ts` & `phase63_e2e_cloud_pipeline_test.dart` -> `'M63.4: Vision R2 ingestion & CloudVideoExportService render-video flow'` | `G-63-05` |
| `REQ-P63-PRE-01..02` | `system_routes.ts`, `cloud_stack_diagnostic_card.dart` | `phase63_e2e_cloud_pipeline_and_preflight.test.ts` & `phase63_e2e_cloud_pipeline_test.dart` -> `'M63.5: GET /api/system/preflight & CloudStackDiagnosticCard probe all 5 pillars'` | `G-63-06` |

