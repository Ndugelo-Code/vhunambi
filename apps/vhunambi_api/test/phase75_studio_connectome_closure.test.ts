import assert from 'node:assert/strict';
import { app } from '../src/server.js';
import {
  EdgeIsolateDatabaseEngine,
  isNodeSqliteAvailable,
  vhunambiDb,
} from '../src/db/vhunambi_db.js';

async function run(): Promise<void> {
  console.log('[Phase 75 Test] Running Studio Cockpit V5, Voice/Mastering SWR & Connectome Closure suite...');

  // 1. EdgeIsolateDatabaseEngine: syncVoicesFromCloud (12s SWR, 2-table gate, async CRUD)
  let selectCalls = 0;
  let shouldFailSignatures = false;
  let upsertCalls = 0;
  let deleteCalls = 0;

  const voiceRows: Array<Record<string, any>> = [];
  const signatureRows: Array<Record<string, any>> = [];
  const jobRows: Array<Record<string, any>> = [
    {
      generation_id: 'gen_p75_cross_isolate',
      creator_id: 'creator_ndugelo',
      job_kind: 'audio_synthesis',
      status: 'succeeded',
      step: 'ready',
      progress_pct: 100,
      track_title: 'Limpopo Dawn',
      genre: 'Amapiano',
      language: 've',
      duration_sec: 185,
      master_mp3_url: '/r2/audio/gen_p75_cross_isolate.mp3',
      stems_zip_url: '/r2/stems/gen_p75_cross_isolate.zip',
      stem_urls_json: {
        vocals: '/r2/stems/gen_p75_cross_isolate/vocals.wav',
        drums: '/r2/stems/gen_p75_cross_isolate/drums.wav',
        bass: '/r2/stems/gen_p75_cross_isolate/bass.wav',
        instrumental: '/r2/stems/gen_p75_cross_isolate/instrumental.wav',
      },
      data_json: {
        generationId: 'gen_p75_cross_isolate',
        trackTitle: 'Limpopo Dawn',
        genre: 'Amapiano',
        language: 've',
        status: 'succeeded',
        step: 'ready',
        progressPct: 100,
        durationSec: 185,
        masterMp3Url: '/r2/audio/gen_p75_cross_isolate.mp3',
      },
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    },
  ];

  const fakeDriver = {
    isConfigured: () => true,
    selectRows: async (table: string, query?: string) => {
      selectCalls += 1;
      if (table === 'voice_clones') {
        return voiceRows;
      }
      if (table === 'sound_signatures') {
        if (shouldFailSignatures) {
          throw new Error('simulated signatures timeout');
        }
        return signatureRows;
      }
      if (table === 'generation_jobs') {
        const match = query?.match(/generation_id=eq\.([^&]+)/);
        if (match) {
          const targetId = decodeURIComponent(match[1]);
          return jobRows.filter((r) => r.generation_id === targetId);
        }
        return jobRows;
      }
      return [];
    },
    upsertRow: async (table: string, row: Record<string, any>) => {
      upsertCalls += 1;
      if (table === 'voice_clones') {
        const idx = voiceRows.findIndex((r) => r.voice_id === row.voice_id);
        if (idx >= 0) voiceRows[idx] = row;
        else voiceRows.push(row);
      } else if (table === 'sound_signatures') {
        const idx = signatureRows.findIndex((r) => r.id === row.id);
        if (idx >= 0) signatureRows[idx] = row;
        else signatureRows.push(row);
      } else if (table === 'generation_jobs') {
        const idx = jobRows.findIndex((r) => r.generation_id === row.generation_id);
        if (idx >= 0) jobRows[idx] = row;
        else jobRows.push(row);
      }
    },
    patchRows: async () => {},
    deleteRows: async (table: string) => {
      deleteCalls += 1;
      if (table === 'sound_signatures') {
        signatureRows.length = 0;
      }
    },
  };

  const isolateA = new EdgeIsolateDatabaseEngine(fakeDriver as any);
  await isolateA.upsertVoiceCloneAsync({
    id: 'vclone_client_75001',
    voiceId: 'vclone_client_75001',
    creatorId: 'creator_ndugelo',
    creatorName: 'Vho-Ndugelo',
    nativeLanguage: 'Tshivenḓa',
    r2ReferenceUrl: '/r2/voice-clones/vclone_client_75001_ref.wav',
  });
  await isolateA.upsertSoundSignatureAsync({
    id: 'sig_client_75001',
    creatorId: 'creator_ndugelo',
    displayCode: 'SIG-VHA-75',
    name: 'SIG-VHA-75',
    source: 'live',
    durationSec: 18,
    recipe: { chestPowerAndAirBoost: 0.91 },
    consentAtIso: new Date().toISOString(),
  });
  assert.equal(upsertCalls, 2);

  // Fresh Isolate B fails partial sync -> must NOT seal 12s SWR window
  const isolateB = new EdgeIsolateDatabaseEngine(fakeDriver as any);
  shouldFailSignatures = true;
  const failedSync = await isolateB.syncVoicesFromCloud(false);
  assert.equal(failedSync, false);
  const callsAfterFailure = selectCalls;

  // Retry immediately after failure must hit cloud again and hydrate both stores
  shouldFailSignatures = false;
  const okSync = await isolateB.syncVoicesFromCloud(false);
  assert.equal(okSync, true);
  assert.ok(selectCalls > callsAfterFailure);
  assert.equal(isolateB.getVoiceCloneById('vclone_client_75001')?.id, 'vclone_client_75001');
  assert.equal(
    isolateB.getSoundSignatureById('sig_client_75001')?.recipe?.chestPowerAndAirBoost,
    0.91,
  );

  // Immediate subsequent read hits 12s SWR TTL with zero extra Supabase queries
  const callsBeforeSwrHit = selectCalls;
  const cachedSync = await isolateB.syncVoicesFromCloud(false);
  assert.equal(cachedSync, true);
  assert.equal(selectCalls, callsBeforeSwrHit);

  // Cross-isolate generation job hydration + awaited updateGenerationJobAsync
  const hydratedJob = await isolateB.syncGenerationJobFromCloud('gen_p75_cross_isolate');
  assert.ok(hydratedJob);
  assert.equal(hydratedJob?.trackTitle, 'Limpopo Dawn');
  const updatedJob = await isolateB.updateGenerationJobAsync('gen_p75_cross_isolate', {
    manifestUrl: '/v1/generations/gen_p75_cross_isolate/manifest',
  });
  assert.ok(updatedJob);
  assert.equal(upsertCalls, 3);

  // Delete signature awaits cloud removal
  const deleted = await isolateB.deleteSoundSignatureAsync('sig_client_75001');
  assert.equal(deleted, true);
  assert.equal(deleteCalls, 1);

  // 2. Live HTTP Route Verification: client ID preservation, PATCH recipe, scoped routes
  const cloneRes = await app.request('/v1/voices/clone', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      id: 'vclone_p75_exact_id',
      creatorName: 'Makhadzi Studio',
      nativeLanguage: 'Tshivenḓa',
      calibrationLines: ['Ndaa! Mbilu yanga i khou tshina kha ngoma dza Vhunambi.'],
      recordingDurationSec: 16,
      r2ReferenceUrl: '/r2/voice-clones/vclone_p75_exact_id_ref.wav',
    }),
  });
  assert.equal(cloneRes.status, 201);
  const cloneBody = (await cloneRes.json()) as any;
  assert.equal(cloneBody.profile.id, 'vclone_p75_exact_id');
  assert.ok(!String(cloneBody.profile.r2ReferenceUrl).includes('r2.vhunambi.com'));

  const sigCreate = await app.request('/v1/voices/signatures', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      id: 'sig_p75_http_1',
      displayCode: 'SIG-VEN-01',
      source: 'live',
      durationSec: 15,
      descriptor16: Array.from({ length: 16 }, (_, i) => i * 0.05),
      formants4: [420, 1450, 2650, 3400],
      consentConfirmed: true,
    }),
  });
  assert.equal(sigCreate.status, 201);

  const patchRecipe = await app.request('/v1/voices/signatures/sig_p75_http_1/recipe', {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ pitchScaleLock: 0.96, chestPowerAndAirBoost: 0.88 }),
  });
  assert.equal(patchRecipe.status, 200);
  const patchJson = (await patchRecipe.json()) as any;
  assert.equal(patchJson.signature.recipe.pitchScaleLock, 0.96);

  const getSig = await app.request('/v1/voices/signatures/sig_p75_http_1');
  assert.equal(getSig.status, 200);

  const delSig = await app.request('/v1/voices/signatures/sig_p75_http_1', {
    method: 'DELETE',
  });
  assert.equal(delSig.status, 200);

  // Scoped read-through routes (/v1/voices, /v1/melodies, /v1/lyrics, /v1/generations/mastering/presets)
  const presetsRes = await app.request('/v1/melodies/presets');
  assert.equal(presetsRes.status, 200);
  const packsRes = await app.request('/v1/melodies/sound-packs');
  assert.equal(packsRes.status, 200);
  const masterPresetsRes = await app.request('/v1/generations/mastering/presets?genre=Amapiano');
  assert.equal(masterPresetsRes.status, 200);
  const masterPresetsBody = (await masterPresetsRes.json()) as any;
  const canonicalRecipe = masterPresetsBody.recommended?.recipe ?? masterPresetsBody.presets?.[0]?.recipe;
  assert.ok(canonicalRecipe);

  // Master bake persists manifest for seeded track
  const masterBake = await app.request('/v1/generations/trk_seed_75001/master', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(canonicalRecipe),
  });
  assert.equal(masterBake.status, 200);
  const bakeJson = (await masterBake.json()) as any;
  assert.equal(bakeJson.success, true);
  assert.ok(bakeJson.manifest);

  // Proxy parity check on vhunambiDb
  assert.equal(typeof vhunambiDb.syncVoicesFromCloud, 'function');
  assert.equal(typeof vhunambiDb.upsertVoiceCloneAsync, 'function');
  assert.equal(typeof vhunambiDb.upsertSoundSignatureAsync, 'function');
  assert.equal(typeof vhunambiDb.deleteSoundSignatureAsync, 'function');
  assert.equal(typeof vhunambiDb.updateGenerationJobAsync, 'function');
  assert.equal(typeof isNodeSqliteAvailable(), 'boolean');

  console.log('[Phase 75 Test] ALL ASSERTIONS PASSED!');
}

run().catch((err) => {
  console.error('[Phase 75 Test] FAILED:', err);
  process.exit(1);
});
