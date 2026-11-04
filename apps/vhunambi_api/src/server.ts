import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { env } from './config/env.js';
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
import { walletRoutes } from './routes/wallet_routes.js';
import { syncRoutes } from './routes/sync_routes.js';
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

// Mount Phase 18 Social Creator Network routes (/api/social/*, /api/creators/*)
app.route('/api', socialRoutes);

// Mount Phase 28 Beats Marketplace & Licensing routes (/api/marketplace/*)
app.route('/api/marketplace', marketplaceRoutes);

// Mount Phase 45 SQLite Persistence & Delta Sync routes (REQ-P45-EXP, REQ-P45-LIB, REQ-P45-WAL, REQ-P45-SYNC)
app.route('/api/explore', exploreRoutes);
app.route('/api/v1/explore', exploreRoutes);
app.route('/api/library', libraryRoutes);
app.route('/api/v1/library', libraryRoutes);
app.route('/api/wallet', walletRoutes);
app.route('/api/v1/wallet', walletRoutes);
app.route('/api/sync', syncRoutes);
app.route('/api/v1/sync', syncRoutes);
