import 'package:flutter/foundation.dart';

/// The 4 standard stem channels separated in the Vhunambi audio engine (REQ-MIX-01).
enum StemType {
  vocals,
  drums,
  bass, // Log Drum & Sub Bass
  melody, // Instruments, Keys & Synths
}

/// A single mixing channel strip with volume gain, pan, mute, and solo controls.
@immutable
class StemChannel {
  final StemType type;
  final String name;
  final String emoji;
  final double gain; // 0.0 to 1.5 (1.0 = unity gain / 0 dB)
  final double pan; // -1.0 (L) to +1.0 (R), 0.0 = Center
  final bool isMuted;
  final bool isSolo;

  const StemChannel({
    required this.type,
    required this.name,
    required this.emoji,
    this.gain = 1.0,
    this.pan = 0.0,
    this.isMuted = false,
    this.isSolo = false,
  });

  /// Computes effective audible volume factor considering global solo and channel mute states.
  double effectiveVolume(bool anySoloActive) {
    if (anySoloActive) {
      return isSolo ? gain : 0.0;
    }
    return isMuted ? 0.0 : gain;
  }

  /// Formatted decibel readout (e.g. "+0.0 dB", "-3.5 dB", "-inf dB").
  String get gainDecibels {
    if (gain <= 0.001) return '-inf dB';
    final normalized = (gain - 1.0) * 12.0; // Simulated dB range (-12 to +6 dB)
    final prefix = normalized >= 0 ? '+' : '';
    return '$prefix${normalized.toStringAsFixed(1)} dB';
  }

  StemChannel copyWith({
    double? gain,
    double? pan,
    bool? isMuted,
    bool? isSolo,
  }) {
    return StemChannel(
      type: type,
      name: name,
      emoji: emoji,
      gain: gain ?? this.gain,
      pan: pan ?? this.pan,
      isMuted: isMuted ?? this.isMuted,
      isSolo: isSolo ?? this.isSolo,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'name': name,
        'emoji': emoji,
        'gain': gain,
        'pan': pan,
        'isMuted': isMuted,
        'isSolo': isSolo,
      };

  factory StemChannel.fromJson(Map<String, dynamic> json) {
    return StemChannel(
      type: StemType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => StemType.vocals,
      ),
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      gain: (json['gain'] as num?)?.toDouble() ?? 1.0,
      pan: (json['pan'] as num?)?.toDouble() ?? 0.0,
      isMuted: (json['isMuted'] as bool?) ?? false,
      isSolo: (json['isSolo'] as bool?) ?? false,
    );
  }
}

/// Bantu Master Bus DSP Suite shaping final mix balance (REQ-MIX-03).
@immutable
class MasterBusDsp {
  /// Low-frequency analog drive & harmonic saturation for Amapiano log drums (0.0 to 1.0).
  final double logDrumSaturation;

  /// Ambient plate reverb tail tailored for indigenous vocal acoustics (0.0 to 1.0).
  final double vocalPlateReverb;

  /// Rhythmic sidechain compressor ducking behind heavy kicks (0.0 to 1.0).
  final double sidechainCompression;

  /// Spatial stereo imaging width expansion (0.0 = Mono, 1.0 = Normal, 1.5 = Wide).
  final double stereoWidth;

  const MasterBusDsp({
    this.logDrumSaturation = 0.4,
    this.vocalPlateReverb = 0.3,
    this.sidechainCompression = 0.5,
    this.stereoWidth = 1.0,
  });

  MasterBusDsp copyWith({
    double? logDrumSaturation,
    double? vocalPlateReverb,
    double? sidechainCompression,
    double? stereoWidth,
  }) {
    return MasterBusDsp(
      logDrumSaturation: logDrumSaturation ?? this.logDrumSaturation,
      vocalPlateReverb: vocalPlateReverb ?? this.vocalPlateReverb,
      sidechainCompression:
          sidechainCompression ?? this.sidechainCompression,
      stereoWidth: stereoWidth ?? this.stereoWidth,
    );
  }

  Map<String, dynamic> toJson() => {
        'logDrumSaturation': logDrumSaturation,
        'vocalPlateReverb': vocalPlateReverb,
        'sidechainCompression': sidechainCompression,
        'stereoWidth': stereoWidth,
      };

  factory MasterBusDsp.fromJson(Map<String, dynamic> json) {
    return MasterBusDsp(
      logDrumSaturation:
          (json['logDrumSaturation'] as num?)?.toDouble() ?? 0.4,
      vocalPlateReverb:
          (json['vocalPlateReverb'] as num?)?.toDouble() ?? 0.3,
      sidechainCompression:
          (json['sidechainCompression'] as num?)?.toDouble() ?? 0.5,
      stereoWidth: (json['stereoWidth'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

/// State representation for the Pocket 4-Channel Stem Mixer (REQ-MIX-01).
@immutable
class StemMixerState {
  final List<StemChannel> channels;
  final MasterBusDsp masterDsp;
  final bool isBouncing;
  final String? activeTrackId;
  final String? activeTrackTitle;
  final String? lastBouncedAudioPath;

  const StemMixerState({
    required this.channels,
    this.masterDsp = const MasterBusDsp(),
    this.isBouncing = false,
    this.activeTrackId,
    this.activeTrackTitle,
    this.lastBouncedAudioPath,
  });

  bool get anySoloActive => channels.any((c) => c.isSolo);

  StemChannel channel(StemType type) => channelFor(type);

  StemChannel channelFor(StemType type) {
    return channels.firstWhere(
      (c) => c.type == type,
      orElse: () => channels.first,
    );
  }

  StemMixerState copyWith({
    List<StemChannel>? channels,
    MasterBusDsp? masterDsp,
    bool? isBouncing,
    String? activeTrackId,
    String? activeTrackTitle,
    String? lastBouncedAudioPath,
  }) {
    return StemMixerState(
      channels: channels ?? this.channels,
      masterDsp: masterDsp ?? this.masterDsp,
      isBouncing: isBouncing ?? this.isBouncing,
      activeTrackId: activeTrackId ?? this.activeTrackId,
      activeTrackTitle: activeTrackTitle ?? this.activeTrackTitle,
      lastBouncedAudioPath:
          lastBouncedAudioPath ?? this.lastBouncedAudioPath,
    );
  }
}

/// Default 4-channel configuration.
const List<StemChannel> kDefaultStemChannels = [
  StemChannel(type: StemType.vocals, name: 'Vocals', emoji: '🎤'),
  StemChannel(type: StemType.drums, name: 'Drums', emoji: '🥁'),
  StemChannel(type: StemType.bass, name: 'Log Drum / Bass', emoji: '🎹'),
  StemChannel(type: StemType.melody, name: 'Melody / Synth', emoji: '🎸'),
];
