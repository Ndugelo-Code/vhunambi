import { Hono } from 'hono';
import { z } from 'zod';
import { vhunambiDb, SA_BANK_REGISTRY } from '../db/vhunambi_db.js';
import {
  assertTenantCreatorAccess,
  resolveEffectiveCreatorId,
  sovereignAuthMiddleware,
} from '../middleware/auth_middleware.js';
import {
  addComment,
  followCreator,
  getClipsByCreator,
  getComments,
  getCreatorWallet,
  getFeed,
  getClipRemixes,
  likeClip,
  likeComment,
  publishClip,
  requestPayout,
  sendCulturalTip,
} from '../modules/social/social_service.js';

/**
 * Phase 18 / Phase C / Phase 62 · Social Creator Network REST router.
 */
export const socialRoutes = new Hono();

socialRoutes.use('/social/*', sovereignAuthMiddleware);
socialRoutes.use('/creators/*', sovereignAuthMiddleware);

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

const CreateCommentSchema = z
  .object({
    text: z.string().default(''),
    userId: z.string().optional(),
    username: z.string().optional(),
    displayName: z.string().optional(),
    avatarUrl: z.string().optional(),
    userReelLoves: z.number().optional(),
    giftEmoji: z.string().optional(),
    giftName: z.string().optional(),
    parentCommentId: z.string().optional(),
    replyToHandle: z.string().optional(),
    gifUrl: z.string().url().optional(),
    stickerId: z.string().min(1).optional(),
    mediaAspectRatio: z.number().positive().optional(),
  })
  .refine(
    (d) =>
      d.text.trim().length > 0 ||
      Boolean(d.gifUrl && d.gifUrl.trim().length > 0) ||
      Boolean(d.stickerId && d.stickerId.trim().length > 0),
    { message: 'text, gifUrl, or stickerId is required' },
  );

const TipSchema = z.object({
  giftId: z.string().optional(),
  amountCoins: z.number().optional(),
  senderId: z.string().optional(),
  senderUsername: z.string().optional(),
  message: z.string().optional(),
});

const PayoutSchema = z.object({
  amountZar: z.number().min(50, 'Minimum payout is R50.00'),
  payoutMethod: z
    .enum(['eft', 'capitec_pay', 'ozow', 'payfast'])
    .default('eft'),
  paymentRail: z
    .enum(['eft', 'capitec_pay', 'ozow', 'payfast'])
    .optional(),
  accountDetails: z.string().optional(),
  bankName: z.string().optional(),
  accountNumber: z.string().optional(),
  branchCode: z.string().optional(),
  accountHolder: z.string().optional(),
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

    const forbidden = assertTenantCreatorAccess(c, parsed.data.creatorId);
    if (forbidden) return forbidden;

    const authUser = c.get('authUser');
    const result = publishClip({
      ...parsed.data,
      creatorId: authUser
        ? resolveEffectiveCreatorId(c, parsed.data.creatorId, authUser.creatorId)
        : parsed.data.creatorId,
      creatorUsername:
        parsed.data.creatorUsername ||
        (authUser ? authUser.handle.replace(/^@/, '') : undefined),
    });
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
  const viewerId = c.get('authUser')?.creatorId ?? 'creator_cern';
  const page = getFeed(cursor, Number.isFinite(limit) ? limit : 20, viewerId);
  return c.json(page, 200);
});

// POST /api/social/clips/:id/like — optimistic like toggle (REQ-SOC-13 / REQ-SOC-24)
socialRoutes.post('/social/clips/:id/like', (c) => {
  const id = c.req.param('id');
  const actorId = c.get('authUser')?.creatorId ?? 'creator_cern';
  const result = likeClip(id, actorId);
  if (!result) {
    return c.json(
      { error: 'NOT_FOUND', message: `Clip ${id} not found` },
      404,
    );
  }
  return c.json(result, 200);
});

// GET /api/social/clips/:id/remixes — remix lineage children (Phase 37 REQ-RMX-TREE-01, deduplicated)
socialRoutes.get('/social/clips/:id/remixes', (c) => {
  const id = c.req.param('id');
  const remixes = getClipRemixes(id);
  return c.json({ clipId: id, count: remixes.length, remixes }, 200);
});

// GET /api/social/clips/:id/comments — thread comments (REQ-COM-01)
socialRoutes.get('/social/clips/:id/comments', (c) => {
  const id = c.req.param('id');
  const viewerId = c.get('authUser')?.creatorId ?? 'creator_cern';
  const comments = getComments(id, viewerId);
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
  const authUser = c.get('authUser');
  const comment = addComment(id, {
    ...parsed.data,
    userId: parsed.data.userId ?? authUser?.creatorId,
    username: parsed.data.username ?? authUser?.handle?.replace(/^@/, ''),
  });
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
  const actorId = c.get('authUser')?.creatorId ?? 'creator_cern';
  const result = likeComment(id, actorId);
  if (!result) {
    return c.json(
      { error: 'NOT_FOUND', message: `Comment ${id} not found` },
      404,
    );
  }
  return c.json(result, 200);
});

interface GifSearchItemDto {
  id: string;
  title: string;
  previewUrl: string;
  gifUrl: string;
  width: number;
  height: number;
}

const CURATED_STUDIO_GIFS: GifSearchItemDto[] = [
  {
    id: 'curated_groove_01',
    title: 'Amapiano Log Drum Bounce',
    previewUrl: 'https://media.giphy.com/media/l0MYt5jPR6QX5pnqM/200w.gif',
    gifUrl: 'https://media.giphy.com/media/l0MYt5jPR6QX5pnqM/giphy.gif',
    width: 480,
    height: 360,
  },
  {
    id: 'curated_studio_02',
    title: 'Studio Fire Session',
    previewUrl: 'https://media.giphy.com/media/3o7abKhOpu0NwenH3O/200w.gif',
    gifUrl: 'https://media.giphy.com/media/3o7abKhOpu0NwenH3O/giphy.gif',
    width: 480,
    height: 270,
  },
  {
    id: 'curated_vibe_03',
    title: 'Head Nod Approved',
    previewUrl: 'https://media.giphy.com/media/GeimqsH0TLDt4tScGw/200w.gif',
    gifUrl: 'https://media.giphy.com/media/GeimqsH0TLDt4tScGw/giphy.gif',
    width: 480,
    height: 480,
  },
  {
    id: 'curated_crown_04',
    title: 'Pure Royalty Energy',
    previewUrl: 'https://media.giphy.com/media/okLCopqw6ElCDnIhuS/200w.gif',
    gifUrl: 'https://media.giphy.com/media/okLCopqw6ElCDnIhuS/giphy.gif',
    width: 480,
    height: 360,
  },
];

async function proxyGifCatalog(
  query: string,
  limit: number,
  env: Record<string, unknown> | undefined,
): Promise<{ source: 'tenor' | 'giphy' | 'curated'; items: GifSearchItemDto[] }> {
  const safeLimit = Math.min(Math.max(limit, 1), 24);
  const tenorKey =
    (typeof env?.TENOR_API_KEY === 'string' && env.TENOR_API_KEY.trim()) ||
    (typeof process !== 'undefined' ? process.env?.TENOR_API_KEY?.trim() : '');
  const giphyKey =
    (typeof env?.GIPHY_API_KEY === 'string' && env.GIPHY_API_KEY.trim()) ||
    (typeof process !== 'undefined' ? process.env?.GIPHY_API_KEY?.trim() : '');

  if (tenorKey) {
    try {
      const endpoint = query
        ? `https://tenor.googleapis.com/v2/search?q=${encodeURIComponent(query)}&key=${encodeURIComponent(tenorKey)}&limit=${safeLimit}&media_filter=tinygif,gif`
        : `https://tenor.googleapis.com/v2/featured?key=${encodeURIComponent(tenorKey)}&limit=${safeLimit}&media_filter=tinygif,gif`;
      const res = await fetch(endpoint, { signal: AbortSignal.timeout(3500) });
      if (res.ok) {
        const json = (await res.json()) as { results?: Array<Record<string, any>> };
        const items: GifSearchItemDto[] = (json.results ?? [])
          .map((r) => {
            const gif = r.media_formats?.gif;
            const tiny = r.media_formats?.tinygif ?? gif;
            if (!gif?.url) return null;
            const dims = Array.isArray(gif.dims) ? gif.dims : [480, 360];
            return {
              id: String(r.id ?? ''),
              title: String(r.content_description ?? 'GIF'),
              previewUrl: String(tiny?.url ?? gif.url),
              gifUrl: String(gif.url),
              width: Number(dims[0] ?? 480),
              height: Number(dims[1] ?? 360),
            };
          })
          .filter((x): x is GifSearchItemDto => x !== null);
        if (items.length > 0) return { source: 'tenor', items };
      }
    } catch (_) { }
  }

  if (giphyKey) {
    try {
      const endpoint = query
        ? `https://api.giphy.com/v1/gifs/search?api_key=${encodeURIComponent(giphyKey)}&q=${encodeURIComponent(query)}&limit=${safeLimit}&rating=pg-13`
        : `https://api.giphy.com/v1/gifs/trending?api_key=${encodeURIComponent(giphyKey)}&limit=${safeLimit}&rating=pg-13`;
      const res = await fetch(endpoint, { signal: AbortSignal.timeout(3500) });
      if (res.ok) {
        const json = (await res.json()) as { data?: Array<Record<string, any>> };
        const items: GifSearchItemDto[] = (json.data ?? [])
          .map((r) => {
            const orig = r.images?.original;
            const preview = r.images?.fixed_width_small ?? orig;
            if (!orig?.url) return null;
            return {
              id: String(r.id ?? ''),
              title: String(r.title ?? 'GIF'),
              previewUrl: String(preview?.url ?? orig.url),
              gifUrl: String(orig.url),
              width: Number(orig.width ?? 480),
              height: Number(orig.height ?? 360),
            };
          })
          .filter((x): x is GifSearchItemDto => x !== null);
        if (items.length > 0) return { source: 'giphy', items };
      }
    } catch (_) { }
  }

  const qLower = query.trim().toLowerCase();
  const filtered = qLower
    ? CURATED_STUDIO_GIFS.filter((g) => g.title.toLowerCase().includes(qLower))
    : CURATED_STUDIO_GIFS;
  return {
    source: 'curated',
    items: (filtered.length > 0 ? filtered : CURATED_STUDIO_GIFS).slice(0, safeLimit),
  };
}

// POST /api/social/comments/:id/react — Phase 73 Comment Multi-Reaction
socialRoutes.post('/social/comments/:id/react', async (c) => {
  const commentId = c.req.param('id');
  let body: Record<string, unknown> = {};
  try {
    body = (await c.req.json()) as Record<string, unknown>;
  } catch (_) { }
  const actorId = c.get('authUser')?.creatorId ?? 'creator_cern';
  const rawReaction = body.reactionType ?? body.reaction ?? null;
  const result = await vhunambiDb.reactToCommentAsync(
    commentId,
    actorId,
    typeof rawReaction === 'string' ? (rawReaction as any) : null,
    c,
  );
  if (!result) {
    return c.json(
      { error: 'NOT_FOUND', message: `Comment ${commentId} not found` },
      404,
    );
  }
  return c.json(result, 200);
});

// GET /api/social/gifs/search — Server-side Tenor/GIPHY proxy with curated fallback
socialRoutes.get('/social/gifs/search', async (c) => {
  const q = (c.req.query('q') ?? '').trim();
  const limit = Number.parseInt(c.req.query('limit') ?? '16', 10);
  const env = (c as unknown as { env?: Record<string, unknown> }).env;
  const result = await proxyGifCatalog(q, Number.isFinite(limit) ? limit : 16, env);
  return c.json({ success: true, ...result }, 200);
});

// GET /api/social/gifs/trending — Trending studio GIFs
socialRoutes.get('/social/gifs/trending', async (c) => {
  const limit = Number.parseInt(c.req.query('limit') ?? '16', 10);
  const env = (c as unknown as { env?: Record<string, unknown> }).env;
  const result = await proxyGifCatalog('', Number.isFinite(limit) ? limit : 16, env);
  return c.json({ success: true, ...result }, 200);
});

// POST /api/social/clips/:id/tip — atomic cultural micro-tipping (REQ-GFT-02, REQ-GFT-03, Phase 62)
socialRoutes.post('/social/clips/:id/tip', async (c) => {
  const id = c.req.param('id');
  const body = await c.req.json().catch(() => ({}));
  const parsed = TipSchema.safeParse(body);
  if (!parsed.success) {
    return c.json(
      { error: 'INVALID_REQUEST', details: parsed.error.flatten() },
      400,
    );
  }

  if (parsed.data.senderId) {
    const forbidden = assertTenantCreatorAccess(c, parsed.data.senderId);
    if (forbidden) return forbidden;
  }

  const effectiveSenderId = resolveEffectiveCreatorId(
    c,
    parsed.data.senderId,
    'creator_cern',
  );
  const authUser = c.get('authUser');
  const resolvedUsername =
    parsed.data.senderUsername ??
    (authUser ? authUser.handle.replace(/^@/, '') : 'soweto_fan');

  const result = sendCulturalTip(
    id,
    effectiveSenderId,
    parsed.data.amountCoins,
    parsed.data.giftId,
    parsed.data.message,
    resolvedUsername,
  );

  if (!result.ok) {
    const status =
      result.errorCode === 'CLIP_NOT_FOUND'
        ? 404
        : result.errorCode === 'INSUFFICIENT_WALLET_BALANCE'
          ? 402
          : 422;
    return c.json(
      {
        ok: false,
        error: result.errorCode,
        code: result.errorCode,
        message: result.message,
      },
      status,
    );
  }

  return c.json(result, 200);
});

// GET /api/creators/:id/clips — creator reel grid source (REQ-SOC-23)
socialRoutes.get('/creators/:id/clips', (c) => {
  const id = c.req.param('id');
  const viewerId = c.get('authUser')?.creatorId ?? 'creator_cern';
  return c.json({ clips: getClipsByCreator(id, viewerId) }, 200);
});

// POST /api/creators/:id/follow — reactive follow toggle (REQ-SOC-08 / REQ-SOC-25)
socialRoutes.post('/creators/:id/follow', (c) => {
  const id = c.req.param('id');
  const actorId = c.get('authUser')?.creatorId ?? 'creator_cern';
  return c.json(followCreator(id, actorId), 200);
});

// GET /api/creators/:id/wallet — creator balance & tipping ledger (REQ-WAL-01 + Phase 61 Tenant Guard)
socialRoutes.get('/creators/:id/wallet', async (c) => {
  const id = c.req.param('id') ?? '';
  const forbidden = assertTenantCreatorAccess(c, id);
  if (forbidden) return forbidden;

  await vhunambiDb.syncCreatorWalletFromCloud(id, c);
  const wallet = getCreatorWallet(id);
  return c.json(wallet, 200);
});

// POST /api/creators/:id/wallet/payout — cashout payout request (REQ-WAL-02 + Phase 61 Tenant Guard)
socialRoutes.post('/creators/:id/wallet/payout', async (c) => {
  const id = c.req.param('id') ?? '';
  const forbidden = assertTenantCreatorAccess(c, id);
  if (forbidden) return forbidden;
  const body = await c.req.json();
  const parsed = PayoutSchema.safeParse(body);
  if (!parsed.success) {
    return c.json(
      { error: 'INVALID_REQUEST', details: parsed.error.flatten() },
      400,
    );
  }

  const data = parsed.data;
  const resolvedRail = data.paymentRail || data.payoutMethod || 'eft';
  const detailsStr = String(data.accountDetails || '').trim();
  if (!detailsStr && (!data.bankName || !data.accountNumber)) {
    return c.json(
      {
        error: 'INVALID_REQUEST',
        message: 'Either accountDetails or bankName + accountNumber are required',
      },
      400,
    );
  }

  let resolvedBank = data.bankName?.trim() || '';
  if (!resolvedBank && detailsStr) {
    const lower = detailsStr.toLowerCase();
    for (const [key, meta] of Object.entries(SA_BANK_REGISTRY)) {
      if (lower.includes(key)) {
        resolvedBank = meta.canonicalName;
        break;
      }
    }
  }

  const resolvedAccountDigits =
    data.accountNumber?.trim() ||
    (detailsStr.replace(/\D/g, '').length >= 8
      ? detailsStr.replace(/\D/g, '')
      : '');

  let sqliteReceipt: ReturnType<typeof vhunambiDb.requestPayout> | null = null;
  if (resolvedBank && resolvedAccountDigits) {
    sqliteReceipt = vhunambiDb.requestPayout({
      creatorId: id,
      amountZar: data.amountZar,
      bankName: resolvedBank,
      accountNumber: resolvedAccountDigits,
      branchCode: data.branchCode,
      paymentRail: resolvedRail,
      accountHolder: data.accountHolder,
    });
    if (!sqliteReceipt.success) {
      return c.json(
        {
          error: 'PAYOUT_REJECTED',
          message: sqliteReceipt.error || 'Payout rejected',
        },
        400,
      );
    }
  }

  const legacyResult = sqliteReceipt
    ? null
    : requestPayout(id, {
      amountZar: data.amountZar,
      payoutMethod: resolvedRail,
    });

  if (!legacyResult && !sqliteReceipt) {
    return c.json(
      {
        error: 'INSUFFICIENT_FUNDS',
        message:
          'Insufficient wallet balance or minimum R50.00 requirement not met',
      },
      400,
    );
  }

  return c.json(
    {
      success: true,
      payoutId: sqliteReceipt?.payoutId ?? legacyResult!.payoutId,
      remainingBalanceZar:
        sqliteReceipt?.remainingBalanceZar ?? legacyResult!.remainingBalanceZar,
      deductedZar: sqliteReceipt?.deductedZar ?? data.amountZar,
      status: sqliteReceipt?.status ?? 'processing',
      bankName: sqliteReceipt?.bankName ?? resolvedBank,
      branchCode: sqliteReceipt?.branchCode,
      maskedAccount: sqliteReceipt?.maskedAccount,
      paymentRail: sqliteReceipt?.paymentRail ?? resolvedRail,
      estimatedSettlement: sqliteReceipt?.estimatedSettlement,
      gatewayRef: sqliteReceipt?.gatewayRef,
      processedAt: sqliteReceipt?.processedAt ?? new Date().toISOString(),
    },
    200,
  );
});
