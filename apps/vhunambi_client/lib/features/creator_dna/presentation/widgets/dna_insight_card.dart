import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/creator_dna_profile.dart';
import '../providers/creator_dna_provider.dart';
import 'dna_genre_badge.dart';
import 'dna_strength_meter.dart';

/// Card displayed on the home dashboard highlighting the user's active Creator DNA strength,
/// signature genre badges, and contextual cultivation tips.
class DnaInsightCard extends ConsumerWidget {
  final bool animatedMeter;

  const DnaInsightCard({
    super.key,
    this.animatedMeter = true,
  });

  static String tipTextFor(CreatorDnaProfile dna) {
    final topGenre = dna.topGenres(1).firstOrNull ?? 'African music';
    return switch (dna.lifecycleState) {
      DnaLifecycleState.seeded => 'Keep exploring to grow your DNA',
      DnaLifecycleState.learning => 'Play more $topGenre to strengthen your profile',
      DnaLifecycleState.calibrated => 'Your DNA is shaping your studio defaults ✨',
      DnaLifecycleState.attuned => 'Vhunambi knows your sound 🎯',
      DnaLifecycleState.uninitialized => 'Complete onboarding to activate your DNA',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dna = ref.watch(creatorDnaProvider);

    if (dna.dnaInsightCardDismissed) {
      return const SizedBox.shrink();
    }

    final top2 = dna.topGenres(2);
    final tip = tipTextFor(dna);

    return Container(
      key: const Key('dna_insight_card'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with title & dismiss
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🧬', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Your Creator DNA',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                key: const Key('dna_insight_card_dismiss_button'),
                icon: Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                padding: EdgeInsets.zero,
                tooltip: 'Dismiss DNA Insight',
                onPressed: () {
                  ref.read(creatorDnaProvider.notifier).dismissInsightCard();
                },
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          // Strength meter & percent label
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DNA Strength',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
              ),
              Text(
                '${dna.strengthPercent}%',
                style: AppTypography.caption.copyWith(
                  color: DnaStrengthMeter.zoneColor(dna.strengthPercent),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          DnaStrengthMeter(
            strengthPercent: dna.strengthPercent,
            animated: animatedMeter,
          ),

          const SizedBox(height: AppSpacing.md),

          // Top genre badges row & tip
          if (top2.isNotEmpty) ...[
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                DnaGenreBadge(genre: top2[0], rank: 1),
                if (top2.length > 1) DnaGenreBadge(genre: top2[1], rank: 2),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          // Contextual tip
          Text(
            tip,
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
