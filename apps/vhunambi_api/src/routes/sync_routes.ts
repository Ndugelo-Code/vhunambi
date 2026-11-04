import { Hono } from 'hono';
import { vhunambiDb } from '../db/vhunambi_db.js';

export const syncRoutes = new Hono();

// POST /api/sync/mutations (REQ-P45-SYNC-01..04)
syncRoutes.post('/mutations', async (c) => {
  const body = await c.req.json();
  const mutations = body.mutations || [];

  const result = vhunambiDb.applyMutationsBatch(mutations);
  return c.json({
    ...result,
    latest_seq: result.latestSeq,
  });
});

// GET /api/sync/delta?since=<seq> (REQ-P45-SYNC-05..06, REQ-P46-SYNC-05)
syncRoutes.get('/delta', (c) => {
  const sinceParam = c.req.query('since_seq') || c.req.query('since') || '0';
  const since = parseInt(sinceParam, 10) || 0;
  const result = vhunambiDb.getDelta(since);

  const eTag = `"cursor-${result.latestSeq}"`;
  const ifNoneMatch = c.req.header('if-none-match');

  if (ifNoneMatch && ifNoneMatch === eTag) {
    return c.body(null, 304, {
      ETag: eTag,
      'Cache-Control': 'no-cache',
    });
  }

  return c.json({
    mutations: result.mutations,
    latestSeq: result.latestSeq,
    latest_seq: result.latestSeq,
  }, 200, {
    ETag: eTag,
    'Cache-Control': 'no-cache',
  });
});

