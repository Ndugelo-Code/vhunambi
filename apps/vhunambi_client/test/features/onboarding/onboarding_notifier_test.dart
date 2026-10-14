import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:vhunambi_client/features/creator_dna/domain/entities/creator_dna_profile.dart';

void main() {
  group('OnboardingNotifier Unit Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state has default genres, languages and not completed', () {
      final state = container.read(onboardingStateProvider);

      expect(state.hasCompletedOnboarding, isFalse);
      expect(state.selectedGenres, contains('Amapiano'));
      expect(state.selectedLanguages, contains('Tshivenḓa'));
      expect(state.userRole, 'Creator');
    });

    test('toggleGenre adds and removes genres correctly', () {
      final notifier = container.read(onboardingStateProvider.notifier);

      // Add 'Gqom'
      notifier.toggleGenre('Gqom');
      expect(container.read(onboardingStateProvider).selectedGenres, contains('Gqom'));

      // Remove 'Gqom'
      notifier.toggleGenre('Gqom');
      expect(container.read(onboardingStateProvider).selectedGenres, isNot(contains('Gqom')));

      // Cannot remove all genres (prevents empty list)
      notifier.toggleGenre('Amapiano'); // Amapiano removed, Afro House remains
      expect(container.read(onboardingStateProvider).selectedGenres.length, 1);
      notifier.toggleGenre('Afro House'); // Should remain because length is 1
      expect(container.read(onboardingStateProvider).selectedGenres, contains('Afro House'));
    });

    test('toggleLanguage adds and removes languages correctly', () {
      final notifier = container.read(onboardingStateProvider.notifier);

      // Add 'Kiswahili'
      notifier.toggleLanguage('Kiswahili');
      expect(container.read(onboardingStateProvider).selectedLanguages, contains('Kiswahili'));

      // Remove 'Kiswahili'
      notifier.toggleLanguage('Kiswahili');
      expect(container.read(onboardingStateProvider).selectedLanguages, isNot(contains('Kiswahili')));
    });

    test('setUserRole updates role correctly', () {
      final notifier = container.read(onboardingStateProvider.notifier);

      notifier.setUserRole('Producer');
      expect(container.read(onboardingStateProvider).userRole, 'Producer');
    });

    test('completeOnboarding sets flag to true', () {
      final notifier = container.read(onboardingStateProvider.notifier);

      notifier.completeOnboarding();
      expect(container.read(onboardingStateProvider).hasCompletedOnboarding, isTrue);
    });

    test('resetOnboarding resets state back to default', () {
      final notifier = container.read(onboardingStateProvider.notifier);

      notifier.setUserRole('Listener');
      notifier.completeOnboarding();
      expect(container.read(onboardingStateProvider).hasCompletedOnboarding, isTrue);

      notifier.resetOnboarding();
      expect(container.read(onboardingStateProvider).hasCompletedOnboarding, isFalse);
      expect(container.read(onboardingStateProvider).userRole, 'Creator');
    });

    // T7.1 — New DNA setter tests (REQ-DNA-OB-12)
    test('setCreativeRole updates creativeRole correctly', () {
      final notifier = container.read(onboardingStateProvider.notifier);

      notifier.setCreativeRole(CreativeRole.vocalist);
      expect(
        container.read(onboardingStateProvider).creativeRole,
        CreativeRole.vocalist,
      );

      notifier.setCreativeRole(CreativeRole.songwriter);
      expect(
        container.read(onboardingStateProvider).creativeRole,
        CreativeRole.songwriter,
      );
    });

    test('setExperienceLevel updates experienceLevel correctly', () {
      final notifier = container.read(onboardingStateProvider.notifier);

      notifier.setExperienceLevel(ExperienceLevel.growing);
      expect(
        container.read(onboardingStateProvider).experienceLevel,
        ExperienceLevel.growing,
      );

      notifier.setExperienceLevel(ExperienceLevel.pro);
      expect(
        container.read(onboardingStateProvider).experienceLevel,
        ExperienceLevel.pro,
      );
    });

    test('setPrimaryLanguage sets primaryLanguage and adds to selectedLanguages', () {
      final notifier = container.read(onboardingStateProvider.notifier);

      notifier.setPrimaryLanguage('isiXhosa');
      final state = container.read(onboardingStateProvider);
      expect(state.primaryLanguage, 'isiXhosa');
      expect(state.selectedLanguages, contains('isiXhosa'));
    });

    test('setPrimaryLanguage does not duplicate if already in selectedLanguages', () {
      final notifier = container.read(onboardingStateProvider.notifier);

      // Tshivenḓa is already in the default selectedLanguages.
      notifier.setPrimaryLanguage('Tshivenḓa');
      final langs = container.read(onboardingStateProvider).selectedLanguages;
      expect(langs.where((l) => l == 'Tshivenḓa').length, 1);
    });

    test('toggleMood adds and removes moods correctly, minimum 1 preserved', () {
      final notifier = container.read(onboardingStateProvider.notifier);

      // Default moods: ['Energetic', 'Chill']
      notifier.toggleMood('Nostalgic');
      expect(container.read(onboardingStateProvider).selectedMoods, contains('Nostalgic'));

      notifier.toggleMood('Nostalgic');
      expect(
        container.read(onboardingStateProvider).selectedMoods,
        isNot(contains('Nostalgic')),
      );

      // Cannot remove last mood — remove 'Chill' then try to remove 'Energetic'
      notifier.toggleMood('Chill'); // removes Chill (2→1)
      notifier.toggleMood('Energetic'); // should stay (length is 1)
      expect(container.read(onboardingStateProvider).selectedMoods, contains('Energetic'));
    });

    test('setTempoPreference updates tempoPreference', () {
      final notifier = container.read(onboardingStateProvider.notifier);

      notifier.setTempoPreference('fast');
      expect(container.read(onboardingStateProvider).tempoPreference, 'fast');

      notifier.setTempoPreference('slow');
      expect(container.read(onboardingStateProvider).tempoPreference, 'slow');
    });

    test('setVocalEnergyPreference updates vocalEnergyPreference', () {
      final notifier = container.read(onboardingStateProvider.notifier);

      notifier.setVocalEnergyPreference('intense');
      expect(container.read(onboardingStateProvider).vocalEnergyPreference, 'intense');

      notifier.setVocalEnergyPreference('soft');
      expect(container.read(onboardingStateProvider).vocalEnergyPreference, 'soft');
    });

    test('DNA setter changes do not break original fields', () {
      final notifier = container.read(onboardingStateProvider.notifier);

      notifier.setCreativeRole(CreativeRole.multiHyphenate);
      notifier.setPrimaryLanguage('Sesotho');
      notifier.toggleMood('Dark');
      notifier.setTempoPreference('hyperspeed');

      final state = container.read(onboardingStateProvider);
      // Original fields must remain intact
      expect(state.hasCompletedOnboarding, isFalse);
      expect(state.selectedGenres, contains('Amapiano'));
      expect(state.userRole, 'Creator');
      // DNA fields updated correctly
      expect(state.creativeRole, CreativeRole.multiHyphenate);
      expect(state.primaryLanguage, 'Sesotho');
      expect(state.selectedMoods, contains('Dark'));
      expect(state.tempoPreference, 'hyperspeed');
    });
  });
}

