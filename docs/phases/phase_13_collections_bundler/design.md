# Phase 13 · Design — Collections & EP/Album Concept Bundler

> **Phase:** 13  
> **Codename:** `collections-bundler`  
> **Parent Blueprint:** `docs/phases/phase_13_collections_bundler/blueprint.md`  
> **Parent Requirements:** `docs/phases/phase_13_collections_bundler/requirements.md`

---

## 1. Directory Structure

```
lib/features/collections/
├── domain/
│   ├── models/
│   │   ├── collection_entity.dart      # CollectionEntity + CollectionType + SplitParticipant
│   │   └── collection_type.dart        # CollectionType enum (can be co-located in collection_entity.dart)
│   └── repositories/
│       └── i_collection_repository.dart
├── data/
│   └── repositories/
│       ├── collection_repository.dart          # Hive-backed (+ in-memory fallback)
│       └── in_memory_collection_repository.dart
└── presentation/
    ├── providers/
    │   └── collections_provider.dart           # collectionRepositoryProvider + collectionsProvider
    ├── views/
    │   ├── collections_vault_view.dart         # /library?tab=collections grid/list
    │   └── collection_detail_view.dart         # Deep-dive detail + split sheet
    └── widgets/
        ├── collection_card.dart                # Grid card widget
        ├── collection_list_tile.dart           # List row widget
        ├── add_to_collection_sheet.dart        # Bottom sheet: pick Library tracks to add
        ├── add_participant_dialog.dart         # Dialog: add/edit SplitParticipant
        └── split_sheet_modal.dart             # Split sheet summary dialog/sheet

test/features/collections/
├── domain/models/
│   └── collection_entity_test.dart
├── data/repositories/
│   └── collection_repository_test.dart
└── presentation/
    ├── providers/
    │   └── collections_provider_test.dart
    └── views/
        ├── collections_vault_view_test.dart
        └── collection_detail_view_test.dart
```

---

## 2. Domain Model Classes

### 2.1 `CollectionType` enum

```dart
/// lib/features/collections/domain/models/collection_entity.dart
enum CollectionType {
  single,
  ep,
  album,
  conceptProject;

  String get label => switch (this) {
    single        => 'Single',
    ep            => 'EP',
    album         => 'Album',
    conceptProject => 'Concept Project',
  };

  /// Recommended (min, max) track range for this collection type.
  (int, int) get recommendedRange => switch (this) {
    single        => (1, 1),
    ep            => (2, 7),
    album         => (8, 20),
    conceptProject => (1, 30),
  };

  static CollectionType fromJson(String value) => switch (value) {
    'ep'              => ep,
    'album'           => album,
    'concept_project' => conceptProject,
    _                 => single,
  };

  String toJson() => switch (this) {
    single        => 'single',
    ep            => 'ep',
    album         => 'album',
    conceptProject => 'concept_project',
  };
}
```

### 2.2 `SplitParticipant` value object

```dart
@immutable
class SplitParticipant {
  final String name;
  final String role;
  final double sharePercent; // 0.0 – 100.0

  const SplitParticipant({
    required this.name,
    required this.role,
    required this.sharePercent,
  });

  SplitParticipant copyWith({String? name, String? role, double? sharePercent});

  Map<String, dynamic> toJson();
  factory SplitParticipant.fromJson(Map<String, dynamic> json);

  @override bool operator ==(Object other);
  @override int get hashCode;
}
```

### 2.3 `CollectionEntity`

```dart
@immutable
class CollectionEntity {
  final String id;               // 'col_<microseconds>'
  final String title;
  final CollectionType type;
  final String genre;
  final String description;
  final DateTime? releaseDate;
  final String? coverImageUrl;
  final List<String> trackIds;
  final List<SplitParticipant> participants;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CollectionEntity({
    required this.id,
    required this.title,
    this.type = CollectionType.ep,
    this.genre = '',
    this.description = '',
    this.releaseDate,
    this.coverImageUrl,
    this.trackIds = const [],
    this.participants = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  // --- Computed Properties ---
  int get trackCount => trackIds.length;
  double get totalSharePercent =>
      participants.fold(0.0, (sum, p) => sum + p.sharePercent);
  bool get isSplitBalanced => (totalSharePercent - 100.0).abs() < 0.01;
  String get typeLabel => type.label;

  CollectionEntity copyWith({ ... });
  Map<String, dynamic> toJson();
  factory CollectionEntity.fromJson(Map<String, dynamic> json);
  @override bool operator ==(Object other);
  @override int get hashCode;
}
```

JSON key convention: `snake_case` keys (`track_ids`, `release_date`, `cover_image_url`, `is_public`). Store `participants` as `List<Map>`.

---

## 3. Repository Interface & Implementations

### 3.1 `ICollectionRepository`

```dart
abstract interface class ICollectionRepository {
  Future<List<CollectionEntity>> getAllCollections();
  Future<CollectionEntity?> getCollectionById(String id);
  Future<void> saveCollection(CollectionEntity entity);
  Future<void> deleteCollection(String id);
  Future<void> addTrackToCollection(String collectionId, String trackId);
  Future<void> removeTrackFromCollection(String collectionId, String trackId);
  Future<void> reorderTracks(String collectionId, List<String> orderedTrackIds);
  Future<void> addParticipant(String collectionId, SplitParticipant participant);
  Future<void> removeParticipant(String collectionId, String participantName);
  Future<void> updateParticipant(String collectionId, SplitParticipant updated);
}
```

### 3.2 `InMemoryCollectionRepository`

- Stores `Map<String, CollectionEntity> _store`.
- Constructor: `InMemoryCollectionRepository({List<CollectionEntity> seed = const []})`.
- `getAllCollections()` returns values sorted by `updatedAt` descending.
- All mutation methods operate on `_store` with proper deep copies of `trackIds` and `participants`.

### 3.3 `CollectionRepository` (Hive-backed)

```dart
class CollectionRepository implements ICollectionRepository {
  CollectionRepository({Box? box}) {
    _box = box;
  }
  
  Box? _box;
  final Map<String, CollectionEntity> _inMemoryFallback = {};
  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    if (_box != null) { _initialized = true; return; }
    try {
      if (!kIsWeb && Hive.isBoxOpen(AppConstants.collectionsBoxKey)) {
        _box = Hive.box(AppConstants.collectionsBoxKey);
      }
    } catch (e) {
      debugPrint('CollectionRepository running in-memory fallback: $e');
    }
    _initialized = true;
  }
  // ... same pattern as PlaylistRepository
}
```

---

## 4. Riverpod Providers

```dart
// lib/features/collections/presentation/providers/collections_provider.dart

/// Injectable repository (override in tests with InMemoryCollectionRepository).
final collectionRepositoryProvider = Provider<ICollectionRepository>(
  (ref) => CollectionRepository(),
);

/// User's collection vault, newest first.
final collectionsProvider =
    StateNotifierProvider<CollectionsNotifier, List<CollectionEntity>>((ref) {
  final notifier = CollectionsNotifier(ref.watch(collectionRepositoryProvider));
  notifier.loadCollections();
  return notifier;
});
```

### `CollectionsNotifier` method signatures

```dart
class CollectionsNotifier extends StateNotifier<List<CollectionEntity>> {
  CollectionsNotifier(this._repository) : super(const []);
  final ICollectionRepository _repository;

  Future<void> loadCollections() async { ... }
  Future<CollectionEntity> createCollection(
    String title,
    CollectionType type, {
    String genre = '',
    String description = '',
    DateTime? releaseDate,
  }) async { ... }
  Future<void> updateCollection(String id, {
    String? title,
    CollectionType? type,
    String? genre,
    String? description,
    DateTime? releaseDate,
  }) async { ... }
  Future<void> deleteCollection(String id) async { ... }
  Future<void> addTrack(String collectionId, String trackId) async { ... }
  Future<void> removeTrack(String collectionId, String trackId) async { ... }
  Future<void> reorderTracks(String collectionId, List<String> newOrder) async { ... }
  Future<void> addParticipant(String collectionId, SplitParticipant p) async { ... }
  Future<void> removeParticipant(String collectionId, String name) async { ... }
  Future<void> updateParticipant(String collectionId, SplitParticipant updated) async { ... }
}
```

---

## 5. Widget Tree

### 5.1 `CollectionsVaultView`

```
CollectionsVaultView (ConsumerStatefulWidget)
  ├── Column
  │   ├── _ActionBar (search + New button)
  │   └── Expanded
  │       ├── (empty) → LibraryEmptyState(category: LibraryCategory.collections)
  │       └── (populated)
  │           ├── GridView.builder → CollectionCard (per collection)
  │           └── (list mode) ListView.separated → CollectionListTile (per collection)
  └── Dialogs (show on demand)
      ├── _CreateCollectionDialog
      └── _RenameCollectionDialog
```

### 5.2 `CollectionCard`

```
Material (color: AppColors.surfaceElevated, shape: RoundedRectangleBorder)
  └── InkWell (onTap: navigate to detail)
      └── Padding
          └── Column
              ├── Expanded → _ArtworkPlaceholder (gradient squircle)
              ├── _TypeBadge chip
              ├── Text(title, AppTypography.bodyLarge)
              └── Text('N songs', AppTypography.caption)
              └── PopupMenuButton([Rename, Delete])
```

### 5.3 `CollectionListTile`

```
Material (color: AppColors.surfaceElevated, shape: RoundedRectangleBorder)
  └── ListTile
      ├── leading: _ArtworkPlaceholder 48×48
      ├── title: Text(title)
      ├── subtitle: Text('N songs • EP')
      └── trailing: PopupMenuButton([Rename, Delete])
```

### 5.4 `CollectionDetailView`

```
Scaffold (backgroundColor: AppColors.surfaceCanvas)
  ├── AppBar (title: liveCollection.title, actions: [PopupMenu(Rename, Delete)])
  └── SingleChildScrollView
      └── Column
          ├── _HeroHeader (artwork 140px + metadata + Play All, Shuffle, Split Sheet)
          ├── SizedBox(height: AppSpacing.lg)
          ├── _SectionHeader('Tracks')
          ├── (empty) → _EmptyTrackPlaceholder
          │   OR
          │   ReorderableListView.builder → _TrackRow (drag handle, index, title, meta, ×)
          ├── TextButton.icon('+ Add Track from Library') → opens AddToCollectionSheet
          ├── SizedBox(height: AppSpacing.lg)
          ├── _SectionHeader('Split Sheet Participants')
          ├── _ParticipantList → _ParticipantRow (name, role, %, edit, ×)
          ├── _TotalShareIndicator
          └── TextButton.icon('+ Add Collaborator') → opens AddParticipantDialog
```

### 5.5 `AddToCollectionSheet`

```
DraggableScrollableSheet
  └── Column
      ├── Handle bar + Title 'Add Track'
      ├── TextField (search filter)
      └── ListView.separated
          └── ListTile (track title, artist, genre checkbox → tap to add)
```

### 5.6 `AddParticipantDialog`

```
AlertDialog (backgroundColor: AppColors.surfaceModal)
  ├── title: 'Add Collaborator' or 'Edit Collaborator'
  ├── content: Column
  │   ├── TextField (Name)
  │   ├── TextField (Role, hint: 'Producer, Composer...')
  │   └── TextField (Share %, keyboardType: number)
  └── actions: [Cancel, Save (disabled if invalid)]
```

### 5.7 `SplitSheetModal`

```
(Desktop ≥1024px) Dialog (maxWidth: 520)
(Mobile) showModalBottomSheet (isScrollControlled: true)
  └── SingleChildScrollView
      └── Column
          ├── Title '📄 Split Sheet — {collectionTitle}'
          ├── Metadata section (type, genre, tracks, duration, created)
          ├── Divider
          ├── Participants table (header row + data rows)
          ├── Balance warning (if !isSplitBalanced)
          └── Action row: [Close] [Copy to Clipboard]
```

---

## 6. Token Mapping

| Widget Element | Token |
| :--- | :--- |
| Page canvas | `AppColors.surfaceCanvas` |
| Card/tile surface | `AppColors.surfaceElevated` |
| Card border | `AppColors.borderSubtle` |
| Modal background | `AppColors.surfaceModal` |
| Primary button | `AppColors.brandPrimary` / `AppColors.brandContrast` |
| EP/Single badge bg | `AppColors.badgeCyanBg` |
| EP/Single badge text | `AppColors.badgeCyan` |
| Album/Concept badge bg | `AppColors.amberInset` |
| Album/Concept badge text | `AppColors.brandPrimary` |
| Split total OK | `AppColors.success` |
| Split total error | `AppColors.error` |
| Track row drag handle | `AppColors.textTertiary` |
| Title text | `AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600)` |
| Metadata / subtitle | `AppTypography.caption.copyWith(color: AppColors.textSecondary)` |
| Section headers | `AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600)` |
| Dialog title | `AppTypography.titleMedium` |

---

## 7. Test Scaffolding Notes

### Provider Override Pattern (same as PlaylistsVaultView)

```dart
ProviderScope(
  overrides: [
    collectionRepositoryProvider.overrideWithValue(
      InMemoryCollectionRepository(seed: [myCollection]),
    ),
  ],
  child: MaterialApp(home: CollectionsVaultView()),
)
```

### `libraryTracksProvider` — no override needed
`LibraryTracksNotifier` auto-seeds `lib_track_001` through `lib_track_004` — reference those IDs directly in `CollectionEntity.trackIds` for widget tests.

### `ReorderableListView` — use `onReorderEnd` not deprecated `onReorder`
```dart
ReorderableListView.builder(
  onReorderEnd: (index) { ... },   // ✅ Flutter ≥3.41
  // NOT onReorder — deprecated
  ...
)
```

### `Material` wrapping `ListTile`
Always wrap `ListTile` in `Material` (not `Container` with `decoration`) when a background color is set, to avoid Flutter framework assertions about invisible ink splashes.
