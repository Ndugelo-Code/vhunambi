import { env } from '../../config/env.js';
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
): Promise<RunPodJobSubmitResult> {
  // Warn loudly in development if tunnel isn't configured — RunPod cannot reach localhost
  if (env.NODE_ENV === 'development' && env.WEBHOOK_BASE_URL.startsWith('http://localhost')) {
    console.warn(
      '[RunPod] ⚠️  WEBHOOK_BASE_URL is localhost — RunPod GPU callbacks WILL fail.\n' +
      '          Start a cloudflared tunnel and set WEBHOOK_BASE_URL in .env:\n' +
      '          $ cloudflared tunnel --url http://localhost:3000',
    );
  }

  const webhookUrl = `${env.WEBHOOK_BASE_URL}/v1/webhooks/ace-step`;
  const jobId = `vhunambi_${generationId}`;

  // If RunPod credentials are configured, dispatch to the shared GPU endpoint
  if (env.RUNPOD_API_KEY && env.RUNPOD_ENDPOINT_ID) {
    try {
      const response = await fetch(
        `https://api.runpod.ai/v2/${env.RUNPOD_ENDPOINT_ID}/run`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${env.RUNPOD_API_KEY}`,
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

  // Local development / fallback: run the 4-phase mock simulation in-process
  console.info(`[RunPod] 🔄 No credentials configured — running mock simulation for ${generationId}`);
  simulateSynthesisPipeline(generationId);
  return { jobId: `mock_${generationId}`, isMock: true };
}
