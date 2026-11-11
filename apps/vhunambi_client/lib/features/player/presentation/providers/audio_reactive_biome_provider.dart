import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/storage/sovereign_domain_repositories.dart';
import '../../../content_studio/domain/models/song_metadata_dna.dart';
import '../../../content_studio/presentation/providers/master_media_object_provider.dart';
import '../../../studio/domain/models/mycelium_biome_models.dart';
import '../../domain/models/stem_mixer_state.dart';
import 'player_provider.dart';
import 'stem_mixer_provider.dart';

/// Manages and persists the active 3-Way Hero Mode in ExpandedCockpitModal (REQ-P55-HERO-01).
class PlayerHeroModeNotifier extends Notifier<PlayerHeroMode> {
  @override
  PlayerHeroMode build() {
    var initialMode = PlayerHeroMode.artwork;
    if (SovereignDomainStorageMode.canHydrateFromStorage(
      AppConstants.playbackSessionBoxKey,
    )) {
      final savedMode = PlaybackSessionRepository.loadHeroMode();
      if (savedMode != null) {
        initialMode = PlayerHeroMode.values.firstWhere(
          (m) => m.name == savedMode,
          orElse: () => PlayerHeroMode.artwork,
        );
      }
    }
    listenSelf((_, next) {
      unawaited(PlaybackSessionRepository.saveHeroMode(next.name));
    });
    return initialMode;
  }

  void setHeroMode(PlayerHeroMode mode) {
    state = mode;
  }
}

/// Persists the active 3-Way Hero Mode in ExpandedCockpitModal (REQ-P55-HERO-01).
final playerHeroModeProvider =
    NotifierProvider<PlayerHeroModeNotifier, PlayerHeroMode>(
      PlayerHeroModeNotifier.new,
    );

/// Canonical mapping from each 3D MyceliumClusterDomain to its primary StemType (REQ-P55-STEM-01).
StemType primaryStemForCluster(MyceliumClusterDomain domain) {
  return switch (domain) {
    MyceliumClusterDomain.vocalNetwork => StemType.vocals,
    MyceliumClusterDomain.rhythmNetwork => StemType.drums,
    MyceliumClusterDomain.harmonyNetwork => StemType.bass,
    MyceliumClusterDomain.melodyCore => StemType.melody,
    MyceliumClusterDomain.emotionNetwork => StemType.vocals,
    MyceliumClusterDomain.productionNetwork => StemType.drums,
  };
}

/// Real-time 60 FPS bridge combining PlayerState, StemMixerState, and FrameModulationSnapshot
/// into an immutable AudioBiomeModulationState (REQ-P55-DSP-03).
final audioReactiveBiomeModulationProvider =
    Provider.autoDispose<AudioBiomeModulationState>((ref) {
      final playerState = ref.watch(playerStateProvider);
      final mixerState = ref.watch(stemMixerProvider);
      final track = playerState.currentTrack;

      if (track == null) {
        return AudioBiomeModulationState.idle;
      }

      final dna = SongMetadataDna.fromTrackInfo(
        id: track.id,
        title: track.title,
        genre: track.genre,
        language: track.language,
        durationSec: track.duration.inSeconds > 0
            ? track.duration.inSeconds
            : playerState.duration.inSeconds,
        coverUrl: track.coverUrl,
      );

      final posMs = playerState.position.inMilliseconds;
      final durMs = playerState.duration.inMilliseconds > 0
          ? playerState.duration.inMilliseconds
          : track.duration.inMilliseconds;

      final snapshot = ref.watch(
        frameModulationSnapshotProvider((dna: dna, positionMs: posMs)),
      );

      final anySolo = mixerState.anySoloActive;
      final gains = <MyceliumClusterDomain, double>{};
      final soloed = <MyceliumClusterDomain>{};
      final muted = <MyceliumClusterDomain>{};

      for (final domain in MyceliumClusterDomain.values) {
        final primaryStem = primaryStemForCluster(domain);
        final ch = mixerState.channelFor(primaryStem);
        gains[domain] = ch.effectiveVolume(anySolo);
        if (ch.isSolo && !ch.isMuted) {
          soloed.add(domain);
        }
        if (ch.isMuted || (anySolo && !ch.isSolo)) {
          muted.add(domain);
        }
      }

      return AudioBiomeModulationState(
        isPlaying: playerState.isPlaying,
        positionMs: posMs,
        durationMs: durMs > 0 ? durMs : 1,
        bassEnergy: snapshot.effectiveBassEnergy,
        drumsEnergy: snapshot.effectiveDrumsEnergy,
        melodicEnergy: snapshot.effectiveMelodicEnergy,
        vocalGlow: snapshot.effectiveVocalGlow,
        logDrumSnapZoom: snapshot.logDrumSnapZoom,
        clusterAudibleGains: gains,
        soloedDomains: soloed,
        mutedDomains: muted,
      );
    });
