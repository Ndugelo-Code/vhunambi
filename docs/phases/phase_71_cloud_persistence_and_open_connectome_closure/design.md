# Phase 71 — Comprehensive Technical Design & Production Implementation Specification

**Document ID:** `VHUNAMBI-SPEC-P71-DESIGN-V1`  
**Phase:** `71` — Cloudflare Worker Supabase Read/Write-Through Durability, `OPEN` Connectome Closure (`EP-P67`, `EP-P69`, `EP-P37`, `EP-P68`) & 100% Green Test Baseline  
**Date:** `2026-11-20`  
**Status:** `SPECIFICATION HARDENED (STAGE 2 & 3 — ZERO PLACEHOLDERS)`  
**Companion Documents:** [`blueprint.md`](./blueprint.md) · [`requirements.md`](./requirements.md) · [`tasks.md`](./tasks.md) · [`memory.md`](./memory.md)

---

## Table of Contents

1. [Overhaul Pass 1 (`M71.1`): PostgreSQL Migration & Atomic Quota RPC (`supabase/`)](#1-overhaul-pass-1-m711-postgresql-migration--atomic-quota-rpc)
2. [Overhaul Pass 1 (`M71.1`): `GenerationJob.visionMeta`, `EdgeIsolateDatabaseEngine` SWR Read/Write-Through & `VhunambiDatabase` Parity](#2-overhaul-pass-1-m711-edge-swr-readwrite-through--database-parity)
3. [Overhaul Pass 1 (`M71.1`): Worker Route Integration (`server.ts`, `notification_routes.ts`, `wallet_routes.ts`, `explore_routes.ts`, `generation_routes.ts`, `webhook_routes.ts`, `vision_routes.ts`)](#3-overhaul-pass-1-m711-worker-route-integration)
4. [Overhaul Pass 1 (`M71.2`): Backend Test Hygiene & Cross-Isolate Simulation Suite](#4-overhaul-pass-1-m712-backend-test-hygiene--cross-isolate-simulation-suite)
5. [Overhaul Pass 2 (`M71.3`): `EP-P67-NOTIF-API` — `HttpNotificationRepository` & `NotificationsNotifier` Sync](#5-overhaul-pass-2-m713-ep-p67-notif-api--httpnotificationrepository--notificationsnotifier)
6. [Overhaul Pass 2 (`M71.3`): `EP-P69-POST-COSIGN-REPOST-HTTP` — `HttpExploreRepository`, `SocialFeedPostsNotifier` & `ReelsCommentsNotifier`](#6-overhaul-pass-2-m713-ep-p69-post-cosign-repost-http--direct-http--offline-only-outbox)
7. [Overhaul Pass 2 (`M71.3`): `EP-P37-REMIX-TREE-API` — Live Genealogical Remix Graph](#7-overhaul-pass-2-m713-ep-p37-remix-tree-api--live-genealogical-remix-graph)
8. [Overhaul Pass 2 (`M71.3`): `EP-P68-CREATOR-ALLOWANCE` Extension — `StudioActionBar`, `GenerationPipelineNotifier` & `SubscriptionUpgradeModal`](#8-overhaul-pass-2-m713-ep-p68-creator-allowance-extension)
9. [Overhaul Pass 2 (`M71.4`): Surgical Repairs for 5 Stale Client Test Files & New Phase 71 Connectome Closure Suite](#9-overhaul-pass-2-m714-surgical-repairs-for-5-stale-client-test-files--phase-71-suite)
10. [Invariants Proof & Failure-Mode Containment](#10-invariants-proof--failure-mode-containment)

---

## 1. Overhaul Pass 1 (`M71.1`): PostgreSQL Migration & Atomic Quota RPC

**Target File:** `supabase/migrations/20261120000001_phase71_schema_parity_and_rpcs.sql`

```sql
BEGIN;

-- =============================================================================
-- Phase 71 (REQ-P71-SQL-01): explore_tracks parity columns
-- =============================================================================
ALTER TABLE public.explore_tracks
  ADD COLUMN IF NOT EXISTS mood TEXT NOT NULL DEFAULT 'Vibrant';

ALTER TABLE public.explore_tracks
  ADD COLUMN IF NOT EXISTS language TEXT NOT NULL DEFAULT 'isiZulu';

ALTER TABLE public.explore_tracks
  ADD COLUMN IF NOT EXISTS discovery_stage TEXT NOT NULL DEFAULT 'freshCrate';

ALTER TABLE public.explore_tracks
  ADD COLUMN IF NOT EXISTS data_json JSONB NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE public.explore_tracks
  ADD COLUMN IF NOT EXISTS created_at BIGINT NOT NULL
    DEFAULT (EXTRACT(EPOCH FROM now()) * 1000)::BIGINT;

CREATE INDEX IF NOT EXISTS idx_explore_tracks_stage_updated
  ON public.explore_tracks (discovery_stage, updated_at DESC);

-- =============================================================================
-- Phase 71 (REQ-P71-SQL-02): user_library_sync parity columns
-- =============================================================================
ALTER TABLE public.user_library_sync
  ADD COLUMN IF NOT EXISTS item_type TEXT NOT NULL DEFAULT 'track';

ALTER TABLE public.user_library_sync
  ADD COLUMN IF NOT EXISTS created_at BIGINT NOT NULL
    DEFAULT (EXTRACT(EPOCH FROM now()) * 1000)::BIGINT;

-- =============================================================================
-- Phase 71 (REQ-P71-SQL-03 / EP-P71-ATOMIC-QUOTA-RPC):
-- Row-locked atomic monthly free song quota consumption across Cloudflare
-- Worker isolates. Prevents double-spending the 10-song free allowance and
-- rolls over expired 30-day cycles inside a single Postgres transaction.
-- =============================================================================
CREATE OR REPLACE FUNCTION public.consume_free_monthly_song_quota_atomic(
  p_user_id TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id TEXT := COALESCE(NULLIF(TRIM(p_user_id), ''), 'creator_cern');
  v_now TIMESTAMPTZ := now();
  v_row public.creator_quotas%ROWTYPE;
  v_used INTEGER;
  v_limit INTEGER;
  v_reset_at TIMESTAMPTZ;
  v_allowed BOOLEAN := false;
  v_remaining INTEGER := 0;
BEGIN
  INSERT INTO public.creator_quotas (
    user_id,
    plan_tier,
    free_monthly_songs_limit,
    free_monthly_songs_used,
    cycle_reset_at,
    updated_at
  )
  VALUES (
    v_user_id,
    'free',
    10,
    0,
    v_now + INTERVAL '30 days',
    v_now
  )
  ON CONFLICT (user_id) DO NOTHING;

  SELECT *
    INTO v_row
    FROM public.creator_quotas
   WHERE user_id = v_user_id
     FOR UPDATE;

  v_limit := COALESCE(v_row.free_monthly_songs_limit, 10);
  v_used := COALESCE(v_row.free_monthly_songs_used, 0);
  v_reset_at := COALESCE(v_row.cycle_reset_at, v_now + INTERVAL '30 days');

  IF v_now >= v_reset_at THEN
    v_used := 0;
    v_reset_at := v_now + INTERVAL '30 days';
  END IF;

  IF LOWER(COALESCE(v_row.plan_tier, 'free')) <> 'free' OR v_limit < 0 THEN
    v_allowed := true;
    v_remaining := CASE WHEN v_limit < 0 THEN 999999 ELSE GREATEST(0, v_limit - v_used) END;
  ELSIF v_used < v_limit THEN
    v_used := v_used + 1;
    v_allowed := true;
    v_remaining := GREATEST(0, v_limit - v_used);
  ELSE
    v_allowed := false;
    v_remaining := 0;
  END IF;

  UPDATE public.creator_quotas
     SET free_monthly_songs_used = v_used,
         cycle_reset_at = v_reset_at,
         updated_at = v_now
   WHERE user_id = v_user_id;

  RETURN jsonb_build_object(
    'userId', v_user_id,
    'planTier', COALESCE(v_row.plan_tier, 'free'),
    'freeMonthlySongsLimit', v_limit,
    'freeMonthlySongsUsed', v_used,
    'freeMonthlySongsRemaining', v_remaining,
    'cycleResetAt', to_char(v_reset_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    'updatedAt', to_char(v_now AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    'allowed', v_allowed
  );
END;
$$;

COMMIT;
```

---

## 2. Overhaul Pass 1 (`M71.1`): Edge SWR Read/Write-Through & Database Parity

### 2.1 `GenerationJob.visionMeta` Field (`apps/vhunambi_api/src/modules/jobs/job_types.ts`)

Add an optional structured `visionMeta?: Record<string, unknown>;` property to `GenerationJob` so Vision and NVENC Render Video jobs persist cleanly inside `generation_jobs.manifest_json` without module-scoped RAM maps:

```ts
import { MasterMediaObjectManifest } from '../dna/dna_types.js';

export type JobStatus = 'queued' | 'running' | 'succeeded' | 'failed';
export type PipelineStep = 'queued' | 'synthesizing' | 'separating_stems' | 'ready' | 'failed';

export interface GenerationJob {
  generationId: string;
  trackTitle: string;
  genre: string;
  language: string;
  status: JobStatus;
  step: PipelineStep;
  progressPct: number;
  masterMp3Url?: string;
  stemsZipUrl?: string;
  stemUrls?: Record<string, string>;
  manifestUrl?: string;
  manifest?: MasterMediaObjectManifest;
  visionMeta?: Record<string, unknown>;
  coverUrl?: string;
  lyrics?: string;
  durationSec?: number;
  errorMessage?: string;
  providerTaskId?: string;
  createdAt: Date;
  updatedAt: Date;
}
```

### 2.2 `EdgeIsolateDatabaseEngine` Upgrades (`apps/vhunambi_api/src/db/edge_persistence_bridge.ts`)

#### A. Exported Failure Record Type & SWR Engine Fields

Export `WriteThroughFailureRecord` and `AtomicQuotaConsumeResult` alongside `CreatorQuotaRecord`:

```ts
export interface WriteThroughFailureRecord {
  id: string;
  label: string;
  error: string;
  timestamp: string;
}

export interface AtomicQuotaConsumeResult extends CreatorQuotaRecord {
  allowed: boolean;
}
```

Inside `EdgeIsolateDatabaseEngine`, replace `private coldStartHydrated = false;` with domain-scoped SWR freshness tracking, a bounded write-through telemetry ring, and an optional test driver injection slot:

```ts
  public static readonly DEFAULT_SWR_TTL_MS = 12_000;
  private static readonly MAX_WRITE_THROUGH_FAILURES = 100;

  private readonly domainHydratedAtMs = new Map<string, number>();
  private readonly domainInFlightPromises = new Map<string, Promise<boolean>>();
  private readonly writeThroughFailures: WriteThroughFailureRecord[] = [];
  private coldStartHydrationPromise: Promise<void> | null = null;
  private readonly injectedDriver: SupabaseCloudDriver | null;

  constructor(injectedDriver?: SupabaseCloudDriver) {
    this.injectedDriver = injectedDriver ?? null;
    this.seedDefaults();
  }

  private resolveCloudDriver(cOrEnv?: unknown): SupabaseCloudDriver {
    if (this.injectedDriver) {
      return this.injectedDriver;
    }
    const resolvedCtx = cOrEnv ?? EdgePersistenceBridge.getActiveContext();
    return EdgePersistenceBridge.getCloudDriver(
      resolvedCtx as Context | Record<string, unknown> | undefined,
    );
  }

  public getWriteThroughFailures(): WriteThroughFailureRecord[] {
    return [...this.writeThroughFailures];
  }

  public getDomainHydratedAt(domainKey: string): number | undefined {
    return this.domainHydratedAtMs.get(domainKey);
  }

  private recordWriteThroughFailure(label: string, err: unknown): void {
    const message = err instanceof Error ? err.message : String(err);
    const entry: WriteThroughFailureRecord = {
      id: `wtf_${Date.now()}_${this.writeThroughFailures.length + 1}`,
      label,
      error: message,
      timestamp: new Date().toISOString(),
    };
    this.writeThroughFailures.push(entry);
    if (
      this.writeThroughFailures.length >
      EdgeIsolateDatabaseEngine.MAX_WRITE_THROUGH_FAILURES
    ) {
      this.writeThroughFailures.splice(
        0,
        this.writeThroughFailures.length -
          EdgeIsolateDatabaseEngine.MAX_WRITE_THROUGH_FAILURES,
      );
    }
    console.error(`[EdgeWriteThroughError] label=${label} error=${message}`);
  }
```

Inside `resetForTesting()`, clear `this.domainHydratedAtMs.clear()`, `this.domainInFlightPromises.clear()`, `this.writeThroughFailures.length = 0`, and `this.coldStartHydrationPromise = null;`.

#### B. Timeout Helper Distinguishing Timeout/Error vs Empty Success

```ts
  private static async withTimeoutResult<T>(
    promise: Promise<T>,
    timeoutMs: number,
  ): Promise<
    { ok: true; value: T } | { ok: false; timedOut: boolean; error?: unknown }
  > {
    let timer: ReturnType<typeof setTimeout> | undefined;
    try {
      const result = await Promise.race([
        promise.then(
          (value) => ({ ok: true as const, value }),
          (error) => ({ ok: false as const, timedOut: false, error }),
        ),
        new Promise<{ ok: false; timedOut: true }>((resolve) => {
          timer = setTimeout(() => resolve({ ok: false, timedOut: true }), timeoutMs);
        }),
      ]);
      return result;
    } finally {
      if (timer !== undefined) clearTimeout(timer);
    }
  }
```

#### C. Non-Swallowing `mirrorWriteThrough` & Awaited `awaitWriteThrough`

Keep single-argument backward compatibility for all 27 existing callers while supporting explicit domain labels and logging/recording every failure:

```ts
  private mirrorWriteThrough(
    opOrLabel: string | ((driver: SupabaseCloudDriver) => Promise<unknown>),
    maybeOp?: (driver: SupabaseCloudDriver) => Promise<unknown>,
  ): void {
    const label = typeof opOrLabel === 'string' ? opOrLabel : 'anonymous_write_through';
    const op = typeof opOrLabel === 'function' ? opOrLabel : maybeOp;
    if (!op) return;

    const activeCtx = EdgePersistenceBridge.getActiveContext();
    const driver = this.resolveCloudDriver(activeCtx);
    if (!driver.isConfigured()) return;

    const task = Promise.resolve()
      .then(() => op(driver))
      .catch((err) => {
        this.recordWriteThroughFailure(label, err);
      });

    try {
      const maybeExecCtx = (activeCtx as Context | undefined)?.executionCtx;
      if (maybeExecCtx && typeof maybeExecCtx.waitUntil === 'function') {
        maybeExecCtx.waitUntil(task);
      }
    } catch {
      // Hono executionCtx getter throws outside Cloudflare Workers runtime
    }
  }

  public async awaitWriteThrough(
    label: string,
    op: (driver: SupabaseCloudDriver) => Promise<unknown>,
    cOrEnv?: unknown,
  ): Promise<boolean> {
    const driver = this.resolveCloudDriver(cOrEnv);
    if (!driver.isConfigured()) return false;
    try {
      await op(driver);
      return true;
    } catch (err) {
      this.recordWriteThroughFailure(label, err);
      return false;
    }
  }
```

#### D. Shared Row Hydration Helpers (Including Fixed `reel_comments` & `explore_tracks`)

Extract clean, reusable row-hydration helpers invoked by BOTH `ensureColdStartHydrated` and the 5 domain-scoped `sync*FromCloud` methods:

```ts
  private hydrateExploreTrackRows(exploreRows: Array<Record<string, any>>): void {
    for (const t of exploreRows) {
      if (!t.id) continue;
      const updatedIso = new Date(Number(t.updated_at || Date.now())).toISOString();
      const createdIso = new Date(
        Number(t.created_at || t.updated_at || Date.now()),
      ).toISOString();
      const stems =
        t.stems_json && typeof t.stems_json === 'object' ? t.stems_json : {};
      const parsedData =
        t.data_json && typeof t.data_json === 'object'
          ? (t.data_json as Record<string, any>)
          : {};
      const normalizedMoodId = normalizeVhunambiMoodId(
        t.mood_id ?? parsedData.moodId ?? t.mood ?? parsedData.mood,
      );
      const description = String(t.description ?? parsedData.description ?? '');
      const allowOpenStemsRemix = Boolean(
        t.allow_open_stems_remix ?? parsedData.allowOpenStemsRemix ?? false,
      );
      const playsCount = Number(t.plays_count ?? parsedData.playCount ?? 0);
      const discoveryStage = String(
        t.discovery_stage ??
          parsedData.discoveryStage ??
          (playsCount >= 8000
            ? 'mainstage'
            : playsCount >= 1500
              ? 'risingBreakout'
              : 'freshCrate'),
      );
      const moodLabel = String(t.mood ?? parsedData.mood ?? 'Vibrant');
      const languageLabel = String(t.language ?? parsedData.language ?? 'isiZulu');

      this.exploreTracks.set(String(t.id), {
        id: String(t.id),
        title: String(t.title ?? 'Untitled Track'),
        artist_name: String(t.artist ?? 'Vhunambi Creator'),
        artist_id: canonicalizeCreatorId(String(t.creator_id ?? 'creator_cern')),
        genre: String(t.genre ?? 'Amapiano'),
        language: languageLabel,
        audio_url: String(t.audio_url ?? ''),
        bpm: Number(t.bpm ?? 113),
        play_count: playsCount,
        like_count: Number(t.likes_count ?? parsedData.likeCount ?? 0),
        cosign_count: Number(t.cosigns_count ?? parsedData.cosignCount ?? 0),
        discovery_stage: discoveryStage,
        mood_id: normalizedMoodId,
        description,
        allow_open_stems_remix: allowOpenStemsRemix ? 1 : 0,
        data_json: JSON.stringify({
          ...parsedData,
          subGenre: t.sub_genre ?? parsedData.subGenre ?? '',
          province: t.region ?? parsedData.province ?? 'South Africa',
          mood: moodLabel,
          moodId: normalizedMoodId,
          language: languageLabel,
          description,
          allowOpenStemsRemix,
          musicalKey: t.musical_key ?? parsedData.musicalKey ?? 'Am',
          coverUrl: t.cover_url ?? parsedData.coverUrl ?? '',
          durationMs: Number(t.duration_sec ?? 180) * 1000,
          stemsAvailable: Object.keys(stems).length > 0,
          isNew: Boolean(t.is_featured ?? parsedData.isNew ?? false),
        }),
        created_at: createdIso,
        updated_at: updatedIso,
      });
    }
  }

  private hydrateKineticPostRows(postsRows: Array<Record<string, any>>): void {
    for (const kp of postsRows) {
      if (!kp.id) continue;
      const dataObj =
        kp.data_json && typeof kp.data_json === 'object'
          ? (kp.data_json as Record<string, any>)
          : {};
      this.kineticPosts.set(String(kp.id), {
        id: String(kp.id),
        creator_id: String(kp.creator_id ?? 'creator_cern'),
        creator_handle: String(kp.creator_handle ?? '@cern'),
        creator_name: String(kp.creator_name ?? 'Cern'),
        caption: String(kp.caption ?? ''),
        media_type: String(dataObj.mediaType ?? 'audio_card'),
        like_count: Number(kp.like_count ?? dataObj.likeCount ?? 0),
        comment_count: Number(kp.comment_count ?? dataObj.commentCount ?? 0),
        cosign_count: Number(kp.cosign_count ?? 0),
        cosign_target: Number(dataObj.cosignTarget ?? 25),
        repost_count: Number(kp.repost_count ?? 0),
        discovery_stage: String(kp.discovery_stage ?? 'freshCrate'),
        data_json:
          typeof kp.data_json === 'string' ? kp.data_json : JSON.stringify(dataObj),
        created_at: new Date(Number(kp.created_at || Date.now())).toISOString(),
        updated_at: new Date(Number(kp.updated_at || Date.now())).toISOString(),
      });
    }
  }

  private hydrateReelCommentRows(commentsRows: Array<Record<string, any>>): void {
    for (const rc of commentsRows) {
      if (!rc.id) continue;
      const parsed =
        rc.data_json && typeof rc.data_json === 'object'
          ? (rc.data_json as Record<string, any>)
          : {};
      const createdIso = new Date(Number(rc.timestamp_ms || Date.now())).toISOString();
      const parentCommentId = rc.parent_comment_id ?? parsed.parentCommentId ?? null;
      const replyToHandle = rc.reply_to_handle ?? parsed.replyToHandle ?? null;
      const likesCount = Number(rc.likes_count ?? parsed.likeCount ?? 0);
      const userId = String(rc.user_id ?? parsed.userId ?? 'creator_cern');
      const username = String(
        rc.username ?? parsed.username ?? `@${userId.replace(/^creator_/, '')}`,
      );
      const displayName = String(
        rc.display_name ?? parsed.displayName ?? parsed.creatorName ?? 'Creator',
      );
      const avatarUrl = String(rc.avatar_url ?? parsed.avatarUrl ?? '');
      const isCreator = Boolean(rc.is_creator ?? parsed.isCreator ?? false);

      this.reelComments.set(String(rc.id), {
        id: String(rc.id),
        reel_id: String(rc.clip_id),
        creator_id: userId,
        username,
        display_name: displayName,
        avatar_url: avatarUrl,
        is_creator: isCreator,
        likes_count: likesCount,
        content: String(rc.text ?? ''),
        language_code: parsed.languageCode ? String(parsed.languageCode) : null,
        parent_comment_id: parentCommentId,
        reply_to_handle: replyToHandle,
        data_json: JSON.stringify({
          ...parsed,
          id: String(rc.id),
          clipId: String(rc.clip_id),
          userId,
          username,
          displayName,
          avatarUrl,
          isCreator,
          text: String(rc.text ?? ''),
          likeCount: likesCount,
          userReelLoves: Number(rc.user_reel_loves ?? parsed.userReelLoves ?? 0),
          ...(rc.gift_emoji ? { giftEmoji: String(rc.gift_emoji) } : {}),
          ...(rc.gift_name ? { giftName: String(rc.gift_name) } : {}),
          ...(parentCommentId ? { parentCommentId: String(parentCommentId) } : {}),
          ...(replyToHandle ? { replyToHandle: String(replyToHandle) } : {}),
          createdAt: parsed.createdAt ?? createdIso,
        }),
        created_at: createdIso,
      });
    }
  }

  private hydrateNotificationRows(notificationRows: Array<Record<string, any>>): void {
    for (const nr of notificationRows) {
      if (!nr.id) continue;
      const id = String(nr.id);
      const cid = canonicalizeCreatorId(String(nr.user_id ?? 'creator_cern'));
      const metaObj =
        nr.metadata_json && typeof nr.metadata_json === 'object'
          ? (nr.metadata_json as Record<string, any>)
          : {};
      this.notifications.set(id, {
        id,
        userId: cid,
        title: String(nr.title ?? 'Notification'),
        message: String(nr.body ?? nr.message ?? ''),
        body: String(nr.body ?? nr.message ?? ''),
        category: (nr.category as NotificationRecord['category']) ?? 'creatorActivity',
        subtype: nr.subtype ? String(nr.subtype) : null,
        priority: (nr.priority as NotificationRecord['priority']) ?? 'normal',
        isRead: Boolean(nr.is_read),
        targetRoute: nr.target_route ? String(nr.target_route) : null,
        targetEntityId: nr.target_entity_id ? String(nr.target_entity_id) : null,
        ctaLabel: nr.cta_label ? String(nr.cta_label) : null,
        metadata: metaObj,
        createdAt: String(nr.created_at ?? new Date().toISOString()),
      });
    }
  }

  private hydrateCreatorQuotaRows(quotaRows: Array<Record<string, any>>): void {
    for (const qr of quotaRows) {
      if (!qr.user_id) continue;
      const cid = canonicalizeCreatorId(String(qr.user_id));
      const limit = Number(qr.free_monthly_songs_limit ?? 10);
      const used = Number(qr.free_monthly_songs_used ?? 0);
      this.creatorQuotas.set(cid, {
        userId: cid,
        planTier: String(qr.plan_tier ?? 'free'),
        freeMonthlySongsLimit: limit,
        freeMonthlySongsUsed: used,
        freeMonthlySongsRemaining: Math.max(0, limit - used),
        cycleResetAt: String(
          qr.cycle_reset_at ??
            new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
        ),
        updatedAt: String(qr.updated_at ?? new Date().toISOString()),
      });
    }
  }
```

#### E. Fixed `mapReelCommentRow` (`#L5507-L5529`)

Preserve `likes_count`, `username`, `display_name`, `avatar_url`, and `is_creator`:

```ts
  private mapReelCommentRow(r: Record<string, any>): Record<string, any> {
    let data: Record<string, any> = {};
    try {
      data = JSON.parse(String(r.data_json || '{}'));
    } catch {
      data = {};
    }
    const parentCommentId =
      data.parentCommentId ?? r.parent_comment_id ?? undefined;
    const replyToHandle =
      data.replyToHandle ?? r.reply_to_handle ?? undefined;
    const userId = String(data.userId ?? r.creator_id);
    const username = String(
      data.username ?? r.username ?? `@${userId.replace(/^creator_/, '')}`,
    );
    const displayName = String(
      data.displayName ?? r.display_name ?? data.creatorName ?? 'Creator',
    );
    const avatarUrl = String(data.avatarUrl ?? r.avatar_url ?? '');
    const isCreator = Boolean(data.isCreator ?? r.is_creator ?? false);
    const likeCount = Number(r.likes_count ?? data.likeCount ?? 0);

    return {
      ...data,
      id: String(r.id),
      clipId: String(data.clipId ?? r.reel_id),
      userId,
      username,
      displayName,
      avatarUrl,
      isCreator,
      text: String(data.text ?? r.content),
      likeCount,
      ...(parentCommentId ? { parentCommentId: String(parentCommentId) } : {}),
      ...(replyToHandle ? { replyToHandle: String(replyToHandle) } : {}),
      createdAt: String(data.createdAt ?? r.created_at),
    };
  }
```

#### F. Domain-Scoped SWR Sync Helpers (`EP-P71-EDGE-SWR-READTHROUGH`)

```ts
  public async syncNotificationsFromCloud(
    userId: string,
    cOrEnv?: unknown,
  ): Promise<NotificationRecord[]> {
    const cid = canonicalizeCreatorId(userId);
    const driver = this.resolveCloudDriver(cOrEnv);
    if (!driver.isConfigured()) {
      return this.listNotifications(cid);
    }
    const domainKey = `notifications:${cid}`;
    const res = await EdgeIsolateDatabaseEngine.withTimeoutResult(
      driver.selectRows<Record<string, any>>(
        'notifications',
        `select=*&user_id=eq.${encodeURIComponent(cid)}&order=created_at.desc&limit=500`,
      ),
      3500,
    );
    if (res.ok) {
      this.hydrateNotificationRows(res.value);
      this.domainHydratedAtMs.set(domainKey, Date.now());
    }
    return this.listNotifications(cid);
  }

  public async syncCreatorQuotaFromCloud(
    userId: string,
    cOrEnv?: unknown,
  ): Promise<CreatorQuotaRecord> {
    const cid = canonicalizeCreatorId(userId);
    const driver = this.resolveCloudDriver(cOrEnv);
    if (!driver.isConfigured()) {
      return this.getCreatorQuota(cid);
    }
    const domainKey = `quota:${cid}`;
    const res = await EdgeIsolateDatabaseEngine.withTimeoutResult(
      driver.selectRows<Record<string, any>>(
        'creator_quotas',
        `select=*&user_id=eq.${encodeURIComponent(cid)}&limit=1`,
      ),
      3000,
    );
    if (res.ok) {
      this.hydrateCreatorQuotaRows(res.value);
      this.domainHydratedAtMs.set(domainKey, Date.now());
    }
    return this.getCreatorQuota(cid);
  }

  public async syncGenerationJobFromCloud(
    genId: string,
    cOrEnv?: unknown,
  ): Promise<GenerationJob | null> {
    const driver = this.resolveCloudDriver(cOrEnv);
    if (!driver.isConfigured()) {
      return this.getGenerationJob(genId);
    }
    const domainKey = `generation:${genId}`;
    const res = await EdgeIsolateDatabaseEngine.withTimeoutResult(
      driver.selectRows<Record<string, any>>(
        'generation_jobs',
        `select=*&generation_id=eq.${encodeURIComponent(genId)}&limit=1`,
      ),
      3000,
    );
    if (res.ok) {
      this.domainHydratedAtMs.set(domainKey, Date.now());
      const gj = res.value[0];
      if (gj && gj.generation_id) {
        const existing = this.generationJobs.get(genId);
        const remoteStatus = String(gj.status ?? 'queued');
        const remoteUpdatedMs = Number(gj.updated_at || 0);
        const existingUpdatedMs = existing?.job.updatedAt.getTime() ?? 0;
        if (
          !existing ||
          (remoteStatus === 'succeeded' && existing.job.status !== 'succeeded') ||
          (remoteStatus === 'failed' && existing.job.status !== 'failed') ||
          remoteUpdatedMs >= existingUpdatedMs
        ) {
          const mapped = this.mapSupabaseGenerationJobRow(gj, existing?.job);
          this.generationJobs.set(mapped.generationId, {
            job: mapped,
            creatorId: canonicalizeCreatorId(
              String(gj.creator_id ?? existing?.creatorId ?? 'creator_cern'),
            ),
            jobKind: String(gj.job_kind ?? existing?.jobKind ?? 'audio_synthesis'),
          });
          return mapped;
        }
      }
    }
    return this.getGenerationJob(genId);
  }

  public async syncExploreFromCloud(
    force = false,
    cOrEnv?: unknown,
  ): Promise<boolean> {
    const driver = this.resolveCloudDriver(cOrEnv);
    if (!driver.isConfigured()) return false;

    const domainKey = 'explore:global';
    const lastHydrated = this.domainHydratedAtMs.get(domainKey) ?? 0;
    if (
      !force &&
      lastHydrated > 0 &&
      Date.now() - lastHydrated < EdgeIsolateDatabaseEngine.DEFAULT_SWR_TTL_MS
    ) {
      return true;
    }

    const existingFlight = this.domainInFlightPromises.get(domainKey);
    if (existingFlight && !force) {
      return existingFlight;
    }

    const syncPromise = (async (): Promise<boolean> => {
      const [tracksRes, postsRes, commentsRes] = await Promise.all([
        EdgeIsolateDatabaseEngine.withTimeoutResult(
          driver.selectRows<Record<string, any>>(
            'explore_tracks',
            'select=*&order=updated_at.desc&limit=200',
          ),
          3500,
        ),
        EdgeIsolateDatabaseEngine.withTimeoutResult(
          driver.selectRows<Record<string, any>>(
            'kinetic_posts',
            'select=*&order=created_at.desc&limit=200',
          ),
          3500,
        ),
        EdgeIsolateDatabaseEngine.withTimeoutResult(
          driver.selectRows<Record<string, any>>(
            'reel_comments',
            'select=*&order=timestamp_ms.desc&limit=400',
          ),
          3500,
        ),
      ]);

      if (tracksRes.ok) this.hydrateExploreTrackRows(tracksRes.value);
      if (postsRes.ok) this.hydrateKineticPostRows(postsRes.value);
      if (commentsRes.ok) this.hydrateReelCommentRows(commentsRes.value);

      const allSucceeded = tracksRes.ok && postsRes.ok && commentsRes.ok;
      if (allSucceeded) {
        this.domainHydratedAtMs.set(domainKey, Date.now());
      }
      return allSucceeded;
    })().finally(() => {
      if (this.domainInFlightPromises.get(domainKey) === syncPromise) {
        this.domainInFlightPromises.delete(domainKey);
      }
    });

    this.domainInFlightPromises.set(domainKey, syncPromise);
    return syncPromise;
  }

  public async syncCreatorWalletFromCloud(
    creatorId: string,
    cOrEnv?: unknown,
  ): Promise<boolean> {
    const cid = canonicalizeCreatorId(creatorId);
    const driver = this.resolveCloudDriver(cOrEnv);
    if (!driver.isConfigured()) return false;

    const domainKey = `wallet:${cid}`;
    const [walletRes, bankRes, topupRes] = await Promise.all([
      EdgeIsolateDatabaseEngine.withTimeoutResult(
        driver.selectRows<Record<string, any>>(
          'wallet_ledger',
          `select=*&creator_id=eq.${encodeURIComponent(cid)}&order=created_at.desc&limit=500`,
        ),
        3500,
      ),
      EdgeIsolateDatabaseEngine.withTimeoutResult(
        driver.selectRows<Record<string, any>>(
          'bank_accounts',
          `select=*&creator_id=eq.${encodeURIComponent(cid)}&limit=50`,
        ),
        3500,
      ),
      EdgeIsolateDatabaseEngine.withTimeoutResult(
        driver.selectRows<Record<string, any>>(
          'payment_topups',
          `select=*&creator_id=eq.${encodeURIComponent(cid)}&order=created_at.desc&limit=100`,
        ),
        3500,
      ),
    ]);

    if (walletRes.ok) {
      const mapped = walletRes.value
        .filter((wl) => Boolean(wl.id))
        .map((wl) => ({
          id: String(wl.id),
          creator_id: cid,
          type: String(wl.type ?? 'topup'),
          amount_zar: Number(wl.amount_zar ?? 0),
          amount_coins: Number(wl.amount_coins ?? 0),
          status: String(wl.status ?? 'completed'),
          reference: String(wl.reference ?? ''),
          data_json:
            typeof wl.metadata_json === 'string'
              ? wl.metadata_json
              : JSON.stringify(wl.metadata_json ?? {}),
          created_at: String(wl.created_at ?? new Date().toISOString()),
        }));
      const existingList = this.walletLedger.get(cid) ?? [];
      const seenIds = new Set(mapped.map((r) => String(r.id)));
      this.walletLedger.set(cid, [
        ...mapped,
        ...existingList.filter((r) => !seenIds.has(String(r.id))),
      ]);
    }
    if (bankRes.ok) {
      for (const ba of bankRes.value) {
        if (!ba.id) continue;
        this.bankAccounts.set(String(ba.id), {
          id: String(ba.id),
          creatorId: cid,
          bankName: String(ba.bank_name ?? ''),
          branchCode: String(ba.branch_code ?? ''),
          maskedAccount: String(ba.account_number_masked ?? ''),
          paymentRail: String(ba.payout_rail ?? 'payfast'),
          accountHolder: ba.account_holder ? String(ba.account_holder) : null,
          updatedAt: String(ba.updated_at ?? new Date().toISOString()),
        });
      }
    }
    if (topupRes.ok) {
      for (const pt of topupRes.value) {
        if (!pt.checkout_id) continue;
        this.payfastCheckouts.set(String(pt.checkout_id), {
          checkoutId: String(pt.checkout_id),
          creatorId: cid,
          provider: String(pt.provider ?? 'payfast'),
          providerPaymentId: pt.provider_payment_id ? String(pt.provider_payment_id) : null,
          packId: String(pt.pack_id ?? 'pack_producer_1500'),
          amountZar: Number(pt.amount_zar ?? 0),
          coinsGranted: Number(pt.coins_granted ?? 0),
          status: String(pt.status ?? 'pending'),
          signatureMd5: String(pt.signature_md5 ?? ''),
          verifiedAt: pt.verified_at ? String(pt.verified_at) : null,
          createdAt: String(pt.created_at ?? new Date().toISOString()),
        });
        if (pt.provider_payment_id) {
          this.payfastByPfId.set(String(pt.provider_payment_id), String(pt.checkout_id));
        }
      }
    }

    const allOk = walletRes.ok && bankRes.ok && topupRes.ok;
    if (allOk) {
      this.domainHydratedAtMs.set(domainKey, Date.now());
    }
    return allOk;
  }
```

#### G. Atomic Quota RPC + Awaited Critical Writes + Track Like & Parity Mirrors

```ts
  public async consumeFreeMonthlySongQuotaAsync(
    userId: string,
    cOrEnv?: unknown,
  ): Promise<AtomicQuotaConsumeResult> {
    const cid = canonicalizeCreatorId(userId);
    const driver = this.resolveCloudDriver(cOrEnv);
    if (driver.isConfigured()) {
      try {
        const rpcRes = await driver.callRpc<Record<string, any>>(
          'consume_free_monthly_song_quota_atomic',
          { p_user_id: cid },
        );
        if (rpcRes && typeof rpcRes === 'object') {
          const limit = Number(rpcRes.freeMonthlySongsLimit ?? 10);
          const used = Number(rpcRes.freeMonthlySongsUsed ?? 0);
          const remaining = Number(
            rpcRes.freeMonthlySongsRemaining ?? Math.max(0, limit - used),
          );
          const record: CreatorQuotaRecord = {
            userId: cid,
            planTier: String(rpcRes.planTier ?? 'free'),
            freeMonthlySongsLimit: limit,
            freeMonthlySongsUsed: used,
            freeMonthlySongsRemaining: remaining,
            cycleResetAt: String(
              rpcRes.cycleResetAt ??
                new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
            ),
            updatedAt: String(rpcRes.updatedAt ?? new Date().toISOString()),
          };
          this.creatorQuotas.set(cid, record);
          this.domainHydratedAtMs.set(`quota:${cid}`, Date.now());
          return {
            ...record,
            allowed: Boolean(rpcRes.allowed ?? true),
          };
        }
      } catch (err) {
        this.recordWriteThroughFailure('creator_quotas.consume_atomic_rpc', err);
      }
    }

    const before = this.getCreatorQuota(cid);
    const isPaid =
      before.planTier.toLowerCase() !== 'free' || before.freeMonthlySongsLimit < 0;
    const allowed = isPaid || before.freeMonthlySongsUsed < before.freeMonthlySongsLimit;
    const updated = allowed ? this.consumeFreeMonthlySongQuota(cid) : before;
    return { ...updated, allowed };
  }

  public async upsertNotificationAsync(
    input: UpsertNotificationInput,
    cOrEnv?: unknown,
  ): Promise<NotificationRecord> {
    const cid = canonicalizeCreatorId(input.userId);
    const existing = this.notifications.get(input.id);
    const record: NotificationRecord = {
      id: input.id,
      userId: cid,
      title: input.title,
      message: input.message,
      body: input.message,
      category: input.category ?? existing?.category ?? 'creatorActivity',
      subtype:
        input.subtype !== undefined ? input.subtype : (existing?.subtype ?? null),
      priority: input.priority ?? existing?.priority ?? 'normal',
      isRead: existing ? existing.isRead : Boolean(input.isRead ?? false),
      targetRoute:
        input.targetRoute !== undefined
          ? input.targetRoute
          : (existing?.targetRoute ?? null),
      targetEntityId:
        input.targetEntityId !== undefined
          ? input.targetEntityId
          : (existing?.targetEntityId ?? null),
      ctaLabel:
        input.ctaLabel !== undefined ? input.ctaLabel : (existing?.ctaLabel ?? null),
      metadata: input.metadata ?? existing?.metadata ?? {},
      createdAt: input.createdAt ?? existing?.createdAt ?? new Date().toISOString(),
    };
    this.notifications.set(record.id, record);
    await this.awaitWriteThrough(
      'notifications.upsert',
      async (driver) => {
        await driver.upsertRow(
          'notifications',
          {
            id: record.id,
            user_id: record.userId,
            title: record.title,
            body: record.body,
            category: record.category,
            subtype: record.subtype,
            priority: record.priority,
            is_read: record.isRead,
            target_route: record.targetRoute,
            target_entity_id: record.targetEntityId,
            cta_label: record.ctaLabel,
            metadata_json: record.metadata,
            created_at: record.createdAt,
          },
          'id',
        );
      },
      cOrEnv,
    );
    return record;
  }

  public async upsertGenerationJobAsync(
    job: GenerationJob,
    creatorId = 'creator_cern',
    jobKind = 'audio_synthesis',
    cOrEnv?: unknown,
  ): Promise<void> {
    const existing = this.generationJobs.get(job.generationId);
    const merged: GenerationJob = {
      ...existing?.job,
      ...job,
      providerTaskId: job.providerTaskId ?? existing?.job.providerTaskId,
      masterMp3Url: job.masterMp3Url ?? existing?.job.masterMp3Url,
      stemsZipUrl: job.stemsZipUrl ?? existing?.job.stemsZipUrl,
      stemUrls: job.stemUrls ?? existing?.job.stemUrls,
      manifestUrl: job.manifestUrl ?? existing?.job.manifestUrl,
      manifest: job.manifest ?? existing?.job.manifest,
      visionMeta: job.visionMeta ?? existing?.job.visionMeta,
      coverUrl: job.coverUrl ?? existing?.job.coverUrl,
      lyrics: job.lyrics ?? existing?.job.lyrics,
    };
    const effectiveCreatorId = canonicalizeCreatorId(creatorId);
    this.generationJobs.set(job.generationId, {
      job: merged,
      creatorId: effectiveCreatorId,
      jobKind,
    });
    const manifestPayload =
      merged.manifest || merged.visionMeta
        ? {
            ...(merged.manifest ?? {}),
            ...(merged.visionMeta ? { visionMeta: merged.visionMeta } : {}),
          }
        : null;
    await this.awaitWriteThrough(
      'generation_jobs.upsert',
      async (driver) => {
        await driver.upsertRow(
          'generation_jobs',
          {
            generation_id: merged.generationId,
            creator_id: effectiveCreatorId,
            job_kind: jobKind,
            provider_task_id: merged.providerTaskId ?? null,
            status: merged.status,
            step: merged.step,
            progress_pct: Math.round(Number(merged.progressPct ?? 0)),
            track_title: merged.trackTitle || 'Untitled Track',
            genre: merged.genre || 'Amapiano',
            language: merged.language || 'Instrumental',
            duration_sec: Math.round(Number(merged.durationSec ?? 180)),
            master_mp3_url: merged.masterMp3Url ?? null,
            stems_zip_url: merged.stemsZipUrl ?? null,
            stem_urls_json: merged.stemUrls ?? {},
            manifest_url: merged.manifestUrl ?? null,
            manifest_json: manifestPayload,
            error_message: merged.errorMessage ?? null,
            created_at: merged.createdAt ? merged.createdAt.getTime() : Date.now(),
            updated_at: merged.updatedAt ? merged.updatedAt.getTime() : Date.now(),
          },
          'generation_id',
        );
      },
      cOrEnv,
    );
  }
```

And in `mapSupabaseGenerationJobRow` (`#L4980-L5033`), preserve `visionMeta`:

```ts
    const rawManifestObj =
      gj.manifest_json && typeof gj.manifest_json === 'object'
        ? (gj.manifest_json as Record<string, any>)
        : undefined;
    const visionMeta =
      rawManifestObj?.visionMeta && typeof rawManifestObj.visionMeta === 'object'
        ? (rawManifestObj.visionMeta as Record<string, unknown>)
        : existingJob?.visionMeta;
```

And in `applyMutationsBatch` (`#L1777-L1780`), mirror track likes to Supabase `explore_tracks.likes_count`:

```ts
          } else if (m.entityType === 'track') {
            const t = this.exploreTracks.get(entityId);
            if (t) {
              t.like_count = Number(t.like_count ?? 0) + 1;
              t.updated_at = new Date().toISOString();
              this.mirrorWriteThrough('explore_tracks.like', async (driver) => {
                await driver.patchRows(
                  'explore_tracks',
                  `id=eq.${encodeURIComponent(entityId)}`,
                  { likes_count: t.like_count, updated_at: Date.now() },
                );
              });
            }
          }
```

And in `upsertExploreTrack` (`#L2474-L2502`), include parity columns `mood`, `language`, `discovery_stage`, `data_json`, `created_at`:

```ts
          mood: String(dataJson.mood ?? 'Vibrant'),
          language: row.language,
          discovery_stage: stage,
          mood_id: normalizedMoodId,
          description,
          allow_open_stems_remix: allowOpenStemsRemix,
          data_json: dataJson,
          created_at: Date.parse(row.created_at) || Date.now(),
          updated_at: Date.now(),
```

And in `syncLibraryTracks` (`#L3094-L3121`), include parity columns `item_type` and `created_at`:

```ts
            item_type: itemType,
            created_at: Date.parse(createdAt) || incomingUpdatedAtMs,
```

Finally, update `ensureColdStartHydrated` (`#L550-L1086`) to:
- Check `this.domainHydratedAtMs.has('cold_start:core')` instead of `this.coldStartHydrated`.
- Use `withTimeoutResult` per query so a timeout or caught error NEVER stamps `'cold_start:core'` or any failed domain key as fresh!
- Reuse `this.hydrateExploreTrackRows`, `this.hydrateKineticPostRows`, `this.hydrateReelCommentRows`, `this.hydrateNotificationRows`, and `this.hydrateCreatorQuotaRows`.

### 2.3 `VhunambiDatabase` Matching Async / Sync Methods (`apps/vhunambi_api/src/db/vhunambi_db.ts`)

Because `vhunambiDb` is typed as `VhunambiDatabase` (wrapping `EdgeIsolateDatabaseEngine` transparently via Proxy when `isNodeSqliteAvailable() === false`), add matching methods to `VhunambiDatabase` in `vhunambi_db.ts` (and re-export `AtomicQuotaConsumeResult`, `WriteThroughFailureRecord`):

```ts
  public getWriteThroughFailures(): WriteThroughFailureRecord[] {
    return [];
  }

  public async syncNotificationsFromCloud(
    userId: string,
    _cOrEnv?: unknown,
  ): Promise<NotificationRecord[]> {
    return this.listNotifications(userId);
  }

  public async syncCreatorQuotaFromCloud(
    userId: string,
    _cOrEnv?: unknown,
  ): Promise<CreatorQuotaRecord> {
    return this.getCreatorQuota(userId);
  }

  public async syncGenerationJobFromCloud(
    genId: string,
    _cOrEnv?: unknown,
  ): Promise<GenerationJob | null> {
    return this.getGenerationJob(genId);
  }

  public async syncExploreFromCloud(
    _force = false,
    _cOrEnv?: unknown,
  ): Promise<boolean> {
    return false;
  }

  public async syncCreatorWalletFromCloud(
    _creatorId: string,
    _cOrEnv?: unknown,
  ): Promise<boolean> {
    return false;
  }

  public async consumeFreeMonthlySongQuotaAsync(
    userId: string,
    _cOrEnv?: unknown,
  ): Promise<AtomicQuotaConsumeResult> {
    const before = this.getCreatorQuota(userId);
    const isPaid =
      before.planTier.toLowerCase() !== 'free' || before.freeMonthlySongsLimit < 0;
    const allowed =
      isPaid || before.freeMonthlySongsUsed < before.freeMonthlySongsLimit;
    const updated = allowed ? this.consumeFreeMonthlySongQuota(userId) : before;
    return { ...updated, allowed };
  }

  public async upsertNotificationAsync(
    input: UpsertNotificationInput,
    _cOrEnv?: unknown,
  ): Promise<NotificationRecord> {
    return this.upsertNotification(input);
  }

  public async upsertGenerationJobAsync(
    job: GenerationJob,
    creatorId = 'creator_cern',
    jobKind = 'audio_synthesis',
    _cOrEnv?: unknown,
  ): Promise<void> {
    this.upsertGenerationJob(job, creatorId, jobKind);
  }
```

Also update `VhunambiDatabase.upsertGenerationJob` & `VhunambiDatabase.mapGenerationJobRow` to persist and restore `job.visionMeta` inside `manifest_json` (under `visionMeta`), maintaining 100% SQLite-to-Edge parity!

---

## 3. Overhaul Pass 1 (`M71.1`): Worker Route Integration

### 3.1 `apps/vhunambi_api/src/server.ts`

Keep `EdgePersistenceBridge.setActiveContext(c)` for every request, and avoid running the monolithic 21-table cold-start wall on routes that perform targeted domain read-through (`/api/notifications`, `/api/wallet`, `/api/explore`, `/v1/generations`, `/v1/vision`, `/v1/webhooks`):

```ts
app.use('*', async (c, next) => {
  EdgePersistenceBridge.setActiveContext(c);
  try {
    const p = c.req.path;
    const hasScopedReadThrough =
      p.startsWith('/api/notifications') ||
      p.startsWith('/api/v1/notifications') ||
      p.startsWith('/api/wallet') ||
      p.startsWith('/api/v1/wallet') ||
      p.startsWith('/api/explore') ||
      p.startsWith('/api/v1/explore') ||
      p.startsWith('/v1/generations') ||
      p.startsWith('/v1/vision') ||
      p.startsWith('/v1/webhooks');

    if (
      !isNodeSqliteAvailable() &&
      !hasScopedReadThrough &&
      (p.startsWith('/api') || p.startsWith('/v1'))
    ) {
      await getEdgeIsolateDatabaseEngine().ensureColdStartHydrated(c);
    }
    return await next();
  } finally {
    EdgePersistenceBridge.setActiveContext(undefined);
  }
});
```

### 3.2 `apps/vhunambi_api/src/routes/notification_routes.ts`

- `GET /`: Make handler `async`, call `const notifications = await vhunambiDb.syncNotificationsFromCloud(creatorId, c);` and `const quota = await vhunambiDb.syncCreatorQuotaFromCloud(creatorId, c);`.
- `POST /`: Call `const saved = await vhunambiDb.upsertNotificationAsync({ ... }, c);`.

### 3.3 `apps/vhunambi_api/src/routes/wallet_routes.ts`

- `GET /allowance`: Make handler `async`, call `const quota = await vhunambiDb.syncCreatorQuotaFromCloud(creatorId, c);`.
- `GET /:creatorId`: Make handler `async`, call `await vhunambiDb.syncCreatorWalletFromCloud(creatorId, c);` before `vhunambiDb.getWallet(creatorId)`.
- `POST /payout`: Call `await vhunambiDb.syncCreatorWalletFromCloud(creatorId, c);` before `vhunambiDb.requestPayout(...)`.

### 3.4 `apps/vhunambi_api/src/routes/explore_routes.ts`

- Make `GET /`, `GET /tracks`, `GET /feed`, `GET /posts/:id`, and `GET /posts/:id/comments` `async`, awaiting `await vhunambiDb.syncExploreFromCloud(false, c);` (or `force = true` on `GET /posts/:id` cache miss) before reading from `vhunambiDb`.

### 3.5 `apps/vhunambi_api/src/routes/generation_routes.ts` & `webhook_routes.ts`

- In `generation_routes.ts`:
  - `POST /`: Replace synchronous `vhunambiDb.consumeFreeMonthlySongQuota(creatorId)` with `const quota = await vhunambiDb.consumeFreeMonthlySongQuotaAsync(creatorId, c);`, and await `vhunambiDb.upsertNotificationAsync(..., c)` for studio & low-quota alerts.
  - `GET /:id` and `GET /:id/manifest`: Call `job = (await vhunambiDb.syncGenerationJobFromCloud(id, c)) ?? job;` whenever `!job || job.status === 'queued' || job.status === 'running'`.
- In `webhook_routes.ts`:
  - Inside `POST /v1/webhooks/ace-step`, after `completeJob(generationId, ...)` or `failJob(generationId, ...)`, retrieve `const updatedJob = getJob(generationId);` (or synthesize a completed `GenerationJob` if the webhook landed on a fresh isolate that didn't create the job!) and `await vhunambiDb.upsertGenerationJobAsync(updatedJob, 'creator_cern', 'audio_synthesis', c);` so Postgres is durably updated BEFORE returning HTTP `200 { received: true }`.

### 3.6 `apps/vhunambi_api/src/routes/vision_routes.ts`

Replace volatile `visionMetaFallbackStore` with persistent `generation_jobs` storage (`visionMeta` inside `manifest_json`):

- In `POST /v1/vision/generate`:
  ```ts
    const visionMeta: Record<string, unknown> = {
      jobId: result.jobId,
      kind: 'vision',
      status: result.status,
      promptText: result.promptText,
      seed: result.seed,
      width: result.width,
      height: result.height,
      outputImageUrl: normalizedImageUrl,
    };
    const jobRecord = createJob({
      generationId: result.jobId,
      trackTitle: input.title ?? 'ComfyUI Artwork',
      genre: input.genre,
      language: input.language,
      providerTaskId: result.jobId,
      status: result.status === 'completed' ? 'succeeded' : 'queued',
      step: result.status === 'completed' ? 'ready' : 'queued',
      progressPct: result.status === 'completed' ? 100 : 10,
      masterMp3Url: normalizedImageUrl,
      visionMeta,
    });
    await vhunambiDb.upsertGenerationJobAsync(
      jobRecord,
      c.get('authUser')?.creatorId ?? 'creator_cern',
      'vision',
      c,
    );
  ```
- In `POST /v1/vision/render-video`:
  Persist `{ jobId, kind: 'render-video', status: 'completed', videoUrl: outputVideoUrl, coverUrl: outputCoverUrl, resolution: input.resolution, fps: input.fps, preset: input.preset, engine: 'RunPod-NVENC-GPU', renderedAt }` via `createJob({ ..., status: 'succeeded', step: 'ready', progressPct: 100, masterMp3Url: outputVideoUrl, coverUrl: outputCoverUrl, visionMeta })` + `await vhunambiDb.upsertGenerationJobAsync(jobRecord, ..., 'render-video', c)`.
- In `GET /v1/vision/render-video/:id` and `GET /v1/vision/:id`:
  Make both handlers `async`, read `let job = getJob(id) ?? (await vhunambiDb.syncGenerationJobFromCloud(id, c)) ?? undefined;`, extract `const meta = job?.visionMeta as VisionJobMeta | undefined;`, and remove the module-scoped `visionMetaFallbackStore` `Map` completely!

---

## 4. Overhaul Pass 1 (`M71.2`): Backend Test Hygiene & Cross-Isolate Simulation Suite

### 4.1 Relocate `phase67_notifications_quota.test.ts`

1. Delete `apps/vhunambi_api/src/phase67_notifications_quota.test.ts`.
2. Create `apps/vhunambi_api/test/phase67_notifications_quota.test.ts` using relative imports (`../src/server.js`, `../src/db/edge_persistence_bridge.js`, `../src/db/vhunambi_db.js`) and standalone `async function runPhase67Tests()` executing all 4 Phase 67 assertions with cleanup in `try/finally` (zero `node:test` runner dependency so `tsx test/phase67_notifications_quota.test.ts` executes cleanly in `npm test`).

### 4.2 Cross-Isolate Durability Simulation Suite (`apps/vhunambi_api/test/phase71_worker_supabase_readthrough.test.ts`)

```ts
import assert from 'node:assert/strict';
import {
  EdgeIsolateDatabaseEngine,
} from '../src/db/edge_persistence_bridge.js';
import type { SupabaseCloudDriver } from '../src/db/supabase_cloud_driver.js';

class MockSharedSupabaseDriver {
  public readonly tables = new Map<string, Array<Record<string, any>>>();
  public failNextSelectTable: string | null = null;
  public failNextWriteTable: string | null = null;
  public rpcCalls = 0;

  public isConfigured(): boolean {
    return true;
  }

  private tableRows(table: string): Array<Record<string, any>> {
    let rows = this.tables.get(table);
    if (!rows) {
      rows = [];
      this.tables.set(table, rows);
    }
    return rows;
  }

  private primaryKeyFor(table: string): string {
    if (table === 'generation_jobs') return 'generation_id';
    if (table === 'creator_quotas') return 'user_id';
    return 'id';
  }

  public async selectRows<T = Record<string, unknown>>(
    table: string,
    queryString: string,
  ): Promise<T[]> {
    if (this.failNextSelectTable === table) {
      this.failNextSelectTable = null;
      throw new Error(`SIMULATED_TIMEOUT_${table}`);
    }
    const rows = [...this.tableRows(table)];
    const eqMatches = Array.from(queryString.matchAll(/([a-z0-9_]+)=eq\.([^&]+)/g));
    const filtered = rows.filter((row) =>
      eqMatches.every((m) => String(row[m[1]] ?? '') === decodeURIComponent(m[2])),
    );
    return filtered as T[];
  }

  public async upsertRow<T = Record<string, unknown>>(
    table: string,
    payload: Record<string, unknown> | Record<string, unknown>[],
    onConflict?: string,
  ): Promise<T[]> {
    if (this.failNextWriteTable === table) {
      this.failNextWriteTable = null;
      throw new Error(`SIMULATED_WRITE_ERROR_${table}`);
    }
    const items = Array.isArray(payload) ? payload : [payload];
    const pk = (onConflict ?? this.primaryKeyFor(table)).split(',')[0];
    const rows = this.tableRows(table);
    for (const item of items) {
      const idx = rows.findIndex((r) => String(r[pk]) === String(item[pk]));
      if (idx >= 0) {
        rows[idx] = { ...rows[idx], ...item };
      } else {
        rows.push({ ...item });
      }
    }
    return items as T[];
  }

  public async patchRows<T = Record<string, unknown>>(
    table: string,
    filterQuery: string,
    patchBody: Record<string, unknown>,
  ): Promise<T[]> {
    if (this.failNextWriteTable === table) {
      this.failNextWriteTable = null;
      throw new Error(`SIMULATED_PATCH_ERROR_${table}`);
    }
    const eqMatches = Array.from(filterQuery.matchAll(/([a-z0-9_]+)=eq\.([^&]+)/g));
    const rows = this.tableRows(table);
    const updated: Record<string, unknown>[] = [];
    for (let i = 0; i < rows.length; i += 1) {
      const matches = eqMatches.every(
        (m) => String(rows[i][m[1]] ?? '') === decodeURIComponent(m[2]),
      );
      if (matches) {
        rows[i] = { ...rows[i], ...patchBody };
        updated.push(rows[i]);
      }
    }
    return updated as T[];
  }

  public async deleteRows<T = Record<string, unknown>>(
    table: string,
    filterQuery: string,
  ): Promise<T[]> {
    const eqMatches = Array.from(filterQuery.matchAll(/([a-z0-9_]+)=eq\.([^&]+)/g));
    const rows = this.tableRows(table);
    const remaining: Record<string, any>[] = [];
    const deleted: Record<string, any>[] = [];
    for (const r of rows) {
      const matches = eqMatches.every(
        (m) => String(r[m[1]] ?? '') === decodeURIComponent(m[2]),
      );
      if (matches) deleted.push(r);
      else remaining.push(r);
    }
    this.tables.set(table, remaining);
    return deleted as T[];
  }

  public async callRpc<T = Record<string, unknown>>(
    fnName: string,
    args: Record<string, unknown>,
  ): Promise<T> {
    this.rpcCalls += 1;
    if (fnName !== 'consume_free_monthly_song_quota_atomic') {
      throw new Error(`UNEXPECTED_RPC_${fnName}`);
    }
    const uid = String(args.p_user_id ?? 'creator_cern');
    const rows = this.tableRows('creator_quotas');
    let row = rows.find((r) => r.user_id === uid);
    if (!row) {
      row = {
        user_id: uid,
        plan_tier: 'free',
        free_monthly_songs_limit: 10,
        free_monthly_songs_used: 0,
        cycle_reset_at: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
        updated_at: new Date().toISOString(),
      };
      rows.push(row);
    }
    const limit = Number(row.free_monthly_songs_limit ?? 10);
    let used = Number(row.free_monthly_songs_used ?? 0);
    const allowed = used < limit;
    if (allowed) used += 1;
    row.free_monthly_songs_used = used;
    row.updated_at = new Date().toISOString();
    return {
      userId: uid,
      planTier: row.plan_tier,
      freeMonthlySongsLimit: limit,
      freeMonthlySongsUsed: used,
      freeMonthlySongsRemaining: Math.max(0, limit - used),
      cycleResetAt: row.cycle_reset_at,
      updatedAt: row.updated_at,
      allowed,
    } as T;
  }
}

async function runPhase71WorkerReadThroughTests(): Promise<void> {
  console.log('\nRunning Phase 71 Cross-Isolate Supabase Read/Write-Through Tests...\n');

  const sharedDriver = new MockSharedSupabaseDriver();
  const isolateA = new EdgeIsolateDatabaseEngine(
    sharedDriver as unknown as SupabaseCloudDriver,
  );
  const isolateB = new EdgeIsolateDatabaseEngine(
    sharedDriver as unknown as SupabaseCloudDriver,
  );

  // 1. Cross-isolate notifications sync (Isolate A writes -> Isolate B reads)
  await isolateA.upsertNotificationAsync({
    id: 'notif_p71_iso_1',
    userId: 'creator_p71_cross',
    title: 'Studio Master Complete',
    message: 'Your Amapiano master finished on RunPod.',
    category: 'creatorActivity',
    subtype: 'studio_render',
    targetRoute: '/track/gen_p71_01',
  });
  const isoBNotifs = await isolateB.syncNotificationsFromCloud('creator_p71_cross');
  assert.equal(isoBNotifs.length, 1);
  assert.equal(isoBNotifs[0].id, 'notif_p71_iso_1');

  // 2. Cross-isolate Kinetic Post + threaded comment projection (preserves likes_count + username)
  isolateA.upsertKineticPost({
    id: 'kpost_p71_01',
    creatorId: 'creator_p71_cross',
    creatorName: 'Vhusi',
    creatorHandle: '@vhusi',
    caption: 'Cross-isolate log drum bounce',
    trackTitle: 'Limpopo Dawn',
    genre: 'Amapiano',
  });
  isolateA.insertReelComment({
    id: 'rc_p71_01',
    clipId: 'kpost_p71_01',
    userId: 'creator_lerato',
    username: '@lerato_keys',
    displayName: 'Lerato Keys',
    avatarUrl: 'https://cdn.vhunambi.com/avatars/lerato.png',
    isCreator: true,
    text: 'Sub-bass sits cleanly!',
    likeCount: 7,
  });
  // Flush microtasks for background mirrorWriteThrough
  await new Promise((r) => setTimeout(r, 20));
  // Strip author fields from data_json in mock PG row to prove SQL column projection works
  const rawCommentRow = sharedDriver.tables
    .get('reel_comments')
    ?.find((r) => r.id === 'rc_p71_01');
  assert.ok(rawCommentRow);
  rawCommentRow!.data_json = {};

  const exploreOk = await isolateB.syncExploreFromCloud(true);
  assert.equal(exploreOk, true);
  assert.ok(isolateB.getKineticPostById('kpost_p71_01'));
  const hydratedComment = isolateB.getReelCommentById('rc_p71_01');
  assert.ok(hydratedComment);
  assert.equal(hydratedComment!.likeCount, 7);
  assert.equal(hydratedComment!.username, '@lerato_keys');
  assert.equal(hydratedComment!.displayName, 'Lerato Keys');
  assert.equal(hydratedComment!.avatarUrl, 'https://cdn.vhunambi.com/avatars/lerato.png');
  assert.equal(hydratedComment!.isCreator, true);

  // 3. RunPod webhook completion on Isolate A immediately visible on warm Isolate B
  await isolateA.upsertGenerationJobAsync(
    {
      generationId: 'gen_p71_webhook_01',
      trackTitle: 'Soweto Midnight',
      genre: 'Amapiano',
      language: 'isiZulu',
      status: 'succeeded',
      step: 'ready',
      progressPct: 100,
      masterMp3Url: 'https://r2.vhunambi.com/audio/gen_p71_webhook_01.wav',
      visionMeta: { kind: 'vision', seed: 42, width: 768, height: 1344 },
      createdAt: new Date(),
      updatedAt: new Date(),
    },
    'creator_p71_cross',
    'audio_synthesis',
  );
  const polledJob = await isolateB.syncGenerationJobFromCloud('gen_p71_webhook_01');
  assert.ok(polledJob);
  assert.equal(polledJob!.status, 'succeeded');
  assert.equal(polledJob!.visionMeta?.seed, 42);

  // 4. Atomic quota across Isolate A & Isolate B never exceeds 10 free songs
  const results = await Promise.all(
    Array.from({ length: 12 }, (_, idx) =>
      (idx % 2 === 0 ? isolateA : isolateB).consumeFreeMonthlySongQuotaAsync(
        'creator_p71_quota_race',
      ),
    ),
  );
  const allowedCount = results.filter((r) => r.allowed).length;
  assert.equal(allowedCount, 10);
  const finalQuota = await isolateB.syncCreatorQuotaFromCloud('creator_p71_quota_race');
  assert.equal(finalQuota.freeMonthlySongsUsed, 10);
  assert.equal(finalQuota.freeMonthlySongsRemaining, 0);

  // 5. Timeout/error NEVER seals freshness; write failure records in telemetry ring
  const isolateC = new EdgeIsolateDatabaseEngine(
    sharedDriver as unknown as SupabaseCloudDriver,
  );
  sharedDriver.failNextSelectTable = 'kinetic_posts';
  const failedSync = await isolateC.syncExploreFromCloud(true);
  assert.equal(failedSync, false);
  assert.equal(isolateC.getDomainHydratedAt('explore:global'), undefined);

  sharedDriver.failNextWriteTable = 'notifications';
  await isolateC.upsertNotificationAsync({
    id: 'notif_p71_fail_ring',
    userId: 'creator_p71_cross',
    title: 'Failure Ring Test',
    message: 'Simulated PostgREST error',
  });
  assert.ok(
    isolateC.getWriteThroughFailures().some((f) => f.label === 'notifications.upsert'),
  );

  // 6. applyMutationsBatch track like mirrors likes_count to explore_tracks
  isolateA.upsertExploreTrack({
    id: 'trk_p71_like_01',
    title: 'Venda Log Drum',
    artistName: 'Vhusi',
    genre: 'Amapiano',
    likeCount: 4,
  });
  await new Promise((r) => setTimeout(r, 20));
  isolateA.applyMutationsBatch(
    [
      {
        idempotencyKey: 'mut_p71_trk_like_1',
        entityType: 'track',
        entityId: 'trk_p71_like_01',
        action: 'like',
        payload: { trackId: 'trk_p71_like_01' },
      },
    ],
    'creator_p71_cross',
  );
  await new Promise((r) => setTimeout(r, 20));
  const pgTrack = sharedDriver.tables
    .get('explore_tracks')
    ?.find((t) => t.id === 'trk_p71_like_01');
  assert.equal(pgTrack?.likes_count, 5);

  console.log('ALL PHASE 71 CROSS-ISOLATE READ/WRITE-THROUGH TESTS PASSED!\n');
}

runPhase71WorkerReadThroughTests().catch((err) => {
  console.error('Phase 71 cross-isolate test failed:', err);
  process.exit(1);
});
```

### 4.3 `apps/vhunambi_api/package.json` `scripts.test`

Append `&& tsx test/phase65_foundation_resilience.test.ts && tsx test/phase67_notifications_quota.test.ts && tsx test/phase71_worker_supabase_readthrough.test.ts` to `scripts.test` (`27/27` suites).

---

## 5. Overhaul Pass 2 (`M71.3`): `EP-P67-NOTIF-API` — `HttpNotificationRepository` & `NotificationsNotifier`

### 5.1 `HttpNotificationRepository`

**Target File:** `apps/vhunambi_client/lib/features/notifications/data/repositories/http_notification_repository.dart`

```dart
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/network/sovereign_api_client.dart';
import 'package:vhunambi_client/features/notifications/domain/models/notification_entity.dart';

/// HTTP repository bridging `/api/notifications*` (`EP-P67-NOTIF-API`) with
/// `SovereignApiClient` Bearer auth and headless test guards.
class HttpNotificationRepository {
  final SovereignApiClient _apiClient;
  final String _apiRestBaseUrl;
  final bool Function() _isAuthenticated;
  final bool isTestMode;
  final bool _hasCustomClient;

  HttpNotificationRepository({
    required SovereignApiClient apiClient,
    required bool Function() isAuthenticated,
    String? apiRestBaseUrl,
    bool? isTestMode,
    bool hasCustomClient = false,
  }) : _apiClient = apiClient,
       _isAuthenticated = isAuthenticated,
       _apiRestBaseUrl = apiRestBaseUrl ?? AppConstants.apiRestBaseUrl,
       isTestMode = isTestMode ?? _detectTestMode(),
       _hasCustomClient = hasCustomClient;

  bool get shouldSkipNetwork =>
      (isTestMode && !_hasCustomClient) || !_isAuthenticated();

  static bool _detectTestMode() {
    if (const bool.fromEnvironment('FLUTTER_TEST')) return true;
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Fetches server-stored & server-emitted alerts via `GET /api/notifications`.
  /// Returns `null` when skipped/offline so local Hive entries remain intact.
  Future<List<NotificationEntity>?> fetchNotifications() async {
    if (shouldSkipNetwork) return null;
    try {
      final uri = Uri.parse('$_apiRestBaseUrl/notifications');
      final response = await _apiClient.get(
        uri,
        timeout: const Duration(seconds: 6),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final rawList =
              decoded['notifications'] as List<dynamic>? ?? const <dynamic>[];
          final parsed = <NotificationEntity>[];
          for (final item in rawList.whereType<Map>()) {
            final map = Map<String, dynamic>.from(item);
            map['message'] =
                (map['message'] as String?)?.isNotEmpty == true
                    ? map['message']
                    : (map['body'] ?? '');
            final entity = NotificationEntity.fromJson(map);
            if (entity.id.isNotEmpty) {
              parsed.add(entity);
            }
          }
          return parsed;
        }
      }
    } catch (e) {
      debugPrint('[HttpNotificationRepository] fetchNotifications fallback: $e');
    }
    return null;
  }

  /// Mirrors a local notification to `POST /api/notifications`.
  Future<bool> upsertNotification(NotificationEntity entity) async {
    if (shouldSkipNetwork || entity.id.isEmpty) return false;
    try {
      final uri = Uri.parse('$_apiRestBaseUrl/notifications');
      final payload = <String, dynamic>{
        'id': entity.id,
        'title': entity.title,
        'message': entity.message,
        'body': entity.message,
        'category': entity.category.name,
        'subtype': entity.subtype,
        'priority': entity.priority.name,
        'isRead': entity.isRead,
        'targetRoute': entity.targetRoute,
        'targetEntityId': entity.targetEntityId ?? entity.targetTrackId,
        'targetTrackId': entity.targetTrackId,
        'ctaLabel': entity.ctaLabel,
        'metadata': entity.metadata,
        'createdAt': entity.createdAt.toIso8601String(),
      };
      final response = await _apiClient.post(
        uri,
        body: jsonEncode(payload),
        timeout: const Duration(seconds: 6),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('[HttpNotificationRepository] upsertNotification fallback: $e');
      return false;
    }
  }

  /// Marks a single notification read via `PATCH /api/notifications/:id/read`.
  Future<bool> markRead(String id) async {
    if (shouldSkipNetwork || id.isEmpty) return false;
    try {
      final uri = Uri.parse(
        '$_apiRestBaseUrl/notifications/${Uri.encodeComponent(id)}/read',
      );
      final response = await _apiClient.send(
        (headers) => http.Request('PATCH', uri)
          ..headers.addAll(<String, String>{
            'Accept': 'application/json',
            ...headers,
          }),
        timeout: const Duration(seconds: 6),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('[HttpNotificationRepository] markRead fallback: $e');
      return false;
    }
  }

  /// Marks all notifications read via `POST /api/notifications/mark-all-read`.
  Future<bool> markAllRead() async {
    if (shouldSkipNetwork) return false;
    try {
      final uri = Uri.parse('$_apiRestBaseUrl/notifications/mark-all-read');
      final response = await _apiClient.post(
        uri,
        body: jsonEncode(const <String, dynamic>{}),
        timeout: const Duration(seconds: 6),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('[HttpNotificationRepository] markAllRead fallback: $e');
      return false;
    }
  }

  /// Deletes a notification via `DELETE /api/notifications/:id`.
  Future<bool> deleteNotification(String id) async {
    if (shouldSkipNetwork || id.isEmpty) return false;
    try {
      final uri = Uri.parse(
        '$_apiRestBaseUrl/notifications/${Uri.encodeComponent(id)}',
      );
      final response = await _apiClient.delete(
        uri,
        timeout: const Duration(seconds: 6),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('[HttpNotificationRepository] deleteNotification fallback: $e');
      return false;
    }
  }
}

final httpNotificationRepositoryProvider = Provider<HttpNotificationRepository>((
  ref,
) {
  final apiClient = ref.watch(sovereignApiClientProvider);
  final overrideRoot = ref.watch(sovereignAuthApiRootUrlProvider);
  final restBase = overrideRoot != null
      ? '${AppConstants.normalizeOriginUrl(overrideRoot)}/api'
      : AppConstants.apiRestBaseUrl;
  return HttpNotificationRepository(
    apiClient: apiClient,
    isAuthenticated: () => ref.read(authSessionProvider).isAuthenticated,
    apiRestBaseUrl: restBase,
  );
});
```

### 5.2 `NotificationsNotifier` Cloud Wiring (`apps/vhunambi_client/lib/features/notifications/presentation/providers/notifications_provider.dart`)

Add optional `HttpNotificationRepository? remoteRepo` to `NotificationsNotifier`:

```dart
class NotificationsNotifier extends StateNotifier<List<NotificationEntity>>
    with SafeNotifierMixin<List<NotificationEntity>> {
  final NotificationRepository _repo;
  final HttpNotificationRepository? _remoteRepo;

  NotificationsNotifier([
    List<NotificationEntity>? initial,
    NotificationRepository? repository,
    HttpNotificationRepository? remoteRepository,
  ]) : _repo = repository ?? NotificationRepository(),
       _remoteRepo = remoteRepository,
       super(
         initial ??
             _hydrateInitialNotifications(
               repository ?? NotificationRepository(),
             ),
       ) {
    if (initial == null &&
        SovereignDomainStorageMode.canHydrateFromStorage(
          AppConstants.notificationsBoxKey,
        )) {
      Future<void>.microtask(hydrateFromStorage);
    }
  }

  /// Hydrates Hive first for 0ms render, then reconciles server alerts via `EP-P67-NOTIF-API`.
  Future<void> hydrateFromStorage() async {
    await _repo.scrubLegacyDemoMocks();
    final loaded = (await _repo.getNotifications())
        .where((n) => !NotificationRepository.isLegacyDemoMockId(n.id))
        .toList();
    if (!mounted) return;
    final cleanCurrent = state
        .where((n) => !NotificationRepository.isLegacyDemoMockId(n.id))
        .toList();
    if (loaded.isNotEmpty) {
      if (cleanCurrent.isEmpty) {
        state = loaded;
      } else {
        state = _mergeNotificationLists(base: loaded, overlay: cleanCurrent);
      }
    } else if (cleanCurrent.length != state.length) {
      state = cleanCurrent;
    }
    await syncFromCloud();
  }

  /// Pulls server-emitted notifications (`GET /api/notifications`) and merges
  /// preserving local `isRead` flags without disturbing offline Hive data.
  Future<void> syncFromCloud() async {
    final remote = _remoteRepo;
    if (remote == null || remote.shouldSkipNetwork) return;
    final remoteList = await remote.fetchNotifications();
    if (!mounted || remoteList == null) return;

    final cleanRemote = remoteList
        .where((n) => !NotificationRepository.isLegacyDemoMockId(n.id))
        .toList(growable: false);
    if (cleanRemote.isEmpty) return;

    final merged = _mergeNotificationLists(base: cleanRemote, overlay: state);
    state = merged;
    await _repo.saveNotifications(merged);
  }

  static List<NotificationEntity> _mergeNotificationLists({
    required List<NotificationEntity> base,
    required List<NotificationEntity> overlay,
  }) {
    final byId = <String, NotificationEntity>{for (final n in base) n.id: n};
    for (final current in overlay) {
      if (NotificationRepository.isLegacyDemoMockId(current.id)) continue;
      final stored = byId[current.id];
      if (stored == null) {
        byId[current.id] = current;
      } else {
        byId[current.id] = stored.copyWith(
          isRead: current.isRead || stored.isRead,
        );
      }
    }
    return byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
```

Mirror mutations non-blockingly in `addNotification`, `upsertNotification`, `markAsRead`, `markAllAsRead`, and `removeNotification`:
- `addNotification`: `if (_remoteRepo != null) unawaited(_remoteRepo.upsertNotification(notification));`
- `upsertNotification`: `if (_remoteRepo != null) unawaited(_remoteRepo.upsertNotification(merged));`
- `markAsRead`: `if (_remoteRepo != null) unawaited(_remoteRepo.markRead(id));`
- `markAllAsRead`: `if (_remoteRepo != null) unawaited(_remoteRepo.markAllRead());`
- `removeNotification`: `if (_remoteRepo != null) unawaited(_remoteRepo.deleteNotification(id));`

And wire `notificationsProvider`:

```dart
final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<NotificationEntity>>((
      ref,
    ) {
      ref.watch(currentCreatorIdProvider);
      final remoteRepo = ref.watch(httpNotificationRepositoryProvider);
      return NotificationsNotifier(null, null, remoteRepo);
    });
```

---

## 6. Overhaul Pass 2 (`M71.3`): `EP-P69-POST-COSIGN-REPOST-HTTP` — Direct HTTP + Offline-Only Outbox

### 6.1 4 New Endpoints on `HttpExploreRepository` (`apps/vhunambi_client/lib/features/explore/data/repositories/http_explore_repository.dart`)

Expose `bool get shouldSkipNetwork => _shouldSkipNetwork;` and append these 4 methods:

```dart
  bool get shouldSkipNetwork => _shouldSkipNetwork;

  /// Fetches paginated Kinetic Posts feed via `GET /api/explore/feed`.
  Future<List<Map<String, dynamic>>> fetchExploreFeed({
    String? stage,
    String? genre,
    int limit = 20,
    int offset = 0,
  }) async {
    if (_shouldSkipNetwork) return const <Map<String, dynamic>>[];
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/explore/feed',
        queryParameters: <String, dynamic>{
          if (stage != null && stage.isNotEmpty) 'stage': stage,
          if (genre != null && genre.isNotEmpty && genre != 'All')
            'genre': genre,
          'limit': limit,
          'offset': offset,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final raw =
            (response.data!['posts'] ?? response.data!['items'])
                as List<dynamic>? ??
            const <dynamic>[];
        return raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      }
    } catch (e) {
      debugPrint('[HttpExploreRepository] fetchExploreFeed fallback: $e');
    }
    return const <Map<String, dynamic>>[];
  }

  /// Co-signs a Kinetic Post via `POST /api/explore/posts/:id/cosign`.
  Future<({int cosignCount, String? discoveryStage, bool graduated})?>
  cosignPost(String postId, {String? creatorId}) async {
    if (_shouldSkipNetwork) return null;
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/explore/posts/$postId/cosign',
        data: <String, dynamic>{
          if (creatorId != null && creatorId.isNotEmpty) 'creatorId': creatorId,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!;
        final postMap = data['post'] is Map
            ? Map<String, dynamic>.from(data['post'] as Map)
            : null;
        return (
          cosignCount:
              (data['cosignCount'] as num?)?.toInt() ??
              (postMap?['cosignCount'] as num?)?.toInt() ??
              0,
          discoveryStage:
              (data['discoveryStage'] ?? postMap?['discoveryStage'])
                  ?.toString(),
          graduated: (data['graduated'] as bool?) ?? false,
        );
      }
    } catch (e) {
      debugPrint('[HttpExploreRepository] cosignPost fallback: $e');
    }
    return null;
  }

  /// Reposts or quote-reposts a Kinetic Post via `POST /api/explore/posts/:id/repost`.
  Future<({int repostCount, Map<String, dynamic>? repost})?> repostPost(
    String postId, {
    Map<String, dynamic>? repost,
  }) async {
    if (_shouldSkipNetwork) return null;
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/explore/posts/$postId/repost',
        data: <String, dynamic>{if (repost != null) 'repost': repost},
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!;
        final postMap = data['post'] is Map
            ? Map<String, dynamic>.from(data['post'] as Map)
            : null;
        return (
          repostCount:
              (data['repostCount'] as num?)?.toInt() ??
              (postMap?['repostCount'] as num?)?.toInt() ??
              0,
          repost: data['repost'] is Map
              ? Map<String, dynamic>.from(data['repost'] as Map)
              : null,
        );
      }
    } catch (e) {
      debugPrint('[HttpExploreRepository] repostPost fallback: $e');
    }
    return null;
  }

  /// Likes a Kinetic Post comment via `POST /api/explore/comments/:id/like`.
  Future<({bool liked, int likeCount})?> likeComment(String commentId) async {
    if (_shouldSkipNetwork) return null;
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/explore/comments/$commentId/like',
        data: const <String, dynamic>{},
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data!;
        return (
          liked: (data['liked'] as bool?) ?? true,
          likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
        );
      }
    } catch (e) {
      debugPrint('[HttpExploreRepository] likeComment fallback: $e');
    }
    return null;
  }
```

### 6.2 `SocialFeedPostsNotifier` Direct HTTP + Offline-Only Outbox (`apps/vhunambi_client/lib/features/explore/presentation/providers/explore_providers.dart`)

1. In `refreshFromCloud`: hydrate `likeCount` and `commentCount` alongside `cosignCount` and `repostCount`:
   ```dart
      if (existing != null) {
        hydrated.add(
          existing.copyWith(
            likeCount:
                (raw['likeCount'] as num?)?.toInt() ?? existing.likeCount,
            commentCount:
                (raw['commentCount'] as num?)?.toInt() ?? existing.commentCount,
            cosignCount:
                (raw['cosignCount'] as num?)?.toInt() ?? existing.cosignCount,
            repostCount:
                (raw['repostCount'] as num?)?.toInt() ?? existing.repostCount,
          ),
        );
      } else {
        hydrated.add(
          SocialMusicPost(
            id: id,
            creatorId: (raw['creatorId'] ?? 'creator_cern').toString(),
            creatorName: (raw['creatorName'] ?? 'Creator').toString(),
            creatorHandle: (raw['creatorHandle'] ?? '@creator').toString(),
            publishedAt:
                DateTime.tryParse((raw['createdAt'] ?? '').toString()) ??
                DateTime.now(),
            caption: (raw['caption'] ?? '').toString(),
            track: Track.fromJson(<String, dynamic>{
              'id': raw['attachmentId'] ?? id,
              'title': raw['trackTitle'] ?? raw['caption'] ?? 'Cloud Post',
              'creatorName': raw['creatorName'] ?? 'Creator',
              'genre': raw['genre'] ?? 'Amapiano',
            }),
            likeCount: (raw['likeCount'] as num?)?.toInt() ?? 0,
            commentCount: (raw['commentCount'] as num?)?.toInt() ?? 0,
            cosignCount: (raw['cosignCount'] as num?)?.toInt() ?? 0,
            repostCount: (raw['repostCount'] as num?)?.toInt() ?? 0,
          ),
        );
      }
   ```
2. Add private helper `_dispatchDirectOrFallback` inside `SocialFeedPostsNotifier` so direct HTTP runs first and `_outbox?.enqueue(...)` is ONLY invoked on failure/offline (eliminating double-increment bugs):
   ```dart
  Future<void> _syncToggleLikeToCloud(String postId) async {
    final repo = repository;
    if (repo != null && !repo.shouldSkipNetwork) {
      final result = await repo.togglePostLike(postId);
      if (result != null) {
        if (!mounted) return;
        state = [
          for (final post in state)
            if (post.id == postId)
              post.copyWith(
                isLikedByMe: result.liked,
                likeCount: result.likeCount,
              )
            else
              post,
        ];
        _persistLikesSnapshot();
        return;
      }
    }
    _outbox?.enqueue(
      SyncMutationRecord(
        idempotencyKey:
            'mut_like_${postId}_${DateTime.now().millisecondsSinceEpoch}',
        entityType: 'post',
        action: 'like',
        payload: {'postId': postId},
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> _syncAddPostToCloud(SocialMusicPost post) async {
    final repo = repository;
    if (repo != null && !repo.shouldSkipNetwork) {
      final published = await repo.publishPost(post.toJson());
      if (published != null) return;
    }
    _outbox?.enqueue(
      SyncMutationRecord(
        idempotencyKey: 'mut_post_${post.id}',
        entityType: 'post',
        action: 'create',
        payload: post.toJson(),
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> _syncRepostToCloud(
    String originalPostId,
    SocialMusicPost repostPost,
  ) async {
    final repo = repository;
    if (repo != null && !repo.shouldSkipNetwork) {
      final result = await repo.repostPost(
        originalPostId,
        repost: repostPost.toJson(),
      );
      if (result != null) {
        if (!mounted) return;
        state = [
          for (final post in state)
            if (post.id == originalPostId)
              post.copyWith(repostCount: result.repostCount)
            else
              post,
        ];
        _persistPostsSnapshot();
        return;
      }
    }
    _outbox?.enqueue(
      SyncMutationRecord(
        idempotencyKey: 'mut_repost_${repostPost.id}',
        entityType: 'post',
        action: 'repost',
        payload: {
          'originalPostId': originalPostId,
          'repost': repostPost.toJson(),
        },
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> _syncCosignToCloud(String postId) async {
    final repo = repository;
    if (repo != null && !repo.shouldSkipNetwork) {
      String? creatorId;
      try {
        creatorId = ref?.read(currentCreatorIdProvider);
      } catch (_) {}
      final result = await repo.cosignPost(postId, creatorId: creatorId);
      if (result != null) {
        if (!mounted) return;
        state = [
          for (final post in state)
            if (post.id == postId)
              post.copyWith(cosignCount: result.cosignCount)
            else
              post,
        ];
        _persistCoSignSnapshot();
        return;
      }
    }
    _outbox?.enqueue(
      SyncMutationRecord(
        idempotencyKey:
            'mut_cosign_${postId}_${DateTime.now().millisecondsSinceEpoch}',
        entityType: 'cosign',
        action: 'cosign',
        payload: {'postId': postId},
        createdAt: DateTime.now(),
      ),
    );
  }
   ```
   Call `unawaited(_syncToggleLikeToCloud(postId))` in `toggleLike`, `unawaited(_syncAddPostToCloud(post))` in `addPost`, `unawaited(_syncRepostToCloud(originalPostId, repostPost))` in `repostPost`, and `unawaited(_syncCosignToCloud(postId))` in `cosignPost` (removing the unconditional `_outbox?.enqueue(...)` calls).

### 6.3 Kinetic Post Comment Likes (`apps/vhunambi_client/lib/features/social/presentation/providers/reels_comments_provider.dart`)

Update `toggleCommentLike` (`#L394-L415`):

```dart
  /// Toggles the current user's like on a specific comment or reply.
  void toggleCommentLike({required String clipId, required String commentId}) {
    final currentList = state.commentsByClipId[clipId];
    if (currentList == null) return;

    final updated = [
      for (final comment in currentList)
        if (comment.id == commentId)
          comment.copyWith(
            isLikedByMe: !comment.isLikedByMe,
            likeCount: (comment.likeCount + (comment.isLikedByMe ? -1 : 1))
                .clamp(0, 9999999),
          )
        else
          comment,
    ];

    state = state.copyWith(
      commentsByClipId: {...state.commentsByClipId, clipId: updated},
    );
    _persistCommentsForClip(clipId, updated);

    final isKineticPost =
        clipId.startsWith('post_') || clipId.startsWith('kpost_');
    if (isKineticPost && _ref != null) {
      unawaited(_ref.read(exploreRepositoryProvider).likeComment(commentId));
      return;
    }
    if (_repo != null) {
      unawaited(_repo.toggleLikeComment(commentId));
    }
  }
```

---

## 7. Overhaul Pass 2 (`M71.3`): `EP-P37-REMIX-TREE-API` — Live Genealogical Remix Graph

### 7.1 `ISocialRepository` & `HttpSocialRepository`

In `apps/vhunambi_client/lib/features/social/domain/repositories/i_social_repository.dart`, add:

```dart
  /// Fetches live remix descendant clips via `GET /api/social/clips/:id/remixes`.
  Future<List<PublishedClip>> getClipRemixes(String clipId);
```

In `apps/vhunambi_client/lib/features/social/data/repositories/http_social_repository.dart`, add:

```dart
  @override
  Future<List<PublishedClip>> getClipRemixes(String clipId) async {
    if (_shouldSkipNetwork || clipId.trim().isEmpty) {
      return const <PublishedClip>[];
    }
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/social/clips/${Uri.encodeComponent(clipId)}/remixes',
      );
      if (response.statusCode == 200 && response.data != null) {
        final rawList = JsonSafe.asList(response.data!['remixes']);
        final parsed = <PublishedClip>[];
        for (final item in rawList) {
          final map = JsonSafe.asMap(item);
          if (map.isNotEmpty) {
            try {
              parsed.add(PublishedClip.fromJson(map));
            } catch (e) {
              debugPrint(
                '[HttpSocialRepository] Skipping malformed remix clip: $e',
              );
            }
          }
        }
        return parsed;
      }
    } catch (e) {
      debugPrint('[HttpSocialRepository] getClipRemixes fallback: $e');
    }
    return const <PublishedClip>[];
  }
```

### 7.2 `remix_lineage_provider.dart` & `remix_lineage_tree_sheet.dart`

In `apps/vhunambi_client/lib/features/social/presentation/providers/remix_lineage_provider.dart`, import `published_clip.dart` and `social_repository_provider.dart` and add:

```dart
/// Converts a backend [PublishedClip] remix child into a [RemixNode].
RemixNode remixNodeFromPublishedClip(PublishedClip clip, {int depth = 1}) {
  final handle = clip.creatorUsername.startsWith('@')
      ? clip.creatorUsername
      : '@${clip.creatorUsername}';
  return RemixNode(
    id: clip.id,
    title: clip.title,
    creatorId: clip.creatorId,
    creatorHandle: handle,
    creatorDisplayName: clip.creatorDisplayName,
    creatorAvatarUrl: clip.creatorAvatarUrl,
    isVerified: clip.isCreatorVerified,
    genre: clip.genre,
    bpm: clip.dna.musical.bpm.round(),
    musicalKey: clip.dna.musical.key,
    remixMode: clip.remixMode ?? RemixCreationMode.openVerseVocal,
    depth: clip.remixGenerationDepth > 0 ? clip.remixGenerationDepth : depth,
    audioUrl: clip.audioUrl,
    coverUrl: clip.coverUrl,
    playCount: clip.playCount,
    likeCount: clip.likeCount,
    coCreationSplits: clip.coCreationSplits,
  );
}

/// Merges live remote remix children onto [root], deduplicating by node ID.
RemixNode mergeRemoteRemixChildren(
  RemixNode root,
  List<PublishedClip> remoteRemixes,
) {
  if (remoteRemixes.isEmpty) return root;
  final existingIds = <String>{
    root.id,
    for (final child in root.children) child.id,
    for (final child in root.children)
      for (final grandChild in child.children) grandChild.id,
  };
  final appended = <RemixNode>[
    ...root.children,
    for (final clip in remoteRemixes)
      if (existingIds.add(clip.id))
        remixNodeFromPublishedClip(clip, depth: root.depth + 1),
  ];
  return root.copyWith(children: appended);
}

/// Fetches live remix descendants from `GET /api/social/clips/:id/remixes`.
final remixLineageRemoteChildrenProvider =
    FutureProvider.family<List<PublishedClip>, String>((ref, clipId) async {
      final repo = ref.watch(socialRepositoryProvider);
      return repo.getClipRemixes(clipId);
    });
```

In `apps/vhunambi_client/lib/features/social/presentation/widgets/remix_lineage_tree_sheet.dart`, merge the live remote children inside `build(...)`:

```dart
    final baseRootNode = ref.watch(remixLineageTreeProvider(trackOrClipId));
    final remoteChildrenAsync = ref.watch(
      remixLineageRemoteChildrenProvider(trackOrClipId),
    );
    final rootNode = mergeRemoteRemixChildren(
      baseRootNode,
      remoteChildrenAsync.valueOrNull ?? const <PublishedClip>[],
    );
```

---

## 8. Overhaul Pass 2 (`M71.3`): `EP-P68-CREATOR-ALLOWANCE` Extension

### 8.1 `StudioActionBar` (`apps/vhunambi_client/lib/features/studio/presentation/widgets/studio_action_bar.dart`)

1. Import `creator_allowance_provider.dart` and `subscription_upgrade_modal.dart`.
2. Inside `build(...)`, watch `final allowance = ref.watch(creatorAllowanceProvider);` and render a compact interactive allowance chip (`Key('studio_allowance_chip')`) above the action row (so both narrow mobile and wide desktop screens have zero horizontal overflow), with a 44dp accessible hit target, Phosphor icon, and tap handler `SubscriptionUpgradeModal.show(context)`:

```dart
        // Phase 71 (CON-04): Live Monthly Free Song Allowance Chip
        Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            button: true,
            label: allowance.isPaidUnlimited
                ? 'Pro Unlimited Songs. Tap to view creator plans.'
                : '${allowance.freeMonthlySongsRemaining} of ${allowance.freeMonthlySongsLimit} free monthly songs remaining. Tap to upgrade.',
            child: InkWell(
              key: const Key('studio_allowance_chip'),
              onTap: () {
                HapticsService().selectionClick();
                SubscriptionUpgradeModal.show(context);
              },
              borderRadius: AppRadius.pillBorder,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 36),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: allowance.isExhausted
                        ? AppColors.error.withValues(alpha: 0.14)
                        : allowance.isLowQuota
                            ? AppColors.coinGold.withValues(alpha: 0.14)
                            : AppColors.surfaceSecondaryOf(context),
                    borderRadius: AppRadius.pillBorder,
                    border: Border.all(
                      color: allowance.isExhausted
                          ? AppColors.error
                          : allowance.isLowQuota
                              ? AppColors.coinGold
                              : AppColors.borderSubtleOf(context),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PhosphorIcon(
                        allowance.isPaidUnlimited
                            ? PhosphorIconsFill.crown
                            : PhosphorIconsFill.musicNotes,
                        size: 14,
                        color: allowance.isExhausted
                            ? AppColors.error
                            : allowance.isLowQuota
                                ? AppColors.coinGold
                                : AppColors.brandPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        allowance.isPaidUnlimited
                            ? 'Pro Unlimited'
                            : '${allowance.freeMonthlySongsRemaining}/${allowance.freeMonthlySongsLimit} Free Songs',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      PhosphorIcon(
                        PhosphorIconsBold.caretRight,
                        size: 12,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
```

3. Replace stock `const Icon(Icons.check_circle_rounded, color: AppColors.brandPrimary)` at `#L169-L172` with:

```dart
            const PhosphorIcon(
              PhosphorIconsFill.checkCircle,
              color: AppColors.brandPrimary,
              size: 18,
            ),
```

### 8.2 `GenerationPipelineNotifier` (`apps/vhunambi_client/lib/features/studio/presentation/providers/generation_pipeline_providers.dart`)

Import `package:vhunambi_client/features/home/presentation/providers/creator_allowance_provider.dart` and immediately after `if (!mounted) return;` at `#L210` (right after `submissionService.submitGeneration(...)` resolves):

```dart
    try {
      _ref.read(creatorAllowanceProvider.notifier).consumeOneSongOptimistically();
    } catch (_) {}
```

### 8.3 `SubscriptionUpgradeModal` (`apps/vhunambi_client/lib/features/home/presentation/widgets/subscription_upgrade_modal.dart`)

1. Import `../providers/creator_allowance_provider.dart`.
2. Inside `build(...)`, watch `final allowance = ref.watch(creatorAllowanceProvider);` and render `Key('upgrade_modal_allowance_card')` right below the Header:

```dart
          // Phase 71 (CON-04): Live Monthly Free Song Allowance Status Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              key: const Key('upgrade_modal_allowance_card'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondaryOf(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: allowance.isExhausted
                      ? AppColors.error
                      : AppColors.borderSubtleOf(context),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      PhosphorIcon(
                        allowance.isPaidUnlimited
                            ? PhosphorIconsFill.crown
                            : PhosphorIconsFill.musicNotes,
                        color: allowance.isExhausted
                            ? AppColors.error
                            : AppColors.brandPrimary,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          allowance.isPaidUnlimited
                              ? 'Pro Plan · Unlimited Generations'
                              : 'Monthly Free Song Allowance',
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimaryOf(context),
                          ),
                        ),
                      ),
                      Text(
                        allowance.isPaidUnlimited
                            ? 'Unlimited'
                            : '${allowance.freeMonthlySongsRemaining}/${allowance.freeMonthlySongsLimit} Left',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w800,
                          color: allowance.isExhausted
                              ? AppColors.error
                              : AppColors.brandPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (!allowance.isPaidUnlimited) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: AppRadius.pillBorder,
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: allowance.freeMonthlySongsLimit > 0
                            ? (allowance.freeMonthlySongsRemaining /
                                    allowance.freeMonthlySongsLimit)
                                .clamp(0.0, 1.0)
                            : 0.0,
                        backgroundColor: AppColors.borderSubtleOf(context),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          allowance.isExhausted
                              ? AppColors.error
                              : allowance.isLowQuota
                                  ? AppColors.coinGold
                                  : AppColors.brandPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${allowance.freeMonthlySongsUsed} of ${allowance.freeMonthlySongsLimit} free songs used this 30-day cycle',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
```

3. Replace hardcoded `color: Colors.white` at `#L304` with `color: AppColors.brandContrast`.

---

## 9. Overhaul Pass 2 (`M71.4`): Surgical Repairs for 5 Stale Client Test Files & Phase 71 Suite

### 9.1 Exact Diffs for the 5 Pre-Existing Failing Client Test Files

1. **`test/core/network/phase63_e2e_cloud_pipeline_test.dart` (`#L486-L494`):**
   Honor Phase 65 lazy stem loading (`REQ-P65-L2-02`) by asserting `stemMixerProvider.activeTrackId == completed.id`, confirming stems are NOT eagerly decoded on completion, and then explicitly invoking `await recordingEngine.loadFromManifest(mmo)` before asserting `recordingEngine.hasRealStems == true` and `recordingEngine.loadedMasterUrl == expectedMasterUrl`:
   ```dart
        // StemMixer hydrated with track metadata; MultiStemAudioEngine lazy-loads on deck open (REQ-P65-L2-02)
        expect(
          container.read(stemMixerProvider).activeTrackId,
          equals(completed.id),
        );
        expect(recordingEngine.hasRealStems, isFalse);
        await recordingEngine.loadFromManifest(mmo);
        expect(recordingEngine.hasRealStems, isTrue);
        expect(recordingEngine.loadedMasterUrl, equals(expectedMasterUrl));
   ```
2. **`test/features/social/reel_audio_pool_and_kinetic_canvas_test.dart` (`#L120-L125`):**
   ```dart
        // Global player initializes paused on cold start; start playback before entering reels
        expect(
          container.read(playerStateProvider).playbackStatus,
          equals(PlaybackStatus.paused),
        );
        container.read(playerStateProvider.notifier).togglePlayPause();
        expect(
          container.read(playerStateProvider).playbackStatus,
          equals(PlaybackStatus.playing),
        );
   ```
3. **`test/features/player/audio_source_resolver_test.dart` (`#L54-L83`):**
   Align with `AppConstants.normalizeCloudMediaUrl(...)`:
   - `#L54-L57`:
     ```dart
      expect(
        resolved.uri.toString(),
        AppConstants.normalizeCloudMediaUrl(
          'https://vhunambi.com/audio/trk_cloud.mp3',
        ),
      );
     ```
   - `#L65-L68`:
     ```dart
      expect(
        resolved.uri.toString(),
        AppConstants.normalizeCloudMediaUrl(
          '${AppConstants.defaultOrigin}/audio/trk_no_url.mp3',
        ),
      );
     ```
   - `#L82`:
     ```dart
      expect(
        resolved.uri.scheme,
        Uri.parse(AppConstants.resolveMediaBaseUrl()).scheme,
      );
     ```
4. **`test/features/player/phase35_drag_dismiss_bin_test.dart` (`#L174-L183`):**
   Replace obsolete `tester.widget<IconButton>(...)` lookups with `_SoftIconButton` / `_PlayPauseOrb` hit-size and `PhosphorIcon` assertions:
   ```dart
      // MobileMiniPlayer renders 44x44 Phosphor-powered soft transport buttons
      for (final key in const [
        Key('mini_player_prev'),
        Key('mini_player_play_pause'),
        Key('mini_player_next'),
      ]) {
        final finder = find.byKey(key);
        expect(finder, findsOneWidget);
        final size = tester.getSize(finder);
        expect(size.width, greaterThanOrEqualTo(44));
        expect(size.height, greaterThanOrEqualTo(44));
        expect(
          find.descendant(of: finder, matching: find.byType(PhosphorIcon)),
          findsWidgets,
        );
      }
   ```
5. **`test/features/player/player_hardware_bridge_test.dart` (`#L47-L49`, `#L86`, `#L145`):**
   - `#L47-L49`:
     ```dart
      expect(state.playbackStatus, PlaybackStatus.paused);
      expect(state.position, Duration.zero);
      expect(state.duration, const Duration(seconds: 24));
     ```
   - Insert `container.read(playerStateProvider.notifier);` immediately before `await handler.playTrack(_track());` at `#L86` and `#L145` so stream listeners are subscribed before the synchronous broadcast event fires.

### 9.2 New Client Connectome Closure Test Suite (`apps/vhunambi_client/test/features/phase71_connectome_closure_test.dart`)

Create `test/features/phase71_connectome_closure_test.dart` with 4 dedicated `group(...)` blocks (keeping Dio `HttpClientAdapter` / `http.MockClient` tests in plain `test()` blocks outside `FakeAsync` per Phase 70 gotcha!):
- **Group 1 (`EP-P67-NOTIF-API`):** Uses `http.MockClient` + `SovereignApiClient` + `HttpNotificationRepository(hasCustomClient: true, isTestMode: true)` to verify `fetchNotifications()`, `upsertNotification()`, `markRead()`, `markAllRead()`, `deleteNotification()`, and `NotificationsNotifier.syncFromCloud()` preserving local `isRead == true` while importing server studio/quota alerts.
- **Group 2 (`EP-P69-POST-COSIGN-REPOST-HTTP`):** Uses a custom `Dio` + `HttpClientAdapter` to assert:
  - `HttpExploreRepository.fetchExploreFeed`, `cosignPost`, `repostPost`, `likeComment` hit exact REST routes.
  - `SocialFeedPostsNotifier` reconciles server counts and enqueues **0** outbox records when direct HTTP succeeds, and enqueues **1** outbox record when direct HTTP fails/returns `null`.
  - `SocialFeedPostsNotifier.refreshFromCloud()` hydrates `likeCount` and `commentCount`.
  - `ReelsCommentsNotifier.toggleCommentLike` routes `post_*` comments to `/api/explore/comments/:id/like`.
- **Group 3 (`EP-P37-REMIX-TREE-API`):** Uses custom `Dio` + `HttpClientAdapter` to verify `HttpSocialRepository.getClipRemixes('clip_root_1')` parses `PublishedClip` list, and a `testWidgets` block overriding `remixLineageRemoteChildrenProvider` proving `RemixLineageTreeSheet` renders merged remote child titles cleanly with bounded `pump()`.
- **Group 4 (`EP-P68-CREATOR-ALLOWANCE`):**
  - `testWidgets` on `StudioActionBar` verifying `Key('studio_allowance_chip')` renders live `7/10 Free Songs`, tapping opens `SubscriptionUpgradeModal`, and `Key('upgrade_modal_allowance_card')` renders live allowance state with zero stock `Icons.*`.
  - Plain `test()` verifying `GenerationPipelineNotifier.submitAndStartGeneration` decrements `creatorAllowanceProvider` from `10` to `9` via `consumeOneSongOptimistically()`.

---

## 10. Invariants Proof & Failure-Mode Containment

1. **Zero Stale Isolate Pinning:** Because `domainHydratedAtMs.set(domainKey, Date.now())` executes ONLY when `res.ok === true` (and `allSucceeded === true` for multi-table Explore sync), transient PostgREST 5xx or timeout spikes degrade cleanly to local cache for that single request and automatically heal on the very next request.
2. **Zero Double-Increment on Explore Interactions:** `SocialFeedPostsNotifier` checks direct HTTP first and returns early on non-null response; `_outbox?.enqueue(...)` is unreachable on HTTP success and executes exclusively on offline/error fallback.
3. **Zero Breaking Impact on Existing Client Tests:** Every new HTTP repository (`HttpNotificationRepository`, `HttpExploreRepository`, `HttpSocialRepository`) obeys `shouldSkipNetwork`, `RemixLineageTreeSheet` retains synchronous `remixLineageTreeProvider` fallback on frame 0, and `VhunambiDatabase` implements matching local-SQLite counterparts for every new async method added to `EdgeIsolateDatabaseEngine`.
