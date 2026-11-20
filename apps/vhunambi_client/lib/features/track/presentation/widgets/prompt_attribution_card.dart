import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_glass_surface.dart';
import 'package:vhunambi_client/features/track/domain/models/track_detail_models.dart';

/// Owner-only Generative Prompt Attribution Card with Studio Remix Action
/// (`REQ-TRK-10`, `STD-UIUX-001` zero emojis / Phosphor icons).
class PromptAttributionCard extends StatelessWidget {
  final TrackDetailEntity track;
  final VoidCallback? onRemixPrompt;

  const PromptAttributionCard({
    super.key,
    required this.track,
    this.onRemixPrompt,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: VhunambiGlassSurface(
        variant: VhunambiGlassVariant.card,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const PhosphorIcon(
                  AppIcons.sparkle,
                  size: 18,
                  color: AppColors.brandPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  'PROMPT',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondaryOf(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtleOf(context)),
              ),
              child: Text(
                '"${track.prompt.isNotEmpty ? track.prompt : 'Traditional African rhythms with contemporary log drums'}"',
                style: AppTypography.bodySmall.copyWith(
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                  color: textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: AppColors.brandContrast,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.pillBorder,
                  ),
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  elevation: 0,
                ),
                onPressed: onRemixPrompt,
                icon: const PhosphorIcon(AppIcons.magicWand, size: 16),
                label: const Text(
                  'Remix Prompt',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
