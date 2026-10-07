# Phase 12.1 · Design — Playlists Vault Views & Hive Persistence

> **Phase:** 12.1 (Phase 12 Completion Patch)  
> **Codename:** `playlists-vault`  
> **Target Framework:** Flutter 3.x+ / Dart 3.x+  
> **State Management:** Flutter Riverpod 2.x+  

---

## 1. Persistence Layer Architecture

### 1.1 AppConstants Extension (`lib/core/constants/app_constants.dart`)

```dart
// Storage Keys
static const String tokenBoxKey = 'vhunambi_tokens';
static const String tracksBoxKey = 'vhunambi_tracks';
static const String preferencesBoxKey = 'vhunambi_prefs';
static const String playlistsBoxKey = 'vhunambi_playlists'; // Added in Phase 12.1
```

### 1.2 Production Playlist Repository (`lib/features/playlists/data/repositories/playlist_repository.dart`)

```dart
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/models/playlist_entity.dart';
import '../../domain/repositories/i_playlist_repository.dart';

class PlaylistRepository implements IPlaylistRepository {
  Box? _box;
  final Map<String, PlaylistEntity> _inMemoryFallback = {};
  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    try {
      if (!kIsWeb) {
        if (!Hive.isBoxOpen(AppConstants.playlistsBoxKey)) {
          _box = await Hive.openBox(AppConstants.playlistsBoxKey);
        } else {
          _box = Hive.box(AppConstants.playlistsBoxKey);
        }
      }
    } catch (e) {
      debugPrint('PlaylistRepository running in-memory fallback: $e');
    }
    _initialized = true;
  }

  @override
  Future<List<PlaylistEntity>> getAllPlaylists() async {
    await _ensureInit();
    if (_box != null) {
      return _box!.values
          .map((v) => PlaylistEntity.fromJson(Map<String, dynamic>.from(v as Map)))
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    return _inMemoryFallback.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<PlaylistEntity?> getPlaylistById(String id) async {
    await _ensureInit();
    if (_box != null) {
      final raw = _box!.get(id);
      if (raw == null) return null;
      return PlaylistEntity.fromJson(Map<String, dynamic>.from(raw as Map));
    }
    return _inMemoryFallback[id];
  }

  @override
  Future<void> savePlaylist(PlaylistEntity playlist) async {
    await _ensureInit();
    if (_box != null) {
      await _box!.put(playlist.id, playlist.toJson());
    } else {
      _inMemoryFallback[playlist.id] = playlist;
    }
  }

  @override
  Future<void> deletePlaylist(String id) async {
    await _ensureInit();
    if (_box != null) {
      await _box!.delete(id);
    } else {
      _inMemoryFallback.remove(id);
    }
  }

  @override
  Future<void> addTrackToPlaylist(String playlistId, String trackId) async {
    final playlist = await getPlaylistById(playlistId);
    if (playlist == null || playlist.trackIds.contains(trackId)) return;
    final updated = playlist.copyWith(
      trackIds: [...playlist.trackIds, trackId],
      updatedAt: DateTime.now(),
    );
    await savePlaylist(updated);
  }

  @override
  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    final playlist = await getPlaylistById(playlistId);
    if (playlist == null || !playlist.trackIds.contains(trackId)) return;
    final updated = playlist.copyWith(
      trackIds: playlist.trackIds.where((id) => id != trackId).toList(),
      updatedAt: DateTime.now(),
    );
    await savePlaylist(updated);
  }
}
```

---

## 2. Presentation Views & Widget Tree

### 2.1 Playlists Vault View (`lib/features/playlists/presentation/views/playlists_vault_view.dart`)

```
PlaylistsVaultView (ConsumerWidget)
├── if (playlists.isEmpty)
│   └── LibraryEmptyState (category: LibraryCategory.playlists, onCreate: showCreateDialog)
└── else
    └── Column
        ├── _PlaylistsHeaderActions (Search, '+ New Playlist', Grid/List switch)
        └── Expanded
            └── if (viewMode == LibraryViewMode.grid)
                └── GridView.builder: PlaylistCard
                    ├── 1:1 Aspect Ratio Cover Mosaic (up to 4 tracks)
                    ├── Title (AppTypography.titleSmall)
                    ├── Metadata ("X songs • Y mins")
                    └── PopupMenuButton [⋮] (Rename, Delete)
                else
                └── ListView.separated: PlaylistListTile
```

### 2.2 Playlist Detail View (`lib/features/playlists/presentation/views/playlist_detail_view.dart`)

```
PlaylistDetailView (ConsumerStatefulWidget)
├── AppBar (Back chevron, Title 'Playlist Details', [⋮] Rename / Delete)
└── SingleChildScrollView
    ├── _PlaylistHeroHeader
    │   ├── 1:1 Square Artwork Container (140x140)
    │   ├── Title (22px bold)
    │   ├── Description (14px muted)
    │   └── Metrics chip row (Track count, cumulative duration)
    ├── _PlaylistActionDeck
    │   ├── ElevatedButton ('▶ Play All', solid #F97316)
    │   └── OutlinedButton ('🔀 Shuffle', inset #1B1B22)
    └── _PlaylistTrackTable
        └── ListView.builder: _PlaylistTrackRow
            ├── Index (#1, #2...)
            ├── Artwork thumbnail (40x40 squircle)
            ├── Title & Artist (clickable to play single track)
            ├── Genre badge & Duration
            └── IconButton (Icons.close_rounded: remove from playlist)
```

---

## 3. Integration Points

1. **`lib/features/playlists/presentation/providers/playlists_provider.dart`:**  
   Update default `playlistRepositoryProvider` to instantiate `PlaylistRepository()`.
2. **`lib/features/library/presentation/views/library_view.dart`:**  
   When `category == LibraryCategory.playlists`, render `PlaylistsVaultView(onCreateRequested: onCreateRequested)` instead of generic track projection.
