# 🏛️ AUDIT BRIEF & PROMPT: The Studio AI Generation Cockpit & MPC Chopper
**Target Agent:** Cline (Plan Mode / Audit Mode — Read-Only Review)  
**Target Codebase:** `apps/vhunambi_client` (Flutter / Dart)  
**Scope:** Studio AI Music Generation Wizard, Bantu Voice LoRA Engine, Heritage Crate Digging, 8-Pad MPC Slicer, and Lyrics Review Cockpit  

---

## 🎯 Mission Statement & Purpose
You are acting as an **independent, unbiased Principal Mobile Audio Workstation Architect and Music Tech Design Lead**.

Your objective is to conduct a rigorous, zero-bias audit of **The Studio AI Generation Cockpit and Heritage MPC Chopper** in the Vhunambi codebase.

Vhunambi is a high-performance African AI Music Workstation and Social Creator Network built for 2026 mobile standards. The **Top Bar Navigation System** and **Bottom Navigation Dock & Audio Transport** have both been modernized into high-performance frosted surfaces with mathematical geometry and 44px touch compliance.

Now we target the core creative engine of the app: **The AI Music Generation Studio (`StudioView`) and the Heritage Crate & 8-Pad MPC Slicer (`_HeritageStudioSheet`)**.

Currently, the Studio features remarkable functional depth (African multilingual synthesis, Bantu Voice LoRA timbres, phonetic alignment previews, 8-pad transient slicing, lyrics review modals). However, **the layout suffers from massive vertical scroll fatigue (10 stacked cards in a single column), sub-standard modal transitions, inconsistent back affordances (`Icons.arrow_back_rounded`), hardcoded bottom padding (`SizedBox(height: 80)`), and touch ergonomics that require a comprehensive 44px HIG/WCAG audit**.

Your goal is to thoroughly audit the current implementation, expose every flaw, vulnerability, and UX friction point, and deliver an uncompromising architectural blueprint for a state-of-the-art 2026 AI music creation cockpit.

---

## 📂 Primary Code Files to Audit

Review and cross-examine the following files in the repository:

### 1. Studio Root View & Sheet Orchestration
* [`apps/vhunambi_client/lib/features/studio/presentation/views/studio_view.dart`](file:///apps/vhunambi_client/lib/features/studio/presentation/views/studio_view.dart):
  * `StudioView`: Single column scrolling with 10 stacked widgets.
  * Line 107: `SizedBox(height: 80)` — hardcoded bottom padding (Defect: not using `VhunambiBottomDockMetrics.scrollInset`).
  * `_StudioAppBar`: Custom header surface.
  * `_openHeritageStudio()`: `showModalBottomSheet(heightFactor: 0.9)` with flat background.
  * `_HeritageStudioSheet`: Line 239 uses `Icons.arrow_back_rounded` (Defect: violates canonical `VhunambiBackButton`).

### 2. The Heritage Crate & 8-Pad MPC Slicer
* [`apps/vhunambi_client/lib/features/studio/presentation/widgets/crate_browser_deck.dart`](file:///apps/vhunambi_client/lib/features/studio/presentation/widgets/crate_browser_deck.dart):
  * Spinning vinyl audition disk (`_VinylDiskWidget`).
  * Search field and category filter chips.
  * Audition and 1-tap "Chop" hand-off.
* [`apps/vhunambi_client/lib/features/studio/presentation/widgets/mpc_slicer_deck.dart`](file:///apps/vhunambi_client/lib/features/studio/presentation/widgets/mpc_slicer_deck.dart):
  * 4x2 8-Pad MPC grid (`_MpcPad`).
  * Transient start/end times, chromatic pitch modulation, reverse toggle, time-stretch slider.
  * `mpc_send_to_mixer` (Send to Stem Mixer) and `mpc_send_to_studio` (Record into Studio) CTA buttons.

### 3. African Multilingual & Bantu Voice LoRA Synthesis
* [`apps/vhunambi_client/lib/features/studio/presentation/widgets/bantu_voice_deck.dart`](file:///apps/vhunambi_client/lib/features/studio/presentation/widgets/bantu_voice_deck.dart):
  * 5 native African timbre cards (penultimate vowel stretch, ancestral vibrato depth, choir ad-libs).
  * Dialect inflection sliders (`_DialectSlider`).
* [`apps/vhunambi_client/lib/features/studio/presentation/widgets/live_phonetic_alignment_preview.dart`](file:///apps/vhunambi_client/lib/features/studio/presentation/widgets/live_phonetic_alignment_preview.dart):
  * Real-time phonetic waveform alignment preview card.
* [`apps/vhunambi_client/lib/features/studio/presentation/widgets/multilingual_language_selector.dart`](file:///apps/vhunambi_client/lib/features/studio/presentation/widgets/multilingual_language_selector.dart):
  * 11 indigenous African languages (Tshivenḓa, isiZulu, Yoruba, Swahili, Amharic, etc.).
* [`apps/vhunambi_client/lib/features/studio/presentation/widgets/regional_genre_selector.dart`](file:///apps/vhunambi_client/lib/features/studio/presentation/widgets/regional_genre_selector.dart):
  * 12 African regional genres (Amapiano, Afrobeats, Maskandi, Gengetone, Highlife, Gqom, etc.).

### 4. Input Cockpit & Sticky Action Bar
* [`apps/vhunambi_client/lib/features/studio/presentation/widgets/prompt_input_box.dart`](file:///apps/vhunambi_client/lib/features/studio/presentation/widgets/prompt_input_box.dart):
  * Prompt text area, "Inspire Me" scenario chips, character limit indicators.
* [`apps/vhunambi_client/lib/features/studio/presentation/widgets/studio_action_bar.dart`](file:///apps/vhunambi_client/lib/features/studio/presentation/widgets/studio_action_bar.dart):
  * Public visibility switch, primary "Generate Song" / "Write Lyrics First" CTA, terms disclaimer.
* [`apps/vhunambi_client/lib/features/studio/presentation/widgets/advanced_options_accordion.dart`](file:///apps/vhunambi_client/lib/features/studio/presentation/widgets/advanced_options_accordion.dart):
  * BPM, Key/Scale, temperature, generation seed, stems separation toggle.

### 5. Generation Pipeline & Lyrics Review
* [`apps/vhunambi_client/lib/features/studio/presentation/widgets/generation_pipeline_card.dart`](file:///apps/vhunambi_client/lib/features/studio/presentation/widgets/generation_pipeline_card.dart):
  * Active pipeline stage progress cards, step countdown, stage badges.
* [`apps/vhunambi_client/lib/features/studio/presentation/widgets/lyrics_review_modal.dart`](file:///apps/vhunambi_client/lib/features/studio/presentation/widgets/lyrics_review_modal.dart):
  * Stanza editor, bracketed tags, idiom insertions, raw markdown toggle.

### 6. Studio Domain & State Contracts (Must Be Preserved)
* [`apps/vhunambi_client/lib/features/studio/domain/models/studio_form_state.dart`](file:///apps/vhunambi_client/lib/features/studio/domain/models/studio_form_state.dart)
* [`apps/vhunambi_client/lib/features/studio/presentation/providers/studio_form_provider.dart`](file:///apps/vhunambi_client/lib/features/studio/presentation/providers/studio_form_provider.dart)
* [`apps/vhunambi_client/lib/features/studio/domain/models/heritage_crate_models.dart`](file:///apps/vhunambi_client/lib/features/studio/domain/models/heritage_crate_models.dart)
* [`apps/vhunambi_client/lib/features/studio/presentation/providers/heritage_crate_provider.dart`](file:///apps/vhunambi_client/lib/features/studio/presentation/providers/heritage_crate_provider.dart)

---

## 🔍 Specific Audit Dimensions

You must assess the codebase across the following 5 critical dimensions:

### Dimension 1: Vertical Scroll Fatigue & Progressive Information Architecture
* **The Current Defect:**
  * In `StudioView`, 10 distinct modules are stacked linearly in a single column: Pipeline Card ➔ Prompt ➔ Dropzone ➔ Genre ➔ Language ➔ Bantu Voice ➔ Phonetic Alignment ➔ Crate/MPC Button ➔ Advanced Accordion ➔ Sticky Action Bar.
  * On a mobile screen (844px height), this creates an immense scroll distance (~2,800 vertical pixels), forcing the creator to scroll past advanced voice LoRA and phonetic alignment widgets just to reach the Generate CTA!
  * Line 107 has a hardcoded `SizedBox(height: 80)` instead of dynamic dock metrics.
* **Audit Questions for Cline:**
  1. How should the Studio IA be restructured for 2026 mobile ergonomics? (e.g. Tabbed Studio Modes: "Quick Prompt", "Voice & Dialect", "Crate & MPC" vs Collapsible Studio Accordions)?
  2. How can the primary Generate action be sticky or accessible without scrolling 2,000px down?
  3. How should `VhunambiBottomDockMetrics.scrollInset` be integrated?

### Dimension 2: Heritage Crate Digging & 8-Pad MPC Slicer Sheet Modernization
* **The Current Defect:**
  * Opened via generic `showModalBottomSheet(heightFactor: 0.9)`.
  * In `_HeritageStudioSheet`, the back affordance is `TextButton.icon(icon: Icons.arrow_back_rounded)` — violating our unified `VhunambiBackButton` (`Icons.chevron_left_rounded` with 44×44px hit constraints).
  * Switching between Crate Browser and MPC Slicer is a hard boolean swap with no fluid transition.
* **Audit Questions for Cline:**
  1. How should the Heritage Studio sheet transition into a frosted modal surface matching our 2026 design system?
  2. How should the back affordance be standardized to `VhunambiBackButton`?
  3. How should the 8-Pad MPC Slicer touch ergonomics, visual transient pads, and haptic feedback be enhanced?

### Dimension 3: African Multilingual & Bantu Voice LoRA Synthesis Ergonomics
* **The Current Defect:**
  * Dialect inflection sliders (`_DialectSlider`) and timbre cards take up huge vertical space.
  * Sliders and chips need validation for touch target size and haptic response consistency.
* **Audit Questions for Cline:**
  1. How should the Bantu Voice LoRA Engine and Phonetic Alignment Preview be presented so they feel state-of-the-art without cluttering the primary generation flow?

### Dimension 4: Generation Pipeline States & Lyrics Review Cockpit
* **The Current Defect:**
  * `GenerationPipelineCard` appears at the very top of the scroll view when active, pushing content down unexpectedly.
  * When generation starts, `_handleGenerate` shows a temporary SnackBar instead of an in-place fluid status transformation.
* **Audit Questions for Cline:**
  1. How should the active generation state gracefully take over or pin to the viewport so creators see live synthesis progress immediately?
  2. What touch ergonomics or modal improvements are needed for `LyricsReviewModal`?

### Dimension 5: Touch Ergonomics & HIG/WCAG Compliance Sweep
* **The Current Defect:**
  * Verify all interactive controls across Studio:
    * Inspire Me chips (`_InspireChip`)
    * Genre chips (`_GenreChip`)
    * Language selector items
    * Voice timbre cards (`_TimbreCard`)
    * MPC pads (`_MpcPad`)
    * Public switch toggle
    * Sliders and buttons
  * Ensure every interactive target maintains the minimum **44×44px** hit area.

---

## 📝 Required Audit Output Deliverables

In your audit report, please provide:

1. **Executive Summary & Verdict:** Honest score (1–10) on the current Studio AI Cockpit and MPC Chopper architecture.
2. **Defect & Friction Matrix:** A structured table listing each issue, file and line number, severity (Critical, High, Medium), and UX impact.
3. **The 2026 Studio Information Architecture Blueprint:** Proposed layout restructuring (progressive disclosure, sticky generation dock, tabbed studio modes).
4. **Heritage Crate & MPC Slicer Ergonomics Specification:** Upgraded sheet design, `VhunambiBackButton` integration, and pad touch layout.
5. **Phase-by-Phase Implementation Roadmap:** Safe, test-aware steps to execute the transformation without breaking existing studio form providers or widget tests.
