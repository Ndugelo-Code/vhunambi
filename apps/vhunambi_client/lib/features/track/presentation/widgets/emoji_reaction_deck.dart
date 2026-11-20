import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_glass_surface.dart';
import 'package:vhunambi_client/features/track/domain/models/track_detail_models.dart';

/// Compact Horizontal Cultural Vector Reaction Rail (`REQ-TRK-06`, `REQ-P70-SCUX-03`).
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
      'fire' => PhosphorIconsFill.flame,
      'love' => PhosphorIconsFill.heart,
      'rhythm' => PhosphorIconsFill.musicNotes,
      'hands' => PhosphorIconsFill.handsClapping,
      'globe' => PhosphorIconsFill.globeHemisphereWest,
      _ => PhosphorIconsFill.sparkle,
    };
  }

  static String getReactionLabel(String key) {
    return switch (key) {
      'fire' => 'Fire',
      'love' => 'Soul',
      'rhythm' => 'Groove',
      'hands' => 'Praise',
      'globe' => 'Pan-African',
      _ => 'Vibe',
    };
  }

  static Color getReactionColor(
    BuildContext context,
    String key,
    bool isSelected,
  ) {
    if (!isSelected) return AppColors.textSecondaryOf(context);
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
    final textPrimary = AppColors.textPrimaryOf(context);
    return Container(
      key: const Key('track_reaction_rail'),
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: TrackDetailEntity.reactionKeys.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final key = TrackDetailEntity.reactionKeys[index];
          final count = track.reactions[key] ?? 0;
          final isSelected = track.userReactions.contains(key);
          final activeColor = getReactionColor(context, key, isSelected);

          return Material(
            color: Colors.transparent,
            child: InkWell(
              key: Key('reaction_$key'),
              onTap: () => onToggleReaction(key),
              borderRadius: AppRadius.pillBorder,
              child: VhunambiGlassSurface(
                variant: VhunambiGlassVariant.pill,
                tintAccent: isSelected ? activeColor : null,
                borderColorOverride: isSelected ? activeColor : null,
                constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    PhosphorIcon(
                      getReactionIcon(key),
                      size: 16,
                      color: activeColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      getReactionLabel(key),
                      style: AppTypography.caption.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isSelected ? activeColor : textPrimary,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        '$count',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? activeColor : textPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
