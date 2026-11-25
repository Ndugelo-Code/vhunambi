import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { app } from '../src/server.js';
import { resolveRuntimeEnv } from '../src/config/env.js';
import { setSimulateEdgeIsolateMode, vhunambiDb } from '../src/db/vhunambi_db.js';
import { createJob, getJob } from '../src/modules/jobs/job_store.js';
import {
  formatLyricsForEngine,
  sanitizeLyricsForAceStep,
} from '../src/modules/lyrics/lyrics_sanitizer.js';
import { buildDualDialectPipelineEventFrame } from '../src/modules/realtime/generation_session_do.js';
import {
  compileSongSpec,
  resolveTargetAudioEngine,
} from '../src/modules/synthesis/prompt_compiler.js';
import {
  checkRunPodJobStatus,
  dispatchSynthesisJob,
} from '../src/modules/synthesis/runpod_adapter.js';

async function run(): Promise<void> {
  console.log('[Phase 81 Test] Running Worker Multi-Model Wire, Polling & DO Sync suite...');

  // 1. Duet/Drop Sanitizer + Title-Case MiniMax Formatter + YuE2 Prohibition
  {
    const rawLyrics =
      '[Voice A] Ndi a ni funa\n(whisper softly)\n[Log Drum Drop]\n[Piano Solo]\n[Drum Solo]\n[Voice B] Ro tshila rothe';
    const aceCleaned = sanitizeLyricsForAceStep(rawLyrics);
    assert.ok(aceCleaned.includes('[voice a]'), `Expected [voice a] in ${aceCleaned}`);
    assert.ok(!aceCleaned.includes('[log drum drop]'), `ACE-Step sanitizer should strip [log drum drop] per P66: ${aceCleaned}`);
    assert.ok(aceCleaned.includes('[piano solo]'), `Expected [piano solo] in ${aceCleaned}`);
    assert.ok(aceCleaned.includes('[drum solo]'), `Expected [drum solo] in ${aceCleaned}`);
    assert.ok(!aceCleaned.includes('whisper softly'));

    const minimaxFormatted = formatLyricsForEngine(rawLyrics, 'minimax_music_3');
    assert.ok(minimaxFormatted.includes('[Voice A]'), `Expected [Voice A] in ${minimaxFormatted}`);
    assert.ok(
      minimaxFormatted.includes('[Log Drum Drop]'),
      `Expected [Log Drum Drop] in ${minimaxFormatted}`,
    );
    assert.ok(
      minimaxFormatted.includes('[Piano Solo]'),
      `Expected [Piano Solo] in ${minimaxFormatted}`,
    );
    assert.ok(minimaxFormatted.includes('[Voice B]'), `Expected [Voice B] in ${minimaxFormatted}`);

    assert.throws(
      () => resolveTargetAudioEngine({ engineTier: 'yue2', isInstrumental: false }),
      /YuE2/i,
    );
    console.log('  [PASS] Duet/Drop sanitizer, MiniMax Title-Case formatter & YuE2 rejection');
  }

  // 2. runpod_adapter.ts lossless dispatch & active multi-take /status/:id polling
  {
    const originalFetch = globalThis.fetch;
    const capturedRunPayloads: Array<Record<string, any>> = [];

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
        capturedRunPayloads.push(JSON.parse(String(init?.body ?? '{}')));
        return new Response(JSON.stringify({ id: 'rp_p81_job_1' }), {
          status: 200,
          headers: { 'content-type': 'application/json' },
        });
      }
      if (url.includes('/status/rp_p81_job_multi')) {
        return new Response(
          JSON.stringify({
            id: 'rp_p81_job_multi',
            status: 'COMPLETED',
            output: {
              audio_url: 'https://r2.vhunambi.test/audio/gen_p81_poll/take_0.mp3',
              stems_zip_url: 'https://r2.vhunambi.test/audio/gen_p81_poll/stems.zip',
              manifest_url: 'https://r2.vhunambi.test/manifests/gen_p81_poll_mmo.json',
              resolved_engine: 'minimax_music_3',
              attribution_tag: 'MiniMax-Music3',
              takes: [
                {
                  takeIndex: 0,
                  seed: 900111,
                  engineUsed: 'minimax_music_3',
                  audioUrl: 'https://r2.vhunambi.test/audio/gen_p81_poll/take_0.mp3',
                  durationSec: 210,
                  score: 0.94,
                  attribution: 'MiniMax-Music3',
                },
                {
                  takeIndex: 1,
                  seed: 900222,
                  engineUsed: 'minimax_music_3',
                  audioUrl: 'https://r2.vhunambi.test/audio/gen_p81_poll/take_1.mp3',
                  durationSec: 210,
                  score: 0.89,
                  attribution: 'MiniMax-Music3',
                },
                {
                  takeIndex: 2,
                  seed: 900333,
                  engineUsed: 'minimax_music_3',
                  audioUrl: 'https://r2.vhunambi.test/audio/gen_p81_poll/take_2.mp3',
                  durationSec: 210,
                  score: 0.81,
                  attribution: 'MiniMax-Music3',
                },
              ],
            },
          }),
          { status: 200, headers: { 'content-type': 'application/json' } },
        );
      }
      if (url.includes('/status/rp_p81_job_prog')) {
        return new Response(
          JSON.stringify({
            id: 'rp_p81_job_prog',
            status: 'IN_PROGRESS',
            output: { stage: 'converting_vocals', progress: 72 },
          }),
          { status: 200, headers: { 'content-type': 'application/json' } },
        );
      }
      return new Response(JSON.stringify({ error: 'unexpected url ' + url }), { status: 404 });
    }) as typeof fetch;

    try {
      const mockEnv = {
        RUNPOD_API_KEY: 'rp_test_key',
        RUNPOD_ENDPOINT_ID: 'ep_test_81',
        PUBLIC_API_BASE_URL: 'https://api.vhunambi.test',
      };

      const vocalPrompt = compileSongSpec({
        trackTitle: 'Limpopo Duet',
        genre: 'Afro-Soul',
        language: 'Tshivenda',
        isInstrumental: false,
        engineTier: 'studio_bake',
        batchCount: 3,
        lyrics: '[Voice A]\nRi a imba\n[Log Drum Drop]\n[Voice B]\nMutupo washu',
      });
      assert.equal(vocalPrompt.isInstrumental, false);

      const vocalDispatch = await dispatchSynthesisJob(
        'gen_p81_vocal',
        vocalPrompt,
        'creator_p81',
        mockEnv,
      );
      assert.equal(vocalDispatch.isMock, false);
      assert.equal(capturedRunPayloads[0]?.input?.is_instrumental, false);
      assert.equal(capturedRunPayloads[0]?.input?.song_spec?.is_instrumental, false);
      assert.ok(
        String(capturedRunPayloads[0]?.input?.song_spec?.lyrics).includes('[Voice A]'),
      );
      assert.ok(
        String(capturedRunPayloads[0]?.input?.song_spec?.lyrics).includes('[Log Drum Drop]'),
      );

      const instPrompt = compileSongSpec({
        trackTitle: 'Sub Log Bass',
        genre: 'Amapiano',
        language: 've',
        isInstrumental: true,
        engineTier: 'studio_bake',
        batchCount: 2,
      });
      assert.equal(instPrompt.isInstrumental, true);
      assert.equal(instPrompt.resolvedEngine, 'ace_step_xl_sft');
      await dispatchSynthesisJob('gen_p81_inst', instPrompt, 'creator_p81', mockEnv);
      assert.equal(capturedRunPayloads[1]?.input?.is_instrumental, true);
      assert.equal(capturedRunPayloads[1]?.input?.song_spec?.is_instrumental, true);
      assert.equal(capturedRunPayloads[1]?.input?.song_spec?.lyrics, '');

      // Active polling /status/:id on IN_PROGRESS + COMPLETED multi-take
      const progStatus = await checkRunPodJobStatus('rp_p81_job_prog', mockEnv);
      assert.equal(progStatus.status, 'IN_PROGRESS');
      assert.equal(progStatus.stage, 'converting_vocals');
      assert.equal(progStatus.progress, 72);

      // Mount mock job in job_store pointing to rp_p81_job_multi and poll GET /v1/generations/:id
      createJob({
        generationId: 'gen_p81_poll',
        creatorId: 'creator_p81',
        trackTitle: 'Thohoyandou Poll',
        genre: 'Afro-Soul',
        language: 'Tshivenda',
        durationSec: 210,
        batchId: 'batch_p81_poll',
        batchCount: 3,
        engineTier: 'studio_bake',
        resolvedEngine: 'minimax_music_3',
        attributionTag: 'MiniMax-Music3',
        providerTaskId: 'rp_p81_job_multi',
        status: 'running',
        step: 'synthesizing',
        progressPct: 40,
      });

      const pollReq = new Request(
        'http://localhost/v1/generations/gen_p81_poll',
      );
      const pollRes = await app.fetch(pollReq, mockEnv as any);
      assert.equal(pollRes.status, 200);
      const pollJson = (await pollRes.json()) as Record<string, any>;
      assert.equal(pollJson.status, 'succeeded');
      assert.equal(pollJson.resolvedEngine, 'minimax_music_3');
      assert.equal(pollJson.attributionTag, 'MiniMax-Music3');
      assert.equal((pollJson.takes as Array<any>).length, 3);
      assert.equal(pollJson.takes[0].seed, 900111);
      assert.equal(pollJson.takes[0].score, 0.94);
      assert.equal(pollJson.takes[2].seed, 900333);
      console.log('  [PASS] dispatchSynthesisJob is_instrumental/casing & multi-take polling parity');
    } finally {
      globalThis.fetch = originalFetch;
    }
  }

  // 3. Simulated Edge Isolate Webhook Progress Persistence & DO stage mapping
  {
    const genId = 'gen_p81_edge_wh';
    setSimulateEdgeIsolateMode(true);
    try {
      await vhunambiDb.upsertGenerationJobAsync(
        {
          generationId: genId,
          creatorId: 'creator_p81_edge',
          trackTitle: 'Edge Webhook Track',
          genre: 'Amapiano',
          language: 've',
          durationSec: 180,
          batchCount: 2,
          engineTier: 'studio_bake',
          resolvedEngine: 'minimax_music_3',
          attributionTag: 'MiniMax-Music3',
          status: 'queued',
          step: 'queued',
          progressPct: 10,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
        'creator_p81_edge',
      );

      const secret = resolveRuntimeEnv().ZR_WEBHOOK_SECRET || '';
      const whPayload = JSON.stringify({
        job_id: `vhunambi_${genId}`,
        status: 'planning_lyrics',
        stage: 'planning_lyrics',
        progress: 18,
        message: 'Planning dialect lyrics...',
      });
      const sig = secret
        ? crypto.createHmac('sha256', secret).update(whPayload).digest('hex')
        : '';

      const whRes = await app.fetch(
        new Request('http://localhost/v1/webhooks/ace-step', {
          method: 'POST',
          headers: {
            'content-type': 'application/json',
            ...(sig ? { 'x-zrs-signature': sig } : {}),
          },
          body: whPayload,
        }),
      );
      assert.equal(whRes.status, 200);
      const persisted = getJob(genId);
      assert.equal(persisted?.status, 'running');
      assert.equal(persisted?.step, 'planning_lyrics');
      assert.equal(persisted?.progressPct, 18);

      // DO dual-dialect frame mapping for planning_lyrics, converting_vocals, and completed takes
      const planningFrame = buildDualDialectPipelineEventFrame({
        generationId: genId,
        status: 'running',
        step: 'planning_lyrics',
        progressPct: 18,
      });
      assert.equal(planningFrame.step_index, 2);

      const vocalFrame = buildDualDialectPipelineEventFrame({
        generationId: genId,
        status: 'running',
        step: 'converting_vocals',
        progressPct: 72,
      });
      assert.equal(vocalFrame.step_index, 3);

      const readyFrame = buildDualDialectPipelineEventFrame({
        generationId: genId,
        status: 'succeeded',
        step: 'ready',
        progressPct: 100,
        masterMp3Url: 'https://r2.vhunambi.test/audio/take_0.mp3',
        resolvedEngine: 'minimax_music_3',
        attributionTag: 'MiniMax-Music3',
        takes: [
          {
            takeIndex: 0,
            seed: 12345,
            engineUsed: 'minimax_music_3',
            audioUrl: 'https://r2.vhunambi.test/audio/take_0.mp3',
            durationSec: 180,
            score: 0.95,
            attribution: 'MiniMax-Music3',
          },
        ],
      });
      assert.equal(readyFrame.step_index, 4);
      const completedTrack = readyFrame.completed_track as Record<string, any>;
      assert.equal(completedTrack.resolved_engine, 'minimax_music_3');
      assert.equal(completedTrack.attribution_tag, 'MiniMax-Music3');
      assert.equal((completedTrack.takes as Array<any>).length, 1);
      console.log('  [PASS] Edge isolate webhook DB persistence & DO stage/takes frames');
    } finally {
      setSimulateEdgeIsolateMode(false);
    }
  }

  console.log('[Phase 81 Test] ALL M81.1 TESTS PASSED');
}

run().catch((err) => {
  console.error('[Phase 81 Test] FAILED:', err);
  process.exit(1);
});
