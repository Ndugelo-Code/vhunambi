import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/beats/domain/models/producer_beat_entity.dart';

/// T12 — Producer beat domain suite (REQ-BEAT-24).
void main() {
  group('BeatStatus', () {
    test('exposes the published labels', () {
      expect(BeatStatus.draft.label, equals('Draft'));
      expect(BeatStatus.published.label, equals('Published'));
      expect(BeatStatus.archived.label, equals('Archived'));
    });

    test('serialises to snake_case names', () {
      expect(BeatStatus.draft.toJson(), equals('draft'));
      expect(BeatStatus.published.toJson(), equals('published'));
      expect(BeatStatus.archived.toJson(), equals('archived'));
    });

    test('fromJson is case tolerant and falls back to draft', () {
      expect(BeatStatus.fromJson('PUBLISHED'), equals(BeatStatus.published));
      expect(BeatStatus.fromJson(' archived '), equals(BeatStatus.archived));
      expect(BeatStatus.fromJson('nonsense'), equals(BeatStatus.draft));
      expect(BeatStatus.fromJson(''), equals(BeatStatus.draft));
    });
  });

  group('BeatLicenseTier', () {
    test('exposes contract labels', () {
      expect(
        BeatLicenseTier.nonExclusiveCommercial.label,
        equals('Non-Exclusive Commercial'),
      );
      expect(
        BeatLicenseTier.exclusiveOwnership.label,
        equals('Exclusive Ownership'),
      );
      expect(BeatLicenseTier.syncLicense.label, equals('Sync License'));
      expect(BeatLicenseTier.personalLease.label, equals('Personal Lease'));
    });

    test('exposes the default credit prices', () {
      expect(BeatLicenseTier.nonExclusiveCommercial.defaultPriceCredits, 10);
      expect(BeatLicenseTier.exclusiveOwnership.defaultPriceCredits, 50);
      expect(BeatLicenseTier.syncLicense.defaultPriceCredits, 30);
      expect(BeatLicenseTier.personalLease.defaultPriceCredits, 5);
    });

    test('fromJson round-trips and defaults to non-exclusive commercial', () {
      for (final tier in BeatLicenseTier.values) {
        expect(BeatLicenseTier.fromJson(tier.toJson()), equals(tier));
      }
      expect(
        BeatLicenseTier.fromJson(' EXCLUSIVEOWNERSHIP '),
        equals(BeatLicenseTier.exclusiveOwnership),
      );
      expect(
        BeatLicenseTier.fromJson('nonsense'),
        equals(BeatLicenseTier.nonExclusiveCommercial),
      );
    });
  });

  group('BeatStemPackage', () {
    test('defaults to an empty, unseparated manifest', () {
      const stems = BeatStemPackage();
      expect(stems.stemCount, 0);
      expect(stems.hasAllStems, isFalse);
      expect(stems.isSeparated, isFalse);
      expect(stems.stemCountLabel, equals('0/4 stems'));
    });

    test('stemCount ignores null and empty urls', () {
      const stems = BeatStemPackage(
        drumsUrl: 'https://cdn/drums.wav',
        bassUrl: '',
        melodyUrl: 'https://cdn/melody.wav',
      );
      expect(stems.stemCount, 2);
      expect(stems.stemCountLabel, equals('2/4 stems'));
    });

    test('hasAllStems flips true with four urls', () {
      const stems = BeatStemPackage(
        drumsUrl: 'd',
        bassUrl: 'b',
        melodyUrl: 'm',
        otherUrl: 'o',
        isSeparated: true,
      );
      expect(stems.stemCount, 4);
      expect(stems.hasAllStems, isTrue);
    });

    test('copyWith replaces individual stems', () {
      const stems = BeatStemPackage(drumsUrl: 'd');
      final updated = stems.copyWith(bassUrl: 'b', isSeparated: true);

      expect(updated.drumsUrl, equals('d'));
      expect(updated.bassUrl, equals('b'));
      expect(updated.isSeparated, isTrue);
    });

    test('JSON round-trips every stem url', () {
      const stems = BeatStemPackage(
        drumsUrl: 'd',
        bassUrl: 'b',
        melodyUrl: 'm',
        otherUrl: 'o',
        isSeparated: true,
      );

      final restored = BeatStemPackage.fromJson(stems.toJson());
      expect(restored, equals(stems));
      expect(restored.toJson()['is_separated'], isTrue);
    });

    test('fromJson tolerates a missing manifest', () {
      final restored = BeatStemPackage.fromJson(const <String, dynamic>{});
      expect(restored, equals(const BeatStemPackage()));
    });
  });

  group('BeatSaleRecord', () {
    test('JSON round-trips the ledger entry', () {
      final sale = BeatSaleRecord(
        saleId: 'sale_1',
        buyerId: 'creator_sipho',
        buyerHandle: '@sipho_beats',
        licenseTier: BeatLicenseTier.syncLicense,
        creditsEarned: 30,
        timestamp: DateTime(2026, 9, 26, 18, 30),
      );

      final restored = BeatSaleRecord.fromJson(sale.toJson());
      expect(restored, equals(sale));
      expect(restored.licenseTier, equals(BeatLicenseTier.syncLicense));
    });

    test('renders the credit delta and ISO date stamps', () {
      final sale = _sale(credits: 15, timestamp: DateTime(2026, 9, 6));
      expect(sale.creditsLabel, equals('+⚡ 15 Credits'));
      expect(sale.dateLabel, equals('2026-09-06'));
    });

    test('fromJson falls back to safe defaults', () {
      final restored = BeatSaleRecord.fromJson(const <String, dynamic>{});
      expect(restored.buyerHandle, equals('@anonymous'));
      expect(restored.creditsEarned, 0);
      expect(
        restored.licenseTier,
        equals(BeatLicenseTier.nonExclusiveCommercial),
      );
    });
  });

  group('ProducerBeatEntity', () {
    test('defaults match the vault contract (REQ-BEAT-01)', () {
      final beat = _beat();

      expect(beat.producerId, equals('current_user'));
      expect(beat.producerName, equals('You'));
      expect(beat.producerHandle, equals('@you'));
      expect(beat.bpm, equals(112));
      expect(beat.priceInCredits, 10);
      expect(beat.status, equals(BeatStatus.draft));
      expect(beat.licenseTier, equals(BeatLicenseTier.nonExclusiveCommercial));
      expect(beat.tags, isEmpty);
      expect(beat.salesRecords, isEmpty);
      expect(beat.auditionCount, 0);
    });

    test('exposes publication flags derived from the status', () {
      expect(_beat().isDraft, isTrue);
      expect(_beat(status: BeatStatus.published).isPublished, isTrue);
      expect(_beat(status: BeatStatus.archived).isArchived, isTrue);
    });

    test('aggregates sales and royalty credits', () {
      final beat = _beat(
        salesRecords: [
          _sale(saleId: 's1', credits: 10),
          _sale(saleId: 's2', credits: 30),
        ],
      );

      expect(beat.totalSales, 2);
      expect(beat.totalEarningsCredits, 40);
    });

    test('renders the badge and metadata labels', () {
      final beat = _beat(status: BeatStatus.published);

      expect(beat.bpmLabel, equals('112 BPM'));
      expect(beat.priceLabel, equals('⚡ 10 Credits'));
      expect(beat.statusLabel, equals('Published'));
      expect(beat.keyLabel, equals('F# Minor'));
      expect(beat.metadataLabel, equals('Amapiano • 112 BPM • F# Minor'));
      expect(beat.salesLabel, equals('⚡ 10 Cr • 0 Sold'));
    });

    test('blank musical keys degrade to "Unknown Key" (REQ-BEAT-06)', () {
      expect(_beat(key: '   ').keyLabel, equals('Unknown Key'));
    });

    test('copyWith replaces selective metadata', () {
      final beat = _beat();
      final updated = beat.copyWith(
        title: 'Bacardi Bounce',
        bpm: 128,
        status: BeatStatus.published,
        priceInCredits: 20,
      );

      expect(updated.title, equals('Bacardi Bounce'));
      expect(updated.bpm, 128);
      expect(updated.isPublished, isTrue);
      expect(updated.priceInCredits, 20);
      expect(updated.id, equals(beat.id));
      expect(updated.genre, equals(beat.genre));
    });

    test('JSON round-trips stems, tags and the royalty ledger', () {
      final beat = _beat(
        tags: const ['Log Drum', 'Private School'],
        status: BeatStatus.published,
        stemPackage: const BeatStemPackage(
          drumsUrl: 'd',
          bassUrl: 'b',
          melodyUrl: 'm',
          otherUrl: 'o',
          isSeparated: true,
        ),
        salesRecords: [_sale(saleId: 's1', credits: 10)],
        auditionCount: 12,
        trackId: 'track_9',
      );

      final restored = ProducerBeatEntity.fromJson(beat.toJson());
      expect(restored, equals(beat));
      expect(restored.tags, equals(const ['Log Drum', 'Private School']));
      expect(restored.stemPackage.hasAllStems, isTrue);
      expect(restored.salesRecords.single.creditsEarned, 10);
      expect(restored.auditionCount, 12);
      expect(restored.trackId, equals('track_9'));
    });

    test('fromJson falls back to safe defaults for partial payloads', () {
      final restored = ProducerBeatEntity.fromJson(
        const <String, dynamic>{'id': 'beat_partial'},
      );

      expect(restored.id, equals('beat_partial'));
      expect(restored.title, equals('Untitled Beat'));
      expect(restored.genre, equals('Amapiano'));
      expect(restored.bpm, equals(112));
      expect(restored.status, equals(BeatStatus.draft));
      expect(restored.stemPackage, equals(const BeatStemPackage()));
    });

    test('equality is structural', () {
      final base = _beat();
      expect(base, equals(base.copyWith()));
      expect(base.hashCode, equals(base.copyWith().hashCode));
      expect(base == base.copyWith(title: 'Other'), isFalse);
    });

    test('createdAgoLabel renders relative creation stamps', () {
      final beat = _beat(
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      );
      expect(beat.createdAgoLabel, equals('Created 2 days ago'));
    });
  });
}

ProducerBeatEntity _beat({
  String id = 'beat_soshanguve',
  String title = 'Soshanguve Pulse',
  String genre = 'Amapiano',
  int bpm = 112,
  String key = 'F# Minor',
  int price = 10,
  BeatStatus status = BeatStatus.draft,
  List<String> tags = const <String>[],
  BeatStemPackage stemPackage = const BeatStemPackage(),
  List<BeatSaleRecord> salesRecords = const <BeatSaleRecord>[],
  int auditionCount = 0,
  String? trackId,
  DateTime? createdAt,
}) =>
    ProducerBeatEntity(
      id: id,
      trackId: trackId,
      title: title,
      genre: genre,
      bpm: bpm,
      musicalKey: key,
      tags: tags,
      priceInCredits: price,
      status: status,
      previewAudioUrl: 'https://cdn.vhunambi.com/beats/$id.mp3',
      stemPackage: stemPackage,
      salesRecords: salesRecords,
      auditionCount: auditionCount,
      createdAt: createdAt ?? DateTime(2026, 9, 20),
      updatedAt: DateTime(2026, 9, 25),
    );

BeatSaleRecord _sale({
  String saleId = 'sale_1',
  int credits = 10,
  DateTime? timestamp,
  BeatLicenseTier tier = BeatLicenseTier.nonExclusiveCommercial,
}) =>
    BeatSaleRecord(
      saleId: saleId,
      buyerId: 'creator_sipho',
      buyerHandle: '@sipho_beats',
      licenseTier: tier,
      creditsEarned: credits,
      timestamp: timestamp ?? DateTime(2026, 9, 26),
    );
