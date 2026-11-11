import { strict as assert } from 'node:assert';
import { app } from '../src/server.js';
import { VhunambiDatabase, vhunambiDb } from '../src/db/vhunambi_db.js';
import { verifyAccessJwt } from '../src/security/crypto_token.js';

async function testPhase61SovereignIdentityAuthAndSecurity(): Promise<void> {
  console.log('Running Phase 61 Sovereign Identity, Auth & Security Tests...');
  const suffix = `${Date.now()}_${Math.floor(Math.random() * 10000)}`;

  // ---------------------------------------------------------------------------
  // 1. Cryptographic Registration, Login, /me & /sessions + Duplicate 409
  // ---------------------------------------------------------------------------
  console.log('  1. Testing /api/auth/register, /login, /me, /sessions...');
  const newHandle = `@phase61_${suffix}`;
  const newEmail = `phase61_${suffix}@vhunambi.test`;
  const registerRes = await app.fetch(
    new Request('http://localhost/api/auth/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        handle: newHandle,
        email: newEmail,
        password: 'SovereignPassword!2026',
        displayName: 'Phase 61 Creator',
        deviceLabel: 'Test Device 1',
        initialCoins: 0,
      }),
    }),
  );
  assert.equal(registerRes.status, 201);
  const regJson = (await registerRes.json()) as any;
  assert.equal(regJson.user.handle, newHandle);
  assert.ok(regJson.user.creatorId.startsWith('creator_phase61_'));
  assert.ok(regJson.accessToken.split('.').length === 3);
  assert.ok(regJson.refreshToken.startsWith('vrt_'));

  const jwtVerified = verifyAccessJwt(regJson.accessToken);
  assert.equal(jwtVerified.valid, true);
  if (jwtVerified.valid) {
    assert.equal(jwtVerified.claims.cid, regJson.user.creatorId);
  }

  // Duplicate registration -> 409 Conflict
  const dupRes = await app.fetch(
    new Request('http://localhost/api/auth/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        handle: newHandle,
        email: newEmail,
        password: 'SovereignPassword!2026',
      }),
    }),
  );
  assert.equal(dupRes.status, 409);

  // Login with seeded creators (@cern & @makhadzi)
  const cernLoginRes = await app.fetch(
    new Request('http://localhost/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        identifier: '@cern',
        password: 'VhunambiSovereign!2026',
        deviceLabel: 'Cern Studio Rig',
      }),
    }),
  );
  assert.equal(cernLoginRes.status, 200);
  const cernAuth = (await cernLoginRes.json()) as any;
  assert.equal(cernAuth.user.creatorId, 'creator_cern');

  const makhadziLoginRes = await app.fetch(
    new Request('http://localhost/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        identifier: '@makhadzi',
        password: 'VhunambiSovereign!2026',
        deviceLabel: 'Makhadzi Studio Rig',
      }),
    }),
  );
  assert.equal(makhadziLoginRes.status, 200);
  const makhadziAuth = (await makhadziLoginRes.json()) as any;
  assert.equal(makhadziAuth.user.creatorId, 'creator_makhadzi');

  // Invalid password -> 401
  const badLoginRes = await app.fetch(
    new Request('http://localhost/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        identifier: '@cern',
        password: 'WrongPassword123',
      }),
    }),
  );
  assert.equal(badLoginRes.status, 401);

  // /api/auth/me & /api/auth/sessions
  const meRes = await app.fetch(
    new Request('http://localhost/api/auth/me', {
      headers: { Authorization: `Bearer ${cernAuth.accessToken}` },
    }),
  );
  assert.equal(meRes.status, 200);
  const meJson = (await meRes.json()) as any;
  assert.equal(meJson.user.creatorId, 'creator_cern');

  const sessionsRes = await app.fetch(
    new Request('http://localhost/api/auth/sessions', {
      headers: { Authorization: `Bearer ${cernAuth.accessToken}` },
    }),
  );
  assert.equal(sessionsRes.status, 200);
  const sessionsJson = (await sessionsRes.json()) as any;
  assert.ok(sessionsJson.count >= 1);
  console.log('     OK Auth registration, seeded login, /me & /sessions verified');

  // ---------------------------------------------------------------------------
  // 2. Refresh Token Rotation, Reuse Detection & Logout Session Revocation
  // ---------------------------------------------------------------------------
  console.log('  2. Testing /api/auth/refresh rotation, reuse detection & /logout...');
  const ephemLoginRes = await app.fetch(
    new Request('http://localhost/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        identifier: newHandle,
        password: 'SovereignPassword!2026',
        deviceLabel: 'Rotation Device',
      }),
    }),
  );
  assert.equal(ephemLoginRes.status, 200);
  const ephemSession = (await ephemLoginRes.json()) as any;
  const firstRefreshToken = ephemSession.refreshToken as string;

  const rotateRes = await app.fetch(
    new Request('http://localhost/api/auth/refresh', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken: firstRefreshToken }),
    }),
  );
  assert.equal(rotateRes.status, 200);
  const rotatedSession = (await rotateRes.json()) as any;
  assert.notEqual(rotatedSession.refreshToken, firstRefreshToken);

  // Replaying already-rotated token triggers family revocation!
  const replayRes = await app.fetch(
    new Request('http://localhost/api/auth/refresh', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken: firstRefreshToken }),
    }),
  );
  assert.equal(replayRes.status, 401);
  const replayJson = (await replayRes.json()) as any;
  assert.equal(replayJson.code, 'AUTH_TOKEN_REUSE_DETECTED');

  // Access token from revoked family is now rejected!
  const revokedMeRes = await app.fetch(
    new Request('http://localhost/api/auth/me', {
      headers: { Authorization: `Bearer ${rotatedSession.accessToken}` },
    }),
  );
  assert.equal(revokedMeRes.status, 401);
  const revokedMeJson = (await revokedMeRes.json()) as any;
  assert.equal(revokedMeJson.code, 'AUTH_SESSION_REVOKED');

  // Explicit logout revokes active session
  const ephemLogin2 = await app.fetch(
    new Request('http://localhost/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        identifier: newHandle,
        password: 'SovereignPassword!2026',
      }),
    }),
  );
  const session2 = (await ephemLogin2.json()) as any;
  const logoutRes = await app.fetch(
    new Request('http://localhost/api/auth/logout', {
      method: 'POST',
      headers: { Authorization: `Bearer ${session2.accessToken}` },
    }),
  );
  assert.equal(logoutRes.status, 200);
  const postLogoutMe = await app.fetch(
    new Request('http://localhost/api/auth/me', {
      headers: { Authorization: `Bearer ${session2.accessToken}` },
    }),
  );
  assert.equal(postLogoutMe.status, 401);
  console.log('     OK Refresh rotation, reuse family revocation & logout verified');

  // ---------------------------------------------------------------------------
  // 3. Cross-Tenant IDOR Blocking (403 TENANT_FORBIDDEN) across all routes
  // ---------------------------------------------------------------------------
  console.log('  3. Testing 403 TENANT_FORBIDDEN across Wallet, Library, Playlists, Marketplace, Sync...');
  const cernHeaders = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${cernAuth.accessToken}`,
  };
  const makhadziHeaders = {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${makhadziAuth.accessToken}`,
  };

  // Seed private library track and private playlist owned by @makhadzi
  const privateLibId = `lib_makhadzi_priv_${suffix}`;
  const makhadziLibRes = await app.fetch(
    new Request('http://localhost/api/library/sync', {
      method: 'POST',
      headers: makhadziHeaders,
      body: JSON.stringify({
        creatorId: 'creator_makhadzi',
        items: [
          {
            id: privateLibId,
            title: 'Makhadzi Private Demo',
            updatedAtMs: Date.now(),
          },
        ],
      }),
    }),
  );
  assert.equal(makhadziLibRes.status, 200);

  const privatePlId = `pl_makhadzi_priv_${suffix}`;
  const makhadziPlRes = await app.fetch(
    new Request('http://localhost/api/playlists', {
      method: 'POST',
      headers: makhadziHeaders,
      body: JSON.stringify({
        id: privatePlId,
        creatorId: 'creator_makhadzi',
        title: 'Makhadzi Private Setlist',
        isPublic: false,
        trackIds: ['trk_cloud_1'],
      }),
    }),
  );
  assert.equal(makhadziPlRes.status, 201);

  // @cern attempts cross-tenant wallet read & payout & creators wallet read
  const idorWalletGet = await app.fetch(
    new Request('http://localhost/api/wallet/creator_makhadzi', {
      headers: cernHeaders,
    }),
  );
  assert.equal(idorWalletGet.status, 403);
  assert.equal(((await idorWalletGet.json()) as any).code, 'TENANT_FORBIDDEN');

  const idorCreatorWallet = await app.fetch(
    new Request('http://localhost/api/creators/creator_makhadzi/wallet', {
      headers: cernHeaders,
    }),
  );
  assert.equal(idorCreatorWallet.status, 403);

  const idorPayoutPost = await app.fetch(
    new Request('http://localhost/api/wallet/payout', {
      method: 'POST',
      headers: cernHeaders,
      body: JSON.stringify({
        creatorId: 'creator_makhadzi',
        amountZar: 100,
        bankName: 'Capitec Bank',
        accountNumber: '1234567890',
        paymentRail: 'capitec_pay',
      }),
    }),
  );
  assert.equal(idorPayoutPost.status, 403);

  // @cern attempts cross-tenant library sync & delete
  const idorLibPost = await app.fetch(
    new Request('http://localhost/api/library/sync', {
      method: 'POST',
      headers: cernHeaders,
      body: JSON.stringify({
        creatorId: 'creator_makhadzi',
        items: [{ id: 'hack_1', title: 'Poison' }],
      }),
    }),
  );
  assert.equal(idorLibPost.status, 403);

  const idorLibDelete = await app.fetch(
    new Request(`http://localhost/api/library/${privateLibId}`, {
      method: 'DELETE',
      headers: cernHeaders,
    }),
  );
  assert.equal(idorLibDelete.status, 403);

  // @cern attempts cross-tenant private playlist read/update/delete
  const idorPlGet = await app.fetch(
    new Request(`http://localhost/api/playlists/${privatePlId}`, {
      headers: cernHeaders,
    }),
  );
  assert.equal(idorPlGet.status, 403);

  const idorPlPut = await app.fetch(
    new Request(`http://localhost/api/playlists/${privatePlId}`, {
      method: 'PUT',
      headers: cernHeaders,
      body: JSON.stringify({ title: 'Stolen Playlist' }),
    }),
  );
  assert.equal(idorPlPut.status, 403);

  const idorPlDelete = await app.fetch(
    new Request(`http://localhost/api/playlists/${privatePlId}`, {
      method: 'DELETE',
      headers: cernHeaders,
    }),
  );
  assert.equal(idorPlDelete.status, 403);

  // @cern attempts marketplace impersonation
  const idorMktPost = await app.fetch(
    new Request('http://localhost/api/marketplace/beats/beat_seed_001/license', {
      method: 'POST',
      headers: cernHeaders,
      body: JSON.stringify({
        buyerId: 'creator_makhadzi',
        tier: 'basic_lease',
      }),
    }),
  );
  assert.equal(idorMktPost.status, 403);

  const idorMktGet = await app.fetch(
    new Request('http://localhost/api/marketplace/licenses/creator_makhadzi', {
      headers: cernHeaders,
    }),
  );
  assert.equal(idorMktGet.status, 403);

  // @cern attempts sync mutation injection for @makhadzi
  const idorSyncPost = await app.fetch(
    new Request('http://localhost/api/sync/mutations', {
      method: 'POST',
      headers: cernHeaders,
      body: JSON.stringify({
        mutations: [
          {
            idempotencyKey: `idor_sync_${suffix}`,
            entityType: 'library_track',
            action: 'create',
            createdAt: new Date().toISOString(),
            payload: {
              id: `hack_lib_${suffix}`,
              creatorId: 'creator_makhadzi',
              title: 'Injected Track',
            },
          },
        ],
      }),
    }),
  );
  assert.equal(idorSyncPost.status, 403);
  console.log('     OK All cross-tenant IDOR attacks blocked with 403 TENANT_FORBIDDEN');

  // ---------------------------------------------------------------------------
  // 4. Zero-Coin Beat Purchase Exploit Elimination (402 INSUFFICIENT_FUNDS)
  // ---------------------------------------------------------------------------
  console.log('  4. Testing zero-coin authenticated beat purchase rejection (402)...');
  const freshLoginRes = await app.fetch(
    new Request('http://localhost/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        identifier: newHandle,
        password: 'SovereignPassword!2026',
      }),
    }),
  );
  const freshAuth = (await freshLoginRes.json()) as any;
  const beatExclTestId = `beat_p61_excl_${suffix}`;
  await app.fetch(
    new Request('http://localhost/api/marketplace/beats', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        id: beatExclTestId,
        producerId: 'creator_makhadzi',
        producerHandle: '@makhadzi',
        producerName: 'Makhadzi',
        title: 'Phase 61 Protected Exclusive',
        genre: 'Lekompo',
        bpm: 118,
        priceCoins: 50,
        priceZar: 45.0,
        previewAudioUrl: 'https://r2.vhunambi.com/beats/p61_test.mp3',
      }),
    }),
  );

  const zeroCoinBuyRes = await app.fetch(
    new Request(
      `http://localhost/api/marketplace/beats/${beatExclTestId}/license`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${freshAuth.accessToken}`,
        },
        body: JSON.stringify({
          buyerId: freshAuth.user.creatorId,
          tier: 'exclusive_stem',
        }),
      },
    ),
  );
  assert.equal(zeroCoinBuyRes.status, 402);
  const zeroCoinJson = (await zeroCoinBuyRes.json()) as any;
  assert.equal(zeroCoinJson.code, 'INSUFFICIENT_FUNDS');

  const beatAfterFail = await app.fetch(
    new Request(`http://localhost/api/marketplace/beats/${beatExclTestId}`),
  );
  const beatAfterJson = (await beatAfterFail.json()) as any;
  assert.equal(beatAfterJson.isExclusiveSold ?? false, false);
  console.log('     OK Zero-coin beat licensing & exclusive theft blocked with 402');

  // ---------------------------------------------------------------------------
  // 5. Strict Mode Header (`x-vhunambi-enforce-auth: true`) Enforcement
  // ---------------------------------------------------------------------------
  console.log('  5. Testing x-vhunambi-enforce-auth: true returns 401 without Bearer...');
  for (const url of [
    'http://localhost/api/wallet/creator_cern',
    'http://localhost/api/library/sync?creatorId=creator_cern',
    'http://localhost/api/playlists?creatorId=creator_cern',
  ]) {
    const strictRes = await app.fetch(
      new Request(url, {
        headers: { 'x-vhunambi-enforce-auth': 'true' },
      }),
    );
    assert.equal(strictRes.status, 401);
    assert.equal(((await strictRes.json()) as any).code, 'AUTH_REQUIRED');
  }
  console.log('     OK Strict mode blocks unauthenticated calls with 401 AUTH_REQUIRED');

  // ---------------------------------------------------------------------------
  // 6. Atomic BEGIN IMMEDIATE Payout Double-Spend Guard
  // ---------------------------------------------------------------------------
  console.log('  6. Testing atomic requestPayout() double-spend guard...');
  const atomicDb = new VhunambiDatabase(':memory:');
  atomicDb.topupWallet('creator_atomic', 120.0, 0);
  const pay1 = atomicDb.requestPayout({
    creatorId: 'creator_atomic',
    amountZar: 80.0,
    bankName: 'Capitec Bank',
    accountNumber: '1234567890',
    paymentRail: 'capitec_pay',
  });
  assert.equal(pay1.success, true);
  assert.equal(pay1.remainingBalanceZar, 40.0);

  const pay2 = atomicDb.requestPayout({
    creatorId: 'creator_atomic',
    amountZar: 60.0,
    bankName: 'Capitec Bank',
    accountNumber: '1234567890',
    paymentRail: 'capitec_pay',
  });
  assert.equal(pay2.success, false);
  assert.equal(atomicDb.getWallet('creator_atomic').balanceZar, 40.0);
  console.log('     OK Atomic payout prevents negative / overdrawn wallet balance');

  // ---------------------------------------------------------------------------
  // 7. Tenant-Scoped GET /api/sync/delta Isolation
  // ---------------------------------------------------------------------------
  console.log('  7. Testing tenant-scoped GET /api/sync/delta isolation...');
  vhunambiDb.topupWallet('creator_makhadzi', 500.0, 1000);
  vhunambiDb.requestPayout({
    creatorId: 'creator_makhadzi',
    amountZar: 60.0,
    bankName: 'FNB',
    accountNumber: '6200123456',
    paymentRail: 'ozow',
  });

  const cernDeltaRes = await app.fetch(
    new Request('http://localhost/api/sync/delta?since=0&limit=200', {
      headers: cernHeaders,
    }),
  );
  assert.equal(cernDeltaRes.status, 200);
  const cernDeltaJson = (await cernDeltaRes.json()) as any;
  const leakedMakhadziPrivate = (cernDeltaJson.mutations as any[]).filter(
    (m) =>
      (m.entityType === 'payout' ||
        m.entityType === 'library_track' ||
        (m.entityType === 'playlist' && m.entityId === privatePlId)) &&
      (m.creatorId === 'creator_makhadzi' || m.entityId === privateLibId),
  );
  assert.equal(leakedMakhadziPrivate.length, 0);

  const makhadziDeltaRes = await app.fetch(
    new Request('http://localhost/api/sync/delta?since=0&limit=200', {
      headers: makhadziHeaders,
    }),
  );
  assert.equal(makhadziDeltaRes.status, 200);
  const makhadziDeltaJson = (await makhadziDeltaRes.json()) as any;
  assert.ok(
    (makhadziDeltaJson.mutations as any[]).some(
      (m) => m.entityId === privateLibId || m.entityId === privatePlId,
    ),
    'Owner should receive their own private delta mutations',
  );
  console.log('     OK Tenant-scoped sync delta prevents private row leakage');

  console.log('\nALL PHASE 61 SOVEREIGN IDENTITY, AUTH & SECURITY TESTS PASSED!');
}

testPhase61SovereignIdentityAuthAndSecurity().catch((err) => {
  console.error('Phase 61 backend security test failed:', err);
  process.exit(1);
});
