import { strict as assert } from 'node:assert';
import { app } from '../src/server.js';
import { getEdgeIsolateDatabaseEngine } from '../src/db/edge_persistence_bridge.js';
import {
  isNodeSqliteAvailable,
  setSimulateEdgeIsolateMode,
} from '../src/db/vhunambi_db.js';
import { normalizeVhunambiMoodId } from '../src/utils/mood_taxonomy.js';

async function reqJson(
  path: string,
  method: 'GET' | 'POST' = 'GET',
  body?: unknown,
  headers: Record<string, string> = {},
): Promise<{ status: number; data: any }> {
  const res = await app.request(path, {
    method,
    headers: {
      ...(body !== undefined ? { 'Content-Type': 'application/json' } : {}),
      ...headers,
    },
    ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
  });
  const data = await res.json();
  return { status: res.status, data };
}

async function exerciseExploreAndProducerBeats(
  modeLabel: string,
  trackId: string,
): Promise<void> {
  console.log(`  [${modeLabel}] 1. POST /api/explore/tracks persists moodId, description & allowOpenStemsRemix...`);
  const postRes = await reqJson('/api/explore/tracks', 'POST', {
    id: trackId,
    title: 'Afro Sunset Melodies (Phase 70)',
    creatorId: 'creator_lerato',
    creatorName: 'Lerato',
    creatorHandle: '@lerato_prod',
    genre: 'Afro-Soul',
    mood: 'Melancholic',
    description: 'Warm guitar & log drum session in Johannesburg.',
    allowOpenStemsRemix: true,
    bpm: 112,
    musicalKey: 'F# Minor',
    audioUrl: 'https://cdn.vhunambi.za/audio/afro_sunset_p70.mp3',
  });
  assert.equal(postRes.status, 201);
  assert.equal(postRes.data.track.moodId, 'soulful');
  assert.equal(
    postRes.data.track.description,
    'Warm guitar & log drum session in Johannesburg.',
  );
  assert.equal(postRes.data.track.allowOpenStemsRemix, true);

  console.log(`  [${modeLabel}] 2. GET /api/explore/tracks?mood=Nostalgic filters by canonical moodId='soulful'...`);
  const listRes = await reqJson('/api/explore/tracks?mood=Nostalgic', 'GET');
  assert.equal(listRes.status, 200);
  const found = (listRes.data.items as any[]).find((t) => t.id === trackId);
  assert.ok(found, `Expected track ${trackId} under moodId='soulful'`);
  assert.equal(found.moodId, 'soulful');
  assert.equal(found.description, 'Warm guitar & log drum session in Johannesburg.');
  assert.equal(found.allowOpenStemsRemix, true);
  for (const item of listRes.data.items as any[]) {
    assert.equal(item.moodId, 'soulful');
  }

  console.log(`  [${modeLabel}] 3. GET /api/marketplace/producers/:producerId/beats returns live beats...`);
  const beatsRes = await reqJson('/api/marketplace/producers/creator_sipho/beats', 'GET');
  assert.equal(beatsRes.status, 200);
  assert.equal(beatsRes.data.producerId, 'creator_sipho');
  assert.ok(Array.isArray(beatsRes.data.beats));
}

async function runPhase70Tests(): Promise<void> {
  console.log('Running Phase 70 Canonical Mood & Producer Beats API Tests...');

  assert.equal(normalizeVhunambiMoodId('Vibrant'), 'uplifting');
  assert.equal(normalizeVhunambiMoodId('Soulful & Nostalgic'), 'soulful');
  assert.equal(normalizeVhunambiMoodId('Party'), 'energetic');
  assert.equal(normalizeVhunambiMoodId('Peaceful'), 'chill');
  assert.equal(normalizeVhunambiMoodId('Atmospheric'), 'hypnotic');
  assert.equal(normalizeVhunambiMoodId('Sensual'), 'romantic');
  assert.equal(normalizeVhunambiMoodId(null), 'uplifting');

  try {
    setSimulateEdgeIsolateMode(false);
    assert.equal(isNodeSqliteAvailable(), true);
    await exerciseExploreAndProducerBeats('SQLite', 'trk_p70_sqlite_01');

    setSimulateEdgeIsolateMode(true);
    getEdgeIsolateDatabaseEngine().resetForTesting();
    assert.equal(isNodeSqliteAvailable(), false);
    await exerciseExploreAndProducerBeats('EdgeIsolate', 'trk_p70_edge_01');

    console.log('ALL Phase 70 Mood & Producer Beats Tests PASSED!');
  } finally {
    setSimulateEdgeIsolateMode(false);
  }
}

runPhase70Tests().catch((err) => {
  console.error('Phase 70 test failure:', err);
  process.exit(1);
});
