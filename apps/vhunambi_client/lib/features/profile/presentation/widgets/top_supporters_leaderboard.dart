import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../domain/models/profile_models.dart';

/// Top Supporters Leaderboard with 🥇 🥈 🥉 Badges (REQ-TRK-14).
class TopSupportersLeaderboard extends StatelessWidget {
  final List<SupporterEntity> supporters;
  final VoidCallback? onTipFirst;

  const TopSupportersLeaderboard({
    super.key,
    required this.supporters,
    this.onTipFirst,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : 16,
        vertical: 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏆', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'Top Supporters',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (supporters.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: AppRadius.cardBorder,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.military_tech_outlined,
                    size: 36,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No supporters yet — be the first to tip!',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (onTipFirst != null) ...[
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: AppColors.brandContrast,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.pillBorder,
                        ),
                      ),
                      onPressed: onTipFirst,
                      child: const Text('Tip Artist 🪙'),
                    ),
                  ],
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 540;
                return Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: supporters.map((supporter) {
                    final width = isWide ? (constraints.maxWidth - 24) / 3 : constraints.maxWidth;
                    return Container(
                      width: width,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: supporter.rank == 1
                              ? AppColors.coinGold.withAlpha(90)
                              : AppColors.borderSubtle,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _getMedal(supporter.rank),
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  supporter.name,
                                  style: AppTypography.bodySmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  supporter.handle,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSecondary,
                              borderRadius: AppRadius.pillBorder,
                            ),
                            child: Text(
                              '⚡ ${supporter.totalCreditsTipped}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.coinGold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }

  String _getMedal(int rank) {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '🏅';
    }
  }
}
