import { Hono } from 'hono';
import { z } from 'zod';
import {
  dispatchComfyUIVisionJob,
} from '../modules/vision/comfyui_adapter.js';
import {
  synthesizeVisionPrompt,
} from '../modules/vision/prompt_synthesizer.js';
import { compileSongMetadataDNA } from '../modules/dna/dna_compiler.js';

export const visionRoutes = new Hono();

const VisionGenerateSchema = z.object({
  title: z.string().optional(),
  genre: z.string().default('Amapiano'),
  language: z.string().default('ve'),
  mood: z.string().optional(),
  prompt: z.string().optional(),
  seed: z.number().optional(),
  width: z.number().default(768),
  height: z.number().default(1344),
  clientId: z.string().optional(),
});

/**
 * POST /v1/vision/generate
 *
 * Generates high-fidelity 9:16 vertical artwork/video background for reels
 * using RunPod ComfyUI (SDXL / FLUX) with African genre cultural prompting.
 */
visionRoutes.post('/generate', async (c) => {
  try {
    const body = await c.req.json();
    const parsed = VisionGenerateSchema.safeParse(body);

    if (!parsed.success) {
      return c.json({ error: 'INVALID_REQUEST', details: parsed.error.flatten() }, 400);
    }

    const input = parsed.data;

    // 1. Compile SongMetadataDNA for authentic cultural visual grounding
    const dna = compileSongMetadataDNA({
      title: input.title ?? 'Untitled Master',
      genre: input.genre,
      language: input.language,
      mood: input.mood ?? 'Euphoric',
      prompt: input.prompt,
    });

    // 2. Synthesize 9:16 visual prompt from DNA or prompt parameter
    const promptText = input.prompt && input.prompt.includes('9:16')
      ? input.prompt
      : await synthesizeVisionPrompt(dna);

    // 3. Dispatch to ComfyUI (RunPod pod / serverless / mock simulation)
    const result = await dispatchComfyUIVisionJob({
      promptText,
      seed: input.seed,
      width: input.width,
      height: input.height,
      clientId: input.clientId,
    });

    return c.json(
      {
        success: true,
        jobId: result.jobId,
        isMock: result.isMock,
        status: result.status,
        promptText: result.promptText,
        seed: result.seed,
        width: result.width,
        height: result.height,
        outputImageUrl: result.outputImageUrl,
      },
      201,
    );
  } catch (err) {
    console.error('[Vision Generate Error]', err);
    return c.json({ error: 'VISION_DISPATCH_ERROR', message: 'Failed to dispatch ComfyUI vision job' }, 500);
  }
});
