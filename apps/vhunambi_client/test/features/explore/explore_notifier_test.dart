import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/features/explore/domain/models/explore_models.dart';
import 'package:vhunambi_client/features/explore/presentation/providers/explore_providers.dart';
import 'package:vhunambi_client/shared/models/track.dart';

void main() {
  group('Explore domain models', () {
    test('CreatorProfile exposes the track count label', () {
      const creator = CreatorProfile(
        id: 'creator_test',
        name: 'Sigwa & Inaf',
        handle: '@sigwa_inaf',
        initials: 'SI',
        trackCount: 96,
        primaryGenres: ['Amapiano'],
      );

      expect(creator.trackCountLabel, '96 songs');
      expect(creator.primaryGenreLabel, 'Amapiano');
      expect(creator.isVerified, isFalse);
    });

    test('CreatorProfile copyWith + equality consider every field', () {
      const base = CreatorProfile(
        id: 'creator_test',
        name: 'Fifi',
        handle: '@fifi',
        initials: 'FI',
        trackCount: 32,
      );

      expect(base, base.copyWith());
      expect(base.hashCode, base.copyWith().hashCode);
      expect(base.copyWith(trackCount: 33).trackCount, 33);
      expect(base.copyWith(isVerified: true).isVerified, isTrue);
      expect(base.copyWith(trackCount: 33) == base, isFalse);
      expect(base.primaryGenreLabel, 'Artist');
    });

    test('Track handleLabel prefers the explicit handle and falls back', () {
      const withHandle = Track(
        id: 't1',
        title: 'A',
        creatorName: 'DJ Vibe',
        creatorHandle: '@djvibe',
        genre: 'Gqom',
        duration: Duration(minutes: 2),
      );
      const withoutHandle = Track(
        id: 't2',
        title: 'B',
        creatorName: 'Sigwa & Inaf',
        genre: 'Amapiano',
        duration: Duration(minutes: 2),
      );

      expect(withHandle.handleLabel, '@djvibe');
      expect(withoutHandle.handleLabel, '@sigwa_inaf');
    });

    test('taxonomy catalogs match the blueprint contracts', () {
      expect(exploreGenreCatalog.length, 12);
      expect(exploreGenreCatalog.first, 'Amapiano');
      expect(exploreGenreCatalog.last, 'Afro-Arabic');
      expect(exploreMoodCatalog.length, 10);
      expect(exploreMoodCatalog.first.value, 'Uplifting');
      expect(exploreMoodCatalog.last.value, 'Dark');
      expect(exploreLanguageCatalog.length, 10);
      expect(exploreLanguageCatalog, contains('Tshivenḓa'));
      expect(exploreAllFilter, 'All');
      expect(ExploreTab.values.length, 3);
      expect(ExploreSortBy.values.length, 2);
    });
  });

  group('Seeded discovery catalog', () {
    test('seeds 8 production tracks with rich metadata', () {
      final tracks = ExploreTracksNotifier().state;

      expect(tracks.length, 8);
      expect(
        tracks.map((track) => track.title),
        containsAll([
          'Grateful in the Light',
          'Ndo Mufuna Matibe',
          'Township Log Drum Heat',
          'Durban Midnight Bass',
          'Kwaito Renaissance',
          'Maskandi Strings of Natal',
          'Afro Sunset Melodies',
          'Lagos Pulse',
        ]),
      );
      expect(tracks.where((track) => track.isNew).length, 1);
      expect(tracks.where((track) => track.trendingRank != null).length, 3);
      expect(tracks.every((track) => track.mood != null), isTrue);
      expect(tracks.every((track) => track.audioUrl != null), isTrue);
    });

    test('seeds 6 creator profiles including the featured deck', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final creators = container.read(exploreCreatorsProvider);
      expect(creators.length, 6);
      expect(
        creators.map((creator) => creator.name),
        containsAll([
          'Sigwa & Inaf',
          'Ndugelo',
          'DJ Vibe',
          'Fifi',
          'Sipho',
          'Lerato',
        ]),
      );
      expect(creators.first.trackCountLabel, '96 songs');
      expect(creators.where((creator) => creator.isVerified).length, 3);
    });

    test('addTrack prepends a freshly published drop', () {
      final notifier = ExploreTracksNotifier();
      const fresh = Track(
        id: 'exp_track_999',
        title: 'Fresh Drop',
        creatorName: 'Tester',
        genre: 'Amapiano',
        duration: Duration(minutes: 3),
      );

      notifier.addTrack(fresh);
      expect(notifier.state.length, 9);
      expect(notifier.state.first, fresh);
    });
  });

  group('filterExploreTracks', () {
    final tracks = ExploreTracksNotifier().state;

    test('no filters returns the full catalog in curated order', () {
      final result = filterExploreTracks(tracks: tracks);
      expect(result.length, 8);
      expect(result.first.title, 'Grateful in the Light');
    });

    test('genre filter scopes to a single genre', () {
      expect(
        filterExploreTracks(tracks: tracks, genre: 'Amapiano').length,
        3,
      );
      expect(filterExploreTracks(tracks: tracks, genre: 'Gqom').length, 1);
      expect(
        filterExploreTracks(tracks: tracks, genre: 'Afro House')
            .single
            .title,
        'Afro Sunset Melodies',
      );
      expect(filterExploreTracks(tracks: tracks, genre: 'All').length, 8);
    });

    test('mood filter scopes to a single mood chip', () {
      expect(
        filterExploreTracks(tracks: tracks, mood: 'Energetic').length,
        2,
      );
      expect(
        filterExploreTracks(tracks: tracks, mood: 'Dark').single.title,
        'Durban Midnight Bass',
      );
      expect(filterExploreTracks(tracks: tracks, mood: 'Angry'), isEmpty);
    });

    test('language filter covers South African languages', () {
      expect(
        filterExploreTracks(tracks: tracks, language: 'isiZulu').length,
        2,
      );
      expect(
        filterExploreTracks(tracks: tracks, language: 'Tshivenḓa')
            .single
            .title,
        'Ndo Mufuna Matibe',
      );
      expect(
        filterExploreTracks(tracks: tracks, language: 'English').length,
        2,
      );
    });

    test('search matches title, creator, genre, language and mood', () {
      expect(
        filterExploreTracks(tracks: tracks, query: 'MATIBE').single.title,
        'Ndo Mufuna Matibe',
      );
      expect(
        filterExploreTracks(tracks: tracks, query: 'fifi').length,
        1,
      );
      expect(
        filterExploreTracks(tracks: tracks, query: 'maskandi').length,
        1,
      );
      expect(
        filterExploreTracks(tracks: tracks, query: 'yoruba').length,
        1,
      );
      expect(
        filterExploreTracks(tracks: tracks, query: 'uplifting').length,
        1,
      );
      expect(filterExploreTracks(tracks: tracks, query: 'zzzz'), isEmpty);
    });

    test('combined filters intersect every dimension', () {
      final result = filterExploreTracks(
        tracks: tracks,
        genre: 'Amapiano',
        mood: 'Energetic',
        language: 'Instrumental',
      );
      expect(result.single.title, 'Township Log Drum Heat');
    });

    test('sorting switches between newest and most liked', () {
      final newest = filterExploreTracks(
        tracks: tracks,
        sortBy: ExploreSortBy.newest,
      );
      expect(newest.first.title, 'Grateful in the Light');

      final mostLiked = filterExploreTracks(
        tracks: tracks,
        sortBy: ExploreSortBy.mostLiked,
      );
      expect(mostLiked.first.title, 'Lagos Pulse');
      expect(mostLiked.first.likeCount, 1120);
      expect(mostLiked.last.title, 'Kwaito Renaissance');
    });

    test('exploreQueueFor keeps the catalog for known tracks', () {
      final queue = exploreQueueFor(tracks, tracks[3]);
      expect(queue.length, 8);
      expect(identical(queue, tracks), isTrue);
    });

    test('exploreQueueFor prepends unknown tracks', () {
      const outside = Track(
        id: 'outside_1',
        title: 'Outside',
        creatorName: 'Tester',
        genre: 'Amapiano',
        duration: Duration(minutes: 1),
      );
      final queue = exploreQueueFor(tracks, outside);
      expect(queue.length, 9);
      expect(queue.first.id, 'outside_1');
    });
  });

  group('Explore provider tree', () {
    test('defaults match the blueprint state contract', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(exploreTabProvider), ExploreTab.discover);
      expect(container.read(exploreSearchQueryProvider), '');
      expect(container.read(exploreGenreFilterProvider), exploreAllFilter);
      expect(container.read(exploreMoodFilterProvider), isNull);
      expect(container.read(exploreLanguageFilterProvider), exploreAllFilter);
      expect(container.read(exploreSortByProvider), ExploreSortBy.newest);
      expect(container.read(exploreTracksProvider).length, 8);
      expect(container.read(filteredExploreTracksProvider).length, 8);
      expect(container.read(exploreCreatorsProvider).length, 6);
    });

    test('filter dimensions recompute the catalog projection', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(exploreGenreFilterProvider.notifier).state = 'Gqom';
      expect(container.read(filteredExploreTracksProvider).length, 1);

      container.read(exploreGenreFilterProvider.notifier).state =
          exploreAllFilter;
      container.read(exploreMoodFilterProvider.notifier).state = 'Peaceful';
      expect(
        container.read(filteredExploreTracksProvider).single.title,
        'Maskandi Strings of Natal',
      );

      container.read(exploreMoodFilterProvider.notifier).state = null;
      container.read(exploreLanguageFilterProvider.notifier).state = 'isiZulu';
      expect(container.read(filteredExploreTracksProvider).length, 2);

      container.read(exploreLanguageFilterProvider.notifier).state =
          exploreAllFilter;
      container.read(exploreSortByProvider.notifier).state =
          ExploreSortBy.mostLiked;
      expect(
        container.read(filteredExploreTracksProvider).first.title,
        'Lagos Pulse',
      );

      container.read(exploreSearchQueryProvider.notifier).state = 'kwaito';
      expect(
        container.read(filteredExploreTracksProvider).single.title,
        'Kwaito Renaissance',
      );
    });

    test('tab switching updates the active discovery sub-tab', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(exploreTabProvider.notifier).state = ExploreTab.forYou;
      expect(container.read(exploreTabProvider), ExploreTab.forYou);

      container.read(exploreTabProvider.notifier).state = ExploreTab.following;
      expect(container.read(exploreTabProvider), ExploreTab.following);
    });

    test('newThisWeek exposes the newest six curated drops', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final newThisWeek = container.read(newThisWeekTracksProvider);
      expect(newThisWeek.length, exploreCatalogPageSize);
      expect(newThisWeek.first.title, 'Grateful in the Light');
      expect(newThisWeek.first.isNew, isTrue);
    });

    test('rising exposes trending ranks ordered by rank', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final rising = container.read(risingTracksProvider);
      expect(rising.length, 3);
      expect(rising.map((track) => track.trendingRank), [1, 2, 3]);
      expect(rising.first.title, 'Ndo Mufuna Matibe');
    });

    test('catalog pagination cursor clamps at the result count', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(visibleExploreTracksProvider).length,
        exploreCatalogPageSize,
      );
      expect(container.read(hasMoreExploreTracksProvider), isTrue);

      // Simulates tapping `Load more` once (8 results total).
      container.read(exploreVisibleCountProvider.notifier).state = 8;
      expect(container.read(visibleExploreTracksProvider).length, 8);
      expect(container.read(hasMoreExploreTracksProvider), isFalse);
    });
  });
}
