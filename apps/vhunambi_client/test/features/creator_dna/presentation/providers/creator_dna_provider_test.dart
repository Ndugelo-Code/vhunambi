import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/creator_dna/data/repositories/creator_dna_repository.dart';
import 'package:vhunambi_client/features/creator_dna/domain/entities/creator_dna_profile.dart';
import 'package:vhunambi_client/features/creator_dna/domain/models/behavior_event.dart';
import 'package:vhunambi_client/features/creator_dna/presentation/providers/creator_dna_provider.dart';
import 'package:vhunambi_client/features/creator_dna/presentation/providers/dna_studio_defaults_provider.dart';
import 'package:vhunambi_client/features/studio/domain/models/studio_form_state.dart';

void main() {
  group('CreatorDnaProvider & Notifier', () {
    late CreatorDnaRepository repository;
    late ProviderContainer container;

    setUp(() {
      repository = CreatorDnaRepository();
      container = ProviderContainer(
        overrides: [
          creatorDnaRepositoryProvider.overrideWithValue(repository),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state matches CreatorDnaProfile.initial()', () {
      final dna = container.read(creatorDnaProvider);

      expect(dna.lifecycleState, DnaLifecycleState.uninitialized);
      expect(dna.onboardingCompleted, isFalse);
      expect(dna.totalBehaviorEvents, 0);
    });

    test('seedFromOnboarding sets genres, languages, and transitions to seeded', () async {
      final notifier = container.read(creatorDnaProvider.notifier);

      await notifier.seedFromOnboarding(
        role: CreativeRole.producer,
        experienceLevel: ExperienceLevel.pro,
        selectedGenres: ['Amapiano', 'Afro Tech'],
        primaryLanguage: 'isiZulu',
        secondaryLanguages: ['English'],
        tempoPreference: 'fast',
        vocalEnergyPreference: 'intense',
        selectedMoods: ['Energetic'],
        completeness: 1.0,
      );

      final state = container.read(creatorDnaProvider);
      expect(state.creativeRole, CreativeRole.producer);
      expect(state.experienceLevel, ExperienceLevel.pro);
      expect(state.genreWeights['Amapiano'], 1.0);
      expect(state.genreWeights['Afro Tech'], 1.0);
      expect(state.languageWeights['isiZulu'], 1.5);
      expect(state.primaryLanguage, 'isiZulu');
      expect(state.lifecycleState, DnaLifecycleState.seeded);
      expect(state.onboardingCompleted, isTrue);
    });

    test('recordEvent adjusts weights and transitions lifecycle to learning', () async {
      final notifier = container.read(creatorDnaProvider.notifier);

      await notifier.seedFromOnboarding(
        role: CreativeRole.vocalist,
        experienceLevel: ExperienceLevel.growing,
        selectedGenres: ['Amapiano'],
        primaryLanguage: 'English',
        secondaryLanguages: [],
        tempoPreference: 'medium',
        vocalEnergyPreference: 'balanced',
        selectedMoods: [],
        completeness: 1.0,
      );

      // Track like increases genre weight by +0.30
      await notifier.recordEvent(
        BehaviorEvent.trackLike(
          trackId: 'trk_1',
          genreHint: 'Amapiano',
          languageHint: 'English',
        ),
      );

      var state = container.read(creatorDnaProvider);
      expect(state.genreWeights['Amapiano'], closeTo(1.30, 0.001));
      expect(state.lifecycleState, DnaLifecycleState.learning);
      expect(state.totalBehaviorEvents, 1);

      // Early skip decreases genre weight by -0.10
      await notifier.recordEvent(
        BehaviorEvent.trackSkip(
          trackId: 'trk_2',
          genreHint: 'Amapiano',
          secondsBeforeSkip: 2,
        ),
      );

      state = container.read(creatorDnaProvider);
      expect(state.genreWeights['Amapiano'], closeTo(1.20, 0.001));
      expect(state.totalBehaviorEvents, 2);
    });

    test('resetDna restores unseeded initial profile', () async {
      final notifier = container.read(creatorDnaProvider.notifier);

      await notifier.seedFromOnboarding(
        role: CreativeRole.producer,
        experienceLevel: ExperienceLevel.pro,
        selectedGenres: ['Gqom'],
        primaryLanguage: 'English',
        secondaryLanguages: [],
        tempoPreference: 'fast',
        vocalEnergyPreference: 'intense',
        selectedMoods: [],
        completeness: 1.0,
      );

      expect(container.read(creatorDnaProvider).onboardingCompleted, isTrue);

      await notifier.resetDna();

      final resetState = container.read(creatorDnaProvider);
      expect(resetState.onboardingCompleted, isFalse);
      expect(resetState.lifecycleState, DnaLifecycleState.uninitialized);
    });

    test('dnaStudioDefaultsProvider maps preferences when seeded', () async {
      // Uninitialized
      var defaults = container.read(dnaStudioDefaultsProvider);
      expect(defaults.hasDnaDefaults, isFalse);

      // Seed
      await container.read(creatorDnaProvider.notifier).seedFromOnboarding(
        role: CreativeRole.producer,
        experienceLevel: ExperienceLevel.pro,
        selectedGenres: ['Afrobeats'],
        primaryLanguage: 'Yoruba',
        secondaryLanguages: [],
        tempoPreference: 'fast',
        vocalEnergyPreference: 'intense',
        selectedMoods: ['Celebratory'],
        completeness: 1.0,
      );

      defaults = container.read(dnaStudioDefaultsProvider);
      expect(defaults.hasDnaDefaults, isTrue);
      expect(defaults.genre, 'Afrobeats');
      expect(defaults.language, 'Yoruba');
      expect(defaults.tempo, TempoBracket.fast);
      expect(defaults.vocalEnergy, VocalEnergy.intense);
      expect(defaults.mood, 'Celebratory');
    });
  });
}
