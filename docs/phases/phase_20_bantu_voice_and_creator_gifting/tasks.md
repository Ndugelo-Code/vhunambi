# Phase 20 · Tasks — Bantu Voice LoRA Synthesis & Creator Cultural Micro-Gifting

> **Phase:** 20  
> **Codename:** `bantu-voice-and-creator-gifting`  
> **Status:** 🟡 IN PROGRESS  
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
- [ ] Implement `BantuVoiceDeck` in `lib/features/studio/presentation/widgets/bantu_voice_deck.dart`.
- [ ] Implement `LivePhoneticAlignmentPreview` in `lib/features/studio/presentation/widgets/live_phonetic_alignment_preview.dart`.
- [ ] Mount the deck in `CreateStudioView` / Studio cockpit.
- **Verification**: Widget tests verifying voice card selection, slider value updates, and phonetic highlighting.

### T3: Track B — Cultural Micro-Gift Domain & Wallet Provider
- [x] Implement `CulturalGift` in `lib/features/social/domain/models/cultural_gift.dart`.
- [x] Implement `CreatorWalletNotifier` & `creatorWalletProvider` in `lib/features/social/presentation/providers/creator_wallet_provider.dart`.
- [x] Wire gift sending to post an announcement comment in `reelsCommentsProvider`.
- [x] **Verification**: Unit tests for wallet balance deductions and gift ledger crediting (`creator_wallet_provider_test.dart` passing).

### T4: Track B — Creator Tipping Sheet & Reel Action Rail Wire-Up
- [ ] Implement `CreatorTippingSheet` in `lib/features/social/presentation/widgets/creator_tipping_sheet.dart`.
- [ ] Wire the Tip button in `KineticReelsModal` (`_ActionRail`) to launch `CreatorTippingSheet.show(context, clip: clip)`.
- **Verification**: Widget tests for tipping sheet display, gift selection, and transaction trigger.

### T5: Track B — Creator Wallet Deck in Profile Views
- [ ] Implement `CreatorWalletDeck` in `lib/features/profile/presentation/widgets/creator_wallet_deck.dart`.
- [ ] Mount the deck in `OwnerProfileView` and `ArtistProfileView`.
- **Verification**: Widget tests verifying earnings metrics and payout button.

### T6: Verification, Static Analysis & Documentation
- [ ] Run `flutter analyze` ensuring 0 issues (`No issues found!`).
- [ ] Run all targeted `flutter test` suites ensuring 100% pass rate.
- [ ] Commit atomically on `main` with standard conventional commit message.
- [ ] Update `docs/AGENT_HANDOFF_BIBLE.md` and `README.md`.
