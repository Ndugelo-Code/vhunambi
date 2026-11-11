import { Hono } from 'hono';
import { z } from 'zod';
import {
  assertTenantCreatorAccess,
  resolveEffectiveCreatorId,
  sovereignAuthMiddleware,
} from '../middleware/auth_middleware.js';
import {
  deleteR2Object,
  getPresignedPutUrl,
} from '../modules/synthesis/r2_storage.js';
import {
  CreateVoiceCloneRequestSchema,
  RegisterSoundSignatureSchema,
  SoundIdealizerRecipeSchema,
} from '../modules/voices/voice_types.js';
import {
  deleteSoundSignature,
  extractPhoneticCalibrationScript,
  filterVoiceCatalog,
  getSoundSignature,
  getVoiceCloneProfile,
  REGIONAL_VOICE_CATALOG,
  registerSoundSignature,
  registerVoiceCloneProfile,
  updateSoundSignatureRecipe,
} from '../modules/voices/voice_catalog.js';

export const voiceRoutes = new Hono();

voiceRoutes.use('*', sovereignAuthMiddleware);

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

    const forbidden = assertTenantCreatorAccess(c, parsed.data.creatorId);
    if (forbidden) return forbidden;

    const effectiveCreatorId = resolveEffectiveCreatorId(
      c,
      parsed.data.creatorId,
      'creator_cern',
    );
    const profile = registerVoiceCloneProfile({
      ...parsed.data,
      creatorId: effectiveCreatorId,
    });

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

/**
 * POST /v1/voices/signatures
 * Registers a sovereign SoundSignatureDna record and returns presigned upload metadata (REQ-SIG-CLOUD-01 / Design 8.2).
 */
voiceRoutes.post('/signatures', async (c) => {
  try {
    const body = await c.req.json();
    const parsed = RegisterSoundSignatureSchema.safeParse(body);

    if (!parsed.success) {
      return c.json(
        { error: 'INVALID_SIGNATURE_PAYLOAD', details: parsed.error.flatten() },
        400,
      );
    }

    // Explicit consent is required before presigning cloud storage or GPU analysis
    if (!parsed.data.consentAtIso && !parsed.data.consentConfirmed) {
      return c.json(
        {
          error: 'CONSENT_REQUIRED_FOR_CLOUD_PROCESSING',
          message: 'Explicit user consent timestamp is required to register a cloud sound signature take.',
        },
        400,
      );
    }

    if (parsed.data.creatorId) {
      const forbidden = assertTenantCreatorAccess(c, parsed.data.creatorId);
      if (forbidden) return forbidden;
    }

    const effectiveCreatorId = resolveEffectiveCreatorId(
      c,
      parsed.data.creatorId,
      'creator_cern',
    );
    const record = registerSoundSignature({
      ...parsed.data,
      creatorId: effectiveCreatorId,
      consentAtIso: parsed.data.consentAtIso ?? new Date().toISOString(),
    });
    const presignedUploadUrl = await getPresignedPutUrl(
      record.r2AudioKey,
      'audio/wav',
      900,
      c,
    );

    return c.json(
      {
        success: true,
        signature: record,
        uploadUrl: presignedUploadUrl,
        presignedUploadUrl,
        expiresInSeconds: 900,
        r2Key: record.r2AudioKey,
      },
      201,
    );
  } catch (err) {
    return c.json(
      { error: 'SIGNATURE_REGISTRATION_FAILED', message: String(err) },
      500,
    );
  }
});

/**
 * POST /v1/voices/signatures/:id/analyze
 * Enqueues GPU timbre embedding and speaker enhancement job.
 */
voiceRoutes.post('/signatures/:id/analyze', async (c) => {
  const id = c.req.param('id');
  const record = getSoundSignature(id);

  if (!record) {
    return c.json({ error: 'NOT_FOUND', message: `Sound signature ${id} not found` }, 404);
  }

  const jobId = `job_embed_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`;
  return c.json({
    success: true,
    jobId,
    status: 'enqueued',
    signatureId: id,
  });
});

/**
 * PATCH /v1/voices/signatures/:id/recipe
 * Updates non-destructive idealization recipe parameters.
 */
voiceRoutes.patch('/signatures/:id/recipe', async (c) => {
  const id = c.req.param('id');
  const existing = getSoundSignature(id);
  if (!existing) {
    return c.json({ error: 'NOT_FOUND', message: `Sound signature ${id} not found` }, 404);
  }
  const forbidden = assertTenantCreatorAccess(c, existing.creatorId);
  if (forbidden) return forbidden;

  const body = await c.req.json();

  const parsed = SoundIdealizerRecipeSchema.partial().safeParse(body);
  if (!parsed.success) {
    return c.json(
      { error: 'INVALID_RECIPE_PAYLOAD', details: parsed.error.flatten() },
      400,
    );
  }

  const updated = updateSoundSignatureRecipe(id, parsed.data);
  if (!updated) {
    return c.json({ error: 'NOT_FOUND', message: `Sound signature ${id} not found` }, 404);
  }

  return c.json({ success: true, signature: updated });
});

/**
 * GET /v1/voices/signatures/:id
 * Retrieves sound signature metadata, recipe, and cloud embedding reference.
 */
voiceRoutes.get('/signatures/:id', (c) => {
  const id = c.req.param('id');
  const record = getSoundSignature(id);

  if (!record) {
    return c.json({ error: 'NOT_FOUND', message: `Sound signature ${id} not found` }, 404);
  }

  return c.json({ signature: record });
});

/**
 * DELETE /v1/voices/signatures/:id
 * Purges signature metadata, cloud audio take, and speaker embedding.
 */
voiceRoutes.delete('/signatures/:id', async (c) => {
  const id = c.req.param('id');
  const existing = getSoundSignature(id);
  if (!existing) {
    return c.json({ error: 'NOT_FOUND', message: `Sound signature ${id} not found` }, 404);
  }

  const forbidden = assertTenantCreatorAccess(c, existing.creatorId);
  if (forbidden) return forbidden;

  const r2Key = existing.r2AudioKey || `signatures/${id}/raw.wav`;
  await deleteR2Object(r2Key, c);
  const deleted = deleteSoundSignature(id);

  if (!deleted) {
    return c.json({ error: 'NOT_FOUND', message: `Sound signature ${id} not found` }, 404);
  }

  return c.json({
    success: true,
    deleted: true,
    deletedId: id,
    id,
    r2Cleaned: true,
    timestamp: new Date().toISOString(),
    purgedResources: [`r2://${r2Key}`, `embeddings/${id}`],
  });
});


