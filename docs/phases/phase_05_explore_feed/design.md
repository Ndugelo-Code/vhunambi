# Phase 5 Design Specification: Explore Feed & Music Discovery (`/explore`)

> **Package:** `apps/vhunambi_client`  
> **Feature Directory:** `lib/features/explore/`  
> **State Engine:** Flutter Riverpod 2.x+

---

## 1. Domain Models & Enums

### 1.1 Enums (`lib/features/explore/domain/models/explore_models.dart`)
```dart
enum ExploreTab {
  discover,
  forYou,
  following,
}

enum ExploreSortBy {
  newest,
  mostLiked,
}
```

### 1.2 `CreatorProfile` Class
```dart
@immutable
class CreatorProfile {
  final String id;
  final String name;
  final String handle;
  final String initials;
  final int trackCount;
  final String? avatarUrl;
  final List<String> primaryGenres;
  final bool isVerified;

  const CreatorProfile({
    required this.id,
    required this.name,
    required this.handle,
    required this.initials,
    required this.trackCount,
    this.avatarUrl,
    this.primaryGenres = const [],
    this.isVerified = false,
  });

  String get trackCountLabel => '$trackCount songs';
}
```

### 1.3 `Track` Model Compatibility
The Explore feed utilizes the existing shared track entity from `lib/shared/models/track.dart`:
```dart
class Track {
  final String id;
  final String title;
  final String creatorName;
  final String? creatorAvatarUrl;
  final String genre;
  final String language;
  final Duration duration;
  final String? audioUrl;
  final String? coverUrl;
  final int likeCount;
  final int playCount;
  final bool isNew;
  final int? trendingRank;
  final String? mood; // Optional additive field for explore mood filtering
}
```

---

## 2. Riverpod State Providers (`lib/features/explore/presentation/providers/explore_providers.dart`)

```dart
final exploreTabProvider = StateProvider<ExploreTab>((ref) => ExploreTab.discover);

final exploreSearchQueryProvider = StateProvider<String>((ref) => '');

final exploreGenreFilterProvider = StateProvider<String>((ref) => 'All');

final exploreMoodFilterProvider = StateProvider<String?>((ref) => null);

final exploreLanguageFilterProvider = StateProvider<String>((ref) => 'All');

final exploreSortByProvider = StateProvider<ExploreSortBy>((ref) => ExploreSortBy.newest);

final exploreCreatorsProvider = Provider<List<CreatorProfile>>((ref) {
  return const [
    CreatorProfile(id: 'c1', name: 'Sigwa & Inaf', handle: '@sigwa_inaf', initials: 'SI', trackCount: 96, primaryGenres: ['Amapiano']),
    CreatorProfile(id: 'c2', name: 'Ndugelo', handle: '@ndugelo', initials: 'ND', trackCount: 21, primaryGenres: ['Maskandi']),
    CreatorProfile(id: 'c3', name: 'DJ Vibe', handle: '@djvibe', initials: 'DJ', trackCount: 45, primaryGenres: ['Gqom']),
    CreatorProfile(id: 'c4', name: 'Fifi', handle: '@fifi', initials: 'FI', trackCount: 32, primaryGenres: ['Amapiano']),
    CreatorProfile(id: 'c5', name: 'Sipho', handle: '@sipho', initials: 'SP', trackCount: 18, primaryGenres: ['Kwaito']),
    CreatorProfile(id: 'c6', name: 'Lerato', handle: '@lerato', initials: 'LR', trackCount: 64, primaryGenres: ['Afro House']),
  ];
});

final exploreTracksProvider = StateNotifierProvider<ExploreTracksNotifier, List<Track>>((ref) {
  return ExploreTracksNotifier();
});

final filteredExploreTracksProvider = Provider<List<Track>>((ref) {
  final tracks = ref.watch(exploreTracksProvider);
  final query = ref.watch(exploreSearchQueryProvider).trim().toLowerCase();
  final genre = ref.watch(exploreGenreFilterProvider);
  final mood = ref.watch(exploreMoodFilterProvider);
  final language = ref.watch(exploreLanguageFilterProvider);
  final sortBy = ref.watch(exploreSortByProvider);

  return filterExploreTracks(
    tracks: tracks,
    query: query,
    genre: genre,
    mood: mood,
    language: language,
    sortBy: sortBy,
  );
});
```

### 2.1 Audio Playback Bridge Helper
```dart
void playExploreTrack(WidgetRef ref, Track track) {
  final playerNotifier = ref.read(playerStateProvider.notifier);
  final allTracks = ref.read(exploreTracksProvider);
  playerNotifier.setQueue(allTracks, startIndex: allTracks.indexOf(track));
  playerNotifier.play();
}
```

---

## 3. Presentation Widget Tree & Hierarchy

```
ExploreView (CustomScrollView with Slivers)
├── SliverToBoxAdapter: ExploreTopBar (Responsive Desktop 68px vs Mobile 56px)
├── SliverToBoxAdapter: ExploreHeaderSection (Title, Subtitle, Segmented Tabs, Streak Badge)
├── SliverToBoxAdapter: AfricanChartsBanner (Terracotta-to-Tangerine hero card)
├── SliverToBoxAdapter: SectionHeader (title: 'New This Week')
├── SliverPadding -> SliverGrid: TrackCard (6-col Desktop / 2-col Mobile)
├── SliverToBoxAdapter: SectionHeader (title: 'Rising')
├── SliverPadding -> SliverGrid or SliverList: TrackListTile (2-col Split Desktop / 1-col Mobile)
├── SliverToBoxAdapter: SectionHeader (title: 'Featured Creators')
├── SliverPadding -> SliverGrid: CreatorCard (6-col single row Desktop / 2-col Mobile)
├── SliverToBoxAdapter: SectionHeader (title: 'Genre Radio')
├── SliverPadding -> SliverGrid: GenreRadioTile (6x2 Desktop / 2x6 Mobile)
├── SliverToBoxAdapter: CatalogFilterBar (Genre rail, mood wrap, language selector, sort pills)
├── SliverPadding -> SliverGrid: Catalog Track Cards or ExploreEmptyState
└── SliverToBoxAdapter: Desktop Load More Button & bottom padding
```

### 3.1 Widget Modules (`lib/features/explore/presentation/widgets/`)
1. **`explore_top_bar.dart`**:
   - `DesktopExploreTopBar` (68px, breadcrumb, search with `Ctrl+K`, credit badge, bell, avatar, `+ Create` CTA).
   - `MobileExploreTopBar` (56px, back/brand, search input pill, compact `+ Create` button).
2. **`explore_header_section.dart`**:
   - Title `"Explore"`, subtitle, segmented pill tabs (`Discover`, `For You`, `Following`), `🔥 2 Streak` badge.
3. **`african_charts_banner.dart`**:
   - `AppGradients.africanChartsBanner`, trendline icon, headline, subtitle, white action pill `"View ->"`.
4. **`track_card.dart`**:
   - 1:1 artwork container, `AppGradients.forGenre(genre)`, instrument vector icon, `✨ NEW` or `#1` trending rank badge, metadata row, footer with likes, plays, handle, and play button wired to `playerStateProvider`.
5. **`track_list_tile.dart`**:
   - 48×48px genre thumbnail, track title, creator, genre, duration, like count, 36×36px orange circular play button.
6. **`creator_card.dart`**:
   - Monogram avatar container, uppercase initials, creator name, `"96 songs"`, `"View profile ->"` action link.
7. **`genre_radio_tile.dart`**:
   - 12 African heritage genres, `AppGradients.forGenre`, glassmorphic `((•)) Play Radio` overlay.
8. **`catalog_filter_bar.dart`**:
   - Horizontal genre pill rail, mood chips wrap (10 emoji moods), language selector, sorting pills (`🔥 Newest` | `❤️ Most Liked`).
9. **`explore_empty_state.dart`**:
   - `Icons.music_off_rounded`, `"No songs match these filters"`, description, `✕ Clear filters` & `✨ Create a song` CTAs.
