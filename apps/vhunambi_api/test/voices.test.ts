import assert from 'node:assert';
import { Hono } from 'hono';
import {
  REGIONAL_VOICE_CATALOG,
  filterVoiceCatalog,
  scoreLyricLinePhonetics,
  extractPhoneticCalibrationScript,
} from '../src/modules/voices/voice_catalog.js';
import { voiceRoutes } from '../src/routes/voice_routes.js';
import { generationRoutes } from '../src/routes/generation_routes.js';

async function runVoiceIdentityTests() {
  console.log('🧪 Running Phase 26 Vocal Identity Catalog & Phonetic Voice Cloning Tests...');

  // 1. Catalog Integrity (24 Regional African Voice Archetypes)
  console.log('  1. Testing 24 Sovereign Regional African Voice Archetypes...');
  assert.strictEqual(
    REGIONAL_VOICE_CATALOG.length,
    24,
    'Catalog must expose 24 distinct regional African voice archetypes',
  );

  const uniqueIds = new Set(REGIONAL_VOICE_CATALOG.map((v) => v.id));
  assert.strictEqual(uniqueIds.size, 24, 'Every voice archetype ID must be unique');

  // Verify regional coverage
  const southern = filterVoiceCatalog({ region: 'southern_africa' });
  const west = filterVoiceCatalog({ region: 'west_africa' });
  const east = filterVoiceCatalog({ region: 'east_africa' });
  const central = filterVoiceCatalog({ region: 'central_africa' });
  const diaspora = filterVoiceCatalog({ region: 'diaspora' });

  assert.ok(southern.length >= 12, 'Must include rich Southern African representation');
  assert.ok(west.length >= 4, 'Must include West African representation');
  assert.ok(east.length >= 3, 'Must include East African representation');
  assert.ok(central.length >= 2, 'Must include Central African representation');
  assert.ok(diaspora.length >= 1, 'Must include Diaspora representation');

  // Verify filtering by language and search query
  const vendaVoices = filterVoiceCatalog({ language: 'Tshivenḓa' });
  const zuluVoices = filterVoiceCatalog({ language: 'isiZulu' });
  assert.ok(vendaVoices.length >= 1, 'Must find Tshivenḓa voices');
  assert.ok(zuluVoices.length >= 3, 'Must find isiZulu voices');
  const searchLogDrum = filterVoiceCatalog({ q: 'Soweto' });
  assert.ok(searchLogDrum.length >= 1, 'Search query must match accent/name metadata');

  // 2. Bantu Phonetic Density Scoring Formula
  console.log('  2. Testing scoreLyricLinePhonetics() Bantu Phonetic Density Formula...');
  const denseLine = 'Ndaa! Mbilu yanga i khou tshimbila kha ṋaledzi na ḓuvha ḽa मुṱa';
  const plainLine = 'We are walking in the sun today';

  const denseScore = scoreLyricLinePhonetics(denseLine);
  const plainScore = scoreLyricLinePhonetics(plainLine);

  assert.ok(
    denseScore.score > plainScore.score + 8.0,
    `Bantu diacritic/cluster/idiom line (${denseScore.score}) must score significantly higher than plain line (${plainScore.score})`,
  );
  assert.ok(denseScore.highlightedTokens.length >= 3, 'Must highlight key phonetic tokens');

  // 3. 3-Line Calibration Script Extraction + Short-Lyrics Fallback
  console.log('  3. Testing extractPhoneticCalibrationScript()...');
  const multiStanzaLyrics = [
    '[Verse 1]',
    'We wake up early in the morning',
    'Ndaa! Mbilu yanga i khou tshina kha ngoma dza Vhunambi',
    'Walking down the street',
    '[Chorus]',
    'Yebo! Hlala phansi ulalele isigqi saseThekwini',
    'Ahee! Kha vha ḓe ri ṱangane tshilombe tsha Amapiano',
  ].join('\n');

  const extracted = extractPhoneticCalibrationScript(multiStanzaLyrics, 'Tshivenḓa');
  assert.strictEqual(extracted.lines.length, 3, 'Must always extract exactly 3 calibration lines');
  assert.ok(
    extracted.lines[0].phoneticScore >= extracted.lines[1].phoneticScore,
    'Lines must be ranked by descending phonetic density score',
  );
  assert.ok(
    extracted.totalEstimatedDurationSec >= 12 && extracted.totalEstimatedDurationSec <= 24,
    'Total estimated calibration duration must be within ~12-24 seconds',
  );

  // Short lyrics fallback test
  const shortFallback = extractPhoneticCalibrationScript('One short line only', 'zu');
  assert.strictEqual(
    shortFallback.lines.length,
    3,
    'Short lyrics must automatically pad to 3 lines using native fallback sentences',
  );

  // 4. API Routes via Hono Fetch
  const app = new Hono();
  app.route('/v1/voices', voiceRoutes);
  app.route('/v1/generations', generationRoutes);

  console.log('  4. Testing GET /v1/voices/catalog...');
  const resCatalog = await app.fetch(
    new Request('http://localhost/v1/voices/catalog?region=southern_africa&gender=female'),
  );
  assert.strictEqual(resCatalog.status, 200);
  const catalogJson = (await resCatalog.json()) as any;
  assert.strictEqual(catalogJson.totalCount, 24);
  assert.ok(catalogJson.filteredCount > 0);
  assert.ok(
    catalogJson.voices.every(
      (v: any) => v.region === 'southern_africa' && v.gender === 'female',
    ),
  );

  console.log('  5. Testing POST /v1/voices/extract-calibration...');
  const resCalib = await app.fetch(
    new Request('http://localhost/v1/voices/extract-calibration', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        lyrics: multiStanzaLyrics,
        language: 'Tshivenḓa',
      }),
    }),
  );
  assert.strictEqual(resCalib.status, 200);
  const calibJson = (await resCalib.json()) as any;
  assert.strictEqual(calibJson.success, true);
  assert.strictEqual(calibJson.script.lines.length, 3);

  console.log('  6. Testing POST /v1/voices/clone & GET /v1/voices/clone/:id...');
  const resClone = await app.fetch(
    new Request('http://localhost/v1/voices/clone', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        creatorName: 'Ndugelo Studio Vocal',
        nativeLanguage: 'Tshivenḓa',
        calibrationLines: calibJson.script.lines.map((l: any) => l.text),
        recordingDurationSec: 18.5,
      }),
    }),
  );
  assert.strictEqual(resClone.status, 201);
  const cloneJson = (await resClone.json()) as any;
  assert.strictEqual(cloneJson.success, true);
  assert.ok(cloneJson.profile.id.startsWith('vclone_'));
  assert.strictEqual(cloneJson.profile.timbreEmbeddingPreview.length, 8);
  assert.strictEqual(cloneJson.profile.recommendedCleanseFlavor, 'studio_clean');

  const cloneId = cloneJson.profile.id;
  const resGetClone = await app.fetch(
    new Request(`http://localhost/v1/voices/clone/${cloneId}`),
  );
  assert.strictEqual(resGetClone.status, 200);
  const getCloneJson = (await resGetClone.json()) as any;
  assert.strictEqual(getCloneJson.profile.id, cloneId);

  console.log('  7. Testing POST /v1/generations with selectedVoiceId & clonedVoiceProfileId...');
  const resGenWithClone = await app.fetch(
    new Request('http://localhost/v1/generations', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        trackTitle: 'Limpopo Vocal Clone Anthem',
        genre: 'Amapiano',
        language: 've',
        bpm: 113,
        durationSec: 120,
        selectedVoiceId: 'vox_venda_royal_alto',
        clonedVoiceProfileId: cloneId,
      }),
    }),
  );
  assert.strictEqual(resGenWithClone.status, 201);
  const genCloneJson = (await resGenWithClone.json()) as any;
  assert.ok(genCloneJson.generationId);
  assert.strictEqual(genCloneJson.vocalIdentity.selectedVoiceId, 'vox_venda_royal_alto');
  assert.strictEqual(genCloneJson.vocalIdentity.clonedVoiceProfileId, cloneId);
  assert.strictEqual(genCloneJson.vocalIdentity.svcMode, 'zero_shot_clone');

  console.log('✅ All Phase 26 Vocal Identity & Voice Cloning Backend Tests Passed!\n');
}

runVoiceIdentityTests().catch((err) => {
  console.error('❌ Phase 26 Vocal Identity Test Failure:', err);
  process.exit(1);
});
