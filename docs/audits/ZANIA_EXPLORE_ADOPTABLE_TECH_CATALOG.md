# Zania Explore → Vhunambi Adoptable Tech Catalog

> **Catalog ID:** `TECH-TRANSFER-ZANIA-TO-VHUNAMBI`  
> **Source Repo Audited:** `C:\Users\Ndugelo\Zania-Explore-v2.5\Zania-Explore`  
> **Date:** `2026-11-25`  
> **Scope:** Pure forensic survey — zero code modified. Every module below was read directly on disk and classified by **Vhunambi Fit**, **Production Readiness**, and **Port Effort**.

---

## 1. Tier 1 — High-Impact, Production-Ready Tech (Adopt First)

| # | Tech / Module | Exact Source Path in `Zania-Explore` | What It Does | Direct Vhunambi Value | Port Effort |
| :-: | :--- | :--- | :--- | :--- | :---: |
| **1** | **Edge ID3v2 `APIC` Cover Extractor** | `scripts/lib/id3v2-parser.ts`<br>`scripts/extract-cover-art.ts` | Zero-dependency Cloudflare Workers (`Uint8Array` + `TextDecoder`) ID3v2.3/v2.4 parser extracting JPEG/PNG/WebP cover art + round-trip R2 verification | Drop straight into `POST /api/media/upload` so every uploaded Suno/DAW MP3 auto-extracts its cover photo into R2 `covers/` with zero mobile data wasted on playback | **Low (1–2h)** |
| **2** | **RunPod Prepaid Balance Cost Guard** | `lib/monitoring/runpod-guard.ts` | Queries RunPod balance (`5s` `AbortSignal.timeout`) before dispatching GPU jobs; warns at `< $5` and auto-blocks generation at `< $2` so a spike never burns prepaid credit silently | Protects your prepaid RunPod balance (`$13.57`) from runaway retries or unexpected GPU burn in `apps/vhunambi_api/src/routes/generation_routes.ts` | **Very Low (30m)** |
| **3** | **Sovereign Bantu Linguistic & Music Context Engine** | `lib/bantu-engine/music/language-context.ts`<br>`lib/bantu-engine/linguistics/noun-classes.ts`<br>`lib/languages/tshivenda/phonology.ts`<br>`lib/languages/isizulu/phonology.ts`<br>`lib/utils/diacritics.ts` | Enforces **Genre ≠ Language** separation (`validateLanguageNeutrality()`), Proto-Bantu Noun Classes (1–15 across all 9 SA Bantu languages), Tshivenḓa/isiZulu IPA phonology & tone rules, and Tshivenḓa NFC diacritic normalizer (`ḓ ḽ ṋ ṅ ṱ` search stripping + comparison) | Upgrades Vhunambi's lyrics generation, vocal prompting (`Seed-VC` / `MiniMax-Music3` / `ACE-Step`), and diacritic-tolerant Explore search (`"Tshivenda"` matches `"Tshivenḓa"`) | **Low–Med** |
| **4** | **Story-to-Lyrics SA Genre System Prompts** | `lib/zr-studio/lyrics-engine/system-prompts.ts`<br>`lib/zr-studio/bantu-training-utils.ts` | Culturally grounded per-genre lyricist prompts (`amapiano`, `maskandi`, `gqom`, `gospel`, etc.) with authentic song structures, ad-libs, oral storytelling rules, plus Bantu phonetic hint guides (`hl`, `dl`, `ng`, `kh`, clicks) for LoRA training & vocal prompting | Directly upgrades `apps/vhunambi_api/src/modules/lyrics/llm_handler.ts` and feeds clean cultural captions into cloud LoRA training datasets | **Low** |
| **5** | **Multi-Engine Bantu Translation Router + Glossaries** | `lib/bantu-engine/translation/router.ts`<br>`lib/bantu-engine/translation/{nllb,madlad,autshumato,workers-ai}-adapter.ts`<br>`lib/bantu-engine/terminology/{glossary-service,rag-pipeline}.ts` | Priority-routed translation across **NLLB-200**, **MADLAD-400**, SA Government **Autshumato**, and edge **Cloudflare Workers AI** (`m2m100-1.2b`), backed by DSAC / OERTB / StatsSA / Mafoko terminology glossaries | Powers **1-tap Lyric Translation** ("Translate my English story into authentic Tshivenḓa / isiZulu / Sepedi lyrics") and localized Vhunambi UI across all 11 SA official languages | **Medium** |
| **6** | **Pan-African Payments (Paystack) + Rewarded-Ad Earn + Cost Calculator** | `lib/monetization/paystack-server.ts`<br>`lib/monetization/earn/rewarded-ad.ts`<br>`lib/monetization/zr-cost-calculator.ts`<br>`lib/monetization/smart-pack-recommendation.ts` | Server-side **Paystack** checkout + verification (adds Nigeria/Kenya/Ghana/SA cards alongside Vhunambi's PayFast!), edge Web-Crypto **HMAC-SHA256 rewarded-ad postback validator** with 5-min replay window & daily caps, plus pure credit-cost calculator (`base + per-min + LoRA surcharge`) | Lets free SA/African creators **watch a rewarded ad to earn free Studio generation coins** (covering your RunPod GPU cost!) and unlocks Pan-African coin top-ups via Paystack | **Medium** |

---

## 2. Tier 2 — Resilience, Edge Infrastructure & Scale Patterns (Adopt When Scaling)

| # | Tech / Module | Exact Source Path in `Zania-Explore` | What It Does | Direct Vhunambi Value |
| :-: | :--- | :--- | :--- | :--- |
| **7** | **Cloudflare Queue Async GPU Consumer (`zr-render-jobs`)** | `lib/zr-studio/queue-consumer.ts`<br>`lib/zr-studio/r2-presigned.ts` | Decouples `POST /v1/generations` from RunPod HTTP calls using Cloudflare Queues with automatic retries (max 3) and pre-signed R2 PUT/GET URLs | Eliminates HTTP timeouts if RunPod spikes or cold-starts slowly; pairs directly with `vhunambi_api` Worker |
| **8** | **Idempotency Keys + Circuit Breaker** | `lib/api/idempotency.ts`<br>`lib/utils/circuit-breaker.ts` | `Idempotency-Key` response caching (24h TTL) preventing duplicate charges/generations on mobile network retries, plus 3-state (`CLOSED` / `OPEN` / `HALF_OPEN`) Circuit Breaker | Stops flaky SA mobile data retries from double-charging Vhunambi Coins or double-submitting RunPod GPU jobs |
| **9** | **ETag + Cursor Streaming & Data-Saver Awareness** | `lib/music/etag.ts`<br>`lib/music/cursor.ts`<br>`lib/music/network-aware.ts`<br>`lib/music/extraction-scheduler.ts` | Deterministic SHA-256 ETag (`304 Not Modified`), cursor pagination, `saveData` / `2g`/`3g` detection, and `MAX_CONCURRENT = 3` extraction concurrency limiter | Slashes mobile data burn on Explore feeds & Track lists (`304` hits use 0 KB body) |
| **10** | **WebAuthn Passkeys + SA ID Verification** | `lib/auth/webauthn-service.ts`<br>`lib/auth/sa-id-validator.ts` | Biometric/Passkey login (`@simplewebauthn`) + South African 13-digit ID checksum/DOB/citizenship validator | Passwordless biometric login + fast KYC check before creator R50+ EFT/Capitec/Ozow royalty payouts! |
| **11** | **Event Ledger + Enterprise Reporting Engine** | `lib/events/{emit,queue-consumer,ip-hash}.ts`<br>`lib/reporting-engine/generators/zr-studio-viability.ts` | Privacy-preserving IP-hashed event ledger queued asynchronously + automated unit-economics / viability scorecards | Gives you a real dashboard tracking **GPU spend vs. Coin revenue per song**, play counts, and retention |

---

## 3. Modules to Skip or Replace (Not Worth Copying As-Is)
- **`runpod-zr-studio/training/train_lora.py` (lines 169–199):** Simulated stub (`time.sleep(5)` + fake loss) — keep its YAML configs and `scripts/validate_dataset.py`, replace the training loop with real `ACE-Step 1.5` LoRA/LoKr training.
- **Next.js / React / Dexie / Howler UI layers (`components/`, `stores/`, `hooks/`):** Vhunambi is native Flutter/Dart (`apps/vhunambi_client`), so only port the **pure TypeScript Worker/API modules, linguistic data, and architecture patterns** — never React/Next.js UI bindings.
- **Education / Gov / PDF / CV modules (`learning/`, `math/`, `history/`, `pdf/`, `government/`):** Out of domain for Vhunambi's music platform.

---

## 4. Recommended Adoption Order
1. **Immediate (Phase 84 — Bug Fixes + Creator Upload Unlock):** Port **`id3v2-parser.ts`** + **`diacritics.ts`** + **`runpod-guard.ts`** alongside fixing the Kinetic Reels `98%` crash (`REEL98-01..05`) and Kinetic Post upload/hydration bugs (`KPOST-01..03`).
2. **Next (Phase 85 — Bantu Lyric Intelligence + Cloud LoRA Training):** Port **`language-context.ts`**, **`system-prompts.ts`**, **`bantu-training-utils.ts`**, and **`translation/router.ts`** (Workers AI + NLLB-200) to power authentic multilingual SA lyrics & auto-captioned cloud LoRA training from `zania-storage`.
3. **Growth & Monetization (Phase 86):** Port **`paystack-server.ts`**, **`rewarded-ad.ts`** (free-user ad-funded GPU credits), **`idempotency.ts`**, **`circuit-breaker.ts`**, and **`sa-id-validator.ts`** (creator payout KYC).
