import { Hono } from 'hono';
import crypto from 'node:crypto';
import { env } from '../config/env.js';
import { updateJobProgress, completeJob, failJob } from '../modules/jobs/job_store.js';

export const webhookRoutes = new Hono();

webhookRoutes.post('/ace-step', async (c) => {
  const signature = c.req.header('x-zrs-signature');
  const rawBody = await c.req.text();

  // HMAC-SHA256 verification
  if (env.ZR_WEBHOOK_SECRET) {
    const expectedSignature = crypto
      .createHmac('sha256', env.ZR_WEBHOOK_SECRET)
      .update(rawBody)
      .digest('hex');

    if (signature !== expectedSignature) {
      console.warn('[Webhook] HMAC signature mismatch');
      return c.json({ error: 'UNAUTHORIZED', message: 'Invalid webhook signature' }, 401);
    }
  }

  try {
    const payload = JSON.parse(rawBody);
    const { job_id, status, progress, result, error } = payload;

    if (!job_id) {
      return c.json({ error: 'BAD_REQUEST', message: 'Missing job_id' }, 400);
    }

    if (status === 'running') {
      updateJobProgress(job_id, {
        status: 'running',
        step: progress?.pct > 60 ? 'separating_stems' : 'synthesizing',
        progressPct: progress?.pct || 50,
      });
    } else if (status === 'succeeded') {
      completeJob(job_id, {
        masterMp3Url: result?.audio_url || '',
        stemsZipUrl: result?.stems_url,
        durationSec: result?.duration_sec,
      });
    } else if (status === 'failed') {
      failJob(job_id, error?.message || 'Synthesis failed');
    }

    return c.json({ received: true });
  } catch (err) {
    return c.json({ error: 'PARSE_ERROR', message: 'Invalid JSON payload' }, 400);
  }
});
