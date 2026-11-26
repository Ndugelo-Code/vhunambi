```json vhunambi-memory
{
  "phase_id": "P85.6",
  "memory_key": "MEM-P85-6-NOTIFICATION-CRASH-AND-ZANIA-DISCOVERY",
  "title": "Android Notification Compact-Index Crash Hotfix & Zania Catalog Explore Search / Creator Directory",
  "status": "completed",
  "completed_at": "2026-11-26T07:55:00+02:00",
  "predecessor_keys": [
    "MEM-P85-5-DOCKER-CLOUD-V5-AND-ANDROID-MEDIA-POLISH",
    "MEM-P84-MEDIA-PIPELINE-ID3-REELS-AND-KPOST"
  ],
  "concept_hubs": [
    "audio_transport",
    "social_graph",
    "media_artwork"
  ],
  "consumes": [
    "EP-P85-5-ANDROID-MEDIA-NOTIF",
    "EP-P84-ZANIA-CATALOG-INGEST",
    "EP-P84-EXPLORE-CURSOR-ETAG"
  ],
  "endpoints": [
    {
      "id": "EP-P85-6-EXPLORE-CREATOR-DIRECTORY",
      "kind": "backend_api_and_client_search",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["social_graph", "media_artwork"],
      "spec_anchor": "docs/memory/sprints/P85_6_memory.md",
      "code_anchor": "apps/vhunambi_api/src/routes/explore_routes.ts",
      "summary": "GET /api/explore/creators (creators + track counts + top genres + search), creatorId/handle/sub-genre/description matching in GET /api/explore/tracks search, 500-row explore_tracks + creators hydration, Flutter ExploreCreatorsNotifier, cloud-merged ExploreSearchView, cursor-paged ExploreTracksNotifier.refreshFromCloud, and Track.creatorId matching in creatorCatalogTracksProvider.",
      "consumers": ["P85.6:ExploreSearchView", "P85.6:ExploreCreatorsNotifier", "P85.6:creatorCatalogTracksProvider"],
      "open_opportunities": "Add server-side creator follow counts and Zania creator banner/avatar assets to the directory payload"
    }
  ],
  "edges": [
    {
      "from": "apps/vhunambi_client/lib/features/explore/presentation/views/explore_search_view.dart",
      "relation": "CONSUMES",
      "to": "EP-P85-6-EXPLORE-CREATOR-DIRECTORY",
      "note": "Debounced cloud search merges remote tracks/creators with local cache"
    }
  ],
  "breakthroughs": [
    "Fixed the release-build tap-to-play crash (RemoteServiceException: Bad notification ... IndexOutOfBoundsException: Index: 3, Size: 3) by setting kAndroidCompactActionIndices to [0, 1, 2]; confirmed working on Huawei JNY-LX1 after installing the 45.1 MB arm64 release APK.",
    "Deployed vhunambi-api Version 06bcbc04-310c-4f73-b6fd-656d8f054c79; live GET /api/explore/tracks?search=zania returns total=186 and GET /api/explore/creators?search=zania returns creator_zania_catalog with trackCount=186.",
    "Root cause of Zania tracks missing from Explore search: client searched only a hardcoded 6-creator list plus a small cached track list, backend search ignored creatorId/handle, and EdgeIsolate cold-start hydrated only 200 explore_tracks."
  ],
  "gotchas": [
    "audio_service 0.18.19 AudioService.java builds notification compact view from nativeActions only (play/pause/prev/next); MediaControl.custom actions go to PlaybackStateCompat.CustomAction, so androidCompactActionIndices must index only the native actions (max index 2 for prev/play/next) or Android SystemUI crashes the app.",
    "On the 8 GB Windows dev host with the IDE open, `dart analyze`, `npm test` and combined `flutter test` runs hang for tens of minutes; run tsc via `node ./node_modules/typescript/bin/tsc -p tsconfig.json --noEmit`, run API tests individually via `node --import tsx test/<file>.test.ts`, and prefer building the APK directly over chained analyze/test commands.",
    "Supabase public.explore_tracks uses columns artist, creator_id, plays_count, likes_count, cosigns_count, discovery_stage; there is no public.tracks table, and public.creators has no email/name/creator_id columns (use id, handle, display_name).",
    "Register endpoint /api/auth/register requires handle, email and password."
  ]
}
```

# Phase 85.6 Sprint Memory (Notification Crash Hotfix & Zania Discovery)

- **Crash fix:** [`vhunambi_audio_handler.dart`](../../../apps/vhunambi_client/lib/features/player/data/services/vhunambi_audio_handler.dart) `kAndroidCompactActionIndices = [0, 1, 2]`, guarded by [`vhunambi_audio_handler_test.dart`](../../../apps/vhunambi_client/test/features/player/vhunambi_audio_handler_test.dart).
- **Backend:** [`explore_routes.ts`](../../../apps/vhunambi_api/src/routes/explore_routes.ts), [`edge_persistence_bridge.ts`](../../../apps/vhunambi_api/src/db/edge_persistence_bridge.ts), [`vhunambi_db.ts`](../../../apps/vhunambi_api/src/db/vhunambi_db.ts), [`phase84_media_id3_and_presign.test.ts`](../../../apps/vhunambi_api/test/phase84_media_id3_and_presign.test.ts).
- **Client:** [`track.dart`](../../../apps/vhunambi_client/lib/shared/models/track.dart), [`explore_models.dart`](../../../apps/vhunambi_client/lib/features/explore/domain/models/explore_models.dart), [`http_explore_repository.dart`](../../../apps/vhunambi_client/lib/features/explore/data/repositories/http_explore_repository.dart), [`explore_providers.dart`](../../../apps/vhunambi_client/lib/features/explore/presentation/providers/explore_providers.dart), [`explore_search_view.dart`](../../../apps/vhunambi_client/lib/features/explore/presentation/views/explore_search_view.dart), [`profile_providers.dart`](../../../apps/vhunambi_client/lib/features/profile/presentation/providers/profile_providers.dart).
- **Verification status:** API `tsc --noEmit` passed; Phase 84 and 85 API tests passed; live API probe confirmed; device test confirmed by user. Flutter `analyze`/`test` and full `npm test` hung and were cancelled, so they were not run to completion.
