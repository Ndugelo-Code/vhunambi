import type { Context } from 'hono';
import type { VhunambiWorkerEnv } from '../types/cloudflare_worker_types.js';

// Load dotenv lazily only in non-test, non-Worker Node.js environments
const globalRuntime = globalThis as unknown as {
  navigator?: { userAgent?: string };
  WebSocketPair?: unknown;
};
const isWorkerRuntime =
  globalRuntime.navigator?.userAgent === 'Cloudflare-Workers' ||
  typeof globalRuntime.WebSocketPair === 'function';

const isTestExecution =
  typeof process !== 'undefined' &&
  (process.env?.NODE_ENV === 'test' ||
    process.env?.VHUNAMBI_SKIP_DOTENV === 'true' ||
    (Array.isArray(process.argv) &&
      process.argv.some((arg) =>
        /(?:^|[\\/])test(?:[\\/]|$)|\.test\.[cm]?[jt]s$/i.test(arg),
      )));

try {
  const getter = (
    process as unknown as { getBuiltinModule?: (id: string) => unknown }
  )?.getBuiltinModule;
  if (!isWorkerRuntime && typeof getter === 'function' && !isTestExecution) {
    import('dotenv')
      .then((d) => d.default?.config())
      .catch(() => { });
  }
} catch {
  // Ignore on Cloudflare Workers
}

export interface RuntimeEnvConfig {
  PORT: number;
  NODE_ENV: string;
  VHUNAMBI_AUTH_MODE: string;
  VHUNAMBI_JWT_SECRET: string;
  SUPABASE_URL: string;
  SUPABASE_ANON_KEY: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  SUPABASE_JWT_SECRET: string;
  ZR_LLM_PROVIDER: 'claude' | 'grok' | 'mock';
  ANTHROPIC_API_KEY: string;
  GROK_API_KEY: string;
  R2_ACCESS_KEY_ID: string;
  R2_SECRET_ACCESS_KEY: string;
  R2_ENDPOINT: string;
  R2_BUCKET: string;
  R2_PUBLIC_BASE_URL: string;
  RUNPOD_API_KEY: string;
  RUNPOD_ENDPOINT_ID: string;
  RUNPOD_COMFYUI_URL: string;
  RUNPOD_COMFYUI_ENDPOINT_ID: string;
  ZR_WEBHOOK_SECRET: string;
  WEBHOOK_BASE_URL: string;
  PAYFAST_MERCHANT_ID: string;
  PAYFAST_MERCHANT_KEY: string;
  PAYFAST_PASSPHRASE: string;
  PAYFAST_SANDBOX: boolean;
}

export type AppEnv = RuntimeEnvConfig;

const mutableEnvOverrides: Record<string, string | number | boolean> = {};

function readString(
  workerEnv: Record<string, unknown> | undefined,
  key: string,
  fallback: string,
): string {
  const fromWorker = workerEnv?.[key];
  if (typeof fromWorker === 'string' && fromWorker.trim().length > 0) {
    return fromWorker.trim();
  }
  if (Object.prototype.hasOwnProperty.call(mutableEnvOverrides, key)) {
    return String(mutableEnvOverrides[key] ?? '').trim();
  }
  const fromProc =
    typeof process !== 'undefined' ? process.env?.[key] : undefined;
  if (typeof fromProc === 'string' && fromProc.trim().length > 0) {
    return fromProc.trim();
  }
  return fallback;
}

export function extractWorkerEnv(
  cOrEnv?: Context | VhunambiWorkerEnv | Record<string, unknown> | null,
): Record<string, unknown> | undefined {
  if (!cOrEnv || typeof cOrEnv !== 'object') return undefined;
  if ('env' in cOrEnv && cOrEnv.env && typeof cOrEnv.env === 'object') {
    return cOrEnv.env as Record<string, unknown>;
  }
  return cOrEnv as Record<string, unknown>;
}

export function resolveRuntimeEnv(
  cOrEnv?: Context | VhunambiWorkerEnv | Record<string, unknown> | null,
): RuntimeEnvConfig {
  const w = extractWorkerEnv(cOrEnv);
  const portRaw = readString(w, 'PORT', '3000');
  const jwtSecret =
    readString(w, 'VHUNAMBI_JWT_SECRET', '') ||
    readString(w, 'SUPABASE_JWT_SECRET', '') ||
    'vhunambi_sovereign_phase61_jwt_hmac_sha256_secret_key_2026_za';

  return {
    PORT: Number.parseInt(portRaw, 10) || 3000,
    NODE_ENV: readString(w, 'NODE_ENV', 'development'),
    VHUNAMBI_AUTH_MODE: readString(w, 'VHUNAMBI_AUTH_MODE', 'permissive'),
    VHUNAMBI_JWT_SECRET: jwtSecret,
    SUPABASE_URL: readString(w, 'SUPABASE_URL', ''),
    SUPABASE_ANON_KEY: readString(w, 'SUPABASE_ANON_KEY', ''),
    SUPABASE_SERVICE_ROLE_KEY: readString(w, 'SUPABASE_SERVICE_ROLE_KEY', ''),
    SUPABASE_JWT_SECRET: readString(w, 'SUPABASE_JWT_SECRET', jwtSecret),
    ZR_LLM_PROVIDER: readString(w, 'ZR_LLM_PROVIDER', 'claude') as
      | 'claude'
      | 'grok'
      | 'mock',
    ANTHROPIC_API_KEY: readString(w, 'ANTHROPIC_API_KEY', ''),
    GROK_API_KEY: readString(w, 'GROK_API_KEY', ''),
    R2_ACCESS_KEY_ID: readString(w, 'R2_ACCESS_KEY_ID', ''),
    R2_SECRET_ACCESS_KEY: readString(w, 'R2_SECRET_ACCESS_KEY', ''),
    R2_ENDPOINT: readString(w, 'R2_ENDPOINT', ''),
    R2_BUCKET: readString(w, 'R2_BUCKET', 'vhunambi-vault'),
    R2_PUBLIC_BASE_URL: readString(
      w,
      'R2_PUBLIC_BASE_URL',
      'http://localhost:3000/r2',
    ),
    RUNPOD_API_KEY: readString(w, 'RUNPOD_API_KEY', ''),
    RUNPOD_ENDPOINT_ID: readString(w, 'RUNPOD_ENDPOINT_ID', ''),
    RUNPOD_COMFYUI_URL: readString(w, 'RUNPOD_COMFYUI_URL', ''),
    RUNPOD_COMFYUI_ENDPOINT_ID: readString(w, 'RUNPOD_COMFYUI_ENDPOINT_ID', ''),
    ZR_WEBHOOK_SECRET: readString(
      w,
      'ZR_WEBHOOK_SECRET',
      'dev_webhook_secret_vhunambi_2026',
    ),
    WEBHOOK_BASE_URL: readString(w, 'WEBHOOK_BASE_URL', 'http://localhost:3000'),
    PAYFAST_MERCHANT_ID: readString(w, 'PAYFAST_MERCHANT_ID', '10000100'),
    PAYFAST_MERCHANT_KEY: readString(w, 'PAYFAST_MERCHANT_KEY', '46f0cd694581a'),
    PAYFAST_PASSPHRASE: readString(
      w,
      'PAYFAST_PASSPHRASE',
      'vhunambi_payfast_passphrase_2026',
    ),
    PAYFAST_SANDBOX: readString(w, 'PAYFAST_SANDBOX', 'true') !== 'false',
  };
}

/**
 * Rewrites dead legacy domains (`r2.vhunambi.com`, `cdn.vhunambi.com`,
 * `cdn.vhunambi.za`, `assets.vhunambi.com`, `/mock-storage/*`) to `R2_PUBLIC_BASE_URL`.
 */
export function resolveMediaUrl(
  rawUrlOrKey: string,
  cOrEnv?: Context | VhunambiWorkerEnv | Record<string, unknown> | null,
): string {
  const trimmed = (rawUrlOrKey ?? '').trim();
  if (!trimmed) return '';
  const runtimeEnv = resolveRuntimeEnv(cOrEnv);
  const base = runtimeEnv.R2_PUBLIC_BASE_URL.replace(/\/+$/, '');

  if (trimmed.startsWith('/mock-storage/')) {
    const key = trimmed.replace(/^\/mock-storage\//, '');
    return `${base}/${key}`;
  }
  const legacyDomainMatch = trimmed.match(
    /^https?:\/\/(?:r2\.vhunambi\.com|cdn\.vhunambi\.com|cdn\.vhunambi\.za|assets\.vhunambi\.com)\/(.+)$/i,
  );
  if (legacyDomainMatch) {
    return `${base}/${legacyDomainMatch[1]}`;
  }
  if (
    !trimmed.startsWith('http://') &&
    !trimmed.startsWith('https://') &&
    !trimmed.startsWith('/')
  ) {
    return `${base}/${trimmed}`;
  }
  return trimmed;
}

export const env: RuntimeEnvConfig = new Proxy({} as RuntimeEnvConfig, {
  get(_target, prop: keyof RuntimeEnvConfig) {
    return resolveRuntimeEnv()[prop];
  },
  set(_target, prop: string | symbol, value: unknown) {
    if (typeof prop === 'string') {
      if (value === undefined) {
        mutableEnvOverrides[prop] = '';
      } else {
        mutableEnvOverrides[prop] = value as string | number | boolean;
      }
    }
    return true;
  },
});
