import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { app } from '../src/server.js';
import { resolveRuntimeEnv } from '../src/config/env.js';
import { vhunambiDb } from '../src/db/vhunambi_db.js';
import { findLoraPackById } from '../src/modules/synthesis/lora_catalog.js';
import {
  selectSourceTracksForLoraPack,
  TrainingTrackMetadataSchema,
} from '../src/modules/synthesis/training_dataset_schema.js';

async function run(): Promise<void> {
  console.log('[Phase 85 Test] Running Cloud LoRA Factory & Webhook suite...');

  // 1. Zod Dataset Metadata Validation + 10+1 Backward-Compatible Catalog Check
  {
    const okMeta = TrainingTrackMetadataSchema.safeParse({
      title: 'Ṅwala Makoleni',
      lora_id: 'bantu_vocals_v1',
      genre: 'bantu_vocals',
      bpm: 112,
      language: 've-ZA',
      lyrics: '[VERSE]\nṄwala makoleni a vhudzimu',
      instrumentation: ['lead_vocals', 'log_drum'],
      license: 'owned',
    });
    assert.equal(okMeta.success, true);

    assert.equal(findLoraPackById('bantu_vocals_v1')?.packType, 'language');

    const res = await app.fetch(
      new Request('http://localhost/v1/studio/loras?genre=Amapiano'),
    );
    assert.equal(res.status, 200);
    const json = (await res.json()) as Record<string, any>;
    assert.equal(json.totalCount, 10);
    assert.equal(json.packs.length, 10);
    assert.equal(json.languagePacks.length, 1);
    assert.equal(json.languagePacks[0].loraId, 'bantu_vocals_v1');
    console.log('  [PASS] 10+1 catalog contract & TrainingTrackMetadataSchema validation');
  }

  // 2. Source Track Selector maps Zania R2 tracks onto Amapiano & Bantu Vocals
  {
    const candidates = Array.from({ length: 10 }, (_, idx) => ({
      id: `trk_p85_amap_${idx}`,
      title: `Zania Amapiano ${idx}`,
      genre: 'Amapiano',
      subGenre: 'Private School Amapiano',
      audioUrl: `/r2/media/creator_zania_catalog/upl_p85_${idx}.mp3`,
      contentSha256: `sha_amap_${idx}_${'a'.repeat(50)}`.slice(0, 64),
      bpm: 113,
      lyricsText: '[VERSE]\nKe nako ya mmino mo Afrika Borwa',
      sourceOrigin: 'creator_upload_zania',
    }));

    const selected = selectSourceTracksForLoraPack('amapiano_logdrum_v1', candidates);
    assert.equal(selected.length, 10);
    const vocalSelected = selectSourceTracksForLoraPack('bantu_vocals_v1', candidates);
    assert.equal(vocalSelected.length, 10);
    console.log('  [PASS] Source track selector matches Zania R2 tracks');
  }

  // 3. Prep Rejects < 8 Tracks, Dispatches >= 8 Tracks, and Webhook Promotes Active Pack
  {
    const gqomReject = await app.fetch(
      new Request('http://localhost/v1/studio/loras/datasets/prep', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ loraId: 'gqom_durban_v1' }),
      }),
    );
    assert.equal(gqomReject.status, 400);
    const rejJson = (await gqomReject.json()) as Record<string, any>;
    assert.equal(rejJson.error, 'INSUFFICIENT_SOURCE_TRACKS');

    // Seed 9 Zania Amapiano tracks into local SQLite explore_tracks for end-to-end prep/train test
    for (let i = 0; i < 9; i++) {
      await vhunambiDb.upsertExploreTrackAsync({
        id: `trk_p85_e2e_${i}`,
        creatorId: 'creator_zania_catalog',
        title: `Zania Log Drum ${i}`,
        artist: 'Zania Music',
        genre: 'Amapiano',
        subGenre: 'Private School Amapiano',
        bpm: 113,
        audioUrl: `/r2/media/creator_zania_catalog/upl_e2e_${i}.mp3`,
        coverUrl: `/r2/covers/creator_zania_catalog/upl_e2e_${i}.jpg`,
        contentSha256: `${String(i).repeat(64)}`.slice(0, 64),
        lyricsText: '[CHORUS]\nShaya log drum',
        sourceOrigin: 'creator_upload_zania',
      });
    }

    const prepRes = await app.fetch(
      new Request('http://localhost/v1/studio/loras/datasets/prep', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ loraId: 'amapiano_logdrum_v1' }),
      }),
    );
    assert.equal(prepRes.status, 202);
    const prepJson = (await prepRes.json()) as Record<string, any>;
    const prepJobId = String(prepJson.job.id);
    assert.ok(prepJson.sourceTrackCount >= 9);

    // Training before dataset_ready webhook must return 400 DATASET_NOT_READY
    const preTrainRes = await app.fetch(
      new Request('http://localhost/v1/studio/loras/train', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ loraId: 'amapiano_logdrum_v1' }),
      }),
    );
    assert.equal(preTrainRes.status, 400);

    // Invalid HMAC signature must return 401
    const env = resolveRuntimeEnv();
    const datasetPayload = JSON.stringify({
      job_id: prepJobId,
      lora_id: 'amapiano_logdrum_v1',
      status: 'dataset_ready',
      valid_tracks: 9,
      tracks: Array.from({ length: 9 }, (_, i) => ({
        source_r2_key: `media/creator_zania_catalog/upl_e2e_${i}.mp3`,
        source_sha256: `${String(i).repeat(64)}`.slice(0, 64),
        curated_wav_r2_key: `training-data/curated/amapiano_logdrum_v1/track_0${i}.wav`,
        curated_json_r2_key: `training-data/curated/amapiano_logdrum_v1/track_0${i}.json`,
        title: `Zania Log Drum ${i}`,
        duration_sec: 145,
        sample_rate: 44100,
        bit_depth: 24,
        bpm: 113,
        valid: true,
      })),
    });

    if (env.ZR_WEBHOOK_SECRET) {
      const badWh = await app.fetch(
        new Request('http://localhost/v1/webhooks/training', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'x-zrs-signature': '0000bad',
          },
          body: datasetPayload,
        }),
      );
      assert.equal(badWh.status, 401);
    }

    const sign = (raw: string) =>
      env.ZR_WEBHOOK_SECRET
        ? crypto
            .createHmac('sha256', env.ZR_WEBHOOK_SECRET)
            .update(raw)
            .digest('hex')
        : '';

    const dsWh = await app.fetch(
      new Request('http://localhost/v1/webhooks/training', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-zrs-signature': sign(datasetPayload),
        },
        body: datasetPayload,
      }),
    );
    assert.equal(dsWh.status, 200);

    // Dispatch real PEFT training job
    const trainRes = await app.fetch(
      new Request('http://localhost/v1/studio/loras/train', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          loraId: 'amapiano_logdrum_v1',
          epochs: 12,
          executionTarget: 'serverless',
        }),
      }),
    );
    assert.equal(trainRes.status, 202);
    const trainJson = (await trainRes.json()) as Record<string, any>;
    const trainJobId = String(trainJson.job.id);

    // Mock 21-byte payload must be rejected with 422 INVALID_ARTIFACT_PROOF
    const mockComplete = JSON.stringify({
      job_id: trainJobId,
      lora_id: 'amapiano_logdrum_v1',
      status: 'completed',
      artifact_bytes: 21,
      artifact_sha256: 'abc',
    });
    const mockWh = await app.fetch(
      new Request('http://localhost/v1/webhooks/training', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-zrs-signature': sign(mockComplete),
        },
        body: mockComplete,
      }),
    );
    assert.equal(mockWh.status, 422);

    // Verified completion promotes pack to active
    const realSha = 'e'.repeat(64);
    const realComplete = JSON.stringify({
      job_id: trainJobId,
      lora_id: 'amapiano_logdrum_v1',
      status: 'completed',
      artifact_r2_key: 'loras/amapiano_logdrum_v1.safetensors',
      artifact_bytes: 18432000,
      artifact_sha256: realSha,
      training_tracks: 9,
      total_epochs: 12,
      final_loss: 0.184,
    });
    const okWh = await app.fetch(
      new Request('http://localhost/v1/webhooks/training', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-zrs-signature': sign(realComplete),
        },
        body: realComplete,
      }),
    );
    assert.equal(okWh.status, 200);

    const factoryRes = await app.fetch(
      new Request('http://localhost/v1/studio/loras/factory'),
    );
    assert.equal(factoryRes.status, 200);
    const factoryJson = (await factoryRes.json()) as Record<string, any>;
    assert.equal(factoryJson.totalPacks, 11);
    const amapPack = factoryJson.packs.find(
      (p: Record<string, any>) => p.loraId === 'amapiano_logdrum_v1',
    );
    assert.equal(amapPack.registryStatus, 'active');
    assert.equal(amapPack.artifactSha256, realSha);
    assert.equal(amapPack.curatedTrackCount, 9);
    console.log('  [PASS] Cloud Prep -> Real Train -> Signed Webhook -> Active Factory state');
  }

  console.log('[Phase 85 Test] All checks PASSED.');
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
