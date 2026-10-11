# 🏛️ AUDIT BRIEF & PROMPT: Universal Audio Transport & Bottom Navigation Dock System
**Target Agent:** Cline (Plan Mode / Audit Mode — Read-Only Review)  
**Target Codebase:** `apps/vhunambi_client` (Flutter / Dart)  
**Scope:** Bottom Navigation Bar, Persistent Floating Mini Player, Expanded Now-Playing Cockpit, Gestures, and Viewport Occlusion  

---

## 🎯 Mission Statement & Purpose
You are acting as an **independent, unbiased Principal Mobile Systems Architect and Audio UX Design Lead**.

Your objective is to conduct a rigorous, zero-bias audit of the **Universal Audio Transport and Bottom Navigation Dock System** in the Vhunambi codebase.

Vhunambi is a high-performance African AI Music Workstation and Social Creator Network built for 2026 mobile standards. Now that the **Top Bar and Platform Navigation System** has been unified with safe-area geometry, canonical back affordances, and frosted glass, the bottom half of the mobile shell requires the same high-caliber architectural treatment.

The mobile music workstation experience relies entirely on the persistent bottom dock: switching root tabs, tracking playback via the floating mini player, expanding into the full-screen now playing cockpit, and adjusting stem balances. Currently, **the mini player, bottom navigation bar, touch targets, and viewport scroll padding suffer from layout squishing, touch target violations (<44px), flat styling, and missing gesture physics**.

Your goal is to thoroughly audit the current implementation, expose every flaw, vulnerability, and UX friction point, and deliver an uncompromising architectural blueprint for a unified, state-of-the-art 2026 bottom dock and audio transport system.

---

## 📂 Primary Code Files to Audit

Review and cross-examine the following files in the repository:

### 1. Root Shell & Bottom Dock Integration
* [`apps/vhunambi_client/lib/main.dart`](file:///apps/vhunambi_client/lib/main.dart):
  * `RootShell.build()`: Scaffold stack layering `IndexedStack`, persistent `MobileMiniPlayer` (`bottom: 0`), and standard `BottomNavigationBar`.
  * Interaction between `BottomNavigationBar` and `MobileMiniPlayer`.
  * Safe-area handling on modern notched/gesture-bar devices (iPhone home indicator, Android gesture bar).

### 2. The Persistent Mini Player
* [`apps/vhunambi_client/lib/features/player/presentation/widgets/mobile_mini_player.dart`](file:///apps/vhunambi_client/lib/features/player/presentation/widgets/mobile_mini_player.dart):
  * 60px flat container pinned directly above the bottom nav bar.
  * 2px `LinearProgressIndicator` scrub line.
  * Touch targets on transport buttons:
    * Skip Previous: `BoxConstraints(minWidth: 32, minHeight: 32)` (Violation).
    * Play/Pause Orb: 36×36px container (Violation).
    * Skip Next: `BoxConstraints(minWidth: 32, minHeight: 32)` (Violation).
    * Dismiss Button: `BoxConstraints(minWidth: 28, minHeight: 28)` (Violation).
  * Horizontal drag gestures (`onHorizontalDragEnd`) vs expansion tap (`onTap: onExpand`).
  * Missing vertical drag-to-expand gesture physics.

### 3. The Expanded Now Playing Cockpit
* [`apps/vhunambi_client/lib/features/player/presentation/widgets/expanded_cockpit_modal.dart`](file:///apps/vhunambi_client/lib/features/player/presentation/widgets/expanded_cockpit_modal.dart):
  * `showModalBottomSheet()` with fixed `0.88` screen height multiplier.
  * Drag handle, dismiss arrow chevron (`Icons.keyboard_arrow_down_rounded`), and route transition ergonomics.
  * Artwork presentation, genre gradient background, and vinyl/rotor visualizer.
  * Scrub bar, audio time formatting, and live position seeker.
  * Integration with Stem Mixer Deck (`stem_mixer_deck.dart`) and Queue Drawer (`queue_drawer.dart`).
  * Video Export modal and Content Studio Quick Action triggers.

### 4. Desktop Audio Transport Bar (For Parity & Contrast)
* [`apps/vhunambi_client/lib/features/player/presentation/widgets/desktop_transport_bar.dart`](file:///apps/vhunambi_client/lib/features/player/presentation/widgets/desktop_transport_bar.dart):
  * Layout differences, volume slider, stem mixer popover, queue drawer.

### 5. Viewport Occlusion Across Primary Screens
* [`apps/vhunambi_client/lib/features/home/presentation/views/home_dashboard_view.dart`](file:///apps/vhunambi_client/lib/features/home/presentation/views/home_dashboard_view.dart)
* [`apps/vhunambi_client/lib/features/explore/presentation/views/explore_view.dart`](file:///apps/vhunambi_client/lib/features/explore/presentation/views/explore_view.dart)
* [`apps/vhunambi_client/lib/features/library/presentation/views/library_view.dart`](file:///apps/vhunambi_client/lib/features/library/presentation/views/library_view.dart)
* [`apps/vhunambi_client/lib/features/marketplace/presentation/views/marketplace_view.dart`](file:///apps/vhunambi_client/lib/features/marketplace/presentation/views/marketplace_view.dart)
  * Verify whether list/grid slivers have dynamic bottom padding to prevent items from being permanently hidden behind the mini player dock!

---

## 🔍 Specific Audit Dimensions

You must assess the codebase across the following 5 critical dimensions:

### Dimension 1: Mini Player Touch Ergonomics & HIG/WCAG Compliance
* **The Intended Vision:** Apple Human Interface Guidelines and WCAG 2.5.5 mandate a minimum 44×44px hit target for all interactive touch controls.
* **The Current Defect:**
  * In `MobileMiniPlayer`, all 4 controls (Skip Previous 32×32, Play/Pause 36×36, Skip Next 32×32, Dismiss 28×28) fall severely below the 44px threshold, causing mis-taps during transit or one-handed operation.
* **Audit Questions for Cline:**
  1. How can we guarantee 44×44px minimum hit targets for transport buttons in a compact 60px mini player without visual clutter?
  2. Should secondary actions (like dismiss) be gesture-based (swipe down) rather than consuming valuable horizontal button real estate?

### Dimension 2: Visual Aesthetics — Flat Box vs 2026 Floating Frosted Island
* **The Current Defect:**
  * `MobileMiniPlayer` is rendered as an opaque `surfaceElevated` rectangular box with a flat 1px border sitting flush against `BottomNavigationBar`.
  * Modern 2026 audio streaming applications (Apple Music, Spotify, Tidal) treat the mini player as a **floating pill or frosted glass card** hovering with subtle elevation, rounded corners, ambient blur (`BackdropFilter`), and reactive artwork glow.
* **Audit Questions for Cline:**
  1. How should the mini player surface be styled using our design tokens (`AppColors.surfaceModal`, `AppRadius.inputBorder`, `BackdropFilter`, and subtle hairline border)?
  2. How should the mini player sit relative to the bottom navigation bar (floating pill with 8px margin vs docked panel)?

### Dimension 3: Gesture Physics & Expansion Lifecycle
* **The Intended Vision:** A seamless, tactile gesture system where tapping or dragging the mini player upward smoothly transitions into the full-screen now playing cockpit, and dragging down collapses it.
* **The Current Defect:**
  * Only horizontal swipe is implemented for next/previous. Expanding requires an explicit tap on the artwork or title.
  * Tapping opens `showModalBottomSheet()` with a generic slide transition rather than a fluid shared-axis or hero expansion.
* **Audit Questions for Cline:**
  1. How should vertical drag-to-expand be implemented cleanly without conflicting with horizontal track-skipping gestures?
  2. How can the transition to `ExpandedCockpitModal` feel instantaneous and organic?

### Dimension 4: Viewport Occlusion & Bottom Scroll Metrics (`VhunambiBottomDockMetrics`)
* **The Current Defect:**
  * In `RootShell`, when `hasActiveTrack` is true, the mini player occupies 60px directly above the bottom nav bar (56px). Together with bottom safe area (34px on iPhones), the bottom occlusion is ~150px!
  * Scrollable views (`ExploreView`, `LibraryView`, etc.) currently have hardcoded or insufficient bottom padding (e.g. `SizedBox(height: 80)`), causing the last cards or list items to be partially or completely obscured under the mini player!
* **Audit Questions for Cline:**
  1. How should we formalize a `VhunambiBottomDockMetrics` class (matching `VhunambiTopBarMetrics`) that dynamically computes:
     `totalBottomInset = bottomSafeArea + navBarHeight + (hasActiveTrack ? miniPlayerHeight + margin : 0)`?
  2. How can all scrollable tabs consume this inset to guarantee zero occlusion?

### Dimension 5: Bottom Navigation Bar Modernization
* **The Current Defect:**
  * The bottom bar is an un-customized standard `BottomNavigationBar` in `Scaffold`.
  * Lacks blur, lacks glowing active indicators, and does not match the premium frosted glass aesthetic of `VhunambiTopBarSurface`.
* **Audit Questions for Cline:**
  1. How should the bottom navigation dock be updated to match the 2026 frosted glass styling (`VhunambiTopBarSurface` counterpart)?
  2. How should tab transitions, active pill indicators, and haptic feedback be coordinated?

---

## 📝 Required Audit Output Deliverables

In your audit report, please provide:

1. **Executive Summary & Verdict:** Honest score (1–10) on the current bottom dock and audio transport system.
2. **Defect & Friction Matrix:** A structured table listing each issue, file and line number, severity (Critical, High, Medium), and UX impact.
3. **The 2026 Floating Mini Player Blueprint:** Exact component structure, styling specification, and 44×44px touch layout.
4. **Viewport Occlusion Mathematical Specification (`VhunambiBottomDockMetrics`):** Sizing formula to permanently eliminate bottom content clipping.
5. **Phase-by-Phase Implementation Roadmap:** Actionable steps to execute the transformation without breaking existing audio provider state or tests.
