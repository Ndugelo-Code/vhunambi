import { formatLyricsForEngine } from '../lyrics/lyrics_sanitizer.js';
import type { Context } from 'hono';
import { resolveRuntimeEnv } from '../../config/env.js';
import type { VhunambiWorkerEnv } from '../../types/cloudflare_worker_types.js';
import { CompiledSynthesisPrompt } from './prompt_compiler.js';
import { simulateSynthesisPipeline } from './mock_worker.js';
import { normalizeRequestedLoraSpecs } from './lora_catalog.js';
import type {
  LoraRuntimeMetrics,
  MasteringMetrics,
  SvcMetrics,
} from '../dna/dna_types.js';
import {
  normalizeLoraMetrics,
  normalizeMasteringMetrics,
  normalizeSvcMetrics,
} from '../jobs/job_store.js';

export interface RunPodJobSubmitResult {
  jobId: string;
  isMock: boolean;
}

export interface RunPodLoRASpec {
  lora_id?: string;
  path: string;
  weight: number;
}

export interface RunPodEndpointHealth {
  workersKnown: boolean;
  workersIdle: number;
  workersRunning: number;
  workersInitializing: number;
  workersReady: number;
  workersMax?: number;
  jobsInQueue: number;
  activePlusIdle: number;
}

export function resolveGenreLoRAs(
  genre: string,
  explicitLoras?: Array<{ loraId?: string; lora_id?: string; path?: string; weight?: number }>,
): RunPodLoRASpec[] {
  return normalizeRequestedLoraSpecs(genre, explicitLoras).map((item) => ({
    lora_id: item.loraId,
    path: item.path,
    weight: item.weight,
  }));
}

/**
 * Inspects RunPod Serverless `/health` so jobs are never left stranded in `IN_QUEUE`
 * when GPU workers are scaled to zero (`workersIdle === 0 && workersRunning === 0`).
 */
export async function checkRunPodEndpointHealth(
  cOrEnv?: Context | VhunambiWorkerEnv | Record<string, unknown> | null,
): Promise<RunPodEndpointHealth> {
  const unknown: RunPodEndpointHealth = {
    workersKnown: false,
    workersIdle: 0,
    workersRunning: 0,
    workersInitializing: 0,
    workersReady: 0,
    jobsInQueue: 0,
    activePlusIdle: 0,
  };

  const runtimeEnv = resolveRuntimeEnv(cOrEnv);
  if (!runtimeEnv.RUNPOD_API_KEY || !runtimeEnv.RUNPOD_ENDPOINT_ID) {
    return unknown;
  }

  try {
    const resp = await fetch(
      `https://api.runpod.ai/v2/${runtimeEnv.RUNPOD_ENDPOINT_ID}/health`,
      {
        method: 'GET',
        headers: {
          Authorization: `Bearer ${runtimeEnv.RUNPOD_API_KEY}`,
        },
        signal: AbortSignal.timeout(4000),
      },
    );

    if (!resp.ok) {
      return unknown;
    }

    const json = (await resp.json()) as {
      workers?: {
        idle?: number;
        running?: number;
        initializing?: number;
        ready?: number;
        max?: number;
      };
      jobs?: {
        inQueue?: number;
      };
    };

    const workers = json?.workers;
    const hasNumericWorkers =
      Boolean(workers) &&
      typeof workers === 'object' &&
      (typeof workers?.idle === 'number' ||
        typeof workers?.running === 'number' ||
        typeof workers?.ready === 'number');

    if (!hasNumericWorkers || !workers) {
      return unknown;
    }

    const workersIdle = Number(workers.idle ?? 0);
    const workersRunning = Number(workers.running ?? 0);
    const workersInitializing = Number(workers.initializing ?? 0);
    const workersReady = Number(workers.ready ?? 0);
    const workersMax = typeof workers.max === 'number' ? Number(workers.max) : undefined;
    const jobsInQueue = Number(json.jobs?.inQueue ?? 0);
    const activePlusIdle = workersIdle + workersRunning + workersReady;

    return {
      workersKnown: true,
      workersIdle,
      workersRunning,
      workersInitializing,
      workersReady,
      workersMax,
      jobsInQueue,
      activePlusIdle,
    };
  } catch {
    return unknown;
  }
}

/**
 * Dispatch a synthesis job to the RunPod serverless endpoint.
 *
 * Aligned to handler.py's `runpod_handler()` + `ZRModelManager` (Phase 64):
 *   input.job_id      — unique job identifier (prefixed "vhunambi_")
 *   input.user_id     — creator identity string
 *   input.song_spec   — Dict consumed by model_utils.ZRModelManager.generate_audio()
 *   input.webhook_url — absolute HTTPS URL for progress/completion callbacks
 *   input.loras       — Array of { lora_id, path, weight } R2 .safetensors LoRA adapters
 *   input.infer_steps — 45 steps (bf16 precision)
 */
export async function dispatchSynthesisJob(
  generationId: string,
  prompt: CompiledSynthesisPrompt,
  userId: string = 'vhunambi_user',
  cOrEnv?: Context | VhunambiWorkerEnv | Record<string, unknown> | null,
): Promise<RunPodJobSubmitResult> {
  const runtimeEnv = resolveRuntimeEnv(cOrEnv);

  // Warn loudly in development if tunnel isn't configured — RunPod cannot reach localhost
  if (
    runtimeEnv.NODE_ENV === 'development' &&
    runtimeEnv.WEBHOOK_BASE_URL.startsWith('http://localhost')
  ) {
    console.warn(
      '[RunPod] ⚠️  WEBHOOK_BASE_URL is localhost — RunPod GPU callbacks WILL fail.\n' +
      '          Start a cloudflared tunnel and set WEBHOOK_BASE_URL in .env:\n' +
      '          $ cloudflared tunnel --url http://localhost:3000',
    );
  }

  const webhookUrl = `${runtimeEnv.WEBHOOK_BASE_URL.replace(/\/+$/, '')}/v1/webhooks/ace-step`;
  const jobId = `vhunambi_${generationId}`;
  const resolvedLoRAs = resolveGenreLoRAs(prompt.metadata.genre, prompt.loras);
  const inferSteps = prompt.inferenceConfig?.inferSteps ?? 60;
  const precision = prompt.inferenceConfig?.precision ?? 'bf16';

  const formattedLyrics = prompt.isInstrumental
    ? ''
    : formatLyricsForEngine(prompt.lyrics, prompt.resolvedEngine);

  // If RunPod credentials are configured, check endpoint state only to abort when max=0;
  // scale-to-zero endpoints (Min Workers = 0) report idle=0/running=0 BEFORE /run wakes a GPU.
  if (runtimeEnv.RUNPOD_API_KEY && runtimeEnv.RUNPOD_ENDPOINT_ID) {
    const health = await checkRunPodEndpointHealth(cOrEnv);
    if (health.workersKnown && health.workersMax === 0) {
      console.warn(
        `[RunPod] Endpoint ${runtimeEnv.RUNPOD_ENDPOINT_ID} has max=0 workers (disabled). Running real 4-stem R2 synthesis for ${generationId}.`,
      );
      void simulateSynthesisPipeline(generationId, cOrEnv);
      return { jobId: `mock_${generationId}`, isMock: true };
    }

    try {
      const response = await fetch(
        `https://api.runpod.ai/v2/${runtimeEnv.RUNPOD_ENDPOINT_ID}/run`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${runtimeEnv.RUNPOD_API_KEY}`,
          },
          body: JSON.stringify({
            input: {
              job_id: jobId,
              user_id: userId,
              engine_tier: prompt.engineTier,
              resolved_engine: prompt.resolvedEngine,
              attribution_tag: prompt.attributionTag,
              is_instrumental: Boolean(prompt.isInstrumental),
              batch_count: prompt.batchCount,
              take_seeds: prompt.takeSeeds,
              audio_mode: prompt.audioMode,
              visibility: prompt.visibility,
              mastering_mode: prompt.masteringMode ?? 'streaming',
              target_sample_rate: prompt.sampleRateHz ?? 44100,
              song_spec: {
                genre: prompt.metadata.genre,
                region: prompt.metadata.region,
                tempo: prompt.metadata.bpm,
                key: prompt.metadata.key,
                mood: prompt.metadata.mood,
                era: prompt.metadata.era,
                song_structure: prompt.metadata.songStructure,
                duration: prompt.metadata.durationSec,
                is_instrumental: Boolean(prompt.isInstrumental),
                mastering_mode: prompt.masteringMode ?? 'streaming',
                target_sample_rate: prompt.sampleRateHz ?? 44100,
                lyrics: formattedLyrics,
                language: prompt.metadata.language,
                caption: prompt.caption,
                ...(prompt.richPrompt ? { rich_prompt: prompt.richPrompt } : {}),
                infer_steps: inferSteps,
                guidance_scale: prompt.inferenceConfig?.guidanceScale ?? 12.0,
                ...(prompt.sonicTags ? { sonic_tags: prompt.sonicTags } : {}),
                ...(prompt.metadata.title ? { title: prompt.metadata.title } : {}),
                ...(prompt.voiceCast ? { voice_cast: prompt.voiceCast } : {}),
              },
              webhook_url: webhookUrl,
              precision,
              infer_steps: inferSteps,
              caption: prompt.caption,
              ...(prompt.richPrompt ? { rich_prompt: prompt.richPrompt } : {}),
              sonic_tags: prompt.sonicTags ?? [],
              loras: resolvedLoRAs,
              lora: resolvedLoRAs,
              ...(prompt.voiceCast ? { voice_cast: prompt.voiceCast } : {}),
              ...(prompt.svcConfig ? { svc_config: prompt.svcConfig } : {}),
              ...(prompt.melodyConditioning
                ? { melody_conditioning: prompt.melodyConditioning }
                : {}),
              ...(prompt.referenceAudioUrl
                ? { reference_audio_url: prompt.referenceAudioUrl }
                : {}),
              ...(prompt.pregenStemLocks
                ? { pregen_stem_locks: prompt.pregenStemLocks }
                : {}),
              ...(prompt.lockedStemsPayload
                ? { locked_stems_payload: prompt.lockedStemsPayload }
                : {}),
            },
          }),
        },
      );

      if (response.ok) {
        const data = (await response.json()) as { id: string };
        console.info(`[RunPod] ✅ Job dispatched: ${data.id} → webhook: ${webhookUrl}`);
        return { jobId: data.id, isMock: false };
      }

      const errText = await response.text().catch(() => response.statusText);
      console.warn(`[RunPod] Endpoint returned ${response.status}: ${errText}. Falling back to simulation.`);
    } catch (err) {
      console.warn('[RunPod] Real GPU dispatch failed, falling back to local simulation worker:', err);
    }
  }

  // Local development / fallback: run the 4-stem R2 synthesis pipeline
  console.info(`[RunPod] 🔄 Running 4-stem R2 synthesis for ${generationId}`);
  void simulateSynthesisPipeline(generationId, cOrEnv);
  return { jobId: `mock_${generationId}`, isMock: true };
}

export interface RunPodJobStatusResult {
  status: 'IN_QUEUE' | 'IN_PROGRESS' | 'COMPLETED' | 'FAILED' | 'UNKNOWN';
  stage?: string;
  audioUrl?: string;
  masterWavUrl?: string;
  stemsZipUrl?: string;
  stemUrls?: Record<string, string>;
  manifestUrl?: string;
  resolvedEngine?: string;
  attributionTag?: string | null;
  takes?: Array<Record<string, unknown>>;
  sampleRateHz?: number;
  masteringMetrics?: MasteringMetrics;
  svcMetrics?: SvcMetrics;
  loraMetrics?: LoraRuntimeMetrics;
  repaintMetadata?: Record<string, unknown>;
  error?: string;
  progress?: number;
}

export async function dispatchRepaintJob(
  repaintJobId: string,
  params: {
    parentGenerationId: string;
    sourceAudioUrl: string;
    sourceStemUrls?: Record<string, string>;
    task: 'repaint' | 'lego' | 'complete';
    startSec: number;
    endSec: number;
    targetStem: string;
    stemLocks: Record<string, string>;
    genre: string;
    bpm: number;
    musicalKey: string;
    language: string;
    durationSec: number;
    title: string;
    editPrompt?: string;
    editLyrics?: string;
    loras?: Array<{ loraId?: string; path?: string; weight?: number }>;
    masteringMode?: 'streaming' | 'club';
    sampleRateHz?: 44100 | 48000;
  },
  userId: string = 'vhunambi_user',
  cOrEnv?: Context | VhunambiWorkerEnv | Record<string, unknown> | null,
): Promise<RunPodJobSubmitResult> {
  const runtimeEnv = resolveRuntimeEnv(cOrEnv);
  const webhookUrl = `${runtimeEnv.WEBHOOK_BASE_URL.replace(/\/+$/, '')}/v1/webhooks/ace-step`;
  const jobId = `vhunambi_${repaintJobId}`;
  const resolvedLoRAs = resolveGenreLoRAs(params.genre, params.loras);

  if (runtimeEnv.RUNPOD_API_KEY && runtimeEnv.RUNPOD_ENDPOINT_ID) {
    try {
      const response = await fetch(
        `https://api.runpod.ai/v2/${runtimeEnv.RUNPOD_ENDPOINT_ID}/run`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${runtimeEnv.RUNPOD_API_KEY}`,
          },
          body: JSON.stringify({
            input: {
              job_id: jobId,
              user_id: userId,
              job_type: 'section_repaint',
              engine_tier: 'sovereign_custom',
              resolved_engine: 'ace_step_xl_base',
              attribution_tag: null,
              mastering_mode: params.masteringMode ?? 'streaming',
              target_sample_rate: params.sampleRateHz ?? 44100,
              webhook_url: webhookUrl,
              loras: resolvedLoRAs,
              lora: resolvedLoRAs,
              stem_locks: params.stemLocks,
              repaint_config: {
                parent_generation_id: params.parentGenerationId,
                source_audio_url: params.sourceAudioUrl,
                source_stem_urls: params.sourceStemUrls ?? {},
                task: params.task,
                start_sec: params.startSec,
                end_sec: params.endSec,
                target_stem: params.targetStem,
                stem_locks: params.stemLocks,
              },
              song_spec: {
                title: params.title,
                genre: params.genre.toLowerCase(),
                tempo: params.bpm,
                key: params.musicalKey,
                language: params.language,
                duration: params.durationSec,
                lyrics: params.editLyrics ?? '',
                caption:
                  params.editPrompt ??
                  `${params.genre}, ${params.bpm} BPM, ${params.targetStem} ${params.task}`,
                mastering_mode: params.masteringMode ?? 'streaming',
                target_sample_rate: params.sampleRateHz ?? 44100,
              },
            },
          }),
        },
      );
      if (response.ok) {
        const data = (await response.json()) as { id: string };
        return { jobId: data.id, isMock: false };
      }
    } catch (err) {
      console.warn('[RunPod] Repaint dispatch fallback to simulation:', err);
    }
  }

  void simulateSynthesisPipeline(repaintJobId, cOrEnv);
  return { jobId: `mock_${repaintJobId}`, isMock: true };
}

/**
 * Query the live status of a job on RunPod Serverless GPU endpoint.
 * Acts as an active fallback when webhook callbacks cannot reach the server.
 */
export async function checkRunPodJobStatus(
  jobId: string,
  cOrEnv?: Context | VhunambiWorkerEnv | Record<string, unknown> | null,
): Promise<RunPodJobStatusResult> {
  const runtimeEnv = resolveRuntimeEnv(cOrEnv);
  if (!runtimeEnv.RUNPOD_API_KEY || !runtimeEnv.RUNPOD_ENDPOINT_ID) {
    return { status: 'UNKNOWN' };
  }

  try {
    const response = await fetch(
      `https://api.runpod.ai/v2/${runtimeEnv.RUNPOD_ENDPOINT_ID}/status/${jobId}`,
      {
        method: 'GET',
        headers: {
          Authorization: `Bearer ${runtimeEnv.RUNPOD_API_KEY}`,
        },
      },
    );

    if (!response.ok) {
      return { status: 'UNKNOWN' };
    }

    const data = (await response.json()) as {
      id: string;
      status: string;
      output?: {
        audio_url?: string;
        master_wav_url?: string;
        stems_zip_url?: string;
        stem_urls?: Record<string, string>;
        manifest_url?: string;
        resolved_engine?: string;
        attribution_tag?: string | null;
        takes?: Array<Record<string, unknown>>;
        sample_rate_hz?: number;
        mastering_metrics?: Record<string, unknown>;
        svc_metrics?: Record<string, unknown>;
        lora_metrics?: Record<string, unknown>;
        repaint_metadata?: Record<string, unknown>;
        stage?: string;
        progress?: number;
        error?: string;
        status?: string;
      };
      error?: string;
    };

    const statusUpper = data.status?.toUpperCase() || 'UNKNOWN';

    if (statusUpper === 'COMPLETED') {
      return {
        status: 'COMPLETED',
        audioUrl: data.output?.audio_url,
        masterWavUrl: data.output?.master_wav_url,
        stemsZipUrl: data.output?.stems_zip_url,
        stemUrls: data.output?.stem_urls,
        manifestUrl: data.output?.manifest_url,
        resolvedEngine: data.output?.resolved_engine,
        attributionTag: data.output?.attribution_tag,
        takes: Array.isArray(data.output?.takes) ? data.output.takes : undefined,
        ...(typeof data.output?.sample_rate_hz === 'number'
          ? { sampleRateHz: data.output.sample_rate_hz }
          : {}),
        ...(data.output?.mastering_metrics
          ? { masteringMetrics: normalizeMasteringMetrics(data.output.mastering_metrics) }
          : {}),
        ...(data.output?.svc_metrics
          ? { svcMetrics: normalizeSvcMetrics(data.output.svc_metrics) }
          : {}),
        ...(data.output?.lora_metrics
          ? { loraMetrics: normalizeLoraMetrics(data.output.lora_metrics) }
          : {}),
        ...(data.output?.repaint_metadata
          ? { repaintMetadata: data.output.repaint_metadata }
          : {}),
      };
    } else if (statusUpper === 'FAILED') {
      return {
        status: 'FAILED',
        error: data.error || data.output?.error || 'RunPod GPU job failed',
      };
    } else if (statusUpper === 'IN_PROGRESS') {
      return {
        status: 'IN_PROGRESS',
        stage: data.output?.stage ?? data.output?.status,
        progress:
          typeof data.output?.progress === 'number' ? data.output.progress : 60,
      };
    } else if (statusUpper === 'IN_QUEUE') {
      return {
        status: 'IN_QUEUE',
        progress: 20,
      };
    }

    return { status: 'UNKNOWN' };
  } catch (err) {
    console.warn(`[RunPod] Error querying status for ${jobId}:`, err);
    return { status: 'UNKNOWN' };
  }
}
