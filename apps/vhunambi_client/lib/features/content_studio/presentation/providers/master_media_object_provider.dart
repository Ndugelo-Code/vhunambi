import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/models/song_metadata_dna.dart';
import '../../domain/models/master_media_object.dart';
import '../../../player/domain/models/stem_mixer_state.dart';
import '../../../player/presentation/providers/stem_mixer_provider.dart';
import '../../../mastering/presentation/providers/mastering_session_provider.dart';

/// Instantaneous modulation snapshot applied to 60 FPS visual rendering (REQ-MMO-11, REQ-MMO-12).
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FrameModulationSnapshot &&
          runtimeType == other.runtimeType &&
          effectiveBassEnergy == other.effectiveBassEnergy &&
          effectiveDrumsEnergy == other.effectiveDrumsEnergy &&
          effectiveMelodicEnergy == other.effectiveMelodicEnergy &&
          effectiveVocalGlow == other.effectiveVocalGlow &&
          logDrumSnapZoom == other.logDrumSnapZoom;

  @override
  int get hashCode => Object.hash(
    effectiveBassEnergy,
    effectiveDrumsEnergy,
    effectiveMelodicEnergy,
    effectiveVocalGlow,
    logDrumSnapZoom,
  );
}

/// In-memory cache fallback for headless / unit test environments
final Map<String, MasterMediaObject> _inMemoryMmoCache = {};

/// State notifier managing active MasterMediaObject hydration and caching
class MasterMediaObjectNotifier extends StateNotifier<MasterMediaObject> {
  final SongMetadataDna dna;

  MasterMediaObjectNotifier(this.dna)
    : super(MasterMediaObject.fromSongMetadataDna(dna)) {
    _hydrateFromCache();
  }

  Future<void> _hydrateFromCache() async {
    // 1. Check in-memory store first
    if (_inMemoryMmoCache.containsKey(dna.id)) {
      state = _inMemoryMmoCache[dna.id]!;
      return;
    }

    // 2. Check Hive box with graceful test fallback
    try {
      if (!kIsWeb && Hive.isBoxOpen(AppConstants.mmoBoxKey)) {
        final box = Hive.box(AppConstants.mmoBoxKey);
        final raw = box.get(dna.id);
        if (raw is String) {
          final jsonMap = jsonDecode(raw) as Map<String, dynamic>;
          final cached = MasterMediaObject.fromJson(jsonMap);
          _inMemoryMmoCache[dna.id] = cached;
          state = cached;
        }
      }
    } catch (e) {
      debugPrint('[MMO Provider] Hive cache access degraded to in-memory: $e');
    }
  }

  /// Updates manifest with measured or freshly compiled object
  Future<void> updateManifest(MasterMediaObject mmo) async {
    state = mmo;
    _inMemoryMmoCache[dna.id] = mmo;

    try {
      if (!kIsWeb && Hive.isBoxOpen(AppConstants.mmoBoxKey)) {
        final box = Hive.box(AppConstants.mmoBoxKey);
        await box.put(dna.id, jsonEncode(mmo.toJson()));
      }
    } catch (e) {
      debugPrint('[MMO Provider] Failed to write to Hive box: $e');
    }
  }
}

/// Family provider caching and delivering the active MasterMediaObject
final masterMediaObjectProvider =
    StateNotifierProvider.family<
      MasterMediaObjectNotifier,
      MasterMediaObject,
      SongMetadataDna
    >((ref, dna) {
      return MasterMediaObjectNotifier(dna);
    });

/// Dart 3 Record typedef for zero-dependency 60 FPS animation family key
typedef FrameModulationQuery = ({SongMetadataDna dna, int positionMs});

/// Combined real-time frame snapshot provider reading MMO curves, StemMixerState, and MasteringSession
final frameModulationSnapshotProvider = Provider.autoDispose
    .family<FrameModulationSnapshot, FrameModulationQuery>((ref, query) {
      final mmo = ref.watch(masterMediaObjectProvider(query.dna));
      final mixerState = ref.watch(stemMixerProvider);
      final masteringSession = ref.watch(masteringSessionProvider);
      final posMs = query.positionMs;

      final anySolo = mixerState.anySoloActive;
      final voxGain = mixerState
          .channelFor(StemType.vocals)
          .effectiveVolume(anySolo);
      final drumsGain = mixerState
          .channelFor(StemType.drums)
          .effectiveVolume(anySolo);
      final bassGain = mixerState
          .channelFor(StemType.bass)
          .effectiveVolume(anySolo);
      final melGain = mixerState
          .channelFor(StemType.melody)
          .effectiveVolume(anySolo);

      // When mastering session preview is active, apply recipe modulation multipliers
      final bool masterActive = masteringSession.isMasteredPreviewActive;
      final double vocalMultiplier = masterActive
          ? masteringSession.recipe.vocalGainMultiplier
          : 1.0;
      final double bassMultiplier = masterActive
          ? masteringSession.recipe.bassGainMultiplier
          : 1.0;
      final double drumsMultiplier = masterActive
          ? masteringSession.recipe.drumsGainMultiplier
          : 1.0;
      final double melMultiplier = masterActive
          ? masteringSession.recipe.melodicGainMultiplier
          : 1.0;

      final rawBass = mmo.modulationBus.sampleStemCurve(
        mmo.modulationBus.bassBytes,
        posMs,
        gain: bassGain,
        isMuted: bassGain <= 0.0,
      );
      final rawDrums = mmo.modulationBus.sampleStemCurve(
        mmo.modulationBus.drumsBytes,
        posMs,
        gain: drumsGain,
        isMuted: drumsGain <= 0.0,
      );
      final rawMelodic = mmo.modulationBus.sampleStemCurve(
        mmo.modulationBus.melodicBytes,
        posMs,
        gain: melGain,
        isMuted: melGain <= 0.0,
      );
      final rawVocal = mmo.modulationBus.sampleStemCurve(
        mmo.modulationBus.vocalsBytes,
        posMs,
        gain: voxGain,
        isMuted: voxGain <= 0.0,
      );
      final rawLogDrum = mmo.modulationBus.computeTransientImpulse(
        TransientEventType.logDrumDrop,
        posMs,
        gain: bassGain,
        isMuted: bassGain <= 0.0,
      );

      return FrameModulationSnapshot(
        effectiveBassEnergy: (rawBass * bassMultiplier).clamp(0.0, 1.0),
        effectiveDrumsEnergy: (rawDrums * drumsMultiplier).clamp(0.0, 1.0),
        effectiveMelodicEnergy: (rawMelodic * melMultiplier).clamp(0.0, 1.0),
        effectiveVocalGlow: (rawVocal * vocalMultiplier).clamp(0.0, 1.0),
        logDrumSnapZoom: (rawLogDrum * bassMultiplier).clamp(0.0, 1.0),
      );
    });
