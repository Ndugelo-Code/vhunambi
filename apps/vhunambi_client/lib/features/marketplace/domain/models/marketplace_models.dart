import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../shared/models/track.dart';

/// The 12 curated African genres exposed by the marketplace filter engine
/// (Blueprint 05 §2.2 / REQ-MKT-05).
const List<String> marketplaceGenreCatalog = [
  'Amapiano',
  'Kwaito',
  'Gqom',
  'Maskandi',
  'Mbaqanga',
  'Marabi',
  'Bubblegum',
  'Afro House',
  'Afrobeats',
  'Afro Jazz',
  'Afro Soul',
  'Afro-Arabic',
];

/// Beat preview audition length used by the screenless player bridge.
const int beatPreviewDurationSeconds = 180;


/// 4-Pillar Multi-Talent Marketplace Category (Phase 39 REQ-MKT-CAT-01)
enum MarketplaceAssetCategory {
  all,
  beats,
  vocals,
  liveInstruments,
  voiceDnaAndPacks,
}

extension MarketplaceAssetCategoryExtension on MarketplaceAssetCategory {
  String get label => switch (this) {
    MarketplaceAssetCategory.all => 'All Assets',
    MarketplaceAssetCategory.beats => 'Beats & Instrumentals',
    MarketplaceAssetCategory.vocals => 'Vocal Hooks & Acapellas',
    MarketplaceAssetCategory.liveInstruments => 'Live Guitars, Sax & Loops',
    MarketplaceAssetCategory.voiceDnaAndPacks => 'Voice DNA & Packs',
  };

  IconData get icon => switch (this) {
    MarketplaceAssetCategory.all => PhosphorIconsRegular.squaresFour,
    MarketplaceAssetCategory.beats => PhosphorIconsRegular.waveform,
    MarketplaceAssetCategory.vocals => PhosphorIconsRegular.microphone,
    MarketplaceAssetCategory.liveInstruments => PhosphorIconsRegular.guitar,
    MarketplaceAssetCategory.voiceDnaAndPacks => PhosphorIconsRegular.fingerprint,
  };
}

/// Sellable instrumental beat listing (design.md §1.1).
@immutable
class BeatListingEntity {
  final String id;
  final String title;
  final String producerId;
  final String producerName;
  final String producerHandle;
  final String? producerAvatarUrl;
  final String genre;
  final int bpm;
  final String musicalKey;
  final int priceInCredits;
  final String previewAudioUrl;
  final String? stemZipUrl;
  final String licenseType;
  final int totalSales;
  final DateTime createdAt;
  final MarketplaceAssetCategory assetCategory;
  final AudioProvenanceType provenanceType;

  const BeatListingEntity({
    required this.id,
    required this.title,
    required this.producerId,
    required this.producerName,
    required this.producerHandle,
    this.producerAvatarUrl,
    required this.genre,
    required this.bpm,
    required this.musicalKey,
    required this.priceInCredits,
    required this.previewAudioUrl,
    this.stemZipUrl,
    this.licenseType = 'Non-Exclusive Commercial',
    this.totalSales = 0,
    required this.createdAt,
    this.assetCategory = MarketplaceAssetCategory.beats,
    this.provenanceType = AudioProvenanceType.humanDawMaster,
  });

  String get bpmLabel => '$bpm BPM';

  String get priceLabel => '⚡ $priceInCredits Credits';

  Duration get previewDuration =>
      const Duration(seconds: beatPreviewDurationSeconds);

  BeatListingEntity copyWith({
    String? id,
    String? title,
    String? producerId,
    String? producerName,
    String? producerHandle,
    String? producerAvatarUrl,
    String? genre,
    int? bpm,
    String? musicalKey,
    int? priceInCredits,
    String? previewAudioUrl,
    String? stemZipUrl,
    String? licenseType,
    int? totalSales,
    DateTime? createdAt,
    MarketplaceAssetCategory? assetCategory,
    AudioProvenanceType? provenanceType,
  }) {
    return BeatListingEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      producerId: producerId ?? this.producerId,
      producerName: producerName ?? this.producerName,
      producerHandle: producerHandle ?? this.producerHandle,
      producerAvatarUrl: producerAvatarUrl ?? this.producerAvatarUrl,
      genre: genre ?? this.genre,
      bpm: bpm ?? this.bpm,
      musicalKey: musicalKey ?? this.musicalKey,
      priceInCredits: priceInCredits ?? this.priceInCredits,
      previewAudioUrl: previewAudioUrl ?? this.previewAudioUrl,
      stemZipUrl: stemZipUrl ?? this.stemZipUrl,
      licenseType: licenseType ?? this.licenseType,
      totalSales: totalSales ?? this.totalSales,
      createdAt: createdAt ?? this.createdAt,
      assetCategory: assetCategory ?? this.assetCategory,
      provenanceType: provenanceType ?? this.provenanceType,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BeatListingEntity &&
        other.id == id &&
        other.title == title &&
        other.producerId == producerId &&
        other.producerName == producerName &&
        other.producerHandle == producerHandle &&
        other.producerAvatarUrl == producerAvatarUrl &&
        other.genre == genre &&
        other.bpm == bpm &&
        other.musicalKey == musicalKey &&
        other.priceInCredits == priceInCredits &&
        other.previewAudioUrl == previewAudioUrl &&
        other.stemZipUrl == stemZipUrl &&
        other.licenseType == licenseType &&
        other.totalSales == totalSales &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        producerId,
        producerName,
        producerHandle,
        producerAvatarUrl,
        genre,
        bpm,
        musicalKey,
        priceInCredits,
        previewAudioUrl,
        stemZipUrl,
        licenseType,
        totalSales,
        createdAt,
      );
}

/// Real-time marketplace filter dimensions (design.md §1.1 / REQ-MKT-05).
@immutable
class MarketplaceFilterState {
  /// Sentinel genre meaning "no genre restriction".
  static const String allGenres = 'All';

  final String searchQuery;
  final String genre;
  final int? minBpm;
  final int? maxBpm;
  final int? maxPriceCredits;
  final MarketplaceAssetCategory category;

  const MarketplaceFilterState({
    this.searchQuery = '',
    this.genre = allGenres,
    this.minBpm,
    this.maxBpm,
    this.maxPriceCredits,
    this.category = MarketplaceAssetCategory.beats,
  });

  bool get hasActiveFilters =>
      searchQuery.trim().isNotEmpty ||
      category != MarketplaceAssetCategory.beats ||
      genre != allGenres ||
      minBpm != null ||
      maxBpm != null ||
      maxPriceCredits != null;

  MarketplaceFilterState copyWith({
    String? searchQuery,
    String? genre,
    int? minBpm,
    int? maxBpm,
    int? maxPriceCredits,
    bool clearBpmRange = false,
    bool clearMaxPrice = false,
    MarketplaceAssetCategory? category,
  }) {
    return MarketplaceFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      genre: genre ?? this.genre,
      minBpm: clearBpmRange ? null : (minBpm ?? this.minBpm),
      maxBpm: clearBpmRange ? null : (maxBpm ?? this.maxBpm),
      maxPriceCredits:
          clearMaxPrice ? null : (maxPriceCredits ?? this.maxPriceCredits),
      category: category ?? this.category,
    );
  }

  /// Clears every filter dimension.
  MarketplaceFilterState cleared() => const MarketplaceFilterState();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MarketplaceFilterState &&
        other.searchQuery == searchQuery &&
        other.genre == genre &&
        other.minBpm == minBpm &&
        other.maxBpm == maxBpm &&
        other.maxPriceCredits == maxPriceCredits &&
        other.category == category;
  }

  @override
  int get hashCode =>
      Object.hash(searchQuery, genre, minBpm, maxBpm, maxPriceCredits, category);
}
