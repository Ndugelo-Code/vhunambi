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
///
/// Example:
/// - 'sigwa' -> 'creator_sigwa'
/// - 'creator_sigwa' -> 'creator_sigwa'
/// - 'creator_creator_sigwa' -> 'creator_sigwa'
String normalizeCreatorId(String id) {
  final raw = extractRawCreatorId(id);
  if (raw.isEmpty) return '';
  return 'creator_$raw';
}
