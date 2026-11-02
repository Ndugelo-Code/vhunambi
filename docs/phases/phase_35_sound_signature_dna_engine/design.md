# Phase 35: Sound Signature ID & Vocal Idealizer - Design

**Document Version:** 1.0.0
**Status:** Specification Draft for sign-off
**Conventions:** $m$ = MIDI pitch (float semitones, $m = 69 + 12\log_2(f/440)$); $F_s$ = sample rate; frame hop $H$; "st" = semitones. All numeric defaults are starting points to be tuned in Track B/C against the acceptance tests in §10.

---

## 1. Module Layout (client)

```
lib/features/sound_signature/
  domain/
    models/        sound_signature_dna.dart, timbre_identity_profile.dart, pitch_contour_profile.dart,
                   phonetic_articulation_profile.dart, rhythmic_transient_grid.dart,
                   recording_quality_profile.dart, sound_idealizer_recipe.dart
    codec/         sig_codec.dart            (Uint8List <-> SoundSignatureDna, versioned)
    services/      i_audio_intake_recorder.dart, real_audio_intake_recorder.dart,
                   audio_import_service.dart, input_quality_gate.dart
    dsp/           resampler.dart, fft.dart, yin_pitch_tracker.dart, lpc_formants.dart,
                   hnr.dart, cepstral_descriptor.dart, onset_detector.dart, key_scale_estimator.dart,
                   note_segmenter.dart, pitch_trajectory_editor.dart, psola.dart,
                   vibrato.dart, formant_shifter.dart, tone_chain.dart (biquads, compressor, exciter),
                   pocket_quantizer.dart, loudness.dart, denoiser.dart
    analyzers/     sound_analyzer.dart       (orchestrates dsp/*, runs in isolate)
    idealizer/     vocal_idealizer.dart, sound_signature_resynthesizer.dart
    bridge/        hum_to_sketchpad.dart, signature_sampler.dart
  data/            sound_signature_repository.dart (Hive), signature_audio_store.dart (files)
  presentation/
    providers/     sound_signature_provider.dart, idealizer_session_provider.dart
    widgets/       sound_signature_idealizer_sheet.dart, vhu_sig_badge.dart, pitch_formant_painter.dart,
                   ab_toggle_bar.dart, idealizer_controls.dart, input_quality_card.dart,
                   consent_upload_sheet.dart
```

Existing files touched: `i_voice_calibration_recorder.dart`, `voice_clone_recorder_sheet.dart`, `reference_audio_dropzone.dart`, `vocal_identity_models.dart` / `vocal_identity_provider.dart`, `melody_sketchpad_models.dart` (+ enum value, channel `customSignatureId`), `melody_wav_synthesizer.dart` (+ custom renderer), `owner_profile_view.dart`, `app_constants.dart`, `pubspec.yaml`, `AndroidManifest.xml`, `main.dart` (box open).

---

## 2. Domain Model

### 2.1 Entities (Dart)

```dart
enum SignatureSource { live, imported }

class SoundSignatureDna {
  final String id;                 // ULID (key)
  final String displayCode;        // 'VHU-SIG-9A4F' (label)
  final SignatureSource source;
  final String createdAtIso;
  final double durationSec;
  final int sampleRate;            // 44100
  final double bpmHint;
  final TimbreIdentityProfile identity;
  final PitchContourProfile pitch;
  final PhoneticArticulationProfile articulation;
  final RhythmicTransientGrid rhythm;
  final RecordingQualityProfile quality;
  final SoundIdealizerRecipe recipe;
  final String? rawAudioPath;      // relative, app docs dir
  final String? cloudEmbeddingRef; // set after cloud analyze
  final String? consentAtIso;      // set when uploaded
  final int schemaVersion;         // 1
}

class TimbreIdentityProfile {
  final List<double> cepstralDescriptor;   // 16
  final List<double> formantsHz;           // [F1..F4], 0 = unknown
  final double glottalWarmth;              // 0..1 (H1-H2 proxy)
  final double harmonicPurityRatio;        // 0..1 (HNR/30)
}

class PitchContourProfile {
  final List<int> f0CentsMidi;             // 50 Hz frames, midi*100, -32768 = unvoiced
  final int rootPitchClass;                // 0..11
  final AfricanScaleMode scaleMode;
  final double keyConfidence;              // 0..1
  final double stabilityScore;             // 0..1
  final double naturalVibratoHz;           // 0 if none
  final double naturalVibratoDepthCents;
}

class PhoneticArticulationProfile {
  final double consonantTransientSharpness; // 0..1
  final List<TimeSpanMs> protectedSegments; // unvoiced/transient spans never pitch-processed
}

class RhythmicTransientGrid {
  final List<int> onsetMs;
  final List<int> offsetFromGridMs;         // signed
  final List<MelodyStepNote> quantizedNotes;// W3 output (<= 16 steps)
}

class RecordingQualityProfile {
  final double snrDb, clippingPct, bandwidthHz, loudnessLufs, reverbEdtMs, voicedRatio;
}

class SoundIdealizerRecipe {
  final double pitchScaleLock;             // 0..1  (0.90)
  final double vibratoAndSustainPolish;    // 0..1  (0.75)
  final double formantDepthShiftSemitones; // -3..3 (0.0)
  final double chestPowerAndAirBoost;      // 0..1  (0.80)
  final double quantizePocketStrength;     // 0..1  (0.85)
  final String? hybridArchetypeId;
  final double hybridBlendMix;             // 0..0.75 (0.25)
  final double referenceCleanup;           // 0..1  (0.70)
}
```

`TimeSpanMs` = `(int startMs, int endMs)`. All models: `const` constructors, `copyWith`, `==/hashCode`. They contain **no theme tokens**, so `const` is fine here (the `AppColors`-no-const rule applies to widgets only).

### 2.2 Display code
`XXXX = hex(sha256(codecBytes ‖ createdAtIso))[0..3]` uppercased; on local collision, append a counter to the hash input until unique. Pure label; never used as a key or proof of identity.

### 2.3 `SigCodec` v1 (little-endian)

| Offset | Field | Type |
| :--- | :--- | :--- |
| 0 | version | u8 (=1) |
| 1 | flags | u8 (bit0 imported, bit1 hasCloudEmbedding) |
| 2 | durationMs | u32 |
| 6 | bpmHint x100 | u16 |
| 8 | root pc / scale index / keyConf x255 / stab x255 | u8 x4 |
| 12 | vibratoHz x100 / depthCents x10 | u16, u16 |
| 16 | formants F1-F4 | f32 x4 |
| 32 | descriptor c1-c16 | f32 x16 |
| 96 | warmth x255, purity x255, sharpness x255 | u8 x3 |
| 99 | quality: snr, clip, bw, lufs, edt, voiced | f32 x6 |
| 123 | recipe: 6 f32 + hybridMix f32 + cleanup f32 + hybridId (len-prefixed UTF-8) | var |
| ... | f0 frame count u16 + `i16[]` | var |
| ... | onsets count u16 + (`u32` ms, `i8` offset) | var |
| ... | notes count u8 + (step u8, row u8, vel u8, glide u8, dur u8) | var |

### 2.4 Size budget (<= 20 s take)
F0: 1,000 frames x 2 B = 2,000 B - descriptor/formants/scalars ~ 260 B - onsets <= 120 x 5 = 600 B - notes <= 64 x 5 = 320 B - recipe ~ 60 B - optional cloud embedding as `f16[256]` = 512 B. **Total ~ 3.8 KB (< 8 KB).** For takes > 30 s, F0 decimates 50 -> 25 Hz to stay <= 8 KB. (The original brief's 8 KB figure holds for the **binary** codec; naive JSON of the same data would be ~4x larger, hence the codec.)

### 2.5 Persistence
- Box `vhunambi_sound_signatures_box` (`Box<Uint8List>` keyed by ULID) + index entry in a small `Box<dynamic>` list for ordering/metadata (code, source, createdAt, rawAudioPath).
- Raw audio: `<docs>/signatures/<ulid>/raw.wav` (mono PCM16 44.1 kHz, ~1.76 MB / 20 s). Quota default 50 MB across signatures, surfaced in the vault storage modal; oldest-unpinned eviction is **not** automatic (user chooses).

---

## 3. Intake

### 3.1 `IAudioIntakeRecorder`
Extends the existing contract (amplitude stream, `isRecording`, start/stop) with `Future<RawTake> stopRecording()` returning `Float32List pcm` (+ `Uint8List wav`). `RealAudioIntakeRecorder` wraps `record`'s PCM16 stream (44.1 kHz mono, `echoCancel: false`, `noiseSuppress: false`, `autoGain: false` - we need the unprocessed signal). `VoiceCalibrationRecordingResult` gains `SoundSignatureDna? signature`; the deterministic fake continues to return a fixed fixture signature so existing tests keep passing.

### 3.2 Count-in & grid (W3)
Hum capture plays a 1-bar metronome count-in (synthesised clicks through the existing player) and records exactly 1 bar (16 steps). $t_0$ = end of count-in, so absolute step indices are meaningful.

### 3.3 Input Quality Gate
- **SNR:** frame RMS in dB; noise floor = 10th percentile; signal = 90th; $\mathrm{SNR} = L_{90}-L_{10}$.
- **Clipping:** % samples with $|x| \ge 0.995$.
- **Bandwidth:** frequency where the long-term average spectrum drops 20 dB below its 200-3000 Hz mean.
- **Voiced ratio:** from the F0 tracker.
- **Reverb (EDT):** median decay time of energy after offsets from -5 to -25 dB, extrapolated to -60 dB (coarse; reported as bands low/med/high).
- **Verdict:** green / amber / red with remedy text; red only for voiced < 3 s or clipping > 5%.

---

## 4. Analysis DSP (Track B)

### 4.1 Resampling
Analysis copy at 16 kHz: polyphase windowed-sinc (Kaiser $\beta$=8.6), ratio 160/441, linear phase. Original 44.1 kHz kept for rendering.

### 4.2 F0 - YIN
Frame $W=512$, window span 1024 samples, hop $H=160$ (10 ms), lag range $\tau\in[18,270]$ ($\approx 60$-$890$ Hz).

$$d(\tau)=\sum_{j=1}^{W}\bigl(x_j-x_{j+\tau}\bigr)^2,\qquad
d'(\tau)=\begin{cases}1 & \tau=0\\ \dfrac{d(\tau)}{\frac1\tau\sum_{j=1}^{\tau}d(j)} & \tau>0\end{cases}$$

Candidates: local minima of $d'$ below 0.35 (top 3). Pick via Viterbi over frames with cost
$$C = d'(\tau) + \lambda\,\bigl|\log_2 (f_t/f_{t-1})\bigr|,\quad \lambda=0.5$$
to suppress octave jumps. Parabolic interpolation of the chosen minimum gives sub-sample $\tau^\*$, $f_0=F_s/\tau^\*$. Voiced iff $d'(\tau^\*)<0.20$ and frame RMS > noise-floor + 6 dB. Output smoothed by a 5-tap median, then stored at 50 Hz in cents.

**Cost:** $2000$ frames $\times$ $512\times 252$ MACs $\approx 2.6\times10^8$ - roughly 1 s in Dart AOT on typed lists (estimate, validated in spike T-B0). FFT autocorrelation is the fallback optimisation.

### 4.3 Note segmentation
Over voiced runs: maintain a running median $\tilde m$; start a new note when $|m-\tilde m|>0.5$ st for $\ge 40$ ms; drop notes $<60$ ms; merge gaps $<30$ ms between same-pitch notes. Per note store onset, offset, median $\tilde m_n$, stability = $1/(1+\sigma_m)$.

### 4.4 Key & scale
Histogram $h[pc]=\sum_n \mathrm{dur}_n\cdot\mathrm{stab}_n$ over $pc=\mathrm{round}(\tilde m_n)\bmod12$. For root $r\in 0..11$ and mode $M$ with pitch-class set $S_M$ (from `semitoneOffsets mod 12`):
$$\mathrm{score}(r,M)=\sum_{p\in S_M}h[(r+p)\bmod 12]-0.5\!\!\sum_{p\notin S_M}\!h[(r+p)\bmod 12]$$
Pick argmax; confidence $=(s_1-s_2)/s_1$. Minor-pentatonic is a subset of natural-minor, so ties are expected - confidence < 0.2 triggers the "Check key" UI. Project/song key always wins when present.

### 4.5 Formants (LPC)
Voiced, high-HNR, above-median-energy frames only (vowel-like). Per frame: pre-emphasis 0.97, Hamming 25 ms, autocorrelation, Levinson-Durbin order 18 (at 16 kHz), polynomial roots (Durand-Kerner), keep conjugate poles with $\theta\in(90\,\mathrm{Hz},\,F_s/2-200)$ and bandwidth $-\frac{F_s}{\pi}\ln|z| < 400$ Hz, sort by frequency; assign $F_1..F_4$ by standard ranges (200-1000, 600-2800, 1500-3500, 2500-4500 Hz). Median across frames. Confidence drops if < 15 usable frames -> formants stored as 0 and UI hides formant markers.

### 4.6 Descriptor, HNR, warmth
- **Descriptor:** per voiced frame: 512-pt FFT -> 24 mel bands (200-7500 Hz) -> log -> DCT-II -> $c_1..c_{16}$; mean over voiced frames.
- **HNR:** $r(T_0)$ = normalised autocorrelation at the YIN lag; $\mathrm{HNR}=10\log_{10}\frac{r}{1-r}$ (clamped for $r\in[0.01,0.99]$).
- **Warmth proxy:** $H_1-H_2$ from the FFT at $f_0$ and $2f_0$ (parabolic peak pick), $\text{warmth}=\mathrm{clamp}\bigl((H_1-H_2+5)/20,0,1\bigr)$. Documented as heuristic.

### 4.7 Onsets
Log-magnitude STFT (hop 10 ms), half-wave-rectified spectral flux, adaptive threshold = local median (200 ms) + $\delta$, peak-pick with 50 ms refractory. Offsets vs. grid: $o_i=t_i - \mathrm{round}(t_i/\Delta)\Delta$, $\Delta=\frac{60}{\mathrm{BPM}}\cdot\frac14$.

---

## 5. Vocal Idealizer (Track C)

Order of operations (each stage is skippable, all driven by the recipe, always from the **raw** take):

```
raw PCM(44.1k) -> [1 denoise] -> [2 pocket quantize] -> [3 pitch/vibrato/formant via PSOLA]
               -> [4 tone chain: box cut, compress, shelf, F1 lift, air] -> [5 limiter] -> [6 loudness match]
```

### 5.1 Pitch trajectory editing
Work in semitones $m(t)$ at 100 Hz frame rate, per note $n$ with median $\tilde m_n$:

1. **Decompose** (zero-phase 2nd-order Butterworth, forward-backward):
   $m = m_{\text{trend}} + m_{\text{vib}} + m_{\text{trem}}$, with $m_{\text{trend}}$ = LP @ 2.5 Hz, $m_{\text{vib}}$ = BP 4-8 Hz of the residual, $m_{\text{trem}}$ = remainder (> 8 Hz).
2. **Target:** allowed pitches $\mathcal P=\{r_0+o+12k\}$ (root $r_0$, offsets $o$ of the chosen `AfricanScaleMode`). $m^\star_n=\arg\min_{p\in\mathcal P}|p-\tilde m_n|$, $\Delta_n=\mathrm{clamp}(m^\star_n-\tilde m_n,\,\pm7)$ (REQ-IDEAL-03: if the unclamped value exceeds 7 st the note is **left unchanged** and reported).
3. **Glide detection:** a segment with $|dm/dt|>10$ st/s, monotone, $\ge 80$ ms, sets $g(t)=1$ (no snap; constant offset only).
4. **Ideal trajectory**, with $\lambda_p$ = Scale Lock, $\nu$ = Vibrato Polish, $\kappa=0.7$:
$$m_{\text{ideal}}(t)=m_{\text{trend}}(t)+\lambda_p\bigl[\Delta_n-\kappa\,(m_{\text{trend}}(t)-\tilde m_n)\bigr](1-g(t))+(1-\nu)\,m_{\text{vib}}(t)+\nu\,V_s(t)+(1-\nu)\,m_{\text{trem}}(t)\cdot 0.1$$
   The $\Delta_n$ step is passed through a one-pole smoother with $\tau=5+195(1-\lambda_p)$ ms, so $\lambda_p=1$ is fast (tight/robotic) and low values glide naturally.
5. **Synthetic vibrato** $V_s(t)=A(t)\sin\varphi(t)$, with the Phase-32 phase accumulator discipline:
$$\varphi[k]=\bigl(\varphi[k-1]+2\pi\cdot 5.2/F_{100}\bigr)\bmod 2\pi,\quad F_{100}=100$$
   $A(t)$ ramps $0\to A_{\max}$ over 150 ms after note onset, with $A_{\max}=0.35\cdot\min(1,\ell_n/600\text{ ms})$ st (i.e. up to 35 cents on notes $\ge600$ ms, scaled down for shorter ones), applied only to notes $\ge300$ ms.
6. **Ratio:** $\rho(t)=2^{(m_{\text{ideal}}-m)/12}$, hard-clamped to $[2^{-7/12},2^{7/12}]$.

### 5.2 TD-PSOLA with formant control
- **Analysis marks** $p_i$: start at the first voiced sample's local waveform peak, advance by local $T_a=1/f_0$, snapping each mark to the max $|x|$ within $\pm T_a/4$.
- **Synthesis marks** $q_k$: $q_0=p_0$, $q_{k+1}=q_k+T_s(q_k)$, $T_s=T_a/\rho$. Each $q_k$ selects the analysis mark nearest in (time-scaled) position.
- **Grain:** $g_i[n]=x[p_i+n]\,w[n]$, $n\in[-T_a,T_a]$, Hann $w$.
- **Formant shift** $s=2^{\Delta_f/12}$: resample each grain by factor $1/s$ (spectral envelope scales by $s$) **before** overlap-add, while $q_k$ spacing stays $T_s$ - pitch and formants are therefore independent.
- **OLA** with a parallel window-sum buffer; output divided by the accumulated window weight (keeps level constant when $\rho\neq1$).
- **Unvoiced / protected segments** are copied through unchanged with 5 ms crossfades at voiced boundaries. **This is how Bantu consonants and Nguni clicks stay sharp by construction** - they are never pitch-processed.
- **Sustain extension** (REQ-IDEAL-06): re-use two alternating mid-note grains for up to +120 ms of extra synthesis marks, then crossfade into the natural release.
- **Known limits:** PSOLA is clean to about $\pm4$-$5$ st, usable to $\pm7$; very breathy/noisy voiced frames reduce epoch accuracy (they fall back to bypass when epoch confidence is low).

### 5.3 Pocket quantize
Onsets $t_i$ with offsets $o_i$. Shift each syllable/segment by $-q\,o_i$ ($q$ = strength), clamped $\pm90$ ms, with 8 ms crossfades. The resulting gap/overlap is absorbed by silence trim/pad; if no silence is available, WSOLA time-stretch of the adjacent sustained span by at most $\pm15\%$.

### 5.4 Tone chain ("Chest Power & Air", $c$ = control)
1. **Denoise** (Reference Cleanup $\gamma$): Wiener gain $G=\max\bigl(\frac{\xi}{1+\xi},\,0.1\bigr)$, $\xi$ via decision-directed estimate ($\alpha=0.98$), noise PSD from the quietest 10% frames.
2. **Box cut:** peaking biquad (RBJ), $f=380$ Hz, $Q=1.0$, gain $=-3\,c\cdot\text{boxiness}$ dB where boxiness comes from the quality profile.
3. **Compressor:** threshold -24 dBFS, ratio 3:1, knee 6 dB, attack 8 ms, release 90 ms, log-domain detector; makeup chosen by loudness match (§5.6).
4. **Chest weight:** low shelf @ 140 Hz, $+3.5c$ dB.
5. **$F_1$ lift:** peaking at the measured $F_1$ (fallback 600 Hz), $Q=1.2$, $+3c$ dB.
6. **Air:** high shelf @ 11.5 kHz $+2.5c$ dB **plus** harmonic exciter $y=x+\mu\,\mathrm{HP}_{5k}\!\bigl(\tanh(d\,\mathrm{HP}_{5k}(x))\bigr)$ gated by voiced & HNR>0.5. If measured `bandwidthHz` < 11 kHz the UI shows "Bandwidth-limited source - air is synthesised" and the shelf is reduced to avoid boosting noise.
7. **Limiter:** look-ahead 2 ms, ceiling -1 dBTP (4x oversampled peak check).

### 5.5 Hybrid preview (approximate, on device)
Applies $\mu\cdot\texttt{archetype.formantShiftSemitones}$ (catalog already carries $\pm4$) on top of the user's formant control, clamped to $\pm3$ st total. Until each of the 24 archetypes has a 16-coef descriptor (computed offline in Track F from reference renders), no spectral-tilt term is applied. Always labelled "Approximate preview".

### 5.6 Loudness match
Approximate BS.1770 integrated loudness (K-weight two-biquad, 400 ms blocks, absolute gate -70 LUFS). Raw and Perfected buffers are gain-matched to within 0.5 LU before A/B.

### 5.7 A/B renderer & session
`IdealizerSession` holds `{raw, perfected, recipe, playhead}`. Slider change -> debounce 250 ms -> isolate re-renders the **affected stages/span** (stage cache keyed by recipe sub-hash) -> swaps `perfected`. Toggle swaps source at the same sample index with a 10 ms equal-power crossfade. Playback via the existing `just_audio` WAV-bytes path used by the Sketchpad.

---

## 6. Track E - Sketchpad Bridge

### 6.1 Hum -> notes
Given selected `AfricanScaleMode` (offsets $o_0..o_7$ ascending) and root $r_0$:
1. Segment notes (§4.3).
2. **Octave folding:** for $s\in\{-24,-12,0,+12,+24\}$ compute $\mathrm{cost}(s)=\sum_n\min_{r}\bigl|\tilde m_n+s-(r_0+o_r)\bigr|$; choose min.
3. Row $=\arg\min_r|\tilde m_n+s-(r_0+o_r)|$; notes further than 1.5 st from any row are snapped and flagged `outOfScale` (shown in UI).
4. $\text{step}=\mathrm{round}\bigl((t_n-t_0)/\Delta\bigr)\bmod16$; $\text{dur}=\mathrm{clamp}(\mathrm{round}(\ell_n/\Delta),1,4)$; velocity $=\mathrm{clamp}(\mathrm{RMS}_n/\mathrm{RMS}_{\text{ref}},0.05,1.0)$; `hasGlide` if end $\le$ start $-3.5$ st.
5. Collisions (two notes, same step & row) keep the louder.
Output is a `List<MelodyStepNote>` merged into the chosen channel through the existing Sketchpad notifier API with undo.

### 6.2 Percussion
Onsets classified by spectral centroid of the first 40 ms: $<400$ Hz -> row 0 (kick), 400-2500 -> row 2 (snare), $>2500$ -> hat row (follows Phase 32's 8-row rack mapping).

### 6.3 Custom signature instrument (`SignatureSampler`)
1. **Pick region:** sliding 300 ms window maximising $\text{HNR}\cdot\text{stability}$ within the 0.2-0.8 s band; fall back to percussive mode if none.
2. **Row buffers:** for each row $r$ target pitch $\mathrm{mtof}(r_0+o_r)$; PSOLA the region by $\rho_r=f_r/f_{\text{region}}$ (clamped; rows beyond $\pm7$ st re-pitch via varispeed with a flagged formant side effect). Cache 8 buffers per (signature, scale, root).
3. **Playback:** ADSR (A 5 ms, R 80 ms), `hasGlide` as a playback-rate ramp -5 st; mixed through `MelodyWavSynthesizer` custom branch so preview and render are identical.
4. **Percussive mode:** rows = varispeed variants ($2^{(r-3.5)/12}$), only for drums/hats.

---

## 7. UI/UX (Track D, `STD-UIUX-001`)

### 7.1 `SoundSignatureIdealizerSheet`
```
+------------------------------------------------+
| (waveform-glyph) Perfect Your Voice      [x]   |
| VHU-SIG-9A4F   [live]   Quality: ● Good        |
| +--------------------------------------------+ |
| | pitch painter: raw (muted) vs ideal (primary)| |
| | scale-degree gridlines, F1-F3 markers       | |
| +--------------------------------------------+ |
|  [ Raw ]  <==  A / B  ==>  [ Perfected ]       |
|  Key: A minor pentatonic  (conf 0.62) [Change] |
|  Pitch Lock ──●──── 90%     Vibrato ──●── 75%  |
|  Formant ───●───── 0 st     Chest/Air ─●─ 80%  |
|  Pocket ───●─────── 85%     Cleanup ──●── 70%  |
|  Hybrid voice: [ None ▾ ]  Mix ──●── 25% (≈)   |
|  [Save] [Apply to Song] [To Sketchpad] [Export]|
+------------------------------------------------+
```
- Icons: Phosphor only (`waveform`, `microphone`, `sliders`, `play`, `pause`, `export`, `trash`, `piano-keys`, `check-circle`, `warning`). 44x44dp targets. No raw hex/emoji.
- Colours via `AppColors` getters; **no `const` widgets over tokens**; `pitch_formant_painter` reads `AppColors` inside `paint()`; `shouldRepaint` includes brightness. Verified under `KeyedSubtree(ValueKey<Brightness>)` remount.
- Keys: `sound_signature_idealizer_sheet`, `sig_ab_toggle`, `sig_slider_pitch_lock`, `sig_slider_vibrato`, `sig_slider_formant`, `sig_slider_chest_air`, `sig_slider_pocket`, `sig_slider_cleanup`, `sig_hybrid_picker`, `sig_action_save|apply|sketchpad|export|delete`.
- States: analysing (progress), permission denied, quality red, formants unavailable, refused-notes list, cloud consent.

### 7.2 Integrations
`VoiceCloneRecorderSheet`: after stop -> "Analysing your voice" -> quality card -> "Perfect my voice" opens the sheet. `ReferenceAudioDropzone`: real picker -> waveform -> analyse -> same sheet (identity actions hidden when `imported`). `OwnerProfileView.voicesAndMelodies`: signature tiles. `vault_storage_modal`: signature audio row + delete.

---

## 8. Track F - Cloud, API, GPU

### 8.1 Corrected pipeline (fixes audit F03-F05)
```
handler.py: ACE-Step -> Demucs(4 stems)
   if svc_config: vocals' = seed_vc.convert(vocals, ref=enhanced reference, recipe)   # REAL, must read/write audio
   stems' = stem_mastering.master(stems with vocals')                                   # Phase 25 wired
   -> mix/upload; result.stages = [{name, executed, ms, in_sha256, out_sha256}]
```
`convert_vocal_stem_with_seed_vc` raises if model/weights are absent - **no more `"status":"converted"` without work**. Hash fallback in `extract_speaker_timbre_embedding` is removed from production.

### 8.2 Endpoints (Zod)
| Method | Path | Purpose |
| :--- | :--- | :--- |
| POST | `/v1/voices/signatures` | register `{ id, displayCode, source, durationSec, recipe, descriptor16, formants4, consentAtIso }` -> `{ uploadUrl, r2Key }` (only if consent present) |
| POST | `/v1/voices/signatures/:id/analyze` | verify object exists in R2, enqueue GPU embed+enhance -> `{ jobId }` |
| PATCH | `/v1/voices/signatures/:id/recipe` | update recipe |
| GET | `/v1/voices/signatures/:id` | metadata + `cloudEmbeddingRef`, enhance report (SNR before/after) |
| DELETE | `/v1/voices/signatures/:id` | purge R2 object + embedding + record |

Persistence replaces the in-memory `Map` (concrete store chosen in task T-F1 from the backend's existing options; R2 JSON sidecar if none). `source: imported` + identity-clone intent -> 403 `IMPORTED_AUDIO_CANNOT_BE_IDENTITY`.

### 8.3 `svc_config` extension
```json
{ "mode": "zero_shot_clone", "clonedProfileId": "...", "signatureId": "...",
  "recipe": { "formantShiftSemitones": 0.0, "hybridArchetypeId": "soweto_golden",
              "hybridMix": 0.25, "cleanup": 0.7, "pitchScaleLock": 0.9 },
  "f0PitchLock": true, "preserveBantuClicks": true }
```

### 8.4 Spikes (gate Track F-neural)
| Spike | Question | If it fails (fallback) |
| :--- | :--- | :--- |
| **S1** | Can Seed-VC (singing/F0-conditioned model, 44.1 kHz) accept a **pre-corrected source** and keep pitch? Check VRAM, per-job seconds, **license compatibility**. | Run conversion on the uncorrected generated vocal; apply on-device Scale Lock only to W2 takes. |
| **S2** | Can speaker-style vectors be interpolated for a hybrid (e.g. spherical interpolation $z=\mathrm{slerp}(z_u,z_a,\mu)$) with a usable result? | Cap hybrid at formant/EQ transfer toward the archetype's descriptor on the cloud output (labelled as such); no neural blend claim. |
| **S3** | Speaker encoder choice/dimension (192 vs 256) and reference-enhance model (e.g. resemble-enhance) license/quality. | Use the encoder bundled with the chosen SVC model; skip dereverb, keep denoise. |

All three are *candidates to be verified* - none are assumed to work or to be licence-compatible.

---

## 9. Security & Privacy (Track F)
- Consent sheet lists: what is sent (raw take + descriptor), why, retention, deletion path. `consentAtIso` stored; server refuses presign without it.
- Presigned PUT, short TTL, content-type/size caps (<= 15 MB), server-side re-check.
- `DELETE` is idempotent, returns what was removed; client mirrors by deleting local files.
- Logs never contain audio, embeddings or raw tokens; GPU worker deletes temp files at job end.
- `PRIVACY_DATA_FLOW.md` §2/§3/§7 updated (new class: voice biometrics).

---

## 10. Verification Plan & Acceptance Numbers

| Test | Method | Pass |
| :--- | :--- | :--- |
| F0 accuracy | synthetic harmonic stacks 80-800 Hz + vibrato | RMSE <= 5 cents (clean); octave errors <= 2% |
| Voicing | synthetic voiced/unvoiced bursts | accuracy >= 95% |
| Formants | impulse train through all-pole filter with known $F_1$-$F_3$ | error <= 5% |
| Key/scale | synthetic melodies in each mode/root | top-1 >= 85% (ties flagged by confidence) |
| Scale Lock | sine phrase detuned $\pm40$ cents | median error <= 10 cents at $\lambda_p=1$ |
| Formant preservation | correct by $\pm4$ st | $F_1$-$F_3$ drift < 5% |
| Formant shift | $\Delta_f=\pm3$ st | measured shift within $\pm6\%$ of target |
| Glide preservation | synthetic -5 st glide | glide slope retained within 15% |
| Unvoiced protection | noise burst + clicks | output identical (bit-exact outside crossfades) |
| Quantize | notes offset $\pm60$ ms | residual <= 10 ms at $q=1$ |
| Onsets | click/tone trains | F1-score >= 0.9 |
| Hum -> notes | synthetic hums on known rows/steps | >= 90% exact row+step |
| Codec | round-trip + golden | exact; size <= 8 KB at 20 s |
| Performance | 20 s analysis / render on Huawei ARM64 | < 3 s / < 4 s |
| UI | widget tests Light+Dark, A/B, permission states | green |
| Cloud | worker tests | stage `executed` asserted; refuses fake success |

**Real-voice validation is manual** (Track G): quiet room, noisy room, headset mic, three speakers, with subjective listening notes recorded in the phase doc - synthetic tests prove the math, not that it sounds good.

## 11. Risks

| Risk | Impact | Mitigation |
| :--- | :--- | :--- |
| PSOLA artifacts on breathy/noisy voices | audible warble | epoch-confidence fallback to bypass; refuse > 7 st; cloud path |
| Direct-form YIN too slow in Dart | breaks 3 s budget | FFT autocorrelation, lower hop for imports |
| Key ambiguity in pentatonic modes | wrong snap | confidence UI + user override |
| Seed-VC licence/VRAM/cost | blocks Track F-neural | S1/S3 gates, fallbacks |
| Voice-clone abuse | legal/ethical | live-only identity, consent, delete, audit logs |
| Over-promising "bad -> good singer" | trust | honest labels, A/B always shown, "needs cloud" lists |
| Scope size | schedule | tracks independently shippable (A+B+C+D is a coherent release) |
