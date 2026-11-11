import { strict as assert } from 'node:assert';
import { app } from '../src/server.js';
import { VhunambiDatabase } from '../src/db/vhunambi_db.js';

async function testPhase59Convergence(): Promise<void> {
  console.log('Running Phase 59 Full-Stack Backend API Convergence Tests...');

  // ---------------------------------------------------------------------------
  // 1. In-memory SQLite WAL Engine: Seeds, Explore Catalog, LWW, Playlists, Banks
  // ---------------------------------------------------------------------------
  console.log('  1. Testing VhunambiDatabase seeds & Phase 59 domain methods...');
  const db = new VhunambiDatabase(':memory:');

  const allTracks = db.getExploreTracks({ limit: 50 });
  assert.ok(allTracks.items.length >= 12, 'expected >= 12 seeded African tracks');
  assert.ok(
    allTracks.items.some((t) => t.genre === 'Amapiano'),
    'expected Amapiano track in seeds',
  );
  assert.ok(
    allTracks.items.some((t) => t.genre === 'Lekompo'),
    'expected Lekompo track in seeds',
  );

  // Genre filter on tracks & posts
  const amapianoOnly = db.getExploreTracks({ genre: 'Amapiano' });
  assert.ok(amapianoOnly.items.length >= 2);
  assert.ok(
    amapianoOnly.items.every(
      (t) =>
        t.genre.toLowerCase() === 'amapiano' ||
        t.subGenre.toLowerCase() === 'amapiano',
    ),
  );

  const feedFiltered = db.getExploreFeed({ genre: 'Venda Folk' });
  assert.ok(feedFiltered.posts.length >= 1);
  const feedNonMatching = db.getExploreFeed({ genre: 'NonExistentGenreXYZ' });
  assert.equal(feedNonMatching.posts.length, 0);

  // Radio harmonic rotation
  const radio = db.getExploreRadioRotation('Lekompo', 10);
  assert.equal(radio.genre, 'Lekompo');
  assert.ok(radio.stationTitle.includes('Lekompo'));
  assert.ok(radio.rotation.length >= 1);

  // LWW Library Delta Sync preserving Phase 58 licensing & monotonic playCount
  db.syncLibraryDelta('usr_test_sync', [
    {
      id: 'lib_p59_1',
      title: 'Tzaneen Exclusive Beat',
      artist: 'Kharishma Wave',
      genre: 'Lekompo',
      playCount: 12,
      updatedAtMs: 2000,
      isLicensedBeat: true,
      licenseTier: 'exclusive_stem',
      certificateId: 'CERT-VHB-59-01',
      licenseHash: 'abc123def',
      masterFileSha256: 'deadbeef',
    },
  ]);

  // Attempt stale update (updatedAtMs = 1000 < 2000) -> skipped!
  const staleRes = db.syncLibraryDelta('usr_test_sync', [
    {
      id: 'lib_p59_1',
      title: 'Stale Overwrite Attempt',
      playCount: 1,
      updatedAtMs: 1000,
    },
  ]);
  assert.equal(staleRes.appliedCount, 0);
  assert.equal(staleRes.skippedCount, 1);
  assert.equal(staleRes.items[0].title, 'Tzaneen Exclusive Beat');

  // Newer partial update without license fields -> updates title, preserves license & max playCount
  const newerRes = db.syncLibraryDelta('usr_test_sync', [
    {
      id: 'lib_p59_1',
      title: 'Tzaneen Exclusive Beat (Renamed)',
      playCount: 5,
      updatedAtMs: 3000,
    },
  ]);
  assert.equal(newerRes.appliedCount, 1);
  assert.equal(newerRes.items[0].title, 'Tzaneen Exclusive Beat (Renamed)');
  assert.equal(newerRes.items[0].playCount, 12);
  assert.equal(newerRes.items[0].isLicensedBeat, true);
  assert.equal(newerRes.items[0].certificateId, 'CERT-VHB-59-01');

  // applyMutationsBatch support for library_track, playlist, track
  const batchRes = db.applyMutationsBatch([
    {
      idempotencyKey: 'idemp_p59_track',
      entityType: 'track',
      action: 'create',
      createdAt: new Date().toISOString(),
      payload: {
        id: 'trk_batch_59',
        title: 'Thohoyandou Pulse',
        creatorName: 'Ndugelo',
        genre: 'Venda Folk',
        bpm: 115,
      },
    },
    {
      idempotencyKey: 'idemp_p59_pl',
      entityType: 'playlist',
      action: 'create',
      createdAt: new Date().toISOString(),
      payload: {
        id: 'pl_batch_59',
        creatorId: 'usr_test_sync',
        title: 'Limpopo Late Nights',
        trackIds: ['trk_batch_59'],
      },
    },
    {
      idempotencyKey: 'idemp_p59_lib',
      entityType: 'library_track',
      action: 'create',
      createdAt: new Date().toISOString(),
      payload: {
        id: 'lib_batch_59',
        creatorId: 'usr_test_sync',
        title: 'Batch Synced Master',
        updatedAtMs: 5000,
      },
    },
  ]);
  assert.equal(batchRes.applied.length, 3);
  assert.equal(batchRes.failed.length, 0);
  assert.ok(db.getPlaylistById('pl_batch_59'));
  assert.ok(db.getExploreTracks({ search: 'Thohoyandou' }).items.length >= 1);
  console.log('     OK SQLite Phase 59 engine verified');

  // ---------------------------------------------------------------------------
  // 2. HTTP Explore Bundle, Tracks, Publish & Genre Radio Routes
  // ---------------------------------------------------------------------------
  console.log('  2. Testing HTTP /api/explore, /tracks, /radio/:genre...');
  const bundleRes = await app.fetch(new Request('http://localhost/api/explore'));
  assert.equal(bundleRes.status, 200);
  const bundleJson = (await bundleRes.json()) as any;
  assert.equal(bundleJson.success, true);
  assert.ok(bundleJson.tracks.length >= 12);
  assert.ok(bundleJson.posts.length >= 1);
  assert.ok(bundleJson.radio.rotation.length >= 1);

  const tracksRes = await app.fetch(
    new Request('http://localhost/api/explore/tracks?genre=Amapiano&sort=trending'),
  );
  assert.equal(tracksRes.status, 200);
  const tracksJson = (await tracksRes.json()) as any;
  assert.equal(tracksJson.success, true);
  assert.ok(tracksJson.items.length >= 2);
  assert.ok(
    tracksJson.items.every((t: any) => t.genre.toLowerCase() === 'amapiano'),
  );

  const publishTrackRes = await app.fetch(
    new Request('http://localhost/api/explore/tracks', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        id: `trk_http_${Date.now()}`,
        title: 'Polokwane Groove LIVE',
        creatorName: 'Makhadzi Studio',
        genre: 'Lekompo',
        bpm: 117,
      }),
    }),
  );
  assert.equal(publishTrackRes.status, 201);

  const radioRes = await app.fetch(
    new Request('http://localhost/api/explore/radio/Lekompo'),
  );
  assert.equal(radioRes.status, 200);
  const radioJson = (await radioRes.json()) as any;
  assert.equal(radioJson.success, true);
  assert.equal(radioJson.genre, 'Lekompo');
  assert.ok(
    radioJson.rotation.some((t: any) => t.title === 'Polokwane Groove LIVE'),
  );
  console.log('     OK Explore REST convergence verified');

  // ---------------------------------------------------------------------------
  // 3. HTTP Library Sync & Delete
  // ---------------------------------------------------------------------------
  console.log('  3. Testing HTTP /api/library/sync & DELETE /api/library/:id...');
  const libCreator = `usr_lib_${Date.now()}`;
  const syncPostRes = await app.fetch(
    new Request('http://localhost/api/library/sync', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        creatorId: libCreator,
        items: [
          {
            id: 'lib_http_1',
            itemType: 'track',
            title: 'Cloud Vault Track 1',
            playCount: 4,
            updatedAtMs: 10000,
          },
        ],
      }),
    }),
  );
  assert.equal(syncPostRes.status, 200);
  const syncPostJson = (await syncPostRes.json()) as any;
  assert.equal(syncPostJson.success, true);
  assert.equal(syncPostJson.appliedCount, 1);

  const delLibRes = await app.fetch(
    new Request(`http://localhost/api/library/lib_http_1?creatorId=${libCreator}`, {
      method: 'DELETE',
    }),
  );
  assert.equal(delLibRes.status, 200);
  const afterDelGet = await app.fetch(
    new Request(`http://localhost/api/library/sync?creatorId=${libCreator}`),
  );
  const afterDelJson = (await afterDelGet.json()) as any;
  assert.equal(afterDelJson.items.length, 0);
  console.log('     OK Library delta sync & hard delete verified');

  // ---------------------------------------------------------------------------
  // 4. HTTP Playlists CRUD & Share Code Generation
  // ---------------------------------------------------------------------------
  console.log('  4. Testing HTTP /api/playlists CRUD & /share...');
  const listPlRes = await app.fetch(
    new Request('http://localhost/api/playlists?creatorId=usr_me'),
  );
  assert.equal(listPlRes.status, 200);
  const listPlJson = (await listPlRes.json()) as any;
  assert.ok(listPlJson.items.length >= 2, 'expected seeded playlists');

  const createPlRes = await app.fetch(
    new Request('http://localhost/api/playlists', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        creatorId: 'usr_me',
        title: 'Weekend Braai Amapiano',
        description: 'Pure log drums and soulful piano chords',
        trackIds: ['trk_cloud_1', 'trk_cloud_4'],
      }),
    }),
  );
  assert.equal(createPlRes.status, 201);
  const createdPl = ((await createPlRes.json()) as any).playlist;
  assert.equal(createdPl.title, 'Weekend Braai Amapiano');

  const updatePlRes = await app.fetch(
    new Request(`http://localhost/api/playlists/${createdPl.id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        title: 'Weekend Braai Amapiano Vol. 2',
        trackIds: ['trk_cloud_1', 'trk_cloud_4', 'trk_cloud_6'],
      }),
    }),
  );
  assert.equal(updatePlRes.status, 200);
  assert.equal(
    ((await updatePlRes.json()) as any).playlist.trackIds.length,
    3,
  );

  const sharePlRes = await app.fetch(
    new Request(`http://localhost/api/playlists/${createdPl.id}/share`, {
      method: 'POST',
    }),
  );
  assert.equal(sharePlRes.status, 200);
  const shareJson = (await sharePlRes.json()) as any;
  assert.ok(shareJson.shareCode.startsWith('VH-'));
  assert.ok(shareJson.shareUrl.startsWith('https://vhunambi.za/p/VH-'));

  const deletePlRes = await app.fetch(
    new Request(`http://localhost/api/playlists/${createdPl.id}`, {
      method: 'DELETE',
    }),
  );
  assert.equal(deletePlRes.status, 200);
  console.log('     OK Playlists CRUD & public share verified');

  // ---------------------------------------------------------------------------
  // 5. HTTP SA Banking Gateway: All 6 Banks + Aliases + 4 Payment Rails
  // ---------------------------------------------------------------------------
  console.log('  5. Testing SA Banking Gateway (/api/wallet/banks & /payout)...');
  const banksRes = await app.fetch(
    new Request('http://localhost/api/wallet/banks'),
  );
  assert.equal(banksRes.status, 200);
  const banksJson = (await banksRes.json()) as any;
  assert.equal(banksJson.banks.length, 6);

  const saCreator = `usr_sa_bank_${Date.now()}`;
  await app.fetch(
    new Request('http://localhost/api/wallet/topup', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        creatorId: saCreator,
        amountZar: 2000,
        amountCoins: 6000,
      }),
    }),
  );

  // Instant Capitec Pay via 'Capitec Bank' alias without explicit branchCode
  const capitecPayRes = await app.fetch(
    new Request('http://localhost/api/wallet/payout', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        creatorId: saCreator,
        amountZar: 150,
        bankName: 'Capitec Bank',
        accountNumber: '1423567890',
        paymentRail: 'capitec_pay',
      }),
    }),
  );
  assert.equal(capitecPayRes.status, 200);
  const capitecPayJson = (await capitecPayRes.json()) as any;
  assert.equal(capitecPayJson.status, 'instant_cleared');
  assert.equal(capitecPayJson.branchCode, '470010');
  assert.equal(capitecPayJson.maskedAccount, '****7890');

  // Reject Capitec Pay for FNB
  const badRailRes = await app.fetch(
    new Request('http://localhost/api/wallet/payout', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        creatorId: saCreator,
        amountZar: 100,
        bankName: 'FNB',
        accountNumber: '6200123456',
        paymentRail: 'capitec_pay',
      }),
    }),
  );
  assert.equal(badRailRes.status, 400);

  // Ozow on Absa Bank alias, PayFast on Nedbank, EFT on Standard Bank & TymeBank
  for (const tc of [
    { bank: 'Absa Bank', rail: 'ozow', expectedStatus: 'instant_cleared', branch: '632005' },
    { bank: 'Nedbank', rail: 'payfast', expectedStatus: 'instant_cleared', branch: '198765' },
    { bank: 'TymeBank', rail: 'eft', expectedStatus: 'processing', branch: '678910' },
  ]) {
    const res = await app.fetch(
      new Request('http://localhost/api/wallet/payout', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          creatorId: saCreator,
          amountZar: 100,
          bankName: tc.bank,
          accountNumber: '123456789',
          paymentRail: tc.rail,
        }),
      }),
    );
    assert.equal(res.status, 200, `${tc.bank} / ${tc.rail} should succeed`);
    const json = (await res.json()) as any;
    assert.equal(json.status, tc.expectedStatus);
    assert.equal(json.branchCode, tc.branch);
  }

  // Converged creator payout route with explicit bank & Ozow rail
  const creatorPayoutRes = await app.fetch(
    new Request(`http://localhost/api/creators/${saCreator}/wallet/payout`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        amountZar: 100,
        paymentRail: 'ozow',
        bankName: 'FNB',
        accountNumber: '6200987654',
      }),
    }),
  );
  assert.equal(creatorPayoutRes.status, 200);
  const creatorPayoutJson = (await creatorPayoutRes.json()) as any;
  assert.equal(creatorPayoutJson.status, 'instant_cleared');
  assert.ok(creatorPayoutJson.payoutId.startsWith('payout_'));
  console.log('     OK SA banking gateway across 6 banks & 4 payment rails verified');

  console.log('\nALL PHASE 59 CONVERGENCE BACKEND TESTS PASSED!');
}

testPhase59Convergence().catch((err) => {
  console.error('Phase 59 convergence test failed:', err);
  process.exit(1);
});

