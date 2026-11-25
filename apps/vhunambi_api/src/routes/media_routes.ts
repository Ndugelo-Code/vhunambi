import { Hono, type Context } from 'hono';
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
import {
  extractId3v2Metadata,
  ID3_INITIAL_RANGE_BYTES,
  ID3_MAX_RANGE_BYTES,
  readId3TagByteLength,
} from '../modules/media/id3v2_parser.js';
import {
  fetchR2ByteRange,
  getPresignedPutUrl,
  hasR2Credentials,
  uploadBytesToR2,
} from '../modules/synthesis/r2_storage.js';

export const MAX_MEDIA_UPLOAD_BYTES = 25 * 1024 * 1024;
export const MAX_DIRECT_R2_UPLOAD_BYTES = 100 * 1024 * 1024;
export const MAX_IMAGE_UPLOAD_BYTES = 25 * 1024 * 1024;

export const ALLOWED_MEDIA_UPLOAD_MIMES: Record<string, string> = {
  'video/mp4': 'mp4',
  'video/quicktime': 'mov',
  'video/webm': 'webm',
  'image/jpeg': 'jpg',
  'image/jpg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
  'audio/mpeg': 'mp3',
  'audio/mp4': 'm4a',
  'audio/wav': 'wav',
  'audio/x-wav': 'wav',
  'audio/wave': 'wav',
  'audio/aac': 'aac',
  'audio/ogg': 'ogg',
  'audio/flac': 'flac',
};

export function inferMediaKindFromMime(mimeType: string): MediaUploadKindWire {
  if (mimeType.startsWith('audio/')) return 'audio';
  if (mimeType.startsWith('video/')) return 'video';
  return 'image';
}

interface ExtractedUploadEnrichment {
  thumbnailUrl: string | null;
  id3Title?: string;
  id3Metadata: Record<string, unknown>;
}

async function extractAndPersistAudioId3FromBytes(
  params: {
    creatorId: string;
    uploadId: string;
    r2Key: string;
    mimeType: string;
    existingThumbnailUrl: string | null;
    initialBytes: Uint8Array;
    allowRangeExtension: boolean;
  },
  c: Context,
): Promise<ExtractedUploadEnrichment> {
  if (!params.mimeType.startsWith('audio/')) {
    return { thumbnailUrl: params.existingThumbnailUrl, id3Metadata: {} };
  }

  let inspectionBytes = params.initialBytes;
  const declaredLen = readId3TagByteLength(inspectionBytes);
  if (
    params.allowRangeExtension &&
    declaredLen !== null &&
    declaredLen > inspectionBytes.byteLength &&
    declaredLen <= ID3_MAX_RANGE_BYTES
  ) {
    const extRange = await fetchR2ByteRange(
      params.r2Key,
      inspectionBytes.byteLength,
      declaredLen - 1,
      c,
    );
    if (extRange && extRange.bytes.byteLength > 0) {
      const combined = new Uint8Array(
        inspectionBytes.byteLength + extRange.bytes.byteLength,
      );
      combined.set(inspectionBytes, 0);
      combined.set(extRange.bytes, inspectionBytes.byteLength);
      inspectionBytes = combined;
    }
  }

  const parsed = extractId3v2Metadata(inspectionBytes);
  if (!parsed) {
    return { thumbnailUrl: params.existingThumbnailUrl, id3Metadata: {} };
  }

  let resolvedThumb = params.existingThumbnailUrl;
  if (!resolvedThumb && parsed.apic) {
    const coverKey = `covers/${params.creatorId}/${params.uploadId}.${parsed.apic.ext}`;
    const storedCover = await uploadBytesToR2(
      coverKey,
      parsed.apic.imageData,
      parsed.apic.mimeType,
      c,
    );
    resolvedThumb = `/r2/${storedCover.key}`;
  }

  const id3Metadata: Record<string, unknown> = {
    version: parsed.version,
    ...(parsed.title ? { title: parsed.title } : {}),
    ...(parsed.artist ? { artist: parsed.artist } : {}),
    ...(parsed.album ? { album: parsed.album } : {}),
    ...(parsed.genre ? { genre: parsed.genre } : {}),
    ...(parsed.bpm ? { bpm: parsed.bpm } : {}),
    ...(parsed.lyrics ? { lyrics: parsed.lyrics } : {}),
    hasEmbeddedCover: Boolean(parsed.apic),
  };

  return {
    thumbnailUrl: resolvedThumb,
    id3Title: parsed.title,
    id3Metadata,
  };
}

export const mediaRoutes = new Hono();
mediaRoutes.use('*', sovereignAuthMiddleware);

// POST /api/media/presign-put — Direct-to-R2 SigV4 PUT minting (EP-P84-R2-PRESIGN-DIRECT)
mediaRoutes.post('/presign-put', async (c) => {
  const authUser = c.get('authUser');
  const creatorId = canonicalizeCreatorId(authUser?.creatorId ?? 'creator_cern');
  const body = (await c.req.json().catch(() => null)) as Record<string, unknown> | null;
  if (!body) {
    return c.json({ error: 'INVALID_REQUEST', message: 'Invalid JSON body' }, 400);
  }

  const mimeType = String(body.mimeType ?? '').split(';')[0].trim().toLowerCase();
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

  const sizeBytes = Number(body.sizeBytes ?? 0);
  const mediaKind = inferMediaKindFromMime(mimeType);
  const maxBytes =
    mediaKind === 'image' ? MAX_IMAGE_UPLOAD_BYTES : MAX_DIRECT_R2_UPLOAD_BYTES;
  if (!Number.isFinite(sizeBytes) || sizeBytes <= 0) {
    return c.json({ error: 'INVALID_REQUEST', message: 'sizeBytes must be > 0' }, 400);
  }
  if (sizeBytes > maxBytes) {
    return c.json(
      {
        error: 'PAYLOAD_TOO_LARGE',
        message: `Media exceeds ${Math.round(maxBytes / (1024 * 1024))} MB limit`,
      },
      413,
    );
  }

  const contentSha256 =
    typeof body.contentSha256 === 'string' && body.contentSha256.trim().length >= 32
      ? body.contentSha256.trim().toLowerCase()
      : null;

  if (contentSha256) {
    await vhunambiDb.syncUserMediaUploadsFromCloud(creatorId, c);
    const existing = vhunambiDb.findUserMediaUploadBySha256(creatorId, contentSha256);
    if (existing) {
      return c.json(
        {
          success: true,
          deduplicated: true,
          uploadId: existing.id,
          r2Key: existing.r2Key,
          remoteUrl: existing.remoteUrl,
          asset: existing,
        },
        200,
      );
    }
  }

  const uploadId = `upl_${Date.now()}_${nanoid(8)}`;
  const r2Key = `media/${creatorId}/${uploadId}.${ext}`;
  const remoteUrl = `/r2/${r2Key}`;
  const canPresign = hasR2Credentials(c);
  const putUrl = canPresign
    ? await getPresignedPutUrl(r2Key, mimeType, 3600, c)
    : null;

  return c.json(
    {
      success: true,
      deduplicated: false,
      uploadId,
      r2Key,
      remoteUrl,
      putUrl,
      uploadStrategy: canPresign ? 'r2_presigned_put' : 'worker_binary',
      expiresInSec: 3600,
    },
    201,
  );
});

// POST /api/media/finalize — Verifies R2 object, extracts ID3v2 APIC + tags, commits DB
mediaRoutes.post('/finalize', async (c) => {
  const authUser = c.get('authUser');
  const creatorId = canonicalizeCreatorId(authUser?.creatorId ?? 'creator_cern');
  const body = (await c.req.json().catch(() => null)) as Record<string, unknown> | null;
  if (!body) {
    return c.json({ error: 'INVALID_REQUEST', message: 'Invalid JSON body' }, 400);
  }

  const uploadId =
    String(body.uploadId ?? '').trim() || `upl_${Date.now()}_${nanoid(8)}`;
  const r2Key = String(body.r2Key ?? '').replace(/^\/+/, '').trim();
  const mimeType = String(body.mimeType ?? '').split(';')[0].trim().toLowerCase();
  const ext = ALLOWED_MEDIA_UPLOAD_MIMES[mimeType];
  if (!r2Key || !ext) {
    return c.json(
      {
        error: 'INVALID_REQUEST',
        message: 'Valid r2Key and supported mimeType are required',
      },
      400,
    );
  }
  if (!r2Key.startsWith(`media/${creatorId}/`) && authUser?.role !== 'admin') {
    return c.json(
      {
        error: 'TENANT_FORBIDDEN',
        message: 'r2Key does not match authenticated creator namespace',
      },
      403,
    );
  }

  const rangeRes = await fetchR2ByteRange(
    r2Key,
    0,
    ID3_INITIAL_RANGE_BYTES - 1,
    c,
  );
  if (!rangeRes) {
    return c.json(
      {
        error: 'OBJECT_NOT_FOUND',
        message: `Uploaded object not found in R2: ${r2Key}`,
      },
      404,
    );
  }

  const filename = String(body.filename ?? '').trim() || `${uploadId}.${ext}`;
  const explicitTitle = String(body.title ?? '').trim();
  const explicitThumb =
    typeof body.thumbnailUrl === 'string' && body.thumbnailUrl.trim()
      ? body.thumbnailUrl.trim()
      : null;

  const enrichment = await extractAndPersistAudioId3FromBytes(
    {
      creatorId,
      uploadId,
      r2Key,
      mimeType,
      existingThumbnailUrl: explicitThumb,
      initialBytes: rangeRes.bytes,
      allowRangeExtension: true,
    },
    c,
  );

  const fallbackTitle =
    filename.replace(/\.[^.]+$/, '').replace(/[_-]+/g, ' ').trim() ||
    'Uploaded Media';
  const resolvedTitle = explicitTitle || enrichment.id3Title || fallbackTitle;
  const sizeBytes =
    rangeRes.totalSize ??
    Math.max(1, Math.round(Number(body.sizeBytes ?? rangeRes.bytes.byteLength)));
  const remoteUrl = `/r2/${r2Key}`;

  const asset = await vhunambiDb.recordUserMediaUploadAsync(
    {
      id: uploadId,
      creatorId,
      mediaKind: inferMediaKindFromMime(mimeType),
      title: resolvedTitle,
      filename,
      mimeType,
      sizeBytes,
      durationMs:
        typeof body.durationMs === 'number' && body.durationMs > 0
          ? Math.round(body.durationMs)
          : null,
      width:
        typeof body.width === 'number' && body.width > 0
          ? Math.round(body.width)
          : null,
      height:
        typeof body.height === 'number' && body.height > 0
          ? Math.round(body.height)
          : null,
      r2Key,
      remoteUrl,
      thumbnailUrl: enrichment.thumbnailUrl,
      sourceSurface: String(body.sourceSurface ?? 'vault').trim() || 'vault',
      id3Metadata: enrichment.id3Metadata,
      contentSha256:
        typeof body.contentSha256 === 'string' && body.contentSha256.trim()
          ? body.contentSha256.trim().toLowerCase()
          : null,
    },
    c,
  );

  return c.json(
    {
      success: true,
      asset,
      key: r2Key,
      url: remoteUrl,
      thumbnailUrl: enrichment.thumbnailUrl,
      id3Metadata: enrichment.id3Metadata,
    },
    201,
  );
});

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
  let contentSha256: string | null =
    (c.req.header('x-media-sha256') || '').trim().toLowerCase() || null;

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
    const rawSha = form.get('contentSha256');
    if (rawSha != null && String(rawSha).trim() !== '') {
      contentSha256 = String(rawSha).trim().toLowerCase();
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
  const objectKey = `media/${creatorId}/${id}.${ext}`;
  const stored = await uploadBytesToR2(objectKey, bytes, mimeType, c);
  const remoteUrl = `/r2/${stored.key}`;

  const enrichment = await extractAndPersistAudioId3FromBytes(
    {
      creatorId,
      uploadId: id,
      r2Key: stored.key,
      mimeType,
      existingThumbnailUrl: thumbnailUrl,
      initialBytes: bytes.subarray(0, Math.min(bytes.byteLength, ID3_MAX_RANGE_BYTES)),
      allowRangeExtension: false,
    },
    c,
  );

  const resolvedTitle =
    title ||
    enrichment.id3Title ||
    safeFilename.replace(/\.[^.]+$/, '').replace(/[_-]+/g, ' ').trim() ||
    'Uploaded Media';

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
      thumbnailUrl: enrichment.thumbnailUrl,
      sourceSurface: sourceSurface || 'vault',
      id3Metadata: enrichment.id3Metadata,
      contentSha256,
    },
    c,
  );

  return c.json(
    {
      success: true,
      asset,
      key: stored.key,
      url: remoteUrl,
      thumbnailUrl: enrichment.thumbnailUrl,
      id3Metadata: enrichment.id3Metadata,
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
