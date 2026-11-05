# Phase 51: Functional & Non-Functional Requirements Specification

## 1. Functional Requirements

### Track A: Hardware Forensic Bug Fixes
- **REQ-P51-FIX-01 (Card Stack Z-Ordering):** In `InteractiveIdentityCardStack`, the card indices mapped to `Stack` children MUST be sorted by distance from the active card (`relativeDepth = (index - _activeIndex).abs()`) in descending order. The active selected card (`relativeDepth == 0`) MUST always be rendered as the final child in the `Stack` list, guaranteeing it paints on top of all other cards with a 100% opaque surface.
- **REQ-P51-FIX-02 (Welcome Screen Clearance):** In `OnboardingAct1Showcase`, spacing between the subtitle and the 4 showcase pills MUST be at least `18dp`. The pills MUST animate upward using `Curves.easeOutCubic` without intersecting or occluding the slogan text.
- **REQ-P51-FIX-03 (Total Modal Opacity & Mini-Player Suppression):** `SongDnaNodeTreeModal` MUST render as a 100% opaque full-screen surface (`#020813` to `#041424`), with zero background text bleed-through from `StudioView`. `MiniPlayerHost` MUST remain completely suppressed whenever the modal is open. `MelodySketchpadModal` MUST utilize 100% opaque background fill.
- **REQ-P51-FIX-04 (Generation Pipeline Trigger & CTA Layout):** Tapping `Key('song_dna_synthesize_btn')` MUST dispatch both `studioFormProvider.notifier.triggerGeneration()` and `generationProgressProvider.notifier.submitAndStartGeneration(...)`, populating `GenerationPipelineCard` with active status. The button label `⚡ Synthesize Song from 3D DNA` MUST be wrapped in a `FittedBox` or non-wrapping flex layout to prevent two-line wrapping on narrow displays.

### Track B & C: 3D Organelle Environment & Cellular Anatomy
- **REQ-P51-WORLD-01 (Abyssal Bio-Space):** The 3D view MUST render an immersive deep space radial backdrop (`#020813` to `#041424`) with subtle holographic horizon telemetry lines on the screen boundaries.
- **REQ-P51-WORLD-02 (Depth-of-Field Bokeh Satellite Organelles):** The background canvas MUST paint 4 out-of-focus satellite organelle clusters (top-left, top-right, bottom-right, bottom-left) using `MaskFilter.blur(BlurStyle.normal, sigma)` with camera parallax displacement.
- **REQ-P51-MEMB-01 (Geodesic Filamentous Membrane):** A 3D geodesic/UV mesh sphere (at least 112 vertices) surrounding the center MUST deform in real time according to:
  $$r(\theta, \phi, t) = R_0 \cdot \bigl(1 + 0.07\sin(3\theta + 1.6t)\cos(2\phi - 1.2t) + 0.04\cos(4\phi + 2.2t)\bigr)$$
  with cyan bioluminescent rim glow (`#00F5D4`).
- **REQ-P51-CORE-01 (Blazing Amber Nucleus & Neural Filaments):** Nested inside the cyan membrane, an Amber core sphere (`#FF6B00` to `#FFB703`) with 4 internal vesicles MUST connect to the inner membrane wall via curved 3D cubic-Bézier filaments pulsing in time with the track BPM.

### Track D: Articulated Molecular Dendrite Chains
- **REQ-P51-DENDR-01 (4 Multi-Jointed Dendrite Arms):** The Song DNA node graph MUST model 4 multi-jointed arms with 24+ interactive sub-nodes:
  1. *Beat & Rhythm Dendrite* (Amber `#FF6B00`): Genre Core, Rhythm Pocket, Tempo Feel, Era Signature, Song Structure.
  2. *Vocal & Linguistic Dendrite* (Cyan `#00F5D4`): Vocal Persona, LoRA Weight, Primary Bantu Tongue, Dialects, Mood & Energy.
  3. *Harmonic & Instrument Dendrite* (Emerald `#10B981`): 5-Channel Matrix, Lead Melody, Chords & Keys, Log-Drum Bass, Drum Kit, Hats & Shakers, Heritage MPC.
  4. *Invasive Intake Dendrite* (Magenta `#F72585`): Invasive Reference, Voice DNA (`VHU-SIG`), Reference Beat, Parent Remix Lineage.
- **REQ-P51-NODE-01 (Microscopic Node Anatomy):** Nodes MUST render as stippled bioluminescent 3D spheres surrounded by precision outer rings (`◎`), connected by glowing bond tubes with traveling photon pulses.
- **REQ-P51-HUD-01 (Decluttered Holographic Callouts):** No giant overlapping rectangular pill overlays. Primary nodes and the currently focused branch project sleek micro-tags and thin leader lines. All `Key('song_dna_bubble_${node.id}')` hit targets MUST remain accessible for touch and automated tests.
- **REQ-P51-CAM-01 (6-DOF Camera Navigation):** Support 1-finger orbit (`yaw`/`pitch`), 2-finger pan/zoom, tap-to-focus dive, and camera reset button (`Key('song_dna_reset_camera_btn')`).

---

## 2. Non-Functional Requirements
- **PERF-01 (60 FPS Performance):** Vector mathematics, spherical harmonic vertex deformation, and Bézier curves MUST compute in $<2.5\text{ms}$ per frame on ARM64 mobile hardware.
- **SEC-01 (Zero External Dependencies):** All geometry, projection, and shaders MUST use built-in Flutter graphics primitives.
- **QUAL-01 (Test Coverage & Analysis):** 100% green tests across existing and new test suites, 0 static analysis diagnostics (`dart analyze`).

