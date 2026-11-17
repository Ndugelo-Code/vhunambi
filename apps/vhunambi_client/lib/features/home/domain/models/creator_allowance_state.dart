import 'package:flutter/foundation.dart';

/// Immutable creator monthly generation allowance snapshot synchronized from
/// `GET /api/wallet/allowance` (Phase 67 M67.4) with local Hive warm-start.
@immutable
class CreatorAllowanceState {
  static const int defaultMonthlyFreeLimit = 10;

  final String creatorId;
  final String planTier;
  final int freeMonthlySongsLimit;
  final int freeMonthlySongsUsed;
  final int freeMonthlySongsRemaining;
  final DateTime? cycleResetAt;
  final bool isLoading;
  final bool isFromCache;

  const CreatorAllowanceState({
    required this.creatorId,
    this.planTier = 'free',
    this.freeMonthlySongsLimit = defaultMonthlyFreeLimit,
    this.freeMonthlySongsUsed = 0,
    this.freeMonthlySongsRemaining = defaultMonthlyFreeLimit,
    this.cycleResetAt,
    this.isLoading = false,
    this.isFromCache = false,
  });

  bool get isPaidUnlimited =>
      planTier.toLowerCase() != 'free' || freeMonthlySongsLimit < 0;

  bool get isLowQuota => !isPaidUnlimited && freeMonthlySongsRemaining <= 2;

  bool get isExhausted => !isPaidUnlimited && freeMonthlySongsRemaining <= 0;

  String get pillLabel =>
      isPaidUnlimited ? 'Pro' : '$freeMonthlySongsRemaining/$freeMonthlySongsLimit';

  factory CreatorAllowanceState.fromJson(
    Map<String, dynamic> json, {
    required String fallbackCreatorId,
    bool isFromCache = false,
  }) {
    final limit = (json['freeMonthlySongsLimit'] as num?)?.toInt() ??
        defaultMonthlyFreeLimit;
    final used =
        ((json['freeMonthlySongsUsed'] as num?)?.toInt() ?? 0).clamp(0, 999);
    final rawRemaining = (json['freeMonthlySongsRemaining'] as num?)?.toInt();
    final remaining = rawRemaining ?? (limit - used).clamp(0, limit);
    return CreatorAllowanceState(
      creatorId:
          (json['userId'] ?? json['creatorId'] ?? fallbackCreatorId).toString(),
      planTier: (json['planTier'] ?? 'free').toString(),
      freeMonthlySongsLimit: limit,
      freeMonthlySongsUsed: used,
      freeMonthlySongsRemaining: remaining,
      cycleResetAt: json['cycleResetAt'] != null
          ? DateTime.tryParse(json['cycleResetAt'].toString())
          : null,
      isLoading: false,
      isFromCache: isFromCache,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'creatorId': creatorId,
        'planTier': planTier,
        'freeMonthlySongsLimit': freeMonthlySongsLimit,
        'freeMonthlySongsUsed': freeMonthlySongsUsed,
        'freeMonthlySongsRemaining': freeMonthlySongsRemaining,
        if (cycleResetAt != null) 'cycleResetAt': cycleResetAt!.toIso8601String(),
      };

  CreatorAllowanceState copyWith({
    String? creatorId,
    String? planTier,
    int? freeMonthlySongsLimit,
    int? freeMonthlySongsUsed,
    int? freeMonthlySongsRemaining,
    DateTime? cycleResetAt,
    bool? isLoading,
    bool? isFromCache,
  }) {
    return CreatorAllowanceState(
      creatorId: creatorId ?? this.creatorId,
      planTier: planTier ?? this.planTier,
      freeMonthlySongsLimit:
          freeMonthlySongsLimit ?? this.freeMonthlySongsLimit,
      freeMonthlySongsUsed: freeMonthlySongsUsed ?? this.freeMonthlySongsUsed,
      freeMonthlySongsRemaining:
          freeMonthlySongsRemaining ?? this.freeMonthlySongsRemaining,
      cycleResetAt: cycleResetAt ?? this.cycleResetAt,
      isLoading: isLoading ?? this.isLoading,
      isFromCache: isFromCache ?? this.isFromCache,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreatorAllowanceState &&
          runtimeType == other.runtimeType &&
          creatorId == other.creatorId &&
          planTier == other.planTier &&
          freeMonthlySongsLimit == other.freeMonthlySongsLimit &&
          freeMonthlySongsUsed == other.freeMonthlySongsUsed &&
          freeMonthlySongsRemaining == other.freeMonthlySongsRemaining;

  @override
  int get hashCode => Object.hash(
        creatorId,
        planTier,
        freeMonthlySongsLimit,
        freeMonthlySongsUsed,
        freeMonthlySongsRemaining,
      );
}
