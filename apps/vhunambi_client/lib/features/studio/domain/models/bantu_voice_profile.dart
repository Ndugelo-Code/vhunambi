import 'package:flutter/foundation.dart';

/// An authentic African voice timbre profile powering native vocal synthesis (REQ-VOX-01).
@immutable
class BantuVoiceProfile {
  final String id;
  final String name;
  final String language;
  final String region;
  final String timbreDescription;
  final String iconEmoji;
  final double loraScale;
  final List<String> characteristicAdLibs;
  final String? assetPath;

  const BantuVoiceProfile({
    required this.id,
    required this.name,
    required this.language,
    required this.region,
    required this.timbreDescription,
    required this.iconEmoji,
    this.loraScale = 0.85,
    this.characteristicAdLibs = const [],
    this.assetPath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'language': language,
        'region': region,
        'timbreDescription': timbreDescription,
        'iconEmoji': iconEmoji,
        'loraScale': loraScale,
        'characteristicAdLibs': characteristicAdLibs,
        if (assetPath != null) 'assetPath': assetPath,
      };

  factory BantuVoiceProfile.fromJson(Map<String, dynamic> json) {
    return BantuVoiceProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      language: json['language'] as String,
      region: json['region'] as String,
      timbreDescription: json['timbreDescription'] as String,
      iconEmoji: json['iconEmoji'] as String? ?? '🎤',
      loraScale: (json['loraScale'] as num?)?.toDouble() ?? 0.85,
      characteristicAdLibs: (json['characteristicAdLibs'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      assetPath: json['assetPath'] as String?,
    );
  }
}

/// The 5 canonical Bantu voice timbre profiles in Vhunambi.
const List<BantuVoiceProfile> kBantuVoiceProfiles = [
  BantuVoiceProfile(
    id: 'venda_folk_elder',
    name: 'Venda Folk Elder',
    language: 'Tshivenḓa',
    region: 'Limpopo / Makhado',
    timbreDescription:
        'Deep resonant chest timbre with natural dental articulation and ancestral oral storytelling cadence.',
    iconEmoji: '👴',
    loraScale: 0.90,
    characteristicAdLibs: ['Ndi zwone!', 'Aa!', 'Kha ri tshimbile!', 'Vhukuma!'],
    assetPath: 'assets/artwork/timbre_elder.png',
  ),
  BantuVoiceProfile(
    id: 'soweto_soul_lead',
    name: 'Soweto Soul Lead',
    language: 'isiZulu / English',
    region: 'Gauteng / Soweto',
    timbreDescription:
        'Warm, emotive gospel-influenced vocal lead with silky vibrato, chest-to-head transitions and soulful runs.',
    iconEmoji: '🎤',
    loraScale: 0.85,
    characteristicAdLibs: ['Yebo!', 'Woza!', 'Soweto vibes!', 'Helele!'],
    assetPath: 'assets/artwork/timbre_crooner.png',
  ),
  BantuVoiceProfile(
    id: 'durban_gqom_chanter',
    name: 'Durban Gqom Chanter',
    language: 'isiZulu',
    region: 'KwaZulu-Natal / Durban',
    timbreDescription:
        'Raw, high-intensity percussive vocal projection, syncopated stadium hype chants and driving rhythmic cadences.',
    iconEmoji: '⚡',
    loraScale: 0.92,
    characteristicAdLibs: ['Shisa!', 'Wena!', 'Asambe!', 'Bashise!'],
    assetPath: 'assets/artwork/timbre_producer.png',
  ),
  BantuVoiceProfile(
    id: 'maskandi_bard',
    name: 'Maskandi Acoustic Bard',
    language: 'isiZulu',
    region: 'KwaZulu-Natal / Tugela',
    timbreDescription:
        'Traditional acoustic guitar troubadour delivery, fast-paced praise poetry (izibongo) and microtonal vocal slides.',
    iconEmoji: '🌿',
    loraScale: 0.88,
    characteristicAdLibs: ['Musho!', 'Webaba!', 'Aw kodwa!', 'Hayi bo!'],
    assetPath: 'assets/artwork/timbre_cantor.png',
  ),
  BantuVoiceProfile(
    id: 'limpopo_pop_queen',
    name: 'Limpopo Pop Queen',
    language: 'Tshivenḓa / Sepedi',
    region: 'Limpopo / Polokwane',
    timbreDescription:
        'Bright, energetic polyrhythmic Afro-pop lead with agile melismatic hooks and vibrant high-register projection.',
    iconEmoji: '✨',
    loraScale: 0.86,
    characteristicAdLibs: ['Ndo livhuwa!', 'Agee!', 'Ahee!', 'Makhado!'],
    assetPath: 'assets/artwork/timbre_poet.png',
  ),
];

/// Fine-grained dialect inflection shaping parameters (REQ-VOX-02).
@immutable
class DialectInflectionConfig {
  /// Penultimate syllable elongation (0.0 to 1.0) characteristic of Bantu speech.
  final double vowelElongation;

  /// Warm ancestral tremolo and chest cavity resonance (0.0 to 1.0).
  final double vibratoDepth;

  /// Intensity of polyrhythmic call-and-response choral responses (0.0 to 1.0).
  final double callAndResponseIntensity;

  /// Frequency of spontaneous cultural interjections and ad-libs (0.0 to 1.0).
  final double adLibFrequency;

  const DialectInflectionConfig({
    this.vowelElongation = 0.5,
    this.vibratoDepth = 0.4,
    this.callAndResponseIntensity = 0.6,
    this.adLibFrequency = 0.5,
  });

  DialectInflectionConfig copyWith({
    double? vowelElongation,
    double? vibratoDepth,
    double? callAndResponseIntensity,
    double? adLibFrequency,
  }) {
    return DialectInflectionConfig(
      vowelElongation: vowelElongation ?? this.vowelElongation,
      vibratoDepth: vibratoDepth ?? this.vibratoDepth,
      callAndResponseIntensity:
          callAndResponseIntensity ?? this.callAndResponseIntensity,
      adLibFrequency: adLibFrequency ?? this.adLibFrequency,
    );
  }

  Map<String, dynamic> toJson() => {
        'vowelElongation': vowelElongation,
        'vibratoDepth': vibratoDepth,
        'callAndResponseIntensity': callAndResponseIntensity,
        'adLibFrequency': adLibFrequency,
      };

  factory DialectInflectionConfig.fromJson(Map<String, dynamic> json) {
    return DialectInflectionConfig(
      vowelElongation:
          (json['vowelElongation'] as num?)?.toDouble() ?? 0.5,
      vibratoDepth: (json['vibratoDepth'] as num?)?.toDouble() ?? 0.4,
      callAndResponseIntensity:
          (json['callAndResponseIntensity'] as num?)?.toDouble() ?? 0.6,
      adLibFrequency: (json['adLibFrequency'] as num?)?.toDouble() ?? 0.5,
    );
  }
}
