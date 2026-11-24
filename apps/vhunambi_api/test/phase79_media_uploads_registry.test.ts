import assert from 'node:assert/strict';
import { app } from '../src/server.js';
import { EdgeIsolateDatabaseEngine } from '../src/db/edge_persistence_bridge.js';
import { vhunambiDb } from '../src/db/vhunambi_db.js';

async function run(): Promise<void> {
  console.log('[Phase 79 Test] Running Sovereign Media Uploads Registry & SWR suite...');

  // 1. EdgeIsolateDatabaseEngine 12s SWR & Timeout Hygiene
  let selectCalls = 0;
  let shouldFailSelect = false;
  let upsertCalls = 0;
  let patchCalls = 0;

  const fakeDriver = {
    isConfigured: () => true,
    selectRows: async (table: string) => {
      selectCalls += 1;
      if (shouldFailSelect) {
        throw new Error('simulated cloud timeout');
      }
      if (table === 'user_media_uploads') {
        return [
          {
            id: 'upl_swr_audio_1',
            creator_id: 'creator_cern',
            media_kind: 'audio',
            title: 'Abafana Master',
            filename: 'abafana.wav',
            mime_type: 'audio/wav',
            size_bytes: 12000,
            duration_ms: 45000,
            r2_key: 'media/creator_cern/upl_swr_audio_1.wav',
            remote_url: '/r2/media/creator_cern/upl_swr_audio_1.wav',
            source_surface: 'reel_picker',
            created_at: '2026-11-24T08:00:00.000Z',
            deleted_at: null,
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

  // Failed cloud select must NOT seal 12s SWR window
  shouldFailSelect = true;
  const failedList = await edge.syncUserMediaUploadsFromCloud('creator_cern');
  assert.equal(failedList.length, 0);
  const callsAfterFail = selectCalls;

  // Immediate retry after failure hits cloud and hydrates records
  shouldFailSelect = false;
  const hydratedList = await edge.syncUserMediaUploadsFromCloud('creator_cern');
  assert.equal(hydratedList.length, 1);
  assert.equal(hydratedList[0].id, 'upl_swr_audio_1');
  assert.equal(hydratedList[0].mediaKind, 'audio');
  assert.ok(selectCalls > callsAfterFail);

  // Cached SWR read within 12s makes zero extra cloud calls
  const callsBeforeCached = selectCalls;
  const cachedList = await edge.syncUserMediaUploadsFromCloud('creator_cern');
  assert.equal(cachedList.length, 1);
  assert.equal(selectCalls, callsBeforeCached);

  // recordUserMediaUploadAsync awaits single cloud upsert without duplicate mirror
  await edge.recordUserMediaUploadAsync({
    id: 'upl_swr_img_1',
    creatorId: 'creator_cern',
    mediaKind: 'image',
    title: 'Studio Session',
    filename: 'session.png',
    mimeType: 'image/png',
    sizeBytes: 4096,
    r2Key: 'media/creator_cern/upl_swr_img_1.png',
    remoteUrl: '/r2/media/creator_cern/upl_swr_img_1.png',
    sourceSurface: 'kinetic_post',
  });
  assert.equal(upsertCalls, 1);
  assert.equal(edge.listUserMediaUploads('creator_cern', 'image').length, 1);
  assert.equal(edge.listUserMediaUploads('creator_cern', 'audio').length, 1);

  // Soft delete awaits single cloud patch and hides from list
  const deleted = await edge.deleteUserMediaUploadAsync(
    'upl_swr_img_1',
    'creator_cern',
  );
  assert.equal(deleted, true);
  assert.equal(patchCalls, 1);
  assert.equal(edge.listUserMediaUploads('creator_cern', 'image').length, 0);

  // 2. Live HTTP Route Verification: POST /api/media/upload (multipart + raw binary)
  const badMime = await app.request('/api/media/upload', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-msdownload' },
    body: new Uint8Array([1, 2, 3]),
  });
  assert.equal(badMime.status, 415);

  const oversized = new Uint8Array(25 * 1024 * 1024 + 16);
  const tooLarge = await app.request('/api/media/upload', {
    method: 'POST',
    headers: { 'Content-Type': 'video/mp4' },
    body: oversized,
  });
  assert.equal(tooLarge.status, 413);

  const form = new FormData();
  const wavBytes = new Uint8Array([0x52, 0x49, 0x46, 0x46, 0x24, 0x00, 0x00, 0x00]);
  form.append('file', new Blob([wavBytes], { type: 'audio/wav' }), 'abafana.wav');
  form.append('title', 'Abafana');
  form.append('sourceSurface', 'reel_picker');
  form.append('durationMs', '42000');

  const uploadRes = await app.request('/api/media/upload', {
    method: 'POST',
    body: form,
  });
  assert.equal(uploadRes.status, 201);
  const uploadJson = (await uploadRes.json()) as any;
  assert.equal(uploadJson.success, true);
  assert.equal(uploadJson.asset.title, 'Abafana');
  assert.equal(uploadJson.asset.mediaKind, 'audio');
  assert.equal(uploadJson.asset.durationMs, 42000);
  assert.ok(String(uploadJson.url).startsWith('/r2/media/'));

  // Raw binary image upload via /api/v1/media/upload
  const pngBytes = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  const rawImgRes = await app.request('/api/v1/media/upload', {
    method: 'POST',
    headers: {
      'Content-Type': 'image/png',
      'x-media-filename': 'cover_take.png',
      'x-media-title': 'Cover Take',
      'x-media-surface': 'kinetic_post',
    },
    body: pngBytes,
  });
  assert.equal(rawImgRes.status, 201);
  const rawImgJson = (await rawImgRes.json()) as any;
  assert.equal(rawImgJson.asset.mediaKind, 'image');

  // GET /api/media/uploads with kind filter
  const audioListRes = await app.request('/api/media/uploads?kind=audio');
  assert.equal(audioListRes.status, 200);
  const audioListJson = (await audioListRes.json()) as any;
  assert.ok(
    audioListJson.uploads.some((u: any) => u.id === uploadJson.asset.id),
    'Audio upload must be listed in GET /api/media/uploads?kind=audio',
  );

  // Backward-compatible POST /api/social/media/upload also indexes into user_media_uploads
  const socialRes = await app.request('/api/social/media/upload', {
    method: 'POST',
    headers: { 'Content-Type': 'video/mp4' },
    body: new Uint8Array([0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70]),
  });
  assert.equal(socialRes.status, 201);
  const socialJson = (await socialRes.json()) as any;
  assert.ok(String(socialJson.url).startsWith('/r2/social/'));
  const videoListRes = await app.request('/api/media/uploads?kind=video');
  assert.equal(videoListRes.status, 200);
  const videoListJson = (await videoListRes.json()) as any;
  assert.ok(
    videoListJson.uploads.some((u: any) => u.remoteUrl === socialJson.url),
    'Legacy /api/social/media/upload must index into user_media_uploads',
  );

  // 3. Cross-tenant DELETE isolation returns 403 TENANT_FORBIDDEN
  const loginMakhadzi = await app.request('/api/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      identifier: '@makhadzi',
      password: 'VhunambiSovereign!2026',
    }),
  });
  assert.equal(loginMakhadzi.status, 200);
  const makhadziAuth = (await loginMakhadzi.json()) as any;
  const makhadziToken = makhadziAuth.accessToken as string;

  const crossTenantDelete = await app.request(
    `/api/media/uploads/${uploadJson.asset.id}`,
    {
      method: 'DELETE',
      headers: {
        Authorization: `Bearer ${makhadziToken}`,
        'x-vhunambi-enforce-auth': 'true',
      },
    },
  );
  assert.equal(crossTenantDelete.status, 403);
  const crossDeleteJson = (await crossTenantDelete.json()) as any;
  assert.equal(crossDeleteJson.code, 'TENANT_FORBIDDEN');

  // Owner delete succeeds and hides upload from GET
  const ownerDelete = await app.request(
    `/api/media/uploads/${uploadJson.asset.id}`,
    { method: 'DELETE' },
  );
  assert.equal(ownerDelete.status, 200);
  const afterDelete = vhunambiDb.getUserMediaUploadById(uploadJson.asset.id);
  assert.equal(afterDelete, null);

  console.log('[Phase 79 Test] ALL ASSERTIONS PASSED!');
}

run().catch((err) => {
  console.error('[Phase 79 Test] FAILED:', err);
  process.exit(1);
});
