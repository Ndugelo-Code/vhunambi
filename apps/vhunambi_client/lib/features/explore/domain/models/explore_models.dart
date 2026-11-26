import 'package:flutter/foundation.dart';

/// Explore discovery sub-navigation tabs (REQ-EXP-02).
enum ExploreTab { discover, forYou, following }

/// Catalog ordering applied by the Explore filter engine (REQ-EXP-08).
enum ExploreSortBy { newest, mostLiked }

/// In-modal TikTok filter tabs for Kinetic Reels (REQ-EXP-REEL-TABS-01).
enum ReelFeedTab { trending, forYou, following, newest }

/// Category tabs for the dedicated TikTok search view (REQ-EXP-SEARCH-05).
enum ExploreSearchCategory { top, songs, reels, creators }

/// Public creator identity rendered by the Explore Featured Creators deck.
/// Reference: `docs/phases/phase_05_explore_feed/design.md` §1.2
@immutable
class CreatorProfile {
  final String id;
  final String name;
  final String handle;
  final String initials;
  final int trackCount;
  final String? avatarUrl;
  final List<String> primaryGenres;
  final bool isVerified;

  const CreatorProfile({
    required this.id,
    required this.name,
    required this.handle,
    required this.initials,
    required this.trackCount,
    this.avatarUrl,
    this.primaryGenres = const [],
    this.isVerified = false,
  });

  factory CreatorProfile.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] ?? json['displayName'] ?? 'Creator').toString();
    final rawHandle = (json['handle'] ?? '').toString().trim();
    final handle = rawHandle.isEmpty
        ? '@${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}'
        : (rawHandle.startsWith('@') ? rawHandle : '@$rawHandle');
    final rawInitials = (json['initials'] ?? '').toString().trim();
    final initials = rawInitials.isNotEmpty
        ? rawInitials
        : (name.length >= 2 ? name.substring(0, 2).toUpperCase() : 'VH');
    final genresRaw = json['primaryGenres'];
    final genres = genresRaw is List
        ? genresRaw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : const <String>[];
    return CreatorProfile(
      id: (json['id'] ?? '').toString(),
      name: name,
      handle: handle,
      initials: initials,
      trackCount: (json['trackCount'] as num?)?.toInt() ?? 0,
      avatarUrl: json['avatarUrl'] as String?,
      primaryGenres: List<String>.unmodifiable(genres),
      isVerified: json['isVerified'] as bool? ?? false,
    );
  }

  String get trackCountLabel => '$trackCount songs';

  /// Primary genre label shown under the creator name.
  String get primaryGenreLabel =>
      primaryGenres.isEmpty ? 'Artist' : primaryGenres.first;

  CreatorProfile copyWith({
    String? id,
    String? name,
    String? handle,
    String? initials,
    int? trackCount,
    String? avatarUrl,
    List<String>? primaryGenres,
    bool? isVerified,
  }) {
    return CreatorProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      handle: handle ?? this.handle,
      initials: initials ?? this.initials,
      trackCount: trackCount ?? this.trackCount,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      primaryGenres: primaryGenres ?? this.primaryGenres,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CreatorProfile &&
        other.id == id &&
        other.name == name &&
        other.handle == handle &&
        other.initials == initials &&
        other.trackCount == trackCount &&
        other.avatarUrl == avatarUrl &&
        listEquals(other.primaryGenres, primaryGenres) &&
        other.isVerified == isVerified;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    handle,
    initials,
    trackCount,
    avatarUrl,
    Object.hashAll(primaryGenres),
    isVerified,
  );
}

/// Immutable mood chip descriptor: emoji-tagged [label] + filter [value].
@immutable
class ExploreMoodOption {
  final String label;
  final String value;

  const ExploreMoodOption(this.label, this.value);
}

/// Sentinels for the unfiltered genre / language selection.
const String exploreAllFilter = 'All';

/// The 12 curated African musical heritage genres (REQ-EXP-07).
const List<String> exploreGenreCatalog = [
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

/// The 10 curated mood filter chips (REQ-EXP-08 / STD-UIUX-001 emoji-free).
const List<ExploreMoodOption> exploreMoodCatalog = [
  ExploreMoodOption('Uplifting', 'Uplifting'),
  ExploreMoodOption('Melancholic', 'Melancholic'),
  ExploreMoodOption('Energetic', 'Energetic'),
  ExploreMoodOption('Romantic', 'Romantic'),
  ExploreMoodOption('Peaceful', 'Peaceful'),
  ExploreMoodOption('Angry', 'Angry'),
  ExploreMoodOption('Nostalgic', 'Nostalgic'),
  ExploreMoodOption('Mysterious', 'Mysterious'),
  ExploreMoodOption('Party', 'Party'),
  ExploreMoodOption('Dark', 'Dark'),
];

/// South African official languages supported by the language selector.
const List<String> exploreLanguageCatalog = [
  'isiZulu',
  'isiXhosa',
  'Afrikaans',
  'English',
  'Sepedi',
  'Setswana',
  'Sesotho',
  'Xitsonga',
  'siSwati',
  'Tshivenḓa',
];
