# Phase 27 Blueprint: Device-Adaptive In-Key 16-Step Melody, Chord & Log-Drum Pattern Sketchpad

> **Phase:** 27 (`phase_27_melody_logdrum_sketchpad`)  
> **Pillar:** Vhunambi V4 Studio Evolution — Pillar 3  
> **Status:** `🔄 IN PROGRESS`  
> **Synergy Touchpoints:** Phase 3 (`ReferenceAudioDropzone`), Phase 22 (`CrateBrowserDeck`), Phase 23 (`MasterMediaObjectManifest` `transientEvents`), Phase 25 (`StemMasteringRecipe.sketchpadLayerMix`)

---

## 1. Executive Summary & Problem Statement

Creators often have a specific Amapiano log-drum bounce, Maskandi *ukupika* guitar turnaround, Venda *mbira* ostinato, or Private School Rhodes chord progression in mind that text prompts alone cannot express. Conversely, traditional 12-note chromatic DAW piano rolls on mobile phones suffer from cramped `< 22px` touch targets and allow out-of-key notes that clash with AI accompaniment.

**Phase 27** solves both problems through four tightly integrated architectural innovations:
1. **Scale-Locked 8-Row × 16-Step Sequencer (Zero Wrong Notes):** Locks the vertical pitch axis to an 8-degree modal ladder (`minor_pentatonic`, `natural_minor`, `maskandi_hexatonic`, `gqom_phrygian_dark`) with per-step **Log-Drum Pitch Glide (`hasGlide: true`, $-5\text{ semitones}$)** and velocity accents.
2. **Two-Layer Local-First Storage Architecture (Zero Disk Bloat):**
   - **Layer 1 (Persistent On-Device Hive Vault — `vhunambi_melody_sketches_box`):** Stores compact `MelodyPatternEntity` JSON blueprints (`< 2 KB` each) locally on-device so creators can save hundreds of custom patterns and non-destructively edit BPM, key, or instrument months later.
   - **Layer 2 (Ephemeral In-Memory 16-Bit PCM WAV Synthesis — `MelodyWavSynthesizer`):** Deterministically renders the 16-step pattern into a valid 44-byte RIFF/WAVE `Uint8List` in RAM (`< 20 ms`) using true 2-Operator FM synthesis for the Fruity DX10-style Amapiano Log Drum, harmonic pluck series for Maskandi Guitar & Venda Mbira, and triad chord voicings for Private School Rhodes.
3. **Device-Adaptive Ergonomics (`ResponsiveUtils.isMobile` vs. `ResponsiveUtils.isDesktop`):**
   - **Mobile (`MobileMelodySketchpadSheet`, `< 768px`):** Bar-paginated 4-step matrix (`[Bar 1: 1–4]` .. `[Bar 4: 13–16]`) guaranteeing `>= 44×44dp` Apple HIG touch targets, paired with an **8-Pad Live Scale Performance Deck**, a **1-Thumb Euclidean Groove Assist**, and a **Glide Mode Pill**.
   - **Desktop (`DesktopMelodyWorkstationView`, `> 1024px`):** Full 16-Step × 8-Row split DAW piano roll with **Chord Voicing Stamp** (`Single Note`, `Triad Chord`, `Soul 7th`), a synchronized bottom **16-Step Velocity & Glide Stalk Lane**, and **QWERTY Keyboard Synth** (`A S D F G H J K`, `Space`, `G`).
4. **Dual-Pipeline Synergy (Pre-Gen ACE-Step 1.5 + Post-Gen Phase 23 MMO & Phase 25 Mastering):**
   - **Pre-Generation:** Attaches `melody_conditioning` to `StudioFormState` (`ReferenceAudioDropzone`) and `runpod_adapter.ts`.
   - **Post-Generation MMO Telemetry (Phase 23):** Injects `log_drum_drop` and `harmonic_turnaround` step timestamps directly into `MasterMediaObjectManifest.modulationBus.transientEvents` so `KineticPreviewCanvas` snaps its camera zoom on the user's exact programmed notes.
   - **Post-Generation Studio Mastering (Phase 25):** Adds `sketchpadLayerMix` (`0.0..1.0`) to `StemMasteringRecipe` so `stem_mastering_worker.py` blends the crystal-clear studio sketchpad loop underneath `bass.wav` or `melodic.wav`.

