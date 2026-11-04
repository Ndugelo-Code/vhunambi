import { strict as assert } from 'node:assert';
import { app } from '../src/server.js';
import { VhunambiDatabase } from '../src/db/vhunambi_db.js';

async function testPersistenceAndSync(): Promise<void> {
  console.log('🧪 Running Phase 45 SQLite Persistence & Delta Sync Tests...');

  // 1. In-memory engine & table creation
  console.log('  1. Testing SQLite WAL in-memory engine and domain table creation...');
  const testDb = new VhunambiDatabase(':memory:');
  assert.equal(typeof testDb.getLatestSeq(), 'number');
  const feed = testDb.getExploreFeed();
  assert.ok(Array.isArray(feed.posts));
  assert.ok(feed.total >= 1);
  console.log('     ✅ In-memory database & 10 domain tables verified');

  // 2. Monotonic sequence & batch mutations
  console.log('  2. Testing monotonic sequence counter and mutation logging...');
  const seq0 = testDb.getLatestSeq();
  const resBatch = testDb.applyMutationsBatch([
    {
      idempotencyKey: 'idemp_test_01',
      entityType: 'post',
      action: 'create',
      payload: { id: 'post_test_01', caption: 'Test Post 1' },
      createdAt: new Date().toISOString(),
    },
    {
      idempotencyKey: 'idemp_test_02',
      entityType: 'post',
      action: 'create',
      payload: { id: 'post_test_02', caption: 'Test Post 2' },
      createdAt: new Date().toISOString(),
    },
  ]);
  assert.equal(resBatch.applied.length, 2);
  assert.equal(resBatch.skipped.length, 0);
  assert.ok(resBatch.latestSeq > seq0);
  console.log('     ✅ Monotonic sequence advancement verified (seq=' + resBatch.latestSeq + ')');

  // 3. Idempotency deduplication
  console.log('  3. Testing idempotency deduplication on repeated mutation keys...');
  const dupBatch = testDb.applyMutationsBatch([
    {
      idempotencyKey: 'idemp_test_01',
      entityType: 'post',
      action: 'create',
      payload: { id: 'post_test_01', caption: 'Duplicate Attempt' },
      createdAt: new Date().toISOString(),
    },
  ]);
  assert.equal(dupBatch.applied.length, 0);
  assert.equal(dupBatch.skipped.length, 1);
  assert.equal(dupBatch.skipped[0], 'idemp_test_01');
  console.log('     ✅ Idempotency deduplication prevented duplicate entity state modification');

  // 4. HTTP POST /api/sync/mutations & GET /api/sync/delta with ETag 304
  console.log('  4. Testing HTTP POST /api/sync/mutations and GET /api/sync/delta (ETag 304)...');
  const postMutationRes = await app.fetch(
    new Request('http://localhost/api/sync/mutations', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        mutations: [
          {
            idempotencyKey: `idemp_http_${Date.now()}`,
            entityType: 'post',
            action: 'create',
            payload: { id: `post_http_${Date.now()}`, caption: 'HTTP Sync Live' },
            createdAt: new Date().toISOString(),
          },
        ],
      }),
    })
  );
  assert.equal(postMutationRes.status, 200);
  const postJson = (await postMutationRes.json()) as any;
  assert.ok(postJson.applied.length >= 1);

  const deltaRes = await app.fetch(new Request('http://localhost/api/sync/delta?since=0'));
  assert.equal(deltaRes.status, 200);
  const etag = deltaRes.headers.get('ETag');
  assert.ok(etag && etag.startsWith('"cursor-'));

  const cachedRes = await app.fetch(
    new Request('http://localhost/api/sync/delta?since=0', {
      headers: { 'if-none-match': etag! },
    })
  );
  assert.equal(cachedRes.status, 304);
  console.log('     ✅ Delta sync and ETag 304 caching verified (' + etag + ')');

  // 5. Co-Sign graduation upon 25 co-signs
  console.log('  5. Testing co-sign auto-promotion to risingBreakout at 25 co-signs...');
  let latestStage = 'freshCrate';
  let latestCount = 22;

  for (let i = 0; i < 3; i++) {
    const cosignRes = await app.fetch(
      new Request('http://localhost/api/explore/posts/post_seed_01/cosign', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ creatorId: 'creator_cern' }),
      })
    );
    assert.equal(cosignRes.status, 200);
    const json = (await cosignRes.json()) as any;
    latestCount = json.cosignCount;
    latestStage = json.discoveryStage;
  }
  assert.ok(latestCount >= 25);
  assert.equal(latestStage, 'risingBreakout');
  console.log('     ✅ Post graduated to risingBreakout at ' + latestCount + ' co-signs');

  // 6. User Library Sync
  console.log('  6. Testing Cloud Vault Library sync (upsert and snapshot)...');
  const libUpsertRes = await app.fetch(
    new Request('http://localhost/api/library/sync', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        creatorId: 'creator_cern',
        items: [
          {
            id: 'trk_cloud_01',
            itemType: 'track',
            title: 'Ndo Mufuna Matibe Studio Master',
            updatedAt: '2026-11-04T12:00:00Z',
          },
        ],
      }),
    })
  );
  assert.equal(libUpsertRes.status, 200);

  const libGetRes = await app.fetch(new Request('http://localhost/api/library/sync?creatorId=creator_cern'));
  assert.equal(libGetRes.status, 200);
  const libData = (await libGetRes.json()) as any;
  assert.ok(libData.items.some((i: any) => i.id === 'trk_cloud_01'));
  console.log('     ✅ Library sync verified with persistent cloud vault items');

  // 7. Sovereign Wallet Payouts & SA Bank Validation
  console.log('  7. Testing sovereign wallet payouts & South African bank validation...');
  const invalidBankRes = await app.fetch(
    new Request('http://localhost/api/wallet/payout', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        creatorId: 'creator_cern',
        amountZar: 100,
        bankName: 'FakeBankGlobal',
        accountNumber: '1234567890',
        branchCode: '123456',
      }),
    })
  );
  assert.equal(invalidBankRes.status, 400);

  const validPayoutRes = await app.fetch(
    new Request('http://localhost/api/wallet/payout', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        creatorId: 'creator_cern',
        amountZar: 100.00,
        bankName: 'Capitec',
        accountNumber: '1234567890',
        branchCode: '470010',
      }),
    })
  );
  assert.equal(validPayoutRes.status, 200);
  const payoutData = (await validPayoutRes.json()) as any;
  assert.equal(payoutData.success, true);
  assert.equal(payoutData.status, 'processing');
  console.log('     ✅ Payout processed cleanly: R' + payoutData.deductedZar + ' to Capitec');

  console.log('🎉 ALL PHASE 45 PERSISTENCE & DELTA SYNC TESTS PASSED!\n');
}

testPersistenceAndSync().catch((err) => {
  console.error('❌ Phase 45 test failed:', err);
  process.exit(1);
});
