# Phase 11 · Tasks — Notifications Drawer & Real-Time Alert System

> **Phase:** 11  
> **Codename:** `notifications-drawer`  
> **Baseline Gate:** `dart analyze .` = 0 issues · `flutter test` = **321/321 passing**  
> **Target:** ≥ 345 passing tests (≥ 24 new tests, zero regressions)  

---

## Task Breakdown

### T11.1 — Pure Relative Time Utility
- [ ] Create `lib/features/notifications/presentation/utils/time_ago_utils.dart`
- [ ] Implement `TimeAgoUtils.format(DateTime dateTime, {DateTime? clock})`
- [ ] Create `test/features/notifications/presentation/utils/time_ago_utils_test.dart` (≥ 6 tests covering seconds, minutes, hours, days, future edge cases)
- [ ] **Gate:** `flutter test test/features/notifications/presentation/utils/time_ago_utils_test.dart`

---

### T11.2 — Notifications Riverpod Provider & State Notifier
- [ ] Create `lib/features/notifications/presentation/providers/notifications_provider.dart`
- [ ] Implement `NotificationsNotifier`:
  - `addNotification(NotificationEntity)` (prepends newest first)
  - `update(...)` (backward-compatible adapter for Phase 10)
  - `markAsRead(String id)`
  - `markAllAsRead()`
  - `removeNotification(String id)`
  - `clearAll()`
- [ ] Implement `notificationsProvider` and `unreadNotificationsCountProvider`
- [ ] Update `lib/features/studio/presentation/providers/generation_pipeline_providers.dart` to export or utilize `notifications_provider.dart`
- [ ] Create `test/features/notifications/presentation/providers/notifications_provider_test.dart` (≥ 8 tests)
- [ ] **Gate:** `flutter test test/features/notifications/presentation/providers/notifications_provider_test.dart`

---

### T11.3 — Notifications Popover Widget Refactor
- [ ] Refactor `lib/features/notifications/presentation/widgets/notifications_popover.dart` to `ConsumerWidget`
- [ ] Bind list to `ref.watch(notificationsProvider)`
- [ ] Bind unread counter badge in header to `ref.watch(unreadNotificationsCountProvider)`
- [ ] Wire `"Mark all read"` to `ref.read(notificationsProvider.notifier).markAllAsRead()`
- [ ] Wire `"Clear all"` to `ref.read(notificationsProvider.notifier).clearAll()`
- [ ] Wire item tap to:
  1. `markAsRead(notification.id)`
  2. `Navigator.of(context).pop()`
  3. `Navigator.of(context).push(MaterialPageRoute(builder: (_) => TrackDetailView(trackId: targetTrackId)))` if `targetTrackId != null`
- [ ] Render `_EmptyNotificationsState` when list is empty
- [ ] Create `test/features/notifications/presentation/widgets/notifications_popover_test.dart` (≥ 7 tests)
- [ ] **Gate:** `flutter test test/features/notifications/presentation/widgets/notifications_popover_test.dart`

---

### T11.4 — Reusable Notification Bell Button Widget
- [ ] Create `lib/features/notifications/presentation/widgets/notification_bell_button.dart`
- [ ] Bind unread counter to `ref.watch(unreadNotificationsCountProvider)`
- [ ] Render badge dot or counter when `unreadCount > 0`
- [ ] Render clean bell icon when `unreadCount == 0`
- [ ] Wire tap to `NotificationsPopover.show(context)`
- [ ] Create `test/features/notifications/presentation/widgets/notification_bell_button_test.dart` (≥ 4 tests)
- [ ] **Gate:** `flutter test test/features/notifications/presentation/widgets/notification_bell_button_test.dart`

---

### T11.5 — Top App Bar Integrations
- [ ] Update `lib/features/explore/presentation/widgets/explore_top_bar.dart` to use `NotificationBellButton`
- [ ] Update `lib/features/library/presentation/widgets/library_app_bar.dart` to use `NotificationBellButton`
- [ ] Update `lib/features/marketplace/presentation/widgets/marketplace_top_bar.dart` to use `NotificationBellButton`
- [ ] Update `lib/features/studio/presentation/views/studio_view.dart` to use `NotificationBellButton`
- [ ] Ensure existing top bar widget tests pass without regressions

---

### T11.6 — Phase 11 Final Gate & Documentation
- [ ] Run `dart analyze .` (0 issues)
- [ ] Run `flutter test` (all tests passing, expected ≥ 345)
- [ ] Create `docs/phases/phase_11_notifications_drawer/walkthrough.md`
- [ ] Update `docs/AGENT_HANDOFF_BIBLE.md` with Phase 11 completion and metrics
- [ ] Update `README.md` status table
