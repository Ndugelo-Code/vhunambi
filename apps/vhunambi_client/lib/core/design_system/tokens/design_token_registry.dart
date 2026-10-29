import 'package:flutter/material.dart';
import 'color_token.dart';
import 'contrast_utils.dart';
import 'design_enums.dart';
import 'token_exceptions.dart';

/// Central registry for Genre and Mood color tokens.
///
/// The registry is the single source of truth for all design color tokens
/// in the Vhunambi application. Tokens are registered at startup and the
/// registry is then sealed to prevent late or duplicate registrations.
///
/// All token lookups are O(1) map accesses and complete in well under 1ms.
class DesignTokenRegistry {
  DesignTokenRegistry._();

  /// Map of Genre to its ColorToken.
  static final Map<Genre, ColorToken> _genreTokens = <Genre, ColorToken>{};

  /// Map of Mood to its ColorToken.
  static final Map<Mood, ColorToken> _moodTokens = <Mood, ColorToken>{};

  /// Whether the registry has been sealed (no further registrations allowed).
  static bool _isSealed = false;

  /// Minimum contrast ratio required between text and tinted surface (WCAG AA).
  static const double _minContrastRatio = 4.5;

  /// Registers a Genre color token.
  ///
  /// Throws [DuplicateTokenException] if the Genre is already registered.
  /// Throws [ContrastViolationException] if the token's text color does not
  /// meet the 4.5:1 contrast minimum against its surface tint.
  /// Throws [StateError] if the registry is sealed.
  static void registerGenre(Genre genre, ColorToken token) {
    if (_isSealed) {
      throw StateError('DesignTokenRegistry is sealed; cannot register new tokens.');
    }
    if (_genreTokens.containsKey(genre)) {
      throw DuplicateTokenException(
        'Genre ${genre.displayName} already has a registered token.',
      );
    }
    _validateToken(genre.displayName, token);
    _genreTokens[genre] = token;
  }

  /// Registers a Mood color token.
  ///
  /// Throws [DuplicateTokenException] if the Mood is already registered.
  /// Throws [ContrastViolationException] if the token's text color does not
  /// meet the 4.5:1 contrast minimum against its surface tint.
  /// Throws [StateError] if the registry is sealed.
  static void registerMood(Mood mood, ColorToken token) {
    if (_isSealed) {
      throw StateError('DesignTokenRegistry is sealed; cannot register new tokens.');
    }
    if (_moodTokens.containsKey(mood)) {
      throw DuplicateTokenException(
        'Mood ${mood.displayName} already has a registered token.',
      );
    }
    _validateToken(mood.displayName, token);
    _moodTokens[mood] = token;
  }

  /// Seals the registry, preventing any further registrations.
  /// Call this after all tokens have been registered (typically during app
  /// initialization before `runApp`).
  static void seal() {
    _isSealed = true;
  }

  /// Returns the ColorToken for the given [genre].
  ///
  /// Throws [TokenNotFoundException] if the genre has no registered token.
  static ColorToken getGenreToken(Genre genre) {
    final token = _genreTokens[genre];
    if (token == null) {
      throw TokenNotFoundException(
        availableTokens: _genreTokens.keys.map((g) => g.displayName).toList(),
      );
    }
    return token;
  }

  /// Returns the ColorToken for the given [mood].
  ///
  /// Throws [TokenNotFoundException] if the mood has no registered token.
  static ColorToken getMoodToken(Mood mood) {
    final token = _moodTokens[mood];
    if (token == null) {
      throw TokenNotFoundException(
        availableTokens: _moodTokens.keys.map((m) => m.displayName).toList(),
      );
    }
    return token;
  }

  /// Returns the accent color for the given [genre].
  static Color getGenreAccent(Genre genre) => getGenreToken(genre).accent;

  /// Returns the surface tint color for the given [genre].
  static Color getGenreSurfaceTint(Genre genre) => getGenreToken(genre).surfaceTint;

  /// Returns the glow color for the given [genre].
  static Color getGenreGlow(Genre genre) => getGenreToken(genre).glow;

  /// Returns the text color for the given [genre].
  static Color getGenreTextColor(Genre genre) => getGenreToken(genre).textColor;

  /// Returns the accent color for the given [mood].
  static Color getMoodAccent(Mood mood) => getMoodToken(mood).accent;

  /// Returns the surface tint color for the given [mood].
  static Color getMoodSurfaceTint(Mood mood) => getMoodToken(mood).surfaceTint;

  /// Returns the glow color for the given [mood].
  static Color getMoodGlow(Mood mood) => getMoodToken(mood).glow;

  /// Returns the text color for the given [mood].
  static Color getMoodTextColor(Mood mood) => getMoodToken(mood).textColor;

  /// Validates that a token meets the minimum contrast ratio requirement.
  static void _validateToken(String name, ColorToken token) {
    final ratio = ContrastUtils.calculateContrastRatio(
      token.textColor,
      token.surfaceTint,
    );
    if (ratio < _minContrastRatio) {
      throw ContrastViolationException(
        tokenName: name,
        actualRatio: ratio,
      );
    }
  }

  /// Generates a validation report mapping token names to their contrast ratios.
  ///
  /// Useful for design review and accessibility auditing.
  static Map<String, double> generateValidationReport() {
    final report = <String, double>{};

    for (final entry in _genreTokens.entries) {
      final ratio = ContrastUtils.calculateContrastRatio(
        entry.value.textColor,
        entry.value.surfaceTint,
      );
      report['Genre: ${entry.key.displayName}'] = ratio;
    }

    for (final entry in _moodTokens.entries) {
      final ratio = ContrastUtils.calculateContrastRatio(
        entry.value.textColor,
        entry.value.surfaceTint,
      );
      report['Mood: ${entry.key.displayName}'] = ratio;
    }

    return report;
  }

  /// Resets the registry to its initial empty, unsealed state.
  ///
  /// This method is intended for test isolation only and is marked
  /// `@visibleForTesting`.
  @visibleForTesting
  static void reset() {
    _genreTokens.clear();
    _moodTokens.clear();
    _isSealed = false;
  }

  /// Returns the number of registered genre tokens.
  static int get genreCount => _genreTokens.length;

  /// Returns the number of registered mood tokens.
  static int get moodCount => _moodTokens.length;

  /// Returns whether the registry is sealed.
  static bool get isSealed => _isSealed;
}