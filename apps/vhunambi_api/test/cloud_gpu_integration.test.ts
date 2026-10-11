import assert from 'node:assert';
import crypto from 'node:crypto';
import { compileSongSpec } from '../src/modules/synthesis/prompt_compiler.js';
import { dispatchSynthesisJob } from '../src/modules/synthesis/runpod_adapter.js';
import { webhookRoutes } from '../src/routes/webhook_routes.js';
import { createJob, getJob } from '../src/modules/jobs/job_store.js';
import { env } from '../src/config/env.js';

async function runPhase16Tests() {
  console.log('🧪 Running Phase 16 Cloud & GPU Integration Tests...');

  // Test 1: Prompt Compiler exports required song_spec metadata
  console.log('  1. Testing prompt_compiler metadata extension...');
  const compiled = compileSongSpec({
    trackTitle: 'Mbilu Yanga',
    genre: 'Amapiano',
    language: 've',
  });

  assert.strictEqual(compiled.metadata.genre, 'amapiano', 'Metadata genre must be lowercase string');
  assert.strictEqual(compiled.metadata.language, 've', 'Metadata language must match');
  assert.strictEqual(compiled.metadata.bpm, 112, 'Metadata BPM must match Amapiano default');
  assert.strictEqual(compiled.metadata.mood, 'euphoric', 'Metadata mood must match genre default');
  assert.strictEqual(compiled.metadata.title, 'Mbilu Yanga', 'Metadata title must match input');
  console.log('     ✅ prompt_compiler produces complete song_spec metadata');

  // Test 2: RunPod Adapter fallback when credentials are not configured
  console.log('  2. Testing runpod_adapter fallback to simulation...');
  const realKey = env.RUNPOD_API_KEY;
  const realEndpoint = env.RUNPOD_ENDPOINT_ID;
  try {
    env.RUNPOD_API_KEY = '';
    env.RUNPOD_ENDPOINT_ID = '';
    const mockGenId = `gen_mock_${Date.now()}`;
    createJob({
      generationId: mockGenId,
      trackTitle: 'Mbilu Yanga',
      genre: 'Amapiano',
      language: 've',
    });

    const mockResult = await dispatchSynthesisJob(mockGenId, compiled, 'user_123');
    assert.strictEqual(mockResult.isMock, true, 'isMock must be true when no credentials configured');
    assert.strictEqual(mockResult.jobId, `mock_${mockGenId}`, 'Mock job ID must be prefixed with mock_');
    console.log('     ✅ runpod_adapter falls back safely to in-process simulation');
  } finally {
    env.RUNPOD_API_KEY = realKey;
    env.RUNPOD_ENDPOINT_ID = realEndpoint;
  }

  // Test 3: RunPod Adapter payload schema alignment when credentials ARE configured
  console.log('  3. Testing runpod_adapter payload schema alignment with handler.py...');
  const originalKey = env.RUNPOD_API_KEY;
  const originalEndpoint = env.RUNPOD_ENDPOINT_ID;
  const originalWebhookBase = env.WEBHOOK_BASE_URL;

  try {
    env.RUNPOD_API_KEY = 'test_api_key';
    env.RUNPOD_ENDPOINT_ID = 'test_endpoint_123';
    env.WEBHOOK_BASE_URL = 'https://tunnel.example.com';

    let capturedUrl = '';
    let capturedHeaders: Record<string, string> = {};
    let capturedBody: any = null;

    // Stub global fetch
    const originalFetch = globalThis.fetch;
    globalThis.fetch = (async (url: string | URL | Request, init?: RequestInit) => {
      capturedUrl = url.toString();
      capturedHeaders = (init?.headers as Record<string, string>) || {};
      capturedBody = JSON.parse(init?.body as string);
      return new Response(JSON.stringify({ id: 'runpod_job_abc123' }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    }) as typeof fetch;

    const realResult = await dispatchSynthesisJob('runpod_gen_99', compiled, 'creator_ndugelo');

    // Restore fetch
    globalThis.fetch = originalFetch;

    assert.strictEqual(realResult.isMock, false, 'isMock must be false on real dispatch');
    assert.strictEqual(realResult.jobId, 'runpod_job_abc123');
    assert.strictEqual(capturedUrl, 'https://api.runpod.ai/v2/test_endpoint_123/run');
    assert.strictEqual(capturedHeaders['Authorization'], 'Bearer test_api_key');
    assert.strictEqual(capturedHeaders['Content-Type'], 'application/json');

    // Validate handler.py schema compliance
    assert(capturedBody.input, 'Request must contain input object');
    assert.strictEqual(capturedBody.input.job_id, 'vhunambi_runpod_gen_99', 'job_id must be prefixed');
    assert.strictEqual(capturedBody.input.user_id, 'creator_ndugelo', 'user_id must match');
    assert.strictEqual(capturedBody.input.webhook_url, 'https://tunnel.example.com/v1/webhooks/ace-step');
    assert.deepStrictEqual(capturedBody.input.loras, []);

    const songSpec = capturedBody.input.song_spec;
    assert.strictEqual(songSpec.genre, 'amapiano');
    assert.strictEqual(songSpec.tempo, 112);
    assert.strictEqual(songSpec.mood, 'euphoric');
    assert.strictEqual(songSpec.duration, 180);
    assert.strictEqual(songSpec.language, 've');
    assert.strictEqual(songSpec.title, 'Mbilu Yanga');
    console.log('     ✅ runpod_adapter dispatches exact handler.py payload schema');
  } finally {
    env.RUNPOD_API_KEY = originalKey;
    env.RUNPOD_ENDPOINT_ID = originalEndpoint;
    env.WEBHOOK_BASE_URL = originalWebhookBase;
  }

  // Test 4: Webhook HMAC signature verification and callback processing
  console.log('  4. Testing webhook HMAC verification and status mapping...');
  const webhookGenId = `hook_test_${Date.now()}`;
  createJob({
    generationId: webhookGenId,
    trackTitle: 'Hook Test',
    genre: 'Gqom',
    language: 'zu',
  });

  const originalSecret = env.ZR_WEBHOOK_SECRET;
  try {
    env.ZR_WEBHOOK_SECRET = 'super_secret_signing_key_123';

    // 4a: Unauthorized request without signature
    const unauthRes = await webhookRoutes.request('/ace-step', {
      method: 'POST',
      body: JSON.stringify({ job_id: `vhunambi_${webhookGenId}`, status: 'processing' }),
    });
    assert.strictEqual(unauthRes.status, 401, 'Request without signature should return 401');

    // 4b: Authorized "processing" callback
    const processingPayload = JSON.stringify({
      job_id: `vhunambi_${webhookGenId}`,
      status: 'processing',
      progress: 50,
      audio_url: null,
      message: 'Generating audio...',
    });
    const processingSig = crypto
      .createHmac('sha256', env.ZR_WEBHOOK_SECRET)
      .update(processingPayload)
      .digest('hex');

    const procRes = await webhookRoutes.request('/ace-step', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-zrs-signature': processingSig,
      },
      body: processingPayload,
    });
    assert.strictEqual(procRes.status, 200, 'Authorized processing callback must return 200');
    let job = getJob(webhookGenId);
    assert.strictEqual(job?.status, 'running');
    assert.strictEqual(job?.step, 'synthesizing');

    // 4c: Authorized "completed" callback
    const completedPayload = JSON.stringify({
      job_id: `vhunambi_${webhookGenId}`,
      status: 'completed',
      progress: 100,
      audio_url: 'https://r2.vhunambi.com/generated/creator/track.wav',
      message: 'Track generated successfully',
    });
    const completedSig = crypto
      .createHmac('sha256', env.ZR_WEBHOOK_SECRET)
      .update(completedPayload)
      .digest('hex');

    const compRes = await webhookRoutes.request('/ace-step', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-zrs-signature': completedSig,
      },
      body: completedPayload,
    });
    assert.strictEqual(compRes.status, 200, 'Authorized completed callback must return 200');
    job = getJob(webhookGenId);
    assert.strictEqual(job?.status, 'succeeded');
    assert.strictEqual(job?.step, 'ready');
    assert.strictEqual(job?.masterMp3Url, 'https://r2.vhunambi.com/generated/creator/track.wav');

    // 4d: Authorized "failed" callback
    const failGenId = `hook_fail_${Date.now()}`;
    createJob({
      generationId: failGenId,
      trackTitle: 'Fail Test',
      genre: 'Kwaito',
      language: 'zu',
    });
    const failPayload = JSON.stringify({
      job_id: `vhunambi_${failGenId}`,
      status: 'failed',
      error: 'CUDA Out Of Memory on worker',
    });
    const failSig = crypto
      .createHmac('sha256', env.ZR_WEBHOOK_SECRET)
      .update(failPayload)
      .digest('hex');

    const failRes = await webhookRoutes.request('/ace-step', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-zrs-signature': failSig,
      },
      body: failPayload,
    });
    assert.strictEqual(failRes.status, 200);
    const failedJob = getJob(failGenId);
    assert.strictEqual(failedJob?.status, 'failed');
    assert.strictEqual(failedJob?.errorMessage, 'CUDA Out Of Memory on worker');
    console.log('     ✅ webhook route enforces HMAC signature and maps status transitions correctly');
  } finally {
    env.ZR_WEBHOOK_SECRET = originalSecret;
  }

  // Test 5: Active RunPod status polling fallback on GET /v1/generations/:id
  console.log('  5. Testing active RunPod status polling fallback on GET /v1/generations/:id...');
  const pollGenId = `poll_test_${Date.now()}`;
  createJob({
    generationId: pollGenId,
    trackTitle: 'Poll Sync Track',
    genre: 'Maskandi',
    language: 'zu',
    providerTaskId: 'runpod_poll_task_789',
  });

  const pollOriginalKey = env.RUNPOD_API_KEY;
  const pollOriginalEndpoint = env.RUNPOD_ENDPOINT_ID;
  try {
    env.RUNPOD_API_KEY = 'mock_key_poll';
    env.RUNPOD_ENDPOINT_ID = 'mock_endpoint_poll';

    const originalFetch = globalThis.fetch;
    globalThis.fetch = (async (url: string | URL | Request) => {
      const urlStr = url.toString();
      if (urlStr.includes('/status/runpod_poll_task_789')) {
        return new Response(
          JSON.stringify({
            id: 'runpod_poll_task_789',
            status: 'COMPLETED',
            output: {
              audio_url: 'https://r2.vhunambi.com/audio/poll_sync_master.wav',
              stems_zip_url: 'https://r2.vhunambi.com/audio/poll_sync_stems.zip',
            },
          }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        );
      }
      return new Response('Not Found', { status: 404 });
    }) as typeof fetch;

    const { generationRoutes } = await import('../src/routes/generation_routes.js');
    const getRes = await generationRoutes.request(`/${pollGenId}`);
    assert.strictEqual(getRes.status, 200);
    const getData = (await getRes.json()) as any;
    assert.strictEqual(getData.status, 'succeeded');
    assert.strictEqual(getData.masterMp3Url, 'https://r2.vhunambi.com/audio/poll_sync_master.wav');
    assert.strictEqual(getData.stemsZipUrl, 'https://r2.vhunambi.com/audio/poll_sync_stems.zip');

    globalThis.fetch = originalFetch;
    console.log('     ✅ active RunPod status polling fallback synchronizes job state flawlessly');
  } finally {
    env.RUNPOD_API_KEY = pollOriginalKey;
    env.RUNPOD_ENDPOINT_ID = pollOriginalEndpoint;
  }

  console.log('\n🎉 ALL PHASE 16 TESTS PASSED! Cloud & GPU Bridge Verified.\n');
}

runPhase16Tests().catch((err) => {
  console.error('❌ Phase 16 test failed:', err);
  process.exit(1);
});
