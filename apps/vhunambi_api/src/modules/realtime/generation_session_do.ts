import type {
  CfDurableObjectState,
  VhunambiWorkerEnv,
} from '../../types/cloudflare_worker_types.js';

export interface GenerationPipelineEventPayload {
  generationId: string;
  status: string;
  step?: string;
  progressPct?: number;
  trackTitle?: string;
  genre?: string;
  language?: string;
  durationSec?: number;
  masterMp3Url?: string;
  stemsZipUrl?: string;
  stemUrls?: Record<string, string>;
  manifestUrl?: string;
  coverUrl?: string;
  lyrics?: string;
  error?: string;
  timestamp?: number;
}

export function buildDualDialectPipelineEventFrame(
  payload: GenerationPipelineEventPayload,
): Record<string, unknown> {
  const rawStep =
    payload.step ??
    (payload.status === 'succeeded' || payload.status === 'completed'
      ? 'ready'
      : payload.status === 'failed'
        ? 'failed'
        : 'synthesizing');
  const pct100 =
    typeof payload.progressPct === 'number' ? payload.progressPct : 0;
  const progressFraction =
    pct100 > 1 ? Math.min(1, pct100 / 100) : Math.max(0, pct100);

  let stepIndex = 1;
  let statusMessage = 'Starting synthesis pipeline...';
  if (rawStep === 'writing_lyrics') {
    stepIndex = 2;
    statusMessage = 'Composing authentic dialect lyrics...';
  } else if (
    rawStep === 'producing_beat' ||
    rawStep === 'synthesizing' ||
    rawStep === 'separating_stems' ||
    rawStep === 'uploading' ||
    rawStep === 'mastering'
  ) {
    stepIndex = 3;
    statusMessage = 'Rendering African rhythm and audio stems...';
  } else if (
    rawStep === 'ready' ||
    rawStep === 'completed' ||
    payload.status === 'succeeded' ||
    payload.status === 'completed'
  ) {
    stepIndex = 4;
    statusMessage = 'Studio Master Ready';
  } else if (rawStep === 'failed' || payload.status === 'failed') {
    stepIndex = 0;
    statusMessage = payload.error || 'Synthesis failed.';
  }

  const completedTrack =
    (rawStep === 'ready' ||
      rawStep === 'completed' ||
      payload.status === 'succeeded' ||
      payload.status === 'completed') &&
    payload.masterMp3Url
      ? {
          id: payload.generationId,
          title: payload.trackTitle ?? 'Studio Master',
          genre: payload.genre ?? 'Amapiano',
          language: payload.language ?? 'English',
          master_mp3_url: payload.masterMp3Url,
          masterMp3Url: payload.masterMp3Url,
          stems_url: payload.stemsZipUrl ?? null,
          stemsZipUrl: payload.stemsZipUrl ?? null,
          stem_urls: payload.stemUrls ?? null,
          stemUrls: payload.stemUrls ?? null,
          manifest_url: payload.manifestUrl ?? null,
          cover_url: payload.coverUrl ?? null,
          coverUrl: payload.coverUrl ?? null,
          lyrics: payload.lyrics ?? null,
          duration_seconds: payload.durationSec ?? 180,
        }
      : null;

  return {
    type: 'pipeline_event',
    // CamelCase (Phase 62 DO contract)
    ...payload,
    timestamp: payload.timestamp ?? Date.now(),
    // Snake_case (Flutter PipelineSocketEvent.fromJson contract)
    generation_id: payload.generationId,
    step: rawStep,
    step_index: stepIndex,
    progress_percent: progressFraction,
    status_message: statusMessage,
    completed_track: completedTrack,
  };
}

/**
 * Cloudflare Durable Object managing realtime WebSocket connections for
 * `/ws/generation?id=<generationId>`. Handles `PING` -> `PONG` heartbeats
 * and broadcasts `pipeline_event` frames pushed from `/v1/webhooks/ace-step`.
 */
export class GenerationSessionDO {
  private readonly state: CfDurableObjectState;
  private readonly sockets = new Set<WebSocket>();
  private lastEvent: GenerationPipelineEventPayload | null = null;

  constructor(state: CfDurableObjectState, _env?: VhunambiWorkerEnv) {
    this.state = state;
  }

  public async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    const generationId = url.searchParams.get('id') || 'unknown';

    if (request.method === 'POST' && url.pathname.endsWith('/internal/broadcast')) {
      const payload = (await request.json()) as GenerationPipelineEventPayload;
      this.lastEvent = payload;
      await this.state.storage.put('last_event', payload);
      const frame = JSON.stringify(buildDualDialectPipelineEventFrame(payload));
      this.broadcastFrame(frame);
      return new Response(
        JSON.stringify({ delivered: true, activeConnections: this.countSockets() }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      );
    }

    if (request.method === 'POST' && url.pathname.endsWith('/internal/frame')) {
      const incoming = (await request.json()) as { type?: string };
      if (incoming.type === 'PING') {
        return new Response(
          JSON.stringify({ type: 'PONG', generationId, timestamp: Date.now() }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        );
      }
    }

    const upgradeHeader = request.headers.get('Upgrade');
    const WebSocketPairCtor = (
      globalThis as unknown as {
        WebSocketPair?: new () => { 0: WebSocket; 1: WebSocket };
      }
    ).WebSocketPair;

    if (upgradeHeader?.toLowerCase() === 'websocket' && WebSocketPairCtor) {
      const pair = new WebSocketPairCtor();
      const clientSocket = pair[0];
      const serverSocket = pair[1] as WebSocket & { accept?: () => void };

      if (typeof this.state.acceptWebSocket === 'function') {
        this.state.acceptWebSocket(serverSocket, [generationId]);
      } else if (typeof serverSocket.accept === 'function') {
        serverSocket.accept();
      }
      this.sockets.add(serverSocket);

      serverSocket.addEventListener('message', (evt: Event) => {
        const data = (evt as { data?: unknown }).data;
        this.handleSocketMessage(serverSocket, String(data ?? ''));
      });
      serverSocket.addEventListener('close', () => {
        this.sockets.delete(serverSocket);
      });

      const cached =
        this.lastEvent ??
        (await this.state.storage.get<GenerationPipelineEventPayload>('last_event'));
      if (cached) {
        try {
          serverSocket.send(
            JSON.stringify(buildDualDialectPipelineEventFrame(cached)),
          );
        } catch {
          // ignore closed socket
        }
      }

      return new Response(null, {
        status: 101,
        webSocket: clientSocket,
      } as unknown as ResponseInit);
    }

    const snapshot =
      this.lastEvent ??
      (await this.state.storage.get<GenerationPipelineEventPayload>('last_event'));
    return new Response(
      JSON.stringify({
        generationId,
        protocol: 'vhunambi_generation_ws_v1',
        activeConnections: this.countSockets(),
        lastEvent: snapshot ?? null,
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    );
  }

  public webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): void {
    const raw =
      typeof message === 'string'
        ? message
        : new TextDecoder().decode(message);
    this.handleSocketMessage(ws, raw);
  }

  public webSocketClose(ws: WebSocket): void {
    this.sockets.delete(ws);
  }

  private handleSocketMessage(ws: WebSocket, raw: string): void {
    try {
      const parsed = JSON.parse(raw) as { type?: string };
      if (parsed.type === 'PING') {
        ws.send(JSON.stringify({ type: 'PONG', timestamp: Date.now() }));
      }
    } catch {
      ws.send(
        JSON.stringify({
          type: 'ERROR',
          message: 'Malformed WebSocket JSON frame',
        }),
      );
    }
  }

  private countSockets(): number {
    const hibernated =
      typeof this.state.getWebSockets === 'function'
        ? this.state.getWebSockets().length
        : 0;
    return Math.max(this.sockets.size, hibernated);
  }

  private broadcastFrame(frame: string): void {
    const targets = new Set<WebSocket>(this.sockets);
    if (typeof this.state.getWebSockets === 'function') {
      for (const s of this.state.getWebSockets()) {
        targets.add(s);
      }
    }
    for (const ws of targets) {
      try {
        ws.send(frame);
      } catch {
        this.sockets.delete(ws);
      }
    }
  }
}

export async function broadcastGenerationEventToDo(
  env: VhunambiWorkerEnv | Record<string, unknown> | undefined,
  event: GenerationPipelineEventPayload,
): Promise<void> {
  const ns = (env as VhunambiWorkerEnv | undefined)?.GENERATION_DO;
  if (!ns) return;
  try {
    const id = ns.idFromName(event.generationId);
    const stub = ns.get(id);
    await stub.fetch(
      `https://do.vhunambi.internal/internal/broadcast?id=${encodeURIComponent(event.generationId)}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(event),
      },
    );
  } catch {
    // Non-fatal in offline/test mode
  }
}

