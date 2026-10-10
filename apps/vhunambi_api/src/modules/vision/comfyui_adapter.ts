import { env } from '../../config/env.js';

export interface ComfyUIJobResult {
  jobId: string;
  isMock: boolean;
  promptText: string;
  seed: number;
  width: number;
  height: number;
  status: 'queued' | 'completed';
  outputImageUrl?: string;
}

export interface DispatchVisionOptions {
  promptText: string;
  seed?: number;
  width?: number;   // Default 768 (9:16 vertical)
  height?: number;  // Default 1344 (9:16 vertical)
  negativePrompt?: string;
  clientId?: string;
}

/**
 * Builds the canonical ComfyUI API graph matching the production
 * JSON state machine from docs/comfyui-sdxl-blueprint-1.md.
 */
export function buildComfyUIPromptGraph(
  promptText: string,
  seed: number,
  width: number = 768,
  height: number = 1344,
  negativePrompt: string = 'blurry, low quality, text, words, watermark, bad anatomy, ugly, signature, frame, border',
  checkpoint: string = 'sd_xl_base_1.0.safetensors',
) {
  return {
    '3': {
      inputs: { ckpt_name: checkpoint },
      class_type: 'CheckpointLoaderSimple',
    },
    '6': {
      inputs: {
        text: promptText,
        clip: ['3', 1],
      },
      class_type: 'CLIPTextEncode',
    },
    '7': {
      inputs: {
        text: negativePrompt,
        clip: ['3', 1],
      },
      class_type: 'CLIPTextEncode',
    },
    '5': {
      inputs: {
        width,
        height,
        batch_size: 1,
      },
      class_type: 'EmptyLatentImage',
    },
    '10': {
      inputs: {
        seed,
        steps: 25,
        cfg: 7.0,
        sampler_name: 'euler',
        scheduler: 'normal',
        denoise: 1.0,
        model: ['3', 0],
        positive: ['6', 0],
        negative: ['7', 0],
        latent_image: ['5', 0],
      },
      class_type: 'KSampler',
    },
    '12': {
      inputs: {
        samples: ['10', 0],
        vae: ['3', 2],
      },
      class_type: 'VAEDecode',
    },
    '15': {
      inputs: {
        filename_prefix: 'vhunambi_cover_9_16',
        images: ['12', 0],
      },
      class_type: 'SaveImage',
    },
  };
}

/**
 * Dispatches a 9:16 artwork generation job to RunPod ComfyUI.
 * Automatically falls back to mock simulation if RunPod credentials are not set.
 */
export async function dispatchComfyUIVisionJob(
  options: DispatchVisionOptions,
): Promise<ComfyUIJobResult> {
  const seed = options.seed ?? Math.floor(Math.random() * 1000000000);
  const width = options.width ?? 768;
  const height = options.height ?? 1344;
  const clientId = options.clientId ?? 'vhunambi_user_client';

  const promptGraph = buildComfyUIPromptGraph(
    options.promptText,
    seed,
    width,
    height,
    options.negativePrompt,
  );

  // 1. Direct ComfyUI HTTP Pod / Proxy endpoint
  if (env.RUNPOD_COMFYUI_URL) {
    try {
      const url = `${env.RUNPOD_COMFYUI_URL.replace(/\/$/, '')}/prompt`;
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(env.RUNPOD_API_KEY ? { Authorization: `Bearer ${env.RUNPOD_API_KEY}` } : {}),
        },
        body: JSON.stringify({
          client_id: clientId,
          prompt: promptGraph,
        }),
      });

      if (response.ok) {
        const data = (await response.json()) as { prompt_id: string };
        console.info(`[ComfyUI] ✅ Job dispatched: ${data.prompt_id} to ${url}`);
        return {
          jobId: data.prompt_id,
          isMock: false,
          promptText: options.promptText,
          seed,
          width,
          height,
          status: 'queued',
        };
      }
      console.warn(`[ComfyUI] ⚠️ Pod returned HTTP ${response.status}, falling back to simulation.`);
    } catch (e) {
      console.warn('[ComfyUI] ⚠️ Failed to reach ComfyUI pod, falling back to simulation:', e);
    }
  }

  // 2. RunPod Serverless ComfyUI Endpoint
  if (env.RUNPOD_API_KEY && env.RUNPOD_COMFYUI_ENDPOINT_ID) {
    try {
      const response = await fetch(
        `https://api.runpod.ai/v2/${env.RUNPOD_COMFYUI_ENDPOINT_ID}/run`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${env.RUNPOD_API_KEY}`,
          },
          body: JSON.stringify({
            input: {
              prompt: promptGraph,
              client_id: clientId,
            },
          }),
        },
      );

      if (response.ok) {
        const data = (await response.json()) as { id: string };
        console.info(`[ComfyUI] ✅ Serverless job dispatched: ${data.id}`);
        return {
          jobId: data.id,
          isMock: false,
          promptText: options.promptText,
          seed,
          width,
          height,
          status: 'queued',
        };
      }
    } catch (e) {
      console.warn('[ComfyUI] ⚠️ Serverless dispatch failed, falling back to simulation:', e);
    }
  }

  // 3. Fallback: In-process Mock Simulation (for local dev & headless tests)
  const mockJobId = `mock_vision_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
  const mockR2Url = `https://r2.vhunambi.com/visuals/mock/${mockJobId}_9_16.png`;

  console.info(`[ComfyUI] 🔄 Running mock simulation for vision job: ${mockJobId}`);
  return {
    jobId: mockJobId,
    isMock: true,
    promptText: options.promptText,
    seed,
    width,
    height,
    status: 'completed',
    outputImageUrl: mockR2Url,
  };
}
