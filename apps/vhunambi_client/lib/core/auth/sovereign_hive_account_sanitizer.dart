import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vhunambi_client/core/auth/sovereign_auth_repository.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/storage/checkout_write_ahead_journal.dart';
import 'package:vhunambi_client/core/storage/hive_aes_vault_cipher.dart';
import 'package:vhunambi_client/core/storage/sovereign_domain_repositories.dart';
import 'package:vhunambi_client/core/storage/sovereign_hive_bootstrap_service.dart';
import 'package:vhunambi_client/features/sound_signature/data/sound_signature_repository.dart';

/// Multi-tenant Hive cache boundary sanitizer (`Phase 61`).
///
/// Clears all tenant-private Sovereign Hive boxes (`Box<dynamic>` and `Box<Map>`)
/// and L1 in-memory caches on account switch or explicit logout, while preserving
/// shared public catalogs ([AppConstants.tracksBoxKey], [AppConstants.marketplaceCatalogBoxKey],
/// [AppConstants.socialReelsBoxKey]), device theme preference, and the per-device
/// CSPRNG AES genesis salt (`HiveAesVaultCipher.deviceGenesisSaltPrefsKey`).
class SovereignHiveAccountSanitizer {
  SovereignHiveAccountSanitizer._();

  /// Shared public catalog & device-level boxes retained across account switches.
  static const Set<String> preservedSharedBoxes = <String>{
    AppConstants.tracksBoxKey,
    AppConstants.marketplaceCatalogBoxKey,
    AppConstants.socialReelsBoxKey,
    AppConstants.themePrefsBoxKey,
  };

  /// Private tenant-scoped Sovereign Hive boxes wiped on account switch / logout.
  static const List<String> tenantPrivateBoxKeys = <String>[
    AppConstants.creatorDnaBoxKey,
    AppConstants.syncOutboxBoxKey,
    AppConstants.walletLedgerBoxKey,
    AppConstants.playbackSessionBoxKey,
    AppConstants.libraryTracksV1BoxKey,
    AppConstants.vaultBoxKey,
    AppConstants.playlistsBoxKey,
    AppConstants.collectionsBoxKey,
    AppConstants.beatsBoxKey,
    AppConstants.licenseCertificatesBoxKey,
    AppConstants.profilesBoxKey,
    AppConstants.notificationsBoxKey,
    AppConstants.studioSessionBoxKey,
    AppConstants.voiceProfilesBoxKey,
    AppConstants.melodySketchesBoxKey,
    AppConstants.soundPacksBoxKey,
    AppConstants.stemDspRecipesBoxKey,
    AppConstants.crateMpcKitsBoxKey,
    AppConstants.mmoManifestBoxKey,
    AppConstants.soundSignaturesBoxKey,
  ];

  /// Alias matching Phase 61 design specification (`design.md` §2.4).
  static Future<List<String>> sanitizeForAccountTransition({
    String? previousCreatorId,
    String? nextCreatorId,
    bool forcePurge = false,
    bool clearAuthSession = false,
  }) async {
    final isSameCreator =
        previousCreatorId != null &&
        nextCreatorId != null &&
        previousCreatorId.trim() == nextCreatorId.trim();
    if (isSameCreator && !forcePurge) {
      return const <String>[];
    }
    return purgeTenantPrivateBoxes(clearAuthSession: clearAuthSession);
  }

  /// Purges all tenant-private boxes and L1 memory caches, returning the list
  /// of open box keys cleared.
  static Future<List<String>> purgeTenantPrivateBoxes({
    bool clearAuthSession = true,
  }) async {
    final cleared = <String>[];

    SovereignDomainStorageMode.clearTenantMemory();
    CheckoutWriteAheadJournal.clearSessionMemory();
    SoundSignatureRepository.clearSessionMemory();
    if (clearAuthSession) {
      SovereignAuthRepository.clearSessionMemory();
    }

    if (kIsWeb) {
      return cleared;
    }

    for (final boxKey in tenantPrivateBoxKeys) {
      try {
        if (!Hive.isBoxOpen(boxKey)) continue;
        if (SovereignHiveBootstrapService.mapTypedBoxKeys.contains(boxKey)) {
          final mapBox = Hive.box<Map>(boxKey);
          if (mapBox.isOpen) {
            await mapBox.clear();
            cleared.add(boxKey);
          }
        } else {
          final dynBox = Hive.box<dynamic>(boxKey);
          if (dynBox.isOpen) {
            await dynBox.clear();
            cleared.add(boxKey);
          }
        }
      } catch (_) {}
    }

    // Selectively sanitize `vhunambi_tokens` while preserving onboarding state.
    if (clearAuthSession) {
      try {
        if (Hive.isBoxOpen(AppConstants.tokenBoxKey)) {
          final tokenBox = Hive.box<dynamic>(AppConstants.tokenBoxKey);
          if (tokenBox.isOpen) {
            await tokenBox.delete(SovereignAuthRepository.sessionStorageKey);
            cleared.add(AppConstants.tokenBoxKey);
          }
        }
      } catch (_) {}
    }

    // Selectively sanitize tenant keys in `vhunambi_prefs`, NEVER deleting
    // `HiveAesVaultCipher.deviceGenesisSaltPrefsKey`.
    try {
      if (Hive.isBoxOpen(AppConstants.prefsBoxKey)) {
        final prefsBox = Hive.box<dynamic>(AppConstants.prefsBoxKey);
        if (prefsBox.isOpen) {
          final keysToDelete = prefsBox.keys
              .where((k) {
                final s = k.toString();
                if (s == HiveAesVaultCipher.deviceGenesisSaltPrefsKey) {
                  return false;
                }
                return s == 'edge_sync_last_seq' ||
                    s == 'edge_sync_last_synced_at' ||
                    s == 'mini_player_state_v1' ||
                    s.startsWith('checkout_wal_');
              })
              .toList(growable: false);
          for (final k in keysToDelete) {
            await prefsBox.delete(k);
          }
        }
      }
    } catch (_) {}

    // Selectively sanitize user-scoped likes/follows/searches in preserved catalog boxes
    // while keeping shared public catalogs (`explore_shared_1`, custom posts/tracks) intact.
    try {
      if (Hive.isBoxOpen(AppConstants.tracksBoxKey)) {
        final tracksBox = Hive.box<dynamic>(AppConstants.tracksBoxKey);
        if (tracksBox.isOpen) {
          const userScopedTrackKeys = <String>[
            'explore_liked_track_ids_v1',
            'explore_liked_post_ids_v1',
            'explore_following_ids_v1',
            'explore_recent_searches_v1',
          ];
          for (final key in userScopedTrackKeys) {
            if (tracksBox.containsKey(key)) {
              await tracksBox.delete(key);
            }
          }
        }
      }
    } catch (_) {}

    try {
      if (Hive.isBoxOpen(AppConstants.socialReelsBoxKey)) {
        final reelsBox = Hive.box<dynamic>(AppConstants.socialReelsBoxKey);
        if (reelsBox.isOpen) {
          final keysToDelete = reelsBox.keys
              .where((k) {
                final s = k.toString();
                return s == 'reel_liked_ids_v1' ||
                    s == 'active_stem_remix_context_v1' ||
                    s.startsWith('stem_remix_');
              })
              .toList(growable: false);
          for (final k in keysToDelete) {
            await reelsBox.delete(k);
          }
        }
      }
    } catch (_) {}

    return cleared;
  }
}

