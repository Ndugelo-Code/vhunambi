# Phase 8 Execution Tasks: Sovereign Offline Audio Vault & Encrypted Caching Pipeline

```
══════════════════════════════════════════════════════════════════════════════════════════════════════════════
  VHUNAMBI ENGINEERING TASK ROADMAP & VERIFICATION CHECKLIST
  PHASE 08: SOVEREIGN OFFLINE AUDIO VAULT & RESILIENT CHUNK STREAMING PIPELINE
  STANDARD: ALL-GEMINI HARDENED SPECIFICATION (STD-SPEC-001 / STD-UIUX-001)
  TARGET PACKAGE: apps/vhunambi_client
  PARENT BLUEPRINT: docs/phases/phase_08_offline_cache/blueprint.md
══════════════════════════════════════════════════════════════════════════════════════════════════════════════
```

---

## 1. Master Milestone Roadmap & Dependency Graph

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        PHASE 08 MILESTONE ROADMAP & DEPENDENCY GRAPH                   │
├────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                        │
│  [M8.1: Pure Dart Domain & AES-CTR Crypto Engine]                                      │
│  └── offline_models.dart, vault_envelope_crypto.dart                                   │
│            │                                                                           │
│            ▼                                                                           │
│  [M8.2: Resilient Dio Chunk Streaming & Storage Service]                               │
│  └── audio_download_service.dart, offline_storage_service.dart                         │
│            │                                                                           │
│            ▼                                                                           │
│  [M8.3: Riverpod Download Manager & Preference Notifiers]                              │
│  └── offline_providers.dart (concurrency queue, speed/ETA telemetry, auto-retry)       │
│            │                                                                           │
│            ▼                                                                           │
│  [M8.4: Playback Engine & Custom Encrypted Stream Resolver]                            │
│  └── audio_source_resolver.dart (EncryptedVmfStreamSource, forced offline guard)        │
│            │                                                                           │
│            ▼                                                                           │
│  [M8.5: UI & Touch Ergonomics Integration]                                             │
│  └── vault_storage_modal.dart, track_actions_sheet.dart, library_view.dart             │
│            │                                                                           │
│            ▼                                                                           │
│  [M8.6: Automated Regression Suite & Physical Device Verification]                     │
│  └── phase08_sovereign_offline_vault_test.dart (100% pass, dart analyze 0 issues)      │
│                                                                                        │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

| Milestone | Focus Area | Target File(s) | Dependencies |
| :---: | :--- | :--- | :---: |
| **M8.1** | Domain Models & AES-128-CTR Crypto | `offline_models.dart`, `vault_envelope_crypto.dart` | None |
| **M8.2** | Resilient Chunk Streaming & Storage | `audio_download_service.dart`, `offline_storage_service.dart` | M8.1 |
| **M8.3** | Riverpod Download Manager & Queue | `offline_providers.dart` | M8.2 |
| **M8.4** | Decrypted Playback Stream Source | `audio_source_resolver.dart` | M8.1, M8.3 |
| **M8.5** | UI Storage Modals & Vault Badges | `vault_storage_modal.dart`, `track_actions_sheet.dart`, `library_view.dart` | M8.3, M8.4 |
| **M8.6** | Test Suite & Device Verification | `phase08_sovereign_offline_vault_test.dart` | M8.1–M8.5 |

---

## 2. Granular Task Checklist

### Milestone M8.1: Pure Dart Domain & AES-128-CTR Crypto Engine

- [x] **Task 8.1.1 (`REQ-P08-STREAM-04`, `REQ-P08-QUOTA-01`):** In `apps/vhunambi_client/lib/features/offline/domain/models/offline_models.dart`, implement immutable domain models:
  - `DownloadTaskStatus` (`idle`, `queued`, `downloading`, `paused`, `retrying`, `verifying`, `completed`, `failed`).
  - `DownloadTask` with fields `trackId`, `title`, `creatorName`, `remoteAudioUrl`, `localFilePath`, `status`, `receivedBytes`, `totalBytes`, `progress`, `bytesPerSecond`, `etaSeconds`, `retryCount`, `formattedSpeed`, `formattedEta`, and `copyWith`.
  - `CacheStorageStats` with `totalBytesUsed`, `cachedTrackCount`, `storageLimitBytes`, `quotaUsagePercentage`, `formattedBytesUsed`, and `formattedStorageLimit`.
  - `OfflinePreferenceState` with `isOfflineModeForced`, `downloadWifiOnly`, `storageLimitBytes`, and `copyWith`.
  - **Acceptance Criteria**: All models are `@immutable`, pure Dart (zero Flutter imports), and verified by value equality.

- [x] **Task 8.1.2 (`REQ-P08-CRYPTO-01`, `REQ-P08-CRYPTO-02`):** Create `apps/vhunambi_client/lib/features/offline/domain/services/vault_envelope_crypto.dart`:
  - Implement `VaultEnvelopeCrypto` with magic header `0x56, 0x48, 0x55, 0x4E` (`"VHUN"`), 2-byte version `0x0001`, 16-byte random IV, and 8-byte big-endian payload length.
  - Implement `encryptToEnvelope(Uint8List rawAudio)` and `decryptFromEnvelope(Uint8List envelope)` using AES-128-CTR stream cipher with SHA-256 HMAC keystream derivation.
  - **Acceptance Criteria**: Arbitrary byte slices can be encrypted and decrypted symmetrically with 100% byte fidelity.

---

### Milestone M8.2: Resilient Chunk Streaming & Storage Service

- [x] **Task 8.2.1 (`REQ-P08-STREAM-01..03`):** In `apps/vhunambi_client/lib/features/offline/data/services/audio_download_service.dart`, implement `ResilientAudioDownloadService`:
  - Default `simulateDownloads: false` in production builds.
  - Stream HTTP response body via `Dio` in $\le 64\text{ KB}$ chunks, appending to swap file `<destinationPath>.vswap`.
  - Attach `Range: bytes=<existing>-` header when resuming an interrupted transfer.
  - Compute exponential backoff retries (up to 3 attempts: 2s, 4s, 8s) upon transient network drops (`DioExceptionType.connectionTimeout`, `receiveTimeout`).
  - Encrypt raw swap bytes into `.vmf` envelope and commit atomically to final destination path upon 100% completion.
  - **Acceptance Criteria**: Cancelling a download cleanly deletes `.vswap`; completion produces a valid `.vmf` file.

- [x] **Task 8.2.2 (`REQ-P08-CRYPTO-03`, `REQ-P08-QUOTA-03`):** In `apps/vhunambi_client/lib/features/offline/data/services/offline_storage_service.dart`, implement `SovereignOfflineStorageService`:
  - Open and manage Hive boxes `library_tracks` and `vhunambi_prefs` with in-memory fallback for test environments.
  - Implement `saveTrackMetadata`, `getTrackMetadata`, `getAllCachedMetadata`, `removeTrackMetadata`, `clearAllMetadata`, and `isTrackCachedLocally`.
  - Resolve platform-specific documents directory path (`vhunambi_vault/audio/`).
  - **Acceptance Criteria**: Deleting metadata also deletes the local `.vmf` file from disk; `isTrackCachedLocally` verifies physical file existence.

---

### Milestone M8.3: Riverpod Download Manager & Preference Notifiers

- [x] **Task 8.3.1 (`REQ-P08-STREAM-04`, `REQ-P08-QUOTA-02`):** In `apps/vhunambi_client/lib/features/offline/presentation/providers/offline_providers.dart`:
  - Implement `DownloadManagerNotifier` managing `Map<String, DownloadTask>` state.
  - Enforce concurrency cap: maximum 2 active concurrent downloads, queuing remaining tasks.
  - Update `downloadManagerProvider`, `cacheStorageStatsProvider`, `offlinePreferencesProvider`, and `audioDownloadServiceProvider`.
  - Implement `requestDownload`, `cancelDownload`, `removeOfflineDownload`, and `clearAllDownloads`.
  - Synchronize track status directly with `libraryTracksProvider.notifier.updateTrackSyncStatus`.
  - **Acceptance Criteria**: Queue automatically advances as downloads complete; speed and ETA update every 500ms.

- [x] **Task 8.3.2 (`REQ-P08-QUOTA-01`):** In `offline_providers.dart`, implement `OfflinePreferencesNotifier`:
  - Methods: `toggleOfflineMode()`, `toggleWifiOnly()`, `setStorageLimit(int bytes)`.
  - Persist settings to Hive `vhunambi_prefs` box.
  - **Acceptance Criteria**: User preferences survive app restarts.

---

### Milestone M8.4: Playback Engine & Custom Encrypted Stream Resolver

- [x] **Task 8.4.1 (`REQ-P08-PLAY-01`, `REQ-P08-PLAY-02`):** In `apps/vhunambi_client/lib/features/player/data/services/audio_source_resolver.dart`:
  - Inject `IOfflineStorageService` and `VaultEnvelopeCrypto` into `AudioSourceResolver`.
  - Prioritize cached `.vmf` file: if `isTrackCachedLocally(track.id) == true`, return `ResolvedAudioSource` with `EncryptedVmfStreamSource`.
  - If `isOfflineModeForced == true` and track is not cached, throw `AudioSourceException(requiresConnectivity: true)`.
  - **Acceptance Criteria**: `just_audio` plays encrypted `.vmf` files with seeking support; forced offline mode blocks cloud streaming.

---

### Milestone M8.5: UI & Touch Ergonomics Integration

- [x] **Task 8.5.1 (`REQ-P08-UI-04`, `REQ-P08-QUOTA-03`):** In `apps/vhunambi_client/lib/features/offline/presentation/widgets/vault_storage_modal.dart`, implement `VaultStorageModal`:
  - Render storage quota progress bar (`Key('vault_storage_meter')`) with formatted usage vs. limit.
  - Storage limit choice chips (`1.0 GB`, `2.0 GB`, `5.0 GB`, `10.0 GB`).
  - Switches for `Wi-Fi only` (`Key('vault_wifi_only_switch')`) and `Force Offline Mode` (`Key('vault_force_offline_switch')`).
  - Outline button for `Clear All Offline Downloads` (`Key('vault_clear_all_downloads_btn')`) with confirmation dialog.
  - **Acceptance Criteria**: Tapping Clear All deletes all cached files and updates reactive stats.

- [x] **Task 8.5.2 (`REQ-P08-UI-01`):** In `apps/vhunambi_client/lib/features/library/presentation/widgets/track_actions_sheet.dart`:
  - Bind download action row to `downloadManagerProvider` and `track.syncStatus`:
    - `cloudOnly` $\to$ `"Download Offline"` with estimated file size.
    - `downloading` $\to$ `"Downloading... X%"` with cancel button.
    - `cachedLocally` $\to$ `"Remove Offline Download"` with trash icon.
  - **Acceptance Criteria**: Tapping download initiates transfer; tapping cancel aborts and cleans up.

- [x] **Task 8.5.3 (`REQ-P08-UI-02`, `REQ-P08-UI-03`):** In `apps/vhunambi_client/lib/features/library/presentation/views/library_view.dart`:
  - Add `"Cached Only"` filter pill (`Key('vault_filter_cached_only')`) in the vault filter bar.
  - Display green offline pin badge on cached track tiles.
  - **Acceptance Criteria**: Selecting "Cached Only" filters vault list strictly to locally cached tracks.

---

### Milestone M8.6: Automated Regression Suite & Physical Device Verification

- [x] **Task 8.6.1 (`G-08-01`..`G-08-06`):** Create `apps/vhunambi_client/test/features/offline/phase08_sovereign_offline_vault_test.dart` implementing all 8 verification gates:
  - `P08-T01`: `VaultEnvelopeCrypto` encrypts raw bytes to `.vmf` with magic header `"VHUN"` and decrypts symmetrically.
  - `P08-T02`: `ResilientAudioDownloadService` writes real bytes to disk and commits swap file atomically.
  - `P08-T03`: `ResilientAudioDownloadService` resumes interrupted downloads via HTTP `Range` headers.
  - `P08-T04`: `DownloadManagerNotifier` enforces concurrency cap of 2 active downloads and calculates speed/ETA.
  - `P08-T05`: `AudioSourceResolver` prioritizes local `.vmf` envelope over remote URL.
  - `P08-T06`: `AudioSourceResolver` throws `AudioSourceException` when forced offline mode is enabled for uncached track.
  - `P08-T07`: `VaultStorageModal` renders quota progress meter and executes Clear All cache purging.
  - `P08-T08`: `LibraryView` scopes list correctly when `TrackSyncFilter.cachedOnly` is selected.

- [x] **Task 8.6.2 (Verification & Delivery):**
  - Run `dart analyze lib/features/offline lib/features/player lib/features/library test/features/offline`.
  - Run `flutter test test/features/offline/phase08_sovereign_offline_vault_test.dart`.
  - Update `docs/AGENT_HANDOFF_BIBLE.md` and author `docs/phases/phase_08_offline_cache/walkthrough.md`.

---

## 3. Stage 4 Execution Verification Checklist

Before signing off on Stage 4 implementation, verify all 7 Anti-Trap invariants:
- [x] Invariant 1: `simulateDownloads` is explicitly `false` in production `audioDownloadServiceProvider`.
- [x] Invariant 2: Audio envelope strictly matches binary format: 4-byte `"VHUN"` magic header, 2-byte version, 16-byte IV, 8-byte length.
- [x] Invariant 3: Download swap file uses `.vswap` extension and is deleted upon cancel or error.
- [x] Invariant 4: `AudioSourceResolver` decrypts `.vmf` files via `StreamAudioSource` with zero whole-file memory bloat.
- [x] Invariant 5: Forced offline mode circuit-breaker throws descriptive user-facing exception on uncached tracks.
- [x] Invariant 6: All UI controls use authentic `PhosphorIcon` tokens (zero raw Unicode emojis).
- [x] Invariant 7: All tests pass with 0 analyzer errors or warnings.
