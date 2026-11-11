import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/storage/sovereign_domain_repositories.dart';
import 'package:vhunambi_client/features/creator_dna/domain/entities/creator_dna_profile.dart';
import '../../domain/models/onboarding_models.dart';

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier() : super(_hydrateInitialState());

  static OnboardingState _hydrateInitialState() {
    if (!SovereignDomainStorageMode.canHydrateFromStorage(
      AppConstants.tokenBoxKey,
    )) {
      return const OnboardingState();
    }

    try {
      final stored = SovereignPrefsRepository.loadOnboardingState();
      if (stored != null) {
        return OnboardingState.fromJson(stored);
      }

      if (!kIsWeb && Hive.isBoxOpen(AppConstants.creatorDnaBoxKey)) {
        final dnaBox = Hive.box<dynamic>(AppConstants.creatorDnaBoxKey);
        final rawDna = dnaBox.get('dna_profile');
        if (rawDna is Map) {
          final map = Map<String, dynamic>.from(rawDna);
          if (map['onboardingCompleted'] == true) {
            final genreWeights = map['genreWeights'];
            final langWeights = map['languageWeights'];
            final roleName = map['creativeRole'] as String?;
            final expName = map['experienceLevel'] as String?;
            return OnboardingState(
              hasCompletedOnboarding: true,
              selectedGenres: genreWeights is Map && genreWeights.isNotEmpty
                  ? genreWeights.keys.map((k) => k.toString()).toList()
                  : const ['Amapiano', 'Afro House'],
              selectedLanguages: langWeights is Map && langWeights.isNotEmpty
                  ? langWeights.keys.map((k) => k.toString()).toList()
                  : const ['Tshivenḓa', 'isiZulu', 'English'],
              creativeRole: CreativeRole.values.firstWhere(
                (r) => r.name == roleName,
                orElse: () => CreativeRole.producer,
              ),
              experienceLevel: ExperienceLevel.values.firstWhere(
                (e) => e.name == expName,
                orElse: () => ExperienceLevel.newbie,
              ),
              primaryLanguage: map['primaryLanguage'] as String? ?? 'English',
              tempoPreference: map['tempoPreference'] as String? ?? 'medium',
              vocalEnergyPreference:
                  map['vocalEnergyPreference'] as String? ?? 'balanced',
              onboardingCompleteness:
                  (map['onboardingCompleteness'] as num?)?.toDouble() ?? 1.0,
            );
          }
        }
      }
    } catch (_) {}

    return const OnboardingState();
  }

  void _persist() {
    unawaited(SovereignPrefsRepository.saveOnboardingState(state.toJson()));
  }

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
    _persist();
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
    _persist();
  }

  void setUserRole(String role) {
    state = state.copyWith(userRole: role);
    _persist();
  }

  void setCreativeRole(CreativeRole role) {
    state = state.copyWith(creativeRole: role);
    _persist();
  }

  void setExperienceLevel(ExperienceLevel level) {
    state = state.copyWith(experienceLevel: level);
    _persist();
  }

  void setPrimaryLanguage(String language) {
    final langs = List<String>.from(state.selectedLanguages);
    if (!langs.contains(language)) {
      langs.add(language);
    }
    state = state.copyWith(primaryLanguage: language, selectedLanguages: langs);
    _persist();
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
    _persist();
  }

  void setTempoPreference(String tempo) {
    state = state.copyWith(tempoPreference: tempo);
    _persist();
  }

  // Phase 49: Birth Year, Generation Era & Cultural Roots
  void setBirthYear(int year) {
    final era = SonicGenerationEra.fromBirthYear(year);
    state = state.copyWith(birthYear: year, generationEra: era);
    _persist();
  }

  void setCulturalHeritage(String heritage) {
    state = state.copyWith(culturalHeritage: heritage);
    _persist();
  }

  void autotuneEraGenres() {
    final eraGenres = state.generationEra.recommendedGenres;
    final merged = {...state.selectedGenres, ...eraGenres}.toList();
    state = state.copyWith(selectedGenres: merged);
    _persist();
  }

  void setVocalEnergyPreference(String energy) {
    state = state.copyWith(vocalEnergyPreference: energy);
    _persist();
  }

  void setCompleteness(double completeness) {
    state = state.copyWith(
      onboardingCompleteness: completeness.clamp(0.0, 1.0),
    );
    _persist();
  }

  void completeOnboarding() {
    state = state.copyWith(
      hasCompletedOnboarding: true,
      onboardingCompleteness: 1.0,
    );
    _persist();
  }

  void resetOnboarding() {
    state = const OnboardingState();
    _persist();
  }
}

final onboardingStateProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
      return OnboardingNotifier();
    });
