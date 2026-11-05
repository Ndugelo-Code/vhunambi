# Phase 52 Blueprint: Macro-Canopy 3D Organelle Biome & Pre-Generation Stem-Lock Engine

## 1. Executive Summary & Problem Space

Based on physical hardware verification (`SVID_20261105_122325_1.mp4` and `Screenshot_20261105_115413`) and our visual north star design (`Neon Song DNA Quantum Tree.png`), Phase 52 addresses two foundational architectural challenges:

1. **Spatial & Visual Bottleneck ("The Distant Toy Problem"):**
   The previous 3D Song DNA view compressed the entire biological structure into a tiny 240×240dp cluster in the center of the viewport, leading to overlapping text pills, rigid straight line connections (`canvas.drawLine`), and a feeling of looking at a distant 2D diagram. Phase 52 elevates this into an immersive **Macro-Canopy 3D Living Ecosystem** ("ants on the organelle surface") where users explore at arm's reach, dive directly into branch canopies (*Beat*, *Vocal*, *Instruments*, *Spatial/Invasive*), and observe organic mucus-membrane-sheathed stem bridges with true additive bioluminescence (`BlendMode.plus`).

2. **Audio Engineering Flaw ("The 6 AM AI Degradation Trap"):**
   When clean, studio-grade 44.1 kHz beats built in Vhunambi's 5-Channel Sketchpad or imported from DAWs are passed into naive diffusion models (ACE-Step / DCAE), the AI re-synthesizes the drums and sub-bass from scratch with lossy compression and Gaussian noise—resulting in washed-out transients, phasey hi-hats, and muddy log-drums. Phase 52 solves this by introducing **Pre-Generation Stem Ingestion & Per-Branch `StemLockMode` (`lockedPure44k`, `harmonicInpaint`, `elasticResynth`)**, guaranteeing 100% pure 44.1 kHz beat and bass pass-through directly to mastering while using AI exclusively as a harmonic accompaniment and vocal inpainter.

---

## 2. System Architecture

```
┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│                  PHASE 52: MACRO-CANOPY BIOME & PRE-GEN STEM-LOCK ARCHITECTURE               │
├──────────────────────────────────────────────────────────────────────────────────────────────┤
│ 1. 3D SPATIAL MACRO CANOPY VIEWPORT (`SongDnaNodeTreeModal`)                                 │
│    • 2.1x scale factor; 3-layer volumetric parallax (0.35x background, 1.0x mid, 1.6x spores) │
│    • 2-Tier Camera Dive: Overview Mode (4 Primary Roots) ⇄ Branch Canopy Focus Mode (Leafs) │
│    • Floating [ 🔭 Surface Overview ] return button (`Key('song_dna_return_overview_btn')`)  │
├──────────────────────────────────────────────────────────────────────────────────────────────┤
│ 2. ORGANIC MUCUS-MEMBRANE STEM BRIDGES & ADDITIVE GLOW (`BlendMode.plus`)                    │
│    • Closed Cubic-Bézier sheaths with flared smooth-min meniscus webbing at junctions        │
│    • 3 intertwined sinusoidal neural fibers + traveling synaptic photon packets              │
│    • 3 tilted orbital atomic energy rings with satellite beads orbiting the orange nucleus   │
│    • Calm idle breathing (30% resting luminosity) vs Contextual network surge (100% active)  │
├──────────────────────────────────────────────────────────────────────────────────────────────┤
│ 3. PER-BRANCH STEM AUTHORITY & DYNAMIC LEAF CANOPY (`StudioFormState` / `SongDnaNode`)       │
│    • StemLockMode: 🔒 lockedPure44k | 🧬 harmonicInpaint | ✨ elasticResynth                  │
│    • Crystalline golden-cyan double-sheath visually protecting locked stems                  │
│    • Dynamic [ + Add Instrument Leaf ] button (`Key('song_dna_add_instrument_leaf_btn')`)   │
├──────────────────────────────────────────────────────────────────────────────────────────────┤
│ 4. HYBRID STEM-LOCK SYNTHESIS PIPELINE (`API` + `GPU handler.py`)                            │
│    • Pure 44.1 kHz WAV export of locked sketchpad channels (drums, log-drum bass)            │
│    • AI generates ONLY harmonicInpaint stems (vocals, missing instruments)                   │
│    • Stage 4 Master DSP fuses pure 44.1 kHz locked stems with AI-inpainted stems (-9.5 LUFS) │
└──────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Core Milestones & Tracks

- **Track A:** Macro-Canopy Camera Traversal & 2-Tier Branch Dive (`Organelle Overview` $\leftrightarrow$ `Branch Canopy Focus`).
- **Track B:** Organic Mucus-Membrane Stem Bridges, Additive Bloom (`BlendMode.plus`), 3 Tilted Atomic Rings & Contextual Surge.
- **Track C:** Pre-Generation Stem Ingestion & Per-Branch `StemLockMode` Selector.
- **Track D:** Hybrid Stem-Lock Synthesis Pipeline (Client, API `prompt_compiler.ts`, GPU `handler.py`).
- **Track E:** Verification Gates, Tests, Clean Analysis, Release APK Build & Hardware Stream Install (`EPHUT20917014649`).

