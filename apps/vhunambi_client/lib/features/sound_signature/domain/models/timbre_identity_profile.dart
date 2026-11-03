/// Timbre Identity Layer of SoundSignatureDna (REQ-SIG-DNA-01 / Design 2.1).
///
/// Encapsulates spectral-envelope descriptors, physical formant resonance
/// peaks (F1-F4) independent of pitch, glottal warmth proxy, and harmonic purity.
class TimbreIdentityProfile {
  const TimbreIdentityProfile({
    required this.cepstralDescriptor,
    required this.formantsHz,
    required this.glottalWarmth,
    required this.harmonicPurityRatio,
  });

  /// 16-coefficient compact mel-frequency spectral envelope descriptor (c1..c16).
  final List<double> cepstralDescriptor;

  /// Resonant formants [F1, F2, F3, F4] in Hz (capturing physical tract/body geometry).
  /// A value of 0.0 indicates unmeasured or low-confidence formant.
  final List<double> formantsHz;

  /// Glottal warmth proxy (0.0 .. 1.0) derived from H1-H2 level differential.
  final double glottalWarmth;

  /// Harmonic Purity Ratio (0.0 .. 1.0) derived from HNR (clamp(HNR/30, 0, 1)).
  final double harmonicPurityRatio;

  TimbreIdentityProfile copyWith({
    List<double>? cepstralDescriptor,
    List<double>? formantsHz,
    double? glottalWarmth,
    double? harmonicPurityRatio,
  }) {
    return TimbreIdentityProfile(
      cepstralDescriptor: cepstralDescriptor ?? this.cepstralDescriptor,
      formantsHz: formantsHz ?? this.formantsHz,
      glottalWarmth: glottalWarmth ?? this.glottalWarmth,
      harmonicPurityRatio: harmonicPurityRatio ?? this.harmonicPurityRatio,
    );
  }

  Map<String, dynamic> toJson() => {
    'cepstralDescriptor': cepstralDescriptor,
    'formantsHz': formantsHz,
    'glottalWarmth': glottalWarmth,
    'harmonicPurityRatio': harmonicPurityRatio,
  };

  factory TimbreIdentityProfile.fromJson(Map<String, dynamic> json) {
    return TimbreIdentityProfile(
      cepstralDescriptor:
          (json['cepstralDescriptor'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [],
      formantsHz:
          (json['formantsHz'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [0.0, 0.0, 0.0, 0.0],
      glottalWarmth: (json['glottalWarmth'] as num?)?.toDouble() ?? 0.5,
      harmonicPurityRatio:
          (json['harmonicPurityRatio'] as num?)?.toDouble() ?? 0.5,
    );
  }
}
