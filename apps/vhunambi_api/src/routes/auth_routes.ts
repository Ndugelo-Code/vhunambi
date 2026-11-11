import { Hono } from 'hono';
import { resolveRuntimeEnv } from '../config/env.js';
import { SupabaseCloudDriver, type GoTrueAuthResponse } from '../db/supabase_cloud_driver.js';
import {
  canonicalizeCreatorId,
  isNodeSqliteAvailable,
  vhunambiDb,
} from '../db/vhunambi_db.js';
import {
  requireAuthenticatedUser,
  sovereignAuthMiddleware,
} from '../middleware/auth_middleware.js';

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
    if (driver.isConfigured() && !isNodeSqliteAvailable()) {
      const normalizedHandle = body.handle.startsWith('@')
        ? body.handle.toLowerCase()
        : `@${body.handle.toLowerCase()}`;
      const creatorId = canonicalizeCreatorId(
        body.creatorId || `creator_${normalizedHandle.slice(1)}`,
      );
      const goTrue = await driver.goTrueSignUp({
        email: body.email.trim().toLowerCase(),
        password: body.password,
        creatorId,
        handle: normalizedHandle,
        displayName: body.displayName?.trim() || normalizedHandle.slice(1),
      });
      const resolvedGoTrueUser =
        goTrue.user ??
        (goTrue as unknown as { id?: string } | undefined);
      const goTrueUserId = resolvedGoTrueUser?.id;
      const resolvedDisplayName =
        body.displayName?.trim() || normalizedHandle.slice(1);
      try {
        await driver.upsertRow(
          'creators',
          {
            id: creatorId,
            handle: normalizedHandle,
            display_name: resolvedDisplayName,
            avatar_url: `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(creatorId)}`,
            archetype: 'Producer',
            tier: 'Sovereign',
          },
          'id',
        );
        if (goTrueUserId) {
          await driver.upsertRow(
            'users',
            {
              user_id: goTrueUserId,
              auth_uid: goTrueUserId,
              creator_id: creatorId,
              handle: normalizedHandle,
              email: body.email.trim().toLowerCase(),
              password_hash: 'GOTRUE_MANAGED',
              role: 'creator',
            },
            'user_id',
          );
        }
      } catch {
        // Non-fatal if Supabase profile row already exists or email confirmation pending
      }
      if (!goTrue.access_token || !goTrue.user) {
        return c.json(
          {
            pendingEmailConfirmation: true,
            email: body.email.trim().toLowerCase(),
            creatorId,
            code: 'EMAIL_CONFIRMATION_REQUIRED',
            message:
              'Account created! Check your email inbox to confirm your address before signing in.',
          },
          202,
        );
      }
      return c.json(
        mapGoTrueBundle(goTrue, creatorId, body.deviceLabel),
        201,
      );
    }

    const bundle = vhunambiDb.registerUser({
      handle: body.handle,
      email: body.email,
      password: body.password,
      displayName: body.displayName,
      creatorId: body.creatorId,
      deviceLabel: body.deviceLabel,
      initialCoins: body.initialCoins,
    });

    if (driver.isConfigured()) {
      try {
        await driver.goTrueSignUp({
          email: bundle.user.email,
          password: body.password,
          creatorId: bundle.user.creatorId,
          handle: bundle.user.handle,
          displayName: bundle.user.displayName,
        });
      } catch {
        // Non-fatal if GoTrue already provisioned this test account
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
        return c.json(
          mapGoTrueBundle(goTrue, identifier, body.deviceLabel),
          200,
        );
      } catch (err) {
        if (!isNodeSqliteAvailable()) {
          throw err;
        }
      }
    }

    const bundle = vhunambiDb.authenticateUser({
      identifier,
      password: body.password,
      deviceLabel: body.deviceLabel,
    });

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

    if (driver.isConfigured() && (!isLocalSovereignRefresh || !isNodeSqliteAvailable())) {
      const goTrue = await driver.goTrueRefreshSession(body.refreshToken);
      return c.json(mapGoTrueBundle(goTrue), 200);
    }

    const bundle = vhunambiDb.rotateRefreshToken(body.refreshToken);
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
  return c.json({
    loggedOut: true,
    sessionId: result.sessionId,
    revoked: result.revoked,
  });
});

authRoutes.get('/me', requireAuthenticatedUser, (c) => {
  const authUser = c.get('authUser')!;
  const user = vhunambiDb.getUserByCreatorId(authUser.creatorId);
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

