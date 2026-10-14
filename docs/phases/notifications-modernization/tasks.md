# Implementation Plan: Notifications Modernization

## Overview

Transform the Phase 11 notification popup modal into a full-screen dedicated notifications center with 4 categories (Social, System, Creator Activity, Algorithmic), WCAG 2.1 AA accessibility compliance, offline persistence with Hive, and advanced features including swipe gestures, bulk actions, search, and filtering. This implementation maintains backward compatibility through feature flags and preserves all 24 existing tests.

**Key Deliverables:**
- Extended NotificationEntity domain model with categories, types, priority, metadata, and actions
- NotificationRepository data layer with Hive persistence (untyped box + in-memory fallback, zero build_runner)
- NotificationsView full-screen dedicated view with category filtering, search, and safe area metrics
- Integration with shell and top-bar bell (preserving canonical 5 tabs and NotificationsPopover)
- Accessibility compliance (semantic labels, keyboard navigation, touch targets)
- Complete coexistence with existing test suites

## Tasks

- [ ] 1. Set up project infrastructure and persistence
  - Verify dependencies in `pubspec.yaml`: `hive`, `hive_flutter`, `cached_network_image`
  - Register `AppConstants.notificationsBoxKey = 'vhunambi_notifications'` in `lib/core/constants/app_constants.dart`
  - Create directory structure: `lib/features/notifications/data/repositories`, `lib/features/notifications/data/models`, `lib/features/notifications/presentation/views`, `lib/features/notifications/presentation/widgets`
  - Ensure untyped Hive box setup (`Box? _box`) with automatic in-memory fallback pattern (zero build_runner / codegen dependencies)
  - _Requirements: 18.1, 18.2_

- [ ] 2. Extend NotificationEntity domain model with new fields
  - [ ] 2.1 Add NotificationCategory enum with values: social, system, creatorActivity, algorithmic
    - Include helper methods: fromString(), name
    - _Requirements: 2.1, 2.2_
  
  - [ ] 2.2 Add NotificationType enum with 26 specific types
    - Include all social types: newFollower, trackLiked, trackCommented, trackShared, mentionInComment, playlistInvite, remixCreated, tipReceived
    - Include all system types: emailVerified, subscriptionChanged, securityAlert, featureAnnouncement, maintenanceWindow
    - Include all creator activity types: generationComplete, stemSeparationComplete, videoExportReady, licensePurchase, releasePublished, analyticsMilestone
    - Include all algorithmic types: trackTrending, similarTracks, newReleaseFromFollowed, weeklyRecap, personalizedRecommendation, communityHighlights
    - Include helper methods: fromString(), name
    - _Requirements: 2.3, 2.4, 3.9, 4.6, 5.7, 6.7_
  
  - [ ] 2.3 Add NotificationPriority enum with values: low, normal, important, urgent
    - Include helper methods: fromString(), name
    - _Requirements: 7.1, 7.2_
  
  - [ ] 2.4 Add NotificationAction class with fields: actionId, label, actionType, actionData
    - Create NotificationActionType enum: navigate, apiCall, shareSheet, dialog
    - Add hand-rolled toJson() and fromJson() mapping
    - _Requirements: 9.2, 9.3_
  
  - [ ] 2.5 Extend NotificationEntity with new fields: category, type, priority, metadata, actions
    - Maintain backward compatibility with existing fields: id, title, message, targetTrackId, createdAt, isRead
    - Add hand-rolled JSON serialization methods: toJson(), fromJson()
    - Update copyWith() to include all new fields
    - Preserve existing equality operator and hashCode
    - _Requirements: 2.2, 2.4, 2.10, 7.1, 9.1, 28.5_
  
  - [ ] 2.6 Update generationReady() factory constructor to use new schema
    - Set category: creatorActivity, type: generationComplete, priority: important
    - Populate metadata with trackId, trackTitle, deepLinkRoute
    - Maintain backward compatibility with targetTrackId
    - _Requirements: 5.1, 28.3, 40.1, 40.3_
  
  - [ ] 2.7 Verify hand-rolled JSON serialization and deserialization
    - Ensure 100% round-trip fidelity between NotificationEntity and Map<String, dynamic>
    - Ensure zero build_runner or hive_generator dependency

- [ ] 3. Create NotificationConfig utility class with category-type mappings
  - Implement categoryForType() static method mapping each NotificationType to its NotificationCategory
  - Implement defaultPriority() static method returning priority per type (urgent for securityAlert, important for tipReceived/licensePurchase/generationComplete)
  - Implement defaultActions() static method returning context-specific action lists per type
  - _Requirements: 2.5, 7.7, 7.8, 9.5, 9.6, 9.7_

- [ ] 4. Implement NotificationRepository with Hive persistence
  - [ ] 4.1 Create SyncOperation model for offline sync queue
    - Define SyncOperationType enum: create, update, delete, markRead, markAllRead
    - Add fields: id, type, notification, notificationId, category, retryCount, createdAt
    - Add factory constructors: create(), update(), delete(), markRead(), markAllRead()
    - Add incrementRetry() method for exponential backoff
    - Add hand-rolled toJson() and fromJson() mapping
    - _Requirements: 21.7, 21.9_
  
  - [ ] 4.2 Implement NotificationRepository constructor and initialization
    - Accept optional `Box? box` parameter following Vhunambi repository standard
    - Implement automatic `_ensureInit()` and `_inMemoryFallback` map for headless test safety
    - Define constants: maxNotifications = 500, boxKey = AppConstants.notificationsBoxKey
    - _Requirements: 18.1, 18.7_
  
  - [ ] 4.3 Implement read operations: getAll(), getByCategory(), getUnread(), getByDateRange(), getById()
    - All methods return sorted by createdAt descending
    - getByCategory() filters by category field
    - getUnread() filters by isRead == false
    - getByDateRange() filters by createdAt between start and end
    - _Requirements: 2.8, 18.6_
  
  - [ ] 4.4 Implement write operations: save(), update(), delete()
    - save() enforces max 500 limit by evicting oldest read notification
    - All operations persist to Hive immediately
    - All operations queue backend sync if online, else add to sync queue
    - _Requirements: 18.3, 18.4, 18.5, 18.7, 18.8, 21.3, 21.4_
  
  - [ ] 4.5 Implement markAsRead() and markAllAsRead([category])
    - markAsRead() updates single notification isRead flag
    - markAllAsRead() updates all notifications in category (or all if category is null)
    - Both operations persist to Hive and sync to backend
    - _Requirements: 18.4, 21.3_
  
  - [ ] 4.6 Implement offline sync: syncOfflineActions()
    - Check connectivity using connectivity_plus
    - Process sync queue operations in FIFO order
    - Implement exponential backoff for failed operations (1s, 2s, 4s)
    - Remove operations after 3 retries or 4xx errors
    - _Requirements: 21.5, 21.6, 21.9, 24.6_
  
  - [ ] 4.7 Implement fetchLatest([since]) for real-time updates
    - Fetch notifications from backend API
    - Persist fetched notifications to Hive
    - Return fetched notifications list
    - _Requirements: 22.1, 22.6_
  
  - [ ] 4.8 Implement circuit breaker pattern for sync failures
    - Track consecutive failures counter
    - Open circuit after 5 consecutive failures
    - Pause sync attempts for 5 minutes when circuit open
    - Reset circuit on successful sync
    - _Requirements: 24.10_

- [ ] 5. Extend NotificationsNotifier with new methods
  - [ ] 5.1 Add NotificationRepository dependency injection
    - Update constructor to accept NotificationRepository
    - Remove in-memory-only initialization
    - _Requirements: 18.6_
  
  - [ ] 5.2 Implement loadFromCache() to initialize state from Hive
    - Call repository.getAll() on notifier initialization
    - Populate initial state with cached notifications
    - _Requirements: 18.6_
  
  - [ ] 5.3 Implement fetchLatest([since]) for pull-to-refresh
    - Call repository.fetchLatest() with optional since parameter
    - Update state with fetched notifications
    - Deduplicate by notification ID
    - _Requirements: 22.6, 22.7_
  
  - [ ] 5.4 Implement syncOfflineActions() wrapper
    - Delegate to repository.syncOfflineActions()
    - Update UI sync status indicator
    - _Requirements: 21.5_
  
  - [ ] 5.5 Implement executeAction(notificationId, actionId)
    - Look up notification and action by IDs
    - Execute action based on actionType (navigate, apiCall, shareSheet, dialog)
    - Update notification metadata with action result
    - Handle errors with ActionFailedException
    - _Requirements: 9.8, 9.9, 24.3_
  
  - [ ] 5.6 Implement filterByCategory(categories) method
    - Filter state to show only notifications in provided category set
    - Maintain original state for filter toggles
    - _Requirements: 8.3, 8.4_
  
  - [ ] 5.7 Update addNotification() to enforce max limit and deduplicate
    - Check if notification ID already exists (skip if duplicate)
    - Call repository.save() to persist
    - Enforce 500 notification limit
    - _Requirements: 18.7, 18.8, 22.7_
  
  - [ ] 5.8 Preserve existing methods for backward compatibility
    - Keep update(), markAsRead(), markAllAsRead(), removeNotification(), clearAll() signatures unchanged
    - Delegate to repository methods internally
    - _Requirements: 28.2, 28.3, 35.6, 35.8_

- [ ] 6. Create computed providers for derived state
  - Implement unreadByCategoryProvider: Map<NotificationCategory, int> computing unread count per category
  - Implement urgentNotificationsProvider: List<NotificationEntity> filtering priority == urgent
  - Implement filteredNotificationsProvider combining category filters, search query, date range filters
  - Preserve existing unreadNotificationsCountProvider logic unchanged
  - _Requirements: 7.10, 8.8, 12.2, 12.5, 35.9_

- [ ] 7. Create UI state providers
  - Implement categoryFilterStateProvider: StateProvider<Set<NotificationCategory>> with all categories active by default
  - Implement searchQueryProvider: StateProvider<String> for search input
  - Implement dateRangeFilterProvider: StateProvider<DateRange?> for date filtering
  - Implement selectionModeProvider: StateProvider<bool> for bulk actions
  - Implement selectedNotificationIdsProvider: StateProvider<Set<String>> for selected notifications
  - Persist categoryFilterStateProvider to Hive with key "notification_category_filters"
  - _Requirements: 8.6, 12.1, 12.5, 10.5, 18.9_

- [ ] 8. Implement TimeAgoUtils enhancements
  - Add support for weeks: "{n} weeks ago" for 7-29 days
  - Use intl package DateFormat for localized absolute dates (30+ days)
  - Add optional locale parameter for localization support
  - Preserve existing behavior for existing tests
  - _Requirements: 32.6, 32.7, 32.9, 32.10_

- [ ] 9. Create NotificationsView full-screen scaffold
  - [ ] 9.1 Implement NotificationsView StatefulWidget with scroll controller
    - Initialize ScrollController for pagination
    - Initialize TextEditingController for search
    - Add scroll listener for pagination trigger (200dp from bottom)
    - Integrate with Bottom_Dock_Metrics for safe area insets
    - _Requirements: 1.3, 1.4, 19.2_
  
  - [ ] 9.2 Implement _loadInitialData() loading cached notifications
    - Call NotificationsNotifier.loadFromCache()
    - Call _refreshNotifications() to fetch latest
    - _Requirements: 18.6, 19.8_
  
  - [ ] 9.3 Implement _refreshNotifications() for pull-to-refresh
    - Set _isRefreshing state flag
    - Call NotificationsNotifier.fetchLatest()
    - Clear _isRefreshing state on completion
    - _Requirements: 1.7, 1.8, 22.6_
  
  - [ ] 9.4 Implement _loadMore() for pagination
    - Check _isLoadingMore flag to prevent duplicate requests
    - Debounce by 500ms
    - Load next 50 notifications
    - Update _hasMore flag when no more notifications
    - _Requirements: 19.2, 19.3, 19.9_
  
  - [ ] 9.5 Build app bar with three states: normal, search, selection
    - Normal: title "Notifications", search icon, filter icon, mark all read button, settings icon
    - Search: back button, search TextField with autofocus, real-time filtering
    - Selection: close button, "{count} selected" title, mark as read icon, delete icon
    - All interactive elements minimum 44x44dp touch targets
    - Mark title as Semantics header: true
    - _Requirements: 1.9, 1.10, 10.5, 10.6, 12.1, 14.3, 16.2, 16.3_
  
  - [ ] 9.6 Build CustomScrollView body with RefreshIndicator
    - Wrap in RefreshIndicator with brand primary color
    - Include SliverToBoxAdapter for category filter row
    - Include SliverToBoxAdapter for active filter badges (conditional)
    - Include SliverFillRemaining or _NotificationList based on empty state
    - Include bottom safe area padding with Bottom_Dock_Metrics
    - _Requirements: 1.7, 8.1, 12.9_
  
  - [ ] 9.7 Implement empty state widget
    - Display Icons.notifications_off_outlined size 64dp
    - Display heading "No notifications yet" with AppTypography.titleLarge
    - Display description text based on filter context
    - Include "Clear filters" button when filters active
    - All text color AppColors.textTertiary
    - _Requirements: 33.1, 33.2, 33.3, 33.4, 33.8, 33.10_
  
  - [ ] 9.8 Implement loading states
    - Initial load: Skeleton screen with 6 shimmer placeholder cards
    - Pull-to-refresh: Loading spinner at top with 40dp height
    - Pagination: Loading spinner at bottom with 40dp height
    - Bulk actions (>10 items): Loading overlay with progress text
    - _Requirements: 23.1, 23.2, 23.4, 23.8_
  
  - [ ] 9.9 Implement error handling with SnackBars
    - Network error: "Unable to load notifications. Check your connection." with retry button
    - Timeout (>10s): Timeout message with retry button
    - Storage error: "Unable to save locally. Changes may be lost."
    - _Requirements: 24.1, 23.6, 24.5_

- [ ] 10. Checkpoint - Ensure NotificationsView renders and loads data
  - Verify NotificationsView displays cached notifications on load
  - Verify pull-to-refresh fetches latest notifications
  - Verify pagination loads additional notifications on scroll
  - Verify empty state displays when no notifications
  - Verify error handling shows appropriate messages
  - Ask the user if questions arise

- [ ] 11. Implement CategoryFilterRow widget
  - [ ] 11.1 Create _CategoryFilterRow ConsumerWidget
    - Display horizontal Row with 4 _CategoryChip widgets
    - Use ResponsiveUtils.isMobile() for responsive minHeight (44dp mobile, 36dp desktop)
    - Apply 16dp horizontal padding, 12dp vertical padding
    - _Requirements: 8.1, 8.2, 17.2, 17.7_
  
  - [ ] 11.2 Implement _CategoryChip widget
    - Display icon, label, unread badge, and active checkmark
    - Active state: category badge color background with 0.2 opacity, colored border
    - Inactive state: surfaceSecondary background, subtle border, reduced opacity
    - onTap: toggle category in categoryFilterStateProvider
    - onLongPress: show category context menu with "Mark all as read", "Delete all", "Turn off"
    - Minimum touch target per responsive constraints
    - Semantic label: "{label}, {unreadCount} unread, {active/inactive}"
    - _Requirements: 8.2, 8.3, 8.4, 8.5, 8.10, 10.9, 14.4, 16.4, 17.3_
  
  - [ ] 11.3 Define category colors matching design specification
    - Social: #8B5CF6 (purple)
    - System: #3B82F6 (blue)
    - Creator: #F97316 (orange)
    - Discovery: #10B981 (green)
    - Verify WCAG AA contrast ratios (4.5:1 minimum)
    - _Requirements: 2.7, 15.5_
  
  - [ ] 11.4 Implement category badge with count capping
    - Display unread count badge on each chip (top-right position)
    - Cap display at "9+" for counts > 9
    - Minimum badge dimensions 16x16dp with 8sp font
    - Use BorderRadius.circular(10) instead of circle to prevent oval distortion
    - _Requirements: 8.8, 31.1, 31.2, 31.4, 31.5, 31.8_
  
  - [ ] 11.5 Implement category context menu sheet
    - Display options: "Mark all as read in this category", "Delete all in this category", "Turn off this category"
    - Execute bulk operations via NotificationsNotifier
    - Show undo SnackBar after destructive actions
    - _Requirements: 10.9, 13.5_

- [ ] 12. Implement NotificationCard widget
  - [ ] 12.1 Create NotificationCard ConsumerWidget structure
    - Accept notification and isSelectionMode parameters
    - Implement responsive minHeight (60dp mobile, 56dp desktop)
    - Apply 12dp padding, rounded corners (12dp radius)
    - Read badge color with 2px border for urgent priority, 1px for others
    - Wrap in RepaintBoundary for paint isolation
    - _Requirements: 7.3, 7.4, 7.5, 16.5, 29.9_
  
  - [ ] 12.2 Implement category icon with badge overlay
    - Main icon: 40x40dp circle with surfaceSecondary background
    - Display avatar for social notifications (metadata.followerAvatarUrl or actorAvatarUrl)
    - Use CachedNetworkImage with error fallback to type icon
    - Category badge: positioned bottom-right, category color, category icon 10px
    - _Requirements: 2.6, 3.10_
  
  - [ ] 12.3 Build card content layout
    - Title row: title text (fontWeight 600) + unread indicator
    - Message + timestamp: "{message} • {timeAgo}" with caption style, 2 line max with ellipsis
    - Action buttons row (conditional on actions not empty)
    - Dismiss button: 32x32dp minimum touch target, close icon 16px
    - _Requirements: 14.5, 16.6, 16.9_
  
  - [ ] 12.4 Implement UnreadIndicator widget
    - Display blue dot (8x8dp circle) + "New" text label (9sp)
    - Semantic label: "Unread"
    - Only show when notification.isRead == false
    - _Requirements: 15.1, 15.2, 15.6_
  
  - [ ] 12.5 Implement ActionButtonsRow widget
    - Render TextButton for each action with responsive minSize (44dp mobile, 32dp desktop)
    - Display action.label text
    - onPressed: call executeAction() via NotificationsNotifier
    - Show loading spinner on button during execution
    - Handle errors with SnackBar and retry action
    - Semantic label: action.label
    - _Requirements: 9.3, 9.4, 9.8, 9.9, 16.7, 23.10_
  
  - [ ] 12.6 Implement swipe-to-dismiss gestures with Dismissible
    - Swipe right (startToEnd): mark as read, return false to keep in list
    - Swipe left (endToStart): delete, return true to dismiss from list
    - confirmDismiss threshold: 50% of card width
    - Background: blue with checkmark icon for right swipe
    - SecondaryBackground: red with delete icon for left swipe
    - onDismissed: show SnackBar with undo action (5 second duration)
    - Disable swipe when isSelectionMode is true
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.7, 11.9_
  
  - [ ] 12.7 Implement card tap and long-press interactions
    - onTap: if selectionMode, toggle selection; else mark as read and navigate
    - onLongPress: show context menu (if not in selection mode)
    - Deep-link navigation: parse metadata.deepLinkRoute or legacy targetTrackId
    - Support routes: /track/:id, /profile/:id, /settings/:page
    - Wrap Navigator.push() in try-catch for error handling
    - _Requirements: 26.1, 26.2, 26.3, 26.9, 24.2_
  
  - [ ] 12.8 Build comprehensive semantic label
    - Include unread status: "Unread notification" if !isRead
    - Include priority label: "Urgent" if urgent, "Important" if important
    - Include title, message, and time ago
    - Format: "{unreadStatus}{priorityLabel}{title}, {message}, {timeAgo}"
    - _Requirements: 14.5, 15.2_
  
  - [ ] 12.9 Implement SelectionCheckbox widget for bulk actions
    - Display Checkbox with minimum 44dp touch target
    - Show only when isSelectionMode is true
    - onChanged: toggle notificationId in selectedNotificationIdsProvider
    - Visible border in unchecked state for accessibility
    - _Requirements: 10.5, 10.6, 15.9, 16.8_

- [ ] 13. Implement NotificationList with date grouping
  - [ ] 13.1 Create _NotificationList widget with date section logic
    - Group notifications by date: "Today", "Yesterday", "This Week", "This Month", "Older"
    - Use SliverList.builder for virtual scrolling
    - Insert sticky section headers between date groups
    - _Requirements: 20.1, 20.2, 20.3, 19.4_
  
  - [ ] 13.2 Implement date grouping algorithm
    - Today: createdAt on current date
    - Yesterday: createdAt on previous date
    - This Week: last 7 days excluding today/yesterday
    - This Month: current month excluding last 7 days
    - Older: before current month
    - _Requirements: 20.4, 20.5, 20.6, 20.7, 20.8_
  
  - [ ] 13.3 Implement sticky section headers
    - Header style: AppTypography.titleSmall, AppColors.textSecondary
    - Display section name and unread count: "Today (3 unread)"
    - Maintain visible while scrolling through section
    - Support tap to collapse/expand section with state persistence
    - _Requirements: 20.2, 20.9, 20.10_
  
  - [ ] 13.4 Wrap notification cards with RepaintBoundary
    - Isolate card repaints during updates
    - Improve scroll performance
    - _Requirements: 29.9_

- [ ] 14. Implement search and advanced filtering
  - [ ] 14.1 Build search bar in app bar
    - Display TextField with autofocus when search icon tapped
    - Hint text: "Search notifications..."
    - onChanged: update searchQueryProvider with 300ms debounce
    - Back button to clear search and return to normal app bar
    - _Requirements: 12.1, 29.6_
  
  - [ ] 14.2 Implement case-insensitive substring search
    - Filter notifications where title or message contains query
    - Use toLowerCase() for case-insensitive matching
    - Support partial word matching
    - _Requirements: 12.2, 12.3_
  
  - [ ] 14.3 Build filter sheet with date range and options
    - Display ModalBottomSheet with surfaceModal background
    - Date range selectors: "Today", "Last 7 days", "Last 30 days", "Custom range"
    - "Show read" toggle to include/exclude read notifications
    - Priority checkboxes for multi-select filtering
    - Apply button to commit filters
    - _Requirements: 12.4, 12.5, 12.6, 12.7, 12.8_
  
  - [ ] 14.4 Implement ActiveFilterBadges widget
    - Display Chip for each active filter: date range, "Unread only", priorities
    - Position below category filter row
    - onTap: remove filter and refresh list
    - _Requirements: 12.9, 12.10_
  
  - [ ] 14.5 Implement filteredNotificationsProvider logic
    - Combine category filters, search query, date range, show read toggle, priorities
    - Apply filters in sequence maintaining performance
    - Cache filtered results to prevent excessive recomputation
    - _Requirements: 12.2, 12.5, 12.6, 12.8_

- [ ] 15. Implement bulk actions functionality
  - [ ] 15.1 Add selection mode toggle in app bar
    - Icon button to enter/exit selection mode
    - Update selectionModeProvider state on toggle
    - _Requirements: 10.4, 10.5_
  
  - [ ] 15.2 Implement bulk "Mark as read" action
    - Read selectedNotificationIdsProvider set
    - Call NotificationsNotifier.markAsRead() for each selected ID
    - Show loading overlay with progress text if >10 selections
    - Display SnackBar on completion with undo action
    - _Requirements: 10.6, 10.8, 10.10, 23.8_
  
  - [ ] 15.3 Implement bulk "Delete" action
    - Read selectedNotificationIdsProvider set
    - Call NotificationsNotifier.removeNotification() for each selected ID
    - Show loading overlay with progress text if >10 selections
    - Display SnackBar with undo action (5 second duration)
    - _Requirements: 10.6, 10.7, 10.10_
  
  - [ ] 15.4 Implement "Mark all read" in category context menu
    - Show options sheet on category long-press
    - Execute NotificationsNotifier.markAllAsRead(category)
    - Display confirmation SnackBar
    - _Requirements: 8.9, 10.2, 10.3_
  
  - [ ] 15.5 Implement undo mechanism for bulk actions
    - Store deleted/modified notifications in temporary cache (5 second expiry)
    - On undo: restore notifications from cache
    - Clear cache after expiry
    - _Requirements: 10.10, 11.7, 11.8_

- [ ] 16. Implement notification context menu
  - [ ] 16.1 Build NotificationContextMenu bottom sheet
    - Display on notification long-press
    - Options: "Mute this type", "Mute from @username" (social only), "Report", "Turn off category", "Delete"
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5, 13.10_
  
  - [ ] 16.2 Implement "Mute this type" functionality
    - Persist mute preference to Hive with key "notification_mute_preferences"
    - Filter out muted types in NotificationsNotifier.addNotification()
    - _Requirements: 13.2, 13.6, 18.10_
  
  - [ ] 16.3 Implement "Mute from @username" functionality
    - Extract actorUsername from metadata
    - Persist user mute list to Hive
    - Filter out notifications from muted users
    - Display muted users in NotificationSettingsView
    - _Requirements: 13.3, 13.7, 25.8_
  
  - [ ] 16.4 Implement "Report" dialog
    - Display reasons: "Spam", "Harassment", "Inappropriate", "Other"
    - Submit report to backend API
    - Hide reported notification locally
    - _Requirements: 13.4, 13.8, 13.9_
  
  - [ ] 16.5 Implement "Turn off category" toggle
    - Update category filter state to exclude category
    - Persist preference to Hive
    - _Requirements: 13.5_

- [ ] 17. Checkpoint - Test notification interactions and bulk actions
  - Verify notification tap navigates to correct deep-link route
  - Verify swipe gestures mark as read and delete correctly
  - Verify selection mode allows multi-select and bulk actions
  - Verify context menu shows correct options per category
  - Verify undo restores deleted notifications within 5 seconds
  - Ask the user if questions arise

- [ ] 18. Integrate NotificationsView with Shell & Safe Area Architecture
  - [ ] 18.1 Register NotificationsView route and push helper
    - Register `/notifications` named route and push helper
    - Preserve RootShell 5 canonical destinations intact (0: Home, 1: Explore, 2: Create, 3: Library, 4: Market)
    - _Requirements: 27.1, 27.2_
  
  - [ ] 18.2 Integrate with VhunambiTopBarMetrics
    - Ensure NotificationsView app bar respects system top padding and kToolbarHeight
    - _Requirements: 27.3_
  
  - [ ] 18.3 Integrate with VhunambiBottomDockMetrics
    - Apply bottom dock scroll inset to ensure last card clears 60px mini-player / 72px desktop DAW dock
    - _Requirements: 27.4, 27.5_
  
  - [ ] 18.4 Display unread badge on top bar NotificationBellButton
    - Read unreadNotificationsCountProvider
    - Display badge with count if > 0 (cap at "9+" for counts > 9)
    - Use red badge if any unread has priority urgent
    - _Requirements: 27.6, 27.7, 7.10, 31.9_
  
  - [ ] 18.5 Implement badge bounce animation on new notification
    - Animate badge with bounce effect when new notification arrives
    - Use 400ms duration animation
    - _Requirements: 27.8, 30.3_
  
  - [ ] 18.6 Support deep-link navigation: vhunambi://notifications
    - Register URL scheme handler to push NotificationsView
    - _Requirements: 27.9, 27.10_

- [ ] 19. Enhance NotificationsPopover with Full-Center Navigation
  - [ ] 19.1 Add "View All Alerts in Center ➔" CTA inside NotificationsPopover
    - Position at bottom of popover list (minHeight: 44px)
    - On tap: closes popover and navigates to NotificationsView
    - Preserve NotificationBellButton opening NotificationsPopover by default (keeping notification_bell_button_test.dart 100% green)
    - _Requirements: 28.1, 28.2_
  
  - [ ] 19.2 Add semantic label with unread count
    - Update Semantics label: "Notifications, {count} unread" or "Notifications, no unread"
    - Ensure screen reader announces full label
    - _Requirements: 14.1, 14.2_
  
  - [ ] 19.3 Fix badge container shape to prevent oval distortion
    - Replace BoxShape.circle with BorderRadius.circular(10)
    - Ensure badge accommodates "9+" text without overflow
    - _Requirements: 31.6, 31.7_
  
  - [ ] 19.4 Update badge colors with theme colors
    - Use AppColors.brandPrimary and AppColors.brandContrast
    - Support red badge for urgent notifications
    - _Requirements: 7.10_
  
  - [ ] 19.5 Ensure touch target compliance
    - Verify ConstrainedBox minWidth 44dp, minHeight 44dp on mobile
    - Use ResponsiveUtils.isMobile() for responsive sizing (36dp desktop)
    - _Requirements: 16.1, 17.6_

- [ ] 20. Implement NotificationSettingsView
  - [ ] 20.1 Create NotificationSettingsView scaffold
    - App bar title: "Notification Settings"
    - Scrollable body with ListView
    - _Requirements: 25.1_
  
  - [ ] 20.2 Build category enable/disable toggles
    - Display SwitchListTile for each NotificationCategory
    - Persist enabled categories to Hive
    - Update NotificationsNotifier to filter disabled categories
    - _Requirements: 25.2, 25.3_
  
  - [ ] 20.3 Build expandable sections for notification type toggles
    - ExpansionTile per category showing all NotificationTypes in that category
    - SwitchListTile for each type
    - Persist enabled types to Hive
    - _Requirements: 25.4, 25.5_
  
  - [ ] 20.4 Implement Quiet Hours feature
    - Display start time and end time pickers
    - Suppress notifications during quiet hours (except urgent priority)
    - Persist quiet hours to Hive
    - _Requirements: 25.6, 25.7_
  
  - [ ] 20.5 Display Muted Users section
    - List all muted usernames from Hive preference
    - Display "Unmute" button per user
    - Update mute list on unmute action
    - _Requirements: 25.8_
  
  - [ ] 20.6 Implement Do Not Disturb toggle
    - Suppress all notifications except urgent priority when enabled
    - Display prominent toggle at top of settings
    - Persist to Hive
    - _Requirements: 25.9_
  
  - [ ] 20.7 Implement notification sound and haptics toggles
    - "Notification Sounds" toggle to enable/disable sounds
    - "Haptic Feedback" toggle to enable/disable haptics
    - Persist both to Hive
    - Respect system Do Not Disturb mode
    - _Requirements: 34.4, 34.5, 34.6, 34.9_

- [ ] 21. Implement notification sound and haptic feedback
  - Play notification sound for urgent priority (platform-appropriate sound)
  - Trigger light haptic feedback for important priority
  - No sound/haptics for normal/low priority
  - Respect notification settings toggles
  - Trigger success haptic on "Mark all as read"
  - _Requirements: 34.1, 34.2, 34.3, 34.8, 34.10_

- [ ] 22. Implement real-time notification delivery
  - [ ] 22.1 Set up WebSocket connection to backend for real-time push
    - Establish WebSocket on app start
    - Listen for notification events
    - _Requirements: 22.4_
  
  - [ ] 22.2 Implement polling fallback if WebSocket fails
    - Poll every 30 seconds when WebSocket disconnected
    - _Requirements: 22.5_
  
  - [ ] 22.3 Deduplicate notifications by ID
    - Track seen notification IDs
    - Skip notifications already in state
    - _Requirements: 22.7_
  
  - [ ] 22.4 Animate new notification sliding in from top
    - Use SlideTransition with 300ms duration, easeOut curve
    - Only animate when NotificationsView is active
    - _Requirements: 22.2, 30.1_
  
  - [ ] 22.5 Implement heads-up notification banner for urgent priority
    - Display banner overlay at top of screen
    - Auto-dismiss after 5 seconds
    - onTap: navigate to NotificationsView and highlight notification
    - Use spring physics animation for slide-down
    - _Requirements: 22.8, 22.9, 22.10, 30.10_

- [ ] 23. Implement accessibility features
  - [ ] 23.1 Add semantic labels to all interactive elements
    - Notification bell: "Notifications, {count} unread"
    - App bar actions: descriptive labels
    - Category chips: "{label}, {unreadCount} unread, {active/inactive}"
    - Notification cards: full semantic label with unread/priority/content
    - Action buttons: action.label
    - _Requirements: 14.1, 14.2, 14.4_
  
  - [ ] 23.2 Implement keyboard navigation with FocusTraversalGroup
    - Tab order: app bar → category filters → notification list → bottom navigation
    - Enter/Space activates focused buttons
    - Escape closes search bar, filter sheet, context menus
    - _Requirements: 14.6, 14.8, 14.9, 14.10_
  
  - [ ] 23.3 Add visible focus indicators
    - 2px outline on focused elements
    - 4.5:1 contrast ratio against background
    - _Requirements: 14.7_
  
  - [ ] 23.4 Verify color contrast ratios (WCAG AA)
    - All text: minimum 4.5:1
    - All UI elements: minimum 3:1
    - Category badge colors verified: purple #8B5CF6, blue #3B82F6, orange #F97316, green #10B981
    - _Requirements: 15.3, 15.4, 15.5_
  
  - [ ] 23.5 Support system text scaling up to 200%
    - Test all text with system font size at 200%
    - Verify no clipping or overflow
    - _Requirements: 15.10_
  
  - [ ] 23.6 Mark headers with proper semantic roles
    - App bar title: header: true, level 1
    - Category section headers: header: true, level 2
    - Notification card titles: header: true, level 3
    - _Requirements: 14.3, 14.4, 14.5_

- [ ] 24. Coexistence & Dual Entry Point Support
  - [ ] 24.1 Ensure NotificationsPopover and NotificationsView stay in sync
    - Both read from unified notificationsProvider
    - Marking read in one immediately updates the other
    - _Requirements: 28.3, 28.8_
  
  - [ ] 24.2 Provide direct push callback on NotificationBellButton
    - Support optional onNavigateToCenter callback for custom routes
    - Default behavior opens popover with "View All Alerts" action
    - _Requirements: 28.9, 28.10_

- [ ] 25. Implement animations and visual polish
  - Notification slide-in animation: 300ms easeOut from top
  - Notification dismiss animation: 250ms easeIn slide-out
  - Badge count bounce animation: 400ms bounce on update
  - Unread dot fade-out: 200ms on mark as read
  - Category chip background transition: 200ms on toggle
  - Sticky header elevation shadow: 150ms fade-in
  - Bulk action staggered fade-out: 50ms offset between cards
  - App bar title fade-in: 300ms on view load
  - _Requirements: 30.1, 30.2, 30.3, 30.4, 30.5, 30.6, 30.8, 30.9_

- [ ] 26. Checkpoint - Test full notification flow end-to-end
  - Verify new notification arrives via WebSocket and appears in list
  - Verify badge updates immediately on new notification
  - Verify category filtering shows/hides correct notifications
  - Verify search filters by title and message
  - Verify swipe gestures work correctly
  - Verify deep-link navigation to tracks, profiles, settings
  - Verify offline sync queues actions and syncs when online
  - Verify all animations play smoothly
  - Verify accessibility with screen reader (TalkBack/VoiceOver)
  - Ask the user if questions arise

- [ ] 27. Verify existing notification test suites
  - [ ] 27.1 Verify notification_bell_button_test.dart
    - Ensure all 7 existing tests pass without modification (tapping bell opens NotificationsPopover)
    - Add test for unread badge "9+" capping
    - _Requirements: 35.4_
  
  - [ ] 27.2 Preserve notification_entity_test.dart
    - Verify all 11 tests pass with extended model
    - Verify copyWith() includes new fields
    - Verify fromJson/toJson round-trip preserves metadata
    - _Requirements: 35.1_
  
  - [ ] 27.3 Preserve notifications_provider_test.dart
    - Verify all 11 tests pass with extended notifier
    - Verify update() adapter maintains backward compatibility
    - Verify unreadNotificationsCountProvider logic unchanged
    - _Requirements: 35.2, 35.6, 35.9_
  
  - [ ] 27.4 Verify notifications_popover_test.dart
    - Verify all 8 existing tests pass without modification
    - Add test for "View All Alerts in Center ➔" button
    - _Requirements: 35.3_

- [ ] 28. Write integration tests for new features
  - Write test: complete notification lifecycle (create → persist → display → tap → navigate → mark read)
  - Write test: offline-online sync (offline actions → queue → online → sync)
  - Write test: category filtering (toggle categories → list updates → persist → restore)
  - Write test: search and filter combination (search + date range + show read toggle)
  - Write test: bulk actions (selection mode → select multiple → mark read → undo)
  - Write test: swipe gestures (swipe right marks read, swipe left deletes with undo)
  - Write test: deep-link navigation to all route types (track, profile, playlist, settings)

- [ ] 29. Performance optimization and profiling
  - [ ] 29.1 Verify initial render < 500ms with 50 notifications
    - Measure with stopwatch in _loadInitialData()
    - Log warning if exceeds target
    - _Requirements: 29.1, 36.1_
  
  - [ ] 29.2 Verify 60fps scrolling with 100 loaded notifications
    - Use WidgetsBinding.instance.addTimingsCallback()
    - Log frame jank warnings (>16ms)
    - _Requirements: 29.2, 36.2_
  
  - [ ] 29.3 Verify category filter toggle < 100ms
    - Measure state update to render time
    - _Requirements: 29.5, 36.3_
  
  - [ ] 29.4 Verify search debounce works (300ms delay)
    - Test rapid typing doesn't trigger excessive filters
    - _Requirements: 29.6_
  
  - [ ] 29.5 Verify pagination Hive query < 50ms
    - Measure repository.getAll() with 500 notifications
    - _Requirements: 36.6_
  
  - [ ] 29.6 Profile in release mode and optimize bottlenecks
    - Run flutter run --release --profile
    - Use DevTools performance view
    - Target <100ms first meaningful paint
    - _Requirements: 36.10_

- [ ] 30. Final integration testing and bug fixes
  - Test all notification types display correctly (26 types across 4 categories)
  - Test all deep-link routes navigate correctly
  - Test all error scenarios display appropriate messages
  - Test offline mode works correctly (cached data, sync queue)
  - Test accessibility features with screen reader
  - Test responsive design on mobile and desktop viewports
  - Fix any bugs discovered during testing
  - Verify all 24 existing tests pass
  - Verify all new tests pass

- [ ] 31. Documentation and rollout preparation
  - Update feature documentation with new notifications capabilities
  - Document migration guide from legacy popup to full-screen view
  - Document feature flag rollout strategy
  - Create release notes covering all new features
  - Prepare A/B test configuration for gradual rollout
  - Document backward compatibility guarantees

- [ ] 32. Implement Kinetic Fluidity, Haptic Choreography & Micro-Interactions
  - [ ] 32.1 Implement `NotificationsHaptics` service
    - File: `lib/features/notifications/presentation/utils/notifications_haptics.dart`
    - Methods: `bellRing()`, `dismissSnap()`, `categorySwitch()`, `markAllReadPulse()`, `itemTap()`
    - Check `!kIsWeb` and wrap in silent try/catch
    - _Requirements: 41.1, 41.2_
  
  - [ ] 32.2 Implement elastic swipe-to-dismiss in `NotificationItemTile`
    - Threshold at 80px / 0.25 drag fraction
    - Trigger `NotificationsHaptics.dismissSnap()` when threshold crossed
    - Trash icon scales up from 0.8 to 1.2 (`Curves.easeOutBack`)
    - Collapse vertically over 220ms on dismiss
    - _Requirements: 41.3, 41.4, 41.5_

  - [ ] 32.3 Implement kinetic sliding category pill & bouncing badges
    - Sliding pill with `Curves.easeOutCubic` (240ms)
    - Badge bounce (`scale: 1.0` -> `1.25` -> `1.0`) on unread count update
    - Trigger `NotificationsHaptics.categorySwitch()` on chip tap
    - _Requirements: 41.6, 41.7_

  - [ ] 32.4 Implement ringing bell wobble on `NotificationBellButton`
    - 3-cycle dampened sine rotation (`±14°` over 320ms) on tap and high-priority arrival
    - Double-tick haptic on tap via `NotificationsHaptics.bellRing()`
    - _Requirements: 41.9_

  - [ ] 32.5 Implement celebratory bulk "Mark all read" glow fade
    - Smooth fade out of unread indicator dots over 300ms
    - Trigger `NotificationsHaptics.markAllReadPulse()`
    - _Requirements: 41.8_

  - [ ] 32.6 Write kinetic suite tests
    - File: `test/features/notifications/presentation/utils/notifications_haptics_test.dart`
    - Test: All haptic methods run cleanly in headless VM test runner without throwing
    - File: `test/features/notifications/presentation/widgets/notification_item_tile_test.dart`
    - Test: Swipe dismiss triggers callback and animates
    - _Requirements: 41.1, 41.2, 41.10_

## Notes

- **Backward Compatibility**: All existing NotificationEntity fields (id, title, message, targetTrackId, createdAt, isRead) are preserved. The update() adapter method maintains the StateProvider contract. All 24 existing tests continue to pass without modification.

- **Dual-Surface Coexistence**: NotificationsPopover remains the fast, anchored quick-preview on header bell click across desktop/mobile. It includes a prominent "View All Alerts in Center ➔" CTA navigating to the dedicated full-screen NotificationsView.

- **Zero-Codegen Architecture**: Adheres strictly to Vhunambi's repository standard (PlaylistRepository, CollectionRepository, BeatRepository): hand-rolled JSON serialization (`toJson` / `fromJson`) with an untyped Hive Box (`Box? _box`) and automatic in-memory fallback for headless test safety. No build_runner or hive_generator.

- **RootShell Integrity**: Preserves RootShell's 5 canonical destinations (0: Home, 1: Explore, 2: Create, 3: Library, 4: Market). NotificationsView is accessed as a dedicated route, avoiding breaking tab index assertions in tests.

- **Performance Optimization**: Virtual scrolling with ListView.builder, pagination with 50-item pages, RepaintBoundary isolation, Hive indexed queries, and image caching ensure smooth performance with thousands of notifications.

- **Accessibility Compliance**: Full WCAG 2.1 AA compliance with semantic labels, keyboard navigation, visible focus indicators, 4.5:1 contrast ratios, responsive touch targets (44dp mobile, 32dp desktop), and screen reader support.

- **Offline-First Architecture**: NotificationRepository with Hive persistence, offline sync queue with exponential backoff, circuit breaker pattern after 5 failures, and connectivity monitoring enable robust offline support.

- **Testing Strategy**: Property-based tests for domain logic, widget tests for UI interactions, integration tests for end-to-end flows, and performance profiling ensure production-ready quality.

## Task Dependency Graph

```json
{
  "waves": [
    {
      "id": 0,
      "tasks": ["1", "2.1", "2.2", "2.3", "2.4"]
    },
    {
      "id": 1,
      "tasks": ["2.5", "2.6", "3", "4.1", "8"]
    },
    {
      "id": 2,
      "tasks": ["2.7", "4.2", "4.3", "4.4", "5.1", "6", "7"]
    },
    {
      "id": 3,
      "tasks": ["4.5", "4.6", "4.7", "5.2", "5.3", "5.7", "5.8"]
    },
    {
      "id": 4,
      "tasks": ["4.8", "5.4", "5.5", "5.6", "9.1", "9.2"]
    },
    {
      "id": 5,
      "tasks": ["9.3", "9.4", "9.5", "9.6", "9.7", "11.1", "11.2", "11.3"]
    },
    {
      "id": 6,
      "tasks": ["9.8", "9.9", "11.4", "11.5", "12.1", "12.2", "12.3"]
    },
    {
      "id": 7,
      "tasks": ["10", "12.4", "12.5", "12.6", "12.7", "12.8", "12.9"]
    },
    {
      "id": 8,
      "tasks": ["13.1", "13.2", "13.3", "13.4", "14.1", "14.2"]
    },
    {
      "id": 9,
      "tasks": ["14.3", "14.4", "14.5", "15.1", "15.2", "15.3"]
    },
    {
      "id": 10,
      "tasks": ["15.4", "15.5", "16.1", "16.2", "16.3", "16.4", "16.5"]
    },
    {
      "id": 11,
      "tasks": ["17", "18.1", "18.2", "18.3", "18.4"]
    },
    {
      "id": 12,
      "tasks": ["18.5", "18.6", "18.7", "19.1", "19.2", "19.3", "19.4", "19.5"]
    },
    {
      "id": 13,
      "tasks": ["20.1", "20.2", "20.3", "20.4", "20.5", "20.6", "20.7", "21"]
    },
    {
      "id": 14,
      "tasks": ["22.1", "22.2", "22.3", "22.4", "22.5", "23.1", "23.2"]
    },
    {
      "id": 15,
      "tasks": ["23.3", "23.4", "23.5", "23.6", "24.1", "24.2", "24.3", "25"]
    },
    {
      "id": 16,
      "tasks": ["26", "27.1", "27.2", "27.3", "27.4", "28"]
    },
    {
      "id": 17,
      "tasks": ["29.1", "29.2", "29.3", "29.4", "29.5", "29.6"]
    },
    {
      "id": 18,
      "tasks": ["30", "31"]
    }
  ]
}
```
