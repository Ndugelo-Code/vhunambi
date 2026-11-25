import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { app } from '../src/server.js';
import { resolveRuntimeEnv } from '../src/config/env.js';
import { vhunambiDb } from '../src/db/vhunambi_db.js';
import { createJob, getJob } from '../src/modules/jobs/job_store.js';
import { resolveRecommendedLoraForGenre } from '../src/modules/synthesis/lora_catalog.js';

async function run(): Promise<void> {
  console.log('[Phase 83 Test] Running Worker African LoRA Catalog & /repaint suite...');

  // 1. Canonical LoRA Catalog GET /v1/studio/loras + 42-genre resolution
  {
    assert.equal(resolveRecommendedLoraForGenre('Private School Amapiano').loraId, 'amapiano_private_school_v1');
    assert.equal(resolveRecommendedLoraForGenre('Sgija').loraId, 'sgija_bacardi_v1');
    assert.equal(resolveRecommendedLoraForGenre('Malende').loraId, 'venda_malende_v1');
    assert.equal(resolveRecommendedLoraForGenre('Lekompo').loraId, 'venda_malende_v1');
    assert.equal(resolveRecommendedLoraForGenre('Isicathamiya').loraId, 'afro_gospel_choir_v1');

    const res = await app.fetch(
      new Request('http://localhost/v1/studio/loras?genre=Private%20School%20Amapiano'),
    );
    assert.equal(res.status, 200);
    const json = (await res.json()) as Record<string, any>;
    assert.equal(json.success, true);
    assert.equal(json.totalCount, 10);
    assert.equal(json.recommended.loraId, 'amapiano_private_school_v1');
    assert.equal(json.packs.length, 10);
    console.log('  [PASS] GET /v1/studio/loras & 42-genre canonical resolution');
  }

  // 2. Explicit loras[] override forwarded on POST /v1/generations + normalized weight <= 1.35
  {
    const originalFetch = globalThis.fetch;
    const runPayloads: Array<Record<string, any>> = [];
    globalThis.fetch = (async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = typeof input === 'string' ? input : input.toString();
      if (url.endsWith('/health')) {
        return new Response(
          JSON.stringify({ workers: { idle: 1, running: 0, initializing: 0, ready: 1, max: 2 } }),
          { status: 200, headers: { 'content-type': 'application/json' } },
        );
      }
      if (url.endsWith('/run')) {
        runPayloads.push(JSON.parse(String(init?.body ?? '{}')));
        return new Response(JSON.stringify({ id: 'rp_p83_lora_gen' }), {
          status: 200,
          headers: { 'content-type': 'application/json' },
        });
      }
      return originalFetch(input, init);
    }) as typeof fetch;

    const prevKey = process.env.RUNPOD_API_KEY;
    const prevEp = process.env.RUNPOD_ENDPOINT_ID;
    process.env.RUNPOD_API_KEY = 'rp_p83_key';
    process.env.RUNPOD_ENDPOINT_ID = 'ep_p83';

    try {
      const genRes = await app.fetch(
        new Request('http://localhost/v1/generations', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            trackTitle: 'LoRA Fusion Track',
            genre: 'Amapiano',
            language: 've',
            engineTier: 'sovereign_custom',
            loras: [
              { loraId: 'amapiano_private_school_v1', weight: 1.0 },
              { loraId: 'venda_malende_v1', weight: 1.0 },
            ],
          }),
        }),
      );
      assert.equal(genRes.status, 201);
      assert.equal(runPayloads.length, 1);
      const sentLoras = runPayloads[0].input.loras as Array<Record<string, any>>;
      assert.equal(sentLoras.length, 2);
      assert.equal(sentLoras[0].lora_id, 'amapiano_private_school_v1');
      assert.equal(sentLoras[1].lora_id, 'venda_malende_v1');
      const sumW = Number(sentLoras[0].weight) + Number(sentLoras[1].weight);
      assert.ok(sumW <= 1.351, `Expected normalized weight sum <= 1.35, got ${sumW}`);
    } finally {
      globalThis.fetch = originalFetch;
      if (prevKey === undefined) delete process.env.RUNPOD_API_KEY;
      else process.env.RUNPOD_API_KEY = prevKey;
      if (prevEp === undefined) delete process.env.RUNPOD_ENDPOINT_ID;
      else process.env.RUNPOD_ENDPOINT_ID = prevEp;
    }
    console.log('  [PASS] POST /v1/generations forwards explicit normalized loras[]');
  }

  // 3. POST /v1/generations/:id/repaint validation + RunPod section_repaint dispatch + parent repaintHistory
  {
    const parentId = 'gen_p83_parent_01';
    createJob({
      generationId: parentId,
      creatorId: 'creator_cern',
      trackTitle: 'Venda Horizon Master',
      genre: 'Malende',
      language: 've',
      durationSec: 180,
      status: 'succeeded',
      step: 'ready',
      progressPct: 100,
      masterMp3Url: 'https://cdn.vhunambi.com/masters/p83_parent.mp3',
      stemUrls: {
        vocals: 'https://cdn.vhunambi.com/stems/p83_vocals.wav',
        drums: 'https://cdn.vhunambi.com/stems/p83_drums.wav',
        bass: 'https://cdn.vhunambi.com/stems/p83_bass.wav',
        melodic: 'https://cdn.vhunambi.com/stems/p83_melodic.wav',
      },
    });

    // Reject invalid < 2s span
    const badRes = await app.fetch(
      new Request(`http://localhost/v1/generations/${parentId}/repaint`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ startSec: 10, endSec: 11, task: 'repaint' }),
      }),
    );
    assert.equal(badRes.status, 400);

    // Reject unknown parent ID
    const res404 = await app.fetch(
      new Request('http://localhost/v1/generations/gen_missing_p83/repaint', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ startSec: 10, endSec: 26, task: 'repaint' }),
      }),
    );
    assert.equal(res404.status, 404);

    const originalFetch = globalThis.fetch;
    const capturedRepaints: Array<Record<string, any>> = [];
    globalThis.fetch = (async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = typeof input === 'string' ? input : input.toString();
      if (url.endsWith('/run')) {
        capturedRepaints.push(JSON.parse(String(init?.body ?? '{}')));
        return new Response(JSON.stringify({ id: 'rp_p83_repaint_job' }), {
          status: 200,
          headers: { 'content-type': 'application/json' },
        });
      }
      return originalFetch(input, init);
    }) as typeof fetch;

    const prevKey = process.env.RUNPOD_API_KEY;
    const prevEp = process.env.RUNPOD_ENDPOINT_ID;
    process.env.RUNPOD_API_KEY = 'rp_p83_key';
    process.env.RUNPOD_ENDPOINT_ID = 'ep_p83';

    let repaintId = '';
    try {
      const rpRes = await app.fetch(
        new Request(`http://localhost/v1/generations/${parentId}/repaint`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            startSec: 16,
            endSec: 32,
            task: 'repaint',
            targetStem: 'melodic',
            stemLocks: {
              node_beat_tempo: 'lockedPure44k',
              vocals: 'lockedPure44k',
            },
            editLyrics: '[Chorus]\nRi khou imba zwa vhuḓi',
            loras: [{ loraId: 'venda_malende_v1', weight: 0.9 }],
          }),
        }),
      );
      assert.equal(rpRes.status, 201);
      const rpJson = (await rpRes.json()) as Record<string, any>;
      repaintId = rpJson.generationId;
      assert.equal(rpJson.parentGenerationId, parentId);
      assert.equal(rpJson.resolvedEngine, 'ace_step_xl_base');
      assert.equal(rpJson.stemLocks.drums, 'lockedPure44k');
      assert.equal(rpJson.stemLocks.vocals, 'lockedPure44k');
      assert.equal(capturedRepaints[0].input.job_type, 'section_repaint');
      assert.equal(capturedRepaints[0].input.repaint_config.start_sec, 16);
      assert.equal(capturedRepaints[0].input.repaint_config.end_sec, 32);
    } finally {
      globalThis.fetch = originalFetch;
      if (prevKey === undefined) delete process.env.RUNPOD_API_KEY;
      else process.env.RUNPOD_API_KEY = prevKey;
      if (prevEp === undefined) delete process.env.RUNPOD_ENDPOINT_ID;
      else process.env.RUNPOD_ENDPOINT_ID = prevEp;
    }

    // Webhook completion appends repaintHistory onto parent & persists loraMetrics
    const whBody = JSON.stringify({
      job_id: `vhunambi_${repaintId}`,
      status: 'completed',
      audio_url: 'https://cdn.vhunambi.com/masters/p83_repainted.mp3',
      resolved_engine: 'ace_step_xl_base',
      lora_metrics: {
        requested_count: 1,
        loaded_count: 1,
        loaded_loras: [
          {
            lora_id: 'venda_malende_v1',
            r2_key: 'loras/venda_malende_v1.safetensors',
            weight: 0.9,
            sha256: 'abc123',
            loaded: true,
          },
        ],
      },
      repaint_metadata: {
        parent_job_id: parentId,
        task: 'repaint',
        start_sec: 16,
        end_sec: 32,
        target_stem: 'melodic',
        stem_locks: { drums: 'lockedPure44k', vocals: 'lockedPure44k' },
      },
    });
    const secret = resolveRuntimeEnv().ZR_WEBHOOK_SECRET;
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (secret) {
      headers['x-zrs-signature'] = crypto
        .createHmac('sha256', secret)
        .update(whBody)
        .digest('hex');
    }
    const whRes = await app.fetch(
      new Request('http://localhost/v1/webhooks/ace-step', {
        method: 'POST',
        headers,
        body: whBody,
      }),
    );
    assert.equal(whRes.status, 200);

    const parentCheck = await app.fetch(
      new Request(`http://localhost/v1/generations/${parentId}`),
    );
    assert.equal(parentCheck.status, 200);
    const parentJson = (await parentCheck.json()) as Record<string, any>;
    assert.equal(Array.isArray(parentJson.repaintHistory), true);
    assert.equal(parentJson.repaintHistory.length, 1);
    assert.equal(parentJson.repaintHistory[0].repaintId, repaintId);
    assert.equal(parentJson.repaintHistory[0].activeLoras[0], 'venda_malende_v1');

    const childJob = getJob(repaintId);
    assert.equal(childJob?.loraMetrics?.loadedCount, 1);
    assert.ok(vhunambiDb.getGenerationJob(parentId));
    console.log('  [PASS] POST /:id/repaint + RunPod dispatch + parent repaintHistory persistence');
  }

  console.log('[Phase 83 Test] All checks PASSED.');
}

run().catch((err) => {
  console.error('[Phase 83 Test] FAILED:', err);
  process.exit(1);
});
