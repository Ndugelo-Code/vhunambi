# Phase 84 Engineering Design Specification — Direct-to-R2 Presigned Pipeline, Pure Edge ID3v2 Extractor, Kinetic Reels 98% Fix, Kinetic Post Uploads & Zania Music Flywheel

> **Spec Suite ID:** `SPEC-P84-MEDIA-ID3-REELS98-KPOST`  
> **Companion Documents:** `blueprint.md`, `requirements.md`, `tasks.md`, `memory.md`  
> **Implementation Standard:** Complete, compilable TypeScript / SQL / Dart / Node 24 code blocks with zero `// TODO` stubs, zero React/D1/Node-`fs` leakage into Cloudflare Workers, and 100% `STD-UIUX-001` compliance (`package:vhunambi_client/...`, `package:phosphor_icons/phosphor_icons.dart`, `AppColors.*Of(context)`, valid `AppTypography.*` getters, zero raw Unicode emojis).

---

## §1. Database Schema & Additive Supabase Migration

### 1.1 `supabase/migrations/20261125000001_phase84_media_id3_and_zania_ingest.sql`

Adds additive columns and deduplication indexes to `public.user_media_uploads` and `public.explore_tracks` while preserving Phase 79 RLS policies (`((SELECT auth.jwt()) ->> 'creator_id') = creator_id`).

```sql
-- ============================================================================
-- VHUNAMBI PHASE 84: EDGE ID3V2 METADATA, SHA-256 DEDUPE & ZANIA INGEST SCHEMA
-- Migration: 20261125000001_phase84_media_id3_and_zania_ingest.sql
-- ============================================================================

-- 1. Extend public.user_media_uploads with ID3v2 metadata & content SHA-256
ALTER TABLE public.user_media_uploads
  ADD COLUMN IF NOT EXISTS id3_metadata_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS content_sha256 TEXT;

CREATE INDEX IF NOT EXISTS idx_user_media_uploads_creator_sha256
  ON public.user_media_uploads (creator_id, content_sha256)
  WHERE content_sha256 IS NOT NULL AND deleted_at IS NULL;

-- 2. Extend public.explore_tracks with deduplication hash, source origin & lyrics
ALTER TABLE public.explore_tracks
  ADD COLUMN IF NOT EXISTS content_sha256 TEXT,
  ADD COLUMN IF NOT EXISTS source_origin TEXT NOT NULL DEFAULT 'vhunambi_studio',
  ADD COLUMN IF NOT EXISTS lyrics_text TEXT NOT NULL DEFAULT '';

CREATE UNIQUE INDEX IF NOT EXISTS idx_explore_tracks_creator_sha256
  ON public.explore_tracks (creator_id, content_sha256)
  WHERE content_sha256 IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_explore_tracks_source_origin
  ON public.explore_tracks (source_origin, created_at DESC);

-- 3. Ensure public.kinetic_posts supports full media persistence indexes
CREATE INDEX IF NOT EXISTS idx_kinetic_posts_creator_created
  ON public.kinetic_posts (creator_id, created_at DESC);
```

---

## §2. Pure Edge Media Modules (`apps/vhunambi_api/src/modules/media/`)

Zero Node.js `fs`, `path`, or `Buffer` imports — 100% Cloudflare Workers (`workerd`) native.

### 2.1 `apps/vhunambi_api/src/modules/media/id3v2_parser.ts` (New)

Ports and extends Zania Explore's `scripts/lib/id3v2-parser.ts` to decode `APIC` (including `'image/jpg'` normalization), `TIT2`, `TPE1`, `TALB`, `TCON`, `TBPM`, and `USLT`, with bounded window length inspection (`readId3TagByteLength`) and Unicode NFC normalization for Tshivenḓa diacritics (`ḓ`, `ḽ`, `ṋ`, `ṅ`, `ṱ`).

```typescript
/**
 * VHUNAMBI Phase 84 — Pure Edge ID3v2.3 / ID3v2.4 Metadata & APIC Cover Extractor
 *
 * Uses exclusively Uint8Array, DataView, and TextDecoder (zero Node fs/Buffer)
 * so it runs natively inside Cloudflare Workers isolates.
 */

export type SupportedCoverMime = 'image/jpeg' | 'image/png' | 'image/webp';

export interface ApicExtraction {
  imageData: Uint8Array;
  mimeType: SupportedCoverMime;
  ext: 'jpg' | 'png' | 'webp';
}

export interface Id3v2MetadataResult {
  version: 3 | 4;
  tagByteLength: number;
  title?: string;
  artist?: string;
  album?: string;
  genre?: string;
  bpm?: number;
  lyrics?: string;
  apic: ApicExtraction | null;
}

export const ID3_INITIAL_RANGE_BYTES = 262_144; // 256 KiB
export const ID3_MAX_RANGE_BYTES = 2_097_152; // 2 MiB hard isolate cap

function readSynchSafeInt(data: Uint8Array, offset: number): number {
  return (
    ((data[offset] & 0x7f) << 21) |
    ((data[offset + 1] & 0x7f) << 14) |
    ((data[offset + 2] & 0x7f) << 7) |
    (data[offset + 3] & 0x7f)
  );
}

function readBigEndianUint32(data: Uint8Array, offset: number): number {
  return (
    (((data[offset] & 0xff) << 24) |
      ((data[offset + 1] & 0xff) << 16) |
      ((data[offset + 2] & 0xff) << 8) |
      (data[offset + 3] & 0xff)) >>>
    0
  );
}

function decodeEncodedBytes(bytes: Uint8Array, encoding: number): string {
  if (bytes.length === 0) return '';
  if (encoding === 1) {
    // UTF-16 with BOM
    if (bytes.length >= 2 && bytes[0] === 0xfe && bytes[1] === 0xff) {
      return new TextDecoder('utf-16be').decode(bytes.subarray(2));
    }
    if (bytes.length >= 2 && bytes[0] === 0xff && bytes[1] === 0xfe) {
      return new TextDecoder('utf-16le').decode(bytes.subarray(2));
    }
    return new TextDecoder('utf-16le').decode(bytes);
  }
  if (encoding === 2) {
    return new TextDecoder('utf-16be').decode(bytes);
  }
  if (encoding === 3) {
    return new TextDecoder('utf-8').decode(bytes);
  }
  return new TextDecoder('iso-8859-1').decode(bytes);
}

function readNullTerminatedString(
  data: Uint8Array,
  offset: number,
  encoding: number,
): { value: string; bytesConsumed: number } {
  if (encoding === 1 || encoding === 2) {
    let end = offset;
    while (end + 1 < data.length) {
      if (data[end] === 0x00 && data[end + 1] === 0x00) {
        break;
      }
      end += 2;
    }
    const slice = data.subarray(offset, end);
    const value = decodeEncodedBytes(slice, encoding);
    const consumed = Math.min(data.length - offset, end - offset + 2);
    return { value, bytesConsumed: consumed };
  }

  let end = offset;
  while (end < data.length && data[end] !== 0x00) {
    end++;
  }
  const slice = data.subarray(offset, end);
  const value = decodeEncodedBytes(slice, encoding);
  const consumed = Math.min(data.length - offset, end - offset + 1);
  return { value, bytesConsumed: consumed };
}

function normalizeApicMime(rawMime: string): {
  mimeType: SupportedCoverMime;
  ext: 'jpg' | 'png' | 'webp';
} | null {
  const cleaned = rawMime.trim().toLowerCase();
  if (cleaned === 'image/jpeg' || cleaned === 'image/jpg' || cleaned === 'jpg') {
    return { mimeType: 'image/jpeg', ext: 'jpg' };
  }
  if (cleaned === 'image/png' || cleaned === 'png') {
    return { mimeType: 'image/png', ext: 'png' };
  }
  if (cleaned === 'image/webp' || cleaned === 'webp') {
    return { mimeType: 'image/webp', ext: 'webp' };
  }
  return null;
}

function detectMimeFromMagicBytes(imageData: Uint8Array): {
  mimeType: SupportedCoverMime;
  ext: 'jpg' | 'png' | 'webp';
} | null {
  if (imageData.length >= 3 && imageData[0] === 0xff && imageData[1] === 0xd8 && imageData[2] === 0xff) {
    return { mimeType: 'image/jpeg', ext: 'jpg' };
  }
  if (
    imageData.length >= 8 &&
    imageData[0] === 0x89 &&
    imageData[1] === 0x50 &&
    imageData[2] === 0x4e &&
    imageData[3] === 0x47
  ) {
    return { mimeType: 'image/png', ext: 'png' };
  }
  if (
    imageData.length >= 12 &&
    imageData[0] === 0x52 &&
    imageData[1] === 0x49 &&
    imageData[2] === 0x46 &&
    imageData[3] === 0x46 &&
    imageData[8] === 0x57 &&
    imageData[9] === 0x45 &&
    imageData[10] === 0x42 &&
    imageData[11] === 0x50
  ) {
    return { mimeType: 'image/webp', ext: 'webp' };
  }
  return null;
}

function parseApicFrameData(frameData: Uint8Array): ApicExtraction | null {
  if (frameData.length < 4) return null;
  let pos = 0;
  const encoding = frameData[pos++];
  const mimeResult = readNullTerminatedString(frameData, pos, 0);
  pos += mimeResult.bytesConsumed;
  if (pos >= frameData.length) return null;

  // Picture type byte (0x03 = Front cover preferred, any valid accepted)
  pos++;
  if (pos >= frameData.length) return null;

  const descResult = readNullTerminatedString(frameData, pos, encoding);
  pos += descResult.bytesConsumed;
  if (pos >= frameData.length) return null;

  const imageData = frameData.slice(pos);
  if (imageData.length < 16) return null;

  const resolvedMime =
    normalizeApicMime(mimeResult.value) ?? detectMimeFromMagicBytes(imageData);
  if (!resolvedMime) return null;

  return {
    imageData,
    mimeType: resolvedMime.mimeType,
    ext: resolvedMime.ext,
  };
}

function parseTextFrame(frameData: Uint8Array): string {
  if (frameData.length < 2) return '';
  const encoding = frameData[0];
  let end = frameData.length;
  // Strip trailing NUL padding bytes
  while (end > 1 && frameData[end - 1] === 0x00) {
    end--;
  }
  const decoded = decodeEncodedBytes(frameData.subarray(1, end), encoding);
  return decoded.replace(/\u0000+/g, '').trim().normalize('NFC');
}

function parseUsltFrame(frameData: Uint8Array): string {
  // Byte 0: encoding, Bytes 1-3: ISO-639-2 language, then null-term descriptor, then lyrics
  if (frameData.length < 6) return '';
  const encoding = frameData[0];
  let pos = 4;
  const desc = readNullTerminatedString(frameData, pos, encoding);
  pos += desc.bytesConsumed;
  if (pos >= frameData.length) return '';
  const raw = decodeEncodedBytes(frameData.subarray(pos), encoding);
  return raw.replace(/\u0000+/g, '').trim().normalize('NFC');
}

function cleanGenreTag(raw: string): string {
  // Convert ID3v1 "(17)Rock" or "(12)Other" cleanly
  const stripped = raw.replace(/^\(\d+\)\s*/, '').trim();
  return stripped || raw.trim();
}

/**
 * Inspects the first 10 bytes of an MP3 buffer and returns the full ID3v2
 * byte length (10 + synchsafe tagSize), or null if no ID3v2.3/v2.4 header exists.
 */
export function readId3TagByteLength(data: Uint8Array): number | null {
  if (data.length < 10) return null;
  if (data[0] !== 0x49 || data[1] !== 0x44 || data[2] !== 0x33) return null;
  const majorVersion = data[3];
  if (majorVersion !== 3 && majorVersion !== 4) return null;
  const tagSize = readSynchSafeInt(data, 6);
  return 10 + tagSize;
}

/**
 * Extracts embedded APIC cover art and core text/lyric frames from raw ID3v2 bytes.
 * Safely handles partial range windows by clamping frame iteration at data.length.
 */
export function extractId3v2Metadata(data: Uint8Array): Id3v2MetadataResult | null {
  const tagByteLength = readId3TagByteLength(data);
  if (tagByteLength === null) return null;

  const majorVersion = data[3] as 3 | 4;
  const flags = data[5];
  const hasExtendedHeader = (flags & 0x40) !== 0;
  const tagEnd = Math.min(data.length, tagByteLength);

  let offset = 10;
  if (hasExtendedHeader) {
    if (offset + 4 > tagEnd) return null;
    const extHeaderSize =
      majorVersion === 4
        ? readSynchSafeInt(data, offset)
        : readBigEndianUint32(data, offset);
    offset += majorVersion === 4 ? extHeaderSize : 4 + extHeaderSize;
  }

  const result: Id3v2MetadataResult = {
    version: majorVersion,
    tagByteLength,
    apic: null,
  };

  const asciiDecoder = new TextDecoder('iso-8859-1');

  while (offset + 10 <= tagEnd) {
    if (data[offset] === 0x00) break;

    const frameId = asciiDecoder.decode(data.subarray(offset, offset + 4));
    offset += 4;

    const frameSize =
      majorVersion === 4
        ? readSynchSafeInt(data, offset)
        : readBigEndianUint32(data, offset);
    offset += 4;

    // 2 bytes frame flags
    offset += 2;

    if (frameSize <= 0) continue;
    if (offset + frameSize > tagEnd) break;

    const frameData = data.subarray(offset, offset + frameSize);

    if (frameId === 'APIC' && result.apic === null) {
      result.apic = parseApicFrameData(frameData);
    } else if (frameId === 'TIT2' && !result.title) {
      const val = parseTextFrame(frameData);
      if (val) result.title = val;
    } else if (frameId === 'TPE1' && !result.artist) {
      const val = parseTextFrame(frameData);
      if (val) result.artist = val;
    } else if (frameId === 'TALB' && !result.album) {
      const val = parseTextFrame(frameData);
      if (val) result.album = val;
    } else if (frameId === 'TCON' && !result.genre) {
      const val = cleanGenreTag(parseTextFrame(frameData));
      if (val) result.genre = val;
    } else if (frameId === 'TBPM' && result.bpm === undefined) {
      const parsedBpm = Math.round(Number.parseFloat(parseTextFrame(frameData)));
      if (Number.isFinite(parsedBpm) && parsedBpm >= 30 && parsedBpm <= 300) {
        result.bpm = parsedBpm;
      }
    } else if (frameId === 'USLT' && !result.lyrics) {
      const val = parseUsltFrame(frameData);
      if (val) result.lyrics = val;
    }

    offset += frameSize;
  }

  return result;
}

export function extractApicFrame(data: Uint8Array): ApicExtraction | null {
  return extractId3v2Metadata(data)?.apic ?? null;
}
```

### 2.2 `apps/vhunambi_api/src/modules/media/etag.ts` & `cursor.ts` (New)

```typescript
// apps/vhunambi_api/src/modules/media/etag.ts
/**
 * Edge-compatible weak FNV-1a 32-bit ETag helper (zero Node crypto/Buffer).
 */
export function computeEdgeEtag(payload: string): string {
  const bytes = new TextEncoder().encode(payload);
  let hash = 0x811c9dc5;
  for (let i = 0; i < bytes.length; i++) {
    hash ^= bytes[i];
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return `W/"${hash.toString(16).padStart(8, '0')}-${bytes.byteLength}"`;
}

export function isIfNoneMatchHit(
  ifNoneMatchHeader: string | undefined,
  currentEtag: string,
): boolean {
  if (!ifNoneMatchHeader) return false;
  const trimmed = ifNoneMatchHeader.trim();
  if (trimmed === '*') return true;
  const normalize = (tag: string) => tag.trim().replace(/^W\//i, '');
  const target = normalize(currentEtag);
  return trimmed.split(',').some((candidate) => normalize(candidate) === target);
}
```

```typescript
// apps/vhunambi_api/src/modules/media/cursor.ts
/**
 * Edge-compatible base64url keyset cursor encoder/decoder (zero Node Buffer).
 */
export interface ExploreCursorPayload {
  sortKey: string | number;
  id: string;
}

export function encodeExploreCursor(payload: ExploreCursorPayload): string {
  const bytes = new TextEncoder().encode(JSON.stringify(payload));
  let binary = '';
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

export function decodeExploreCursor(
  raw: string | undefined | null,
): ExploreCursorPayload | null {
  if (!raw || typeof raw !== 'string') return null;
  try {
    const padded = raw
      .replace(/-/g, '+')
      .replace(/_/g, '/')
      .padEnd(raw.length + ((4 - (raw.length % 4)) % 4), '=');
    const binary = atob(padded);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }
    const parsed = JSON.parse(new TextDecoder().decode(bytes)) as Record<
      string,
      unknown
    >;
    if (
      parsed &&
      typeof parsed === 'object' &&
      typeof parsed.id === 'string' &&
      parsed.id.length > 0 &&
      (typeof parsed.sortKey === 'string' || typeof parsed.sortKey === 'number')
    ) {
      return { sortKey: parsed.sortKey, id: parsed.id };
    }
    return null;
  } catch {
    return null;
  }
}
```

---

## §3. Backend R2 Range Reader, Media Routes & Durable Explore Persistence (`apps/vhunambi_api`)

### 3.1 Additive `fetchR2ByteRange` in `apps/vhunambi_api/src/modules/synthesis/r2_storage.ts`

```typescript
export interface R2ByteRangeResult {
  bytes: Uint8Array;
  totalSize: number | null;
  contentType: string | null;
}

/**
 * Reads a bounded byte range [startByte, endByte] (inclusive) from R2 without
 * loading the entire media object into Cloudflare Worker isolate RAM.
 * Lookup order: inMemoryR2Objects (tests) -> VHUNAMBI_VAULT binding -> S3 Range GET.
 */
export async function fetchR2ByteRange(
  objectKey: string,
  startByte: number,
  endByte: number,
  cOrEnv?: Context | VhunambiWorkerEnv | Record<string, unknown> | null,
): Promise<R2ByteRangeResult | null> {
  const cleanKey = objectKey.replace(/^\/+/, '');
  const safeStart = Math.max(0, Math.floor(startByte));
  const safeEnd = Math.max(safeStart, Math.floor(endByte));
  const length = safeEnd - safeStart + 1;

  // 1. In-memory test / same-isolate cache
  const mem = inMemoryR2Objects.get(cleanKey);
  if (mem) {
    if (safeStart >= mem.bytes.byteLength) {
      return {
        bytes: new Uint8Array(0),
        totalSize: mem.bytes.byteLength,
        contentType: mem.contentType,
      };
    }
    const slice = mem.bytes.subarray(
      safeStart,
      Math.min(mem.bytes.byteLength, safeEnd + 1),
    );
    return {
      bytes: slice,
      totalSize: mem.bytes.byteLength,
      contentType: mem.contentType,
    };
  }

  // 2. Native Cloudflare Workers R2 bucket binding (zero egress, range-native)
  const workerEnv = extractWorkerEnv(cOrEnv) as VhunambiWorkerEnv | undefined;
  if (workerEnv?.VHUNAMBI_VAULT) {
    const obj = await workerEnv.VHUNAMBI_VAULT.get(cleanKey, {
      range: { offset: safeStart, length },
    });
    if (!obj) return null;
    const arrBuf = await obj.arrayBuffer();
    return {
      bytes: new Uint8Array(arrBuf),
      totalSize: typeof obj.size === 'number' ? obj.size : null,
      contentType: obj.httpMetadata?.contentType ?? null,
    };
  }

  // 3. S3-compatible SigV4 Range GET fallback
  const runtimeEnv = resolveRuntimeEnv(cOrEnv);
  const client = createR2Client(cOrEnv);
  if (!client || !runtimeEnv.R2_ENDPOINT) return null;

  const bucket = runtimeEnv.R2_BUCKET || 'vhunambi-vault';
  const endpoint = runtimeEnv.R2_ENDPOINT.replace(/\/+$/, '');
  const resp = await client.fetch(`${endpoint}/${bucket}/${cleanKey}`, {
    method: 'GET',
    headers: { Range: `bytes=${safeStart}-${safeEnd}` },
  });
  if (!resp.ok && resp.status !== 206) return null;
  const contentRange = resp.headers.get('content-range');
  const totalMatch = contentRange?.match(/\/(\d+)$/);
  return {
    bytes: new Uint8Array(await resp.arrayBuffer()),
    totalSize: totalMatch ? Number.parseInt(totalMatch[1], 10) : null,
    contentType: resp.headers.get('content-type'),
  };
}
```

### 3.2 Presign, Finalize & ID3 Extraction in `apps/vhunambi_api/src/routes/media_routes.ts`

```typescript
export const MAX_MEDIA_UPLOAD_BYTES = 25 * 1024 * 1024;
export const MAX_DIRECT_R2_UPLOAD_BYTES = 100 * 1024 * 1024; // 100 MB for direct video/audio PUT
export const MAX_IMAGE_UPLOAD_BYTES = 25 * 1024 * 1024;

// Add 'audio/flac': 'flac' to ALLOWED_MEDIA_UPLOAD_MIMES

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
      { error: 'UNSUPPORTED_MEDIA_TYPE', message: `Unsupported MIME type: ${mimeType || 'unknown'}` },
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

  const uploadId = String(body.uploadId ?? '').trim() || `upl_${Date.now()}_${nanoid(8)}`;
  const r2Key = String(body.r2Key ?? '').replace(/^\/+/, '').trim();
  const mimeType = String(body.mimeType ?? '').split(';')[0].trim().toLowerCase();
  const ext = ALLOWED_MEDIA_UPLOAD_MIMES[mimeType];
  if (!r2Key || !ext) {
    return c.json(
      { error: 'INVALID_REQUEST', message: 'Valid r2Key and supported mimeType are required' },
      400,
    );
  }
  if (!r2Key.startsWith(`media/${creatorId}/`) && authUser?.role !== 'admin') {
    return c.json(
      { error: 'TENANT_FORBIDDEN', message: 'r2Key does not match authenticated creator namespace' },
      403,
    );
  }

  const rangeRes = await fetchR2ByteRange(r2Key, 0, ID3_INITIAL_RANGE_BYTES - 1, c);
  if (!rangeRes) {
    return c.json(
      { error: 'OBJECT_NOT_FOUND', message: `Uploaded object not found in R2: ${r2Key}` },
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
    filename.replace(/\.[^.]+$/, '').replace(/[_-]+/g, ' ').trim() || 'Uploaded Media';
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
```

### 3.3 Durable Write-Through (`upsertKineticPostAsync`, `upsertExploreTrackAsync`) & Explore Cursor/ETag

In `apps/vhunambi_api/src/db/edge_persistence_bridge.ts` and `apps/vhunambi_api/src/db/vhunambi_db.ts`:
- Add `public async upsertKineticPostAsync(input: Record<string, any>, c?: any): Promise<Record<string, any>>` that calls `this.upsertKineticPost(input, true)` (skipping fire-and-forget `mirrorWriteThrough`) and then `await this.awaitWriteThrough(async (driver) => driver.upsertRow('kinetic_posts', rowPayload, 'id'), c)` so `POST /api/explore/posts` never loses rows when the Cloudflare Worker isolate finishes.
- Add `public async upsertExploreTrackAsync(input: Record<string, any>, c?: any): Promise<Record<string, any>>` with the exact same `awaitWriteThrough` pattern for `public.explore_tracks` (persisting `content_sha256`, `source_origin`, and `lyrics_text`).
- In `apps/vhunambi_api/src/routes/explore_routes.ts`:
  - `POST /api/explore/posts` calls `await vhunambiDb.upsertKineticPostAsync(..., c)`.
  - `POST /api/explore/tracks` calls `await vhunambiDb.upsertExploreTrackAsync(..., c)`.
  - `GET /api/explore/tracks` parses `?cursor=` via `decodeExploreCursor()`, slices page items deterministically, emits `nextCursor`, computes `const etag = computeEdgeEtag(payloadJson)`, checks `isIfNoneMatchHit(c.req.header('if-none-match'), etag)` -> returns `c.body(null, 304, { ETag: etag, 'Cache-Control': 'private, max-age=15, must-revalidate' })`, otherwise returns `200` with `ETag` header.

---

## §4. Flutter Client Media Engine & Reels 98% Fix (`apps/vhunambi_client`)

### 4.1 Pure MIME Inference Helper (`apps/vhunambi_client/lib/features/media/domain/utils/media_mime_utils.dart` — New)

```dart
import 'package:vhunambi_client/features/media/domain/models/uploaded_media_asset.dart';

const Map<String, String> kExtensionToMimeMap = <String, String>{
  'mp4': 'video/mp4',
  'm4v': 'video/mp4',
  'mov': 'video/quicktime',
  'webm': 'video/webm',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'mp3': 'audio/mpeg',
  'wav': 'audio/wav',
  'm4a': 'audio/mp4',
  'aac': 'audio/aac',
  'ogg': 'audio/ogg',
  'flac': 'audio/flac',
};

/// Resolves canonical MIME type from declared MIME or file extension.
/// Prevents hardcoding 'video/mp4' or 'image/jpeg' on PNG/WebP/MOV/MP3 files.
String inferMimeTypeFromMedia({
  required String filename,
  String? declaredMime,
  MediaAssetKind? fallbackKind,
}) {
  final normalizedDeclared =
      (declaredMime ?? '').split(';').first.trim().toLowerCase();
  if (normalizedDeclared.isNotEmpty &&
      normalizedDeclared != 'application/octet-stream') {
    if (normalizedDeclared == 'image/jpg') return 'image/jpeg';
    if (kExtensionToMimeMap.values.contains(normalizedDeclared) ||
        normalizedDeclared == 'audio/x-wav' ||
        normalizedDeclared == 'audio/wave') {
      return normalizedDeclared;
    }
  }

  final dotIdx = filename.lastIndexOf('.');
  if (dotIdx != -1 && dotIdx < filename.length - 1) {
    final ext = filename.substring(dotIdx + 1).trim().toLowerCase();
    final mapped = kExtensionToMimeMap[ext];
    if (mapped != null) return mapped;
  }

  return switch (fallbackKind) {
    MediaAssetKind.video => 'video/mp4',
    MediaAssetKind.audio => 'audio/mpeg',
    MediaAssetKind.image || null => 'image/jpeg',
  };
}

bool isVideoFilenameOrMime(String filename, [String? declaredMime]) {
  return inferMimeTypeFromMedia(
    filename: filename,
    declaredMime: declaredMime,
  ).startsWith('video/');
}
```

### 4.2 Replay-Safe `401` Interceptor (`apps/vhunambi_client/lib/core/network/sovereign_api_client.dart`)

Surgical upgrade inside `buildDioInterceptor({Dio? retryDio})`:

```dart
      onError: (error, handler) async {
        final status = error.response?.statusCode;
        final alreadyRetried =
            error.requestOptions.extra['_p61Retried'] == true;
        final session = _readSession();
        if (status == 401 &&
            !alreadyRetried &&
            session.refreshToken.isNotEmpty) {
          final refreshed = await singleFlightRefresh();
          if (refreshed != null && refreshed.isAuthenticated) {
            final opts = error.requestOptions;
            opts.extra['_p61Retried'] = true;
            opts.headers.addAll(refreshed.authHeaders);

            // Phase 84 (REEL98-01): Never replay a consumed single-use FormData stream.
            final bodyBuilder = opts.extra['_p84BodyBuilder'];
            if (bodyBuilder is Object Function()) {
              opts.data = bodyBuilder();
            } else if (opts.data is FormData) {
              // Cannot safely replay finalized FormData without a builder; surface clean error.
              return handler.next(error);
            }

            try {
              final client = retryDio ?? Dio();
              final replayed = await client.fetch<dynamic>(opts);
              return handler.resolve(replayed);
            } on DioException catch (replayErr) {
              return handler.next(replayErr);
            }
          }
        }
        handler.next(error);
      },
```

### 4.3 `UploadedMediaAsset` Extension (`apps/vhunambi_client/lib/features/media/domain/models/uploaded_media_asset.dart`)

Add optional, backward-compatible nullable fields so extracted ID3 cover art and track tags propagate across `UploadsVaultView`, `CreateKineticPostSheet`, and `KineticReelPublishView`:
- `final String? thumbnailUrl;` (normalized remote `/r2/covers/...` URL)
- `final String? artist;`
- `final String? album;`
- `final String? genre;`
- `final int? bpm;`
- `final String? contentSha256;`
- Getter `String? get bestCoverSource => (thumbnailUrl?.trim().isNotEmpty == true) ? thumbnailUrl : thumbnailLocalPath;`
- Update `copyWith`, `toJson`, and `fromJson` (reading both camelCase `thumbnailUrl` / `id3Metadata` and snake_case `thumbnail_url` / `id3_metadata_json`).

### 4.4 Direct-to-R2 `HttpMediaUploadRepository` (`apps/vhunambi_client/lib/features/media/data/repositories/http_media_upload_repository.dart`)

```dart
  @override
  Future<UploadedMediaAsset> uploadMedia({
    required UploadedMediaAsset staged,
    required Uint8List bytes,
    void Function(int sent, int total)? onProgress,
  }) async {
    final total = bytes.length;
    onProgress?.call((total * 0.05).round(), total);

    // Step 1: Request Direct-to-R2 SigV4 PUT URL (bypasses 25 MB Worker RAM cap)
    final presignRes = await _dio.post<Map<String, dynamic>>(
      '$_baseUrl/media/presign-put',
      data: <String, dynamic>{
        'filename': staged.filename,
        'mimeType': staged.mimeType,
        'sizeBytes': bytes.length,
        'title': staged.title,
        'sourceSurface': staged.sourceSurface,
        if (staged.contentSha256 != null) 'contentSha256': staged.contentSha256,
      },
    );

    final presignBody = presignRes.data ?? const <String, dynamic>{};
    if (presignBody['deduplicated'] == true && presignBody['asset'] is Map) {
      onProgress?.call(total, total);
      return _hydrateSyncedAsset(
        staged,
        Map<String, dynamic>.from(presignBody['asset'] as Map),
        presignBody,
      );
    }

    final strategy = (presignBody['uploadStrategy'] ?? 'worker_binary').toString();
    final putUrl = presignBody['putUrl']?.toString();
    final uploadId = presignBody['uploadId']?.toString();
    final r2Key = presignBody['r2Key']?.toString();

    if (strategy == 'r2_presigned_put' &&
        putUrl != null &&
        putUrl.isNotEmpty &&
        uploadId != null &&
        r2Key != null) {
      // Step 2: Stream raw bytes directly to Cloudflare R2 (no auth header, no FormData)
      final rawPutDio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(minutes: 4),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      await rawPutDio.put<dynamic>(
        putUrl,
        data: Stream<List<int>>.fromIterable(<List<int>>[bytes]),
        options: Options(
          headers: <String, dynamic>{
            Headers.contentLengthHeader: bytes.length,
            Headers.contentTypeHeader: staged.mimeType,
          },
        ),
        onSendProgress: (sent, putTotal) {
          final denom = putTotal > 0 ? putTotal : total;
          final scaled = (0.05 + 0.85 * (sent / denom).clamp(0.0, 1.0));
          onProgress?.call((scaled * total).round(), total);
        },
      );

      onProgress?.call((total * 0.94).round(), total);

      // Step 3: Finalize on Worker -> triggers bounded ID3v2 APIC cover + metadata extraction
      final finalizeRes = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/media/finalize',
        data: <String, dynamic>{
          'uploadId': uploadId,
          'r2Key': r2Key,
          'filename': staged.filename,
          'mimeType': staged.mimeType,
          'sizeBytes': bytes.length,
          'title': staged.title,
          'sourceSurface': staged.sourceSurface,
          if (staged.durationMs != null) 'durationMs': staged.durationMs,
          if (staged.width != null) 'width': staged.width,
          if (staged.height != null) 'height': staged.height,
          if (staged.contentSha256 != null) 'contentSha256': staged.contentSha256,
        },
      );

      final finBody = finalizeRes.data ?? const <String, dynamic>{};
      final rawAsset = finBody['asset'] is Map
          ? Map<String, dynamic>.from(finBody['asset'] as Map)
          : <String, dynamic>{};
      onProgress?.call(total, total);
      return _hydrateSyncedAsset(staged, rawAsset, finBody);
    }

    // Fallback (local dev / test without R2 S3 keys): raw binary POST with replayable builder
    final res = await _dio.post<Map<String, dynamic>>(
      '$_baseUrl/media/upload',
      data: bytes,
      options: Options(
        contentType: staged.mimeType,
        headers: <String, dynamic>{
          'x-media-filename': staged.filename,
          'x-media-title': staged.title,
          'x-media-surface': staged.sourceSurface,
        },
        extra: <String, dynamic>{
          '_p84BodyBuilder': () => bytes,
        },
      ),
      onSendProgress: (sent, uploadTotal) {
        final denom = uploadTotal > 0 ? uploadTotal : total;
        final scaled = (0.05 + 0.90 * (sent / denom).clamp(0.0, 1.0));
        onProgress?.call((scaled * total).round(), total);
      },
    );

    final body = res.data ?? const <String, dynamic>{};
    final rawAsset = body['asset'] is Map
        ? Map<String, dynamic>.from(body['asset'] as Map)
        : <String, dynamic>{};
    onProgress?.call(total, total);
    return _hydrateSyncedAsset(staged, rawAsset, body);
  }

  UploadedMediaAsset _hydrateSyncedAsset(
    UploadedMediaAsset staged,
    Map<String, dynamic> rawAsset,
    Map<String, dynamic> envelope,
  ) {
    final rawUrl = (rawAsset['remoteUrl'] ?? envelope['url'] ?? '').toString();
    if (rawUrl.isEmpty) {
      throw StateError('Upload response did not include a valid R2 URL');
    }
    final rawThumb =
        (rawAsset['thumbnailUrl'] ?? envelope['thumbnailUrl'] ?? '').toString();
    final id3 = rawAsset['id3Metadata'] is Map
        ? Map<String, dynamic>.from(rawAsset['id3Metadata'] as Map)
        : (envelope['id3Metadata'] is Map
            ? Map<String, dynamic>.from(envelope['id3Metadata'] as Map)
            : const <String, dynamic>{});
    final extractedTitle = (rawAsset['title'] ?? id3['title'] ?? '').toString().trim();

    return staged.copyWith(
      title: extractedTitle.isNotEmpty ? extractedTitle : staged.title,
      remoteUrl: AppConstants.normalizeCloudMediaUrl(rawUrl),
      remoteKey: (rawAsset['r2Key'] ?? envelope['key'])?.toString(),
      thumbnailUrl: rawThumb.isNotEmpty
          ? AppConstants.normalizeCloudMediaUrl(rawThumb)
          : staged.thumbnailUrl,
      artist: id3['artist']?.toString() ?? staged.artist,
      album: id3['album']?.toString() ?? staged.album,
      genre: id3['genre']?.toString() ?? staged.genre,
      bpm: (id3['bpm'] as num?)?.toInt() ?? staged.bpm,
      status: MediaUploadStatus.synced,
      progress: 1.0,
      clearError: true,
    );
  }
```

### 4.5 Reels Deduplication & Honest `publishClip` (`reel_audio_picker_sheet.dart`, `kinetic_reel_publish_view.dart`, `http_social_repository.dart`)

1. **`MediaUploadQueueNotifier.awaitOrRetryAsset(String assetId)`:**
   - Checks in-flight `Map<String, Future<UploadedMediaAsset>> _inFlightUploads` so if `ReelAudioPickerSheet` already started uploading `stagedAudioAssetId`, `KineticReelPublishView` awaits the exact same `Future` (or returns immediately if `status == MediaUploadStatus.synced`). Only retries if `status == MediaUploadStatus.failed`.
2. **`KineticReelStudioView._pickGalleryMedia()`:**
   - Replaces hardcoded `isVideo ? 'video/mp4' : 'image/jpeg'` with `inferMimeTypeFromMedia(filename: media.name, declaredMime: media.mimeType, fallbackKind: isVideo ? MediaAssetKind.video : MediaAssetKind.image)`.
3. **`HttpSocialRepository.publishClip()`:**
   - Passes `options: Options(sendTimeout: const Duration(seconds: 20), receiveTimeout: const Duration(seconds: 20))`.
   - Removes silent production fallback: only uses `_publishClipFallback()` when `_shouldSkipNetwork == true`; otherwise throws `StateError('Failed to publish reel (HTTP ${response.statusCode})')` or rethrows `DioException` so `KineticReelPublishView` displays `Key('reel_publish_error_banner')` + `Key('reel_publish_retry_btn')`.

---

## §5. Kinetic Post Real Uploads & Feed Media Hydration (`create_kinetic_post_sheet.dart` & `explore_providers.dart`)

### 5.1 `CreateKineticPostSheet` Upgrades (`REQ-P84-KPOST-01..03`)

1. **Default State Hygiene:**
   - `int _audioSourceTabIndex = 0;` (`My Uploads` first).
   - Remove static `_grooveSeeds` (`sk_01..03`) and remove `_selectedTrack = initialTracks.first;` (respect explicit `widget.initialTrack` only).
   - Remove `'kpost_track_default'` / `'Vhunambi Sonic Groove'` fake track injection on submit.
2. **Direct Audio Upload CTA (`Key('kpost_upload_audio_btn')`):**
   - Inside the Sound Attachment deck (always visible at top of `My Uploads` tab, `>= 44dp` height, `PhosphorIcon(PhosphorIconsBold.uploadSimple)` + `AppColors.brandPrimary` pill border, `AppTypography.titleSmall`):
   ```dart
   Future<void> _pickAndUploadAudio() async {
     final picked = await FilePicker.platform.pickFiles(
       type: FileType.custom,
       allowedExtensions: const <String>['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
       withData: true,
     );
     if (picked == null || picked.files.isEmpty) return;
     final file = picked.files.first;
     final bytes = file.bytes ??
         (file.path != null ? await File(file.path!).readAsBytes() : null);
     if (bytes == null || bytes.isEmpty || !mounted) return;

     final mimeType = inferMimeTypeFromMedia(
       filename: file.name,
       fallbackKind: MediaAssetKind.audio,
     );
     setState(() => _isUploadingAudio = true);
     try {
       final synced = await ref
           .read(mediaUploadQueueProvider.notifier)
           .stageAndEnqueue(
             bytes: bytes,
             filename: file.name,
             mimeType: mimeType,
             kind: MediaAssetKind.audio,
             title: file.name.replaceAll(RegExp(r'\.[^.]+$'), ''),
             sourceSurface: 'kinetic_post',
             awaitUpload: true,
           );
       if (!mounted) return;
       if (synced.status != MediaUploadStatus.synced || synced.remoteUrl == null) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text(
               synced.errorMessage ?? 'Audio upload failed. Tap Retry in My Uploads.',
             ),
           ),
         );
         return;
       }
       final uploadedTrack = Track(
         id: synced.id,
         title: synced.title,
         creatorName: synced.artist ?? ref.read(ownerProfileProvider).displayName,
         creatorHandle: ref.read(ownerProfileProvider).handle,
         genre: synced.genre ?? 'Amapiano',
         bpm: synced.bpm ?? 114,
         duration: Duration(milliseconds: synced.durationMs ?? 180000),
         audioUrl: synced.remoteUrl,
         coverUrl: synced.thumbnailUrl,
       );
       setState(() {
         _selectedTrack = uploadedTrack;
         _audioSourceTabIndex = 0;
       });
     } finally {
       if (mounted) setState(() => _isUploadingAudio = false);
     }
   }
   ```
3. **Awaited Photo Upload & Honest Vision AI:**
   - `_pickAndUploadPhoto()` sets `awaitUpload: true` and awaits `synced.remoteUrl` before adding to `_attachedImages`; on failure, shows an honest snackbar instead of attaching a device-local `localFilePath`.
   - `_generateVisionAiArtwork()` removes `asset:${AppAssets.allBundledArtworkAssets[fallbackIndex]}` fallback; if `/v1/vision/generate` throws or returns `isMock == true`, surfaces an inline honest message (`Key('kpost_vision_unavailable_notice')`) prompting the user to upload a real photo.

### 5.2 `SocialFeedPostsNotifier.refreshFromCloud()` Full Hydration (`explore_providers.dart`)

Replace lines `850-898` hydration logic so both existing-post updates AND newly hydrated posts retain real uploaded image, audio, and extracted cover URLs:

```dart
        final rawImages = raw['imageAttachments'] ?? raw['image_attachments'];
        final parsedImages = <String>[
          if (rawImages is List)
            ...rawImages
                .map((e) => AppConstants.normalizeCloudMediaUrl(e.toString()))
                .where((u) => u.isNotEmpty),
        ];
        final rawPrimaryImage =
            (raw['imageAttachment'] ?? raw['image_attachment'] ?? '').toString().trim();
        final normalizedPrimaryImage = rawPrimaryImage.isNotEmpty
            ? AppConstants.normalizeCloudMediaUrl(rawPrimaryImage)
            : (parsedImages.isNotEmpty ? parsedImages.first : null);

        final rawAudioUrl =
            (raw['audioUrl'] ?? raw['audio_url'] ?? raw['audioPreviewUrl'] ?? raw['audio_preview_url'] ?? '')
                .toString()
                .trim();
        final rawCoverUrl =
            (raw['coverUrl'] ?? raw['cover_url'] ?? '').toString().trim();

        hydrated.add(
          SocialMusicPost(
            id: id,
            creatorId: (raw['creatorId'] ?? raw['creator_id'] ?? 'creator_cern').toString(),
            creatorName: (raw['creatorName'] ?? raw['creator_name'] ?? 'Creator').toString(),
            creatorHandle: (raw['creatorHandle'] ?? raw['creator_handle'] ?? '@creator').toString(),
            publishedAt:
                DateTime.tryParse((raw['createdAt'] ?? raw['created_at'] ?? '').toString()) ??
                DateTime.now(),
            caption: (raw['caption'] ?? '').toString(),
            imageAttachment: normalizedPrimaryImage,
            imageAttachments: parsedImages,
            track: Track.fromJson(<String, dynamic>{
              'id': raw['trackId'] ?? raw['track_id'] ?? raw['attachmentId'] ?? id,
              'title': raw['trackTitle'] ?? raw['track_title'] ?? raw['caption'] ?? 'Cloud Post',
              'creatorName': raw['creatorName'] ?? raw['creator_name'] ?? 'Creator',
              'genre': raw['genre'] ?? 'Amapiano',
              if (rawAudioUrl.isNotEmpty)
                'audioUrl': AppConstants.normalizeCloudMediaUrl(rawAudioUrl),
              if (rawCoverUrl.isNotEmpty)
                'coverUrl': AppConstants.normalizeCloudMediaUrl(rawCoverUrl),
            }),
            likeCount: (raw['likeCount'] as num?)?.toInt() ?? 0,
            isLikedByMe:
                (raw['isLikedByMe'] as bool?) ?? (parsedMyReaction != null),
            reactionCounts: KineticReactionType.parseCounts(
              raw['reactionCounts'] ?? raw['reaction_counts_json'],
            ),
            myReaction: parsedMyReaction,
            commentCount: (raw['commentCount'] as num?)?.toInt() ?? 0,
            cosignCount: (raw['cosignCount'] as num?)?.toInt() ?? 0,
            repostCount: (raw['repostCount'] as num?)?.toInt() ?? 0,
          ),
        );
```

---

## §6. Zero-Local-RAM Zania Music Bulk Ingest CLI (`tools/zania-ingest/ingest_zania_catalog.mjs`)

Zero external npm dependencies (`node:fs`, `node:path`, `node:crypto`, built-in `fetch` on Node 24). Streams files with concurrency `2`, computes SHA-256 deduplication hash, resolves folder -> genre/sub-genre, reads sibling `cover.{webp,png,jpg}` + `lyrics.txt`, supports `--dry-run`, and ingests live via `/api/media/presign-put` -> R2 PUT -> `/api/media/finalize` -> `POST /api/explore/tracks`.

```javascript
#!/usr/bin/env node
/**
 * VHUNAMBI Phase 84 — Zero-Duplication Zania Music Catalog Ingest CLI
 * Usage:
 *   node tools/zania-ingest/ingest_zania_catalog.mjs --dir "C:\Users\Ndugelo\Music\ZANIA MUSIC\READY" --dry-run
 *   node tools/zania-ingest/ingest_zania_catalog.mjs --dir "C:\Users\Ndugelo\Music\ZANIA MUSIC\READY" --api-url https://vhunambi-api.ndugelo.workers.dev --token <JWT>
 */
import { createHash } from 'node:crypto';
import { createReadStream, existsSync } from 'node:fs';
import { readdir, readFile, stat } from 'node:fs/promises';
import path from 'node:path';

export function resolveGenreFromRelativePath(relPath) {
  const norm = relPath.replace(/\\/g, '/').toLowerCase();
  if (norm.includes('amapiano')) return { genre: 'Amapiano', subGenre: 'Private School Amapiano', moodId: 'groove' };
  if (norm.includes('venda afro')) return { genre: 'Afrobeats', subGenre: 'Venda Afro', moodId: 'soulful' };
  if (norm.startsWith('afro/')) return { genre: 'Afrobeats', subGenre: 'Afro Fusion', moodId: 'uplifting' };
  if (norm.startsWith('house/')) return { genre: 'Afro House', subGenre: 'Deep House', moodId: 'euphoric' };
  if (norm.startsWith('pop/')) return { genre: 'Mzansi Pop', subGenre: 'Afro Pop', moodId: 'uplifting' };
  if (norm.startsWith('rock/')) return { genre: 'Afro Rock', subGenre: 'Alternative Rock', moodId: 'energetic' };
  if (norm.startsWith('wave/')) return { genre: 'Afro Fusion', subGenre: 'Synth Wave', moodId: 'late_night' };
  if (norm.startsWith('instrumental/')) return { genre: 'Instrumental', subGenre: 'Studio Bed', moodId: 'focus' };
  if (norm.startsWith('jazz/')) return { genre: 'Afro Jazz', subGenre: 'Cape Jazz', moodId: 'chill' };
  if (norm.startsWith('phonk/')) return { genre: 'Phonk', subGenre: 'Dark Bounce', moodId: 'intense' };
  if (norm.startsWith('epic orchestration/')) return { genre: 'Cinematic', subGenre: 'Epic Orchestral', moodId: 'cinematic' };
  if (norm.startsWith('trap/')) return { genre: 'SA Hip Hop', subGenre: 'Trap', moodId: 'intense' };
  if (norm.startsWith('celestial/')) return { genre: 'Ambient', subGenre: 'Celestial', moodId: 'peaceful' };
  if (norm.startsWith('rap/')) return { genre: 'SA Hip Hop', subGenre: 'Rap', moodId: 'energetic' };
  return { genre: 'Afro Fusion', subGenre: 'Zania Curated', moodId: 'chill' };
}

export async function sha256File(filePath) {
  return new Promise((resolve, reject) => {
    const hash = createHash('sha256');
    const stream = createReadStream(filePath);
    stream.on('data', (chunk) => hash.update(chunk));
    stream.on('end', () => resolve(hash.digest('hex')));
    stream.on('error', reject);
  });
}

export async function collectMp3Files(rootDir, currentDir = rootDir, out = []) {
  const entries = await readdir(currentDir, { withFileTypes: true });
  for (const entry of entries) {
    const full = path.join(currentDir, entry.name);
    if (entry.isDirectory()) {
      await collectMp3Files(rootDir, full, out);
    } else if (entry.isFile() && entry.name.toLowerCase().endsWith('.mp3')) {
      const dir = path.dirname(full);
      const siblingCover = ['cover.webp', 'cover.png', 'cover.jpg']
        .map((c) => path.join(dir, c))
        .find((p) => existsSync(p)) ?? null;
      const siblingLyrics = ['lyrics.txt', `${path.basename(full, '.mp3')}.txt`]
        .map((l) => path.join(dir, l))
        .find((p) => existsSync(p)) ?? null;
      const rel = path.relative(rootDir, full);
      const fileStat = await stat(full);
      out.push({
        fullPath: full,
        relativePath: rel,
        filename: entry.name,
        title: entry.name.replace(/\.mp3$/i, '').trim().normalize('NFC'),
        sizeBytes: fileStat.size,
        siblingCover,
        siblingLyrics,
        ...resolveGenreFromRelativePath(rel),
      });
    }
  }
  return out;
}

async function ingestOne(item, { apiUrl, token, creatorId }) {
  const contentSha256 = await sha256File(item.fullPath);
  const authHeaders = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${token}`,
  };

  const presignRes = await fetch(`${apiUrl}/api/media/presign-put`, {
    method: 'POST',
    headers: authHeaders,
    body: JSON.stringify({
      filename: item.filename,
      mimeType: 'audio/mpeg',
      sizeBytes: item.sizeBytes,
      title: item.title,
      sourceSurface: 'zania_ingest',
      contentSha256,
    }),
  });
  if (!presignRes.ok) {
    throw new Error(`presign-put failed (${presignRes.status}): ${await presignRes.text()}`);
  }
  const presign = await presignRes.json();
  let asset = presign.asset;

  if (!presign.deduplicated) {
    const mp3Bytes = await readFile(item.fullPath);
    if (presign.uploadStrategy === 'r2_presigned_put' && presign.putUrl) {
      const putRes = await fetch(presign.putUrl, {
        method: 'PUT',
        headers: { 'Content-Type': 'audio/mpeg' },
        body: mp3Bytes,
      });
      if (!putRes.ok) throw new Error(`R2 PUT failed (${putRes.status})`);

      const finRes = await fetch(`${apiUrl}/api/media/finalize`, {
        method: 'POST',
        headers: authHeaders,
        body: JSON.stringify({
          uploadId: presign.uploadId,
          r2Key: presign.r2Key,
          filename: item.filename,
          mimeType: 'audio/mpeg',
          sizeBytes: item.sizeBytes,
          title: item.title,
          sourceSurface: 'zania_ingest',
          contentSha256,
        }),
      });
      if (!finRes.ok) throw new Error(`finalize failed (${finRes.status}): ${await finRes.text()}`);
      asset = (await finRes.json()).asset;
    }
  }

  const lyricsText = item.siblingLyrics
    ? (await readFile(item.siblingLyrics, 'utf8')).trim().normalize('NFC')
    : '';

  const trackRes = await fetch(`${apiUrl}/api/explore/tracks`, {
    method: 'POST',
    headers: authHeaders,
    body: JSON.stringify({
      id: `trk_zania_${contentSha256.slice(0, 14)}`,
      creatorId,
      title: asset?.title || item.title,
      artist: asset?.id3Metadata?.artist || 'Zania Music',
      genre: item.genre,
      subGenre: item.subGenre,
      moodId: item.moodId,
      bpm: asset?.id3Metadata?.bpm || 114,
      audioUrl: asset?.remoteUrl,
      coverUrl: asset?.thumbnailUrl || '',
      contentSha256,
      sourceOrigin: 'creator_upload_zania',
      lyricsText,
    }),
  });
  if (!trackRes.ok) {
    throw new Error(`explore/tracks failed (${trackRes.status}): ${await trackRes.text()}`);
  }
  return { status: presign.deduplicated ? 'deduped' : 'uploaded', title: item.title, genre: item.genre };
}

async function main() {
  const args = process.argv.slice(2);
  const getArg = (flag, fallback = '') => {
    const idx = args.indexOf(flag);
    return idx !== -1 && args[idx + 1] ? args[idx + 1] : fallback;
  };
  const dir = getArg('--dir');
  const dryRun = args.includes('--dry-run');
  const apiUrl = getArg('--api-url', 'https://vhunambi-api.ndugelo.workers.dev').replace(/\/+$/, '');
  const token = getArg('--token', process.env.VHUNAMBI_INGEST_TOKEN || '');
  const creatorId = getArg('--creator-id', 'creator_cern');
  const limit = Number.parseInt(getArg('--limit', '0'), 10) || 0;

  if (!dir || !existsSync(dir)) {
    console.error('Error: --dir <path> must point to an existing ZANIA MUSIC directory.');
    process.exit(1);
  }

  const items = await collectMp3Files(dir);
  const subset = limit > 0 ? items.slice(0, limit) : items;

  if (dryRun) {
    const byGenre = {};
    for (const item of subset) {
      byGenre[item.genre] = (byGenre[item.genre] || 0) + 1;
    }
    console.log(JSON.stringify({
      dryRun: true,
      scannedMp3s: subset.length,
      withSiblingCover: subset.filter((i) => i.siblingCover).length,
      withSiblingLyrics: subset.filter((i) => i.siblingLyrics).length,
      byGenre,
      sample: subset.slice(0, 5),
    }, null, 2));
    return;
  }

  if (!token) {
    console.error('Error: --token <JWT> or VHUNAMBI_INGEST_TOKEN is required for live ingest.');
    process.exit(1);
  }

  let uploaded = 0;
  let deduped = 0;
  let failed = 0;
  const concurrency = 2;
  let cursor = 0;

  async function worker() {
    while (cursor < subset.length) {
      const item = subset[cursor++];
      try {
        const res = await ingestOne(item, { apiUrl, token, creatorId });
        if (res.status === 'deduped') deduped++;
        else uploaded++;
      } catch (err) {
        failed++;
        console.error(`[FAIL] ${item.relativePath}: ${err.message}`);
      }
    }
  }

  await Promise.all(Array.from({ length: concurrency }, () => worker()));
  console.log(JSON.stringify({ total: subset.length, uploaded, deduped, failed }, null, 2));
  if (failed > 0) process.exit(1);
}

if (import.meta.url === `file://${process.argv[1]?.replace(/\\/g, '/')}`) {
  main().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}
```

---

## §7. Formal Proof of Invariants

1. **Zero Finalized-FormData Crash Invariant (`REEL98-01`):** `HttpMediaUploadRepository` eliminates `FormData` completely on both the Direct-to-R2 PUT path (`Stream<List<int>>` raw bytes) and the worker binary fallback (`Uint8List` + `_p84BodyBuilder`). Additionally, `SovereignApiClient.buildDioInterceptor()` checks `if (opts.data is FormData)` before any `client.fetch(opts)` replay, mathematically guaranteeing `Bad state: The FormData has already been finalized` cannot recur on any `401` refresh.
2. **Bounded Worker Memory Invariant (`REQ-P84-PRESIGN-03` & `REQ-P84-ID3-03`):** Every `/api/media/finalize` request reads `<= 256 KiB` initially and at most `2 MiB` total via `fetchR2ByteRange`, strictly below Cloudflare Workers' `128 MiB` isolate ceiling regardless of whether a user uploads a `95 MB` 4K reel or a `40 MB` lossless WAV.
3. **Zero Silent Write-Loss Invariant (`KPOST-03`):** Both `POST /api/explore/posts` and `POST /api/explore/tracks` await `awaitWriteThrough` before responding `201`, guaranteeing the Supabase row is committed before the Worker tears down the request context.
4. **Zero Duplicate Storage Invariant (`REQ-P84-ZANIA-01`):** Every ingest call passes SHA-256 `contentSha256` to `/api/media/presign-put` and `idx_explore_tracks_creator_sha256`, making repeated runs of `ingest_zania_catalog.mjs` strictly idempotent.
