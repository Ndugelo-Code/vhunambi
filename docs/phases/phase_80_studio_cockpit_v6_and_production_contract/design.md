# Phase 80 Technical Design — Studio Cockpit V6, `vhunambi.com` Parity & `StudioGenerationContractV6`

> **Document ID:** `DESIGN-PHASE-80`  
> **Phase Folder:** `docs/phases/phase_80_studio_cockpit_v6_and_production_contract/`  
> **Compliance:** 100% authentic `package:vhunambi_client/...`, `package:phosphor_icons/phosphor_icons.dart`, `VhunambiGlassSurface`, `VhunambiGlassTabBar`, `AppColors.*Of(context)`, `AppTypography.*`, zero raw Unicode emojis (`STD-UIUX-001`), zero `ILyricsGenerationService` breaking changes, zero `YuE2` references.

---

## 1. Pass 1 (`M80.1`) — Backend `StudioGenerationContractV6`, Multi-Take Schema & AI Assist APIs

### 1.1 Supabase Additive Migration (`supabase/migrations/20261124000002_phase80_generation_jobs_v6_multitake.sql`)

```sql
-- Phase 80: StudioGenerationContractV6 & Multi-Take Baking Registry on public.generation_jobs
-- Apply to Supabase Cloud via supabase_mcp BEFORE deploying vhunambi-api.

ALTER TABLE public.generation_jobs
  ADD COLUMN IF NOT EXISTS batch_id TEXT,
  ADD COLUMN IF NOT EXISTS batch_count INTEGER NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS engine_tier TEXT NOT NULL DEFAULT 'studio_bake',
  ADD COLUMN IF NOT EXISTS resolved_engine TEXT NOT NULL DEFAULT 'minimax_music_3',
  ADD COLUMN IF NOT EXISTS audio_mode TEXT NOT NULL DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS reference_audio_url TEXT,
  ADD COLUMN IF NOT EXISTS visibility TEXT NOT NULL DEFAULT 'public',
  ADD COLUMN IF NOT EXISTS attribution_tag TEXT,
  ADD COLUMN IF NOT EXISTS lyrics_text TEXT,
  ADD COLUMN IF NOT EXISTS cover_url TEXT,
  ADD COLUMN IF NOT EXISTS voice_cast_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS generation_spec_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS takes_json JSONB NOT NULL DEFAULT '[]'::jsonb;

CREATE INDEX IF NOT EXISTS idx_generation_jobs_batch_id
  ON public.generation_jobs (batch_id)
  WHERE batch_id IS NOT NULL;

ALTER TABLE public.generation_jobs ENABLE ROW LEVEL SECURITY;

-- Phase 79 Advisor Guardrail (0003_auth_rls_initplan):
-- Wrap ONLY auth.jwt() inside SELECT so all 4 policies pass with 0 warnings.
DROP POLICY IF EXISTS generation_jobs_select_own ON public.generation_jobs;
CREATE POLICY generation_jobs_select_own ON public.generation_jobs
  FOR SELECT
  USING (((SELECT auth.jwt()) ->> 'creator_id') = creator_id);

DROP POLICY IF EXISTS generation_jobs_insert_own ON public.generation_jobs;
CREATE POLICY generation_jobs_insert_own ON public.generation_jobs
  FOR INSERT
  WITH CHECK (((SELECT auth.jwt()) ->> 'creator_id') = creator_id);

DROP POLICY IF EXISTS generation_jobs_update_own ON public.generation_jobs;
CREATE POLICY generation_jobs_update_own ON public.generation_jobs
  FOR UPDATE
  USING (((SELECT auth.jwt()) ->> 'creator_id') = creator_id)
  WITH CHECK (((SELECT auth.jwt()) ->> 'creator_id') = creator_id);

DROP POLICY IF EXISTS generation_jobs_delete_own ON public.generation_jobs;
CREATE POLICY generation_jobs_delete_own ON public.generation_jobs
  FOR DELETE
  USING (((SELECT auth.jwt()) ->> 'creator_id') = creator_id);
```

### 1.2 Multi-Take Domain Contract (`apps/vhunambi_api/src/modules/jobs/job_types.ts` & `job_store.ts`)

```typescript
import { MasterMediaObjectManifest } from '../dna/dna_types.js';

export type JobStatus = 'queued' | 'running' | 'succeeded' | 'failed';
export type PipelineStep =
  | 'queued'
  | 'planning_lyrics'
  | 'synthesizing'
  | 'separating_stems'
  | 'converting_vocals'
  | 'mastering'
  | 'uploading'
  | 'ready'
  | 'failed';

export type StudioEngineTier = 'fast_draft' | 'studio_bake' | 'sovereign_custom';
export type ResolvedAudioEngine =
  | 'ace_step_xl_turbo'
  | 'ace_step_xl_sft'
  | 'ace_step_xl_base'
  | 'minimax_music_3';
export type ReferenceAudioMode =
  | 'none'
  | 'remix'
  | 'cover'
  | 'reference'
  | 'inspiration';

export interface GenerationTakeRecord {
  takeIndex: number;
  seed: number;
  engineUsed: ResolvedAudioEngine | string;
  audioUrl: string;
  durationSec?: number;
  score?: number;
  attribution?: string | null;
}

export interface GenerationJob {
  generationId: string;
  creatorId?: string;
  batchId?: string;
  batchCount?: number;
  engineTier?: StudioEngineTier;
  resolvedEngine?: ResolvedAudioEngine;
  audioMode?: ReferenceAudioMode;
  referenceAudioUrl?: string;
  visibility?: 'public' | 'private';
  attributionTag?: string | null;
  voiceCast?: Record<string, unknown>;
  generationSpec?: Record<string, unknown>;
  takes?: GenerationTakeRecord[];
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

- **`job_store.ts` Update:**
  - `createJob` assigns `creatorId: resolvedCreator` directly onto `job` before calling `vhunambiDb.upsertGenerationJob(job, resolvedCreator)`.
  - `completeJob` accepts optional `takes?: GenerationTakeRecord[]`, `attributionTag?: string | null`, and `resolvedEngine?: ResolvedAudioEngine`, preserving `existing?.creatorId` and `existing?.durationSec ?? 180` (never clobbering `durationSec` back to `180` when a `300s` or `60s` track completes!).

### 1.3 1:1 SQLite & Edge Persistence Bridge Parity (`vhunambi_db.ts` & `edge_persistence_bridge.ts`)

1. **`apps/vhunambi_api/src/db/vhunambi_db.ts`:**
   - In constructor DDL after `CREATE TABLE IF NOT EXISTS generation_jobs (...)`, run idempotent `ALTER TABLE generation_jobs ADD COLUMN ...` statements wrapped in `try { ... } catch {}` for each of the 13 new columns (`batch_id`, `batch_count`, `engine_tier`, `resolved_engine`, `audio_mode`, `reference_audio_url`, `visibility`, `attribution_tag`, `lyrics_text`, `cover_url`, `voice_cast_json`, `generation_spec_json`, `takes_json`).
   - In `mapGenerationJobRow(r)`: deserialize `creatorId: String(r.creator_id ?? 'creator_cern')`, `batchId`, `batchCount`, `engineTier`, `resolvedEngine`, `audioMode`, `referenceAudioUrl`, `visibility`, `attributionTag`, `lyrics: r.lyrics_text ?? undefined`, `coverUrl: r.cover_url ?? undefined`, `voiceCast` (`JSON.parse`), `generationSpec` (`JSON.parse`), and `takes` (`JSON.parse`).
   - In `upsertGenerationJob(job, creatorId, jobKind)`: resolve `const owner = canonicalizeCreatorId(creatorId || job.creatorId || 'creator_cern');` and persist all 13 columns in the `INSERT ... ON CONFLICT(generation_id) DO UPDATE SET ...` statement using `COALESCE(excluded.<col>, generation_jobs.<col>)` for optional metadata.
   - **Critical Bug Fix (`STU-09`) in `updateGenerationJob`:** Call `this.upsertGenerationJob(merged, merged.creatorId ?? existing.creatorId ?? 'creator_cern')` so updating status/progress NEVER resets `creator_id` back to `'creator_cern'`.
2. **`apps/vhunambi_api/src/db/edge_persistence_bridge.ts`:**
   - Mirror the exact 13 columns inside `mergeAndStoreGenerationJob`, `mapCloudGenerationJobRow`, `upsertGenerationJob`, and `upsertGenerationJobAsync` (maintaining 1:1 method parity with `vhunambi_db.ts`!).
   - In `mergeAndStoreGenerationJob`: resolve `effectiveCreatorId = canonicalizeCreatorId(creatorId !== 'creator_cern' ? creatorId : (job.creatorId ?? existing?.creatorId ?? creatorId))`.

### 1.4 42-Genre Preset Catalog & Duet-Safe Lyric Sanitizer (`constants.ts` & `lyrics_sanitizer.ts`)

1. **`apps/vhunambi_api/src/modules/synthesis/constants.ts`:**
   - Expand `GENRE_PRESETS` from `6` entries to **`26+` canonical acoustic profiles** covering all `42` Flutter catalog genres (`amapiano`, `privateschoolamapiano`, `sgija`, `bacardi`, `gqom`, `maskandi`, `kwaito`, `afrohouse`, `gospel`, `mbaqanga`, `marabi`, `bubblegum`, `isicathamiya`, `mbube`, `afrobeats`, `afrofusion`, `afrosoul`, `afrojazz`, `highlife`, `rumba`, `soukous`, `chimurenga`, `kuduro`, `kizomba`, `gengetone`, `ethiojazz`, `coupedecale`, `bongoflava`, `afrodrill`, `reggae`, `dancehall`, `samba`, `afrocuban`, `gospelsoul`, `hiphop`, `rb`, `pop`, `electronic`, `lofichill`, `kpop`, `bollywoodfusion`, `afroasianlofi`).
2. **`apps/vhunambi_api/src/modules/lyrics/lyrics_sanitizer.ts`:**
   - Expand `ALLOWED_SECTION` to preserve duet and musical solo markers while still stripping spoken prose stage directions:
   ```typescript
   const ALLOWED_SECTION =
     /^(intro|verse(?:\s*\d+)?|pre-?chorus|chorus(?:\s*\d+)?|bridge|outro|instrumental|hook|voice\s*[a-d]|duet|choir|call|response|guitar\s*solo|sax\s*solo|log\s*drum\s*drop|drop|breakdown)$/;
   ```

### 1.5 Multi-Model Compiler, Seed Generator & RunPod Dispatch (`prompt_compiler.ts` & `runpod_adapter.ts`)

```typescript
export function resolveTargetAudioEngine(input: {
  engineTier?: StudioEngineTier;
  isInstrumental?: boolean;
  audioMode?: ReferenceAudioMode;
  referenceAudioUrl?: string;
  clonedVoiceProfileId?: string;
}): {
  resolvedEngine: ResolvedAudioEngine;
  attributionTag: string | null;
} {
  const tier = input.engineTier ?? 'studio_bake';
  const hasReference =
    Boolean(input.referenceAudioUrl?.trim()) &&
    (input.audioMode ?? 'none') !== 'none';
  const hasVoiceClone = Boolean(input.clonedVoiceProfileId?.trim());

  if (tier === 'fast_draft') {
    return { resolvedEngine: 'ace_step_xl_turbo', attributionTag: null };
  }
  if (tier === 'sovereign_custom' || hasReference || hasVoiceClone) {
    return { resolvedEngine: 'ace_step_xl_base', attributionTag: null };
  }
  // MiniMax Music 3.0 sglang-omni rejects empty lyrics: route instrumentals to ACE-Step 1.5 XL-SFT
  if (input.isInstrumental) {
    return { resolvedEngine: 'ace_step_xl_sft', attributionTag: null };
  }
  return { resolvedEngine: 'minimax_music_3', attributionTag: 'MiniMax-Music3' };
}

export function generateUniqueTakeSeeds(batchCount: number): number[] {
  const count = Math.max(1, Math.min(4, Math.round(batchCount || 1)));
  const seeds = new Set<number>();
  while (seeds.size < count) {
    const buf = new Uint32Array(2);
    crypto.getRandomValues(buf);
    // Positive safe 53-bit integer (> 0) avoiding MiniMax sglang-omni seed=0 determinism
    const hi = (buf[0]! & 0x001fffff) * 0x100000000;
    const candidate = hi + buf[1]!;
    if (candidate > 0) seeds.add(candidate);
  }
  return [...seeds];
}
```

- **Lifting the 48-Char Truncation Cap (`STU-10`):**
  - In `buildAceStepStyleTags(...)`, preserve rich user prompt descriptors up to `320` characters (splitting on `,`/`.`/`;`, stripping brackets, deduplicating against preset tags), append voice-cast descriptors (`duet male and female vocals`, `choir call-and-response`, `intense vocal projection`, `high vibrato warmth`, `cultural ad-libs`) derived from `voiceCast` + `dialectInflection`, AND include the full `richPrompt` (`<= 4000` chars) on `CompiledSynthesisPrompt.richPrompt` + `song_spec.rich_prompt`.
- **`runpod_adapter.ts` Forwarding:**
  - Include `engine_tier`, `resolved_engine`, `attribution_tag`, `batch_id`, `batch_count`, `take_seeds`, `audio_mode`, `rich_prompt`, `voice_cast`, `era`, `song_structure`, `region`, and `visibility` in the RunPod `/run` payload (`input` + `input.song_spec`), while maintaining 100% compatibility with existing `handler.py` keys (`job_id`, `user_id`, `song_spec`, `webhook_url`, `loras`, `svc_config`, `reference_audio_url`).

### 1.6 Studio AI Assist & Photo/Duet Lyrics Routes (`studio_routes.ts`, `lyrics_routes.ts`, `server.ts`)

1. **New File: `apps/vhunambi_api/src/routes/studio_routes.ts`:**
   - `POST /v1/studio/improve-prompt`:
     - Schema: `{ prompt: z.string().trim().min(2).max(2000), genre: z.string().default('Amapiano'), region: z.string().default('South Africa'), language: z.string().default('English'), mood: z.string().optional(), ensemble: z.enum(['solo', 'duet', 'choir']).optional(), isInstrumental: z.boolean().default(false) }`.
     - Calls `callRunPodOpenSourceLLM(systemPrompt, userMsg, c, 0.7, 320)` to expand terse user ideas into a vivid 2-sentence studio arrangement brief specifying instrumentation, percussion groove, bass texture, vocal dynamics, and cultural atmosphere; falls back deterministically using `getGenrePreset(genre)` + `getLanguageContext(language)` when LLM is offline.
     - Returns `{ success: true, improvedPrompt, genre, suggestedBpm, suggestedMood, provider }`.
2. **Updates in `apps/vhunambi_api/src/routes/lyrics_routes.ts`:**
   - Extend `GenerateLyricsSchema` with optional `ensemble: z.enum(['solo', 'duet', 'choir']).optional()`, `voiceCast: z.array(z.string()).max(6).optional()`, `mood: z.string().optional()`.
   - When `ensemble === 'duet'`, instruct LLM (and deterministic composer in `llm_handler.ts`) to format verses and bridges with `[VOICE A]` and `[VOICE B]` alternating lines and `[DUET]` choruses.
   - Add `POST /v1/lyrics/from-photo`:
     - Schema: `{ photoUrl: z.string().trim().min(1), captionHint: z.string().max(600).optional(), genre: z.string().default('Amapiano'), language: z.string().default('English'), mood: z.string().optional(), ensemble: z.enum(['solo', 'duet', 'choir']).optional() }`.
     - Synthesizes culturally grounded lyrics inspired by the uploaded photo metadata/caption hint using `callRunPodOpenSourceLLM` + deterministic fallback, returning `{ success: true, rawLyrics, stanzas, detectedLanguage, sourcePhotoUrl }`.
3. **Mount in `apps/vhunambi_api/src/server.ts`:**
   - Add `p.startsWith('/v1/studio')` to `hasScopedReadThrough`.
   - Mount `app.route('/v1/studio', studioRoutes)`.

### 1.7 Honest Queued-to-Ready Notifications & Long-Bake Webhook Handling (`generation_routes.ts`, `webhook_routes.ts`, `mock_worker.ts`)

- **Shared Helper `notifyGenerationCompletedOnce(job, c)` (exported from `job_store.ts`):**
  - Resolves `creatorId = canonicalizeCreatorId(job.creatorId ?? 'creator_cern')`.
  - Upgrades `notif_gen_${job.generationId}` to unread Ready state via `await vhunambiDb.upsertNotificationAsync({ id: 'notif_gen_' + job.generationId, userId: creatorId, title: 'Studio Track Ready: "' + job.trackTitle + '"', message: 'Mastered ' + job.genre + ' track is ready to play.', isRead: false, category: 'creatorActivity', subtype: 'studio_render', priority: 'normal', targetRoute: '/track/' + job.generationId, targetEntityId: job.generationId, ctaLabel: 'Open Track Cockpit', metadata: { trackId: job.generationId, attributionTag: job.attributionTag ?? null, batchCount: job.batchCount ?? 1 } }, c)`.
- **`POST /v1/generations` (`generation_routes.ts`):**
  - Resolves `creatorId` BEFORE `createJob(...)`.
  - Persists queued job immediately via `await vhunambiDb.upsertGenerationJobAsync(createdJob, creatorId, 'audio_synthesis', c)`.
  - **Replaces** the premature `"Studio Track Ready"` wording at lines `135–156` with an **honest queued entry** on the same `id: 'notif_gen_' + generationId` (`title: 'Studio Bake Queued: "' + input.trackTitle + '"'`, `targetRoute: '/studio'`, `ctaLabel: 'View Bake Progress'`) — fixing `STU-08` while keeping `phase67_notifications_quota.test.ts#L150` (`ids.some((id) => id.startsWith('notif_gen_'))`) 100% green!
  - Returns `batchId`, `batchCount`, `engineTier`, `resolvedEngine`, `attributionTag`, `audioMode`, `durationSec`, and `takes: []` alongside all legacy response keys.
- **`GET /v1/generations/:id` (`generation_routes.ts`) & `mock_worker.ts`:**
  - Raises `staleUnscheduled` threshold from `240000ms` to `900000ms` (`15 min`) for `studio_bake` / `sovereign_custom` jobs when workers are initializing/cold-starting, while keeping immediate fallback if `health.workersMax === 0`.
  - Calls `await notifyGenerationCompletedOnce(completedJob, c)` when RunPod status polling or `mock_worker.ts` transitions a job to `succeeded`.
  - Returns `batchId`, `batchCount`, `engineTier`, `resolvedEngine`, `audioMode`, `attributionTag`, `takes`, and `visibility` in the JSON payload.
- **`POST /v1/webhooks/ace-step` (`webhook_routes.ts`):**
  - Maps granular `status` / `stage` strings (`planning_lyrics`, `synthesizing`, `processing`, `separating_stems`, `converting_vocals`, `mastering`, `uploading`, `completed`, `failed`) accurately onto `PipelineStep` and broadcasts via `GenerationSessionDO`.
  - On `completed`: hydrates `existingJob = getJob(generationId) ?? await vhunambiDb.syncGenerationJobFromCloud(generationId, c)`, preserves `realCreatorId = existingJob?.creatorId ?? 'creator_cern'`, normalizes `payload.takes` (or synthesizes a 1-element take array from `audio_url` + `existingJob?.resolvedEngine` + `existingJob?.attributionTag`), persists via `await vhunambiDb.upsertGenerationJobAsync(updatedJob, realCreatorId, 'audio_synthesis', c)`, and calls `await notifyGenerationCompletedOnce(updatedJob, c)`.

---

## 2. Pass 1 & Pass 2 (`M80.2`–`M80.4`) — Flutter Studio Cockpit V6 Glass Overhaul & `vhunambi.com` Parity

### 2.1 Domain Models & State (`studio_form_state.dart`, `studio_genre_catalog.dart`, `generation_pipeline_state.dart`)

1. **`apps/vhunambi_client/lib/features/studio/domain/models/studio_form_state.dart`:**
   - Add enums (zero raw emojis):
     - `enum StudioEngineTier { fastDraft, studioBake, sovereignCustom }` with `.wireValue` (`'fast_draft'`, `'studio_bake'`, `'sovereign_custom'`), `.label`, `.subtitle`, `.etaLabel`.
     - `enum ReferenceAudioMode { none, remix, cover, reference, inspiration }` with `.wireValue`, `.label`, `.description`.
   - Extend `StudioFormState` with defaults preserving **100% of existing tests** (`studio_form_test.dart#L19` & `studio_session_repository_test.dart#L64` explicitly assert `this.durationSeconds = 30` on untouched state — keep `this.durationSeconds = 30` in `const StudioFormState()` and expose full `10..360` range + `30s`/`1:30`/`3:00`/`5:00 Sweet Spot`/`6:00` quick pills on the slider!):
     - `final ReferenceAudioMode audioMode;` (default `ReferenceAudioMode.none`)
     - `final StudioEngineTier engineTier;` (default `StudioEngineTier.studioBake`)
     - `final int batchCount;` (default `1`, clamped `1..4`)
     - `final List<String> selectedVoiceIds;` (default `const <String>[]`, max `6`)
     - `final String? sourcePhotoPath;` & `final String? sourcePhotoUrl;`
     - `final String? sourceTrackId;`
   - Remember to include all new fields in `copyWith`, `operator ==`, and `hashCode`!
   - Add `resolvedEnginePreview` getter mirroring `resolveTargetAudioEngine(...)` so the UI accurately previews when `Instrumental Only` auto-routes `Studio Bake` to `ACE-Step 1.5 XL-SFT` or when `MiniMax-Music3` attribution applies.

2. **New File: `apps/vhunambi_client/lib/features/studio/domain/models/studio_genre_catalog.dart`:**
   - Pure Dart `StudioGenreItem` (`name`, `icon`, `region`, `defaultBpm`, `styleHint`) and `kStudioGenreCatalog` containing all **42 curated genres** across `['South Africa', 'Africa', 'Americas', 'Global', 'Asia']` using `AppIcons.*` / `PhosphorIconsRegular.*` ONLY.

3. **`apps/vhunambi_client/lib/features/studio/domain/models/generation_pipeline_state.dart`:**
   - Preserve `enum PipelineStep { startingUp, writingLyrics, producingBeat, ready, failed }` (100% backward-compatible with existing tests).
   - Add `enum BakeStage { planningLyrics, composingArrangement, cloningAndPolishingVocals, broadcastMastering, ready, failed }` with `.stageIndex` (`1..4`, `0` failed) and `.label`.
   - Add `@immutable class GenerationTake`: `{ takeIndex, seed, engineUsed, audioUrl, durationSec, score, attribution }` with `.fromJson(...)`.
   - Extend `PipelineSocketEvent` and `GenerationProgressState` with optional additive fields:
     - `final BakeStage bakeStage;` (defaults derived from `step` when omitted)
     - `final String? resolvedEngine;`
     - `final String? attributionTag;`
     - `final List<GenerationTake> takes;` (default `const []`)
     - `final int activeTakeIndex;` (default `0`)

### 2.2 Dedicated AI Assist Service & 18-Min Polling (`studio_ai_assist_service.dart`, `http_generation_submission_service.dart`, `generation_pipeline_providers.dart`)

1. **New File: `apps/vhunambi_client/lib/features/studio/data/services/studio_ai_assist_service.dart`:**
   - Keeps `ILyricsGenerationService` 100% untouched (zero broken test doubles!).
   - Exposes `studioAiAssistServiceProvider`:
     - `Future<String> improvePrompt({ required String prompt, required String genre, required String region, required String language, String? mood, String? ensemble, bool isInstrumental = false })`: calls `POST $_baseUrl/studio/improve-prompt` (skips live network under `FLUTTER_TEST` without custom `Dio` and returns rich local expansion).
     - `Future<LyricsReviewDraft> generateLyricsFromPhoto({ required String photoUrl, String? captionHint, required String genre, required String language, String? mood, String? ensemble })`: calls `POST $_baseUrl/lyrics/from-photo` with offline fallback.
     - `Future<LyricsReviewDraft> generateDuetAwareLyrics({ required String prompt, required String genre, required String language, required String ensemble, List<String> voiceCast = const [], String? mood })`: calls `POST $_baseUrl/lyrics/generate` with `ensemble` + `voiceCast` when `ensemble != 'solo'` (falls back to `lyricsGenerationServiceProvider`).

2. **`HttpGenerationSubmissionService` (`http_generation_submission_service.dart`):**
   - Extend `submitGeneration(...)` with optional V6 named parameters (`durationSec`, `region`, `lyricsMode`, `sourcePhotoUrl`, `isAutoTitle`, `era`, `songStructure`, `visibility`, `engineTier`, `batchCount`, `audioMode`, `sourceTrackId`, `voiceCast`).
   - Upgrade `pollGenerationProgress(String generationId)`:
     - Replace `const maxAttempts = 60;` (`90s`) with adaptive polling up to **18 minutes** (`maxAttempts = 380`: `2s` delay for first `30` attempts, `3s` delay thereafter), mapping `planning_lyrics` / `synthesizing` / `separating_stems` / `converting_vocals` / `mastering` / `ready` into `BakeStage` AND parsing `takes`, `resolvedEngine`, and `attributionTag`.

3. **`GenerationPipelineNotifier` (`generation_pipeline_providers.dart`):**
   - `submitAndStartGeneration(...)` snapshots ALL V6 fields from `studioFormProvider` and `vocalIdentityProvider` (`durationSeconds`, `region`, `lyricsMode`, `isAutoTitle`, `era`, `songStructure`, `visibility`, `engineTier`, `batchCount`, `audioMode`, `sourcePhotoUrl`, `sourceTrackId`, `voiceCast` with `selectedVoiceIds`, `clonedVoiceReferenceUrl`, and `dialectInflection`), guaranteeing **zero dropped parameters** whether launched from `StudioActionBar` or `LyricsReviewModal._approveDraft`!
   - Add `selectActiveTake(int index)` method on `GenerationPipelineNotifier` so tapping `Take 1`..`Take 4` in `GenerationPipelineCard` swaps the active playable `completedTrack` cleanly.

### 2.3 Studio Cockpit V6 Glass Widget Overhaul (`M80.2` – `M80.4`)

1. **`StudioView` (`studio_view.dart`):**
   - Replace `_modeSwitcher` with `VhunambiGlassTabBar(scrollable: false, items: [VhunambiGlassTabItem(key: const Key('studio_tab_compose'), label: 'Compose', icon: AppIcons.sparkle), VhunambiGlassTabItem(key: const Key('studio_tab_voice'), label: 'Voice', icon: AppIcons.mic), VhunambiGlassTabItem(key: const Key('studio_tab_crate_mpc'), label: 'Crate & MPC', icon: AppIcons.sliders)])`.
   - Remove permanent top `ProgressTrackerWidget()` outside `IndexedStack` (`STU-01`); place compact `SongDnaHoverPill` + Vibe Dice in the top utility row inside `Compose` only.
   - Remove `const CockpitQuantumEntanglementRack()` from pre-gen `Compose` (`STU-02`).
   - Mount the new V6 Compose stack inside `IndexedStack` tab 0:
     1. `if (isPipelineVisible) GenerationPipelineCard(...)`
     2. `const StudioSessionRecoveryBanner()`
     3. `const PromptInputBox()`
     4. `const ReferenceAudioDropzone()`
     5. `const _DnaSuggestionChip()` *(with compact `SongDnaHoverPill`)*
     6. `const ActiveRemixLineageBanner()`
     7. `const RegionalGenreSelector()`
     8. `const StudioLyricsAndBakeDeck()` *(Language, Instrumental Only, 3-Mode Lyrics, Engine Tier, Song Length `10s–360s`, Title, Batch `1–4`)*
     9. `const AdvancedOptionsAccordion()`
     10. `const StudioPastSongsRemixShelf()`
   - Convert `Scaffold.backgroundColor` and sticky `StudioActionBar` container to `AppColors.surfaceCanvasOf(context)` / `VhunambiGlassSurface`.

2. **`PromptInputBox` (`prompt_input_box.dart`):**
   - Wrap in `VhunambiGlassSurface(enableLiveBlur: false)` with `AppColors.*Of(context)`.
   - Add `Key('studio_improve_prompt_btn')` (`'Improve with AI'`, `minHeight: 44`, Phosphor `AppIcons.sparkle` + loading spinner) inside the `Wrap` strip next to `Inspire Me` and `studio_preset_chip_0..2`.

3. **`ReferenceAudioDropzone` (`reference_audio_dropzone.dart`):**
   - Wrap in `VhunambiGlassSurface(enableLiveBlur: false)` + `AppColors.*Of(context)`.
   - Replace raw `AudioImportService` + fake `'amapiano_logdrum_ref_01.wav'` cancel fallback with Phase 79 `VhunambiMediaVault` (`ref.read(mediaUploadQueueProvider.notifier).stageAndEnqueue(bytes: ..., filename: ..., mimeType: ..., kind: MediaAssetKind.audio, sourceSurface: 'studio')`) — if user cancels picker, do nothing!
   - Replace cramped 3-column `Row` with a responsive `Wrap` (`minHeight: 44` pills):
     - `Key('dropzone_upload_audio_btn')` (`Upload Audio` / `Swap Audio`)
     - `Key('dropzone_from_uploads_btn')` (`My Uploads` — opens glass modal listing `mediaUploadQueueProvider` audio assets)
     - `Key('dropzone_record_tune_btn')` (`Record Tune` — opens `VoiceCloneRecorderSheet` / compact audio capture bridge)
     - `Key('dropzone_load_licensed_beat_btn')` (`My Beats`)
     - `Key('dropzone_open_sketchpad_btn')` (`Sketchpad`)
   - When reference audio is attached:
     - Render audition play/pause control (`Key('dropzone_preview_audio_btn')`) using `SafeAudioOrchestrator.instance.acquireSlot(AudioEngineSlot.studioPreview, onPreemptPause: ...)` (`package:vhunambi_client/core/resilience/safe_audio_orchestrator.dart`, bypassed under `FLUTTER_TEST`, and `SafeAudioOrchestrator.instance.unregisterSlot(AudioEngineSlot.studioPreview)` in `dispose()`).
     - Render the 4 explicit Recreate Mode glass tiles in a 2x2 responsive `LayoutBuilder` grid (`Key('audio_mode_remix')`, `Key('audio_mode_cover')`, `Key('audio_mode_reference')`, `Key('audio_mode_inspiration')`), defaulting to `ReferenceAudioMode.remix` upon attachment.

4. **`RegionalGenreSelector` (`regional_genre_selector.dart`):**
   - Wrap in `VhunambiGlassSurface(enableLiveBlur: false)` + `AppColors.*Of(context)`.
   - Replace hardcoded 18-item `_allGenres` with `kStudioGenreCatalog` (`42` genres across all `5` regions — fixing empty `'Asia'`).

5. **New File: `apps/vhunambi_client/lib/features/studio/presentation/widgets/studio_lyrics_and_bake_deck.dart`:**
   - Combines `MultilingualLanguageSelector` (preserving `'Language'` text pin and `44dp` chips) + `Instrumental Only` switch (`Key('studio_instrumental_switch')`) + 3-Mode Lyrics `VhunambiGlassTabBar` (`Key('studio_lyrics_mode_bar')`: `AI writes` | `My own` | `From photo`) + inline custom lyrics editor with `[Voice A]`/`[Voice B]`/`[Chorus]` quick tags + Phase 79 `VhunambiMediaVault` photo picker for `From photo` + Production & Bake Settings card:
     - 3-tier Engine Selector (`Key('studio_engine_tier_selector')`: `Fast Draft`, `Studio Bake`, `Sovereign Custom`) showing auto-routing note when `Instrumental Only` is enabled.
     - `Song Length` slider (`Key('studio_duration_slider')`, `10`..`360` sec, `30s` / `1:30` / `3:00` / `5:00 Sweet Spot` / `6:00` chips rendered with Phosphor icons — zero raw star/emoji literals).
     - `Song Title` toggle (`AI picks title` vs. `I'll name it` with `Key('studio_custom_title_input')`).
     - `Number of songs` (`Key('batch_count_1')`..`Key('batch_count_4')`).

6. **`BantuVoiceDeck` (`bantu_voice_deck.dart`) & `LyricsReviewModal` (`lyrics_review_modal.dart`):**
   - Convert `BantuVoiceDeck` to `VhunambiGlassSurface` + `AppColors.*Of(context)` while strictly preserving `'Bantu Voice LoRA Engine'`, `'5 Native Dialects'`, all 5 `ValueKey('timbre_<id>')` cards (`width: 156` so all 5 build on `1400px` in `bantu_voice_deck_test.dart`), and exactly `4` `Slider` widgets!
   - Add `Key('voice_quick_duet_btn')` (`'Quick Duet: Female + Male'`, sets `VocalVoices.duet`, `VocalGender.mixed`, and selects a curated female + male pair in `selectedVoiceIds`).
   - Replace the colliding 2-button `Row` (`'24 Regional Voices'` / `'Clone My Voice'`) with a full-label responsive `Wrap` (`minHeight: 44`) and add horizontal padding + `clipBehavior: Clip.none` to the timbre card list (`STU-03`).
   - Support multi-select Curated AI Voices (`<= 6`) and display active `My Cloned Voices` badge with direct selection.
   - Keep Expressive Nuance (`voice_dialect_grid_card`) expanded by default with a collapsible toggle header so both `phase56` test #2 and `bantu_voice_deck_test.dart` (`findsNWidgets(4)` `Slider`s) pass untouched!
   - In `LyricsReviewModal`: pass full V6 state in `_approveDraft`, replace `Icon(PhosphorIcons.treeStructure(...))` with `PhosphorIcon(PhosphorIconsRegular.treeStructure)`, and style `[VOICE A]` / `[VOICE B]` / `[DUET]` badges distinctly.

7. **`InlineCrateMpcWorkbench` (`inline_crate_mpc_workbench.dart`) & `MpcSlicerDeck` (`mpc_slicer_deck.dart`):**
   - Replace 4-column `Row` with `VhunambiGlassTabBar(scrollable: true, ...)` preserving `Key('workbench_mode_crate')`, `Key('workbench_mode_mpc')`, `Key('workbench_mode_sketchpad')`, `Key('workbench_mode_daw_upload')`.
   - Fix MPC header spacing (`'${mpcState.bpm} BPM · Stretch ${mpcState.timeStretchRatio.toStringAsFixed(1)}x'`) and replace fixed `72x54` `Wrap` with responsive 4-column `LayoutBuilder` rows (`minHeight: 56`, zero bottom clipping).
   - Wire `Key('mpc_send_to_studio')` in `MpcSlicerDeck` to attach bounced MPC chop metadata to `studioFormProvider` and switch `studioCockpitTabProvider` to `CockpitWorkspaceTab.compose`.

8. **`GenerationPipelineCard` (`generation_pipeline_card.dart`) & `StudioPastSongsRemixShelf` (`studio_past_songs_remix_shelf.dart`):**
   - Upgrade `GenerationPipelineCard` to frosted `VhunambiGlassSurface` while strictly preserving the 4 primary step labels (`'Starting up...'`, `'Writing lyrics...'`, `'Producing the beat...'`, `'Your song is ready!'`), exactly `2` `CircularProgressIndicator`s when generating, and `4` `AppIcons.check` glyphs when ready (`generation_pipeline_card_test.dart#L115-L148`)!
   - Render the 4-pill `BakeStage` Cinematic Progress Strip (`Planning` · `Composing` · `Vocal Polish` · `Mastering` using `PhosphorIconsFill.checkCircle` / animated pulse dots — zero extra `CircularProgressIndicator` or `AppIcons.check`), `"Safe to explore — we'll notify you when ready"` banner while `isGenerating`, multi-take selector (`Key('pipeline_take_chip_0')`..`3`) when `takes.length > 1`, and `"MiniMax-Music3"` attribution pill (`Key('pipeline_minimax_attribution_badge')`) whenever `attributionTag == 'MiniMax-Music3'`.
   - Preserve existing `'Result'`, `'New song'`, `'Play Master'`, `'Create Reel'`, `'Show lyrics'` labels and keys so `generation_pipeline_card_test.dart` and `phase64_studio_scroll_and_audio_test.dart` stay 100% green.
   - New `StudioPastSongsRemixShelf`: searchable glass card reading `libraryTracksProvider` (non-deleted tracks) with 1-tap `Remix` button setting `referenceAudioPath`, `audioMode: ReferenceAudioMode.remix`, `sourceTrackId`, and `genre`.

9. **`STD-UIUX-001` Cleanup (`guided_lyrics_composer.dart`, `song_dna_node_tree_modal.dart`, `studio_action_bar.dart`):**
   - Strip raw dingbat/emoji codepoints (`U+2726`, `U+2794`, and `U+26A1`) from `guided_lyrics_composer.dart#L436,#L537` and `song_dna_node_tree_modal.dart#L1702`.
   - In `StudioActionBar`: reflect `batchCount` (`e.g. 'Write Lyrics First'` / `'Generate Song (2 Takes)'`), pass `LyricsMode.fromPhoto` & `LyricsMode.myOwn` cleanly, and use `AppColors.*Of(context)`.
