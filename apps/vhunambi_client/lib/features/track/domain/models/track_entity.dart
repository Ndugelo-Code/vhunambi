import 'package:flutter/foundation.dart';
import '../../../../shared/models/track.dart';

/// A finished studio master returned by the audio synthesis pipeline
/// (`completed_track` inside a WebSocket `pipeline_event` frame, Phase 10).
@immutable
class TrackEntity {
  final String id;
  final String title;
  final String genre;
  final String language;
  final Duration duration;

  /// Signed CDN url of the rendered MP3 master consumed by the stem downloader.
  final String masterMp3Url;

  final String? coverUrl;
  final String? lyrics;

  const TrackEntity({
    required this.id,
    required this.title,
    required this.genre,
    this.language = 'English',
    required this.duration,
    required this.masterMp3Url,
    this.coverUrl,
    this.lyrics,
  });

  /// Tolerant decoder: a malformed frame must never crash the pipeline socket.
  factory TrackEntity.fromJson(Map<String, dynamic> json) {
    return TrackEntity(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      genre: json['genre'] as String? ?? 'Afro House',
      language: json['language'] as String? ?? 'English',
      duration: Duration(
        seconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      ),
      masterMp3Url: json['master_mp3_url'] as String? ?? '',
      coverUrl: json['cover_url'] as String?,
      lyrics: json['lyrics'] as String?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'genre': genre,
        'language': language,
        'duration_seconds': duration.inSeconds,
        'master_mp3_url': masterMp3Url,
        'cover_url': coverUrl,
        'lyrics': lyrics,
      };

  /// `mm:ss` rendering contract shared with the completion notification.
  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Bridges this finished master into the global persistent audio player model.
  Track toTrack() {
    return Track(
      id: id,
      title: title,
      creatorName: 'AI Studio',
      genre: genre,
      language: language,
      duration: duration,
      audioUrl: masterMp3Url,
      coverUrl: coverUrl,
      isNew: true,
    );
  }

  TrackEntity copyWith({
    String? id,
    String? title,
    String? genre,
    String? language,
    Duration? duration,
    String? masterMp3Url,
    String? coverUrl,
    String? lyrics,
  }) {
    return TrackEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      genre: genre ?? this.genre,
      language: language ?? this.language,
      duration: duration ?? this.duration,
      masterMp3Url: masterMp3Url ?? this.masterMp3Url,
      coverUrl: coverUrl ?? this.coverUrl,
      lyrics: lyrics ?? this.lyrics,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          genre == other.genre &&
          language == other.language &&
          duration == other.duration &&
          masterMp3Url == other.masterMp3Url &&
          coverUrl == other.coverUrl &&
          lyrics == other.lyrics;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        genre,
        language,
        duration,
        masterMp3Url,
        coverUrl,
        lyrics,
      );

  @override
  String toString() => 'TrackEntity($id, $title)';
}
