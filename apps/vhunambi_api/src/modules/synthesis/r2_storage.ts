import { AwsClient } from 'aws4fetch';
import type { Context } from 'hono';
import { extractWorkerEnv, resolveRuntimeEnv } from '../../config/env.js';
import type { VhunambiWorkerEnv } from '../../types/cloudflare_worker_types.js';

export function hasR2Credentials(
  cOrEnv?: Context | VhunambiWorkerEnv | Record<string, unknown> | null,
): boolean {
  const runtimeEnv = resolveRuntimeEnv(cOrEnv);
  return Boolean(
    runtimeEnv.R2_ACCESS_KEY_ID &&
    runtimeEnv.R2_SECRET_ACCESS_KEY &&
    runtimeEnv.R2_ENDPOINT,
  );
}

function createR2Client(
  cOrEnv?: Context | VhunambiWorkerEnv | Record<string, unknown> | null,
): AwsClient | null {
  const runtimeEnv = resolveRuntimeEnv(cOrEnv);
  if (
    !runtimeEnv.R2_ACCESS_KEY_ID ||
    !runtimeEnv.R2_SECRET_ACCESS_KEY ||
    !runtimeEnv.R2_ENDPOINT
  ) {
    return null;
  }

  return new AwsClient({
    accessKeyId: runtimeEnv.R2_ACCESS_KEY_ID,
    secretAccessKey: runtimeEnv.R2_SECRET_ACCESS_KEY,
    service: 's3',
    region: 'auto',
  });
}

export async function getPresignedPutUrl(
  objectKey: string,
  contentTypeOrExpiry: string | number = 'audio/mpeg',
  expiresInSeconds = 3600,
  cOrEnv?: Context | VhunambiWorkerEnv | Record<string, unknown> | null,
): Promise<string> {
  const contentType =
    typeof contentTypeOrExpiry === 'string'
      ? contentTypeOrExpiry
      : 'audio/mpeg';
  const effectiveExpires =
    typeof contentTypeOrExpiry === 'number'
      ? contentTypeOrExpiry
      : expiresInSeconds;

  const runtimeEnv = resolveRuntimeEnv(cOrEnv);
  const client = createR2Client(cOrEnv);
  const cleanKey = objectKey.replace(/^\/+/, '');
  const bucket = runtimeEnv.R2_BUCKET || 'vhunambi-vault';

  if (!client || !runtimeEnv.R2_ENDPOINT) {
    return `${runtimeEnv.R2_PUBLIC_BASE_URL.replace(/\/+$/, '')}/${cleanKey}?presigned=put&expires=${effectiveExpires}`;
  }

  const endpoint = runtimeEnv.R2_ENDPOINT.replace(/\/+$/, '');
  const url = new URL(`${endpoint}/${bucket}/${cleanKey}`);
  url.searchParams.set('X-Amz-Expires', String(effectiveExpires));

  const signed = await client.sign(
    new Request(url.toString(), {
      method: 'PUT',
      headers: { 'Content-Type': contentType },
    }),
    { aws: { signQuery: true } },
  );

  return signed.url;
}

export async function getPresignedGetUrl(
  objectKey: string,
  expiresInSeconds = 86400,
  cOrEnv?: Context | VhunambiWorkerEnv | Record<string, unknown> | null,
): Promise<string> {
  const runtimeEnv = resolveRuntimeEnv(cOrEnv);
  const client = createR2Client(cOrEnv);
  const cleanKey = objectKey.replace(/^\/+/, '');
  const bucket = runtimeEnv.R2_BUCKET || 'vhunambi-vault';

  if (!client || !runtimeEnv.R2_ENDPOINT) {
    return `${runtimeEnv.R2_PUBLIC_BASE_URL.replace(/\/+$/, '')}/${cleanKey}?presigned=get&expires=${expiresInSeconds}`;
  }

  const endpoint = runtimeEnv.R2_ENDPOINT.replace(/\/+$/, '');
  const url = new URL(`${endpoint}/${bucket}/${cleanKey}`);
  url.searchParams.set('X-Amz-Expires', String(expiresInSeconds));

  const signed = await client.sign(
    new Request(url.toString(), {
      method: 'GET',
    }),
    { aws: { signQuery: true } },
  );

  return signed.url;
}

export async function fetchR2S3Object(
  objectKey: string,
  cOrEnv?: Context | VhunambiWorkerEnv | Record<string, unknown> | null,
): Promise<Response | null> {
  const runtimeEnv = resolveRuntimeEnv(cOrEnv);
  const client = createR2Client(cOrEnv);
  if (!client || !runtimeEnv.R2_ENDPOINT) {
    return null;
  }
  const cleanKey = objectKey.replace(/^\/+/, '');
  const bucket = runtimeEnv.R2_BUCKET || 'vhunambi-vault';
  const endpoint = runtimeEnv.R2_ENDPOINT.replace(/\/+$/, '');
  const url = `${endpoint}/${bucket}/${cleanKey}`;
  return client.fetch(url, { method: 'GET' });
}

export interface InMemoryR2Object {
  key: string;
  bytes: Uint8Array;
  contentType: string;
  etag: string;
  uploadedAt: string;
}

const inMemoryR2Objects = new Map<string, InMemoryR2Object>();

export function getInMemoryR2Object(key: string): InMemoryR2Object | null {
  const cleanKey = key.replace(/^\/+/, '');
  return inMemoryR2Objects.get(cleanKey) ?? null;
}

export async function uploadBytesToR2(
  objectKey: string,
  data: Uint8Array | ArrayBuffer | string,
  contentType = 'application/octet-stream',
  cOrEnv?: Context | VhunambiWorkerEnv | Record<string, unknown> | null,
): Promise<{ key: string; url: string; etag: string }> {
  const cleanKey = objectKey.replace(/^\/+/, '');
  const bytes =
    typeof data === 'string'
      ? new TextEncoder().encode(data)
      : data instanceof Uint8Array
        ? data
        : new Uint8Array(data);
  const etag = `"r2_${bytes.byteLength}_${Date.now()}"`;

  // Always cache in process memory so immediate local/test GET /r2/:key succeeds
  inMemoryR2Objects.set(cleanKey, {
    key: cleanKey,
    bytes,
    contentType,
    etag,
    uploadedAt: new Date().toISOString(),
  });

  const workerEnv = extractWorkerEnv(cOrEnv) as VhunambiWorkerEnv | undefined;
  if (workerEnv?.VHUNAMBI_VAULT) {
    await workerEnv.VHUNAMBI_VAULT.put(cleanKey, bytes, {
      httpMetadata: { contentType },
    });
  } else {
    const client = createR2Client(cOrEnv);
    const runtimeEnv = resolveRuntimeEnv(cOrEnv);
    if (client && runtimeEnv.R2_ENDPOINT) {
      const bucket = runtimeEnv.R2_BUCKET || 'vhunambi-vault';
      const endpoint = runtimeEnv.R2_ENDPOINT.replace(/\/+$/, '');
      await client.fetch(`${endpoint}/${bucket}/${cleanKey}`, {
        method: 'PUT',
        headers: { 'Content-Type': contentType },
        body: bytes.slice().buffer as ArrayBuffer,
      });
    }
  }

  const runtimeEnv = resolveRuntimeEnv(cOrEnv);
  const base = runtimeEnv.R2_PUBLIC_BASE_URL.replace(/\/+$/, '');
  return {
    key: cleanKey,
    url: `${base}/${cleanKey}`,
    etag,
  };
}

export async function deleteR2Object(
  objectKey: string,
  cOrEnv?: Context | VhunambiWorkerEnv | Record<string, unknown> | null,
): Promise<boolean> {
  const cleanKey = objectKey.replace(/^\/+/, '');
  inMemoryR2Objects.delete(cleanKey);
  const workerEnv = extractWorkerEnv(cOrEnv) as VhunambiWorkerEnv | undefined;
  if (workerEnv?.VHUNAMBI_VAULT) {
    await workerEnv.VHUNAMBI_VAULT.delete(cleanKey);
    return true;
  }

  const runtimeEnv = resolveRuntimeEnv(cOrEnv);
  const client = createR2Client(cOrEnv);
  if (!client || !runtimeEnv.R2_ENDPOINT) {
    return true;
  }
  const bucket = runtimeEnv.R2_BUCKET || 'vhunambi-vault';
  const endpoint = runtimeEnv.R2_ENDPOINT.replace(/\/+$/, '');
  const url = `${endpoint}/${bucket}/${cleanKey}`;
  const res = await client.fetch(url, { method: 'DELETE' });
  return res.ok;
}
