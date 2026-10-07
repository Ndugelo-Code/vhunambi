import assert from 'node:assert';
import { generateLyricsFromLLM } from '../src/modules/lyrics/llm_handler.js';
import { compileSongSpec } from '../src/modules/synthesis/prompt_compiler.js';
import { createJob, getJob } from '../src/modules/jobs/job_store.js';

async function runTests() {
  console.log('🧪 Running Vhunambi API Unit & Integration Tests...');

  // Test 1: Prompt Compiler
  console.log('  1. Testing compileSongSpec (Amapiano, Tshivenḓa)...');
  const compiled = compileSongSpec({
    trackTitle: 'Lwendo lwa Vhunambi',
    genre: 'Amapiano',
    language: 've',
  });
  assert(compiled.caption.includes('Amapiano'), 'Caption should contain Amapiano genre');
  assert(compiled.caption.includes('112 BPM'), 'Caption should contain default 112 BPM');
  assert(compiled.metadata.bpm === 112, 'Metadata BPM should be 112');
  console.log('     ✅ compileSongSpec passed');

  // Test 2: Lyrics Generation with bracketed stanzas
  console.log('  2. Testing generateLyricsFromLLM (Tshivenḓa stanzas)...');
  const lyricsResult = await generateLyricsFromLLM(
    'A song about the sacred rain queen of Venda',
    'Amapiano',
    've',
    'System prompt',
  );
  assert(lyricsResult.stanzas.length >= 4, 'Should generate at least 4 structured stanzas');
  assert(lyricsResult.stanzas.some((s) => s.header === '[INTRO]'), 'Should contain [INTRO]');
  assert(lyricsResult.stanzas.some((s) => s.header === '[CHORUS]'), 'Should contain [CHORUS]');
  assert(lyricsResult.rawLyrics.includes('[CHORUS]'), 'Raw lyrics must include [CHORUS]');
  console.log('     ✅ generateLyricsFromLLM passed with bracketed stanzas');

  // Test 3: Job Store lifecycle
  console.log('  3. Testing Job Store lifecycle...');
  const testId = `gen_test_${Date.now()}`;
  createJob({
    generationId: testId,
    trackTitle: 'Test Track',
    genre: 'Gqom',
    language: 'zu',
  });
  const fetchedJob = getJob(testId);
  assert(fetchedJob !== undefined, 'Job should exist');
  assert(fetchedJob.status === 'queued', 'Initial status should be queued');
  console.log('     ✅ Job Store passed');

  console.log('\n🎉 ALL TESTS PASSED! Backend engine verified.');
}

runTests().catch((err) => {
  console.error('❌ Test failed:', err);
  process.exit(1);
});
