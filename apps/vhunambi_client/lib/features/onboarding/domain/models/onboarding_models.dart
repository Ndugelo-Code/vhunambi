import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:vhunambi_client/features/creator_dna/domain/entities/creator_dna_profile.dart';

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
  }) {
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
