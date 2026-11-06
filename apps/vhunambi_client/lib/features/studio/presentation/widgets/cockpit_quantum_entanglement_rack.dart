import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import '../../domain/models/mycelium_biome_models.dart';
import '../../domain/models/studio_form_state.dart';
import '../providers/mycelium_biome_provider.dart';
import '../providers/song_dna_graph_provider.dart';
import '../providers/studio_form_provider.dart';
import 'song_dna_node_tree_modal.dart';

/// Phase 54 + Phase 56: Bidirectional 2D <-> 3D Quantum Stem Authority Rack.
/// Renders a compact, collapsible 2x3 grid of the 6 Mycelium Cluster Domains
/// so mobile viewports never suffer from 6 full-width stacked cards.
class CockpitQuantumEntanglementRack extends ConsumerStatefulWidget {
  final ValueChanged<MyceliumClusterDomain>? onJumpTo3DCluster;

  const CockpitQuantumEntanglementRack({
    super.key = const Key('cockpit_quantum_entanglement_rack'),
    this.onJumpTo3DCluster,
  });

  @override
  ConsumerState<CockpitQuantumEntanglementRack> createState() =>
      _CockpitQuantumEntanglementRackState();
}

class _CockpitQuantumEntanglementRackState
    extends ConsumerState<CockpitQuantumEntanglementRack> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final biomeGraph = ref.watch(myceliumBiomeGraphProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lockedCount = biomeGraph.clusters.values
        .where((c) => c.stemLockMode == StemLockMode.lockedPure44k)
        .length;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceElevated.withValues(alpha: 0.72)
            : AppColors.lightSurfaceElevated.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.brandPrimary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const PhosphorIcon(
                  PhosphorIconsBold.atom,
                  size: 13,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: GestureDetector(
                  key: const Key('cockpit_rack_collapse_toggle_btn'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _isExpanded = !_isExpanded);
                  },
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          '2D <-> 3D Quantum Stem Authority',
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brandPrimary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$lockedCount Locked',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      PhosphorIcon(
                        _isExpanded
                            ? PhosphorIconsBold.caretUp
                            : PhosphorIconsBold.caretDown,
                        size: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isExpanded) ...[
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final isTwoCol = constraints.maxWidth >= 280;
                final cardWidth = isTwoCol
                    ? (constraints.maxWidth - 8) / 2
                    : constraints.maxWidth;

                return Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final domain in MyceliumClusterDomain.values)
                      _buildDomainAuthorityTile(
                        context,
                        ref,
                        cluster: biomeGraph.clusters[domain]!,
                        width: cardWidth,
                        isDark: isDark,
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDomainAuthorityTile(
    BuildContext context,
    WidgetRef ref, {
    required MushroomFruitingBody cluster,
    required double width,
    required bool isDark,
  }) {
    final domain = cluster.domain;
    final domainColor = Color(domain.hexColor);
    final mode = cluster.stemLockMode;

    return Container(
      key: Key('cockpit_domain_card_${domain.name}'),
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0A1422).withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: domainColor.withValues(alpha: 0.45),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: domainColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  domain.displayName,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${(cluster.confidence * 100).round()}%',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  color: domainColor,
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                key: Key('cockpit_jump_3d_${domain.name}'),
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (widget.onJumpTo3DCluster != null) {
                    widget.onJumpTo3DCluster!(domain);
                  } else {
                    SongDnaNodeTreeModal.show(
                      context,
                      initialFocusedDomain: domain,
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: domainColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: domainColor.withValues(alpha: 0.5),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PhosphorIcon(
                        PhosphorIconsBold.cubeFocus,
                        size: 10,
                        color: domainColor,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '3D',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: domainColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              _buildMicroModeChip(
                ref: ref,
                domain: domain,
                targetMode: StemLockMode.lockedPure44k,
                currentMode: mode,
                label: 'Lock',
                activeColor: const Color(0xFFFFB703),
                primaryLockKey: Key('cockpit_stem_lock_${domain.name}'),
              ),
              const SizedBox(width: 3),
              _buildMicroModeChip(
                ref: ref,
                domain: domain,
                targetMode: StemLockMode.harmonicInpaint,
                currentMode: mode,
                label: 'Inpaint',
                activeColor: const Color(0xFF00F5D4),
              ),
              const SizedBox(width: 3),
              _buildMicroModeChip(
                ref: ref,
                domain: domain,
                targetMode: StemLockMode.elasticResynth,
                currentMode: mode,
                label: 'Resynth',
                activeColor: const Color(0xFFD946EF),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMicroModeChip({
    required WidgetRef ref,
    required MyceliumClusterDomain domain,
    required StemLockMode targetMode,
    required StemLockMode currentMode,
    required String label,
    required Color activeColor,
    Key? primaryLockKey,
  }) {
    final isSelected = currentMode == targetMode;
    final widgetKey = primaryLockKey ?? Key('cockpit_stem_lock_${domain.name}_${targetMode.name}');

    return Expanded(
      child: GestureDetector(
        key: widgetKey,
        onTap: () {
          HapticFeedback.selectionClick();
          ref
              .read(songDnaGraphProvider.notifier)
              .setStemLockMode(domain.legacyBranchRootId, targetMode);
          ref
              .read(studioFormProvider.notifier)
              .setClusterStemLockMode(domain, targetMode);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: isSelected ? activeColor : Colors.white12,
              width: 0.8,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: isSelected ? activeColor : Colors.white60,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
