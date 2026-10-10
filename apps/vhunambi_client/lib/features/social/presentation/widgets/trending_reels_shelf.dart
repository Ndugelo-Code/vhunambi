import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../domain/models/published_clip.dart';
import '../providers/trending_reels_provider.dart';
import 'kinetic_reels_modal.dart';

/// A single 9:16 trending reel card for the horizontal discovery shelf
/// (REQ-TRD-01). Image-only — tapping opens the zero-video reels feed.
class TrendingReelCard extends StatelessWidget {
  final PublishedClip clip;
  final List<PublishedClip> reels;
  final int index;

  const TrendingReelCard({
    super.key,
    required this.clip,
    required this.reels,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final width = isDesktop ? 160.0 : 140.0;

    return GestureDetector(
      key: ValueKey('trending_card_${clip.id}'),
      onTap: () => KineticReelsModal.show(
        context,
        clips: reels,
        initialClipId: clip.id,
      ),
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: AppSpacing.sm),
        decoration: BoxDecoration(
          borderRadius: AppRadius.cardBorder,
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: ClipRRect(
          borderRadius: AppRadius.cardBorder,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration:
                    BoxDecoration(gradient: AppGradients.forGenre(clip.genre)),
              ),
              if (clip.coverUrl.isNotEmpty)
                Image.network(
                  clip.coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                    stops: [0.35, 1.0],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    Row(
                      children: [
                        _Avatar(username: clip.creatorUsername, size: 22),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            '@${clip.creatorUsername}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (clip.isCreatorVerified) ...[
                          const SizedBox(width: 3),
                          const Icon(Icons.verified_rounded,
                              color: AppColors.brandPrimary, size: 13),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      clip.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          const Icon(Icons.play_arrow_rounded,
                              size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 2),
                          Text(formatLikes(clip.playCount),
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.textSecondary)),
                          const SizedBox(width: 8),
                          const Icon(Icons.favorite_rounded,
                              size: 13, color: AppColors.brandPrimary),
                          const SizedBox(width: 2),
                          Text(formatLikes(clip.likeCount),
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String username;
  final double size;
  const _Avatar({required this.username, required this.size});

  @override
  Widget build(BuildContext context) {
    final initial =
        username.isNotEmpty ? username[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.brandPrimary,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AppTypography.caption.copyWith(
          color: AppColors.brandContrast,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Horizontal discovery shelf of trending kinetic reels (REQ-TRD-01 / REQ-TRD-04).
///
/// Mounted in Explore and Home. Reads the virality-sorted [trendingReelsProvider]
/// and filters via [trendingReelsGenreProvider].
class TrendingReelsShelf extends ConsumerWidget {
  const TrendingReelsShelf({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reels = ref.watch(trendingReelsProvider);
    final activeGenre = ref.watch(trendingReelsGenreProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department_rounded,
                  color: AppColors.brandPrimary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trending Kinetic Reels 🎬',
                        style: AppTypography.titleMedium
                            .copyWith(fontWeight: FontWeight.bold)),
                    Text('Discover African Creators',
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              TextButton(
                key: const Key('trending_view_all'),
                onPressed: () => KineticReelsModal.show(context, clips: reels),
                child: Text(
                  'View all ->',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.brandPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Genre filter pills
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: kTrendingGenres.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
            itemBuilder: (context, i) {
              final genre = kTrendingGenres[i];
              final isActive = genre == activeGenre;
              return _GenrePill(
                label: genre,
                isActive: isActive,
                onTap: () => ref
                    .read(trendingReelsGenreProvider.notifier)
                    .state = genre,
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Horizontal reel list
        SizedBox(
          height: 260,
          child: reels.isEmpty
              ? const Center(child: Text('No trending reels yet'))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  itemCount: reels.length,
                  itemBuilder: (context, i) => TrendingReelCard(
                    clip: reels[i],
                    reels: reels,
                    index: i,
                  ),
                ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

class _GenrePill extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _GenrePill(
      {required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('trending_genre_$label'),
      onTap: onTap,
      borderRadius: AppRadius.pillBorder,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isActive ? AppColors.brandPrimary : AppColors.surfaceSecondary,
          borderRadius: AppRadius.pillBorder,
          border: Border.all(
            color: isActive ? AppColors.brandPrimary : AppColors.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: isActive ? AppColors.brandContrast : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
