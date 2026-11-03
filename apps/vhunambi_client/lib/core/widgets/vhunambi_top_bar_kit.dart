import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../design_system/tokens/app_icons.dart';

import '../theme/app_colors.dart';
import '../utils/responsive_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';
import '../../features/profile/presentation/providers/profile_providers.dart';
import '../../features/social/presentation/providers/creator_wallet_provider.dart';
import '../../features/profile/presentation/views/owner_profile_view.dart';
import '../../features/profile/presentation/widgets/creator_avatar.dart';

/// Shared top-bar geometry, surface and affordances for the Vhunambi shell.
///
/// Centralizes the safe-area math so every custom `PreferredSize` header
/// reserves `statusBarInset + toolbarHeight` instead of a fixed `56px` box
/// that squishes content on notched / island / punch-hole devices.
///
/// Reference: docs/audits/TOP_BAR_NAVIGATION_AUDIT_PROMPT.md (Dimension 2).
abstract final class VhunambiTopBarMetrics {
  /// Status-bar / camera-cutout inset. `0` on desktop and in bare test envs.
  static double topInset(BuildContext context) =>
      MediaQuery.paddingOf(context).top;

  /// Constant interactive row height — invariant across device cutouts so the
  /// content never squishes; only the inset region above it grows.
  static double toolbarHeight(BuildContext context) =>
      ResponsiveUtils.isDesktop(context) ? 64 : 56;

  /// Total height a `PreferredSize` must reserve for a [VhunambiTopBarSurface]:
  /// the status-bar inset plus the constant interactive toolbar.
  static double totalHeight(BuildContext context, {double? toolbarHeight}) =>
      topInset(context) +
      (toolbarHeight ?? VhunambiTopBarMetrics.toolbarHeight(context));
}

/// Decorated top-bar surface that paints the status-bar inset region in the
/// same colour as the toolbar (one continuous surface) and pins the
/// interactive content to a constant [toolbarHeight] so it never squishes.
///
/// Replaces the `Container(height: X) + SafeArea(bottom: false)` anti-pattern.
///
/// Dimension 5: Supports frosted glassmorphism via [enableBlur], applying a
/// modern 2026 backdrop filter blur with translucent canvas background and
/// subtle hairline border.
class VhunambiTopBarSurface extends StatelessWidget {
  /// The interactive row. Provide it already horizontally padded if desired.
  final Widget child;

  /// Interactive row height. Defaults to [VhunambiTopBarMetrics.toolbarHeight].
  final double? toolbarHeight;

  /// Custom decoration; defaults to the canvas surface + bottom hairline.
  final BoxDecoration? decoration;

  /// Whether to render a 2026 frosted-glass backdrop blur (defaults to true).
  final bool enableBlur;

  /// Blur intensity when [enableBlur] is active. Defaults to 16.0.
  final double blurSigma;

  /// Opacity of the background canvas surface when frosted glass is enabled.
  /// Defaults to 0.85 to let ambient content subtly show through.
  final double surfaceOpacity;

  const VhunambiTopBarSurface({
    super.key,
    required this.child,
    this.toolbarHeight,
    this.decoration,
    this.enableBlur = true,
    this.blurSigma = 16.0,
    this.surfaceOpacity = 0.85,
  });

  @override
  Widget build(BuildContext context) {
    final bar = toolbarHeight ?? VhunambiTopBarMetrics.toolbarHeight(context);
    final content = Padding(
      padding: EdgeInsets.only(top: VhunambiTopBarMetrics.topInset(context)),
      child: SizedBox(height: bar, width: double.infinity, child: child),
    );

    if (!enableBlur) {
      return Container(
        width: double.infinity,
        decoration:
            decoration ??
            BoxDecoration(
              color: AppColors.surfaceCanvas,
              border: Border(
                bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
              ),
            ),
        child: content,
      );
    }

    final effectiveDecoration =
        decoration ??
        BoxDecoration(
          color: AppColors.surfaceCanvas.withValues(alpha: surfaceOpacity),
          border: Border(
            bottom: BorderSide(color: AppColors.borderSubtle, width: 1),
          ),
        );

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          width: double.infinity,
          decoration: effectiveDecoration,
          child: content,
        ),
      ),
    );
  }
}

/// Canonical back affordance for pushed routes.
///
/// Uses a single glyph (`chevron_left_rounded`) with a 44x44 minimum touch
/// target (Apple HIG / WCAG 2.5.5) and defaults to `Navigator.maybePop()`.
class VhunambiBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? color;
  final String tooltip;

  const VhunambiBackButton({
    super.key,
    this.onPressed,
    this.color,
    this.tooltip = 'Back',
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: const PhosphorIcon(AppIcons.caretLeft, size: 20),
      color: color ?? AppColors.textPrimary,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
    );
  }
}

/// Standardized user coins chip synchronized across all top bars.
class VhunambiUserCoinsChip extends ConsumerWidget {
  const VhunambiUserCoinsChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creatorWallet = ref.watch(creatorWalletProvider);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.coinGold.withAlpha(20),
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: AppColors.coinGold.withAlpha(120), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PhosphorIcon(
            PhosphorIconsFill.coins,
            size: 14,
            color: AppColors.coinGold,
          ),
          const SizedBox(width: 4),
          Text(
            '${creatorWallet.userCoinsBalance} Coins',
            style: AppTypography.caption.copyWith(
              color: AppColors.coinGold,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Standardized owner profile avatar button synchronized across all top bars.
class VhunambiUserAvatarButton extends ConsumerWidget {
  final double size;
  const VhunambiUserAvatarButton({super.key, this.size = 32});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerProfile = ref.watch(ownerProfileProvider);
    return InkWell(
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const OwnerProfileView()));
      },
      borderRadius: BorderRadius.circular(size / 2),
      child: CreatorAvatar(
        size: size,
        monogram: ownerProfile.monogram,
        avatarUrl: ownerProfile.avatarUrl,
      ),
    );
  }
}
