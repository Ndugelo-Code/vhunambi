# Phase 41 Design: Creator Sovereign Royalty Payouts & Banking KYC Sheet

## §1. Banking Model & Universal Branch Directory
```dart
@immutable
class CreatorBankingDetails {
  final String bankName;
  final String accountHolder;
  final String accountNumber;
  final String branchCode;
  final String payoutMethod;

  const CreatorBankingDetails({
    required this.bankName,
    required this.accountHolder,
    required this.accountNumber,
    required this.branchCode,
    this.payoutMethod = 'EFT Direct',
  });

  String get maskedAccount {
    if (accountNumber.length <= 4) return accountNumber;
    return '•••• ' + accountNumber.substring(accountNumber.length - 4);
  }
}

const Map<String, String> kSouthAfricanUniversalBranchCodes = {
  'Capitec Bank': '470010',
  'FNB': '250655',
  'Standard Bank': '051001',
  'Nedbank': '198765',
  'Absa Bank': '632005',
  'TymeBank': '678910',
};
```

---

## §2. Payout Details Sheet Widget Hierarchy
```
PayoutDetailsSheet (ConsumerStatefulWidget)
 └── Container (Rounded Top, AppColors.surfaceElevatedOf(context))
      └── SingleChildScrollView
           ├── Drag Handle (44x4dp)
           ├── Header: 'Cash Out Creator Royalties' (Icon: PhosphorIconsRegular.bank)
           ├── Available Balance Chip: 'Available: R1,420.00'
           ├── Form Fields:
           │    ├── Bank Dropdown / Chips (Standard Bank, FNB, Capitec, etc.)
           │    ├── Account Holder Input (Key: 'payout_account_holder_input')
           │    ├── Account Number Input (Key: 'payout_account_number_input')
           │    └── Branch Code Input (Key: 'payout_branch_code_input')
           └── Confirm Button (Key: 'payout_confirm_btn')
```

---

## §3. Wallet Provider Integration
```dart
Future<bool> requestBankingPayout({
  required double amountZar,
  required CreatorBankingDetails bankingDetails,
}) async {
  if (amountZar < 50.0 || amountZar > state.creatorEarnedZar) {
    return false;
  }

  final statusMsg =
      'Payout of R${amountZar.toStringAsFixed(2)} to ${bankingDetails.bankName} (${bankingDetails.maskedAccount}) initiated!';

  state = state.copyWith(
    creatorEarnedZar: state.creatorEarnedZar - amountZar,
    payoutStatusMessage: statusMsg,
  );

  _ref.read(notificationsProvider.notifier).addNotification(
    NotificationEntity(
      id: 'notif_payout_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Royalty Payout Initiated',
      message: statusMsg,
      category: NotificationCategory.system,
      priority: NotificationPriority.high,
      createdAt: DateTime.now(),
    ),
  );

  return true;
}
```

