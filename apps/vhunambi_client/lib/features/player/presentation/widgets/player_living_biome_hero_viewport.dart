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
import '../../domain/models/stem_mixer_state.dart';
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
                    ref.read(biomeCameraProvider.notifier).addOrbitDelta(
                          deltaYaw: details.delta.dx * 0.008,
                          deltaPitch: -details.delta.dy * 0.006,
                        );
                  },
                  onTapUp: (details) {
                    final hit = BiomeProjectionEngine.hitTest(
                      tapPosition: details.localPosition,
                      viewportSize: canvasSize,
                      graph: syncedGraph,
                      camera: camera,
                    );
                    if (hit.hitCluster != null) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedDomain =
                            _selectedDomain == hit.hitCluster ? null : hit.hitCluster;
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
                left: 10,
                right: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        key: const Key('player_biome_dsp_badge'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
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
                              size: 12,
                              color: AppColors.badgeCyan,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                '3D BIOME • ${modulation.synchronizedJourneySection.label.toUpperCase()}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.badge.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      key: const Key('player_open_full_3d_biome_btn'),
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        SongDnaNodeTreeModal.show(context);
                      },
                      borderRadius: AppRadius.pillBorder,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
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
                              size: 12,
                              color: AppColors.brandPrimary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '3D Universe',
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
              color: AppColors.darkTextSecondary,
            ),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
