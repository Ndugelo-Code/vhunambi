import { Hono } from 'hono';
import { vhunambiDb } from '../db/vhunambi_db.js';
import {
  assertTenantCreatorAccess,
  resolveEffectiveCreatorId,
  sovereignAuthMiddleware,
} from '../middleware/auth_middleware.js';

export const libraryRoutes = new Hono();

libraryRoutes.use('*', sovereignAuthMiddleware);

// GET /api/library — Alias for library snapshot
libraryRoutes.get('/', (c) => {
  const requestedId = c.req.query('creatorId');
  const forbidden = assertTenantCreatorAccess(c, requestedId);
  if (forbidden) return forbidden;

  const creatorId = resolveEffectiveCreatorId(c, requestedId, 'creator_cern');
  const items = vhunambiDb.getLibrary(creatorId);
  return c.json({
    creatorId,
    items,
    count: items.length,
    serverSeq: vhunambiDb.getLatestSeq(),
    syncedAt: new Date().toISOString(),
  });
});

// GET /api/library/sync?creatorId=... (REQ-P45-LIB-01)
libraryRoutes.get('/sync', (c) => {
  const requestedId = c.req.query('creatorId');
  const forbidden = assertTenantCreatorAccess(c, requestedId);
  if (forbidden) return forbidden;

  const creatorId = resolveEffectiveCreatorId(c, requestedId, 'creator_cern');
  const items = vhunambiDb.getLibrary(creatorId);
  return c.json({
    creatorId,
    items,
    count: items.length,
    serverSeq: vhunambiDb.getLatestSeq(),
    syncedAt: new Date().toISOString(),
  });
});

// POST /api/library/sync (REQ-P45-LIB-02..04 + Phase 59 LWW delta merge + Phase 61 Tenant Guard)
libraryRoutes.post('/sync', async (c) => {
  const body = await c.req.json();
  const forbidden = assertTenantCreatorAccess(c, body.creatorId);
  if (forbidden) return forbidden;

  const creatorId = resolveEffectiveCreatorId(c, body.creatorId, 'creator_cern');
  const items = Array.isArray(body.items) ? body.items : [];

  const result = vhunambiDb.syncLibraryDelta(creatorId, items);
  return c.json({
    success: true,
    creatorId,
    upserted: result.appliedCount + result.skippedCount,
    appliedCount: result.appliedCount,
    skippedCount: result.skippedCount,
    items: result.items,
    serverSeq: result.serverSeq,
    syncedAt: result.syncedAt,
    status: 'synced',
  });
});

// DELETE /api/library/:id — Hard delete library item from cloud vault (with ownership check)
libraryRoutes.delete('/:id', (c) => {
  const id = c.req.param('id');
  const requestedCreatorId = c.req.query('creatorId');
  const forbiddenQuery = assertTenantCreatorAccess(c, requestedCreatorId);
  if (forbiddenQuery) return forbiddenQuery;

  const authUser = c.get('authUser');
  if (authUser) {
    const ownerId = vhunambiDb.getLibraryItemOwnerCreatorId(id);
    if (ownerId && ownerId !== authUser.creatorId && authUser.role !== 'admin') {
      return c.json(
        {
          error: `Forbidden: Library item '${id}' belongs to '${ownerId}', not '${authUser.creatorId}'.`,
          code: 'TENANT_FORBIDDEN',
        },
        403,
      );
    }
  }

  const effectiveCreatorId = authUser ? authUser.creatorId : requestedCreatorId;
  const deleted = vhunambiDb.deleteLibraryItem(id, effectiveCreatorId);
  if (!deleted) {
    return c.json({ success: false, error: 'Library item not found', id }, 404);
  }
  return c.json({ success: true, id, serverSeq: vhunambiDb.getLatestSeq() });
});

