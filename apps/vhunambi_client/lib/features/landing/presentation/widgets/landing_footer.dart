import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';

/// Global marketing footer with the Tshivenḓa mission statement and link groups
/// (REQ-MKT-11).
class LandingFooter extends StatelessWidget {
  static const String wordmark = 'VHUNAMBI';
  static const String mission =
      'vhunambi — from Tshivenḓa for "the talent or ability to sing". Building the future of African music creation.';

  static const List<String> productLinks = [
    'Explore',
    'Studio',
    'Library',
    'Beat Marketplace',
    'Pricing',
  ];

  static const List<String> legalLinks = [
    'Terms of Service',
    'Privacy Policy',
    'Commercial Licensing',
    'Copyright & Takedown',
  ];

  const LandingFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: AppColors.brandPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.music_note_rounded,
                    size: 16,
                    color: AppColors.brandContrast,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  wordmark,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              mission,
              style: AppTypography.bodySmall.copyWith(height: 1.5),
            ),
            const SizedBox(height: AppSpacing.md),
            _FooterLinks(title: 'Product', links: productLinks),
            const SizedBox(height: AppSpacing.sm),
            _FooterLinks(title: 'Legal & Licensing', links: legalLinks),
          ],
        ),
      ),
    );
  }
}

class _FooterLinks extends StatelessWidget {
  final String title;
  final List<String> links;

  const _FooterLinks({required this.title, required this.links});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: AppTypography.caption.copyWith(
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xxs,
          children: [
            for (final link in links)
              InkWell(
                onTap: () {},
                child: Text(
                  link,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
