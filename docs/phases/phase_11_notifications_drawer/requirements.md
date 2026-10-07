# Phase 11 · Requirements — Notifications Drawer & Real-Time Alert System

> **Phase:** 11  
> **Codename:** `notifications-drawer`  
> **Standard:** RFC 2119 / EARS (Easy Approach to Requirements Syntax)  
> **Status:** 🟡 SPECIFICATION  

---

## 1. Functional Requirements

### 1.1 State Management & Notifications Notifier

* **REQ-NOTIF-01.1** — The system SHALL define `notificationsProvider` as a `StateNotifierProvider<NotificationsNotifier, List<NotificationEntity>>`.
* **REQ-NOTIF-01.2** — `NotificationsNotifier` SHALL support `addNotification(NotificationEntity notification)`, prepending the notification to the head of the list so newest notifications appear first.
* **REQ-NOTIF-01.3** — `NotificationsNotifier` SHALL support `markAsRead(String id)`, mutating `isRead` to `true` for the specified notification without altering the relative ordering of the list.
* **REQ-NOTIF-01.4** — `NotificationsNotifier` SHALL support `markAllAsRead()`, mutating `isRead` to `true` across all existing notifications.
* **REQ-NOTIF-01.5** — `NotificationsNotifier` SHALL support `removeNotification(String id)`, removing the item with matching `id` from the list.
* **REQ-NOTIF-01.6** — `NotificationsNotifier` SHALL support `clearAll()`, resetting the notification list to an empty list `[]`.
* **REQ-NOTIF-01.7** — The system SHALL provide an `unreadNotificationsCountProvider` that computes `notifications.where((n) => !n.isRead).length` synchronously and reactively.

---

### 1.2 Notifications Popover / Drawer Interface

* **REQ-NOTIF-02.1** — The system SHALL provide `NotificationsPopover` as a `ConsumerWidget` or `ConsumerStatefulWidget` displaying the live list of notifications from `notificationsProvider`.
* **REQ-NOTIF-02.2** — `NotificationsPopover` SHALL expose a static `show(BuildContext context)` method displaying the popover in a non-modal dialog anchored near the top-right on desktop or centered/top-inset on mobile.
* **REQ-NOTIF-02.3** — The header SHALL display a bell icon, the title `"Notifications"`, and an unread counter badge indicating the number of unread alerts.
* **REQ-NOTIF-02.4** — When there are 0 unread alerts, the unread badge in the header SHALL be hidden or display nothing.
* **REQ-NOTIF-02.5** — The header SHALL provide a `"Mark all read"` interactive control that invokes `markAllAsRead()`.
* **REQ-NOTIF-02.6** — When `notificationsProvider` contains no notifications, `NotificationsPopover` SHALL render an empty state displaying an icon, `"No notifications yet"`, and guidance text.

---

### 1.3 Notification Item Presentation & Deep Linking

* **REQ-NOTIF-03.1** — Each notification item SHALL display a circular leading icon with `Icons.music_note_rounded`.
* **REQ-NOTIF-03.2** — Each notification item SHALL display the notification title in `AppTypography.bodySmall` with semi-bold weight.
* **REQ-NOTIF-03.3** — Each notification item SHALL display the subtitle message concatenated with a relative time string (e.g. `"9 minutes ago"` or `"2h ago"`).
* **REQ-NOTIF-03.4** — Each unread notification SHALL display a solid orange circle indicator (`AppColors.brandPrimary`, 8x8px) on its trailing edge. Read notifications SHALL NOT display this dot.
* **REQ-NOTIF-03.5** — When the user taps a notification item, the system SHALL:
  1. Call `markAsRead(notification.id)`.
  2. Dismiss the popover via `Navigator.of(context).pop()`.
  3. If `notification.targetTrackId` is non-null, navigate to `TrackDetailView(trackId: notification.targetTrackId!)`.

---

### 1.4 Top App Bar Bell Integration

* **REQ-NOTIF-04.1** — The system SHALL provide a `NotificationBellButton` widget that renders an `IconButton` with `Icons.notifications_none_rounded`.
* **REQ-NOTIF-04.2** — When `unreadNotificationsCountProvider > 0`, `NotificationBellButton` SHALL display a badge indicator (a subtle badge dot or count badge) positioned at the top-right of the bell icon.
* **REQ-NOTIF-04.3** — When `unreadNotificationsCountProvider == 0`, `NotificationBellButton` SHALL render the clean bell icon without any badge.
* **REQ-NOTIF-04.4** — Tapping `NotificationBellButton` SHALL trigger `NotificationsPopover.show(context)`.
* **REQ-NOTIF-04.5** — `NotificationBellButton` SHALL be integrated into:
  - `ExploreTopBar`
  - `LibraryAppBar`
  - `MarketplaceTopBar`
  - `StudioView` header

---

## 2. Non-Functional Requirements & Invariants

* **NFR-NOTIF-01 (Theme Compliance)** — All colors, spacing, and typography MUST be derived strictly from `AppColors`, `AppSpacing`, `AppTypography`, and `AppRadius`. No raw hex codes allowed.
* **NFR-NOTIF-02 (Phase 10 Compatibility)** — Phase 10's `GenerationPipelineNotifier` uses `notificationsProvider` to prepend completion notifications (`_ref.read(notificationsProvider.notifier).update(...)` or `addNotification(...)`). The new provider MUST maintain 100% interoperability with Phase 10 so existing tests continue to pass.
* **NFR-NOTIF-03 (Headless Test Safety)** — All popover and bell button widgets MUST execute cleanly in headless widget tests with zero animation leaks or pending timer failures.
