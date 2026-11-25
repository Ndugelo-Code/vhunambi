import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { app } from '../src/server.js';
import { EdgeIsolateDatabaseEngine } from '../src/db/edge_persistence_bridge.js';
import {
  extractApicFrame,
  extractId3v2Metadata,
  readId3TagByteLength,
} from '../src/modules/media/id3v2_parser.js';
import { computeEdgeEtag, isIfNoneMatchHit } from '../src/modules/media/etag.js';
import {
  decodeExploreCursor,
  encodeExploreCursor,
} from '../src/modules/media/cursor.js';

function synchSafeBytes(val: number): [number, number, number, number] {
  return [
    (val >> 21) & 0x7f,
    (val >> 14) & 0x7f,
    (val >> 7) & 0x7f,
    val & 0x7f,
  ];
}

function buildTextFrame(id: string, text: string, encoding = 3): Uint8Array {
  const textBytes =
    encoding === 1
      ? Buffer.concat([Buffer.from([0xff, 0xfe]), Buffer.from(text, 'utf16le')])
      : Buffer.from(text, 'utf8');
  const payload = Buffer.concat([Buffer.from([encoding]), textBytes]);
  const header = Buffer.alloc(10);
  header.write(id, 0, 4, 'ascii');
  const sz = synchSafeBytes(payload.length);
  header[4] = sz[0];
  header[5] = sz[1];
  header[6] = sz[2];
  header[7] = sz[3];
  return new Uint8Array(Buffer.concat([header, payload]));
}

function buildApicFrame(mime: string, imageBytes: Uint8Array): Uint8Array {
  const payload = Buffer.concat([
    Buffer.from([0x00]), // ISO-8859-1
    Buffer.from(mime, 'ascii'),
    Buffer.from([0x00]),
    Buffer.from([0x03]), // Cover (front)
    Buffer.from([0x00]), // empty description
    Buffer.from(imageBytes),
  ]);
  const header = Buffer.alloc(10);
  header.write('APIC', 0, 4, 'ascii');
  const sz = synchSafeBytes(payload.length);
  header[4] = sz[0];
  header[5] = sz[1];
  header[6] = sz[2];
  header[7] = sz[3];
  return new Uint8Array(Buffer.concat([header, payload]));
}

function buildSyntheticMp3WithId3v24(frames: Uint8Array[]): Uint8Array {
  const body = Buffer.concat(frames.map((f) => Buffer.from(f)));
  const header = Buffer.alloc(10);
  header.write('ID3', 0, 3, 'ascii');
  header[3] = 4; // v2.4
  header[4] = 0;
  header[5] = 0;
  const sz = synchSafeBytes(body.length);
  header[6] = sz[0];
  header[7] = sz[1];
  header[8] = sz[2];
  header[9] = sz[3];
  const audioPadding = Buffer.from([0xff, 0xfb, 0x90, 0x64, 0x00, 0x00]);
  return new Uint8Array(Buffer.concat([header, body, audioPadding]));
}

async function run(): Promise<void> {
  console.log('[Phase 84 Test] Running Edge ID3v2, Direct-R2 Presign/Finalize, Cursor/ETag & Write-Through suite...');

  // 1. Pure Edge ID3v2 extraction (APIC image/jpg alias + UTF-16 Venda diacritics + TCON cleanup)
  const fakeJpeg = new Uint8Array([
    0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46,
    0x00, 0x01, 0x01, 0x00, 0x00, 0x01, 0xff, 0xd9,
  ]);
  const mp3Bytes = buildSyntheticMp3WithId3v24([
    buildTextFrame('TIT2', 'Ṅwala Makoleni', 1),
    buildTextFrame('TPE1', 'Zania Venda', 3),
    buildTextFrame('TALB', 'Limpopo Nights', 3),
    buildTextFrame('TCON', '(17)Afrobeats', 3),
    buildTextFrame('TBPM', '116', 3),
    buildApicFrame('image/jpg', fakeJpeg),
  ]);

  const parsed = extractId3v2Metadata(mp3Bytes);
  assert.ok(parsed);
  assert.equal(parsed.version, 4);
  assert.equal(parsed.title, 'Ṅwala Makoleni'.normalize('NFC'));
  assert.equal(parsed.artist, 'Zania Venda');
  assert.equal(parsed.album, 'Limpopo Nights');
  assert.equal(parsed.genre, 'Afrobeats');
  assert.equal(parsed.bpm, 116);
  assert.ok(parsed.apic);
  assert.equal(parsed.apic.mimeType, 'image/jpeg');
  assert.equal(parsed.apic.ext, 'jpg');
  assert.equal(parsed.apic.imageData.byteLength, fakeJpeg.byteLength);

  // Truncated window before APIC still recovers text frames without crashing
  const declaredLen = readId3TagByteLength(mp3Bytes);
  assert.ok(declaredLen && declaredLen > 40);
  const partialWindow = extractId3v2Metadata(mp3Bytes.subarray(0, mp3Bytes.length - 12));
  assert.ok(partialWindow);
  assert.equal(partialWindow.title, 'Ṅwala Makoleni'.normalize('NFC'));
  assert.equal(extractApicFrame(new Uint8Array([0x00, 0x01, 0x02])), null);

  // 2. FNV-1a ETag & base64url Keyset Cursor
  const etagA = computeEdgeEtag('{"tracks":[1,2]}');
  const etagB = computeEdgeEtag('{"tracks":[1,3]}');
  assert.notEqual(etagA, etagB);
  assert.equal(isIfNoneMatchHit(etagA, etagA), true);
  assert.equal(isIfNoneMatchHit(`"other", ${etagA}`, etagA), true);
  assert.equal(isIfNoneMatchHit(etagB, etagA), false);

  const encoded = encodeExploreCursor({ sortKey: '2026-11-25T10:00:00Z', id: 'trk_123' });
  assert.deepEqual(decodeExploreCursor(encoded), {
    sortKey: '2026-11-25T10:00:00Z',
    id: 'trk_123',
  });
  assert.equal(decodeExploreCursor('!!!not-valid-base64!!!'), null);
  assert.equal(decodeExploreCursor(''), null);

  // 3. Direct-to-R2 presign-put + SHA-256 deduplication + /upload ID3 auto-cover
  const sha = createHash('sha256').update(mp3Bytes).digest('hex');
  const badPresign = await app.request('/api/media/presign-put', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      filename: 'bad.exe',
      mimeType: 'application/x-msdownload',
      sizeBytes: 1200,
    }),
  });
  assert.equal(badPresign.status, 415);

  const bigImage = await app.request('/api/media/presign-put', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      filename: 'huge.png',
      mimeType: 'image/png',
      sizeBytes: 30 * 1024 * 1024,
    }),
  });
  assert.equal(bigImage.status, 413);

  // Presign allows up to 100 MB video
  const bigVideoOk = await app.request('/api/media/presign-put', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      filename: 'reel_95mb.mov',
      mimeType: 'video/quicktime',
      sizeBytes: 95 * 1024 * 1024,
    }),
  });
  assert.equal(bigVideoOk.status, 201);
  const bigVideoJson = (await bigVideoOk.json()) as Record<string, any>;
  assert.ok(String(bigVideoJson.r2Key).endsWith('.mov'));

  // Raw binary /api/media/upload extracts APIC cover + ID3 tags + registers SHA-256
  const upRes = await app.request('/api/media/upload', {
    method: 'POST',
    headers: {
      'Content-Type': 'audio/mpeg',
      'x-media-filename': 'nwala_makoleni.mp3',
      'x-media-surface': 'zania_ingest',
      'x-media-sha256': sha,
    },
    body: mp3Bytes,
  });
  assert.equal(upRes.status, 201);
  const upJson = (await upRes.json()) as Record<string, any>;
  assert.ok(String(upJson.thumbnailUrl).startsWith('/r2/covers/'));
  assert.equal(upJson.asset.title, 'Ṅwala Makoleni'.normalize('NFC'));
  assert.equal(upJson.asset.id3Metadata.genre, 'Afrobeats');
  assert.equal(upJson.asset.id3Metadata.bpm, 116);

  // Extracted cover serves live over GET /r2/:key
  const coverServe = await app.request(String(upJson.thumbnailUrl));
  assert.equal(coverServe.status, 200);
  const servedBytes = new Uint8Array(await coverServe.arrayBuffer());
  assert.equal(servedBytes.byteLength, fakeJpeg.byteLength);

  // Second presign-put with same SHA-256 deduplicates without minting duplicate object
  const dedupePresign = await app.request('/api/media/presign-put', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      filename: 'nwala_makoleni.mp3',
      mimeType: 'audio/mpeg',
      sizeBytes: mp3Bytes.byteLength,
      contentSha256: sha,
    }),
  });
  assert.equal(dedupePresign.status, 200);
  const dedupeJson = (await dedupePresign.json()) as Record<string, any>;
  assert.equal(dedupeJson.deduplicated, true);
  assert.equal(dedupeJson.asset.id, upJson.asset.id);

  // /finalize rejects missing object with 404 and cross-tenant r2Key with 403
  const missingFin = await app.request('/api/media/finalize', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      uploadId: 'upl_missing',
      r2Key: 'media/creator_cern/does_not_exist.mp3',
      filename: 'missing.mp3',
      mimeType: 'audio/mpeg',
      sizeBytes: 100,
    }),
  });
  assert.equal(missingFin.status, 404);

  const foreignFin = await app.request('/api/media/finalize', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      uploadId: 'upl_foreign',
      r2Key: 'media/creator_other/hack.mp3',
      filename: 'hack.mp3',
      mimeType: 'audio/mpeg',
      sizeBytes: 100,
    }),
  });
  assert.equal(foreignFin.status, 403);

  // 4. Explore Tracks ETag 304 + Keyset Cursor + Durable Edge Write-Through
  const trk1Res = await app.request('/api/explore/tracks?limit=2&sort=newest');
  assert.equal(trk1Res.status, 200);
  const etagHeader = trk1Res.headers.get('etag');
  assert.ok(etagHeader);
  const trk1Json = (await trk1Res.json()) as Record<string, any>;
  assert.ok(Array.isArray(trk1Json.items) && trk1Json.items.length > 0);

  const trk304 = await app.request('/api/explore/tracks?limit=2&sort=newest', {
    headers: { 'If-None-Match': etagHeader! },
  });
  assert.equal(trk304.status, 304);

  const upsertedTables: string[] = [];
  const edge = new EdgeIsolateDatabaseEngine({
    isConfigured: () => true,
    selectRows: async () => [],
    upsertRow: async (table: string) => {
      await new Promise((r) => setTimeout(r, 15));
      upsertedTables.push(table);
    },
    patchRows: async () => {},
    deleteRows: async () => {},
  } as any);

  await edge.upsertKineticPostAsync({
    id: 'kpost_p84_durable_1',
    creatorId: 'creator_cern',
    caption: 'Live studio check',
    audioUrl: '/r2/media/creator_cern/song.mp3',
    coverUrl: '/r2/covers/creator_cern/cover.jpg',
  });
  await edge.upsertExploreTrackAsync({
    id: 'trk_p84_durable_1',
    creatorId: 'creator_cern',
    title: 'Zania Durable Track',
    genre: 'Amapiano',
    audioUrl: '/r2/media/creator_cern/song.mp3',
    contentSha256: sha,
    sourceOrigin: 'creator_upload_zania',
  });
  assert.deepEqual(upsertedTables, ['kinetic_posts', 'explore_tracks']);

  console.log('[Phase 84 Test] ALL ASSERTIONS PASSED!');
}

run().catch((err) => {
  console.error('[Phase 84 Test Failed]', err);
  process.exit(1);
});
