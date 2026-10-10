# Phase 16 · Requirements — Live Cloud & GPU Infrastructure Integration

> **Phase:** 16  
> **Codename:** `cloud-gpu-bridge`  
> **Status:** 🟡 SPECIFICATION  
> **Standard:** EARS (Easy Approach to Requirements Syntax) + RFC 2119 modal verbs  

---

## 1. Functional Requirements

### REQ-16-01: RunPod Adapter Payload Alignment
**[SHALL]** The `dispatchSynthesisJob()` function in `runpod_adapter.ts` SHALL produce a JSON request body whose `input` object contains exactly the following fields consumed by `handler.py`'s `runpod_handler()`:
- `job_id` (string): prefixed `vhunambi_{generationId}`
- `user_id` (string): creator identity string (defaults to `"vhunambi_user"` when auth not yet implemented)
- `song_spec` (object): containing `genre`, `tempo`, `mood`, `duration`, `lyrics`, `language`, and optionally `title`
- `webhook_url` (string): absolute HTTPS URL pointing to `POST /v1/webhooks/ace-step` on the publicly reachable tunnel host
- `loras` (optional array): array of `{path, weight}` objects for LoRA conditioning

**[SHALL NOT]** The adapter SHALL NOT send the Phase 15 prompt-style payload (`prompt.caption`, `prompt.lyrics`, `output.audio_put_url`) to the shared RunPod endpoint.

### REQ-16-02: Webhook HMAC Verification
**[SHALL]** The `POST /v1/webhooks/ace-step` route SHALL verify every inbound callback by:
1. Reading the raw request body as a UTF-8 string.
2. Computing `HMAC-SHA256(key=ZR_WEBHOOK_SECRET, message=body_sorted_compact_json)`.
3. Comparing with the value in `x-zrs-signature` header via constant-time comparison.
4. Returning HTTP 401 and discarding the payload if signatures do not match.

### REQ-16-03: Job Store Audio URL Persistence
**[SHALL]** Upon receiving a `completed` webhook callback, the gateway SHALL:
1. Parse `audio_url` from the payload (R2 public URL).
2. Update the corresponding job record in `jobStore` to `status: "completed"` with `audioUrl` populated.
3. This change SHALL be immediately observable by `GET /v1/generations/:id`.

### REQ-16-04: Stem Download Graceful Degradation
**[SHALL]** Since the current GPU worker does not produce a stem ZIP, the Flutter `_ReadyTrackCard` widget SHALL hide the "Download Stems" button when `stemsUrl` is null or absent in the job completion payload.

**[SHALL NOT]** The app SHALL NOT render a broken download action for stems until a GPU worker update (Phase 17) explicitly returns a `stems_url` field.

### REQ-16-05: Webhook Tunnel Configuration
**[SHALL]** `apps/vhunambi_api` SHALL read the public webhook base URL from `WEBHOOK_BASE_URL` environment variable and use it to construct the `webhook_url` value passed to RunPod.

**[SHOULD]** When `WEBHOOK_BASE_URL` is not set and `NODE_ENV=development`, the gateway SHOULD log a prominent warning: `[WARNING] WEBHOOK_BASE_URL not configured. RunPod callbacks will fail. Start cloudflared tunnel and set this variable.`

### REQ-16-06: Cloudflare R2 Bucket Isolation
**[SHALL]** VHUNAMBI's generated audio assets SHALL be stored exclusively in the `vhunambi-audio` R2 bucket under the path `generated/{userId}/{jobId}.wav`.

**[SHALL NOT]** VHUNAMBI assets SHALL NOT be written to ZR Studio's existing R2 bucket.

### REQ-16-07: R2 CORS Configuration
**[SHALL]** The `vhunambi-audio` R2 bucket SHALL have a CORS policy allowing:
- `GET` and `HEAD` requests from `https://vhunambi.com`, `https://www.vhunambi.com`, and `http://localhost:*`
- `Content-Type`, `Accept-Ranges`, and `Content-Length` response headers exposed

### REQ-16-08: Full End-to-End Generation Test
**[SHALL]** At least one successful end-to-end generation cycle SHALL be demonstrated and verified:
1. Lyrics generated via `/v1/lyrics/generate`.
2. Job submitted via `/v1/generations` (dispatches to real RunPod).
3. Webhook callback received, HMAC verified, job updated to `completed`.
4. `GET /v1/generations/:jobId` returns `status: completed` with a valid `audioUrl`.
5. Flutter pipeline card advances to `Ready` and loads audio into player.

---

## 2. Non-Functional Requirements

### REQ-16-NF-01: Zero Idle Cost
The RunPod endpoint is serverless; no additional monthly standby cost SHALL be incurred by VHUNAMBI sharing the existing endpoint.

### REQ-16-NF-02: Credentials Security
**[SHALL]** All API keys, secrets, and R2 credentials SHALL be stored in `apps/vhunambi_api/.env` which is already excluded from git via the root `.gitignore`.

**[SHALL NOT]** Credentials SHALL NOT be committed to the GitHub repository.

### REQ-16-NF-03: Backward Compatibility with Mock Worker
**[SHALL]** When `RUNPOD_API_KEY` or `RUNPOD_ENDPOINT_ID` are not set, the gateway SHALL fall back to the local `mock_worker.ts` simulation pipeline without any code changes.

---

## 3. Credential Inventory

The following table defines every credential required for Phase 16 to function end-to-end:

| Env Variable | Source | Description |
|:---|:---|:---|
| `RUNPOD_API_KEY` | RunPod Dashboard → Settings → API Keys | Bearer token for RunPod REST API |
| `RUNPOD_ENDPOINT_ID` | RunPod Dashboard → Serverless → Endpoints | ID of the `zr-studio-gpu` endpoint |
| `ANTHROPIC_API_KEY` | Anthropic Console | Claude API for story-to-lyrics |
| `GROK_API_KEY` | x.ai Console (optional) | Alternative LLM |
| `R2_ACCESS_KEY_ID` | Cloudflare Dashboard → R2 → Manage API Tokens | S3-compatible access key |
| `R2_SECRET_ACCESS_KEY` | Cloudflare Dashboard → R2 → Manage API Tokens | S3-compatible secret |
| `R2_ENDPOINT` | Cloudflare Dashboard → R2 → `vhunambi-audio` bucket | Format: `https://{ACCOUNT_ID}.r2.cloudflarestorage.com` |
| `R2_BUCKET` | Fixed | `vhunambi-audio` |
| `ZR_WEBHOOK_SECRET` | **Copy from ZR Studio** — same value as GPU worker has | Must match exactly what `handler.py` uses for HMAC |
| `WEBHOOK_BASE_URL` | cloudflared tunnel output | e.g. `https://abc123.trycloudflare.com` |
