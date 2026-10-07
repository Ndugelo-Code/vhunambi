import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/track_detail_models.dart';

/// 5-Glyph Cultural Emoji Reaction Pill Deck (REQ-TRK-06).
class EmojiReactionDeck extends StatelessWidget {
  final TrackDetailEntity track;
  final ValueChanged<String> onToggleReaction;

  const EmojiReactionDeck({
    super.key,
    required this.track,
    required this.onToggleReaction,
  });

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
            final glyph = TrackDetailEntity.reactionGlyphs[key] ?? '✨';
            final count = track.reactions[key] ?? 0;
            final isSelected = track.userReactions.contains(key);

            return InkWell(
              onTap: () => onToggleReaction(key),
              borderRadius: AppRadius.pillBorder,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.brandPrimary.withAlpha(20)
                      : AppColors.surfaceElevated,
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.brandPrimary
                        : AppColors.borderSubtle,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      glyph,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$count',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? AppColors.brandPrimary
                            : AppColors.textPrimary,
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
