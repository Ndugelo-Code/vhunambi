# Phase 32: Studio-Grade 44.1 kHz Multi-Track Melody & Drum Engine — Requirements

**Document Version:** 1.0.0  
**Status:** Specification Draft for Verification with Argon  

---

## 1. Functional Requirements

### 1.1 Audio Engine & Synthesis Fidelity (`Track A`)
- **REQ-SKP2-AUDIO-01 (44.1 kHz Stereo Master Pipeline):**
  - All audio synthesis in `MelodyWavSynthesizer` must output **44,100 Hz 16-bit PCM RIFF/WAVE** stereo audio buffers.
  - The legacy `22,050 Hz` sample rate is deprecated to eliminate Nyquist foldover distortion above 11 kHz.
- **REQ-SKP2-AUDIO-02 (Sample-by-Sample Continuous Phase Integration):**
  - All frequency sweeps (kicks, 808 subs, log-drum pitch attacks, vibrato, and pitch glides) must integrate phase on a per-sample basis:
    $$\phi[n] = \left(\phi[n - 1] + \frac{2\pi \cdot f_{\text{inst}}[n]}{44100}\right) \pmod{2\pi}$$
  - Computing `math.sin(2 * math.pi * f(t) * t)` with dynamic $f(t)$ is strictly forbidden.
- **REQ-SKP2-AUDIO-03 (Physical Plucked-String Waveguides):**
  - Guitars (`maskandiGuitar`, `electricGuitar`) and Solo Violin (`soloViolin`) must implement a digital waveguide using a Karplus-Strong feedback loop of length $N = \lfloor 44100 / f_0 \rfloor$, a single-pole damping low-pass filter, and acoustic body resonance.
- **REQ-SKP2-AUDIO-04 (Breath-Bore Resonators with Vibrato):**
  - Bamboo Flute (`bambooFlute`) and Soprano Saxophone (`sopranoSax`) must feature a soft breath attack transient ($40\text{ms}$), 5 Hz human vibrato LFO ($\pm 0.8\%$ frequency excursion), band-passed air chiff, and warm reed harmonic roll-off.
- **REQ-SKP2-AUDIO-05 (FL Studio DX10 Log Drum & 808 Sub):**
  - Amapiano Log Drum (`amapianoLogDrum`) and Hip-Hop 808 Sub (`hipHop808Sub`) must feature a phase-integrated wooden knock transient ($380\text{ Hz} \rightarrow f_0$ over $16\text{ms}$), 2-operator FM body ($2.0 \times f_0$), phase-locked sub-octave sine ($0.5 \times f_0$), and smooth cubic $-5\text{ semitone}$ pitch glide (`normT > 0.30`).
- **REQ-SKP2-AUDIO-06 (8-Row Studio Drum Rack):**
  - When editing `drums` or `hats` channels, the 8 rows must synthesize dedicated studio drum voices across 6 genre kits (`amapiano`, `hipHop`, `gqom`, `afrobeats`, `house`, `pop`):
    - Row 0: Sub 808 / Log Kick
    - Row 1: Studio Punch Kick ($160\text{ Hz} \rightarrow 48\text{ Hz}$ sweep)
    - Row 2: Dual-Membrane Crisp Snare ($185\text{ Hz} + 330\text{ Hz}$ + band-passed wires)
    - Row 3: Woody Rimshot / Wood Clack ($480\text{ Hz} + 1150\text{ Hz}$)
    - Row 4: Diffused Handclap ($1.5\text{ kHz}$ band-passed 4-burst grain)
    - Row 5: Closed Metallic Hi-Hat ($7.5\text{ kHz}$ high-pass, $25\text{ms}$ decay)
    - Row 6: Open Shimmer Cymbal/Hat ($220\text{ms}$ decay)
    - Row 7: African Mbaḓi Shaker / Conga Slap ($240\text{ Hz}$)

---

### 1.2 Multi-Track Channel Rack & Master Drive Bus (`Track B`)
- **REQ-SKP2-TRACK-01 (5-Channel Master Groove Model):**
  - The sketchpad state must support 5 synchronized channel tracks:
    1. `SketchpadChannelRole.lead`
    2. `SketchpadChannelRole.chords`
    3. `SketchpadChannelRole.bass`
    4. `SketchpadChannelRole.drums`
    5. `SketchpadChannelRole.hats`
- **REQ-SKP2-TRACK-02 (Independent Channel Attributes):**
  - Each channel must maintain its own `List<MelodyStepNote> steps`, `SketchpadInstrument instrument`, `double volume` ($0.0 \dots 1.2$), `bool isMuted`, and `bool isSolo`.
- **REQ-SKP2-TRACK-03 (Single vs Multi-Track Playback):**
  - If notes only exist on one channel (e.g. Lead Piano), master playback must render a clean solo melody.
  - When notes exist across multiple channels, all unmuted channels must sum in real-time through the Master Drive Bus.
- **REQ-SKP2-TRACK-04 (Master Drive Bus Processing):**
  - The master bus must apply global BPM, swing shuffle ($0 \dots 50\%$), master drive tube saturation (`tanh`), and a soft-knee peak limiter to prevent digital clipping.

---

### 1.3 Hybrid Sound Pack Architecture (`Track C`)
- **REQ-SKP2-PACK-01 (Native Core Kit Zero-Download Guarantee):**
  - All 18 core instruments and 6 genre drum kits must be pre-baked in native Dart DSP with $0\text{ MB}$ network download requirement and $< 3.5\text{ MB}$ asset footprint.
- **REQ-SKP2-PACK-02 (In-App Sound Pack Store & Hive Caching):**
  - `StudioSoundPackSheet` must display downloadable expansion packs (Packs 2–6).
  - Tapping download must fetch the pack from the CDN, display real-time progress, cache files in `getApplicationDocumentsDirectory()/sound_packs/`, and persist state in Hive (`AppConstants.soundPacksBoxKey`).
- **REQ-SKP2-PACK-03 (Backend Manifest API):**
  - `GET /v1/melodies/sound-packs` in `apps/vhunambi_api` must return the official JSON manifest of available packs.

---

### 1.4 Curvy Minimalist UI/UX (`Track D` — `STD-UIUX-001`)
- **REQ-SKP2-UI-01 (Elimination of Stacked Chip Rails & Emojis):**
  - All 4 stacked horizontal chip rails and raw Unicode emojis (`🥁`, `🎹`, `🪵`, `🎸`) must be replaced with Phosphor vector icons and compact dropdown pills.
- **REQ-SKP2-UI-02 (Compact Curvy Top Bar - 48dp):**
  - Must include:
    - Active Instrument/Kit Pill Dropdown (`Key('sketchpad_instrument_dropdown_btn')`)
    - Key & Scale Pill Dropdown (`Key('sketchpad_key_scale_dropdown_btn')`)
    - Sound Pack Store button (`Key('sketchpad_open_sound_packs_btn')`, `PhosphorIconsRegular.package`)
    - Full-Screen Expand Toggle (`Key('sketchpad_fullscreen_toggle_btn')`, `PhosphorIconsRegular.cornersOut`)
    - Close Button (`Key('sketchpad_close_btn')`, `PhosphorIconsRegular.x`)
- **REQ-SKP2-UI-03 (Sliding Curvy Channel Rack Tabs - 44dp):**
  - Horizontal segmented pill bar with 5 tabs: `lead`, `chords`, `bass`, `drums`, `hats`.
  - Active channels displaying an active glowing indicator dot (`●`) and mute badge (`M`).
  - Long-press on any tab opens a curvy channel popover with Volume, Mute, Solo, and Clear Channel.
- **REQ-SKP2-UI-04 (Curvy 16-Step Matrix & Dynamic Row Labels):**
  - Note cells must use rounded pill borders (`BorderRadius.circular(10)`).
  - When editing `drums` or `hats`, rows display drum voice labels (`Sub Kick`, `Punch Kick`, etc.) instead of scale note names.
- **REQ-SKP2-UI-05 (Hold-to-Edit Gesture Note Inspector):**
  - Long-pressing a step cell opens a floating radial/curved inspector (`_StepNoteInspectorSheet`) to edit Velocity, Pitch Glide ($-5\text{st}$), Duration, or Chord Stamp (Single / Triad / 7th).
- **REQ-SKP2-UI-06 (Touch Target Compliance):**
  - All interactive buttons and touch zones must measure $\ge 44 \times 44\text{dp}$.

---

## 2. Non-Functional Requirements

- **NFR-PERF-01 (Synthesis Speed):** Single-note audition hits must synthesize in $< 6\text{ms}$; 16-step 5-channel master loops must synthesize in $< 45\text{ms}$.
- **NFR-SIZE-01 (APK Footprint):** The total Android ARM64 release APK size must remain $\le 45\text{ MB}$.
- **NFR-TEST-01 (Zero Regressions):** Existing Phase 27 tests in `test/features/studio/melody_sketchpad_modal_test.dart` and `melody_sketchpad_provider_and_synth_test.dart` must pass 100%.
- **NFR-OFFLINE-01 (Complete Offline Playability):** The core sketchpad must function with 100% audio capability in airplane mode.

