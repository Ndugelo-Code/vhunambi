import { Hono } from 'hono';
import { nanoid } from 'nanoid';
import { z } from 'zod';
import {
  VALID_KINETIC_REACTIONS,
  normalizeKineticReactionWire,
} from '../db/edge_persistence_bridge.js';
import {
  canonicalizeCreatorId,
  vhunambiDb,
  SA_BANK_REGISTRY,
} from '../db/vhunambi_db.js';
import { uploadBytesToR2 } from '../modules/synthesis/r2_storage.js';
import { inferMediaKindFromMime } from './media_routes.js';
import {
  assertTenantCreatorAccess,
  resolveEffectiveCreatorId,
  sovereignAuthMiddleware,
} from '../middleware/auth_middleware.js';
import {
  addComment,
  followCreator,
  getClipById,
  getClipsByCreator,
  getComments,
  getCreatorWallet,
  getFeed,
  getClipRemixes,
  likeClip,
  likeComment,
  publishClipAsync,
  reactToClipAsync,
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
  videoUrl: z.string().nullable().optional(),
  mediaKind: z
    .enum([
      'artwork',
      'camera_video',
      'gallery_video',
      'gallery_photo',
      'vision',
    ])
    .optional(),
  audioStartMs: z.number().int().min(0).optional(),
  audioEndMs: z.number().int().min(1000).optional(),
  effectPreset: z.string().optional(),
  effectIntensity: z.number().min(0).max(1).optional(),
  typographyPreset: z.string().optional(),
  speedRate: z.number().min(0.25).max(4).optional(),
  stickerId: z.string().nullable().optional(),
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

const MAX_SOCIAL_MEDIA_BYTES = 25 * 1024 * 1024; // 26,214,400 bytes
const ALLOWED_SOCIAL_MEDIA_MIMES: Record<string, string> = {
  'video/mp4': 'mp4',
  'video/quicktime': 'mov',
  'video/webm': 'webm',
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'audio/mpeg': 'mp3',
  'audio/mp4': 'm4a',
  'audio/wav': 'wav',
  'audio/x-wav': 'wav',
  'audio/wave': 'wav',
  'audio/aac': 'aac',
  'audio/ogg': 'ogg',
};

// POST /api/social/media/upload — authenticated R2 media upload for Reels Studio v4 (REQ-P74-BE-04)
socialRoutes.post('/social/media/upload', async (c) => {
  const authUser = c.get('authUser');
  const creatorId = canonicalizeCreatorId(authUser?.creatorId ?? 'creator_cern');
  const reqContentType = (c.req.header('content-type') || '').toLowerCase();

  let bytes: Uint8Array;
  let mimeType = '';

  if (reqContentType.includes('multipart/form-data')) {
    const form = await c.req.formData();
    const file = form.get('file');
    if (!file || typeof (file as Blob).arrayBuffer !== 'function') {
      return c.json(
        { error: 'INVALID_REQUEST', message: 'Missing multipart file field' },
        400,
      );
    }
    const fileBlob = file as Blob;
    mimeType = (fileBlob.type || '').split(';')[0].trim().toLowerCase();
    bytes = new Uint8Array(await fileBlob.arrayBuffer());
  } else {
    mimeType = reqContentType.split(';')[0].trim().toLowerCase();
    bytes = new Uint8Array(await c.req.arrayBuffer());
  }

  const ext = ALLOWED_SOCIAL_MEDIA_MIMES[mimeType];
  if (!ext) {
    return c.json(
      {
        error: 'UNSUPPORTED_MEDIA_TYPE',
        message: `Unsupported MIME type: ${mimeType || 'unknown'}`,
      },
      415,
    );
  }
  if (bytes.byteLength === 0) {
    return c.json(
      { error: 'INVALID_REQUEST', message: 'Empty media payload' },
      400,
    );
  }
  if (bytes.byteLength > MAX_SOCIAL_MEDIA_BYTES) {
    return c.json(
      {
        error: 'PAYLOAD_TOO_LARGE',
        message: 'Media payload exceeds 25 MB limit',
      },
      413,
    );
  }

  const objectKey = `social/${creatorId}/${Date.now()}_${nanoid(8)}.${ext}`;
  const stored = await uploadBytesToR2(objectKey, bytes, mimeType, c);
  const remoteUrl = `/r2/${stored.key}`;
  const uploadedFilename = stored.key.split('/').pop() ?? `upload.${ext}`;
  await vhunambiDb.recordUserMediaUploadAsync(
    {
      id: `upl_soc_${Date.now()}_${nanoid(8)}`,
      creatorId,
      mediaKind: inferMediaKindFromMime(mimeType),
      title: 'Social Media Upload',
      filename: uploadedFilename,
      mimeType,
      sizeBytes: bytes.byteLength,
      r2Key: stored.key,
      remoteUrl,
      sourceSurface: 'social',
    },
    c,
  );
  return c.json(
    {
      success: true,
      key: stored.key,
      url: remoteUrl,
      contentType: mimeType,
      size: bytes.byteLength,
    },
    201,
  );
});

// POST /api/social/publish — 1-tap in-house publish (REQ-SOC-01 / REQ-P74-BE-03)
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
    const result = await publishClipAsync(
      {
        ...parsed.data,
        creatorId: authUser
          ? resolveEffectiveCreatorId(c, parsed.data.creatorId, authUser.creatorId)
          : parsed.data.creatorId,
        creatorUsername:
          parsed.data.creatorUsername ||
          (authUser ? authUser.handle.replace(/^@/, '') : undefined),
      },
      c,
    );
    return c.json({ success: true, ...result }, 201);
  } catch (error) {
    console.error('[Social Publish Error]', error);
    return c.json(
      { error: 'PUBLISH_ERROR', message: 'Failed to publish clip' },
      500,
    );
  }
});

// GET /api/social/feed — cursor-paginated discovery feed (REQ-SOC-16 / REQ-SOC-22 / REQ-P74-BE-02)
socialRoutes.get('/social/feed', async (c) => {
  await vhunambiDb.syncSocialFromCloud(false, c);
  const cursor = c.req.query('cursor');
  const limit = Number.parseInt(c.req.query('limit') ?? '20', 10);
  const viewerId = c.get('authUser')?.creatorId ?? 'creator_cern';
  const page = getFeed(cursor, Number.isFinite(limit) ? limit : 20, viewerId);
  return c.json(page, 200);
});

// GET /api/social/clips/:id — single clip detail with SWR read-through (REQ-P74-BE-02)
socialRoutes.get('/social/clips/:id', async (c) => {
  await vhunambiDb.syncSocialFromCloud(false, c);
  const id = c.req.param('id');
  const viewerId = c.get('authUser')?.creatorId ?? 'creator_cern';
  const clip = getClipById(id, viewerId);
  if (!clip) {
    return c.json(
      { error: 'NOT_FOUND', message: `Clip ${id} not found` },
      404,
    );
  }
  return c.json(clip, 200);
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

// POST /api/social/clips/:id/react — 6-type clip multi-reaction toggle/switch (REQ-P74-BE-03)
socialRoutes.post('/social/clips/:id/react', async (c) => {
  const id = c.req.param('id');
  let body: Record<string, unknown> = {};
  try {
    body = (await c.req.json()) as Record<string, unknown>;
  } catch (_) { }
  const rawReaction = body.reactionType ?? body.reaction ?? null;
  if (rawReaction !== null && rawReaction !== undefined) {
    const normalized = normalizeKineticReactionWire(rawReaction);
    if (!normalized || !VALID_KINETIC_REACTIONS.has(normalized)) {
      return c.json(
        {
          error: 'INVALID_REACTION',
          message: `Unsupported reactionType: ${String(rawReaction)}`,
        },
        400,
      );
    }
  }
  const reactionType =
    rawReaction === null || rawReaction === undefined
      ? null
      : normalizeKineticReactionWire(rawReaction);
  const actorId = c.get('authUser')?.creatorId ?? 'creator_cern';
  const result = await reactToClipAsync(id, actorId, reactionType, c);
  if (!result.success) {
    return c.json(
      { error: 'NOT_FOUND', message: `Clip ${id} not found` },
      404,
    );
  }
  return c.json(result, 200);
});

// GET /api/social/clips/:id/remixes — remix lineage children (Phase 37 REQ-RMX-TREE-01, deduplicated)
socialRoutes.get('/social/clips/:id/remixes', async (c) => {
  await vhunambiDb.syncSocialFromCloud(false, c);
  const id = c.req.param('id');
  const remixes = getClipRemixes(id);
  return c.json({ clipId: id, count: remixes.length, remixes }, 200);
});

// GET /api/social/clips/:id/comments — thread comments (REQ-COM-01 / REQ-P74-BE-02)
socialRoutes.get('/social/clips/:id/comments', async (c) => {
  await vhunambiDb.syncSocialFromCloud(false, c);
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

// GET /api/creators/:id/clips — creator reel grid source (REQ-SOC-23 / REQ-P74-BE-02)
socialRoutes.get('/creators/:id/clips', async (c) => {
  await vhunambiDb.syncSocialFromCloud(false, c);
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
