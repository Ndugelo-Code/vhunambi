# Phase 8 Resume Handoff: Offline Audio Persistence & Hive Cache

> **Document Purpose:** Seamless resume guide for any agent (Antigravity / Cline / Cursor) picking up Phase 8 where it was left. Read this first — it captures exact completion status, what is done, what remains, and the exact next actions to take.
>
> **Last Updated:** 2026-09-24T04:50:00+02:00
> **Written By:** Antigravity (Lead Architect) — End-of-Session Sign-Off
> **Repository Root:** `c:\Users\Ndugelo\VHUNAMBI\monorepo\`
> **Client Package:** `apps/vhunambi_client/`

---

## 1. Current Repository Health (Verified at Sign-Off)

```powershell
cd c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_client

dart analyze .
# No issues found! (0 issues)

flutter test
# 160/160 baseline tests passing (100%)
# NOTE: Phase 8 tests (T8.6) are NOT yet written — target is 180+ tests
```

> **IMPORTANT:** The 160 baseline count is from Phase 7 completion. Phase 8 implementation files are in place but their dedicated tests (T8.6) have not yet been created.

---

## 2. Phase 8 Objective & Scope

Implement offline audio playback for the Asset Vault (`/library`):
- Encrypted local disk storage for downloaded MP3/WAV tracks
- Hive-backed metadata cache for the vault
- Download progress manager (FSM: `idle -> queued -> downloading -> completed | failed | paused`)
- Storage quota subsystem with `VaultStorageModal`
- Full UI integration across Library, Track Detail, and Player features

**Specification docs** (read these):
- `docs/phases/phase_08_offline_cache/blueprint.md`
- `docs/phases/phase_08_offline_cache/requirements.md`
- `docs/phases/phase_08_offline_cache/design.md`
- `docs/phases/phase_08_offline_cache/tasks.md`

---

## 3. Implementation Status by Task

### T8.1 — Domain Layer Models — COMPLETE
**File:** `lib/features/offline/domain/models/offline_models.dart` (249 lines)

All required types implemented and `@immutable`:
| Type | Status | Notes |
|---|---|---|
| `DownloadStatus` enum | Done | `idle, queued, downloading, paused, completed, failed` |
| `AudioDownloadQuality` enum | Done | `mp3HighQuality (320kbps), wavLossless (24-bit WAV)` |
| `AudioDownloadQualityExtension` | Done | `.label` and `.fileExtension` getters |
| `DownloadTask` | Done | Immutable with `copyWith`, `==`, `hashCode`, progress/byte getters |
| `CacheStorageStats` | Done | `quotaUsagePercentage`, `formattedBytesUsed`, `formatBytes()` static helper |
| `OfflinePreferenceState` | Done | `isOfflineModeForced`, `downloadQuality`, `wifiOnlyDownload`, `storageLimitBytes` |

---

### T8.2 — Service Layer & Persistence Engine — COMPLETE
**Files:**
- `lib/features/offline/data/services/offline_storage_service.dart` (7189 bytes)
- `lib/features/offline/data/services/audio_download_service.dart` (3957 bytes)

**`OfflineStorageService` implements `IOfflineStorageService`:**
- `init()` — Opens Hive boxes with safe in-memory fallback for headless test environments
- `resolveVaultAudioDirectory()` — Returns `path_provider` app documents dir with test fallback
- `saveTrackMetadata(track, localPath, fileSizeBytes)` — Persists to Hive `vaultBoxKey`
- `getTrackMetadata(trackId)` — Returns cached `LibraryTrack?`
- `listAllCachedTracks()` — Returns all persisted tracks from Hive
- `removeTrackMetadata(trackId)` — Evicts from Hive
- `clearAllMetadata()` — Clears entire vault Hive box
- `_inMemoryVault` — In-memory Map fallback activated when Hive unavailable

**`AudioDownloadService` implements `IAudioDownloadService`:**
- `downloadFile(trackId, remoteUrl, destinationPath, onProgress)` — Chunked Dio streaming with progress callbacks
- `cancelDownload(trackId)` — Cancels active Dio download by CancelToken
- `simulateDownloads` flag — Deterministic simulated download ticker (10 ticks x 10% progress) for test reliability

---

### T8.3 — Riverpod State Notifiers & Providers — COMPLETE
**File:** `lib/features/offline/presentation/providers/offline_providers.dart` (245 lines)

| Provider | Type | Status |
|---|---|---|
| `offlineStorageServiceProvider` | `Provider<IOfflineStorageService>` | Done |
| `audioDownloadServiceProvider` | `Provider<IAudioDownloadService>` | Done (simulateDownloads: true) |
| `downloadManagerProvider` | `StateNotifierProvider<DownloadManagerNotifier, Map<String, DownloadTask>>` | Done |
| `cacheStorageStatsProvider` | `Provider<CacheStorageStats>` | Done |
| `offlinePreferencesProvider` | `StateNotifierProvider<OfflinePreferencesNotifier, OfflinePreferenceState>` | Done |

**`DownloadManagerNotifier` actions:**
- `downloadTrack(LibraryTrack, {quality})` — Full FSM: queued -> downloading -> completed|failed; syncs with `libraryTracksProvider` via `setSyncStatus` and `setTrackOfflinePath`
- `cancelDownload(trackId)` — Cancels Dio and resets sync status to `cloudOnly`
- `retryDownload(LibraryTrack)` — Delegates to `downloadTrack`
- `removeOfflineTrack(trackId)` — Evicts metadata and clears offline path from vault
- `clearAllOfflineTracks()` — Full purge; clears all `cachedLocally` vault tracks

---

### T8.4 — Offline UI Widgets & Storage Modal — COMPLETE
**Files:**
- `lib/features/offline/presentation/widgets/vault_storage_modal.dart` (15246 bytes)
- `lib/features/offline/presentation/widgets/offline_indicator_badge.dart` (2168 bytes)

**`VaultStorageModal`:** Full-featured bottom sheet:
- Animated quota progress bar (`quotaUsagePercentage`)
- Summary chip: cached track count + total size in MB
- Per-track scrollable list with individual sizes
- "Clear All Downloads" button with confirmation dialog
- Styled with `AppColors`, `AppGradients`, `AppTypography`, `AppRadius`, `AppSpacing`

**`OfflineIndicatorBadge`:** Pill badge:
- `Icons.offline_pin_rounded` in `AppColors.brandPrimary`
- Subtle brand amber glow behind icon

---

### T8.5 — Vault & Player UI Integration — COMPLETE (with 1 caveat)

| File | Change | Status |
|---|---|---|
| `lib/features/library/presentation/widgets/track_actions_sheet.dart` | Dynamic Download Offline / progress / Remove Offline Download via `downloadManagerProvider` | Done |
| `lib/features/library/presentation/widgets/library_badges.dart` | `SyncStatusBadge` updated to reflect `downloading` state | Done |
| `lib/features/library/presentation/widgets/library_app_bar.dart` | Storage quota action button (`Icons.storage_rounded`) triggers `VaultStorageModal` | Done |
| `lib/features/track/presentation/views/track_detail_view.dart` | Download dialog connected to `downloadManagerProvider` | Done |
| `lib/features/player/presentation/widgets/expanded_cockpit_modal.dart` | `OfflineIndicatorBadge` displayed when current track is local | Done |
| `lib/features/library/presentation/widgets/library_track_tile.dart` | Download progress bar + offline pin badge | VERIFY |
| `lib/features/library/presentation/widgets/library_track_grid_card.dart` | Download progress bar + offline pin badge | VERIFY |

> **VERIFY items:** `library_track_tile.dart` and `library_track_grid_card.dart` inline badge/progress integration (tasks.md line 64-65) should be verified and completed if missing.

---

### T8.6 — Automated Testing Suite — NOT YET STARTED

This is the **primary remaining work** for Phase 8.

**Tests to create:**
```
test/features/offline/offline_storage_service_test.dart   (target: 7+ tests)
test/features/offline/download_manager_test.dart          (target: 8+ tests)
test/features/offline/vault_storage_modal_test.dart       (target: 5+ tests)
```

**Target total test count after Phase 8:** 180+ (20+ new on top of 160 baseline)

**Test implementation guidance:**
- `OfflineStorageService` tests: call `init()` without Hive plugin — the service auto-detects headless and uses `_inMemoryVault` in-memory fallback. No plugin mocking required.
- `DownloadManagerNotifier` tests: use `ProviderContainer` with `audioDownloadServiceProvider.overrideWithValue(AudioDownloadService(simulateDownloads: true))`
- `VaultStorageModal` widget tests: pump with `ProviderScope` overriding `cacheStorageStatsProvider` and `downloadManagerProvider` with mock data

---

### T8.7 — Verification Gates & Sign-Off — NOT YET COMPLETE

- [ ] `flutter test` -> 180+ tests passing
- [ ] Update `docs/AGENT_HANDOFF_BIBLE.md` — add Phase 8 to phase roster and delivery record section
- [ ] Create `docs/phases/phase_08_offline_cache/walkthrough.md` — final delivery report

---

## 4. Exact Next Actions (in order)

```
STEP 1: Pre-flight verification
  dart analyze .        must be 0 issues
  flutter test          must be 160/160

STEP 2: Verify T8.5 tile integration
  Open: lib/features/library/presentation/widgets/library_track_tile.dart
  Open: lib/features/library/presentation/widgets/library_track_grid_card.dart
  Add: download progress bar when syncStatus == TrackSyncStatus.downloading
  Add: offline pin badge when syncStatus == TrackSyncStatus.cachedLocally

STEP 3: Create test/features/offline/ test suite (T8.6)
  Create: offline_storage_service_test.dart  (7+ tests)
  Create: download_manager_test.dart         (8+ tests)
  Create: vault_storage_modal_test.dart      (5+ tests)

STEP 4: Final verification gates (T8.7)
  dart analyze .        0 issues
  flutter test          180+ passing

STEP 5: Update AGENT_HANDOFF_BIBLE.md
  Mark Phase 8 as COMPLETE
  Update health status to 180+/180+ tests
  Add Phase 8 delivery section (modelled on Phase 7 section at lines 165-177)

STEP 6: Create docs/phases/phase_08_offline_cache/walkthrough.md
  Report: all REQ-OFF-XX requirements to implementation mapping
  Report: test count breakdown

STEP 7: Advance to Phase 9 planning (if user approves)
  Phase 9: Production Audio Engine Hardware Bridge & Platform Services
  Focus: Native OS lockscreen controls, notification transport, background audio session
```

---

## 5. Codebase Invariants (NEVER BREAK THESE)

1. **Zero raw hex values** — Always use `AppColors.*`, `AppGradients.*`, `AppTypography.*`, `AppRadius.*`, `AppSpacing.*`
   - Token files: `lib/core/theme/app_colors.dart`, `app_gradients.dart`, `app_typography.dart`, `app_dimensions.dart` (AppRadius + AppSpacing), `app_theme.dart`
2. **`AudioRepeatMode` not `RepeatMode`** — Flutter 3.44 exports a conflicting `RepeatMode` enum
3. **Headless test safety** — `OfflineStorageService.init()` must never throw in headless Flutter test environments; it uses `_inMemoryVault` automatically
4. **Zero regressions** — All 160 baseline tests must continue to pass
5. **Immutable state** — State models use `copyWith`; state is never mutated directly inside widget builds
6. **Name is `vhunambi`** — With an 'i'. Never `vhunamba`.

---

## 6. Key File Map

```
apps/vhunambi_client/
  lib/features/offline/
    domain/models/offline_models.dart           T8.1 DONE (249 lines)
    data/services/
      offline_storage_service.dart              T8.2 DONE (7189 bytes)
      audio_download_service.dart               T8.2 DONE (3957 bytes)
    presentation/
      providers/offline_providers.dart          T8.3 DONE (245 lines)
      widgets/
        vault_storage_modal.dart                T8.4 DONE (15246 bytes)
        offline_indicator_badge.dart            T8.4 DONE (2168 bytes)
  lib/features/library/presentation/widgets/
    track_actions_sheet.dart                    T8.5 DONE
    library_badges.dart                         T8.5 DONE
    library_app_bar.dart                        T8.5 DONE
    library_track_tile.dart                     T8.5 VERIFY
    library_track_grid_card.dart                T8.5 VERIFY
  lib/features/track/presentation/views/
    track_detail_view.dart                      T8.5 DONE
  lib/features/player/presentation/widgets/
    expanded_cockpit_modal.dart                 T8.5 DONE
  test/features/offline/
    offline_storage_service_test.dart           T8.6 TO CREATE
    download_manager_test.dart                  T8.6 TO CREATE
    vault_storage_modal_test.dart               T8.6 TO CREATE

docs/phases/phase_08_offline_cache/
  blueprint.md      (8964 bytes) DONE
  requirements.md   (5247 bytes) DONE
  design.md         (5884 bytes) DONE
  tasks.md          (4880 bytes) DONE
  walkthrough.md                 TO CREATE (T8.7)
```

---

## 7. Phase 9 Preview (After Phase 8 Sign-Off)

**Phase 9: Production Audio Engine Hardware Bridge & Platform Services**
- Native OS lockscreen playback controls (Android `MediaSession`, iOS `MPNowPlayingInfoCenter`, macOS `MPRemoteCommandCenter`)
- Notification transport bar integration via `audio_service` package
- Background audio session management via `audio_session` package
- The `audio_service` and `audio_session` packages are **already in `pubspec.yaml`** from Phase 1
- Foundation Blueprint: `docs/foundation_blueprints/07_AUDIO_TRANSPORT_AND_PIPELINE_MODALS_SPEC.md`

---

## 8. Cline Resume Prompt for T8.6

Copy and paste this directly to Cline to complete Phase 8:

```
You are resuming Phase 8 of the Vhunambi client (apps/vhunambi_client).
Phase 8 implementation (T8.1-T8.5) is COMPLETE. Your only job is T8.6:
create the automated test suite for the offline module.

PRE-FLIGHT: Run `dart analyze .` (must be 0 issues) and `flutter test` (must be 160 passing).

CREATE these 3 test files:

1. test/features/offline/offline_storage_service_test.dart
   - Test: init() in headless mode uses in-memory fallback (no throws)
   - Test: saveTrackMetadata stores and retrieves metadata
   - Test: listAllCachedTracks returns all saved tracks
   - Test: removeTrackMetadata evicts a single entry
   - Test: clearAllMetadata clears the vault
   - Test: CacheStorageStats.formatBytes formats bytes/KB/MB/GB correctly
   - Test: OfflinePreferenceState copyWith preserves unchanged fields

2. test/features/offline/download_manager_test.dart
   Use ProviderContainer with audioDownloadServiceProvider.overrideWithValue(
     AudioDownloadService(simulateDownloads: true)
   )
   - Test: downloadTrack transitions status from queued to completed
   - Test: downloadTrack syncs libraryTracksProvider to cachedLocally
   - Test: cancelDownload resets syncStatus to cloudOnly
   - Test: removeOfflineTrack removes task and clears vault path
   - Test: clearAllOfflineTracks purges all cachedLocally tracks
   - Test: duplicate downloadTrack call is idempotent (no double-queue)
   - Test: DownloadTask.formattedProgressPercentage returns "75%" at progress 0.75
   - Test: DownloadTask.isActive is true when downloading or queued

3. test/features/offline/vault_storage_modal_test.dart
   Pump VaultStorageModal inside ProviderScope with mocked providers.
   - Test: renders "Vault Storage" heading
   - Test: displays quota progress bar when cachedTrackCount > 0
   - Test: shows cached track list items
   - Test: "Clear All Downloads" button is present
   - Test: empty state text when no cached tracks

CODEBASE INVARIANTS (NEVER BREAK):
- Zero raw hex values. Always AppColors.*, AppGradients.*, AppRadius.*, AppSpacing.*, AppTypography.*
- Use AudioRepeatMode not RepeatMode (Flutter 3.44 enum collision)
- OfflineStorageService is headless-safe (auto in-memory fallback)
- All 160 baseline tests must keep passing (zero regressions)

VERIFICATION GATES:
  dart analyze .    0 issues
  flutter test      180+ tests passing (100%)

Report completion with the exact test count breakdown.
```
