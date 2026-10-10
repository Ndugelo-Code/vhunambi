# VHUNAMBI — Autonomous Engineering Monorepo

> **Platform:** African AI Music Synthesis & Commercial Licensing Platform  
> **Source Origin:** Production Web Client (`https://vhunambi.com`)  
> **Target:** Cross-Platform Client (Flutter/Dart — Windows, macOS, Android, iOS)  
> **Architecture Standard:** Dual-Agent Symbiosis ([`docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md))  
> **Current Status:** ✅ Phase 0 – 18 Complete (Full-Stack Audio Synthesis Engine, Live Cloud & RunPod GPU Bridge, Bantu Linguistic Modules, Beats Vault, Song Metadata DNA & Lyric Video Content Engine, Social Creator Network & In-House Kinetic Reels Discovery)

---

## 1. Executive Summary & Brand Identity

* **Platform Name:** **`vhunambi`** (with an **i**, from Tshivenḓa for *"the talent or ability to sing"*). Never use `vhunamba`.
* **Domain & Mission:** Empowering creators with state-of-the-art generative audio synthesis tailored specifically for African regional rhythms (Amapiano, Kwaito, Gqom, Maskandi, Mbaqanga, Marabi, Afro House), 25+ indigenous African and diaspora dialects, stem separation, and instant commercial beat licensing.
* **Dual-Agent Engineering Model:**
  - **Antigravity IDE:** Chief Architect, Visual Dissector, Repository Pre-Flight Gatekeeper, QA Auditor.
  - **Cline + DeepSeek V4 Flash:** High-Volume Implementation Workhorse (1M context headroom).

---

## 2. Monorepo Structure

```
c:\Users\Ndugelo\VHUNAMBI\monorepo\
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
│       │   │   └── constants/             # AppConstants
│       │   ├── features/
│       │   │   ├── beats/                 # Producer Beats Vault (/library?tab=beats) — 87 passing tests
│       │   │   ├── content_studio/        # 9:16 Content Studio Dock (60 FPS kinetic canvas, 4 typography styles, MP4 export)
│       │   │   ├── home/                  # Native Creator Dashboard (Tab 0)
│       │   │   ├── onboarding/            # Native Splash Screen & 3-Step Preference Onboarding Flow
│       │   │   ├── explore/               # Explore Feed & Discovery (/explore)
│       │   │   ├── landing/               # Marketing Funnel — hero, genres, pillars, pricing
│       │   │   ├── library/               # Library & User Asset Vault (/library)
│       │   │   ├── marketplace/           # Beats Marketplace (/market)
│       │   │   ├── offline/               # Offline Audio Persistence, Hive Cache & Vault Storage Modal
│       │   │   ├── player/                # Persistent Audio Transport Bar & Expanded Cockpit Modal
│       │   │   ├── profile/               # Creator Studio & Public Artist Profiles
│       │   │   ├── studio/                # Studio Cockpit (/create) & Live Generation Pipeline Card
│       │   │   ├── track/                 # Track Details Cockpit (/track/:id)
│       │   │   └── notifications/         # Real-time notifications drawer & popover
│       │   └── main.dart                  # Root application entry
│       └── test/                          # Complete test suites
│
└── docs/
    ├── AGENT_HANDOFF_BIBLE.md             # ⭐ SINGLE ENTRY POINT FOR INCOMING AGENT
    ├── VHUNAMBI_AGENT_WORKFLOW_STANDARD.md# Dual-Agent Symbiosis Operational Protocol
    ├── AI_AGENT_WORKFLOW_STANDARD.md      # LODA Protocol Foundation Blueprint
    ├── CLINE_HANDOFF_PHASE3.md            # Phase 3 Handoff Record (Executed & Verified)
    ├── CLINE_HANDOFF_PHASE4.md            # Phase 4 Handoff Record (Executed & Verified)
    ├── CLINE_HANDOFF_PHASE5.md            # Phase 5 Handoff Record (Executed & Verified)
    ├── CLINE_HANDOFF_PHASE6.md            # Phase 6 Handoff Record (Executed & Verified)
    ├── CLINE_HANDOFF_PHASE7.md            # Phase 7 Handoff Record (Executed & Verified)
    ├── CLINE_HANDOFF_PHASE8_RESUME.md     # Phase 8 Handoff Record (Executed & Verified)
    ├── CLINE_HANDOFF_PHASE9.md            # Phase 9 Master Execution Handoff (Specified & Ready)
    ├── foundation_blueprints/             # Single Source of Truth (SSOT) Specifications:
    │   ├── README.md                      # Index, 5-layer dissection rule & Tshivenḓa etymology
    │   ├── 00_SYSTEM_DESIGN_TOKENS.md     # Colors, surfaces, typography, radii, 12 genre gradients
    │   ├── 01_EXPLORE_PAGE_SPEC.md        # Explore view (/explore) & responsive breakpoints
    │   ├── 02_PERSISTENT_PLAYER_SPEC.md   # Audio architecture, bottom dock & expanded cockpit
    │   ├── 03_CREATE_STUDIO_SPEC.md       # Parameter-rich studio cockpit (/create)
    │   ├── 04_LIBRARY_VAULT_SPEC.md       # User asset vault (/library) & 6 asset tabs
    │   ├── 05_MARKETPLACE_AND_LANDING_SPEC.md # Beats marketplace (/market), native home dashboard & onboarding
    │   ├── 06_TRACK_AND_CREATOR_PROFILES_SPEC.md # Track details & creator studio profiles
    │   └── 07_AUDIO_TRANSPORT_AND_PIPELINE_MODALS_SPEC.md # Transport bar, mobile dock, modals
    └── phases/
        ├── phase_03_create_studio/        # Phase 3 4-doc suite (blueprint, requirements, design, tasks)
        ├── phase_04_library_vault/        # Phase 4 4-doc suite (blueprint, requirements, design, tasks)
        ├── phase_05_explore_feed/         # Phase 5 4-doc suite (blueprint, requirements, design, tasks)
        ├── phase_06_marketplace/          # Phase 6 4-doc suite (blueprint, requirements, design, tasks)
        ├── phase_07_track_profiles/       # Phase 7 4-doc suite (blueprint, requirements, design, tasks)
        ├── phase_08_offline_cache/        # Phase 8 5-doc suite (blueprint, requirements, design, tasks, walkthrough)
        ├── phase_09_hardware_audio_bridge/# Phase 9 4-doc suite (blueprint, requirements, design, tasks)
        ├── phase_10_generation_pipeline_bridge/ # Phase 10 4-doc suite
        ├── phase_11_notifications_drawer/ # Phase 11 4-doc suite
        ├── phase_12_lyrics_and_playlists/ # Phase 12 5-doc suite (walkthrough included)
        ├── phase_12_1_playlists_vault/    # Phase 12.1 5-doc suite (walkthrough included)
        ├── phase_13_collections_bundler/  # Phase 13 5-doc suite (walkthrough included)
        ├── phase_14_beats_vault/          # Phase 14 5-doc suite (walkthrough included)
        ├── phase_15_backend_engine/       # Phase 15 5-doc suite (walkthrough included)
        ├── phase_16_cloud_gpu_integration/# Phase 16 5-doc suite (walkthrough included)
        └── phase_17_song_dna_content_engine/ # Phase 17 5-doc suite (walkthrough included)

```

---

## 3. Engineering Phase Roadmap & Active Status

| Phase | Milestone Name | Status | Verified Deliverables |
|:---:|---|:---:|---|
| **0** | **SSOT Foundation Blueprints** | ✅ Complete | Blueprints 00 through 07 codified on disk in `docs/foundation_blueprints/`. |
| **1** | **Project Initialization & Design Tokens** | ✅ Complete | Created `apps/vhunambi_client`, installed ecosystem, codified theme tokens in `lib/core/theme/`. |
| **2** | **Core Shell & Persistent Audio Engine** | ✅ Complete | `PlayerState`, `PlayerNotifier`, `MobileMiniPlayer`, `DesktopTransportBar`, `ExpandedCockpitModal`, `GenerationPipelineCard`, `NotificationsPopover`. |
| **3** | **Studio Creation Cockpit (`/create`)** | ✅ Complete | Full parameter tree, `StudioFormNotifier`, 6 custom widgets, mounted in `RootShell`, **14 passing tests**. |
| **4** | **Library & User Asset Vault (`/library`)** | ✅ Complete | `LibraryTrack` vault model, 6-category rail with counts, search/sync filters, list & square-grid layouts, universal empty states, soft-delete Trash with restore/purge, contextual action sheet, licensing certificate dialog, mounted in `RootShell` tab 3 — **47 passing tests**. |
| **5** | **Explore Feed & Music Discovery** | ✅ Complete | 10-slice `CustomScrollView` (header/tabs/streak, charts banner, New This Week, Rising matrix, creator deck, 12-genre radio, filter engine, catalog, load-more), Ctrl+K search, playback bridge into the persistent player — mounted at `RootShell` tab 1, **78 passing tests**. |
| **6** | **Beats Marketplace & Native App Architecture** | ✅ Complete | `/market`: beat listing grid + credit licensing flow (vault write) + filter sheet + PWA install dock. Native App Architecture: `SplashView` + 3-step `OnboardingView` (genre/language preferences) + `HomeDashboardView` on Tab 0 (greeting, prompt bar, 4 action tiles, Jump Back In mini-card, trending rail) + native `SubscriptionUpgradeModal` — **127 passing tests**. |
| **7** | **Track Details & Creator Profiles** | ✅ Complete | `/track/:id` (1:1 art, ambient amber glow, royalty-free notice, waveform scrubber, lyrics teleprompter, 4-stem lab & FSM, cultural emoji deck, prompt attribution, comments, recommendations), `/profile/:id` (public artist profile, monogram, 5 stats, top supporters, top songs, recent activity), `/profile/me` (creator studio profile, releases manager, tip ledger, referral card) — **160 passing tests**. |
| **8** | **Hive Local Cache & Audio Offline Sync** | ✅ Complete | Offline audio persistence, dual Hive boxes (`vaultBoxKey`, `preferencesBoxKey`), streaming downloader FSM, storage quota modal, offline badges & player integration — **207 passing tests**. |
| **9** | **Native Hardware Audio Bridge & Media Notifications** | ✅ Complete | Native platform audio sessions (`AudioSessionManager`), system lock-screen media notification controls (`VhunambiAudioHandler`), hardware media key listener, dynamic audio source resolver — **254 passing tests**. |
| **10** | **Generation Pipeline Real-Time WebSocket Bridge** | ✅ Complete | Real-time synthesis WebSocket bridge (`GenerationSocketService`), multi-stage Result panel (`GenerationPipelineCard`), stem download orchestrator, notifications dispatch — **321 passing tests**. |
| **11** | **Notifications Drawer & Real-Time Alert System** | ✅ Complete | Interactive notifications drawer/popover, unread counter badge (`NotificationBellButton`), deep-link routing on alert tap, backward-compatible `notificationsProvider`. |
| **12** | **Studio Lyrics Review Cockpit & Playlists Queue** | ✅ Complete | Subsystem A: Interactive lyrics review modal, cultural idiom injection, raw editor toggle, approve-to-beat handoff. Subsystem B: Full playlist CRUD, sliding `QueueDrawer` with reorderable upcoming queue, `AddToPlaylistSheet` — **460 passing tests**. |
| **12.1** | **Playlists Vault & Local Persistence** | ✅ Complete | Dedicated Playlists tab in Library Vault (`/library?tab=playlists`), `PlaylistDetailView`, Hive persistent `PlaylistRepository` with headless test safety — **477 passing tests**. |
| **13** | **Collections & EP/Album Concept Bundler** | ✅ Complete | Collections tab in Library Vault (`/library?tab=collections`), `CollectionEntity`/`SplitParticipant` domain, Hive `CollectionRepository`, `CollectionsVaultView` (2/3/4-col grid + list, create/rename/delete), `CollectionDetailView` (hero header, Play All/Shuffle, reorderable tracks, split-sheet ledger), `SplitSheetModal` with clipboard export — **541 passing tests**. |
| **14** | **Producer Beats Vault & Beatstore Listing Cockpit** | ✅ Complete | `/library?tab=beats`: `ProducerBeatEntity` / `BeatStemPackage` / `BeatSaleRecord` domain, Hive `BeatRepository`, `beatsProvider`, `BeatsVaultView`, `BeatDetailCockpitView` — **87 passing tests** (100% green). |
| **15** | **Full-Stack Autonomous Backend & Pipeline Bridge** | ✅ Complete | Colocated `apps/vhunambi_api` (Node.js/Hono): Bantu dialect prompt compiler, story-to-lyrics LLM engine, Cloudflare R2 presigned storage, ACE-Step GPU adapter & simulation worker, `/health` observability. Client: `HttpLyricsGenerationService`, `HttpGenerationSubmissionService`, live 4-stage pipeline FSM card, master auto-play, and stem download bridge. |
| **16** | **Live Cloud & GPU Infrastructure Integration** | ✅ Complete | RunPod Serverless ACE-Step 1.5 adapter aligned to upstream `handler.py` schema, Cloudflare R2 audio storage (`vhunambi-audio`), HMAC-SHA256 authenticated webhook gateway (`POST /v1/webhooks/ace-step`), `WEBHOOK_BASE_URL` tunnel configuration, Flutter `TrackEntity` stems degradation, and comprehensive integration test suite. |
| **17** | **Song Metadata DNA & Lyric Video Content Engine** | ✅ Complete | Headless RunPod ComfyUI 9:16 Vision adapter (768×1344), prompt synthesizer, SongMetadataDna domain & compiler, Flutter Content Studio Dock (60 FPS kinetic preview canvas, 4 typography styles, duration trimmer, atmospheric overlays, MP4 export, genre-aware smart defaults, post-generation & vault entrypoints) — **19 passing tests** (100% green). |

---

## 4. Verification Health Check

### Client (`apps/vhunambi_client`)
```powershell
cd apps/vhunambi_client

# 1. Static Analysis Gate (0 issues)
dart analyze .

# 2. Automated Test Suite (100% passing)
flutter test
```

### Backend API Gateway (`apps/vhunambi_api`)
```powershell
cd apps/vhunambi_api

# 1. TypeScript Build Gate (0 errors)
pnpm build

# 2. Automated Test Suite (5/5 suites passing)
pnpm test
```

---

## 5. How to Resume Work

1. Open [`docs/AGENT_HANDOFF_BIBLE.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/AGENT_HANDOFF_BIBLE.md) for complete context.
2. Phases 0 through 17 are **fully executed, verified, and passing**.
3. Phase 17 artefacts: [`docs/phases/phase_17_song_dna_content_engine/walkthrough.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_17_song_dna_content_engine/walkthrough.md) and master handoff [`docs/CLINE_HANDOFF_PHASE17.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/CLINE_HANDOFF_PHASE17.md).
4. Both workspaces are clean with zero errors across tests and static analysis.

