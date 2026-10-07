# Master Handoff Prompt: Phase 4 — Library & User Asset Vault (`/library`)

> **To be executed by:** Cline (DeepSeek V4 Flash / 1M Context Window) OR Antigravity IDE  
> **Working Directory:** `apps/vhunambi_client/`  
> **Source Blueprint:** `docs/foundation_blueprints/04_LIBRARY_VAULT_SPEC.md`  
> **Phase 4-Doc Suite:** `docs/phases/phase_04_library_vault/` (`blueprint.md`, `requirements.md`, `design.md`, `tasks.md`)  
> **Architecture Standard:** `docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`

---

## Pre-Flight Status & Guardrails
1. **Baseline Status:** `dart analyze .` reports **0 issues**. `flutter test` reports **14 of 14 tests passing cleanly (100%)**.
2. **Brand Identity:** Name is strictly **`vhunambi`** (with an **i**).
3. **Design Tokens:** Strictly utilize `AppColors`, `AppGradients`, `AppTypography`, `AppRadius`, and `AppSpacing` from `package:vhunambi_client/core/theme/`. **NEVER hardcode raw hex values or ad-hoc border radii.**
4. **Collision Safety:** Do NOT import `RepeatMode` from Flutter; our audio repeat enum is `AudioRepeatMode`.
5. **Responsive Utilities:** Use `ResponsiveUtils.isDesktop(context)` (> 1024px) vs `ResponsiveUtils.isMobile(context)` (< 768px).

---

## Phase 4 Implementation Goal
Build out the complete **Library & User Asset Vault (`LibraryView`)** under `lib/features/library/` based on Blueprint 04, and wire it into tab index 3 of `RootShell` in `lib/main.dart`.

---

## Step-by-Step Task Sequence

### 1. Domain Models
Path: `lib/features/library/domain/models/library_models.dart`
- Enums: `LibraryCategory` (`songs`, `playlists`, `collections`, `beats`, `licensing`, `trash`), `LibraryViewMode` (`list`, `grid`), `TrackSyncStatus` (`synced`, `downloading`, `cachedLocally`, `cloudOnly`, `error`).
- Immutable `LibraryTrack` entity with `id`, `title`, `creatorName`, `genre`, `language`, `durationSeconds`, `remoteAudioUrl`, `localAudioFilePath`, `coverImageUrl`, `createdAt`, `licenseType`, `isDeleted`, `deletedAt`, `syncStatus`, `copyWith`, and `formattedDuration`.

### 2. Riverpod State Providers
Path: `lib/features/library/presentation/providers/library_providers.dart`
- `libraryCategoryProvider` (`StateProvider<LibraryCategory>`) defaulting to `songs`.
- `librarySearchQueryProvider` (`StateProvider<String>`) defaulting to `''`.
- `libraryViewModeProvider` (`StateProvider<LibraryViewMode>`) defaulting to `list`.
- `LibraryTracksNotifier` and `libraryTracksProvider`:
  - Provide seed demo tracks:
    - `"Grateful in the Light"`, Amapiano, English, 216s, creator `"cern"`, commercial license.
    - `"Ndo Mufuna Matibe"`, Amapiano, Tshivenḓa, 198s, creator `"Fifi"`, commercial license.
    - `"Township Log Drum Heat"`, Amapiano, instrumental, 180s, creator `"Sipho"`.
    - `"Durban Midnight Bass"`, Gqom, instrumental, 150s, creator `"DJ Vibe"`.
  - Methods: `addTrack`, `deleteTrack` (soft delete), `restoreTrack`, `purgeTrackPermanently`, `setSyncStatus`.
- `filteredLibraryTracksProvider`: Computes tracks matching current active category and search query.

### 3. Library UI Components (under `lib/features/library/presentation/widgets/`)
- **`library_app_bar.dart`**:
  - Responsive header: Brand emblem, centered breadcrumb `"My Library"` (desktop), credit pill (`⚡ 10 songs left`), notification bell, `📊 Analytics` button (desktop), overflow `⋮`, and primary `✨ Create` button.
- **`library_category_rail.dart`**:
  - Horizontal pill rail: `♪ Songs`, `≡♪ Playlists`, `💿 Collections`, `🛍️ Beats`, `⚖️ Licensing`, `🗑️ Trash`.
  - Active pill: `#F97316` background, `#000000` text, bold. Inactive: `#1B1B22`, border `#2D2D38`, `#9CA3AF`.
- **`library_empty_state.dart`**:
  - 48x48px squircle container (`#141418`, border `#2D2D38`, radius 14px), music note icon.
  - Title `"No songs yet"` (or `"No beats yet"`, etc.), helper subtext, and solid orange pill CTA `[ ✨ Create your first song ]`.
- **`library_track_tile.dart`**:
  - List row: Cover art with genre gradient (`AppGradients.forGenre`), title, duration (`mm:ss`), genre badge, offline chip (`⬇️ Offline` vs `☁️ Cloud`), and `⋮` button.
- **`library_track_grid_card.dart`**:
  - 2-column square card format with cover art, overlay badges, and play trigger.
- **`track_actions_sheet.dart`**:
  - Modal bottom sheet: `Play Now` (updates `playerStateProvider`), `Add to Playlist`, `Stem Separation`, `Download Offline`, `View Commercial License`, `Share Song`, `Move to Trash`.

### 4. Screen Assembly & RootShell Integration
- Path: `lib/features/library/presentation/views/library_view.dart`:
  - Composes `LibraryAppBar`, `LibraryCategoryRail`, search/filter bar with grid/list view toggle, and conditionally renders `LibraryEmptyState` or the populated list/grid.
- In `lib/main.dart`:
  - Replace `Scaffold(body: Center(child: Text('Library Vault')))` at tab index 3 with `const LibraryView()`.

### 5. Automated Tests
- `test/features/library/library_notifier_test.dart`
- `test/features/library/library_view_test.dart`

---

## Verification Criteria
- `dart analyze .` must report `No issues found!`.
- `flutter test` must pass all test cases without regression.

---

## Execution Record — 2026-09-22 ✅

**Status:** Phase 4 complete and verified. `dart analyze .` → `No issues found!` (0 issues). `flutter test` → `47 of 47 tests passed!` (14 baseline + 26 new library unit tests + 7 new library widget tests).

### Delivered Under `apps/vhunambi_client/`
* `lib/features/library/domain/models/library_models.dart` — `LibraryCategory`, `LibraryViewMode`, `TrackSyncStatus`, `LibrarySortOrder`, `LibrarySyncFilter`, immutable `LibraryTrack` (`copyWith`, `formattedDuration`, `createdAgoLabel`, `publicShareUrl`, `licenseCertificateId`, `toTrack()`).
* `lib/features/library/presentation/providers/library_providers.dart` — category/search/view-mode/sort/sync-filter providers, `LibraryTracksNotifier` (+ 4 seeded production vault records), `filteredLibraryTracksProvider`, `libraryCategoryCountsProvider`, `playLibraryTrack()`.
* `lib/features/library/presentation/widgets/` — `library_app_bar.dart`, `library_category_rail.dart`, `library_empty_state.dart`, `library_badges.dart`, `library_cover_art.dart`, `library_track_tile.dart`, `library_track_grid_card.dart`, `track_actions_sheet.dart`.
* `lib/features/library/presentation/views/library_view.dart` — screen assembly plus the search / sync-filter / view-mode strip.
* `lib/main.dart` — `RootShell` tab index 3 now renders `LibraryView(onCreateRequested: _openStudio)`; the vault `✨ Create` CTA and empty-state CTA switch the shell to the Studio tab (index 2).
* `lib/core/theme/app_dimensions.dart` — additive `AppRadius.squircle` (14px) token.
* `lib/core/constants/app_constants.dart` — additive `vaultBoxKey` / `vaultAudioDirectory` constants.
* `test/features/library/library_notifier_test.dart` (26 tests), `test/features/library/library_view_test.dart` (7 tests).

### Spec Deviations / Additions (documented for the auditor)
1. `LibraryTrack` carries an additive `isInstrumental` flag so the `🛍️ Beats` tab isolates standalone instrumentals while the track keeps its true style genre (Amapiano/Gqom) for the `AppGradients.forGenre` artwork and genre badge.
2. `LibrarySortOrder` + `librarySortProvider` and `LibrarySyncFilter` + `librarySyncFilterProvider` were added because Blueprint 04 §1.1 / §3.2 require an overflow control (`⋮`) and a `🎛️ Filter` control whose behaviour the SSOT left unspecified; they now drive the documented sort and offline/cloud filter semantics.
3. The search strip remains mounted whenever a query is active (with a `No matches for "…"` empty state and `Clear search` CTA) so users can always clear the query.
4. `🎛️ Filter` also clears on category change (search query resets) to keep category switching legible.
5. `Play Now` writes into the existing `playerStateProvider`; `Download Offline` marks `localAudioFilePath` + `TrackSyncStatus.cachedLocally` (binary writing lands in Phase 8); `Add to Playlist` and `Stem Separation` surface informational feedback pending their backend phases.
6. Playlist / Collection / Licensing categories render the universal empty state because the Phase 4 design contract models `LibraryTrack` records only.
