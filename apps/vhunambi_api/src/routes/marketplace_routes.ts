import { Hono } from 'hono';
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
    const listing = upsertMarketplaceBeat(body);
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
  const deleted = deleteMarketplaceBeat(c.req.param('id'));
  if (!deleted) {
    return c.json({ error: 'Beat not found' }, 404);
  }
  return c.json({ success: true, message: 'Beat unpublished from marketplace' });
});

/**
 * POST /api/marketplace/beats/:id/license
 * Atomic license purchase: generates cryptographic certificate & credits seller wallet.
 */
marketplaceRoutes.post('/beats/:id/license', async (c) => {
  try {
    const beatId = c.req.param('id');
    const body = await c.req.json<LicenseBeatRequest>();
    if (!body.buyerId || !body.tier) {
      return c.json({ error: 'buyerId and tier are required' }, 400);
    }

    const result = licenseBeat(beatId, body);
    if (!result) {
      return c.json({ error: 'Beat not found or licensing failed' }, 404);
    }

    return c.json(result, 201);
  } catch (e: unknown) {
    return c.json({ error: 'Invalid licensing request' }, 400);
  }
});

/**
 * GET /api/marketplace/licenses/:buyerId
 * Retrieves all commercial certificates and stem packages licensed by a user.
 */
marketplaceRoutes.get('/licenses/:buyerId', (c) => {
  const buyerId = c.req.param('buyerId');
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

