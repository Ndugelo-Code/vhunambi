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
  remixedFromClipId?: string;
  remixAttribution?: string;
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

interface ReelCommentDto {
  id: string;
  clipId: string;
  userId: string;
  username: string;
  displayName: string;
  avatarUrl?: string;
  isCreator: boolean;
  text: string;
  likeCount: number;
  isLikedByMe: boolean;
  userReelLoves: number;
  giftEmoji?: string;
  giftName?: string;
  createdAt: string;
}

interface CreatorWalletDto {
  creatorId: string;
  balanceZar: number;
  totalCoinsReceived: number;
  topSupporters: Array<{
    username: string;
    displayName: string;
    totalCoins: number;
    totalZar: number;
    topGiftEmoji: string;
    rank: number;
  }>;
  recentTransactions: Array<{
    id: string;
    clipId: string;
    senderUsername: string;
    recipientCreatorId: string;
    gift: { id: string; name: string; emoji: string; coinPrice: number; zarPrice: number };
    message?: string;
    timestamp: string;
  }>;
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
  
  // Verify mandatory keys exist
  for (const k of CLIP_KEYS) {
    assert.ok(k in justPublished!, `clip must have property ${k}`);
  }
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

  await runPart3(published);
}

async function runPart3(published: PublishResult) {
  // 9. Community Comments: GET & POST
  console.log('  9. Testing GET & POST /api/social/clips/:id/comments (REQ-COM-01, REQ-COM-02)...');
  const initialCommentsRes = await get(`/api/social/clips/${published.clipId}/comments`);
  assert.strictEqual(initialCommentsRes.status, 200, 'get comments must return 200');
  const initialComments = (await initialCommentsRes.json()) as { comments: ReelCommentDto[] };
  assert.strictEqual(initialComments.comments.length, 0, 'new clip starts with 0 comments');

  const addCommentRes = await post(`/api/social/clips/${published.clipId}/comments`, {
    text: 'That bassline drop is heavenly! 🔥🇿🇦',
    username: 'kgothatso_test',
    displayName: 'Kgothatso Test',
    userReelLoves: 3,
  });
  assert.strictEqual(addCommentRes.status, 201, 'create comment must return 201');
  const createdComment = (await addCommentRes.json()) as ReelCommentDto;
  assert.ok(createdComment.id.startsWith('c_'), 'comment id format');
  assert.strictEqual(createdComment.text, 'That bassline drop is heavenly! 🔥🇿🇦');
  assert.strictEqual(createdComment.username, 'kgothatso_test');
  assert.strictEqual(createdComment.likeCount, 0);
  assert.strictEqual(createdComment.isLikedByMe, false);

  const updatedCommentsRes = await get(`/api/social/clips/${published.clipId}/comments`);
  const updatedComments = (await updatedCommentsRes.json()) as { comments: ReelCommentDto[] };
  assert.strictEqual(updatedComments.comments.length, 1, 'comment list must now contain 1 item');
  assert.strictEqual(updatedComments.comments[0].id, createdComment.id);
  console.log('     ✅ GET & POST comments passed');

  // 10. Comment Like Toggle
  console.log('  10. Testing POST /api/social/comments/:id/like...');
  const likedCommentRes = await post(`/api/social/comments/${createdComment.id}/like`, {});
  assert.strictEqual(likedCommentRes.status, 200, 'comment like must return 200');
  const likedComment = (await likedCommentRes.json()) as { liked: boolean; likeCount: number };
  assert.strictEqual(likedComment.liked, true, 'comment liked');
  assert.strictEqual(likedComment.likeCount, 1, 'like count increments to 1');

  const unlikedCommentRes = await post(`/api/social/comments/${createdComment.id}/like`, {});
  const unlikedComment = (await unlikedCommentRes.json()) as { liked: boolean; likeCount: number };
  assert.strictEqual(unlikedComment.liked, false, 'comment unliked');
  assert.strictEqual(unlikedComment.likeCount, 0, 'like count decrements to 0');
  console.log('     ✅ comment like toggle passed');

  // 11. Cultural Micro-Gift Tipping
  console.log('  11. Testing POST /api/social/clips/:id/tip (REQ-GFT-02, REQ-GFT-03)...');
  const tipRes = await post(`/api/social/clips/${published.clipId}/tip`, {
    giftId: 'log_drum_trophy',
    senderUsername: 'soweto_fan',
    message: 'Best log drum of 2026!',
  });
  assert.strictEqual(tipRes.status, 200, 'tipping must return 200');
  const tipResult = (await tipRes.json()) as {
    transaction: { id: string; gift: { name: string; emoji: string; zarPrice: number } };
    comment: ReelCommentDto;
    newBalanceZar: number;
  };
  assert.ok(tipResult.transaction.id.startsWith('tx_'), 'tx id prefix');
  assert.strictEqual(tipResult.transaction.gift.emoji, '🎹');
  assert.strictEqual(tipResult.transaction.gift.zarPrice, 15.0);
  assert.ok(tipResult.comment.text.includes('Best log drum of 2026!'), 'auto celebration comment text');
  assert.strictEqual(tipResult.comment.giftEmoji, '🎹');
  console.log('     ✅ cultural micro-gift tipping passed');

  // 12. Creator Wallet & Supporter Leaderboard
  console.log('  12. Testing GET /api/creators/:id/wallet (REQ-WAL-01)...');
  const walletRes = await get('/api/creators/creator_makhadzi/wallet');
  assert.strictEqual(walletRes.status, 200, 'wallet must return 200');
  const wallet = (await walletRes.json()) as CreatorWalletDto;
  assert.ok(wallet.balanceZar >= 1435.0, 'wallet balance credited with tip');
  assert.ok(wallet.totalCoinsReceived >= 4800, 'coins total updated');
  assert.ok(Array.isArray(wallet.topSupporters), 'top supporters is an array');
  assert.ok(wallet.topSupporters.some((s) => s.username === 'soweto_fan'), 'tipper listed in supporters');
  assert.ok(wallet.recentTransactions.length > 0, 'recent transactions listed');
  console.log('     ✅ creator wallet & leaderboard passed');

  // 13. Creator Payout Request
  console.log('  13. Testing POST /api/creators/:id/wallet/payout (REQ-WAL-02)...');
  const payoutRes = await post('/api/creators/creator_makhadzi/wallet/payout', {
    amountZar: 100.0,
    payoutMethod: 'eft',
    accountDetails: 'Standard Bank Acc #123456789',
  });
  assert.strictEqual(payoutRes.status, 200, 'payout must return 200');
  const payoutResult = (await payoutRes.json()) as { success: boolean; payoutId: string; remainingBalanceZar: number };
  assert.strictEqual(payoutResult.success, true);
  assert.ok(payoutResult.payoutId.startsWith('payout_'));

  // Negative test: payout under minimum R50
  const smallPayoutRes = await post('/api/creators/creator_makhadzi/wallet/payout', {
    amountZar: 20.0,
    payoutMethod: 'eft',
    accountDetails: 'Standard Bank Acc #123456789',
  });
  assert.strictEqual(smallPayoutRes.status, 400, 'payout under R50 must 400');
  console.log('     ✅ creator payout request passed');

  // 14. Phase D Viral Remix Genealogy & Lineage
  console.log('  14. Testing Viral Remix Lineage Propagation (Phase D)...');
  const remixRes = await post('/api/social/publish', {
    trackId: 'track_test_remix_1',
    title: 'Venda Sunrise (Private School Remix)',
    caption: 'Flipped the log drum with jazzy chords! 🎹✨',
    tags: ['Amapiano', 'Remix'],
    visibility: 'public',
    remixedFromClipId: published.clipId,
    remixAttribution: 'Remixed from @makhadzi',
    dna: {
      genre: 'Amapiano', bpm: 112,
      musical: { bpm: 112, key: 'Am' },
    },
  });
  assert.strictEqual(remixRes.status, 201, 'remix publish returns 201');
  const remixFeed = (await (await get('/api/social/feed')).json()) as FeedPage;
  const parentClip = remixFeed.clips.find((c) => c.id === published.clipId);
  assert.ok(parentClip, 'parent clip exists');
  assert.strictEqual(parentClip!.remixCount, 1, 'parent clip remixCount incremented to 1');
  console.log('     ✅ viral remix lineage propagation passed');

  console.log('\n🎉 ALL TESTS PASSED! Social Creator Network & Remix Genealogy API verified.');
}
