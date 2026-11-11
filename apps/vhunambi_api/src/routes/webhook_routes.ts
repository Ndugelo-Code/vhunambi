import { Hono } from 'hono';
import crypto from 'node:crypto';
import { extractWorkerEnv, resolveRuntimeEnv } from '../config/env.js';
import {
  updateJobProgress,
  completeJob,
  failJob,
} from '../modules/jobs/job_store.js';
import type { VhunambiWorkerEnv } from '../types/cloudflare_worker_types.js';
import { broadcastGenerationEventToDo } from '../modules/realtime/generation_session_do.js';

export const webhookRoutes = new Hono<{ Bindings: VhunambiWorkerEnv }>();

/**
 * POST /v1/webhooks/ace-step
 *
 * Receives progress and completion callbacks from the RunPod GPU worker
 * (runpod-zr-studio/handler.py -> send_webhook()).
 */
webhookRoutes.post('/ace-step', async (c) => {
  const signature = c.req.header('x-zrs-signature');
  const rawBody = await c.req.text();
  const runtimeEnv = resolveRuntimeEnv(c);

  // Constant-time HMAC-SHA256 verification — reject any callback with mismatched signature
  if (runtimeEnv.ZR_WEBHOOK_SECRET) {
    const expectedSignature = crypto
      .createHmac('sha256', runtimeEnv.ZR_WEBHOOK_SECRET)
      .update(rawBody)
      .digest('hex');

    const expectedBuf = Buffer.from(expectedSignature.toLowerCase(), 'utf8');
    const providedBuf = Buffer.from((signature ?? '').trim().toLowerCase(), 'utf8');
    const matches =
      expectedBuf.length === providedBuf.length &&
      crypto.timingSafeEqual(expectedBuf, providedBuf);

    if (!matches) {
      console.warn('[Webhook] HMAC signature mismatch — discarding payload');
      return c.json(
        { error: 'UNAUTHORIZED', message: 'Invalid webhook signature' },
        401,
      );
    }
  }

  let payload: {
    job_id?: string;
    status?: string;
    audio_url?: string | null;
    master_wav_url?: string | null;
    stems_zip_url?: string | null;
    manifest_url?: string | null;
    stem_urls?: Record<string, string> | null;
    error?: string | null;
    progress?: number | null;
    message?: string | null;
  };

  try {
    payload = JSON.parse(rawBody);
  } catch {
    return c.json({ error: 'PARSE_ERROR', message: 'Invalid JSON payload' }, 400);
  }

  const {
    job_id,
    status,
    progress,
    audio_url,
    manifest_url,
    stems_zip_url,
    stem_urls,
    error,
  } = payload;

  if (!job_id) {
    return c.json({ error: 'BAD_REQUEST', message: 'Missing job_id' }, 400);
  }

  // Strip "vhunambi_" prefix added by runpod_adapter to recover internal generationId
  const generationId = job_id.startsWith('vhunambi_')
    ? job_id.slice('vhunambi_'.length)
    : job_id;

  console.info(
    `[Webhook] job=${generationId} status=${status} progress=${progress ?? '-'}`,
  );

  const workerEnv = extractWorkerEnv(c);

  switch (status) {
    case 'processing': {
      const progressPct =
        typeof progress === 'number' ? Math.round(progress * 0.6) : 30;
      updateJobProgress(generationId, {
        status: 'running',
        step: 'synthesizing',
        progressPct,
      });
      await broadcastGenerationEventToDo(workerEnv, {
        generationId,
        status: 'running',
        step: 'synthesizing',
        progressPct,
      });
      break;
    }

    case 'uploading': {
      const progressPct =
        typeof progress === 'number' ? 60 + Math.round(progress * 0.35) : 80;
      updateJobProgress(generationId, {
        status: 'running',
        step: 'synthesizing',
        progressPct,
      });
      await broadcastGenerationEventToDo(workerEnv, {
        generationId,
        status: 'running',
        step: 'synthesizing',
        progressPct,
      });
      break;
    }

    case 'completed': {
      const masterMp3Url = audio_url || '';
      const stemsZipUrl = stems_zip_url || undefined;
      const stemUrls = stem_urls || undefined;
      const manifestUrl = manifest_url || undefined;
      completeJob(generationId, {
        masterMp3Url,
        stemsZipUrl,
        stemUrls,
        manifestUrl,
      });
      await broadcastGenerationEventToDo(workerEnv, {
        generationId,
        status: 'succeeded',
        step: 'ready',
        progressPct: 100,
        masterMp3Url,
        stemsZipUrl,
        stemUrls,
        manifestUrl,
      });
      console.info(
        `[Webhook] Job ${generationId} complete -> ${audio_url} (stems: ${stem_urls ? 'yes' : 'no'}, manifest: ${manifest_url ?? 'none'})`,
      );
      break;
    }

    case 'failed': {
      const errorMsg = typeof error === 'string' ? error : 'GPU synthesis failed';
      failJob(generationId, errorMsg);
      await broadcastGenerationEventToDo(workerEnv, {
        generationId,
        status: 'failed',
        step: 'failed',
        progressPct: 0,
        error: errorMsg,
      });
      console.error(`[Webhook] Job ${generationId} failed: ${error}`);
      break;
    }

    default:
      console.warn(`[Webhook] Unknown status "${status}" for job ${generationId}`);
  }

  return c.json({ received: true });
});
