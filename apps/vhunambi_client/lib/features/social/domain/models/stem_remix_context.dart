import 'package:flutter/foundation.dart';
import '../../../collections/domain/models/collection_entity.dart';
import '../../../content_studio/domain/models/song_metadata_dna.dart';

/// Creation mode under which a remix was authored (Phase 37 REQ-RMX-MODEL-01).
enum RemixCreationMode {
  openVerseVocal('Open Verse Vocal', 'vocal'),
  beatStemFlip('Beat & Drum Flip', 'beat_flip'),
  aiStudioRemix('Full Studio Remix', 'studio');

  const RemixCreationMode(this.label, this.wireValue);
  final String label;
  final String wireValue;

  static RemixCreationMode fromWire(String? wire) {
    if (wire == null) return RemixCreationMode.aiStudioRemix;
    return RemixCreationMode.values.firstWhere(
      (m) => m.wireValue == wire || m.name == wire,
      orElse: () => RemixCreationMode.aiStudioRemix,
    );
  }
}

/// Context packaging a source reel for branching / remixing (REQ-RMX-02, Phase 37).
@immutable
class StemRemixContext {
  final String parentClipId;
  final String parentCreatorUsername;
  final String parentCreatorDisplayName;
  final String parentTrackTitle;
  final String parentCoverArtUrl;
  final String? parentCreatorId;
  final RemixCreationMode creationMode;
  final int remixGenerationDepth;
  final List<SplitParticipant> coCreationSplits;
  final SongMetadataDna? originalDna;

  const StemRemixContext({
    required this.parentClipId,
    required this.parentCreatorUsername,
    required this.parentCreatorDisplayName,
    required this.parentTrackTitle,
    required this.parentCoverArtUrl,
    this.parentCreatorId,
    this.creationMode = RemixCreationMode.aiStudioRemix,
    this.remixGenerationDepth = 1,
    this.coCreationSplits = const [],
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
    'parentCreatorId': parentCreatorId,
    'creationMode': creationMode.wireValue,
    'remixGenerationDepth': remixGenerationDepth,
    'coCreationSplits': coCreationSplits.map((s) => s.toJson()).toList(),
    if (originalDna != null) 'originalDna': originalDna!.toJson(),
  };

  factory StemRemixContext.fromJson(Map<String, dynamic> json) {
    return StemRemixContext(
      parentClipId: json['parentClipId'] as String,
      parentCreatorUsername: json['parentCreatorUsername'] as String,
      parentCreatorDisplayName:
          json['parentCreatorDisplayName'] as String? ??
          json['parentCreatorUsername'] as String,
      parentTrackTitle: json['parentTrackTitle'] as String,
      parentCoverArtUrl: json['parentCoverArtUrl'] as String? ?? '',
      parentCreatorId: json['parentCreatorId'] as String?,
      creationMode: RemixCreationMode.fromWire(json['creationMode'] as String?),
      remixGenerationDepth:
          (json['remixGenerationDepth'] as num?)?.toInt() ?? 1,
      coCreationSplits: (json['coCreationSplits'] as List<dynamic>? ?? const [])
          .map(
            (s) =>
                SplitParticipant.fromJson(Map<String, dynamic>.from(s as Map)),
          )
          .toList(),
      originalDna: json['originalDna'] is Map
          ? SongMetadataDna.fromJson(
              Map<String, dynamic>.from(json['originalDna'] as Map),
            )
          : null,
    );
  }
}
