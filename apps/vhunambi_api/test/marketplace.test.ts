import { strict as assert } from 'node:assert';
import { app } from '../src/server.js';
import { getCreatorWallet } from '../src/modules/social/social_service.js';

async function testMarketplaceApi(): Promise<void> {
  console.log('🧪 Running Phase 28 Beats Marketplace & Royalty Ledger Tests...');

  // 1. GET /api/marketplace/beats (Catalog Feed)
  console.log('  1. Testing GET /api/marketplace/beats (Catalog Feed)...');
  const feedRes = await app.fetch(
    new Request('http://localhost/api/marketplace/beats'),
  );
  assert.equal(feedRes.status, 200);
  const feedData = (await feedRes.json()) as {
    beats: Array<{ id: string; title: string; genre: string; priceCoins: number }>;
    total: number;
    hasMore: boolean;
  };
  assert.ok(feedData.beats.length >= 6, 'Should contain at least 6 seeded beats');
  assert.equal(feedData.total >= 6, true);
  console.log('     ✅ Catalog feed returns seeded beats');

  // 2. Query Filtering (Genre, BPM, Search, MaxPrice)
  console.log('  2. Testing multi-dimensional filtering...');
  const amapianoRes = await app.fetch(
    new Request('http://localhost/api/marketplace/beats?genre=Amapiano'),
  );
  const amapianoData = (await amapianoRes.json()) as { beats: Array<{ genre: string }> };
  assert.ok(amapianoData.beats.every((b) => b.genre === 'Amapiano'));

  const searchRes = await app.fetch(
    new Request('http://localhost/api/marketplace/beats?search=Quantum'),
  );
  const searchData = (await searchRes.json()) as { beats: Array<{ title: string }> };
  assert.equal(searchData.beats.length, 1);
  assert.ok(searchData.beats[0]?.title.includes('Quantum'));

  const bpmRes = await app.fetch(
    new Request('http://localhost/api/marketplace/beats?minBpm=120&maxBpm=130'),
  );
  const bpmData = (await bpmRes.json()) as { beats: Array<{ bpm: number }> };
  assert.ok(bpmData.beats.every((b) => b.bpm >= 120 && b.bpm <= 130));
  console.log('     ✅ Filtering by genre, search, and BPM passed');

  // 3. GET /api/marketplace/beats/:id
  console.log('  3. Testing GET /api/marketplace/beats/:id...');
  const singleRes = await app.fetch(
    new Request('http://localhost/api/marketplace/beats/beat_seed_001'),
  );
  assert.equal(singleRes.status, 200);
  const singleBeat = (await singleRes.json()) as { id: string; title: string };
  assert.equal(singleBeat.id, 'beat_seed_001');
  assert.equal(singleBeat.title, 'Soweto Log-Drum VIP');
  console.log('     ✅ GET single beat passed');

  // 4. POST /api/marketplace/beats (Producer Publishing)
  console.log('  4. Testing POST /api/marketplace/beats (Producer Publishing)...');
  const newBeatPayload = {
    id: 'beat_custom_producer_99',
    producerId: 'creator_test_producer',
    producerHandle: '@producer_dj',
    producerName: 'DJ Producer Test',
    title: 'Polokwane Bacardi Fire',
    genre: 'Bacardi',
    bpm: 125,
    musicalKey: 'A Minor',
    tags: ['Bacardi', 'Pretoria', 'Percussion'],
    priceCoins: 55,
    priceZar: 50.0,
    previewAudioUrl: 'https://r2.vhunambi.com/beats/polokwane_fire.mp3',
    stemPackage: {
      masterAudioUrl: 'https://r2.vhunambi.com/beats/polokwane_fire.mp3',
      drumsUrl: 'https://r2.vhunambi.com/beats/stems/polokwane_drums.wav',
    },
  };

  const publishRes = await app.fetch(
    new Request('http://localhost/api/marketplace/beats', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(newBeatPayload),
    }),
  );
  assert.equal(publishRes.status, 201);
  const publishedBeat = (await publishRes.json()) as { id: string; title: string };
  assert.equal(publishedBeat.id, 'beat_custom_producer_99');
  assert.equal(publishedBeat.title, 'Polokwane Bacardi Fire');
  console.log('     ✅ Producer beat publishing passed');

  // 5. POST /api/marketplace/beats/:id/license (Atomic Purchase & 85% Royalty Routing)
  console.log('  5. Testing atomic license purchase & 85% wallet royalty crediting...');
  const initialWallet = getCreatorWallet('creator_test_producer');
  const initialBalanceZar = initialWallet.balanceZar;

  const licensePayload = {
    buyerId: 'buyer_artist_123',
    buyerHandle: '@mufasa_artist',
    tier: 'stems_trackout',
    paymentMethod: 'coins',
  };

  const licenseRes = await app.fetch(
    new Request(
      'http://localhost/api/marketplace/beats/beat_custom_producer_99/license',
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(licensePayload),
      },
    ),
  );
  assert.equal(licenseRes.status, 201);
  const licenseData = (await licenseRes.json()) as {
    certificate: {
      certificateId: string;
      licenseHash: string;
      tier: string;
      amountPaidZar: number;
      producerRoyaltyZar: number;
      buyerHandle: string;
    };
    beat: { salesCount: number };
  };

  assert.ok(licenseData.certificate.certificateId.startsWith('CERT-VHB-'));
  assert.ok(licenseData.certificate.licenseHash.length === 64, 'SHA-256 hex hash');
  assert.equal(licenseData.certificate.tier, 'stems_trackout');
  assert.equal(licenseData.beat.salesCount, 1);

  // Verify 85% royalty split in producer's wallet
  const updatedWallet = getCreatorWallet('creator_test_producer');
  const expectedRoyaltyZar = Math.round(50.0 * 3 * 0.85 * 100) / 100; // 150 * 0.85 = 127.5
  assert.equal(
    updatedWallet.balanceZar,
    initialBalanceZar + expectedRoyaltyZar,
    'Seller wallet must receive 85% of transaction ZAR value',
  );
  assert.ok(
    updatedWallet.recentTransactions.some((tx) =>
      tx.message.includes('Polokwane Bacardi Fire'),
    ),
    'Transaction ledger must record beat sale attribution',
  );
  console.log('     ✅ Atomic licensing & 85% wallet royalty routing verified');

  // 6. GET /api/marketplace/licenses/:buyerId
  console.log('  6. Testing GET /api/marketplace/licenses/:buyerId...');
  const licensesRes = await app.fetch(
    new Request('http://localhost/api/marketplace/licenses/buyer_artist_123'),
  );
  assert.equal(licensesRes.status, 200);
  const licensesData = (await licensesRes.json()) as {
    buyerId: string;
    certificates: Array<{ beatTitle: string }>;
  };
  assert.equal(licensesData.buyerId, 'buyer_artist_123');
  assert.equal(licensesData.certificates.length, 1);
  assert.equal(
    licensesData.certificates[0]?.beatTitle,
    'Polokwane Bacardi Fire',
  );
  console.log('     ✅ Buyer licenses retrieval passed');

  // 7. DELETE /api/marketplace/beats/:id (Unpublish)
  console.log('  7. Testing DELETE /api/marketplace/beats/:id (Unpublish)...');
  const deleteRes = await app.fetch(
    new Request(
      'http://localhost/api/marketplace/beats/beat_custom_producer_99',
      { method: 'DELETE' },
    ),
  );
  assert.equal(deleteRes.status, 200);

  const reGetRes = await app.fetch(
    new Request(
      'http://localhost/api/marketplace/beats/beat_custom_producer_99',
    ),
  );
  assert.equal(reGetRes.status, 404);
  console.log('     ✅ Beat unpublishing passed');

  console.log('🎉 ALL PHASE 28 MARKETPLACE & ROYALTY TESTS PASSED!\n');
}

testMarketplaceApi().catch((err) => {
  console.error('❌ Marketplace test failed:', err);
  process.exit(1);
});

