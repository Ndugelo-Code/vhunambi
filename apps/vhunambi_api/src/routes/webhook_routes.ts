import { Hono } from 'hono';
import crypto from 'node:crypto';
import { extractWorkerEnv, resolveRuntimeEnv } from '../config/env.js';
import { vhunambiDb } from '../db/vhunambi_db.js';
import {
  getJob,
  updateJobProgress,
  completeJob,
  failJob,
  notifyGenerationCompletedOnce,
} from '../modules/jobs/job_store.js';
import type {
  GenerationTakeRecord,
  PipelineStep,
  ResolvedAudioEngine,
} from '../modules/jobs/job_types.js';
import type { VhunambiWorkerEnv } from '../types/cloudflare_worker_types.js';
import { broadcastGenerationEventToDo } from '../modules/realtime/generation_session_do.js';

export const webhookRoutes = new Hono<{ Bindings: VhunambiWorkerEnv }>();

function mapWebhookStageToStep(rawStatus: string): PipelineStep {
  switch (rawStatus.trim().toLowerCase()) {
    case 'planning_lyrics':
      return 'planning_lyrics';
    case 'separating_stems':
      return 'separating_stems';
    case 'converting_vocals':
      return 'converting_vocals';
    case 'mastering':
      return 'mastering';
    case 'uploading':
      return 'uploading';
    case 'completed':
    case 'ready':
    case 'succeeded':
      return 'ready';
    case 'failed':
      return 'failed';
    default:
      return 'synthesizing';
  }
}

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
    stage?: string;
    audio_url?: string | null;
    master_wav_url?: string | null;
    stems_zip_url?: string | null;
    manifest_url?: string | null;
    stem_urls?: Record<string, string> | null;
    resolved_engine?: string | null;
    attribution_tag?: string | null;
    takes?: Array<Record<string, unknown>> | null;
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
    stage,
    progress,
    audio_url,
    manifest_url,
    stems_zip_url,
    stem_urls,
    error,
    message,
  } = payload;

  if (!job_id) {
    return c.json({ error: 'BAD_REQUEST', message: 'Missing job_id' }, 400);
  }

  // Strip "vhunambi_" prefix added by runpod_adapter to recover internal generationId
  const generationId = job_id.startsWith('vhunambi_')
    ? job_id.slice('vhunambi_'.length)
    : job_id;

  const stageKey = (stage ?? status ?? 'processing').toString();
  console.info(
    `[Webhook] job=${generationId} status=${status} stage=${stageKey} progress=${progress ?? '-'}`,
  );

  const workerEnv = extractWorkerEnv(c);
  const normalizedStatus = (status ?? '').trim().toLowerCase();

  if (
    normalizedStatus === 'processing' ||
    normalizedStatus === 'planning_lyrics' ||
    normalizedStatus === 'synthesizing' ||
    normalizedStatus === 'separating_stems' ||
    normalizedStatus === 'converting_vocals' ||
    normalizedStatus === 'mastering' ||
    normalizedStatus === 'uploading'
  ) {
    const step = mapWebhookStageToStep(
      stage ?? (normalizedStatus === 'processing' ? 'synthesizing' : normalizedStatus),
    );
    const defaultPct =
      step === 'planning_lyrics'
        ? 18
        : step === 'synthesizing'
          ? 42
          : step === 'separating_stems'
            ? 60
            : step === 'converting_vocals'
              ? 72
              : step === 'mastering'
                ? 84
                : 92;
    const progressPct =
      typeof progress === 'number' ? Math.max(10, Math.min(98, Math.round(progress))) : defaultPct;

    updateJobProgress(generationId, {
      status: 'running',
      step,
      progressPct,
    });
    await broadcastGenerationEventToDo(workerEnv, {
      generationId,
      status: 'running',
      step,
      progressPct,
      ...(message ? { message } : {}),
    });
    return c.json({ received: true });
  }

  switch (normalizedStatus) {
    case 'completed': {
      const existingJob =
        getJob(generationId) ??
        (await vhunambiDb.syncGenerationJobFromCloud(generationId, c)) ??
        undefined;
      const realCreatorId = existingJob?.creatorId ?? 'creator_cern';
      const masterMp3Url = audio_url || '';
      const stemsZipUrl = stems_zip_url || undefined;
      const stemUrls = stem_urls || undefined;
      const manifestUrl = manifest_url || undefined;
      const resolvedEngine = (payload.resolved_engine ??
        existingJob?.resolvedEngine ??
        'minimax_music_3') as ResolvedAudioEngine;
      const attributionTag =
        payload.attribution_tag !== undefined
          ? payload.attribution_tag
          : resolvedEngine === 'minimax_music_3'
            ? 'MiniMax-Music3'
            : (existingJob?.attributionTag ?? null);

      const takes: GenerationTakeRecord[] = Array.isArray(payload.takes) && payload.takes.length > 0
        ? payload.takes.map((raw, idx) => ({
          takeIndex: Number(raw.takeIndex ?? raw.take_index ?? idx),
          seed: Number(raw.seed ?? idx + 1),
          engineUsed: String(raw.engineUsed ?? raw.engine_used ?? resolvedEngine),
          audioUrl: String(raw.audioUrl ?? raw.audio_url ?? masterMp3Url),
          durationSec:
            raw.durationSec !== undefined
              ? Number(raw.durationSec)
              : existingJob?.durationSec,
          score: raw.score !== undefined ? Number(raw.score) : undefined,
          attribution:
            raw.attribution !== undefined
              ? (raw.attribution as string | null)
              : attributionTag,
        }))
        : masterMp3Url
          ? [
            {
              takeIndex: 0,
              seed: 1,
              engineUsed: resolvedEngine,
              audioUrl: masterMp3Url,
              durationSec: existingJob?.durationSec ?? 180,
              score: 1.0,
              attribution: attributionTag,
            },
          ]
          : [];

      completeJob(generationId, {
        masterMp3Url,
        stemsZipUrl,
        stemUrls,
        manifestUrl,
        takes,
        attributionTag,
        resolvedEngine,
      });

      const updatedJob = getJob(generationId) ?? {
        ...(existingJob ?? {}),
        generationId,
        creatorId: realCreatorId,
        trackTitle: existingJob?.trackTitle ?? 'AI Master',
        genre: existingJob?.genre ?? 'Amapiano',
        language: existingJob?.language ?? 've',
        durationSec: existingJob?.durationSec ?? 180,
        status: 'succeeded' as const,
        step: 'ready' as const,
        progressPct: 100,
        masterMp3Url,
        stemsZipUrl,
        stemUrls,
        manifestUrl,
        takes,
        attributionTag,
        resolvedEngine,
        createdAt: existingJob?.createdAt ?? new Date(),
        updatedAt: new Date(),
      };
      await vhunambiDb.upsertGenerationJobAsync(
        updatedJob,
        realCreatorId,
        'audio_synthesis',
        c,
      );
      await notifyGenerationCompletedOnce(updatedJob, c);
      await broadcastGenerationEventToDo(workerEnv, {
        generationId,
        status: 'succeeded',
        step: 'ready',
        progressPct: 100,
        masterMp3Url,
        stemsZipUrl,
        stemUrls,
        manifestUrl,
        resolvedEngine,
        attributionTag,
        takes,
      });
      console.info(
        `[Webhook] Job ${generationId} (owner=${realCreatorId}) complete -> ${audio_url} (takes: ${takes.length}, stems: ${stem_urls ? 'yes' : 'no'})`,
      );
      break;
    }

    case 'failed': {
      const existingJob =
        getJob(generationId) ??
        (await vhunambiDb.syncGenerationJobFromCloud(generationId, c)) ??
        undefined;
      const realCreatorId = existingJob?.creatorId ?? 'creator_cern';
      const errorMsg = typeof error === 'string' ? error : 'GPU synthesis failed';
      failJob(generationId, errorMsg);
      const failedJob = getJob(generationId);
      if (failedJob) {
        await vhunambiDb.upsertGenerationJobAsync(
          failedJob,
          realCreatorId,
          'audio_synthesis',
          c,
        );
      }
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
