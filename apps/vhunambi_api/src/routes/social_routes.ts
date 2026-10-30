import { Hono } from 'hono';
import { z } from 'zod';
import {
  addComment,
  followCreator,
  getClipsByCreator,
  getComments,
  getCreatorWallet,
  getFeed,
  likeClip,
  likeComment,
  publishClip,
  requestPayout,
  sendTip,
} from '../modules/social/social_service.js';

/**
 * Phase 18 / Phase C · Social Creator Network REST router.
 *
 * Mounted at `/api` by `src/server.ts`, yielding the design.md §5 contract:
 *   POST /api/social/publish
 *   GET  /api/social/feed?cursor=&limit=
 *   POST /api/social/clips/:id/like
 *   GET  /api/social/clips/:id/comments
 *   POST /api/social/clips/:id/comments
 *   POST /api/social/comments/:id/like
 *   POST /api/social/clips/:id/tip
 *   GET  /api/creators/:id/clips
 *   POST /api/creators/:id/follow
 *   GET  /api/creators/:id/wallet
 *   POST /api/creators/:id/wallet/payout
 */
export const socialRoutes = new Hono();

const PublishClipSchema = z.object({
  trackId: z.string().min(1, 'trackId is required'),
  title: z.string().default('Untitled Clip'),
  caption: z.string().default(''),
  tags: z.array(z.string()).default([]),
  visibility: z.enum(['public', 'followers']).default('public'),
  dna: z.record(z.unknown()).default({}),
  creatorId: z.string().optional(),
  creatorUsername: z.string().optional(),
  creatorDisplayName: z.string().optional(),
  creatorAvatarUrl: z.string().optional(),
  isCreatorVerified: z.boolean().optional(),
  audioUrl: z.string().optional(),
  coverUrl: z.string().optional(),
  remixedFromClipId: z.string().optional(),
  remixAttribution: z.string().optional(),
});

const CreateCommentSchema = z.object({
  text: z.string().min(1, 'text is required'),
  userId: z.string().optional(),
  username: z.string().optional(),
  displayName: z.string().optional(),
  avatarUrl: z.string().optional(),
  userReelLoves: z.number().optional(),
  giftEmoji: z.string().optional(),
  giftName: z.string().optional(),
});

const TipSchema = z.object({
  giftId: z.string().min(1, 'giftId is required'),
  senderUsername: z.string().optional(),
  message: z.string().optional(),
});

const PayoutSchema = z.object({
  amountZar: z.number().min(50, 'Minimum payout is R50.00'),
  payoutMethod: z.enum(['eft', 'capitec_pay', 'ozow']).default('eft'),
  accountDetails: z.string().min(1, 'Account details are required'),
});

// POST /api/social/publish — 1-tap in-house publish (REQ-SOC-01)
socialRoutes.post('/social/publish', async (c) => {
  try {
    const body = await c.req.json();
    const parsed = PublishClipSchema.safeParse(body);

    if (!parsed.success) {
      return c.json(
        { error: 'INVALID_REQUEST', details: parsed.error.flatten() },
        400,
      );
    }

    const result = publishClip(parsed.data);
    return c.json({ success: true, ...result }, 201);
  } catch (error) {
    console.error('[Social Publish Error]', error);
    return c.json(
      { error: 'PUBLISH_ERROR', message: 'Failed to publish clip' },
      500,
    );
  }
});

// GET /api/social/feed — cursor-paginated discovery feed (REQ-SOC-16 / REQ-SOC-22)
socialRoutes.get('/social/feed', (c) => {
  const cursor = c.req.query('cursor');
  const limit = Number.parseInt(c.req.query('limit') ?? '20', 10);
  const page = getFeed(cursor, Number.isFinite(limit) ? limit : 20);
  return c.json(page, 200);
});

// POST /api/social/clips/:id/like — optimistic like toggle (REQ-SOC-13 / REQ-SOC-24)
socialRoutes.post('/social/clips/:id/like', (c) => {
  const id = c.req.param('id');
  const result = likeClip(id);
  if (!result) {
    return c.json(
      { error: 'NOT_FOUND', message: `Clip ${id} not found` },
      404,
    );
  }
  return c.json(result, 200);
});

// GET /api/social/clips/:id/comments — thread comments (REQ-COM-01)
socialRoutes.get('/social/clips/:id/comments', (c) => {
  const id = c.req.param('id');
  const comments = getComments(id);
  return c.json({ comments }, 200);
});

// POST /api/social/clips/:id/comments — post comment to thread (REQ-COM-02)
socialRoutes.post('/social/clips/:id/comments', async (c) => {
  const id = c.req.param('id');
  const body = await c.req.json();
  const parsed = CreateCommentSchema.safeParse(body);
  if (!parsed.success) {
    return c.json(
      { error: 'INVALID_REQUEST', details: parsed.error.flatten() },
      400,
    );
  }
  const comment = addComment(id, parsed.data);
  if (!comment) {
    return c.json(
      { error: 'NOT_FOUND', message: `Clip ${id} not found` },
      404,
    );
  }
  return c.json(comment, 201);
});

// POST /api/social/comments/:id/like — like a comment (REQ-COM-01)
socialRoutes.post('/social/comments/:id/like', (c) => {
  const id = c.req.param('id');
  const result = likeComment(id);
  if (!result) {
    return c.json(
      { error: 'NOT_FOUND', message: `Comment ${id} not found` },
      404,
    );
  }
  return c.json(result, 200);
});

// POST /api/social/clips/:id/tip — cultural micro-tipping (REQ-GFT-02, REQ-GFT-03)
socialRoutes.post('/social/clips/:id/tip', async (c) => {
  const id = c.req.param('id');
  const body = await c.req.json();
  const parsed = TipSchema.safeParse(body);
  if (!parsed.success) {
    return c.json(
      { error: 'INVALID_REQUEST', details: parsed.error.flatten() },
      400,
    );
  }
  const result = sendTip(id, parsed.data);
  if (!result) {
    return c.json(
      { error: 'NOT_FOUND', message: `Clip ${id} not found` },
      404,
    );
  }
  return c.json(result, 200);
});

// GET /api/creators/:id/clips — creator reel grid source (REQ-SOC-23)
socialRoutes.get('/creators/:id/clips', (c) => {
  const id = c.req.param('id');
  return c.json({ clips: getClipsByCreator(id) }, 200);
});

// POST /api/creators/:id/follow — reactive follow toggle (REQ-SOC-08 / REQ-SOC-25)
socialRoutes.post('/creators/:id/follow', (c) => {
  const id = c.req.param('id');
  return c.json(followCreator(id), 200);
});

// GET /api/creators/:id/wallet — creator balance & tipping ledger (REQ-WAL-01)
socialRoutes.get('/creators/:id/wallet', (c) => {
  const id = c.req.param('id');
  const wallet = getCreatorWallet(id);
  return c.json(wallet, 200);
});

// POST /api/creators/:id/wallet/payout — cashout payout request (REQ-WAL-02)
socialRoutes.post('/creators/:id/wallet/payout', async (c) => {
  const id = c.req.param('id');
  const body = await c.req.json();
  const parsed = PayoutSchema.safeParse(body);
  if (!parsed.success) {
    return c.json(
      { error: 'INVALID_REQUEST', details: parsed.error.flatten() },
      400,
    );
  }
  const result = requestPayout(id, parsed.data);
  if (!result) {
    return c.json(
      {
        error: 'INSUFFICIENT_FUNDS',
        message: 'Insufficient wallet balance or minimum R50.00 requirement not met',
      },
      400,
    );
  }
  return c.json(result, 200);
});
