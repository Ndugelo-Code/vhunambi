import { Hono } from 'hono';
import { z } from 'zod';
import { vhunambiDb } from '../db/vhunambi_db.js';
import {
  resolveEffectiveCreatorId,
  sovereignAuthMiddleware,
} from '../middleware/auth_middleware.js';
import type { VhunambiWorkerEnv } from '../types/cloudflare_worker_types.js';

export const notificationRoutes = new Hono<{ Bindings: VhunambiWorkerEnv }>();

notificationRoutes.use('*', sovereignAuthMiddleware);

const UpsertNotificationSchema = z.object({
  id: z.string().min(1),
  userId: z.string().optional(),
  title: z.string().min(1),
  message: z.string().default(''),
  body: z.string().optional(),
  category: z
    .enum(['social', 'system', 'creatorActivity', 'algorithmic'])
    .default('creatorActivity'),
  subtype: z.string().optional().nullable(),
  priority: z.enum(['low', 'normal', 'high', 'urgent']).default('normal'),
  isRead: z.boolean().default(false),
  targetRoute: z.string().optional().nullable(),
  targetEntityId: z.string().optional().nullable(),
  targetTrackId: z.string().optional().nullable(),
  ctaLabel: z.string().optional().nullable(),
  metadata: z.record(z.unknown()).default({}),
  createdAt: z.string().optional(),
});

// GET /api/notifications
notificationRoutes.get('/', (c) => {
  const queryUser = c.req.query('userId');
  const creatorId = resolveEffectiveCreatorId(c, queryUser, 'creator_cern');
  const notifications = vhunambiDb.listNotifications(creatorId);
  const quota = vhunambiDb.getCreatorQuota(creatorId);
  const unreadCount = notifications.filter((n) => !n.isRead).length;
  return c.json({
    success: true,
    creatorId,
    unreadCount,
    quota,
    notifications,
  });
});

// POST /api/notifications
notificationRoutes.post('/', async (c) => {
  const raw = await c.req.json().catch(() => ({}));
  const parsed = UpsertNotificationSchema.safeParse(raw);
  if (!parsed.success) {
    return c.json(
      { error: 'INVALID_NOTIFICATION', details: parsed.error.flatten() },
      400,
    );
  }
  const data = parsed.data;
  const creatorId = resolveEffectiveCreatorId(c, data.userId, 'creator_cern');
  const saved = vhunambiDb.upsertNotification({
    id: data.id,
    userId: creatorId,
    title: data.title,
    message: data.body ?? data.message,
    category: data.category,
    subtype: data.subtype ?? null,
    priority: data.priority,
    isRead: data.isRead,
    targetRoute: data.targetRoute ?? null,
    targetEntityId: data.targetEntityId ?? data.targetTrackId ?? null,
    ctaLabel: data.ctaLabel ?? null,
    metadata: data.metadata,
    createdAt: data.createdAt ?? new Date().toISOString(),
  });
  return c.json({ success: true, notification: saved }, 201);
});

// PATCH /api/notifications/:id/read
notificationRoutes.patch('/:id/read', (c) => {
  const id = c.req.param('id');
  const queryUser = c.req.query('userId');
  const creatorId = resolveEffectiveCreatorId(c, queryUser, 'creator_cern');
  const updated = vhunambiDb.markNotificationRead(creatorId, id);
  return c.json({ success: true, notification: updated });
});

// POST /api/notifications/mark-all-read
notificationRoutes.post('/mark-all-read', async (c) => {
  const body = await c.req.json().catch(() => ({} as Record<string, unknown>));
  const creatorId = resolveEffectiveCreatorId(
    c,
    typeof body?.userId === 'string' ? body.userId : c.req.query('userId'),
    'creator_cern',
  );
  const count = vhunambiDb.markAllNotificationsRead(creatorId);
  return c.json({ success: true, markedReadCount: count });
});

// DELETE /api/notifications/:id
notificationRoutes.delete('/:id', (c) => {
  const id = c.req.param('id');
  const queryUser = c.req.query('userId');
  const creatorId = resolveEffectiveCreatorId(c, queryUser, 'creator_cern');
  vhunambiDb.deleteNotification(creatorId, id);
  return c.json({ success: true, deletedId: id });
});
