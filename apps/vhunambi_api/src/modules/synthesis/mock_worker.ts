import { updateJobProgress, completeJob, failJob } from '../jobs/job_store.js';
import { getPresignedGetUrl } from './r2_storage.js';

/**
 * High-fidelity local simulation worker.
 * Simulates RunPod ACE-Step inference lifecycle:
 * 1. queued (0s -> 10%)
 * 2. synthesizing (2s -> 50%)
 * 3. separating_stems (4s -> 85%)
 * 4. ready (6s -> 100%)
 */
export function simulateSynthesisPipeline(generationId: string): void {
  // Stage 1: Queued -> Synthesizing
  setTimeout(() => {
    updateJobProgress(generationId, {
      status: 'running',
      step: 'synthesizing',
      progressPct: 35,
    });
  }, 1500);

  // Stage 2: Synthesizing halfway
  setTimeout(() => {
    updateJobProgress(generationId, {
      status: 'running',
      step: 'synthesizing',
      progressPct: 60,
    });
  }, 3000);

  // Stage 3: Stem Separation
  setTimeout(() => {
    updateJobProgress(generationId, {
      status: 'running',
      step: 'separating_stems',
      progressPct: 85,
    });
  }, 4500);

  // Stage 4: Succeeded & Master Ready
  setTimeout(async () => {
    const masterMp3Url = await getPresignedGetUrl(`${generationId}_master.mp3`);
    const stemsZipUrl = await getPresignedGetUrl(`${generationId}_stems.zip`);
    const stemUrls = {
      vocals: await getPresignedGetUrl(`${generationId}_vocals.mp3`),
      drums: await getPresignedGetUrl(`${generationId}_drums.mp3`),
      bass: await getPresignedGetUrl(`${generationId}_bass.mp3`),
      melodic: await getPresignedGetUrl(`${generationId}_melodic.mp3`),
    };

    completeJob(generationId, {
      masterMp3Url,
      stemsZipUrl,
      stemUrls,
      durationSec: 180,
    });
  }, 6000);
}
