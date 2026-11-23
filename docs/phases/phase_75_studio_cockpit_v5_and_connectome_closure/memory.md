```json vhunambi-memory
{
  "phase_id": "P75",
  "memory_key": "MEM-P75-STUDIO-COCKPIT-V5-CONNECTOME-CLOSURE",
  "title": "Studio Cockpit V5, 100% Connectome Closure (EP-P66/P27/P26/P25), Worker Voice/Mastering SWR & Direct-to-Reels Bridge",
  "status": "completed",
  "completed_at": "2026-11-22T00:48:23Z",
  "predecessor_keys": [
    "MEM-P70-SONG-COCKPIT-VISITOR-PROFILE",
    "MEM-P71-CLOUD-SPINE-CONNECTOME-CLOSURE",
    "MEM-P72-ASSET-VAULT-OWNER-PROFILE-GLASS",
    "MEM-P73-KPOST-CHROMATIC-REACTIONS-HYGIENE",
    "MEM-P74-KINETIC-REELS-STUDIO-V4"
  ],
  "concept_hubs": [
    "ai_synthesis_gpu",
    "audio_transport",
    "identity_role",
    "mood_taxonomy",
    "sync_outbox",
    "ui_surface_std",
    "social_graph"
  ],
  "consumes": [
    "EP-P66-LYRICS-REFINE-STORY",
    "EP-P27-MELODY-PRESETS-PACKS",
    "EP-P26-VOICE-CALIBRATION-RECIPE",
    "EP-P25-GEN-MASTER-PRESETS",
    "EP-P74-REELS-STUDIO-PIPELINE",
    "EP-P74-KARAOKE-LYRIC-SANITIZER",
    "EP-P71-EDGE-SWR-READTHROUGH",
    "EP-P70-GLASS-SURFACE"
  ],
  "endpoints": [
    {
      "id": "EP-P75-VOICES-CLOUD-SWR",
      "kind": "backend_persistence",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["sync_outbox", "ai_synthesis_gpu", "identity_role"],
      "spec_anchor": "docs/phases/phase_75_studio_cockpit_v5_and_connectome_closure/design.md#22-appsvhunambi_apisrcdbedge_persistence_bridgets--appsvhunambi_apisrcdbvhunambi_dbts-11-parity",
      "code_anchor": "apps/vhunambi_api/src/db/edge_persistence_bridge.ts",
      "summary": "12-second domain-scoped SWR read-through (syncVoicesFromCloud) and awaited write-through across voice_clones and sound_signatures, plus cross-isolate SWR hydration on POST /v1/generations/:id/master achieving 100% Worker route isolation.",
      "consumers": [
        "P75:voice_routes",
        "P75:generation_routes",
        "P75:server_scoped_bypass"
      ],
      "open_opportunities": "Reuse syncVoicesFromCloud to hydrate creator voice clone roster on OwnerProfileView and cross-device Studio sign-in"
    },
    {
      "id": "EP-P75-STUDIO-CONNECTOME-CLIENTS",
      "kind": "client_repository_and_state",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["ai_synthesis_gpu", "audio_transport", "mood_taxonomy", "identity_role"],
      "spec_anchor": "docs/phases/phase_75_studio_cockpit_v5_and_connectome_closure/design.md#3-pass-1-m752--client-connectome-closure-engines-appsvhunambi_client",
      "code_anchor": "apps/vhunambi_client/lib/features/studio/data/services/http_lyrics_generation_service.dart",
      "summary": "Client HTTP wiring closing all 4 final OPEN endpoints: Lyrics refine & story-transform, Sketchpad cloud presets & R2 sound packs, Voice calibration & Sound Signature PATCH recipe sync, and Server Mastering presets + Track MMO manifest stem hydration.",
      "consumers": [
        "P75:LyricsReviewModal",
        "P75:MelodySketchpadNotifier",
        "P75:SoundPackManagerNotifier",
        "P75:CrossModuleSynergyDeck",
        "P75:MasteringSessionNotifier",
        "P75:TrackDetailNotifier"
      ],
      "open_opportunities": "Expose offline-cached MMO 4-stem waveform peaks from /v1/generations/:id/manifest inside TrackSonicTelemetryCard and ExpandedCockpitModal"
    },
    {
      "id": "EP-P75-CREATION-TO-REELS-BRIDGE",
      "kind": "ui_flow_and_state",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["social_graph", "audio_transport", "ui_surface_std"],
      "spec_anchor": "docs/phases/phase_75_studio_cockpit_v5_and_connectome_closure/design.md#41-direct-creation-to-viral-bridge-ep-p74-reels-studio-pipeline",
      "code_anchor": "apps/vhunambi_client/lib/features/studio/presentation/widgets/generation_pipeline_card.dart",
      "summary": "Unified 1-tap launch into Phase 74 full-screen KineticReelStudioView.show(context, initialTrack: ...) from Studio generation completion, TrackDetailView, TrackActionsSheet, and ExpandedCockpitModal, paired with LyricKaraokeSanitizer teleprompter sanitization.",
      "consumers": [
        "P75:GenerationPipelineCard",
        "P75:TrackDetailView",
        "P75:TrackActionsSheet",
        "P75:ExpandedCockpitModal"
      ],
      "open_opportunities": "Add post-bake 'Drop Mastered Track as Reel' CTA inside DesktopMasteringStudioView and MobileQuickMasterSheet"
    }
  ],
  "edges": [
    {
      "from": "apps/vhunambi_client/lib/features/studio/data/services/http_lyrics_generation_service.dart",
      "relation": "CONSUMES",
      "to": "EP-P66-LYRICS-REFINE-STORY",
      "note": "Wires POST /v1/lyrics/refine (rawLyrics) and POST /v1/lyrics/story-transform (structuredLyrics)"
    },
    {
      "from": "apps/vhunambi_client/lib/features/studio/presentation/providers/sound_pack_manager_provider.dart",
      "relation": "CONSUMES",
      "to": "EP-P27-MELODY-PRESETS-PACKS",
      "note": "Hydrates Sound Packs from GET /v1/melodies/sound-packs and downloads R2 pack bundles"
    },
    {
      "from": "apps/vhunambi_client/lib/features/sound_signature/data/sound_signature_repository.dart",
      "relation": "CONSUMES",
      "to": "EP-P26-VOICE-CALIBRATION-RECIPE",
      "note": "Persists idealizer recipe edits via PATCH /v1/voices/signatures/:id/recipe"
    },
    {
      "from": "apps/vhunambi_client/lib/features/track/presentation/providers/track_providers.dart",
      "relation": "CONSUMES",
      "to": "EP-P25-GEN-MASTER-PRESETS",
      "note": "Hydrates real R2 4-stem URLs from GET /v1/generations/:id/manifest in separateStems()"
    },
    {
      "from": "apps/vhunambi_client/lib/features/studio/presentation/widgets/generation_pipeline_card.dart",
      "relation": "ROUTES_TO",
      "to": "EP-P74-REELS-STUDIO-PIPELINE",
      "note": "Direct 1-tap handoff from Studio generation completion into KineticReelStudioView"
    }
  ],
  "breakthroughs": [
    "Stage 4 verification closed all 4 remaining OPEN Connectome endpoints (EP-P66, EP-P27, EP-P26, EP-P25) with 100% Worker route isolation (syncVoicesFromCloud 12s SWR, POST /v1/generations/:id/master cross-isolate lookup, /v1/voices|/melodies|/lyrics scoped bypass), zero stock Icons.*, and zero raw Unicode emojis across studio/ and mastering/.",
    "Full verification gates passed: apps/vhunambi_api tsc --noEmit + 31/31 test suites; apps/vhunambi_client dart analyze (0 issues across 8 feature modules + Phase 75 suite) and 372/372 Flutter tests (--timeout=60s)."
  ],
  "gotchas": [
    "POST /v1/lyrics/story-transform strictly validates 2-letter ISO baseLanguage codes and 6 lowercase STORY_GENRES; Flutter display strings like 'Tshivenḓa' or 'Afro House' must be normalized before posting.",
    "StudioSoundPackEntity.fromJson originally threw Null-to-String cast errors on backend payloads using name/description instead of title/subtitle; JsonSafe field fallbacks are required.",
    "TrackDetailNotifier.loadManifestFromCloud bare relative stem keys (e.g. stems/<id>_vocals.wav without leading / or scheme) must be prefixed with resolveMediaBaseUrl(overrideOrigin: origin).",
    "VhunambiGlassSurface exposes tintAccent and borderColorOverride (not tintColor or borderColor); ILyricsGenerationService test doubles like _ThrowingLyricsService must implement refineLyrics and transformStoryToLyrics."
  ]
}
```

# Phase 75 Session Memory & Breakthroughs (Completed)

## 1. Core Architectural Scope
- Closes the final `4` `OPEN` Connectome endpoints (`EP-P66-LYRICS-REFINE-STORY`, `EP-P27-MELODY-PRESETS-PACKS`, `EP-P26-VOICE-CALIBRATION-RECIPE`, `EP-P25-GEN-MASTER-PRESETS`), bringing monorepo `OPEN` endpoints to **`0`**.
- Completes **100% Cloudflare Worker route isolation** (`syncVoicesFromCloud` 12s SWR, `POST /v1/generations/:id/master` cross-isolate SWR, `/v1/voices`, `/v1/melodies`, `/v1/lyrics` added to `hasScopedReadThrough`).
- Connects Studio, Track Detail, Asset Vault, and Full-Screen Player directly into Phase 74's `KineticReelStudioView.show(context, initialTrack: ...)` and purges `STD-UIUX-001` icon/emoji debt across Studio and Mastering.

## 2. Verified Traps Guarded Before Stage 4
- `story_transform.ts#L306` returns `structuredLyrics`, not `rawLyrics`.
- `generation_routes.ts#L374-425` (`POST /:id/master`) lacked `syncGenerationJobFromCloud(id, c)`, causing cross-isolate 404s that triggered `/mock-storage/` masking in `mastering_session_provider.dart#L486-515`.
- `track_notifier_test.dart#L171-195` requires canonical stem IDs (`'${trackId}_vocals'`) and labels (`['Vocals', 'Drums', 'Bass & Log Drums', 'Instrumental']`).
