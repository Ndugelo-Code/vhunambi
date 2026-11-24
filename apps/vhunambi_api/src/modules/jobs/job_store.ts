import {
  GenerationJob,
  GenerationTakeRecord,
  JobStatus,
  PipelineStep,
  ResolvedAudioEngine,
} from './job_types.js';
import { MasterMediaObjectManifest } from '../dna/dna_types.js';
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
  await vhunambiDb.upsertNotificationAsync(
    {
      id: `notif_gen_${job.generationId}`,
      userId: creatorId,
      title: `Studio Track Ready: "${title}"`,
      message: `Mastered ${genre} track (${durationSec}s) is ready to play.`,
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
      },
    },
    cOrEnv,
  );
}
