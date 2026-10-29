# Phase 26 Requirements: African Vocal Identity Catalog & Post-Lyrics Zero-Shot Voice Cloning

> **Phase:** 26 (`phase_26_vocal_identity_cloning`)  
> **Standard:** RFC 2119 & EARS (Easy Approach to Requirements Syntax)  
> **Status:** `✅ COMPLETE`

---

## 1. Regional African Vocal Identity Catalog (`REQ-VOC-CAT`)

- **REQ-VOC-01 (Ubiquitous):** The backend (`apps/vhunambi_api`) and client (`apps/vhunambi_client`) SHALL maintain a curated catalog of at least **24 distinct Regional African Voice Archetypes** (`RegionalVoiceArchetype`) spanning `Southern Africa`, `West Africa`, `East Africa`, `Central Africa`, and `Diaspora`.
- **REQ-VOC-02 (Ubiquitous):** Each `RegionalVoiceArchetype` SHALL specify `id`, `name`, `region`, `gender` (`male`, `female`, `duet`, `choir`), `deliveryStyle`, `nativeLanguage`, `accentDescription`, `vocalRange`, `loraScale`, `formantShiftSemitones`, and `recommendedCleanseFlavor` (linking to Phase 25 `VocalCleanseFlavor`).
- **REQ-VOC-03 (Event-Driven):** WHEN `GET /v1/voices/catalog` is queried with optional filter parameters (`region`, `gender`, `language`, `style`, `q`), `apps/vhunambi_api` SHALL return the matching subset of `RegionalVoiceArchetype` items with HTTP `200`.

---

## 2. Post-Lyrics Phonetic Calibration Extraction (`REQ-VOC-EXT`)

- **REQ-VOC-04 (Event-Driven):** WHEN a user approves or reviews lyrics in `LyricsReviewModal` or invokes `POST /v1/voices/extract-calibration`, the system SHALL score all non-empty lyric lines (excluding structural section headers like `[Chorus]`) using the deterministic Bantu Phonetic Density formula:
  $$S_{\text{line}} = 3.0 \times N_{\text{diacritics}} + 2.5 \times N_{\text{clusters}} + 2.0 \times N_{\text{idioms}} + 1.0 \times \text{clamp}\left(\frac{\text{wordCount}}{6}, 0, 2\right)$$
- **REQ-VOC-05 (Ubiquitous):** The extractor SHALL return a `PhoneticCalibrationScript` containing up to **3 top-scoring distinct lines**, each annotated with its `phoneticScore`, `highlightedTokens` (detected diacritics, consonant clusters, and cultural idioms), and `estimatedDurationSec`.
- **REQ-VOC-06 (Unwanted/Fallback):** IF the input lyrics contain fewer than 3 lines or are empty, THEN the extractor SHALL pad the script with culturally authentic fallback calibration sentences in the active language (`Tshivenḓa`, `isiZulu`, `Sesotho`, etc.) so the user always has 3 calibration lines.

---

## 3. Zero-Shot Voice Recording & Cloning Pipeline (`REQ-VOC-CLN`)

- **REQ-VOC-07 (Ubiquitous):** The client SHALL define an injectable `IVoiceCalibrationRecorder` interface with a headless-safe default implementation (`DeterministicVoiceCalibrationRecorder`) that emits live 60 Hz amplitude levels (`0.0` to `1.0`) and synthesizes a deterministic `CreatorVoiceCloneProfile` without throwing `MissingPluginException` or leaking timers.
- **REQ-VOC-08 (Event-Driven):** WHEN `POST /v1/voices/clone` is called with a valid calibration payload (`creatorName`, `language`, `calibrationLines`, `recordingDurationSec`, optional `audioBase64` or `r2ReferenceUrl`), `apps/vhunambi_api` SHALL validate the payload via Zod, compute a `CreatorVoiceCloneProfile` (`id`, `creatorName`, `nativeLanguage`, `timbreEmbedding256`, `cadenceWpm`, `clarityScore`, `recommendedCleanseFlavor`), and return HTTP `201`.
- **REQ-VOC-09 (State-Driven):** WHILE a `CreatorVoiceCloneProfile` or catalog `RegionalVoiceArchetype` is active in `vocalIdentityProvider`, submitting a track generation (`POST /v1/generations`) SHALL include `selectedVoiceId` and/or `clonedVoiceProfileId` and forward `svc_config` to `runpod_adapter.ts`.
- **REQ-VOC-10 (Ubiquitous):** The standalone Cloud GPU worker `tools/zr-studio-gpu/seed_vc_worker.py` SHALL implement F0-locked zero-shot Singing Voice Conversion (`convert_vocal_stem_with_seed_vc`) and phoneme cadence alignment (`align_bantu_phoneme_cadence`) prior to Phase 25 stem mastering.

---

## 4. UI Ergonomics, Synergy & Privacy Compliance (`REQ-VOC-UI`)

- **REQ-VOC-11 (Event-Driven):** WHEN the user taps `"🎤 Record My Voice (3-Line Calibration)"` (`Key('lyrics_review_clone_voice_btn')`) in `LyricsReviewModal`, the system SHALL open `VoiceCloneRecorderSheet` (`Key('voice_clone_recorder_sheet')`) pre-populated with the 3 highest-scoring lines (`Key('calibration_line_0')`, `Key('calibration_line_1')`, `Key('calibration_line_2')`) from the current lyric draft.
- **REQ-VOC-12 (Event-Driven):** WHEN the user completes recording and taps `"✨ Synthesize My Voice DNA"` (`Key('voice_clone_finalize_btn')`), the system SHALL persist the `CreatorVoiceCloneProfile` to Hive (`AppConstants.voiceProfilesBoxKey`), select it as the active vocal identity, and synchronize the recommended `VocalCleanseFlavor` with `masteringSessionProvider`.
- **REQ-VOC-13 (State-Driven):** The user SHALL be able to browse and filter all 24+ regional voices and their saved cloned voices in `VocalIdentityPickerSheet` (`Key('vocal_identity_picker_sheet')`) accessible from `BantuVoiceDeck` (`Key('open_vocal_identity_catalog_btn')`) and `LyricsReviewModal`.
- **REQ-VOC-14 (Ubiquitous — Token & Touch Discipline):** Every interactive control in `VoiceCloneRecorderSheet` and `VocalIdentityPickerSheet` SHALL enforce a minimum `44×44dp` touch target and use zero hardcoded hex colors or raw border radii.
- **REQ-VOC-15 (Ubiquitous — Privacy Audit):** `docs/PRIVACY_DATA_FLOW.md` SHALL explicitly document `CreatorVoiceCloneProfile` and voice calibration recordings as sovereign user assets with zero foundation model training.

