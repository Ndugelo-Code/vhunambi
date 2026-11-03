# Phase 36: Bantu Linguistic DSP, Story-to-Lyrics & Cross-Module Synergy - Blueprint

**Document Version:** 1.0.0
**Status:** In progress (docs authored 2026-11-03)
**Depends on:** Phase 32 (5-channel sketchpad), Phase 35 (`SoundSignatureDna`, vocal idealizer, `PocketQuantizer`)
**Research basis:** `docs/bantu_intelligence_suite/` (01-05). Docs 01, 02, 04 carry a 2026-11-03 correction: **Tshivenḓa is a peer branch, not a pivot.**
**Standards:** `STD-UIUX-001` (Phosphor icons only, >= 44x44dp targets, no raw emojis, no raw hex, `AppColors` getters, no `const` over theme tokens)

---

## 1. Vision

Give Vhunambi the linguistic intelligence Zania only wrote as text: peer-branch-aware Bantu DSP guards, deterministic Story-to-Lyrics, honest lyric translation with a phonetic sing-along, and cross-module actions that surface what the studio already measures.

## 2. Linguistic model (binding for all tracks)

Four equal peer branches of Southern Bantu, no hub:

```
 Nguni (S40)  <─────────>  Sotho-Tswana (S30)
 zu xh ss nr                nso tn st
     ▲  ╲                    ╱  ▲
     ▼    ╲                ╱    ▼
 Tswa-Ronga (S50) <─────>  Tshivenḓa (S20)
 ts                         ve
```

- `enum BantuLanguageBranch { nguni, sothoTswana, tshivenda, tswaRonga }`; 9 languages: `zu, xh, ss, nr` (Nguni), `nso, tn, st` (Sotho-Tswana), `ve` (Tshivenḓa), `ts` (Tswa-Ronga).
- **Rule 1** intra-branch = direct identity routing (no shift rules). **Rule 2** cross-branch = pairwise `sourceBranch→targetBranch` rules + noun-class prefix alignment. **Rule 3** the idealizer loads the singer's branch protection profile.
- The route planner **never inserts a hub**.
- Shift-rule and noun-prefix tables are a **starter set** needing native-speaker/linguist validation; they must not be described as authoritative in UI or docs.

## 3. Tracks

| Track | Scope | Primary location |
| :--- | :--- | :--- |
| A | Peer-branch Bantu linguistic DSP (Dart) + 3 DSP guards | `lib/features/sound_signature/domain/dsp/` |
| B | Story-to-Lyrics `ZR-STORYLYRICS-001` | `apps/vhunambi_api`, `LyricsReviewModal` |
| C | Lyric translation + phonetic sing-along | `bantu_lyric_translation_service.dart`, `KineticReelsModal`, `LyricsTeleprompter` |
| D | Cross-module synergy deck + mastery badges | `crossModuleSynergyProvider`, `cross_module_synergy_deck.dart`, `HomeDashboardView`, `OwnerProfileView` |

## 4. What is real vs. claimed

- Zania accuracy/BLEU/uplift numbers are **Zania-reported, unverified in Vhunambi**; Phase 36 makes no such claims.
- Phase 35 PSOLA already leaves unvoiced consonants bit-exact; Track A *extends/verifies* with branch-specific windows, it does not introduce click protection.
- Numeric DSP constants (60 ms depressor window, 2.0 st polarity threshold, 1.5x penultimate ratio) are **design defaults to be tuned/measured on Vhunambi data**, not linguistic laws.
- v1 translation is lexicon-based over a small curated glossary; unknown words show "meaning unavailable".

## 5. Non-goals

- No hub/pivot language; no formant normalisation toward any language.
- No external LLM dependency in v1 (optional hook only).
- No monetary/credit rewards (**needs owner decision**).
- No new ML models; APK stays <= 200 MB (ARM64 release).

## 6. Decisions needing owner input

| # | Decision | Default |
| :--- | :--- | :--- |
| D1 | Any reward touching money/credits for badges | **None** (cosmetic only) |
| D2 | Optional LLM hook for story transform | Off in v1 |
| D3 | Who validates the starter shift/noun-class/glossary tables (native speakers) | Open |

## 7. Exit criteria

All `tasks.md` gates green: `dart analyze` 0 issues, `flutter test` and `pnpm test` green, ARM64 release APK <= 200 MB installed on device `EPHUT20917014649`.
