import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_glass_surface.dart';
import 'package:vhunambi_client/features/track/domain/models/track_detail_models.dart';

/// Primary Social Engagement Row: Like, Plays, Playlist, Share, Remix, Tip
/// (`REQ-TRK-04`, `REQ-P70-SCUX-02` Light-Mode Safe Contrast).
class TrackActionsBar extends StatelessWidget {
  final TrackDetailEntity track;
  final VoidCallback onToggleLike;
  final VoidCallback? onRemix;
  final VoidCallback? onTip;
  final VoidCallback? onShare;
  final VoidCallback? onAddToPlaylist;

  const TrackActionsBar({
    super.key,
    required this.track,
    required this.onToggleLike,
    this.onRemix,
    this.onTip,
    this.onShare,
    this.onAddToPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final likeColor = track.isLiked ? AppColors.brandPrimary : textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: <Widget>[
          // 1. High-Contrast Like Pill (fixes Light-Mode white-on-white SC-04)
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('track_like_pill'),
              onTap: onToggleLike,
              borderRadius: AppRadius.pillBorder,
              child: VhunambiGlassSurface(
                variant: VhunambiGlassVariant.pill,
                tintAccent: track.isLiked ? AppColors.brandPrimary : null,
                borderColorOverride: track.isLiked
                    ? AppColors.brandPrimary
                    : null,
                constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    PhosphorIcon(
                      track.isLiked
                          ? PhosphorIconsFill.heart
                          : PhosphorIconsRegular.heart,
                      color: likeColor,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${track.likesCount}',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: likeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. Play Count Pill
          VhunambiGlassSurface(
            key: const Key('track_plays_pill'),
            variant: VhunambiGlassVariant.pill,
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                PhosphorIcon(
                  PhosphorIconsRegular.play,
                  color: textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  '${track.playCount}',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // 3. Save to Playlist Pill (optional)
          if (onAddToPlaylist != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('track_playlist_pill'),
                onTap: onAddToPlaylist,
                borderRadius: AppRadius.pillBorder,
                child: VhunambiGlassSurface(
                  variant: VhunambiGlassVariant.pill,
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      PhosphorIcon(
                        AppIcons.playlist,
                        color: textPrimary,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Save',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 4. Share Pill (optional)
          if (onShare != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('track_share_pill'),
                onTap: onShare,
                borderRadius: AppRadius.pillBorder,
                child: VhunambiGlassSurface(
                  variant: VhunambiGlassVariant.pill,
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      PhosphorIcon(
                        AppIcons.share,
                        color: textPrimary,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Share',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 5. Remix Pill (mounted only for owners or open-stems tracks)
          if (onRemix != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('track_remix_pill'),
                onTap: onRemix,
                borderRadius: AppRadius.pillBorder,
                child: VhunambiGlassSurface(
                  variant: VhunambiGlassVariant.pill,
                  tintAccent: AppColors.brandPrimary,
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const PhosphorIcon(
                        PhosphorIconsRegular.shuffle,
                        color: AppColors.brandPrimary,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Remix',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 6. Tip Creator Pill (Gold/Amber)
          if (onTip != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('track_tip_pill'),
                onTap: onTip,
                borderRadius: AppRadius.pillBorder,
                child: VhunambiGlassSurface(
                  variant: VhunambiGlassVariant.pill,
                  tintAccent: AppColors.coinGold,
                  borderColorOverride: AppColors.coinGold.withValues(
                    alpha: 0.45,
                  ),
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const PhosphorIcon(
                        PhosphorIconsRegular.coin,
                        color: AppColors.coinGold,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Tip',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.coinGold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
