import { strict as assert } from 'node:assert';
import { app } from '../src/server.js';
import {
  synthesizeAndCacheMissingR2Object,
  synthesizeCoverPngBytes,
  synthesizeTrackStemPackWav,
} from '../src/modules/synthesis/r2_media_synthesizer.js';
import { generateLocalMockLyrics } from '../src/modules/lyrics/llm_handler.js';

async function runPhase65Tests(): Promise<void> {
  console.log('\n🛡️ Running Phase 65 Backend Resilience & Fidelity Tests (B1-B5)...\n');

  // Register test boom route BEFORE Hono compiles SmartRouter on first request
  app.get('/__phase65_boom_test', () => {
    const err = new Error('Simulated unhandled controller throw') as Error & {
      status?: number;
      code?: string;
    };
    err.status = 400;
    err.code = 'INVALID_JSON_PAYLOAD';
    throw err;
  });

  // B1: app.notFound returns structured JSON error + CORS headers
  const notFoundRes = await app.request('/v1/non-existent-phase65-endpoint');
  assert.equal(notFoundRes.status, 404);
  assert.equal(notFoundRes.headers.get('access-control-allow-origin'), '*');
  const notFoundBody = (await notFoundRes.json()) as Record<string, unknown>;
  assert.equal(notFoundBody.success, false);
  assert.equal(notFoundBody.errorCode, 'NOT_FOUND');
  console.log('  ✅ B1 (app.notFound + CORS envelope) passed');

  // B2: app.onError returns structured JSON error + CORS headers when route throws
  const errRes = await app.request('/__phase65_boom_test');
  assert.equal(errRes.status, 400);
  assert.equal(errRes.headers.get('access-control-allow-origin'), '*');
  const errBody = (await errRes.json()) as Record<string, unknown>;
  assert.equal(errBody.success, false);
  assert.equal(errBody.errorCode, 'INVALID_JSON_PAYLOAD');
  console.log('  ✅ B2 (app.onError + CORS envelope) passed');

  // B3: synthesizeCoverPngBytes produces valid RFC-2083 PNG magic header, IHDR, IEND
  const png = synthesizeCoverPngBytes('covers/test_phase65.png');
  assert.ok(png.byteLength > 128);
  assert.deepEqual(
    Array.from(png.slice(0, 8)),
    [137, 80, 78, 71, 13, 10, 26, 10],
  );
  const pngAscii = String.fromCharCode(...png.slice(12, 16));
  assert.equal(pngAscii, 'IHDR');
  const iendTag = String.fromCharCode(...png.slice(png.length - 8, png.length - 4));
  assert.equal(iendTag, 'IEND');

  const r2Png = await synthesizeAndCacheMissingR2Object('visuals/default_9_16.png');
  assert.equal(r2Png.contentType, 'image/png');
  assert.deepEqual(Array.from(r2Png.bytes.slice(0, 4)), [137, 80, 78, 71]);
  console.log('  ✅ B3 (RFC-2083 PNG synthesis & MIME parity) passed');

  // B4: Synthesized R2 audio WAV is 24 seconds long (never 3-4s stub)
  const r2Wav = await synthesizeAndCacheMissingR2Object('audio/phase65_test_master.wav');
  assert.equal(r2Wav.contentType, 'audio/wav');
  assert.equal(String.fromCharCode(...r2Wav.bytes.slice(0, 4)), 'RIFF');
  assert.equal(String.fromCharCode(...r2Wav.bytes.slice(8, 12)), 'WAVE');
  // 24s * 11025 Hz * 2 channels * 2 bytes = 1,058,400 + 44 header = 1,058,444
  assert.ok(r2Wav.bytes.byteLength >= 1058444);

  const pack = synthesizeTrackStemPackWav({ seedKey: 'phase65_pack' });
  assert.ok(pack.master.byteLength >= 1058444);
  console.log('  ✅ B4 (24s stereo WAV synthesis & tiling) passed');

  // B5: Lyrics fallback does not parrot raw prompt instructions into stanzas
  const rawPrompt =
    'Make a 90s kwaito song with heavy bassline and township whistles';
  const lyrics = generateLocalMockLyrics(rawPrompt, 'Kwaito', 'Tshivenda');
  assert.ok(lyrics.rawLyrics.includes('[INTRO]'));
  assert.ok(lyrics.rawLyrics.includes('[VERSE 1]'));
  assert.ok(lyrics.rawLyrics.includes('[CHORUS]'));
  assert.equal(lyrics.rawLyrics.includes(`Thinking of ${rawPrompt}`), false);
  assert.equal(lyrics.rawLyrics.includes(`we move through ${rawPrompt}`), false);
  console.log('  ✅ B5 (Non-echoing lyrics fallback) passed');

  console.log('\n🎉 ALL PHASE 65 BACKEND RESILIENCE TESTS (B1-B5) PASSED!\n');
}

runPhase65Tests().catch((err) => {
  console.error('❌ Phase 65 backend test failed:', err);
  process.exit(1);
});

