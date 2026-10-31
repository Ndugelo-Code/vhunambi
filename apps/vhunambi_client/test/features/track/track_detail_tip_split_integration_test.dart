import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/theme/app_theme.dart';
import 'package:vhunambi_client/features/collections/data/repositories/in_memory_collection_repository.dart';
import 'package:vhunambi_client/features/collections/domain/models/collection_entity.dart';
import 'package:vhunambi_client/features/collections/presentation/providers/collections_provider.dart';
import 'package:vhunambi_client/features/social/presentation/providers/creator_wallet_provider.dart';
import 'package:vhunambi_client/features/track/presentation/views/track_detail_view.dart';
import 'package:vhunambi_client/features/track/presentation/widgets/track_actions_bar.dart';

void main() {
  testWidgets('Tipping a track belonging to a collection splits payout across collaborators',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final now = DateTime(2026, 10, 31);
    final repo = InMemoryCollectionRepository(
      seed: [
        CollectionEntity(
          id: 'col_amapiano_split',
          title: 'Ze Amapiano EP',
          trackIds: const ['seed-01'], // Matches trackId
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
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        collectionRepositoryProvider.overrideWithValue(repo),
      ],
    );

    // Initial load of collections
    await container.read(collectionsProvider.notifier).loadCollections();

    // Check initial user coin balance
    final initialBalance = container.read(creatorWalletProvider).userCoinsBalance;
    expect(initialBalance, greaterThanOrEqualTo(50));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const TrackDetailView(trackId: 'seed-01'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Open Tip modal
    final tipButton = find.descendant(
      of: find.byType(TrackActionsBar),
      matching: find.text('Tip'),
    );
    expect(tipButton, findsOneWidget);
    await tester.tap(tipButton);
    await tester.pumpAndSettle();

    // Modal is open, shows split sheet attribution
    expect(find.textContaining('Split Sheet: Ze Amapiano EP (2 Collaborators)'), findsOneWidget);

    // 2. Tap 50 credits tip
    final fiftyCreditsBtn = find.text('50');
    expect(fiftyCreditsBtn, findsOneWidget);
    await tester.tap(fiftyCreditsBtn);
    await tester.pumpAndSettle();

    // 3. User balance debited by 50
    final updatedState = container.read(creatorWalletProvider);
    expect(updatedState.userCoinsBalance, equals(initialBalance - 50));

    // 4. Gross earnings increased (50 coins = R15 ZAR at standard tokenomics)
    expect(updatedState.creatorReceivedCoins, greaterThanOrEqualTo(50));

    // 5. Transactions ledger received split entries for both collaborators
    final splitTransactions = updatedState.transactions
        .where((t) => t.clipId == 'seed-01')
        .toList();
    expect(splitTransactions, hasLength(2));

    final producerTx = splitTransactions.firstWhere((t) => t.recipientCreatorId == 'creator_cern');
    expect(producerTx.gift.coinPrice, equals(30)); // 60% of 50
    expect(producerTx.gift.zarPrice, equals(9.0));  // 60% of R15

    final vocalistTx = splitTransactions.firstWhere((t) => t.recipientCreatorId == 'creator_fifi');
    expect(vocalistTx.gift.coinPrice, equals(20)); // 40% of 50
    expect(vocalistTx.gift.zarPrice, equals(6.0));  // 40% of R15

    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}
