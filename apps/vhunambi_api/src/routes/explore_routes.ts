import { Hono } from 'hono';
import { vhunambiDb } from '../db/vhunambi_db.js';
import {
  assertTenantCreatorAccess,
  resolveEffectiveCreatorId,
  sovereignAuthMiddleware,
} from '../middleware/auth_middleware.js';

export const exploreRoutes = new Hono();

exploreRoutes.use('*', sovereignAuthMiddleware);

// GET /api/explore — Unified Explore discovery bundle (tracks + kinetic posts + radio)
exploreRoutes.get('/', (c) => {
  const stage = c.req.query('stage') as any;
  const genre = c.req.query('genre');
  const limit = c.req.query('limit') ? parseInt(c.req.query('limit')!, 10) : 50;
  const offset = c.req.query('offset') ? parseInt(c.req.query('offset')!, 10) : 0;

  const bundle = vhunambiDb.getExploreDiscoveryBundle({ stage, genre, limit, offset });
  return c.json({ success: true, ...bundle });
});

// GET /api/explore/tracks — Dynamic African track catalog with stage & trending ranking
exploreRoutes.get('/tracks', (c) => {
  const genre = c.req.query('genre');
  const stage = c.req.query('stage');
  const sort = (c.req.query('sort') as any) || 'trending';
  const search = c.req.query('search');
  const limit = c.req.query('limit') ? parseInt(c.req.query('limit')!, 10) : 50;

  const result = vhunambiDb.getExploreTracks({ genre, stage, sort, search, limit });
  return c.json({
    success: true,
    items: result.items,
    tracks: result.items,
    total: result.total,
    serverSeq: result.serverSeq,
  });
});

// POST /api/explore/tracks — Publish or update a track in the Explore catalog
exploreRoutes.post('/tracks', async (c) => {
  try {
    const body = await c.req.json();
    if (!body?.title || String(body.title).trim() === '') {
      return c.json({ success: false, error: 'Track title is required' }, 400);
    }
    const forbidden = assertTenantCreatorAccess(c, body.creatorId);
    if (forbidden) return forbidden;

    const authUser = c.get('authUser');
    const track = vhunambiDb.upsertExploreTrack({
      ...body,
      creatorId: authUser
        ? resolveEffectiveCreatorId(c, body.creatorId, authUser.creatorId)
        : body.creatorId,
    });
    return c.json({ success: true, track }, 201);
  } catch (err: any) {
    return c.json({ success: false, error: err?.message || 'Invalid JSON body' }, 400);
  }
});

// GET /api/explore/radio/:genre — Genre radio harmonic rotation
exploreRoutes.get('/radio/:genre', (c) => {
  const genre = decodeURIComponent(c.req.param('genre'));
  const limit = c.req.query('limit') ? parseInt(c.req.query('limit')!, 10) : 20;
  const radio = vhunambiDb.getExploreRadioRotation(genre, limit);
  return c.json({ success: true, ...radio });
});

// GET /api/explore/feed (REQ-P45-EXP-01..02)
exploreRoutes.get('/feed', (c) => {
  const stage = c.req.query('stage') as any;
  const genre = c.req.query('genre');
  const limit = c.req.query('limit') ? parseInt(c.req.query('limit')!, 10) : 20;
  const offset = c.req.query('offset') ? parseInt(c.req.query('offset')!, 10) : 0;

  const result = vhunambiDb.getExploreFeed({ stage, genre, limit, offset });
  return c.json(result);
});

// POST /api/explore/posts/:id/cosign (REQ-P45-EXP-04..05)
exploreRoutes.post('/posts/:id/cosign', async (c) => {
  const postId = c.req.param('id');
  let body: any = {};
  try {
    body = await c.req.json();
  } catch (_) { }

  const forbidden = assertTenantCreatorAccess(c, body.creatorId);
  if (forbidden) return forbidden;

  const effectiveCreatorId = resolveEffectiveCreatorId(
    c,
    body.creatorId,
    'creator_cern',
  );
  const result = vhunambiDb.cosignPost(postId, effectiveCreatorId);
  if (!result.success) {
    return c.json({ error: 'Post not found', postId }, 404);
  }
  return c.json(result);
});

// POST /api/explore/posts/:id/repost (REQ-P45-EXP-06)
exploreRoutes.post('/posts/:id/repost', (c) => {
  const postId = c.req.param('id');
  const result = vhunambiDb.repostPost(postId);
  if (!result.success) {
    return c.json({ error: 'Post not found', postId }, 404);
  }
  return c.json(result);
});

