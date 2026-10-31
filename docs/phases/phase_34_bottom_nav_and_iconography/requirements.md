# 📋 Phase 34 Requirements: Mobile Bottom Navigation & Phosphor Iconography

**Phase Identifier:** `PHASE-34-NAV-ICON`  
**Status:** Approved for Implementation  

---

## 1. Functional Requirements

### 1.1 Mobile Bottom Navigation (`VhunambiMobileBottomNav`)
- **REQ-NAV-01 (Zero-Flash Interaction):** The bottom navigation bar MUST NOT trigger Material 2/3 `InkResponse` highlight blooms or white splashes on touch-down. Pressing and holding any tab must remain completely clean on dark frosted glass with zero "cracked screen" flash glow.
- **REQ-NAV-02 (Soft Ambient Capsule Indicator):** The active tab MUST be indicated by a soft, rounded capsule (`AppColors.brandPrimary.withAlpha(25)`, `borderRadius: 16dp`) that smoothly translates and animates between tabs with `Curves.easeOutCubic` over $220\text{ms}$.
- **REQ-NAV-03 (Elevated Center "Create" Orb):** Tab 2 (`Create`) MUST feature an elevated hero presentation with `AppGradients.brandGlow`, circular/pill geometry, and `PhosphorIconsFill.sparkle`, maintaining 48×48dp minimum touch bounds.
- **REQ-NAV-04 (Single-Channel Curated Haptics):** Tab switches MUST fire `HapticsService().selectionClick()` without framework-level double-click interference. Tapping an already active tab MUST NOT trigger unnecessary vibration or flash glows.
- **REQ-NAV-05 (Double-Tap / Reselect Action):** Tapping the already-active tab MUST trigger `HapticsService().lightImpact()` and support an optional `onReselect` callback (e.g. scroll to top).
- **REQ-NAV-06 (Touch Target Geometry):** Every tab MUST provide $\ge 48 \times 48\text{dp}$ touch target bounds, fully compliant with Apple HIG and Android Accessibility requirements.
- **REQ-NAV-07 (Automation Test Keys):** The 5 tabs MUST be tagged with exact keys:
  - `Key('mobile_nav_tab_0')` — Home
  - `Key('mobile_nav_tab_1')` — Explore
  - `Key('mobile_nav_tab_2')` — Create
  - `Key('mobile_nav_tab_3')` — Library
  - `Key('mobile_nav_tab_4')` — Market

---

### 1.2 Iconography System (`AppIcons`)
- **REQ-ICON-01 (Package Integration):** The client application MUST integrate `phosphor_icons: ^3.0.1` in `pubspec.yaml`.
- **REQ-ICON-02 (Centralized Token Registry):** All standard application icons MUST be centralized in `lib/core/design_system/tokens/app_icons.dart` (`AppIcons`), exposing style-specific Phosphor icons with rounded terminals (`StrokeCap.round`).
- **REQ-ICON-03 (Deprecation of Emojis as UI Icons):**
  - Home Dashboard: The Streak pill (`🔥`) and Coin pill (`🪙`) MUST use `PhosphorIcon(AppIcons.flame)` and `PhosphorIcon(AppIcons.coin)`.
  - Profile & Wallet: Profile stats streak, wallet received coins, and tip buttons MUST use vector icons.
  - Studio Cockpit: The 3 segment tabs (`🎵 Songs`, `💿 Releases`, `🎛️ My Beatstore`) MUST use vector icons with clean text labels (`Songs`, `Releases`, `Beatstore`).
- **REQ-ICON-04 (Cultural Gifts Preservation):** Emojis MUST be strictly preserved for user-generated social comments and canonical cultural gifts (`kCulturalGifts`), where they represent authentic cultural fan gifts rather than UI application controls.
- **REQ-ICON-05 (Tree-Shaking Safety):** All Phosphor icon usages MUST reference explicit style classes (`PhosphorIconsRegular.*`, `PhosphorIconsFill.*`, `PhosphorIconsBold.*`, `PhosphorIconsDuotone.*`) to guarantee compile-time font subsetting.

---

## 2. Non-Functional Requirements & Performance
- **REQ-PERF-01 (60/120 FPS Transitions):** Tab indicator sliding and icon scaling animations MUST execute without frame drops or jank on budget mobile devices.
- **REQ-A11Y-01 (Screen Reader Semantics):** Each tab MUST expose proper `Semantics` labels (`label: 'Home tab, 1 of 5'`, etc.) and announce active selection state.
- **REQ-TEST-01 (Test Suite Integrity):** All existing home, explore, profile, player, and marketplace tests MUST pass with 0 regressions.

