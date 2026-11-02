# Phase 32: Studio-Grade 44.1 kHz Multi-Track Melody & Drum Engine — Technical Design

**Document Version:** 1.0.0  
**Status:** Specification Draft for Verification with Argon  

---

## 1. Digital Signal Processing (DSP) Mathematical Formulations

### 1.1 Sample-by-Sample Continuous Phase Accumulator
To eliminate the phase-discontinuity glitch bug where pitch swept audio produces laser clicks and frequency foldover:

$$\phi[n] = \left(\phi[n - 1] + \frac{2\pi \cdot f_{\text{inst}}[n]}{f_s}\right) \pmod{2\pi}$$

Where:
- $f_s = 44,100\text{ Hz}$
- $f_{\text{inst}}[n]$ is the instantaneous frequency at sample $n$.

### 1.2 Karplus-Strong Physical Plucked-String Waveguide (Guitars & Violin)
For Nylon Acoustic Guitar, Clean Electric Guitar, and Solo Violin:

$$y[n] = x[n] + \rho \cdot \frac{y[n - N] + y[n - N - 1]}{2}$$

Where:
- Delay buffer length $N = \left\lfloor \frac{f_s}{f_0} \right\rfloor$
- $\rho \approx 0.992$ is the string tension decay coefficient
- $x[n]$ is a burst of band-limited noise representing the plectrum/bow attack ($0 \le n < N$).
- Body resonance is added via a dual-biquad bandpass filter tuned to $110\text{ Hz}$ and $220\text{ Hz}$.

### 1.3 Breath-Bore Acoustic Waveguide (Flute & Saxophone)
For Bamboo Flute and Soprano Saxophone:

$$f_{\text{inst}}[n] = f_0 \cdot \left(1.0 + A_{\text{vib}} \sin(2\pi \cdot 5.0 \cdot t_n)\right)$$

Where:
- $A_{\text{vib}} = 0.008$ ($5\text{ Hz}$ vibrato with $\pm 0.8\%$ pitch drift)
- Attack envelope: Soft exponential onset $\tau_{\text{attack}} = 0.040\text{s}$
- Embouchure air chiff: Bandpassed noise $B_{\text{chiff}}(t)$ centered at $2.8\text{ kHz}$ ($Q = 3.2$).
- Bore harmonics: Non-linear tanh reed excitation summed across odd/even harmonics.

### 1.4 8-Row Studio Drum Rack Formulations
When editing `drums` or `hats`, each row triggers a dedicated DSP algorithm:

1. **Row 0: Sub 808 / Log Kick**:
   $$f(t) = 42\text{ Hz} + 85\text{ Hz} \cdot e^{-t / 0.040}, \quad A(t) = e^{-t / 0.450}$$
2. **Row 1: Punch Kick**:
   $$f(t) = 48\text{ Hz} + 112\text{ Hz} \cdot e^{-t / 0.016}, \quad A(t) = e^{-t / 0.160}$$
   Plus a high-frequency beater click ($2.5\text{ kHz}$ burst, $4\text{ms}$).
3. **Row 2: Dual-Membrane Snare**:
   $$S(t) = \left(0.6 \sin(2\pi \cdot 185 \cdot t) + 0.4 \sin(2\pi \cdot 330 \cdot t)\right) e^{-t / 0.08} + N_{\text{wires}}(t) \cdot e^{-t / 0.18}$$
4. **Row 3: Woody Rimshot**:
   $$R(t) = \left(\sin(2\pi \cdot 480 \cdot t) + 0.7 \sin(2\pi \cdot 1150 \cdot t)\right) e^{-t / 0.025}$$
5. **Row 4: Club Handclap**:
   Four micro-bursts of shaped noise at $t_0 = 0, 11\text{ms}, 22\text{ms}, 33\text{ms}$ with high-pass cutoff at $1.5\text{ kHz}$.
6. **Row 5: Closed Hi-Hat**:
   Square-wave ring matrix modulated by 6 inharmonic oscillators ($f = [245, 306, 384, 522, 705, 869]\text{ Hz}$), high-passed at $7.5\text{ kHz}$, decay $\tau = 25\text{ms}$.
7. **Row 6: Open Shimmer Cymbal/Hat**:
   Same ring matrix, decay $\tau = 220\text{ms}$.
8. **Row 7: African Mbaḓi Shaker / Conga**:
   Exponentially damped band-passed noise pulse ($\tau = 35\text{ms}$, center frequency $5.8\text{ kHz}$).

### 1.5 Master Drive Summing Bus with Soft-Knee Limiter
All 5 channels are summed into a stereo buffer ($L[n], R[n]$):

$$M[n] = \sum_{c=1}^{5} (1 - \text{muted}_c) \cdot \text{vol}_c \cdot \text{ChannelSample}_c[n]$$

Tube warmth and soft clipping are applied via fast rational tanh:

$$\text{Out}[n] = \text{tanh}\left(M[n] \cdot (1.0 + 0.5 \cdot \text{drive})\right)$$

---

## 2. Domain Data Models

```dart
enum SketchpadChannelRole {
  lead('Lead Melody', 'lead', 0),
  chords('Chords & Keys', 'chords', 1),
  bass('Bass & Sub', 'bass', 2),
  drums('Beat & Drums', 'drums', 3),
  hats('Hi-Hats & Percs', 'hats', 4);

  const SketchpadChannelRole(this.label, this.wireValue, this.channelIndex);
  final String label;
  final String wireValue;
  final int channelIndex;
}

enum BeatKitGenre {
  amapiano('Amapiano Groove Kit'),
  hipHop('Hip-Hop Trap Kit'),
  gqom('Durban Gqom Kit'),
  afrobeats('Lagos Afrobeats Kit'),
  house('Deep House 4x4 Kit'),
  pop('Studio Pop Kit');

  const BeatKitGenre(this.label);
  final String label;
}

class SketchpadChannelTrack {
  final SketchpadChannelRole role;
  final SketchpadInstrument instrument;
  final BeatKitGenre beatKit;
  final List<MelodyStepNote> steps;
  final double volume; // 0.0 to 1.2
  final double pan;    // -1.0 to 1.0
  final bool isMuted;
  final bool isSolo;

  const SketchpadChannelTrack({
    required this.role,
    required this.instrument,
    this.beatKit = BeatKitGenre.amapiano,
    this.steps = const [],
    this.volume = 1.0,
    this.pan = 0.0,
    this.isMuted = false,
    this.isSolo = false,
  });

  bool get hasNotes => steps.isNotEmpty;
}

class MultiTrackGrooveEntity {
  final String id;
  final String name;
  final int bpm;
  final String musicalKey;
  final AfricanScaleMode scaleMode;
  final Map<SketchpadChannelRole, SketchpadChannelTrack> channels;
  final double masterDriveAmount;
  final double swingPercent;

  const MultiTrackGrooveEntity({
    required this.id,
    required this.name,
    required this.bpm,
    required this.musicalKey,
    required this.scaleMode,
    required this.channels,
    this.masterDriveAmount = 0.20,
    this.swingPercent = 12.0,
  });

  /// Extracts legacy single-channel pattern for Phase 27 backward compatibility.
  MelodyPatternEntity toLegacyPattern(SketchpadChannelRole role) {
    final channel = channels[role] ?? channels[SketchpadChannelRole.lead]!;
    return MelodyPatternEntity(
      id: id,
      name: name,
      bpm: bpm,
      musicalKey: musicalKey,
      scaleMode: scaleMode,
      instrument: channel.instrument,
      notes: channel.steps,
    );
  }
}
```

---

## 3. Hybrid Sound Pack Manager Model

```dart
class StudioSoundPackEntity {
  final String id;
  final String title;
  final String subtitle;
  final String genre;
  final double sizeMb;
  final bool isBundledNative;
  final bool isInstalled;
  final List<String> instrumentNames;
  final String downloadUrl;

  const StudioSoundPackEntity({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.genre,
    required this.sizeMb,
    this.isBundledNative = false,
    this.isInstalled = false,
    required this.instrumentNames,
    required this.downloadUrl,
  });
}
```

---

## 4. UI/UX Hierarchy & Token System (`STD-UIUX-001`)

```
MelodySketchpadModal
│
├── _CurvyTopBar (48dp)
│   ├── InstrumentDropdownPill: [ 🎹 Grand Piano ▾ ] -> _InstrumentPickerSheet
│   ├── KeyScaleDropdownPill:   [ Am • Pentatonic ▾ ] -> _KeyScalePickerSheet
│   ├── SoundPacksButton:       PhosphorIcon(package) -> StudioSoundPackSheet
│   ├── FullscreenToggleButton: PhosphorIcon(cornersOut)
│   └── CloseButton:            PhosphorIcon(x)
│
├── _SlidingChannelRack (44dp)
│   └── ListView(horizontal):
│       ├── Tab: [ ● Lead ]
│       ├── Tab: [ ● Chords ]
│       ├── Tab: [ ● Log Drum ]
│       ├── Tab: [ ● Beat ]
│       └── Tab: [ ● Hats ]
│       (Long-press: _ChannelMixerPopover - Volume, Mute, Solo, Clear)
│
├── _CurvyStepMatrix (Main Canvas)
│   ├── 8 Pitch / Drum Voice Label Column (Row 0..7)
│   └── 16 Rounded Pill Step Cells (BorderRadius.circular(10))
│       ├── Single Tap: Toggle Note + 44.1 kHz Audition
│       └── Long-Press: _StepNoteInspectorSheet (Velocity, Glide, Chords)
│
└── _MinimalMasterTransportDock (52dp)
    ├── MasterPlayButton: PhosphorIcon(play/pause)
    ├── BpmPillDropdown: [ 113 BPM ▾ ]
    ├── AutoBeatButton: PhosphorIcon(sparkle) "Auto-Beat"
    ├── SaveButton: PhosphorIcon(floppyDisk)
    └── AttachGrooveButton: "Attach to Studio"
```

