import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/marketplace/domain/models/marketplace_models.dart';
import 'package:vhunambi_client/features/marketplace/presentation/providers/marketplace_providers.dart';

void main() {
  group('Marketplace domain models', () {
    test('BeatListingEntity exposes bpm and credit price labels', () {
      final beat = _beat();

      expect(beat.bpmLabel, '112 BPM');
      expect(beat.priceLabel, '⚡ 5 Credits');
      expect(beat.previewDuration, const Duration(seconds: 180));
      expect(beat.licenseType, 'Non-Exclusive Commercial');
    });

    test('BeatListingEntity copyWith + equality cover every field', () {
      final beat = _beat();

      expect(beat, beat.copyWith());
      expect(beat.hashCode, beat.copyWith().hashCode);
      expect(beat.copyWith(bpm: 128).bpm, 128);
      expect(beat.copyWith(totalSales: 4).totalSales, 4);
      expect(beat.copyWith(bpm: 128) == beat, isFalse);
    });

    test('MarketplaceFilterState tracks and clears dimensions', () {
      const empty = MarketplaceFilterState();
      expect(empty.hasActiveFilters, isFalse);
      expect(empty.genre, MarketplaceFilterState.allGenres);

      final filtered = empty.copyWith(
        searchQuery: 'durban',
        genre: 'Gqom',
        minBpm: 100,
        maxBpm: 140,
        maxPriceCredits: 5,
      );
      expect(filtered.hasActiveFilters, isTrue);
      expect(filtered.minBpm, 100);

      final clearedBpm = filtered.copyWith(clearBpmRange: true);
      expect(clearedBpm.minBpm, isNull);
      expect(clearedBpm.maxBpm, isNull);
      expect(clearedBpm.maxPriceCredits, 5);

      expect(clearedBpm.copyWith(clearMaxPrice: true).maxPriceCredits, isNull);
      expect(filtered.cleared(), const MarketplaceFilterState());
      expect(filtered.copyWith(), filtered);
    });

    test('marketplace genre catalog mirrors the 12 curated genres', () {
      expect(marketplaceGenreCatalog.length, 12);
      expect(marketplaceGenreCatalog.first, 'Amapiano');
      expect(marketplaceGenreCatalog.last, 'Afro-Arabic');
    });
  });

  group('Seeded marketplace listings', () {
    test('seeds six African instrumentals inside the curated catalog', () {
      final allItems = MarketplaceBeatsNotifier().state;
      final beats = allItems
          .where((item) => item.assetCategory == MarketplaceAssetCategory.beats)
          .toList();

      expect(allItems.length, 11);
      expect(beats.length, 6);
      expect(
        beats.map((beat) => beat.title),
        containsAll([
          'Township Heat',
          'Durban Midnight Bass',
          'Zulu Acoustic Flow',
          'Soweto Sunset Groove',
          'Limpopo Log Drum Rush',
          'Lagos Afrobeat Horns',
        ]),
      );
      expect(beats.every((beat) => beat.priceInCredits == 5), isTrue);
      expect(beats.every((beat) => beat.stemZipUrl != null), isTrue);
      expect(beats.every((beat) => beat.previewAudioUrl.isNotEmpty), isTrue);
    });

    test('registerSale and markSoldExclusive update listing state', () {
      final notifier = MarketplaceBeatsNotifier();
      final before = notifier.state.first.totalSales;

      notifier.registerSale(notifier.state.first.id);
      expect(notifier.state.first.totalSales, before + 1);

      notifier.markSoldExclusive(
        beatId: notifier.state.first.id,
        buyerId: 'buyer_exclusive_1',
      );
      expect(notifier.state.first.isExclusiveSold, isTrue);
      expect(notifier.state.first.exclusiveBuyerId, 'buyer_exclusive_1');
      expect(
        filterBeats(beats: notifier.state)
            .any((b) => b.id == notifier.state.first.id),
        isFalse,
      );
    });

    test('provider tree exposes defaults for the marketplace surface', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(marketplaceCreditsProvider), 10);
      expect(container.read(marketplaceBeatsProvider).length, 11);
      expect(container.read(filteredBeatsProvider).length, 6);
      expect(
        container.read(marketplaceFilterProvider),
        const MarketplaceFilterState(),
      );

      container.read(marketplaceFilterProvider.notifier).state =
          const MarketplaceFilterState(genre: 'Amapiano');
      expect(container.read(filteredBeatsProvider).length, 2);
    });
  });

  group('filterBeats', () {
    final beats = MarketplaceBeatsNotifier().state;

    const allAmapiano = MarketplaceFilterState(genre: 'Amapiano');
    const gqomOnly = MarketplaceFilterState(genre: 'Gqom');
    const marabiOnly = MarketplaceFilterState(genre: 'Marabi');

    test('no filters returns every listing newest-first', () {
      final result = filterBeats(beats: beats);
      expect(result.length, 6);
      expect(result.first.title, 'Township Heat');
      expect(result.last.title, 'Lagos Afrobeat Horns');
    });

    test('genre filter scopes the listing set', () {
      expect(filterBeats(beats: beats, filter: allAmapiano).length, 2);
      expect(
        filterBeats(beats: beats, filter: gqomOnly).single.title,
        'Durban Midnight Bass',
      );
      expect(filterBeats(beats: beats, filter: marabiOnly), isEmpty);
    });

    test('BPM range filter bounds the tempo window', () {
      final midTempo = filterBeats(
        beats: beats,
        filter: const MarketplaceFilterState(minBpm: 110, maxBpm: 115),
      );
      expect(
        midTempo.map((beat) => beat.title),
        ['Township Heat', 'Zulu Acoustic Flow', 'Limpopo Log Drum Rush'],
      );
      expect(
        filterBeats(
          beats: beats,
          filter: const MarketplaceFilterState(minBpm: 125),
        ).single.title,
        'Durban Midnight Bass',
      );
    });

    test('credit price cap filter enforces the ceiling', () {
      expect(
        filterBeats(
          beats: beats,
          filter: const MarketplaceFilterState(maxPriceCredits: 4),
        ),
        isEmpty,
      );
      expect(
        filterBeats(
          beats: beats,
          filter: const MarketplaceFilterState(maxPriceCredits: 5),
        ).length,
        6,
      );
    });

    test('search matches titles, producers, handles and genres', () {
      expect(
        filterBeats(
          beats: beats,
          filter: const MarketplaceFilterState(searchQuery: 'LAGOS'),
        ).single.title,
        'Lagos Afrobeat Horns',
      );
      expect(
        filterBeats(
          beats: beats,
          filter: const MarketplaceFilterState(searchQuery: 'sipho'),
        ).length,
        1,
      );
      expect(
        filterBeats(
          beats: beats,
          filter: const MarketplaceFilterState(searchQuery: '@lerato_prod'),
        ).length,
        1,
      );
      expect(
        filterBeats(
          beats: beats,
          filter: const MarketplaceFilterState(searchQuery: 'maskandi'),
        ).length,
        1,
      );
      expect(
        filterBeats(
          beats: beats,
          filter: const MarketplaceFilterState(searchQuery: 'zzzz'),
        ),
        isEmpty,
      );
    });

    test('combined filters intersect every dimension', () {
      final result = filterBeats(
        beats: beats,
        filter: const MarketplaceFilterState(
          genre: 'Amapiano',
          minBpm: 113,
          maxBpm: 120,
        ),
      );
      expect(result.single.title, 'Limpopo Log Drum Rush');
    });
  });
}

BeatListingEntity _beat({
  String id = 'beat_test',
  String title = 'Test Beat',
  String genre = 'Amapiano',
  int bpm = 112,
  int priceInCredits = 5,
  int totalSales = 0,
}) {
  return BeatListingEntity(
    id: id,
    title: title,
    producerId: 'producer_test',
    producerName: 'Test Producer',
    producerHandle: '@test_producer',
    genre: genre,
    bpm: bpm,
    musicalKey: 'F# Minor',
    priceInCredits: priceInCredits,
    previewAudioUrl: 'https://cdn.vhunambi.com/beats/$id.mp3',
    totalSales: totalSales,
    createdAt: DateTime(2026, 1, 1),
  );
}
