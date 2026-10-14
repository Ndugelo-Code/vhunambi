import 'package:flutter_test/flutter_test.dart';
import 'package:vhunambi_client/core/cache/cache_entry.dart';
import 'package:vhunambi_client/core/cache/profile_cache.dart';
import 'package:vhunambi_client/core/network/error_handler.dart';
import 'package:vhunambi_client/features/profile/domain/models/error_state.dart';
import 'package:vhunambi_client/features/profile/domain/models/loading_state.dart';
import 'package:vhunambi_client/features/profile/domain/models/profile_models.dart';
import 'package:vhunambi_client/features/profile/domain/models/profile_operation_state.dart';
import 'package:vhunambi_client/features/profile/domain/models/profile_operation_type.dart';
import 'package:vhunambi_client/features/profile/domain/repositories/profile_repository.dart';
import 'package:vhunambi_client/features/profile/presentation/providers/profile_operation_notifier.dart';
import 'package:vhunambi_client/features/profile/presentation/providers/profile_providers.dart';

class FakeProfileRepository implements ProfileRepository {
  ArtistProfileEntity? profileToReturn;
  Exception? errorToThrow;
  int fetchCalls = 0;
  int toggleFollowCalls = 0;
  int tipCalls = 0;
  int avatarCalls = 0;

  @override
  Future<ArtistProfileEntity> fetchProfile(String artistId) async {
    fetchCalls++;
    if (errorToThrow != null) throw errorToThrow!;
    return profileToReturn ??
        ArtistProfileEntity(
          id: artistId,
          username: artistId,
          displayName: 'Test Artist',
          monogram: 'TA',
        );
  }

  @override
  Future<void> toggleFollow(String artistId, bool isFollowing) async {
    toggleFollowCalls++;
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<void> tipArtist(String artistId, int credits) async {
    tipCalls++;
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<void> updateAvatar(String artistId, String? avatarUrl) async {
    avatarCalls++;
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<void> toggleTipsEnabled(String artistId, bool enabled) async {
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<void> addRelease(String artistId, MusicReleaseEntity release) async {
    if (errorToThrow != null) throw errorToThrow!;
  }
}

void main() {
  group('ProfileOperationState', () {
    test('tracks loading states per operation type', () {
      var state = const ProfileOperationState();
      expect(state.isLoading(ProfileOperationType.fetch), isFalse);

      state = state.withLoading(
        ProfileOperationType.fetch,
        LoadingState.loading(retryAttempt: 2),
      );
      expect(state.isLoading(ProfileOperationType.fetch), isTrue);
      expect(state.loadingStates[ProfileOperationType.fetch]?.retryLabel,
          'Retrying... (2/3)');
      expect(state.isAnyLoading, isTrue);

      state = state.withLoading(
        ProfileOperationType.fetch,
        const LoadingState.idle(),
      );
      expect(state.isLoading(ProfileOperationType.fetch), isFalse);
      expect(state.isAnyLoading, isFalse);
    });

    test('tracks error states per operation type', () {
      var state = const ProfileOperationState();
      expect(state.errorFor(ProfileOperationType.follow), isNull);

      final error = ErrorState.now(
        message: 'Network failed',
        operationType: ProfileOperationType.follow,
        attemptCount: 1,
        isRetryable: true,
      );

      state = state.withError(ProfileOperationType.follow, error);
      expect(state.errorFor(ProfileOperationType.follow), equals(error));
      expect(state.errorFor(ProfileOperationType.follow)?.shouldShowRetry, isTrue);

      state = state.clearError(ProfileOperationType.follow);
      expect(state.errorFor(ProfileOperationType.follow), isNull);
    });

    test('detects cache staleness when older than 24 hours', () {
      const freshProfile = ArtistProfileEntity(
        id: 'fresh',
        username: 'fresh',
        displayName: 'Fresh',
        monogram: 'FR',
      );

      final stateFresh = ProfileOperationState(
        cachedProfile: CacheEntry(
          data: freshProfile,
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      );
      expect(stateFresh.isCacheStale, isFalse);

      final stateStale = ProfileOperationState(
        cachedProfile: CacheEntry(
          data: freshProfile,
          timestamp: DateTime.now().subtract(const Duration(hours: 25)),
        ),
      );
      expect(stateStale.isCacheStale, isTrue);
    });

    test('copyWith updates fields immutably', () {
      const state = ProfileOperationState(isOffline: false);
      final updated = state.copyWith(isOffline: true);

      expect(state.isOffline, isFalse);
      expect(updated.isOffline, isTrue);
    });
  });

  group('ProfileOperationNotifier', () {
    late FakeProfileRepository repository;
    late ProfileCache cache;
    late ArtistProfileNotifier profileNotifier;

    setUp(() {
      repository = FakeProfileRepository();
      cache = ProfileCache();
      profileNotifier = ArtistProfileNotifier('fifi');
    });

    test('initial fetch populates state and cache on success', () async {
      final notifier = ProfileOperationNotifier(
        artistId: 'fifi',
        repository: repository,
        cache: cache,
        profileNotifier: profileNotifier,
        autoInitialize: false,
      );

      expect(notifier.state.cachedProfile, isNull);
      await notifier.fetchProfile();

      expect(notifier.state.isLoading(ProfileOperationType.fetch), isFalse);
      expect(notifier.state.cachedProfile, isNotNull);
      expect(notifier.state.cachedProfile!.data.id, 'fifi');
      expect(notifier.state.errorFor(ProfileOperationType.fetch), isNull);

      final fromCache = await cache.get('fifi');
      expect(fromCache, isNotNull);
    });

    test('fetch failure records ErrorState with retry eligibility', () async {
      repository.errorToThrow = const ApiException(
        statusCode: 500,
        message: 'Server Down',
      );

      final notifier = ProfileOperationNotifier(
        artistId: 'fifi',
        repository: repository,
        cache: cache,
        profileNotifier: profileNotifier,
        autoInitialize: false,
      );

      await notifier.fetchProfile();

      expect(notifier.state.isLoading(ProfileOperationType.fetch), isFalse);
      final error = notifier.state.errorFor(ProfileOperationType.fetch);
      expect(error, isNotNull);
      expect(error!.isRetryable, isTrue);
      expect(error.message, contains('Server error'));
    });

    test('toggleFollow optimistic update succeeds', () async {
      final notifier = ProfileOperationNotifier(
        artistId: 'fifi',
        repository: repository,
        cache: cache,
        profileNotifier: profileNotifier,
        autoInitialize: false,
      );

      final initialFollowing = profileNotifier.state.isFollowing;
      final initialCount = profileNotifier.state.followerCount;

      await notifier.toggleFollow();

      expect(profileNotifier.state.isFollowing, !initialFollowing);
      expect(profileNotifier.state.followerCount, initialCount + 1);
      expect(notifier.state.errorFor(ProfileOperationType.follow), isNull);
    });

    test('toggleFollow failure rolls back ArtistProfileNotifier state', () async {
      final notifier = ProfileOperationNotifier(
        artistId: 'fifi',
        repository: repository,
        cache: cache,
        profileNotifier: profileNotifier,
        autoInitialize: false,
      );

      final initialFollowing = profileNotifier.state.isFollowing;
      final initialCount = profileNotifier.state.followerCount;

      repository.errorToThrow = const ApiException(
        statusCode: 500,
        message: 'Failed to follow',
      );

      await notifier.toggleFollow();

      // Rolled back to original
      expect(profileNotifier.state.isFollowing, initialFollowing);
      expect(profileNotifier.state.followerCount, initialCount);

      // Error state recorded
      final error = notifier.state.errorFor(ProfileOperationType.follow);
      expect(error, isNotNull);
    });

    test('tipArtist failure rolls back tip record from history', () async {
      final notifier = ProfileOperationNotifier(
        artistId: 'fifi',
        repository: repository,
        cache: cache,
        profileNotifier: profileNotifier,
        autoInitialize: false,
      );

      final initialHistoryLength = profileNotifier.state.tipHistory.length;

      repository.errorToThrow = const ApiException(
        statusCode: 500,
        message: 'Tip failed',
      );

      await notifier.tipArtist(50);

      // Rolled back to original history length
      expect(profileNotifier.state.tipHistory.length, initialHistoryLength);
      expect(notifier.state.errorFor(ProfileOperationType.tip), isNotNull);
    });

    test('deduplicates concurrent in-flight fetchProfile requests', () async {
      final notifier = ProfileOperationNotifier(
        artistId: 'fifi',
        repository: repository,
        cache: cache,
        profileNotifier: profileNotifier,
        autoInitialize: false,
      );

      await Future.wait([
        notifier.fetchProfile(),
        notifier.fetchProfile(),
        notifier.fetchProfile(),
      ]);

      expect(repository.fetchCalls, equals(1));
    });
  });
}
