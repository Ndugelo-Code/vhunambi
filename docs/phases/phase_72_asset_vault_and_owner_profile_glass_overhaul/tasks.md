# Phase 72 — Deterministic Two-Pass Implementation Tasks & Verification Roadmap

**Document ID:** `VHUNAMBI-SPEC-P72-TASKS-V1`  
**Phase:** `72` — Asset Vault (`LibraryView`), Owner Studio Profile (`OwnerProfileView`) Glass Overhaul, `ViewerRole.owner` Parity & Library/Playlist/License Cloud SWR  
**Date:** `2026-11-20`  
**Status:** `COMPLETED (PASS 1 & PASS 2 VERIFIED)`  
**Companion Documents:** [`blueprint.md`](./blueprint.md) · [`requirements.md`](./requirements.md) · [`design.md`](./design.md) · [`memory.md`](./memory.md)

---

## 1. Master Two-Pass Milestone Roadmap & Dependency Graph

```text
+======================================================================================+
| OVERHAUL PASS 1 — BACKEND VAULT SWR (`M72.1`) & CLIENT ASSET VAULT (`M72.2`)         |
| Independent compile boundary: `tsc.cmd --noEmit` + `npm test` (28/28) +              |
| `flutter analyze --no-pub` + Asset Vault / Marketplace / Track tests                 |
+======================================================================================+
   [M72.1] Backend Library, Playlist & Marketplace Multi-Isolate SWR Durability
      |-- Task 1.1: edge_persistence_bridge.ts (4 SWR readers + 5 awaited writers + telemetry)
      |-- Task 1.2: vhunambi_db.ts (1:1 SQLite proxy parity for every new async method)
      |-- Task 1.3: library_routes.ts, playlist_routes.ts, marketplace_routes.ts, server.ts
      |-- Task 1.4: test/phase72_vault_swr_and_licenses.test.ts + package.json (`28/28`)
      v
   [M72.2] Client Asset Vault Glass Overhaul, `ViewerRole.owner` & Buyer Licenses HTTP
      |-- Task 2.1: library_models.dart, library_providers.dart, track_providers.dart
      |-- Task 2.2: IMarketplaceRepository, HttpMarketplaceRepository, marketplace_providers.dart
      |-- Task 2.3: LibraryCoverArt, PlaylistCoverArt, CollectionArtworkPlaceholder,
      |             BeatsVaultView, VaultStorageModal (`VhunambiTrackArtwork` + glass + insets)
      |-- Task 2.4: LibraryView, LibraryAppBar, LibraryTrackTile, LibraryTrackGridCard,
      |             LibraryCategoryRail, LibraryBadges, LibraryEmptyState, TrackActionsSheet,
      |             TrackDetailsModal, PlaylistsVaultView, CollectionsVaultView, vhunambi_top_bar_kit
      v
+======================================================================================+
| OVERHAUL PASS 2 — OWNER STUDIO PROFILE (`M72.3`) & VERIFICATION + SLEEP (`M72.4`)    |
| Depends cleanly on Pass 1 (`LibraryTrack` metadata & `toggleTrackVisibility`)        |
+======================================================================================+
   [M72.3] Owner Studio Profile Glass Overhaul, Light-Mode Contrast & Parity
      |-- Task 3.1: OwnerProfileView (MiniPlayer suppression, Light-Mode contrast, Glass backdrop,
      |             live owner songs + persisted visibility + Cockpit push, Kinetic Posts shelf,
      |             dynamic Reels shelf, 100% private studio tools preserved)
      |-- Task 3.2: PinnedSpotlightCard, OwnerBeatstoreCockpit, CreatorWalletDeck (live 10/10)
      |-- Task 3.3: ReleasesManagerCard, TipHistoryLedger, ProfileReferralCard,
      |             ArtistVoiceShowcaseCard, AvatarCustomizationModal, CreatorAvatar,
      |             CreatorDnaHelixLabSheet, ProfileSettingsDrawer, EditProfileSheet,
      |             PinSongSelectorSheet, StudioAnalyticsConsoleSheet, ErrorBoundary,
      |             ProgressiveListLoader, OfflineIndicator (`STD-UIUX-001` & Light-Mode purge)
      v
   [M72.4] Legacy Test Realignment, Phase 72 Suite, Full Gates & `SLEEP` Consolidation
      |-- Task 4.1: Realign 3 legacy profile test files for `STD-UIUX-001` + live library titles
      |-- Task 4.2: Author test/features/phase72_asset_vault_and_owner_profile_test.dart
      |-- Task 4.3: Run all static/test/grep gates, mark memory.md completed, run consolidate_memory.mjs
```

| Milestone | Pass | Scope | Verification Gate |
| :--- | :---: | :--- | :--- |
| **`M72.1`** | Pass 1 | Backend 12s SWR read/write-through for Library, Playlists, Marketplace & Buyer Licenses | `.\node_modules\.bin\tsc.cmd --noEmit` (`0` errors) + `npm test` (`28/28` suites green) |
| **`M72.2`** | Pass 1 | Asset Vault glass overhaul, `VhunambiTrackArtwork`, `LibraryTrack` owner metadata, live allowance, `EP-P72-BUYER-LICENSES-HTTP` | `flutter analyze --no-pub` (`0` issues) + `test/features/library/` + `test/features/beats/` + `test/features/track/` |
| **`M72.3`** | Pass 2 | `OwnerProfileView` glass overhaul, Light-Mode contrast repair, `MiniPlayerHost` suppression, live owner songs/posts/beatstore/allowance | `flutter analyze --no-pub` (`0` issues) + zero `Icons.` / raw emojis grep |
| **`M72.4`** | Pass 2 | 3 legacy profile test realignments + `phase72_asset_vault_and_owner_profile_test.dart` + `SLEEP` consolidation | All targeted Flutter suites green (`--timeout=60s`) + `consolidate_memory.mjs` |

---

## 2. Pass 1 — Milestone `M72.1`: Backend Multi-Isolate SWR Durability (`apps/vhunambi_api/`)

### Task `1.1` — Extend `EdgeIsolateDatabaseEngine` with Vault/Playlist/Marketplace SWR (`REQ-P72-SWR-01..04`)
- **Target File:** `apps/vhunambi_api/src/db/edge_persistence_bridge.ts`
- **Implementation:** Per `design.md` §1.1:
  - Add row hydrators `hydrateLibraryRows`, `hydratePlaylistRows`, `hydrateMarketplaceAssetRows`, and `hydrateBeatLicenseRows` using `canonicalizeCreatorId(...)`.
  - Add 4 domain-scoped 12s SWR read-through methods (`syncUserLibraryFromCloud`, `syncPlaylistsFromCloud`, `syncBuyerLicensesFromCloud`, `syncMarketplaceFromCloud`) using `withTimeoutResult(..., 3500)` and stamping `domainHydratedAtMs` ONLY when `res.ok === true`.
  - Normalize `creator_id` and `buyer_id` comparisons in `getPlaylists` and `getBeatLicensesByBuyer` via `canonicalizeCreatorId(...)`.
  - Add labeled telemetry tags (`'user_library_sync.delete'`, `'playlists.upsert'`, `'playlists.delete'`, `'beat_licenses.record'`) and expose 5 awaited write-through methods: `syncLibraryDeltaAsync`, `deleteLibraryItemAsync`, `upsertPlaylistAsync`, `deletePlaylistAsync`, `sharePlaylistAsync`.
- **Acceptance Criteria:** Zero `.catch(() => {})` calls introduced; failed/timed-out cloud fetches never seal `domainHydratedAtMs`; legacy `'usr_me'` rows match canonical `'creator_cern'` seamlessly.

### Task `1.2` — Maintain 1:1 `VhunambiDatabase` Proxy Parity (`REQ-P72-SWR-05`)
- **Target File:** `apps/vhunambi_api/src/db/vhunambi_db.ts`
- **Implementation:** Per `design.md` §1.2, add matching method signatures on `VhunambiDatabase` (`syncUserLibraryFromCloud`, `syncPlaylistsFromCloud`, `syncBuyerLicensesFromCloud`, `syncMarketplaceFromCloud`, `syncLibraryDeltaAsync`, `deleteLibraryItemAsync`, `upsertPlaylistAsync`, `deletePlaylistAsync`, `sharePlaylistAsync`) delegating cleanly to synchronous SQLite equivalents.
- **Acceptance Criteria:** `apps/vhunambi_api/node_modules/.bin/tsc.cmd --noEmit` exits `0` with zero TS2339 missing-property errors on `vhunambiDb`.

### Task `1.3` — Wire SWR Routes & Scoped Cold-Start Bypass (`REQ-P72-SWR-06`)
- **Target Files:**
  - `apps/vhunambi_api/src/routes/library_routes.ts`
  - `apps/vhunambi_api/src/routes/playlist_routes.ts`
  - `apps/vhunambi_api/src/routes/marketplace_routes.ts`
  - `apps/vhunambi_api/src/server.ts`
- **Implementation:** Per `design.md` §1.3–§1.6:
  - `library_routes.ts`: await `syncUserLibraryFromCloud` on `GET /` & `GET /sync`; await `syncLibraryDeltaAsync` on `POST /sync`; await `deleteLibraryItemAsync` on `DELETE /:id`.
  - `playlist_routes.ts`: await `syncPlaylistsFromCloud` on `GET /` & `GET /:id`; await `upsertPlaylistAsync`, `deletePlaylistAsync`, and `sharePlaylistAsync` on write endpoints.
  - `marketplace_routes.ts`: await `syncMarketplaceFromCloud` on `GET /beats`, `GET /beats/:id`, `GET /producers/:producerId/beats`, and `GET /licenses/verify/:certificateId`; await `syncBuyerLicensesFromCloud` on `GET /licenses/:buyerId`.
  - `server.ts`: add `/api/library`, `/api/v1/library`, `/api/playlists`, `/api/v1/playlists`, `/api/marketplace`, and `/api/v1/marketplace` to `hasScopedReadThrough`.
- **Acceptance Criteria:** Every library, playlist, and marketplace endpoint bypasses the monolithic 21-table cold-start pull and stays consistent across independent Worker isolates.

### Task `1.4` — Author Cross-Isolate SWR Test Suite & Register in `package.json` (`REQ-P72-SWR-01..06`)
- **Target Files:**
  - `apps/vhunambi_api/test/phase72_vault_swr_and_licenses.test.ts`
  - `apps/vhunambi_api/package.json`
- **Implementation:** Per `design.md` §4.1, write a deterministic mock-`SupabaseCloudDriver` dual-isolate test (`Isolate A` writes -> `Isolate B` reads via SWR) covering:
  1. `user_library_sync` delta upsert + delete propagation across isolates.
  2. `playlists` create + share + canonical `'usr_me'`/`'creator_cern'` resolution across isolates.
  3. `marketplace_assets` + `beat_licenses` (`syncBuyerLicensesFromCloud` & `GET /api/marketplace/licenses/:buyerId`) across isolates.
  4. Timeout/error safety: failed fetch does NOT seal `domainHydratedAtMs`, allowing immediate recovery on the next request.
  - Append `phase72_vault_swr_and_licenses.test.ts` to the `test` script in `apps/vhunambi_api/package.json` (bringing total from `27` to `28`).
- **Acceptance Criteria:** `npm test` in `apps/vhunambi_api/` passes **`28/28`** suites with `0` failures.

---

## 3. Pass 1 — Milestone `M72.2`: Client Asset Vault Glass Overhaul, `ViewerRole.owner` & Buyer Licenses (`apps/vhunambi_client/`)

### Task `2.1` — Enrich `LibraryTrack`, Add `toggleTrackVisibility` & Wire `TrackDetailNotifier` (`REQ-P72-AV-01..02`)
- **Target Files:**
  - `apps/vhunambi_client/lib/features/library/domain/models/library_models.dart`
  - `apps/vhunambi_client/lib/features/library/presentation/providers/library_providers.dart`
  - `apps/vhunambi_client/lib/features/track/presentation/providers/track_providers.dart`
- **Implementation:** Per `design.md` §2.1–§2.3:
  - Add backward-compatible optional fields `creatorId`, `creatorHandle`, `mood`, `moodId`, `bpm`, `description`, `allowOpenStemsRemix`, and `isPublic` (default `true`) to `LibraryTrack` (`toJson`, `fromJson`, `copyWith`, and `toTrack()` preserving `creatorHandle` and `mood`).
  - Annotate `'cern'` starter tracks in `LibraryTracksNotifier` with `creatorId: 'creator_cern'`, `creatorHandle: '@cern'`, canonical `VhunambiMood` `moodId`, and `bpm`.
  - Add `LibraryTracksNotifier.toggleTrackVisibility(String trackId)` updating Hive + state + sync outbox (`isPublic`).
  - Update `TrackDetailNotifier._lookupInitialTrack` to read `lt.creatorId`, `lt.creatorHandle`, `VhunambiMood.normalize(lt.moodId ?? lt.mood)`, `lt.bpm`, `lt.description`, and `lt.allowOpenStemsRemix` directly so owned vault tracks deterministically resolve `ViewerRole.owner`.
- **Acceptance Criteria:** Tapping any owned vault track opens `TrackDetailView` with `ViewerRole.owner` regardless of display-name casing or edits.

### Task `2.2` — Wire Buyer Licenses HTTP Sync (`EP-P72-BUYER-LICENSES-HTTP`, `REQ-P72-AV-08`)
- **Target Files:**
  - `apps/vhunambi_client/lib/features/marketplace/domain/repositories/i_marketplace_repository.dart`
  - `apps/vhunambi_client/lib/features/marketplace/data/repositories/http_marketplace_repository.dart`
  - `apps/vhunambi_client/lib/features/marketplace/presentation/providers/marketplace_providers.dart`
- **Implementation:** Per `design.md` §2.4:
  - Add `Future<List<SovereignLicenseCertificate>> getBuyerLicenses(String buyerId)` to `IMarketplaceRepository` and implement `GET /api/marketplace/licenses/$buyerId` in `HttpMarketplaceRepository` (returning `[]` when `_shouldSkipNetwork` is true for headless widget tests, parsing both `{licenses: [...]}` and raw list payloads via `SovereignLicenseCertificate.fromJson`).
  - Expose `buyerLicensesFamilyProvider = FutureProvider.family<List<SovereignLicenseCertificate>, String>(...)` in `marketplace_providers.dart`.
- **Acceptance Criteria:** `HttpMarketplaceRepository.getBuyerLicenses` cleanly parses live Worker responses in a plain `test()` with mock `Dio` adapter and never hangs in headless widget tests.

### Task `2.3` — Migrate Vault Artwork & Embedded Vault Sub-Views (`REQ-P72-AV-03`, `REQ-P72-AV-08..09`, `REQ-P72-NFR-01..02`)
- **Target Files:**
  - `apps/vhunambi_client/lib/features/library/presentation/widgets/library_cover_art.dart`
  - `apps/vhunambi_client/lib/features/playlists/presentation/widgets/playlist_cover_art.dart`
  - `apps/vhunambi_client/lib/features/playlists/presentation/views/playlists_vault_view.dart`
  - `apps/vhunambi_client/lib/features/collections/presentation/widgets/collection_artwork_placeholder.dart`
  - `apps/vhunambi_client/lib/features/collections/presentation/views/collections_vault_view.dart`
  - `apps/vhunambi_client/lib/features/beats/presentation/views/beats_vault_view.dart`
  - `apps/vhunambi_client/lib/features/offline/presentation/widgets/vault_storage_modal.dart`
- **Implementation:** Per `design.md` §2.5–§2.6:
  - Replace broken `CachedNetworkImage('asset:...')` and flat `AppGradients.forGenre` fallback boxes in `LibraryCoverArt`, `PlaylistCoverArt`, `CollectionArtworkPlaceholder`, `BeatsVaultView`, and `VaultStorageModal` with `VhunambiTrackArtwork` (`EP-P68-TRACK-ARTWORK`).
  - Wrap repeating playlist, collection, beat, and storage cards in `VhunambiGlassSurface(enableLiveBlur: false)` with zero `Icons.*` and zero raw emojis.
  - Hydrate `buyerLicensesFamilyProvider(currentCreatorId)` into `BeatsVaultView`'s `Licensed Beats` tab (`Key('beats_vault_mode_licensed')`), merging remote certificates cleanly with local vault records.
  - Replace hardcoded `110` / `AppSpacing.md` bottom paddings in `PlaylistsVaultView`, `CollectionsVaultView`, and `BeatsVaultView` with `VhunambiBottomDockMetrics.scrollInset(hasActiveTrack: ref.watch(currentTrackProvider) != null)`.
- **Acceptance Criteria:** Every seeded `'asset:...'` cover renders its bundled artwork PNG with zero HTTP decode failures; `beats_vault_view_test.dart` passes; zero `Icons.*` remain.

### Task `2.4` — Overhaul `LibraryView`, `LibraryAppBar`, Tiles, Sheets & Top-Bar Coin Chip (`REQ-P72-AV-04..07`, `REQ-P72-AV-09`, `REQ-P72-NFR-01..02`)
- **Target Files:**
  - `apps/vhunambi_client/lib/features/library/presentation/views/library_view.dart`
  - `apps/vhunambi_client/lib/features/library/presentation/widgets/library_app_bar.dart`
  - `apps/vhunambi_client/lib/features/library/presentation/widgets/library_track_tile.dart`
  - `apps/vhunambi_client/lib/features/library/presentation/widgets/library_track_grid_card.dart`
  - `apps/vhunambi_client/lib/features/library/presentation/widgets/library_category_rail.dart`
  - `apps/vhunambi_client/lib/features/library/presentation/widgets/library_badges.dart`
  - `apps/vhunambi_client/lib/features/library/presentation/widgets/library_empty_state.dart`
  - `apps/vhunambi_client/lib/features/library/presentation/widgets/track_actions_sheet.dart`
  - `apps/vhunambi_client/lib/features/library/presentation/widgets/track_details_modal.dart`
  - `apps/vhunambi_client/lib/core/design_system/components/vhunambi_top_bar_kit.dart`
- **Implementation:** Per `design.md` §2.7–§2.10:
  - Wrap `LibraryView` body in `VhunambiAmbientMeshBackdrop`; trigger non-blocking `libraryTracksProvider.notifier.syncWithCloud()` on mount (only when authenticated and not in test skip mode) + `RefreshIndicator` + compact `libraryCloudSyncStatusProvider` badge (`Key('library_cloud_sync_badge')`).
  - Upgrade `LibraryAppBar` with `_AllowanceBalancePill` (`Key('library_allowance_chip')`) watching `creatorAllowanceProvider`, rendering `'${allowance.freeMonthlySongsRemaining} songs left'` (or `'Pro Unlimited'`) using `PhosphorIconsFill.musicNotes` — **CRITICAL:** DO NOT use `PhosphorIconsRegular.sparkle` in `_AllowanceBalancePill` because `library_view_test.dart#L79` asserts `find.byIcon(PhosphorIconsRegular.sparkle)` equals `findsOneWidget` on mobile!
  - Surface `_CachedOnlyFilterPill` (`Key('vault_filter_cached_only')`) visibly on mobile (`< 768dp`) without `RenderFlex` overflow at `360x800dp`, add clearable search (`Key('vault_search_clear_btn')`) with `onTapOutside` keyboard dismissal, and display merged remote buyer licenses under `LibraryCategory.licensing`.
  - Upgrade `LibraryTrackTile` & `LibraryTrackGridCard` onto `VhunambiGlassSurface(enableLiveBlur: false)` with `>= 44x44dp` touch targets (`ConstrainedBox(minWidth: 44, minHeight: 44)`) and replace all `Icons.*` with Phosphor icons.
  - Upgrade `TrackActionsSheet` to replace the `handleStemSeparation` `SnackBar` dead-end with **"Open Song Cockpit & Stems"** (`Key('track_action_open_cockpit')`) pushing `TrackDetailView(trackId: track.id)` under `ViewerRole.owner`, preserve `Song Details` (`TrackDetailsModal`), and replace legacy `https://r2.vhunambi.com/...` defaults with `AppAssets.resolveGenreCoverAsset(...)`.
  - Enforce `>= 44dp` tap height on `VhunambiUserCoinsChip` in `vhunambi_top_bar_kit.dart`.
- **Acceptance Criteria:** `flutter analyze --no-pub` (`0` issues); `library_view_test.dart` passes unchanged (`'10 songs left'` + single `PhosphorIconsRegular.sparkle` on mobile preserved); zero `Icons.` or raw emojis across `features/library/`.

---

## 4. Pass 2 — Milestone `M72.3`: Owner Studio Profile Glass Overhaul & Parity (`apps/vhunambi_client/lib/features/profile/`)

### Task `3.1` — Overhaul `OwnerProfileView` (`REQ-P72-OP-01..04`, `REQ-P72-OP-06`, `REQ-P72-NFR-01..02`)
- **Target File:** `apps/vhunambi_client/lib/features/profile/presentation/views/owner_profile_view.dart`
- **Implementation:** Per `design.md` §3.1:
  - Increment `pushedFullScreenOverlayCountProvider` via post-frame callback in `initState()` and decrement via guarded `Future.microtask` in `dispose()` (matching `ArtistProfileView#L59-L80`) so `MiniPlayerHost` never overlaps `OwnerProfileView`.
  - Wrap body in `VhunambiAmbientMeshBackdrop` and migrate hero card, studio tabs, track rows, DNA card container, and sheets to `VhunambiGlassSurface(enableLiveBlur: false)` using `AppColors.*Of(context)` (NOTE: `AppColors` has NO `textTertiaryOf(context)` — use `AppColors.textSecondaryOf(context)`).
  - Fix every Light-Mode contrast defect (`VhunambiBackButton`, `Key('owner_header_settings_btn')`, genre `ChoiceChip`s, groove edit button — zero hardcoded `Colors.white` / `Colors.white70` on light surfaces).
  - Replace hardcoded `track_own_01`/`track_own_02` `"Your Songs"` list and ephemeral `_trackVisibility` map with a live projection of non-deleted vocal tracks owned by the active creator from `libraryTracksProvider` (with starter fallback owned by `profile.id` if empty). Wire `Key('owner_song_tile_${track.id}')` -> `TrackDetailView(trackId: track.id)` (`ViewerRole.owner`), `Key('owner_song_visibility_${track.id}')` -> `libraryTracksProvider.notifier.toggleTrackVisibility(track.id)`, and `>= 44x44dp` inline Play button -> `track.toTrack()`.
  - Scope `_OwnerReelsShelf` dynamically via `creatorClipsFamilyProvider(currentCreatorId)` instead of hardcoded `'creator_me'`.
  - Add `_OwnerKineticPostsShelf` (`Key('owner_kinetic_posts_section')`) watching `socialFeedPostsProvider` filtered by canonical owner ID, pushing `KineticPostFocusView(postId: post.id, initialPost: post)` on tap.
  - Preserve **100%** of private Owner Studio tools (`DAW / Vocal Upload`, `Change Avatar`, `Edit Profile`, `Pin Song`, `Studio Analytics`, `Settings`, `CreatorDnaProfileCard(isOwner: true)`, `ArtistVoiceShowcaseCard`, `MelodySketchpadModal`, `OwnerBeatstoreCockpit`, `ReleasesManagerCard`, `CreatorWalletDeck`, `CrossModuleSynergyDeck`, `TipHistoryLedger`, `ProfileReferralCard`).
  - Purge every raw Unicode emoji and stock `Icons.*` from `owner_profile_view.dart`.
- **Acceptance Criteria:** Zero white-on-white contrast traps in Light Mode; `MiniPlayerHost` suppressed while open; 100% owner studio controls intact; live songs & visibility persist cleanly.

### Task `3.2` — Upgrade `PinnedSpotlightCard`, `OwnerBeatstoreCockpit` & `CreatorWalletDeck` (`REQ-P72-OP-05..07`, `REQ-P72-NFR-01..02`)
- **Target Files:**
  - `apps/vhunambi_client/lib/features/profile/presentation/widgets/pinned_spotlight_card.dart`
  - `apps/vhunambi_client/lib/features/profile/presentation/widgets/owner_beatstore_cockpit.dart`
  - `apps/vhunambi_client/lib/features/profile/presentation/widgets/creator_wallet_deck.dart`
- **Implementation:** Per `design.md` §3.2–§3.4:
  - `PinnedSpotlightCard`: migrate cover art to `VhunambiTrackArtwork`, normalize audio URL via `AppConstants.normalizeCloudMediaUrl`, wrap in `VhunambiGlassSurface`, and push `TrackDetailView(trackId: pinnedTrackId!)` on tap.
  - `OwnerBeatstoreCockpit`: watch `currentCreatorIdProvider` instead of hardcoded `'creator_ndugelo'`; migrate cards to `VhunambiGlassSurface(enableLiveBlur: false)` and Phosphor icons.
  - `CreatorWalletDeck`: embed glass **Monthly Free Songs Allowance** card (`Key('wallet_monthly_allowance_card')`) watching `creatorAllowanceProvider` (`'${allowance.freeMonthlySongsRemaining}/${allowance.freeMonthlySongsLimit} free songs left'` or `'Pro Unlimited'`, opening `SubscriptionUpgradeModal.show(context)` on tap), replace raw coin/medal emojis (`'4,750 🪙'` -> Phosphor coin icon + `'4,750'`), and adopt `AppColors.*Of(context)` + `VhunambiGlassSurface`.
- **Acceptance Criteria:** `PinnedSpotlightCard` renders `'asset:'` covers cleanly and navigates to `TrackDetailView`; Beatstore dynamically tracks active creator; Wallet shows live `10/10` free song allowance alongside ZAR earnings.

### Task `3.3` — Complete `STD-UIUX-001` & Light-Mode Glass Alignment Across Supporting Profile Widgets (`REQ-P72-OP-01`, `REQ-P72-NFR-01..02`)
- **Target Files:**
  - `apps/vhunambi_client/lib/features/profile/presentation/widgets/releases_manager_card.dart`
  - `apps/vhunambi_client/lib/features/profile/presentation/widgets/tip_history_ledger.dart`
  - `apps/vhunambi_client/lib/features/profile/presentation/widgets/profile_referral_card.dart`
  - `apps/vhunambi_client/lib/features/profile/presentation/widgets/artist_voice_showcase_card.dart`
  - `apps/vhunambi_client/lib/features/profile/presentation/widgets/avatar_customization_modal.dart`
  - `apps/vhunambi_client/lib/features/profile/presentation/widgets/creator_avatar.dart`
  - `apps/vhunambi_client/lib/features/profile/presentation/widgets/creator_dna_helix_lab_sheet.dart`
  - `apps/vhunambi_client/lib/features/profile/presentation/widgets/profile_settings_drawer.dart`
  - `apps/vhunambi_client/lib/features/profile/presentation/widgets/edit_profile_sheet.dart`
  - `apps/vhunambi_client/lib/features/profile/presentation/widgets/pin_song_selector_sheet.dart`
  - `apps/vhunambi_client/lib/features/profile/presentation/widgets/studio_analytics_console_sheet.dart`
  - `apps/vhunambi_client/lib/features/profile/presentation/widgets/error_boundary.dart`
  - `apps/vhunambi_client/lib/features/profile/presentation/widgets/progressive_list_loader.dart`
  - `apps/vhunambi_client/lib/features/profile/presentation/widgets/offline_indicator.dart`
- **Implementation:** Per `design.md` §3.5:
  - Replace every remaining `Icons.*` and raw Unicode emoji with Phosphor icons (`AppIcons.*` / `PhosphorIconsRegular.*` / `PhosphorIconsFill.*`).
  - Replace hardcoded `Colors.white` / `Color(0x...)` and static `AppColors.surfaceElevated`/`textPrimary`/`textSecondary`/`borderSubtle` with `AppColors.*Of(context)` and `VhunambiGlassSurface(enableLiveBlur: false)`.
  - Ensure `AvatarCustomizationModal` renders `'Cultural AI'` paired with a Phosphor sparkle icon instead of raw `'Cultural AI ✨'`.
- **Acceptance Criteria:** Static regex scan confirms **`0`** `Icons.` and **`0`** raw emojis across the entire `lib/features/profile/` directory.

---

## 5. Pass 2 — Milestone `M72.4`: Test Realignments, Phase 72 Suite & `SLEEP` Consolidation

### Task `4.1` — Realign 3 Legacy Profile Test Files (`REQ-P72-NFR-01`, `REQ-P72-NFR-03`)
- **Target Files:**
  - `apps/vhunambi_client/test/features/profile/owner_profile_view_test.dart`
  - `apps/vhunambi_client/test/features/profile/creator_wallet_deck_test.dart`
  - `apps/vhunambi_client/test/features/profile/avatar_customization_modal_test.dart`
- **Implementation:** Update ONLY the purged raw-emoji & hardcoded-track legacy assertions:
  - `owner_profile_view_test.dart`: `'🎵 House (1)'` -> `'House (1)'`, `'🎹 Amapiano (4)'` -> `'Amapiano (4)'`, `'ZaYN'` -> `'Grateful in the Light'`, `'🌐 Public'` -> `'Public'`, `'🔒 Private'` -> `'Private'`.
  - `creator_wallet_deck_test.dart`: `'4,750 🪙'` -> `'4,750'` (paired with Phosphor coin icon assertion).
  - `avatar_customization_modal_test.dart`: `'Cultural AI ✨'` -> `'Cultural AI'`.
- **Acceptance Criteria:** All 3 files plus `phase30_creator_profile_convergence_test.dart` pass cleanly under `--timeout=60s`.

### Task `4.2` — Author Comprehensive Phase 72 Client Verification Suite (`REQ-P72-AV-01..09`, `REQ-P72-OP-01..07`)
- **Target File:** `apps/vhunambi_client/test/features/phase72_asset_vault_and_owner_profile_test.dart`
- **Implementation:** Per `design.md` §4.2, verify:
  1. `LibraryTrack` preserves `creatorId`, `creatorHandle`, `moodId`, `bpm`, `description`, `allowOpenStemsRemix`, `isPublic`, and resolves `ViewerRole.owner` inside `TrackDetailNotifier` / `TrackDetailView`.
  2. `LibraryCoverArt` & `PlaylistCoverArt` render `'asset:...'` covers through `VhunambiTrackArtwork` (zero `CachedNetworkImage` calls for local assets).
  3. Mobile `LibraryView` (`360x800dp`) exposes `Key('vault_filter_cached_only')`, `Key('library_allowance_chip')` showing live `creatorAllowanceProvider`, clearable search (`Key('vault_search_clear_btn')`), and zero `RenderFlex` overflow.
  4. `TrackActionsSheet` exposes `Key('track_action_open_cockpit')` and pushes `TrackDetailView`.
  5. Plain `test()` (outside `FakeAsync`): `HttpMarketplaceRepository.getBuyerLicenses('creator_cern')` hits `GET /api/marketplace/licenses/creator_cern` and parses `SovereignLicenseCertificate` rows cleanly.
  6. `OwnerProfileView` increments `pushedFullScreenOverlayCountProvider` on mount and decrements on dispose, renders cleanly in **both Light Mode (`Brightness.light`) and Dark Mode (`Brightness.dark`)**, displays live `libraryTracksProvider` songs, persists visibility toggles across rebuilds, mounts `Key('owner_kinetic_posts_section')` -> `KineticPostFocusView`, and renders `Key('wallet_monthly_allowance_card')` with live `10/10` free song allowance.
- **Acceptance Criteria:** Every test in `phase72_asset_vault_and_owner_profile_test.dart` passes under `flutter test --no-pub --timeout=60s`.

### Task `4.3` — Final Verification Gates & `vhunambi-memory` `SLEEP` Consolidation
- **Target Files:**
  - `docs/phases/phase_72_asset_vault_and_owner_profile_glass_overhaul/memory.md`
  - `docs/memory/CORTEX_INDEX.md` (auto-updated by `consolidate_memory.mjs`)
  - `docs/memory/CONNECTOME_GRAPH.json` (auto-updated by `consolidate_memory.mjs`)
- **Implementation:**
  1. Execute all verification commands in §7 below and confirm `0` errors / `0` analyzer issues / `0` static `Icons.` or raw emoji violations.
  2. Update `docs/phases/phase_72_asset_vault_and_owner_profile_glass_overhaul/memory.md`: set `"status": "completed"`, `"completed_at": "<YYYY-MM-DD>"`, and record verified test counts.
  3. Run `node .agents/skills/vhunambi-memory/scripts/consolidate_memory.mjs` and confirm `EP-P72-VAULT-CLOUD-SWR` and `EP-P72-BUYER-LICENSES-HTTP` are registered in `CONNECTOME_GRAPH.json`.

---

## 6. Anti-Trap Execution Checklist (Stage 4 Executor Guardrails)

- [x] **Trap 1 (`library_view_test.dart:79` Single Sparkle Icon Guard):** `_AllowanceBalancePill` (`Key('library_allowance_chip')`) uses `PhosphorIconsFill.musicNotes` (NOT `PhosphorIconsRegular.sparkle`) and formats label `'${allowance.freeMonthlySongsRemaining} songs left'` so existing `library_view_test.dart#L39, #L73, #L79` stays 100% green without edits.
- [x] **Trap 2 (`AppColors` Missing `textTertiaryOf`):** `AppColors` defines `surfaceElevatedOf`, `surfaceSecondaryOf`, `surfaceModalOf`, `borderSubtleOf`, `textPrimaryOf`, and `textSecondaryOf` ONLY — never call `AppColors.textTertiaryOf(context)`.
- [x] **Trap 3 (60 FPS Android Budget):** Every `VhunambiGlassSurface` inside a `ListView`, `GridView`, `Wrap`, or repeating studio card sets `enableLiveBlur: false` (zero `BackdropFilter` inside scroll builders).
- [x] **Trap 4 (`VhunambiDatabase` TS Parity):** Every async method added to `EdgeIsolateDatabaseEngine` has an identical method signature on `VhunambiDatabase` (`vhunambi_db.ts`) verified via `.\node_modules\.bin\tsc.cmd --noEmit`.
- [x] **Trap 5 (SWR Poisoning):** `syncUserLibraryFromCloud`, `syncPlaylistsFromCloud`, `syncBuyerLicensesFromCloud`, and `syncMarketplaceFromCloud` NEVER stamp `domainHydratedAtMs` when `res.ok === false` or on timeout.
- [x] **Trap 6 (`Dio` Inside `FakeAsync`):** `HttpMarketplaceRepository.getBuyerLicenses` unit test runs in plain `test()`, NOT `testWidgets()`, and production `HttpMarketplaceRepository` checks `_shouldSkipNetwork` so headless widget tests never hang.
- [x] **Trap 7 (MiniPlayer Lifecycle Safety):** `OwnerProfileView` decrements `pushedFullScreenOverlayCountProvider` via guarded `Future.microtask` in `dispose()` only if it incremented in `initState()`.
- [x] **Trap 8 (`STD-UIUX-001` Total Purge):** Zero `Icons.` and zero raw Unicode emojis remain anywhere in Phase 72 touched files (`features/library/`, `features/playlists/`, `features/collections/`, `features/beats/`, `features/offline/`, `features/profile/`).
- [x] **Trap 9 (Windows PowerShell CLI Safety):** Run `.\node_modules\.bin\tsc.cmd --noEmit` directly (never `npx tsc`, which can hang on Windows PowerShell).
- [x] **Trap 10 (100% Owner Feature Preservation):** Do NOT strip or hide `CreatorDnaHelixLabSheet`, `ArtistVoiceShowcaseCard`, `MelodySketchpadModal`, `OwnerBeatstoreCockpit`, `ReleasesManagerCard`, `CreatorWalletDeck`, `StudioAnalyticsConsoleSheet`, `EditProfileSheet`, `PinSongSelectorSheet`, `ProfileSettingsDrawer`, `TipHistoryLedger`, or `ProfileReferralCard` when harmonizing `OwnerProfileView`.

---

## 7. Exact Verification Commands (Windows PowerShell)

```powershell
# 1. Pass 1 Backend Typecheck & Full Test Suite (28/28)
Push-Location apps\vhunambi_api
.\node_modules\.bin\tsc.cmd --noEmit
npm test
Pop-Location

# 2. Pass 1 & Pass 2 Static Analysis (0 issues)
Push-Location apps\vhunambi_client
flutter analyze --no-pub

# 3. Pass 1 Asset Vault, Beats, Marketplace & Track Suites
flutter test --no-pub --timeout=60s `
  test\features\library\ `
  test\features\beats\ `
  test\features\track\

# 4. Pass 2 Owner Profile & Phase 72 Verification Suite
flutter test --no-pub --timeout=60s `
  test\features\profile\ `
  test\features\phase72_asset_vault_and_owner_profile_test.dart
Pop-Location

# 5. STD-UIUX-001 Static Hygiene Audit (must return 0 matches for Icons.)
Select-String -Path `
  "apps\vhunambi_client\lib\features\library\**\*.dart", `
  "apps\vhunambi_client\lib\features\playlists\**\*.dart", `
  "apps\vhunambi_client\lib\features\collections\**\*.dart", `
  "apps\vhunambi_client\lib\features\beats\**\*.dart", `
  "apps\vhunambi_client\lib\features\offline\**\*.dart", `
  "apps\vhunambi_client\lib\features\profile\**\*.dart" `
  -Pattern '\bIcons\.'

# 6. SLEEP — Consolidate Vhunambi Codebase Brain (ONLY after ALL gates above pass)
node .agents\skills\vhunambi-memory\scripts\consolidate_memory.mjs
```
