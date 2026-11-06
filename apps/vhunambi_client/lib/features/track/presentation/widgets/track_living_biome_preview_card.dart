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
