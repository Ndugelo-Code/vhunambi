import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../content_studio/presentation/providers/content_studio_provider.dart';
import '../../../content_studio/presentation/widgets/publish_clip_modal.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../domain/models/published_clip.dart';
import '../providers/trending_reels_provider.dart';
import 'kinetic_reels_modal.dart';
import 'remix_attribution_badge.dart';

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
                    if (clip.isRemix) ...[
                      const SizedBox(height: 3),
                      RemixAttributionBadge(clip: clip),
                    ],
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

/// Facebook Stories-Style Card #0: Allows user to pick a library track and post a reel (REQ-EXP-REEL-RAIL-01..03).
class _PostKineticReelCard extends StatelessWidget {
  final VoidCallback onTap;

  const _PostKineticReelCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final width = isDesktop ? 160.0 : 140.0;

    return GestureDetector(
      key: const Key('explore_post_kinetic_reel_card'),
      onTap: onTap,
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: AppSpacing.sm),
        decoration: BoxDecoration(
          borderRadius: AppRadius.cardBorder,
          border: Border.all(
            color: AppColors.brandPrimary.withValues(alpha: 0.5),
            width: 1.5,
          ),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.surfaceElevated,
              AppColors.surfaceCanvas,
            ],
          ),
        ),
        child: ClipRRect(
          borderRadius: AppRadius.cardBorder,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borderSubtle, width: 2),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 28,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: AppColors.brandPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: AppColors.brandContrast,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Post Reel',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Share creation',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal discovery shelf of trending kinetic reels with Facebook Stories-style
/// Card #0 [ ➕ Post Reel ] (REQ-TRD-01 / REQ-EXP-REEL-RAIL-01..04).
class TrendingReelsShelf extends ConsumerWidget {
  const TrendingReelsShelf({super.key});

  void _showPostReelSheet(BuildContext context, WidgetRef ref) {
    final libraryTracks = ref.read(libraryTracksProvider);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceModal,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        if (libraryTracks.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.music_off_rounded,
                  size: 48,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'No Tracks in Vault',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Generate or upload a song in Studio to create your first reel.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: AppColors.brandContrast,
                  ),
                  child: const Text('Got it'),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Track for Reel',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Choose a track from your library vault to publish as a 60 FPS kinetic reel.',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: libraryTracks.length,
                  itemBuilder: (c, idx) {
                    final track = libraryTracks[idx];
                    return ListTile(
                      key: Key('post_reel_track_${track.id}'),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: AppRadius.thumbBorder,
                        ),
                        child: const Icon(
                          Icons.audiotrack_rounded,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                      title: Text(track.title),
                      subtitle: Text('${track.genre} • ${track.creatorName}'),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        ref.read(contentStudioProvider.notifier).initializeWithDna(
                              dna: track.toSongMetadataDna(),
                              audioUrl: track.remoteAudioUrl,
                              coverArtUrl: track.coverImageUrl ?? '',
                            );
                        PublishClipModal.show(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reels = ref.watch(trendingReelsProvider);
    final activeGenre = ref.watch(trendingReelsGenreProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Micro-Header
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: AppColors.brandPrimary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Kinetic Reels',
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                key: const Key('trending_view_all'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(44, 36),
                ),
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

        // Compact Genre filter pills
        SizedBox(
          height: 36,
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

        // Horizontal Stories-style Reel Rail: Card #0 is [ ➕ Post Reel ]
        SizedBox(
          height: 260,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: reels.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return _PostKineticReelCard(
                  onTap: () => _showPostReelSheet(context, ref),
                );
              }
              final reelIndex = i - 1;
              return TrendingReelCard(
                clip: reels[reelIndex],
                reels: reels,
                index: reelIndex,
              );
            },
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
