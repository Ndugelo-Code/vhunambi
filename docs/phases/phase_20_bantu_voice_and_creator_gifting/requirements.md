# Phase 20 · Requirements — Bantu Voice LoRA Synthesis & Creator Cultural Micro-Gifting

> **Phase:** 20  
> **Codename:** `bantu-voice-and-creator-gifting`  
> **Status:** 🟡 SPECIFICATION  
> **Target Apps:** `apps/vhunambi_client`  
> **Standard:** EARS / RFC 2119 Specification Standard  

---

## 1. RFC 2119 Keywords
The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in RFC 2119.

---

## 2. Functional Requirements (Track A: Bantu Voice & Dialect Engine)

### REQ-VOX-01: Bantu Voice Profiles Catalog
- The application **MUST** provide a curated catalog of at least 5 authentic African singer profiles:
  1. `venda_folk_elder` (Venda Folk Elder — deep chest timbre, natural dental articulation)
  2. `soweto_soul_lead` (Soweto Soul Lead — warm, gospel-inflected melodic runs)
  3. `durban_gqom_chanter` (Durban Gqom Chanter — percussive raw vocal projection)
  4. `maskandi_bard` (Maskandi Acoustic Bard — rapid praise poetry cadence)
  5. `limpopo_pop_queen` (Limpopo Pop Queen — high-energy, vibrant Afro-pop lead)
- Each profile **SHALL** expose metadata including `id`, `name`, `language`, `region`, `timbreDescription`, `iconEmoji`, and `loraScale`.

### REQ-VOX-02: Dialect Inflection Sliders
- The Studio cockpit **MUST** expose 4 dialect inflection parameters:
  1. `vowelElongation` (0.0 to 1.0, default 0.5): models penultimate vowel duration.
  2. `vibratoDepth` (0.0 to 1.0, default 0.4): controls ancestral tremolo resonance.
  3. `callAndResponseIntensity` (0.0 to 1.0, default 0.6): layers choral response vocals.
  4. `adLibFrequency` (0.0 to 1.0, default 0.5): injects authentic cultural ad-libs.
- Adjusting these sliders **SHALL** update `StudioFormState` reactively.

### REQ-VOX-03: Live Phonetic Lyric Alignment Preview
- When lyrics and language are present in Studio, the engine **MUST** provide a live phonetic alignment preview.
- The preview **SHALL** highlight:
  - Venda dental consonants (`ḓ`, `ṱ`, `ṋ`, `ḽ`) in primary accent color.
  - Nguni click consonants (`c`, `q`, `x`) in percussive gold accent color.
  - Syllable stress markers matching the selected tempo.

### REQ-VOX-04: Serialization into Song DNA
- When generation is triggered, the selected `BantuVoiceProfile` and `DialectInflectionConfig` **MUST** be serialized into `VocalsDna.loras` in the generated track's `SongMetadataDna`.

---

## 3. Functional Requirements (Track B: Creator Cultural Micro-Gifting & Wallet)

### REQ-GFT-01: Gifting Trigger in Reels Modal
- In `KineticReelsModal`, tapping the Tip button (`Icons.monetization_on_rounded`) on the action rail **MUST** launch `CreatorTippingSheet`.
- The modal **SHALL** display the recipient creator's avatar and handle (`@creator`).

### REQ-GFT-02: Cultural Micro-Gift Matrix
- The gifting sheet **MUST** offer 4 African cultural gifts:
  1. 🐚 **Cowrie Shell (Mbaḓi)**: 5 🪙 Coins (R2.00)
  2. 🥁 **African Drum (Ngoma)**: 15 🪙 Coins (R5.00)
  3. 🎹 **Log Drum Trophy (Tshikona)**: 50 🪙 Coins (R15.00)
  4. 👑 **Royal Venda Crown (Khare)**: 200 🪙 Coins (R50.00)
- Each gift **SHALL** render with its icon, coin price, ZAR equivalent, and cultural significance description.

### REQ-GFT-03: Optimistic Gifting & Community Celebration
- Tapping "Send Gift" **MUST**:
  1. Deduct the gift's coin cost from the sender's balance in `creatorWalletProvider`.
  2. Credit the creator's ledger with the gift amount.
  3. Trigger a visual celebratory animation (particle or floating reward banner).
  4. Automatically post a celebratory supporter announcement into the reel's comment thread (via `reelsCommentsProvider`).

### REQ-GFT-04: Creator Wallet & Payout Dashboard
- On `OwnerProfileView` and `ArtistProfileView`, the application **MUST** display a `CreatorWalletDeck`.
- The wallet **MUST** display:
  - Total lifetime tip earnings (in ZAR and Vhunambi Coins).
  - Top supporters leaderboard.
  - "Request Payout" CTA highlighting supported South African payout rails (Ozow, Capitec Pay, PayFast).

---

## 4. Performance & Token Strictness Requirements

### REQ-PRF-01: Token Discipline
- All components **MUST** strictly utilize `AppColors`, `AppRadius`, `AppTypography`, and `AppSpacing`. Zero raw hex values are permitted.

### REQ-PRF-02: Responsive Parity
- All sheets, decks, and sliders **MUST** adapt seamlessly across mobile (< 768px) and desktop (> 1024px) without render overflow.
