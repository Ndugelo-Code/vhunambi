---
name: vhunambi-spec-architect
description: >-
  Author, audit, and harden Vhunambi 4-document phase specification suites
  (blueprint.md, requirements.md, design.md, tasks.md) under the All-Gemini
  Engineering Standard (Gemini 4 Argon Browser Architect + Antigravity Gemini 3.8
  Flash Draft/Executor + Antigravity Gemini 4 Argon Codebase Forensic Auditor).
  Use this skill whenever the user asks to create, review, refine, or standardize
  phase specifications, or before executing a new engineering phase.
---

# Vhunambi 4-Document Specification Architect & Forensic Hardening Skill

This skill enforces the official **Vhunambi All-Gemini Specification & Forensic Hardening Standard** established in [`docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`](../../../docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md) and exemplified by the Gold Standard Phase 53 suite ([`docs/phases/phase_53_organic_mycelium_3d_biome/`](../../../docs/phases/phase_53_organic_mycelium_3d_biome/)).

---

## 1. The All-Gemini 4-Stage Engineering Pipeline

Vhunambi operates on a 100% Gemini multi-tier workflow designed for maximum architectural intelligence, zero specification drift, and optimal credit efficiency:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                    VHUNAMBI ALL-GEMINI 4-STAGE ENGINEERING PIPELINE                    │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ STAGE 1: VISION, VIDEO FORENSICS & ARCHITECTURE (Gemini 4 Argon Browser Chat + User)   │
│ • Inspects physical device screen recordings (.mp4), screenshots & concept renders.    │
│ • Diagnoses root-cause UX, physics, rendering, and state defects.                      │
│ • Formulates the mathematical/architectural metaphor and generates the Stage 2 Prompt. │
├───────────────────────────────────────────┬────────────────────────────────────────────┤
│                                           ▼                                            │
│ STAGE 2: HIGH-VELOCITY 4-DOC SPEC DRAFTING (Antigravity IDE — Gemini 3.8 Flash High)   │
│ • STRICT RULE: Spec-Only Turn! Zero edits in `lib/` or `test/`, zero builds/tests.     │
│ • Authors the full 4-document suite in `docs/phases/phase_XX_<name>/`:                 │
│   1. `blueprint.md` (450–600+ lines)    3. `design.md` (800–2,500+ lines)              │
│   2. `requirements.md` (280–400+ lines) 4. `tasks.md` (250–350+ lines)                 │
├───────────────────────────────────────────┬────────────────────────────────────────────┤
│                                           ▼                                            │
│ STAGE 3: FORENSIC SPEC AUDIT & HARDENING (Argon Browser -> Antigravity Argon High)     │
│ • Argon Browser Chat audits Flash 3.8's 4 spec files to catch hidden implementation    │
│   traps (e.g., theory-vs-code bait-and-switches, axis contradictions, dead callbacks). │
│ • Antigravity IDE (switched to Gemini 4 Argon High) rewrites and unifies the 4 spec    │
│   files in-place with zero code execution (preserving Argon credits for pure math/arch)│
├───────────────────────────────────────────┬────────────────────────────────────────────┤
│                                           ▼                                            │
│ STAGE 4: DETERMINISTIC EXECUTION & DEVICE DEPLOY (Antigravity IDE — Gemini 3.8 Flash)  │
│ • User switches Antigravity IDE back to Gemini 3.8 Flash (High).                       │
│ • Flash executes Milestones M1–M6 directly from the Argon-hardened `design.md`.        │
│ • Runs `flutter analyze` (0 issues), `flutter test` (100% pass), builds release APK,   │
│   installs on physical device (`EPHUT20917014649`), and updates `AGENT_HANDOFF_BIBLE`. │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Strict Turn Guardrails (Stage 2 Draft & Stage 3 Argon Hardening)

When operating in **Stage 2 (Spec Drafting)** or **Stage 3 (Argon Spec Hardening)**:
1. **DO NOT create or modify any `.dart` or `.ts` files in `apps/` (`lib/` or `test/`).**
2. **DO NOT run `flutter test`, `flutter analyze`, `dart analyze`, or `flutter build`.**
3. Dedicate 100% of token budget and reasoning to authoring and unifying the 4 markdown files in `docs/phases/phase_XX_<name>/`.

---

## 3. Structure & Depth Standards for the 4 Specification Documents

Every phase specification suite in `docs/phases/phase_XX_<name>/` MUST contain all four files below and meet the formatting, box-diagram, and mathematical rigor of [`docs/phases/phase_53_organic_mycelium_3d_biome/`](../../../docs/phases/phase_53_organic_mycelium_3d_biome/):

### 3.1 `blueprint.md` (Target: 450–600 lines)
- **§1 Executive Overview & Visual North Star**: Problem statement from physical device recordings and architectural solution.
- **§2 Forensic Post-Mortem Comparison Box**: Side-by-side ASCII box table comparing previous failure modes vs. the new architecture.
- **§3 Multi-Layer Decoupled System Architecture**: ASCII layered architecture diagram tracing Audio/Data $\to$ Pure Dart Domain $\to$ Procedural/Business Engine $\to$ Camera/Controller $\to$ Flutter HUD.
- **§4 Spatial Topology & Domain Taxonomy**: ASCII spatial map + canonical markdown table of all primary entities, coordinates, palettes, and child nodes.
- **§5–§7 State Machines & Dual-Viewport HUD Wireframes**: Mermaid `stateDiagram-v2` + full ASCII wireframes for Desktop ($\ge 600\text{dp}$) and Mobile Portrait ($< 600\text{dp}$).
- **§8–§12 Mathematical Formulations, Entanglement Sequence & Hardware Vertex/Memory Budget**: Mermaid `sequenceDiagram`, explicit equations, and verification gates table (`G-01` through `G-06`).

### 3.2 `requirements.md` (Target: 280–400 lines)
- **§1 Document Scope, Coordinate Standard & EARS / RFC-2119 Conventions**: Explicit definition of coordinate axes and EARS keywords (`WHEN`, `WHILE`, `IF...THEN`, `WHERE`, `SHALL`).
- **§2–§6 Categorized Functional Requirements**: Grouped logically (`REQ-PXX-CORE-*`, `REQ-PXX-MYCEL-*`, `REQ-PXX-CAM-*`, `REQ-PXX-HUD-*`) with explicit widget keys (`Key('...')`), numerical bounds, and child node inventories.
- **§7 Non-Functional & Performance Requirements (`REQ-PXX-NFR-*`)**:
  - 60 FPS mobile ARM64 frame budget ($\le 16.6\text{ms}$).
  - Built-in Flutter GPU rendering (`dart:ui` `Vertices`, `vector_math_64`) with zero unverified third-party native plugins.
  - Zero Raw Emojis Law (`STD-UIUX-001`).
  - Headless Dart VM domain testability.
- **§8–§12 Error Resilience & Granular Requirement-to-Test Traceability Matrix**: ASCII matrix mapping every `REQ-PXX-*` ID to its exact target class and `test('...')` case.

### 3.3 `design.md` (Target: 800–2,500 lines)
- **§1–§2 Comprehensive Mathematical Foundations**: Complete, continuous equations with partial derivatives, surface normals, spline interpolations, view/projection transformations, and pointer-count gesture state machines.
- **§3 Pure Dart Domain Architecture**: Complete, compilable Dart classes (`enum`, `Vector3D`, domain entities, `copyWith`, equality) with zero `package:flutter` or `dart:ui` imports.
- **§4–§6 Projection Engine, Synchronous Hit-Testing & Riverpod Providers**: Compilable `ProjectionEngine.project3D(...)`, synchronous `hitTest(...)`, and Riverpod `StateNotifierProvider` declarations.
- **§8–§12 Complete Production CustomPainters & HUD Widget Implementations**: Full, copy-paste-ready Dart code for all painters and HUD decks (zero `// TODO` or `// ... other fields` placeholders!).
- **§13–§14 Mathematical Proofs & End-to-End Sequence Diagrams**: Formal proof of zero gimbal lock / state invariants + Mermaid diagrams.

### 3.4 `tasks.md` (Target: 250–350 lines)
- **§1 Master Milestone Roadmap & Dependency Graph**: ASCII roadmap box (`M1` through `M6`) + summary table.
- **§2–§7 Milestones M1–M6 Granular Tasks**: Each task (`Task X.Y`) specifies Target File (`apps/vhunambi_client/lib/...`), concrete method signatures, and Acceptance Criteria.
- **§8–§9 Traceability Matrix & Stage 4 Execution Verification Checklist**: Boxed `[x]` checklist of the 7 Anti-Trap invariants + exact PowerShell verification commands.

---

## 4. The 6 Mandatory Anti-Bait-and-Switch Laws (Forensic Audit Gate)

Before signing off on any specification suite, read and verify all 6 laws in [references/FORENSIC_SPEC_CHECKLIST.md](./references/FORENSIC_SPEC_CHECKLIST.md):

1. **Law 1 — Theory-to-Code Mathematical Fidelity**: The code in `design.md` §8 MUST implement the exact 3D/mathematical equations defined in `design.md` §2 (never bait-and-switch 3D parametric mesh equations into flat 2D `canvas.drawOval` or single-line shortcuts).
2. **Law 2 — Unified Coordinate Convention**: All 4 documents MUST use the exact same coordinate axes and numerical loci (for 3D views: **Right-Handed 3D Y-Up World Space** where $X$ is right, $Y = h(X, Z) \ge 0$ is UP, $Z$ is foreground depth, and screen projection maps $+Y$ upward via $Y_{\text{screen}} = H/2 - y_{\text{eye}} \cdot \text{scale}$).
3. **Law 3 — Authentic Vhunambi Monorepo Imports & Tokens**:
   - Package name is **`package:vhunambi_client/...`** (NEVER `package:vhunambi/...`).
   - Icon package is **`package:phosphor_icons/phosphor_icons.dart`** using `PhosphorIcon(PhosphorIconsBold.*)` / `PhosphorIconsRegular.*` / `PhosphorIconsFill.*` (NEVER `package:phosphor_flutter/...`).
   - Color tokens in `AppColors` are `darkSurfaceCanvas`, `darkSurfaceElevated`, `darkSurfaceSecondary`, `darkSurfaceModal`, `darkBorderSubtle`, `brandPrimary`, `surfaceElevatedOf(context)`, `textPrimaryOf(context)` (NEVER `AppColors.surfaceDark`).
   - Typography tokens in `AppTypography` are `displayLarge`, `displayMedium`, `titleLarge`, `titleMedium`, `titleSmall`, `bodyLarge`, `bodyMedium`, `bodyMuted`, `bodySmall`, `caption`, `badge`, `bouncyDisplayLarge`, `bouncyTitleLarge`, `bouncyBadge` (NEVER `AppTypography.labelSmall` or `labelMedium`).
4. **Law 4 — Synchronous Hit-Testing & Semantic Test Keys**: Never leave hit-box callbacks uncalled. Provide a synchronous `hitTest(...)` method AND semantic `Positioned` widget targets with explicit `Key('...')` identifiers.
5. **Law 5 — 100% HUD & Requirement Widget Parity**: Every HUD deck or control mentioned in `blueprint.md` or `requirements.md` MUST have a complete widget implementation in `design.md` and a task in `tasks.md`.
6. **Law 6 — Zero Raw Emojis (`STD-UIUX-001`)**: Zero raw unicode emojis in Dart code blocks, widget trees, or formal tables.

