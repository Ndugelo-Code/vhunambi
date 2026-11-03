import '../../../../features/studio/domain/models/melody_sketchpad_models.dart';

/// Pitch and vibrato contour layer of SoundSignatureDna (REQ-SIG-DNA-01 / Design 2.1).
///
/// Encapsulates sampled F0 curve (50 Hz frames, cents-quantized MIDI), root pitch class,
/// African scale mode estimation with confidence, stability score, and natural vibrato metrics.
class PitchContourProfile {
  /// Sentinel value indicating an unvoiced frame in [f0CentsMidi].
  static const int unvoicedSentinel = -32768;

  const PitchContourProfile({
    required this.f0CentsMidi,
    required this.rootPitchClass,
    required this.scaleMode,
    required this.keyConfidence,
    required this.stabilityScore,
    required this.naturalVibratoHz,
    required this.naturalVibratoDepthCents,
  });

  /// Sampled fundamental frequency contour at 50 Hz frame rate.
  /// Each entry is (MIDI_semitones * 100). Unvoiced frames use [unvoicedSentinel].
  final List<int> f0CentsMidi;

  /// Root pitch class (0..11 where 0=C, 1=C#, 2=D, ... 9=A, 11=B).
  final int rootPitchClass;

  /// Estimated or user-selected African musical scale mode.
  final AfricanScaleMode scaleMode;

  /// Key estimation confidence score (0.0 .. 1.0).
  final double keyConfidence;

  /// Overall pitch stability score (0.0 .. 1.0).
  final double stabilityScore;

  /// Measured natural vibrato rate in Hz (0.0 if no vibrato detected).
  final double naturalVibratoHz;

  /// Measured natural vibrato depth in cents peak-to-peak.
  final double naturalVibratoDepthCents;

  PitchContourProfile copyWith({
    List<int>? f0CentsMidi,
    int? rootPitchClass,
    AfricanScaleMode? scaleMode,
    double? keyConfidence,
    double? stabilityScore,
    double? naturalVibratoHz,
    double? naturalVibratoDepthCents,
  }) {
    return PitchContourProfile(
      f0CentsMidi: f0CentsMidi ?? this.f0CentsMidi,
      rootPitchClass: rootPitchClass ?? this.rootPitchClass,
      scaleMode: scaleMode ?? this.scaleMode,
      keyConfidence: keyConfidence ?? this.keyConfidence,
      stabilityScore: stabilityScore ?? this.stabilityScore,
      naturalVibratoHz: naturalVibratoHz ?? this.naturalVibratoHz,
      naturalVibratoDepthCents:
          naturalVibratoDepthCents ?? this.naturalVibratoDepthCents,
    );
  }

  Map<String, dynamic> toJson() => {
        'f0CentsMidi': f0CentsMidi,
        'rootPitchClass': rootPitchClass,
        'scaleMode': scaleMode.wireValue,
        'keyConfidence': keyConfidence,
        'stabilityScore': stabilityScore,
        'naturalVibratoHz': naturalVibratoHz,
        'naturalVibratoDepthCents': naturalVibratoDepthCents,
      };

  factory PitchContourProfile.fromJson(Map<String, dynamic> json) {
    return PitchContourProfile(
      f0CentsMidi: (json['f0CentsMidi'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      rootPitchClass: (json['rootPitchClass'] as num?)?.toInt() ?? 9, // default A
      scaleMode: AfricanScaleMode.fromWire(json['scaleMode'] as String?),
      keyConfidence: (json['keyConfidence'] as num?)?.toDouble() ?? 0.5,
      stabilityScore: (json['stabilityScore'] as num?)?.toDouble() ?? 0.5,
      naturalVibratoHz: (json['naturalVibratoHz'] as num?)?.toDouble() ?? 0.0,
      naturalVibratoDepthCents:
          (json['naturalVibratoDepthCents'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

