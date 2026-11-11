import { Hono } from 'hono';
import { vhunambiDb } from '../db/vhunambi_db.js';
import {
  assertTenantCreatorAccess,
  isStrictAuthEnforced,
  resolveEffectiveCreatorId,
  sovereignAuthMiddleware,
} from '../middleware/auth_middleware.js';
import {
  deleteMarketplaceBeat,
  getBeatById,
  getLicensesByBuyer,
  getMarketplaceBeats,
  getProducerBeats,
  licenseBeat,
  upsertMarketplaceBeat,
} from '../modules/marketplace/marketplace_service.js';
import {
  CreateBeatListingRequest,
  LicenseBeatRequest,
  MarketplaceFilterQuery,
} from '../modules/marketplace/marketplace_types.js';

export const marketplaceRoutes = new Hono();

marketplaceRoutes.use('*', sovereignAuthMiddleware);

/**
 * GET /api/marketplace/beats
 * Public beat catalog feed with multi-dimensional filtering.
 */
marketplaceRoutes.get('/beats', (c) => {
  const query: MarketplaceFilterQuery = {
    genre: c.req.query('genre'),
    search: c.req.query('search'),
    minBpm: c.req.query('minBpm') ? Number(c.req.query('minBpm')) : undefined,
    maxBpm: c.req.query('maxBpm') ? Number(c.req.query('maxBpm')) : undefined,
    maxPrice: c.req.query('maxPrice') ? Number(c.req.query('maxPrice')) : undefined,
    cursor: c.req.query('cursor'),
    limit: c.req.query('limit') ? Number(c.req.query('limit')) : undefined,
  };

  const result = getMarketplaceBeats(query);
  return c.json(result);
});

/**
 * GET /api/marketplace/beats/:id
 * Retrieve a single beat listing.
 */
marketplaceRoutes.get('/beats/:id', (c) => {
  const beat = getBeatById(c.req.param('id'));
  if (!beat) {
    return c.json({ error: 'Beat not found' }, 404);
  }
  return c.json(beat);
});

/**
 * POST /api/marketplace/beats
 * Upsert or publish a producer's beat into the public marketplace.
 */
marketplaceRoutes.post('/beats', async (c) => {
  try {
    const body = await c.req.json<CreateBeatListingRequest>();
    if (!body.title || !body.genre || !body.bpm || !body.previewAudioUrl) {
      return c.json({ error: 'Missing required beat listing fields' }, 400);
    }
    const forbidden = assertTenantCreatorAccess(c, body.producerId);
    if (forbidden) return forbidden;

    const effectiveProducerId = resolveEffectiveCreatorId(
      c,
      body.producerId,
      'creator_cern',
    );
    const listing = upsertMarketplaceBeat({
      ...body,
      producerId: effectiveProducerId,
      producerHandle: body.producerHandle || c.get('authUser')?.handle || '@user_beats',
    });
    return c.json(listing, 201);
  } catch (e: unknown) {
    return c.json({ error: 'Invalid JSON payload' }, 400);
  }
});

/**
 * DELETE /api/marketplace/beats/:id
 * Unpublishes / removes a beat from the public marketplace.
 */
marketplaceRoutes.delete('/beats/:id', (c) => {
  const beatId = c.req.param('id');
  const existing = getBeatById(beatId);
  if (!existing) {
    return c.json({ error: 'Beat not found' }, 404);
  }
  const authUser = c.get('authUser');
  if (authUser && authUser.role !== 'admin') {
    const forbidden = assertTenantCreatorAccess(c, existing.producerId);
    if (forbidden) return forbidden;
  }
  if (existing.isExclusiveSold) {
    return c.json(
      {
        error: 'EXCLUSIVE_SOLD_LOCKED',
        code: 'EXCLUSIVE_SOLD_LOCKED',
        message: 'Cannot delete a beat after an exclusive buyout license has been issued.',
      },
      409,
    );
  }
  const deleted = deleteMarketplaceBeat(beatId);
  if (!deleted) {
    return c.json({ error: 'Beat not found' }, 404);
  }
  return c.json({ success: true, deleted: true, beatId, message: 'Beat unpublished from marketplace' });
});

/**
 * POST /api/marketplace/beats/:id/license
 * Atomic license purchase: generates cryptographic certificate & credits seller wallet.
 * Phase 61: Strictly enforces buyer tenant ownership and wallet balance for authenticated / strict requests.
 */
marketplaceRoutes.post('/beats/:id/license', async (c) => {
  try {
    const beatId = c.req.param('id');
    const body = await c.req.json<LicenseBeatRequest>();
    const forbidden = assertTenantCreatorAccess(c, body.buyerId);
    if (forbidden) return forbidden;

    const effectiveBuyerId = resolveEffectiveCreatorId(
      c,
      body.buyerId,
      '',
    );
    if (!effectiveBuyerId || !body.tier) {
      return c.json({ error: 'buyerId and tier are required' }, 400);
    }

    const mustEnforceWallet =
      Boolean(c.get('authUser')) ||
      isStrictAuthEnforced(c) ||
      body.enforceWalletBalance === true;

    const result = licenseBeat(beatId, {
      ...body,
      buyerId: effectiveBuyerId,
      buyerHandle: body.buyerHandle || c.get('authUser')?.handle || '@creator',
      enforceWalletBalance: mustEnforceWallet ? true : body.enforceWalletBalance,
    });
    if (!result.ok) {
      if (result.errorCode === 'EXCLUSIVE_CONFLICT') {
        return c.json({ error: result.error, code: result.errorCode }, 409);
      }
      if (result.errorCode === 'INSUFFICIENT_FUNDS') {
        return c.json({ error: result.error, code: result.errorCode }, 402);
      }
      return c.json({ error: result.error, code: result.errorCode }, 404);
    }

    return c.json({ certificate: result.certificate, beat: result.beat }, 201);
  } catch (e: unknown) {
    return c.json({ error: 'Invalid licensing request' }, 400);
  }
});

/**
 * GET /api/marketplace/licenses/verify/:certificateId
 * Verifies cryptographic SHA-256 certificate digest integrity against SQLite registry.
 */
marketplaceRoutes.get('/licenses/verify/:certificateId', (c) => {
  const verification = vhunambiDb.verifyBeatLicense(
    c.req.param('certificateId'),
  );
  if (!verification.found) {
    return c.json(
      { found: false, valid: false, error: 'Certificate not found' },
      404,
    );
  }
  return c.json(verification);
});

/**
 * GET /api/marketplace/licenses/:buyerId
 * Retrieves all commercial certificates and stem packages licensed by a user.
 */
marketplaceRoutes.get('/licenses/:buyerId', (c) => {
  const buyerId = c.req.param('buyerId');
  const forbidden = assertTenantCreatorAccess(c, buyerId);
  if (forbidden) return forbidden;

  const certificates = getLicensesByBuyer(buyerId);
  return c.json({ buyerId, certificates });
});

/**
 * GET /api/marketplace/producers/:producerId/beats
 * Retrieves beats published by a specific producer.
 */
marketplaceRoutes.get('/producers/:producerId/beats', (c) => {
  const producerId = c.req.param('producerId');
  const beats = getProducerBeats(producerId);
  return c.json({ producerId, beats });
});

