import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/collections/domain/models/collection_entity.dart';
import 'package:vhunambi_client/features/collections/domain/services/royalty_distribution_service.dart';

void main() {
  group('RoyaltyDistributionService', () {
    final now = DateTime(2026, 10, 31);

    test('splits 60/40 balanced collection with exact ZAR and Coins', () {
      final collection = CollectionEntity(
        id: 'col_amapiano_ep',
        title: 'Ze Amapiano EP',
        createdAt: now,
        updatedAt: now,
        participants: const [
          SplitParticipant(
            name: 'cern',
            role: 'Producer',
            sharePercent: 60.0,
            creatorId: 'creator_cern',
            handle: '@cern',
          ),
          SplitParticipant(
            name: 'Fifi',
            role: 'Vocalist',
            sharePercent: 40.0,
            creatorId: 'creator_fifi',
            handle: '@fifi',
          ),
        ],
      );

      final result = RoyaltyDistributionService.calculateSplit(
        collection: collection,
        grossZar: 150.0,
        grossCoins: 50,
      );

      expect(result.isBalanced, isTrue);
      expect(result.grossZar, equals(150.0));
      expect(result.grossCoins, equals(50));
      expect(result.distributions, hasLength(2));

      // cern: 60% of R150 = R90, 60% of 50 = 30 coins
      expect(result.distributions[0].participant.name, equals('cern'));
      expect(result.distributions[0].zarAmount, equals(90.0));
      expect(result.distributions[0].coinsAmount, equals(30));

      // Fifi: 40% of R150 = R60, 40% of 50 = 20 coins
      expect(result.distributions[1].participant.name, equals('Fifi'));
      expect(result.distributions[1].zarAmount, equals(60.0));
      expect(result.distributions[1].coinsAmount, equals(20));

      // Invariants: zero leakage
      expect(result.totalAllocatedZar, equals(150.0));
      expect(result.totalAllocatedCoins, equals(50));
    });

    test('reconciles 1-cent and remainder coin dust for 3-way split (33.33/33.33/33.34)', () {
      final collection = CollectionEntity(
        id: 'col_trio_ep',
        title: 'Tribal Trio',
        createdAt: now,
        updatedAt: now,
        participants: const [
          SplitParticipant(
            name: 'Producer A',
            role: 'Beatmaker',
            sharePercent: 33.34,
            creatorId: 'creator_a',
          ),
          SplitParticipant(
            name: 'Vocalist B',
            role: 'Vocals',
            sharePercent: 33.33,
            creatorId: 'creator_b',
          ),
          SplitParticipant(
            name: 'Engineer C',
            role: 'Mixing',
            sharePercent: 33.33,
            creatorId: 'creator_c',
          ),
        ],
      );

      // R100 gross split across 33.34% (R33.34), 33.33% (R33.33), 33.33% (R33.33)
      final result = RoyaltyDistributionService.calculateSplit(
        collection: collection,
        grossZar: 100.0,
        grossCoins: 10,
      );

      expect(result.isBalanced, isTrue);
      expect(result.distributions, hasLength(3));

      // Total must strictly equal gross amounts without rounding drift
      expect(result.totalAllocatedZar, equals(100.0));
      expect(result.totalAllocatedCoins, equals(10));
    });

    test('flags unbalanced split sheet and attributes 100% to primary contributor with warning', () {
      final collection = CollectionEntity(
        id: 'col_unbalanced',
        title: 'Unfinished EP',
        createdAt: now,
        updatedAt: now,
        participants: const [
          SplitParticipant(
            name: 'Leader',
            role: 'Producer',
            sharePercent: 50.0,
          ),
          SplitParticipant(
            name: 'Guest',
            role: 'Vocalist',
            sharePercent: 20.0,
          ),
        ],
      );

      final result = RoyaltyDistributionService.calculateSplit(
        collection: collection,
        grossZar: 200.0,
        grossCoins: 80,
      );

      expect(result.isBalanced, isFalse);
      expect(result.warningMessage, contains('Unbalanced split sheet (Total: 70.0%)'));
      expect(result.distributions, hasLength(1));
      expect(result.distributions.first.participant.name, equals('Leader'));
      expect(result.distributions.first.zarAmount, equals(200.0));
      expect(result.distributions.first.coinsAmount, equals(80));
    });

    test('handles empty participants collection safely', () {
      final collection = CollectionEntity(
        id: 'col_empty',
        title: 'Empty EP',
        createdAt: now,
        updatedAt: now,
        participants: const [],
      );

      final result = RoyaltyDistributionService.calculateSplit(
        collection: collection,
        grossZar: 50.0,
        grossCoins: 20,
      );

      expect(result.isBalanced, isFalse);
      expect(result.distributions, isEmpty);
      expect(result.warningMessage, contains('No participants defined'));
    });
  });
}

