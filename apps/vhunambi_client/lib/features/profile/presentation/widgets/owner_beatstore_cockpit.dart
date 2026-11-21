import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/auth/auth_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/creator_id_utils.dart';
import '../../../../core/widgets/vhunambi_glass_surface.dart';
import '../../../../core/widgets/vhunambi_track_artwork.dart';
import '../../../beats/domain/models/producer_beat_entity.dart';
import '../../../beats/presentation/providers/beats_provider.dart';
import '../../../beats/presentation/widgets/beat_form_dialog.dart';
import '../../../marketplace/presentation/providers/marketplace_providers.dart';

/// Account Owner Producer Beatstore Cockpit (Phase 30 REQ-PROF-STUDIO-01..05).
/// Syncs between local [beatsProvider] vault and [marketplaceBeatsProvider] listings.
class OwnerBeatstoreCockpit extends ConsumerWidget {
  const OwnerBeatstoreCockpit({super.key});

  void _showNewBeatDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return BeatFormDialog(
          onSubmitted: (result) {
            ref
                .read(beatsProvider.notifier)
                .createBeat(
                  title: result.title,
                  genre: result.genre,
                  bpm: result.bpm,
                  musicalKey: result.musicalKey,
                  tags: result.tags,
                  priceInCredits: result.priceInCredits,
                  licenseTier: result.licenseTier,
                  status: result.status,
                );
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Beat "${result.title}" added to your beatstore!',
                ),
                backgroundColor: AppColors.surfaceElevatedOf(context),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creatorId = canonicalizeCreatorId(
      ref.watch(currentCreatorIdProvider),
    );
    final vaultBeats = ref.watch(beatsProvider);
    final marketBeats = ref.watch(creatorBeatsFamilyProvider(creatorId));

    // Combined unique beat titles/ids
    final totalBeats =
        vaultBeats.length +
        marketBeats
            .where(
              (mb) => !vaultBeats.any(
                (vb) => vb.id == mb.id || vb.title == mb.title,
              ),
            )
            .length;

    final totalSales =
        vaultBeats.fold<int>(0, (sum, b) => sum + b.totalSales) +
        marketBeats.fold<int>(0, (sum, b) => sum + b.totalSales);

    final totalCoins =
        vaultBeats.fold<int>(
          0,
          (sum, b) => sum + (b.totalSales * b.priceInCredits),
        ) +
        marketBeats.fold<int>(
          0,
          (sum, b) => sum + (b.totalSales * b.priceInCredits),
        );
    final grossZar = (totalCoins * 0.9).toStringAsFixed(0);

    return Column(
      key: const Key('owner_beatstore_cockpit'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Performance Summary Deck
        VhunambiGlassSurface(
          variant: VhunambiGlassVariant.card,
          enableLiveBlur: false,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const PhosphorIcon(
                        PhosphorIconsRegular.storefront,
                        color: AppColors.brandPrimary,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Producer Beatstore',
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondaryOf(context),
                      borderRadius: AppRadius.pillBorder,
                      border: Border.all(
                        color: AppColors.borderSubtleOf(context),
                      ),
                    ),
                    child: const Text(
                      '85% Payout Rate',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      context: context,
                      label: 'Beats Listed',
                      value: '$totalBeats',
                      icon: PhosphorIconsRegular.disc,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _buildMetricTile(
                      context: context,
                      label: 'Total Sales',
                      value: '$totalSales',
                      icon: PhosphorIconsRegular.bag,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _buildMetricTile(
                      context: context,
                      label: 'Gross Earned',
                      value: 'R$grossZar',
                      icon: PhosphorIconsRegular.coins,
                      valueColor: AppColors.coinGold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // 2. Action Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Catalog ($totalBeats)',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textPrimaryOf(context),
                fontWeight: FontWeight.bold,
              ),
            ),
            ElevatedButton.icon(
              key: const Key('owner_upload_beat_btn'),
              onPressed: () => _showNewBeatDialog(context, ref),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                foregroundColor: AppColors.brandContrast,
                elevation: 0,
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.pillBorder,
                ),
              ),
              icon: const PhosphorIcon(
                PhosphorIconsBold.plus,
                size: 18,
                color: AppColors.brandContrast,
              ),
              label: const Text(
                'Upload Beat',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.sm),

        // 3. Beat Listings or Empty State
        if (vaultBeats.isEmpty && marketBeats.isEmpty)
          VhunambiGlassSurface(
            key: const Key('owner_beatstore_empty'),
            variant: VhunambiGlassVariant.card,
            enableLiveBlur: false,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                PhosphorIcon(
                  PhosphorIconsRegular.musicNotesSimple,
                  size: 36,
                  color: AppColors.textSecondaryOf(context),
                ),
                const SizedBox(height: 10),
                Text(
                  'No beats in your store yet',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textPrimaryOf(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Upload instrumental productions and stems to earn direct royalties.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else ...[
          // Render vault beats
          for (final beat in vaultBeats) _buildVaultBeatRow(context, beat),

          // Render market beats not already in vault
          for (final mb in marketBeats)
            if (!vaultBeats.any((vb) => vb.id == mb.id || vb.title == mb.title))
              _buildMarketBeatRow(context, mb),
        ],
      ],
    );
  }

  Widget _buildMetricTile({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondaryOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtleOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PhosphorIcon(
                icon,
                size: 14,
                color: AppColors.textSecondaryOf(context),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondaryOf(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: valueColor ?? AppColors.textPrimaryOf(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVaultBeatRow(BuildContext context, ProducerBeatEntity beat) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: VhunambiGlassSurface(
        variant: VhunambiGlassVariant.card,
        enableLiveBlur: false,
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            VhunambiTrackArtwork(
              coverUrl: null,
              genre: beat.genre,
              trackId: beat.id,
              width: 40,
              height: 40,
              borderRadius: AppRadius.thumbBorder,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    beat.title,
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryOf(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${beat.genre} • ${beat.bpm} BPM',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondaryOf(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: beat.status == BeatStatus.published
                              ? AppColors.brandPrimary.withAlpha(40)
                              : AppColors.surfaceSecondaryOf(context),
                          borderRadius: AppRadius.pillBorder,
                        ),
                        child: Text(
                          beat.status.label,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: beat.status == BeatStatus.published
                                ? AppColors.brandPrimary
                                : AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${beat.priceInCredits} Coins',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.coinGold,
                  ),
                ),
                Text(
                  '${beat.totalSales} sales',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketBeatRow(BuildContext context, dynamic mb) {
    final beatId = (mb.id as String?) ?? (mb.title as String);
    final genre = (mb.genre as String?) ?? 'Amapiano';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: VhunambiGlassSurface(
        variant: VhunambiGlassVariant.card,
        enableLiveBlur: false,
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            VhunambiTrackArtwork(
              coverUrl: null,
              genre: genre,
              trackId: beatId,
              width: 40,
              height: 40,
              borderRadius: AppRadius.thumbBorder,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mb.title as String,
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryOf(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$genre • ${mb.bpm} BPM',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${mb.priceInCredits} Coins',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.coinGold,
                  ),
                ),
                Text(
                  '${mb.totalSales} sales',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
