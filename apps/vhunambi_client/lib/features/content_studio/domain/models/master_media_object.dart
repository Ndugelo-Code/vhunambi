import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'song_metadata_dna.dart';
import 'lyric_word_timestamp.dart';
import '../../../player/domain/models/stem_mixer_state.dart';

/// Provenance of the Master Media Object Manifest.
enum ManifestProvenance {
  measured,
  synthesized,
}

/// Types of discrete acoustic transient events detected or synthesized.
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

/// Clamps slice start and end bounds within total track duration
({double startSec, double endSec}) clampSliceBounds(
  double rawStartSec,
  double durationSec,
  double trackTotalSec,
) {
  final safeTotal = math.max(4.0, trackTotalSec);
  final wrappedStart = (rawStartSec + durationSec <= safeTotal)
      ? rawStartSec
      : rawStartSec % math.max(1.0, safeTotal - durationSec);
  final startSec = double.parse(math.max(0.0, wrappedStart).toStringAsFixed(3));
  final endSec =
      double.parse(math.min(safeTotal, startSec + durationSec).toStringAsFixed(3));
  return (startSec: startSec, endSec: endSec);
}

@immutable
class TransientEventEntity {
  final int timestampMs;
  final TransientEventType type;
  final StemType stem;
  final double intensity; // 0.0 to 1.0
  final int durationMs;

  const TransientEventEntity({
    required this.timestampMs,
    required this.type,
    required this.stem,
    required this.intensity,
    this.durationMs = 180,
  });

  Map<String, dynamic> toJson() => {
        'timestampMs': timestampMs,
        'type': transientTypeToWireString(type),
        'stem': stemTypeToWireString(stem),
        'intensity': intensity,
        'durationMs': durationMs,
      };

  factory TransientEventEntity.fromJson(Map<String, dynamic> json) =>
      TransientEventEntity(
        timestampMs: (json['timestampMs'] as num).toInt(),
        type: transientTypeFromWireString(json['type'] as String? ?? 'kick'),
        stem: stemTypeFromWireString(json['stem'] as String? ?? 'drums'),
        intensity: (json['intensity'] as num?)?.toDouble() ?? 1.0,
        durationMs: (json['durationMs'] as num?)?.toInt() ?? 180,
      );
}

@immutable
class MpcPadSliceManifest {
  final int padIndex; // 0 to 7
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

  Map<String, dynamic> toJson() => {
        'padIndex': padIndex,
        'label': label,
        'sourceStem': stemTypeToWireString(sourceStem),
        'startSec': startSec,
        'endSec': endSec,
        'peakIntensity': peakIntensity,
        'recommendedSemitoneShift': recommendedSemitoneShift,
      };

  factory MpcPadSliceManifest.fromJson(Map<String, dynamic> json) =>
      MpcPadSliceManifest(
        padIndex: (json['padIndex'] as num).toInt(),
        label: json['label'] as String? ?? 'Slice',
        sourceStem: stemTypeFromWireString(json['sourceStem'] as String? ?? 'drums'),
        startSec: (json['startSec'] as num?)?.toDouble() ?? 0.0,
        endSec: (json['endSec'] as num?)?.toDouble() ?? 0.5,
        peakIntensity: (json['peakIntensity'] as num?)?.toDouble() ?? 1.0,
        recommendedSemitoneShift:
            (json['recommendedSemitoneShift'] as num?)?.toInt() ?? 0,
      );
}

@immutable
class SongSectionBlueprintEntity {
  final String name;
  final int startMs;
  final int endMs;
  final int barsCount;
  final StemType dominantStem;
  final String? visualPresetOverride;

  const SongSectionBlueprintEntity({
    required this.name,
    required this.startMs,
    required this.endMs,
    required this.barsCount,
    required this.dominantStem,
    this.visualPresetOverride,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'startMs': startMs,
        'endMs': endMs,
        'barsCount': barsCount,
        'dominantStem': stemTypeToWireString(dominantStem),
        if (visualPresetOverride != null)
          'visualPresetOverride': visualPresetOverride,
      };

  factory SongSectionBlueprintEntity.fromJson(Map<String, dynamic> json) =>
      SongSectionBlueprintEntity(
        name: json['name'] as String? ?? 'Section',
        startMs: (json['startMs'] as num).toInt(),
        endMs: (json['endMs'] as num).toInt(),
        barsCount: (json['barsCount'] as num?)?.toInt() ?? 4,
        dominantStem:
            stemTypeFromWireString(json['dominantStem'] as String? ?? 'drums'),
        visualPresetOverride: json['visualPresetOverride'] as String?,
      );
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
    if (isMuted || curveBytes.isEmpty || durationMs <= 0 || gain <= 0.0) return 0.0;
    final int idx =
        ((positionMs * sampleRateHz) ~/ 1000).clamp(0, curveBytes.length - 1);
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

  Map<String, dynamic> toJson() => {
        'sampleRateHz': sampleRateHz,
        'durationMs': durationMs,
        'frameCount': frameCount,
        'encodedCurvesBase64': {
          'masterRms': base64Encode(masterRmsBytes),
          'vocals': base64Encode(vocalsBytes),
          'drums': base64Encode(drumsBytes),
          'bass': base64Encode(bassBytes),
          'melodic': base64Encode(melodicBytes),
        },
        'transientEvents': transientEvents.map((e) => e.toJson()).toList(),
      };

  factory ModulationTelemetryBus.fromJson(Map<String, dynamic> json) {
    final sampleRateHz = (json['sampleRateHz'] as num?)?.toInt() ?? 60;
    final durationMs = (json['durationMs'] as num).toInt();
    final frameCount = (json['frameCount'] as num?)?.toInt() ??
        math.max(1, (durationMs * sampleRateHz) ~/ 1000);

    final curvesMap =
        json['encodedCurvesBase64'] as Map<String, dynamic>? ?? {};

    Uint8List decodeCurve(String? b64) {
      if (b64 == null || b64.isEmpty) return Uint8List(frameCount);
      try {
        return base64Decode(b64);
      } catch (_) {
        return Uint8List(frameCount);
      }
    }

    final rawEvents = json['transientEvents'] as List<dynamic>? ?? [];
    final transientEvents = rawEvents
        .map((e) => TransientEventEntity.fromJson(e as Map<String, dynamic>))
        .toList();

    return ModulationTelemetryBus(
      sampleRateHz: sampleRateHz,
      durationMs: durationMs,
      frameCount: frameCount,
      masterRmsBytes: decodeCurve(curvesMap['masterRms'] as String?),
      vocalsBytes: decodeCurve(curvesMap['vocals'] as String?),
      drumsBytes: decodeCurve(curvesMap['drums'] as String?),
      bassBytes: decodeCurve(curvesMap['bass'] as String?),
      melodicBytes: decodeCurve(curvesMap['melodic'] as String?),
      transientEvents: transientEvents,
    );
  }
}

/// The Executable Master Media Object (MMO v2.0).
@immutable
class MasterMediaObject {
  final SongMetadataDna dna;
  final String schemaVersion;
  final ManifestProvenance provenance;
  final String masterMp3Url;
  final String? masterWavUrl;
  final String coverArt9x16Url;
  final String? coverArt1x1Url;
  final String? stemsZipUrl;
  final Map<StemType, String> stemUrls;
  final ModulationTelemetryBus modulationBus;
  final List<MpcPadSliceManifest> mpcKitPads;
  final List<SongSectionBlueprintEntity> sections;

  const MasterMediaObject({
    required this.dna,
    this.schemaVersion = '2.0',
    this.provenance = ManifestProvenance.synthesized,
    required this.masterMp3Url,
    this.masterWavUrl,
    required this.coverArt9x16Url,
    this.coverArt1x1Url,
    this.stemsZipUrl,
    required this.stemUrls,
    required this.modulationBus,
    required this.mpcKitPads,
    required this.sections,
  });

  Map<String, dynamic> toJson() {
    final stemUrlsMap = <String, String>{};
    stemUrls.forEach((key, value) {
      stemUrlsMap[stemTypeToWireString(key)] = value;
    });

    final dnaJson = dna.toJson();
    dnaJson.remove('version');

    return {
      ...dnaJson,
      'schemaVersion': schemaVersion,
      'provenance': provenance.name,
      'assets': {
        'masterMp3Url': masterMp3Url,
        if (masterWavUrl != null) 'masterWavUrl': masterWavUrl,
        'coverArt9x16Url': coverArt9x16Url,
        if (coverArt1x1Url != null) 'coverArt1x1Url': coverArt1x1Url,
        if (stemsZipUrl != null) 'stemsZipUrl': stemsZipUrl,
        'stemUrls': stemUrlsMap,
      },
      'modulationBus': modulationBus.toJson(),
      'mpcKitPads': mpcKitPads.map((p) => p.toJson()).toList(),
      'structure': {
        'sections': sections.map((s) => s.toJson()).toList(),
      },
    };
  }

  factory MasterMediaObject.fromJson(Map<String, dynamic> json) {
    final dna = SongMetadataDna.fromJson(json);
    final schemaVersion = json['schemaVersion'] as String? ?? '2.0';
    final provenanceStr = json['provenance'] as String? ?? 'synthesized';
    final provenance = provenanceStr == 'measured'
        ? ManifestProvenance.measured
        : ManifestProvenance.synthesized;

    final assets = json['assets'] as Map<String, dynamic>? ?? {};
    final masterMp3Url = assets['masterMp3Url'] as String? ?? '';
    final masterWavUrl = assets['masterWavUrl'] as String?;
    final coverArt9x16Url = assets['coverArt9x16Url'] as String? ?? '';
    final coverArt1x1Url = assets['coverArt1x1Url'] as String?;
    final stemsZipUrl = assets['stemsZipUrl'] as String?;

    final rawStemUrls = assets['stemUrls'] as Map<String, dynamic>? ?? {};
    final stemUrls = <StemType, String>{};
    rawStemUrls.forEach((k, v) {
      if (v is String) {
        stemUrls[stemTypeFromWireString(k)] = v;
      }
    });

    final modulationBus = ModulationTelemetryBus.fromJson(
        json['modulationBus'] as Map<String, dynamic>? ?? {});

    final rawPads = json['mpcKitPads'] as List<dynamic>? ?? [];
    final mpcKitPads = rawPads
        .map((p) => MpcPadSliceManifest.fromJson(p as Map<String, dynamic>))
        .toList();

    final structure = json['structure'] as Map<String, dynamic>? ?? {};
    final rawSections = structure['sections'] as List<dynamic>? ?? [];
    final sections = rawSections
        .map((s) => SongSectionBlueprintEntity.fromJson(s as Map<String, dynamic>))
        .toList();

    return MasterMediaObject(
      dna: dna,
      schemaVersion: schemaVersion,
      provenance: provenance,
      masterMp3Url: masterMp3Url,
      masterWavUrl: masterWavUrl,
      coverArt9x16Url: coverArt9x16Url,
      coverArt1x1Url: coverArt1x1Url,
      stemsZipUrl: stemsZipUrl,
      stemUrls: stemUrls,
      modulationBus: modulationBus,
      mpcKitPads: mpcKitPads,
      sections: sections,
    );
  }

  /// Synthesizes an authentic MasterMediaObject deterministically from SongMetadataDna
  /// using the 16-step African genre beat grid.
  factory MasterMediaObject.fromSongMetadataDna(
    SongMetadataDna dna, {
    String? masterMp3Url,
    String? coverArtUrl,
    Map<StemType, String>? stemUrls,
  }) {
    final bpm = dna.musical.bpm;
    final durationSec = dna.musical.durationSec;
    final durationMs = (durationSec * 1000).toInt();
    final genreLower = dna.genre.toLowerCase();

    final isAmapiano = genreLower.contains('amapiano');
    final isGqom = genreLower.contains('gqom');

    final beatSec = 60.0 / bpm;
    final barSec = 4.0 * beatSec;
    final stepSec = barSec / 16.0;

    // 1. Structure sections
    final totalBars = math.max(4, (durationSec / barSec).floor());
    final introBars = math.min(8, math.max(1, (totalBars * 0.15).floor()));
    final buildBars = math.min(8, math.max(1, (totalBars * 0.20).floor()));
    final dropBars = math.max(2, (totalBars * 0.40).floor());
    final bridgeBars = math.max(1, (totalBars * 0.13).floor());

    final sections = <SongSectionBlueprintEntity>[
      SongSectionBlueprintEntity(
        name: 'Intro',
        startMs: 0,
        endMs: (introBars * barSec * 1000).round(),
        barsCount: introBars,
        dominantStem: StemType.drums,
        visualPresetOverride: 'subtle_drift',
      ),
      SongSectionBlueprintEntity(
        name: 'Log Drum Build',
        startMs: (introBars * barSec * 1000).round(),
        endMs: ((introBars + buildBars) * barSec * 1000).round(),
        barsCount: buildBars,
        dominantStem: StemType.melody,
        visualPresetOverride: 'logdrum_punch',
      ),
      SongSectionBlueprintEntity(
        name: 'The Drop',
        startMs: ((introBars + buildBars) * barSec * 1000).round(),
        endMs: ((introBars + buildBars + dropBars) * barSec * 1000).round(),
        barsCount: dropBars,
        dominantStem: StemType.bass,
        visualPresetOverride: 'hyperkinetic',
      ),
      SongSectionBlueprintEntity(
        name: 'Bridge',
        startMs: ((introBars + buildBars + dropBars) * barSec * 1000).round(),
        endMs: ((introBars + buildBars + dropBars + bridgeBars) * barSec * 1000).round(),
        barsCount: bridgeBars,
        dominantStem: StemType.vocals,
        visualPresetOverride: 'subtle_drift',
      ),
      SongSectionBlueprintEntity(
        name: 'Outro',
        startMs: ((introBars + buildBars + dropBars + bridgeBars) * barSec * 1000).round(),
        endMs: durationMs,
        barsCount: math.max(1, totalBars - (introBars + buildBars + dropBars + bridgeBars)),
        dominantStem: StemType.drums,
        visualPresetOverride: 'subtle_drift',
      ),
    ];

    // 2. 60 Hz Modulation Curves with 1-frame attack + exponential release
    const sampleRateHz = 60;
    final frameCount = math.max(1, (durationMs * sampleRateHz) ~/ 1000);
    final masterRmsBytes = Uint8List(frameCount);
    final vocalsBytes = Uint8List(frameCount);
    final drumsBytes = Uint8List(frameCount);
    final bassBytes = Uint8List(frameCount);
    final melodicBytes = Uint8List(frameCount);

    double computeHitEnergy(int fRel, double k, double aPeak) {
      if (fRel < 0) return 0.0;
      if (fRel == 0) return 0.65 * aPeak;
      return aPeak * math.exp(-k * (fRel - 1));
    }

    final alignment = dna.alignment;

    for (var f = 0; f < frameCount; f++) {
      final t = f / sampleRateHz;
      final tMs = (t * 1000).round();

      String activeSection = sections[0].name;
      for (var s = 0; s < sections.length; s++) {
        if (tMs >= sections[s].startMs && tMs < sections[s].endMs) {
          activeSection = sections[s].name;
          break;
        }
      }
      final isTheDrop = activeSection == 'The Drop';
      final isBuild = activeSection == 'Log Drum Build';
      final isIntro = activeSection == 'Intro';
      final isBridge = activeSection == 'Bridge';

      final beatTime = t % barSec;
      final stepIndex = (beatTime / stepSec).floor() % 16;
      final stepOnset = stepIndex * stepSec;
      final timeSinceStep = beatTime - stepOnset;
      final fRel = (timeSinceStep * sampleRateHz).floor();

      // --- DRUMS ---
      double drumsPeak = 0.0;
      if (isAmapiano) {
        if (stepIndex == 0 || stepIndex == 4 || stepIndex == 8 || stepIndex == 12) {
          drumsPeak = 1.0;
        } else if (stepIndex == 4 || stepIndex == 12) {
          drumsPeak = 0.9;
        } else if (isTheDrop &&
            (stepIndex == 2 || stepIndex == 6 || stepIndex == 10 || stepIndex == 14)) {
          drumsPeak = 0.45;
        }
      } else if (isGqom) {
        if (stepIndex == 0 || stepIndex == 3 || stepIndex == 6 || stepIndex == 10 || stepIndex == 12) {
          drumsPeak = 1.0;
        }
      } else {
        if (stepIndex % 4 == 0) drumsPeak = 0.95;
      }

      final eHitDrums = drumsPeak > 0 ? computeHitEnergy(fRel, 0.48, drumsPeak) : 0.0;
      final bDrums = isTheDrop ? 0.08 : 0.02;
      drumsBytes[f] = (255 * (bDrums + (1 - bDrums) * eHitDrums)).round().clamp(0, 255);

      // --- BASS (LOG DRUM) ---
      double bassPeak = 0.0;
      if (isAmapiano) {
        if (isTheDrop || isBuild) {
          if (stepIndex == 3 || stepIndex == 6 || stepIndex == 11 || stepIndex == 14) {
            bassPeak = 1.0;
          } else if (stepIndex == 0) {
            bassPeak = 0.85;
          }
        }
      } else if (isGqom) {
        if (stepIndex == 0 || stepIndex == 3 || stepIndex == 6 || stepIndex == 10) {
          bassPeak = 0.95;
        }
      } else {
        if (stepIndex == 0 || stepIndex == 8) bassPeak = 0.8;
      }

      final eHitBass = bassPeak > 0 ? computeHitEnergy(fRel, 0.22, bassPeak) : 0.0;
      final bBass = isTheDrop ? 0.18 : isBuild ? 0.10 : 0.0;
      bassBytes[f] = (255 * (bBass + (1 - bBass) * eHitBass)).round().clamp(0, 255);

      // --- MELODIC ---
      double melPeak = 0.0;
      if (stepIndex == 2 || stepIndex == 6 || stepIndex == 8 || stepIndex == 14) {
        melPeak = 0.85;
      }
      final eHitMel = melPeak > 0 ? computeHitEnergy(fRel, 0.16, melPeak) : 0.0;
      final bMel = isTheDrop ? 0.22 : isIntro || isBridge ? 0.12 : 0.16;
      melodicBytes[f] = (255 * (bMel + (1 - bMel) * eHitMel)).round().clamp(0, 255);

      // --- VOCALS ---
      double vocalEnergy = 0.0;
      for (var w = 0; w < alignment.length; w++) {
        final word = alignment[w];
        if (t >= word.start && t <= word.end) {
          final pWord = (t - word.start) / math.max(0.05, word.end - word.start);
          final stress = word.phoneticStress;
          vocalEnergy =
              math.pow(math.sin(math.pi * pWord.clamp(0.0, 1.0)), 0.7) *
              (0.55 + 0.45 * stress);
          break;
        }
      }
      vocalsBytes[f] = (255 * vocalEnergy).round().clamp(0, 255);

      // --- MASTER RMS ---
      masterRmsBytes[f] = (0.35 * bassBytes[f] +
              0.25 * drumsBytes[f] +
              0.20 * vocalsBytes[f] +
              0.20 * melodicBytes[f])
          .round()
          .clamp(0, 255);
    }

    // 3. Transient events
    final transientEvents = <TransientEventEntity>[];

    for (var s = 0; s < sections.length; s++) {
      transientEvents.add(TransientEventEntity(
        timestampMs: sections[s].startMs,
        type: TransientEventType.sectionChange,
        stem: sections[s].dominantStem,
        intensity: 0.9,
        durationMs: 240,
      ));
    }

    for (var bar = 0; bar < totalBars; bar++) {
      final barTimeMs = (bar * barSec * 1000).round();
      if (barTimeMs >= durationMs) break;

      final isDropBar = bar >= introBars + buildBars && bar < introBars + buildBars + dropBars;

      transientEvents.add(TransientEventEntity(
        timestampMs: barTimeMs,
        type: TransientEventType.kick,
        stem: StemType.drums,
        intensity: 0.88,
        durationMs: 160,
      ));

      final snareTimeMs = ((bar * barSec + 4 * stepSec) * 1000).round();
      if (snareTimeMs < durationMs) {
        transientEvents.add(TransientEventEntity(
          timestampMs: snareTimeMs,
          type: TransientEventType.snareClap,
          stem: StemType.drums,
          intensity: 0.75,
          durationMs: 160,
        ));
      }

      if (isDropBar && isAmapiano) {
        final dropSteps = [3, 6, 11, 14];
        for (var ds = 0; ds < dropSteps.length; ds++) {
          final logTimeMs = ((bar * barSec + dropSteps[ds] * stepSec) * 1000).round();
          if (logTimeMs < durationMs) {
            transientEvents.add(TransientEventEntity(
              timestampMs: logTimeMs,
              type: TransientEventType.logDrumDrop,
              stem: StemType.bass,
              intensity: 0.95,
              durationMs: 220,
            ));
          }
        }
      }

      if (bar % 4 == 3) {
        final turnTimeMs = ((bar * barSec + 12 * stepSec) * 1000).round();
        if (turnTimeMs < durationMs) {
          transientEvents.add(TransientEventEntity(
            timestampMs: turnTimeMs,
            type: TransientEventType.harmonicTurnaround,
            stem: StemType.melody,
            intensity: 0.72,
            durationMs: 200,
          ));
        }
      }
    }

    for (var w = 0; w < alignment.length; w++) {
      transientEvents.add(TransientEventEntity(
        timestampMs: (alignment[w].start * 1000).round(),
        type: TransientEventType.vocalOnset,
        stem: StemType.vocals,
        intensity: 0.8,
        durationMs: 200,
      ));
    }

    transientEvents.sort((a, b) => a.timestampMs.compareTo(b.timestampMs));

    // 4. Role-Stratified 8-Pad MPC Kit
    LyricWordTimestamp? idiomWord;
    try {
      idiomWord = alignment.firstWhere((w) => w.isCulturalIdiom);
    } catch (_) {
      idiomWord = null;
    }
    final firstWord = alignment.isNotEmpty ? alignment.first : null;

    final p0 = clampSliceBounds(0.0 * barSec, 1 * beatSec, durationSec.toDouble());
    final p1 = clampSliceBounds(1.0 * barSec + 1.0 * beatSec, 2 * beatSec, durationSec.toDouble());
    final p2 = clampSliceBounds(15.0 * barSec, 2 * beatSec, durationSec.toDouble());
    final p3 = clampSliceBounds(15.0 * barSec + 2.0 * beatSec, 4 * beatSec, durationSec.toDouble());
    final p4 = clampSliceBounds(8.0 * barSec, 4 * beatSec, durationSec.toDouble());
    final p5 = clampSliceBounds(11.0 * barSec, 2 * beatSec, durationSec.toDouble());
    final p6 = clampSliceBounds(
        firstWord != null ? firstWord.start : 16.0 * barSec, 4 * beatSec, durationSec.toDouble());
    final p7 = clampSliceBounds(
        idiomWord != null ? idiomWord.start : 17.0 * barSec + 2.0 * beatSec,
        2 * beatSec,
        durationSec.toDouble());

    final mpcKitPads = <MpcPadSliceManifest>[
      MpcPadSliceManifest(
        padIndex: 0,
        label: 'Kick Downbeat',
        sourceStem: StemType.drums,
        startSec: p0.startSec,
        endSec: p0.endSec,
        peakIntensity: 0.92,
        recommendedSemitoneShift: 0,
      ),
      MpcPadSliceManifest(
        padIndex: 1,
        label: 'Syncopated Clap',
        sourceStem: StemType.drums,
        startSec: p1.startSec,
        endSec: p1.endSec,
        peakIntensity: 0.82,
        recommendedSemitoneShift: 0,
      ),
      MpcPadSliceManifest(
        padIndex: 2,
        label: 'Log Drum Drop',
        sourceStem: StemType.bass,
        startSec: p2.startSec,
        endSec: p2.endSec,
        peakIntensity: 0.98,
        recommendedSemitoneShift: 0,
      ),
      MpcPadSliceManifest(
        padIndex: 3,
        label: 'Sub-Bass Glide',
        sourceStem: StemType.bass,
        startSec: p3.startSec,
        endSec: p3.endSec,
        peakIntensity: 0.88,
        recommendedSemitoneShift: -2,
      ),
      MpcPadSliceManifest(
        padIndex: 4,
        label: 'Guitar Turnaround',
        sourceStem: StemType.melody,
        startSec: p4.startSec,
        endSec: p4.endSec,
        peakIntensity: 0.78,
        recommendedSemitoneShift: 0,
      ),
      MpcPadSliceManifest(
        padIndex: 5,
        label: 'Harmonic Stab',
        sourceStem: StemType.melody,
        startSec: p5.startSec,
        endSec: p5.endSec,
        peakIntensity: 0.84,
        recommendedSemitoneShift: 0,
      ),
      MpcPadSliceManifest(
        padIndex: 6,
        label: 'Vocal Chant Hook',
        sourceStem: StemType.vocals,
        startSec: p6.startSec,
        endSec: p6.endSec,
        peakIntensity: 0.90,
        recommendedSemitoneShift: 0,
      ),
      MpcPadSliceManifest(
        padIndex: 7,
        label: 'Bantu Idiom Ad-Lib',
        sourceStem: StemType.vocals,
        startSec: p7.startSec,
        endSec: p7.endSec,
        peakIntensity: 0.95,
        recommendedSemitoneShift: 0,
      ),
    ];

    final trackId = dna.id;
    final defaultStemUrls = stemUrls ??
        {
          StemType.vocals: '/mock-storage/${trackId}_vocals.mp3',
          StemType.drums: '/mock-storage/${trackId}_drums.mp3',
          StemType.bass: '/mock-storage/${trackId}_bass.mp3',
          StemType.melody: '/mock-storage/${trackId}_melodic.mp3',
        };

    return MasterMediaObject(
      dna: dna,
      schemaVersion: '2.0',
      provenance: ManifestProvenance.synthesized,
      masterMp3Url: masterMp3Url ?? '/mock-storage/${trackId}_master.mp3',
      coverArt9x16Url:
          coverArtUrl ?? 'https://assets.vhunambi.com/covers/${trackId}_9x16.jpg',
      stemUrls: defaultStemUrls,
      modulationBus: ModulationTelemetryBus(
        sampleRateHz: sampleRateHz,
        durationMs: durationMs,
        frameCount: frameCount,
        masterRmsBytes: masterRmsBytes,
        vocalsBytes: vocalsBytes,
        drumsBytes: drumsBytes,
        bassBytes: bassBytes,
        melodicBytes: melodicBytes,
        transientEvents: transientEvents,
      ),
      mpcKitPads: mpcKitPads,
      sections: sections,
    );
  }
}
