# Phase 13 · Requirements — Collections & EP/Album Concept Bundler

> **Phase:** 13  
> **Codename:** `collections-bundler`  
> **Standard:** RFC 2119 (MUST, SHALL, SHOULD, MAY) + EARS (Ubiquitous, Event-driven, Optional)  
> **Parent Blueprint:** `docs/phases/phase_13_collections_bundler/blueprint.md`

---

## 1. Domain Model Requirements

### REQ-COL-01 — Collection Entity
The system **MUST** define an immutable `CollectionEntity` class in `lib/features/collections/domain/models/collection_entity.dart` with the following fields:
- `id: String` — unique slug prefixed `col_`.
- `title: String` — display name (non-empty after trim).
- `type: CollectionType` — enum: `single`, `ep`, `album`, `conceptProject`.
- `genre: String` — defaults to `''`.
- `description: String` — defaults to `''`.
- `releaseDate: DateTime?` — optional target release date.
- `coverImageUrl: String?` — optional remote artwork URL.
- `trackIds: List<String>` — ordered list of `LibraryTrack.id` values.
- `participants: List<SplitParticipant>` — ordered collaborator entries.
- `createdAt: DateTime` — immutable creation timestamp.
- `updatedAt: DateTime` — mutable last-edit timestamp.

### REQ-COL-02 — Collection Type Enum
The system **MUST** define a `CollectionType` enum with values: `single`, `ep`, `album`, `conceptProject`. Each value **MUST** expose a `label` getter (`'Single'`, `'EP'`, `'Album'`, `'Concept Project'`) and a `recommendedRange` getter returning an `(int min, int max)` record: `(1,1)`, `(2,7)`, `(8,20)`, `(1,30)`.

### REQ-COL-03 — Split Participant Model
The system **MUST** define an immutable `SplitParticipant` value object with fields:
- `name: String` — collaborator display name.
- `role: String` — e.g. `'Producer'`, `'Composer'`, `'Lyricist'`.
- `sharePercent: double` — 0.0 to 100.0.

Both `CollectionEntity` and `SplitParticipant` **MUST** implement `toJson()`, `fromJson()`, `copyWith()`, `==`, and `hashCode`.

### REQ-COL-04 — Collection Computed Properties
`CollectionEntity` **MUST** expose:
- `trackCount → int` — length of `trackIds`.
- `totalSharePercent → double` — sum of all `participants[].sharePercent`.
- `isSplitBalanced → bool` — true when `totalSharePercent == 100.0`.
- `typeLabel → String` — delegated to `type.label`.

---

## 2. Repository Requirements

### REQ-COL-05 — `ICollectionRepository` Interface
The system **MUST** define `ICollectionRepository` in `lib/features/collections/domain/repositories/i_collection_repository.dart` with:
- `getAllCollections() → Future<List<CollectionEntity>>` — returns newest-first.
- `getCollectionById(String id) → Future<CollectionEntity?>`.
- `saveCollection(CollectionEntity entity) → Future<void>` — upsert by `id`.
- `deleteCollection(String id) → Future<void>` — idempotent.
- `addTrackToCollection(String collectionId, String trackId) → Future<void>` — appends if not already present.
- `removeTrackFromCollection(String collectionId, String trackId) → Future<void>`.
- `reorderTracks(String collectionId, List<String> orderedTrackIds) → Future<void>`.
- `addParticipant(String collectionId, SplitParticipant participant) → Future<void>`.
- `removeParticipant(String collectionId, String participantName) → Future<void>`.
- `updateParticipant(String collectionId, SplitParticipant updated) → Future<void>`.

### REQ-COL-06 — `InMemoryCollectionRepository`
The system **MUST** provide `InMemoryCollectionRepository implements ICollectionRepository` seeded via an optional `List<CollectionEntity>` constructor argument for headless test isolation.

### REQ-COL-07 — `CollectionRepository` (Hive-backed)
The system **MUST** provide `CollectionRepository implements ICollectionRepository` backed by `Hive.box(AppConstants.collectionsBoxKey)` storing JSON maps. When Hive is uninitialized or the box is not open, it **MUST** fall back to in-memory storage without throwing unhandled async exceptions (pattern from `PlaylistRepository`).

### REQ-COL-08 — Constants Key
The system **MUST** add `static const String collectionsBoxKey = 'vhunambi_collections'` to `AppConstants`.

---

## 3. Provider Requirements

### REQ-COL-09 — `collectionsProvider`
The system **MUST** define `collectionsProvider` as a `StateNotifierProvider<CollectionsNotifier, List<CollectionEntity>>` that calls `loadCollections()` on initialization and exposes state as newest-first list.

### REQ-COL-10 — `CollectionsNotifier` CRUD
`CollectionsNotifier` **MUST** expose:
- `loadCollections()` — reads from repository.
- `createCollection(title, type, {genre, description, releaseDate}) → Future<CollectionEntity>` — generates `id = 'col_${now.microsecondsSinceEpoch}'`, saves, and prepends.
- `updateCollection(id, {title?, type?, genre?, description?, releaseDate?}) → Future<void>`.
- `deleteCollection(id) → Future<void>`.
- `addTrack(collectionId, trackId) → Future<void>`.
- `removeTrack(collectionId, trackId) → Future<void>`.
- `reorderTracks(collectionId, newOrder) → Future<void>`.
- `addParticipant(collectionId, participant) → Future<void>`.
- `removeParticipant(collectionId, participantName) → Future<void>`.
- `updateParticipant(collectionId, updated) → Future<void>`.

### REQ-COL-11 — `collectionRepositoryProvider`
The system **MUST** define `collectionRepositoryProvider` as an injectable `Provider<ICollectionRepository>` defaulting to `CollectionRepository()` and overrideable in tests with `InMemoryCollectionRepository`.

---

## 4. Collections Vault View Requirements

### REQ-COL-12 — Library Integration
When `LibraryCategory.collections` is the active category, `LibraryView` **MUST** render `CollectionsVaultView` in place of the default tracks list/grid.

### REQ-COL-13 — Empty State
When there are no collections, `CollectionsVaultView` **MUST** render the universal `LibraryEmptyState(category: LibraryCategory.collections)` with the standard CTA that opens the Create Collection dialog.

### REQ-COL-14 — Action Bar
`CollectionsVaultView` **MUST** render an action bar containing:
- A search `TextField` that filters collections by title and genre in real-time.
- A `New Collection` `ElevatedButton` that opens the create dialog.

### REQ-COL-15 — Grid Display
When collections exist, `CollectionsVaultView` **MUST** display them in a responsive grid (2/3/4 columns) where each card shows:
- An artwork placeholder mosaic squircle (`AppColors.surfaceSecondary`/`surfaceElevated` gradient + `Icons.album_outlined`).
- The collection `title` in `AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600)`.
- A type badge chip (`EP`, `Album`, `Single`, `Concept`) using `AppColors.badgeCyanBg`/`badgeCyan` for EP/Single and `AppColors.amberInset`/`brandPrimary` for Album/Concept.
- The track count: `N songs`.
- A contextual overflow menu `[⋮]` with `Rename` and `Delete` options.

### REQ-COL-16 — List Display
When `libraryViewModeProvider == LibraryViewMode.list`, `CollectionsVaultView` **MUST** display collections as `Material`-wrapped `ListTile` rows with:
- Artwork squircle (48×48px) as leading widget.
- `title` as primary text.
- `'${trackCount} ${trackCount == 1 ? 'song' : 'songs'} • ${type.label}'` as subtitle when no description, or prepended with description if set.
- `[⋮]` popup menu with Rename and Delete as trailing widget.

### REQ-COL-17 — Create Dialog
Tapping `New Collection` or the empty-state CTA **MUST** open a dialog with:
- `TextField` for collection title (required, non-empty after trim).
- `DropdownButton` for `CollectionType` (default: `ep`).
- `TextField` for genre (optional, hint: `e.g. Amapiano`).
- `TextField` for optional description.
- `Cancel` and `Create` buttons. `Create` **MUST** be disabled while title is empty.

### REQ-COL-18 — Rename Dialog
Tapping `Rename` in the overflow menu **MUST** open a dialog pre-populated with the existing title, type, and genre, accepting edits and calling `updateCollection`.

### REQ-COL-19 — Delete Confirmation
Tapping `Delete` **MUST** present an `AlertDialog` confirming the action. Confirming **MUST** call `deleteCollection`. Tracks remain in the Library Vault.

---

## 5. Collection Detail View Requirements

### REQ-COL-20 — Navigation
Tapping any collection card or list row **MUST** navigate to `CollectionDetailView(collection: entity)` via `MaterialPageRoute`.

### REQ-COL-21 — Hero Header
`CollectionDetailView` **MUST** render a hero header row containing:
- Artwork placeholder (140×140px) on the left.
- On the right: title, type badge, genre, track count, aggregate formatted duration, and optional release date.
- `▶ Play All` and `🔀 Shuffle` action buttons calling `playerNotifierProvider.playPlaylist(...)`.
- `📄 Split Sheet` button opening the Split Sheet Summary modal.

### REQ-COL-22 — Track Listing
`CollectionDetailView` **MUST** render the resolved track list as a `ReorderableListView.builder` where:
- Each row is a `Material`-wrapped `ListTile` with drag handle, track index, title, `artist • genre`, and a `×` remove button.
- Reordering **MUST** call `collectionsNotifier.reorderTracks(...)`.
- Removing **MUST** call `collectionsNotifier.removeTrack(...)`.

### REQ-COL-23 — Add Track Button
Below the track list, a `TextButton.icon` reading `+ Add Track from Library` **MUST** open an `AddTrackToCollectionSheet` bottom sheet listing Library tracks not already in this collection.

### REQ-COL-24 — Split Sheet Participants
`CollectionDetailView` **MUST** display a `Split Sheet Participants` section below the track list showing:
- Each `SplitParticipant` as a row: `Name | Role | XX%` with `Edit` and `×` remove buttons.
- An `+ Add Collaborator` `TextButton` opening an `AddParticipantDialog`.
- A total share indicator: `'Total: ${totalSharePercent.toStringAsFixed(0)}%'` in `AppColors.success` when 100%, `AppColors.error` otherwise.

### REQ-COL-25 — Add Collaborator Dialog
`AddParticipantDialog` **MUST** contain fields for `Name`, `Role`, and `Share %` (0.0–100.0). `Save` **MUST** be disabled when name or role is empty, or when share is not a valid double 0–100.

### REQ-COL-26 — Edit Collaborator
Tapping `Edit` on a participant **MUST** open `AddParticipantDialog` pre-populated with current values, updating via `updateParticipant`.

---

## 6. Split Sheet Modal Requirements

### REQ-COL-27 — Split Sheet Summary Modal
Tapping `📄 Split Sheet` in the detail view **MUST** open a `SplitSheetModal` (centered `Dialog` on desktop ≥1024px, 90% bottom sheet on mobile) containing:
- Collection title, type, genre, track count, total duration, and creation date.
- A formatted table of participants (Name, Role, Share%).
- A balance warning if `!isSplitBalanced`.
- `Close` and `Copy to Clipboard` buttons. Copy **MUST** call `Clipboard.setData(ClipboardData(text: formattedText))`.

---

## 7. Test Requirements

### REQ-COL-28 — Unit Tests: Domain Model
`test/features/collections/domain/models/collection_entity_test.dart` **MUST** cover:
- Default field values.
- `trackCount`, `totalSharePercent`, `isSplitBalanced`, `typeLabel`.
- `copyWith` field replacement.
- `toJson()` / `fromJson()` round-trip.
- `==` and `hashCode` structural equality.
- `CollectionType.label` and `recommendedRange` for all 4 values.
- `SplitParticipant` JSON round-trip and equality.

### REQ-COL-29 — Unit Tests: Repository
`test/features/collections/data/repositories/collection_repository_test.dart` **MUST** cover:
- `InMemoryCollectionRepository`: CRUD, ordering, idempotent delete, add/remove track, reorder, add/remove/update participant.

### REQ-COL-30 — Unit Tests: Provider
`test/features/collections/presentation/providers/collections_provider_test.dart` **MUST** cover:
- `loadCollections`, `createCollection`, `updateCollection`, `deleteCollection`, `addTrack`, `removeTrack`, `reorderTracks`, `addParticipant`, `removeParticipant`, `updateParticipant`.

### REQ-COL-31 — Widget Tests: CollectionsVaultView
`test/features/collections/presentation/views/collections_vault_view_test.dart` **MUST** cover:
- Empty state renders `'No collections yet'` and CTA.
- Tapping CTA opens Create dialog.
- Populated state renders grid cards with title, type badge, and track count.
- List mode renders `Material` `ListTile` rows.
- Search filters by title.
- Tapping a card navigates to `CollectionDetailView`.

### REQ-COL-32 — Widget Tests: CollectionDetailView
`test/features/collections/presentation/views/collection_detail_view_test.dart` **MUST** cover:
- Header renders title, type badge, and action buttons.
- Empty track placeholder renders when no tracks.
- Resolved track renders title and metadata.
- Removing a track calls `removeTrack`.
- `Play All` queues tracks via `playerNotifierProvider`.
- Participant section renders and total share indicator is correct color.
- Tapping Split Sheet opens modal.

### REQ-COL-33 — Zero Regressions
`dart analyze .` **MUST** report **0 issues**. `flutter test` **MUST** pass all tests (baseline 477 + ≥ 35 new Phase 13 tests).
