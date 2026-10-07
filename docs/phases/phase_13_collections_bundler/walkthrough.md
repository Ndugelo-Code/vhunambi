# Phase 13 · Walkthrough — Collections & EP/Album Concept Bundler

> **Phase:** 13
> **Codename:** `collections-bundler`
> **Standard:** RFC 2119 / EARS (see `requirements.md`)
> **Executed By:** Cline (Dual-Agent Symbiosis Protocol)
> **Verification:** `dart analyze .` = **0 issues** · `flutter test --no-pub` = **541/541 passing (100%)**

---

## 1. Executive Summary

Phase 13 closes the `/library?tab=collections` deferred loop from Phase 4 by shipping the **Collections Bundler** — a structured release-authoring layer that groups vault tracks into Singles, EPs, Albums and Concept Projects with unified artwork, release metadata and split-sheet attribution:

1. **Domain layer (`collection_entity.dart`)**:
   * `CollectionType` enum (`single`, `ep`, `album`, `conceptProject`) with `label`, `badgeLabel`, `recommendedRange` records, snake_case `toJson()` and a tolerant `fromJson()`.
   * `SplitParticipant` immutable value object (`name`, `role`, `sharePercent`) with `copyWith`, JSON round-trip, structural equality and a `shareLabel` percentage formatter.
   * `CollectionEntity` aggregate with 11 stored fields plus computed `trackCount`, `trackCountLabel`, `totalSharePercent`, `isSplitBalanced`, `typeLabel` and `isWithinRecommendedRange`, `copyWith`, snake_case JSON and structural equality.

2. **Persistence (`ICollectionRepository` + two implementations)**:
   * `InMemoryCollectionRepository` — seeded double for headless tests, newest-`updatedAt`-first ordering, idempotent delete, duplicate-safe track insertion, name-matched participant removal/update.
   * `CollectionRepository` — Hive-backed (`AppConstants.collectionsBoxKey = 'vhunambi_collections'`) storing JSON maps, with a silent in-memory fallback whenever Hive is uninitialized (headless `flutter_test` safety, mirrors `PlaylistRepository`).

3. **State (`collections_provider.dart`)**:
   * `collectionRepositoryProvider` (injectable) + `collectionsProvider` (`StateNotifierProvider<CollectionsNotifier, List<CollectionEntity>>`).
   * `CollectionsNotifier` exposes the full 11-method engine: `loadCollections`, `createCollection` (`col_<microseconds>` ids, trimmed input, prepend), `updateCollection` (nullable patch + `updatedAt` bump), `deleteCollection`, `addTrack`, `removeTrack`, `reorderTracks`, `addParticipant`, `removeParticipant`, `updateParticipant`, plus `containsTrack` / `collectionById` helpers. Every mutation delegates to the repository and mirrors the persisted entity back into vault state.

4. **Vault UI (`CollectionsVaultView`)**:
   * Mounted at `/library?tab=collections` inside `LibraryView`.
   * Universal `LibraryEmptyState(category: LibraryCategory.collections)` with the *Start a collection* CTA opening the create dialog.
   * Action bar with real-time search (title + genre) and the `New Collection` pill CTA.
   * Responsive vault: 2 / 3 / 4 column grid (`childAspectRatio: 0.85`) of mosaic-artwork cards with type badge, title, `N songs` and a `⋮` Rename/Delete menu; list mode renders `Material`-wrapped `ListTile` rows with `'N songs • EP'` metadata.

5. **Detail UI (`CollectionDetailView`)**:
   * Live-resolved collection (survives vault refreshes) with AppBar title and Rename/Delete overflow.
   * Hero header: 140px mosaic artwork, title, type badge, genre, `N songs • duration`, optional release date, description and a non-blocking recommended-range warning.
   * Action deck: `▶ Play All`, `🔀 Shuffle` (both queue the resolved tracks through `playerStateProvider.notifier.playTrack`) and `📄 Split Sheet`.
   * Reorderable track listing (drag handles, index, `artist • genre`, duration, `×` remove, tap-to-play) plus `+ Add Track from Library`.
   * Split-sheet participant ledger with `Edit`/`×` actions and the `Total: NN%` indicator coloured `AppColors.success` at 100% and `AppColors.error` otherwise.

6. **Modals (`presentation/widgets/`)**:
   * `CollectionFormDialog` — shared Create/Edit dialog (title, type dropdown, genre, description, optional release-date picker; submit disabled while the title is blank).
   * `AddToCollectionSheet` — vault picker excluding tracks already in the collection, with search and an “all tracks already added” empty state.
   * `AddParticipantDialog` — add/edit collaborator with 0–100 share validation (`Save` disabled until valid).
   * `SplitSheetModal` — desktop `Dialog` (maxWidth 520) / mobile bottom sheet containing metadata, the participant table, the balance warning and `Copy to Clipboard` (`Clipboard.setData`).
   * `CollectionArtworkPlaceholder`, `CollectionTypeBadge` and `collection_format.dart` (`formatCollectionDate`, `formatCollectionDuration`) shared by every surface.

---

## 2. Task Ledger

| Task | Status | Evidence |
| --- | --- | --- |
| T1 Constants | ✅ Complete | `AppConstants.collectionsBoxKey` |
| T2 Domain models | ✅ Complete | `collection_entity.dart`, 13 tests |
| T3 Repository interface | ✅ Complete | `i_collection_repository.dart` (10 methods) |
| T4 `InMemoryCollectionRepository` | ✅ Complete | `in_memory_collection_repository.dart` |
| T5 `CollectionRepository` (Hive) | ✅ Complete | `collection_repository.dart` + box round-trip tests |
| T6 Providers | ✅ Complete | `collections_provider.dart`, 12 tests |
| T7 `CollectionsVaultView` | ✅ Complete | `collections_vault_view.dart`, 8 tests |
| T8 `CollectionDetailView` | ✅ Complete | `collection_detail_view.dart`, 12 tests |
| T9 `AddToCollectionSheet` | ✅ Complete | `add_to_collection_sheet.dart` |
| T10 `AddParticipantDialog` | ✅ Complete | `add_participant_dialog.dart` |
| T11 `SplitSheetModal` | ✅ Complete | `split_sheet_modal.dart` |
| T12 Library integration | ✅ Complete | `library_view.dart` ternary + mount test |
| T13 Tests | ✅ Complete | 63 new collection tests + 1 realigned library CTA test, 0 regressions (477 → 541) |

---

## 3. Test Inventory (64 New/Realigned Tests · 477 → 541)

```
collection_entity_test.dart (18 tests)
  * CollectionType labels + recommended ranges · badge captions · snake_case round-trip
  * unknown payload fallback · SplitParticipant JSON round-trip · partial payload
  * shareLabel · copyWith · equality · CollectionEntity defaults · computed properties
  * unbalanced split · range warnings · copyWith · snake_case JSON · full round-trip
  * partial payload · structural equality

collection_repository_test.dart (14 tests)
  * In-memory: seed · upsert · newest-first ordering · lookup · idempotent delete
  * add/remove/reorder tracks (duplicates + misses tolerated)
  * add/remove/update participants (name matching)
  * Hive-backed: persistence + rehydration ordering · track/participant mutation round-trip
  * In-memory fallback when Hive is uninitialized

collections_provider_test.dart (11 tests)
  * Empty container · loadCollections mirror · createCollection (trim + prepend + release date)
  * updateCollection (patch + unknown id) · deleteCollection · addTrack · removeTrack
  * reorderTracks · participant add/update/remove reflected in vault state

collections_vault_view_test.dart (8 tests)
  * Empty state + CTA · create dialog · grid cards (badge, count) · list rows
  * search filtering · card → detail navigation · New Collection creation
  * `/library?tab=collections` mounts CollectionsVaultView

collection_detail_view_test.dart (12 tests)
  * resolveCollectionTracks ordering + placeholder fallback (unit)
  * hero header/action deck · empty placeholders · resolved track metadata
  * remove track → repository · Play All queues tracks · participant rows + balanced total
  * unbalanced total colour · add collaborator persistence · edit collaborator share
  * Split Sheet modal open/close + balance warning
```

---

## 4. Key Design Decisions & Deviations

1. **`onReorderItem` instead of the handoff’s `onReorderEnd`:** Flutter 3.44.4 asserts that exactly one of `onReorder` / `onReorderItem` is supplied (`material/reorderable_list.dart:129`), and `onReorderEnd` is only a `void Function(int index)` drag-completion hook carrying no source index. The listing therefore uses the modern `onReorderItem` (the same callback standardised in `QueueDrawer`), whose `newIndex` is already adjusted for the removed item — the move is a plain remove-then-insert.
2. **`playerStateProvider.notifier` instead of `playerNotifierProvider`:** REQ-COL-21 names a `playerNotifierProvider` that does not exist in the codebase; Play All / Shuffle use `playerStateProvider.notifier.playTrack(queue.first, queue: queue)` (`playPlaylist` only accepts a `PlaylistEntity`).
3. **Shared `CollectionFormDialog`:** tasks.md allowed the create/rename dialogs inline in the vault view, but the detail view needs the same surface — the dialog lives in `presentation/widgets/collection_form_dialog.dart` and is reused by both (per design.md §1 widget map).
4. **Grid columns 2/3/4:** `ResponsiveUtils.gridColumns()` returns 6/2, contradicting Blueprint 13 §7; the vault derives 2 (mobile) / 3 (tablet) / 4 (desktop) from `ResponsiveUtils.isMobile/isTablet/isDesktop` instead.
5. **`ReorderableListView` row keys:** the framework requires the widget returned by `itemBuilder` to carry a key, so the `ValueKey('collection_track_<id>')` is passed to the row widget itself. A first cut placed it on an inner `Padding`, which threw `Every item of ReorderableListView must have a key`.
6. **Headless Hive safety:** `CollectionRepository` never calls `Hive.openBox()`; `_ensureInit()` checks `Hive.isBoxOpen(collectionsBoxKey)` and otherwise stores to `_inMemoryFallback`, so no unhandled async zone exceptions escape in VM test runners.
7. **Material-wrapped tiles:** every background-coloured `ListTile` is wrapped in `Material(color: …, shape: RoundedRectangleBorder(…))` to avoid the invisible-ink-splash assertion and to keep ripple feedback.
8. **Zero raw hex:** all surfaces, badges, borders and typography resolve through `AppColors.*` / `AppTypography.*` / `AppRadius.*` / `AppSpacing.*` (`dart analyze` clean).
9. **Phase 4 CTA test realigned (not weakened):** `library_view_test.dart` previously asserted that the *Collections* tab's empty-state CTA routes to the Studio cockpit. REQ-COL-13 intentionally supersedes that for this category (the CTA now opens the Create Collection dialog), so the Studio-handoff assertion was moved to a generic category (Licensing, `Create your first song`) and a new assertion locks the Collections CTA to the dialog. Generic Studio routing coverage is therefore preserved **and** extended.

---

## 5. Files Delivered / Modified

### Created
* `lib/features/collections/domain/models/collection_entity.dart`
* `lib/features/collections/domain/repositories/i_collection_repository.dart`
* `lib/features/collections/data/repositories/in_memory_collection_repository.dart`
* `lib/features/collections/data/repositories/collection_repository.dart`
* `lib/features/collections/presentation/providers/collections_provider.dart`
* `lib/features/collections/presentation/collection_format.dart`
* `lib/features/collections/presentation/views/collections_vault_view.dart`
* `lib/features/collections/presentation/views/collection_detail_view.dart`
* `lib/features/collections/presentation/widgets/collection_type_badge.dart`
* `lib/features/collections/presentation/widgets/collection_artwork_placeholder.dart`
* `lib/features/collections/presentation/widgets/collection_form_dialog.dart`
* `lib/features/collections/presentation/widgets/add_to_collection_sheet.dart`
* `lib/features/collections/presentation/widgets/add_participant_dialog.dart`
* `lib/features/collections/presentation/widgets/split_sheet_modal.dart`
* `test/features/collections/domain/models/collection_entity_test.dart`
* `test/features/collections/data/repositories/collection_repository_test.dart`
* `test/features/collections/presentation/providers/collections_provider_test.dart`
* `test/features/collections/presentation/views/collections_vault_view_test.dart`
* `test/features/collections/presentation/views/collection_detail_view_test.dart`
* `docs/phases/phase_13_collections_bundler/walkthrough.md`

### Modified
* `lib/core/constants/app_constants.dart` (added `collectionsBoxKey`)
* `lib/features/library/presentation/views/library_view.dart` (collections tab mount)
* `test/features/library/library_view_test.dart` (Collections-tab CTA assertion realigned to REQ-COL-13; Studio handoff retained on generic categories)

*(all paths relative to `apps/vhunambi_client/`)*

---

## 6. Deferred / Future Work

* Real cover-art upload + `coverImageUrl` rendering (media pipeline lands with the publishing phase).
* Collection → distribution handoff (streaming submission, ISRC assignment).
* Split-sheet PDF export and signature capture (the clipboard summary ships today).
* Cross-device collection sync (the Hive box is local-only, mirroring the playlist vault).


