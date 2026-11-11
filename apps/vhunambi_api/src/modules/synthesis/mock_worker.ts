import { extractWorkerEnv, resolveRuntimeEnv } from '../../config/env.js';
import type { VhunambiWorkerEnv } from '../../types/cloudflare_worker_types.js';
import { updateJobProgress, completeJob } from '../jobs/job_store.js';
import { broadcastGenerationEventToDo } from '../realtime/generation_session_do.js';
import { getPresignedGetUrl } from './r2_storage.js';

function getExecutionContext(
  cOrEnv?: unknown,
): { waitUntil?: (p: Promise<unknown>) => void } | undefined {
  if (!cOrEnv || typeof cOrEnv !== 'object') return undefined;
  try {
    const execCtx = (
      cOrEnv as { executionCtx?: { waitUntil?: (p: Promise<unknown>) => void } }
    ).executionCtx;
    if (execCtx && typeof execCtx.waitUntil === 'function') {
      return execCtx;
    }
  } catch {
    // Hono throws when Context has no Cloudflare ExecutionContext (Node tests)
  }
  return undefined;
}

function scheduleDelay(ms: number, unrefWhenNoExecCtx: boolean): Promise<void> {
  return new Promise((resolve) => {
    const timer = setTimeout(resolve, ms);
    if (unrefWhenNoExecCtx && typeof timer.unref === 'function') {
      timer.unref();
    }
  });
}

/**
 * High-fidelity local simulation worker.
 * Simulates RunPod ACE-Step inference lifecycle and broadcasts Durable Object
 * WebSocket events across all 4 stages.
 */
export function simulateSynthesisPipeline(
  generationId: string,
  cOrEnv?: unknown,
): Promise<void> {
  const execCtx = getExecutionContext(cOrEnv);
  const unrefWhenNoExecCtx = !execCtx;
  const workerEnv = extractWorkerEnv(
    cOrEnv as VhunambiWorkerEnv | Record<string, unknown> | undefined,
  );
  const runtimeEnv = resolveRuntimeEnv(cOrEnv as any);
  const stepMs = runtimeEnv.NODE_ENV === 'test' ? 25 : 1500;

  const pipelinePromise = (async () => {
    await scheduleDelay(stepMs, unrefWhenNoExecCtx);
    updateJobProgress(generationId, {
      status: 'running',
      step: 'synthesizing',
      progressPct: 35,
    });
    await broadcastGenerationEventToDo(workerEnv, {
      generationId,
      status: 'running',
      step: 'synthesizing',
      progressPct: 35,
    });

    await scheduleDelay(stepMs, unrefWhenNoExecCtx);
    updateJobProgress(generationId, {
      status: 'running',
      step: 'synthesizing',
      progressPct: 60,
    });
    await broadcastGenerationEventToDo(workerEnv, {
      generationId,
      status: 'running',
      step: 'synthesizing',
      progressPct: 60,
    });

    await scheduleDelay(stepMs, unrefWhenNoExecCtx);
    updateJobProgress(generationId, {
      status: 'running',
      step: 'separating_stems',
      progressPct: 85,
    });
    await broadcastGenerationEventToDo(workerEnv, {
      generationId,
      status: 'running',
      step: 'separating_stems',
      progressPct: 85,
    });

    await scheduleDelay(stepMs, unrefWhenNoExecCtx);
    const masterMp3Url = await getPresignedGetUrl(
      `${generationId}_master.mp3`,
      86400,
      cOrEnv as any,
    );
    const stemsZipUrl = await getPresignedGetUrl(
      `${generationId}_stems.zip`,
      86400,
      cOrEnv as any,
    );
    const stemUrls = {
      vocals: await getPresignedGetUrl(`${generationId}_vocals.mp3`, 86400, cOrEnv as any),
      drums: await getPresignedGetUrl(`${generationId}_drums.mp3`, 86400, cOrEnv as any),
      bass: await getPresignedGetUrl(`${generationId}_bass.mp3`, 86400, cOrEnv as any),
      melodic: await getPresignedGetUrl(`${generationId}_melodic.mp3`, 86400, cOrEnv as any),
    };

    completeJob(generationId, {
      masterMp3Url,
      stemsZipUrl,
      stemUrls,
      durationSec: 180,
    });
    await broadcastGenerationEventToDo(workerEnv, {
      generationId,
      status: 'succeeded',
      step: 'ready',
      progressPct: 100,
      masterMp3Url,
      stemsZipUrl,
      stemUrls,
    });
  })();

  if (execCtx?.waitUntil) {
    execCtx.waitUntil(pipelinePromise);
  }

  return pipelinePromise;
}
