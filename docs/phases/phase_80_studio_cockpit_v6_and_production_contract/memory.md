```json vhunambi-memory
{
  "phase_id": "P80",
  "memory_key": "MEM-P80-STUDIO-COCKPIT-V6-PRODUCTION-CONTRACT",
  "title": "Studio Cockpit V6 Glass Overhaul, vhunambi.com Production Parity & StudioGenerationContractV6 Multi-Take Backend",
  "status": "completed",
  "completed_at": "2026-11-24T14:09:00+02:00",
  "predecessor_keys": [
    "MEM-P65-FOUNDATION-CRASH-IMMUNITY",
    "MEM-P70-SONG-COCKPIT-VISITOR-PROFILE",
    "MEM-P75-STUDIO-COCKPIT-V5-CONNECTOME-CLOSURE",
    "MEM-P78-VAULT-EXPLORE-CONTINUITY-UPLOADS-GLASS-TABS",
    "MEM-P79-SOVEREIGN-MEDIA-UPLOAD-ENGINE"
  ],
  "concept_hubs": [
    "ai_synthesis_gpu",
    "audio_transport",
    "mood_taxonomy",
    "ui_surface_std",
    "media_artwork",
    "quota_economy",
    "notifications_bus",
    "sync_outbox"
  ],
  "consumes": [
    "EP-P65-CRASH-AUDIO-SHIELD",
    "EP-P67-QUOTA-API",
    "EP-P67-NOTIF-API",
    "EP-P70-GLASS-SURFACE",
    "EP-P71-EDGE-SWR-READTHROUGH",
    "EP-P75-VOICES-CLOUD-SWR",
    "EP-P75-STUDIO-CONNECTOME-CLIENTS",
    "EP-P75-CREATION-TO-REELS-BRIDGE",
    "EP-P78-GLASS-TAB-BAR",
    "EP-P79-MEDIA-UPLOAD-ENGINE",
    "EP-P79-USER-MEDIA-REGISTRY-API"
  ],
  "endpoints": [
    {
      "id": "EP-P80-GENERATION-CONTRACT-V6",
      "kind": "backend_api_and_schema",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["ai_synthesis_gpu", "sync_outbox", "notifications_bus", "quota_economy"],
      "spec_anchor": "docs/phases/phase_80_studio_cockpit_v6_and_production_contract/design.md#1-pass-1-m801--backend-studiogenerationcontractv6-multi-take-schema--ai-assist-apis",
      "code_anchor": "apps/vhunambi_api/src/routes/generation_routes.ts",
      "summary": "Lossless StudioGenerationContractV6 across POST /v1/generations, prompt_compiler.ts (deterministic MiniMax 3.0 vs ACE-Step 1.5 XL routing, >48c prompt preservation, [Voice A]/[Voice B] duet tags, unique 64-bit takeSeeds), public.generation_jobs multi-take migration (batch_id + takes_json + initplan-clean RLS), true creatorId retention, and deferred Ready notifications.",
      "consumers": [
        "P80:HttpGenerationSubmissionService",
        "P80:GenerationPipelineNotifier",
        "P80:webhook_routes.ts"
      ],
      "open_opportunities": "Consume resolvedEngine, takeSeeds, audio_mode, voice_cast, and rich_prompt directly inside Phase 81 RunPod L40S 48GB multi-model handler.py and Phase 82 BS-RoFormer + Seed-VC + Matchering 2.0 chain"
    },
    {
      "id": "EP-P80-STUDIO-AI-ASSIST-API",
      "kind": "backend_api",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["ai_synthesis_gpu", "mood_taxonomy", "media_artwork"],
      "spec_anchor": "docs/phases/phase_80_studio_cockpit_v6_and_production_contract/design.md#16-studio-ai-assist--photo-lyrics-routes-studio_routests--lyrics_routests",
      "code_anchor": "apps/vhunambi_api/src/routes/studio_routes.ts",
      "summary": "POST /v1/studio/improve-prompt (genre/mood/duet-aware prompt expansion), POST /v1/lyrics/from-photo (Phase 79 Vault image to structured lyrics), and duet-aware POST /v1/lyrics/generate ([Voice A]/[Voice B] scripts) with scoped Edge read-through bypass.",
      "consumers": [
        "P80:StudioAiAssistService",
        "P80:PromptInputBox",
        "P80:StudioLyricsAndBakeDeck"
      ],
      "open_opportunities": "Connect Phase 82/83 vision captioning models to POST /v1/lyrics/from-photo for pixel-level visual lyric grounding"
    },
    {
      "id": "EP-P80-STUDIO-COCKPIT-V6",
      "kind": "ui_surface",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["ui_surface_std", "audio_transport", "media_artwork", "ai_synthesis_gpu"],
      "spec_anchor": "docs/phases/phase_80_studio_cockpit_v6_and_production_contract/design.md#2-pass-1--pass-2-m802m804--flutter-studio-cockpit-v6-glass-overhaul--vhunambicom-parity",
      "code_anchor": "apps/vhunambi_client/lib/features/studio/presentation/views/studio_view.dart",
      "summary": "Frosted-glass Studio Cockpit V6 using VhunambiGlassSurface + VhunambiGlassTabBar, zero pre-gen stem lock clutter (STU-02), zero 360dp truncation (STU-03), 42-genre 5-region catalog, Reference Audio + 4 Recreate Modes wired to VhunambiMediaVault, Instrumental/Length/3-Mode Lyrics/Title/Batch/Engine Tier, Multi-Voice Duet Casting, Cinematic 4-Stage Baking Monitor with MiniMax-Music3 attribution, and Past-Song Remix Shelf.",
      "consumers": [
        "P80:StudioView",
        "P80:BantuVoiceDeck",
        "P80:InlineCrateMpcWorkbench",
        "P80:GenerationPipelineCard"
      ],
      "open_opportunities": "Mount relocated CockpitQuantumEntanglementRack inside Phase 83 Post-Generation Track/Remix Studio wired to ACE-Step 1.5 XL-Base section repaint"
    }
  ],
  "edges": [
    {
      "from": "apps/vhunambi_client/lib/features/studio/presentation/widgets/reference_audio_dropzone.dart",
      "relation": "CONSUMES",
      "to": "EP-P79-MEDIA-UPLOAD-ENGINE",
      "note": "Stages uploaded reference audio and picks reusable audio from VhunambiMediaVault with SafeAudioOrchestrator preview"
    },
    {
      "from": "apps/vhunambi_client/lib/features/studio/presentation/views/studio_view.dart",
      "relation": "CONSUMES",
      "to": "EP-P78-GLASS-TAB-BAR",
      "note": "Replaces flat solid-orange Studio mode buttons and Crate/MPC sub-tabs with unified frosted VhunambiGlassTabBar"
    },
    {
      "from": "apps/vhunambi_client/lib/features/studio/data/services/http_generation_submission_service.dart",
      "relation": "CONSUMES",
      "to": "EP-P80-GENERATION-CONTRACT-V6",
      "note": "Submits lossless StudioGenerationContractV6 DTO and polls up to 18 minutes for multi-take Studio Bakes"
    },
    {
      "from": "apps/vhunambi_client/lib/features/studio/presentation/widgets/prompt_input_box.dart",
      "relation": "CONSUMES",
      "to": "EP-P80-STUDIO-AI-ASSIST-API",
      "note": "Invokes POST /v1/studio/improve-prompt via StudioAiAssistService with offline deterministic fallback"
    }
  ],
  "breakthroughs": [
    "Draft spec established: lossless StudioGenerationContractV6, multi-take generation_jobs schema (batch_id + takes_json), MiniMax Music 3.0 serving guardrails (unique 64-bit seeds, instrumental -> ACE-Step XL-SFT auto-routing, MiniMax-Music3 attribution), and full Studio Cockpit V6 glass parity."
  ],
  "gotchas": [
    "Do NOT add new required or optional parameters to ILyricsGenerationService abstract methods because existing test doubles (e.g. _ThrowingLyricsService) implement ILyricsGenerationService directly; place improvePrompt, generateLyricsFromPhoto, and duet lyric generation on StudioAiAssistService instead.",
    "vhunambi_db.ts#updateGenerationJob previously called this.upsertGenerationJob(merged) without passing existing.creatorId, silently overwriting creator_id with 'creator_cern' on every job progress update; store creatorId directly on GenerationJob and forward it on every upsert/update.",
    "Removing CockpitQuantumEntanglementRack from pre-gen Compose (STU-02) requires updating Test #1 in test/features/studio/phase56_studio_cockpit_and_mobile_biome_overhaul_test.dart while keeping CockpitQuantumEntanglementRack intact for phase54 standalone test #4 and Phase 83 post-gen Remix.",
    "Supabase Performance Advisor 0003_auth_rls_initplan requires ((SELECT auth.jwt()) ->> 'creator_id') = creator_id on all public.generation_jobs RLS policies, and migration 20261124000002_phase80_generation_jobs_v6_multitake.sql must be applied to Supabase Cloud BEFORE deploying vhunambi-api.",
    "Route isInstrumental == true away from minimax_music_3 to ace_step_xl_sft so Phase 81 sglang-omni /v1/audio/speech never returns HTTP 400 on empty lyrics, and always generate unique non-zero 64-bit takeSeeds per take so sglang-omni seed=0 never produces identical batches.",
    "POST /v1/generations must upsert notif_gen_<generationId> initially as 'Studio Bake Queued' (not omit it) because phase67_notifications_quota.test.ts#L150 asserts ids.some(id => id.startsWith('notif_gen_')) immediately after POST, then upgrade notif_gen_<generationId> to unread 'Studio Track Ready' on completion.",
    "Keep StudioFormState default durationSeconds = 30 (studio_form_test.dart#L19 & studio_session_repository_test.dart#L64), preserve GenerationPipelineCard's 4 step titles + 2 CircularProgressIndicators + 4 AppIcons.check glyphs (generation_pipeline_card_test.dart#L115-L148), and preserve BantuVoiceDeck's 4 Sliders (bantu_voice_deck_test.dart#L29)."
  ]
}
```

# Phase 80 Session Memory (Completed — Stage 4 Verified & Consolidated)

> **Status:** `completed` (`completed_at: 2026-11-24T14:09:00+02:00`). Verified across backend TypeScript + 33 test suites, `STD-UIUX-001` (`TOTAL_ICONS=0`, `TOTAL_EMOJIS=0`), all 292 tests in `test/features/studio/`, and 30 cross-domain tests (`phase75`, `phase78`, `phase79`). Remaining operational step: apply `20261124000002_phase80_generation_jobs_v6_multitake.sql` to Supabase Cloud before deploying `vhunambi-api` to Cloudflare Workers.
