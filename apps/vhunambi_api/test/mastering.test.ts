import assert from 'node:assert';
import { Hono } from 'hono';
import {
  GENRE_MASTER_PRESETS,
  getMasteringPresetForGenre,
  enrichManifestWithMasteringRecipe,
} from '../src/modules/mastering/mastering_presets.js';
import { StemMasteringRecipe } from '../src/modules/mastering/mastering_types.js';
import { compileMasterMediaObjectManifest } from '../src/modules/dna/dna_compiler.js';
import { createJob, completeJob } from '../src/modules/jobs/job_store.js';
import { generationRoutes } from '../src/routes/generation_routes.js';

async function runMasteringTests() {
  console.log('🧪 Running Phase 25 Stem Mastering API & Preset Tests...');

  // 1. Preset Catalog Integrity
  console.log('  1. Testing Genre Master Presets Catalog (6 Regional Presets)...');
  assert.strictEqual(GENRE_MASTER_PRESETS.length, 6, 'Must expose exactly 6 presets');

  const presetIds = GENRE_MASTER_PRESETS.map((p) => p.id);
  assert.ok(presetIds.includes('amapiano_club_knock'));
  assert.ok(presetIds.includes('private_school_warmth'));
  assert.ok(presetIds.includes('gqom_warehouse_sub'));
  assert.ok(presetIds.includes('maskandi_acoustic_clarity'));
  assert.ok(presetIds.includes('afro_house_horizon'));
  assert.ok(presetIds.includes('kwaito_golden_tape'));

  // 2. Genre-Matching Resolver
  console.log('  2. Testing getMasteringPresetForGenre()...');
  assert.strictEqual(getMasteringPresetForGenre('Amapiano').id, 'amapiano_club_knock');
  assert.strictEqual(getMasteringPresetForGenre('Private School Amapiano').id, 'private_school_warmth');
  assert.strictEqual(getMasteringPresetForGenre('Gqom').id, 'gqom_warehouse_sub');
  assert.strictEqual(getMasteringPresetForGenre('Maskandi').id, 'maskandi_acoustic_clarity');
  assert.strictEqual(getMasteringPresetForGenre('Afro House').id, 'afro_house_horizon');
  assert.strictEqual(getMasteringPresetForGenre('Kwaito').id, 'kwaito_golden_tape');

  // 3. Manifest Curve Enrichment & Mastered Asset Wiring
  console.log('  3. Testing enrichManifestWithMasteringRecipe()...');
  const baseManifest = compileMasterMediaObjectManifest({
    id: 'test_master_trk_01',
    title: 'Sunrise Log Drum Master',
    genre: 'Amapiano',
    language: 've',
    durationSec: 10,
  });

  const recipe = getMasteringPresetForGenre('Amapiano').recipe;
  const enriched = enrichManifestWithMasteringRecipe(baseManifest, recipe);

  assert.strictEqual(enriched.provenance, 'measured');
  assert.strictEqual(enriched.assets.masterMp3Url, '/mock-storage/test_master_trk_01_mastered.mp3');
  assert.strictEqual(enriched.assets.masterWavUrl, '/mock-storage/test_master_trk_01_mastered.wav');
  assert.ok(enriched.assets.stemUrls.bass.includes('bass_mastered.wav'));
  assert.ok(enriched.assets.stemUrls.vocals.includes('vocals_mastered.wav'));

  // Verify curves still valid Base64 and decoded buffer length matches frame count
  const bassBuf = Buffer.from(enriched.modulationBus.encodedCurvesBase64.bass, 'base64');
  assert.strictEqual(bassBuf.length, baseManifest.modulationBus.frameCount);

  // 4. API Endpoints via Hono Fetch
  const app = new Hono();
  app.route('/v1/generations', generationRoutes);

  console.log('  4. Testing GET /v1/generations/mastering/presets...');
  const resPresets = await app.fetch(
    new Request('http://localhost/v1/generations/mastering/presets?genre=Amapiano'),
  );
  assert.strictEqual(resPresets.status, 200);
  const presetsJson = (await resPresets.json()) as any;
  assert.strictEqual(presetsJson.recommended.id, 'amapiano_club_knock');
  assert.strictEqual(presetsJson.presets.length, 6);

  console.log('  5. Testing POST /v1/generations/:id/master with seeded track ID...');
  const resMasterSeeded = await app.fetch(
    new Request('http://localhost/v1/generations/trk_seeded_amapiano_01/master', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(recipe),
    }),
  );
  assert.strictEqual(resMasterSeeded.status, 200);
  const masterJson = (await resMasterSeeded.json()) as any;
  assert.strictEqual(masterJson.success, true);
  assert.strictEqual(masterJson.presetId, 'amapiano_club_knock');
  assert.strictEqual(masterJson.targetLufs, -9.5);
  assert.ok(masterJson.masteredMp3Url.includes('mastered.mp3'));
  assert.strictEqual(masterJson.manifest.provenance, 'measured');

  console.log('  6. Testing POST /v1/generations/:id/master with active job store record...');
  const jobId = 'gen_master_test_123';
  createJob({
    generationId: jobId,
    trackTitle: 'Studio Master Test Track',
    genre: 'Gqom',
    language: 'zu',
  });
  completeJob(jobId, {
    masterMp3Url: '/mock-storage/raw.mp3',
    durationSec: 120,
    manifest: compileMasterMediaObjectManifest({
      id: jobId,
      title: 'Studio Master Test Track',
      genre: 'Gqom',
      language: 'zu',
      durationSec: 120,
    }),
  });

  const gqomRecipe = getMasteringPresetForGenre('Gqom').recipe;
  const resMasterJob = await app.fetch(
    new Request(`http://localhost/v1/generations/${jobId}/master`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(gqomRecipe),
    }),
  );
  assert.strictEqual(resMasterJob.status, 200);
  const jobMasterJson = (await resMasterJob.json()) as any;
  assert.strictEqual(jobMasterJson.presetId, 'gqom_warehouse_sub');
  assert.ok(jobMasterJson.manifest.assets.masterMp3Url.includes('mastered.mp3'));

  console.log('  7. Testing POST /v1/generations/:id/master validation & 404 handling...');
  const res404 = await app.fetch(
    new Request('http://localhost/v1/generations/gen_unknown_nonexistent/master', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(recipe),
    }),
  );
  assert.strictEqual(res404.status, 404);

  const res400 = await app.fetch(
    new Request('http://localhost/v1/generations/trk_seeded_amapiano_01/master', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ invalidField: true }),
    }),
  );
  assert.strictEqual(res400.status, 400);

  console.log('✅ All Phase 25 Mastering API & Preset Tests Passed Successfully!\n');
}

runMasteringTests().catch((err) => {
  console.error('❌ Phase 25 Mastering Test Failure:', err);
  process.exit(1);
});

