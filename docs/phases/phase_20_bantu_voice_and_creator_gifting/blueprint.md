# Phase 20 · Blueprint — Bantu Voice LoRA Synthesis & Creator Cultural Micro-Gifting

> **Phase:** 20  
> **Codename:** `bantu-voice-and-creator-gifting`  
> **Status:** 🟡 SPECIFICATION  
> **Target Apps:** `apps/vhunambi_client`  
> **Architecture Standard:** Dual-Agent Pair Programming Standard ([`docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md))  

---

## 1. Executive Vision & Cultural Context

Phase 20 unites two essential pillars of the Vhunambi ecosystem:
1. **Deep Generative Audio (Studio Track)**: Solidifying Vhunambi's technological moat as the leading African AI music platform through the **Bantu Voice LoRA & Dialect Inflection Engine**. Users in Create Studio can choose authentic African singer timbres (Venda Folk Elder, Soweto Soul Lead, Durban Gqom Chanter, Maskandi Bard, Limpopo Pop Queen) and shape dialect inflection (vowel elongation, vibrato depth, call-and-response backing, and authentic ad-libs) with live phonetic lyric alignment preview.
2. **Honest Monetization (Social Track)**: Converting social discovery into tangible income for creators through the **Creator Cultural Micro-Gifting & Creator Wallet Engine**. The unwired "Tip" button on the `KineticReelsModal` rail opens a cultural gifting drawer featuring ancestral African currency and musical symbols (🐚 Cowrie Shell, 🥁 African Drum, 🎹 Log Drum Trophy, 👑 Royal Venda Crown). Sent gifts trigger celebratory particle animations, pin supporter banners in comments, and credit the creator's payout-ready wallet.

---

## 2. Visual Layouts & Wireframes

### 2.1 Studio Track: Bantu Voice & Dialect Engine (`BantuVoiceDeck`)
```
+-----------------------------------------------------------------------------------+
|  BANTU VOICE & DIALECT INFLECTION                                 [✨ AI LoRA v2] |
|                                                                                   |
|  Select Singer Timbre:                                                            |
|  +----------------+  +----------------+  +----------------+  +----------------+   |
|  | 👴 Venda Elder |  | 🎤 Soweto Soul |  | ⚡ Gqom Chanter|  | 🌿 Maskandi    |...|
|  | Deep chest tone|  | Silky gospel   |  | Stadium hype   |  | Acoustic bard  |   |
|  +----------------+  +----------------+  +----------------+  +----------------+   |
|                                                                                   |
|  Dialect Inflection Parameters:                                                   |
|  Vowel Elongation:      [========o===========] 65%  (Penultimate syllable stretch)|
|  Vibrato & Tremolo:     [====o===============] 40%  (Warm ancestral resonance)    |
|  Call & Response Choirs:[==========o=========] 75%  (Polyrhythmic backing layers) |
|  Ad-Lib Intensity:      [=======o============] 50%  ("Ndi zwone!", "Yebo!", "Aa!")|
|                                                                                   |
|  Live Phonetic Alignment Preview:                                                 |
|  [ Ndi ] [ mu-fu-na ] [ Ma-ti-be ]  -->  /n-d-i/  [ḓ: dental]  [BPM 114 Sync]     |
+-----------------------------------------------------------------------------------+
```

### 2.2 Social Track: Creator Tipping Sheet (`CreatorTippingSheet`)
```
+-----------------------------------------------------------------------------------+
|  === (Drag Handle) ===                                                            |
|  Support @makhadzi with Cultural Gifts                                   [X] Close|
|  Your Balance: 150 🪙 Coins  (+ Top Up)                                            |
|-----------------------------------------------------------------------------------|
|  +-----------------------+   +-----------------------+                            |
|  | 🐚 Cowrie Shell       |   | 🥁 African Drum       |                            |
|  | "Ancient gratitude"   |   | "Sacred rhythm salute"|                            |
|  | 5 🪙 (R2.00)          |   | 15 🪙 (R5.00)         |                            |
|  +-----------------------+   +-----------------------+                            |
|  +-----------------------+   +-----------------------+                            |
|  | 🎹 Log Drum Trophy    |   | 👑 Royal Venda Crown  |                            |
|  | "Amapiano mastery"    |   | "Royalty honor"       |                            |
|  | 50 🪙 (R15.00)        |   | 200 🪙 (R50.00)       |                            |
|  +-----------------------+   +-----------------------+                            |
|-----------------------------------------------------------------------------------|
|  [ Add personal message: "This sound changed my day! 🔥"                        ] |
|  [ (✨) Send Gift (200 🪙 / R50.00)                                              ] |
+-----------------------------------------------------------------------------------+
```

### 2.3 Creator Wallet & Payout Deck (`CreatorWalletDeck`)
```
+-----------------------------------------------------------------------------------+
|  CREATOR EARNINGS & TIPS WALLET                                                   |
|  Total Received: R 1,420.00 (4,750 🪙 Coins)               [ Request Payout -> ]   |
|  Supported Rails: Ozow Instant EFT • Capitec Pay • PayFast                        |
|                                                                                   |
|  Top Supporters Leaderboard:                                                      |
|  1. @lerato_piano     👑 Royal Crown (x2)  •  R 100.00                            |
|  2. @thabo_beats      🎹 Log Drum Trophy   •  R 15.00                             |
|  3. @kgothatso_sa     🥁 African Drum (x3) •  R 15.00                             |
+-----------------------------------------------------------------------------------+
```

---

## 3. Responsive Geometries

| Surface | Mobile (< 768px) | Desktop (> 1024px) |
|---|---|---|
| **`BantuVoiceDeck`** | Stacked sliders, horizontal scrollable voice cards | 2-column grid (voice deck left, live phonetic preview right) |
| **`CreatorTippingSheet`** | Bottom sheet (max 65% screen height, 2x2 grid) | Centered modal dialog or slide-in right drawer |
| **`CreatorWalletDeck`** | Full-width container in Profile view | Elevated card in right sidebar or stats tab |

---

## 4. Design Token Matrix

- **Surfaces**: `AppColors.surfaceCanvas`, `AppColors.surfaceElevated`, `AppColors.surfaceModal`.
- **Gifting Highlights**: `AppColors.coinGold` (`#F59E0B`), `AppColors.brandPrimary` (`#22C55E` / `#EAB308`), `AppColors.accentOrange`.
- **Radii**: `AppRadius.cardBorder` (12px), `AppRadius.pillBorder` (999px), `AppRadius.inputBorder` (10px).
- **Typography**: `AppTypography.titleMedium`, `AppTypography.bodyMedium`, `AppTypography.caption`.
