import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/vhunambi_glass_surface.dart';
import '../../domain/models/library_models.dart';
import '../providers/library_providers.dart';
import 'library_badges.dart';
import 'library_cover_art.dart';
import 'track_actions_sheet.dart';

/// Square glass vault grid card with overlay badges and a centred play trigger
/// (`REQ-LIB-04`, `REQ-P72-AV-04`, `enableLiveBlur: false`).
class LibraryTrackGridCard extends ConsumerWidget {
  final LibraryTrack track;

  const LibraryTrackGridCard({super.key, required this.track});

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
    return VhunambiGlassSurface(
      variant: VhunambiGlassVariant.card,
      enableLiveBlur: false,
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
                right: 48,
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

              // Contextual overflow trigger (44x44dp target)
              Positioned(
                top: 0,
                right: 0,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    tooltip: 'Asset actions',
                    icon: const PhosphorIcon(
                      PhosphorIconsRegular.dotsThreeVertical,
                      size: 18,
                      color: AppColors.darkTextPrimary,
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
                    color: AppColors.surfaceCanvasOf(context).withAlpha(185),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.brandPrimary),
                  ),
                  child: const Center(
                    child: PhosphorIcon(
                      AppIcons.play,
                      size: 22,
                      color: AppColors.brandPrimary,
                    ),
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
                        color: AppColors.darkTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${track.creatorName} • ${track.formattedDuration}',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.darkTextSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        const PhosphorIcon(
                          PhosphorIconsRegular.headphones,
                          size: 11,
                          color: AppColors.darkTextSecondary,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          track.playCountLabel,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.darkTextSecondary,
                          ),
                        ),
                      ],
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
