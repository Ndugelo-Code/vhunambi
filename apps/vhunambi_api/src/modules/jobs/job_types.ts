export type JobStatus = 'queued' | 'running' | 'succeeded' | 'failed';
export type PipelineStep = 'queued' | 'synthesizing' | 'separating_stems' | 'ready' | 'failed';

export interface GenerationJob {
  generationId: string;
  trackTitle: string;
  genre: string;
  language: string;
  status: JobStatus;
  step: PipelineStep;
  progressPct: number;
  masterMp3Url?: string;
  stemsZipUrl?: string;
  durationSec?: number;
  errorMessage?: string;
  providerTaskId?: string;
  createdAt: Date;
  updatedAt: Date;
}
