export interface CfExecutionContext {
  waitUntil(promise: Promise<unknown>): void;
  passThroughOnException(): void;
  props?: Record<string, unknown>;
}

export interface CfR2ObjectBody {
  key: string;
  size: number;
  etag: string;
  body: ReadableStream<Uint8Array> | null;
  httpMetadata?: {
    contentType?: string;
    cacheControl?: string;
  };
  arrayBuffer(): Promise<ArrayBuffer>;
  text(): Promise<string>;
}

export interface CfR2Bucket {
  get(key: string): Promise<CfR2ObjectBody | null>;
  put(
    key: string,
    value: ReadableStream | ArrayBuffer | Uint8Array | string,
    options?: { httpMetadata?: { contentType?: string; cacheControl?: string } },
  ): Promise<unknown>;
  delete(keys: string | string[]): Promise<void>;
}

export interface CfHyperdriveBinding {
  connectionString: string;
}

export interface CfDurableObjectId {
  toString(): string;
}

export interface CfDurableObjectStub {
  fetch(input: Request | string | URL, init?: RequestInit): Promise<Response>;
}

export interface CfDurableObjectNamespace {
  idFromName(name: string): CfDurableObjectId;
  get(id: CfDurableObjectId): CfDurableObjectStub;
}

export interface CfDurableObjectStorage {
  get<T = unknown>(key: string): Promise<T | undefined>;
  put<T = unknown>(key: string, value: T): Promise<void>;
  delete(key: string): Promise<boolean>;
}

export interface CfDurableObjectState {
  id: CfDurableObjectId;
  storage: CfDurableObjectStorage;
  acceptWebSocket?(ws: WebSocket, tags?: string[]): void;
  getWebSockets?(tag?: string): WebSocket[];
}

export interface VhunambiWorkerEnv {
  NODE_ENV?: string;
  VHUNAMBI_AUTH_MODE?: string;
  VHUNAMBI_JWT_SECRET?: string;
  SUPABASE_URL?: string;
  SUPABASE_ANON_KEY?: string;
  SUPABASE_SERVICE_ROLE_KEY?: string;
  SUPABASE_JWT_SECRET?: string;
  R2_ACCESS_KEY_ID?: string;
  R2_SECRET_ACCESS_KEY?: string;
  R2_ENDPOINT?: string;
  R2_BUCKET?: string;
  R2_PUBLIC_BASE_URL?: string;
  RUNPOD_API_KEY?: string;
  RUNPOD_ENDPOINT_ID?: string;
  RUNPOD_COMFYUI_URL?: string;
  RUNPOD_COMFYUI_ENDPOINT_ID?: string;
  ZR_WEBHOOK_SECRET?: string;
  WEBHOOK_BASE_URL?: string;
  ZR_LLM_PROVIDER?: 'claude' | 'grok' | 'mock';
  ANTHROPIC_API_KEY?: string;
  GROK_API_KEY?: string;
  PAYFAST_MERCHANT_ID?: string;
  PAYFAST_MERCHANT_KEY?: string;
  PAYFAST_PASSPHRASE?: string;
  PAYFAST_SANDBOX?: string;
  VHUNAMBI_VAULT?: CfR2Bucket;
  HYPERDRIVE?: CfHyperdriveBinding;
  GENERATION_DO?: CfDurableObjectNamespace;
}
