import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../domain/models/profile_models.dart';
import 'loading/async_image_with_fallback.dart';

/// Ambient Cover Banner, Monogram Avatar & Artist Action Strip (REQ-TRK-12).
class ProfileBannerHeader extends StatelessWidget {
  final ArtistProfileEntity profile;
  final VoidCallback onToggleFollow;
  final VoidCallback? onTipArtist;
  final VoidCallback? onShare;
  final VoidCallback? onReport;

  const ProfileBannerHeader({
    super.key,
    required this.profile,
    required this.onToggleFollow,
    this.onTipArtist,
    this.onShare,
    this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final bannerHeight = isDesktop ? 180.0 : 140.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Ambient Cover Banner with Musical Watermark Glyphs
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: bannerHeight,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.2, -0.6),
                  radius: 1.2,
                  colors: [
                    Color(0xFF78350F), // Bronze-amber
                    Color(0xFF2E1505),
                    Color(0xFF141418), // Surface canvas
                  ],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: 40,
                    top: 20,
                    child: Icon(
                      Icons.piano_rounded,
                      size: 80,
                      color: Colors.white.withAlpha(15),
                    ),
                  ),
                  Positioned(
                    left: 60,
                    top: 30,
                    child: Icon(
                      Icons.album_rounded,
                      size: 60,
                      color: Colors.white.withAlpha(15),
                    ),
                  ),
                  Positioned(
                    right: 180,
                    bottom: 20,
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      size: 70,
                      color: Colors.white.withAlpha(12),
                    ),
                  ),
                ],
              ),
            ),

            // 2. 84px AsyncImageWithFallback Avatar with 4px Cutout Border
            Positioned(
              bottom: -42,
              left: isDesktop ? 32 : 16,
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.surfaceCanvas,
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(120),
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

        // 3. Artist Identity Details
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    profile.displayName,
                    style: (isDesktop
                            ? AppTypography.displayMedium
                            : AppTypography.titleLarge)
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (profile.isVerified) ...[
                    const SizedBox(width: 8),
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
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 14,
                            color: Color(0xFF3B82F6),
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
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '@${profile.username}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (profile.bio.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  profile.bio,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // 4. Action Strip
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  // Follow / Following Button
                  Semantics(
                    label: profile.isFollowing
                        ? 'Unfollow ${profile.displayName}'
                        : 'Follow ${profile.displayName}',
                    button: true,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: profile.isFollowing
                            ? AppColors.surfaceElevated
                            : AppColors.brandPrimary,
                        foregroundColor: profile.isFollowing
                            ? Colors.white
                            : AppColors.brandContrast,
                        side: profile.isFollowing
                            ? const BorderSide(color: AppColors.borderSubtle)
                            : BorderSide.none,
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.pillBorder,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                        elevation: 0,
                      ),
                      onPressed: onToggleFollow,
                      child: Text(
                        profile.isFollowing ? 'Following' : 'Follow',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  // Tip Artist Button
                  if (profile.tipsEnabled)
                    Semantics(
                      label: 'Tip ${profile.displayName} with credits',
                      button: true,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surfaceElevated,
                          foregroundColor: AppColors.coinGold,
                          side: BorderSide(color: AppColors.coinGold.withAlpha(90)),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.pillBorder,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          elevation: 0,
                        ),
                        onPressed: onTipArtist,
                        icon: const Icon(Icons.monetization_on_rounded, size: 18),
                        label: const Text(
                          'Tip Artist',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                  // Share Button
                  Semantics(
                    label: 'Share ${profile.displayName}\'s profile',
                    button: true,
                    child: IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceElevated,
                        side: const BorderSide(color: AppColors.borderSubtle),
                      ),
                      icon: const Icon(Icons.share_rounded, size: 18, color: Colors.white),
                      onPressed: onShare,
                    ),
                  ),

                  // Report Button
                  Semantics(
                    label: 'Report ${profile.displayName}\'s profile',
                    button: true,
                    child: IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surfaceElevated,
                        side: const BorderSide(color: AppColors.borderSubtle),
                      ),
                      icon: const Icon(Icons.flag_outlined, size: 18, color: AppColors.textSecondary),
                      onPressed: onReport,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
