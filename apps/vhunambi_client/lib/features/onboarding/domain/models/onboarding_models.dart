import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:vhunambi_client/features/creator_dna/domain/entities/creator_dna_profile.dart';

/// Cultural and chronological generation era derived from the creator's birth year (REQ-P49-ROOTS-01..03).
enum SonicGenerationEra {
  era80sGolden,
  era90sKwaitoHouse,
  era2000sPianoGqom,
  era2011NextGenKinetic;

  String get label {
    switch (this) {
      case SonicGenerationEra.era80sGolden:
        return '80s Heritage & Golden Era';
      case SonicGenerationEra.era90sKwaitoHouse:
        return '90s Kwaito & House Era';
      case SonicGenerationEra.era2000sPianoGqom:
        return '2000s Piano & Gqom Wave';
      case SonicGenerationEra.era2011NextGenKinetic:
        return 'Next-Gen Kinetic & Sgija Era';
    }
  }

  String get description {
    switch (this) {
      case SonicGenerationEra.era80sGolden:
        return 'Mbaqanga brass, Bubblegum synths, and classic Maskandi finger-picking';
      case SonicGenerationEra.era90sKwaitoHouse:
        return '110 BPM township house, Kwaito kicks, and pioneering Afro-House';
      case SonicGenerationEra.era2000sPianoGqom:
        return 'Soulful Rhodes keys, deep house chords, and Durban broken-beat Gqom';
      case SonicGenerationEra.era2011NextGenKinetic:
        return 'Amapiano log drums, private school horns, and 3-step kinetic polyrhythms';
    }
  }

  List<String> get recommendedGenres {
    switch (this) {
      case SonicGenerationEra.era80sGolden:
        return const ['Mbaqanga', 'Maskandi', 'African Gospel', 'Kwaito'];
      case SonicGenerationEra.era90sKwaitoHouse:
        return const ['Kwaito', 'Afro House', 'Maskandi', 'SA Hip-Hop'];
      case SonicGenerationEra.era2000sPianoGqom:
        return const ['Amapiano', 'Private School Piano', 'Gqom', 'Afrobeats'];
      case SonicGenerationEra.era2011NextGenKinetic:
        return const ['Amapiano', 'Shangaan Electro', 'Gqom', 'Afrobeats'];
    }
  }

  static SonicGenerationEra fromBirthYear(int year) {
    if (year <= 1989) return SonicGenerationEra.era80sGolden;
    if (year <= 1999) return SonicGenerationEra.era90sKwaitoHouse;
    if (year <= 2010) return SonicGenerationEra.era2000sPianoGqom;
    return SonicGenerationEra.era2011NextGenKinetic;
  }
}

@immutable
class OnboardingState {
  final bool hasCompletedOnboarding;
  final List<String> selectedGenres;
  final List<String> selectedLanguages;
  final String userRole;

  // Adaptive Creator DNA fields
  final CreativeRole creativeRole;
  final ExperienceLevel experienceLevel;
  final String primaryLanguage;
  final List<String> selectedMoods;
  final String tempoPreference;
  final String vocalEnergyPreference;
  final double onboardingCompleteness;

  // Phase 49: Birth Year, Generation Era & Cultural Roots
  final int birthYear;
  final SonicGenerationEra generationEra;
  final String culturalHeritage;

  const OnboardingState({
    this.hasCompletedOnboarding = false,
    this.selectedGenres = const ['Amapiano', 'Afro House'],
    this.selectedLanguages = const ['Tshivenḓa', 'isiZulu', 'English'],
    this.userRole = 'Creator',
    this.creativeRole = CreativeRole.producer,
    this.experienceLevel = ExperienceLevel.newbie,
    this.primaryLanguage = 'English',
    this.selectedMoods = const ['Energetic', 'Chill'],
    this.tempoPreference = 'medium',
    this.vocalEnergyPreference = 'balanced',
    this.onboardingCompleteness = 0.0,
    this.birthYear = 2002,
    this.generationEra = SonicGenerationEra.era2000sPianoGqom,
    this.culturalHeritage = 'Tshivenḓa & Zulu Roots',
  });

  OnboardingState copyWith({
    bool? hasCompletedOnboarding,
    List<String>? selectedGenres,
    List<String>? selectedLanguages,
    String? userRole,
    CreativeRole? creativeRole,
    ExperienceLevel? experienceLevel,
    String? primaryLanguage,
    List<String>? selectedMoods,
    String? tempoPreference,
    String? vocalEnergyPreference,
    double? onboardingCompleteness,
    int? birthYear,
    SonicGenerationEra? generationEra,
    String? culturalHeritage,
  }) {
    final effectiveYear = birthYear ?? this.birthYear;
    return OnboardingState(
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      selectedGenres: selectedGenres ?? this.selectedGenres,
      selectedLanguages: selectedLanguages ?? this.selectedLanguages,
      userRole: userRole ?? this.userRole,
      creativeRole: creativeRole ?? this.creativeRole,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      primaryLanguage: primaryLanguage ?? this.primaryLanguage,
      selectedMoods: selectedMoods ?? this.selectedMoods,
      tempoPreference: tempoPreference ?? this.tempoPreference,
      vocalEnergyPreference:
          vocalEnergyPreference ?? this.vocalEnergyPreference,
      onboardingCompleteness:
          onboardingCompleteness ?? this.onboardingCompleteness,
      birthYear: effectiveYear,
      generationEra:
          generationEra ??
          (birthYear != null
              ? SonicGenerationEra.fromBirthYear(effectiveYear)
              : this.generationEra),
      culturalHeritage: culturalHeritage ?? this.culturalHeritage,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'hasCompletedOnboarding': hasCompletedOnboarding,
    'selectedGenres': selectedGenres,
    'selectedLanguages': selectedLanguages,
    'userRole': userRole,
    'creativeRole': creativeRole.name,
    'experienceLevel': experienceLevel.name,
    'primaryLanguage': primaryLanguage,
    'selectedMoods': selectedMoods,
    'tempoPreference': tempoPreference,
    'vocalEnergyPreference': vocalEnergyPreference,
    'onboardingCompleteness': onboardingCompleteness,
    'birthYear': birthYear,
    'generationEra': generationEra.name,
    'culturalHeritage': culturalHeritage,
  };

  factory OnboardingState.fromJson(Map<String, dynamic> json) {
    final birthYear = (json['birthYear'] as num?)?.toInt() ?? 2002;
    final rawGenres = json['selectedGenres'] as List<dynamic>?;
    final rawLanguages = json['selectedLanguages'] as List<dynamic>?;
    final rawMoods = json['selectedMoods'] as List<dynamic>?;
    final roleName = json['creativeRole'] as String?;
    final expName = json['experienceLevel'] as String?;
    final eraName = json['generationEra'] as String?;

    return OnboardingState(
      hasCompletedOnboarding: json['hasCompletedOnboarding'] as bool? ?? false,
      selectedGenres: rawGenres == null || rawGenres.isEmpty
          ? const ['Amapiano', 'Afro House']
          : rawGenres.map((e) => e.toString()).toList(),
      selectedLanguages: rawLanguages == null || rawLanguages.isEmpty
          ? const ['Tshivenḓa', 'isiZulu', 'English']
          : rawLanguages.map((e) => e.toString()).toList(),
      userRole: json['userRole'] as String? ?? 'Creator',
      creativeRole: CreativeRole.values.firstWhere(
        (r) => r.name == roleName,
        orElse: () => CreativeRole.producer,
      ),
      experienceLevel: ExperienceLevel.values.firstWhere(
        (e) => e.name == expName,
        orElse: () => ExperienceLevel.newbie,
      ),
      primaryLanguage: json['primaryLanguage'] as String? ?? 'English',
      selectedMoods: rawMoods == null || rawMoods.isEmpty
          ? const ['Energetic', 'Chill']
          : rawMoods.map((e) => e.toString()).toList(),
      tempoPreference: json['tempoPreference'] as String? ?? 'medium',
      vocalEnergyPreference:
          json['vocalEnergyPreference'] as String? ?? 'balanced',
      onboardingCompleteness:
          (json['onboardingCompleteness'] as num?)?.toDouble() ?? 0.0,
      birthYear: birthYear,
      generationEra: eraName != null
          ? SonicGenerationEra.values.firstWhere(
              (era) => era.name == eraName,
              orElse: () => SonicGenerationEra.fromBirthYear(birthYear),
            )
          : SonicGenerationEra.fromBirthYear(birthYear),
      culturalHeritage:
          json['culturalHeritage'] as String? ?? 'Tshivenḓa & Zulu Roots',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnboardingState &&
          runtimeType == other.runtimeType &&
          hasCompletedOnboarding == other.hasCompletedOnboarding &&
          listEquals(selectedGenres, other.selectedGenres) &&
          listEquals(selectedLanguages, other.selectedLanguages) &&
          userRole == other.userRole &&
          creativeRole == other.creativeRole &&
          experienceLevel == other.experienceLevel &&
          primaryLanguage == other.primaryLanguage &&
          listEquals(selectedMoods, other.selectedMoods) &&
          tempoPreference == other.tempoPreference &&
          vocalEnergyPreference == other.vocalEnergyPreference &&
          onboardingCompleteness == other.onboardingCompleteness;

  @override
  int get hashCode => Object.hash(
    hasCompletedOnboarding,
    Object.hashAll(selectedGenres),
    Object.hashAll(selectedLanguages),
    userRole,
    creativeRole,
    experienceLevel,
    primaryLanguage,
    Object.hashAll(selectedMoods),
    tempoPreference,
    vocalEnergyPreference,
    onboardingCompleteness,
  );
}

/// The 12 distinct African genres curated for the Vhunambi onboarding deck (REQ-P47-BUG-02).
@immutable
class AfricanGenreModel {
  final String id;
  final String name;
  final String region;
  final Color accentColor;
  final String description;

  const AfricanGenreModel({
    required this.id,
    required this.name,
    required this.region,
    required this.accentColor,
    required this.description,
  });
}

const List<AfricanGenreModel> kAfricanOnboardingGenres = [
  AfricanGenreModel(
    id: 'amapiano',
    name: 'Amapiano',
    region: 'South Africa',
    accentColor: Color(0xFFF97316),
    description: 'Deep house, jazz chords, and resonant sub-bass log drums',
  ),
  AfricanGenreModel(
    id: 'private_school_piano',
    name: 'Private School Piano',
    region: 'South Africa',
    accentColor: Color(0xFFF59E0B),
    description: 'Sophisticated soulful keys and warm horn arrangements',
  ),
  AfricanGenreModel(
    id: 'gqom',
    name: 'Gqom',
    region: 'Durban, South Africa',
    accentColor: Color(0xFF06B6D4),
    description: 'Raw, minimalistic, broken-beat club energy',
  ),
  AfricanGenreModel(
    id: 'maskandi',
    name: 'Maskandi',
    region: 'KwaZulu-Natal',
    accentColor: Color(0xFF10B981),
    description: 'Acoustic Zulu guitar picking and praise-poetry',
  ),
  AfricanGenreModel(
    id: 'afro_house',
    name: 'Afro House',
    region: 'South Africa / Angola',
    accentColor: Color(0xFF8B5CF6),
    description: 'Deep tribal percussion and spiritual vocal chants',
  ),
  AfricanGenreModel(
    id: 'kwaito',
    name: 'Kwaito',
    region: 'Soweto, South Africa',
    accentColor: Color(0xFFEC4899),
    description: 'Slow-tempo house with township chants and 90s swagger',
  ),
  AfricanGenreModel(
    id: 'afrobeats',
    name: 'Afrobeats',
    region: 'West Africa (Nigeria / Ghana)',
    accentColor: Color(0xFF3B82F6),
    description: 'Infectious pop grooves, syncopated polyrhythms, and brass',
  ),
  AfricanGenreModel(
    id: 'sa_hip_hop',
    name: 'SA Hip-Hop',
    region: 'South Africa',
    accentColor: Color(0xFFEF4444),
    description: 'Boom-bap and trap laced with vernacular punchlines',
  ),
  AfricanGenreModel(
    id: 'african_gospel',
    name: 'African Gospel',
    region: 'Pan-African',
    accentColor: Color(0xFFEAB308),
    description: 'Uplifting choral harmonies, brass, and organ grooves',
  ),
  AfricanGenreModel(
    id: 'mbaqanga',
    name: 'Mbaqanga',
    region: 'South Africa',
    accentColor: Color(0xFF14B8A6),
    description: 'Township jive, groaning basslines, and brass riffs',
  ),
  AfricanGenreModel(
    id: 'shangaan_electro',
    name: 'Shangaan Electro',
    region: 'Limpopo, South Africa',
    accentColor: Color(0xFFD946EF),
    description: 'High-speed 180 BPM electronic marimba grooves',
  ),
  AfricanGenreModel(
    id: 'bongo_flava',
    name: 'Bongo Flava',
    region: 'Tanzania / East Africa',
    accentColor: Color(0xFF6366F1),
    description: 'Swahili melodies blending R&B, Taarab, and Afro-pop',
  ),
];
