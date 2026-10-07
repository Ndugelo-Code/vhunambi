import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/library_models.dart';
import '../providers/library_providers.dart';
import 'library_badges.dart';
import 'library_cover_art.dart';
import 'track_actions_sheet.dart';

/// Dense vault list row rendering title, creator, duration, genre and the
/// offline/cloud cache indicator (REQ-LIB-05).
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
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
                    Text(
                      '${track.creatorName} • ${track.formattedDuration} • ${track.createdAgoLabel}',
                      style: AppTypography.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SyncStatusBadge(track: track),
              const SizedBox(width: AppSpacing.xxs),
              SizedBox(
                width: 34,
                height: 34,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  tooltip: 'Asset actions',
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textSecondary,
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
