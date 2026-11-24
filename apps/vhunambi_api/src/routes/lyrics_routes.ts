import { Hono } from 'hono';
import { z } from 'zod';
import { getGenreSystemPrompt } from '../modules/lyrics/system_prompts.js';
import {
  generateEnsembleLyricsFromLLM,
  generateLyricsFromPhotoWithLLM,
  parseStanzas,
  refineLyricsWithLLM,
} from '../modules/lyrics/llm_handler.js';
import { sanitizeLyricsForClient } from '../modules/lyrics/lyrics_sanitizer.js';
import { MUSIC_LANGUAGES } from '../modules/bantu/language_context.js';
import {
  STORY_GENRES,
  normalizeGenre,
  transformStoryToLyrics,
} from '../modules/lyrics/story_transform.js';
import type { VhunambiWorkerEnv } from '../types/cloudflare_worker_types.js';

export const lyricsRoutes = new Hono<{ Bindings: VhunambiWorkerEnv }>();

const GenerateLyricsSchema = z.object({
  // An empty prompt used to 400 -> client silently fell back to canned lyrics.
  prompt: z
    .string()
    .optional()
    .transform((v) => (v && v.trim().length > 0 ? v.trim() : 'Untitled song')),
  genre: z.string().default('Amapiano'),
  language: z.string().default('ve'),
  ensemble: z.enum(['solo', 'duet', 'choir']).optional(),
  voiceCast: z.array(z.string()).max(6).optional(),
  mood: z.string().optional(),
});

lyricsRoutes.post('/generate', async (c) => {
  try {
    const body = await c.req.json();
    const parsed = GenerateLyricsSchema.safeParse(body);

    if (!parsed.success) {
      return c.json({ error: 'INVALID_REQUEST', details: parsed.error.flatten() }, 400);
    }

    const { prompt, genre, language, ensemble, voiceCast, mood } = parsed.data;
    const systemPrompt = getGenreSystemPrompt(genre);
    const result = await generateEnsembleLyricsFromLLM(
      {
        prompt,
        genre,
        language,
        systemPrompt,
        ensemble,
        voiceCast,
        mood,
      },
      c,
    );

    // Strip stage directions ACE-Step would sing; keep UPPERCASE headers for the client parser.
    const cleanLyrics = sanitizeLyricsForClient(result.rawLyrics);

    return c.json({
      success: true,
      rawLyrics: cleanLyrics,
      stanzas: parseStanzas(cleanLyrics),
      vocalInstructions: result.vocalInstructions,
      detectedLanguage: result.detectedLanguage,
      moodAnalysis: result.moodAnalysis,
      cultureTags: result.cultureTags,
      ...(ensemble ? { ensemble } : {}),
    });
  } catch (error) {
    console.error('[Lyrics Route Error]', error);
    return c.json({
      error: 'SYNTHESIS_ERROR',
      message: 'Failed to generate lyrics',
      details: error instanceof Error ? error.stack || error.message : String(error),
    }, 500);
  }
});

const PhotoLyricsSchema = z.object({
  photoUrl: z.string().trim().min(1),
  captionHint: z.string().max(600).optional(),
  genre: z.string().default('Amapiano'),
  language: z.string().default('English'),
  mood: z.string().optional(),
  ensemble: z.enum(['solo', 'duet', 'choir']).optional(),
});

lyricsRoutes.post('/from-photo', async (c) => {
  try {
    const body = await c.req.json();
    const parsed = PhotoLyricsSchema.safeParse(body);
    if (!parsed.success) {
      return c.json({ error: 'INVALID_REQUEST', details: parsed.error.flatten() }, 400);
    }

    const result = await generateLyricsFromPhotoWithLLM(parsed.data, c);
    const cleanLyrics = sanitizeLyricsForClient(result.rawLyrics);
    return c.json({
      success: true,
      rawLyrics: cleanLyrics,
      stanzas: parseStanzas(cleanLyrics),
      vocalInstructions: result.vocalInstructions,
      detectedLanguage: result.detectedLanguage,
      moodAnalysis: result.moodAnalysis,
      cultureTags: result.cultureTags,
      sourcePhotoUrl: parsed.data.photoUrl,
    });
  } catch (error) {
    console.error('[Photo Lyrics Error]', error);
    return c.json(
      { error: 'PHOTO_LYRICS_ERROR', message: 'Failed to synthesize lyrics from photo' },
      500,
    );
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
