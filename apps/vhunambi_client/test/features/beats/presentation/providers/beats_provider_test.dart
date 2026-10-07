import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/beats/data/repositories/in_memory_beat_repository.dart';
import 'package:vhunambi_client/features/beats/domain/models/producer_beat_entity.dart';
import 'package:vhunambi_client/features/beats/presentation/providers/beats_provider.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/marketplace/presentation/providers/marketplace_providers.dart';

/// T12 — Beats vault provider suite (REQ-BEAT-24).
void main() {
  group('BeatsNotifier', () {
    test('loads the persisted vault newest-first', () async {
      final container = _container(
        seed: [
          _beat(id: 'beat_old', createdAt: DateTime(2026, 9, 1)),
          _beat(id: 'beat_new', createdAt: DateTime(2026, 9, 20)),
        ],
      );

      await container.read(beatsProvider.notifier).loadBeats();

      expect(
        container.read(beatsProvider).map((beat) => beat.id).toList(),
        equals(['beat_new', 'beat_old']),
      );
    });

    test('createBeat trims input and clamps the tempo into 40–260', () async {
      final container = _container(seed: const []);
      final notifier = container.read(beatsProvider.notifier);
      await notifier.loadBeats();

      final fast = await notifier.createBeat(
        title: '  Maputo Groove  ',
        genre: 'Afro House',
        bpm: 900,
        musicalKey: 'Eb Minor',
        tags: const ['Log Drum'],
        priceInCredits: 20,
      );
      final slow = await notifier.createBeat(
        title: 'Deep Kwaito',
        genre: 'Kwaito',
        bpm: 10,
      );

      expect(fast.title, equals('Maputo Groove'));
      expect(fast.bpm, 260);
      expect(slow.bpm, 40);
      expect(fast.id, startsWith('beat_'));
      expect(fast.previewAudioUrl, isEmpty);
      expect(container.read(beatsProvider), hasLength(2));
      expect(container.read(beatsProvider).first.id, equals(slow.id));
    });

    test('creating a published beat injects the marketplace listing',
        () async {
      final container = _container(seed: const []);
      final notifier = container.read(beatsProvider.notifier);
      await notifier.loadBeats();

      final beat = await notifier.createBeat(
        title: 'Pretoria Vibe',
        genre: 'Amapiano',
        bpm: 118,
        priceInCredits: 20,
        status: BeatStatus.published,
      );

      final listing = container
          .read(marketplaceBeatsProvider)
          .firstWhere((entry) => entry.id == beat.id);
      expect(listing.priceInCredits, 20);
      expect(listing.genre, equals('Amapiano'));
      expect(listing.licenseType, equals('Non-Exclusive Commercial'));
    });

    test('publishToMarket is idempotent and never duplicates the listing',
        () async {
      final container = _container(seed: [_beat()]);
      final notifier = container.read(beatsProvider.notifier);
      await notifier.loadBeats();

      final baseline = container.read(marketplaceBeatsProvider).length;

      await notifier.publishToMarket('beat_1');
      await notifier.publishToMarket('beat_1');

      expect(container.read(beatsProvider).single.isPublished, isTrue);
      expect(container.read(marketplaceBeatsProvider), hasLength(baseline + 1));
      expect(
        container
            .read(marketplaceBeatsProvider)
            .where((listing) => listing.id == 'beat_1'),
        hasLength(1),
      );
    });

    test('unpublishFromMarket reverts to draft and pulls the listing',
        () async {
      final container = _container(
        seed: [_beat(status: BeatStatus.published)],
      );
      final notifier = container.read(beatsProvider.notifier);
      await notifier.loadBeats();
      await notifier.publishToMarket('beat_1');

      await notifier.unpublishFromMarket('beat_1');

      expect(container.read(beatsProvider).single.isDraft, isTrue);
      expect(
        container
            .read(marketplaceBeatsProvider)
            .any((listing) => listing.id == 'beat_1'),
        isFalse,
      );
    });

    test('archive / restore transitions follow the state machine', () async {
      final container = _container(
        seed: [_beat(status: BeatStatus.published)],
      );
      final notifier = container.read(beatsProvider.notifier);
      await notifier.loadBeats();
      await notifier.publishToMarket('beat_1');

      await notifier.archiveBeat('beat_1');
      expect(container.read(beatsProvider).single.isArchived, isTrue);
      expect(
        container
            .read(marketplaceBeatsProvider)
            .any((listing) => listing.id == 'beat_1'),
        isFalse,
      );

      await notifier.restoreToDraft('beat_1');
      expect(container.read(beatsProvider).single.isDraft, isTrue);
    });

    test('deleteBeat removes the beat and its listing', () async {
      final container = _container(
        seed: [_beat(status: BeatStatus.published)],
      );
      final notifier = container.read(beatsProvider.notifier);
      await notifier.loadBeats();
      await notifier.publishToMarket('beat_1');

      await notifier.deleteBeat('beat_1');

      expect(container.read(beatsProvider), isEmpty);
      expect(
        container
            .read(marketplaceBeatsProvider)
            .any((listing) => listing.id == 'beat_1'),
        isFalse,
      );
    });

    test('recordSale appends a ledger entry and syncs the listing', () async {
      final container = _container(
        seed: [_beat(status: BeatStatus.published)],
      );
      final notifier = container.read(beatsProvider.notifier);
      await notifier.loadBeats();
      await notifier.publishToMarket('beat_1');

      await notifier.recordSale(
        'beat_1',
        '@kwaito_king',
        30,
        BeatLicenseTier.syncLicense,
      );

      final beat = container.read(beatsProvider).single;
      expect(beat.totalSales, 1);
      expect(beat.totalEarningsCredits, 30);
      expect(beat.salesRecords.single.buyerHandle, equals('@kwaito_king'));
      expect(beat.salesRecords.single.buyerId, equals('kwaito_king'));

      final listing = container
          .read(marketplaceBeatsProvider)
          .firstWhere((entry) => entry.id == 'beat_1');
      expect(listing.totalSales, 1);
    });

    test('recordAudition increments the preview counter', () async {
      final container = _container(seed: [_beat()]);
      final notifier = container.read(beatsProvider.notifier);
      await notifier.loadBeats();

      await notifier.recordAudition('beat_1');
      await notifier.recordAudition('beat_1');

      expect(container.read(beatsProvider).single.auditionCount, 2);
    });

    test('convertTrackToBeat maps the vault asset metadata', () async {
      final container = _container(seed: const []);
      final notifier = container.read(beatsProvider.notifier);
      await notifier.loadBeats();

      final beat = await notifier.convertTrackToBeat(
        _track(),
        bpm: 124,
        key: 'A Minor',
        price: 15,
      );

      expect(beat.trackId, equals('track_9'));
      expect(beat.title, equals('Township Log Drum Heat'));
      expect(beat.genre, equals('Amapiano'));
      expect(beat.bpm, 124);
      expect(beat.musicalKey, equals('A Minor'));
      expect(beat.priceInCredits, 15);
      expect(beat.isDraft, isTrue);
      expect(beat.previewAudioUrl, equals('https://cdn/track_9.mp3'));
      expect(beat.tags, equals(const ['Instrumental', 'Amapiano']));
    });

    test('mutations on an unknown beat are ignored', () async {
      final container = _container(seed: const []);
      final notifier = container.read(beatsProvider.notifier);
      await notifier.loadBeats();

      await notifier.publishToMarket('ghost');
      await notifier.recordSale('ghost', '@nobody', 10, BeatLicenseTier.syncLicense);
      await notifier.recordAudition('ghost');
      await notifier.deleteBeat('ghost');

      expect(container.read(beatsProvider), isEmpty);
      expect(notifier.beatById('ghost'), isNull);
    });
  });

  group('Beats vault projection', () {
    final soshanguve = _beat(
      id: 'beat_soshanguve',
      title: 'Soshanguve Pulse',
      genre: 'Amapiano',
      bpm: 112,
      key: 'F# Minor',
      status: BeatStatus.published,
      tags: const ['Log Drum', 'Soulful'],
      sales: [10, 10],
      createdAt: DateTime(2026, 9, 20),
    );
    final durban = _beat(
      id: 'beat_durban',
      title: 'Durban Midnight Rush',
      genre: 'Gqom',
      bpm: 128,
      key: 'C Major',
      status: BeatStatus.published,
      tags: const ['Dark Sub'],
      sales: [30],
      createdAt: DateTime(2026, 9, 10),
    );
    final sophiatown = _beat(
      id: 'beat_sophiatown',
      title: 'Sophiatown Bounce',
      genre: 'Kwaito',
      bpm: 106,
      key: 'A Minor',
      tags: const ['Vocal Chop'],
      createdAt: DateTime(2026, 9, 1),
    );

    List<ProducerBeatEntity> project(BeatsVaultFilterState filter) =>
        filterBeatsVault(
          beats: [soshanguve, durban, sophiatown],
          filter: filter,
        );

    test('free-text search spans title, genre, key, handle and tags', () {
      expect(
        project(const BeatsVaultFilterState(searchQuery: 'durban'))
            .single
            .id,
        equals('beat_durban'),
      );
      expect(
        project(const BeatsVaultFilterState(searchQuery: 'kwaito'))
            .single
            .id,
        equals('beat_sophiatown'),
      );
      expect(
        project(const BeatsVaultFilterState(searchQuery: 'f# minor'))
            .single
            .id,
        equals('beat_soshanguve'),
      );
      expect(
        project(const BeatsVaultFilterState(searchQuery: 'log drum'))
            .single
            .id,
        equals('beat_soshanguve'),
      );
      expect(project(const BeatsVaultFilterState(searchQuery: 'zzz')), isEmpty);
    });

    test('status and genre dimensions compose with the search scope', () {
      final published = project(
        const BeatsVaultFilterState(statusFilter: BeatStatus.published),
      );
      expect(published, hasLength(2));

      final drafts = project(
        const BeatsVaultFilterState(statusFilter: BeatStatus.draft),
      );
      expect(drafts.single.id, equals('beat_sophiatown'));

      final kwaitoPublished = project(
        const BeatsVaultFilterState(
          statusFilter: BeatStatus.published,
          genreFilter: 'Kwaito',
        ),
      );
      expect(kwaitoPublished, isEmpty);

      final gqom = project(const BeatsVaultFilterState(genreFilter: 'Gqom'));
      expect(gqom.single.id, equals('beat_durban'));

      expect(project(const BeatsVaultFilterState()), hasLength(3));
    });

    test('every ordering mode sorts as documented', () {
      expect(
        project(const BeatsVaultFilterState()).map((beat) => beat.id).toList(),
        equals(['beat_soshanguve', 'beat_durban', 'beat_sophiatown']),
      );
      expect(
        project(const BeatsVaultFilterState(sortOrder: BeatsSortOrder.bpmAsc))
            .map((beat) => beat.id)
            .toList(),
        equals(['beat_sophiatown', 'beat_soshanguve', 'beat_durban']),
      );
      expect(
        project(const BeatsVaultFilterState(sortOrder: BeatsSortOrder.bpmDesc))
            .first
            .id,
        equals('beat_durban'),
      );
      expect(
        project(const BeatsVaultFilterState(sortOrder: BeatsSortOrder.mostSales))
            .map((beat) => beat.id)
            .take(2)
            .toList(),
        equals(['beat_soshanguve', 'beat_durban']),
      );
      expect(
        project(
          const BeatsVaultFilterState(
            sortOrder: BeatsSortOrder.highestEarnings,
          ),
        ).first.id,
        equals('beat_durban'),
      );
      expect(
        project(const BeatsVaultFilterState(sortOrder: BeatsSortOrder.newest))
            .first
            .id,
        equals('beat_soshanguve'),
      );
    });

    test('BeatsVaultFilterState exposes activity and reset semantics', () {
      const idle = BeatsVaultFilterState();
      expect(idle.hasActiveFilters, isFalse);
      expect(
        idle
            .copyWith(searchQuery: 'amapiano')
            .copyWith(statusFilter: BeatStatus.draft)
            .copyWith(genreFilter: 'Kwaito')
            .hasActiveFilters,
        isTrue,
      );
      expect(
        idle
            .copyWith(statusFilter: BeatStatus.published)
            .copyWith(clearStatus: true)
            .hasActiveFilters,
        isFalse,
      );
      expect(
        idle.copyWith(genreFilter: 'Gqom', searchQuery: 'x').cleared(),
        equals(idle),
      );
      expect(BeatsSortOrder.values.map((order) => order.label).toList(),
          hasLength(5));
      expect(BeatsSortOrder.mostSales.label, equals('Most Sold'));
    });

    test('beatsVaultStatsFor aggregates the producer analytics', () {
      final stats = beatsVaultStatsFor([soshanguve, durban, sophiatown]);

      expect(stats.totalBeats, 3);
      expect(stats.publishedCount, 2);
      expect(stats.draftCount, 1);
      expect(stats.vaultOnlyCount, 1);
      expect(stats.totalSalesCount, 3);
      expect(stats.totalCreditsEarned, 50);
      expect(beatsVaultStatsFor(const []).totalBeats, 0);
    });

    test('beatListingFromEntity bridges into the marketplace model', () {
      final listing = beatListingFromEntity(
        _beat(status: BeatStatus.published, stems: true),
      );

      expect(listing.id, equals('beat_1'));
      expect(listing.licenseType, equals('Non-Exclusive Commercial'));
      expect(
        listing.stemZipUrl,
        equals('https://cdn.vhunambi.com/beats/stems/beat_1_stems.zip'),
      );

      final bareListing = beatListingFromEntity(_beat());
      expect(bareListing.stemZipUrl, isNull);
      expect(bareListing.totalSales, 0);
    });

    test('beatPreviewTrack always streams a 180 second instrumental', () {
      final track = beatPreviewTrack(_beat(title: 'Ekasi Nights'));

      expect(track.id, equals('beat_1'));
      expect(track.title, equals('Ekasi Nights'));
      expect(track.creatorHandle, equals('@you'));
      expect(track.language, equals('Instrumental'));
      expect(track.duration, equals(const Duration(seconds: 180)));
      expect(track.audioUrl, equals('https://cdn/beat_1.mp3'));
    });

    test('the vault projection reacts to the filter provider', () async {
      final container = _container(seed: [soshanguve, durban, sophiatown]);
      await container.read(beatsProvider.notifier).loadBeats();

      expect(container.read(filteredBeatsVaultProvider), hasLength(3));
      expect(container.read(beatsVaultStatsProvider).publishedCount, 2);

      container.read(beatsVaultFilterProvider.notifier).state =
          const BeatsVaultFilterState(
        searchQuery: 'durban',
        sortOrder: BeatsSortOrder.bpmDesc,
      );

      expect(container.read(filteredBeatsVaultProvider).single.id,
          equals('beat_durban'));

      container.read(beatsVaultFilterProvider.notifier).state =
          const BeatsVaultFilterState(searchQuery: 'nothing here');
      expect(container.read(filteredBeatsVaultProvider), isEmpty);
    });
  });
}

ProviderContainer _container({required List<ProducerBeatEntity> seed}) {
  final container = ProviderContainer(
    overrides: <Override>[
      beatRepositoryProvider.overrideWithValue(
        InMemoryBeatRepository(seed: seed),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

ProducerBeatEntity _beat({
  String id = 'beat_1',
  String title = 'Ekasi Nights',
  String genre = 'Amapiano',
  int bpm = 112,
  String key = 'F# Minor',
  BeatStatus status = BeatStatus.draft,
  List<String> tags = const <String>[],
  List<int> sales = const <int>[],
  bool stems = false,
  int price = 10,
  int auditionCount = 0,
  DateTime? createdAt,
}) =>
    ProducerBeatEntity(
      id: id,
      title: title,
      genre: genre,
      bpm: bpm,
      musicalKey: key,
      tags: tags,
      priceInCredits: price,
      status: status,
      previewAudioUrl: 'https://cdn/$id.mp3',
      stemPackage: stems
          ? const BeatStemPackage(
              drumsUrl: 'drums.wav',
              bassUrl: 'bass.wav',
              melodyUrl: 'melody.wav',
              otherUrl: 'fx.wav',
              isSeparated: true,
            )
          : const BeatStemPackage(),
      salesRecords: <BeatSaleRecord>[for (final c in sales) _sale(c)],
      auditionCount: auditionCount,
      createdAt: createdAt ?? DateTime(2026, 9, 15),
      updatedAt: DateTime(2026, 9, 23),
    );

BeatSaleRecord _sale(int credits) => BeatSaleRecord(
      saleId: 'sale_$credits',
      buyerId: 'creator_sipho',
      buyerHandle: '@sipho_beats',
      licenseTier: BeatLicenseTier.nonExclusiveCommercial,
      creditsEarned: credits,
      timestamp: DateTime(2026, 9, 24),
    );

LibraryTrack _track() => LibraryTrack(
      id: 'track_9',
      title: 'Township Log Drum Heat',
      creatorName: 'You',
      genre: 'Amapiano',
      language: 'Tshivenda',
      durationSeconds: 187,
      remoteAudioUrl: 'https://cdn/track_9.mp3',
      createdAt: DateTime(2026, 9, 18),
      isInstrumental: true,
    );
