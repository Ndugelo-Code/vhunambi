import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../explore/presentation/widgets/genre_glyph.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../domain/models/marketplace_models.dart';
import '../providers/marketplace_providers.dart';

/// Marketplace beat listing card: gradient artwork, BPM/key badges, audition
/// trigger, producer tag, credit price and licensing CTA (REQ-MKT-03).
class BeatCard extends ConsumerWidget {
  final BeatListingEntity beat;
  final VoidCallback? onLicenseRequested;

  const BeatCard({super.key, required this.beat, this.onLicenseRequested});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `select` keeps this card off the playback-position rebuild path.
    final isCurrent = ref.watch(
      playerStateProvider.select((s) => s.currentTrack?.id == beat.id),
    );
    final isPlaying = ref.watch(
      playerStateProvider
          .select((s) => s.isPlaying && s.currentTrack?.id == beat.id),
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(
          color: isCurrent ? AppColors.brandPrimary : AppColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _artwork(ref, isPlaying)),
          const SizedBox(height: 6),
          _identity(),
          const SizedBox(height: AppSpacing.xxs),
          _footer(),
        ],
      ),
    );
  }

  Widget _artwork(WidgetRef ref, bool isPlaying) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.input),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppGradients.forGenre(beat.genre),
              ),
            ),
            Center(
              child: Icon(
                exploreGenreGlyph(beat.genre),
                size: 32,
                color: AppColors.textPrimary.withAlpha(230),
              ),
            ),
            Positioned(
              top: AppSpacing.xxs + 2,
              left: AppSpacing.xxs + 2,
              child: _Badge(label: beat.bpmLabel),
            ),
            Positioned(
              top: AppSpacing.xxs + 2,
              right: AppSpacing.xxs + 2,
              child: _Badge(label: beat.musicalKey),
            ),
            Center(
              child: InkWell(
                onTap: () => auditionBeat(ref, beat),
                borderRadius: AppRadius.pillBorder,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.brandPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: PhosphorIcon(
                    isPlaying ? AppIcons.pause : AppIcons.play,
                    size: 20,
                    color: AppColors.brandContrast,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _identity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          beat.title,
          style: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Flexible(
              child: Text(
                beat.producerHandle,
                style: AppTypography.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.xxs),
            const PhosphorIcon(
              AppIcons.verified,
              size: 12,
              color: AppColors.badgeCyan,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          '${beat.genre} • ${beat.totalSales} sales',
          style: AppTypography.caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _footer() {
    return Row(
      children: [
        Expanded(
          child: Text(
            beat.priceLabel,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.brandPrimary,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.xxs),
        OutlinedButton(
          onPressed: onLicenseRequested,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.brandPrimary,
            side: const BorderSide(color: AppColors.brandPrimary),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 4,
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.pillBorder,
            ),
          ),
          child: Text(
            'License Beat',
            style: AppTypography.caption.copyWith(
              color: AppColors.brandPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Semi-transparent dark squircle badge used for the BPM and key chips.
class _Badge extends StatelessWidget {
  final String label;

  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceCanvas.withAlpha(190),
        borderRadius: AppRadius.squircleBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        label,
        style: AppTypography.badge.copyWith(color: AppColors.textPrimary),
      ),
    );
  }
}
