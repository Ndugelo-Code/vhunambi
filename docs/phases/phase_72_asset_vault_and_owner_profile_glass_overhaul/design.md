# Phase 72 — Asset Vault (`LibraryView`), Owner Studio Profile (`OwnerProfileView`) Glass Overhaul, `ViewerRole.owner` Parity & Library/Playlist/License Cloud SWR — Technical Design Specification

**Document ID:** `VHUNAMBI-SPEC-P72-DESIGN-V1`  
**Date:** 2026-11-20  
**Target Branch:** `fix/studio-cockpit-bugs-vh001-vh006`  
**Companion Documents:** [`blueprint.md`](./blueprint.md) | [`requirements.md`](./requirements.md) | [`tasks.md`](./tasks.md) | [`memory.md`](./memory.md)

---

## 1. Pass 1 (`M72.1`): Backend Multi-Isolate SWR & Awaited Write-Through (`apps/vhunambi_api/`)

### 1.1 `EdgeIsolateDatabaseEngine` (`apps/vhunambi_api/src/db/edge_persistence_bridge.ts`)

Add the 4 domain-scoped SWR read-through methods and awaited critical write-through methods directly alongside Phase 71's `syncNotificationsFromCloud`–`syncCreatorWalletFromCloud` helpers (lines `1255`–`1485`), using `DEFAULT_SWR_TTL_MS = 12_000`, `withTimeoutResult`, and never stamping `domainHydratedAtMs` on timeout or error:

```typescript
  private hydrateLibraryRows(rows: Array<Record<string, any>>): void {
    for (const lib of rows) {
      if (!lib.id) continue;
      const norm = normalizeLibrarySyncRow(lib);
      const normId = String(norm.id);
      const cid = canonicalizeCreatorId(
        String(norm.creatorId ?? lib.creator_id ?? 'creator_cern'),
      );
      this.libraryItems.set(normId, {
        id: normId,
        creator_id: cid,
        item_type: String(norm.itemType ?? lib.item_type ?? 'track'),
        title: String(norm.title ?? lib.title ?? 'Untitled Track'),
        data_json: JSON.stringify({ ...norm, creatorId: cid }),
        created_at: String(
          norm.createdAt ?? norm.updatedAt ?? new Date().toISOString(),
        ),
        updated_at: String(norm.updatedAt ?? new Date().toISOString()),
      });
    }
  }

  private hydratePlaylistRows(rows: Array<Record<string, any>>): void {
    for (const pl of rows) {
      if (!pl.id) continue;
      const norm = normalizePlaylistRow(pl);
      const id = String(norm.id);
      const cid = canonicalizeCreatorId(
        String(norm.creatorId ?? pl.creator_id ?? 'creator_cern'),
      );
      const rawShareCode = norm.shareCode ? String(norm.shareCode) : null;
      const effectiveShareCode =
        rawShareCode && rawShareCode.startsWith('priv_') ? null : rawShareCode;
      const createdIso = new Date(Number(pl.created_at || Date.now())).toISOString();
      const updatedIso = new Date(Number(pl.updated_at || Date.now())).toISOString();
      this.playlists.set(id, {
        id,
        creator_id: cid,
        title: String(norm.title ?? 'Untitled Playlist'),
        description: String(norm.description ?? ''),
        cover_image_url: norm.coverImageUrl ?? null,
        track_ids_json: JSON.stringify(norm.trackIds ?? []),
        is_public: norm.isPublic ? 1 : 0,
        share_code: effectiveShareCode,
        share_url: effectiveShareCode
          ? `https://vhunambi.za/p/${effectiveShareCode}`
          : null,
        created_at: createdIso,
        updated_at: updatedIso,
      });
    }
  }

  private hydrateBeatLicenseRows(rows: Array<Record<string, any>>): void {
    for (const bl of rows) {
      if (!bl.certificate_id) continue;
      const norm = normalizeBeatLicenseRow(bl);
      const amtZar = Number(bl.amount_paid_zar ?? norm.amountPaidZar ?? 0);
      const amtCoins = Number(bl.amount_paid_coins ?? norm.amountPaidCoins ?? 0);
      const buyerCid = canonicalizeCreatorId(String(bl.buyer_id ?? norm.buyerId ?? ''));
      const producerCid = canonicalizeCreatorId(
        String(bl.producer_id ?? norm.producerId ?? ''),
      );
      const enriched = {
        ...norm,
        buyerId: buyerCid,
        producerId: producerCid,
      };
      this.beatLicenses.set(String(bl.certificate_id), {
        certificate_id: String(bl.certificate_id),
        license_hash: String(bl.license_hash ?? ''),
        beat_id: String(bl.beat_id ?? ''),
        producer_id: producerCid,
        buyer_id: buyerCid,
        tier: String(bl.tier ?? 'basic_lease'),
        coins_paid: amtCoins,
        zar_paid: amtZar,
        producer_coins: Math.max(1, Math.floor(amtCoins * 0.85)),
        producer_zar: Number((amtZar * 0.85).toFixed(2)),
        issued_at: new Date(Number(bl.purchased_at || Date.now())).toISOString(),
        data_json: JSON.stringify(enriched),
      });
    }
  }

  private hydrateMarketplaceAssetRows(rows: Array<Record<string, any>>): void {
    for (const ma of rows) {
      if (!ma.id) continue;
      const norm = normalizeMarketplaceAssetRow(ma);
      const id = String(norm.id);
      const producerCid = canonicalizeCreatorId(
        String(norm.producerId ?? ma.producer_id ?? 'creator_kabza'),
      );
      this.marketplaceBeats.set(id, {
        ...norm,
        id,
        producerId: producerCid,
      });
    }
  }

  public async syncUserLibraryFromCloud(
    creatorId: string,
    cOrEnv?: unknown,
    force = false,
  ): Promise<any[]> {
    const cid = canonicalizeCreatorId(creatorId);
    const driver = this.resolveCloudDriver(cOrEnv);
    if (!driver.isConfigured()) {
      return this.getLibrary(cid);
    }

    const domainKey = `library:${cid}`;
    const lastHydrated = this.domainHydratedAtMs.get(domainKey) ?? 0;
    if (
      !force &&
      lastHydrated > 0 &&
      Date.now() - lastHydrated < EdgeIsolateDatabaseEngine.DEFAULT_SWR_TTL_MS
    ) {
      return this.getLibrary(cid);
    }

    const res = await EdgeIsolateDatabaseEngine.withTimeoutResult(
      driver.selectRows<Record<string, any>>(
        'user_library_sync',
        `select=*&creator_id=eq.${encodeURIComponent(cid)}&order=updated_at.desc&limit=500`,
      ),
      3500,
    );
    if (res.ok) {
      const remoteIds = new Set(res.value.map((r) => String(r.id ?? '')).filter(Boolean));
      for (const [existingId, existingRow] of this.libraryItems.entries()) {
        if (
          canonicalizeCreatorId(String(existingRow.creator_id)) === cid &&
          !remoteIds.has(existingId)
        ) {
          this.libraryItems.delete(existingId);
        }
      }
      this.hydrateLibraryRows(res.value);
      this.domainHydratedAtMs.set(domainKey, Date.now());
    }
    return this.getLibrary(cid);
  }

  public async syncPlaylistsFromCloud(
    creatorId?: string,
    cOrEnv?: unknown,
    force = false,
  ): Promise<boolean> {
    const cid = creatorId ? canonicalizeCreatorId(creatorId) : '';
    const driver = this.resolveCloudDriver(cOrEnv);
    if (!driver.isConfigured()) return false;

    const domainKey = `playlists:${cid || 'public'}`;
    const lastHydrated = this.domainHydratedAtMs.get(domainKey) ?? 0;
    if (
      !force &&
      lastHydrated > 0 &&
      Date.now() - lastHydrated < EdgeIsolateDatabaseEngine.DEFAULT_SWR_TTL_MS
    ) {
      return true;
    }

    const query = cid
      ? `select=*&or=(creator_id.eq.${encodeURIComponent(cid)},is_public.eq.true)&order=updated_at.desc&limit=200`
      : 'select=*&order=updated_at.desc&limit=200';
    const res = await EdgeIsolateDatabaseEngine.withTimeoutResult(
      driver.selectRows<Record<string, any>>('playlists', query),
      3500,
    );
    if (res.ok) {
      const remoteIds = new Set(res.value.map((r) => String(r.id ?? '')).filter(Boolean));
      if (cid) {
        for (const [plId, row] of this.playlists.entries()) {
          if (
            canonicalizeCreatorId(String(row.creator_id)) === cid &&
            !remoteIds.has(plId)
          ) {
            this.playlists.delete(plId);
          }
        }
      }
      this.hydratePlaylistRows(res.value);
      this.domainHydratedAtMs.set(domainKey, Date.now());
      return true;
    }
    return false;
  }

  public async syncBuyerLicensesFromCloud(
    buyerId: string,
    cOrEnv?: unknown,
    force = false,
  ): Promise<any[]> {
    const cid = canonicalizeCreatorId(buyerId);
    const driver = this.resolveCloudDriver(cOrEnv);
    if (!driver.isConfigured()) {
      return this.getBeatLicensesByBuyer(cid);
    }

    const domainKey = `licenses:${cid}`;
    const lastHydrated = this.domainHydratedAtMs.get(domainKey) ?? 0;
    if (
      !force &&
      lastHydrated > 0 &&
      Date.now() - lastHydrated < EdgeIsolateDatabaseEngine.DEFAULT_SWR_TTL_MS
    ) {
      return this.getBeatLicensesByBuyer(cid);
    }

    const res = await EdgeIsolateDatabaseEngine.withTimeoutResult(
      driver.selectRows<Record<string, any>>(
        'beat_licenses',
        `select=*&buyer_id=eq.${encodeURIComponent(cid)}&order=purchased_at.desc&limit=300`,
      ),
      3500,
    );
    if (res.ok) {
      this.hydrateBeatLicenseRows(res.value);
      this.domainHydratedAtMs.set(domainKey, Date.now());
    }
    return this.getBeatLicensesByBuyer(cid);
  }

  public async syncMarketplaceFromCloud(
    force = false,
    cOrEnv?: unknown,
  ): Promise<boolean> {
    const driver = this.resolveCloudDriver(cOrEnv);
    if (!driver.isConfigured()) return false;

    const domainKey = 'marketplace:global';
    const lastHydrated = this.domainHydratedAtMs.get(domainKey) ?? 0;
    if (
      !force &&
      lastHydrated > 0 &&
      Date.now() - lastHydrated < EdgeIsolateDatabaseEngine.DEFAULT_SWR_TTL_MS
    ) {
      return true;
    }

    const [assetsRes, licensesRes] = await Promise.all([
      EdgeIsolateDatabaseEngine.withTimeoutResult(
        driver.selectRows<Record<string, any>>(
          'marketplace_assets',
          'select=*&order=updated_at.desc&limit=200',
        ),
        3500,
      ),
      EdgeIsolateDatabaseEngine.withTimeoutResult(
        driver.selectRows<Record<string, any>>(
          'beat_licenses',
          'select=*&order=purchased_at.desc&limit=300',
        ),
        3500,
      ),
    ]);

    if (assetsRes.ok) this.hydrateMarketplaceAssetRows(assetsRes.value);
    if (licensesRes.ok) this.hydrateBeatLicenseRows(licensesRes.value);

    const ok = assetsRes.ok && licensesRes.ok;
    if (ok) {
      this.domainHydratedAtMs.set(domainKey, Date.now());
    }
    return ok;
  }

  public async syncLibraryDeltaAsync(
    creatorId: string,
    incomingItems: any[],
    cOrEnv?: unknown,
  ): Promise<ReturnType<EdgeIsolateDatabaseEngine['syncLibraryDelta']>> {
    const cid = canonicalizeCreatorId(creatorId);
    await this.syncUserLibraryFromCloud(cid, cOrEnv);
    const result = this.syncLibraryDelta(cid, incomingItems, true);
    const driver = this.resolveCloudDriver(cOrEnv);
    if (driver.isConfigured()) {
      for (const item of result.items) {
        const updatedAtMs = Number(item.updatedAtMs ?? Date.now());
        try {
          await driver.upsertRow(
            'user_library_sync',
            {
              id: String(item.id),
              creator_id: cid,
              item_type: String(item.itemType ?? 'track'),
              title: String(item.title ?? 'Untitled Track'),
              artist: String(item.creatorName ?? item.artistName ?? item.artist ?? 'Vhunambi Creator'),
              genre: String(item.genre ?? 'Amapiano'),
              bpm: Math.round(Number(item.bpm ?? 113)),
              duration_sec: Math.round(Number(item.durationSeconds ?? item.durationSec ?? 180)),
              audio_url: String(item.remoteAudioUrl ?? item.audioUrl ?? ''),
              cover_url: String(item.coverImageUrl ?? item.coverUrl ?? ''),
              is_favorite: Boolean(item.isFavorite ?? false),
              is_downloaded: Boolean(item.isDownloaded ?? false),
              play_count: Number(item.playCount ?? 0),
              is_licensed_beat: Boolean(item.isLicensedBeat ?? false),
              license_tier: item.licenseTierId ?? item.licenseTier ?? null,
              certificate_id: item.licenseCertificateIdOverride ?? item.certificateId ?? null,
              license_hash: item.licenseHash ?? null,
              master_file_sha256: item.masterFileSha256 ?? null,
              stems_json: item.stemPaths ?? item.stemFilesJson ?? {},
              data_json: item,
              created_at: Date.parse(String(item.createdAt ?? '')) || updatedAtMs,
              updated_at: updatedAtMs,
            },
            'id,creator_id',
          );
        } catch (err) {
          this.recordWriteThroughFailure('user_library_sync.upsert_async', err);
        }
      }
      this.domainHydratedAtMs.set(`library:${cid}`, Date.now());
    }
    return result;
  }

  public async deleteLibraryItemAsync(
    id: string,
    creatorId?: string,
    cOrEnv?: unknown,
  ): Promise<boolean> {
    const cid = creatorId ? canonicalizeCreatorId(creatorId) : undefined;
    if (cid) {
      await this.syncUserLibraryFromCloud(cid, cOrEnv);
    }
    const deleted = this.deleteLibraryItem(id, cid, true);
    if (!deleted) return false;
    const driver = this.resolveCloudDriver(cOrEnv);
    if (driver.isConfigured()) {
      try {
        const filter = cid ? `&creator_id=eq.${encodeURIComponent(cid)}` : '';
        await driver.deleteRows(
          'user_library_sync',
          `id=eq.${encodeURIComponent(id)}${filter}`,
        );
      } catch (err) {
        this.recordWriteThroughFailure('user_library_sync.delete_async', err);
      }
    }
    return true;
  }

  public async upsertPlaylistAsync(
    input: Record<string, any>,
    cOrEnv?: unknown,
  ): Promise<Record<string, any>> {
    const normalizedInput = {
      ...input,
      creatorId: canonicalizeCreatorId(
        String(input.creatorId ?? input.creator_id ?? 'creator_cern'),
      ),
    };
    const mapped = this.upsertPlaylist(normalizedInput, true);
    const driver = this.resolveCloudDriver(cOrEnv);
    if (driver.isConfigured()) {
      try {
        await driver.upsertRow(
          'playlists',
          {
            id: String(mapped.id),
            creator_id: canonicalizeCreatorId(String(mapped.creatorId)),
            title: String(mapped.title),
            description: String(mapped.description ?? ''),
            cover_url: String(mapped.coverImageUrl ?? ''),
            track_ids_json: mapped.trackIds ?? [],
            is_public: Boolean(mapped.isPublic),
            share_code: mapped.shareCode
              ? String(mapped.shareCode)
              : `priv_${String(mapped.id)}`,
            data_json: mapped,
            created_at: Date.parse(String(mapped.createdAt)) || Date.now(),
            updated_at: Date.parse(String(mapped.updatedAt)) || Date.now(),
          },
          'id',
        );
        this.domainHydratedAtMs.set(
          `playlists:${canonicalizeCreatorId(String(mapped.creatorId))}`,
          Date.now(),
        );
      } catch (err) {
        this.recordWriteThroughFailure('playlists.upsert_async', err);
      }
    }
    return mapped;
  }

  public async deletePlaylistAsync(
    id: string,
    creatorId?: string,
    cOrEnv?: unknown,
  ): Promise<boolean> {
    const cid = creatorId ? canonicalizeCreatorId(creatorId) : undefined;
    await this.syncPlaylistsFromCloud(cid, cOrEnv);
    const deleted = this.deletePlaylist(id, cid, true);
    if (!deleted) return false;
    const driver = this.resolveCloudDriver(cOrEnv);
    if (driver.isConfigured()) {
      try {
        await driver.deleteRows('playlists', `id=eq.${encodeURIComponent(id)}`);
      } catch (err) {
        this.recordWriteThroughFailure('playlists.delete_async', err);
      }
    }
    return true;
  }

  public async sharePlaylistAsync(
    id: string,
    cOrEnv?: unknown,
  ): Promise<Record<string, any> | null> {
    await this.syncPlaylistsFromCloud(undefined, cOrEnv);
    const shared = this.sharePlaylist(id);
    if (!shared) return null;
    const driver = this.resolveCloudDriver(cOrEnv);
    if (driver.isConfigured()) {
      try {
        await driver.patchRows(
          'playlists',
          `id=eq.${encodeURIComponent(id)}`,
          {
            is_public: true,
            share_code: String(shared.shareCode),
            data_json: shared,
            updated_at: Date.now(),
          },
        );
      } catch (err) {
        this.recordWriteThroughFailure('playlists.share_async', err);
      }
    }
    return shared;
  }
```

And canonicalize comparisons in `getLibrary`, `getPlaylists`, `deleteLibraryItem`, `deletePlaylist`, and `getBeatLicensesByBuyer`:

```typescript
  public getLibrary(creatorId: string): any[] {
    const cid = canonicalizeCreatorId(creatorId);
    const rows = Array.from(this.libraryItems.values())
      .filter((r) => canonicalizeCreatorId(String(r.creator_id)) === cid)
      .sort((a, b) => String(b.updated_at).localeCompare(String(a.updated_at)));
    return rows.map((r) => {
      let data: Record<string, any> = {};
      try {
        data = JSON.parse(String(r.data_json || '{}'));
      } catch {
        data = {};
      }
      return {
        id: r.id,
        creatorId: canonicalizeCreatorId(String(r.creator_id)),
        itemType: r.item_type,
        title: r.title,
        createdAt: data.createdAt || r.created_at,
        updatedAt: data.updatedAt || r.updated_at,
        updated_at: r.updated_at,
        ...data,
      };
    });
  }

  public getPlaylists(creatorId?: string, includePublic: boolean = true): any[] {
    const cid = creatorId && creatorId.trim() !== ''
      ? canonicalizeCreatorId(creatorId)
      : '';
    let rows = Array.from(this.playlists.values());
    if (cid) {
      rows = includePublic
        ? rows.filter(
            (r) =>
              canonicalizeCreatorId(String(r.creator_id)) === cid ||
              Number(r.is_public ?? 0) === 1,
          )
        : rows.filter((r) => canonicalizeCreatorId(String(r.creator_id)) === cid);
    }
    rows.sort((a, b) => String(b.updated_at).localeCompare(String(a.updated_at)));
    return rows.map((r) => this.mapPlaylistRow(r));
  }

  public getBeatLicensesByBuyer(buyerId: string): any[] {
    const cid = canonicalizeCreatorId(buyerId);
    return Array.from(this.beatLicenses.values())
      .filter((r) => canonicalizeCreatorId(String(r.buyer_id)) === cid)
      .sort((a, b) => String(b.issued_at).localeCompare(String(a.issued_at)))
      .map((r) => JSON.parse(String(r.data_json || '{}')));
  }
```

### 1.2 `VhunambiDatabase` Local SQLite Proxy Parity (`apps/vhunambi_api/src/db/vhunambi_db.ts`)

Add 1:1 signature-matched proxy methods on `VhunambiDatabase` right after `upsertNotificationAsync`:

```typescript
  public async syncUserLibraryFromCloud(
    creatorId: string,
    _cOrEnv?: unknown,
    _force = false,
  ): Promise<any[]> {
    return this.getLibrary(creatorId);
  }

  public async syncPlaylistsFromCloud(
    _creatorId?: string,
    _cOrEnv?: unknown,
    _force = false,
  ): Promise<boolean> {
    return false;
  }

  public async syncBuyerLicensesFromCloud(
    buyerId: string,
    _cOrEnv?: unknown,
    _force = false,
  ): Promise<any[]> {
    return this.getBeatLicensesByBuyer(buyerId);
  }

  public async syncMarketplaceFromCloud(
    _force = false,
    _cOrEnv?: unknown,
  ): Promise<boolean> {
    return false;
  }

  public async syncLibraryDeltaAsync(
    creatorId: string,
    incomingItems: any[],
    _cOrEnv?: unknown,
  ): Promise<ReturnType<VhunambiDatabase['syncLibraryDelta']>> {
    return this.syncLibraryDelta(creatorId, incomingItems, true);
  }

  public async deleteLibraryItemAsync(
    id: string,
    creatorId?: string,
    _cOrEnv?: unknown,
  ): Promise<boolean> {
    return this.deleteLibraryItem(id, creatorId, true);
  }

  public async upsertPlaylistAsync(
    input: Record<string, any>,
    _cOrEnv?: unknown,
  ): Promise<Record<string, any>> {
    return this.upsertPlaylist(input, true);
  }

  public async deletePlaylistAsync(
    id: string,
    creatorId?: string,
    _cOrEnv?: unknown,
  ): Promise<boolean> {
    return this.deletePlaylist(id, creatorId, true);
  }

  public async sharePlaylistAsync(
    id: string,
    _cOrEnv?: unknown,
  ): Promise<Record<string, any> | null> {
    return this.sharePlaylist(id);
  }
```

### 1.3 Scoped Route Bypass & Async Route Handlers (`server.ts`, `library_routes.ts`, `playlist_routes.ts`, `marketplace_routes.ts`)

In `apps/vhunambi_api/src/server.ts#L53-L63`, extend `hasScopedReadThrough`:

```typescript
    const hasScopedReadThrough =
      p.startsWith('/api/notifications') ||
      p.startsWith('/api/v1/notifications') ||
      p.startsWith('/api/wallet') ||
      p.startsWith('/api/v1/wallet') ||
      p.startsWith('/api/explore') ||
      p.startsWith('/api/v1/explore') ||
      p.startsWith('/api/library') ||
      p.startsWith('/api/v1/library') ||
      p.startsWith('/api/playlists') ||
      p.startsWith('/api/v1/playlists') ||
      p.startsWith('/api/marketplace') ||
      p.startsWith('/api/v1/marketplace') ||
      p.startsWith('/v1/generations') ||
      p.startsWith('/v1/vision') ||
      p.startsWith('/v1/webhooks');
```

In `apps/vhunambi_api/src/routes/library_routes.ts`:

```typescript
libraryRoutes.get('/', async (c) => {
  const requestedId = c.req.query('creatorId');
  const forbidden = assertTenantCreatorAccess(c, requestedId);
  if (forbidden) return forbidden;
  const creatorId = resolveEffectiveCreatorId(c, requestedId, 'creator_cern');
  const items = await vhunambiDb.syncUserLibraryFromCloud(creatorId, c);
  return c.json({
    creatorId,
    items,
    count: items.length,
    serverSeq: vhunambiDb.getLatestSeq(),
    syncedAt: new Date().toISOString(),
  });
});

libraryRoutes.get('/sync', async (c) => {
  const requestedId = c.req.query('creatorId');
  const forbidden = assertTenantCreatorAccess(c, requestedId);
  if (forbidden) return forbidden;
  const creatorId = resolveEffectiveCreatorId(c, requestedId, 'creator_cern');
  const items = await vhunambiDb.syncUserLibraryFromCloud(creatorId, c);
  return c.json({
    creatorId,
    items,
    count: items.length,
    serverSeq: vhunambiDb.getLatestSeq(),
    syncedAt: new Date().toISOString(),
  });
});

libraryRoutes.post('/sync', async (c) => {
  const body = await c.req.json();
  const forbidden = assertTenantCreatorAccess(c, body.creatorId);
  if (forbidden) return forbidden;
  const creatorId = resolveEffectiveCreatorId(c, body.creatorId, 'creator_cern');
  const items = Array.isArray(body.items) ? body.items : [];
  const result = await vhunambiDb.syncLibraryDeltaAsync(creatorId, items, c);
  return c.json({
    success: true,
    creatorId,
    upserted: result.appliedCount + result.skippedCount,
    appliedCount: result.appliedCount,
    skippedCount: result.skippedCount,
    items: result.items,
    serverSeq: result.serverSeq,
    syncedAt: result.syncedAt,
    status: 'synced',
  });
});

libraryRoutes.delete('/:id', async (c) => {
  const id = c.req.param('id');
  const requestedCreatorId = c.req.query('creatorId');
  const forbiddenQuery = assertTenantCreatorAccess(c, requestedCreatorId);
  if (forbiddenQuery) return forbiddenQuery;

  const authUser = c.get('authUser');
  const effectiveCreatorId = authUser ? authUser.creatorId : requestedCreatorId;
  if (effectiveCreatorId) {
    await vhunambiDb.syncUserLibraryFromCloud(effectiveCreatorId, c);
  }
  if (authUser) {
    const ownerId = vhunambiDb.getLibraryItemOwnerCreatorId(id);
    if (ownerId && ownerId !== authUser.creatorId && authUser.role !== 'admin') {
      return c.json(
        {
          error: `Forbidden: Library item '${id}' belongs to '${ownerId}', not '${authUser.creatorId}'.`,
          code: 'TENANT_FORBIDDEN',
        },
        403,
      );
    }
  }
  const deleted = await vhunambiDb.deleteLibraryItemAsync(id, effectiveCreatorId, c);
  if (!deleted) {
    return c.json({ success: false, error: 'Library item not found', id }, 404);
  }
  return c.json({ success: true, id, serverSeq: vhunambiDb.getLatestSeq() });
});
```

In `apps/vhunambi_api/src/routes/playlist_routes.ts` (convert `GET /`, `GET /:id`, `POST /`, `PUT /:id`, `DELETE /:id`, `POST /:id/share` to `async`, awaiting `vhunambiDb.syncPlaylistsFromCloud(creatorId, c)` before reads/ownership checks and awaiting `upsertPlaylistAsync` / `deletePlaylistAsync` / `sharePlaylistAsync` on mutations).

In `apps/vhunambi_api/src/routes/marketplace_routes.ts` (convert `GET /beats`, `GET /beats/:id`, `GET /producers/:producerId/beats`, `GET /licenses/verify/:certificateId`, `GET /licenses/:buyerId` to `async`):

```typescript
marketplaceRoutes.get('/beats', async (c) => {
  await vhunambiDb.syncMarketplaceFromCloud(false, c);
  const query: MarketplaceFilterQuery = {
    genre: c.req.query('genre'),
    search: c.req.query('search'),
    minBpm: c.req.query('minBpm') ? Number(c.req.query('minBpm')) : undefined,
    maxBpm: c.req.query('maxBpm') ? Number(c.req.query('maxBpm')) : undefined,
    maxPrice: c.req.query('maxPrice') ? Number(c.req.query('maxPrice')) : undefined,
    cursor: c.req.query('cursor'),
    limit: c.req.query('limit') ? Number(c.req.query('limit')) : undefined,
  };
  return c.json(getMarketplaceBeats(query));
});

marketplaceRoutes.get('/beats/:id', async (c) => {
  await vhunambiDb.syncMarketplaceFromCloud(false, c);
  const beat = getBeatById(c.req.param('id'));
  if (!beat) return c.json({ error: 'Beat not found' }, 404);
  return c.json(beat);
});

marketplaceRoutes.get('/licenses/verify/:certificateId', async (c) => {
  await vhunambiDb.syncMarketplaceFromCloud(false, c);
  const verification = vhunambiDb.verifyBeatLicense(c.req.param('certificateId'));
  if (!verification.found) {
    return c.json({ found: false, valid: false, error: 'Certificate not found' }, 404);
  }
  return c.json(verification);
});

marketplaceRoutes.get('/licenses/:buyerId', async (c) => {
  const buyerId = c.req.param('buyerId');
  const forbidden = assertTenantCreatorAccess(c, buyerId);
  if (forbidden) return forbidden;
  await vhunambiDb.syncBuyerLicensesFromCloud(buyerId, c);
  const certificates = getLicensesByBuyer(buyerId);
  return c.json({ buyerId, certificates });
});

marketplaceRoutes.get('/producers/:producerId/beats', async (c) => {
  await vhunambiDb.syncMarketplaceFromCloud(false, c);
  const producerId = c.req.param('producerId');
  const beats = getProducerBeats(producerId);
  return c.json({ producerId, beats });
});
```

---

## 2. Pass 1 (`M72.2`): Client Asset Vault Glass Overhaul, `ViewerRole.owner` & Buyer Licenses (`apps/vhunambi_client/`)

### 2.1 Enriched `LibraryTrack` Model & `TrackDetailNotifier` Direct Hydration

In `apps/vhunambi_client/lib/features/library/domain/models/library_models.dart`, add 8 backward-compatible optional fields (`creatorId`, `creatorHandle`, `mood`, `moodId`, `bpm`, `description`, `allowOpenStemsRemix`, `isPublic`):

```dart
  /// Canonical creator ID (`creator_cern`, etc.) guaranteeing `ViewerRole.owner` parity.
  final String? creatorId;
  final String? creatorHandle;
  final String? mood;
  final String? moodId;
  final int? bpm;
  final String? description;
  final bool allowOpenStemsRemix;
  final bool isPublic;
```

In `LibraryTrack.toJson()` / `LibraryTrack.fromJson()` / `copyWith()` / `toTrack()`:

```dart
  /// Bridges a vault asset into the global persistent player queue model.
  Track toTrack() {
    return Track(
      id: id,
      title: title,
      creatorName: creatorName,
      creatorHandle: creatorHandle,
      genre: genre,
      language: language,
      duration: duration,
      audioUrl: masterAudioFilePath ?? localAudioFilePath ?? remoteAudioUrl,
      coverUrl: coverImageUrl,
      playCount: playCount,
      mood: mood ?? moodId,
    );
  }
```

In `LibraryTracksNotifier` (`apps/vhunambi_client/lib/features/library/presentation/providers/library_providers.dart`), add `toggleTrackVisibility(String id)`:

```dart
  /// Persists Public/Private catalog visibility for an owned vault track.
  void toggleTrackVisibility(String id) {
    _localMutatedIds.add(id);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    LibraryTrack? updated;
    state = [
      for (final track in state)
        if (track.id == id)
          updated = track.copyWith(
            isPublic: !track.isPublic,
            updatedAtMs: nowMs,
          )
        else
          track,
    ];
    if (updated != null) {
      _persistAndQueue(updated, action: 'update');
    }
  }
```

Seed `lib_track_001` (`'Grateful in the Light'`) and `lib_track_002` (`'Ndo Mufuna Matibe'`) with explicit ownership & mood metadata (`creatorId: 'creator_cern'`, `creatorHandle: '@cern'`, `mood: 'Uplifting'`, `moodId: 'uplifting'`, `bpm: 113` on `lib_track_001`; `creatorId: 'creator_cern'`, `creatorHandle: '@cern'`, `mood: 'Soulful'`, `moodId: 'soulful'`, `bpm: 112` on `lib_track_002` so owned starter tracks in the creator's vault always belong to `'creator_cern'` when opened in `OwnerProfileView` and `LibraryView`!).

In `apps/vhunambi_client/lib/features/track/presentation/providers/track_providers.dart` (`_lookupInitialTrack`, lines `285`–`318`):

```dart
      final libraryTracks = ref.read(libraryTracksProvider);
      for (final lt in libraryTracks) {
        if (lt.id == trackId) {
          final handleSlug = lt.creatorName.toLowerCase().replaceAll(
            RegExp(r'[^a-z0-9]+'),
            '_',
          );
          final resolvedCreatorId = (lt.creatorId != null && lt.creatorId!.trim().isNotEmpty)
              ? canonicalizeCreatorId(lt.creatorId!)
              : canonicalizeCreatorId(
                  lt.creatorName,
                  fallback: 'creator_$handleSlug',
                );
          final resolvedHandle =
              (lt.creatorHandle != null && lt.creatorHandle!.trim().isNotEmpty)
              ? lt.creatorHandle!.trim()
              : handleFromCreatorId(resolvedCreatorId);
          final canonicalMood = VhunambiMood.normalize(lt.moodId ?? lt.mood);
          return TrackDetailEntity(
            id: lt.id,
            title: lt.title,
            genre: lt.genre,
            language: lt.language,
            duration: Duration(
              seconds: lt.durationSeconds > 0 ? lt.durationSeconds : 180,
            ),
            creatorId: resolvedCreatorId,
            creatorName: lt.creatorName,
            creatorHandle: resolvedHandle,
            playCount: lt.playCount,
            coverUrl: lt.coverImageUrl,
            createdAt: lt.createdAt,
            bpm: (lt.bpm != null && lt.bpm! > 0)
                ? lt.bpm!
                : _defaultBpmForGenre(lt.genre),
            mood: canonicalMood.label,
            moodId: canonicalMood.moodId,
            description: lt.description ?? '',
            allowOpenStemsRemix: lt.allowOpenStemsRemix,
            lyrics: lt.lyrics,
            audioUrl: lt.effectiveAudioPath ?? lt.remoteAudioUrl,
            stemsAvailable: lt.hasUnpackedStems,
            isPublic: lt.isPublic,
          );
        }
      }
```

### 2.2 Unified Artwork Renderers (`library_cover_art.dart`, `playlist_cover_art.dart`, `collection_artwork_placeholder.dart`)

Replace `apps/vhunambi_client/lib/features/library/presentation/widgets/library_cover_art.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_track_artwork.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';

/// Unified vault track cover backed by [VhunambiTrackArtwork] (`EP-P68-TRACK-ARTWORK`),
/// cleanly resolving `asset:` URIs, remote R2 URLs, and bundled cultural genre covers.
class LibraryCoverArt extends StatelessWidget {
  final LibraryTrack track;
  final double? size;
  final double radius;
  final bool showGlyph;

  const LibraryCoverArt({
    super.key,
    required this.track,
    this.size = 48,
    this.radius = AppRadius.thumb,
    this.showGlyph = false,
  });

  @override
  Widget build(BuildContext context) {
    final artwork = VhunambiTrackArtwork(
      coverUrl: track.coverImageUrl,
      genre: track.genre,
      trackId: track.id,
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(radius),
      badgeIconSize: (size ?? 64) * 0.36,
      showSubtleBorder: radius > 0,
    );
    if (size == null) return artwork;
    return SizedBox(width: size, height: size, child: artwork);
  }
}
```

Replace `PlaylistCoverArt` (`apps/vhunambi_client/lib/features/playlists/presentation/widgets/playlist_cover_art.dart`):

```dart
import 'package:flutter/material.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_track_artwork.dart';
import 'package:vhunambi_client/features/playlists/domain/models/playlist_entity.dart';
import 'package:vhunambi_client/shared/models/track.dart';

/// Dynamic playlist cover art backed by [VhunambiTrackArtwork] (`EP-P68-TRACK-ARTWORK`).
class PlaylistCoverArt extends StatelessWidget {
  final PlaylistEntity playlist;
  final List<Track> tracks;
  final double size;

  const PlaylistCoverArt({
    super.key,
    required this.playlist,
    required this.tracks,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.thumb),
      child: SizedBox(width: size, height: size, child: _content()),
    );
  }

  Widget _content() {
    final coverUrl = playlist.coverImageUrl;
    if (coverUrl != null && coverUrl.isNotEmpty) {
      return VhunambiTrackArtwork(
        coverUrl: coverUrl,
        genre: tracks.isNotEmpty ? tracks.first.genre : 'Amapiano',
        trackId: playlist.id,
        width: size,
        height: size,
        borderRadius: BorderRadius.zero,
        showSubtleBorder: false,
      );
    }

    if (tracks.length >= 4) {
      final quad = tracks.take(4).toList(growable: false);
      return Column(
        children: [
          for (var row = 0; row < 2; row++)
            Expanded(
              child: Row(
                children: [
                  for (var col = 0; col < 2; col++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(0.5),
                        child: VhunambiTrackArtwork(
                          coverUrl: quad[row * 2 + col].coverUrl,
                          genre: quad[row * 2 + col].genre,
                          trackId: quad[row * 2 + col].id,
                          borderRadius: BorderRadius.zero,
                          showSubtleBorder: false,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      );
    }

    if (tracks.isNotEmpty) {
      final first = tracks.first;
      return VhunambiTrackArtwork(
        coverUrl: first.coverUrl,
        genre: first.genre,
        trackId: first.id,
        width: size,
        height: size,
        borderRadius: BorderRadius.zero,
        showSubtleBorder: false,
      );
    }

    return VhunambiTrackArtwork(
      genre: 'Amapiano',
      trackId: playlist.id,
      width: size,
      height: size,
      borderRadius: BorderRadius.zero,
      showSubtleBorder: false,
    );
  }
}
```

And update `CollectionArtworkPlaceholder` (`collection_artwork_placeholder.dart`) to accept optional `String genre = 'Amapiano'` & `String? seedId` and render `VhunambiTrackArtwork` with `PhosphorIconsRegular.disc` corner badge (zero stock `Icons.album_outlined`).

### 2.3 Live `LibraryAppBar` Allowance Pill & `LibraryView` Glass + Cloud Sync

In `apps/vhunambi_client/lib/features/library/presentation/widgets/library_app_bar.dart`:
- Remove dead `static const String creditBalanceLabel = '10 songs left';`.
- Replace `_CreditBalancePill` with a `ConsumerWidget` watching `creatorAllowanceProvider`:

```dart
class _AllowanceBalancePill extends ConsumerWidget {
  const _AllowanceBalancePill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowance = ref.watch(creatorAllowanceProvider);
    final label = allowance.isPaidUnlimited
        ? 'Pro Unlimited'
        : '${allowance.freeMonthlySongsRemaining} songs left';
    final accent = allowance.isExhausted
        ? AppColors.error
        : allowance.isLowQuota
            ? AppColors.streakFire
            : AppColors.coinGold;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Center(
        child: InkWell(
          key: const Key('library_allowance_chip'),
          onTap: () => SubscriptionUpgradeModal.show(context),
          borderRadius: AppRadius.pillBorder,
          child: VhunambiGlassSurface(
            variant: VhunambiGlassVariant.pill,
            tintAccent: accent,
            borderColorOverride: accent.withValues(alpha: 0.45),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 6,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PhosphorIcon(
                  PhosphorIconsFill.musicNotes,
                  size: 14,
                  color: accent,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textPrimaryOf(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

*(Critical Test Guard: Using `PhosphorIconsFill.musicNotes` — NEVER `PhosphorIconsRegular.sparkle` — ensures `library_view_test.dart#L79` `expect(find.byIcon(PhosphorIconsRegular.sparkle), findsOneWidget)` remains 100% green, and default `10` remaining songs renders `'10 songs left'` cleanly so `library_view_test.dart#L39, #L73` stay 100% green while dynamically reflecting live quota decrements!)*

In `apps/vhunambi_client/lib/features/library/presentation/views/library_view.dart`:
- Convert `LibraryView` to `ConsumerStatefulWidget` so `initState()` schedules a non-blocking `syncWithCloud()` when `authSessionProvider.isAuthenticated` (skipped safely in headless guest/test mode).
- Wrap the `Scaffold` body in `VhunambiAmbientMeshBackdrop`.
- Wrap `_VaultList` & `_VaultGrid` in `RefreshIndicator(onRefresh: () => ref.read(libraryTracksProvider.notifier).syncWithCloud())`.
- Render `_CachedOnlyFilterPill` visibly on mobile inside a compact horizontal row or secondary filter strip (zero `Offstage`, zero `360dp` overflow), add clear icon (`Key('vault_search_clear_btn')`) and `onTapOutside: (_) => FocusScope.of(context).unfocus()` on the search `TextField`, and mount compact `Key('library_cloud_sync_badge')` watching `libraryCloudSyncStatusProvider`.
- Replace every stock `Icons.*` in `library_view.dart`, `library_badges.dart`, `library_category_rail.dart`, `library_empty_state.dart`, `library_track_tile.dart`, `library_track_grid_card.dart`, `track_actions_sheet.dart`, and `track_details_modal.dart` with `PhosphorIcon(...)`, enforce `>= 44x44dp` tap targets on every `IconButton` (replacing `34x34` & `32x32` boxes), and use `VhunambiGlassSurface(enableLiveBlur: false)` on tiles and grid cards.

In `TrackActionsSheet` (`apps/vhunambi_client/lib/features/library/presentation/widgets/track_actions_sheet.dart`):

```dart
    void handleOpenCockpit() {
      final host = hostContext ?? context;
      close();
      Navigator.of(host).push(
        MaterialPageRoute<void>(
          builder: (_) => TrackDetailView(trackId: track.id),
        ),
      );
    }
```

Mount **"Open Song Cockpit & Stems"** (`Key('track_action_open_cockpit')`, `icon: AppIcons.waveform`, `onTap: handleOpenCockpit`) replacing the dead `handleStemSeparation` `SnackBar`, remove the `'💰'` emoji from `'List in Beatstore'` and its snackbar, and replace `'https://r2.vhunambi.com/visuals/default_9_16.png'` with `AppAssets.resolveGenreCoverAsset(track.genre, seedId: track.id)`.

### 2.4 Buyer Licenses HTTP Sync (`EP-P72-BUYER-LICENSES-HTTP`)

In `apps/vhunambi_client/lib/features/marketplace/domain/repositories/i_marketplace_repository.dart`:

```dart
  /// Fetches all commercial beat licenses purchased by [buyerId] via
  /// `GET /api/marketplace/licenses/:buyerId` (`EP-P72-BUYER-LICENSES-HTTP`).
  Future<List<SovereignLicenseCertificate>> getBuyerLicenses(String buyerId);
```

In `apps/vhunambi_client/lib/features/marketplace/data/repositories/http_marketplace_repository.dart`:

```dart
  @override
  Future<List<SovereignLicenseCertificate>> getBuyerLicenses(
    String buyerId,
  ) async {
    final canonicalBuyer = canonicalizeCreatorId(buyerId);
    if (_shouldSkipNetwork) {
      return const <SovereignLicenseCertificate>[];
    }
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/licenses/${Uri.encodeComponent(canonicalBuyer)}',
      );
      if (res.statusCode == 200 && res.data != null) {
        final rawList = res.data!['certificates'] as List<dynamic>? ?? const <dynamic>[];
        return rawList
            .whereType<Map>()
            .map(
              (item) => SovereignLicenseCertificate.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList(growable: false);
      }
    } catch (e) {
      debugPrint('[HttpMarketplaceRepository] getBuyerLicenses fallback: $e');
    }
    return const <SovereignLicenseCertificate>[];
  }
```

In `apps/vhunambi_client/lib/features/marketplace/presentation/providers/marketplace_providers.dart`:

```dart
/// Cloud-backed commercial beat license certificates owned by [buyerId]
/// (`GET /api/marketplace/licenses/:buyerId`, `EP-P72-BUYER-LICENSES-HTTP`).
final buyerLicensesFamilyProvider =
    FutureProvider.family<List<SovereignLicenseCertificate>, String>((
      ref,
      buyerId,
    ) async {
      final repo = ref.watch(marketplaceRepositoryProvider);
      return repo.getBuyerLicenses(buyerId);
    });
```

Wire `buyerLicensesFamilyProvider(ref.watch(currentCreatorIdProvider))` into `BeatsVaultView._buildLicensedBeats` (merging remote certificates with local licensed `LibraryTrack` records by `certificateId`/`beatId`, rendering covers via `VhunambiTrackArtwork`, using `VhunambiBottomDockMetrics.scrollInset`, and purging `'🎛️'` / `'🛍️'` emojis and stock `Icons.*`).

---

## 3. Pass 2 (`M72.3`): Owner Studio Profile Glass Overhaul & Parity (`apps/vhunambi_client/lib/features/profile/`)

### 3.1 `OwnerProfileView` (`owner_profile_view.dart`) — `MiniPlayerHost` Suppression, Light-Mode Repair & Live Owner Catalog

1. **Ref-Counted Overlay Suppression (`EP-P68-MINIPLAYER-SUPPRESS`):**

```dart
  StateController<int>? _pushedOverlayCounter;
  bool _didIncrementPushedOverlay = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final counter = ref.read(pushedFullScreenOverlayCountProvider.notifier);
      _pushedOverlayCounter = counter;
      _didIncrementPushedOverlay = true;
      counter.state++;
    });
  }

  @override
  void dispose() {
    final counter = _pushedOverlayCounter;
    if (_didIncrementPushedOverlay && counter != null) {
      _didIncrementPushedOverlay = false;
      Future<void>.microtask(() {
        if (counter.mounted && counter.state > 0) {
          counter.state = (counter.state - 1).clamp(0, 99);
        }
      });
    }
    super.dispose();
  }
```

2. **Light-Mode Safe AppBar & `VhunambiAmbientMeshBackdrop`:**
   - Remove `color: Colors.white` on `VhunambiBackButton()` (`#L233`, `#L253`) and header settings `PhosphorIcon(AppIcons.settings, color: AppColors.textPrimaryOf(context), size: 20)` (`#L281`).
   - Fix `_showNewReleaseDialog` `ChoiceChip` (`#L120-L125`): `backgroundColor: AppColors.surfaceSecondaryOf(context)`, label color `isSelected ? AppColors.brandContrast : AppColors.textPrimaryOf(context)`, and remove `'💿'` from release creation SnackBar.
   - Fix `_buildVoicesAndMelodiesTab` edit button (`#L943`): `color: AppColors.textSecondaryOf(context)`.
   - Wrap body in `VhunambiAmbientMeshBackdrop` and convert hero card, segmented switcher, track rows, mastery badges, and empty cards to `VhunambiGlassSurface(enableLiveBlur: false)`.

3. **Live `"Your Songs"` Projection, Persisted Visibility & `ViewerRole.owner` Push:**

```dart
  List<LibraryTrack> _resolveOwnerSongs(
    List<LibraryTrack> libraryTracks,
    ArtistProfileEntity profile,
    String activeCreatorId,
  ) {
    final canonicalActive = canonicalizeCreatorId(activeCreatorId);
    final owned = libraryTracks.where((t) {
      if (t.isDeleted || t.isInstrumental) return false;
      if (t.creatorId != null && t.creatorId!.trim().isNotEmpty) {
        return canonicalizeCreatorId(t.creatorId!) == canonicalActive;
      }
      final nameSlug = canonicalizeCreatorId(
        t.creatorName,
        fallback: '',
      );
      return nameSlug == canonicalActive ||
          t.creatorName.toLowerCase() == profile.displayName.toLowerCase() ||
          t.creatorName.toLowerCase() == profile.username.toLowerCase();
    }).toList(growable: false);
    return owned;
  }
```

Each song row (`Key('owner_song_tile_${track.id}')`):
- Renders `VhunambiTrackArtwork(coverUrl: track.coverImageUrl, genre: track.genre, trackId: track.id, width: 44, height: 44)`.
- Tapping the row pushes `TrackDetailView(trackId: track.id)` (resolving `ViewerRole.owner`).
- Visibility pill (`Key('owner_song_visibility_${track.id}')`) displays `PhosphorIcon(track.isPublic ? PhosphorIconsRegular.globe : PhosphorIconsRegular.lock, ...)` + plain text `track.isPublic ? 'Public' : 'Private'` and calls `ref.read(libraryTracksProvider.notifier).toggleTrackVisibility(track.id)`.
- Inline Play `IconButton` enforces `constraints: const BoxConstraints(minWidth: 44, minHeight: 44)` and uses `PhosphorIcon(AppIcons.play, color: AppColors.brandPrimary, size: 22)`.
- Top Genres chips render `PhosphorIcon(AppIcons.songs, size: 13, color: AppColors.brandPrimary)` + plain text `'House (1)'`, `'Amapiano (4)'`, `'Maskandi (2)'` (zero raw emojis!).

4. **Owner Reels & Kinetic Posts Shelf (`EP-P69-KPOST-FOCUS-ROUTE`):**
   - `_OwnerReelsShelf` watches `creatorClipsFamilyProvider(ref.watch(currentCreatorIdProvider))` (replacing hardcoded `'creator_me'`).
   - Add `_OwnerKineticPostsShelf` (`Key('owner_kinetic_posts_section')`) watching `socialFeedPostsProvider` filtered to `canonicalizeCreatorId(post.creatorId) == canonicalizeCreatorId(currentCreatorId)`, rendering glass cards with `VhunambiTrackArtwork` and pushing `KineticPostFocusView(postId: post.id, initialPost: post)` on tap.

### 3.2 `PinnedSpotlightCard`, `OwnerBeatstoreCockpit` & `CreatorWalletDeck`

1. **`PinnedSpotlightCard` (`pinned_spotlight_card.dart`):**
   - Wrap card in `VhunambiGlassSurface(borderColorOverride: AppColors.brandPrimary.withValues(alpha: 0.45))` with `InkWell` pushing `TrackDetailView(trackId: pinnedTrackId!)`.
   - Replace `Image.network(coverUrl)` with `VhunambiTrackArtwork(coverUrl: coverUrl, genre: genre, trackId: pinnedTrackId, width: 52, height: 52)`.
   - Normalize fallback audio URL with `AppConstants.normalizeCloudMediaUrl(audioUrl ?? '')`.

2. **`OwnerBeatstoreCockpit` (`owner_beatstore_cockpit.dart`):**
   - Replace `creatorBeatsFamilyProvider('creator_ndugelo')` (`#L54`) with `creatorBeatsFamilyProvider(ref.watch(currentCreatorIdProvider))`.
   - Replace all 8 stock `Icons.*`, raw emoji `'🎛️'`, and both `AppGradients.forGenre` squares with `PhosphorIcon(...)`, `VhunambiTrackArtwork`, and `VhunambiGlassSurface(enableLiveBlur: false)`.

3. **`CreatorWalletDeck` (`creator_wallet_deck.dart`):**
   - Watch `creatorAllowanceProvider` (`EP-P68-CREATOR-ALLOWANCE`) and mount `Key('wallet_monthly_allowance_card')` inside `VhunambiGlassSurface`:

```dart
class _MonthlyAllowanceStrip extends ConsumerWidget {
  const _MonthlyAllowanceStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowance = ref.watch(creatorAllowanceProvider);
    final accent = allowance.isExhausted
        ? AppColors.error
        : allowance.isLowQuota
            ? AppColors.streakFire
            : AppColors.brandPrimary;
    final label = allowance.isPaidUnlimited
        ? 'Pro Unlimited Creation Plan'
        : '${allowance.freeMonthlySongsRemaining}/${allowance.freeMonthlySongsLimit} free monthly songs left';

    return VhunambiGlassSurface(
      key: const Key('wallet_monthly_allowance_card'),
      variant: VhunambiGlassVariant.card,
      tintAccent: accent,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          PhosphorIcon(PhosphorIconsFill.musicNotes, color: accent, size: 18),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimaryOf(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            key: const Key('wallet_allowance_upgrade_btn'),
            onPressed: () => SubscriptionUpgradeModal.show(context),
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 44),
              foregroundColor: AppColors.brandPrimary,
            ),
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }
}
```

   - Replace `Icons.account_balance_wallet_rounded` with `PhosphorIconsFill.wallet` and purge raw emojis (`🪙`, `🥇`, `🥈`, `🥉`, `🎖️`) with `PhosphorIconsFill.coins` & rank-tinted `PhosphorIconsFill.medal` (and align `creator_wallet_deck_test.dart#L30`).

4. **Remaining Profile Cards `STD-UIUX-001` & Theme Cleanup:**
   - Migrate `releases_manager_card.dart`, `tip_history_ledger.dart`, `profile_referral_card.dart`, `artist_voice_showcase_card.dart`, `avatar_customization_modal.dart`, `creator_avatar.dart`, `creator_dna_helix_lab_sheet.dart`, `profile_settings_drawer.dart`, `edit_profile_sheet.dart`, `pin_song_selector_sheet.dart`, `studio_analytics_console_sheet.dart`, `error_boundary.dart`, `progressive_list_loader.dart`, and `offline_indicator.dart` to `VhunambiGlassSurface` / `AppColors.*Of(context)` / `VhunambiTrackArtwork` / `PhosphorIcon(...)` with zero raw emojis and zero stock `Icons.*`.

---

## 4. Verification Test Blueprints (`M72.1` & `M72.4`)

### 4.1 Backend Cross-Isolate SWR Suite (`apps/vhunambi_api/test/phase72_vault_swr_and_licenses.test.ts`)

Uses the shared fake `SupabaseCloudDriver` pattern established in `phase71_worker_supabase_readthrough.test.ts` to prove:
1. Isolate A `syncLibraryDeltaAsync` + Isolate B `syncUserLibraryFromCloud` returns A's track across isolates, and Isolate A `deleteLibraryItemAsync` evicts it from Isolate B on SWR refresh.
2. Isolate A `upsertPlaylistAsync` & `sharePlaylistAsync` + Isolate B `syncPlaylistsFromCloud` (including legacy `'usr_me'` -> `'creator_cern'` canonicalization) returns the playlist and share URL.
3. Isolate A `recordBeatLicenseAtomic` + Isolate B `syncBuyerLicensesFromCloud('creator_cern')` returns canonicalized certificates with valid SHA-256 `verifyBeatLicense`.
4. Timeout / error on `user_library_sync`, `playlists`, or `beat_licenses` NEVER stamps `domainHydratedAtMs` and logs labeled write-through telemetry on failure.

### 4.2 Client Suite (`apps/vhunambi_client/test/features/phase72_asset_vault_and_owner_profile_test.dart`)

1. **Plain `test()` (outside `FakeAsync`):** `HttpMarketplaceRepository.getBuyerLicenses` with custom `HttpClientAdapter` sends `GET /api/marketplace/licenses/creator_cern` and parses `List<SovereignLicenseCertificate>`.
2. **Widget Tests (`testWidgets` with bounded `pump()`):**
   - `LibraryCoverArt` & `PlaylistCoverArt` mount `VhunambiTrackArtwork` cleanly for `asset:` covers without `CachedNetworkImage`.
   - Vaulted `LibraryTrack` with `creatorId: 'creator_cern'`, `moodId: 'soulful'`, `bpm: 118` opens `TrackDetailView` resolving `ViewerRole.owner` (Studio Cockpit tools unlocked).
   - `LibraryView` on `360x800` mobile renders visible `Key('vault_filter_cached_only')`, live `Key('library_allowance_chip')`, clearable search, and `VhunambiAmbientMeshBackdrop` with zero `RenderFlex` overflow.
   - `OwnerProfileView` in Light Mode & Dark Mode increments `pushedFullScreenOverlayCountProvider` to `1` while mounted and decrements back to `0` on pop; renders live owner songs from `libraryTracksProvider`; persists visibility toggle; renders `Key('wallet_monthly_allowance_card')`; scopes `OwnerBeatstoreCockpit` to `currentCreatorIdProvider`; and pushes `TrackDetailView` / `KineticPostFocusView`.
3. **Legacy Test Realignments (`M72.4`):**
   - `apps/vhunambi_client/test/features/profile/owner_profile_view_test.dart`: update emoji-prefixed finders (`'🎵 House (1)'` -> `'House (1)'`, `'🎹 Amapiano (4)'` -> `'Amapiano (4)'`, `'🌐 Public'` -> `'Public'`, `'🔒 Private'` -> `'Private'`) and live song title (`'ZaYN'` -> `'Grateful in the Light'`).
   - `apps/vhunambi_client/test/features/profile/creator_wallet_deck_test.dart`: update `'4,750 🪙'` -> `'4,750'`.
   - `apps/vhunambi_client/test/features/profile/avatar_customization_modal_test.dart`: update `'Cultural AI ✨'` -> `'Cultural AI'`.
