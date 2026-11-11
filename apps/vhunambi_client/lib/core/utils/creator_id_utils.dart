/// Utilities for resilient and idempotent creator identifier transformations.
/// Handles stripping repeated 'creator_' prefixes and normalizing to canonical format.
library;

/// Strips any number of leading 'creator_' prefixes to extract the raw alphanumeric username.
///
/// Example:
/// - 'sigwa' -> 'sigwa'
/// - 'creator_sigwa' -> 'sigwa'
/// - 'creator_creator_sigwa' -> 'sigwa'
String extractRawCreatorId(String id) {
  var current = id.trim();
  while (current.startsWith('creator_')) {
    current = current.substring(8);
  }
  return current;
}

/// Normalizes any creator identifier to the canonical `creator_<id>` format.
String normalizeCreatorId(String id) => _normalizeCreatorIdImpl(id);

String _normalizeCreatorIdImpl(String id) {
  final raw = extractRawCreatorId(id);
  if (raw.isEmpty) return '';
  if (raw == 'blackcoffee' || raw == 'black_coffee') {
    return 'creator_black_coffee';
  }
  return 'creator_$raw';
}

const Set<String> _anonymousAliasIds = <String>{
  'me',
  'usr_me',
  'buyer_user',
  'buyer_default',
  'user_current',
  'vhunambi_creator',
  'vhunambi_user',
};

/// Canonicalizes handles, raw slugs, or anonymous legacy aliases (`usr_me`, `me`,
/// `buyer_user`, `@blackcoffee`, `creator_blackcoffee`) onto a single `creator_<slug>`
/// tenant identity (`Phase 61 & Phase 62`).
String canonicalizeCreatorId(
  String? input, {
  String fallback = 'creator_cern',
}) =>
    _canonicalizeCreatorIdImpl(input, fallback: fallback);

String _canonicalizeCreatorIdImpl(
  String? input, {
  String fallback = 'creator_cern',
}) {
  if (input == null) return fallback;
  var trimmed = input.trim().toLowerCase();
  if (trimmed.isEmpty) return fallback;
  if (trimmed.startsWith('@')) {
    trimmed = trimmed.substring(1);
  }
  final raw = extractRawCreatorId(trimmed).replaceAll(RegExp(r'[^a-z0-9_.-]'), '');
  if (raw.isEmpty ||
      _anonymousAliasIds.contains(raw) ||
      _anonymousAliasIds.contains(trimmed)) {
    return fallback;
  }
  if (raw == 'blackcoffee' || raw == 'black_coffee') {
    return 'creator_black_coffee';
  }
  return 'creator_$raw';
}

/// Derives an `@handle` display handle from a canonical creator ID.
String handleFromCreatorId(String creatorId) =>
    _handleFromCreatorIdImpl(creatorId);

String _handleFromCreatorIdImpl(String creatorId) {
  final raw = extractRawCreatorId(creatorId.trim().toLowerCase());
  if (raw.isEmpty || _anonymousAliasIds.contains(raw)) return '@cern';
  if (raw == 'black_coffee' || raw == 'blackcoffee') return '@blackcoffee';
  return '@$raw';
}

/// Static wrapper class exposing the top-level creator ID normalization helpers.
abstract final class CreatorIdUtils {
  static String extractRaw(String id) => extractRawCreatorId(id);
  static String normalizeCreatorId(String id) => _normalizeCreatorIdImpl(id);
  static String canonicalizeCreatorId(
    String? input, {
    String fallback = 'creator_cern',
  }) =>
      _canonicalizeCreatorIdImpl(input, fallback: fallback);
  static String handleFromCreatorId(String creatorId) =>
      _handleFromCreatorIdImpl(creatorId);
}
