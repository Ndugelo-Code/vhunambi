# Phase 20 Master Handoff: Bantu Voice LoRA Synthesis & Creator Cultural Micro-Gifting

> **Phase:** 20  
> **Codename:** `bantu-voice-and-creator-gifting`  
> **Working Directory:** `apps/vhunambi_client`  
> **Architecture Standard:** [`docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md)  
> **Spec Suite:** [`docs/phases/phase_20_bantu_voice_and_creator_gifting/`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_20_bantu_voice_and_creator_gifting/)  
> **Baseline:** `dart analyze` = 0 issues; `flutter test` = 100% passing (foundation + regression suites passing).  

---

## 1. Executive Summary & Accomplished Foundation

The Lead Architect (Antigravity) has authored the full specification suite and established the robust domain and state management foundation for Phase 20:

1. **Track A — Bantu Voice LoRA Synthesis**:
   - `BantuVoiceProfile` and the 5 canonical profiles (`kBantuVoiceProfiles`):
     - 👴 `venda_folk_elder` (Tshivenḓa, Limpopo / Makhado, 0.90 LoRA scale)
     - 🎤 `soweto_soul_lead` (isiZulu / English, Gauteng / Soweto, 0.85 LoRA scale)
     - ⚡ `durban_gqom_chanter` (isiZulu, KwaZulu-Natal / Durban, 0.92 LoRA scale)
     - 🌿 `maskandi_bard` (isiZulu, KwaZulu-Natal / Tugela, 0.88 LoRA scale)
     - ✨ `limpopo_pop_queen` (Tshivenḓa / Sepedi, Limpopo / Polokwane, 0.86 LoRA scale)
   - `DialectInflectionConfig` with 4 parameters:
     - `vowelElongation` (0.0 to 1.0, penultimate syllable stretch)
     - `vibratoDepth` (0.0 to 1.0, ancestral chest cavity resonance)
     - `callAndResponseIntensity` (0.0 to 1.0, choir backing)
     - `adLibFrequency` (0.0 to 1.0, cultural shouts/interjections)
   - `StudioFormState` and `StudioFormNotifier` wired with `selectedVoiceProfile`, `dialectInflection`, `setBantuVoiceProfile`, `updateDialectInflection`, and `toSongMetadataDna` embedding LoRA data.
   - Comprehensive unit tests: `test/features/studio/bantu_voice_profile_test.dart` (100% passing).

2. **Track B — Creator Cultural Micro-Gifting & Creator Wallet**:
   - `CulturalGift` and `kCulturalGifts` catalogue:
     - 🐚 Cowrie Shell / Mbaḓi (5 🪙 / R2.00)
     - 🥁 African Drum / Ngoma (15 🪙 / R5.00)
     - 🎹 Log Drum Trophy / Tshikona (50 🪙 / R15.00)
     - 👑 Royal Venda Crown / Khare (200 🪙 / R50.00)
   - `CreatorWalletState` and `CreatorWalletNotifier` (`creatorWalletProvider`):
     - Initial balance: 250 coins, R1,420.00 creator earnings, 4,750 coins received.
     - `sendGift`: Deducts coins, credits creator ZAR/coins, adds transaction, and auto-posts celebratory comment announcement to `reelsCommentsProvider`.
     - `topUpCoins`: Increases coin balance.
     - `requestPayout`: Validates amount (>= R50, <= balance), deducts earnings, and logs status message.
   - `ReelComment` extended with `giftEmoji` and `giftName`.
   - Comprehensive unit tests: `test/features/social/creator_wallet_provider_test.dart` (100% passing).

---

## 2. Cline Implementation Assignments (Presentation Layer)

Cline is tasked with building the high-impact UI widgets and connecting them cleanly into the user experience.

### Task 1: `BantuVoiceDeck` & `LivePhoneticAlignmentPreview` (Studio Cockpit)
**Target File 1:** `lib/features/studio/presentation/widgets/bantu_voice_deck.dart`
- **Widget Hierarchy:**
  - Header: `"Bantu Voice LoRA Engine"` + badge `"5 Native Dialects"`.
  - Horizontal scrolling / Wrap list of timbre selector cards (`_TimbreCard`):
    - Shows `iconEmoji`, `name`, `language`, `region`, and active glowing border (`AppColors.gold` / `AppColors.brandGoldLight`).
    - Tapping dispatches `ref.read(studioFormProvider.notifier).setBantuVoiceProfile(profile)`.
  - Dialect Inflection Sliders:
    - 4 smooth sliders using `AppColors.primary` & `AppColors.gold`:
      1. Syllable Stretch (Penultimate Vowel Elongation)
      2. Ancestral Vibrato Depth
      3. Call-and-Response Choir Backing
      4. Cultural Ad-Lib Frequency
    - Tapping or dragging updates `ref.read(studioFormProvider.notifier).updateDialectInflection(...)`.

**Target File 2:** `lib/features/studio/presentation/widgets/live_phonetic_alignment_preview.dart`
- **Purpose:** Displays live lyric phonetic analysis chips before generation.
- **Phonetic Highlighting Engine:**
  - Identifies Venda dental consonants: `ḓ`, `ṱ`, `ṋ`, `ḽ` (highlighted in gold pill with tooltip "Venda Dental Consonant").
  - Identifies Nguni click consonants: `c`, `q`, `x` (highlighted in cyan/emerald pill with tooltip "Nguni Click Consonant").
  - Highlights penultimate syllable vowels in bold accent to show the elongation rhythm.

**Mounting:**
- Mount `BantuVoiceDeck` into `lib/features/studio/presentation/views/create_studio_view.dart` inside the vocal configuration section.

---

### Task 2: `CreatorTippingSheet` & Action Rail Wiring (Reels Player)
**Target File 1:** `lib/features/social/presentation/widgets/creator_tipping_sheet.dart`
- **Presentation:** Modal bottom sheet opened via `CreatorTippingSheet.show(BuildContext context, {required PublishedClip clip})`.
- **UI Elements:**
  - Drag handle + header: `"Support @${clip.creatorUsername}"` + coin balance pill (`"🪙 ${state.userCoinsBalance}"`).
  - 2x2 Grid of Cultural Gifts:
    - Cards displaying `emoji`, `name`, `"${gift.coinPrice} 🪙 (R${gift.zarPrice})"`, and brief `culturalMeaning`.
    - Active selection state with golden border and elevation.
  - Optional custom message `TextField` (`"Leave an encouraging praise note..."`).
  - Send Gift Button:
    - Displays `"Send ${selectedGift.name} (${selectedGift.coinPrice} 🪙)"`.
    - Tapping calls `ref.read(creatorWalletProvider.notifier).sendGift(...)`.
    - Shows celebration feedback (`SnackBar` / animated particle toast: `"Sent 👑 Royal Venda Crown to @creator!"`).
    - Closes bottom sheet smoothly.

**Target File 2:** Wire in `lib/features/social/presentation/widgets/kinetic_reels_modal.dart`
- In `_ActionRail`, locate the Tip button (`Icons.monetization_on_rounded`).
- Replace `onTap: () {}` with:
  ```dart
  onTap: () {
    CreatorTippingSheet.show(context, clip: clip);
  }
  ```

---

### Task 3: `CreatorWalletDeck` (Profile Views)
**Target File 1:** `lib/features/profile/presentation/widgets/creator_wallet_deck.dart`
- **UI Elements:**
  - Earnings Overview:
    - Lifetime Earnings in ZAR (`R1,420.00`) with African sunrise gradient background.
    - Cultural Coins Received (`4,750 🪙`).
  - Payout Action Button:
    - `"Request Payout (Ozow / Capitec Pay / EFT)"`.
    - Tapping opens a quick payout dialog to cash out royalties.
  - Top Supporters Leaderboard:
    - Lists top 4 patrons: rank medal (`🥇`, `🥈`, `🥉`), username, total coins, and top gift emoji (`👑`, `🎹`, `🥁`).
  - Recent Gift Feed:
    - Compact cards showing recent gifts received with timestamp and supporter message.

**Mounting:**
- Mount `CreatorWalletDeck` in `apps/vhunambi_client/lib/features/profile/presentation/views/artist_profile_view.dart` and/or `owner_profile_view.dart` as a tab or card section.

---

### Task 4: Widget Tests
1. **`test/features/studio/bantu_voice_deck_test.dart`**:
   - Renders 5 timbre profile cards.
   - Tapping changes selected profile in `studioFormProvider`.
   - Modifying sliders updates dialect inflection state.
2. **`test/features/social/creator_tipping_sheet_test.dart`**:
   - Opens sheet and renders 4 cultural gifts.
   - Selecting a gift and tapping send triggers `sendGift` and deducts coins.
3. **`test/features/profile/creator_wallet_deck_test.dart`**:
   - Renders lifetime earnings and top supporter ranks.
   - Payout button triggers payout method selection.

---

## 3. Strict Quality Invariants

- **Token Discipline**: Use `AppColors`, `AppRadius`, `AppTypography`, `AppSpacing`. Never hardcode raw hex colors (`0xFF...`).
- **Responsive Layout**: Wrap small metrics in `FittedBox` or `Wrap` to ensure zero `RenderFlex` overflow on 360px mobile viewports.
- **Hydration & Animation Safety**: When using animations, avoid indefinite repeating timers in test environments or wrap in appropriate lifecycle controllers.
- **Verification Rule**: Before completing, ensure `dart analyze` reports **0 issues** and `flutter test` passes **100%**.
