```json vhunambi-memory
{
  "phase_id": "P85.5",
  "memory_key": "MEM-P85-5-DOCKER-CLOUD-V5-AND-ANDROID-MEDIA-POLISH",
  "title": "Docker Build Cloud :vhunambi-v5 Pipeline, Cloud GPU Factory Skill & Branded Android MediaStyle Notification Polish",
  "status": "completed",
  "completed_at": "2026-11-25T18:20:00+02:00",
  "predecessor_keys": [
    "MEM-P85-CLOUD-LORA-FACTORY",
    "MEM-P83-POSTGEN-STEM-REPAINT-AND-LORA-STUDIO"
  ],
  "concept_hubs": [
    "ai_synthesis_gpu",
    "audio_transport",
    "media_artwork",
    "ui_surface_std"
  ],
  "consumes": [
    "EP-P85-CLOUD-DATASET-PREP",
    "EP-P85-PEFT-LORA-TRAINER",
    "EP-P85-LORA-REGISTRY-DB"
  ],
  "endpoints": [
    {
      "id": "EP-P85-5-DOCKER-BUILD-CLOUD",
      "kind": "cloud_gpu_release_pipeline",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["ai_synthesis_gpu"],
      "spec_anchor": ".agents/skills/vhunambi-cloud-gpu-factory/SKILL.md",
      "code_anchor": "tools/zr-studio-gpu/Dockerfile.delta",
      "summary": "Docker Build Cloud (cloud-ndugelo-vhunambi) remote linux/amd64 thin-delta build & push workflow publishing ndugelo/zr-studio-gpu:vhunambi-v5 (with onnxruntime-1.32.0 + /app/training/) to RunPod endpoint e7wt9pgo7djv55 release v10 with zero GitHub Actions billing and zero local 15 GB pull.",
      "consumers": ["P85.5:RunPod-e7wt9pgo7djv55", "P85.5:vhunambi-cloud-gpu-factory"],
      "open_opportunities": "Reuse cloud-ndugelo-vhunambi for :vhunambi-v6+ worker iterations and future MiniMax Music 3.0 / ACE-Step 1.5 XL image updates"
    },
    {
      "id": "EP-P85-5-ANDROID-MEDIA-NOTIF",
      "kind": "android_media_notification_and_duration_sync",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["audio_transport", "media_artwork", "ui_surface_std"],
      "spec_anchor": "docs/memory/sprints/P85_5_memory.md",
      "code_anchor": "apps/vhunambi_client/lib/features/player/data/services/vhunambi_audio_handler.dart",
      "summary": "Branded Android MediaStyle notification with monochrome Vhunambi vector icon (ic_stat_vhunambi.xml), 7 custom Phosphor vector drawables (ic_vh_*.xml) protected by res/raw/keep.xml, native-readable artUri temp caching for automatic chromatic colorization, live Favorite toggle replacing Stop, clean display metadata, and just_audio durationStream sync into PlayerState + MediaItem.duration.",
      "consumers": ["P85.5:PlayerNotifier", "P85.5:UploadsVaultView"],
      "open_opportunities": "Pair MediaStyle notification with a custom glassmorphic Android Home Screen AppWidget in a future polish sprint"
    }
  ],
  "edges": [
    {
      "from": "tools/zr-studio-gpu/Dockerfile.delta",
      "relation": "PROVIDES",
      "to": "EP-P85-5-DOCKER-BUILD-CLOUD",
      "note": "Builds ndugelo/zr-studio-gpu:vhunambi-v5 remotely on cloud-ndugelo-vhunambi with onnxruntime + Phase 85 training package"
    },
    {
      "from": "apps/vhunambi_client/lib/features/player/data/services/vhunambi_audio_handler.dart",
      "relation": "PROVIDES",
      "to": "EP-P85-5-ANDROID-MEDIA-NOTIF",
      "note": "Caches Flutter asset/local covers to file:// URIs, renders ic_stat_vhunambi + ic_vh_* controls, and syncs live stream duration"
    }
  ],
  "breakthroughs": [
    "Replaced blocked GitHub Actions GPU image builds with Docker Build Cloud (cloud-ndugelo-vhunambi) + Dockerfile.delta, shipping ndugelo/zr-studio-gpu:vhunambi-v5 (sha256:e80ff29e2295ed8388e0bcd51bb9fc8430be64d75a1b384054ed72c8b62309e7) to RunPod endpoint e7wt9pgo7djv55 release v10 in 12s build+push time with zero local base image pull.",
    "Codified Phase 81-85 Docker Build Cloud, RunPod Serverless/Pod ops, ACE-Step/MiniMax/BS-RoFormer/Seed-VC/Matchering guardrails, and R2/Supabase LoRA promotion into reusable workspace skill .agents/skills/vhunambi-cloud-gpu-factory/SKILL.md.",
    "Shipped Vhunambi branded Android MediaStyle notification (ic_stat_vhunambi.xml, 7 ic_vh_*.xml drawables, R8 res/raw/keep.xml, artUri temp cache, live Favorite action, durationStream sync), verified with dart analyze (0 issues), 171/171 player tests, and 45.1 MB arm64 release APK installed on Huawei device EPHUT20917014649."
  ],
  "gotchas": [
    "Docker Build Cloud requires creating the named cloud builder once in https://app.docker.com/build before docker buildx create --use --driver cloud ndugelo/<name> succeeds (otherwise returns 404 unknown builder).",
    "Android R8 resource shrinking (isShrinkResources = true) strips drawables referenced dynamically by string name in audio_service (ic_vh_*, ic_stat_vhunambi) unless preserved in android/app/src/main/res/raw/keep.xml.",
    "Android status-bar/notification small icons only read the alpha channel (solid-background PNG favicons become solid white squares); always use a pure-white transparent-background 24dp vector silhouette."
  ]
}
```

# Phase 85.5 Sprint Memory (Docker Build Cloud `:vhunambi-v5`, Cloud GPU Skill & Branded Android Notification)

- **Cloud GPU & LoRA Skill:** [`.agents/skills/vhunambi-cloud-gpu-factory/SKILL.md`](../../../.agents/skills/vhunambi-cloud-gpu-factory/SKILL.md) + [`references/models_and_lora_playbook.md`](../../../.agents/skills/vhunambi-cloud-gpu-factory/references/models_and_lora_playbook.md)
- **GPU Worker Delta & Docs:** [`tools/zr-studio-gpu/Dockerfile.delta`](../../../tools/zr-studio-gpu/Dockerfile.delta) (`ndugelo/zr-studio-gpu:vhunambi-v5`, RunPod `e7wt9pgo7djv55` release `v10`), [`tools/zr-studio-gpu/README.md`](../../../tools/zr-studio-gpu/README.md)
- **Android MediaStyle & Duration Sync:** [`vhunambi_audio_handler.dart`](../../../apps/vhunambi_client/lib/features/player/data/services/vhunambi_audio_handler.dart), [`player_state.dart`](../../../apps/vhunambi_client/lib/features/player/domain/models/player_state.dart), [`player_provider.dart`](../../../apps/vhunambi_client/lib/features/player/presentation/providers/player_provider.dart), [`uploads_vault_view.dart`](../../../apps/vhunambi_client/lib/features/library/presentation/views/uploads_vault_view.dart), [`keep.xml`](../../../apps/vhunambi_client/android/app/src/main/res/raw/keep.xml)
