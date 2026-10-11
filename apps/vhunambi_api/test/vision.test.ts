import assert from 'node:assert';
import {
  buildComfyUIPromptGraph,
  dispatchComfyUIVisionJob,
} from '../src/modules/vision/comfyui_adapter.js';
import {
  synthesizeLocalVisionPrompt,
  synthesizeVisionPrompt,
} from '../src/modules/vision/prompt_synthesizer.js';
import { compileSongMetadataDNA } from '../src/modules/dna/dna_compiler.js';
import { env } from '../src/config/env.js';

async function runVisionTests() {
  console.log('🧪 Running Vhunambi Vision Engine Tests...');

  // 1. Test buildComfyUIPromptGraph node schema
  console.log('  1. Testing buildComfyUIPromptGraph schema alignment (9:16 aspect ratio)...');
  const testSeed = 4239847239;
  const testPrompt = 'Amapiano neon Johannesburg night skyline, 9:16 vertical ratio';
  const graph = buildComfyUIPromptGraph(testPrompt, testSeed);

  assert.strictEqual(graph['3'].class_type, 'CheckpointLoaderSimple');
  assert.strictEqual(graph['3'].inputs.ckpt_name, 'sd_xl_base_1.0.safetensors');

  // Node 5: 9:16 Latent Resolution
  assert.strictEqual(graph['5'].class_type, 'EmptyLatentImage');
  assert.strictEqual(graph['5'].inputs.width, 768);
  assert.strictEqual(graph['5'].inputs.height, 1344);
  assert.strictEqual(graph['5'].inputs.batch_size, 1);

  // Node 6: Positive Prompt Insertion
  assert.strictEqual(graph['6'].class_type, 'CLIPTextEncode');
  assert.strictEqual(graph['6'].inputs.text, testPrompt);

  // Node 7: Negative Prompt
  assert.strictEqual(graph['7'].class_type, 'CLIPTextEncode');
  assert.ok(graph['7'].inputs.text.includes('blurry'));

  // Node 10: KSampler
  assert.strictEqual(graph['10'].class_type, 'KSampler');
  assert.strictEqual(graph['10'].inputs.seed, testSeed);
  assert.strictEqual(graph['10'].inputs.steps, 25);
  assert.strictEqual(graph['10'].inputs.cfg, 7.0);

  // Node 12 & 15: VAE Decode and SaveImage
  assert.strictEqual(graph['12'].class_type, 'VAEDecode');
  assert.strictEqual(graph['15'].class_type, 'SaveImage');
  assert.strictEqual(graph['15'].inputs.filename_prefix, 'vhunambi_cover_9_16');
  console.log('     ✅ buildComfyUIPromptGraph adheres strictly to blueprint node state machine');

  // 2. Test Local Prompt Synthesizer
  console.log('  2. Testing synthesizeLocalVisionPrompt for African genres...');
  const dnaAmapiano = compileSongMetadataDNA({
    title: 'Log Drum Haven',
    genre: 'Amapiano',
    language: 'Tshivenḓa',
    mood: 'Euphoric & Nostalgic',
    prompt: 'Delicate Rhodes chords and soulful female leads',
  });

  const promptAmapiano = synthesizeLocalVisionPrompt(dnaAmapiano);
  assert.ok(promptAmapiano.includes('9:16 vertical ratio'));
  assert.ok(promptAmapiano.includes('Johannesburg'));
  assert.ok(promptAmapiano.includes('8k resolution'));

  const dnaGqom = compileSongMetadataDNA({
    title: 'Durban Night',
    genre: 'Gqom',
    language: 'isiZulu',
    mood: 'Dark & Raw',
  });
  const promptGqom = synthesizeLocalVisionPrompt(dnaGqom);
  assert.ok(promptGqom.includes('Durban warehouse rave'));
  assert.ok(promptGqom.includes('9:16 vertical ratio'));
  console.log('     ✅ synthesizeLocalVisionPrompt compiles evocative 9:16 genre descriptions');

  // 3. Test dispatchComfyUIVisionJob fallback when no credentials are configured
  console.log('  3. Testing dispatchComfyUIVisionJob fallback simulation...');
  const originalUrl = env.RUNPOD_COMFYUI_URL;
  const originalKey = env.RUNPOD_API_KEY;
  const originalEndpoint = env.RUNPOD_COMFYUI_ENDPOINT_ID;

  try {
    env.RUNPOD_COMFYUI_URL = undefined;
    env.RUNPOD_API_KEY = undefined;
    env.RUNPOD_COMFYUI_ENDPOINT_ID = undefined;

    const result = await dispatchComfyUIVisionJob({
      promptText: promptAmapiano,
      seed: testSeed,
    });

    assert.strictEqual(result.isMock, true);
    assert.ok(result.jobId.startsWith('mock_vision_'));
    assert.strictEqual(result.width, 768);
    assert.strictEqual(result.height, 1344);
    assert.strictEqual(result.status, 'completed');
    assert.ok(result.outputImageUrl?.includes('.png'));
    console.log('     ✅ dispatchComfyUIVisionJob falls back cleanly to mock simulation');
  } finally {
    env.RUNPOD_COMFYUI_URL = originalUrl;
    env.RUNPOD_API_KEY = originalKey;
    env.RUNPOD_COMFYUI_ENDPOINT_ID = originalEndpoint;
  }

  // 4. Test synthesizeVisionPrompt end-to-end
  console.log('  4. Testing synthesizeVisionPrompt with SongMetadataDNA...');
  const fullPrompt = await synthesizeVisionPrompt(dnaAmapiano);
  assert.ok(fullPrompt.length > 50);
  assert.ok(fullPrompt.includes('9:16'));
  console.log('     ✅ synthesizeVisionPrompt executes successfully');

  // 5. Test POST /v1/vision/generate HTTP route
  console.log('  5. Testing POST /v1/vision/generate HTTP route...');
  const { app } = await import('../src/server.js');
  const routeRes = await app.request('/v1/vision/generate', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      title: 'Makhado Sunset',
      genre: 'Amapiano',
      language: 've',
      mood: 'Soulful & Euphoric',
    }),
  });

  assert.strictEqual(routeRes.status, 201);
  const routeData = (await routeRes.json()) as any;
  assert.strictEqual(routeData.success, true);
  assert.strictEqual(routeData.width, 768);
  assert.strictEqual(routeData.height, 1344);
  assert.ok(routeData.promptText.includes('9:16'));
  console.log('     ✅ POST /v1/vision/generate route validated successfully');

  console.log('🎉 ALL VISION ENGINE TESTS PASSED!\n');
}

runVisionTests().catch((err) => {
  console.error('❌ Vision tests failed:', err);
  process.exit(1);
});
