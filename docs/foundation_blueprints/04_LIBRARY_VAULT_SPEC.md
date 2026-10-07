# Blueprint 04: Library & Asset Vault Specification (`04_LIBRARY_VAULT_SPEC.md`)

> **Target Platform:** Flutter 3.x+ / Dart 3.x+ (Windows, macOS, Android, iOS)  
> **Route Path:** `/library`  
> **State Management:** Flutter Riverpod 2.x+  
> **Local Storage / Offline Cache:** Hive / Isar / SQLite  
> **Source Origin:** Production Web Client (`https://vhunambi.com/library`)

---

## 1. Responsive Scaffolding (Mobile vs Desktop)

The User Library (`/library`) acts as the personal vault for user-generated tracks, stems, curated playlists, licensing certificates, and offline audio downloads. The UI adapts responsively between touch-optimized mobile screens and high-density desktop production environments.

```
Desktop Scaffolding (> 1024px):
┌──────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ [ < ] (🎵) VHUNAMBI                 My Library               [⚡ 10 songs left] [🔔] [📊 Analytics] [⋮] [✨ Create] │
└──────────────────────────────────────────────────────────────────────────────────────────────────────┘
│                                                                                                      │
│  [ ♪ Songs ]  [ ≡♪ Playlists ]  [ 💿 Collections ]  [ 🛍️ Beats ]  [ ⚖️ Licensing ]  [ 🗑️ Trash ]        │
│                                                                                                      │
│                                                ┌────┐                                                │
│                                                │ ♪  │  <-- Squircle Container (48x48, #141418)       │
│                                                └────┘                                                │
│                                             No songs yet                                             │
│                  Head to the Studio and generate your first song — it'll appear here instantly.      │
│                                      [ ✨ Create your first song ]                                    │
└──────────────────────────────────────────────────────────────────────────────────────────────────────┘

Mobile PWA Scaffolding (< 600px):
┌──────────────────────────────────────────────────────────────────────┐
│ (🎵) VHUNAMBI                   [⚡ 10 songs left]  [🔔]  [⋮]  [✨]  │ <-- Mobile Header
├──────────────────────────────────────────────────────────────────────┤
│ [ ♪ Songs ]  [ ≡♪ Playlists ]  [ 💿 Collections ]  [ 🛍️ Beats ] ...  │ <-- Horizontal Rail
│                                                                      │
│                                ┌────┐                                │
│                                │ ♪  │                                │
│                                └────┘                                │
│                             No songs yet                             │
│                  Head to the Studio and generate your                │
│                 first song — it'll appear here instantly.            │
│                                                                      │
│                     [ ✨ Create your first song ]                    │
│                                                                      │
├──────────────────────────────────────────────────────────────────────┤
│    [Home]        [Explore]        [✨ Create]     ─[Library]─  [Market]│ <-- Active Orange Bar
└──────────────────────────────────────────────────────────────────────┘
```

---

### 1.1 Top App Bar Scaffolding

| Control / Element | Mobile Viewport (<600px) | Desktop Viewport (>1024px) |
| :--- | :--- | :--- |
| **Leading Brand Group** | Brand circle badge + `"VHUNAMBI"` wordmark | Back chevron (`<`) + Brand circle badge + `"VHUNAMBI"` |
| **Center Breadcrumb** | *Hidden (Conserves horizontal space)* | `"My Library"` (`fontSize: 14`, `#9CA3AF`) |
| **Credit Balance** | Pill badge: `⚡ 10 songs left` | Pill badge: `⚡ 10 songs left` |
| **Notification Bell** | Icon button `🔔` (`#9CA3AF`) | Icon button `🔔` (`#9CA3AF`) |
| **Analytics Action** | *Hidden in mobile header* | `📊 Analytics` button (`#141418`, border `#2D2D38`) |
| **Overflow Menu (`⋮`)** | Dark pill container with vertical dots | Vertical three dots icon button |
| **Primary CTA** | Orange square button `[✨]` with sparkle | Solid orange pill button `[✨ Create]` with label |

---

### 1.2 Bottom Navigation Dock (Mobile) vs Navigation Rail (Desktop)

* **Mobile Navigation Dock:**
  * Fixed bottom dock (`height: 64px`, background `#141418`).
  * Tab destination: `Library` index `3`.
  * **Active State:** Orange highlight label (`color: #F97316`), vertical book/library glyph (`color: #F97316`), and an accent indicator line (`height: 2px`, `color: #F97316`) positioned directly above the icon.
* **Desktop Navigation Dock:**
  * Persistent top-level navigation bar or left-hand `NavigationRail` with persistent access to all studio assets.

---

## 2. Library Navigation & Category Tabs

A horizontally scrollable pill rail positioned directly beneath the top header:

```
┌────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ [ ♪ Songs ]   [ ≡♪ Playlists ]   [ 💿 Collections ]   [ 🛍️ Beats ]   [ ⚖️ Licensing ]   [ 🗑️ Trash ] │
└────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### 2.1 Tab Taxonomy & Metadata Contracts

| Tab Index | Tab Label & Icon | Target Asset Type | Primary Capabilities |
| :---: | :--- | :--- | :--- |
| **0** | `♪ Songs` (Active) | Individual generated music tracks | Playback, stem separation, download, lyrics view, licensing export |
| **1** | `≡♪ Playlists` | User-curated custom playlists | Create playlist, reorder queue, collaborative playlist sharing |
| **2** | `💿 Collections` | EPs, albums, concept projects | Multi-track grouping, unified artwork, album-level export |
| **3** | `🛍️ Beats` | Standalone instrumental beats | Beat-store listing, BPM tags, key tags, stem package exports |
| **4** | `⚖️ Licensing` | Commercial certificates & split sheets | Ownership certificates, PDF download, synchronization licenses |
| **5** | `🗑️ Trash` | Soft-deleted audio tracks | 30-day purge grace period, one-tap restore, permanent wipe |

### 2.2 Category Pill Styling Tokens

* **Active Category Pill (`♪ Songs`):**
  * Background: `#F97316` (`AppColors.brandPrimary`).
  * Text & Icon Color: `#000000` (`AppColors.brandContrast`).
  * Font Weight: `FontWeight.w700`.
  * Padding: `8px 18px`.
  * Border Radius: `9999px` (Full pill).
* **Inactive Category Pill:**
  * Background: `#141418` (`surfaceElevated`) / `#1B1B22`.
  * Border: `1px solid #2D2D38` (`borderSubtle`).
  * Text & Icon Color: `#9CA3AF` (`textSecondary`).
  * Font Weight: `FontWeight.w500`.
  * Hover / Press: Text `#FFFFFF`, border `#4B4B5A`.

---

## 3. View States Specification

### 3.1 Empty State Pattern (Universal Design Token)

When the active category contains zero records:

```
┌────────────────────────────────────────────────────────┐
│                        ┌────┐                          │
│                        │ ♪  │   <-- 48x48 Squircle     │
│                        └────┘                          │
│                                                        │
│                     No songs yet                       │  <-- 20px Bold Header
│                                                        │
│          Head to the Studio and generate your          │  <-- 14px Muted Description
│         first song — it'll appear here instantly.      │
│                                                        │
│             ┌─────────────────────────────┐            │
│             │  ✨ Create your first song   │            │  <-- Solid Orange Pill CTA
│             └─────────────────────────────┘            │
└────────────────────────────────────────────────────────┘
```

1. **Centered Squircle Glyph Container:**
   * Dimensions: `48x48px`.
   * Surface: `#141418`, border `1px solid #2D2D38`.
   * Border Radius: `14px`.
   * Icon: Musical note vector (`color: #FFFFFF`, `size: 22`).
2. **Headline:**
   * Text: `"No songs yet"` (or `"No playlists yet"`, `"No collections yet"`).
   * Styling: `fontSize: 20`, `fontWeight: FontWeight.bold`, `color: #FFFFFF`.
   * Margin Bottom: `8px`.
3. **Helper Copy:**
   * Text: `"Head to the Studio and generate your first song — it'll appear here instantly."`
   * Styling: `fontSize: 14`, `color: #9CA3AF`, `textAlign: TextAlign.center`, `height: 1.5`.
   * Max Width: `340px`.
   * Margin Bottom: `24px`.
4. **Primary Call-to-Action:**
   * Pill Button: `✨ Create your first song`.
   * Background: `#F97316`, Text `#000000` (`fontWeight: FontWeight.bold`).
   * Action: Pushes `/create` (Studio Cockpit).

---

### 3.2 Populated Audio Vault (Grid & List Views)

When tracks exist in the library, users can switch between a **2-Column Square Grid** and a **Dense Track List**:

```
┌────────────────────────────────────────────────────────────────────────┐
│ [ 🔍 Search my songs...           ]     [ 🎛️ Filter ]  [ ⊞ Grid / ☰ List ] │
├────────────────────────────────────────────────────────────────────────┤
│ ┌────┬───────────────────────────────────────────┬──────────────┬─────┐│
│ │ 🎹 │ Grateful in the Light                     │ Amapiano     │ [⋮] ││
│ │    │ 3:36 • Created 2 hours ago                │ ⬇️ Offline   │     ││
│ └────┴───────────────────────────────────────────┴──────────────┴─────┘│
│ ┌────┬───────────────────────────────────────────┬──────────────┬─────┐│
│ │ 🎸 │ Township Sunset                           │ Maskandi     │ [⋮] ││
│ │    │ 4:12 • Created yesterday                  │ ☁️ Cloud     │     ││
│ └────┴───────────────────────────────────────────┴──────────────┴─────┘│
└────────────────────────────────────────────────────────────────────────┘
```

#### Contextual Action Bottom Sheet / Menu (`TrackActionsSheet`):
Triggered by tapping the vertical three dots (`[⋮]`) on any library item:
* `▶ Play Now`: Inserts track at the top of the queue and begins playback.
* `➕ Add to Playlist`: Opens modal sheet to append track to an existing or new playlist.
* `🎛️ Stem Separation`: Initiates backend 4-stem split (Vocals, Drums, Bass, Other).
* `⬇️ Download Offline`: Caches MP3/FLAC and metadata locally on device storage.
* `⚖️ View Commercial License`: Displays PDF license certificate & ownership hash.
* `🔗 Share Song`: Generates public web preview link (`https://vhunambi.com/track/{id}`).
* `🗑️ Move to Trash`: Soft-deletes the track to the `Trash` category.

---

## 4. Native Offline Storage & State Architecture (Hive / Riverpod)

```
┌────────────────────────────────────────────────────────────────────────┐
│                             LibraryView                                │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │ ref.watch(libraryTracksProvider)
                                     ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        LibraryTracksNotifier                           │
│  - fetchCloudTracks()                 - cacheTrackOffline(id)          │
│  - deleteTrack(id)                    - restoreTrack(id)               │
│  - filterByCategory(LibraryCategory)  - searchTracks(query)            │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │
                 ┌───────────────────┴───────────────────┐
                 ▼                                       ▼
┌─────────────────────────────────┐   ┌──────────────────────────────────┐
│        Supabase API / CDN       │   │        Local Hive Storage        │
│   (Remote Database & Audio S3)  │   │  (Offline Audio Files & Metadata)│
└─────────────────────────────────┘   └──────────────────────────────────┘
```

### 4.1 Local Persistence Entity (`CachedTrackEntity`)

```dart
// lib/features/library/domain/models/cached_track_entity.dart
import 'package:hive/hive.dart';

part 'cached_track_entity.g.dart';

enum SyncStatus { synced, downloading, cachedLocally, error }

@HiveType(typeId: 1)
class CachedTrackEntity extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String creatorName;

  @HiveField(3)
  final String genre;

  @HiveField(4)
  final String language;

  @HiveField(5)
  final int durationSeconds;

  @HiveField(6)
  final String remoteAudioUrl;

  @HiveField(7)
  final String? localAudioFilePath;

  @HiveField(8)
  final String? localCoverImagePath;

  @HiveField(9)
  final DateTime createdAt;

  @HiveField(10)
  final String licenseType; // 'Commercial', 'Personal', 'PublicDomain'

  @HiveField(11)
  final List<double> waveformPoints;

  @HiveField(12)
  final bool isDeleted; // In Trash if true

  @HiveField(13)
  final DateTime? deletedAt;

  CachedTrackEntity({
    required this.id,
    required this.title,
    required this.creatorName,
    required this.genre,
    required this.language,
    required this.durationSeconds,
    required this.remoteAudioUrl,
    this.localAudioFilePath,
    this.localCoverImagePath,
    required this.createdAt,
    this.licenseType = 'Commercial',
    this.waveformPoints = const [],
    this.isDeleted = false,
    this.deletedAt,
  });

  bool get isOfflineAvailable => localAudioFilePath != null;
}
```

### 4.2 Riverpod State Providers

```dart
// lib/features/library/presentation/providers/library_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/cached_track_entity.dart';

enum LibraryCategory { songs, playlists, collections, beats, licensing, trash }

final libraryCategoryProvider = StateProvider<LibraryCategory>((ref) => LibraryCategory.songs);
final librarySearchQueryProvider = StateProvider<String>((ref) => '');

final userTracksProvider = StreamProvider<List<CachedTrackEntity>>((ref) async* {
  final category = ref.watch(libraryCategoryProvider);
  final searchQuery = ref.watch(librarySearchQueryProvider).toLowerCase();

  // Watch local Hive box stream combined with cloud fetch
  final box = await Hive.openBox<CachedTrackEntity>('library_tracks');
  
  yield* box.watch().map((_) {
    return box.values.where((track) {
      if (category == LibraryCategory.trash) {
        return track.isDeleted;
      }
      if (track.isDeleted) return false;

      if (category == LibraryCategory.beats) {
        return track.genre.toLowerCase() == 'instrumental';
      }

      if (searchQuery.isNotEmpty && !track.title.toLowerCase().contains(searchQuery)) {
        return false;
      }

      return true;
    }).toList();
  });
});
```

---

## 5. Offline Download Manager & Cache Integrity

* **Storage Directory:**
  * Android: `getApplicationDocumentsDirectory() + /vhunambi_vault/audio/`
  * iOS: `getLibraryDirectory() + /vhunambi_vault/audio/`
  * Desktop (Windows/macOS): `%APPDATA%/vhunambi/vault/audio/`
* **Download Flow:**
  1. Stream remote audio file with progress emission (`downloadProgressProvider`).
  2. Verify content length and SHA-256 integrity hash.
  3. Store binary to local filesystem.
  4. Write `localAudioFilePath` record into Hive database box.
  5. Audio player dynamically prefers `localAudioFilePath` if present when user is offline or to conserve network bandwidth.
