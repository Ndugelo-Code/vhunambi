import '../tokens/design_enums.dart';
import '../tokens/color_token.dart';
import '../tokens/design_token_registry.dart';

/// Validation errors for [GenerationRequestModel].
class GenerationRequestValidationException implements Exception {
  final String field;
  final String message;
  GenerationRequestValidationException(this.field, this.message);
  @override
  String toString() => 'GenerationRequestValidationException($field: $message)';
}

/// Single source of truth state object holding all parameters for song
/// generation.
///
/// This model is the central state container used by the Studio Cockpit,
/// Onboarding, and Adaptive Mini Player features. All field changes go
/// through validated setters that notify listeners via
/// [GenerationRequestNotifier].
class GenerationRequestModel {
  /// Default BPM value.
  static const int _defaultBpm = 120;

  /// Default DNA slider value (0.0 to 1.0).
  static const double _defaultDnaStrength = 0.5;

  /// Default visibility value.
  static const String _defaultVisibility = 'private';

  final Genre genre;
  final Mood mood;
  final int bpm;
  final double dnaStrength;
  final String visibility;
  final String? lyrics;
  final String? prompt;

  const GenerationRequestModel({
    required this.genre,
    required this.mood,
    this.bpm = _defaultBpm,
    this.dnaStrength = _defaultDnaStrength,
    this.visibility = _defaultVisibility,
    this.lyrics,
    this.prompt,
  });

  /// Creates a [GenerationRequestModel] with default values.
  factory GenerationRequestModel.defaults() {
    return GenerationRequestModel(
      genre: Genre.amapiano,
      mood: Mood.joyful,
    );
  }

  /// Returns the [ColorToken] for the current [genre].
  ColorToken get genreToken => DesignTokenRegistry.getGenreToken(genre);

  /// Returns the [ColorToken] for the current [mood].
  ColorToken get moodToken => DesignTokenRegistry.getMoodToken(mood);

  /// Returns a copy of this model with the given fields replaced.
  GenerationRequestModel copyWith({
    Genre? genre,
    Mood? mood,
    int? bpm,
    double? dnaStrength,
    String? visibility,
    String? lyrics,
    String? prompt,
    bool clearLyrics = false,
    bool clearPrompt = false,
  }) {
    return GenerationRequestModel(
      genre: genre ?? this.genre,
      mood: mood ?? this.mood,
      bpm: bpm ?? this.bpm,
      dnaStrength: dnaStrength ?? this.dnaStrength,
      visibility: visibility ?? this.visibility,
      lyrics: clearLyrics ? null : (lyrics ?? this.lyrics),
      prompt: clearPrompt ? null : (prompt ?? this.prompt),
    );
  }

  /// Validates all fields and throws [GenerationRequestValidationException]
  /// if any field is invalid.
  void validate() {
    if (bpm < 40 || bpm > 240) {
      throw GenerationRequestValidationException(
        'bpm',
        'BPM must be between 40 and 240, got $bpm',
      );
    }
    if (dnaStrength < 0.0 || dnaStrength > 1.0) {
      throw GenerationRequestValidationException(
        'dnaStrength',
        'DNA strength must be between 0.0 and 1.0, got $dnaStrength',
      );
    }
    if (visibility.isEmpty) {
      throw GenerationRequestValidationException(
        'visibility',
        'Visibility must not be empty',
      );
    }
  }

  /// Serializes this model to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'genre': genre.name,
      'mood': mood.name,
      'bpm': bpm,
      'dna_strength': dnaStrength,
      'visibility': visibility,
      if (lyrics != null) 'lyrics': lyrics,
      if (prompt != null) 'prompt': prompt,
    };
  }

  /// Deserializes a [GenerationRequestModel] from a JSON map.
  ///
  /// Missing or unknown fields use default values to support older app
  /// versions.
  factory GenerationRequestModel.fromJson(Map<String, dynamic> json) {
    final genreName = json['genre'] as String?;
    final moodName = json['mood'] as String?;
    return GenerationRequestModel(
      genre: genreName != null
          ? Genre.values.firstWhere(
              (g) => g.name == genreName,
              orElse: () => Genre.amapiano,
            )
          : Genre.amapiano,
      mood: moodName != null
          ? Mood.values.firstWhere(
              (m) => m.name == moodName,
              orElse: () => Mood.joyful,
            )
          : Mood.joyful,
      bpm: (json['bpm'] as num?)?.toInt() ?? _defaultBpm,
      dnaStrength: (json['dna_strength'] as num?)?.toDouble() ??
          _defaultDnaStrength,
      visibility: (json['visibility'] as String?) ?? _defaultVisibility,
      lyrics: json['lyrics'] as String?,
      prompt: json['prompt'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GenerationRequestModel &&
          runtimeType == other.runtimeType &&
          genre == other.genre &&
          mood == other.mood &&
          bpm == other.bpm &&
          dnaStrength == other.dnaStrength &&
          visibility == other.visibility &&
          lyrics == other.lyrics &&
          prompt == other.prompt;

  @override
  int get hashCode =>
      Object.hash(genre, mood, bpm, dnaStrength, visibility, lyrics, prompt);

  @override
  String toString() =>
      'GenerationRequestModel(genre: $genre, mood: $mood, bpm: $bpm, '
      'dnaStrength: $dnaStrength, visibility: $visibility)';
}