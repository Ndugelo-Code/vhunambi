# Phase 84 Requirements Specification — Media Pipeline Overhaul, Edge ID3v2 Extraction, Kinetic Reels 98% Fix, Kinetic Post Uploads & Zania Music Flywheel

> **Spec Suite ID:** `SPEC-P84-MEDIA-ID3-REELS98-KPOST`  
> **Companion Documents:** `blueprint.md`, `design.md`, `tasks.md`, `memory.md`  
> **Workflow Standard:** Vhunambi All-Gemini 5-Document Specification Standard (`STD-UIUX-001`)

---

## §1. Document Scope & EARS / RFC-2119 Conventions

This specification defines every functional, data-contract, UI/UX, and non-functional requirement for **Phase 84**. All requirements use strict EARS syntax (`WHEN`, `WHILE`, `IF ... THEN`, `WHERE`, `THE SYSTEM SHALL`) combined with RFC-2119 normatives (`MUST`, `SHALL`, `SHOULD`, `MUST NOT`).

**Key Coordinate & Domain Conventions:**
- All R2 object keys are bucket-relative without leading slashes (`media/{creatorId}/{uploadId}.{ext}`, `covers/{creatorId}/{uploadId}.{ext}`).
- All cloud media URLs exposed to clients use normalized `/r2/{objectKey}` paths (resolved via `AppConstants.normalizeCloudMediaUrl`).
- All audio duration fields use milliseconds (`durationMs`) on `UploadedMediaAsset` / `user_media_uploads` and seconds (`durationSec`) on `explore_tracks`.
- All Flutter UI components strictly obey `STD-UIUX-001`: `package:vhunambi_client/...`, `package:phosphor_icons/phosphor_icons.dart`, `AppColors.*Of(context)`, valid `AppTypography.*` getters, `>= 44x44dp` touch targets, and **zero raw Unicode emojis**.

---

## §2. Direct-to-R2 Presigned Upload Requirements (`REQ-P84-PRESIGN-*`)

### `REQ-P84-PRESIGN-01` — Presigned Direct-to-R2 PUT Minting
**WHEN** an authenticated creator sends `POST /api/media/presign-put` with `{ filename, mimeType, sizeBytes, mediaKind?, title?, sourceSurface?, contentSha256? }`, **THE SYSTEM SHALL**:
1. Validate `mimeType` against the expanded allow-list (including `video/mp4`, `video/quicktime`, `video/webm`, `image/jpeg`, `image/png`, `image/webp`, `audio/mpeg`, `audio/mp4`, `audio/wav`, `audio/x-wav`, `audio/wave`, `audio/aac`, `audio/ogg`, `audio/flac`).
2. Enforce `sizeBytes > 0` and `sizeBytes <= 104_857_600` (`100 MB` for video/audio; `<= 26_214_400` / `25 MB` for images), returning HTTP `413 PAYLOAD_TOO_LARGE` when exceeded or `415 UNSUPPORTED_MEDIA_TYPE` on unsupported MIME.
3. IF `contentSha256` matches an existing non-deleted upload owned by the same `creatorId`, **THE SYSTEM SHALL** return HTTP `200` with `{ success: true, deduplicated: true, asset }` without minting a new R2 object.
4. Otherwise, mint `uploadId = "upl_<ts>_<nanoid8>"`, compute `r2Key = "media/<creatorId>/<uploadId>.<ext>"`, generate a 1-hour SigV4 `putUrl` via `getPresignedPutUrl(r2Key, mimeType, 3600, c)` when R2 credentials are active (or set `uploadStrategy: "worker_binary"` when R2 S3 credentials are absent in local/test mode), and return HTTP `201` with `{ success: true, deduplicated: false, uploadId, r2Key, remoteUrl: "/r2/" + r2Key, putUrl, uploadStrategy, expiresInSec: 3600 }`.

### `REQ-P84-PRESIGN-02` — Upload Finalization & Durable Cloud Commit
**WHEN** an authenticated creator sends `POST /api/media/finalize` with `{ uploadId, r2Key, filename, mimeType, sizeBytes, title?, sourceSurface?, durationMs?, width?, height?, thumbnailUrl?, contentSha256? }`, **THE SYSTEM SHALL**:
1. Verify tenant ownership (`r2Key` MUST begin with `media/${creatorId}/` unless `authUser.role === 'admin'`; otherwise return HTTP `403 TENANT_FORBIDDEN`).
2. Verify the object exists in R2 (or in-memory test vault) via `fetchR2ByteRange(r2Key, 0, 262143, c)`. If missing, return HTTP `404 OBJECT_NOT_FOUND`.
3. IF `mimeType.startsWith('audio/')`, run `REQ-P84-ID3-01`..`03` over the fetched header bytes to populate `thumbnailUrl`, `title` (when user did not supply an explicit title), and `id3Metadata`.
4. Commit the record to Supabase `public.user_media_uploads` via `await vhunambiDb.recordUserMediaUploadAsync(..., c)` (`awaitWriteThrough`) before returning HTTP `201` with `{ success: true, asset, key: r2Key, url: "/r2/" + r2Key }`.

### `REQ-P84-PRESIGN-03` — Zero Worker Isolate RAM Exhaustion
**WHILE** handling uploads larger than `25 MB` via `/api/media/presign-put` + direct R2 `PUT` + `/api/media/finalize`, **THE SYSTEM SHALL NOT** read the full media payload into Cloudflare Worker isolate memory (`c.req.arrayBuffer()` / `fileBlob.arrayBuffer()`). Worker memory reads during `/finalize` **MUST** remain bounded to `<= 2_097_152` bytes (`2 MiB`).

---

## §3. Pure Edge ID3v2 Cover & Metadata Extraction Requirements (`REQ-P84-ID3-*`)

### `REQ-P84-ID3-01` — Pure Edge `Uint8Array` ID3v2.3 & ID3v2.4 Parser
**WHERE** `apps/vhunambi_api/src/modules/media/id3v2_parser.ts` executes inside Cloudflare Workers (`workerd`), **THE SYSTEM SHALL** parse ID3v2.3 and ID3v2.4 headers using exclusively standard Web APIs (`Uint8Array`, `DataView`, `TextDecoder`, `String.prototype.normalize('NFC')`) with **zero** Node.js `fs`, `path`, or `Buffer` imports.

### `REQ-P84-ID3-02` — Full Frame Extraction (`APIC` + Text + Lyrics)
**WHEN** `extractId3v2Metadata(bytes: Uint8Array)` parses a valid ID3v2.3 or ID3v2.4 header, **THE SYSTEM SHALL** extract:
- `apic`: First valid embedded picture frame (`APIC`) with normalized MIME type (`image/jpeg`, `image/png`, or `image/webp`; normalizing legacy `'image/jpg'` -> `'image/jpeg'`), returning `{ imageData: Uint8Array, mimeType, ext }`.
- `title` (`TIT2`), `artist` (`TPE1`), `album` (`TALB`), `genre` (`TCON`, stripping ID3v1 numeric genre parentheses like `"(17)Rock"` -> `"Rock"`), `bpm` (`TBPM`, parsed finite positive integer in `[30, 300]`), and `lyrics` (`USLT`, skipping 3-byte language code + null-terminated content descriptor).
- All decoded text frames **MUST** support ISO-8859-1 (`0`), UTF-16 with BOM (`1`), UTF-16BE (`2`), and UTF-8 (`3`) encodings and be NFC-normalized to preserve Tshivenḓa diacritics (`ḓ`, `ḽ`, `ṋ`, `ṅ`, `ṱ`).

### `REQ-P84-ID3-03` — Bounded Range Extension & Automatic R2 Cover Persistence
**WHEN** `POST /api/media/finalize` or `POST /api/media/upload` processes an `audio/mpeg` (or ID3-tagged audio) payload:
1. If `readId3TagByteLength(initial256Kb)` exceeds `262_144` bytes and is `<= 2_097_152` bytes, `/finalize` **SHALL** perform at most **one** follow-up `fetchR2ByteRange` call to fetch the remaining tag bytes.
2. If an `APIC` cover frame is found and no explicit `thumbnailUrl` was provided, **THE SYSTEM SHALL** write the extracted cover bytes to R2 key `covers/${creatorId}/${uploadId}.${apic.ext}` with `Cache-Control: public, max-age=31536000, immutable` and persist `thumbnailUrl = "/r2/covers/${creatorId}/${uploadId}.${apic.ext}"`.
3. Extracted `artist`, `album`, `genre`, `bpm`, and `hasEmbeddedCover` **SHALL** be stored in `user_media_uploads.id3_metadata_json` and returned on the serialized `asset` payload so Flutter `UploadedMediaAsset` renders the cover immediately without re-downloading audio bytes.

---

## §4. Kinetic Reels 98% Crash Remediation Requirements (`REQ-P84-REEL98-*`)

### `REQ-P84-REEL98-01` — Replay-Safe `401` Auth Interceptor (Zero Finalized `FormData` Crash)
**WHEN** `SovereignApiClient.buildDioInterceptor()` intercepts an HTTP `401` response and refreshes the session via `singleFlightRefresh()`:
1. **IF** `error.requestOptions.data` is a `FormData` instance (whose single-use stream is already finalized), **THE SYSTEM SHALL NOT** pass that consumed `FormData` directly to `client.fetch(opts)`.
2. Instead, `buildDioInterceptor()` **SHALL** check for a request-level `extra['_p84BodyBuilder']` (`Object Function()`) callback to rebuild a fresh payload before calling `client.fetch(opts)`, OR return the refreshed error cleanly if no builder exists so callers never throw `Bad state: The FormData has already been finalized`.
3. Additionally, `HttpMediaUploadRepository.uploadMedia()` **SHALL** prefer Direct-to-R2 `PUT` (which sends raw `Uint8List` bytes directly to `putUrl` after presign) and fallback to raw binary `POST /api/media/upload` with `x-media-*` headers (never finalized `FormData` streams) when presigning is unavailable.

### `REQ-P84-REEL98-02` — True Upload Progress & Unified Vault Sync Visibility
**WHILE** `MediaUploadQueueNotifier` uploads an asset:
1. Direct-to-R2 uploads **SHALL** emit monotonic progress `0.05` (presign) -> `0.05..0.90` (R2 stream `PUT`) -> `0.94` (`/finalize` + ID3 extraction) -> `1.00` (synced).
2. `UploadsVaultView` **SHALL** display clear per-asset status pills (`Synced`, `Uploading`, `Failed — Tap Retry`) and surface a non-dismissive `Retry All Failed` action (`Key('uploads_vault_retry_all_btn')`) whenever any local asset fails cloud sync, plus display extracted `UploadedMediaAsset.thumbnailUrl` via `VhunambiTrackArtwork`.

### `REQ-P84-REEL98-03` — True MIME Inference in `KineticReelStudioView`
**WHEN** a creator picks gallery photo or video media in `KineticReelStudioView._pickGalleryMedia()`, **THE SYSTEM SHALL** infer the exact MIME type via `inferMimeTypeFromMedia(filename: media.name, declaredMime: media.mimeType)` (mapping `.png`, `.webp`, `.jpg`/`.jpeg`, `.mov`, `.webm`, `.mp4`, `.mp3`, `.wav`, `.m4a`, `.aac`, `.ogg`, `.flac`) instead of hardcoding `'video/mp4'` or `'image/jpeg'`.

### `REQ-P84-REEL98-04` — Zero Duplicate Audio Upload Across Reel Picker & Publish
**WHEN** a creator imports audio inside `ReelAudioPickerSheet`:
1. `ReelAudioPickerSheet` **SHALL** attach the staged `stagedAudioAssetId` onto `ReelAudioSelection`.
2. `KineticReelPublishView._submitPublish()` **SHALL** inspect `mediaUploadQueueProvider` for `stagedAudioAssetId` first: if already `MediaUploadStatus.synced` with a valid `remoteUrl`, reuse it immediately (`0` bytes uploaded); if `uploading`, await its completion; only enqueue a new upload if `stagedAudioAssetId` is absent or missing.

### `REQ-P84-REEL98-05` — Honest `publishClip` Timeout & Error Surfacing
**WHEN** `HttpSocialRepository.publishClip()` calls `POST /api/social/publish`:
1. The request **SHALL** use an explicit `Options(receiveTimeout: const Duration(seconds: 20), sendTimeout: const Duration(seconds: 20))` override (replacing the `4s` default).
2. **IF** `_shouldSkipNetwork` is `false` (all non-test production runs) and the server returns a non-`201` response or times out, `publishClip()` **SHALL** throw a typed `StateError` / `DioException` (MUST NOT silently fabricate a local `_publishClipFallback()` clip), so `KineticReelPublishView` displays an explicit error banner (`Key('reel_publish_error_banner')`) with a `Retry Publish` button (`Key('reel_publish_retry_btn')`).

---

## §5. Kinetic Post Real Uploads & Cloud Hydration Requirements (`REQ-P84-KPOST-*`)

### `REQ-P84-KPOST-01` — Direct Audio & Photo Upload CTAs & Zero Mock Defaults
**WHEN** a creator opens `CreateKineticPostSheet`:
1. `_audioSourceTabIndex` **SHALL** default to `0` (`My Uploads`) instead of `2` (`Trending`), and `_selectedTrack` **SHALL** initialize to `null` (unless `initialTrack` was explicitly passed by the caller) instead of auto-attaching seeded `initialTracks.first`.
2. The Sound Attachment deck **SHALL** render an explicit `Upload Audio` button (`Key('kpost_upload_audio_btn')`, `>= 44dp` height, `PhosphorIcon(PhosphorIconsBold.uploadSimple)`) that launches `FilePicker` (`mp3/wav/m4a/aac/ogg/flac`), uploads via `MediaUploadQueueNotifier.stageAndEnqueue(..., awaitUpload: true)`, populates the newly synced track card with its extracted ID3 `APIC` cover art + title/genre/BPM, and selects it automatically.
3. Hardcoded mock `_grooveSeeds` (`sk_01..03`) and fallback `'Vhunambi Sonic Groove'` (`id: 'kpost_track_default'`) **SHALL BE REMOVED**. A creator MAY publish a caption + photo post without attaching a track, or attach any real uploaded / studio / catalog track.

### `REQ-P84-KPOST-02` — Honest Vision AI Artwork (Zero Silent Mock Asset Injection)
**WHEN** a creator taps `Vision AI` (`Key('kpost_vision_ai_btn')`) inside `CreateKineticPostSheet`:
1. **IF** `POST /v1/vision/generate` fails, times out, or returns a non-HTTPS/mock fallback (`isMock == true`), **THE SYSTEM SHALL NOT** silently attach a bundled `asset:assets/images/artwork/...` mock image.
2. Instead, **THE SYSTEM SHALL** display an honest inline error state/snackbar explaining that Vision AI generation is temporarily unavailable and inviting the user to upload a real photo.

### `REQ-P84-KPOST-03` — Awaited Media Uploads, Durable Supabase Write-Through & Full Feed Hydration
1. **WHEN** a creator picks a photo in `CreateKineticPostSheet._pickAndUploadPhoto()` (`Key('kpost_upload_photo_btn')`), **THE SYSTEM SHALL** stage & await upload completion (`awaitUpload: true`, showing an inline uploading indicator and blocking Publish until all attached photos/audio resolve to cloud `remoteUrl`s — never posting a device-only `localFilePath`).
2. **WHEN** `POST /api/explore/posts` executes on `apps/vhunambi_api`, **THE SYSTEM SHALL** call `await vhunambiDb.upsertKineticPostAsync(..., c)` (using `awaitWriteThrough`) so the row is durably committed to Supabase `public.kinetic_posts` before HTTP `201` is returned.
3. **WHEN** `SocialFeedPostsNotifier.refreshFromCloud()` (`explore_providers.dart`) hydrates posts from `GET /api/explore`, **THE SYSTEM SHALL** parse and preserve `imageAttachment`, `imageAttachments`, `audioAttachment`, `audioUrl`, `coverUrl`, `trackId`, `trackTitle`, and `genre` on both updated and newly hydrated `SocialMusicPost` instances.

---

## §6. Explore Edge Caching, Pagination & Zania Music Flywheel Requirements (`REQ-P84-EXPLORE-*` & `REQ-P84-ZANIA-*`)

### `REQ-P84-EXPLORE-01` — Edge Keyset Cursor & FNV-1a `ETag` on `GET /api/explore/tracks`
**WHEN** a client requests `GET /api/explore/tracks`:
1. **THE SYSTEM SHALL** support optional `?cursor=<base64url>` decoded by pure edge `decodeExploreCursor()` (malformed cursors MUST safely return `null` and fall back to page 1 — never throw `500`), returning `nextCursor: string | null` alongside `items`, `tracks`, `total`, and `serverSeq`.
2. **THE SYSTEM SHALL** compute a weak FNV-1a `ETag` (`computeEdgeEtag`) over the serialized response body, attach `ETag` and `Cache-Control: private, max-age=15, must-revalidate`, and return HTTP `304 Not Modified` with empty body whenever `If-None-Match` matches.

### `REQ-P84-ZANIA-01` — Zero-Duplication Idempotent Zania Music Bulk Ingest CLI
**WHERE** `tools/zania-ingest/ingest_zania_catalog.mjs` runs on Node 24 (`--dir <path> [--dry-run] [--api-url <url>] [--creator-id <id>] [--limit <n>]`):
1. **THE SYSTEM SHALL** recursively scan `READY/` MP3 files (streaming with `concurrency <= 2` and `< 150 MB` RAM), compute each file's SHA-256 hash (`contentSha256`), parse embedded ID3v2 tags + `APIC` cover via the shared pure parser, detect sibling `cover.{webp,png,jpg}` and `lyrics.txt` in the same leaf folder, and map folder paths deterministically via the §4.2 genre table.
2. **IF** `--dry-run` is set, print a complete JSON/table manifest without making network mutations.
3. **IF** live ingest is run, upload each track via `POST /api/media/presign-put` -> direct R2 `PUT` -> `POST /api/media/finalize` (skipping already-ingested `contentSha256` matches with zero duplication) and publish to `POST /api/explore/tracks` with `sourceOrigin: 'creator_upload_zania'` and `lyricsText`.

---

## §7. Non-Functional & Compliance Requirements (`REQ-P84-NFR-*`)

| ID | Requirement | Verification Bound |
| :--- | :--- | :--- |
| **`REQ-P84-NFR-01`** | **Cloudflare Workers Edge Purity:** `id3v2_parser.ts`, `etag.ts`, and `cursor.ts` MUST NOT import `node:fs`, `node:path`, `Buffer`, `next/*`, `drizzle-orm`, or React. | Static import check + `tsc --noEmit` + Worker tests |
| **`REQ-P84-NFR-02`** | **Supabase RLS Security Hygiene:** Additive columns on `user_media_uploads` and `explore_tracks` MUST preserve `((SELECT auth.jwt()) ->> 'creator_id') = creator_id` policies with `0` Supabase advisor warnings. | SQL migration inspection + advisor check |
| **`REQ-P84-NFR-03`** | **`STD-UIUX-001` Visual Compliance:** All modified Flutter views/sheets MUST use `PhosphorIcon`, `AppColors.*Of(context)`, valid `AppTypography.*`, `>= 44x44dp` tap targets, and `0` raw Unicode emojis or stock `Icons.*`. | Grep audit + `flutter analyze --no-pub` |
| **`REQ-P84-NFR-04`** | **Bounded Test Execution:** All Flutter widget tests MUST pass under `flutter test --timeout=60s` without `pumpAndSettle` hangs on active animations. | `flutter test --timeout=60s` |
| **`REQ-P84-NFR-05`** | **Zero-Laptop-Load Guarantee:** `tools/zania-ingest/` MUST execute with zero Docker containers, zero local FFmpeg binary requirements, and `< 150 MB` peak RAM. | CLI dry-run smoke on `C:\Users\Ndugelo\Music\ZANIA MUSIC` |

---

## §8. Error Resilience & Degradation Contracts

| Failure Scenario | Expected System Behavior |
| :--- | :--- |
| **MP3 has no ID3v2 header or corrupt `APIC` frame** | `extractId3v2Metadata()` returns `null` / empty metadata without throwing; upload succeeds cleanly with `thumbnailUrl = null` and filename-derived title. |
| **MP3 has `> 2 MB` embedded uncompressed BMP/PNG** | Range reader stops at `2 MiB` hard ceiling; text frames (`TIT2`/`TPE1`/`TCON`/`TBPM`) before `APIC` still decode; cover skipped safely with warning log. |
| **R2 S3 credentials absent in local/unit-test env** | `/api/media/presign-put` returns `uploadStrategy: "worker_binary"`; Flutter repository falls back to raw binary `POST /api/media/upload` with `x-media-*` headers (still replay-safe on `401`!). |
| **401 JWT expiry mid-upload** | `SovereignApiClient` refreshes JWT once via `singleFlightRefresh()`, rebuilds request cleanly via `_p84BodyBuilder` (never touching a finalized `FormData`), and completes upload seamlessly. |
| **Network drops during R2 PUT** | Local AppDocs staged file & Hive entry remain intact (`status: failed`); UI shows explicit error message + `Retry` button reusing `stagedAssetId` without re-picking from gallery. |

---

## §9. Requirement-to-Test Traceability Matrix

```text
+========================+==============================================+==================================================+
| Requirement ID         | Target Production Module / File              | Verification Test Case                           |
+========================+==============================================+==================================================+
| REQ-P84-PRESIGN-01..03 | apps/vhunambi_api/src/routes/media_routes.ts | phase84_media_id3_and_presign.test.ts:           |
|                        | apps/vhunambi_api/src/modules/synthesis/     |  - presign-put validates MIME/100MB/dedupe       |
|                        |   r2_storage.ts                              |  - finalize verifies tenant & commits Supabase   |
+------------------------+----------------------------------------------+--------------------------------------------------+
| REQ-P84-ID3-01..03     | apps/vhunambi_api/src/modules/media/         | phase84_media_id3_and_presign.test.ts:           |
|                        |   id3v2_parser.ts                            |  - ID3v2.3 & v2.4 APIC + image/jpg normalization |
|                        |                                              |  - TIT2/TPE1/TALB/TCON/TBPM/USLT + Venda NFC     |
|                        |                                              |  - truncated 256KB window + 2MB cap guard        |
+------------------------+----------------------------------------------+--------------------------------------------------+
| REQ-P84-REEL98-01..05  | sovereign_api_client.dart                    | phase84_media_reels_kpost_test.dart:             |
|                        | http_media_upload_repository.dart            |  - 401 replay never throws finalized FormData    |
|                        | media_upload_queue_provider.dart             |  - presign -> PUT -> finalize monotonic progress |
|                        | kinetic_reel_studio_view.dart                |  - inferMimeTypeFromMedia handles png/mov/mp3    |
|                        | reel_audio_picker_sheet.dart                 |  - stagedAudioAssetId prevents duplicate upload  |
|                        | kinetic_reel_publish_view.dart               |  - publishClip throws on prod failure (no fake)  |
|                        | http_social_repository.dart                  |                                                  |
+------------------------+----------------------------------------------+--------------------------------------------------+
| REQ-P84-KPOST-01..03   | create_kinetic_post_sheet.dart               | phase84_media_reels_kpost_test.dart:             |
|                        | explore_providers.dart                       |  - defaults to My Uploads, 0 mock _grooveSeeds   |
|                        | edge_persistence_bridge.ts                   |  - upload audio & photo CTAs await R2 URLs       |
|                        | explore_routes.ts                            |  - refreshFromCloud preserves images/audio/cover |
|                        |                                              | phase84_media_id3_and_presign.test.ts:           |
|                        |                                              |  - POST /api/explore/posts awaits write-through  |
+------------------------+----------------------------------------------+--------------------------------------------------+
| REQ-P84-EXPLORE-01     | apps/vhunambi_api/src/modules/media/         | phase84_media_id3_and_presign.test.ts:           |
|                        |   etag.ts, cursor.ts                         |  - GET /api/explore/tracks returns ETag & 304    |
|                        | apps/vhunambi_api/src/routes/                |  - keyset cursor paginates & ignores bad cursors |
|                        |   explore_routes.ts                          |                                                  |
+------------------------+----------------------------------------------+--------------------------------------------------+
| REQ-P84-ZANIA-01       | tools/zania-ingest/ingest_zania_catalog.mjs  | CLI --dry-run against ZANIA MUSIC (189 MP3s)     |
|                        | supabase/migrations/20261125000001_*.sql     | + unit test for folder-to-genre & SHA-256 dedupe |
+========================+==============================================+==================================================+
```
