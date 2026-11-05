# Phase 52 Requirements: Macro-Canopy 3D Organelle Biome & Pre-Generation Stem-Lock Engine

## 1. Functional Requirements

### Track A: Macro-Canopy Camera Traversal & 2-Tier Spatial Hierarchy
- **REQ-P52-MACRO-01:** The 3D Song DNA rendering canvas SHALL increase its base organelle and spatial scaling factor to **`2.1x`** (default `cameraDistance = 320.0`, focal length `420.0`), filling the mobile and desktop viewport with volumetric depth.
- **REQ-P52-MACRO-02:** The system SHALL operate in two distinct camera modes:
  - **Overview Mode:** The camera hovers right above the surface of the pulsing orange nucleus ($Y \in [-30, 40]$), viewing the 4 primary branch roots (`Beat & Groove`, `Vocal & Dialect`, `Instruments & Harmony`, `Spatial & Invasive`). In Overview Mode, ONLY the 4 Primary Branch Roots SHALL display text pills (`Key('song_dna_bubble_${node.id}')`), eliminating pill collisions.
  - **Branch Canopy Focus Mode:** Tapping any Primary Branch Root (or its bubble) SHALL spring-animate the camera (`cameraDistance = 220.0`, target positioned on the selected branch root) along the mucus-membrane stem bridge into that branch canopy.
- **REQ-P52-MACRO-03:** In Branch Canopy Focus Mode, the selected branch's child Leaf Bubbles (e.g. `Rhodes Piano`, `Bamboo Flute`, `Maskandi Guitar`, `Log-Drum Sub`, `MPC Chops`) SHALL be displayed with high-legibility micro-tags and double-ring receptors (`◎`) at arm's reach.
- **REQ-P52-MACRO-04:** The modal SHALL render a floating **`[ 🔭 Surface Overview ]`** pill button (`Key('song_dna_return_overview_btn')`) whenever the user is in Branch Canopy Focus Mode, allowing a smooth camera glide back to the Organelle Overview.

### Track B: Organic Mucus-Membrane Stem Bridges & Additive Bioluminescence
- **REQ-P52-MUCUS-01:** Every stem connecting the organelle core to a branch root (and from a branch root to child leaves) SHALL be rendered as an organic biological stem bridge (`_paintMucusMembraneBridge`):
  1. A closed Cubic-Bézier tube path with flared smooth-min meniscus webbing at both attachment junctions (`startRadius * 1.45` tapering to a curved mid-span waist and flaring to `endRadius * 1.35`).
  2. 3 intertwined sinusoidal internal neural fibers rendered using **`BlendMode.plus`** for true additive luminous blending.
  3. Synaptic bioluminescent photon packets travelling along the Bézier spine at speeds proportional to the stem's energy and BPM.
- **REQ-P52-CORE-01:** The central Organelle Nucleus SHALL render:
  1. A multi-layered additive plasma core with radial gradient blending from pure white `#FFFFFF` center to blazing gold `#FFB703` and amber `#FB5607` using `BlendMode.plus`.
  2. A dense cyan filamentous geodesic mesh with luminous vertex intersections.
  3. **3 Tilted Elliptical Orbital Energy Rings** rotating in 3D space with glowing orbital beads and background depth-of-field bokeh clusters.
- **REQ-P52-SURGE-01:** The rendering engine SHALL support **Calm Idle Motion vs. Contextual Network Surge**:
  - Unselected branches breathe at `30%` resting luminosity.
  - Selecting a branch (or playing audio) sends an action-potential light surge along its mucus-membrane stem bridge, illuminating that entire branch family to `100%` additive brilliance.

### Track C: Pre-Generation Stem Ingestion & Per-Branch `StemLockMode`
- **REQ-P52-STEM-01:** The system SHALL define `enum StemLockMode`:
  - `lockedPure44k`: `🔒 Stem-Locked (Pure 44.1 kHz)` — Guarantees untouched 44.1 kHz stem pass-through directly to mastering; AI only receives timing/key grid for accompaniment synthesis.
  - `harmonicInpaint`: `🧬 Guided AI Inpaint` — AI synthesizes only this missing stem harmonically locked to user's locked stems.
  - `elasticResynth`: `✨ AI Style Re-Imagine` — AI transforms and re-synthesizes reference audio.
- **REQ-P52-STEM-02:** `StudioFormState` SHALL maintain `Map<String, StemLockMode> branchStemLockModes`, defaulting `Beat` and `Log-Drum / Sketchpad` branches to `StemLockMode.lockedPure44k` when active, and `Vocal` / unprogrammed `Instrument` branches to `StemLockMode.harmonicInpaint`.
- **REQ-P52-STEM-03:** The Quick-Action Card (`Key('song_dna_quick_action_card')`) SHALL display a 3-way **Stem Authority Selector Pill** (`Key('song_dna_stem_lock_selector')`) allowing instant toggling of `StemLockMode`.
- **REQ-P52-STEM-04:** Stems in `StemLockMode.lockedPure44k` SHALL be visually represented in 3D space by a **crystalline golden-cyan double-sheath** on their mucus-membrane bridge.
- **REQ-P52-LEAF-01:** On the Instruments & Harmony Branch, the UI SHALL render a **`[ + Add Instrument Leaf ]`** button (`Key('song_dna_add_instrument_leaf_btn')`) to dynamically spawn or swap instrument leaf bubbles (`Private School Rhodes`, `Bamboo Flute`, `Maskandi Guitar`, `Soprano Sax`, `Solo Violin`, `808 Sub`).

### Track D: Hybrid Stem-Lock Synthesis Pipeline
- **REQ-P52-PIPE-01:** When synthesis is triggered, client services SHALL export active `lockedPure44k` channels (drums, log-drum bass) at pure 44.1 kHz 16-bit PCM and transmit the `pregenStemLocks` manifest to the backend synthesis endpoint.
- **REQ-P52-PIPE-02:** `CompiledSynthesisPrompt` in `prompt_compiler.ts` SHALL include `pregenStemLocks` in synthesis metadata.
- **REQ-P52-PIPE-03:** In `tools/zr-studio-gpu/handler.py`, the worker SHALL inspect `pregen_stem_locks`: when locked stems are present, it SHALL inject the pure 44.1 kHz audio before Stage 4 mastering, bypassing AI re-synthesis on locked stems and preventing beat degradation.

---

## 2. Non-Functional Requirements
- **Zero Raw Emojis (`STD-UIUX-001`):** Use Phosphor icons or vector CustomPainters exclusively.
- **Zero Plugin Law:** No external packages added to `pubspec.yaml` or `package.json`.
- **60 FPS Performance:** All procedural 3D math and additive shader calculations MUST run smoothly on mobile hardware (`EPHUT20917014649`).

