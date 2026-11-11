# Phase 59 — Full-Stack Backend API Convergence (`apps/vhunambi_api` & `apps/vhunambi_client`)
## Master Execution Roadmap & Granular Task Matrix

**Document ID**: `VH-TASKS-P59-FULLSTACK-CONVERGENCE`  
**Phase**: `59`  
**Status**: `COMPLETED`  
**Engineering Standard**: All-Gemini Engineering Standard (`STD-ARCH-P59` / `STD-UIUX-001` / `STD-SYNC-039`)

---

## 1. Master Milestone Roadmap

| Milestone ID | Milestone Name | Primary Scope | Gate |
| :--- | :--- | :--- | :--- |
| **`M59.1`** | **SQLite WAL Engine & Hono REST Convergence (`apps/vhunambi_api`)** | `vhunambi_db.ts` (`playlists` schema, 12 `explore_tracks` seeds, `getExploreTracks`, `getExploreRadioRotation`, `syncLibraryDelta`, `SA_BANK_REGISTRY` & multi-rail `requestPayout`, `applyMutationsBatch`), `explore_routes.ts`, `library_routes.ts`, `playlist_routes.ts`, `wallet_routes.ts`, `social_routes.ts`, `server.ts`. | `G-59-01..04` |
| **`M59.2`** | **Explore Discovery Client Serialization & `HttpExploreRepository`** | `Track.toJson()` / `fromJson()` / `copyWith()`, `HttpExploreRepository`, `ExploreTracksNotifier` & `SocialFeedPostsNotifier` cloud hydration + Genre Radio provider. | `G-59-01` |
| **`M59.3`** | **Library Cloud Delta Sync & Hive Persistence (`HttpLibrarySyncRepository`)** | `LibraryTrack.toJson()` / `fromJson()`, `HttpLibrarySyncRepository` (LWW merge + Hive + Dio), `LibraryTracksNotifier` persistence & `SyncOutboxService` enqueueing, `libraryCloudSyncStatusProvider`. | `G-59-02` |
| **`M59.4`** | **Playlists Full-Stack CRUD, Cloud Sharing & Phosphor UI Upgrade** | `PlaylistEntity` (`shareCode`, `shareUrl`), `IPlaylistRepository` & `PlaylistRepository` (Dio + Outbox + `syncPlaylistsWithCloud` + `sharePlaylist`), `PlaylistsNotifier`, `PlaylistsVaultView` Phosphor icons & Cloud Sync action. | `G-59-03`, `G-59-06` |
| **`M59.5`** | **SA Banking Gateway Convergence & `EdgeSyncCoordinator` Delta Hydrator** | `SaBankOption` & `PayoutGatewayRail` in `creator_wallet.dart`, `HttpSocialRepository.requestPayout` unified `/api/wallet/payout` wiring, `PayoutDetailsSheet` auto-branch & rail selector, `EdgeSyncCoordinator.registerDeltaHydrator`. | `G-59-04`, `G-59-05` |
| **`M59.6`** | **Full-Stack Verification, Automated Test Suites & Static Analysis Sign-Off** | Backend TypeScript tests (`phase59_convergence.test.ts`), Flutter test suites (`phase59_explore_sync_test.dart`, `phase59_library_sync_test.dart`, `phase59_playlist_cloud_sync_test.dart`, `phase59_wallet_payout_gateway_test.dart`), `dart analyze` & `dart format`. | `G-59-07`, `G-59-08` |

---

## 2. Granular Task Breakdown

### Milestone `M59.1`: SQLite WAL Engine & Hono REST Convergence (`apps/vhunambi_api`)

- [x] **Task `59.1.1` — Upgrade `VhunambiDatabase` Schema, Seeds & Domain Engines**
  - **Target File**: `apps/vhunambi_api/src/db/vhunambi_db.ts`
  - **Deliverables**:
    1. Add `playlists` table (`id, creator_id, title, description, cover_image_url, track_ids_json, is_public, share_code, share_url, created_at, updated_at`) and index in `initSchema()`.
    2. Seed 12 canonical African tracks into `explore_tracks` and 2 playlists into `playlists` inside `seedInitialDataIfEmpty()`.
    3. Implement `getExploreTracks()`, `getExploreRadioRotation()`, `upsertExploreTrack()`, and fix `getExploreFeed()` to filter by `options.genre` when provided.
    4. Implement `syncLibraryDelta()` with LWW (`updatedAtMs`), monotonic `playCount`, and non-destructive Phase 58 beat license preservation.
    5. Implement `getPlaylists()`, `getPlaylistById()`, `upsertPlaylist()`, `deletePlaylist()`, and `sharePlaylist()`.
    6. Add `SA_BANK_REGISTRY` (aliasing `'Capitec'`/`'Capitec Bank'`, `'FNB'`, `'Standard Bank'`, `'Nedbank'`, `'ABSA'`/`'Absa Bank'`, `'TymeBank'`) and upgrade `requestPayout()` with `capitec_pay`, `ozow`, `payfast`, and `eft` rails.
    7. Extend `applyMutationsBatch()` to handle `entityType` values `'library_track'`, `'playlist'`, and `'track'`.

- [x] **Task `59.1.2` — Upgrade `explore_routes.ts` & `library_routes.ts`**
  - **Target Files**:
    - `apps/vhunambi_api/src/routes/explore_routes.ts`
    - `apps/vhunambi_api/src/routes/library_routes.ts`
  - **Deliverables**:
    1. Add `GET /api/explore`, `GET /api/explore/tracks`, `POST /api/explore/tracks`, and `GET /api/explore/radio/:genre` in `explore_routes.ts`.
    2. Add `GET /api/library/sync` and `POST /api/library/sync` in `library_routes.ts`.

- [x] **Task `59.1.3` — Create `playlist_routes.ts` & Mount in `server.ts`**
  - **Target Files**:
    - `apps/vhunambi_api/src/routes/playlist_routes.ts` (New)
    - `apps/vhunambi_api/src/server.ts`
  - **Deliverables**:
    1. Implement `GET /`, `GET /:id`, `POST /`, `PUT /:id`, `DELETE /:id`, and `POST /:id/share` in `playlist_routes.ts`.
    2. Mount `app.route('/api/playlists', playlistRoutes)` in `server.ts`.

- [x] **Task `59.1.4` — Unify `wallet_routes.ts` & `social_routes.ts` Payout Gateway**
  - **Target Files**:
    - `apps/vhunambi_api/src/routes/wallet_routes.ts`
    - `apps/vhunambi_api/src/routes/social_routes.ts`
  - **Deliverables**:
    1. Add `GET /api/wallet/banks` and pass `branchCode`, `paymentRail`, and `accountHolder` in `POST /api/wallet/payout`.
    2. Bridge `POST /api/creators/:id/wallet/payout` in `social_routes.ts` to `vhunambiDb.requestPayout` so both endpoints share the SQLite WAL ledger.

---

### Milestone `M59.2`: Explore Discovery Client Serialization & `HttpExploreRepository`

- [x] **Task `59.2.1` — Add `toJson()`, `fromJson()`, and `copyWith()` to `Track`**
  - **Target File**: `apps/vhunambi_client/lib/shared/models/track.dart`
  - **Deliverables**: Complete JSON round-trip support for all 20 `Track` fields and `DiscoveryStage`.

- [x] **Task `59.2.2` — Create `HttpExploreRepository` & Wire `explore_providers.dart`**
  - **Target Files**:
    - `apps/vhunambi_client/lib/features/explore/data/repositories/http_explore_repository.dart` (New)
    - `apps/vhunambi_client/lib/features/explore/presentation/providers/explore_providers.dart`
  - **Deliverables**:
    1. Implement `fetchExploreBundle()`, `fetchExploreTracks()`, `fetchGenreRadio()`, and `publishTrack()`.
    2. Add `refreshFromCloud()` and `publishTrackToCloud()` to `ExploreTracksNotifier`, and expose `exploreGenreRadioProvider`.

---

### Milestone `M59.3`: Library Cloud Delta Sync & Hive Persistence

- [x] **Task `59.3.1` — Add `toJson()`, `fromJson()`, and `updatedAtMs` to `LibraryTrack`**
  - **Target File**: `apps/vhunambi_client/lib/features/library/domain/models/library_models.dart`
  - **Deliverables**: Full JSON serialization preserving core metadata, soft-delete tombstones, and Phase 58 beat license fields.

- [x] **Task `59.3.2` — Create `HttpLibrarySyncRepository` & Upgrade `LibraryTracksNotifier`**
  - **Target Files**:
    - `apps/vhunambi_client/lib/features/library/data/repositories/http_library_sync_repository.dart` (New)
    - `apps/vhunambi_client/lib/features/library/presentation/providers/library_providers.dart`
  - **Deliverables**:
    1. Implement Hive box `'vhunambi_library_tracks_v1'` + in-memory fallback + `mergeTracksLww()` + `syncDelta()` (`POST /api/library/sync`).
    2. Wire `LibraryTracksNotifier` mutations (`addTrack`, `upsertLicensedTrack`, `deleteTrack`, `restoreTrack`, `purgeTrackPermanently`, `toggleFavorite`, `incrementPlayCount`) to persist locally, enqueue `SyncMutationRecord` (`entityType: 'library_track'`), and expose `syncWithCloud()` + `libraryCloudSyncStatusProvider`.

---

### Milestone `M59.4`: Playlists Full-Stack CRUD, Cloud Sharing & Phosphor UI Upgrade

- [x] **Task `59.4.1` — Upgrade `PlaylistEntity`, `IPlaylistRepository`, `PlaylistRepository` & `PlaylistsNotifier`**
  - **Target Files**:
    - `apps/vhunambi_client/lib/features/playlists/domain/models/playlist_entity.dart`
    - `apps/vhunambi_client/lib/features/playlists/domain/repositories/i_playlist_repository.dart`
    - `apps/vhunambi_client/lib/features/playlists/data/repositories/playlist_repository.dart`
    - `apps/vhunambi_client/lib/features/playlists/presentation/providers/playlists_provider.dart`
  - **Deliverables**:
    1. Add `shareCode` and `shareUrl` to `PlaylistEntity`.
    2. Add `syncPlaylistsWithCloud()` and `sharePlaylist(String id)` to `IPlaylistRepository`, `PlaylistRepository`, and `PlaylistsNotifier`.
    3. Wire `SyncOutboxService` (`entityType: 'playlist'`) and optional `Dio` cloud calls into `PlaylistRepository`.

- [x] **Task `59.4.2` — Upgrade `PlaylistsVaultView` to Phosphor Icons & Cloud Sync Action**
  - **Target File**: `apps/vhunambi_client/lib/features/playlists/presentation/views/playlists_vault_view.dart`
  - **Deliverables**:
    1. Replace `Icons.search_rounded`, `Icons.clear_rounded`, and `Icons.add_rounded` with `PhosphorIcon`.
    2. Add Cloud Sync button (`Key('playlists_cloud_sync_btn')`) triggering `ref.read(playlistsProvider.notifier).syncWithCloud()`.

---

### Milestone `M59.5`: SA Banking Gateway Convergence & `EdgeSyncCoordinator` Delta Hydrator

- [x] **Task `59.5.1` — Upgrade `creator_wallet.dart`, `http_social_repository.dart`, `creator_wallet_provider.dart` & `payout_details_sheet.dart`**
  - **Target Files**:
    - `apps/vhunambi_client/lib/features/social/domain/models/creator_wallet.dart`
    - `apps/vhunambi_client/lib/features/social/domain/repositories/i_social_repository.dart`
    - `apps/vhunambi_client/lib/features/social/data/repositories/http_social_repository.dart`
    - `apps/vhunambi_client/lib/features/social/presentation/providers/creator_wallet_provider.dart`
    - `apps/vhunambi_client/lib/features/profile/presentation/widgets/payout_details_sheet.dart`
  - **Deliverables**:
    1. Add `SaBankRegistry` (auto branch lookup) and `PayoutGatewayRail` (`capitec_pay`, `ozow`, `payfast`, `eft`) + `PayoutClearanceReceipt`.
    2. Route `HttpSocialRepository.requestPayout()` to `POST /api/wallet/payout` with fallback to `/api/creators/:id/wallet/payout`.
    3. Auto-fill universal branch codes on bank selection and add Settlement Rail selector pills in `PayoutDetailsSheet`.

- [x] **Task `59.5.2` — Add `registerDeltaHydrator` to `EdgeSyncCoordinator`**
  - **Target File**: `apps/vhunambi_client/lib/core/sync/edge_sync_coordinator.dart`
  - **Deliverables**:
    1. Add `SyncDeltaHydrator` registration and invoke registered hydrators whenever `GET /api/v1/sync/delta` returns non-empty `changes`.

---

### Milestone `M59.6`: Full-Stack Verification, Automated Test Suites & Static Analysis Sign-Off

- [x] **Task `59.6.1` — Author Backend Convergence Test Suite**
  - **Target File**: `apps/vhunambi_api/test/phase59_convergence.test.ts` (New)
  - **Coverage**: `GET /api/explore`, `GET /api/explore/tracks`, `GET /api/explore/radio/:genre`, `GET/POST /api/library/sync`, `GET/POST/PUT/DELETE /api/playlists`, `POST /api/playlists/:id/share`, and `POST /api/wallet/payout` across all 6 SA banks and 4 payment rails.

- [x] **Task `59.6.2` — Author Client Explore & Genre Radio Sync Tests**
  - **Target File**: `apps/vhunambi_client/test/features/explore/phase59_explore_sync_test.dart` (New)

- [x] **Task `59.6.3` — Author Client Library Cloud Delta Sync & `EdgeSyncCoordinator` Hydrator Tests**
  - **Target File**: `apps/vhunambi_client/test/features/library/phase59_library_sync_test.dart` (New)

- [x] **Task `59.6.4` — Author Client Playlists Cloud CRUD & Share Tests**
  - **Target File**: `apps/vhunambi_client/test/features/playlists/phase59_playlist_cloud_sync_test.dart` (New)

- [x] **Task `59.6.5` — Author Client SA Banking & Payout Gateway Tests + Run Full Verification Gate**
  - **Target File**: `apps/vhunambi_client/test/features/social/phase59_wallet_payout_gateway_test.dart` (New)
  - **Verification Commands**:
    1. `dart format --output=none --set-exit-if-changed <all_23_touched_files>` (`0 changed`)
    2. `flutter analyze --no-pub <all_23_touched_files>` (`No issues found!`)
    3. Consolidated `flutter test --no-pub -j 1 <19_phase59_and_regression_suites>` (`172/172 passed`) & `apps/vhunambi_api` `npx tsc --noEmit && npm test` (`17/17 test suites passed`)

---

## 3. 7-Point Anti-Trap Verification Checklist

1. **Package Import Purity**: 100% `package:vhunambi_client/...` imports across all new and edited Dart files.
2. **Phosphor Icon Purity**: Zero `Icons.*` in `playlists_vault_view.dart` or `payout_details_sheet.dart`; strictly `package:phosphor_icons/phosphor_icons.dart`.
3. **Token Purity**: Only valid `AppColors.*` and `AppTypography.*` tokens.
4. **Zero Raw Emojis**: Zero Unicode emoji characters in UI strings, snackbars, or labels.
5. **Riverpod Constructor Discipline**: Explicit constructor dependency injection on all `StateNotifier` classes (`Ref? _ref` optional only).
6. **Hive Unit-Test Resilience**: Both `HttpLibrarySyncRepository` and `PlaylistRepository` gracefully fall back to in-memory maps when Hive boxes are not opened in unit tests.
7. **SA Bank Alias Safety**: Both `'Capitec'` and `'Capitec Bank'`, and both `'ABSA'` and `'Absa Bank'`, pass validation on client and server.

