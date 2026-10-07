import { Hono } from 'hono';
import { z } from 'zod';
import { nanoid } from 'nanoid';
import { env } from '../config/env.js';
import { compileSongSpec } from '../modules/synthesis/prompt_compiler.js';
import { getPresignedPutUrl } from '../modules/synthesis/r2_storage.js';
import { dispatchSynthesisJob } from '../modules/synthesis/runpod_adapter.js';
import { createJob, getJob } from '../modules/jobs/job_store.js';

export const generationRoutes = new Hono();

const SubmitGenerationSchema = z.object({
  trackTitle: z.string().default('Untitled Track'),
  genre: z.string().default('Amapiano'),
  language: z.string().default('ve'),
  lyrics: z.string().optional(),
  isInstrumental: z.boolean().default(false),
  tempoBpm: z.number().optional(),
  musicalKey: z.string().optional(),
  durationSec: z.number().default(180),
});

generationRoutes.post('/', async (c) => {
  try {
    const body = await c.req.json();
    const parsed = SubmitGenerationSchema.safeParse(body);

    if (!parsed.success) {
      return c.json({ error: 'INVALID_REQUEST', details: parsed.error.flatten() }, 400);
    }

    const input = parsed.data;
    const generationId = `gen_${Date.now()}_${nanoid(8)}`;

    // 1. Record job
    createJob({
      generationId,
      trackTitle: input.trackTitle,
      genre: input.genre,
      language: input.language,
    });

    // 2. Compile prompt for AI synthesis model
    const compiledPrompt = compileSongSpec(input);

    // 3. Pre-sign Cloudflare R2 destination URLs for master & stems
    const audioPutUrl = await getPresignedPutUrl(`${generationId}_master.mp3`);
    const stemsPutUrl = await getPresignedPutUrl(`${generationId}_stems.zip`);

    // 4. Dispatch to RunPod Serverless GPU (or mock simulation worker)
    const dispatchResult = await dispatchSynthesisJob(generationId, compiledPrompt, {
      audioPutUrl,
      stemsPutUrl,
    });

    return c.json(
      {
        success: true,
        generationId,
        status: 'queued',
        step: 'queued',
        progressPct: 10,
        providerTaskId: dispatchResult.jobId,
        pollUrl: `/v1/generations/${generationId}`,
        websocketUrl: `ws://localhost:${env.PORT}/ws/generation?id=${generationId}`,
      },
      201,
    );
  } catch (error) {
    console.error('[Generation Submit Error]', error);
    return c.json({ error: 'DISPATCH_ERROR', message: 'Failed to initiate audio synthesis' }, 500);
  }
});

generationRoutes.get('/:id', async (c) => {
  const id = c.req.param('id');
  const job = getJob(id);

  if (!job) {
    return c.json({ error: 'NOT_FOUND', message: `Generation job ${id} not found` }, 404);
  }

  return c.json({
    generationId: job.generationId,
    trackTitle: job.trackTitle,
    genre: job.genre,
    language: job.language,
    status: job.status,
    step: job.step,
    progressPct: job.progressPct,
    masterMp3Url: job.masterMp3Url,
    stemsZipUrl: job.stemsZipUrl,
    durationSec: job.durationSec,
    errorMessage: job.errorMessage,
    updatedAt: job.updatedAt.toISOString(),
  });
});
