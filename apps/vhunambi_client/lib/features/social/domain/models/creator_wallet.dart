import 'package:flutter/foundation.dart';
import 'package:vhunambi_client/features/social/domain/models/cultural_gift.dart';

/// Represents a top community supporter on a creator's tipping leaderboard (REQ-WAL-01).
@immutable
class SupporterRank {
  final String username;
  final String displayName;
  final int totalCoins;
  final double totalZar;
  final String topGiftEmoji;
  final int rank;

  const SupporterRank({
    required this.username,
    required this.displayName,
    required this.totalCoins,
    required this.totalZar,
    required this.topGiftEmoji,
    required this.rank,
  });

  Map<String, dynamic> toJson() => {
    'username': username,
    'displayName': displayName,
    'totalCoins': totalCoins,
    'totalZar': totalZar,
    'topGiftEmoji': topGiftEmoji,
    'rank': rank,
  };

  factory SupporterRank.fromJson(Map<String, dynamic> json) {
    return SupporterRank(
      username: json['username'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      totalCoins: (json['totalCoins'] as num?)?.toInt() ?? 0,
      totalZar: (json['totalZar'] as num?)?.toDouble() ?? 0.0,
      topGiftEmoji: json['topGiftEmoji'] as String? ?? '🐚',
      rank: (json['rank'] as num?)?.toInt() ?? 1,
    );
  }
}

/// Ledger entry for a cultural micro-gift tip sent to a creator (REQ-GFT-02, REQ-WAL-01).
@immutable
class GiftTransaction {
  final String id;
  final String clipId;
  final String senderUsername;
  final String recipientCreatorId;
  final CulturalGift gift;
  final String? message;
  final DateTime timestamp;

  const GiftTransaction({
    required this.id,
    required this.clipId,
    required this.senderUsername,
    required this.recipientCreatorId,
    required this.gift,
    this.message,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'clipId': clipId,
    'senderUsername': senderUsername,
    'recipientCreatorId': recipientCreatorId,
    'gift': gift.toJson(),
    if (message != null) 'message': message,
    'timestamp': timestamp.toIso8601String(),
  };

  factory GiftTransaction.fromJson(Map<String, dynamic> json) {
    return GiftTransaction(
      id: json['id'] as String? ?? '',
      clipId: json['clipId'] as String? ?? '',
      senderUsername: json['senderUsername'] as String? ?? 'listener',
      recipientCreatorId: json['recipientCreatorId'] as String? ?? '',
      gift: json['gift'] != null
          ? CulturalGift.fromJson(json['gift'] as Map<String, dynamic>)
          : kCulturalGifts.first,
      message: json['message'] as String?,
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// Creator financial balance, lifetime coins, and tipping ledger (REQ-WAL-01).
@immutable
class CreatorWallet {
  final String creatorId;
  final double balanceZar;
  final int? balanceCoins;
  final int totalCoinsReceived;
  final List<SupporterRank> topSupporters;
  final List<GiftTransaction> recentTransactions;

  const CreatorWallet({
    required this.creatorId,
    this.balanceZar = 0.0,
    this.balanceCoins,
    this.totalCoinsReceived = 0,
    this.topSupporters = const [],
    this.recentTransactions = const [],
  });

  CreatorWallet copyWith({
    String? creatorId,
    double? balanceZar,
    int? balanceCoins,
    int? totalCoinsReceived,
    List<SupporterRank>? topSupporters,
    List<GiftTransaction>? recentTransactions,
  }) {
    return CreatorWallet(
      creatorId: creatorId ?? this.creatorId,
      balanceZar: balanceZar ?? this.balanceZar,
      balanceCoins: balanceCoins ?? this.balanceCoins,
      totalCoinsReceived: totalCoinsReceived ?? this.totalCoinsReceived,
      topSupporters: topSupporters ?? this.topSupporters,
      recentTransactions: recentTransactions ?? this.recentTransactions,
    );
  }

  Map<String, dynamic> toJson() => {
    'creatorId': creatorId,
    'balanceZar': balanceZar,
    if (balanceCoins != null) 'balanceCoins': balanceCoins,
    'totalCoinsReceived': totalCoinsReceived,
    'topSupporters': topSupporters.map((s) => s.toJson()).toList(),
    'recentTransactions': recentTransactions.map((tx) => tx.toJson()).toList(),
  };

  factory CreatorWallet.fromJson(Map<String, dynamic> json) {
    return CreatorWallet(
      creatorId: json['creatorId'] as String? ?? '',
      balanceZar: (json['balanceZar'] as num?)?.toDouble() ?? 0.0,
      balanceCoins:
          ((json['balanceCoins'] ?? json['coinsBalance']) as num?)?.toInt(),
      totalCoinsReceived: (json['totalCoinsReceived'] as num?)?.toInt() ?? 0,
      topSupporters:
          (json['topSupporters'] as List<dynamic>?)
              ?.map((e) => SupporterRank.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      recentTransactions:
          (json['recentTransactions'] as List<dynamic>?)
              ?.map((e) => GiftTransaction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

/// Canonical ZAR coin top-up SKU returned by `/api/payments/payfast/packs` (`Phase 63`).
@immutable
class PayFastCoinPack {
  final String packId;
  final String label;
  final double amountZar;
  final int coinsGranted;

  const PayFastCoinPack({
    required this.packId,
    required this.label,
    required this.amountZar,
    required this.coinsGranted,
  });

  factory PayFastCoinPack.fromJson(Map<String, dynamic> json) {
    return PayFastCoinPack(
      packId: json['packId']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      amountZar: (json['amountZar'] as num?)?.toDouble() ?? 0.0,
      coinsGranted: (json['coinsGranted'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Initiated PayFast ZAR checkout session returned by `/api/payments/payfast/checkout`.
@immutable
class PayFastCheckoutSession {
  final String checkoutId;
  final String creatorId;
  final String packId;
  final double amountZar;
  final int coinsToCredit;
  final String paymentUrl;
  final Map<String, String> formFields;
  final String signature;
  final String status;

  const PayFastCheckoutSession({
    required this.checkoutId,
    required this.creatorId,
    required this.packId,
    required this.amountZar,
    required this.coinsToCredit,
    required this.paymentUrl,
    this.formFields = const <String, String>{},
    this.signature = '',
    this.status = 'pending',
  });

  factory PayFastCheckoutSession.fromJson(Map<String, dynamic> json) {
    final rawFields = json['formFields'];
    final fields = <String, String>{};
    if (rawFields is Map) {
      rawFields.forEach((k, v) {
        fields[k.toString()] = v?.toString() ?? '';
      });
    }
    return PayFastCheckoutSession(
      checkoutId: json['checkoutId']?.toString() ?? '',
      creatorId: json['creatorId']?.toString() ?? 'creator_cern',
      packId: json['packId']?.toString() ?? '',
      amountZar: (json['amountZar'] as num?)?.toDouble() ?? 0.0,
      coinsToCredit:
          ((json['coinsToCredit'] ?? json['coinsGranted']) as num?)?.toInt() ??
          0,
      paymentUrl: json['paymentUrl']?.toString() ?? '',
      formFields: fields,
      signature: json['signature']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
    );
  }
}

/// Status or settlement response from `/api/payments/payfast/status/:id` or `sandbox-settle/:id`.
@immutable
class PayFastStatusSnapshot {
  final String checkoutId;
  final String creatorId;
  final String status;
  final bool settled;
  final bool idempotentReplay;
  final int coinsCredited;
  final int? walletBalanceCoins;
  final double? walletBalanceZar;
  final String? pfPaymentId;

  const PayFastStatusSnapshot({
    required this.checkoutId,
    required this.creatorId,
    required this.status,
    required this.settled,
    this.idempotentReplay = false,
    this.coinsCredited = 0,
    this.walletBalanceCoins,
    this.walletBalanceZar,
    this.pfPaymentId,
  });

  factory PayFastStatusSnapshot.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status']?.toString() ??
        ((json['settled'] == true) ? 'completed' : 'pending');
    return PayFastStatusSnapshot(
      checkoutId: json['checkoutId']?.toString() ?? '',
      creatorId: json['creatorId']?.toString() ?? 'creator_cern',
      status: statusStr,
      settled: json['settled'] == true || statusStr == 'completed',
      idempotentReplay: json['idempotentReplay'] == true,
      coinsCredited:
          ((json['coinsCredited'] ?? json['coinsGranted']) as num?)?.toInt() ??
          0,
      walletBalanceCoins:
          ((json['walletBalanceCoins'] ?? json['balanceCoins']) as num?)
              ?.toInt(),
      walletBalanceZar:
          ((json['walletBalanceZar'] ?? json['balanceZar']) as num?)
              ?.toDouble(),
      pfPaymentId: json['pfPaymentId']?.toString(),
    );
  }
}

/// Confirmation receipt after a creator requests a cashout payout (REQ-WAL-02 + Phase 59).
@immutable
class PayoutReceipt {
  final bool success;
  final String payoutId;
  final double remainingBalanceZar;
  final String status;
  final String? bankName;
  final String? branchCode;
  final String? maskedAccount;
  final PayoutGatewayRail paymentRail;
  final String? estimatedSettlement;
  final String? gatewayRef;
  final String? error;

  const PayoutReceipt({
    required this.success,
    required this.payoutId,
    required this.remainingBalanceZar,
    this.status = 'processing',
    this.bankName,
    this.branchCode,
    this.maskedAccount,
    this.paymentRail = PayoutGatewayRail.eft,
    this.estimatedSettlement,
    this.gatewayRef,
    this.error,
  });

  Map<String, dynamic> toJson() => {
    'success': success,
    'payoutId': payoutId,
    'remainingBalanceZar': remainingBalanceZar,
    'status': status,
    if (bankName != null) 'bankName': bankName,
    if (branchCode != null) 'branchCode': branchCode,
    if (maskedAccount != null) 'maskedAccount': maskedAccount,
    'paymentRail': paymentRail.wireId,
    if (estimatedSettlement != null) 'estimatedSettlement': estimatedSettlement,
    if (gatewayRef != null) 'gatewayRef': gatewayRef,
    if (error != null) 'error': error,
  };

  factory PayoutReceipt.fromJson(Map<String, dynamic> json) {
    return PayoutReceipt(
      success: json['success'] as bool? ?? false,
      payoutId: json['payoutId'] as String? ?? '',
      remainingBalanceZar:
          (json['remainingBalanceZar'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'processing',
      bankName: json['bankName'] as String?,
      branchCode: json['branchCode'] as String?,
      maskedAccount: json['maskedAccount'] as String?,
      paymentRail: PayoutGatewayRail.fromWire(json['paymentRail']?.toString()),
      estimatedSettlement: json['estimatedSettlement'] as String?,
      gatewayRef: json['gatewayRef'] as String?,
      error: json['error'] as String?,
    );
  }
}

/// Alias matching Phase 59 SA Gateway Clearance Receipt specification.
typedef PayoutClearanceReceipt = PayoutReceipt;

/// Supported South African clearing rails for creator royalty disbursements (Phase 59).
enum PayoutGatewayRail {
  capitecPay(
    wireId: 'capitec_pay',
    displayName: 'Capitec Pay',
    shortLabel: 'Capitec Pay',
    estimatedSettlement: 'Instant (< 60s)',
    isInstant: true,
  ),
  ozow(
    wireId: 'ozow',
    displayName: 'Ozow Instant EFT',
    shortLabel: 'Ozow',
    estimatedSettlement: 'Instant (< 60s)',
    isInstant: true,
  ),
  payFast(
    wireId: 'payfast',
    displayName: 'PayFast Instant',
    shortLabel: 'PayFast',
    estimatedSettlement: 'Instant (< 60s)',
    isInstant: true,
  ),
  eft(
    wireId: 'eft',
    displayName: 'Standard SA EFT',
    shortLabel: 'Standard EFT',
    estimatedSettlement: '1-2 Business Days (SARB EFT)',
    isInstant: false,
  );

  const PayoutGatewayRail({
    required this.wireId,
    required this.displayName,
    required this.shortLabel,
    required this.estimatedSettlement,
    required this.isInstant,
  });

  final String wireId;
  final String displayName;
  final String shortLabel;
  final String estimatedSettlement;
  final bool isInstant;

  static PayoutGatewayRail fromWire(String? raw) {
    final normalized = (raw ?? 'eft').trim().toLowerCase();
    for (final rail in PayoutGatewayRail.values) {
      if (rail.wireId == normalized || rail.name.toLowerCase() == normalized) {
        return rail;
      }
    }
    if (normalized.contains('capitec')) return PayoutGatewayRail.capitecPay;
    if (normalized.contains('ozow')) return PayoutGatewayRail.ozow;
    if (normalized.contains('payfast')) return PayoutGatewayRail.payFast;
    return PayoutGatewayRail.eft;
  }
}

/// Canonical South African bank metadata & universal branch routing (Phase 59).
@immutable
class SaBankOption {
  final String canonicalName;
  final String code;
  final String universalBranchCode;
  final bool supportsCapitecPay;
  final bool supportsOzow;
  final bool supportsPayFast;

  const SaBankOption({
    required this.canonicalName,
    required this.code,
    required this.universalBranchCode,
    this.supportsCapitecPay = false,
    this.supportsOzow = true,
    this.supportsPayFast = true,
  });

  factory SaBankOption.fromJson(Map<String, dynamic> json) {
    return SaBankOption(
      canonicalName: json['canonicalName'] as String? ?? '',
      code: json['code'] as String? ?? '',
      universalBranchCode: json['universalBranchCode'] as String? ?? '',
      supportsCapitecPay: json['supportsCapitecPay'] as bool? ?? false,
      supportsOzow: json['supportsOzow'] as bool? ?? true,
      supportsPayFast: json['supportsPayFast'] as bool? ?? true,
    );
  }
}

/// Authoritative South African clearing bank directory & alias lookup (Phase 59).
abstract final class SaBankRegistry {
  static const List<SaBankOption> banks = [
    SaBankOption(
      canonicalName: 'Capitec Bank',
      code: 'CAPITEC',
      universalBranchCode: '470010',
      supportsCapitecPay: true,
    ),
    SaBankOption(
      canonicalName: 'FNB',
      code: 'FNB',
      universalBranchCode: '250655',
    ),
    SaBankOption(
      canonicalName: 'Standard Bank',
      code: 'SBSA',
      universalBranchCode: '051001',
    ),
    SaBankOption(
      canonicalName: 'Nedbank',
      code: 'NEDBANK',
      universalBranchCode: '198765',
    ),
    SaBankOption(
      canonicalName: 'Absa Bank',
      code: 'ABSA',
      universalBranchCode: '632005',
    ),
    SaBankOption(
      canonicalName: 'TymeBank',
      code: 'TYME',
      universalBranchCode: '678910',
    ),
  ];

  static final Map<String, SaBankOption> _aliasMap = {
    'capitec': banks[0],
    'capitec bank': banks[0],
    'fnb': banks[1],
    'first national bank': banks[1],
    'standard bank': banks[2],
    'sbsa': banks[2],
    'nedbank': banks[3],
    'absa': banks[4],
    'absa bank': banks[4],
    'tymebank': banks[5],
    'tyme bank': banks[5],
  };

  /// Resolves a [SaBankOption] from canonical name or common alias (case-insensitive).
  static SaBankOption? lookupBank(String? bankName) {
    if (bankName == null) return null;
    return _aliasMap[bankName.trim().toLowerCase()];
  }

  /// Resolves the 6-digit universal branch code for [bankName] or alias.
  static String universalBranchCodeFor(String? bankName) {
    return lookupBank(bankName)?.universalBranchCode ?? '470010';
  }

  /// Returns whether [rail] is permitted for [bankName].
  static bool supportsRail(String? bankName, PayoutGatewayRail rail) {
    if (rail != PayoutGatewayRail.capitecPay) return true;
    return lookupBank(bankName)?.supportsCapitecPay ?? false;
  }
}

/// Banking & KYC verification details for creator royalty payouts (Phase 41 REQ-PAYOUT-MODEL-01).
@immutable
class CreatorBankingDetails {
  final String bankName;
  final String accountHolder;
  final String accountNumber;
  final String branchCode;
  final String payoutMethod;
  final PayoutGatewayRail paymentRail;

  const CreatorBankingDetails({
    required this.bankName,
    required this.accountHolder,
    required this.accountNumber,
    required this.branchCode,
    this.payoutMethod = 'EFT Direct',
    this.paymentRail = PayoutGatewayRail.eft,
  });

  String get maskedAccount {
    if (accountNumber.length <= 4) return accountNumber;
    return '•••• ${accountNumber.substring(accountNumber.length - 4)}';
  }

  Map<String, String> toJson() => {
    'bankName': bankName,
    'accountHolder': accountHolder,
    'accountNumber': accountNumber,
    'branchCode': branchCode,
    'payoutMethod': payoutMethod,
    'paymentRail': paymentRail.wireId,
  };

  factory CreatorBankingDetails.fromJson(Map<String, dynamic> json) {
    return CreatorBankingDetails(
      bankName: json['bankName']?.toString() ?? '',
      accountHolder: json['accountHolder']?.toString() ?? '',
      accountNumber: json['accountNumber']?.toString() ?? '',
      branchCode: json['branchCode']?.toString() ?? '',
      payoutMethod: json['payoutMethod']?.toString() ?? 'EFT Direct',
      paymentRail: PayoutGatewayRail.fromWire(json['paymentRail']?.toString()),
    );
  }
}

/// South African universal clearing codes for instant EFT routing.
const Map<String, String> kSouthAfricanUniversalBranchCodes = {
  'Capitec Bank': '470010',
  'FNB': '250655',
  'Standard Bank': '051001',
  'Nedbank': '198765',
  'Absa Bank': '632005',
  'TymeBank': '678910',
};
