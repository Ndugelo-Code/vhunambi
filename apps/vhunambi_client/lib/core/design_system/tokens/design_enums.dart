/// Musical style category for genre color tokens.
///
/// Defines the African and diaspora genres supported by Vhunambi's
/// design system. Each genre maps to a single color set (accent, surface
/// tint, glow, text color) registered in [DesignTokenRegistry].
enum Genre {
  amapiano,
  afroHouse,
  gqom,
  kwaito,
  afroPop,
  maskandi,
  hipHop,
  gospel;

  /// Human-readable display name for UI presentation.
  String get displayName => switch (this) {
        Genre.amapiano => 'Amapiano',
        Genre.afroHouse => 'Afro House',
        Genre.gqom => 'Gqom',
        Genre.kwaito => 'Kwaito',
        Genre.afroPop => 'Afro Pop',
        Genre.maskandi => 'Maskandi',
        Genre.hipHop => 'Hip-Hop',
        Genre.gospel => 'Gospel',
      };
}

/// Emotional quality category for mood color tokens.
///
/// Defines moods that influence visual identity in generation and
/// onboarding contexts. Each mood maps to a single color set.
enum Mood {
  joyful,
  melancholic,
  energetic,
  calm,
  romantic;

  /// Human-readable display name for UI presentation.
  String get displayName => switch (this) {
        Mood.joyful => 'Joyful',
        Mood.melancholic => 'Melancholic',
        Mood.energetic => 'Energetic',
        Mood.calm => 'Calm',
        Mood.romantic => 'Romantic',
      };
}