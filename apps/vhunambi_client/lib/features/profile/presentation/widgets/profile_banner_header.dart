import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/design_system/tokens/app_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/utils/responsive_utils.dart';
import 'package:vhunambi_client/features/profile/domain/models/profile_models.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/loading/async_image_with_fallback.dart';

/// Ambient Cover Banner, Monogram Avatar & High-Contrast Visitor Action Strip
/// (`REQ-TRK-12`, `REQ-P70-PROF-01..03`, `STD-UIUX-001`).
class ProfileBannerHeader extends StatelessWidget {
  final ArtistProfileEntity profile;
  final VoidCallback onToggleFollow;
  final VoidCallback? onTipArtist;
  final VoidCallback? onShare;
  final VoidCallback? onReport;
  final VoidCallback? onOpenOverflowMenu;

  const ProfileBannerHeader({
    super.key,
    required this.profile,
    required this.onToggleFollow,
    this.onTipArtist,
    this.onShare,
    this.onReport,
    this.onOpenOverflowMenu,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final bannerHeight = isDesktop ? 180.0 : 140.0;
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final surfaceSecondary = AppColors.surfaceSecondaryOf(context);
    final borderSubtle = AppColors.borderSubtleOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // 1. Ambient Cover Banner with Phosphor Musical Watermark Glyphs
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Container(
              height: bannerHeight,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.2, -0.6),
                  radius: 1.2,
                  colors: <Color>[
                    Color(0xFF78350F),
                    Color(0xFF2E1505),
                    Color(0xFF141418),
                  ],
                ),
              ),
              child: Stack(
                children: <Widget>[
                  Positioned(
                    right: 40,
                    top: 20,
                    child: PhosphorIcon(
                      AppIcons.piano,
                      size: 80,
                      color: Colors.white.withAlpha(15),
                    ),
                  ),
                  Positioned(
                    left: 60,
                    top: 30,
                    child: PhosphorIcon(
                      AppIcons.releases,
                      size: 60,
                      color: Colors.white.withAlpha(15),
                    ),
                  ),
                  Positioned(
                    right: 180,
                    bottom: 20,
                    child: PhosphorIcon(
                      AppIcons.waveform,
                      size: 70,
                      color: Colors.white.withAlpha(12),
                    ),
                  ),
                ],
              ),
            ),

            // 2. 84px Overlapping Avatar with Canvas Cutout Ring
            Positioned(
              bottom: -42,
              left: isDesktop ? 32 : 16,
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.surfaceCanvasOf(context),
                    width: 4,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withAlpha(110),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: AsyncImageWithFallback(
                  imageUrl: profile.avatarUrl,
                  monogram: profile.monogram,
                  size: 76,
                  borderRadius: BorderRadius.circular(38),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 52),

        // 3. Creator Identity Details
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    profile.displayName,
                    style:
                        (isDesktop
                                ? AppTypography.displayMedium
                                : AppTypography.titleLarge)
                            .copyWith(
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                  ),
                  if (profile.isVerified)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A8A).withAlpha(60),
                        borderRadius: AppRadius.pillBorder,
                        border: Border.all(color: const Color(0xFF3B82F6)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          PhosphorIcon(
                            PhosphorIconsFill.sealCheck,
                            size: 14,
                            color: Color(0xFF60A5FA),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Verified Artist',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF60A5FA),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '@${profile.username}',
                style: AppTypography.caption.copyWith(
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: <Widget>[
                  Container(
                    key: const Key('creator_archetype_badge'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: surfaceSecondary,
                      borderRadius: AppRadius.pillBorder,
                      border: Border.all(
                        color: AppColors.brandPrimary.withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        PhosphorIcon(
                          profile.archetype.icon,
                          size: 12,
                          color: AppColors.brandPrimary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          profile.archetype.displayName,
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 10.5,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    key: const Key('creator_monthly_listeners_pill'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: surfaceSecondary,
                      borderRadius: AppRadius.pillBorder,
                      border: Border.all(color: borderSubtle, width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const PhosphorIcon(
                          PhosphorIconsRegular.headphones,
                          size: 12,
                          color: AppColors.badgeCyan,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${(profile.monthlyListenersCount / 1000).toStringAsFixed(1)}K Monthly',
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 10.5,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (profile.bio.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  profile.bio,
                  style: AppTypography.bodySmall.copyWith(
                    color: textPrimary,
                    height: 1.4,
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // 4. High-Contrast Action Strip (Instant Follow + Tip + [ ••• ] Overflow)
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Semantics(
                    label: profile.isFollowing
                        ? 'Unfollow ${profile.displayName}'
                        : 'Follow ${profile.displayName}',
                    button: true,
                    child: ElevatedButton(
                      key: const Key('profile_follow_btn'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(124, 44),
                        backgroundColor: profile.isFollowing
                            ? surfaceSecondary
                            : AppColors.brandPrimary,
                        foregroundColor: profile.isFollowing
                            ? textPrimary
                            : AppColors.brandContrast,
                        side: profile.isFollowing
                            ? BorderSide(color: borderSubtle, width: 1.2)
                            : BorderSide.none,
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.pillBorder,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        elevation: 0,
                      ),
                      onPressed: onToggleFollow,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          PhosphorIcon(
                            profile.isFollowing
                                ? AppIcons.check
                                : AppIcons.plus,
                            size: 16,
                            color: profile.isFollowing
                                ? textPrimary
                                : AppColors.brandContrast,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            profile.isFollowing ? 'Following' : 'Follow',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: profile.isFollowing
                                  ? textPrimary
                                  : AppColors.brandContrast,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (profile.tipsEnabled)
                    Semantics(
                      label: 'Tip ${profile.displayName} with credits',
                      button: true,
                      child: ElevatedButton.icon(
                        key: const Key('profile_tip_artist_btn'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          backgroundColor: surfaceSecondary,
                          foregroundColor: AppColors.coinGold,
                          side: BorderSide(
                            color: AppColors.coinGold.withValues(alpha: 0.45),
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.pillBorder,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          elevation: 0,
                        ),
                        onPressed: onTipArtist,
                        icon: const PhosphorIcon(AppIcons.coin, size: 18),
                        label: const Text(
                          'Tip Artist',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                  if (onOpenOverflowMenu != null)
                    Semantics(
                      label: 'More actions for ${profile.displayName}',
                      button: true,
                      child: IconButton(
                        key: const Key('visitor_profile_overflow_btn'),
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: surfaceSecondary,
                          foregroundColor: textPrimary,
                          side: BorderSide(color: borderSubtle),
                        ),
                        icon: PhosphorIcon(
                          AppIcons.dotsHorizontal,
                          size: 18,
                          color: textPrimary,
                        ),
                        onPressed: onOpenOverflowMenu,
                      ),
                    )
                  else ...<Widget>[
                    if (onShare != null)
                      IconButton(
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: surfaceSecondary,
                          foregroundColor: textPrimary,
                          side: BorderSide(color: borderSubtle),
                        ),
                        icon: PhosphorIcon(
                          AppIcons.share,
                          size: 18,
                          color: textPrimary,
                        ),
                        onPressed: onShare,
                      ),
                    if (onReport != null)
                      IconButton(
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: surfaceSecondary,
                          side: BorderSide(color: borderSubtle),
                        ),
                        icon: PhosphorIcon(
                          PhosphorIconsRegular.flag,
                          size: 18,
                          color: textSecondary,
                        ),
                        onPressed: onReport,
                      ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
