import 'package:flutter/material.dart';
import 'color_token.dart';
import 'design_enums.dart';
import 'design_token_registry.dart';

/// Registers all Vhunambi Genre and Mood color tokens with the
/// [DesignTokenRegistry].
///
/// Each token defines a complete color set (accent, surface tint, glow,
/// text color) with WCAG AA 4.5:1 contrast between textColor and
/// surfaceTint. Colors are derived from the Vhunambi design system
/// (see `docs/foundation_blueprints/00_SYSTEM_DESIGN_TOKENS.md`) and
/// existing `AppColors` / `AppGradients` tokens.
///
/// Call [registerAllTokens] during app initialization before `runApp`,
/// followed by [DesignTokenRegistry.seal()].
class TokenRegistration {
  TokenRegistration._();

  /// Registers all 8 genre and 5 mood color tokens.
  static void registerAllTokens() {
    _registerGenres();
    _registerMoods();
  }

  static void _registerGenres() {
    DesignTokenRegistry.registerGenre(
      Genre.amapiano,
      const ColorToken(
        accent: Color(0xFFF97316), // Vibrant Amber / Orange
        surfaceTint: Color(0xFF1A1A1E), // Deep near-black canvas
        glow: Color(0x1AF97316), // Semi-transparent amber glow
        textColor: Color(0xFFFFFFFF), // White text on dark tint
      ),
    );

    DesignTokenRegistry.registerGenre(
      Genre.afroHouse,
      const ColorToken(
        accent: Color(0xFFEA580C), // Dark Orange / Burnt Amber
        surfaceTint: Color(0xFF2A1A14), // Deep burnt sienna canvas
        glow: Color(0x1AEA580C),
        textColor: Color(0xFFFFFFFF),
      ),
    );

    DesignTokenRegistry.registerGenre(
      Genre.gqom,
      const ColorToken(
        accent: Color(0xFF4F46E5), // Indigo
        surfaceTint: Color(0xFF1E1E3A), // Deep indigo canvas
        glow: Color(0x1A4F46E5),
        textColor: Color(0xFFFFFFFF),
      ),
    );

    DesignTokenRegistry.registerGenre(
      Genre.kwaito,
      const ColorToken(
        accent: Color(0xFFDC2626), // Red
        surfaceTint: Color(0xFF2A1414), // Deep red canvas
        glow: Color(0x1ADC2626),
        textColor: Color(0xFFFFFFFF),
      ),
    );

    DesignTokenRegistry.registerGenre(
      Genre.afroPop,
      const ColorToken(
        accent: Color(0xFFF59E0B), // Amber
        surfaceTint: Color(0xFF2A2A14), // Deep amber canvas
        glow: Color(0x1AF59E0B),
        textColor: Color(0xFFFFFFFF),
      ),
    );

    DesignTokenRegistry.registerGenre(
      Genre.maskandi,
      const ColorToken(
        accent: Color(0xFF059669), // Emerald Green
        surfaceTint: Color(0xFF142A1E), // Deep green canvas
        glow: Color(0x1A059669),
        textColor: Color(0xFFFFFFFF),
      ),
    );

    DesignTokenRegistry.registerGenre(
      Genre.hipHop,
      const ColorToken(
        accent: Color(0xFF8B5CF6), // Violet / Electric Purple
        surfaceTint: Color(0xFF2A143A), // Deep purple canvas
        glow: Color(0x1A8B5CF6),
        textColor: Color(0xFFFFFFFF),
      ),
    );

    DesignTokenRegistry.registerGenre(
      Genre.gospel,
      const ColorToken(
        accent: Color(0xFF10B981), // Emerald / Mint Green
        surfaceTint: Color(0xFF142A22), // Deep emerald canvas
        glow: Color(0x1A10B981),
        textColor: Color(0xFFFFFFFF),
      ),
    );
  }

  static void _registerMoods() {
    DesignTokenRegistry.registerMood(
      Mood.joyful,
      const ColorToken(
        accent: Color(0xFFF59E0B), // Sunny Amber
        surfaceTint: Color(0xFF2A2A14), // Deep amber canvas
        glow: Color(0x1AF59E0B),
        textColor: Color(0xFFFFFFFF),
      ),
    );

    DesignTokenRegistry.registerMood(
      Mood.melancholic,
      const ColorToken(
        accent: Color(0xFF4F46E5), // Soft Indigo
        surfaceTint: Color(0xFF1E1E3A), // Deep indigo canvas
        glow: Color(0x1A4F46E5),
        textColor: Color(0xFFFFFFFF),
      ),
    );

    DesignTokenRegistry.registerMood(
      Mood.energetic,
      const ColorToken(
        accent: Color(0xFFF97316), // Vibrant Orange
        surfaceTint: Color(0xFF1A1A1E), // Deep near-black canvas
        glow: Color(0x1AF97316),
        textColor: Color(0xFFFFFFFF),
      ),
    );

    DesignTokenRegistry.registerMood(
      Mood.calm,
      const ColorToken(
        accent: Color(0xFF10B981), // Mint Green
        surfaceTint: Color(0xFF142A22), // Deep emerald canvas
        glow: Color(0x1A10B981),
        textColor: Color(0xFFFFFFFF),
      ),
    );

    DesignTokenRegistry.registerMood(
      Mood.romantic,
      const ColorToken(
        accent: Color(0xFFDB2777), // Rose Pink
        surfaceTint: Color(0xFF2A1422), // Deep rose canvas
        glow: Color(0x1ADB2777),
        textColor: Color(0xFFFFFFFF),
      ),
    );
  }
}