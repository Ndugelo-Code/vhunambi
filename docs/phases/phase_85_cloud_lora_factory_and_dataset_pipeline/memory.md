```json vhunambi-memory
{
  "phase_id": "P85",
  "memory_key": "MEM-P85-CLOUD-LORA-FACTORY",
  "title": "Cloud-Only Zero-Local-RAM LoRA Factory: RunPod Dataset Prepper, Real ACE-Step 1.5 PEFT Trainer, Supabase LoRA Registry & Live Factory UI",
  "status": "completed",
  "completed_at": "2026-11-25T13:52:00+02:00",
  "predecessor_keys": [
    "MEM-P83-POSTGEN-STEM-REPAINT-AND-LORA-STUDIO",
    "MEM-P84-MEDIA-PIPELINE-ID3-REELS-AND-KPOST"
  ],
  "concept_hubs": [
    "ai_synthesis_gpu",
    "media_artwork",
    "audio_transport",
    "sync_outbox",
    "ui_surface_std"
  ],
  "consumes": [
    "EP-P83-SOVEREIGN-LORA-CATALOG",
    "EP-P82-BS-ROFORMER-SEED-VC",
    "EP-P84-R2-PRESIGN-DIRECT",
    "EP-P84-EDGE-ID3-EXTRACTOR",
    "EP-P84-ZANIA-CATALOG-INGEST"
  ],
  "endpoints": [
    {
      "id": "EP-P85-CLOUD-DATASET-PREP",
      "kind": "gpu_cloud_prep",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["ai_synthesis_gpu", "audio_transport", "media_artwork"],
      "spec_anchor": "docs/phases/phase_85_cloud_lora_factory_and_dataset_pipeline/design.md#42-cloud-runpod-dataset-prepper-toolszr-studio-trainingdataset_prep_workerpy",
      "code_anchor": "tools/zr-studio-training/dataset_prep_worker.py",
      "summary": "Cloud RunPod dataset preprocessor (job_type='lora_dataset_prep') converting R2 source MP3s into validated 44.1kHz 24-bit stereo WAV + JSON sidecars with optional BS-RoFormer vocal isolation, librosa BPM/key extraction, and validate_dataset.py gating.",
      "consumers": ["P85:handler.py", "P85:studio_routes.ts"],
      "open_opportunities": "Hook newly uploaded paid Suno / verified community creator tracks directly into automatic incremental dataset refresh batches"
    },
    {
      "id": "EP-P85-PEFT-LORA-TRAINER",
      "kind": "gpu_training_worker",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["ai_synthesis_gpu", "audio_transport"],
      "spec_anchor": "docs/phases/phase_85_cloud_lora_factory_and_dataset_pipeline/design.md#43-real-ace-step-15-bf16-peft-lora-trainer-toolszr-studio-trainingtrain_lorapy",
      "code_anchor": "tools/zr-studio-training/train_lora.py",
      "summary": "Real PyTorch bf16 PEFT ACE-Step DiT flow-matching LoRA trainer (zero mocks) with cached VAE latents, finite-tensor & SHA-256 verification, dual-format .safetensors + PEFT adapter_config export to R2 loras/, and dual-path auto-activation in model_utils.py:_hot_swap_loras().",
      "consumers": ["P85:handler.py", "P85:model_utils.py"],
      "open_opportunities": "Extend checkpoint resume and multi-pack scheduled retraining on dedicated RunPod spot GPUs as curated pack sizes pass 50+ tracks"
    },
    {
      "id": "EP-P85-LORA-REGISTRY-DB",
      "kind": "backend_api_and_schema",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["ai_synthesis_gpu", "sync_outbox"],
      "spec_anchor": "docs/phases/phase_85_cloud_lora_factory_and_dataset_pipeline/design.md#2-additive-supabase-postgresql-migration",
      "code_anchor": "apps/vhunambi_api/src/routes/studio_routes.ts",
      "summary": "Supabase lora_registry, lora_dataset_tracks, and lora_training_jobs schema + Worker orchestration routes (GET /v1/studio/loras/factory, POST /datasets/prep, POST /train, GET /jobs, POST /v1/webhooks/training) with 10+1 pack backward compatibility (bantu_vocals_v1).",
      "consumers": ["P85:StudioLoraRegistryNotifier", "P85:webhook_routes.ts"],
      "open_opportunities": "Attach Phase 86 RunPod balance guard and DO Idempotency-Key protection onto POST /v1/studio/loras/train"
    },
    {
      "id": "EP-P85-LORA-FACTORY-UI",
      "kind": "client_ui_and_provider",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["ui_surface_std", "ai_synthesis_gpu"],
      "spec_anchor": "docs/phases/phase_85_cloud_lora_factory_and_dataset_pipeline/design.md#5-flutter-studio-lora-registry--factory-ui",
      "code_anchor": "apps/vhunambi_client/lib/features/studio/presentation/widgets/lora_factory_status_sheet.dart",
      "summary": "StudioLoraRegistryNotifier + STD-UIUX-001 LoraFactoryStatusSheet surfacing live Active/Training/Ready/Untrained status pills, track readiness progress (e.g., 31/8 Amapiano), and 1-tap cloud Prep/Train triggers across Studio & Repaint sheets.",
      "consumers": ["P85:TrackSectionRepaintSheet"],
      "open_opportunities": "Surface creator royalty attribution badges on active community-contributed regional LoRA packs"
    }
  ],
  "edges": [
    {
      "from": "apps/vhunambi_api/src/routes/studio_routes.ts",
      "relation": "CONSUMES",
      "to": "EP-P83-SOVEREIGN-LORA-CATALOG",
      "note": "Enriches 10 genre packs + languagePacks[bantu_vocals_v1] with live Supabase lora_registry status while preserving totalCount===10"
    },
    {
      "from": "tools/zr-studio-training/dataset_prep_worker.py",
      "relation": "CONSUMES",
      "to": "EP-P82-BS-ROFORMER-SEED-VC",
      "note": "Reuses separate_lead_vocal_bs_roformer() to isolate clean Bantu vocal stems for bantu_vocals_v1 training datasets"
    },
    {
      "from": "tools/zr-studio-gpu/handler.py",
      "relation": "ROUTES_TO",
      "to": "EP-P85-PEFT-LORA-TRAINER",
      "note": "Dispatches job_type='lora_dataset_prep' and job_type='lora_train_peft' inside the Docker Build Cloud built :vhunambi-v5 GPU worker (RunPod e7wt9pgo7djv55 release v10)"
    }
  ],
  "breakthroughs": [
    "Applied additive migration 20261125000002_phase85_cloud_lora_factory.sql to live Supabase project cbnruevwrqwjnnoscgsz seeding all 11 canonical LoRA packs with zero RLS advisor regressions.",
    "Trained and reload-verified all 6/6 ready Sovereign African LoRA packs on an on-demand RunPod NVIDIA A40 Pod (amapiano_logdrum_v1, amapiano_private_school_v1, venda_malende_v1, afrohouse_ancestral_v1, afrobeats_lagos_v1, bantu_vocals_v1) on ACE-Step/ACE-Step-v1-3.5B, verified finite >64B .safetensors + SHA-256 in R2 zr-studio-audio/loras/, promoted all 6 to status='active' in live Supabase, and deleted the Pod ($0/hr idle).",
    "Adopted Docker Build Cloud (cloud-ndugelo-vhunambi) + tools/zr-studio-gpu/Dockerfile.delta (bypassing blocked GitHub Actions billing) to build and push ndugelo/zr-studio-gpu:vhunambi-v5 (sha256:e80ff29e2295ed8388e0bcd51bb9fc8430be64d75a1b384054ed72c8b62309e7) with onnxruntime-1.32.0, peft, safetensors, pyyaml, _ROFORMER_SEP_CACHE, and prefix=None LoRA loading, and rolled out RunPod endpoint e7wt9pgo7djv55 to release v10 (100% on latest).",
    "Upgraded Worker API & deployed vhunambi-api Version 1e59f21e-1a27-4c2e-b3ac-4551be226f42 (38/38 API suites pass) preserving totalCount===10 while adding GET /v1/studio/loras/factory, POST /datasets/prep, POST /train, and HMAC-SHA256 POST /v1/webhooks/training.",
    "Implemented StudioLoraRegistryNotifier + STD-UIUX-001 LoraFactoryStatusSheet + TrackSectionRepaintSheet Factory launcher (dart analyze 0 issues; 7/7 Flutter Phase 83+85 tests pass; STD_UIUX_001_HITS=0)."
  ],
  "gotchas": [
    "Donor train_lora.py:201-215 is a mock writing b'MOCK_SAFETENSORS_DATA' (21 bytes) to dead zania-explore.vercel.app; NEVER copy its body — use real PyTorch PEFT flow-matching optimization and verify >64 bytes + torch.isfinite() + SHA-256.",
    "phase83_repaint_lora_routes.test.ts:26-28 asserts GET /v1/studio/loras returns totalCount === 10 and packs.length === 10; keep AFRICAN_LORA_PACKS at 10 genre packs and expose bantu_vocals_v1 in additive languagePacks[] + findLoraPackById().",
    "Upstream ACE-Step / PEFT loaders require prefix=None on load_lora_adapter() or a PEFT directory (adapter_config.json + adapter_model.safetensors); embed PEFT config inside .safetensors __metadata__ AND reconstruct a local PEFT directory via materialize_peft_dir_from_safetensors() in model_utils.py:_hot_swap_loras().",
    "Developer laptop has 8 GB RAM / 1 TB HDD / Intel Iris Xe and GitHub Actions billing is blocked; build GPU worker delta images via Docker Build Cloud (--builder cloud-ndugelo-vhunambi --platform=linux/amd64 --provenance=false -f tools/zr-studio-gpu/Dockerfile.delta --push ./tools) with an explicit bumped tag (:vhunambi-v<N>) and PATCH RunPod update-endpoint with ONLY {image} so [redacted] env secrets are never wiped."
  ]
}
```

# Phase 85 Session Memory (Completed — Live Cloud Trained, `:vhunambi-v5` Deployed)

> **Status:** `completed` (`completed_at: 2026-11-25T13:52:00+02:00`; live A40 LoRA training + Docker Build Cloud `:vhunambi-v5` rollout completed `2026-11-25T18:19:00+02:00`). All milestones `M1..M6` verified against Python `unittest` (16/16 GPU + 3/3 PEFT tests), `tsc --noEmit` + `npm test` (38/38 API suites), `dart analyze` (0 issues), `flutter test` (7/7 Phase 83+85 tests), `STD-UIUX-001` check (`0` hits), live Supabase migration `20261125000002_phase85_cloud_lora_factory.sql` with 6/6 ready LoRA packs `active`, live Cloudflare Worker (`1e59f21e-1a27-4c2e-b3ac-4551be226f42`), and live RunPod endpoint `e7wt9pgo7djv55` release `v10` (`ndugelo/zr-studio-gpu:vhunambi-v5`). Operational playbook codified in [`.agents/skills/vhunambi-cloud-gpu-factory/SKILL.md`](../../../.agents/skills/vhunambi-cloud-gpu-factory/SKILL.md).
