# Phase 8 Cline Handoff & Dual-Agent Protocol: Offline Audio Persistence & Hive Cache

> **Target Package:** `apps/vhunambi_client`  
> **Status:** Active Execution  
> **Pre-Flight Baseline:** `dart analyze .` = 0 issues | `flutter test` = 160/160 passing (100%)  
> **Specification Reference:** [`docs/phases/phase_08_offline_cache/`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_08_offline_cache/)  

---

## 1. Objective & Scope

Implement the complete local storage, Hive caching, background download manager, and storage quota subsystem for Vhunambi:
1. `lib/features/offline/domain/models/offline_models.dart`: Models for `DownloadStatus`, `DownloadTask`, `CacheStorageStats`, `AudioDownloadQuality`, and `OfflinePreferenceState`.
2. `lib/features/offline/data/services/offline_storage_service.dart`: Hive-backed storage service for vault track metadata and binary audio locations.
3. `lib/features/offline/data/services/audio_download_service.dart`: Streaming audio downloader with chunked progress emission.
4. `lib/features/offline/presentation/providers/offline_providers.dart`: Riverpod `DownloadManagerNotifier`, `downloadManagerProvider`, `cacheStorageStatsProvider`, and `offlinePreferencesProvider`.
5. `lib/features/offline/presentation/widgets/vault_storage_modal.dart` & `offline_indicator_badge.dart`: Vault storage quota dialog and offline pin badges.
6. Integration into `TrackActionsSheet`, `LibraryTrackTile`, `LibraryTrackGridCard`, `LibraryAppBar`, and `ExpandedCockpitModal`.
7. Unit and widget test suite bringing passing test count to 180+.

---

## 2. Codebase Invariants & Non-Negotiables

1. **Design Tokens:** Always use `AppColors`, `AppGradients`, `AppTypography`, `AppRadius`, and `AppSpacing` from `package:vhunambi_client/core/theme/`. Never use raw hex codes or ad-hoc borders. Note: `AppRadius` and `AppSpacing` are in `app_dimensions.dart`.
2. **SDK Enum Safety:** Never create an enum named `RepeatMode` (use `AudioRepeatMode`).
3. **Headless / Test Safety:** `OfflineStorageService` and `AudioDownloadService` must operate safely in headless test environments (memory-backed fallback or mockable interface) so tests never fail due to missing Flutter plugins.
4. **Zero Regressions:** All 160 baseline tests must continue to pass without error.
