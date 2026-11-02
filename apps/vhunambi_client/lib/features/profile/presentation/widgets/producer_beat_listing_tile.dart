import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../marketplace/domain/models/marketplace_models.dart';

/// Single interactive beat listing tile on the public artist profile (Phase 30 REQ-PROF-BEAT-CAT-02).
/// Displays playback preview trigger, genre, BPM, key, and 1-tap license modal launch.
class ProducerBeatListingTile extends StatelessWidget {
  final BeatListingEntity beat;
  final VoidCallback onAudition;
  final VoidCallback onLicense;
  final bool isPlaying;

  const ProducerBeatListingTile({
    super.key,
    required this.beat,
    required this.onAudition,
    required this.onLicense,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    final zarPrice = (beat.priceInCredits * 0.9).round();

    return Container(
      key: Key('producer_beat_tile_${beat.id}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(
          color: isPlaying ? AppColors.brandPrimary : AppColors.borderSubtle,
        ),
      ),
      child: Row(
        children: [
          // 44x44dp minimum touch target for Audition play button
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: InkWell(
              key: Key('beat_tile_audition_btn_${beat.id}'),
              onTap: onAudition,
              borderRadius: AppRadius.thumbBorder,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppGradients.forGenre(beat.genre),
                  borderRadius: AppRadius.thumbBorder,
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Metadata Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  beat.title,
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: AppRadius.pillBorder,
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Text(
                        beat.genre,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${beat.bpmLabel} • ${beat.musicalKey}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Price & Licensing Action
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${beat.priceInCredits} Coins',
                style: AppTypography.caption.copyWith(
                  color: AppColors.coinGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'R$zarPrice',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 36),
                child: ElevatedButton(
                  key: Key('beat_tile_license_btn_${beat.id}'),
                  onPressed: onLicense,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.surfaceSecondary,
                    foregroundColor: AppColors.textPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.pillBorder,
                    ),
                    side: BorderSide(color: AppColors.borderSubtle),
                  ),
                  child: const Text(
                    'License',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

