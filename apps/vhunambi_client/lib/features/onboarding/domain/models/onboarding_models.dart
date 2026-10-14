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
