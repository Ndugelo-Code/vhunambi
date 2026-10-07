import { Hono } from 'hono';
import { z } from 'zod';
import { getGenreSystemPrompt } from '../modules/lyrics/system_prompts.js';
import { generateLyricsFromLLM, parseStanzas } from '../modules/lyrics/llm_handler.js';

export const lyricsRoutes = new Hono();

const GenerateLyricsSchema = z.object({
  prompt: z.string().min(1),
  genre: z.string().default('Amapiano'),
  language: z.string().default('ve'),
});

lyricsRoutes.post('/generate', async (c) => {
  try {
    const body = await c.req.json();
    const parsed = GenerateLyricsSchema.safeParse(body);

    if (!parsed.success) {
      return c.json({ error: 'INVALID_REQUEST', details: parsed.error.flatten() }, 400);
    }

    const { prompt, genre, language } = parsed.data;
    const systemPrompt = getGenreSystemPrompt(genre);
    const result = await generateLyricsFromLLM(prompt, genre, language, systemPrompt);

    return c.json({
      success: true,
      rawLyrics: result.rawLyrics,
      stanzas: result.stanzas,
      vocalInstructions: result.vocalInstructions,
      detectedLanguage: result.detectedLanguage,
      moodAnalysis: result.moodAnalysis,
      cultureTags: result.cultureTags,
    });
  } catch (error) {
    console.error('[Lyrics Route Error]', error);
    return c.json({ error: 'SYNTHESIS_ERROR', message: 'Failed to generate lyrics' }, 500);
  }
});

const RefineLyricsSchema = z.object({
  currentLyrics: z.string(),
  refinementInstruction: z.string(),
  idiomToInsert: z.string().optional(),
});

lyricsRoutes.post('/refine', async (c) => {
  try {
    const body = await c.req.json();
    const parsed = RefineLyricsSchema.safeParse(body);

    if (!parsed.success) {
      return c.json({ error: 'INVALID_REQUEST', details: parsed.error.flatten() }, 400);
    }

    const { currentLyrics, refinementInstruction, idiomToInsert } = parsed.data;
    let updatedLyrics = currentLyrics;

    if (idiomToInsert) {
      updatedLyrics = `${currentLyrics.trim()}\n${idiomToInsert}`;
    }

    return c.json({
      success: true,
      rawLyrics: updatedLyrics,
      stanzas: parseStanzas(updatedLyrics),
      refinementApplied: refinementInstruction,
    });
  } catch (error) {
    return c.json({ error: 'REFINE_ERROR', message: 'Failed to refine lyrics' }, 500);
  }
});
