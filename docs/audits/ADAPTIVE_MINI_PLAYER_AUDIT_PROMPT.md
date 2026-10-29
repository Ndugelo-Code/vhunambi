# 🔍 Audit Brief & Prompt: Adaptive Mini Player & Now Playing Cockpit (Spec 3 / VH-014..017)

> **Document Type:** Read-Only Audit Brief & Inspection Prompt  
> **Target Subsystem:** Audio Transport, Mini Player Host & Now Playing Modal  
> **Protocol Authority:** Lead Architect (Antigravity IDE)  
> **Auditor & Implementer:** Cline / DeepSeek V4 Flash  
> **Standard:** [`docs/DUAL_AGENT_AUDIT_IMPROVE_WORKFLOW.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/DUAL_AGENT_AUDIT_IMPROVE_WORKFLOW.md)  
> **Target Files:**  
> - `apps/vhunambi_client/lib/features/player/presentation/widgets/mini_player_host.dart`  
> - `apps/vhunambi_client/lib/features/player/presentation/widgets/mobile_mini_player.dart`  
> - `apps/vhunambi_client/lib/features/player/presentation/widgets/card_form.dart`  
> - `apps/vhunambi_client/lib/features/player/presentation/widgets/pill_form.dart`  
> - `apps/vhunambi_client/lib/features/player/presentation/widgets/expanded_cockpit_modal.dart`  
> - `apps/vhunambi_client/lib/features/player/presentation/providers/mini_player_controller.dart`  
> - `apps/vhunambi_client/lib/main.dart`  

---

## 1. Audit Mission & Guidelines

Inspect the target files line-by-line in **read-only mode** to verify alignment with 2026 Mobile & Desktop Audio Workstation Standards, Apple HIG / Material 3 touch ergonomics, and the 4-document specification under `docs/phases/adaptive-mini-player/`.

Do not edit code during this audit. Produce a structured Audit Report covering the 8 standardized dimensions below.

---

## 2. The 8-Dimension Audit Scorecard

### Dimension 1: Dock & Navigation Geometry
- Does `MiniPlayerHost` coordinate cleanly with `VhunambiBottomDockMetrics`?
- Is there duplicate rendering between `RootShell` (lines 191-203 in `main.dart`) and the `MaterialApp.builder` overlay?
- Does `MiniPlayerController.reservedBottom` return `0.0` when in Card or Pill forms so screens can use the full viewport?

### Dimension 2: Top Bar & Header Geometry
- When the player is in `PillForm` (top extreme zone), does its position respect `VhunambiTopBarMetrics.totalHeight(context)` without overlapping top bar actions or system status bars?

### Dimension 3: Touch Targets & Ergonomics (44×44px Mandate)
- Measure bounding boxes of all interactive controls:
  - Play/Pause, Previous, Next in `BarForm`
  - Drag hit-bounds and tap-to-expand in `CardForm`
  - Play/Pause in `PillForm`
  - All 12 buttons in `ExpandedCockpitModal`
- Are any controls smaller than 44×44dp?

### Dimension 4: Surface & Frosted Materials
- Are surfaces utilizing `AppColors.surfaceElevated` with appropriate frosted backdrop blur?
- Are borders and accents derived from `VhunambiThemeExtension.of(context)`?
- Are there any raw hex `#...` values or un-tokenized colors?

### Dimension 5: Responsive Viewport Layout
- How does the player behave on small mobile screens (360dp width)?
- Does the action strip in `ExpandedCockpitModal` overflow horizontally on narrow viewports?
- Does Desktop (> 1024px) cleanly fall back to `DesktopTransportBar` without overlay collision?

### Dimension 6: State Preservation & Route Trapping
- Examine `MiniPlayerHost._shouldHide()`: Does it rely on `ModalRoute.of(context)` inside `MaterialApp.builder` where context returns `null`?
- Does `SharedPreferences` persistence survive device rotation and process recreation?

### Dimension 7: Keyboard & Accessibility
- Does `MiniPlayerHost` immediately hide when the software keyboard opens (`viewInsets.bottom > 0`)?
- Does `PillForm` respect `AccessibilityService.isReduceMotionEnabled(context)` and bypass 30fps periodic glow timers?
- Are interactive controls assigned descriptive `Semantics`?

### Dimension 8: Test Pins & Guardrails
- Are all mandatory widget keys present:
  - `Key('mini_player_host')`
  - `Key('mini_player_bar')`
  - `Key('mini_player_card')`
  - `Key('mini_player_pill')`
  - `Key('mini_player_play_pause')`
  - `Key('mini_player_prev')`
  - `Key('mini_player_next')`
  - `Key('cockpit_repeat_btn')`
  - `Key('cockpit_shuffle_btn')`
  - `Key('cockpit_stems_btn')`
  - `Key('cockpit_share_btn')`
- Do existing 98 player tests remain protected?

---

## 3. Required Output Format for Audit Report

Produce your report following this markdown structure:
1. **Executive Assessment & Gap Scorecard (1-10 on each dimension)**
2. **Detailed Finding Inventory (File, Line Number, Finding, Impact, Proposed Fix)**
3. **Identified Test Guardrails (List of existing test pins that must not break)**
4. **Phased Implementation Recommendation (Wave 1 to Wave 4)**
