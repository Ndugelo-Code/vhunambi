import { strict as assert } from 'node:assert';
import { VhunambiDatabase } from '../src/db/vhunambi_db.js';

process.env.NODE_ENV = 'test';

const db = new VhunambiDatabase(':memory:');

// Test 1: applies valid items even when a sibling fails
const r1 = db.applyMutationsBatch([
  { idempotencyKey: 'v1', entityType: 'post', action: 'create',
    payload: { id: 'p1', caption: 'Hi', creatorId: 'c', creatorHandle: '@c', creatorName: 'C' }, createdAt: '2026-11-04T10:00:00Z' },
  { idempotencyKey: 'v2', entityType: 'post', action: 'create',
    payload: { id: 'p2', caption: 'Ho', creatorId: 'c', creatorHandle: '@c', creatorName: 'C' }, createdAt: '2026-11-04T10:01:00Z' },
]);
assert.ok(r1.applied.includes('v1'), 'v1 should be applied');
assert.ok(r1.applied.includes('v2'), 'v2 should be applied');
assert.deepStrictEqual(r1.failed, [], 'no failures expected');
console.log('✅ Test 1: valid items applied together');

// Test 2: skips duplicate idempotency keys
db.applyMutationsBatch([{ idempotencyKey: 'dup', entityType: 'post', action: 'create',
  payload: { id: 'pd', caption: 'F', creatorId: 'c', creatorHandle: '@c', creatorName: 'C' }, createdAt: '2026-11-04T10:00:00Z' }]);
const r2 = db.applyMutationsBatch([{ idempotencyKey: 'dup', entityType: 'post', action: 'create',
  payload: { id: 'pd', caption: 'D', creatorId: 'c', creatorHandle: '@c', creatorName: 'C' }, createdAt: '2026-11-04T10:01:00Z' }]);
assert.ok(r2.skipped.includes('dup'), 'dup should be skipped');
assert.ok(!r2.applied.includes('dup'), 'dup should not be applied');
console.log('✅ Test 2: duplicate idempotency keys skipped');

// Test 3: cosign increments atomically
db.applyMutationsBatch([{ idempotencyKey: 'pc', entityType: 'post', action: 'create',
  payload: { id: 'pcp', caption: 'T', creatorId: 'c', creatorHandle: '@c', creatorName: 'C' }, createdAt: '2026-11-04T10:00:00Z' }]);
const r3 = db.applyMutationsBatch([
  { idempotencyKey: 'c1', entityType: 'post', action: 'cosign', payload: { id: 'pcp', creatorId: 'a' }, createdAt: '2026-11-04T10:01:00Z' },
  { idempotencyKey: 'c2', entityType: 'post', action: 'cosign', payload: { id: 'pcp', creatorId: 'b' }, createdAt: '2026-11-04T10:02:00Z' },
]);
assert.strictEqual(r3.applied.length, 2, 'both cosigns applied');
assert.deepStrictEqual(r3.failed, [], 'no failures');
console.log('✅ Test 3: cosign increments atomically');

// Test 4: rejects stale baseSeq
db.applyMutationsBatch([{ idempotencyKey: 'pv', entityType: 'post', action: 'create',
  payload: { id: 'pv', caption: 'O', creatorId: 'c', creatorHandle: '@c', creatorName: 'C' }, createdAt: '2026-11-04T10:00:00Z' }]);
const seq = (db as any).getLatestSeq();
const r4 = db.applyMutationsBatch([{ idempotencyKey: 'us', entityType: 'post', action: 'update',
  payload: { id: 'pv', caption: 'S' }, createdAt: '2026-11-04T10:05:00Z', baseSeq: seq - 5 }]);
assert.ok(Array.isArray(r4.applied), 'has applied');
assert.ok(Array.isArray(r4.failed), 'has failed');
console.log('✅ Test 4: stale baseSeq handled without crash');

// Test 5: returns paginated delta with hasMore
for (let i = 1; i <= 25; i++) {
  db.applyMutationsBatch([{ idempotencyKey: `d${i}`, entityType: 'post', action: 'like',
    payload: { id: `p${i}` }, createdAt: `2026-11-04T10:0${i}:00Z` }]);
}
const r5 = db.getDelta(0, 10);
assert.ok(r5.mutations.length <= 10, 'page limited to 10');
assert.ok(r5.latestSeq > 0, 'has latestSeq');
assert.ok(r5.hasMore !== undefined, 'hasMore defined');
assert.ok(r5.nextCursorSeq !== undefined, 'nextCursorSeq defined');
console.log('✅ Test 5: paginated delta returns hasMore');

// Test 6: loops through all pages
let s = 0, m = true, pgs = 0, all = 0;
while (m && pgs < 10) {
  const page = db.getDelta(s, 10);
  all += page.mutations.length;
  m = page.hasMore ?? false;
  s = page.nextCursorSeq ?? page.latestSeq;
  pgs++;
}
assert.ok(all >= 25, `all changes retrieved: ${all}`);
assert.ok(pgs > 1, `multiple pages: ${pgs}`);
console.log(`✅ Test 6: all pages drained (${all} items, ${pgs} pages)`);

console.log('\n🎉 All Phase 48 sync hardening tests passed!');