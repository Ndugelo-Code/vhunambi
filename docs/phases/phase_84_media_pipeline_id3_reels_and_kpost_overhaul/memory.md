```json vhunambi-memory
{
  "phase_id": "P84",
  "memory_key": "MEM-P84-MEDIA-PIPELINE-ID3-REELS-AND-KPOST",
  "title": "Media Pipeline Overhaul: Direct-to-R2 Presigned Uploads, Edge ID3v2 Cover/Metadata Extraction, Kinetic Reels 98% Fix, Kinetic Post Uploads & Zania Music Flywheel",
  "status": "completed",
  "completed_at": "2026-11-25T12:31:00+02:00",
  "predecessor_keys": [
    "MEM-P79-SOVEREIGN-MEDIA-UPLOAD-ENGINE",
    "MEM-P83-POSTGEN-STEM-REPAINT-AND-LORA-STUDIO"
  ],
  "concept_hubs": [
    "media_artwork",
    "audio_transport",
    "social_graph",
    "sync_outbox",
    "ui_surface_std"
  ],
  "consumes": [
    "EP-P79-USER-MEDIA-REGISTRY-API",
    "EP-P79-MEDIA-UPLOAD-ENGINE",
    "EP-P78-REAL-AUDIO-VIDEO-INGEST",
    "EP-P74-REELS-STUDIO-PIPELINE",
    "EP-P69-KPOST-FOCUS-ROUTE",
    "EP-P68-TRACK-ARTWORK"
  ],
  "endpoints": [
    {
      "id": "EP-P84-R2-PRESIGN-DIRECT",
      "kind": "backend_api",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["media_artwork", "sync_outbox"],
      "spec_anchor": "docs/phases/phase_84_media_pipeline_id3_reels_and_kpost_overhaul/design.md#32-presign-finalize--id3-extraction-in-appsvhunambi_apisrcroutesmedia_routests",
      "code_anchor": "apps/vhunambi_api/src/routes/media_routes.ts",
      "summary": "POST /api/media/presign-put and POST /api/media/finalize enabling <=100MB direct-to-R2 SigV4 PUT streaming with SHA-256 deduplication, bounded Worker RAM (<=2MiB), and replay-safe 401 Flutter upload execution.",
      "consumers": ["P84:HttpMediaUploadRepository", "P84:ingest_zania_catalog.mjs"],
      "open_opportunities": "Reuse direct-to-R2 presigned PUT + SHA-256 dedupe inside Phase 85 Cloud LoRA raw training dataset ingestion"
    },
    {
      "id": "EP-P84-EDGE-ID3-EXTRACTOR",
      "kind": "backend_media_parser",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["media_artwork", "audio_transport"],
      "spec_anchor": "docs/phases/phase_84_media_pipeline_id3_reels_and_kpost_overhaul/design.md#21-appsvhunambi_apisrcmodulesmediaid3v2_parserts-new",
      "code_anchor": "apps/vhunambi_api/src/modules/media/id3v2_parser.ts",
      "summary": "Pure edge Uint8Array ID3v2.3/v2.4 extractor decoding APIC cover art (JPEG/PNG/WebP + image/jpg alias) and TIT2/TPE1/TALB/TCON/TBPM/USLT frames via bounded R2 byte-range reads and persisting covers to R2 covers/.",
      "consumers": ["P84:media_routes.ts", "P84:UploadsVaultView"],
      "open_opportunities": "Feed extracted ID3v2 USLT lyrics, TBPM, and TCON tags directly into Phase 85 cloud dataset metadata sidecars"
    },
    {
      "id": "EP-P84-KPOST-MEDIA-UPLOAD",
      "kind": "client_ui_and_repo",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["social_graph", "media_artwork", "ui_surface_std"],
      "spec_anchor": "docs/phases/phase_84_media_pipeline_id3_reels_and_kpost_overhaul/design.md#51-createkineticpostsheet-upgrades-req-p84-kpost-0103",
      "code_anchor": "apps/vhunambi_client/lib/features/explore/presentation/widgets/create_kinetic_post_sheet.dart",
      "summary": "Upgrades CreateKineticPostSheet to default to My Uploads, add direct Audio & Photo cloud upload CTAs, purge mock _grooveSeeds and bundled Vision AI fallbacks, await Supabase upsertKineticPostAsync, and hydrate media in refreshFromCloud().",
      "consumers": ["P84:CreateKineticPostSheet", "P84:SocialFeedPostsNotifier"],
      "open_opportunities": "Extend CreateKineticPostSheet audio upload flow to allow direct 1-tap stem remix posting from UploadsVaultView"
    },
    {
      "id": "EP-P84-EXPLORE-CURSOR-ETAG",
      "kind": "backend_api_pagination",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["social_graph", "sync_outbox"],
      "spec_anchor": "docs/phases/phase_84_media_pipeline_id3_reels_and_kpost_overhaul/design.md#22-appsvhunambi_apisrcmodulesmediaetagts--cursort-new",
      "code_anchor": "apps/vhunambi_api/src/routes/explore_routes.ts",
      "summary": "Pure edge base64url keyset pagination (?cursor=) and weak FNV-1a ETag / If-None-Match 304 Not Modified caching on GET /api/explore/tracks.",
      "consumers": ["P84:explore_routes.ts"],
      "open_opportunities": "Adopt identical keyset cursor + FNV-1a ETag caching on GET /api/social/feed and GET /api/media/uploads"
    },
    {
      "id": "EP-P84-ZANIA-CATALOG-INGEST",
      "kind": "cli_and_r2_bridge",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["media_artwork", "audio_transport", "sync_outbox"],
      "spec_anchor": "docs/phases/phase_84_media_pipeline_id3_reels_and_kpost_overhaul/design.md#6-zero-local-ram-zania-music-bulk-ingest-cli-toolszania-ingestingest_zania_catalogmjs",
      "code_anchor": "tools/zania-ingest/ingest_zania_catalog.mjs",
      "summary": "Zero-dependency Node 24 streaming CLI ingesting local ZANIA MUSIC MP3s, sibling covers, and lyrics into R2 zr-studio-audio and Supabase explore_tracks with SHA-256 deduplication and <150MB RAM usage.",
      "consumers": ["P84:ingest_zania_catalog.mjs"],
      "open_opportunities": "Reuse manifest output directly as the input seed list for Phase 85 RunPod cloud LoRA dataset preparation"
    }
  ],
  "edges": [
    {
      "from": "apps/vhunambi_client/lib/features/media/data/repositories/http_media_upload_repository.dart",
      "relation": "CONSUMES",
      "to": "EP-P84-R2-PRESIGN-DIRECT",
      "note": "Streams raw media bytes via presign-put -> direct R2 PUT -> finalize, eliminating finalized FormData 401 replay crashes"
    },
    {
      "from": "apps/vhunambi_api/src/routes/media_routes.ts",
      "relation": "CONSUMES",
      "to": "EP-P84-EDGE-ID3-EXTRACTOR",
      "note": "Extracts embedded APIC covers and TIT2/TPE1/TCON/TBPM/USLT metadata during /api/media/finalize and /api/media/upload"
    },
    {
      "from": "tools/zania-ingest/ingest_zania_catalog.mjs",
      "relation": "CONSUMES",
      "to": "EP-P84-R2-PRESIGN-DIRECT",
      "note": "Deduplicates and streams 189 local ZANIA MUSIC MP3s into Vhunambi R2 and Explore catalog"
    }
  ],
  "breakthroughs": [
    "Applied additive migration 20261125000001_phase84_media_id3_and_zania_ingest.sql to live Supabase project cbnruevwrqwjnnoscgsz with zero RLS advisor regressions.",
    "Implemented pure edge ID3v2.3/v2.4 extractor (APIC, TIT2, TPE1, TALB, TCON, TBPM, USLT, NFC UTF-16LE/BE), FNV-1a ETag/304, keyset cursor, /api/media/presign-put + /api/media/finalize, and awaited Supabase write-through across EdgeIsolateDatabaseEngine and VhunambiDatabase (37/37 API test suites green).",
    "Deployed live Cloudflare Worker vhunambi-api at https://vhunambi-api.ndugelosigwadi.workers.dev (Version 377ef962-93ab-446d-a1de-5c0bd8f682c2, /health 200 OK).",
    "Eliminated the Kinetic Reels 98% FormData 401 replay crash, removed duplicate audio re-uploads, raised /api/social/publish timeout to 20s, and wired direct audio/photo uploads + cloud hydration into CreateKineticPostSheet (dart analyze 0 issues; 30/30 Flutter Phase 84/79/77/73 tests green; 0 STD-UIUX-001 hits).",
    "Verified zero-dependency Node streaming CLI (tools/zania-ingest/ingest_zania_catalog.mjs --dry-run) across 188 READY MP3s (48 sibling covers, 20 sibling lyrics, 0 errors)."
  ],
  "gotchas": [
    "Never replay a consumed Dio FormData on 401 refresh in sovereign_api_client.dart (causes REEL98-01 crash at 98% progress).",
    "Donor id3v2-parser.ts returned null whenever data.length < 10 + tagSize; always use readId3TagByteLength + bounded <=2MiB extension and clamp loop end to Math.min(data.length, tagByteLength).",
    "Always normalize APIC MIME 'image/jpg' to 'image/jpeg' and verify magic bytes because Suno/FFmpeg encoders frequently emit 'image/jpg'.",
    "POST /api/explore/posts and POST /api/explore/tracks MUST await awaitWriteThrough (upsertKineticPostAsync / upsertExploreTrackAsync) so Cloudflare Workers never drop Supabase writes on request exit."
  ]
}
```

# Phase 84 Session Memory (Completed — Stage 4 Verified & Deployed)

> **Status:** `completed` (`completed_at: 2026-11-25T12:31:00+02:00`). All milestones `M1..M6` implemented and verified against `tsc --noEmit`, `npm test` (37 suites), `dart analyze` (0 issues), `flutter test` (`phase84`, `phase73`, `phase77`, `phase79` — 30/30 passed), `STD-UIUX-001` check (`0` hits), `ingest_zania_catalog.mjs --dry-run` (188 MP3s scanned), live Supabase migration `20261125000001_phase84_media_id3_and_zania_ingest.sql`, and live Cloudflare Worker deploy (`377ef962-93ab-446d-a1de-5c0bd8f682c2`).
