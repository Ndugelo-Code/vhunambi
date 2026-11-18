import { strict as assert } from 'node:assert';
import { app } from '../src/server.js';
import { getEdgeIsolateDatabaseEngine } from '../src/db/edge_persistence_bridge.js';
import {
  isNodeSqliteAvailable,
  setSimulateEdgeIsolateMode,
} from '../src/db/vhunambi_db.js';

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

async function exercisePipeline(modeLabel: string, postId: string): Promise<void> {
  console.log(`  [${modeLabel}] 1. Create & fetch Kinetic Post...`);
  const createRes = await reqJson('/api/v1/explore/posts', 'POST', {
    id: postId,
    creatorId: 'creator_makhadzi',
    creatorName: 'Makhadzi',
    creatorHandle: '@makhadzi',
    caption: 'Venda Folk LoRA & sub-bass log drum test',
    mediaType: 'audio_card',
    cosignCount: 5,
    repostCount: 2,
  });
  assert.equal(createRes.status, 201);
  assert.equal(createRes.data.post.id, postId);

  const getRes = await reqJson(`/api/v1/explore/posts/${postId}`, 'GET');
  assert.equal(getRes.status, 200);
  assert.equal(getRes.data.post.likeCount, 0);
  assert.equal(getRes.data.post.cosignCount, 5);

  console.log(`  [${modeLabel}] 2. Like toggle updates likeCount without touching cosignCount...`);
  const like1 = await reqJson(`/api/v1/explore/posts/${postId}/like`, 'POST', {
    creatorId: 'creator_cern',
  });
  assert.equal(like1.status, 200);
  assert.equal(like1.data.liked, true);
  assert.equal(like1.data.likeCount, 1);

  const afterLike = await reqJson(`/api/v1/explore/posts/${postId}`, 'GET');
  assert.equal(afterLike.data.post.likeCount, 1);
  assert.equal(afterLike.data.post.cosignCount, 5);

  console.log(`  [${modeLabel}] 3. Repost increments repostCount and upserts quote repost...`);
  const repostId = `${postId}_repost_cern`;
  const repostRes = await reqJson(`/api/v1/explore/posts/${postId}/repost`, 'POST', {
    repost: {
      id: repostId,
      creatorId: 'creator_cern',
      creatorName: 'Cern',
      creatorHandle: '@cern',
      caption: 'Must listen!',
      repostedFromPostId: postId,
      repostedFromCreatorHandle: '@makhadzi',
    },
  });
  assert.equal(repostRes.status, 200);
  assert.equal(repostRes.data.repostCount, 3);
  assert.equal(repostRes.data.repost.id, repostId);

  console.log(`  [${modeLabel}] 4. Add top-level comment, nested Author reply, and sort...`);
  const c1 = await reqJson(`/api/v1/explore/posts/${postId}/comments`, 'POST', {
    text: 'Heavy log drum slide!',
    userId: 'u_thabo',
    username: 'thabo_beats',
    displayName: 'Thabo Beats',
    userReelLoves: 5,
  });
  assert.equal(c1.status, 201);
  assert.equal(c1.data.isCreator, false);

  const c2 = await reqJson(`/api/v1/explore/posts/${postId}/comments`, 'POST', {
    text: 'Ndo livhuwa! Wait for Stem 2.',
    userId: 'creator_makhadzi',
    username: 'makhadzi',
    displayName: 'Makhadzi',
    parentCommentId: c1.data.id,
    replyToHandle: '@thabo_beats',
  });
  assert.equal(c2.status, 201);
  assert.equal(c2.data.parentCommentId, c1.data.id);
  assert.equal(c2.data.replyToHandle, '@thabo_beats');
  assert.equal(c2.data.isCreator, true);

  // Like c1 twice (toggle on -> toggle off)
  const likeComment1 = await reqJson(`/api/v1/explore/comments/${c1.data.id}/like`, 'POST', {});
  assert.equal(likeComment1.status, 200);
  assert.equal(likeComment1.data.liked, true);
  assert.equal(likeComment1.data.likeCount, 1);

  const threadRes = await reqJson(
    `/api/v1/explore/posts/${postId}/comments?sort=relevant`,
    'GET',
  );
  assert.equal(threadRes.status, 200);
  assert.equal(threadRes.data.total, 2);
  assert.equal(threadRes.data.comments[0].id, c1.data.id);

  const newestRes = await reqJson(
    `/api/v1/explore/posts/${postId}/comments?sort=newest`,
    'GET',
  );
  assert.equal(newestRes.status, 200);
  assert.equal(newestRes.data.comments.length, 2);

  console.log(`  [${modeLabel}] 5. /api/social/clips/:postId/comments falls back to kinetic_posts...`);
  const socialFallback = await reqJson(
    `/api/social/clips/${postId}/comments`,
    'POST',
    {
      text: 'Transparent fallback reply',
      userId: 'creator_sigwa',
      username: 'sigwa_inaf',
      displayName: 'Sigwa',
      parentCommentId: c1.data.id,
      replyToHandle: '@thabo_beats',
    },
  );
  assert.equal(socialFallback.status, 201);
  assert.equal(socialFallback.data.clipId, postId);

  console.log(`  [${modeLabel}] 6. Outbox sync mutations preserve like_count vs cosign_count & comment.create...`);
  const suffix = Date.now();
  const syncRes = await reqJson('/api/v1/sync/mutations', 'POST', {
    mutations: [
      {
        idempotencyKey: `mut_p69_like_${modeLabel}_${suffix}`,
        entityType: 'post',
        action: 'like',
        payload: { postId },
        createdAt: new Date().toISOString(),
      },
      {
        idempotencyKey: `mut_p69_repost_${modeLabel}_${suffix}`,
        entityType: 'post',
        action: 'repost',
        payload: { originalPostId: postId },
        createdAt: new Date().toISOString(),
      },
      {
        idempotencyKey: `mut_p69_comment_${modeLabel}_${suffix}`,
        entityType: 'comment',
        action: 'create',
        payload: {
          id: `c_sync_${modeLabel}_${suffix}`,
          postId,
          text: 'Synced offline comment',
          userId: 'creator_cern',
          username: 'cern',
          displayName: 'Cern',
          parentCommentId: c1.data.id,
          replyToHandle: '@thabo_beats',
        },
        createdAt: new Date().toISOString(),
      },
    ],
  });
  assert.equal(syncRes.status, 200);
  assert.equal(syncRes.data.applied.length, 3);

  const finalPost = await reqJson(`/api/v1/explore/posts/${postId}`, 'GET');
  assert.equal(finalPost.data.post.likeCount, 2, 'post.like sync increments likeCount');
  assert.equal(finalPost.data.post.cosignCount, 5, 'post.like sync never corrupts cosignCount');
  assert.equal(finalPost.data.post.repostCount, 4, 'post.repost sync increments repostCount');
  assert.equal(finalPost.data.post.commentCount, 4, '4 total comments recorded');
}

async function runPhase69Tests(): Promise<void> {
  console.log('Running Phase 69 Kinetic Posts & Threaded Comments API Tests...');
  try {
    setSimulateEdgeIsolateMode(false);
    assert.equal(isNodeSqliteAvailable(), true);
    await exercisePipeline('SQLite', 'post_p69_sqlite_01');

    setSimulateEdgeIsolateMode(true);
    getEdgeIsolateDatabaseEngine().resetForTesting();
    assert.equal(isNodeSqliteAvailable(), false);
    await exercisePipeline('EdgeIsolate', 'post_p69_edge_01');

    console.log('ALL Phase 69 Backend & Edge Tests PASSED!');
  } finally {
    setSimulateEdgeIsolateMode(false);
  }
}

runPhase69Tests().catch((err) => {
  console.error('Phase 69 test failure:', err);
  process.exit(1);
});
