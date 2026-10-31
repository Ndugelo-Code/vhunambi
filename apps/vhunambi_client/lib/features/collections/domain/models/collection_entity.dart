import 'package:flutter/foundation.dart';

/// Collection bundling taxonomy (REQ-COL-02 / Blueprint 13 §5).
///
/// A collection groups vault tracks into release shapes: `Single`, `EP`,
/// `Album` and `Concept Project`.
enum CollectionType {
  single,
  ep,
  album,
  conceptProject;

  /// Human readable label rendered by badges, rows and the split sheet.
  String get label => switch (this) {
    CollectionType.single => 'Single',
    CollectionType.ep => 'EP',
    CollectionType.album => 'Album',
    CollectionType.conceptProject => 'Concept Project',
  };

  /// Compact badge caption (`Concept Project` → `Concept`).
  String get badgeLabel => switch (this) {
    CollectionType.conceptProject => 'Concept',
    _ => label,
  };

  /// Recommended `(min, max)` track count for this release shape.
  (int, int) get recommendedRange => switch (this) {
    CollectionType.single => (1, 1),
    CollectionType.ep => (2, 7),
    CollectionType.album => (8, 20),
    CollectionType.conceptProject => (1, 30),
  };

  /// Persisted snake_case discriminator used by the Hive JSON payload.
  String toJson() => switch (this) {
    CollectionType.single => 'single',
    CollectionType.ep => 'ep',
    CollectionType.album => 'album',
    CollectionType.conceptProject => 'concept_project',
  };

  /// Tolerant reader — unknown or legacy payloads resolve to `Single`.
  static CollectionType fromJson(String value) => switch (value) {
    'ep' => CollectionType.ep,
    'album' => CollectionType.album,
    'concept_project' => CollectionType.conceptProject,
    _ => CollectionType.single,
  };
}

/// Immutable collaborator split-sheet entry (REQ-COL-03 / REQ-COL-SPLIT-01).
@immutable
class SplitParticipant {
  final String name;
  final String role;

  /// Ownership share, `0.0` – `100.0`.
  final double sharePercent;

  /// Platform creator identifier (e.g. `creator_cern`, `creator_fifi`), if registered.
  final String? creatorId;

  /// User handle (e.g. `@cern`, `@fifi`).
  final String? handle;

  /// Optional payout address or bank tag.
  final String? walletAddress;

  const SplitParticipant({
    required this.name,
    required this.role,
    required this.sharePercent,
    this.creatorId,
    this.handle,
    this.walletAddress,
  });

  SplitParticipant copyWith({
    String? name,
    String? role,
    double? sharePercent,
    String? creatorId,
    String? handle,
    String? walletAddress,
  }) {
    return SplitParticipant(
      name: name ?? this.name,
      role: role ?? this.role,
      sharePercent: sharePercent ?? this.sharePercent,
      creatorId: creatorId ?? this.creatorId,
      handle: handle ?? this.handle,
      walletAddress: walletAddress ?? this.walletAddress,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'role': role,
    'share_percent': sharePercent,
    if (creatorId != null) 'creator_id': creatorId,
    if (handle != null) 'handle': handle,
    if (walletAddress != null) 'wallet_address': walletAddress,
  };

  factory SplitParticipant.fromJson(Map<String, dynamic> json) {
    return SplitParticipant(
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? '',
      sharePercent: (json['share_percent'] as num?)?.toDouble() ?? 0.0,
      creatorId: json['creator_id'] as String?,
      handle: json['handle'] as String?,
      walletAddress: json['wallet_address'] as String?,
    );
  }

  /// `50%` / `12.5%` rendering contract used by the split-sheet table.
  String get shareLabel {
    final rounded = sharePercent.toStringAsFixed(2);
    final trimmed = rounded
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
    return '$trimmed%';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SplitParticipant &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          role == other.role &&
          sharePercent == other.sharePercent &&
          creatorId == other.creatorId &&
          handle == other.handle &&
          walletAddress == other.walletAddress;

  @override
  int get hashCode =>
      Object.hash(name, role, sharePercent, creatorId, handle, walletAddress);
}

/// Immutable user collection aggregate (REQ-COL-01).
///
/// A collection bundles vault track ids (`LibraryTrack.id`) with unified
/// release metadata and split-sheet attribution. Persisted through
/// `ICollectionRepository` — Hive `collectionsBoxKey` in production,
/// in-memory in headless tests.
@immutable
class CollectionEntity {
  final String id;
  final String title;
  final CollectionType type;
  final String genre;
  final String description;
  final DateTime? releaseDate;
  final String? coverImageUrl;

  /// Ordered list of `LibraryTrack.id` values.
  final List<String> trackIds;
  final List<SplitParticipant> participants;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CollectionEntity({
    required this.id,
    required this.title,
    this.type = CollectionType.ep,
    this.genre = '',
    this.description = '',
    this.releaseDate,
    this.coverImageUrl,
    this.trackIds = const <String>[],
    this.participants = const <SplitParticipant>[],
    required this.createdAt,
    required this.updatedAt,
  });

  // --- Computed Properties (REQ-COL-04) ---

  int get trackCount => trackIds.length;

  double get totalSharePercent =>
      participants.fold<double>(0.0, (sum, p) => sum + p.sharePercent);

  bool get isSplitBalanced => (totalSharePercent - 100.0).abs() < 0.01;

  String get typeLabel => type.label;

  /// `1 song` / `12 songs` label used by cards, rows and the split sheet.
  String get trackCountLabel =>
      trackCount == 1 ? '1 song' : '$trackCount songs';

  /// `true` when the bundle sits inside the type's recommended track range.
  bool get isWithinRecommendedRange {
    final (min, max) = type.recommendedRange;
    return trackCount >= min && trackCount <= max;
  }

  CollectionEntity copyWith({
    String? id,
    String? title,
    CollectionType? type,
    String? genre,
    String? description,
    DateTime? releaseDate,
    String? coverImageUrl,
    List<String>? trackIds,
    List<SplitParticipant>? participants,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CollectionEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      genre: genre ?? this.genre,
      description: description ?? this.description,
      releaseDate: releaseDate ?? this.releaseDate,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      trackIds: trackIds ?? this.trackIds,
      participants: participants ?? this.participants,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'type': type.toJson(),
    'genre': genre,
    'description': description,
    'release_date': releaseDate?.toIso8601String(),
    'cover_image_url': coverImageUrl,
    'track_ids': trackIds,
    'participants': participants.map((p) => p.toJson()).toList(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory CollectionEntity.fromJson(Map<String, dynamic> json) {
    final rawParticipants = json['participants'] as List<dynamic>?;
    return CollectionEntity(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      type: CollectionType.fromJson(json['type'] as String? ?? 'ep'),
      genre: json['genre'] as String? ?? '',
      description: json['description'] as String? ?? '',
      releaseDate: json['release_date'] == null
          ? null
          : DateTime.tryParse(json['release_date'] as String),
      coverImageUrl: json['cover_image_url'] as String?,
      trackIds:
          (json['track_ids'] as List<dynamic>?)?.cast<String>() ?? const [],
      participants:
          rawParticipants
              ?.whereType<Map<dynamic, dynamic>>()
              .map(
                (raw) =>
                    SplitParticipant.fromJson(Map<String, dynamic>.from(raw)),
              )
              .toList(growable: false) ??
          const <SplitParticipant>[],
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CollectionEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          type == other.type &&
          genre == other.genre &&
          description == other.description &&
          releaseDate == other.releaseDate &&
          coverImageUrl == other.coverImageUrl &&
          listEquals(trackIds, other.trackIds) &&
          listEquals(participants, other.participants) &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    type,
    genre,
    description,
    releaseDate,
    coverImageUrl,
    Object.hashAll(trackIds),
    Object.hashAll(participants),
    createdAt,
    updatedAt,
  );
}
