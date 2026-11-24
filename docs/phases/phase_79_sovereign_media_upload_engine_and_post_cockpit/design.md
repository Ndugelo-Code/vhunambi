# Phase 79 Technical Design Specification (`design.md`)

**Document ID:** `VHUNAMBI-SPEC-P79-DESIGN-V1`  
**Phase ID:** `P79` — Sovereign Media Upload & Reuse Engine (`VhunambiMediaVault`), Local-First R2 Sync Queue, `CreateKineticPostSheet` Glass Cockpit v2 & Reels Studio Layout Repairs  
**Standard:** 100% Compilable SQL, TypeScript & Dart — Verified Against Live Workspace Signatures (`STD-UIUX-001`: Zero `Icons.*`, Zero Raw Unicode Emojis, `*Of(context)` Dual-Theme Tokens)

---

## 1. Pass 1 (`M79.1`) — Backend Durable Media Asset Registry (`supabase/` & `apps/vhunambi_api/`)

### 1.1 Supabase Migration: `supabase/migrations/20261124000001_phase79_user_media_uploads.sql`

```sql
-- ============================================================================
-- VHUNAMBI PHASE 79: USER MEDIA UPLOADS DURABLE REGISTRY & RLS
-- Migration: 20261124000001_phase79_user_media_uploads.sql
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.user_media_uploads (
  id TEXT PRIMARY KEY,
  creator_id TEXT NOT NULL,
  media_kind TEXT NOT NULL CHECK (media_kind IN ('audio', 'video', 'image')),
  title TEXT NOT NULL,
  filename TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  size_bytes BIGINT NOT NULL CHECK (size_bytes > 0),
  duration_ms INTEGER,
  width INTEGER,
  height INTEGER,
  r2_key TEXT NOT NULL,
  remote_url TEXT NOT NULL,
  thumbnail_url TEXT,
  source_surface TEXT NOT NULL DEFAULT 'vault',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_user_media_uploads_creator_created
  ON public.user_media_uploads (creator_id, created_at DESC)
  WHERE deleted_at IS NULL;

ALTER TABLE public.user_media_uploads ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_media_uploads'
      AND policyname = 'user_media_uploads_owner_select'
  ) THEN
    CREATE POLICY user_media_uploads_owner_select
      ON public.user_media_uploads
      FOR SELECT
      TO authenticated
      USING ((SELECT auth.jwt() ->> 'creator_id') = creator_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_media_uploads'
      AND policyname = 'user_media_uploads_owner_insert'
  ) THEN
    CREATE POLICY user_media_uploads_owner_insert
      ON public.user_media_uploads
      FOR INSERT
      TO authenticated
      WITH CHECK ((SELECT auth.jwt() ->> 'creator_id') = creator_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_media_uploads'
      AND policyname = 'user_media_uploads_owner_update'
  ) THEN
    CREATE POLICY user_media_uploads_owner_update
      ON public.user_media_uploads
      FOR UPDATE
      TO authenticated
      USING ((SELECT auth.jwt() ->> 'creator_id') = creator_id)
      WITH CHECK ((SELECT auth.jwt() ->> 'creator_id') = creator_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'user_media_uploads'
      AND policyname = 'user_media_uploads_owner_delete'
  ) THEN
    CREATE POLICY user_media_uploads_owner_delete
      ON public.user_media_uploads
      FOR DELETE
      TO authenticated
      USING ((SELECT auth.jwt() ->> 'creator_id') = creator_id);
  END IF;
END $$;
```

---

### 1.2 Edge SWR & 1:1 SQLite Proxy Parity (`edge_persistence_bridge.ts` & `vhunambi_db.ts`)

#### A. Shared Record Contract & `EdgeIsolateDatabaseEngine` Methods (`apps/vhunambi_api/src/db/edge_persistence_bridge.ts`)

```typescript
export type MediaUploadKindWire = 'audio' | 'video' | 'image';

export interface UserMediaUploadRecord {
  id: string;
  creatorId: string;
  mediaKind: MediaUploadKindWire;
  title: string;
  filename: string;
  mimeType: string;
  sizeBytes: number;
  durationMs: number | null;
  width: number | null;
  height: number | null;
  r2Key: string;
  remoteUrl: string;
  thumbnailUrl: string | null;
  sourceSurface: string;
  createdAt: string;
  deletedAt: string | null;
}

export function normalizeUserMediaUploadRow(
  raw: Record<string, unknown>,
): UserMediaUploadRecord {
  const kindRaw = String(raw.media_kind ?? raw.mediaKind ?? 'image').toLowerCase();
  const mediaKind: MediaUploadKindWire =
    kindRaw === 'audio' || kindRaw === 'video' ? kindRaw : 'image';
  return {
    id: String(raw.id ?? ''),
    creatorId: canonicalizeCreatorId(String(raw.creator_id ?? raw.creatorId ?? 'creator_cern')),
    mediaKind,
    title: String(raw.title ?? 'Uploaded Media'),
    filename: String(raw.filename ?? 'upload.bin'),
    mimeType: String(raw.mime_type ?? raw.mimeType ?? 'application/octet-stream'),
    sizeBytes: Math.max(1, Number(raw.size_bytes ?? raw.sizeBytes ?? 1)),
    durationMs:
      raw.duration_ms != null || raw.durationMs != null
        ? Number(raw.duration_ms ?? raw.durationMs)
        : null,
    width:
      raw.width != null ? Number(raw.width) : null,
    height:
      raw.height != null ? Number(raw.height) : null,
    r2Key: String(raw.r2_key ?? raw.r2Key ?? ''),
    remoteUrl: String(raw.remote_url ?? raw.remoteUrl ?? ''),
    thumbnailUrl:
      raw.thumbnail_url != null || raw.thumbnailUrl != null
        ? String(raw.thumbnail_url ?? raw.thumbnailUrl)
        : null,
    sourceSurface: String(raw.source_surface ?? raw.sourceSurface ?? 'vault'),
    createdAt: String(raw.created_at ?? raw.createdAt ?? new Date().toISOString()),
    deletedAt:
      raw.deleted_at != null || raw.deletedAt != null
        ? String(raw.deleted_at ?? raw.deletedAt)
        : null,
  };
}
```

Inside `EdgeIsolateDatabaseEngine`:
```typescript
  private readonly userMediaUploads = new Map<string, UserMediaUploadRecord>();

  private hydrateUserMediaUploadRows(rows: Array<Record<string, unknown>>): void {
    for (const raw of rows) {
      const normalized = normalizeUserMediaUploadRow(raw);
      if (normalized.id) {
        this.userMediaUploads.set(normalized.id, normalized);
      }
    }
  }

  public recordUserMediaUpload(
    input: Partial<UserMediaUploadRecord> & { id: string; r2Key: string; remoteUrl: string },
    skipMirror = false,
  ): UserMediaUploadRecord {
    const record = normalizeUserMediaUploadRow({
      ...input,
      creatorId: canonicalizeCreatorId(input.creatorId ?? 'creator_cern'),
      createdAt: input.createdAt ?? new Date().toISOString(),
    });
    this.userMediaUploads.set(record.id, record);
    if (!skipMirror) {
      this.mirrorWriteThrough('user_media_uploads.upsert', (driver) =>
        driver.upsertRow(
          'user_media_uploads',
          {
            id: record.id,
            creator_id: record.creatorId,
            media_kind: record.mediaKind,
            title: record.title,
            filename: record.filename,
            mime_type: record.mimeType,
            size_bytes: record.sizeBytes,
            duration_ms: record.durationMs,
            width: record.width,
            height: record.height,
            r2_key: record.r2Key,
            remote_url: record.remoteUrl,
            thumbnail_url: record.thumbnailUrl,
            source_surface: record.sourceSurface,
            created_at: record.createdAt,
            deleted_at: record.deletedAt,
          },
          'id',
        ),
      );
    }
    return record;
  }

  public async recordUserMediaUploadAsync(
    input: Partial<UserMediaUploadRecord> & { id: string; r2Key: string; remoteUrl: string },
    cOrEnv?: unknown,
  ): Promise<UserMediaUploadRecord> {
    const record = this.recordUserMediaUpload(input, true);
    const driver = this.resolveCloudDriver(cOrEnv);
    if (driver.isConfigured()) {
      await this.awaitCloudWrite('user_media_uploads.upsert_async', () =>
        driver.upsertRow(
          'user_media_uploads',
          {
            id: record.id,
            creator_id: record.creatorId,
            media_kind: record.mediaKind,
            title: record.title,
            filename: record.filename,
            mime_type: record.mimeType,
            size_bytes: record.sizeBytes,
            duration_ms: record.durationMs,
            width: record.width,
            height: record.height,
            r2_key: record.r2Key,
            remote_url: record.remoteUrl,
            thumbnail_url: record.thumbnailUrl,
            source_surface: record.sourceSurface,
            created_at: record.createdAt,
            deleted_at: record.deletedAt,
          },
          'id',
        ),
      );
    }
    return record;
  }

  public getUserMediaUploadById(id: string): UserMediaUploadRecord | null {
    const found = this.userMediaUploads.get(id);
    if (!found || found.deletedAt) return null;
    return found;
  }

  public listUserMediaUploads(
    creatorId: string,
    kind?: MediaUploadKindWire,
  ): UserMediaUploadRecord[] {
    const cid = canonicalizeCreatorId(creatorId);
    const items = Array.from(this.userMediaUploads.values()).filter((u) => {
      if (u.deletedAt) return false;
      if (canonicalizeCreatorId(u.creatorId) !== cid) return false;
      if (kind && u.mediaKind !== kind) return false;
      return true;
    });
    items.sort((a, b) => b.createdAt.localeCompare(a.createdAt));
    return items;
  }

  public async syncUserMediaUploadsFromCloud(
    creatorId: string,
    cOrEnv?: unknown,
    force = false,
  ): Promise<UserMediaUploadRecord[]> {
    const cid = canonicalizeCreatorId(creatorId);
    const driver = this.resolveCloudDriver(cOrEnv);
    if (!driver.isConfigured()) {
      return this.listUserMediaUploads(cid);
    }

    const domainKey = `media_uploads:${cid}`;
    const lastHydrated = this.domainHydratedAtMs.get(domainKey) ?? 0;
    if (
      !force &&
      lastHydrated > 0 &&
      Date.now() - lastHydrated < EdgeIsolateDatabaseEngine.DEFAULT_SWR_TTL_MS
    ) {
      return this.listUserMediaUploads(cid);
    }

    const existing = this.domainInFlightPromises.get(domainKey);
    if (existing && !force) {
      await existing;
      return this.listUserMediaUploads(cid);
    }

    const flight = (async (): Promise<boolean> => {
      const res = await EdgeIsolateDatabaseEngine.withTimeoutResult(
        driver.selectRows<Record<string, unknown>>(
          'user_media_uploads',
          `select=*&creator_id=eq.${encodeURIComponent(cid)}&order=created_at.desc&limit=200`,
        ),
        3500,
      );
      if (res.ok) {
        this.hydrateUserMediaUploadRows(res.value);
        this.domainHydratedAtMs.set(domainKey, Date.now());
        return true;
      }
      return false;
    })().finally(() => {
      if (this.domainInFlightPromises.get(domainKey) === flight) {
        this.domainInFlightPromises.delete(domainKey);
      }
    });

    this.domainInFlightPromises.set(domainKey, flight);
    await flight;
    return this.listUserMediaUploads(cid);
  }

  public deleteUserMediaUpload(
    id: string,
    creatorId?: string,
    skipMirror = false,
  ): boolean {
    const existing = this.userMediaUploads.get(id);
    if (!existing || existing.deletedAt) return false;
    if (
      creatorId &&
      canonicalizeCreatorId(existing.creatorId) !== canonicalizeCreatorId(creatorId)
    ) {
      return false;
    }
    const deletedAt = new Date().toISOString();
    this.userMediaUploads.set(id, { ...existing, deletedAt });
    if (!skipMirror) {
      this.mirrorWriteThrough('user_media_uploads.soft_delete', (driver) =>
        driver.patchRows(
          'user_media_uploads',
          `id=eq.${encodeURIComponent(id)}`,
          { deleted_at: deletedAt },
        ),
      );
    }
    return true;
  }

  public async deleteUserMediaUploadAsync(
    id: string,
    creatorId?: string,
    cOrEnv?: unknown,
  ): Promise<boolean> {
    const deleted = this.deleteUserMediaUpload(id, creatorId, true);
    if (!deleted) return false;
    const driver = this.resolveCloudDriver(cOrEnv);
    if (driver.isConfigured()) {
      const deletedAt = this.userMediaUploads.get(id)?.deletedAt ?? new Date().toISOString();
      await this.awaitCloudWrite('user_media_uploads.soft_delete_async', () =>
        driver.patchRows(
          'user_media_uploads',
          `id=eq.${encodeURIComponent(id)}`,
          { deleted_at: deletedAt },
        ),
      );
    }
    return true;
  }
```
*(Also clear `this.userMediaUploads.clear()` inside `EdgeIsolateDatabaseEngine.resetForTesting()`.)*

#### B. 1:1 SQLite Table & Proxy Methods (`apps/vhunambi_api/src/db/vhunambi_db.ts`)

```typescript
export {
  normalizeUserMediaUploadRow,
  type MediaUploadKindWire,
  type UserMediaUploadRecord,
} from './edge_persistence_bridge.js';

// Inside VhunambiDatabase.initializeSchema():
this.db.exec(`
  CREATE TABLE IF NOT EXISTS user_media_uploads (
    id TEXT PRIMARY KEY,
    creator_id TEXT NOT NULL,
    media_kind TEXT NOT NULL,
    title TEXT NOT NULL,
    filename TEXT NOT NULL,
    mime_type TEXT NOT NULL,
    size_bytes INTEGER NOT NULL,
    duration_ms INTEGER,
    width INTEGER,
    height INTEGER,
    r2_key TEXT NOT NULL,
    remote_url TEXT NOT NULL,
    thumbnail_url TEXT,
    source_surface TEXT NOT NULL DEFAULT 'vault',
    created_at TEXT NOT NULL,
    deleted_at TEXT
  );
  CREATE INDEX IF NOT EXISTS idx_sqlite_user_media_uploads_creator
    ON user_media_uploads (creator_id, created_at DESC);
`);

// Inside VhunambiDatabase class methods (1:1 parity with EdgeIsolateDatabaseEngine):
public recordUserMediaUpload(
  input: Partial<UserMediaUploadRecord> & { id: string; r2Key: string; remoteUrl: string },
  _skipMirror = false,
): UserMediaUploadRecord {
  const record = normalizeUserMediaUploadRow({
    ...input,
    creatorId: canonicalizeCreatorId(input.creatorId ?? 'creator_cern'),
    createdAt: input.createdAt ?? new Date().toISOString(),
  });
  this.db
    .prepare(
      `INSERT INTO user_media_uploads (
        id, creator_id, media_kind, title, filename, mime_type, size_bytes,
        duration_ms, width, height, r2_key, remote_url, thumbnail_url,
        source_surface, created_at, deleted_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        title = excluded.title,
        remote_url = excluded.remote_url,
        thumbnail_url = excluded.thumbnail_url,
        deleted_at = excluded.deleted_at`,
    )
    .run(
      record.id,
      record.creatorId,
      record.mediaKind,
      record.title,
      record.filename,
      record.mimeType,
      record.sizeBytes,
      record.durationMs,
      record.width,
      record.height,
      record.r2Key,
      record.remoteUrl,
      record.thumbnailUrl,
      record.sourceSurface,
      record.createdAt,
      record.deletedAt,
    );
  return record;
}

public async recordUserMediaUploadAsync(
  input: Partial<UserMediaUploadRecord> & { id: string; r2Key: string; remoteUrl: string },
  _cOrEnv?: unknown,
): Promise<UserMediaUploadRecord> {
  return this.recordUserMediaUpload(input, true);
}

public getUserMediaUploadById(id: string): UserMediaUploadRecord | null {
  const row = this.db
    .prepare(
      `SELECT * FROM user_media_uploads WHERE id = ? AND deleted_at IS NULL LIMIT 1`,
    )
    .get(id) as Record<string, unknown> | undefined;
  return row ? normalizeUserMediaUploadRow(row) : null;
}

public listUserMediaUploads(
  creatorId: string,
  kind?: MediaUploadKindWire,
): UserMediaUploadRecord[] {
  const cid = canonicalizeCreatorId(creatorId);
  const rows = (
    kind
      ? this.db
          .prepare(
            `SELECT * FROM user_media_uploads
             WHERE creator_id = ? AND media_kind = ? AND deleted_at IS NULL
             ORDER BY created_at DESC`,
          )
          .all(cid, kind)
      : this.db
          .prepare(
            `SELECT * FROM user_media_uploads
             WHERE creator_id = ? AND deleted_at IS NULL
             ORDER BY created_at DESC`,
          )
          .all(cid)
  ) as Array<Record<string, unknown>>;
  return rows.map((r) => normalizeUserMediaUploadRow(r));
}

public async syncUserMediaUploadsFromCloud(
  creatorId: string,
  _cOrEnv?: unknown,
  _force = false,
): Promise<UserMediaUploadRecord[]> {
  return this.listUserMediaUploads(creatorId);
}

public deleteUserMediaUpload(
  id: string,
  creatorId?: string,
  _skipMirror = false,
): boolean {
  const existing = this.getUserMediaUploadById(id);
  if (!existing) return false;
  if (
    creatorId &&
    canonicalizeCreatorId(existing.creatorId) !== canonicalizeCreatorId(creatorId)
  ) {
    return false;
  }
  const deletedAt = new Date().toISOString();
  const res = this.db
    .prepare(`UPDATE user_media_uploads SET deleted_at = ? WHERE id = ?`)
    .run(deletedAt, id);
  return Number(res.changes ?? 0) > 0;
}

public async deleteUserMediaUploadAsync(
  id: string,
  creatorId?: string,
  _cOrEnv?: unknown,
): Promise<boolean> {
  return this.deleteUserMediaUpload(id, creatorId, true);
}
```

---

### 1.3 Worker Media Router (`apps/vhunambi_api/src/routes/media_routes.ts`, `social_routes.ts`, `server.ts`)

```typescript
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
    title || safeFilename.replace(/\.[^.]+$/, '').replace(/[_-]+/g, ' ').trim() || 'Uploaded Media';
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
    canonicalizeCreatorId(existing.creatorId) !== canonicalizeCreatorId(authUser.creatorId) &&
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
```

In `apps/vhunambi_api/src/server.ts`:
- Add `p.startsWith('/api/media') || p.startsWith('/api/v1/media')` to `hasScopedReadThrough`.
- Mount `app.route('/api/media', mediaRoutes);` and `app.route('/api/v1/media', mediaRoutes);`.

In `apps/vhunambi_api/src/routes/social_routes.ts` (`POST /social/media/upload`):
- After `uploadBytesToR2`, also call `await vhunambiDb.recordUserMediaUploadAsync({ id: 'upl_soc_' + nanoid(10), creatorId, mediaKind: inferMediaKindFromMime(mimeType), title: 'Social Media Upload', filename: stored.key.split('/').pop() ?? 'upload.' + ext, mimeType, sizeBytes: bytes.byteLength, r2Key: stored.key, remoteUrl: '/r2/' + stored.key, sourceSurface: 'social' }, c);` while keeping the `201` `{ success: true, key, url, contentType, size }` JSON body unchanged.

---

## 2. Pass 1 (`M79.2`) — Client `VhunambiMediaVault`, Resumable Sync Queue & Studio Real-Time Playback

### 2.1 Pure Dart Domain Model: `lib/features/media/domain/models/uploaded_media_asset.dart`

```dart
import 'package:flutter/foundation.dart';

enum MediaAssetKind { audio, video, image }

enum MediaUploadStatus { queued, uploading, synced, failed }

@immutable
class UploadedMediaAsset {
  final String id;
  final String creatorId;
  final MediaAssetKind kind;
  final String title;
  final String filename;
  final String mimeType;
  final int sizeBytes;
  final String? localFilePath;
  final String? thumbnailLocalPath;
  final String? remoteUrl;
  final String? remoteKey;
  final int? durationMs;
  final int? width;
  final int? height;
  final String sourceSurface;
  final MediaUploadStatus status;
  final double progress;
  final String? errorMessage;
  final DateTime createdAt;

  const UploadedMediaAsset({
    required this.id,
    required this.creatorId,
    required this.kind,
    required this.title,
    required this.filename,
    required this.mimeType,
    required this.sizeBytes,
    this.localFilePath,
    this.thumbnailLocalPath,
    this.remoteUrl,
    this.remoteKey,
    this.durationMs,
    this.width,
    this.height,
    this.sourceSurface = 'vault',
    this.status = MediaUploadStatus.queued,
    this.progress = 0.0,
    this.errorMessage,
    required this.createdAt,
  });

  String? get bestPlayableOrRenderableSource {
    if (localFilePath != null && localFilePath!.trim().isNotEmpty) {
      return localFilePath;
    }
    if (remoteUrl != null && remoteUrl!.trim().isNotEmpty) {
      return remoteUrl;
    }
    return null;
  }

  UploadedMediaAsset copyWith({
    String? title,
    String? localFilePath,
    String? thumbnailLocalPath,
    String? remoteUrl,
    bool clearRemoteUrl = false,
    String? remoteKey,
    int? durationMs,
    int? width,
    int? height,
    MediaUploadStatus? status,
    double? progress,
    String? errorMessage,
    bool clearError = false,
  }) {
    return UploadedMediaAsset(
      id: id,
      creatorId: creatorId,
      kind: kind,
      title: title ?? this.title,
      filename: filename,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      localFilePath: localFilePath ?? this.localFilePath,
      thumbnailLocalPath: thumbnailLocalPath ?? this.thumbnailLocalPath,
      remoteUrl: clearRemoteUrl ? null : (remoteUrl ?? this.remoteUrl),
      remoteKey: remoteKey ?? this.remoteKey,
      durationMs: durationMs ?? this.durationMs,
      width: width ?? this.width,
      height: height ?? this.height,
      sourceSurface: sourceSurface,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'creatorId': creatorId,
    'mediaKind': kind.name,
    'title': title,
    'filename': filename,
    'mimeType': mimeType,
    'sizeBytes': sizeBytes,
    if (localFilePath != null) 'localFilePath': localFilePath,
    if (thumbnailLocalPath != null) 'thumbnailLocalPath': thumbnailLocalPath,
    if (remoteUrl != null) 'remoteUrl': remoteUrl,
    if (remoteKey != null) 'r2Key': remoteKey,
    if (durationMs != null) 'durationMs': durationMs,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    'sourceSurface': sourceSurface,
    'status': status.name,
    'progress': progress,
    if (errorMessage != null) 'errorMessage': errorMessage,
    'createdAt': createdAt.toIso8601String(),
  };

  factory UploadedMediaAsset.fromJson(Map<String, dynamic> json) {
    final kindRaw = (json['mediaKind'] ?? json['kind'] ?? 'image')
        .toString()
        .toLowerCase();
    final kind = switch (kindRaw) {
      'audio' => MediaAssetKind.audio,
      'video' => MediaAssetKind.video,
      _ => MediaAssetKind.image,
    };
    final statusRaw = (json['status'] ??
            (json['remoteUrl'] != null ? 'synced' : 'queued'))
        .toString()
        .toLowerCase();
    final status = switch (statusRaw) {
      'uploading' => MediaUploadStatus.uploading,
      'synced' => MediaUploadStatus.synced,
      'failed' => MediaUploadStatus.failed,
      _ => MediaUploadStatus.queued,
    };
    return UploadedMediaAsset(
      id: (json['id'] ?? '').toString(),
      creatorId: (json['creatorId'] ?? json['creator_id'] ?? 'creator_cern')
          .toString(),
      kind: kind,
      title: (json['title'] ?? 'Uploaded Media').toString(),
      filename: (json['filename'] ?? 'upload.bin').toString(),
      mimeType: (json['mimeType'] ?? json['mime_type'] ?? 'application/octet-stream')
          .toString(),
      sizeBytes: (json['sizeBytes'] ?? json['size_bytes'] as num?)?.toInt() ?? 1,
      localFilePath: json['localFilePath'] as String?,
      thumbnailLocalPath:
          (json['thumbnailLocalPath'] ?? json['thumbnailUrl']) as String?,
      remoteUrl: (json['remoteUrl'] ?? json['remote_url']) as String?,
      remoteKey: (json['r2Key'] ?? json['r2_key']) as String?,
      durationMs: (json['durationMs'] ?? json['duration_ms'] as num?)?.toInt(),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      sourceSurface:
          (json['sourceSurface'] ?? json['source_surface'] ?? 'vault').toString(),
      status: status,
      progress: ((json['progress'] as num?)?.toDouble() ??
              (status == MediaUploadStatus.synced ? 1.0 : 0.0))
          .clamp(0.0, 1.0),
      errorMessage: json['errorMessage'] as String?,
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}
```

---

### 2.2 Hive Box Registration & `SovereignMediaStorageService` (`lib/core/media/sovereign_media_storage_service.dart`)

- **`app_constants.dart`:** Add `static const String mediaUploadsBoxKey = 'vhunambi_uploads_v1';`.
- **`sovereign_hive_bootstrap_service.dart`:** Append `AppConstants.mediaUploadsBoxKey` to `tier1BoxKeys` (`18` Tier-1 boxes, `27` total boxes) and update `test/features/storage/sovereign_hive_bootstrap_test.dart` (`17 -> 18`, `26 -> 27`).
- **`sovereign_domain_repositories.dart`:** Invoke `SovereignMediaStorageService.clearTenantSessionMemory()` inside `SovereignDomainStorageMode.clearTenantMemory()` and `clearAllForTesting()`.

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/utils/creator_id_utils.dart';
import 'package:vhunambi_client/features/media/domain/models/uploaded_media_asset.dart';

/// Local-first sandbox file vault + multi-tenant Hive persistence for user media
/// (`EP-P79-MEDIA-UPLOAD-ENGINE`, `REQ-P79-VLT-01`).
class SovereignMediaStorageService {
  static final Map<String, Map<String, dynamic>> _sessionFallbackStore =
      <String, Map<String, dynamic>>{};

  static bool get isTestEnv {
    if (const bool.fromEnvironment('FLUTTER_TEST')) return true;
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  static void clearTenantSessionMemory() {
    _sessionFallbackStore.clear();
  }

  static String compositeKey(String creatorId, String assetId) {
    final cid = canonicalizeCreatorId(creatorId);
    return '$cid::$assetId';
  }

  static String sanitizeExtension(String filename, String mimeType) {
    final lowerName = filename.toLowerCase();
    final dotIdx = lowerName.lastIndexOf('.');
    if (dotIdx != -1 && dotIdx < lowerName.length - 1) {
      final candidate = lowerName.substring(dotIdx + 1).replaceAll(
        RegExp(r'[^a-z0-9]'),
        '',
      );
      if (candidate.isNotEmpty && candidate.length <= 5) {
        return candidate;
      }
    }
    return switch (mimeType.toLowerCase()) {
      'audio/mpeg' => 'mp3',
      'audio/mp4' => 'm4a',
      'audio/wav' || 'audio/x-wav' || 'audio/wave' => 'wav',
      'audio/aac' => 'aac',
      'audio/ogg' => 'ogg',
      'video/quicktime' => 'mov',
      'video/webm' => 'webm',
      'video/mp4' => 'mp4',
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
  }

  /// Copies [bytes] into persistent sandbox storage (`AppDocs/vhunambi_media/...`
  /// on device, or deterministic system temp directory under `FLUTTER_TEST`) in <50ms.
  static Future<String?> stageMediaBytes({
    required String creatorId,
    required String assetId,
    required MediaAssetKind kind,
    required String filename,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    if (kIsWeb || bytes.isEmpty) return null;
    final cid = canonicalizeCreatorId(creatorId);
    final ext = sanitizeExtension(filename, mimeType);
    final folder = switch (kind) {
      MediaAssetKind.audio => 'audio',
      MediaAssetKind.video => 'video',
      MediaAssetKind.image => 'images',
    };

    Directory rootDir;
    if (isTestEnv) {
      rootDir = Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}vhunambi_test_media${Platform.pathSeparator}$cid${Platform.pathSeparator}$folder',
      );
    } else {
      final docs = await getApplicationDocumentsDirectory();
      rootDir = Directory(
        '${docs.path}${Platform.pathSeparator}vhunambi_media${Platform.pathSeparator}$cid${Platform.pathSeparator}$folder',
      );
    }
    if (!rootDir.existsSync()) {
      await rootDir.create(recursive: true);
    }
    final targetFile = File(
      '${rootDir.path}${Platform.pathSeparator}$assetId.$ext',
    );
    await targetFile.writeAsBytes(bytes, flush: true);
    return targetFile.path;
  }

  static Future<void> saveAsset(UploadedMediaAsset asset) async {
    final key = compositeKey(asset.creatorId, asset.id);
    final payload = asset.toJson();
    _sessionFallbackStore[key] = payload;
    if (Hive.isBoxOpen(AppConstants.mediaUploadsBoxKey)) {
      final box = Hive.box<dynamic>(AppConstants.mediaUploadsBoxKey);
      await box.put(key, jsonEncode(payload));
    }
  }

  static List<UploadedMediaAsset> loadCreatorAssets(String creatorId) {
    final cid = canonicalizeCreatorId(creatorId);
    final prefix = '$cid::';
    final merged = <String, UploadedMediaAsset>{};

    for (final entry in _sessionFallbackStore.entries) {
      if (entry.key.startsWith(prefix)) {
        final asset = UploadedMediaAsset.fromJson(entry.value);
        if (asset.id.isNotEmpty) merged[asset.id] = asset;
      }
    }

    if (Hive.isBoxOpen(AppConstants.mediaUploadsBoxKey)) {
      final box = Hive.box<dynamic>(AppConstants.mediaUploadsBoxKey);
      for (final dynamic rawKey in box.keys) {
        final k = rawKey.toString();
        if (!k.startsWith(prefix)) continue;
        final dynamic rawVal = box.get(rawKey);
        try {
          Map<String, dynamic>? map;
          if (rawVal is String && rawVal.isNotEmpty) {
            map = jsonDecode(rawVal) as Map<String, dynamic>;
          } else if (rawVal is Map) {
            map = Map<String, dynamic>.from(rawVal);
          }
          if (map != null) {
            final asset = UploadedMediaAsset.fromJson(map);
            if (asset.id.isNotEmpty) merged[asset.id] = asset;
          }
        } catch (_) {}
      }
    }

    final list = merged.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static Future<void> removeAsset(UploadedMediaAsset asset) async {
    final key = compositeKey(asset.creatorId, asset.id);
    _sessionFallbackStore.remove(key);
    if (Hive.isBoxOpen(AppConstants.mediaUploadsBoxKey)) {
      final box = Hive.box<dynamic>(AppConstants.mediaUploadsBoxKey);
      await box.delete(key);
    }
    if (!kIsWeb &&
        asset.localFilePath != null &&
        asset.localFilePath!.isNotEmpty) {
      try {
        final f = File(asset.localFilePath!);
        if (f.existsSync()) {
          await f.delete();
        }
      } catch (_) {}
    }
  }
}
```

---

### 2.3 `HttpMediaUploadRepository` & Resumable `MediaUploadQueueNotifier`

#### A. `lib/features/media/data/repositories/http_media_upload_repository.dart`

```dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/features/media/domain/models/uploaded_media_asset.dart';

abstract class IMediaUploadRepository {
  Future<UploadedMediaAsset> uploadMedia({
    required UploadedMediaAsset staged,
    required Uint8List bytes,
    void Function(int sent, int total)? onProgress,
  });

  Future<List<UploadedMediaAsset>> fetchUploads({
    required String creatorId,
    MediaAssetKind? kind,
  });

  Future<bool> deleteRemoteUpload(String assetId);
}

class HttpMediaUploadRepository implements IMediaUploadRepository {
  final Dio _dio;
  final String _baseUrl;

  HttpMediaUploadRepository({
    Dio? dio,
    String? baseUrl,
    Interceptor? authInterceptor,
  }) : _baseUrl = baseUrl ?? AppConstants.apiRestBaseUrl,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               sendTimeout: const Duration(seconds: 90),
               receiveTimeout: const Duration(seconds: 30),
             ),
           ) {
    if (dio == null && authInterceptor != null) {
      _dio.interceptors.add(authInterceptor);
    }
  }

  @override
  Future<UploadedMediaAsset> uploadMedia({
    required UploadedMediaAsset staged,
    required Uint8List bytes,
    void Function(int sent, int total)? onProgress,
  }) async {
    final form = FormData.fromMap(<String, dynamic>{
      'title': staged.title,
      'filename': staged.filename,
      'sourceSurface': staged.sourceSurface,
      if (staged.durationMs != null) 'durationMs': '${staged.durationMs}',
      if (staged.width != null) 'width': '${staged.width}',
      if (staged.height != null) 'height': '${staged.height}',
      'file': MultipartFile.fromBytes(
        bytes,
        filename: staged.filename,
        contentType: DioMediaType.parse(staged.mimeType),
      ),
    });

    final res = await _dio.post<Map<String, dynamic>>(
      '$_baseUrl/media/upload',
      data: form,
      onSendProgress: onProgress,
    );

    final body = res.data ?? const <String, dynamic>{};
    final rawAsset = body['asset'] is Map
        ? Map<String, dynamic>.from(body['asset'] as Map)
        : <String, dynamic>{};
    final rawUrl = (rawAsset['remoteUrl'] ?? body['url'] ?? '').toString();
    if (rawUrl.isEmpty) {
      throw DioException(
        requestOptions: res.requestOptions,
        message: 'Upload response did not include a valid R2 URL',
      );
    }
    final normalizedUrl = AppConstants.normalizeCloudMediaUrl(rawUrl);

    return staged.copyWith(
      remoteUrl: normalizedUrl,
      remoteKey: (rawAsset['r2Key'] ?? body['key'])?.toString(),
      status: MediaUploadStatus.synced,
      progress: 1.0,
      clearError: true,
    );
  }

  @override
  Future<List<UploadedMediaAsset>> fetchUploads({
    required String creatorId,
    MediaAssetKind? kind,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '$_baseUrl/media/uploads',
      queryParameters: <String, dynamic>{
        'creatorId': creatorId,
        if (kind != null) 'kind': kind.name,
      },
    );
    final rawList = res.data?['uploads'];
    if (rawList is! List) return const <UploadedMediaAsset>[];
    return rawList
        .whereType<Map>()
        .map(
          (m) => UploadedMediaAsset.fromJson(Map<String, dynamic>.from(m)).copyWith(
            remoteUrl: AppConstants.normalizeCloudMediaUrl(
              (m['remoteUrl'] ?? m['remote_url'] ?? '').toString(),
            ),
            status: MediaUploadStatus.synced,
            progress: 1.0,
          ),
        )
        .toList();
  }

  @override
  Future<bool> deleteRemoteUpload(String assetId) async {
    final res = await _dio.delete<Map<String, dynamic>>(
      '$_baseUrl/media/uploads/$assetId',
    );
    return res.data?['success'] == true;
  }
}
```

#### B. `lib/features/media/presentation/providers/media_upload_queue_provider.dart`

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/media/sovereign_media_storage_service.dart';
import 'package:vhunambi_client/core/utils/creator_id_utils.dart';
import 'package:vhunambi_client/features/media/data/repositories/http_media_upload_repository.dart';
import 'package:vhunambi_client/features/media/domain/models/uploaded_media_asset.dart';
import 'package:vhunambi_client/features/social/domain/repositories/i_social_repository.dart';
import 'package:vhunambi_client/features/social/presentation/providers/social_repository_provider.dart';

/// Optional custom [IMediaUploadRepository] override for unit/widget tests.
final customMediaUploadRepositoryProvider = Provider<IMediaUploadRepository?>(
  (ref) => null,
);

final mediaUploadRepositoryProvider = Provider<IMediaUploadRepository>((ref) {
  final custom = ref.watch(customMediaUploadRepositoryProvider);
  if (custom != null) return custom;
  return HttpMediaUploadRepository(
    authInterceptor: ref.watch(authDioInterceptorProvider),
  );
});

final mediaUploadQueueProvider =
    StateNotifierProvider<MediaUploadQueueNotifier, List<UploadedMediaAsset>>((
      ref,
    ) {
      final creatorId = ref.watch(currentCreatorIdProvider);
      final repo = ref.watch(mediaUploadRepositoryProvider);
      final hasCustomMediaRepo =
          ref.watch(customMediaUploadRepositoryProvider) != null;
      final socialRepo = ref.watch(socialRepositoryProvider);
      return MediaUploadQueueNotifier(
        creatorId: creatorId,
        repository: repo,
        fallbackSocialRepository: socialRepo,
        useTestSocialFallback:
            SovereignMediaStorageService.isTestEnv && !hasCustomMediaRepo,
      );
    });

class MediaUploadQueueNotifier extends StateNotifier<List<UploadedMediaAsset>> {
  final String creatorId;
  final IMediaUploadRepository _repository;
  final ISocialRepository _fallbackSocialRepository;
  final bool _useTestSocialFallback;
  final Map<String, Uint8List> _inMemoryBytes = <String, Uint8List>{};

  MediaUploadQueueNotifier({
    required this.creatorId,
    required IMediaUploadRepository repository,
    required ISocialRepository fallbackSocialRepository,
    required bool useTestSocialFallback,
  }) : _repository = repository,
       _fallbackSocialRepository = fallbackSocialRepository,
       _useTestSocialFallback = useTestSocialFallback,
       super(
         SovereignMediaStorageService.loadCreatorAssets(
           canonicalizeCreatorId(creatorId),
         ),
       );

  /// Stages [bytes] locally in <50ms, records [UploadedMediaAsset] in Hive,
  /// and starts background R2 upload (or awaits completion when [awaitUpload] is true).
  Future<UploadedMediaAsset> stageAndEnqueue({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    required MediaAssetKind kind,
    String? title,
    String sourceSurface = 'vault',
    int? durationMs,
    int? width,
    int? height,
    bool awaitUpload = false,
  }) async {
    final cid = canonicalizeCreatorId(creatorId);
    final id = 'upl_${DateTime.now().microsecondsSinceEpoch}';
    final localPath = await SovereignMediaStorageService.stageMediaBytes(
      creatorId: cid,
      assetId: id,
      kind: kind,
      filename: filename,
      mimeType: mimeType,
      bytes: bytes,
    );
    final resolvedTitle =
        (title != null && title.trim().isNotEmpty)
            ? title.trim()
            : filename.replaceAll(RegExp(r'\.[^.]+$'), '').trim();

    final initial = UploadedMediaAsset(
      id: id,
      creatorId: cid,
      kind: kind,
      title: resolvedTitle.isEmpty ? 'Uploaded Media' : resolvedTitle,
      filename: filename,
      mimeType: mimeType,
      sizeBytes: bytes.length,
      localFilePath: localPath,
      sourceSurface: sourceSurface,
      durationMs: durationMs,
      width: width,
      height: height,
      status: MediaUploadStatus.queued,
      progress: 0.0,
      createdAt: DateTime.now(),
    );

    _inMemoryBytes[id] = bytes;
    state = <UploadedMediaAsset>[
      initial,
      ...state.where((e) => e.id != id),
    ];
    await SovereignMediaStorageService.saveAsset(initial);

    if (awaitUpload) {
      return _performUpload(id);
    }
    unawaited(_performUpload(id));
    return initial;
  }

  Future<UploadedMediaAsset> _performUpload(String assetId) async {
    final idx = state.indexWhere((a) => a.id == assetId);
    if (idx == -1) {
      throw StateError('Upload asset $assetId not found');
    }
    final current = state[idx];
    Uint8List? bytes = _inMemoryBytes[assetId];
    if (bytes == null &&
        !kIsWeb &&
        current.localFilePath != null &&
        File(current.localFilePath!).existsSync()) {
      bytes = await File(current.localFilePath!).readAsBytes();
    }
    if (bytes == null || bytes.isEmpty) {
      final failedMissing = current.copyWith(
        status: MediaUploadStatus.failed,
        clearRemoteUrl: true,
        errorMessage: 'Local media file unavailable for upload.',
      );
      await _replaceAsset(failedMissing);
      return failedMissing;
    }

    final uploading = current.copyWith(
      status: MediaUploadStatus.uploading,
      progress: 0.05,
      clearError: true,
    );
    await _replaceAsset(uploading);

    try {
      if (_useTestSocialFallback) {
        final socialRes = await _fallbackSocialRepository.uploadReelMedia(
          bytes: bytes,
          filename: uploading.filename,
          mimeType: uploading.mimeType,
        );
        final syncedTest = uploading.copyWith(
          remoteUrl: socialRes.url,
          remoteKey: socialRes.key,
          status: MediaUploadStatus.synced,
          progress: 1.0,
          clearError: true,
        );
        await _replaceAsset(syncedTest);
        return syncedTest;
      }

      final synced = await _repository.uploadMedia(
        staged: uploading,
        bytes: bytes,
        onProgress: (sent, total) {
          if (!mounted || total <= 0) return;
          final pct = (sent / total).clamp(0.05, 0.98);
          _updateProgressInMemory(assetId, pct);
        },
      );
      await _replaceAsset(synced);
      return synced;
    } catch (e) {
      final failed = uploading.copyWith(
        status: MediaUploadStatus.failed,
        clearRemoteUrl: true,
        progress: 0.0,
        errorMessage: e.toString(),
      );
      await _replaceAsset(failed);
      return failed;
    }
  }

  void _updateProgressInMemory(String assetId, double progress) {
    final idx = state.indexWhere((a) => a.id == assetId);
    if (idx == -1) return;
    final next = List<UploadedMediaAsset>.of(state);
    next[idx] = next[idx].copyWith(
      status: MediaUploadStatus.uploading,
      progress: progress,
    );
    state = next;
  }

  Future<void> _replaceAsset(UploadedMediaAsset updated) async {
    if (!mounted) return;
    state = <UploadedMediaAsset>[
      for (final item in state)
        if (item.id == updated.id) updated else item,
    ];
    await SovereignMediaStorageService.saveAsset(updated);
  }

  Future<UploadedMediaAsset?> retryUpload(String assetId) async {
    final exists = state.any((a) => a.id == assetId);
    if (!exists) return null;
    return _performUpload(assetId);
  }

  Future<void> retryAllPending() async {
    final pendingIds = state
        .where(
          (a) =>
              a.status == MediaUploadStatus.failed ||
              a.status == MediaUploadStatus.queued,
        )
        .map((a) => a.id)
        .toList();
    for (final id in pendingIds) {
      await _performUpload(id);
    }
  }

  Future<void> deleteUpload(String assetId) async {
    final target = state.where((a) => a.id == assetId).firstOrNull;
    if (target == null) return;
    _inMemoryBytes.remove(assetId);
    state = state.where((a) => a.id != assetId).toList();
    await SovereignMediaStorageService.removeAsset(target);
    if (!SovereignMediaStorageService.isTestEnv &&
        target.status == MediaUploadStatus.synced) {
      try {
        await _repository.deleteRemoteUpload(assetId);
      } catch (_) {}
    }
  }

  Future<void> syncFromCloud() async {
    if (_useTestSocialFallback) return;
    try {
      final remote = await _repository.fetchUploads(
        creatorId: canonicalizeCreatorId(creatorId),
      );
      if (!mounted || remote.isEmpty) return;
      final byId = <String, UploadedMediaAsset>{
        for (final local in state) local.id: local,
      };
      for (final cloudItem in remote) {
        final existing = byId[cloudItem.id];
        byId[cloudItem.id] = existing != null
            ? cloudItem.copyWith(localFilePath: existing.localFilePath)
            : cloudItem;
        await SovereignMediaStorageService.saveAsset(byId[cloudItem.id]!);
      }
      final merged = byId.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = merged;
    } catch (_) {}
  }
}
```

---

### 2.4 Local File Priority in `VhunambiTrackArtwork`, `AudioSourceResolver` & Studio Audio Transport

1. **`safe_audio_orchestrator.dart`:**
   ```dart
   enum AudioEngineSlot {
     masterPlayer,
     stemMixer,
     reelPool,
     sketchpad,
     studioPreview,
   }
   ```
2. **`vhunambi_track_artwork.dart`:**
   Add `import 'dart:io' show File;` and resolve readable local paths before `isRemote`:
   ```dart
   String? resolveLocalPath(String? rawUrl) {
     if (kIsWeb || rawUrl == null) return null;
     final trimmed = rawUrl.trim();
     if (trimmed.isEmpty) return null;
     if (trimmed.startsWith('file://')) {
       try {
         final p = Uri.parse(trimmed).toFilePath();
         if (File(p).existsSync()) return p;
       } catch (_) {}
       return null;
     }
     if (!trimmed.startsWith('http://') &&
         !trimmed.startsWith('https://') &&
         !trimmed.startsWith('asset:') &&
         !trimmed.startsWith('assets/')) {
       try {
         if (File(trimmed).existsSync()) return trimmed;
       } catch (_) {}
     }
     return null;
   }
   ```
   When `localPath != null`, render:
   ```dart
   Image.file(
     File(localPath),
     width: width,
     height: height,
     fit: BoxFit.cover,
     errorBuilder: (_, _, _) => buildAssetImage(genreAssetFallback),
   );
   ```
3. **`audio_source_resolver.dart`:**
   Immediately after Step 1 (encrypted `.vmf` check) and *before* Step 2 (`isOfflineModeForced`):
   ```dart
   final candidateRaw = (track.audioUrl ?? '').trim();
   if (!kIsWeb && candidateRaw.isNotEmpty) {
     String? plainLocalPath;
     if (candidateRaw.startsWith('file://')) {
       try {
         plainLocalPath = Uri.parse(candidateRaw).toFilePath();
       } catch (_) {}
     } else if (!candidateRaw.startsWith('http://') &&
         !candidateRaw.startsWith('https://') &&
         !candidateRaw.startsWith('/r2/') &&
         !candidateRaw.startsWith('/mock-storage/')) {
       plainLocalPath = candidateRaw;
     }
     if (plainLocalPath != null && _fileExists(plainLocalPath)) {
       return ResolvedAudioSource(
         uri: Uri.file(plainLocalPath),
         isLocalFile: true,
         localFilePath: plainLocalPath,
       );
     }
   }
   ```
4. **Studio Real-Time `AudioPlayer` in `KineticReelStudioView` (`kinetic_reel_studio_view.dart`):**
   ```dart
   AudioPlayer? _studioAudioPlayer;
   StreamSubscription<Duration>? _studioPosSub;
   bool _isStudioAudioPlaying = false;
   double _studioPlaybackPosSec = 0.0;

   Future<void> _syncStudioAudioTransport() async {
     if (_isTestEnv) return;
     if (_stage == _ReelStudioStage.publish) {
       await _pauseStudioAudio();
       return;
     }
     final sourcePath = _audio.localFilePath;
     final remoteRaw = _audio.audioUrl;
     if ((sourcePath == null || sourcePath.isEmpty) &&
         (remoteRaw == null || remoteRaw.isEmpty)) {
       return;
     }

     await ref.read(playerStateProvider.notifier).pause();
     await SafeAudioOrchestrator.instance.acquireSlot(
       AudioEngineSlot.studioPreview,
       onPreemptPause: _pauseStudioAudio,
     );

     final player = _studioAudioPlayer ??= AudioPlayer();
     _studioPosSub ??= player.positionStream.listen((pos) {
       if (!mounted) return;
       final ms = pos.inMilliseconds;
       if (ms >= _audioEndMs) {
         player.seek(Duration(milliseconds: _audioStartMs));
       }
       setState(() {
         _studioPlaybackPosSec = ms / 1000.0;
         _isStudioAudioPlaying = player.playing;
       });
     });

     try {
       if (!kIsWeb && sourcePath != null && File(sourcePath).existsSync()) {
         await player.setFilePath(sourcePath);
       } else if (remoteRaw != null && remoteRaw.isNotEmpty) {
         await player.setUrl(AppConstants.normalizeCloudMediaUrl(remoteRaw));
       }
       await player.setSpeed(_speedRate);
       await player.seek(Duration(milliseconds: _audioStartMs));
       unawaited(player.play());
       if (mounted) setState(() => _isStudioAudioPlaying = true);
     } catch (_) {}
   }

   Future<void> _pauseStudioAudio() async {
     try {
       await _studioAudioPlayer?.pause();
     } catch (_) {}
     if (mounted) {
       setState(() => _isStudioAudioPlaying = false);
     }
   }
   ```
   *(Dispose `_studioPosSub?.cancel()`, `_studioAudioPlayer?.dispose()`, and `SafeAudioOrchestrator.instance.unregisterSlot(AudioEngineSlot.studioPreview)` in `dispose()`.)*

5. **Stage 3 Video Poster, Live Byte Progress & Cellular Retry (`kinetic_reel_publish_view.dart`):**
   ```dart
   double _uploadProgress = 0.0;
   String? _publishError;
   String? _stagedUploadAssetId;
   VideoPlayerController? _posterVideoController;
   bool _posterReady = false;

   // Poster widget helper:
   Widget _buildStage3PosterPreview() {
     final isVideo =
         widget.mediaKind == 'camera_video' || widget.mediaKind == 'gallery_video';
     if (isVideo &&
         (widget.customMediaLocalPath != null || widget.customMediaBytes != null)) {
       return ClipRRect(
         key: const Key('publish_video_poster_preview'),
         borderRadius: BorderRadius.circular(14),
         child: SizedBox(
           width: 88,
           height: 124,
           child: _posterReady && _posterVideoController != null
               ? FittedBox(
                   fit: BoxFit.cover,
                   child: SizedBox(
                     width: _posterVideoController!.value.size.width,
                     height: _posterVideoController!.value.size.height,
                     child: VideoPlayer(_posterVideoController!),
                   ),
                 )
               : Container(
                   color: AppColors.darkSurfaceSecondary,
                   alignment: Alignment.center,
                   child: const PhosphorIcon(
                     AppIcons.reels,
                     color: AppColors.brandPrimary,
                     size: 28,
                   ),
                 ),
         ),
       );
     }
     if (widget.mediaKind == 'gallery_photo' &&
         (widget.customMediaLocalPath != null || widget.customMediaBytes != null)) {
       return ClipRRect(
         key: const Key('publish_photo_poster_preview'),
         borderRadius: BorderRadius.circular(14),
         child: !kIsWeb &&
                 widget.customMediaLocalPath != null &&
                 File(widget.customMediaLocalPath!).existsSync()
             ? Image.file(
                 File(widget.customMediaLocalPath!),
                 width: 88,
                 height: 124,
                 fit: BoxFit.cover,
               )
             : Image.memory(
                 widget.customMediaBytes!,
                 width: 88,
                 height: 124,
                 fit: BoxFit.cover,
               ),
       );
     }
     return ClipRRect(
       borderRadius: BorderRadius.circular(14),
       child: VhunambiTrackArtwork(
         trackId: widget.audio.id,
         title: widget.audio.title,
         genre: widget.audio.genre,
         coverUrl: widget.audio.coverUrl,
         width: 88,
         height: 124,
         borderRadius: 14,
       ),
     );
   }
   ```
   During `_submitPublish()`: stage/retry through `mediaUploadQueueProvider.notifier` (`awaitUpload: true`), mirror progress via `ref.listen(mediaUploadQueueProvider, ...)`, render `LinearProgressIndicator(key: const Key('reel_publish_progress_bar'), value: _uploadProgress > 0 ? _uploadProgress : null)`, and if `result.status == MediaUploadStatus.failed` or `publishClip` throws, set `_publishError` (without popping!) and render `OutlinedButton.icon(key: const Key('reel_publish_retry_btn'), onPressed: _submitPublish, icon: const PhosphorIcon(AppIcons.remix, size: 16), label: const Text('Retry Publish'))`.

---

## 3. Pass 2 (`M79.3` – `M79.4`) — `CreateKineticPostSheet` Glass Cockpit v2, `Uploads` Vault Hub & Reels Studio Layout Repairs

### 3.1 `CreateKineticPostSheet` Glass Cockpit v2 (`social_music_post.dart` & `create_kinetic_post_sheet.dart`)

1. **`KineticPostImageAttachment` (`social_music_post.dart`):**
   Add optional `final String? localFilePath;` and `final String? uploadAssetId;` fields (`copyWith`, `toJson`, `fromJson`), plus helper `String get bestRenderPath => (localFilePath != null && localFilePath!.isNotEmpty) ? localFilePath! : imageUrl;`.

2. **Above-the-Fold Live Visual Stage & `My Uploads` Reuse (`create_kinetic_post_sheet.dart`):**
   Mount `_buildLiveVisualStageCarousel(context, queueItems)` **immediately below `_buildCaptionField(context)`** so attached photos are 100% visible without scrolling:

   ```dart
   Widget _buildLiveVisualStageCarousel(
     BuildContext context,
     List<UploadedMediaAsset> queueAssets,
   ) {
     if (_attachedImages.isEmpty) return const SizedBox.shrink();
     final byId = <String, UploadedMediaAsset>{
       for (final item in queueAssets) item.id: item,
     };

     return Padding(
       key: const Key('kpost_media_preview_carousel'),
       padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm),
       child: SizedBox(
         height: 148,
         child: ListView.separated(
           scrollDirection: Axis.horizontal,
           itemCount: _attachedImages.length,
           separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
           itemBuilder: (context, index) {
             final att = _attachedImages[index];
             final tracked = att.uploadAssetId != null
                 ? byId[att.uploadAssetId!]
                 : null;
             final frameWidth = (148 * _selectedAspectRatio.ratio).clamp(
               112.0,
               220.0,
             );
             return SizedBox(
               width: frameWidth,
               height: 148,
               child: Stack(
                 fit: StackFit.expand,
                 children: [
                   VhunambiTrackArtwork(
                     trackId: 'kpost_att_$index',
                     title: att.visionPrompt ?? 'Attached Photo',
                     coverUrl: att.bestRenderPath,
                     width: frameWidth,
                     height: 148,
                     borderRadius: 14,
                   ),
                   if (tracked != null &&
                       tracked.status == MediaUploadStatus.uploading)
                     Container(
                       decoration: BoxDecoration(
                         color: Colors.black.withValues(alpha: 0.48),
                         borderRadius: BorderRadius.circular(14),
                       ),
                       alignment: Alignment.center,
                       child: Column(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           SizedBox(
                             width: 28,
                             height: 28,
                             child: CircularProgressIndicator(
                               value: tracked.progress,
                               strokeWidth: 2.6,
                               color: AppColors.brandPrimary,
                             ),
                           ),
                           const SizedBox(height: 4),
                           Text(
                             '${(tracked.progress * 100).round()}%',
                             style: AppTypography.badge.copyWith(
                               color: Colors.white,
                             ),
                           ),
                         ],
                       ),
                     ),
                   if (tracked != null &&
                       tracked.status == MediaUploadStatus.failed)
                     Container(
                       decoration: BoxDecoration(
                         color: Colors.black.withValues(alpha: 0.68),
                         borderRadius: BorderRadius.circular(14),
                       ),
                       alignment: Alignment.center,
                       child: TextButton.icon(
                         onPressed: () async {
                           final retried = await ref
                               .read(mediaUploadQueueProvider.notifier)
                               .retryUpload(tracked.id);
                           if (retried != null &&
                               retried.remoteUrl != null &&
                               mounted) {
                             setState(() {
                               _attachedImages[index] = KineticPostImageAttachment(
                                 imageUrl: retried.remoteUrl!,
                                 localFilePath: retried.localFilePath,
                                 uploadAssetId: retried.id,
                                 aspectRatio: _selectedAspectRatio,
                               );
                             });
                           }
                         },
                         icon: const PhosphorIcon(
                           AppIcons.remix,
                           size: 14,
                           color: AppColors.brandPrimary,
                         ),
                         label: Text(
                           'Retry',
                           style: AppTypography.caption.copyWith(
                             color: Colors.white,
                             fontWeight: FontWeight.w700,
                           ),
                         ),
                       ),
                     ),
                   Positioned(
                     top: 6,
                     right: 6,
                     child: GestureDetector(
                       key: Key('kpost_remove_image_$index'),
                       onTap: () => setState(() => _attachedImages.removeAt(index)),
                       child: Container(
                         width: 26,
                         height: 26,
                         decoration: BoxDecoration(
                           color: Colors.black.withValues(alpha: 0.65),
                           shape: BoxShape.circle,
                         ),
                         alignment: Alignment.center,
                         child: const PhosphorIcon(
                           AppIcons.close,
                           size: 14,
                           color: Colors.white,
                         ),
                       ),
                     ),
                   ),
                 ],
               ),
             );
           },
         ),
       ),
     );
   }
   ```
   - Add `Key('kpost_pick_from_uploads_btn')` pill next to `Key('kpost_pick_photo_btn')` / `Key('kpost_upload_photo_btn')` opening a modal sheet of `MediaAssetKind.image` items from `mediaUploadQueueProvider`.
   - Replace the bare sound `PopupMenuButton` with `VhunambiGlassTabBar(key: const Key('kpost_audio_source_tabs'), items: [My Uploads, My Vault, Trending, Grooves], ...)` + `VhunambiGlassSurface(key: const Key('kpost_audio_attachment_card'), ...)` containing `VhunambiTrackArtwork` (`48x48`), `IconButton(key: const Key('kpost_audio_audition_btn'), ...)` guarded by `SafeAudioOrchestrator` + `_detectTestMode()`, hook duration pills (`kpost_trim_15s`, `kpost_trim_30s`, `kpost_trim_60s`, `kpost_trim_full`), and horizontal track selector chips.
   - Migrate every remaining static `AppColors.*` token in `create_kinetic_post_sheet.dart` to `*Of(context)`.

---

### 3.2 `LibraryCategory.uploads` Across All 5 Coupled Library Files + `UploadsVaultView`

1. **`library_models.dart`:** `enum LibraryCategory { songs, reels, uploads, playlists, collections, beats, licensing, trash }`
2. **`library_providers.dart`:** Add `ownerMediaUploadsProvider`, wire `LibraryCategory.uploads` count in `libraryCategoryCountsProvider`, add `LibraryCategory.uploads => false` in `_matchesCategory`, and scrub `'AI Studio'` / `'@aistudio'` in `LibraryTracksNotifier.hydrateFromLocalBox`.
3. **`library_category_rail.dart`:** Insert `_CategoryPillSpec(category: LibraryCategory.uploads, label: 'Uploads', icon: AppIcons.upload)` (never `PhosphorIconsRegular.sparkle`!).
4. **`library_empty_state.dart`:** Add `LibraryCategory.uploads` case (`icon: AppIcons.upload`, `headline: 'No uploads yet'`, `ctaLabel: 'Upload audio or media'`, `ctaIcon: AppIcons.upload`).
5. **`library_view.dart` & `lib/features/library/presentation/views/uploads_vault_view.dart`:**

```dart
import 'dart:io' show Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_bottom_dock_kit.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_glass_surface.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_glass_tab_bar.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_track_artwork.dart';
import 'package:vhunambi_client/features/content_studio/presentation/views/kinetic_reel_studio_view.dart';
import 'package:vhunambi_client/features/explore/presentation/widgets/create_kinetic_post_sheet.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/library/presentation/widgets/library_empty_state.dart';
import 'package:vhunambi_client/features/media/domain/models/uploaded_media_asset.dart';
import 'package:vhunambi_client/features/media/presentation/providers/media_upload_queue_provider.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/shared/models/track.dart';

class UploadsVaultView extends ConsumerStatefulWidget {
  const UploadsVaultView({super.key});

  @override
  ConsumerState<UploadsVaultView> createState() => _UploadsVaultViewState();
}

class _UploadsVaultViewState extends ConsumerState<UploadsVaultView> {
  int _kindTabIndex = 0; // 0: All, 1: Audio, 2: Video, 3: Images

  bool get _isTestEnv {
    if (const bool.fromEnvironment('FLUTTER_TEST')) return true;
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _pickAndEnqueueMedia() async {
    if (_isTestEnv) {
      await ref.read(mediaUploadQueueProvider.notifier).stageAndEnqueue(
            bytes: Uint8List.fromList(<int>[0x52, 0x49, 0x46, 0x46, 0x01, 0x02]),
            filename: 'abafana_master.wav',
            mimeType: 'audio/wav',
            kind: MediaAssetKind.audio,
            title: 'Abafana Master',
            sourceSurface: 'vault',
          );
      return;
    }
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      withData: true,
      allowedExtensions: const <String>[
        'mp3',
        'm4a',
        'wav',
        'aac',
        'ogg',
        'mp4',
        'mov',
        'webm',
        'jpg',
        'jpeg',
        'png',
        'webp',
      ],
    );
    final file = picked?.files.firstOrNull;
    if (file == null || file.bytes == null) return;
    final ext = (file.extension ?? '').toLowerCase();
    final (MediaAssetKind kind, String mime) = switch (ext) {
      'mp3' => (MediaAssetKind.audio, 'audio/mpeg'),
      'm4a' => (MediaAssetKind.audio, 'audio/mp4'),
      'wav' => (MediaAssetKind.audio, 'audio/wav'),
      'aac' => (MediaAssetKind.audio, 'audio/aac'),
      'ogg' => (MediaAssetKind.audio, 'audio/ogg'),
      'mp4' => (MediaAssetKind.video, 'video/mp4'),
      'mov' => (MediaAssetKind.video, 'video/quicktime'),
      'webm' => (MediaAssetKind.video, 'video/webm'),
      'png' => (MediaAssetKind.image, 'image/png'),
      'webp' => (MediaAssetKind.image, 'image/webp'),
      _ => (MediaAssetKind.image, 'image/jpeg'),
    };
    await ref.read(mediaUploadQueueProvider.notifier).stageAndEnqueue(
          bytes: file.bytes!,
          filename: file.name,
          mimeType: mime,
          kind: kind,
          sourceSurface: 'vault',
        );
  }

  @override
  Widget build(BuildContext context) {
    final allUploads = ref.watch(ownerMediaUploadsProvider);
    final query = ref.watch(librarySearchQueryProvider);
    final hasActiveTrack = ref.watch(
      playerStateProvider.select((s) => s.hasActiveTrack),
    );
    final bottomInset = VhunambiBottomDockMetrics.scrollInset(
      hasActiveTrack: hasActiveTrack,
    );

    final filtered = allUploads.where((u) {
      return switch (_kindTabIndex) {
        1 => u.kind == MediaAssetKind.audio,
        2 => u.kind == MediaAssetKind.video,
        3 => u.kind == MediaAssetKind.image,
        _ => true,
      };
    }).toList();

    if (allUploads.isEmpty) {
      return LibraryEmptyState(
        key: const Key('library_uploads_vault_view'),
        category: LibraryCategory.uploads,
        searchQuery: query,
        onCreateRequested: _pickAndEnqueueMedia,
      );
    }

    return Padding(
      key: const Key('library_uploads_vault_view'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: VhunambiGlassTabBar(
                  key: const Key('library_uploads_kind_tabs'),
                  selectedIndex: _kindTabIndex,
                  onSelected: (i) => setState(() => _kindTabIndex = i),
                  items: const <VhunambiGlassTabItem>[
                    VhunambiGlassTabItem(label: 'All'),
                    VhunambiGlassTabItem(label: 'Audio', icon: AppIcons.songs),
                    VhunambiGlassTabItem(label: 'Video', icon: AppIcons.reels),
                    VhunambiGlassTabItem(label: 'Images', icon: AppIcons.sparkle),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: FilledButton.icon(
                  key: const Key('library_uploads_add_btn'),
                  onPressed: _pickAndEnqueueMedia,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: AppColors.brandContrast,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.pillBorder,
                    ),
                  ),
                  icon: const PhosphorIcon(AppIcons.upload, size: 16),
                  label: const Text('Upload'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.only(bottom: bottomInset),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, index) {
                final asset = filtered[index];
                final statusLabel = switch (asset.status) {
                  MediaUploadStatus.synced => 'Synced to Cloud',
                  MediaUploadStatus.uploading =>
                    'Uploading ${(asset.progress * 100).round()}%',
                  MediaUploadStatus.failed => 'Upload Failed',
                  MediaUploadStatus.queued => 'Queued Locally',
                };
                final statusColor = switch (asset.status) {
                  MediaUploadStatus.synced => AppColors.success,
                  MediaUploadStatus.uploading => AppColors.brandPrimary,
                  MediaUploadStatus.failed => AppColors.error,
                  MediaUploadStatus.queued => AppColors.textSecondaryOf(context),
                };

                return VhunambiGlassSurface(
                  key: Key('upload_vault_item_${asset.id}'),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Row(
                    children: [
                      VhunambiTrackArtwork(
                        trackId: asset.id,
                        title: asset.title,
                        coverUrl: asset.kind == MediaAssetKind.image
                            ? asset.bestPlayableOrRenderableSource
                            : asset.thumbnailLocalPath,
                        width: 52,
                        height: 52,
                        borderRadius: 10,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              asset.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleSmall.copyWith(
                                color: AppColors.textPrimaryOf(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${asset.kind.name.toUpperCase()} • $statusLabel',
                              style: AppTypography.caption.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (asset.kind == MediaAssetKind.audio)
                        IconButton(
                          key: Key('upload_vault_play_${asset.id}'),
                          tooltip: 'Play Audio',
                          onPressed: () {
                            final src = asset.bestPlayableOrRenderableSource;
                            if (src == null) return;
                            ref.read(playerStateProvider.notifier).playTrack(
                                  Track(
                                    id: asset.id,
                                    title: asset.title,
                                    artist: 'My Uploads',
                                    genre: 'Uploaded',
                                    durationSeconds:
                                        ((asset.durationMs ?? 30000) / 1000)
                                            .round(),
                                    audioUrl: src,
                                  ),
                                );
                          },
                          icon: const PhosphorIcon(
                            AppIcons.play,
                            size: 18,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                      if (asset.status == MediaUploadStatus.failed)
                        IconButton(
                          key: Key('upload_vault_retry_${asset.id}'),
                          tooltip: 'Retry Upload',
                          onPressed: () => ref
                              .read(mediaUploadQueueProvider.notifier)
                              .retryUpload(asset.id),
                          icon: const PhosphorIcon(
                            AppIcons.remix,
                            size: 18,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                      IconButton(
                        key: Key('upload_vault_reel_${asset.id}'),
                        tooltip: 'Use in Reel',
                        onPressed: () => KineticReelStudioView.show(context),
                        icon: PhosphorIcon(
                          AppIcons.reels,
                          size: 18,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                      IconButton(
                        key: Key('upload_vault_post_${asset.id}'),
                        tooltip: 'Use in Post',
                        onPressed: () => CreateKineticPostSheet.show(context),
                        icon: PhosphorIcon(
                          AppIcons.share,
                          size: 18,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                      IconButton(
                        key: Key('upload_vault_delete_${asset.id}'),
                        tooltip: 'Delete Upload',
                        onPressed: () => ref
                            .read(mediaUploadQueueProvider.notifier)
                            .deleteUpload(asset.id),
                        icon: const PhosphorIcon(
                          AppIcons.trash,
                          size: 18,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

---

### 3.3 `ReelAudioPickerSheet` v2, Dark-Mode `_PostKineticReelCard` & Reels Studio Layout Repairs (`UPL-03` – `UPL-06`)

1. **`reel_audio_picker_sheet.dart` (`UPL-05`):**
   - Replace `TabBar` with scrollable `VhunambiGlassTabBar` synced with `TabController(length: 5, vsync: this)`: `My Vault`, `My Uploads`, `Trending`, `Saved`, `Vibes`.
   - Populate `My Uploads` from `mediaUploadQueueProvider` (`u.kind == MediaAssetKind.audio`) and render `VhunambiTrackArtwork` on every audio row across all 5 tabs.
   - Scrub legacy `'AI Studio'` / `'@aistudio'` inside `ReelStudioAudioSelection.fromLibraryTrack` to the active creator handle.

2. **`trending_reels_shelf.dart` (`UPL-04`):**
   - Replace static `AppColors.surfaceElevated` / `AppColors.surfaceCanvas` on `_PostKineticReelCard` with `VhunambiGlassSurface(variant: VhunambiGlassVariant.card, enableLiveBlur: false, tintAccent: AppColors.brandPrimary, borderRadius: BorderRadius.circular(20), child: ...)` and convert all remaining `AppColors.*` references in `trending_reels_shelf.dart` to `*Of(context)`.

3. **Bounded Tool Rail, Compact `<= 34%` Stage 2 Glass Drawer & Draggable Sticker (`kinetic_reel_studio_view.dart`, `typography_preset_picker.dart`, `atmospheric_effects_deck.dart` — `UPL-03a`, `UPL-06`):**
   - Tool rail wrapper:
     ```dart
     Positioned(
       top: 76,
       bottom: 156,
       right: _railOnRight ? 12 : null,
       left: _railOnRight ? null : 12,
       child: SingleChildScrollView(
         key: const Key('reel_studio_tool_rail_scroll'),
         physics: const BouncingScrollPhysics(),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: railButtons,
         ),
       ),
     )
     ```
   - Stage 2 bottom drawer wrapper (`<= 34%` height, zero lyric occlusion):
     ```dart
     ConstrainedBox(
       key: const Key('reel_studio_stage2_bottom_drawer'),
       constraints: BoxConstraints(
         maxHeight: MediaQuery.sizeOf(context).height * 0.34,
       ),
       child: VhunambiGlassSurface(
         margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
         padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
         borderRadius: BorderRadius.circular(22),
         child: SingleChildScrollView(
           physics: const BouncingScrollPhysics(),
           child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               _buildEditorTabStrip(),
               const SizedBox(height: 8),
               _buildCompactActiveEditorTool(),
             ],
           ),
         ),
       ),
     )
     ```
   - Draggable Stage 2 sticker (`Offset _stickerOffset = const Offset(210, 92)`):
     ```dart
     Positioned(
       left: _stickerOffset.dx.clamp(12.0, canvasWidth - 96.0),
       top: _stickerOffset.dy.clamp(68.0, canvasHeight - 220.0),
       child: GestureDetector(
         key: Key('reel_studio_canvas_sticker_$_activeStickerId'),
         onPanUpdate: (details) {
           setState(() {
             _stickerOffset = Offset(
               (_stickerOffset.dx + details.delta.dx).clamp(
                 12.0,
                 canvasWidth - 96.0,
               ),
               (_stickerOffset.dy + details.delta.dy).clamp(
                 68.0,
                 canvasHeight - 220.0,
               ),
             );
           });
         },
         child: SovereignStickerGraphic(sticker: activeSticker),
       ),
     )
     ```

4. **Complete SafeArea Dual-Handle `ReelAudioTrimmerSheet` (`reel_audio_trimmer_sheet.dart` — `UPL-03b`):**

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/content_studio_preset.dart';

class ReelAudioTrimmerSheet extends StatefulWidget {
  final String trackTitle;
  final double totalDurationSec;
  final int initialStartMs;
  final int initialEndMs;

  const ReelAudioTrimmerSheet({
    super.key,
    required this.trackTitle,
    required this.totalDurationSec,
    required this.initialStartMs,
    required this.initialEndMs,
  });

  static Future<({int startMs, int endMs})?> show(
    BuildContext context, {
    required String trackTitle,
    required double totalDurationSec,
    required int initialStartMs,
    required int initialEndMs,
  }) {
    return showModalBottomSheet<({int startMs, int endMs})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReelAudioTrimmerSheet(
        trackTitle: trackTitle,
        totalDurationSec: totalDurationSec,
        initialStartMs: initialStartMs,
        initialEndMs: initialEndMs,
      ),
    );
  }

  @override
  State<ReelAudioTrimmerSheet> createState() => _ReelAudioTrimmerSheetState();
}

class _ReelAudioTrimmerSheetState extends State<ReelAudioTrimmerSheet> {
  static const List<DurationPreset> _windowPresets = <DurationPreset>[
    DurationPreset.hook15s,
    DurationPreset.reel30s,
    DurationPreset.reel60s,
    DurationPreset.reel90s,
  ];

  late double _startSec;
  late double _endSec;

  double get _maxTrackSec => math.max(15.0, widget.totalDurationSec);

  @override
  void initState() {
    super.initState();
    _startSec = (widget.initialStartMs / 1000.0).clamp(0.0, _maxTrackSec - 5.0);
    final rawEnd = widget.initialEndMs / 1000.0;
    _endSec = rawEnd.clamp(_startSec + 5.0, math.min(_maxTrackSec, _startSec + 90.0));
  }

  String _fmt(double seconds) {
    final s = seconds.round();
    final mins = s ~/ 60;
    final rem = (s % 60).toString().padLeft(2, '0');
    return '$mins:$rem';
  }

  @override
  Widget build(BuildContext context) {
    final clampedStart = _startSec.clamp(0.0, math.max(0.0, _maxTrackSec - 5.0));
    final clampedEnd = _endSec.clamp(
      math.min(_maxTrackSec, clampedStart + 5.0),
      _maxTrackSec,
    );
    final windowSec = clampedEnd - clampedStart;
    final maxStart = math.max(0.0, _maxTrackSec - windowSec);

    return SafeArea(
      top: false,
      child: Container(
        key: const Key('reel_audio_trimmer_sheet'),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        decoration: BoxDecoration(
          color: AppColors.surfaceModalOf(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const PhosphorIcon(
                    AppIcons.waveform,
                    size: 18,
                    color: AppColors.brandPrimary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Trim Hook • ${widget.trackTitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.textPrimaryOf(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${_fmt(clampedStart)} – ${_fmt(clampedEnd)}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.brandPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _windowPresets.map((preset) {
                  final sec = preset.targetSeconds.toDouble();
                  final active = (windowSec - sec).abs() < 0.6;
                  return ChoiceChip(
                    key: Key('reel_duration_pill_${preset.targetSeconds}'),
                    selected: active,
                    label: Text('${preset.targetSeconds}s'),
                    onSelected: (_) {
                      setState(() {
                        final boundedWin = math.min(sec, _maxTrackSec);
                        _startSec = clampedStart.clamp(
                          0.0,
                          math.max(0.0, _maxTrackSec - boundedWin),
                        );
                        _endSec = math.min(_maxTrackSec, _startSec + boundedWin);
                      });
                    },
                  );
                }).toList(growable: false),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 60,
                width: double.infinity,
                child: CustomPaint(
                  painter: _GlowingWaveformPainter(
                    startFrac: clampedStart / _maxTrackSec,
                    endFrac: clampedEnd / _maxTrackSec,
                    accentColor: AppColors.brandPrimary,
                  ),
                ),
              ),
              RangeSlider(
                key: const Key('reel_audio_trim_range_slider'),
                values: RangeValues(clampedStart, clampedEnd),
                min: 0.0,
                max: _maxTrackSec,
                activeColor: AppColors.brandPrimary,
                onChanged: (values) {
                  final span = (values.end - values.start).clamp(5.0, 90.0);
                  setState(() {
                    _startSec = values.start.clamp(
                      0.0,
                      math.max(0.0, _maxTrackSec - span),
                    );
                    _endSec = (_startSec + span).clamp(5.0, _maxTrackSec);
                  });
                },
              ),
              Slider(
                key: const Key('reel_audio_trim_slider'),
                value: clampedStart.clamp(0.0, maxStart > 0 ? maxStart : 1.0),
                min: 0.0,
                max: maxStart > 0 ? maxStart : 1.0,
                activeColor: AppColors.brandPrimary,
                onChanged: maxStart > 0
                    ? (v) => setState(() {
                        _startSec = v;
                        _endSec = math.min(_maxTrackSec, v + windowSec);
                      })
                    : null,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  key: const Key('reel_audio_trimmer_done_btn'),
                  onPressed: () {
                    Navigator.of(context).pop((
                      startMs: (clampedStart * 1000).round(),
                      endMs: (clampedEnd * 1000).round(),
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: AppColors.brandContrast,
                  ),
                  child: const Text('Use Hook Segment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowingWaveformPainter extends CustomPainter {
  final double startFrac;
  final double endFrac;
  final Color accentColor;

  const _GlowingWaveformPainter({
    required this.startFrac,
    required this.endFrac,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const barCount = 48;
    final barSpacing = size.width / barCount;
    final barWidth = math.max(2.0, barSpacing * 0.52);

    for (var i = 0; i < barCount; i++) {
      final frac = i / barCount;
      final inWindow = frac >= startFrac && frac <= endFrac;
      final amp =
          0.25 + 0.72 * ((math.sin(i * 0.72) + math.cos(i * 0.31)).abs() / 2.0);
      final h = size.height * amp;
      final x = i * barSpacing;
      final y = (size.height - h) / 2.0;

      final paint = Paint()
        ..color = inWindow ? accentColor : accentColor.withValues(alpha: 0.22)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, h),
          const Radius.circular(3),
        ),
        paint,
      );
    }

    final handlePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5;
    final startX = (startFrac * size.width).clamp(1.0, size.width - 1.0);
    final endX = (endFrac * size.width).clamp(1.0, size.width - 1.0);
    canvas.drawLine(Offset(startX, 0), Offset(startX, size.height), handlePaint);
    canvas.drawLine(Offset(endX, 0), Offset(endX, size.height), handlePaint);
  }

  @override
  bool shouldRepaint(_GlowingWaveformPainter oldDelegate) =>
      oldDelegate.startFrac != startFrac || oldDelegate.endFrac != endFrac;
}
```
