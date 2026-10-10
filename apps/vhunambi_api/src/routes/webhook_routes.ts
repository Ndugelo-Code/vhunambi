import { Hono } from 'hono';
import crypto from 'node:crypto';
import { env } from '../config/env.js';
import { updateJobProgress, completeJob, failJob } from '../modules/jobs/job_store.js';

export const webhookRoutes = new Hono();

/**
 * POST /v1/webhooks/ace-step
 *
 * Receives progress and completion callbacks from the RunPod GPU worker
 * (runpod-zr-studio/handler.py → send_webhook_notification()).
 *
 * ⚠️ FIELD CONTRACT — payload from handler.py:
 *   {
 *     job_id:    string,   // "vhunambi_{generationId}"
 *     status:    "processing" | "uploading" | "completed" | "failed",
 *     audio_url: string | null,   // TOP-LEVEL (NOT nested inside result)
 *     error:     string | null,
 *     progress:  number | null,   // 0–100
 *     message:   string | null,
 *   }
 *
 * HMAC verification: header "x-zrs-signature" = HMAC-SHA256(ZR_WEBHOOK_SECRET, compact-sorted-JSON)
 * Note: handler.py computes the signature on the compact sorted JSON, but sends the full payload
 * as regular JSON. We verify against the raw body as received.
 */
webhookRoutes.post('/ace-step', async (c) => {
  const signature = c.req.header('x-zrs-signature');
  const rawBody = await c.req.text();

  // HMAC-SHA256 verification — reject any callback that doesn't match our shared secret
  if (env.ZR_WEBHOOK_SECRET) {
    const expectedSignature = crypto
      .createHmac('sha256', env.ZR_WEBHOOK_SECRET)
      .update(rawBody)
      .digest('hex');

    if (signature !== expectedSignature) {
      console.warn('[Webhook] ⛔ HMAC signature mismatch — discarding payload');
      return c.json({ error: 'UNAUTHORIZED', message: 'Invalid webhook signature' }, 401);
    }
  }

  let payload: {
    job_id?: string;
    status?: string;
    audio_url?: string | null;
    error?: string | null;
    progress?: number | null;
    message?: string | null;
  };

  try {
    payload = JSON.parse(rawBody);
  } catch {
    return c.json({ error: 'PARSE_ERROR', message: 'Invalid JSON payload' }, 400);
  }

  const { job_id, status, progress, audio_url, error } = payload;

  if (!job_id) {
    return c.json({ error: 'BAD_REQUEST', message: 'Missing job_id' }, 400);
  }

  // Strip "vhunambi_" prefix added by runpod_adapter to recover the internal generationId
  const generationId = job_id.startsWith('vhunambi_') ? job_id.slice('vhunambi_'.length) : job_id;

  console.info(`[Webhook] job=${generationId} status=${status} progress=${progress ?? '-'}`);

  switch (status) {
    case 'processing':
      updateJobProgress(generationId, {
        status: 'running',
        step: 'synthesizing',
        progressPct: typeof progress === 'number' ? Math.round(progress * 0.6) : 30,
      });
      break;

    case 'uploading':
      updateJobProgress(generationId, {
        status: 'running',
        step: 'synthesizing',
        progressPct: typeof progress === 'number' ? 60 + Math.round(progress * 0.35) : 80,
      });
      break;

    case 'completed':
      // audio_url is TOP-LEVEL in handler.py payload (not nested inside result)
      completeJob(generationId, {
        masterMp3Url: audio_url || '',
        // handler.py v1 does not return stems_url — stemsZipUrl will be undefined
        stemsZipUrl: undefined,
      });
      console.info(`[Webhook] ✅ Job ${generationId} complete → ${audio_url}`);
      break;

    case 'failed':
      failJob(generationId, typeof error === 'string' ? error : 'GPU synthesis failed');
      console.error(`[Webhook] ❌ Job ${generationId} failed: ${error}`);
      break;

    default:
      console.warn(`[Webhook] Unknown status "${status}" for job ${generationId}`);
  }

  return c.json({ received: true });
});
