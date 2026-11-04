import { Hono } from 'hono';
import { vhunambiDb } from '../db/vhunambi_db.js';

export const exploreRoutes = new Hono();

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
  } catch (_) {}

  const result = vhunambiDb.cosignPost(postId, body.creatorId);
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

