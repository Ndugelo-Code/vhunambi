# Phase 57 Requirements: System-1 Calibrated "Jev" DNA Melody Resynthesizer & Acoustic-True 44.1 kHz 5-Channel DSP Overhaul

**Phase Number:** 57  
**Specification Standard:** EARS (Easy Approach to Requirements Syntax) + RFC-2119 (`SHALL`, `MUST`, `SHOULD`, `MAY`)  
**Target Module:** `apps/vhunambi_client/lib/features/studio/`  

---

## 1. Acoustic-True 44.1 kHz 5-Channel DSP Requirements (`REQ-P57-DSP`)

### `REQ-P57-DSP-01`: Bounded Padé `[3/2]` $\tanh$ Master Soft-Knee Limiter & Int16 Wrap Prevention
- **Statement:** **WHEN** `MelodyWavSynthesizer` encodes mono or stereo floating-point mix buffers into 16-bit PCM RIFF/WAVE bytes, **THE SYSTEM SHALL** apply per-channel pre-summing headroom gain weights ($g_{\text{bass}} = 0.52$, $g_{\text{drums}} = 0.55$, $g_{\text{chords}} = 0.42$, $g_{\text{lead}} = 0.48$, $g_{\text{hats}} = 0.38$), pass every master bus sample through the bounded Padé `[3/2]` $\tanh$ soft-knee limiter ($\tanh_{\text{Pade}}(x) \in [-1.0, +1.0]$), and clamp every scaled integer sample via `.round().clamp(-32767, 32767)` prior to `ByteData.setInt16` so that two's-complement polarity wrap-around can **NEVER** occur at any channel density or `masterDrive` setting.

### `REQ-P57-DSP-02`: Kick-Triggered Bass Sidechain Envelope Ducking
- **Statement:** **WHEN** `SketchpadChannelRole.drums` triggers a Kick voice (`scaleRow == 0` Sub 808 or `scaleRow == 1` Punch Kick) at sample onset $n_k$ while `SketchpadChannelRole.bass` is active, **THE SYSTEM SHALL** apply a sidechain ducking envelope $G_{\text{duck}}(n) \in [0.59, 1.0]$ ($-4.5\text{ dB}$ maximum attenuation with $4\text{ ms}$ linear attack and $55\text{ ms}$ exponential release) to the `bass` channel buffer before master stereo summing.

### `REQ-P57-DSP-03`: True Phase-Integrated Pitch Envelopes & Elimination of Sine-Tone Knock Bleeps
- **Statement:** **WHEN** synthesizing pitch-dropping sub-bass or drum voices (`amapianoLogDrum`, `hipHop808Sub`, `gqomDarkSub`, `Sub 808`, `Punch Kick`, `Talking Conga Slap`), **THE SYSTEM SHALL** compute phase via the exact analytical integral $\Phi(t) = 2\pi \left(f_0 t + \Delta f \cdot \tau_p (1 - e^{-t/\tau_p})\right)$ rather than multiplying instantaneous frequency $f(t)$ by $t$, and **SHALL** replace raw high-frequency sine-tone knock oscillators ($380\text{ Hz}$, $420\text{ Hz}$, $620\text{ Hz}$) with warm low-frequency wooden mallet transients ($135\text{ Hz} \to f_0$ over $12\text{ ms}$) so instantaneous frequency never inverts or produces synthetic beeps.

### `REQ-P57-DSP-04`: Role-Aware Octave Anchoring (`bass`, `chords`, `lead`)
- **Statement:** **WHEN** resolving scale frequencies (`resolveScaleFrequencyHz`) or note labels (`resolveScaleNoteLabel`) for a channel or step note, **THE SYSTEM SHALL** accept an optional `SketchpadChannelRole? role` parameter and enforce strict role-based octave anchoring:
  - `SketchpadChannelRole.bass`: **MUST** anchor to **Octaves 1–2** (`baseMidi = 28..33` depending on root key so all 8 scale rows reside strictly within $36.7\text{ Hz} - 115.0\text{ Hz}$, $\text{MIDI } 28..45$) regardless of which `SketchpadInstrument` is selected.
  - `SketchpadChannelRole.chords`: **MUST** anchor to **Octaves 3–4** (`baseMidi = 48`, $\text{MIDI } 48..72$).
  - `SketchpadChannelRole.lead`: **MUST** anchor to **Octaves 4–5** (`baseMidi = 60`, $\text{MIDI } 60..81$).

### `REQ-P57-DSP-05`: Mono-Legato Bass Voice Allocation, Multi-Step Overlap-Add Sustain & 2-Pole Butterworth LPF
- **Statement:** **WHEN** synthesizing `SketchpadChannelRole.bass`, **THE SYSTEM SHALL**:
  1. Enforce **Mono-Legato Voice Allocation** (selecting the lowest active `scaleRow` if multiple rows exist on the same step) and sustain each note across subsequent empty steps up to $4 \times \Delta T_{\text{step}}$ ($\approx 530\text{ ms}$ at $113\text{ BPM}$) until the next bass onset, applying an $8\text{ ms}$ raised-cosine crossfade at retrigger boundaries.
  2. Filter the entire `bass` channel through a 2-pole Butterworth Low-Pass Filter with cutoff $f_c = 195\text{ Hz}$ ($Q = 0.707$) to eliminate high-frequency harshness.

### `REQ-P57-DSP-06`: Cantabile Multi-Step Lead Sustain & Automatic Diatonic Chord Voicing
- **Statement:** **WHEN** synthesizing `SketchpadChannelRole.lead` and `SketchpadChannelRole.chords`, **THE SYSTEM SHALL**:
  1. Sustain `lead` notes across subsequent empty steps up to $3 \times \Delta T_{\text{step}}$ (minimum gate $2.2 \times \Delta T_{\text{step}}$ + $180\text{ ms}$ overlap-add release tail) with a soft $12\text{ ms}$ onset and a $3,800\text{ Hz}$ 2-pole Butterworth LPF.
  2. Automatically voice single-note root triggers on `chords` into rich diatonic triads/minor-9th voicings ($f_{\text{root}}$, $f_{\text{3rd}}$, $f_{\text{5th}}$, and subtle $f_{\text{7th}}$) with $\pm 6\text{ cents}$ stereo chorus detuning and sustain across empty steps up to $4 \times \Delta T_{\text{step}}$.

---

## 2. Dedicated `Hi-Hats & Percs` Matrix Requirements (`REQ-P57-HATS`)

### `REQ-P57-HATS-01`: Dedicated 8-Row High-Frequency Percussion Synthesis (`synthesizeHatPercVoice`)
- **Statement:** **WHEN** synthesizing `SketchpadChannelRole.hats` in `MelodyWavSynthesizer`, **THE SYSTEM SHALL** route all 8 rows to a dedicated `synthesizeHatPercVoice` engine (never `_synthesizeDrumRackVoice`) implementing 8 distinct African & Studio high-frequency percussion voices:
  - `Row 0`: **Talking Conga Slap** ($460\text{ Hz} \to 380\text{ Hz}$ phase-integrated membrane slap, $\tau = 65\text{ ms}$)
  - `Row 1`: **Afro Wood Clave** ($1,420\text{ Hz} + 2,180\text{ Hz}$ hollow rosewood cavity resonator, $\tau = 18\text{ ms}$)
  - `Row 2`: **Shekere Gourd** ($4.6\text{ kHz}$ triple-grain beaded gourd friction envelope + $310\text{ Hz}$ gourd body)
  - `Row 3`: **Mbaḓi Seed Shaker** ($5.8\text{ kHz}$ dual-grain band-passed seed rattle with $16\text{ ms}$ scrape attack)
  - `Row 4`: **32nd Sgija Hat Roll** (3-hit micro-ratchet closed hat subdivision across $\Delta T_{\text{step}}$ with crescendo velocity $0.55 \to 0.78 \to 1.00$)
  - `Row 5`: **Closed Crisp Hat** ($8.2\text{ kHz}$ high-passed 6-oscillator metallic chick, $\tau = 22\text{ ms}$)
  - `Row 6`: **Open Shimmer Hat** ($7.2\text{ kHz}$ high-passed 6-oscillator metallic ring matrix, $\tau = 240\text{ ms}$)
  - `Row 7`: **Crash Shimmer** ($3.4\text{ kHz} - 9.2\text{ kHz}$ inharmonic bronze shimmer cluster, $\tau = 380\text{ ms}$)

### `REQ-P57-HATS-02`: Acoustic Open-Hat-to-Closed-Hat Choke Group
- **Statement:** **WHEN** `SketchpadChannelRole.hats` triggers an Open Shimmer Hat (`Row 6`) on step $s_1$ and subsequently triggers a Closed Crisp Hat (`Row 5`) or 32nd Sgija Hat Roll (`Row 4`) on step $s_2 > s_1$ while the Open Hat tail is still decaying, **THE SYSTEM SHALL** choke (rapidly attenuate over $8\text{ ms}$) the active Open Shimmer Hat envelope at the exact sample onset of step $s_2$.

### `REQ-P57-HATS-03`: Distinct UI Row Labels & Accurate Single-Pad Auditioning for `drums` vs. `hats`
- **Statement:** **WHEN** `state.activeChannelRole == SketchpadChannelRole.hats`, **THE SYSTEM SHALL** render `kHatPercVoiceNames` (`['Conga Slap', 'Wood Clave', 'Shekere', 'Mbaḓi Shaker', 'Sgija Roll', 'Closed Hat', 'Open Hat', 'Crash']`) in both Desktop and Mobile sequencer surfaces, and **WHEN** the user taps any cell or live pad on `drums` or `hats`, `MelodySketchpadNotifier` **SHALL** synthesize the exact corresponding drum or hat-perc voice via `MelodyWavSynthesizer.synthesizeSingleDrumOrHatWavBytes`.

---

## 3. "Jev" System-1 Calibrated DNA Resynthesizer Requirements (`REQ-P57-DNA`)

### `REQ-P57-DNA-01`: Strict Active-Channel Scope Isolation Law ($\mathcal{A}_{\text{active}}$)
- **Statement:** **WHEN** `SketchpadDnaResynthesizer.resynthesize` is invoked on a `MultiTrackGrooveEntity`, **THE SYSTEM SHALL** compute the active channel set:
  $$\mathcal{A}_{\text{active}} = \bigl\{ c \in \{\text{lead}, \text{chords}, \text{bass}, \text{drums}, \text{hats}\} \;\big|\; \text{groove.channels}[c].\text{steps.isNotEmpty} \bigr\}$$
  - **IF** $|\mathcal{A}_{\text{active}}| \ge 1$, **THE SYSTEM SHALL** analyze and modify **ONLY** the channels $c \in \mathcal{A}_{\text{active}}$, and **MUST** leave every channel $c \notin \mathcal{A}_{\text{active}}$ completely empty (`steps.isEmpty == true`).
  - **IF** $|\mathcal{A}_{\text{active}}| == 0$ (all 5 channels are empty), **THE SYSTEM SHALL** scope resynthesis exclusively to `{ fallbackActiveRole }` (`state.activeChannelRole`), leaving the other 4 channels empty.

### `REQ-P57-DNA-02`: 4-Axis Musical Coherence Diagnostic $Q(c) \in [0.0, 1.0]$
- **Statement:** **WHEN** evaluating an active channel $c \in \mathcal{A}_{\text{active}}$, **THE SYSTEM SHALL** compute a deterministic coherence score $Q(c) \in [0.0, 1.0]$ combining Rhythmic Grid Stability ($Q_{\text{rhythm}}$), Melodic Contour Smoothness ($Q_{\text{contour}}$), Harmonic Scale Gravity ($Q_{\text{tonal}}$), and Cross-Channel Vertical Consonance ($Q_{\text{vertical}}$) for pitched channels, or Pocket Alignment + Density Balance + Syncopation ($Q_{\text{perc}}$) for percussive channels.

### `REQ-P57-DNA-03`: Jev System-1 Calibrated Softmax Distribution & MAD Confidence
- **Statement:** **WHEN** resynthesizing step $(c, s)$ for $c \in \mathcal{A}_{\text{active}}$, **THE SYSTEM SHALL** compute an 8-row logit vector $z_r(c, s)$ conditioned on the user's `CreatorDnaProfile` (`topGenres`, `tempoPreference`, `vocalEnergyPreference`, `strengthPercent`), convert it via temperature-scaled softmax $p_r = \text{softmax}(z / T_c)_r$, and compute the Jev Mean Absolute Deviation confidence metric:
  $$\text{Confidence}(p) = \max\!\left(0.0, \; 1.0 - \frac{\sum_{r=0}^7 p_r |r - r^*|}{2.0}\right), \quad r^* = \arg\max_{r \in \{0..7\}} p_r$$

### `REQ-P57-DNA-04`: Adaptive Skill-Tier Bayesian Fusion (`Beginner`, `Intermediate`, `Pro`)
- **Statement:** **WHEN** applying Jev DNA resynthesis to channel $c \in \mathcal{A}_{\text{active}}$ with intervention weight $\lambda_c = (1.0 - Q(c))^{1.25} \in [0.10, 0.88]$, **THE SYSTEM SHALL** adapt its musical intervention to the user's detected coherence tier:
  - **Beginner Tier ($Q(c) < 0.40$):** Re-quantize erratic off-grid collisions into the Creator DNA genre pocket, smooth erratic octave leaps ($\ge 5$ rows) into stepwise/pentatonic contours, anchor downbeats to tonic/fifth (`Row 0` / `Row 4`), and raise post-resynthesis coherence to $Q_{\text{after}}(c) \ge 0.72$.
  - **Intermediate Tier ($0.40 \le Q(c) \le 0.75$):** Preserve user motif anchor notes while resolving dissonant clashes, locking bass/kick pockets, and weaving complementary call-and-response syncopation.
  - **Pro Tier ($Q(c) > 0.75$):** Preserve $\ge 80\%$ of the user's step pitches while applying micro-velocity humanization, Amapiano/Maskandi glide inflections (`hasGlide`), and high-confidence harmonic lock.

### `REQ-P57-DNA-05`: Cross-Channel Entanglement Order
- **Statement:** **WHEN** multiple channels are present in $\mathcal{A}_{\text{active}}$, **THE SYSTEM SHALL** process them in strict harmonic-rhythmic anchor order (`chords` $\to$ `bass` $\to$ `drums` $\to$ `hats` $\to$ `lead`) so that `bass` locks to `chords` roots, `drums` kicks lock to `bass` onsets, `hats` weave off-beat pockets around `drums`, and `lead` phrases breathe in the rhythmic gaps.

---

## 4. Clean Replacement, Undo History & UI Requirements (`REQ-P57-UNDO`)

### `REQ-P57-UNDO-01`: Clean In-Place Channel Replacement & Bounded 10-State Undo Stack
- **Statement:** **WHEN** the user triggers `applyDnaResynthesis()`, **THE SYSTEM SHALL** push a deep copy of the pre-resynthesis `MultiTrackGrooveEntity` onto `state.dnaUndoStack` (retaining up to 10 snapshots in LIFO order), cleanly replace the `steps` list of each channel $c \in \mathcal{A}_{\text{active}}$ (never blindly appending duplicate notes onto the same step/row), populate `state.lastDnaReport`, and re-synthesize the 44.1 kHz preview WAV buffer.

### `REQ-P57-UNDO-02`: Single-Tap DNA Undo Restoration
- **Statement:** **WHEN** the user taps the **`Undo`** button (`Key('sketchpad_undo_dna_btn')`) while `state.dnaUndoStack.isNotEmpty`, **THE SYSTEM SHALL** pop the most recent `MultiTrackGrooveEntity` snapshot from `dnaUndoStack`, restore `state.multiTrackGroove` and `state.activePattern` to that exact state, clear `lastDnaReport` if the stack becomes empty, and re-synthesize the preview WAV buffer.

### `REQ-P57-UNDO-03`: Sketchpad DNA Co-Creation Controls & Telemetry Banner
- **Statement:** **WHEN** `MelodySketchpadModal` is rendered, **THE SYSTEM SHALL** mount:
  1. An **`Apply DNA`** action button with `Key('sketchpad_apply_dna_btn')` in the transport bar.
  2. A conditional **`Undo`** action button with `Key('sketchpad_undo_dna_btn')` whenever `state.canUndoDna` (`state.dnaUndoStack.isNotEmpty`) is true.
  3. A dismissible telemetry banner with `Key('sketchpad_dna_report_banner')` whenever `state.lastDnaReport != null`, displaying the inferred genre style, coherence boost ($Q_{\text{before}} \to Q_{\text{after}}$), Jev MAD confidence percentage, and count of resynthesized active channels.

---

## 5. Non-Functional Requirements (`REQ-P57-NFR`)

- **`REQ-P57-NFR-01` (Deterministic Execution):** `SketchpadDnaResynthesizer.resynthesize` **SHALL** be 100% deterministic for a given `MultiTrackGrooveEntity` and `CreatorDnaProfile` (zero unseeded `Random()` calls).
- **`REQ-P57-NFR-02` (Zero External Native Dependencies):** All 44.1 kHz DSP filtering, phase integration, sidechain ducking, Padé limiting, and Jev DNA matrix math **SHALL** be implemented in pure Dart (`dart:math`, `dart:typed_data`).
- **`REQ-P57-NFR-03` (Design Token & Icon Hygiene):** All UI additions in `melody_sketchpad_modal.dart` **SHALL** use `AppColors`, `AppTypography`, `AppSpacing`, `AppRadius`, and `PhosphorIcon` (`package:phosphor_icons/phosphor_icons.dart`) with zero raw emojis or hardcoded hex colors.
- **`REQ-P57-NFR-04` (Backward Compatibility):** All existing Phase 27/32 widget keys (`sketchpad_play_stop_btn`, `sketchpad_attach_reference_btn`, `sketchpad_save_vault_btn`, `sketchpad_clear_btn`, `sketchpad_channel_tab_*`, `sketchpad_cell_*`) **SHALL** remain intact.

---

## 6. Requirement-to-Test Traceability Matrix

| Requirement ID | Primary Implementation File(s) | Verification Test Case in `phase57_sketchpad_dna_and_acoustic_dsp_test.dart` | Gate |
| :--- | :--- | :--- | :---: |
| `REQ-P57-DSP-01` | `melody_wav_synthesizer.dart` | `P57-T01: Master 5-channel full-velocity summing stays strictly bounded within Int16 without wrap-around` | `G-01` |
| `REQ-P57-DSP-02` | `melody_wav_synthesizer.dart` | `P57-T02: Kick-triggered sidechain envelope ducks bass amplitude on simultaneous Kick+Bass hits` | `G-01` |
| `REQ-P57-DSP-03` | `melody_wav_synthesizer.dart` | `P57-T03: Phase-integrated sub-bass and kick envelopes exhibit monotonic pitch decay with zero high-freq beep` | `G-01` |
| `REQ-P57-DSP-04` | `melody_sketchpad_models.dart` | `P57-T04: Role-aware resolveScaleFrequencyHz anchors bass to Octaves 1-2 (36-115 Hz) and lead to Octaves 4-5` | `G-03` |
| `REQ-P57-DSP-05`, `06` | `melody_wav_synthesizer.dart` | `P57-T05: Multi-step overlap-add sustain holds bass and lead notes across empty steps (>140 ms)` | `G-03` |
| `REQ-P57-HATS-01..03` | `melody_wav_synthesizer.dart`, `melody_sketchpad_models.dart` | `P57-T06: Hi-Hats & Percs synthesizes 8 high-freq voices with Open->Closed Hat choke group and distinct labels` | `G-02` |
| `REQ-P57-DNA-01` | `sketchpad_dna_resynthesizer.dart` | `P57-T07: Strict Active-Channel Scope Isolation (1, 2, 3, 5 active channels never populate empty channels)` | `G-04` |
| `REQ-P57-DNA-02..05` | `sketchpad_dna_resynthesizer.dart` | `P57-T08: Jev 4-Axis Coherence Q(c), MAD Confidence, and Beginner/Intermediate/Pro adaptive fusion` | `G-05` |
| `REQ-P57-UNDO-01..03` | `melody_sketchpad_provider.dart`, `melody_sketchpad_modal.dart` | `P57-T09: Apply DNA clean replacement, 10-state Undo stack restoration, and widget telemetry banner` | `G-06` |

