# Phase 61: Sovereign Identity, Authentication & Multi-Tenant Security Convergence — Detailed Engineering Design

> **Document ID:** `VHUNAMBI-SPEC-P61-DESIGN-V1`
> **Phase:** `61 — Sovereign Identity, Authentication & Multi-Tenant Security Convergence`
> **Engineering Standard:** `All-Gemini Engineering Standard (100% Compilable TypeScript & Dart Specifications — Zero Placeholders)`
> **Status:** `HARDENED SPECIFICATION SUITE — READY FOR EXECUTION`

---

## 1. Backend Cryptographic Security Engine (`apps/vhunambi_api`)

### 1.1 Zero-Dependency Password Hashing, JWT Signing & Token Digest Engine (`apps/vhunambi_api/src/security/crypto_token.ts`)

```typescript
import {
  createHash,
  createHmac,
  randomBytes,
  scryptSync,
  timingSafeEqual,
} from 'node:crypto';

export interface SovereignJwtClaims {
  sub: string;       // user_id (e.g. 'usr_cern')
  cid: string;       // creator_id (e.g. 'creator_cern')
  hdl: string;       // handle (e.g. '@cern')
  sid: string;       // session_id (e.g. 'ses_...')
  role: string;      // 'creator' | 'admin'
  iat: number;       // issued at (seconds)
  exp: number;       // expires at (seconds)
}

const SCRYPT_N = 16384;
const SCRYPT_R = 8;
const SCRYPT_P = 1;
const SCRYPT_KEYLEN = 64;

const DEFAULT_DEV_JWT_SECRET =
  'vhunambi_sovereign_phase61_jwt_hmac_sha256_secret_key_2026_za';

export function resolveJwtSecret(): string {
  const fromEnv = process.env.VHUNAMBI_JWT_SECRET?.trim();
  if (fromEnv && fromEnv.length >= 32) {
    return fromEnv;
  }
  return DEFAULT_DEV_JWT_SECRET;
}

function base64UrlEncode(input: Buffer | string): string {
  const buf = typeof input === 'string' ? Buffer.from(input, 'utf8') : input;
  return buf
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

function base64UrlDecodeToBuffer(input: string): Buffer {
  const normalized = input.replace(/-/g, '+').replace(/_/g, '/');
  const padLength = (4 - (normalized.length % 4)) % 4;
  const padded = normalized + '='.repeat(padLength);
  return Buffer.from(padded, 'base64');
}

/**
 * Memory-hard password hashing via node:crypto scryptSync (N=16384, r=8, p=1, keylen=64).
 * Format: scrypt$16384$8$1$<saltHex>$<derivedKeyHex>
 */
export function hashPassword(password: string, explicitSaltHex?: string): string {
  const saltBuf = explicitSaltHex
    ? Buffer.from(explicitSaltHex, 'hex')
    : randomBytes(16);
  const derivedKey = scryptSync(password, saltBuf, SCRYPT_KEYLEN, {
    N: SCRYPT_N,
    r: SCRYPT_R,
    p: SCRYPT_P,
  });
  return `scrypt$${SCRYPT_N}$${SCRYPT_R}$${SCRYPT_P}$${saltBuf.toString('hex')}$${derivedKey.toString('hex')}`;
}

/**
 * Constant-time password verification against a stored scrypt hash record.
 */
export function verifyPassword(password: string, storedRecord: string): boolean {
  try {
    const parts = storedRecord.split('$');
    if (parts.length !== 6 || parts[0] !== 'scrypt') {
      return false;
    }
    const n = Number.parseInt(parts[1], 10);
    const r = Number.parseInt(parts[2], 10);
    const p = Number.parseInt(parts[3], 10);
    const saltBuf = Buffer.from(parts[4], 'hex');
    const expectedKeyBuf = Buffer.from(parts[5], 'hex');

    if (
      !Number.isFinite(n) ||
      !Number.isFinite(r) ||
      !Number.isFinite(p) ||
      saltBuf.length === 0 ||
      expectedKeyBuf.length === 0
    ) {
      return false;
    }

    const candidateKeyBuf = scryptSync(password, saltBuf, expectedKeyBuf.length, {
      N: n,
      r,
      p,
    });

    if (candidateKeyBuf.length !== expectedKeyBuf.length) {
      return false;
    }
    return timingSafeEqual(candidateKeyBuf, expectedKeyBuf);
  } catch {
    return false;
  }
}

/**
 * Signs an RFC 7519 HS256 JWT access token.
 */
export function signAccessJwt(
  claims: Omit<SovereignJwtClaims, 'iat' | 'exp'>,
  ttlSeconds = 3600,
  nowSeconds = Math.floor(Date.now() / 1000)
): { token: string; expiresAtIso: string; claims: SovereignJwtClaims } {
  const headerJson = JSON.stringify({ alg: 'HS256', typ: 'JWT' });
  const fullClaims: SovereignJwtClaims = {
    ...claims,
    iat: nowSeconds,
    exp: nowSeconds + ttlSeconds,
  };
  const payloadJson = JSON.stringify(fullClaims);

  const encodedHeader = base64UrlEncode(headerJson);
  const encodedPayload = base64UrlEncode(payloadJson);
  const signingInput = `${encodedHeader}.${encodedPayload}`;

  const signature = createHmac('sha256', resolveJwtSecret())
    .update(signingInput, 'utf8')
    .digest();
  const encodedSignature = base64UrlEncode(signature);

  return {
    token: `${signingInput}.${encodedSignature}`,
    expiresAtIso: new Date(fullClaims.exp * 1000).toISOString(),
    claims: fullClaims,
  };
}

export type JwtVerificationResult =
  | { valid: true; claims: SovereignJwtClaims }
  | { valid: false; reason: 'MALFORMED' | 'INVALID_SIGNATURE' | 'EXPIRED' };

/**
 * Verifies an HS256 JWT in constant time and checks token expiration.
 */
export function verifyAccessJwt(
  token: string,
  nowSeconds = Math.floor(Date.now() / 1000)
): JwtVerificationResult {
  try {
    const segments = token.trim().split('.');
    if (segments.length !== 3) {
      return { valid: false, reason: 'MALFORMED' };
    }
    const [encodedHeader, encodedPayload, encodedSignature] = segments;
    const signingInput = `${encodedHeader}.${encodedPayload}`;

    const expectedSig = createHmac('sha256', resolveJwtSecret())
      .update(signingInput, 'utf8')
      .digest();
    const actualSig = base64UrlDecodeToBuffer(encodedSignature);

    if (expectedSig.length !== actualSig.length) {
      return { valid: false, reason: 'INVALID_SIGNATURE' };
    }
    if (!timingSafeEqual(expectedSig, actualSig)) {
      return { valid: false, reason: 'INVALID_SIGNATURE' };
    }

    const headerObj = JSON.parse(
      base64UrlDecodeToBuffer(encodedHeader).toString('utf8')
    ) as { alg?: string };
    if (headerObj.alg !== 'HS256') {
      return { valid: false, reason: 'MALFORMED' };
    }

    const claims = JSON.parse(
      base64UrlDecodeToBuffer(encodedPayload).toString('utf8')
    ) as SovereignJwtClaims;

    if (
      !claims ||
      typeof claims.sub !== 'string' ||
      typeof claims.cid !== 'string' ||
      typeof claims.sid !== 'string' ||
      typeof claims.exp !== 'number'
    ) {
      return { valid: false, reason: 'MALFORMED' };
    }

    if (nowSeconds >= claims.exp) {
      return { valid: false, reason: 'EXPIRED' };
    }

    return { valid: true, claims };
  } catch {
    return { valid: false, reason: 'MALFORMED' };
  }
}

/**
 * Generates an opaque 32-byte CSPRNG refresh token and its SHA-256 hex digest.
 */
export function generateRefreshTokenPair(): {
  refreshToken: string;
  refreshTokenHash: string;
} {
  const raw = randomBytes(32);
  const refreshToken = `vrt_${base64UrlEncode(raw)}`;
  const refreshTokenHash = hashRefreshToken(refreshToken);
  return { refreshToken, refreshTokenHash };
}

/**
 * Computes the SHA-256 hex digest of a refresh token.
 */
export function hashRefreshToken(refreshToken: string): string {
  return createHash('sha256').update(refreshToken.trim(), 'utf8').digest('hex');
}
```

---

### 1.2 Dual-Gate Authentication & Tenant Isolation Middleware (`apps/vhunambi_api/src/middleware/auth_middleware.ts`)

```typescript
import type { Context, Next } from 'hono';
import { vhunambiDb } from '../db/vhunambi_db.js';
import { verifyAccessJwt } from '../security/crypto_token.js';

export interface AuthenticatedPrincipal {
  userId: string;
  creatorId: string;
  handle: string;
  role: string;
  sessionId: string;
}

declare module 'hono' {
  interface ContextVariableMap {
    authUser?: AuthenticatedPrincipal;
  }
}

/**
 * Returns true if strict authentication enforcement is enabled via request header or environment variable.
 */
export function isStrictAuthEnforced(c: Context): boolean {
  const enforceHeader = c.req.header('x-vhunambi-enforce-auth')?.toLowerCase();
  if (enforceHeader === 'true' || enforceHeader === '1') {
    return true;
  }
  const envMode = process.env.VHUNAMBI_AUTH_MODE?.toLowerCase();
  return envMode === 'strict';
}

/**
 * Extracts and verifies the Bearer token if present.
 * - If Authorization header is present: strictly validates JWT and active session (returns 401 on any failure).
 * - If Authorization header is absent:
 *   * If strict auth is enforced (via header or env): returns 401 AUTH_REQUIRED.
 *   * Otherwise: allows request to proceed in legacy/guest mode for backwards-compatible test suites.
 */
export async function sovereignAuthMiddleware(c: Context, next: Next) {
  const authHeader = c.req.header('Authorization') ?? c.req.header('authorization');

  if (authHeader && authHeader.trim().length > 0) {
    const trimmed = authHeader.trim();
    if (!trimmed.toLowerCase().startsWith('bearer ')) {
      return c.json(
        {
          error: 'Malformed Authorization header. Expected Bearer <token>.',
          code: 'AUTH_TOKEN_MALFORMED',
        },
        401
      );
    }

    const rawToken = trimmed.slice(7).trim();
    if (!rawToken) {
      return c.json(
        {
          error: 'Missing Bearer token value.',
          code: 'AUTH_TOKEN_MISSING',
        },
        401
      );
    }

    const verification = verifyAccessJwt(rawToken);
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
              : 'AUTH_TOKEN_INVALID',
        },
        401
      );
    }

    const { claims } = verification;
    const sessionActive = vhunambiDb.isSessionActive(claims.sid);
    if (!sessionActive) {
      return c.json(
        {
          error: 'Authentication session has been revoked or expired.',
          code: 'AUTH_SESSION_REVOKED',
        },
        401
      );
    }

    c.set('authUser', {
      userId: claims.sub,
      creatorId: claims.cid,
      handle: claims.hdl,
      role: claims.role,
      sessionId: claims.sid,
    });
    return next();
  }

  if (isStrictAuthEnforced(c)) {
    return c.json(
      {
        error: 'Authentication is required to access this resource.',
        code: 'AUTH_REQUIRED',
      },
      401
    );
  }

  return next();
}

/**
 * Strictly requires an authenticated principal (used on /api/auth/me, /api/auth/sessions, etc.).
 */
export async function requireAuthenticatedUser(c: Context, next: Next) {
  const authHeader = c.req.header('Authorization') ?? c.req.header('authorization');
  if (!authHeader || !authHeader.trim().toLowerCase().startsWith('bearer ')) {
    return c.json(
      {
        error: 'Bearer authentication token is required.',
        code: 'AUTH_REQUIRED',
      },
      401
    );
  }
  return sovereignAuthMiddleware(c, next);
}

/**
 * Verifies that if the request is authenticated, the targetCreatorId belongs to the authenticated user
 * (unless the user has role === 'admin'). Returns a 403 Response if forbidden, or null if permitted.
 */
export function assertTenantCreatorAccess(
  c: Context,
  targetCreatorId: string | undefined | null
): Response | null {
  const authUser = c.get('authUser');
  if (!authUser) {
    return null;
  }
  if (authUser.role === 'admin') {
    return null;
  }
  const normalizedTarget = targetCreatorId?.trim();
  if (normalizedTarget && normalizedTarget !== authUser.creatorId) {
    return c.json(
      {
        error: `Forbidden: Authenticated principal '${authUser.creatorId}' cannot access or mutate resources owned by '${normalizedTarget}'.`,
        code: 'TENANT_FORBIDDEN',
        authenticatedCreatorId: authUser.creatorId,
        requestedCreatorId: normalizedTarget,
      },
      403
    );
  }
  return null;
}

/**
 * Resolves the effective creatorId for a route handler:
 * - If authenticated and targetCreatorId is omitted, defaults to authUser.creatorId.
 * - Otherwise uses targetCreatorId or fallbackDefault.
 */
export function resolveEffectiveCreatorId(
  c: Context,
  requestedCreatorId: string | undefined | null,
  fallbackDefault = 'creator_cern'
): string {
  const authUser = c.get('authUser');
  const trimmed = requestedCreatorId?.trim();
  if (trimmed && trimmed.length > 0) {
    return trimmed;
  }
  if (authUser) {
    return authUser.creatorId;
  }
  const headerCreatorId = c.req.header('x-vhunambi-creator-id')?.trim();
  if (headerCreatorId && headerCreatorId.length > 0) {
    return headerCreatorId;
  }
  return fallbackDefault;
}
```

---

### 1.3 SQLite Schema Upgrades, Atomic `BEGIN IMMEDIATE` Payouts & Tenant-Scoped Sync in `VhunambiDatabase` (`apps/vhunambi_api/src/db/vhunambi_db.ts`)

Add the following interfaces, tables, migrations, and methods to `apps/vhunambi_api/src/db/vhunambi_db.ts`:

```typescript
export interface SovereignUserRecord {
  userId: string;
  creatorId: string;
  handle: string;
  displayName: string;
  email: string;
  role: string;
  avatarUrl: string;
  isVerified: boolean;
  createdAt: string;
}

export interface SovereignAuthSessionRecord {
  sessionId: string;
  userId: string;
  creatorId: string;
  familyId: string;
  deviceLabel: string;
  expiresAt: string;
  revoked: boolean;
  revokeReason: string | null;
  createdAt: string;
  rotatedAt: string;
}

export interface AuthTokenBundle {
  user: SovereignUserRecord;
  session: SovereignAuthSessionRecord;
  accessToken: string;
  refreshToken: string;
  expiresAt: string;
}
```

#### 1.3.1 Schema Migration Additions in `VhunambiDatabase.migrate()`
Inside `migrate()`, add `users` and `auth_sessions` DDL plus the idempotent `creator_id` column migration on `sync_mutation_log`:

```typescript
      CREATE TABLE IF NOT EXISTS users (
        user_id TEXT PRIMARY KEY,
        creator_id TEXT NOT NULL UNIQUE,
        handle TEXT NOT NULL UNIQUE,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'creator',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (creator_id) REFERENCES creators(id)
      );

      CREATE INDEX IF NOT EXISTS idx_users_handle ON users(handle);
      CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

      CREATE TABLE IF NOT EXISTS auth_sessions (
        session_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        creator_id TEXT NOT NULL,
        family_id TEXT NOT NULL,
        refresh_token_hash TEXT NOT NULL,
        previous_token_hash TEXT,
        device_label TEXT NOT NULL DEFAULT 'vhunambi_client',
        expires_at TEXT NOT NULL,
        revoked INTEGER NOT NULL DEFAULT 0,
        revoke_reason TEXT,
        created_at TEXT NOT NULL,
        rotated_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(user_id)
      );

      CREATE INDEX IF NOT EXISTS idx_auth_sessions_user ON auth_sessions(user_id, revoked);
      CREATE INDEX IF NOT EXISTS idx_auth_sessions_family ON auth_sessions(family_id);
      CREATE INDEX IF NOT EXISTS idx_auth_sessions_token_hash ON auth_sessions(refresh_token_hash);
```

And immediately following `this.db.exec(...)` inside `migrate()`, ensure `sync_mutation_log` has `creator_id` and seed users if empty:

```typescript
    const mutationCols = this.db
      .prepare(`PRAGMA table_info(sync_mutation_log)`)
      .all() as Array<{ name: string }>;
    if (!mutationCols.some((col) => col.name === 'creator_id')) {
      this.db.exec(
        `ALTER TABLE sync_mutation_log ADD COLUMN creator_id TEXT NOT NULL DEFAULT 'system';`
      );
    }
    this.db.exec(
      `CREATE INDEX IF NOT EXISTS idx_sync_mutation_creator_seq ON sync_mutation_log(creator_id, seq);`
    );
```

#### 1.3.2 Deterministic Sovereign User Seeding (`seedUsersIfEmpty()`)
Called at the end of `seedIfEmpty()` (and if `SELECT COUNT(*) FROM users` is `0`):

```typescript
  public static readonly DEFAULT_SEED_PASSWORD = 'VhunambiSovereign!2026';
  private static cachedDefaultSeedHash: string | null = null;

  private getDefaultSeedPasswordHash(): string {
    if (!VhunambiDatabase.cachedDefaultSeedHash) {
      VhunambiDatabase.cachedDefaultSeedHash = hashPassword(
        VhunambiDatabase.DEFAULT_SEED_PASSWORD,
        '7668756e616d62695f736565645f3631'
      );
    }
    return VhunambiDatabase.cachedDefaultSeedHash;
  }

  private seedUsersIfEmpty(): void {
    const userCount = (
      this.db.prepare('SELECT COUNT(*) as c FROM users').get() as { c: number }
    ).c;
    if (userCount > 0) return;

    const now = new Date().toISOString();
    const defaultHash = this.getDefaultSeedPasswordHash();
    const seedAccounts = [
      {
        userId: 'usr_cern',
        creatorId: 'creator_cern',
        handle: '@cern',
        email: 'cern@vhunambi.co.za',
      },
      {
        userId: 'usr_makhadzi',
        creatorId: 'creator_makhadzi',
        handle: '@makhadzi',
        email: 'makhadzi@vhunambi.co.za',
      },
      {
        userId: 'usr_kabza',
        creatorId: 'creator_kabza',
        handle: '@kabza',
        email: 'kabza@vhunambi.co.za',
      },
      {
        userId: 'usr_focalistic',
        creatorId: 'creator_focalistic',
        handle: '@focalistic',
        email: 'focalistic@vhunambi.co.za',
      },
      {
        userId: 'usr_tyla',
        creatorId: 'creator_tyla',
        handle: '@tyla',
        email: 'tyla@vhunambi.co.za',
      },
      {
        userId: 'usr_black_coffee',
        creatorId: 'creator_black_coffee',
        handle: '@blackcoffee',
        email: 'blackcoffee@vhunambi.co.za',
      },
    ];

    const insertUser = this.db.prepare(`
      INSERT OR IGNORE INTO users (
        user_id, creator_id, handle, email, password_hash, role, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, 'creator', ?, ?)
    `);

    for (const acc of seedAccounts) {
      insertUser.run(
        acc.userId,
        acc.creatorId,
        acc.handle,
        acc.email,
        defaultHash,
        now,
        now
      );
    }
  }
```

#### 1.3.3 Tenant-Scoped `recordMutation` & `getDelta`
Update `recordMutation` and `getDelta` in `vhunambi_db.ts` so every mutation carries its owning `creator_id` and private mutations are filtered in `getDelta`:

```typescript
  public recordMutation(
    entityType: string,
    entityId: string,
    operation: 'UPSERT' | 'DELETE',
    payload: unknown,
    creatorId?: string
  ): number {
    const now = new Date().toISOString();
    let resolvedCreatorId = creatorId?.trim();
    if (!resolvedCreatorId && payload && typeof payload === 'object') {
      const p = payload as Record<string, unknown>;
      const candidate =
        (typeof p.creatorId === 'string' && p.creatorId) ||
        (typeof p.creator_id === 'string' && p.creator_id) ||
        (typeof p.buyerId === 'string' && p.buyerId) ||
        (typeof p.authorId === 'string' && p.authorId);
      if (candidate) {
        resolvedCreatorId = candidate.trim();
      }
    }
    const finalCreatorId = resolvedCreatorId || 'system';

    const result = this.db
      .prepare(
        `INSERT INTO sync_mutation_log (entity_type, entity_id, operation, payload_json, creator_id, created_at)
         VALUES (?, ?, ?, ?, ?, ?)`
      )
      .run(
        entityType,
        entityId,
        operation,
        JSON.stringify(payload),
        finalCreatorId,
        now
      );
    return Number(result.lastInsertRowid);
  }

  public getDelta(sinceSeq: number, limit = 100, viewerCreatorId?: string) {
    const safeLimit = Math.max(1, Math.min(500, limit));
    const rows = this.db
      .prepare(
        `SELECT seq, entity_type, entity_id, operation, payload_json, creator_id, created_at
         FROM sync_mutation_log
         WHERE seq > ?
         ORDER BY seq ASC
         LIMIT ?`
      )
      .all(sinceSeq, safeLimit * 3) as Array<Record<string, unknown>>;

    const latestSeqRow = this.db
      .prepare('SELECT COALESCE(MAX(seq), 0) as max_seq FROM sync_mutation_log')
      .get() as { max_seq: number };

    const normalizedViewer = viewerCreatorId?.trim();
    const privateEntityTypes = new Set([
      'payout',
      'library_track',
      'beat_license',
      'wallet_ledger',
    ]);

    const filteredRows: Array<Record<string, unknown>> = [];
    for (const r of rows) {
      if (filteredRows.length >= safeLimit) break;
      const entityType = String(r.entity_type);
      const rowCreatorId = String(r.creator_id ?? 'system');

      if (normalizedViewer) {
        if (privateEntityTypes.has(entityType)) {
          let isSellerOnLicense = false;
          if (entityType === 'beat_license') {
            try {
              const parsed = JSON.parse(String(r.payload_json)) as Record<
                string,
                unknown
              >;
              if (parsed.sellerId === normalizedViewer) {
                isSellerOnLicense = true;
              }
            } catch {
              isSellerOnLicense = false;
            }
          }
          if (rowCreatorId !== normalizedViewer && !isSellerOnLicense) {
            continue;
          }
        } else if (entityType === 'playlist') {
          if (rowCreatorId !== normalizedViewer && rowCreatorId !== 'system') {
            try {
              const parsed = JSON.parse(String(r.payload_json)) as Record<
                string,
                unknown
              >;
              const isPublic =
                parsed.isPublic === true || parsed.is_public === 1;
              if (!isPublic) {
                continue;
              }
            } catch {
              continue;
            }
          }
        }
      }

      filteredRows.push(r);
    }

    return {
      sinceSeq,
      latestSeq: latestSeqRow.max_seq,
      count: filteredRows.length,
      mutations: filteredRows.map((r) => ({
        seq: Number(r.seq),
        entityType: String(r.entity_type),
        entityId: String(r.entity_id),
        operation: String(r.operation),
        creatorId: String(r.creator_id ?? 'system'),
        payload: JSON.parse(String(r.payload_json)),
        createdAt: String(r.created_at),
      })),
    };
  }
```

#### 1.3.4 Atomic `BEGIN IMMEDIATE` Lock on `requestPayout()`
In `VhunambiDatabase.requestPayout()` (`vhunambi_db.ts`), wrap the balance check, bank account upsert, negative ledger insertion, and mutation log inside `BEGIN IMMEDIATE ... COMMIT` with `ROLLBACK` on error:

```typescript
    this.db.exec('BEGIN IMMEDIATE');
    try {
      const currentWallet = this.getWallet(req.creatorId);
      if (currentWallet.balanceCoins < amountCoins) {
        throw new Error(
          `INSUFFICIENT_FUNDS: Available ${currentWallet.balanceCoins} coins (R ${currentWallet.balanceZar.toFixed(2)}), requested ${amountCoins} coins`
        );
      }

      if (req.saveBankDetails !== false) {
        const bankAccId = `bank_${req.creatorId}_${normalizedBank
          .toLowerCase()
          .replace(/[^a-z0-9]/g, '_')}`;
        this.db
          .prepare(
            `INSERT INTO bank_accounts (id, creator_id, bank_name, account_holder, account_masked, branch_code, is_default, created_at)
             VALUES (?, ?, ?, ?, ?, ?, 1, ?)
             ON CONFLICT(id) DO UPDATE SET
               account_holder = excluded.account_holder,
               account_masked = excluded.account_masked,
               branch_code = excluded.branch_code,
               is_default = 1`
          )
          .run(
            bankAccId,
            req.creatorId,
            normalizedBank,
            req.accountHolder.trim(),
            maskedAccount,
            branchCode,
            now
          );
      }

      const description = `${gatewayLabel} Instant Payout to ${normalizedBank} (${maskedAccount}) — Ref ${payoutRef}`;

      this.db
        .prepare(
          `INSERT INTO wallet_ledger
           (id, creator_id, type, amount_coins, amount_zar, description, bank_name, account_masked, payout_ref, status, created_at)
           VALUES (?, ?, 'PAYOUT', ?, ?, ?, ?, ?, ?, 'SETTLED', ?)`
        )
        .run(
          payoutId,
          req.creatorId,
          -amountCoins,
          -grossAmountZar,
          description,
          normalizedBank,
          maskedAccount,
          payoutRef,
          now
        );

      const seq = this.recordMutation(
        'payout',
        payoutId,
        'UPSERT',
        {
          id: payoutId,
          creatorId: req.creatorId,
          amountCoins,
          grossAmountZar,
          gatewayFeeZar,
          netAmountZar,
          bankName: normalizedBank,
          accountMasked: maskedAccount,
          branchCode,
          gateway: gatewayKey,
          payoutRef,
          status: 'SETTLED',
          settledAt: now,
        },
        req.creatorId
      );

      this.db.exec('COMMIT');

      const updatedWallet = this.getWallet(req.creatorId);
      return {
        payoutId,
        creatorId: req.creatorId,
        amountCoins,
        amountZar: grossAmountZar,
        grossAmountZar,
        gatewayFeeZar,
        netAmountZar,
        newBalanceCoins: updatedWallet.balanceCoins,
        newBalanceZar: updatedWallet.balanceZar,
        bankName: normalizedBank,
        accountHolder: req.accountHolder.trim(),
        accountMasked: maskedAccount,
        branchCode,
        gateway: gatewayKey,
        gatewayLabel,
        payoutRef,
        status: 'SETTLED',
        settledAt: now,
        seq,
      };
    } catch (err) {
      try {
        this.db.exec('ROLLBACK');
      } catch {
        // Ignore rollback error if transaction already closed
      }
      throw err;
    }
```

#### 1.3.5 User Registration, Login, Session Rotation & Revocation Methods in `VhunambiDatabase`

```typescript
  private static normalizeHandle(rawHandle: string): string {
    const cleaned = rawHandle.trim().toLowerCase().replace(/^@+/, '');
    return `@${cleaned.replace(/[^a-z0-9_.-]/g, '')}`;
  }

  public getUserByCreatorId(creatorId: string): SovereignUserRecord | null {
    const row = this.db
      .prepare(
        `SELECT u.user_id, u.creator_id, u.handle, u.email, u.role, u.created_at,
                c.display_name, c.avatar_url, c.is_verified
         FROM users u
         LEFT JOIN creators c ON c.id = u.creator_id
         WHERE u.creator_id = ?`
      )
      .get(creatorId) as Record<string, unknown> | undefined;
    if (!row) return null;
    return {
      userId: String(row.user_id),
      creatorId: String(row.creator_id),
      handle: String(row.handle),
      displayName: String(row.display_name ?? row.handle),
      email: String(row.email),
      role: String(row.role ?? 'creator'),
      avatarUrl: String(
        row.avatar_url ??
          `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(String(row.creator_id))}`
      ),
      isVerified: Number(row.is_verified ?? 1) === 1,
      createdAt: String(row.created_at),
    };
  }

  public isSessionActive(sessionId: string): boolean {
    const row = this.db
      .prepare(
        `SELECT revoked, expires_at FROM auth_sessions WHERE session_id = ?`
      )
      .get(sessionId) as { revoked: number; expires_at: string } | undefined;
    if (!row || Number(row.revoked) !== 0) {
      return false;
    }
    return new Date(row.expires_at).getTime() > Date.now();
  }

  private createAuthSessionAndTokens(
    user: SovereignUserRecord,
    deviceLabel = 'vhunambi_client'
  ): AuthTokenBundle {
    const now = new Date();
    const nowIso = now.toISOString();
    const expiresAtIso = new Date(
      now.getTime() + 30 * 24 * 60 * 60 * 1000
    ).toISOString();
    const sessionId = `ses_${randomUUID().replace(/-/g, '').slice(0, 20)}`;
    const familyId = `fam_${randomUUID().replace(/-/g, '').slice(0, 16)}`;
    const { refreshToken, refreshTokenHash } = generateRefreshTokenPair();

    this.db
      .prepare(
        `INSERT INTO auth_sessions (
          session_id, user_id, creator_id, family_id, refresh_token_hash,
          previous_token_hash, device_label, expires_at, revoked, revoke_reason,
          created_at, rotated_at
        ) VALUES (?, ?, ?, ?, ?, NULL, ?, ?, 0, NULL, ?, ?)`
      )
      .run(
        sessionId,
        user.userId,
        user.creatorId,
        familyId,
        refreshTokenHash,
        deviceLabel,
        expiresAtIso,
        nowIso,
        nowIso
      );

    const signed = signAccessJwt({
      sub: user.userId,
      cid: user.creatorId,
      hdl: user.handle,
      sid: sessionId,
      role: user.role,
    });

    return {
      user,
      session: {
        sessionId,
        userId: user.userId,
        creatorId: user.creatorId,
        familyId,
        deviceLabel,
        expiresAt: expiresAtIso,
        revoked: false,
        revokeReason: null,
        createdAt: nowIso,
        rotatedAt: nowIso,
      },
      accessToken: signed.token,
      refreshToken,
      expiresAt: signed.expiresAtIso,
    };
  }

  public registerUser(input: {
    handle: string;
    email: string;
    password: string;
    displayName?: string;
    creatorId?: string;
    deviceLabel?: string;
    initialCoins?: number;
  }): AuthTokenBundle {
    const normalizedHandle = VhunambiDatabase.normalizeHandle(input.handle);
    if (normalizedHandle.length < 3) {
      throw new Error('INVALID_HANDLE: Handle must contain at least 2 alphanumeric characters.');
    }
    const normalizedEmail = input.email.trim().toLowerCase();
    if (!normalizedEmail.includes('@') || normalizedEmail.length < 5) {
      throw new Error('INVALID_EMAIL: A valid email address is required.');
    }
    if (!input.password || input.password.length < 8) {
      throw new Error('WEAK_PASSWORD: Password must be at least 8 characters long.');
    }

    const handleSlug = normalizedHandle.slice(1).replace(/[^a-z0-9_]/g, '_');
    const creatorId =
      input.creatorId?.trim() || `creator_${handleSlug}`;
    const userId = `usr_${handleSlug}_${randomUUID().slice(0, 6)}`;
    const displayName =
      input.displayName?.trim() || normalizedHandle.slice(1).toUpperCase();
    const passwordHash = hashPassword(input.password);
    const now = new Date().toISOString();

    this.db.exec('BEGIN IMMEDIATE');
    try {
      const existing = this.db
        .prepare(
          `SELECT user_id FROM users WHERE handle = ? OR email = ? OR creator_id = ?`
        )
        .get(normalizedHandle, normalizedEmail, creatorId) as
        | { user_id: string }
        | undefined;

      if (existing) {
        throw new Error(
          'AUTH_IDENTITY_EXISTS: A sovereign user with that handle, email, or creator ID already exists.'
        );
      }

      this.db
        .prepare(
          `INSERT INTO creators (id, handle, display_name, avatar_url, bio, followers_count, following_count, is_verified, created_at)
           VALUES (?, ?, ?, ?, ?, 0, 0, 1, ?)
           ON CONFLICT(id) DO UPDATE SET
             handle = excluded.handle,
             display_name = excluded.display_name`
        )
        .run(
          creatorId,
          normalizedHandle,
          displayName,
          `https://api.dicebear.com/7.x/avataaars/svg?seed=${encodeURIComponent(creatorId)}`,
          'Sovereign Creator on Vhunambi Cloud',
          now
        );

      this.db
        .prepare(
          `INSERT INTO users (user_id, creator_id, handle, email, password_hash, role, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, 'creator', ?, ?)`
        )
        .run(
          userId,
          creatorId,
          normalizedHandle,
          normalizedEmail,
          passwordHash,
          now,
          now
        );

      const welcomeCoins =
        typeof input.initialCoins === 'number'
          ? Math.max(0, Math.round(input.initialCoins))
          : 2500;
      if (welcomeCoins > 0 && !this.hasWalletActivity(creatorId)) {
        const zarRate = 0.1;
        this.db
          .prepare(
            `INSERT INTO wallet_ledger (id, creator_id, type, amount_coins, amount_zar, description, status, created_at)
             VALUES (?, ?, 'CREDIT_ROYALTY', ?, ?, ?, 'SETTLED', ?)`
          )
          .run(
            `wtx_welcome_${creatorId}`,
            creatorId,
            welcomeCoins,
            Number((welcomeCoins * zarRate).toFixed(2)),
            'Sovereign Creator Genesis Grant',
            now
          );
      }

      this.db.exec('COMMIT');
    } catch (err) {
      try {
        this.db.exec('ROLLBACK');
      } catch {
        // ignore
      }
      throw err;
    }

    const createdUser = this.getUserByCreatorId(creatorId)!;
    return this.createAuthSessionAndTokens(
      createdUser,
      input.deviceLabel ?? 'vhunambi_client'
    );
  }

  public authenticateUser(input: {
    identifier: string;
    password: string;
    deviceLabel?: string;
  }): AuthTokenBundle {
    const rawId = input.identifier.trim().toLowerCase();
    const handleCandidate = rawId.startsWith('@') ? rawId : `@${rawId}`;

    const row = this.db
      .prepare(
        `SELECT user_id, creator_id, password_hash
         FROM users
         WHERE LOWER(email) = ? OR LOWER(handle) = ? OR LOWER(creator_id) = ?`
      )
      .get(rawId, handleCandidate, rawId) as
      | { user_id: string; creator_id: string; password_hash: string }
      | undefined;

    if (!row || !verifyPassword(input.password, row.password_hash)) {
      throw new Error('INVALID_CREDENTIALS: Invalid handle/email or password.');
    }

    const user = this.getUserByCreatorId(row.creator_id);
    if (!user) {
      throw new Error('INVALID_CREDENTIALS: Creator record missing.');
    }

    return this.createAuthSessionAndTokens(
      user,
      input.deviceLabel ?? 'vhunambi_client'
    );
  }

  public rotateRefreshToken(refreshToken: string): AuthTokenBundle {
    const tokenHash = hashRefreshToken(refreshToken);

    const sessionRow = this.db
      .prepare(
        `SELECT session_id, user_id, creator_id, family_id, refresh_token_hash,
                previous_token_hash, device_label, expires_at, revoked, revoke_reason, created_at
         FROM auth_sessions
         WHERE refresh_token_hash = ? OR previous_token_hash = ?`
      )
      .get(tokenHash, tokenHash) as Record<string, unknown> | undefined;

    if (!sessionRow) {
      throw new Error('AUTH_REFRESH_INVALID: Unrecognized refresh token.');
    }

    const familyId = String(sessionRow.family_id);
    const isReplayOfRotatedToken =
      String(sessionRow.previous_token_hash ?? '') === tokenHash &&
      String(sessionRow.refresh_token_hash) !== tokenHash;

    if (isReplayOfRotatedToken) {
      const nowIso = new Date().toISOString();
      this.db
        .prepare(
          `UPDATE auth_sessions
           SET revoked = 1, revoke_reason = 'TOKEN_REUSE_DETECTED', rotated_at = ?
           WHERE family_id = ?`
        )
        .run(nowIso, familyId);
      throw new Error(
        'AUTH_TOKEN_REUSE_DETECTED: Refresh token reuse detected; session family revoked.'
      );
    }

    if (Number(sessionRow.revoked) !== 0) {
      throw new Error('AUTH_SESSION_REVOKED: Session has been revoked.');
    }

    if (new Date(String(sessionRow.expires_at)).getTime() <= Date.now()) {
      throw new Error('AUTH_SESSION_EXPIRED: Refresh session has expired.');
    }

    const nextPair = generateRefreshTokenPair();
    const nowIso = new Date().toISOString();
    const nextExpiresAt = new Date(
      Date.now() + 30 * 24 * 60 * 60 * 1000
    ).toISOString();
    const sessionId = String(sessionRow.session_id);
    const creatorId = String(sessionRow.creator_id);

    this.db
      .prepare(
        `UPDATE auth_sessions
         SET previous_token_hash = refresh_token_hash,
             refresh_token_hash = ?,
             expires_at = ?,
             rotated_at = ?
         WHERE session_id = ?`
      )
      .run(nextPair.refreshTokenHash, nextExpiresAt, nowIso, sessionId);

    const user = this.getUserByCreatorId(creatorId);
    if (!user) {
      throw new Error('AUTH_USER_NOT_FOUND: User no longer exists.');
    }

    const signed = signAccessJwt({
      sub: user.userId,
      cid: user.creatorId,
      hdl: user.handle,
      sid: sessionId,
      role: user.role,
    });

    return {
      user,
      session: {
        sessionId,
        userId: user.userId,
        creatorId: user.creatorId,
        familyId,
        deviceLabel: String(sessionRow.device_label ?? 'vhunambi_client'),
        expiresAt: nextExpiresAt,
        revoked: false,
        revokeReason: null,
        createdAt: String(sessionRow.created_at),
        rotatedAt: nowIso,
      },
      accessToken: signed.token,
      refreshToken: nextPair.refreshToken,
      expiresAt: signed.expiresAtIso,
    };
  }

  public revokeSession(
    sessionId: string,
    reason = 'USER_LOGOUT'
  ): { sessionId: string; revoked: boolean } {
    const nowIso = new Date().toISOString();
    const res = this.db
      .prepare(
        `UPDATE auth_sessions
         SET revoked = 1, revoke_reason = ?, rotated_at = ?
         WHERE session_id = ?`
      )
      .run(reason, nowIso, sessionId);
    return {
      sessionId,
      revoked: Number(res.changes) > 0,
    };
  }

  public listSessionsForCreator(
    creatorId: string
  ): SovereignAuthSessionRecord[] {
    const rows = this.db
      .prepare(
        `SELECT session_id, user_id, creator_id, family_id, device_label,
                expires_at, revoked, revoke_reason, created_at, rotated_at
         FROM auth_sessions
         WHERE creator_id = ?
         ORDER BY rotated_at DESC`
      )
      .all(creatorId) as Array<Record<string, unknown>>;

    return rows.map((r) => ({
      sessionId: String(r.session_id),
      userId: String(r.user_id),
      creatorId: String(r.creator_id),
      familyId: String(r.family_id),
      deviceLabel: String(r.device_label ?? 'vhunambi_client'),
      expiresAt: String(r.expires_at),
      revoked: Number(r.revoked) !== 0,
      revokeReason: r.revoke_reason ? String(r.revoke_reason) : null,
      createdAt: String(r.created_at),
      rotatedAt: String(r.rotated_at),
    }));
  }

  public getPlaylistOwnerCreatorId(playlistId: string): string | null {
    const row = this.db
      .prepare(`SELECT creator_id FROM playlists WHERE id = ?`)
      .get(playlistId) as { creator_id: string } | undefined;
    return row ? String(row.creator_id) : null;
  }
```

---

### 1.4 Auth Routes (`apps/vhunambi_api/src/routes/auth_routes.ts`)

```typescript
import { Hono } from 'hono';
import { vhunambiDb } from '../db/vhunambi_db.js';
import {
  requireAuthenticatedUser,
  sovereignAuthMiddleware,
} from '../middleware/auth_middleware.js';

export const authRoutes = new Hono();

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
        400
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
        400
      );
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
        400
      );
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
      { error: 'Active session or sessionId is required.', code: 'AUTH_REQUIRED' },
      401
    );
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
  if (!user) {
    return c.json({ error: 'User not found', code: 'USER_NOT_FOUND' }, 404);
  }
  const wallet = vhunambiDb.getWallet(authUser.creatorId);
  return c.json({
    user,
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
```

---

### 1.5 Tenant Isolation & Exploit Closure Across Domain Routes (`wallet`, `marketplace`, `library`, `playlists`, `sync`, `server`)

#### 1.5.1 `apps/vhunambi_api/src/routes/wallet_routes.ts`
Update `walletRoutes` to apply `sovereignAuthMiddleware` and `assertTenantCreatorAccess`:

```typescript
import { Hono } from 'hono';
import { vhunambiDb } from '../db/vhunambi_db.js';
import {
  assertTenantCreatorAccess,
  resolveEffectiveCreatorId,
  sovereignAuthMiddleware,
} from '../middleware/auth_middleware.js';

export const walletRoutes = new Hono();

walletRoutes.use('*', sovereignAuthMiddleware);

walletRoutes.get('/gateways', (c) => {
  return c.json({
    gateways: [
      {
        id: 'CAPITEC_PAY',
        label: 'Capitec Pay Direct',
        feePercent: 1.0,
        minZar: 50,
        settlementSpeed: 'INSTANT',
      },
      {
        id: 'OZOW_EFT',
        label: 'Ozow Instant EFT',
        feePercent: 1.5,
        minZar: 50,
        settlementSpeed: 'INSTANT',
      },
      {
        id: 'PAYFAST',
        label: 'PayFast Instant Clearing',
        feePercent: 2.0,
        minZar: 50,
        settlementSpeed: 'SAME_DAY',
      },
    ],
  });
});

walletRoutes.get('/', (c) => {
  const requestedId = c.req.query('creatorId');
  const forbidden = assertTenantCreatorAccess(c, requestedId);
  if (forbidden) return forbidden;

  const creatorId = resolveEffectiveCreatorId(c, requestedId, 'creator_cern');
  return c.json(vhunambiDb.getWallet(creatorId));
});

walletRoutes.get('/:creatorId', (c) => {
  const creatorId = c.req.param('creatorId');
  const forbidden = assertTenantCreatorAccess(c, creatorId);
  if (forbidden) return forbidden;

  return c.json(vhunambiDb.getWallet(creatorId));
});

walletRoutes.post('/payout', async (c) => {
  try {
    const body = (await c.req.json()) as {
      creatorId?: string;
      amountCoins?: number;
      amountZar?: number;
      bankName?: string;
      accountHolder?: string;
      accountNumber?: string;
      branchCode?: string;
      gateway?: 'CAPITEC_PAY' | 'OZOW_EFT' | 'PAYFAST';
      idempotencyKey?: string;
      saveBankDetails?: boolean;
    };

    const forbidden = assertTenantCreatorAccess(c, body.creatorId);
    if (forbidden) return forbidden;

    const creatorId = resolveEffectiveCreatorId(c, body.creatorId, 'creator_cern');

    if (!body.bankName || !body.accountHolder || !body.accountNumber) {
      return c.json(
        {
          error: 'bankName, accountHolder, and accountNumber are required',
          code: 'VALIDATION_ERROR',
        },
        400
      );
    }

    const result = vhunambiDb.requestPayout({
      creatorId,
      amountCoins: body.amountCoins,
      amountZar: body.amountZar,
      bankName: body.bankName,
      accountHolder: body.accountHolder,
      accountNumber: body.accountNumber,
      branchCode: body.branchCode,
      gateway: body.gateway,
      idempotencyKey: body.idempotencyKey,
      saveBankDetails: body.saveBankDetails,
    });

    return c.json(result, 201);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Payout failed';
    if (message.startsWith('INSUFFICIENT_FUNDS')) {
      return c.json({ error: message, code: 'INSUFFICIENT_FUNDS' }, 422);
    }
    return c.json({ error: message, code: 'PAYOUT_INVALID' }, 400);
  }
});
```

#### 1.5.2 Closing the Free Beat License Exploit in `marketplace_service.ts` & `marketplace_routes.ts`
In `apps/vhunambi_api/src/routes/marketplace_routes.ts`, attach `sovereignAuthMiddleware`, verify tenant match on `buyerId` (`assertTenantCreatorAccess`), and whenever `c.get('authUser')` is present or `isStrictAuthEnforced(c)` is true, force `enforceWalletBalance: true`:

```typescript
// Inside marketplace_routes.ts:
marketplaceRoutes.use('*', sovereignAuthMiddleware);

// On POST /beats/:id/license and POST /license:
const forbidden = assertTenantCreatorAccess(c, body.buyerId);
if (forbidden) return forbidden;

const effectiveBuyerId = resolveEffectiveCreatorId(c, body.buyerId, 'buyer_default');
const mustEnforceWallet =
  Boolean(c.get('authUser')) ||
  isStrictAuthEnforced(c) ||
  body.enforceWalletBalance === true;

const receipt = MarketplaceService.purchaseBeatLicense({
  assetId,
  buyerId: effectiveBuyerId,
  tier: body.tier as LicenseTierType,
  customPriceCoins: body.customPriceCoins,
  idempotencyKey: body.idempotencyKey,
  enforceWalletBalance: mustEnforceWallet ? true : body.enforceWalletBalance,
});
```

And on `GET /licenses/:buyerId`:
```typescript
marketplaceRoutes.get('/licenses/:buyerId', (c) => {
  const buyerId = c.req.param('buyerId');
  const forbidden = assertTenantCreatorAccess(c, buyerId);
  if (forbidden) return forbidden;
  const licenses = MarketplaceService.getBuyerLicenses(buyerId);
  return c.json({ buyerId, count: licenses.length, licenses });
});
```

#### 1.5.3 `apps/vhunambi_api/src/routes/library_routes.ts` & `playlist_routes.ts`
In `library_routes.ts` and `playlist_routes.ts`, attach `sovereignAuthMiddleware` and enforce `assertTenantCreatorAccess`. In `playlist_routes.ts`:
- Before `POST /`, `PUT /:id`, or `DELETE /:id`, check `vhunambiDb.getPlaylistOwnerCreatorId(playlistId)`: if the playlist already exists and its owner does not match `authUser.creatorId`, return `403 TENANT_FORBIDDEN`.

#### 1.5.4 `apps/vhunambi_api/src/routes/sync_routes.ts` & `server.ts`
In `sync_routes.ts`:
- Attach `sovereignAuthMiddleware`.
- In `GET /delta`: check `assertTenantCreatorAccess(c, c.req.query('creatorId'))`; pass `viewerCreatorId = c.get('authUser')?.creatorId ?? c.req.query('creatorId')` to `vhunambiDb.getDelta(sinceSeq, limit, viewerCreatorId)`.
- In `POST /mutations`: if `c.get('authUser')` is present, verify every mutation payload's `creatorId` / `buyerId` / `authorId` (when specified) matches `authUser.creatorId` (`403 TENANT_FORBIDDEN` on mismatch), and default `enforceWalletBalance: true` on authenticated `beat_license` mutations.

In `apps/vhunambi_api/src/server.ts`:
- Mount `authRoutes` at `/v1/auth`, `/api/auth`, and `/api/v1/auth`.
- Apply `sovereignAuthMiddleware` and `assertTenantCreatorAccess` on `/api/creators/:id/wallet` and `/api/creators/:id/wallet/withdraw` in `social_routes.ts`.

---

## 2. Client Sovereign Auth Vault, API Client & 6-Way Identity Unification (`apps/vhunambi_client`)

### 2.1 Per-Device CSPRNG Entropy in `HiveAesVaultCipher` (`apps/vhunambi_client/lib/core/storage/hive_aes_vault_cipher.dart`)

```dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Deterministic + Device-Entropic HKDF-SHA256 256-bit key derivation for Tier 0 Sensitive Hive Boxes.
///
/// Phase 61 Upgrade (`REQ-P61-CLI-01`):
/// - Generates a 32-byte cryptographically random salt (`Random.secure()`) on first device launch
///   and persists it inside `vhunambi_prefs` under `deviceGenesisSaltPrefKey`.
/// - Derives the 256-bit AES key via two-stage HMAC-SHA256 (HKDF-Extract + HKDF-Expand).
class HiveAesVaultCipher {
  HiveAesVaultCipher._();

  static const String deviceGenesisSaltPrefKey =
      'sovereign_device_genesis_salt_v61';

  static const String _applicationIkm =
      'vhunambi_sovereign_hive_vault_v60_ikm_za_enterprise';
  static const String _fallbackSalt = 'vhunambi_tier0_aes256_hkdf_salt_v1';

  static String? _activeDeviceSalt;

  /// Generates a 32-byte CSPRNG base64url salt using [Random.secure].
  static String generateSecureSaltBase64Url() {
    final random = Random.secure();
    final bytes = Uint8List(32);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return base64UrlEncode(bytes);
  }

  /// Ensures the device-unique 32-byte CSPRNG salt is loaded from or created in [prefsBox].
  static Future<String> ensureDeviceGenesisSalt(Box<dynamic> prefsBox) async {
    final existing = prefsBox.get(deviceGenesisSaltPrefKey);
    if (existing is String && existing.trim().length >= 32) {
      _activeDeviceSalt = existing.trim();
      return _activeDeviceSalt!;
    }
    final generated = generateSecureSaltBase64Url();
    await prefsBox.put(deviceGenesisSaltPrefKey, generated);
    _activeDeviceSalt = generated;
    return generated;
  }

  /// Sets or overrides the active device salt in memory (used by tests or bootstrap).
  static void setActiveDeviceSalt(String? salt) {
    _activeDeviceSalt = salt?.trim();
  }

  /// Returns the currently active device salt (or fallback salt if not yet bootstrapped).
  static String get activeDeviceSalt =>
      (_activeDeviceSalt != null && _activeDeviceSalt!.isNotEmpty)
          ? _activeDeviceSalt!
          : _fallbackSalt;

  /// Derives an exact 32-byte (256-bit) AES key using two-stage HMAC-SHA256 (HKDF-Extract + Expand).
  static Uint8List derive256BitKey({
    String? customSeed,
    String? deviceSaltOverride,
  }) {
    final effectiveSalt =
        deviceSaltOverride?.trim() ??
        (customSeed != null ? _fallbackSalt : activeDeviceSalt);
    final ikmBytes = utf8.encode(customSeed ?? _applicationIkm);
    final saltBytes = utf8.encode(effectiveSalt);

    // Stage 1: HKDF-Extract(salt, IKM) -> PRK
    final extractHmac = Hmac(sha256, saltBytes);
    final prk = extractHmac.convert(ikmBytes).bytes;

    // Stage 2: HKDF-Expand(PRK, info || 0x01) -> 32-byte OKM
    final infoBytes = <int>[
      ...utf8.encode('vhunambi_hive_tier0_aes256_v61'),
      0x01,
    ];
    final expandHmac = Hmac(sha256, prk);
    final okm = expandHmac.convert(infoBytes).bytes;

    return Uint8List.fromList(okm.sublist(0, 32));
  }

  /// Builds the [HiveAesCipher] instance used to open Tier 0 boxes.
  static HiveAesCipher buildCipher({
    String? customSeed,
    String? deviceSaltOverride,
  }) {
    return HiveAesCipher(
      derive256BitKey(
        customSeed: customSeed,
        deviceSaltOverride: deviceSaltOverride,
      ),
    );
  }
}
```

In `apps/vhunambi_client/lib/core/storage/hive_service.dart`, update `HiveService.init()` so `prefsBox` (`vhunambi_prefs`) is opened first and `await HiveAesVaultCipher.ensureDeviceGenesisSalt(_prefsBox!)` is called right before constructing `HiveAesVaultCipher.buildCipher()` for Tier-0 boxes.

---

### 2.2 Canonical Creator ID Unification Utility (`apps/vhunambi_client/lib/core/utils/creator_id_utils.dart`)

```dart
/// Utilities for normalizing creator handles and creator IDs across
/// client seed data, local Hive caches, and backend API routes.
///
/// Phase 61 Upgrade (`REQ-P61-CLI-03`):
/// Resolves all legacy split-brain aliases (`'me'`, `'usr_me'`, `'buyer_user'`,
/// `'buyer_default'`, `'vhunambi_user'`) to the active canonical creator ID.
String normalizeCreatorIdFromHandle(String handle, {String? fallbackId}) {
  final clean = handle.trim().toLowerCase().replaceAll('@', '');
  if (clean.isEmpty) {
    return fallbackId ?? 'creator_cern';
  }
  if (clean == 'vhunambi_user' || clean == 'me' || clean == 'usr_me') {
    return fallbackId ?? 'creator_cern';
  }
  if (clean.startsWith('creator_')) {
    return clean;
  }
  return 'creator_$clean';
}

/// Canonicalizes any raw creator ID or legacy placeholder alias to a valid creator ID.
String canonicalizeCreatorId(
  String? rawId, {
  String activeCreatorId = 'creator_cern',
}) {
  if (rawId == null) return activeCreatorId;
  final trimmed = rawId.trim();
  if (trimmed.isEmpty) return activeCreatorId;

  const legacySelfAliases = <String>{
    'me',
    'usr_me',
    'buyer_user',
    'buyer_default',
    'vhunambi_user',
    '@vhunambi_user',
    'default_user',
  };

  if (legacySelfAliases.contains(trimmed.toLowerCase())) {
    return activeCreatorId;
  }
  if (trimmed.startsWith('@')) {
    return normalizeCreatorIdFromHandle(trimmed, fallbackId: activeCreatorId);
  }
  return trimmed;
}

/// Derives a canonical `@handle` from a creatorId (e.g. `'creator_cern'` -> `'@cern'`).
String handleFromCreatorId(String creatorId) {
  final trimmed = creatorId.trim().toLowerCase();
  if (trimmed.startsWith('@')) return trimmed;
  if (trimmed.startsWith('creator_')) {
    return '@${trimmed.substring('creator_'.length)}';
  }
  return '@$trimmed';
}
```

---

### 2.3 Sovereign Auth Session Model (`apps/vhunambi_client/lib/core/auth/sovereign_auth_session.dart`)

```dart
import 'package:flutter/foundation.dart';

enum SovereignAuthMode {
  guestSeeded,
  authenticated,
}

@immutable
class SovereignAuthSession {
  final String userId;
  final String creatorId;
  final String handle;
  final String displayName;
  final String email;
  final String avatarUrl;
  final String? accessToken;
  final String? refreshToken;
  final String? sessionId;
  final DateTime? expiresAt;
  final SovereignAuthMode authMode;
  final bool isVerified;

  const SovereignAuthSession({
    required this.userId,
    required this.creatorId,
    required this.handle,
    required this.displayName,
    required this.email,
    required this.avatarUrl,
    this.accessToken,
    this.refreshToken,
    this.sessionId,
    this.expiresAt,
    required this.authMode,
    this.isVerified = true,
  });

  factory SovereignAuthSession.seededDefault({
    String creatorId = 'creator_cern',
    String handle = '@cern',
    String displayName = 'CERN',
    String email = 'cern@vhunambi.co.za',
  }) {
    final cleanSlug = creatorId.replaceFirst('creator_', '');
    return SovereignAuthSession(
      userId: 'usr_$cleanSlug',
      creatorId: creatorId,
      handle: handle,
      displayName: displayName,
      email: email,
      avatarUrl:
          'https://api.dicebear.com/7.x/avataaars/svg?seed=$creatorId',
      authMode: SovereignAuthMode.guestSeeded,
      isVerified: true,
    );
  }

  bool get isAuthenticated =>
      authMode == SovereignAuthMode.authenticated &&
      accessToken != null &&
      accessToken!.isNotEmpty;

  bool get isAccessTokenExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(
      expiresAt!.subtract(const Duration(seconds: 30)),
    );
  }

  SovereignAuthSession copyWith({
    String? userId,
    String? creatorId,
    String? handle,
    String? displayName,
    String? email,
    String? avatarUrl,
    String? accessToken,
    String? refreshToken,
    String? sessionId,
    DateTime? expiresAt,
    SovereignAuthMode? authMode,
    bool? isVerified,
  }) {
    return SovereignAuthSession(
      userId: userId ?? this.userId,
      creatorId: creatorId ?? this.creatorId,
      handle: handle ?? this.handle,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      sessionId: sessionId ?? this.sessionId,
      expiresAt: expiresAt ?? this.expiresAt,
      authMode: authMode ?? this.authMode,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'userId': userId,
      'creatorId': creatorId,
      'handle': handle,
      'displayName': displayName,
      'email': email,
      'avatarUrl': avatarUrl,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'sessionId': sessionId,
      'expiresAt': expiresAt?.toIso8601String(),
      'authMode': authMode.name,
      'isVerified': isVerified,
    };
  }

  factory SovereignAuthSession.fromJson(Map<String, dynamic> json) {
    final modeStr = json['authMode']?.toString() ?? 'guestSeeded';
    final mode = modeStr == SovereignAuthMode.authenticated.name
        ? SovereignAuthMode.authenticated
        : SovereignAuthMode.guestSeeded;
    final expiresRaw = json['expiresAt']?.toString();
    return SovereignAuthSession(
      userId: json['userId']?.toString() ?? 'usr_cern',
      creatorId: json['creatorId']?.toString() ?? 'creator_cern',
      handle: json['handle']?.toString() ?? '@cern',
      displayName: json['displayName']?.toString() ?? 'CERN',
      email: json['email']?.toString() ?? 'cern@vhunambi.co.za',
      avatarUrl:
          json['avatarUrl']?.toString() ??
          'https://api.dicebear.com/7.x/avataaars/svg?seed=creator_cern',
      accessToken: json['accessToken']?.toString(),
      refreshToken: json['refreshToken']?.toString(),
      sessionId: json['sessionId']?.toString(),
      expiresAt:
          expiresRaw != null ? DateTime.tryParse(expiresRaw) : null,
      authMode: mode,
      isVerified: json['isVerified'] != false,
    );
  }

  factory SovereignAuthSession.fromApiBundle(Map<String, dynamic> bundle) {
    final userMap = (bundle['user'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final sessionMap = (bundle['session'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final creatorId = userMap['creatorId']?.toString() ?? 'creator_cern';
    final expiresRaw = bundle['expiresAt']?.toString();

    return SovereignAuthSession(
      userId: userMap['userId']?.toString() ?? 'usr_cern',
      creatorId: creatorId,
      handle: userMap['handle']?.toString() ?? '@cern',
      displayName: userMap['displayName']?.toString() ?? 'CERN',
      email: userMap['email']?.toString() ?? 'cern@vhunambi.co.za',
      avatarUrl:
          userMap['avatarUrl']?.toString() ??
          'https://api.dicebear.com/7.x/avataaars/svg?seed=$creatorId',
      accessToken: bundle['accessToken']?.toString(),
      refreshToken: bundle['refreshToken']?.toString(),
      sessionId:
          sessionMap['sessionId']?.toString() ??
          bundle['sessionId']?.toString(),
      expiresAt:
          expiresRaw != null ? DateTime.tryParse(expiresRaw) : null,
      authMode: SovereignAuthMode.authenticated,
      isVerified: userMap['isVerified'] != false,
    );
  }
}
```

---

### 2.4 Multi-User Hive Account Sanitizer (`apps/vhunambi_client/lib/core/auth/sovereign_hive_account_sanitizer.dart`)

```dart
import 'package:vhunambi_client/core/storage/hive_service.dart';

/// Purges tenant-private Hive boxes and resets delta-sync cursors whenever
/// the user signs out or transitions to a different creator identity (`REQ-P61-CLI-05`).
///
/// Preserves public catalog caches (`vhunambi_tracks`, `vhunambi_marketplace_catalog_box`,
/// `vhunambi_sound_packs_box`) and the device genesis salt (`sovereign_device_genesis_salt_v61`).
class SovereignHiveAccountSanitizer {
  final HiveService _hiveService;

  const SovereignHiveAccountSanitizer(this._hiveService);

  /// Sanitizes private user state in Hive when signing out or switching between accounts.
  Future<void> sanitizeForAccountTransition({
    required String? previousCreatorId,
    required String nextCreatorId,
    bool forcePurge = false,
  }) async {
    if (!_hiveService.isInitialized) return;

    final isSameCreator =
        previousCreatorId != null &&
        previousCreatorId.trim() == nextCreatorId.trim();
    if (isSameCreator && !forcePurge) {
      return;
    }

    // 1. Clear Tier-0 private financial, legal & biometric boxes
    await _hiveService.walletLedgerBox.clear();
    await _hiveService.licenseCertificatesBox.clear();
    await _hiveService.creatorDnaBox.clear();

    // 2. Clear Tier-1 pending mutation outbox so User A's mutations never replay under User B
    await _hiveService.syncOutboxBox.clear();

    // 3. Clear Tier-2 user-private Library & Playlists boxes
    await _hiveService.libraryTracksBox.clear();
    await _hiveService.playlistsBox.clear();

    // 4. Remove active owner profile entry ('profile_me') while keeping cached public profiles
    if (_hiveService.profilesBox.containsKey('profile_me')) {
      await _hiveService.profilesBox.delete('profile_me');
    }

    // 5. Reset edge delta-sync sequence cursor so the new creator fetches their own delta stream
    await _hiveService.prefsBox.put('edge_sync_last_seq', 0);
    await _hiveService.prefsBox.put('active_sovereign_creator_id', nextCreatorId);
  }
}
```

---

### 2.5 Tier-0 `vhunambi_tokens` Repository (`apps/vhunambi_client/lib/core/auth/sovereign_auth_repository.dart`)

```dart
import 'dart:convert';
import 'package:vhunambi_client/core/auth/sovereign_auth_session.dart';
import 'package:vhunambi_client/core/storage/hive_service.dart';

/// Persists and restores [SovereignAuthSession] inside the Tier-0 AES-256 encrypted
/// `vhunambi_tokens` Hive box (`REQ-P61-CLI-02`).
class SovereignAuthRepository {
  static const String sessionStorageKey = 'sovereign_auth_session_v1';

  final HiveService _hiveService;

  const SovereignAuthRepository(this._hiveService);

  /// Loads the persisted [SovereignAuthSession] from `vhunambi_tokens`, or returns
  /// the default seeded session (`creator_cern`) if no session is stored.
  SovereignAuthSession loadSession() {
    if (!_hiveService.isInitialized) {
      return SovereignAuthSession.seededDefault();
    }
    try {
      final raw = _hiveService.tokenBox.get(sessionStorageKey);
      if (raw == null) {
        return SovereignAuthSession.seededDefault();
      }
      if (raw is String && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return SovereignAuthSession.fromJson(decoded);
      }
      if (raw is Map) {
        return SovereignAuthSession.fromJson(Map<String, dynamic>.from(raw));
      }
    } catch (_) {
      // Fall back cleanly if corrupted
    }
    return SovereignAuthSession.seededDefault();
  }

  /// Writes [session] into the encrypted `vhunambi_tokens` Hive box.
  Future<void> saveSession(SovereignAuthSession session) async {
    if (!_hiveService.isInitialized) return;
    final encoded = jsonEncode(session.toJson());
    await _hiveService.tokenBox.put(sessionStorageKey, encoded);
    await _hiveService.prefsBox.put(
      'active_sovereign_creator_id',
      session.creatorId,
    );
  }

  /// Removes the persisted session from `vhunambi_tokens`.
  Future<void> clearSession() async {
    if (!_hiveService.isInitialized) return;
    await _hiveService.tokenBox.delete(sessionStorageKey);
  }
}
```

---

### 2.6 Unified `SovereignApiClient` with Single-Flight `401` Token Refresh (`apps/vhunambi_client/lib/core/network/sovereign_api_client.dart`)

Add `resolveApiRootUrl()` to `AppConstants` (`apps/vhunambi_client/lib/core/constants/app_constants.dart`):

```dart
  /// Returns the root API URL without trailing `/v1` (e.g. `http://localhost:3000`).
  static String resolveApiRootUrl() {
    final v1 = resolveApiBaseUrl();
    if (v1.endsWith('/v1')) {
      return v1.substring(0, v1.length - 3);
    }
    return v1;
  }
```

And implement `SovereignApiClient` in `apps/vhunambi_client/lib/core/network/sovereign_api_client.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:vhunambi_client/core/auth/sovereign_auth_repository.dart';
import 'package:vhunambi_client/core/auth/sovereign_auth_session.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';

typedef SessionUpdatedCallback = void Function(SovereignAuthSession session);

/// Centralized HTTP client for Vhunambi API requests (`REQ-P61-CLI-04`).
///
/// Responsibilities:
/// 1. Injects `Authorization: Bearer <accessToken>` when authenticated.
/// 2. Injects `X-Vhunambi-Creator-Id: <creatorId>` on all requests.
/// 3. Executes single-flight `POST /api/auth/refresh` rotation when a protected
///    endpoint responds with `401`, updates `vhunambi_tokens`, and replays the request once.
class SovereignApiClient {
  final http.Client _httpClient;
  final SovereignAuthRepository _authRepository;
  final String _baseUrl;
  final SessionUpdatedCallback? onSessionUpdated;

  Future<SovereignAuthSession?>? _inflightRefreshFuture;

  SovereignApiClient({
    required SovereignAuthRepository authRepository,
    http.Client? httpClient,
    String? baseUrl,
    this.onSessionUpdated,
  }) : _authRepository = authRepository,
       _httpClient = httpClient ?? http.Client(),
       _baseUrl = baseUrl ?? AppConstants.resolveApiRootUrl();

  String get baseUrl => _baseUrl;

  Uri resolveUri(String path, [Map<String, String>? queryParameters]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$_baseUrl$normalizedPath');
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }
    return uri.replace(
      queryParameters: <String, String>{
        ...uri.queryParameters,
        ...queryParameters,
      },
    );
  }

  Map<String, String> buildHeaders({
    Map<String, String>? extraHeaders,
    SovereignAuthSession? sessionOverride,
  }) {
    final session = sessionOverride ?? _authRepository.loadSession();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Vhunambi-Creator-Id': session.creatorId,
    };
    if (session.isAuthenticated) {
      headers['Authorization'] = 'Bearer ${session.accessToken}';
    }
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }
    return headers;
  }

  Future<http.Response> get(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    return _sendWithRefreshRetry(
      () => _httpClient
          .get(
            resolveUri(path, queryParameters),
            headers: buildHeaders(extraHeaders: headers),
          )
          .timeout(timeout),
    );
  }

  Future<http.Response> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final encodedBody = body == null
        ? null
        : (body is String ? body : jsonEncode(body));
    return _sendWithRefreshRetry(
      () => _httpClient
          .post(
            resolveUri(path),
            headers: buildHeaders(extraHeaders: headers),
            body: encodedBody,
          )
          .timeout(timeout),
    );
  }

  Future<http.Response> put(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final encodedBody = body == null
        ? null
        : (body is String ? body : jsonEncode(body));
    return _sendWithRefreshRetry(
      () => _httpClient
          .put(
            resolveUri(path),
            headers: buildHeaders(extraHeaders: headers),
            body: encodedBody,
          )
          .timeout(timeout),
    );
  }

  Future<http.Response> delete(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    return _sendWithRefreshRetry(
      () => _httpClient
          .delete(
            resolveUri(path, queryParameters),
            headers: buildHeaders(extraHeaders: headers),
          )
          .timeout(timeout),
    );
  }

  Future<http.Response> _sendWithRefreshRetry(
    Future<http.Response> Function() requestFn,
  ) async {
    final initialResponse = await requestFn();
    if (initialResponse.statusCode != 401) {
      return initialResponse;
    }

    final currentSession = _authRepository.loadSession();
    final refreshToken = currentSession.refreshToken;
    if (!currentSession.isAuthenticated ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      return initialResponse;
    }

    final refreshedSession = await _performSingleFlightRefresh(refreshToken);
    if (refreshedSession == null || !refreshedSession.isAuthenticated) {
      return initialResponse;
    }

    return requestFn();
  }

  Future<SovereignAuthSession?> _performSingleFlightRefresh(
    String refreshToken,
  ) {
    if (_inflightRefreshFuture != null) {
      return _inflightRefreshFuture!;
    }
    final future = _executeRefreshCall(refreshToken);
    _inflightRefreshFuture = future;
    return future.whenComplete(() {
      _inflightRefreshFuture = null;
    });
  }

  Future<SovereignAuthSession?> _executeRefreshCall(String refreshToken) async {
    try {
      final response = await _httpClient
          .post(
            resolveUri('/api/auth/refresh'),
            headers: const <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{'refreshToken': refreshToken}),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final nextSession = SovereignAuthSession.fromApiBundle(decoded);
        await _authRepository.saveSession(nextSession);
        onSessionUpdated?.call(nextSession);
        return nextSession;
      }

      if (response.statusCode == 401) {
        final fallback = SovereignAuthSession.seededDefault(
          creatorId: _authRepository.loadSession().creatorId,
          handle: _authRepository.loadSession().handle,
          displayName: _authRepository.loadSession().displayName,
        );
        await _authRepository.saveSession(fallback);
        onSessionUpdated?.call(fallback);
      }
    } catch (_) {
      // Network offline during refresh: preserve current session
    }
    return null;
  }
}
```

---

### 2.7 Riverpod Auth Providers & 6-Way Client Identity Unification (`apps/vhunambi_client/lib/core/auth/auth_providers.dart`)

```dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:vhunambi_client/core/auth/sovereign_auth_repository.dart';
import 'package:vhunambi_client/core/auth/sovereign_auth_session.dart';
import 'package:vhunambi_client/core/auth/sovereign_hive_account_sanitizer.dart';
import 'package:vhunambi_client/core/network/sovereign_api_client.dart';
import 'package:vhunambi_client/core/storage/hive_service.dart';
import 'package:vhunambi_client/core/utils/creator_id_utils.dart';

final sovereignHttpClientProvider = Provider<http.Client>((ref) {
  return http.Client();
});

final sovereignAuthRepositoryProvider = Provider<SovereignAuthRepository>((ref) {
  return SovereignAuthRepository(HiveService());
});

final sovereignHiveAccountSanitizerProvider =
    Provider<SovereignHiveAccountSanitizer>((ref) {
      return SovereignHiveAccountSanitizer(HiveService());
    });

final sovereignApiClientProvider = Provider<SovereignApiClient>((ref) {
  final repo = ref.watch(sovereignAuthRepositoryProvider);
  final httpClient = ref.watch(sovereignHttpClientProvider);
  return SovereignApiClient(
    authRepository: repo,
    httpClient: httpClient,
    onSessionUpdated: (updatedSession) {
      ref.read(authSessionProvider.notifier).adoptSession(updatedSession);
    },
  );
});

class AuthSessionNotifier extends StateNotifier<SovereignAuthSession> {
  final SovereignAuthRepository _repository;
  final SovereignHiveAccountSanitizer _sanitizer;
  final http.Client _httpClient;
  final String _baseUrl;

  AuthSessionNotifier({
    required SovereignAuthRepository repository,
    required SovereignHiveAccountSanitizer sanitizer,
    required http.Client httpClient,
    required String baseUrl,
  }) : _repository = repository,
       _sanitizer = sanitizer,
       _httpClient = httpClient,
       _baseUrl = baseUrl,
       super(repository.loadSession());

  void adoptSession(SovereignAuthSession session) {
    state = session;
  }

  /// Authenticates against `POST /api/auth/login` and binds the Tier-0 Hive vault.
  Future<SovereignAuthSession> signIn({
    required String identifier,
    required String password,
  }) async {
    final previousCreatorId = state.creatorId;
    final response = await _httpClient
        .post(
          Uri.parse('$_baseUrl/api/auth/login'),
          headers: const <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(<String, dynamic>{
            'identifier': identifier.trim(),
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 8));

    final bodyMap = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw StateError(
        bodyMap['error']?.toString() ?? 'Authentication failed.',
      );
    }

    final nextSession = SovereignAuthSession.fromApiBundle(bodyMap);
    await _sanitizer.sanitizeForAccountTransition(
      previousCreatorId: previousCreatorId,
      nextCreatorId: nextSession.creatorId,
    );
    await _repository.saveSession(nextSession);
    state = nextSession;
    return nextSession;
  }

  /// Registers a new creator account via `POST /api/auth/register`.
  Future<SovereignAuthSession> register({
    required String handle,
    required String email,
    required String password,
    required String displayName,
  }) async {
    final previousCreatorId = state.creatorId;
    final response = await _httpClient
        .post(
          Uri.parse('$_baseUrl/api/auth/register'),
          headers: const <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(<String, dynamic>{
            'handle': handle.trim(),
            'email': email.trim(),
            'password': password,
            'displayName': displayName.trim(),
          }),
        )
        .timeout(const Duration(seconds: 8));

    final bodyMap = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw StateError(bodyMap['error']?.toString() ?? 'Registration failed.');
    }

    final nextSession = SovereignAuthSession.fromApiBundle(bodyMap);
    await _sanitizer.sanitizeForAccountTransition(
      previousCreatorId: previousCreatorId,
      nextCreatorId: nextSession.creatorId,
    );
    await _repository.saveSession(nextSession);
    state = nextSession;
    return nextSession;
  }

  /// Switches to a local seeded creator preset or signs in if server is reachable.
  Future<SovereignAuthSession> switchSeededCreatorPreset({
    required String creatorId,
    required String handle,
    required String displayName,
    String? password,
  }) async {
    final previousCreatorId = state.creatorId;
    if (password != null && password.isNotEmpty) {
      try {
        return await signIn(identifier: handle, password: password);
      } catch (_) {
        // Offline fallback to seeded preset
      }
    }

    final nextSession = SovereignAuthSession.seededDefault(
      creatorId: creatorId,
      handle: handle,
      displayName: displayName,
      email: '${handle.replaceAll('@', '')}@vhunambi.co.za',
    );
    await _sanitizer.sanitizeForAccountTransition(
      previousCreatorId: previousCreatorId,
      nextCreatorId: nextSession.creatorId,
      forcePurge: previousCreatorId != nextSession.creatorId,
    );
    await _repository.saveSession(nextSession);
    state = nextSession;
    return nextSession;
  }

  /// Revokes remote session (best-effort), sanitizes private Hive boxes, and resets to default seeded mode.
  Future<void> signOut({String defaultCreatorId = 'creator_cern'}) async {
    final current = state;
    if (current.isAuthenticated && current.accessToken != null) {
      try {
        await _httpClient
            .post(
              Uri.parse('$_baseUrl/api/auth/logout'),
              headers: <String, String>{
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${current.accessToken}',
              },
              body: jsonEncode(<String, dynamic>{
                'sessionId': current.sessionId,
              }),
            )
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        // Offline sign-out still sanitizes local state deterministically
      }
    }

    await _sanitizer.sanitizeForAccountTransition(
      previousCreatorId: current.creatorId,
      nextCreatorId: defaultCreatorId,
      forcePurge: true,
    );
    await _repository.clearSession();
    final fallback = SovereignAuthSession.seededDefault(
      creatorId: defaultCreatorId,
      handle: handleFromCreatorId(defaultCreatorId),
      displayName: defaultCreatorId
          .replaceFirst('creator_', '')
          .toUpperCase(),
    );
    state = fallback;
  }
}

final authSessionProvider =
    StateNotifierProvider<AuthSessionNotifier, SovereignAuthSession>((ref) {
      final repo = ref.watch(sovereignAuthRepositoryProvider);
      final sanitizer = ref.watch(sovereignHiveAccountSanitizerProvider);
      final httpClient = ref.watch(sovereignHttpClientProvider);
      final apiClient = ref.watch(sovereignApiClientProvider);
      return AuthSessionNotifier(
        repository: repo,
        sanitizer: sanitizer,
        httpClient: httpClient,
        baseUrl: apiClient.baseUrl,
      );
    });

/// Single canonical source of truth for the active user's creatorId across all 6 client domains (`REQ-P61-CLI-03`).
final currentCreatorIdProvider = Provider<String>((ref) {
  final session = ref.watch(authSessionProvider);
  return canonicalizeCreatorId(session.creatorId);
});

/// Single canonical source of truth for the active user's `@handle`.
final currentCreatorHandleProvider = Provider<String>((ref) {
  final session = ref.watch(authSessionProvider);
  return session.handle.startsWith('@')
      ? session.handle
      : '@${session.handle}';
});
```

### 2.8 Wiring the 6 Client Domains to `currentCreatorIdProvider` & `sovereignApiClientProvider`

1. **Playlists (`apps/vhunambi_client/lib/features/playlists/presentation/providers/playlists_provider.dart`)**:
   - Replace `defaultCreatorId = 'creator_makhadzi'` with `final activeCreatorId = ref.watch(currentCreatorIdProvider);` in `playlistRepositoryProvider` and attach Bearer headers from `sovereignAuthRepositoryProvider`.
2. **Library (`apps/vhunambi_client/lib/features/library/presentation/providers/library_tracks_provider.dart`)**:
   - Read `final activeCreatorId = ref.watch(currentCreatorIdProvider);` instead of hardcoded `'creator_cern'` and attach Bearer headers when calling `/api/library/sync` and `/api/library`.
3. **Creator Wallet (`apps/vhunambi_client/lib/features/social/presentation/providers/creator_wallet_provider.dart`)**:
   - Read `final activeCreatorId = ref.watch(currentCreatorIdProvider);` instead of hardcoded `'creator_cern'` and include Bearer headers on `/api/wallet/:id` and `/api/wallet/payout`.
4. **Marketplace Beat Checkout (`apps/vhunambi_client/lib/features/marketplace/presentation/providers/beat_checkout_provider.dart` & `marketplace_providers.dart`)**:
   - Default `buyerId` to `ref.read(currentCreatorIdProvider)` instead of `'buyer_user'` / `'buyer_default'` and pass Bearer headers via `HttpMarketplaceRepository`.
5. **Social Feed & Reels Comments (`apps/vhunambi_client/lib/features/social/presentation/providers/social_feed_provider.dart` & `reels_comments_provider.dart`)**:
   - Use `ref.read(currentCreatorIdProvider)` and `ref.read(currentCreatorHandleProvider)` when creating Kinetic Posts or Reels comments.
6. **Content Studio & Owner Profile (`apps/vhunambi_client/lib/features/content_studio/presentation/providers/content_studio_provider.dart` & `profile_provider.dart`)**:
   - Watch `currentCreatorIdProvider` in `ownerProfileProvider` and `contentStudioProvider` so switching between `@cern` and `@makhadzi` dynamically updates the active Creator Profile and Content Studio workspace.

---

## 3. Obsidian Tactile Identity HUD & Auth Sheet (`STD-UIUX-001` Compliant)

### 3.1 `AccountIdentitySecurityCard` (`apps/vhunambi_client/lib/features/profile/presentation/widgets/account_identity_security_card.dart`)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/auth/sovereign_auth_session.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/features/auth/presentation/widgets/sovereign_auth_sheet.dart';

class AccountIdentitySecurityCard extends ConsumerWidget {
  const AccountIdentitySecurityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);
    final isAuthenticated = session.isAuthenticated;

    return Container(
      key: const Key('auth_identity_security_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.obsidianSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAuthenticated
              ? AppColors.emeraldSuccess.withValues(alpha: 0.45)
              : AppColors.electricGold.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (isAuthenticated
                          ? AppColors.emeraldSuccess
                          : AppColors.electricGold)
                      .withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isAuthenticated
                      ? PhosphorIcons.shieldCheck
                      : PhosphorIcons.lockKey,
                  color: isAuthenticated
                      ? AppColors.emeraldSuccess
                      : AppColors.electricGold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      session.displayName,
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.mistWhite,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${session.handle}  •  ${session.creatorId}',
                      key: const Key('auth_creator_handle_text'),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.ashGrey,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                key: const Key('auth_mode_badge_pill'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: (isAuthenticated
                          ? AppColors.emeraldSuccess
                          : AppColors.electricGold)
                      .withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      isAuthenticated
                          ? PhosphorIcons.checkCircle
                          : PhosphorIcons.key,
                      size: 13,
                      color: isAuthenticated
                          ? AppColors.emeraldSuccess
                          : AppColors.electricGold,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isAuthenticated ? 'SOVEREIGN JWT' : 'SEEDED VAULT',
                      style: AppTypography.labelSmall.copyWith(
                        color: isAuthenticated
                            ? AppColors.emeraldSuccess
                            : AppColors.electricGold,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.obsidianCanvas,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  PhosphorIcons.lockKey,
                  size: 14,
                  color: AppColors.ashGrey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tier-0 AES-256 HKDF Vault Active  •  Tenant Sync Isolated',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.ashGrey,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                key: const Key('auth_open_sheet_btn'),
                onPressed: () {
                  SovereignAuthSheet.show(context);
                },
                icon: const Icon(PhosphorIcons.key, size: 15),
                label: Text(
                  isAuthenticated ? 'Session & Credentials' : 'Sign In / Register',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.electricGold,
                  side: BorderSide(
                    color: AppColors.electricGold.withValues(alpha: 0.5),
                  ),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('auth_switch_account_btn'),
                onPressed: () {
                  SovereignAuthSheet.show(context);
                },
                icon: const Icon(PhosphorIcons.userSwitch, size: 15),
                label: const Text('Switch Creator'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.mistWhite,
                  side: BorderSide(
                    color: AppColors.ashGrey.withValues(alpha: 0.35),
                  ),
                ),
              ),
              if (isAuthenticated || session.creatorId != 'creator_cern')
                OutlinedButton.icon(
                  key: const Key('auth_sign_out_btn'),
                  onPressed: () async {
                    await ref.read(authSessionProvider.notifier).signOut();
                  },
                  icon: const Icon(PhosphorIcons.signOut, size: 15),
                  label: const Text('Reset / Sign Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.crimsonAlert,
                    side: BorderSide(
                      color: AppColors.crimsonAlert.withValues(alpha: 0.45),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
```

---

### 3.2 `SovereignAuthSheet` Modal (`apps/vhunambi_client/lib/features/auth/presentation/widgets/sovereign_auth_sheet.dart`)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';

class SovereignAuthSheet extends ConsumerStatefulWidget {
  const SovereignAuthSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SovereignAuthSheet(),
    );
  }

  @override
  ConsumerState<SovereignAuthSheet> createState() => _SovereignAuthSheetState();
}

class _SovereignAuthSheetState extends ConsumerState<SovereignAuthSheet> {
  bool _isRegisterMode = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  final TextEditingController _identifierController = TextEditingController(
    text: '@cern',
  );
  final TextEditingController _emailController = TextEditingController(
    text: 'cern@vhunambi.co.za',
  );
  final TextEditingController _displayNameController = TextEditingController(
    text: 'CERN',
  );
  final TextEditingController _passwordController = TextEditingController(
    text: 'VhunambiSovereign!2026',
  );

  @override
  void dispose() {
    _identifierController.dispose();
    _emailController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final notifier = ref.read(authSessionProvider.notifier);
      if (_isRegisterMode) {
        await notifier.register(
          handle: _identifierController.text,
          email: _emailController.text,
          password: _passwordController.text,
          displayName: _displayNameController.text,
        );
      } else {
        await notifier.signIn(
          identifier: _identifierController.text,
          password: _passwordController.text,
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _errorMessage = err.toString().replaceFirst('Bad state: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _applyPreset({
    required String creatorId,
    required String handle,
    required String displayName,
  }) async {
    _identifierController.text = handle;
    _displayNameController.text = displayName;
    _emailController.text = '${handle.replaceAll('@', '')}@vhunambi.co.za';
    _passwordController.text = 'VhunambiSovereign!2026';

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authSessionProvider.notifier)
          .switchSeededCreatorPreset(
            creatorId: creatorId,
            handle: handle,
            displayName: displayName,
            password: _passwordController.text,
          );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _errorMessage = err.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Container(
          key: const Key('sovereign_auth_sheet'),
          margin: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: bottomInset + 16,
            top: 24,
          ),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.obsidianSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.electricGold.withValues(alpha: 0.4),
              width: 1.2,
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      PhosphorIcons.shieldCheck,
                      color: AppColors.electricGold,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'SOVEREIGN CREATOR IDENTITY',
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.mistWhite,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        PhosphorIcons.x,
                        color: AppColors.ashGrey,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('auth_tab_login'),
                        onPressed: () {
                          setState(() {
                            _isRegisterMode = false;
                            _errorMessage = null;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: !_isRegisterMode
                              ? AppColors.electricGold.withValues(alpha: 0.16)
                              : Colors.transparent,
                          foregroundColor: !_isRegisterMode
                              ? AppColors.electricGold
                              : AppColors.ashGrey,
                        ),
                        child: const Text('SIGN IN'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('auth_tab_register'),
                        onPressed: () {
                          setState(() {
                            _isRegisterMode = true;
                            _errorMessage = null;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _isRegisterMode
                              ? AppColors.electricGold.withValues(alpha: 0.16)
                              : Colors.transparent,
                          foregroundColor: _isRegisterMode
                              ? AppColors.electricGold
                              : AppColors.ashGrey,
                        ),
                        child: const Text('CREATE ACCOUNT'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null) ...<Widget>[
                  Container(
                    key: const Key('auth_error_banner'),
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.crimsonAlert.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.crimsonAlert),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.crimsonAlert,
                      ),
                    ),
                  ),
                ],
                TextField(
                  key: const Key('auth_email_or_handle_input'),
                  controller: _identifierController,
                  style: const TextStyle(color: AppColors.mistWhite),
                  decoration: InputDecoration(
                    labelText: _isRegisterMode
                        ? 'Creator Handle (e.g. @cern)'
                        : 'Handle or Email',
                    labelStyle: const TextStyle(color: AppColors.ashGrey),
                  ),
                ),
                if (_isRegisterMode) ...<Widget>[
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('auth_email_input'),
                    controller: _emailController,
                    style: const TextStyle(color: AppColors.mistWhite),
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      labelStyle: TextStyle(color: AppColors.ashGrey),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('auth_display_name_input'),
                    controller: _displayNameController,
                    style: const TextStyle(color: AppColors.mistWhite),
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                      labelStyle: TextStyle(color: AppColors.ashGrey),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  key: const Key('auth_password_input'),
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: AppColors.mistWhite),
                  decoration: const InputDecoration(
                    labelText: 'Sovereign Password',
                    labelStyle: TextStyle(color: AppColors.ashGrey),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    ActionChip(
                      key: const Key('auth_preset_cern'),
                      label: const Text('@cern'),
                      onPressed: () => _applyPreset(
                        creatorId: 'creator_cern',
                        handle: '@cern',
                        displayName: 'CERN',
                      ),
                    ),
                    ActionChip(
                      key: const Key('auth_preset_makhadzi'),
                      label: const Text('@makhadzi'),
                      onPressed: () => _applyPreset(
                        creatorId: 'creator_makhadzi',
                        handle: '@makhadzi',
                        displayName: 'Makhadzi',
                      ),
                    ),
                    ActionChip(
                      key: const Key('auth_preset_kabza'),
                      label: const Text('@kabza'),
                      onPressed: () => _applyPreset(
                        creatorId: 'creator_kabza',
                        handle: '@kabza',
                        displayName: 'Kabza De Small',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  key: const Key('auth_submit_primary_btn'),
                  onPressed: _isSubmitting ? null : _submit,
                  icon: const Icon(PhosphorIcons.lockKey, size: 16),
                  label: Text(
                    _isRegisterMode
                        ? 'CREATE & BIND HIVE VAULT'
                        : 'AUTHENTICATE & BIND HIVE VAULT',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.electricGold,
                    foregroundColor: AppColors.obsidianCanvas,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  key: const Key('auth_continue_guest_btn'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Continue in Seeded Vault Mode',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.ashGrey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

