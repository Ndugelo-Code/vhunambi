import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../studio/domain/models/studio_form_state.dart';
import '../../domain/models/studio_dna_defaults.dart';
import 'creator_dna_provider.dart';

/// Derived provider computing initial adaptive Studio form defaults based on active Creator DNA.
final dnaStudioDefaultsProvider = Provider<StudioDnaDefaults>((ref) {
  final dna = ref.watch(creatorDnaProvider);

  if (!dna.onboardingCompleted || dna.genreWeights.isEmpty) {
    return const StudioDnaDefaults.empty();
  }

  final topGenre = dna.topGenres(1).firstOrNull ?? 'Amapiano';
  final tempo = _parseTempo(dna.tempoPreference);
  final energy = _parseEnergy(dna.vocalEnergyPreference);
  final topMood = dna.moodWeights.entries.isEmpty
      ? 'Uplifting'
      : (dna.moodWeights.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .first
          .key;

  return StudioDnaDefaults(
    genre: topGenre,
    language: dna.primaryLanguage,
    tempo: tempo,
    vocalEnergy: energy,
    mood: topMood,
    hasDnaDefaults: true,
  );
});

TempoBracket _parseTempo(String pref) => switch (pref) {
      'slow' => TempoBracket.slow,
      'fast' => TempoBracket.fast,
      'hyperspeed' => TempoBracket.veryFast,
      _ => TempoBracket.medium,
    };

VocalEnergy _parseEnergy(String pref) => switch (pref) {
      'soft' => VocalEnergy.soft,
      'intense' => VocalEnergy.intense,
      _ => VocalEnergy.mid,
    };
