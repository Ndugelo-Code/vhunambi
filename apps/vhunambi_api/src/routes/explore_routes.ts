import { Hono } from 'hono';
import { vhunambiDb } from '../db/vhunambi_db.js';
import {
  assertTenantCreatorAccess,
  resolveEffectiveCreatorId,
  sovereignAuthMiddleware,
} from '../middleware/auth_middleware.js';
import {
  decodeExploreCursor,
  encodeExploreCursor,
} from '../modules/media/cursor.js';
import { computeEdgeEtag, isIfNoneMatchHit } from '../modules/media/etag.js';
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

// GET /api/explore/tracks — Dynamic African track catalog with keyset cursor & ETag caching
exploreRoutes.get('/tracks', async (c) => {
  await vhunambiDb.syncExploreFromCloud(false, c);
  const genre = c.req.query('genre');
  const stage = c.req.query('stage');
  const sort = ((c.req.query('sort') as string) || 'trending') as
    | 'trending'
    | 'newest'
    | 'likes'
    | 'plays';
  const search = c.req.query('search');
  const rawMood = c.req.query('moodId') || c.req.query('mood');
  const moodId =
    rawMood && rawMood.trim() !== '' && rawMood.trim().toLowerCase() !== 'all'
      ? normalizeVhunambiMoodId(rawMood)
      : undefined;
  const rawLimit = c.req.query('limit') ? parseInt(c.req.query('limit')!, 10) : 50;
  const pageLimit = Math.min(Math.max(Number.isFinite(rawLimit) ? rawLimit : 50, 1), 100);
  const decodedCursor = decodeExploreCursor(c.req.query('cursor'));

  // Pull bounded superset when cursor pagination is active so we can slice deterministically
  const result = vhunambiDb.getExploreTracks({
    genre,
    stage,
    sort,
    search,
    moodId,
    limit: decodedCursor ? 100 : pageLimit + 1,
  });

  const getSortKey = (t: (typeof result.items)[number]): string | number => {
    if (sort === 'newest') return t.createdAt;
    if (sort === 'likes') return t.likesCount;
    if (sort === 'plays') return t.playsCount;
    return t.trendingScore;
  };

  let ordered = [...result.items].sort((a, b) => {
    const ka = getSortKey(a);
    const kb = getSortKey(b);
    if (typeof kb === 'number' && typeof ka === 'number' && kb !== ka) {
      return kb - ka;
    }
    if (String(kb) !== String(ka)) {
      return String(kb).localeCompare(String(ka));
    }
    return b.id.localeCompare(a.id);
  });

  if (decodedCursor) {
    ordered = ordered.filter((t) => {
      const k = getSortKey(t);
      const ck = decodedCursor.sortKey;
      if (typeof k === 'number' && typeof ck === 'number') {
        if (k !== ck) return k < ck;
        return t.id.localeCompare(decodedCursor.id) < 0;
      }
      const cmp = String(k).localeCompare(String(ck));
      if (cmp !== 0) return cmp < 0;
      return t.id.localeCompare(decodedCursor.id) < 0;
    });
  }

  const hasMore = ordered.length > pageLimit;
  const pageItems = ordered.slice(0, pageLimit);
  const lastItem = pageItems[pageItems.length - 1];
  const nextCursor =
    hasMore && lastItem
      ? encodeExploreCursor({ sortKey: getSortKey(lastItem), id: lastItem.id })
      : null;

  const normalizedItems = pageItems.map((t) => ({
    ...t,
    moodId: normalizeVhunambiMoodId(t.moodId ?? t.mood),
    description: t.description ?? '',
    allowOpenStemsRemix: Boolean(t.allowOpenStemsRemix),
  }));

  const payload = {
    success: true,
    items: normalizedItems,
    tracks: normalizedItems,
    total: result.total,
    nextCursor,
    serverSeq: result.serverSeq,
  };
  const bodyJson = JSON.stringify(payload);
  const etag = computeEdgeEtag(bodyJson);

  if (isIfNoneMatchHit(c.req.header('if-none-match'), etag)) {
    return c.body(null, 304, {
      ETag: etag,
      'Cache-Control': 'private, max-age=15, must-revalidate',
    });
  }

  c.header('ETag', etag);
  c.header('Cache-Control', 'private, max-age=15, must-revalidate');
  return c.json(payload);
});

// POST /api/explore/tracks — Publish or update a track in the Explore catalog (Durable Write-Through)
exploreRoutes.post('/tracks', async (c) => {
  try {
    const body = await c.req.json();
    if (!body?.title || String(body.title).trim() === '') {
      return c.json({ success: false, error: 'Track title is required' }, 400);
    }
    const forbidden = assertTenantCreatorAccess(c, body.creatorId);
    if (forbidden) return forbidden;

    const authUser = c.get('authUser');
    const track = await vhunambiDb.upsertExploreTrackAsync(
      {
        ...body,
        creatorId: authUser
          ? resolveEffectiveCreatorId(c, body.creatorId, authUser.creatorId)
          : body.creatorId,
      },
      c,
    );
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
  const viewerCreatorId = c.get('authUser')?.creatorId ?? 'creator_cern';

  const result = vhunambiDb.getExploreFeed({ stage, genre, limit, offset, viewerCreatorId });
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
  const viewerCreatorId = c.get('authUser')?.creatorId ?? 'creator_cern';
  await vhunambiDb.syncExploreFromCloud(false, c);
  let post = vhunambiDb.getKineticPostById(postId, viewerCreatorId);
  if (!post) {
    await vhunambiDb.syncExploreFromCloud(true, c);
    post = vhunambiDb.getKineticPostById(postId, viewerCreatorId);
  }
  if (!post) {
    return c.json({ error: 'Post not found', postId }, 404);
  }
  return c.json({ success: true, post });
});

// POST /api/explore/posts — Publish or upsert a Kinetic Post (Durable Write-Through)
exploreRoutes.post('/posts', async (c) => {
  try {
    const body = await c.req.json();
    const forbidden = assertTenantCreatorAccess(c, body?.creatorId);
    if (forbidden) return forbidden;
    const authUser = c.get('authUser');
    const post = await vhunambiDb.upsertKineticPostAsync(
      {
        ...body,
        creatorId: authUser
          ? resolveEffectiveCreatorId(c, body?.creatorId, authUser.creatorId)
          : body?.creatorId,
        creatorHandle:
          body?.creatorHandle || (authUser ? authUser.handle : '@cern'),
      },
      c,
    );
    return c.json({ success: true, post }, 201);
  } catch (err: any) {
    return c.json({ success: false, error: err?.message || 'Invalid JSON' }, 400);
  }
});

// POST /api/explore/posts/:id/react — Phase 73 Multi-Reaction Toggle/Switch
exploreRoutes.post('/posts/:id/react', async (c) => {
  const postId = c.req.param('id');
  let body: Record<string, unknown> = {};
  try {
    body = (await c.req.json()) as Record<string, unknown>;
  } catch (_) { }
  const effectiveCreatorId = resolveEffectiveCreatorId(
    c,
    typeof body.creatorId === 'string' ? body.creatorId : undefined,
    'creator_cern',
  );
  const rawReaction = body.reactionType ?? body.reaction ?? null;
  const result = await vhunambiDb.reactToKineticPostAsync(
    postId,
    effectiveCreatorId,
    typeof rawReaction === 'string' ? (rawReaction as any) : null,
    c,
  );
  if (!result.success) {
    return c.json({ error: 'Post not found', postId }, 404);
  }
  return c.json(result, 200);
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
  const gifUrl = typeof body?.gifUrl === 'string' ? body.gifUrl.trim() : '';
  const stickerId =
    typeof body?.stickerId === 'string' ? body.stickerId.trim() : '';
  const mediaAspectRatio =
    typeof body?.mediaAspectRatio === 'number' &&
      Number.isFinite(body.mediaAspectRatio)
      ? body.mediaAspectRatio
      : undefined;

  if (!text && !gifUrl && !stickerId) {
    return c.json(
      {
        error: 'INVALID_REQUEST',
        message: 'text, gifUrl, or stickerId is required',
      },
      400,
    );
  }
  const authUser = c.get('authUser');
  const comment = vhunambiDb.addKineticPostComment(postId, {
    text,
    ...(gifUrl ? { gifUrl } : {}),
    ...(stickerId ? { stickerId } : {}),
    ...(mediaAspectRatio ? { mediaAspectRatio } : {}),
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

// POST /api/explore/comments/:id/react — Phase 73 Comment Multi-Reaction
exploreRoutes.post('/comments/:id/react', async (c) => {
  const commentId = c.req.param('id');
  let body: Record<string, unknown> = {};
  try {
    body = (await c.req.json()) as Record<string, unknown>;
  } catch (_) { }
  const actorId = c.get('authUser')?.creatorId ?? 'creator_cern';
  const rawReaction = body.reactionType ?? body.reaction ?? null;
  const result = await vhunambiDb.reactToCommentAsync(
    commentId,
    actorId,
    typeof rawReaction === 'string' ? (rawReaction as any) : null,
    c,
  );
  if (!result) {
    return c.json(
      { error: 'NOT_FOUND', message: `Comment ${commentId} not found` },
      404,
    );
  }
  return c.json(result, 200);
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

