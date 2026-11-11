# Phase 59 — Full-Stack Backend API Convergence (`apps/vhunambi_api` & `apps/vhunambi_client`)
## Formal EARS & RFC-2119 Requirements Specification

**Document ID**: `VH-REQ-P59-FULLSTACK-CONVERGENCE`  
**Phase**: `59`  
**Status**: `ARGON-HARDENED SPECIFICATION`  
**Normative Keywords**: `SHALL`, `MUST`, `SHOULD`, `MAY` (per RFC-2119)

---

## 1. Explore Discovery, Genre Filtering & Radio Rotations (`REQ-P59-EXP`)

### `REQ-P59-EXP-01`: SQLite `explore_tracks` Seeding & Trending Velocity Computation
- **WHEN** `VhunambiDatabase` initializes via `seedInitialDataIfEmpty()`, the backend **SHALL** seed at least 12 canonical African catalog tracks into `explore_tracks` spanning `Amapiano`, `Afro-Tech`, `3-Step`, `Gqom`, `Afrobeats`, `Lekompo`, `Bacardi`, `Shangaan Electro`, `Maskandi`, `Kwaito`, `Deep House`, and `Hip-Hop` if `SELECT COUNT(*) FROM explore_tracks` is `0`.
- **WHERE** a track row is returned by `VhunambiDatabase`, the engine **SHALL** compute and attach deterministic `trendingScore` ($\in [0, 100]$) and `discoveryStage` (`'freshCrate' | 'risingBreakout' | 'mainstage'`).

### `REQ-P59-EXP-02`: Unified `GET /api/explore` & `GET /api/explore/tracks` Endpoints
- **WHEN** a client sends `GET /api/explore` with optional query parameters `genre`, `stage`, `sort` (`'trending' | 'newest' | 'likes' | 'plays'`), `search`, `cursor`, and `limit` (default `30`, max `100`), the API **SHALL** return HTTP `200 OK` with `{ status: 'ok', data: { tracks, posts, creators, radioStations, nextCursor, hasMore, serverSeq } }`.
- **WHEN** `genre` is provided and is not `'All'`, both `tracks` (`explore_tracks`) and `posts` (`kinetic_posts`) **SHALL** be filtered case-insensitively by matching `genre` or `sub_genre`.
- **WHEN** a client sends `GET /api/explore/tracks`, the API **SHALL** return `{ status: 'ok', data: { items, total, serverSeq } }` filtered by `genre`, `stage`, `search`, and sorted by `sort`.

### `REQ-P59-EXP-03`: Dynamic African Genre Radio Endpoint (`GET /api/explore/radio/:genre`)
- **WHEN** a client sends `GET /api/explore/radio/:genre` (e.g., `/api/explore/radio/Amapiano` or `/api/explore/radio/All`), the API **SHALL** return HTTP `200 OK` with `{ status: 'ok', data: { genre, stationTitle, description, seedBpm, rotation: ExploreTrackItem[], serverSeq } }` ordered by BPM harmonic proximity and trending score.

### `REQ-P59-EXP-04`: `Track` JSON Serialization & `HttpExploreRepository` Client Hydration
- **THE** client `Track` model (`lib/shared/models/track.dart`) **SHALL** implement `toJson()`, `fromJson(Map<String, dynamic> json)`, and `copyWith(...)` preserving all 20 fields (`id`, `title`, `artist`, `bpm`, `key`, `genre`, `duration`, `audioUrl`, `coverUrl`, `waveform`, `likesCount`, `commentsCount`, `sharesCount`, `cosignsCount`, `playCount`, `uploadedAt`, `discoveryStage`, `stemsAvailable`, `creatorHandle`, `province`).
- **WHEN** `ExploreTracksNotifier` initializes or `refreshFromCloud()` is invoked, it **SHALL** fetch tracks via `HttpExploreRepository` (`GET /api/explore`) and merge them with local tracks while gracefully falling back to the 8 offline seed tracks if the backend is unreachable.

### `REQ-P59-EXP-05`: Explore Track Upload & Co-Sign Persistence (`POST /api/explore/tracks`)
- **WHEN** a creator uploads or publishes a track or kinetic post on the client, or co-signs/reposts an item, the mutation **SHALL** be persisted to `explore_tracks` / `kinetic_posts` and recorded in `sync_mutation_log` so subsequent `GET /api/explore` and `GET /api/v1/sync/delta` calls include the update.

---

## 2. Bi-Directional Library Cloud Delta Sync (`REQ-P59-LIB`)

### `REQ-P59-LIB-01`: `LibraryTrack` Complete JSON Serialization
- **THE** `LibraryTrack` model (`lib/features/library/domain/models/library_models.dart`) **SHALL** implement `toJson()` and `factory LibraryTrack.fromJson(Map<String, dynamic> json)` preserving 100% of fields:
  - Core metadata: `id`, `title`, `artist`, `bpm`, `key`, `genre`, `durationMs` / `duration`, `dateAdded`, `filePath`
  - Flags & counters: `isStem`, `isFavorite`, `playCount`, `isDeleted`, `deletedAt`, `isMastered`, `lufs`
  - Phase 58 Beat Licensing metadata: `licensePurchaseId`, `licenseTierId`, `licenseCertificateHash`, `producerHandle`, `stemFilePaths`
  - Sync metadata: `updatedAtMs`

### `REQ-P59-LIB-02`: `GET /api/library/sync` & `POST /api/library/sync` Backend Endpoints
- **WHEN** a client requests `GET /api/library/sync?creatorId=<id>&sinceSeq=<seq>`, the backend **SHALL** return HTTP `200 OK` with `{ status: 'ok', data: { creatorId, items: LibrarySyncRecord[], serverSeq, syncedAt } }`.
- **WHEN** a client sends `POST /api/library/sync` with `{ creatorId, items: LibraryTrackJson[], deletedIds?: string[] }`, the backend **SHALL** atomically reconcile each item into `user_library_sync` using Last-Write-Wins (`updatedAtMs`) + monotonic `playCount = max(local, remote)` + non-destructive license metadata preservation, log each mutation to `sync_mutation_log` (`entityType: 'library_track'`), and return HTTP `200 OK` with `{ status: 'ok', data: { appliedCount, items, serverSeq, syncedAt } }`.

### `REQ-P59-LIB-03`: `HttpLibrarySyncRepository` & Hive Local Persistence
- **THE** client **SHALL** provide `HttpLibrarySyncRepository` backed by local Hive box `'vhunambi_library_tracks_v1'` (with automatic in-memory fallback when Hive is uninitialized in unit tests) and `Dio`.
- **WHEN** `LibraryTracksNotifier` mutates state (`addTrack`, `upsertLicensedTrack`, `deleteTrack`, `restoreTrack`, `purgeTrackPermanently`, `toggleFavorite`, `incrementPlayCount`), it **SHALL** immediately persist the updated `LibraryTrack` list to `HttpLibrarySyncRepository` local storage and enqueue a `SyncMutationRecord` (`entityType: 'library_track'`).

### `REQ-P59-LIB-04`: `applyMutationsBatch` Support for `library_track`
- **WHEN** `POST /api/v1/sync/batch` receives a mutation with `entityType === 'library_track'` and `operation` in `'upsert' | 'create' | 'update' | 'delete' | 'restore' | 'purge' | 'favorite' | 'play'`, `VhunambiDatabase.applyMutationsBatch()` **SHALL** apply the change to `user_library_sync` inside the SQLite transaction.

### `REQ-P59-LIB-05`: Library Cloud Sync Trigger & Status Provider
- **THE** client **SHALL** expose `libraryCloudSyncStatusProvider` and `LibraryTracksNotifier.syncWithCloud()` so the Library view or `EdgeSyncCoordinator` can trigger an on-demand or background delta sync and inspect `{ isSyncing, lastSyncedAt, serverSeq, pendingCount, errorMessage }`.

---

## 3. Playlists Cloud CRUD & Sovereign Sharing (`REQ-P59-PL`)

### `REQ-P59-PL-01`: SQLite `playlists` Table & Seed Initialization
- **THE** backend `VhunambiDatabase` **SHALL** create the `playlists` table (`id`, `creator_id`, `title`, `description`, `cover_image_url`, `track_ids_json`, `is_public`, `share_code`, `share_url`, `created_at`, `updated_at`) and seed 2 initial playlists (`pl_amapiano_gold`, `pl_3step_horizon`) when empty.

### `REQ-P59-PL-02`: `/api/playlists` Full CRUD & Share Endpoints
- **THE** backend **SHALL** mount `/api/playlists` in `server.ts` via `playlist_routes.ts` supporting:
  1. `GET /api/playlists?creatorId=<id>`: Returns `{ status: 'ok', data: { items: PlaylistJson[], total, serverSeq } }`.
  2. `GET /api/playlists/:id`: Returns `{ status: 'ok', data: PlaylistJson }` or `404 Not Found`.
  3. `POST /api/playlists`: Validates `title` (non-empty), persists new playlist in `playlists`, logs to `sync_mutation_log`, and returns `201 Created` with `{ status: 'ok', data: PlaylistJson, serverSeq }`.
  4. `PUT /api/playlists/:id`: Updates `title`, `description`, `cover_image_url`, `track_ids`, or `is_public`, logs to `sync_mutation_log`, and returns `200 OK`.
  5. `DELETE /api/playlists/:id`: Deletes the playlist row, logs to `sync_mutation_log` (`operation: 'delete'`), and returns `200 OK` with `{ status: 'ok', deletedId, serverSeq }`.
  6. `POST /api/playlists/:id/share`: Marks `is_public = 1`, generates deterministic `share_code` and `share_url` (`https://vhunambi.za/p/<shareCode>`), and returns `200 OK` with `{ status: 'ok', data: { playlistId, shareCode, shareUrl, isPublic: true, sharedAt }, serverSeq }`.

### `REQ-P59-PL-03`: `PlaylistEntity` Share Metadata & Hybrid `PlaylistRepository`
- **THE** `PlaylistEntity` model (`lib/features/playlists/domain/models/playlist_entity.dart`) **SHALL** support optional `shareCode` (`share_code`) and `shareUrl` (`share_url`) fields in `toJson()`, `fromJson()`, and `copyWith()` while remaining 100% backward-compatible with existing tests.
- **THE** `PlaylistRepository` (`lib/features/playlists/data/repositories/playlist_repository.dart`) **SHALL** accept optional `Dio? dio` and `SyncOutboxService? outbox`, persisting immediately to local Hive/memory while syncing with `/api/playlists` and exposing `syncPlaylistsWithCloud()` and `sharePlaylist(String id)`.

### `REQ-P59-PL-04`: `applyMutationsBatch` Support for `playlist`
- **WHEN** `POST /api/v1/sync/batch` receives a mutation with `entityType === 'playlist'`, `VhunambiDatabase.applyMutationsBatch()` **SHALL** upsert or delete the corresponding row in `playlists` atomically.

### `REQ-P59-PL-05`: `PlaylistsVaultView` Phosphor Icon & Cloud Share Compliance
- **THE** `PlaylistsVaultView` (`lib/features/playlists/presentation/views/playlists_vault_view.dart`) **SHALL** replace all legacy stock Material `Icons.*` (`Icons.search_rounded`, `Icons.clear_rounded`, `Icons.add_rounded`) with `PhosphorIcon` (`PhosphorIcons.magnifyingGlass()`, `PhosphorIcons.x()`, `PhosphorIcons.plus()`) and expose a cloud sync indicator button (`Key('playlists_cloud_sync_btn')`).

---

## 4. South African Banking & Payout Gateway Convergence (`REQ-P59-PAY`)

### `REQ-P59-PAY-01`: Canonical South African Bank & Universal Branch Registry
- **THE** backend (`vhunambi_db.ts`) and client (`creator_wallet.dart` / `payout_details_sheet.dart`) **SHALL** normalize all South African bank names case-insensitively and alias-safely:
  - `'Capitec'` / `'Capitec Bank'` $\to$ Canonical `'Capitec Bank'`, Branch `'470010'`
  - `'FNB'` / `'First National Bank'` $\to$ Canonical `'FNB'`, Branch `'250655'`
  - `'Standard Bank'` $\to$ Canonical `'Standard Bank'`, Branch `'051001'`
  - `'Nedbank'` $\to$ Canonical `'Nedbank'`, Branch `'198765'`
  - `'ABSA'` / `'Absa'` / `'Absa Bank'` $\to$ Canonical `'Absa Bank'`, Branch `'632005'`
  - `'TymeBank'` / `'Tyme Bank'` $\to$ Canonical `'TymeBank'`, Branch `'678910'`
- **IF** `branchCode` is omitted or empty in `POST /api/wallet/payout`, the backend **SHALL** auto-fill the bank's universal branch code from the canonical registry.

### `REQ-P59-PAY-02`: Multi-Rail Payout Clearance (`Capitec Pay`, `Ozow`, `PayFast`, `Standard EFT`)
- **WHEN** `POST /api/wallet/payout` is called with `{ creatorId, amountZar, bankName, accountNumber, branchCode?, paymentRail?, accountHolder? }`, the backend **SHALL** validate:
  1. `amountZar >= 50` (HTTP `400` if below minimum R50.00),
  2. `accountNumber` contains `8` to `12` digits (HTTP `400` if invalid),
  3. `bankName` resolves in the SA Bank Registry (HTTP `400` if unsupported),
  4. Creator `balance_zar >= amountZar` (HTTP `400` if insufficient funds).
- **UPON** validation, `VhunambiDatabase.requestPayout()` **SHALL** atomically debit `creators.balance_zar`, upsert the verified masked account into `bank_accounts`, insert a `'payout'` entry into `wallet_ledger` with gateway metadata (`paymentRail`, `feeZar`, `netPayoutZar`, `referenceCode`, `estimatedArrival`, `maskedAccount`), log to `sync_mutation_log`, and return HTTP `201 Created`.

### `REQ-P59-PAY-03`: Unification of `/api/wallet/payout` and `/api/creators/:id/wallet/payout`
- **WHEN** a client calls either `POST /api/wallet/payout` or `POST /api/creators/:id/wallet/payout`, both routes **SHALL** execute against the unified SQLite WAL `vhunambiDb.requestPayout` engine and synchronize the in-memory `socialService` projection so `GET /api/wallet/:creatorId` and `GET /api/creators/:id/wallet` return consistent balances and transaction ledgers.

### `REQ-P59-PAY-04`: `PayoutDetailsSheet` Auto-Branch & Gateway Rail Selector
- **WHEN** a user selects a South African bank in `PayoutDetailsSheet` (`lib/features/profile/presentation/widgets/payout_details_sheet.dart`), the sheet **SHALL** automatically populate the canonical universal branch code (while allowing manual override) and let the user select a settlement rail (`Capitec Pay`, `Ozow Instant EFT`, `PayFast`, or `Standard EFT`).

### `REQ-P59-PAY-05`: `HttpSocialRepository` & `CreatorWalletNotifier` Payout Receipt Wiring
- **WHEN** `CreatorWalletNotifier.requestPayout()` executes, it **SHALL** pass `bankName`, `accountNumber`, `branchCode`, and `paymentRail` to the repository, update local wallet balance and transaction ledger with the gateway clearance reference, and enqueue an offline `payout` mutation in `SyncOutboxService` if the network is unreachable.

---

## 5. Edge Sync Coordinator Bi-Directional Hydration (`REQ-P59-SYNC`)

### `REQ-P59-SYNC-01`: `EdgeSyncCoordinator` Delta Hydrator Registration & Dispatch
- **THE** `EdgeSyncCoordinator` (`lib/core/sync/edge_sync_coordinator.dart`) **SHALL** support registering domain delta hydrator callbacks (`typedef SyncDeltaHydrator = FutureOr<void> Function(List<Map<String, dynamic>> mutations)`).
- **WHEN** `EdgeSyncCoordinator.syncNow()` pulls non-empty `changes` from `GET /api/v1/sync/delta`, it **SHALL** invoke all registered hydrators before marking the sync cycle complete.

---

## 6. Non-Functional Requirements (`REQ-P59-NFR`)

- **`REQ-P59-NFR-01` (Offline Resilience)**: Every HTTP repository (`HttpExploreRepository`, `HttpLibrarySyncRepository`, `PlaylistRepository`, `HttpSocialRepository`) **MUST** catch `DioException` and socket timeouts gracefully (`<= 4s` timeout) and fall back to local Hive/seed state without throwing unhandled exceptions to UI widgets.
- **`REQ-P59-NFR-02` (SQLite WAL Atomicity)**: All multi-table writes in `vhunambi_db.ts` **MUST** execute inside `this.db.transaction(...)` and increment `sync_mutation_log.seq` monotonically.
- **`REQ-P59-NFR-03` (STD-UIUX-001 Visual & Token Purity)**: Zero raw emojis in UI text, zero stock Material `Icons.*` in touched views, and 100% adherence to `AppColors.*` and `AppTypography.*`.

---

## 7. Requirement-to-Test Traceability Matrix

| Requirement ID | Primary Implementation Files | Verification Test Suite | Gate |
| :--- | :--- | :--- | :--- |
| `REQ-P59-EXP-01..03` | `apps/vhunambi_api/src/db/vhunambi_db.ts`, `src/routes/explore_routes.ts` | `apps/vhunambi_api/src/__tests__/phase59_convergence.test.ts` | `G-59-01` |
| `REQ-P59-EXP-04..05` | `lib/shared/models/track.dart`, `lib/features/explore/data/repositories/http_explore_repository.dart`, `explore_providers.dart` | `test/features/explore/phase59_explore_sync_test.dart` | `G-59-01` |
| `REQ-P59-LIB-01..05` | `apps/vhunambi_api/src/routes/library_routes.ts`, `lib/features/library/domain/models/library_models.dart`, `http_library_sync_repository.dart`, `library_providers.dart` | `test/features/library/phase59_library_sync_test.dart` | `G-59-02` |
| `REQ-P59-PL-01..05` | `apps/vhunambi_api/src/routes/playlist_routes.ts`, `lib/features/playlists/domain/models/playlist_entity.dart`, `playlist_repository.dart`, `playlists_vault_view.dart` | `test/features/playlists/phase59_playlist_cloud_sync_test.dart` | `G-59-03` |
| `REQ-P59-PAY-01..05` | `apps/vhunambi_api/src/routes/wallet_routes.ts`, `social_routes.ts`, `lib/features/social/domain/models/creator_wallet.dart`, `payout_details_sheet.dart` | `test/features/social/phase59_wallet_payout_gateway_test.dart` | `G-59-04` |
| `REQ-P59-SYNC-01` | `lib/core/sync/edge_sync_coordinator.dart` | `test/features/library/phase59_library_sync_test.dart` | `G-59-05` |

