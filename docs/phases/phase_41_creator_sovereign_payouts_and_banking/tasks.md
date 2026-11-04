# Phase 41 Tasks: Creator Sovereign Royalty Payouts & Banking KYC Sheet

- [ ] **Track A: Banking Data Models & Universal Clearing Codes**
  - [ ] **T-A1**: Define `CreatorBankingDetails` and `kSouthAfricanUniversalBranchCodes` in `creator_wallet.dart`.
  - [ ] **T-A2**: Add `requestBankingPayout` method to `CreatorWalletNotifier` in `creator_wallet_provider.dart`.

- [ ] **Track B: Sovereign Payout Modal Interface**
  - [ ] **T-B1**: Create `PayoutDetailsSheet` in `lib/features/profile/presentation/widgets/payout_details_sheet.dart` with validation for SA banks.
  - [ ] **T-B2**: Update `CreatorWalletDeck` in `creator_wallet_deck.dart` to open `PayoutDetailsSheet.show(context)` on cashout tap.

- [ ] **Track C: Universal Profile Avatar Navigation**
  - [ ] **T-C1**: Mount `VhunambiUserAvatarButton(size: 32)` in `LibraryAppBar` mobile row.

- [ ] **Track D: Verification & Quality**
  - [ ] **T-D1**: Author and pass `test/features/profile/phase41_creator_payouts_and_banking_test.dart`.
  - [ ] **T-D2**: Run `dart analyze lib test` → 0 issues.
  - [ ] **T-D3**: Run regression tests → 100% green.

