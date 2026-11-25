# Phase 84 Implementation Task Plan — Media Pipeline Overhaul, Edge ID3v2 Extraction, Kinetic Reels 98% Fix, Kinetic Post Uploads & Zania Music Flywheel

> **Spec Suite ID:** `SPEC-P84-MEDIA-ID3-REELS98-KPOST`  
> **Companion Documents:** `blueprint.md`, `requirements.md`, `design.md`, `memory.md`  
> **Execution Mode:** Stage 4 Two-Pass Implementation (`/vhunambi-executioner`: Pass 1 = SQL + Worker Edge API + CLI; Pass 2 = Flutter Client Upload/Reels/KPost + Full Regression Verification)

---

## §1. Master Milestone Roadmap & Dependency Graph

```text
+---------------------------------------------------------------------------------------------------+
|                             PHASE 84 EXECUTION ROADMAP (M1 -> M6)                                 |
+---------------------------------------------------------------------------------------------------+
|                                                                                                   |
|  [PASS 1: SCHEMA, EDGE MEDIA ENGINE & DURABLE CLOUD PERSISTENCE]                                  |
|   M1: Supabase Additive Migration + Pure Edge Media Modules (id3v2_parser, etag, cursor)          |
|    |                                                                                              |
|    v                                                                                              |
|   M2: Worker Direct-to-R2 (/presign-put + /finalize + ID3), fetchR2ByteRange & Durable Write      |
|    |  (upsertKineticPostAsync, upsertExploreTrackAsync, GET /api/explore/tracks Cursor + 304)     |
|    |                                                                                              |
|  [PASS 2: FLUTTER CLIENT FIXES, KINETIC POST UPLOADS & ZANIA FLYWHEEL CLI]                        |
|    v                                                                                              |
|   M3: Flutter Replay-Safe 401 Interceptor, UploadedMediaAsset ID3 Fields & Direct-to-R2 Repo      |
|    |  (sovereign_api_client, media_mime_utils, http_media_upload_repository, queue provider)      |
|    v                                                                                              |
|   M4: Kinetic Reels 98% End-to-End Fix (MIME inference, audio dedupe, 20s publishClip errors)     |
|    |                                                                                              |
|    v                                                                                              |
|   M5: Kinetic Post Real Audio/Photo Uploads, Zero Mock Defaults & refreshFromCloud() Hydration    |
|    |                                                                                              |
|    v                                                                                              |
|   M6: Zania Music Ingest CLI (tools/zania-ingest/) + API/Flutter Test Suites + Deploy + SLEEP     |
|                                                                                                   |
+---------------------------------------------------------------------------------------------------+
```

| Milestone | Scope | Primary Files | Gate |
| :---: | :--- | :--- | :---: |
| **`M1`** | SQL Migration + Pure Edge ID3v2 / ETag / Cursor | `supabase/migrations/20261125000001_*.sql`, `apps/vhunambi_api/src/modules/media/{id3v2_parser,etag,cursor}.ts` | `G-01` |
| **`M2`** | R2 Range Reader + `/presign-put` + `/finalize` + Durable Explore | `r2_storage.ts`, `media_routes.ts`, `edge_persistence_bridge.ts`, `vhunambi_db.ts`, `explore_routes.ts` | `G-01`, `G-02` |
| **`M3`** | Flutter Replay-Safe `401` + Direct-to-R2 Upload Engine | `media_mime_utils.dart`, `sovereign_api_client.dart`, `uploaded_media_asset.dart`, `http_media_upload_repository.dart`, `media_upload_queue_provider.dart` | `G-03`, `G-04` |
| **`M4`** | Kinetic Reels `98%` Fix + Vault Sync UI | `kinetic_reel_studio_view.dart`, `reel_audio_picker_sheet.dart`, `kinetic_reel_publish_view.dart`, `http_social_repository.dart`, `uploads_vault_view.dart` | `G-03`, `G-04` |
| **`M5`** | Kinetic Post Direct Uploads + Feed Hydration | `create_kinetic_post_sheet.dart`, `explore_providers.dart` | `G-03`, `G-04` |
| **`M6`** | Zania CLI + Tests + Deploy + Memory Consolidation | `tools/zania-ingest/ingest_zania_catalog.mjs`, `phase84_media_id3_and_presign.test.ts`, `phase84_media_reels_kpost_test.dart`, `memory.md` | `G-01..G-06` |

---

## §2. Milestone M1 — Additive Migration & Pure Edge Media Modules

- [x] **Task 1.1 — Author Additive Supabase Migration**
  - **Target File:** `supabase/migrations/20261125000001_phase84_media_id3_and_zania_ingest.sql`
  - **Contract:** Add `id3_metadata_json JSONB NOT NULL DEFAULT '{}'::jsonb` and `content_sha256 TEXT` to `public.user_media_uploads`; add `content_sha256 TEXT`, `source_origin TEXT NOT NULL DEFAULT 'vhunambi_studio'`, `lyrics_text TEXT NOT NULL DEFAULT ''` to `public.explore_tracks`; add partial/unique SHA-256 indexes and `idx_kinetic_posts_creator_created`.
  - **Acceptance Criteria:** Migration is 100% idempotent (`IF NOT EXISTS`), alters zero existing RLS policies, and introduces `0` Supabase advisor warnings.

- [x] **Task 1.2 — Implement Pure Edge ID3v2.3 / ID3v2.4 Extractor**
  - **Target File:** `apps/vhunambi_api/src/modules/media/id3v2_parser.ts`
  - **Exports:** `readId3TagByteLength(data: Uint8Array)`, `extractId3v2Metadata(data: Uint8Array)`, `extractApicFrame(data: Uint8Array)`, `ID3_INITIAL_RANGE_BYTES`, `ID3_MAX_RANGE_BYTES`.
  - **Acceptance Criteria:** Decodes `APIC` (`image/jpeg`, `image/png`, `image/webp` + `'image/jpg'` alias + magic-byte fallback), `TIT2`, `TPE1`, `TALB`, `TCON` (strips ID3v1 `(17)` prefix), `TBPM` (`[30, 300]`), and `USLT`; handles ISO-8859-1 / UTF-16 BOM / UTF-16BE / UTF-8 with Unicode NFC preservation for Tshivenḓa diacritics; zero Node `fs`/`path`/`Buffer` imports.

- [x] **Task 1.3 — Implement Pure Edge FNV-1a ETag & Keyset Cursor**
  - **Target Files:** `apps/vhunambi_api/src/modules/media/etag.ts`, `apps/vhunambi_api/src/modules/media/cursor.ts`
  - **Exports:** `computeEdgeEtag`, `isIfNoneMatchHit`, `encodeExploreCursor`, `decodeExploreCursor`.
  - **Acceptance Criteria:** Zero Node `crypto`/`Buffer` imports; `decodeExploreCursor` returns `null` (never throws) on malformed base64 or JSON; weak `ETag` matches RFC 7232 `If-None-Match` lists.

---

## §3. Milestone M2 — Direct-to-R2 Endpoints, R2 Byte Range & Durable Write-Through

- [x] **Task 2.1 — Add `fetchR2ByteRange` to R2 Storage Adapter**
  - **Target File:** `apps/vhunambi_api/src/modules/synthesis/r2_storage.ts`
  - **Signature:** `export async function fetchR2ByteRange(objectKey, startByte, endByte, cOrEnv?): Promise<R2ByteRangeResult | null>`
  - **Acceptance Criteria:** Supports 3-tier lookup: `inMemoryR2Objects` (tests) -> Cloudflare `VHUNAMBI_VAULT.get(key, { range: { offset, length } })` -> `aws4fetch` S3 `Range: bytes=start-end` fallback.

- [x] **Task 2.2 — Add `/api/media/presign-put`, `/api/media/finalize` & Upgrade `/api/media/upload` with ID3 Extraction**
  - **Target File:** `apps/vhunambi_api/src/routes/media_routes.ts`
  - **Acceptance Criteria:**
    - Adds `'audio/flac': 'flac'` to `ALLOWED_MEDIA_UPLOAD_MIMES`.
    - `POST /api/media/presign-put` validates MIME + `<= 100 MB` (video/audio) / `<= 25 MB` (image), supports `contentSha256` dedupe (`200`), and mints SigV4 PUT URL (`201`) or `uploadStrategy: "worker_binary"`.
    - `POST /api/media/finalize` enforces `media/${creatorId}/` tenant prefix (`403`), reads `<= 256 KiB` (bounded extension `<= 2 MiB`), persists extracted `APIC` cover to `covers/${creatorId}/${uploadId}.${ext}`, and commits `user_media_uploads` via `awaitWriteThrough`.
    - Existing `POST /api/media/upload` runs `extractAndPersistAudioId3FromBytes` on `audio/*` uploads before returning `201`.

- [x] **Task 2.3 — Add `upsertKineticPostAsync`, `upsertExploreTrackAsync` & `findUserMediaUploadBySha256`**
  - **Target Files:** `apps/vhunambi_api/src/db/edge_persistence_bridge.ts`, `apps/vhunambi_api/src/db/vhunambi_db.ts`
  - **Acceptance Criteria:** `recordUserMediaUpload` / `recordUserMediaUploadAsync` persists `id3_metadata_json` and `content_sha256`; `upsertKineticPostAsync` and `upsertExploreTrackAsync` await Supabase write-through (`awaitWriteThrough`) so zero rows are dropped on Worker teardown.

- [x] **Task 2.4 — Wire Durable Write-Through & Cursor/ETag into Explore Routes**
  - **Target File:** `apps/vhunambi_api/src/routes/explore_routes.ts`
  - **Acceptance Criteria:** `POST /api/explore/posts` awaits `upsertKineticPostAsync`; `POST /api/explore/tracks` awaits `upsertExploreTrackAsync`; `GET /api/explore/tracks` returns `nextCursor`, `ETag`, and `304 Not Modified` on `If-None-Match` hit.

---

## §4. Milestone M3 — Flutter Replay-Safe 401 & Direct-to-R2 Upload Engine

- [x] **Task 3.1 — Add `media_mime_utils.dart` Helper**
  - **Target File:** `apps/vhunambi_client/lib/features/media/domain/utils/media_mime_utils.dart`
  - **Exports:** `inferMimeTypeFromMedia(...)`, `isVideoFilenameOrMime(...)`.
  - **Acceptance Criteria:** Correctly resolves `.mp4`, `.mov`, `.webm`, `.jpg`/`.jpeg`, `.png`, `.webp`, `.mp3`, `.wav`, `.m4a`, `.aac`, `.ogg`, `.flac`, and normalizes `'image/jpg'` -> `'image/jpeg'`.

- [x] **Task 3.2 — Harden `SovereignApiClient.buildDioInterceptor` Against Finalized `FormData` Replay**
  - **Target File:** `apps/vhunambi_client/lib/core/network/sovereign_api_client.dart`
  - **Acceptance Criteria:** On `401` refresh, invokes `opts.extra['_p84BodyBuilder']` if supplied; if `opts.data is FormData` with no builder, never calls `client.fetch(opts)` on the finalized stream (`REEL98-01`).

- [x] **Task 3.3 — Extend `UploadedMediaAsset` with ID3 Cover & Track Metadata Fields**
  - **Target File:** `apps/vhunambi_client/lib/features/media/domain/models/uploaded_media_asset.dart`
  - **Fields Added:** `thumbnailUrl`, `artist`, `album`, `genre`, `bpm`, `contentSha256`, plus `bestCoverSource` getter.
  - **Acceptance Criteria:** 100% backward compatible with existing Hive snapshots; `fromJson` parses both camelCase and snake_case (`thumbnail_url`, `id3_metadata_json`).

- [x] **Task 3.4 — Upgrade `HttpMediaUploadRepository` & `MediaUploadQueueNotifier` to Direct-to-R2 Flow**
  - **Target Files:** `apps/vhunambi_client/lib/features/media/data/repositories/http_media_upload_repository.dart`, `apps/vhunambi_client/lib/features/media/presentation/providers/media_upload_queue_provider.dart`
  - **Acceptance Criteria:** Executes `POST /api/media/presign-put` -> direct R2 `PUT` (streaming raw bytes, `0.05 -> 0.90`) -> `POST /api/media/finalize` (`0.94 -> 1.00`), falling back to replay-safe raw binary `POST /api/media/upload` when `uploadStrategy == 'worker_binary'`; adds `awaitOrRetryAsset(String assetId)` deduplicating concurrent in-flight uploads (`_inFlightUploads`).

---

## §5. Milestone M4 — Kinetic Reels 98% Fix & Uploads Vault Sync UI

- [x] **Task 4.1 — Replace Hardcoded MIME in `KineticReelStudioView._pickGalleryMedia`**
  - **Target File:** `apps/vhunambi_client/lib/features/content_studio/presentation/views/kinetic_reel_studio_view.dart`
  - **Acceptance Criteria:** Uses `inferMimeTypeFromMedia(filename: media.name, declaredMime: media.mimeType)` so `.png`, `.webp`, `.mov`, `.webm` never fail backend MIME validation (`REEL98-03`).

- [x] **Task 4.2 — Eliminate Duplicate Audio Re-Upload in `ReelAudioPickerSheet` & `KineticReelPublishView`**
  - **Target Files:** `apps/vhunambi_client/lib/features/content_studio/presentation/widgets/reel_audio_picker_sheet.dart`, `apps/vhunambi_client/lib/features/content_studio/presentation/views/kinetic_reel_publish_view.dart`
  - **Acceptance Criteria:** `ReelAudioPickerSheet` passes `stagedAudioAssetId` onto `ReelAudioSelection`; `KineticReelPublishView._submitPublish()` calls `queueNotifier.awaitOrRetryAsset(stagedAudioAssetId)` instead of uploading `importedAudioBytes` a second time (`REEL98-04`). Surface `Key('reel_publish_error_banner')` + `Key('reel_publish_retry_btn')` on error.

- [x] **Task 4.3 — Raise `publishClip` Timeout to 20s & Stop Silent Production Fake Clips**
  - **Target File:** `apps/vhunambi_client/lib/features/social/data/repositories/http_social_repository.dart`
  - **Acceptance Criteria:** Overrides `sendTimeout` and `receiveTimeout` to `20s` on `POST /api/social/publish`; only invokes `_publishClipFallback()` when `_shouldSkipNetwork == true` (`REEL98-05`).

- [x] **Task 4.4 — Upgrade `UploadsVaultView` to Render Extracted ID3 Covers & Explicit Cloud Sync Retry**
  - **Target File:** `apps/vhunambi_client/lib/features/library/presentation/views/uploads_vault_view.dart`
  - **Acceptance Criteria:** Renders `asset.bestCoverSource` via `VhunambiTrackArtwork`, displays `Synced` / `Uploading` / `Failed` status badges (`PhosphorIcon`, `AppColors.*Of(context)`, `>= 44dp`), and surfaces `Key('uploads_vault_retry_all_btn')` whenever any failed upload exists.

---

## §6. Milestone M5 — Kinetic Post Real Uploads & Feed Cloud Hydration

- [x] **Task 5.1 — Overhaul `CreateKineticPostSheet` with Real Audio/Photo Uploads & Zero Mock Assets**
  - **Target File:** `apps/vhunambi_client/lib/features/explore/presentation/widgets/create_kinetic_post_sheet.dart`
  - **Acceptance Criteria:**
    - `_audioSourceTabIndex` defaults to `0` (`My Uploads`); `_selectedTrack` initializes to `widget.initialTrack` (`null` if absent).
    - Adds `Key('kpost_upload_audio_btn')` (`>= 44dp`, `PhosphorIcon(PhosphorIconsBold.uploadSimple)`) uploading MP3/WAV/M4A/AAC/OGG/FLAC via `MediaUploadQueueNotifier` and attaching the synced track + extracted ID3 cover.
    - Removes `_grooveSeeds` (`sk_01..03`) and `'kpost_track_default'` / `'Vhunambi Sonic Groove'`.
    - `_pickAndUploadPhoto()` (`Key('kpost_upload_photo_btn')`) awaits cloud `remoteUrl` (`awaitUpload: true`) before allowing publish.
    - `_generateVisionAiArtwork()` (`Key('kpost_vision_ai_btn')`) never injects bundled mock `asset:` artwork on error; displays `Key('kpost_vision_unavailable_notice')`.

- [x] **Task 5.2 — Fix `SocialFeedPostsNotifier.refreshFromCloud()` Media Hydration**
  - **Target File:** `apps/vhunambi_client/lib/features/explore/presentation/providers/explore_providers.dart`
  - **Acceptance Criteria:** Hydrates `imageAttachment`, `imageAttachments`, `audioUrl` / `audioPreviewUrl`, `coverUrl`, `trackId`, `trackTitle`, and `genre` cleanly on cloud refresh (`KPOST-03`).

---

## §7. Milestone M6 — Zania Music Ingest CLI, Full Tests, Cloud Deploy & Memory Consolidation

- [x] **Task 6.1 — Create Zero-Dependency Zania Music Bulk Ingest CLI**
  - **Target File:** `tools/zania-ingest/ingest_zania_catalog.mjs`
  - **Acceptance Criteria:** Implements §6 of `design.md`; `--dry-run` against `C:\Users\Ndugelo\Music\ZANIA MUSIC\READY` scans all `189` MP3s with `< 150 MB` RAM and `0` errors.

- [x] **Task 6.2 — Author Phase 84 API & Flutter Regression Test Suites**
  - **Target Files:** `apps/vhunambi_api/test/phase84_media_id3_and_presign.test.ts` (add to `package.json` `test` script!), `apps/vhunambi_client/test/features/media/phase84_media_reels_kpost_test.dart`
  - **Acceptance Criteria:** 100% requirement coverage per `requirements.md` §9 traceability matrix; Flutter tests pass under `--timeout=60s`.

- [x] **Task 6.3 — Deploy Supabase Migration + Cloudflare Worker + Finalize `memory.md`**
  - **Acceptance Criteria:** Apply `20261125000001_phase84_media_id3_and_zania_ingest.sql`, deploy `vhunambi-api` Worker, verify live `/health` and `/api/media/presign-put`, update `PHASE_80_PLUS_STUDIO_AND_RUNPOD_MASTER_TRACKER.md`, mark `memory.md` `"status": "completed"`, and run `node .agents/skills/vhunambi-memory/scripts/consolidate_memory.mjs`.

---

## §8. Stage 4 Anti-Trap & Execution Verification Checklist

- [x] **Anti-Trap 1 (Edge Purity):** `id3v2_parser.ts`, `etag.ts`, `cursor.ts` contain zero `node:fs`, `node:path`, `Buffer`, `next/*`, or `drizzle-orm` imports.
- [x] **Anti-Trap 2 (Truncated ID3 Window Guard):** `extractId3v2Metadata` clamps iteration at `Math.min(data.length, tagByteLength)` and `/finalize` caps range extensions at `2 MiB`.
- [x] **Anti-Trap 3 (Zero Finalized FormData Replay):** `SovereignApiClient.buildDioInterceptor()` checks `opts.data is FormData` and `HttpMediaUploadRepository` uses Direct-to-R2 PUT / raw binary fallback.
- [x] **Anti-Trap 4 (Authentic Imports & Tokens):** All Dart code uses `package:vhunambi_client/...`, `package:phosphor_icons/phosphor_icons.dart`, `AppColors.*Of(context)`, and valid `AppTypography.*` getters.
- [x] **Anti-Trap 5 (`STD-UIUX-001`):** `0` stock `Icons.*` and `0` raw Unicode emojis across every modified `.dart` file; all buttons `>= 44x44dp`.
- [x] **Anti-Trap 6 (Durable Write-Through):** `POST /api/explore/posts` and `POST /api/explore/tracks` await `awaitWriteThrough` before HTTP `201`.
- [x] **Anti-Trap 7 (Bounded Widget Tests):** Every Flutter widget test avoids unbounded `pumpAndSettle()` on active animations and passes under `--timeout=60s`.

---

## §9. Exact Verification Gate Commands (PowerShell — Windows Safe)

```powershell
# 1. Backend Typecheck & Full Test Suite (avoid Windows npx hangs)
cd apps\vhunambi_api
.\node_modules\.bin\tsc.cmd --noEmit
npm test

# 2. Flutter Static Analysis & Targeted + Regression Widget Tests
cd ..\vhunambi_client
flutter analyze --no-pub
flutter test test/features/media/phase84_media_reels_kpost_test.dart --timeout=60s

# 3. Zania Music CLI Dry-Run Smoke (Zero Local Docker / <150 MB RAM)
cd ..\..
node tools/zania-ingest/ingest_zania_catalog.mjs --dir "C:\Users\Ndugelo\Music\ZANIA MUSIC\READY" --dry-run

# 4. Stage 4 SLEEP Consolidation (ONLY after G-01..G-06 pass & memory.md status="completed")
node .agents/skills/vhunambi-memory/scripts/consolidate_memory.mjs
```
