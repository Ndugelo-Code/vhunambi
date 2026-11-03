/// Input audio recording quality metrics layer of SoundSignatureDna (REQ-SIG-DNA-01 / Design 2.1).
///
/// Encapsulates acoustic signal-to-noise ratio, digital clipping percentage,
/// bandwidth rolloff, integrated loudness in LUFS, estimated room reverberation,
/// and voiced speech ratio.
class RecordingQualityProfile {
  const RecordingQualityProfile({
    required this.snrDb,
    required this.clippingPct,
    required this.bandwidthHz,
    required this.loudnessLufs,
    required this.reverbEdtMs,
    required this.voicedRatio,
  });

  /// Signal-to-noise ratio in decibels (L90 - L10 energy differential).
  final double snrDb;

  /// Percentage of samples with absolute amplitude >= 0.995 (0.0 .. 100.0).
  final double clippingPct;

  /// Effective upper frequency bandwidth cutoff in Hz (-20 dB rolloff).
  final double bandwidthHz;

  /// Integrated loudness in LUFS (BS.1770 approximation).
  final double loudnessLufs;

  /// Estimated room early decay time (EDT) in milliseconds.
  final double reverbEdtMs;

  /// Proportion of analyzed frames detected as voiced (0.0 .. 1.0).
  final double voicedRatio;

  /// Traffic-light input quality verdict for UI feedback (REQ-SIG-INTAKE-05).
  RecordingQualityVerdict get verdict {
    if (clippingPct > 5.0 || voicedRatio < 0.15) {
      return RecordingQualityVerdict.poor;
    }
    if (snrDb < 12.0 || clippingPct > 1.0 || bandwidthHz < 7000.0) {
      return RecordingQualityVerdict.fair;
    }
    return RecordingQualityVerdict.good;
  }

  /// Plain-language feedback and suggested remediation for user guidance.
  String get remediationTip {
    if (clippingPct > 1.0) {
      return 'Microphone signal clipped. Move slightly further back from your phone.';
    }
    if (snrDb < 12.0) {
      return 'Background noise detected. Move to a quieter room for optimal voice clarity.';
    }
    if (reverbEdtMs > 350.0) {
      return 'Room echo detected. Record away from hard walls or large open spaces.';
    }
    if (bandwidthHz < 7000.0) {
      return 'Bandwidth limited phone mic. High-frequency air will be synthesized in studio.';
    }
    return 'Studio-grade signal clarity. Ready for vocal idealization.';
  }

  RecordingQualityProfile copyWith({
    double? snrDb,
    double? clippingPct,
    double? bandwidthHz,
    double? loudnessLufs,
    double? reverbEdtMs,
    double? voicedRatio,
  }) {
    return RecordingQualityProfile(
      snrDb: snrDb ?? this.snrDb,
      clippingPct: clippingPct ?? this.clippingPct,
      bandwidthHz: bandwidthHz ?? this.bandwidthHz,
      loudnessLufs: loudnessLufs ?? this.loudnessLufs,
      reverbEdtMs: reverbEdtMs ?? this.reverbEdtMs,
      voicedRatio: voicedRatio ?? this.voicedRatio,
    );
  }

  Map<String, dynamic> toJson() => {
        'snrDb': snrDb,
        'clippingPct': clippingPct,
        'bandwidthHz': bandwidthHz,
        'loudnessLufs': loudnessLufs,
        'reverbEdtMs': reverbEdtMs,
        'voicedRatio': voicedRatio,
      };

  factory RecordingQualityProfile.fromJson(Map<String, dynamic> json) {
    return RecordingQualityProfile(
      snrDb: (json['snrDb'] as num?)?.toDouble() ?? 24.0,
      clippingPct: (json['clippingPct'] as num?)?.toDouble() ?? 0.0,
      bandwidthHz: (json['bandwidthHz'] as num?)?.toDouble() ?? 16000.0,
      loudnessLufs: (json['loudnessLufs'] as num?)?.toDouble() ?? -20.0,
      reverbEdtMs: (json['reverbEdtMs'] as num?)?.toDouble() ?? 120.0,
      voicedRatio: (json['voicedRatio'] as num?)?.toDouble() ?? 0.75,
    );
  }
}

enum RecordingQualityVerdict {
  good('Studio Grade', 0xFF2ECC71),
  fair('Usable with Polish', 0xFFF39C12),
  poor('Needs Retake', 0xFFE74C3C);

  const RecordingQualityVerdict(this.label, this.colorValue);
  final String label;
  final int colorValue;
}

