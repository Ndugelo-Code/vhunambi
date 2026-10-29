/// Base exception for design token registry errors.
abstract class DesignTokenException implements Exception {
  final String message;
  const DesignTokenException(this.message);
  @override
  String toString() => message;
}

/// Thrown when a duplicate token registration is attempted for the same
/// Genre or Mood. The registry enforces a single definition per token.
class DuplicateTokenException extends DesignTokenException {
  const DuplicateTokenException(super.message);
}

/// Thrown when a token violates the minimum WCAG AA contrast ratio
/// requirement (4.5:1 for normal text on tinted surface).
class ContrastViolationException extends DesignTokenException {
  /// The name of the token that violated the contrast requirement.
  final String tokenName;

  /// The actual measured contrast ratio.
  final double actualRatio;

  const ContrastViolationException({
    required this.tokenName,
    required this.actualRatio,
  }) : super(
          'Contrast violation for $tokenName: ratio $actualRatio is below 4.5:1',
        );
}

/// Thrown when a requested token is not found in the registry.
class TokenNotFoundException extends DesignTokenException {
  /// The list of currently available token names for diagnostic purposes.
  final List<String> availableTokens;

  TokenNotFoundException({
    required this.availableTokens,
  }) : super('Token not found. Available: ${availableTokens.join(', ')}');
}