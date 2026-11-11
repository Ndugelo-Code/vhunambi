import { Hono } from 'hono';
import { z } from 'zod';
import { getGenreSystemPrompt } from '../modules/lyrics/system_prompts.js';
import { generateLyricsFromLLM, parseStanzas } from '../modules/lyrics/llm_handler.js';
import { refineLyricsWithLLM } from '../modules/lyrics/llm_handler.js';
import { MUSIC_LANGUAGES } from '../modules/bantu/language_context.js';
import { STORY_GENRES, normalizeGenre, transformStoryToLyrics } from '../modules/lyrics/story_transform.js';
import type { VhunambiWorkerEnv } from '../types/cloudflare_worker_types.js';

export const lyricsRoutes = new Hono<{ Bindings: VhunambiWorkerEnv }>();

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
    const result = await generateLyricsFromLLM(
      prompt,
      genre,
      language,
      systemPrompt,
      c,
    );

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
  genre: z.string().optional(),
  language: z.string().optional(),
});

lyricsRoutes.post('/refine', async (c) => {
  try {
    const body = await c.req.json();
    const parsed = RefineLyricsSchema.safeParse(body);

    if (!parsed.success) {
      return c.json({ error: 'INVALID_REQUEST', details: parsed.error.flatten() }, 400);
    }

    const { currentLyrics, refinementInstruction, idiomToInsert, genre, language } =
      parsed.data;
    const refined = await refineLyricsWithLLM(
      {
        currentLyrics,
        refinementInstruction,
        idiomToInsert,
        genre,
        language,
      },
      c,
    );

    return c.json({
      success: true,
      rawLyrics: refined.rawLyrics,
      stanzas: refined.stanzas.length > 0 ? refined.stanzas : parseStanzas(refined.rawLyrics),
      refinementApplied: refinementInstruction,
      provider: refined.provider,
    });
  } catch (error) {
    return c.json({ error: 'REFINE_ERROR', message: 'Failed to refine lyrics' }, 500);
  }
});


// ── Phase 36 Track B: Story-to-Lyrics (ZR-STORYLYRICS-001) ───────────────────
const StoryTransformSchema = z.object({
  storyText: z.string().trim().min(20).max(3000),
  genre: z.string().default('amapiano'),
  baseLanguage: z.string().default('zu'),
  targetCognateLanguages: z.array(z.string()).max(8).optional(),
  mood: z.array(z.string()).max(6).optional(),
});

lyricsRoutes.post('/story-transform', async (c) => {
  try {
    const body = await c.req.json();
    const parsed = StoryTransformSchema.safeParse(body);
    if (!parsed.success) {
      return c.json({ error: 'INVALID_REQUEST', details: parsed.error.flatten() }, 400);
    }

    const genre = normalizeGenre(parsed.data.genre);
    if (!genre) {
      return c.json({ error: 'UNSUPPORTED_GENRE', supported: STORY_GENRES }, 400);
    }

    const langCode = parsed.data.baseLanguage.toLowerCase().split('-')[0];
    if (!MUSIC_LANGUAGES.some((l) => l.languageCode === langCode)) {
      return c.json(
        { error: 'UNSUPPORTED_LANGUAGE', supported: MUSIC_LANGUAGES.map((l) => l.languageCode) },
        400,
      );
    }

    const result = transformStoryToLyrics({
      storyText: parsed.data.storyText,
      genre,
      baseLanguage: langCode,
      targetCognateLanguages: parsed.data.targetCognateLanguages,
      mood: parsed.data.mood,
    });
    return c.json({ success: true, ...result });
  } catch (error) {
    console.error('[Story Transform Route Error]', error);
    return c.json({ error: 'STORY_TRANSFORM_ERROR', message: 'Failed to transform story' }, 500);
  }
});
