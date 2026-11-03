/// Non-destructive vocal idealization recipe layer of SoundSignatureDna (REQ-SIG-DNA-01 / Design 2.1).
///
/// Holds the user-sculpted parameters applied over the raw audio take during
/// 44.1 kHz TD-PSOLA resynthesis and cloud Seed-VC rendering.
class SoundIdealizerRecipe {
  const SoundIdealizerRecipe({
    this.pitchScaleLock = 0.90,
    this.vibratoAndSustainPolish = 0.75,
    this.formantDepthShiftSemitones = 0.0,
    this.chestPowerAndAirBoost = 0.80,
    this.quantizePocketStrength = 0.85,
    this.hybridArchetypeId,
    this.hybridBlendMix = 0.25,
    this.referenceCleanup = 0.70,
  });

  /// Degree to which off-key F0 notes snap to the active African scale (0.0 .. 1.0).
  /// Preserves intentional glides by slope detection.
  final double pitchScaleLock;

  /// High-frequency tremor removal and 5.2 Hz studio vibrato injection (0.0 .. 1.0).
  final double vibratoAndSustainPolish;

  /// Vocal tract formant depth shift in semitones (-3.0 .. +3.0) independent of pitch.
  final double formantDepthShiftSemitones;

  /// Dynamics compression, 140 Hz chest weight, and 11.5 kHz air enhancement (0.0 .. 1.0).
  final double chestPowerAndAirBoost;

  /// Micro-timing alignment of syllable and note attacks to the 16-step grid (0.0 .. 1.0).
  final double quantizePocketStrength;

  /// Optional Regional African Voice Archetype ID for timbre blending (e.g. 'soweto_golden').
  final String? hybridArchetypeId;

  /// Proportion of hybrid voice archetype blended into the timbre (0.0 .. 0.75).
  final double hybridBlendMix;

  /// Decision-directed Wiener denoise and room dereverberation strength (0.0 .. 1.0).
  final double referenceCleanup;

  SoundIdealizerRecipe copyWith({
    double? pitchScaleLock,
    double? vibratoAndSustainPolish,
    double? formantDepthShiftSemitones,
    double? chestPowerAndAirBoost,
    double? quantizePocketStrength,
    String? hybridArchetypeId,
    bool clearHybridArchetype = false,
    double? hybridBlendMix,
    double? referenceCleanup,
  }) {
    return SoundIdealizerRecipe(
      pitchScaleLock: pitchScaleLock ?? this.pitchScaleLock,
      vibratoAndSustainPolish:
          vibratoAndSustainPolish ?? this.vibratoAndSustainPolish,
      formantDepthShiftSemitones:
          formantDepthShiftSemitones ?? this.formantDepthShiftSemitones,
      chestPowerAndAirBoost:
          chestPowerAndAirBoost ?? this.chestPowerAndAirBoost,
      quantizePocketStrength:
          quantizePocketStrength ?? this.quantizePocketStrength,
      hybridArchetypeId: clearHybridArchetype
          ? null
          : (hybridArchetypeId ?? this.hybridArchetypeId),
      hybridBlendMix: hybridBlendMix ?? this.hybridBlendMix,
      referenceCleanup: referenceCleanup ?? this.referenceCleanup,
    );
  }

  Map<String, dynamic> toJson() => {
        'pitchScaleLock': pitchScaleLock,
        'vibratoAndSustainPolish': vibratoAndSustainPolish,
        'formantDepthShiftSemitones': formantDepthShiftSemitones,
        'chestPowerAndAirBoost': chestPowerAndAirBoost,
        'quantizePocketStrength': quantizePocketStrength,
        'hybridArchetypeId': hybridArchetypeId,
        'hybridBlendMix': hybridBlendMix,
        'referenceCleanup': referenceCleanup,
      };

  factory SoundIdealizerRecipe.fromJson(Map<String, dynamic> json) {
    return SoundIdealizerRecipe(
      pitchScaleLock: (json['pitchScaleLock'] as num?)?.toDouble() ?? 0.90,
      vibratoAndSustainPolish:
          (json['vibratoAndSustainPolish'] as num?)?.toDouble() ?? 0.75,
      formantDepthShiftSemitones:
          (json['formantDepthShiftSemitones'] as num?)?.toDouble() ?? 0.0,
      chestPowerAndAirBoost:
          (json['chestPowerAndAirBoost'] as num?)?.toDouble() ?? 0.80,
      quantizePocketStrength:
          (json['quantizePocketStrength'] as num?)?.toDouble() ?? 0.85,
      hybridArchetypeId: json['hybridArchetypeId'] as String?,
      hybridBlendMix: (json['hybridBlendMix'] as num?)?.toDouble() ?? 0.25,
      referenceCleanup: (json['referenceCleanup'] as num?)?.toDouble() ?? 0.70,
    );
  }
}

