# Phase 26 Tasks: African Vocal Identity Catalog & Post-Lyrics Zero-Shot Voice Cloning

> **Phase:** 26 (`phase_26_vocal_identity_cloning`)  
> **Status:** `✅ COMPLETE`

---

## Track A: 4-Document Specification Suite
- [x] **T1.1:** Author `blueprint.md`, `requirements.md`, `design.md`, and `tasks.md` under `docs/phases/phase_26_vocal_identity_cloning/`.

## Track B: Backend Voice Catalog, Calibration Extractor & RunPod Seed-VC Worker
- [x] **T2.1 (`apps/vhunambi_api/src/modules/voices/voice_types.ts`) (new):** Define Zod schemas and TypeScript types for `VocalGender`, `AfricanVoiceRegion`, `VocalDeliveryStyle`, `RegionalVoiceArchetype`, `PhoneticCalibrationLine`, `PhoneticCalibrationScript`, and `CreatorVoiceCloneProfile`.
- [x] **T2.2 (`apps/vhunambi_api/src/modules/voices/voice_catalog.ts`) (new):** Seed the 24 regional African voice archetypes, implement `filterVoiceCatalog()`, `extractPhoneticCalibrationScript()`, and in-memory/stateful `registerVoiceCloneProfile()`.
- [x] **T2.3 (`apps/vhunambi_api/src/routes/voice_routes.ts` & `src/server.ts`) (new/modify):** Mount `/v1/voices/catalog`, `/v1/voices/extract-calibration`, and `/v1/voices/clone`.
- [x] **T2.4 (`prompt_compiler.ts`, `runpod_adapter.ts`, `generation_routes.ts`) (modify):** Extend generation submission with optional `selectedVoiceId` and `clonedVoiceProfileId` and attach `svc_config` when present.
- [x] **T2.5 (`tools/zr-studio-gpu/seed_vc_worker.py` & `docs/RUNPOD_MMO_WORKER_SPEC.md`) (new/modify):** Implement zero-shot Singing Voice Conversion & Bantu phoneme alignment worker and document in `RUNPOD_MMO_WORKER_SPEC.md`.
- [x] **T2.6 (`apps/vhunambi_api/test/voices.test.ts` & `package.json`) (new/modify):** Author backend test suite and wire into `pnpm test` (9/9 suites passing).

## Track C: Client Domain Models, Phonetic Extractor, Recorder & Providers
- [x] **T3.1 (`lib/core/constants/app_constants.dart`) (modify):** Add `voiceProfilesBoxKey = 'vhunambi_voice_profiles_box'`.
- [x] **T3.2 (`lib/features/studio/domain/models/vocal_identity_models.dart`) (new):** Implement `RegionalVoiceArchetype`, `kRegionalVoiceCatalog` (24 archetypes), `PhoneticCalibrationLine`, `PhoneticCalibrationScript`, and `CreatorVoiceCloneProfile`.
- [x] **T3.3 (`lib/features/studio/domain/services/phonetic_calibration_extractor.dart`) (new):** Implement deterministic Bantu Phonetic Density Scorer ($S_{\text{line}}$) and 3-line calibration script extractor.
- [x] **T3.4 (`lib/features/studio/domain/services/i_voice_calibration_recorder.dart`) (new):** Implement `IVoiceCalibrationRecorder` and headless-safe `DeterministicVoiceCalibrationRecorder`.
- [x] **T3.5 (`lib/features/studio/presentation/providers/vocal_identity_provider.dart`) (new):** Implement `VocalIdentityState` and `VocalIdentityNotifier` with Hive persistence and Phase 25 `masteringSessionProvider` synergy.

## Track D: UI Surfaces, `LyricsReviewModal` & `BantuVoiceDeck` Integration & Privacy Audit
- [x] **T4.1 (`lib/features/studio/presentation/widgets/voice_clone_recorder_sheet.dart`) (new):** Build 3-line teleprompter voice note calibration recorder sheet with phonetic badges, live waveform bars, and DNA synthesis CTA.
- [x] **T4.2 (`lib/features/studio/presentation/widgets/vocal_identity_picker_sheet.dart`) (new):** Build filterable 24-voice regional catalog & "My Cloned Voices" sheet.
- [x] **T4.3 (`lyrics_review_modal.dart` & `bantu_voice_deck.dart`) (modify):** Wire `"Clone My Voice (3 Lines)"` (`Key('lyrics_review_clone_voice_btn')`) and `"24 Regional Voices"` (`Key('open_vocal_identity_catalog_btn')`) into `LyricsReviewModal` and `BantuVoiceDeck`.
- [x] **T4.4 (`docs/PRIVACY_DATA_FLOW.md`) (modify):** Register `CreatorVoiceCloneProfile` and voice calibration audio in the privacy data flow audit.

## Track E: Client Automated Tests & Handoff Documentation
- [x] **T5.1 (`test/features/studio/vocal_identity_extractor_and_provider_test.dart`) (new):** Unit tests for `PhoneticCalibrationExtractor`, 24-voice catalog filtering, `DeterministicVoiceCalibrationRecorder`, and `VocalIdentityNotifier` + Phase 25 mastering coupling.
- [x] **T5.2 (`test/features/studio/widgets/voice_clone_and_picker_sheet_test.dart`) (new):** Widget tests for `VoiceCloneRecorderSheet`, `VocalIdentityPickerSheet`, and `BantuVoiceDeck` voice identity badge & triggers.
- [x] **T5.3 (`walkthrough.md` & `docs/AGENT_HANDOFF_BIBLE.md`):** Document verification metrics and update handoff bible.
