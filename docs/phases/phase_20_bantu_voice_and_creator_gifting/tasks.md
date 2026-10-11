# Phase 20 · Tasks — Bantu Voice LoRA Synthesis & Creator Cultural Micro-Gifting

> **Phase:** 20  
> **Codename:** `bantu-voice-and-creator-gifting`  
> **Status:** 🟢 COMPLETE  
> **Target Apps:** `apps/vhunambi_client`  
> **Standard:** Dual-Agent Pair Programming Standard ([`docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md))  

---

## Pre-Flight Check Matrix

- [x] Baseline static analysis passes with 0 issues (`flutter analyze`).
- [x] Baseline test suites pass 100% (77/77 tests passing).
- [x] Working tree is clean on `main` at `b7bdb1e`.

---

## Sequenced Implementation Tasks

### T1: Track A — Bantu Voice Domain Models & Providers
- [x] Implement `BantuVoiceProfile` in `lib/features/studio/domain/models/bantu_voice_profile.dart`.
- [x] Implement `DialectInflectionConfig` in `lib/features/studio/domain/models/bantu_voice_profile.dart`.
- [x] Extend `StudioFormState` and `StudioFormNotifier` with voice profile and inflection parameters.
- [x] **Verification**: Unit tests for voice profiles and form state serialization (`bantu_voice_profile_test.dart` passing).

### T2: Track A — Bantu Voice UI & Live Phonetic Preview
- [x] Implement `BantuVoiceDeck` in `lib/features/studio/presentation/widgets/bantu_voice_deck.dart`.
- [x] Implement `LivePhoneticAlignmentPreview` in `lib/features/studio/presentation/widgets/live_phonetic_alignment_preview.dart`.
- [x] Mount the deck in `StudioView` cockpit.
- [x] **Verification**: Widget tests verifying voice card selection, slider value updates, and phonetic highlighting (`bantu_voice_deck_test.dart` passing).

### T3: Track B — Cultural Micro-Gift Domain & Wallet Provider
- [x] Implement `CulturalGift` in `lib/features/social/domain/models/cultural_gift.dart`.
- [x] Implement `CreatorWalletNotifier` & `creatorWalletProvider` in `lib/features/social/presentation/providers/creator_wallet_provider.dart`.
- [x] Wire gift sending to post an announcement comment in `reelsCommentsProvider`.
- [x] **Verification**: Unit tests for wallet balance deductions and gift ledger crediting (`creator_wallet_provider_test.dart` passing).

### T4: Track B — Creator Tipping Sheet & Reel Action Rail Wire-Up
- [x] Implement `CreatorTippingSheet` in `lib/features/social/presentation/widgets/creator_tipping_sheet.dart`.
- [x] Wire the Tip button in `KineticReelsModal` (`_ActionRail`) to launch `CreatorTippingSheet.show(context, clip: clip)`.
- [x] **Verification**: Widget tests for tipping sheet display, gift selection, and transaction trigger (`creator_tipping_sheet_test.dart` passing).

### T5: Track B — Creator Wallet Deck in Profile Views
- [x] Implement `CreatorWalletDeck` in `lib/features/profile/presentation/widgets/creator_wallet_deck.dart`.
- [x] Mount the deck in `OwnerProfileView` for royalty cashout.
- [x] **Verification**: Widget tests verifying earnings metrics and payout button (`creator_wallet_deck_test.dart` passing).

### T6: Verification, Static Analysis & Documentation
- [x] Run `dart analyze apps/vhunambi_client` ensuring 0 issues (`No issues found!`).
- [x] Run all targeted `flutter test` suites ensuring 100% pass rate (84/84 test suites passing).
- [x] Commit atomically on `main` with standard conventional commit message.
- [x] Update `docs/AGENT_HANDOFF_BIBLE.md` and `README.md`.
