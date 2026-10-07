import { AwsClient } from 'aws4fetch';
import { env } from '../../config/env.js';

let _client: AwsClient | null = null;

export function hasR2Credentials(): boolean {
  return Boolean(env.R2_ACCESS_KEY_ID && env.R2_SECRET_ACCESS_KEY && env.R2_ENDPOINT);
}

function getR2Client(): AwsClient | null {
  if (!hasR2Credentials()) return null;

  if (!_client) {
    _client = new AwsClient({
      accessKeyId: env.R2_ACCESS_KEY_ID!,
      secretAccessKey: env.R2_SECRET_ACCESS_KEY!,
      service: 's3',
      region: 'auto',
    });
  }

  return _client;
}

export async function getPresignedPutUrl(key: string, expirySeconds = 3600): Promise<string> {
  const client = getR2Client();
  if (!client || !env.R2_ENDPOINT) {
    // Return mock endpoint for local offline development
    return `http://localhost:${env.PORT}/mock-storage/${key}`;
  }

  const endpoint = env.R2_ENDPOINT.replace(/\/$/, '');
  const url = new URL(`${endpoint}/${env.R2_BUCKET}/${key}`);
  url.searchParams.set('X-Amz-Expires', String(expirySeconds));

  const signed = await client.sign(
    new Request(url.toString(), {
      method: 'PUT',
    }),
    { aws: { signQuery: true } },
  );

  return signed.url;
}

export async function getPresignedGetUrl(key: string, expirySeconds = 86400): Promise<string> {
  const client = getR2Client();
  if (!client || !env.R2_ENDPOINT) {
    // Return mock endpoint for local offline development
    return `http://localhost:${env.PORT}/mock-storage/${key}`;
  }

  const endpoint = env.R2_ENDPOINT.replace(/\/$/, '');
  const url = new URL(`${endpoint}/${env.R2_BUCKET}/${key}`);
  url.searchParams.set('X-Amz-Expires', String(expirySeconds));

  const signed = await client.sign(
    new Request(url.toString(), {
      method: 'GET',
    }),
    { aws: { signQuery: true } },
  );

  return signed.url;
}
