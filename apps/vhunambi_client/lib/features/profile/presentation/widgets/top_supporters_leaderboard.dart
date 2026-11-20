import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/utils/responsive_utils.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_glass_surface.dart';
import 'package:vhunambi_client/features/profile/domain/models/profile_models.dart';

/// Top Supporters Leaderboard with Phosphor Medal Badges (`REQ-TRK-14`, `STD-UIUX-001`).
class TopSupportersLeaderboard extends StatelessWidget {
  final List<SupporterEntity> supporters;
  final VoidCallback? onTipFirst;

  const TopSupportersLeaderboard({
    super.key,
    required this.supporters,
    this.onTipFirst,
  });

  Color _medalColor(int rank) {
    return switch (rank) {
      1 => AppColors.coinGold,
      2 => const Color(0xFF94A3B8),
      3 => const Color(0xFFD97706),
      _ => AppColors.brandPrimary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : 16,
        vertical: 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const PhosphorIcon(
                AppIcons.trophy,
                color: AppColors.coinGold,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Top Supporters',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (supporters.isEmpty)
            VhunambiGlassSurface(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: <Widget>[
                  PhosphorIcon(
                    AppIcons.trophy,
                    size: 36,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No supporters yet — be the first to tip!',
                    style: AppTypography.bodySmall.copyWith(
                      color: textSecondary,
                    ),
                  ),
                  if (onTipFirst != null) ...<Widget>[
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        backgroundColor: AppColors.brandPrimary,
                        foregroundColor: AppColors.brandContrast,
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.pillBorder,
                        ),
                      ),
                      onPressed: onTipFirst,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text('Tip Artist'),
                          SizedBox(width: 6),
                          PhosphorIcon(AppIcons.coin, size: 16),
                        ],
                      ),
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
                    final width = isWide
                        ? (constraints.maxWidth - 24) / 3
                        : constraints.maxWidth;
                    final rankColor = _medalColor(supporter.rank);
                    return VhunambiGlassSurface(
                      width: width,
                      tintAccent: supporter.rank == 1
                          ? AppColors.coinGold
                          : null,
                      borderColorOverride: supporter.rank == 1
                          ? AppColors.coinGold.withValues(alpha: 0.45)
                          : null,
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: rankColor.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: PhosphorIcon(
                                PhosphorIconsFill.medal,
                                size: 20,
                                color: rankColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  supporter.name,
                                  style: AppTypography.bodySmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${supporter.handle} · ${supporter.rankBadge}',
                                  style: AppTypography.caption.copyWith(
                                    color: textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                              color: AppColors.surfaceSecondaryOf(context),
                              borderRadius: AppRadius.pillBorder,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const PhosphorIcon(
                                  AppIcons.lightning,
                                  size: 12,
                                  color: AppColors.coinGold,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${supporter.totalCreditsTipped}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.coinGold,
                                  ),
                                ),
                              ],
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
}
