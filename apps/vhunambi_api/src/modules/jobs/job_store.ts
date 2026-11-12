import { GenerationJob, JobStatus, PipelineStep } from './job_types.js';
import { MasterMediaObjectManifest } from '../dna/dna_types.js';
import { vhunambiDb } from '../../db/vhunambi_db.js';

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
  const job: GenerationJob = {
    ...params,
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

  const resolvedCreator = creatorIdOverride ?? params.creatorId ?? 'creator_cern';
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
    durationSec: result.durationSec || 180,
  });
}

export function failJob(generationId: string, errorMessage: string): void {
  vhunambiDb.updateGenerationJob(generationId, {
    status: 'failed',
    step: 'failed',
    errorMessage,
  });
}
