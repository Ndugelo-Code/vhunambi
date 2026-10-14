# Requirements Document

## Introduction

This specification defines the transformation of VHUNAMBI's notification system from a modal popup (Phase 11 implementation) to a full-featured, accessible, category-based notifications center. The modernization addresses critical accessibility violations identified in the audit report, implements approved enhancement phases (A-E), and expands functionality to support VHUNAMBI's social platform features including followers, tips, comments, collaborations, and algorithmic discovery.

The transformation maintains backward compatibility with existing `notificationsProvider` state while introducing:
- Full-screen dedicated notifications view accessible via NotificationBellButton and NotificationsPopover
- Four distinct notification categories (Social, System, Creator Activity, Algorithmic)
- Visual categorization system with color-coded badges and category-specific icons
- Advanced filtering, bulk actions, and search capabilities
- WCAG 2.1 AA accessibility compliance
- Persistent storage with offline support
- Rich notification types with context-specific actions

## Glossary

- **Notifications_System**: The complete notification subsystem including domain models, state management, storage, UI components, and navigation integration
- **Notification_Entity**: Domain model representing a single notification with type, category, priority, metadata, and actions
- **Notifications_View**: Full-screen dedicated view for browsing, filtering, and managing notifications
- **Notification_Bell**: Icon button in app bars that displays unread count badge and opens popover / navigates to Notifications_View
- **Notification_Popover**: Header modal dialog component (Phase 11) for quick previews, coexisting with Notifications_View with a "View All Alerts" action
- **Category_Filter**: UI component allowing users to show/hide notification categories
- **Bulk_Action**: Operation applied to multiple notifications simultaneously (mark all read, delete all)
- **Notification_Repository**: Data access layer managing persistence to Hive storage and synchronization with backend
- **Root_Shell**: Top-level navigation container with 5 canonical destinations (0: Home, 1: Explore, 2: Create, 3: Library, 4: Market)
- **Bottom_Dock_Metrics**: System providing safe area insets for bottom navigation coordination
- **Screen_Reader**: Assistive technology that reads UI elements aloud for visually impaired users
- **Touch_Target**: Interactive area of a UI element, must be minimum 44x44dp per HIG
- **Semantic_Label**: Text description provided to screen readers for accessibility
- **Deep_Link**: Navigation route to specific content (tracks, profiles, playlists, settings)
- **Hive_Storage**: Local NoSQL database for offline data persistence
- **Virtual_Scrolling**: Performance optimization technique rendering only visible list items
- **Skeleton_Screen**: Loading placeholder matching final content layout
- **Swipe_Gesture**: Touch interaction where user drags finger horizontally across element

## Requirements

### Requirement 1: Dedicated Full-Screen Notifications View

**User Story:** As a VHUNAMBI user, I want a dedicated full-screen notifications view accessible from the header bell and popover, so that I can browse and manage all my notifications in one place with rich filtering and bulk management.

#### Acceptance Criteria

1. THE Root_Shell SHALL strictly preserve its 5 canonical destinations (0: Home, 1: Explore, 2: Create, 3: Library, 4: Market) without inserting a 6th bottom navigation tab
2. WHEN the user taps "View All Alerts in Center ➔" inside the Notifications_Popover or triggers the full notifications route, THE system SHALL navigate to the Notifications_View
3. THE Notifications_View SHALL render as a full-height scrollable view with app bar and bottom safe area insets
4. THE Notifications_View SHALL integrate with Bottom_Dock_Metrics to respect persistent player and dock height
5. THE Notifications_View SHALL provide full keyboard traversal and focus order
6. THE Notification_Bell in all app bars SHALL open the Notifications_Popover for quick previews, with an option to push Notifications_View
7. THE Notifications_View SHALL support pull-to-refresh gesture to fetch latest notifications
8. WHEN the Notifications_View is refreshing, THE Notifications_View SHALL display a loading indicator at the top
9. THE Notifications_View app bar SHALL display "Notifications" as the title
10. THE Notifications_View app bar SHALL include a settings icon button that navigates to notification preferences

### Requirement 2: Notification Category System

**User Story:** As a VHUNAMBI user, I want notifications organized into clear categories (Social, System, Creator Activity, Algorithmic), so that I can quickly identify and filter notification types.

#### Acceptance Criteria

1. THE Notification_Entity SHALL define a `NotificationCategory` enum with values: `social`, `system`, `creatorActivity`, `algorithmic`
2. THE Notification_Entity SHALL include a `category` field of type `NotificationCategory`
3. THE Notification_Entity SHALL define a `NotificationType` enum with at least 20 specific types including: `newFollower`, `trackLiked`, `trackCommented`, `trackShared`, `mentionInComment`, `playlistInvite`, `remixCreated`, `tipReceived`, `emailVerified`, `subscriptionChanged`, `securityAlert`, `featureAnnouncement`, `generationComplete`, `stemSeparationComplete`, `videoExportReady`, `licensePurchase`, `releasePublished`, `analyticsMilestone`, `trackTrending`, `weeklyRecap`
4. THE Notification_Entity SHALL include a `type` field of type `NotificationType`
5. THE Notifications_System SHALL map each `NotificationType` to exactly one `NotificationCategory`
6. WHEN rendering a notification, THE Notifications_View SHALL display a category-specific icon: `Icons.person` for social, `Icons.settings` for system, `Icons.music_note` for creatorActivity, `Icons.trending_up` for algorithmic
7. WHEN rendering a notification, THE Notifications_View SHALL display a category-specific badge color: purple for social, blue for system, orange for creatorActivity, green for algorithmic
8. THE Notifications_View SHALL group notifications by category with section headers displaying category name and unread count
9. WHEN a notification category has zero notifications, THE Notifications_View SHALL hide that category section
10. THE Notification_Entity SHALL include a `metadata` field of type `Map<String, dynamic>` to store type-specific data

### Requirement 3: Social Notifications

**User Story:** As a VHUNAMBI creator, I want to receive notifications when users interact with my content or profile, so that I can engage with my audience and build community.

#### Acceptance Criteria

1. WHEN a user follows the creator, THE Notifications_System SHALL create a notification with type `newFollower` containing follower user ID and username in metadata
2. WHEN a user likes the creator's track, THE Notifications_System SHALL create a notification with type `trackLiked` containing track ID, track title, and liker username in metadata
3. WHEN a user comments on the creator's track, THE Notifications_System SHALL create a notification with type `trackCommented` containing track ID, comment ID, comment preview, and commenter username in metadata
4. WHEN a user shares the creator's track, THE Notifications_System SHALL create a notification with type `trackShared` containing track ID and sharer username in metadata
5. WHEN a user mentions the creator in a comment, THE Notifications_System SHALL create a notification with type `mentionInComment` containing comment ID, comment preview, and mentioner username in metadata
6. WHEN a user invites the creator to a collaborative playlist, THE Notifications_System SHALL create a notification with type `playlistInvite` containing playlist ID, playlist name, and inviter username in metadata
7. WHEN a user creates a remix of the creator's track, THE Notifications_System SHALL create a notification with type `remixCreated` containing original track ID, remix track ID, and remixer username in metadata
8. WHEN a user sends a tip to the creator, THE Notifications_System SHALL create a notification with type `tipReceived` containing tip amount, currency, and tipper username in metadata
9. THE Notifications_System SHALL set category to `social` for all notification types: `newFollower`, `trackLiked`, `trackCommented`, `trackShared`, `mentionInComment`, `playlistInvite`, `remixCreated`, `tipReceived`
10. WHEN rendering a social notification, THE Notifications_View SHALL display the actor's profile avatar as the notification icon

### Requirement 4: System Notifications

**User Story:** As a VHUNAMBI user, I want to receive notifications about account changes, security events, and platform announcements, so that I stay informed about my account status.

#### Acceptance Criteria

1. WHEN the user's email is verified, THE Notifications_System SHALL create a notification with type `emailVerified`
2. WHEN the user's subscription changes, THE Notifications_System SHALL create a notification with type `subscriptionChanged` containing old plan, new plan, and effective date in metadata
3. WHEN a new device logs into the user's account, THE Notifications_System SHALL create a notification with type `securityAlert` containing device type, location, and timestamp in metadata
4. WHEN the platform announces a new feature, THE Notifications_System SHALL create a notification with type `featureAnnouncement` containing feature name and description in metadata
5. WHEN scheduled maintenance is upcoming, THE Notifications_System SHALL create a notification with type `maintenanceWindow` containing start time, duration, and affected services in metadata
6. THE Notifications_System SHALL set category to `system` for all notification types: `emailVerified`, `subscriptionChanged`, `securityAlert`, `featureAnnouncement`, `maintenanceWindow`
7. WHEN rendering a system notification with type `securityAlert`, THE Notifications_System SHALL set priority to `urgent`
8. THE Notifications_View SHALL display system notifications with a blue badge and `Icons.settings` icon
9. WHEN a user taps a `securityAlert` notification, THE Notifications_View SHALL navigate to the Security Settings page
10. WHEN a user taps a `subscriptionChanged` notification, THE Notifications_View SHALL navigate to the Subscription Management page

### Requirement 5: Creator Activity Notifications

**User Story:** As a VHUNAMBI creator, I want to receive notifications when my content generation tasks complete, so that I can review and publish my creations promptly.

#### Acceptance Criteria

1. WHEN a track generation completes, THE Notifications_System SHALL create a notification with type `generationComplete` containing track ID, track title, genre, and duration in metadata
2. WHEN a stem separation task completes, THE Notifications_System SHALL create a notification with type `stemSeparationComplete` containing track ID and stem count in metadata
3. WHEN a Content Studio video export finishes, THE Notifications_System SHALL create a notification with type `videoExportReady` containing video ID, video title, and file size in metadata
4. WHEN a beat license is purchased, THE Notifications_System SHALL create a notification with type `licensePurchase` containing track ID, license type, buyer username, and revenue amount in metadata
5. WHEN a release is published to the marketplace, THE Notifications_System SHALL create a notification with type `releasePublished` containing release ID, release title, and publication timestamp in metadata
6. WHEN a track reaches an analytics milestone, THE Notifications_System SHALL create a notification with type `analyticsMilestone` containing track ID, milestone type, and milestone value in metadata
7. THE Notifications_System SHALL set category to `creatorActivity` for all notification types: `generationComplete`, `stemSeparationComplete`, `videoExportReady`, `licensePurchase`, `releasePublished`, `analyticsMilestone`
8. THE Notifications_View SHALL display creator activity notifications with an orange badge and `Icons.music_note` icon
9. WHEN a user taps a `generationComplete` notification, THE Notifications_View SHALL navigate to the Track Detail View with the track ID from metadata
10. WHEN a user taps a `videoExportReady` notification, THE Notifications_View SHALL navigate to the Content Studio View with the video ID from metadata

### Requirement 6: Algorithmic Discovery Notifications

**User Story:** As a VHUNAMBI user, I want to receive personalized recommendations and discovery notifications, so that I can find new music and trends that match my taste.

#### Acceptance Criteria

1. WHEN a user's track enters trending charts, THE Notifications_System SHALL create a notification with type `trackTrending` containing track ID, chart name, and chart position in metadata
2. WHEN the algorithm identifies tracks similar to user's liked tracks, THE Notifications_System SHALL create a notification with type `similarTracks` containing track IDs and similarity score in metadata
3. WHEN an artist the user follows releases new content, THE Notifications_System SHALL create a notification with type `newReleaseFromFollowed` containing artist ID, track ID, and release date in metadata
4. WHEN the weekly recap is generated, THE Notifications_System SHALL create a notification with type `weeklyRecap` containing listening stats, top genres, and top artists in metadata
5. WHEN the algorithm generates personalized recommendations, THE Notifications_System SHALL create a notification with type `personalizedRecommendation` containing track IDs and recommendation reason in metadata
6. WHEN community highlights are curated, THE Notifications_System SHALL create a notification with type `communityHighlights` containing featured track IDs and curator note in metadata
7. THE Notifications_System SHALL set category to `algorithmic` for all notification types: `trackTrending`, `similarTracks`, `newReleaseFromFollowed`, `weeklyRecap`, `personalizedRecommendation`, `communityHighlights`
8. THE Notifications_View SHALL display algorithmic notifications with a green badge and `Icons.trending_up` icon
9. WHEN rendering an algorithmic notification with type `weeklyRecap`, THE Notifications_View SHALL display a custom card layout with statistics visualization
10. WHEN a user taps a `trackTrending` notification, THE Notifications_View SHALL navigate to the Chart View with the chart name from metadata

### Requirement 7: Notification Priority Levels

**User Story:** As a VHUNAMBI user, I want urgent notifications visually distinguished from normal notifications, so that I can prioritize my attention appropriately.

#### Acceptance Criteria

1. THE Notification_Entity SHALL define a `NotificationPriority` enum with values: `low`, `normal`, `important`, `urgent`
2. THE Notification_Entity SHALL include a `priority` field of type `NotificationPriority` with default value `normal`
3. WHEN rendering a notification with priority `urgent`, THE Notifications_View SHALL display a red accent border and red badge
4. WHEN rendering a notification with priority `important`, THE Notifications_View SHALL display an amber accent border and amber badge
5. WHEN rendering a notification with priority `normal`, THE Notifications_View SHALL display the standard category badge color
6. WHEN rendering a notification with priority `low`, THE Notifications_View SHALL display a muted gray badge
7. THE Notifications_System SHALL set priority to `urgent` for notification types: `securityAlert`, `accountSuspended`
8. THE Notifications_System SHALL set priority to `important` for notification types: `tipReceived`, `licensePurchase`, `subscriptionExpiring`
9. THE Notifications_View SHALL sort notifications by priority descending, then by createdAt descending within each priority group
10. WHEN the Notification_Bell displays unread count, THE Notification_Bell SHALL use red badge color if any unread notification has priority `urgent`

### Requirement 8: Category Filtering

**User Story:** As a VHUNAMBI user, I want to filter notifications by category, so that I can focus on specific notification types without distraction.

#### Acceptance Criteria

1. THE Notifications_View SHALL display a horizontal row of category filter chips below the app bar
2. THE Category_Filter SHALL display four chips labeled: "Social", "System", "Creator", "Discovery"
3. WHEN a category chip is tapped, THE Notifications_View SHALL toggle the visibility of that category's notifications
4. WHEN a category is hidden, THE Category_Filter SHALL display the chip in an inactive state with reduced opacity
5. WHEN a category is visible, THE Category_Filter SHALL display the chip with the category's badge color as background
6. THE Notifications_View SHALL persist category filter state across app restarts using Hive_Storage
7. WHEN all categories are hidden, THE Notifications_View SHALL display an empty state message "All categories hidden. Tap a category above to show notifications."
8. THE Category_Filter SHALL display unread count badge on each chip showing unread notifications in that category
9. WHEN the user long-presses a category chip, THE Notifications_View SHALL show a menu with option "Mark all as read in this category"
10. THE Notifications_View SHALL animate category sections appearing and disappearing with 300ms fade transition

### Requirement 9: Notification Actions

**User Story:** As a VHUNAMBI user, I want context-specific action buttons on notifications, so that I can respond directly without navigating away.

#### Acceptance Criteria

1. THE Notification_Entity SHALL include an `actions` field of type `List<NotificationAction>` containing zero or more action buttons
2. THE Notification_Entity SHALL define a `NotificationAction` class with fields: `actionId`, `label`, `actionType`, `actionData`
3. WHEN rendering a notification with actions, THE Notifications_View SHALL display action buttons in a horizontal row below the notification message
4. WHEN rendering action buttons, THE Notifications_View SHALL ensure each button has minimum touch target of 44x44dp
5. WHEN a notification has type `newFollower`, THE Notification_Entity SHALL include actions: "Follow Back" and "View Profile"
6. WHEN a notification has type `playlistInvite`, THE Notification_Entity SHALL include actions: "Accept" and "Decline"
7. WHEN a notification has type `trackCommented`, THE Notification_Entity SHALL include actions: "Reply" and "View Track"
8. WHEN a user taps an action button, THE Notifications_View SHALL execute the action without dismissing the notification
9. WHEN an action completes successfully, THE Notifications_View SHALL update the notification to show action result (e.g., "Following @username")
10. IF an action execution fails, THEN THE Notifications_View SHALL display a Snackbar with error message and retry button

### Requirement 10: Bulk Actions

**User Story:** As a VHUNAMBI user, I want to mark all notifications as read or delete multiple notifications at once, so that I can efficiently manage large numbers of notifications.

#### Acceptance Criteria

1. THE Notifications_View app bar SHALL display a "Mark all read" action button
2. WHEN the user taps "Mark all read", THE Notifications_System SHALL mark all visible notifications as read
3. IF any category is hidden by Category_Filter, THEN "Mark all read" SHALL only affect visible categories
4. THE Notifications_View SHALL display a selection mode toggle button in the app bar
5. WHEN selection mode is active, THE Notifications_View SHALL display checkboxes on each notification card
6. WHEN selection mode is active, THE Notifications_View app bar SHALL replace standard actions with bulk action buttons: "Delete", "Mark as read", "Cancel"
7. WHEN the user selects notifications and taps "Delete", THE Notifications_System SHALL remove the selected notifications
8. WHEN the user selects notifications and taps "Mark as read", THE Notifications_System SHALL mark the selected notifications as read
9. WHEN the user long-presses a category header, THE Notifications_View SHALL show options: "Mark all as read in category", "Delete all in category", "Turn off this category"
10. WHEN a bulk action completes, THE Notifications_View SHALL display a Snackbar with undo action available for 5 seconds

### Requirement 11: Swipe Gestures

**User Story:** As a VHUNAMBI mobile user, I want to swipe notifications to quickly mark them as read or delete them, so that I can manage notifications with natural mobile gestures.

#### Acceptance Criteria

1. WHEN the user swipes a notification card right by at least 50% of card width, THE Notifications_View SHALL mark the notification as read
2. WHEN the user swipes a notification card left by at least 50% of card width, THE Notifications_View SHALL delete the notification
3. WHILE swiping a notification right, THE Notifications_View SHALL display a blue background with checkmark icon
4. WHILE swiping a notification left, THE Notifications_View SHALL display a red background with delete icon
5. WHEN a notification is dismissed via swipe, THE Notifications_View SHALL animate the card sliding out with 250ms duration
6. WHEN a notification is marked read via swipe, THE Notifications_View SHALL update the unread badge count immediately
7. WHEN a notification is deleted via swipe, THE Notifications_View SHALL display a Snackbar with "Undo" action for 5 seconds
8. IF the user taps "Undo" within 5 seconds, THEN THE Notifications_System SHALL restore the deleted notification
9. THE Notifications_View SHALL disable swipe gestures when selection mode is active
10. WHEN the user swipes a notification less than 50% of card width, THE Notifications_View SHALL animate the card returning to original position with spring physics

### Requirement 12: Search and Advanced Filtering

**User Story:** As a VHUNAMBI user, I want to search notifications by content and filter by date range, so that I can find specific past notifications.

#### Acceptance Criteria

1. WHEN the user taps the search icon in the Notifications_View app bar, THE Notifications_View SHALL display a search bar with text input
2. WHEN the user types in the search bar, THE Notifications_View SHALL filter notifications to show only those with title or message matching the search query
3. THE Notifications_View search SHALL be case-insensitive and support partial word matching
4. THE Notifications_View SHALL display a filter button in the app bar that opens a filter sheet
5. WHEN the filter sheet is opened, THE Notifications_View SHALL display date range selectors: "Today", "Last 7 days", "Last 30 days", "Custom range"
6. WHEN a date range is selected, THE Notifications_View SHALL filter notifications to show only those within the selected date range
7. WHEN the filter sheet is opened, THE Notifications_View SHALL display a "Show read" toggle that includes/excludes read notifications
8. WHEN the filter sheet is opened, THE Notifications_View SHALL display priority checkboxes allowing multi-select of priority levels
9. THE Notifications_View SHALL display active filter badges below the Category_Filter showing applied filters (e.g., "Last 7 days", "Unread only")
10. WHEN the user taps a filter badge, THE Notifications_View SHALL remove that filter and refresh the notification list

### Requirement 13: Long-Press Context Menu

**User Story:** As a VHUNAMBI user, I want advanced options available via long-press on notifications, so that I can mute specific notification types or report spam.

#### Acceptance Criteria

1. WHEN the user long-presses a notification card, THE Notifications_View SHALL display a context menu with options
2. THE context menu SHALL include option "Mute this type" that disables future notifications of the same NotificationType
3. THE context menu SHALL include option "Mute from @username" that disables notifications from the specific actor (for social notifications)
4. THE context menu SHALL include option "Report" that opens a report dialog with reason options
5. THE context menu SHALL include option "Turn off category" that disables all notifications in the notification's category
6. WHEN the user selects "Mute this type", THE Notifications_System SHALL persist the mute preference and stop creating notifications of that type
7. WHEN the user selects "Mute from @username", THE Notifications_System SHALL persist the mute preference and filter out notifications from that actor
8. WHEN the user selects "Report", THE Notifications_View SHALL display a report dialog with reasons: "Spam", "Harassment", "Inappropriate", "Other"
9. WHEN the user submits a report, THE Notifications_System SHALL send the report to the backend and hide the reported notification
10. THE context menu SHALL display a "Delete" option that removes the notification immediately without undo option

### Requirement 14: Accessibility Compliance (WCAG 2.1 AA)

**User Story:** As a VHUNAMBI user with disabilities, I want the notifications system to be fully accessible via screen readers and keyboard, so that I can access all functionality without barriers.

#### Acceptance Criteria

1. THE Notification_Bell SHALL provide semantic label "Notifications, {count} unread" to Screen_Reader when unread count is greater than zero
2. THE Notification_Bell SHALL provide semantic label "Notifications, no unread" to Screen_Reader when unread count is zero
3. THE Notifications_View app bar title SHALL be marked as heading level 1 for Screen_Reader navigation
4. THE Notifications_View category headers SHALL be marked as heading level 2 for Screen_Reader navigation
5. WHEN rendering a notification card, THE Notifications_View SHALL provide semantic structure with title marked as heading level 3 and message as description
6. THE Notifications_View SHALL implement keyboard navigation with Tab key moving focus through all interactive elements in logical order
7. WHEN an element has keyboard focus, THE Notifications_View SHALL display a visible focus indicator with minimum 2px outline and 4.5:1 contrast ratio
8. THE Notifications_View SHALL support Enter key to activate focused buttons and open focused notifications
9. THE Notifications_View SHALL support Escape key to close search bar, filter sheet, or context menus when open
10. THE Notifications_View SHALL implement FocusTraversalGroup to ensure tab order flows: app bar actions → category filters → notification list → footer actions

### Requirement 15: Color Contrast and Visual Indicators

**User Story:** As a VHUNAMBI user with visual impairments, I want notifications to use text labels in addition to color, so that I can distinguish notification states without relying on color alone.

#### Acceptance Criteria

1. WHEN rendering an unread notification, THE Notifications_View SHALL display both a blue dot indicator AND text label "New" with minimum font size 9sp
2. THE Semantic_Label for unread indicator SHALL be "Unread notification"
3. THE Notifications_View SHALL ensure all text has minimum contrast ratio of 4.5:1 against background
4. THE Notifications_View SHALL ensure all interactive elements have minimum contrast ratio of 3:1 against adjacent colors
5. THE Notifications_View category badge colors SHALL meet WCAG AA contrast requirements: purple badge #8B5CF6 on white background, blue badge #3B82F6 on white, orange badge #F97316 on white, green badge #10B981 on white
6. WHEN rendering priority badges, THE Notifications_View SHALL include text labels: "Urgent" for urgent priority, "Important" for important priority
7. THE Notifications_View SHALL display notification timestamps in font size minimum 12sp with sufficient contrast
8. THE Category_Filter active state SHALL use both background color AND a checkmark icon to indicate selection
9. THE Notifications_View selection mode checkboxes SHALL have minimum touch target 44x44dp and visible border in unchecked state
10. THE Notifications_View SHALL support system-wide text scaling up to 200% without clipping or layout overflow

### Requirement 16: Touch Target Compliance

**User Story:** As a VHUNAMBI mobile user, I want all interactive elements to have adequate touch targets, so that I can tap buttons accurately without frustration.

#### Acceptance Criteria

1. THE Notification_Bell SHALL have minimum Touch_Target dimensions of 44x44dp
2. THE Notifications_View "Mark all read" button SHALL have minimum Touch_Target dimensions of 44x44dp
3. THE Notifications_View settings icon button SHALL have minimum Touch_Target dimensions of 44x44dp
4. THE Category_Filter chips SHALL have minimum Touch_Target height of 44dp
5. THE Notifications_View notification card SHALL have minimum Touch_Target height of 60dp
6. THE Notifications_View dismiss icon on notification cards SHALL have minimum Touch_Target of 44x44dp with padding
7. THE Notifications_View action buttons on notification cards SHALL each have minimum Touch_Target of 44x44dp
8. THE Notifications_View selection mode checkboxes SHALL have minimum Touch_Target of 44x44dp
9. WHEN rendering on desktop viewport (width >= 1024dp), THE Notifications_View MAY reduce Touch_Target to minimum 32x32dp for mouse pointer precision
10. THE Notifications_View SHALL ensure touch targets do not overlap and have minimum 8dp spacing between adjacent interactive elements

### Requirement 17: Responsive Touch Constraints

**User Story:** As a VHUNAMBI user on different devices, I want touch targets optimized for my device type, so that interactions feel natural whether I'm using touch or mouse.

#### Acceptance Criteria

1. THE Notifications_View SHALL use ResponsiveUtils.isMobile(context) to determine device interaction mode
2. WHEN ResponsiveUtils.isMobile(context) returns true, THE Notifications_View SHALL apply minimum Touch_Target of 44x44dp to all interactive elements
3. WHEN ResponsiveUtils.isMobile(context) returns false, THE Notifications_View SHALL apply minimum Touch_Target of 32x32dp to all interactive elements
4. WHEN ResponsiveUtils.isMobile(context) returns false, THE Notifications_View SHALL increase notification card density by reducing vertical padding from 12dp to 8dp
5. WHEN ResponsiveUtils.isMobile(context) returns false, THE Notifications_View SHALL display notification actions as icon buttons instead of text buttons to save space
6. THE Notification_Bell SHALL use responsive constraints: 44x44dp on mobile, 36x36dp on desktop
7. THE Category_Filter chips SHALL use responsive constraints: 44dp height on mobile, 36dp height on desktop
8. WHEN viewport width is less than 600dp, THE Notifications_View SHALL display notification cards with single-column layout
9. WHEN viewport width is 600dp or greater, THE Notifications_View MAY display notification cards with two-column grid layout
10. THE Notifications_View SHALL respond to system pointer hover events on desktop by displaying hover state with elevated shadow

### Requirement 18: Persistence and Storage

**User Story:** As a VHUNAMBI user, I want my notifications to persist across app restarts, so that I don't lose notification history when I close the app.

#### Acceptance Criteria

1. THE Notification_Repository SHALL use Hive_Storage to persist notifications locally with box key "vhunambi_notifications"
2. THE Notification_Entity SHALL implement JSON serialization with toJson() and fromJson() methods
3. WHEN the Notifications_System adds a notification, THE Notification_Repository SHALL save it to Hive_Storage immediately
4. WHEN the Notifications_System marks a notification as read, THE Notification_Repository SHALL update the stored notification in Hive_Storage
5. WHEN the Notifications_System removes a notification, THE Notification_Repository SHALL delete it from Hive_Storage
6. WHEN NotificationsNotifier initializes, THE Notification_Repository SHALL load all stored notifications from Hive_Storage and populate initial state
7. THE Notification_Repository SHALL enforce a maximum of 500 notifications stored locally
8. WHEN the notification count exceeds 500, THE Notification_Repository SHALL evict the oldest read notifications first
9. THE Notification_Repository SHALL persist category filter state to Hive_Storage with key "notification_category_filters"
10. THE Notification_Repository SHALL persist notification mute preferences to Hive_Storage with key "notification_mute_preferences"

### Requirement 19: Notification Pagination

**User Story:** As a VHUNAMBI user with hundreds of notifications, I want notifications to load incrementally, so that the app remains performant with large notification history.

#### Acceptance Criteria

1. THE Notifications_View SHALL initially display the 50 most recent notifications
2. WHEN the user scrolls to within 200dp of the list bottom, THE Notifications_View SHALL trigger loading of the next 50 notifications
3. WHEN loading additional notifications, THE Notifications_View SHALL display a loading indicator at the list bottom
4. THE Notifications_View SHALL use ListView.builder with virtual scrolling to render only visible items
5. WHEN all notifications are loaded, THE Notifications_View SHALL display "All caught up!" message at list bottom
6. THE Notifications_View SHALL cache scroll position when navigating away and restore position when returning
7. IF the user has more than 500 total notifications, THEN THE Notifications_View SHALL display "View older notifications" link at list bottom that navigates to archived notifications view
8. THE Notification_Repository SHALL maintain an in-memory cache of the 100 most recent notifications for instant rendering
9. WHEN the Notifications_View requests notifications beyond the cache, THE Notification_Repository SHALL query Hive_Storage asynchronously
10. THE Notifications_View SHALL debounce scroll-triggered pagination by minimum 500ms to prevent excessive queries

### Requirement 20: Date Grouping

**User Story:** As a VHUNAMBI user, I want notifications grouped by date, so that I can easily distinguish recent notifications from older ones.

#### Acceptance Criteria

1. THE Notifications_View SHALL group notifications into date sections: "Today", "Yesterday", "This Week", "This Month", "Older"
2. THE Notifications_View SHALL display date section headers with font style matching AppTypography.titleSmall and color AppColors.textSecondary
3. WHEN rendering date groups, THE Notifications_View SHALL sort notifications within each group by createdAt descending
4. THE Notifications_View date section "Today" SHALL include notifications with createdAt on the current date
5. THE Notifications_View date section "Yesterday" SHALL include notifications with createdAt on the previous date
6. THE Notifications_View date section "This Week" SHALL include notifications with createdAt within the last 7 days excluding today and yesterday
7. THE Notifications_View date section "This Month" SHALL include notifications with createdAt within the current month excluding the last 7 days
8. THE Notifications_View date section "Older" SHALL include all notifications with createdAt before the current month
9. THE Notifications_View SHALL display date section headers as sticky headers that remain visible while scrolling through the section
10. THE Notifications_View SHALL allow collapsing date sections by tapping the section header, persisting collapsed state to Hive_Storage

### Requirement 21: Offline Mode and Sync

**User Story:** As a VHUNAMBI user with unreliable connectivity, I want to access my notification history offline and sync changes when connection is restored, so that I can manage notifications without network dependency.

#### Acceptance Criteria

1. WHEN the device has no network connection, THE Notifications_View SHALL display cached notifications from Hive_Storage
2. WHEN the device has no network connection, THE Notifications_View SHALL display an offline indicator banner at the top
3. WHEN the user marks notifications as read while offline, THE Notification_Repository SHALL queue the mutations locally
4. WHEN the user deletes notifications while offline, THE Notification_Repository SHALL queue the mutations locally
5. WHEN network connection is restored, THE Notification_Repository SHALL sync queued mutations to the backend
6. WHEN network connection is restored, THE Notification_Repository SHALL fetch new notifications created since last sync
7. THE Notification_Repository SHALL use a sync queue with operation types: `markRead`, `delete`, `markAllRead`, `updatePreferences`
8. IF a sync operation fails with 4xx error, THEN THE Notification_Repository SHALL remove it from the queue and log the error
9. IF a sync operation fails with 5xx error or network error, THEN THE Notification_Repository SHALL retry with exponential backoff up to 3 attempts
10. THE Notifications_View SHALL display a sync status indicator showing "Syncing {count} actions" when sync is in progress

### Requirement 22: Real-Time Updates

**User Story:** As a VHUNAMBI user, I want new notifications to appear automatically without refreshing, so that I receive timely alerts while using the app.

#### Acceptance Criteria

1. WHEN the app receives a new notification from the backend, THE Notifications_System SHALL add it to the notification list immediately
2. WHEN a new notification arrives while the Notifications_View is active, THE Notifications_View SHALL animate the new notification sliding in from the top
3. WHEN a new notification arrives while the Notifications_View is not active, THE Notification_Bell SHALL update the unread count badge
4. THE Notifications_System SHALL establish a WebSocket connection to the backend for real-time notification delivery
5. IF the WebSocket connection fails or disconnects, THEN THE Notifications_System SHALL fall back to polling every 30 seconds
6. WHEN the app returns from background, THE Notifications_System SHALL fetch notifications created since the app was backgrounded
7. THE Notifications_System SHALL deduplicate incoming notifications by notification ID to prevent duplicates from polling and WebSocket
8. WHEN a new notification arrives with priority `urgent`, THE Notifications_System SHALL display a heads-up notification banner overlay
9. THE heads-up notification banner SHALL auto-dismiss after 5 seconds or when the user taps it
10. WHEN the user taps the heads-up banner, THE Root_Shell SHALL navigate to the Notifications_View and highlight the notification

### Requirement 23: Loading States

**User Story:** As a VHUNAMBI user, I want clear loading indicators when notifications are being fetched, so that I understand the app is working and not frozen.

#### Acceptance Criteria

1. WHEN the Notifications_View first loads and cache is empty, THE Notifications_View SHALL display a Skeleton_Screen with 6 placeholder notification cards
2. THE Skeleton_Screen notification placeholders SHALL match the layout of real notification cards with animated shimmer effect
3. WHEN pull-to-refresh is triggered, THE Notifications_View SHALL display a loading spinner at the top with 40dp height
4. WHEN pagination loading is triggered, THE Notifications_View SHALL display a loading spinner at the list bottom with 40dp height
5. WHEN category filter state changes, THE Notifications_View SHALL animate the filtered notifications with 200ms fade transition
6. IF initial notification fetch takes longer than 10 seconds, THEN THE Notifications_View SHALL display a timeout message with retry button
7. WHEN the retry button is tapped, THE Notifications_View SHALL clear the timeout message and retry the fetch operation
8. THE Notifications_View SHALL display a loading overlay when executing bulk actions on more than 10 notifications
9. THE loading overlay SHALL display progress text "Deleting {count} notifications..." or "Marking {count} as read..."
10. WHEN an action button on a notification is tapped, THE action button SHALL display a small loading spinner until the action completes

### Requirement 24: Error Handling

**User Story:** As a VHUNAMBI user, I want clear error messages and recovery options when operations fail, so that I can understand what went wrong and try again.

#### Acceptance Criteria

1. IF a notification fetch fails with network error, THEN THE Notifications_View SHALL display a Snackbar "Unable to load notifications. Check your connection." with retry button
2. IF deep-link navigation fails because target content not found, THEN THE Notifications_View SHALL display a Snackbar "{Content type} not found" and remain on Notifications_View
3. IF notification action execution fails, THEN THE Notifications_View SHALL display a Snackbar "{Action} failed. Try again." with retry button
4. IF Hive_Storage read fails, THEN THE Notification_Repository SHALL log the error and return empty notification list
5. IF Hive_Storage write fails, THEN THE Notification_Repository SHALL log the error and display a Snackbar "Unable to save locally. Changes may be lost."
6. IF sync operation fails after 3 retries, THEN THE Notification_Repository SHALL display a Snackbar "Sync failed. Will retry when connection improves."
7. THE Notifications_View SHALL wrap all Navigator.push calls in try-catch blocks to handle deactivated element errors
8. IF a notification contains invalid metadata or missing required fields, THEN THE Notifications_View SHALL render a fallback notification card with error icon and message "Notification data incomplete"
9. IF the backend returns malformed notification JSON, THEN THE Notification_Repository SHALL log the error and skip that notification without crashing
10. THE Notifications_System SHALL implement circuit breaker pattern: after 5 consecutive sync failures, pause sync attempts for 5 minutes before retrying

### Requirement 25: Notification Settings View

**User Story:** As a VHUNAMBI user, I want to configure which notification types I receive, so that I can reduce noise and focus on notifications that matter to me.

#### Acceptance Criteria

1. WHEN the user taps the settings icon in the Notifications_View app bar, THE Root_Shell SHALL navigate to the Notification_Settings_View
2. THE Notification_Settings_View SHALL display a list of all NotificationCategory values with enable/disable toggles
3. WHEN a category toggle is disabled, THE Notifications_System SHALL stop creating new notifications in that category
4. THE Notification_Settings_View SHALL display expandable sections for each category showing individual NotificationType toggles
5. WHEN a type toggle is disabled, THE Notifications_System SHALL stop creating new notifications of that type
6. THE Notification_Settings_View SHALL display a "Quiet Hours" section with start time and end time pickers
7. WHEN Quiet Hours are active, THE Notifications_System SHALL suppress notification creation except for priority `urgent` notifications
8. THE Notification_Settings_View SHALL display a "Muted Users" section listing all users muted via long-press menu with unmute buttons
9. THE Notification_Settings_View SHALL display a "Do Not Disturb" toggle that suppresses all notifications except priority `urgent`
10. THE Notification_Settings_View SHALL persist all preference changes to Hive_Storage immediately

### Requirement 26: Deep-Link Support for All Routes

**User Story:** As a VHUNAMBI user, I want notification taps to navigate to the relevant content, so that I can quickly access tracks, profiles, playlists, and settings from notifications.

#### Acceptance Criteria

1. WHEN a notification has targetTrackId in metadata, THE Notifications_View SHALL navigate to TrackDetailView with the track ID
2. WHEN a notification has targetUserId in metadata, THE Notifications_View SHALL navigate to ProfileView with the user ID
3. WHEN a notification has targetPlaylistId in metadata, THE Notifications_View SHALL navigate to PlaylistDetailView with the playlist ID
4. WHEN a notification has targetCommentId in metadata, THE Notifications_View SHALL navigate to TrackDetailView and scroll to the comment
5. WHEN a notification has targetSettingsRoute in metadata, THE Notifications_View SHALL navigate to the specified settings page
6. WHEN a notification has targetExternalUrl in metadata, THE Notifications_View SHALL open the URL in an in-app browser or external browser
7. THE Notification_Entity metadata SHALL support multiple target fields simultaneously (e.g., targetTrackId and targetCommentId for comment notifications)
8. THE Notifications_View SHALL capture Navigator.of(context) before pop() to prevent deactivated element lookup errors
9. IF navigation to target content fails, THEN THE Notifications_View SHALL display error handling per Requirement 24 criterion 2
10. THE Notifications_View SHALL support custom deep-link handlers registered by other feature modules via a deep-link registry

### Requirement 27: Integration with Root Shell & Safe Area Architecture

**User Story:** As a VHUNAMBI user, I want the notifications view to integrate seamlessly with the shell metrics, so that content clears the persistent audio player and top navigation.

#### Acceptance Criteria

1. THE Root_Shell SHALL strictly preserve its 5 canonical destinations (`0: Home`, `1: Explore`, `2: Create`, `3: Library`, `4: Market`) without inserting a 6th bottom navigation tab
2. THE Notifications_View SHALL be registered as a named route (`/notifications`) and accessible via Navigator.push
3. THE Notifications_View SHALL integrate with VhunambiTopBarMetrics to respect status bar and top navigation heights
4. THE Notifications_View SHALL integrate with Bottom_Dock_Metrics to apply bottom padding equal to persistent player dock height plus safe area insets
5. WHEN the persistent audio player is active (60px mobile / 72px desktop), THE Notifications_View scroll view SHALL ensure the last notification card remains fully visible above the player dock
6. THE Notification_Bell in top bars SHALL display the unread notifications badge when unreadNotificationsCountProvider is greater than zero
7. THE Notification_Bell badge SHALL display the actual unread count if less than or equal to 9, or "9+" if greater than 9
8. WHEN a new notification arrives, THE Notification_Bell badge SHALL update dynamically and emit screen reader announcements
9. THE Notifications_View SHALL support deep-linking via URL scheme: `vhunambi://notifications` to navigate directly to the view
10. THE Notifications_View back button SHALL return the user to their previous view in Root_Shell

### Requirement 28: Coexistence with Quick Popover

**User Story:** As a VHUNAMBI user, I want quick popover previews on desktop/tablet while having access to the full center, so that existing fast workflows and tests remain intact.

#### Acceptance Criteria

1. THE Notification_Bell SHALL continue to open NotificationsPopover on tap, preserving existing test assertions in notification_bell_button_test.dart
2. THE NotificationsPopover SHALL add a prominent "View All Alerts in Center ➔" action button that navigates to Notifications_View
3. THE Notifications_System SHALL maintain the existing notificationsProvider state interface for backward compatibility
4. THE NotificationsNotifier update() adapter method SHALL remain functional during migration period
5. THE Notifications_System SHALL continue to support seededNotifications for preview surfaces
6. THE Notification_Entity SHALL extend the legacy notification model without breaking existing fields: id, title, message, targetTrackId, createdAt, isRead
7. THE existing notification test suites (notification_bell_button_test.dart and notifications_popover_test.dart) SHALL continue to pass without modification
8. THE Notifications_System SHALL provide consistent notification counts across both NotificationsPopover and NotificationsView
9. WHEN a notification is marked read in NotificationsPopover or NotificationsView, both views SHALL reflect the updated state immediately
10. Tapping a notification in either NotificationsPopover or NotificationsView SHALL resolve its deep-link target appropriately

### Requirement 29: Performance Optimization

**User Story:** As a VHUNAMBI user with thousands of notifications, I want the notifications view to scroll smoothly and load quickly, so that performance remains excellent even with extensive notification history.

#### Acceptance Criteria

1. THE Notifications_View SHALL render the initial viewport of notifications within 500ms of view load
2. THE Notifications_View SHALL maintain 60fps scrolling performance with up to 500 notifications loaded
3. THE Notifications_View SHALL use ListView.builder virtual scrolling to render only visible items plus 10-item buffer
4. THE Notification_Repository SHALL index notifications by category and date in Hive_Storage for fast filtered queries
5. WHEN category filters change, THE Notifications_View SHALL update the visible list within 100ms
6. THE Notifications_View SHALL debounce search input by 300ms to prevent excessive filtering on each keystroke
7. THE Notification_Entity toJson() and fromJson() methods SHALL complete serialization of 100 notifications within 50ms
8. THE Notifications_System SHALL batch state updates: when multiple notifications arrive simultaneously, update state once with all notifications
9. THE Notifications_View SHALL use RepaintBoundary widgets around notification cards to isolate repaints
10. THE Notifications_View SHALL dispose of image resources for notification avatars when scrolled out of viewport

### Requirement 30: Animation and Visual Polish

**User Story:** As a VHUNAMBI user, I want smooth animations and visual feedback, so that the notifications experience feels polished and premium.

#### Acceptance Criteria

1. WHEN a new notification arrives, THE Notifications_View SHALL animate it sliding in from the top with 300ms duration and easeOut curve
2. WHEN a notification is dismissed, THE Notifications_View SHALL animate it sliding out with 250ms duration and easeIn curve
3. WHEN the unread badge count changes, THE Notification_Bell badge SHALL animate with a bounce effect using 400ms duration
4. WHEN a notification is marked as read, THE unread dot indicator SHALL animate fading out over 200ms
5. WHEN category filter chips are toggled, THE Notifications_View SHALL animate the chip background color transition over 200ms
6. WHEN date section headers become sticky, THE Notifications_View SHALL animate a subtle elevation shadow appearing over 150ms
7. WHEN the user pulls to refresh, THE Notifications_View SHALL display a custom refresh indicator matching the brand primary color
8. WHEN bulk actions complete, THE Notifications_View SHALL animate affected notification cards with staggered fade-out using 50ms offset between cards
9. WHEN the Notifications_View is first navigated to, THE app bar title SHALL fade in over 300ms
10. WHEN a heads-up notification banner appears, THE banner SHALL slide down from the top with spring physics animation

### Requirement 31: Notification Badge Capping

**User Story:** As a VHUNAMBI user with many unread notifications, I want the badge counter to be capped at a readable number, so that the badge doesn't overflow and distort the layout.

#### Acceptance Criteria

1. WHEN unreadNotificationsCountProvider is 9 or less, THE Notification_Bell badge SHALL display the exact unread count
2. WHEN unreadNotificationsCountProvider is greater than 9, THE Notification_Bell badge SHALL display "9+"
3. THE Notification_Bell badge SHALL use minimum dimensions of 18x18dp to accommodate "9+" text at 9sp font size
4. THE Category_Filter chip badges SHALL use minimum dimensions of 16x16dp with 8sp font size
5. WHEN a Category_Filter chip unread count is greater than 9, THE chip badge SHALL display "9+"
6. THE Notification_Bell badge container SHALL use BorderRadius.circular(10) instead of BoxShape.circle to prevent oval distortion
7. THE Notification_Bell badge text SHALL be center-aligned both horizontally and vertically
8. THE Category_Filter chip badge SHALL be positioned at the top-right corner of the chip with -4dp offset
9. THE Notification_Bell in all top bars SHALL follow the same capping rules: display exact count if ≤9, else "9+"
10. THE Notifications_View category section headers SHALL display exact unread counts without capping (e.g., "Social (23 unread)")

### Requirement 32: Time Display Utilities

**User Story:** As a VHUNAMBI user, I want notification timestamps to display in human-readable relative format, so that I can quickly understand when notifications arrived.

#### Acceptance Criteria

1. THE TimeAgoUtils.format() method SHALL return "Just now" for notifications created less than 60 seconds ago
2. THE TimeAgoUtils.format() method SHALL return "{n} minute(s) ago" for notifications created 1-59 minutes ago
3. THE TimeAgoUtils.format() method SHALL return "{n} hour(s) ago" for notifications created 1-23 hours ago
4. THE TimeAgoUtils.format() method SHALL return "Yesterday" for notifications created 24-47 hours ago
5. THE TimeAgoUtils.format() method SHALL return "{n} days ago" for notifications created 2-6 days ago
6. THE TimeAgoUtils.format() method SHALL return "{n} weeks ago" for notifications created 7-29 days ago
7. THE TimeAgoUtils.format() method SHALL return absolute date in format "MMM dd, yyyy" for notifications created 30 or more days ago
8. THE TimeAgoUtils.format() method SHALL support optional clock parameter for deterministic testing
9. THE TimeAgoUtils.format() method SHALL use singular form for n=1 ("1 minute ago") and plural form for n>1 ("2 minutes ago")
10. THE TimeAgoUtils.format() method SHALL respect user's locale for date formatting when returning absolute dates

### Requirement 33: Empty State Messaging

**User Story:** As a VHUNAMBI user with no notifications, I want helpful empty state messages, so that I understand the notifications feature and what will appear there.

#### Acceptance Criteria

1. WHEN the notification list is completely empty, THE Notifications_View SHALL display an empty state with icon `Icons.notifications_off_outlined` size 64dp
2. THE empty state SHALL display heading "No notifications yet" with AppTypography.titleLarge
3. THE empty state SHALL display description "New followers, track activity, and creator updates will appear here." with AppTypography.bodyMedium
4. WHEN the notification list is empty due to category filters hiding all categories, THE Notifications_View SHALL display message "All categories hidden. Tap a category above to show notifications."
5. WHEN the notification list is empty due to search with no matches, THE Notifications_View SHALL display message "No notifications match '{query}'. Try a different search."
6. WHEN the notification list is empty due to date filter with no matches, THE Notifications_View SHALL display message "No notifications in this date range."
7. WHEN the notification list is empty due to "Show read: off" filter with no unread notifications, THE Notifications_View SHALL display message "You're all caught up! No unread notifications."
8. THE empty state SHALL include a "Clear filters" button when filters are active
9. WHEN the "Clear filters" button is tapped, THE Notifications_View SHALL reset all filters to default state
10. THE empty state icon and text SHALL have color AppColors.textTertiary to indicate inactive state

### Requirement 34: Notification Sound and Haptics

**User Story:** As a VHUNAMBI user, I want notification sounds and haptic feedback, so that I receive multi-sensory alerts when important notifications arrive.

#### Acceptance Criteria

1. WHEN a new notification arrives with priority `urgent`, THE Notifications_System SHALL play a notification sound
2. WHEN a new notification arrives with priority `important`, THE Notifications_System SHALL trigger light haptic feedback
3. WHEN a new notification arrives with priority `normal` or `low`, THE Notifications_System SHALL not play sound or trigger haptics
4. THE Notification_Settings_View SHALL display a "Notification Sounds" toggle to enable/disable notification sounds
5. THE Notification_Settings_View SHALL display a "Haptic Feedback" toggle to enable/disable haptic feedback
6. WHEN notification sounds are disabled in settings, THE Notifications_System SHALL not play sounds regardless of priority
7. WHEN haptic feedback is disabled in settings, THE Notifications_System SHALL not trigger haptics regardless of priority
8. THE Notifications_System SHALL use platform-appropriate notification sound: iOS system sound on iOS, Android notification sound on Android
9. THE Notifications_System SHALL respect system-wide Do Not Disturb mode and suppress sounds when active
10. WHEN the user marks all notifications as read, THE Notifications_View SHALL trigger success haptic feedback

### Requirement 35: Test Preservation

**User Story:** As a developer, I want all existing notification tests to continue passing, so that the modernization doesn't introduce regressions.

#### Acceptance Criteria

1. THE notification_entity_test.dart test suite SHALL pass all 11 existing tests without modification
2. THE notifications_provider_test.dart test suite SHALL pass all 11 existing tests without modification
3. THE notifications_popover_test.dart test suite SHALL pass all 8 existing tests during migration period with feature flag
4. THE notification_bell_button_test.dart test suite SHALL pass all 7 existing tests with navigation change to Notifications_View
5. THE Notification_Entity copyWith() method SHALL maintain existing behavior for legacy fields
6. THE NotificationsNotifier update() adapter method SHALL maintain backward compatibility with Phase 10 StateProvider contract
7. THE seededNotifications test fixture SHALL remain unchanged for existing tests
8. THE NotificationsNotifier addNotification() method SHALL maintain newest-first prepending behavior
9. THE unreadNotificationsCountProvider computed provider SHALL maintain existing count logic
10. THE Notification_Entity equality operator SHALL continue to compare by id and isRead fields

## Performance Requirements

### Requirement 36: Notification List Rendering Performance

**User Story:** As a VHUNAMBI user, I want instant notification list rendering, so that there is no perceived lag when opening the notifications view.

#### Acceptance Criteria

1. THE Notifications_View SHALL complete first paint of cached notifications within 300ms of navigation
2. THE Notifications_View SHALL achieve 60fps frame rate during scrolling with 100 loaded notifications
3. THE Notifications_View SHALL achieve 60fps frame rate during category filter transitions
4. THE Notifications_View ListView.builder SHALL limit simultaneous widget builds to visible viewport plus 10-item buffer
5. THE Notifications_View SHALL measure scroll performance and log warning if frame time exceeds 16ms
6. THE Notification_Repository Hive query for initial 50 notifications SHALL complete within 50ms
7. THE Notifications_View SHALL use AutomaticKeepAliveClientMixin for category filter chips to prevent rebuild on scroll
8. THE Notifications_View SHALL dispose of scroll controller listeners when view is disposed
9. THE Notifications_View SHALL use const constructors for all static widgets to optimize rebuild performance
10. THE Notifications_View SHALL profile performance in release mode and achieve sub-100ms first meaningful paint

## Integration Requirements

### Requirement 37: Social Feed Integration

**User Story:** As a VHUNAMBI creator, I want notifications triggered by social interactions on my published clips, so that I stay engaged with my audience.

#### Acceptance Criteria

1. WHEN a user likes a PublishedClip, THE social_service SHALL call NotificationsNotifier.addNotification() with type `trackLiked`
2. WHEN a user comments on a PublishedClip, THE social_service SHALL call NotificationsNotifier.addNotification() with type `trackCommented`
3. WHEN a user shares a PublishedClip, THE social_service SHALL call NotificationsNotifier.addNotification() with type `trackShared`
4. THE social notification metadata SHALL include socialActivityId for linking back to the specific like/comment/share
5. THE social notification metadata SHALL include actorId and actorUsername for displaying the user who performed the action
6. THE social notification metadata SHALL include clipId and clipTitle for navigation and display
7. WHEN a user taps a social notification, THE Notifications_View SHALL navigate to the PublishedClip detail view
8. THE social_service SHALL deduplicate rapid-fire notifications: if the same user likes 5 tracks within 1 minute, batch into single "liked 5 of your tracks" notification
9. THE social_service SHALL respect user mute preferences: if creator muted the actor, skip notification creation
10. THE social_service SHALL set notification priority to `normal` for likes/shares, `important` for comments on creator's own tracks

### Requirement 38: Wallet and Tipping Integration

**User Story:** As a VHUNAMBI creator, I want notifications when I receive tips, so that I can acknowledge and thank supporters.

#### Acceptance Criteria

1. WHEN a user sends a tip via CreatorWalletDeck, THE wallet_service SHALL call NotificationsNotifier.addNotification() with type `tipReceived`
2. THE tip notification metadata SHALL include tipAmount, tipCurrency, tipperId, tipperUsername, targetTrackId
3. THE tip notification SHALL set priority to `important`
4. THE tip notification title SHALL format as "You received R{amount} from @{username}!"
5. THE tip notification message SHALL include the track title that was tipped
6. WHEN a user taps a tip notification, THE Notifications_View SHALL navigate to the wallet transactions view
7. THE tip notification SHALL include action button "Say Thanks" that opens a reply dialog
8. WHEN "Say Thanks" is tapped, THE Notifications_View SHALL display a dialog with quick reply templates
9. THE wallet_service SHALL aggregate tips: if multiple users tip within 5 minutes, create single notification "You received R{total} from {n} supporters"
10. THE tip notification SHALL display a custom coin icon instead of the default music note icon

### Requirement 39: Profile and Follow Integration

**User Story:** As a VHUNAMBI creator, I want notifications when users follow me, so that I can follow back and build my network.

#### Acceptance Criteria

1. WHEN a user follows a creator, THE profile_service SHALL call NotificationsNotifier.addNotification() with type `newFollower`
2. THE follow notification metadata SHALL include followerId, followerUsername, followerAvatarUrl
3. THE follow notification title SHALL format as "@{username} started following you"
4. THE follow notification SHALL include actions: "Follow Back" and "View Profile"
5. WHEN "Follow Back" is tapped, THE Notifications_View SHALL call profile_service.followUser() and update the notification to show "Following @{username}"
6. WHEN "View Profile" is tapped, THE Notifications_View SHALL navigate to the ProfileView with followerId
7. THE profile_service SHALL batch follow notifications: if 5+ users follow within 10 minutes, create single notification "You have {n} new followers"
8. WHEN a batched follow notification is tapped, THE Notifications_View SHALL navigate to the followers list view
9. THE follow notification SHALL display the follower's avatar as the notification icon
10. THE profile_service SHALL set notification priority to `normal` for follow notifications

### Requirement 40: Track Generation Pipeline Integration

**User Story:** As a VHUNAMBI creator, I want notifications when my track generation completes, so that I can review and publish my creations immediately.

#### Acceptance Criteria

1. WHEN a track generation pipeline completes, THE generation_service SHALL call NotificationEntity.generationReady() factory method
2. THE generation notification SHALL maintain backward compatibility with existing factory method signature
3. THE generation notification metadata SHALL include trackId, trackTitle, genre, duration, waveformUrl
4. THE generation notification SHALL set category to `creatorActivity` and type to `generationComplete`
5. THE generation notification SHALL set priority to `important`
6. WHEN a user taps a generation notification, THE Notifications_View SHALL navigate to TrackDetailView with trackId
7. THE generation notification SHALL mark as read automatically when the user views the track
8. THE generation notification SHALL include action button "Share Now" that opens the share sheet
9. THE generation_service SHALL include generation job metadata in notification: model used, inference time, seed
10. IF generation fails, THEN THE generation_service SHALL create a notification with type `generationFailed` and priority `important`

