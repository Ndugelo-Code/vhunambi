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

/// Square vault grid card with overlay badges and a centred play trigger
/// (REQ-LIB-04 / Blueprint 04 §3.2).
class LibraryTrackGridCard extends ConsumerWidget {
  final LibraryTrack track;

  const LibraryTrackGridCard({super.key, required this.track});

  /// Bottom readability scrim derived from the pure-black brand contrast token.
  static final LinearGradient _bottomScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      AppColors.brandContrast.withAlpha(0),
      AppColors.brandContrast.withAlpha(215),
    ],
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.cardBorder,
        child: InkWell(
          onTap: () => playLibraryTrack(ref, track),
          child: Stack(
            fit: StackFit.expand,
            children: [
              LibraryCoverArt(
                track: track,
                size: null,
                radius: 0,
                showGlyph: false,
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: _bottomScrim),
                ),
              ),

              // Overlay badges
              Positioned(
                top: AppSpacing.xs,
                left: AppSpacing.xs,
                right: 40,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GenreBadge(genre: track.genre),
                    const SizedBox(height: AppSpacing.xxs),
                    SyncStatusBadge(track: track),
                  ],
                ),
              ),

              // Contextual overflow trigger
              Positioned(
                top: 2,
                right: 2,
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    tooltip: 'Asset actions',
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: AppColors.textPrimary,
                    ),
                    onPressed: () => TrackActionsSheet.show(context, track),
                  ),
                ),
              ),

              // Play trigger
              Center(
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCanvas.withAlpha(170),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.brandPrimary),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 26,
                    color: AppColors.brandPrimary,
                  ),
                ),
              ),

              // Asset identity
              Positioned(
                left: AppSpacing.xs,
                right: AppSpacing.xs,
                bottom: AppSpacing.xs,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.title,
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${track.creatorName} • ${track.formattedDuration}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
