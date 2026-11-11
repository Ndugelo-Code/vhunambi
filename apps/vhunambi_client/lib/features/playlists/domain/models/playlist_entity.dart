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
  final String? shareCode;
  final String? shareUrl;

  const PlaylistEntity({
    required this.id,
    required this.title,
    this.description = '',
    this.coverImageUrl,
    this.trackIds = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isPublic = true,
    this.shareCode,
    this.shareUrl,
  });

  int get trackCount => trackIds.length;

  bool get isEmpty => trackIds.isEmpty;

  /// `1 song` / `12 songs` label used by the vault and picker tiles.
  String get trackCountLabel =>
      trackCount == 1 ? '1 song' : '$trackCount songs';

  PlaylistEntity copyWith({
    String? id,
    String? title,
    String? description,
    String? coverImageUrl,
    List<String>? trackIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPublic,
    String? shareCode,
    String? shareUrl,
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
      shareCode: shareCode ?? this.shareCode,
      shareUrl: shareUrl ?? this.shareUrl,
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
    if (shareCode != null) 'share_code': shareCode,
    if (shareUrl != null) 'share_url': shareUrl,
  };

  factory PlaylistEntity.fromJson(Map<String, dynamic> json) {
    final rawTrackIds = json['track_ids'] ?? json['trackIds'];
    final parsedTrackIds = rawTrackIds is List
        ? rawTrackIds.map((e) => e.toString()).toList(growable: false)
        : const <String>[];
    final createdAtRaw = (json['created_at'] ?? json['createdAt'])?.toString();
    final updatedAtRaw = (json['updated_at'] ?? json['updatedAt'])?.toString();
    return PlaylistEntity(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Untitled Playlist').toString(),
      description: json['description'] as String? ?? '',
      coverImageUrl:
          (json['cover_image_url'] ?? json['coverImageUrl']) as String?,
      trackIds: parsedTrackIds,
      createdAt: createdAtRaw != null
          ? (DateTime.tryParse(createdAtRaw) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: updatedAtRaw != null
          ? (DateTime.tryParse(updatedAtRaw) ?? DateTime.now())
          : DateTime.now(),
      isPublic: (json['is_public'] ?? json['isPublic']) as bool? ?? true,
      shareCode: (json['share_code'] ?? json['shareCode']) as String?,
      shareUrl: (json['share_url'] ?? json['shareUrl']) as String?,
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
          isPublic == other.isPublic &&
          shareCode == other.shareCode &&
          shareUrl == other.shareUrl;

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
    shareCode,
    shareUrl,
  );
}
