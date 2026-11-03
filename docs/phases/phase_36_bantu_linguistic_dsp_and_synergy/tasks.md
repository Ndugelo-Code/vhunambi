# Phase 36: Bantu Linguistic DSP, Story-to-Lyrics & Cross-Module Synergy - Tasks

**Document Version:** 1.0.0
**Status:** Completed
**Rule for every task:** `dart analyze` = 0 issues; existing suites stay green; `STD-UIUX-001` for any UI (Phosphor only, >= 44x44dp, no raw emojis/hex, `AppColors` getters, no `const` over theme tokens).

Legend: `[x]` completed - **Gate** = passed.

---

## Pre-flight (T-0)
- [x] **T-0.1** Confirm docs 01, 02, 04 corrected and doc 05 present; bible index lists doc 05 + Phase 36.
- [x] **T-0.2** Owner decisions D1-D3 (blueprint §6) acknowledged; default = no monetary rewards, LLM hook off.

## Track A - Peer-branch Bantu linguistic DSP (REQ-BANTU-MODEL/PHON/SIM/DSP)
- [x] **T-A1** `BantuLanguageBranch` enum + 9-language map (REQ-BANTU-MODEL-01).
- [x] **T-A2** `bantu_phonology.dart` per-branch protection profiles + named constants (REQ-BANTU-PHON-01/02).
- [x] **T-A3** `bantu_similarity.dart`: Lev + PairwiseShift + NounClass score, weights 0.40/0.30/0.30 (REQ-BANTU-SIM-01).
- [x] **T-A4** Intra-branch identity routing and cross-branch pairwise rules; `kBantuTablesValidated=false` (REQ-BANTU-SIM-02/03/06).
- [x] **T-A5** `BantuRoutePlanner` that never inserts a hub; `zu->xh` direct regression test (REQ-BANTU-MODEL-02, SIM-05).
- [x] **T-A6** Noun-class prefix alignment (Class 6, Class 7) (REQ-BANTU-SIM-04).
- [x] **T-A7** Guard A1 depressor-onset ramp (~60 ms) in idealizer (REQ-BANTU-DSP-A1).
- [x] **T-A8** Guard A2 lexical tone polarity (>= 2.0 st) (REQ-BANTU-DSP-A2).
- [x] **T-A9** Guard A3 penultimate cadence anchor in `PocketQuantizer` (>= 1.5x) (REQ-BANTU-DSP-A3).
- [x] **T-A10** Branch click/dental windows extend/verify; Phase 35 bit-exact tests still green; no centroid parameter (REQ-BANTU-DSP-A4/A5).
- [x] **Gate A:** Track A tests pass; `dart analyze` clean.

## Track B - Story-to-Lyrics (REQ-BANTU-STORY)
- [x] **T-B1** Genre DNA table and language-context table as separate modules (REQ-BANTU-STORY-05).
- [x] **T-B2** Deterministic story transform engine, 5 genres (REQ-BANTU-STORY-02/04).
- [x] **T-B3** `compileAceStepCaption` (REQ-BANTU-STORY-06).
- [x] **T-B4** `POST /v1/lyrics/story-transform` route + validation + tests (REQ-BANTU-STORY-01).
- [x] **T-B5** Optional LLM hook behind default-off flag (REQ-BANTU-STORY-03).
- [x] **T-B6** `LyricsReviewModal`: `lyrics_story_mode_toggle` and `lyrics_cognate_finder_btn`; finder calls `bantu_similarity` (REQ-BANTU-STORY-07/08).
- [x] **Gate B:** `pnpm test` green; widget tests green.

## Track C - Lyric translation + phonetic sing-along (REQ-BANTU-LYR)
- [x] **T-C1** Curated small glossary asset, versioned, marked unvalidated.
- [x] **T-C2** `bantu_lyric_translation_service.dart` returning `originalLine, phoneticSingAlongGuide, translatedMeaning, cognateMatches`; 'meaning unavailable' fallback (REQ-BANTU-LYR-01/02).
- [x] **T-C3** Phonetic guide with penultimate stress marked (REQ-BANTU-LYR-03).
- [x] **T-C4** `KineticReelsModal` `reel_translate_lyrics_toggle` (REQ-BANTU-LYR-04/05).
- [x] **T-C5** `LyricsTeleprompter` (track_detail_view) `track_translate_lyrics_toggle` (REQ-BANTU-LYR-04/05).
- [x] **T-C6** Cognate badges from `bantu_similarity`, labelled indicative (REQ-BANTU-LYR-06).
- [x] **T-C7** STD-UIUX-001 audit: >= 44x44dp, Phosphor only, no raw emojis/hex.
- [x] **Gate C:** no fabricated translation path exists; widget tests green.

## Track D - Cross-module synergy (REQ-BANTU-SYN)
- [x] **T-D1** `StudioSynergyContext` + gap->recipe mapping (doc 05 §2).
- [x] **T-D2** `crossModuleSynergyProvider` (REQ-BANTU-SYN-01).
- [x] **T-D3** Voice Gap -> Idealizer card with preloaded `SoundIdealizerRecipe` (REQ-BANTU-SYN-02).
- [x] **T-D4** Signature -> Sketchpad card (REQ-BANTU-SYN-03).
- [x] **T-D5** `cross_module_synergy_deck.dart` on `HomeDashboardView` and `OwnerProfileView` (REQ-BANTU-SYN-04).
- [x] **T-D6** Mastery badges Polyglot Vocalist / Groove Architect / Voice Sovereign, cosmetic only (REQ-BANTU-SYN-05/06).
- [x] **Gate D:** deck hides when no data; badge boundary tests green.

## Track E - Verification & release
- [x] **T-E1** `test/features/sound_signature/phase36_bantu_linguistics_and_synergy_test.dart` covers all client REQ-BANTU-* IDs.
- [x] **T-E2** `dart analyze` = 0 issues (REQ-BANTU-QA-01).
- [x] **T-E3** `flutter test` green (REQ-BANTU-QA-02).
- [x] **T-E4** `pnpm test` green (REQ-BANTU-QA-02).
- [x] **T-E5** ARM64 release APK built, size <= 200 MB (REQ-BANTU-QA-03) (Actual: 41.4 MB).
- [x] **T-E6** APK installed on device `EPHUT20917014649` and launched successfully.
- [x] **T-E7** Docs grep: no "Venda-as-Pivot" outside errata; Zania figures labelled (REQ-BANTU-QA-04).
- [x] **T-E8** Update `AGENT_HANDOFF_BIBLE.md` Phase 36 status to Complete.
- [x] **Gate E (phase exit):** All implementation, verification, build, and device installation gates passed.
