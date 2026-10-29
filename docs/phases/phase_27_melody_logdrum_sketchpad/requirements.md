# Phase 27 Requirements: Device-Adaptive In-Key Melody, Chord & Log-Drum Pattern Sketchpad

> **Phase:** 27 (`phase_27_melody_logdrum_sketchpad`)  
> **Requirement IDs:** `REQ-SKP-01` through `REQ-SKP-15`

---

## 1. Scale-Locked Pitch Engine & Starter Catalog (`REQ-SKP-01` .. `REQ-SKP-04`)

- **`REQ-SKP-01` (5 Sovereign African Sketchpad Instruments):** Support `amapiano_log_drum`, `private_school_rhodes`, `maskandi_guitar`, `venda_mbira`, and `marimba_wood`.
- **`REQ-SKP-02` (4 Scale-Locked Modal Ladders):** Support `minor_pentatonic` (`[0, 3, 5, 7, 10, 12, 15, 17]`), `natural_minor` (`[0, 2, 3, 5, 7, 8, 10, 12]`), `maskandi_hexatonic` (`[0, 2, 4, 5, 7, 9, 12, 14]`), and `gqom_phrygian_dark` (`[0, 1, 5, 7, 8, 10, 12, 13]`) across 12 chromatic root keys (`C`, `C#`, `D`, `D#`, `E`, `F`, `F#`, `G`, `G#`, `A`, `A#`, `B`).
- **`REQ-SKP-03` (Per-Step Log-Drum Pitch Glide & Velocity):** Each step note (`MelodyStepNote`) shall store `stepIndex` (`0..15`), `scaleRow` (`0..7`), `velocity` (`0.0..1.0`), `hasGlide` (`bool`, $-5\text{ semitone}$ pitch slide), and `durationSteps` (`1..4`).
- **`REQ-SKP-04` (6 Iconic African Starter Patterns):** Seed `kabza_logdrum_bounce`, `private_school_rhodes_lush`, `maskandi_ukupika_turnaround`, `venda_domba_mbira`, `gqom_dark_sub_pulse`, and `afro_house_marimba_arp` on both backend (`/v1/melodies/presets`) and client (`kStarterMelodyPatterns`).

---

## 2. Two-Layer Storage & Pure-Dart Acoustic Synthesis (`REQ-SKP-05` .. `REQ-SKP-07`)

- **`REQ-SKP-05` (Layer 1 — Local Hive Pattern Vault):** Persist user-created `MelodyPatternEntity` JSON blueprints (`< 2 KB`) locally in `AppConstants.melodySketchesBoxKey` (`'vhunambi_melody_sketches_box'`) with a safe in-memory fallback when Hive is not open in headless `flutter test`.
- **`REQ-SKP-06` (Layer 2 — Ephemeral In-Memory 16-Bit PCM WAV Synthesizer):** `MelodyWavSynthesizer.synthesizePatternToWavBytes()` shall deterministically synthesize a valid 44-byte RIFF/WAVE mono 16-bit PCM `Uint8List` in RAM (`< 20 ms`) with zero filesystem pollution and zero native plugin dependencies:
  - `amapianoLogDrum`: 2-Operator FM synthesis with a `14 ms` exponential mallet pitch-drop ($1 + 2.2 e^{-t/0.014}$), $2.41 \times f_0$ wooden knock modulator, $0.5 \times f_0$ phase-locked sub-octave sine, and $-5\text{ semitone}$ exponential slide when `hasGlide == true`.
  - `privateSchoolRhodes`: Scale triad/7th voicing ($f_0 + 0.45 f_{\text{3rd}} + 0.35 f_{\text{5th}}$) with a `20 ms` $7 \times f_0$ bell tine transient.
  - `maskandiGuitar` & `vendaMbira`: Plucked harmonic series ($\sum_{k=1}^5 k^{-1.2} e^{-k t / \tau} \sin(2\pi k f_0 t)$) plus $2.756 \times f_0$ metallic overtone for Mbira.
  - `marimbaWood`: Warm hollow fundamental + 4th harmonic resonator.
- **`REQ-SKP-07` (Euclidean Groove Assist):** Provide a deterministic Euclidean rhythm generator that populates in-key syncopated African patterns across the 16 steps with one tap.

---

## 3. Device-Adaptive UX Surfaces (`REQ-SKP-08` .. `REQ-SKP-11`)

- **`REQ-SKP-08` (Mobile Bar-Paginated HIG Sequencer & 8-Pad Live Deck):** On mobile viewports (`< 768px`), `MelodySketchpadModal` shall render the **Bar-Paginated 4-Step Grid** (`Key('mobile_bar_page_0..3')`) where every cell (`Key('sketchpad_cell_${row}_${step}')`) meets the `>= 44×44dp` touch target rule, plus a toggleable **8-Pad Live Scale Performance Deck** (`Key('mobile_input_mode_toggle')`, `Key('mobile_scale_pad_0..7')`).
- **`REQ-SKP-09` (Desktop 16-Step Split DAW Workstation):** On desktop viewports (`> 1024px`), `MelodySketchpadModal` shall render the full **16-Step × 8-Row Piano Roll** (`Key('desktop_piano_roll_grid')`), **Chord Voicing Stamp Mode** (`Key('desktop_chord_stamp_single')`, `Key('desktop_chord_stamp_triad')`, `Key('desktop_chord_stamp_seventh')`), **Synchronized Bottom 16-Step Velocity & Glide Stalk Lane** (`Key('desktop_velocity_lane')`), and **QWERTY Keyboard Synth Listener**.
- **`REQ-SKP-10` (Entrypoint Wiring in Studio & Heritage Crate):** Wire `"🎹 Compose Melody / Log-Drum"` (`Key('dropzone_open_sketchpad_btn')`) and active badge (`Key('dropzone_active_sketchpad_badge')`) in `ReferenceAudioDropzone`, and `"🎹 Open in Melody Sketchpad"` (`Key('crate_open_sketchpad_btn')`) in `CrateBrowserDeck`.
- **`REQ-SKP-11` (Zero Timer Leaks in Headless Tests):** Any step-playhead preview timer in `MelodySketchpadNotifier` or UI widgets must be cleanly cancelled on `stopPreview()` and `dispose()`.

---

## 4. Dual-Pipeline Synergy & Privacy Compliance (`REQ-SKP-12` .. `REQ-SKP-15`)

- **`REQ-SKP-12` (Backend `/v1/melodies` API & Generation Conditioning):** Expose `GET /v1/melodies/presets` and `POST /v1/melodies/render-reference`, and forward `melody_conditioning` in `POST /v1/generations` and `runpod_adapter.ts`.
- **`REQ-SKP-13` (Phase 23 MMO Transient Injection):** Merge `log_drum_drop` and `harmonic_turnaround` step timestamps from an attached `MelodyPatternManifest` into `MasterMediaObjectManifest.modulationBus.transientEvents` in `dna_compiler.ts`.
- **`REQ-SKP-14` (Phase 25 Mastering `sketchpadLayerMix` Synergy):** Add `sketchpadLayerMix` (`0.0..1.0`, default `0.35` when a sketchpad pattern is attached) to `StemMasteringRecipe` (`mastering_types.ts`, `stem_mastering_recipe.dart`, `mastering_session_provider.dart`, and `stem_mastering_worker.py`).
- **`REQ-SKP-15` (Privacy Data Flow Audit):** Document `Saved Melody Sketchpad Patterns` (on-device Hive) and `Ephemeral Melody Reference WAV` in `docs/PRIVACY_DATA_FLOW.md`.

