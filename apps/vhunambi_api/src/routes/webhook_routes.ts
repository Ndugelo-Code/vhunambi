import { Hono, type Context } from 'hono';
import crypto from 'node:crypto';
import { extractWorkerEnv, resolveRuntimeEnv } from '../config/env.js';
import { vhunambiDb } from '../db/vhunambi_db.js';
import {
  getJob,
  updateJobProgress,
  completeJob,
  failJob,
  normalizeLoraMetrics,
  normalizeMasteringMetrics,
  normalizeSvcMetrics,
  notifyGenerationCompletedOnce,
  recordRepaintCompletionOnParent,
} from '../modules/jobs/job_store.js';
import type {
  GenerationTakeRecord,
  PipelineStep,
  ResolvedAudioEngine,
} from '../modules/jobs/job_types.js';
import type { VhunambiWorkerEnv } from '../types/cloudflare_worker_types.js';
import { broadcastGenerationEventToDo } from '../modules/realtime/generation_session_do.js';

export const webhookRoutes = new Hono<{ Bindings: VhunambiWorkerEnv }>();

async function syncWebhookProgressAsync(
  c: Context<{ Bindings: VhunambiWorkerEnv }>,
  generationId: string,
  updates: { status: 'running'; step: PipelineStep; progressPct: number },
): Promise<void> {
  const work = async () => {
    if (!getJob(generationId)) {
      await vhunambiDb.syncGenerationJobFromCloud(generationId, c);
    }
    await vhunambiDb.updateGenerationJobAsync(generationId, updates, c);
  };
  const promise = work();
  try {
    const execCtx = c.executionCtx;
    if (execCtx && typeof execCtx.waitUntil === 'function') {
      execCtx.waitUntil(promise);
      return;
    }
  } catch {
    // Hono throws accessing c.executionCtx in Node / simulated-edge tests
  }
  await promise;
}

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
    sample_rate_hz?: number | null;
    mastering_metrics?: Record<string, unknown> | null;
    svc_metrics?: Record<string, unknown> | null;
    lora_metrics?: Record<string, unknown> | null;
    repaint_metadata?: Record<string, unknown> | null;
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
    await syncWebhookProgressAsync(c, generationId, {
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

      const sampleRateHz =
        typeof payload.sample_rate_hz === 'number' &&
        Number.isFinite(payload.sample_rate_hz)
          ? payload.sample_rate_hz
          : existingJob?.sampleRateHz;
      const masteringMetrics =
        normalizeMasteringMetrics(payload.mastering_metrics) ??
        existingJob?.masteringMetrics;
      const svcMetrics =
        normalizeSvcMetrics(payload.svc_metrics) ?? existingJob?.svcMetrics;
      const loraMetrics =
        normalizeLoraMetrics(payload.lora_metrics) ?? existingJob?.loraMetrics;
      const repaintMetadata =
        (payload.repaint_metadata && typeof payload.repaint_metadata === 'object'
          ? payload.repaint_metadata
          : undefined) ?? existingJob?.repaintMetadata;

      completeJob(generationId, {
        masterMp3Url,
        stemsZipUrl,
        stemUrls,
        manifestUrl,
        takes,
        attributionTag,
        resolvedEngine,
        ...(sampleRateHz ? { sampleRateHz } : {}),
        ...(masteringMetrics ? { masteringMetrics } : {}),
        ...(svcMetrics ? { svcMetrics } : {}),
        ...(loraMetrics ? { loraMetrics } : {}),
        ...(repaintMetadata ? { repaintMetadata } : {}),
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
        ...(sampleRateHz ? { sampleRateHz } : {}),
        ...(masteringMetrics ? { masteringMetrics } : {}),
        ...(svcMetrics ? { svcMetrics } : {}),
        ...(loraMetrics ? { loraMetrics } : {}),
        ...(repaintMetadata ? { repaintMetadata } : {}),
        createdAt: existingJob?.createdAt ?? new Date(),
        updatedAt: new Date(),
      };
      await vhunambiDb.upsertGenerationJobAsync(
        updatedJob,
        realCreatorId,
        'audio_synthesis',
        c,
      );

      const parentId =
        updatedJob.parentGenerationId ??
        (repaintMetadata?.parent_job_id
          ? String(repaintMetadata.parent_job_id)
          : undefined);
      if (parentId) {
        const activeLoraIds =
          loraMetrics?.loadedLoras
            ?.filter((l) => l.loaded && l.loraId)
            .map((l) => l.loraId) ?? [];
        await recordRepaintCompletionOnParent(
          parentId,
          {
            repaintId: generationId,
            task: String(repaintMetadata?.task ?? 'repaint'),
            startSec: Number(repaintMetadata?.start_sec ?? 0),
            endSec: Number(repaintMetadata?.end_sec ?? 8),
            targetStem: String(repaintMetadata?.target_stem ?? 'full'),
            ...(repaintMetadata?.stem_locks &&
            typeof repaintMetadata.stem_locks === 'object'
              ? {
                  stemLocks: repaintMetadata.stem_locks as Record<string, string>,
                }
              : {}),
            ...(activeLoraIds.length > 0 ? { activeLoras: activeLoraIds } : {}),
            createdAtIso: new Date().toISOString(),
          },
          c,
        );
      }

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
        ...(sampleRateHz ? { sampleRateHz } : {}),
        ...(masteringMetrics ? { masteringMetrics } : {}),
        ...(svcMetrics ? { svcMetrics } : {}),
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

/**
 * POST /v1/webhooks/training
 *
 * Receives HMAC-SHA256 signed progress, dataset validation, and PEFT LoRA
 * completion callbacks from RunPod Cloud Training workers (Phase 85).
 */
webhookRoutes.post('/training', async (c) => {
  const signature = c.req.header('x-zrs-signature');
  const rawBody = await c.req.text();
  const runtimeEnv = resolveRuntimeEnv(c);

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
      return c.json(
        { error: 'UNAUTHORIZED', message: 'Invalid training webhook signature' },
        401,
      );
    }
  }

  let payload: Record<string, any>;
  try {
    payload = JSON.parse(rawBody) as Record<string, any>;
  } catch {
    return c.json({ error: 'PARSE_ERROR', message: 'Invalid JSON payload' }, 400);
  }

  const jobId = String(payload.job_id ?? payload.jobId ?? '').trim();
  const loraId = String(payload.lora_id ?? payload.loraId ?? '').trim();
  const statusRaw = String(payload.status ?? '').trim().toLowerCase();
  if (!jobId || !loraId) {
    return c.json(
      { error: 'BAD_REQUEST', message: 'job_id and lora_id are required' },
      400,
    );
  }

  const existingRegistry = vhunambiDb.getLoraRegistryEntry(loraId);
  const now = new Date().toISOString();

  if (statusRaw === 'dataset_ready') {
    const incomingTracks = Array.isArray(payload.tracks) ? payload.tracks : [];
    const mappedTracks = incomingTracks.map((t: Record<string, any>, idx: number) => ({
      id: String(t.id ?? `ldt_${loraId}_${idx}_${String(t.source_sha256 ?? idx).slice(0, 10)}`),
      loraId,
      sourceTrackId: t.source_track_id ? String(t.source_track_id) : null,
      sourceR2Key: String(t.source_r2_key ?? ''),
      sourceSha256: String(t.source_sha256 ?? `sha_${idx}`),
      curatedWavR2Key: t.curated_wav_r2_key ? String(t.curated_wav_r2_key) : null,
      curatedJsonR2Key: t.curated_json_r2_key ? String(t.curated_json_r2_key) : null,
      title: String(t.title ?? `Track ${idx + 1}`),
      vocalIsolated: Boolean(t.vocal_isolated),
      durationSec: t.duration_sec != null ? Number(t.duration_sec) : null,
      sampleRate: t.sample_rate != null ? Number(t.sample_rate) : null,
      bitDepth: t.bit_depth != null ? Number(t.bit_depth) : null,
      bpm: t.bpm != null ? Number(t.bpm) : null,
      musicalKey: t.musical_key ? String(t.musical_key) : null,
      language: String(t.language ?? 'en-ZA'),
      license: String(t.license ?? 'owned'),
      trainingWeight: Number(t.training_weight ?? 1.0),
      validationStatus: (t.valid === false ? 'invalid' : 'valid') as 'valid' | 'invalid',
      validationErrors: Array.isArray(t.errors) ? t.errors.map(String) : [],
      metadataJson: {},
      createdAt: now,
      updatedAt: now,
    }));
    await vhunambiDb.upsertLoraDatasetTracksAsync(mappedTracks, c);

    const validCount = Number(
      payload.valid_tracks ?? mappedTracks.filter((x) => x.validationStatus === 'valid').length,
    );
    const minTracks = existingRegistry?.minTracks ?? 8;
    await vhunambiDb.upsertLoraTrainingJobAsync(
      {
        id: jobId,
        loraId,
        jobType: 'dataset_prep',
        status: 'dataset_ready',
        progressPct: 100,
        metricsJson: { validTracks: validCount, totalTracks: mappedTracks.length },
        completedAt: now,
      },
      c,
    );
    if (existingRegistry?.status !== 'active') {
      await vhunambiDb.upsertLoraRegistryAsync(
        {
          loraId,
          status: validCount >= minTracks ? 'ready_to_train' : 'untrained',
          trainingTracks: validCount,
        },
        c,
      );
    }
    return c.json({ received: true, loraId, validTracks: validCount });
  }

  if (statusRaw === 'completed') {
    const sha256 = String(payload.artifact_sha256 ?? payload.sha256 ?? '').trim();
    const bytes = Number(payload.artifact_bytes ?? payload.bytes ?? 0);
    if (bytes <= 64 || !/^[a-f0-9]{64}$/i.test(sha256)) {
      return c.json(
        {
          error: 'INVALID_ARTIFACT_PROOF',
          message: 'Verified .safetensors completion requires artifact_bytes > 64 and 64-hex SHA-256.',
        },
        422,
      );
    }

    const r2Key = String(payload.artifact_r2_key ?? payload.r2_key ?? `loras/${loraId}.safetensors`);
    const finalLoss = payload.final_loss != null ? Number(payload.final_loss) : null;
    const trainingTracks = Number(payload.training_tracks ?? existingRegistry?.trainingTracks ?? 0);

    await vhunambiDb.upsertLoraTrainingJobAsync(
      {
        id: jobId,
        loraId,
        jobType: 'peft_train',
        status: 'completed',
        progressPct: 100,
        currentEpoch: Number(payload.total_epochs ?? payload.current_epoch ?? 0),
        totalEpochs: Number(payload.total_epochs ?? 0),
        currentLoss: finalLoss,
        bestLoss: payload.best_loss != null ? Number(payload.best_loss) : finalLoss,
        artifactR2Key: r2Key,
        artifactSha256: sha256.toLowerCase(),
        metricsJson: {
          artifactBytes: bytes,
          trainingTracks,
          finalLoss,
        },
        completedAt: now,
      },
      c,
    );

    await vhunambiDb.upsertLoraRegistryAsync(
      {
        loraId,
        r2Key,
        status: 'active',
        artifactSha256: sha256.toLowerCase(),
        artifactBytes: bytes,
        trainingTracks,
        finalLoss,
        trainedAt: now,
      },
      c,
    );
    return c.json({ received: true, loraId, status: 'active', sha256: sha256.toLowerCase() });
  }

  if (statusRaw === 'failed') {
    const errMsg = String(payload.error ?? 'RunPod training failed');
    await vhunambiDb.upsertLoraTrainingJobAsync(
      {
        id: jobId,
        loraId,
        status: 'failed',
        errorMessage: errMsg,
        completedAt: now,
      },
      c,
    );
    // Preserve active status if a previous verified .safetensors adapter is already live
    if (existingRegistry?.status !== 'active') {
      await vhunambiDb.upsertLoraRegistryAsync(
        { loraId, status: 'failed' },
        c,
      );
    }
    return c.json({ received: true, loraId, status: 'failed' });
  }

  // Intermediate progress (downloading / preparing / training / validating / uploading)
  const validInterim = new Set([
    'queued',
    'downloading',
    'preparing',
    'training',
    'validating',
    'uploading',
  ]);
  const mappedJobStatus = validInterim.has(statusRaw) ? statusRaw : 'training';
  await vhunambiDb.upsertLoraTrainingJobAsync(
    {
      id: jobId,
      loraId,
      status: mappedJobStatus as any,
      progressPct: Math.min(99, Math.max(0, Number(payload.progress_pct ?? payload.progress ?? 25))),
      currentEpoch: Number(payload.current_epoch ?? payload.epoch ?? 0),
      totalEpochs: Number(payload.total_epochs ?? 0),
      currentLoss: payload.current_loss != null ? Number(payload.current_loss) : (payload.loss != null ? Number(payload.loss) : null),
      bestLoss: payload.best_loss != null ? Number(payload.best_loss) : null,
    },
    c,
  );
  if (
    existingRegistry?.status !== 'active' &&
    (mappedJobStatus === 'training' || mappedJobStatus === 'validating' || mappedJobStatus === 'preparing')
  ) {
    await vhunambiDb.upsertLoraRegistryAsync(
      {
        loraId,
        status: mappedJobStatus as any,
      },
      c,
    );
  }
  return c.json({ received: true, loraId, status: mappedJobStatus });
});
