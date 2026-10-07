import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  void completeOnboarding() {
    state = state.copyWith(hasCompletedOnboarding: true);
  }

  void resetOnboarding() {
    state = const OnboardingState();
  }
}

final onboardingStateProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  return OnboardingNotifier();
});
