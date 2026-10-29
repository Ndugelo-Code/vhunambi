import { Hono } from 'hono';
import { z } from 'zod';
import { CreateVoiceCloneRequestSchema } from '../modules/voices/voice_types.js';
import {
  extractPhoneticCalibrationScript,
  filterVoiceCatalog,
  getVoiceCloneProfile,
  REGIONAL_VOICE_CATALOG,
  registerVoiceCloneProfile,
} from '../modules/voices/voice_catalog.js';

export const voiceRoutes = new Hono();

/**
 * GET /v1/voices/catalog
 * Returns the 24+ Sovereign Regional African Voice Archetypes with optional filtering (REQ-VOC-03).
 */
voiceRoutes.get('/catalog', (c) => {
  const region = c.req.query('region');
  const gender = c.req.query('gender');
  const language = c.req.query('language');
  const style = c.req.query('style');
  const q = c.req.query('q');

  const voices = filterVoiceCatalog({ region, gender, language, style, q });

  return c.json({
    totalCount: REGIONAL_VOICE_CATALOG.length,
    filteredCount: voices.length,
    voices,
  });
});

const ExtractCalibrationSchema = z.object({
  lyrics: z.string().default(''),
  language: z.string().default('ve'),
});

/**
 * POST /v1/voices/extract-calibration
 * Scores the user's lyrics and returns the top 3 phonetically dense lines (REQ-VOC-04..06).
 */
voiceRoutes.post('/extract-calibration', async (c) => {
  try {
    const body = await c.req.json();
    const parsed = ExtractCalibrationSchema.safeParse(body);

    if (!parsed.success) {
      return c.json(
        { error: 'INVALID_CALIBRATION_REQUEST', details: parsed.error.flatten() },
        400,
      );
    }

    const script = extractPhoneticCalibrationScript(
      parsed.data.lyrics,
      parsed.data.language,
    );

    return c.json({
      success: true,
      script,
    });
  } catch (err) {
    return c.json(
      { error: 'CALIBRATION_EXTRACTION_FAILED', message: String(err) },
      500,
    );
  }
});

/**
 * POST /v1/voices/clone
 * Validates and registers a 3-line zero-shot voice calibration recording (REQ-VOC-08).
 */
voiceRoutes.post('/clone', async (c) => {
  try {
    const body = await c.req.json();
    const parsed = CreateVoiceCloneRequestSchema.safeParse(body);

    if (!parsed.success) {
      return c.json(
        { error: 'INVALID_VOICE_CLONE_PAYLOAD', details: parsed.error.flatten() },
        400,
      );
    }

    const profile = registerVoiceCloneProfile(parsed.data);

    return c.json(
      {
        success: true,
        profile,
      },
      201,
    );
  } catch (err) {
    return c.json(
      { error: 'VOICE_CLONE_SYNTHESIS_ERROR', message: String(err) },
      500,
    );
  }
});

/**
 * GET /v1/voices/clone/:id
 * Retrieves a registered CreatorVoiceCloneProfile by ID.
 */
voiceRoutes.get('/clone/:id', (c) => {
  const id = c.req.param('id');
  const profile = getVoiceCloneProfile(id);

  if (!profile) {
    return c.json({ error: 'NOT_FOUND', message: `Voice clone ${id} not found` }, 404);
  }

  return c.json({ profile });
});

