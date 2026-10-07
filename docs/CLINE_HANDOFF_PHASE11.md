# Phase 11 Master Handoff: Notifications Drawer & Real-Time Alert System

> **Document Purpose:** Single authoritative handoff guide for any agent (Antigravity / Cline / Cursor) implementing Phase 11. Read this first — it captures exact requirements, architectural invariants, full class designs, and the execution checklist.
>
> **Generated At:** 2026-09-26T15:37:00+02:00  
> **Lead Architect:** Antigravity (Dual-Agent Symbiosis Protocol)  
> **Repository Root:** `c:\Users\Ndugelo\VHUNAMBI\monorepo\`  
> **Client Workspace:** `apps/vhunambi_client/`  
> **Current Health:** `flutter analyze` = **0 issues** | `flutter test` = **321/321 passing (100%)**  
> **Target Test Count:** **≥ 345 tests (≥ 24 new tests)**

---

## 1. Phase 11 Objectives & Scope

Transform the static Phase 2 `NotificationsPopover` into a fully reactive, real-time alert center wired to Riverpod state:

1. **`NotificationsNotifier` & Provider** — Full alert management state notifier in `lib/features/notifications/presentation/providers/notifications_provider.dart` with `addNotification`, `markAsRead`, `markAllAsRead`, `removeNotification`, `clearAll`, and `unreadNotificationsCountProvider`.
2. **Interactive `NotificationsPopover`** — Refactor `lib/features/notifications/presentation/widgets/notifications_popover.dart` to a `ConsumerWidget` displaying live alerts, relative time formatted strings, dynamic unread badge in header, "Mark all read", individual alert dismissal, and deep-link navigation on tap.
3. **Deep-Link Navigation** — Tapping an alert marks it as read, dismisses the popover, and pushes `TrackDetailView(trackId: targetTrackId)`.
4. **Reusable `NotificationBellButton`** — Icon button with stacked unread badge pill/dot that binds to `unreadNotificationsCountProvider` and triggers `NotificationsPopover.show(context)`.
5. **Top Bar Unification** — Wire `NotificationBellButton` into `ExploreTopBar`, `LibraryAppBar`, `MarketplaceTopBar`, and `StudioView`.
6. **Zero-Regression Guarantee** — Maintain 100% compatibility with Phase 10's `generationProgressProvider` notification dispatch and pass all 321 baseline tests.

---

## 2. Specification Documents (Single Source of Truth)

Read and adhere to all 4 documents in `docs/phases/phase_11_notifications_drawer/`:

- [`blueprint.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_11_notifications_drawer/blueprint.md)
- [`requirements.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_11_notifications_drawer/requirements.md)
- [`design.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_11_notifications_drawer/design.md)
- [`tasks.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_11_notifications_drawer/tasks.md)

---

## 3. Codebase Invariants (NEVER BREAK THESE)

1. **Zero Raw Hex Values:** Always use `AppColors.*`, `AppTypography.*`, `AppRadius.*`, `AppSpacing.*`. No raw `Color(0xFF...)` literals.
2. **Riverpod 2.x only:** `StateNotifierProvider`, `Provider`. No `ChangeNotifier`, no `provider` package.
3. **Headless Test Safety:** Popover and Bell button tests must run in `flutter_test` without animation leaks or uncancelled timers.
4. **Phase 10 Compatibility:** Phase 10's `GenerationPipelineNotifier._onGenerationComplete()` updates `notificationsProvider`. `NotificationsNotifier` must provide an `.update()` adapter so existing code compiles and tests pass without modification.
5. **Zero Regressions:** All 321 baseline tests must continue to pass cleanly.

---

## 4. File Map — Everything to Create/Modify

### New files to CREATE

```
lib/features/notifications/presentation/
  providers/notifications_provider.dart                 ← T11.2
  utils/time_ago_utils.dart                             ← T11.1
  widgets/notification_bell_button.dart                 ← T11.4
test/features/notifications/
  presentation/
    utils/time_ago_utils_test.dart                      ← T11.1
    providers/notifications_provider_test.dart          ← T11.2
    widgets/notifications_popover_test.dart             ← T11.3
    widgets/notification_bell_button_test.dart          ← T11.4
```

### Files to MODIFY

```
lib/features/notifications/presentation/widgets/notifications_popover.dart ← T11.3
lib/features/studio/presentation/providers/generation_pipeline_providers.dart ← T11.2 (re-export or use notificationsProvider)
lib/features/explore/presentation/widgets/explore_top_bar.dart ← T11.5
lib/features/library/presentation/widgets/library_app_bar.dart ← T11.5
lib/features/marketplace/presentation/widgets/marketplace_top_bar.dart ← T11.5
lib/features/studio/presentation/views/studio_view.dart ← T11.5
```

---

## 5. Verification Gates

```powershell
cd apps/vhunambi_client

# Per-task gates
flutter test test/features/notifications/presentation/utils/time_ago_utils_test.dart
flutter test test/features/notifications/presentation/providers/notifications_provider_test.dart
flutter test test/features/notifications/presentation/widgets/notifications_popover_test.dart
flutter test test/features/notifications/presentation/widgets/notification_bell_button_test.dart

# Final Phase 11 verification gates (MUST REPORT 0 ISSUES & ALL TESTS PASSED)
dart analyze .
flutter test
```
