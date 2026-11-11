import { Hono } from 'hono';
import { vhunambiDb } from '../db/vhunambi_db.js';
import {
  assertTenantCreatorAccess,
  isStrictAuthEnforced,
  sovereignAuthMiddleware,
} from '../middleware/auth_middleware.js';

export const syncRoutes = new Hono();

syncRoutes.use('*', sovereignAuthMiddleware);

// POST /api/sync/mutations (REQ-P45-SYNC-01..04, REQ-P48-PF-01..06, Phase 61 Tenant Guard)
syncRoutes.post('/mutations', async (c) => {
  const body = await c.req.json();
  const mutations = Array.isArray(body.mutations) ? body.mutations : [];
  const authUser = c.get('authUser');

  if (authUser && authUser.role !== 'admin') {
    for (const m of mutations) {
      const p = (m?.payload || {}) as Record<string, unknown>;
      const claimedOwner =
        (typeof p.creatorId === 'string' && p.creatorId.trim()) ||
        (typeof p.creator_id === 'string' && p.creator_id.trim()) ||
        (typeof p.buyerId === 'string' && p.buyerId.trim());
      if (claimedOwner && claimedOwner !== authUser.creatorId) {
        return c.json(
          {
            error: `Forbidden: Authenticated principal '${authUser.creatorId}' cannot submit mutation for '${claimedOwner}'.`,
            code: 'TENANT_FORBIDDEN',
          },
          403,
        );
      }
      if (m?.entityType === 'beat_license') {
        m.payload = {
          ...p,
          buyerId: authUser.creatorId,
          enforceWalletBalance: true,
        };
      }
    }
  } else if (isStrictAuthEnforced(c)) {
    for (const m of mutations) {
      if (m?.entityType === 'beat_license') {
        m.payload = { ...(m.payload || {}), enforceWalletBalance: true };
      }
    }
  }

  const result = vhunambiDb.applyMutationsBatch(mutations);
  return c.json({
    ...result,
    latest_seq: result.latestSeq,
  });
});

// GET /api/sync/delta?since_seq=<seq>&limit=<1..200> (REQ-P45-SYNC-05..06, Phase 61 Tenant Filter)
syncRoutes.get('/delta', (c) => {
  const sinceParam = c.req.query('since_seq') || c.req.query('since') || '0';
  const since = parseInt(sinceParam, 10) || 0;

  const requestedCreatorId = c.req.query('creatorId');
  const forbidden = assertTenantCreatorAccess(c, requestedCreatorId);
  if (forbidden) return forbidden;

  const authUser = c.get('authUser');
  const viewerCreatorId = authUser ? authUser.creatorId : requestedCreatorId;

  // Phase 48: paginated delta with limit (default 100, max 200)
  const limitParam = c.req.query('limit') || '100';
  const limit = Math.min(Math.max(parseInt(limitParam, 10) || 100, 1), 200);

  const result = vhunambiDb.getDelta(since, limit, viewerCreatorId);

  const eTag = viewerCreatorId
    ? `"cursor-${result.latestSeq}-${viewerCreatorId}"`
    : `"cursor-${result.latestSeq}"`;
  const ifNoneMatch = c.req.header('if-none-match');

  if (ifNoneMatch && ifNoneMatch === eTag) {
    return c.body(null, 304, {
      ETag: eTag,
      'Cache-Control': 'no-cache',
    });
  }

  return c.json(
    {
      // Phase 48 paginated fields
      changes: result.mutations,
      latestSeq: result.latestSeq,
      latest_seq: result.latestSeq,
      nextCursorSeq: result.nextCursorSeq,
      hasMore: result.hasMore,
      // Backward-compatible Phase 45/46 fields
      mutations: result.mutations,
    },
    200,
    {
      ETag: eTag,
      'Cache-Control': 'no-cache',
    },
  );
});

