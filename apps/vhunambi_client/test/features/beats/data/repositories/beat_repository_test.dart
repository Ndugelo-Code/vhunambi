import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/features/beats/data/repositories/beat_repository.dart';
import 'package:vhunambi_client/features/beats/data/repositories/in_memory_beat_repository.dart';
import 'package:vhunambi_client/features/beats/domain/models/producer_beat_entity.dart';

/// T12 — Producer beat repository suite (REQ-BEAT-24).
void main() {
  group('InMemoryBeatRepository', () {
    test('seeds three realistic African producer beats (REQ-BEAT-08)', () async {
      final beats = await InMemoryBeatRepository().getAllBeats();

      expect(beats, hasLength(3));
      expect(
        beats.map((beat) => beat.genre).toSet(),
        equals({'Amapiano', 'Gqom', 'Kwaito'}),
      );

      final soshanguve = beats.firstWhere((beat) => beat.id == 'beat_soshanguve');
      expect(soshanguve.title, equals('Soshanguve Pulse'));
      expect(soshanguve.bpm, 112);
      expect(soshanguve.musicalKey, equals('F# Minor'));
      expect(soshanguve.isPublished, isTrue);
      expect(soshanguve.stemPackage.hasAllStems, isTrue);

      final durban = beats.firstWhere((beat) => beat.id == 'beat_durban');
      expect(durban.bpm, 128);
      expect(durban.musicalKey, equals('C Major'));

      final sophiatown = beats.firstWhere((beat) => beat.id == 'beat_sophiatown');
      expect(sophiatown.bpm, 106);
      expect(sophiatown.musicalKey, equals('A Minor'));
      expect(sophiatown.isDraft, isTrue);
    });

    test('an explicit seed replaces the demo catalogue', () async {
      expect(
        await InMemoryBeatRepository(seed: const []).getAllBeats(),
        isEmpty,
      );

      final custom = InMemoryBeatRepository(seed: [_beat()]);
      expect((await custom.getAllBeats()).single.id, equals('beat_1'));
    });

    test('getAllBeats returns the newest creation first', () async {
      final repository = InMemoryBeatRepository(seed: const []);
      final now = DateTime(2026, 9, 27, 12);

      await repository.saveBeat(
        _beat(id: 'older', createdAt: now.subtract(const Duration(days: 4))),
      );
      await repository.saveBeat(_beat(id: 'newer', createdAt: now));
      await repository.saveBeat(
        _beat(id: 'middle', createdAt: now.subtract(const Duration(days: 1))),
      );

      expect(
        (await repository.getAllBeats()).map((beat) => beat.id).toList(),
        equals(['newer', 'middle', 'older']),
      );
    });

    test('saveBeat upserts by id, getBeatById resolves or returns null',
        () async {
      final repository = InMemoryBeatRepository(seed: const []);

      await repository.saveBeat(_beat(title: 'First'));
      await repository.saveBeat(_beat(title: 'Replaced'));

      expect(await repository.getAllBeats(), hasLength(1));
      expect(
        (await repository.getBeatById('beat_1'))?.title,
        equals('Replaced'),
      );
      expect(await repository.getBeatById('missing'), isNull);
    });

    test('deleteBeat removes the record and is idempotent', () async {
      final repository = InMemoryBeatRepository(seed: [_beat()]);

      await repository.deleteBeat('beat_1');
      await repository.deleteBeat('beat_1');

      expect(await repository.getAllBeats(), isEmpty);
    });

    test('publishBeat / unpublishBeat flip the status', () async {
      final repository = InMemoryBeatRepository(seed: [_beat()]);

      final published = await repository.publishBeat('beat_1');
      expect(published.isPublished, isTrue);
      expect((await repository.getBeatById('beat_1'))!.isPublished, isTrue);

      final draft = await repository.unpublishBeat('beat_1');
      expect(draft.isDraft, isTrue);
      expect((await repository.getBeatById('beat_1'))!.isDraft, isTrue);
    });

    test('recordSale appends to the royalty ledger', () async {
      final repository = InMemoryBeatRepository(seed: [_beat()]);

      final updated = await repository.recordSale('beat_1', _sale(credits: 30));

      expect(updated.totalSales, 1);
      expect(updated.totalEarningsCredits, 30);
      expect(updated.salesRecords.single.licenseTier,
          equals(BeatLicenseTier.syncLicense));
    });

    test('incrementAuditions bumps the preview counter', () async {
      final repository = InMemoryBeatRepository(seed: [_beat()]);

      await repository.incrementAuditions('beat_1');
      final updated = await repository.incrementAuditions('beat_1');

      expect(updated.auditionCount, 2);
    });

    test('clearAll empties the catalogue', () async {
      final repository = InMemoryBeatRepository();

      await repository.clearAll();

      expect(await repository.getAllBeats(), isEmpty);
    });

    test('mutations on an unknown beat throw a StateError', () async {
      final repository = InMemoryBeatRepository(seed: const []);

      expect(
        () => repository.publishBeat('ghost'),
        throwsA(isA<StateError>()),
      );
      expect(
        () => repository.recordSale('ghost', _sale()),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('BeatRepository (Hive-backed)', () {
    late Directory tempDir;
    late Box hiveBox;
    late BeatRepository repository;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vhunambi_beats_');
      Hive.init(tempDir.path);
      hiveBox = await Hive.openBox(AppConstants.beatsBoxKey);
      repository = BeatRepository(box: hiveBox);
    });

    tearDown(() async {
      await hiveBox.close();
      await Hive.close();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('persists and rehydrates beats newest-first (REQ-BEAT-09)', () async {
      final now = DateTime(2026, 9, 27, 12);

      await repository.saveBeat(
        _beat(id: 'beat_a', createdAt: now.subtract(const Duration(days: 2))),
      );
      await repository.saveBeat(_beat(id: 'beat_b', createdAt: now));

      final beats = await repository.getAllBeats();
      expect(beats.map((beat) => beat.id).toList(), equals(['beat_b', 'beat_a']));
      expect(hiveBox.get('beat_b'), isA<Map>());
    });

    test('publish, sale and audition mutations round-trip through the box',
        () async {
      await repository.saveBeat(_beat());

      await repository.publishBeat('beat_1');
      await repository.recordSale('beat_1', _sale(credits: 15));
      await repository.incrementAuditions('beat_1');

      final stored = await repository.getBeatById('beat_1');
      expect(stored!.isPublished, isTrue);
      expect(stored.totalSales, 1);
      expect(stored.totalEarningsCredits, 15);
      expect(stored.auditionCount, 1);

      await repository.unpublishBeat('beat_1');
      expect((await repository.getBeatById('beat_1'))!.isDraft, isTrue);

      await repository.deleteBeat('beat_1');
      expect(await repository.getBeatById('beat_1'), isNull);
    });

    test('clearAll wipes the persisted box', () async {
      await repository.saveBeat(_beat());
      await repository.clearAll();

      expect(await repository.getAllBeats(), isEmpty);
    });
  });

  group('BeatRepository (in-memory fallback)', () {
    test('works seamlessly when Hive is not initialized (REQ-BEAT-09)',
        () async {
      final repository = BeatRepository();
      expect(await repository.getAllBeats(), isEmpty);

      await repository.saveBeat(_beat());
      await repository.publishBeat('beat_1');
      await repository.recordSale('beat_1', _sale(credits: 10));
      await repository.incrementAuditions('beat_1');

      final beats = await repository.getAllBeats();
      expect(beats.single.isPublished, isTrue);
      expect(beats.single.totalEarningsCredits, 10);
      expect(beats.single.auditionCount, 1);

      await repository.deleteBeat('beat_1');
      expect(await repository.getAllBeats(), isEmpty);
    });
  });
}

ProducerBeatEntity _beat({
  String id = 'beat_1',
  String title = 'Soshanguve Pulse',
  String genre = 'Amapiano',
  int bpm = 112,
  BeatStatus status = BeatStatus.draft,
  DateTime? createdAt,
}) =>
    ProducerBeatEntity(
      id: id,
      title: title,
      genre: genre,
      bpm: bpm,
      musicalKey: 'F# Minor',
      status: status,
      previewAudioUrl: 'https://cdn.vhunambi.com/beats/$id.mp3',
      createdAt: createdAt ?? DateTime(2026, 9, 20),
      updatedAt: DateTime(2026, 9, 24),
    );

BeatSaleRecord _sale({
  int credits = 10,
  BeatLicenseTier tier = BeatLicenseTier.syncLicense,
}) =>
    BeatSaleRecord(
      saleId: 'sale_1',
      buyerId: 'creator_sipho',
      buyerHandle: '@sipho_beats',
      licenseTier: tier,
      creditsEarned: credits,
      timestamp: DateTime(2026, 9, 26),
    );
