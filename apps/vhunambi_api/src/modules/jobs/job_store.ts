import {
  GenerationJob,
  GenerationTakeRecord,
  JobStatus,
  PipelineStep,
  ResolvedAudioEngine,
} from './job_types.js';
import {
  LoraRuntimeMetrics,
  MasterMediaObjectManifest,
  MasteringMetrics,
  RepaintHistoryEntry,
  SvcMetrics,
} from '../dna/dna_types.js';
import { canonicalizeCreatorId, vhunambiDb } from '../../db/vhunambi_db.js';

export function createJob(
  params: {
    generationId: string;
    trackTitle: string;
    genre: string;
    language: string;
    providerTaskId?: string;
    creatorId?: string;
    status?: JobStatus;
    step?: PipelineStep;
    progressPct?: number;
  } & Partial<GenerationJob>,
  creatorIdOverride?: string,
): GenerationJob {
  const now = new Date();
  const resolvedCreator = canonicalizeCreatorId(
    creatorIdOverride ?? params.creatorId ?? 'creator_cern',
  );
  const job: GenerationJob = {
    ...params,
    creatorId: resolvedCreator,
    generationId: params.generationId,
    trackTitle: params.trackTitle,
    genre: params.genre,
    language: params.language,
    providerTaskId: params.providerTaskId,
    status: params.status ?? 'queued',
    step: params.step ?? 'queued',
    progressPct: params.progressPct ?? 10,
    createdAt: params.createdAt ?? now,
    updatedAt: params.updatedAt ?? now,
  };

  vhunambiDb.upsertGenerationJob(job, resolvedCreator);
  return job;
}

export function setJobProviderTaskId(generationId: string, providerTaskId: string): void {
  vhunambiDb.updateGenerationJob(generationId, { providerTaskId });
}

export function getJob(generationId: string): GenerationJob | undefined {
  return vhunambiDb.getGenerationJob(generationId) ?? undefined;
}

export function updateJobStatus(
  generationId: string,
  updates: Partial<GenerationJob>,
): GenerationJob | undefined {
  return vhunambiDb.updateGenerationJob(generationId, updates) ?? undefined;
}

export function listJobs(creatorId?: string): GenerationJob[] {
  return vhunambiDb.listGenerationJobs(creatorId);
}

/**
 * Jobs still in flight (`queued` or `running`) — surfaced by the health
 * check's `activeJobs` metric (Mission 4).
 */
export function countActiveJobs(): number {
  return vhunambiDb.countActiveGenerationJobs();
}

export function updateJobProgress(
  generationId: string,
  updates: {
    status: JobStatus;
    step: PipelineStep;
    progressPct: number;
  },
): void {
  vhunambiDb.updateGenerationJob(generationId, updates);
}

export function normalizeMasteringMetrics(
  raw: unknown,
): MasteringMetrics | undefined {
  if (!raw || typeof raw !== 'object') return undefined;
  const m = raw as Record<string, unknown>;
  const integrated = m.integratedLufs ?? m.integrated_lufs;
  const target = m.targetLufs ?? m.target_lufs;
  const truePeak = m.truePeakDbtp ?? m.true_peak_dbtp;
  const sampleRate = m.sampleRateHz ?? m.sample_rate_hz;
  return {
    ...(m.mode !== undefined ? { mode: String(m.mode) } : {}),
    ...(m.profileId !== undefined || m.profile_id !== undefined
      ? { profileId: String(m.profileId ?? m.profile_id) }
      : {}),
    ...(typeof integrated === 'number' && Number.isFinite(integrated)
      ? { integratedLufs: integrated }
      : {}),
    ...(typeof target === 'number' && Number.isFinite(target)
      ? { targetLufs: target }
      : {}),
    ...(typeof truePeak === 'number' && Number.isFinite(truePeak)
      ? { truePeakDbtp: truePeak }
      : {}),
    ...(typeof sampleRate === 'number' && Number.isFinite(sampleRate)
      ? { sampleRateHz: sampleRate }
      : {}),
    ...(m.engine !== undefined ? { engine: String(m.engine) } : {}),
  };
}

export function normalizeSvcMetrics(raw: unknown): SvcMetrics | undefined {
  if (!raw || typeof raw !== 'object') return undefined;
  const s = raw as Record<string, unknown>;
  const sim = s.similarityScore ?? s.similarity_score;
  const refDec = s.referenceDecoded ?? s.reference_decoded;
  const bantu = s.bantuTransientsPreserved ?? s.bantu_transients_preserved;
  const polish = s.polishApplied ?? s.polish_applied;
  return {
    ...(s.applied !== undefined ? { applied: Boolean(s.applied) } : {}),
    ...(s.engine !== undefined ? { engine: String(s.engine) } : {}),
    ...(refDec !== undefined ? { referenceDecoded: Boolean(refDec) } : {}),
    ...(typeof sim === 'number' && Number.isFinite(sim)
      ? { similarityScore: sim }
      : {}),
    ...(bantu !== undefined ? { bantuTransientsPreserved: Boolean(bantu) } : {}),
    ...(polish !== undefined ? { polishApplied: Boolean(polish) } : {}),
  };
}

export function normalizeLoraMetrics(raw: unknown): LoraRuntimeMetrics | undefined {
  if (!raw || typeof raw !== 'object') return undefined;
  const l = raw as Record<string, unknown>;
  const reqCount = l.requestedCount ?? l.requested_count;
  const loadCount = l.loadedCount ?? l.loaded_count;
  const rawList = Array.isArray(l.loadedLoras ?? l.loaded_loras)
    ? ((l.loadedLoras ?? l.loaded_loras) as Array<Record<string, unknown>>)
    : undefined;
  return {
    ...(typeof reqCount === 'number' && Number.isFinite(reqCount)
      ? { requestedCount: reqCount }
      : {}),
    ...(typeof loadCount === 'number' && Number.isFinite(loadCount)
      ? { loadedCount: loadCount }
      : {}),
    ...(rawList
      ? {
          loadedLoras: rawList.map((item) => ({
            loraId: String(item.loraId ?? item.lora_id ?? ''),
            r2Key: String(item.r2Key ?? item.r2_key ?? ''),
            weight: Number(item.weight ?? 0.85),
            ...(item.sha256 ? { sha256: String(item.sha256) } : {}),
            loaded: Boolean(item.loaded),
          })),
        }
      : {}),
  };
}

export async function recordRepaintCompletionOnParent(
  parentId: string,
  entry: RepaintHistoryEntry,
  cOrEnv?: unknown,
): Promise<void> {
  const parent =
    getJob(parentId) ??
    (await vhunambiDb.syncGenerationJobFromCloud(parentId, cOrEnv)) ??
    undefined;
  if (!parent) return;
  const existing = Array.isArray(parent.repaintHistory)
    ? parent.repaintHistory.filter((item) => item.repaintId !== entry.repaintId)
    : [];
  const nextHistory = [...existing, entry];
  const updatedManifest = parent.manifest
    ? {
        ...parent.manifest,
        repaintHistory: nextHistory,
      }
    : undefined;
  vhunambiDb.updateGenerationJob(parentId, {
    repaintHistory: nextHistory,
    ...(updatedManifest ? { manifest: updatedManifest } : {}),
  });
  const latest = getJob(parentId) ?? {
    ...parent,
    repaintHistory: nextHistory,
    ...(updatedManifest ? { manifest: updatedManifest } : {}),
  };
  await vhunambiDb.upsertGenerationJobAsync(
    latest,
    latest.creatorId ?? 'creator_cern',
    'audio_synthesis',
    cOrEnv,
  );
}

export function completeJob(
  generationId: string,
  result: {
    masterMp3Url: string;
    stemsZipUrl?: string;
    stemUrls?: Record<string, string>;
    durationSec?: number;
    manifestUrl?: string;
    manifest?: MasterMediaObjectManifest;
    coverUrl?: string;
    lyrics?: string;
    takes?: GenerationTakeRecord[];
    attributionTag?: string | null;
    resolvedEngine?: ResolvedAudioEngine;
    sampleRateHz?: number;
    masteringMetrics?: MasteringMetrics;
    svcMetrics?: SvcMetrics;
    loraMetrics?: LoraRuntimeMetrics;
    repaintMetadata?: Record<string, unknown>;
  },
): void {
  const existing = getJob(generationId);
  vhunambiDb.updateGenerationJob(generationId, {
    status: 'succeeded',
    step: 'ready',
    progressPct: 100,
    masterMp3Url: result.masterMp3Url,
    stemsZipUrl: result.stemsZipUrl,
    stemUrls: result.stemUrls,
    manifestUrl: result.manifestUrl,
    manifest: result.manifest,
    coverUrl:
      result.coverUrl ??
      existing?.coverUrl ??
      result.manifest?.assets?.coverArt1x1Url ??
      result.manifest?.assets?.coverArt9x16Url,
    lyrics: result.lyrics ?? existing?.lyrics,
    durationSec: result.durationSec ?? existing?.durationSec ?? 180,
    ...(result.takes ? { takes: result.takes } : {}),
    ...(result.attributionTag !== undefined
      ? { attributionTag: result.attributionTag }
      : {}),
    ...(result.resolvedEngine ? { resolvedEngine: result.resolvedEngine } : {}),
    ...(result.sampleRateHz ? { sampleRateHz: result.sampleRateHz } : {}),
    ...(result.masteringMetrics ? { masteringMetrics: result.masteringMetrics } : {}),
    ...(result.svcMetrics ? { svcMetrics: result.svcMetrics } : {}),
    ...(result.loraMetrics ? { loraMetrics: result.loraMetrics } : {}),
    ...(result.repaintMetadata ? { repaintMetadata: result.repaintMetadata } : {}),
  });
}

export function failJob(generationId: string, errorMessage: string): void {
  vhunambiDb.updateGenerationJob(generationId, {
    status: 'failed',
    step: 'failed',
    errorMessage,
  });
}

/**
 * Upgrades the idempotent `notif_gen_<id>` notification to unread Ready state
 * ONLY once synthesis actually finishes (`webhook_routes`, polling sync, or `mock_worker`).
 */
export async function notifyGenerationCompletedOnce(
  job: GenerationJob,
  cOrEnv?: unknown,
): Promise<void> {
  const creatorId = canonicalizeCreatorId(job.creatorId ?? 'creator_cern');
  const title = job.trackTitle || 'Studio Master';
  const genre = job.genre || 'Amapiano';
  const durationSec = job.durationSec ?? 180;
  const measuredLufs =
    job.masteringMetrics?.integratedLufs ??
    job.manifest?.masteringMetrics?.integratedLufs;
  const lufsSuffix =
    typeof measuredLufs === 'number' && Number.isFinite(measuredLufs)
      ? ` · ${measuredLufs.toFixed(1)} LUFS`
      : '';
  await vhunambiDb.upsertNotificationAsync(
    {
      id: `notif_gen_${job.generationId}`,
      userId: creatorId,
      title: `Studio Track Ready: "${title}"`,
      message: `Mastered ${genre} track (${durationSec}s${lufsSuffix}) is ready to play.`,
      isRead: false,
      category: 'creatorActivity',
      subtype: 'studio_render',
      priority: 'normal',
      targetRoute: `/track/${job.generationId}`,
      targetEntityId: job.generationId,
      ctaLabel: 'Open Track Cockpit',
      metadata: {
        trackId: job.generationId,
        trackTitle: title,
        genre,
        durationSec,
        resolvedEngine: job.resolvedEngine ?? 'minimax_music_3',
        attributionTag: job.attributionTag ?? null,
        batchCount: job.batchCount ?? 1,
        ...(typeof measuredLufs === 'number' && Number.isFinite(measuredLufs)
          ? { integratedLufs: measuredLufs }
          : {}),
        ...(job.masteringMetrics?.profileId
          ? { masteringProfile: job.masteringMetrics.profileId }
          : {}),
        ...(job.svcMetrics?.applied !== undefined
          ? { voiceCloneApplied: Boolean(job.svcMetrics.applied) }
          : {}),
      },
    },
    cOrEnv,
  );
}
