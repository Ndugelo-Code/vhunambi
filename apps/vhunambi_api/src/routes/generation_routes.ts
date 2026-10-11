import { Hono } from 'hono';
import { z } from 'zod';
import { nanoid } from 'nanoid';
import { env } from '../config/env.js';
import { compileSongSpec } from '../modules/synthesis/prompt_compiler.js';
import { dispatchSynthesisJob, checkRunPodJobStatus } from '../modules/synthesis/runpod_adapter.js';
import {
  createJob,
  getJob,
  setJobProviderTaskId,
  updateJobProgress,
  completeJob,
  failJob,
} from '../modules/jobs/job_store.js';

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
  /** Optional user identifier — forwarded to RunPod worker as user_id */
  userId: z.string().optional(),
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

    // 3. Dispatch to RunPod Serverless GPU (or mock simulation worker)
    const dispatchResult = await dispatchSynthesisJob(
      generationId,
      compiledPrompt,
      input.userId ?? 'vhunambi_user',
    );

    // Record providerTaskId for fallback active polling
    setJobProviderTaskId(generationId, dispatchResult.jobId);

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

  // Active sync from RunPod if job is still in flight and has a real providerTaskId
  if (
    (job.status === 'queued' || job.status === 'running') &&
    job.providerTaskId &&
    !job.providerTaskId.startsWith('mock_')
  ) {
    const liveStatus = await checkRunPodJobStatus(job.providerTaskId);
    if (liveStatus.status === 'COMPLETED' && liveStatus.audioUrl) {
      completeJob(id, {
        masterMp3Url: liveStatus.audioUrl,
        stemsZipUrl: liveStatus.stemsZipUrl,
      });
    } else if (liveStatus.status === 'FAILED') {
      failJob(id, liveStatus.error || 'RunPod GPU job failed');
    } else if (liveStatus.status === 'IN_PROGRESS') {
      updateJobProgress(id, {
        status: 'running',
        step: 'synthesizing',
        progressPct: liveStatus.progress ?? 60,
      });
    }
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

