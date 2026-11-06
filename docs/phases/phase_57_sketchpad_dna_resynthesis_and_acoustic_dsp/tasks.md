# Phase 57 Execution Tasks: System-1 Calibrated "Jev" DNA Melody Resynthesizer & Acoustic-True 44.1 kHz 5-Channel DSP Overhaul

**Phase Number:** 57  
**Spec Directory:** `docs/phases/phase_57_sketchpad_dna_resynthesis_and_acoustic_dsp/`  
**Target Workspace:** `apps/vhunambi_client/`  
**Execution Strategy:** Dual-Wave All-Gemini Execution Split (`Wave 1: Gemini 3.8 Flash Workhorse Track` $\to$ `Wave 2: Gemini 4 Argon Advanced DSP, Jev DNA & Verification Track`)

---

## 1. Execution Wave Assignment Overview

| Wave | Assigned Model | Tracks & Tasks | Target Files |
| :---: | :--- | :--- | :--- |
| **Wave 1** | **`[FOR GEMINI 3.8 FLASH — WORKHORSE AGENT]`** | Track 57.1 (Domain Models & Role Octave Anchoring), Track 57.3 (Provider Undo Stack & Actions), Track 57.4 (Modal UI Controls & Row Labels) | `melody_sketchpad_models.dart`, `sketchpad_dna_resynthesizer.dart`, `melody_sketchpad_provider.dart`, `melody_sketchpad_modal.dart` |
| **Wave 2** | **`[FOR GEMINI 4 ARGON — ADVANCED DSP & VERIFICATION ARCHITECT]`** | Track 57.2 (44.1 kHz Acoustic DSP & Bleep Eradication), Track 57.5 (Full 9-Gate Verification Suite & Regression Audit) | `melody_wav_synthesizer.dart`, `phase57_sketchpad_dna_and_acoustic_dsp_test.dart` |

> **Note:** Because `design.md` (§3–§8) contains 100% unabridged, copy-paste-ready source code for every file in both waves, either Wave 1 + Wave 2 can be run sequentially across Flash and Argon, or all tasks can be executed cleanly from `design.md`.

---

## 2. Detailed Task Checklist

### Track 57.1 — Domain Models, Role-Aware Octave Anchoring & Hat/Perc Taxonomy `[FOR GEMINI 3.8 FLASH — WORKHORSE AGENT]`

- [x] **Task 57.1.1 (`REQ-P57-HATS-03`, `REQ-P57-DSP-04`):** In `apps/vhunambi_client/lib/features/studio/domain/models/melody_sketchpad_models.dart`, add `kHatPercVoiceNames` (8 dedicated High-Frequency Percussion labels: `'Conga Slap'`, `'Wood Clave'`, `'Shekere'`, `'Mbaḓi Shaker'`, `'Sgija Roll'`, `'Closed Hat'`, `'Open Hat'`, `'Crash'`) and `resolveChannelRowLabel(...)` exactly as specified in `design.md` §3.1.
- [x] **Task 57.1.2 (`REQ-P57-DSP-04`):** In `apps/vhunambi_client/lib/features/studio/domain/models/melody_sketchpad_models.dart`, update `resolveScaleFrequencyHz` and `resolveScaleNoteLabel` to accept an optional `SketchpadChannelRole? role` parameter and enforce `_resolveBaseMidiForRoleAndInstrument` so `SketchpadChannelRole.bass` anchors strictly to Sub-Bass Octaves 1–2 ($\text{MIDI } 28..45$, $36.7\text{ Hz} - 115.0\text{ Hz}$), `chords` to Octaves 3–4, and `lead` to Octaves 4–5 (`design.md` §3.1).
- [x] **Task 57.1.3 (`REQ-P57-UNDO-01..03`):** In `apps/vhunambi_client/lib/features/studio/domain/models/melody_sketchpad_models.dart`, append `ChannelDnaDiagnostic` and `DnaResynthesisReport`, and update `MultiTrackGrooveEntity.starterAmapianoGroove` `hats` channel steps to use `Row 3` (`Mbaḓi Shaker`), `Row 4` (`Sgija Roll`), `Row 5` (`Closed Hat`), and `Row 6` (`Open Hat`) (`design.md` §3.1).

---

### Track 57.2 — Acoustic-True 44.1 kHz 5-Channel DSP Overhaul `[FOR GEMINI 4 ARGON — ADVANCED DSP & VERIFICATION ARCHITECT]`

- [x] **Task 57.2.1 (`REQ-P57-DSP-01`, `REQ-P57-DSP-02`):** In `apps/vhunambi_client/lib/features/studio/domain/services/melody_wav_synthesizer.dart`, implement `resolveRoleHeadroomGain`, `padeTanhLimiter` (Bounded Padé `[3/2]` $\tanh$ soft-knee limiter), `.clamp(-32767, 32767)` in `_encodePcm16WavMono` / `_encodePcm16WavStereo`, and Kick-triggered Bass sidechain envelope ducking ($-4.5\text{ dB}$, $4\text{ ms}$ attack, $55\text{ ms}$ release) (`design.md` §4).
- [x] **Task 57.2.2 (`REQ-P57-DSP-03`):** In `melody_wav_synthesizer.dart`, replace all `f(t) * t` pitch-drop products and raw $380\text{ Hz}$ / $420\text{ Hz}$ / $620\text{ Hz}$ sine-tone knock oscillators on `amapianoLogDrum`, `hipHop808Sub`, `gqomDarkSub`, `Sub 808`, `Punch Kick`, and `Talking Conga Slap` with `_integratedPitchDropPhase` ($\Phi(t) = 2\pi [f_0 t + \Delta f \tau_p (1 - e^{-t/\tau_p})]$) (`design.md` §4).
- [x] **Task 57.2.3 (`REQ-P57-DSP-05`, `REQ-P57-DSP-06`):** In `melody_wav_synthesizer.dart`, implement `_renderBassMonoLegatoChannel` (mono-legato sustain across up to 4 empty steps + $8\text{ ms}$ cosine retrigger crossfade + $195\text{ Hz}$ 2-pole Butterworth LPF), `_renderChordsPolyphonicChannel` (automatic diatonic triad voicing + $\pm 6\text{ cents}$ stereo chorus + $2,800\text{ Hz}$ LPF), and `_renderLeadCantabileChannel` (multi-step sustain + $180\text{ ms}$ release tail + $3,800\text{ Hz}$ LPF) (`design.md` §4).
- [x] **Task 57.2.4 (`REQ-P57-HATS-01`, `REQ-P57-HATS-02`, `REQ-P57-HATS-03`):** In `melody_wav_synthesizer.dart`, implement `synthesizeHatPercVoice` (8 dedicated African & Studio high-frequency percussion voices), `_renderHatsPercChannel` with Open-Hat (`Row 6`) to Closed-Hat (`Row 5` / `Row 4`) acoustic choke group ($8\text{ ms}$ cosine choke), and `synthesizeSingleDrumOrHatWavBytes` (`design.md` §4).

---

### Track 57.3 — Jev System-1 Calibrated DNA Resynthesizer & Provider Undo Stack `[FOR GEMINI 3.8 FLASH — WORKHORSE AGENT]`

- [x] **Task 57.3.1 (`REQ-P57-DNA-01..05`):** Create `apps/vhunambi_client/lib/features/studio/domain/services/sketchpad_dna_resynthesizer.dart` implementing `SketchpadDnaResynthesizer` with strict Active-Channel Scope Isolation (`resolveActiveChannelScope`), 4-Axis Musical Coherence `computeChannelCoherence`, Jev MAD Confidence `computeMadConfidence`, Adaptive Skill-Tier Bayesian Fusion (`Beginner` / `Intermediate` / `Pro`), and Cross-Channel Entanglement (`chords -> bass -> drums -> hats -> lead`) (`design.md` §5).
- [x] **Task 57.3.2 (`REQ-P57-UNDO-01`, `REQ-P57-UNDO-02`, `REQ-P57-HATS-03`):** In `apps/vhunambi_client/lib/features/studio/presentation/providers/melody_sketchpad_provider.dart`, extend `MelodySketchpadState` with `dnaUndoStack` (`List<MultiTrackGrooveEntity>`, max 10), `lastDnaReport` (`DnaResynthesisReport?`), `canUndoDna`, and `isHatsChannel`, update `_auditionSingleScaleRow` to call `synthesizeSingleDrumOrHatWavBytes` and pass `role: state.activeChannelRole`, and implement `applyDnaResynthesis`, `undoDnaResynthesis`, and `dismissDnaReport` (`design.md` §6).

---

### Track 57.4 — Sketchpad Modal UI Controls & Telemetry Banner `[FOR GEMINI 3.8 FLASH — WORKHORSE AGENT]`

- [x] **Task 57.4.1 (`REQ-P57-UNDO-03`):** In `apps/vhunambi_client/lib/features/studio/presentation/widgets/melody_sketchpad_modal.dart`, mount `ActionChip(key: Key('sketchpad_apply_dna_btn'), ...)` (`Apply DNA`), conditional `ActionChip(key: Key('sketchpad_undo_dna_btn'), ...)` (`Undo`), and dismissible telemetry banner `Container(key: Key('sketchpad_dna_report_banner'), ...)` (`design.md` §7.1).
- [x] **Task 57.4.2 (`REQ-P57-HATS-03`, `REQ-P57-DSP-04`):** In `melody_sketchpad_modal.dart`, update `_MobileAdaptiveSurface` and `_DesktopWorkstationMatrix` to render row labels via `resolveChannelRowLabel(...)` and pass `role: state.activeChannelRole` to `resolveScaleFrequencyHz` (`design.md` §7.2).

---

### Track 57.5 — Verification Test Suite & Zero-Regression Audit `[FOR GEMINI 4 ARGON — ADVANCED DSP & VERIFICATION ARCHITECT]`

- [x] **Task 57.5.1 (`G-01`..`G-06`):** Create `apps/vhunambi_client/test/features/studio/phase57_sketchpad_dna_and_acoustic_dsp_test.dart` implementing all 9 verification tests (`P57-T01` through `P57-T09`) (`design.md` §8).
- [x] **Task 57.5.2 (Static Analysis & Test Execution):** Run `dart analyze` and `flutter test` across the Phase 57 test suite and existing studio tests:
  ```powershell
  cd apps/vhunambi_client
  dart analyze lib/features/studio test/features/studio/phase57_sketchpad_dna_and_acoustic_dsp_test.dart
  flutter test test/features/studio/phase57_sketchpad_dna_and_acoustic_dsp_test.dart test/features/studio/studio_view_test.dart
  ```

