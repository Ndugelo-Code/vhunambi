import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { env } from './config/env.js';
import { lyricsRoutes } from './routes/lyrics_routes.js';
import { generationRoutes } from './routes/generation_routes.js';
import { webhookRoutes } from './routes/webhook_routes.js';
import { socialRoutes } from './routes/social_routes.js';
import { visionRoutes } from './routes/vision_routes.js';
import { countActiveJobs } from './modules/jobs/job_store.js';

/**
 * Hono application (routes + middleware only — no `serve()` side effects).
 *
 * Extracted from `src/index.ts` so tests can exercise endpoints through
 * `app.fetch(...)` without binding a port (Mission 4 / REQ-BE health check).
 * The process bootstrap lives in `index.ts`.
 */
export const app = new Hono();

// Enable CORS for Flutter web / desktop / local testing
app.use('*', cors());

/**
 * Observability payload shared by `GET /health` and `GET /v1/health`.
 *
 * - `uptimeSeconds` — seconds since the process booted (`process.uptime()`).
 * - `memoryMb`      — resident set size in MiB (`process.memoryUsage().rss`).
 * - `environment`   — `NODE_ENV` (`development` outside production).
 * - `activeJobs`    — synthesis jobs still `queued` or `running` in the store.
 */
const healthPayload = () => ({
  status: 'ok' as const,
  service: 'vhunambi_api',
  uptimeSeconds: Math.floor(process.uptime()),
  memoryMb: Math.round(process.memoryUsage().rss / 1024 / 1024),
  environment: env.NODE_ENV,
  activeJobs: countActiveJobs(),
  timestamp: new Date().toISOString(),
});

// Health Check (canonical + versioned aliases)
app.get('/health', (c) => c.json(healthPayload()));
app.get('/v1/health', (c) => c.json(healthPayload()));

// Mock Storage static server for local development audio files
app.get('/mock-storage/:filename', (c) => {
  const filename = c.req.param('filename');
  // Return a mock audio response header
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

// Mount Phase 18 Social Creator Network routes (/api/social/*, /api/creators/*)
app.route('/api', socialRoutes);