import assert from 'node:assert/strict';
import { app } from '../src/server.js';
import { vhunambiDb } from '../src/db/vhunambi_db.js';
import { EdgeIsolateDatabaseEngine } from '../src/db/edge_persistence_bridge.js';

async function run(): Promise<void> {
  console.log('[Phase 73 Test] Running Multi-Reactions, Comment Media & GIF Proxy suite...');

  const post = vhunambiDb.upsertKineticPost({
    id: 'kpost_p73_test_1',
    creatorId: 'creator_makhadzi',
    creatorName: 'Makhadzi',
    creatorHandle: '@makhadzi',
    caption: 'Phase 73 Chromatic & Reaction Test',
    likeCount: 1840,
    track: {
      id: 'trk_p73_1',
      title: 'Limpopo Sunset',
      creatorName: 'Makhadzi',
      genre: 'Amapiano',
      mood: 'Soulful',
    },
  });
  assert.equal(post.id, 'kpost_p73_test_1');
  assert.equal(post.likeCount, 1840);

  // 1. Toggle fire reaction on existing 1840-like post -> must preserve 1840 legacy likes + add 1 fire = 1841!
  const r1 = await app.request('/api/explore/posts/kpost_p73_test_1/react', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ reactionType: 'fire' }),
  });
  assert.equal(r1.status, 200);
  const b1 = (await r1.json()) as any;
  assert.equal(b1.myReaction, 'fire');
  assert.equal(b1.reactionCounts.love, 1840);
  assert.equal(b1.reactionCounts.fire, 1);
  assert.equal(b1.likeCount, 1841);

  // 2. Switch reaction fire -> wow (atomic decrement fire, increment wow, preserve 1840 love)
  const r2 = await app.request('/api/explore/posts/kpost_p73_test_1/react', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ reactionType: 'wow' }),
  });
  assert.equal(r2.status, 200);
  const b2 = (await r2.json()) as any;
  assert.equal(b2.myReaction, 'wow');
  assert.equal(b2.reactionCounts.fire ?? 0, 0);
  assert.equal(b2.reactionCounts.wow, 1);
  assert.equal(b2.reactionCounts.love, 1840);
  assert.equal(b2.likeCount, 1841);

  // 3. Repeat wow -> toggles off to null, restoring 1840 total
  const r3 = await app.request('/api/explore/posts/kpost_p73_test_1/react', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ reactionType: 'wow' }),
  });
  assert.equal(r3.status, 200);
  const b3 = (await r3.json()) as any;
  assert.equal(b3.myReaction, null);
  assert.equal(b3.likeCount, 1840);

  // 4. Media-only sticker comment succeeds without text
  const cRes = await app.request('/api/explore/posts/kpost_p73_test_1/comments', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      text: '',
      stickerId: 'stk_log_drum_hit',
      mediaAspectRatio: 1.0,
    }),
  });
  assert.equal(cRes.status, 201);
  const createdComment = (await cRes.json()) as any;
  assert.equal(createdComment.stickerId, 'stk_log_drum_hit');

  // 5. Comment multi-reaction toggle
  const crRes = await app.request(
    `/api/explore/comments/${createdComment.id}/react`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ reactionType: 'haha' }),
    },
  );
  assert.equal(crRes.status, 200);
  const crBody = (await crRes.json()) as any;
  assert.equal(crBody.myReaction, 'haha');
  assert.equal(crBody.reactionCounts.haha, 1);

  // 6. Empty comment without media rejected with 400
  const badComment = await app.request(
    '/api/explore/posts/kpost_p73_test_1/comments',
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text: '   ' }),
    },
  );
  assert.equal(badComment.status, 400);

  // 7. EdgeIsolateDatabaseEngine preserves legacy counts & avoids duplicate writes on async
  let upsertCount = 0;
  let patchCount = 0;
  const fakeDriver = {
    isConfigured: () => true,
    selectRows: async (table: string) => {
      if (table === 'social_interactions') {
        return [
          {
            interaction_type: 'post_react',
            target_id: 'kpost_swr_1',
            actor_creator_id: 'creator_cern',
            reaction_type: 'fire',
            created_at: Date.now(),
          },
        ];
      }
      if (table === 'kinetic_posts') {
        return [
          {
            id: 'kpost_swr_1',
            creator_id: 'creator_makhadzi',
            creator_handle: '@makhadzi',
            creator_name: 'Makhadzi',
            caption: 'SWR post',
            like_count: 100,
            reaction_counts_json: { love: 99, fire: 1 },
            created_at: Date.now(),
            updated_at: Date.now(),
          },
        ];
      }
      return [];
    },
    upsertRow: async () => {
      upsertCount += 1;
    },
    patchRows: async () => {
      patchCount += 1;
    },
    deleteRows: async () => {},
  };
  const edge = new EdgeIsolateDatabaseEngine(fakeDriver as any);
  const synced = await edge.syncExploreFromCloud(true);
  assert.equal(synced, true);
  const hydratedPost = edge.getKineticPostById('kpost_swr_1', 'creator_cern');
  assert.equal(hydratedPost?.myReaction, 'fire');
  await edge.reactToKineticPostAsync('kpost_swr_1', 'creator_cern', 'haha');
  assert.equal(upsertCount, 1);
  assert.equal(patchCount, 1);

  // 8. GIF search & trending return 200 with curated fallback when no key configured
  const gifRes = await app.request('/api/social/gifs/search?q=amapiano');
  assert.equal(gifRes.status, 200);
  const gifBody = (await gifRes.json()) as any;
  assert.equal(gifBody.success, true);
  assert.ok(Array.isArray(gifBody.items) && gifBody.items.length > 0);

  console.log('[Phase 73 Test] ALL ASSERTIONS PASSED!');
}

run().catch((err) => {
  console.error('[Phase 73 Test] FAILED:', err);
  process.exit(1);
});
