import 'package:flutter/foundation.dart';
import '../../../../shared/models/track.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/master_media_object.dart';
import 'package:vhunambi_client/features/content_studio/domain/models/song_metadata_dna.dart';
import 'package:vhunambi_client/features/player/domain/models/stem_mixer_state.dart';

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

  /// Optional signed CDN url of the separated stems bundle (ZIP).
  final String? stemsUrl;

  /// Map of individual separated stems (vocals, drums, bass, melodic) for Pocket DAW live mixing.
  final Map<StemType, String>? stemUrls;

  final String? coverUrl;
  final String? lyrics;

  const TrackEntity({
    required this.id,
    required this.title,
    required this.genre,
    this.language = 'English',
    required this.duration,
    required this.masterMp3Url,
    this.stemsUrl,
    this.stemUrls,
    this.coverUrl,
    this.lyrics,
  });

  /// Tolerant decoder: a malformed frame must never crash the pipeline socket.
  factory TrackEntity.fromJson(Map<String, dynamic> json) {
    Map<StemType, String>? parsedStemUrls;
    final rawStems = json['stem_urls'] ?? json['stemUrls'];
    if (rawStems is Map) {
      parsedStemUrls = <StemType, String>{};
      rawStems.forEach((key, val) {
        if (val != null) {
          parsedStemUrls![stemTypeFromWireString(key.toString())] = val.toString();
        }
      });
    }

    return TrackEntity(
      id: (json['id'] ?? json['generationId'] ?? json['generation_id'])
              as String? ??
          '',
      title: (json['title'] ?? json['trackTitle'] ?? json['track_title'])
              as String? ??
          'Untitled',
      genre: json['genre'] as String? ?? 'Afro House',
      language: json['language'] as String? ?? 'English',
      duration: Duration(
        seconds:
            ((json['duration_seconds'] ?? json['durationSec']) as num?)
                ?.toInt() ??
            0,
      ),
      masterMp3Url:
          (json['master_mp3_url'] ?? json['masterMp3Url'] ?? json['audio_url'])
              as String? ??
          '',
      stemsUrl: (json['stems_url'] ??
              json['stems_zip_url'] ??
              json['stemsZipUrl'])
          as String?,
      stemUrls: parsedStemUrls,
      coverUrl: (json['cover_url'] ?? json['coverUrl']) as String?,
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
        'stems_url': stemsUrl,
        if (stemUrls != null)
          'stem_urls': stemUrls!.map(
            (k, v) => MapEntry(stemTypeToWireString(k), v),
          ),
        'cover_url': coverUrl,
        'lyrics': lyrics,
      };

  /// Whether an archive of stems is available for download.
  bool get hasStems => stemsUrl != null && stemsUrl!.isNotEmpty;

  /// Whether all 4 isolated stems are available for true multi-stem Pocket DAW auditioning.
  bool get hasRealStems =>
      stemUrls != null &&
      stemUrls!.containsKey(StemType.vocals) &&
      stemUrls!.containsKey(StemType.drums) &&
      stemUrls!.containsKey(StemType.bass) &&
      stemUrls!.containsKey(StemType.melody) &&
      (stemUrls![StemType.vocals]?.isNotEmpty ?? false) &&
      (stemUrls![StemType.drums]?.isNotEmpty ?? false) &&
      (stemUrls![StemType.bass]?.isNotEmpty ?? false) &&
      (stemUrls![StemType.melody]?.isNotEmpty ?? false);

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
      stemUrls: stemUrls,
    );
  }

  /// Converts this finished master into canonical SongMetadataDna for the Content Studio.
  SongMetadataDna toSongMetadataDna() {
    return SongMetadataDna.fromTrackInfo(
      id: id,
      title: title,
      genre: genre,
      language: language,
      durationSec: duration.inSeconds,
      lyrics: lyrics,
      coverUrl: coverUrl,
    );
  }

  TrackEntity copyWith({
    String? id,
    String? title,
    String? genre,
    String? language,
    Duration? duration,
    String? masterMp3Url,
    String? stemsUrl,
    Map<StemType, String>? stemUrls,
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
      stemsUrl: stemsUrl ?? this.stemsUrl,
      stemUrls: stemUrls ?? this.stemUrls,
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
          stemsUrl == other.stemsUrl &&
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
        stemsUrl,
        coverUrl,
        lyrics,
      );

  @override
  String toString() => 'TrackEntity($id, $title)';
}
