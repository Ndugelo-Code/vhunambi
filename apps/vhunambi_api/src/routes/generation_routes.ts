import { Hono } from 'hono';
import { z } from 'zod';
import { nanoid } from 'nanoid';
import { env } from '../config/env.js';
import { compileSongSpec } from '../modules/synthesis/prompt_compiler.js';
import { dispatchSynthesisJob, checkRunPodJobStatus } from '../modules/synthesis/runpod_adapter.js';
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

export const generationRoutes = new Hono();

const SubmitGenerationSchema = z.object({
  trackTitle: z.string().default('Untitled Track'),
  genre: z.string().default('Amapiano'),
  language: z.string().default('ve'),
  lyrics: z.string().optional(),
  isInstrumental: z.boolean().default(false),
  tempoBpm: z.number().optional(),
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

    // 1. Record job
    createJob({
      generationId,
      trackTitle: input.trackTitle,
      genre: input.genre,
      language: input.language,
    });

    // 2. Compile prompt for AI synthesis model
    const compiledPrompt = compileSongSpec(input);

    // 3. Dispatch to RunPod Serverless GPU (or mock simulation worker)
    const dispatchResult = await dispatchSynthesisJob(
      generationId,
      compiledPrompt,
      input.userId ?? 'vhunambi_user',
    );

    // Record providerTaskId for fallback active polling
    setJobProviderTaskId(generationId, dispatchResult.jobId);

    return c.json(
      {
        success: true,
        generationId,
        status: 'queued',
        step: 'queued',
        progressPct: 10,
        providerTaskId: dispatchResult.jobId,
        pollUrl: `/v1/generations/${generationId}`,
        websocketUrl: `ws://localhost:${env.PORT}/ws/generation?id=${generationId}`,
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
  const job = getJob(id);

  if (!job) {
    return c.json({ error: 'NOT_FOUND', message: `Generation job ${id} not found` }, 404);
  }

  // Active sync from RunPod if job is still in flight and has a real providerTaskId
  if (
    (job.status === 'queued' || job.status === 'running') &&
    job.providerTaskId &&
    !job.providerTaskId.startsWith('mock_')
  ) {
    const liveStatus = await checkRunPodJobStatus(job.providerTaskId);
    if (liveStatus.status === 'COMPLETED' && liveStatus.audioUrl) {
      completeJob(id, {
        masterMp3Url: liveStatus.audioUrl,
        stemsZipUrl: liveStatus.stemsZipUrl,
      });
    } else if (liveStatus.status === 'FAILED') {
      failJob(id, liveStatus.error || 'RunPod GPU job failed');
    } else if (liveStatus.status === 'IN_PROGRESS') {
      updateJobProgress(id, {
        status: 'running',
        step: 'synthesizing',
        progressPct: liveStatus.progress ?? 60,
      });
    }
  }

  return c.json({
    generationId: job.generationId,
    trackTitle: job.trackTitle,
    genre: job.genre,
    language: job.language,
    status: job.status,
    step: job.step,
    progressPct: job.progressPct,
    masterMp3Url: job.masterMp3Url,
    stemsZipUrl: job.stemsZipUrl,
    stemUrls: job.stemUrls,
    manifestUrl: job.manifestUrl,
    durationSec: job.durationSec,
    errorMessage: job.errorMessage,
    updatedAt: job.updatedAt.toISOString(),
  });
});

/**
 * GET /v1/generations/:id/manifest
 * Returns the Master Media Object Manifest (v2.0) with status 200, or 404 if not found.
 */
generationRoutes.get('/:id/manifest', async (c) => {
  const id = c.req.param('id');
  const job = getJob(id);

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



