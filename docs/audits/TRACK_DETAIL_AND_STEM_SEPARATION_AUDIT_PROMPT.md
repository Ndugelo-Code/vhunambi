# 🏛️ AUDIT BRIEF & PROMPT: Track Details Cockpit & Audio Stem Separation Lab
**Target Agent:** Cline (Plan Mode / Audit Mode — Read-Only Review)  
**Target Codebase:** `apps/vhunambi_client` (Flutter / Dart)  
**Scope:** Track Detail Cockpit (`TrackDetailView`), 4-Stem Separation Lab (`StemSeparationLab`), Pocket Stem Mixer (`StemMixerDeck`), Amplitude Waveform Scrubber (`WaveformScrubber`), Social Actions, Utility Dock, Synchronized Lyrics Teleprompter, and Recommendation Shelves  

---

## 🎯 Mission Statement & Purpose
You are acting as an **independent, unbiased Principal Mobile Audio Workstation Architect and Music-Tech Design Lead**.

Your objective is to conduct a rigorous, zero-bias audit of **The Track Details Cockpit and Audio Stem Separation Lab** in the Vhunambi codebase.

Vhunambi is a high-performance African AI Music Workstation and Social Creator Network built for 2026 mobile standards. The **Top Bar Navigation System**, **Bottom Navigation Dock & Universal Audio Transport**, and **Studio AI Generation Cockpit & MPC Chopper** have all been modernized into high-performance frosted surfaces with mathematical geometry, tabbed progressive disclosure, and 44px touch compliance.

Now we target the core listening and audio dissection surface of the platform: **The Track Detail View (`TrackDetailView`) and the 4-Stem Separation Lab (`StemSeparationLab` & `StemMixerDeck`)**.

Currently, `TrackDetailView` features impressive engineering depth (11 distinct modular components spanning 1:1 artwork, dynamic lyrics formatting, interactive pseudo-amplitude scrubbing, 4-stem DSP simulation, social tipping, emoji reactions, and comment threads). However, **the layout suffers from severe vertical scroll fatigue (11 stacked cards exceeding 3,400px of scroll), zero bottom inset padding (causing content collisions with the universal floating transport), flat/opaque `AppBar` styling, hardcoded magic pixel scroll jumps (`_scrollTo(520)` and `_scrollTo(1100)`), and pervasive touch target violations (24–28px icons on mute, solo, download, like, and audition buttons)**.

Your goal is to thoroughly audit the current implementation, expose every flaw, vulnerability, and UX friction point, and deliver an uncompromising architectural blueprint for a state-of-the-art 2026 mobile track details and stem separation experience.

---

## 📂 Primary Code Files to Audit

Review and cross-examine the following files in the repository:

### 1. Track Detail Root View
* [`apps/vhunambi_client/lib/features/track/presentation/views/track_detail_view.dart`](file:///apps/vhunambi_client/lib/features/track/presentation/views/track_detail_view.dart):
  * `TrackDetailView`: Single column scrolling with 11 stacked widgets.
  * Lines 262–298: Flat `AppBar(backgroundColor: AppColors.surfaceCanvas)` — missing frosted glass blur (`VhunambiTopBar`) and responsive title behavior.
  * Lines 303–512: `SingleChildScrollView` has no bottom inset padding (Defect: collisions with `VhunambiFloatingTransportSurface`).
  * Lines 359 & 361: `onJumpToLyrics: () => _scrollTo(520)` and `onJumpToComments: () => _scrollTo(1100)` — hardcoded magic pixel offsets that break on variable screen densities or lyrics lengths.
  * Lines 436–447: "Open Pocket Stem Mixer" uses generic `showModalBottomSheet(heightFactor: 0.9, backgroundColor: AppColors.surfaceElevated)` lacking 2026 frosted styling, drag handle, and canonical back/close affordance.

### 2. Stem Separation Lab & Pocket Stem Mixer
* [`apps/vhunambi_client/lib/features/track/presentation/widgets/stem_separation_lab.dart`](file:///apps/vhunambi_client/lib/features/track/presentation/widgets/stem_separation_lab.dart):
  * FSM progress indicator (Vocals, Drums, Bass, Instrumental).
  * Lines 226–250: Solo pill button has `vertical: 4` (~20px touch height).
  * Lines 255–268: Mute button has `constraints: const BoxConstraints()` and `padding: const EdgeInsets.all(4)` (28×28px touch area).
  * Lines 273–282: Download stem button has `constraints: const BoxConstraints()` and `padding: const EdgeInsets.all(4)` (28×28px touch area).
* [`apps/vhunambi_client/lib/features/player/presentation/widgets/stem_mixer_deck.dart`](file:///apps/vhunambi_client/lib/features/player/presentation/widgets/stem_mixer_deck.dart):
  * 4-channel console with vertical faders, pan sliders, mute/solo buttons, master Bantu DSP, and bounce master mix.

### 3. Waveform Scrubber & Synchronized Lyrics Teleprompter
* [`apps/vhunambi_client/lib/features/track/presentation/widgets/waveform_scrubber.dart`](file:///apps/vhunambi_client/lib/features/track/presentation/widgets/waveform_scrubber.dart):
  * Play/pause button (line 44): `IconButton(iconSize: 42, padding: EdgeInsets.zero, constraints: const BoxConstraints())` (42×42px touch area, sub-44px).
  * 38-bar pseudo-amplitude scrubbing visualizer.
* [`apps/vhunambi_client/lib/features/track/presentation/widgets/lyrics_teleprompter.dart`](file:///apps/vhunambi_client/lib/features/track/presentation/widgets/lyrics_teleprompter.dart):
  * Bracketed lyrics formatting (`[Verse 1]`, `[Chorus]`, etc.) and language badge.

### 4. Social Engagement, Utility Toolbar & Cultural Reactions
* [`apps/vhunambi_client/lib/features/track/presentation/widgets/track_actions_bar.dart`](file:///apps/vhunambi_client/lib/features/track/presentation/widgets/track_actions_bar.dart):
  * Like pill button: `vertical: 8` (~34px touch height).
  * Remix and Tip buttons: `vertical: 10` (~38px touch height).
* [`apps/vhunambi_client/lib/features/track/presentation/widgets/utility_tool_dock.dart`](file:///apps/vhunambi_client/lib/features/track/presentation/widgets/utility_tool_dock.dart):
  * Line 34: `height: 40` horizontal rail.
  * Line 90: Tool chips have `padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)` (~28px touch height).
* [`apps/vhunambi_client/lib/features/track/presentation/widgets/emoji_reaction_deck.dart`](file:///apps/vhunambi_client/lib/features/track/presentation/widgets/emoji_reaction_deck.dart):
  * 5 cultural reaction pills: `vertical: 7` (~32px touch height).
* [`apps/vhunambi_client/lib/features/track/presentation/widgets/comments_section.dart`](file:///apps/vhunambi_client/lib/features/track/presentation/widgets/comments_section.dart):
  * Lines 234–248: Comment like button has `iconSize: 16, padding: const EdgeInsets.all(4), constraints: const BoxConstraints()` (24×24px touch area).
* [`apps/vhunambi_client/lib/features/track/presentation/widgets/more_like_this_shelf.dart`](file:///apps/vhunambi_client/lib/features/track/presentation/widgets/more_like_this_shelf.dart):
  * Lines 158–167: Play audition button has `iconSize: 26, padding: EdgeInsets.zero, constraints: const BoxConstraints()` (26×26px touch area).
  * Line 28: `margin: const EdgeInsets.fromLTRB(16, 12, 16, 40)` — insufficient bottom clearance.

---

## 🔒 Rigid Test Guardrails (Must Never Break)
Audit the existing test suite in [`test/features/track/track_detail_view_test.dart`](file:///apps/vhunambi_client/test/features/track/track_detail_view_test.dart):
* **Pin 1 — All 11 Components Rendered**: The test explicitly checks that all 11 core dissection widgets exist in the tree (`TrackHeroSection`, `TrackActionsBar`, `UtilityToolDock`, `EmojiReactionDeck`, `WaveformScrubber`, `LyricsTeleprompter`, `StemSeparationLab`, `PromptAttributionCard`, `CommentsSection`, `MoreLikeThisShelf`, plus specific string matches).
* **Pin 2 — Social Toggles**: Likes count increment/decrement contracts in `TrackActionsBar`.
* **Pin 3 — Comment Submission**: Input submission via `Icons.send_rounded`.
* **Pin 4 — Stem Separation FSM**: Pumping `Separate` button transitions through 4 delayed stages to produce `'Vocals'`, `'Drums'`, `'Bass & Log Drums'`, and `'Instrumental'`.

Any proposed architecture MUST keep all 11 component contracts fully mounted and functional.

---

## 🔍 Five Critical Audit Dimensions

You must assess the codebase across the following 5 critical dimensions:

### Dimension 1: Vertical Scroll Fatigue & Bottom Transport Dock Clearance
* **The Current Defect:**
  * 11 distinct modules are stacked linearly, resulting in ~3,400px of scroll.
  * The bottom of the view has only `40px` margin, which causes the bottom recommendations to collide with or be hidden behind `VhunambiFloatingTransportSurface` (active dock requires `VhunambiBottomDockMetrics.scrollInset` + safe area).
* **Audit Questions for Cline:**
  1. How should the Track Detail screen maintain its high functional density while eliminating scroll fatigue? (e.g. sticky playback controls, segmented sub-views, or collapsible sections that keep all 11 test widgets mounted)?
  2. How must `VhunambiBottomDockMetrics.scrollInset` be integrated at the bottom of the scroll view?

### Dimension 2: Frosted Glass Top Bar & Immersive Header Architecture
* **The Current Defect:**
  * `TrackDetailView` uses a basic `AppBar` with flat `surfaceCanvas` and static centered title `"VHUNAMBI"`.
  * As the user scrolls past the 220px album artwork, the track title disappears from view and is not reflected in the top bar.
* **Audit Questions for Cline:**
  1. How should the top bar be upgraded to use frosted glass (`VhunambiTopBar` with `BackdropFilter` blur 16–24 and `AppColors.surfaceCanvas.withAlpha(200)`)?
  2. How should the top bar dynamically display the track title and artist name when scrolled past the hero section?

### Dimension 3: 4-Stem Separation Lab & Pocket Stem Mixer Modal Modernization
* **The Current Defect:**
  * "Open Pocket Stem Mixer" opens a bottom sheet with flat `surfaceElevated`, missing the 2026 frosted modal surface (`AppColors.surfaceModal`), pill drag handle, and canonical back navigation.
  * In `StemSeparationLab`, solo pills are 20px tall, while mute and download buttons are 28×28px.
* **Audit Questions for Cline:**
  1. How should the Pocket Stem Mixer bottom sheet be modernized into an organic, frosted audio workstation sheet matching the Heritage Studio standard?
  2. How should the stem cards in `StemSeparationLab` be restructured for tactile audio control (visual VU levels, distinct solo/mute states, 44px hit constraints)?

### Dimension 4: Section Navigation Ergonomics & Magic Pixel Offsets
* **The Current Defect:**
  * In `UtilityToolDock`, `onJumpToLyrics` calls `_scrollTo(520)` and `onJumpToComments` calls `_scrollTo(1100)`.
  * These hardcoded offsets fail on different screen sizes, orientations, and content lengths.
* **Audit Questions for Cline:**
  1. How can section jumps be rewritten using `GlobalKey` and `Scrollable.ensureVisible` for precision jumping that never misses its target?

### Dimension 5: Touch Ergonomics & HIG/WCAG 44×44px Compliance Sweep
* **The Current Defect:**
  * Multiple interactive elements across `track` widgets violate the 44×44px minimum touch target size:
    * Stem Mute button: 28×28px
    * Stem Download button: 28×28px
    * Stem Solo pill: ~20px height
    * Utility dock rail chips: 28px height (rail height 40px)
    * Social Like button: ~34px height
    * Social Remix & Tip buttons: ~38px height
    * Cultural Emoji reaction pills: ~32px height
    * Comment Like button: 24×24px
    * Recommendation Audition button: 26×26px
    * Waveform play/pause button: 42×42px
* **Audit Questions for Cline:**
  1. How should each of these controls be refactored with `BoxConstraints(minHeight: 44, minWidth: 44)` and centered alignment without disrupting visual typography or card layouts?

---

## 📝 Required Audit Output Deliverables

In your audit report, please provide:

1. **Executive Summary & Verdict:** Honest score (1–10) on the current Track Details and Stem Separation architecture.
2. **Defect & Friction Matrix:** A structured table listing each issue, file and line number, severity (Critical, High, Medium), and UX impact.
3. **The 2026 Track Cockpit Architecture Blueprint:** Proposed layout restructuring (frosted top bar with scroll-aware title, `VhunambiBottomDockMetrics.scrollInset`, `GlobalKey` navigation, and tactile stem controls).
4. **Pocket Stem Mixer Modal Ergonomics Specification:** Upgraded sheet design with frosted glass, drag handle, and tactile faders.
5. **Phase-by-Phase Implementation Roadmap:** Safe, test-aware steps to execute the transformation without breaking any of the 4 test pins or 805 existing feature tests.
