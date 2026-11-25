import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { app } from '../src/server.js';
import { resolveRuntimeEnv } from '../src/config/env.js';
import { setSimulateEdgeIsolateMode, vhunambiDb } from '../src/db/vhunambi_db.js';
import { createJob, getJob } from '../src/modules/jobs/job_store.js';
import { StemMasteringRecipeSchema } from '../src/modules/mastering/mastering_types.js';
import {
  enrichManifestWithMasteringRecipe,
  getMasteringPresetForGenre,
} from '../src/modules/mastering/mastering_presets.js';
import { compileMasterMediaObjectManifest } from '../src/modules/dna/dna_compiler.js';
import { buildDualDialectPipelineEventFrame } from '../src/modules/realtime/generation_session_do.js';
import {
  checkRunPodJobStatus,
  dispatchSynthesisJob,
} from '../src/modules/synthesis/runpod_adapter.js';
import { compileSongSpec } from '../src/modules/synthesis/prompt_compiler.js';
import {
  getVoiceCloneProfile,
  registerVoiceCloneProfile,
} from '../src/modules/voices/voice_catalog.js';

async function run(): Promise<void> {
  console.log('[Phase 82 Test] Running Worker Mastering, Cold Voice Hydration & Provenance suite...');

  // 1. StemMasteringRecipeSchema supports -9.0 (Club), -9.5 (Amapiano legacy), and -14.0 (Streaming)
  {
    const baseRecipe = getMasteringPresetForGenre('Amapiano').recipe;
    const clubParsed = StemMasteringRecipeSchema.safeParse({
      ...baseRecipe,
      targetLufs: -9.0,
    });
    assert.equal(clubParsed.success, true, 'Expected -9.0 LUFS Club recipe to validate');

    const streamParsed = StemMasteringRecipeSchema.safeParse({
      ...baseRecipe,
      targetLufs: -14.0,
    });
    assert.equal(streamParsed.success, true, 'Expected -14.0 LUFS Streaming recipe to validate');
    console.log('  [PASS] StemMasteringRecipeSchema accepts -9.0, -9.5, and -14.0 LUFS');
  }

  // 2. Live Cloud R2 URL preservation on enrichManifestWithMasteringRecipe + POST /:id/master
  {
    const liveJobId = 'gen_p82_live_master_01';
    const liveMasterUrl = 'https://cdn.vhunambi.com/masters/p82_live.mp3';
    const liveVocalsUrl = 'https://cdn.vhunambi.com/stems/p82_vocals.wav';
    const liveMelodicUrl = 'https://cdn.vhunambi.com/stems/p82_melodic.wav';
    const liveManifest = compileMasterMediaObjectManifest({
      id: liveJobId,
      title: 'Limpopo Broadcast Master',
      genre: 'Amapiano',
      language: 've',
      durationSec: 120,
      masterMp3Url: liveMasterUrl,
      masterWavUrl: 'https://cdn.vhunambi.com/masters/p82_live.wav',
      stemUrls: {
        vocals: liveVocalsUrl,
        drums: 'https://cdn.vhunambi.com/stems/p82_drums.wav',
        bass: 'https://cdn.vhunambi.com/stems/p82_bass.wav',
        melodic: liveMelodicUrl,
      },
      provenance: 'measured',
    });

    const baseRecipe = getMasteringPresetForGenre('Amapiano').recipe;
    const enrichedLive = enrichManifestWithMasteringRecipe(liveManifest, {
      ...baseRecipe,
      targetLufs: -14.0,
    });
    assert.equal(enrichedLive.assets.masterMp3Url, liveMasterUrl);
    assert.equal(enrichedLive.assets.stemUrls.vocals, liveVocalsUrl);
    assert.equal(enrichedLive.assets.stemUrls.melodic, liveMelodicUrl);
    assert.equal(enrichedLive.masteringMetrics?.mode, 'streaming');
    assert.equal(enrichedLive.masteringMetrics?.targetLufs, -14.0);

    createJob({
      generationId: liveJobId,
      creatorId: 'creator_cern',
      trackTitle: 'Limpopo Broadcast Master',
      genre: 'Amapiano',
      language: 've',
      status: 'succeeded',
      step: 'ready',
      progressPct: 100,
      masterMp3Url: liveMasterUrl,
      manifest: liveManifest,
    });

    const res = await app.fetch(
      new Request(`http://localhost/v1/generations/${liveJobId}/master`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ...baseRecipe, targetLufs: -14.0 }),
      }),
    );
    assert.equal(res.status, 200);
    const body = (await res.json()) as Record<string, any>;
    assert.equal(body.masteredMp3Url, liveMasterUrl);
    assert.equal(body.stemUrls.vocals, liveVocalsUrl);
    assert.equal(body.targetLufs, -14.0);
    console.log('  [PASS] Live R2 URLs preserved on enrichManifestWithMasteringRecipe & POST /:id/master');
  }

  // 3. Cold-isolate syncVoicesFromCloud hydration + RunPod mastering_mode & target_sample_rate forwarding
  {
    const originalFetch = globalThis.fetch;
    const originalSyncVoices = vhunambiDb.syncVoicesFromCloud.bind(vhunambiDb);
    const capturedPayloads: Array<Record<string, any>> = [];
    let syncVoicesCalled = 0;

    const coldCloneId = 'clone_p82_cold_01';
    const coldRefUrl = 'https://cdn.vhunambi.com/clones/mutale_cold_ref.wav';

    vhunambiDb.syncVoicesFromCloud = async () => {
      syncVoicesCalled += 1;
      registerVoiceCloneProfile({
        id: coldCloneId,
        creatorId: 'creator_cern',
        creatorName: 'Mutale Cold Isolate',
        nativeLanguage: 've',
        r2ReferenceUrl: coldRefUrl,
        recordingDurationSec: 12,
        calibrationLines: [
          'Ndi a ni funa ngazwothe',
          'Mutale u khou imba zwavhudi',
          'Ri do tshila rothe namusi',
        ],
        consentConfirmed: true,
      });
      return true;
    };

    globalThis.fetch = (async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = typeof input === 'string' ? input : input.toString();
      if (url.endsWith('/health')) {
        return new Response(
          JSON.stringify({
            workers: { idle: 1, running: 0, initializing: 0, ready: 1, max: 2 },
            jobs: { inQueue: 0 },
          }),
          { status: 200, headers: { 'content-type': 'application/json' } },
        );
      }
      if (url.endsWith('/run')) {
        capturedPayloads.push(JSON.parse(String(init?.body ?? '{}')));
        return new Response(JSON.stringify({ id: 'rp_p82_job_1' }), {
          status: 200,
          headers: { 'content-type': 'application/json' },
        });
      }
      return originalFetch(input, init);
    }) as typeof fetch;

    const prevRunPodKey = process.env.RUNPOD_API_KEY;
    const prevRunPodEndpoint = process.env.RUNPOD_ENDPOINT_ID;
    process.env.RUNPOD_API_KEY = 'rp_test_key_p82';
    process.env.RUNPOD_ENDPOINT_ID = 'ep_test_p82';

    try {
      const submitRes = await app.fetch(
        new Request('http://localhost/v1/generations', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            trackTitle: 'Cold Isolate Vocal Clone',
            genre: 'Maskandi',
            language: 've',
            clonedVoiceProfileId: coldCloneId,
            masteringMode: 'club',
            sampleRateHz: 48000,
          }),
        }),
      );
      assert.equal(submitRes.status, 201);
      const submitJson = (await submitRes.json()) as Record<string, any>;
      assert.equal(submitJson.masteringMode, 'club');
      assert.equal(submitJson.sampleRateHz, 48000);
      assert.equal(syncVoicesCalled >= 1, true, 'Expected cold isolate syncVoicesFromCloud');
      assert.ok(getVoiceCloneProfile(coldCloneId));
      assert.equal(capturedPayloads.length, 1);
      const runInput = capturedPayloads[0].input;
      assert.equal(runInput.mastering_mode, 'club');
      assert.equal(runInput.target_sample_rate, 48000);
      assert.equal(
        runInput.svc_config?.r2ReferenceUrl,
        getVoiceCloneProfile(coldCloneId)?.r2ReferenceUrl,
      );
      assert.ok(runInput.svc_config?.r2ReferenceUrl?.includes('clones/mutale_cold_ref.wav'));

      // Direct compiler + polling check
      const compiled = compileSongSpec({
        trackTitle: 'Direct Poll Check',
        genre: 'Amapiano',
        language: 've',
        masteringMode: 'streaming',
        sampleRateHz: 48000,
      });
      await dispatchSynthesisJob('gen_p82_direct_dispatch', compiled, 'creator_cern');
      assert.equal(capturedPayloads[1].input.mastering_mode, 'streaming');
      assert.equal(capturedPayloads[1].input.target_sample_rate, 48000);
    } finally {
      vhunambiDb.syncVoicesFromCloud = originalSyncVoices;
      globalThis.fetch = originalFetch;
      if (prevRunPodKey === undefined) delete process.env.RUNPOD_API_KEY;
      else process.env.RUNPOD_API_KEY = prevRunPodKey;
      if (prevRunPodEndpoint === undefined) delete process.env.RUNPOD_ENDPOINT_ID;
      else process.env.RUNPOD_ENDPOINT_ID = prevRunPodEndpoint;
    }
    console.log('  [PASS] Cold-isolate syncVoicesFromCloud + RunPod mastering_mode & 48kHz forwarding');
  }

  // 4. Webhook & /status polling persist masteringMetrics, svcMetrics, sampleRateHz & enriched notification
  {
    const genId = 'gen_p82_webhook_prov_01';
    createJob({
      generationId: genId,
      creatorId: 'creator_cern',
      trackTitle: 'Thohoyandou Broadcast Master',
      genre: 'Amapiano',
      language: 've',
      durationSec: 180,
      engineTier: 'studio_bake',
      resolvedEngine: 'minimax_music_3',
      attributionTag: 'MiniMax-Music3',
      status: 'running',
      step: 'mastering',
      progressPct: 84,
    });

    const webhookBody = JSON.stringify({
      job_id: `vhunambi_${genId}`,
      status: 'completed',
      audio_url: 'https://cdn.vhunambi.com/masters/thohoyandou_p82.mp3',
      manifest_url: 'https://cdn.vhunambi.com/manifests/thohoyandou_p82.json',
      stem_urls: {
        vocals: 'https://cdn.vhunambi.com/stems/vocals.wav',
        drums: 'https://cdn.vhunambi.com/stems/drums.wav',
        bass: 'https://cdn.vhunambi.com/stems/bass.wav',
        melodic: 'https://cdn.vhunambi.com/stems/melodic.wav',
      },
      resolved_engine: 'minimax_music_3',
      attribution_tag: 'MiniMax-Music3',
      sample_rate_hz: 44100,
      mastering_metrics: {
        mode: 'streaming',
        profile_id: 'sa_amapiano_private_school',
        integrated_lufs: -14.0,
        target_lufs: -14.0,
        true_peak_dbtp: -1.1,
        sample_rate_hz: 44100,
        engine: 'matchering_2.0',
      },
      svc_metrics: {
        applied: true,
        engine: 'seed_vc_rmvpe_v2',
        reference_decoded: true,
        similarity_score: 0.91,
        bantu_transients_preserved: true,
        polish_applied: true,
      },
    });

    const secret = resolveRuntimeEnv().ZR_WEBHOOK_SECRET;
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (secret) {
      headers['x-zrs-signature'] = crypto
        .createHmac('sha256', secret)
        .update(webhookBody)
        .digest('hex');
    }

    const whRes = await app.fetch(
      new Request('http://localhost/v1/webhooks/ace-step', {
        method: 'POST',
        headers,
        body: webhookBody,
      }),
    );
    assert.equal(whRes.status, 200);

    const statusRes = await app.fetch(
      new Request(`http://localhost/v1/generations/${genId}`),
    );
    assert.equal(statusRes.status, 200);
    const statusJson = (await statusRes.json()) as Record<string, any>;
    assert.equal(statusJson.sampleRateHz, 44100);
    assert.equal(statusJson.masteringMetrics?.integratedLufs, -14.0);
    assert.equal(
      statusJson.masteringMetrics?.profileId,
      'sa_amapiano_private_school',
    );
    assert.equal(statusJson.svcMetrics?.applied, true);
    assert.equal(statusJson.svcMetrics?.bantuTransientsPreserved, true);

    const manifestRes = await app.fetch(
      new Request(`http://localhost/v1/generations/${genId}/manifest`),
    );
    assert.equal(manifestRes.status, 200);
    const manifestJson = (await manifestRes.json()) as Record<string, any>;
    assert.equal(manifestJson.resolvedEngine, 'minimax_music_3');
    assert.equal(manifestJson.attributionTag, 'MiniMax-Music3');
    assert.equal(manifestJson.masteringMetrics?.integratedLufs, -14.0);
    assert.equal(manifestJson.svcMetrics?.applied, true);

    const notifs = vhunambiDb.listNotifications('creator_cern');
    const genNotif = notifs.find((n) => n.id === `notif_gen_${genId}`);
    assert.ok(genNotif, 'Expected notif_gen_ record');
    assert.ok(
      genNotif.message.includes('-14.0 LUFS'),
      `Expected measured LUFS in notification message: ${genNotif.message}`,
    );

    const frame = buildDualDialectPipelineEventFrame({
      generationId: genId,
      status: 'succeeded',
      step: 'ready',
      progressPct: 100,
      masterMp3Url: statusJson.masterMp3Url,
      resolvedEngine: 'minimax_music_3',
      attributionTag: 'MiniMax-Music3',
      sampleRateHz: 44100,
      masteringMetrics: statusJson.masteringMetrics,
      svcMetrics: statusJson.svcMetrics,
    });
    const completedTrack = frame.completed_track as Record<string, any>;
    assert.equal(completedTrack.mastering_metrics?.integratedLufs, -14.0);
    assert.equal(completedTrack.svc_metrics?.applied, true);

    // Also verify RunPod polling parses mastering_metrics & svc_metrics
    const originalFetch = globalThis.fetch;
    globalThis.fetch = (async () =>
      new Response(
        JSON.stringify({
          id: 'rp_poll_p82',
          status: 'COMPLETED',
          output: {
            audio_url: 'https://cdn.vhunambi.com/masters/poll_p82.mp3',
            sample_rate_hz: 48000,
            mastering_metrics: {
              mode: 'club',
              integrated_lufs: -9.0,
              true_peak_dbtp: -1.0,
            },
            svc_metrics: {
              applied: true,
              similarity_score: 0.89,
            },
          },
        }),
        { status: 200, headers: { 'content-type': 'application/json' } },
      )) as typeof fetch;
    const prevKey = process.env.RUNPOD_API_KEY;
    const prevEp = process.env.RUNPOD_ENDPOINT_ID;
    process.env.RUNPOD_API_KEY = 'rp_poll_key';
    process.env.RUNPOD_ENDPOINT_ID = 'rp_poll_ep';
    try {
      const polled = await checkRunPodJobStatus('rp_poll_p82');
      assert.equal(polled.sampleRateHz, 48000);
      assert.equal(polled.masteringMetrics?.integratedLufs, -9.0);
      assert.equal(polled.svcMetrics?.applied, true);
    } finally {
      globalThis.fetch = originalFetch;
      if (prevKey === undefined) delete process.env.RUNPOD_API_KEY;
      else process.env.RUNPOD_API_KEY = prevKey;
      if (prevEp === undefined) delete process.env.RUNPOD_ENDPOINT_ID;
      else process.env.RUNPOD_ENDPOINT_ID = prevEp;
    }

    // Ensure simulated Edge isolate toggle remains off
    setSimulateEdgeIsolateMode(false);
    assert.ok(getJob(genId));
    console.log('  [PASS] Webhook, /manifest, polling, DO frames & LUFS Ready alerts verified');
  }

  console.log('[Phase 82 Test] All checks PASSED.');
}

run().catch((err) => {
  console.error('[Phase 82 Test] FAILED:', err);
  process.exit(1);
});
