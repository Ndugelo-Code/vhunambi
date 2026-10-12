# VHUNAMBI — Autonomous Engineering Monorepo

> **Platform:** African AI Music Synthesis & Commercial Licensing Platform  
> **Source Origin:** Production Web Client (`https://vhunambi.com`)  
> **Target:** Cross-Platform Client (Flutter/Dart — Windows, macOS, Android, iOS)  
> **Architecture Standard:** Dual-Agent Symbiosis ([`docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md))  
> **Current Status:** ✅ Phase 0 – 22 Complete + Full-Stack UI/UX Modernization Sprint (Top Bar, Bottom Dock, Studio Cockpit, Track Details, Explore Feed — 44px HIG Compliance, Frosted Surfaces & Coordinated Dock Metrics) — **805 Tests Passing · 0 Analyzer Warnings**

---

## 1. Executive Summary & Brand Identity

* **Platform Name:** **`vhunambi`** (with an **i**, from Tshivenḓa for *"the talent or ability to sing"*). Never use `vhunamba`.
* **Domain & Mission:** Empowering creators with state-of-the-art generative audio synthesis tailored specifically for African regional rhythms (Amapiano, Kwaito, Gqom, Maskandi, Mbaqanga, Marabi, Afro House), 25+ indigenous African and diaspora dialects, stem separation, and instant commercial beat licensing.
* **Dual-Agent Engineering Model:**
  - **Antigravity IDE:** Chief Architect, Visual Dissector, Repository Pre-Flight Gatekeeper, QA Auditor, Verification Gatekeeper.
  - **Cline + DeepSeek V4 Flash:** High-Volume Audit & Implementation Workhorse (1M context headroom).
* **Audit-Then-Improve Protocol:** Full-stack UI/UX refactoring follows the structured Lead + Cline dual-agent workflow documented in [`docs/DUAL_AGENT_AUDIT_IMPROVE_WORKFLOW.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/DUAL_AGENT_AUDIT_IMPROVE_WORKFLOW.md).

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
│       │   │   ├── onboarding/            # Native Splash Screen & 3-Step Preference Onboarding Flow
│       │   │   ├── player/                # Persistent Audio Transport Bar & Expanded Cockpit Modal — HIG 44px sweep
│       │   │   ├── playlists/             # Playlists Vault & Local Persistence (/library?tab=playlists)
│       │   │   ├── profile/               # Creator Studio & Public Artist Profiles
│       │   │   ├── social/                # Social Creator Network: Kinetic Reels, Reactions, Tipping
│       │   │   ├── studio/                # Studio AI Cockpit (/create) & MPC Chopper — HIG 44px sweep
│       │   │   └── track/                 # Track Details Cockpit & Stem Separation Lab (/track/:id) — HIG 44px sweep
│       │   └── main.dart                  # Root application entry
│       └── test/                          # Complete test suites — 805 tests, 0 regressions
│
└── docs/
    ├── AGENT_HANDOFF_BIBLE.md             # ⭐ SINGLE ENTRY POINT FOR INCOMING AGENT
    ├── VHUNAMBI_AGENT_WORKFLOW_STANDARD.md# Dual-Agent Symbiosis Operational Protocol (incl. Audit-Then-Improve §6)
    ├── DUAL_AGENT_AUDIT_IMPROVE_WORKFLOW.md # Lead + Cline Audit-Then-Improve Lifecycle & Trap Catalog
    ├── VHUNAMBI_MODERNIZATION_CHRONICLE.md # Full-Stack UI/UX Modernization Master Record (5 Systems)
    ├── AI_AGENT_WORKFLOW_STANDARD.md      # LODA Protocol Foundation Blueprint
    ├── CLINE_HANDOFF_PHASE3.md            # Phase 3 Handoff Record (Executed & Verified)
    ├── CLINE_HANDOFF_PHASE4.md            # Phase 4 Handoff Record (Executed & Verified)
    ├── CLINE_HANDOFF_PHASE5.md            # Phase 5 Handoff Record (Executed & Verified)
    ├── CLINE_HANDOFF_PHASE6.md            # Phase 6 Handoff Record (Executed & Verified)
    ├── CLINE_HANDOFF_PHASE7.md            # Phase 7 Handoff Record (Executed & Verified)
    ├── CLINE_HANDOFF_PHASE8_RESUME.md     # Phase 8 Handoff Record (Executed & Verified)
    ├── CLINE_HANDOFF_PHASE9.md            # Phase 9 Handoff Record (Executed & Verified)
    ├── CLINE_HANDOFF_PHASE10.md           # Phase 10 Handoff Record (Executed & Verified)
    ├── CLINE_HANDOFF_PHASE11.md           # Phase 11 Handoff Record (Executed & Verified)
    ├── CLINE_HANDOFF_PHASE12.md           # Phase 12 Handoff Record (Executed & Verified)
    ├── CLINE_HANDOFF_PHASE12_1.md         # Phase 12.1 Handoff Record (Executed & Verified)
    ├── CLINE_HANDOFF_PHASE13.md           # Phase 13 Handoff Record (Executed & Verified)
    ├── CLINE_HANDOFF_PHASE14.md           # Phase 14 Handoff Record (Executed & Verified)
    ├── CLINE_HANDOFF_PHASE17.md           # Phase 17 Handoff Record (Executed & Verified)
    ├── CLINE_HANDOFF_PHASE18.md           # Phase 18 Handoff Record (Executed & Verified)
    ├── CLINE_HANDOFF_PHASE19.md           # Phase 19 Handoff Record (Executed & Verified)
    ├── CLINE_HANDOFF_PHASE20.md           # Phase 20 Handoff Record (Executed & Verified)
    ├── CLINE_HANDOFF_PHASE21.md           # Phase 21 Handoff Record (Executed & Verified)
    ├── CLINE_HANDOFF_PHASE22.md           # Phase 22 Handoff Record (Executed & Verified)
    ├── audits/                            # Audit Briefs & Prompts (Lead Architect authored)
    │   ├── TOP_BAR_NAVIGATION_AUDIT_PROMPT.md
    │   ├── BOTTOM_NAV_AND_AUDIO_TRANSPORT_AUDIT_PROMPT.md
    │   ├── STUDIO_AI_COCKPIT_AND_MPC_CHOPPER_AUDIT_PROMPT.md
    │   ├── TRACK_DETAIL_AND_STEM_SEPARATION_AUDIT_PROMPT.md
    │   └── EXPLORE_AND_HERITAGE_DISCOVERY_AUDIT_PROMPT.md
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
        ├── phase_17_song_dna_content_engine/ # Phase 17 5-doc suite (walkthrough included)
        └── phase_18_social_creator_network/ # Phase 18 5-doc suite (walkthrough included)

```

---

## 3. Engineering Phase Roadmap & Active Status

| Phase | Milestone Name | Status | Verified Deliverables |
|:---:|---|:---:|---|
| **0** | **SSOT Foundation Blueprints** | ✅ Complete | Blueprints 00 through 07 codified on disk in `docs/foundation_blueprints/`. |
| **1** | **Project Initialization & Design Tokens** | ✅ Complete | Created `apps/vhunambi_client`, installed ecosystem, codified theme tokens in `lib/core/theme/`. |
| **2** | **Core Shell & Persistent Audio Engine** | ✅ Complete | `PlayerState`, `PlayerNotifier`, `MobileMiniPlayer`, `DesktopTransportBar`, `ExpandedCockpitModal`, `GenerationPipelineCard`, `NotificationsPopover`. |
| **3** | **Studio Creation Cockpit (`/create`)** | ✅ Complete | Full parameter tree, `StudioFormNotifier`, 6 custom widgets, mounted in `RootShell`, **14 passing tests**. |
| **4** | **Library & User Asset Vault (`/library`)** | ✅ Complete | `LibraryTrack` vault model, 6-category rail with counts, search/sync filters, list & square-grid layouts, universal empty states, soft-delete Trash with restore/purge, contextual action sheet, licensing certificate dialog, mounted in `RootShell` tab 3. |
| **5** | **Explore Feed & Music Discovery** | ✅ Complete | 10-slice `CustomScrollView` (header/tabs/streak, charts banner, New This Week, Rising matrix, creator deck, 12-genre radio, filter engine, catalog, load-more), Ctrl+K search, playback bridge into the persistent player — mounted at `RootShell` tab 1. |
| **6** | **Beats Marketplace & Native App Architecture** | ✅ Complete | `/market`: beat listing grid + credit licensing flow (vault write) + filter sheet + PWA install dock. Native App Architecture: `SplashView` + 3-step `OnboardingView` (genre/language preferences) + `HomeDashboardView` on Tab 0 (greeting, prompt bar, 4 action tiles, Jump Back In mini-card, trending rail) + native `SubscriptionUpgradeModal`. |
| **7** | **Track Details & Creator Profiles** | ✅ Complete | `/track/:id` (1:1 art, ambient amber glow, royalty-free notice, waveform scrubber, lyrics teleprompter, 4-stem lab & FSM, cultural emoji deck, prompt attribution, comments, recommendations), `/profile/:id` (public artist profile, monogram, 5 stats, top supporters, top songs, recent activity), `/profile/me` (creator studio profile, releases manager, tip ledger, referral card). |
| **8** | **Hive Local Cache & Audio Offline Sync** | ✅ Complete | Offline audio persistence, dual Hive boxes (`vaultBoxKey`, `preferencesBoxKey`), streaming downloader FSM, storage quota modal, offline badges & player integration. |
| **9** | **Native Hardware Audio Bridge & Media Notifications** | ✅ Complete | Native platform audio sessions (`AudioSessionManager`), system lock-screen media notification controls (`VhunambiAudioHandler`), hardware media key listener, dynamic audio source resolver. |
| **10** | **Generation Pipeline Real-Time WebSocket Bridge** | ✅ Complete | Real-time synthesis WebSocket bridge (`GenerationSocketService`), multi-stage Result panel (`GenerationPipelineCard`), stem download orchestrator, notifications dispatch. |
| **11** | **Notifications Drawer & Real-Time Alert System** | ✅ Complete | Interactive notifications drawer/popover, unread counter badge (`NotificationBellButton`), deep-link routing on alert tap, backward-compatible `notificationsProvider`. |
| **12** | **Studio Lyrics Review Cockpit & Playlists Queue** | ✅ Complete | Subsystem A: Interactive lyrics review modal, cultural idiom injection, raw editor toggle, approve-to-beat handoff. Subsystem B: Full playlist CRUD, sliding `QueueDrawer` with reorderable upcoming queue, `AddToPlaylistSheet`. |
| **12.1** | **Playlists Vault & Local Persistence** | ✅ Complete | Dedicated Playlists tab in Library Vault (`/library?tab=playlists`), `PlaylistDetailView`, Hive persistent `PlaylistRepository` with headless test safety. |
| **13** | **Collections & EP/Album Concept Bundler** | ✅ Complete | Collections tab in Library Vault (`/library?tab=collections`), `CollectionEntity`/`SplitParticipant` domain, Hive `CollectionRepository`, `CollectionsVaultView` (2/3/4-col grid + list, create/rename/delete), `CollectionDetailView` (hero header, Play All/Shuffle, reorderable tracks, split-sheet ledger), `SplitSheetModal` with clipboard export. |
| **14** | **Producer Beats Vault & Beatstore Listing Cockpit** | ✅ Complete | `/library?tab=beats`: `ProducerBeatEntity` / `BeatStemPackage` / `BeatSaleRecord` domain, Hive `BeatRepository`, `beatsProvider`, `BeatsVaultView`, `BeatDetailCockpitView`. |
| **15** | **Full-Stack Autonomous Backend & Pipeline Bridge** | ✅ Complete | Colocated `apps/vhunambi_api` (Node.js/Hono): Bantu dialect prompt compiler, story-to-lyrics LLM engine, Cloudflare R2 presigned storage, ACE-Step GPU adapter & simulation worker, `/health` observability. Client: `HttpLyricsGenerationService`, `HttpGenerationSubmissionService`, live 4-stage pipeline FSM card, master auto-play, and stem download bridge. |
| **16** | **Live Cloud & GPU Infrastructure Integration** | ✅ Complete | RunPod Serverless ACE-Step 1.5 adapter aligned to upstream `handler.py` schema, Cloudflare R2 audio storage (`vhunambi-audio`), HMAC-SHA256 authenticated webhook gateway (`POST /v1/webhooks/ace-step`), `WEBHOOK_BASE_URL` tunnel configuration, Flutter `TrackEntity` stems degradation, and comprehensive integration test suite. |
| **17** | **Song Metadata DNA & Lyric Video Content Engine** | ✅ Complete | Headless RunPod ComfyUI 9:16 Vision adapter (768×1344), prompt synthesizer, SongMetadataDna domain & compiler, Flutter Content Studio Dock (60 FPS kinetic preview canvas, 4 typography styles, duration trimmer, atmospheric overlays, MP4 export, genre-aware smart defaults, post-generation & vault entrypoints). |
| **18** | **Social Creator Network & In-House Discovery** | ✅ Complete | Backend API: `/v1/social/clips`, `/v1/social/feed`, `/v1/social/clips/:id/metrics`. Client: `PublishedClip` domain, Riverpod `SocialFeedNotifier`, `OwnerReelsGrid`, `ArtistReelsGrid`, full-screen swipeable `KineticReelsModal` with video/cover background, waveform scrubbing, love bursts, and copy-link sharing. |
| **19** | **Trending Kinetic Reels Discovery & TikTok Community Engagement** | ✅ Complete | `TrendingReelsShelf` & `TrendingReelCard` mounted in `HomeDashboardView` and `ExploreView` with genre filtering pills (`kTrendingGenres`), TikTok-style `ReelsCommentSheet` with 1-tap cultural reaction emoji badges (🔥, 👑, 🇿🇦, 🎹, 🐐), honest community love counter, and quick praise comments. |
| **20** | **Bantu Voice LoRA Engine & Creator Cultural Micro-Gifting** | ✅ Complete | Track A: 5 native African singer timbres (👴 Venda Elder, 🎤 Soweto Soul, ⚡ Durban Gqom, 🌿 Maskandi Bard, ✨ Limpopo Queen), 4 dialect inflection sliders, and `LivePhoneticAlignmentPreview`. Track B: `CreatorTippingSheet` on reel action rail, 4 cultural micro-gifts (🐚 Cowrie, 🥁 Drum, 🎹 Log Drum Trophy, 👑 Crown), auto-posted supporter announcements, and `CreatorWalletDeck` with ZAR cashout rails (Ozow, Capitec Pay, EFT). |
| **21** | **Audio-Stem Social Remixing & Pocket 4-Channel Stem Mixer** | ✅ Complete | Track A: "Remix This Reel" creation branching on `KineticReelsModal` action rail, `StemRemixContext` stem extraction, and `RemixAttributionBadge` lineage pill. Track B: `StemMixerDeck` pocket 4-channel DAW console (Vocals 🎤, Drums 🥁, Log Drum 🎹, Melody 🎸), vertical gain faders, pan sliders, M/S buttons, 4-parameter Master Bus DSP with Amapiano/Maskandi/Duet presets, and 1-Tap Master Mix Bounce to `/vault/bounces/`. |
| **22** | **Heritage Crate Digging & Native Hardware Video Muxer** | ✅ Complete | Track A: `CrateBrowserDeck` with 3D-inspired spinning vinyl and 6 authentic indigenous African instruments (Mbira, Kora, Talking Drum, Marimba, Uhadi Bow, Venda Chants), plus 8-Pad AI `MpcSlicerDeck` with transient beat-slicing, semitone pitch modulation (−12..+12), reverse playback, and chop kit bounce. Track B: `VideoExportModal` hardware video renderer (1080×1920 9:16 and 1080×1080 1:1 @ 60 FPS), holographic animated watermark toggle, viral caption generator (`#Amapiano #Vhunambi #Afrobeats`), and 1-Tap `SocialShareRail` for TikTok, Instagram Reels, YouTube Shorts, and Camera Roll. |
| **M1–M5** | **Full-Stack UI/UX Modernization Sprint** | ✅ Complete | **Audit-Then-Improve** dual-agent protocol applied to 5 core systems: Top Bar Navigation (frosted surfaces, `VhunambiTopBarMetrics`, scroll-aware title), Bottom Dock & Audio Transport (`VhunambiBottomDockMetrics`, drag-to-expand, unified scroll insets), Studio AI Cockpit (`IndexedStack` zero-unmount switcher, frosted heritage modal), Track Details (frosted app bar, frosted stem mixer modal), Explore Discovery Feed (44px responsive touch geometry, viewport-safe layout). **805/805 tests · 0 analyzer warnings**. See [`docs/VHUNAMBI_MODERNIZATION_CHRONICLE.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_MODERNIZATION_CHRONICLE.md). |

---

## 4. Verification Health Check

### Client (`apps/vhunambi_client`)
```powershell
cd apps/vhunambi_client

# 1. Static Analysis Gate (0 issues)
flutter analyze apps/vhunambi_client

# 2. Automated Test Suite (805 passing)
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
2. Phases 0 through 22 are **fully executed, verified, and passing**. The Full-Stack UI/UX Modernization Sprint (M1–M5) is also complete.
3. Latest engineering records:
   - **Phase 22 Handoff:** [`docs/CLINE_HANDOFF_PHASE22.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/CLINE_HANDOFF_PHASE22.md)
   - **Modernization Chronicle:** [`docs/VHUNAMBI_MODERNIZATION_CHRONICLE.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_MODERNIZATION_CHRONICLE.md)
   - **Workflow Standard:** [`docs/DUAL_AGENT_AUDIT_IMPROVE_WORKFLOW.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/DUAL_AGENT_AUDIT_IMPROVE_WORKFLOW.md)
4. Both workspaces are clean with zero errors across tests and static analysis.
