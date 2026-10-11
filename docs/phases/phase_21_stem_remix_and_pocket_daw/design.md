# Phase 21 · Design — Audio-Stem Social Remixing & Pocket 4-Channel Stem Mixer

> **Phase:** 21  
> **Codename:** `stem-remix-and-pocket-daw`  
> **Status:** 🟡 SPECIFICATION  
> **Target Apps:** `apps/vhunambi_client`  
> **Architecture Standard:** Dual-Agent Pair Programming Standard ([`docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md))  

---

## 1. Domain Entities & Models

### 1.1 `StemMixerState` & `StemChannel`
```dart
// lib/features/player/domain/models/stem_mixer_state.dart

import 'package:flutter/foundation.dart';

enum StemType {
  vocals,
  drums,
  bass, // Log Drum
  melody, // Instruments
}

@immutable
class StemChannel {
  final StemType type;
  final String name;
  final String emoji;
  final double gain; // 0.0 to 1.5 (default 1.0)
  final double pan; // -1.0 to 1.0 (default 0.0)
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

  /// Computed effective volume considering solo and mute states.
  double effectiveVolume(bool anySoloActive) {
    if (anySoloActive) {
      return isSolo ? gain : 0.0;
    }
    return isMuted ? 0.0 : gain;
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
}

@immutable
class MasterBusDsp {
  final double logDrumSaturation; // 0.0 to 1.0
  final double vocalPlateReverb; // 0.0 to 1.0
  final double sidechainCompression; // 0.0 to 1.0
  final double stereoWidth; // 0.0 to 1.5

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
}

@immutable
class StemMixerState {
  final List<StemChannel> channels;
  final MasterBusDsp masterDsp;
  final bool isBouncing;
  final String? activeTrackId;
  final String? activeTrackTitle;

  const StemMixerState({
    required this.channels,
    this.masterDsp = const MasterBusDsp(),
    this.isBouncing = false,
    this.activeTrackId,
    this.activeTrackTitle,
  });

  bool get anySoloActive => channels.any((c) => c.isSolo);
}
```

### 1.2 `StemRemixContext`
```dart
// lib/features/social/domain/models/stem_remix_context.dart

import 'package:flutter/foundation.dart';
import '../../content_studio/domain/models/song_metadata_dna.dart';

@immutable
class StemRemixContext {
  final String parentClipId;
  final String parentCreatorUsername;
  final String parentTrackTitle;
  final String parentCoverArtUrl;
  final SongMetadataDna? originalDna;

  const StemRemixContext({
    required this.parentClipId,
    required this.parentCreatorUsername,
    required this.parentTrackTitle,
    required this.parentCoverArtUrl,
    this.originalDna,
  });

  String get attributionLineage =>
      '🔁 Remixed from @$parentCreatorUsername\'s "$parentTrackTitle"';
}
```

### 1.3 `PublishedClip` Lineage Extension
Extend `PublishedClip`:
- `final String? remixedFromClipId;`
- `final String? remixAttribution;`

---

## 2. Riverpod State Providers

### 2.1 `StemMixerNotifier` (`stemMixerProvider`)
```dart
// lib/features/player/presentation/providers/stem_mixer_provider.dart

class StemMixerNotifier extends StateNotifier<StemMixerState> {
  // setChannelGain, setChannelPan, toggleMute, toggleSolo,
  // updateMasterDsp, applyPreset, resetMix, bounceMasterMix
}
```

### 2.2 `StemRemixNotifier` (`stemRemixProvider`)
```dart
// lib/features/social/presentation/providers/stem_remix_provider.dart

class StemRemixNotifier extends StateNotifier<StemRemixContext?> {
  void initiateRemix(PublishedClip clip);
  void clearRemix();
}
```

---

## 3. Presentation Layer Widgets

1. **`StemMixerDeck`** (`lib/features/player/presentation/widgets/stem_mixer_deck.dart`):
   - 4-fader channel bank with dB labels, volume sliders, pan sliders, and M/S buttons.
   - Master Bus DSP rack (Log Drum Saturation, Plate Reverb, Sidechain Ducking, Stereo Width).
   - "Bounce Master" action button.
2. **`RemixAttributionBadge`** (`lib/features/social/presentation/widgets/remix_attribution_badge.dart`):
   - Stylized badge displaying `"🔁 Remixed from @creator's 'Title'"`.
   - Mounted in `KineticReelsModal` and `TrendingReelCard`.
3. **`KineticReelsModal` Remix Action Rail Wire-Up**:
   - Wire `Icons.alt_route_rounded` to launch the Remix flow / Stem Mixer.
