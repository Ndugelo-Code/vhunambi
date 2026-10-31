import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/track_detail_models.dart';

/// 5-Glyph Cultural Vector Reaction Pill Deck (REQ-TRK-06 / STD-UIUX-001).
class EmojiReactionDeck extends StatelessWidget {
  final TrackDetailEntity track;
  final ValueChanged<String> onToggleReaction;

  const EmojiReactionDeck({
    super.key,
    required this.track,
    required this.onToggleReaction,
  });

  static IconData getReactionIcon(String key) {
    return switch (key) {
      'fire' => PhosphorIconsRegular.fire,
      'love' => PhosphorIconsRegular.heart,
      'rhythm' => PhosphorIconsRegular.musicNotes,
      'hands' => PhosphorIconsRegular.handsClapping,
      'globe' => PhosphorIconsRegular.globeHemisphereWest,
      _ => PhosphorIconsRegular.sparkle,
    };
  }

  static Color getReactionColor(String key, bool isSelected) {
    if (!isSelected) return AppColors.textSecondary;
    return switch (key) {
      'fire' => AppColors.brandPrimary,
      'love' => AppColors.error,
      'rhythm' => AppColors.accentElectric,
      'hands' => AppColors.coinGold,
      'globe' => AppColors.badgeCyan,
      _ => AppColors.brandPrimary,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: TrackDetailEntity.reactionKeys.map((key) {
            final count = track.reactions[key] ?? 0;
            final isSelected = track.userReactions.contains(key);
            final activeColor = getReactionColor(key, isSelected);

            return InkWell(
              key: Key('reaction_$key'),
              onTap: () => onToggleReaction(key),
              borderRadius: AppRadius.pillBorder,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withAlpha(25)
                      : AppColors.surfaceElevated,
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(
                    color: isSelected ? activeColor : AppColors.borderSubtle,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PhosphorIcon(
                      getReactionIcon(key),
                      size: 18,
                      color: activeColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$count',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? activeColor : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
