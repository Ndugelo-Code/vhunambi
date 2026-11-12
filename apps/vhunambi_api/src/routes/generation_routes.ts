import { Hono } from 'hono';
import { z } from 'zod';
import { nanoid } from 'nanoid';
import { resolveRuntimeEnv } from '../config/env.js';
import { isNodeSqliteAvailable, vhunambiDb } from '../db/vhunambi_db.js';
import type { VhunambiWorkerEnv } from '../types/cloudflare_worker_types.js';
import { compileSongSpec } from '../modules/synthesis/prompt_compiler.js';
import {
  dispatchSynthesisJob,
  checkRunPodJobStatus,
  checkRunPodEndpointHealth,
} from '../modules/synthesis/runpod_adapter.js';
import { simulateSynthesisPipeline } from '../modules/synthesis/mock_worker.js';
import { getVoiceCloneProfile } from '../modules/voices/voice_catalog.js';
import { compileMasterMediaObjectManifest } from '../modules/dna/dna_compiler.js';
import { StemMasteringRecipeSchema } from '../modules/mastering/mastering_types.js';
import { MelodyPatternManifestSchema } from '../modules/melody/melody_types.js';
import {
  GENRE_MASTER_PRESETS,
  getMasteringPresetForGenre,
  enrichManifestWithMasteringRecipe,
} from '../modules/mastering/mastering_presets.js';
import {
  createJob,
  getJob,
  setJobProviderTaskId,
  updateJobProgress,
  completeJob,
  failJob,
} from '../modules/jobs/job_store.js';

export const generationRoutes = new Hono<{ Bindings: VhunambiWorkerEnv }>();

function resolveGenerationWsUrl(reqUrlRaw: string, forwardedProto: string | undefined, hostHeader: string | undefined, port: number, generationId: string): string {
  const reqUrl = new URL(reqUrlRaw);
  const isHttps = forwardedProto
    ? forwardedProto.toLowerCase() === 'https'
    : reqUrl.protocol === 'https:';
  const wsProto = isHttps ? 'wss:' : 'ws:';
  const host = hostHeader || reqUrl.host || `localhost:${port}`;
  return `${wsProto}//${host}/ws/generation?id=${generationId}`;
}

const SubmitGenerationSchema = z.object({
  trackTitle: z.string().default('Untitled Track'),
  prompt: z.string().optional(),
  genre: z.string().default('Amapiano'),
  language: z.string().default('ve'),
  lyrics: z.string().optional(),
  isInstrumental: z.boolean().default(false),
  tempoBpm: z.number().optional(),
  bpm: z.number().optional(),
  musicalKey: z.string().optional(),
  durationSec: z.number().default(180),
  /** Optional user identifier — forwarded to RunPod worker as user_id */
  userId: z.string().optional(),
  /** Phase 26: Optional Regional Voice Archetype ID */
  selectedVoiceId: z.string().optional(),
  /** Phase 26: Optional Zero-Shot Creator Voice Clone Profile ID */
  clonedVoiceProfileId: z.string().optional(),
  /** Phase 27: Optional 16-step Melody / Log-Drum Pattern Manifest */
  melodyPattern: MelodyPatternManifestSchema.optional(),
  /** Phase 27: Optional Melody Pattern Reference ID */
  melodyReferenceId: z.string().optional(),
  /** Phase 63: Optional pre-gen uploaded R2 reference audio URL */
  referenceAudioUrl: z.string().optional(),
  /** Phase 63: Optional 3D Mycelium stem authority locks */
  pregenStemLocks: z
    .record(
      z.string(),
      z.enum(['lockedPure44k', 'harmonicInpaint', 'elasticResynth']),
    )
    .optional(),
  /** Phase 63: Optional base64 payloads for pure 44.1 kHz locked stems */
  lockedStemsPayload: z.record(z.string(), z.string()).optional(),
});

generationRoutes.post('/', async (c) => {
  try {
    const body = await c.req.json();
    const parsed = SubmitGenerationSchema.safeParse(body);

    if (!parsed.success) {
      return c.json({ error: 'INVALID_REQUEST', details: parsed.error.flatten() }, 400);
    }

    const input = parsed.data;
    const generationId = `gen_${Date.now()}_${nanoid(8)}`;

    const clonedProfile = input.clonedVoiceProfileId
      ? getVoiceCloneProfile(input.clonedVoiceProfileId)
      : undefined;

    // 1. Compile prompt for AI synthesis model
    const compiledPrompt = compileSongSpec({
      ...input,
      tempoBpm: input.tempoBpm ?? input.bpm,
      ...(clonedProfile?.r2ReferenceUrl
        ? { clonedVoiceReferenceUrl: clonedProfile.r2ReferenceUrl }
        : {}),
    });

    // 2. Record job (including auto-composed lyrics if available)
    createJob({
      generationId,
      trackTitle: input.trackTitle,
      genre: input.genre,
      language: input.language,
      durationSec: input.durationSec,
      ...(compiledPrompt.lyrics ? { lyrics: compiledPrompt.lyrics } : {}),
    });

    // 3. Dispatch to RunPod Serverless GPU (or Queue-Zero 4-stem R2 synthesis fallback)
    const dispatchResult = await dispatchSynthesisJob(
      generationId,
      compiledPrompt,
      input.userId ?? 'vhunambi_user',
      c,
    );

    // Record providerTaskId for fallback active polling
    setJobProviderTaskId(generationId, dispatchResult.jobId);

    const runtimeEnv = resolveRuntimeEnv(c);
    const websocketUrl = resolveGenerationWsUrl(
      c.req.url,
      c.req.header('x-forwarded-proto'),
      c.req.header('host'),
      runtimeEnv.PORT,
      generationId,
    );

    return c.json(
      {
        success: true,
        generationId,
        status: 'queued',
        step: 'queued',
        progressPct: 10,
        providerTaskId: dispatchResult.jobId,
        pollUrl: `/v1/generations/${generationId}`,
        websocketUrl,
        ...(compiledPrompt.lyrics ? { lyrics: compiledPrompt.lyrics } : {}),
        sonicTags: compiledPrompt.sonicTags ?? [],
        loras: compiledPrompt.loras ?? [],
        vocalIdentity: {
          selectedVoiceId: input.selectedVoiceId ?? null,
          clonedVoiceProfileId: input.clonedVoiceProfileId ?? null,
          svcMode: input.clonedVoiceProfileId
            ? 'zero_shot_clone'
            : input.selectedVoiceId
              ? 'catalog_archetype'
              : 'default',
        },
        melodyConditioning: compiledPrompt.melodyConditioning ?? null,
      },
      201,
    );
  } catch (error) {
    console.error('[Generation Submit Error]', error);
    return c.json({ error: 'DISPATCH_ERROR', message: 'Failed to initiate audio synthesis' }, 500);
  }
});

/**
 * GET /v1/generations/mastering/presets
 * Returns the 6 regional studio mastering presets or a genre-matched default.
 */
generationRoutes.get('/mastering/presets', (c) => {
  const genre = c.req.query('genre');
  if (genre) {
    return c.json({
      recommended: getMasteringPresetForGenre(genre),
      presets: GENRE_MASTER_PRESETS,
    });
  }
  return c.json({ presets: GENRE_MASTER_PRESETS });
});

generationRoutes.get('/:id', async (c) => {
  const id = c.req.param('id');
  let job = getJob(id);
  if (
    !isNodeSqliteAvailable() &&
    (!job || job.status === 'queued' || job.status === 'running')
  ) {
    job = (await vhunambiDb.hydrateGenerationJobById(id, c)) ?? job;
  }

  if (!job) {
    return c.json({ error: 'NOT_FOUND', message: `Generation job ${id} not found` }, 404);
  }

  // Active sync from RunPod if job is still in flight and has a real providerTaskId
  if (
    (job.status === 'queued' || job.status === 'running') &&
    job.providerTaskId &&
    !job.providerTaskId.startsWith('mock_')
  ) {
    const liveStatus = await checkRunPodJobStatus(job.providerTaskId, c);
    if (liveStatus.status === 'COMPLETED' && liveStatus.audioUrl) {
      completeJob(id, {
        masterMp3Url: liveStatus.audioUrl,
        stemsZipUrl: liveStatus.stemsZipUrl,
        stemUrls: liveStatus.stemUrls,
        manifestUrl: liveStatus.manifestUrl,
      });
    } else if (liveStatus.status === 'FAILED') {
      failJob(id, liveStatus.error || 'RunPod GPU job failed');
    } else if (liveStatus.status === 'IN_PROGRESS') {
      updateJobProgress(id, {
        status: 'running',
        step: 'synthesizing',
        progressPct: liveStatus.progress ?? 60,
      });
    } else if (liveStatus.status === 'IN_QUEUE') {
      const ageMs = Date.now() - job.createdAt.getTime();
      if (ageMs > 8000) {
        const health = await checkRunPodEndpointHealth(c);
        if (health.workersKnown && health.activePlusIdle === 0) {
          setJobProviderTaskId(id, `mock_${id}`);
          updateJobProgress(id, {
            status: 'running',
            step: 'synthesizing',
            progressPct: 35,
          });
          void simulateSynthesisPipeline(id, c);
        }
      }
    }
  }

  const currentJob = getJob(id) ?? job;
  const resolvedCoverUrl =
    currentJob.coverUrl ??
    currentJob.manifest?.assets?.coverArt1x1Url ??
    currentJob.manifest?.assets?.coverArt9x16Url;

  return c.json({
    generationId: currentJob.generationId,
    trackTitle: currentJob.trackTitle,
    genre: currentJob.genre,
    language: currentJob.language,
    status: currentJob.status,
    step: currentJob.step,
    progressPct: currentJob.progressPct,
    masterMp3Url: currentJob.masterMp3Url,
    stemsZipUrl: currentJob.stemsZipUrl,
    stemUrls: currentJob.stemUrls,
    manifestUrl: currentJob.manifestUrl,
    ...(resolvedCoverUrl ? { coverUrl: resolvedCoverUrl } : {}),
    ...(currentJob.lyrics ? { lyrics: currentJob.lyrics } : {}),
    durationSec: currentJob.durationSec,
    errorMessage: currentJob.errorMessage,
    updatedAt: currentJob.updatedAt.toISOString(),
  });
});

/**
 * GET /v1/generations/:id/manifest
 * Returns the Master Media Object Manifest (v2.0) with status 200, or 404 if not found.
 */
generationRoutes.get('/:id/manifest', async (c) => {
  const id = c.req.param('id');
  let job = getJob(id);
  if (
    !isNodeSqliteAvailable() &&
    (!job || job.status === 'queued' || job.status === 'running')
  ) {
    job = (await vhunambiDb.hydrateGenerationJobById(id, c)) ?? job;
  }

  if (!job) {
    return c.json({ error: 'NOT_FOUND', message: `Generation job ${id} not found` }, 404);
  }

  if (job.manifest) {
    return c.json(job.manifest, 200);
  }

  const manifest = compileMasterMediaObjectManifest({
    id: job.generationId,
    title: job.trackTitle,
    genre: job.genre,
    language: job.language,
    durationSec: job.durationSec || 180,
    masterMp3Url: job.masterMp3Url,
    stemsZipUrl: job.stemsZipUrl,
    stemUrls: job.stemUrls as any,
    provenance: job.manifestUrl ? 'measured' : 'synthesized',
  });

  return c.json(manifest, 200);
});

/**
 * POST /v1/generations/:id/master
 * Phase 25 Tier B: Non-destructive stem-targeted studio mastering bake.
 * Validates StemMasteringRecipe, enriches MMO modulation curves, and returns mastered asset URLs.
 */
generationRoutes.post('/:id/master', async (c) => {
  const id = c.req.param('id');
  const job = getJob(id);
  const isSeededTrack = id.startsWith('trk_') || id.startsWith('seed_');

  if (!job && !isSeededTrack) {
    return c.json({ error: 'NOT_FOUND', message: `Generation job ${id} not found` }, 404);
  }

  let body: unknown;
  try {
    body = await c.req.json();
  } catch {
    return c.json({ error: 'INVALID_JSON', message: 'Request body must be valid JSON' }, 400);
  }

  const parsed = StemMasteringRecipeSchema.safeParse(body);
  if (!parsed.success) {
    return c.json(
      { error: 'INVALID_MASTERING_RECIPE', details: parsed.error.flatten() },
      400,
    );
  }

  const recipe = parsed.data;
  const baseManifest =
    job?.manifest ??
    compileMasterMediaObjectManifest({
      id: job?.generationId ?? id,
      title: job?.trackTitle ?? 'Amapiano Sunrise Master',
      genre: job?.genre ?? 'Amapiano',
      language: job?.language ?? 've',
      durationSec: job?.durationSec || 180,
      masterMp3Url: job?.masterMp3Url,
      stemsZipUrl: job?.stemsZipUrl,
      stemUrls: job?.stemUrls as any,
      provenance: 'measured',
    });

  const enrichedManifest = enrichManifestWithMasteringRecipe(baseManifest, recipe);

  if (job) {
    completeJob(id, {
      masterMp3Url: enrichedManifest.assets.masterMp3Url,
      stemsZipUrl: enrichedManifest.assets.stemsZipUrl,
      stemUrls: enrichedManifest.assets.stemUrls,
      durationSec: job.durationSec || 180,
      manifestUrl: `/v1/generations/${id}/manifest`,
      manifest: enrichedManifest,
    });
  }

  return c.json(
    {
      success: true,
      generationId: id,
      presetId: recipe.presetId,
      targetLufs: recipe.targetLufs,
      masteredMp3Url: enrichedManifest.assets.masterMp3Url,
      masteredWavUrl: enrichedManifest.assets.masterWavUrl,
      stemUrls: enrichedManifest.assets.stemUrls,
      manifest: enrichedManifest,
    },
    200,
  );
});



