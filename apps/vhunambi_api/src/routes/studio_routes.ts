import { Hono } from 'hono';
import { z } from 'zod';
import { nanoid } from 'nanoid';
import {
  canonicalizeCreatorId,
  vhunambiDb,
  type LoraRegistryRecord,
} from '../db/vhunambi_db.js';
import { sovereignAuthMiddleware } from '../middleware/auth_middleware.js';
import { improveStudioPromptWithLLM } from '../modules/lyrics/llm_handler.js';
import {
  AFRICAN_LORA_PACKS,
  ALL_SOVEREIGN_LORA_PACKS,
  findLoraPackById,
  LANGUAGE_LORA_PACKS,
  resolveRecommendedLoraForGenre,
  type AfricanLoraPackDescriptor,
} from '../modules/synthesis/lora_catalog.js';
import {
  dispatchLoraDatasetPrepJob,
  dispatchLoraPeftTrainingJob,
} from '../modules/synthesis/runpod_adapter.js';
import {
  extractR2KeyFromAudioUrl,
  getTrainingHyperparamDefaults,
  selectSourceTracksForLoraPack,
  VhunambiLoraIdSchema,
  type VhunambiLoraId,
} from '../modules/synthesis/training_dataset_schema.js';
import type { VhunambiWorkerEnv } from '../types/cloudflare_worker_types.js';

export const studioRoutes = new Hono<{ Bindings: VhunambiWorkerEnv }>();

function enrichPackDescriptor(
  pack: AfricanLoraPackDescriptor,
  registry?: LoraRegistryRecord,
  readyTrackCount = 0,
  curatedTrackCount = 0,
) {
  return {
    ...pack,
    packType: pack.packType ?? 'genre',
    registryStatus: registry?.status ?? 'untrained',
    trainingTracks: registry?.trainingTracks ?? 0,
    readyTrackCount,
    curatedTrackCount,
    minTracks: registry?.minTracks ?? 8,
    recommendedTracks: registry?.recommendedTracks ?? 15,
    artifactSha256: registry?.artifactSha256 ?? null,
    artifactBytes: registry?.artifactBytes ?? 0,
    finalLoss: registry?.finalLoss ?? null,
    trainedAt: registry?.trainedAt ?? null,
    loraRank: registry?.loraRank ?? getTrainingHyperparamDefaults(pack.loraId as VhunambiLoraId).loraRank,
    loraAlpha: registry?.loraAlpha ?? getTrainingHyperparamDefaults(pack.loraId as VhunambiLoraId).loraAlpha,
  };
}

/**
 * GET /v1/studio/loras
 * Exposes the canonical 10-pack African Genre LoRA catalog (backward compatible with Phase 83)
 * plus additive languagePacks[] (bantu_vocals_v1) and live Supabase registry status.
 */
studioRoutes.get('/loras', async (c) => {
  const genre = c.req.query('genre') ?? 'Amapiano';
  const recommended = resolveRecommendedLoraForGenre(genre);
  const [registryRows, candidates] = await Promise.all([
    vhunambiDb.listLoraRegistryAsync(c),
    vhunambiDb.listAllExploreTrackCandidatesAsync(c),
  ]);
  const regMap = new Map(registryRows.map((r) => [r.loraId, r]));

  const packs = AFRICAN_LORA_PACKS.map((p) => {
    const reg = regMap.get(p.loraId);
    const matchedCount = selectSourceTracksForLoraPack(
      p.loraId as VhunambiLoraId,
      candidates,
    ).length;
    return enrichPackDescriptor(p, reg, matchedCount, reg?.trainingTracks ?? 0);
  });

  const languagePacks = LANGUAGE_LORA_PACKS.map((p) => {
    const reg = regMap.get(p.loraId);
    const matchedCount = selectSourceTracksForLoraPack(
      p.loraId as VhunambiLoraId,
      candidates,
    ).length;
    return enrichPackDescriptor(p, reg, matchedCount, reg?.trainingTracks ?? 0);
  });

  const recReg = regMap.get(recommended.loraId);
  return c.json({
    success: true,
    totalCount: AFRICAN_LORA_PACKS.length,
    genre,
    recommended: enrichPackDescriptor(
      recommended,
      recReg,
      selectSourceTracksForLoraPack(recommended.loraId as VhunambiLoraId, candidates).length,
      recReg?.trainingTracks ?? 0,
    ),
    packs,
    languagePacks,
  });
});

/**
 * GET /v1/studio/loras/factory
 * Returns all 11 packs (10 genre + bantu_vocals_v1), Zania/R2 source track readiness,
 * curated track counts, and recent RunPod dataset/training jobs.
 */
studioRoutes.get('/loras/factory', async (c) => {
  const [registryRows, candidates, recentJobs] = await Promise.all([
    vhunambiDb.listLoraRegistryAsync(c),
    vhunambiDb.listAllExploreTrackCandidatesAsync(c),
    vhunambiDb.listLoraTrainingJobsAsync(undefined, c),
  ]);
  const regMap = new Map(registryRows.map((r) => [r.loraId, r]));

  const curatedByPack = await Promise.all(
    ALL_SOVEREIGN_LORA_PACKS.map(async (p) => {
      const ds = await vhunambiDb.listLoraDatasetTracksAsync(p.loraId, c);
      return [
        p.loraId,
        ds.filter((t) => t.validationStatus === 'valid').length,
      ] as const;
    }),
  );
  const curatedMap = new Map(curatedByPack);

  const packs = ALL_SOVEREIGN_LORA_PACKS.map((p) => {
    const reg = regMap.get(p.loraId);
    const sourceCount = selectSourceTracksForLoraPack(
      p.loraId as VhunambiLoraId,
      candidates,
    ).length;
    const curatedCount = curatedMap.get(p.loraId) ?? 0;
    return {
      ...enrichPackDescriptor(p, reg, sourceCount, curatedCount),
      latestJob: recentJobs.find((j) => j.loraId === p.loraId) ?? null,
    };
  });

  return c.json({
    success: true,
    totalPacks: packs.length,
    readyPackCount: packs.filter((p) => p.readyTrackCount >= p.minTracks).length,
    activePackCount: packs.filter((p) => p.registryStatus === 'active').length,
    totalSourceTracks: candidates.length,
    packs,
    recentJobs,
  });
});

const DatasetPrepRequestSchema = z.object({
  loraId: VhunambiLoraIdSchema,
  sourceTrackIds: z.array(z.string().min(1)).max(200).optional(),
  extractVocals: z.boolean().optional(),
  forceReprep: z.boolean().default(false),
  allowPartialPrep: z.boolean().default(false),
});

studioRoutes.post('/loras/datasets/prep', sovereignAuthMiddleware, async (c) => {
  const authUser = c.get('authUser');
  const creatorId = canonicalizeCreatorId(authUser?.creatorId ?? 'creator_cern');
  const raw = await c.req.json().catch(() => null);
  const parsed = DatasetPrepRequestSchema.safeParse(raw);
  if (!parsed.success) {
    return c.json(
      { error: 'INVALID_REQUEST', details: parsed.error.flatten() },
      400,
    );
  }

  const { loraId, sourceTrackIds, extractVocals, forceReprep, allowPartialPrep } =
    parsed.data;
  const pack = findLoraPackById(loraId);
  if (!pack) {
    return c.json({ error: 'LORA_NOT_FOUND' }, 404);
  }

  const candidates = await vhunambiDb.listAllExploreTrackCandidatesAsync(c);
  const selected = sourceTrackIds?.length
    ? candidates.filter((t) => sourceTrackIds.includes(t.id))
    : selectSourceTracksForLoraPack(loraId, candidates);

  if (selected.length < 8 && !allowPartialPrep) {
    return c.json(
      {
        error: 'INSUFFICIENT_SOURCE_TRACKS',
        message: `${pack.label} requires at least 8 R2 tracks (currently ${selected.length}). Upload or ingest more tracks first.`,
        loraId,
        availableTracks: selected.length,
        minTracks: 8,
      },
      400,
    );
  }

  const hp = getTrainingHyperparamDefaults(loraId);
  const jobId = `job_prep_${loraId}_${nanoid(8)}`;
  const sourcePayload = selected
    .map((t) => {
      const r2Key = extractR2KeyFromAudioUrl(t.audioUrl);
      if (!r2Key) return null;
      return {
        id: t.id,
        title: t.title,
        r2Key,
        sha256: t.contentSha256,
        bpm: t.bpm,
        genre: t.genre,
        subGenre: t.subGenre,
        lyricsText: t.lyricsText,
        license: 'owned',
      };
    })
    .filter((x): x is NonNullable<typeof x> => Boolean(x));

  const dispatch = await dispatchLoraDatasetPrepJob(
    {
      jobId,
      loraId,
      genre: pack.genre,
      extractVocals: extractVocals ?? hp.extractVocals,
      forceReprep,
      sourceTracks: sourcePayload,
    },
    c,
  );

  await vhunambiDb.upsertLoraRegistryAsync(
    { loraId, status: 'preparing' },
    c,
  );
  const job = await vhunambiDb.upsertLoraTrainingJobAsync(
    {
      id: jobId,
      loraId,
      jobType: 'dataset_prep',
      runpodJobId: dispatch.runpodJobId,
      executionTarget: 'serverless',
      status: 'preparing',
      progressPct: 10,
      hyperparamsJson: {
        extractVocals: extractVocals ?? hp.extractVocals,
        sourceCount: sourcePayload.length,
      },
      triggeredBy: creatorId,
    },
    c,
  );

  return c.json(
    {
      success: true,
      job,
      sourceTrackCount: sourcePayload.length,
      isSimulated: dispatch.isSimulated,
    },
    202,
  );
});

const TrainLoraRequestSchema = z.object({
  loraId: VhunambiLoraIdSchema,
  epochs: z.number().int().min(1).max(60).optional(),
  learningRate: z.number().min(1e-6).max(5e-3).optional(),
  loraRank: z.union([z.literal(8), z.literal(16), z.literal(32), z.literal(64)]).optional(),
  loraAlpha: z.number().int().min(8).max(128).optional(),
  batchSize: z.number().int().min(1).max(8).optional(),
  executionTarget: z.enum(['serverless', 'pod']).default('serverless'),
  overrideCuratedCheck: z.boolean().default(false),
});

studioRoutes.post('/loras/train', sovereignAuthMiddleware, async (c) => {
  const authUser = c.get('authUser');
  const creatorId = canonicalizeCreatorId(authUser?.creatorId ?? 'creator_cern');
  const raw = await c.req.json().catch(() => null);
  const parsed = TrainLoraRequestSchema.safeParse(raw);
  if (!parsed.success) {
    return c.json(
      { error: 'INVALID_REQUEST', details: parsed.error.flatten() },
      400,
    );
  }

  const {
    loraId,
    epochs,
    learningRate,
    loraRank,
    loraAlpha,
    batchSize,
    executionTarget,
    overrideCuratedCheck,
  } = parsed.data;
  const pack = findLoraPackById(loraId);
  if (!pack) {
    return c.json({ error: 'LORA_NOT_FOUND' }, 404);
  }

  const curatedTracks = await vhunambiDb.listLoraDatasetTracksAsync(loraId, c);
  const validCount = curatedTracks.filter(
    (t) => t.validationStatus === 'valid',
  ).length;
  if (validCount < 8 && !overrideCuratedCheck) {
    return c.json(
      {
        error: 'DATASET_NOT_READY',
        message: `Run Cloud Dataset Prep first (${validCount}/8 validated curated WAVs ready).`,
        loraId,
        curatedValidTracks: validCount,
        minTracks: 8,
      },
      400,
    );
  }

  const hp = getTrainingHyperparamDefaults(loraId);
  const resolvedConfig = {
    loraRank: loraRank ?? hp.loraRank,
    loraAlpha: loraAlpha ?? hp.loraAlpha,
    epochs: epochs ?? hp.epochs,
    batchSize: batchSize ?? hp.batchSize,
    gradAccumSteps: hp.gradAccumSteps,
    learningRate: learningRate ?? hp.learningRate,
    warmupSteps: hp.warmupSteps,
    precision: 'bf16',
  };

  const jobId = `job_train_${loraId}_${nanoid(8)}`;
  const dispatch = await dispatchLoraPeftTrainingJob(
    {
      jobId,
      loraId,
      executionTarget,
      config: resolvedConfig,
    },
    c,
  );

  const existingReg = vhunambiDb.getLoraRegistryEntry(loraId);
  if (existingReg?.status !== 'active') {
    await vhunambiDb.upsertLoraRegistryAsync(
      {
        loraId,
        status: 'queued',
        loraRank: resolvedConfig.loraRank,
        loraAlpha: resolvedConfig.loraAlpha,
      },
      c,
    );
  }

  const job = await vhunambiDb.upsertLoraTrainingJobAsync(
    {
      id: jobId,
      loraId,
      jobType: 'peft_train',
      runpodJobId: dispatch.runpodJobId,
      executionTarget,
      status: 'queued',
      progressPct: 5,
      totalEpochs: resolvedConfig.epochs,
      hyperparamsJson: resolvedConfig,
      triggeredBy: creatorId,
    },
    c,
  );

  return c.json(
    {
      success: true,
      job,
      curatedTrackCount: validCount,
      isSimulated: dispatch.isSimulated,
      podLaunchCommand: dispatch.podLaunchCommand,
    },
    202,
  );
});

studioRoutes.get('/loras/jobs', async (c) => {
  const loraId = c.req.query('loraId') || undefined;
  const jobs = await vhunambiDb.listLoraTrainingJobsAsync(loraId, c);
  return c.json({ success: true, count: jobs.length, jobs });
});

studioRoutes.get('/loras/jobs/:jobId', async (c) => {
  const jobId = c.req.param('jobId');
  const job = await vhunambiDb.getLoraTrainingJobAsync(jobId, c);
  if (!job) {
    return c.json({ error: 'JOB_NOT_FOUND' }, 404);
  }
  return c.json({ success: true, job });
});

const ImprovePromptSchema = z.object({
  prompt: z.string().trim().min(2).max(2000),
  genre: z.string().default('Amapiano'),
  region: z.string().default('South Africa'),
  language: z.string().default('English'),
  mood: z.string().optional(),
  ensemble: z.enum(['solo', 'duet', 'choir']).optional(),
  isInstrumental: z.boolean().default(false),
});

studioRoutes.post('/improve-prompt', async (c) => {
  try {
    const body = await c.req.json();
    const parsed = ImprovePromptSchema.safeParse(body);
    if (!parsed.success) {
      return c.json(
        { error: 'INVALID_REQUEST', details: parsed.error.flatten() },
        400,
      );
    }

    const result = await improveStudioPromptWithLLM(parsed.data, c);
    return c.json({
      success: true,
      improvedPrompt: result.improvedPrompt,
      genre: parsed.data.genre,
      suggestedBpm: result.suggestedBpm,
      suggestedMood: result.suggestedMood,
      provider: result.provider,
    });
  } catch (error) {
    console.error('[Studio Improve Prompt Error]', error);
    return c.json(
      { error: 'PROMPT_IMPROVE_ERROR', message: 'Failed to improve prompt' },
      500,
    );
  }
});
