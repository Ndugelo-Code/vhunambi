# Phase 35: Sound Signature ID (`VHU-SIG`) & Vocal Idealizer - Requirements

**Document Version:** 1.0.0
**Status:** Specification Draft for sign-off
**Priority key:** P0 = blocks phase, P1 = required for release, P2 = stretch

---

## 1. Functional Requirements

### 1.1 Track A - Real Intake Foundation

- **REQ-SIG-INTAKE-01 (P0) Real microphone capture.** A real `IAudioIntakeRecorder` implementation captures mono PCM16 at 44,100 Hz via the `record` plugin. It implements the existing `IVoiceCalibrationRecorder` seam so `VoiceCloneRecorderSheet` and all tests keep working; `DeterministicVoiceCalibrationRecorder` stays as the headless test double.
- **REQ-SIG-INTAKE-02 (P0) Permission flow.** `RECORD_AUDIO` declared in the Android manifest; runtime request with a rationale sheet; denial and "permanently denied" states show an actionable Phosphor-icon message (open settings), never a dead end.
- **REQ-SIG-INTAKE-03 (P0) Live metering from real samples.** The existing `amplitudeStream` emits RMS computed from actual captured frames (replacing the synthetic sine).
- **REQ-SIG-INTAKE-04 (P1) Import.** `ReferenceAudioDropzone` replaces its mock with a real picker; supports WAV/MP3/M4A/AAC/OGG; decodes to PCM; rejects > 60 s and < 3 s with a specific message; shows the real waveform and duration.
- **REQ-SIG-INTAKE-05 (P1) Input Quality Gate.** Before analysis, compute SNR, clipping %, level, bandwidth, and speech/voiced ratio. Show a traffic-light verdict with plain-language fixes ("move closer", "too much room echo"). Block (not warn) only when voiced duration < 3 s or clipping > 5%.
- **REQ-SIG-INTAKE-06 (P0) Source flag.** Every signature carries `source: live | imported`. `imported` signatures **cannot** be registered as a voice *identity* clone (REQ-SIG-PRIV-04).
- **REQ-SIG-INTAKE-07 (P1) Raw take retention.** The raw PCM take is saved to the app documents directory as WAV; the signature references it by relative path. Missing file degrades gracefully (A/B disabled, recipe preserved).

### 1.2 Domain Model & Persistence

- **REQ-SIG-DNA-01 (P0)** `SoundSignatureDna` immutable entity: `id` (ULID), `displayCode` (`VHU-SIG-XXXX`), `source`, `createdAtIso`, `durationSec`, `sampleRate`, `bpmHint`, five layers (design §2), `recipe`, `rawAudioPath`, `cloudEmbeddingRef?`, `schemaVersion`.
- **REQ-SIG-DNA-02 (P0) Display code.** `XXXX` = first 4 hex of SHA-256(layer bytes + `createdAtIso`); on collision within the local vault, re-salt until unique. It is a **label only**; the ULID is the key.
- **REQ-SIG-DNA-03 (P0) Binary codec.** `SigCodec` v1 encodes the signature as `Uint8List` with explicit version byte. Size <= 8 KB for <= 20 s of audio (design §2.4). Decode of an unknown newer version fails soft (read-only, "update app").
- **REQ-SIG-DNA-04 (P0) Storage.** New `AppConstants.soundSignaturesBoxKey = 'vhunambi_sound_signatures_box'`; opened at startup alongside existing boxes; headless-safe (`Hive.isBoxOpen` guard pattern used by `VocalIdentityNotifier`).
- **REQ-SIG-DNA-05 (P1) Link to clone profile.** `CreatorVoiceCloneProfile` gains optional `signatureId`; existing persisted profiles (no field) still load.
- **REQ-SIG-DNA-06 (P1) Honest metrics.** Replace hard-coded `clarityScore` and text-derived `cadenceWpm` with values derived from the analysed audio.

### 1.3 Track B - Analysis DSP (all on device, isolate, pure Dart)

- **REQ-SIG-ANALYSIS-01 (P0) F0 tracking.** YIN (direct form; FFT-accelerated only if the REQ-SIG-ANALYSIS-11 budget is missed) with cumulative-mean-normalised difference, absolute threshold 0.15, parabolic interpolation, continuity penalty against octave jumps, 5-frame median smoothing. Output 100 Hz internally, stored at 50 Hz cents.
- **REQ-SIG-ANALYSIS-02 (P0) Voicing decision.** A frame is voiced iff aperiodicity $d'_{\min} < 0.20$ **and** RMS above an adaptive noise-floor gate. Unvoiced frames are never pitch-processed (protects Bantu consonants/clicks).
- **REQ-SIG-ANALYSIS-03 (P0) Formants.** LPC (order $2+F_s/1000$ at 16 kHz, pre-emphasis 0.97, 25 ms Hamming, Levinson-Durbin), root-solve, keep poles with bandwidth < 400 Hz and f > 90 Hz; $F_1$-$F_4$ = median over high-HNR vowel-like frames.
- **REQ-SIG-ANALYSIS-04 (P0) Descriptor.** 16 mean cepstral coefficients $c_1..c_{16}$ over voiced frames (24 log-mel -> DCT, $c_0$ dropped). Similarity = cosine.
- **REQ-SIG-ANALYSIS-05 (P1) Harmonic purity.** HNR via normalised autocorrelation at $T_0$: $\mathrm{HNR}=10\log_{10}\frac{r(T_0)}{1-r(T_0)}$; `harmonicPurityRatio = clamp(HNR/30, 0, 1)`.
- **REQ-SIG-ANALYSIS-06 (P1) Glottal-warmth proxy.** Normalised H1-H2 level difference over voiced frames, documented as a heuristic proxy.
- **REQ-SIG-ANALYSIS-07 (P0) Key & scale.** Estimate root via pitch-class histogram weighted by duration/stability, scored against the four `AfricanScaleMode` templates; always **user-overridable**; confidence reported. A chosen song key overrides estimation.
- **REQ-SIG-ANALYSIS-08 (P1) Vibrato measurement.** Detect natural vibrato rate (4-8 Hz) and depth (cents) per sustained note via the F0 residual after slow-trend removal.
- **REQ-SIG-ANALYSIS-09 (P0) Onsets & grid.** Log-compressed spectral flux with adaptive median threshold; offsets measured against a BPM grid (user/project BPM, else tempo estimate).
- **REQ-SIG-ANALYSIS-10 (P1) Quality profile.** SNR (speech vs noise-floor percentile), clipping %, bandwidth (-20 dB rolloff), integrated loudness, reverb estimate (early-decay time from offsets).
- **REQ-SIG-ANALYSIS-11 (P1) Performance budget.** Full analysis of a 20 s take < 3 s on the Huawei ARM64 test device, in an isolate; UI shows progress and stays responsive.
- **REQ-SIG-ANALYSIS-12 (P0) Sub-octave protection (guard G1).** The first local minimum of $d'$ below 0.15 receives a $-0.05$ cost bonus in the Viterbi candidate scorer so a $2\tau$ minimum never beats the true period; verified with a strong-subharmonic synthetic signal.
- **REQ-SIG-ANALYSIS-13 (P0) NaN-free formants (guard G2).** Durand-Kerner capped at 30 iterations / 1e-5; non-convergence or non-finite roots fall back to parabolic peak-picking on the 512-point all-pole spectrum $1/|A(e^{j\omega})|^2$. No `NaN`/`Infinity` may ever be written into a `SoundSignatureDna`; the codec rejects non-finite values.

### 1.4 Track C - Vocal Idealizer (non-destructive, recipe over raw take)

- **REQ-SIG-IDEAL-01 (P0) Scale Lock.** Per segmented note, target = nearest allowed scale degree (root-relative offsets of the chosen mode, folded mod 12). Correction amount scaled by `pitchScaleLock`; retune smoothing time constant $\tau = 5\text{ ms} + 195\text{ ms}\,(1-\lambda_p)$.
- **REQ-SIG-IDEAL-02 (P0) Glide preservation.** A monotone slope > 10 st/s sustained > 80 ms is classified an intentional glide and exempted from snapping (offset only).
- **REQ-SIG-IDEAL-03 (P0) Safety rail.** Any note needing > 700 cents correction is left unchanged on device and listed as "needs cloud".
- **REQ-SIG-IDEAL-04 (P0) Pitch shifting method.** TD-PSOLA driven by F0-derived pitch marks; unvoiced/transient regions bypass pitch processing; ratio limits per design §5.
- **REQ-SIG-IDEAL-05 (P0) Vibrato & Sustain Polish.** Decompose F0 into slow note trend, 4-8 Hz vibrato band, and > 8 Hz tremor; remove tremor; blend natural and synthetic vibrato by `vibratoAndSustainPolish`; synthetic vibrato 5.2 Hz, depth <= 35 cents, onset delay 150 ms, only on notes >= 300 ms.
- **REQ-SIG-IDEAL-06 (P1) Sustain extension.** Notes tails may be extended up to +120 ms by pitch-synchronous grain repetition with crossfade (no looping artifacts audible at 44.1 kHz test).
- **REQ-SIG-IDEAL-07 (P0) Formant Shift.** Independent of pitch via PSOLA grain resampling; +-3 st hard bound; $F_1$-$F_3$ of the output verified by LPC within +-6% of the target shift.
- **REQ-SIG-IDEAL-08 (P1) Chest Power & Air chain.** Order: denoise -> box cut -> compressor -> low shelf -> $F_1$ peaking lift -> HNR-gated air (high shelf + harmonic exciter) -> true-peak limiter at -1 dBTP.
- **REQ-SIG-IDEAL-09 (P1) Pocket Quantize.** Segment onsets moved by $-q\cdot o_i$, max 90 ms; gap handled by silence trim/pad, else WSOLA stretch <= +-15%.
- **REQ-SIG-IDEAL-10 (P1) Hybrid preview (approximate).** On-device hybrid uses formant shift + spectral-tilt EQ toward the archetype descriptor, labelled **"Approximate preview - final blend rendered in cloud"**.
- **REQ-SIG-IDEAL-11 (P0) Non-destructive.** The raw take is never modified; recipe changes re-render from raw; "Reset" restores defaults instantly.
- **REQ-SIG-IDEAL-12 (P1) Reference Cleanup.** Spectral-subtractive/Wiener denoise (decision-directed, gain floor 0.1) with strength control; heavy dereverb deferred to cloud.
- **REQ-SIG-IDEAL-13 (P0) Segment-wise trajectory filtering (guard G3).** The F0 decomposition never filters across the `-32768` unvoiced sentinel: unvoiced gaps < 60 ms are bridged linearly in semitone space; each contiguous voiced run is filtered independently (forward-backward Butterworth, 10-frame reflected padding, state reset per run); runs < 20 frames are trend-only.
- **REQ-SIG-IDEAL-14 (P0) PSOLA overlap-add safety (guard G4).** Grains are extracted at half-width $\lceil T_a\max(1,s)\rceil$ before $1/s$ resampling so upward formant shifts keep full coverage; the OLA divisor is $\max(W_{\text{sum}}[n],0.20)$ for **all** ratios (including pitch-down); floor-hit rate > 2% raises an artifact warning.

### 1.5 A/B Audition

- **REQ-SIG-AB-01 (P0)** `SoundSignatureResynthesizer` renders to a 44,100 Hz mono (stereo-ready) PCM16 buffer using the same master rate and WAV writer as `MelodyWavSynthesizer`.
- **REQ-SIG-AB-02 (P0)** One-tap `[ Raw | Perfected ]` toggle switches sources at the **same playhead position** with a 10 ms crossfade; both buffers loudness-matched (within 0.5 LU) so "louder = better" bias is removed.
- **REQ-SIG-AB-03 (P1)** Slider changes re-render only the affected span (debounced 250 ms); full re-render for the 20 s take < 4 s.
- **REQ-SIG-AB-04 (P1)** Render runs in an isolate; cancellation supported; no dropped UI frames.

### 1.6 Track E - Sketchpad Bridge

- **REQ-SIG-HUM-01 (P0) Hum -> notes.** Segment voiced F0 into notes (hysteresis +-0.5 st, min 60 ms); map to `scaleRow 0..7` for the selected scale/root with whole-phrase octave folding minimising total distance; `stepIndex = round((onset-t_0)/stepDur) mod 16`; `durationSteps = clamp(round(dur/stepDur),1,4)`; `velocity` from normalised RMS (0.05-1.0).
- **REQ-SIG-HUM-02 (P1) Glide flag.** `hasGlide = true` when the note ends >= 3.5 st below its start (matches the -5 st log-drum slide).
- **REQ-SIG-HUM-03 (P1) Percussion intake.** Beatbox/tap input classified percussive (HNR low, no stable F0) -> onsets to drum rows via spectral-centroid thresholds (low = kick row, mid = snare, high = hat).
- **REQ-SIG-HUM-04 (P0) Target channel.** User chooses channel (`lead/chords/bass/drums/hats`); existing notes are not destroyed without an explicit "Replace" choice and undo.
- **REQ-SIG-INST-01 (P1) Custom signature instrument.** `SketchpadInstrument.customSoundSignature`; the channel stores `customSignatureId`. Persisted sketches stay loadable; unknown enum values fall back as today via `fromWire`.
- **REQ-SIG-INST-02 (P1) Sampler.** Choose the best sustained region (0.2-0.8 s: stable F0, high HNR); pre-render 8 scale-row buffers by PSOLA at selection time; playback is sample-accurate in the master mix.
- **REQ-SIG-INST-03 (P1) Percussive mode.** Non-pitched sources map the 8 rows to varispeed variants (no pitch claim) and are only offered on `drums/hats`.
- **REQ-SIG-INST-04 (P1) Render parity.** Custom instruments render identically in on-device preview and `/v1/melodies/render-reference` (server receives pre-rendered stem or sample buffer ref, never raw voice without consent).

### 1.7 Track D - UI/UX

- **REQ-SIG-UI-01 (P0) `SoundSignatureIdealizerSheet`.** Responsive sheet (mobile full-height, desktop side sheet) showing: `VHU-SIG-XXXX` badge, quality verdict, painter (raw vs ideal pitch + formant markers), A/B toggle, seven controls, key/scale selector (with detected + confidence), actions: **Save**, **Apply to Song**, **Send to Sketchpad**, **Export vocal stem (W2)**, **Delete**.
- **REQ-SIG-UI-02 (P0) Standards.** `STD-UIUX-001`: Phosphor glyphs only, 44x44dp targets, zero raw emojis, zero hex literals, `AppColors` getters, no `const` over theme tokens; painters read colours at paint time; verified in Light and Dark.
- **REQ-SIG-UI-03 (P1) Integrations.** `VoiceCloneRecorderSheet` -> "Analyse my voice" step; `ReferenceAudioDropzone` -> real import + analyse; `OwnerProfileView.voicesAndMelodies` lists signatures with badge, A/B audition, re-sculpt, delete; vault storage modal shows signature audio quota.
- **REQ-SIG-UI-04 (P1) No dead ends.** Every button performs a real action or is not shown; no SnackBar-only stubs (consistent with FLAWS audit M6).
- **REQ-SIG-UI-05 (P1) Honest labelling.** Hybrid preview badge "Approximate"; low-confidence key shows "Check key"; refused >700-cent notes are listed.

### 1.8 Track F - Cloud, API & Privacy

- **REQ-SIG-CLOUD-01 (P0) Durable registry.** Replace the in-memory `clonedVoiceStore` with persistent storage; survive restart/deploy.
- **REQ-SIG-CLOUD-02 (P0) Real upload.** Reference/take uploaded to R2 via presigned URL **only** on explicit user action; server verifies object exists before returning a profile; fabricated URL default removed.
- **REQ-SIG-CLOUD-03 (P0) Endpoints.** `POST /v1/voices/signatures` (register metadata + recipe, returns presign), `POST /v1/voices/signatures/:id/analyze` (enqueue cloud embed + enhance), `PATCH /v1/voices/signatures/:id/recipe`, `GET /v1/voices/signatures/:id`, `DELETE /v1/voices/signatures/:id` (purges R2 + embedding). Zod-validated; auth-scoped.
- **REQ-SIG-CLOUD-04 (P0) Real speaker encoder.** `extract_speaker_timbre_embedding` replaced by a real model; dimension configurable (192/256); hash fallback **removed** from production path (explicit error instead of fake success).
- **REQ-SIG-CLOUD-05 (P0) Stage actually executes.** `handler.py` calls the SVC stage when `svc_config` present and the mastering stage afterwards; the job result includes per-stage `executed: true`, timing and input/output hashes so "did it run" is verifiable. `convert_vocal_stem_with_seed_vc` must read and write real audio or raise.
- **REQ-SIG-CLOUD-06 (P1) Recipe in cloud.** `svc_config` extended with `signatureRecipe` (formant shift, hybrid id/mix, cleanup strength); documented fallback behaviour when a spike fails (design §8).
- **REQ-SIG-CLOUD-07 (P1) Reference enhance.** Cloud reference cleaning (denoise/dereverb) before embedding; reports before/after SNR.

### 1.9 Privacy & Safety

- **REQ-SIG-PRIV-01 (P0) On-device default.** Analysis, idealize, preview and sketchpad conversion never leave the device.
- **REQ-SIG-PRIV-02 (P0) Explicit consent.** Upload requires a dedicated consent sheet naming what is sent, retention, and how to delete; consent timestamp stored with the signature.
- **REQ-SIG-PRIV-03 (P0) Delete everywhere.** One action removes local raw take, signature blob, and (if uploaded) R2 object + server record + embedding; confirmation shows what will be removed (POPIA-aligned).
- **REQ-SIG-PRIV-04 (P0) Anti-impersonation.** Voice *identity* registration requires `source: live` and the randomised calibration read; imported audio is limited to style/melody reference and Hum-to-Sketchpad.
- **REQ-SIG-PRIV-05 (P1) Docs.** `docs/PRIVACY_DATA_FLOW.md` updated: new data class "voice biometrics", on-device storage, cloud flow, retention, deletion.

---

## 2. Non-Functional Requirements

| ID | Requirement |
| :--- | :--- |
| **NFR-SIG-01** | APK <= 45 MB; no bundled ML models; plugin additions documented with size delta. |
| **NFR-SIG-02** | All DSP is pure Dart, pure-function, deterministic (seeded) and unit-testable without a device. |
| **NFR-SIG-03** | Analysis/render in isolates; main isolate never blocks > 8 ms per frame. |
| **NFR-SIG-04** | Memory: peak < 120 MB during a 60 s import analysis. |
| **NFR-SIG-05** | Accessibility: all controls have semantic labels; A/B state announced. |
| **NFR-SIG-06** | `dart analyze lib test` = 0 issues; existing suites stay green. |

## 3. Test Requirements

- **REQ-SIG-TEST-01** Synthetic-signal unit tests: sine/harmonic stack with known F0, vibrato, detune; LPC test via all-pole-filtered impulse train with known formants.
- **REQ-SIG-TEST-02** Acceptance thresholds (from design §10): F0 RMSE <= 5 cents (clean), octave-error <= 2%, Scale-Lock median error <= 10 cents, formant drift < 5% after +-4 st correction, onset F1-score >= 0.9, Hum->notes accuracy >= 90%.
- **REQ-SIG-TEST-03** Golden-file tests for `SigCodec` round-trip and size budget.
- **REQ-SIG-TEST-04** Widget tests: sheet renders in Light/Dark, A/B toggle, slider -> re-render request, permission-denied states (using the fake recorder).
- **REQ-SIG-TEST-05** API tests: signature CRUD, consent required, delete purges, imported-source identity rejection.
- **REQ-SIG-TEST-06** GPU worker tests: stage-executed assertions; refuses to fake success when model missing.
- **REQ-SIG-TEST-07** Manual device matrix: Huawei ARM64 mic capture, headset mic, noisy room, quiet room.
- **REQ-SIG-TEST-08** Guard tests G1-G4 exactly as listed in design §10 (sub-octave, LPC convergence, segment filtering, window-sum floor), including a NaN/Inf sweep over the whole recipe space.

## 4. Traceability

| Audit finding | Requirements |
| :--- | :--- |
| SIG-F01 | INTAKE-01..03, 05 |
| SIG-F02 | DNA-06, ANALYSIS-03/04, CLOUD-04 |
| SIG-F03 | CLOUD-02 |
| SIG-F04 | CLOUD-01 |
| SIG-F05 | CLOUD-05, 06 |
| SIG-F06 | INTAKE-04 |
| SIG-F07 | ANALYSIS-*, IDEAL-* |
