import 'package:flutter/foundation.dart';

/// Hybrid Sound Pack Entity for native & downloadable expansion libraries (Phase 32).
@immutable
class StudioSoundPackEntity {
  final String id;
  final String title;
  final String subtitle;
  final String genre;
  final double sizeMb;
  final bool isBundledNative;
  final bool isInstalled;
  final List<String> instrumentNames;
  final String downloadUrl;

  const StudioSoundPackEntity({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.genre,
    required this.sizeMb,
    this.isBundledNative = false,
    this.isInstalled = false,
    required this.instrumentNames,
    required this.downloadUrl,
  });

  StudioSoundPackEntity copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? genre,
    double? sizeMb,
    bool? isBundledNative,
    bool? isInstalled,
    List<String>? instrumentNames,
    String? downloadUrl,
  }) {
    return StudioSoundPackEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      genre: genre ?? this.genre,
      sizeMb: sizeMb ?? this.sizeMb,
      isBundledNative: isBundledNative ?? this.isBundledNative,
      isInstalled: isInstalled ?? this.isInstalled,
      instrumentNames: instrumentNames ?? this.instrumentNames,
      downloadUrl: downloadUrl ?? this.downloadUrl,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'genre': genre,
    'sizeMb': sizeMb,
    'isBundledNative': isBundledNative,
    'isInstalled': isInstalled,
    'instrumentNames': instrumentNames,
    'downloadUrl': downloadUrl,
  };

  factory StudioSoundPackEntity.fromJson(Map<String, dynamic> json) {
    return StudioSoundPackEntity(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      genre: json['genre'] as String,
      sizeMb: (json['sizeMb'] as num).toDouble(),
      isBundledNative: json['isBundledNative'] as bool? ?? false,
      isInstalled: json['isInstalled'] as bool? ?? false,
      instrumentNames: (json['instrumentNames'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      downloadUrl: json['downloadUrl'] as String? ?? '',
    );
  }
}

/// The 6 Official Vhunambi Sound Packs.
const List<StudioSoundPackEntity> kOfficialSoundPacks = [
  StudioSoundPackEntity(
    id: 'pack_vhunambi_core_native',
    title: 'Vhunambi Core Studio Kit',
    subtitle: '18 Native Instruments & 6 Genre Drum Racks',
    genre: 'African Heritage & Studio Universal',
    sizeMb: 0.0,
    isBundledNative: true,
    isInstalled: true,
    instrumentNames: [
      'Concert Grand Piano',
      'Private School Rhodes',
      'Amapiano Log Drum',
      'Nylon Guitar',
      'Bamboo Flute',
      'Soprano Sax',
      '808 Sub',
      'Amapiano Drum Kit',
    ],
    downloadUrl: '',
  ),
  StudioSoundPackEntity(
    id: 'pack_private_school_vip',
    title: 'Kabza & Kelvin Private School VIP',
    subtitle: 'Warm DX10 Log-Drums & Vintage Rhodes MK8',
    genre: 'Private School Amapiano',
    sizeMb: 14.2,
    isBundledNative: false,
    isInstalled: false,
    instrumentNames: [
      'VIP Log Drum (Soweto Deep)',
      'Rhodes MK8 Bell Tines',
      'Vocal Chants & Hype Stabs',
      'Kabza Shaker Matrix',
    ],
    downloadUrl: 'https://cdn.vhunambi.com/packs/private_school_vip.tar.gz',
  ),
  StudioSoundPackEntity(
    id: 'pack_grand_piano_strings',
    title: 'FL Producer Grand Piano & Strings',
    subtitle: 'Steinway D Concert Grand & Symphonic Violin Ensemble',
    genre: 'Classical & Cinematic',
    sizeMb: 16.4,
    isBundledNative: false,
    isInstalled: false,
    instrumentNames: [
      'Steinway Concert Grand D',
      'Symphonic Violins & Cello',
      'Warm String Pad',
    ],
    downloadUrl: 'https://cdn.vhunambi.com/packs/grand_piano_strings.tar.gz',
  ),
  StudioSoundPackEntity(
    id: 'pack_soweto_horns_flute',
    title: 'Soweto Live Sax, Flute & Jazz Horns',
    subtitle: 'Authentic South African Brass & Reed Session Recordings',
    genre: 'Afro Jazz & Soul',
    sizeMb: 12.8,
    isBundledNative: false,
    isInstalled: false,
    instrumentNames: [
      'Tenor Saxophone (Growl)',
      'Bamboo Flute (High)',
      'Brass Section Stabs',
    ],
    downloadUrl: 'https://cdn.vhunambi.com/packs/soweto_horns.tar.gz',
  ),
  StudioSoundPackEntity(
    id: 'pack_808_gqom_drums',
    title: '808 Trap & Durban Gqom Heavy Drums',
    subtitle: 'Distorted 808s, Warehouse Tones & Saturated Kicks',
    genre: 'Trap & Gqom',
    sizeMb: 11.5,
    isBundledNative: false,
    isInstalled: false,
    instrumentNames: [
      'Overdriven 808 Boom',
      'eThekwini Dark Tom',
      'Trap Hi-Hat Rolls',
    ],
    downloadUrl: 'https://cdn.vhunambi.com/packs/808_gqom_drums.tar.gz',
  ),
  StudioSoundPackEntity(
    id: 'pack_lagos_afrobeats_hitmaker',
    title: 'Lagos Afrobeats & House Hitmaker',
    subtitle: 'Punchy Afrobeats Snares, Talking Drum & 909 Groove',
    genre: 'Afrobeats & Deep House',
    sizeMb: 13.0,
    isBundledNative: false,
    isInstalled: false,
    instrumentNames: [
      'Lagos Talking Drum',
      'Afrobeats Rim Clack',
      'Deep House 909 Punch',
    ],
    downloadUrl: 'https://cdn.vhunambi.com/packs/lagos_afrobeats.tar.gz',
  ),
];
