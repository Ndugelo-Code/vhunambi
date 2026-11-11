---
name: vhunambi-executioner
description: >-
  Deterministic Stage 4 code execution, anti-trap implementation, and forensic verification engine for Vhunambi 4-document phase specification suites (blueprint.md, requirements.md, design.md, tasks.md). Use this skill whenever the user invokes /vhunambi-executioner or asks to execute, implement, build, or verify a Vhunambi engineering phase from its specification suite without lazy/summary code, destructive overwrites, or test timeouts.
---

# Vhunambi Stage 4 Executioner Skill (`vhunambi-executioner`)

This skill governs **Stage 4 (Deterministic Execution, Anti-Trap Code Synthesis & Full-Stack Verification)** of the Vhunambi **All-Gemini Engineering Standard**. It is the operational counterpart to [`vhunambi-spec-architect`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/.agents/skills/vhunambi-spec-architect/SKILL.md).

Where `vhunambi-spec-architect` turns architectural intent into an Argon-hardened 4-document specification suite (`blueprint.md`, `requirements.md`, `design.md`, `tasks.md`), **`vhunambi-executioner`** ensures the executing agent (e.g., Antigravity Gemini 3.8 Flash or Gemini 4 Argon) translates every requirement, wireframe geometry, mathematical formula, SQL migration, edge handler, and widget contract into **100% production-complete code with zero regressions**.

---

## 1. Position in the 4-Stage All-Gemini Engineering Pipeline

| Stage | Role | Active Skill | Core Responsibility |
| :--- | :--- | :--- | :--- |
| **Stage 1** | External Strategic Architect (Gemini 4 Argon Browser) | — | Defines macro-system topology, phase roadmap, and strategic traps. |
| **Stage 2** | Rapid Spec Drafter (Gemini 3.8 Flash) | [`vhunambi-spec-architect`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/.agents/skills/vhunambi-spec-architect/SKILL.md) | Scaffolds the 4-document phase suite (`blueprint.md`, `requirements.md`, `design.md`, `tasks.md`). |
| **Stage 3** | Codebase Forensic Spec Auditor (Gemini 4 Argon High) | [`vhunambi-spec-architect`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/.agents/skills/vhunambi-spec-architect/SKILL.md) | Audits and hardens the 4-document suite against live monorepo symbols, schemas, and cross-phase invariants. |
| **Stage 4** | **Deterministic Phase Executioner (Gemini 3.8 Flash / Argon)** | **`vhunambi-executioner` (THIS SKILL)** | Executes `tasks.md` milestone-by-milestone (`M1` $\to$ `MN`) by cross-reading all 4 spec documents, performing surgical additive edits, enforcing zero-lazy-code discipline, and passing all static analysis & bounded-timeout test gates. |

---

## 2. The 8 Non-Negotiable Stage 4 Execution Laws

Every agent executing a Vhunambi phase MUST strictly obey these 8 laws without exception:

### Law 1: The 4-Document Cross-Read Protocol (Zero Single-Doc Blindness)
Never implement a milestone by reading `tasks.md` or `design.md` in isolation. Each of the 4 documents holds mandatory contracts that must be synthesized together before editing any file:
1. **`tasks.md` (The Execution Sequence & Gate Map)**: Dictates the strict milestone execution order (`M1` $\to$ `MN`), exact target file paths, method signatures, and verification test commands.
2. **`requirements.md` (The Contract & Edge-Case Matrix)**: Dictates exact `Key('...')` widget identifiers, HTTP status codes (`401`, `402`, `409`, `503`), numeric thresholds, latency budgets, and EARS error-recovery behaviors (`IF ... THEN THE SYSTEM SHALL ...`).
3. **`blueprint.md` (The Spatial & State-Machine Truth)**: Dictates ASCII wireframe layout hierarchies, pixel/dp dimensions, responsive breakpoints, and Finite State Machine (FSM) state transitions.
4. **`design.md` (The Code & Schema Reference)**: Provides concrete SQL DDL, TypeScript/Hono handlers, Python GPU handlers, and Dart/Riverpod implementations.

### Law 2: Additive Surgical Editing vs. Destructive File Replacement
`design.md` often presents focused code listings showing the newly introduced or upgraded methods/constants for a target file. **NEVER blindly overwrite an existing shared file with a partial code snippet from `design.md`!**
- **Mandatory Pre-Edit Read**: Before modifying any existing file (`app_constants.dart`, `vhunambi_db.ts`, `server.ts`, `hive_aes_vault_cipher.dart`, `creator_id_utils.dart`, `sovereign_hive_account_sanitizer.dart`, `auth_providers.dart`, etc.), you MUST first read the existing file using `read_file`.
- **Inventory Existing Contracts**: Identify all existing constants, Hive box keys (e.g., all 26 Phase 60 box keys in `AppConstants`), layout metrics, SQLite column names (`data_json`), and backward-compatible method aliases (e.g., keeping both `createCipher()` and `buildCipher()`, keeping both `getWallet()` and `getWalletSnapshot()`, keeping both top-level functions and static wrapper classes).
- **Prefer `edit_file` Over `write_file` on Existing Files**: Merge new fields, methods, and branches surgically using `edit_file`. Only use `write_file` with `Overwrite: true` if you have verified line-by-line that **100% of existing public symbols and cross-phase contracts** are preserved in the new file content.

### Law 3: Zero Lazy, Summary, or Placeholder Code
Summary code, stubbed handlers, and omitted blocks are strictly forbidden across the entire monorepo:
- **Forbidden Comments & Stubs**: Never write `// TODO`, `// FIXME`, `// ... existing code ...`, `// implement later`, `throw UnimplementedError()`, or empty `{}` catch blocks that silently swallow errors without deterministic fallback.
- **No Geometric or Algorithmic Downgrades**: When `design.md` specifies 3D right-handed perspective math, `ui.Vertices` triangle meshes, custom fragment/canvas shaders, or PL/pgSQL `FOR UPDATE` row-locking RPCs, implement the complete mathematical and transactional pipeline—never substitute flat `canvas.drawOval` placeholders or unlocked queries.
- **Full Error & Loading States**: Every UI component and API route must implement its complete EARS error boundary, offline outbox fallback, and loading state as specified in `requirements.md`.

### Law 4: Authentic Monorepo Imports, Design Tokens & Zero Raw Emojis (`STD-UIUX-001`)
All Flutter (`apps/vhunambi_client`) code must use authentic workspace symbols:
- **Package Name**: Always `import 'package:vhunambi_client/...';` (NEVER `package:vhunambi/...`).
- **Vector Icons (`STD-UIUX-001`)**: Always `import 'package:phosphor_icons/phosphor_icons.dart';` with `PhosphorIcon(PhosphorIconsBold.*)`, `PhosphorIconsRegular.*`, or `PhosphorIconsFill.*` (NEVER `package:phosphor_flutter/...` and **ZERO raw Unicode emojis** in UI strings, badges, or formal comments).
- **Color Tokens (`AppColors`)**: Use `AppColors.darkSurfaceCanvas`, `AppColors.darkSurfaceElevated`, `AppColors.darkSurfaceSecondary`, `AppColors.darkSurfaceModal`, `AppColors.darkBorderSubtle`, `AppColors.brandPrimary`, `AppColors.badgeCyan`, `AppColors.coinGold`, `AppColors.success`, `AppColors.warning`, `AppColors.error`, `AppColors.surfaceElevatedOf(context)`, `AppColors.textPrimaryOf(context)`, `AppColors.textSecondaryOf(context)`. Never invent nonexistent token names (`obsidianBg`, `surfaceCard`) or hardcode raw hex colors in widgets when a semantic token exists.
- **Typography Tokens (`AppTypography`)**: Use `AppTypography.displayLarge`, `displayMedium`, `titleLarge`, `titleMedium`, `titleSmall`, `bodyLarge`, `bodyMedium`, `bodyMuted`, `bodySmall`, `caption`, `badge`, `bouncyDisplayLarge`, `bouncyTitleLarge`, `bouncyBadge`. Never reference nonexistent `AppTypography.labelSmall` or `AppTypography.labelMedium`.
- **Touch Target Ergonomics**: Every interactive button, icon button, chip, or slider must enforce a minimum $44 \times 44\text{dp}$ hit target (`ConstrainedBox(constraints: const BoxConstraints(minWidth: 44, minHeight: 44))`).

### Law 5: Anti-Hang Test Discipline (Zero 10-Minute Timeouts)
Widget and unit tests in `apps/vhunambi_client/test/` and `apps/vhunambi_api/src/` must execute deterministically in seconds—never hanging for 10+ minutes:
- **Ban Unbounded `pumpAndSettle()` on Animated Trees**: Many Vhunambi screens and drawers run continuous 60 FPS animations (`AnimationController.repeat()`, audio-reactive visualizers, pulse indicators, shimmer effects, or periodic timers). Calling `await tester.pumpAndSettle()` on these trees causes `flutter test` to hang until the 10-minute test runner timeout expires! Always use bounded frame steps:
  ```dart
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  ```
- **Zero Live Network / Real Socket Delays in Tests**: Never allow unit or widget tests to make real HTTP calls or wait on 15s–30s `Dio` connection timeouts. Always inject fake/mock repositories or custom `HttpClientAdapter` stubs that resolve deterministically within `< 50ms`.
- **Mandatory Static L1 Cache & Hive Sanitization Between Tests**: Because Phase 60 repositories (`WalletLedgerRepository`, `PlaybackSessionRepository`, `StemDspRecipeRepository`, `CrateMpcKitsRepository`, `ExploreCacheRepository`, `SocialReelsCacheRepository`, `SovereignPrefsRepository`) maintain static in-memory L1 caches alongside Hive boxes, every multi-user or account-transition test MUST reset static L1 state (`WalletLedgerRepository.clearForTesting()`, `PlaybackSessionRepository.clearForTesting()`, `StemDspRecipeRepository.clearForTesting()`, etc.) in `setUp`/`tearDown` and inside `SovereignHiveAccountSanitizer.sanitizeForAccountTransition()`.
- **Always Run Targeted Tests with Explicit `--timeout=60s`**: When verifying a milestone, run the specific test file with `--timeout=60s` (`flutter test test/path/to/test_file.dart --timeout=60s`) so any accidental infinite loop fails fast in 60 seconds instead of stalling the session for 10–30 minutes.

### Law 6: Cross-Phase Bridge & Runtime Hygiene
Guard against the classic cross-phase and multi-runtime traps:
1. **Dart Lexical Scope Collision Prevention**: When a file defines both top-level utility functions (e.g., `String canonicalizeCreatorId(String raw)`) and a static utility class with the same method name (`CreatorIdUtils.canonicalizeCreatorId(String raw)`), never call the bare function name inside the class method (Dart resolves bare identifiers inside a class to the static method itself, causing infinite recursion `StackOverflowError`!). Always delegate both to a private top-level `_canonicalizeCreatorIdImpl(raw)` helper.
2. **Cloudflare Workers (`workerd`) V8 Isolate Safety in `apps/vhunambi_api`**:
   - Never use top-level static `import { DatabaseSync } from 'node:sqlite'` or unguarded top-level `fs.mkdirSync()` in modules loaded by `src/worker.ts`.
   - Always check `isNodeSqliteAvailable()` (`typeof process !== 'undefined' && typeof process.getBuiltinModule === 'function' && Boolean(process.getBuiltinModule('node:sqlite'))`) before touching `vhunambiDb` in dual-mode stores (`job_store.ts`, `auth_middleware.ts`, `vhunambi_db.ts`).
   - Guard Node-only process metrics (`typeof process.uptime === 'function'`, `typeof process.memoryUsage === 'function'`) in health and telemetry endpoints.
3. **Phase 60 $\leftrightarrow$ Phase 61 $\leftrightarrow$ Phase 62 Vault & Session Continuity**:
   - Keep both `HiveAesVaultCipher.createCipher()` and `HiveAesVaultCipher.buildCipher()` alive.
   - Ensure `SovereignAuthRepository.clearSession()` deletes only `sovereign_auth_session_v1` (`tokenBox.delete(sessionStorageKey)`) rather than calling `tokenBox.clear()`, preserving `'onboarding_state_v1'` across sign-outs.
   - Preserve both `vhunambiDb.getWallet(creatorId)` and `vhunambiDb.getWalletSnapshot(creatorId)` in `apps/vhunambi_api/src/db/vhunambi_db.ts`.

### Law 7: Sequential Milestone-by-Milestone Execution & Micro-Gating
Never dump edits across 25 files across all milestones at once without intermediate verification. Execute strictly one milestone (`MX.1`, then `MX.2`, ..., `MX.N`) at a time:
1. Read the milestone tasks in `tasks.md` and corresponding sections in `design.md`, `requirements.md`, and `blueprint.md`.
2. Read every existing file touched by that milestone before editing.
3. Apply the surgical edits or create the new files for that milestone.
4. Immediately run the milestone's **Micro-Gate**:
   - For TypeScript (`apps/vhunambi_api`): `npx tsc --noEmit` + the milestone's node test (`node --import tsx --test src/<test_file>.ts`).
   - For Python (`tools/zr-studio-gpu`): `python -m py_compile handler.py`.
   - For Flutter (`apps/vhunambi_client`): `dart analyze <modified_dart_files>` + `flutter test <milestone_test_file> --timeout=60s`.
5. Fix any compiler, analyzer, or test failure immediately while the context of that single milestone is fresh.
6. Mark the completed tasks `[x]` in `tasks.md` using `edit_file` before advancing to the next milestone.

### Law 8: Full-Stack Final Sign-Off Gate
A phase execution is NOT complete until all applicable stack gates pass with zero errors and `tasks.md` has every milestone checked off (`[x]`).

---

## 3. Step-by-Step Stage 4 Execution Playbook

When invoked (via `/vhunambi-executioner` or a phase implementation prompt), follow this exact workflow:

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ STEP 1: PHASE SUITE INGESTION & MILESTONE QUEUE INITIALIZATION              │
│  • Read docs/phases/phase_XX_.../tasks.md, requirements.md, blueprint.md,    │
│    and design.md.                                                            │
│  • Identify which milestones [ ] remain unchecked in tasks.md.               │
├──────────────────────────────────────────────────────────────────────────────┤
│ STEP 2: PER-MILESTONE PRE-FLIGHT FILE INSPECTION                             │
│  • For active Milestone MX.Y, read every existing target file first.         │
│  • Diff existing public exports/constants/methods against design.md so zero  │
│    existing callers are broken.                                              │
├──────────────────────────────────────────────────────────────────────────────┤
│ STEP 3: PRODUCTION-COMPLETE IMPLEMENTATION (ZERO LAZY CODE)                  │
│  • Apply surgical edits (edit_file) or create new files (write_file).        │
│  • Enforce exact Keys('...'), EARS error branches, and authentic tokens.     │
├──────────────────────────────────────────────────────────────────────────────┤
│ STEP 4: MILESTONE MICRO-GATE (ANALYZE + BOUNDED-TIMEOUT TEST)                │
│  • Run tsc --noEmit / dart analyze / python -m py_compile.                   │
│  • Run milestone unit/widget test with --timeout=60s.                        │
│  • Update [x] checkboxes in tasks.md for Milestone MX.Y.                     │
├──────────────────────────────────────────────────────────────────────────────┤
│ STEP 5: FULL-STACK CONVERGENCE & HANDOFF GATE                                │
│  • Run full analyzer & test suites across modified packages.                 │
│  • Present concise verification report with clickable file:/// links.        │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Reference Checklist

Before finalizing any milestone or full phase execution, verify your work against:
- [`references/STAGE4_EXECUTION_VERIFICATION_CHECKLIST.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/.agents/skills/vhunambi-executioner/references/STAGE4_EXECUTION_VERIFICATION_CHECKLIST.md)

