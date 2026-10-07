import 'package:flutter/foundation.dart';

/// Lifecycle and marketplace visibility status of a producer beat.
/// Reference: `docs/phases/phase_14_beats_vault/requirements.md` REQ-BEAT-02.
enum BeatStatus {
  draft,
  published,
  archived;

  /// Human readable badge label.
  String get label => switch (this) {
        BeatStatus.draft => 'Draft',
        BeatStatus.published => 'Published',
        BeatStatus.archived => 'Archived',
      };

  /// snake_case persistence representation (enum names are already lowercase).
  String toJson() => name;

  /// Tolerant reader with a `draft` fallback (REQ-BEAT-02).
  static BeatStatus fromJson(String value) {
    final normalized = value.toLowerCase().trim();
    return BeatStatus.values.firstWhere(
      (status) => status.name == normalized,
      orElse: () => BeatStatus.draft,
    );
  }
}

/// Commercial licensing rights tiers offered for a beat (REQ-BEAT-03).
enum BeatLicenseTier {
  nonExclusiveCommercial,
  exclusiveOwnership,
  syncLicense,
  personalLease;

  /// Contract label rendered in the vault and marketplace.
  String get label => switch (this) {
        BeatLicenseTier.nonExclusiveCommercial => 'Non-Exclusive Commercial',
        BeatLicenseTier.exclusiveOwnership => 'Exclusive Ownership',
        BeatLicenseTier.syncLicense => 'Sync License',
        BeatLicenseTier.personalLease => 'Personal Lease',
      };

  /// Suggested credit price used by `BeatFormDialog` when the tier changes.
  int get defaultPriceCredits => switch (this) {
        BeatLicenseTier.nonExclusiveCommercial => 10,
        BeatLicenseTier.exclusiveOwnership => 50,
        BeatLicenseTier.syncLicense => 30,
        BeatLicenseTier.personalLease => 5,
      };

  String toJson() => name;

  /// Tolerant reader defaulting to the standard commercial release right.
  static BeatLicenseTier fromJson(String value) {
    final normalized = value.toLowerCase().trim();
    return BeatLicenseTier.values.firstWhere(
      (tier) => tier.name.toLowerCase() == normalized,
      orElse: () => BeatLicenseTier.nonExclusiveCommercial,
    );
  }
}

/// Standard beat tempo used whenever a BPM is not supplied (REQ-BEAT-01).
const int defaultBeatBpm = 112;

/// Bounds enforced by the authoring dialog and tap-tempo control.
const int minBeatBpm = 40;
const int maxBeatBpm = 260;

/// Four-stem package manifest backing the Stems Package card (REQ-BEAT-04).
@immutable
class BeatStemPackage {
  final String? drumsUrl;
  final String? bassUrl;
  final String? melodyUrl;
  final String? otherUrl;

  /// `true` once the separation lab has generated the stem files.
  final bool isSeparated;

  const BeatStemPackage({
    this.drumsUrl,
    this.bassUrl,
    this.melodyUrl,
    this.otherUrl,
    this.isSeparated = false,
  });

  /// Number of materialised stem URLs (`0`–`4`).
  int get stemCount => [drumsUrl, bassUrl, melodyUrl, otherUrl]
      .where((url) => url != null && url.isNotEmpty)
      .length;

  bool get hasAllStems => stemCount == 4;

  /// `4/4` style manifest summary rendered by the vault cards.
  String get stemCountLabel => '$stemCount/4 stems';

  BeatStemPackage copyWith({
    String? drumsUrl,
    String? bassUrl,
    String? melodyUrl,
    String? otherUrl,
    bool? isSeparated,
  }) {
    return BeatStemPackage(
      drumsUrl: drumsUrl ?? this.drumsUrl,
      bassUrl: bassUrl ?? this.bassUrl,
      melodyUrl: melodyUrl ?? this.melodyUrl,
      otherUrl: otherUrl ?? this.otherUrl,
      isSeparated: isSeparated ?? this.isSeparated,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'drums_url': drumsUrl,
        'bass_url': bassUrl,
        'melody_url': melodyUrl,
        'other_url': otherUrl,
        'is_separated': isSeparated,
      };

  factory BeatStemPackage.fromJson(Map<String, dynamic> json) {
    return BeatStemPackage(
      drumsUrl: json['drums_url'] as String?,
      bassUrl: json['bass_url'] as String?,
      melodyUrl: json['melody_url'] as String?,
      otherUrl: json['other_url'] as String?,
      isSeparated: json['is_separated'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeatStemPackage &&
          runtimeType == other.runtimeType &&
          drumsUrl == other.drumsUrl &&
          bassUrl == other.bassUrl &&
          melodyUrl == other.melodyUrl &&
          otherUrl == other.otherUrl &&
          isSeparated == other.isSeparated;

  @override
  int get hashCode =>
      Object.hash(drumsUrl, bassUrl, melodyUrl, otherUrl, isSeparated);
}

/// Historical ledger record of a beat license purchased by another creator
/// (REQ-BEAT-05).
@immutable
class BeatSaleRecord {
  final String saleId;
  final String buyerId;
  final String buyerHandle;
  final BeatLicenseTier licenseTier;
  final int creditsEarned;
  final DateTime timestamp;

  const BeatSaleRecord({
    required this.saleId,
    required this.buyerId,
    required this.buyerHandle,
    required this.licenseTier,
    required this.creditsEarned,
    required this.timestamp,
  });

  /// `+⚡ 10 Credits` ledger delta shown in the royalty history.
  String get creditsLabel => '+⚡ $creditsEarned Credits';

  /// `2026-09-26` date stamp rendered by the royalty ledger rows.
  String get dateLabel {
    final month = timestamp.month.toString().padLeft(2, '0');
    final day = timestamp.day.toString().padLeft(2, '0');
    return '${timestamp.year}-$month-$day';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sale_id': saleId,
        'buyer_id': buyerId,
        'buyer_handle': buyerHandle,
        'license_tier': licenseTier.toJson(),
        'credits_earned': creditsEarned,
        'timestamp': timestamp.toIso8601String(),
      };

  factory BeatSaleRecord.fromJson(Map<String, dynamic> json) {
    return BeatSaleRecord(
      saleId: json['sale_id'] as String? ?? '',
      buyerId: json['buyer_id'] as String? ?? '',
      buyerHandle: json['buyer_handle'] as String? ?? '@anonymous',
      licenseTier:
          BeatLicenseTier.fromJson(json['license_tier'] as String? ?? ''),
      creditsEarned: json['credits_earned'] as int? ?? 0,
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
              DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeatSaleRecord &&
          runtimeType == other.runtimeType &&
          saleId == other.saleId &&
          buyerId == other.buyerId &&
          buyerHandle == other.buyerHandle &&
          licenseTier == other.licenseTier &&
          creditsEarned == other.creditsEarned &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(
        saleId,
        buyerId,
        buyerHandle,
        licenseTier,
        creditsEarned,
        timestamp,
      );
}

/// Primary Producer Beat aggregate entity (REQ-BEAT-01).
@immutable
class ProducerBeatEntity {
  final String id;

  /// Originating vault asset when the beat was converted from `LibraryTrack`.
  final String? trackId;
  final String title;
  final String producerId;
  final String producerName;
  final String producerHandle;
  final String genre;
  final int bpm;
  final String musicalKey;
  final List<String> tags;
  final int priceInCredits;
  final BeatLicenseTier licenseTier;
  final BeatStatus status;
  final String previewAudioUrl;
  final BeatStemPackage stemPackage;
  final List<BeatSaleRecord> salesRecords;
  final int auditionCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProducerBeatEntity({
    required this.id,
    this.trackId,
    required this.title,
    this.producerId = 'current_user',
    this.producerName = 'You',
    this.producerHandle = '@you',
    required this.genre,
    this.bpm = defaultBeatBpm,
    this.musicalKey = 'F# Minor',
    this.tags = const <String>[],
    this.priceInCredits = 10,
    this.licenseTier = BeatLicenseTier.nonExclusiveCommercial,
    this.status = BeatStatus.draft,
    this.previewAudioUrl = '',
    this.stemPackage = const BeatStemPackage(),
    this.salesRecords = const <BeatSaleRecord>[],
    this.auditionCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPublished => status == BeatStatus.published;
  bool get isDraft => status == BeatStatus.draft;
  bool get isArchived => status == BeatStatus.archived;

  /// Number of completed license purchases (REQ-BEAT-06).
  int get totalSales => salesRecords.length;

  /// Aggregate royalty credits credited to the producer.
  int get totalEarningsCredits =>
      salesRecords.fold<int>(0, (sum, record) => sum + record.creditsEarned);

  String get bpmLabel => '$bpm BPM';
  String get priceLabel => '⚡ $priceInCredits Credits';
  String get statusLabel => status.label;

  /// Empty keys degrade gracefully instead of rendering a blank badge.
  String get keyLabel => musicalKey.trim().isEmpty ? 'Unknown Key' : musicalKey;

  /// `Amapiano • 112 BPM • F# Minor` vault subtitle.
  String get metadataLabel => '$genre • $bpmLabel • $keyLabel';

  /// `⚡ 10 Cr • 5 Sold` card footer.
  String get salesLabel => '⚡ $priceInCredits Cr • $totalSales Sold';

  /// `180s preview` copy surfaced by the publish confirmation sheet.
  static const int previewSeconds = 180;

  /// Human readable creation stamp, e.g. `Created 2 days ago`.
  String get createdAgoLabel {
    final difference = DateTime.now().difference(createdAt);

    if (difference.inMinutes < 1) return 'Created just now';
    if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return 'Created $minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    }
    if (difference.inHours < 24) {
      final hours = difference.inHours;
      return 'Created $hours ${hours == 1 ? 'hour' : 'hours'} ago';
    }
    final days = difference.inDays;
    return 'Created $days ${days == 1 ? 'day' : 'days'} ago';
  }

  ProducerBeatEntity copyWith({
    String? id,
    String? trackId,
    String? title,
    String? producerId,
    String? producerName,
    String? producerHandle,
    String? genre,
    int? bpm,
    String? musicalKey,
    List<String>? tags,
    int? priceInCredits,
    BeatLicenseTier? licenseTier,
    BeatStatus? status,
    String? previewAudioUrl,
    BeatStemPackage? stemPackage,
    List<BeatSaleRecord>? salesRecords,
    int? auditionCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProducerBeatEntity(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      title: title ?? this.title,
      producerId: producerId ?? this.producerId,
      producerName: producerName ?? this.producerName,
      producerHandle: producerHandle ?? this.producerHandle,
      genre: genre ?? this.genre,
      bpm: bpm ?? this.bpm,
      musicalKey: musicalKey ?? this.musicalKey,
      tags: tags ?? this.tags,
      priceInCredits: priceInCredits ?? this.priceInCredits,
      licenseTier: licenseTier ?? this.licenseTier,
      status: status ?? this.status,
      previewAudioUrl: previewAudioUrl ?? this.previewAudioUrl,
      stemPackage: stemPackage ?? this.stemPackage,
      salesRecords: salesRecords ?? this.salesRecords,
      auditionCount: auditionCount ?? this.auditionCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'track_id': trackId,
        'title': title,
        'producer_id': producerId,
        'producer_name': producerName,
        'producer_handle': producerHandle,
        'genre': genre,
        'bpm': bpm,
        'musical_key': musicalKey,
        'tags': tags,
        'price_in_credits': priceInCredits,
        'license_tier': licenseTier.toJson(),
        'status': status.toJson(),
        'preview_audio_url': previewAudioUrl,
        'stem_package': stemPackage.toJson(),
        'sales_records': salesRecords.map((record) => record.toJson()).toList(),
        'audition_count': auditionCount,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory ProducerBeatEntity.fromJson(Map<String, dynamic> json) {
    return ProducerBeatEntity(
      id: json['id'] as String? ?? '',
      trackId: json['track_id'] as String?,
      title: json['title'] as String? ?? 'Untitled Beat',
      producerId: json['producer_id'] as String? ?? 'current_user',
      producerName: json['producer_name'] as String? ?? 'You',
      producerHandle: json['producer_handle'] as String? ?? '@you',
      genre: json['genre'] as String? ?? 'Amapiano',
      bpm: json['bpm'] as int? ?? defaultBeatBpm,
      musicalKey: json['musical_key'] as String? ?? 'F# Minor',
      tags: (json['tags'] as List<dynamic>?)
              ?.map((tag) => tag.toString())
              .toList() ??
          const <String>[],
      priceInCredits: json['price_in_credits'] as int? ?? 10,
      licenseTier:
          BeatLicenseTier.fromJson(json['license_tier'] as String? ?? ''),
      status: BeatStatus.fromJson(json['status'] as String? ?? ''),
      previewAudioUrl: json['preview_audio_url'] as String? ?? '',
      stemPackage: json['stem_package'] is Map
          ? BeatStemPackage.fromJson(
              Map<String, dynamic>.from(json['stem_package'] as Map),
            )
          : const BeatStemPackage(),
      salesRecords: (json['sales_records'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((record) =>
                  BeatSaleRecord.fromJson(Map<String, dynamic>.from(record)))
              .toList() ??
          const <BeatSaleRecord>[],
      auditionCount: json['audition_count'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProducerBeatEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          genre == other.genre &&
          bpm == other.bpm &&
          musicalKey == other.musicalKey &&
          priceInCredits == other.priceInCredits &&
          licenseTier == other.licenseTier &&
          status == other.status &&
          auditionCount == other.auditionCount &&
          stemPackage == other.stemPackage &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        genre,
        bpm,
        musicalKey,
        priceInCredits,
        licenseTier,
        status,
        auditionCount,
        stemPackage,
        updatedAt,
      );
}
