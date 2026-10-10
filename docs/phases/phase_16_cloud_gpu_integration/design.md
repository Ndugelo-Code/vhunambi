# Phase 16 · Design — Live Cloud & GPU Infrastructure Integration

> **Phase:** 16  
> **Codename:** `cloud-gpu-bridge`  
> **Status:** 🟡 SPECIFICATION  

---

## 1. Files Modified

| File | Change Type | Description |
|:---|:---:|:---|
| `apps/vhunambi_api/src/modules/synthesis/runpod_adapter.ts` | **MODIFY** | Align `input` payload to `handler.py` schema |
| `apps/vhunambi_api/src/routes/webhook_routes.ts` | **MODIFY** | Fix payload field names to match `handler.py`'s webhook shape |
| `apps/vhunambi_api/src/config/env.ts` | **MODIFY** | Add `WEBHOOK_BASE_URL` env variable |
| `apps/vhunambi_api/.env.example` | **MODIFY** | Add `WEBHOOK_BASE_URL` and `USER_ID_DEFAULT` |
| `apps/vhunambi_client/.../generation_pipeline_card.dart` | **MODIFY** | Hide "Download Stems" when `stemsUrl` is null |

---

## 2. `runpod_adapter.ts` — New Payload Schema

### Why it changes
Phase 15's adapter sent a prompt-style payload that doesn't match `handler.py`. The GPU worker expects `song_spec` with `genre`, `tempo`, `mood`, `duration`, `lyrics`, and `language`, not `prompt.caption`.

### New dispatch payload
```typescript
// POST https://api.runpod.ai/v2/{RUNPOD_ENDPOINT_ID}/run
{
  input: {
    job_id:      `vhunambi_${generationId}`,
    user_id:     userId,            // string from context, defaults "vhunambi_user"
    song_spec: {
      genre:    prompt.metadata.genre,       // e.g. "amapiano"
      tempo:    prompt.metadata.bpm,         // e.g. 116
      mood:     prompt.metadata.mood,        // e.g. "energetic"
      duration: prompt.metadata.durationSec, // seconds int
      lyrics:   prompt.lyrics,               // full bracketed stanza text
      language: prompt.metadata.language,    // e.g. "tshivenda"
      title:    prompt.metadata.title,       // optional
    },
    webhook_url: `${WEBHOOK_BASE_URL}/v1/webhooks/ace-step`,
    loras: [],    // empty for now; Phase 17 will add Bantu vocal LoRAs
  }
}
```

### Authorization header
```
Authorization: Bearer {RUNPOD_API_KEY}
```
*(Note: `handler.py` via RunPod platform receives this; our code sends it)*

---

## 3. `webhook_routes.ts` — Field Name Alignment

### Problem
`handler.py`'s `send_webhook_notification()` sends:
```json
{ "job_id": "...", "status": "completed|failed|processing|uploading", "audio_url": "...", "error": "...", "progress": 75.0, "message": "..." }
```

Phase 15's route currently checks for `status === 'running'` and `status === 'succeeded'` — these are RunPod's own job status values, not the custom values set by `handler.py`.

### Updated status mapping

| `handler.py` sends | Our route should do |
|:---|:---|
| `processing` | `updateJobProgress` → `synthesizing`, pct from `progress` field |
| `uploading` | `updateJobProgress` → `uploading_to_r2`, pct from `progress` field |
| `completed` | `completeJob` with `audio_url` as `masterMp3Url` |
| `failed` | `failJob` with `error` as message |

### Updated result field mapping
```typescript
// handler.py sends audio_url at TOP LEVEL (not inside result)
const { job_id, status, progress, audio_url, error, message } = payload;

if (status === 'completed') {
  completeJob(job_id, { masterMp3Url: audio_url || '' });
}
```

---

## 4. `env.ts` — WEBHOOK_BASE_URL Addition

```typescript
export interface AppEnv {
  // ... existing fields ...
  WEBHOOK_BASE_URL: string;  // NEW: public tunnel URL for RunPod callbacks
}

export const env: AppEnv = {
  // ... existing fields ...
  WEBHOOK_BASE_URL: process.env.WEBHOOK_BASE_URL || `http://localhost:${process.env.PORT || 3000}`,
};
```

When `NODE_ENV=development` and `WEBHOOK_BASE_URL` is still `localhost`, the adapter logs a warning since RunPod in the cloud cannot reach localhost.

---

## 5. `prompt_compiler.ts` — Metadata Extension

The `CompiledSynthesisPrompt` type's `metadata` needs two new fields so `runpod_adapter.ts` can populate `song_spec.genre`, `song_spec.mood`, and `song_spec.language`:

```typescript
export interface CompiledSynthesisPrompt {
  caption: string;
  lyrics: string;
  metadata: {
    bpm: number;
    key: string;
    timeSignature: string;
    durationSec: number;
    genre: string;      // NEW
    mood: string;       // NEW
    language: string;   // NEW
    title?: string;     // NEW (optional)
  };
}
```

---

## 6. Flutter `_ReadyTrackCard` — Stems Graceful Degradation

When `stemsUrl` is null (which it will always be with current GPU worker), the "Download Stems" button must be hidden rather than showing a broken action.

```dart
// In generation_pipeline_card.dart _ReadyTrackCard
if (stemsUrl != null)
  OutlinedButton.icon(
    onPressed: () => _downloadStems(stemsUrl!),
    icon: const Icon(Icons.layers_outlined),
    label: const Text('Download Stems'),
  ),
```

---

## 7. R2 CORS Policy for `vhunambi-audio` Bucket

```json
{
  "rules": [
    {
      "AllowedOrigins": [
        "https://vhunambi.com",
        "https://www.vhunambi.com",
        "http://localhost:3000",
        "http://localhost:*"
      ],
      "AllowedMethods": ["GET", "HEAD"],
      "AllowedHeaders": ["*"],
      "ExposeHeaders": ["Content-Length", "Content-Type", "Accept-Ranges"],
      "MaxAgeSeconds": 3600
    }
  ]
}
```
