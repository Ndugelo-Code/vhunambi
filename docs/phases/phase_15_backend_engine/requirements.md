# Phase 15 · Requirements Specification — Autonomous African AI Music Synthesis API & Bridge

> **Phase:** 15  
> **Codename:** `backend-engine-bridge`  
> **Status:** 🟡 SPECIFICATION  
> **Repository Root:** `c:\Users\Ndugelo\VHUNAMBI\monorepo\`  
> **Target Apps:** `apps/vhunambi_api` & `apps/vhunambi_client`  
> **Requirement Standard:** RFC 2119 (`MUST`, `SHALL`, `SHOULD`, `MAY`) & Easy Approach to Requirements Syntax (EARS)  

---

## 1. Backend Service & API Requirements (`apps/vhunambi_api`)

### REQ-BE-01: Monorepo Package Initialization
The monorepo **SHALL** maintain a dedicated backend service at `apps/vhunambi_api` configured with TypeScript 5.x, Node.js (or Edge runtime), and automated script targets for `dev`, `build`, and `test`.

### REQ-BE-02: Environment Configuration & Fallbacks
The backend **MUST** read environment variables (`RUNPOD_API_KEY`, `RUNPOD_ENDPOINT_ID`, `ANTHROPIC_API_KEY`, `GROK_API_KEY`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET_NAME`, `ZR_WEBHOOK_SECRET`) from `.env`. When external credentials are not supplied in local development, it **SHALL** gracefully fall back to a mock inference worker that simulates progress ticks and produces deterministic audio stems.

### REQ-BE-03: Story-to-Lyrics Endpoint (`POST /v1/lyrics/generate`)
When receiving a generation prompt, genre, and language code:
1. The backend **MUST** invoke the LLM handler (Claude 3.5 Sonnet / Grok) using genre-specific system prompts.
2. The response **MUST** contain structured stanzas labeled with standard bracketed headers (`[INTRO]`, `[VERSE 1]`, `[PRE-CHORUS]`, `[CHORUS]`, `[BRIDGE]`, `[OUTRO]`).
3. The response **MUST** include `vocal_instructions`, `detected_language`, `mood_analysis`, and `culture_tags`.

### REQ-BE-04: Interactive Lyrics Refinement (`POST /v1/lyrics/refine`)
The backend **MUST** provide an endpoint accepting `current_lyrics`, `refinement_instruction`, and optional `idiom_to_insert`. It **SHALL** return an updated version of the lyrics maintaining the bracketed structural integrity.

### REQ-BE-05: Prompt Compiler & Bantu Engine
When compiling a `SongSpec` for synthesis:
1. The backend **MUST** resolve the genre default BPM range, default key, and characteristic instrumentation (e.g., Amapiano log drum, shakers, piano stabs).
2. The backend **MUST** support indigenous South African languages (featuring Tshivenḓa `ve`, Zulu `zu`, Xhosa `xh`) with phonetic pronunciation instructions for vocal synthesis.
3. The prompt compiler **SHALL** output a language-neutral genre caption, sectioned lyrics, and exact numerical metadata (BPM, key, duration in seconds).

### REQ-BE-06: Synthesis Job Dispatch (`POST /v1/generations`)
When a generation job is submitted:
1. The backend **MUST** validate the input parameters against `GenerateRequestSchema`.
2. The backend **MUST** mint a unique `generation_id` (`gen_<timestamp>_<nanoid>`).
3. The backend **MUST** generate Cloudflare R2 presigned PUT URLs for `master.mp3` and `stems.zip`.
4. The backend **MUST** dispatch the payload to the RunPod ACE-Step endpoint and return HTTP 201 with `{ generation_id, status: "queued", poll_url }`.

### REQ-BE-07: HMAC-Verified GPU Webhook (`POST /v1/webhooks/ace-step`)
1. The webhook endpoint **MUST** verify the `x-zrs-signature` header using `HMAC-SHA256(rawBody, ZR_WEBHOOK_SECRET)`.
2. Unsigned or invalid requests **MUST** be rejected with HTTP 401.
3. Valid progress ticks **MUST** update the in-memory or database job state.
4. On `succeeded`, the backend **MUST** generate 24-hour presigned GET URLs for the uploaded audio assets.

### REQ-BE-08: Job Status & Polling (`GET /v1/generations/:id`)
The backend **MUST** expose an endpoint returning current status (`queued`, `running`, `succeeded`, `failed`), progress percentage (`0-100`), error codes, and the final `master_mp3_url` upon completion.

---

## 2. Flutter Client Integration Requirements (`apps/vhunambi_client`)

### REQ-BE-21: Configurable API Base URL
The Flutter client **MUST** read its API origin from `AppConstants.apiBaseUrl`, which **SHALL** be overridable via `--dart-define=API_BASE_URL=<url>` or runtime configuration (defaulting to `http://localhost:3000/v1` in debug mode).

### REQ-BE-22: Real HTTP Lyrics Generation Service
The client **MUST** implement `HttpLyricsGenerationService` satisfying `ILyricsGenerationService`:
1. It **SHALL** replace `FakeLyricsGenerationService` as the default in `lyricsGenerationServiceProvider`.
2. It **MUST** call `POST /v1/lyrics/generate` using `Dio`.
3. If network fails, it **SHALL** surface a descriptive error to the `LyricsReviewModal` rather than crashing.

### REQ-BE-23: Generation Submission Service
The client **MUST** submit approved lyrics, genre, and prompt to `POST /v1/generations` when the user taps "Approve & Produce Beat":
1. It **MUST** obtain a server-minted `generation_id` rather than relying purely on client-side timestamp IDs.
2. It **MUST** transition `GenerationPipelineNotifier` into the active tracking phase.

### REQ-BE-24: Dual-Transport Pipeline Tracking (WebSocket + Polling Fallback)
1. The client **SHALL** attempt real-time tracking via WebSocket (`ws://<host>/ws/generation?id=<id>`).
2. If WebSocket connection fails or times out, the client **MUST** automatically fall back to polling `GET /v1/generations/:id` every 2 seconds until terminal state (`succeeded` / `failed`).

### REQ-BE-25: Presigned R2 Playback & Stem Downloading
When the job completes:
1. `StemDownloadService` **MUST** download the master MP3 from the presigned R2 URL provided in the `ready` payload into `<temp>/vhunambi_downloads/`.
2. `AudioSourceResolver` **MUST** play directly from the presigned URL if the local file is not yet cached.

---

## 3. Quality & Regression Requirements

### REQ-BE-31: Zero Static Analysis Errors
Both `flutter analyze` in `apps/vhunambi_client` and `npm run lint` / `tsc --noEmit` in `apps/vhunambi_api` **MUST** report **0 errors / 0 issues**.

### REQ-BE-32: Repair Baseline Test Failures (Beats Vault)
The 16 failing tests in `apps/vhunambi_client/test/features/beats/` identified in the audit **MUST** be repaired to ensure 100% test pass rate across all suites.
