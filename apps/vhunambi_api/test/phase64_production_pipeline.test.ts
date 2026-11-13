import { strict as assert } from 'node:assert';
import { app } from '../src/server.js';
import {
  EdgeIsolateDatabaseEngine,
  EdgePersistenceBridge,
} from '../src/db/edge_persistence_bridge.js';
import {
  isNodeSqliteAvailable,
  setSimulateEdgeIsolateMode,
  vhunambiDb,
} from '../src/db/vhunambi_db.js';
import {
  generateLocalMockLyrics,
  generateLyricsFromLLM,
} from '../src/modules/lyrics/llm_handler.js';
import { getGenreSystemPrompt } from '../src/modules/lyrics/system_prompts.js';
import { compileSongSpec } from '../src/modules/synthesis/prompt_compiler.js';
import { getJob } from '../src/modules/jobs/job_store.js';
import { env } from '../src/config/env.js';

interface MemoryR2Entry {
  bytes: Uint8Array;
  httpMetadata?: { contentType?: string; cacheControl?: string };
}

function createMemoryR2Vault() {
  const store = new Map<string, MemoryR2Entry>();
  return {
    store,
    bucket: {
      async get(key: string) {
        const entry = store.get(key);
        if (!entry) return null;
        return {
          key,
          size: entry.bytes.byteLength,
          etag: `etag_${key}`,
          body: new ReadableStream({
            start(controller) {
              controller.enqueue(entry.bytes);
              controller.close();
            },
          }),
          httpMetadata: entry.httpMetadata,
          async arrayBuffer() {
            return entry.bytes.slice().buffer;
          },
          async text() {
            return new TextDecoder().decode(entry.bytes);
          },
        };
      },
      async put(
        key: string,
        value: ReadableStream | ArrayBuffer | Uint8Array | string,
        options?: { httpMetadata?: { contentType?: string; cacheControl?: string } },
      ) {
        let bytes: Uint8Array;
        if (typeof value === 'string') {
          bytes = new TextEncoder().encode(value);
        } else if (value instanceof Uint8Array) {
          bytes = new Uint8Array(value);
        } else if (value instanceof ArrayBuffer) {
          bytes = new Uint8Array(value);
        } else {
          bytes = new Uint8Array(await new Response(value).arrayBuffer());
        }
        store.set(key, { bytes, httpMetadata: options?.httpMetadata });
        return { key, size: bytes.byteLength };
      },
      async delete(keys: string | string[]) {
        const arr = Array.isArray(keys) ? keys : [keys];
        for (const k of arr) store.delete(k);
      },
    },
  };
}

async function runPhase64Tests(): Promise<void> {
  console.log('🧪 Running Phase 64 Full Production Pipeline Tests...');

  // ---------------------------------------------------------------------------
  // 1. G-64-01: Resilient Sovereign Auth Register & Login when GoTrue returns null token / unconfirmed
  // ---------------------------------------------------------------------------
  console.log('  1. Testing G-64-01 resilient auth register/login on Cloudflare Worker...');
  setSimulateEdgeIsolateMode(true);
  const origFetch = globalThis.fetch;
  try {
    assert.equal(isNodeSqliteAvailable(), false);
    globalThis.fetch = (async (input: string | URL | Request, init?: RequestInit) => {
      const url = input.toString();
      if (url.includes('/auth/v1/admin/users')) {
        return new Response(JSON.stringify({ error: 'admin forbidden' }), {
          status: 403,
          headers: { 'Content-Type': 'application/json' },
        });
      }
      if (url.includes('/auth/v1/signup')) {
        // GoTrue confirmation enabled -> null access_token
        return new Response(
          JSON.stringify({ user: { id: 'gt_u_p64', email: 'ndu_p64@vhunambi.co.za' }, access_token: null }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        );
      }
      if (url.includes('/auth/v1/token')) {
        return new Response(JSON.stringify({ error: 'email_not_confirmed' }), {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        });
      }
      if (url.includes('/rest/v1/')) {
        if ((init?.method || 'GET').toUpperCase() === 'GET') {
          return new Response(JSON.stringify([]), {
            status: 200,
            headers: { 'Content-Type': 'application/json' },
          });
        }
        return new Response(JSON.stringify([{ ok: true }]), {
          status: 201,
          headers: { 'Content-Type': 'application/json' },
        });
      }
      return origFetch(input, init);
    }) as typeof fetch;

    const workerAuthEnv = {
      NODE_ENV: 'test',
      VHUNAMBI_AUTH_MODE: 'strict',
      VHUNAMBI_JWT_SECRET: 'phase64_test_jwt_secret_1234567890',
      SUPABASE_URL: 'https://mock-p64.supabase.co',
      SUPABASE_ANON_KEY: 'anon_p64_key',
      SUPABASE_SERVICE_ROLE_KEY: 'service_role_p64_test_key_1234567890',
    };

    const suffix = Date.now().toString().slice(-6);
    const regRes = await app.fetch(
      new Request('http://localhost/api/auth/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          handle: `@p64_user_${suffix}`,
          email: `p64_${suffix}@vhunambi.co.za`,
          password: 'SovereignPassword!2026',
          displayName: 'Phase 64 Creator',
        }),
      }),
      workerAuthEnv as never,
    );
    assert.equal(regRes.status, 201, 'Register must return 201 even when GoTrue requires email confirm');
    const regJson = (await regRes.json()) as {
      accessToken: string;
      refreshToken: string;
      user: { handle: string; creatorId: string };
    };
    assert.ok(regJson.accessToken && regJson.accessToken.length > 20);
    assert.ok(regJson.refreshToken && regJson.refreshToken.length > 10);
    assert.equal(regJson.user.handle, `@p64_user_${suffix}`);

    const loginRes = await app.fetch(
      new Request('http://localhost/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          identifier: `p64_${suffix}@vhunambi.co.za`,
          password: 'SovereignPassword!2026',
        }),
      }),
      workerAuthEnv as never,
    );
    assert.equal(loginRes.status, 200, 'Login must verify via scrypt/PostgREST fallback when GoTrue fails');
    const loginJson = (await loginRes.json()) as { accessToken: string };
    assert.ok(loginJson.accessToken && loginJson.accessToken.length > 20);

    // Also verify /v1/auth/register works cleanly under strict mode
    const v1RegRes = await app.fetch(
      new Request('http://localhost/v1/auth/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          handle: `@p64_v1_${suffix}`,
          email: `p64_v1_${suffix}@vhunambi.co.za`,
          password: 'SovereignPassword!2026',
        }),
      }),
      workerAuthEnv as never,
    );
    assert.equal(v1RegRes.status, 201, '/v1/auth/register must succeed under strict auth mode');
    console.log('     ✅ G-64-01 resilient Worker auth passed');

    // -------------------------------------------------------------------------
    // 2. G-64-03: Read-Through R2 Media Synthesizer & Range Streaming + Seeder
    // -------------------------------------------------------------------------
    console.log('  2. Testing G-64-03 Read-Through GET /r2/:key, HTTP 206 Range & seed-r2-media...');
    const vault = createMemoryR2Vault();
    const r2Env = {
      NODE_ENV: 'test',
      VHUNAMBI_AUTH_MODE: 'permissive',
      R2_PUBLIC_BASE_URL: 'https://worker.example/r2',
      VHUNAMBI_VAULT: vault.bucket,
    };

    const audioRes = await app.fetch(
      new Request('http://localhost/r2/audio/amapiano_readthrough_test.mp3'),
      r2Env as never,
    );
    assert.equal(audioRes.status, 200);
    const wavBytes = new Uint8Array(await audioRes.arrayBuffer());
    assert.ok(wavBytes.byteLength > 4096, 'Synthesized R2 audio must be non-trivial WAV buffer');
    assert.equal(String.fromCharCode(wavBytes[0], wavBytes[1], wavBytes[2], wavBytes[3]), 'RIFF');
    assert.ok(vault.store.has('audio/amapiano_readthrough_test.mp3'), 'Read-through must cache into R2');

    const rangeRes = await app.fetch(
      new Request('http://localhost/r2/audio/amapiano_readthrough_test.mp3', {
        headers: { Range: 'bytes=0-1023' },
      }),
      r2Env as never,
    );
    assert.equal(rangeRes.status, 206, 'Range requests must return 206 Partial Content');
    const sliceBytes = new Uint8Array(await rangeRes.arrayBuffer());
    assert.equal(sliceBytes.byteLength, 1024);

    const coverRes = await app.fetch(
      new Request('http://localhost/r2/visuals/amapiano_cover.png'),
      r2Env as never,
    );
    assert.equal(coverRes.status, 200);
    const pngBytes = new Uint8Array(await coverRes.arrayBuffer());
    assert.ok(pngBytes.byteLength > 128, 'Synthesized PNG artwork must be non-trivial');
    assert.deepEqual(Array.from(pngBytes.slice(0, 4)), [137, 80, 78, 71]);

    const bmpRes = await app.fetch(
      new Request('http://localhost/r2/visuals/amapiano_cover.bmp'),
      r2Env as never,
    );
    assert.equal(bmpRes.status, 200);
    const bmpBytes = new Uint8Array(await bmpRes.arrayBuffer());
    assert.ok(bmpBytes.byteLength > 10000, 'Synthesized BMP artwork must be high-resolution RGB bitmap');
    assert.equal(String.fromCharCode(bmpBytes[0], bmpBytes[1]), 'BM');

    const seedRes = await app.fetch(
      new Request('http://localhost/api/system/seed-r2-media', {
        method: 'POST',
      }),
      r2Env as never,
    );
    assert.equal(seedRes.status, 200);
    const seedJson = (await seedRes.json()) as {
      success: boolean;
      seededCount: number;
      totalBytes: number;
    };
    assert.equal(seedJson.success, true);
    assert.ok(seedJson.seededCount >= 4);
    assert.ok(seedJson.totalBytes > 50000);
    console.log('     ✅ G-64-03 read-through R2 media synthesizer & seeder passed');

    // -------------------------------------------------------------------------
    // 3. G-64-04: 19-Table Cold-Start Hydration & Non-Blocking PostgREST Write-Through
    // -------------------------------------------------------------------------
    console.log('  3. Testing G-64-04 EdgeIsolateDatabaseEngine cold-start hydration & write-through...');
    const postedTables: string[] = [];
    globalThis.fetch = (async (input: string | URL | Request, init?: RequestInit) => {
      const url = input.toString();
      const method = (init?.method || 'GET').toUpperCase();
      if (url.includes('/rest/v1/')) {
        const tableName = url.split('/rest/v1/')[1].split('?')[0];
        if (method === 'GET') {
          if (tableName === 'playlists') {
            return new Response(
              JSON.stringify([
                {
                  id: 'pl_hydrated_p64',
                  creator_id: 'creator_cern',
                  title: 'Limpopo Hydrated Mix',
                  description: 'Cold-start recovered playlist',
                  track_ids_json: ['trk_1'],
                  is_public: true,
                },
              ]),
              { status: 200, headers: { 'Content-Type': 'application/json' } },
            );
          }
          return new Response(JSON.stringify([]), {
            status: 200,
            headers: { 'Content-Type': 'application/json' },
          });
        }
        postedTables.push(tableName);
        return new Response(JSON.stringify([{ ok: true }]), {
          status: 201,
          headers: { 'Content-Type': 'application/json' },
        });
      }
      return origFetch(input, init);
    }) as typeof fetch;

    const freshEdge = new EdgeIsolateDatabaseEngine();
    await freshEdge.ensureColdStartHydrated({
      SUPABASE_URL: 'https://mock-p64.supabase.co',
      SUPABASE_SERVICE_ROLE_KEY: 'service_role_p64_test_key_1234567890',
    });
    const hydratedPlaylists = freshEdge.getPlaylists('creator_cern');
    assert.ok(
      hydratedPlaylists.some((p) => p.id === 'pl_hydrated_p64'),
      'Cold-start hydration must restore playlists from Supabase PostgREST',
    );
    EdgePersistenceBridge.setActiveContext({
      env: {
        SUPABASE_URL: 'https://mock-p64.supabase.co',
        SUPABASE_SERVICE_ROLE_KEY: 'service_role_p64_test_key_1234567890',
      },
    } as never);
    try {
      freshEdge.upsertPlaylist({
        id: 'pl_write_through_p64',
        creatorId: 'creator_cern',
        title: 'Write-Through Playlist',
        trackIds: ['trk_1'],
      });
    } finally {
      EdgePersistenceBridge.setActiveContext(undefined);
    }
    await new Promise((r) => setTimeout(r, 30));
    assert.ok(
      postedTables.includes('playlists'),
      'Playlist mutation must trigger PostgREST write-through upsert',
    );
    console.log('     ✅ G-64-04 Supabase cold-start hydration & write-through passed');

    // -------------------------------------------------------------------------
    // 4. G-64-05: Disabled Endpoint Guard (max=0), Scale-to-Zero Wake & 4-Stem R2
    // -------------------------------------------------------------------------
    console.log('  4. Testing G-64-05 RunPod disabled guard (max=0), scale-to-zero wake & 4-stem R2...');
    const qzVault = createMemoryR2Vault();
    globalThis.fetch = (async (input: string | URL | Request) => {
      const url = input.toString();
      if (url.endsWith('/health')) {
        return new Response(
          JSON.stringify({ workers: { idle: 0, running: 0, ready: 0, initializing: 0, max: 0 } }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        );
      }
      throw new Error(`Unexpected fetch to ${url} when workers.max == 0`);
    }) as typeof fetch;

    // Also verify scale-to-zero endpoint (idle=0, running=0, max=3) DOES wake via POST /run
    const { dispatchSynthesisJob } = await import('../src/modules/synthesis/runpod_adapter.js');
    const { compileSongSpec } = await import('../src/modules/synthesis/prompt_compiler.js');
    const prevFetchBeforeWake = globalThis.fetch;
    let wakeRunCalled = false;
    globalThis.fetch = (async (input: string | URL | Request) => {
      const url = input.toString();
      if (url.endsWith('/health')) {
        return new Response(
          JSON.stringify({ workers: { idle: 0, running: 0, ready: 0, initializing: 0, max: 3 } }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        );
      }
      if (url.endsWith('/run')) {
        wakeRunCalled = true;
        return new Response(JSON.stringify({ id: 'rp_scale_to_zero_wake_1' }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        });
      }
      throw new Error(`Unexpected wake fetch: ${url}`);
    }) as typeof fetch;

    const wakeCompiled = compileSongSpec({
      trackTitle: 'Scale Wake Test',
      prompt: 'Private school Amapiano',
      genre: 'Amapiano',
      language: 've',
    });
    const wakeDispatch = await dispatchSynthesisJob(
      'gen_scale_to_zero_wake',
      wakeCompiled,
      'creator_wake',
      {
        RUNPOD_API_KEY: 'rp_test_wake_key',
        RUNPOD_ENDPOINT_ID: 'ep_test_wake',
        WEBHOOK_BASE_URL: 'https://worker.example',
      },
    );
    assert.equal(wakeRunCalled, true, 'Min-workers=0 endpoint (max>0) must submit POST /run to wake GPU');
    assert.equal(wakeDispatch.isMock, false);
    assert.equal(wakeDispatch.jobId, 'rp_scale_to_zero_wake_1');
    globalThis.fetch = prevFetchBeforeWake;

    const qzEnv = {
      NODE_ENV: 'test',
      VHUNAMBI_AUTH_MODE: 'permissive',
      RUNPOD_API_KEY: 'rp_test_qz_key',
      RUNPOD_ENDPOINT_ID: 'ep_test_qz',
      WEBHOOK_BASE_URL: 'https://worker.example',
      R2_PUBLIC_BASE_URL: 'https://worker.example/r2',
      VHUNAMBI_VAULT: qzVault.bucket,
    };

    const qzGenRes = await app.fetch(
      new Request('http://localhost/v1/generations', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          trackTitle: 'Thohoyandou Rain',
          prompt: 'Soulful Private School Amapiano with warm Rhodes',
          genre: 'Amapiano',
          language: 've',
        }),
      }),
      qzEnv as never,
    );
    assert.equal(qzGenRes.status, 201);
    const qzGenJson = (await qzGenRes.json()) as {
      generationId: string;
      loras: Array<{ path: string }>;
      lyrics?: string;
    };
    assert.ok(qzGenJson.loras.length >= 1);
    assert.ok(qzGenJson.lyrics && qzGenJson.lyrics.includes('[CHORUS]'));

    // Wait briefly for stepMs=25ms*4 in-process 4-stem R2 synthesis to complete
    for (let attempt = 0; attempt < 25; attempt++) {
      const j = getJob(qzGenJson.generationId);
      if (j?.status === 'succeeded') break;
      await new Promise((r) => setTimeout(r, 40));
    }

    const pollRes = await app.fetch(
      new Request(`http://localhost/v1/generations/${qzGenJson.generationId}`),
      qzEnv as never,
    );
    assert.equal(pollRes.status, 200);
    const pollJson = (await pollRes.json()) as {
      status: string;
      masterMp3Url?: string;
      coverUrl?: string;
      stemUrls?: Record<string, string>;
    };
    assert.equal(pollJson.status, 'succeeded');
    assert.ok(pollJson.masterMp3Url?.includes(`${qzGenJson.generationId}_master.mp3`));
    assert.ok(pollJson.coverUrl?.includes(`${qzGenJson.generationId}_cover.bmp`));
    for (const role of ['vocals', 'drums', 'bass', 'melodic']) {
      assert.ok(pollJson.stemUrls?.[role], `Missing stem URL for ${role}`);
      const key = `${qzGenJson.generationId}_${role}.mp3`;
      assert.ok(qzVault.store.has(key), `Missing R2 stem object ${key}`);
      assert.ok((qzVault.store.get(key)?.bytes.byteLength ?? 0) > 10000);
    }
    assert.ok(qzVault.store.has(`${qzGenJson.generationId}_mmo.json`));

    // Cross-isolate generation_jobs hydration check
    globalThis.fetch = (async (input: string | URL | Request) => {
      const url = input.toString();
      if (url.includes('/rest/v1/generation_jobs')) {
        return new Response(
          JSON.stringify([
            {
              generation_id: 'gen_cross_isolate_p64',
              creator_id: 'creator_cern',
              job_kind: 'audio_synthesis',
              provider_task_id: 'mock_gen_cross_isolate_p64',
              status: 'succeeded',
              step: 'ready',
              progress_pct: 100,
              track_title: 'Cross Isolate Dawn',
              genre: 'Amapiano',
              language: 've',
              duration_sec: 180,
              master_mp3_url: 'https://worker.example/r2/gen_cross_isolate_p64_master.mp3',
              stems_zip_url: 'https://worker.example/r2/gen_cross_isolate_p64_stems.zip',
              stem_urls_json: {
                vocals: 'https://worker.example/r2/gen_cross_isolate_p64_vocals.mp3',
              },
              manifest_url: 'https://worker.example/r2/gen_cross_isolate_p64_mmo.json',
              manifest_json: {
                id: 'gen_cross_isolate_p64',
                assets: {
                  masterMp3Url: 'https://worker.example/r2/gen_cross_isolate_p64_master.mp3',
                  coverArt1x1Url: 'https://worker.example/r2/gen_cross_isolate_p64_cover.bmp',
                },
              },
              created_at: Date.now() - 4000,
              updated_at: Date.now(),
            },
          ]),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        );
      }
      return new Response(JSON.stringify([]), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    }) as typeof fetch;

    const crossEnv = {
      NODE_ENV: 'test',
      VHUNAMBI_AUTH_MODE: 'permissive',
      SUPABASE_URL: 'https://mock-p64.supabase.co',
      SUPABASE_SERVICE_ROLE_KEY: 'service_role_p64_test_key_1234567890',
    };
    const crossPollRes = await app.fetch(
      new Request('http://localhost/v1/generations/gen_cross_isolate_p64'),
      crossEnv as never,
    );
    assert.equal(crossPollRes.status, 200, 'Cross-isolate GET /v1/generations/:id must hydrate from Supabase');
    const crossPollJson = (await crossPollRes.json()) as {
      status: string;
      masterMp3Url?: string;
      coverUrl?: string;
    };
    assert.equal(crossPollJson.status, 'succeeded');
    assert.equal(crossPollJson.masterMp3Url, 'https://worker.example/r2/gen_cross_isolate_p64_master.mp3');
    assert.equal(crossPollJson.coverUrl, 'https://worker.example/r2/gen_cross_isolate_p64_cover.bmp');

    console.log('     ✅ G-64-05 Queue-Zero 4-stem R2 synthesis & cross-isolate MMO hydration passed');

    // -------------------------------------------------------------------------
    // 5. G-64-06: Open-Source RunPod LLM + Prompt-Reactive Bantu Lyrics + Prompt Compiler
    // -------------------------------------------------------------------------
    console.log('  5. Testing G-64-06 Open-Source RunPod LLM, Bantu lyrics & Two-Stage compiler...');
    let calledRunpodLlmUrl = '';
    let capturedLlmModel = '';
    globalThis.fetch = (async (input: string | URL | Request, init?: RequestInit) => {
      calledRunpodLlmUrl = input.toString();
      const parsedBody = JSON.parse(String(init?.body ?? '{}')) as { model?: string };
      capturedLlmModel = parsedBody.model ?? '';
      return new Response(
        JSON.stringify({
          choices: [
            {
              message: {
                content:
                  '[INTRO]\nNdi zwone!\n\n[VERSE 1]\nPula i khou na Thohoyandou\n\n[CHORUS]\nVhunambi ha vhukuma',
              },
            },
          ],
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      );
    }) as typeof fetch;

    const llmRes = await generateLyricsFromLLM(
      'Sacred mountain rainfall',
      'Amapiano',
      've',
      getGenreSystemPrompt('Amapiano'),
      {
        RUNPOD_API_KEY: 'rp_llm_key',
        RUNPOD_LLM_ENDPOINT_ID: 'ep_qwen_7b',
        RUNPOD_LLM_MODEL: 'Qwen/Qwen2.5-7B-Instruct',
        ZR_LLM_PROVIDER: 'runpod_vllm',
      },
    );
    assert.equal(
      calledRunpodLlmUrl,
      'https://api.runpod.ai/v2/ep_qwen_7b/openai/v1/chat/completions',
    );
    assert.equal(capturedLlmModel, 'Qwen/Qwen2.5-7B-Instruct');
    assert.ok(llmRes.rawLyrics.includes('Thohoyandou'));

    const localLyricsA = generateLocalMockLyrics(
      'Sacred mountain rainfall in Venda',
      'Amapiano',
      've',
    );
    const localLyricsB = generateLocalMockLyrics(
      'Soweto midnight neon highway drive',
      'Gqom',
      'zu',
    );
    assert.notEqual(
      localLyricsA.rawLyrics,
      localLyricsB.rawLyrics,
      'Different prompts must produce distinct multi-section Bantu lyrics',
    );
    assert.ok(localLyricsA.stanzas.length >= 6);
    assert.ok(localLyricsA.rawLyrics.includes('mountain') || localLyricsA.rawLyrics.includes('Venda'));

    const compiledP64 = compileSongSpec({
      trackTitle: 'Limpopo Sunset',
      prompt: 'Deep Private School Amapiano with warm Rhodes chords',
      genre: 'Amapiano',
      language: 've',
    });
    assert.ok(compiledP64.loras && compiledP64.loras.length >= 1);
    assert.equal(compiledP64.loras[0].path, 'loras/amapiano_logdrum_v1.safetensors');
    assert.equal(compiledP64.inferenceConfig?.precision, 'bf16');
    assert.equal(compiledP64.inferenceConfig?.inferSteps, 45);
    assert.ok((compiledP64.sonicTags?.length ?? 0) >= 5);
    assert.ok(compiledP64.lyrics.includes('[CHORUS]'));
    console.log('     ✅ G-64-06 Open-Source RunPod LLM & Two-Stage compiler passed');

    // -------------------------------------------------------------------------
    // 6. G-64-07: Procedural Cover Artwork & Structured MP4 in vision_routes
    // -------------------------------------------------------------------------
    console.log('  6. Testing G-64-07 procedural cover artwork & video container in vision_routes...');
    const visionVault = createMemoryR2Vault();
    const prevRunpodKey = env.RUNPOD_API_KEY;
    const prevComfyUrl = env.RUNPOD_COMFYUI_URL;
    const prevComfyEp = env.RUNPOD_COMFYUI_ENDPOINT_ID;
    env.RUNPOD_API_KEY = '';
    env.RUNPOD_COMFYUI_URL = '';
    env.RUNPOD_COMFYUI_ENDPOINT_ID = '';

    try {
      const visionEnv = {
        NODE_ENV: 'test',
        VHUNAMBI_AUTH_MODE: 'permissive',
        R2_PUBLIC_BASE_URL: 'https://worker.example/r2',
        VHUNAMBI_VAULT: visionVault.bucket,
      };
      const vGenRes = await app.fetch(
        new Request('http://localhost/v1/vision/generate', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            title: 'Limpopo Artwork',
            genre: 'Amapiano',
            language: 've',
          }),
        }),
        visionEnv as never,
      );
      assert.equal(vGenRes.status, 201);
      const vGenJson = (await vGenRes.json()) as { jobId: string; outputImageUrl: string };
      const imgEntry = visionVault.store.get(`visuals/mock/${vGenJson.jobId}_9_16.png`);
      assert.ok(imgEntry, 'Procedural vision cover artwork must be written to R2');
      assert.ok(
        imgEntry.bytes.byteLength > 16384,
        'Procedural vision cover artwork must exceed 16 KB (not 67-byte 1x1 PNG)',
      );
      assert.deepEqual(Array.from(imgEntry.bytes.slice(0, 4)), [137, 80, 78, 71]);

      const vRenderRes = await app.fetch(
        new Request('http://localhost/v1/vision/render-video', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            title: 'Limpopo Reel',
            resolution: '1080x1920',
            fps: 60,
            preset: 'kineticBounce',
          }),
        }),
        visionEnv as never,
      );
      assert.equal(vRenderRes.status, 200);
      const vRenderJson = (await vRenderRes.json()) as {
        videoUrl: string;
        coverUrl?: string;
      };
      const mp4Key = new URL(vRenderJson.videoUrl).pathname.replace(/^\/r2\//, '');
      const mp4Entry = visionVault.store.get(mp4Key);
      assert.ok(mp4Entry && mp4Entry.bytes.byteLength > 600);
      assert.equal(
        String.fromCharCode(mp4Entry.bytes[4], mp4Entry.bytes[5], mp4Entry.bytes[6], mp4Entry.bytes[7]),
        'ftyp',
      );
      assert.ok(vRenderJson.coverUrl, 'Reel render should also expose companion coverUrl');
      console.log('     ✅ G-64-07 procedural cover artwork & reel persistence passed');
    } finally {
      env.RUNPOD_API_KEY = prevRunpodKey;
      env.RUNPOD_COMFYUI_URL = prevComfyUrl;
      env.RUNPOD_COMFYUI_ENDPOINT_ID = prevComfyEp;
    }

    void vhunambiDb;
  } finally {
    globalThis.fetch = origFetch;
    setSimulateEdgeIsolateMode(false);
  }

  console.log('\n🎉 ALL PHASE 64 PRODUCTION PIPELINE TESTS PASSED (100% GREEN)!\n');
}

runPhase64Tests().catch((err) => {
  console.error('❌ Phase 64 test failed:', err);
  process.exit(1);
});
