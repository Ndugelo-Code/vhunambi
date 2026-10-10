import { Hono } from 'hono';
import { z } from 'zod';
import {
  followCreator,
  getClipsByCreator,
  getFeed,
  likeClip,
  publishClip,
} from '../modules/social/social_service.js';

/**
 * Phase 18 · Social Creator Network REST router.
 *
 * Mounted at `/api` by `src/server.ts`, yielding the design.md §5 contract:
 *   POST /api/social/publish
 *   GET  /api/social/feed?cursor=&limit=
 *   POST /api/social/clips/:id/like
 *   GET  /api/creators/:id/clips
 *   POST /api/creators/:id/follow
 */
export const socialRoutes = new Hono();

const PublishClipSchema = z.object({
  trackId: z.string().min(1, 'trackId is required'),
  title: z.string().default('Untitled Clip'),
  caption: z.string().default(''),
  tags: z.array(z.string()).default([]),
  visibility: z.enum(['public', 'followers']).default('public'),
  dna: z.record(z.unknown()).default({}),
  creatorId: z.string().optional(),
  creatorUsername: z.string().optional(),
  creatorDisplayName: z.string().optional(),
  creatorAvatarUrl: z.string().optional(),
  isCreatorVerified: z.boolean().optional(),
  audioUrl: z.string().optional(),
  coverUrl: z.string().optional(),
});

// POST /api/social/publish — 1-tap in-house publish (REQ-SOC-01)
socialRoutes.post('/social/publish', async (c) => {
  try {
    const body = await c.req.json();
    const parsed = PublishClipSchema.safeParse(body);

    if (!parsed.success) {
      return c.json(
        { error: 'INVALID_REQUEST', details: parsed.error.flatten() },
        400,
      );
    }

    const result = publishClip(parsed.data);
    return c.json({ success: true, ...result }, 201);
  } catch (error) {
    console.error('[Social Publish Error]', error);
    return c.json(
      { error: 'PUBLISH_ERROR', message: 'Failed to publish clip' },
      500,
    );
  }
});

// GET /api/social/feed — cursor-paginated discovery feed (REQ-SOC-16 / REQ-SOC-22)
socialRoutes.get('/social/feed', (c) => {
  const cursor = c.req.query('cursor');
  const limit = Number.parseInt(c.req.query('limit') ?? '20', 10);
  const page = getFeed(cursor, Number.isFinite(limit) ? limit : 20);
  return c.json(page, 200);
});

// POST /api/social/clips/:id/like — optimistic like toggle (REQ-SOC-13 / REQ-SOC-24)
socialRoutes.post('/social/clips/:id/like', (c) => {
  const id = c.req.param('id');
  const result = likeClip(id);
  if (!result) {
    return c.json(
      { error: 'NOT_FOUND', message: `Clip ${id} not found` },
      404,
    );
  }
  return c.json(result, 200);
});

// GET /api/creators/:id/clips — creator reel grid source (REQ-SOC-23)
socialRoutes.get('/creators/:id/clips', (c) => {
  const id = c.req.param('id');
  return c.json({ clips: getClipsByCreator(id) }, 200);
});

// POST /api/creators/:id/follow — reactive follow toggle (REQ-SOC-08 / REQ-SOC-25)
socialRoutes.post('/creators/:id/follow', (c) => {
  const id = c.req.param('id');
  return c.json(followCreator(id), 200);
});
