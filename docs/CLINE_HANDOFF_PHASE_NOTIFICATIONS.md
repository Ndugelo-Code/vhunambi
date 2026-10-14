# System M7 Master Handoff: Notifications Modernization & Accessible Center

> **Document Purpose:** Single authoritative handoff guide for any agent (Antigravity / Cline / Cursor) implementing System M7.
>
> **Generated At:** October 2026  
> **Lead Architect:** Antigravity (Dual-Agent Symbiosis Protocol)  
> **Repository Root:** `c:\Users\Ndugelo\VHUNAMBI\monorepo\`  
> **Client Workspace:** `apps/vhunambi_client/`  
> **Baseline Health:** `dart analyze lib test` = **0 issues** | `flutter test` = **813/813 passing (100%)**  
> **Target Test Count:** **≥ 837 tests (≥ 24 new tests, 0 regressions)**

---

## 1. System Objectives & Scope

Transform the Phase 11 notification drawer popup into a full-scale, accessible, category-driven notifications center with offline Hive caching and 44×44px touch ergonomics:

1. **Category Rail & Classification** — 4 distinct categories (`Social`, `System`, `Creator Activity`, `Algorithmic`) mapped to design tokens (`AppColors.accentElectric`, `AppColors.accentGold`, `AppColors.brandPrimary`, `AppColors.accentSuccess`).
2. **Offline Persistence (Untyped Hive Box + In-Memory Fallback)** — Untyped Hive box mapped to `AppConstants.notificationsBoxKey` with hand-rolled JSON serialization (`toJson()` / `fromJson()`). **ZERO `build_runner` or `@HiveType` codegen**.
3. **Dedicated View (`NotificationsView`)** — Full-screen responsive notifications center with search, filter tabs, bulk mark-as-read, swipe-to-dismiss, and safe-area dock integration (`VhunambiTopBarMetrics` / `VhunambiBottomDockMetrics`).
4. **Preserve Canonical 5-Tab RootShell** — Do **NOT** add a 6th bottom nav tab. RootShell stays at 5 canonical destinations (`0: Home`, `1: Explore`, `2: Create`, `3: Library`, `4: Market`).
5. **Dual-Surface Coexistence** — Preserve `NotificationsPopover` in its entirety. Tapping `NotificationBellButton` triggers the popover; clicking `"View All Alerts ➔"` navigates to `NotificationsView`. All existing tests in `notifications_popover_test.dart` and `notification_bell_button_test.dart` MUST continue to pass cleanly.

---

## 2. Specification Documents (Single Source of Truth)

Read and adhere strictly to all 4 documents in `docs/phases/notifications-modernization/`:

- [blueprint.md](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/notifications-modernization/blueprint.md)
- [requirements.md](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/notifications-modernization/requirements.md)
- [design.md](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/notifications-modernization/design.md)
- [tasks.md](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/notifications-modernization/tasks.md)

---

## 3. Codebase Invariants (NEVER BREAK THESE)

1. **Zero Code Generation:** Never run `build_runner` or introduce `@HiveType` / `@HiveField`. Use standard Map-based JSON serialization.
2. **Zero Raw Hex Colors:** Always resolve colors through `AppColors.*`.
3. **Ergonomic Touch Targets:** Every filter chip, action button, and dismiss target must satisfy `BoxConstraints(minHeight: 44, minWidth: 44)`.
4. **Headless Test Safety:** In-memory fallback allows all widget tests to pass in CI without Hive path initialization errors.
5. **Zero Regressions:** All 813 baseline tests must stay green.

---

## 4. Key Target Files

### Files to CREATE
```
apps/vhunambi_client/lib/features/notifications/
  data/
    repositories/notification_repository.dart
  presentation/
    views/notifications_view.dart
    widgets/notification_category_rail.dart
    widgets/notification_item_tile.dart
    widgets/notification_search_bar.dart
    widgets/notification_empty_state.dart
apps/vhunambi_client/test/features/notifications/
  data/repositories/notification_repository_test.dart
  presentation/views/notifications_view_test.dart
  presentation/widgets/notification_category_rail_test.dart
  presentation/widgets/notification_item_tile_test.dart
```

### Files to MODIFY
```
apps/vhunambi_client/lib/core/constants/app_constants.dart (register notificationsBoxKey)
apps/vhunambi_client/lib/features/notifications/domain/entities/notification_entity.dart (extend fields, add toJson/fromJson)
apps/vhunambi_client/lib/features/notifications/presentation/providers/notifications_provider.dart (wire repository)
apps/vhunambi_client/lib/features/notifications/presentation/widgets/notifications_popover.dart (add "View All Alerts" CTA)
```

---

## 5. Verification Commands

```powershell
cd apps/vhunambi_client
dart analyze lib test
flutter test test/features/notifications/
flutter test
```
