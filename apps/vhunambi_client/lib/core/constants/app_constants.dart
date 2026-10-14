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

  // Library & User Asset Vault (Blueprint 04)
  static const String vaultBoxKey = 'library_tracks';
  static const String vaultAudioDirectory = 'vhunambi_vault/audio';
}
