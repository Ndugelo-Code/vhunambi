import assert from 'node:assert';
import { app } from '../src/server.js';
import { countClips } from '../src/modules/social/social_service.js';

/** Shape of a published clip as returned by the API. */
interface PublishedClipDto {
  id: string;
  trackId: string;
  creatorId: string;
  creatorUsername: string;
  creatorDisplayName: string;
  creatorAvatarUrl: string | null;
  isCreatorVerified: boolean;
  title: string;
  caption: string;
  tags: string[];
  genre: string;
  audioUrl: string;
  coverUrl: string;
  dna: Record<string, unknown>;
  playCount: number;
  likeCount: number;
  commentCount: number;
  remixCount: number;
  isLikedByMe: boolean;
  isSavedByMe: boolean;
  publishedAt: string;
}

interface FeedPage {
  clips: PublishedClipDto[];
  nextCursor: string | null;
}

interface PublishResult {
  success: boolean;
  clipId: string;
  shareUrl: string;
  publishedAt: string;
}

function post(path: string, body: unknown) {
  return app.request(path, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
}

function get(path: string) {
  return app.request(path);
}

const CLIP_KEYS = [
  'audioUrl', 'caption', 'commentCount', 'coverUrl', 'creatorAvatarUrl',
  'creatorDisplayName', 'creatorId', 'creatorUsername', 'dna', 'genre', 'id',
  'isCreatorVerified', 'isLikedByMe', 'isSavedByMe', 'likeCount', 'playCount',
  'publishedAt', 'remixCount', 'tags', 'title', 'trackId',
].sort();

async function runTests() {
  console.log('🧪 Running Vhunambi API Social Creator Network Tests...');
  const baselineClips = countClips();

  // 1. POST /api/social/publish -> 201 + share descriptor
  console.log('  1. Testing POST /api/social/publish...');
  const publishRes = await post('/api/social/publish', {
    trackId: 'track_test_publish_1',
    title: 'Venda Sunrise',
    caption: 'Test caption for the social pipeline 🎹',
    tags: ['Amapiano', 'Tshivenḓa'],
    visibility: 'public',
    dna: {
      genre: 'Amapiano', bpm: 112, mood: 'Uplifting',
      paletteId: 'sunsetGold', typographyPreset: 'karaokeBounce', timestamps: [],
    },
  });
  assert.strictEqual(publishRes.status, 201, 'publish must return 201');
  const published = (await publishRes.json()) as PublishResult;
  assert.strictEqual(published.success, true, 'publish success flag');
  assert.ok(published.clipId.startsWith('clip_pub_'), 'clipId prefix');
  assert.ok(
    published.shareUrl.includes('/reels/') && published.shareUrl.includes('@'),
    'shareUrl must follow the /@username/reels/:id deep-link format',
  );
  assert.ok(!Number.isNaN(Date.parse(published.publishedAt)), 'ISO-8601 date');
  assert.strictEqual(countClips(), baselineClips + 1, 'publish must store a clip');
  console.log('     ✅ POST /api/social/publish passed');

  // 2. GET /api/social/feed -> 200 + schema + contains the new clip
  console.log('  2. Testing GET /api/social/feed...');
  const feedRes = await get('/api/social/feed');
  assert.strictEqual(feedRes.status, 200, 'feed must return 200');
  const feed = (await feedRes.json()) as FeedPage;
  assert.ok(Array.isArray(feed.clips), 'feed.clips must be an array');
  assert.ok(feed.clips.length >= baselineClips, 'feed must include seeded clips');
  const justPublished = feed.clips.find((c) => c.id === published.clipId);
  assert.ok(justPublished, 'newly published clip must appear in the feed');
  assert.deepStrictEqual(
    Object.keys(justPublished!).sort(), CLIP_KEYS,
    'clip DTO must expose exactly the documented fields',
  );
  assert.strictEqual(justPublished!.isLikedByMe, false, 'new clip starts un-liked');
  assert.strictEqual(justPublished!.genre, 'Amapiano', 'genre derives from dna.genre');
  const dna = justPublished!.dna as Record<string, unknown>;
  for (const key of ['musical', 'vocals', 'visualTheme']) {
    assert.ok(
      dna[key] && typeof dna[key] === 'object',
      `normalized dna must include a ${key} object for the Dart SongMetadataDna parser`,
    );
  }
  console.log('     ✅ GET /api/social/feed passed');

  // 3. Cursor pagination
  console.log('  3. Testing feed cursor pagination...');
  const page1 = (await (await get('/api/social/feed?limit=2')).json()) as FeedPage;
  assert.strictEqual(page1.clips.length, 2, 'limit=2 must return 2 clips');
  assert.ok(page1.nextCursor, 'more clips available -> nextCursor must be set');
  const page2 = (await (await get(`/api/social/feed?cursor=${page1.nextCursor}&limit=2`)).json()) as FeedPage;
  assert.ok(
    !page2.clips.some((c) => page1.clips.some((p) => p.id === c.id)),
    'page 2 must not repeat page 1 clips',
  );
  console.log('     ✅ feed cursor pagination passed');

  // 4. Like toggle
  console.log('  4. Testing POST /api/social/clips/:id/like...');
  const liked = (await (await post(`/api/social/clips/${published.clipId}/like`, {})).json()) as { liked: boolean; likeCount: number };
  assert.strictEqual(liked.liked, true, 'first like sets liked=true');
  assert.strictEqual(liked.likeCount, 1, 'like count increments to 1');
  const unliked = (await (await post(`/api/social/clips/${published.clipId}/like`, {})).json()) as { liked: boolean; likeCount: number };
  assert.strictEqual(unliked.liked, false, 'second tap un-likes');
  assert.strictEqual(unliked.likeCount, 0, 'like count decrements back to 0');
  console.log('     ✅ like toggle passed');

  await runPart2(published);
}

runTests().catch((err) => {
  console.error('❌ Test failed:', err);
  process.exit(1);
});


async function runPart2(published: PublishResult) {
  // 5. Like unknown clip -> 404
  console.log('  5. Testing like of an unknown clip...');
  const missingRes = await post('/api/social/clips/clip_does_not_exist/like', {});
  assert.strictEqual(missingRes.status, 404, 'unknown clip like must 404');
  console.log('     ✅ unknown-clip like 404 passed');

  // 6. Creator clips
  console.log('  6. Testing GET /api/creators/:id/clips...');
  const creatorRes = await get('/api/creators/creator_makhadzi/clips');
  assert.strictEqual(creatorRes.status, 200, 'creator clips must return 200');
  const creatorBody = (await creatorRes.json()) as { clips: PublishedClipDto[] };
  assert.ok(creatorBody.clips.length > 0, 'seeded creator must have clips');
  assert.ok(
    creatorBody.clips.every((c) => c.creatorId === 'creator_makhadzi'),
    'all returned clips must belong to the requested creator',
  );
  console.log('     ✅ GET /api/creators/:id/clips passed');

  // 7. Follow toggle
  console.log('  7. Testing POST /api/creators/:id/follow...');
  const followed = (await (await post('/api/creators/creator_makhadzi/follow', {})).json()) as { following: boolean; followerCount: number };
  assert.strictEqual(typeof followed.following, 'boolean', 'following flag');
  assert.ok(
    Number.isInteger(followed.followerCount) && followed.followerCount >= 0,
    'followerCount must be a non-negative integer',
  );
  const unfollowed = (await (await post('/api/creators/creator_makhadzi/follow', {})).json()) as { following: boolean; followerCount: number };
  assert.notStrictEqual(followed.following, unfollowed.following, 'second follow call must toggle the state');
  console.log('     ✅ follow toggle passed');

  // 8. Invalid publish body -> 400
  console.log('  8. Testing invalid publish request...');
  const badRes = await post('/api/social/publish', { title: 'missing trackId' });
  assert.strictEqual(badRes.status, 400, 'publish without trackId must 400');
  const badBody = (await badRes.json()) as { error: string };
  assert.strictEqual(badBody.error, 'INVALID_REQUEST', 'error code must be INVALID_REQUEST');
  console.log('     ✅ invalid publish 400 passed');

  assert.ok(published.clipId.length > 0, 'clip id retained across suites');
  console.log('\n🎉 ALL TESTS PASSED! Social Creator Network API verified.');
}
