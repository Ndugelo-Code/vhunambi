import { env } from '../../config/env.js';
import { CompiledSynthesisPrompt } from './prompt_compiler.js';
import { simulateSynthesisPipeline } from './mock_worker.js';

export interface RunPodJobSubmitResult {
  jobId: string;
  isMock: boolean;
}

export async function dispatchSynthesisJob(
  generationId: string,
  prompt: CompiledSynthesisPrompt,
  outputUrls: {
    audioPutUrl: string;
    stemsPutUrl: string;
  },
): Promise<RunPodJobSubmitResult> {
  // If RunPod is configured, dispatch to GPU endpoint
  if (env.RUNPOD_API_KEY && env.RUNPOD_ENDPOINT_ID) {
    try {
      const response = await fetch(`https://api.runpod.ai/v2/${env.RUNPOD_ENDPOINT_ID}/run`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: env.RUNPOD_API_KEY,
        },
        body: JSON.stringify({
          input: {
            job_id: generationId,
            engine: 'ace-step',
            prompt: {
              caption: prompt.caption,
              lyrics: prompt.lyrics,
              metadata: prompt.metadata,
            },
            output: {
              audio_put_url: outputUrls.audioPutUrl,
              stems_put_prefix: outputUrls.stemsPutUrl,
            },
            callback: {
              webhook_url: `http://localhost:${env.PORT}/v1/webhooks/ace-step`,
              hmac_secret_id: env.ZR_WEBHOOK_SECRET,
            },
          },
        }),
      });

      if (response.ok) {
        const data = (await response.json()) as { id: string };
        return { jobId: data.id, isMock: false };
      }
    } catch (err) {
      console.warn('[RunPod] Real GPU dispatch failed, falling back to local simulation worker:', err);
    }
  }

  // Local development / fallback simulation
  simulateSynthesisPipeline(generationId);
  return { jobId: `mock_${generationId}`, isMock: true };
}
