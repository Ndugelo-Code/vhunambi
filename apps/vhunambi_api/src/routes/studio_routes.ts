import { Hono } from 'hono';
import { z } from 'zod';
import { improveStudioPromptWithLLM } from '../modules/lyrics/llm_handler.js';
import type { VhunambiWorkerEnv } from '../types/cloudflare_worker_types.js';

export const studioRoutes = new Hono<{ Bindings: VhunambiWorkerEnv }>();

const ImprovePromptSchema = z.object({
  prompt: z.string().trim().min(2).max(2000),
  genre: z.string().default('Amapiano'),
  region: z.string().default('South Africa'),
  language: z.string().default('English'),
  mood: z.string().optional(),
  ensemble: z.enum(['solo', 'duet', 'choir']).optional(),
  isInstrumental: z.boolean().default(false),
});

studioRoutes.post('/improve-prompt', async (c) => {
  try {
    const body = await c.req.json();
    const parsed = ImprovePromptSchema.safeParse(body);
    if (!parsed.success) {
      return c.json(
        { error: 'INVALID_REQUEST', details: parsed.error.flatten() },
        400,
      );
    }

    const result = await improveStudioPromptWithLLM(parsed.data, c);
    return c.json({
      success: true,
      improvedPrompt: result.improvedPrompt,
      genre: parsed.data.genre,
      suggestedBpm: result.suggestedBpm,
      suggestedMood: result.suggestedMood,
      provider: result.provider,
    });
  } catch (error) {
    console.error('[Studio Improve Prompt Error]', error);
    return c.json(
      { error: 'PROMPT_IMPROVE_ERROR', message: 'Failed to improve prompt' },
      500,
    );
  }
});
