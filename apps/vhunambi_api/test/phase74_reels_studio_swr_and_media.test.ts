import assert from 'node:assert/strict';
import { app } from '../src/server.js';
import { vhunambiDb } from '../src/db/vhunambi_db.js';
import { EdgeIsolateDatabaseEngine } from '../src/db/edge_persistence_bridge.js';

async function run(): Promise<void> {
  console.log('[Phase 74 Test] Running Reels Studio Cloud SWR, Clip Reactions & R2 Media Upload suite...');

  // 1. EdgeIsolateDatabaseEngine: syncSocialFromCloud (12s SWR, 3-table gate, DESC timestamp sort)
  let selectCalls = 0;
  let shouldFailComments = false;
  let upsertCalls = 0;
  let patchCalls = 0;

  const now = Date.now();
  const fakeDriver = {
    isConfigured: () => true,
    selectRows: async (table: string) => {
      selectCalls += 1;
      if (table === 'published_clips') {
        return [
          {
            id: 'clip_swr_new',
            track_id: 'trk_new',
            creator_id: 'creator_makhadzi',
            title: 'Newest Studio Reel',
            caption: 'Fresh camera take',
            genre: 'Amapiano',
            likes_count: 1840,
            comments_count: 2,
            remixes_count: 0,
            audio_url: '/r2/audio/new.mp3',
            cover_url: '/r2/covers/new.jpg',
            video_url: '/r2/social/creator_makhadzi/take1.mp4',
            media_kind: 'camera_video',
            audio_start_ms: 12000,
            audio_end_ms: 42000,
            effect_preset: 'super_8mm',
            effect_intensity: 0.8,
            typography_preset: 'luminousGlow',
            speed_rate: 1.5,
            sticker_id: 'stk_log_drum_hit',
            reaction_counts_json: {},
            data_json: {
              id: 'clip_swr_new',
              creatorUsername: 'makhadzi',
              creatorDisplayName: 'Makhadzi',
            },
            created_at: now + 5000,
            updated_at: now + 5000,
          },
          {
            id: 'clip_swr_old',
            track_id: 'trk_old',
            creator_id: 'creator_cern',
            title: 'Older Reel',
            caption: 'Legacy drop',
            genre: 'Gqom',
            likes_count: 10,
            comments_count: 0,
            remixes_count: 0,
            audio_url: '/r2/audio/old.mp3',
            cover_url: '/r2/covers/old.jpg',
            created_at: now - 10000,
            updated_at: now - 10000,
          },
        ];
      }
      if (table === 'reel_comments') {
        if (shouldFailComments) {
          throw new Error('simulated timeout');
        }
        return [];
      }
      if (table === 'social_interactions') {
        return [
          {
            interaction_type: 'clip_react',
            target_id: 'clip_swr_old',
            actor_creator_id: 'creator_cern',
            reaction_type: 'fire',
            created_at: now,
          },
        ];
      }
      return [];
    },
    upsertRow: async () => {
      upsertCalls += 1;
    },
    patchRows: async () => {
      patchCalls += 1;
    },
    deleteRows: async () => {},
  };

  const edge = new EdgeIsolateDatabaseEngine(fakeDriver as any);

  // Partial failure must NOT seal the 12s SWR window
  shouldFailComments = true;
  const firstSync = await edge.syncSocialFromCloud(false);
  assert.equal(firstSync, false);
  const callsAfterFailure = selectCalls;

  // Retry immediately after failure must hit cloud again because TTL was not stamped
  shouldFailComments = false;
  const secondSync = await edge.syncSocialFromCloud(false);
  assert.equal(secondSync, true);
  assert.ok(selectCalls > callsAfterFailure);

  // Immediate subsequent read hits 12s SWR cache with zero extra Supabase queries
  const callsBeforeCachedRead = selectCalls;
  const cachedSync = await edge.syncSocialFromCloud(false);
  assert.equal(cachedSync, true);
  assert.equal(selectCalls, callsBeforeCachedRead);

  // Newest-first timestamp ordering preserved (no blind .reverse() inverting DESC rows!)
  const ordered = edge.listPublishedClipRows();
  assert.equal(ordered[0].id, 'clip_swr_new');
  assert.equal(ordered[1].id, 'clip_swr_old');
  assert.equal(ordered[0].mediaKind, 'camera_video');
  assert.equal(ordered[0].stickerId, 'stk_log_drum_hit');
  assert.equal(ordered[0].speedRate, 1.5);

  // reactToClipAsync seeds counts.love = 1840 when unindexed + adds 1 fire = 1841, single write
  const rx1 = await edge.reactToClipAsync('clip_swr_new', 'creator_cern', 'fire');
  assert.equal(rx1.success, true);
  assert.equal(rx1.myReaction, 'fire');
  assert.equal(rx1.reactionCounts.love, 1840);
  assert.equal(rx1.reactionCounts.fire, 1);
  assert.equal(rx1.likeCount, 1841);
  assert.equal(upsertCalls, 1);
  assert.equal(patchCalls, 1);

  // upsertPublishedClipAsync issues single awaited cloud upsert without duplicate mirror
  await edge.upsertPublishedClipAsync({
    id: 'clip_swr_direct',
    trackId: 'trk_direct',
    title: 'Direct Publish',
    genre: 'Amapiano',
    mediaKind: 'gallery_video',
    videoUrl: '/r2/social/creator_cern/clip.mp4',
  });
  assert.equal(upsertCalls, 2);

  // 2. Live HTTP Route Verification: POST /api/social/media/upload
  const strictDenied = await app.request('/api/social/media/upload', {
    method: 'POST',
    headers: {
      'Content-Type': 'video/mp4',
      'x-vhunambi-enforce-auth': 'true',
    },
    body: new Uint8Array([1, 2, 3, 4]),
  });
  assert.equal(strictDenied.status, 401);

  const badMime = await app.request('/api/social/media/upload', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-msdownload' },
    body: new Uint8Array([1, 2, 3]),
  });
  assert.equal(badMime.status, 415);

  const oversized = new Uint8Array(25 * 1024 * 1024 + 16);
  const tooLarge = await app.request('/api/social/media/upload', {
    method: 'POST',
    headers: { 'Content-Type': 'video/mp4' },
    body: oversized,
  });
  assert.equal(tooLarge.status, 413);

  const form = new FormData();
  const mp4Bytes = new Uint8Array([0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70]);
  form.append('file', new Blob([mp4Bytes], { type: 'video/mp4' }), 'studio_take.mp4');
  const uploadOk = await app.request('/api/social/media/upload', {
    method: 'POST',
    body: form,
  });
  assert.equal(uploadOk.status, 201);
  const uploaded = (await uploadOk.json()) as any;
  assert.equal(uploaded.success, true);
  assert.ok(String(uploaded.url).startsWith('/r2/social/'));
  assert.equal(uploaded.contentType, 'video/mp4');
  assert.equal(uploaded.size, mp4Bytes.byteLength);

  // Verify uploaded R2 object is immediately readable via GET /r2/:key
  const r2Fetch = await app.request(uploaded.url);
  assert.equal(r2Fetch.status, 200);

  // Also allow audio/mpeg for imported local audio hooks
  const mp3Res = await app.request('/api/social/media/upload', {
    method: 'POST',
    headers: { 'Content-Type': 'audio/mpeg' },
    body: new Uint8Array([0x49, 0x44, 0x33, 0x03]),
  });
  assert.equal(mp3Res.status, 201);

  // 3. POST /api/social/publish + GET /api/social/clips/:id + POST /api/social/clips/:id/react
  const pubRes = await app.request('/api/social/publish', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      trackId: 'trk_p74_1',
      title: 'Limpopo Sunset Studio',
      caption: 'Recorded live in Makhado',
      tags: ['#Amapiano', '#VhunambiStudio'],
      visibility: 'public',
      videoUrl: uploaded.url,
      mediaKind: 'camera_video',
      audioStartMs: 5000,
      audioEndMs: 35000,
      effectPreset: 'makhado_warm',
      effectIntensity: 0.72,
      typographyPreset: 'kineticBounce',
      speedRate: 1.0,
      stickerId: 'stk_makhado_wave',
      dna: { genre: 'Amapiano', bpm: 113 },
    }),
  });
  assert.equal(pubRes.status, 201);
  const pubBody = (await pubRes.json()) as any;
  assert.ok(pubBody.clipId);

  const getClipRes = await app.request(`/api/social/clips/${pubBody.clipId}`);
  assert.equal(getClipRes.status, 200);
  const clipDetail = (await getClipRes.json()) as any;
  assert.equal(clipDetail.mediaKind, 'camera_video');
  assert.equal(clipDetail.stickerId, 'stk_makhado_wave');
  assert.equal(clipDetail.audioStartMs, 5000);
  assert.equal(clipDetail.audioEndMs, 35000);

  // Invalid reaction rejected with 400
  const badRx = await app.request(`/api/social/clips/${pubBody.clipId}/react`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ reactionType: 'unicorn' }),
  });
  assert.equal(badRx.status, 400);

  // Valid reaction toggle + switch + toggle off
  const rxFire = await app.request(`/api/social/clips/${pubBody.clipId}/react`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ reactionType: 'fire' }),
  });
  assert.equal(rxFire.status, 200);
  const rxFireJson = (await rxFire.json()) as any;
  assert.equal(rxFireJson.myReaction, 'fire');
  assert.equal(rxFireJson.reactionCounts.fire, 1);
  assert.equal(rxFireJson.likeCount, 1);

  const rxWow = await app.request(`/api/social/clips/${pubBody.clipId}/react`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ reactionType: 'wow' }),
  });
  assert.equal(rxWow.status, 200);
  const rxWowJson = (await rxWow.json()) as any;
  assert.equal(rxWowJson.myReaction, 'wow');
  assert.equal(rxWowJson.reactionCounts.fire ?? 0, 0);
  assert.equal(rxWowJson.reactionCounts.wow, 1);

  const rxOff = await app.request(`/api/social/clips/${pubBody.clipId}/react`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ reactionType: 'wow' }),
  });
  assert.equal(rxOff.status, 200);
  const rxOffJson = (await rxOff.json()) as any;
  assert.equal(rxOffJson.myReaction, null);
  assert.equal(rxOffJson.likeCount, 0);

  // Seed legacy SQLite reaction preservation sanity check
  vhunambiDb.upsertPublishedClip({
    id: 'clip_sqlite_legacy',
    trackId: 'trk_legacy',
    title: 'SQLite Legacy Clip',
    genre: 'Amapiano',
    likeCount: 1840,
  });
  const sqliteRx = vhunambiDb.reactToClip('clip_sqlite_legacy', 'creator_cern', 'fire');
  assert.equal(sqliteRx.reactionCounts.love, 1840);
  assert.equal(sqliteRx.reactionCounts.fire, 1);
  assert.equal(sqliteRx.likeCount, 1841);

  console.log('[Phase 74 Test] ALL ASSERTIONS PASSED!');
}

run().catch((err) => {
  console.error('[Phase 74 Test] FAILED:', err);
  process.exit(1);
});
