# Phase 62: Hybrid Cloud Stack Topology & Production Edge Convergence — System Requirements

> **Document ID:** `VHUNAMBI-SPEC-P62-REQUIREMENTS-V1`
> **Phase:** `62 — Hybrid Cloud Stack Topology & Production Edge Convergence (Supabase + Cloudflare Workers/R2 + RunPod GPU)`
> **Engineering Standard:** `All-Gemini Engineering Standard (EARS + RFC-2119 Formal Specification)`
> **Status:** `HARDENED SPECIFICATION SUITE — READY FOR EXECUTION`
> **Audit Foundation:** `docs/audits/HYBRID_CLOUD_STACK_TOPOLOGY_PHASE62_AUDIT.md`

---

## 1. Document Scope, Origin Conventions & EARS / RFC-2119 Syntax

This specification defines the formal functional, persistence, cryptographic, edge-runtime, GPU-pipeline, payment-settlement, and client-networking requirements for **Phase 62: Hybrid Cloud Stack Topology & Production Edge Convergence** across:
- `supabase/migrations/` (PostgreSQL 19-table schema, RLS policies, and `FOR UPDATE` PL/pgSQL RPCs)
- `apps/vhunambi_api` (Cloudflare Workers Hono Edge Gateway, Durable Object WebSocket server, R2 zero-egress storage, PayFast ITN verifier, and dual-driver SQLite/Supabase persistence)
- `tools/zr-studio-gpu` (RunPod Serverless 5-stage synthesis, Seed-VC vocal conversion, stem mastering, and R2 artifact uploader)
- `apps/vhunambi_client` (Flutter Android/iOS/Desktop unified cloud origin, Dio auth interceptors, and PayFast checkout integration)

All requirements follow the **Easy Approach to Requirements Syntax (EARS)** (`UBIQUITOUS`, `EVENT-DRIVEN`, `STATE-DRIVEN`, `UNWANTED-BEHAVIOR`) paired with **RFC-2119** normative keywords (`MUST`, `MUST NOT`, `SHALL`, `SHOULD`, `MAY`).

---

## 2. Database Schema, Lazy SQLite Proxy & Atomic RPC Requirements (`REQ-P62-DB`)

### `REQ-P62-DB-01`: Complete 19-Table Schema Parity (`SQLite` $\leftrightarrow$ `Supabase PostgreSQL`)
- **Pattern:** `UBIQUITOUS`
- **Statement:** Both the production PostgreSQL migration (`supabase/migrations/20261110000001_phase62_hybrid_cloud_schema.sql`) and `VhunambiDatabase.migrate()` (`apps/vhunambi_api/src/db/vhunambi_db.ts`) **MUST** define and maintain all **19 canonical tables**: `creators`, `users`, `auth_sessions`, `sync_mutation_log`, `wallet_ledger`, `bank_accounts`, `explore_tracks`, `kinetic_posts`, `published_clips`, `reel_comments`, `marketplace_assets`, `beat_licenses`, `sound_signatures`, `user_library_sync`, `playlists`, `generation_jobs`, `voice_clones`, `social_interactions`, and `payment_topups`.
- **Acceptance Criteria:**
  1. `public.creators` includes both the Phase 59–61 columns (`archetype`, `tier`, `reputation_score`, `data_json`, `updated_at`) and the Supabase profile columns (`bio`, `followers_count`, `following_count`, `is_verified`, `created_at`).
  2. `public.sync_mutation_log` includes `creator_id TEXT NOT NULL DEFAULT 'system'` and composite index `idx_sync_mutation_creator_seq (creator_id, seq)`.
  3. All 7 seeded sovereign creators (`creator_cern`, `creator_makhadzi`, `creator_kabza`, `creator_focalistic`, `creator_tyla`, `creator_black_coffee`, plus canonical alias `creator_blackcoffee`), 12 regional heritage `explore_tracks`, and 6 `marketplace_assets` beats are deterministically seeded when empty.

### `REQ-P62-DB-02`: Lazy `process.getBuiltinModule` SQLite Loading & Cloudflare Workers Import Safety
- **Pattern:** `STATE-DRIVEN`
- **Statement:** **WHILE** `apps/vhunambi_api` is imported inside Cloudflare Workers (`workerd`) or any non-SQLite edge isolate, `vhunambi_db.ts` **MUST NOT** execute static top-level `import { DatabaseSync } from 'node:sqlite'`, `fs.mkdirSync()`, or `new VhunambiDatabase()` at module evaluation time.
- **Acceptance Criteria:**
  1. `vhunambi_db.ts` loads `node:sqlite`, `node:fs`, and `node:path` on demand via `process.getBuiltinModule(...)` and wraps `export const vhunambiDb` in a lazy-initializing `Proxy` that instantiates the default `VhunambiDatabase` only when a property or method is first invoked.
  2. `new VhunambiDatabase(':memory:')` in Node.js (`npm test`) continues to execute synchronously with 0 breaking changes across all 18 existing backend test suites.

### `REQ-P62-DB-03`: Parent-Row `FOR UPDATE` Serialization in Financial & Licensing RPCs
- **Pattern:** `EVENT-DRIVEN`
- **Statement:** **WHEN** executing a wallet payout (`execute_atomic_payout`), a beat license purchase (`record_beat_license_atomic`), or a cultural reel tip (`send_cultural_tip_atomic`), the database engine **MUST** acquire an exclusive transaction lock (`BEGIN IMMEDIATE` in SQLite; `SELECT id FROM public.creators WHERE id = p_creator_id FOR UPDATE` in PostgreSQL) before computing ledger balances or checking exclusive beat availability.
- **Acceptance Criteria:**
  1. Concurrent or sequential payout, beat license, or tip requests that exceed the caller's available `balanceCoins` or `balanceZar` are deterministically rejected (`INSUFFICIENT_FUNDS` / `INSUFFICIENT_WALLET_BALANCE`) without driving the ledger negative.
  2. `record_beat_license_atomic` locks the target `marketplace_assets` row (`FOR UPDATE`), rejects already-sold exclusive beats with `EXCLUSIVE_CONFLICT` (`409`), debits the buyer, credits 85% royalty to the producer in `wallet_ledger`, and marks `is_exclusive_sold = 1` when applicable.

### `REQ-P62-DB-04`: SQL-Level Tenant Delta-Sync Filtering & Outbox Mutation Validation
- **Pattern:** `UNWANTED-BEHAVIOR`
- **Statement:** **IF** a client submits a batch of outbox mutations via `POST /api/sync/mutations`, **THEN** `applyMutations()` **MUST NOT** call `topupWallet()` on `entityType === 'tip'` without first debiting the authenticated sender's wallet, and **MUST** look up canonical beat pricing from `marketplace_assets` on `entityType === 'beat_license'` rather than trusting client-supplied `amountPaidCoins` when `priceCoins > 0`. Furthermore, `getDelta()` **MUST** filter tenant visibility directly in the SQL `WHERE` clause rather than over-fetching `limit * 3` rows in memory.
- **Acceptance Criteria:**
  1. Submitting a `tip` mutation in `POST /api/sync/mutations` when the sender has `0` coins fails with a rejected mutation entry (`INSUFFICIENT_FUNDS`) and never mints free coins for the recipient or self.
  2. `getDelta(sinceSeq, limit, viewerCreatorId)` executes an indexed SQL query filtering `(creator_id = ? OR entity_type IN ('explore_track', 'kinetic_post', 'published_clip', 'reel_comment') OR (entity_type = 'playlist' AND ...))` directly in SQLite/PostgreSQL.

---

## 3. Cloudflare Workers Runtime, R2 Vault & Durable Object WebSocket Requirements (`REQ-P62-CF`)

### `REQ-P62-CF-01`: Cloudflare Worker Entrypoint (`src/worker.ts`) & `wrangler.toml` Configuration
- **Pattern:** `UBIQUITOUS`
- **Statement:** The backend package (`apps/vhunambi_api`) **MUST** provide a valid `wrangler.toml` configuration and `src/worker.ts` entrypoint exporting `default { fetch(request, env, ctx) }` and `GenerationSessionDO` that compiles cleanly under `npm run build` (`tsc`) with zero external un-installed npm dependencies.
- **Acceptance Criteria:**
  1. `wrangler.toml` declares `name = "vhunambi-api"`, `main = "src/worker.ts"`, `compatibility_flags = ["nodejs_compat"]`, `[vars]` (`R2_BUCKET = "vhunambi-vault"`), `[[r2_buckets]]` (`binding = "VHUNAMBI_VAULT"`), `[[hyperdrive]]` (`binding = "HYPERDRIVE"`), and `[durable_objects]` (`binding = "GENERATION_DO"`, `class_name = "GenerationSessionDO"`).
  2. `GET /health` and `GET /v1/health` guard `process.uptime()` and `process.memoryUsage()` with `typeof process` checks so edge isolates never throw `TypeError`.

### `REQ-P62-CF-02`: Request-Scoped Environment Resolution (`resolveRuntimeEnv`)
- **Pattern:** `EVENT-DRIVEN`
- **Statement:** **WHEN** any route, middleware, storage helper, or cryptographic module reads configuration secrets (`VHUNAMBI_JWT_SECRET`, `VHUNAMBI_AUTH_MODE`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `R2_BUCKET`, `R2_PUBLIC_BASE_URL`, `ZR_WEBHOOK_SECRET`, `PAYFAST_PASSPHRASE`), it **MUST** resolve them through `resolveRuntimeEnv(cOrEnv)` merging Cloudflare Worker `c.env` bindings over `process.env` defaults.
- **Acceptance Criteria:**
  1. Passing mock Worker `env` bindings to `app.fetch(request, mockEnv, mockCtx)` dynamically overrides `VHUNAMBI_JWT_SECRET`, `VHUNAMBI_AUTH_MODE`, `R2_PUBLIC_BASE_URL`, and `PAYFAST_PASSPHRASE` per request without mutating global `process.env`.

### `REQ-P62-CF-03`: Zero-Egress R2 Object Streaming & Unified `vhunambi-vault` Bucket
- **Pattern:** `EVENT-DRIVEN`
- **Statement:** **WHEN** a client requests `GET /r2/:key{.*}` on the Worker or requests a presigned upload/download URL via `r2_storage.ts`, the backend **MUST** target the standardized bucket `vhunambi-vault` (`R2_BUCKET`) and stream objects from `c.env.VHUNAMBI_VAULT` (with fallback to deterministic WAV/MP3 binary synthesis in offline dev/test mode).
- **Acceptance Criteria:**
  1. `r2_storage.ts` defaults `R2_BUCKET` to `'vhunambi-vault'` and generates valid AWS4-HMAC-SHA256 presigned `PUT` and `GET` URLs when `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, and `R2_ENDPOINT` are present.
  2. `GET /r2/:key{.*}` streams the object from `c.env.VHUNAMBI_VAULT.get(key)` with appropriate `Content-Type`, `Accept-Ranges: bytes`, and `Cache-Control` headers.

### `REQ-P62-CF-04`: `GenerationSessionDO` Durable Object WebSocket Server (`WS /ws/generation`)
- **Pattern:** `EVENT-DRIVEN`
- **Statement:** **WHEN** a client connects to `GET /ws/generation?id=<generationId>` (or dispatches a frame / webhook notification to `GenerationSessionDO`), the backend **MUST** support WebSocket upgrade, reply to `{"type":"PING"}` with `{"type":"PONG","timestamp":...}`, emit the current job state from `generation_jobs` on connect, and broadcast `{"type":"pipeline_event",...}` frames whenever `POST /v1/webhooks/ace-step` updates the generation job.
- **Acceptance Criteria:**
  1. `GenerationSessionDO` maintains connected WebSocket sessions per `generationId`, responds to `PING` frames with `PONG`, and broadcasts `pipeline_event` JSON payloads to all active sockets on `/internal/broadcast`.
  2. `POST /v1/generations` dynamically constructs `websocketUrl` from the incoming request origin (`ws://` or `wss://`) rather than hardcoding `ws://localhost:3000/ws/generation`.

---

## 4. Supabase GoTrue JWT Unification & Multi-Tenant Auth Requirements (`REQ-P62-AUTH`)

### `REQ-P62-AUTH-01`: Dual-Format JWT Claim Normalization (`Sovereign` + `Supabase GoTrue`)
- **Pattern:** `EVENT-DRIVEN`
- **Statement:** **WHEN** `verifyAccessJwt(token, secretOverride)` verifies an HS256 JWT signed with `VHUNAMBI_JWT_SECRET` (or `SUPABASE_JWT_SECRET`), it **MUST** accept both Sovereign Phase 61 claims (`{ sub, cid, hdl, sid, role }`) and Supabase GoTrue claims (`{ sub, session_id, email, role: 'authenticated', app_metadata, user_metadata }`), normalizing them into `SovereignJwtClaims` with `isGoTrueToken: boolean`.
- **Acceptance Criteria:**
  1. A JWT minted with Supabase GoTrue structure (`sub: '<uuid>', session_id: '<uuid>', role: 'authenticated', user_metadata: { creator_id: 'creator_cern', handle: '@cern' }`) passes `verifyAccessJwt()` with `cid === 'creator_cern'`, `hdl === '@cern'`, `role === 'creator'`, and `isGoTrueToken === true`.
  2. `sovereignAuthMiddleware` does not reject valid `isGoTrueToken === true` tokens when their `session_id` is absent from local SQLite `public.auth_sessions` (unless explicitly revoked in session tombstones).

### `REQ-P62-AUTH-02`: Canonical Creator ID Reconciliation (`@blackcoffee` Parity)
- **Pattern:** `UBIQUITOUS`
- **Statement:** Both `apps/vhunambi_api` (`canonicalizeCreatorId`) and `apps/vhunambi_client` (`CreatorIdUtils.canonicalizeCreatorId`) **MUST** normalize `'creator_blackcoffee'` and `'creator_black_coffee'` to the same canonical identifier (`'creator_black_coffee'`) while accepting both forms in login, lookup, and tenant ownership checks.
- **Acceptance Criteria:**
  1. Logging in with `@blackcoffee`, `creator_blackcoffee`, or `creator_black_coffee` resolves to `'creator_black_coffee'` and passes `assertTenantCreatorAccess` for either alias.

### `REQ-P62-AUTH-03`: Supabase GoTrue Auth Bridge with `@handle` Resolution
- **Pattern:** `STATE-DRIVEN`
- **Statement:** **WHILE** `SUPABASE_URL` and `SUPABASE_ANON_KEY`/`SUPABASE_SERVICE_ROLE_KEY` are configured in the runtime environment, `/api/auth/register`, `/api/auth/login`, `/api/auth/refresh`, and `/api/auth/logout` **MUST** support bridging authentication to Supabase GoTrue after resolving `@handle` identifiers to their registered email address, while returning the standard `AuthTokenBundle` response schema.
- **Acceptance Criteria:**
  1. Local SQLite auth continues to operate with zero network dependency when `SUPABASE_URL` is unset, and bridges via `SupabaseCloudDriver` when `SUPABASE_URL` is configured.

---

## 5. Volatile-RAM Elimination, Unified Wallet & Security Hardening Requirements (`REQ-P62-STATE`)

### `REQ-P62-STATE-01`: Elimination of All 4 Process-Local RAM Stores
- **Pattern:** `UBIQUITOUS`
- **Statement:** `job_store.ts`, `marketplace_service.ts`, `social_service.ts`, and `voice_catalog.ts` **MUST** persist and query all mutable state (`generation_jobs`, `marketplace_assets`, `beat_licenses`, `published_clips`, `reel_comments`, `social_interactions`, `voice_clones`, `sound_signatures`) in `VhunambiDatabase` / `SupabaseCloudDriver` rather than isolated in-memory `Map` or `Set` globals.
- **Acceptance Criteria:**
  1. Creating a generation job, publishing a clip, liking a clip/comment, following a creator, listing a beat, cloning a voice, or creating a sound signature persists across `VhunambiDatabase` instances and returns consistent state across endpoints.
  2. `GET /api/social/clips/:id/remixes` is registered exactly once in `social_routes.ts` (removing the 4 duplicate handler registrations) and queries `published_clips WHERE remixed_from_clip_id = ?`.

### `REQ-P62-STATE-02`: Unified Creator Wallet Ledger & Elimination of Double Royalty Credit
- **Pattern:** `EVENT-DRIVEN`
- **Statement:** **WHEN** a client calls `GET /api/creators/:id/wallet` or `GET /api/wallet/:creatorId`, both routes **MUST** return the exact same ledger balance and transaction history from `vhunambiDb.getWalletSnapshot(creatorId)`. Furthermore, `licenseBeat()` **MUST NOT** call volatile `creditProducerBeatRoyalty()` in addition to `recordBeatLicenseAtomic()`.
- **Acceptance Criteria:**
  1. Licensing a beat for `500` coins credits the producer's `wallet_ledger` exactly once with `85%` (`425` coins / `R 85.00`), and both `GET /api/wallet/:producerId` and `GET /api/creators/:producerId/wallet` reflect the identical `balanceCoins` and `balanceZar`.

### `REQ-P62-STATE-03`: Atomic Cultural Tip Debit & Remix Split (`sendCulturalTipAtomic`)
- **Pattern:** `EVENT-DRIVEN`
- **Statement:** **WHEN** a client calls `POST /api/social/clips/:id/tip`, the backend **MUST** verify the caller's identity via `sovereignAuthMiddleware`, verify that the sender has sufficient balance in `wallet_ledger`, atomically debit the sender, credit the clip creator (or split 70% to the remixer and 30% to the original stem ancestor when `remixedFromClipId` is present), and insert a persistent celebration comment in `reel_comments`.
- **Acceptance Criteria:**
  1. Attempting to tip a clip when the sender's wallet balance is less than the tip amount returns `402 Payment Required` (`INSUFFICIENT_WALLET_BALANCE`) and neither credits the recipient nor posts a gift comment.
  2. Self-tipping (`senderId === clip.creatorId`) is rejected with `422 SELF_TIP_FORBIDDEN`.

### `REQ-P62-STATE-04`: Producer Ownership Guards on Marketplace & Explore Writes
- **Pattern:** `UNWANTED-BEHAVIOR`
- **Statement:** **IF** an authenticated caller attempts to create/overwrite (`POST /api/marketplace/beats`) or delete (`DELETE /api/marketplace/beats/:id`) a beat owned by a different `producerId`, or delete a beat that has already been sold exclusively (`isExclusiveSold === true`), **THEN** the backend **MUST** reject the request with `403 TENANT_FORBIDDEN` or `409 EXCLUSIVE_SOLD_LOCKED`.
- **Acceptance Criteria:**
  1. `@makhadzi` attempting to `DELETE /api/marketplace/beats/beat_1` (owned by `@kabza` / `producer_kabza`) receives `403 TENANT_FORBIDDEN`, and `beat_1` remains intact in `marketplace_assets`.

---

## 6. South African Payment Gateway (`PayFast ITN`) & Financial Exploit Closure Requirements (`REQ-P62-PAY`)

### `REQ-P62-PAY-01`: Closure of Unverified `POST /api/wallet/topup` in Strict Mode
- **Pattern:** `UNWANTED-BEHAVIOR`
- **Statement:** **IF** `POST /api/wallet/topup` is called while strict auth/production mode is active (`x-vhunambi-enforce-auth: true`, `VHUNAMBI_AUTH_MODE=strict`, or `NODE_ENV=production`) without a valid `x-vhunambi-payment-signature` HMAC header, **THEN** the route **MUST** reject the request with `403 FORBIDDEN` (`PAYMENT_VERIFICATION_REQUIRED`).
- **Acceptance Criteria:**
  1. Any unverified `POST /api/wallet/topup` request under strict mode returns `403 PAYMENT_VERIFICATION_REQUIRED` and leaves `wallet_ledger` unchanged.

### `REQ-P62-PAY-02`: PayFast Checkout Initiation & Ordered MD5 ITN Verification (`/api/payments/payfast/*`)
- **Pattern:** `EVENT-DRIVEN`
- **Statement:** **WHEN** a client calls `POST /api/payments/payfast/checkout`, the backend **MUST** create a `'pending'` record in `payment_topups` and return signed PayFast checkout parameters; **WHEN** PayFast invokes `POST /api/payments/payfast/itn`, the backend **MUST** verify the ordered MD5 signature (using `PAYFAST_PASSPHRASE` and `timingSafeEqual`), verify `payment_status === 'COMPLETE'` and `amount_gross` parity, enforce `pf_payment_id` idempotency, and atomically credit `wallet_ledger`.
- **Acceptance Criteria:**
  1. `POST /api/payments/payfast/checkout` requires authentication (`assertTenantCreatorAccess`) and returns `201 Created` with `{ checkoutId, paymentUrl, formFields, signature, amountZar, coinsToCredit }`.
  2. `POST /api/payments/payfast/itn` with a forged MD5 signature returns `400 INVALID_PAYFAST_SIGNATURE` and credits `0` coins.
  3. `POST /api/payments/payfast/itn` with a valid signature credits the creator's `wallet_ledger` exactly once; replaying the same ITN payload (`pf_payment_id`) returns `200 OK` (`idempotentReplay: true`) without double-crediting.

---

## 7. RunPod Serverless GPU (`zr-studio-gpu`), Vision Polling & Grok LLM Requirements (`REQ-P62-GPU`)

### `REQ-P62-GPU-01`: RunPod `zr-studio-gpu` Mastering Import, Seed-VC Disk Write & MP3 R2 Upload
- **Pattern:** `UBIQUITOUS`
- **Statement:** The RunPod GPU worker (`tools/zr-studio-gpu/`) **MUST** expose `master_stems_to_commercial_target` in `stem_mastering_worker.py` (normalizing both flat and nested mastering recipes and accepting Stage 5 `transient_events`), write 24-bit PCM converted vocal WAV files to `output_wav_path` in `seed_vc_worker.py`, encode 320kbps `master.mp3` via `ffmpeg` and upload it to R2 (`vhunambi-vault`) in `mmo_extractor.py`, and copy all worker Python modules into `Dockerfile` with `pedalboard` and `pyloudnorm` in `requirements.txt`.
- **Acceptance Criteria:**
  1. `handler.py` extracts Stage 5 transient metadata prior to Stage 4 stem mastering and executes without `ImportError` or `KeyError`.
  2. `seed_vc_worker.py` writes valid stereo audio samples to `output_wav_path` so `os.path.exists(converted_vox_path)` is `True`.
  3. `mmo_extractor.py` uploads `master.mp3` (and `master.wav`) to R2, populates `result_urls["master_mp3_url"]`, and returns a non-null `audio_url` in the final webhook payload.

### `REQ-P62-GPU-02`: Constant-Time Webhook Verification & Durable Object Broadcast
- **Pattern:** `EVENT-DRIVEN`
- **Statement:** **WHEN** `POST /v1/webhooks/ace-step` receives a RunPod callback, it **MUST** verify `x-zrs-signature` using `timingSafeEqual`, persist `masterMp3Url`, `stemsZipUrl`, `stemUrls`, and `manifest` into `generation_jobs`, and notify `GenerationSessionDO` so connected WebSocket clients receive the `pipeline_event` immediately.
- **Acceptance Criteria:**
  1. Valid HMAC webhooks update the persistent `generation_jobs` record and push the update to active `/ws/generation` subscribers; invalid signatures return `401 Unauthorized`.

### `REQ-P62-GPU-03`: Vision Job Polling (`GET /v1/vision/:id`), Real Voice Signature Presigning & Grok LLM
- **Pattern:** `EVENT-DRIVEN`
- **Statement:** **WHEN** clients interact with `/v1/vision/*`, `/v1/voices/signatures`, or `/v1/lyrics/*`, the backend **MUST**:
  1. Provide `GET /v1/vision/:id` and `GET /v1/vision/render-video/:id` to poll persisted vision/video jobs in `generation_jobs` using `R2_PUBLIC_BASE_URL` media URLs,
  2. Generate genuine AWS4 S3 presigned `PUT` URLs via `getPresignedPutUrl` in `POST /v1/voices/signatures` and delete R2 objects on `DELETE /v1/voices/signatures/:id`, and
  3. Support xAI Grok (`GROK_API_KEY` via `https://api.x.ai/v1/chat/completions`) in `llm_handler.ts` alongside Anthropic Claude and LLM-backed `POST /v1/lyrics/refine`.
- **Acceptance Criteria:**
  1. `GET /v1/vision/:id` returns the persisted vision job status and resolved R2 output URL.
  2. `POST /v1/voices/signatures` returns a presigned upload URL from `getPresignedPutUrl` and persists the signature in `sound_signatures`.

---

## 8. Flutter Client Unified Cloud Origin, Auth Interceptors & Checkout Requirements (`REQ-P62-CLI`)

### `REQ-P62-CLI-01`: Unified `AppConstants` Cloud Origin, WebSocket & Media URL Normalization
- **Pattern:** `UBIQUITOUS`
- **Statement:** `AppConstants` (`apps/vhunambi_client/lib/core/constants/app_constants.dart`) **MUST** derive `resolveApiRootUrl()`, `apiBaseUrl`, `resolveWsUrl()`, `resolveMediaBaseUrl()`, and `normalizeCloudMediaUrl()` from `--dart-define=API_BASE_URL` and `--dart-define=MEDIA_BASE_URL` (stripping any trailing `/` or `/v1` suffix on root resolution and falling back to local `:3000` only when unset).
- **Acceptance Criteria:**
  1. Regardless of whether `API_BASE_URL` is passed as `https://vhunambi-api.prod.workers.dev` or `https://vhunambi-api.prod.workers.dev/v1`, `resolveApiRootUrl()` returns `'https://vhunambi-api.prod.workers.dev'`, `apiBaseUrl` returns `'https://vhunambi-api.prod.workers.dev/v1'`, and `resolveWsUrl()` returns `'wss://vhunambi-api.prod.workers.dev/ws/generation'`.
  2. `normalizeCloudMediaUrl(rawUrl)` rewrites legacy `https://r2.vhunambi.com/*`, `https://cdn.vhunambi.com/*`, `https://cdn.vhunambi.za/*`, `https://assets.vhunambi.com/*`, and `/mock-storage/*` paths to `resolveMediaBaseUrl()`.

### `REQ-P62-CLI-02`: 100% Repository Base URL & Auth Interceptor Convergence
- **Pattern:** `UBIQUITOUS`
- **Statement:** All Flutter networking services—`SovereignAuthRepository`, `EdgeSyncCoordinator`, `HttpExploreRepository`, `HttpLibrarySyncRepository`, `HttpMarketplaceRepository`, `PlaylistRepository`, `HttpSocialRepository`, `HttpGenerationSubmissionService`, `HttpLyricsGenerationService`, `MasteringSessionNotifier`, `GenerationSocketService`, and `CloudVideoExportService`—**MUST** use `AppConstants.resolveApiRootUrl()` / `apiBaseUrl` / `resolveWsUrl()`, and `exploreRepositoryProvider`, `generationSubmissionServiceProvider`, `lyricsGenerationServiceProvider`, and `MasteringSessionNotifier` **MUST** attach Sovereign auth headers/interceptors.
- **Acceptance Criteria:**
  1. Zero networking repositories hardcode `http://localhost:3000`, `http://10.0.2.2:3000`, `https://api.vhunambi.com`, or `https://vhunambi-api.zaniaexplore.co.za/v1` directly instead of calling `AppConstants`.
  2. `exploreRepositoryProvider`, `generationSubmissionServiceProvider`, and `lyricsGenerationServiceProvider` attach `ref.watch(authDioInterceptorProvider)` to their `Dio` instances.

---

## 9. Non-Functional & Zero-Regression Requirements (`REQ-P62-NFR`)

- **`REQ-P62-NFR-01` (Zero Un-Installed NPM Dependencies)**: All Phase 62 backend additions **MUST** compile and pass tests using only the packages already installed in `apps/vhunambi_api/package.json` (`hono`, `aws4fetch`, `nanoid`, `zod`, `node:crypto`, `node:sqlite` via `process.getBuiltinModule`, and standard `fetch`).
- **`REQ-P62-NFR-02` (Sub-Second Offline Test Execution)**: All 18 existing backend test suites plus `phase62_hybrid_cloud_topology.test.ts` and all Flutter unit/widget tests **MUST** run 100% offline with zero live internet calls required during `npm test` or `flutter test`.
- **`REQ-P62-NFR-03` (Zero Raw Emojis Law — `STD-UIUX-001`)**: All Dart and TypeScript code blocks, UI labels, and specification tables **MUST** contain zero raw Unicode emojis.

---

## 10. Requirement-to-Test Traceability Matrix

| Requirement ID | Primary Implementation Files | Verification Test Suite | Gate |
| :--- | :--- | :--- | :--- |
| `REQ-P62-DB-01` .. `04` | `supabase/migrations/20261110000001_phase62_hybrid_cloud_schema.sql`, `vhunambi_db.ts`, `supabase_cloud_driver.ts` | `apps/vhunambi_api/test/phase62_hybrid_cloud_topology.test.ts` | `G-62-01` |
| `REQ-P62-CF-01` .. `04` | `wrangler.toml`, `src/worker.ts`, `src/config/env.ts`, `src/server.ts`, `r2_storage.ts` | `apps/vhunambi_api/test/phase62_hybrid_cloud_topology.test.ts` | `G-62-02` |
| `REQ-P62-AUTH-01` .. `03` | `crypto_token.ts`, `auth_middleware.ts`, `auth_routes.ts` | `apps/vhunambi_api/test/phase62_hybrid_cloud_topology.test.ts` | `G-62-03` |
| `REQ-P62-STATE-01` .. `04` | `job_store.ts`, `marketplace_service.ts`, `social_service.ts`, `voice_catalog.ts`, `social_routes.ts`, `marketplace_routes.ts` | `apps/vhunambi_api/test/phase62_hybrid_cloud_topology.test.ts` | `G-62-04` |
| `REQ-P62-PAY-01` .. `02` | `payment_routes.ts`, `wallet_routes.ts`, `sync_routes.ts` | `apps/vhunambi_api/test/phase62_hybrid_cloud_topology.test.ts` | `G-62-05` |
| `REQ-P62-GPU-01` .. `03` | `tools/zr-studio-gpu/*`, `vision_routes.ts`, `voice_routes.ts`, `llm_handler.ts`, `webhook_routes.ts` | `apps/vhunambi_api/test/phase62_hybrid_cloud_topology.test.ts` | `G-62-06` |
| `REQ-P62-CLI-01` .. `02` | `app_constants.dart`, `creator_id_utils.dart`, `explore_providers.dart`, `generation_pipeline_providers.dart`, `lyrics_review_provider.dart`, repositories | `apps/vhunambi_client/test/core/network/phase62_hybrid_cloud_client_test.dart` | `G-62-07`, `G-62-08` |

