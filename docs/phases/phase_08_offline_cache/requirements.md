# Phase 8 Requirements: Sovereign Offline Audio Vault & Encrypted Caching Pipeline

```
══════════════════════════════════════════════════════════════════════════════════════════════════════════════
  VHUNAMBI ENGINEERING REQUIREMENTS SPECIFICATION
  PHASE 08: SOVEREIGN OFFLINE AUDIO VAULT & RESILIENT CHUNK STREAMING PIPELINE
  STANDARD: EARS (Easy Approach to Requirements Syntax) & RFC 2119
  TARGET PACKAGE: apps/vhunambi_client
  PARENT BLUEPRINT: docs/phases/phase_08_offline_cache/blueprint.md
══════════════════════════════════════════════════════════════════════════════════════════════════════════════
```

---

## 1. Document Scope, Architecture Standards & EARS Conventions

This document specifies the exact behavioral, functional, security, and performance requirements for the **Sovereign Offline Audio Vault** in `apps/vhunambi_client`.

### EARS Requirement Syntactical Patterns
Every functional requirement adheres to the **Easy Approach to Requirements Syntax (EARS)**:
- **Ubiquitous**: `The system SHALL <response>`
- **Event-Driven**: `WHEN <trigger>, the system SHALL <response>`
- **State-Driven**: `WHILE <state>, the system SHALL <response>`
- **Unwanted Event**: `IF <error condition>, THEN the system SHALL <response>`
- **Optional Feature**: `WHERE <feature is enabled>, the system SHALL <response>`

---

## 2. Real HTTP Chunk Streaming & Network Resilience Requirements

### REQ-P08-STREAM-01: Real HTTP Chunk Streaming Execution
* **WHEN** a track download is triggered for a valid remote URL, the `ResilientAudioDownloadService` **SHALL** establish a streaming HTTP connection using `Dio` and write incoming binary chunks to disk in progressive blocks ($\le 64\text{ KB}$).
* The system **SHALL NOT** default to simulated timer loops or mock delays in production builds (`simulateDownloads: false`).
* **WHERE** a track URL begins with `test://`, `mock://`, or `simulateDownloads == true` is explicitly passed in a test environment, the service **SHALL** execute the deterministic mock transfer runner.

### REQ-P08-STREAM-02: HTTP Range Resumable Transfers
* **IF** an in-progress download is interrupted by a network timeout, socket exception, or application suspension, **THEN** the system **SHALL** inspect the temporary swap file (`<track_id>.vswap`).
* **WHEN** the transfer is resumed, the system **SHALL** attach the HTTP request header `Range: bytes=<existing_byte_length>-` to stream solely the remaining payload from the CDN server without redownloading previously transferred bytes.
* **IF** the remote CDN server returns `HTTP 416 (Range Not Satisfiable)` or `HTTP 200 (OK)` instead of `HTTP 206 (Partial Content)`, **THEN** the system **SHALL** truncate the swap file to 0 bytes and restart the transfer from byte 0.

### REQ-P08-STREAM-03: Exponential Backoff Auto-Retry
* **IF** a streaming network transfer encounters a transient network failure (`DioExceptionType.connectionTimeout`, `sendTimeout`, `receiveTimeout`, or `connectionError`), **THEN** the system **SHALL** transition the task to `DownloadTaskStatus.retrying` and attempt up to 3 automatic retries.
* The delay between retries **SHALL** scale exponentially:
  $$T_{\text{delay}} = 2^k \cdot 1000\text{ms} + \text{jitter}, \quad k \in \{1, 2, 3\}$$
* **IF** all 3 retries fail, **THEN** the system **SHALL** transition the task status to `DownloadTaskStatus.failed` and preserve the swap file for manual user retry.

### REQ-P08-STREAM-04: Dynamic Transfer Speed & ETA Telemetry
* **WHILE** a track is streaming, the `DownloadManagerNotifier` **SHALL** calculate real-time transfer velocity every $500\text{ms}$ using Exponential Moving Average smoothing ($\alpha = 0.35$).
* The system **SHALL** expose `bytesPerSecond` ($v$), human-readable formatted speed (e.g. `"1.2 MB/s"` or `"640 KB/s"`), and estimated remaining time in seconds ($t_{\text{eta}}$) on the `DownloadTask` entity.

---

## 3. Cryptographic Storage & Vault Envelope Requirements

### REQ-P08-CRYPTO-01: Encrypted Audio Envelope Format (`.vmf`)
* **WHEN** audio chunks are committed to device storage, the system **SHALL** encapsulate the payload inside the proprietary Vhunambi Media File (`.vmf`) envelope.
* The envelope **SHALL** strictly conform to the binary layout:
  1. `MAGIC_HEADER`: Exactly 4 bytes `0x56, 0x48, 0x55, 0x4E` (`"VHUN"`).
  2. `VERSION`: 2-byte big-endian unsigned short `0x0001`.
  3. `IV_NONCE`: 16 cryptographically random bytes generated via `Random.secure()`.
  4. `PAYLOAD_SIZE`: 8-byte big-endian unsigned integer indicating unencrypted byte length.
  5. `CIPHERTEXT`: AES-128-CTR encrypted audio stream.

### REQ-P08-CRYPTO-02: Device-Unique Key Derivation
* The system **SHALL** derive the 128-bit AES encryption key using PBKDF2 or SHA-256 HMAC incorporating the application bundle identifier (`com.vhunambi.app`), a sovereign master seed, and an immutable salt stored in secure device storage.
* Raw audio bytes **SHALL NEVER** be written to unencrypted storage partitions where non-privileged external applications can scrape master audio files.

### REQ-P08-CRYPTO-03: Two-Phase Commit Atomic File Storage
* **WHILE** downloading, all received ciphertext **SHALL** be written exclusively to a swap file with the extension `.vswap`.
* **WHEN** the download reaches 100% of reported `content-length` and the magic header is validated, the system **SHALL** execute an atomic file rename from `<track_id>.vswap` to `<track_id>.vmf`.
* **IF** the download is cancelled by the user, **THEN** the system **SHALL** immediately abort the active transfer and delete the associated `.vswap` file from disk.

---

## 4. Playback Integration & Source Resolution Requirements

### REQ-P08-PLAY-01: Priority Resolution of Cached Vault Audio
* **WHEN** `AudioSourceResolver.resolveSource(track)` is invoked, the resolver **SHALL** first query `IOfflineStorageService.isTrackCachedLocally(track.id)`.
* **IF** a valid `.vmf` file exists at the recorded local path, **THEN** the resolver **SHALL** construct and return a `StreamAudioSource` or local file URI that decrypts the `.vmf` envelope on-the-fly into `just_audio`.
* Decryption **SHALL** support arbitrary seeking via byte-offset calculation in AES-CTR mode without reading the entire encrypted file into RAM memory.

### REQ-P08-PLAY-02: Forced Offline Mode Circuit-Breaker
* **WHERE** the user has toggled `isOfflineModeForced: true` in `OfflinePreferencesState`, the system **SHALL** block all outbound network audio streams.
* **IF** the requested track is not present in the local offline vault while forced offline mode is active, **THEN** `AudioSourceResolver` **SHALL** throw a descriptive `AudioSourceException` with `requiresConnectivity: true`.
* The playback UI **SHALL** display a helpful dialog/toast: `"Offline mode is enabled and this track is not cached. Connect to download it for offline playback."`

### REQ-P08-PLAY-03: Offline Playback Source Indicators
* **WHILE** a track is playing from local encrypted cache, the `ExpandedCockpitModal` **SHALL** render an offline badge with `Key('player_offline_source_pill')`.
* The badge **SHALL** display `PhosphorIcon(PhosphorIconsFill.cloudSlash)` and the text `"Offline Vault"`.

---

## 5. Storage Quota, LRU Eviction & Vault Management Requirements

### REQ-P08-QUOTA-01: Configurable Storage Ceilings
* The system **SHALL** support user-selectable offline storage ceilings in `OfflinePreferenceState`:
  1. `500 MB` ($524,288,000\text{ bytes}$)
  2. `1.0 GB` ($1,073,741,824\text{ bytes}$)
  3. `2.0 GB` ($2,147,483,648\text{ bytes}$)
  4. `5.0 GB` ($5,368,709,120\text{ bytes}$) — Default
  5. `10.0 GB` ($10,737,418,240\text{ bytes}$)
  6. `Unlimited` ($0\text{ bytes}$)

### REQ-P08-QUOTA-02: Automated LRU Cache Eviction
* **WHEN** a newly completed download causes total cached bytes to exceed the configured storage ceiling, the `CacheEvictionEngine` **SHALL** automatically evict unpinned cached tracks until total usage is below 85% of the ceiling.
* Tracks **SHALL** be ranked for eviction by Least Recently Played timestamp ($T_{\text{last\_played}}$).
* Pinned tracks (`isPinned == true`) and user favorites **SHALL NOT** be auto-evicted.

### REQ-P08-QUOTA-03: One-Tap Cache Purging
* **WHEN** the user triggers `"Clear All Offline Downloads"` in `VaultStorageModal` (`Key('vault_clear_all_downloads_btn')`), the system **SHALL**:
  1. Delete all `.vmf` and `.vswap` audio files in the vault audio directory.
  2. Update all records in the Hive `library_tracks` box to `TrackSyncStatus.cloudOnly`.
  3. Emit an updated `CacheStorageStats` with `totalBytesUsed == 0` and `cachedTrackCount == 0`.

---

## 6. UI/UX & Touch Ergonomics Requirements (`STD-UIUX-001`)

### REQ-P08-UI-01: Track Actions Sheet Download Actions
* In `TrackActionsSheet`, the download action row **SHALL** dynamically render:
  - **Cloud-Only State**: Label `"Download Offline"` with estimated file size (e.g. `8.5 MB`) and `PhosphorIcon(PhosphorIconsRegular.downloadSimple)`.
  - **Downloading State**: Label `"Downloading... 64%"` with live progress bar and `Key('track_action_cancel_download_btn')`.
  - **Cached State**: Label `"Remove Offline Download"` with `PhosphorIcon(PhosphorIconsRegular.trashSimple)` and file size badge.

### REQ-P08-UI-02: Library Vault Track Sync Badges & Progress Rings
* In `LibraryTrackTile` and `LibraryTrackGridCard`, the widget **SHALL** render:
  - An interactive circular progress indicator with percentage text when `syncStatus == TrackSyncStatus.downloading`.
  - A green offline pin badge (`PhosphorIcon(PhosphorIconsFill.checkCircle, color: AppColors.brandPrimary)`) when `syncStatus == TrackSyncStatus.cachedLocally`.

### REQ-P08-UI-03: Vault Filter Rail Cached-Only Filter
* In `LibraryView` filter rail, the system **SHALL** provide a `"Cached Only"` filter pill with `Key('vault_filter_cached_only')`.
* **WHEN** selected, the vault list **SHALL** filter strictly to tracks where `syncStatus == TrackSyncStatus.cachedLocally`.

### REQ-P08-UI-04: Vault Storage Quota Modal (`VaultStorageModal`)
* The `VaultStorageModal` **SHALL** be accessible from `LibraryAppBar` (`Key('library_vault_storage_btn')`) and render:
  - A visual progress meter with `Key('vault_storage_meter')` showing bytes used vs. limit.
  - Radio pills for storage limits (`500 MB`, `1 GB`, `2 GB`, `5 GB`, `10 GB`).
  - Wi-Fi only download toggle switch (`Key('vault_wifi_only_switch')`).
  - Force Offline Mode toggle switch (`Key('vault_force_offline_switch')`).
  - Clear All button with confirmation dialog (`Key('vault_clear_all_downloads_btn')`).

---

## 7. Non-Functional & Performance Requirements (`REQ-P08-NFR-*`)

- **`REQ-P08-NFR-01` (I/O Throughput & Frame Rate)**: Chunked file writes and stream decryption **SHALL NOT** block the Flutter UI thread. All disk encryption and hashing **SHALL** run within buffered streams maintaining a smooth 60 FPS UI frame rate.
- **`REQ-P08-NFR-02` (Zero Third-Party Binary Bloat)**: Streaming and decryption **SHALL** use existing monorepo dependencies (`dio`, `path_provider`, `hive_flutter`, `crypto`, `just_audio`). Zero unverified third-party native C++ plugins are permitted.
- **`REQ-P08-NFR-03` (Zero Raw Emojis)**: In strict compliance with `STD-UIUX-001`, all UI icons and indicators **SHALL** use `PhosphorIcon` tokens (e.g. `PhosphorIconsRegular.downloadSimple`, `PhosphorIconsFill.cloudSlash`). Zero raw Unicode emojis.
- **`REQ-P08-NFR-04` (Headless Dart VM Testability)**: All domain services (`VaultEnvelopeCrypto`, `ResilientAudioDownloadService`, `CacheEvictionEngine`) **SHALL** execute seamlessly in headless Dart VM environments using temporary test directories and in-memory mock adapters.

---

## 8. Requirement-to-Test Traceability Matrix

```
┌──────────────────┬─────────────────────────────────────┬────────────────────────────────────────────┐
│ Requirement ID   │ Target Service / Widget             │ Automated Verification Test Case           │
├──────────────────┼─────────────────────────────────────┼────────────────────────────────────────────┤
│ REQ-P08-STREAM-01│ ResilientAudioDownloadService       │ 'real HTTP chunk stream writes binary'     │
│ REQ-P08-STREAM-02│ ResilientAudioDownloadService       │ 'HTTP Range header resumes partial swap'   │
│ REQ-P08-STREAM-03│ ResilientAudioDownloadService       │ 'network timeout triggers exponential retry'│
│ REQ-P08-STREAM-04│ DownloadManagerNotifier             │ 'computes transfer speed and ETA telemetry'│
│ REQ-P08-CRYPTO-01│ VaultEnvelopeCrypto                 │ 'encapsulates audio into .vmf envelope'    │
│ REQ-P08-CRYPTO-02│ VaultEnvelopeCrypto                 │ 'encrypts/decrypts with device salt key'   │
│ REQ-P08-CRYPTO-03│ SovereignOfflineStorageService      │ 'atomic rename .vswap to .vmf on verify'   │
│ REQ-P08-PLAY-01  │ AudioSourceResolver                 │ 'prioritizes local .vmf cache over remote' │
│ REQ-P08-PLAY-02  │ AudioSourceResolver                 │ 'forced offline mode throws on cloud track'│
│ REQ-P08-PLAY-03  │ ExpandedCockpitModal                │ 'displays offline source badge in cockpit' │
│ REQ-P08-QUOTA-01 │ OfflinePreferencesNotifier          │ 'persists storage ceiling configurations'  │
│ REQ-P08-QUOTA-02 │ CacheEvictionEngine                 │ 'evicts unpinned LRU tracks when over quota'│
│ REQ-P08-QUOTA-03 │ SovereignOfflineStorageService      │ 'clears all downloads and resets metadata' │
│ REQ-P08-UI-01    │ TrackActionsSheet                   │ 'renders dynamic download/remove actions'  │
│ REQ-P08-UI-02    │ LibraryTrackTile                    │ 'renders progress ring and offline pin'    │
│ REQ-P08-UI-03    │ LibraryView                         │ 'scopes vault list to cachedOnly filter'   │
│ REQ-P08-UI-04    │ VaultStorageModal                   │ 'renders quota meter and clear all CTA'    │
└──────────────────┴─────────────────────────────────────┴────────────────────────────────────────────┘
```
