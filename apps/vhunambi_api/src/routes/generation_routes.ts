import { Hono } from 'hono';
import { z } from 'zod';
import { nanoid } from 'nanoid';
import { resolveRuntimeEnv } from '../config/env.js';
import {
  canonicalizeCreatorId,
  isNodeSqliteAvailable,
  vhunambiDb,
} from '../db/vhunambi_db.js';
import type { VhunambiWorkerEnv } from '../types/cloudflare_worker_types.js';
import { compileSongSpec } from '../modules/synthesis/prompt_compiler.js';
import { sanitizeLyricsForClient } from '../modules/lyrics/lyrics_sanitizer.js';
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
  notifyGenerationCompletedOnce,
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

const VoiceCastPayloadSchema = z.object({
  ensemble: z.enum(['solo', 'duet', 'choir']).default('solo'),
  gender: z.enum(['male', 'female', 'mixed']).default('male'),
  deliveryMode: z.enum(['auto', 'melodic', 'rap', 'spokenWord', 'choir']).default('auto'),
  energy: z.enum(['soft', 'mid', 'intense']).default('mid'),
  selectedVoiceIds: z.array(z.string()).max(6).default([]),
  clonedVoiceProfileId: z.string().optional(),
  clonedVoiceReferenceUrl: z.string().optional(),
  dialectInflection: z
    .object({
      vowelElongation: z.number().min(0).max(1).default(0.5),
      vibratoDepth: z.number().min(0).max(1).default(0.4),
      callAndResponseIntensity: z.number().min(0).max(1).default(0.6),
      adLibFrequency: z.number().min(0).max(1).default(0.5),
    })
    .optional(),
});

const SubmitGenerationSchema = z.object({
  contractVersion: z.literal('v6').default('v6'),
  trackTitle: z.string().default('Untitled Track'),
  isAutoTitle: z.boolean().default(true),
  prompt: z.string().max(4000).optional(),
  genre: z.string().default('Amapiano'),
  region: z.string().default('South Africa'),
  language: z.string().default('ve'),
  lyricsMode: z.enum(['ai_writes', 'my_own', 'from_photo', 'instrumental']).default('ai_writes'),
  lyrics: z.string().max(12000).optional(),
  sourcePhotoUrl: z.string().optional(),
  isInstrumental: z.boolean().default(false),
  tempoBpm: z.number().min(50).max(220).optional(),
  bpm: z.number().min(50).max(220).optional(),
  musicalKey: z.string().optional(),
  mood: z.string().optional(),
  era: z.string().optional(),
  songStructure: z.enum(['standard', 'extended', 'freestyle', 'loop']).default('standard'),
  durationSec: z.number().min(10).max(360).default(90),
  visibility: z.enum(['public', 'private']).default('public'),
  engineTier: z.enum(['fast_draft', 'studio_bake', 'sovereign_custom']).default('studio_bake'),
  batchCount: z.number().int().min(1).max(4).default(1),
  audioMode: z.enum(['none', 'remix', 'cover', 'reference', 'inspiration']).default('none'),
  sourceTrackId: z.string().optional(),
  voiceCast: VoiceCastPayloadSchema.optional(),
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
    const batchId = `batch_${Date.now()}_${nanoid(6)}`;
    const creatorId = canonicalizeCreatorId(
      c.get('authUser')?.creatorId ?? input.userId ?? 'creator_cern',
    );

    const effectiveCloneId =
      input.voiceCast?.clonedVoiceProfileId ?? input.clonedVoiceProfileId;
    const clonedProfile = effectiveCloneId
      ? getVoiceCloneProfile(effectiveCloneId)
      : undefined;
    const effectiveCloneRefUrl =
      input.voiceCast?.clonedVoiceReferenceUrl ?? clonedProfile?.r2ReferenceUrl;

    // 1. Compile prompt & multi-model routing spec (MiniMax 3.0 vs ACE-Step 1.5 XL)
    const compiledPrompt = compileSongSpec({
      ...input,
      tempoBpm: input.tempoBpm ?? input.bpm,
      selectedVoiceId: input.selectedVoiceId ?? input.voiceCast?.selectedVoiceIds?.[0],
      clonedVoiceProfileId: effectiveCloneId,
      ...(effectiveCloneRefUrl ? { clonedVoiceReferenceUrl: effectiveCloneRefUrl } : {}),
    });

    const sanitizedLyrics = compiledPrompt.lyrics
      ? sanitizeLyricsForClient(compiledPrompt.lyrics)
      : undefined;

    // 2. Record job with real owner & full V6 spec (persisted asynchronously in Edge Workers)
    const createdJob = createJob(
      {
        generationId,
        creatorId,
        batchId,
        batchCount: compiledPrompt.batchCount,
        engineTier: compiledPrompt.engineTier,
        resolvedEngine: compiledPrompt.resolvedEngine,
        audioMode: compiledPrompt.audioMode,
        referenceAudioUrl: input.referenceAudioUrl,
        visibility: input.visibility,
        attributionTag: compiledPrompt.attributionTag,
        voiceCast: (input.voiceCast ?? undefined) as Record<string, unknown> | undefined,
        generationSpec: {
          contractVersion: input.contractVersion,
          prompt: input.prompt ?? '',
          region: input.region,
          lyricsMode: input.lyricsMode,
          mood: input.mood ?? compiledPrompt.metadata.mood,
          era: input.era,
          songStructure: input.songStructure,
          takeSeeds: compiledPrompt.takeSeeds,
          sourcePhotoUrl: input.sourcePhotoUrl,
          sourceTrackId: input.sourceTrackId,
        },
        takes: [],
        trackTitle: input.trackTitle,
        genre: input.genre,
        language: input.language,
        durationSec: compiledPrompt.metadata.durationSec,
        ...(sanitizedLyrics ? { lyrics: sanitizedLyrics } : {}),
      },
      creatorId,
    );
    await vhunambiDb.upsertGenerationJobAsync(
      createdJob,
      creatorId,
      'audio_synthesis',
      c,
    );

    // 3. Dispatch to RunPod Serverless GPU (or Queue-Zero 4-stem R2 synthesis fallback)
    const dispatchResult = await dispatchSynthesisJob(
      generationId,
      compiledPrompt,
      creatorId,
      c,
    );

    // Record providerTaskId for fallback active polling
    setJobProviderTaskId(generationId, dispatchResult.jobId);
    await vhunambiDb.updateGenerationJobAsync(
      generationId,
      { providerTaskId: dispatchResult.jobId },
      c,
    );

    // Phase 67 + Phase 71 + Phase 80: Atomic monthly free song quota decrement & honest queued alert
    const quota = await vhunambiDb.consumeFreeMonthlySongQuotaAsync(creatorId, c);
    await vhunambiDb.upsertNotificationAsync(
      {
        id: `notif_gen_${generationId}`,
        userId: creatorId,
        title: `Studio Bake Queued: "${input.trackTitle}"`,
        message: `Baking ${input.genre} track (${compiledPrompt.batchCount} take${compiledPrompt.batchCount === 1 ? '' : 's'}). We'll notify you as soon as it finishes (${quota.freeMonthlySongsRemaining} / ${quota.freeMonthlySongsLimit} monthly free songs left).`,
        category: 'creatorActivity',
        subtype: 'studio_render',
        priority: 'normal',
        targetRoute: '/studio',
        targetEntityId: generationId,
        ctaLabel: 'View Bake Progress',
        metadata: {
          trackId: generationId,
          trackTitle: input.trackTitle,
          genre: input.genre,
          batchId,
          batchCount: compiledPrompt.batchCount,
          resolvedEngine: compiledPrompt.resolvedEngine,
          attributionTag: compiledPrompt.attributionTag,
          freeSongsRemaining: quota.freeMonthlySongsRemaining,
          freeSongsTotal: quota.freeMonthlySongsLimit,
        },
      },
      c,
    );
    if (
      quota.freeMonthlySongsRemaining === 3 ||
      quota.freeMonthlySongsRemaining === 1 ||
      quota.freeMonthlySongsRemaining === 0
    ) {
      await vhunambiDb.upsertNotificationAsync(
        {
          id: `notif_quota_low_${creatorId}_${quota.freeMonthlySongsRemaining}`,
          userId: creatorId,
          title:
            quota.freeMonthlySongsRemaining === 0
              ? 'Monthly Free Song Allowance Used (0 / 10 Left)'
              : `${quota.freeMonthlySongsRemaining} Free Monthly Song${quota.freeMonthlySongsRemaining === 1 ? '' : 's'} Remaining`,
          message:
            quota.freeMonthlySongsRemaining === 0
              ? 'You used all 10 monthly free songs. Top up Cultural Coins or upgrade to keep generating right away.'
              : `You have ${quota.freeMonthlySongsRemaining} free song generations remaining in this 30-day cycle.`,
          category: 'system',
          subtype: 'monthly_quota',
          priority: quota.freeMonthlySongsRemaining <= 1 ? 'high' : 'normal',
          targetRoute: '/wallet',
          ctaLabel: 'View Balance & Usage',
          metadata: {
            freeSongsTotal: quota.freeMonthlySongsLimit,
            freeSongsRemaining: quota.freeMonthlySongsRemaining,
            planTier: quota.planTier,
          },
        },
        c,
      );
    }

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
        batchId,
        batchCount: compiledPrompt.batchCount,
        engineTier: compiledPrompt.engineTier,
        resolvedEngine: compiledPrompt.resolvedEngine,
        attributionTag: compiledPrompt.attributionTag,
        audioMode: compiledPrompt.audioMode,
        durationSec: compiledPrompt.metadata.durationSec,
        visibility: compiledPrompt.visibility,
        takeSeeds: compiledPrompt.takeSeeds,
        takes: [],
        status: 'queued',
        step: 'queued',
        progressPct: 10,
        providerTaskId: dispatchResult.jobId,
        pollUrl: `/v1/generations/${generationId}`,
        websocketUrl,
        quota,
        ...(sanitizedLyrics ? { lyrics: sanitizedLyrics } : {}),
        sonicTags: compiledPrompt.sonicTags ?? [],
        loras: compiledPrompt.loras ?? [],
        vocalIdentity: {
          selectedVoiceId:
            input.selectedVoiceId ?? input.voiceCast?.selectedVoiceIds?.[0] ?? null,
          clonedVoiceProfileId: effectiveCloneId ?? null,
          ensemble: input.voiceCast?.ensemble ?? 'solo',
          selectedVoiceIds: input.voiceCast?.selectedVoiceIds ?? [],
          svcMode: effectiveCloneId
            ? 'zero_shot_clone'
            : (input.selectedVoiceId ?? input.voiceCast?.selectedVoiceIds?.[0])
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
    job = (await vhunambiDb.syncGenerationJobFromCloud(id, c)) ?? job;
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
      const completedTakes =
        job.takes && job.takes.length > 0
          ? job.takes
          : [
              {
                takeIndex: 0,
                seed: 1,
                engineUsed: job.resolvedEngine ?? 'minimax_music_3',
                audioUrl: liveStatus.audioUrl,
                durationSec: job.durationSec ?? 180,
                score: 1.0,
                attribution: job.attributionTag ?? null,
              },
            ];
      completeJob(id, {
        masterMp3Url: liveStatus.audioUrl,
        stemsZipUrl: liveStatus.stemsZipUrl,
        stemUrls: liveStatus.stemUrls,
        manifestUrl: liveStatus.manifestUrl,
        takes: completedTakes,
      });
      const updated = getJob(id) ?? job;
      await vhunambiDb.upsertGenerationJobAsync(
        updated,
        updated.creatorId ?? 'creator_cern',
        'audio_synthesis',
        c,
      );
      await notifyGenerationCompletedOnce(updated, c);
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
      const maxQueueGraceMs =
        job.engineTier === 'fast_draft' ? 240000 : 900000; // 15 min grace for long bakes
      if (ageMs > 45000) {
        const health = await checkRunPodEndpointHealth(c);
        const endpointDisabled = health.workersMax === 0;
        const staleUnscheduled =
          ageMs > maxQueueGraceMs &&
          health.workersRunning === 0 &&
          health.workersInitializing === 0 &&
          health.workersIdle === 0 &&
          health.workersReady === 0;
        if (health.workersKnown && (endpointDisabled || staleUnscheduled)) {
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
    creatorId: currentJob.creatorId ?? 'creator_cern',
    batchId: currentJob.batchId,
    batchCount: currentJob.batchCount ?? 1,
    engineTier: currentJob.engineTier ?? 'studio_bake',
    resolvedEngine: currentJob.resolvedEngine ?? 'minimax_music_3',
    attributionTag: currentJob.attributionTag ?? null,
    audioMode: currentJob.audioMode ?? 'none',
    visibility: currentJob.visibility ?? 'public',
    takes: currentJob.takes ?? [],
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
    job = (await vhunambiDb.syncGenerationJobFromCloud(id, c)) ?? job;
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
  let job = getJob(id);
  if (!isNodeSqliteAvailable() && !job) {
    job = (await vhunambiDb.syncGenerationJobFromCloud(id, c)) ?? undefined;
  }
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
    await vhunambiDb.updateGenerationJobAsync(
      id,
      {
        status: 'succeeded',
        step: 'ready',
        progressPct: 100,
        masterMp3Url: enrichedManifest.assets.masterMp3Url,
        stemsZipUrl: enrichedManifest.assets.stemsZipUrl,
        stemUrls: enrichedManifest.assets.stemUrls,
        durationSec: job.durationSec || 180,
        manifestUrl: `/v1/generations/${id}/manifest`,
        manifest: enrichedManifest,
      },
      c,
    );
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
