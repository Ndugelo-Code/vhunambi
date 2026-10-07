import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/track_detail_models.dart';

/// Generative Prompt Attribution Card with Studio Remix Action (REQ-TRK-10).
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(width: 8),
              Text(
                'PROMPT',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Inset Prompt Container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Text(
              '"${track.prompt.isNotEmpty ? track.prompt : 'Traditional African rhythms with contemporary log drums'}"',
              style: AppTypography.bodySmall.copyWith(
                fontStyle: FontStyle.italic,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Action Row
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: AppColors.brandContrast,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.pillBorder,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                elevation: 0,
              ),
              onPressed: onRemixPrompt,
              icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
              label: const Text(
                'Remix Prompt ✨',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
