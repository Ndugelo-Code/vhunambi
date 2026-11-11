import { RuntimeEnvConfig, resolveRuntimeEnv } from '../config/env.js';

export interface GoTrueAuthResponse {
  access_token: string;
  refresh_token: string;
  expires_in: number;
  expires_at?: number;
  user: {
    id: string;
    email?: string;
    user_metadata?: Record<string, unknown>;
    app_metadata?: Record<string, unknown>;
  };
}

export interface NormalizedWalletLedgerEntry {
  id: string;
  creatorId: string;
  type: string;
  amountZar: number;
  signedDeltaZar: number;
  amountCoins: number;
  status: string;
  reference: string;
  metadata: Record<string, unknown>;
  createdAt: string;
}

/**
 * Resolves the SQLite vs PostgreSQL `wallet_ledger` sign & column divergence:
 * - SQLite stores `data_json` and positive `amount_zar` on `type = 'payout'` (subtracted on read).
 * - PostgreSQL stores `metadata_json` and negative `-ABS(amount_zar)` on `type = 'payout_withdrawal'`.
 */
export function normalizeWalletLedgerRow(
  row: Record<string, unknown>,
): NormalizedWalletLedgerEntry {
  const type = String(row.type ?? row.tx_type ?? 'topup');
  const rawZar = Number(row.amount_zar ?? row.amountZar ?? 0);
  const rawCoins = Number(row.amount_coins ?? row.amountCoins ?? 0);

  let signedDeltaZar = rawZar;
  if ((type === 'payout' || type === 'payout_withdrawal') && rawZar > 0) {
    signedDeltaZar = -Math.abs(rawZar);
  }

  let metadata: Record<string, unknown> = {};
  const rawMeta = row.metadata_json ?? row.data_json ?? row.metadata;
  if (typeof rawMeta === 'string' && rawMeta.trim().length > 0) {
    try {
      metadata = JSON.parse(rawMeta) as Record<string, unknown>;
    } catch {
      metadata = {};
    }
  } else if (rawMeta && typeof rawMeta === 'object') {
    metadata = rawMeta as Record<string, unknown>;
  }

  return {
    id: String(row.id ?? ''),
    creatorId: String(row.creator_id ?? row.creatorId ?? ''),
    type,
    amountZar: Math.abs(rawZar),
    signedDeltaZar: Number(signedDeltaZar.toFixed(2)),
    amountCoins: Math.trunc(rawCoins),
    status: String(row.status ?? 'completed'),
    reference: String(row.reference ?? ''),
    metadata,
    createdAt: String(row.created_at ?? row.createdAt ?? new Date().toISOString()),
  };
}

export function computeWalletTotalsFromLedgerRows(
  rows: Array<Record<string, unknown>>,
): {
  balanceZar: number;
  balanceCoins: number;
  pendingPayoutZar: number;
  transactions: NormalizedWalletLedgerEntry[];
} {
  const transactions = rows.map(normalizeWalletLedgerRow);
  let balanceZar = 0;
  let balanceCoins = 0;
  let pendingPayoutZar = 0;
  for (const tx of transactions) {
    if (tx.status === 'failed' || tx.status === 'rejected') continue;
    if (tx.type === 'payout' || tx.type === 'payout_withdrawal') {
      const debit = Math.abs(tx.amountZar);
      if (tx.status === 'completed' || tx.status === 'instant_cleared') {
        balanceZar -= debit;
      } else if (
        tx.status === 'pending' ||
        tx.status === 'processing' ||
        tx.status === 'processing_eft'
      ) {
        pendingPayoutZar += debit;
        balanceZar -= debit;
      }
      continue;
    }
    if (tx.status === 'completed') {
      balanceZar += tx.signedDeltaZar;
      balanceCoins += tx.amountCoins;
    }
  }
  return {
    balanceZar: Number(Math.max(0, balanceZar).toFixed(2)),
    balanceCoins: Math.max(0, Math.trunc(balanceCoins)),
    pendingPayoutZar: Number(pendingPayoutZar.toFixed(2)),
    transactions,
  };
}

/**
 * Normalizes `beat_licenses` rows between SQLite (`coins_paid`, `zar_paid`, `issued_at`, `data_json`)
 * and PostgreSQL (`amount_paid_coins`, `amount_paid_zar`, `purchased_at`, `terms_json`, `stems_urls_json`).
 */
export function normalizeBeatLicenseRow(
  row: Record<string, unknown>,
): Record<string, unknown> {
  let baseData: Record<string, unknown> = {};
  if (typeof row.data_json === 'string' && row.data_json.trim()) {
    try {
      baseData = JSON.parse(row.data_json) as Record<string, unknown>;
    } catch {
      baseData = {};
    }
  } else if (typeof row.terms_json === 'string' && row.terms_json.trim()) {
    try {
      baseData = JSON.parse(row.terms_json) as Record<string, unknown>;
    } catch {
      baseData = {};
    }
  } else if (row.terms_json && typeof row.terms_json === 'object') {
    baseData = row.terms_json as Record<string, unknown>;
  }
  return {
    ...baseData,
    certificateId: String(row.certificate_id ?? baseData.certificateId ?? ''),
    licenseHash: String(row.license_hash ?? baseData.licenseHash ?? ''),
    beatId: String(row.beat_id ?? baseData.beatId ?? ''),
    beatTitle: String(row.beat_title ?? baseData.beatTitle ?? 'Untitled Beat'),
    producerId: String(row.producer_id ?? baseData.producerId ?? ''),
    buyerId: String(row.buyer_id ?? baseData.buyerId ?? ''),
    tier: String(row.tier ?? baseData.tier ?? 'basic_lease'),
    amountPaidCoins: Number(
      row.amount_paid_coins ?? row.coins_paid ?? baseData.amountPaidCoins ?? 0,
    ),
    amountPaidZar: Number(
      row.amount_paid_zar ?? row.zar_paid ?? baseData.amountPaidZar ?? 0,
    ),
    masterFileSha256: String(
      row.master_file_sha256 ?? baseData.masterFileSha256 ?? '',
    ),
    issuedAt: String(
      row.issued_at ?? row.purchased_at ?? baseData.issuedAt ?? new Date().toISOString(),
    ),
  };
}

/**
 * Normalizes `user_library_sync` rows between SQLite (`data_json`, ISO `updated_at`)
 * and PostgreSQL (normalized columns + `BIGINT updated_at`).
 */
export function normalizeLibrarySyncRow(
  row: Record<string, unknown>,
): Record<string, unknown> {
  let parsed: Record<string, unknown> = {};
  if (typeof row.data_json === 'string' && row.data_json.trim()) {
    try {
      parsed = JSON.parse(row.data_json) as Record<string, unknown>;
    } catch {
      parsed = {};
    }
  }
  const rawUpdatedAt = row.updated_at ?? parsed.updatedAt;
  const updatedAtIso =
    typeof rawUpdatedAt === 'number'
      ? new Date(rawUpdatedAt).toISOString()
      : String(rawUpdatedAt ?? new Date().toISOString());

  return {
    ...parsed,
    id: String(row.id ?? parsed.id ?? ''),
    creatorId: String(row.creator_id ?? parsed.creatorId ?? 'creator_cern'),
    itemType: String(row.item_type ?? parsed.itemType ?? 'track'),
    title: String(row.title ?? parsed.title ?? 'Untitled Track'),
    genre: String(row.genre ?? parsed.genre ?? 'Amapiano'),
    language: String(row.language ?? parsed.language ?? 've'),
    masterMp3Url: String(
      row.master_mp3_url ?? parsed.masterMp3Url ?? parsed.audioUrl ?? '',
    ),
    updatedAt: updatedAtIso,
  };
}

/**
 * Normalizes `sync_mutation_log` rows between SQLite (`idempotency_key`, `action`, `created_at`)
 * and PostgreSQL (`mutation_id`, `operation`, `client_ts`, `server_ts`).
 */
export function normalizeSyncMutationRow(
  row: Record<string, unknown>,
): Record<string, unknown> {
  let payload: Record<string, unknown> = {};
  const rawPayload = row.payload_json ?? row.payload;
  if (typeof rawPayload === 'string' && rawPayload.trim()) {
    try {
      payload = JSON.parse(rawPayload) as Record<string, unknown>;
    } catch {
      payload = {};
    }
  } else if (rawPayload && typeof rawPayload === 'object') {
    payload = rawPayload as Record<string, unknown>;
  }

  return {
    seq: Number(row.seq ?? 0),
    idempotencyKey: String(
      row.idempotency_key ?? row.mutation_id ?? row.idempotencyKey ?? '',
    ),
    mutationId: String(
      row.mutation_id ?? row.idempotency_key ?? row.idempotencyKey ?? '',
    ),
    creatorId: String(row.creator_id ?? row.creatorId ?? 'system'),
    entityType: String(row.entity_type ?? row.entityType ?? ''),
    entityId: String(row.entity_id ?? row.entityId ?? ''),
    action: String(row.action ?? row.operation ?? 'upsert'),
    operation: String(row.operation ?? row.action ?? 'upsert'),
    payload,
    createdAt: String(
      row.created_at ?? row.server_ts ?? new Date().toISOString(),
    ),
  };
}

/**
 * Normalizes `playlists` rows between SQLite (`cover_image_url`, `is_public INTEGER`, `track_ids_json`)
 * and PostgreSQL (`cover_image_url`, `is_public BOOLEAN`, `tracks_json`).
 */
export function normalizePlaylistRow(
  row: Record<string, unknown>,
): Record<string, unknown> {
  let parsed: Record<string, unknown> = {};
  if (typeof row.data_json === 'string' && row.data_json.trim()) {
    try {
      parsed = JSON.parse(row.data_json) as Record<string, unknown>;
    } catch {
      parsed = {};
    }
  }
  let trackIds: string[] = Array.isArray(parsed.trackIds)
    ? (parsed.trackIds as unknown[]).map(String)
    : [];
  const rawTracks = row.track_ids_json ?? row.tracks_json ?? row.trackIds;
  if (typeof rawTracks === 'string' && rawTracks.trim()) {
    try {
      const dec = JSON.parse(rawTracks);
      if (Array.isArray(dec)) trackIds = dec.map(String);
    } catch {
      // keep existing
    }
  } else if (Array.isArray(rawTracks)) {
    trackIds = rawTracks.map(String);
  }
  const isPublicRaw = row.is_public ?? parsed.isPublic;
  const coverImageUrl =
    row.cover_image_url ?? row.cover_url ?? parsed.coverImageUrl ?? parsed.coverUrl ?? null;
  const isPublic = isPublicRaw === true || Number(isPublicRaw) === 1;
  return {
    ...parsed,
    id: String(row.id ?? parsed.id ?? ''),
    creatorId: String(row.creator_id ?? parsed.creatorId ?? 'creator_cern'),
    creator_id: String(row.creator_id ?? parsed.creatorId ?? 'creator_cern'),
    title: String(row.title ?? parsed.title ?? 'Untitled Playlist'),
    description: String(row.description ?? parsed.description ?? ''),
    coverUrl: String(coverImageUrl ?? ''),
    coverImageUrl,
    cover_image_url: coverImageUrl,
    trackIds,
    track_ids: trackIds,
    isPublic,
    is_public: isPublic,
    shareCode: row.share_code ?? parsed.shareCode ?? null,
    share_code: row.share_code ?? parsed.shareCode ?? null,
    shareUrl: row.share_url ?? parsed.shareUrl ?? null,
    share_url: row.share_url ?? parsed.shareUrl ?? null,
  };
}

/**
 * Normalizes `marketplace_assets` rows between SQLite and PostgreSQL.
 */
export function normalizeMarketplaceAssetRow(
  row: Record<string, unknown>,
): Record<string, unknown> {
  let parsed: Record<string, unknown> = {};
  if (typeof row.data_json === 'string' && row.data_json.trim()) {
    try {
      parsed = JSON.parse(row.data_json) as Record<string, unknown>;
    } catch {
      parsed = {};
    }
  }
  const soldRaw = row.is_exclusive_sold ?? parsed.isExclusiveSold;
  return {
    ...parsed,
    id: String(row.id ?? parsed.id ?? ''),
    title: String(row.title ?? parsed.title ?? ''),
    producerId: String(row.producer_id ?? parsed.producerId ?? ''),
    assetCategory: String(row.asset_category ?? parsed.assetCategory ?? 'beats'),
    priceZar: Number(row.price_zar ?? parsed.priceZar ?? 0),
    priceCoins: Number(row.price_coins ?? parsed.priceCoins ?? 0),
    isExclusiveSold: soldRaw === true || Number(soldRaw) === 1,
    exclusiveBuyerId:
      row.exclusive_buyer_id ?? row.buyer_creator_id ?? parsed.exclusiveBuyerId ?? null,
  };
}

/**
 * Zero-dependency Edge HTTP driver for Supabase PostgREST, PL/pgSQL RPCs, and GoTrue Auth.
 * Uses standard Web `fetch` so it executes natively on Cloudflare Workers and Node.js
 * without requiring un-installed external npm packages.
 */
export class SupabaseCloudDriver {
  private readonly supabaseUrl: string;
  private readonly serviceRoleKey: string;
  private readonly anonKey: string;

  constructor(envInput?: Partial<RuntimeEnvConfig> | Record<string, unknown>) {
    const resolved = resolveRuntimeEnv(envInput);
    this.supabaseUrl = resolved.SUPABASE_URL.replace(/\/+$/, '');
    this.serviceRoleKey = resolved.SUPABASE_SERVICE_ROLE_KEY;
    this.anonKey = resolved.SUPABASE_ANON_KEY || resolved.SUPABASE_SERVICE_ROLE_KEY;
  }

  public isConfigured(): boolean {
    return (
      this.supabaseUrl.startsWith('https://') &&
      this.serviceRoleKey.trim().length > 20
    );
  }

  private buildRestHeaders(prefer?: string): Record<string, string> {
    const headers: Record<string, string> = {
      apikey: this.serviceRoleKey,
      'Content-Type': 'application/json',
    };
    if (!this.serviceRoleKey.startsWith('sb_secret_')) {
      headers.Authorization = `Bearer ${this.serviceRoleKey}`;
    }
    if (prefer) {
      headers.Prefer = prefer;
    }
    return headers;
  }

  public async callRpc<T = Record<string, unknown>>(
    fnName: string,
    args: Record<string, unknown>,
  ): Promise<T> {
    const res = await fetch(`${this.supabaseUrl}/rest/v1/rpc/${fnName}`, {
      method: 'POST',
      headers: this.buildRestHeaders(),
      body: JSON.stringify(args),
    });
    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`SUPABASE_RPC_ERROR[${fnName}]: ${res.status} ${errText}`);
    }
    return (await res.json()) as T;
  }

  public async selectRows<T = Record<string, unknown>>(
    table: string,
    queryString: string,
  ): Promise<T[]> {
    const url = `${this.supabaseUrl}/rest/v1/${table}?${queryString}`;
    const res = await fetch(url, {
      method: 'GET',
      headers: this.buildRestHeaders(),
    });
    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`SUPABASE_SELECT_ERROR[${table}]: ${res.status} ${errText}`);
    }
    return (await res.json()) as T[];
  }

  public async insertRow<T = Record<string, unknown>>(
    table: string,
    payload: Record<string, unknown> | Record<string, unknown>[],
  ): Promise<T[]> {
    const res = await fetch(`${this.supabaseUrl}/rest/v1/${table}`, {
      method: 'POST',
      headers: this.buildRestHeaders('return=representation'),
      body: JSON.stringify(payload),
    });
    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`SUPABASE_INSERT_ERROR[${table}]: ${res.status} ${errText}`);
    }
    return (await res.json()) as T[];
  }

  public async upsertRow<T = Record<string, unknown>>(
    table: string,
    payload: Record<string, unknown> | Record<string, unknown>[],
    onConflict?: string,
  ): Promise<T[]> {
    const conflictQuery = onConflict
      ? `?on_conflict=${encodeURIComponent(onConflict)}`
      : '';
    const res = await fetch(
      `${this.supabaseUrl}/rest/v1/${table}${conflictQuery}`,
      {
        method: 'POST',
        headers: this.buildRestHeaders(
          'resolution=merge-duplicates,return=representation',
        ),
        body: JSON.stringify(payload),
      },
    );
    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`SUPABASE_UPSERT_ERROR[${table}]: ${res.status} ${errText}`);
    }
    return (await res.json()) as T[];
  }

  public async patchRows<T = Record<string, unknown>>(
    table: string,
    filterQuery: string,
    patchBody: Record<string, unknown>,
  ): Promise<T[]> {
    const res = await fetch(
      `${this.supabaseUrl}/rest/v1/${table}?${filterQuery}`,
      {
        method: 'PATCH',
        headers: this.buildRestHeaders('return=representation'),
        body: JSON.stringify(patchBody),
      },
    );
    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`SUPABASE_PATCH_ERROR[${table}]: ${res.status} ${errText}`);
    }
    return (await res.json()) as T[];
  }

  public async deleteRows<T = Record<string, unknown>>(
    table: string,
    filterQuery: string,
  ): Promise<T[]> {
    const res = await fetch(
      `${this.supabaseUrl}/rest/v1/${table}?${filterQuery}`,
      {
        method: 'DELETE',
        headers: this.buildRestHeaders('return=representation'),
      },
    );
    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`SUPABASE_DELETE_ERROR[${table}]: ${res.status} ${errText}`);
    }
    return (await res.json()) as T[];
  }

  public async goTrueSignUp(params: {
    email: string;
    password: string;
    creatorId: string;
    handle: string;
    displayName: string;
  }): Promise<GoTrueAuthResponse> {
    const res = await fetch(`${this.supabaseUrl}/auth/v1/signup`, {
      method: 'POST',
      headers: {
        apikey: this.anonKey,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        email: params.email,
        password: params.password,
        data: {
          creator_id: params.creatorId,
          handle: params.handle,
          display_name: params.displayName,
        },
      }),
    });
    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`GOTRUE_SIGNUP_FAILED: ${res.status} ${errText}`);
    }
    return (await res.json()) as GoTrueAuthResponse;
  }

  public async goTrueSignInWithPassword(
    email: string,
    password: string,
  ): Promise<GoTrueAuthResponse> {
    const res = await fetch(
      `${this.supabaseUrl}/auth/v1/token?grant_type=password`,
      {
        method: 'POST',
        headers: {
          apikey: this.anonKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ email, password }),
      },
    );
    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`GOTRUE_LOGIN_FAILED: ${res.status} ${errText}`);
    }
    return (await res.json()) as GoTrueAuthResponse;
  }

  public async goTrueRefreshSession(
    refreshToken: string,
  ): Promise<GoTrueAuthResponse> {
    const res = await fetch(
      `${this.supabaseUrl}/auth/v1/token?grant_type=refresh_token`,
      {
        method: 'POST',
        headers: {
          apikey: this.anonKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ refresh_token: refreshToken }),
      },
    );
    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`GOTRUE_REFRESH_FAILED: ${res.status} ${errText}`);
    }
    return (await res.json()) as GoTrueAuthResponse;
  }
}

