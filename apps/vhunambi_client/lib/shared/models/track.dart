import 'package:flutter/foundation.dart';

@immutable
class Track {
  final String id;
  final String title;
  final String creatorName;
  final String? creatorAvatarUrl;
  final String genre;
  final String language;
  final Duration duration;
  final String? audioUrl;
  final String? coverUrl;
  final int likeCount;
  final int playCount;
  final bool isNew;
  final int? trendingRank;

  /// Optional mood tag powering the Explore mood filter engine (Blueprint 01 §5.2).
  final String? mood;

  /// Optional creator handle (e.g. `@sigwa_inaf`) rendered in Explore footers.
  final String? creatorHandle;

  const Track({
    required this.id,
    required this.title,
    required this.creatorName,
    this.creatorAvatarUrl,
    required this.genre,
    this.language = 'English',
    required this.duration,
    this.audioUrl,
    this.coverUrl,
    this.likeCount = 0,
    this.playCount = 0,
    this.isNew = false,
    this.trendingRank,
    this.mood,
    this.creatorHandle,
  });

  /// Handle label with a deterministic fallback derived from [creatorName].
  String get handleLabel {
    final handle = creatorHandle;
    if (handle != null && handle.isNotEmpty) return handle;
    final slug = creatorName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return '@$slug';
  }

  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
