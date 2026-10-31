import 'package:flutter/foundation.dart';
import '../models/collection_entity.dart';

/// Single collaborator payout allocation calculated by the royalty distribution engine (REQ-ROY-SPLIT-02, 03).
@immutable
class SplitShareDistribution {
  final SplitParticipant participant;
  final double zarAmount;
  final int coinsAmount;

  const SplitShareDistribution({
    required this.participant,
    required this.zarAmount,
    required this.coinsAmount,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SplitShareDistribution &&
          runtimeType == other.runtimeType &&
          participant == other.participant &&
          zarAmount == other.zarAmount &&
          coinsAmount == other.coinsAmount;

  @override
  int get hashCode => Object.hash(participant, zarAmount, coinsAmount);

  @override
  String toString() =>
      'SplitShareDistribution(name: ${participant.name}, share: ${participant.shareLabel}, zar: R${zarAmount.toStringAsFixed(2)}, coins: $coinsAmount)';
}

/// Comprehensive outcome of a royalty split calculation.
@immutable
class RoyaltyDistributionResult {
  final bool isBalanced;
  final double grossZar;
  final int grossCoins;
  final List<SplitShareDistribution> distributions;
  final String? warningMessage;

  const RoyaltyDistributionResult({
    required this.isBalanced,
    required this.grossZar,
    required this.grossCoins,
    required this.distributions,
    this.warningMessage,
  });

  /// Total ZAR allocated across all collaborator distributions.
  double get totalAllocatedZar =>
      distributions.fold<double>(0.0, (sum, d) => sum + d.zarAmount);

  /// Total Cultural Coins allocated across all collaborator distributions.
  int get totalAllocatedCoins =>
      distributions.fold<int>(0, (sum, d) => sum + d.coinsAmount);
}

/// Core financial engine that splits track earnings (tips, beat licenses, streaming)
/// across project collaborators in strict accordance with the signed Split Sheet.
class RoyaltyDistributionService {
  const RoyaltyDistributionService._();

  /// Calculates proportional ZAR and Cultural Coin allocations for [collection].
  ///
  /// Guarantees:
  /// 1. Mathematical conservation: sum(allocatedZar) == grossZar (zero 1-cent leakage).
  /// 2. Integer coin conservation: sum(allocatedCoins) == grossCoins.
  /// 3. If the split sheet is not balanced (|sum - 100| > 0.01), [isBalanced] is false
  ///    and [distributions] attributes 100% to the project owner/first participant
  ///    with a descriptive warning to prevent financial stalling.
  static RoyaltyDistributionResult calculateSplit({
    required CollectionEntity collection,
    double grossZar = 0.0,
    int grossCoins = 0,
  }) {
    final sanitizedZar = grossZar < 0 ? 0.0 : double.parse(grossZar.toStringAsFixed(2));
    final sanitizedCoins = grossCoins < 0 ? 0 : grossCoins;

    if (collection.participants.isEmpty) {
      return RoyaltyDistributionResult(
        isBalanced: false,
        grossZar: sanitizedZar,
        grossCoins: sanitizedCoins,
        distributions: const [],
        warningMessage: 'No participants defined on collection split sheet.',
      );
    }

    if (!collection.isSplitBalanced) {
      // Unbalanced split: 100% defaults to primary contributor with warning
      final primary = collection.participants.first;
      return RoyaltyDistributionResult(
        isBalanced: false,
        grossZar: sanitizedZar,
        grossCoins: sanitizedCoins,
        distributions: [
          SplitShareDistribution(
            participant: primary,
            zarAmount: sanitizedZar,
            coinsAmount: sanitizedCoins,
          ),
        ],
        warningMessage:
            'Unbalanced split sheet (Total: ${collection.totalSharePercent.toStringAsFixed(1)}%). 100% credited to ${primary.name}.',
      );
    }

    final distributions = <SplitShareDistribution>[];
    double allocatedZar = 0.0;
    int allocatedCoins = 0;

    for (int i = 0; i < collection.participants.length; i++) {
      final p = collection.participants[i];
      final factor = p.sharePercent / 100.0;

      final rawZar = double.parse((sanitizedZar * factor).toStringAsFixed(2));
      final rawCoins = (sanitizedCoins * factor).floor();

      allocatedZar += rawZar;
      allocatedCoins += rawCoins;

      distributions.add(SplitShareDistribution(
        participant: p,
        zarAmount: rawZar,
        coinsAmount: rawCoins,
      ));
    }

    // Residual dust reconciliation (eliminate 1-cent rounding drift and remainder coins)
    final diffZar = double.parse((sanitizedZar - allocatedZar).toStringAsFixed(2));
    final diffCoins = sanitizedCoins - allocatedCoins;

    if (distributions.isNotEmpty && (diffZar.abs() > 0.0001 || diffCoins > 0)) {
      final first = distributions.first;
      distributions[0] = SplitShareDistribution(
        participant: first.participant,
        zarAmount: double.parse((first.zarAmount + diffZar).toStringAsFixed(2)),
        coinsAmount: first.coinsAmount + diffCoins,
      );
    }

    return RoyaltyDistributionResult(
      isBalanced: true,
      grossZar: sanitizedZar,
      grossCoins: sanitizedCoins,
      distributions: List.unmodifiable(distributions),
    );
  }
}

