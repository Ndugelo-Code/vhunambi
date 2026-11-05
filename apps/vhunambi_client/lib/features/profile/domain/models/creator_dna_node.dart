import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../creator_dna/domain/entities/creator_dna_profile.dart';
import '../../../onboarding/domain/models/onboarding_models.dart';

/// Evolutionary completion status of a discrete genomic locus (REQ-P49-DNA-01..02).
enum GenomicStatus {
  sequenced,
  lockedQuest,
}

/// The 8 discrete genomic loci in the MMORPG Creator DNA model (REQ-P49-DNA-01).
enum DnaNodeType {
  craftPersona,
  generationEra,
  linguisticRoots,
  sonicGenres,
  voiceSignature,
  grooveArchitect,
  coCreationLineage,
  arTastemaker,
}

/// Friendly title helper for CreativeRole according to STD-UIUX-001.
extension CreativeRoleFriendlyTitle on CreativeRole {
  String get friendlyTitle => switch (this) {
        CreativeRole.producer => 'Producer & Beatmaker',
        CreativeRole.vocalist => 'Natural Vocalist',
        CreativeRole.songwriter => 'Live Instrumentalist',
        CreativeRole.multiHyphenate => 'DAW Master & Artist',
        CreativeRole.musicLover => 'Kinetic Creator & Curator',
      };
}

/// Represents an inspectable locus on the 3D Creator DNA Double-Helix (REQ-P49-DNA-01).
class CreatorDnaNode {
  final int index;
  final DnaNodeType type;
  final String title;
  final String traitLabel;
  final String description;
  final String? questInstruction;
  final String? questActionRoute;
  final Color accentColor;
  final PhosphorIconData icon;
  final GenomicStatus status;
  final int dnaPowerBonus;

  const CreatorDnaNode({
    required this.index,
    required this.type,
    required this.title,
    required this.traitLabel,
    required this.description,
    this.questInstruction,
    this.questActionRoute,
    required this.accentColor,
    required this.icon,
    required this.status,
    this.dnaPowerBonus = 15,
  });

  bool get isSequenced => status == GenomicStatus.sequenced;

  /// Constructs the 8 MMORPG genomic nodes from the onboarding state (REQ-P49-DNA-01..02).
  /// Nodes 1-4 are sequenced during onboarding; Nodes 5-8 are locked quests.
  static List<CreatorDnaNode> getOnboardingDnaNodes(OnboardingState state) {
    final friendlyRole = state.creativeRole.friendlyTitle;
    final era = state.generationEra;
    final genresString = state.selectedGenres.isNotEmpty
        ? state.selectedGenres.join(' • ')
        : 'Amapiano';
    final languagesString = state.selectedLanguages.isNotEmpty
        ? state.selectedLanguages.join(' • ')
        : state.primaryLanguage;

    return [
      CreatorDnaNode(
        index: 0,
        type: DnaNodeType.craftPersona,
        title: friendlyRole,
        traitLabel: 'CRAFT PERSONA',
        description:
            'Your core creative archetype: $friendlyRole. Calibrated to African sonic heritage and DAW workflows.',
        accentColor: const Color(0xFFF97316),
        icon: PhosphorIconsBold.sparkle,
        status: GenomicStatus.sequenced,
        dnaPowerBonus: 15,
      ),
      CreatorDnaNode(
        index: 1,
        type: DnaNodeType.generationEra,
        title: 'Born ${state.birthYear} • ${era.label}',
        traitLabel: 'GENERATION ERA',
        description: era.description,
        accentColor: const Color(0xFF06B6D4),
        icon: PhosphorIconsBold.calendar,
        status: GenomicStatus.sequenced,
        dnaPowerBonus: 15,
      ),
      CreatorDnaNode(
        index: 2,
        type: DnaNodeType.linguisticRoots,
        title: languagesString,
        traitLabel: 'LINGUISTIC ROOTS',
        description:
            'Rooted in ${state.culturalHeritage} with tonal language cadence and vernacular lyricism.',
        accentColor: const Color(0xFF10B981),
        icon: PhosphorIconsBold.translate,
        status: GenomicStatus.sequenced,
        dnaPowerBonus: 15,
      ),
      CreatorDnaNode(
        index: 3,
        type: DnaNodeType.sonicGenres,
        title: genresString,
        traitLabel: 'SONIC GENRES',
        description:
            'Affinities tuned to ${state.generationEra.label}. Primary groove tempo at ${state.tempoPreference.toUpperCase()}.',
        accentColor: const Color(0xFFF59E0B),
        icon: PhosphorIconsBold.disc,
        status: GenomicStatus.sequenced,
        dnaPowerBonus: 15,
      ),
      const CreatorDnaNode(
        index: 4,
        type: DnaNodeType.voiceSignature,
        title: 'Vocal Timbre & Harmonic Formants',
        traitLabel: 'VOICE SIGNATURE',
        description:
            'Micro-tonal vocal resonance profile, formant tracking, and melodic inflection DNA.',
        questInstruction:
            'Record a 20s voice take in Studio to sequence your vocal timbre.',
        questActionRoute: '/studio/record',
        accentColor: Color(0xFF8B5CF6),
        icon: PhosphorIconsBold.microphone,
        status: GenomicStatus.lockedQuest,
        dnaPowerBonus: 15,
      ),
      const CreatorDnaNode(
        index: 5,
        type: DnaNodeType.grooveArchitect,
        title: 'Log-Drum & Poly-Meter Matrix',
        traitLabel: 'GROOVE ARCHITECT',
        description:
            'Percussive syncopation patterns, 3-step kicks, and log-drum bass velocity dynamics.',
        questInstruction:
            'Build a 5-channel log-drum groove in Sketchpad.',
        questActionRoute: '/studio/sketchpad',
        accentColor: Color(0xFFEC4899),
        icon: PhosphorIconsBold.waveSine,
        status: GenomicStatus.lockedQuest,
        dnaPowerBonus: 15,
      ),
      const CreatorDnaNode(
        index: 6,
        type: DnaNodeType.coCreationLineage,
        title: 'Sovereign Stem-Flip Lineage',
        traitLabel: 'CO-CREATION LINEAGE',
        description:
            'Smart contract attribution tree, remix royalties, and collaborative splits.',
        questInstruction: 'Drop an Open-Verse or Stem-Flip on Explore.',
        questActionRoute: '/explore',
        accentColor: Color(0xFF14B8A6),
        icon: PhosphorIconsBold.gitFork,
        status: GenomicStatus.lockedQuest,
        dnaPowerBonus: 15,
      ),
      const CreatorDnaNode(
        index: 7,
        type: DnaNodeType.arTastemaker,
        title: 'Decentralized Crate Curator',
        traitLabel: 'AR TASTEMAKER',
        description:
            'Curatorial weight in algorithmic Fresh Crate discovery and community voting.',
        questInstruction: 'Co-sign emerging artists in the Fresh Crate.',
        questActionRoute: '/explore',
        accentColor: Color(0xFFEAB308),
        icon: PhosphorIconsBold.flame,
        status: GenomicStatus.lockedQuest,
        dnaPowerBonus: 15,
      ),
    ];
  }

  /// Constructs the 8 nodes from a persistable [CreatorDnaProfile] (REQ-P49-LAB-01..02).
  static List<CreatorDnaNode> fromCreatorDnaProfile(CreatorDnaProfile profile) {
    final friendlyRole = profile.creativeRole.friendlyTitle;
    final genresString = profile.topGenres(3).isNotEmpty
        ? profile.topGenres(3).join(' • ')
        : 'Amapiano';

    return [
      CreatorDnaNode(
        index: 0,
        type: DnaNodeType.craftPersona,
        title: friendlyRole,
        traitLabel: 'CRAFT PERSONA',
        description:
            'Your core creative archetype: $friendlyRole. Level: ${profile.lifecycleState.name.toUpperCase()}.',
        accentColor: const Color(0xFFF97316),
        icon: PhosphorIconsBold.sparkle,
        status: GenomicStatus.sequenced,
        dnaPowerBonus: 15,
      ),
      const CreatorDnaNode(
        index: 1,
        type: DnaNodeType.generationEra,
        title: 'African Sonic Heritage',
        traitLabel: 'GENERATION ERA',
        description:
            'Attuned to continental polyrhythms and modern electronic movements.',
        accentColor: Color(0xFF06B6D4),
        icon: PhosphorIconsBold.calendar,
        status: GenomicStatus.sequenced,
        dnaPowerBonus: 15,
      ),
      CreatorDnaNode(
        index: 2,
        type: DnaNodeType.linguisticRoots,
        title: profile.primaryLanguage,
        traitLabel: 'LINGUISTIC ROOTS',
        description:
            'Primary linguistic inflection: ${profile.primaryLanguage} with tonal vocal expression.',
        accentColor: const Color(0xFF10B981),
        icon: PhosphorIconsBold.translate,
        status: GenomicStatus.sequenced,
        dnaPowerBonus: 15,
      ),
      CreatorDnaNode(
        index: 3,
        type: DnaNodeType.sonicGenres,
        title: genresString,
        traitLabel: 'SONIC GENRES',
        description:
            'Active genre affinities. Tempo feel: ${profile.tempoPreference.toUpperCase()}.',
        accentColor: const Color(0xFFF59E0B),
        icon: PhosphorIconsBold.disc,
        status: GenomicStatus.sequenced,
        dnaPowerBonus: 15,
      ),
      const CreatorDnaNode(
        index: 4,
        type: DnaNodeType.voiceSignature,
        title: 'Vocal Timbre & Harmonic Formants',
        traitLabel: 'VOICE SIGNATURE',
        description:
            'Micro-tonal vocal resonance profile, formant tracking, and melodic inflection DNA.',
        questInstruction:
            'Record a 20s voice take in Studio to sequence your vocal timbre.',
        questActionRoute: '/studio/record',
        accentColor: Color(0xFF8B5CF6),
        icon: PhosphorIconsBold.microphone,
        status: GenomicStatus.lockedQuest,
        dnaPowerBonus: 15,
      ),
      const CreatorDnaNode(
        index: 5,
        type: DnaNodeType.grooveArchitect,
        title: 'Log-Drum & Poly-Meter Matrix',
        traitLabel: 'GROOVE ARCHITECT',
        description:
            'Percussive syncopation patterns, 3-step kicks, and log-drum bass velocity dynamics.',
        questInstruction:
            'Build a 5-channel log-drum groove in Sketchpad.',
        questActionRoute: '/studio/sketchpad',
        accentColor: Color(0xFFEC4899),
        icon: PhosphorIconsBold.waveSine,
        status: GenomicStatus.lockedQuest,
        dnaPowerBonus: 15,
      ),
      const CreatorDnaNode(
        index: 6,
        type: DnaNodeType.coCreationLineage,
        title: 'Sovereign Stem-Flip Lineage',
        traitLabel: 'CO-CREATION LINEAGE',
        description:
            'Smart contract attribution tree, remix royalties, and collaborative splits.',
        questInstruction: 'Drop an Open-Verse or Stem-Flip on Explore.',
        questActionRoute: '/explore',
        accentColor: Color(0xFF14B8A6),
        icon: PhosphorIconsBold.gitFork,
        status: GenomicStatus.lockedQuest,
        dnaPowerBonus: 15,
      ),
      const CreatorDnaNode(
        index: 7,
        type: DnaNodeType.arTastemaker,
        title: 'Decentralized Crate Curator',
        traitLabel: 'AR TASTEMAKER',
        description:
            'Curatorial weight in algorithmic Fresh Crate discovery and community voting.',
        questInstruction: 'Co-sign emerging artists in the Fresh Crate.',
        questActionRoute: '/explore',
        accentColor: Color(0xFFEAB308),
        icon: PhosphorIconsBold.flame,
        status: GenomicStatus.lockedQuest,
        dnaPowerBonus: 15,
      ),
    ];
  }
}

