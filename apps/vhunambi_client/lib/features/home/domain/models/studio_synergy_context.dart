import '../../../sound_signature/domain/models/sound_idealizer_recipe.dart';
import '../../../sound_signature/domain/models/sound_signature_dna.dart';

/// The kind of measured voice or composition gap detected (Phase 36 REQ-BANTU-SYN-01).
enum SynergyGapKind {
  lowStability,
  lowSnr,
  highReverb,
  lowKeyConfidence,
  highGridOffset,
  signatureUnusedInSketchpad,
}

/// Diagnostic context linking a measured gap to a preloaded studio recipe (doc 05 §2).
class StudioSynergyContext {
  const StudioSynergyContext({
    required this.sourceModule,
    required this.targetModule,
    required this.gapKind,
    required this.measuredValue,
    required this.suggestedRecipe,
    this.signature,
  });

  final String sourceModule;
  final String targetModule;
  final SynergyGapKind gapKind;
  final double measuredValue;
  final SoundIdealizerRecipe suggestedRecipe;
  final SoundSignatureDna? signature;
}

/// Renderable recommendation card item for the home & profile synergy decks (REQ-BANTU-SYN-04).
class SynergyCardItem {
  const SynergyCardItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.context,
    required this.metricSummary,
  });

  final String id;
  final String title;
  final String subtitle;
  final String actionLabel;
  final StudioSynergyContext context;
  final String metricSummary;
}

/// Creator mastery badge representation (REQ-BANTU-SYN-05, REQ-BANTU-SYN-06).
///
/// NOTE: Rewards are strictly COSMETIC (profile badge flair, UI highlight).
/// Zero monetary or wallet credit fields (enforced by REQ-BANTU-SYN-06).
class CreatorMasteryBadge {
  const CreatorMasteryBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.isUnlocked,
    this.unlockedAt,
    this.badgeFlair = '',
  });

  final String id;
  final String name;
  final String description;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final String badgeFlair;
}

