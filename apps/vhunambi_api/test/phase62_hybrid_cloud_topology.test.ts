import { strict as assert } from 'node:assert';
import { createHmac } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { app } from '../src/server.js';
import workerEntry, { GenerationSessionDO } from '../src/worker.js';
import {
  vhunambiDb,
  canonicalizeCreatorId,
  isNodeSqliteAvailable,
} from '../src/db/vhunambi_db.js';
import {
  resolveJwtSecret,
  verifyAccessJwt,
} from '../src/security/crypto_token.js';
import { computePayFastSignature } from '../src/routes/payment_routes.js';
import { resolveMediaUrl, resolveRuntimeEnv } from '../src/config/env.js';

async function testPhase62HybridCloudTopology(): Promise<void> {
  console.log('🧪 Running Phase 62 Hybrid Cloud Stack Topology Tests...');

  // 1. 19-Table Supabase SQL Migration & Lazy SQLite Proxy
  console.log('  1. Verifying 19-table Supabase migration SQL & lazy proxy...');
  assert.equal(isNodeSqliteAvailable(), true);
  const migrationPath = path.resolve(
    process.cwd(),
    '../../supabase/migrations/20261110000001_phase62_hybrid_cloud_schema.sql',
  );
  const migrationSql = fs.readFileSync(migrationPath, 'utf8');
  for (const requiredTable of [
    'creators',
    'users',
    'auth_sessions',
    'sync_mutation_log',
    'wallet_ledger',
    'bank_accounts',
    'explore_tracks',
    'kinetic_posts',
    'published_clips',
    'reel_comments',
    'marketplace_assets',
    'beat_licenses',
    'sound_signatures',
    'user_library_sync',
    'playlists',
    'generation_jobs',
    'voice_clones',
    'social_interactions',
    'payment_topups',
  ]) {
    assert.ok(
      migrationSql.includes(`public.${requiredTable}`),
      `Missing table public.${requiredTable} in Supabase migration`,
    );
  }
  for (const requiredFn of [
    'execute_atomic_payout',
    'record_beat_license_atomic',
    'send_cultural_tip_atomic',
    'custom_access_token_hook',
  ]) {
    assert.ok(
      migrationSql.includes(requiredFn),
      `Missing SQL function ${requiredFn} in Supabase migration`,
    );
  }
  assert.ok(migrationSql.includes('FOR UPDATE'));

  // 2. GoTrue JWT Normalization & @blackcoffee Canonical ID Parity
  console.log('  2. Testing GoTrue JWT normalization & @blackcoffee canonical ID...');
  assert.equal(
    canonicalizeCreatorId('creator_blackcoffee'),
    'creator_black_coffee',
  );
  assert.equal(canonicalizeCreatorId('@blackcoffee'), 'creator_black_coffee');

  // Mint a GoTrue-shaped HS256 token (no top-level `cid` or `sid`)
  const secret = resolveJwtSecret();
  const headerB64 = Buffer.from(
    JSON.stringify({ alg: 'HS256', typ: 'JWT' }),
  ).toString('base64url');
  const payloadB64 = Buffer.from(
    JSON.stringify({
      sub: '550e8400-e29b-41d4-a716-446655440000',
      session_id: '770e8400-e29b-41d4-a716-446655440111',
      role: 'authenticated',
      email: 'cern@vhunambi.co.za',
      user_metadata: {
        creator_id: 'creator_cern',
        handle: '@cern',
      },
      iat: Math.floor(Date.now() / 1000) - 10,
      exp: Math.floor(Date.now() / 1000) + 3600,
    }),
  ).toString('base64url');
  const sigB64 = createHmac('sha256', secret)
    .update(`${headerB64}.${payloadB64}`)
    .digest('base64url');
  const goTrueJwt = `${headerB64}.${payloadB64}.${sigB64}`;

  const verified = verifyAccessJwt(goTrueJwt);
  assert.equal(verified.valid, true);
  if (verified.valid) {
    assert.equal(verified.claims.cid, 'creator_cern');
    assert.equal(verified.claims.hdl, '@cern');
    assert.equal(verified.claims.isGoTrueToken, true);
  }

  // Verify GoTrue JWT passes sovereignAuthMiddleware without 401 AUTH_SESSION_REVOKED
  const meRes = await app.fetch(
    new Request('http://localhost/api/auth/me', {
      headers: { Authorization: `Bearer ${goTrueJwt}` },
    }),
  );
  assert.equal(meRes.status, 200);

  // 3. Strict-Mode Unverified Topup Rejection + PayFast Checkout & Verified ITN
  console.log('  3. Testing strict-mode topup block & PayFast ITN settlement...');
  const blockedTopup = await app.fetch(
    new Request('http://localhost/api/wallet/topup', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${goTrueJwt}`,
        'x-vhunambi-enforce-auth': 'true',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        creatorId: 'creator_cern',
        amountZar: 50000,
        amountCoins: 500000,
      }),
    }),
  );
  assert.equal(blockedTopup.status, 403);

  const checkoutRes = await app.fetch(
    new Request('http://localhost/api/payments/payfast/checkout', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${goTrueJwt}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        creatorId: 'creator_cern',
        packId: 'pack_producer_1500',
      }),
    }),
  );
  assert.equal(checkoutRes.status, 201);
  const checkoutJson = (await checkoutRes.json()) as {
    checkoutId: string;
    amountZar: number;
    coinsToCredit: number;
  };
  assert.ok(checkoutJson.checkoutId.startsWith('chk_pf_'));
  assert.equal(checkoutJson.amountZar, 150);
  assert.equal(checkoutJson.coinsToCredit, 1500);

  // Forged ITN signature -> 400
  const badItnRes = await app.fetch(
    new Request('http://localhost/api/payments/payfast/itn', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        m_payment_id: checkoutJson.checkoutId,
        pf_payment_id: `pf_${Date.now()}`,
        payment_status: 'COMPLETE',
        amount_gross: '150.00',
        signature: 'deadbeef000000000000000000000000',
      }),
    }),
  );
  assert.equal(badItnRes.status, 400);

  // Valid signed ITN -> 200 settled & wallet credited once
  const pfId = `pf_valid_${Date.now()}`;
  const itnFields: Record<string, string> = {
    m_payment_id: checkoutJson.checkoutId,
    pf_payment_id: pfId,
    payment_status: 'COMPLETE',
    amount_gross: '150.00',
  };
  const validSig = computePayFastSignature(
    itnFields,
    resolveRuntimeEnv().PAYFAST_PASSPHRASE,
  );
  const beforeWallet = vhunambiDb.getWalletSnapshot('creator_cern');
  const goodItnRes = await app.fetch(
    new Request('http://localhost/api/payments/payfast/itn', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ...itnFields, signature: validSig }),
    }),
  );
  assert.equal(goodItnRes.status, 200);
  const goodItnJson = (await goodItnRes.json()) as {
    settled: boolean;
    idempotentReplay: boolean;
  };
  assert.equal(goodItnJson.settled, true);
  assert.equal(goodItnJson.idempotentReplay, false);

  const afterWallet = vhunambiDb.getWalletSnapshot('creator_cern');
  assert.equal(afterWallet.balanceCoins, beforeWallet.balanceCoins + 1500);

  // Replay exact same ITN -> idempotent no-op (no double credit!)
  const replayItnRes = await app.fetch(
    new Request('http://localhost/api/payments/payfast/itn', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ...itnFields, signature: validSig }),
    }),
  );
  assert.equal(replayItnRes.status, 200);
  const replayJson = (await replayItnRes.json()) as { idempotentReplay: boolean };
  assert.equal(replayJson.idempotentReplay, true);
  assert.equal(
    vhunambiDb.getWalletSnapshot('creator_cern').balanceCoins,
    afterWallet.balanceCoins,
  );

  // Status poll endpoint confirms completion
  const statusRes = await app.fetch(
    new Request(
      `http://localhost/api/payments/payfast/status/${checkoutJson.checkoutId}`,
      {
        headers: { Authorization: `Bearer ${goTrueJwt}` },
      },
    ),
  );
  assert.equal(statusRes.status, 200);
  const statusJson = (await statusRes.json()) as {
    status: string;
    walletBalanceCoins: number;
  };
  assert.equal(statusJson.status, 'completed');
  assert.equal(statusJson.walletBalanceCoins, afterWallet.balanceCoins);

  // 4. Unified Wallet Routes (/api/wallet/:id == /api/creators/:id/wallet)
  console.log('  4. Testing unified wallet routes...');
  const socialWalletRes = await app.fetch(
    new Request('http://localhost/api/creators/creator_cern/wallet', {
      headers: { Authorization: `Bearer ${goTrueJwt}` },
    }),
  );
  assert.equal(socialWalletRes.status, 200);
  const socialWalletJson = (await socialWalletRes.json()) as {
    balanceCoins: number;
  };
  assert.equal(socialWalletJson.balanceCoins, afterWallet.balanceCoins);

  // 5. Cloudflare Worker Entrypoint, GenerationSessionDO & Zero-Egress /r2 Streaming
  console.log('  5. Testing Cloudflare Worker fetch, GenerationSessionDO & /r2...');
  const mockStorage = new Map<string, unknown>();
  const doInstance = new GenerationSessionDO({
    id: { toString: () => 'do_gen_test_1' },
    storage: {
      get: async <T>(k: string) => mockStorage.get(k) as T | undefined,
      put: async <T>(k: string, v: T) => {
        mockStorage.set(k, v);
      },
      delete: async (k: string) => mockStorage.delete(k),
    },
  });

  const pingRes = await doInstance.fetch(
    new Request('https://do.vhunambi.internal/internal/frame?id=gen_test_1', {
      method: 'POST',
      body: JSON.stringify({ type: 'PING' }),
    }),
  );
  assert.equal(pingRes.status, 200);
  const pongJson = (await pingRes.json()) as { type: string };
  assert.equal(pongJson.type, 'PONG');

  const broadcastRes = await doInstance.fetch(
    new Request('https://do.vhunambi.internal/internal/broadcast?id=gen_test_1', {
      method: 'POST',
      body: JSON.stringify({
        generationId: 'gen_test_1',
        status: 'completed',
        progressPct: 100,
        masterMp3Url: 'https://pub-vault.r2.dev/audio/gen_test_1/master.mp3',
      }),
    }),
  );
  assert.equal(broadcastRes.status, 200);

  const workerHealthRes = await workerEntry.fetch(
    new Request('https://vhunambi-api.workers.dev/health'),
    { R2_BUCKET: 'vhunambi-vault' },
    { waitUntil: () => {}, passThroughOnException: () => {} },
  );
  assert.equal(workerHealthRes.status, 200);

  const r2StreamRes = await workerEntry.fetch(
    new Request('https://vhunambi-api.workers.dev/r2/beats/amapiano_1.mp3'),
    {
      R2_BUCKET: 'vhunambi-vault',
      VHUNAMBI_VAULT: {
        put: async () => null,
        get: async (key: string) =>
          key === 'beats/amapiano_1.mp3'
            ? {
                key,
                etag: 'etag_test_amapiano_1',
                body: new ReadableStream({
                  start(controller) {
                    controller.enqueue(new Uint8Array([0x49, 0x44, 0x33]));
                    controller.close();
                  },
                }),
                size: 3,
                httpMetadata: { contentType: 'audio/mpeg' },
                arrayBuffer: async () => new Uint8Array([0x49, 0x44, 0x33]).buffer,
                text: async () => 'ID3',
              }
            : null,
        delete: async () => {},
      },
    },
    { waitUntil: () => {}, passThroughOnException: () => {} },
  );
  assert.equal(r2StreamRes.status, 200);
  assert.equal(r2StreamRes.headers.get('content-type'), 'audio/mpeg');

  // 6. Media URL Normalization & Vision / Lyrics Endpoints
  console.log('  6. Testing media URL normalization, Vision GET & Lyrics refine...');
  assert.equal(
    resolveMediaUrl('https://r2.vhunambi.com/beats/amapiano_1.wav', {
      R2_PUBLIC_BASE_URL: 'https://pub-123.r2.dev',
    }),
    'https://pub-123.r2.dev/beats/amapiano_1.wav',
  );

  const visionGenRes = await app.fetch(
    new Request('http://localhost/v1/vision/generate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        genre: 'Amapiano',
        language: 've',
        mood: 'Euphoric',
        lyricsSnippet: 'Ndi matsheloni',
      }),
    }),
  );
  assert.equal(visionGenRes.status, 201);
  const visionGenJson = (await visionGenRes.json()) as { jobId: string };
  const visionPollRes = await app.fetch(
    new Request(`http://localhost/v1/vision/${visionGenJson.jobId}`),
  );
  assert.equal(visionPollRes.status, 200);

  const refineRes = await app.fetch(
    new Request('http://localhost/v1/lyrics/refine', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        currentLyrics: '[VERSE 1]\nNdi matsheloni Venda',
        refinementInstruction: 'Add warmth and joy',
        idiomToInsert: 'Ndi matsheloni!',
        genre: 'Amapiano',
        language: 've',
      }),
    }),
  );
  assert.equal(refineRes.status, 200);
  const refineJson = (await refineRes.json()) as {
    rawLyrics: string;
    stanzas: unknown[];
  };
  assert.ok(refineJson.rawLyrics.length > 0);
  assert.ok(refineJson.stanzas.length > 0);

  console.log('✅ Phase 62 Hybrid Cloud Stack Topology Tests Passed 100%!');
}

testPhase62HybridCloudTopology().catch((err) => {
  console.error('❌ Phase 62 test failed:', err);
  process.exit(1);
});

