# Phase 23 · Technical Design Document — The Executable Master Media Object (MMO v2.0)

> **Phase:** 23  
> **Codename:** `master-media-object-v2`  
> **Target Apps:** `apps/vhunambi_api`, `apps/vhunambi_client`  
> **Standard:** Vhunambi Autonomous Engineering Standard  
> **Parent Blueprint:** [`docs/phases/phase_23_master_media_object/blueprint.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_23_master_media_object/blueprint.md)  

---

## 1. Backend Data Contracts & Schema Expansion (`apps/vhunambi_api`)

### 1.1 Extended Types (`src/modules/dna/dna_types.ts`):

```typescript
export type StemRole = 'vocals' | 'drums' | 'bass' | 'melodic';

export type TransientEventType =
  | 'kick'
  | 'log_drum_drop'
  | 'snare_clap'
  | 'vocal_onset'
  | 'harmonic_turnaround'
  | 'section_change';

export interface LyricWordTimestampV2 extends LyricWordTimestamp {
  phoneticStress?: number;   // 0.0 to 1.0 (defaults to 0.5)
  isCulturalIdiom?: boolean; // highlights Bantu ad-libs in brandPrimary
}

export interface TransientEvent {
  timestampMs: number;
  type: TransientEventType;
  stem: StemRole;
  intensity: number;         // 0.0 to 1.0
  durationMs?: number;       // default decay window 180ms
}

export interface MpcPadSliceManifest {
  padIndex: number;          // 0 to 7 mapping to mpc_pad_0..7
  label: string;             // e.g. "Kick Downbeat", "Log Drum Drop"
  sourceStem: StemRole;
  startSec: number;
  endSec: number;
  peakIntensity: number;     // 0.0 to 1.0
  recommendedSemitoneShift: number; // default 0 (-12..+12)
}

export interface SongSectionBlueprint {
  name: 'Intro' | 'Vocal Chant' | 'Log Drum Build' | 'The Drop' | 'Bridge' | 'Outro';
  startMs: number;
  endMs: number;
  barsCount: number;
  dominantStem: StemRole;
  visualPresetOverride?: 'subtle_drift' | 'logdrum_punch' | 'hyperkinetic';
}

export interface MasterMediaObjectManifest extends SongMetadataDNA {
  schemaVersion: '2.0';
  provenance: 'measured' | 'synthesized';
  alignment: LyricWordTimestampV2[];

  assets: {
    masterMp3Url: string;
    masterWavUrl?: string;
    coverArt9x16Url: string;
    coverArt1x1Url?: string;
    stemsZipUrl?: string;
    stemUrls: Record<StemRole, string>;
  };

  modulationBus: {
    sampleRateHz: 60;
    durationMs: number;
    frameCount: number;
    encodedCurvesBase64: {
      masterRms: string;     // 60Hz Uint8 curve Base64
      vocals: string;
      drums: string;
      bass: string;          // Dedicated Amapiano log-drum / sub-bass
      melodic: string;
    };
    transientEvents: TransientEvent[];
  };

  mpcKitPads: MpcPadSliceManifest[];
  structure: {
    sections: SongSectionBlueprint[];
  };
}
```

### 1.2 Deterministic Mathematical Manifest Synthesizer (`src/modules/dna/dna_compiler.ts`):

When real audio PCM is not yet separated by the GPU worker, `compileMasterMediaObjectManifest()` deterministically constructs:
1. **BPM-Locked 60 Hz Curves via 16-Step Genre Beat-Grids**: Generates 60 samples per second modeled on authentic African musical templates:
   - **Amapiano (110–115 BPM)**: Downbeat kick transients on 16th steps 0, 4, 8, 12; syncopated log-drum hits (`log_drum_drop`) on steps 3, 6, 11, 14 during 'The Drop' sections.
   - **Gqom (125–130 BPM)**: Broken-beat heavy kicks and tom transients on steps 0, 3, 6, 10, 12.
   - **Maskandi / Afro House**: Melodic stem energy pulsing on 8th and 16th guitar turnaround subdivisions.
2. **Quantized Uint8 Base64 Encoding**: Normalizes amplitudes to `0..255`, creates a `Buffer.from(uint8Array).toString('base64')` string (~10.8 KB per 180s curve).
3. **Role-Stratified 8-Pad MPC Kit**: Calculates exact slice boundaries for pads 0–7 across drums, bass, melodic, and vocal stems snapped to musical beat subdivisions.

---

## 2. Client Domain Models & Telemetry Bus (`apps/vhunambi_client`)

### 2.1 Domain Class & Wire Format Mappers (`lib/features/content_studio/domain/models/master_media_object.dart`):

```dart
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'song_metadata_dna.dart';
import 'lyric_word_timestamp.dart';
import '../../../player/domain/models/stem_mixer_state.dart';

enum ManifestProvenance { measured, synthesized }

enum TransientEventType {
  kick,
  logDrumDrop,
  snareClap,
  vocalOnset,
  harmonicTurnaround,
  sectionChange,
}

/// Bidirectional wire-format mappers between TypeScript backend and Dart client
StemType stemTypeFromWireString(String wire) {
  switch (wire.toLowerCase().trim()) {
    case 'vocals':
      return StemType.vocals;
    case 'drums':
      return StemType.drums;
    case 'bass':
      return StemType.bass;
    case 'melodic':
    case 'melody':
      return StemType.melody;
    default:
      return StemType.melody;
  }
}

String stemTypeToWireString(StemType stem) {
  switch (stem) {
    case StemType.vocals:
      return 'vocals';
    case StemType.drums:
      return 'drums';
    case StemType.bass:
      return 'bass';
    case StemType.melody:
      return 'melodic'; // TypeScript wire schema uses 'melodic'
  }
}

TransientEventType transientTypeFromWireString(String wire) {
  switch (wire) {
    case 'kick':
      return TransientEventType.kick;
    case 'log_drum_drop':
      return TransientEventType.logDrumDrop;
    case 'snare_clap':
      return TransientEventType.snareClap;
    case 'vocal_onset':
      return TransientEventType.vocalOnset;
    case 'harmonic_turnaround':
      return TransientEventType.harmonicTurnaround;
    case 'section_change':
      return TransientEventType.sectionChange;
    default:
      return TransientEventType.kick;
  }
}

String transientTypeToWireString(TransientEventType type) {
  switch (type) {
    case TransientEventType.kick:
      return 'kick';
    case TransientEventType.logDrumDrop:
      return 'log_drum_drop';
    case TransientEventType.snareClap:
      return 'snare_clap';
    case TransientEventType.vocalOnset:
      return 'vocal_onset';
    case TransientEventType.harmonicTurnaround:
      return 'harmonic_turnaround';
    case TransientEventType.sectionChange:
      return 'section_change';
  }
}

@immutable
class TransientEventEntity {
  final int timestampMs;
  final TransientEventType type;
  final StemType stem;
  final double intensity;
  final int durationMs;

  const TransientEventEntity({
    required this.timestampMs,
    required this.type,
    required this.stem,
    required this.intensity,
    this.durationMs = 180,
  });
}

@immutable
class MpcPadSliceManifest {
  final int padIndex;
  final String label;
  final StemType sourceStem;
  final double startSec;
  final double endSec;
  final double peakIntensity;
  final int recommendedSemitoneShift;

  const MpcPadSliceManifest({
    required this.padIndex,
    required this.label,
    required this.sourceStem,
    required this.startSec,
    required this.endSec,
    required this.peakIntensity,
    this.recommendedSemitoneShift = 0,
  });
}

@immutable
class ModulationTelemetryBus {
  final int sampleRateHz;
  final int durationMs;
  final int frameCount;
  final Uint8List masterRmsBytes;
  final Uint8List vocalsBytes;
  final Uint8List drumsBytes;
  final Uint8List bassBytes;
  final Uint8List melodicBytes;
  final List<TransientEventEntity> transientEvents;

  const ModulationTelemetryBus({
    this.sampleRateHz = 60,
    required this.durationMs,
    required this.frameCount,
    required this.masterRmsBytes,
    required this.vocalsBytes,
    required this.drumsBytes,
    required this.bassBytes,
    required this.melodicBytes,
    required this.transientEvents,
  });

  /// O(1) zero-allocation lookup of normalized amplitude (0.0 to 1.0)
  double sampleStemCurve(
    Uint8List curveBytes,
    int positionMs, {
    double gain = 1.0,
    bool isMuted = false,
  }) {
    if (isMuted || curveBytes.isEmpty || durationMs <= 0) return 0.0;
    final int idx = ((positionMs * sampleRateHz) ~/ 1000).clamp(0, curveBytes.length - 1);
    return ((curveBytes[idx] / 255.0) * gain).clamp(0.0, 1.0);
  }

  /// Binary-search transient impulse calculation with exponential decay
  double computeTransientImpulse(
    TransientEventType type,
    int positionMs, {
    double gain = 1.0,
    bool isMuted = false,
  }) {
    if (isMuted || gain <= 0.0 || transientEvents.isEmpty) return 0.0;

    double maxImpulse = 0.0;
    for (var i = 0; i < transientEvents.length; i++) {
      final ev = transientEvents[i];
      if (ev.type != type) continue;
      final delta = positionMs - ev.timestampMs;
      if (delta >= 0 && delta <= ev.durationMs) {
        final progress = delta / ev.durationMs;
        final decay = math.exp(-4.5 * progress);
        final candidate = ev.intensity * decay * gain;
        if (candidate > maxImpulse) maxImpulse = candidate;
      }
    }
    return maxImpulse.clamp(0.0, 1.0);
  }
}

@immutable
class MasterMediaObject {
  final SongMetadataDna dna;
  final String schemaVersion;
  final ManifestProvenance provenance;
  final Map<StemType, String> stemUrls;
  final ModulationTelemetryBus modulationBus;
  final List<MpcPadSliceManifest> mpcKitPads;

  const MasterMediaObject({
    required this.dna,
    this.schemaVersion = '2.0',
    this.provenance = ManifestProvenance.synthesized,
    required this.stemUrls,
    required this.modulationBus,
    required this.mpcKitPads,
  });

  /// Deterministic client synthesis from SongMetadataDna when offline
  factory MasterMediaObject.fromSongMetadataDna(SongMetadataDna dna) {
    // Implements authentic 16-step beat-grid generation for Amapiano, Gqom, Maskandi
    ...
  }
}
```

---

## 3. Riverpod State Architecture & Provider Coupling

### 3.1 Provider Declarations (`master_media_object_provider.dart`):

```dart
@immutable
class FrameModulationSnapshot {
  final double effectiveBassEnergy;
  final double effectiveDrumsEnergy;
  final double effectiveMelodicEnergy;
  final double effectiveVocalGlow;
  final double logDrumSnapZoom;

  const FrameModulationSnapshot({
    this.effectiveBassEnergy = 0.0,
    this.effectiveDrumsEnergy = 0.0,
    this.effectiveMelodicEnergy = 0.0,
    this.effectiveVocalGlow = 0.0,
    this.logDrumSnapZoom = 0.0,
  });
}

/// Family provider caching and delivering the active MasterMediaObject
final masterMediaObjectProvider = StateNotifierProvider.family<
    MasterMediaObjectNotifier, MasterMediaObject, SongMetadataDna>((ref, dna) {
  return MasterMediaObjectNotifier(dna);
});

/// Dart 3 Record typedef for zero-dependency family key
typedef FrameModulationQuery = ({SongMetadataDna dna, int positionMs});

/// Combined real-time frame snapshot provider reading both MMO and StemMixerState
final frameModulationSnapshotProvider = Provider.autoDispose
    .family<FrameModulationSnapshot, FrameModulationQuery>((ref, query) {
  final mmo = ref.watch(masterMediaObjectProvider(query.dna));
  final mixerState = ref.watch(stemMixerProvider);
  final posMs = query.positionMs;

  final anySolo = mixerState.anySoloActive;
  final voxGain = mixerState.channelFor(StemType.vocals).effectiveVolume(anySolo);
  final drumsGain = mixerState.channelFor(StemType.drums).effectiveVolume(anySolo);
  final bassGain = mixerState.channelFor(StemType.bass).effectiveVolume(anySolo);
  final melGain = mixerState.channelFor(StemType.melody).effectiveVolume(anySolo);

  return FrameModulationSnapshot(
    effectiveBassEnergy: mmo.modulationBus.sampleStemCurve(
      mmo.modulationBus.bassBytes,
      posMs,
      gain: bassGain,
      isMuted: bassGain <= 0.0,
    ),
    effectiveDrumsEnergy: mmo.modulationBus.sampleStemCurve(
      mmo.modulationBus.drumsBytes,
      posMs,
      gain: drumsGain,
      isMuted: drumsGain <= 0.0,
    ),
    effectiveMelodicEnergy: mmo.modulationBus.sampleStemCurve(
      mmo.modulationBus.melodicBytes,
      posMs,
      gain: melGain,
      isMuted: melGain <= 0.0,
    ),
    effectiveVocalGlow: mmo.modulationBus.sampleStemCurve(
      mmo.modulationBus.vocalsBytes,
      posMs,
      gain: voxGain,
      isMuted: voxGain <= 0.0,
    ),
    logDrumSnapZoom: mmo.modulationBus.computeTransientImpulse(
      TransientEventType.logDrumDrop,
      posMs,
      gain: bassGain,
      isMuted: bassGain <= 0.0,
    ),
  );
});
```

---

## 4. UI Integrations

### 4.1 `KineticPreviewCanvas` Modulation Injection:
- Transform scale incorporates `1.0 + (0.12 * snapshot.logDrumSnapZoom)` for punchy camera response.
- Active lyric word typography bloom radius scales with `snapshot.effectiveVocalGlow * (word.phoneticStress ?? 0.5)`.
- If `word.isCulturalIdiom == true`, glow tint uses `AppColors.brandPrimary` with `BoxShadow(color: AppColors.brandPrimary.withAlpha(180))`.

### 4.2 `MpcSlicerDeck` Pad Snapping:
- `MpcSlicerNotifier.loadFromManifestPads(List<MpcPadSliceManifest> pads)` updates `state.pads` with the 8 role-stratified slices, preserving pad label and start/end boundaries without requiring manual slicing.
