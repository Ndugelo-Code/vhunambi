import 'package:flutter/foundation.dart';

/// Vocal Cleanse & Enhancement flavors (REQ-MST-DOM-03).
enum VocalCleanseFlavor {
  off('off', 'Raw Direct', 'No neural processing applied'),
  studioClean('studio_clean', 'Studio Clean', 'Adobe-style de-noise, de-reverb, and air sheen'),
  warmIntimate('warm_intimate', 'Warm Soul', 'Tube warmth, smooth low-mids, intimate proximity'),
  wideAnthem('wide_anthem', 'Choir Anthem', 'Stadium stereo expansion and ambient hall tail');

  final String wireValue;
  final String label;
  final String description;

  const VocalCleanseFlavor(this.wireValue, this.label, this.description);

  static VocalCleanseFlavor fromWire(String? wire) {
    if (wire == null) return VocalCleanseFlavor.studioClean;
    return VocalCleanseFlavor.values.firstWhere(
      (f) => f.wireValue == wire || f.name == wire,
      orElse: () => VocalCleanseFlavor.studioClean,
    );
  }
}

/// Bass / Log-Drum Character flavors (REQ-MST-DOM-03).
enum BassCharacterFlavor {
  natural('natural', 'Natural Bass', 'Original frequency balance'),
  heavyWoodenKnock('heavy_wooden_knock', 'Wooden Knock', '45Hz sub-octave, 165Hz tube knock, kick sidechain'),
  deepSub808('deep_sub_808', 'Deep Sub-808', 'Maximum sub-bass pressure below 50Hz for club subs'),
  smoothGlide('smooth_glide', 'Smooth Glide', 'Warm rounded log-drum tone with gentle sidechain ducking');

  final String wireValue;
  final String label;
  final String description;

  const BassCharacterFlavor(this.wireValue, this.label, this.description);

  static BassCharacterFlavor fromWire(String? wire) {
    if (wire == null) return BassCharacterFlavor.heavyWoodenKnock;
    return BassCharacterFlavor.values.firstWhere(
      (f) => f.wireValue == wire || f.name == wire,
      orElse: () => BassCharacterFlavor.heavyWoodenKnock,
    );
  }
}

/// Drum bus transient & punch flavors (REQ-MST-DOM-03).
enum DrumCharacterFlavor {
  natural('natural', 'Natural Kit', 'Balanced drum bus dynamics'),
  crispShakers('crisp_shakers', 'Crisp Shakers', 'Enhanced high-frequency sheen and snare attack snap'),
  clubPunch('club_punch', 'Club Punch', 'Aggressive parallel NY compression and punchy kick click'),
  vintageWarm('vintage_warm', 'Vintage Warm', 'Soft-clipped tape warmth and scooped 320Hz boxiness');

  final String wireValue;
  final String label;
  final String description;

  const DrumCharacterFlavor(this.wireValue, this.label, this.description);

  static DrumCharacterFlavor fromWire(String? wire) {
    if (wire == null) return DrumCharacterFlavor.crispShakers;
    return DrumCharacterFlavor.values.firstWhere(
      (f) => f.wireValue == wire || f.name == wire,
      orElse: () => DrumCharacterFlavor.crispShakers,
    );
  }
}

/// Melodic stereo width and vocal pocket flavors (REQ-MST-DOM-03).
enum MelodicCharacterFlavor {
  natural('natural', 'Natural Stereo', 'Standard stereo field balance'),
  wideStereoPocket('wide_stereo_pocket', 'Wide Vocal Pocket', '-2.5dB Mid scoop at 1.8kHz for vocals + wide Sides'),
  warmRhodes('warm_rhodes', 'Warm Rhodes', 'Lush private school chord warmth and gentle high-cut'),
  brightAcoustic('bright_acoustic', 'Bright Pluck', 'Airy acoustic guitar & marimba clarity with +30% width');

  final String wireValue;
  final String label;
  final String description;

  const MelodicCharacterFlavor(this.wireValue, this.label, this.description);

  static MelodicCharacterFlavor fromWire(String? wire) {
    if (wire == null) return MelodicCharacterFlavor.wideStereoPocket;
    return MelodicCharacterFlavor.values.firstWhere(
      (f) => f.wireValue == wire || f.name == wire,
      orElse: () => MelodicCharacterFlavor.wideStereoPocket,
    );
  }
}

/// 4-band Parametric EQ values per stem (REQ-MST-DOM-01).
@immutable
class StemEqBands {
  final double highpassHz; // 20 .. 250 Hz
  final double lowGainDb; // -12 .. +12 dB
  final double midGainDb; // -12 .. +12 dB
  final double midFreqHz; // 250 .. 5000 Hz
  final double airGainDb; // -12 .. +12 dB

  const StemEqBands({
    required this.highpassHz,
    required this.lowGainDb,
    required this.midGainDb,
    required this.midFreqHz,
    required this.airGainDb,
  });

  StemEqBands copyWith({
    double? highpassHz,
    double? lowGainDb,
    double? midGainDb,
    double? midFreqHz,
    double? airGainDb,
  }) {
    return StemEqBands(
      highpassHz: highpassHz ?? this.highpassHz,
      lowGainDb: lowGainDb ?? this.lowGainDb,
      midGainDb: midGainDb ?? this.midGainDb,
      midFreqHz: midFreqHz ?? this.midFreqHz,
      airGainDb: airGainDb ?? this.airGainDb,
    );
  }

  Map<String, dynamic> toJson() => {
        'highpassHz': highpassHz,
        'lowGainDb': lowGainDb,
        'midGainDb': midGainDb,
        'midFreqHz': midFreqHz,
        'airGainDb': airGainDb,
      };

  factory StemEqBands.fromJson(Map<String, dynamic> json) {
    return StemEqBands(
      highpassHz: (json['highpassHz'] as num?)?.toDouble() ?? 80.0,
      lowGainDb: (json['lowGainDb'] as num?)?.toDouble() ?? 0.0,
      midGainDb: (json['midGainDb'] as num?)?.toDouble() ?? 0.0,
      midFreqHz: (json['midFreqHz'] as num?)?.toDouble() ?? 1500.0,
      airGainDb: (json['airGainDb'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Vocals Mastering Chain Configuration (REQ-MST-DOM-01).
@immutable
class VocalsMasteringConfig {
  final VocalCleanseFlavor flavor;
  final double neuralDenoiseStrength; // 0.0 .. 1.0
  final double neuralDereverbStrength; // 0.0 .. 1.0
  final double compressionAmount; // 0.0 .. 1.0
  final StemEqBands eq;

  const VocalsMasteringConfig({
    this.flavor = VocalCleanseFlavor.studioClean,
    this.neuralDenoiseStrength = 0.85,
    this.neuralDereverbStrength = 0.65,
    this.compressionAmount = 0.65,
    this.eq = const StemEqBands(
      highpassHz: 95.0,
      lowGainDb: 0.5,
      midGainDb: 1.5,
      midFreqHz: 2400.0,
      airGainDb: 3.5,
    ),
  });

  VocalsMasteringConfig copyWith({
    VocalCleanseFlavor? flavor,
    double? neuralDenoiseStrength,
    double? neuralDereverbStrength,
    double? compressionAmount,
    StemEqBands? eq,
  }) {
    return VocalsMasteringConfig(
      flavor: flavor ?? this.flavor,
      neuralDenoiseStrength:
          neuralDenoiseStrength ?? this.neuralDenoiseStrength,
      neuralDereverbStrength:
          neuralDereverbStrength ?? this.neuralDereverbStrength,
      compressionAmount: compressionAmount ?? this.compressionAmount,
      eq: eq ?? this.eq,
    );
  }

  Map<String, dynamic> toJson() => {
        'flavor': flavor.wireValue,
        'neuralDenoiseStrength': neuralDenoiseStrength,
        'neuralDereverbStrength': neuralDereverbStrength,
        'compressionAmount': compressionAmount,
        'eq': eq.toJson(),
      };

  factory VocalsMasteringConfig.fromJson(Map<String, dynamic> json) {
    return VocalsMasteringConfig(
      flavor: VocalCleanseFlavor.fromWire(json['flavor'] as String?),
      neuralDenoiseStrength:
          (json['neuralDenoiseStrength'] as num?)?.toDouble() ?? 0.85,
      neuralDereverbStrength:
          (json['neuralDereverbStrength'] as num?)?.toDouble() ?? 0.65,
      compressionAmount:
          (json['compressionAmount'] as num?)?.toDouble() ?? 0.65,
      eq: json['eq'] is Map
          ? StemEqBands.fromJson(Map<String, dynamic>.from(json['eq'] as Map))
          : const StemEqBands(
              highpassHz: 95.0,
              lowGainDb: 0.5,
              midGainDb: 1.5,
              midFreqHz: 2400.0,
              airGainDb: 3.5,
            ),
    );
  }
}

/// Bass / Log Drum Mastering Chain Configuration (REQ-MST-DOM-01).
@immutable
class BassMasteringConfig {
  final BassCharacterFlavor flavor;
  final double subHarmonicMix; // 0.0 .. 1.0 (35-55 Hz sub-octave)
  final double knockDriveDb; // 0.0 .. 9.0 dB (165 Hz tube drive)
  final double sidechainDuckDb; // -6.0 .. 0.0 dB (kick ducking)
  final StemEqBands eq;

  const BassMasteringConfig({
    this.flavor = BassCharacterFlavor.heavyWoodenKnock,
    this.subHarmonicMix = 0.55,
    this.knockDriveDb = 4.5,
    this.sidechainDuckDb = -3.5,
    this.eq = const StemEqBands(
      highpassHz: 30.0,
      lowGainDb: 3.5,
      midGainDb: 3.0,
      midFreqHz: 165.0,
      airGainDb: 1.0,
    ),
  });

  BassMasteringConfig copyWith({
    BassCharacterFlavor? flavor,
    double? subHarmonicMix,
    double? knockDriveDb,
    double? sidechainDuckDb,
    StemEqBands? eq,
  }) {
    return BassMasteringConfig(
      flavor: flavor ?? this.flavor,
      subHarmonicMix: subHarmonicMix ?? this.subHarmonicMix,
      knockDriveDb: knockDriveDb ?? this.knockDriveDb,
      sidechainDuckDb: sidechainDuckDb ?? this.sidechainDuckDb,
      eq: eq ?? this.eq,
    );
  }

  Map<String, dynamic> toJson() => {
        'flavor': flavor.wireValue,
        'subHarmonicMix': subHarmonicMix,
        'knockDriveDb': knockDriveDb,
        'sidechainDuckDb': sidechainDuckDb,
        'eq': eq.toJson(),
      };

  factory BassMasteringConfig.fromJson(Map<String, dynamic> json) {
    return BassMasteringConfig(
      flavor: BassCharacterFlavor.fromWire(json['flavor'] as String?),
      subHarmonicMix: (json['subHarmonicMix'] as num?)?.toDouble() ?? 0.55,
      knockDriveDb: (json['knockDriveDb'] as num?)?.toDouble() ?? 4.5,
      sidechainDuckDb: (json['sidechainDuckDb'] as num?)?.toDouble() ?? -3.5,
      eq: json['eq'] is Map
          ? StemEqBands.fromJson(Map<String, dynamic>.from(json['eq'] as Map))
          : const StemEqBands(
              highpassHz: 30.0,
              lowGainDb: 3.5,
              midGainDb: 3.0,
              midFreqHz: 165.0,
              airGainDb: 1.0,
            ),
    );
  }
}

/// Drums Mastering Chain Configuration (REQ-MST-DOM-01).
@immutable
class DrumsMasteringConfig {
  final DrumCharacterFlavor flavor;
  final double transientAttackSnap; // -1.0 .. +1.0
  final double parallelCrushMix; // 0.0 .. 1.0
  final StemEqBands eq;

  const DrumsMasteringConfig({
    this.flavor = DrumCharacterFlavor.crispShakers,
    this.transientAttackSnap = 0.45,
    this.parallelCrushMix = 0.3,
    this.eq = const StemEqBands(
      highpassHz: 45.0,
      lowGainDb: 1.0,
      midGainDb: -2.5,
      midFreqHz: 320.0,
      airGainDb: 2.5,
    ),
  });

  DrumsMasteringConfig copyWith({
    DrumCharacterFlavor? flavor,
    double? transientAttackSnap,
    double? parallelCrushMix,
    StemEqBands? eq,
  }) {
    return DrumsMasteringConfig(
      flavor: flavor ?? this.flavor,
      transientAttackSnap: transientAttackSnap ?? this.transientAttackSnap,
      parallelCrushMix: parallelCrushMix ?? this.parallelCrushMix,
      eq: eq ?? this.eq,
    );
  }

  Map<String, dynamic> toJson() => {
        'flavor': flavor.wireValue,
        'transientAttackSnap': transientAttackSnap,
        'parallelCrushMix': parallelCrushMix,
        'eq': eq.toJson(),
      };

  factory DrumsMasteringConfig.fromJson(Map<String, dynamic> json) {
    return DrumsMasteringConfig(
      flavor: DrumCharacterFlavor.fromWire(json['flavor'] as String?),
      transientAttackSnap:
          (json['transientAttackSnap'] as num?)?.toDouble() ?? 0.45,
      parallelCrushMix: (json['parallelCrushMix'] as num?)?.toDouble() ?? 0.3,
      eq: json['eq'] is Map
          ? StemEqBands.fromJson(Map<String, dynamic>.from(json['eq'] as Map))
          : const StemEqBands(
              highpassHz: 45.0,
              lowGainDb: 1.0,
              midGainDb: -2.5,
              midFreqHz: 320.0,
              airGainDb: 2.5,
            ),
    );
  }
}

/// Melodic Mastering Chain Configuration (REQ-MST-DOM-01).
@immutable
class MelodicMasteringConfig {
  final MelodicCharacterFlavor flavor;
  final double midVocalPocketCutDb; // -6.0 .. 0.0 dB
  final double stereoWidthBoost; // 0.0 .. 1.0
  final StemEqBands eq;

  const MelodicMasteringConfig({
    this.flavor = MelodicCharacterFlavor.wideStereoPocket,
    this.midVocalPocketCutDb = -2.5,
    this.stereoWidthBoost = 0.35,
    this.eq = const StemEqBands(
      highpassHz: 110.0,
      lowGainDb: -1.5,
      midGainDb: -2.0,
      midFreqHz: 1800.0,
      airGainDb: 2.0,
    ),
  });

  MelodicMasteringConfig copyWith({
    MelodicCharacterFlavor? flavor,
    double? midVocalPocketCutDb,
    double? stereoWidthBoost,
    StemEqBands? eq,
  }) {
    return MelodicMasteringConfig(
      flavor: flavor ?? this.flavor,
      midVocalPocketCutDb: midVocalPocketCutDb ?? this.midVocalPocketCutDb,
      stereoWidthBoost: stereoWidthBoost ?? this.stereoWidthBoost,
      eq: eq ?? this.eq,
    );
  }

  Map<String, dynamic> toJson() => {
        'flavor': flavor.wireValue,
        'midVocalPocketCutDb': midVocalPocketCutDb,
        'stereoWidthBoost': stereoWidthBoost,
        'eq': eq.toJson(),
      };

  factory MelodicMasteringConfig.fromJson(Map<String, dynamic> json) {
    return MelodicMasteringConfig(
      flavor: MelodicCharacterFlavor.fromWire(json['flavor'] as String?),
      midVocalPocketCutDb:
          (json['midVocalPocketCutDb'] as num?)?.toDouble() ?? -2.5,
      stereoWidthBoost: (json['stereoWidthBoost'] as num?)?.toDouble() ?? 0.35,
      eq: json['eq'] is Map
          ? StemEqBands.fromJson(Map<String, dynamic>.from(json['eq'] as Map))
          : const StemEqBands(
              highpassHz: 110.0,
              lowGainDb: -1.5,
              midGainDb: -2.0,
              midFreqHz: 1800.0,
              airGainDb: 2.0,
            ),
    );
  }
}

/// Canonical Stem Mastering Recipe (REQ-MST-DOM-01).
@immutable
class StemMasteringRecipe {
  final String presetId;
  final double targetLufs; // -9.5 or -14.0
  final double sketchpadLayerMix; // 0.0..1.0 (Phase 27 Sketchpad Layer Synergy)
  final VocalsMasteringConfig vocals;
  final BassMasteringConfig bass;
  final DrumsMasteringConfig drums;
  final MelodicMasteringConfig melodic;

  const StemMasteringRecipe({
    this.presetId = 'amapiano_club_knock',
    this.targetLufs = -9.5,
    this.sketchpadLayerMix = 0.0,
    this.vocals = const VocalsMasteringConfig(),
    this.bass = const BassMasteringConfig(),
    this.drums = const DrumsMasteringConfig(),
    this.melodic = const MelodicMasteringConfig(),
  });

  // Dynamic preview gain multipliers for Tier A zero-latency audition
  double get vocalGainMultiplier =>
      1.0 +
      vocals.neuralDenoiseStrength * 0.12 +
      (vocals.eq.airGainDb > 0 ? vocals.eq.airGainDb * 0.025 : 0.0);

  double get bassGainMultiplier =>
      1.0 +
      bass.subHarmonicMix * 0.25 +
      (bass.knockDriveDb / 9.0) * 0.2;

  double get drumsGainMultiplier =>
      1.0 +
      (drums.transientAttackSnap > 0 ? drums.transientAttackSnap * 0.18 : 0.0) +
      drums.parallelCrushMix * 0.15;

  double get melodicGainMultiplier => 1.0 + melodic.stereoWidthBoost * 0.15;

  double get estimatedIntegratedLufs => targetLufs;
  double get estimatedTruePeakDbtp => -1.0;

  StemMasteringRecipe copyWith({
    String? presetId,
    double? targetLufs,
    double? sketchpadLayerMix,
    VocalsMasteringConfig? vocals,
    BassMasteringConfig? bass,
    DrumsMasteringConfig? drums,
    MelodicMasteringConfig? melodic,
  }) {
    return StemMasteringRecipe(
      presetId: presetId ?? this.presetId,
      targetLufs: targetLufs ?? this.targetLufs,
      sketchpadLayerMix: sketchpadLayerMix ?? this.sketchpadLayerMix,
      vocals: vocals ?? this.vocals,
      bass: bass ?? this.bass,
      drums: drums ?? this.drums,
      melodic: melodic ?? this.melodic,
    );
  }

  Map<String, dynamic> toJson() => {
        'presetId': presetId,
        'targetLufs': targetLufs,
        'sketchpadLayerMix': sketchpadLayerMix,
        'vocals': vocals.toJson(),
        'bass': bass.toJson(),
        'drums': drums.toJson(),
        'melodic': melodic.toJson(),
      };

  factory StemMasteringRecipe.fromJson(Map<String, dynamic> json) {
    return StemMasteringRecipe(
      presetId: json['presetId'] as String? ?? 'amapiano_club_knock',
      targetLufs: (json['targetLufs'] as num?)?.toDouble() ?? -9.5,
      sketchpadLayerMix:
          (json['sketchpadLayerMix'] as num?)?.toDouble().clamp(0.0, 1.0) ??
              0.0,
      vocals: json['vocals'] is Map
          ? VocalsMasteringConfig.fromJson(
              Map<String, dynamic>.from(json['vocals'] as Map))
          : const VocalsMasteringConfig(),
      bass: json['bass'] is Map
          ? BassMasteringConfig.fromJson(
              Map<String, dynamic>.from(json['bass'] as Map))
          : const BassMasteringConfig(),
      drums: json['drums'] is Map
          ? DrumsMasteringConfig.fromJson(
              Map<String, dynamic>.from(json['drums'] as Map))
          : const DrumsMasteringConfig(),
      melodic: json['melodic'] is Map
          ? MelodicMasteringConfig.fromJson(
              Map<String, dynamic>.from(json['melodic'] as Map))
          : const MelodicMasteringConfig(),
    );
  }

  /// Automatically resolves the regional studio preset for a genre.
  static StemMasteringRecipe forGenre(String genre) {
    final g = genre.toLowerCase().trim();
    if (g.contains('private')) {
      return kGenreMasterPresets[1].recipe;
    }
    if (g.contains('gqom')) {
      return kGenreMasterPresets[2].recipe;
    }
    if (g.contains('maskandi') || g.contains('mbaqanga')) {
      return kGenreMasterPresets[3].recipe;
    }
    if (g.contains('house')) {
      return kGenreMasterPresets[4].recipe;
    }
    if (g.contains('kwaito') || g.contains('bubblegum') || g.contains('marabi')) {
      return kGenreMasterPresets[5].recipe;
    }
    return kGenreMasterPresets[0].recipe;
  }
}

/// Genre Master Preset descriptor.
@immutable
class GenreMasterPreset {
  final String id;
  final String name;
  final String genre;
  final String description;
  final StemMasteringRecipe recipe;

  const GenreMasterPreset({
    required this.id,
    required this.name,
    required this.genre,
    required this.description,
    required this.recipe,
  });
}

/// 6 Regional African Studio Presets (REQ-MST-DOM-02).
const List<GenreMasterPreset> kGenreMasterPresets = [
  GenreMasterPreset(
    id: 'amapiano_club_knock',
    name: 'Amapiano Club Knock',
    genre: 'Amapiano',
    description:
        'Chest-rattling 45Hz sub-octave log drum, -3.5dB kick sidechain, and crisp shaker sheen.',
    recipe: StemMasteringRecipe(
      presetId: 'amapiano_club_knock',
      targetLufs: -9.5,
      vocals: VocalsMasteringConfig(
        flavor: VocalCleanseFlavor.studioClean,
        neuralDenoiseStrength: 0.85,
        neuralDereverbStrength: 0.65,
        compressionAmount: 0.65,
        eq: StemEqBands(
          highpassHz: 95.0,
          lowGainDb: 0.5,
          midGainDb: 1.5,
          midFreqHz: 2400.0,
          airGainDb: 3.5,
        ),
      ),
      bass: BassMasteringConfig(
        flavor: BassCharacterFlavor.heavyWoodenKnock,
        subHarmonicMix: 0.55,
        knockDriveDb: 4.5,
        sidechainDuckDb: -3.5,
        eq: StemEqBands(
          highpassHz: 30.0,
          lowGainDb: 3.5,
          midGainDb: 3.0,
          midFreqHz: 165.0,
          airGainDb: 1.0,
        ),
      ),
      drums: DrumsMasteringConfig(
        flavor: DrumCharacterFlavor.crispShakers,
        transientAttackSnap: 0.45,
        parallelCrushMix: 0.3,
        eq: StemEqBands(
          highpassHz: 45.0,
          lowGainDb: 1.0,
          midGainDb: -2.5,
          midFreqHz: 320.0,
          airGainDb: 2.5,
        ),
      ),
      melodic: MelodicMasteringConfig(
        flavor: MelodicCharacterFlavor.wideStereoPocket,
        midVocalPocketCutDb: -2.5,
        stereoWidthBoost: 0.35,
        eq: StemEqBands(
          highpassHz: 110.0,
          lowGainDb: -1.5,
          midGainDb: -2.0,
          midFreqHz: 1800.0,
          airGainDb: 2.0,
        ),
      ),
    ),
  ),
  GenreMasterPreset(
    id: 'private_school_warmth',
    name: 'Private School Soul',
    genre: 'Private School Amapiano',
    description:
        'Lush Kelvin Momo-style Rhodes warmth, smooth sub-bass glide, and intimate vocal air.',
    recipe: StemMasteringRecipe(
      presetId: 'private_school_warmth',
      targetLufs: -14.0,
      vocals: VocalsMasteringConfig(
        flavor: VocalCleanseFlavor.warmIntimate,
        neuralDenoiseStrength: 0.8,
        neuralDereverbStrength: 0.5,
        compressionAmount: 0.55,
        eq: StemEqBands(
          highpassHz: 85.0,
          lowGainDb: 1.5,
          midGainDb: 1.0,
          midFreqHz: 2000.0,
          airGainDb: 2.5,
        ),
      ),
      bass: BassMasteringConfig(
        flavor: BassCharacterFlavor.smoothGlide,
        subHarmonicMix: 0.45,
        knockDriveDb: 2.5,
        sidechainDuckDb: -2.5,
        eq: StemEqBands(
          highpassHz: 28.0,
          lowGainDb: 2.5,
          midGainDb: 1.5,
          midFreqHz: 150.0,
          airGainDb: 0.0,
        ),
      ),
      drums: DrumsMasteringConfig(
        flavor: DrumCharacterFlavor.vintageWarm,
        transientAttackSnap: 0.25,
        parallelCrushMix: 0.2,
        eq: StemEqBands(
          highpassHz: 40.0,
          lowGainDb: 1.5,
          midGainDb: -1.5,
          midFreqHz: 350.0,
          airGainDb: 1.5,
        ),
      ),
      melodic: MelodicMasteringConfig(
        flavor: MelodicCharacterFlavor.warmRhodes,
        midVocalPocketCutDb: -2.0,
        stereoWidthBoost: 0.45,
        eq: StemEqBands(
          highpassHz: 95.0,
          lowGainDb: 1.5,
          midGainDb: 1.0,
          midFreqHz: 1200.0,
          airGainDb: 2.0,
        ),
      ),
    ),
  ),
  GenreMasterPreset(
    id: 'gqom_warehouse_sub',
    name: 'Gqom Warehouse Sub',
    genre: 'Gqom',
    description:
        'Relentless Durban warehouse sub-808 pressure, aggressive club punch, and dark atmosphere.',
    recipe: StemMasteringRecipe(
      presetId: 'gqom_warehouse_sub',
      targetLufs: -9.5,
      vocals: VocalsMasteringConfig(
        flavor: VocalCleanseFlavor.wideAnthem,
        neuralDenoiseStrength: 0.75,
        neuralDereverbStrength: 0.4,
        compressionAmount: 0.75,
        eq: StemEqBands(
          highpassHz: 105.0,
          lowGainDb: 0.0,
          midGainDb: 2.0,
          midFreqHz: 2600.0,
          airGainDb: 3.0,
        ),
      ),
      bass: BassMasteringConfig(
        flavor: BassCharacterFlavor.deepSub808,
        subHarmonicMix: 0.7,
        knockDriveDb: 5.5,
        sidechainDuckDb: -4.5,
        eq: StemEqBands(
          highpassHz: 25.0,
          lowGainDb: 4.5,
          midGainDb: 2.0,
          midFreqHz: 140.0,
          airGainDb: 0.5,
        ),
      ),
      drums: DrumsMasteringConfig(
        flavor: DrumCharacterFlavor.clubPunch,
        transientAttackSnap: 0.65,
        parallelCrushMix: 0.45,
        eq: StemEqBands(
          highpassHz: 38.0,
          lowGainDb: 2.5,
          midGainDb: -3.0,
          midFreqHz: 300.0,
          airGainDb: 2.0,
        ),
      ),
      melodic: MelodicMasteringConfig(
        flavor: MelodicCharacterFlavor.wideStereoPocket,
        midVocalPocketCutDb: -3.0,
        stereoWidthBoost: 0.4,
        eq: StemEqBands(
          highpassHz: 120.0,
          lowGainDb: -2.0,
          midGainDb: -1.5,
          midFreqHz: 1800.0,
          airGainDb: 1.5,
        ),
      ),
    ),
  ),
  GenreMasterPreset(
    id: 'maskandi_acoustic_clarity',
    name: 'Maskandi Acoustic Clarity',
    genre: 'Maskandi',
    description:
        'Crystal-clear ukuvamba acoustic guitar picking, natural vocal front-presence, and tight bass.',
    recipe: StemMasteringRecipe(
      presetId: 'maskandi_acoustic_clarity',
      targetLufs: -14.0,
      vocals: VocalsMasteringConfig(
        flavor: VocalCleanseFlavor.studioClean,
        neuralDenoiseStrength: 0.9,
        neuralDereverbStrength: 0.75,
        compressionAmount: 0.6,
        eq: StemEqBands(
          highpassHz: 90.0,
          lowGainDb: 0.5,
          midGainDb: 2.0,
          midFreqHz: 2200.0,
          airGainDb: 4.0,
        ),
      ),
      bass: BassMasteringConfig(
        flavor: BassCharacterFlavor.natural,
        subHarmonicMix: 0.25,
        knockDriveDb: 2.0,
        sidechainDuckDb: -2.0,
        eq: StemEqBands(
          highpassHz: 35.0,
          lowGainDb: 2.0,
          midGainDb: 2.5,
          midFreqHz: 180.0,
          airGainDb: 1.0,
        ),
      ),
      drums: DrumsMasteringConfig(
        flavor: DrumCharacterFlavor.crispShakers,
        transientAttackSnap: 0.35,
        parallelCrushMix: 0.2,
        eq: StemEqBands(
          highpassHz: 45.0,
          lowGainDb: 1.0,
          midGainDb: -2.0,
          midFreqHz: 320.0,
          airGainDb: 2.5,
        ),
      ),
      melodic: MelodicMasteringConfig(
        flavor: MelodicCharacterFlavor.brightAcoustic,
        midVocalPocketCutDb: -2.0,
        stereoWidthBoost: 0.3,
        eq: StemEqBands(
          highpassHz: 100.0,
          lowGainDb: 0.0,
          midGainDb: 2.5,
          midFreqHz: 2800.0,
          airGainDb: 3.5,
        ),
      ),
    ),
  ),
  GenreMasterPreset(
    id: 'afro_house_horizon',
    name: 'Afro House Horizon',
    genre: 'Afro House',
    description:
        'Panoramic festival stereo width, driving four-on-the-floor kick punch, and soaring vocals.',
    recipe: StemMasteringRecipe(
      presetId: 'afro_house_horizon',
      targetLufs: -9.5,
      vocals: VocalsMasteringConfig(
        flavor: VocalCleanseFlavor.wideAnthem,
        neuralDenoiseStrength: 0.85,
        neuralDereverbStrength: 0.55,
        compressionAmount: 0.65,
        eq: StemEqBands(
          highpassHz: 95.0,
          lowGainDb: 0.0,
          midGainDb: 1.5,
          midFreqHz: 2500.0,
          airGainDb: 4.0,
        ),
      ),
      bass: BassMasteringConfig(
        flavor: BassCharacterFlavor.deepSub808,
        subHarmonicMix: 0.5,
        knockDriveDb: 3.5,
        sidechainDuckDb: -4.0,
        eq: StemEqBands(
          highpassHz: 28.0,
          lowGainDb: 3.5,
          midGainDb: 1.5,
          midFreqHz: 150.0,
          airGainDb: 0.5,
        ),
      ),
      drums: DrumsMasteringConfig(
        flavor: DrumCharacterFlavor.clubPunch,
        transientAttackSnap: 0.5,
        parallelCrushMix: 0.35,
        eq: StemEqBands(
          highpassHz: 40.0,
          lowGainDb: 2.0,
          midGainDb: -2.5,
          midFreqHz: 310.0,
          airGainDb: 3.0,
        ),
      ),
      melodic: MelodicMasteringConfig(
        flavor: MelodicCharacterFlavor.wideStereoPocket,
        midVocalPocketCutDb: -2.5,
        stereoWidthBoost: 0.5,
        eq: StemEqBands(
          highpassHz: 115.0,
          lowGainDb: -1.0,
          midGainDb: -2.0,
          midFreqHz: 1800.0,
          airGainDb: 2.5,
        ),
      ),
    ),
  ),
  GenreMasterPreset(
    id: 'kwaito_golden_tape',
    name: 'Kwaito Golden Tape',
    genre: 'Kwaito',
    description:
        '90s Soweto analog tape saturation, heavy slowed-down bass groove, and punchy vocal cadence.',
    recipe: StemMasteringRecipe(
      presetId: 'kwaito_golden_tape',
      targetLufs: -9.5,
      vocals: VocalsMasteringConfig(
        flavor: VocalCleanseFlavor.warmIntimate,
        neuralDenoiseStrength: 0.8,
        neuralDereverbStrength: 0.6,
        compressionAmount: 0.7,
        eq: StemEqBands(
          highpassHz: 88.0,
          lowGainDb: 1.0,
          midGainDb: 2.0,
          midFreqHz: 2100.0,
          airGainDb: 2.5,
        ),
      ),
      bass: BassMasteringConfig(
        flavor: BassCharacterFlavor.heavyWoodenKnock,
        subHarmonicMix: 0.5,
        knockDriveDb: 4.0,
        sidechainDuckDb: -3.0,
        eq: StemEqBands(
          highpassHz: 30.0,
          lowGainDb: 3.5,
          midGainDb: 2.5,
          midFreqHz: 160.0,
          airGainDb: 0.5,
        ),
      ),
      drums: DrumsMasteringConfig(
        flavor: DrumCharacterFlavor.vintageWarm,
        transientAttackSnap: 0.4,
        parallelCrushMix: 0.35,
        eq: StemEqBands(
          highpassHz: 42.0,
          lowGainDb: 2.0,
          midGainDb: -1.5,
          midFreqHz: 330.0,
          airGainDb: 1.5,
        ),
      ),
      melodic: MelodicMasteringConfig(
        flavor: MelodicCharacterFlavor.warmRhodes,
        midVocalPocketCutDb: -2.0,
        stereoWidthBoost: 0.25,
        eq: StemEqBands(
          highpassHz: 100.0,
          lowGainDb: 1.0,
          midGainDb: 0.5,
          midFreqHz: 1500.0,
          airGainDb: 1.5,
        ),
      ),
    ),
  ),
];

