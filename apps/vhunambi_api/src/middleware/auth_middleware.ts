import type { Context, Next } from 'hono';
import { resolveRuntimeEnv } from '../config/env.js';
import {
  canonicalizeCreatorId,
  vhunambiDb,
} from '../db/vhunambi_db.js';
import { verifyAccessJwtAsync } from '../security/crypto_token.js';

export interface AuthenticatedPrincipal {
  userId: string;
  creatorId: string;
  handle: string;
  role: string;
  sessionId: string;
  isGoTrueToken?: boolean;
}

export type AuthenticatedCreatorContext = AuthenticatedPrincipal;

declare module 'hono' {
  interface ContextVariableMap {
    authUser?: AuthenticatedPrincipal;
  }
}

/**
 * Returns true if strict authentication enforcement is enabled via request header
 * or request-scoped / process environment configuration.
 */
export function isStrictAuthEnforced(c: Context): boolean {
  const enforceHeader = c.req.header('x-vhunambi-enforce-auth')?.toLowerCase();
  if (enforceHeader === 'true' || enforceHeader === '1') {
    return true;
  }
  const runtimeEnv = resolveRuntimeEnv(c);
  return runtimeEnv.VHUNAMBI_AUTH_MODE.toLowerCase() === 'strict';
}

/**
 * Dual-Gate Authentication & Tenant Middleware (`REQ-P61-AUTH-03` / `REQ-P62-AUTH-01`):
 * - Supports both Sovereign Phase 61 HS256 JWTs and Supabase GoTrue JWTs via `resolveRuntimeEnv(c)`.
 * - Skips local SQLite `auth_sessions` checks for GoTrue tokens or pure V8 isolates without SQLite.
 * - Preserves permissive mode when Authorization is absent unless strict mode is active.
 */
export async function sovereignAuthMiddleware(c: Context, next: Next) {
  const authHeader =
    c.req.header('Authorization') ?? c.req.header('authorization');
  const runtimeEnv = resolveRuntimeEnv(c);

  if (authHeader && authHeader.trim().length > 0) {
    const trimmed = authHeader.trim();
    if (!trimmed.toLowerCase().startsWith('bearer ')) {
      return c.json(
        {
          error: 'Malformed Authorization header. Expected Bearer <token>.',
          code: 'AUTH_TOKEN_MALFORMED',
        },
        401,
      );
    }

    const rawToken = trimmed.slice(7).trim();
    if (!rawToken) {
      return c.json(
        {
          error: 'Missing Bearer token value.',
          code: 'AUTH_TOKEN_MISSING',
        },
        401,
      );
    }

    const verification = await verifyAccessJwtAsync(rawToken, {
      secret: runtimeEnv.VHUNAMBI_JWT_SECRET,
      supabaseUrl: runtimeEnv.SUPABASE_URL,
    });
    if (!verification.valid) {
      return c.json(
        {
          error:
            verification.reason === 'EXPIRED'
              ? 'Access token has expired.'
              : 'Invalid access token signature or payload.',
          code:
            verification.reason === 'EXPIRED'
              ? 'AUTH_TOKEN_EXPIRED'
              : verification.reason === 'MALFORMED'
                ? 'AUTH_TOKEN_MALFORMED'
                : 'AUTH_TOKEN_INVALID',
        },
        401,
      );
    }

    const { claims } = verification;
    if (
      !claims.isGoTrueToken &&
      !vhunambiDb.isSessionActive(claims.sid)
    ) {
      return c.json(
        {
          error: 'Authentication session has been revoked or expired.',
          code: 'AUTH_SESSION_REVOKED',
        },
        401,
      );
    }

    c.set('authUser', {
      userId: claims.sub,
      creatorId: canonicalizeCreatorId(claims.cid),
      handle: claims.hdl,
      role: claims.role,
      sessionId: claims.sid,
      isGoTrueToken: claims.isGoTrueToken,
    });
    return next();
  }

  if (isStrictAuthEnforced(c)) {
    return c.json(
      {
        error: 'Authentication is required to access this resource.',
        code: 'AUTH_REQUIRED',
      },
      401,
    );
  }

  return next();
}

/**
 * Strictly requires an authenticated principal (used on /api/auth/me, /api/auth/sessions).
 */
export async function requireAuthenticatedUser(c: Context, next: Next) {
  const authHeader =
    c.req.header('Authorization') ?? c.req.header('authorization');
  if (!authHeader || !authHeader.trim().toLowerCase().startsWith('bearer ')) {
    return c.json(
      {
        error: 'Bearer authentication token is required.',
        code: 'AUTH_REQUIRED',
      },
      401,
    );
  }
  return sovereignAuthMiddleware(c, next);
}

/**
 * Verifies that if the request is authenticated, the targetCreatorId belongs to the authenticated user.
 * Compares canonicalized IDs so `'creator_blackcoffee'` and `'creator_black_coffee'` are treated as identical.
 */
export function assertTenantCreatorAccess(
  c: Context,
  targetCreatorId: string | undefined | null,
): Response | null {
  const authUser = c.get('authUser');
  if (!authUser) {
    return null;
  }
  if (authUser.role === 'admin') {
    return null;
  }
  const normalizedTarget = targetCreatorId?.trim();
  if (!normalizedTarget) {
    return null;
  }
  const canonicalTarget = canonicalizeCreatorId(normalizedTarget);
  const canonicalActor = canonicalizeCreatorId(authUser.creatorId);
  if (canonicalTarget !== canonicalActor) {
    return c.json(
      {
        error: `Forbidden: Authenticated principal '${authUser.creatorId}' cannot access or mutate resources owned by '${normalizedTarget}'.`,
        code: 'TENANT_FORBIDDEN',
        authenticatedCreatorId: authUser.creatorId,
        requestedCreatorId: normalizedTarget,
      },
      403,
    );
  }
  return null;
}

/**
 * Resolves the effective creatorId for a route handler:
 * - Explicitly requested creatorId if non-empty, else authUser.creatorId, else x-vhunambi-creator-id, else fallbackDefault.
 */
export function resolveEffectiveCreatorId(
  c: Context,
  requestedCreatorId: string | undefined | null,
  fallbackDefault = 'creator_cern',
): string {
  const trimmed = requestedCreatorId?.trim();
  if (trimmed && trimmed.length > 0) {
    return trimmed;
  }
  const authUser = c.get('authUser');
  if (authUser) {
    return authUser.creatorId;
  }
  const headerCreatorId = c.req.header('x-vhunambi-creator-id')?.trim();
  if (headerCreatorId && headerCreatorId.length > 0) {
    return headerCreatorId;
  }
  return fallbackDefault;
}

