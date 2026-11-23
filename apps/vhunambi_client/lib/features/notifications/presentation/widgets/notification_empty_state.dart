import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';

/// Clean placeholder shown when no alerts match the active filter/search.
///
/// Displays an African-motif glyph, a headline and a supporting caption, all
/// resolved through `AppColors` / `AppTypography` tokens.
class NotificationEmptyState extends StatelessWidget {
  const NotificationEmptyState({
    super.key,
    this.title = 'Nothing here yet',
    this.message = 'Rendered songs, tips and studio updates will appear here.',
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.section,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondaryOf(context),
              shape: BoxShape.circle,
            ),
            child: PhosphorIcon(
              PhosphorIconsRegular.bellSlash,
              size: 32,
              color: AppColors.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            key: const Key('notification_empty_title'),
            textAlign: TextAlign.center,
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}
