# VHUNAMBI — Autonomous Engineering Monorepo

> **Platform:** African AI Music Synthesis & Commercial Licensing Platform  
> **Source Origin:** Production Web Client (`https://vhunambi.com`)  
> **Target:** Cross-Platform Client (Flutter/Dart — Windows, macOS, Android, iOS)  
> **Architecture Standard:** All-Gemini 4-Stage Symbiosis & Forensic Specification Standard ([`docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md))  
> **Specification Architect Skill:** [`.agents/skills/vhunambi-spec-architect/SKILL.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/.agents/skills/vhunambi-spec-architect/SKILL.md)  
> **Current Status:** Phases 0 – 52 Complete & Verified on Physical Device (`EPHUT20917014649`) · **Phase 53 (Organic Mycelium 3D Biome)** Stage 3 Argon-Hardened 4-Doc Spec Suite Complete & Ready for Stage 4 Flash Execution (`0 Analyzer Warnings · 100% Green Test Suite · 43.3 MB ARM64 Release APK`)

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
│       └── vhunambi-spec-architect/       # Workspace Skill: Forensic 4-Doc Specification Architect
│           ├── SKILL.md                   # All-Gemini 4-Stage Pipeline & 6 Anti-Bait-and-Switch Laws
│           └── references/
│               └── FORENSIC_SPEC_CHECKLIST.md # 6-Trap Forensic Audit Checklist & Authentic Token Cheat-Sheet
│
├── apps/
│   ├── vhunambi_api/                      # Autonomous Node.js/Hono Audio Synthesis API Gateway
│   │   ├── src/
│   │   │   ├── modules/
│   │   │   │   ├── bantu/                 # Bantu language context (Tshivenḓa phonetic guidelines, cultural idioms)
│   │   │   │   ├── dna/                   # Canonical SongMetadataDna compiler & types
│   │   │   │   ├── lyrics/                # LLM story-to-lyrics engine & bracketed stanza compiler
│   │   │   │   ├── synthesis/             # African genre prompt compiler, Cloudflare R2 storage, RunPod adapter
│   │   │   │   ├── vision/                # Headless RunPod ComfyUI 9:16 vision adapter & prompt synthesizer
│   │   │   │   └── jobs/                  # Job tracking store & state machine
│   │   │   ├── routes/                    # /v1/lyrics, /v1/generations, /v1/webhooks, /health
│   │   │   ├── server.ts                  # Portless Hono app for modularity & testability
│   │   │   └── index.ts                   # Bootstrapped server entry point
│   │   └── test/                          # Unit and integration test suites (100% passing)
│   │
│   └── vhunambi_client/                   # Production Flutter Cross-Platform Client
│       ├── lib/
│       │   ├── core/
│       │   │   ├── theme/                 # Design system tokens (AppColors, AppGradients, AppTypography, AppRadius, AppSpacing)
│       │   │   ├── utils/                 # ResponsiveUtils (Mobile < 768px vs Desktop > 1024px)
│       │   │   ├── constants/             # AppConstants
│       │   │   └── widgets/               # Shared UI atoms: VhunambiBackButton, VhunambiTopBarMetrics, VhunambiBottomDockMetrics
│       │   ├── features/
│       │   │   ├── beats/                 # Producer Beats Vault (/library?tab=beats)
│       │   │   ├── collections/           # Collections & EP/Album Concept Bundler (/library?tab=collections)
│       │   │   ├── content_studio/        # 9:16 Content Studio Dock (60 FPS kinetic canvas, 4 typography styles, MP4 export)
│       │   │   ├── explore/               # Explore Feed & Heritage Discovery (/explore) — HIG 44px sweep
│       │   │   ├── home/                  # Native Creator Dashboard (Tab 0)
│       │   │   ├── landing/               # Marketing Funnel — hero, genres, pillars, pricing
│       │   │   ├── library/               # Library & User Asset Vault (/library)
│       │   │   ├── marketplace/           # Beats Marketplace (/market)
│       │   │   ├── notifications/         # Real-time notifications drawer & popover
│       │   │   ├── offline/               # Offline Audio Persistence, Hive Cache & Vault Storage Modal
│       │   │   ├── onboarding/            # Native Splash Screen & 4-Step Creator DNA Onboarding Flow
│       │   │   ├── player/                # Persistent Audio Transport Bar & Expanded Cockpit Modal — HIG 44px sweep
│       │   │   ├── playlists/             # Playlists Vault & Local Persistence (/library?tab=playlists)
│       │   │   ├── profile/               # Creator Studio & Public Artist Profiles
│       │   │   ├── social/                # Social Creator Network: Kinetic Reels, Reactions, Tipping
│       │   │   ├── studio/                # Studio AI Cockpit (/create), 5-Channel Groove Sketchpad, 3D Song DNA Biome
│       │   │   └── track/                 # Track Details Cockpit & Stem Separation Lab (/track/:id) — HIG 44px sweep
│       │   └── main.dart                  # Root application entry
│       └── test/                          # Complete test suites — 100% green, 0 regressions
│
└── docs/
    ├── AGENT_HANDOFF_BIBLE.md             # SINGLE ENTRY POINT FOR INCOMING AGENT
    ├── VHUNAMBI_AGENT_WORKFLOW_STANDARD.md# All-Gemini 4-Stage Symbiosis & Forensic Specification Standard (Rev 4.0)
    ├── DUAL_AGENT_AUDIT_IMPROVE_WORKFLOW.md # Audit-Then-Improve Lifecycle & Trap Catalog
    ├── VHUNAMBI_MODERNIZATION_CHRONICLE.md # Full-Stack UI/UX Modernization Master Record
    ├── standards/
    │   └── VHUNAMBI_UI_UX_AND_ICONOGRAPHY_STANDARD.md # STD-UIUX-001 (Phosphor Icons, Frosted Bleed, 360dp Defense)
    ├── audits/                            # Forensic Audit Briefs & Root-Cause Reports
    ├── foundation_blueprints/             # Single Source of Truth (SSOT) Specifications (00 through 07)
    └── phases/
        ├── phase_03_create_studio/ ... phase_31_.../  # Executed & Verified Foundation & Expansion Phases
        ├── phase_32_multitrack_sketchpad/             # 44.1 kHz 5-Channel Groove Sequencer & Sound Pack Manager
        ├── phase_34_split_sheet_royalty_engine/       # Split-Sheet Royalty Engine & Export
        ├── phase_35_sound_signature_dna_engine/       # Creator DNA 8-Loci Sequencing & Sound Signature Engine
        ├── phase_36_creator_dna_cockpit_and_studio/   # Creator DNA Cockpit & Studio Attunement
        ├── phase_46_kinetic_reels_v3_and_edge_sync/   # Kinetic Reels V3, Live Edge Sync & RunPod V2 Router
        ├── phase_50_creator_dna_onboarding_and_tree/  # 4-Step Creator DNA Onboarding & Song DNA Quantum Tree
        ├── phase_51_bioluminescent_song_organelle/    # Sovereign Full-Screen 3D Organelle World View
        ├── phase_52_surface_walker_3d_biome/          # Surface-Walker Macro-Canopy Camera & 21-Node Expansion
        └── phase_53_organic_mycelium_3d_biome/        # PRIMARY GOLD STANDARD: 3D Organic Mycelium Biome (4-Doc Suite)
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
| **52** | **Surface-Walker 3D Biome & 21-Node Hierarchical Sub-Branch Canopy** | Complete | 3-Tier Camera State Machine (`surfaceOverview` 1.0x, `canopyFlyIn` 2.25x, `leafInspect` 2.85x), 15 hierarchical sub-nodes (`SongDnaSubNode`), and `+ Add Instrument Leaf` dynamic creation. Installed on Huawei `EPHUT20917014649`. |
| **53** | **Organic Mycelium Network 3D Musical Ecosystem Biome** | **Stage 3 Spec Hardened (Ready for Stage 4 Execution)** | Complete 4-doc specification suite in [`docs/phases/phase_53_organic_mycelium_3d_biome/`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_53_organic_mycelium_3d_biome/blueprint.md): 6 primary fruiting-body mushroom clusters (`ui.Vertices` 5-ring × 24-seg 3D fluted caps, 32 arched gills, 8-ring hyperboloid stalks, 72 rootlet tendrils), 120-attractor space-colonization hyphae web with 16 3D sprout mushrooms, unified Right-Handed 3D Y-Up projection & synchronous hit-testing, and 5 HUD decks. |

---

## 4. Verification Health Check

### Client (`apps/vhunambi_client`)
```powershell
cd apps/vhunambi_client

# 1. Static Analysis Gate (0 issues)
flutter analyze

# 2. Automated Test Suite (100% passing)
flutter test

# 3. Physical Device Release Build & Install (Stage 4 Only)
flutter build apk --release --target-platform android-arm64
adb -s EPHUT20917014649 install -r build/app/outputs/flutter-apk/app-release.apk
```

### Backend API Gateway (`apps/vhunambi_api`)
```powershell
cd apps/vhunambi_api

# 1. TypeScript Build Gate (0 errors)
pnpm build

# 2. Automated Test Suite (100% passing)
pnpm test
```

---

## 5. How to Resume Work

1. Read [`docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md) and [`.agents/skills/vhunambi-spec-architect/SKILL.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/.agents/skills/vhunambi-spec-architect/SKILL.md) to confirm your active stage in the **All-Gemini 4-Stage Symbiosis Pipeline**.
2. Open [`docs/AGENT_HANDOFF_BIBLE.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/AGENT_HANDOFF_BIBLE.md) for full architectural context.
3. For **Phase 53 Stage 4 Execution** (`Gemini 3.8 Flash High`), execute Milestones M1 through M6 in [`docs/phases/phase_53_organic_mycelium_3d_biome/tasks.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_53_organic_mycelium_3d_biome/tasks.md) against the Argon-hardened [`design.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_53_organic_mycelium_3d_biome/design.md).
