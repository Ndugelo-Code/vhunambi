import { Hono } from 'hono';
import { extractWorkerEnv, resolveRuntimeEnv } from '../config/env.js';
import { EdgePersistenceBridge } from '../db/edge_persistence_bridge.js';
import { isNodeSqliteAvailable } from '../db/vhunambi_db.js';
import { sovereignAuthMiddleware } from '../middleware/auth_middleware.js';
import { seedCoreCatalogMediaToR2 } from '../modules/synthesis/r2_media_synthesizer.js';
import { hasR2Credentials } from '../modules/synthesis/r2_storage.js';
import type { VhunambiWorkerEnv } from '../types/cloudflare_worker_types.js';

export const systemRoutes = new Hono<{ Bindings: VhunambiWorkerEnv }>();

systemRoutes.use('*', sovereignAuthMiddleware);

export interface PillarDiagnosticStatus {
  status: 'healthy' | 'degraded' | 'misconfigured';
  mode: string;
  latencyMs: number;
  summary: string;
}

systemRoutes.get('/preflight', async (c) => {
  const startTs = Date.now();
  const runtimeEnv = resolveRuntimeEnv(c);
  const workerEnv = extractWorkerEnv(c) as VhunambiWorkerEnv | undefined;
  const sqliteAvailable = isNodeSqliteAvailable();
  const engineMode = EdgePersistenceBridge.resolveActiveEngineMode(
    sqliteAvailable,
    c,
  );
  const cloudDriver = EdgePersistenceBridge.getCloudDriver(c);

  // 1. Supabase Auth & PostgreSQL / Edge Persistence Pillar
  const supabaseConfigured = cloudDriver.isConfigured();
  const supabasePillar: PillarDiagnosticStatus = {
    status: supabaseConfigured || sqliteAvailable ? 'healthy' : 'degraded',
    mode: engineMode,
    latencyMs: Math.max(1, Date.now() - startTs),
    summary: supabaseConfigured
      ? 'Supabase PostgREST & GoTrue configured'
      : sqliteAvailable
        ? 'Local Node SQLite active (Supabase cloud credentials not set)'
        : 'Edge Isolate Memory Engine active (Seeded catalog ready)',
  };

  // 2. Cloudflare R2 Zero-Egress Vault Pillar
  const hasVaultBinding = Boolean(workerEnv?.VHUNAMBI_VAULT);
  const hasS3Keys = hasR2Credentials(c);
  const r2Pillar: PillarDiagnosticStatus = {
    status: hasVaultBinding || hasS3Keys ? 'healthy' : 'degraded',
    mode: hasVaultBinding
      ? 'worker_r2_binding'
      : hasS3Keys
        ? 's3_presigned'
        : 'local_r2_proxy',
    latencyMs: 1,
    summary: `Bucket: ${runtimeEnv.R2_BUCKET} | Media Origin: ${runtimeEnv.R2_PUBLIC_BASE_URL}`,
  };

  // 3. RunPod Serverless Audio GPU (ACE-Step + Demucs + Mastering)
  const hasRunpodAudio = Boolean(
    runtimeEnv.RUNPOD_API_KEY && runtimeEnv.RUNPOD_ENDPOINT_ID,
  );
  const runpodAudioPillar: PillarDiagnosticStatus = {
    status: hasRunpodAudio ? 'healthy' : 'degraded',
    mode: hasRunpodAudio ? 'runpod_serverless_gpu' : 'mock_synthesis_worker',
    latencyMs: 1,
    summary: hasRunpodAudio
      ? `RunPod Endpoint ${runtimeEnv.RUNPOD_ENDPOINT_ID} armed`
      : 'In-process mock synthesis worker active',
  };

  // 4. RunPod Vision ComfyUI GPU
  const hasRunpodVision = Boolean(
    runtimeEnv.RUNPOD_COMFYUI_URL ||
      (runtimeEnv.RUNPOD_API_KEY && runtimeEnv.RUNPOD_COMFYUI_ENDPOINT_ID),
  );
  const runpodVisionPillar: PillarDiagnosticStatus = {
    status: hasRunpodVision ? 'healthy' : 'degraded',
    mode: hasRunpodVision ? 'comfyui_gpu' : 'deterministic_r2_fallback',
    latencyMs: 1,
    summary: hasRunpodVision
      ? 'ComfyUI 9:16 artwork & NVENC video pipeline armed'
      : 'Deterministic R2 cover/reel fallback active',
  };

  // 5. PayFast ZAR Gateway, Open-Source RunPod LLM & Durable Object WebSockets
  const hasRunpodLlm = Boolean(
    runtimeEnv.RUNPOD_LLM_URL ||
      (runtimeEnv.RUNPOD_API_KEY && runtimeEnv.RUNPOD_LLM_ENDPOINT_ID),
  );
  const hasLlmKey = Boolean(
    hasRunpodLlm || runtimeEnv.ANTHROPIC_API_KEY || runtimeEnv.GROK_API_KEY,
  );
  const hasDoBinding = Boolean(workerEnv?.GENERATION_DO);
  const paymentAndLlmPillar: PillarDiagnosticStatus = {
    status: 'healthy',
    mode: runtimeEnv.PAYFAST_SANDBOX ? 'payfast_sandbox' : 'payfast_live',
    latencyMs: 1,
    summary: `PayFast (${runtimeEnv.PAYFAST_SANDBOX ? 'Sandbox' : 'Live'}) | LLM: ${runtimeEnv.ZR_LLM_PROVIDER} (${runtimeEnv.RUNPOD_LLM_MODEL})${hasLlmKey ? '' : ' (local composer)'} | DO WS: ${hasDoBinding ? 'bound' : 'http_fallback'}`,
  };

  // 6. Webhook Callback Loopback Reachability Check
  const isLoopbackWebhook =
    runtimeEnv.WEBHOOK_BASE_URL.includes('localhost') ||
    runtimeEnv.WEBHOOK_BASE_URL.includes('127.0.0.1');
  const webhookMisconfigured = hasRunpodAudio && isLoopbackWebhook;
  const webhookPillar: PillarDiagnosticStatus = {
    status: webhookMisconfigured ? 'misconfigured' : 'healthy',
    mode: isLoopbackWebhook ? 'loopback_dev' : 'public_https_webhook',
    latencyMs: 1,
    summary: webhookMisconfigured
      ? 'WARNING: RUNPOD_API_KEY is set while WEBHOOK_BASE_URL is localhost; RunPod cannot reach loopback callbacks!'
      : `Callback target: ${runtimeEnv.WEBHOOK_BASE_URL}/v1/webhooks/ace-step`,
  };

  const allStatuses = [
    supabasePillar.status,
    r2Pillar.status,
    runpodAudioPillar.status,
    runpodVisionPillar.status,
    paymentAndLlmPillar.status,
    webhookPillar.status,
  ];
  const aggregateStatus: 'healthy' | 'degraded' | 'misconfigured' =
    allStatuses.includes('misconfigured')
      ? 'misconfigured'
      : allStatuses.every((s) => s === 'healthy')
        ? 'healthy'
        : 'degraded';

  return c.json({
    status: aggregateStatus,
    environment: runtimeEnv.NODE_ENV,
    persistenceEngine: engineMode,
    pillars: {
      supabase: supabasePillar,
      r2Vault: r2Pillar,
      runpodAudio: runpodAudioPillar,
      runpodVision: runpodVisionPillar,
      paymentAndLlm: paymentAndLlmPillar,
      webhookCallback: webhookPillar,
    },
    timestamp: new Date().toISOString(),
  });
});

systemRoutes.post('/seed-r2-media', async (c) => {
  const rawLimit = Number.parseInt(c.req.query('limit') ?? '', 10);
  const rawOffset = Number.parseInt(c.req.query('offset') ?? '0', 10);
  const result = await seedCoreCatalogMediaToR2(c, {
    offset: Number.isFinite(rawOffset) ? rawOffset : 0,
    ...(Number.isFinite(rawLimit) && rawLimit > 0 ? { limit: rawLimit } : {}),
  });
  return c.json({
    success: true,
    bucket: resolveRuntimeEnv(c).R2_BUCKET,
    mediaOrigin: resolveRuntimeEnv(c).R2_PUBLIC_BASE_URL,
    ...result,
    timestamp: new Date().toISOString(),
  });
});

