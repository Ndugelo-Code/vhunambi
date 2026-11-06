# Phase 57 Blueprint: System-1 Calibrated "Jev" DNA Melody Resynthesizer & Acoustic-True 44.1 kHz 5-Channel DSP Overhaul

**Phase Number:** 57  
**Track / Module:** `apps/vhunambi_client/lib/features/studio/` (`domain/models`, `domain/services`, `presentation/providers`, `presentation/widgets`)  
**Architecture Standard:** All-Gemini Engineering Standard (Gemini 4 Argon Browser Architect + Antigravity Gemini 4 Argon Codebase Forensic Auditor + Gemini 3.8 Flash / Argon Dual-Wave Executor)  
**Target Frame Budget:** $\le 8.33\text{ ms}$ UI frame time ($120\text{ Hz}$ lock); $\le 45\text{ ms}$ synchronous 5-channel stereo WAV synthesis + Jev DNA inference latency  
**Status:** Specification Complete — Ready for Execution

---

## 1. Executive Overview & North Star Vision

During live physical-device auditioning of the **Melody & Groove Sketchpad** on Android (`Huawei JNY-LX1`), four compounding acoustic and musical usability bottlenecks prevented the 5-channel sequencer from reaching studio production readiness:

1. **Master Player "Bleeping" & Phase-Inversion Chirps on Bass & Drums:**
   - **Phase-Derivative Chirp Bug:** In `MelodyWavSynthesizer`, percussive and sub-bass pitch drops (`amapianoLogDrum`, `hipHop808Sub`, `gqomDarkSub`, and Drum Rack Kicks) multiplied time-varying frequency $f(t) = f_0 + \Delta f e^{-t/\tau}$ directly by $t$ inside $\sin(2\pi f(t) t)$ rather than integrating instantaneous phase $\Phi(t) = 2\pi \int_0^t f(\tau)\,d\tau$. By the product rule, the instantaneous frequency $f_{\text{inst}}(t) = f_0 + \Delta f e^{-t/\tau}(1 - t/\tau)$ collapsed through zero and went **negative** at $t > \tau$, reversing phase mid-cycle and emitting a synthetic FM chirp on every note.
   - **Sine-Tone "Knock" Bleeps:** Pure high-frequency sine oscillators at $380\text{ Hz}$, $420\text{ Hz}$, and $620\text{ Hz}$ (`math.sin(2 * pi * 420 * t)`) were summed directly into sub-bass and kick voices, producing an audible telephone-like beep on every bass/kick hit.
   - **Master Bus Headroom & Unducked Low-End Summing:** Simultaneous Kick + Sub-Bass + Chords hits summed without per-role headroom calibration or Kick-to-Bass sidechain ducking.
2. **`Hi-Hats & Percs` Playing Kicks and Snares Instead of High-Frequency Percussion:**
   - Both `SketchpadChannelRole.drums` and `SketchpadChannelRole.hats` routed to `_synthesizeDrumRackVoice` and displayed `kDrumRackVoiceNames`. Consequently, Rows 0–4 on the **Hi-Hats & Percs** tab triggered Sub 808 Kicks, Punch Kicks, Snares, and Claps instead of dedicated hi-hats, shakers, shekeres, claves, and conga slaps. Furthermore, `_synthesizeSingleDrumHit` in `MelodySketchpadNotifier` hardcoded a $55\text{ Hz}$ `amapianoLogDrum` note for every single drum/hat pad tap.
3. **`Bass & Sub` and `Lead Melody` Sounding Like Rapid-Fire High-Tempo Beats:**
   - At $113\text{ BPM}$, a single 16th-note step lasts only $\Delta T_{\text{step}} = 132.7\text{ ms}$. Every bass and lead note was chopped at a single-step gate ($132\text{ ms}$), turning melodic lines into rapid staccato clicks. Additionally, `resolveScaleFrequencyHz` determined octave strictly from `SketchpadInstrument` rather than anchoring `SketchpadChannelRole.bass` to true Sub-Bass Octaves 1–2 ($\text{MIDI } 28..45$, $41.2\text{ Hz} - 110.0\text{ Hz}$) and `lead` to Octaves 4–5 ($\text{MIDI } 60..81$).
4. **Absence of Intelligent, Active-Channel-Scoped Creator DNA Groove Co-Creation:**
   - Creators needed a one-tap **`Apply DNA`** (`SketchpadDnaResynthesizer`) engine inspired by the **Jev System-1 Calibrated Inference** paradigm: evaluating the user's current sketch across 4 musical coherence axes $Q(c) \in [0, 1]$, computing MAD-calibrated pitch/rhythm probability distributions conditioned on `CreatorDnaProfile`, strictly isolating modifications to the user's **active (non-empty) channels** ($\mathcal{A}_{\text{active}}$), cleanly replacing the active channels in-place without layered chaos, and providing an instant 10-deep **`Undo`** stack.

---

## 2. Forensic Post-Mortem Comparison Box (Phase 32 Legacy vs. Phase 57 Architecture)

```text
+--------------------------------------------------------------------------------------------------+
| LEGACY PHASE 27/32 SKETCHPAD DEFECTS              | PHASE 57 ACOUSTIC & JEV DNA ARCHITECTURE     |
+---------------------------------------------------+----------------------------------------------+
| 1. Unintegrated Pitch Drop & Sine Beep Knock:     | 1. True Phase Integral + Padé [3/2] Limiter  |
|    sin(2*pi*(f0 + df*e^(-t/tau))*t) inverts       |    Phi(t) = 2*pi*(f0*t + df*tau*(1-e^-t/tau))|
|    instantaneous frequency at t > tau, plus       |    + 2-pole Butterworth LPF (195 Hz on Bass) |
|    raw 380Hz/420Hz/620Hz sine knocks and          |    + Kick-triggered -4.5 dB Bass Sidechain   |
|    uncalibrated multi-track summing cause bleeps. |    + Bounded Padé [3/2] tanh soft limiter.   |
+---------------------------------------------------+----------------------------------------------+
| 2. Shared Drum Rack on Hi-Hats & Percs Tab:       | 2. Dedicated 8-Row Hat & Perc Synthesis Matrix|
|    SketchpadChannelRole.hats calls                |    synthesizeHatPercVoice + kHatPercVoiceNames|
|    _synthesizeDrumRackVoice; Rows 0-4 play        |    (Talking Conga, Wood Clave, Shekere,      |
|    808 Kicks, Punch Kicks, and Snares.            |    Mbaḓi Shaker, 32nd Sgija Roll, Closed Hat,|
|    Single-pad audition plays 55 Hz Log Drum.      |    Open Shimmer Hat w/ Choke Group, Crash).  |
+---------------------------------------------------+----------------------------------------------+
| 3. 132 ms Staccato Gate Chopping & Wrong Octaves: | 3. Multi-Step Overlap-Add & Octave Anchoring:|
|    Bass & Lead notes cut off at 1 step (132 ms)   |    Bass anchored to Octaves 1-2 (41-110 Hz)  |
|    and use instrument-only octave lookup, making  |    with Mono-Legato sustain across empty     |
|    melodies sound like high-tempo percussive      |    steps (up to 4 steps) + 8ms crossfade;    |
|    machine-gun beats.                             |    Lead anchored to Octaves 4-5 w/ sustain.  |
+---------------------------------------------------+----------------------------------------------+
| 4. No Creator DNA Groove Resynthesis:             | 4. Jev System-1 Calibrated DNA Resynthesizer:|
|    Users had to manually program all 16 steps     |    Strict Active-Channel Scope Isolation     |
|    with no adaptive co-creation or Undo history.  |    (A_active), 4-Axis Coherence Q(c), MAD    |
|                                                   |    Confidence, Clean Replace & 10-Step Undo. |
+---------------------------------------------------+----------------------------------------------+
```

---

## 3. Multi-Layer Decoupled System Architecture

```text
+==================================================================================================+
|                        PRESENTATION LAYER (melody_sketchpad_modal.dart)                          |
|                                                                                                  |
|  +--------------------------------------------------------------------------------------------+  |
|  | Top Studio Header & 5-Channel Role Ribbon (Lead | Chords | Bass | Drums | Hi-Hats & Percs) |  |
|  +--------------------------------------------------------------------------------------------+  |
|  | Jev DNA Telemetry Banner (Key: 'sketchpad_dna_report_banner')                              |  |
|  | [DNA Calibrated • Q: 64% -> 89% • MAD Conf: 82% • Active: Bass, Drums • Amapiano Lock] [x] |  |
|  +--------------------------------------------------------------------------------------------+  |
|  | Dual-Viewport Sequencer Surface                                                            |  |
|  |  - Desktop (>1024px): 16-Step x 8-Row Matrix (Role-Aware Labels: Scale / Drum / Hat-Perc)  |  |
|  |  - Mobile (<768px):   4-Bar Paginated 8x4 HIG Matrix + Live 8-Pad Performance Deck         |  |
|  +--------------------------------------------------------------------------------------------+  |
|  | Bottom Transport & DNA Co-Creation Bar                                                     |  |
|  |  [Play/Stop]  [Apply DNA (Key: 'sketchpad_apply_dna_btn')]  [Undo ('sketchpad_undo_dna_btn')]|
|  |  [Ref Conditioning Slider]                        [Save Vault]  [Attach Reference]         |  |
|  +--------------------------------------------------------------------------------------------+  |
+================================================|=================================================+
                                                 |
                                                 v
+==================================================================================================+
|                    STATE MANAGEMENT LAYER (melody_sketchpad_provider.dart)                       |
|                                                                                                  |
|  MelodySketchpadState:                                                                           |
|   - multiTrackGroove: MultiTrackGrooveEntity                                                     |
|   - activeChannelRole: SketchpadChannelRole                                                      |
|   - dnaUndoStack: List<MultiTrackGrooveEntity> (Bounded LIFO Stack, Max 10 Snapshots)            |
|   - lastDnaReport: DnaResynthesisReport?                                                         |
|                                                                                                  |
|  MelodySketchpadNotifier:                                                                        |
|   - applyDnaResynthesis() -> Snapshots current groove -> Runs SketchpadDnaResynthesizer          |
|                           -> Replaces ONLY A_active channels -> Auto-synthesizes 44.1 kHz WAV    |
|   - undoDnaResynthesis()  -> Pops top snapshot from dnaUndoStack -> Restores exact prior groove  |
|   - _auditionSingleScaleRow(row) -> Role-aware single-note / drum-hit / hat-perc audition        |
+=======================|==================================================|=======================+
                        |                                                  |
                        v                                                  v
+===============================================+  +===============================================+
|   JEV DNA RESYNTHESIS ENGINE                  |  |   ACOUSTIC 44.1 kHz DSP ENGINE                |
|   (sketchpad_dna_resynthesizer.dart)          |  |   (melody_wav_synthesizer.dart)               |
|                                               |  |                                               |
| 1. Active-Channel Scope Detector (A_active):  |  | 1. Role-Aware Octave & Sustain Planner:       |
|    Inspects non-empty channels in groove.     |  |    - Bass: Oct 1-2 (41-110 Hz), Mono-Legato   |
|    Never touches empty channels!              |  |      sustain across empty steps, 195 Hz LPF.  |
| 2. 4-Axis Musical Coherence Q(c) in [0, 1]:   |  |    - Chords: Oct 3-4 (130-523 Hz), Diatonic   |
|    Rhythm + Contour + Tonal + Vertical Lock.  |  |      Triad/Min9 voicing, +/-6c stereo chorus. |
| 3. Jev System-1 Logit & Softmax Engine:       |  |    - Lead: Oct 4-5 (261-880 Hz), Multi-step   |
|    Computes p(r | c, s, DNA) over 8 rows      |  |      legato sustain, 3.8 kHz warm LPF.        |
|    and MAD Confidence = 1 - MAD(p)/MAD_unif.  |  | 2. Decoupled Drum Rack vs. Hat/Perc Matrix:   |
| 4. Adaptive Bayesian Fusion (lambda_c):       |  |    - Drums: 8-row Phase-Integrated Drum Rack. |
|    - Beginner (Q < 0.40): Structural Rescue   |  |    - Hats:  8-row High-Freq Hat/Perc Matrix   |
|    - Intermediate (0.40..0.75): Groove Polish |  |      with Open-to-Closed Hat Choke Group.     |
|    - Pro (Q > 0.75): Micro-Velocity & Inflect |  | 3. Master Bus Sidechain & Padé [3/2] Limiter: |
| 5. Cross-Channel Entanglement:                |  |    Kick ducks Bass by -4.5 dB (4ms/55ms);     |
|    chords -> bass -> drums -> hats -> lead.   |  |    Padé tanh soft-clipper + Int16 clamp.      |
+===============================================+  +===============================================+
```

---

## 4. 5-Channel Acoustic Frequency & Percussion Taxonomy

### 4.1 Pitched Melodic Channels (`bass`, `chords`, `lead`)

| Channel Role | Target MIDI Range | Fundamental Frequency Band | Polyphony & Gate Sustain Physics | Filtering & Spatialization |
| :--- | :--- | :--- | :--- | :--- |
| **`bass`** (`Bass & Sub`) | $\text{MIDI } 28..45$ (Octaves 1–2) | $41.20\text{ Hz} - 110.00\text{ Hz}$ | **Mono-Legato Sustain**: Holds across subsequent empty steps up to $4 \times \Delta T_{\text{step}}$ ($\approx 530\text{ ms}$) until next bass onset; $8\text{ ms}$ cosine retrigger crossfade. | 2-Pole Butterworth LPF ($f_c = 195\text{ Hz}$, $Q = 0.707$), phase-integrated log-drum thud ($145\text{ Hz} \to f_0$ over $12\text{ ms}$), Dead-Center Pan ($0.0$). |
| **`chords`** (`Chords & Pads`) | $\text{MIDI } 48..72$ (Octaves 3–4) | $130.81\text{ Hz} - 523.25\text{ Hz}$ | **Polyphonic Sustain**: Holds across empty steps up to $4 \times \Delta T_{\text{step}}$ ($\approx 530\text{ ms}$) with automatic diatonic Root + 3rd + 5th (+ 7th/9th) chord stack when a single root pad is placed. | Warm $2.8\text{ kHz}$ LPF rolloff, $\pm 6\text{ cents}$ Left/Right stereo chorus detuning, Wide Stereo Pan. |
| **`lead`** (`Lead Melody`) | $\text{MIDI } 60..81$ (Octaves 4–5) | $261.63\text{ Hz} - 880.00\text{ Hz}$ | **Cantabile Phrase Sustain**: Holds across empty steps up to $3 \times \Delta T_{\text{step}}$ (minimum $2.2 \times \Delta T_{\text{step}}$ gate + $180\text{ ms}$ overlap-add release tail), $12\text{ ms}$ breath/hammer attack. | 2-Pole Butterworth LPF ($f_c = 3,800\text{ Hz}$), $5.5\text{ Hz}$ expressive vibrato ($\pm 0.35\%$ after $90\text{ ms}$), Slight Right Pan ($+0.12$). |

### 4.2 Decoupled Percussion Channels (`drums` vs. `hats`)

| Row Index | `SketchpadChannelRole.drums` (`kDrumRackVoiceNames`) | `SketchpadChannelRole.hats` (`kHatPercVoiceNames`) | Acoustic Synthesis Topology for `hats` (`synthesizeHatPercVoice`) |
| :---: | :--- | :--- | :--- |
| **Row 7** (Top) | `Shaker` | **`Crash Shimmer`** | 6-oscillator inharmonic bronze cluster ($3.4\text{ kHz} - 9.2\text{ kHz}$) + high-passed air sheen, $\tau = 380\text{ ms}$. |
| **Row 6** | `Open Hat` | **`Open Shimmer Hat`** | 6-oscillator metallic square-ring matrix high-passed at $7.2\text{ kHz}$, $\tau = 240\text{ ms}$. **Choke Group**: truncated in $8\text{ ms}$ whenever Row 5 or Row 4 triggers! |
| **Row 5** | `Closed Hat` | **`Closed Crisp Hat`** | High-passed ($8.2\text{ kHz}$) metallic chick transient, tight exponential decay $\tau = 22\text{ ms}$. |
| **Row 4** | `Clap` | **`32nd Sgija Roll`** | 3-hit micro-ratchet closed hat roll subdividing $\Delta T_{\text{step}}$ into $3 \times (\Delta T_{\text{step}} / 3)$ hits with crescendo velocity $0.55 \to 0.78 \to 1.00$. |
| **Row 3** | `Rimshot` | **`Mbaḓi Seed Shaker`** | Dual-grain band-passed woven seed rattle ($f_c = 5.8\text{ kHz}$, $Q = 3.0$) with $16\text{ ms}$ forward-back attack-scrape envelope. |
| **Row 2** | `Snare` | **`Shekere Gourd`** | Triple-grain beaded gourd friction envelope ($f_c = 4.6\text{ kHz}$) + hollow gourd body resonance ($310\text{ Hz}$, $\tau = 28\text{ ms}$). |
| **Row 1** | `Punch Kick` | **`Afro Wood Clave`** | Dual-mode African rosewood cavity resonator ($1,420\text{ Hz} + 2,180\text{ Hz}$, $\tau = 18\text{ ms}$) with zero sub-bass content. |
| **Row 0** (Bottom) | `Sub 808` | **`Talking Conga Slap`** | Phase-integrated membrane pitch bend ($460\text{ Hz} \to 380\text{ Hz}$ over $10\text{ ms}$, $\tau = 65\text{ ms}$) + crisp palm transient. |

---

## 5. The "Jev" System-1 Calibrated DNA Resynthesis Pipeline

```text
+--------------------------------------------------------------------------------------------------+
| STEP 1: STRICT ACTIVE-CHANNEL SCOPE ISOLATION (REQ-P57-DNA-01)                                   |
|   A_active = { c in [lead, chords, bass, drums, hats] | groove.channels[c].steps.isNotEmpty }    |
|   - If |A_active| == 0: Fallback to { state.activeChannelRole } so user still gets a seed groove.|
|   - If |A_active| >= 1: ONLY channels in A_active are analyzed and modified.                     |
|                         All channels NOT in A_active remain 100% untouched (0 notes added).      |
+--------------------------------------------------------------------------------------------------+
                                                 |
                                                 v
+--------------------------------------------------------------------------------------------------+
| STEP 2: 4-AXIS MUSICAL COHERENCE DIAGNOSTIC Q(c) in [0.0, 1.0] (REQ-P57-DNA-02)                  |
|   For each pitched channel c in A_active:                                                        |
|     Q(c) = 0.30 * Q_rhythm(c) + 0.30 * Q_contour(c) + 0.25 * Q_tonal(c) + 0.15 * Q_vertical(c)   |
|   For each percussive channel c in A_active (drums, hats):                                       |
|     Q(c) = Q_perc(c) = 0.45 * S_pocket(c) + 0.35 * S_density(c) + 0.20 * S_syncopation(c)        |
+--------------------------------------------------------------------------------------------------+
                                                 |
                                                 v
+--------------------------------------------------------------------------------------------------+
| STEP 3: JEV SYSTEM-1 CALIBRATED DISTRIBUTION & MAD CONFIDENCE (REQ-P57-DNA-03)                   |
|   - Intervention Strength: lambda_c = (1.0 - Q(c))^1.25 clamped to [0.10, 0.88]                  |
|   - Softmax Temperature:   T_c = 0.35 + 0.65 * (1.0 - S_DNA)                                     |
|   - Row Logits z_r(c, s):  Combines User Anchors + Genre Prior + Markov Step Transition          |
|                            + Harmonic Gravity (Root/5th/3rd) + Cross-Channel Lock.               |
|   - Calibrated Softmax:    p_r = exp(z_r / T_c) / sum_k exp(z_k / T_c)                           |
|   - Jev MAD Confidence:    Conf(p) = max(0, 1 - (sum_r p_r * |r - r*|) / 2.0)                    |
+--------------------------------------------------------------------------------------------------+
                                                 |
                                                 v
+--------------------------------------------------------------------------------------------------+
| STEP 4: CROSS-CHANNEL ENTANGLEMENT & CLEAN IN-PLACE REPLACEMENT (REQ-P57-DNA-04)                 |
|   Processed in musical anchor order (for channels present in A_active):                          |
|     1. chords  (Establishes harmonic root sequence r_chord(s) across the 16 steps)               |
|     2. bass    (Locks to r_chord(s) on downbeats & log-drum syncopated pockets; mono-legato)     |
|     3. drums   (Locks kick to bass onsets or anchors backbeat snare/rimshot)                     |
|     4. hats    (Weaves off-beat shaker/hat pockets around drum hits + Row 4 Sgija rolls)         |
|     5. lead    (Weaves call-and-response pentatonic motif in gaps of bass/vocal rhythm)          |
|   Replaces channel steps cleanly (no double-stacking chaos) & pushes prior groove to Undo stack. |
+--------------------------------------------------------------------------------------------------+
```

---

## 6. Dual-Viewport UI & Jev DNA Telemetry Wireframe

```text
+--------------------------------------------------------------------------------------------------+
| [PianoIcon] Melody & Groove Sketchpad   [Rhodes v] [F#m Pentatonic v] [113 BPM -/+] [Clear] [X]  |
+--------------------------------------------------------------------------------------------------+
| [ Lead • 4 ]  [ Chords ]  [ Bass • 5 ]  [ Drums • 6 ]  [ Hi-Hats & Percs • 8 ]   [Grid | Pads]   |
+--------------------------------------------------------------------------------------------------+
| [Sparkle] DNA Calibrated (Amapiano) • Coherence 58% -> 89% • MAD Conf 84% • 3 Active Ch     [X]  |
|           <-- Key('sketchpad_dna_report_banner')                                                 |
+--------------------------------------------------------------------------------------------------+
| Crash Shimmer    | [ ] [ ] [ ] [ ] | [ ] [ ] [ ] [ ] | [ ] [ ] [ ] [ ] | [ ] [ ] [ ] [ ] |       |
| Open Shimmer Hat | [ ] [ ] [ ] [•] | [ ] [ ] [ ] [ ] | [ ] [ ] [ ] [•] | [ ] [ ] [ ] [ ] |       |
| Closed Crisp Hat | [•] [ ] [•] [ ] | [•] [ ] [•] [ ] | [•] [ ] [•] [ ] | [•] [ ] [ ] [ ] |       |
| 32nd Sgija Roll  | [ ] [ ] [ ] [ ] | [ ] [ ] [ ] [ ] | [ ] [ ] [ ] [ ] | [ ] [ ] [•] [ ] |       |
| Mbaḓi Shaker     | [ ] [•] [ ] [•] | [ ] [•] [ ] [•] | [ ] [•] [ ] [•] | [ ] [•] [ ] [•] |       |
| Shekere Gourd    | [ ] [ ] [•] [ ] | [ ] [ ] [ ] [•] | [ ] [ ] [•] [ ] | [ ] [ ] [ ] [•] |       |
| Afro Wood Clave  | [•] [ ] [ ] [•] | [ ] [ ] [•] [ ] | [•] [ ] [ ] [•] | [ ] [ ] [•] [ ] |       |
| Talking Conga    | [ ] [ ] [ ] [ ] | [ ] [•] [ ] [ ] | [ ] [ ] [ ] [ ] | [ ] [•] [ ] [•] |       |
+--------------------------------------------------------------------------------------------------+
| [ (>) ]  [Sparkle Apply DNA]  [Undo (2)]   Ref: 65% [====o===]   [Bookmark]  [Attach Reference]  |
|          ^Key('sketchpad_apply_dna_btn')   ^Key('sketchpad_undo_dna_btn')                        |
+--------------------------------------------------------------------------------------------------+
```

---

## 7. Mathematical Formulations Summary

### 7.1 Bounded Padé `[3/2]` $\tanh$ Master Soft-Knee Limiter
$$\tanh_{\text{Pade}}(x) = \begin{cases} -1.0, & x \le -3.0 \\ +1.0, & x \ge +3.0 \\ \dfrac{x(27 + x^2)}{27 + 9x^2}, & |x| < 3.0 \end{cases}$$

### 7.2 Kick-Triggered Bass Sidechain Ducking Envelope
$$G_{\text{duck}}(n) = 1.0 - 0.41 \sum_{n_k \in \mathcal{K}_{\text{kick}}} \mathcal{E}_{\text{sc}}\!\left(\frac{n - n_k}{f_s}\right), \quad \mathcal{E}_{\text{sc}}(\Delta t) = \begin{cases} 0, & \Delta t < 0 \\ \frac{\Delta t}{0.004}, & 0 \le \Delta t < 0.004 \\ \exp\!\left(-\frac{\Delta t - 0.004}{0.055}\right), & \Delta t \ge 0.004 \end{cases}$$
clamped to $G_{\text{duck}}(n) \in [0.59, 1.0]$.

### 7.3 True Phase-Integrated Pitch Envelope (Zero Phase-Inversion Chirp)
$$\Phi(t) = 2\pi \int_0^t \left(f_0 + \Delta f \, e^{-\tau / \tau_p}\right) d\tau = 2\pi \left( f_0 t + \Delta f \cdot \tau_p \left(1 - e^{-t / \tau_p}\right) \right)$$

### 7.4 Jev System-1 MAD Confidence Metric
Given softmax row distribution $p = (p_0, \dots, p_7)$ with mode $r^* = \arg\max_{r \in \{0..7\}} p_r$:
$$\text{MAD}(p) = \sum_{r=0}^7 p_r \, |r - r^*|, \quad \text{Confidence}(p) = \max\!\left(0.0, \; 1.0 - \frac{\text{MAD}(p)}{\text{MAD}_{\text{unif}}}\right), \quad \text{MAD}_{\text{unif}} = 2.0$$

---

## 8. Verification Gates (`G-01` through `G-06`)

| Gate ID | Verification Gate Description | Target Pass Criterion |
| :---: | :--- | :--- |
| **`G-01`** | **Zero Master Bleep / Int16 Wrap-Around Gate** | 5 simultaneous full-velocity channels (`lead`, `chords`, `bass`, `drums`, `hats`) at `masterDrive = 1.0` produce valid PCM16 stereo WAV with zero NaN/Inf, zero wrap-around polarity inversions, and peak $|\text{sample}| \le 32,767$. |
| **`G-02`** | **Decoupled Hi-Hats & Percs Synthesis Gate** | `SketchpadChannelRole.hats` uses `kHatPercVoiceNames` and `synthesizeHatPercVoice`; spectral centroid / zero-crossing rate of `hats` Rows 0–4 is strictly high-frequency percussion ($> 1,200\text{ Hz}$ ZCR) compared to `drums` Rows 0–1 Sub 808 Kicks ($< 250\text{ Hz}$ ZCR), and Open Hat (Row 6) is choked when Closed Hat (Row 5) triggers. |
| **`G-03`** | **True Sub-Bass Octave & Multi-Step Sustain Gate** | `resolveScaleFrequencyHz(..., role: SketchpadChannelRole.bass)` resolves all 8 rows strictly inside $[36.0\text{ Hz}, 115.0\text{ Hz}]$ regardless of selected `SketchpadInstrument`, and sustained bass/lead notes across empty steps maintain continuous non-zero RMS past step 1 ($t > 140\text{ ms}$). |
| **`G-04`** | **Strict Active-Channel Scope Isolation Gate** | Calling `applyDnaResynthesis()` when $k \in \{1, 2, 3, 4\}$ channels have notes modifies **only** those $k$ channels; all $5 - k$ empty channels remain at `steps.isEmpty == true`. |
| **`G-05`** | **Jev Coherence Monotonicity & Adaptive Tier Gate** | Across chaotic Beginner patterns ($Q < 0.40$), Intermediate grooves ($0.40 \le Q \le 0.75$), and Pro grooves ($Q > 0.75$), `SketchpadDnaResynthesizer` achieves $Q_{\text{after}}(c) \ge Q_{\text{before}}(c)$ (and $Q_{\text{after}}(c) \ge 0.72$ for Beginner inputs) while preserving $\ge 80\%$ of Pro user step pitches. |
| **`G-06`** | **Clean In-Place Replacement & 10-State Undo Gate** | `applyDnaResynthesis()` pushes prior groove to `dnaUndoStack` (capped at 10) and updates `lastDnaReport`; `undoDnaResynthesis()` restores the exact bit-for-bit prior `MultiTrackGrooveEntity`. |

