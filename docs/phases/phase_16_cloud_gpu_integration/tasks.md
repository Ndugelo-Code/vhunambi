# Phase 16 · Tasks Execution Plan — Live Cloud & GPU Infrastructure Integration

> **Phase:** 16  
> **Codename:** `cloud-gpu-bridge`  
> **Status:** 🟢 COMPLETE  
> **Repository Root:** `c:\Users\Ndugelo\VHUNAMBI\monorepo\`  
> **Target App:** `apps/vhunambi_api` & `apps/vhunambi_client`  
> **Standard:** Dual-Agent Pair Programming Standard ([`docs/AI_AGENT_WORKFLOW_STANDARD.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/AI_AGENT_WORKFLOW_STANDARD.md))  

---

## 1. Pre-Flight Checklist

- [x] Verify Node.js and pnpm build tools in `apps/vhunambi_api`.
- [x] Inspect upstream `handler.py` and `r2_uploader.py` in `C:\Users\Ndugelo\Zania-Explore-v2.5\Zania-Explore\runpod-zr-studio\`.
- [x] Check client baseline (`flutter analyze` and `flutter test`).
- [x] Ensure non-destructive modifications to existing simulation/mock pipeline.

---

## 2. Sequenced Implementation Tasks

### Part A: RunPod Adapter & Synthesis Gateway Alignment (`apps/vhunambi_api`)

- [x] **T1: Prompt Compiler Metadata Extension**
  - Add `genre`, `mood`, `language`, and optional `title` to `CompiledSynthesisPrompt.metadata`.
  - Add `defaultMood` to `GenreSynthesisSpec` in `constants.ts` for all genre presets.
  - *Verification*: Prompt compiler populates complete song spec metadata.

- [x] **T2: RunPod Adapter Schema Alignment**
  - Rewrite `runpod_adapter.ts` to dispatch `{ input: { job_id, user_id, song_spec, webhook_url, loras } }` matching `handler.py`.
  - Use `Authorization: Bearer <RUNPOD_API_KEY>`.
  - Fall back cleanly to `simulateSynthesisPipeline` when RunPod environment keys are not configured.
  - *Verification*: Unit tests verify correct JSON payload structure without sending invalid prompt shape.

- [x] **T3: Webhook Route Status & Field Realignment**
  - Update `webhook_routes.ts` to process `handler.py` status transitions (`processing`, `uploading`, `completed`, `failed`).
  - Read `audio_url` from top-level callback payload.
  - Strip `vhunambi_` prefix when updating internal `job_store.ts` IDs.
  - Enforce HMAC verification (`x-zrs-signature` header with `ZR_WEBHOOK_SECRET`).
  - *Verification*: Webhook route parses mock callback and updates job store state.

- [x] **T4: Environment Configuration & Documentation**
  - Add `WEBHOOK_BASE_URL` to `env.ts` and `.env.example`.
  - Document required environment variables for shared RunPod and Cloudflare R2 bucket (`vhunambi-audio`).
  - *Verification*: `pnpm run build` succeeds without type errors.

---

### Part B: Flutter Client Graceful Degradation (`apps/vhunambi_client`)

- [x] **T5: Stems Graceful Degradation in Generation Pipeline**
  - Update `generation_pipeline_card.dart` / `TrackEntity` to handle tracks where stem bundles are not yet rendered by the single-WAV worker.
  - Ensure UI gracefully hides or communicates stem availability without crashing or triggering broken network downloads.
  - *Verification*: `flutter test test/features/studio/presentation/widgets/generation_pipeline_card_test.dart` passes (12/12 passed).

---

### Part C: Verification & Quality Gates

- [x] **T6: Backend Test Verification & Build Gate**
  - Run `pnpm run test` in `apps/vhunambi_api`.
  - Run `pnpm run build` in `apps/vhunambi_api`.
  - *Verification*: Zero build or test failures in `apps/vhunambi_api` (all 3 test suites passed, `tsc` exited 0).

- [x] **T7: Client Static Analysis & Test Gate**
  - Run `flutter analyze` in `apps/vhunambi_client`.
  - Run `flutter test` across all feature suites.
  - *Verification*: 0 analysis issues and 100% green test suite.

- [x] **T8: Phase 16 Walkthrough & Verification Report**
  - Generate `docs/phases/phase_16_cloud_gpu_integration/walkthrough.md`.
  - Document operational setup guide (Cloudflare R2 CORS, RunPod shared endpoint, and cloudflared tunnel command).
