import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/stem_mixer_state.dart';

/// Manages interactive 4-channel stem mixing, muting, soloing, pan,
/// and master bus DSP processing (REQ-MIX-01 … REQ-MIX-05).
class StemMixerNotifier extends StateNotifier<StemMixerState> {
  StemMixerNotifier()
      : super(const StemMixerState(
          channels: kDefaultStemChannels,
          activeTrackId: 'trk_active_mix',
          activeTrackTitle: 'Amapiano Sunrise Master',
        ));

  /// Sets gain volume for a specific stem channel (0.0 to 1.5).
  void setChannelGain(StemType type, double gain) {
    state = state.copyWith(
      channels: state.channels.map((channel) {
        if (channel.type == type) {
          return channel.copyWith(gain: gain.clamp(0.0, 1.5));
        }
        return channel;
      }).toList(),
    );
  }

  /// Sets stereo panning for a specific stem channel (-1.0 to +1.0).
  void setChannelPan(StemType type, double pan) {
    state = state.copyWith(
      channels: state.channels.map((channel) {
        if (channel.type == type) {
          return channel.copyWith(pan: pan.clamp(-1.0, 1.0));
        }
        return channel;
      }).toList(),
    );
  }

  /// Toggles mute state for a specific stem channel.
  void toggleMute(StemType type) {
    state = state.copyWith(
      channels: state.channels.map((channel) {
        if (channel.type == type) {
          return channel.copyWith(isMuted: !channel.isMuted);
        }
        return channel;
      }).toList(),
    );
  }

  /// Toggles solo state for a specific stem channel.
  void toggleSolo(StemType type) {
    state = state.copyWith(
      channels: state.channels.map((channel) {
        if (channel.type == type) {
          return channel.copyWith(isSolo: !channel.isSolo);
        }
        return channel;
      }).toList(),
    );
  }

  /// Updates Bantu Master Bus DSP suite.
  void updateMasterDsp(MasterBusDsp dsp) {
    state = state.copyWith(masterDsp: dsp);
  }

  /// Applies a genre-specific sonic preset to the mixer.
  void applyPreset(String presetName) {
    switch (presetName) {
      case 'Amapiano Club Banger':
        state = state.copyWith(
          masterDsp: const MasterBusDsp(
            logDrumSaturation: 0.85,
            sidechainCompression: 0.75,
            stereoWidth: 1.25,
            vocalPlateReverb: 0.25,
          ),
          channels: state.channels.map((c) {
            if (c.type == StemType.bass) return c.copyWith(gain: 1.25);
            if (c.type == StemType.drums) return c.copyWith(gain: 1.1);
            return c.copyWith(gain: 1.0);
          }).toList(),
        );
        break;
      case 'Deep Maskandi Acoustic':
        state = state.copyWith(
          masterDsp: const MasterBusDsp(
            logDrumSaturation: 0.2,
            vocalPlateReverb: 0.6,
            sidechainCompression: 0.3,
            stereoWidth: 1.4,
          ),
          channels: state.channels.map((c) {
            if (c.type == StemType.melody) return c.copyWith(gain: 1.2);
            if (c.type == StemType.vocals) return c.copyWith(gain: 1.15);
            return c.copyWith(gain: 0.95);
          }).toList(),
        );
        break;
      case 'Clean Vocal Duet':
        state = state.copyWith(
          masterDsp: const MasterBusDsp(
            logDrumSaturation: 0.3,
            vocalPlateReverb: 0.5,
            sidechainCompression: 0.4,
            stereoWidth: 1.1,
          ),
          channels: state.channels.map((c) {
            if (c.type == StemType.vocals) return c.copyWith(gain: 1.3);
            return c.copyWith(gain: 0.9);
          }).toList(),
        );
        break;
    }
  }

  /// Resets all channels to unity gain (1.0), center pan (0.0), and unmuted/unsoloed.
  void resetMix() {
    state = state.copyWith(
      channels: kDefaultStemChannels,
      masterDsp: const MasterBusDsp(),
    );
  }

  /// Renders and bounces the current active stem balance into a master audio file (REQ-MIX-05).
  Future<String> bounceMasterMix() async {
    state = state.copyWith(isBouncing: true);

    // Simulate audio rendering / DSP bounce
    final bouncedPath =
        '/vault/bounces/master_mix_${DateTime.now().millisecondsSinceEpoch}.wav';

    state = state.copyWith(
      isBouncing: false,
      lastBouncedAudioPath: bouncedPath,
    );

    return bouncedPath;
  }
}

/// Global provider for the Pocket 4-Channel Stem Mixer.
final stemMixerProvider =
    StateNotifierProvider<StemMixerNotifier, StemMixerState>((ref) {
  return StemMixerNotifier();
});
