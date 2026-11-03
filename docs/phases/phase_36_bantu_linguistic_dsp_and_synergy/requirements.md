# Phase 36: Bantu Linguistic DSP, Story-to-Lyrics & Cross-Module Synergy - Requirements

**Document Version:** 1.0.0
**Status:** In progress
**Priority key:** P0 = blocks phase, P1 = required for release, P2 = stretch
**Language:** RFC 2119 (MUST/SHOULD/MAY). Each requirement is testable; the verifying test lives in `test/features/sound_signature/phase36_bantu_linguistics_and_synergy_test.dart` (client) or `apps/vhunambi_api` tests (API) unless noted.

---

## 1. Track A - Peer-branch Bantu linguistic DSP

- **REQ-BANTU-MODEL-01 (P0)** The domain MUST define `enum BantuLanguageBranch { nguni, sothoTswana, tshivenda, tswaRonga }` and exactly 9 supported languages mapped to branches: `zu, xh, ss, nr` -> nguni; `nso, tn, st` -> sothoTswana; `ve` -> tshivenda; `ts` -> tswaRonga. *Test:* mapping table asserted for all 9; unknown code -> null/explicit error.
- **REQ-BANTU-MODEL-02 (P0)** No code path MAY designate any language or branch as a hub, pivot or centroid. *Test:* route planner property test over all ordered language pairs asserts every route has <= 2 nodes (source, target) and contains no third language.
- **REQ-BANTU-PHON-01 (P0)** `bantu_phonology.dart` MUST expose a per-branch protection profile: Nguni = clicks + depressor onsets; Tshivenḓa = dental plosives + breathy `vh`; Sotho-Tswana = 7-vowel spacing; Tswa-Ronga = whistled sibilants. *Test:* each branch returns its distinct feature set; sets are not equal across branches.
- **REQ-BANTU-PHON-02 (P1)** Profile numeric constants (windows, thresholds) MUST be named constants documented as tunable defaults. *Test:* static check/unit test that constants are exported and finite.
- **REQ-BANTU-SIM-01 (P0)** `bantu_similarity.dart` MUST compute `Score = round(0.40*Lev + 0.30*PairwiseShift + 0.30*NounClass)`, each component in 0..100, result clamped 0..100. *Test:* weighted-sum fixtures; identical words score 100.
- **REQ-BANTU-SIM-02 (P0)** When source and target languages share a branch, the PairwiseShift component MUST use identity routing (no shift rules applied). *Test:* `zu`<->`xh` applies zero shift rules (rule count asserted = 0).
- **REQ-BANTU-SIM-03 (P0)** When branches differ, only pairwise `sourceBranch->targetBranch` rules MAY be applied. *Test:* `zu`->`ve` uses only Nguni->Tshivenḓa rules; no rule from another branch pair is consulted.
- **REQ-BANTU-SIM-04 (P1)** Noun-class alignment MUST compare class by prefix (e.g. Class 6 `ama-`<->`ma-`, Class 7 `isi-`<->`se-`<->`tshi-`). *Test:* fixtures for these pairs return aligned class.
- **REQ-BANTU-SIM-05 (P0)** The `zu->ve->xh` regression MUST NOT occur: the planner MUST route `zu` to `xh` directly. *Test:* `plan(zu, xh)` returns `[zu, xh]`; scoring `qeda` against a Nguni target is never degraded by passing through `fhela`.
- **REQ-BANTU-SIM-06 (P1)** The shift-rule table and noun-class table MUST be flagged in code and UI copy as a starter set pending linguist validation. *Test:* exported `isValidated == false` constant; no UI string contains "authoritative".
- **REQ-BANTU-DSP-A1 (P0) Depressor onset guard.** For Nguni and Tshivenḓa singers, the first ~60 ms (named constant) of a voiced run starting with a depressor consonant MUST be exempted from scale-lock correction via a linear ramp from 0 to full correction. *Test:* synthetic F0 with a depressed onset: correction at t=0 is 0, linear to full at 60 ms, unchanged after; other branches get no exemption.
- **REQ-BANTU-DSP-A2 (P0) Lexical tone polarity guard.** When the raw adjacent-run median delta is >= 2.0 semitones, the idealized delta MUST NOT invert sign. *Test:* raw +2.5 st step snapped to a scale that would produce -1 st is corrected to >= 0; raw delta < 2.0 st is not constrained.
- **REQ-BANTU-DSP-A3 (P1) Penultimate cadence anchor.** In `PocketQuantizer`, if the phrase-penultimate syllable duration >= 1.5x the phrase median syllable duration, the interval from it to the final onset MUST be preserved (the same shift is applied to both). *Test:* ratio 1.6 -> interval equal before/after; ratio 1.4 -> normal quantization.
- **REQ-BANTU-DSP-A4 (P0) No timbre normalisation.** The idealizer MUST keep the singer's own formant envelope and MUST NOT normalise toward another language's centroid. *Test:* output formants within the Phase 35 +-6% shift tolerance of the requested shift only; no centroid parameter exists.
- **REQ-BANTU-DSP-A5 (P1)** Existing Phase 35 behaviour (unvoiced consonants bit-exact) MUST remain. *Test:* Phase 35 consonant bit-exact tests still pass; new branch click-window test asserts sample-identical pass-through on flagged windows.

## 2. Track B - Story-to-Lyrics (ZR-STORYLYRICS-001)

- **REQ-BANTU-STORY-01 (P0)** The API MUST expose `POST /v1/lyrics/story-transform` in `apps/vhunambi_api`. *Test:* 200 for valid request, 400 for empty story or unknown genre, auth behaviour consistent with sibling `/v1/lyrics/*` routes.
- **REQ-BANTU-STORY-02 (P0)** v1 MUST be deterministic and not require an external LLM: identical input -> identical output. *Test:* two calls return deep-equal bodies; test runs with network disabled.
- **REQ-BANTU-STORY-03 (P1)** An optional LLM hook MAY exist behind a disabled-by-default flag. *Test:* flag off -> hook never invoked (spy).
- **REQ-BANTU-STORY-04 (P0)** Supported genres: Amapiano, Maskandi, Gqom, Gospel, Kwaito-HipHop; each returns a genre-specific section structure. *Test:* per-genre structure snapshot.
- **REQ-BANTU-STORY-05 (P0)** Genre DNA and language context MUST be strictly separated: the same genre accepts every one of the 9 languages, and changing language MUST NOT change the genre structure/caption genre fields. *Test:* genre x language matrix.
- **REQ-BANTU-STORY-06 (P0)** The response MUST include `compileAceStepCaption` output built from genre DNA + language context + vocal instructions + mood. *Test:* caption contains all four parts.
- **REQ-BANTU-STORY-07 (P1)** `LyricsReviewModal` MUST include a Story-to-Lyrics toggle with `Key('lyrics_story_mode_toggle')` and a Cognate & Rhyme Finder control with `Key('lyrics_cognate_finder_btn')`; both >= 44x44dp, Phosphor icons only. *Test:* widget test finds keys, checks size >= 44x44, toggles state.
- **REQ-BANTU-STORY-08 (P1)** The Cognate & Rhyme Finder MUST call `bantu_similarity` (no unused algorithm). *Test:* widget test with injected fake asserts invocation.

## 3. Track C - Lyric translation + phonetic sing-along

- **REQ-BANTU-LYR-01 (P0)** `bantu_lyric_translation_service.dart` MUST return per line `{originalLine, phoneticSingAlongGuide, translatedMeaning, cognateMatches}`. *Test:* shape test.
- **REQ-BANTU-LYR-02 (P0)** v1 translation MUST be lexicon-based over a small curated glossary; unknown words/lines MUST yield `translatedMeaning == 'meaning unavailable'`. It MUST NOT fabricate translations. *Test:* known word -> glossary meaning; unknown word -> 'meaning unavailable'; no network/LLM calls.
- **REQ-BANTU-LYR-03 (P1)** The phonetic guide MUST mark the penultimate syllable of each word. *Test:* fixtures for 2-, 3-, 4-syllable words.
- **REQ-BANTU-LYR-04 (P1)** `KineticReelsModal` MUST show `Key('reel_translate_lyrics_toggle')`; `LyricsTeleprompter` (track_detail_view) MUST show `Key('track_translate_lyrics_toggle')`. Targets >= 44x44dp; Phosphor icons only; no raw emojis (STD-UIUX-001). *Test:* widget tests per key, size assertion, source grep for emoji/hex.
- **REQ-BANTU-LYR-05 (P1)** Toggles default OFF; when ON, the translation layer renders without altering original line timing. *Test:* original line position unchanged.
- **REQ-BANTU-LYR-06 (P1)** Cognate badges MUST come from `bantu_similarity` and be labelled as indicative. *Test:* badge present only when score >= threshold constant.

## 4. Track D - Cross-module synergy

- **REQ-BANTU-SYN-01 (P0)** A `crossModuleSynergyProvider` MUST derive recommendation cards from real measured values (`stabilityScore`, `snrDb`, `reverbEdtMs`, `keyConfidence`, `offsetFromGridMs`, signature presence). *Test:* provider with fixtures -> expected cards; no data -> empty list (no placeholders).
- **REQ-BANTU-SYN-02 (P0)** The Voice Gap -> Idealizer card MUST open `SoundSignatureIdealizerSheet` with a preloaded `SoundIdealizerRecipe` for the gap. *Test:* tap -> recipe fields match mapping table in doc 05 §2.
- **REQ-BANTU-SYN-03 (P1)** The Signature -> Sketchpad card MUST appear only when a signature exists and links to the sketchpad hum flow. *Test:* conditional appearance.
- **REQ-BANTU-SYN-04 (P1)** `cross_module_synergy_deck.dart` MUST render on `HomeDashboardView` and (compact) on `OwnerProfileView`, show at most 3 cards, be dismissible, and meet >= 44x44dp. *Test:* widget tests.
- **REQ-BANTU-SYN-05 (P1)** Mastery badges: Polyglot Vocalist (songs in >= 3 distinct branches), Groove Architect (all 5 Phase 32 channels), Voice Sovereign (first VHU-SIG extracted). *Test:* threshold boundary tests (2 vs 3 branches; 4 vs 5 channels; 0 vs 1 signature).
- **REQ-BANTU-SYN-06 (P0)** Badge rewards MUST be cosmetic/profile only. Any perk touching money/credits is **needs owner decision** and MUST NOT be implemented. *Test:* badge model has no monetary field; grep for credit mutation in badge code = none.

## 5. Quality gates

- **REQ-BANTU-QA-01 (P0)** `dart analyze` MUST report 0 issues.
- **REQ-BANTU-QA-02 (P0)** `flutter test` and `pnpm test` MUST be green.
- **REQ-BANTU-QA-03 (P1)** ARM64 release APK MUST be <= 200 MB and install on device `EPHUT20917014649`.
- **REQ-BANTU-QA-04 (P1)** Docs MUST label Zania figures as "Zania-reported, unverified in Vhunambi" and MUST NOT describe any language as pivot/hub. *Test:* grep of `docs/bantu_intelligence_suite` and phase 36 docs for "Venda-as-Pivot" outside errata/rejection text returns none.
