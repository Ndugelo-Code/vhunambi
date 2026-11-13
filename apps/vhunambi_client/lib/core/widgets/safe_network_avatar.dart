import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';

/// Error-resilient circular avatar widget (REQ-P65-L3-04).
///
/// Normalizes legacy/R2 URLs, attaches `onBackgroundImageError` to [CircleAvatar],
/// and falls back cleanly to creator initials or a [PhosphorIcon] on 404/codec error.
class SafeNetworkAvatar extends StatefulWidget {
  final String? imageUrl;
  final String fallbackLabel;
  final double radius;
  final Color? backgroundColor;

  const SafeNetworkAvatar({
    super.key = const Key('safe_network_avatar'),
    required this.imageUrl,
    required this.fallbackLabel,
    this.radius = 20,
    this.backgroundColor,
  });

  @override
  State<SafeNetworkAvatar> createState() => _SafeNetworkAvatarState();
}

class _SafeNetworkAvatarState extends State<SafeNetworkAvatar> {
  bool _hasError = false;

  @override
  void didUpdateWidget(covariant SafeNetworkAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _hasError = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final raw = widget.imageUrl?.trim() ?? '';
    final normalizedUrl = raw.isEmpty
        ? ''
        : AppConstants.normalizeCloudMediaUrl(raw);
    final showImage = normalizedUrl.isNotEmpty && !_hasError;
    final trimmedLabel = widget.fallbackLabel.trim();
    final initial = trimmedLabel.isNotEmpty
        ? trimmedLabel[0].toUpperCase()
        : '';

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: widget.backgroundColor ?? AppColors.surfaceSecondary,
      backgroundImage: showImage ? NetworkImage(normalizedUrl) : null,
      onBackgroundImageError: showImage
          ? (Object exception, StackTrace? stackTrace) {
              if (mounted && !_hasError) {
                setState(() => _hasError = true);
              }
            }
          : null,
      child: !showImage
          ? KeyedSubtree(
              key: const Key('safe_network_avatar_fallback'),
              child: initial.isNotEmpty
                  ? Text(
                      initial,
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : const PhosphorIcon(
                      PhosphorIconsBold.user,
                      color: AppColors.brandPrimary,
                      size: 16,
                    ),
            )
          : null,
    );
  }
}
