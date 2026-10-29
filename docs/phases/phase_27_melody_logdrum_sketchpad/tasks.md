# Phase 27 Tasks: Device-Adaptive In-Key Melody, Chord & Log-Drum Pattern Sketchpad

> **Phase:** 27 (`phase_27_melody_logdrum_sketchpad`)  
> **Status:** `✅ COMPLETE & VERIFIED`

---

## Track A: 4-Document Specification Suite
- [x] **T1.1:** Author `blueprint.md`, `requirements.md`, `design.md`, and `tasks.md` under `docs/phases/phase_27_melody_logdrum_sketchpad/`.

## Track B: Backend Melody Routes, Starter Presets & MMO/Mastering Synergy Bridge
- [x] **T2.1 (`apps/vhunambi_api/src/modules/melody/melody_types.ts` & `melody_presets.ts`) (new):** Define Zod schemas (`SketchpadInstrument`, `AfricanScaleMode`, `MelodyStepNote`, `MelodyPatternManifest`), scale frequency math, deterministic WAV header synthesizer, transient extractor, and 6 seeded African starter patterns.
- [x] **T2.2 (`apps/vhunambi_api/src/routes/melody_routes.ts` & `src/server.ts`) (new/modify):** Mount `GET /v1/melodies/presets` and `POST /v1/melodies/render-reference` at `/v1/melodies`.
- [x] **T2.3 (`dna_compiler.ts`, `generation_routes.ts`, `prompt_compiler.ts`, `runpod_adapter.ts`, `mastering_types.ts`, `stem_mastering_worker.py`) (modify):** Wire `melody_conditioning` into generation dispatch, merge sketchpad step transients into `MasterMediaObjectManifest.modulationBus.transientEvents`, and add `sketchpadLayerMix` (`0.0..1.0`) to `StemMasteringRecipe`.
- [x] **T2.4 (`apps/vhunambi_api/test/melodies.test.ts` & `package.json`) (new/modify):** Author backend test suite and wire into `pnpm test` (**10/10 suites passing**).

## Track C: Client Domain Models, Scale Engine, FM/Harmonic WAV Synthesizer & Hive Vault
- [x] **T3.1 (`lib/core/constants/app_constants.dart`) (modify):** Add `melodySketchesBoxKey = 'vhunambi_melody_sketches_box'`.
- [x] **T3.2 (`lib/features/studio/domain/models/melody_sketchpad_models.dart`) (new):** Implement `SketchpadInstrument`, `AfricanScaleMode`, `ChordStampMode`, `MelodyStepNote`, `MelodyPatternEntity`, `resolveScaleFrequencyHz()`, and `kStarterMelodyPatterns` (6 seeded patterns).
- [x] **T3.3 (`lib/features/studio/domain/services/melody_wav_synthesizer.dart`) (new):** Implement pure-Dart 16-bit PCM RIFF/WAVE synthesizer (`synthesizePatternToWavBytes`) with DX10-style FM log-drum synthesis, pitch glide, Rhodes triad voicing, Maskandi guitar pluck, and Venda mbira tine overtones, plus Euclidean groove generator.
- [x] **T3.4 (`stem_mastering_recipe.dart`, `mastering_session_provider.dart`, `studio_form_state.dart`, `studio_form_provider.dart`) (modify):** Add `sketchpadLayerMix` (`0.0..1.0`) to `StemMasteringRecipe` and `setSketchpadLayerMix` to `MasteringSessionNotifier`.
- [x] **T3.5 (`lib/features/studio/presentation/providers/melody_sketchpad_provider.dart`) (new):** Implement `MelodySketchpadState` and `MelodySketchpadNotifier` with 8×16 grid toggling, Chord Stamp, Glide mode, Euclidean Groove Assist, Hive persistence (`melodySketchesBoxKey`), and 1-tap attachment to `studioFormProvider` + `masteringSessionProvider`.

## Track D: Device-Adaptive Mobile/Desktop UI Surfaces, Entrypoint Wiring & Privacy Audit
- [x] **T4.1 (`lib/features/studio/presentation/widgets/melody_sketchpad_modal.dart`) (new):** Build responsive `MelodySketchpadModal` featuring:
  - **Mobile (< 768px):** Bar-Paginated 4-Step HIG Grid (`Key('mobile_bar_page_0..3')`), Dual Input Mode Toggle (`Key('mobile_input_mode_toggle')`), 8-Pad Live Scale Performance Deck (`Key('mobile_scale_pad_0..7')`), and 1-Thumb Euclidean Groove Assist (`Key('sketchpad_euclidean_groove_btn')`).
  - **Desktop (> 1024px):** Full 16-Step × 8-Row Split DAW Piano Roll (`Key('desktop_piano_roll_grid')`), Chord Voicing Stamp (`Key('desktop_chord_stamp_single')`, `Key('desktop_chord_stamp_triad')`, `Key('desktop_chord_stamp_seventh')`), Bottom 16-Step Velocity & Glide Stalk Lane (`Key('desktop_velocity_lane')`), and QWERTY Keyboard Synth listener.
- [x] **T4.2 (`reference_audio_dropzone.dart` & `crate_browser_deck.dart`) (modify):** Wire `Key('dropzone_open_sketchpad_btn')` and `Key('dropzone_active_sketchpad_badge')` in `ReferenceAudioDropzone`, and `Key('crate_open_sketchpad_btn')` in `CrateBrowserDeck`.
- [x] **T4.3 (`docs/PRIVACY_DATA_FLOW.md`) (modify):** Document `Saved Melody Sketchpad Patterns` (on-device Hive) and `Ephemeral Melody Reference WAV` in §2 and §3.

## Track E: Automated Tests & Final Documentation
- [x] **T5.1 (`test/features/studio/melody_sketchpad_provider_and_synth_test.dart`) (new):** Unit tests for `resolveScaleFrequencyHz`, `MelodyWavSynthesizer` (RIFF/WAVE header, DX10 log-drum glide, instrument waveforms), Euclidean groove generator, Hive vault save/delete, and `studioFormProvider` + `masteringSessionProvider` (`sketchpadLayerMix`) coupling.
- [x] **T5.2 (`test/features/studio/widgets/melody_sketchpad_modal_test.dart`) (new):** Widget tests verifying both Mobile (`< 768px` Bar-Paginated 4-Step Grid + 8-Pad Live Scale Deck) and Desktop (`> 1024px` 16-Step Piano Roll + Chord Stamp + Velocity Lane) surfaces, plus `ReferenceAudioDropzone` & `CrateBrowserDeck` triggers.
- [x] **T5.3 (`walkthrough.md` & `docs/AGENT_HANDOFF_BIBLE.md`):** Record verification metrics (`10/10` backend suites, `1,152+` client tests, `0` analyzer issues).
