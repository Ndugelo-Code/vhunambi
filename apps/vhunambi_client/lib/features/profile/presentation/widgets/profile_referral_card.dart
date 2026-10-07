import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';

/// One-Tap Profile Referral & Link Copy Card (REQ-TRK-16).
class ProfileReferralCard extends StatelessWidget {
  final String username;

  const ProfileReferralCard({
    super.key,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.brandPrimary.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.link_rounded,
              color: AppColors.brandPrimary,
              size: 24,
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
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Let the world discover your music.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3A2508),
              foregroundColor: AppColors.brandPrimary,
              side: const BorderSide(color: AppColors.brandPrimary),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.pillBorder,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              elevation: 0,
            ),
            onPressed: () {
              final link = 'https://vhunambi.com/profile/$username';
              Clipboard.setData(ClipboardData(text: link));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Profile link copied: $link 📋'),
                  backgroundColor: AppColors.surfaceElevated,
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text(
              'Copy Link',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
