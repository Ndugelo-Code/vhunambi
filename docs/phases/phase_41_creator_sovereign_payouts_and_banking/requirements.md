# Phase 41 Requirements: Creator Sovereign Royalty Payouts & Banking KYC Sheet

## Track A: Banking & KYC Data Models
- **REQ-PAYOUT-MODEL-01**: `CreatorWalletState` must support persisting optional verified `savedBankingDetails` (Bank Name, Account Holder Name, Masked Account Number, Branch Code, Payout Rail).
- **REQ-PAYOUT-VALID-02**: The banking form must enforce validation:
  - Account Holder Name: Non-empty, minimum 3 alphabetic characters.
  - Account Number: 8 to 11 digits numeric.
  - Withdrawal Amount: Validated against `state.creatorEarnedZar` with a minimum threshold of R50.00.

## Track B: Sovereign Payout Modal Interface
- **REQ-PAYOUT-UI-01**: Tapping "Cash Out Royalties" on `CreatorWalletDeck` (`Key('creator_wallet_cashout_btn')`) must open `PayoutDetailsSheet.show(context)`.
- **REQ-PAYOUT-UI-02**: `PayoutDetailsSheet` must provide:
  - Bank selector dropdown / choice chips for South Africa's major institutions: `Capitec Bank`, `FNB`, `Standard Bank`, `Nedbank`, `Absa`, `TymeBank`.
  - Input field for Account Holder Name (`Key('payout_account_holder_input')`).
  - Input field for Account Number (`Key('payout_account_number_input')`).
  - Auto-populated Universal Branch Code (`Key('payout_branch_code_input')`).
  - Confirm Cash Out button (`Key('payout_confirm_btn')`).

## Track C: State Dispatch & Live Notifications
- **REQ-PAYOUT-DISPATCH-01**: On successful submission:
  - Deduct the requested withdrawal amount from `state.creatorEarnedZar`.
  - Set `state.payoutStatusMessage` to `'Payout of R<amount> via <Bank> (Acc ending in <last4>) initiated!'`.
  - Add a `NotificationCategory.system` / `NotificationPriority.high` receipt to `notificationsProvider`.
  - Close the modal and show a confirmation SnackBar with `AppColors.brandPrimary`.

## Track D: Universal Avatar Navigation
- **REQ-NAV-AVATAR-01**: `LibraryAppBar` mobile row must include `VhunambiUserAvatarButton(size: 32)` to ensure consistent one-tap profile access across all 4 primary application tabs (Explore, Create, Library, Market).

## Track E: Quality & Verification
- **REQ-VERIF-01**: Unit/widget test suite `test/features/profile/phase41_creator_payouts_and_banking_test.dart` passes 100%.
- **REQ-VERIF-02**: `dart analyze lib test` passes with 0 issues.

