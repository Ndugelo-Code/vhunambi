import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/creator_dna_provider.dart';
import '../../domain/entities/creator_dna_profile.dart';
import 'dna_genre_badge.dart';
import 'dna_strength_meter.dart';

/// Full-fidelity Creator DNA card rendered in Owner and Artist profiles,
/// showcasing sound signature metrics, genre affinities, on-device privacy status,
/// and self-sovereign reset controls.
class CreatorDnaProfileCard extends ConsumerWidget {
  final bool isOwner;
  final CreatorDnaProfile? customDna;

  const CreatorDnaProfileCard({super.key, this.isOwner = true, this.customDna});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CreatorDnaProfile dna =
        customDna ?? ref.watch(creatorDnaProvider);

    return Container(
      key: const Key('creator_dna_profile_card'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Text('🧬', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        'Creator DNA',
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Text(
                  dna.lifecycleState.name.toUpperCase(),
                  style: AppTypography.caption.copyWith(
                    color: DnaStrengthMeter.zoneColor(dna.strengthPercent),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // Strength & Meter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Sound Signature Attunement',
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${dna.strengthPercent}%',
                style: AppTypography.bodySmall.copyWith(
                  color: DnaStrengthMeter.zoneColor(dna.strengthPercent),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          DnaStrengthMeter(strengthPercent: dna.strengthPercent),

          const SizedBox(height: AppSpacing.md),

          // Top Genres
          if (dna.genreWeights.isNotEmpty) ...[
            Text(
              'Affinities & Heritage',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: dna.topGenres(4).asMap().entries.map((entry) {
                return DnaGenreBadge(genre: entry.value, rank: entry.key + 1);
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Sound signature specs
          Row(
            children: [
              Expanded(
                child: _buildSpecTile(
                  'Rhythm',
                  dna.tempoPreference.toUpperCase(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildSpecTile(
                  'Vocal Energy',
                  dna.vocalEnergyPreference.toUpperCase(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _buildSpecTile('Language', dna.primaryLanguage)),
            ],
          ),

          if (isOwner) ...[
            const SizedBox(height: AppSpacing.md),
            Divider(color: AppColors.borderSubtle),
            const SizedBox(height: AppSpacing.xs),

            // Privacy Guarantee & Reset Action
            Row(
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 14,
                  color: AppColors.success,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Stored 100% locally on your device',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                    ),
                  ),
                ),
                TextButton(
                  key: const Key('reset_dna_button'),
                  onPressed: () => _confirmReset(context, ref),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    'Reset DNA',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpecTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surfaceModal,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardBorder,
          side: BorderSide(color: AppColors.borderSubtle),
        ),
        title: const Text(
          'Reset Creator DNA?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This will erase your on-device taste weights, prompt pre-fills, and telemetry log. This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            key: const Key('confirm_reset_dna_button'),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              await ref.read(creatorDnaProvider.notifier).resetDna();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Creator DNA has been reset to defaults'),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
