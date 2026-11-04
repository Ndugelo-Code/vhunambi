import { Hono } from 'hono';
import { vhunambiDb } from '../db/vhunambi_db.js';

export const syncRoutes = new Hono();

// POST /api/sync/mutations (REQ-P45-SYNC-01..04, REQ-P48-PF-01..06)
syncRoutes.post('/mutations', async (c) => {
  const body = await c.req.json();
  const mutations = body.mutations || [];

  const result = vhunambiDb.applyMutationsBatch(mutations);
  return c.json({
    ...result,
    latest_seq: result.latestSeq,
  });
});

// GET /api/sync/delta?since_seq=<seq>&limit=<1..200> (REQ-P45-SYNC-05..06, REQ-P46-SYNC-05, REQ-P48-PD-01..04)
syncRoutes.get('/delta', (c) => {
  const sinceParam = c.req.query('since_seq') || c.req.query('since') || '0';
  const since = parseInt(sinceParam, 10) || 0;

  // Phase 48: paginated delta with limit (default 100, max 200)
  const limitParam = c.req.query('limit') || '100';
  const limit = Math.min(Math.max(parseInt(limitParam, 10) || 100, 1), 200);

  const result = vhunambiDb.getDelta(since, limit);

  const eTag = `"cursor-${result.latestSeq}"`;
  const ifNoneMatch = c.req.header('if-none-match');

  if (ifNoneMatch && ifNoneMatch === eTag) {
    return c.body(null, 304, {
      ETag: eTag,
      'Cache-Control': 'no-cache',
    });
  }

  return c.json({
    // Phase 48 paginated fields
    changes: result.mutations,
    latestSeq: result.latestSeq,
    latest_seq: result.latestSeq,
    nextCursorSeq: result.nextCursorSeq,
    hasMore: result.hasMore,
    // Backward-compatible Phase 45/46 fields
    mutations: result.mutations,
  }, 200, {
    ETag: eTag,
    'Cache-Control': 'no-cache',
  });
});

