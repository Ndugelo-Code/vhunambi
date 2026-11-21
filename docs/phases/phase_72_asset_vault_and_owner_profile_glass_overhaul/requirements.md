# Phase 72 — Asset Vault (`LibraryView`), Owner Studio Profile (`OwnerProfileView`) Glass Overhaul, `ViewerRole.owner` Parity & Library/Playlist/License Cloud SWR — Requirements Specification

**Document ID:** `VHUNAMBI-SPEC-P72-REQUIREMENTS-V1`  
**Date:** 2026-11-20  
**Target Branch:** `fix/studio-cockpit-bugs-vh001-vh006`  
**Normative Keywords:** RFC 2119 (`SHALL`, `MUST`, `MUST NOT`, `SHOULD`) and EARS (`WHEN`, `WHILE`, `IF ... THEN`, `WHERE`).

---

## 1. Document Scope & Cross-Stack Invariants

This specification defines every functional, UI/UX (`STD-UIUX-001`), multi-isolate cloud persistence, and testability requirement for Phase 72 across:
- **Backend (`apps/vhunambi_api/`):** `edge_persistence_bridge.ts`, `vhunambi_db.ts`, `library_routes.ts`, `playlist_routes.ts`, `marketplace_routes.ts`, `server.ts`, `package.json`, and `test/phase72_vault_swr_and_licenses.test.ts`.
- **Client Asset Vault (`apps/vhunambi_client/lib/features/{library,playlists,collections,beats,offline,marketplace,track}/`):** `LibraryTrack`, `LibraryTracksNotifier`, `LibraryView`, `LibraryAppBar`, `LibraryCoverArt`, `LibraryTrackTile`, `LibraryTrackGridCard`, `LibraryCategoryRail`, `LibraryBadges`, `LibraryEmptyState`, `TrackActionsSheet`, `TrackDetailsModal`, `PlaylistCoverArt`, `PlaylistsVaultView`, `CollectionArtworkPlaceholder`, `CollectionsVaultView`, `BeatsVaultView`, `VaultStorageModal`, `IMarketplaceRepository`, `HttpMarketplaceRepository`, `marketplace_providers.dart`, `track_providers.dart`, and `vhunambi_top_bar_kit.dart`.
- **Client Owner Studio Profile (`apps/vhunambi_client/lib/features/profile/`):** `OwnerProfileView`, `PinnedSpotlightCard`, `OwnerBeatstoreCockpit`, `CreatorWalletDeck`, `ReleasesManagerCard`, `TipHistoryLedger`, `ProfileReferralCard`, `ArtistVoiceShowcaseCard`, `AvatarCustomizationModal`, `CreatorAvatar`, `CreatorDnaHelixLabSheet`, `ProfileSettingsDrawer`, `EditProfileSheet`, `PinSongSelectorSheet`, `StudioAnalyticsConsoleSheet`, `ErrorBoundary`, `ProgressiveListLoader`, and `OfflineIndicator`.

---

## 2. Backend Domain-Scoped SWR Durability Requirements (`M72.1`)

- **`REQ-P72-SWR-01` (User Library SWR Read-Through):** `EdgeIsolateDatabaseEngine` SHALL provide `syncUserLibraryFromCloud(creatorId: string, cOrEnv?: unknown): Promise<any[]>` using domain key ``library:${cid}`` and `DEFAULT_SWR_TTL_MS = 12_000`. It SHALL query `user_library_sync` scoped by `creator_id=eq.${cid}` inside `withTimeoutResult(..., 3500)`, hydrate rows into `this.libraryItems`, and stamp `domainHydratedAtMs` ONLY when `res.ok === true`.
- **`REQ-P72-SWR-02` (Playlists SWR Read-Through & Canonical Creator IDs):** `EdgeIsolateDatabaseEngine` SHALL provide `syncPlaylistsFromCloud(creatorId?: string, cOrEnv?: unknown): Promise<boolean>` using domain key ``playlists:${cid || 'public'}`` (12s TTL). Both cold-start hydration and `syncPlaylistsFromCloud` SHALL normalize `creator_id` via `canonicalizeCreatorId(...)`, and `getPlaylists(creatorId, includePublic)` SHALL compare canonicalized IDs so legacy `'usr_me'` rows match `'creator_cern'`.
- **`REQ-P72-SWR-03` (Buyer Licenses & Marketplace SWR Read-Through):** `EdgeIsolateDatabaseEngine` SHALL provide `syncBuyerLicensesFromCloud(buyerId: string, cOrEnv?: unknown): Promise<any[]>` (domain key ``licenses:${cid}``) and `syncMarketplaceFromCloud(force = false, cOrEnv?: unknown): Promise<boolean>` (domain key `'marketplace:global'`). `getBeatLicensesByBuyer(buyerId)` SHALL compare `canonicalizeCreatorId(String(r.buyer_id)) === canonicalizeCreatorId(buyerId)`.
- **`REQ-P72-SWR-04` (Awaited Critical Writes & Labeled Telemetry):** Every Supabase write-through in `deleteLibraryItem`, `upsertPlaylist`, `deletePlaylist`, and `recordBeatLicenseAtomic` SHALL carry an explicit telemetry label (`'user_library_sync.delete'`, `'playlists.upsert'`, `'playlists.delete'`, `'beat_licenses.record'`). `EdgeIsolateDatabaseEngine` SHALL expose `syncLibraryDeltaAsync`, `deleteLibraryItemAsync`, `upsertPlaylistAsync`, `deletePlaylistAsync`, and `sharePlaylistAsync` so Worker routes await critical Supabase persistence before returning `200`/`201`.
- **`REQ-P72-SWR-05` (`VhunambiDatabase` Proxy Parity):** Every new async method added to `EdgeIsolateDatabaseEngine` SHALL have a signature-compatible counterpart on `VhunambiDatabase` (`apps/vhunambi_api/src/db/vhunambi_db.ts`) delegating to the synchronous SQLite engine so `tsc --noEmit` exits `0`.
- **`REQ-P72-SWR-06` (Route Wiring & Scoped Cold-Start Bypass):**
  - `library_routes.ts` (`GET /`, `GET /sync`, `POST /sync`, `DELETE /:id`) SHALL await `syncUserLibraryFromCloud` (and `syncLibraryDeltaAsync` / `deleteLibraryItemAsync`).
  - `playlist_routes.ts` (`GET /`, `GET /:id`, `POST /`, `PUT /:id`, `DELETE /:id`, `POST /:id/share`) SHALL await `syncPlaylistsFromCloud` (and `*Async` write helpers).
  - `marketplace_routes.ts` (`GET /beats`, `GET /beats/:id`, `GET /producers/:producerId/beats`, `GET /licenses/:buyerId`, `GET /licenses/verify/:certificateId`) SHALL await `syncMarketplaceFromCloud` or `syncBuyerLicensesFromCloud`.
  - `server.ts` SHALL include `/api/library`, `/api/v1/library`, `/api/playlists`, `/api/v1/playlists`, `/api/marketplace`, and `/api/v1/marketplace` in `hasScopedReadThrough`.

---

## 3. Asset Vault Functional, Artwork & `ViewerRole.owner` Requirements (`M72.2`)

- **`REQ-P72-AV-01` (`LibraryTrack` Metadata & `ViewerRole.owner` Fidelity):** `LibraryTrack` (`library_models.dart`) SHALL add backward-compatible optional fields `creatorId`, `creatorHandle`, `mood`, `moodId`, `bpm`, `description`, `allowOpenStemsRemix`, and `isPublic` (default `true`), serialized in `toJson`/`fromJson`/`copyWith` and preserved in `toTrack()`. Starter tracks owned by `'cern'` SHALL carry `creatorId: 'creator_cern'`, `creatorHandle: '@cern'`, canonical `VhunambiMood` `moodId`, and `bpm`.
- **`REQ-P72-AV-02` (`TrackDetailNotifier` Direct Library Hydration):** WHEN `TrackDetailNotifier._lookupInitialTrack` resolves a `LibraryTrack`, it SHALL use `lt.creatorId` (when non-empty), `lt.creatorHandle`, `VhunambiMood.normalize(lt.moodId ?? lt.mood)`, `lt.bpm` (falling back to `_defaultBpmForGenre(lt.genre)`), `lt.description`, and `lt.allowOpenStemsRemix` so owned library songs deterministically resolve `ViewerRole.owner`.
- **`REQ-P72-AV-03` (`VhunambiTrackArtwork` Across All Vault Sub-Views):** `LibraryCoverArt`, `PlaylistCoverArt`, `CollectionArtworkPlaceholder`, `BeatsVaultView` licensed beat cards, and `VaultStorageModal` rows SHALL render covers via `VhunambiTrackArtwork` (`EP-P68-TRACK-ARTWORK`), eliminating broken `CachedNetworkImage('asset:...')` requests and flat `AppGradients.forGenre` fallback boxes.
- **`REQ-P72-AV-04` (Glass Surface Architecture & 60 FPS Android Guardrail):** `LibraryView` SHALL wrap its body in `VhunambiAmbientMeshBackdrop` and render search bars, rails, tiles, grid cards, and sheets using `VhunambiGlassSurface` (`EP-P70-GLASS-SURFACE`) with **`enableLiveBlur: false`** on all repeating list/grid items.
- **`REQ-P72-AV-05` (Non-Blocking Vault Cloud Sync & Live Allowance):**
  - `LibraryView` SHALL trigger a non-blocking `libraryTracksProvider.notifier.syncWithCloud()` on mount (ONLY when authenticated and not in headless test skip mode) and expose pull-to-refresh (`RefreshIndicator`) + a compact `libraryCloudSyncStatusProvider` indicator badge (`Key('library_cloud_sync_badge')`).
  - `LibraryAppBar` SHALL remove the dead unused `'10 songs left'` static constant and surface live `creatorAllowanceProvider` (`EP-P68-CREATOR-ALLOWANCE`) with label `'${allowance.freeMonthlySongsRemaining} songs left'` (or `'Pro Unlimited'` when `isPaidUnlimited`) inside `Key('library_allowance_chip')`, opening `SubscriptionUpgradeModal.show(context)` on tap, while preserving `find.byIcon(PhosphorIconsRegular.sparkle)` == `1` on mobile (`library_view_test.dart#L79`).
- **`REQ-P72-AV-06` (Mobile `Cached Only` Ergonomics & Clearable Search):** `_CachedOnlyFilterPill` (`Key('vault_filter_cached_only')`) SHALL be visibly accessible on mobile (`< 768dp`) without `RenderFlex` overflow at `360x800dp`. The vault search `TextField` SHALL provide a clear icon button (`Key('vault_search_clear_btn')`) when non-empty and dismiss the keyboard via `onTapOutside`.
- **`REQ-P72-AV-07` (`TrackActionsSheet` Cockpit Navigation & Dead-End Removal):** `TrackActionsSheet` SHALL replace the `handleStemSeparation` `SnackBar` dead-end with **"Open Song Cockpit & Stems"** (`Key('track_action_open_cockpit')`) pushing `TrackDetailView(trackId: track.id)` under `ViewerRole.owner`, keep `Song Details` (`TrackDetailsModal`) for quick spec inspection, and replace legacy `https://r2.vhunambi.com/...` defaults with `AppAssets.resolveGenreCoverAsset(track.genre, seedId: track.id)`.
- **`REQ-P72-AV-08` (Buyer Licenses HTTP Sync — `EP-P72-BUYER-LICENSES-HTTP`):** `IMarketplaceRepository` & `HttpMarketplaceRepository` SHALL implement `Future<List<SovereignLicenseCertificate>> getBuyerLicenses(String buyerId)` calling `GET /api/marketplace/licenses/$buyerId` (guarded by `_shouldSkipNetwork` for headless tests). `buyerLicensesFamilyProvider` SHALL hydrate remote purchases into `BeatsVaultView`'s `Licensed Beats` tab (`Key('beats_vault_mode_licensed')`) and `LibraryCategory.licensing` so cross-device beat purchases appear cleanly alongside local vault records.
- **`REQ-P72-AV-09` (Bottom Dock Insets & `>= 44x44dp` Touch Targets):** `PlaylistsVaultView`, `CollectionsVaultView`, and `BeatsVaultView` SHALL replace hardcoded `110` / `AppSpacing.md` bottom padding with `VhunambiBottomDockMetrics.scrollInset(hasActiveTrack: ...)`. All interactive buttons in `LibraryTrackTile`, `LibraryTrackGridCard`, `LibraryAppBar`, and `VhunambiUserCoinsChip` SHALL meet `>= 44x44dp` hit bounds.

---

## 4. Owner Studio Profile Requirements (`M72.3`)

- **`REQ-P72-OP-01` (Light-Mode Contrast & Zero White-on-White Traps):** `OwnerProfileView` and all mounted profile cards/dialogs/sheets SHALL replace every hardcoded `Colors.white`, `Colors.white70`, raw hex `Color(0x...)`, and static `AppColors.surfaceElevated` / `textPrimary` / `textSecondary` / `borderSubtle` with theme-adaptive `AppColors.*Of(context)` and `VhunambiGlassSurface`. Back chevron (`VhunambiBackButton`), header settings button (`Key('owner_header_settings_btn')`), release `ChoiceChip`s, and groove edit buttons MUST maintain WCAG AA contrast in both Light and Dark themes.
- **`REQ-P72-OP-02` (`MiniPlayerHost` Suppression on Pushed Route):** `OwnerProfileView` SHALL increment `pushedFullScreenOverlayCountProvider` in a post-frame callback in `initState()` and decrement it via a guarded microtask in `dispose()` (matching `ArtistProfileView#L59-L80`), guaranteeing `MiniPlayerHost` never overlaps `OwnerProfileView` while playing audio.
- **`REQ-P72-OP-03` (Glass Visual Harmonization & 100% Owner Feature Preservation):** `OwnerProfileView` SHALL wrap its body in `VhunambiAmbientMeshBackdrop` and render its hero profile card, studio tabs, track rows, DNA card, beatstore, releases, wallet, mastery badges, tip ledger, and referral card using `VhunambiGlassSurface` (`enableLiveBlur: false` on repeating cards), while preserving **100%** of private studio tools (`DAW / Vocal Upload`, `Change Avatar`, `Edit Profile`, `Pin Song`, `Studio Analytics`, `Settings`, `CreatorDnaProfileCard(isOwner: true)`, `ArtistVoiceShowcaseCard`, `MelodySketchpadModal`, `OwnerBeatstoreCockpit`, `ReleasesManagerCard`, `CreatorWalletDeck`, `CrossModuleSynergyDeck`, `TipHistoryLedger`, `ProfileReferralCard`).
- **`REQ-P72-OP-04` (Live Owner Songs, Persisted Visibility & `ViewerRole.owner` Cockpit Push):**
  - `OwnerProfileView` `"Your Songs"` SHALL project live non-deleted vocal songs owned by the active creator from `libraryTracksProvider` (matching `creatorId` or canonical `creatorName`), preserving fallback starter tracks owned by `profile.id` if the vault is empty.
  - Tapping a song card (`Key('owner_song_tile_${track.id}')`) SHALL push `TrackDetailView(trackId: track.id)` resolving `ViewerRole.owner`.
  - Tapping the Public/Private toggle pill (`Key('owner_song_visibility_${track.id}')`) SHALL persist `isPublic` via `libraryTracksProvider.notifier.toggleTrackVisibility(track.id)` (persisted to Hive + sync outbox, NEVER widget-local `_trackVisibility` RAM).
  - The inline Play `IconButton` SHALL enforce `>= 44x44dp` tap bounds and queue `track.toTrack()`.
- **`REQ-P72-OP-05` (`PinnedSpotlightCard` Artwork & Cockpit Navigation):** `PinnedSpotlightCard` SHALL render artwork via `VhunambiTrackArtwork`, normalize audio URLs via `AppConstants.normalizeCloudMediaUrl`, adopt `VhunambiGlassSurface`, and push `TrackDetailView(trackId: pinnedTrackId!)` when tapped.
- **`REQ-P72-OP-06` (Owner Beatstore Dynamic Scoping & Kinetic Posts Focus Route):**
  - `OwnerBeatstoreCockpit` SHALL watch `currentCreatorIdProvider` instead of hardcoded `'creator_ndugelo'`.
  - `_OwnerReelsShelf` SHALL watch `creatorClipsFamilyProvider(currentCreatorId)` instead of hardcoded `'creator_me'`, and `OwnerProfileView` SHALL render an **Owner Kinetic Posts** section (`Key('owner_kinetic_posts_section')`) watching `socialFeedPostsProvider` filtered to the owner's canonical creator ID, pushing `KineticPostFocusView(postId: post.id)` (`EP-P69-KPOST-FOCUS-ROUTE`) on tap.
- **`REQ-P72-OP-07` (Live 10/10 Allowance Inside `CreatorWalletDeck`):** `CreatorWalletDeck` SHALL embed a glass **Monthly Free Songs Allowance** card (`Key('wallet_monthly_allowance_card')`) watching `creatorAllowanceProvider` (`EP-P68-CREATOR-ALLOWANCE`), displaying `'${allowance.freeMonthlySongsRemaining}/${allowance.freeMonthlySongsLimit} free songs left'` (or `'Pro Unlimited'`) with an Upgrade tap trigger opening `SubscriptionUpgradeModal.show(context)`.

---

## 5. Non-Functional & `STD-UIUX-001` Requirements (`REQ-P72-NFR-*`)

- **`REQ-P72-NFR-01` (Zero Stock Material `Icons.*` & Zero Raw Unicode Emojis — `STD-UIUX-001`):** Every modified file across `features/library/`, `features/playlists/`, `features/collections/`, `features/beats/`, `features/offline/`, and `features/profile/` SHALL have **0** `Icons.*` occurrences and **0** raw Unicode emojis (`💰`, `🎛️`, `🛍️`, `💿`, `🎵`, `🎹`, `🎸`, `▶`, `❤️`, `🌐`, `🔒`, `🪙`, `🥇`, `🥈`, `🥉`, `🎖️`, `⚡`, `🎙️`, `👸`, `🤴`, `🎤`, `📋`, `✨`, `🪄`, `📸`). All UI glyphs MUST use `PhosphorIcon(AppIcons.* / PhosphorIconsRegular.* / PhosphorIconsFill.*)`.
- **`REQ-P72-NFR-02` (60 FPS Android Budget):** `VhunambiGlassSurface` on repeating list/grid items MUST keep `enableLiveBlur: false`. Zero `BackdropFilter` widgets may be mounted inside `ListView`/`GridView` item builders.
- **`REQ-P72-NFR-03` (Bounded Headless Widget Testing):** All Phase 72 Flutter widget tests MUST run under `flutter test --no-pub --timeout=60s` using bounded `pump(...)` loops where animated tickers exist, and HTTP repository tests (`Dio` custom adapter) MUST execute in plain `test()` outside `FakeAsync`.

---

## 6. Requirement-to-Test Traceability Matrix

| Requirement ID | Primary Implementation Anchor(s) | Verification Test Case(s) |
| :--- | :--- | :--- |
| `REQ-P72-SWR-01..06` | `edge_persistence_bridge.ts`, `vhunambi_db.ts`, `library_routes.ts`, `playlist_routes.ts`, `marketplace_routes.ts`, `server.ts` | `test/phase72_vault_swr_and_licenses.test.ts` (Isolate A -> Isolate B library/playlist/marketplace/license SWR + delete durability) |
| `REQ-P72-AV-01..02` | `library_models.dart`, `library_providers.dart`, `track_providers.dart` | `phase72_asset_vault_and_owner_profile_test.dart`: `LibraryTrack preserves creatorId/moodId/bpm and resolves ViewerRole.owner in TrackDetailView` |
| `REQ-P72-AV-03..07` | `library_view.dart`, `library_app_bar.dart`, `library_cover_art.dart`, `playlist_cover_art.dart`, `track_actions_sheet.dart`, `beats_vault_view.dart`, `vault_storage_modal.dart` | `library_view_test.dart` + `phase72_asset_vault_and_owner_profile_test.dart`: `LibraryCoverArt & PlaylistCoverArt render asset: covers via VhunambiTrackArtwork; mobile Cached Only visible; TrackActionsSheet opens TrackDetailView` |
| `REQ-P72-AV-08` | `i_marketplace_repository.dart`, `http_marketplace_repository.dart`, `marketplace_providers.dart`, `beats_vault_view.dart` | `phase72_asset_vault_and_owner_profile_test.dart`: `HttpMarketplaceRepository.getBuyerLicenses parses GET /api/marketplace/licenses/:buyerId` (plain `test()`) |
| `REQ-P72-OP-01..07` | `owner_profile_view.dart`, `pinned_spotlight_card.dart`, `owner_beatstore_cockpit.dart`, `creator_wallet_deck.dart` | `owner_profile_view_test.dart`, `creator_wallet_deck_test.dart`, `avatar_customization_modal_test.dart`, `phase72_asset_vault_and_owner_profile_test.dart` (Light/Dark contrast, `pushedFullScreenOverlayCountProvider`, live owner tracks, persisted visibility, Kinetic Posts, live allowance) |
| `REQ-P72-NFR-01..03` | All Phase 72 touched files | Static grep (`0` `Icons.`, `0` raw emojis) + `flutter analyze --no-pub` (`0` issues) + all suites `--timeout=60s` |
