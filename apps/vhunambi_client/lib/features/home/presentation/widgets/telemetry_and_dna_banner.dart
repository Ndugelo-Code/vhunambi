import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/services/haptics_service.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/features/creator_dna/presentation/providers/creator_dna_provider.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/creator_dna_helix_lab_sheet.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/generation_pipeline_providers.dart';

/// Zone 1.5: Displays live AI pipeline progress when generating (`home_pipeline_progress_card`),
/// or a slim 48dp Creator DNA calibration strip linking to [CreatorDnaHelixLabSheet].
class TelemetryAndDnaBanner extends ConsumerWidget {
  final VoidCallback? onNavigateToStudio;

  const TelemetryAndDnaBanner({
    super.key,
    this.onNavigateToStudio,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pipeline = ref.watch(generationProgressProvider);
    final dna = ref.watch(creatorDnaProvider);

    if (pipeline != null && pipeline.isGenerating) {
      return Material(
        color: AppColors.surfaceElevatedOf(context),
        borderRadius: AppRadius.inputBorder,
        child: InkWell(
          key: const Key('home_inflight_generation_banner'),
          borderRadius: AppRadius.inputBorder,
          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
            onNavigateToStudio?.call();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: AppRadius.inputBorder,
              border: Border.all(
                color: AppColors.brandPrimary.withValues(alpha: 0.45),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const PhosphorIcon(
                      PhosphorIconsFill.waveform,
                      size: 16,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${pipeline.trackTitle} • ${pipeline.genre}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${(pipeline.progressPercent * 100).round()}%',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  pipeline.statusMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: AppRadius.pillBorder,
                  child: LinearProgressIndicator(
                    value: pipeline.progressPercent.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: AppColors.borderSubtleOf(context),
                    color: AppColors.brandPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final topGenre =
        dna.topGenres(1).isNotEmpty ? dna.topGenres(1).first : 'Adaptive Sound';

    return Material(
      color: AppColors.surfaceElevatedOf(context),
      borderRadius: AppRadius.pillBorder,
      child: InkWell(
        key: const Key('home_dna_compact_strip'),
        borderRadius: AppRadius.pillBorder,
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
          HapticsService().lightImpact();
          CreatorDnaHelixLabSheet.show(context, profile: dna);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: AppRadius.pillBorder,
            border: Border.all(
              color: AppColors.accentElectric.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: <Widget>[
              const PhosphorIcon(
                PhosphorIconsFill.dna,
                size: 16,
                color: AppColors.accentElectric,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Creator DNA ${dna.strengthPercent}% calibrated • $topGenre',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textPrimaryOf(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Helix',
                style: AppTypography.caption.copyWith(
                  color: AppColors.accentElectric,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              const PhosphorIcon(
                PhosphorIconsBold.caretRight,
                size: 12,
                color: AppColors.accentElectric,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
