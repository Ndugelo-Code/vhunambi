import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/studio_form_state.dart';
import 'studio_form_provider.dart';

/// Derives progress-tracker slot states from [StudioFormState] — single source
/// of truth per REQ-STM-01. No duplicate state is cached here.
class ProgressTracker {
  final StudioFormState state;

  ProgressTracker(this.state);

  /// Slot definitions: (key, label, isSet, stateLabel)
  List<ProgressSlot> get slots => [
        ProgressSlot(
          key: 'prompt',
          label: 'Prompt',
          isSet: state.prompt.isNotEmpty,
          stateLabel: state.prompt.isEmpty ? 'Empty' : 'Set',
        ),
        ProgressSlot(
          key: 'genre',
          label: 'Genre',
          isSet: state.genre.isNotEmpty,
          stateLabel: 'Auto',
        ),
        ProgressSlot(
          key: 'mood',
          label: 'Mood',
          isSet: state.mood.isNotEmpty,
          stateLabel: state.mood == 'Uplifting' ? 'Auto' : 'Set',
        ),
        ProgressSlot(
          key: 'tempo',
          label: 'Tempo',
          isSet: true, // always has a default
          stateLabel: state.tempo == TempoBracket.medium ? 'Auto' : 'Set',
        ),
        ProgressSlot(
          key: 'vocal_energy',
          label: 'Vocal Energy',
          isSet: true, // always has a default
          stateLabel: state.vocalEnergy == VocalEnergy.mid ? 'Auto' : 'Set',
        ),
        ProgressSlot(
          key: 'language',
          label: 'Language',
          isSet: state.language.isNotEmpty,
          stateLabel: state.language == 'English' ? 'Auto' : 'Set',
        ),
        ProgressSlot(
          key: 'lyrics_mode',
          label: 'Lyrics Mode',
          isSet: true, // always has a default
          stateLabel: state.lyricsMode == LyricsMode.aiWrite ? 'Auto' : 'Set',
        ),
        ProgressSlot(
          key: 'dna_usage',
          label: 'DNA Usage',
          isSet: true,
          stateLabel: 'Auto',
        ),
        ProgressSlot(
          key: 'visibility',
          label: 'Visibility',
          isSet: true, // always has a default
          stateLabel: state.visibility,
        ),
      ];

  /// Ratio of filled slots (0.0 to 1.0).
  double get completenessRatio {
    if (slots.isEmpty) return 0.0;
    final filled = slots.where((s) => s.isSet).length;
    return filled / slots.length;
  }

  /// DNA usage percentage (mock: based on how many defaults are used).
  int get dnaUsagePercent {
    final autoCount =
        slots.where((s) => s.stateLabel == 'Auto').length;
    return (autoCount / slots.length * 100).round().clamp(0, 100);
  }
}

/// A single progress-tracker slot.
class ProgressSlot {
  final String key;
  final String label;
  final bool isSet;
  final String stateLabel; // "Empty", "Set", or "Auto"

  const ProgressSlot({
    required this.key,
    required this.label,
    required this.isSet,
    required this.stateLabel,
  });
}

/// Provider exposing a [ProgressTracker] derived from [StudioFormState].
final progressTrackerProvider =
    Provider<ProgressTracker>((ref) {
  final state = ref.watch(studioFormProvider);
  return ProgressTracker(state);
});