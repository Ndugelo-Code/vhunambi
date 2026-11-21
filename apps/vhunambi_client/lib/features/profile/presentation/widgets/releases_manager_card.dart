import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/vhunambi_glass_surface.dart';
import '../../domain/models/profile_models.dart';

/// Discography Releases Manager for Albums, EPs, and Singles (REQ-TRK-15).
class ReleasesManagerCard extends StatelessWidget {
  final List<MusicReleaseEntity> releases;
  final VoidCallback? onNewRelease;

  const ReleasesManagerCard({
    super.key,
    required this.releases,
    this.onNewRelease,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: VhunambiGlassSurface(
        variant: VhunambiGlassVariant.card,
        enableLiveBlur: false,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                const PhosphorIcon(
                  PhosphorIconsRegular.disc,
                  size: 20,
                  color: AppColors.brandPrimary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Discography Releases',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textPrimaryOf(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: AppColors.brandContrast,
                    minimumSize: const Size(0, 44),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.pillBorder,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    elevation: 0,
                  ),
                  onPressed: onNewRelease,
                  icon: const PhosphorIcon(PhosphorIconsBold.plus, size: 16),
                  label: const Text(
                    'New Release',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (releases.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondaryOf(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSubtleOf(context)),
                ),
                child: Column(
                  children: [
                    PhosphorIcon(
                      PhosphorIconsRegular.musicNotes,
                      size: 38,
                      color: AppColors.textSecondaryOf(context),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Group your songs into an Album, EP, or Single.',
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryOf(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your official artist discography starts here.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (onNewRelease != null) ...[
                      const SizedBox(height: 16),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.brandPrimary.withAlpha(24),
                          foregroundColor: AppColors.brandPrimary,
                          minimumSize: const Size(0, 44),
                          side: const BorderSide(color: AppColors.brandPrimary),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.pillBorder,
                          ),
                        ),
                        onPressed: onNewRelease,
                        child: const Text('Create First Release'),
                      ),
                    ],
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: releases.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final rel = releases[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondaryOf(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.borderSubtleOf(context),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: AppGradients.forGenre(rel.genre),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: PhosphorIcon(
                              PhosphorIconsRegular.disc,
                              color: AppColors.brandContrast,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rel.title,
                                style: AppTypography.bodySmall.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimaryOf(context),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${rel.typeLabel} • ${rel.trackCount} ${rel.trackCount == 1 ? 'track' : 'tracks'} • ${rel.releaseYear} • ${rel.genre}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondaryOf(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
