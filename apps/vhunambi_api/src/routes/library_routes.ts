import { Hono } from 'hono';
import { vhunambiDb } from '../db/vhunambi_db.js';

export const libraryRoutes = new Hono();

// GET /api/library/sync?creatorId=... (REQ-P45-LIB-01)
libraryRoutes.get('/sync', (c) => {
  const creatorId = c.req.query('creatorId') || 'creator_cern';
  const items = vhunambiDb.getLibrary(creatorId);
  return c.json({ creatorId, items });
});

// POST /api/library/sync (REQ-P45-LIB-02..04)
libraryRoutes.post('/sync', async (c) => {
  const body = await c.req.json();
  const creatorId = body.creatorId || 'creator_cern';
  const items = body.items || [];

  const upserted = vhunambiDb.upsertLibrary(creatorId, items);
  return c.json({ success: true, creatorId, upserted, status: 'synced' });
});

