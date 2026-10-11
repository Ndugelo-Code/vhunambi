import 'package:flutter/foundation.dart';
import '../../../content_studio/domain/models/song_metadata_dna.dart';

/// Context packaging a source reel for branching / remixing (REQ-RMX-02).
@immutable
class StemRemixContext {
  final String parentClipId;
  final String parentCreatorUsername;
  final String parentCreatorDisplayName;
  final String parentTrackTitle;
  final String parentCoverArtUrl;
  final SongMetadataDna? originalDna;

  const StemRemixContext({
    required this.parentClipId,
    required this.parentCreatorUsername,
    required this.parentCreatorDisplayName,
    required this.parentTrackTitle,
    required this.parentCoverArtUrl,
    this.originalDna,
  });

  /// Standard social attribution lineage text.
  String get attributionLineage =>
      '🔁 Remixed from @$parentCreatorUsername\'s "$parentTrackTitle"';

  Map<String, dynamic> toJson() => {
        'parentClipId': parentClipId,
        'parentCreatorUsername': parentCreatorUsername,
        'parentCreatorDisplayName': parentCreatorDisplayName,
        'parentTrackTitle': parentTrackTitle,
        'parentCoverArtUrl': parentCoverArtUrl,
        if (originalDna != null) 'originalDna': originalDna!.toJson(),
      };

  factory StemRemixContext.fromJson(Map<String, dynamic> json) {
    return StemRemixContext(
      parentClipId: json['parentClipId'] as String,
      parentCreatorUsername: json['parentCreatorUsername'] as String,
      parentCreatorDisplayName: json['parentCreatorDisplayName'] as String? ??
          json['parentCreatorUsername'] as String,
      parentTrackTitle: json['parentTrackTitle'] as String,
      parentCoverArtUrl: json['parentCoverArtUrl'] as String? ?? '',
      originalDna: json['originalDna'] != null
          ? SongMetadataDna.fromJson(
              json['originalDna'] as Map<String, dynamic>)
          : null,
    );
  }
}
