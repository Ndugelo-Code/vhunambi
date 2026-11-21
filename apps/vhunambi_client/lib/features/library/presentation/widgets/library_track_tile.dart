import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/vhunambi_glass_surface.dart';
import '../../domain/models/library_models.dart';
import '../providers/library_providers.dart';
import 'library_badges.dart';
import 'library_cover_art.dart';
import 'track_actions_sheet.dart';

/// Dense glass vault list row rendering title, creator, duration, genre and the
/// offline/cloud cache indicator (`REQ-LIB-05`, `REQ-P72-AV-04`, `enableLiveBlur: false`).
class LibraryTrackTile extends ConsumerWidget {
  final LibraryTrack track;
  final bool showGenreBadge;

  const LibraryTrackTile({
    super.key,
    required this.track,
    this.showGenreBadge = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return VhunambiGlassSurface(
      variant: VhunambiGlassVariant.card,
      enableLiveBlur: false,
      child: InkWell(
        onTap: () => playLibraryTrack(ref, track),
        borderRadius: AppRadius.cardBorder,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              LibraryCoverArt(track: track, size: 48),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            track.title,
                            style: AppTypography.bodyLarge.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryOf(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (showGenreBadge) ...[
                          const SizedBox(width: AppSpacing.xs),
                          GenreBadge(genre: track.genre),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            showGenreBadge
                                ? '${track.creatorName} • ${track.formattedDuration} • ${track.createdAgoLabel}'
                                : '${track.creatorName} • ${track.formattedDuration} • ${track.playCountLabel}',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondaryOf(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (showGenreBadge) ...[
                          const SizedBox(width: AppSpacing.xs),
                          PhosphorIcon(
                            PhosphorIconsRegular.headphones,
                            size: 12,
                            color: AppColors.textSecondaryOf(context),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            track.playCountLabel,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondaryOf(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SyncStatusBadge(track: track),
              const SizedBox(width: AppSpacing.xxs),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  tooltip: track.isFavorite
                      ? 'Remove from favourites'
                      : 'Add to favourites',
                  icon: PhosphorIcon(
                    track.isFavorite
                        ? PhosphorIconsFill.heart
                        : PhosphorIconsRegular.heart,
                    size: 18,
                    color: track.isFavorite
                        ? AppColors.brandPrimary
                        : AppColors.textSecondaryOf(context),
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    ref
                        .read(libraryTracksProvider.notifier)
                        .toggleFavorite(track.id);
                  },
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  tooltip: 'Asset actions',
                  icon: PhosphorIcon(
                    PhosphorIconsRegular.dotsThreeVertical,
                    size: 18,
                    color: AppColors.textSecondaryOf(context),
                  ),
                  onPressed: () => TrackActionsSheet.show(context, track),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
