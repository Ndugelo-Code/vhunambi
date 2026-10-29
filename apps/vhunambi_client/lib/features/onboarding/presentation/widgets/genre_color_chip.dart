import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/core/design_system/design_system.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';

/// Chip representing a musical genre with its distinct brand color.
///
/// Uses [VhunambiThemeExtension] to resolve genre accent, surface tint,
/// and text colors from the [DesignTokenRegistry]. Selected state applies
/// the genre's accent color to border, text, and check mark, with a tinted
/// surface at alpha 0.15. Maintains WCAG AA 4.5:1 contrast.
class GenreColorChip extends ConsumerWidget {
  /// The genre to display.
  final Genre genre;

  /// Whether this chip is currently selected.
  final bool isSelected;

  /// Callback invoked when the chip is tapped.
  final VoidCallback onTap;

  const GenreColorChip({
    super.key,
    required this.genre,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = VhunambiThemeExtension.of(context);
    final accent = theme.genreAccent(genre);
    final surfaceTint = theme.genreSurfaceTint(genre);
    final textColor = theme.genreTextColor(genre);

    return Semantics(
      button: true,
      selected: isSelected,
      label: AccessibilityService.genreChipLabel(genre.displayName, isSelected),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticsService().lightImpact();
            onTap();
          },
          borderRadius: AppRadius.pillBorder,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? surfaceTint.withValues(alpha: 0.15)
                  : AppColors.surfaceElevated,
              borderRadius: AppRadius.pillBorder,
              border: Border.all(
                color: isSelected ? accent : AppColors.borderSubtle,
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  genre.displayName,
                  style: AppTypography.bodySmall.copyWith(
                    color: isSelected ? accent : textColor,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    Icons.check_circle,
                    color: accent,
                    size: 18,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
