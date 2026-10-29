import 'package:flutter/material.dart';
import '../tokens/design_token_registry.dart';
import '../tokens/design_enums.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';

/// Flutter [ThemeExtension] that exposes Vhunambi design tokens through
/// `Theme.of(context)`.
///
/// Use `VhunambiThemeExtension.of(context)` to access genre/mood color
/// tokens, touch target sizes, and spacing tokens from any widget.
class VhunambiThemeExtension extends ThemeExtension<VhunambiThemeExtension> {
  /// Minimum touch target size (48×48 dp per WCAG 2.5.5 / Apple HIG).
  final Size minTouchTarget;

  /// Standard card border radius.
  final BorderRadius cardBorder;

  /// Standard input border radius.
  final BorderRadius inputBorder;

  /// Standard modal border radius.
  final BorderRadius modalBorder;

  const VhunambiThemeExtension({
    this.minTouchTarget = const Size(48.0, 48.0),
    this.cardBorder = AppRadius.cardBorder,
    this.inputBorder = AppRadius.inputBorder,
    this.modalBorder = AppRadius.modalBorder,
  });

  /// Resolves the extension from the current BuildContext.
  ///
  /// Returns a fallback extension with default values if the extension is
  /// not present in the theme.
  static VhunambiThemeExtension of(BuildContext context) {
    return Theme.of(context).extension<VhunambiThemeExtension>() ??
        const VhunambiThemeExtension();
  }

  /// Returns the accent color for [genre] from the design token registry,
  /// falling back to [AppColors.brandPrimary] if the token is not found.
  Color genreAccent(Genre genre) {
    try {
      return DesignTokenRegistry.getGenreAccent(genre);
    } catch (_) {
      return AppColors.brandPrimary;
    }
  }

  /// Returns the surface tint color for [genre] from the design token registry,
  /// falling back to [AppColors.surfaceElevated] if the token is not found.
  Color genreSurfaceTint(Genre genre) {
    try {
      return DesignTokenRegistry.getGenreSurfaceTint(genre);
    } catch (_) {
      return AppColors.surfaceElevated;
    }
  }

  /// Returns the glow color for [genre] from the design token registry,
  /// falling back to a default glow if the token is not found.
  Color genreGlow(Genre genre) {
    try {
      return DesignTokenRegistry.getGenreGlow(genre);
    } catch (_) {
      return const Color(0x1AF97316);
    }
  }

  /// Returns the text color for [genre] from the design token registry,
  /// falling back to [AppColors.textPrimary] if the token is not found.
  Color genreTextColor(Genre genre) {
    try {
      return DesignTokenRegistry.getGenreTextColor(genre);
    } catch (_) {
      return AppColors.textPrimary;
    }
  }

  /// Returns the accent color for [mood] from the design token registry,
  /// falling back to [AppColors.brandPrimary] if the token is not found.
  Color moodAccent(Mood mood) {
    try {
      return DesignTokenRegistry.getMoodAccent(mood);
    } catch (_) {
      return AppColors.brandPrimary;
    }
  }

  /// Returns the surface tint color for [mood] from the design token registry,
  /// falling back to [AppColors.surfaceElevated] if the token is not found.
  Color moodSurfaceTint(Mood mood) {
    try {
      return DesignTokenRegistry.getMoodSurfaceTint(mood);
    } catch (_) {
      return AppColors.surfaceElevated;
    }
  }

  /// Returns the glow color for [mood] from the design token registry,
  /// falling back to a default glow if the token is not found.
  Color moodGlow(Mood mood) {
    try {
      return DesignTokenRegistry.getMoodGlow(mood);
    } catch (_) {
      return const Color(0x1AF97316);
    }
  }

  /// Returns the text color for [mood] from the design token registry,
  /// falling back to [AppColors.textPrimary] if the token is not found.
  Color moodTextColor(Mood mood) {
    try {
      return DesignTokenRegistry.getMoodTextColor(mood);
    } catch (_) {
      return AppColors.textPrimary;
    }
  }

  @override
  VhunambiThemeExtension copyWith({
    Size? minTouchTarget,
    BorderRadius? cardBorder,
    BorderRadius? inputBorder,
    BorderRadius? modalBorder,
  }) {
    return VhunambiThemeExtension(
      minTouchTarget: minTouchTarget ?? this.minTouchTarget,
      cardBorder: cardBorder ?? this.cardBorder,
      inputBorder: inputBorder ?? this.inputBorder,
      modalBorder: modalBorder ?? this.modalBorder,
    );
  }

  @override
  VhunambiThemeExtension lerp(
    covariant VhunambiThemeExtension? other,
    double t,
  ) {
    if (other is! VhunambiThemeExtension) return this;
    return VhunambiThemeExtension(
      minTouchTarget: Size(
        minTouchTarget.width + (other.minTouchTarget.width - minTouchTarget.width) * t,
        minTouchTarget.height + (other.minTouchTarget.height - minTouchTarget.height) * t,
      ),
      cardBorder: cardBorder,
      inputBorder: inputBorder,
      modalBorder: modalBorder,
    );
  }
}