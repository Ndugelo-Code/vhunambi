import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Reusable African Creator Profile Avatar & Icon.
///
/// Supports custom uploaded photos, RunPod AI synthesized portraits,
/// or authentic cultural monogram fallbacks with HIG 44px ergonomics.
class CreatorAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String monogram;
  final double size;
  final double borderWidth;
  final Color? borderColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showEditBadge;
  final Key? avatarKey;

  const CreatorAvatar({
    super.key,
    this.avatarUrl,
    this.monogram = 'ND',
    this.size = 44.0,
    this.borderWidth = 1.5,
    this.borderColor,
    this.onTap,
    this.onLongPress,
    this.showEditBadge = false,
    this.avatarKey,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = borderColor ?? AppColors.brandPrimary;
    final hasValidUrl = avatarUrl != null && avatarUrl!.trim().isNotEmpty;

    Widget avatarContent;

    if (hasValidUrl) {
      avatarContent = Image.network(
        avatarUrl!,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (_, _, _) => _buildMonogramFallback(),
        loadingBuilder: (_, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildMonogramFallback();
        },
      );
    } else {
      avatarContent = _buildMonogramFallback();
    }

    Widget avatarCore = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.brandPrimary.withAlpha(26),
        shape: BoxShape.circle,
        border: Border.all(
          color: effectiveBorderColor,
          width: borderWidth,
        ),
      ),
      child: ClipOval(
        child: avatarContent,
      ),
    );

    if (showEditBadge) {
      final badgeSize = (size * 0.36).clamp(18.0, 26.0);
      avatarCore = Stack(
        clipBehavior: Clip.none,
        children: [
          avatarCore,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                color: AppColors.brandPrimary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.surfaceCanvas,
                  width: 2,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: badgeSize * 0.55,
                  color: AppColors.brandContrast,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Ensure minimum 44x44 touch geometry
    return Semantics(
      button: onTap != null,
      label: 'Creator profile avatar',
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: size < 44 ? 44 : size,
          minHeight: size < 44 ? 44 : size,
        ),
        child: InkWell(
          key: avatarKey,
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(size / 2),
          child: Center(child: avatarCore),
        ),
      ),
    );
  }

  Widget _buildMonogramFallback() {
    final cleanMonogram = monogram.trim();
    if (cleanMonogram.isNotEmpty) {
      return Center(
        child: Text(
          cleanMonogram,
          style: AppTypography.titleMedium.copyWith(
            color: AppColors.brandPrimary,
            fontWeight: FontWeight.bold,
            fontSize: (size * 0.35).clamp(11.0, 26.0),
          ),
        ),
      );
    }
    return Center(
      child: Icon(
        Icons.person_rounded,
        color: AppColors.brandPrimary,
        size: (size * 0.55).clamp(18.0, 36.0),
      ),
    );
  }
}
