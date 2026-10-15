import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/notification_enums.dart';

/// Central mapping from [NotificationCategory] to its design-token color,
/// glyph and short rail label. Keeps zero raw hex — every color resolves
/// through `AppColors`.
abstract final class NotificationCategoryStyle {
  /// Accent token for a category (blueprint §6 taxonomy).
  static Color color(NotificationCategory category) => switch (category) {
        NotificationCategory.social => AppColors.accentElectric,
        NotificationCategory.system => AppColors.accentGold,
        NotificationCategory.creatorActivity => AppColors.brandPrimary,
        NotificationCategory.algorithmic => AppColors.accentSuccess,
      };

  /// Glyph for a category (blueprint §6 taxonomy).
  static IconData icon(NotificationCategory category) => switch (category) {
        NotificationCategory.social => Icons.people_alt_outlined,
        NotificationCategory.system => Icons.shield_outlined,
        NotificationCategory.creatorActivity => Icons.auto_awesome,
        NotificationCategory.algorithmic => Icons.trending_up_rounded,
      };

  /// Human-readable label for a category.
  static String label(NotificationCategory category) => switch (category) {
        NotificationCategory.social => 'Social',
        NotificationCategory.system => 'System',
        NotificationCategory.creatorActivity => 'Activity',
        NotificationCategory.algorithmic => 'Discovery',
      };
}
