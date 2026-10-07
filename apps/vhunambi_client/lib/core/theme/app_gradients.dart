import 'package:flutter/material.dart';

/// Regional African Genre Gradients and Hero Visual Tokens
/// Reference: docs/foundation_blueprints/00_SYSTEM_DESIGN_TOKENS.md
abstract final class AppGradients {
  // Hero African Music Charts Banner
  static const LinearGradient africanChartsBanner = LinearGradient(
    colors: [Color(0xFFC2410C), Color(0xFFEA580C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Marketing Hero Text Accent
  static const LinearGradient heroTextGradient = LinearGradient(
    colors: [Color(0xFFF97316), Color(0xFFF59E0B)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // The 12 Curated African Genre Cover Gradients
  static const LinearGradient amapiano = LinearGradient(
    colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient kwaito = LinearGradient(
    colors: [Color(0xFF991B1B), Color(0xFFDC2626)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gqom = LinearGradient(
    colors: [Color(0xFF312E81), Color(0xFF4F46E5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient maskandi = LinearGradient(
    colors: [Color(0xFF065F46), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient mbaqanga = LinearGradient(
    colors: [Color(0xFF78350F), Color(0xFFB45309)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient marabi = LinearGradient(
    colors: [Color(0xFF581C87), Color(0xFF7E22CE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bubblegum = LinearGradient(
    colors: [Color(0xFFBE185D), Color(0xFFF43F5E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient afroHouse = LinearGradient(
    colors: [Color(0xFFC2410C), Color(0xFFEA580C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient afrobeats = LinearGradient(
    colors: [Color(0xFFB45309), Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient afroJazz = LinearGradient(
    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient afroSoul = LinearGradient(
    colors: [Color(0xFF831843), Color(0xFFDB2777)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient afroArabic = LinearGradient(
    colors: [Color(0xFF047857), Color(0xFF0D9488)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Helper to resolve a genre string directly to its corresponding design token gradient
  static LinearGradient forGenre(String genre) {
    return switch (genre.toLowerCase().trim()) {
      'amapiano'   => amapiano,
      'kwaito'     => kwaito,
      'gqom'       => gqom,
      'maskandi'   => maskandi,
      'mbaqanga'   => mbaqanga,
      'marabi'     => marabi,
      'bubblegum'  => bubblegum,
      'afro house' || 'afrohouse' => afroHouse,
      'afrobeats'  => afrobeats,
      'afro jazz'  || 'afrojazz'  => afroJazz,
      'afro soul'  || 'afrosoul'  => afroSoul,
      'afro-arabic'|| 'afro arabic' => afroArabic,
      _            => amapiano,
    };
  }
}
