import {
  createHash,
  createHmac,
  randomBytes,
  scryptSync,
  timingSafeEqual,
} from 'node:crypto';

export interface SovereignJwtClaims {
  sub: string;             // user_id (e.g. 'usr_cern') or GoTrue UUID
  cid: string;             // canonical creator_id (e.g. 'creator_cern')
  hdl: string;             // normalized handle (e.g. '@cern')
  sid: string;             // session_id (e.g. 'ses_...')
  role: string;            // 'creator' | 'admin'
  iat: number;             // issued at (seconds)
  exp: number;             // expires at (seconds)
  isGoTrueToken?: boolean; // true when normalized from Supabase GoTrue claims
}

const SCRYPT_N = 16384;
const SCRYPT_R = 8;
const SCRYPT_P = 1;
const SCRYPT_KEYLEN = 64;

const DEFAULT_DEV_JWT_SECRET =
  'vhunambi_sovereign_phase61_jwt_hmac_sha256_secret_key_2026_za';

export function resolveJwtSecret(secretOverride?: string): string {
  const explicit = secretOverride?.trim();
  if (explicit && explicit.length >= 32) {
    return explicit;
  }
  const fromEnv =
    (typeof process !== 'undefined'
      ? process.env.VHUNAMBI_JWT_SECRET?.trim() ||
      process.env.SUPABASE_JWT_SECRET?.trim()
      : undefined) ?? '';
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

function isCloudflareWorkerEdgeRuntime(): boolean {
  const g = globalThis as unknown as {
    navigator?: { userAgent?: string };
    WebSocketPair?: unknown;
  };
  return (
    g.navigator?.userAgent === 'Cloudflare-Workers' ||
    typeof g.WebSocketPair === 'function'
  );
}

/**
 * Memory-hard password hashing via node:crypto scryptSync.
 * Uses N=16384 in Node/SQLite and N=1024 in Cloudflare Workers edge isolates
 * to stay comfortably inside the 10ms Free Plan Worker CPU budget.
 * Format: scrypt$<N>$8$1$<saltHex>$<derivedKeyHex>
 */
export function hashPassword(password: string, explicitSaltHex?: string): string {
  const saltBuf = explicitSaltHex
    ? Buffer.from(explicitSaltHex, 'hex')
    : randomBytes(16);
  const effectiveN = isCloudflareWorkerEdgeRuntime() ? 1024 : SCRYPT_N;
  const derivedKey = scryptSync(password, saltBuf, SCRYPT_KEYLEN, {
    N: effectiveN,
    r: SCRYPT_R,
    p: SCRYPT_P,
  });
  return `scrypt$${effectiveN}$${SCRYPT_R}$${SCRYPT_P}$${saltBuf.toString('hex')}$${derivedKey.toString('hex')}`;
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
  nowSeconds = Math.floor(Date.now() / 1000),
  secretOverride?: string,
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

  const signature = createHmac('sha256', resolveJwtSecret(secretOverride))
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

function normalizeAndValidateJwtClaims(
  raw: Record<string, unknown>,
  nowSeconds: number,
): JwtVerificationResult {
  if (!raw || typeof raw.sub !== 'string' || typeof raw.exp !== 'number') {
    return { valid: false, reason: 'MALFORMED' };
  }

  const appMeta = (raw.app_metadata ?? {}) as Record<string, unknown>;
  const userMeta = (raw.user_metadata ?? {}) as Record<string, unknown>;

  const rawCid =
    typeof raw.cid === 'string'
      ? raw.cid
      : typeof appMeta.creator_id === 'string'
        ? appMeta.creator_id
        : typeof userMeta.creator_id === 'string'
          ? userMeta.creator_id
          : undefined;

  if (!rawCid || rawCid.trim().length === 0) {
    return { valid: false, reason: 'MALFORMED' };
  }

  const isGoTrueToken = typeof raw.cid !== 'string';

  const rawSid =
    typeof raw.sid === 'string'
      ? raw.sid
      : typeof raw.session_id === 'string'
        ? raw.session_id
        : isGoTrueToken
          ? `gotrue_${raw.sub}`
          : undefined;

  if (!rawSid || rawSid.trim().length === 0) {
    return { valid: false, reason: 'MALFORMED' };
  }

  const normalizedCid =
    rawCid.trim() === 'creator_blackcoffee'
      ? 'creator_black_coffee'
      : rawCid.trim();

  const rawHdl =
    typeof raw.hdl === 'string'
      ? raw.hdl
      : typeof appMeta.handle === 'string'
        ? appMeta.handle
        : typeof userMeta.handle === 'string'
          ? userMeta.handle
          : `@${normalizedCid.replace(/^creator_/, '')}`;

  const rawRole =
    typeof appMeta.vhunambi_role === 'string'
      ? appMeta.vhunambi_role
      : raw.role === 'authenticated' || typeof raw.role !== 'string'
        ? 'creator'
        : String(raw.role);

  if (nowSeconds >= raw.exp) {
    return { valid: false, reason: 'EXPIRED' };
  }

  return {
    valid: true,
    claims: {
      sub: raw.sub,
      cid: normalizedCid,
      hdl: rawHdl.startsWith('@') ? rawHdl : `@${rawHdl}`,
      sid: rawSid,
      role: rawRole,
      iat: typeof raw.iat === 'number' ? raw.iat : nowSeconds,
      exp: raw.exp,
      isGoTrueToken,
    },
  };
}

export interface JwkPublicKey {
  kty?: string;
  crv?: string;
  x?: string;
  y?: string;
  kid?: string;
  alg?: string;
  use?: string;
  ext?: boolean;
  key_ops?: string[];
  [key: string]: unknown;
}

interface CachedJwksEntry {
  keys: JwkPublicKey[];
  fetchedAtMs: number;
}

const jwksCache = new Map<string, CachedJwksEntry>();
const JWKS_TTL_MS = 5 * 60 * 1000;

async function resolveEs256PublicKeyFromSupabaseJwks(
  supabaseUrl: string,
  kid?: string,
  forceRefresh = false,
): Promise<JwkPublicKey[]> {
  const cleanUrl = supabaseUrl.replace(/\/+$/, '');
  const now = Date.now();
  const cached = jwksCache.get(cleanUrl);
  if (
    !forceRefresh &&
    cached &&
    now - cached.fetchedAtMs < JWKS_TTL_MS &&
    (!kid || cached.keys.some((k) => k.kid === kid))
  ) {
    return cached.keys;
  }

  const res = await fetch(`${cleanUrl}/auth/v1/.well-known/jwks.json`, {
    method: 'GET',
    headers: { Accept: 'application/json' },
  });
  if (!res.ok) {
    return cached?.keys ?? [];
  }
  const body = (await res.json()) as {
    keys?: JwkPublicKey[];
  };
  const keys = Array.isArray(body?.keys) ? body.keys : [];
  jwksCache.set(cleanUrl, { keys, fetchedAtMs: now });
  return keys;
}

/**
 * Verifies an HS256 JWT in constant time and normalizes both Sovereign
 * Phase 61 claims and Supabase GoTrue JWT claims (`app_metadata` / `user_metadata`).
 */
export function verifyAccessJwt(
  token: string,
  secretOrNow?: string | number,
  nowSecondsOverride?: number,
): JwtVerificationResult {
  try {
    const secretOverride =
      typeof secretOrNow === 'string' ? secretOrNow : undefined;
    const nowSeconds =
      typeof secretOrNow === 'number'
        ? secretOrNow
        : (nowSecondsOverride ?? Math.floor(Date.now() / 1000));

    const segments = token.trim().split('.');
    if (segments.length !== 3) {
      return { valid: false, reason: 'MALFORMED' };
    }
    const [encodedHeader, encodedPayload, encodedSignature] = segments;
    const signingInput = `${encodedHeader}.${encodedPayload}`;
    const secret = resolveJwtSecret(secretOverride);

    const expectedSig = createHmac('sha256', secret)
      .update(signingInput, 'utf8')
      .digest();
    const actualSig = base64UrlDecodeToBuffer(encodedSignature);

    if (
      expectedSig.length !== actualSig.length ||
      !timingSafeEqual(expectedSig, actualSig)
    ) {
      return { valid: false, reason: 'INVALID_SIGNATURE' };
    }

    const headerObj = JSON.parse(
      base64UrlDecodeToBuffer(encodedHeader).toString('utf8'),
    ) as { alg?: string };
    if (headerObj.alg !== 'HS256') {
      return { valid: false, reason: 'MALFORMED' };
    }

    const raw = JSON.parse(
      base64UrlDecodeToBuffer(encodedPayload).toString('utf8'),
    ) as Record<string, unknown>;

    return normalizeAndValidateJwtClaims(raw, nowSeconds);
  } catch {
    return { valid: false, reason: 'MALFORMED' };
  }
}

/**
 * Verifies both HS256 (Sovereign / Legacy Supabase) and ES256 (Supabase ECC P-256
 * Asymmetric JWKS) JWTs across Node.js and Cloudflare Workers isolates.
 */
export async function verifyAccessJwtAsync(
  token: string,
  options?: {
    secret?: string;
    supabaseUrl?: string;
    nowSeconds?: number;
    jwksKeysOverride?: JwkPublicKey[];
  },
): Promise<JwtVerificationResult> {
  try {
    const segments = token.trim().split('.');
    if (segments.length !== 3) {
      return { valid: false, reason: 'MALFORMED' };
    }
    const [encodedHeader, encodedPayload, encodedSignature] = segments;
    const headerObj = JSON.parse(
      base64UrlDecodeToBuffer(encodedHeader).toString('utf8'),
    ) as { alg?: string; kid?: string };

    if (!headerObj?.alg || headerObj.alg === 'HS256') {
      return verifyAccessJwt(token, options?.secret, options?.nowSeconds);
    }

    if (headerObj.alg !== 'ES256') {
      return { valid: false, reason: 'MALFORMED' };
    }

    const nowSeconds = options?.nowSeconds ?? Math.floor(Date.now() / 1000);
    const subtle = globalThis.crypto?.subtle;
    if (!subtle) {
      return { valid: false, reason: 'INVALID_SIGNATURE' };
    }

    let candidateKeys = options?.jwksKeysOverride;
    if (!candidateKeys || candidateKeys.length === 0) {
      if (!options?.supabaseUrl) {
        return { valid: false, reason: 'INVALID_SIGNATURE' };
      }
      candidateKeys = await resolveEs256PublicKeyFromSupabaseJwks(
        options.supabaseUrl,
        headerObj.kid,
      );
      if (
        headerObj.kid &&
        !candidateKeys.some((k) => k.kid === headerObj.kid)
      ) {
        candidateKeys = await resolveEs256PublicKeyFromSupabaseJwks(
          options.supabaseUrl,
          headerObj.kid,
          true,
        );
      }
    }

    const filteredKeys = headerObj.kid
      ? candidateKeys.filter((k) => !k.kid || k.kid === headerObj.kid)
      : candidateKeys;
    const keysToTry = filteredKeys.length > 0 ? filteredKeys : candidateKeys;
    if (!keysToTry || keysToTry.length === 0) {
      return { valid: false, reason: 'INVALID_SIGNATURE' };
    }

    const signingBytes = new TextEncoder().encode(
      `${encodedHeader}.${encodedPayload}`,
    );
    const sigBytes = new Uint8Array(base64UrlDecodeToBuffer(encodedSignature));

    let verified = false;
    for (const jwk of keysToTry) {
      try {
        const key = await subtle.importKey(
          'jwk',
          jwk,
          { name: 'ECDSA', namedCurve: 'P-256' },
          false,
          ['verify'],
        );
        const ok = await subtle.verify(
          { name: 'ECDSA', hash: 'SHA-256' },
          key,
          sigBytes,
          signingBytes,
        );
        if (ok) {
          verified = true;
          break;
        }
      } catch {
        // Try next candidate JWK
      }
    }

    if (!verified) {
      return { valid: false, reason: 'INVALID_SIGNATURE' };
    }

    const raw = JSON.parse(
      base64UrlDecodeToBuffer(encodedPayload).toString('utf8'),
    ) as Record<string, unknown>;
    return normalizeAndValidateJwtClaims(raw, nowSeconds);
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

