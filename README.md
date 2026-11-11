# VHUNAMBI — Autonomous Engineering Monorepo

> **Platform:** African AI Music Synthesis & Commercial Licensing Platform  
> **Source Origin:** Production Web Client (`https://vhunambi.com`)  
> **Target:** Cross-Platform Client (Flutter/Dart — Windows, macOS, Android, iOS) + Cloudflare Workers Edge API (`workerd`)  
> **Architecture Standard:** All-Gemini Engineering Standard ([`docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md))  
> **Specification Architect & Executioner Skills:** [`.agents/skills/vhunambi-spec-architect/SKILL.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/.agents/skills/vhunambi-spec-architect/SKILL.md) · [`.agents/skills/vhunambi-executioner/SKILL.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/.agents/skills/vhunambi-executioner/SKILL.md)  
> **Current Status (2026-11-12):** Phases 0 – 63 Implemented · Live Cloudflare Worker (`https://vhunambi-api.ndugelosigwadi.workers.dev`) & R2 (`zr-studio-audio`) Deployed · Supabase GoTrue + 19-Table Schema Provisioned · `42.8 MB` Cloud-Wired ARM64 Release APK Installed on Huawei (`EPHUT20917014649`) (`20/20 API Test Suites Green · Phase 58–63 Convergence Shipped`)

---

## 1. Executive Summary & Brand Identity

* **Platform Name:** **`vhunambi`** (with an **i**, from Tshivenḓa for *"the talent or ability to sing"*). Never use `vhunamba`.
* **Domain & Mission:** Empowering creators with state-of-the-art generative audio synthesis tailored specifically for African regional rhythms (Amapiano, Kwaito, Gqom, Maskandi, Mbaqanga, Marabi, Bubblegum, Afro House), 25+ indigenous African and diaspora dialects, 4-stem separation, 3D Song DNA visual synthesis, and instant commercial beat licensing.
* **All-Gemini 4-Stage Engineering Symbiosis:**
  1. **Stage 1 — Vision, Video Forensics & Strategy (`Gemini 4 Argon` on Browser Chat + User):** Inspects physical device screen recordings (`.mp4`), screenshots, and generative concept imagery to diagnose root-cause UX/physics/rendering gaps and formulate the Stage 2 Spec Generation Prompt.
  2. **Stage 2 — High-Velocity 4-Doc Spec Drafting (`Antigravity IDE — Gemini 3.8 Flash High`):** Operates strictly in Spec-Only Mode (zero edits in `lib/` or `test/`, zero builds/tests) to author the initial 4-document specification suite (`blueprint.md`, `requirements.md`, `design.md`, `tasks.md`).
  3. **Stage 3 — Forensic Spec Cross-Examination & Hardening (`Gemini 4 Argon` Browser Chat $\to$ `Antigravity IDE — Gemini 4 Argon High`):** Audits Flash 3.8's drafted specs against the **6 Anti-Bait-and-Switch Laws** ([`FORENSIC_SPEC_CHECKLIST.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/.agents/skills/vhunambi-spec-architect/references/FORENSIC_SPEC_CHECKLIST.md)), catching theory-vs-code shortcuts, coordinate axis contradictions, dead callbacks, and hallucinated tokens before rewriting and unifying the 4 spec files in-place with zero code execution.
  4. **Stage 4 — Deterministic Code Execution, Verification & Physical Device Deployment (`Antigravity IDE — Gemini 3.8 Flash High`):** Executes Milestones M1–M6 deterministically from the Argon-hardened specs, enforces `flutter analyze` (`0 issues`) and `flutter test` (`100% green`), builds the ARM64 release APK, and deploys to the physical Huawei test device (`EPHUT20917014649`).

---

## 2. Monorepo Structure

```
c:\Users\Ndugelo\VHUNAMBI\monorepo\
├── .agents/
│   └── skills/
│       ├── vhunambi-spec-architect/       # Workspace Skill: Forensic 4-Doc Specification Architect
│       └── vhunambi-executioner/          # Workspace Skill: Stage 4 Deterministic Execution & Verification
│
├── supabase/
│   └── migrations/
│       └── 20261110000001_phase62_hybrid_cloud_schema.sql # 19-table Postgres schema & atomic RPCs
│
├── tools/
│   └── zr-studio-gpu/                     # Tier-2 RunPod Serverless GPU Worker (Demucs v4, Mastering, Seed-VC, MMO)
│
├── apps/
│   ├── vhunambi_api/                      # Hybrid Edge/Node Hono API (Cloudflare Worker + Node.js SQLite WAL)
│   │   ├── wrangler.toml                  # Cloudflare Worker config (`VHUNAMBI_VAULT` = `zr-studio-audio`, `GENERATION_DO`)
│   │   ├── src/
│   │   │   ├── config/                    # Request-scoped `resolveRuntimeEnv(c)` & media origin normalizer
│   │   │   ├── db/                        # `vhunambi_db.ts` (lazy `node:sqlite`), `edge_persistence_bridge.ts`, `supabase_cloud_driver.ts`
│   │   │   ├── middleware/                # Dual-gate JWT & tenant isolation (`sovereignAuthMiddleware`, strict mode)
│   │   │   ├── security/                  # `HS256` & Supabase `ES256` JWKS verifier, `scrypt` password hashing
│   │   │   ├── modules/
│   │   │   │   ├── bantu/                 # Bantu language context (Tshivenḓa phonetic guidelines, cultural idioms)
│   │   │   │   ├── dna/                   # Canonical SongMetadataDna & MMO v2.0 compiler
│   │   │   │   ├── lyrics/                # LLM / Story-to-lyrics engine & bracketed stanza compiler
│   │   │   │   ├── marketplace/           # Atomic beat licensing & exclusive buyout guard
│   │   │   │   ├── realtime/              # `GenerationSessionDO` Durable Object WebSocket coordinator
│   │   │   │   ├── social/                # Social clips, comments, cultural tipping & creator wallet bridge
│   │   │   │   ├── synthesis/             # Prompt compiler, R2 vault S3/binding proxy, RunPod & mock adapters
│   │   │   │   ├── vision/                # Headless RunPod ComfyUI 9:16 vision adapter & video stub fallback
│   │   │   │   ├── voices/                # 24-voice African catalog & sound signature registry
│   │   │   │   └── jobs/                  # Generation job tracking store
│   │   │   ├── routes/                    # auth, explore, generations, library, lyrics, marketplace, melodies, payments, playlists, social, sync, system, vision, voices, wallet, webhooks
│   │   │   ├── worker.ts                  # Cloudflare Worker entrypoint & Durable Object export
│   │   │   ├── server.ts                  # Portless Hono app (`/r2/*`, `/ws/generation`, REST routes)
│   │   │   └── index.ts                   # Node.js server entrypoint
│   │   └── test/                          # 20 unit & integration test suites (`npm test` -> 20/20 passing)
│   │
│   └── vhunambi_client/                   # Production Flutter Cross-Platform Client
│       ├── lib/
│       │   ├── core/
│       │   │   ├── auth/                  # `authSessionProvider`, `SovereignAuthRepository`, multi-tenant Hive sanitizer
│       │   │   ├── constants/             # `AppConstants` (`API_BASE_URL`, `MEDIA_BASE_URL`, 26 Hive box keys)
│       │   │   ├── design_system/         # Design token registry & generation request state
│       │   │   ├── network/               # `SovereignApiClient` & Dio `401` single-flight refresh interceptor
│       │   │   ├── storage/               # `SovereignHiveBootstrapService` (26 AES-256/Hive boxes), WAL & compaction
│       │   │   ├── sync/                  # `EdgeSyncCoordinator` delta pull/push & lifecycle sync
│       │   │   ├── theme/                 # Light/Dark tokens (`AppColors`, `AppGradients`, `AppTypography`, etc.)
│       │   │   ├── utils/                 # `ResponsiveUtils`, `canonicalizeCreatorId`
│       │   │   └── widgets/               # Shared UI atoms (`VhunambiTopBarKit`, `VhunambiBottomDockKit`, etc.)
│       │   ├── features/
│       │   │   ├── auth/                  # `SovereignAuthSheet` (Supabase Sign-In, Registration & Quick Studio Switch)
│       │   │   ├── beats/, collections/, content_studio/, creator_dna/, explore/, home/, landing/,
│       │   │   │   library/, marketplace/, mastering/, notifications/, offline/, onboarding/,
│       │   │   │   player/, playlists/, profile/, social/, studio/, track/
│       │   └── main.dart                  # 26-Box Hive boot + `RootShell` + `MiniPlayerHost`
│       └── test/                          # Comprehensive client unit & widget test suites
│
└── docs/
    ├── AGENT_HANDOFF_BIBLE.md             # Authoritative monorepo handoff & phase history (Phases 0–63)
    ├── FLAWS_AND_UNFINISHED_FEATURES.md   # Index to live architecture, cloud & device gap audit
    ├── VHUNAMBI_AGENT_WORKFLOW_STANDARD.md# All-Gemini Engineering Standard
    ├── audits/                            # Forensic audits (`FLAWS_AND_UNFINISHED_FEATURES_AUDIT.md`, Phases 60–63)
    ├── foundation_blueprints/             # Single Source of Truth (SSOT) Specifications (00 through 07)
    └── phases/                            # Phases 03 through 63 specification suites (`blueprint/requirements/design/tasks`)
```

---

## 3. Engineering Phase Roadmap & Active Status

| Phase | Milestone Name | Status | Verified Deliverables |
|:---:|---|:---:|---|
| **0 – 22** | **Core Platform, Audio Engine, Backend API, Cloud GPU & Heritage Crate** | Complete | Blueprints 00–07, Flutter client (`apps/vhunambi_client`), Node.js/Hono API (`apps/vhunambi_api`), RunPod ACE-Step 1.5 & ComfyUI adapters, Cloudflare R2 storage, Bantu Voice LoRA Engine, 4-Channel Stem Mixer, Heritage Crate & MPC Chopper, and 60 FPS Hardware Video Muxer. |
| **M1 – M6** | **Full-Stack UI/UX Modernization Sprint (`STD-UIUX-001`)** | Complete | Phosphor Iconography, frosted glass surfaces, 44×44 dp touch targets, `VhunambiTopBarMetrics`, `VhunambiBottomDockMetrics`, and `AfricanGreetingResolver`. |
| **32 – 34** | **44.1 kHz 5-Channel Groove Sketchpad & Split-Sheet Royalty Engine** | Complete | Multi-track PCM audio synthesizer, hybrid Sound Pack Manager, curvy minimalist workstation UI, and cryptographic split-sheet ledger. |
| **35 – 36** | **Sound Signature & Creator DNA 8-Loci Engine** | Complete | 8-loci genomic creator profiling, real-time studio prompt attunement, and interactive double-helix visualization. |
| **46** | **Kinetic Reels V3, Live Edge Sync Coordinator & RunPod V2 Router** | Complete | Zero-latency reel prebuffering, offline-first mutation outbox sync, and multi-endpoint GPU failover routing. |
| **50** | **4-Step Creator DNA Onboarding & Song DNA Quantum Tree** | Complete | First-launch 4-step genomic onboarding flow (`OnboardingView`), official `app_icon.png` launcher branding, and interactive `SongDnaNodeTreeModal`. |
| **51** | **Sovereign Bioluminescent Song Organelle 3D Environment** | Complete | Full-screen opaque `Navigator.of(context, rootNavigator: true)` route (`#020710`), 180-node Fibonacci organelle membrane, and depth-of-field bokeh satellites. |
| **52** | **Surface-Walker 3D Biome & 21-Node Hierarchical Sub-Branch Canopy** | Complete | 3-Tier Camera State Machine (`surfaceOverview`, `canopyFlyIn`, `leafInspect`), 15 hierarchical sub-nodes (`SongDnaSubNode`), and `+ Add Instrument Leaf` dynamic creation. |
| **53** | **Organic Mycelium Network 3D Musical Ecosystem Biome** | Complete | 6 fruiting-body mushroom clusters, terrain-clamped hyphae filigree mesh, Right-Handed 3D Y-Up camera engine, and 5 ecological HUD decks. |
| **54 – 56** | **Cockpit–Biome Quantum Entanglement, Audio-Reactive Player & Mobile Overhaul** | Complete | Bidirectional 5-provider graph sync, audio-reactive 3D Biome hero mode in `ExpandedCockpitModal`, compact prompt-first Studio Compose, and mobile HUD popovers. |
| **57** | **System-1 Calibrated "Jev" DNA Melody Resynthesizer & 44.1 kHz DSP** | Complete | Padé `[3/2]` soft-knee limiter, analytical pitch-drop phase integration, kick-to-bass sidechain ducking, acoustic choke group, and active-channel DNA resynthesis. |
| **58** | **Sovereign Beatstore Licensing, SHA-256 Certificates & Stem Unpacker** | Complete | 3-tier checkout (`Basic MP3`, `Premium WAV`, `Exclusive Stem`), `85/15` split, FIPS 180-4 SHA-256 deeds, `BeatDeliveryUnpackerService`, and atomic exclusive buyout lock. |
| **59** | **Full-Stack Backend API Convergence & SA Banking Gateway** | Complete | `/api/explore`, `/api/library/sync`, `/api/playlists` CRUD/share, canonical 6-bank SA registry + 4 payout rails, and `EdgeSyncCoordinator` delta hydrators. |
| **60** | **26-Box Sovereign Hive Brain & Persistence Convergence** | Complete | Startup 26-box initialization, HKDF-SHA256 `HiveAesCipher` across 7 sensitive boxes, $O(1)$ entity keys, `CheckoutWriteAheadJournal`, and `HiveBrainTelemetryCard`. |
| **61** | **Sovereign Identity, Authentication & Multi-Tenant Security** | Complete | `/api/auth/*`, dual-gate `sovereignAuthMiddleware`, `BEGIN IMMEDIATE` payout lock, `402` zero-coin beat exploit closure, `SovereignAuthSheet`, and tenant Hive sanitizer. |
| **62** | **Hybrid Cloud Stack Topology & Production Edge Convergence** | Complete | 19-table Supabase PostgreSQL migration (`supabase/migrations/`), Cloudflare `worker.ts` + `GenerationSessionDO`, `VHUNAMBI_VAULT` R2 streaming, `PayFast ITN`, and `tools/zr-studio-gpu` repairs. |
| **63** | **E2E Studio-to-Cloud Execution Loop, `workerd` Bridge & 5-Pillar Preflight** | Complete (Code & Edge Deployed) | `EdgePersistenceBridge` (`workerd` compatibility), `PUT /r2/:key`, unified Studio submit, dual-dialect DO WebSockets, `CloudVideoExportService`, and `GET /api/system/preflight` + `CloudStackDiagnosticCard`. |

---

## 4. Current Live Cloud Standings (Verified `2026-11-12`)

### Active Cloud Infrastructure
- **Cloudflare Worker (`vhunambi-api`):** Deployed live at `https://vhunambi-api.ndugelosigwadi.workers.dev` (`GET /health` -> `200 OK`; `VHUNAMBI_AUTH_MODE = "strict"`, `GENERATION_DO` Durable Object bound).
- **Cloudflare R2 (`zr-studio-audio`):** Bound as `VHUNAMBI_VAULT` with public origin `https://pub-d22409017abb4dd999327a092c5f06d3.r2.dev` (`PUT /r2/:key` and `GET /r2/:key` live). Bucket currently contains `0` seeded objects.
- **Supabase Cloud (`cbnruevwrqwjnnoscgsz.supabase.co`):** 19-table migration applied; 7 seeded creator accounts provisioned in Supabase Auth (`@cern`, `@makhadzi`, `@sigwa`, `@kabza`, `@focalistic`, `@tyla`, `@blackcoffee`).
- **Physical Android Client:** [`app-release.apk`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/build/app/outputs/flutter-apk/app-release.apk) (`44,887,831 bytes` / `42.8 MB` ARM64) compiled with live `API_BASE_URL` and `MEDIA_BASE_URL` overrides and installed on Huawei `JNY_LX1` (`EPHUT20917014649`).

### Verified Operational Reality vs. Remaining Gaps
- **Works Live Today:** Supabase `ES256` authentication, strict JWT gating, 5-Pillar Preflight probe (`GET /api/system/preflight`), real R2 WAV uploads from Sketchpad / Voice Clone / Sound Signatures, real on-device 44.1 kHz Sketchpad & Vocal Catalog audio playback, and 26-box AES-256/Hive local persistence.
- **Known Gaps (See [`docs/audits/FLAWS_AND_UNFINISHED_FEATURES_AUDIT.md#11-post-phase-63-live-cloud-deployment--physical-device-gap-audit-2026-11-12`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/audits/FLAWS_AND_UNFINISHED_FEATURES_AUDIT.md#L484) and [`docs/AGENT_HANDOFF_BIBLE.md#40-live-cloud-standings--post-phase-63-remediation-queue-2026-11-12`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/AGENT_HANDOFF_BIBLE.md#L1768)):**
  1. **RunPod Audio Endpoint (`e7wt9pgo7djv55`):** Credentials configured in Worker secrets, but `0` workers are online (`jobs` queue until client timeout); `tools/zr-studio-gpu/Dockerfile` also omits `model_utils.py`.
  2. **Main MiniPlayer Transport (`main.dart`):** `bootstrapPlatformAudioHandler` is not overridden in `ProviderScope`, leaving the global MiniPlayer on headless `TestVhunambiAudioHandler` (timer ticks without speaker output; Sketchpad & 4-Stem Pocket DAW still use `just_audio`).
  3. **LLM / Vision / Voice / PayFast Stubs:** `ANTHROPIC_API_KEY` and `GROK_API_KEY` are unset (template lyrics fallback), `RUNPOD_COMFYUI_*` is unset (1x1 transparent PNG & 32-byte empty `.mp4` header uploaded to R2), `/v1/voices/signatures/:id/analyze` is an `enqueued` stub, and PayFast runs in Sandbox mode.
  4. **Worker Postgres Bridge:** Only `auth_routes.ts` queries `SupabaseCloudDriver`; all other Worker data routes still use in-isolate volatile `EdgeIsolateDatabaseEngine` memory rather than Supabase PostgreSQL.

---

## 5. Verification Health Check & Deployment

### Client (`apps/vhunambi_client`)
```powershell
cd apps/vhunambi_client

# 1. Static Analysis Gate
flutter analyze

# 2. Automated Test Suite (use timeout guard for widget suites)
flutter test --timeout=60s

# 3. Cloud-Wired ARM64 Release APK Build & Device Install
flutter build apk --release --target-platform android-arm64 `
  --dart-define=API_BASE_URL=https://vhunambi-api.ndugelosigwadi.workers.dev `
  --dart-define=MEDIA_BASE_URL=https://pub-d22409017abb4dd999327a092c5f06d3.r2.dev
adb -s EPHUT20917014649 install -r build/app/outputs/flutter-apk/app-release.apk
```

### Backend API Gateway (`apps/vhunambi_api`)
```powershell
cd apps/vhunambi_api

# 1. TypeScript Build Gate (0 errors) & All 20 Test Suites (20/20 green)
npm run build
npm test

# 2. Deploy Cloudflare Worker
.\node_modules\.bin\wrangler.cmd deploy
```

---

## 6. How to Resume Work

1. Read [`docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md) and [`.agents/skills/vhunambi-executioner/SKILL.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/.agents/skills/vhunambi-executioner/SKILL.md).
2. Open [`docs/AGENT_HANDOFF_BIBLE.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/AGENT_HANDOFF_BIBLE.md) for the complete Phases 0–63 architecture record and live cloud status.
3. Open [`docs/audits/FLAWS_AND_UNFINISHED_FEATURES_AUDIT.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/audits/FLAWS_AND_UNFINISHED_FEATURES_AUDIT.md) (Section 11) for the exact prioritized next fixes across RunPod, `main.dart` audio transport, R2 asset seeding, and Supabase Postgres route wiring.
