# Phase 26 Blueprint: African Vocal Identity Catalog & Post-Lyrics Zero-Shot Phonetic Voice Cloning Engine

> **Phase:** 26 (`phase_26_vocal_identity_cloning`)  
> **Parent Blueprint:** [`docs/VHUNAMBI_V4_STUDIO_EVOLUTION_BLUEPRINT.md`](../../VHUNAMBI_V4_STUDIO_EVOLUTION_BLUEPRINT.md)  
> **Status:** `✅ COMPLETE`  
> **Target Surface:** `apps/vhunambi_api`, `apps/vhunambi_client`, `tools/zr-studio-gpu/seed_vc_worker.py`

---

## 1. Executive Summary & Architectural Vision

Across global social media, the #1 complaint against generative AI music is **vocal fatigue**: almost every track uses the same 2 generic synthetic male/female timbres and struggles with authentic African tonal/click phonetics.

**Phase 26** solves this permanently through a two-pronged **Sovereign African Vocal Identity Architecture**:
1. **24+ Sovereign Regional African Voice Catalog (`GET /v1/voices/catalog`):**
   Expands Phase 20's initial 5 Bantu LoRA profiles into a rich, filterable catalog of **24+ distinct regional vocal archetypes** stratified by Region (`Southern Africa`, `West Africa`, `East Africa`, `Central Africa`, `Diaspora`), Gender/Range (`Male`, `Female`, `Duet`, `Choir`), Delivery Style (`Melodic Soul`, `Amapiano Chant`, `Gqom MC`, `Maskandi Storyteller`, `Afrobeats Smooth`, `Choir Harmony`), and native dialect formants (`Tshivenḓa`, `isiZulu`, `Sesotho`, `Sepedi`, `isiXhosa`, `Xitsonga`, `Yorùbá`, `Kiswahili`, etc.).
2. **Post-Lyrics 3-Line Phonetic Voice Cloning (`PhoneticCalibrationExtractor` & `VoiceCloneRecorderSheet`):**
   Immediately after a creator writes or approves lyrics in `LyricsReviewModal`, they can tap **"🎤 Record My Voice (3-Line Calibration)"**. Instead of reading generic English sentences, our deterministic **Bantu Phonetic Density Scorer ($S_{\text{line}}$)** scans their own lyrics and extracts the **3 most phonetically dense lines** containing dental/velar diacritics (`ḓ`, `ṱ`, `ṋ`, `ḽ`, `ṅ`), click/cluster digraphs (`tsh`, `hl`, `dl`, `kh`, `ph`, `th`, `ng`), and cultural idioms. The user records a single 15–20 second voice note repeating those 3 lines, capturing both their **256-dim speaker timbre embedding** and their exact **phonetic cadence** for zero-shot Singing Voice Conversion (`Seed-VC` / `RVC v2`) on the RunPod GPU worker.

---

## 2. Mathematical & Systems Foundations

### 2.1 Bantu Phonetic Density Scoring Formula ($S_{\text{line}}$)
Given a candidate lyric line $L$ from the user's approved stanzas, `PhoneticCalibrationExtractor` computes:
$$S_{\text{line}}(L) = 3.0 \times N_{\text{diacritics}}(L) + 2.5 \times N_{\text{clusters}}(L) + 2.0 \times N_{\text{idioms}}(L) + 1.0 \times \text{clamp}\left(\frac{\text{wordCount}(L)}{6}, 0, 2\right)$$
- $N_{\text{diacritics}}$: Count of Tshivenḓa/Bantu diacritical characters (`ḓ`, `ṱ`, `ṋ`, `ḽ`, `ṅ` and uppercase variants).
- $N_{\text{clusters}}$: Count of Bantu consonant clusters and click digraphs (`tsh`, `dz`, `pf`, `bv`, `hl`, `dl`, `kh`, `ph`, `th`, `ng`, `nk`, `ny`, `sh`, `zh`).
- $N_{\text{idioms}}$: Count of recognized cultural interjections and glossary terms (`ndaa`, `aa`, `yebo`, `ahee`, `siyabonga`, `kea leboga`, `eish`, `yoh`, `bathong`, `haibo`, `shapa`, `khuza`).
- Top 3 distinct lines are selected to form the `PhoneticCalibrationScript`.

### 2.2 Headless-Safe Microphone Capture (`IVoiceCalibrationRecorder`)
To prevent `MissingPluginException` in headless `flutter test` runs and avoid native C++ APK bloat:
- `IVoiceCalibrationRecorder` defines a clean domain contract for starting capture, streaming 60 Hz normalized RMS amplitude (`Stream<double>`), and stopping capture to return a `VoiceCalibrationRecordingResult` (`.wav` PCM bytes, duration, average clarity, and 256-float speaker embedding preview).
- `DeterministicVoiceCalibrationRecorder` provides a zero-plugin, timer-safe implementation for tests and offline simulation.

### 2.3 Synergy with Phase 25 Mastering & Privacy Audit (`VH-013`)
- Every `RegionalVoiceArchetype` and `CreatorVoiceCloneProfile` carries a `recommendedVocalCleanseFlavor` (`studio_clean`, `warm_intimate`, `wide_anthem`) that couples directly into Phase 25's `masteringSessionProvider`.
- `docs/PRIVACY_DATA_FLOW.md` is updated to classify `CreatorVoiceCloneProfile` and calibration recordings under strict on-device Hive sovereignty + encrypted TLS 1.3 zero-training GPU synthesis.

