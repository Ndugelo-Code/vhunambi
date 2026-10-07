# Phase 15 · Tasks Execution Plan — Full-Stack Autonomous Synthesis

> **Phase:** 15  
> **Codename:** `backend-engine-bridge`  
> **Status:** 🟢 COMPLETE  
> **Repository Root:** `c:\Users\Ndugelo\VHUNAMBI\monorepo\`  
> **Standard:** Dual-Agent Pair Programming Standard ([`docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md))  

---

## 1. Pre-Flight Checklist

- [x] Check Node.js and npm/pnpm availability in the Windows environment.
- [x] Inspect existing `apps/vhunambi_client` baseline (`flutter analyze` clean).
- [x] Verify source files in `C:\Users\Ndugelo\Zania-Explore-v2.5\Zania-Explore\lib\zr-studio\`.

---

## 2. Sequenced Implementation Tasks

### Part A: Backend API Gateway (`apps/vhunambi_api`)

- [x] **T1: Initialize `apps/vhunambi_api` Package**
  - Create `apps/vhunambi_api/package.json`, `tsconfig.json`, and directory structure.
  - Set up build and dev scripts (`pnpm dev`, `pnpm build`, `pnpm test`).
  - *Verification*: `pnpm build` exits 0.

- [x] **T2: Port Core ZR Studio Synthesis & Bantu Modules**
  - Port `prompt_compiler.ts` with African genre presets (Amapiano, Gqom, Maskandi, Kwaito).
  - Port `bantu/` linguistic modules (Tshivenḓa `ve` phonetic guidelines and cultural idioms).
  - Port `r2_storage.ts` for Cloudflare R2 presigned PUT/GET generation.
  - Port `runpod_adapter.ts` for ACE-Step GPU serverless dispatch.
  - *Verification*: Unit tests for prompt compilation and genre presets pass.

- [x] **T3: Port & Implement Story-to-Lyrics Engine**
  - Port Claude/Grok LLM handler with strict bracketed stanza schema (`[INTRO]`, `[VERSE 1]`, `[CHORUS]`, etc.).
  - Implement `POST /v1/lyrics/generate` and `POST /v1/lyrics/refine`.
  - *Verification*: Integration test querying `/v1/lyrics/generate` returns structured stanzas.

- [x] **T4: Implement Job Orchestrator, Mock Worker & Webhooks**
  - Implement in-memory / persistent job tracker (`job_store.ts`).
  - Implement `POST /v1/generations` and `GET /v1/generations/:id`.
  - Add realistic `mock_worker.ts` that simulates the 4-phase synthesis FSM when RunPod credentials are not set.
  - Implement HMAC-verified webhook `POST /v1/webhooks/ace-step`.
  - Implement observability health endpoint `GET /health` and `GET /v1/health`.
  - *Verification*: Full job submission -> progress ticks -> completion loop executes cleanly.

---

### Part B: Flutter Client Integration & Baseline Repair (`apps/vhunambi_client`)

- [x] **T5: Repair Baseline 16 Failing Beats Vault Tests**
  - Fix `beats_provider_test.dart` and `beats_vault_view_test.dart`.
  - Re-run `flutter test` to ensure 100% green baseline across all 627+ tests.
  - *Verification*: `flutter test test/features/beats/` reports 0 failures (87/87 tests passed).

- [x] **T6: Implement `HttpLyricsGenerationService` in Flutter**
  - Create `lib/features/studio/data/services/http_lyrics_generation_service.dart`.
  - Wire into `lyricsGenerationServiceProvider` with fallback to `FakeLyricsGenerationService` when offline.
  - Add unit tests validating JSON parsing into `LyricsReviewDraft` and `LyricsStanza`.
  - *Verification*: `flutter test test/features/studio/data/services/http_lyrics_generation_service_test.dart` passes.

- [x] **T7: Implement `HttpGenerationSubmissionService` & Wire Approval Flow**
  - Implement real job submission calling `POST /v1/generations`.
  - Update `lyrics_review_modal.dart` to submit to backend via `submitAndStartGeneration`.
  - Enable HTTP polling fallback in `GenerationPipelineNotifier` to stream 4-phase synthesis ticks.
  - Enable auto-play and stem download triggers upon completion.
  - *Verification*: Studio generation triggers real network submission and updates pipeline card.

---

### Part C: Full-Stack Verification & Handoff

- [x] **T8: Zero Static Analysis & 100% Green Test Suite**
  - Run `flutter analyze` in `apps/vhunambi_client` (reported `No issues found!`).
  - Run `flutter test` in `apps/vhunambi_client` (all 634 tests passing).
  - Run `pnpm build` in `apps/vhunambi_api` (exited 0).
  - Run `pnpm test` in `apps/vhunambi_api` (all tests passing).

- [x] **T9: Documentation & Walkthrough**
  - Update `README.md` to reflect Phase 15 status (Full-Stack Monorepo).
  - Generate comprehensive walkthrough artifact detailing how to run both client and API.
