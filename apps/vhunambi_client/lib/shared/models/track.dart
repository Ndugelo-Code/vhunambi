import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/features/player/domain/models/stem_mixer_state.dart';

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

  Track copyWith({
    String? id,
    String? title,
    String? creatorName,
    String? creatorAvatarUrl,
    String? genre,
    String? language,
    Duration? duration,
    String? audioUrl,
    String? coverUrl,
    int? likeCount,
    int? playCount,
    bool? isNew,
    int? trendingRank,
    String? mood,
    String? creatorHandle,
    Map<StemType, String>? stemUrls,
    AudioProvenanceType? provenanceType,
  }) {
    return Track(
      id: id ?? this.id,
      title: title ?? this.title,
      creatorName: creatorName ?? this.creatorName,
      creatorAvatarUrl: creatorAvatarUrl ?? this.creatorAvatarUrl,
      genre: genre ?? this.genre,
      language: language ?? this.language,
      duration: duration ?? this.duration,
      audioUrl: audioUrl ?? this.audioUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      likeCount: likeCount ?? this.likeCount,
      playCount: playCount ?? this.playCount,
      isNew: isNew ?? this.isNew,
      trendingRank: trendingRank ?? this.trendingRank,
      mood: mood ?? this.mood,
      creatorHandle: creatorHandle ?? this.creatorHandle,
      stemUrls: stemUrls ?? this.stemUrls,
      provenanceType: provenanceType ?? this.provenanceType,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'creatorName': creatorName,
    'artist': creatorName,
    if (creatorAvatarUrl != null) 'creatorAvatarUrl': creatorAvatarUrl,
    'genre': genre,
    'language': language,
    'durationMs': duration.inMilliseconds,
    'durationSeconds': duration.inSeconds,
    if (audioUrl != null) 'audioUrl': audioUrl,
    if (coverUrl != null) 'coverUrl': coverUrl,
    'likeCount': likeCount,
    'likesCount': likeCount,
    'playCount': playCount,
    'playsCount': playCount,
    'isNew': isNew,
    if (trendingRank != null) 'trendingRank': trendingRank,
    if (mood != null) 'mood': mood,
    if (creatorHandle != null) 'creatorHandle': creatorHandle,
    if (stemUrls != null)
      'stemUrls': <String, String>{
        for (final entry in stemUrls!.entries) entry.key.name: entry.value,
      },
    'provenanceType': provenanceType.name,
  };

  factory Track.fromJson(Map<String, dynamic> json) {
    final durationMsRaw = json['durationMs'] ?? json['duration_ms'];
    final durationSecRaw =
        json['durationSeconds'] ?? json['duration_seconds'] ?? json['duration'];
    final Duration resolvedDuration;
    if (durationMsRaw is num && durationMsRaw > 0) {
      resolvedDuration = Duration(milliseconds: durationMsRaw.round());
    } else if (durationSecRaw is num && durationSecRaw > 0) {
      resolvedDuration = Duration(seconds: durationSecRaw.round());
    } else {
      resolvedDuration = const Duration(minutes: 3);
    }

    Map<StemType, String>? parsedStems;
    final rawStems = json['stemUrls'];
    if (rawStems is Map) {
      final map = <StemType, String>{};
      for (final entry in rawStems.entries) {
        final keyStr = entry.key.toString();
        final stemType = StemType.values
            .where((s) => s.name == keyStr)
            .firstOrNull;
        if (stemType != null && entry.value != null) {
          map[stemType] = entry.value.toString();
        }
      }
      if (map.isNotEmpty) parsedStems = map;
    }

    final rawProvenance =
        (json['provenanceType'] ??
                (json['songDna'] is Map
                    ? (json['songDna'] as Map)['provenanceType']
                    : null))
            ?.toString();
    final AudioProvenanceType resolvedProvenance;
    if (rawProvenance == 'humanCreated') {
      resolvedProvenance = AudioProvenanceType.humanDawMaster;
    } else {
      resolvedProvenance = AudioProvenanceType.values.firstWhere(
        (e) => e.name == rawProvenance,
        orElse: () => AudioProvenanceType.hybridCoCreation,
      );
    }

    return Track(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Untitled Track').toString(),
      creatorName:
          (json['creatorName'] ??
                  json['artist'] ??
                  json['artist_name'] ??
                  'Vhunambi Creator')
              .toString(),
      creatorAvatarUrl: json['creatorAvatarUrl'] as String?,
      genre: (json['genre'] ?? 'Amapiano').toString(),
      language: (json['language'] ?? 'English').toString(),
      duration: resolvedDuration,
      audioUrl: (json['audioUrl'] ?? json['audio_url']) as String?,
      coverUrl: (json['coverUrl'] ?? json['cover_url']) as String?,
      likeCount:
          ((json['likeCount'] ?? json['likesCount'] ?? json['like_count'])
                  as num?)
              ?.toInt() ??
          0,
      playCount:
          ((json['playCount'] ?? json['playsCount'] ?? json['play_count'])
                  as num?)
              ?.toInt() ??
          0,
      isNew: json['isNew'] as bool? ?? false,
      trendingRank: (json['trendingRank'] as num?)?.toInt(),
      mood: json['mood'] as String?,
      creatorHandle:
          (json['creatorHandle'] ?? json['creator_handle']) as String?,
      stemUrls: parsedStems,
      provenanceType: resolvedProvenance,
    );
  }
}
