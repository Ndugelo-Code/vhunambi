import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/services/haptics_service.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_track_artwork.dart';
import 'package:vhunambi_client/features/player/presentation/providers/player_provider.dart';
import 'package:vhunambi_client/shared/models/track.dart';

/// Zone 3: Horizontal square-artwork track carousel (`REQ-P68-FEED-03`, `REQ-P68-FEED-04`).
class HorizontalGenreTrackShelf extends ConsumerWidget {
  final List<Track> tracks;
  final List<String> selectedGenres;
  final VoidCallback? onViewAll;

  const HorizontalGenreTrackShelf({
    super.key,
    required this.tracks,
    required this.selectedGenres,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayed = tracks.take(8).toList();
    final activeTrackId = ref.watch(
      playerStateProvider.select((s) => s.currentTrack?.id),
    );
    final isPlaying = ref.watch(
      playerStateProvider.select((s) => s.isPlaying),
    );

    return Column(
      key: const Key('home_trending_genres_shelf'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Trending in Your Genres',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.textPrimaryOf(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      selectedGenres.isNotEmpty
                          ? selectedGenres.take(2).join(' • ')
                          : 'All Regional Genres',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const Key('home_trending_view_all_btn'),
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  foregroundColor: AppColors.brandPrimary,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'View all',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const PhosphorIcon(
                      PhosphorIconsBold.caretRight,
                      size: 13,
                      color: AppColors.brandPrimary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: displayed.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final track = displayed[index];
              final isSelected = activeTrackId == track.id;
              return GestureDetector(
                key: Key('home_trending_track_${track.id}'),
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  HapticsService().lightImpact();
                  ref
                      .read(playerStateProvider.notifier)
                      .playTrack(track, queue: displayed);
                },
                child: SizedBox(
                  width: 148,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Stack(
                        children: <Widget>[
                          VhunambiTrackArtwork(
                            coverUrl: track.coverUrl,
                            genre: track.genre,
                            trackId: track.id,
                            width: 148,
                            height: 148,
                            borderRadius: AppRadius.cardBorder,
                          ),
                          Positioned(
                            left: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.68),
                                borderRadius: AppRadius.pillBorder,
                              ),
                              child: Text(
                                track.genre,
                                style: AppTypography.badge.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.brandPrimary
                                    : Colors.black.withValues(alpha: 0.72),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: PhosphorIcon(
                                  isSelected && isPlaying
                                      ? PhosphorIconsFill.pause
                                      : PhosphorIconsFill.play,
                                  size: 14,
                                  color: isSelected
                                      ? AppColors.brandContrast
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: isSelected
                              ? AppColors.brandPrimary
                              : AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        track.handleLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
