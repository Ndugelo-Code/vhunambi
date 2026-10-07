import 'package:flutter/foundation.dart';

/// Immutable user playlist aggregate (REQ-PL-01).
///
/// Persisted through `IPlaylistRepository` — Hive `playlistsBoxKey` in
/// production, in-memory in headless tests.
@immutable
class PlaylistEntity {
  final String id;
  final String title;
  final String description;
  final String? coverImageUrl;
  final List<String> trackIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPublic;

  const PlaylistEntity({
    required this.id,
    required this.title,
    this.description = '',
    this.coverImageUrl,
    this.trackIds = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isPublic = true,
  });

  int get trackCount => trackIds.length;

  bool get isEmpty => trackIds.isEmpty;

  /// `1 song` / `12 songs` label used by the vault and picker tiles.
  String get trackCountLabel => trackCount == 1 ? '1 song' : '$trackCount songs';

  PlaylistEntity copyWith({
    String? id,
    String? title,
    String? description,
    String? coverImageUrl,
    List<String>? trackIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPublic,
  }) {
    return PlaylistEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      trackIds: trackIds ?? this.trackIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPublic: isPublic ?? this.isPublic,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'cover_image_url': coverImageUrl,
        'track_ids': trackIds,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'is_public': isPublic,
      };

  factory PlaylistEntity.fromJson(Map<String, dynamic> json) {
    return PlaylistEntity(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      coverImageUrl: json['cover_image_url'] as String?,
      trackIds:
          (json['track_ids'] as List<dynamic>?)?.cast<String>() ?? const [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isPublic: json['is_public'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaylistEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          description == other.description &&
          coverImageUrl == other.coverImageUrl &&
          listEquals(trackIds, other.trackIds) &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          isPublic == other.isPublic;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        description,
        coverImageUrl,
        Object.hashAll(trackIds),
        createdAt,
        updatedAt,
        isPublic,
      );
}
