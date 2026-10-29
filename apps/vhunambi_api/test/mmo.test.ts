import assert from 'node:assert';
import crypto from 'node:crypto';
import {
  compileMasterMediaObjectManifest,
  clampSliceBounds,
} from '../src/modules/dna/dna_compiler.js';
import { createJob, getJob } from '../src/modules/jobs/job_store.js';
import { generationRoutes } from '../src/routes/generation_routes.js';
import { webhookRoutes } from '../src/routes/webhook_routes.js';
import { env } from '../src/config/env.js';

async function runMmoTests() {
  console.log('🧪 Running Phase 23 Master Media Object (MMO v2.0) Tests...');

  // Test 1: Deterministic Mathematical Manifest Compilation (Amapiano, 112 BPM, 180s)
  console.log('  1. Testing compileMasterMediaObjectManifest (Amapiano, 180s)...');
  const manifest = compileMasterMediaObjectManifest({
    id: 'test_mmo_track_01',
    title: 'Amapiano Quantum Log Drum',
    genre: 'Amapiano',
    language: 've',
    bpm: 112,
    durationSec: 180,
    alignment: [
      { word: 'Woza', start: 10.0, end: 10.5, stanzaIndex: 0 },
      { word: 'Vhunambi', start: 10.6, end: 11.2, stanzaIndex: 0 },
      { word: 'Yebo', start: 35.0, end: 35.4, stanzaIndex: 1 },
    ],
  });

  assert.strictEqual(manifest.schemaVersion, '2.0', 'schemaVersion must be 2.0');
  assert.strictEqual(manifest.provenance, 'synthesized', 'provenance must default to synthesized');
  assert.strictEqual(manifest.musical.bpm, 112);
  assert.strictEqual(manifest.modulationBus.sampleRateHz, 60);

  const expectedFrames = 180 * 60; // 10,800 frames
  assert.strictEqual(
    manifest.modulationBus.frameCount,
    expectedFrames,
    `frameCount must be ${expectedFrames}`,
  );

  // Test 2: Quantized Uint8 Base64 Curve Payload Size & Integrity (REQ-MMO-03)
  console.log('  2. Testing 60 Hz Quantized Uint8 Base64 curves (<= 15 KB)...');
  const curves = manifest.modulationBus.encodedCurvesBase64;
  const curveKeys: Array<keyof typeof curves> = [
    'masterRms',
    'vocals',
    'drums',
    'bass',
    'melodic',
  ];

  for (const key of curveKeys) {
    const b64 = curves[key];
    assert.ok(typeof b64 === 'string', `${key} curve must be a Base64 string`);

    // Verify payload size is <= 15 KB (15 * 1024 bytes = 15,360 characters)
    const sizeBytes = Buffer.byteLength(b64, 'utf8');
    assert.ok(
      sizeBytes <= 15360,
      `${key} Base64 string size (${sizeBytes} bytes) must be <= 15 KB (15,360 bytes)`,
    );

    // Verify exact frame decoding
    const decodedBuffer = Buffer.from(b64, 'base64');
    assert.strictEqual(
      decodedBuffer.length,
      expectedFrames,
      `${key} decoded buffer must have exactly ${expectedFrames} Uint8 samples`,
    );

    // Verify all bytes are 0..255
    for (let i = 0; i < decodedBuffer.length; i += 100) {
      assert.ok(
        decodedBuffer[i] >= 0 && decodedBuffer[i] <= 255,
        `Sample at ${i} must be within Uint8 range`,
      );
    }
  }
  console.log('     ✅ All 5 curves <= 15 KB and decode to 10,800 Uint8 samples');

  // Test 3: Sub-Bass Baseline Floor in The Drop Section
  console.log('  3. Testing sub-bass baseline floor (18%) during The Drop...');
  const dropSection = manifest.structure.sections.find((s) => s.name === 'The Drop');
  assert.ok(dropSection, 'The Drop section must exist');

  const bassBuffer = Buffer.from(curves.bass, 'base64');
  const dropStartFrame = Math.floor((dropSection.startMs * 60) / 1000);
  const dropEndFrame = Math.floor((dropSection.endMs * 60) / 1000);

  // Inspect frames in the drop section
  let minDropBassByte = 255;
  for (let f = dropStartFrame + 5; f < dropEndFrame - 5; f += 20) {
    if (bassBuffer[f] < minDropBassByte) minDropBassByte = bassBuffer[f];
  }
  // 18% floor of 255 is ~45.9
  assert.ok(
    minDropBassByte >= 45,
    `Bass floor in The Drop (${minDropBassByte}) must be >= 45 (~18% sub-bass drone floor)`,
  );
  console.log(`     ✅ Sustained sub-bass floor in The Drop verified (min: ${minDropBassByte}/255)`);

  // Test 4: Role-Stratified 8-Pad MPC Kit Manifest (REQ-MMO-05)
  console.log('  4. Testing 8-pad role-stratified MPC kit manifest...');
  assert.strictEqual(manifest.mpcKitPads.length, 8, 'Must have exactly 8 MPC pads');

  const expectedRoles = [
    'drums',
    'drums',
    'bass',
    'bass',
    'melodic',
    'melodic',
    'vocals',
    'vocals',
  ];

  manifest.mpcKitPads.forEach((pad, idx) => {
    assert.strictEqual(pad.padIndex, idx, `Pad index must be ${idx}`);
    assert.strictEqual(pad.sourceStem, expectedRoles[idx], `Pad ${idx} stem must be ${expectedRoles[idx]}`);
    assert.ok(pad.startSec >= 0, `Pad ${idx} startSec must be >= 0`);
    assert.ok(pad.endSec > pad.startSec, `Pad ${idx} endSec must be > startSec`);
    assert.ok(
      pad.endSec <= manifest.musical.durationSec,
      `Pad ${idx} endSec must be <= track duration`,
    );
    assert.ok(pad.peakIntensity > 0 && pad.peakIntensity <= 1.0);
  });
  console.log('     ✅ 8-Pad role stratification verified (Drums x2, Bass x2, Melodic x2, Vocals x2)');

  // Test 5: clampSliceBounds short track protection
  console.log('  5. Testing clampSliceBounds guard on short 15s track...');
  const clamped = clampSliceBounds(15 * 2.14, 2.14, 15.0);
  assert.ok(clamped.startSec >= 0, 'startSec must be >= 0');
  assert.ok(clamped.endSec <= 15.0, 'endSec must not exceed total track duration (15.0s)');
  console.log(`     ✅ clampSliceBounds safely wraps to ${clamped.startSec}s..${clamped.endSec}s`);

  // Test 6: Chronological Transient Events (REQ-MMO-04)
  console.log('  6. Testing transient events chronology and variety...');
  const transients = manifest.modulationBus.transientEvents;
  assert.ok(transients.length > 0, 'Transient events must not be empty');

  // Verify chronological order
  for (let i = 1; i < transients.length; i++) {
    assert.ok(
      transients[i].timestampMs >= transients[i - 1].timestampMs,
      'Transients must be strictly ordered by timestampMs',
    );
  }
  const eventTypes = new Set(transients.map((e) => e.type));
  assert.ok(eventTypes.has('kick'), 'Must include kick transients');
  assert.ok(eventTypes.has('log_drum_drop'), 'Must include log_drum_drop transients');
  assert.ok(eventTypes.has('snare_clap'), 'Must include snare_clap transients');
  assert.ok(eventTypes.has('section_change'), 'Must include section_change transients');
  console.log(`     ✅ ${transients.length} sorted transient events verified across all stems`);

  // Test 7: HTTP Route GET /v1/generations/:id/manifest (REQ-MMO-07)
  console.log('  7. Testing GET /v1/generations/:id/manifest endpoint...');
  const genId = `gen_mmo_api_${Date.now()}`;
  createJob({
    generationId: genId,
    trackTitle: 'API Route Test',
    genre: 'Gqom',
    language: 'zu',
  });

  // 7a: Success 200
  const res200 = await generationRoutes.request(`/${genId}/manifest`);
  assert.strictEqual(res200.status, 200, 'Existing generation manifest must return 200');
  const body200 = (await res200.json()) as any;
  assert.strictEqual(body200.schemaVersion, '2.0');
  assert.strictEqual(body200.genre, 'Gqom');
  assert.strictEqual(body200.provenance, 'synthesized');
  assert.strictEqual(body200.mpcKitPads.length, 8);

  // 7b: Not Found 404
  const res404 = await generationRoutes.request(`/non_existent_id_999/manifest`);
  assert.strictEqual(res404.status, 404, 'Unknown generation must return 404');
  const body404 = (await res404.json()) as any;
  assert.strictEqual(body404.error, 'NOT_FOUND');
  console.log('     ✅ GET /v1/generations/:id/manifest returns 200 with manifest and 404 on unknown ID');

  // Test 8: Webhook callback with manifest_url (REQ-MMO-08)
  console.log('  8. Testing webhook callback ingesting manifest_url...');
  const hookGenId = `hook_mmo_${Date.now()}`;
  createJob({
    generationId: hookGenId,
    trackTitle: 'Hook MMO Test',
    genre: 'Maskandi',
    language: 'zu',
  });

  const originalSecret = env.ZR_WEBHOOK_SECRET;
  try {
    env.ZR_WEBHOOK_SECRET = 'mmo_test_secret_key';
    const payload = JSON.stringify({
      job_id: `vhunambi_${hookGenId}`,
      status: 'completed',
      audio_url: 'https://r2.vhunambi.com/audio/master.mp3',
      stems_zip_url: 'https://r2.vhunambi.com/audio/stems.zip',
      manifest_url: 'https://r2.vhunambi.com/manifests/measured_mmo.json',
    });

    const sig = crypto.createHmac('sha256', env.ZR_WEBHOOK_SECRET).update(payload).digest('hex');

    const hookRes = await webhookRoutes.request('/ace-step', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-zrs-signature': sig,
      },
      body: payload,
    });
    assert.strictEqual(hookRes.status, 200);

    const updatedJob = getJob(hookGenId);
    assert.strictEqual(
      updatedJob?.manifestUrl,
      'https://r2.vhunambi.com/manifests/measured_mmo.json',
      'manifestUrl must be attached to completed job',
    );

    // Verify GET /manifest reports provenance: measured when manifestUrl is present
    const measuredRes = await generationRoutes.request(`/${hookGenId}/manifest`);
    assert.strictEqual(measuredRes.status, 200);
    const measuredBody = (await measuredRes.json()) as any;
    assert.strictEqual(
      measuredBody.provenance,
      'measured',
      'Manifest provenance must be measured when manifestUrl is present',
    );
    console.log('     ✅ Webhook attaches manifest_url and routes report provenance: measured');

    // Test 9: Webhook callback with isolated stem_urls (Tier 2 Cloud GPU Parity)
    console.log('  9. Testing webhook callback with isolated stem_urls (Tier 2)...');
    const tier2GenId = `hook_tier2_${Date.now()}`;
    createJob({
      generationId: tier2GenId,
      trackTitle: 'Tier 2 4-Stem Test',
      genre: 'Amapiano',
      language: 've',
    });

    const stemPayload = JSON.stringify({
      job_id: `vhunambi_${tier2GenId}`,
      status: 'completed',
      audio_url: 'https://r2.vhunambi.com/audio/master.mp3',
      stems_zip_url: 'https://r2.vhunambi.com/audio/stems.zip',
      manifest_url: 'https://r2.vhunambi.com/manifests/tier2_measured_mmo.json',
      stem_urls: {
        vocals: 'https://r2.vhunambi.com/audio/vocals.mp3',
        drums: 'https://r2.vhunambi.com/audio/drums.mp3',
        bass: 'https://r2.vhunambi.com/audio/bass.mp3',
        melodic: 'https://r2.vhunambi.com/audio/melodic.mp3',
      },
    });

    const stemSig = crypto.createHmac('sha256', env.ZR_WEBHOOK_SECRET).update(stemPayload).digest('hex');

    const stemHookRes = await webhookRoutes.request('/ace-step', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-zrs-signature': stemSig,
      },
      body: stemPayload,
    });
    assert.strictEqual(stemHookRes.status, 200);

    const tier2Job = getJob(tier2GenId);
    assert.strictEqual(tier2Job?.stemUrls?.vocals, 'https://r2.vhunambi.com/audio/vocals.mp3');
    assert.strictEqual(tier2Job?.stemUrls?.drums, 'https://r2.vhunambi.com/audio/drums.mp3');

    // Verify GET /:id returns stemUrls
    const getJobRes = await generationRoutes.request(`/${tier2GenId}`);
    assert.strictEqual(getJobRes.status, 200);
    const getJobBody = (await getJobRes.json()) as any;
    assert.strictEqual(getJobBody.stemUrls?.bass, 'https://r2.vhunambi.com/audio/bass.mp3');

    // Verify GET /:id/manifest embeds stemUrls in assets
    const manifestRes = await generationRoutes.request(`/${tier2GenId}/manifest`);
    assert.strictEqual(manifestRes.status, 200);
    const manifestBody = (await manifestRes.json()) as any;
    assert.strictEqual(manifestBody.assets?.stemUrls?.melodic, 'https://r2.vhunambi.com/audio/melodic.mp3');
    console.log('     ✅ Tier 2 isolated stem_urls ingested and wired into manifest assets');
  } finally {
    env.ZR_WEBHOOK_SECRET = originalSecret;
  }

  console.log('\n🎉 ALL PHASE 23 & TIER 2 BACKEND MMO TESTS PASSED! Manifest Compiler Verified.\n');
}

runMmoTests().catch((err) => {
  console.error('❌ MMO test failed:', err);
  process.exit(1);
});
