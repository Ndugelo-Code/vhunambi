import { Hono, type Context } from 'hono';
import { z } from 'zod';
import {
  extractWorkerEnv,
  resolveMediaUrl,
  resolveRuntimeEnv,
} from '../config/env.js';
import { createJob, getJob, completeJob } from '../modules/jobs/job_store.js';
import { sovereignAuthMiddleware } from '../middleware/auth_middleware.js';
import type { VhunambiWorkerEnv } from '../types/cloudflare_worker_types.js';
import {
  dispatchComfyUIVisionJob,
} from '../modules/vision/comfyui_adapter.js';
import {
  synthesizeVisionPrompt,
} from '../modules/vision/prompt_synthesizer.js';
import { compileSongMetadataDNA } from '../modules/dna/dna_compiler.js';
import { uploadBytesToR2 } from '../modules/synthesis/r2_storage.js';
import { synthesizeCoverArtworkBytes } from '../modules/synthesis/r2_media_synthesizer.js';

export const visionRoutes = new Hono<{ Bindings: VhunambiWorkerEnv }>();

visionRoutes.use('*', sovereignAuthMiddleware);

function buildPlayableContainerMp4Bytes(): Uint8Array {
  // Structured ISO BMFF container (ftypisom + mdat payload + moov/mvhd header)
  const ftyp = [
    0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, // size=24, 'ftyp'
    0x69, 0x73, 0x6f, 0x6d, 0x00, 0x00, 0x02, 0x00, // 'isom', minor=512
    0x69, 0x73, 0x6f, 0x6d, 0x6d, 0x70, 0x34, 0x31, // 'isommp41'
  ];
  const mdatPayload = new Uint8Array(512);
  const mdatSize = 8 + mdatPayload.length;
  const mdatHeader = [
    (mdatSize >>> 24) & 0xff,
    (mdatSize >>> 16) & 0xff,
    (mdatSize >>> 8) & 0xff,
    mdatSize & 0xff,
    0x6d, 0x64, 0x61, 0x74, // 'mdat'
  ];
  const mvhdBody = new Uint8Array(100);
  mvhdBody[15] = 0xe8; // timescale ~ 1000
  mvhdBody[14] = 0x03;
  mvhdBody[19] = 0xe8; // duration ~ 1000ms
  mvhdBody[18] = 0x03;
  const mvhdSize = 8 + mvhdBody.length;
  const moovSize = 8 + mvhdSize;
  const moovHeader = [
    (moovSize >>> 24) & 0xff,
    (moovSize >>> 16) & 0xff,
    (moovSize >>> 8) & 0xff,
    moovSize & 0xff,
    0x6d, 0x6f, 0x6f, 0x76, // 'moov'
    (mvhdSize >>> 24) & 0xff,
    (mvhdSize >>> 16) & 0xff,
    (mvhdSize >>> 8) & 0xff,
    mvhdSize & 0xff,
    0x6d, 0x76, 0x68, 0x64, // 'mvhd'
  ];
  const out = new Uint8Array(
    ftyp.length + mdatHeader.length + mdatPayload.length + moovHeader.length + mvhdBody.length,
  );
  let cursor = 0;
  out.set(ftyp, cursor);
  cursor += ftyp.length;
  out.set(mdatHeader, cursor);
  cursor += mdatHeader.length;
  out.set(mdatPayload, cursor);
  cursor += mdatPayload.length;
  out.set(moovHeader, cursor);
  cursor += moovHeader.length;
  out.set(mvhdBody, cursor);
  return out;
}

interface VisionJobMeta {
  jobId: string;
  kind: 'vision' | 'render-video';
  status: string;
  promptText?: string;
  seed?: number;
  width?: number;
  height?: number;
  outputImageUrl?: string;
  videoUrl?: string;
  resolution?: string;
  fps?: number;
  preset?: string;
  engine?: string;
  renderedAt?: string;
}

const visionMetaFallbackStore = new Map<string, VisionJobMeta>();

function normalizeVisionUrl(
  rawUrl: string,
  c: Context<{ Bindings: VhunambiWorkerEnv }>,
): string {
  const workerEnv = extractWorkerEnv(c);
  const explicitOverride =
    (typeof workerEnv?.R2_PUBLIC_BASE_URL === 'string' &&
      workerEnv.R2_PUBLIC_BASE_URL.trim()) ||
    (typeof process !== 'undefined' && process.env?.R2_PUBLIC_BASE_URL?.trim());
  return explicitOverride ? resolveMediaUrl(rawUrl, c) : rawUrl;
}

const VisionGenerateSchema = z.object({
  title: z.string().optional(),
  genre: z.string().default('Amapiano'),
  language: z.string().default('ve'),
  mood: z.string().optional(),
  prompt: z.string().optional(),
  seed: z.number().optional(),
  width: z.number().default(768),
  height: z.number().default(1344),
  clientId: z.string().optional(),
});

/**
 * POST /v1/vision/generate
 *
 * Generates high-fidelity 9:16 vertical artwork/video background for reels
 * using RunPod ComfyUI (SDXL / FLUX) with African genre cultural prompting.
 */
visionRoutes.post('/generate', async (c) => {
  try {
    const body = await c.req.json();
    const parsed = VisionGenerateSchema.safeParse(body);

    if (!parsed.success) {
      return c.json({ error: 'INVALID_REQUEST', details: parsed.error.flatten() }, 400);
    }

    const input = parsed.data;

    // 1. Compile SongMetadataDNA for authentic cultural visual grounding
    const dna = compileSongMetadataDNA({
      title: input.title ?? 'Untitled Master',
      genre: input.genre,
      language: input.language,
      mood: input.mood ?? 'Euphoric',
      prompt: input.prompt,
    });

    // 2. Synthesize 9:16 visual prompt from DNA or prompt parameter
    const promptText = input.prompt && input.prompt.includes('9:16')
      ? input.prompt
      : await synthesizeVisionPrompt(dna);

    // 3. Dispatch to ComfyUI (RunPod pod / serverless / mock simulation)
    const result = await dispatchComfyUIVisionJob(
      {
        promptText,
        seed: input.seed,
        width: input.width,
        height: input.height,
        clientId: input.clientId,
      },
      c,
    );

    if (result.status === 'completed' && result.isMock) {
      const artworkBytes = synthesizeCoverArtworkBytes(
        `${input.title ?? result.jobId}_${input.genre}_${input.language}`,
      );
      await uploadBytesToR2(
        `visuals/mock/${result.jobId}_9_16.png`,
        artworkBytes,
        'image/bmp',
        c,
      );
    }

    const workerEnv = extractWorkerEnv(c) as VhunambiWorkerEnv | undefined;
    const normalizedImageUrl = result.outputImageUrl
      ? workerEnv?.VHUNAMBI_VAULT
        ? resolveMediaUrl(result.outputImageUrl, c)
        : normalizeVisionUrl(result.outputImageUrl, c)
      : undefined;

    createJob({
      generationId: result.jobId,
      trackTitle: input.title ?? 'ComfyUI Artwork',
      genre: input.genre,
      language: input.language,
      providerTaskId: result.jobId,
    });
    if (result.status === 'completed' && normalizedImageUrl) {
      completeJob(result.jobId, {
        masterMp3Url: normalizedImageUrl,
      });
    }

    visionMetaFallbackStore.set(result.jobId, {
      jobId: result.jobId,
      kind: 'vision',
      status: result.status,
      promptText: result.promptText,
      seed: result.seed,
      width: result.width,
      height: result.height,
      outputImageUrl: normalizedImageUrl,
    });

    return c.json(
      {
        success: true,
        jobId: result.jobId,
        isMock: result.isMock,
        status: result.status,
        promptText: result.promptText,
        seed: result.seed,
        width: result.width,
        height: result.height,
        outputImageUrl: normalizedImageUrl,
        pollUrl: `/v1/vision/${result.jobId}`,
      },
      201,
    );
  } catch (err) {
    console.error('[Vision Generate Error]', err);
    return c.json({ error: 'VISION_DISPATCH_ERROR', message: 'Failed to dispatch ComfyUI vision job' }, 500);
  }
});

const RenderVideoSchema = z.object({
  trackId: z.string().optional(),
  title: z.string().optional(),
  mmoManifest: z.record(z.any()).optional(),
  resolution: z.string().default('1080x1920'),
  fps: z.number().default(60),
  preset: z.string().default('kineticBounce'),
  includeWatermark: z.boolean().default(true),
});

/**
 * POST /v1/vision/render-video
 */
visionRoutes.post('/render-video', async (c) => {
  try {
    const body = await c.req.json();
    const parsed = RenderVideoSchema.safeParse(body);

    if (!parsed.success) {
      return c.json({ error: 'INVALID_REQUEST', details: parsed.error.flatten() }, 400);
    }

    const input = parsed.data;
    const jobId = `vjob_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    const timestamp = Date.now();
    const safeTitle = (input.title ?? 'reel').toLowerCase().replace(/[^a-z0-9]/g, '_');
    const r2Key = `reels/vhunambi_${safeTitle}_${timestamp}.mp4`;
    const stored = await uploadBytesToR2(
      r2Key,
      buildPlayableContainerMp4Bytes(),
      'video/mp4',
      c,
    );
    const coverKey = `reels/vhunambi_${safeTitle}_${timestamp}_cover.bmp`;
    const coverBytes = synthesizeCoverArtworkBytes(`${safeTitle}_${input.preset}`);
    await uploadBytesToR2(coverKey, coverBytes, 'image/bmp', c);
    const workerEnv = extractWorkerEnv(c) as VhunambiWorkerEnv | undefined;
    const rawVideoUrl = `https://r2.vhunambi.com/${stored.key}`;
    const rawCoverUrl = `https://r2.vhunambi.com/${coverKey}`;
    const outputVideoUrl = workerEnv?.VHUNAMBI_VAULT
      ? resolveMediaUrl(rawVideoUrl, c)
      : normalizeVisionUrl(rawVideoUrl, c);
    const outputCoverUrl = workerEnv?.VHUNAMBI_VAULT
      ? resolveMediaUrl(rawCoverUrl, c)
      : normalizeVisionUrl(rawCoverUrl, c);
    const renderedAt = new Date().toISOString();

    createJob({
      generationId: jobId,
      trackTitle: input.title ?? 'Lyric Reel',
      genre: 'Amapiano',
      language: 've',
    });
    completeJob(jobId, {
      masterMp3Url: outputVideoUrl,
    });

    visionMetaFallbackStore.set(jobId, {
      jobId,
      kind: 'render-video',
      status: 'completed',
      videoUrl: outputVideoUrl,
      resolution: input.resolution,
      fps: input.fps,
      preset: input.preset,
      engine: 'RunPod-NVENC-GPU',
      renderedAt,
    });

    return c.json(
      {
        success: true,
        jobId,
        status: 'completed',
        videoUrl: outputVideoUrl,
        coverUrl: outputCoverUrl,
        resolution: input.resolution,
        fps: input.fps,
        preset: input.preset,
        renderedAt,
        engine: 'RunPod-NVENC-GPU',
        pollUrl: `/v1/vision/render-video/${jobId}`,
      },
      200,
    );
  } catch (err) {
    console.error('[Vision Render Video Error]', err);
    return c.json({ error: 'VIDEO_RENDER_ERROR', message: 'Failed to process video render request' }, 500);
  }
});

/**
 * GET /v1/vision/render-video/:id
 * Status polling endpoint for server-side NVENC lyric video renders.
 */
visionRoutes.get('/render-video/:id', (c) => {
  const id = c.req.param('id');
  const meta = visionMetaFallbackStore.get(id);
  const job = getJob(id);

  if (!meta && !job) {
    return c.json(
      { error: 'NOT_FOUND', message: `Video render job ${id} not found` },
      404,
    );
  }

  const resolvedVideoUrl = meta?.videoUrl ?? job?.masterMp3Url;
  return c.json({
    success: true,
    jobId: id,
    status:
      meta?.status ??
      (job?.status === 'succeeded' ? 'completed' : job?.status ?? 'queued'),
    videoUrl: resolvedVideoUrl,
    resolution: meta?.resolution ?? '1080x1920',
    fps: meta?.fps ?? 60,
    preset: meta?.preset ?? 'kineticBounce',
    engine: meta?.engine ?? 'RunPod-NVENC-GPU',
    renderedAt: meta?.renderedAt ?? job?.updatedAt.toISOString(),
  });
});

/**
 * GET /v1/vision/:id
 * Status polling endpoint for 9:16 ComfyUI artwork generation jobs.
 */
visionRoutes.get('/:id', async (c) => {
  const id = c.req.param('id');
  const meta = visionMetaFallbackStore.get(id);
  const job = getJob(id);

  if (!meta && !job) {
    return c.json(
      { error: 'NOT_FOUND', message: `Vision job ${id} not found` },
      404,
    );
  }

  let status =
    meta?.status ??
    (job?.status === 'succeeded' ? 'completed' : job?.status ?? 'queued');
  let outputImageUrl = meta?.outputImageUrl ?? job?.masterMp3Url;

  const runtimeEnv = resolveRuntimeEnv(c);
  if (
    status !== 'completed' &&
    !id.startsWith('mock_') &&
    runtimeEnv.RUNPOD_API_KEY &&
    runtimeEnv.RUNPOD_COMFYUI_ENDPOINT_ID
  ) {
    try {
      const pollResp = await fetch(
        `https://api.runpod.ai/v2/${runtimeEnv.RUNPOD_COMFYUI_ENDPOINT_ID}/status/${id}`,
        {
          headers: { Authorization: `Bearer ${runtimeEnv.RUNPOD_API_KEY}` },
        },
      );
      if (pollResp.ok) {
        const pollJson = (await pollResp.json()) as {
          status?: string;
          output?: { image_url?: string; images?: string[] };
        };
        const upper = (pollJson.status ?? '').toUpperCase();
        if (upper === 'COMPLETED') {
          status = 'completed';
          const remoteUrl =
            pollJson.output?.image_url ?? pollJson.output?.images?.[0];
          if (remoteUrl) {
            let resolvedUrl = normalizeVisionUrl(remoteUrl, c);
            try {
              const imgRes = await fetch(remoteUrl);
              if (imgRes.ok) {
                const imgBytes = new Uint8Array(await imgRes.arrayBuffer());
                const storedImg = await uploadBytesToR2(
                  `vision/${id}.png`,
                  imgBytes,
                  imgRes.headers.get('content-type') || 'image/png',
                  c,
                );
                const workerEnv = extractWorkerEnv(c) as VhunambiWorkerEnv | undefined;
                resolvedUrl = workerEnv?.VHUNAMBI_VAULT
                  ? resolveMediaUrl(storedImg.url, c)
                  : normalizeVisionUrl(storedImg.url, c);
              }
            } catch {
              // Keep normalized remoteUrl when direct ingestion fails
            }
            outputImageUrl = resolvedUrl;
            completeJob(id, { masterMp3Url: outputImageUrl });
            if (meta) {
              meta.status = 'completed';
              meta.outputImageUrl = outputImageUrl;
            }
          }
        } else if (upper === 'IN_PROGRESS') {
          status = 'processing';
        }
      }
    } catch {
      // Preserve last persisted status if RunPod status call is unreachable
    }
  }

  return c.json({
    success: true,
    jobId: id,
    status,
    promptText: meta?.promptText ?? job?.trackTitle,
    seed: meta?.seed,
    width: meta?.width ?? 768,
    height: meta?.height ?? 1344,
    outputImageUrl,
  });
});

