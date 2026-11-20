import { Hono } from 'hono';
import { vhunambiDb } from '../db/vhunambi_db.js';
import {
  assertTenantCreatorAccess,
  resolveEffectiveCreatorId,
  sovereignAuthMiddleware,
} from '../middleware/auth_middleware.js';
import { normalizeVhunambiMoodId } from '../utils/mood_taxonomy.js';

export const exploreRoutes = new Hono();

exploreRoutes.use('*', sovereignAuthMiddleware);

// GET /api/explore — Unified Explore discovery bundle (tracks + kinetic posts + radio)
exploreRoutes.get('/', async (c) => {
  await vhunambiDb.syncExploreFromCloud(false, c);
  const stage = c.req.query('stage') as any;
  const genre = c.req.query('genre');
  const limit = c.req.query('limit') ? parseInt(c.req.query('limit')!, 10) : 50;
  const offset = c.req.query('offset') ? parseInt(c.req.query('offset')!, 10) : 0;

  const bundle = vhunambiDb.getExploreDiscoveryBundle({ stage, genre, limit, offset });
  return c.json({ success: true, ...bundle });
});

// GET /api/explore/tracks — Dynamic African track catalog with stage & trending ranking
exploreRoutes.get('/tracks', async (c) => {
  await vhunambiDb.syncExploreFromCloud(false, c);
  const genre = c.req.query('genre');
  const stage = c.req.query('stage');
  const sort = (c.req.query('sort') as any) || 'trending';
  const search = c.req.query('search');
  const rawMood = c.req.query('moodId') || c.req.query('mood');
  const moodId =
    rawMood && rawMood.trim() !== '' && rawMood.trim().toLowerCase() !== 'all'
      ? normalizeVhunambiMoodId(rawMood)
      : undefined;
  const limit = c.req.query('limit') ? parseInt(c.req.query('limit')!, 10) : 50;

  const result = vhunambiDb.getExploreTracks({
    genre,
    stage,
    sort,
    search,
    moodId,
    limit,
  });
  const normalizedItems = result.items.map((t) => ({
    ...t,
    moodId: normalizeVhunambiMoodId(t.moodId ?? t.mood),
    description: t.description ?? '',
    allowOpenStemsRemix: Boolean(t.allowOpenStemsRemix),
  }));
  return c.json({
    success: true,
    items: normalizedItems,
    tracks: normalizedItems,
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
exploreRoutes.get('/feed', async (c) => {
  await vhunambiDb.syncExploreFromCloud(false, c);
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

// POST /api/explore/posts/:id/repost (REQ-P45-EXP-06 + Phase 69 quote repost upsert)
exploreRoutes.post('/posts/:id/repost', async (c) => {
  const postId = c.req.param('id');
  let body: any = {};
  try {
    body = await c.req.json();
  } catch (_) { }
  const repostPayload =
    body?.repost && typeof body.repost === 'object'
      ? (body.repost as Record<string, any>)
      : undefined;
  const result = vhunambiDb.repostPost(postId, repostPayload);
  if (!result.success) {
    return c.json({ error: 'Post not found', postId }, 404);
  }
  return c.json(result);
});

// GET /api/explore/posts/:id — Single Kinetic Post lookup (Phase 69 REQ-P69-API-01)
exploreRoutes.get('/posts/:id', async (c) => {
  const postId = c.req.param('id');
  await vhunambiDb.syncExploreFromCloud(false, c);
  let post = vhunambiDb.getKineticPostById(postId);
  if (!post) {
    await vhunambiDb.syncExploreFromCloud(true, c);
    post = vhunambiDb.getKineticPostById(postId);
  }
  if (!post) {
    return c.json({ error: 'Post not found', postId }, 404);
  }
  return c.json({ success: true, post });
});

// POST /api/explore/posts — Publish or upsert a Kinetic Post (Phase 69 REQ-P69-API-01)
exploreRoutes.post('/posts', async (c) => {
  try {
    const body = await c.req.json();
    const forbidden = assertTenantCreatorAccess(c, body?.creatorId);
    if (forbidden) return forbidden;
    const authUser = c.get('authUser');
    const post = vhunambiDb.upsertKineticPost({
      ...body,
      creatorId: authUser
        ? resolveEffectiveCreatorId(c, body?.creatorId, authUser.creatorId)
        : body?.creatorId,
      creatorHandle:
        body?.creatorHandle || (authUser ? authUser.handle : '@cern'),
    });
    return c.json({ success: true, post }, 201);
  } catch (err: any) {
    return c.json({ success: false, error: err?.message || 'Invalid JSON' }, 400);
  }
});

// POST /api/explore/posts/:id/like — Optimistic post like toggle (Phase 69 REQ-P69-API-01)
exploreRoutes.post('/posts/:id/like', async (c) => {
  const postId = c.req.param('id');
  let body: any = {};
  try {
    body = await c.req.json();
  } catch (_) { }
  const effectiveCreatorId = resolveEffectiveCreatorId(
    c,
    body?.creatorId,
    'creator_cern',
  );
  const result = vhunambiDb.likeKineticPost(postId, effectiveCreatorId);
  if (!result.success) {
    return c.json({ error: 'Post not found', postId }, 404);
  }
  return c.json(result);
});

// GET /api/explore/posts/:id/comments — Threaded comments for a Kinetic Post (Phase 69 REQ-P69-API-01)
exploreRoutes.get('/posts/:id/comments', async (c) => {
  await vhunambiDb.syncExploreFromCloud(false, c);
  const postId = c.req.param('id');
  const sort = (c.req.query('sort') || 'relevant') as 'relevant' | 'newest';
  const viewerId = c.get('authUser')?.creatorId ?? 'creator_cern';
  const comments = vhunambiDb.getKineticPostComments(postId, viewerId, sort);
  return c.json({ postId, comments, total: comments.length }, 200);
});

// POST /api/explore/posts/:id/comments — Add top-level comment or nested reply (Phase 69 REQ-P69-API-01)
exploreRoutes.post('/posts/:id/comments', async (c) => {
  const postId = c.req.param('id');
  let body: any = {};
  try {
    body = await c.req.json();
  } catch (_) {
    return c.json({ error: 'INVALID_REQUEST' }, 400);
  }
  const text = String(body?.text ?? '').trim();
  if (!text) {
    return c.json({ error: 'INVALID_REQUEST', message: 'text is required' }, 400);
  }
  const authUser = c.get('authUser');
  const comment = vhunambiDb.addKineticPostComment(postId, {
    text,
    userId: body?.userId ?? authUser?.creatorId ?? 'creator_cern',
    username:
      body?.username ?? authUser?.handle?.replace(/^@/, '') ?? 'cern',
    displayName:
      body?.displayName ?? authUser?.handle?.replace(/^@/, '') ?? 'Cern',
    avatarUrl: body?.avatarUrl,
    userReelLoves: Number(body?.userReelLoves ?? 0),
    parentCommentId: body?.parentCommentId,
    replyToHandle: body?.replyToHandle,
  });
  if (!comment) {
    return c.json({ error: 'NOT_FOUND', message: `Post ${postId} not found` }, 404);
  }
  return c.json(comment, 201);
});

// POST /api/explore/comments/:id/like — Like a comment on Explore (Phase 69 REQ-P69-API-01)
exploreRoutes.post('/comments/:id/like', (c) => {
  const commentId = c.req.param('id');
  const actorId = c.get('authUser')?.creatorId ?? 'creator_cern';
  const result = vhunambiDb.likeCommentById(commentId, actorId);
  if (!result) {
    return c.json({ error: 'NOT_FOUND', message: `Comment ${commentId} not found` }, 404);
  }
  return c.json(result, 200);
});

