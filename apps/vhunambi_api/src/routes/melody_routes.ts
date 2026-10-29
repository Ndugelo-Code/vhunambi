import { Hono } from 'hono';
import { MelodyPatternManifestSchema } from '../modules/melody/melody_types.js';
import {
  filterMelodyPresets,
  renderMelodyReferencePayload,
  STARTER_MELODY_PATTERNS,
} from '../modules/melody/melody_presets.js';

export const melodyRoutes = new Hono();

/**
 * GET /v1/melodies/presets
 * Returns the 6 Iconic African Starter Melody & Log-Drum Patterns (REQ-SKP-04, REQ-SKP-12).
 */
melodyRoutes.get('/presets', (c) => {
  const genre = c.req.query('genre');
  const instrument = c.req.query('instrument');

  const presets = filterMelodyPresets({ genre, instrument });
  return c.json({
    totalCount: STARTER_MELODY_PATTERNS.length,
    filteredCount: presets.length,
    presets,
  });
});

/**
 * POST /v1/melodies/render-reference
 * Validates a 16-step MelodyPatternManifest, synthesizes its WAV reference payload,
 * and returns extracted MMO transient events (`log_drum_drop` / `harmonic_turnaround`) (REQ-SKP-12).
 */
melodyRoutes.post('/render-reference', async (c) => {
  try {
    const body = await c.req.json();
    const parsed = MelodyPatternManifestSchema.safeParse(body);

    if (!parsed.success) {
      return c.json(
        { error: 'INVALID_MELODY_PATTERN', details: parsed.error.flatten() },
        400,
      );
    }

    const rendered = renderMelodyReferencePayload(parsed.data);
    return c.json({
      success: true,
      ...rendered,
    });
  } catch (err) {
    return c.json(
      { error: 'MELODY_RENDER_FAILED', message: String(err) },
      500,
    );
  }
});

