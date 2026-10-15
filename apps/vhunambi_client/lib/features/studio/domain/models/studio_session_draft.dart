import 'package:flutter/foundation.dart';

import 'studio_form_state.dart';

/// Persisted snapshot of in-progress `StudioFormState` (non-ephemeral fields
/// only) powering the Ghost Session auto-save & recovery loop (M10 /
/// REQ-SES-01 → REQ-SES-07).
///
/// Serialization is hand-rolled JSON — zero `build_runner` / `@HiveType`
/// codegen (repository invariant #1).
@immutable
class StudioSessionDraft {
  final String sessionId;
  final DateTime savedAt;
  final String prompt;
  final String genre;
  final String region;
  final String language;
  final bool isInstrumental;
  final int durationSeconds;

  /// `LyricsMode.name` (enum name, not label).
  final String lyricsMode;
  final String? customLyrics;
  final String mood;

  /// `TempoBracket.name`.
  final String tempo;

  /// `VocalVoices.name`.
  final String vocalVoices;

  /// `VocalGender.name`.
  final String vocalGender;

  /// `VocalMode.name`.
  final String vocalMode;

  /// `VocalEnergy.name`.
  final String vocalEnergy;

  /// `SongStructure.name`.
  final String songStructure;
  final bool isAutoTitle;
  final String? customTitle;
  final bool isPublic;
  final String? referenceAudioPath;

  /// Serialized `BantuVoiceProfile` (rehydrated via `fromJson` on restore).
  final Map<String, dynamic> voiceProfileJson;

  /// Serialized `DialectInflectionConfig`.
  final Map<String, dynamic> dialectInflectionJson;

  const StudioSessionDraft({
    required this.sessionId,
    required this.savedAt,
    required this.prompt,
    required this.genre,
    required this.region,
    required this.language,
    required this.isInstrumental,
    required this.durationSeconds,
    required this.lyricsMode,
    this.customLyrics,
    required this.mood,
    required this.tempo,
    required this.vocalVoices,
    required this.vocalGender,
    required this.vocalMode,
    required this.vocalEnergy,
    required this.songStructure,
    required this.isAutoTitle,
    this.customTitle,
    required this.isPublic,
    this.referenceAudioPath,
    this.voiceProfileJson = const <String, dynamic>{},
    this.dialectInflectionJson = const <String, dynamic>{},
  });

  /// Builds a draft snapshot of [form] with a fresh session id and timestamp.
  factory StudioSessionDraft.fromFormState(StudioFormState form) {
    return StudioSessionDraft(
      sessionId: 'session_${DateTime.now().millisecondsSinceEpoch}',
      savedAt: DateTime.now(),
      prompt: form.prompt,
      genre: form.genre,
      region: form.region,
      language: form.language,
      isInstrumental: form.isInstrumental,
      durationSeconds: form.durationSeconds,
      lyricsMode: form.lyricsMode.name,
      customLyrics: form.customLyrics,
      mood: form.mood,
      tempo: form.tempo.name,
      vocalVoices: form.vocalVoices.name,
      vocalGender: form.vocalGender.name,
      vocalMode: form.vocalMode.name,
      vocalEnergy: form.vocalEnergy.name,
      songStructure: form.songStructure.name,
      isAutoTitle: form.isAutoTitle,
      customTitle: form.customTitle,
      isPublic: form.isPublic,
      referenceAudioPath: form.referenceAudioPath,
      voiceProfileJson: form.selectedVoiceProfile.toJson(),
      dialectInflectionJson: form.dialectInflection.toJson(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'sessionId': sessionId,
        'savedAt': savedAt.toIso8601String(),
        'prompt': prompt,
        'genre': genre,
        'region': region,
        'language': language,
        'isInstrumental': isInstrumental,
        'durationSeconds': durationSeconds,
        'lyricsMode': lyricsMode,
        if (customLyrics != null) 'customLyrics': customLyrics,
        'mood': mood,
        'tempo': tempo,
        'vocalVoices': vocalVoices,
        'vocalGender': vocalGender,
        'vocalMode': vocalMode,
        'vocalEnergy': vocalEnergy,
        'songStructure': songStructure,
        'isAutoTitle': isAutoTitle,
        if (customTitle != null) 'customTitle': customTitle,
        'isPublic': isPublic,
        if (referenceAudioPath != null)
          'referenceAudioPath': referenceAudioPath,
        'voiceProfileJson': voiceProfileJson,
        'dialectInflectionJson': dialectInflectionJson,
      };

  factory StudioSessionDraft.fromJson(Map<String, dynamic> json) {
    return StudioSessionDraft(
      sessionId: json['sessionId'] as String? ?? '',
      savedAt:
          DateTime.tryParse(json['savedAt'] as String? ?? '') ?? DateTime.now(),
      prompt: json['prompt'] as String? ?? '',
      genre: json['genre'] as String? ?? 'Amapiano',
      region: json['region'] as String? ?? 'South Africa',
      language: json['language'] as String? ?? 'English',
      isInstrumental: json['isInstrumental'] as bool? ?? false,
      durationSeconds: json['durationSeconds'] as int? ?? 30,
      lyricsMode: json['lyricsMode'] as String? ?? 'aiWrite',
      customLyrics: json['customLyrics'] as String?,
      mood: json['mood'] as String? ?? 'Uplifting',
      tempo: json['tempo'] as String? ?? 'medium',
      vocalVoices: json['vocalVoices'] as String? ?? 'solo',
      vocalGender: json['vocalGender'] as String? ?? 'male',
      vocalMode: json['vocalMode'] as String? ?? 'auto',
      vocalEnergy: json['vocalEnergy'] as String? ?? 'mid',
      songStructure: json['songStructure'] as String? ?? 'standard',
      isAutoTitle: json['isAutoTitle'] as bool? ?? true,
      customTitle: json['customTitle'] as String?,
      isPublic: json['isPublic'] as bool? ?? true,
      referenceAudioPath: json['referenceAudioPath'] as String?,
      voiceProfileJson: Map<String, dynamic>.from(
        (json['voiceProfileJson'] as Map?) ?? const <String, dynamic>{},
      ),
      dialectInflectionJson: Map<String, dynamic>.from(
        (json['dialectInflectionJson'] as Map?) ?? const <String, dynamic>{},
      ),
    );
  }

  /// Whether the session has meaningful content worth recovering.
  ///
  /// A pristine studio form (empty prompt, no lyrics, default Amapiano genre)
  /// must never trigger the recovery banner.
  bool get hasContent =>
      prompt.trim().isNotEmpty ||
      (customLyrics?.trim().isNotEmpty ?? false) ||
      genre != 'Amapiano';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudioSessionDraft &&
          runtimeType == other.runtimeType &&
          sessionId == other.sessionId &&
          savedAt == other.savedAt &&
          prompt == other.prompt &&
          genre == other.genre &&
          region == other.region &&
          language == other.language &&
          isInstrumental == other.isInstrumental &&
          durationSeconds == other.durationSeconds &&
          lyricsMode == other.lyricsMode &&
          customLyrics == other.customLyrics &&
          mood == other.mood &&
          tempo == other.tempo &&
          vocalVoices == other.vocalVoices &&
          vocalGender == other.vocalGender &&
          vocalMode == other.vocalMode &&
          vocalEnergy == other.vocalEnergy &&
          songStructure == other.songStructure &&
          isAutoTitle == other.isAutoTitle &&
          customTitle == other.customTitle &&
          isPublic == other.isPublic &&
          referenceAudioPath == other.referenceAudioPath &&
          mapEquals(voiceProfileJson, other.voiceProfileJson) &&
          mapEquals(dialectInflectionJson, other.dialectInflectionJson);

  @override
  int get hashCode => Object.hashAll(<Object?>[
        sessionId,
        savedAt,
        prompt,
        genre,
        region,
        language,
        isInstrumental,
        durationSeconds,
        lyricsMode,
        customLyrics,
        mood,
        tempo,
        vocalVoices,
        vocalGender,
        vocalMode,
        vocalEnergy,
        songStructure,
        isAutoTitle,
        customTitle,
        isPublic,
        referenceAudioPath,
      ]);
}
