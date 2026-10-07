import 'package:flutter/foundation.dart';

@immutable
class OnboardingState {
  final bool hasCompletedOnboarding;
  final List<String> selectedGenres;
  final List<String> selectedLanguages;
  final String userRole;

  const OnboardingState({
    this.hasCompletedOnboarding = false,
    this.selectedGenres = const ['Amapiano', 'Afro House'],
    this.selectedLanguages = const ['Tshivenḓa', 'isiZulu', 'English'],
    this.userRole = 'Creator',
  });

  OnboardingState copyWith({
    bool? hasCompletedOnboarding,
    List<String>? selectedGenres,
    List<String>? selectedLanguages,
    String? userRole,
  }) {
    return OnboardingState(
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      selectedGenres: selectedGenres ?? this.selectedGenres,
      selectedLanguages: selectedLanguages ?? this.selectedLanguages,
      userRole: userRole ?? this.userRole,
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
          userRole == other.userRole;

  @override
  int get hashCode => Object.hash(
        hasCompletedOnboarding,
        Object.hashAll(selectedGenres),
        Object.hashAll(selectedLanguages),
        userRole,
      );
}
