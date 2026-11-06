# Phase 55 Technical Design Specification: Audio-Reactive Living Mycelium Player, Real-Time Stem Visualizer & 3D Playback Universe

- **Phase Identifier**: `phase_55_audio_reactive_biome_player`
- **Target Application**: `apps/vhunambi_client`
- **Architecture Blueprint**: [`docs/phases/phase_55_audio_reactive_biome_player/blueprint.md`](./blueprint.md)
- **Requirements Specification**: [`docs/phases/phase_55_audio_reactive_biome_player/requirements.md`](./requirements.md)
- **Parent Audit Reference**: [`docs/audits/PLAYER_STEMS_MIXER_AND_AUDIO_REACTIVE_3D_BIOME_AUDIT.md`](../../audits/PLAYER_STEMS_MIXER_AND_AUDIO_REACTIVE_3D_BIOME_AUDIT.md)

---

## 1. Architectural Overview & Coordinate Invariants

### 1.1 Right-Handed 3D Y-Up World Space Invariant
All 3D geometry in `OrganicMycelium3DPainter`, `PlayerLivingBiomeHeroViewport`, and `TrackLivingBiomePreviewCard` strictly adheres to **Right-Handed 3D Y-Up World Space**:
- **$X$-Axis**: Lateral horizontal position ($+X$ right, $-X$ left).
- **$Y$-Axis**: Vertical elevation ($+Y$ upward from terrain base $Y_{\text{root}, k} = h(X_k, Z_k) \ge 0$ to mushroom cap apex $Y_{\text{apex}, k} = Y_{\text{root}, k} + H_{\text{stipe}, k} + \Delta Y_{\text{acoustic}, k}$).
- **$Z$-Axis**: Foreground depth ($+Z$ toward camera, $-Z$ into background).
- **Screen Projection**: `BiomeProjectionEngine.project3D(worldPos, camera, size)` maps $+Y$ upward on screen via $Y_{\text{screen}} = H/2 - y_{\text{eye}} \cdot \text{scale}$.

---

## 2. Mathematical Foundations for 60 FPS Audio-Reactive 3D Biome Rendering

### 2.1 Continuous Domain Energy Mapping ($E_{D_k}(t)$)
Given the 60 FPS `FrameModulationSnapshot` at playback position $t = \text{positionMs}$ with normalized acoustic energies $E_{\text{bass}}, E_{\text{drums}}, E_{\text{melodic}}, E_{\text{vocal}}, S_{\text{snap}} \in [0.0, 1.0]$:

$$\begin{aligned}
E_{\text{melodyCore}}(t) &= \text{clamp}(E_{\text{melodic}}(t), 0.0, 1.0) \\
E_{\text{rhythmNetwork}}(t) &= \text{clamp}(0.60 \cdot E_{\text{bass}}(t) + 0.40 \cdot E_{\text{drums}}(t), 0.0, 1.0) \\
E_{\text{vocalNetwork}}(t) &= \text{clamp}(E_{\text{vocal}}(t), 0.0, 1.0) \\
E_{\text{harmonyNetwork}}(t) &= \text{clamp}(0.50 \cdot E_{\text{melodic}}(t) + 0.50 \cdot E_{\text{bass}}(t), 0.0, 1.0) \\
E_{\text{productionNetwork}}(t) &= \text{clamp}(0.50 \cdot E_{\text{drums}}(t) + 0.50 \cdot E_{\text{melodic}}(t), 0.0, 1.0) \\
E_{\text{emotionNetwork}}(t) &= \text{clamp}(1.40 \cdot E_{\text{melodic}}(t) \cdot E_{\text{vocal}}(t), 0.0, 1.0)
\end{aligned}$$

### 2.2 Stem Audibility, Solo Spotlight & Dormancy State
Let $\text{anySolo} \in \{\text{true}, \text{false}\}$ denote `stemMixerState.anySoloActive`. For each cluster domain $D_k$ and its primary mapped stem $S(D_k) \in \{\text{vocals}, \text{drums}, \text{bass}, \text{melody}\}$:
- **Dormant State ($\mu_k = 1$)**: $D_k$ is dormant if its mapped stem channel is muted (`channel.isMuted == true`) OR if `anySolo == true` and `channel.isSolo == false`.
- **Solo Spotlight State ($\sigma_k = 1$)**: $D_k$ is solo-spotlighted if `channel.isSolo == true` and `channel.isMuted == false`.
- **Audible Gain Factor ($G_k \in [0.0, 1.5]$)**: $G_k = \text{channel.effectiveVolume}(\text{anySolo})$.

### 2.3 Radial Cap Dilation, Stipe Heave & Luminosity Multipliers
1. **Cap Scale Multiplier ($\kappa_k(t)$)**:
   $$\kappa_k(t) = \begin{cases}
   0.86, & \text{if } \mu_k = 1 \\
   \text{clamp}\Big(1.0 + 0.18 \cdot E_{D_k}(t) \cdot G_k + 0.08 \cdot \sigma_k, \; 0.85, \; 1.32\Big), & \text{if } \mu_k = 0
   \end{cases}$$
2. **Luminosity Multiplier ($L_k(t)$)**:
   $$L_k(t) = \begin{cases}
   0.20, & \text{if } \mu_k = 1 \\
   \text{clamp}(1.15 + 0.20 \cdot E_{D_k}(t), \; 1.00, \; 1.35), & \text{if } \sigma_k = 1 \\
   \text{clamp}(0.85 + 0.30 \cdot E_{D_k}(t), \; 0.50, \; 1.25), & \text{otherwise}
   \end{cases}$$
3. **Vertical Stipe Acoustic Heave ($\Delta Y_{\text{acoustic}, k}(t)$)**:
   $$\Delta Y_{\text{acoustic}, k}(t) = 6.5 \cdot E_{D_k}(t) \cdot (1 - \mu_k)$$
4. **Synaptic Photon Velocity Multiplier ($v_{\text{mult}}(t)$)**:
   $$v_{\text{mult}}(t) = \text{clamp}\Big(1.0 + 2.5 \cdot E_{\text{melodic}}(t) + 1.5 \cdot E_{\text{drums}}(t), \; 1.0, \; 5.0\Big)$$
5. **Log-Drum Camera Snap-Zoom ($Z_{\text{snap}}(t)$)**:
   $$Z_{\text{snap}}(t) = \text{clamp}\Big(1.0 + 0.065 \cdot S_{\text{snap}}(t), \; 1.0, \; 1.065\Big)$$

---

## 3. Pure Dart Domain Layer Additions

### 3.1 `PlayerHeroMode` & `AudioBiomeModulationState` (`apps/vhunambi_client/lib/features/studio/domain/models/mycelium_biome_models.dart`)

Add the following Pure Dart types to `mycelium_biome_models.dart`:

```dart
/// The 3 hero visual surfaces in ExpandedCockpitModal (REQ-P55-HERO-01).
enum PlayerHeroMode {
  artwork,
  biome3d,
  lyrics;

  String get label => switch (this) {
    artwork => 'Artwork',
    biome3d => '3D Biome',
    lyrics => 'Lyrics',
  };
}

/// Pure Dart 60 FPS audio-reactive modulation state driving the 3D Mycelium Biome (REQ-P55-DSP-01..03).
class AudioBiomeModulationState {
  final bool isPlaying;
  final int positionMs;
  final int durationMs;
  final double bassEnergy;
  final double drumsEnergy;
  final double melodicEnergy;
  final double vocalGlow;
  final double logDrumSnapZoom;
  final Map<MyceliumClusterDomain, double> clusterAudibleGains;
  final Set<MyceliumClusterDomain> soloedDomains;
  final Set<MyceliumClusterDomain> mutedDomains;

  const AudioBiomeModulationState({
    this.isPlaying = false,
    this.positionMs = 0,
    this.durationMs = 1,
    this.bassEnergy = 0.0,
    this.drumsEnergy = 0.0,
    this.melodicEnergy = 0.0,
    this.vocalGlow = 0.0,
    this.logDrumSnapZoom = 0.0,
    this.clusterAudibleGains = const {},
    this.soloedDomains = const {},
    this.mutedDomains = const {},
  });

  static const AudioBiomeModulationState idle = AudioBiomeModulationState();

  /// Normalized playback progress ratio in [0.0, 1.0].
  double get progressRatio {
    if (durationMs <= 0) return 0.0;
    return (positionMs / durationMs).clamp(0.0, 1.0);
  }

  /// Deterministically maps playback progress to the 5 SongJourneySection stages (REQ-P55-DSP-03).
  SongJourneySection get synchronizedJourneySection {
    final r = progressRatio;
    if (r < 0.15) return SongJourneySection.intro;
    if (r < 0.40) return SongJourneySection.verse;
    if (r < 0.70) return SongJourneySection.chorus;
    if (r < 0.85) return SongJourneySection.bridge;
    return SongJourneySection.outro;
  }

  /// True when a cluster is muted or non-soloed while another cluster is soloed (REQ-P55-DSP-02).
  bool isDomainDormant(MyceliumClusterDomain domain) {
    if (mutedDomains.contains(domain)) return true;
    if (soloedDomains.isNotEmpty && !soloedDomains.contains(domain)) {
      return true;
    }
    return false;
  }

  /// True when a cluster's mapped stem channel is explicitly soloed.
  bool isDomainSoloed(MyceliumClusterDomain domain) =>
      soloedDomains.contains(domain) && !mutedDomains.contains(domain);

  /// Evaluates real-time normalized acoustic energy in [0.0, 1.0] for [domain] (REQ-P55-DSP-01).
  double domainEnergyFor(MyceliumClusterDomain domain) {
    if (isDomainDormant(domain)) return 0.0;
    final raw = switch (domain) {
      MyceliumClusterDomain.melodyCore => melodicEnergy,
      MyceliumClusterDomain.rhythmNetwork =>
        0.60 * bassEnergy + 0.40 * drumsEnergy,
      MyceliumClusterDomain.vocalNetwork => vocalGlow,
      MyceliumClusterDomain.harmonyNetwork =>
        0.50 * melodicEnergy + 0.50 * bassEnergy,
      MyceliumClusterDomain.productionNetwork =>
        0.50 * drumsEnergy + 0.50 * melodicEnergy,
      MyceliumClusterDomain.emotionNetwork =>
        1.40 * melodicEnergy * vocalGlow,
    };
    return raw.clamp(0.0, 1.0);
  }

  /// Evaluates radial cap dilation multiplier in [0.85, 1.32] for [domain] (REQ-P55-DSP-02).
  double capScaleMultiplierFor(MyceliumClusterDomain domain) {
    if (isDomainDormant(domain)) return 0.86;
    final energy = domainEnergyFor(domain);
    final gain = (clusterAudibleGains[domain] ?? 1.0).clamp(0.0, 1.5);
    final soloBoost = isDomainSoloed(domain) ? 0.08 : 0.0;
    return (1.0 + 0.18 * energy * gain + soloBoost).clamp(0.85, 1.32);
  }

  /// Evaluates bioluminescent luminosity multiplier in [0.20, 1.35] for [domain] (REQ-P55-DSP-02).
  double luminosityMultiplierFor(MyceliumClusterDomain domain) {
    if (isDomainDormant(domain)) return 0.20;
    final energy = domainEnergyFor(domain);
    if (isDomainSoloed(domain)) {
      return (1.15 + 0.20 * energy).clamp(1.00, 1.35);
    }
    return (0.85 + 0.30 * energy).clamp(0.50, 1.25);
  }

  /// Vertical stipe acoustic heave in world dp along +Y (REQ-P55-DSP-02).
  double stipeHeaveFor(MyceliumClusterDomain domain) {
    if (isDomainDormant(domain)) return 0.0;
    return 6.5 * domainEnergyFor(domain);
  }

  /// Synaptic photon speed multiplier along arterial hyphae in [1.0, 5.0] (REQ-P55-DSP-02).
  double get photonSpeedMultiplier =>
      (1.0 + 2.5 * melodicEnergy + 1.5 * drumsEnergy).clamp(1.0, 5.0);

  /// Camera snap-zoom multiplier on log-drum transients in [1.0, 1.065] (REQ-P55-DSP-02).
  double get cameraSnapZoomMultiplier =>
      (1.0 + 0.065 * logDrumSnapZoom).clamp(1.0, 1.065);

  /// Floating spore cloud alpha in [0.35, 0.90].
  double get sporeCloudAlpha =>
      (0.35 + 0.55 * vocalGlow).clamp(0.35, 0.90);
}
```

### 3.2 `StemChannel.iconIdentifier` Hygiene (`apps/vhunambi_client/lib/features/player/domain/models/stem_mixer_state.dart`)

Update `StemType` and `StemChannel` in `stem_mixer_state.dart` to expose semantic `iconIdentifier` tokens while keeping `this.emoji = ''` optional with a default so existing JSON/unit tests remain 100% compatible:

```dart
enum StemType {
  vocals,
  drums,
  bass, // Log Drum & Sub Bass
  melody; // Instruments, Keys & Synths

  String get iconIdentifier => switch (this) {
    StemType.vocals => 'vocals',
    StemType.drums => 'drums',
    StemType.bass => 'bass',
    StemType.melody => 'melody',
  };
}
```

---

## 4. Real-Time Audio-to-Biome Bridge Provider (`apps/vhunambi_client/lib/features/player/presentation/providers/audio_reactive_biome_provider.dart`)

Create `apps/vhunambi_client/lib/features/player/presentation/providers/audio_reactive_biome_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../content_studio/domain/models/song_metadata_dna.dart';
import '../../../content_studio/presentation/providers/master_media_object_provider.dart';
import '../../../studio/domain/models/mycelium_biome_models.dart';
import '../../domain/models/stem_mixer_state.dart';
import 'player_provider.dart';
import 'stem_mixer_provider.dart';

/// Persists the active 3-Way Hero Mode in ExpandedCockpitModal (REQ-P55-HERO-01).
final playerHeroModeProvider = StateProvider<PlayerHeroMode>((ref) {
  return PlayerHeroMode.artwork;
});

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
```

---

## 5. Audio-Reactive Upgrades to `OrganicMycelium3DPainter` (`apps/vhunambi_client/lib/features/studio/presentation/widgets/biome/organic_mycelium_3d_painter.dart`)

Add `final AudioBiomeModulationState? audioModulation;` to `OrganicMycelium3DPainter`:
1. **Effective Camera Snap-Zoom**:
   ```dart
   final effectiveCamera = audioModulation != null && audioModulation!.logDrumSnapZoom > 0.01
       ? camera.copyWith(
           zoom: (camera.zoom * audioModulation!.cameraSnapZoomMultiplier)
               .clamp(BiomeCameraState.minZoom, BiomeCameraState.maxZoom),
         )
       : camera;
   ```
2. **Synaptic Photon Acceleration in `_draw3DMyceliumRootWeb`**:
   ```dart
   final baseSectionSpeed =
       graph.activeSection == SongJourneySection.chorus ? 1.45 : 1.0;
   final dspSpeed = audioModulation?.photonSpeedMultiplier ?? 1.0;
   final speedMultiplier = baseSectionSpeed * dspSpeed;
   ```
3. **Mushroom Cap Radial Dilation, Stipe Heave, Luminosity & Solo Spotlight Halo in `_draw3DFruitingBody`**:
   ```dart
   final mod = audioModulation;
   final capAudioScale = mod?.capScaleMultiplierFor(cluster.domain) ?? 1.0;
   final lumAudioMult = mod?.luminosityMultiplierFor(cluster.domain) ?? 1.0;
   final acousticHeaveY = mod?.stipeHeaveFor(cluster.domain) ?? 0.0;
   final isSoloSpotlight = mod?.isDomainSoloed(cluster.domain) ?? false;

   final hStipe = cluster.stipeHeight * stipeGrowth;
   final yApex = yRoot + hStipe + breathY + acousticHeaveY;
   final rCap = cluster.capRadius * capGrowth * capAudioScale;
   final hCap = cluster.capDepth * capGrowth * capAudioScale;
   final lum = (cluster.currentLuminosity * opacityMult * lumAudioMult)
       .clamp(0.12, 1.35);
   ```
   When `isSoloSpotlight == true`, draw a golden bioluminescent spotlight ring (`const Color(0xFFFFD166)`) around `heartProj.screenOffset` with radius `rCap * 0.92 * heartProj.scale.clamp(0.4, 2.2)`.
4. **Update `shouldRepaint`**:
   ```dart
   @override
   bool shouldRepaint(covariant OrganicMycelium3DPainter oldDelegate) {
     return oldDelegate.animationProgress != animationProgress ||
         oldDelegate.camera != camera ||
         oldDelegate.focusTransitionProgress != focusTransitionProgress ||
         oldDelegate.graph != graph ||
         oldDelegate.audioModulation != audioModulation;
   }
   ```

---

## 6. Interactive 3D Biome Player Viewport (`apps/vhunambi_client/lib/features/player/presentation/widgets/player_living_biome_hero_viewport.dart`)

Create `apps/vhunambi_client/lib/features/player/presentation/widgets/player_living_biome_hero_viewport.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../studio/domain/models/mycelium_biome_models.dart';
import '../../../studio/presentation/controllers/biome_camera_controller.dart';
import '../../../studio/presentation/providers/mycelium_biome_provider.dart';
import '../../../studio/presentation/widgets/biome/organic_mycelium_3d_painter.dart';
import '../../../studio/presentation/widgets/song_dna_node_tree_modal.dart';
import '../providers/audio_reactive_biome_provider.dart';
import '../providers/player_provider.dart';
import '../providers/stem_mixer_provider.dart';

/// Interactive 3D Mycelium Living Ecosystem embedded inside ExpandedCockpitModal (REQ-P55-HERO-02, REQ-P55-STEM-01).
class PlayerLivingBiomeHeroViewport extends ConsumerStatefulWidget {
  final double height;

  const PlayerLivingBiomeHeroViewport({
    super.key,
    this.height = 280,
  });

  @override
  ConsumerState<PlayerLivingBiomeHeroViewport> createState() =>
      _PlayerLivingBiomeHeroViewportState();
}

class _PlayerLivingBiomeHeroViewportState
    extends ConsumerState<PlayerLivingBiomeHeroViewport> {
  MyceliumClusterDomain? _selectedDomain;

  @override
  Widget build(BuildContext context) {
    final graph = ref.watch(myceliumBiomeGraphProvider);
    final camera = ref.watch(biomeCameraProvider);
    final modulation = ref.watch(audioReactiveBiomeModulationProvider);
    final mixerState = ref.watch(stemMixerProvider);

    // Deterministic animation phase synchronized to playback clock (0..1 every 6 seconds)
    final animProgress = ((modulation.positionMs % 6000) / 6000.0).clamp(0.0, 1.0);
    final syncedGraph = graph.copyWith(
      activeSection: modulation.synchronizedJourneySection,
    );

    return Container(
      key: const Key('player_living_biome_viewport'),
      height: widget.height,
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceCanvas,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.brandPrimary.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPrimary.withValues(alpha: 0.16),
            blurRadius: 28,
            spreadRadius: -4,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canvasSize = Size(
            constraints.maxWidth,
            constraints.maxHeight,
          );

          return Stack(
            children: [
              // 1. 3D Mycelium Canvas with Orbit Gesture Support
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) {
                    ref.read(biomeCameraProvider.notifier).orbit(
                          details.delta.dx * 0.008,
                          -details.delta.dy * 0.006,
                        );
                  },
                  onTapUp: (details) {
                    final hit = BiomeProjectionEngine.hitTestCluster(
                      tapOffset: details.localPosition,
                      graph: syncedGraph,
                      camera: camera,
                      canvasSize: canvasSize,
                    );
                    if (hit != null) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedDomain =
                            _selectedDomain == hit ? null : hit;
                      });
                    }
                  },
                  child: CustomPaint(
                    size: canvasSize,
                    painter: OrganicMycelium3DPainter(
                      graph: syncedGraph,
                      camera: camera,
                      animationProgress: animProgress,
                      audioModulation: modulation,
                    ),
                  ),
                ),
              ),

              // 2. Semantic Positioned Cluster Tap Targets (Law 4 Compliance)
              for (final cluster in syncedGraph.clusters.values)
                Builder(
                  builder: (context) {
                    final proj = BiomeProjectionEngine.project3D(
                      cluster.capApexPosition,
                      camera,
                      canvasSize,
                    );
                    if (proj == null) return const SizedBox.shrink();
                    final dx = (proj.screenOffset.dx - 24.0)
                        .clamp(4.0, (canvasSize.width - 52.0).clamp(4.0, double.infinity));
                    final dy = (proj.screenOffset.dy - 24.0)
                        .clamp(4.0, (canvasSize.height - 52.0).clamp(4.0, double.infinity));
                    return Positioned(
                      left: dx,
                      top: dy,
                      width: 48,
                      height: 48,
                      child: Semantics(
                        button: true,
                        label: '${cluster.domain.displayName} cluster',
                        child: GestureDetector(
                          key: Key('player_biome_cluster_${cluster.domain.name}'),
                          behavior: HitTestBehavior.translucent,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedDomain = _selectedDomain == cluster.domain
                                  ? null
                                  : cluster.domain;
                            });
                          },
                        ),
                      ),
                    );
                  },
                ),

              // 3. Top Header Overlay: Live 60 FPS DSP Badge & Expand to Full 3D Universe
              Positioned(
                top: 10,
                left: 12,
                right: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      key: const Key('player_biome_dsp_badge'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.darkSurfaceElevated.withValues(alpha: 0.88),
                        borderRadius: AppRadius.pillBorder,
                        border: Border.all(
                          color: AppColors.badgeCyan.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const PhosphorIcon(
                            PhosphorIconsBold.waveform,
                            size: 13,
                            color: AppColors.badgeCyan,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'LIVE 3D BIOME • ${modulation.synchronizedJourneySection.label.toUpperCase()}',
                            style: AppTypography.badge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      key: const Key('player_open_full_3d_biome_btn'),
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        SongDnaNodeTreeModal.show(context);
                      },
                      borderRadius: AppRadius.pillBorder,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.darkSurfaceElevated.withValues(alpha: 0.90),
                          borderRadius: AppRadius.pillBorder,
                          border: Border.all(color: AppColors.brandPrimary),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const PhosphorIcon(
                              AppIcons.dna,
                              size: 13,
                              color: AppColors.brandPrimary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Full 3D Universe',
                              style: AppTypography.badge.copyWith(
                                color: AppColors.brandPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Selected Cluster Quick-Mix Solo / Mute HUD (REQ-P55-STEM-01)
              if (_selectedDomain != null)
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 38,
                  child: PlayerBiomeQuickMixHud(
                    domain: _selectedDomain!,
                    modulation: modulation,
                    mixerState: mixerState,
                    onClose: () => setState(() => _selectedDomain = null),
                  ),
                ),

              // 5. Bottom Playback-Synchronized 5-Section Song Journey Scrubber (REQ-P55-HERO-02)
              Positioned(
                left: 8,
                right: 8,
                bottom: 6,
                child: Container(
                  key: const Key('player_biome_journey_bar'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.darkSurfaceElevated.withValues(alpha: 0.92),
                    borderRadius: AppRadius.pillBorder,
                    border: Border.all(color: AppColors.darkBorderSubtle),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final section in SongJourneySection.values)
                        Builder(
                          builder: (context) {
                            final isCurrent =
                                modulation.synchronizedJourneySection == section;
                            return InkWell(
                              key: Key('player_biome_section_${section.name}'),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                ref
                                    .read(playerStateProvider.notifier)
                                    .seekByRatio(section.normalizedPosition);
                                ref
                                    .read(myceliumBiomeGraphProvider.notifier)
                                    .selectSongJourneySection(section);
                              },
                              borderRadius: AppRadius.pillBorder,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? AppColors.brandPrimary.withValues(alpha: 0.22)
                                      : Colors.transparent,
                                  borderRadius: AppRadius.pillBorder,
                                ),
                                child: Text(
                                  section.label,
                                  style: AppTypography.badge.copyWith(
                                    color: isCurrent
                                        ? AppColors.brandPrimary
                                        : AppColors.textSecondary,
                                    fontWeight: isCurrent
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Compact Solo / Mute Stem Quick-Mix HUD revealed when a 3D mushroom is tapped in Now Playing.
class PlayerBiomeQuickMixHud extends ConsumerWidget {
  final MyceliumClusterDomain domain;
  final AudioBiomeModulationState modulation;
  final StemMixerState mixerState;
  final VoidCallback onClose;

  const PlayerBiomeQuickMixHud({
    super.key,
    required this.domain,
    required this.modulation,
    required this.mixerState,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryStem = primaryStemForCluster(domain);
    final channel = mixerState.channelFor(primaryStem);
    final energyPct = (modulation.domainEnergyFor(domain) * 100).round();
    final clusterColor = Color(domain.hexColor);

    return Container(
      key: const Key('player_biome_quick_mix_hud'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.darkSurfaceModal,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: clusterColor.withValues(alpha: 0.65)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: clusterColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${domain.shortLabel} • ${channel.name}',
                  style: AppTypography.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${channel.gainDecibels} • $energyPct% Live Energy',
                  style: AppTypography.badge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Quick Solo Button
          InkWell(
            key: Key('biome_quick_solo_${domain.name}'),
            onTap: () {
              HapticFeedback.mediumImpact();
              ref.read(stemMixerProvider.notifier).toggleSolo(primaryStem);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: channel.isSolo
                    ? AppColors.coinGold
                    : AppColors.darkSurfaceSecondary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: channel.isSolo
                      ? AppColors.coinGold
                      : AppColors.darkBorderSubtle,
                ),
              ),
              child: Text(
                'Solo',
                style: AppTypography.badge.copyWith(
                  color: channel.isSolo ? Colors.black : Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Quick Mute Button
          InkWell(
            key: Key('biome_quick_mute_${domain.name}'),
            onTap: () {
              HapticFeedback.mediumImpact();
              ref.read(stemMixerProvider.notifier).toggleMute(primaryStem);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: channel.isMuted
                    ? AppColors.error
                    : AppColors.darkSurfaceSecondary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: channel.isMuted
                      ? AppColors.error
                      : AppColors.darkBorderSubtle,
                ),
              ),
              child: Text(
                'Mute',
                style: AppTypography.badge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: const PhosphorIcon(
              AppIcons.close,
              size: 14,
              color: AppColors.textSecondary,
            ),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
```

---

## 7. `StemMixerBiomeEntanglementStrip` in `StemMixerDeck` (`apps/vhunambi_client/lib/features/player/presentation/widgets/stem_mixer_deck.dart`)

Add `StemMixerBiomeEntanglementStrip` inside `StemMixerDeck` directly above the channel strips:

```dart
/// Live 6-Cluster Mycelium Stem Telemetry & Solo/Mute Entanglement Strip (REQ-P55-STEM-02).
class StemMixerBiomeEntanglementStrip extends ConsumerWidget {
  const StemMixerBiomeEntanglementStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modulation = ref.watch(audioReactiveBiomeModulationProvider);
    final mixerNotifier = ref.read(stemMixerProvider.notifier);

    return Container(
      key: const Key('stem_mixer_biome_strip'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.inputBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PhosphorIcon(
                AppIcons.dna,
                size: 15,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Living 3D Mycelium Stem Entanglement',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'Tap: Solo • Hold: Mute',
                style: AppTypography.badge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final domain in MyceliumClusterDomain.values)
                Builder(
                  builder: (context) {
                    final isDormant = modulation.isDomainDormant(domain);
                    final isSolo = modulation.isDomainSoloed(domain);
                    final energyPct =
                        (modulation.domainEnergyFor(domain) * 100).round();
                    final stemType = primaryStemForCluster(domain);
                    final color = Color(domain.hexColor);

                    return InkWell(
                      key: Key('stem_mixer_cluster_pill_${domain.name}'),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        mixerNotifier.toggleSolo(stemType);
                      },
                      onLongPress: () {
                        HapticFeedback.mediumImpact();
                        mixerNotifier.toggleMute(stemType);
                      },
                      borderRadius: AppRadius.pillBorder,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: isDormant ? 0.35 : 1.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isSolo
                                ? color.withValues(alpha: 0.25)
                                : AppColors.surfaceSecondary,
                            borderRadius: AppRadius.pillBorder,
                            border: Border.all(
                              color: isSolo
                                  ? AppColors.coinGold
                                  : color.withValues(alpha: 0.55),
                              width: isSolo ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: isDormant
                                      ? AppColors.textSecondary
                                      : color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${domain.shortLabel} ${isDormant ? "MUTED" : "$energyPct%"}',
                                style: AppTypography.badge.copyWith(
                                  color: Colors.white,
                                  fontWeight: isSolo
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
```

---

## 8. `TrackLivingBiomePreviewCard` in `TrackDetailView` (`apps/vhunambi_client/lib/features/track/presentation/widgets/track_living_biome_preview_card.dart`)

Create `apps/vhunambi_client/lib/features/track/presentation/widgets/track_living_biome_preview_card.dart` and mount it inside `TrackDetailView` immediately below `StemSeparationLab`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../player/presentation/providers/audio_reactive_biome_provider.dart';
import '../../../studio/domain/models/mycelium_biome_models.dart';
import '../../../studio/presentation/widgets/song_dna_node_tree_modal.dart';

/// Interactive Living Song DNA Biome card for TrackDetailView (REQ-P55-TRK-01).
class TrackLivingBiomePreviewCard extends ConsumerWidget {
  final String trackTitle;
  final String genre;

  const TrackLivingBiomePreviewCard({
    super.key,
    required this.trackTitle,
    required this.genre,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modulation = ref.watch(audioReactiveBiomeModulationProvider);

    return Container(
      key: const Key('track_detail_living_biome_card'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(
          color: AppColors.brandPrimary.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: PhosphorIcon(
                    AppIcons.dna,
                    color: AppColors.brandPrimary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Living 3D Song DNA Biome',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Explore the 6 audio-reactive mycelium clusters of "$trackTitle".',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                key: const Key('track_detail_open_3d_biome_btn'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: Colors.black,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.pillBorder,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  SongDnaNodeTreeModal.show(context);
                },
                icon: const PhosphorIcon(
                  AppIcons.dna,
                  size: 16,
                  color: Colors.black,
                ),
                label: Text(
                  'Enter 3D Biome',
                  style: AppTypography.caption.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final domain in MyceliumClusterDomain.values)
                Builder(
                  builder: (context) {
                    final energyPct =
                        (modulation.domainEnergyFor(domain) * 100).round();
                    final color = Color(domain.hexColor);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: AppRadius.pillBorder,
                        border: Border.all(
                          color: color.withValues(alpha: 0.55),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${domain.shortLabel} • $energyPct%',
                            style: AppTypography.badge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
```

