# Phase 12 · Design — Studio Lyrics Review Cockpit & Playlists Queue Management

> **Phase:** 12  
> **Codename:** `lyrics-and-playlists`  
> **Target Framework:** Flutter 3.x+ / Dart 3.x+  
> **State Management:** Flutter Riverpod 2.x+  

---

## 1. Domain Models & Entities

### 1.1 Lyrics Section Models (`lib/features/studio/domain/models/lyrics_review_models.dart`)

```dart
import 'package:flutter/foundation.dart';

enum LyricsSectionType {
  intro,
  verse,
  chorus,
  hook,
  bridge,
  outro,
}

@immutable
class LyricsSection {
  final String id;
  final LyricsSectionType type;
  final String header; // e.g., "[Verse 1] • 8 bars"
  final List<String> lines;
  final List<String> rhymeNotes;

  const LyricsSection({
    required this.id,
    required this.type,
    required this.header,
    required this.lines,
    this.rhymeNotes = const [],
  });

  LyricsSection copyWith({
    String? id,
    LyricsSectionType? type,
    String? header,
    List<String>? lines,
    List<String>? rhymeNotes,
  }) {
    return LyricsSection(
      id: id ?? this.id,
      type: type ?? this.type,
      header: header ?? this.header,
      lines: lines ?? this.lines,
      rhymeNotes: rhymeNotes ?? this.rhymeNotes,
    );
  }

  String toFormattedString() {
    return '$header\n${lines.join('\n')}';
  }
}

@immutable
class LyricsReviewDraft {
  final String prompt;
  final String genre;
  final String language;
  final List<LyricsSection> sections;
  final List<String> culturalIdioms;
  final bool isRawEditorMode;
  final String rawText;

  const LyricsReviewDraft({
    required this.prompt,
    required this.genre,
    required this.language,
    required this.sections,
    this.culturalIdioms = const [],
    this.isRawEditorMode = false,
    required this.rawText,
  });

  LyricsReviewDraft copyWith({
    String? prompt,
    String? genre,
    String? language,
    List<LyricsSection>? sections,
    List<String>? culturalIdioms,
    bool? isRawEditorMode,
    String? rawText,
  }) {
    return LyricsReviewDraft(
      prompt: prompt ?? this.prompt,
      genre: genre ?? this.genre,
      language: language ?? this.language,
      sections: sections ?? this.sections,
      culturalIdioms: culturalIdioms ?? this.culturalIdioms,
      isRawEditorMode: isRawEditorMode ?? this.isRawEditorMode,
      rawText: rawText ?? this.rawText,
    );
  }
}
```

### 1.2 Playlist Domain Entities (`lib/features/playlists/domain/models/playlist_entity.dart`)

```dart
import 'package:flutter/foundation.dart';

@immutable
class PlaylistEntity {
  final String id;
  final String title;
  final String description;
  final String? coverImageUrl;
  final List<String> trackIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPublic;

  const PlaylistEntity({
    required this.id,
    required this.title,
    this.description = '',
    this.coverImageUrl,
    this.trackIds = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isPublic = true,
  });

  int get trackCount => trackIds.length;

  PlaylistEntity copyWith({
    String? id,
    String? title,
    String? description,
    String? coverImageUrl,
    List<String>? trackIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPublic,
  }) {
    return PlaylistEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      trackIds: trackIds ?? this.trackIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPublic: isPublic ?? this.isPublic,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'cover_image_url': coverImageUrl,
    'track_ids': trackIds,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'is_public': isPublic,
  };

  factory PlaylistEntity.fromJson(Map<String, dynamic> json) {
    return PlaylistEntity(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      coverImageUrl: json['cover_image_url'] as String?,
      trackIds: (json['track_ids'] as List<dynamic>?)?.cast<String>() ?? const [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isPublic: json['is_public'] as bool? ?? true,
    );
  }
}
```

---

## 2. Services & Repository Layer

### 2.1 Lyrics Generation Service Interface (`lib/features/studio/domain/services/i_lyrics_generation_service.dart`)

```dart
abstract class ILyricsGenerationService {
  Future<LyricsReviewDraft> generateLyrics({
    required String prompt,
    required String genre,
    required String language,
  });

  List<String> getCulturalIdioms(String language);
}
```

* **`FakeLyricsGenerationService`**: Provides deterministic generation with authentic Tshivenḓa, isiZulu, Sepedi, Swahili, and Amapiano lyrical stanzas without backend network calls.
* **`LyricsGenerationService`**: Connects to the Vhunambi LLM synthesis worker endpoint.

### 2.2 Playlist Repository Interface (`lib/features/playlists/domain/repositories/i_playlist_repository.dart`)

```dart
abstract class IPlaylistRepository {
  Future<List<PlaylistEntity>> getAllPlaylists();
  Future<PlaylistEntity?> getPlaylistById(String id);
  Future<void> savePlaylist(PlaylistEntity playlist);
  Future<void> deletePlaylist(String id);
  Future<void> addTrackToPlaylist(String playlistId, String trackId);
  Future<void> removeTrackFromPlaylist(String playlistId, String trackId);
}
```

* **`PlaylistRepository`**: Backed by Hive box `playlistsBoxKey` in production with JSON fallback.
* **`InMemoryPlaylistRepository`**: In-memory test double for zero-disk headless test isolation.

---

## 3. Riverpod Providers & State Notifiers

### 3.1 Lyrics Review Notifier (`lib/features/studio/presentation/providers/lyrics_review_provider.dart`)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/lyrics_review_models.dart';
import '../../domain/services/i_lyrics_generation_service.dart';
import '../../data/services/fake_lyrics_generation_service.dart';

final lyricsGenerationServiceProvider = Provider<ILyricsGenerationService>((ref) {
  return FakeLyricsGenerationService();
});

final lyricsReviewProvider = StateNotifierProvider<LyricsReviewNotifier, LyricsReviewDraft?>((ref) {
  final service = ref.watch(lyricsGenerationServiceProvider);
  return LyricsReviewNotifier(service);
});

class LyricsReviewNotifier extends StateNotifier<LyricsReviewDraft?> {
  final ILyricsGenerationService _service;
  LyricsReviewNotifier(this._service) : super(null);

  Future<void> loadGeneratedLyrics({
    required String prompt,
    required String genre,
    required String language,
  }) async {
    final draft = await _service.generateLyrics(
      prompt: prompt,
      genre: genre,
      language: language,
    );
    state = draft;
  }

  void updateSectionLines(String sectionId, List<String> newLines) {
    if (state == null) return;
    final updated = state!.sections.map((s) {
      if (s.id == sectionId) return s.copyWith(lines: newLines);
      return s;
    }).toList();
    final raw = updated.map((s) => s.toFormattedString()).join('\n\n');
    state = state!.copyWith(sections: updated, rawText: raw);
  }

  void insertIdiom(String idiom, {String? targetSectionId}) {
    if (state == null || state!.sections.isEmpty) return;
    final targetId = targetSectionId ?? state!.sections.first.id;
    final updated = state!.sections.map((s) {
      if (s.id == targetId) {
        return s.copyWith(lines: [...s.lines, idiom]);
      }
      return s;
    }).toList();
    final raw = updated.map((s) => s.toFormattedString()).join('\n\n');
    state = state!.copyWith(sections: updated, rawText: raw);
  }

  void toggleEditorMode() {
    if (state == null) return;
    state = state!.copyWith(isRawEditorMode: !state!.isRawEditorMode);
  }

  void updateRawText(String raw) {
    if (state == null) return;
    state = state!.copyWith(rawText: raw);
  }

  void clear() {
    state = null;
  }
}
```

### 3.2 Playlists Notifier (`lib/features/playlists/presentation/providers/playlists_provider.dart`)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/playlist_entity.dart';
import '../../domain/repositories/i_playlist_repository.dart';

final playlistRepositoryProvider = Provider<IPlaylistRepository>((ref) {
  throw UnimplementedError('Override with PlaylistRepository or InMemoryPlaylistRepository');
});

final playlistsProvider = StateNotifierProvider<PlaylistsNotifier, List<PlaylistEntity>>((ref) {
  final repo = ref.watch(playlistRepositoryProvider);
  return PlaylistsNotifier(repo);
});

class PlaylistsNotifier extends StateNotifier<List<PlaylistEntity>> {
  final IPlaylistRepository _repo;

  PlaylistsNotifier(this._repo) : super(const []) {
    loadPlaylists();
  }

  Future<void> loadPlaylists() async {
    final list = await _repo.getAllPlaylists();
    state = list;
  }

  Future<PlaylistEntity> createPlaylist(String title, {String description = ''}) async {
    final playlist = PlaylistEntity(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: description,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _repo.savePlaylist(playlist);
    state = [playlist, ...state];
    return playlist;
  }

  Future<void> deletePlaylist(String id) async {
    await _repo.deletePlaylist(id);
    state = state.where((p) => p.id != id).toList();
  }

  Future<void> toggleTrackInPlaylist(String playlistId, String trackId) async {
    final playlist = state.firstWhere((p) => p.id == playlistId);
    if (playlist.trackIds.contains(trackId)) {
      await _repo.removeTrackFromPlaylist(playlistId, trackId);
      state = state.map((p) => p.id == playlistId
          ? p.copyWith(trackIds: p.trackIds.where((id) => id != trackId).toList(), updatedAt: DateTime.now())
          : p).toList();
    } else {
      await _repo.addTrackToPlaylist(playlistId, trackId);
      state = state.map((p) => p.id == playlistId
          ? p.copyWith(trackIds: [...p.trackIds, trackId], updatedAt: DateTime.now())
          : p).toList();
    }
  }
}
```

### 3.3 PlayerNotifier Playback Queue Enhancements

`PlayerNotifier` in `lib/features/player/presentation/providers/player_provider.dart` receives additive queue management methods:

```dart
void addToQueue(Track track) {
  final newQueue = [...state.queue, track];
  state = state.copyWith(queue: newQueue);
}

void playNext(Track track) {
  if (state.queue.isEmpty) {
    playTrack(track);
    return;
  }
  final newQueue = List<Track>.from(state.queue);
  final insertIndex = (state.currentIndex + 1).clamp(0, newQueue.length);
  newQueue.insert(insertIndex, track);
  state = state.copyWith(queue: newQueue);
}

void removeFromQueue(int index) {
  if (index < 0 || index >= state.queue.length) return;
  final newQueue = List<Track>.from(state.queue)..removeAt(index);
  int newIndex = state.currentIndex;
  if (index < state.currentIndex) {
    newIndex--;
  } else if (index == state.currentIndex && newQueue.isNotEmpty) {
    newIndex = newIndex % newQueue.length;
  }
  state = state.copyWith(
    queue: newQueue,
    currentIndex: newIndex,
  );
}

void reorderQueue(int oldIndex, int newIndex) {
  if (oldIndex < 0 || oldIndex >= state.queue.length) return;
  final newQueue = List<Track>.from(state.queue);
  if (newIndex > oldIndex) newIndex -= 1;
  final item = newQueue.removeAt(oldIndex);
  newQueue.insert(newIndex, item);

  // Recalculate current index if active track moved
  int updatedCurrent = state.currentIndex;
  if (state.currentIndex == oldIndex) {
    updatedCurrent = newIndex;
  } else if (oldIndex < state.currentIndex && newIndex >= state.currentIndex) {
    updatedCurrent--;
  } else if (oldIndex > state.currentIndex && newIndex <= state.currentIndex) {
    updatedCurrent++;
  }

  state = state.copyWith(queue: newQueue, currentIndex: updatedCurrent);
}

void clearUpcomingQueue() {
  if (state.currentTrack == null) {
    state = state.copyWith(queue: const [], currentIndex: -1);
    return;
  }
  state = state.copyWith(
    queue: [state.currentTrack!],
    currentIndex: 0,
  );
}

void playPlaylist(PlaylistEntity playlist, List<Track> tracks) {
  if (tracks.isEmpty) return;
  playTrack(tracks.first, queue: tracks);
}
```

---

## 4. Widget Hierarchy & Presentation Tree

### 4.1 Subsystem A: Lyrics Review UI

```
LyricsReviewModal (Dialog on Desktop / Sheet on Mobile)
├── _LyricsReviewHeader (Title, Genre badge, Language pill, Close)
├── SingleChildScrollView
│   ├── _PromptSummaryCard (Prompt excerpt, generation seed info)
│   ├── if (!isRawEditorMode)
│   │   ├── ListView.builder: _LyricsSectionCard
│   │   │   ├── _SectionHeaderBadge ([Verse 1] / [Chorus], edit icon)
│   │   │   └── _EditableLineRows (inline text inputs)
│   │   └── _CulturalIdiomsRail (Horizontal scrollable chip rail)
│   └── else
│       └── _RawMultilineLyricsEditor (Markdown text field)
└── _LyricsReviewActionBar
    ├── OutlinedButton ('Regenerate Lyrics')
    ├── TextButton ('Toggle Raw Editor')
    └── ElevatedButton.icon ('Approve & Produce Beat ➔', #F97316)
```

### 4.2 Subsystem B: Playlists & Queue UI

```
QueueDrawer (Desktop Side Drawer / Mobile Bottom Sheet)
├── _QueueDrawerHeader (Title 'Playback Queue', count pill, 'Clear' action, Close)
├── _NowPlayingCard (Thumbnail, title, artist, live equalizer bars)
└── Expanded: ReorderableListView.builder
    └── _QueueTrackTile
        ├── DragHandle (Icons.drag_handle_rounded)
        ├── Artwork thumbnail (40x40 squircle)
        ├── Title & Artist metadata
        ├── Duration text
        └── IconButton: Remove (Icons.close_rounded)

AddToPlaylistSheet (Bottom Sheet)
├── _SheetHeader (Title 'Add to Playlist', track title)
├── _SearchField (Filter user playlists)
├── OutlinedButton ('+ Create New Playlist')
├── Expanded: ListView.builder: _PlaylistCheckboxTile
└── ElevatedButton ('Done')

LibraryPlaylistsView (Mounted at /library tab 1)
├── if (playlists.isEmpty)
│   └── LibraryEmptyState ('No playlists yet', 'Create your first playlist')
└── else
    └── ResponsiveGrid (2 cols Mobile / 4 cols Desktop): PlaylistCard
```
