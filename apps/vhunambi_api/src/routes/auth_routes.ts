import { Hono, type Context } from 'hono';
import { resolveRuntimeEnv } from '../config/env.js';
import { SupabaseCloudDriver, type GoTrueAuthResponse } from '../db/supabase_cloud_driver.js';
import {
  type AuthTokenBundle,
  canonicalizeCreatorId,
  isNodeSqliteAvailable,
  vhunambiDb,
} from '../db/vhunambi_db.js';
import {
  requireAuthenticatedUser,
  sovereignAuthMiddleware,
} from '../middleware/auth_middleware.js';
import { hashPassword, hashRefreshToken } from '../security/crypto_token.js';

export const authRoutes = new Hono();

const CANONICAL_SEED_EMAILS: Record<string, string> = {
  creator_cern: 'cern@vhunambi.co.za',
  creator_makhadzi: 'makhadzi@vhunambi.co.za',
  creator_sigwa: 'sigwa@vhunambi.co.za',
  creator_kabza: 'kabza@vhunambi.co.za',
  creator_focalistic: 'focalistic@vhunambi.co.za',
  creator_tyla: 'tyla@vhunambi.co.za',
  creator_black_coffee: 'blackcoffee@vhunambi.co.za',
};

function mapGoTrueBundle(
  res: GoTrueAuthResponse,
  fallbackHandle?: string,
  deviceLabel = 'vhunambi_client',
) {
  const userMeta = res.user?.user_metadata ?? {};
  const appMeta = res.user?.app_metadata ?? {};
  const rawCreatorId =
    (appMeta.creator_id as string | undefined) ??
    (userMeta.creator_id as string | undefined) ??
    fallbackHandle ??
    `creator_${(res.user?.email ?? res.user?.id ?? 'user').split('@')[0]}`;
  const creatorId = canonicalizeCreatorId(rawCreatorId);
  const rawHandle =
    (userMeta.handle as string | undefined) ??
    (appMeta.handle as string | undefined) ??
    `@${creatorId.replace(/^creator_/, '')}`;
  const handle = rawHandle.startsWith('@') ? rawHandle : `@${rawHandle}`;
  const displayName =
    (userMeta.display_name as string | undefined) ??
    handle.slice(1).toUpperCase();
  const nowIso = new Date().toISOString();
  const expiresAtIso =
    typeof res.expires_at === 'number'
      ? new Date(res.expires_at * 1000).toISOString()
      : new Date(Date.now() + (res.expires_in || 3600) * 1000).toISOString();
  const sessionId = `gotrue_${res.user.id}`;

  return {
    user: {
      userId: res.user.id,
      creatorId,
      handle,
      displayName,
      email: res.user.email ?? '',
      role: String(appMeta.vhunambi_role ?? 'creator'),
      avatarUrl: `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(creatorId)}`,
      isVerified: true,
      createdAt: nowIso,
    },
    session: {
      sessionId,
      userId: res.user.id,
      creatorId,
      familyId: sessionId,
      deviceLabel,
      expiresAt: expiresAtIso,
      revoked: false,
      revokeReason: null,
      createdAt: nowIso,
      rotatedAt: nowIso,
    },
    accessToken: res.access_token,
    refreshToken: res.refresh_token,
    expiresAt: expiresAtIso,
  };
}

async function resolveEmailForIdentifier(
  identifier: string,
  driver: SupabaseCloudDriver,
): Promise<string> {
  const trimmed = identifier.trim().toLowerCase();
  if (trimmed.includes('@') && trimmed.includes('.')) {
    return trimmed;
  }
  const canonical = canonicalizeCreatorId(trimmed);
  if (CANONICAL_SEED_EMAILS[canonical]) {
    return CANONICAL_SEED_EMAILS[canonical];
  }
  const localUser = vhunambiDb.getUserByCreatorId(canonical);
  if (localUser?.email) {
    return localUser.email.toLowerCase();
  }
  if (driver.isConfigured()) {
    const handleLookup = trimmed.startsWith('@') ? trimmed : `@${trimmed}`;
    try {
      const rows = await driver.selectRows<{ email?: string }>(
        'users',
        `select=email&or=(handle.ilike.${encodeURIComponent(handleLookup)},creator_id.eq.${encodeURIComponent(canonical)})&limit=1`,
      );
      if (rows[0]?.email) {
        return String(rows[0].email).toLowerCase();
      }
    } catch {
      // Fall back to deterministic handle domain
    }
  }
  const slug = trimmed.replace(/^@/, '').replace(/[^a-z0-9_.-]/g, '_');
  return `${slug}@vhunambi.co.za`;
}

function scheduleBackground(c: Context, task: Promise<unknown>): void {
  const safeTask = task.catch(() => { });
  try {
    c.executionCtx?.waitUntil(safeTask);
  } catch {
    // executionCtx absent outside Cloudflare Workers runtime
  }
}

async function mirrorBundleToSupabase(
  driver: SupabaseCloudDriver,
  bundle: AuthTokenBundle,
  rawPassword?: string,
  authUid?: string,
): Promise<void> {
  if (!driver.isConfigured()) return;
  const syncSnap = vhunambiDb.getAuthSyncSnapshot(
    bundle.user.creatorId,
    bundle.session.sessionId,
  );
  const passwordHash =
    syncSnap?.passwordHash ||
    (rawPassword ? hashPassword(rawPassword) : 'GOTRUE_MANAGED');
  const refreshTokenHash =
    syncSnap?.refreshTokenHash || hashRefreshToken(bundle.refreshToken);

  try {
    await driver.upsertRow(
      'creators',
      {
        id: bundle.user.creatorId,
        handle: bundle.user.handle,
        display_name: bundle.user.displayName,
        avatar_url: bundle.user.avatarUrl,
        archetype: 'Producer',
        tier: bundle.user.isVerified ? 'Sovereign' : 'Standard',
        is_verified: bundle.user.isVerified,
        updated_at: Date.now(),
      },
      'id',
    );
    await driver.upsertRow(
      'users',
      {
        user_id: bundle.user.userId,
        ...(authUid ? { auth_uid: authUid } : {}),
        creator_id: bundle.user.creatorId,
        handle: bundle.user.handle,
        email: bundle.user.email.toLowerCase(),
        password_hash: passwordHash,
        role: bundle.user.role,
        updated_at: new Date().toISOString(),
      },
      'creator_id',
    );
    await driver.upsertRow(
      'auth_sessions',
      {
        session_id: bundle.session.sessionId,
        user_id: bundle.user.userId,
        creator_id: bundle.user.creatorId,
        family_id: bundle.session.familyId,
        refresh_token_hash: refreshTokenHash,
        previous_token_hash: syncSnap?.previousTokenHash ?? null,
        device_label: bundle.session.deviceLabel,
        expires_at: bundle.session.expiresAt,
        revoked: bundle.session.revoked,
        revoke_reason: bundle.session.revokeReason,
        created_at: bundle.session.createdAt,
        rotated_at: bundle.session.rotatedAt,
      },
      'session_id',
    );
  } catch {
    // Non-blocking PostgREST sync
  }
}

async function hydrateUserFromSupabaseByIdentifier(
  driver: SupabaseCloudDriver,
  identifier: string,
): Promise<boolean> {
  if (!driver.isConfigured()) return false;
  const trimmed = identifier.trim().toLowerCase();
  const handleLookup = trimmed.startsWith('@') ? trimmed : `@${trimmed}`;
  const canonical = canonicalizeCreatorId(trimmed);
  try {
    const userRows = await driver.selectRows<Record<string, unknown>>(
      'users',
      `select=*&or=(email.ilike.${encodeURIComponent(trimmed)},handle.ilike.${encodeURIComponent(handleLookup)},creator_id.eq.${encodeURIComponent(canonical)})&limit=1`,
    );
    const u = userRows[0];
    if (!u) return false;
    const cid = canonicalizeCreatorId(String(u.creator_id ?? canonical));
    const creatorRows = await driver.selectRows<Record<string, unknown>>(
      'creators',
      `id=eq.${encodeURIComponent(cid)}&select=*&limit=1`,
    ).catch(() => []);
    const cr = creatorRows[0];
    vhunambiDb.hydrateExternalUser({
      userId: String(u.user_id ?? `usr_${cid}`),
      creatorId: cid,
      handle: String(u.handle ?? handleLookup),
      displayName: cr?.display_name ? String(cr.display_name) : undefined,
      email: String(u.email ?? `${cid}@vhunambi.co.za`),
      passwordHash: String(u.password_hash ?? 'GOTRUE_MANAGED'),
      role: String(u.role ?? 'creator'),
      avatarUrl: cr?.avatar_url ? String(cr.avatar_url) : undefined,
      isVerified: cr?.is_verified !== false,
      createdAt: u.created_at ? String(u.created_at) : undefined,
    });
    return true;
  } catch {
    return false;
  }
}

async function hydrateSessionFromSupabaseByRefreshToken(
  driver: SupabaseCloudDriver,
  refreshToken: string,
): Promise<boolean> {
  if (!driver.isConfigured()) return false;
  const tokenHash = hashRefreshToken(refreshToken);
  try {
    const rows = await driver.selectRows<Record<string, unknown>>(
      'auth_sessions',
      `select=*&or=(refresh_token_hash.eq.${encodeURIComponent(tokenHash)},previous_token_hash.eq.${encodeURIComponent(tokenHash)})&limit=1`,
    );
    const s = rows[0];
    if (!s) return false;
    const cid = canonicalizeCreatorId(String(s.creator_id ?? ''));
    if (cid && !vhunambiDb.getUserByCreatorId(cid)) {
      await hydrateUserFromSupabaseByIdentifier(driver, cid);
    }
    vhunambiDb.hydrateExternalSession({
      sessionId: String(s.session_id),
      userId: String(s.user_id),
      creatorId: cid,
      familyId: String(s.family_id),
      refreshTokenHash: String(s.refresh_token_hash),
      previousTokenHash: s.previous_token_hash
        ? String(s.previous_token_hash)
        : null,
      deviceLabel: String(s.device_label ?? 'vhunambi_client'),
      expiresAt: String(s.expires_at),
      revoked: Boolean(s.revoked),
      revokeReason: s.revoke_reason ? String(s.revoke_reason) : null,
      createdAt: s.created_at ? String(s.created_at) : undefined,
      rotatedAt: s.rotated_at ? String(s.rotated_at) : undefined,
    });
    return true;
  } catch {
    return false;
  }
}

authRoutes.post('/register', async (c) => {
  try {
    const body = (await c.req.json()) as {
      handle?: string;
      email?: string;
      password?: string;
      displayName?: string;
      creatorId?: string;
      deviceLabel?: string;
      initialCoins?: number;
    };

    if (!body.handle || !body.email || !body.password) {
      return c.json(
        {
          error: 'handle, email, and password are required.',
          code: 'VALIDATION_ERROR',
        },
        400,
      );
    }

    const runtimeEnv = resolveRuntimeEnv(c);
    const driver = new SupabaseCloudDriver(runtimeEnv);
    const cleanedHandle = body.handle.trim().toLowerCase().replace(/^@+/, '');
    const normalizedHandle = `@${cleanedHandle.replace(/[^a-z0-9_.-]/g, '')}`;
    const handleSlug = normalizedHandle.slice(1).replace(/[^a-z0-9_]/g, '_');
    const normalizedEmail = body.email.trim().toLowerCase();
    const resolvedCreatorId = canonicalizeCreatorId(
      body.creatorId?.trim() || `creator_${handleSlug}`,
    );
    const resolvedDisplayName =
      body.displayName?.trim() || normalizedHandle.slice(1).toUpperCase();

    if (driver.isConfigured() && !isNodeSqliteAvailable()) {
      try {
        const existingRows = await driver.selectRows<{ user_id?: string }>(
          'users',
          `select=user_id&or=(handle.ilike.${encodeURIComponent(normalizedHandle)},email.ilike.${encodeURIComponent(normalizedEmail)},creator_id.eq.${encodeURIComponent(resolvedCreatorId)})&limit=1`,
        );
        if (existingRows.length > 0) {
          return c.json(
            {
              error:
                'AUTH_IDENTITY_EXISTS: A sovereign user with that handle, email, or creator ID already exists.',
              code: 'AUTH_IDENTITY_EXISTS',
            },
            409,
          );
        }
      } catch {
        // Proceed with local edge uniqueness validation if PostgREST query is unreachable
      }
    }

    let goTrueUserId: string | undefined;
    if (driver.isConfigured()) {
      const adminUser = await driver.goTrueAdminCreateUser({
        email: normalizedEmail,
        password: body.password,
        userMetadata: {
          creator_id: resolvedCreatorId,
          handle: normalizedHandle,
          display_name: resolvedDisplayName,
        },
      });
      if (adminUser && typeof adminUser.id === 'string') {
        goTrueUserId = adminUser.id;
      } else {
        try {
          const goTrue = await driver.goTrueSignUp({
            email: normalizedEmail,
            password: body.password,
            creatorId: resolvedCreatorId,
            handle: normalizedHandle,
            displayName: resolvedDisplayName,
          });
          goTrueUserId = goTrue.user?.id;
        } catch {
          // Best-effort GoTrue shadow signup; Sovereign JWT + PostgREST persistence below is authoritative
        }
      }
    }

    const bundle = vhunambiDb.registerUser({
      handle: body.handle,
      email: normalizedEmail,
      password: body.password,
      displayName: body.displayName,
      creatorId: body.creatorId,
      deviceLabel: body.deviceLabel,
      initialCoins: body.initialCoins,
      jwtSecret: runtimeEnv.VHUNAMBI_JWT_SECRET,
    });

    if (driver.isConfigured()) {
      const syncPromise = mirrorBundleToSupabase(
        driver,
        bundle,
        body.password,
        goTrueUserId,
      );
      if (!isNodeSqliteAvailable()) {
        await syncPromise;
      } else {
        scheduleBackground(c, syncPromise);
      }
    }

    return c.json(bundle, 201);
  } catch (err) {
    const msg = err instanceof Error ? err.message : 'Registration failed';
    if (msg.startsWith('AUTH_IDENTITY_EXISTS')) {
      return c.json({ error: msg, code: 'AUTH_IDENTITY_EXISTS' }, 409);
    }
    return c.json({ error: msg, code: 'VALIDATION_ERROR' }, 400);
  }
});

authRoutes.post('/login', async (c) => {
  try {
    const body = (await c.req.json()) as {
      identifier?: string;
      handleOrEmail?: string;
      email?: string;
      handle?: string;
      password?: string;
      deviceLabel?: string;
    };

    const identifier =
      body.identifier ?? body.handleOrEmail ?? body.email ?? body.handle;
    if (!identifier || !body.password) {
      return c.json(
        {
          error: 'identifier (handle or email) and password are required.',
          code: 'VALIDATION_ERROR',
        },
        400,
      );
    }

    const runtimeEnv = resolveRuntimeEnv(c);
    const driver = new SupabaseCloudDriver(runtimeEnv);
    if (driver.isConfigured()) {
      const resolvedEmail = await resolveEmailForIdentifier(identifier, driver);
      try {
        const goTrue = await driver.goTrueSignInWithPassword(
          resolvedEmail,
          body.password,
        );
        if (goTrue.access_token && goTrue.user) {
          return c.json(
            mapGoTrueBundle(goTrue, identifier, body.deviceLabel),
            200,
          );
        }
      } catch {
        // Fall back to Sovereign scrypt verification + PostgREST hydration
      }
      if (!isNodeSqliteAvailable()) {
        await hydrateUserFromSupabaseByIdentifier(driver, identifier);
      }
    }

    const bundle = vhunambiDb.authenticateUser({
      identifier,
      password: body.password,
      deviceLabel: body.deviceLabel,
      jwtSecret: runtimeEnv.VHUNAMBI_JWT_SECRET,
    });

    if (driver.isConfigured()) {
      const syncPromise = mirrorBundleToSupabase(driver, bundle);
      if (!isNodeSqliteAvailable()) {
        await syncPromise;
      } else {
        scheduleBackground(c, syncPromise);
      }
    }

    return c.json(bundle, 200);
  } catch (err) {
    const msg = err instanceof Error ? err.message : 'Authentication failed';
    return c.json({ error: msg, code: 'INVALID_CREDENTIALS' }, 401);
  }
});

authRoutes.post('/refresh', async (c) => {
  try {
    const body = (await c.req.json()) as { refreshToken?: string };
    if (!body.refreshToken || body.refreshToken.trim().length === 0) {
      return c.json(
        { error: 'refreshToken is required.', code: 'VALIDATION_ERROR' },
        400,
      );
    }

    const runtimeEnv = resolveRuntimeEnv(c);
    const driver = new SupabaseCloudDriver(runtimeEnv);
    const isLocalSovereignRefresh = body.refreshToken.trim().startsWith('vrt_');

    if (driver.isConfigured() && !isLocalSovereignRefresh) {
      const goTrue = await driver.goTrueRefreshSession(body.refreshToken);
      return c.json(mapGoTrueBundle(goTrue), 200);
    }

    if (driver.isConfigured() && !isNodeSqliteAvailable()) {
      await hydrateSessionFromSupabaseByRefreshToken(driver, body.refreshToken);
    }

    const bundle = vhunambiDb.rotateRefreshToken(
      body.refreshToken,
      runtimeEnv.VHUNAMBI_JWT_SECRET,
    );
    if (driver.isConfigured()) {
      scheduleBackground(c, mirrorBundleToSupabase(driver, bundle));
    }
    return c.json(bundle, 200);
  } catch (err) {
    const msg = err instanceof Error ? err.message : 'Token refresh failed';
    const code = msg.startsWith('AUTH_TOKEN_REUSE_DETECTED')
      ? 'AUTH_TOKEN_REUSE_DETECTED'
      : 'AUTH_REFRESH_INVALID';
    return c.json({ error: msg, code }, 401);
  }
});

authRoutes.post('/logout', sovereignAuthMiddleware, async (c) => {
  const authUser = c.get('authUser');
  let sessionId = authUser?.sessionId;

  if (!sessionId) {
    try {
      const body = (await c.req.json()) as { sessionId?: string };
      sessionId = body.sessionId;
    } catch {
      // ignore empty body
    }
  }

  if (!sessionId) {
    return c.json(
      {
        error: 'Active session or sessionId is required.',
        code: 'AUTH_REQUIRED',
      },
      401,
    );
  }

  if (authUser?.isGoTrueToken) {
    return c.json({
      loggedOut: true,
      sessionId,
      revoked: true,
    });
  }

  const result = vhunambiDb.revokeSession(sessionId, 'USER_LOGOUT');
  const runtimeEnv = resolveRuntimeEnv(c);
  const driver = new SupabaseCloudDriver(runtimeEnv);
  if (driver.isConfigured()) {
    scheduleBackground(
      c,
      driver.patchRows(
        'auth_sessions',
        `session_id=eq.${encodeURIComponent(sessionId)}`,
        {
          revoked: true,
          revoke_reason: 'USER_LOGOUT',
          rotated_at: new Date().toISOString(),
        },
      ),
    );
  }
  return c.json({
    loggedOut: true,
    sessionId: result.sessionId,
    revoked: result.revoked,
  });
});

authRoutes.get('/me', requireAuthenticatedUser, async (c) => {
  const authUser = c.get('authUser')!;
  let user = vhunambiDb.getUserByCreatorId(authUser.creatorId);
  if (!user && !authUser.isGoTrueToken && !isNodeSqliteAvailable()) {
    const driver = new SupabaseCloudDriver(resolveRuntimeEnv(c));
    if (driver.isConfigured()) {
      await hydrateUserFromSupabaseByIdentifier(driver, authUser.creatorId);
      user = vhunambiDb.getUserByCreatorId(authUser.creatorId);
    }
  }
  if (!user && !authUser.isGoTrueToken) {
    return c.json({ error: 'User not found', code: 'USER_NOT_FOUND' }, 404);
  }
  const resolvedUser = user ?? {
    userId: authUser.userId,
    creatorId: authUser.creatorId,
    handle: authUser.handle,
    displayName: authUser.handle.replace(/^@/, '').toUpperCase(),
    email: '',
    role: authUser.role,
    avatarUrl: `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(authUser.creatorId)}`,
    isVerified: true,
    createdAt: new Date().toISOString(),
  };
  const wallet = vhunambiDb.getWallet(resolvedUser.creatorId);
  return c.json({
    user: resolvedUser,
    sessionId: authUser.sessionId,
    wallet: {
      balanceCoins: wallet.balanceCoins,
      balanceZar: wallet.balanceZar,
    },
  });
});

authRoutes.get('/sessions', requireAuthenticatedUser, (c) => {
  const authUser = c.get('authUser')!;
  const sessions = vhunambiDb.listSessionsForCreator(authUser.creatorId);
  return c.json({
    creatorId: authUser.creatorId,
    activeSessionId: authUser.sessionId,
    count: sessions.length,
    sessions,
  });
});

