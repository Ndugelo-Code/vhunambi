# Phase 8 Tasks: Offline Audio Persistence & Hive Cache

> **Target Package:** `apps/vhunambi_client`  
> **Parent Blueprint:** [`docs/foundation_blueprints/04_LIBRARY_VAULT_SPEC.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/foundation_blueprints/04_LIBRARY_VAULT_SPEC.md) §5  
> **Requirements Reference:** [`docs/phases/phase_08_offline_cache/requirements.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_08_offline_cache/requirements.md)  
> **Design Reference:** [`docs/phases/phase_08_offline_cache/design.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_08_offline_cache/design.md)  

---

## Pre-Flight Check

- [x] Run `dart analyze .` in `apps/vhunambi_client` $\rightarrow$ 0 issues found.
- [x] Run `flutter test` $\rightarrow$ 160/160 tests passing (100%).
- [x] Verify dependencies: `hive_flutter`, `path_provider`, and `dio` present in `pubspec.yaml`.

---

## Implementation Tasks

### T8.1: Domain Layer Models
- [x] Create `lib/features/offline/domain/models/offline_models.dart`:
  - `DownloadStatus` (`idle`, `queued`, `downloading`, `paused`, `completed`, `failed`).
  - `AudioDownloadQuality` (`mp3HighQuality`, `wavLossless`).
  - `DownloadTask` immutable model with copyWith and getters.
  - `CacheStorageStats` with byte formatting and quota calculation.
  - `OfflinePreferenceState` with settings fields.

### T8.2: Service Layer & Persistence Engine
- [x] Create `lib/features/offline/data/services/offline_storage_service.dart`:
  - `IOfflineStorageService` interface + `OfflineStorageService` implementation.
  - Hive boxes initialization (`vaultBoxKey` and `preferencesBoxKey`).
  - Safe fallback for unit test / headless environments.
  - Save, get, list, and clear track metadata and file paths.
- [x] Create `lib/features/offline/data/services/audio_download_service.dart`:
  - `IAudioDownloadService` interface + `AudioDownloadService` implementation.
  - Chunked streaming download with progress callbacks.
  - Test / mock download simulator with deterministic progress ticks.

### T8.3: Riverpod State Notifiers & Providers
- [x] Create `lib/features/offline/presentation/providers/offline_providers.dart`:
  - `offlineStorageServiceProvider` and `audioDownloadServiceProvider`.
  - `DownloadManagerNotifier` & `downloadManagerProvider`:
    - `downloadTrack(LibraryTrack track)`
    - `cancelDownload(String trackId)`
    - `retryDownload(String trackId)`
    - `removeOfflineTrack(String trackId)`
    - `clearAllOfflineTracks()`
    - Synchronizes directly with `libraryTracksProvider`.
  - `cacheStorageStatsProvider`: Computes storage stats from cached vault tracks.
  - `offlinePreferencesProvider` / `OfflinePreferencesNotifier`.

### T8.4: Offline UI Widgets & Storage Modal
- [x] Create `lib/features/offline/presentation/widgets/vault_storage_modal.dart`:
  - Progress bar showing quota consumed.
  - Total cached count and size in MB.
  - Scrollable list of cached items with individual sizes.
  - Clear All Downloads button with confirmation.
- [x] Create `lib/features/offline/presentation/widgets/offline_indicator_badge.dart`:
  - Pill badge with `Icons.offline_pin_rounded` and subtle brand styling.

### T8.5: Vault & Player UI Integration
- [x] Update `lib/features/library/presentation/widgets/track_actions_sheet.dart`:
  - Dynamically display Download Offline, live downloading progress, or Remove Offline Download.
- [x] Update `lib/features/library/presentation/widgets/library_track_tile.dart` and `library_track_grid_card.dart`:
  - Show download progress bar when `downloading`, offline pin badge when `cachedLocally`.
- [x] Update `lib/features/library/presentation/widgets/library_app_bar.dart`:
  - Add Storage Quota action button (`Icons.pie_chart_outline_rounded` or `Icons.storage_rounded`) to trigger `VaultStorageModal`.
- [x] Update `lib/features/track/presentation/views/track_detail_view.dart`:
  - Connect download dialog to `downloadManagerProvider`.
- [x] Update `lib/features/player/presentation/widgets/expanded_cockpit_modal.dart`:
  - Display offline playback badge when current track is playing from local cache.

### T8.6: Automated Testing Suite
- [x] Create `test/features/offline/offline_storage_service_test.dart`:
  - Test metadata saving, retrieval, listing, removal, and size computation.
- [x] Create `test/features/offline/download_manager_test.dart`:
  - Test queuing, progress emission, completion, cancellation, and error handling.
- [x] Create `test/features/offline/vault_storage_modal_test.dart`:
  - Test modal rendering, cached tracks list, and clear all trigger.

### T8.7: Verification Gates & Handoff Sign-off
- [x] Run `dart analyze .` $\rightarrow$ 0 issues found.
- [x] Run `flutter test` $\rightarrow$ 100% passing tests (207/207 tests).
- [x] Update `docs/AGENT_HANDOFF_BIBLE.md` and `README.md`.
- [x] Create `walkthrough.md` report.
