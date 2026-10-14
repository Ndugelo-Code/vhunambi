# Implementation Plan: Profile UX Enhancement

## Overview

This document provides a granular, actionable task list for implementing the Profile UX Enhancement feature. The implementation transforms the VHUNAMBI Profile feature with robust error handling, comprehensive loading states, and industry-standard accessibility support.

## Tasks

- [x] 1. Set up project structure and core interfaces
  - Create directory structure for network layer (`lib/core/network/`)
  - Create directory structure for cache layer (`lib/core/cache/`)
  - Create directory structure for accessibility layer (`lib/core/accessibility/`)
  - Set up test directories matching source structure
  - _Requirements: 1.1, 2.1_

- [x] 2. Implement network operation layer
  - [x] 2.1 Create OperationResult sealed class
    - Create file `lib/core/network/operation_result.dart`
    - Implement `OperationResult<T>` sealed class with `SuccessResult` and `FailureResult` subclasses
    - Add `isSuccess`, `isFailure`, `data`, and `errorMessage` getters
    - Include error context (message, exception, attemptCount)
    - _Requirements: 1.1, 1.2_
  
  - [x] 2.2 Create ErrorType enum and NetworkErrorHandler
    - Create file `lib/core/network/error_handler.dart`
    - Define `ErrorType` enum (timeout, noConnection, serverError, unauthorized, forbidden, notFound, clientError, unknown)
    - Implement `NetworkErrorHandler.classify()` method for exception classification
    - Implement `NetworkErrorHandler.toUserMessage()` for user-friendly error messages
    - Add `isRetryable` getter for each ErrorType
    - _Requirements: 1.2, 1.3_
  
  - [x] 2.3 Create RetryStrategy with exponential backoff
    - Create file `lib/core/network/retry_strategy.dart`
    - Implement `RetryStrategy` class with configurable parameters (maxAttempts=3, initialDelay=1s, maxDelay=16s, multiplier=2.0)
    - Implement `delayFor(int attempt)` method calculating exponential backoff
    - Ensure delay never exceeds maxDelay
    - _Requirements: 2.1, 2.2_
  
  - [x] 2.4 Create NetworkOperation wrapper
    - Create file `lib/core/network/network_operation.dart`
    - Implement `NetworkOperation<T>` class wrapping async operations
    - Add 10-second timeout to all operations
    - Implement retry loop with attempt tracking
    - Integrate RetryStrategy for delay calculation
    - Integrate NetworkErrorHandler for error classification
    - Return OperationResult with success or failure
    - _Requirements: 1.1, 2.2, 2.3_
  
  - [x]* 2.5 Write unit tests for network layer
    - Test RetryStrategy exponential backoff calculation (attempts 1-5)
    - Test RetryStrategy maxDelay cap enforcement
    - Test NetworkErrorHandler classification for all exception types
    - Test NetworkErrorHandler user message generation
    - Test NetworkOperation successful execution
    - Test NetworkOperation retry on timeout and retryable errors
    - Test NetworkOperation no retry on non-retryable errors
    - Test NetworkOperation max retry limit enforcement
    - Test NetworkOperation 10-second timeout
    - Target: 100% coverage for network layer
    - _Requirements: 1.1, 1.2, 2.1, 2.2_

- [x] 3. Implement enhanced state management
  - [x] 3.1 Create ProfileOperationType enum
    - Create file `lib/features/profile/domain/models/profile_operation_type.dart`
    - Define enum values: fetch, follow, tip, visibilityToggle, avatarUpdate, createRelease
    - _Requirements: 1.2_
  
  - [x] 3.2 Create LoadingState model
    - Create file `lib/features/profile/domain/models/loading_state.dart`
    - Implement `LoadingState` class with isLoading, retryAttempt, startTime
    - Add factory constructors: `LoadingState.idle()`, `LoadingState.loading({int? retryAttempt})`
    - Add `retryLabel` getter for UI display ("Retrying... (2/3)")
    - _Requirements: 1.3, 5.1_
  
  - [x] 3.3 Create ErrorState model
    - Create file `lib/features/profile/domain/models/error_state.dart`
    - Implement `ErrorState` class with message, operationType, timestamp, attemptCount, isRetryable, context
    - Add `shouldShowRetry` getter (isRetryable && attemptCount < 3)
    - _Requirements: 1.2, 1.4, 12.1_
  
  - [x] 3.4 Create CacheEntry model
    - Create file `lib/core/cache/cache_entry.dart`
    - Implement `CacheEntry<T>` class with data and timestamp
    - Add factory constructor `CacheEntry.now(T data)`
    - Add `age` getter and `isStale` getter (>24 hours)
    - _Requirements: 14.2, 14.5_
  
  - [x] 3.5 Create ProfileOperationState
    - Create file `lib/features/profile/domain/models/profile_operation_state.dart`
    - Define `ProfileOperationState` tracking `loadingStates`, `errorStates`, `cachedProfile`, and `isOffline`
    - Add helper methods: `isLoading(ProfileOperationType)`, `errorFor(ProfileOperationType)`, `isCacheStale`
    - Implement `copyWith` for immutable state updates
    - Preserves `ArtistProfileEntity` return type for `artistProfileFamilyProvider`
    - _Requirements: 1.2, 1.3, 14.2_
  
  - [x] 3.6 Create ProfileOperationNotifier
    - Create file `lib/features/profile/presentation/providers/profile_operation_notifier.dart`
    - Extend `StateNotifier<ProfileOperationState>` with NetworkOperation integration
    - Implement `fetchProfile()` with automatic retry and cache update
    - Wire companion updates for mutations (follow, tip, visibility)
    - Add private methods: `_setLoading()`, `_setError()`, `_clearError()`
    - Implement cache initialization in constructor
    - _Requirements: 1.1, 1.2, 3.1, 3.2, 3.3, 3.4_
  
  - [x]* 3.7 Write unit tests for state management
    - Verify all existing tests in `profile_notifier_test.dart` pass 100% green
    - Test ProfileOperationState loading state tracking per operation type
    - Test ProfileOperationState error state tracking per operation type
    - Test ProfileOperationState cache staleness detection (>24 hours)
    - Test ProfileOperationState copyWith partial updates
    - Test ProfileOperationNotifier initial fetch with cache fallback
    - Test ProfileOperationNotifier fetch success updates state and cache
    - Test ProfileOperationNotifier fetch failure sets error state
    - Test ProfileOperationNotifier retry increments attempt count
    - Target: 95% coverage for state management
    - _Requirements: 1.1, 1.2, 3.1, 3.2, 3.3, 3.4_

- [x] 4. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Implement cache management layer
  - [x] 5.1 Create ProfileCache with Hive and In-Memory Fallback
    - Create file `lib/core/cache/profile_cache.dart`
    - Implement in-memory cache (`Map<String, CacheEntry<ArtistProfileEntity>>`)
    - Implement persistent cache using untyped Hive Box (`Box? _box`) with JSON serialization
    - Implement `get(String artistId)` checking memory first, then persistent storage
    - Implement `put(String artistId, ArtistProfileEntity profile)` to both caches
    - Implement `_enforceSizeLimit()` removing oldest entries when >20 profiles
    - Implement `clear()` removing all cached data
    - Add constants: maxCacheSize=20, staleThreshold=24 hours
    - _Requirements: 14.1, 14.2, 14.6, 14.7_
  
  - [x]* 5.2 Write unit tests for cache layer
    - Test memory cache hit before persistent cache
    - Test persistent cache persistence and retrieval
    - Test JSON serialization roundtrip
    - Test cache size limit enforcement (20 max)
    - Test removal of oldest entries when limit exceeded
    - Test cache clear removes all entries
    - Target: 95% coverage for cache layer
    - _Requirements: 14.1, 14.2, 14.7_

- [x] 6. Implement UI loading components
  - [x] 6.1 Re-export and bind existing ShimmerBox
    - Reuse existing token-disciplined, headless-safe `ShimmerBox` and `TrackTileSkeleton` from `lib/shared/widgets/shimmer_skeleton.dart`
    - Verify reduced motion compliance via `MediaQuery.disableAnimationsOf(context)`
    - Do NOT create duplicate shimmer controllers or hardcode `#141418`
    - _Requirements: 4.3, 11.1_
  
  - [x] 6.2 Create ProfileSkeletonScreen
    - Create file `lib/features/profile/presentation/widgets/loading/profile_skeleton_screen.dart`
    - Compose existing `ShimmerBox` and `TrackTileSkeleton` widgets
    - Layout: banner (220px), avatar (68px circle), name/bio (3 lines), stats grid (4 items), track rows
    - Support responsive breakpoints (mobile <768px, desktop ≥1024px)
    - Apply token styling with AppColors.surfaceElevated and AppColors.surfaceSecondary
    - _Requirements: 4.1, 4.2, 4.3, 4.6, 4.7_
  
  - [x] 6.3 Create ErrorBoundary widget
    - Create file `lib/features/profile/presentation/widgets/error/error_boundary.dart`
    - Implement centered error display with icon, message, retry button
    - Accept parameters: message, onRetry callback, onContactSupport callback, icon
    - Style retry button with AppColors.brandPrimary and pillBorder
    - Support optional contact support button
    - _Requirements: 1.1, 1.4, 4.5_
  
  - [x] 6.4 Create LoadingOverlay widget
    - Create file `lib/features/profile/presentation/widgets/loading/loading_overlay.dart`
    - Implement translucent overlay (Colors.black54) with centered spinner
    - Accept parameters: isLoading bool, message string, child widget
    - Show overlay only when isLoading=true
    - Display optional loading message below spinner
    - Use AppColors.surfaceModal for spinner container
    - _Requirements: 5.1, 5.2, 5.3, 5.4_
  
  - [x] 6.5 Create AsyncImageWithFallback widget
    - Create file `lib/features/profile/presentation/widgets/loading/async_image_with_fallback.dart`
    - Implement StatefulWidget tracking ImageLoadingState (loading, loaded, error)
    - Show ShimmerBox during initial loading
    - Show Image.network when URL loads successfully
    - Show monogram on gradient background when load fails or URL is null
    - Implement `_generateGradient(String seed)` using username hash for hue
    - Add 10-second timeout for image loading
    - _Requirements: 6.1, 6.2, 6.3, 6.5, 6.7_
  
  - [x] 6.6 Create ProgressiveListLoader widget
    - Create file `lib/features/profile/presentation/widgets/loading/progressive_list_loader.dart`
    - Implement ListView.builder with load-more footer
    - Accept parameters: items list, itemBuilder, onLoadMore callback, pageSize, hasMore
    - Show "Load More" button when hasMore=true and not loading
    - Show loading spinner during load more
    - Show error with retry button on load more failure
    - Preserve existing items on load more error
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5_
  
  - [x]* 6.7 Write widget tests for loading components
    - Test ProfileSkeletonScreen renders correct number of placeholders
    - Test ProfileSkeletonScreen shimmer animation at 1.5s duration
    - Test ProfileSkeletonScreen reduced motion disables shimmer
    - Test ProfileSkeletonScreen responsive layout (mobile vs desktop)
    - Test ErrorBoundary displays message and retry button
    - Test ErrorBoundary retry button calls onRetry callback
    - Test LoadingOverlay shows when isLoading=true
    - Test LoadingOverlay hides when isLoading=false
    - Test AsyncImageWithFallback loading shimmer initially
    - Test AsyncImageWithFallback displays image on success
    - Test AsyncImageWithFallback displays monogram on failure
    - Test ProgressiveListLoader renders items and load more button
    - Test ProgressiveListLoader loading spinner during load more
    - Test ProgressiveListLoader error state with retry
    - Target: 85% coverage for UI components
    - _Requirements: 4.1, 4.2, 4.3, 5.1, 6.1, 6.2, 13.1, 13.2_

- [x] 7. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 8. Implement accessibility layer
  - [x] 8.1 Create A11yButton wrapper
    - Create file `lib/core/accessibility/a11y_button.dart`
    - Wrap button with Semantics widget providing semantic label
    - Enforce minimum touch target: ConstrainedBox(minWidth: 48, minHeight: 48)
    - Add Material InkWell for tap feedback
    - Accept parameters: semanticLabel, onPressed, child, padding, enabled
    - _Requirements: 7.1, 7.2, 9.1, 9.2_
  
  - [x] 8.2 Create A11yFocusIndicator
    - Create file `lib/core/accessibility/a11y_focus_indicator.dart`
    - Display 2px solid border with AppColors.brandPrimary when hasFocus=true
    - Accept parameters: child, hasFocus bool
    - Use AppRadius.cardBorder for border radius
    - _Requirements: 8.2, 8.3, 10.6_
  
  - [x] 8.3 Create KeyboardNavigationController
    - Create file `lib/core/accessibility/keyboard_navigation_controller.dart`
    - Implement focus node registration and management
    - Implement `focusNext()` cycling to next focus node
    - Implement `focusPrevious()` cycling to previous focus node
    - Maintain focus order list and current index
    - Implement dispose for cleanup
    - _Requirements: 8.1, 8.2, 8.5_
  
  - [x] 8.4 Create SemanticLabelBuilder helper
    - Create file `lib/core/accessibility/semantic_label_builder.dart`
    - Provide static methods for building descriptive labels
    - Examples: followButtonLabel(artistName, isFollowing), statTileLabel(value, statName), tipButtonLabel(artistName)
    - _Requirements: 7.1, 7.2, 7.3, 7.4_
  
  - [x] 8.5 Create ContrastChecker debug tool
    - Create file `lib/core/accessibility/contrast_checker.dart`
    - Implement `calculateContrastRatio(Color foreground, Color background)` using WCAG formula
    - Implement `_relativeLuminance(Color)` helper
    - Implement `_luminanceChannel(double)` helper
    - Implement `getWCAGLevel(double ratio)` returning enum (AAA ≥7.0, AA ≥4.5, AA Large ≥3.0, FAIL <3.0)
    - Define WCAGLevel enum with label and color getters
    - _Requirements: 10.1, 10.2, 10.3, 15.2_
  
  - [x]* 8.6 Write unit tests for accessibility layer
    - Test A11yButton enforces 48x48dp minimum touch target
    - Test A11yButton semantic label attachment
    - Test A11yFocusIndicator border appearance when hasFocus=true
    - Test KeyboardNavigationController focus cycling
    - Test ContrastChecker WCAG ratio calculation for known color pairs
    - Test ContrastChecker level classification (AAA, AA, AA Large, FAIL)
    - Target: 90% coverage for accessibility layer
    - _Requirements: 7.1, 8.2, 9.1, 10.1_

- [x] 9. Implement offline cache and indicators
  - [x] 9.1 Create OfflineIndicator banner
    - Create file `lib/features/profile/presentation/widgets/offline/offline_indicator.dart`
    - Display banner with cloud_off icon, timestamp message, and optional refresh button
    - Accept parameters: cacheTimestamp, onRefresh callback
    - Use AppColors.amberInset background with brandPrimary border
    - Implement `_formatTimeAgo(Duration)` helper (just now, Xm ago, Xh ago, Xd ago)
    - _Requirements: 14.2, 14.4_
  
  - [x] 9.2 Integrate cache into ProfileOperationNotifier
    - Update `_initializeProfile()` to check cache first before network fetch
    - Update `fetchProfile()` to save to cache on success
    - Add `_hasConnection()` helper to detect offline state
    - Set `isOffline` flag in ProfileOperationState when offline
    - _Requirements: 14.1, 14.2, 14.3_
  
  - [x]* 9.3 Write integration tests for offline cache
    - Test cache hit displays data immediately
    - Test network fetch updates cached data
    - Test offline state shows offline indicator
    - Test pull-to-refresh attempts fetch when online
    - Test mutation fails immediately when offline with error message
    - _Requirements: 14.1, 14.2, 14.3, 14.4_

- [x] 10. Implement companion profile operation providers
  - [x] 10.1 Create profileOperationProvider
    - Update file `lib/features/profile/presentation/providers/profile_providers.dart`
    - Add companion provider: `profileOperationProvider` using ProfileOperationNotifier
    - Strictly preserve existing `artistProfileFamilyProvider` emitting `ArtistProfileEntity`
    - _Requirements: 1.1, 1.2, 3.1_
  
  - [x] 10.2 Create ownerProfileOperationProvider
    - Update file `lib/features/profile/presentation/providers/profile_providers.dart`
    - Add companion provider: `ownerProfileOperationProvider` using ProfileOperationNotifier with 'me' artistId
    - Strictly preserve existing `ownerProfileProvider` emitting `ArtistProfileEntity`
    - _Requirements: 1.1, 1.2_

- [x] 11. Integrate resilience & accessibility into ArtistProfileView
  - [x] 11.1 Update ArtistProfileView with skeleton screen
    - Update file `lib/features/profile/presentation/views/artist_profile_view.dart`
    - Retain `ref.watch(artistProfileFamilyProvider(artistId))` for ArtistProfileEntity
    - Watch `ref.watch(profileOperationProvider(artistId))` for async operation state
    - Show ProfileSkeletonScreen when loading state for fetch operation is true
    - Fade transition (200ms) from skeleton to content on load success
    - _Requirements: 4.1, 4.4, 4.5_
  
  - [x] 11.2 Add error boundary to ArtistProfileView
    - Update file `lib/features/profile/presentation/views/artist_profile_view.dart`
    - Show ErrorBoundary when error state for fetch operation exists
    - Pass error message and retry callback to ErrorBoundary
    - Retry callback invokes `ref.read(profileOperationProvider(artistId).notifier).fetchProfile()`
    - _Requirements: 1.1, 1.4, 4.5_
  
  - [x] 11.3 Add loading overlay for mutations in ArtistProfileView
    - Update file `lib/features/profile/presentation/views/artist_profile_view.dart`
    - Wrap appropriate action containers in LoadingOverlay
    - Show overlay when loading state for follow or tip operations is true
    - Display operation-specific message ("Following...", "Tipping...")
    - _Requirements: 5.1, 5.2, 5.3_
  
  - [x] 11.4 Replace avatar with AsyncImageWithFallback
    - Update file `lib/features/profile/presentation/views/artist_profile_view.dart`
    - Replace existing avatar rendering in ProfileBannerHeader
    - Use AsyncImageWithFallback with profile.avatarUrl and profile.monogram
    - Set size to 68px
    - _Requirements: 6.1, 6.2, 6.3_
  
  - [x] 11.5 Add offline indicator to ArtistProfileView
    - Update file `lib/features/profile/presentation/views/artist_profile_view.dart`
    - Show OfflineIndicator at top when state.isOffline=true
    - Pass cache timestamp and refresh callback
    - _Requirements: 14.2, 14.4_
  
  - [x] 11.6 Add error toast on optimistic update rollback
    - Update file `lib/features/profile/presentation/views/artist_profile_view.dart`
    - Listen to error state changes in ref.listen
    - Show SnackBar with error message when follow or tip error appears
    - _Requirements: 3.5, 3.6_

- [x] 12. Integrate error handling into OwnerProfileView
  - [x] 12.1 Update OwnerProfileView with skeleton screen
    - Update file `lib/features/profile/presentation/views/owner_profile_view.dart`
    - Watch enhanced owner provider instead of old provider
    - Show ProfileSkeletonScreen when loading state for fetch operation is true
    - _Requirements: 4.1, 4.4, 4.5_
  
  - [x] 12.2 Add error boundary to OwnerProfileView
    - Update file `lib/features/profile/presentation/views/owner_profile_view.dart`
    - Show ErrorBoundary when error state for fetch operation exists
    - _Requirements: 1.1, 1.4, 4.5_
  
  - [x] 12.3 Add loading overlay for mutations in OwnerProfileView
    - Update file `lib/features/profile/presentation/views/owner_profile_view.dart`
    - Wrap view body in LoadingOverlay
    - Show overlay when loading state for avatarUpdate, createRelease, or visibilityToggle is true
    - _Requirements: 5.1, 5.2, 5.4_
  
  - [x] 12.4 Replace owner avatar with AsyncImageWithFallback
    - Update file `lib/features/profile/presentation/views/owner_profile_view.dart`
    - Replace CreatorAvatar content with AsyncImageWithFallback
    - _Requirements: 6.1, 6.2_
  
  - [x] 12.5 Add offline indicator to OwnerProfileView
    - Update file `lib/features/profile/presentation/views/owner_profile_view.dart`
    - Show OfflineIndicator when state.isOffline=true
    - _Requirements: 14.2, 14.4_

- [x] 13. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 14. Add accessibility enhancements to profile views
  - [x] 14.1 Wrap interactive buttons with A11yButton in ArtistProfileView
    - Update file `lib/features/profile/presentation/views/artist_profile_view.dart`
    - Wrap follow button with A11yButton, semantic label: "Follow [Artist Name]" or "Unfollow [Artist Name]"
    - Wrap tip button with A11yButton, semantic label: "Tip [Artist Name] with credits"
    - Wrap share button with A11yButton, semantic label: "Share [Artist Name]'s profile"
    - Wrap tab buttons with A11yButton with tab name semantic labels
    - _Requirements: 7.1, 7.2, 7.3, 9.1_
  
  - [x] 14.2 Add semantic labels to stat tiles in ArtistProfileView
    - Update file `lib/features/profile/presentation/widgets/profile_stats_grid.dart`
    - Wrap each stat tile in Semantics with label format: "[Value] [Stat Name]"
    - Examples: "1,820 followers", "45,200 plays", "8 songs"
    - _Requirements: 7.2_
  
  - [x] 14.3 Add focus indicators to interactive elements
    - Update ArtistProfileView and OwnerProfileView
    - Wrap focusable widgets with A11yFocusIndicator
    - Track focus state using FocusNode for each interactive element
    - _Requirements: 8.2, 8.3_
  
  - [x] 14.4 Add keyboard navigation support
    - Update ArtistProfileView and OwnerProfileView
    - Create KeyboardNavigationController instance
    - Register all interactive element focus nodes in logical tab order
    - Support Arrow key navigation in tab bars
    - Support Escape key to navigate back
    - _Requirements: 8.1, 8.4, 8.5, 8.6, 8.7_
  
  - [x] 14.5 Add screen reader announcements for state changes
    - Update EnhancedProfileNotifier to announce state changes
    - Announce "Now following [Artist Name]" or "Unfollowed [Artist Name]" after toggleFollow
    - Announce "Tipped [Amount] credits to [Artist Name]" after tipArtist
    - Use Semantics.fromProperties with liveRegion for announcements
    - _Requirements: 7.5, 7.6_
  
  - [x] 14.6 Mark decorative elements as hidden from screen readers
    - Update ArtistProfileView and OwnerProfileView
    - Add excludeSemantics: true to decorative icons and images
    - Ensure only semantic content is announced
    - _Requirements: 7.7_
  
  - [x]* 14.7 Write accessibility integration tests
    - Test tab navigation through profile elements in logical order
    - Test focus indicator appearance on focused elements
    - Test Enter/Space key activation for buttons
    - Test Arrow key navigation in tab bars
    - Test Escape key navigation back
    - Test screen reader announcements for follow toggle
    - Test screen reader announcements for tipping
    - _Requirements: 7.1, 7.5, 7.6, 8.1, 8.4, 8.5_

- [x] 15. Implement reduced motion support
  - [x] 15.1 Disable shimmer animation when reduced motion enabled
    - Update ShimmerBox widget
    - Check MediaQuery.disableAnimationsOf(context)
    - Show solid color background instead of animated gradient
    - _Requirements: 11.1_
  
  - [x] 15.2 Replace fade transitions with instant swaps
    - Update ArtistProfileView and OwnerProfileView
    - Check MediaQuery.disableAnimationsOf(context)
    - Use 0ms duration for skeleton-to-content transitions
    - _Requirements: 11.2_
  
  - [x] 15.3 Reduce optimistic update feedback duration
    - Update EnhancedProfileNotifier
    - When reduced motion enabled, use 300ms flash instead of 2-second highlight
    - _Requirements: 11.6_
  
  - [x]* 15.4 Write reduced motion tests
    - Test shimmer animation disabled when MediaQuery.disableAnimations=true
    - Test transitions use 0ms duration with reduced motion
    - Test optimistic feedback uses shorter duration
    - _Requirements: 11.1, 11.2, 11.6_

- [x] 16. Implement debug mode and developer tools
  - [x] 16.1 Create A11yAuditMode debug overlay
    - Create file `lib/core/accessibility/a11y_audit_mode.dart`
    - Implement overlay showing touch target size compliance (green ≥48dp, yellow 40-47dp, red <40dp)
    - Show contrast ratio badges on all text elements
    - Highlight elements missing semantic labels with red dashed border
    - Add toggle in developer menu (triple-tap app version)
    - _Requirements: 15.1, 15.2, 15.3, 15.6_
  
  - [x] 16.2 Add keyboard navigation path logging
    - Update KeyboardNavigationController
    - Log focus order to console in debug mode
    - Show focus order numbers in A11yAuditMode overlay
    - _Requirements: 15.4_
  
  - [x] 16.3 Add screen reader simulation panel
    - Update A11yAuditMode
    - Create debug panel showing screen reader output simulation
    - Display what would be announced for each interaction
    - _Requirements: 15.5_
  
  - [x] 16.4 Add accessibility audit report export
    - Update A11yAuditMode
    - Implement JSON export function with all violations and compliance metrics
    - Include: touch target violations, contrast violations, missing semantic labels, keyboard navigation issues
    - _Requirements: 15.7_

- [x] 17. Final integration and polish
  - [x] 17.1 Add pull-to-refresh support
    - Update ArtistProfileView and OwnerProfileView
    - Wrap scroll view in RefreshIndicator
    - Clear error state and call fetchProfile on pull-to-refresh
    - _Requirements: 12.6, 14.6_
  
  - [x] 17.2 Implement error state persistence across navigation
    - Verify error states persist in ProfileState when navigating away and back
    - Verify retry option restores on navigation return
    - _Requirements: 12.1, 12.2, 12.3, 12.4_
  
  - [x] 17.3 Add progressive loading for large data sets
    - Update ArtistProfileView releases list to use ProgressiveListLoader
    - Update ArtistProfileView clips grid to use infinite scroll (load next 20 at 200px from bottom)
    - Update tip history ledger to use virtual scrolling for >50 entries
    - _Requirements: 13.1, 13.2, 13.3, 13.6_
  
  - [x] 17.4 Preserve scroll position and loaded content on tab switch
    - Update ArtistProfileView TabBarView
    - Use AutomaticKeepAliveClientMixin for each tab content
    - _Requirements: 13.7_
  
  - [x]* 17.5 Write end-to-end integration tests
    - Test happy path: cache hit → fetch succeeds → fresh data displays
    - Test network failure path: fetch fails → error boundary shows → retry succeeds
    - Test offline path: offline → cached data → offline indicator → refresh on reconnect
    - Test optimistic failure path: follow toggle → UI updates → network fails → rollback → error toast
    - Test pagination path: scroll to bottom → load more triggers → spinner → items append
    - Test stale cache path: 25-hour-old cache → stale warning → refresh → fresh data
    - _Requirements: All requirements_

- [x] 18. Performance optimization
  - [x] 18.1 Add RepaintBoundary around shimmer animations
    - Update ProfileSkeletonScreen
    - Wrap each ShimmerBox in RepaintBoundary
    - _Requirements: Performance considerations_
  
  - [x] 18.2 Implement selective rebuilds with Riverpod select
    - Update ArtistProfileView and OwnerProfileView
    - Use `ref.watch(provider.select((s) => s.isLoading(type)))` for specific fields
    - _Requirements: Performance considerations_
  
  - [x] 18.3 Add request deduplication
    - Update EnhancedProfileNotifier
    - Track in-flight requests and return existing Future if duplicate fetch
    - _Requirements: Performance considerations_
  
  - [x] 18.4 Implement memory management for image cache
    - Update AsyncImageWithFallback or create ImageCacheManager
    - Limit decoded images in memory to 50 max with LRU eviction
    - Clear cache on memory warnings
    - _Requirements: Performance considerations_

- [x] 19. Documentation and cleanup
  - [x] 19.1 Add code documentation
    - Add dartdoc comments to all public classes and methods
    - Include usage examples in class-level documentation
    - _Requirements: All_
  
  - [x] 19.2 Create developer guide
    - Document how to use EnhancedProfileNotifier
    - Document how to add new profile operations with error handling
    - Document accessibility best practices
    - Document debug mode usage
    - _Requirements: All_
  
  - [x] 19.3 Update feature flags
    - Create FeatureFlags class with useEnhancedErrorHandling flag
    - Document rollback procedure
    - _Requirements: Integration approach_
  
  - [x] 19.4 Clean up deprecated code
    - Mark old ArtistProfileNotifier as deprecated
    - Add migration guide in deprecation notice
    - _Requirements: Integration approach_

- [x] 20. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional test tasks and can be skipped for faster MVP (though strongly recommended)
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at logical breaks
- Core implementation tasks (non-test) are not marked optional and must be implemented
- The implementation uses Dart/Flutter as specified in the design document
- All file paths are relative to `lib/` directory in the Flutter project
- Testing targets: Network layer 100%, State management 95%, UI components 85%

## Task Dependency Graph

```json
{
  "waves": [
    {
      "id": 0,
      "tasks": ["1", "2.1", "2.2", "2.3"]
    },
    {
      "id": 1,
      "tasks": ["2.4", "3.1", "3.2", "3.3", "3.4"]
    },
    {
      "id": 2,
      "tasks": ["2.5", "3.5", "5.1"]
    },
    {
      "id": 3,
      "tasks": ["3.6", "5.2", "6.1"]
    },
    {
      "id": 4,
      "tasks": ["3.7", "6.2", "6.3", "6.4", "6.5", "6.6", "8.1", "8.2", "8.3", "8.4", "8.5"]
    },
    {
      "id": 5,
      "tasks": ["6.7", "8.6", "9.1"]
    },
    {
      "id": 6,
      "tasks": ["9.2", "10.1", "10.2"]
    },
    {
      "id": 7,
      "tasks": ["9.3", "11.1", "11.2", "12.1", "12.2"]
    },
    {
      "id": 8,
      "tasks": ["11.3", "11.4", "11.5", "12.3", "12.4", "12.5"]
    },
    {
      "id": 9,
      "tasks": ["11.6", "14.1", "14.2", "14.3"]
    },
    {
      "id": 10,
      "tasks": ["14.4", "14.5", "14.6", "15.1", "15.2", "15.3"]
    },
    {
      "id": 11,
      "tasks": ["14.7", "15.4", "16.1", "16.2", "16.3", "16.4"]
    },
    {
      "id": 12,
      "tasks": ["17.1", "17.2", "17.3", "17.4"]
    },
    {
      "id": 13,
      "tasks": ["17.5", "18.1", "18.2", "18.3", "18.4"]
    },
    {
      "id": 14,
      "tasks": ["19.1", "19.2", "19.3", "19.4"]
    }
  ]
}
```
