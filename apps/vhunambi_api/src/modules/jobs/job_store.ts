import { GenerationJob, JobStatus, PipelineStep } from './job_types.js';

const jobs = new Map<string, GenerationJob>();

export function createJob(params: {
  generationId: string;
  trackTitle: string;
  genre: string;
  language: string;
}): GenerationJob {
  const job: GenerationJob = {
    generationId: params.generationId,
    trackTitle: params.trackTitle,
    genre: params.genre,
    language: params.language,
    status: 'queued',
    step: 'queued',
    progressPct: 10,
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  jobs.set(params.generationId, job);
  return job;
}

export function getJob(generationId: string): GenerationJob | undefined {
  return jobs.get(generationId);
}

/**
 * Jobs still in flight (`queued` or `running`) — surfaced by the health
 * check's `activeJobs` metric (Mission 4).
 */
export function countActiveJobs(): number {
  let active = 0;
  for (const job of jobs.values()) {
    if (job.status === 'queued' || job.status === 'running') active++;
  }
  return active;
}

export function updateJobProgress(
  generationId: string,
  updates: {
    status: JobStatus;
    step: PipelineStep;
    progressPct: number;
  },
): void {
  const job = jobs.get(generationId);
  if (!job) return;

  job.status = updates.status;
  job.step = updates.step;
  job.progressPct = updates.progressPct;
  job.updatedAt = new Date();
}

export function completeJob(
  generationId: string,
  result: {
    masterMp3Url: string;
    stemsZipUrl?: string;
    durationSec?: number;
  },
): void {
  const job = jobs.get(generationId);
  if (!job) return;

  job.status = 'succeeded';
  job.step = 'ready';
  job.progressPct = 100;
  job.masterMp3Url = result.masterMp3Url;
  job.stemsZipUrl = result.stemsZipUrl;
  job.durationSec = result.durationSec || 180;
  job.updatedAt = new Date();
}

export function failJob(generationId: string, errorMessage: string): void {
  const job = jobs.get(generationId);
  if (!job) return;

  job.status = 'failed';
  job.step = 'failed';
  job.errorMessage = errorMessage;
  job.updatedAt = new Date();
}
