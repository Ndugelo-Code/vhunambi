import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/core/design_system/design_system.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';

/// Chip representing an emotional mood with its distinct brand color.
///
/// Uses [VhunambiThemeExtension] to resolve mood accent, surface tint,
/// and text colors from the [DesignTokenRegistry]. Selected state applies
/// the mood's accent color to border and text, with a tinted surface at
/// alpha 0.12. Visually distinct from [GenreColorChip] via smaller, rounded
/// pill styling. Maintains WCAG AA 4.5:1 contrast.
class MoodColorChip extends ConsumerWidget {
  /// The mood to display.
  final Mood mood;

  /// Whether this chip is currently selected.
  final bool isSelected;

  /// Callback invoked when the chip is tapped.
  final VoidCallback onTap;

  const MoodColorChip({
    super.key,
    required this.mood,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = VhunambiThemeExtension.of(context);
    final accent = theme.moodAccent(mood);
    final surfaceTint = theme.moodSurfaceTint(mood);
    final textColor = theme.moodTextColor(mood);

    return Semantics(
      button: true,
      selected: isSelected,
      label: AccessibilityService.moodChipLabel(mood.displayName, isSelected),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticsService().lightImpact();
            onTap();
          },
          borderRadius: AppRadius.pillBorder,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40, minWidth: 40),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? surfaceTint.withValues(alpha: 0.12)
                  : AppColors.surfaceElevated,
              borderRadius: AppRadius.pillBorder,
              border: Border.all(
                color: isSelected ? accent : AppColors.borderSubtle,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Text(
              mood.displayName,
              style: AppTypography.bodySmall.copyWith(
                color: isSelected ? accent : textColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
