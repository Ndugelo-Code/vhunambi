import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/storage/hive_compaction_scheduler.dart';

/// Controls whether provider notifiers hydrate from L1 static memory when running
/// inside `FLUTTER_TEST` without an open Hive box (disabled by default to keep
/// unrelated headless unit tests isolated per test case).
class SovereignDomainStorageMode {
  SovereignDomainStorageMode._();

  @visibleForTesting
  static bool allowMemoryHydrationInTests = false;

  static bool get _isFlutterTestEnvironment {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  static bool canHydrateFromStorage(String boxKey) {
    if (!kIsWeb && Hive.isBoxOpen(boxKey)) return true;
    if (kIsWeb) return true;
    if (allowMemoryHydrationInTests) return true;
    return !_isFlutterTestEnvironment;
  }

  /// Clears L1 static caches of tenant-private domains during account switch or sign-out (`Phase 61`).
  static void clearTenantMemory() {
    WalletLedgerRepository.clearSessionMemory();
    PlaybackSessionRepository.clearSessionMemory();
    StemDspRecipeRepository.clearSessionMemory();
    CrateMpcKitsRepository.clearSessionMemory();
    ExploreCacheRepository.clearUserSessionMemory();
    SocialReelsCacheRepository.clearUserSessionMemory();
    SovereignPrefsRepository.clearTenantSessionMemory();
  }

  @visibleForTesting
  static void clearAllForTesting() {
    WalletLedgerRepository.clearForTesting();
    PlaybackSessionRepository.clearForTesting();
    StemDspRecipeRepository.clearForTesting();
    CrateMpcKitsRepository.clearForTesting();
    ExploreCacheRepository.clearForTesting();
    SocialReelsCacheRepository.clearForTesting();
    MarketplaceCatalogCacheRepository.clearForTesting();
    SovereignPrefsRepository.clearForTesting();
  }
}

Box<dynamic>? _openDynamicBoxOrNull(String boxName) {
  if (kIsWeb) return null;
  try {
    if (Hive.isBoxOpen(boxName)) {
      final box = Hive.box<dynamic>(boxName);
      if (box.isOpen) return box;
    }
  } catch (_) {}
  return null;
}

Future<void> _safeBoxPut(String boxName, dynamic key, dynamic value) async {
  final box = _openDynamicBoxOrNull(boxName);
  if (box == null) return;
  try {
    await box.put(key, value);
  } catch (_) {
    // Ignore concurrent box close races during shutdown/restart.
  }
}

Future<void> _safeBoxDelete(String boxName, dynamic key) async {
  final box = _openDynamicBoxOrNull(boxName);
  if (box == null) return;
  try {
    await box.delete(key);
  } catch (_) {
    // Ignore concurrent box close races during shutdown/restart.
  }
}

Future<void> _safeRecordMutation(String boxName) async {
  if (kIsWeb || !Hive.isBoxOpen(boxName)) return;
  try {
    await HiveCompactionScheduler.recordMutation(boxName);
  } catch (_) {}
}

/// 1. Creator Wallet, Coin Balance, Transaction Ledger & Saved SA Bank Details
/// Persists in `vhunambi_wallet_ledger_box` (Encrypted Tier 0).
class WalletLedgerRepository {
  WalletLedgerRepository._();

  static const String _snapshotKey = 'wallet_snapshot_v1';
  static const String _bankDetailsKey = 'saved_sa_bank_details_v1';
  static const String _txPrefix = 'tx_';

  static Map<String, dynamic>? _memorySnapshot;
  static Map<String, String>? _memoryBankDetails;
  static final Map<String, Map<String, dynamic>> _memoryTransactions =
      <String, Map<String, dynamic>>{};

  static Future<void> saveWalletSnapshot({
    required int userCoinsBalance,
    required double creatorEarnedZar,
    required int creatorReceivedCoins,
    required List<Map<String, dynamic>> transactions,
  }) async {
    final snapshot = <String, dynamic>{
      'userCoinsBalance': userCoinsBalance,
      'creatorEarnedZar': creatorEarnedZar,
      'creatorReceivedCoins': creatorReceivedCoins,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    _memorySnapshot = snapshot;
    _memoryTransactions.clear();
    for (final tx in transactions) {
      final id = tx['id'] as String? ?? '';
      if (id.isNotEmpty) {
        _memoryTransactions['$_txPrefix$id'] = Map<String, dynamic>.from(tx);
      }
    }

    await _safeBoxPut(
      AppConstants.walletLedgerBoxKey,
      _snapshotKey,
      jsonEncode(snapshot),
    );
    for (final entry in _memoryTransactions.entries.toList()) {
      await _safeBoxPut(
        AppConstants.walletLedgerBoxKey,
        entry.key,
        jsonEncode(entry.value),
      );
    }
    await _safeRecordMutation(AppConstants.walletLedgerBoxKey);
  }

  static Map<String, dynamic>? loadWalletSnapshot() {
    final box = _openDynamicBoxOrNull(AppConstants.walletLedgerBoxKey);
    if (box != null) {
      final rawSnap = box.get(_snapshotKey);
      if (rawSnap is String) {
        try {
          final snap = Map<String, dynamic>.from(
            jsonDecode(rawSnap) as Map<dynamic, dynamic>,
          );
          final txs = <Map<String, dynamic>>[];
          for (final rawKey in box.keys) {
            final key = rawKey.toString();
            if (key.startsWith(_txPrefix)) {
              final rawTx = box.get(key);
              if (rawTx is String) {
                txs.add(
                  Map<String, dynamic>.from(
                    jsonDecode(rawTx) as Map<dynamic, dynamic>,
                  ),
                );
              }
            }
          }
          txs.sort((a, b) {
            final da =
                DateTime.tryParse(a['timestamp'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final db =
                DateTime.tryParse(b['timestamp'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return db.compareTo(da);
          });
          snap['transactions'] = txs;
          return snap;
        } catch (_) {}
      }
    }
    if (_memorySnapshot != null) {
      final txs = _memoryTransactions.values.toList()
        ..sort((a, b) {
          final da =
              DateTime.tryParse(a['timestamp'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final db =
              DateTime.tryParse(b['timestamp'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return db.compareTo(da);
        });
      return <String, dynamic>{..._memorySnapshot!, 'transactions': txs};
    }
    return null;
  }

  static Future<void> saveBankDetails({
    required String bankName,
    required String accountHolder,
    required String accountNumber,
    required String branchCode,
    String payoutMethod = 'EFT Direct',
    String paymentRail = 'eft',
  }) async {
    final details = <String, String>{
      'bankName': bankName,
      'accountHolder': accountHolder,
      'accountNumber': accountNumber,
      'branchCode': branchCode,
      'payoutMethod': payoutMethod,
      'paymentRail': paymentRail,
    };
    _memoryBankDetails = details;
    await _safeBoxPut(
      AppConstants.walletLedgerBoxKey,
      _bankDetailsKey,
      jsonEncode(details),
    );
  }

  static Map<String, String>? loadBankDetails() {
    final box = _openDynamicBoxOrNull(AppConstants.walletLedgerBoxKey);
    if (box != null) {
      final raw = box.get(_bankDetailsKey);
      if (raw is String) {
        try {
          final decoded = jsonDecode(raw) as Map<dynamic, dynamic>;
          return decoded.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          );
        } catch (_) {}
      }
    }
    return _memoryBankDetails;
  }

  /// Clears in-memory L1 wallet ledger & bank details on account switch / sign-out.
  static void clearSessionMemory() {
    _memorySnapshot = null;
    _memoryBankDetails = null;
    _memoryTransactions.clear();
  }

  @visibleForTesting
  static void clearForTesting() => clearSessionMemory();
}

/// 2. Player Queue, Active Track, Seek Position, Hero Mode & Recently Played
/// Persists in `vhunambi_playback_session_box` (Tier 0).
class PlaybackSessionRepository {
  PlaybackSessionRepository._();

  static const String _sessionKey = 'active_playback_session_v1';
  static const String _heroModeKey = 'player_hero_mode_v1';
  static const String _recentlyPlayedKey = 'recently_played_ids_v1';

  static Map<String, dynamic>? _memorySession;
  static String? _memoryHeroMode;
  static List<String>? _memoryRecentlyPlayedIds;

  static Future<void> savePlaybackSession(Map<String, dynamic> session) async {
    _memorySession = Map<String, dynamic>.from(session);
    await _safeBoxPut(
      AppConstants.playbackSessionBoxKey,
      _sessionKey,
      jsonEncode(session),
    );
    await _safeRecordMutation(AppConstants.playbackSessionBoxKey);
  }

  static Map<String, dynamic>? loadPlaybackSession() {
    final box = _openDynamicBoxOrNull(AppConstants.playbackSessionBoxKey);
    if (box != null) {
      final raw = box.get(_sessionKey);
      if (raw is String) {
        try {
          return Map<String, dynamic>.from(
            jsonDecode(raw) as Map<dynamic, dynamic>,
          );
        } catch (_) {}
      }
    }
    return _memorySession;
  }

  static Future<void> saveHeroMode(String modeName) async {
    _memoryHeroMode = modeName;
    await _safeBoxPut(
      AppConstants.playbackSessionBoxKey,
      _heroModeKey,
      modeName,
    );
  }

  static String? loadHeroMode() {
    final box = _openDynamicBoxOrNull(AppConstants.playbackSessionBoxKey);
    if (box != null) {
      final raw = box.get(_heroModeKey);
      if (raw is String) return raw;
    }
    return _memoryHeroMode;
  }

  static Future<void> saveRecentlyPlayedIds(List<String> ids) async {
    _memoryRecentlyPlayedIds = List<String>.from(ids);
    await _safeBoxPut(
      AppConstants.playbackSessionBoxKey,
      _recentlyPlayedKey,
      jsonEncode(ids),
    );
  }

  static List<String>? loadRecentlyPlayedIds() {
    final box = _openDynamicBoxOrNull(AppConstants.playbackSessionBoxKey);
    if (box != null) {
      final raw = box.get(_recentlyPlayedKey);
      if (raw is String) {
        try {
          return (jsonDecode(raw) as List<dynamic>)
              .map((e) => e.toString())
              .toList();
        } catch (_) {}
      }
    }
    return _memoryRecentlyPlayedIds;
  }

  /// Clears in-memory L1 playback session & queue on account switch / sign-out.
  static void clearSessionMemory() {
    _memorySession = null;
    _memoryHeroMode = null;
    _memoryRecentlyPlayedIds = null;
  }

  @visibleForTesting
  static void clearForTesting() => clearSessionMemory();
}

/// 3. 4-Stem Mixer & Per-Track Mastering DSP Recipes
/// Persists in `vhunambi_stem_dsp_recipes_box` (Tier 1).
class StemDspRecipeRepository {
  StemDspRecipeRepository._();

  static final Map<String, Map<String, dynamic>> _memoryStemMixes =
      <String, Map<String, dynamic>>{};
  static final Map<String, Map<String, dynamic>> _memoryMasteringRecipes =
      <String, Map<String, dynamic>>{};

  static Future<void> saveStemMixerState(
    String trackId,
    Map<String, dynamic> stateJson,
  ) async {
    final key = 'stem_mix_$trackId';
    _memoryStemMixes[key] = Map<String, dynamic>.from(stateJson);
    await _safeBoxPut(
      AppConstants.stemDspRecipesBoxKey,
      key,
      jsonEncode(stateJson),
    );
    await _safeRecordMutation(AppConstants.stemDspRecipesBoxKey);
  }

  static Map<String, dynamic>? loadStemMixerState(String trackId) {
    final key = 'stem_mix_$trackId';
    final box = _openDynamicBoxOrNull(AppConstants.stemDspRecipesBoxKey);
    if (box != null) {
      final raw = box.get(key);
      if (raw is String) {
        try {
          return Map<String, dynamic>.from(
            jsonDecode(raw) as Map<dynamic, dynamic>,
          );
        } catch (_) {}
      }
    }
    return _memoryStemMixes[key];
  }

  static Future<void> saveMasteringRecipe(
    String trackId,
    Map<String, dynamic> recipeJson,
  ) async {
    final key = 'master_recipe_$trackId';
    _memoryMasteringRecipes[key] = Map<String, dynamic>.from(recipeJson);
    await _safeBoxPut(
      AppConstants.stemDspRecipesBoxKey,
      key,
      jsonEncode(recipeJson),
    );
    await _safeRecordMutation(AppConstants.stemDspRecipesBoxKey);
  }

  static Map<String, dynamic>? loadMasteringRecipe(String trackId) {
    final key = 'master_recipe_$trackId';
    final box = _openDynamicBoxOrNull(AppConstants.stemDspRecipesBoxKey);
    if (box != null) {
      final raw = box.get(key);
      if (raw is String) {
        try {
          return Map<String, dynamic>.from(
            jsonDecode(raw) as Map<dynamic, dynamic>,
          );
        } catch (_) {}
      }
    }
    return _memoryMasteringRecipes[key];
  }

  /// Clears in-memory L1 stem DSP & mastering recipes on account switch / sign-out.
  static void clearSessionMemory() {
    _memoryStemMixes.clear();
    _memoryMasteringRecipes.clear();
  }

  @visibleForTesting
  static void clearForTesting() => clearSessionMemory();
}

/// 4. Heritage Crate Favorites, Custom 8-Pad MPC Kits & 3D Mycelium Biome Leaves
/// Persists in `vhunambi_crate_mpc_kits_box` (Tier 1).
class CrateMpcKitsRepository {
  CrateMpcKitsRepository._();

  static const String _favoritesKey = 'favorite_sample_ids_v1';
  static const String _biomeLeavesKey = 'custom_biome_leaves_v1';
  static Set<String>? _memoryFavorites;
  static final Map<String, Map<String, dynamic>> _memoryMpcKits =
      <String, Map<String, dynamic>>{};
  static List<Map<String, dynamic>>? _memoryBiomeLeaves;

  static Future<void> saveFavoriteSampleIds(Set<String> ids) async {
    _memoryFavorites = Set<String>.from(ids);
    await _safeBoxPut(
      AppConstants.crateMpcKitsBoxKey,
      _favoritesKey,
      jsonEncode(ids.toList()),
    );
  }

  static Set<String>? loadFavoriteSampleIds() {
    final box = _openDynamicBoxOrNull(AppConstants.crateMpcKitsBoxKey);
    if (box != null) {
      final raw = box.get(_favoritesKey);
      if (raw is String) {
        try {
          return (jsonDecode(raw) as List<dynamic>)
              .map((e) => e.toString())
              .toSet();
        } catch (_) {}
      }
    }
    return _memoryFavorites;
  }

  static Future<void> saveMpcKit(
    String kitKey,
    Map<String, dynamic> kitJson,
  ) async {
    final key = 'mpc_kit_$kitKey';
    _memoryMpcKits[key] = Map<String, dynamic>.from(kitJson);
    await _safeBoxPut(
      AppConstants.crateMpcKitsBoxKey,
      key,
      jsonEncode(kitJson),
    );
  }

  static Map<String, dynamic>? loadMpcKit(String kitKey) {
    final key = 'mpc_kit_$kitKey';
    final box = _openDynamicBoxOrNull(AppConstants.crateMpcKitsBoxKey);
    if (box != null) {
      final raw = box.get(key);
      if (raw is String) {
        try {
          return Map<String, dynamic>.from(
            jsonDecode(raw) as Map<dynamic, dynamic>,
          );
        } catch (_) {}
      }
    }
    return _memoryMpcKits[key];
  }

  static Future<void> saveCustomBiomeLeaves(
    List<Map<String, dynamic>> leaves,
  ) async {
    _memoryBiomeLeaves = List<Map<String, dynamic>>.from(leaves);
    await _safeBoxPut(
      AppConstants.crateMpcKitsBoxKey,
      _biomeLeavesKey,
      jsonEncode(leaves),
    );
  }

  static List<Map<String, dynamic>>? loadCustomBiomeLeaves() {
    final box = _openDynamicBoxOrNull(AppConstants.crateMpcKitsBoxKey);
    if (box != null) {
      final raw = box.get(_biomeLeavesKey);
      if (raw is String) {
        try {
          return (jsonDecode(raw) as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>))
              .toList();
        } catch (_) {}
      }
    }
    return _memoryBiomeLeaves;
  }

  /// Clears in-memory L1 favorites, MPC kits & biome leaves on account switch / sign-out.
  static void clearSessionMemory() {
    _memoryFavorites = null;
    _memoryMpcKits.clear();
    _memoryBiomeLeaves = null;
  }

  @visibleForTesting
  static void clearForTesting() => clearSessionMemory();
}

/// 5. Explore Discovery Feed, Liked Track IDs, A&R Co-Signs & Recent Searches
/// Persists in repurposed `vhunambi_tracks` (`AppConstants.tracksBoxKey`, Tier 1).
class ExploreCacheRepository {
  ExploreCacheRepository._();

  static const String _cachedTracksKey = 'explore_cached_tracks_v1';
  static const String _customPostsKey = 'explore_custom_posts_v1';
  static const String _likedTrackIdsKey = 'explore_liked_track_ids_v1';
  static const String _coSignVotesKey = 'explore_cosign_votes_v1';
  static const String _coSignStatesKey = 'explore_cosign_states_v1';
  static const String _likedPostIdsKey = 'explore_liked_post_ids_v1';
  static const String _followingIdsKey = 'explore_following_ids_v1';
  static const String _recentSearchesKey = 'explore_recent_searches_v1';

  static List<Map<String, dynamic>>? _memoryCachedTracks;
  static List<Map<String, dynamic>>? _memoryCustomPosts;
  static Set<String>? _memoryLikedTrackIds;
  static Map<String, int>? _memoryCoSignVotes;
  static Map<String, Map<String, dynamic>>? _memoryCoSignStates;
  static Set<String>? _memoryLikedPostIds;
  static Set<String>? _memoryFollowingIds;
  static List<String>? _memoryRecentSearches;

  static Future<void> saveCachedTracks(
    List<Map<String, dynamic>> tracks,
  ) async {
    _memoryCachedTracks = tracks
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    await _safeBoxPut(
      AppConstants.tracksBoxKey,
      _cachedTracksKey,
      jsonEncode(tracks),
    );
    await _safeRecordMutation(AppConstants.tracksBoxKey);
  }

  static List<Map<String, dynamic>>? loadCachedTracks() {
    final box = _openDynamicBoxOrNull(AppConstants.tracksBoxKey);
    if (box != null) {
      final raw = box.get(_cachedTracksKey);
      if (raw is String) {
        try {
          return (jsonDecode(raw) as List<dynamic>)
              .whereType<Map<dynamic, dynamic>>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        } catch (_) {}
      }
    }
    return _memoryCachedTracks;
  }

  static Future<void> saveCustomPosts(List<Map<String, dynamic>> posts) async {
    _memoryCustomPosts = posts
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    await _safeBoxPut(
      AppConstants.tracksBoxKey,
      _customPostsKey,
      jsonEncode(posts),
    );
    await _safeRecordMutation(AppConstants.tracksBoxKey);
  }

  static List<Map<String, dynamic>>? loadCustomPosts() {
    final box = _openDynamicBoxOrNull(AppConstants.tracksBoxKey);
    if (box != null) {
      final raw = box.get(_customPostsKey);
      if (raw is String) {
        try {
          return (jsonDecode(raw) as List<dynamic>)
              .whereType<Map<dynamic, dynamic>>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        } catch (_) {}
      }
    }
    return _memoryCustomPosts;
  }

  static Future<void> saveLikedTrackIds(Set<String> likedIds) async {
    _memoryLikedTrackIds = Set<String>.from(likedIds);
    await _safeBoxPut(
      AppConstants.tracksBoxKey,
      _likedTrackIdsKey,
      jsonEncode(likedIds.toList()),
    );
  }

  static Set<String>? loadLikedTrackIds() {
    final box = _openDynamicBoxOrNull(AppConstants.tracksBoxKey);
    if (box != null) {
      final raw = box.get(_likedTrackIdsKey);
      if (raw is String) {
        try {
          return (jsonDecode(raw) as List<dynamic>)
              .map((e) => e.toString())
              .toSet();
        } catch (_) {}
      }
    }
    return _memoryLikedTrackIds;
  }

  static Future<void> saveCoSignVotes(Map<String, int> votes) async {
    _memoryCoSignVotes = Map<String, int>.from(votes);
    await _safeBoxPut(
      AppConstants.tracksBoxKey,
      _coSignVotesKey,
      jsonEncode(votes),
    );
  }

  static Map<String, int>? loadCoSignVotes() {
    final box = _openDynamicBoxOrNull(AppConstants.tracksBoxKey);
    if (box != null) {
      final raw = box.get(_coSignVotesKey);
      if (raw is String) {
        try {
          final decoded = jsonDecode(raw) as Map<dynamic, dynamic>;
          return decoded.map(
            (k, v) => MapEntry(k.toString(), (v as num).toInt()),
          );
        } catch (_) {}
      }
    }
    return _memoryCoSignVotes;
  }

  static Future<void> saveCoSignStates(
    Map<String, Map<String, dynamic>> states,
  ) async {
    _memoryCoSignStates = states.map(
      (k, v) => MapEntry(k, Map<String, dynamic>.from(v)),
    );
    final votesOnly = <String, int>{
      for (final e in states.entries)
        if (e.value['cosignCount'] is num)
          e.key: (e.value['cosignCount'] as num).toInt(),
    };
    _memoryCoSignVotes = votesOnly;
    await _safeBoxPut(
      AppConstants.tracksBoxKey,
      _coSignStatesKey,
      jsonEncode(states),
    );
    await _safeBoxPut(
      AppConstants.tracksBoxKey,
      _coSignVotesKey,
      jsonEncode(votesOnly),
    );
  }

  static Map<String, Map<String, dynamic>>? loadCoSignStates() {
    final box = _openDynamicBoxOrNull(AppConstants.tracksBoxKey);
    if (box != null) {
      final raw = box.get(_coSignStatesKey);
      if (raw is String) {
        try {
          final decoded = jsonDecode(raw) as Map<dynamic, dynamic>;
          return decoded.map(
            (k, v) => MapEntry(
              k.toString(),
              Map<String, dynamic>.from(v as Map<dynamic, dynamic>),
            ),
          );
        } catch (_) {}
      }
    }
    return _memoryCoSignStates;
  }

  static Future<void> saveFollowingIds(Set<String> followingIds) async {
    _memoryFollowingIds = Set<String>.from(followingIds);
    await _safeBoxPut(
      AppConstants.tracksBoxKey,
      _followingIdsKey,
      jsonEncode(followingIds.toList()),
    );
  }

  static Set<String>? loadFollowingIds() {
    final box = _openDynamicBoxOrNull(AppConstants.tracksBoxKey);
    if (box != null) {
      final raw = box.get(_followingIdsKey);
      if (raw is String) {
        try {
          return (jsonDecode(raw) as List<dynamic>)
              .map((e) => e.toString())
              .toSet();
        } catch (_) {}
      }
    }
    return _memoryFollowingIds;
  }

  static Future<void> saveLikedPostIds(Set<String> likedPostIds) async {
    _memoryLikedPostIds = Set<String>.from(likedPostIds);
    await _safeBoxPut(
      AppConstants.tracksBoxKey,
      _likedPostIdsKey,
      jsonEncode(likedPostIds.toList()),
    );
  }

  static Set<String>? loadLikedPostIds() {
    final box = _openDynamicBoxOrNull(AppConstants.tracksBoxKey);
    if (box != null) {
      final raw = box.get(_likedPostIdsKey);
      if (raw is String) {
        try {
          return (jsonDecode(raw) as List<dynamic>)
              .map((e) => e.toString())
              .toSet();
        } catch (_) {}
      }
    }
    return _memoryLikedPostIds;
  }

  static Future<void> saveRecentSearches(List<String> searches) async {
    _memoryRecentSearches = List<String>.from(searches);
    await _safeBoxPut(
      AppConstants.tracksBoxKey,
      _recentSearchesKey,
      jsonEncode(searches),
    );
  }

  static List<String>? loadRecentSearches() {
    final box = _openDynamicBoxOrNull(AppConstants.tracksBoxKey);
    if (box != null) {
      final raw = box.get(_recentSearchesKey);
      if (raw is String) {
        try {
          return (jsonDecode(raw) as List<dynamic>)
              .map((e) => e.toString())
              .toList();
        } catch (_) {}
      }
    }
    return _memoryRecentSearches;
  }

  /// Clears only user-scoped L1 likes, follows & recent searches while preserving shared catalogs.
  static void clearUserSessionMemory() {
    _memoryLikedTrackIds = null;
    _memoryLikedPostIds = null;
    _memoryFollowingIds = null;
    _memoryRecentSearches = null;
  }

  @visibleForTesting
  static void clearForTesting() {
    _memoryCachedTracks = null;
    _memoryCustomPosts = null;
    _memoryCoSignVotes = null;
    _memoryCoSignStates = null;
    clearUserSessionMemory();
  }
}

/// 6. Social Kinetic Reels, Multi-Tap Loves, Comments & Stem Remix Mute Cache
/// Persists in `vhunambi_social_reels_box` (Tier 1).
class SocialReelsCacheRepository {
  SocialReelsCacheRepository._();

  static const String _customClipsKey = 'social_custom_clips_v1';
  static const String _reelLoveCountsKey = 'reel_love_counts_v1';
  static const String _reelLikedIdsKey = 'reel_liked_ids_v1';
  static const String _activeRemixContextKey = 'active_stem_remix_context_v1';
  static const String _reelCommentsPrefix = 'reel_comments_';

  static List<Map<String, dynamic>>? _memoryCustomClips;
  static Map<String, int>? _memoryLoveCounts;
  static Set<String>? _memoryLikedIds;
  static Map<String, dynamic>? _memoryActiveRemixContext;
  static final Map<String, List<Map<String, dynamic>>> _memoryReelComments =
      <String, List<Map<String, dynamic>>>{};
  static final Map<String, Map<String, bool>> _memoryStemRemixMutes =
      <String, Map<String, bool>>{};

  static Future<void> saveCustomClips(List<Map<String, dynamic>> clips) async {
    _memoryCustomClips = clips
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    await _safeBoxPut(
      AppConstants.socialReelsBoxKey,
      _customClipsKey,
      jsonEncode(clips),
    );
    await _safeRecordMutation(AppConstants.socialReelsBoxKey);
  }

  static List<Map<String, dynamic>>? loadCustomClips() {
    final box = _openDynamicBoxOrNull(AppConstants.socialReelsBoxKey);
    if (box != null) {
      final raw = box.get(_customClipsKey);
      if (raw is String) {
        try {
          return (jsonDecode(raw) as List<dynamic>)
              .whereType<Map<dynamic, dynamic>>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        } catch (_) {}
      }
    }
    return _memoryCustomClips;
  }

  static Future<void> saveReelEngagement({
    required Map<String, int> loveCounts,
    required Set<String> likedIds,
  }) async {
    _memoryLoveCounts = Map<String, int>.from(loveCounts);
    _memoryLikedIds = Set<String>.from(likedIds);
    await _safeBoxPut(
      AppConstants.socialReelsBoxKey,
      _reelLoveCountsKey,
      jsonEncode(loveCounts),
    );
    await _safeBoxPut(
      AppConstants.socialReelsBoxKey,
      _reelLikedIdsKey,
      jsonEncode(likedIds.toList()),
    );
  }

  static Map<String, int>? loadReelLoveCounts() {
    final box = _openDynamicBoxOrNull(AppConstants.socialReelsBoxKey);
    if (box != null) {
      final raw = box.get(_reelLoveCountsKey);
      if (raw is String) {
        try {
          final map = jsonDecode(raw) as Map<dynamic, dynamic>;
          return map.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
        } catch (_) {}
      }
    }
    return _memoryLoveCounts;
  }

  static Set<String>? loadReelLikedIds() {
    final box = _openDynamicBoxOrNull(AppConstants.socialReelsBoxKey);
    if (box != null) {
      final raw = box.get(_reelLikedIdsKey);
      if (raw is String) {
        try {
          return (jsonDecode(raw) as List<dynamic>)
              .map((e) => e.toString())
              .toSet();
        } catch (_) {}
      }
    }
    return _memoryLikedIds;
  }

  static Future<void> saveReelComments(
    String reelId,
    List<Map<String, dynamic>> comments,
  ) async {
    final key = '$_reelCommentsPrefix$reelId';
    _memoryReelComments[key] = List<Map<String, dynamic>>.from(comments);
    await _safeBoxPut(
      AppConstants.socialReelsBoxKey,
      key,
      jsonEncode(comments),
    );
  }

  static List<Map<String, dynamic>>? loadReelComments(String reelId) {
    final key = '$_reelCommentsPrefix$reelId';
    final box = _openDynamicBoxOrNull(AppConstants.socialReelsBoxKey);
    if (box != null) {
      final raw = box.get(key);
      if (raw is String) {
        try {
          return (jsonDecode(raw) as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>))
              .toList();
        } catch (_) {}
      }
    }
    return _memoryReelComments[key];
  }

  static Map<String, List<Map<String, dynamic>>> loadAllReelComments() {
    final result = <String, List<Map<String, dynamic>>>{};
    final box = _openDynamicBoxOrNull(AppConstants.socialReelsBoxKey);
    if (box != null) {
      for (final rawKey in box.keys) {
        final key = rawKey.toString();
        if (key.startsWith(_reelCommentsPrefix)) {
          final clipId = key.substring(_reelCommentsPrefix.length);
          final parsed = loadReelComments(clipId);
          if (parsed != null) {
            result[clipId] = parsed;
          }
        }
      }
      return result;
    }
    for (final entry in _memoryReelComments.entries) {
      if (entry.key.startsWith(_reelCommentsPrefix)) {
        final clipId = entry.key.substring(_reelCommentsPrefix.length);
        result[clipId] = entry.value;
      }
    }
    return result;
  }

  static Future<void> saveActiveRemixContext(
    Map<String, dynamic>? contextJson,
  ) async {
    _memoryActiveRemixContext = contextJson == null
        ? null
        : Map<String, dynamic>.from(contextJson);
    if (contextJson == null) {
      await _safeBoxDelete(
        AppConstants.socialReelsBoxKey,
        _activeRemixContextKey,
      );
    } else {
      await _safeBoxPut(
        AppConstants.socialReelsBoxKey,
        _activeRemixContextKey,
        jsonEncode(contextJson),
      );
    }
  }

  static Map<String, dynamic>? loadActiveRemixContext() {
    final box = _openDynamicBoxOrNull(AppConstants.socialReelsBoxKey);
    if (box != null) {
      final raw = box.get(_activeRemixContextKey);
      if (raw is String) {
        try {
          return Map<String, dynamic>.from(
            jsonDecode(raw) as Map<dynamic, dynamic>,
          );
        } catch (_) {}
      } else if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
    }
    return _memoryActiveRemixContext;
  }

  static Future<void> saveStemRemixMutes(
    String reelId,
    Map<String, bool> stemMutes,
  ) async {
    final key = 'stem_remix_$reelId';
    _memoryStemRemixMutes[key] = Map<String, bool>.from(stemMutes);
    await _safeBoxPut(
      AppConstants.socialReelsBoxKey,
      key,
      jsonEncode(stemMutes),
    );
  }

  static Map<String, bool>? loadStemRemixMutes(String reelId) {
    final key = 'stem_remix_$reelId';
    final box = _openDynamicBoxOrNull(AppConstants.socialReelsBoxKey);
    if (box != null) {
      final raw = box.get(key);
      if (raw is String) {
        try {
          final map = jsonDecode(raw) as Map<dynamic, dynamic>;
          return map.map((k, v) => MapEntry(k.toString(), v as bool));
        } catch (_) {}
      }
    }
    return _memoryStemRemixMutes[key];
  }

  /// Clears only user-scoped L1 liked reel IDs & active stem remix state while preserving shared reels/comments.
  static void clearUserSessionMemory() {
    _memoryLikedIds = null;
    _memoryActiveRemixContext = null;
    _memoryStemRemixMutes.clear();
  }

  @visibleForTesting
  static void clearForTesting() {
    _memoryCustomClips = null;
    _memoryLoveCounts = null;
    _memoryReelComments.clear();
    clearUserSessionMemory();
  }
}

/// 7. Marketplace Beat Catalog & Exclusive Buyout Lock Cache
/// Persists in `vhunambi_marketplace_catalog_box` (Tier 1).
class MarketplaceCatalogCacheRepository {
  MarketplaceCatalogCacheRepository._();

  static const String _listingPrefix = 'listing_';
  static const String _removedListingPrefix = 'removed_listing_';

  static final Set<String> _memoryExclusiveSoldIds = <String>{};
  static final Map<String, String> _memoryExclusiveBuyers = <String, String>{};
  static final Map<String, int> _memoryBeatSalesCounts = <String, int>{};
  static final Map<String, Map<String, dynamic>> _memoryCustomListings =
      <String, Map<String, dynamic>>{};
  static final Set<String> _memoryRemovedListingIds = <String>{};

  static Future<void> saveBeatListing(Map<String, dynamic> listingJson) async {
    final beatId = (listingJson['id'] ?? '').toString();
    if (beatId.isEmpty) return;
    _memoryCustomListings[beatId] = Map<String, dynamic>.from(listingJson);
    _memoryRemovedListingIds.remove(beatId);
    await _safeBoxPut(
      AppConstants.marketplaceCatalogBoxKey,
      '$_listingPrefix$beatId',
      jsonEncode(listingJson),
    );
    await _safeBoxDelete(
      AppConstants.marketplaceCatalogBoxKey,
      '$_removedListingPrefix$beatId',
    );
    await _safeRecordMutation(AppConstants.marketplaceCatalogBoxKey);
  }

  static Future<void> removeBeatListing(String beatId) async {
    _memoryCustomListings.remove(beatId);
    _memoryRemovedListingIds.add(beatId);
    await _safeBoxDelete(
      AppConstants.marketplaceCatalogBoxKey,
      '$_listingPrefix$beatId',
    );
    await _safeBoxPut(
      AppConstants.marketplaceCatalogBoxKey,
      '$_removedListingPrefix$beatId',
      true,
    );
  }

  static List<Map<String, dynamic>> loadCustomListings() {
    final box = _openDynamicBoxOrNull(AppConstants.marketplaceCatalogBoxKey);
    if (box != null) {
      final result = <Map<String, dynamic>>[];
      for (final rawKey in box.keys) {
        final key = rawKey.toString();
        if (key.startsWith(_listingPrefix)) {
          final raw = box.get(key);
          if (raw is String) {
            try {
              result.add(
                Map<String, dynamic>.from(
                  jsonDecode(raw) as Map<dynamic, dynamic>,
                ),
              );
            } catch (_) {}
          } else if (raw is Map) {
            result.add(Map<String, dynamic>.from(raw));
          }
        }
      }
      return result;
    }
    return _memoryCustomListings.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Set<String> loadRemovedListingIds() {
    final result = <String>{..._memoryRemovedListingIds};
    final box = _openDynamicBoxOrNull(AppConstants.marketplaceCatalogBoxKey);
    if (box != null) {
      for (final rawKey in box.keys) {
        final key = rawKey.toString();
        if (key.startsWith(_removedListingPrefix) && box.get(key) == true) {
          result.add(key.substring(_removedListingPrefix.length));
        }
      }
    }
    return result;
  }

  static Future<void> markExclusiveSold(
    String beatId, {
    String? buyerId,
  }) async {
    _memoryExclusiveSoldIds.add(beatId);
    if (buyerId != null && buyerId.isNotEmpty) {
      _memoryExclusiveBuyers[beatId] = buyerId;
    }
    await _safeBoxPut(
      AppConstants.marketplaceCatalogBoxKey,
      'exclusive_sold_$beatId',
      true,
    );
    if (buyerId != null && buyerId.isNotEmpty) {
      await _safeBoxPut(
        AppConstants.marketplaceCatalogBoxKey,
        'exclusive_buyer_$beatId',
        buyerId,
      );
    }
    await _safeRecordMutation(AppConstants.marketplaceCatalogBoxKey);
  }

  static Future<void> saveSalesCount(String beatId, int totalSales) async {
    _memoryBeatSalesCounts[beatId] = totalSales;
    await _safeBoxPut(
      AppConstants.marketplaceCatalogBoxKey,
      'sales_count_$beatId',
      totalSales,
    );
  }

  static int? loadSalesCount(String beatId) {
    final box = _openDynamicBoxOrNull(AppConstants.marketplaceCatalogBoxKey);
    if (box != null) {
      final raw = box.get('sales_count_$beatId');
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
    }
    return _memoryBeatSalesCounts[beatId];
  }

  static String? loadExclusiveBuyerId(String beatId) {
    final box = _openDynamicBoxOrNull(AppConstants.marketplaceCatalogBoxKey);
    if (box != null) {
      final raw = box.get('exclusive_buyer_$beatId');
      if (raw is String && raw.isNotEmpty) return raw;
    }
    return _memoryExclusiveBuyers[beatId];
  }

  static bool isExclusiveSold(String beatId) {
    if (_memoryExclusiveSoldIds.contains(beatId)) return true;
    final box = _openDynamicBoxOrNull(AppConstants.marketplaceCatalogBoxKey);
    if (box != null) {
      final val = box.get('exclusive_sold_$beatId');
      if (val == true) {
        _memoryExclusiveSoldIds.add(beatId);
        return true;
      }
    }
    return false;
  }

  static Set<String> getAllExclusiveSoldBeatIds() {
    final result = <String>{..._memoryExclusiveSoldIds};
    final box = _openDynamicBoxOrNull(AppConstants.marketplaceCatalogBoxKey);
    if (box != null) {
      for (final rawKey in box.keys) {
        final key = rawKey.toString();
        if (key.startsWith('exclusive_sold_') && box.get(key) == true) {
          result.add(key.substring('exclusive_sold_'.length));
        }
      }
    }
    return result;
  }

  @visibleForTesting
  static void clearForTesting() {
    _memoryExclusiveSoldIds.clear();
    _memoryExclusiveBuyers.clear();
    _memoryBeatSalesCounts.clear();
    _memoryCustomListings.clear();
    _memoryRemovedListingIds.clear();
  }
}

/// 8. Sovereign Session Genesis, Content Studio Drafts & Edge Sync Cursor
/// Persists across `vhunambi_tokens`, `vhunambi_prefs`, `vhunambi_profiles`, and `vhunambi_studio_session`.
class SovereignPrefsRepository {
  SovereignPrefsRepository._();

  static const String _onboardingKey = 'onboarding_state_v1';
  static const String _edgeLastSeqKey = 'edge_sync_last_seq';
  static const String _edgeLastSyncedAtKey = 'edge_sync_last_synced_at';
  static const String _ownerProfileKey = 'profile_me';
  static const String _miniPlayerStateKey = 'mini_player_state_v1';
  static const String _generationRequestKey = 'generation_request_model_v1';

  static Map<String, dynamic>? _memoryOnboarding;
  static int? _memoryLastServerSeq;
  static DateTime? _memoryLastSyncedAt;
  static Map<String, dynamic>? _memoryOwnerProfile;
  static Map<String, dynamic>? _memoryMiniPlayerState;
  static Map<String, dynamic>? _memoryGenerationRequest;
  static final Map<String, Map<String, dynamic>> _memoryContentStudioDrafts =
      <String, Map<String, dynamic>>{};

  static Future<void> saveOnboardingState(Map<String, dynamic> state) async {
    _memoryOnboarding = Map<String, dynamic>.from(state);
    await _safeBoxPut(
      AppConstants.tokenBoxKey,
      _onboardingKey,
      jsonEncode(state),
    );
  }

  static Map<String, dynamic>? loadOnboardingState() {
    final box = _openDynamicBoxOrNull(AppConstants.tokenBoxKey);
    if (box != null) {
      final raw = box.get(_onboardingKey);
      if (raw is String) {
        try {
          return Map<String, dynamic>.from(
            jsonDecode(raw) as Map<dynamic, dynamic>,
          );
        } catch (_) {}
      }
    }
    return _memoryOnboarding;
  }

  static Future<void> saveEdgeSyncCursor({
    required int lastServerSeq,
    required DateTime lastSyncedAt,
  }) async {
    _memoryLastServerSeq = lastServerSeq;
    _memoryLastSyncedAt = lastSyncedAt;
    await _safeBoxPut(AppConstants.prefsBoxKey, _edgeLastSeqKey, lastServerSeq);
    await _safeBoxPut(
      AppConstants.prefsBoxKey,
      _edgeLastSyncedAtKey,
      lastSyncedAt.toIso8601String(),
    );
  }

  static int loadEdgeSyncLastSeq() {
    final box = _openDynamicBoxOrNull(AppConstants.prefsBoxKey);
    if (box != null) {
      final raw = box.get(_edgeLastSeqKey);
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
    }
    return _memoryLastServerSeq ?? 0;
  }

  static DateTime? loadEdgeSyncLastSyncedAt() {
    final box = _openDynamicBoxOrNull(AppConstants.prefsBoxKey);
    if (box != null) {
      final raw = box.get(_edgeLastSyncedAtKey);
      if (raw is String) {
        return DateTime.tryParse(raw);
      }
    }
    return _memoryLastSyncedAt;
  }

  static Future<void> saveContentStudioDraft(
    String trackId,
    Map<String, dynamic> draftJson,
  ) async {
    final key = 'content_studio_draft_$trackId';
    _memoryContentStudioDrafts[key] = Map<String, dynamic>.from(draftJson);
    await _safeBoxPut(
      AppConstants.studioSessionBoxKey,
      key,
      jsonEncode(draftJson),
    );
  }

  static Map<String, dynamic>? loadContentStudioDraft(String trackId) {
    final key = 'content_studio_draft_$trackId';
    final box = _openDynamicBoxOrNull(AppConstants.studioSessionBoxKey);
    if (box != null) {
      final raw = box.get(key);
      if (raw is String) {
        try {
          return Map<String, dynamic>.from(
            jsonDecode(raw) as Map<dynamic, dynamic>,
          );
        } catch (_) {}
      }
    }
    return _memoryContentStudioDrafts[key];
  }

  static Future<void> clearContentStudioDraft(String trackId) async {
    final key = 'content_studio_draft_$trackId';
    _memoryContentStudioDrafts.remove(key);
    await _safeBoxDelete(AppConstants.studioSessionBoxKey, key);
  }

  static Future<void> saveMiniPlayerState(Map<String, dynamic> state) async {
    _memoryMiniPlayerState = Map<String, dynamic>.from(state);
    await _safeBoxPut(
      AppConstants.prefsBoxKey,
      _miniPlayerStateKey,
      jsonEncode(state),
    );
  }

  static Map<String, dynamic>? loadMiniPlayerState() {
    final box = _openDynamicBoxOrNull(AppConstants.prefsBoxKey);
    if (box != null) {
      final raw = box.get(_miniPlayerStateKey);
      if (raw is String) {
        try {
          return Map<String, dynamic>.from(
            jsonDecode(raw) as Map<dynamic, dynamic>,
          );
        } catch (_) {}
      } else if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
    }
    return _memoryMiniPlayerState;
  }

  static Future<void> saveGenerationRequest(
    Map<String, dynamic> modelJson,
  ) async {
    _memoryGenerationRequest = Map<String, dynamic>.from(modelJson);
    await _safeBoxPut(
      AppConstants.studioSessionBoxKey,
      _generationRequestKey,
      jsonEncode(modelJson),
    );
  }

  static Map<String, dynamic>? loadGenerationRequest() {
    final box = _openDynamicBoxOrNull(AppConstants.studioSessionBoxKey);
    if (box != null) {
      final raw = box.get(_generationRequestKey);
      if (raw is String) {
        try {
          return Map<String, dynamic>.from(
            jsonDecode(raw) as Map<dynamic, dynamic>,
          );
        } catch (_) {}
      } else if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
    }
    return _memoryGenerationRequest;
  }

  /// Persists the account owner `'me'` profile under key `profile_me` in
  /// `vhunambi_profiles` using the same envelope structure as [ProfileCache].
  static Future<void> saveOwnerProfile(Map<String, dynamic> profileJson) async {
    _memoryOwnerProfile = Map<String, dynamic>.from(profileJson);
    final envelope = <String, dynamic>{
      'profile': Map<String, dynamic>.from(profileJson),
      'timestamp': DateTime.now().toIso8601String(),
    };
    await _safeBoxPut(
      AppConstants.profileBoxKey,
      _ownerProfileKey,
      jsonEncode(envelope),
    );
  }

  static Map<String, dynamic>? loadOwnerProfile() {
    final box = _openDynamicBoxOrNull(AppConstants.profileBoxKey);
    if (box != null) {
      final raw = box.get(_ownerProfileKey);
      if (raw != null) {
        try {
          final Map<String, dynamic> decoded = raw is String
              ? Map<String, dynamic>.from(
                  jsonDecode(raw) as Map<dynamic, dynamic>,
                )
              : Map<String, dynamic>.from(raw as Map<dynamic, dynamic>);
          if (decoded['profile'] is Map) {
            return Map<String, dynamic>.from(decoded['profile'] as Map);
          }
          return decoded;
        } catch (_) {}
      }
    }
    return _memoryOwnerProfile;
  }

  /// Clears tenant-scoped L1 preferences, profile & sync cursor while explicitly preserving [_memoryOnboarding].
  static void clearTenantSessionMemory() {
    _memoryLastServerSeq = null;
    _memoryLastSyncedAt = null;
    _memoryOwnerProfile = null;
    _memoryMiniPlayerState = null;
    _memoryGenerationRequest = null;
    _memoryContentStudioDrafts.clear();
  }

  @visibleForTesting
  static void clearForTesting() {
    _memoryOnboarding = null;
    clearTenantSessionMemory();
  }
}
