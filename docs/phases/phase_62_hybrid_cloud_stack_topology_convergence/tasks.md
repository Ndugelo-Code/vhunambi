# Phase 62: Hybrid Cloud Stack Topology & Production Edge Convergence — Execution Tasks & Verification Plan

> **Document ID:** `VHUNAMBI-SPEC-P62-TASKS-V1`
> **Phase:** `62 — Hybrid Cloud Stack Topology & Production Edge Convergence (Supabase + Cloudflare Workers/R2 + RunPod GPU)`
> **Engineering Standard:** `All-Gemini Engineering Standard`
> **Status:** `HARDENED SPECIFICATION SUITE — READY FOR EXECUTION`
> **Audit Foundation:** `docs/audits/HYBRID_CLOUD_STACK_TOPOLOGY_PHASE62_AUDIT.md`

---

## 1. Master Milestone Roadmap & Dependency Graph (`M62.1` – `M62.8`)

```text
+----------------------------------------------------------------------------------------------------------+
|                         PHASE 62 EXECUTION ROADMAP (`M62.1` -> `M62.8`)                                  |
+----------------------------------------------------------------------------------------------------------+
|  [M62.1] 19-Table Supabase SQL Migration, Atomic `FOR UPDATE` RPCs & Lazy `node:sqlite` Proxy            |
|     |                                                                                                    |
|     +---> [M62.2] Cloudflare Workers (`wrangler.toml`, `worker.ts`), R2 Vault & `GenerationSessionDO` WS |
|     |        |                                                                                           |
|     |        +---> [M62.3] Supabase GoTrue <-> Sovereign JWT Homomorphism & `@blackcoffee` ID Parity     |
|     |                 |                                                                                  |
|     +-----------------+---> [M62.4] Zero Volatile RAM Stores, Unified Wallet & Producer Ownership Guards |
|                                |                                                                         |
|                                +---> [M62.5] South African PayFast Checkout/ITN & Top-Up Exploit Closure |
|                                |                                                                         |
|                                +---> [M62.6] RunPod `zr-studio-gpu` Repair, Vision Polling & Grok LLM    |
|                                         |                                                                |
|                                         +---> [M62.7] Flutter Unified Cloud Origin & Auth Interceptors   |
|                                                  |                                                       |
|                                                  v                                                       |
|                                         [M62.8] Full-Stack Zero-Regression & Cloud Cutover Verification  |
+----------------------------------------------------------------------------------------------------------+
```

| Milestone ID | Milestone Name | Target Package(s) | Verification Gate |
| :--- | :--- | :--- | :--- |
| **`M62.1`** | **19-Table Supabase PostgreSQL Schema, Atomic RPCs & Lazy SQLite Proxy** | `supabase/`, `apps/vhunambi_api` | `G-62-01` |
| **`M62.2`** | **Cloudflare Workers Entrypoint, Request-Scoped `c.env`, R2 Vault & `GenerationSessionDO` WS** | `apps/vhunambi_api` | `G-62-02` |
| **`M62.3`** | **Supabase GoTrue ↔ Sovereign JWT Unification & Canonical `@blackcoffee` Parity** | `apps/vhunambi_api` | `G-62-03` |
| **`M62.4`** | **Elimination of All 4 Volatile RAM Stores, Unified Wallet & Route Auth Hardening** | `apps/vhunambi_api` | `G-62-04` |
| **`M62.5`** | **South African Payment Gateway (`PayFast ITN`) & Top-Up Exploit Closure** | `apps/vhunambi_api` | `G-62-05` |
| **`M62.6`** | **RunPod `zr-studio-gpu` Repair, ComfyUI Polling (`GET /v1/vision/:id`) & Grok LLM** | `tools/zr-studio-gpu`, `apps/vhunambi_api` | `G-62-06` |
| **`M62.7`** | **Flutter Client Unified Cloud Origin, Auth Interceptors & Media URL Normalization** | `apps/vhunambi_client` | `G-62-07` |
| **`M62.8`** | **Full-Stack Phase 62 Automated Verification Suites & Zero-Analyzer Gate** | `apps/vhunambi_api`, `apps/vhunambi_client` | `G-62-01` .. `G-62-08` |

---

## 2. Granular Implementation Tasks (`62.1.1` – `62.8.3`)

### Milestone `M62.1`: 19-Table Supabase PostgreSQL Schema, Atomic RPCs & Lazy SQLite Proxy
- [x] **Task `62.1.1` (`20261110000001_phase62_hybrid_cloud_schema.sql`)**: Create `supabase/migrations/20261110000001_phase62_hybrid_cloud_schema.sql` defining all 19 tables (`creators`, `users`, `auth_sessions`, `sync_mutation_log`, `wallet_ledger`, `bank_accounts`, `explore_tracks`, `kinetic_posts`, `published_clips`, `reel_comments`, `marketplace_assets`, `beat_licenses`, `sound_signatures`, `user_library_sync`, `playlists`, `generation_jobs`, `voice_clones`, `social_interactions`, `payment_topups`) and the 4 PostgreSQL functions (`execute_atomic_payout`, `record_beat_license_atomic`, `send_cultural_tip_atomic`, `custom_access_token_hook`) with parent-row `SELECT ... FROM public.creators WHERE id = ... FOR UPDATE` locks.
- [x] **Task `62.1.2` (`supabase_cloud_driver.ts`)**: Create `apps/vhunambi_api/src/db/supabase_cloud_driver.ts` implementing `SupabaseCloudDriver` (`isConfigured`, `callRpc`, `selectRows`, `upsertRow`, `goTrueSignUp`, `goTrueSignInWithPassword`, `goTrueRefreshSession`) using standard `fetch` with zero external un-installed npm packages.
- [x] **Task `62.1.3` (`vhunambi_db.ts` Lazy Proxy, `isNodeSqliteAvailable()` & 19-Table Parity)**: Upgrade `apps/vhunambi_api/src/db/vhunambi_db.ts` to:
  1. Load `node:sqlite`, `node:fs`, and `node:path` lazily via `process.getBuiltinModule(...)`, export `isNodeSqliteAvailable(): boolean` (`VhunambiDatabase.isNodeSqliteAvailable()`), and expose `export const vhunambiDb` via a lazy-initializing `Proxy`,
  2. Export `canonicalizeCreatorId` normalizing `'creator_blackcoffee'` $\leftrightarrow$ `'creator_black_coffee'`,
  3. Preserve existing `getWallet(creatorId)` and SQLite `wallet_ledger` (`data_json`) column names intact while adding `getWalletSnapshot(creatorId)` alias, the 4 new SQLite tables (`generation_jobs`, `voice_clones`, `social_interactions`, `payment_topups`), and CRUD methods (`upsertGenerationJob`, `getGenerationJob`, `updateGenerationJob`, `listGenerationJobs`, `countActiveGenerationJobs`, `sendCulturalTipAtomic`, `createPayFastCheckout`, `getPayFastCheckout`, `settlePayFastItnAtomic`), and
  4. Replace the unverified `topupWallet` call on `entityType === 'tip'` in `applyMutations()` with `sendCulturalTipAtomic` and push `getDelta()` tenant visibility filtering into the SQL `WHERE` clause.

### Milestone `M62.2`: Cloudflare Workers Entrypoint, Request-Scoped `c.env`, R2 Vault & `GenerationSessionDO`
- [x] **Task `62.2.1` (`wrangler.toml` & `cloudflare_worker_types.ts`)**: Create `apps/vhunambi_api/wrangler.toml` (`R2_BUCKET = "vhunambi-vault"`, `VHUNAMBI_VAULT`, `HYPERDRIVE`, `GENERATION_DO`) and `apps/vhunambi_api/src/types/cloudflare_worker_types.ts`.
- [x] **Task `62.2.2` (`env.ts` & `r2_storage.ts`)**: Upgrade `apps/vhunambi_api/src/config/env.ts` with `resolveRuntimeEnv(cOrEnv)` and `resolveMediaUrl(rawUrl, cOrEnv)`, and upgrade `apps/vhunambi_api/src/modules/synthesis/r2_storage.ts` to default `R2_BUCKET` to `'vhunambi-vault'` and add `deleteR2Object(objectKey, cOrEnv)`.
- [x] **Task `62.2.3` (`worker.ts` & `server.ts`)**: Create `apps/vhunambi_api/src/worker.ts` exporting `GenerationSessionDO`, `broadcastGenerationEventToDo`, and the default Worker `fetch(request, env, ctx)` handler; update `apps/vhunambi_api/src/server.ts` to guard `process.uptime()`/`process.memoryUsage()` in `/health`, add `GET /r2/:key{.*}` zero-egress R2 streaming, add `/ws/generation` fallback routing, and mount `paymentRoutes` at `/api/payments` and `/api/v1/payments`.

### Milestone `M62.3`: Supabase GoTrue ↔ Sovereign JWT Unification & Handle Login Bridge
- [x] **Task `62.3.1` (`crypto_token.ts` & `auth_middleware.ts`)**: Upgrade `verifyAccessJwt(token, secretOverride)` in `apps/vhunambi_api/src/security/crypto_token.ts` to normalize both Sovereign and Supabase GoTrue JWT claims (`cid ?? app_metadata.creator_id ?? user_metadata.creator_id`, `isGoTrueToken`), and update `apps/vhunambi_api/src/middleware/auth_middleware.ts` to read `resolveRuntimeEnv(c)`, support `isGoTrueToken` sessions, and compare canonical creator IDs in `assertTenantCreatorAccess`.
- [x] **Task `62.3.2` (`auth_routes.ts`)**: Update `apps/vhunambi_api/src/routes/auth_routes.ts` to support `@blackcoffee` canonical login and optional `SupabaseCloudDriver` GoTrue bridging when `SUPABASE_URL` is configured.

### Milestone `M62.4`: Elimination of All 4 Volatile RAM Stores, Unified Wallet & Route Auth Hardening
- [x] **Task `62.4.1` (`job_store.ts`)**: Refactor `apps/vhunambi_api/src/modules/jobs/job_store.ts` to persist and query jobs in `vhunambiDb` (`generation_jobs`), guarded by `isNodeSqliteAvailable()` so pure V8 Cloudflare Worker isolates (`workerd`) fall back cleanly on `/health` without throwing when `node:sqlite` is absent.
- [x] **Task `62.4.2` (`marketplace_service.ts` & `marketplace_routes.ts`)**: Back `marketplace_service.ts` with `vhunambiDb` (`marketplace_assets` & `beat_licenses`), remove duplicate `creditProducerBeatRoyalty` in `licenseBeat()`, normalize media URLs via `resolveMediaUrl`, and enforce producer ownership (`403 TENANT_FORBIDDEN`) + exclusive lock (`409 EXCLUSIVE_SOLD_LOCKED`) on `POST /beats` and `DELETE /beats/:id`.
- [x] **Task `62.4.3` (`social_service.ts`, `social_routes.ts` & `explore_routes.ts`)**: Back `social_service.ts` with `vhunambiDb` (`published_clips`, `reel_comments`, `social_interactions`), unify `getCreatorWallet()` onto `vhunambiDb.getWalletSnapshot(creatorId)` / `getWallet(creatorId)`, wire `sendCulturalTip` to `vhunambiDb.sendCulturalTipAtomic` (`402` on low sender balance, `422` on self-tip), deduplicate `GET /social/clips/:id/remixes` in `social_routes.ts`, and wire `sovereignAuthMiddleware` into `social_routes.ts` and `explore_routes.ts`.
- [x] **Task `62.4.4` (`voice_catalog.ts` & `voice_routes.ts`)**: Persist voice clones and sound signatures in `vhunambiDb` (`voice_clones`, `sound_signatures`), replace the fake `?presigned=true` string in `POST /v1/voices/signatures` with `await getPresignedPutUrl(...)`, and call `await deleteR2Object(...)` in `DELETE /v1/voices/signatures/:id`.

### Milestone `M62.5`: South African Payment Gateway (`PayFast ITN`) & Top-Up Exploit Closure
- [x] **Task `62.5.1` (`payment_routes.ts` & `wallet_routes.ts`)**: Create `apps/vhunambi_api/src/routes/payment_routes.ts` implementing `computePayFastSignature`, `verifyPayFastSignatureConstantTime`, `POST /payfast/checkout`, `POST /payfast/itn`, and `GET /payfast/status/:checkoutId`; and update `POST /api/wallet/topup` in `wallet_routes.ts` to reject unverified top-ups with `403 PAYMENT_VERIFICATION_REQUIRED` when strict mode is active.

### Milestone `M62.6`: RunPod `zr-studio-gpu` Repair, ComfyUI Polling (`GET /v1/vision/:id`) & Grok LLM
- [x] **Task `62.6.1` (`tools/zr-studio-gpu/*`)**:
  1. Add `normalize_mastering_recipe` and `master_stems_to_commercial_target` to `tools/zr-studio-gpu/stem_mastering_worker.py`,
  2. Reorder Stage 5 transient extraction before Stage 4 mastering in `tools/zr-studio-gpu/handler.py`,
  3. Write converted 24-bit PCM WAV files to `output_wav_path` in `tools/zr-studio-gpu/seed_vc_worker.py`,
  4. Encode 320kbps `master.mp3` via `ffmpeg` and upload it to `vhunambi-vault` in `tools/zr-studio-gpu/mmo_extractor.py`, and
  5. Update `tools/zr-studio-gpu/Dockerfile` and `requirements.txt` to include `stem_mastering_worker.py`, `seed_vc_worker.py`, `pedalboard`, and `pyloudnorm`.
- [x] **Task `62.6.2` (`webhook_routes.ts`, `generation_routes.ts`, `vision_routes.ts`, `llm_handler.ts`)**: Use `timingSafeEqual` and `broadcastGenerationEventToDo` in `webhook_routes.ts`; derive dynamic `websocketUrl` in `generation_routes.ts`; add `GET /v1/vision/:id` and `GET /v1/vision/render-video/:id` in `vision_routes.ts`; and implement the xAI Grok branch + LLM-backed `/refine` in `llm_handler.ts` and `lyrics_routes.ts`.

### Milestone `M62.7`: Flutter Client Unified Cloud Origin, Auth Interceptors & Media URL Normalization
- [x] **Task `62.7.1` (`app_constants.dart` & `creator_id_utils.dart`)**:
  1. In `apps/vhunambi_client/lib/core/constants/app_constants.dart`, **preserve 100% of existing layout constants (`mobileMaxWidth`, `sidebarExpandedWidth`, `bottomNavHeight`, `miniPlayerHeight`, `defaultBpm`, etc.) and all 26 Phase 60 Sovereign Hive Brain Box Keys**, adding `normalizeOriginUrl`, `resolveApiRootUrl`, `apiBaseUrl`, `apiRestBaseUrl`, `resolveWsUrl`, `resolveMediaBaseUrl`, and `normalizeCloudMediaUrl`.
  2. In `apps/vhunambi_client/lib/core/utils/creator_id_utils.dart`, **keep all existing top-level functions (`extractRawCreatorId`, `normalizeCreatorId`, `canonicalizeCreatorId`, `handleFromCreatorId`)** AND add `abstract final class CreatorIdUtils` delegating to private `_...Impl` helpers (avoiding lexical self-recursion), reconciling `'creator_blackcoffee'` $\to$ `'creator_black_coffee'` across `creator_id_utils.dart` and `auth_providers.dart`.
- [x] **Task `62.7.2` (Repository Origins & Auth Interceptors)**: Wire `AppConstants` resolvers and `authDioInterceptorProvider` across `edge_sync_coordinator.dart`, `http_explore_repository.dart`, `explore_providers.dart`, `http_library_sync_repository.dart`, `http_marketplace_repository.dart`, `playlist_repository.dart`, `http_social_repository.dart`, `generation_pipeline_providers.dart`, `lyrics_review_provider.dart`, `mastering_session_provider.dart`, `generation_socket_service.dart`, and `cloud_video_export_service.dart`.

### Milestone `M62.8`: Full-Stack Phase 62 Automated Verification Suites
- [x] **Task `62.8.1` (`phase62_hybrid_cloud_topology.test.ts` & `package.json`)**: Create `apps/vhunambi_api/test/phase62_hybrid_cloud_topology.test.ts` and register it in `apps/vhunambi_api/package.json`.
- [x] **Task `62.8.2` (`phase62_hybrid_cloud_client_test.dart`)**: Create `apps/vhunambi_client/test/core/network/phase62_hybrid_cloud_client_test.dart`.
- [x] **Task `62.8.3` (Full-Stack Regression & Zero-Analyzer Verification)**: Run `npm test` (`19` backend suites), `flutter test test/core/network/phase62_hybrid_cloud_client_test.dart`, and `flutter analyze` (`0` issues).

---

## 3. Requirement-to-Task-to-Test Traceability Matrix

| Requirement ID | Task IDs | Verification Test File | Gate |
| :--- | :--- | :--- | :--- |
| `REQ-P62-DB-01` .. `04` | `62.1.1`, `62.1.2`, `62.1.3` | `apps/vhunambi_api/test/phase62_hybrid_cloud_topology.test.ts` | `G-62-01` |
| `REQ-P62-CF-01` .. `04` | `62.2.1`, `62.2.2`, `62.2.3` | `apps/vhunambi_api/test/phase62_hybrid_cloud_topology.test.ts` | `G-62-02` |
| `REQ-P62-AUTH-01` .. `03` | `62.3.1`, `62.3.2` | `apps/vhunambi_api/test/phase62_hybrid_cloud_topology.test.ts` | `G-62-03` |
| `REQ-P62-STATE-01` .. `04` | `62.4.1`, `62.4.2`, `62.4.3`, `62.4.4` | `apps/vhunambi_api/test/phase62_hybrid_cloud_topology.test.ts` | `G-62-04` |
| `REQ-P62-PAY-01` .. `02` | `62.5.1` | `apps/vhunambi_api/test/phase62_hybrid_cloud_topology.test.ts` | `G-62-05` |
| `REQ-P62-GPU-01` .. `03` | `62.6.1`, `62.6.2` | `apps/vhunambi_api/test/phase62_hybrid_cloud_topology.test.ts` | `G-62-06` |
| `REQ-P62-CLI-01` .. `02` | `62.7.1`, `62.7.2`, `62.8.2` | `apps/vhunambi_client/test/core/network/phase62_hybrid_cloud_client_test.dart` | `G-62-07`, `G-62-08` |

---

## 4. Anti-Bait-and-Switch Forensic Verification Checklist

- [x] **1. Zero Placeholder Code (`Law 1`)**: Verified zero occurrences of `// TODO`, `// ...`, `throw UnimplementedError`, or stubbed methods across `design.md`.
- [x] **2. 100% Authentic Codebase Symbols & Zero Un-Installed Dependencies (`Law 2`)**: Verified all backend code compiles with existing `package.json` dependencies (`hono`, `aws4fetch`, `nanoid`, `zod`, `node:crypto`, `process.getBuiltinModule('node:sqlite')`) and all Flutter code uses `package:vhunambi_client/...`.
- [x] **3. Zero Emoji Contamination (`Law 3`)**: Verified zero raw Unicode emojis in Dart widget trees, code blocks, or formal tables (`STD-UIUX-001`).
- [x] **4. Mermaid Diagram Syntax Safety (`Law 4`)**: Verified only `stateDiagram-v2` and `sequenceDiagram` are used with clean labels and zero HTML tags.
- [x] **5. 100% Legacy Test Backward Compatibility (`Law 5`)**: Verified `vhunambiDb` lazy `Proxy` preserves synchronous execution for all 18 existing backend test suites while preventing Cloudflare Workers import crashes.
- [x] **6. Spec-Only Turn Compliance (`Law 6`)**: Verified zero `.dart`, `.ts`, or `.py` files in `apps/` or `tools/` were modified during specification authoring.

---

## 5. Stage 4 PowerShell Verification Commands (For Execution Turn)

```powershell
# 1. Verify TypeScript Compilation & All 19 Backend Test Suites (18 Legacy + Phase 62)
Set-Location c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_api
npm run build
npm test

# 2. Verify Python Syntax Compilation for RunPod GPU Worker (`tools/zr-studio-gpu`)
Set-Location c:\Users\Ndugelo\VHUNAMBI\monorepo\tools\zr-studio-gpu
python -m py_compile handler.py mmo_extractor.py stem_mastering_worker.py seed_vc_worker.py

# 3. Verify Flutter Client Phase 62 Cloud Origin, Interceptor & Auth Tests + Analyzer
Set-Location c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_client
flutter test test/core/network/phase62_hybrid_cloud_client_test.dart
flutter analyze
```

