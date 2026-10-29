import assert from 'node:assert';
import { Hono } from 'hono';
import {
  STARTER_MELODY_PATTERNS,
  filterMelodyPresets,
  resolveScaleFrequencyHz,
  extractMelodyPatternTransients,
  renderMelodyReferencePayload,
} from '../src/modules/melody/melody_presets.js';
import { compileMasterMediaObjectManifest } from '../src/modules/dna/dna_compiler.js';
import { StemMasteringRecipeSchema } from '../src/modules/mastering/mastering_types.js';
import { melodyRoutes } from '../src/routes/melody_routes.js';
import { generationRoutes } from '../src/routes/generation_routes.js';

async function runMelodySketchpadTests() {
  console.log('🧪 Running Phase 27 Melody, Chord & Log-Drum Sketchpad Backend Tests...');

  // 1. Starter Catalog Integrity (6 Iconic African Patterns)
  console.log('  1. Testing 6 Iconic African Starter Melody & Log-Drum Patterns...');
  assert.strictEqual(STARTER_MELODY_PATTERNS.length, 6);
  const presetIds = STARTER_MELODY_PATTERNS.map((p) => p.id);
  assert.ok(presetIds.includes('kabza_logdrum_bounce'));
  assert.ok(presetIds.includes('private_school_rhodes_lush'));
  assert.ok(presetIds.includes('maskandi_ukupika_turnaround'));
  assert.ok(presetIds.includes('venda_domba_mbira'));
  assert.ok(presetIds.includes('gqom_dark_sub_pulse'));
  assert.ok(presetIds.includes('afro_house_marimba_arp'));

  const logDrumOnly = filterMelodyPresets({ instrument: 'amapiano_log_drum' });
  assert.strictEqual(logDrumOnly.length, 2);

  // 2. Scale-Locked Pitch Math
  console.log('  2. Testing resolveScaleFrequencyHz() Scale-Locked Pitch Ladder...');
  const row0 = resolveScaleFrequencyHz('F#m', 'minor_pentatonic', 0, 'amapiano_log_drum');
  const row5 = resolveScaleFrequencyHz('F#m', 'minor_pentatonic', 5, 'amapiano_log_drum'); // +12 semitones = 1 octave
  assert.ok(row0 > 40 && row0 < 100, `Expected F#1/F#2 sub-bass range, got ${row0}Hz`);
  assert.ok(
    Math.abs(row5 / row0 - 2.0) < 0.01,
    `Row 5 (+12 semitones) must be exactly 2x frequency of Row 0 (${row5} vs ${row0})`,
  );

  // 3. WAV Reference Synthesis & Transient Extraction
  console.log('  3. Testing renderMelodyReferencePayload() & RIFF/WAVE header...');
  const kabza = STARTER_MELODY_PATTERNS[0];
  const rendered = renderMelodyReferencePayload(kabza);
  assert.strictEqual(rendered.patternId, 'kabza_logdrum_bounce');
  assert.ok(rendered.r2ReferenceUrl.endsWith('.wav'));

  const wavBuf = Buffer.from(rendered.wavBase64Preview, 'base64');
  assert.strictEqual(wavBuf.subarray(0, 4).toString('ascii'), 'RIFF');
  assert.strictEqual(wavBuf.subarray(8, 12).toString('ascii'), 'WAVE');
  assert.ok(rendered.transientEvents.length >= kabza.notes.length);
  assert.ok(rendered.transientEvents.every((ev) => ev.type === 'log_drum_drop'));

  // 4. Phase 23 MMO Transient Injection Synergy
  console.log('  4. Testing compileMasterMediaObjectManifest() with attached melodyPattern...');
  const mmoWithoutSketch = compileMasterMediaObjectManifest({
    id: 'trk_no_sketch',
    title: 'Plain Track',
    genre: 'Amapiano',
    language: 've',
    durationSec: 12,
  });
  const mmoWithSketch = compileMasterMediaObjectManifest({
    id: 'trk_with_sketch',
    title: 'Sketchpad Track',
    genre: 'Amapiano',
    language: 've',
    durationSec: 12,
    melodyPattern: kabza,
  });
  assert.ok(
    mmoWithSketch.modulationBus.transientEvents.length >
    mmoWithoutSketch.modulationBus.transientEvents.length,
    'Attached melodyPattern must inject step transients into MMO modulationBus',
  );

  // 5. Phase 25 Mastering Recipe sketchpadLayerMix Synergy
  console.log('  5. Testing StemMasteringRecipeSchema sketchpadLayerMix field...');
  const parsedRecipe = StemMasteringRecipeSchema.parse({
    presetId: 'amapiano_club_knock',
    targetLufs: -9.5,
    sketchpadLayerMix: 0.35,
    vocals: {
      flavor: 'studio_clean',
      neuralDenoiseStrength: 0.85,
      neuralDereverbStrength: 0.65,
      compressionAmount: 0.65,
      eq: { highpassHz: 95, lowGainDb: 0.5, midGainDb: 1.5, midFreqHz: 2400, airGainDb: 3.5 },
    },
    bass: {
      flavor: 'heavy_wooden_knock',
      subHarmonicMix: 0.55,
      knockDriveDb: 4.5,
      sidechainDuckDb: -3.5,
      eq: { highpassHz: 30, lowGainDb: 3.5, midGainDb: 3.0, midFreqHz: 165, airGainDb: 1.0 },
    },
    drums: {
      flavor: 'crisp_shakers',
      transientAttackSnap: 0.45,
      parallelCrushMix: 0.3,
      eq: { highpassHz: 45, lowGainDb: 1.0, midGainDb: -2.5, midFreqHz: 320, airGainDb: 2.5 },
    },
    melodic: {
      flavor: 'wide_stereo_pocket',
      midVocalPocketCutDb: -2.5,
      stereoWidthBoost: 0.35,
      eq: { highpassHz: 110, lowGainDb: -1.5, midGainDb: -2.0, midFreqHz: 1800, airGainDb: 2.0 },
    },
  });
  assert.strictEqual(parsedRecipe.sketchpadLayerMix, 0.35);

  // 6. Hono HTTP Routes (/v1/melodies/* & /v1/generations)
  const app = new Hono();
  app.route('/v1/melodies', melodyRoutes);
  app.route('/v1/generations', generationRoutes);

  console.log('  6. Testing GET /v1/melodies/presets & POST /v1/melodies/render-reference...');
  const resPresets = await app.fetch(
    new Request('http://localhost/v1/melodies/presets?genre=Maskandi'),
  );
  assert.strictEqual(resPresets.status, 200);
  const presetsJson = (await resPresets.json()) as any;
  assert.strictEqual(presetsJson.totalCount, 6);
  assert.strictEqual(presetsJson.filteredCount, 1);
  assert.strictEqual(presetsJson.presets[0].id, 'maskandi_ukupika_turnaround');

  const resRender = await app.fetch(
    new Request('http://localhost/v1/melodies/render-reference', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(kabza),
    }),
  );
  assert.strictEqual(resRender.status, 200);
  const renderJson = (await resRender.json()) as any;
  assert.strictEqual(renderJson.success, true);
  assert.strictEqual(renderJson.patternId, 'kabza_logdrum_bounce');

  console.log('  7. Testing POST /v1/generations with melodyPattern conditioning...');
  const resGen = await app.fetch(
    new Request('http://localhost/v1/generations', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        trackTitle: 'Soweto Sketchpad Bounce',
        genre: 'Amapiano',
        language: 've',
        durationSec: 120,
        melodyPattern: kabza,
      }),
    }),
  );
  assert.strictEqual(resGen.status, 201);
  const genJson = (await resGen.json()) as any;
  assert.ok(genJson.melodyConditioning);
  assert.strictEqual(genJson.melodyConditioning.patternId, 'kabza_logdrum_bounce');
  assert.strictEqual(genJson.melodyConditioning.instrument, 'amapiano_log_drum');

  console.log('✅ All Phase 27 Melody, Chord & Log-Drum Sketchpad Backend Tests Passed!\n');
}

runMelodySketchpadTests().catch((err) => {
  console.error('❌ Phase 27 Melody Sketchpad Test Failure:', err);
  process.exit(1);
});
