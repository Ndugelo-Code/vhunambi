import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../features/player/domain/models/stem_mixer_state.dart';

/// Audio provenance classifier declaring the human craft or algorithmic origin
/// of a musical work (Phase 39 REQ-ID-PROV-01).
enum AudioProvenanceType {
  humanDawMaster,
  liveVocalRecording,
  liveInstrumentStem,
  hybridCoCreation,
  aiGenerated,
}

extension AudioProvenanceTypeExtension on AudioProvenanceType {
  String get displayName => switch (this) {
    AudioProvenanceType.humanDawMaster => 'Human DAW Master',
    AudioProvenanceType.liveVocalRecording => '100% Live Vocal',
    AudioProvenanceType.liveInstrumentStem => 'Live Instrument',
    AudioProvenanceType.hybridCoCreation => 'Hybrid Co-Creation',
    AudioProvenanceType.aiGenerated => 'Vhunambi AI',
  };

  IconData get icon => switch (this) {
    AudioProvenanceType.humanDawMaster =>
      PhosphorIconsRegular.slidersHorizontal,
    AudioProvenanceType.liveVocalRecording => PhosphorIconsRegular.microphone,
    AudioProvenanceType.liveInstrumentStem => PhosphorIconsRegular.musicNotes,
    AudioProvenanceType.hybridCoCreation => PhosphorIconsRegular.gitFork,
    AudioProvenanceType.aiGenerated => PhosphorIconsRegular.sparkle,
  };
}

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

  /// Optional separated stem audio sources for Pocket DAW 4-channel live mixing.
  final Map<StemType, String>? stemUrls;

  /// Craft provenance indicating whether this audio was produced in a DAW,
  /// sung live, played on an instrument, or AI-generated (REQ-ID-PROV-01).
  final AudioProvenanceType provenanceType;

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
    this.stemUrls,
    this.provenanceType = AudioProvenanceType.hybridCoCreation,
  });

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
