import { Hono } from 'hono';
import { vhunambiDb } from '../db/vhunambi_db.js';

export const syncRoutes = new Hono();

// POST /api/sync/mutations (REQ-P45-SYNC-01..04)
syncRoutes.post('/mutations', async (c) => {
  const body = await c.req.json();
  const mutations = body.mutations || [];

  const result = vhunambiDb.applyMutationsBatch(mutations);
  return c.json(result);
});

// GET /api/sync/delta?since=<seq> (REQ-P45-SYNC-05..06)
syncRoutes.get('/delta', (c) => {
  const since = c.req.query('since') ? parseInt(c.req.query('since')!, 10) : 0;
  const result = vhunambiDb.getDelta(since);

  const eTag = `"cursor-${result.latestSeq}"`;
  const ifNoneMatch = c.req.header('if-none-match');

  if (ifNoneMatch && ifNoneMatch === eTag) {
    return c.body(null, 304, {
      ETag: eTag,
      'Cache-Control': 'no-cache',
    });
  }

  return c.json(result, 200, {
    ETag: eTag,
    'Cache-Control': 'no-cache',
  });
});

