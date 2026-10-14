import 'package:flutter/foundation.dart';
import '../../../../core/cache/cache_entry.dart';
import 'error_state.dart';
import 'loading_state.dart';
import 'profile_models.dart';
import 'profile_operation_type.dart';

/// Companion state model tracking async operations, loading flags, and error states.
/// Preserves `artistProfileFamilyProvider` emitting `ArtistProfileEntity` without breaking changes.
@immutable
class ProfileOperationState {
  final Map<ProfileOperationType, LoadingState> loadingStates;
  final Map<ProfileOperationType, ErrorState?> errorStates;
  final CacheEntry<ArtistProfileEntity>? cachedProfile;
  final bool isOffline;

  const ProfileOperationState({
    this.loadingStates = const {},
    this.errorStates = const {},
    this.cachedProfile,
    this.isOffline = false,
  });

  /// Check if a specific operation is currently loading.
  bool isLoading(ProfileOperationType type) =>
      loadingStates[type]?.isLoading ?? false;

  /// Get the current error state for a specific operation, if any.
  ErrorState? errorFor(ProfileOperationType type) => errorStates[type];

  /// Indicates if any operation is actively in-flight.
  bool get isAnyLoading =>
      loadingStates.values.any((state) => state.isLoading);

  /// Indicates if cached profile data is older than 24 hours.
  bool get isCacheStale => cachedProfile?.isStale ?? false;

  /// Immutable state copy with updated fields.
  ProfileOperationState copyWith({
    Map<ProfileOperationType, LoadingState>? loadingStates,
    Map<ProfileOperationType, ErrorState?>? errorStates,
    CacheEntry<ArtistProfileEntity>? cachedProfile,
    bool? isOffline,
  }) {
    return ProfileOperationState(
      loadingStates: loadingStates ?? this.loadingStates,
      errorStates: errorStates ?? this.errorStates,
      cachedProfile: cachedProfile ?? this.cachedProfile,
      isOffline: isOffline ?? this.isOffline,
    );
  }

  /// Convenience helper to update loading state for a single operation.
  ProfileOperationState withLoading(
    ProfileOperationType type,
    LoadingState state,
  ) {
    final updated = Map<ProfileOperationType, LoadingState>.from(loadingStates);
    updated[type] = state;
    return copyWith(loadingStates: updated);
  }

  /// Convenience helper to set or clear error for a single operation.
  ProfileOperationState withError(
    ProfileOperationType type,
    ErrorState? error,
  ) {
    final updated = Map<ProfileOperationType, ErrorState?>.from(errorStates);
    updated[type] = error;
    return copyWith(errorStates: updated);
  }

  /// Convenience helper to clear error for a single operation.
  ProfileOperationState clearError(ProfileOperationType type) =>
      withError(type, null);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileOperationState &&
          runtimeType == other.runtimeType &&
          mapEquals(loadingStates, other.loadingStates) &&
          mapEquals(errorStates, other.errorStates) &&
          cachedProfile == other.cachedProfile &&
          isOffline == other.isOffline;

  @override
  int get hashCode => Object.hash(
        Object.hashAll(loadingStates.entries),
        Object.hashAll(errorStates.entries),
        cachedProfile,
        isOffline,
      );
}
