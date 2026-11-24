import { Hono } from 'hono';
import { nanoid } from 'nanoid';
import {
  canonicalizeCreatorId,
  vhunambiDb,
  type MediaUploadKindWire,
} from '../db/vhunambi_db.js';
import {
  assertTenantCreatorAccess,
  resolveEffectiveCreatorId,
  sovereignAuthMiddleware,
} from '../middleware/auth_middleware.js';
import { uploadBytesToR2 } from '../modules/synthesis/r2_storage.js';

export const MAX_MEDIA_UPLOAD_BYTES = 25 * 1024 * 1024;

export const ALLOWED_MEDIA_UPLOAD_MIMES: Record<string, string> = {
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

export function inferMediaKindFromMime(mimeType: string): MediaUploadKindWire {
  if (mimeType.startsWith('audio/')) return 'audio';
  if (mimeType.startsWith('video/')) return 'video';
  return 'image';
}

export const mediaRoutes = new Hono();
mediaRoutes.use('*', sovereignAuthMiddleware);

// POST /api/media/upload
mediaRoutes.post('/upload', async (c) => {
  const authUser = c.get('authUser');
  const creatorId = canonicalizeCreatorId(authUser?.creatorId ?? 'creator_cern');
  const reqContentType = (c.req.header('content-type') || '').toLowerCase();

  let bytes: Uint8Array;
  let mimeType = '';
  let filename = c.req.header('x-media-filename') || '';
  let title = c.req.header('x-media-title') || '';
  let sourceSurface = c.req.header('x-media-surface') || 'vault';
  let durationMs: number | null = null;
  let width: number | null = null;
  let height: number | null = null;
  let thumbnailUrl: string | null = null;

  if (reqContentType.includes('multipart/form-data')) {
    const form = await c.req.formData();
    const file = form.get('file');
    if (!file || typeof (file as Blob).arrayBuffer !== 'function') {
      return c.json(
        { error: 'INVALID_REQUEST', message: 'Missing multipart file field' },
        400,
      );
    }
    const fileBlob = file as Blob & { name?: string };
    mimeType = (fileBlob.type || '').split(';')[0].trim().toLowerCase();
    filename = String(form.get('filename') ?? fileBlob.name ?? filename ?? '').trim();
    title = String(form.get('title') ?? title ?? '').trim();
    sourceSurface = String(form.get('sourceSurface') ?? sourceSurface ?? 'vault').trim();
    const rawDur = form.get('durationMs');
    if (rawDur != null && String(rawDur).trim() !== '') {
      const parsed = Number.parseInt(String(rawDur), 10);
      if (Number.isFinite(parsed) && parsed > 0) durationMs = parsed;
    }
    const rawW = form.get('width');
    if (rawW != null && String(rawW).trim() !== '') {
      const parsed = Number.parseInt(String(rawW), 10);
      if (Number.isFinite(parsed) && parsed > 0) width = parsed;
    }
    const rawH = form.get('height');
    if (rawH != null && String(rawH).trim() !== '') {
      const parsed = Number.parseInt(String(rawH), 10);
      if (Number.isFinite(parsed) && parsed > 0) height = parsed;
    }
    const rawThumb = form.get('thumbnailUrl');
    if (rawThumb != null && String(rawThumb).trim() !== '') {
      thumbnailUrl = String(rawThumb).trim();
    }
    bytes = new Uint8Array(await fileBlob.arrayBuffer());
  } else {
    mimeType = reqContentType.split(';')[0].trim().toLowerCase();
    bytes = new Uint8Array(await c.req.arrayBuffer());
  }

  const ext = ALLOWED_MEDIA_UPLOAD_MIMES[mimeType];
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
  if (bytes.byteLength > MAX_MEDIA_UPLOAD_BYTES) {
    return c.json(
      {
        error: 'PAYLOAD_TOO_LARGE',
        message: 'Media payload exceeds 25 MB limit',
      },
      413,
    );
  }

  const id = `upl_${Date.now()}_${nanoid(8)}`;
  const mediaKind = inferMediaKindFromMime(mimeType);
  const safeFilename = filename || `${id}.${ext}`;
  const resolvedTitle =
    title ||
    safeFilename.replace(/\.[^.]+$/, '').replace(/[_-]+/g, ' ').trim() ||
    'Uploaded Media';
  const objectKey = `media/${creatorId}/${id}.${ext}`;
  const stored = await uploadBytesToR2(objectKey, bytes, mimeType, c);
  const remoteUrl = `/r2/${stored.key}`;

  const asset = await vhunambiDb.recordUserMediaUploadAsync(
    {
      id,
      creatorId,
      mediaKind,
      title: resolvedTitle,
      filename: safeFilename,
      mimeType,
      sizeBytes: bytes.byteLength,
      durationMs,
      width,
      height,
      r2Key: stored.key,
      remoteUrl,
      thumbnailUrl,
      sourceSurface: sourceSurface || 'vault',
    },
    c,
  );

  return c.json(
    {
      success: true,
      asset,
      key: stored.key,
      url: remoteUrl,
      contentType: mimeType,
      size: bytes.byteLength,
    },
    201,
  );
});

// GET /api/media/uploads?creatorId=...&kind=audio|video|image
mediaRoutes.get('/uploads', async (c) => {
  const requestedId = c.req.query('creatorId');
  const forbidden = assertTenantCreatorAccess(c, requestedId);
  if (forbidden) return forbidden;

  const creatorId = resolveEffectiveCreatorId(c, requestedId, 'creator_cern');
  await vhunambiDb.syncUserMediaUploadsFromCloud(creatorId, c);

  const kindParam = (c.req.query('kind') || '').trim().toLowerCase();
  const kindFilter: MediaUploadKindWire | undefined =
    kindParam === 'audio' || kindParam === 'video' || kindParam === 'image'
      ? kindParam
      : undefined;

  const uploads = vhunambiDb.listUserMediaUploads(creatorId, kindFilter);
  return c.json({
    success: true,
    creatorId,
    uploads,
    count: uploads.length,
  });
});

// DELETE /api/media/uploads/:id
mediaRoutes.delete('/uploads/:id', async (c) => {
  const id = c.req.param('id');
  const requestedCreatorId = c.req.query('creatorId');
  const forbiddenQuery = assertTenantCreatorAccess(c, requestedCreatorId);
  if (forbiddenQuery) return forbiddenQuery;

  const authUser = c.get('authUser');
  const effectiveCreatorId = authUser
    ? authUser.creatorId
    : resolveEffectiveCreatorId(c, requestedCreatorId, 'creator_cern');

  await vhunambiDb.syncUserMediaUploadsFromCloud(effectiveCreatorId, c);
  const existing = vhunambiDb.getUserMediaUploadById(id);
  if (!existing) {
    return c.json({ success: false, error: 'Media upload not found', id }, 404);
  }
  if (
    authUser &&
    canonicalizeCreatorId(existing.creatorId) !==
      canonicalizeCreatorId(authUser.creatorId) &&
    authUser.role !== 'admin'
  ) {
    return c.json(
      {
        error: `Forbidden: Media upload '${id}' belongs to '${existing.creatorId}'.`,
        code: 'TENANT_FORBIDDEN',
      },
      403,
    );
  }

  await vhunambiDb.deleteUserMediaUploadAsync(id, existing.creatorId, c);
  return c.json({ success: true, id });
});
