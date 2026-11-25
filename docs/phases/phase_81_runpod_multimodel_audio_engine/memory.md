```json vhunambi-memory
{
  "phase_id": "P81",
  "memory_key": "MEM-P81-RUNPOD-MULTIMODEL-AUDIO-ENGINE",
  "title": "RunPod Multi-Model Synthesis Router (MiniMax Music 3.0 + ACE-Step 1.5 XL) & Multi-Take A&R Baking",
  "status": "completed",
  "completed_at": "2026-11-24T19:18:00+02:00",
  "predecessor_keys": [
    "MEM-P64-PRODUCTION-PIPELINE-LORA-GPU",
    "MEM-P66-STUDIO-WIRING-BANTU-GUARD-LUFS",
    "MEM-P79-SOVEREIGN-MEDIA-UPLOAD-ENGINE",
    "MEM-P80-STUDIO-COCKPIT-V6-PRODUCTION-CONTRACT"
  ],
  "concept_hubs": [
    "ai_synthesis_gpu",
    "audio_transport",
    "mood_taxonomy",
    "quota_economy",
    "sync_outbox",
    "notifications_bus",
    "ui_surface_std"
  ],
  "consumes": [
    "EP-P67-NOTIF-API",
    "EP-P79-MEDIA-UPLOAD-ENGINE",
    "EP-P80-GENERATION-CONTRACT-V6",
    "EP-P80-STUDIO-COCKPIT-V6"
  ],
  "endpoints": [
    {
      "id": "EP-P81-RUNPOD-MULTIMODEL-ROUTER",
      "kind": "gpu_worker_router",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["ai_synthesis_gpu", "mood_taxonomy", "audio_transport"],
      "spec_anchor": "docs/phases/phase_81_runpod_multimodel_audio_engine/design.md#21-complete-new-module-toolszr-studio-gpumodel_routerpy",
      "code_anchor": "tools/zr-studio-gpu/model_router.py",
      "summary": "ZRMultiModelRouter co-hosting MiniMaxAI/MiniMax-Music3 (vocal Studio Bake, <=300s sweet spot / 360s cap, MiniMax-Music3 attribution, 32kHz->44.1kHz polyphase upsample) and ACE-Step 1.5 XL ({turbo,sft,base} + R2 LoRAs, instrumental/ref-audio HTTP 400 shield, Latin Bantu guard, strict YuE2 ban) configured on RunPod zr-studio-prod v8 (L40S/A6000 48GB+ pools, 40GB disk, 1200s timeout).",
      "consumers": ["P81:handler.py", "P81:runpod_adapter.ts", "P81:model_utils.py"],
      "open_opportunities": "Feed Phase 82 BS-RoFormer clean vocal isolation, neural Seed-VC conversion, and Matchering 2.0 SA reference mastering directly from normalized 44.1kHz winning take"
    },
    {
      "id": "EP-P81-MULTITAKE-AR-SCORER",
      "kind": "gpu_dsp_and_client_switcher",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["ai_synthesis_gpu", "audio_transport", "ui_surface_std"],
      "spec_anchor": "docs/phases/phase_81_runpod_multimodel_audio_engine/blueprint.md#61-composite-ar-candidate-quality-score-q_texttake-in-0-1",
      "code_anchor": "tools/zr-studio-gpu/handler.py",
      "summary": "Per-take unique non-zero 64-bit seeding, mathematical A&R candidate quality scoring (active ratio, crest factor pocket, vocal presence, anti-clipping), audio/{job_id}/take_{i}.mp3 R2 uploads, and 44dp scored GenerationPipelineCard take pills with LibraryTrack Vault promotion.",
      "consumers": ["P81:GenerationPipelineCard", "P81:GenerationPipelineNotifier", "P81:HttpGenerationSubmissionService"],
      "open_opportunities": "Surface alternate takes inside Phase 83 Post-Generation Track/Remix Cockpit for A/B section splice and bar-range repaint"
    },
    {
      "id": "EP-P81-EDGE-WEBHOOK-SYNC",
      "kind": "backend_webhook_and_do_bridge",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["sync_outbox", "ai_synthesis_gpu", "notifications_bus"],
      "spec_anchor": "docs/phases/phase_81_runpod_multimodel_audio_engine/design.md#14-edge-isolate-webhook-progress-sync-webhook_routests--do-stage-mapping-generation_session_dots",
      "code_anchor": "apps/vhunambi_api/src/routes/webhook_routes.ts",
      "summary": "Guarded waitUntil Supabase progress persistence on intermediate RunPod webhooks with cold-isolate hydration, multi-take /status/:id active polling parity, and complete GenerationSessionDO stepIndex mapping for planning_lyrics and converting_vocals.",
      "consumers": ["P81:generation_routes.ts", "P81:GenerationSessionDO", "P81:runpod_adapter.ts"],
      "open_opportunities": "Extend stage webhook telemetry in Phase 82 with measured LUFS / Seed-VC similarity metrics"
    }
  ],
  "edges": [
    {
      "from": "tools/zr-studio-gpu/handler.py",
      "relation": "CONSUMES",
      "to": "EP-P80-GENERATION-CONTRACT-V6",
      "note": "Executes engine_tier, resolved_engine, is_instrumental, batch_count, take_seeds, rich_prompt, and voice_cast end-to-end on RunPod GPU"
    },
    {
      "from": "apps/vhunambi_client/lib/features/studio/presentation/widgets/generation_pipeline_card.dart",
      "relation": "CONSUMES",
      "to": "EP-P81-MULTITAKE-AR-SCORER",
      "note": "Renders >=44dp take switcher pills with A&R quality score badges and promotes selected take into LibraryVault"
    },
    {
      "from": "apps/vhunambi_api/src/routes/webhook_routes.ts",
      "relation": "PROVIDES",
      "to": "EP-P81-EDGE-WEBHOOK-SYNC",
      "note": "Hydrates cold Worker isolates and persists intermediate planning_lyrics->uploading progress via guarded waitUntil"
    }
  ],
  "breakthroughs": [
    "Deployed Worker multi-model wire & DO sync (Version 86c1a475-d1dd-4ece-b11e-489ad9bd2991, 34/34 backend test suites passing) and built tools/zr-studio-gpu/model_router.py + multi-take A&R handler.py (7/7 offline Python tests passing in 17.3s).",
    "Upgraded live RunPod zr-studio-prod (e7wt9pgo7djv55, v8) to 40GB container disk, 1200000ms (20m) execution timeout, and 48GB+ VRAM pools (ADA_48_PRO, AMPERE_48, AMPERE_80) and updated GitHub Actions workflow push_gpu_worker.yml for zero-local-data :vhunambi-v4 builds.",
    "Flutter multi-take A&R UI (44dp take pills, score badges, LibraryTrack Vault promotion on selectActiveTake) passed 11/11 Phase 80/81 studio widget tests at 360x800 Light & Dark modes."
  ],
  "gotchas": [
    "Phase 66 regression test (phase66_audio_prompt_hygiene.test.ts) asserts that sanitizeLyricsForAceStep strips '[Log drum drop: ...]'; keep [log drum drop] stripped in ALLOWED_SECTION for ACE-Step and preserve [Log Drum Drop] exclusively via ALLOWED_MINIMAX_SECTION inside formatLyricsForEngine(..., 'minimax_music_3').",
    "Importing torch cold on CPU-only Windows hosts adds >50s latency even when acestep is absent; guard ZRModelManager._try_load_ace_step_pipeline with importlib.util.find_spec('acestep') and guard _offload_cuda_caches with 'torch' in sys.modules.",
    "RunPod update-endpoint replaces the full env map when env is passed and overwrites [redacted] secrets with literal '[redacted]'; omit env when patching GPU pools, disk, and timeout unless resupplying real secrets."
  ]
}
```

# Phase 81 Session Memory (Stage 4 Complete)

> **Status:** `completed` (`2026-11-24T19:18:00+02:00`). Worker `vhunambi-api` deployed live (`86c1a475`), RunPod `zr-studio-prod` upgraded to v8 (`48GB+` pools, `40GB` disk, `1200s` timeout), and all Python/Worker/Flutter verification suites passed. Remaining cloud ops: `git push` to trigger GitHub Actions `:vhunambi-v4` build and provision/attach the `100 GB` `/runpod-volume` (`$7/mo` out of `$13.57` balance) once ready for live GPU weights.
