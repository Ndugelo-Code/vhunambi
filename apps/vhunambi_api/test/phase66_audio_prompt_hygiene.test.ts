import { strict as assert } from 'node:assert';
import { sanitizeLyricsForAceStep } from '../src/modules/lyrics/lyrics_sanitizer.js';
import { compileSongSpec } from '../src/modules/synthesis/prompt_compiler.js';

const dirty = [
  '[Crisp soft shakers, gentle Rhodes chords swell]',
  '[INTRO: 8 bars percussive shaker]',
  'Ndi a takala musi',
  '[Log drum drop: heavy sub-808 sidechain layering]',
  '(Li-ste-en... hear that sweet horn blow...)',
  '[VERSE 1] Ndo neta',
  '[CHORUS]',
  'Sing it loud (ad lib)',
].join('\n');
const clean = sanitizeLyricsForAceStep(dirty);
assert.equal(clean, '[intro]\nNdi a takala musi\n[verse 1]\nNdo neta\n[chorus]\nSing it loud');
assert(!/shaker|log drum|horn/i.test(clean));

// Cockpit selections reach the ACE-Step tag caption as comma-separated tags.
const kw = compileSongSpec({
  trackTitle: 'T', genre: '90s Kwaito', language: 'zu', tempoBpm: 102, mood: 'Soulful & Nostalgic',
});
assert(kw.caption.includes('kwaito'), 'genre tag: ' + kw.caption);
assert(kw.caption.includes('102 bpm'));
assert(kw.caption.includes('soulful'));
assert(!kw.caption.includes('Arrangement') && !/[\[\]]/.test(kw.caption), 'no prose/brackets in caption');
assert(kw.loras?.[0]?.path.includes('kwaito'), 'kwaito LoRA, got ' + kw.loras?.[0]?.path);
assert(!/[\[\(][^\]\)]*(bpm|groove|session)/i.test(kw.lyrics), 'no meta in lyrics');
assert.equal(kw.inferenceConfig?.guidanceScale, 12);
assert(kw.metadata.durationSec >= 60);

const inst = compileSongSpec({ trackTitle: 'T', genre: 'Amapiano', language: 've', isInstrumental: true });
assert.equal(inst.lyrics, '');
assert(inst.caption.includes('no vocals'));
console.log('phase66 audio prompt hygiene: OK');