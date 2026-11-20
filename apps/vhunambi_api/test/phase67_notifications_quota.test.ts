import assert from 'node:assert/strict';
import { app } from '../src/server.js';
import {
  EdgeIsolateDatabaseEngine,
  getEdgeIsolateDatabaseEngine,
} from '../src/db/edge_persistence_bridge.js';
import { setSimulateEdgeIsolateMode } from '../src/db/vhunambi_db.js';

function resetState(): void {
  setSimulateEdgeIsolateMode(false);
  getEdgeIsolateDatabaseEngine().resetForTesting();
}

async function runPhase67Tests(): Promise<void> {
  console.log(
    '\nRunning Phase 67 Backend: Notifications & 10 Free Monthly Songs Quota Engine Tests...\n',
  );

  // 1. GET /api/wallet/allowance initializes 10 free monthly song credits
  try {
    const res = await app.fetch(
      new Request('http://localhost/api/wallet/allowance?userId=creator_p67_alice'),
    );
    assert.equal(res.status, 200);
    const body = (await res.json()) as Record<string, any>;
    assert.equal(body.success, true);
    assert.equal(body.planTier, 'free');
    assert.equal(body.freeMonthlySongsLimit, 10);
    assert.equal(body.freeMonthlySongsUsed, 0);
    assert.equal(body.freeMonthlySongsRemaining, 10);
    console.log('  [PASS] GET /api/wallet/allowance initialization');
  } finally {
    resetState();
  }

  // 2. CRUD /api/notifications supports upsert, read toggle, mark-all-read, and delete
  try {
    const uid = 'creator_p67_crud';
    const postRes = await app.fetch(
      new Request('http://localhost/api/notifications', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          id: 'notif_p67_1',
          userId: uid,
          title: 'Welcome to Vhunambi',
          message: 'Your sovereign studio is live.',
          category: 'system',
          subtype: 'welcome',
          targetRoute: '/studio',
          ctaLabel: 'Open Studio Cockpit',
        }),
      }),
    );
    assert.equal(postRes.status, 201);

    await app.fetch(
      new Request('http://localhost/api/notifications', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          id: 'notif_p67_2',
          userId: uid,
          title: 'Reel Loved',
          message: 'Loved Makhado groove',
          category: 'social',
          subtype: 'reel_love',
          targetRoute: '/reel/clip_seed_01',
        }),
      }),
    );

    const listRes = await app.fetch(
      new Request(`http://localhost/api/notifications?userId=${uid}`),
    );
    assert.equal(listRes.status, 200);
    const listBody = (await listRes.json()) as Record<string, any>;
    assert.equal(listBody.unreadCount, 2);
    assert.equal(listBody.notifications.length, 2);

    const readOne = await app.fetch(
      new Request(`http://localhost/api/notifications/notif_p67_1/read?userId=${uid}`, {
        method: 'PATCH',
      }),
    );
    assert.equal(readOne.status, 200);
    const readOneBody = (await readOne.json()) as Record<string, any>;
    assert.equal(readOneBody.notification.isRead, true);

    const markAll = await app.fetch(
      new Request('http://localhost/api/notifications/mark-all-read', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ userId: uid }),
      }),
    );
    assert.equal(markAll.status, 200);
    const markAllBody = (await markAll.json()) as Record<string, any>;
    assert.equal(markAllBody.markedReadCount, 1);

    const delRes = await app.fetch(
      new Request(`http://localhost/api/notifications/notif_p67_1?userId=${uid}`, {
        method: 'DELETE',
      }),
    );
    assert.equal(delRes.status, 200);

    const afterList = await app.fetch(
      new Request(`http://localhost/api/v1/notifications?userId=${uid}`),
    );
    const afterBody = (await afterList.json()) as Record<string, any>;
    assert.equal(afterBody.unreadCount, 0);
    assert.equal(afterBody.notifications.length, 1);
    console.log('  [PASS] CRUD /api/notifications');
  } finally {
    resetState();
  }

  // 3. POST /v1/generations decrements free monthly song allowance and emits alerts
  try {
    const uid = 'creator_p67_quota_test';
    for (let i = 1; i <= 7; i += 1) {
      const genRes = await app.fetch(
        new Request('http://localhost/v1/generations', {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({
            trackTitle: `Limpopo Anthem ${i}`,
            genre: 'Amapiano',
            language: 've',
            userId: uid,
          }),
        }),
      );
      assert.equal(genRes.status, 201);
      const genBody = (await genRes.json()) as Record<string, any>;
      assert.equal(genBody.quota.freeMonthlySongsUsed, i);
      assert.equal(genBody.quota.freeMonthlySongsRemaining, 10 - i);
    }

    const inboxRes = await app.fetch(
      new Request(`http://localhost/api/notifications?userId=${uid}`),
    );
    const inboxBody = (await inboxRes.json()) as Record<string, any>;
    assert.equal(inboxBody.quota.freeMonthlySongsRemaining, 3);
    const ids = (inboxBody.notifications as Array<Record<string, any>>).map(
      (n) => String(n.id),
    );
    assert.ok(ids.includes(`notif_quota_low_${uid}_3`));
    assert.ok(ids.some((id) => id.startsWith('notif_gen_')));
    console.log('  [PASS] POST /v1/generations quota & notification alerts');
  } finally {
    resetState();
  }

  // 4. EdgeIsolateDatabaseEngine parity without node:sqlite (workerd simulation)
  try {
    setSimulateEdgeIsolateMode(true);
    const uid = 'creator_p67_edge';

    const quotaRes = await app.fetch(
      new Request(`http://localhost/api/wallet/allowance?userId=${uid}`),
    );
    assert.equal(quotaRes.status, 200);
    const qBody = (await quotaRes.json()) as Record<string, any>;
    assert.equal(qBody.freeMonthlySongsLimit, 10);

    const postRes = await app.fetch(
      new Request('http://localhost/api/notifications', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          id: 'notif_edge_1',
          userId: uid,
          title: 'Edge Alert',
          message: 'Persisted inside EdgeIsolateDatabaseEngine',
          category: 'system',
          subtype: 'monthly_quota',
          targetRoute: '/wallet',
        }),
      }),
    );
    assert.equal(postRes.status, 201);

    const listRes = await app.fetch(
      new Request(`http://localhost/api/notifications?userId=${uid}`),
    );
    const listBody = (await listRes.json()) as Record<string, any>;
    assert.equal(listBody.notifications.length, 1);
    assert.equal(listBody.notifications[0].targetRoute, '/wallet');
    assert.ok(EdgeIsolateDatabaseEngine);
    console.log('  [PASS] EdgeIsolateDatabaseEngine workerd parity');
  } finally {
    resetState();
  }

  console.log('\nALL PHASE 67 BACKEND TESTS PASSED!\n');
}

runPhase67Tests().catch((err) => {
  console.error('Phase 67 backend test failed:', err);
  process.exit(1);
});
