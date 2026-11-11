# Phase 60 Requirements: Sovereign Hive Brain Activation, Unified Persistence & Edge-Sync Convergence

> **Phase ID**: `phase_60_sovereign_hive_brain_and_persistence_convergence`
> **Requirement Syntax**: Formal EARS (Easy Approach to Requirements Syntax — `WHEN`, `WHILE`, `IF...THEN`, `WHERE`, `SHALL`)
> **Engineering Standard**: All-Gemini Engineering Standard (`STD-ARCH-060`, `STD-UIUX-001`, `STD-SEC-012`)

---

## 1. Sovereign Hive Bootstrapping & Splash Hydration (`REQ-P60-BOOT`)

### `REQ-P60-BOOT-01` — Sovereign 26-Box Registry in `AppConstants`
- **Statement**: **WHERE** `AppConstants` ([`app_constants.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/core/constants/app_constants.dart)) defines Hive box keys, the system **SHALL** declare constants for all 26 Sovereign Hive Boxes, adding `walletLedgerBoxKey = 'vhunambi_wallet_ledger_box'`, `playbackSessionBoxKey = 'vhunambi_playback_session_box'`, `stemDspRecipesBoxKey = 'vhunambi_stem_dsp_recipes_box'`, `crateMpcKitsBoxKey = 'vhunambi_crate_mpc_kits_box'`, `socialReelsBoxKey = 'vhunambi_social_reels_box'`, `marketplaceCatalogBoxKey = 'vhunambi_marketplace_catalog_box'`, and `notificationsBoxKey = 'notifications_v1'`, while repurposing `tokenBoxKey = 'vhunambi_tokens'` for Sovereign Auth/Onboarding Genesis and `tracksBoxKey = 'vhunambi_tracks'` for Explore Discovery & Radio Cache.
- **Acceptance Criteria**:
  1. `SovereignHiveBootstrapService.allBoxKeys` contains exactly 26 distinct box names.
  2. `SovereignHiveBootstrapService.encryptedBoxKeys` contains the 7 AES-256 protected box names (`vhunambi_tokens`, `vhunambi_creator_dna`, `vhunambi_voice_profiles_box`, `vhunambi_sound_signatures_box`, `vhunambi_license_certificates`, `vhunambi_sync_outbox_box`, `vhunambi_wallet_ledger_box`).

### `REQ-P60-BOOT-02` — Production `Hive.initFlutter()` & 3-Tier Parallel Open in `main.dart`
- **Statement**: **WHEN** the application starts in [`main.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/main.dart) on a non-Web native runtime outside `FLUTTER_TEST`, the system **SHALL** execute `await SovereignHiveBootstrapService.ensureInitialized()` before `runApp(...)`, calling `await Hive.initFlutter()`, deriving the 256-bit `HiveAesCipher`, and opening all 26 boxes across Tier 0 (7 boxes), Tier 1 (17 boxes), and Tier 2 (2 boxes).
- **Acceptance Criteria**:
  1. `main()` is `Future<void> main() async` and awaits `SovereignHiveBootstrapService.ensureInitialized()`.
  2. If a corrupted or legacy unencrypted box throws during encrypted open, `SovereignHiveBootstrapService` gracefully opens and migrates the box into encrypted form without crashing startup.

### `REQ-P60-BOOT-03` — Headless `FLUTTER_TEST` Isolation Guarantee
- **Statement**: **IF** `Platform.environment.containsKey('FLUTTER_TEST')` is `true` **OR** `kIsWeb` is `true` (when `forceNativeInit` is `false`), **THEN** `SovereignHiveBootstrapService.ensureInitialized()` **SHALL** skip `Hive.initFlutter()` disk I/O and rely on deterministic L1 in-memory repository maps, **UNLESS** a test explicitly initializes Hive in a temporary directory and invokes `SovereignHiveBootstrapService.openAllBoxesForTesting()`.
- **Acceptance Criteria**:
  1. Existing widget and unit tests run with zero `MissingPluginException` or `path_provider` failures.
  2. Integration tests can call `await SovereignHiveBootstrapService.openAllBoxesForTesting(cipherKey: ...)` against a temporary directory to verify real `.hive` disk persistence across all 26 boxes.

### `REQ-P60-BOOT-04` — Onboarding State Persistence & Hydration
- **Statement**: **WHEN** the user updates birth year, cultural heritage, initial tracks, or calls `completeOnboarding()` on [`OnboardingNotifier`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/onboarding/presentation/providers/onboarding_providers.dart), the system **SHALL** persist the serialized `OnboardingState` (`hasCompletedOnboarding`, `birthYear`, `generationEra`, `culturalHeritage`, `initialTracks`) to `vhunambi_tokens` (`'onboarding_state_v1'`) and synchronize `hasCompletedOnboarding` with `CreatorDnaRepository`.
- **Acceptance Criteria**:
  1. `OnboardingNotifier` hydrates saved state on construction from `vhunambi_tokens` (or falls back to `CreatorDnaRepository.loadProfile()` if `profile.totalEventsLogged > 0` or `onboarding_completed == true`).
  2. Re-instantiating `OnboardingNotifier` after `completeOnboarding()` returns `state.hasCompletedOnboarding == true` and preserves `birthYear`, `generationEra`, and `culturalHeritage`.

### `REQ-P60-BOOT-05` — `SplashView` Returning-User Route Gate
- **Statement**: **WHEN** [`SplashView`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/onboarding/presentation/views/splash_view.dart) completes its splash timer, the system **SHALL** inspect the hydrated `onboardingProvider.hasCompletedOnboarding` state and navigate to `'/'` (`RootShell`) when `true`, or `'/onboarding'` when `false`.
- **Acceptance Criteria**:
  1. Returning users with `hasCompletedOnboarding == true` bypass `/onboarding` and land directly on `'/'`.

---

## 2. Remediating Broken Boxes, Leaks & Edge Sync (`REQ-P60-FIX`)

### `REQ-P60-FIX-01` — Wire `NotificationRepository` into `NotificationsNotifier` with $O(1)$ Keys
- **Statement**: **WHEN** [`NotificationsNotifier`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/notifications/presentation/providers/notifications_provider.dart) initializes or mutates notifications (`markAsRead`, `markAllAsRead`, `addNotification`, `deleteNotification`, `clearAll`), the system **SHALL** read and write through [`NotificationRepository`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/notifications/data/repositories/notification_repository.dart) using $O(1)$ per-notification keys (`notif_<id>`) in `notifications_v1`, seeding initial notifications only when the repository is empty.
- **Acceptance Criteria**:
  1. `NotificationRepository` automatically migrates any legacy monolithic `'notifications'` list entry into individual `notif_<id>` keys on first read and deletes the `'notifications'` key.
  2. Marking a notification as read or adding a new notification persists across `ProviderContainer` restarts.

### `REQ-P60-FIX-02` — Add L1 In-Memory Fallback to `SoundSignatureRepository`
- **Statement**: **WHEN** [`SoundSignatureRepository`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/studio/data/repositories/sound_signature_repository.dart) saves, retrieves, lists, or deletes a `SoundSignatureModel` while `vhunambi_sound_signatures_box` is closed (such as in headless tests), the system **SHALL** store and serve the `.vss` binary bytes from an internal `_inMemorySignatures` map in addition to writing to Hive when the box is open.
- **Acceptance Criteria**:
  1. `saveSignature`, `getSignature`, `getAllSignatures`, and `deleteSignature` succeed with 100% fidelity both when `vhunambi_sound_signatures_box` is open and when running in headless RAM mode.

### `REQ-P60-FIX-03` — Atomic `.vmf` File & Metadata Purge on `purgeTrackPermanently`
- **Statement**: **WHEN** `LibraryTracksNotifier.purgeTrackPermanently(String id)` ([`library_providers.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/library/presentation/providers/library_providers.dart#L270-L287)) is invoked, the system **SHALL** also invoke `OfflineStorageService.removeTrackMetadata(id)` (`vaultBoxKey = 'library_tracks'`) to delete any associated encrypted `.vmf` audio master/stem files on disk and remove the vault metadata entry.
- **Acceptance Criteria**:
  1. Purging a track removes it from `vhunambi_library_tracks_v1`, removes its metadata from `library_tracks`, and deletes its physical `.vmf` file if present.

### `REQ-P60-FIX-04` — Real Byte Accounting in `cacheStorageStatsProvider`
- **Statement**: **WHEN** [`cacheStorageStatsProvider`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/offline/presentation/providers/offline_providers.dart#L40-L56) computes storage statistics, the system **SHALL** combine real `.vmf` byte sizes from `OfflineStorageService.getTotalCachedSizeBytes()` with estimated/measured byte sizes of downloaded library tracks and Hive records rather than multiplying strictly by a hardcoded `8500000` constant when real metadata exists.
- **Acceptance Criteria**:
  1. If `OfflineStorageService` has recorded exact byte sizes for tracks, `cacheStorageStatsProvider` reflects those exact byte totals plus any Hive brain payload bytes.

### `REQ-P60-FIX-05` — Unify `EdgeSyncCoordinator` Base URL & Persist `lastServerSeq`
- **Statement**: **WHEN** [`EdgeSyncCoordinator`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/core/sync/edge_sync_coordinator.dart) initializes and completes delta pulls, the system **SHALL** resolve the default base URL to `http://localhost:3000` (`http://10.0.2.2:3000` on Android, overridable via `--dart-define=API_BASE_URL`), load persisted `lastServerSeq` and `lastSyncedAt` from `vhunambi_prefs` (`'edge_sync_last_seq'`, `'edge_sync_last_synced_at'`) on boot, and persist updated sequence numbers after every successful delta pull.
- **Acceptance Criteria**:
  1. `EdgeSyncCoordinator` defaults to port `3000` (matching Phase 59 `HttpExploreRepository`, `HttpLibrarySyncRepository`, `HttpPlaylistRepository`, `HttpWalletRepository`).
  2. Updating `lastServerSeq` persists to `vhunambi_prefs` and survives `EdgeSyncCoordinator` re-creation.

### `REQ-P60-FIX-06` — Register Delta Hydrators & `AppLifecycleListener` Resume Hook
- **Statement**: **WHEN** `edgeSyncCoordinatorProvider` is constructed and `VhunambiApp` is active, the system **SHALL** register `library_track` and `playlist` delta hydrators on `EdgeSyncCoordinator` and attach an `AppLifecycleListener` in `VhunambiApp` that invokes `edgeSyncCoordinatorProvider.notifier.onAppResumed()` when the app transitions to `AppLifecycleState.resumed`.
- **Acceptance Criteria**:
  1. Incoming `library_track` and `playlist` delta records from `GET /api/v1/sync/delta` automatically hydrate local Hive/repository state.
  2. Resuming the app triggers `onAppResumed()`.

---

## 3. Persisting the 10 Ignored App Domains (`REQ-P60-DOM`)

### `REQ-P60-DOM-01` — Creator Wallet, Ledger & Saved SA Bank Details (`WalletLedgerRepository`)
- **Statement**: **WHEN** [`CreatorWalletNotifier`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/wallet/presentation/providers/creator_wallet_provider.dart) mutates `userCoinsBalance`, `creatorEarnedZar`, `creatorReceivedCoins`, `transactions`, or saved South African bank payout details (`bankName`, `accountHolder`, `accountNumber`, `branchCode`), the system **SHALL** persist the snapshot and $O(1)$ transaction records (`tx_<id>`) in `vhunambi_wallet_ledger_box` via `WalletLedgerRepository` and hydrate from it on initialization.
- **Acceptance Criteria**:
  1. Top-ups (`topUpCoins`), tips (`sendCoinTip`), beat deductions (`deductForBeatPurchase`), payouts (`withdrawPayout`), and saved bank details survive app restarts offline.

### `REQ-P60-DOM-02` — Player Queue, Seek Position, 3D Hero Mode & Recently Played (`PlaybackSessionRepository`)
- **Statement**: **WHEN** [`PlayerNotifier`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/player/presentation/providers/player_provider.dart), `playerHeroModeProvider`, or [`RecentlyPlayedNotifier`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/library/presentation/providers/library_providers.dart#L126-L140) updates the active track, queue, seek position, shuffle/repeat mode, hero mode (`artwork`/`biome3d`/`lyrics`), or recently played track IDs, the system **SHALL** persist the session snapshot to `vhunambi_playback_session_box` via `PlaybackSessionRepository` and hydrate on cold start (defaulting `isPlaying: false` on cold boot so audio does not auto-blast unexpectedly).
- **Acceptance Criteria**:
  1. Playing a track, seeking to a timestamp, changing queue/repeat/shuffle, switching Hero mode, and recording `recentlyPlayedIdsProvider` all persist and restore across `ProviderContainer` restarts.

### `REQ-P60-DOM-03` — 4-Stem Mixer & Per-Track Mastering DSP Recipes (`StemDspRecipeRepository`)
- **Statement**: **WHEN** [`StemMixerNotifier`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/player/presentation/providers/stem_mixer_provider.dart) or [`MasteringSessionNotifier`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/studio/presentation/providers/mastering_session_provider.dart) modifies stem channel gain/pan/mute/solo, `MasterBusDsp` parameters, or `StemMasteringRecipe` settings for a track, the system **SHALL** persist the JSON state in `vhunambi_stem_dsp_recipes_box` (`stem_mix_<trackId>`, `master_recipe_<trackId>`) via `StemDspRecipeRepository` and restore it when that track is loaded.
- **Acceptance Criteria**:
  1. Adjusting stem faders, soloing log drums, toggling `MasterBusDsp`, or customizing a `StemMasteringRecipe` persists in `vhunambi_stem_dsp_recipes_box` and reloads automatically.

### `REQ-P60-DOM-04` — Heritage Crate Favorites, Custom 8-Pad MPC Kits & 3D Biome Leaves (`CrateMpcKitsRepository`)
- **Statement**: **WHEN** [`HeritageCrateNotifier`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/studio/presentation/providers/heritage_crate_provider.dart), `MpcSlicerNotifier`, or [`MyceliumBiomeGraphNotifier`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/studio/presentation/providers/mycelium_biome_provider.dart) toggles favorite loops, edits 8-pad MPC transient slice kits, or adds custom 3D Mycelium Biome harmony leaves / branch lock modes, the system **SHALL** persist those changes in `vhunambi_crate_mpc_kits_box` via `CrateMpcKitsRepository`.
- **Acceptance Criteria**:
  1. Starred Heritage Crate sample IDs, edited 8-pad MPC kits, and custom 3D Biome harmony leaves persist and hydrate on initialization.

### `REQ-P60-DOM-05` — Explore Discovery Bundle, Co-Signs, Likes & Search Cache (`ExploreCacheRepository`)
- **Statement**: **WHEN** [`ExploreTracksNotifier`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/explore/presentation/providers/explore_providers.dart), `coSignVotesProvider`, or `recentSearchesProvider` updates explore tracks, liked track IDs, A&R Co-Sign votes, or recent search queries, the system **SHALL** cache them in `vhunambi_tracks` (`AppConstants.tracksBoxKey`) via `ExploreCacheRepository` and hydrate immediately on offline startup.
- **Acceptance Criteria**:
  1. Explore tracks, liked states, A&R Co-Sign vote counts, and recent searches persist in `vhunambi_tracks` and survive offline restarts.

### `REQ-P60-DOM-06` — Social Kinetic Reels, Loves, Comments & Remix Lineage (`SocialReelsCacheRepository`)
- **Statement**: **WHEN** [`SocialFeedNotifier`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/social/presentation/providers/social_feed_provider.dart), [`ReelsCommentsNotifier`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/social/presentation/providers/reels_comments_provider.dart), or [`StemRemixNotifier`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/social/presentation/providers/stem_remix_provider.dart) mutates reel likes/loves, adds timestamped reel comments, or updates stem remix mute states, the system **SHALL** persist them in `vhunambi_social_reels_box` via `SocialReelsCacheRepository`.
- **Acceptance Criteria**:
  1. Multi-tap love counts, newly posted reel comments, and stem remix mute toggles persist in `vhunambi_social_reels_box` and restore on initialization.

### `REQ-P60-DOM-07` — Marketplace Beat Catalog & Exclusive Buyout Lock Cache (`MarketplaceCatalogCacheRepository`)
- **Statement**: **WHEN** [`MarketplaceBeatsNotifier`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/marketplace/presentation/providers/marketplace_providers.dart) or [`HttpMarketplaceRepository`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/marketplace/data/repositories/http_marketplace_repository.dart) loads catalog beats or marks a beat as `isExclusiveSold = true`, the system **SHALL** persist the catalog and exclusive buyout lock flags in `vhunambi_marketplace_catalog_box` via `MarketplaceCatalogCacheRepository`.
- **Acceptance Criteria**:
  1. Purchasing an Exclusive Stem License marks `isExclusiveSold = true` in `vhunambi_marketplace_catalog_box` and keeps the beat locked across cold restarts.

### `REQ-P60-DOM-08` — Content Studio Drafts, Owner Profile Write-Through & `SharedPreferences` Absorption
- **Statement**: **WHEN** [`ContentStudioNotifier`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/explore/presentation/providers/content_studio_provider.dart) edits lyric typography, shaders, trim windows, or word timestamps, **OR WHEN** [`ArtistProfileNotifier`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/profile/presentation/providers/profile_providers.dart) updates the `'me'` profile, **OR WHEN** `MiniPlayerController` / `GenerationRequestNotifier` saves preferences, the system **SHALL** persist Content Studio drafts in `vhunambi_studio_session`, write `'me'` profile edits through to `ProfileCache` (`vhunambi_profiles`, exempting `'me'` from LRU eviction), and mirror `MiniPlayerController` / `GenerationRequestNotifier` state into `vhunambi_prefs` / `vhunambi_studio_session`.
- **Acceptance Criteria**:
  1. Content Studio edits for a track reload when reopening `contentStudioProvider(trackId)`.
  2. Owner profile edits (`updateProfile`, `pinTrack`, `sendTip`, `toggleTipsEnabled`) persist to `ProfileCache` (`'me'`) and reload on startup.

---

## 4. Hive Scaling, Security & Atomic Upgrades (`REQ-P60-UPG`)

### `REQ-P60-UPG-01` — $O(1)$ Entity-Keyed Storage Refactor (Zero 500-Item Rewrites)
- **Statement**: **WHEN** `NotificationRepository`, `CreatorDnaRepository` (`logEvent`), `VocalIdentityNotifier`, or `MelodySketchpadNotifier` persists records, the system **SHALL** store each entity under its own individual Hive key (`notif_<id>`, `dna_evt_<000..499>` with `dna_evt_cursor`, `voice_<id>`, `sketch_<id>`) instead of re-serializing the entire collection under a single key, while transparently migrating any existing legacy single-key array on first load.
- **Acceptance Criteria**:
  1. Logging 1 Creator DNA event or saving 1 voice profile / melody sketch / notification performs an $O(1)$ single-record write.
  2. Legacy keys (`'notifications'`, `'behavior_log'`, `'cloned_voice_profiles_json'`, `'saved_melody_sketches_json'`) are migrated seamlessly without data loss.

### `REQ-P60-UPG-02` — AES-256 `HiveAesCipher` Encryption at Rest (`HiveAesVaultCipher`)
- **Statement**: **WHEN** `SovereignHiveBootstrapService` opens the 7 sensitive boxes (`vhunambi_tokens`, `vhunambi_creator_dna`, `vhunambi_voice_profiles_box`, `vhunambi_sound_signatures_box`, `vhunambi_license_certificates`, `vhunambi_sync_outbox_box`, `vhunambi_wallet_ledger_box`), the system **SHALL** supply an AES-256 `HiveAesCipher` derived deterministically via `HiveAesVaultCipher` (HKDF-SHA256 32-byte key), and wire `VaultEnvelopeCrypto` to use the same derived sovereign key.
- **Acceptance Criteria**:
  1. `HiveAesVaultCipher.derive256BitKey(deviceSalt: ...)` produces a deterministic 32-byte key (`length == 32`).
  2. All 7 sensitive boxes open and round-trip encrypted payloads using `HiveAesCipher`.

### `REQ-P60-UPG-03` — Cross-Box Atomic `CheckoutWriteAheadJournal`
- **Statement**: **WHEN** `BeatCheckoutNotifier.purchaseBeat()` executes a multi-box beat purchase across Wallet, License Certificates, Library Vault, Beat Repository, Marketplace Catalog, and Sync Outbox, the system **SHALL** first write a `PREPARED` entry to `CheckoutWriteAheadJournal` (`vhunambi_prefs` key `checkout_wal_<txId>`), mark it `COMMITTED` (and delete the WAL key) only after all 5 stores succeed, and automatically roll forward any incomplete `PREPARED` journal entries during `SovereignHiveBootstrapService` startup.
- **Acceptance Criteria**:
  1. Simulated crash mid-checkout leaves a `checkout_wal_<txId>` entry that `CheckoutWriteAheadJournal.recoverInterruptedTransactions()` reconciles idempotently on next boot without double-deducting coins.

### `REQ-P60-UPG-04` — Automatic Fragmentation Tracking & `HiveCompactionScheduler`
- **Statement**: **WHEN** mutations or deletions occur across Hive boxes, `HiveCompactionScheduler` **SHALL** track per-box mutation counts $M_{\text{mutations}}(b)$, compute fragmentation ratio $\Phi_{\text{frag}}(b) = \frac{M_{\text{mutations}}(b)}{N_{\text{live}}(b) + 1}$, and execute `await box.compact()` whenever $\Phi_{\text{frag}}(b) \ge 0.20$ and $M_{\text{mutations}}(b) \ge 25$, or when manually triggered via `compactAllBoxesNow()`.
- **Acceptance Criteria**:
  1. `HiveCompactionScheduler` tracks mutation counters, calculates fragmentation ratios, compacts open boxes on threshold or manual command, and resets mutation counters to `0`.

---

## 5. Sovereign Hive Brain Telemetry HUD (`REQ-P60-HUD`)

### `REQ-P60-HUD-01` — `HiveBrainTelemetryCard` in `ProfileSettingsDrawer`
- **Statement**: **WHEN** the user opens [`ProfileSettingsDrawer`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/profile/presentation/widgets/profile_settings_drawer.dart), the system **SHALL** render `HiveBrainTelemetryCard` (`Key('hive_brain_status_card')`) displaying active box count (`26 / 26`), AES-256 verification status (`Key('hive_encryption_verified_pill')`), tier breakdown badge (`Key('hive_box_metrics_badge')`), persisted entity count, `EdgeSyncCoordinator` sequence cursor (`seq #<N>`), fragmentation ratio, and action buttons for manual compaction (`Key('hive_compact_now_btn')`) and delta sync (`Key('hive_sync_now_btn')`).
- **Acceptance Criteria**:
  1. `find.byKey(const Key('hive_brain_status_card'))`, `find.byKey(const Key('hive_encryption_verified_pill'))`, `find.byKey(const Key('hive_box_metrics_badge'))`, and `find.byKey(const Key('hive_compact_now_btn'))` are present in `ProfileSettingsDrawer`.
  2. Tapping `Key('hive_compact_now_btn')` invokes `HiveCompactionScheduler.compactAllBoxesNow()` and refreshes telemetry metrics.

---

## 6. Non-Functional Requirements (`REQ-P60-NFR`)

- **`REQ-P60-NFR-01` (Zero Analyzer Errors)**: All modified and newly created Dart files **SHALL** pass `dart analyze` / `flutter analyze` with 0 errors and 0 warnings.
- **`REQ-P60-NFR-02` (Strict Design Token & Icon Compliance)**: All UI widgets **SHALL** use `package:phosphor_icons/phosphor_icons.dart`, valid `AppColors` tokens, and valid `AppTypography` styles (`titleLarge`, `titleMedium`, `titleSmall`, `bodyLarge`, `bodyMedium`, `bodySmall`, `caption`, `badge`), with zero raw emojis in Dart source files (`STD-UIUX-001`).

---

## 7. Complete Requirement-to-Test Traceability Matrix

| Requirement ID | Primary Implementation File(s) | Verification Test File | Gate ID |
| :--- | :--- | :--- | :---: |
| `REQ-P60-BOOT-01..03` | `lib/core/constants/app_constants.dart`, `lib/core/storage/sovereign_hive_bootstrap_service.dart`, `lib/main.dart` | `test/features/storage/sovereign_hive_bootstrap_test.dart` | `G-60-01` |
| `REQ-P60-BOOT-04..05` | `lib/features/onboarding/presentation/providers/onboarding_providers.dart`, `lib/features/onboarding/presentation/views/splash_view.dart` | `test/features/storage/sovereign_hive_bootstrap_test.dart` | `G-60-02` |
| `REQ-P60-FIX-01..02` | `lib/features/notifications/data/repositories/notification_repository.dart`, `lib/features/notifications/presentation/providers/notifications_provider.dart`, `lib/features/studio/data/repositories/sound_signature_repository.dart` | `test/features/storage/hive_fixes_and_upgrades_test.dart` | `G-60-03` |
| `REQ-P60-FIX-03..04` | `lib/features/library/presentation/providers/library_providers.dart`, `lib/features/offline/presentation/providers/offline_providers.dart` | `test/features/storage/hive_fixes_and_upgrades_test.dart` | `G-60-05` |
| `REQ-P60-FIX-05..06` | `lib/core/sync/edge_sync_coordinator.dart`, `lib/app/app.dart` | `test/features/storage/hive_fixes_and_upgrades_test.dart` | `G-60-06` |
| `REQ-P60-DOM-01..08` | `lib/core/storage/sovereign_domain_repositories.dart`, `creator_wallet_provider.dart`, `player_provider.dart`, `stem_mixer_provider.dart`, `mastering_session_provider.dart`, `heritage_crate_provider.dart`, `explore_providers.dart`, `social_feed_provider.dart`, `marketplace_providers.dart`, `content_studio_provider.dart`, `profile_providers.dart` | `test/features/storage/ignored_domains_persistence_test.dart` | `G-60-04` |
| `REQ-P60-UPG-01..04` | `lib/core/storage/hive_aes_vault_cipher.dart`, `lib/core/storage/checkout_write_ahead_journal.dart`, `lib/core/storage/hive_compaction_scheduler.dart`, `creator_dna_repository.dart`, `vocal_identity_provider.dart`, `melody_sketchpad_provider.dart` | `test/features/storage/hive_fixes_and_upgrades_test.dart` | `G-60-07` |
| `REQ-P60-HUD-01` | `lib/features/profile/presentation/widgets/hive_brain_telemetry_card.dart`, `lib/features/profile/presentation/widgets/profile_settings_drawer.dart` | `test/features/storage/hive_brain_telemetry_hud_test.dart` | `G-60-08` |

