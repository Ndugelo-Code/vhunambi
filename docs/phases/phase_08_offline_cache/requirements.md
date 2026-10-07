# Phase 8 Requirements: Offline Audio Persistence & Hive Cache

> **Target Package:** `apps/vhunambi_client`  
> **Standard:** EARS (Easy Approach to Requirements Syntax) & RFC 2119 (`MUST`, `SHALL`, `SHOULD`)  
> **Parent Blueprint:** [`docs/foundation_blueprints/04_LIBRARY_VAULT_SPEC.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/foundation_blueprints/04_LIBRARY_VAULT_SPEC.md) §5  

---

## 1. Local Storage & Hive Box Requirements

### REQ-OFF-01: Offline Storage Service Initialization
* The system **MUST** provide an `OfflineStorageService` managing local persistence using Hive boxes.
* The service **MUST** open or initialize the `library_tracks` box (`AppConstants.vaultBoxKey`) and `vhunambi_prefs` box (`AppConstants.preferencesBoxKey`).
* In headless or test environments, the service **MUST** support in-memory operation without failing or throwing platform channel missing plugin exceptions.

### REQ-OFF-02: Track Metadata Persistence & Retrieval
* When a track is downloaded or imported, the system **MUST** persist its metadata (ID, title, artist, genre, audio path, file size in bytes, download timestamp) into Hive.
* The system **MUST** provide methods to retrieve all cached tracks, find a cached track by ID, and verify if a local audio file exists at the recorded file path.

### REQ-OFF-03: Local File Eviction & Cache Purging
* When a user removes an offline download, the system **MUST** delete the binary file from local storage, remove the record from Hive, and update the track's `syncStatus` back to `TrackSyncStatus.cloudOnly`.
* The system **MUST** provide a "Clear All Downloads" capability that removes all cached audio binaries and resets all vault records to cloud-only state.

---

## 2. Download Manager & Queue State Machine Requirements

### REQ-OFF-04: Background Download Execution & Progress Tracking
* The system **MUST** provide a `DownloadManagerNotifier` backed by Riverpod state.
* The download manager **MUST** support streaming remote audio files and emitting real-time progress (`0.0` to `1.0`), byte counts (received vs. total), and transfer status (`queued`, `downloading`, `paused`, `completed`, `failed`).
* The download manager **MUST** constrain concurrent downloads to a maximum of 2 active downloads, queuing additional requests until active slots complete.

### REQ-OFF-05: Download Cancellation & Error Recovery
* When an active download is cancelled by the user, the system **MUST** abort the transfer, delete any partial temporary files, and restore the track status to `cloudOnly`.
* If a network error or transfer timeout occurs, the system **MUST** transition the task status to `failed` and allow one-tap retry.

---

## 3. Storage Quota & Analytics Requirements

### REQ-OFF-06: Cache Storage Statistics & Quota Inspection
* The system **MUST** compute and expose `CacheStorageStats` via `cacheStorageStatsProvider`.
* `CacheStorageStats` **MUST** include:
  1. `totalBytesUsed`: Total bytes occupied by cached audio tracks.
  2. `formattedBytesUsed`: Human-readable size string (e.g. `"42.8 MB"`).
  3. `cachedTrackCount`: Total number of locally cached audio assets.
  4. `storageLimitBytes`: Configured storage ceiling (default: 5 GB).
  5. `quotaUsagePercentage`: Fraction of storage quota consumed (`0.0` to `1.0`).

---

## 4. UI/UX Integration Requirements

### REQ-OFF-07: Track Actions Sheet Integration
* In `TrackActionsSheet`, the download action **MUST** dynamically display:
  - `"Download Offline"` with approximate file size when `syncStatus == TrackSyncStatus.cloudOnly`.
  - `"Downloading..."` with live progress percentage and a cancel button when `syncStatus == TrackSyncStatus.downloading`.
  - `"Remove Offline Download"` when `syncStatus == TrackSyncStatus.cachedLocally`.

### REQ-OFF-08: Vault Badges & Offline Visual Indicators
* In `LibraryTrackTile` and `LibraryTrackGridCard`, the widget **MUST** display:
  - A linear progress indicator or progress ring when `syncStatus == TrackSyncStatus.downloading`.
  - An offline pin badge (`Icons.offline_pin_rounded` in `AppColors.brandPrimary`) when `syncStatus == TrackSyncStatus.cachedLocally`.

### REQ-OFF-09: Offline-Only Filter Scoping
* When the user selects `LibrarySyncFilter.offlineOnly` in the vault search/filter strip, the vault **MUST** filter the list to display strictly tracks where `syncStatus == TrackSyncStatus.cachedLocally` and `localAudioFilePath != null`.

### REQ-OFF-10: Persistent Audio Player Offline Fallback
* When `PlayerNotifier.playTrack()` or `playLibraryTrack()` is invoked, if a local cached file exists for the track, the audio engine **MUST** prioritize the local file path over the remote URL.
* In the expanded cockpit modal, if the currently playing track is playing from local cache, the view **MUST** render an offline playback pill badge (`"Offline Storage"`).

### REQ-OFF-11: Vault Storage Quota Modal
* The system **MUST** provide a `VaultStorageModal` dialog/bottom sheet accessible from the Library vault.
* The modal **MUST** display:
  - A progress bar indicating storage used vs. limit.
  - Total cached track count and total disk usage.
  - A list of cached tracks with individual file sizes.
  - A `"Clear All Downloads"` confirmation button.
