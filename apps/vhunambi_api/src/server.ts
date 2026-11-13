import { Hono, type Context } from 'hono';
import { cors } from 'hono/cors';
import { extractWorkerEnv, resolveRuntimeEnv } from './config/env.js';
import type { VhunambiWorkerEnv } from './types/cloudflare_worker_types.js';
import {
  fetchR2S3Object,
  getInMemoryR2Object,
  uploadBytesToR2,
} from './modules/synthesis/r2_storage.js';
import { synthesizeAndCacheMissingR2Object } from './modules/synthesis/r2_media_synthesizer.js';
import {
  EdgePersistenceBridge,
  getEdgeIsolateDatabaseEngine,
  isNodeSqliteAvailable,
  vhunambiDb,
} from './db/vhunambi_db.js';
import { lyricsRoutes } from './routes/lyrics_routes.js';
import { generationRoutes } from './routes/generation_routes.js';
import { webhookRoutes } from './routes/webhook_routes.js';
import { socialRoutes } from './routes/social_routes.js';
import { visionRoutes } from './routes/vision_routes.js';
import { voiceRoutes } from './routes/voice_routes.js';
import { melodyRoutes } from './routes/melody_routes.js';
import { marketplaceRoutes } from './routes/marketplace_routes.js';
import { exploreRoutes } from './routes/explore_routes.js';
import { libraryRoutes } from './routes/library_routes.js';
import { playlistRoutes } from './routes/playlist_routes.js';
import { walletRoutes } from './routes/wallet_routes.js';
import { paymentRoutes } from './routes/payment_routes.js';
import { syncRoutes } from './routes/sync_routes.js';
import { authRoutes } from './routes/auth_routes.js';
import { systemRoutes } from './routes/system_routes.js';
import { countActiveJobs, getJob } from './modules/jobs/job_store.js';

/**
 * Hono application (routes + middleware only — no `serve()` side effects).
 *
 * Extracted from `src/index.ts` so tests can exercise endpoints through
 * `app.fetch(...)` without binding a port (Mission 4 / REQ-BE health check).
 * The process bootstrap lives in `index.ts`.
 */
export const app = new Hono<{ Bindings: VhunambiWorkerEnv }>();

// Enable CORS for Flutter web / desktop / local testing
app.use('*', cors());

// Bind active Worker Context for non-blocking Supabase write-through & cold-start hydration
app.use('*', async (c, next) => {
  EdgePersistenceBridge.setActiveContext(c);
  try {
    if (
      !isNodeSqliteAvailable() &&
      (c.req.path.startsWith('/api') || c.req.path.startsWith('/v1'))
    ) {
      await getEdgeIsolateDatabaseEngine().ensureColdStartHydrated(c);
    }
    return await next();
  } finally {
    EdgePersistenceBridge.setActiveContext(undefined);
  }
});

function inferContentType(key: string): string {
  const lower = key.toLowerCase();
  if (lower.endsWith('.wav')) return 'audio/wav';
  if (lower.endsWith('.mp3')) return 'audio/mpeg';
  if (lower.endsWith('.m4a')) return 'audio/mp4';
  if (lower.endsWith('.zip')) return 'application/zip';
  if (lower.endsWith('.json')) return 'application/json';
  if (lower.endsWith('.mp4')) return 'video/mp4';
  if (lower.endsWith('.bmp')) return 'image/bmp';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  return 'application/octet-stream';
}

function buildR2ByteResponse(
  req: Request,
  bytes: Uint8Array,
  contentType: string,
  etag?: string,
): Response {
  const total = bytes.byteLength;
  const headers: Record<string, string> = {
    'Content-Type': contentType,
    'Accept-Ranges': 'bytes',
    'Cache-Control': 'public, max-age=31536000, immutable',
  };
  if (etag) {
    headers.ETag = etag;
  }

  const rangeHeader = req.headers.get('range');
  if (rangeHeader && total > 0) {
    const match = /^bytes=(\d+)-(\d*)$/i.exec(rangeHeader.trim());
    if (match) {
      const start = Number.parseInt(match[1], 10);
      const rawEnd = match[2] ? Number.parseInt(match[2], 10) : total - 1;
      const end = Math.min(total - 1, Math.max(start, rawEnd));
      if (start < total && end >= start) {
        const sliced = bytes.subarray(start, end + 1);
        return new Response(sliced.slice().buffer as ArrayBuffer, {
          status: 206,
          headers: {
            ...headers,
            'Content-Range': `bytes ${start}-${end}/${total}`,
            'Content-Length': String(sliced.byteLength),
          },
        });
      }
    }
  }

  return new Response(bytes.slice().buffer as ArrayBuffer, {
    status: 200,
    headers: {
      ...headers,
      'Content-Length': String(total),
    },
  });
}

/**
 * Observability payload shared by `GET /health` and `GET /v1/health`.
 */
const healthPayload = (c?: Context<{ Bindings: VhunambiWorkerEnv }>) => {
  const runtimeEnv = resolveRuntimeEnv(c);
  const hasProcess = typeof process !== 'undefined';
  const uptimeSeconds =
    hasProcess && typeof process.uptime === 'function'
      ? Math.floor(process.uptime())
      : 0;
  const memoryMb =
    hasProcess && typeof process.memoryUsage === 'function'
      ? Math.round(process.memoryUsage().rss / 1024 / 1024)
      : 0;

  return {
    status: 'ok' as const,
    service: 'vhunambi_api',
    uptimeSeconds,
    memoryMb,
    environment: runtimeEnv.NODE_ENV,
    activeJobs: countActiveJobs(),
    timestamp: new Date().toISOString(),
  };
};

// Health Check (canonical + versioned aliases)
app.get('/health', (c) => c.json(healthPayload(c)));
app.get('/v1/health', (c) => c.json(healthPayload(c)));

// Zero-egress Cloudflare R2 Vault object upload & streaming
app.put('/r2/:key{.*}', async (c) => {
  const rawKey = c.req.param('key') ?? '';
  const cleanKey = rawKey.replace(/^\/+/, '');
  if (!cleanKey || cleanKey.includes('..')) {
    return c.json({ error: 'INVALID_R2_KEY' }, 400);
  }
  const contentType =
    c.req.header('content-type') || inferContentType(cleanKey);
  const arrayBuf = await c.req.arrayBuffer();
  const stored = await uploadBytesToR2(
    cleanKey,
    new Uint8Array(arrayBuf),
    contentType,
    c,
  );
  return c.json(
    {
      uploaded: true,
      key: stored.key,
      url: stored.url,
      etag: stored.etag,
      size: arrayBuf.byteLength,
      contentType,
    },
    200,
  );
});

app.get('/r2/:key{.*}', async (c) => {
  const rawKey = c.req.param('key') ?? '';
  const cleanKey = rawKey.replace(/^\/+/, '');
  if (!cleanKey || cleanKey.includes('..')) {
    return c.json({ error: 'INVALID_R2_KEY' }, 400);
  }

  const workerEnv = extractWorkerEnv(c) as VhunambiWorkerEnv | undefined;
  const rangeHeader = c.req.header('range');
  if (workerEnv?.VHUNAMBI_VAULT) {
    const obj = await workerEnv.VHUNAMBI_VAULT.get(cleanKey);
    if (obj) {
      const contentType =
        obj.httpMetadata?.contentType ?? inferContentType(cleanKey);
      if (rangeHeader) {
        const bytes = new Uint8Array(await obj.arrayBuffer());
        return buildR2ByteResponse(c.req.raw, bytes, contentType, obj.etag);
      }
      const headers = new Headers();
      headers.set('Content-Type', contentType);
      headers.set(
        'Cache-Control',
        obj.httpMetadata?.cacheControl ?? 'public, max-age=31536000, immutable',
      );
      headers.set('Accept-Ranges', 'bytes');
      if (typeof obj.size === 'number') {
        headers.set('Content-Length', String(obj.size));
      }
      if (obj.etag) {
        headers.set('ETag', obj.etag);
      }
      const body = obj.body ?? (await obj.arrayBuffer());
      return new Response(body, { status: 200, headers });
    }
  }

  const memObj = getInMemoryR2Object(cleanKey);
  if (memObj) {
    return buildR2ByteResponse(
      c.req.raw,
      memObj.bytes,
      memObj.contentType || inferContentType(cleanKey),
      memObj.etag,
    );
  }

  const s3Res = await fetchR2S3Object(cleanKey, c);
  if (s3Res && s3Res.ok) {
    const headers = new Headers(s3Res.headers);
    if (!headers.has('Content-Type')) {
      headers.set('Content-Type', inferContentType(cleanKey));
    }
    headers.set('Accept-Ranges', 'bytes');
    if (!headers.has('Cache-Control')) {
      headers.set('Cache-Control', 'public, max-age=31536000, immutable');
    }
    return new Response(s3Res.body, { status: s3Res.status, headers });
  }

  // Read-through synthesizer when object does not yet exist in R2
  const synthesized = await synthesizeAndCacheMissingR2Object(cleanKey, c);
  return buildR2ByteResponse(
    c.req.raw,
    synthesized.bytes,
    synthesized.contentType,
  );
});

// Durable Object WebSocket bridge & HTTP metadata fallback for /ws/generation
app.get('/ws/generation', async (c) => {
  const generationId = c.req.query('id') || 'default';
  const workerEnv = extractWorkerEnv(c) as VhunambiWorkerEnv | undefined;
  if (workerEnv?.GENERATION_DO) {
    const id = workerEnv.GENERATION_DO.idFromName(generationId);
    const stub = workerEnv.GENERATION_DO.get(id);
    return stub.fetch(c.req.raw);
  }
  const job = vhunambiDb.getGenerationJob(generationId) ?? getJob(generationId);
  return c.json({
    generationId,
    protocol: 'vhunambi_generation_ws_v1',
    status: job?.status ?? 'unknown',
    step: job?.step ?? null,
    progressPct: job?.progressPct ?? 0,
    job: job ?? null,
  });
});

// Mock Storage static server for local development audio files
app.get('/mock-storage/:filename', (c) => {
  const filename = c.req.param('filename');
  return c.text(`Mock Audio Binary Content for ${filename}`, 200, {
    'Content-Type': filename.endsWith('.zip') ? 'application/zip' : 'audio/mpeg',
    'Content-Disposition': `attachment; filename="${filename}"`,
  });
});

// Mount /v1 Routes
app.route('/v1/lyrics', lyricsRoutes);
app.route('/v1/generations', generationRoutes);
app.route('/v1/webhooks', webhookRoutes);
app.route('/v1/vision', visionRoutes);
app.route('/v1/voices', voiceRoutes);
app.route('/v1/melodies', melodyRoutes);

// Mount Phase 61 Sovereign Identity & Authentication routes BEFORE broad /api routers
app.route('/v1/auth', authRoutes);
app.route('/api/auth', authRoutes);
app.route('/api/v1/auth', authRoutes);

// Mount Phase 18 Social Creator Network routes (/api/social/*, /api/creators/*)
app.route('/api', socialRoutes);

// Mount Phase 28 Beats Marketplace & Licensing routes (/api/marketplace/*)
app.route('/api/marketplace', marketplaceRoutes);

// Mount Phase 45 / Phase 59 SQLite Persistence & Delta Sync routes
app.route('/api/explore', exploreRoutes);
app.route('/api/v1/explore', exploreRoutes);
app.route('/api/library', libraryRoutes);
app.route('/api/v1/library', libraryRoutes);
app.route('/api/playlists', playlistRoutes);
app.route('/api/v1/playlists', playlistRoutes);
app.route('/api/wallet', walletRoutes);
app.route('/api/v1/wallet', walletRoutes);
app.route('/api/payments', paymentRoutes);
app.route('/api/v1/payments', paymentRoutes);
app.route('/api/sync', syncRoutes);
app.route('/api/v1/sync', syncRoutes);

// Mount Phase 63 5-Pillar Cloud Stack Preflight routes
app.route('/api/system', systemRoutes);
app.route('/api/v1/system', systemRoutes);
app.route('/v1/system', systemRoutes);

// Phase 65 (REQ-P65-L5-01): Global JSON Error & NotFound Boundaries
app.onError((err, c) => {
  const statusCandidate =
    (err as { status?: number; statusCode?: number })?.status ??
    (err as { statusCode?: number })?.statusCode ??
    500;
  const status =
    statusCandidate >= 400 && statusCandidate < 600 ? statusCandidate : 500;
  const errorCode =
    (err as { code?: string })?.code ??
    (status === 400
      ? 'BAD_REQUEST'
      : status === 401
        ? 'UNAUTHORIZED'
        : status === 403
          ? 'FORBIDDEN'
          : status === 404
            ? 'NOT_FOUND'
            : 'INTERNAL_SERVER_ERROR');

  c.header('Access-Control-Allow-Origin', '*');
  return c.json(
    {
      success: false,
      status: 'error',
      code: errorCode,
      error: err.message || 'Unhandled server error',
      errorCode,
      message: err.message || 'Unhandled server error',
      path: c.req.path,
      timestamp: new Date().toISOString(),
    },
    status as 500,
  );
});

app.notFound((c) => {
  c.header('Access-Control-Allow-Origin', '*');
  return c.json(
    {
      success: false,
      status: 'error',
      code: 'NOT_FOUND',
      error: `Route not found: ${c.req.method} ${c.req.path}`,
      errorCode: 'NOT_FOUND',
      message: `Route not found: ${c.req.method} ${c.req.path}`,
      path: c.req.path,
      timestamp: new Date().toISOString(),
    },
    404,
  );
});
