# 🚀 CLINE HANDOFF: Spec 3 — Adaptive Mini Player & Now Playing Cockpit (VH-014 to VH-017)

> **Document Type:** Master Implementation Handoff & Prompt Contract  
> **Target Agent:** Cline / DeepSeek V4 Flash (1M Context Headroom)  
> **Lead Architect & QA Gatekeeper:** Antigravity IDE  
> **Status:** Ready for Execution  
> **Baseline Health:** `flutter analyze` = **0 issues (100% clean)** | `flutter test` = **1,030+ passing (100% green)**  
> **Target Workspace:** `apps/vhunambi_client`  
> **Authoritative Specifications (4-Doc Suite):**  
> - [`docs/phases/adaptive-mini-player/blueprint.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/adaptive-mini-player/blueprint.md)  
> - [`docs/phases/adaptive-mini-player/requirements.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/adaptive-mini-player/requirements.md)  
> - [`docs/phases/adaptive-mini-player/design.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/adaptive-mini-player/design.md)  
> - [`docs/phases/adaptive-mini-player/tasks.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/adaptive-mini-player/tasks.md)  

---

## 1. Executive Summary & Mission

You are implementing **Spec 3: Adaptive Mini Player & Now Playing Cockpit (VH-014 through VH-017)** for VHUNAMBI. This feature transforms the existing fixed 64px docked player bar into a fluid, context-aware interface that adapts to user needs and screen content, freeing up critical workspace real estate during AI song generation.

### Core Deliverables:
1. **VH-014 (P0): Three Morphing Forms & Gestures**:
   - **Bar Form**: Full-width docked strip above navigation with complete transport.
   - **Card Form**: 128×128dp square floating card with cover gradient and progress percentage.
   - **Pill Form**: 160×48dp capsule with 30fps amplitude reactive cover glow.
   - **Gestures**: Hold-drag activation (350ms, scale 1.03), extreme zone morphing, and horizontal fling dismiss (>250 px/s).
2. **VH-015 (P0): Flutter Material Transparency Fix**:
   - Wrap `MiniPlayerHost` and `ExpandedCockpitModal` root widgets in `Material(type: MaterialType.transparency)` to permanently banish yellow underlines on text.
3. **VH-016 (P1): Wire 12 Now Playing Controls**:
   - Fully wire all buttons in `ExpandedCockpitModal`: Repeat mode cycle (`AudioRepeatMode.off` → `all` → `one`), Shuffle toggle, Stem Mixer trigger, Share sheet, Lyrics toggle, and Like optimism.
4. **VH-017 (P1): Now Playing Layout Hardening**:
   - Resolve horizontal action row overflow on 360dp mobile viewports using a responsive wrapping row or scrollable horizontal strip.

---

## 2. Verified Foundations Established by Chief Architect (Antigravity)

Before this handoff, Antigravity verified repository health and completed the foundation groundwork:
1. **Design System Tokens (Spec 4)** are registered and sealed in `main.dart` (`TokenRegistration.registerAllTokens()`, `DesignTokenRegistry.seal()`).
2. **Audio repeat enum** is strictly named `AudioRepeatMode` (`off`, `all`, `one`) to avoid collision with Flutter 3.44's SDK.
3. **Player baseline tests** (98/98) and studio tests (196/196) are 100% passing.
4. **Draft components** exist in `lib/features/player/presentation/`:
   - `providers/mini_player_controller.dart`
   - `widgets/mini_player_host.dart`
   - `widgets/card_form.dart`
   - `widgets/pill_form.dart`

---

## 3. Strict Codebase Invariants & Non-Negotiable Rules

1. **Zero Raw Hex Colors**:
   - Always resolve colors through `AppColors.*` or `VhunambiThemeExtension.of(context).*`.
2. **Zero Raw Typography**:
   - Always use `AppTypography.*` from `lib/core/theme/app_typography.dart`.
3. **Touch Targets (WCAG 2.5.5 / Apple HIG)**:
   - Every tap target (buttons, icons, chips) must have a minimum interactive bounding box of **44×44dp** (`minHeight: 44, minWidth: 44`).
4. **Enum Safety**:
   - Never use `RepeatMode`. Always use `AudioRepeatMode`.
5. **Animation & Timer Safety**:
   - In `PillForm`, always cancel `Timer? _amplitudeTimer` inside `dispose()`.
   - Never call `setState()` without an `if (!mounted) return;` guard.
   - Respect `AccessibilityService.isReduceMotionEnabled(context)`.
6. **Mandatory Widget Keys**:
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

---

## 4. Implementation Steps (Ordered Dependency Waves)

### Wave 1: Controller & Navigation Route Trapping
1. **Fix route detection in `lib/features/player/presentation/widgets/mini_player_host.dart`**:
   - Do NOT use `ModalRoute.of(context)` inside `MaterialApp.builder` as it returns `null`.
   - Use an inherited route listener or `NavigatorObserver` callback to hide the player on `/splash`, `/onboarding`, and `/auth`.
2. **Coordinate with `RootShell` (`lib/main.dart`)**:
   - Ensure `MobileMiniPlayer` is rendered via `MiniPlayerHost` overlay so it is not duplicated.
   - Preserve `DesktopTransportBar` for desktop viewports (`ResponsiveUtils.isDesktop(context)`).

### Wave 2: The Three Player Forms
1. **`MobileMiniPlayer` (Bar Form)**:
   - Attach `Key('mini_player_bar')`.
   - Ensure 44×44dp touch targets on play/pause, previous, and next.
   - Wire visual disable state (opacity 0.38) at queue boundaries when repeat mode is off.
2. **`CardForm`**:
   - Ensure 128×128dp square container with `AppRadius.cardBorder` (12dp).
   - Genre gradient background with glowing border using `VhunambiThemeExtension.of(context).genreAccent`.
   - Horizontal snap physics (16dp inset from screen edge on drag release).
3. **`PillForm`**:
   - 160×48dp capsule layout with 32dp circular cover avatar.
   - 30fps amplitude reactive glow with `PaletteGenerator` extraction.
   - Reduce-motion fallback: static ambient shadow when enabled.
   - Safe timer disposal in `dispose()`.

### Wave 3: Gesture Engine & Obstacle Avoidance
1. **`PlayerObstacle` widget**:
   - Create `lib/features/player/presentation/widgets/player_obstacle.dart` to register bounding `Rect` with `MiniPlayerController`.
   - Wrap the bottom studio dock with `PlayerObstacle(id: 'content_studio_dock')`.
2. **Extreme Zones & Fling in `MiniPlayerHost`**:
   - Hold gesture (350ms): medium haptic impact, scale 1.03.
   - Top 72dp zone: morphs to `PillForm`.
   - Bottom 120dp zone: morphs to `BarForm` & re-engages auto mode.
   - Fling gesture (>250 px/s): 180ms slide off-screen, call `playerNotifier.stop()`, clear active track.

### Wave 4: Now Playing Cockpit Hardening
1. **`ExpandedCockpitModal` (`lib/features/player/presentation/widgets/expanded_cockpit_modal.dart`)**:
   - Ensure root is wrapped in `Material(type: MaterialType.transparency)`.
   - Wire repeat mode button to cycle `AudioRepeatMode`.
   - Wire shuffle button to toggle `playerNotifier.toggleShuffle()`.
   - Wire stems button to open `StemMixerDeck`.
   - Wire share button to open system share sheet or clipboard confirmation.
   - Replace rigid overflowing row with a scrollable/wrapping action deck.

---

## 5. Verification Commands for Cline

Run these commands in `apps/vhunambi_client` before declaring completion:

```powershell
cd apps/vhunambi_client

# 1. Static Analysis Gate (0 issues required)
flutter analyze

# 2. Player Test Suite Gate
flutter test test/features/player/

# 3. Studio & Onboarding Regression Checks
flutter test test/features/studio/
flutter test test/features/onboarding/
```

---

## 6. Guarded Master Prompt for Cline

Copy and paste this exact prompt to invoke Cline for implementation:

```text
You are acting as the Implementation Specialist for VHUNAMBI under the Dual-Agent Pair Programming Standard.

YOUR MISSION:
Implement Spec 3: Adaptive Mini Player & Now Playing Cockpit (VH-014 through VH-017) adhering strictly to:
- docs/CLINE_HANDOFF_SPEC_3_ADAPTIVE_MINI_PLAYER.md
- docs/phases/adaptive-mini-player/blueprint.md
- docs/phases/adaptive-mini-player/requirements.md
- docs/phases/adaptive-mini-player/design.md
- docs/phases/adaptive-mini-player/tasks.md

KEY INVARIANTS:
1. Never use raw hex values; use AppColors or VhunambiThemeExtension.
2. Every interactive control must have a minimum 44×44dp touch target.
3. Audio repeat mode is strictly named AudioRepeatMode (never RepeatMode).
4. Wrap MiniPlayerHost and ExpandedCockpitModal in Material(type: MaterialType.transparency) to prevent yellow underlines.
5. In PillForm, always cancel _amplitudeTimer in dispose() and check mounted before setState.
6. Fix the ModalRoute.of(context) null issue in MaterialApp.builder using a navigator observer or route listener.
7. Ensure all widget keys specified in section 3 are present.

VERIFICATION TARGET:
flutter analyze reports 0 issues.
flutter test test/features/player/ passes 100% green without flaky timer leaks.
```
