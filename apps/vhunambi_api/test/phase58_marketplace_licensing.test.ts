import { strict as assert } from 'node:assert';
import { createHash } from 'node:crypto';
import { app } from '../src/server.js';
import { VhunambiDatabase, vhunambiDb } from '../src/db/vhunambi_db.js';

async function testPhase58MarketplaceLicensing(): Promise<void> {
  console.log('🧪 Running Phase 58 Sovereign Beatstore Licensing & ACID API Tests...');

  // 1. SQLite In-Memory Canonical Hash & ACID Transaction Suite
  console.log('  1. Testing VhunambiDatabase ACID recordBeatLicenseAtomic & hash verification...');
  const db = new VhunambiDatabase(':memory:');
  db.topupWallet('buyer_ac_1', 150.0, 500);

  const issuedAt = '2026-11-09T09:00:00.000Z';
  const masterDigest = createHash('sha256').update('master_wav_bytes').digest('hex');
  const expectedPreimage = `VHUNAMBI_LIC_V2|CERT-VHB-20261109-AAA111|beat_ac_1|prod_ac_1|buyer_ac_1|exclusive_stem|150|45.00|${issuedAt}|${masterDigest}`;
  const expectedHash = createHash('sha256').update(expectedPreimage).digest('hex');

  const computed = db.computeCanonicalLicenseHash({
    certificateId: 'CERT-VHB-20261109-AAA111',
    beatId: 'beat_ac_1',
    producerId: 'prod_ac_1',
    buyerId: 'buyer_ac_1',
    tierSlug: 'exclusive_stem',
    amountPaidCoins: 150,
    amountPaidZar: 45.0,
    issuedAt,
    masterFileSha256: masterDigest,
  });
  assert.equal(computed, expectedHash);

  const atomicRes = db.recordBeatLicenseAtomic({
    certificateId: 'CERT-VHB-20261109-AAA111',
    beatId: 'beat_ac_1',
    beatTitle: 'Limpopo Log Drum Anthem',
    producerId: 'prod_ac_1',
    producerHandle: '@prod_ac_1',
    buyerId: 'buyer_ac_1',
    buyerHandle: '@buyer_ac_1',
    tierSlug: 'exclusive_stem',
    amountPaidCoins: 150,
    amountPaidZar: 45.0,
    producerRoyaltyCoins: 128,
    producerRoyaltyZar: 38.25,
    issuedAt,
    commercialTerms: 'Exclusive worldwide master + stems',
    masterFileSha256: masterDigest,
    isExclusive: true,
    enforceBuyerWallet: true,
    dataJson: {
      certificateId: 'CERT-VHB-20261109-AAA111',
      beatId: 'beat_ac_1',
      tier: 'exclusive_stem',
    },
  });

  assert.equal(atomicRes.status, 'ok');
  assert.equal(atomicRes.licenseHash, expectedHash);
  assert.equal(db.getWallet('buyer_ac_1').balanceCoins, 350);
  assert.equal(db.getWallet('prod_ac_1').balanceCoins, 128);

  const verified = db.verifyBeatLicense('CERT-VHB-20261109-AAA111');
  assert.equal(verified.found, true);
  assert.equal(verified.valid, true);
  assert.equal(db.verifyBeatLicense('CERT-MISSING').found, false);

  // Exclusive conflict check in DB
  db.topupWallet('buyer_ac_2', 300.0, 1000);
  const conflictRes = db.recordBeatLicenseAtomic({
    certificateId: 'CERT-VHB-20261109-BBB222',
    beatId: 'beat_ac_1',
    beatTitle: 'Limpopo Log Drum Anthem',
    producerId: 'prod_ac_1',
    producerHandle: '@prod_ac_1',
    buyerId: 'buyer_ac_2',
    buyerHandle: '@buyer_ac_2',
    tierSlug: 'basic_lease',
    amountPaidCoins: 25,
    amountPaidZar: 7.5,
    producerRoyaltyCoins: 21,
    producerRoyaltyZar: 6.38,
    issuedAt,
    commercialTerms: 'Basic MP3 lease',
    masterFileSha256: masterDigest,
    isExclusive: false,
    enforceBuyerWallet: true,
    dataJson: { certificateId: 'CERT-VHB-20261109-BBB222' },
  });
  assert.equal(conflictRes.status, 'exclusive_conflict');
  assert.equal(db.getWallet('buyer_ac_2').balanceCoins, 1000);

  // Insufficient funds guard in DB
  db.topupWallet('buyer_low', 3.0, 10);
  const lowFundsRes = db.recordBeatLicenseAtomic({
    certificateId: 'CERT-VHB-20261109-CCC333',
    beatId: 'beat_ac_open',
    beatTitle: 'Open Beat',
    producerId: 'prod_ac_2',
    producerHandle: '@prod_ac_2',
    buyerId: 'buyer_low',
    buyerHandle: '@buyer_low',
    tierSlug: 'stems_trackout',
    amountPaidCoins: 75,
    amountPaidZar: 22.5,
    producerRoyaltyCoins: 64,
    producerRoyaltyZar: 19.13,
    issuedAt,
    commercialTerms: 'Premium WAV',
    isExclusive: false,
    enforceBuyerWallet: true,
    dataJson: { certificateId: 'CERT-VHB-20261109-CCC333' },
  });
  assert.equal(lowFundsRes.status, 'insufficient_funds');
  assert.equal(db.getWallet('buyer_low').balanceCoins, 10);

  // Sync batch ingestion (must operate safely inside SAVEPOINT without nested BEGIN error)
  const syncRes = db.applyMutationsBatch([
    {
      idempotencyKey: 'lic_CERT-SYNC-1',
      entityType: 'beat_license',
      action: 'purchase',
      createdAt: issuedAt,
      payload: {
        certificateId: 'CERT-SYNC-1',
        beatId: 'beat_sync_1',
        beatTitle: 'Venda Groove',
        producerId: 'prod_sync_1',
        producerHandle: '@prod_sync',
        buyerId: 'buyer_sync_1',
        buyerHandle: '@buyer_sync',
        tier: 'basic_lease',
        amountPaidCoins: 25,
        amountPaidZar: 7.5,
        issuedAtIso8601: issuedAt,
        commercialTerms: 'Basic Lease',
        masterFileSha256: masterDigest,
        isExclusiveRights: false,
      },
    },
  ]);
  assert.equal(syncRes.applied.length, 1);
  assert.equal(syncRes.failed.length, 0);
  assert.equal(db.verifyBeatLicense('CERT-SYNC-1').valid, true);
  console.log('     ✅ SQLite ACID checkout, exclusive lock, low-funds guard & savepoint sync verified');

  // 2. HTTP Route Tests: 201 -> verify -> 409 Conflict -> 402 Insufficient Funds
  console.log('  2. Testing HTTP /api/marketplace exclusivity (409), verify & 402 routes...');
  const suffix = Date.now();
  const beatExclId = `beat_p58_excl_${suffix}`;
  const beatOpenId = `beat_p58_open_${suffix}`;
  const buyerRichId = `buyer_rich_${suffix}`;
  const buyerPoorId = `buyer_poor_${suffix}`;

  vhunambiDb.topupWallet(buyerRichId, 300.0, 1000);
  vhunambiDb.topupWallet(buyerPoorId, 3.0, 10);

  for (const [id, title] of [
    [beatExclId, 'Phase 58 Exclusive Beat'],
    [beatOpenId, 'Phase 58 Open Beat'],
  ] as const) {
    const createRes = await app.fetch(
      new Request('http://localhost/api/marketplace/beats', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          id,
          producerId: `prod_${suffix}`,
          producerHandle: `@prod_${suffix}`,
          producerName: 'Phase 58 Producer',
          title,
          genre: 'Amapiano',
          bpm: 112,
          musicalKey: 'F# Minor',
          priceCoins: 25,
          priceZar: 7.5,
          previewAudioUrl: `https://r2.vhunambi.com/beats/${id}.mp3`,
        }),
      }),
    );
    assert.equal(createRes.status, 201);
  }

  // Purchase exclusive stem tier
  const firstPurchase = await app.fetch(
    new Request(`http://localhost/api/marketplace/beats/${beatExclId}/license`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        buyerId: buyerRichId,
        buyerHandle: '@rich_buyer',
        tier: 'exclusive_stem',
      }),
    }),
  );
  assert.equal(firstPurchase.status, 201);
  const purchaseJson = (await firstPurchase.json()) as {
    certificate: {
      certificateId: string;
      licenseHash: string;
      amountPaidCoins: number;
      producerRoyaltyCoins: number;
    };
    beat: { isExclusiveSold: boolean };
  };
  assert.equal(purchaseJson.certificate.amountPaidCoins, 150);
  assert.equal(purchaseJson.certificate.producerRoyaltyCoins, 128);
  assert.equal(purchaseJson.beat.isExclusiveSold, true);

  // Verify endpoint check
  const verifyRes = await app.fetch(
    new Request(
      `http://localhost/api/marketplace/licenses/verify/${purchaseJson.certificate.certificateId}`,
    ),
  );
  assert.equal(verifyRes.status, 200);
  const verifyJson = (await verifyRes.json()) as { found: boolean; valid: boolean };
  assert.equal(verifyJson.found, true);
  assert.equal(verifyJson.valid, true);

  // Unknown cert -> 404
  const verifyMissing = await app.fetch(
    new Request('http://localhost/api/marketplace/licenses/verify/CERT-DOES-NOT-EXIST'),
  );
  assert.equal(verifyMissing.status, 404);

  // Duplicate license on exclusively sold beat -> 409 Conflict
  const conflictHttp = await app.fetch(
    new Request(`http://localhost/api/marketplace/beats/${beatExclId}/license`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        buyerId: buyerRichId,
        buyerHandle: '@rich_buyer',
        tier: 'basic_lease',
      }),
    }),
  );
  assert.equal(conflictHttp.status, 409);

  // Exclusively sold beat removed from public marketplace feed
  const feedRes = await app.fetch(
    new Request('http://localhost/api/marketplace/beats?limit=50'),
  );
  assert.equal(feedRes.status, 200);
  const feedJson = (await feedRes.json()) as { beats: Array<{ id: string }> };
  assert.equal(
    feedJson.beats.some((b) => b.id === beatExclId),
    false,
    'Exclusively sold beat must not appear in public feed',
  );

  // Insufficient buyer Coins -> 402 Payment Required
  const lowFundsHttp = await app.fetch(
    new Request(`http://localhost/api/marketplace/beats/${beatOpenId}/license`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        buyerId: buyerPoorId,
        buyerHandle: '@poor_buyer',
        tier: 'stems_trackout',
      }),
    }),
  );
  assert.equal(lowFundsHttp.status, 402);

  console.log('     ✅ HTTP 201 / verify 200 & 404 / 409 Conflict / 402 Insufficient Funds verified');
  console.log('🎉 ALL PHASE 58 BACKEND TESTS PASSED!\n');
}

testPhase58MarketplaceLicensing().catch((err) => {
  console.error('❌ Phase 58 backend test failed:', err);
  process.exit(1);
});

