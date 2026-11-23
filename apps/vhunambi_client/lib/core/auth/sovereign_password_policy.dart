import 'package:flutter/foundation.dart';

/// Deterministic Sovereign & Supabase Free-Tier Password Policy (`minLength = 8`).
///
/// Mirrors `apps/vhunambi_api/src/security/password_policy.ts` 1:1:
/// - Minimum 8 characters
/// - No leading or trailing whitespace
/// - At least one lowercase letter (`a-z`), one uppercase letter (`A-Z`),
///   one digit (`0-9`), and one symbol (`!@#$%...`)
/// - Rejects common breached/sequential passwords (`Password123!`, `12345678`, `Qwerty123!`)
@immutable
class SovereignPasswordEvaluation {
  final bool hasMinLength;
  final bool hasNoEdgeWhitespace;
  final bool hasLowercase;
  final bool hasUppercase;
  final bool hasDigit;
  final bool hasSymbol;
  final bool notCommonWeak;
  final String? failureMessage;

  const SovereignPasswordEvaluation({
    required this.hasMinLength,
    required this.hasNoEdgeWhitespace,
    required this.hasLowercase,
    required this.hasUppercase,
    required this.hasDigit,
    required this.hasSymbol,
    required this.notCommonWeak,
    required this.failureMessage,
  });

  bool get isValid => failureMessage == null;

  String get firstFailureMessage =>
      failureMessage ??
      'Password must be at least ${SovereignPasswordPolicy.minLength} characters with uppercase, lowercase, digit, and symbol.';
}

abstract final class SovereignPasswordPolicy {
  static const int minLength = 8;

  static const Set<String> _commonBreachedBases = <String>{
    'password',
    'passw0rd',
    'p@ssword',
    'p@ssw0rd',
    '12345678',
    '123456789',
    '1234567890',
    'qwerty',
    'qwertyui',
    'qwerty123',
    'admin',
    'administrator',
    'letmein',
    'welcome',
    'iloveyou',
    'monkey',
    'dragon',
    'master',
    'sunshine',
    'trustno1',
  };

  static final RegExp _lowerRegex = RegExp(r'[a-z]');
  static final RegExp _upperRegex = RegExp(r'[A-Z]');
  static final RegExp _digitRegex = RegExp(r'[0-9]');
  static final RegExp _symbolRegex = RegExp(r'[^A-Za-z0-9\s]');
  static final RegExp _trailingDigitsSymbols = RegExp(
    r'''[0-9!@#$%^&*()_+\-=\[\]{};':"\\|,.<>/?~`]+$''',
  );
  static final RegExp _sequentialPrefix = RegExp(
    r'^(?:123456|abcdef|qwerty)',
    caseSensitive: false,
  );

  static SovereignPasswordEvaluation evaluate(String password) {
    final hasMinLength = password.length >= minLength;
    final hasNoEdgeWhitespace =
        password.isNotEmpty && password.trim().length == password.length;
    final hasLowercase = _lowerRegex.hasMatch(password);
    final hasUppercase = _upperRegex.hasMatch(password);
    final hasDigit = _digitRegex.hasMatch(password);
    final hasSymbol = _symbolRegex.hasMatch(password);

    final normalizedLower = password.toLowerCase();
    final strippedBase = normalizedLower.replaceAll(_trailingDigitsSymbols, '');
    final isSequential = _sequentialPrefix.hasMatch(password);
    final notCommonWeak =
        password.isNotEmpty &&
        !_commonBreachedBases.contains(normalizedLower) &&
        !_commonBreachedBases.contains(strippedBase) &&
        !isSequential;

    String? failureMessage;
    if (!hasMinLength) {
      failureMessage =
          'Password must be at least $minLength characters long.';
    } else if (!hasNoEdgeWhitespace) {
      failureMessage = 'Password cannot start or end with spaces.';
    } else if (!hasLowercase || !hasUppercase || !hasDigit || !hasSymbol) {
      failureMessage =
          'Password must include uppercase, lowercase, a digit, and a symbol (e.g. !@#\$%).';
    } else if (!notCommonWeak) {
      failureMessage =
          'Password is too common or easily guessed. Choose a unique passphrase.';
    }

    return SovereignPasswordEvaluation(
      hasMinLength: hasMinLength,
      hasNoEdgeWhitespace: hasNoEdgeWhitespace,
      hasLowercase: hasLowercase,
      hasUppercase: hasUppercase,
      hasDigit: hasDigit,
      hasSymbol: hasSymbol,
      notCommonWeak: notCommonWeak,
      failureMessage: failureMessage,
    );
  }
}
