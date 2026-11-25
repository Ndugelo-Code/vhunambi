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
  dispatchRepaintJob,
  dispatchSynthesisJob,
  checkRunPodJobStatus,
  checkRunPodEndpointHealth,
} from '../modules/synthesis/runpod_adapter.js';
import { normalizeRequestedLoraSpecs } from '../modules/synthesis/lora_catalog.js';
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
import type {
  GenerationTakeRecord,
  PipelineStep,
  ResolvedAudioEngine,
} from '../modules/jobs/job_types.js';
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
  /** Phase 82: Broadcast mastering loudness mode & studio sample rate */
  masteringMode: z.enum(['streaming', 'club']).default('streaming'),
  sampleRateHz: z.union([z.literal(44100), z.literal(48000)]).default(44100),
  /** Phase 83: Explicit Sovereign African LoRA Pack overrides */
  loras: z
    .array(
      z.object({
        loraId: z.string().min(1),
        path: z.string().optional(),
        weight: z.number().min(0.1).max(1.2).default(0.85),
      }),
    )
    .max(3)
    .optional(),
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
    let clonedProfile = effectiveCloneId
      ? getVoiceCloneProfile(effectiveCloneId)
      : undefined;
    if (effectiveCloneId && !clonedProfile) {
      await vhunambiDb.syncVoicesFromCloud(false, c);
      clonedProfile = getVoiceCloneProfile(effectiveCloneId);
    }
    const effectiveCloneRefUrl =
      input.voiceCast?.clonedVoiceReferenceUrl ?? clonedProfile?.r2ReferenceUrl;

    const resolvedExplicitLoras = input.loras?.length
      ? normalizeRequestedLoraSpecs(input.genre, input.loras)
      : undefined;

    // 1. Compile prompt & multi-model routing spec (MiniMax 3.0 vs ACE-Step 1.5 XL)
    const compiledPrompt = compileSongSpec({
      ...input,
      tempoBpm: input.tempoBpm ?? input.bpm,
      selectedVoiceId: input.selectedVoiceId ?? input.voiceCast?.selectedVoiceIds?.[0],
      clonedVoiceProfileId: effectiveCloneId,
      masteringMode: input.masteringMode,
      sampleRateHz: input.sampleRateHz,
      ...(resolvedExplicitLoras ? { loras: resolvedExplicitLoras } : {}),
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
        masteringMode: compiledPrompt.masteringMode,
        sampleRateHz: compiledPrompt.sampleRateHz,
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
          masteringMode: compiledPrompt.masteringMode,
          sampleRateHz: compiledPrompt.sampleRateHz,
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
        masteringMode: compiledPrompt.masteringMode,
        sampleRateHz: compiledPrompt.sampleRateHz,
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
      const resolvedEng = (liveStatus.resolvedEngine ??
        job.resolvedEngine ??
        'minimax_music_3') as ResolvedAudioEngine;
      const resolvedAttr =
        liveStatus.attributionTag !== undefined
          ? liveStatus.attributionTag
          : resolvedEng === 'minimax_music_3'
            ? 'MiniMax-Music3'
            : (job.attributionTag ?? null);
      const completedTakes: GenerationTakeRecord[] =
        Array.isArray(liveStatus.takes) && liveStatus.takes.length > 0
          ? liveStatus.takes.map((raw, idx) => ({
            takeIndex: Number(raw.takeIndex ?? raw.take_index ?? idx),
            seed: Number(raw.seed ?? idx + 1),
            engineUsed: String(
              raw.engineUsed ?? raw.engine_used ?? resolvedEng,
            ),
            audioUrl: String(
              raw.audioUrl ?? raw.audio_url ?? liveStatus.audioUrl,
            ),
            durationSec:
              raw.durationSec !== undefined
                ? Number(raw.durationSec)
                : raw.duration_sec !== undefined
                  ? Number(raw.duration_sec)
                  : job!.durationSec,
            score: raw.score !== undefined ? Number(raw.score) : undefined,
            attribution:
              raw.attribution !== undefined
                ? (raw.attribution as string | null)
                : resolvedAttr,
          }))
          : job.takes && job.takes.length > 0
            ? job.takes
            : [
              {
                takeIndex: 0,
                seed: 1,
                engineUsed: resolvedEng,
                audioUrl: liveStatus.audioUrl,
                durationSec: job.durationSec ?? 180,
                score: 1.0,
                attribution: resolvedAttr,
              },
            ];
      completeJob(id, {
        masterMp3Url: liveStatus.audioUrl,
        stemsZipUrl: liveStatus.stemsZipUrl,
        stemUrls: liveStatus.stemUrls,
        manifestUrl: liveStatus.manifestUrl,
        takes: completedTakes,
        resolvedEngine: resolvedEng,
        attributionTag: resolvedAttr,
        ...(liveStatus.sampleRateHz ? { sampleRateHz: liveStatus.sampleRateHz } : {}),
        ...(liveStatus.masteringMetrics
          ? { masteringMetrics: liveStatus.masteringMetrics }
          : {}),
        ...(liveStatus.svcMetrics ? { svcMetrics: liveStatus.svcMetrics } : {}),
        ...(liveStatus.loraMetrics ? { loraMetrics: liveStatus.loraMetrics } : {}),
        ...(liveStatus.repaintMetadata
          ? { repaintMetadata: liveStatus.repaintMetadata }
          : {}),
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
      const stageRaw = String(liveStatus.stage ?? 'synthesizing')
        .trim()
        .toLowerCase();
      const validStep: PipelineStep =
        stageRaw === 'planning_lyrics' ||
          stageRaw === 'separating_stems' ||
          stageRaw === 'converting_vocals' ||
          stageRaw === 'mastering' ||
          stageRaw === 'uploading'
          ? (stageRaw as PipelineStep)
          : 'synthesizing';
      updateJobProgress(id, {
        status: 'running',
        step: validStep,
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
    ...(currentJob.sampleRateHz ? { sampleRateHz: currentJob.sampleRateHz } : {}),
    ...(currentJob.masteringMode ? { masteringMode: currentJob.masteringMode } : {}),
    ...(currentJob.masteringMetrics
      ? { masteringMetrics: currentJob.masteringMetrics }
      : {}),
    ...(currentJob.svcMetrics ? { svcMetrics: currentJob.svcMetrics } : {}),
    ...(currentJob.loraMetrics ? { loraMetrics: currentJob.loraMetrics } : {}),
    ...(currentJob.repaintHistory ? { repaintHistory: currentJob.repaintHistory } : {}),
    ...(currentJob.parentGenerationId
      ? { parentGenerationId: currentJob.parentGenerationId }
      : {}),
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
    return c.json(
      {
        ...job.manifest,
        ...(job.manifest.sampleRateHz || job.sampleRateHz
          ? { sampleRateHz: job.manifest.sampleRateHz ?? job.sampleRateHz }
          : {}),
        ...(job.manifest.resolvedEngine || job.resolvedEngine
          ? { resolvedEngine: job.manifest.resolvedEngine ?? job.resolvedEngine }
          : {}),
        ...(job.manifest.attributionTag !== undefined || job.attributionTag !== undefined
          ? { attributionTag: job.manifest.attributionTag ?? job.attributionTag ?? null }
          : {}),
        ...(job.manifest.masteringMetrics || job.masteringMetrics
          ? { masteringMetrics: job.manifest.masteringMetrics ?? job.masteringMetrics }
          : {}),
        ...(job.manifest.svcMetrics || job.svcMetrics
          ? { svcMetrics: job.manifest.svcMetrics ?? job.svcMetrics }
          : {}),
        ...(job.manifest.loraMetrics || job.loraMetrics
          ? { loraMetrics: job.manifest.loraMetrics ?? job.loraMetrics }
          : {}),
        ...(job.manifest.repaintHistory || job.repaintHistory
          ? { repaintHistory: job.manifest.repaintHistory ?? job.repaintHistory }
          : {}),
      },
      200,
    );
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
    ...(job.sampleRateHz ? { sampleRateHz: job.sampleRateHz } : {}),
    ...(job.resolvedEngine ? { resolvedEngine: job.resolvedEngine } : {}),
    ...(job.attributionTag !== undefined ? { attributionTag: job.attributionTag } : {}),
    ...(job.masteringMetrics ? { masteringMetrics: job.masteringMetrics } : {}),
    ...(job.svcMetrics ? { svcMetrics: job.svcMetrics } : {}),
    ...(job.loraMetrics ? { loraMetrics: job.loraMetrics } : {}),
    ...(job.repaintHistory ? { repaintHistory: job.repaintHistory } : {}),
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
        ...(enrichedManifest.masteringMetrics
          ? { masteringMetrics: enrichedManifest.masteringMetrics }
          : {}),
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

const STEM_LOCK_ALIAS_MAP: Record<string, 'vocals' | 'drums' | 'bass' | 'melodic'> = {
  vocals: 'vocals',
  node_vocals: 'vocals',
  node_vocal_persona: 'vocals',
  node_branch_vocal: 'vocals',
  drums: 'drums',
  node_drums: 'drums',
  node_beat_tempo: 'drums',
  node_branch_beat: 'drums',
  node_sketchpad_groove: 'drums',
  bass: 'bass',
  node_bass: 'bass',
  melodic: 'melodic',
  instrumental: 'melodic',
  other: 'melodic',
  node_melodic: 'melodic',
  node_harmony_chords: 'melodic',
  node_branch_instruments: 'melodic',
  node_spatial_atmosphere: 'melodic',
};

function normalizeStemLockPayload(
  raw?: Record<string, string>,
): Record<string, 'lockedPure44k' | 'harmonicInpaint' | 'elasticResynth'> {
  const out: Record<string, 'lockedPure44k' | 'harmonicInpaint' | 'elasticResynth'> = {};
  if (!raw) return out;
  for (const [k, v] of Object.entries(raw)) {
    const role = STEM_LOCK_ALIAS_MAP[k.trim().toLowerCase()];
    if (
      role &&
      (v === 'lockedPure44k' || v === 'harmonicInpaint' || v === 'elasticResynth')
    ) {
      if (k.trim().toLowerCase() === role || !out[role]) {
        out[role] = v;
      }
    }
  }
  return out;
}

const RepaintGenerationSchema = z
  .object({
    startSec: z.number().min(0),
    endSec: z.number().min(2),
    task: z.enum(['repaint', 'lego', 'complete']).default('repaint'),
    targetStem: z
      .enum(['full', 'vocals', 'drums', 'bass', 'melodic'])
      .default('full'),
    stemLocks: z
      .record(
        z.string(),
        z.enum(['lockedPure44k', 'harmonicInpaint', 'elasticResynth']),
      )
      .optional(),
    editPrompt: z.string().max(2000).optional(),
    editLyrics: z.string().max(8000).optional(),
    loras: z
      .array(
        z.object({
          loraId: z.string().min(1),
          path: z.string().optional(),
          weight: z.number().min(0.1).max(1.2).default(0.85),
        }),
      )
      .max(3)
      .optional(),
    masteringMode: z.enum(['streaming', 'club']).default('streaming'),
    sampleRateHz: z.union([z.literal(44100), z.literal(48000)]).default(44100),
  })
  .refine((d) => d.endSec - d.startSec >= 2, {
    message: 'Repaint window (endSec - startSec) must be at least 2 seconds',
  });

/**
 * POST /v1/generations/:id/repaint
 * Phase 83 (`EP-P83-ACE-STEP-SECTION-REPAINT`): Dispatches section repaint / stem lego / extend
 * on ACE-Step 1.5 XL-Base and links child revision back to parent generation.
 */
generationRoutes.post('/:id/repaint', async (c) => {
  const parentId = c.req.param('id');
  let parentJob = getJob(parentId);
  if (!isNodeSqliteAvailable() && !parentJob) {
    parentJob = (await vhunambiDb.syncGenerationJobFromCloud(parentId, c)) ?? undefined;
  }
  const isSeededTrack = parentId.startsWith('trk_') || parentId.startsWith('seed_') || parentId.startsWith('seed-');
  if (!parentJob && !isSeededTrack) {
    return c.json(
      { error: 'NOT_FOUND', message: `Generation job ${parentId} not found` },
      404,
    );
  }

  let body: unknown;
  try {
    body = await c.req.json();
  } catch {
    return c.json(
      { error: 'INVALID_JSON', message: 'Request body must be valid JSON' },
      400,
    );
  }

  const parsed = RepaintGenerationSchema.safeParse(body);
  if (!parsed.success) {
    return c.json(
      { error: 'INVALID_REPAINT_REQUEST', details: parsed.error.flatten() },
      400,
    );
  }

  const input = parsed.data;
  const creatorId = canonicalizeCreatorId(
    c.get('authUser')?.creatorId ?? parentJob?.creatorId ?? 'creator_cern',
  );
  const genre = parentJob?.genre ?? 'Amapiano';
  const language = parentJob?.language ?? 've';
  const title = parentJob?.trackTitle ?? 'Studio Master';
  const durationSec = parentJob?.durationSec ?? 180;
  const bpm = Number((parentJob?.generationSpec?.bpm as number | undefined) ?? 112);
  const musicalKey = String(parentJob?.generationSpec?.musicalKey ?? 'F#m');
  const normalizedLocks = normalizeStemLockPayload(input.stemLocks);
  const resolvedLoras = normalizeRequestedLoraSpecs(genre, input.loras);

  const repaintJobId = `gen_repaint_${Date.now()}_${nanoid(6)}`;
  const runtimeEnv = resolveRuntimeEnv(c);
  const forwardedProto = c.req.header('x-forwarded-proto');
  const hostHeader = c.req.header('x-forwarded-host') || c.req.header('host');
  const websocketUrl = resolveGenerationWsUrl(
    c.req.url,
    forwardedProto,
    hostHeader,
    runtimeEnv.PORT,
    repaintJobId,
  );

  const created = createJob(
    {
      generationId: repaintJobId,
      parentGenerationId: parentId,
      creatorId,
      engineTier: 'sovereign_custom',
      resolvedEngine: 'ace_step_xl_base',
      attributionTag: null,
      audioMode: 'remix',
      masteringMode: input.masteringMode,
      sampleRateHz: input.sampleRateHz,
      trackTitle: `${title} (Repaint)`,
      genre,
      language,
      durationSec,
      ...(input.editLyrics ? { lyrics: input.editLyrics } : {}),
      generationSpec: {
        parentGenerationId: parentId,
        repaintTask: input.task,
        startSec: input.startSec,
        endSec: input.endSec,
        targetStem: input.targetStem,
        stemLocks: normalizedLocks,
        loras: resolvedLoras,
        masteringMode: input.masteringMode,
        sampleRateHz: input.sampleRateHz,
      },
      repaintMetadata: {
        parent_job_id: parentId,
        task: input.task,
        start_sec: input.startSec,
        end_sec: input.endSec,
        target_stem: input.targetStem,
        stem_locks: normalizedLocks,
      },
    },
    creatorId,
  );
  await vhunambiDb.upsertGenerationJobAsync(created, creatorId, 'audio_synthesis', c);

  const dispatchResult = await dispatchRepaintJob(
    repaintJobId,
    {
      parentGenerationId: parentId,
      sourceAudioUrl:
        parentJob?.masterMp3Url ??
        parentJob?.manifest?.assets?.masterMp3Url ??
        `/mock-storage/${parentId}.mp3`,
      sourceStemUrls: parentJob?.stemUrls ?? parentJob?.manifest?.assets?.stemUrls,
      task: input.task,
      startSec: input.startSec,
      endSec: input.endSec,
      targetStem: input.targetStem,
      stemLocks: normalizedLocks,
      genre,
      bpm,
      musicalKey,
      language,
      durationSec,
      title,
      editPrompt: input.editPrompt,
      editLyrics: input.editLyrics ?? parentJob?.lyrics,
      loras: resolvedLoras,
      masteringMode: input.masteringMode,
      sampleRateHz: input.sampleRateHz,
    },
    creatorId,
    c,
  );

  setJobProviderTaskId(repaintJobId, dispatchResult.jobId);
  await vhunambiDb.updateGenerationJobAsync(
    repaintJobId,
    { providerTaskId: dispatchResult.jobId },
    c,
  );

  return c.json(
    {
      success: true,
      generationId: repaintJobId,
      parentGenerationId: parentId,
      resolvedEngine: 'ace_step_xl_base',
      attributionTag: null,
      task: input.task,
      repaintRange: { startSec: input.startSec, endSec: input.endSec },
      targetStem: input.targetStem,
      stemLocks: normalizedLocks,
      activeLoras: resolvedLoras,
      status: 'queued',
      pollUrl: `/v1/generations/${repaintJobId}`,
      websocketUrl,
    },
    201,
  );
});
