# Phase 4 Design Specification: Library & User Asset Vault (`/library`)

> **Package:** `apps/vhunambi_client`  
> **Feature Directory:** `lib/features/library/`  
> **State Engine:** Riverpod 2.x+

---

## 1. Domain Models & Enums

### 1.1 Enums (`lib/features/library/domain/models/library_models.dart`)
```dart
enum LibraryCategory {
  songs,
  playlists,
  collections,
  beats,
  licensing,
  trash,
}

enum LibraryViewMode {
  list,
  grid,
}

enum TrackSyncStatus {
  synced,
  downloading,
  cachedLocally,
  cloudOnly,
  error,
}
```

### 1.2 `LibraryTrack` Class
```dart
@immutable
class LibraryTrack {
  final String id;
  final String title;
  final String creatorName;
  final String genre;
  final String language;
  final int durationSeconds;
  final String remoteAudioUrl;
  final String? localAudioFilePath;
  final String? coverImageUrl;
  final DateTime createdAt;
  final String licenseType;
  final bool isDeleted;
  final DateTime? deletedAt;
  final TrackSyncStatus syncStatus;

  const LibraryTrack({
    required this.id,
    required this.title,
    required this.creatorName,
    required this.genre,
    required this.language,
    required this.durationSeconds,
    required this.remoteAudioUrl,
    this.localAudioFilePath,
    this.coverImageUrl,
    required this.createdAt,
    this.licenseType = 'Commercial',
    this.isDeleted = false,
    this.deletedAt,
    this.syncStatus = TrackSyncStatus.cloudOnly,
  });

  bool get isOfflineAvailable => localAudioFilePath != null;
  String get formattedDuration => '${durationSeconds ~/ 60}:${(durationSeconds % 60).toString().padLeft(2, '0')}';

  LibraryTrack copyWith({ ... });
}
```

---

## 2. Riverpod State Providers (`lib/features/library/presentation/providers/library_providers.dart`)

```dart
final libraryCategoryProvider =
    StateProvider<LibraryCategory>((ref) => LibraryCategory.songs);

final librarySearchQueryProvider =
    StateProvider<String>((ref) => '');

final libraryViewModeProvider =
    StateProvider<LibraryViewMode>((ref) => LibraryViewMode.list);

final libraryTracksProvider =
    StateNotifierProvider<LibraryTracksNotifier, List<LibraryTrack>>((ref) {
  return LibraryTracksNotifier();
});
```

### `LibraryTracksNotifier` Methods:
- `addTrack(LibraryTrack track)`
- `deleteTrack(String id)` (Marks `isDeleted: true`)
- `restoreTrack(String id)` (Marks `isDeleted: false`)
- `purgeTrackPermanently(String id)`
- `setTrackOfflinePath(String id, String path)`

---

## 3. UI Component Hierarchy

```
LibraryView
├── LibraryAppBar (Sticky responsive header)
├── LibraryCategoryRail (Horizontal pill slider)
└── Expanded
    ├── LibraryEmptyState (When filtered tracks are empty)
    └── Populated Vault
        ├── Search & ViewMode Toggle Strip
        ├── ListView (if viewMode == list) -> LibraryTrackTile
        └── GridView (if viewMode == grid) -> LibraryTrackGridCard
```

### Contextual Actions Modal:
`TrackActionsSheet.show(BuildContext context, LibraryTrack track)`

---

## 4. Integration into RootShell

In `apps/vhunambi_client/lib/main.dart`:
```dart
// Replace tab index 3 in _pages:
_pages = [
  Scaffold(body: Center(child: Text('Home View'))),
  ExploreView(),
  StudioView(),
  LibraryView(), // <-- Phase 4 Integration
  Scaffold(body: Center(child: Text('Marketplace'))),
];
```
