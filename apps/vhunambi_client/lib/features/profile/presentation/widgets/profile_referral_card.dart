import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/vhunambi_glass_surface.dart';

/// One-Tap Profile Referral & Link Copy Card (REQ-TRK-16).
class ProfileReferralCard extends StatelessWidget {
  final String username;

  const ProfileReferralCard({super.key, required this.username});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: VhunambiGlassSurface(
        variant: VhunambiGlassVariant.card,
        enableLiveBlur: false,
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withAlpha(24),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: PhosphorIcon(
                  PhosphorIconsRegular.link,
                  color: AppColors.brandPrimary,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Share your profile',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textPrimaryOf(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Let the world discover your music.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.brandPrimary.withAlpha(24),
                foregroundColor: AppColors.brandPrimary,
                minimumSize: const Size(0, 44),
                side: const BorderSide(color: AppColors.brandPrimary),
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.pillBorder,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              onPressed: () {
                final link = 'https://vhunambi.com/profile/$username';
                Clipboard.setData(ClipboardData(text: link));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Profile link copied: $link'),
                    backgroundColor: AppColors.surfaceElevatedOf(context),
                  ),
                );
              },
              icon: const PhosphorIcon(PhosphorIconsRegular.copy, size: 16),
              label: const Text(
                'Copy Link',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
