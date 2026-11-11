import { Hono } from 'hono';
import { vhunambiDb } from '../db/vhunambi_db.js';
import {
  assertTenantCreatorAccess,
  resolveEffectiveCreatorId,
  sovereignAuthMiddleware,
} from '../middleware/auth_middleware.js';

export const playlistRoutes = new Hono();

playlistRoutes.use('*', sovereignAuthMiddleware);

// GET /api/playlists — List playlists for creator (+ optional public playlists)
playlistRoutes.get('/', (c) => {
  const requestedId = c.req.query('creatorId');
  const forbidden = assertTenantCreatorAccess(c, requestedId);
  if (forbidden) return forbidden;

  const authUser = c.get('authUser');
  const creatorId = authUser ? authUser.creatorId : requestedId;
  const includePublic = c.req.query('includePublic') !== 'false';
  const items = vhunambiDb.getPlaylists(creatorId, includePublic);
  return c.json({
    success: true,
    items,
    playlists: items,
    count: items.length,
    serverSeq: vhunambiDb.getLatestSeq(),
  });
});

// GET /api/playlists/:id — Fetch a single playlist by id or shareCode
playlistRoutes.get('/:id', (c) => {
  const id = c.req.param('id');
  const playlist = vhunambiDb.getPlaylistById(id);
  if (!playlist) {
    return c.json({ success: false, error: 'Playlist not found', id }, 404);
  }
  const authUser = c.get('authUser');
  if (
    authUser &&
    !playlist.isPublic &&
    playlist.creatorId !== authUser.creatorId &&
    authUser.role !== 'admin'
  ) {
    return c.json(
      {
        error: `Forbidden: Private playlist '${id}' belongs to '${playlist.creatorId}'.`,
        code: 'TENANT_FORBIDDEN',
      },
      403,
    );
  }
  return c.json({ success: true, playlist });
});

// POST /api/playlists — Create or upsert a playlist
playlistRoutes.post('/', async (c) => {
  try {
    const body = await c.req.json();
    if (!body?.title || String(body.title).trim() === '') {
      return c.json({ success: false, error: 'Playlist title is required' }, 400);
    }

    const forbidden = assertTenantCreatorAccess(c, body.creatorId);
    if (forbidden) return forbidden;

    const authUser = c.get('authUser');
    if (body.id) {
      const ownerId = vhunambiDb.getPlaylistOwnerCreatorId(String(body.id));
      if (authUser && ownerId && ownerId !== authUser.creatorId && authUser.role !== 'admin') {
        return c.json(
          {
            error: `Forbidden: Playlist '${body.id}' belongs to '${ownerId}'.`,
            code: 'TENANT_FORBIDDEN',
          },
          403,
        );
      }
    }

    const effectiveCreatorId = authUser
      ? authUser.creatorId
      : body.creatorId ?? 'usr_me';
    const playlist = vhunambiDb.upsertPlaylist({
      ...body,
      creatorId: effectiveCreatorId,
    });
    return c.json({ success: true, playlist, serverSeq: vhunambiDb.getLatestSeq() }, 201);
  } catch (err: any) {
    return c.json({ success: false, error: err?.message || 'Invalid JSON body' }, 400);
  }
});

// PUT /api/playlists/:id — Update playlist metadata or track list
playlistRoutes.put('/:id', async (c) => {
  try {
    const id = c.req.param('id');
    const body = await c.req.json();
    const existing = vhunambiDb.getPlaylistById(id);
    if (!existing && (!body?.title || String(body.title).trim() === '')) {
      return c.json({ success: false, error: 'Playlist not found', id }, 404);
    }

    const forbidden = assertTenantCreatorAccess(c, body.creatorId);
    if (forbidden) return forbidden;

    const authUser = c.get('authUser');
    if (
      authUser &&
      existing &&
      existing.creatorId !== authUser.creatorId &&
      authUser.role !== 'admin'
    ) {
      return c.json(
        {
          error: `Forbidden: Playlist '${id}' belongs to '${existing.creatorId}'.`,
          code: 'TENANT_FORBIDDEN',
        },
        403,
      );
    }

    const effectiveCreatorId = authUser
      ? authUser.creatorId
      : resolveEffectiveCreatorId(c, body.creatorId, existing?.creatorId ?? 'usr_me');
    const playlist = vhunambiDb.upsertPlaylist({
      ...body,
      id,
      creatorId: effectiveCreatorId,
    });
    return c.json({ success: true, playlist, serverSeq: vhunambiDb.getLatestSeq() });
  } catch (err: any) {
    return c.json({ success: false, error: err?.message || 'Invalid JSON body' }, 400);
  }
});

// DELETE /api/playlists/:id — Delete playlist
playlistRoutes.delete('/:id', (c) => {
  const id = c.req.param('id');
  const requestedCreatorId = c.req.query('creatorId');
  const forbidden = assertTenantCreatorAccess(c, requestedCreatorId);
  if (forbidden) return forbidden;

  const authUser = c.get('authUser');
  if (authUser) {
    const ownerId = vhunambiDb.getPlaylistOwnerCreatorId(id);
    if (ownerId && ownerId !== authUser.creatorId && authUser.role !== 'admin') {
      return c.json(
        {
          error: `Forbidden: Playlist '${id}' belongs to '${ownerId}'.`,
          code: 'TENANT_FORBIDDEN',
        },
        403,
      );
    }
  }

  const effectiveCreatorId = authUser ? authUser.creatorId : requestedCreatorId;
  const deleted = vhunambiDb.deletePlaylist(id, effectiveCreatorId);
  if (!deleted) {
    return c.json({ success: false, error: 'Playlist not found', id }, 404);
  }
  return c.json({ success: true, id, serverSeq: vhunambiDb.getLatestSeq() });
});

// POST /api/playlists/:id/share — Generate public share link & code
playlistRoutes.post('/:id/share', (c) => {
  const id = c.req.param('id');
  const authUser = c.get('authUser');
  if (authUser) {
    const ownerId = vhunambiDb.getPlaylistOwnerCreatorId(id);
    if (ownerId && ownerId !== authUser.creatorId && authUser.role !== 'admin') {
      return c.json(
        {
          error: `Forbidden: Playlist '${id}' belongs to '${ownerId}'.`,
          code: 'TENANT_FORBIDDEN',
        },
        403,
      );
    }
  }

  const playlist = vhunambiDb.sharePlaylist(id);
  if (!playlist) {
    return c.json({ success: false, error: 'Playlist not found', id }, 404);
  }
  return c.json({
    success: true,
    playlist,
    shareCode: playlist.shareCode,
    shareUrl: playlist.shareUrl,
    serverSeq: vhunambiDb.getLatestSeq(),
  });
});

