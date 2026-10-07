import 'package:flutter/foundation.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/models/track.dart';

/// Library & User Asset Vault domain taxonomy.
/// Reference: docs/foundation_blueprints/04_LIBRARY_VAULT_SPEC.md
enum LibraryCategory {
  songs,
  playlists,
  collections,
  beats,
  licensing,
  trash,
}

/// Vault rendering mode: dense list rows vs. 2-column square grid cards.
enum LibraryViewMode {
  list,
  grid,
}

/// Offline cache integrity state for a vaulted audio asset.
enum TrackSyncStatus {
  synced,
  downloading,
  cachedLocally,
  cloudOnly,
  error,
}

/// Vault ordering applied by the populated asset list.
/// Additive extension backing the header overflow control of Blueprint 04 §1.1.
enum LibrarySortOrder {
  newestFirst,
  oldestFirst,
  titleAscending,
}

/// Local vs. cloud presence filter backing the `🎛️ Filter` control (Blueprint 04 §3.2).
enum LibrarySyncFilter {
  any,
  offlineOnly,
  cloudOnly,
}

const List<String> _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Immutable user vault audio asset.
/// Mirrors `CachedTrackEntity` from Blueprint 04 §4.1 with the presentation
/// contract defined in `docs/phases/phase_04_library_vault/design.md`.
@immutable
class LibraryTrack {
  final String id;
  final String title;
  final String creatorName;
  final String genre;
  final String language;
  final int durationSeconds;
  final String remoteAudioUrl;
  final String? localAudioFilePath;
  final String? coverImageUrl;
  final DateTime createdAt;
  final String licenseType;
  final bool isDeleted;
  final DateTime? deletedAt;
  final TrackSyncStatus syncStatus;

  /// True for standalone instrumental beats listed in the `🛍️ Beats` tab.
  final bool isInstrumental;

  const LibraryTrack({
    required this.id,
    required this.title,
    required this.creatorName,
    required this.genre,
    required this.language,
    required this.durationSeconds,
    required this.remoteAudioUrl,
    this.localAudioFilePath,
    this.coverImageUrl,
    required this.createdAt,
    this.licenseType = 'Commercial',
    this.isDeleted = false,
    this.deletedAt,
    this.syncStatus = TrackSyncStatus.cloudOnly,
    this.isInstrumental = false,
  });

  /// True when a local audio copy exists inside the device vault directory.
  bool get isOfflineAvailable => localAudioFilePath != null;

  Duration get duration => Duration(seconds: durationSeconds);

  /// `mm:ss` rendering contract (REQ-LIB-05).
  String get formattedDuration {
    final minutes = durationSeconds ~/ 60;
    final seconds = (durationSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Human readable creation timestamp, e.g. `Created 2 hours ago`.
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
    if (days == 1) return 'Created yesterday';
    if (days < 30) return 'Created $days days ago';

    final month = _monthNames[createdAt.month - 1];
    return 'Created $month ${createdAt.day}, ${createdAt.year}';
  }

  /// Public web preview link used by the `Share Song` vault action.
  String get publicShareUrl => '${AppConstants.defaultOrigin}/track/$id';

  /// Ownership certificate reference displayed by the licensing action.
  String get licenseCertificateId =>
      'VHB-${licenseType.toUpperCase()}-${id.toUpperCase()}';

  LibraryTrack copyWith({
    String? id,
    String? title,
    String? creatorName,
    String? genre,
    String? language,
    int? durationSeconds,
    String? remoteAudioUrl,
    String? localAudioFilePath,
    bool clearLocalAudioFilePath = false,
    String? coverImageUrl,
    DateTime? createdAt,
    String? licenseType,
    bool? isDeleted,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    TrackSyncStatus? syncStatus,
    bool? isInstrumental,
  }) {
    return LibraryTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      creatorName: creatorName ?? this.creatorName,
      genre: genre ?? this.genre,
      language: language ?? this.language,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      remoteAudioUrl: remoteAudioUrl ?? this.remoteAudioUrl,
      localAudioFilePath: clearLocalAudioFilePath
          ? null
          : (localAudioFilePath ?? this.localAudioFilePath),
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      createdAt: createdAt ?? this.createdAt,
      licenseType: licenseType ?? this.licenseType,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      syncStatus: syncStatus ?? this.syncStatus,
      isInstrumental: isInstrumental ?? this.isInstrumental,
    );
  }

  /// Bridges a vault asset into the global persistent player queue model.
  Track toTrack() {
    return Track(
      id: id,
      title: title,
      creatorName: creatorName,
      genre: genre,
      language: language,
      duration: duration,
      audioUrl: localAudioFilePath ?? remoteAudioUrl,
      coverUrl: coverImageUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LibraryTrack &&
        other.id == id &&
        other.title == title &&
        other.creatorName == creatorName &&
        other.genre == genre &&
        other.language == language &&
        other.durationSeconds == durationSeconds &&
        other.remoteAudioUrl == remoteAudioUrl &&
        other.localAudioFilePath == localAudioFilePath &&
        other.coverImageUrl == coverImageUrl &&
        other.createdAt == createdAt &&
        other.licenseType == licenseType &&
        other.isDeleted == isDeleted &&
        other.deletedAt == deletedAt &&
        other.syncStatus == syncStatus &&
        other.isInstrumental == isInstrumental;
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        creatorName,
        genre,
        language,
        durationSeconds,
        remoteAudioUrl,
        localAudioFilePath,
        coverImageUrl,
        createdAt,
        licenseType,
        isDeleted,
        deletedAt,
        syncStatus,
        isInstrumental,
      );

}
