import 'package:flutter/foundation.dart';

/// Ownership licence attached to a generated track (REQ-TRK-03).
enum LicenseType { personal, commercial }

/// Isolated performance stem produced by the Stem Separation Lab (REQ-TRK-09).
@immutable
class StemTrackEntity {
  final String id;
  final String name;
  final String audioUrl;
  final Duration duration;
  final bool isMuted;
  final bool isSoloed;
  final double volume;

  const StemTrackEntity({
    required this.id,
    required this.name,
    required this.audioUrl,
    required this.duration,
    this.isMuted = false,
    this.isSoloed = false,
    this.volume = 1.0,
  });

  StemTrackEntity copyWith({
    bool? isMuted,
    bool? isSoloed,
    double? volume,
  }) {
    return StemTrackEntity(
      id: id,
      name: name,
      audioUrl: audioUrl,
      duration: duration,
      isMuted: isMuted ?? this.isMuted,
      isSoloed: isSoloed ?? this.isSoloed,
      volume: volume ?? this.volume,
    );
  }
}

/// 4-step stem isolation FSM (REQ-TRK-09).
enum StemSeparationStatus {
  idle,
  isolatingVocals,
  isolatingDrums,
  isolatingBass,
  isolatingInstrumental,
  ready,
  error,
}

@immutable
class StemSeparationState {
  final StemSeparationStatus status;
  final double progress;
  final List<StemTrackEntity> stems;
  final String? errorMessage;

  const StemSeparationState({
    this.status = StemSeparationStatus.idle,
    this.progress = 0.0,
    this.stems = const [],
    this.errorMessage,
  });

  bool get isProcessing =>
      status != StemSeparationStatus.idle &&
      status != StemSeparationStatus.ready &&
      status != StemSeparationStatus.error;

  bool get isReady => status == StemSeparationStatus.ready;

  String get stepLabel {
    return switch (status) {
      StemSeparationStatus.isolatingVocals => 'Isolating Vocals (1/4)...',
      StemSeparationStatus.isolatingDrums =>
        'Extracting Drum Transient (2/4)...',
      StemSeparationStatus.isolatingBass =>
        'Filtering Sub-Bass / Log Drums (3/4)...',
      StemSeparationStatus.isolatingInstrumental =>
        'Synthesizing Backing Instrumental (4/4)...',
      StemSeparationStatus.ready => 'All 4 stems isolated and ready',
      StemSeparationStatus.error => 'Stem separation failed',
      StemSeparationStatus.idle => 'Ready to extract 4 stems',
    };
  }

  StemSeparationState copyWith({
    StemSeparationStatus? status,
    double? progress,
    List<StemTrackEntity>? stems,
    String? errorMessage,
  }) {
    return StemSeparationState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      stems: stems ?? this.stems,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Full track dissection record backing `/track/:id` (design.md §1.1).
@immutable
class TrackDetailEntity {
  /// Ordered cultural emoji reaction keys used by the reaction dock (REQ-TRK-06).
  static const List<String> reactionKeys = [
    'fire',
    'love',
    'rhythm',
    'hands',
    'globe',
  ];

  static const Map<String, String> reactionGlyphs = {
    'fire': '🔥',
    'love': '❤️',
    'rhythm': '🎵',
    'hands': '🙌',
    'globe': '🌍',
  };

  static const String ownershipNotice =
      'This track is 100% royalty-free and owned by you. Commercial usage depends on your subscription plan and licensing terms.';

  final String id;
  final String title;
  final String genre;
  final String language;
  final Duration duration;
  final String creatorId;
  final String creatorName;
  final String creatorHandle;
  final LicenseType licenseType;
  final bool isLiked;
  final int likesCount;
  final int playCount;
  final Map<String, int> reactions;
  final Set<String> userReactions;
  final String lyrics;
  final String prompt;
  final StemSeparationState stemState;

  const TrackDetailEntity({
    required this.id,
    required this.title,
    required this.genre,
    required this.language,
    required this.duration,
    required this.creatorId,
    required this.creatorName,
    required this.creatorHandle,
    this.licenseType = LicenseType.personal,
    this.isLiked = false,
    this.likesCount = 0,
    this.playCount = 0,
    this.reactions = const {
      'fire': 0,
      'love': 1,
      'rhythm': 0,
      'hands': 0,
      'globe': 0,
    },
    this.userReactions = const {'love'},
    this.lyrics = '',
    this.prompt = '',
    this.stemState = const StemSeparationState(),
  });

  bool get isCommercial => licenseType == LicenseType.commercial;

  String get licenseBadge =>
      isCommercial ? '⚖️ Commercial Use' : '🛡️ Personal Use';

  String get metadataLabel => '$genre • $language • $formattedDuration';

  String get formattedDuration {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  TrackDetailEntity copyWith({
    bool? isLiked,
    int? likesCount,
    int? playCount,
    Map<String, int>? reactions,
    Set<String>? userReactions,
    String? lyrics,
    String? prompt,
    StemSeparationState? stemState,
  }) {
    return TrackDetailEntity(
      id: id,
      title: title,
      genre: genre,
      language: language,
      duration: duration,
      creatorId: creatorId,
      creatorName: creatorName,
      creatorHandle: creatorHandle,
      licenseType: licenseType,
      isLiked: isLiked ?? this.isLiked,
      likesCount: likesCount ?? this.likesCount,
      playCount: playCount ?? this.playCount,
      reactions: reactions ?? this.reactions,
      userReactions: userReactions ?? this.userReactions,
      lyrics: lyrics ?? this.lyrics,
      prompt: prompt ?? this.prompt,
      stemState: stemState ?? this.stemState,
    );
  }
}

/// Discussion thread entry (REQ-TRK-11).
@immutable
class CommentEntity {
  final String id;
  final String trackId;
  final String authorName;
  final String authorHandle;
  final String content;
  final DateTime createdAt;
  final int likesCount;
  final bool isLiked;

  const CommentEntity({
    required this.id,
    required this.trackId,
    required this.authorName,
    required this.authorHandle,
    required this.content,
    required this.createdAt,
    this.likesCount = 0,
    this.isLiked = false,
  });

  String get initials {
    final parts = authorName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'V';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    final last = parts.last;
    return (parts.first.substring(0, 1) +
            (last.isEmpty ? '' : last.substring(0, 1)))
        .toUpperCase();
  }
}
