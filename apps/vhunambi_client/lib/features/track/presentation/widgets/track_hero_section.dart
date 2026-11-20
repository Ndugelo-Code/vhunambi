import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/auth/viewer_role.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/utils/responsive_utils.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_glass_surface.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_track_artwork.dart';
import 'package:vhunambi_client/features/track/domain/models/track_detail_models.dart';

/// 1:1 Cover Art Showcase, Metadata & Role-Gated Ownership Callout
/// (`REQ-TRK-02`, `REQ-TRK-03`, `REQ-P70-GATE-01`, `REQ-P70-SCUX-01`).
class TrackHeroSection extends StatelessWidget {
  final TrackDetailEntity track;
  final ViewerRole viewerRole;
  final VoidCallback? onTapCreator;

  const TrackHeroSection({
    super.key,
    required this.track,
    this.viewerRole = ViewerRole.visitor,
    this.onTapCreator,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final artSize = isDesktop ? 280.0 : 220.0;
    final isOwner = viewerRole == ViewerRole.owner;
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        const SizedBox(height: 16),

        // 1:1 Unified Track Artwork with Ambient Glow (`EP-P68-TRACK-ARTWORK`)
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.brandPrimary.withValues(alpha: 0.22),
                blurRadius: 36,
                spreadRadius: -6,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: VhunambiTrackArtwork(
            key: const Key('track_hero_artwork'),
            coverUrl: track.coverUrl,
            genre: track.genre,
            trackId: track.id,
            width: artSize,
            height: artSize,
            borderRadius: BorderRadius.circular(24),
            badgeIconSize: 44,
          ),
        ),

        const SizedBox(height: 22),

        // Track Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            track.title,
            style:
                (isDesktop
                        ? AppTypography.displayMedium
                        : AppTypography.titleLarge)
                    .copyWith(fontWeight: FontWeight.bold, color: textPrimary),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        const SizedBox(height: 6),

        // Metadata Subtitle
        Text(
          track.metadataLabel,
          style: AppTypography.bodySmall.copyWith(
            color: textSecondary,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 12),

        // Creator Link Byline
        InkWell(
          key: const Key('track_hero_creator_link'),
          onTap: onTapCreator,
          borderRadius: AppRadius.pillBorder,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary.withAlpha(30),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.brandPrimary),
                  ),
                  child: Center(
                    child: Text(
                      track.creatorName.isNotEmpty
                          ? track.creatorName[0].toUpperCase()
                          : 'C',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  track.creatorName,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  track.creatorHandle,
                  style: AppTypography.caption.copyWith(color: textSecondary),
                ),
                const SizedBox(width: 4),
                const PhosphorIcon(
                  AppIcons.verified,
                  size: 14,
                  color: AppColors.brandPrimary,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Strict Role-Gated Ownership Deed vs Visitor Provenance Pill (`SC-01`)
        if (isOwner)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: VhunambiGlassSurface(
              key: const Key('track_owner_deed_card'),
              variant: VhunambiGlassVariant.card,
              tintAccent: AppColors.success,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: const BoxConstraints(maxWidth: 480),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const PhosphorIcon(
                    PhosphorIconsFill.shieldCheck,
                    size: 18,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Created by you · ${track.licenseBadge}',
                          style: AppTypography.titleSmall.copyWith(
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          TrackDetailEntity.ownershipNotice,
                          style: AppTypography.caption.copyWith(
                            color: textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          VhunambiGlassSurface(
            key: const Key('track_visitor_provenance_pill'),
            variant: VhunambiGlassVariant.pill,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                PhosphorIcon(
                  track.allowOpenStemsRemix
                      ? PhosphorIconsFill.sparkle
                      : PhosphorIconsFill.lockSimple,
                  size: 15,
                  color: track.allowOpenStemsRemix
                      ? AppColors.brandPrimary
                      : textSecondary,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    track.visitorProvenanceNotice,
                    style: AppTypography.caption.copyWith(
                      color: textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
