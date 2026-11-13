import 'package:flutter/foundation.dart';

/// Global application constants and configuration
abstract final class AppConstants {
  static const String appName = 'VHUNAMBI';
  static const String appTagline = 'Create African Music with a Single Prompt';
  static const String appVersion = '0.1.0';
  static const String defaultOrigin = 'https://vhunambi.com';

  /// Raw compile-time `--dart-define=API_BASE_URL=...` override.
  static const String configuredApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Raw compile-time `--dart-define=MEDIA_BASE_URL=...` override.
  static const String configuredMediaBaseUrl = String.fromEnvironment(
    'MEDIA_BASE_URL',
    defaultValue: '',
  );

  /// Strips trailing `/` and `/v1` or `/api` suffixes so all root, `/api`, and
  /// `/v1` consumers derive from one canonical origin.
  static String normalizeOriginUrl(String rawUrl) {
    var cleaned = rawUrl.trim();
    while (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    if (cleaned.endsWith('/api/v1')) {
      cleaned = cleaned.substring(0, cleaned.length - '/api/v1'.length);
    } else if (cleaned.endsWith('/v1')) {
      cleaned = cleaned.substring(0, cleaned.length - '/v1'.length);
    } else if (cleaned.endsWith('/api')) {
      cleaned = cleaned.substring(0, cleaned.length - '/api'.length);
    }
    return cleaned;
  }

  /// Resolves the root HTTP origin (`https://vhunambi-api.<you>.workers.dev`
  /// when `API_BASE_URL` is configured, or `http://10.0.2.2:3000` /
  /// `http://localhost:3000` locally).
  static String resolveApiRootUrl({String? overrideOrigin}) {
    final candidate = (overrideOrigin ?? configuredApiBaseUrl).trim();
    if (candidate.isNotEmpty) {
      return normalizeOriginUrl(candidate);
    }
    if (kIsWeb) return 'http://localhost:3000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  /// Resolves `/v1` API base URL for Studio Generation, Lyrics, Vision, Voices & Melodies.
  static String get apiBaseUrl => '${resolveApiRootUrl()}/v1';

  /// Resolves `/api` base URL for Explore, Library, Playlists, Social, Wallet & Payments.
  static String get apiRestBaseUrl => '${resolveApiRootUrl()}/api';

  /// Resolves WebSocket URL (`wss://` for `https://`, `ws://` for `http://`).
  static String resolveWsUrl({
    String path = '/ws/generation',
    String? overrideOrigin,
  }) {
    final root = resolveApiRootUrl(overrideOrigin: overrideOrigin);
    final wsRoot = root.startsWith('https://')
        ? 'wss://${root.substring('https://'.length)}'
        : root.startsWith('http://')
        ? 'ws://${root.substring('http://'.length)}'
        : root;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$wsRoot$cleanPath';
  }

  /// Resolves zero-egress R2 public base URL (`MEDIA_BASE_URL` or `${root}/r2`).
  static String resolveMediaBaseUrl({String? overrideOrigin}) {
    if (configuredMediaBaseUrl.trim().isNotEmpty) {
      var base = configuredMediaBaseUrl.trim();
      while (base.endsWith('/')) {
        base = base.substring(0, base.length - 1);
      }
      return base;
    }
    return '${resolveApiRootUrl(overrideOrigin: overrideOrigin)}/r2';
  }

  /// Rewrites dead legacy domains (`r2.vhunambi.com`, `cdn.vhunambi.com`,
  /// `cdn.vhunambi.za`, `assets.vhunambi.com`, `/mock-storage/*`) to the active R2 media origin.
  static String normalizeCloudMediaUrl(
    String rawUrl, {
    String? overrideOrigin,
  }) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return '';
    final mediaBase = resolveMediaBaseUrl(overrideOrigin: overrideOrigin);
    if (trimmed.startsWith('/mock-storage/')) {
      final key = trimmed.substring('/mock-storage/'.length);
      return '$mediaBase/$key';
    }
    if (trimmed.startsWith('/r2/')) {
      final key = trimmed.substring('/r2/'.length);
      return '$mediaBase/$key';
    }
    final legacyRegex = RegExp(
      r'^https?:\/\/(?:r2\.vhunambi\.com|cdn\.vhunambi\.com|cdn\.vhunambi\.za|assets\.vhunambi\.com|cdn\.vhunambi\.co\.za|storage\.vhunambi\.dev|(?:www\.)?vhunambi\.com)\/(.+)$',
      caseSensitive: false,
    );
    final match = legacyRegex.firstMatch(trimmed);
    if (match != null) {
      return '$mediaBase/${match.group(1)}';
    }
    return trimmed;
  }

  // Responsive Breakpoints
  static const double mobileMaxWidth = 767;
  static const double tabletMinWidth = 768;
  static const double tabletMaxWidth = 1024;
  static const double desktopMinWidth = 1025;

  // Navigation Dimensions
  static const double sidebarExpandedWidth = 240;
  static const double sidebarCollapsedWidth = 72;
  static const double bottomNavHeight = 64;
  static const double miniPlayerHeight = 64;
  static const double rightPanelWidth = 340;
  static const double topAppBarHeight = 64;

  // Grid Columns
  static const int desktopGridColumns = 4;
  static const int tabletGridColumns = 3;
  static const int mobileGridColumns = 2;

  // Content Constraints
  static const double maxContentWidth = 1440;
  static const double maxFormWidth = 480;
  static const double maxReadableWidth = 680;

  // Audio Defaults
  static const int defaultBpm = 120;
  static const int minBpm = 60;
  static const int maxBpm = 200;
  static const Duration maxTrackDuration = Duration(minutes: 5);
  static const Duration previewDuration = Duration(seconds: 30);

  // Pagination
  static const int defaultPageSize = 20;
  static const int searchDebounceMs = 300;

  // =========================================================================
  // Sovereign Hive Brain 26-Box Storage Keys (Phase 60)
  // =========================================================================

  // Tier 0: Eager Hot-Boot Sovereign Nucleus (7 Boxes)
  static const String tokenBoxKey =
      'vhunambi_tokens'; // Encrypted Auth & Onboarding Genesis
  static const String preferencesBoxKey = 'vhunambi_prefs';
  static const String prefsBoxKey =
      preferencesBoxKey; // Unified App Prefs, EdgeSync Cursor & Checkout WAL
  static const String themePrefsBoxKey = 'vhunambi_theme_prefs_box';
  static const String creatorDnaBoxKey =
      'vhunambi_creator_dna'; // Encrypted Creator DNA & O(1) Ring Log
  static const String syncOutboxBoxKey =
      'vhunambi_sync_outbox_box'; // Encrypted Offline Mutation WAL
  static const String walletLedgerBoxKey =
      'vhunambi_wallet_ledger_box'; // Encrypted Creator Wallet & SA Bank Ledger
  static const String playbackSessionBoxKey =
      'vhunambi_playback_session_box'; // Player Queue, Seek, HeroMode, RecentlyPlayed

  // Tier 1: Eager Domain Matrix (17 Boxes)
  static const String libraryTracksV1BoxKey = 'vhunambi_library_tracks_v1';
  static const String vaultBoxKey =
      'library_tracks'; // OfflineStorageService .vmf Vault Index
  static const String vaultAudioDirectory = 'vhunambi_vault/audio';
  static const String playlistsBoxKey = 'vhunambi_playlists';
  static const String collectionsBoxKey = 'vhunambi_collections';
  static const String beatsBoxKey = 'vhunambi_beats';
  static const String licenseCertificatesBoxKey =
      'vhunambi_license_certificates'; // Encrypted Ownership Certificates
  static const String marketplaceCatalogBoxKey =
      'vhunambi_marketplace_catalog_box'; // Beat Catalog & Exclusive Locks
  static const String profileBoxKey = 'vhunambi_profiles';
  static const String profilesBoxKey =
      profileBoxKey; // LRU ProfileCache + Pinned 'me' Owner Profile
  static const String notificationsBoxKey =
      'notifications_v1'; // O(1) Per-Entity Notifications
  static const String studioSessionBoxKey =
      'vhunambi_studio_session'; // Studio + GenerationReq + ContentStudio Drafts
  static const String voiceProfilesBoxKey =
      'vhunambi_voice_profiles_box'; // Encrypted O(1) Cloned Voice Profiles
  static const String melodySketchesBoxKey =
      'vhunambi_melody_sketches_box'; // O(1) Melody Sketches
  static const String soundPacksBoxKey = 'vhunambi_sound_packs_box';
  static const String stemDspRecipesBoxKey =
      'vhunambi_stem_dsp_recipes_box'; // Per-Track 4-Stem Mixer & Mastering Recipes
  static const String crateMpcKitsBoxKey =
      'vhunambi_crate_mpc_kits_box'; // Heritage Crate Favorites, 8-Pad MPC Kits & Biome Leaves
  static const String tracksBoxKey =
      'vhunambi_tracks'; // Repurposed: Explore Discovery, Radio, Likes & Co-Signs Cache
  static const String socialReelsBoxKey =
      'vhunambi_social_reels_box'; // Kinetic Reels, Comments & Stem Remix Lineage Cache

  // Tier 2: Heavy Payload & Compaction-Managed Boxes (2 Boxes)
  static const String mmoBoxKey = 'vhunambi_mmo_manifest_box';
  static const String mmoManifestBoxKey = mmoBoxKey;
  static const String soundSignaturesBoxKey =
      'vhunambi_sound_signatures_box'; // Encrypted .vss Binary Signatures
}
