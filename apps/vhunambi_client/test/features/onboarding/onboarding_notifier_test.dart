import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/features/onboarding/presentation/providers/onboarding_providers.dart';

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
  });
}
