import '../../domain/models/producer_beat_entity.dart';
import '../../domain/repositories/i_beat_repository.dart';

/// CDN origin used by the seeded producer beats.
const String beatCdnOrigin = 'https://cdn.vhunambi.com/beats';

/// In-memory [IBeatRepository] double (REQ-BEAT-08).
///
/// Zero disk, zero Hive, zero timers — safe for headless `flutter_test` runs.
/// Passing an explicit [seed] (including `const []`) replaces the demo
/// catalogue, which the vault widget tests use to exercise the empty state.
class InMemoryBeatRepository implements IBeatRepository {
  InMemoryBeatRepository({List<ProducerBeatEntity>? seed}) {
    for (final beat in seed ?? seedProducerBeats()) {
      _store[beat.id] = beat;
    }
  }

  final Map<String, ProducerBeatEntity> _store =
      <String, ProducerBeatEntity>{};

  @override
  Future<List<ProducerBeatEntity>> getAllBeats() async {
    final beats = _store.values.toList();
    beats.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return beats;
  }

  @override
  Future<ProducerBeatEntity?> getBeatById(String id) async => _store[id];

  @override
  Future<void> saveBeat(ProducerBeatEntity beat) async {
    _store[beat.id] = beat;
  }

  @override
  Future<void> deleteBeat(String id) async {
    _store.remove(id);
  }

  @override
  Future<ProducerBeatEntity> publishBeat(String id) async {
    final beat = _require(id);
    final published = beat.copyWith(
      status: BeatStatus.published,
      updatedAt: DateTime.now(),
    );
    _store[id] = published;
    return published;
  }

  @override
  Future<ProducerBeatEntity> unpublishBeat(String id) async {
    final beat = _require(id);
    final unpublished = beat.copyWith(
      status: BeatStatus.draft,
      updatedAt: DateTime.now(),
    );
    _store[id] = unpublished;
    return unpublished;
  }

  @override
  Future<ProducerBeatEntity> recordSale(String id, BeatSaleRecord sale) async {
    final beat = _require(id);
    final updated = beat.copyWith(
      salesRecords: <BeatSaleRecord>[...beat.salesRecords, sale],
      updatedAt: DateTime.now(),
    );
    _store[id] = updated;
    return updated;
  }

  @override
  Future<ProducerBeatEntity> incrementAuditions(String id) async {
    final beat = _require(id);
    final updated = beat.copyWith(auditionCount: beat.auditionCount + 1);
    _store[id] = updated;
    return updated;
  }

  @override
  Future<void> clearAll() async {
    _store.clear();
  }

  ProducerBeatEntity _require(String id) {
    final beat = _store[id];
    if (beat == null) {
      throw StateError('Unknown beat: $id');
    }
    return beat;
  }
}

/// Demo catalogue of three realistic African producer beats (REQ-BEAT-08).
List<ProducerBeatEntity> seedProducerBeats() {
  final now = DateTime.now();

  return <ProducerBeatEntity>[
    ProducerBeatEntity(
      id: 'beat_soshanguve',
      title: 'Soshanguve Pulse',
      genre: 'Amapiano',
      bpm: 112,
      musicalKey: 'F# Minor',
      tags: const <String>['Log Drum', 'Private School', 'Soulful'],
      priceInCredits: 10,
      status: BeatStatus.published,
      previewAudioUrl: '$beatCdnOrigin/soshanguve-pulse.mp3',
      stemPackage: BeatStemPackage(
        drumsUrl: '$beatCdnOrigin/soshanguve-pulse-drums.wav',
        bassUrl: '$beatCdnOrigin/soshanguve-pulse-bass.wav',
        melodyUrl: '$beatCdnOrigin/soshanguve-pulse-melody.wav',
        otherUrl: '$beatCdnOrigin/soshanguve-pulse-fx.wav',
        isSeparated: true,
      ),
      salesRecords: <BeatSaleRecord>[
        BeatSaleRecord(
          saleId: 'sale_001',
          buyerId: 'creator_sipho',
          buyerHandle: '@sipho_beats',
          licenseTier: BeatLicenseTier.nonExclusiveCommercial,
          creditsEarned: 10,
          timestamp: now.subtract(const Duration(days: 1)),
        ),
        BeatSaleRecord(
          saleId: 'sale_002',
          buyerId: 'creator_lerato',
          buyerHandle: '@lerato_prod',
          licenseTier: BeatLicenseTier.nonExclusiveCommercial,
          creditsEarned: 10,
          timestamp: now.subtract(const Duration(hours: 5)),
        ),
      ],
      auditionCount: 48,
      createdAt: now.subtract(const Duration(days: 3)),
      updatedAt: now.subtract(const Duration(hours: 5)),
    ),
    ProducerBeatEntity(
      id: 'beat_durban',
      title: 'Durban Midnight Rush',
      genre: 'Gqom',
      bpm: 128,
      musicalKey: 'C Major',
      tags: const <String>['Broken Beat', 'Dark Sub'],
      priceInCredits: 15,
      status: BeatStatus.published,
      previewAudioUrl: '$beatCdnOrigin/durban-midnight-rush.mp3',
      stemPackage: BeatStemPackage(
        drumsUrl: '$beatCdnOrigin/durban-midnight-rush-drums.wav',
        bassUrl: '$beatCdnOrigin/durban-midnight-rush-bass.wav',
        melodyUrl: '$beatCdnOrigin/durban-midnight-rush-melody.wav',
        isSeparated: true,
      ),
      salesRecords: <BeatSaleRecord>[
        BeatSaleRecord(
          saleId: 'sale_003',
          buyerId: 'creator_djvibe',
          buyerHandle: '@djvibe',
          licenseTier: BeatLicenseTier.syncLicense,
          creditsEarned: 30,
          timestamp: now.subtract(const Duration(days: 2)),
        ),
      ],
      auditionCount: 22,
      createdAt: now.subtract(const Duration(days: 5)),
      updatedAt: now.subtract(const Duration(days: 2)),
    ),
    ProducerBeatEntity(
      id: 'beat_sophiatown',
      title: 'Sophiatown Bounce',
      genre: 'Kwaito',
      bpm: 106,
      musicalKey: 'A Minor',
      tags: const <String>['Bubblegum', 'Vocal Chop'],
      priceInCredits: 5,
      status: BeatStatus.draft,
      previewAudioUrl: '$beatCdnOrigin/sophiatown-bounce.mp3',
      auditionCount: 9,
      createdAt: now.subtract(const Duration(days: 7)),
      updatedAt: now.subtract(const Duration(days: 7)),
    ),
  ];
}
