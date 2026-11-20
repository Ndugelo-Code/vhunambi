# Vhunambi Monorepo Topology, Agent Infrastructure & Codebase Memory Readiness Audit

**Document ID:** `AUDIT-ARCH-MEMORY-001`  
**Date:** 2026-11-19  
**Branch / HEAD:** `fix/studio-cockpit-bugs-vh001-vh006` (`bf7ca98` — `feat(explore,social): Phase 69 Kinetic Post focus domain, threaded replies, API/schema overhaul & docs`)  
**Audit Scope:** Read-only forensic inspection of the Vhunambi monorepo structure, git history, Antigravity rules/skills/global config, `docs/` volume & drift, backend API routes, and client cross-cutting primitives (`OPEN` vs. `CONNECTED_EXTENSIBLE` endpoint readiness).  
**Related References:** [`README.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/README.md) · [`docs/AGENT_HANDOFF_BIBLE.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/AGENT_HANDOFF_BIBLE.md) · [`docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md)

---

## 1. Executive Summary & Repo Health Snapshot

Vhunambi has scaled to **497 Dart source files** + **228 Dart test files** in `apps/vhunambi_client`, **56 TypeScript source files** + **24 test suites** in `apps/vhunambi_api`, **8 Python scripts/worker modules** in `tools/`, and **397 markdown specification/audit/handoff files totaling 122,875 physical lines** (`split(/\r?\n/).length`, including `README.md` and `docs/`).

While the Tri-Skill engineering pipeline (`vhunambi-forensic-auditor` $\to$ `vhunambi-spec-architect` $\to$ `vhunambi-executioner`) enforces high architectural fidelity *inside* a single phase, cross-session continuity currently depends on manual linear reading of [`docs/AGENT_HANDOFF_BIBLE.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/AGENT_HANDOFF_BIBLE.md) (`1,963` lines) or browsing **74 folders** under `docs/phases/` (`99,164` lines). There is **no workspace rules folder (`.agents/rules/`)**, no machine-readable endpoint registry, and no Wake/Active/Sleep memory protocol.

### Headline Repository Snapshot (Verified from Disk)

| Dimension | Verified State | Evidence / Notes |
| :--- | :--- | :--- |
| **Git Branch & HEAD** | `fix/studio-cockpit-bugs-vh001-vh006` @ `bf7ca98` | Clean working tree at audit start (`git status --short` empty). |
| **Highest Implemented Phase** | **Phase 69** (Kinetic Post Focus Domain & Threaded Replies) | `docs/phases/phase_69_kinetic_post_focus_and_threading_overhaul/` (`9/9` tasks `[x]`). Also includes un-numbered **"Phase 68.5" Cinema Splash Screen (`Madoni Software`)** implemented in [`splash_view.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/onboarding/presentation/views/splash_view.dart#L17-L20). |
| **Root Instruction Files** | **None at monorepo root** | `AGENTS.md`, `GEMINI.md`, `.antigravityrules`, `CLAUDE.md`, `.cursorrules`, and `.agent/` are all absent at root. |
| **Workspace `.agents/` Surface** | **3 skills only** (`vhunambi-forensic-auditor`, `vhunambi-spec-architect`, `vhunambi-executioner`) | Zero `.agents/rules/` and zero `.agents/workflows/` exist today. Zero-token Node/Python hooks can drop straight into `.agents/rules/` + `.agents/skills/vhunambi-memory/`. |
| **Global `~/.gemini/` State** | `~/.gemini/GEMINI.md` (`14` lines) + `mcpServers: [runpod]` | `~/.gemini/GEMINI.md` contains unrelated **Zania Next.js/React** styling rules (`lib/motion-config.ts`, `app/globals.css`). `~/.gemini/config/rules`, `~/.gemini/config/skills`, and `~/.gemini/antigravity/rules` do not exist. |
| **Available Script Runtimes** | **Node `v24.14.0`**, **Python `3.12.5`**, **PowerShell `7.4.22`** | Root monorepo has no `package.json` (`apps/vhunambi_api/package.json` owns Node/TS scripts). Zero-dependency Node `.mjs` scripts (`node .agents/skills/...`) work natively anywhere in the repo. |
| **Top Context-Loss Bottlenecks** | 1. **122,875 lines** of markdown across `docs/` (`74` phase folders)<br>2. **14+ backend API endpoints** sitting `OPEN` with zero Dart callers (e.g., all 5 Phase 67 `/api/notifications*` routes)<br>3. **No dependency graph** linking shared primitives (`VhunambiTrackArtwork`, `ThreadedCommentsSection`, `Mood`, `ViewerRole`) to remaining legacy screens (`TrackDetailView`, `ArtistProfileView`) | Full analysis in Sections 4 and 5 below. |

---

## 2. Complete Monorepo & Feature Map

### 2.1 Top-Level Workspace Topology (`c:\Users\Ndugelo\VHUNAMBI\monorepo\`)

```text
c:\Users\Ndugelo\VHUNAMBI\monorepo\
├── .agents\
│   └── skills\                          # 3 workspace skills (6 files total); NO rules/ or workflows/ yet
├── .github\workflows\                   # deploy_api.yml, push_gpu_worker.yml
├── .kiro\                               # Legacy IDE specs (6 spec folders under .kiro/specs/, empty .kiro/settings/)
├── apps\
│   ├── vhunambi_api\                    # Hybrid Node.js + Cloudflare Workers (workerd) Hono API
│   └── vhunambi_client\                 # Flutter/Dart cross-platform client (497 lib Dart files, 228 test files)
├── docs\                                # 397 files, 122,693 lines (30 audits, 74 phase folders, 45 root docs, etc.)
├── scratch\                             # Scratch directory
├── supabase\migrations\                 # 3 sequential PostgreSQL SQL migrations
├── tools\                               # zr-studio-gpu (RunPod Python worker) + slice_assets.py
├── .gitignore
└── README.md                            # 182 lines
```

### 2.2 Flutter Client (`apps/vhunambi_client/`)

* **Root Manifest:** `pubspec.yaml` (no `package.json` at client or repo root).
* **Core Subsystems (`apps/vhunambi_client/lib/core/` — 13 folders, 66 files):**
  * `accessibility` (`6`), `auth` (`4`), `cache` (`3`), `constants` (`3`), `design_system` (`14`), `navigation` (`2`), `network` (`5`), `resilience` (`3`), `storage` (`5`), `sync` (`2`), `theme` (`6`), `utils` (`3`), `widgets` (`6`).
* **Feature Modules (`apps/vhunambi_client/lib/features/` — 21 folders, 429 feature files + `main.dart` + barrel files = 497 total `lib/*.dart`):**
  * `auth` (`1`), `beats` (`15`), `collections` (`15`), `content_studio` (`17`), `creator_dna` (`14`), `explore` (`23`), `home` (`15`), `landing` (`13`), `library` (`13`), `marketplace` (`19`), `mastering` (`4`), `notifications` (`17`), `offline` (`7`), `onboarding` (`13`), `player` (`27`), `playlists` (`9`), `profile` (`41`), `social` (`29`), `sound_signature` (`38`), `studio` (`87`), `track` (`15`).
* **Verification Suite:** `228` `.dart` test files under `apps/vhunambi_client/test/`.

### 2.3 Backend API (`apps/vhunambi_api/`)

* **Runtime Entrypoints:** [`src/index.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/index.ts) (Node.js server), [`src/worker.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/worker.ts) (Cloudflare Worker + `GenerationSessionDO`), [`src/server.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/server.ts) (shared Hono router mounts).
* **Database & Persistence Layer (`src/db/`):**
  * [`vhunambi_db.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/db/vhunambi_db.ts) (lazy `node:sqlite` WAL driver with `isNodeSqliteAvailable()` guard)
  * [`edge_persistence_bridge.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/db/edge_persistence_bridge.ts) (volatile isolate store for Cloudflare Workers `workerd`)
  * [`supabase_cloud_driver.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/db/supabase_cloud_driver.ts) (PostgREST/Supabase client — currently wired primarily in `auth_routes.ts`)
* **Routes (`src/routes/` — 17 route files):**
  * [`auth_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/auth_routes.ts), [`explore_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/explore_routes.ts), [`generation_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/generation_routes.ts), [`library_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/library_routes.ts), [`lyrics_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/lyrics_routes.ts), [`marketplace_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/marketplace_routes.ts), [`melody_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/melody_routes.ts), [`notification_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/notification_routes.ts), [`payment_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/payment_routes.ts), [`playlist_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/playlist_routes.ts), [`social_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/social_routes.ts), [`sync_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/sync_routes.ts), [`system_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/system_routes.ts), [`vision_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/vision_routes.ts), [`voice_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/voice_routes.ts), [`wallet_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/wallet_routes.ts), [`webhook_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/webhook_routes.ts).
* **Domain Modules (`src/modules/` — 11 subfolders):** `bantu`, `dna`, `jobs`, `lyrics`, `marketplace`, `mastering`, `melody`, `realtime`, `social`, `synthesis`, `vision`, `voices` (12 subfolders total).
* **Test Hygiene Observation:** [`apps/vhunambi_api/package.json`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/package.json) runs **23** sequential `tsx test/*.test.ts` suites, whereas `apps/vhunambi_api/test/` actually contains **24** `.test.ts` files (`phase65_foundation_resilience.test.ts` is omitted from `npm test`) AND a stray [`src/phase67_notifications_quota.test.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/phase67_notifications_quota.test.ts) sits inside `src/` rather than `test/`.

### 2.4 Database Migrations (`supabase/migrations/`) & GPU Tools (`tools/`)

* **Supabase Migrations (chronological):**
  1. [`20261110000001_phase62_hybrid_cloud_schema.sql`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/supabase/migrations/20261110000001_phase62_hybrid_cloud_schema.sql) (base 19-table PostgreSQL schema)
  2. [`20261116000001_phase67_notifications_and_quotas.sql`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/supabase/migrations/20261116000001_phase67_notifications_and_quotas.sql) (notifications table & `10` free monthly songs quota columns)
  3. [`20261118000001_phase69_kinetic_posts_and_threaded_comments.sql`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/supabase/migrations/20261118000001_phase69_kinetic_posts_and_threaded_comments.sql) (`kinetic_posts.(like_count, comment_count)` & `reel_comments.(parent_comment_id, reply_to_handle)`)
* **Tools (`tools/`):**
  * `tools/zr-studio-gpu/`: `Dockerfile`, `Dockerfile.delta`, `handler.py`, `model_utils.py`, `mmo_extractor.py`, `seed_vc_worker.py`, `stem_mastering_worker.py`, `requirements.txt`, `README.md`.
  * `tools/slice_assets.py`.

### 2.5 Recent Git History (`git log -n 15 --oneline`)

* `bf7ca98` — Phase 69 Kinetic Post focus domain, threaded replies, API/schema overhaul & docs
* `baa613e` — Phase 67 notifications & 10-song quota engine + Phase 68 Main Room overhaul
* `f87b38c` — Update `AGENT_HANDOFF_BIBLE` Section 42 & GPU README for Phase 66 / `vhunambi-v3`
* `c70fcde` — Fix Studio `VH001`–`VH006`, ACE-Step lyric sanitizer, Chinese vocal guard, `-14 LUFS` mastering
* `852bb3d` / `57d9d39` / `0b2507d` — Phase 65 foundation fault-containment & RunPod GPU CI workflow
* `36cc83a` — Phase 64 cloud production pipeline, hardware audio bootstrap, R2 synthesis & ACE-Step LoRA

---

## 3. Antigravity Skills, Rules & Workflows Architecture Map

### 3.1 Workspace `.agents/` & Legacy `.kiro/` Inventory

| Location | Contents | Trigger / Status |
| :--- | :--- | :--- |
| [`.agents/skills/vhunambi-forensic-auditor/SKILL.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/.agents/skills/vhunambi-forensic-auditor/SKILL.md) (`229` lines) + `references/FORENSIC_AUDIT_CHECKLIST_AND_TAXONOMY.md` (`71` lines) | Stage 1 & Stage 5 forensic codebase/device audit engine producing `docs/audits/<NAME>_AUDIT.md`. | **Active** — model-matched or `/vhunambi-forensic-auditor`. |
| [`.agents/skills/vhunambi-spec-architect/SKILL.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/.agents/skills/vhunambi-spec-architect/SKILL.md) (`123` lines) + `references/FORENSIC_SPEC_CHECKLIST.md` (`37` lines) | Stage 2 & Stage 3 4-doc phase suite author/hardener enforcing 6 Anti-Bait-and-Switch Laws. | **Active** — model-matched or `/vhunambi-spec-architect`. |
| [`.agents/skills/vhunambi-executioner/SKILL.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/.agents/skills/vhunambi-executioner/SKILL.md) (`134` lines) + `references/STAGE4_EXECUTION_VERIFICATION_CHECKLIST.md` (`40` lines) | Stage 4 deterministic executioner enforcing 8 Execution Laws (`tasks.md` `[x]` updates, `--timeout=60s`). | **Active** — model-matched or `/vhunambi-executioner`. |
| `.agents/rules/` | **DOES NOT EXIST** | Ready to host tiny always-on `vhunambi-memory-steering.md`. |
| `.agents/workflows/` | **DOES NOT EXIST** | Zero legacy workflow files needing migration. |
| `.kiro/specs/` (`adaptive-mini-player`, `cross-cutting-design-system`, `notifications-modernization`, `onboarding-modernization`, `profile-ux-enhancement`, `studio-cockpit-fixes`) | Historical Kiro spec folders (pre-Antigravity standardization; `.kiro/settings/` is empty). | **Legacy archive** (read-only historical specs). |

### 3.2 Global `~/.gemini/` Inspection (Metadata Only)

* **`~/.gemini/GEMINI.md` (`14` lines):** Contains unrelated Next.js/React rules (`lib/motion-config.ts`, `HYDRATION_SAFE_VARIANTS`, `app/globals.css`, `.zania-scrollbar`). Because it sits globally at user root, it injects Next.js instructions into Vhunambi turns unless overridden/ignored by workspace rules.
* **`~/.gemini/config/rules/`, `~/.gemini/config/skills/`, `~/.gemini/antigravity/rules/`:** Do not exist.
* **MCP Servers:** `runpod` configured in `~/.gemini/config/mcp_config.json`.
* **`~/.gemini/antigravity/knowledge/`:** Contains `knowledge.lock` only.

### 3.3 Current Inter-Skill Handoff & Context-Loss Insertion Map

```text
  [STAGE 1: vhunambi-forensic-auditor]
     |-- Output: docs/audits/<NAME>_AUDIT.md
     |-- GAP ON REFRESH: Auditor must grep all apps/ & docs/ manually; blind to earlier OPEN routes (e.g. Phase 67 /api/notifications)
     v
  [STAGE 2 & 3: vhunambi-spec-architect]
     |-- Output: docs/phases/phase_XX_<name>/{blueprint,requirements,design,tasks}.md  (1,800-3,500+ lines)
     |-- GAP ON REFRESH: Writes 4 heavy docs with NO 5th memory.md summary; no Concept Hub index of distant relatives
     v
  [STAGE 4: vhunambi-executioner]
     |-- Output: Code in apps/ + tools/ + [x] in tasks.md + optional README/BIBLE prose update
     |-- GAP ON REFRESH: Prose in AGENT_HANDOFF_BIBLE.md reaches 1,963 lines; Phase 65 & 66 status/tasks drift
```

**Natural Insertion Points for `vhunambi-memory`:**
1. **Wake Hook (`always_on` rule in `.agents/rules/vhunambi-memory-steering.md`, `< 1 KB`):** Triggers before Stage 1, 2, or 4 starts $\to$ reads `docs/memory/CORTEX_INDEX.md` (`< 4 KB`) + runs `node .agents/skills/vhunambi-memory/scripts/query_connectome.mjs --hubs ...`.
2. **Active Spec Hook (`vhunambi-spec-architect`):** Requires drafting `memory.md` (`status: draft`) listing consumed endpoint IDs and new endpoint IDs created.
3. **Sleep & Dream Hook (`vhunambi-executioner` post-gate):** Updates `memory.md` to `status: completed` *only after* `flutter analyze` / `tsc --noEmit` / tests pass, then runs `node .agents/skills/vhunambi-memory/scripts/consolidate_memory.mjs` to update `CONNECTOME_GRAPH.json`, flip claimed `OPEN` endpoints to `CONNECTED_EXTENSIBLE`, regenerate `CORTEX_INDEX.md`, and emit the **Open & Distant Synergy Ripple Report**.

---

## 4. Documentation Drift & Context-Cost Matrix

### 4.1 Exact Documentation Volume (`docs/` + `README.md`)

| Location | File Count | Physical Lines | Purpose & Context Cost Assessment |
| :--- | :---: | :---: | :--- |
| `docs/phases/` (**74** folders) | `320` | **`99,164`** | **Primary context killer.** Average ~`1,340` lines/folder; recent overhauls (`phase_56`, `phase_57`, `phase_58`, `phase_62`, `phase_67`, `phase_68`, `phase_69`) average **`3,000–5,257` lines each**. |
| `docs/*.md` (Root `docs/`) | `45` | **`10,240`** | Includes `AGENT_HANDOFF_BIBLE.md` (`1,963`), `VHUNAMBI_MODERNIZATION_CHRONICLE.md` (`785`), `CLINE_HANDOFF_*` (`28` legacy handoff docs), and `session-resume-*` (`4` files). |
| `docs/audits/` | `30` | **`8,381`** | Pre-spec forensic audits & prompt docs (`192–582` lines each). |
| `docs/foundation_blueprints/` | `9` | **`3,255`** | Baseline specs `00`–`07` + addendum. |
| `docs/bantu_intelligence_suite/` | `5` | **`846`** | Linguistic & prompt rules. |
| `docs/blueprints/` | `2` | **`616`** | Feature blueprints. |
| `docs/standards/` | `1` | **`213`** | UI/UX / coding standards. |
| `README.md` (Repo Root) | `1` | **`182`** | Executive roadmap & live standings. |
| **TOTAL TRACKED DOCS** | **`413`** | **`122,897`** | *(Plus 6 legacy `.kiro/specs/` folders).* Reading even `10%` burns tens of thousands of tokens per session. |

*(Note: `PHASE69` added `3,401` lines across `blueprint.md`, `requirements.md`, `design.md`, `tasks.md` + `292` lines in `PHASE69_KINETIC_POST_FOCUS_AND_THREADING_AUDIT.md`.)*

### 4.2 Structural Irregularities & Drift Audit Findings

| Defect / Drift Category | Exact Evidence on Disk | Concrete Impact |
| :--- | :--- | :--- |
| **1. Stale `main.dart` Audio Claim in Client README** | [`apps/vhunambi_client/README.md#L33`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/README.md#L33) still states *"Global MiniPlayer (`audioHandlerProvider`) currently defaults to headless `TestVhunambiAudioHandler` because `bootstrapPlatformAudioHandler` is not overridden... in `lib/main.dart`"*, even though [`lib/main.dart#L60-L70`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/main.dart#L60-L70) ALREADY overrides `audioHandlerProvider.overrideWithValue(audioHandler)` with `bootstrapPlatformAudioHandler()`. | Misleads future agents into "re-fixing" a solved Phase 64/65 bug instead of diagnosing hardware `ExoPlayer` / test harness failures accurately. |
| **2. Missing Phase Spec Folders for Implemented Code (`P66`, `P68.5`)** | `docs/phases/` skips **`phase_28`**, **`phase_66`**, and **`phase_70`** (`74` folders total, including duplicate numbers `phase_33_*` $\times 2$, `phase_34_*` $\times 2$, `phase_35_*` $\times 2$, and 4 un-numbered legacy folders: `adaptive-mini-player`, `creator-dna-adaptive-intelligence`, `notifications-modernization`, `profile-ux-enhancement`, `studio-ai-cockpit-v2` — 5 non-`phase_XX` folders). Meanwhile **Phase 66** (`c70fcde`) and **"Phase 68.5" Madoni Software Cinema Splash** ([`splash_view.dart#L17-L20`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/onboarding/presentation/views/splash_view.dart#L17-L20)) shipped directly to code with zero `docs/phases/` folder. | A future session scanning `docs/phases/` misses Phase 66 audio/lyric hygiene and Phase 68.5 Madoni Splash branding completely. Only a `memory.md` / `CONNECTOME_GRAPH.json` entry catches un-spec'd sprints. |
| **3. Non-Checkbox `tasks.md` in Phase 65** | [`phase_65_foundation_stability_and_fault_containment/tasks.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_65_foundation_stability_and_fault_containment/tasks.md#L360-L404) tracks implementation via a markdown table (`0` `[x]` / `0` `[ ]` task checkboxes) despite Stage 4 code (`VhunambiCrashShield`, `SafeAudioOrchestrator`, `SafeNotifierMixin`, `SafeNetworkAvatar`, `JsonSafe`) being live across 3–6 files each. | Automated scripts scanning `tasks.md` for `- [ ]` vs `- [x]` falsely assume Phase 65 has 0 progress unless normalized via `memory.md` `status: completed`. |
| **4. Root `VHUNAMBI_AGENT_WORKFLOW_STANDARD.md` Link Typo** | [`docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md#L7`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md#L7) links to `vhunambi_spec_architect` (underscore) whereas the real folder is `.agents/skills/vhunambi-spec-architect` (hyphen). It also still models a 4-doc standard (`blueprint`, `requirements`, `design`, `tasks`) with no `memory.md` 5th doc. | Must be updated when introducing `memory.md` as the 5th canonical phase document. |
| **5. Phase 69 Test Debt vs Unrelated Pre-existing Failures** | Phase 69 `tasks.md` `69.1.1`–`69.4.3` (`9/9`) are `[x]`, `flutter analyze` = `0 issues`, Backend = `23/23` suites (`0` TS errors), Explore/Social/Notifications = `183/183` passed. However, `11` pre-existing unrelated client test failures remain in `core/network`, `player`, `studio`, `track`, and `social/reel_audio_pool_and_kinetic_canvas_test.dart`, and `apps/vhunambi_api/test/phase65_foundation_resilience.test.ts` is excluded from `npm test`. | Future `vhunambi-memory` sessions must distinguish live baseline health from pre-existing unrelated test debt. |

---

## 5. Initial Connectome Seed Table (`OPEN`, `CONNECTED_EXTENSIBLE` & `SEALED`)

This seed inventory is extracted directly from live imports, URL calls, and route definitions across `apps/vhunambi_client/lib/` and `apps/vhunambi_api/src/routes/` so `CONNECTOME_GRAPH.json` and `CORTEX_INDEX.md` can be seeded with **zero speculation**.

### 5.1 Proposed Fixed Concept Hubs (`CONCEPT_HUBS.md`)

1. `#identity_role` — Auth (`SovereignAuthRepository`), canonical IDs (`CreatorIdUtils`), Owner vs. Visitor permissions (`ViewerRole`), repost attribution (`ownerProfileProvider`).
2. `#media_artwork` — Bundled artwork resolver (`AppAssets.resolveGenreCoverAsset`), `VhunambiTrackArtwork`, `SafeNetworkAvatar`, R2 vault streaming (`/r2/:key`), Vision/splash branding (`Madoni Software`).
3. `#quota_economy` — `10 Free Monthly Songs` quota (`GET /api/wallet/allowance`, `CreatorAllowanceNotifier`), Beatstore licensing, Coin Top-Up, PayFast ITN, creator payouts & banks.
4. `#audio_transport` — `SafeAudioOrchestrator` mutex, `VhunambiAudioHandler` (`bootstrapPlatformAudioHandler`), `JustAudioMultiStemEngine`, `ReelAudioPoolService`, `MiniPlayerHost` Tab-0 suppression (`homeInlineNowPlayingMountedProvider`).
5. `#mood_taxonomy` — **Currently fragmented**: Studio `Mood` enum ([`design_enums.dart#L33-L48`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/core/design_system/tokens/design_enums.dart#L33-L48)) + `StudioFormNotifier.setMood` vs. Explore free-string `exploreMoodFilterProvider` vs. Track `mood` strings.
6. `#social_graph` — Kinetic Posts (`SocialMusicPost`), `KineticPostFocusView`, `ThreadedCommentsSection`, `StudioReactionComposerBar`, `ReelsCommentSheet`, `Follow` & `Co-Sign` graduation, `RemixLineageTree`.
7. `#notifications_bus` — `NotificationsNotifier`, `OnboardingNotificationsService`, `NotificationBellButton` (5 consumers), `NotificationDetailBottomSheet`, `NotificationDeepLinkRouter` (`/post/:id`, `/track/:id`, etc.), **and unwired `/api/notifications*` backend**.
8. `#sync_outbox` — `SovereignHiveBootstrapService` (26 AES-256 boxes), `EdgeSyncCoordinator` (`/api/sync/mutations`, `/delta`), `applyMutationsBatch` in SQLite/Edge, `JsonSafe`, `SupabaseCloudDriver` (currently auth-only in Worker).
9. `#ui_surface_std` — `STD-UIUX-001` (zero raw Unicode emojis, Phosphor icons, `*Of(context)` dual-theme adapters, `44x44dp` touch targets), `VhunambiTopBarKit`, `VhunambiBottomDockKit`.
10. `#ai_synthesis_gpu` — Prompt compiler (`buildAceStepStyleTags`), `LyricsSanitizer`, Latin phonetic guard, RunPod `ACE-Step 1.5` & `Demucs`, `-14.0 LUFS` mastering, Vision video render (`/v1/vision/render-video`).

---

### 5.2 Seed `OPEN` Backend & Unwired Endpoints Queue (Built, Zero Client HTTP Callers Yet)

| Endpoint ID | Route / Primitive & Source Location | Origin Phase | Hubs | Why It Is `OPEN` & Immediate Opportunity |
| :--- | :--- | :---: | :--- | :--- |
| **`EP-P67-NOTIF-API`** | `GET/POST /api/notifications`, `PATCH /:id/read`, `POST /mark-all-read`, `DELETE /:id` ([`notification_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/notification_routes.ts)) | `P67` | `#notifications_bus`, `#sync_outbox` | Built in Phase 67 M67.4; **zero HTTP callers** in `apps/vhunambi_client/lib/features/notifications/` (client uses local Hive `NotificationRepository` only). Ready to wire cross-device notification cloud sync. |
| **`EP-P69-POST-COSIGN-REPOST-HTTP`** | `POST /api/explore/posts/:id/cosign`, `POST /api/explore/posts/:id/repost`, `POST /api/explore/comments/:id/like`, `GET /api/explore/feed` ([`explore_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/explore_routes.ts)) | `P69` | `#social_graph`, `#sync_outbox` | Mounted on backend in Phase 69/59; `HttpExploreRepository` calls `/explore`, `/tracks`, `/radio`, `/posts/:id`, `/posts`, `/posts/:id/like`, and `/posts/:id/comments`, leaving `/cosign`, `/repost`, `/explore/comments/:id/like`, and `/explore/feed` without direct HTTP callers (currently rely on `EdgeSyncCoordinator` outbox or `/social/comments/:id/like`). |
| **`EP-P66-LYRICS-REFINE-STORY`** | `POST /v1/lyrics/refine`, `POST /v1/lyrics/story-transform` ([`lyrics_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/lyrics_routes.ts)) | `P12/P66` | `#ai_synthesis_gpu`, `#mood_taxonomy` | `HttpLyricsGenerationService` only calls `/v1/lyrics/generate`. Line-level AI lyric refine & story-to-lyrics transform endpoints sit `OPEN` for Studio Lyrics Review upgrades. |
| **`EP-P27-MELODY-PRESETS-PACKS`** | `GET /v1/melodies/presets`, `GET /v1/melodies/sound-packs` ([`melody_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/melody_routes.ts)) | `P27` | `#audio_transport`, `#ai_synthesis_gpu` | `PreGenR2UploadService` calls `POST /v1/melodies/render-reference`; preset & sound-pack discovery endpoints have zero client callers. |
| **`EP-P26-VOICE-CALIBRATION-RECIPE`** | `POST /v1/voices/extract-calibration`, `PATCH /v1/voices/signatures/:id/recipe` ([`voice_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/voice_routes.ts)) | `P26/P35` | `#ai_synthesis_gpu`, `#identity_role` | Mounted on backend with zero client HTTP callers (`PreGenR2UploadService` calls `/clone`, `/signatures`, and `/signatures/:id/analyze`). |
| **`EP-P25-GEN-MASTER-PRESETS`** | `GET /v1/generations/mastering/presets`, `GET /v1/generations/:id/manifest` ([`generation_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/generation_routes.ts)) | `P25/P63` | `#ai_synthesis_gpu`, `#audio_transport` | Zero client HTTP callers (`MasteringSessionProvider` calls `/v1/generations` & `/master` directly). |
| **`EP-P58-MKT-VERIFY-PRODUCER`** | `GET /api/marketplace/licenses/verify/:certificateId`, `GET /licenses/:buyerId`, `GET /producers/:producerId/beats` ([`marketplace_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/marketplace_routes.ts)) | `P58` | `#quota_economy`, `#identity_role` | Built for public SHA-256 certificate verification & visitor producer catalogs (`ArtistProfileView` Beatstore tab!); currently **0 client HTTP callers** (`HttpMarketplaceRepository` only calls `/beats`, `/beats/:id`, `/beats/:id/license`). |
| **`EP-P37-REMIX-TREE-API`** | `GET /api/social/clips/:id/remixes` ([`social_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/social_routes.ts)) | `P37` | `#social_graph` | Zero client HTTP callers (`HttpSocialRepository` never queries `/remixes`; `RemixLineageTreeSheet` runs locally). |
| **`EP-P41-WALLET-DIRECT`** | `GET /api/wallet/:creatorId`, `POST /api/wallet/topup` ([`wallet_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/wallet_routes.ts)) | `P41/P61` | `#quota_economy` | Client uses `/api/creators/:id/wallet`, `/api/wallet/allowance`, and `/api/payments/payfast/*`; direct `/api/wallet/:creatorId` & `/topup` routes have zero client callers. |

---

### 5.3 Seed `CONNECTED_EXTENSIBLE` Shared Primitives & Cross-Phase Contracts

| Endpoint / Primitive ID | Definition File | Current Consumers (Disk Verified) | Hubs | Future Phase Opportunity (e.g. Phase 70+) |
| :--- | :--- | :--- | :--- | :--- |
| **`EP-P68-TRACK-ARTWORK`** | [`vhunambi_track_artwork.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/core/widgets/vhunambi_track_artwork.dart) | **4:** `KineticPostFocusView`, `ExploreSocialPostCard`, `HorizontalGenreTrackShelf`, `NowPlayingHomeCard` | `#media_artwork`, `#ui_surface_std` | **Not yet adopted** in [`track_detail_view.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/track/presentation/views/track_detail_view.dart) (`uses: false`, `6` stock `Icons.*`) or [`artist_profile_view.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/profile/presentation/views/artist_profile_view.dart) (`uses: false`, `10` stock `Icons.*`). Prime target for **Phase 70**. |
| **`EP-P69-THREADED-COMMENTS`** | [`threaded_comments_section.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/social/presentation/widgets/threaded_comments_section.dart) | **2:** `KineticPostFocusView`, `ReelsCommentSheet` | `#social_graph`, `#ui_surface_std` | Reusable `ThreadedCommentsSection` + `StudioReactionComposerBar` ready to drop directly into **`TrackDetailView`** (`uses: false` today!). |
| **`EP-P69-KPOST-FOCUS-ROUTE`** | [`kinetic_post_focus_view.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/explore/presentation/views/kinetic_post_focus_view.dart) | **2:** `ExploreSocialPostCard`, `NotificationDeepLinkRouter` | `#social_graph`, `#notifications_bus` | Supports `/post/:id`; extensible for profile post grids inside `ArtistProfileView` / `OwnerProfileView`. |
| **`EP-P67-NOTIF-BELL`** | [`notification_bell_button.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/notifications/presentation/widgets/notification_bell_button.dart) | **5:** `VhunambiAppBar`, `ExploreTopBar`, `MainRoomHeader`, `LibraryAppBar`, `MarketplaceTopBar` | `#notifications_bus`, `#ui_surface_std` | Unified unread badge across top-level tabs; ready for backing by `EP-P67-NOTIF-API`. |
| **`EP-P67-DEEPLINK-ROUTER`** | [`notification_deep_link_router.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/notifications/presentation/utils/notification_deep_link_router.dart) | **2:** `NotificationsView`, `NotificationDetailBottomSheet` | `#notifications_bus`, `#social_graph` | Central route dispatcher (`/track/:id`, `/post/:id`, `/studio`, `/profile/:id`). |
| **`EP-P68-CREATOR-ALLOWANCE`** | [`creator_allowance_provider.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/home/presentation/providers/creator_allowance_provider.dart) | **1:** `MainRoomHeader` | `#quota_economy` | Currently mounted only in Home (`MainRoomHeader`); extensible to Studio Compose quota pill & `SubscriptionUpgradeModal`. |
| **`EP-P68-MINIPLAYER-SUPPRESS`** | `homeInlineNowPlayingMountedProvider` ([`navigation_providers.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/core/navigation/navigation_providers.dart)) | `MiniPlayerHost` (`mini_player_host.dart`), `HomeDashboardView` | `#audio_transport`, `#ui_surface_std` | Coordinates floating MiniPlayer visibility against inline players cleanly (`1` tab consumer so far). |
| **`EP-P65-CRASH-AUDIO-SHIELD`** | `VhunambiCrashShield`, `SafeAudioOrchestrator`, `SafeNotifierMixin`, `SafeNetworkAvatar`, `JsonSafe` | **3–6+** files each (`lib/core/resilience/`, `lib/core/utils/`, `lib/core/widgets/`) | `#audio_transport`, `#sync_outbox` | Mandatory mixins/utilities for any new `StateNotifier`, audio player, JSON parser, or avatar. Note: `SafeNetworkAvatar` only has 4 feature consumers so far (mostly Explore/Social). |
| **`EP-P61-IDENTITY-UTILS`** | [`creator_id_utils.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/core/utils/creator_id_utils.dart) | **10** (`auth`, `creator_dna`, `marketplace`, `playlists`, `profile`, `artist_profile_view`) | `#identity_role` | Already wired with owner checks inside `TrackDetailView` (`hasOwnerCheck=true`) and `ArtistProfileView` (`hasOwnerCheck=true`), ready to pair with formal `ViewerRole` / `EP-P58-MKT-VERIFY-PRODUCER` visitor isolation. |
| **`EP-P68-MOOD-FRAGMENTED`** | `enum Mood` ([`design_enums.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/core/design_system/tokens/design_enums.dart#L33-L48)) vs `StudioFormNotifier.setMood` vs `exploreMoodFilterProvider` | Studio Form & Explore Filter | `#mood_taxonomy`, `#ai_synthesis_gpu`, `#social_graph` | **Close/Distant Ripple Risk:** `design_enums.dart` defines `5` enum values (`joyful, melancholic, energetic, calm, romantic`), `StudioFormNotifier` uses string labels (`'Soulful & Nostalgic'`, `'Dark & Intense'`, etc.), and Explore seeds (`'Uplifting'`, `'Nostalgic'`, `'Energetic'`, `'Dark'`, `'Party'`, `'Peaceful'`, `'Romantic'`). Unifying this into a canonical `VhunambiMood` contract impacts Studio, Explore radio/filters, and Home mixes simultaneously. |

### 5.4 Seed `SEALED` Maintenance Primitives (Closed Internal Utilities)

* **`EP-P67-SCRUB-LEGACY-NOTIFS` (`SEALED`):** `NotificationRepository.isLegacyDemoMockId` / `scrubLegacyDemoMocks()` — internal Disk/Hive cleanup from Phase 67.
* **`EP-P63-R2-SEEDER` (`SEALED` / Ops):** `POST /api/system/seed-r2-media` ([`system_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/system_routes.ts)) — operator-only R2 hydration tool, not a client app UI target.
* **`EP-P62-RUNPOD-WEBHOOK` (`SEALED` / Webhook):** `POST /v1/webhooks/ace-step` ([`webhook_routes.ts`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_api/src/routes/webhook_routes.ts)) — server-to-server HMAC callback from RunPod GPU workers.

### 5.5 Active Standing Summary (`Phases 64–70` + `P68.5`) & Cross-Phase Coupling Highlights

1. **Phase 67 (`Notifications Center`):** UI & deep-links **Complete** (`15/15` `[x]`), client `OnboardingNotificationsService` active, `/api/notifications*` backend routes **built & tested yet still `OPEN` on client** (`0` HTTP callers).
2. **Phase 68 (`Home Dashboard Main Room`) + `68.5` (`Madoni Software Splash`):** **Complete** (`22/22` `[x]` + live [`splash_view.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/onboarding/presentation/views/splash_view.dart#L17-L420) & obsidian [`launch_background.xml`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/android/app/src/main/res/drawable/launch_background.xml)). `CreatorAllowanceNotifier` (`GET /api/wallet/allowance`) & `VhunambiTrackArtwork` are wired into Home & Explore, waiting for Studio/Track/Profile adoption.
3. **Phase 69 (`Kinetic Post Focus & Threading`):** **Complete & Shipped on APK** (`9/9` `[x]`, commit `bf7ca98`, `43.2 MB` APK installed on `EPHUT20917014649`). Delivered `KineticPostFocusView`, `ThreadedCommentsSection`, `StudioReactionComposerBar`, `ReelsCommentSheet` unification, and `/api/v1/explore/posts*`.
4. **Queued / Next Candidates (`Phase 70+`):**
   * **Song Cockpit (`TrackDetailView` — `936` lines) & Visitor Profile (`ArtistProfileView` — `803` lines):** Neither adopts `VhunambiTrackArtwork` (`EP-P68-TRACK-ARTWORK`) nor `ThreadedCommentsSection` (`EP-P69-THREADED-COMMENTS`), **TrackDetailView has `6` stock `Icons.*` and `ArtistProfileView` has `10` stock `Icons.*`** (`STD-UIUX-001` debt), and neither wires the **`OPEN`** `GET /api/marketplace/producers/:producerId/beats` endpoint (`EP-P58-MKT-VERIFY-PRODUCER`).
   * **Cloudflare Worker Full Postgres Persistence (`worker.ts` / `SupabaseCloudDriver`):** Most Worker routes beyond `auth_routes.ts` still rely on volatile `EdgeIsolateDatabaseEngine` memory rather than `SupabaseCloudDriver`, making cross-isolate persistence (`notifications`, `posts`, `wallet`) an important backend follow-up.
   * **Unified `Mood` Taxonomy (`EP-P68-MOOD-FRAGMENTED`):** Bridging `Mood` enum, Studio presets, and Explore mood filters unlocks Mood Radio and personalized Home curated mixes cleanly.
