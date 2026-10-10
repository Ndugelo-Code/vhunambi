import 'package:flutter/foundation.dart';
import 'lyric_word_timestamp.dart';

/// The canonical, immutable Song Metadata DNA representing all acoustic,
/// linguistic, vocal, visual, and rhythmic specifications of a Vhunambi song.
@immutable
class SongMetadataDna {
  final String id;
  final String version;
  final String title;
  final String genre;
  final String language;
  final CulturalContextDna? culturalContext;
  final MusicalDna musical;
  final VocalsDna vocals;
  final VisualThemeDna visualTheme;
  final List<LyricWordTimestamp> alignment;

  const SongMetadataDna({
    required this.id,
    this.version = '1.0',
    required this.title,
    required this.genre,
    required this.language,
    this.culturalContext,
    required this.musical,
    required this.vocals,
    required this.visualTheme,
    this.alignment = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'version': version,
        'title': title,
        'genre': genre,
        'language': language,
        if (culturalContext != null)
          'culturalContext': culturalContext!.toJson(),
        'musical': musical.toJson(),
        'vocals': vocals.toJson(),
        'visualTheme': visualTheme.toJson(),
        'alignment': alignment.map((w) => w.toJson()).toList(),
      };

  factory SongMetadataDna.fromJson(Map<String, dynamic> json) {
    return SongMetadataDna(
      id: json['id'] as String,
      version: json['version'] as String? ?? '1.0',
      title: json['title'] as String? ?? 'Untitled',
      genre: json['genre'] as String? ?? 'Amapiano',
      language: json['language'] as String? ?? 'Tshivenḓa',
      culturalContext: json['culturalContext'] != null
          ? CulturalContextDna.fromJson(
              json['culturalContext'] as Map<String, dynamic>)
          : null,
      musical: MusicalDna.fromJson(json['musical'] as Map<String, dynamic>),
      vocals: VocalsDna.fromJson(json['vocals'] as Map<String, dynamic>),
      visualTheme:
          VisualThemeDna.fromJson(json['visualTheme'] as Map<String, dynamic>),
      alignment: (json['alignment'] as List<dynamic>?)
              ?.map((w) =>
                  LyricWordTimestamp.fromJson(w as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  /// Synthesizes complete SongMetadataDna from standard track fields.
  /// Automatically extracts word alignment from lyrics if available.
  factory SongMetadataDna.fromTrackInfo({
    required String id,
    required String title,
    required String genre,
    required String language,
    required int durationSec,
    String? lyrics,
    String? coverUrl,
  }) {
    final alignmentList = <LyricWordTimestamp>[];
    if (lyrics != null && lyrics.trim().isNotEmpty) {
      final words = lyrics.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      final totalSec = durationSec > 0 ? durationSec.toDouble() : 180.0;
      final step = words.isNotEmpty ? (totalSec * 0.8) / words.length : 1.0;
      for (var i = 0; i < words.length; i++) {
        final start = (i * step) + 2.0;
        final end = start + (step * 0.9);
        alignmentList.add(LyricWordTimestamp(
          word: words[i],
          start: double.parse(start.toStringAsFixed(2)),
          end: double.parse(end.toStringAsFixed(2)),
          stanzaIndex: i ~/ 8,
        ));
      }
    }

    final lowerGenre = genre.toLowerCase();
    final bpm = lowerGenre.contains('gqom')
        ? 128
        : lowerGenre.contains('amapiano')
            ? 113
            : lowerGenre.contains('maskandi')
                ? 120
                : lowerGenre.contains('drill')
                    ? 140
                    : 118;

    return SongMetadataDna(
      id: id,
      title: title,
      genre: genre,
      language: language,
      musical: MusicalDna(
        bpm: bpm,
        key: 'F# Minor',
        energyBracket: lowerGenre.contains('gqom') ? 'high' : 'mid',
        durationSec: durationSec > 0 ? durationSec : 180,
      ),
      vocals: VocalsDna(
        deliveryMode: lowerGenre.contains('gqom') ? 'chanted' : 'melodic',
        gender: 'female',
        energy: 'mid',
      ),
      visualTheme: VisualThemeDna(
        mood: lowerGenre.contains('amapiano')
            ? 'Warm Sunset Glow'
            : lowerGenre.contains('gqom')
                ? 'Midnight Club Neon'
                : 'Highland Sunset',
        comfyPrompt: 'Vibrant 9:16 vertical cover art for $genre song "$title"',
        seed: id.hashCode.abs() % 1000000,
      ),
      alignment: alignmentList,
    );
  }

  SongMetadataDna copyWith({
    String? id,
    String? version,
    String? title,
    String? genre,
    String? language,
    CulturalContextDna? culturalContext,
    MusicalDna? musical,
    VocalsDna? vocals,
    VisualThemeDna? visualTheme,
    List<LyricWordTimestamp>? alignment,
  }) {
    return SongMetadataDna(
      id: id ?? this.id,
      version: version ?? this.version,
      title: title ?? this.title,
      genre: genre ?? this.genre,
      language: language ?? this.language,
      culturalContext: culturalContext ?? this.culturalContext,
      musical: musical ?? this.musical,
      vocals: vocals ?? this.vocals,
      visualTheme: visualTheme ?? this.visualTheme,
      alignment: alignment ?? this.alignment,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SongMetadataDna &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          version == other.version &&
          title == other.title &&
          genre == other.genre &&
          language == other.language &&
          culturalContext == other.culturalContext &&
          musical == other.musical &&
          vocals == other.vocals &&
          visualTheme == other.visualTheme &&
          listEquals(alignment, other.alignment);

  @override
  int get hashCode => Object.hash(
        id,
        version,
        title,
        genre,
        language,
        culturalContext,
        musical,
        vocals,
        visualTheme,
        Object.hashAll(alignment),
      );
}

@immutable
class CulturalContextDna {
  final String region;
  final List<String> idioms;
  final String phoneticGuidelines;

  const CulturalContextDna({
    required this.region,
    this.idioms = const [],
    this.phoneticGuidelines = '',
  });

  Map<String, dynamic> toJson() => {
        'region': region,
        'idioms': idioms,
        'phoneticGuidelines': phoneticGuidelines,
      };

  factory CulturalContextDna.fromJson(Map<String, dynamic> json) =>
      CulturalContextDna(
        region: json['region'] as String? ?? 'Limpopo, South Africa',
        idioms: (json['idioms'] as List<dynamic>?)?.cast<String>() ?? const [],
        phoneticGuidelines: json['phoneticGuidelines'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CulturalContextDna &&
          runtimeType == other.runtimeType &&
          region == other.region &&
          listEquals(idioms, other.idioms) &&
          phoneticGuidelines == other.phoneticGuidelines;

  @override
  int get hashCode =>
      Object.hash(region, Object.hashAll(idioms), phoneticGuidelines);
}

@immutable
class MusicalDna {
  final int bpm;
  final String key;
  final String energyBracket; // 'soft', 'mid', 'intense'
  final int durationSec;

  const MusicalDna({
    required this.bpm,
    required this.key,
    required this.energyBracket,
    required this.durationSec,
  });

  Map<String, dynamic> toJson() => {
        'bpm': bpm,
        'key': key,
        'energyBracket': energyBracket,
        'durationSec': durationSec,
      };

  factory MusicalDna.fromJson(Map<String, dynamic> json) => MusicalDna(
        bpm: json['bpm'] as int? ?? 112,
        key: json['key'] as String? ?? 'F# Minor',
        energyBracket: json['energyBracket'] as String? ?? 'mid',
        durationSec: json['durationSec'] as int? ?? 180,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MusicalDna &&
          runtimeType == other.runtimeType &&
          bpm == other.bpm &&
          key == other.key &&
          energyBracket == other.energyBracket &&
          durationSec == other.durationSec;

  @override
  int get hashCode => Object.hash(bpm, key, energyBracket, durationSec);
}

@immutable
class VocalsDna {
  final String deliveryMode; // 'melodic', 'rap', 'spokenWord', 'choir'
  final String gender; // 'male', 'female', 'duet', 'choir'
  final String energy; // 'soft', 'mid', 'intense'
  final List<Map<String, dynamic>> loras;

  const VocalsDna({
    required this.deliveryMode,
    required this.gender,
    required this.energy,
    this.loras = const [],
  });

  Map<String, dynamic> toJson() => {
        'deliveryMode': deliveryMode,
        'gender': gender,
        'energy': energy,
        'loras': loras,
      };

  factory VocalsDna.fromJson(Map<String, dynamic> json) => VocalsDna(
        deliveryMode: json['deliveryMode'] as String? ?? 'melodic',
        gender: json['gender'] as String? ?? 'male',
        energy: json['energy'] as String? ?? 'mid',
        loras: (json['loras'] as List<dynamic>?)
                ?.map((item) => Map<String, dynamic>.from(item as Map))
                .toList() ??
            const [],
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VocalsDna &&
          runtimeType == other.runtimeType &&
          deliveryMode == other.deliveryMode &&
          gender == other.gender &&
          energy == other.energy;

  @override
  int get hashCode => Object.hash(deliveryMode, gender, energy);
}

@immutable
class VisualThemeDna {
  final String mood;
  final String comfyPrompt;
  final String negativePrompt;
  final int seed;
  final String aspectRatio; // '9:16'

  const VisualThemeDna({
    required this.mood,
    required this.comfyPrompt,
    this.negativePrompt = 'blurry, low quality, watermark, text, signature',
    required this.seed,
    this.aspectRatio = '9:16',
  });

  Map<String, dynamic> toJson() => {
        'mood': mood,
        'comfyPrompt': comfyPrompt,
        'negativePrompt': negativePrompt,
        'seed': seed,
        'aspectRatio': aspectRatio,
      };

  factory VisualThemeDna.fromJson(Map<String, dynamic> json) => VisualThemeDna(
        mood: json['mood'] as String? ?? 'Cinematic',
        comfyPrompt: json['comfyPrompt'] as String? ?? '',
        negativePrompt: json['negativePrompt'] as String? ??
            'blurry, low quality, watermark, text, signature',
        seed: json['seed'] as int? ?? 42,
        aspectRatio: json['aspectRatio'] as String? ?? '9:16',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VisualThemeDna &&
          runtimeType == other.runtimeType &&
          mood == other.mood &&
          comfyPrompt == other.comfyPrompt &&
          negativePrompt == other.negativePrompt &&
          seed == other.seed &&
          aspectRatio == other.aspectRatio;

  @override
  int get hashCode =>
      Object.hash(mood, comfyPrompt, negativePrompt, seed, aspectRatio);
}
