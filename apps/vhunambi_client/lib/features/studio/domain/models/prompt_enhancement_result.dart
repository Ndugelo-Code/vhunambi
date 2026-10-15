import 'package:flutter/foundation.dart';

/// Result of the pure-Dart `StudioPromptIntelligence.enhance()` pass (M10 /
/// REQ-PRI-01 → REQ-PRI-06).
@immutable
class PromptEnhancementResult {
  /// Raw input prompt before intelligence pass.
  final String rawPrompt;

  /// Richer prompt copy the creator can adopt in one tap.
  final String enhancedPrompt;

  /// Detected field name → suggested value (`genre`, `language`,
  /// `vocalGender`, `vocalMode`, `mood`).
  final Map<String, dynamic> suggestedOverrides;

  const PromptEnhancementResult({
    this.rawPrompt = '',
    required this.enhancedPrompt,
    this.suggestedOverrides = const <String, dynamic>{},
  });

  /// `true` when at least one studio field override was detected.
  bool get hasOverrides => suggestedOverrides.isNotEmpty;

  /// Convenience getters for detected studio field overrides.
  String? get detectedGenre => suggestedOverrides['genre'] as String?;
  String? get detectedLanguage => suggestedOverrides['language'] as String?;
  String? get detectedMood => suggestedOverrides['mood'] as String?;
  String? get detectedVocalGender => suggestedOverrides['vocalGender'] as String?;
  String? get detectedVocalMode => suggestedOverrides['vocalMode'] as String?;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PromptEnhancementResult &&
          runtimeType == other.runtimeType &&
          rawPrompt == other.rawPrompt &&
          enhancedPrompt == other.enhancedPrompt &&
          mapEquals(suggestedOverrides, other.suggestedOverrides);

  @override
  int get hashCode =>
      Object.hash(rawPrompt, enhancedPrompt, Object.hashAll(suggestedOverrides.entries));
}