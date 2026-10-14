import 'package:flutter/foundation.dart';
import 'package:vhunambi_client/features/studio/domain/models/studio_form_state.dart';

/// DNA-derived default values for the Studio form.
/// These are adaptive suggestions based on the user's sound profile, never forced overrides.
@immutable
class StudioDnaDefaults {
  final String genre;
  final String language;
  final TempoBracket tempo;
  final VocalEnergy vocalEnergy;
  final String mood;
  final bool hasDnaDefaults; // false when DNA is uninitialized or unseeded

  const StudioDnaDefaults({
    this.genre = 'Amapiano',
    this.language = 'English',
    this.tempo = TempoBracket.medium,
    this.vocalEnergy = VocalEnergy.mid,
    this.mood = 'Uplifting',
    this.hasDnaDefaults = false,
  });

  const StudioDnaDefaults.empty() : this();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StudioDnaDefaults &&
          runtimeType == other.runtimeType &&
          genre == other.genre &&
          language == other.language &&
          tempo == other.tempo &&
          vocalEnergy == other.vocalEnergy &&
          mood == other.mood &&
          hasDnaDefaults == other.hasDnaDefaults;

  @override
  int get hashCode => Object.hash(
        genre,
        language,
        tempo,
        vocalEnergy,
        mood,
        hasDnaDefaults,
      );
}
