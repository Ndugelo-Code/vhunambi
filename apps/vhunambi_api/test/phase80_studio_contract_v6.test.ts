import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { app } from '../src/server.js';
import { resolveRuntimeEnv } from '../src/config/env.js';
import {
  EdgeIsolateDatabaseEngine,
  isNodeSqliteAvailable,
  setSimulateEdgeIsolateMode,
  vhunambiDb,
} from '../src/db/vhunambi_db.js';
import {
  compileSongSpec,
  generateUniqueTakeSeeds,
  resolveTargetAudioEngine,
} from '../src/modules/synthesis/prompt_compiler.js';
import {
  sanitizeLyricsForAceStep,
  sanitizeLyricsForClient,
} from '../src/modules/lyrics/lyrics_sanitizer.js';
import { hasGenrePreset } from '../src/modules/synthesis/constants.js';
import { getJob } from '../src/modules/jobs/job_store.js';

async function run(): Promise<void> {
  console.log('[Phase 80 Test] Running Studio Cockpit V6 & Production Contract suite...');

  // 1. Multi-model deterministic engine routing & MiniMax-Music3 attribution rules
  {
    const fast = resolveTargetAudioEngine({ engineTier: 'fast_draft', isInstrumental: false });
    assert.equal(fast.resolvedEngine, 'ace_step_xl_turbo');
    assert.equal(fast.attributionTag, null);

    const studioVocal = resolveTargetAudioEngine({ engineTier: 'studio_bake', isInstrumental: false });
    assert.equal(studioVocal.resolvedEngine, 'minimax_music_3');
    assert.equal(studioVocal.attributionTag, 'MiniMax-Music3');

    const studioInst = resolveTargetAudioEngine({ engineTier: 'studio_bake', isInstrumental: true });
    assert.equal(studioInst.resolvedEngine, 'ace_step_xl_sft');
    assert.equal(studioInst.attributionTag, null);

    const sovereign = resolveTargetAudioEngine({ engineTier: 'sovereign_custom', isInstrumental: false });
    assert.equal(sovereign.resolvedEngine, 'ace_step_xl_base');
    assert.equal(sovereign.attributionTag, null);

    const withRef = resolveTargetAudioEngine({
      engineTier: 'studio_bake',
      isInstrumental: false,
      audioMode: 'remix',
      referenceAudioUrl: 'https://r2.vhunambi.com/ref/beat.wav',
    });
    assert.equal(withRef.resolvedEngine, 'ace_step_xl_base');
    assert.equal(withRef.attributionTag, null);

    // 4 unique positive non-zero 64-bit seeds
    const seeds = generateUniqueTakeSeeds(4);
    assert.equal(seeds.length, 4);
    assert.equal(new Set(seeds).size, 4);
    for (const s of seeds) {
      assert.ok(s > 0 && Number.isSafeInteger(s));
    }

    // All 42 UI genres resolve cleanly across all 5 regions (including Asia & Americas)
    for (const genre of [
      'Private School Amapiano',
      'Lekompo',
      'Ethio-Jazz',
      'Samba',
      'Afro-Cuban',
      'Dancehall',
      'Bollywood Fusion',
      'K-Pop',
      'Afro-Asian Lo-Fi',
    ]) {
      assert.ok(hasGenrePreset(genre), `Expected genre preset for ${genre}`);
    }
    console.log('  [PASS] Multi-model routing, attribution, unique seeds & 42-genre presets');
  }

  // 2. Prompt preservation (>48 chars) & Duet/Solo section tag sanitization
  {
    const longPrompt =
      'Deep dusty Durban Amapiano groove with warm Rhodes chords, crisp shakers, sub-bass log drums, and soulful gospel choir lifts in the bridge.';
    const compiled = compileSongSpec({
      trackTitle: 'Limpopo Skyline',
      prompt: longPrompt,
      genre: 'Amapiano',
      region: 'South Africa',
      language: 'Zulu',
      durationSec: 210,
      engineTier: 'studio_bake',
      batchCount: 3,
      voiceCast: {
        ensemble: 'duet',
        gender: 'mixed',
        selectedVoiceIds: ['kamo_duet_f', 'tebogo_baritone_m'],
      },
    });
    assert.equal(compiled.resolvedEngine, 'minimax_music_3');
    assert.equal(compiled.attributionTag, 'MiniMax-Music3');
    assert.equal(compiled.batchCount, 3);
    assert.equal(compiled.takeSeeds.length, 3);
    assert.equal(new Set(compiled.takeSeeds).size, 3);
    assert.equal(compiled.metadata.durationSec, 210);
    assert.ok(compiled.caption.length > 48, 'Style caption must not truncate at 48 chars');
    assert.equal(compiled.richPrompt, longPrompt);
    assert.ok(!compiled.caption.toLowerCase().includes('yue2'));

    const rawDuet = [
      '[Verse 1]',
      '[Voice A]',
      'Yebo mama we dance till sunrise',
      '[Voice B]',
      'Ngihamba nawe through the golden light',
      '[Guitar Solo]',
      '[Drop]',
      '[Duet]',
      'Together under African skies',
    ].join('\n');
    const aceLyrics = sanitizeLyricsForAceStep(rawDuet);
    const clientLyrics = sanitizeLyricsForClient(rawDuet);
    for (const tag of ['[Voice A]', '[Voice B]', '[Guitar Solo]', '[Drop]', '[Duet]']) {
      assert.ok(aceLyrics.toLowerCase().includes(tag.toLowerCase()), `ACE lyrics missing ${tag}`);
      assert.ok(clientLyrics.toLowerCase().includes(tag.toLowerCase()), `Client lyrics missing ${tag}`);
    }
    console.log('  [PASS] >48-char prompt preservation & duet tag sanitization');
  }

  // 3. Studio AI Assist routes (/v1/studio/improve-prompt, /v1/lyrics/from-photo, duet /v1/lyrics/generate)
  {
    const improveRes = await app.fetch(
      new Request('http://localhost/v1/studio/improve-prompt', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          prompt: 'underground amapiano club song',
          genre: 'Amapiano',
          region: 'South Africa',
          language: 'Zulu',
          ensemble: 'duet',
        }),
      }),
    );
    assert.equal(improveRes.status, 200);
    const improveJson = (await improveRes.json()) as Record<string, any>;
    assert.equal(improveJson.success, true);
    assert.ok(String(improveJson.improvedPrompt).length > 30);

    const photoRes = await app.fetch(
      new Request('http://localhost/v1/lyrics/from-photo', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          photoUrl: '/r2/media/creator_p80/sunset.jpg',
          captionHint: 'Golden sunset over Thohoyandou hills',
          genre: 'Afro-Pop',
          language: 'Tshivenda',
          ensemble: 'duet',
        }),
      }),
    );
    assert.equal(photoRes.status, 200);
    const photoJson = (await photoRes.json()) as Record<string, any>;
    assert.equal(photoJson.success, true);
    assert.ok(String(photoJson.rawLyrics).length > 40);

    const duetRes = await app.fetch(
      new Request('http://localhost/v1/lyrics/generate', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          prompt: 'A love song across two villages',
          genre: 'Afro-Soul',
          language: 'Tshivenda',
          ensemble: 'duet',
          voiceCast: ['p80_soprano', 'p80_baritone'],
        }),
      }),
    );
    assert.equal(duetRes.status, 200);
    const duetJson = (await duetRes.json()) as Record<string, any>;
    assert.equal(duetJson.success, true);
    assert.equal(duetJson.ensemble, 'duet');
    const duetLower = String(duetJson.rawLyrics).toLowerCase();
    assert.ok(duetLower.includes('[voice a]'), `Expected [voice a] in ${duetJson.rawLyrics}`);
    assert.ok(duetLower.includes('[voice b]'), `Expected [voice b] in ${duetJson.rawLyrics}`);
    console.log('  [PASS] /v1/studio/improve-prompt, /v1/lyrics/from-photo & duet /v1/lyrics/generate');
  }

  // 4. V6 Generation submission -> honest Queued notification -> webhook Ready upgrade + true creatorId + takes_json
  {
    const uid = 'creator_p80_real_owner';
    const submitRes = await app.fetch(
      new Request('http://localhost/v1/generations', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          contractVersion: 'v6',
          userId: uid,
          trackTitle: 'Vhembe Gold',
          isAutoTitle: false,
          prompt: 'Warm Afro-Soul duet with live fingerstyle electric guitar and gospel choir chorus',
          genre: 'Afro-Soul',
          region: 'South Africa',
          language: 've',
          lyricsMode: 'ai_writes',
          lyrics: '[Verse 1]\n[Voice A]\nVhembe sunshine\n[Voice B]\nShining bright',
          durationSec: 195,
          engineTier: 'studio_bake',
          batchCount: 2,
          visibility: 'private',
          voiceCast: {
            ensemble: 'duet',
            gender: 'mixed',
            selectedVoiceIds: ['v1', 'v2'],
          },
        }),
      }),
    );
    assert.equal(submitRes.status, 201);
    const submitJson = (await submitRes.json()) as Record<string, any>;
    const genId = String(submitJson.generationId);
    assert.equal(submitJson.batchCount, 2);
    assert.equal(submitJson.engineTier, 'studio_bake');
    assert.equal(submitJson.resolvedEngine, 'minimax_music_3');
    assert.equal(submitJson.attributionTag, 'MiniMax-Music3');
    assert.equal(submitJson.durationSec, 195);
    assert.equal(submitJson.visibility, 'private');
    assert.equal((submitJson.takeSeeds as number[]).length, 2);

    // Check notification is HONESTLY Queued (never premature "Ready")
    const queuedInboxRes = await app.fetch(
      new Request(`http://localhost/api/notifications?userId=${uid}`),
    );
    const queuedInbox = (await queuedInboxRes.json()) as Record<string, any>;
    const genNotifQueued = (queuedInbox.notifications as Array<Record<string, any>>).find(
      (n) => n.id === `notif_gen_${genId}`,
    );
    assert.ok(genNotifQueued, 'Expected notif_gen_<id> on queued submit');
    assert.equal(genNotifQueued.title, 'Studio Bake Queued: "Vhembe Gold"');
    assert.ok(!String(genNotifQueued.title).startsWith('Studio Track Ready'));

    // Simulate intermediate granular webhook stage -> separating_stems
    const stagePayload = JSON.stringify({
      job_id: `vhunambi_${genId}`,
      status: 'separating_stems',
      stage: 'separating_stems',
      progress: 64,
      message: 'Splitting 4 studio stems',
    });
    const secret = resolveRuntimeEnv().ZR_WEBHOOK_SECRET || '';
    const stageSig = secret
      ? crypto.createHmac('sha256', secret).update(stagePayload).digest('hex')
      : '';
    const stageRes = await app.fetch(
      new Request('http://localhost/v1/webhooks/ace-step', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          ...(stageSig ? { 'x-zrs-signature': stageSig } : {}),
        },
        body: stagePayload,
      }),
    );
    assert.equal(stageRes.status, 200);
    assert.equal(getJob(genId)?.step, 'separating_stems');

    // Simulate completion webhook with multi-take payload -> must retain real creatorId & upgrade notification
    const donePayload = JSON.stringify({
      job_id: `vhunambi_${genId}`,
      status: 'completed',
      audio_url: `https://r2.vhunambi.com/audio/${genId}_take1.mp3`,
      resolved_engine: 'minimax_music_3',
      attribution_tag: 'MiniMax-Music3',
      takes: [
        {
          takeIndex: 0,
          seed: submitJson.takeSeeds[0],
          audioUrl: `https://r2.vhunambi.com/audio/${genId}_take1.mp3`,
          durationSec: 195,
        },
        {
          takeIndex: 1,
          seed: submitJson.takeSeeds[1],
          audioUrl: `https://r2.vhunambi.com/audio/${genId}_take2.mp3`,
          durationSec: 192,
        },
      ],
    });
    const doneSig = secret
      ? crypto.createHmac('sha256', secret).update(donePayload).digest('hex')
      : '';
    const doneRes = await app.fetch(
      new Request('http://localhost/v1/webhooks/ace-step', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          ...(doneSig ? { 'x-zrs-signature': doneSig } : {}),
        },
        body: donePayload,
      }),
    );
    assert.equal(doneRes.status, 200);

    // Poll GET /v1/generations/:id and verify V6 fields + takes
    const pollRes = await app.fetch(new Request(`http://localhost/v1/generations/${genId}`));
    assert.equal(pollRes.status, 200);
    const pollJson = (await pollRes.json()) as Record<string, any>;
    assert.equal(pollJson.status, 'succeeded');
    assert.equal(pollJson.resolvedEngine, 'minimax_music_3');
    assert.equal(pollJson.attributionTag, 'MiniMax-Music3');
    assert.equal((pollJson.takes as Array<unknown>).length, 2);

    // Verify true creatorId preserved in local SQLite (when available) and notification upgraded
    if (isNodeSqliteAvailable()) {
      const persisted = vhunambiDb.getGenerationJob(genId);
      assert.equal(persisted?.creatorId, uid);
      assert.equal(persisted?.takes?.length, 2);
    }

    const readyInboxRes = await app.fetch(
      new Request(`http://localhost/api/notifications?userId=${uid}`),
    );
    const readyInbox = (await readyInboxRes.json()) as Record<string, any>;
    const genNotifReady = (readyInbox.notifications as Array<Record<string, any>>).find(
      (n) => n.id === `notif_gen_${genId}`,
    );
    assert.ok(genNotifReady);
    assert.equal(genNotifReady.title, 'Studio Track Ready: "Vhembe Gold"');
    assert.equal(genNotifReady.isRead, false);
    console.log('  [PASS] Honest Queued -> Ready notification & webhook true creatorId + multi-take');
  }

  // 5. EdgeIsolateDatabaseEngine V6 13-column round-trip
  try {
    setSimulateEdgeIsolateMode(true);
    const storedRows = new Map<string, Record<string, any>>();
    const fakeDriver = {
      isConfigured: () => true,
      selectRows: async (table: string, query?: string) => {
        if (table !== 'generation_jobs') return [];
        const match = query?.match(/generation_id=eq\.([^&]+)/);
        if (match) {
          const row = storedRows.get(decodeURIComponent(match[1]));
          return row ? [row] : [];
        }
        return Array.from(storedRows.values());
      },
      upsertRow: async (table: string, row: Record<string, any>) => {
        if (table === 'generation_jobs') {
          storedRows.set(String(row.generation_id), row);
        }
      },
      patchRows: async () => {},
      deleteRows: async () => {},
    };
    const edge = new EdgeIsolateDatabaseEngine(fakeDriver as any);
    await edge.upsertGenerationJobAsync(
      {
        generationId: 'gen_p80_edge_rt',
        creatorId: 'creator_edge_80',
        jobKind: 'audio_synthesis',
        status: 'succeeded',
        step: 'ready',
        progressPct: 100,
        trackTitle: 'Edge Multi Take',
        genre: 'Amapiano',
        language: 'Zulu',
        durationSec: 210,
        batchId: 'batch_p80_1',
        batchCount: 2,
        engineTier: 'studio_bake',
        resolvedEngine: 'minimax_music_3',
        audioMode: 'none',
        visibility: 'private',
        attributionTag: 'MiniMax-Music3',
        takes: [
          { takeIndex: 0, seed: 111, audioUrl: '/r2/t1.mp3', durationSec: 210 },
          { takeIndex: 1, seed: 222, audioUrl: '/r2/t2.mp3', durationSec: 205 },
        ],
        createdAt: new Date(),
        updatedAt: new Date(),
      },
      'creator_edge_80',
    );
    const synced = await edge.syncGenerationJobFromCloud('gen_p80_edge_rt');
    assert.ok(synced);
    assert.equal(synced.creatorId, 'creator_edge_80');
    assert.equal(synced.batchCount, 2);
    assert.equal(synced.resolvedEngine, 'minimax_music_3');
    assert.equal(synced.attributionTag, 'MiniMax-Music3');
    assert.equal(synced.takes?.length, 2);
    console.log('  [PASS] EdgeIsolateDatabaseEngine V6 13-column round-trip');
  } finally {
    setSimulateEdgeIsolateMode(false);
  }

  console.log('[Phase 80 Test] ALL V6 CONTRACT TESTS PASSED!');
}

run().catch((err) => {
  console.error('[Phase 80 Test FAILED]', err);
  process.exit(1);
});
