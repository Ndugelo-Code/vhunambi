import { strict as assert } from 'node:assert';
import { createHmac } from 'node:crypto';
import { app } from '../src/server.js';
import {
  isNodeSqliteAvailable,
  setSimulateEdgeIsolateMode,
  vhunambiDb,
} from '../src/db/vhunambi_db.js';
import {
  SupabaseCloudDriver,
  computeWalletTotalsFromLedgerRows,
  normalizeBeatLicenseRow,
  normalizeLibrarySyncRow,
  normalizeMarketplaceAssetRow,
  normalizePlaylistRow,
  normalizeSyncMutationRow,
  normalizeWalletLedgerRow,
} from '../src/db/supabase_cloud_driver.js';
import { buildDualDialectPipelineEventFrame } from '../src/modules/realtime/generation_session_do.js';
import {
  type JwkPublicKey,
  resolveJwtSecret,
  verifyAccessJwtAsync,
} from '../src/security/crypto_token.js';

function mintTestJwt(creatorId = 'creator_cern', handle = '@cern'): string {
  const secret = resolveJwtSecret();
  const headerB64 = Buffer.from(
    JSON.stringify({ alg: 'HS256', typ: 'JWT' }),
  ).toString('base64url');
  const payloadB64 = Buffer.from(
    JSON.stringify({
      sub: `550e8400-e29b-41d4-a716-${Date.now().toString().slice(-12).padStart(12, '0')}`,
      session_id: '770e8400-e29b-41d4-a716-446655440999',
      role: 'authenticated',
      email: 'cern@vhunambi.co.za',
      user_metadata: {
        creator_id: creatorId,
        handle,
      },
      iat: Math.floor(Date.now() / 1000) - 5,
      exp: Math.floor(Date.now() / 1000) + 3600,
    }),
  ).toString('base64url');
  const sigB64 = createHmac('sha256', secret)
    .update(`${headerB64}.${payloadB64}`)
    .digest('base64url');
  return `${headerB64}.${payloadB64}.${sigB64}`;
}

async function testPhase63E2eCloudPipelineAndPreflight(): Promise<void> {
  console.log('🧪 Running Phase 63 End-to-End Cloud Pipeline & Preflight Tests...');
  const jwt = mintTestJwt('creator_cern', '@cern');

  // ---------------------------------------------------------------------------
  // 1. M63.1 / G-63-01: workerd simulated isolate mode across all 7 domain routes + PayFast + Auth
  // ---------------------------------------------------------------------------
  console.log(
    '  1. Testing workerd simulated isolate mode across all 7 domain routes & PayFast...',
  );
  setSimulateEdgeIsolateMode(true);
  try {
    assert.equal(isNodeSqliteAvailable(), false);

    // Explore
    const exploreRes = await app.fetch(
      new Request('http://localhost/api/explore', {
        headers: { Authorization: `Bearer ${jwt}` },
      }),
    );
    assert.equal(exploreRes.status, 200);
    const exploreJson = (await exploreRes.json()) as {
      success: boolean;
      tracks: unknown[];
    };
    assert.equal(exploreJson.success, true);
    assert.ok(exploreJson.tracks.length >= 1);

    // Library
    const libPostRes = await app.fetch(
      new Request('http://localhost/api/library/sync', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${jwt}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          creatorId: 'creator_cern',
          items: [
            {
              id: 'trk_edge_isolate_1',
              title: 'Edge Isolate Anthem',
              genre: 'Amapiano',
              language: 've',
              remoteAudioUrl: 'https://r2.vhunambi.com/audio/edge_1.mp3',
              updatedAtMs: Date.now(),
            },
          ],
        }),
      }),
    );
    assert.equal(libPostRes.status, 200);
    const libGetRes = await app.fetch(
      new Request('http://localhost/api/library/sync?creatorId=creator_cern', {
        headers: { Authorization: `Bearer ${jwt}` },
      }),
    );
    assert.equal(libGetRes.status, 200);
    const libJson = (await libGetRes.json()) as { items: Array<{ id: string }> };
    assert.ok(libJson.items.some((i) => i.id === 'trk_edge_isolate_1'));

    // Playlists
    const plPostRes = await app.fetch(
      new Request('http://localhost/api/playlists', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${jwt}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          id: 'pl_edge_1',
          creatorId: 'creator_cern',
          title: 'Venda Night Crate',
          trackIds: ['trk_edge_isolate_1'],
          isPublic: true,
        }),
      }),
    );
    assert.equal(plPostRes.status, 201);
    const plGetRes = await app.fetch(
      new Request('http://localhost/api/playlists?creatorId=creator_cern', {
        headers: { Authorization: `Bearer ${jwt}` },
      }),
    );
    assert.equal(plGetRes.status, 200);

    // Sync mutations & delta
    const syncPostRes = await app.fetch(
      new Request('http://localhost/api/sync/mutations', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${jwt}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          mutations: [
            {
              idempotencyKey: `mut_edge_${Date.now()}`,
              entityType: 'track_meta',
              action: 'upsert',
              payload: { creatorId: 'creator_cern', id: 'trk_edge_isolate_1' },
              createdAt: new Date().toISOString(),
            },
          ],
        }),
      }),
    );
    assert.equal(syncPostRes.status, 200);
    const syncDeltaRes = await app.fetch(
      new Request('http://localhost/api/sync/delta?since_seq=0', {
        headers: { Authorization: `Bearer ${jwt}` },
      }),
    );
    assert.equal(syncDeltaRes.status, 200);

    // Wallet
    const banksRes = await app.fetch(
      new Request('http://localhost/api/wallet/banks', {
        headers: { Authorization: `Bearer ${jwt}` },
      }),
    );
    assert.equal(banksRes.status, 200);
    const walletBeforeRes = await app.fetch(
      new Request('http://localhost/api/wallet/creator_cern', {
        headers: { Authorization: `Bearer ${jwt}` },
      }),
    );
    assert.equal(walletBeforeRes.status, 200);
    const walletBefore = (await walletBeforeRes.json()) as {
      balanceCoins: number;
    };
    assert.ok(walletBefore.balanceCoins >= 1200);

    // Marketplace
    const mktGetRes = await app.fetch(
      new Request('http://localhost/api/marketplace/beats', {
        headers: { Authorization: `Bearer ${jwt}` },
      }),
    );
    assert.equal(mktGetRes.status, 200);
    const mktPostRes = await app.fetch(
      new Request('http://localhost/api/marketplace/beats', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${jwt}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          title: 'Venda Log Drum Edge Beat',
          genre: 'Amapiano',
          bpm: 113,
          previewAudioUrl: 'https://r2.vhunambi.com/beats/edge_beat.mp3',
          priceZar: 250,
          priceCoins: 300,
          producerId: 'creator_cern',
        }),
      }),
    );
    assert.equal(mktPostRes.status, 201);

    // Social
    const socFeedRes = await app.fetch(
      new Request('http://localhost/api/social/feed', {
        headers: { Authorization: `Bearer ${jwt}` },
      }),
    );
    assert.equal(socFeedRes.status, 200);
    const socPubRes = await app.fetch(
      new Request('http://localhost/api/social/publish', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${jwt}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          trackId: 'trk_edge_isolate_1',
          title: 'Edge Isolate Anthem',
          caption: 'Workerd persistence bridge live!',
          creatorId: 'creator_cern',
        }),
      }),
    );
    assert.equal(socPubRes.status, 201);

    // Auth (/api/auth/me in workerd)
    const meRes = await app.fetch(
      new Request('http://localhost/api/auth/me', {
        headers: { Authorization: `Bearer ${jwt}` },
      }),
    );
    assert.equal(meRes.status, 200);

    // PayFast packs, checkout, sandbox-settle, idempotency & non-sandbox 403
    const packsRes = await app.fetch(
      new Request('http://localhost/api/payments/payfast/packs'),
    );
    assert.equal(packsRes.status, 200);
    const packsJson = (await packsRes.json()) as {
      packs: Array<{ packId: string; amountZar: number; coinsGranted: number }>;
    };
    assert.equal(packsJson.packs.length, 3);
    assert.equal(packsJson.packs[0].packId, 'pack_starter_500');
    assert.equal(packsJson.packs[0].amountZar, 55);
    assert.equal(packsJson.packs[0].coinsGranted, 500);

    const checkoutRes = await app.fetch(
      new Request('http://localhost/api/payments/payfast/checkout', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${jwt}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          creatorId: 'creator_cern',
          packId: 'pack_starter_500',
        }),
      }),
    );
    assert.equal(checkoutRes.status, 201);
    const checkoutJson = (await checkoutRes.json()) as { checkoutId: string };

    // Blocked when PAYFAST_SANDBOX === 'false'
    const forbiddenSandboxRes = await app.fetch(
      new Request(
        `http://localhost/api/payments/payfast/sandbox-settle/${checkoutJson.checkoutId}`,
        {
          method: 'POST',
          headers: { Authorization: `Bearer ${jwt}` },
        },
      ),
      { PAYFAST_SANDBOX: 'false' } as never,
    );
    assert.equal(forbiddenSandboxRes.status, 403);

    // Allowed when PAYFAST_SANDBOX === true
    const settleRes = await app.fetch(
      new Request(
        `http://localhost/api/payments/payfast/sandbox-settle/${checkoutJson.checkoutId}`,
        {
          method: 'POST',
          headers: { Authorization: `Bearer ${jwt}` },
        },
      ),
      { PAYFAST_SANDBOX: 'true' } as never,
    );
    assert.equal(settleRes.status, 200);
    const settleJson = (await settleRes.json()) as {
      settled: boolean;
      sandbox: boolean;
      idempotentReplay: boolean;
      coinsCredited: number;
      balanceCoins: number;
    };
    assert.equal(settleJson.settled, true);
    assert.equal(settleJson.sandbox, true);
    assert.equal(settleJson.idempotentReplay, false);
    assert.equal(settleJson.coinsCredited, 500);
    assert.equal(settleJson.balanceCoins, walletBefore.balanceCoins + 500);

    // Idempotent replay does NOT double credit
    const replayRes = await app.fetch(
      new Request(
        `http://localhost/api/payments/payfast/sandbox-settle/${checkoutJson.checkoutId}`,
        {
          method: 'POST',
          headers: { Authorization: `Bearer ${jwt}` },
        },
      ),
      { PAYFAST_SANDBOX: 'true' } as never,
    );
    assert.equal(replayRes.status, 200);
    const replayJson = (await replayRes.json()) as {
      idempotentReplay: boolean;
      balanceCoins: number;
    };
    assert.equal(replayJson.idempotentReplay, true);
    assert.equal(replayJson.balanceCoins, walletBefore.balanceCoins + 500);

    // Status reflects settled checkout and incremented balance
    const statusRes = await app.fetch(
      new Request(
        `http://localhost/api/payments/payfast/status/${checkoutJson.checkoutId}`,
        {
          headers: { Authorization: `Bearer ${jwt}` },
        },
      ),
    );
    assert.equal(statusRes.status, 200);
    const statusJson = (await statusRes.json()) as {
      status: string;
      walletBalanceCoins: number;
    };
    assert.equal(statusJson.status, 'completed');
    assert.equal(statusJson.walletBalanceCoins, walletBefore.balanceCoins + 500);

    // Preflight inside edge isolate reports edge_isolate_memory
    const edgePreflightRes = await app.fetch(
      new Request('http://localhost/api/system/preflight', {
        headers: { Authorization: `Bearer ${jwt}` },
      }),
    );
    assert.equal(edgePreflightRes.status, 200);
    const edgePreflightJson = (await edgePreflightRes.json()) as {
      persistenceEngine: string;
    };
    assert.equal(edgePreflightJson.persistenceEngine, 'edge_isolate_memory');
  } finally {
    setSimulateEdgeIsolateMode(false);
  }
  assert.equal(isNodeSqliteAvailable(), true);

  // ---------------------------------------------------------------------------
  // 2. M63.1 / G-63-01: SupabaseCloudDriver CRUD + 6 SQLite <-> Postgres normalizers
  // ---------------------------------------------------------------------------
  console.log(
    '  2. Testing SupabaseCloudDriver CRUD & 6-table schema/sign normalizers...',
  );
  const originalFetch = globalThis.fetch;
  const fetchCalls: Array<{ url: string; method: string; headers: Record<string, string> }> = [];
  globalThis.fetch = (async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = typeof input === 'string' ? input : input.toString();
    const method = (init?.method ?? 'GET').toUpperCase();
    const headers = (init?.headers ?? {}) as Record<string, string>;
    fetchCalls.push({ url, method, headers });
    return new Response(JSON.stringify([{ id: 'row_1', ok: true }]), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  }) as typeof fetch;

  try {
    const driver = new SupabaseCloudDriver({
      SUPABASE_URL: 'https://demo.supabase.co',
      SUPABASE_SERVICE_ROLE_KEY: 'service_role_secret_key_for_phase63_test_1234',
      SUPABASE_ANON_KEY: 'anon_secret_key_for_phase63_test_1234',
    });
    assert.equal(driver.isConfigured(), true);

    await driver.insertRow('creators', { id: 'creator_cern' });
    await driver.upsertRow('creators', { id: 'creator_cern' }, 'id');
    await driver.patchRows('creators', 'id=eq.creator_cern', { verified: true });
    await driver.deleteRows('creators', 'id=eq.creator_cern');

    assert.equal(fetchCalls.length, 4);
    assert.equal(fetchCalls[0].method, 'POST');
    assert.equal(fetchCalls[1].headers.Prefer, 'resolution=merge-duplicates,return=representation');
    assert.ok(fetchCalls[1].url.includes('on_conflict=id'));
    assert.equal(fetchCalls[2].method, 'PATCH');
    assert.equal(fetchCalls[3].method, 'DELETE');
  } finally {
    globalThis.fetch = originalFetch;
  }

  // Normalizer sign & column parity checks
  const sqlitePayout = normalizeWalletLedgerRow({
    id: 'w1',
    creator_id: 'creator_cern',
    type: 'payout',
    amount_zar: 100,
    amount_coins: 0,
    status: 'completed',
    data_json: JSON.stringify({ rail: 'capitec_pay' }),
  });
  assert.equal(sqlitePayout.signedDeltaZar, -100);
  const pgPayout = normalizeWalletLedgerRow({
    id: 'w2',
    creator_id: 'creator_cern',
    type: 'payout_withdrawal',
    amount_zar: -50,
    amount_coins: 0,
    status: 'completed',
    metadata_json: { rail: 'ozow' },
  });
  assert.equal(pgPayout.signedDeltaZar, -50);
  const totals = computeWalletTotalsFromLedgerRows([
    {
      id: 'w0',
      creator_id: 'creator_cern',
      type: 'topup',
      amount_zar: 500,
      amount_coins: 1500,
      status: 'completed',
    },
    {
      id: 'w1',
      creator_id: 'creator_cern',
      type: 'payout',
      amount_zar: 100,
      status: 'completed',
    },
    {
      id: 'w2',
      creator_id: 'creator_cern',
      type: 'payout_withdrawal',
      amount_zar: -50,
      status: 'completed',
    },
  ]);
  assert.equal(totals.balanceZar, 350);
  assert.equal(totals.balanceCoins, 1500);

  const normalizedLic = normalizeBeatLicenseRow({
    certificate_id: 'cert_1',
    amount_paid_coins: 300,
    amount_paid_zar: 50,
    purchased_at: '2026-11-11T00:00:00.000Z',
  });
  assert.equal(normalizedLic.amountPaidCoins, 300);
  assert.equal(normalizedLic.amountPaidZar, 50);
  assert.equal(normalizedLic.issuedAt, '2026-11-11T00:00:00.000Z');

  const normalizedLib = normalizeLibrarySyncRow({
    id: 'lib_1',
    updated_at: 1762819200000,
  });
  assert.ok(String(normalizedLib.updatedAt).endsWith('Z'));

  const normalizedMut = normalizeSyncMutationRow({
    seq: 42,
    mutation_id: 'mut_pg_42',
    operation: 'upsert',
    server_ts: '2026-11-11T00:00:00.000Z',
  });
  assert.equal(normalizedMut.idempotencyKey, 'mut_pg_42');
  assert.equal(normalizedMut.action, 'upsert');

  const normalizedPl = normalizePlaylistRow({
    id: 'pl_pg_1',
    cover_image_url: 'https://r2.vhunambi.com/covers/pl.png',
    is_public: true,
    tracks_json: JSON.stringify(['trk_1']),
  });
  assert.equal(normalizedPl.isPublic, true);
  assert.deepEqual(normalizedPl.trackIds, ['trk_1']);

  const normalizedAsset = normalizeMarketplaceAssetRow({
    id: 'beat_1',
    is_exclusive_sold: 1,
    exclusive_buyer_id: 'creator_cern',
  });
  assert.equal(normalizedAsset.isExclusiveSold, true);
  assert.equal(normalizedAsset.exclusiveBuyerId, 'creator_cern');

  // ---------------------------------------------------------------------------
  // 3. M63.1 / M63.2 / M63.4: PUT /r2/:key, melody render-reference WAV,
  //    dual-dialect DO frame, Vision render-video MP4 & POST /v1/generations
  // ---------------------------------------------------------------------------
  console.log(
    '  3. Testing PUT /r2/:key, melody WAV upload, dual-dialect DO frame & Vision R2 MP4...',
  );
  const putR2Payload = Uint8Array.from([0x52, 0x49, 0x46, 0x46, 0x24, 0x00, 0x00, 0x00]);
  const putR2Res = await app.fetch(
    new Request('http://localhost/r2/signatures/p63_probe.wav', {
      method: 'PUT',
      headers: { 'Content-Type': 'audio/wav' },
      body: putR2Payload,
    }),
  );
  assert.equal(putR2Res.status, 200);
  const getR2Res = await app.fetch(
    new Request('http://localhost/r2/signatures/p63_probe.wav'),
  );
  assert.equal(getR2Res.status, 200);
  assert.equal(getR2Res.headers.get('content-type'), 'audio/wav');
  const getR2Bytes = new Uint8Array(await getR2Res.arrayBuffer());
  assert.deepEqual(Array.from(getR2Bytes), Array.from(putR2Payload));

  // POST /v1/melodies/render-reference -> stores RIFF WAV in R2
  const melodyRes = await app.fetch(
    new Request('http://localhost/v1/melodies/render-reference', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        id: 'mel_p63_1',
        name: 'Venda Log Drum Sketch',
        genre: 'Amapiano',
        instrument: 'amapiano_log_drum',
        musicalKey: 'F# Minor',
        bpm: 113,
        notes: [
          { stepIndex: 0, scaleRow: 1, velocity: 0.9 },
          { stepIndex: 4, scaleRow: 3, velocity: 0.85 },
        ],
      }),
    }),
  );
  assert.equal(melodyRes.status, 200);
  const melodyJson = (await melodyRes.json()) as {
    success: boolean;
    r2ObjectKey: string;
    r2ReferenceUrl: string;
  };
  assert.equal(melodyJson.success, true);
  assert.ok(melodyJson.r2ObjectKey.startsWith('sketchpad-refs/'));
  const wavFetch = await app.fetch(
    new Request(`http://localhost/r2/${melodyJson.r2ObjectKey}`),
  );
  assert.equal(wavFetch.status, 200);
  const wavBuf = new Uint8Array(await wavFetch.arrayBuffer());
  assert.equal(
    String.fromCharCode(wavBuf[0], wavBuf[1], wavBuf[2], wavBuf[3]),
    'RIFF',
  );

  // POST /v1/generations accepting referenceAudioUrl + pregenStemLocks
  const genRes = await app.fetch(
    new Request('http://localhost/v1/generations', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        trackTitle: 'Phase 63 Master',
        genre: 'Amapiano',
        language: 've',
        isInstrumental: true,
        tempoBpm: 113,
        musicalKey: 'F# Minor',
        referenceAudioUrl: melodyJson.r2ReferenceUrl,
        pregenStemLocks: {
          drums: 'lockedPure44k',
          vocals: 'harmonicInpaint',
        },
      }),
    }),
  );
  assert.ok(genRes.status === 200 || genRes.status === 201 || genRes.status === 202);

  // GenerationSessionDO dual-dialect frame
  const readyFrame = buildDualDialectPipelineEventFrame({
    generationId: 'gen_dual_1',
    status: 'completed',
    progressPct: 100,
    trackTitle: 'Dual Dialect Track',
    genre: 'Amapiano',
    masterMp3Url: 'https://r2.vhunambi.com/audio/gen_dual_1/master.mp3',
    stemUrls: {
      vocals: 'https://r2.vhunambi.com/audio/gen_dual_1/vocals.mp3',
      drums: 'https://r2.vhunambi.com/audio/gen_dual_1/drums.mp3',
      bass: 'https://r2.vhunambi.com/audio/gen_dual_1/bass.mp3',
      melody: 'https://r2.vhunambi.com/audio/gen_dual_1/melody.mp3',
    },
  });
  assert.equal(readyFrame.generation_id, 'gen_dual_1');
  assert.equal(readyFrame.step_index, 4);
  assert.equal(readyFrame.progress_percent, 1);
  assert.ok(readyFrame.completed_track && typeof readyFrame.completed_track === 'object');

  // Vision render-video R2 MP4 persistence & polling
  const renderRes = await app.fetch(
    new Request('http://localhost/v1/vision/render-video', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        title: 'Phase 63 Reel',
        resolution: '1080x1920',
        fps: 60,
        preset: 'kineticBounce',
      }),
    }),
  );
  assert.equal(renderRes.status, 200);
  const renderJson = (await renderRes.json()) as {
    jobId: string;
    videoUrl: string;
  };
  assert.ok(renderJson.videoUrl.includes('.mp4'));
  const reelPollRes = await app.fetch(
    new Request(`http://localhost/v1/vision/render-video/${renderJson.jobId}`),
  );
  assert.equal(reelPollRes.status, 200);
  const r2ReelPath = new URL(renderJson.videoUrl).pathname.replace(/^\/+/, '');
  const storedReel = await app.fetch(
    new Request(`http://localhost/r2/${r2ReelPath}`),
  );
  assert.equal(storedReel.status, 200);
  const mp4Bytes = new Uint8Array(await storedReel.arrayBuffer());
  assert.equal(
    String.fromCharCode(mp4Bytes[4], mp4Bytes[5], mp4Bytes[6], mp4Bytes[7]),
    'ftyp',
  );

  // ---------------------------------------------------------------------------
  // 4. M63.5 / G-63-06: GET /api/system/preflight & loopback webhook detector
  // ---------------------------------------------------------------------------
  console.log(
    '  4. Testing GET /api/system/preflight & loopback webhook detection...',
  );
  const preflightRes = await app.fetch(
    new Request('http://localhost/api/system/preflight', {
      headers: { Authorization: `Bearer ${jwt}` },
    }),
  );
  assert.equal(preflightRes.status, 200);
  const preflightJson = (await preflightRes.json()) as {
    persistenceEngine: string;
    pillars: Record<string, { status: string; mode: string; summary: string }>;
  };
  assert.equal(preflightJson.persistenceEngine, 'node_sqlite');
  for (const key of [
    'supabase',
    'r2Vault',
    'runpodAudio',
    'runpodVision',
    'paymentAndLlm',
    'webhookCallback',
  ]) {
    assert.ok(preflightJson.pillars[key], `Missing pillar ${key}`);
  }

  // Loopback webhook warning when RUNPOD_API_KEY is armed against localhost
  const loopbackWarnRes = await app.fetch(
    new Request('http://localhost/v1/system/preflight', {
      headers: { Authorization: `Bearer ${jwt}` },
    }),
    {
      RUNPOD_API_KEY: 'rp_test_armed_secret_key',
      RUNPOD_ENDPOINT_ID: 'ep_test_audio_123',
      WEBHOOK_BASE_URL: 'http://localhost:3000',
    } as never,
  );
  assert.equal(loopbackWarnRes.status, 200);
  const loopbackWarnJson = (await loopbackWarnRes.json()) as {
    status: string;
    pillars: { webhookCallback: { status: string; summary: string } };
  };
  assert.equal(loopbackWarnJson.status, 'misconfigured');
  assert.equal(loopbackWarnJson.pillars.webhookCallback.status, 'misconfigured');

  // Verify SQLite balance remained consistent after isolate exit
  assert.ok(vhunambiDb.getWalletSnapshot('creator_cern').balanceCoins >= 1200);

  // ---------------------------------------------------------------------------
  // 5. Supabase ECC (P-256 / ES256) JWKS Verification & sb_secret_ Header Guard
  // ---------------------------------------------------------------------------
  console.log(
    '  5. Testing Supabase ES256 (ECC P-256) JWKS verification & sb_secret_ headers...',
  );
  const kp = await globalThis.crypto.subtle.generateKey(
    { name: 'ECDSA', namedCurve: 'P-256' },
    true,
    ['sign', 'verify'],
  );
  const pubJwk = (await globalThis.crypto.subtle.exportKey(
    'jwk',
    kp.publicKey,
  )) as JwkPublicKey;
  pubJwk.kid = 'kid_phase63_p256';
  pubJwk.alg = 'ES256';
  const esHeaderB64 = Buffer.from(
    JSON.stringify({ alg: 'ES256', typ: 'JWT', kid: 'kid_phase63_p256' }),
  ).toString('base64url');
  const esPayloadB64 = Buffer.from(
    JSON.stringify({
      sub: '990e8400-e29b-41d4-a716-446655440111',
      session_id: '880e8400-e29b-41d4-a716-446655440222',
      role: 'authenticated',
      user_metadata: {
        creator_id: 'creator_blackcoffee',
        handle: '@blackcoffee',
      },
      iat: Math.floor(Date.now() / 1000) - 5,
      exp: Math.floor(Date.now() / 1000) + 3600,
    }),
  ).toString('base64url');
  const esSigBuf = await globalThis.crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    kp.privateKey,
    new TextEncoder().encode(`${esHeaderB64}.${esPayloadB64}`),
  );
  const esJwt = `${esHeaderB64}.${esPayloadB64}.${Buffer.from(esSigBuf).toString('base64url')}`;
  const esVerified = await verifyAccessJwtAsync(esJwt, {
    jwksKeysOverride: [pubJwk],
  });
  assert.equal(esVerified.valid, true);
  if (esVerified.valid) {
    assert.equal(esVerified.claims.cid, 'creator_black_coffee');
    assert.equal(esVerified.claims.isGoTrueToken, true);
  }
  const tamperedJwt = `${esHeaderB64}.${esPayloadB64}.${Buffer.from(new Uint8Array(64)).toString('base64url')}`;
  const esRejected = await verifyAccessJwtAsync(tamperedJwt, {
    jwksKeysOverride: [pubJwk],
  });
  assert.equal(esRejected.valid, false);

  const prevFetchForSecretKeyTest = globalThis.fetch;
  let capturedHeaders: Record<string, string> = {};
  globalThis.fetch = (async (_url: unknown, init?: RequestInit) => {
    capturedHeaders = (init?.headers as Record<string, string>) ?? {};
    return new Response(JSON.stringify([{ id: 'creator_cern' }]), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  }) as typeof fetch;
  try {
    const secretKeyDriver = new SupabaseCloudDriver({
      SUPABASE_URL: 'https://example-proj.supabase.co',
      SUPABASE_SERVICE_ROLE_KEY: 'sb_secret_test_key_1234567890abcdef',
    });
    await secretKeyDriver.selectRows('creators', 'select=id');
    assert.equal(capturedHeaders.apikey, 'sb_secret_test_key_1234567890abcdef');
    assert.equal(capturedHeaders.Authorization, undefined);
  } finally {
    globalThis.fetch = prevFetchForSecretKeyTest;
  }

  console.log('✅ Phase 63 End-to-End Cloud Pipeline & Preflight Tests Passed 100%!');
}

testPhase63E2eCloudPipelineAndPreflight().catch((err) => {
  console.error('❌ Phase 63 test failed:', err);
  process.exit(1);
});

