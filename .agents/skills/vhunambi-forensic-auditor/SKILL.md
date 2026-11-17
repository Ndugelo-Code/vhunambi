---
name: vhunambi-forensic-auditor
description: >-
  Forensic codebase, runtime, UI/UX surface, and end-to-end cloud/GPU pipeline auditing and analysis engine for the Vhunambi monorepo. Produces gold-standard, zero-speculation audit reports in docs/audits/ with exact file-and-line citations, ASCII topology maps, Mermaid breakpoint diagrams, exhaustive call-site censuses, P0-P3 severity matrices, and Stage 2/Stage 4 remediation blueprints. Use this skill whenever the user invokes /vhunambi-forensic-auditor, asks to audit, analyze, diagnose, or inspect any Vhunambi feature, screen, backend route, database schema, GPU worker, or physical device log, or before authoring a new phase specification suite.
---

# Vhunambi Codebase Forensic Auditor & Systems Analysis Skill (`vhunambi-forensic-auditor`)

This skill governs **Stage 1 (Forensic Codebase Discovery, Physical Device Post-Mortem & Pre-Spec Audit)** and **Stage 5 (Post-Execution Regression & Live Pipeline Verification)** of the **Vhunambi All-Gemini Engineering Standard**.

It is the foundational diagnostic counterpart to [`vhunambi-spec-architect`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/.agents/skills/vhunambi-spec-architect/SKILL.md) and [`vhunambi-executioner`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/.agents/skills/vhunambi-executioner/SKILL.md), codifying the exact forensic methodology established across the 25+ canonical audit reports in [`docs/audits/`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/audits/).

---

## 1. Position in the Vhunambi Tri-Skill Engineering Ecosystem

In the Vhunambi workflow, **no major specification or remediation phase is authored blind**. Every architectural leap begins with an uncompromising forensic audit stored in `docs/audits/`:

```
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                     VHUNAMBI TRI-SKILL AUTONOMOUS ENGINEERING LOOP                       │
├──────────────────────────────────────────────────────────────────────────────────────────┤
│ 1. FORENSIC DISCOVERY & ROOT-CAUSE AUDIT (`vhunambi-forensic-auditor` — THIS SKILL)      │
│    • Performs read-only static AST/regex sweeps, cross-stack wire tracing, and physical  │
│      device telemetry inspection (`adb logcat`, HTTP payloads, R2 binary headers).       │
│    • Produces a permanent, line-cited forensic report in `docs/audits/<NAME>_AUDIT.md`   │
│      with an ordered Milestone Plan (`MXX.1` – `MXX.N`).                                 │
├─────────────────────────────────────────────┬────────────────────────────────────────────┤
│                                             ▼                                            │
│ 2. 4-DOCUMENT SPECIFICATION ARCHITECTURE (`vhunambi-spec-architect`)                     │
│    • Ingests the `docs/audits/<NAME>_AUDIT.md` findings and milestone blueprint.         │
│    • Authors and Argon-hardens `blueprint.md`, `requirements.md`, `design.md`, and       │
│      `tasks.md` under `docs/phases/phase_XX_<name>/`.                                    │
├─────────────────────────────────────────────┬────────────────────────────────────────────┤
│                                             ▼                                            │
│ 3. DETERMINISTIC ANTI-TRAP EXECUTION (`vhunambi-executioner`)                            │
│    • Executes `tasks.md` milestone-by-milestone (`M1` -> `MN`) with surgical additive    │
│      edits, zero lazy/summary code, and bounded `--timeout=60s` verification gates.      │
│    • Feeds back into `vhunambi-forensic-auditor` for post-deploy convergence sign-off.   │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

| Skill Name | Pipeline Stage | Primary Artifact Output | Core Mandate |
| :--- | :--- | :--- | :--- |
| **`vhunambi-forensic-auditor` (THIS SKILL)** | **Stage 1 (Pre-Spec Audit) & Stage 5 (Post-Deploy Audit)** | `docs/audits/<TOPIC>_AUDIT.md` | Expose every root-cause crash, wire break, schema drift, `STD-UIUX-001` violation, and unfinished stub with 100% file-and-line proof. |
| [`vhunambi-spec-architect`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/.agents/skills/vhunambi-spec-architect/SKILL.md) | **Stage 2 (Spec Draft) & Stage 3 (Argon Hardening)** | `docs/phases/phase_XX_.../{blueprint,requirements,design,tasks}.md` | Translate audit remediation blueprints into unified, trap-free 4-document phase specifications. |
| [`vhunambi-executioner`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/.agents/skills/vhunambi-executioner/SKILL.md) | **Stage 4 (Deterministic Execution)** | Production code in `apps/` & `tools/` + `[x]` in `tasks.md` | Implement every milestone with surgical edits, zero placeholders, and 100% passing analyzer/test gates. |

---

## 2. Strict Audit-Turn Guardrails

When operating in **Pure Forensic Audit Mode** (generating or updating an audit report in `docs/audits/`):
1. **Read-Only Codebase Inspection**: Do NOT modify application source files in `apps/vhunambi_client/lib/`, `apps/vhunambi_api/src/`, or `tools/zr-studio-gpu/` unless the user explicitly asks you to audit *and* immediately execute the fixes in the same turn.
2. **Never Poll Long-Running Shell Commands**: Prefer fast, targeted `read_file` calls and bounded directory searches scoped strictly to `apps/vhunambi_client/lib`, `apps/vhunambi_api/src`, `tools/zr-studio-gpu`, and `supabase/migrations` (never recursively scan `build/`, `.dart_tool/`, or `node_modules/`).
3. **Permanent Documentation Artifact**: Unless the user asks for a quick chat-only summary, always persist comprehensive audits as a structured markdown document in `docs/audits/<UPPER_SNAKE_CASE_NAME>_AUDIT.md`.

---

## 3. The 4 Canonical Vhunambi Audit Archetypes

Every Vhunambi audit falls into one (or a hybrid) of four proven archetypes in [`docs/audits/`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/audits/):

### Archetype A: Full-Stack Crash, Stability & Fault-Containment Audit
- **Canonical Exemplar**: [`docs/audits/PHASE65_FOUNDATION_STABILITY_AND_ERROR_HANDLING_AUDIT.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/audits/PHASE65_FOUNDATION_STABILITY_AND_ERROR_HANDLING_AUDIT.md)
- **Focus**: Physical device crash dumps (`adb logcat -b crash`, `dumpsys dropbox`), Android resource/manifest integrity (`drawable/ic_stat_music`), root isolate crash shields (`runZonedGuarded`, `FlutterError.onError`, `PlatformDispatcher.instance.onError`), concurrent `just_audio` / `ExoPlayer` hardware decoder contention, async `StateNotifier` post-dispose `mounted` guards, unguarded stream `.listen()` calls, and unsafe JSON casts (`as Map<String, dynamic>`).

### Archetype B: End-to-End Cloud, Edge (`workerd`), Database & GPU Pipeline Audit
- **Canonical Exemplars**:
  - [`docs/audits/PHASE63_E2E_CLOUD_PIPELINE_AND_PREFLIGHT_AUDIT.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/audits/PHASE63_E2E_CLOUD_PIPELINE_AND_PREFLIGHT_AUDIT.md)
  - [`docs/audits/HYBRID_CLOUD_STACK_TOPOLOGY_PHASE62_AUDIT.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/audits/HYBRID_CLOUD_STACK_TOPOLOGY_PHASE62_AUDIT.md)
- **Focus**: Tracing a user action from Flutter UI $\to$ Hono/Cloudflare Worker (`src/worker.ts`) $\to$ Durable Objects (`GenerationSessionDO`) $\to$ Supabase Postgres / `node:sqlite` (`vhunambi_db.ts`) $\to$ Cloudflare R2 (`VHUNAMBI_VAULT`) $\to$ RunPod Serverless GPU (`tools/zr-studio-gpu/handler.py`, `model_utils.py`, `stem_mastering_worker.py`) and back. Exposes `workerd` V8 isolate traps (`SQLITE_UNAVAILABLE_IN_EDGE_ISOLATE`), volatile RAM fallbacks, per-request `c.env` loss, `camelCase` vs `snake_case` wire mismatches, SQLite $\leftrightarrow$ Postgres schema/sign drift, and DSP/phonetic bugs (`ACE-Step` lyric sanitization, `LangSegment` Bantu-to-Chinese vocal misclassification, `-9.5 LUFS` stem re-summing distortion).

### Archetype C: UI/UX Surface, Design System (`STD-UIUX-001`) & Unfinished Stub Audit
- **Canonical Exemplars**:
  - [`docs/audits/FLAWS_AND_UNFINISHED_FEATURES_AUDIT.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/audits/FLAWS_AND_UNFINISHED_FEATURES_AUDIT.md)
  - [`docs/audits/MOBILE_BOTTOM_NAV_AND_ICONOGRAPHY_AUDIT.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/audits/MOBILE_BOTTOM_NAV_AND_ICONOGRAPHY_AUDIT.md)
  - [`docs/audits/ADAPTIVE_MINI_PLAYER_AND_DRAG_DISMISS_AUDIT.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/audits/ADAPTIVE_MINI_PLAYER_AND_DRAG_DISMISS_AUDIT.md)
- **Focus**: Auditing visual harmony across screens against the Home Dashboard golden standard, catching stock Material `Icons.*` and raw Unicode emoji violations (`STD-UIUX-001`), verifying $44 \times 44\text{dp}$ WCAG/HIG touch targets, checking `360x800` compact mobile overflow resistance, auditing bottom-dock occlusion (`VhunambiBottomDockMetrics` / `PlayerObstacle`), exposing "SnackBar Dead-Ends" (buttons that only show a toast instead of executing real logic or opening existing modals), and cataloguing orphaned/unmounted widgets.

### Archetype D: Deep Subsystem & Domain Architecture Audit
- **Canonical Exemplars**:
  - [`docs/audits/STUDIO_COCKPIT_AND_2D_SONG_CREATION_FLOW_AUDIT.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/audits/STUDIO_COCKPIT_AND_2D_SONG_CREATION_FLOW_AUDIT.md)
  - [`docs/audits/PLAYER_STEMS_MIXER_AND_AUDIO_REACTIVE_3D_BIOME_AUDIT.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/audits/PLAYER_STEMS_MIXER_AND_AUDIO_REACTIVE_3D_BIOME_AUDIT.md)
  - [`docs/audits/HIVE_PERSISTENCE_ENGINE_COMPREHENSIVE_AUDIT.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/audits/HIVE_PERSISTENCE_ENGINE_COMPREHENSIVE_AUDIT.md)
  - [`docs/audits/SOVEREIGN_IDENTITY_AUTH_AND_SECURITY_AUDIT.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/audits/SOVEREIGN_IDENTITY_AUTH_AND_SECURITY_AUDIT.md)
- **Focus**: Complete architectural decomposition of a complex domain subsystem: ASCII visual hierarchy maps, Riverpod provider dependency graphs, 2D control-to-DSP/neural conditioning tables, AES-256 Hive vault & L1 cache sanitization audits, and end-to-end African creator user journey walkthroughs.

---

## 4. The 8 Non-Negotiable Vhunambi Forensic Auditing Laws

Every audit conducted under this skill MUST obey these 8 laws without exception:

### Law 1: Zero Speculation — Exact File & Line Evidence (`file:///...#LXX-LYY`)
Never guess how a widget, provider, route, or worker behaves based on its filename. You MUST read the actual implementation and cite clickable workspace links with exact line ranges (e.g., [`vhunambi_audio_handler.dart#L61`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/player/data/services/vhunambi_audio_handler.dart#L61)) for every finding.

### Law 2: Exhaustive Census Over Anecdotal Sampling
Never write vague statements like *"several providers lack `mounted` checks"* or *"some routes call `vhunambiDb` directly."* Perform a systematic census across the target scope and list **every single offending file and line number** in a structured markdown table so the Stage 2 Spec Architect and Stage 4 Executioner have a 100% complete target list.

### Law 3: Cross-Boundary Wire, Schema & Runtime Traceability
When auditing any feature that crosses process or language boundaries, trace the exact data contract across all 5 layers:
1. **Flutter Presentation & Providers (`apps/vhunambi_client/lib/`)**: Check whether UI selectors (`studioFormProvider`, etc.) are actually read and passed into the request DTO, or if defaults (`creatorDnaProvider`, `FakeLyricsGenerationService`) silently override user selections.
2. **HTTP / WebSocket Wire Format**: Compare the exact JSON keys and enum strings serialized by the server (`camelCase` vs `snake_case`, status names like `'synthesizing'` vs `'queued'`) against the Dart `.fromJson()` / Zod parser on the receiving end.
3. **Cloudflare Worker (`workerd`) Edge Safety (`apps/vhunambi_api/src/`)**: Check whether routes guard `isNodeSqliteAvailable()`, pass per-request `c.env` into adapters (`runpod_adapter.ts`, `comfyui_adapter.ts`), wrap background promises in `ctx.waitUntil(...)`, and persist state in Supabase Postgres / Durable Objects rather than volatile isolate `Map`s.
4. **SQLite (`vhunambi_db.ts`) $\leftrightarrow$ Postgres (`supabase/migrations/`) Parity**: Verify table names, column names (`data_json` vs `metadata_json`, `cover_url` vs `cover_image_url`), primary keys, timestamp types (`TEXT` ISO vs `BIGINT` epoch ms), and sign conventions (e.g., positive vs negative payout ledger entries).
5. **RunPod GPU & R2 Media Pipeline (`tools/zr-studio-gpu/`)**: Verify prompt compilation tags, lyric sanitization (stripping non-structural `[stage directions]` before `ACEStepPipeline`), `LangSegment` Latin phonetic guards for Bantu languages (`ve`, `zu`, `xh`, `st`, `tn`, `ts`), non-destructive `-14 LUFS` master audio handling vs Demucs 4-stem separation, and genuine binary headers (MP3/WAV/PNG/MP4) uploaded to R2.

### Law 4: Physical Device & Runtime Telemetry Forensics
When auditing live hardware issues (e.g., on Huawei `JNY_LX1` `EPHUT20917014649` or Samsung flagships) or screen recordings:
- Correlate video timestamps (`MM:SS`) or crash logs (`adb logcat -b crash`, `dumpsys dropbox`) directly to the exact Dart/Java/Python stack frame and state transition that caused the symptom.
- Distinguish between **fatal OS-level exceptions** (e.g., missing Android `drawable/` notification icon crashing `NotificationManager` on the Java main thread), **UI thread stalls/jank** (e.g., 10 concurrent `ExoPlayer` decoders or unthrottled 3D canvas allocations), and **silent fallback masking** (e.g., `try/catch` blocks that swallow API 400s and return hardcoded English demo lyrics).

### Law 5: Unfinished Feature, "SnackBar Dead-End" & Orphaned Code Detection
Actively inspect action handlers (`onTap`, `onPressed`) and service bindings for:
1. **SnackBar / Toast Dead-Ends**: Buttons that close a sheet or show `ScaffoldMessenger.of(context).showSnackBar(...)` without mutating state, calling a repository, or opening the target modal (especially when the target modal—such as `AddToPlaylistSheet`—already exists in the codebase!).
2. **Simulated Production Flags**: Services running with `isSimulated: true`, `simulateDownloads: true`, hardcoded `Future.delayed(...)` stubs, or `/mock-storage/...` URLs.
3. **Orphaned / Unmounted Widgets**: Fully built widgets in `lib/` that have zero incoming imports outside their own file.

### Law 6: UI/UX, Touch Physics & Design Token Compliance (`STD-UIUX-001`)
Every UI/UX audit must verify compliance with Vhunambi's visual and ergonomic invariants:
- **Zero Raw Unicode Emojis (`STD-UIUX-001`)**: Flag any literal emoji (`'🔥'`, `'🪙'`, `'✨'`, `'🎵'`, `'💿'`) in `Text(...)` widgets, snackbars, or labels; prescribe the exact `PhosphorIcon(AppIcons.*)` replacement.
- **Zero Stock Material Icons**: Flag any `Icon(Icons.*)` usage and prescribe the exact `PhosphorIcon(AppIcons.*)` or `PhosphorIconsRegular.*` / `PhosphorIconsFill.*` token.
- **Authentic `AppColors` & `AppTypography` Tokens**: Verify no hardcoded hex/RGB colors or hallucinated tokens are used when semantic tokens exist.
- **$44 \times 44\text{dp}$ Minimum Touch Targets & Compact Viewport Safety**: Verify all interactive controls meet $44 \times 44\text{dp}$ minimum hit bounds and render without `RenderFlex` overflow at `360x800`.
- **Top Bar & Bottom Dock Geometry**: Check safe-area padding (`VhunambiTopBarMetrics`), floating mini-player clearance (`VhunambiBottomDockMetrics.scrollInset`, `PlayerObstacle`), and single-source-of-truth tab state (`appNavigationTabProvider`).

### Law 7: Visual Architecture Communication (ASCII Boxes & Mermaid Diagrams)
Every Vhunambi audit report MUST make complex system relationships immediately scannable using:
- **ASCII Comparison / Spectrum Boxes (`┌───┬───┐`)**: Contrasting "Golden Standard vs. Legacy/Broken Surface" or "Current Defect vs. Required Architecture."
- **ASCII Layout & Layer Hierarchies**: Showing exact screen/widget nesting and pixel/dp metrics.
- **Mermaid Diagrams (`flowchart TD`, `sequenceDiagram`, `stateDiagram-v2`)**: Mapping end-to-end breakpoint topologies (`BREAK 1` $\to$ `BREAK N`), Riverpod provider graphs, or multi-step race conditions.

### Law 8: Actionable Remediation Architecture & Ordered Milestone Handoff
An audit is never just a list of complaints. Every audit report MUST conclude with:
1. **Severity Classification (`P0` – `P3`)**:
   - `P0` (**Critical / Blocker**): Process crash, data loss/corruption, broken E2E core loop, security/auth bypass, or severe audio/visual distortion.
   - `P1` (**High / Major Defect**): Feature silently falls back to fake/demo data, cross-tab state desync, post-dispose exception risk, or major UX dead-end.
   - `P2` (**Medium / Structural Drift**): Design system (`STD-UIUX-001`) icon/emoji violation, layout crowding on `360dp` screens, or missing non-critical error telemetry.
   - `P3` (**Low / Polish & Cleanup**): Orphaned dead code, minor visual asymmetry, or documentation/comment cleanup.
2. **Concrete Architectural Solution Blueprint**: Named containment layers, exact class/method contracts, and code snippets showing the fix pattern.
3. **Ordered Milestone Plan (`MXX.1` – `MXX.N`)**: Sequenced so `P0` stop-the-bleeding fixes land first, ready to hand directly into `/vhunambi-spec-architect` or `/vhunambi-executioner`.

---

## 5. Mandatory Anatomy of a `docs/audits/<NAME>_AUDIT.md` Report

When authoring a new audit document in `docs/audits/`, structure it with these canonical sections:

```markdown
# <Title: Phase XX / Subsystem — Comprehensive Forensic Audit>

**Document ID:** `AUDIT-<DOMAIN>-<NNN>`
**Date:** YYYY-MM-DD
**Branch / Commit:** `<branch>` (`<short-sha>`)
**Audit Scope:** Read-only static & runtime forensic audit across `<paths>`
**Related Specs & Audits:** Links to predecessor phases and related audits

---

## 1. Executive Summary & Headline Verdict
- High-level architectural verdict and honest readiness scorecard.
- Physical device / runtime smoking gun evidence (if applicable).
- **Executive Root-Cause & Severity Matrix** (`Symptom | Severity | Primary Root Cause | Exact File & Line Evidence`).
- **End-to-End Breakpoint Topology Map** (Mermaid `flowchart TD` or ASCII comparison box).

---

## 2. Pillar-by-Pillar / Dimension-by-Dimension Forensic Findings
For each pillar or dimension:
- Architectural explanation + ASCII diagram or schema diff table.
- **Exhaustive Findings Table** (`ID | Sev | File & Line(s) | Exact Defect | Concrete Remediation Pattern`).
- Exact code excerpts proving the defect (e.g., unguarded call sites, mismatched JSON keys, dead-end `SnackBar` handlers).

---

## 3. Target Remediation Architecture Blueprint
- Multi-layer architectural blueprint (`Layer 1` .. `Layer N`) defining the exact classes, mixins, SQL migrations, or UI components required to permanently close all findings.

---

## 4. Ordered Remediation Milestone Plan (`MXX.1` – `MXX.N`)
- Step-by-step milestone breakdown ready for `/vhunambi-spec-architect` (to generate the 4-doc phase suite) or `/vhunambi-executioner` (for direct surgical execution).
- Verification gate commands (`flutter analyze`, `flutter test --timeout=60s`, `tsc --noEmit`, `python -m py_compile`, physical device ADB checks).
```

---

## 6. Step-by-Step 5-Stage Forensic Audit Playbook

When invoked (via `/vhunambi-forensic-auditor` or an audit/analysis request), execute this 5-step workflow:

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ STEP 1: SCOPE DEFINITION & PRIOR AUDIT DISCOVERY                             │
│  • Identify which archetype(s) apply (A: Crash/Stability, B: Cloud/GPU E2E,  │
│    C: UI/UX & Stubs, D: Subsystem Deep-Dive).                                │
│  • Check `docs/audits/` and `docs/phases/` for existing audits or specs on   │
│    the target subsystem to build on prior context without duplication.       │
├──────────────────────────────────────────────────────────────────────────────┤
│ STEP 2: MULTI-LAYER STATIC & RUNTIME EVIDENCE SWEEP                          │
│  • Read primary entrypoints, providers, repositories, routes, and workers.   │
│  • Run targeted searches scoped to `lib/`, `src/`, `tools/` to build an      │
│    exhaustive census of call sites, casts, icons, emojis, or schema columns. │
│  • If device/video logs are present, trace every symptom to its exact line.  │
├──────────────────────────────────────────────────────────────────────────────┤
│ STEP 3: CROSS-BOUNDARY CONTRACT & INVARIANT DIFFING                          │
│  • Verify wire contracts (Flutter DTO <-> Hono Route <-> DB <-> RunPod GPU). │
│  • Check `STD-UIUX-001` tokens, 44x44dp touch targets, and dock occlusion.   │
│  • Check `workerd` isolate safety, Hive L1 cache hygiene, and error guards.  │
├──────────────────────────────────────────────────────────────────────────────┤
│ STEP 4: SYNTHESIZE & WRITE `docs/audits/<NAME>_AUDIT.md`                     │
│  • Author the complete forensic report in `docs/audits/` with clickable      │
│    `file:///...#LXX-LYY` links, ASCII boxes, Mermaid diagrams, P0-P3 tables, │
│    and the Remediation Blueprint.                                            │
├──────────────────────────────────────────────────────────────────────────────┤
│ STEP 5: NEXT-STAGE HANDOFF (`vhunambi-spec-architect` / `executioner`)       │
│  • Present a concise executive summary to the user with a link to the new    │
│    audit report and offer to launch Stage 2 (`vhunambi-spec-architect`) or   │
│    direct surgical remediation (`vhunambi-executioner`).                     │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 7. Companion Reference Checklist & Taxonomy

Before finalizing any audit report, consult the 6-Pillar Forensic Inspection Checklist and Scan Recipes in:
- [`references/FORENSIC_AUDIT_CHECKLIST_AND_TAXONOMY.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/.agents/skills/vhunambi-forensic-auditor/references/FORENSIC_AUDIT_CHECKLIST_AND_TAXONOMY.md)
