import {
  LoraRuntimeMetrics,
  MasterMediaObjectManifest,
  MasteringMetrics,
  RepaintHistoryEntry,
  SvcMetrics,
} from '../dna/dna_types.js';

export type JobStatus = 'queued' | 'running' | 'succeeded' | 'failed';
export type PipelineStep =
  | 'queued'
  | 'planning_lyrics'
  | 'synthesizing'
  | 'separating_stems'
  | 'converting_vocals'
  | 'mastering'
  | 'uploading'
  | 'ready'
  | 'failed';

export type StudioEngineTier = 'fast_draft' | 'studio_bake' | 'sovereign_custom';
export type ResolvedAudioEngine =
  | 'ace_step_xl_turbo'
  | 'ace_step_xl_sft'
  | 'ace_step_xl_base'
  | 'minimax_music_3';
export type ReferenceAudioMode =
  | 'none'
  | 'remix'
  | 'cover'
  | 'reference'
  | 'inspiration';

export interface GenerationTakeRecord {
  takeIndex: number;
  seed: number;
  engineUsed: ResolvedAudioEngine | string;
  audioUrl: string;
  durationSec?: number;
  score?: number;
  attribution?: string | null;
}

export interface GenerationJob {
  generationId: string;
  creatorId?: string;
  batchId?: string;
  batchCount?: number;
  engineTier?: StudioEngineTier;
  resolvedEngine?: ResolvedAudioEngine;
  audioMode?: ReferenceAudioMode;
  referenceAudioUrl?: string;
  visibility?: 'public' | 'private';
  attributionTag?: string | null;
  voiceCast?: Record<string, unknown>;
  generationSpec?: Record<string, unknown>;
  takes?: GenerationTakeRecord[];
  trackTitle: string;
  genre: string;
  language: string;
  status: JobStatus;
  step: PipelineStep;
  progressPct: number;
  masterMp3Url?: string;
  stemsZipUrl?: string;
  stemUrls?: Record<string, string>;
  manifestUrl?: string;
  manifest?: MasterMediaObjectManifest;
  visionMeta?: Record<string, unknown>;
  coverUrl?: string;
  lyrics?: string;
  durationSec?: number;
  sampleRateHz?: number;
  masteringMode?: 'streaming' | 'club';
  masteringMetrics?: MasteringMetrics;
  svcMetrics?: SvcMetrics;
  parentGenerationId?: string;
  loraMetrics?: LoraRuntimeMetrics;
  repaintHistory?: RepaintHistoryEntry[];
  repaintMetadata?: Record<string, unknown>;
  errorMessage?: string;
  providerTaskId?: string;
  createdAt: Date;
  updatedAt: Date;
}
