import assert from 'node:assert/strict';
import { EdgeIsolateDatabaseEngine } from '../src/db/edge_persistence_bridge.js';
import type { SupabaseCloudDriver } from '../src/db/supabase_cloud_driver.js';

class MockSharedSupabaseDriver {
  public readonly tables = new Map<string, Array<Record<string, any>>>();
  public failNextSelectTable: string | null = null;
  public failNextWriteTable: string | null = null;
  public rpcCalls = 0;

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
    if (table === 'generation_jobs') return 'generation_id';
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
    const filtered = rows.filter((row) =>
      eqMatches.every((m) => String(row[m[1]] ?? '') === decodeURIComponent(m[2])),
    );
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
    if (this.failNextWriteTable === table) {
      this.failNextWriteTable = null;
      throw new Error(`SIMULATED_PATCH_ERROR_${table}`);
    }
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
    args: Record<string, unknown>,
  ): Promise<T> {
    this.rpcCalls += 1;
    if (fnName !== 'consume_free_monthly_song_quota_atomic') {
      throw new Error(`UNEXPECTED_RPC_${fnName}`);
    }
    const uid = String(args.p_user_id ?? 'creator_cern');
    const rows = this.tableRows('creator_quotas');
    let row = rows.find((r) => r.user_id === uid);
    if (!row) {
      row = {
        user_id: uid,
        plan_tier: 'free',
        free_monthly_songs_limit: 10,
        free_monthly_songs_used: 0,
        cycle_reset_at: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
        updated_at: new Date().toISOString(),
      };
      rows.push(row);
    }
    const limit = Number(row.free_monthly_songs_limit ?? 10);
    let used = Number(row.free_monthly_songs_used ?? 0);
    const allowed = used < limit;
    if (allowed) used += 1;
    row.free_monthly_songs_used = used;
    row.updated_at = new Date().toISOString();
    return {
      userId: uid,
      planTier: row.plan_tier,
      freeMonthlySongsLimit: limit,
      freeMonthlySongsUsed: used,
      freeMonthlySongsRemaining: Math.max(0, limit - used),
      cycleResetAt: row.cycle_reset_at,
      updatedAt: row.updated_at,
      allowed,
    } as T;
  }
}

async function runPhase71WorkerReadThroughTests(): Promise<void> {
  console.log('\nRunning Phase 71 Cross-Isolate Supabase Read/Write-Through Tests...\n');

  const sharedDriver = new MockSharedSupabaseDriver();
  const isolateA = new EdgeIsolateDatabaseEngine(
    sharedDriver as unknown as SupabaseCloudDriver,
  );
  const isolateB = new EdgeIsolateDatabaseEngine(
    sharedDriver as unknown as SupabaseCloudDriver,
  );

  // 1. Cross-isolate notifications sync (Isolate A writes -> Isolate B reads)
  await isolateA.upsertNotificationAsync({
    id: 'notif_p71_iso_1',
    userId: 'creator_p71_cross',
    title: 'Studio Master Complete',
    message: 'Your Amapiano master finished on RunPod.',
    category: 'creatorActivity',
    subtype: 'studio_render',
    targetRoute: '/track/gen_p71_01',
  });
  const isoBNotifs = await isolateB.syncNotificationsFromCloud('creator_p71_cross');
  assert.equal(isoBNotifs.length, 1);
  assert.equal(isoBNotifs[0].id, 'notif_p71_iso_1');

  // 2. Cross-isolate Kinetic Post + threaded comment projection (preserves likes_count + username)
  isolateA.upsertKineticPost({
    id: 'kpost_p71_01',
    creatorId: 'creator_p71_cross',
    creatorName: 'Vhusi',
    creatorHandle: '@vhusi',
    caption: 'Cross-isolate log drum bounce',
    trackTitle: 'Limpopo Dawn',
    genre: 'Amapiano',
  });
  isolateA.insertReelComment({
    id: 'rc_p71_01',
    clipId: 'kpost_p71_01',
    userId: 'creator_lerato',
    username: '@lerato_keys',
    displayName: 'Lerato Keys',
    avatarUrl: 'https://cdn.vhunambi.com/avatars/lerato.png',
    isCreator: true,
    text: 'Sub-bass sits cleanly!',
    likeCount: 7,
  });
  await new Promise((r) => setTimeout(r, 20));

  const rawCommentRow = sharedDriver.tables
    .get('reel_comments')
    ?.find((r) => r.id === 'rc_p71_01');
  assert.ok(rawCommentRow);
  rawCommentRow!.data_json = {};

  const exploreOk = await isolateB.syncExploreFromCloud(true);
  assert.equal(exploreOk, true);
  assert.ok(isolateB.getKineticPostById('kpost_p71_01'));
  const hydratedComment = isolateB.getReelCommentById('rc_p71_01');
  assert.ok(hydratedComment);
  assert.equal(hydratedComment!.likeCount, 7);
  assert.equal(hydratedComment!.username, '@lerato_keys');
  assert.equal(hydratedComment!.displayName, 'Lerato Keys');
  assert.equal(hydratedComment!.avatarUrl, 'https://cdn.vhunambi.com/avatars/lerato.png');
  assert.equal(hydratedComment!.isCreator, true);

  // 3. RunPod webhook completion on Isolate A immediately visible on warm Isolate B
  await isolateA.upsertGenerationJobAsync(
    {
      generationId: 'gen_p71_webhook_01',
      trackTitle: 'Soweto Midnight',
      genre: 'Amapiano',
      language: 'isiZulu',
      status: 'succeeded',
      step: 'ready',
      progressPct: 100,
      masterMp3Url: 'https://r2.vhunambi.com/audio/gen_p71_webhook_01.wav',
      visionMeta: { kind: 'vision', seed: 42, width: 768, height: 1344 },
      createdAt: new Date(),
      updatedAt: new Date(),
    },
    'creator_p71_cross',
    'audio_synthesis',
  );
  const polledJob = await isolateB.syncGenerationJobFromCloud('gen_p71_webhook_01');
  assert.ok(polledJob);
  assert.equal(polledJob!.status, 'succeeded');
  assert.equal(polledJob!.visionMeta?.seed, 42);

  // 4. Atomic quota across Isolate A & Isolate B never exceeds 10 free songs
  const results = await Promise.all(
    Array.from({ length: 12 }, (_, idx) =>
      (idx % 2 === 0 ? isolateA : isolateB).consumeFreeMonthlySongQuotaAsync(
        'creator_p71_quota_race',
      ),
    ),
  );
  const allowedCount = results.filter((r) => r.allowed).length;
  assert.equal(allowedCount, 10);
  const finalQuota = await isolateB.syncCreatorQuotaFromCloud('creator_p71_quota_race');
  assert.equal(finalQuota.freeMonthlySongsUsed, 10);
  assert.equal(finalQuota.freeMonthlySongsRemaining, 0);

  // 5. Timeout/error NEVER seals freshness; write failure records in telemetry ring
  const isolateC = new EdgeIsolateDatabaseEngine(
    sharedDriver as unknown as SupabaseCloudDriver,
  );
  sharedDriver.failNextSelectTable = 'kinetic_posts';
  const failedSync = await isolateC.syncExploreFromCloud(true);
  assert.equal(failedSync, false);
  assert.equal(isolateC.getDomainHydratedAt('explore:global'), undefined);

  sharedDriver.failNextWriteTable = 'notifications';
  await isolateC.upsertNotificationAsync({
    id: 'notif_p71_fail_ring',
    userId: 'creator_p71_cross',
    title: 'Failure Ring Test',
    message: 'Simulated PostgREST error',
  });
  assert.ok(
    isolateC.getWriteThroughFailures().some((f) => f.label === 'notifications.upsert'),
  );

  // 6. applyMutationsBatch track like mirrors likes_count to explore_tracks
  isolateA.upsertExploreTrack({
    id: 'trk_p71_like_01',
    title: 'Venda Log Drum',
    artistName: 'Vhusi',
    genre: 'Amapiano',
    likeCount: 4,
  });
  await new Promise((r) => setTimeout(r, 20));
  isolateA.applyMutationsBatch([
    {
      idempotencyKey: 'mut_p71_trk_like_1',
      entityType: 'track',
      action: 'like',
      payload: { trackId: 'trk_p71_like_01', creatorId: 'creator_p71_cross' },
      createdAt: new Date().toISOString(),
    },
  ]);
  await new Promise((r) => setTimeout(r, 20));
  const pgTrack = sharedDriver.tables
    .get('explore_tracks')
    ?.find((t) => t.id === 'trk_p71_like_01');
  assert.equal(pgTrack?.likes_count, 5);

  console.log('ALL PHASE 71 CROSS-ISOLATE READ/WRITE-THROUGH TESTS PASSED!\n');
}

runPhase71WorkerReadThroughTests().catch((err) => {
  console.error('Phase 71 cross-isolate test failed:', err);
  process.exit(1);
});
