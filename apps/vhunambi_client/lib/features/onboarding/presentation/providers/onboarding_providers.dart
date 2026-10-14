import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/features/creator_dna/domain/entities/creator_dna_profile.dart';
import '../../domain/models/onboarding_models.dart';

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier() : super(const OnboardingState());

  void toggleGenre(String genre) {
    final current = List<String>.from(state.selectedGenres);
    if (current.contains(genre)) {
      if (current.length > 1) {
        current.remove(genre);
      }
    } else {
      current.add(genre);
    }
    state = state.copyWith(selectedGenres: current);
  }

  void toggleLanguage(String language) {
    final current = List<String>.from(state.selectedLanguages);
    if (current.contains(language)) {
      if (current.length > 1) {
        current.remove(language);
      }
    } else {
      current.add(language);
    }
    state = state.copyWith(selectedLanguages: current);
  }

  void setUserRole(String role) {
    state = state.copyWith(userRole: role);
  }

  void setCreativeRole(CreativeRole role) {
    state = state.copyWith(creativeRole: role);
  }

  void setExperienceLevel(ExperienceLevel level) {
    state = state.copyWith(experienceLevel: level);
  }

  void setPrimaryLanguage(String language) {
    final langs = List<String>.from(state.selectedLanguages);
    if (!langs.contains(language)) {
      langs.add(language);
    }
    state = state.copyWith(
      primaryLanguage: language,
      selectedLanguages: langs,
    );
  }

  void toggleMood(String mood) {
    final current = List<String>.from(state.selectedMoods);
    if (current.contains(mood)) {
      if (current.length > 1) {
        current.remove(mood);
      }
    } else {
      current.add(mood);
    }
    state = state.copyWith(selectedMoods: current);
  }

  void setTempoPreference(String tempo) {
    state = state.copyWith(tempoPreference: tempo);
  }

  void setVocalEnergyPreference(String energy) {
    state = state.copyWith(vocalEnergyPreference: energy);
  }

  void setCompleteness(double completeness) {
    state = state.copyWith(onboardingCompleteness: completeness.clamp(0.0, 1.0));
  }

  void completeOnboarding() {
    state = state.copyWith(
      hasCompletedOnboarding: true,
      onboardingCompleteness: 1.0,
    );
  }

  void resetOnboarding() {
    state = const OnboardingState();
  }
}

final onboardingStateProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  return OnboardingNotifier();
});
