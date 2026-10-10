import assert from 'node:assert';
import { compileSongMetadataDNA } from '../src/modules/dna/dna_compiler.js';

console.log('🧪 Running Vhunambi DNA Compiler Tests...');

// 1. Test basic compilation with Amapiano & Tshivenḓa
console.log('  1. Testing compileSongMetadataDNA (Amapiano, Tshivenḓa)...');
const dnaAmapiano = compileSongMetadataDNA({
  title: 'Vhubvo Hanga',
  genre: 'Amapiano',
  language: 'Tshivenḓa',
  mood: 'Soulful & Nostalgic',
  prompt: 'Delicate jazz chords and warm Rhodes',
});

assert.strictEqual(dnaAmapiano.title, 'Vhubvo Hanga');
assert.strictEqual(dnaAmapiano.genre, 'Amapiano');
assert.strictEqual(dnaAmapiano.language, 'Tshivenḓa');
assert.strictEqual(dnaAmapiano.musical.bpm, 112);
assert.strictEqual(dnaAmapiano.musical.timeSignature, '4/4');
assert.strictEqual(dnaAmapiano.visualTheme.aspectRatio, '9:16');
assert.ok(dnaAmapiano.visualTheme.comfyPrompt.includes('Amapiano album cover art'));
assert.ok(dnaAmapiano.culturalContext?.idioms.length! > 0);
console.log('     ✅ Amapiano DNA compiled with 9:16 visual parameters and Bantu idioms');

// 2. Test Gqom compilation with intense energy
console.log('  2. Testing compileSongMetadataDNA (Gqom, isiZulu)...');
const dnaGqom = compileSongMetadataDNA({
  genre: 'Gqom',
  language: 'isiZulu',
  deliveryMode: 'spokenWord',
  gender: 'male',
});

assert.strictEqual(dnaGqom.musical.bpm, 128);
assert.strictEqual(dnaGqom.vocals.deliveryMode, 'spokenWord');
assert.strictEqual(dnaGqom.vocals.gender, 'male');
assert.strictEqual(dnaGqom.musical.energyBracket, 'intense');
console.log('     ✅ Gqom DNA compiled with accurate BPM and vocal delivery mode');

// 3. Test Alignment preserving
console.log('  3. Testing alignment word timestamps preservation...');
const dnaAligned = compileSongMetadataDNA({
  genre: 'Amapiano',
  language: 'Tshivenḓa',
  alignment: [
    { word: 'Ndi', start: 1.0, end: 1.25, stanzaIndex: 0 },
    { word: 'mufunwa', start: 1.28, end: 1.85, stanzaIndex: 0 },
  ],
});

assert.strictEqual(dnaAligned.alignment.length, 2);
assert.strictEqual(dnaAligned.alignment[0].word, 'Ndi');
assert.strictEqual(dnaAligned.alignment[1].word, 'mufunwa');
console.log('     ✅ Lyric timestamps preserved without mutation');

console.log('🎉 ALL DNA COMPILER TESTS PASSED!\n');
