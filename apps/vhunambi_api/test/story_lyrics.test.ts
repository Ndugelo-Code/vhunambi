import assert from 'node:assert';
import { Hono } from 'hono';
import { lyricsRoutes } from '../src/routes/lyrics_routes.js';
import {
  GENRE_DNA,
  STORY_GENRES,
  compileAceStepCaption,
  normalizeGenre,
  pickHookLine,
  splitStoryIntoLines,
  transformStoryToLyrics,
  validateLanguageNeutrality,
} from '../src/modules/lyrics/story_transform.js';
import { getLanguageContext } from '../src/modules/bantu/language_context.js';

async function run() {
  console.log('🧪 Running Phase 36 Story-to-Lyrics (ZR-STORYLYRICS-001) Tests...');

  // 1. Strict genre DNA / language separation
  console.log('  1. Genre DNA templates are language-neutral...');
  for (const g of STORY_GENRES) {
    const offenders = validateLanguageNeutrality(GENRE_DNA[g].promptTemplate);
    assert.deepStrictEqual(offenders, [], `${g} genre DNA must not mention a language: ${offenders}`);
  }
  assert.ok(validateLanguageNeutrality('Amapiano with isiZulu vocals').length > 0, 'detector must flag language names');

  // 2. Caption compilation joins DNA + language context
  console.log('  2. compileAceStepCaption combines DNA + language context...');
  const caption = compileAceStepCaption(GENRE_DNA.amapiano, getLanguageContext('ve'), ['warm', 'reflective']);
  assert.ok(caption.includes('114 BPM'));
  assert.ok(caption.includes('Tshivenḓa'));
  assert.ok(caption.includes('warm, reflective mood'));

  // 3. Story splitting preserves the creator's own words
  console.log('  3. Story splitting never rewrites the creator words...');
  const story =
    'Ndo vha ndi tshi khou tshimbila nga tshifhinga tsha vhusiku. Mme vho mmbidza! Ndo fhindula, ndi tshi tshenuwa vhukuma.';
  const lines = splitStoryIntoLines(story);
  assert.ok(lines.length >= 3);
  const rejoined = lines.join(' ').replace(/[.!,]/g, '');
  for (const w of ['tshimbila', 'vhusiku', 'mmbidza', 'tshenuwa']) {
    assert.ok(rejoined.includes(w), `word ${w} must survive`);
  }
  const hook = pickHookLine(lines);
  assert.ok(lines.includes(hook));

  // 4. Genre structures
  console.log('  4. Each genre yields its authentic section structure...');
  const expectTag: Record<string, string> = {
    amapiano: '[PRE-CHORUS]',
    maskandi: '[IZIHLABO / INTRO]',
    gqom: '[DROP / CHANT 1]',
    gospel: '[CALL AND RESPONSE]',
    kwaito: '[HOOK]',
    hiphop: '[VERSE 2]',
  };
  for (const g of STORY_GENRES) {
    const out = transformStoryToLyrics({ storyText: story, genre: g, baseLanguage: 'zu' });
    assert.ok(out.structuredLyrics.includes(expectTag[g]), `${g} must contain ${expectTag[g]}`);
    assert.ok(out.compiledCaption.includes('isiZulu'));
    assert.strictEqual(out.language.code, 'zu');
    assert.ok(out.structuredLyrics.includes(out.hookLine));
    assert.ok(out.stanzas.length > 0);
  }

  // 5. No story line is silently dropped
  console.log('  5. No narrative line is dropped...');
  const long = Array.from({ length: 40 }, (_, i) => `Mutsho wa ${i} u a vhonala`).join('. ') + '.';
  const out = transformStoryToLyrics({ storyText: long, genre: 'gqom', baseLanguage: 've' });
  for (let i = 0; i < 40; i++) {
    assert.ok(out.structuredLyrics.includes(`Mutsho wa ${i} u a vhonala`), `line ${i} must be placed`);
  }

  // 6. HTTP route
  console.log('  6. POST /v1/lyrics/story-transform...');
  const app = new Hono();
  app.route('/v1/lyrics', lyricsRoutes);
  const ok = await app.request(
    new Request('http://localhost/v1/lyrics/story-transform', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        storyText: story,
        genre: 'Maskandi',
        baseLanguage: 'zu-ZA',
        targetCognateLanguages: ['ve', 'st', 'zu', 'xx'],
        mood: ['nostalgic'],
      }),
    }),
  );
  assert.strictEqual(ok.status, 200);
  const j = (await ok.json()) as Record<string, unknown>;
  assert.strictEqual(j.success, true);
  assert.strictEqual(j.genreStructureUsed, 'maskandi_storytelling');
  assert.deepStrictEqual(j.cognateTargets, ['ve', 'st'], 'unknown + self codes are filtered');

  const short = await app.request(
    new Request('http://localhost/v1/lyrics/story-transform', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ storyText: 'too short' }),
    }),
  );
  assert.strictEqual(short.status, 400);

  const badGenre = await app.request(
    new Request('http://localhost/v1/lyrics/story-transform', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ storyText: story, genre: 'polka' }),
    }),
  );
  assert.strictEqual(badGenre.status, 400);

  const badLang = await app.request(
    new Request('http://localhost/v1/lyrics/story-transform', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ storyText: story, baseLanguage: 'fr' }),
    }),
  );
  assert.strictEqual(badLang.status, 400);
  assert.strictEqual(normalizeGenre('SA Hip-Hop'), 'hiphop');

  console.log('✅ Phase 36 Story-to-Lyrics tests passed.');
}

run().catch((e) => {
  console.error('❌ Story-to-Lyrics tests failed:', e);
  process.exit(1);
});

