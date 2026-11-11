import type { Context } from 'hono';
import { resolveRuntimeEnv } from '../../config/env.js';
import type { VhunambiWorkerEnv } from '../../types/cloudflare_worker_types.js';
import { CompiledSynthesisPrompt } from './prompt_compiler.js';
import { simulateSynthesisPipeline } from './mock_worker.js';

export interface RunPodJobSubmitResult {
  jobId: string;
  isMock: boolean;
}

/**
 * Dispatch a synthesis job to the RunPod serverless endpoint.
 *
 * ⚠️ SCHEMA CONTRACT — Aligned to handler.py's `runpod_handler()` / `generate_music()`:
 *   input.job_id      — unique job identifier (prefixed "vhunambi_")
 *   input.user_id     — creator identity string
 *   input.song_spec   — Dict consumed by model_utils.ZRModelManager.generate_audio():
 *                         genre, tempo, mood, duration, lyrics, language, title
 *   input.webhook_url — absolute HTTPS URL for progress/completion callbacks
 *                         (HMAC-signed with ZR_WEBHOOK_SECRET via x-zrs-signature header)
 *   input.loras       — optional array of {path, weight} LoRA adapters
 *
 * Webhook callback payload (sent by handler.py send_webhook_notification()):
 *   { job_id, status: "processing|uploading|completed|failed",
 *     audio_url, error, progress, message }
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

  // If RunPod credentials are configured, dispatch to the shared GPU endpoint
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
              // ── Aligned to handler.py GenerationRequest schema ─────────────
              job_id: jobId,
              user_id: userId,
              song_spec: {
                genre:    prompt.metadata.genre,
                tempo:    prompt.metadata.bpm,
                mood:     prompt.metadata.mood,
                duration: prompt.metadata.durationSec,
                lyrics:   prompt.lyrics,
                language: prompt.metadata.language,
                ...(prompt.metadata.title ? { title: prompt.metadata.title } : {}),
              },
              webhook_url: webhookUrl,
              // LoRA array — empty for Phase 16; Phase 17 will add Bantu vocal adapters
              loras: [],
              lora: [],
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

  // Local development / fallback: run the 4-phase mock simulation
  console.info(`[RunPod] 🔄 No credentials configured — running mock simulation for ${generationId}`);
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

