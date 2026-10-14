// ignore_for_file: prefer_initializing_formals
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/cache/cache_entry.dart';
import '../../../../core/cache/profile_cache.dart';
import '../../../../core/network/network_operation.dart';
import '../../domain/models/error_state.dart';
import '../../domain/models/loading_state.dart';
import '../../domain/models/profile_models.dart';
import '../../domain/models/profile_operation_state.dart';
import '../../domain/models/profile_operation_type.dart';
import '../../domain/repositories/profile_repository.dart';
import 'profile_providers.dart';

/// Companion notifier managing async operation states, error boundaries, retries, and offline caching.
/// Operates alongside `ArtistProfileNotifier` without altering `ArtistProfileEntity` contracts.
class ProfileOperationNotifier extends StateNotifier<ProfileOperationState> {
  final String artistId;
  final ProfileRepository _repository;
  final ProfileCache _cache;
  final ArtistProfileNotifier _profileNotifier;
  final bool Function()? isOfflineCheck;

  ProfileOperationNotifier({
    required this.artistId,
    required ProfileRepository repository,
    required ProfileCache cache,
    required ArtistProfileNotifier profileNotifier,
    this.isOfflineCheck,
    bool autoInitialize = true,
  })  : _repository = repository,
        _cache = cache,
        _profileNotifier = profileNotifier,
        super(const ProfileOperationState()) {
    if (autoInitialize) {
      _initializeProfile();
    }
  }

  Future<void> _initializeProfile() async {
    // 1. Try cache first for instantaneous render
    final cached = await _cache.get(artistId);
    if (cached != null) {
      state = state.copyWith(
        cachedProfile: cached,
        isOffline: _isOffline(),
      );
      _profileNotifier.seedFromCache(cached.data);
    }

    // 2. Fetch fresh profile data
    await fetchProfile();
  }

  bool _isOffline() {
    if (isOfflineCheck != null) {
      return isOfflineCheck!();
    }
    return false;
  }

  Future<void>? _inFlightFetch;

  /// Fetch profile with automatic retry and cache persistence on success.
  /// Deduplicates concurrent in-flight requests.
  Future<void> fetchProfile() async {
    if (_inFlightFetch != null) {
      return _inFlightFetch!;
    }

    _inFlightFetch = _executeFetchProfile();
    try {
      await _inFlightFetch;
    } finally {
      _inFlightFetch = null;
    }
  }

  Future<void> _executeFetchProfile() async {
    _setLoading(ProfileOperationType.fetch, true);
    _clearError(ProfileOperationType.fetch);

    final operation = NetworkOperation<ArtistProfileEntity>(
      execute: () => _repository.fetchProfile(artistId),
    );
    final result = await operation();

    if (result.isSuccess && result.data != null) {
      final entry = CacheEntry.now(result.data!);
      state = state.copyWith(
        cachedProfile: entry,
        isOffline: false,
      );
      _profileNotifier.seedFromCache(result.data!);
      await _cache.put(artistId, result.data!);
      _setLoading(ProfileOperationType.fetch, false);
    } else {
      _setError(
        ProfileOperationType.fetch,
        ErrorState.now(
          message: result.errorMessage ?? 'Failed to load profile',
          operationType: ProfileOperationType.fetch,
          attemptCount: result.attemptCount,
          isRetryable: true,
        ),
      );
      _setLoading(ProfileOperationType.fetch, false);
    }
  }

  /// Toggles follow state with optimistic update and rollback on failure.
  Future<void> toggleFollow() async {
    final originalFollowing = _profileNotifier.state.isFollowing;
    final originalFollowerCount = _profileNotifier.state.followerCount;

    // Optimistic update on core entity
    _profileNotifier.toggleFollow();
    _setLoading(ProfileOperationType.follow, true);
    _clearError(ProfileOperationType.follow);

    final operation = NetworkOperation<void>(
      execute: () => _repository.toggleFollow(artistId, !originalFollowing),
    );
    final result = await operation();
    _setLoading(ProfileOperationType.follow, false);

    if (result.isFailure) {
      // Rollback optimistic update
      _profileNotifier.rollbackFollow(originalFollowing, originalFollowerCount);
      _setError(
        ProfileOperationType.follow,
        ErrorState.now(
          message: result.errorMessage ??
              'Failed to ${originalFollowing ? 'unfollow' : 'follow'} artist. Please try again.',
          operationType: ProfileOperationType.follow,
          attemptCount: result.attemptCount,
          isRetryable: true,
        ),
      );
    }
  }

  /// Sends a tip with optimistic ledger addition and rollback on error.
  Future<void> tipArtist(
    int credits, {
    String senderName = 'cern',
    String senderHandle = '@cern',
  }) async {
    if (credits <= 0) return;

    _setLoading(ProfileOperationType.tip, true);
    _clearError(ProfileOperationType.tip);

    final previousHistory = List<TipRecordEntity>.from(_profileNotifier.state.tipHistory);
    _profileNotifier.tipArtist(credits, senderName: senderName, senderHandle: senderHandle);

    final operation = NetworkOperation<void>(
      execute: () => _repository.tipArtist(artistId, credits),
    );
    final result = await operation();
    _setLoading(ProfileOperationType.tip, false);

    if (result.isFailure) {
      _profileNotifier.state = _profileNotifier.state.copyWith(tipHistory: previousHistory);
      _setError(
        ProfileOperationType.tip,
        ErrorState.now(
          message: result.errorMessage ?? 'Failed to send tip. Please try again.',
          operationType: ProfileOperationType.tip,
          attemptCount: result.attemptCount,
          isRetryable: true,
        ),
      );
    }
  }

  /// Updates creator avatar with rollback on network failure.
  Future<void> updateAvatar(String? url) async {
    final originalUrl = _profileNotifier.state.avatarUrl;

    _setLoading(ProfileOperationType.avatarUpdate, true);
    _clearError(ProfileOperationType.avatarUpdate);
    _profileNotifier.updateAvatar(url);

    final operation = NetworkOperation<void>(
      execute: () => _repository.updateAvatar(artistId, url),
    );
    final result = await operation();
    _setLoading(ProfileOperationType.avatarUpdate, false);

    if (result.isFailure) {
      _profileNotifier.updateAvatar(originalUrl);
      _setError(
        ProfileOperationType.avatarUpdate,
        ErrorState.now(
          message: result.errorMessage ?? 'Failed to update avatar. Please try again.',
          operationType: ProfileOperationType.avatarUpdate,
          attemptCount: result.attemptCount,
          isRetryable: true,
        ),
      );
    }
  }

  /// Toggles tip receiving availability.
  Future<void> toggleTipsEnabled() async {
    final originalState = _profileNotifier.state.tipsEnabled;

    _setLoading(ProfileOperationType.visibilityToggle, true);
    _clearError(ProfileOperationType.visibilityToggle);
    _profileNotifier.toggleTipsEnabled();

    final operation = NetworkOperation<void>(
      execute: () => _repository.toggleTipsEnabled(artistId, !originalState),
    );
    final result = await operation();
    _setLoading(ProfileOperationType.visibilityToggle, false);

    if (result.isFailure) {
      _profileNotifier.toggleTipsEnabled();
      _setError(
        ProfileOperationType.visibilityToggle,
        ErrorState.now(
          message: result.errorMessage ?? 'Failed to update tip settings.',
          operationType: ProfileOperationType.visibilityToggle,
          attemptCount: result.attemptCount,
          isRetryable: true,
        ),
      );
    }
  }

  /// Adds a new music release to the discography with rollback on error.
  Future<void> addRelease(MusicReleaseEntity release) async {
    final previousReleases = List<MusicReleaseEntity>.from(_profileNotifier.state.releases);

    _setLoading(ProfileOperationType.createRelease, true);
    _clearError(ProfileOperationType.createRelease);
    _profileNotifier.addRelease(release);

    final operation = NetworkOperation<void>(
      execute: () => _repository.addRelease(artistId, release),
    );
    final result = await operation();
    _setLoading(ProfileOperationType.createRelease, false);

    if (result.isFailure) {
      _profileNotifier.state = _profileNotifier.state.copyWith(releases: previousReleases);
      _setError(
        ProfileOperationType.createRelease,
        ErrorState.now(
          message: result.errorMessage ?? 'Failed to publish release.',
          operationType: ProfileOperationType.createRelease,
          attemptCount: result.attemptCount,
          isRetryable: true,
        ),
      );
    }
  }

  void _setLoading(ProfileOperationType type, bool isLoading, {int? retryAttempt}) {
    state = state.withLoading(
      type,
      isLoading
          ? LoadingState.loading(retryAttempt: retryAttempt)
          : const LoadingState.idle(),
    );
  }

  void _setError(ProfileOperationType type, ErrorState error) {
    state = state.withError(type, error);
  }

  void _clearError(ProfileOperationType type) {
    state = state.clearError(type);
  }
}
