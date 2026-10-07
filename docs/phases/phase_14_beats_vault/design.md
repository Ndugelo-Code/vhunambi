# Phase 14 · Design — Producer Beats Vault & Beatstore Listing Cockpit

> **Phase:** 14  
> **Codename:** `beats-vault`  
> **Parent Blueprint:** `docs/phases/phase_14_beats_vault/blueprint.md`  
> **Parent Requirements:** `docs/phases/phase_14_beats_vault/requirements.md`  
> **Standard:** Production Dart 3.x / Flutter Riverpod 2.x  

---

## 1. Architecture Overview & Package Layout

```
lib/features/beats/
├── domain/
│   ├── models/
│   │   └── producer_beat_entity.dart        # Enums, StemPackage, SaleRecord & ProducerBeatEntity
│   └── repositories/
│       └── i_beat_repository.dart           # Pure abstract repository contract
├── data/
│   └── repositories/
│       ├── in_memory_beat_repository.dart   # Seeded double for headless unit & widget tests
│       └── beat_repository.dart             # Production Hive-backed repository with headless fallback
└── presentation/
    ├── providers/
    │   └── beats_provider.dart              # BeatsNotifier, filter & stats providers
    ├── views/
    │   ├── beats_vault_view.dart            # Primary /library?tab=beats screen
    │   └── beat_detail_cockpit_view.dart    # Detailed beat management & sales ledger cockpit
    └── widgets/
        ├── beat_card.dart                   # Responsive grid card
        ├── beat_list_tile.dart              # Dense list mode tile (Material-wrapped)
        ├── beat_status_badge.dart           # Draft / Published / Archived badge
        ├── beat_stats_banner.dart           # Producer analytics top card
        ├── beat_form_dialog.dart            # Create / Convert / Edit modal dialog
        ├── publish_beat_modal.dart          # Marketplace publish confirmation sheet
        └── stem_export_modal.dart           # Stems ZIP manifest download modal
```

---

## 2. Domain Models (`producer_beat_entity.dart`)

```dart
import 'package:flutter/foundation.dart';

/// Lifecycle and marketplace visibility status of a producer beat.
enum BeatStatus {
  draft,
  published,
  archived;

  String get label => switch (this) {
        BeatStatus.draft => 'Draft',
        BeatStatus.published => 'Published',
        BeatStatus.archived => 'Archived',
      };

  String toJson() => name;

  static BeatStatus fromJson(String value) {
    return BeatStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase().trim(),
      orElse: () => BeatStatus.draft,
    );
  }
}

/// Commercial licensing rights tiers offered for the beat.
enum BeatLicenseTier {
  nonExclusiveCommercial,
  exclusiveOwnership,
  syncLicense,
  personalLease;

  String get label => switch (this) {
        BeatLicenseTier.nonExclusiveCommercial => 'Non-Exclusive Commercial',
        BeatLicenseTier.exclusiveOwnership => 'Exclusive Ownership',
        BeatLicenseTier.syncLicense => 'Sync License',
        BeatLicenseTier.personalLease => 'Personal Lease',
      };

  int get defaultPriceCredits => switch (this) {
        BeatLicenseTier.nonExclusiveCommercial => 10,
        BeatLicenseTier.exclusiveOwnership => 50,
        BeatLicenseTier.syncLicense => 30,
        BeatLicenseTier.personalLease => 5,
      };

  String toJson() => name;

  static BeatLicenseTier fromJson(String value) {
    return BeatLicenseTier.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase().trim(),
      orElse: () => BeatLicenseTier.nonExclusiveCommercial,
    );
  }
}

/// Stems package availability and audio file manifests.
@immutable
class BeatStemPackage {
  final String? drumsUrl;
  final String? bassUrl;
  final String? melodyUrl;
  final String? otherUrl;
  final bool isSeparated;

  const BeatStemPackage({
    this.drumsUrl,
    this.bassUrl,
    this.melodyUrl,
    this.otherUrl,
    this.isSeparated = false,
  });

  int get stemCount => [drumsUrl, bassUrl, melodyUrl, otherUrl]
      .where((u) => u != null && u.isNotEmpty)
      .length;

  bool get hasAllStems => stemCount == 4;

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

  Map<String, dynamic> toJson() => {
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
  int get hashCode => Object.hash(drumsUrl, bassUrl, melodyUrl, otherUrl, isSeparated);
}

/// Historical ledger record of a beat license purchased by another creator.
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

  Map<String, dynamic> toJson() => {
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
      licenseTier: BeatLicenseTier.fromJson(json['license_tier'] as String? ?? ''),
      creditsEarned: json['credits_earned'] as int? ?? 0,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
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
  int get hashCode => Object.hash(saleId, buyerId, buyerHandle, licenseTier, creditsEarned, timestamp);
}

/// Primary Producer Beat aggregate entity.
@immutable
class ProducerBeatEntity {
  final String id;
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
    this.bpm = 112,
    this.musicalKey = 'F# Minor',
    this.tags = const [],
    this.priceInCredits = 10,
    this.licenseTier = BeatLicenseTier.nonExclusiveCommercial,
    this.status = BeatStatus.draft,
    this.previewAudioUrl = '',
    this.stemPackage = const BeatStemPackage(),
    this.salesRecords = const [],
    this.auditionCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPublished => status == BeatStatus.published;
  bool get isDraft => status == BeatStatus.draft;
  bool get isArchived => status == BeatStatus.archived;

  int get totalSales => salesRecords.length;
  int get totalEarningsCredits =>
      salesRecords.fold<int>(0, (sum, record) => sum + record.creditsEarned);

  String get bpmLabel => '$bpm BPM';
  String get priceLabel => '⚡ $priceInCredits Credits';
  String get statusLabel => status.label;
  String get keyLabel => musicalKey.isEmpty ? 'Key: N/A' : musicalKey;

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

  Map<String, dynamic> toJson() => {
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
        'sales_records': salesRecords.map((r) => r.toJson()).toList(),
        'audition_count': auditionCount,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory ProducerBeatEntity.fromJson(Map<String, dynamic> json) {
    return ProducerBeatEntity(
      id: json['id'] as String,
      trackId: json['track_id'] as String?,
      title: json['title'] as String? ?? 'Untitled Beat',
      producerId: json['producer_id'] as String? ?? 'current_user',
      producerName: json['producer_name'] as String? ?? 'You',
      producerHandle: json['producer_handle'] as String? ?? '@you',
      genre: json['genre'] as String? ?? 'Amapiano',
      bpm: json['bpm'] as int? ?? 112,
      musicalKey: json['musical_key'] as String? ?? 'F# Minor',
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      priceInCredits: json['price_in_credits'] as int? ?? 10,
      licenseTier: BeatLicenseTier.fromJson(json['license_tier'] as String? ?? ''),
      status: BeatStatus.fromJson(json['status'] as String? ?? ''),
      previewAudioUrl: json['preview_audio_url'] as String? ?? '',
      stemPackage: json['stem_package'] != null
          ? BeatStemPackage.fromJson(json['stem_package'] as Map<String, dynamic>)
          : const BeatStemPackage(),
      salesRecords: (json['sales_records'] as List<dynamic>?)
              ?.map((e) => BeatSaleRecord.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      auditionCount: json['audition_count'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
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
          status == other.status &&
          auditionCount == other.auditionCount &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(id, title, genre, bpm, musicalKey, priceInCredits, status, updatedAt);
}
```

---

## 3. Repositories

### 3.1 Interface (`i_beat_repository.dart`)

```dart
abstract class IBeatRepository {
  Future<List<ProducerBeatEntity>> getAllBeats();
  Future<ProducerBeatEntity?> getBeatById(String id);
  Future<void> saveBeat(ProducerBeatEntity beat);
  Future<void> deleteBeat(String id);
  Future<ProducerBeatEntity> publishBeat(String id);
  Future<ProducerBeatEntity> unpublishBeat(String id);
  Future<ProducerBeatEntity> recordSale(String id, BeatSaleRecord sale);
  Future<ProducerBeatEntity> incrementAuditions(String id);
  Future<void> clearAll();
}
```

### 3.2 In-Memory Double (`in_memory_beat_repository.dart`)
- Pre-seeds 3 realistic beats (Amapiano 112 BPM `Soshanguve Pulse`, Gqom 128 BPM `Durban Rush`, Kwaito 106 BPM `Sophiatown Bounce`).
- Implements sorting by `createdAt` descending.
- Thread-safe and synchronous execution wrapped in `Future.value()`.

### 3.3 Hive-Backed (`beat_repository.dart`)
- Key: `AppConstants.beatsBoxKey = 'vhunambi_beats'`.
- Internal helper: `_ensureBox()` verifies `Hive.isBoxOpen(AppConstants.beatsBoxKey)` and falls back to in-memory map if closed or uninitialized.
- Stores JSON serialized string maps.

---

## 4. Providers & Reactive State (`beats_provider.dart`)

```dart
enum BeatsSortOrder {
  newest,
  bpmAsc,
  bpmDesc,
  mostSales,
  highestEarnings,
}

@immutable
class BeatsVaultFilterState {
  final String searchQuery;
  final BeatStatus? statusFilter;
  final String? genreFilter;
  final BeatsSortOrder sortOrder;

  const BeatsVaultFilterState({
    this.searchQuery = '',
    this.statusFilter,
    this.genreFilter,
    this.sortOrder = BeatsSortOrder.newest,
  });

  BeatsVaultFilterState copyWith({
    String? searchQuery,
    BeatStatus? statusFilter,
    bool clearStatus = false,
    String? genreFilter,
    bool clearGenre = false,
    BeatsSortOrder? sortOrder,
  }) {
    return BeatsVaultFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: clearStatus ? null : (statusFilter ?? this.statusFilter),
      genreFilter: clearGenre ? null : (genreFilter ?? this.genreFilter),
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

@immutable
class BeatsVaultStats {
  final int totalBeats;
  final int publishedCount;
  final int draftCount;
  final int totalSalesCount;
  final int totalCreditsEarned;

  const BeatsVaultStats({
    required this.totalBeats,
    required this.publishedCount,
    required this.draftCount,
    required this.totalSalesCount,
    required this.totalCreditsEarned,
  });
}
```

### Providers
1. `beatRepositoryProvider`: Injects `IBeatRepository` (defaults to `BeatRepository()`, overridden in tests with `InMemoryBeatRepository`).
2. `beatsProvider`: `StateNotifierProvider<BeatsNotifier, List<ProducerBeatEntity>>`.
3. `beatsVaultFilterProvider`: `StateProvider<BeatsVaultFilterState>`.
4. `filteredBeatsVaultProvider`: `Provider<List<ProducerBeatEntity>>` filtering and sorting `beatsProvider` based on `beatsVaultFilterProvider`.
5. `beatsVaultStatsProvider`: `Provider<BeatsVaultStats>` aggregating sales, credits, and publication metrics.

---

## 5. UI Presentation & Component Tree

### 5.1 `BeatsVaultView` Tree
```
BeatsVaultView (ConsumerStatefulWidget)
└── Column
    ├── BeatStatsBanner (Producer metrics: Beats, Live, Sales, Earnings)
    ├── Padding (Search Strip & Controls)
    │   └── Row
    │       ├── Search TextField ("Search my beats...")
    │       ├── Status Chips Row (All, Published, Draft)
    │       ├── View Mode Toggle (Grid / List)
    │       └── [ + New Beat ] Button (Pill, AppColors.brandPrimary)
    └── Expanded
        └── if beats.isEmpty -> LibraryEmptyState (Category: beats)
            else if viewMode == grid -> _BeatsGrid
                 else -> _BeatsList
```

### 5.2 `BeatDetailCockpitView` Tree
```
BeatDetailCockpitView (ConsumerWidget)
└── Scaffold
    ├── AppBar (Back, Title, [⋮ Actions])
    └── SingleChildScrollView (max-width 880px centered)
        └── Column
            ├── Hero Section
            │   ├── 160×160 Squircle Artwork (with BPM/Key badges overlay)
            │   └── Title, Producer, Genre, Tags, [▶ Audition]
            ├── Marketplace Status Section
            │   └── Card (Status Pill, Price, Tier, [Publish / Switch to Draft] Button)
            ├── Stems Package Section
            │   └── Card (4 Stem status chips, [⭳ Export Stems Bundle] CTA)
            └── Sales & License Ledger Section
                └── Card (List of recent BeatSaleRecord rows)
```

---

## 6. Token Bindings

```dart
// Colors
AppColors.surfaceCanvas       // Root scaffold background (#0A0A0C)
AppColors.surfaceElevated     // Cards and tiles background (#141418)
AppColors.surfaceSecondary    // Inset search and chips (#1B1B22)
AppColors.surfaceModal        // Dialogs & sheets (#16161C)
AppColors.borderSubtle        // Card borders (#2D2D38)
AppColors.brandPrimary        // Buttons & highlights (#F97316)
AppColors.brandContrast       // Black text on brand buttons (#000000)
AppColors.success             // Published status badge (#10B981)
AppColors.badgeCyan           // BPM & Key tag badges (#06B6D4)
AppColors.badgeCyanBg         // BPM & Key tag background

// Typography
AppTypography.titleLarge      // Section & screen headers
AppTypography.titleMedium     // Card titles
AppTypography.bodyLarge       // Descriptions
AppTypography.bodySmall       // Secondary metadata
AppTypography.caption         // Subtitles and timestamps
AppTypography.badge           // Pill badges

// Radii
AppRadius.cardBorder          // Card corners (16px)
AppRadius.inputBorder         // Inputs (12px)
AppRadius.pillBorder          // Action pills (9999px)
AppRadius.modalBorder         // Sheets & dialogs (24px)
AppRadius.squircle            // Squircle artworks (14px)
```
