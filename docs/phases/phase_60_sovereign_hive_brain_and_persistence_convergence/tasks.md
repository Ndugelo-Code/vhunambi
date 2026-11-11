# Phase 60 Implementation Tasks: Sovereign Hive Brain Activation, Unified Persistence & Edge-Sync Convergence

> **Phase ID**: `phase_60_sovereign_hive_brain_and_persistence_convergence`
> **Engineering Standard**: All-Gemini Engineering Standard (`STD-ARCH-060`, `STD-UIUX-001`, `STD-SEC-012`)
> **Execution Mode**: Ready for Stage 4 Execution

---

## Milestone Overview

| Milestone | Title | Tasks | Verification Gate(s) |
| :--- | :--- | :---: | :---: |
| **`M60.1`** | **Sovereign 26-Box Bootstrap, AES-256 Cipher, Compaction Scheduler & Checkout WAL** | `60.1.1` – `60.1.5` | `G-60-01`, `G-60-07` |
| **`M60.2`** | **Onboarding Hydration, Notification Wiring, SoundSignature L1 & Vault `.vmf` Purge Fixes** | `60.2.1` – `60.2.4` | `G-60-02`, `G-60-03`, `G-60-05` |
| **`M60.3`** | **Persisting Ignored Domains Part I: Wallet Ledger, Playback Session, Stem DSP & Crate/MPC Kits** | `60.3.1` – `60.3.5` | `G-60-04` |
| **`M60.4`** | **Persisting Ignored Domains Part II: Explore, Social Reels, Marketplace, Content Studio & `'me'` Profile** | `60.4.1` – `60.4.5` | `G-60-04` |
| **`M60.5`** | **$O(1)$ Entity-Keyed Storage Refactor & `EdgeSyncCoordinator` Convergence** | `60.5.1` – `60.5.3` | `G-60-06`, `G-60-07` |
| **`M60.6`** | **Sovereign Hive Brain Telemetry HUD & Comprehensive Verification Suite** | `60.6.1` – `60.6.4` | `G-60-08` |

---

## Milestone `M60.1`: Sovereign 26-Box Bootstrap, AES-256 Cipher, Compaction Scheduler & Checkout WAL

- [x] **Task `60.1.1` — Register All 26 Sovereign Hive Box Keys in `AppConstants`** (`REQ-P60-BOOT-01`)
  - **File**: `apps/vhunambi_client/lib/core/constants/app_constants.dart`
  - **Action**: Add constants `walletLedgerBoxKey`, `playbackSessionBoxKey`, `libraryTracksV1BoxKey`, `notificationsBoxKey`, `stemDspRecipesBoxKey`, `crateMpcKitsBoxKey`, `socialReelsBoxKey`, and `marketplaceCatalogBoxKey`, while documenting the repurposed `tokenBoxKey = 'vhunambi_tokens'` and `tracksBoxKey = 'vhunambi_tracks'`.
  - **Acceptance**: `AppConstants` exposes all 26 box keys with zero analyzer warnings.

- [x] **Task `60.1.2` — Implement `HiveAesVaultCipher` (HKDF-SHA256 256-Bit Key Derivation)** (`REQ-P60-UPG-02`)
  - **Files**:
    - `apps/vhunambi_client/lib/core/storage/hive_aes_vault_cipher.dart`
    - `apps/vhunambi_client/lib/features/offline/domain/services/vault_envelope_crypto.dart`
  - **Action**: Implement `HiveAesVaultCipher.derive256BitKey()` and `HiveAesVaultCipher.createCipher()`. Update `VaultEnvelopeCrypto._deriveDefaultKey()` to delegate to `HiveAesVaultCipher.derive256BitKey()` so both Hive boxes and `.vmf` envelopes share the deterministic 256-bit HKDF-SHA256 key.
  - **Acceptance**: `HiveAesVaultCipher.derive256BitKey()` returns a 32-byte `Uint8List` and creates a valid `HiveAesCipher`.

- [x] **Task `60.1.3` — Implement `HiveCompactionScheduler` & `CheckoutWriteAheadJournal`** (`REQ-P60-UPG-03`, `REQ-P60-UPG-04`)
  - **Files**:
    - `apps/vhunambi_client/lib/core/storage/hive_compaction_scheduler.dart`
    - `apps/vhunambi_client/lib/core/storage/checkout_write_ahead_journal.dart`
    - `apps/vhunambi_client/lib/features/marketplace/presentation/providers/beat_checkout_provider.dart`
  - **Action**: Create `HiveCompactionScheduler` ($\Phi_{\text{frag}}(b) \ge 0.20$ and $M_{\text{mutations}}(b) \ge 25$) and `CheckoutWriteAheadJournal` (`vhunambi_prefs` key `checkout_wal_<txId>`). Wrap `BeatCheckoutNotifier.purchaseBeat()` with `prepareCheckout(...)` before mutating stores and `commitCheckout(...)` upon completion.
  - **Acceptance**: Interrupted checkout WAL entries are recovered idempotently via `CheckoutWriteAheadJournal.recoverInterruptedTransactions()`.

- [x] **Task `60.1.4` — Implement `SovereignHiveBootstrapService` & Wire `main.dart`** (`REQ-P60-BOOT-02`, `REQ-P60-BOOT-03`)
  - **Files**:
    - `apps/vhunambi_client/lib/core/storage/sovereign_hive_bootstrap_service.dart`
    - `apps/vhunambi_client/lib/main.dart`
  - **Action**: Implement `SovereignHiveBootstrapService.ensureInitialized()`, `openAllBoxes()`, and `getTelemetrySnapshot()`. Update `main()` in `apps/vhunambi_client/lib/main.dart` to `Future<void> main() async` and await `SovereignHiveBootstrapService.ensureInitialized()` before `runApp(...)`.
  - **Acceptance**: All 26 boxes open cleanly in native mode and skip disk I/O in `FLUTTER_TEST` mode.

---

## Milestone `M60.2`: Onboarding Hydration, Notification Wiring, SoundSignature L1 & Vault `.vmf` Purge Fixes

- [x] **Task `60.2.1` — Persist & Hydrate `OnboardingNotifier` and `SplashView` Route Gate** (`REQ-P60-BOOT-04`, `REQ-P60-BOOT-05`)
  - **Files**:
    - `apps/vhunambi_client/lib/features/onboarding/presentation/providers/onboarding_providers.dart`
    - `apps/vhunambi_client/lib/features/onboarding/presentation/views/splash_view.dart`
  - **Action**: Hydrate `OnboardingNotifier` on construction from `SovereignPrefsRepository.loadOnboardingState()` (with fallback check on `CreatorDnaRepository.loadProfile()`). Persist state in `setBirthYear`, `toggleCulturalHeritage`, `setInitialTracks`, `completeOnboarding`, and `resetOnboarding`.
  - **Acceptance**: Returning users with `hasCompletedOnboarding == true` navigate from `SplashView` directly to `'/'`.

- [x] **Task `60.2.2` — Upgrade `NotificationRepository` to $O(1)$ Keys & Wire `NotificationsNotifier`** (`REQ-P60-FIX-01`)
  - **Files**:
    - `apps/vhunambi_client/lib/features/notifications/data/repositories/notification_repository.dart`
    - `apps/vhunambi_client/lib/features/notifications/presentation/providers/notifications_provider.dart`
  - **Action**: Refactor `NotificationRepository` to store each notification under `notif_<id>` with automatic migration from legacy `'notifications'` list key. Inject `NotificationRepository` into `NotificationsNotifier` so notifications load from persistence and seed only when empty.
  - **Acceptance**: Notification read states, additions, and deletions persist across `ProviderContainer` restarts.

- [x] **Task `60.2.3` — Add L1 In-Memory Fallback to `SoundSignatureRepository`** (`REQ-P60-FIX-02`)
  - **File**: `apps/vhunambi_client/lib/features/sound_signature/data/sound_signature_repository.dart`
  - **Action**: Add `static final Map<String, Uint8List> _inMemorySignatures` to `SoundSignatureRepository` and update `saveSignature`, `getSignature`, `getAllSignatures`, and `deleteSignature` to read/write both Hive (when open) and `_inMemorySignatures`.
  - **Acceptance**: Saving and loading `.vss` sound signatures succeeds in both headless `flutter test` and native Hive.

- [x] **Task `60.2.4` — Fix Vault `.vmf` Leak on `purgeTrackPermanently` & Real Storage Quota Accounting** (`REQ-P60-FIX-03`, `REQ-P60-FIX-04`)
  - **Files**:
    - `apps/vhunambi_client/lib/features/library/presentation/providers/library_providers.dart`
    - `apps/vhunambi_client/lib/features/offline/presentation/providers/offline_providers.dart`
  - **Action**: In `LibraryTracksNotifier.purgeTrackPermanently(String id)`, also invoke `OfflineStorageService.removeTrackMetadata(id)` (`offlineStorageServiceProvider`). Update `cacheStorageStatsProvider` to include real `OfflineStorageService.getTotalCachedSizeBytes()` and Hive brain bytes.
  - **Acceptance**: Purging a track deletes its `library_tracks` metadata and `.vmf` file on disk; `cacheStorageStatsProvider` reflects real byte sizes.

---

## Milestone `M60.3`: Persisting Ignored Domains Part I (Wallet, Playback, Stem DSP & Crate/MPC)

- [x] **Task `60.3.1` — Create `sovereign_domain_repositories.dart`** (`REQ-P60-DOM-01..08`)
  - **File**: `apps/vhunambi_client/lib/core/storage/sovereign_domain_repositories.dart`
  - **Action**: Implement `WalletLedgerRepository`, `PlaybackSessionRepository`, `StemDspRecipeRepository`, `CrateMpcKitsRepository`, `ExploreCacheRepository`, `SocialReelsCacheRepository`, `MarketplaceCatalogCacheRepository`, and `SovereignPrefsRepository`.
  - **Acceptance**: All 8 domain repositories compile cleanly and support both Hive box persistence and L1 memory fallback.

- [x] **Task `60.3.2` — Wire `CreatorWalletNotifier` to `WalletLedgerRepository`** (`REQ-P60-DOM-01`)
  - **File**: `apps/vhunambi_client/lib/features/social/presentation/providers/creator_wallet_provider.dart`
  - **Action**: Hydrate `CreatorWalletState` (`userCoinsBalance`, `creatorEarnedZar`, `creatorReceivedCoins`, `transactions`) from `WalletLedgerRepository.loadWalletSnapshot()` on startup, and persist after `topUpCoins`, `sendCoinTip`, `deductForBeatPurchase`, `withdrawPayout`, and `refreshFromCloud`. Add `savePayoutBankDetails(...)` / `savedBankDetails` persistence.
  - **Acceptance**: Wallet coin balance, ZAR earnings, transaction ledger, and saved SA bank details survive restarts offline.

- [x] **Task `60.3.3` — Wire `PlayerNotifier`, `playerHeroModeProvider` & `RecentlyPlayedNotifier` to `PlaybackSessionRepository`** (`REQ-P60-DOM-02`)
  - **Files**:
    - `apps/vhunambi_client/lib/features/player/presentation/providers/player_provider.dart`
    - `apps/vhunambi_client/lib/features/library/presentation/providers/library_providers.dart`
  - **Action**: Hydrate `PlayerNotifier` (`currentTrack`, `queue`, `position`, `isShuffle`, `repeatMode`, with `isPlaying: false` on cold start) and `RecentlyPlayedNotifier` (`recentlyPlayedIdsProvider`) from `PlaybackSessionRepository`, and persist on track change, seek, queue mutation, shuffle/repeat toggle, and recently played recording.
  - **Acceptance**: Active track, queue, seek position, repeat/shuffle mode, and 20-item recently played list survive restarts.

- [x] **Task `60.3.4` — Wire `StemMixerNotifier` & `MasteringSessionNotifier` to `StemDspRecipeRepository`** (`REQ-P60-DOM-03`)
  - **Files**:
    - `apps/vhunambi_client/lib/features/player/presentation/providers/stem_mixer_provider.dart`
    - `apps/vhunambi_client/lib/features/mastering/presentation/providers/mastering_session_provider.dart`
  - **Action**: Hydrate and persist `StemMixerState.toJson()` / `fromJson()` in `StemMixerNotifier` and `StemMasteringRecipe.toJson()` / `fromJson()` in `MasteringSessionNotifier` via `StemDspRecipeRepository`.
  - **Acceptance**: Custom 4-stem fader/mute/solo/DSP mixes and mastering recipes persist per track.

- [x] **Task `60.3.5` — Wire `HeritageCrateNotifier`, `MpcSlicerNotifier` & `MyceliumBiomeGraphNotifier` to `CrateMpcKitsRepository`** (`REQ-P60-DOM-04`)
  - **Files**:
    - `apps/vhunambi_client/lib/features/studio/presentation/providers/heritage_crate_provider.dart`
    - `apps/vhunambi_client/lib/features/studio/presentation/providers/mycelium_biome_provider.dart`
  - **Action**: Persist and hydrate favorite sample IDs in `HeritageCrateNotifier`, custom 8-pad MPC slice kits in `MpcSlicerNotifier`, and custom 3D Mycelium Biome harmony leaves in `MyceliumBiomeGraphNotifier` via `CrateMpcKitsRepository`.
  - **Acceptance**: Starred Crate samples, edited 8-pad MPC kits, and custom 3D Biome leaves persist across restarts.

---

## Milestone `M60.4`: Persisting Ignored Domains Part II (Explore, Social Reels, Marketplace, Content Studio & `'me'` Profile)

- [x] **Task `60.4.1` — Wire `ExploreTracksNotifier`, `coSignVotesProvider` & `recentSearchesProvider` to `ExploreCacheRepository`** (`REQ-P60-DOM-05`)
  - **File**: `apps/vhunambi_client/lib/features/explore/presentation/providers/explore_providers.dart`
  - **Action**: Hydrate and persist liked track IDs in `ExploreTracksNotifier`, A&R Co-Sign vote counts in `CoSignVotesNotifier`, and recent search queries in `RecentSearchesNotifier` via `ExploreCacheRepository` (`vhunambi_tracks`).
  - **Acceptance**: Explore likes, A&R Co-Sign votes, and recent searches survive restarts.

- [x] **Task `60.4.2` — Wire `SocialFeedNotifier`, `ReelsCommentsNotifier` & `StemRemixNotifier` to `SocialReelsCacheRepository`** (`REQ-P60-DOM-06`)
  - **Files**:
    - `apps/vhunambi_client/lib/features/social/presentation/providers/social_feed_provider.dart`
    - `apps/vhunambi_client/lib/features/social/presentation/providers/reels_comments_provider.dart`
    - `apps/vhunambi_client/lib/features/social/presentation/providers/stem_remix_provider.dart`
  - **Action**: Persist and hydrate reel multi-tap love counts and liked states in `SocialFeedNotifier`, user-added timestamped comments in `ReelsCommentsNotifier`, and stem remix mute toggles in `StemRemixNotifier` via `SocialReelsCacheRepository` (`vhunambi_social_reels_box`).
  - **Acceptance**: Multi-tap love counts, posted reel comments, and stem remix mute states survive restarts.

- [x] **Task `60.4.3` — Wire `MarketplaceBeatsNotifier` & `HttpMarketplaceRepository` to `MarketplaceCatalogCacheRepository`** (`REQ-P60-DOM-07`)
  - **Files**:
    - `apps/vhunambi_client/lib/features/marketplace/data/repositories/http_marketplace_repository.dart`
    - `apps/vhunambi_client/lib/features/marketplace/presentation/providers/marketplace_providers.dart`
  - **Action**: Persist `markExclusiveSold(beatId)` into `MarketplaceCatalogCacheRepository` (`vhunambi_marketplace_catalog_box`) and overlay persisted `isExclusiveSold` flags when loading beats in `HttpMarketplaceRepository` and `MarketplaceBeatsNotifier`.
  - **Acceptance**: Exclusive beat buyout locks persist across cold restarts.

- [x] **Task `60.4.4` — Wire `ContentStudioNotifier` & `ArtistProfileNotifier` (`'me'`) Persistence** (`REQ-P60-DOM-08`)
  - **Files**:
    - `apps/vhunambi_client/lib/features/content_studio/presentation/providers/content_studio_provider.dart`
    - `apps/vhunambi_client/lib/features/profile/presentation/providers/profile_providers.dart`
    - `apps/vhunambi_client/lib/features/profile/data/datasources/profile_cache.dart`
  - **Action**: Persist and hydrate `ContentStudioState` (`selectedPreset`, `effects`, `startTime`, `endTime`, `lyrics`) via `SovereignPrefsRepository.saveContentStudioDraft(trackId, ...)`. In `ArtistProfileNotifier`, hydrate `'me'` from `ProfileCache` on init, write through `updateProfile`, `pinTrack`, `unpinTrack`, `sendTip`, and `toggleTipsEnabled` to `ProfileCache`, and exempt `'me'` from LRU eviction in `ProfileCache._enforceSizeLimit()`.
  - **Acceptance**: Content Studio edits and `'me'` profile customizations survive restarts.

---

## Milestone `M60.5`: $O(1)$ Entity-Keyed Storage Refactor & `EdgeSyncCoordinator` Convergence

- [x] **Task `60.5.1` — Upgrade `CreatorDnaRepository`, `VocalIdentityNotifier` & `MelodySketchpadNotifier` to $O(1)$ Entity Keys** (`REQ-P60-UPG-01`)
  - **Files**:
    - `apps/vhunambi_client/lib/features/creator_dna/data/repositories/creator_dna_repository.dart`
    - `apps/vhunambi_client/lib/features/studio/presentation/providers/vocal_identity_provider.dart`
    - `apps/vhunambi_client/lib/features/studio/presentation/providers/melody_sketchpad_provider.dart`
  - **Action**: Store Creator DNA behavioral events in $O(1)$ ring keys (`dna_evt_<0..499>` + `dna_evt_cursor`), voice clones under `voice_<id>`, and melody sketches under `sketch_<id>`, migrating legacy monolithic keys on read.
  - **Acceptance**: Single-event or single-entity mutations perform $O(1)$ writes and preserve backward compatibility.

- [x] **Task `60.5.2` — Upgrade `EdgeSyncCoordinator` (Port 3000, Persisted `lastServerSeq`, Delta Hydrators & AppLifecycle Resume)** (`REQ-P60-FIX-05`, `REQ-P60-FIX-06`)
  - **Files**:
    - `apps/vhunambi_client/lib/core/sync/edge_sync_coordinator.dart`
    - `apps/vhunambi_client/lib/main.dart`
  - **Action**: Point `edgeSyncCoordinatorProvider` default `baseUrl` to port `3000` (`http://localhost:3000` / `http://10.0.2.2:3000`), hydrate and persist `lastServerSeq` & `lastSyncedAt` via `SovereignPrefsRepository`, register `library_track` and `playlist` delta hydrators, and attach an `AppLifecycleListener` in `VhunambiApp` calling `onAppResumed()`.
  - **Acceptance**: `EdgeSyncCoordinator` persists `lastServerSeq` across restarts, defaults to port 3000, and invokes registered delta hydrators.

---

## Milestone `M60.6`: Sovereign Hive Brain Telemetry HUD & Comprehensive Verification Suite

- [x] **Task `60.6.1` — Create `HiveBrainTelemetryCard` & Embed in `ProfileSettingsDrawer`** (`REQ-P60-HUD-01`)
  - **Files**:
    - `apps/vhunambi_client/lib/features/profile/presentation/widgets/hive_brain_telemetry_card.dart`
    - `apps/vhunambi_client/lib/features/profile/presentation/widgets/profile_settings_drawer.dart`
  - **Action**: Implement `HiveBrainTelemetryCard` (`Key('hive_brain_status_card')`, `Key('hive_encryption_verified_pill')`, `Key('hive_box_metrics_badge')`, `Key('hive_compact_now_btn')`, `Key('hive_sync_now_btn')`) and render it inside `ProfileSettingsDrawer`.
  - **Acceptance**: `ProfileSettingsDrawer` displays the Sovereign Hive Brain telemetry card and triggers compaction / sync on tap.

- [x] **Task `60.6.2` — Author Unit, Integration & Widget Verification Suites** (`G-60-01` .. `G-60-08`)
  - **Files**:
    - `apps/vhunambi_client/test/features/storage/sovereign_hive_bootstrap_test.dart`
    - `apps/vhunambi_client/test/features/storage/ignored_domains_persistence_test.dart`
    - `apps/vhunambi_client/test/features/storage/hive_fixes_and_upgrades_test.dart`
    - `apps/vhunambi_client/test/features/storage/hive_brain_telemetry_hud_test.dart`
  - **Action**: Write comprehensive unit and widget tests verifying all 26 boxes, onboarding hydration, notification & sound signature persistence, all 10 newly persisted domains, `.vmf` purge cleanup, `EdgeSyncCoordinator` sequence persistence, `HiveAesVaultCipher`, `CheckoutWriteAheadJournal`, `HiveCompactionScheduler`, and `HiveBrainTelemetryCard`.
  - **Acceptance**: `flutter test` passes 100% of test cases and `flutter analyze` reports 0 errors.

---

## Stage 4 Verification Commands

```powershell
# 1. Static Analysis Gate (Zero Errors)
cd apps/vhunambi_client
flutter analyze

# 2. Sovereign Hive Brain & Persistence Convergence Test Suite
flutter test test/features/storage/sovereign_hive_bootstrap_test.dart `
             test/features/storage/ignored_domains_persistence_test.dart `
             test/features/storage/hive_fixes_and_upgrades_test.dart `
             test/features/storage/hive_brain_telemetry_hud_test.dart
```

