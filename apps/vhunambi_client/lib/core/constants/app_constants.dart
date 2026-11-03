/// Global application constants and configuration
abstract final class AppConstants {
  static const String appName = 'VHUNAMBI';
  static const String appTagline = 'Create African Music with a Single Prompt';
  static const String defaultOrigin = 'https://vhunambi.com';
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://vhunambi-api.zaniaexplore.co.za/v1',
  );

  // Storage Keys
  static const String tokenBoxKey = 'vhunambi_tokens';
  static const String tracksBoxKey = 'vhunambi_tracks';
  static const String preferencesBoxKey = 'vhunambi_prefs';
  static const String playlistsBoxKey = 'vhunambi_playlists';
  static const String collectionsBoxKey = 'vhunambi_collections';
  static const String beatsBoxKey = 'vhunambi_beats';
  static const String profileBoxKey = 'vhunambi_profiles';
  static const String creatorDnaBoxKey = 'vhunambi_creator_dna';

  // Notifications Center (M8) — untyped Hive box for offline alert persistence.
  static const String notificationsBoxKey = 'notifications_v1';

  // Studio AI Cockpit (M10) — ghost session draft auto-save & recovery.
  static const String studioSessionBoxKey = 'vhunambi_studio_session';

  // Library & User Asset Vault (Blueprint 04)
  static const String vaultBoxKey = 'library_tracks';
  static const String vaultAudioDirectory = 'vhunambi_vault/audio';

  // Executable Master Media Object (MMO v2.0) — Phase 23 Hive persistence
  static const String mmoBoxKey = 'vhunambi_mmo_manifest_box';

  // Vocal Identity & Cloned Voice Profiles — Phase 26 Hive persistence
  static const String voiceProfilesBoxKey = 'vhunambi_voice_profiles_box';

  // In-Key Melody, Chord & Log-Drum Sketchpad Vault — Phase 27 Hive persistence
  static const String melodySketchesBoxKey = 'vhunambi_melody_sketches_box';

  // Sound Pack Expansion Manager — Phase 32 Hive persistence
  static const String soundPacksBoxKey = 'vhunambi_sound_packs_box';

  // Adaptive Theme Mode & Appearance Preferences — Phase 33 Hive persistence
  static const String themePrefsBoxKey = 'vhunambi_theme_prefs_box';

  /// Phase 35: Sovereign Sound Signature DNA Hive box key.
  static const String soundSignaturesBoxKey = 'vhunambi_sound_signatures_box';
}

