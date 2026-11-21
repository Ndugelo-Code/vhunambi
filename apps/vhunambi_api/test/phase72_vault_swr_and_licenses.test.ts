import assert from 'node:assert/strict';
import { EdgeIsolateDatabaseEngine } from '../src/db/edge_persistence_bridge.js';
import type { SupabaseCloudDriver } from '../src/db/supabase_cloud_driver.js';

class MockVaultCloudDriver {
  public readonly tables = new Map<string, Array<Record<string, any>>>();
  public failNextSelectTable: string | null = null;
  public failNextWriteTable: string | null = null;

  public isConfigured(): boolean {
    return true;
  }

  private tableRows(table: string): Array<Record<string, any>> {
    let rows = this.tables.get(table);
    if (!rows) {
      rows = [];
      this.tables.set(table, rows);
    }
    return rows;
  }

  private primaryKeyFor(table: string): string {
    if (table === 'beat_licenses') return 'certificate_id';
    if (table === 'creator_quotas') return 'user_id';
    return 'id';
  }

  public async selectRows<T = Record<string, unknown>>(
    table: string,
    queryString: string,
  ): Promise<T[]> {
    if (this.failNextSelectTable === table) {
      this.failNextSelectTable = null;
      throw new Error(`SIMULATED_TIMEOUT_${table}`);
    }
    const rows = [...this.tableRows(table)];
    const eqMatches = Array.from(queryString.matchAll(/([a-z0-9_]+)=eq\.([^&]+)/g));
    let filtered = rows.filter((row) =>
      eqMatches.every((m) => String(row[m[1]] ?? '') === decodeURIComponent(m[2])),
    );
    const orMatch = /or=\(([^)]+)\)/.exec(queryString);
    if (orMatch) {
      const clauses = orMatch[1].split(',');
      filtered = filtered.filter((row) =>
        clauses.some((clause) => {
          const [col, opVal] = clause.split('.eq.');
          if (!col || opVal === undefined) return false;
          return String(row[col] ?? '') === decodeURIComponent(opVal);
        }),
      );
    }
    return filtered as T[];
  }

  public async upsertRow<T = Record<string, unknown>>(
    table: string,
    payload: Record<string, unknown> | Record<string, unknown>[],
    onConflict?: string,
  ): Promise<T[]> {
    if (this.failNextWriteTable === table) {
      this.failNextWriteTable = null;
      throw new Error(`SIMULATED_WRITE_ERROR_${table}`);
    }
    const items = Array.isArray(payload) ? payload : [payload];
    const pk = (onConflict ?? this.primaryKeyFor(table)).split(',')[0];
    const rows = this.tableRows(table);
    for (const item of items) {
      const idx = rows.findIndex((r) => String(r[pk]) === String(item[pk]));
      if (idx >= 0) {
        rows[idx] = { ...rows[idx], ...item };
      } else {
        rows.push({ ...item });
      }
    }
    return items as T[];
  }

  public async patchRows<T = Record<string, unknown>>(
    table: string,
    filterQuery: string,
    patchBody: Record<string, unknown>,
  ): Promise<T[]> {
    const eqMatches = Array.from(filterQuery.matchAll(/([a-z0-9_]+)=eq\.([^&]+)/g));
    const rows = this.tableRows(table);
    const updated: Record<string, unknown>[] = [];
    for (let i = 0; i < rows.length; i += 1) {
      const matches = eqMatches.every(
        (m) => String(rows[i][m[1]] ?? '') === decodeURIComponent(m[2]),
      );
      if (matches) {
        rows[i] = { ...rows[i], ...patchBody };
        updated.push(rows[i]);
      }
    }
    return updated as T[];
  }

  public async deleteRows<T = Record<string, unknown>>(
    table: string,
    filterQuery: string,
  ): Promise<T[]> {
    const eqMatches = Array.from(filterQuery.matchAll(/([a-z0-9_]+)=eq\.([^&]+)/g));
    const rows = this.tableRows(table);
    const remaining: Record<string, any>[] = [];
    const deleted: Record<string, any>[] = [];
    for (const r of rows) {
      const matches = eqMatches.every(
        (m) => String(r[m[1]] ?? '') === decodeURIComponent(m[2]),
      );
      if (matches) deleted.push(r);
      else remaining.push(r);
    }
    this.tables.set(table, remaining);
    return deleted as T[];
  }

  public async callRpc<T = Record<string, unknown>>(
    fnName: string,
    _args: Record<string, unknown>,
  ): Promise<T> {
    throw new Error(`RPC_FALLBACK_${fnName}`);
  }
}

async function runPhase72VaultSwrTests(): Promise<void> {
  console.log('\nRunning Phase 72 Vault/Playlist/Marketplace SWR & Licenses Tests...\n');

  const sharedDriver = new MockVaultCloudDriver();
  const isolateA = new EdgeIsolateDatabaseEngine(
    sharedDriver as unknown as SupabaseCloudDriver,
  );
  const isolateB = new EdgeIsolateDatabaseEngine(
    sharedDriver as unknown as SupabaseCloudDriver,
  );

  // 1. User library delta upsert & hard delete propagate across Worker isolates
  const syncRes = await isolateA.syncLibraryDeltaAsync('usr_me', [
    {
      id: 'lib_p72_iso_1',
      title: 'Limpopo Sunset Vault Mix',
      creatorName: 'Cern',
      creatorHandle: '@cern',
      genre: 'Amapiano',
      mood: 'Soulful',
      moodId: 'soulful',
      bpm: 114,
      durationSeconds: 198,
      isPublic: false,
      updatedAtMs: Date.now(),
    },
  ]);
  assert.equal(syncRes.appliedCount, 1);

  const isoBLib = await isolateB.syncUserLibraryFromCloud('creator_cern');
  assert.ok(isoBLib.some((i) => i.id === 'lib_p72_iso_1'));
  const syncedTrack = isoBLib.find((i) => i.id === 'lib_p72_iso_1')!;
  assert.equal(syncedTrack.creatorId, 'creator_cern');
  assert.equal(syncedTrack.isPublic, false);

  const deleted = await isolateA.deleteLibraryItemAsync('lib_p72_iso_1', 'creator_cern');
  assert.equal(deleted, true);
  const isoBAfterDelete = await isolateB.syncUserLibraryFromCloud(
    'creator_cern',
    undefined,
    true,
  );
  assert.equal(
    isoBAfterDelete.some((i) => i.id === 'lib_p72_iso_1'),
    false,
  );

  // 2. Playlists upsert + share + legacy 'usr_me' canonicalization across isolates
  const createdPl = await isolateA.upsertPlaylistAsync({
    id: 'pl_p72_iso_1',
    creatorId: 'usr_me',
    title: 'Late Night Log Drums',
    description: 'Cross-isolate playlist durability test',
    trackIds: ['trk_01', 'trk_02'],
    isPublic: false,
  });
  assert.equal(createdPl.creatorId, 'creator_cern');

  const sharedPl = await isolateA.sharePlaylistAsync('pl_p72_iso_1');
  assert.ok(sharedPl);
  assert.equal(sharedPl!.isPublic, true);
  assert.ok(sharedPl!.shareCode);

  const plOk = await isolateB.syncPlaylistsFromCloud('usr_me');
  assert.equal(plOk, true);
  const isoBPlaylists = isolateB.getPlaylists('creator_cern', false);
  assert.ok(isoBPlaylists.some((p) => p.id === 'pl_p72_iso_1' && p.isPublic));

  // 3. Buyer beat licenses + marketplace catalog propagate across isolates
  const issuedAt = new Date().toISOString();
  const licRes = isolateA.recordBeatLicenseAtomic({
    certificateId: 'cert_p72_001',
    beatId: 'beat_p72_01',
    beatTitle: 'Pretoria Groove Beat',
    producerId: 'creator_kabza',
    producerHandle: '@kabza_de_venda',
    buyerId: 'usr_me',
    buyerHandle: '@cern',
    tierSlug: 'stems_trackout',
    amountPaidCoins: 150,
    amountPaidZar: 135,
    producerRoyaltyCoins: 128,
    producerRoyaltyZar: 114.75,
    issuedAt,
    commercialTerms: 'Up to 500,000 streams + 4 stems.',
    isExclusive: false,
    enforceBuyerWallet: false,
    dataJson: {
      certificateId: 'cert_p72_001',
      beatId: 'beat_p72_01',
      beatTitle: 'Pretoria Groove Beat',
      producerId: 'creator_kabza',
      producerHandle: '@kabza_de_venda',
      buyerId: 'creator_cern',
      buyerHandle: '@cern',
      tierSlug: 'stems_trackout',
      amountPaidCoins: 150,
      amountPaidZar: 135,
      issuedAtIso8601: issuedAt,
    },
  });
  assert.equal(licRes.status, 'ok');
  await new Promise((r) => setTimeout(r, 25));

  const isoBLicenses = await isolateB.syncBuyerLicensesFromCloud('creator_cern');
  assert.ok(isoBLicenses.some((c) => c.certificateId === 'cert_p72_001'));
  const mktOk = await isolateB.syncMarketplaceFromCloud(true);
  assert.equal(mktOk, true);
  const verify = isolateB.verifyBeatLicense('cert_p72_001');
  assert.equal(verify.found, true);
  assert.equal(verify.valid, true);

  // 4. Failed select NEVER seals domainHydratedAtMs & failed write logs telemetry
  const freshDriver = new MockVaultCloudDriver();
  const isolateC = new EdgeIsolateDatabaseEngine(
    freshDriver as unknown as SupabaseCloudDriver,
  );
  freshDriver.failNextSelectTable = 'user_library_sync';
  const failedFirst = await isolateC.syncUserLibraryFromCloud('creator_fail_recover');
  assert.equal(failedFirst.length, 0);

  await freshDriver.upsertRow('user_library_sync', {
    id: 'lib_p72_recover',
    creator_id: 'creator_fail_recover',
    item_type: 'track',
    title: 'Recovered After Failure',
    data_json: { id: 'lib_p72_recover', creatorId: 'creator_fail_recover', title: 'Recovered After Failure' },
    updated_at: Date.now(),
  });
  const recovered = await isolateC.syncUserLibraryFromCloud('creator_fail_recover');
  assert.equal(recovered.length, 1);

  freshDriver.failNextWriteTable = 'playlists';
  await isolateC.upsertPlaylistAsync({
    id: 'pl_p72_telemetry',
    creatorId: 'creator_cern',
    title: 'Telemetry Failure Playlist',
  });
  assert.ok(
    isolateC
      .getWriteThroughFailures()
      .some((f) => f.label === 'playlists.upsert_async'),
  );

  console.log('ALL PHASE 72 VAULT SWR & BUYER LICENSES TESTS PASSED!');
}

runPhase72VaultSwrTests().catch((err) => {
  console.error(err);
  process.exit(1);
});
