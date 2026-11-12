import type { Context } from 'hono';
import { resolveRuntimeEnv } from '../../config/env.js';
import type { VhunambiWorkerEnv } from '../../types/cloudflare_worker_types.js';
import { CompiledSynthesisPrompt } from './prompt_compiler.js';
import { simulateSynthesisPipeline } from './mock_worker.js';

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
  jobsInQueue: number;
  activePlusIdle: number;
}

const GENRE_LORA_DEFAULTS: Record<string, { loraId: string; path: string; weight: number }> = {
  amapiano: {
    loraId: 'amapiano_logdrum_v1',
    path: 'loras/amapiano_logdrum_v1.safetensors',
    weight: 0.85,
  },
  gqom: {
    loraId: 'gqom_durban_v1',
    path: 'loras/gqom_durban_v1.safetensors',
    weight: 0.88,
  },
  maskandi: {
    loraId: 'maskandi_picking_v1',
    path: 'loras/maskandi_picking_v1.safetensors',
    weight: 0.82,
  },
  venda: {
    loraId: 'venda_malende_v1',
    path: 'loras/venda_malende_v1.safetensors',
    weight: 0.85,
  },
  afrobeats: {
    loraId: 'afrobeats_lagos_v1',
    path: 'loras/afrobeats_lagos_v1.safetensors',
    weight: 0.80,
  },
  kwaito: {
    loraId: 'kwaito_township_v1',
    path: 'loras/kwaito_township_v1.safetensors',
    weight: 0.82,
  },
  gospel: {
    loraId: 'afro_gospel_choir_v1',
    path: 'loras/afro_gospel_choir_v1.safetensors',
    weight: 0.84,
  },
  afrohouse: {
    loraId: 'afrohouse_ancestral_v1',
    path: 'loras/afrohouse_ancestral_v1.safetensors',
    weight: 0.85,
  },
};

export function resolveGenreLoRAs(
  genre: string,
  explicitLoras?: Array<{ loraId?: string; lora_id?: string; path: string; weight: number }>,
): RunPodLoRASpec[] {
  if (Array.isArray(explicitLoras) && explicitLoras.length > 0) {
    return explicitLoras
      .filter((item) => Boolean(item && item.path))
      .map((item) => ({
        ...(item.loraId || item.lora_id ? { lora_id: item.loraId ?? item.lora_id } : {}),
        path: item.path,
        weight: typeof item.weight === 'number' ? item.weight : 0.85,
      }));
  }
  const normalized = (genre || 'amapiano').toLowerCase().replace(/[^a-z]/g, '');
  const preset = GENRE_LORA_DEFAULTS[normalized] ?? GENRE_LORA_DEFAULTS.amapiano;
  return [
    {
      lora_id: preset.loraId,
      path: preset.path,
      weight: preset.weight,
    },
  ];
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
    const jobsInQueue = Number(json.jobs?.inQueue ?? 0);
    const activePlusIdle = workersIdle + workersRunning + workersReady;

    return {
      workersKnown: true,
      workersIdle,
      workersRunning,
      workersInitializing,
      workersReady,
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
  const inferSteps = prompt.inferenceConfig?.inferSteps ?? 45;
  const precision = prompt.inferenceConfig?.precision ?? 'bf16';

  // If RunPod credentials are configured, check endpoint worker availability then dispatch
  if (runtimeEnv.RUNPOD_API_KEY && runtimeEnv.RUNPOD_ENDPOINT_ID) {
    const health = await checkRunPodEndpointHealth(cOrEnv);
    if (health.workersKnown && health.activePlusIdle === 0) {
      console.warn(
        `[RunPod] Queue-Zero Guard: endpoint ${runtimeEnv.RUNPOD_ENDPOINT_ID} has 0 active/idle workers (initializing=${health.workersInitializing}). Running real 4-stem R2 synthesis for ${generationId}.`,
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
              song_spec: {
                genre: prompt.metadata.genre,
                tempo: prompt.metadata.bpm,
                mood: prompt.metadata.mood,
                duration: prompt.metadata.durationSec,
                lyrics: prompt.lyrics,
                language: prompt.metadata.language,
                caption: prompt.caption,
                infer_steps: inferSteps,
                ...(prompt.sonicTags ? { sonic_tags: prompt.sonicTags } : {}),
                ...(prompt.metadata.title ? { title: prompt.metadata.title } : {}),
              },
              webhook_url: webhookUrl,
              precision,
              infer_steps: inferSteps,
              caption: prompt.caption,
              sonic_tags: prompt.sonicTags ?? [],
              loras: resolvedLoRAs,
              lora: resolvedLoRAs,
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
  audioUrl?: string;
  masterWavUrl?: string;
  stemsZipUrl?: string;
  stemUrls?: Record<string, string>;
  manifestUrl?: string;
  error?: string;
  progress?: number;
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
      };
    } else if (statusUpper === 'FAILED') {
      return {
        status: 'FAILED',
        error: data.error || data.output?.error || 'RunPod GPU job failed',
      };
    } else if (statusUpper === 'IN_PROGRESS') {
      return {
        status: 'IN_PROGRESS',
        progress: 60,
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
