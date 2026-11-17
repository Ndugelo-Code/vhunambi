import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/notification_entity.dart';
import '../../domain/models/notification_enums.dart';

/// Central mapping from [NotificationCategory] and optional `subtype` to its
/// design-token color, Phosphor glyph, rail label, and in-card category pill.
abstract final class NotificationCategoryStyle {
  /// Accent token for a category chip on the top filter rail.
  static Color color(NotificationCategory category) => switch (category) {
    NotificationCategory.social => AppColors.accentElectric, // #8B5CF6 Violet
    NotificationCategory.system => AppColors.coinGold, // #F59E0B Amber Gold
    NotificationCategory.creatorActivity =>
      AppColors.brandPrimary, // #F97316 Ember Orange
    NotificationCategory.algorithmic =>
      AppColors.badgeCyan, // #22D3EE Electric Cyan
  };

  /// Semantic accent for an individual [NotificationEntity], supporting
  /// Emerald Teal (`AppColors.success`) for Creator DNA calibration milestones.
  static Color entityColor(NotificationEntity notification) {
    final sub = notification.subtype?.trim().toLowerCase() ?? '';
    if (sub == 'dna_calibration' || sub == 'dna_milestone') {
      return AppColors.success; // #10B981 Emerald Teal
    }
    if (sub == 'monthly_quota' || sub == 'credits' || sub == 'welcome') {
      return AppColors.coinGold; // #F59E0B Warm Amber Gold
    }
    return color(notification.category);
  }

  /// Phosphor glyph for a category chip (`STD-UIUX-001`).
  static IconData icon(NotificationCategory category) => switch (category) {
    NotificationCategory.social => PhosphorIconsRegular.usersThree,
    NotificationCategory.system => PhosphorIconsRegular.shieldCheck,
    NotificationCategory.creatorActivity => AppIcons.sparkle,
    NotificationCategory.algorithmic => AppIcons.analytics,
  };

  /// Subtype-aware Phosphor glyph for an individual notification card.
  static IconData entityIcon(NotificationEntity notification) {
    final sub = notification.subtype?.trim().toLowerCase() ?? '';
    return switch (sub) {
      'dna_calibration' || 'dna_milestone' => AppIcons.dna,
      'monthly_quota' || 'credits' => AppIcons.coin,
      'welcome' => PhosphorIconsFill.shieldCheck,
      'reel_love' || 'post_like' => AppIcons.heart,
      'repost' => AppIcons.remix,
      'comment' => AppIcons.chat,
      'gift' => AppIcons.coins,
      'follow' => PhosphorIconsFill.userPlus,
      'ar_cosign' => PhosphorIconsFill.fire,
      'license_sold' => AppIcons.coin,
      'studio_render' => AppIcons.songs,
      'reel_render' => AppIcons.reels,
      _ => icon(notification.category),
    };
  }

  /// Human-readable label for a category rail chip.
  static String label(NotificationCategory category) => switch (category) {
    NotificationCategory.social => 'Social',
    NotificationCategory.system => 'System',
    NotificationCategory.creatorActivity => 'Activity',
    NotificationCategory.algorithmic => 'Discovery',
  };

  /// Descriptive pill label rendered inside each notification card.
  static String pillLabel(NotificationEntity notification) {
    final sub = notification.subtype?.trim().toLowerCase() ?? '';
    return switch (sub) {
      'welcome' => 'System • Welcome',
      'dna_calibration' || 'dna_milestone' => 'Creator DNA',
      'monthly_quota' => 'Free Tier Quota',
      'credits' => 'Credits & Plan',
      'studio_render' => 'Studio Render',
      'reel_render' => 'Reel Export',
      'license_sold' => 'Royalty Split',
      'reel_love' => 'Social • Love',
      'post_like' => 'Social • Like',
      'repost' => 'Social • Repost',
      'comment' => 'Social • Comment',
      'gift' => 'Social • Cultural Gift',
      'follow' => 'Social • Follow',
      'ar_cosign' => 'Social • Co-Sign',
      _ => switch (notification.category) {
        NotificationCategory.social => 'Social',
        NotificationCategory.system => 'System',
        NotificationCategory.creatorActivity => 'Studio Activity',
        NotificationCategory.algorithmic => 'Discovery',
      },
    };
  }
}
