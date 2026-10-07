# Phase 13 · Tasks — Collections & EP/Album Concept Bundler

> **Phase:** 13  
> **Codename:** `collections-bundler`  
> **Baseline:** `dart analyze .` = 0 issues | `flutter test` = 477/477 passing  
> **Target:** `dart analyze .` = 0 issues | `flutter test` = ≥ 512 (≥ 35 new tests, 0 regressions)

---

## Pre-Flight Checks (Run Before Writing Any Code)

```powershell
cd c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_client
dart analyze .          # MUST report: No issues found!
flutter test --no-pub   # MUST report: 477 tests passed (0 failures)
```

Both commands MUST pass before proceeding to Task 1.

---

## Task 1 — Constants (10 min)

**File:** `lib/core/constants/app_constants.dart`

- [ ] Add: `static const String collectionsBoxKey = 'vhunambi_collections';`

**Verification:** `dart analyze .` → 0 issues.

---

## Task 2 — Domain Models (30 min)

**File:** `lib/features/collections/domain/models/collection_entity.dart`

- [ ] Define `CollectionType` enum with values: `single`, `ep`, `album`, `conceptProject`.
  - `label` getter: `'Single'`, `'EP'`, `'Album'`, `'Concept Project'`.
  - `recommendedRange` getter returning `(int, int)` record: `(1,1)`, `(2,7)`, `(8,20)`, `(1,30)`.
  - `toJson()` returning snake_case strings.
  - `CollectionType.fromJson(String)` factory.
- [ ] Define `SplitParticipant` immutable value object:
  - Fields: `name`, `role`, `sharePercent`.
  - `copyWith`, `toJson`, `fromJson`, `==`, `hashCode`.
- [ ] Define `CollectionEntity` immutable class:
  - All fields per REQ-COL-01.
  - Computed: `trackCount`, `totalSharePercent`, `isSplitBalanced`, `typeLabel`.
  - `copyWith`, `toJson`, `fromJson`, `==`, `hashCode`.

**Verification:** `dart analyze .` → 0 issues.

---

## Task 3 — Repository Interface (10 min)

**File:** `lib/features/collections/domain/repositories/i_collection_repository.dart`

- [ ] Define `abstract interface class ICollectionRepository` with all 10 method signatures from REQ-COL-05.

---

## Task 4 — `InMemoryCollectionRepository` (20 min)

**File:** `lib/features/collections/data/repositories/in_memory_collection_repository.dart`

- [ ] Implement `InMemoryCollectionRepository implements ICollectionRepository`.
- [ ] Constructor: `InMemoryCollectionRepository({List<CollectionEntity> seed = const []})` seeding `_store`.
- [ ] `getAllCollections()` returns values sorted by `updatedAt` descending.
- [ ] All mutation methods perform deep copies of `trackIds` and `participants` lists before storing updated entities.
- [ ] `addTrackToCollection`: append only if not already present.
- [ ] `removeParticipant`: matches by `name`.

---

## Task 5 — `CollectionRepository` (Hive-backed) (20 min)

**File:** `lib/features/collections/data/repositories/collection_repository.dart`

- [ ] Import `package:hive_flutter/hive_flutter.dart` (NOT `package:hive/hive.dart`).
- [ ] Constructor: `CollectionRepository({Box? box}) { _box = box; }` (prefer_initializing_formals avoided intentionally).
- [ ] `_ensureInit()` pattern: check `_initialized`, skip if `_box != null`, try `Hive.isBoxOpen(collectionsBoxKey)`, fall back silently to `_inMemoryFallback`.
- [ ] All methods call `_ensureInit()` before operating, and use `_box?.get()` / `_box?.put()` if non-null, otherwise `_inMemoryFallback`.
- [ ] `getAllCollections()` deserializes via `CollectionEntity.fromJson(json.cast())` sorted newest-first.

---

## Task 6 — Riverpod Providers (15 min)

**File:** `lib/features/collections/presentation/providers/collections_provider.dart`

- [ ] `collectionRepositoryProvider = Provider<ICollectionRepository>((ref) => CollectionRepository())`.
- [ ] `collectionsProvider = StateNotifierProvider<CollectionsNotifier, List<CollectionEntity>>((ref) { ... notifier.loadCollections(); ... })`.
- [ ] `CollectionsNotifier extends StateNotifier<List<CollectionEntity>>` with all 11 methods from REQ-COL-10.
- [ ] `createCollection` generates `id = 'col_${DateTime.now().microsecondsSinceEpoch}'`, prepends to state.
- [ ] `updateCollection` only updates supplied non-null fields, sets `updatedAt = DateTime.now()`.
- [ ] `addTrack` / `removeTrack` / `reorderTracks` delegate to repository then update state in-place.
- [ ] `addParticipant` / `removeParticipant` / `updateParticipant` delegate to repository then update state in-place.

---

## Task 7 — `CollectionsVaultView` (60 min)

**File:** `lib/features/collections/presentation/views/collections_vault_view.dart`

- [ ] `ConsumerStatefulWidget` with `_searchController` and `_searchQuery`.
- [ ] When `allCollections.isEmpty` → render `LibraryEmptyState(category: LibraryCategory.collections, onCreateRequested: _showCreateDialog)`.
- [ ] Action bar: `TextField` (search) + `ElevatedButton` (`New Collection` → `_showCreateDialog()`).
- [ ] Filter `filteredCollections` by `_searchQuery` against `title` and `genre` (case-insensitive).
- [ ] `viewMode == LibraryViewMode.grid` → `GridView.builder` with `_CollectionCard`.
- [ ] `viewMode == LibraryViewMode.list` → `ListView.separated` with `_CollectionListTile`.
- [ ] `_showCreateDialog()` → `showDialog` with `_CreateCollectionDialog`.
- [ ] `_showRenameDialog(collection)` → `showDialog` with `_RenameCollectionDialog`.
- [ ] `_confirmDelete(collection)` → `AlertDialog` with `Cancel`/`Delete` buttons.
- [ ] On card tap: `Navigator.of(context).push(MaterialPageRoute(builder: (_) => CollectionDetailView(collection: c)))`.
- [ ] `_CollectionCard`: `Material` + `InkWell`, artwork placeholder, `_TypeBadge`, title, track count, popup menu.
- [ ] `_CollectionListTile`: `Material` + `ListTile` (NO `Container` with `decoration`), artwork leading, title, subtitle `'N song(s) • TypeLabel'`, popup menu trailing.
- [ ] `_TypeBadge`: EP/Single → `badgeCyanBg`/`badgeCyan`; Album/Concept → `amberInset`/`brandPrimary`.
- [ ] `_CreateCollectionDialog` / `_RenameCollectionDialog`: title `TextField`, `DropdownButton<CollectionType>`, genre `TextField`, description `TextField`, `Cancel`/`Create` (disabled if title empty).

---

## Task 8 — `CollectionDetailView` (75 min)

**File:** `lib/features/collections/presentation/views/collection_detail_view.dart`

- [ ] `ConsumerWidget` watching `collectionsProvider` for live state, uses `liveCollection = allCollections.firstWhere(id == collection.id, orElse: () => collection)`.
- [ ] `_resolveTracks(WidgetRef, List<String> ids) → List<Track>` from `libraryTracksProvider` with fallback placeholder.
- [ ] `AppBar` with `liveCollection.title`, `PopupMenuButton` (Rename, Delete).
- [ ] Hero header row (artwork 140px + metadata column: title, `_TypeBadge`, genre, N songs, duration, release date if set).
- [ ] `▶ Play All` and `🔀 Shuffle` `ElevatedButton` / `OutlinedButton` calling `playerStateProvider` pattern.
- [ ] `📄 Split Sheet` `OutlinedButton` opening `SplitSheetModal`.
- [ ] Tracks section header.
- [ ] When no tracks: placeholder `Container` with `Text('No songs added yet. ...')`.
- [ ] When tracks exist: `ReorderableListView.builder` using `onReorderEnd` (NOT deprecated `onReorder`).
  - Each row: `Material`-wrapped `ListTile` (drag handle as leading, index, title, subtitle `'artist • genre'`, `×` remove button, formatted duration in trailing).
  - Key: `ValueKey(track.id)`.
- [ ] `TextButton.icon('+  Add Track from Library')` → opens `AddToCollectionSheet`.
- [ ] Split Sheet Participants section header.
- [ ] `_ParticipantRow` per participant: name, role, `XX%`, Edit button, × remove button.
- [ ] `_TotalShareIndicator`: `'Total: ${totalShare.toStringAsFixed(0)}%'`, color `AppColors.success` if `isSplitBalanced` else `AppColors.error`.
- [ ] `TextButton.icon('+ Add Collaborator')` → opens `AddParticipantDialog`.

---

## Task 9 — `AddToCollectionSheet` (20 min)

**File:** `lib/features/collections/presentation/views/collection_detail_view.dart` (inline private class) or separate widget file.

- [ ] `showModalBottomSheet` with `DraggableScrollableSheet`.
- [ ] Shows all `libraryTracksProvider` tracks NOT already in `collection.trackIds`.
- [ ] Search `TextField` to filter by title.
- [ ] Each row: `ListTile(title: track.title, subtitle: '${track.creatorName} • ${track.genre}', onTap: () { addTrack; Navigator.pop; })`.
- [ ] When no unAdded tracks: show `'All your library tracks are already in this collection.'`.

---

## Task 10 — `AddParticipantDialog` (25 min)

**File:** `lib/features/collections/presentation/views/collection_detail_view.dart` (inline) or separate widget.

- [ ] `AlertDialog` (backgroundColor: `AppColors.surfaceModal`).
- [ ] Title: `'Add Collaborator'` or `'Edit Collaborator'` depending on whether pre-populated.
- [ ] `TextField` for Name (autofocus).
- [ ] `TextField` for Role (hint: `'e.g. Producer, Composer, Lyricist'`).
- [ ] `TextField` for Share % (keyboardType: `TextInputType.number`, validates 0–100).
- [ ] `Save` button disabled while name or role is empty or share invalid.
- [ ] On save: calls `collectionsNotifier.addParticipant(...)` or `updateParticipant(...)`.

---

## Task 11 — `SplitSheetModal` (20 min)

**File:** Inline in `collection_detail_view.dart` or `lib/features/collections/presentation/views/collection_detail_view.dart`.

- [ ] Desktop (≥1024px): `showDialog` with centered `Dialog(child: _SplitSheetContent(...))`.
- [ ] Mobile: `showModalBottomSheet(isScrollControlled: true, ...)` wrapping `_SplitSheetContent`.
- [ ] `_SplitSheetContent`:
  - Title row: `📄 Split Sheet — {title}`.
  - Metadata: type, genre, track count, duration, creation date.
  - Participants table (header + data rows).
  - Balance warning in `AppColors.error` if `!isSplitBalanced`.
  - `Close` and `Copy to Clipboard` (`Clipboard.setData`) buttons.

---

## Task 12 — Library Integration (10 min)

**File:** `lib/features/library/presentation/views/library_view.dart`

- [ ] Import `CollectionsVaultView`.
- [ ] In the `Expanded` child condition, add: `else if (category == LibraryCategory.collections) CollectionsVaultView(onCreateRequested: onCreateRequested)`.

---

## Task 13 — Tests (60 min)

### `collection_entity_test.dart`
- [ ] Default fields (type=ep, genre='', description='', trackIds=[], participants=[]).
- [ ] `trackCount`, `totalSharePercent`, `isSplitBalanced`, `typeLabel`.
- [ ] `copyWith` partial replacement.
- [ ] `toJson()` / `fromJson()` round-trip for `CollectionEntity`.
- [ ] `CollectionType.fromJson` and `toJson` for all 4 values.
- [ ] `CollectionType.label` and `recommendedRange` for all 4 values.
- [ ] `SplitParticipant` toJson/fromJson round-trip and equality.
- [ ] `== and `hashCode` structural equality.

### `collection_repository_test.dart`
- [ ] Empty repository starts empty.
- [ ] `saveCollection` inserts; second save with same id replaces.
- [ ] `getAllCollections` returns newest-first.
- [ ] `getCollectionById` returns matching entity or null.
- [ ] `deleteCollection` removes and is idempotent.
- [ ] `addTrackToCollection` appends and ignores duplicates.
- [ ] `removeTrackFromCollection` removes and tolerates misses.
- [ ] `reorderTracks` sets new order.
- [ ] `addParticipant` appends participant.
- [ ] `removeParticipant` removes by name and tolerates misses.
- [ ] `updateParticipant` replaces matching by name.

### `collections_provider_test.dart`
- [ ] Fresh container starts empty.
- [ ] `loadCollections` mirrors repository.
- [ ] `createCollection` persists, prepends, trims title.
- [ ] `updateCollection` renames without touching trackIds.
- [ ] `updateCollection` ignores unknown ids.
- [ ] `deleteCollection` removes from vault and repository.
- [ ] `addTrack` ignores duplicates and unknown collections.
- [ ] `removeTrack` tolerates absent tracks and unknown ids.
- [ ] `reorderTracks` updates order in state.
- [ ] `addParticipant` / `removeParticipant` / `updateParticipant` reflect in state.

### `collections_vault_view_test.dart`
- [ ] Empty state renders `'No collections yet'` and CTA text.
- [ ] Tapping CTA opens Create dialog.
- [ ] Populated state renders grid cards with title, type badge, track count.
- [ ] List mode renders `Material` `ListTile` rows without Flutter assertions.
- [ ] Search query filters collections by title.
- [ ] Tapping a card navigates to `CollectionDetailView`.

### `collection_detail_view_test.dart`
- [ ] Header renders title, type badge, Play All, Shuffle, Split Sheet buttons.
- [ ] Empty tracks renders placeholder text.
- [ ] Resolved track renders title and `'artist • genre'` subtitle.
- [ ] Removing track calls `removeTrack`.
- [ ] `Play All` queues tracks via `playerStateProvider`.
- [ ] Participant row shows name, role, share.
- [ ] Total share indicator is green when balanced, red when not.
- [ ] Tapping Split Sheet button opens the modal.

---

## Final Verification Gate

```powershell
cd c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_client

dart analyze .          # MUST report: No issues found! (0 issues)
flutter test --no-pub   # MUST report: ≥ 512 tests passed (0 failures)
```

**Then write `docs/phases/phase_13_collections_bundler/walkthrough.md`** and update:
- `docs/AGENT_HANDOFF_BIBLE.md` header + Phase 13 delivery record.
- `README.md` status banner and milestone table.
