# Dual-Agent Master Handoff — Phase 3: Notifications Modernization & Accessible Center (System M8)

> **Document Purpose:** Single authoritative handoff guide for Cline (or Cursor/Antigravity) implementing Phase 3.
>
> **Generated At:** October 2026  
> **Lead Architect:** Antigravity (Dual-Agent Symbiosis Protocol)  
> **Repository Root:** `c:\Users\Ndugelo\VHUNAMBI\monorepo\`  
> **Client Workspace:** `apps/vhunambi_client/`  
> **Baseline Health:** `flutter analyze` = **0 issues** | `flutter test` = **911/911 passing (100%)**  
> **Target Test Count:** **≥ 935 tests (≥ 24 new tests, 0 regressions)**  
> **Governing Spec Suite:** `docs/phases/notifications-modernization/` ([blueprint.md](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/notifications-modernization/blueprint.md), [requirements.md](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/notifications-modernization/requirements.md), [design.md](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/notifications-modernization/design.md), [tasks.md](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/notifications-modernization/tasks.md))  
> **Roadmap Context:** [SYNTHESIS_AND_SEQUENCE.md](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/SYNTHESIS_AND_SEQUENCE.md)

---

## 1. Executive Summary & Architecture

Phase 3 transforms VHUNAMBI's notification subsystem from a simple 360px popup into an **Accessible, Category-Driven Notifications Center** with offline Hive persistence, touch ergonomics, swipe gestures, and intelligent algorithmic prioritization.

### Key Deliverables:
1. **Category Rail & Classification** — 4 distinct categories:
   - `Social` (`AppColors.accentElectric`): Tips, comments, followers, collaborations.
   - `System` (`AppColors.accentGold`): Credits, terms, app updates, security.
   - `Creator Activity` (`AppColors.brandPrimary`): Generation ready, stem separation, export complete.
   - `Algorithmic` (`AppColors.accentSuccess`): Recommended tracks, trending sound packs matching Creator DNA.
2. **Offline Persistence (Untyped Hive Box + In-Memory Fallback)** — Untyped Hive box mapped to `AppConstants.notificationsBoxKey` (`'notifications_v1'`) with hand-rolled JSON serialization (`toJson()` / `fromJson()`). **ZERO `build_runner` or `@HiveType` codegen**.
3. **Dedicated View (`NotificationsView`)** — Full-screen responsive notifications center with search bar, category filter tabs, bulk mark-as-read, swipe-to-dismiss, and safe-area dock integration (`VhunambiTopBarMetrics` / `VhunambiBottomDockMetrics`).
4. **Creator DNA Intelligence Integration** — Uses Phase 2's `creatorDnaProvider` to sort `NotificationCategory.algorithmic` alerts based on the user's top genres and sound signature.
5. **Dual-Surface Coexistence** — Preserves `NotificationsPopover` in its entirety. Tapping `NotificationBellButton` continues to show the quick popover; clicking `"View All Alerts ➔"` navigates to `NotificationsView`. All existing tests in `notifications_popover_test.dart` and `notification_bell_button_test.dart` MUST continue to pass cleanly.
6. **Kinetic Fluidity & Tactile Haptic Choreography ("The Sensory Station")** — Platform-safe `NotificationsHaptics`, elastic swipe-to-dismiss with 80px snap feedback, 3-cycle ringing wobble on `NotificationBellButton`, sliding category pill with bouncing unread count badges, and smooth fade-out of glowing unread dots on bulk mark read.

---

## 2. Foundations Already Implemented & Verified by Chief Architect

Before starting Phase 3, the Chief Architect completed and locked in Phase 1 & Phase 2:
1. **Creator DNA Engine Live (`lib/features/creator_dna/`)**:
   - `creatorDnaProvider` (`CreatorDnaProfile`) is live and tested.
   - When filtering or sorting the `NotificationCategory.algorithmic` tab, Cline can read `ref.watch(creatorDnaProvider)` to prioritize alerts whose genre matches `profile.topGenres` or `profile.primarySoundSignature`.
2. **Constants Registered (`lib/core/constants/app_constants.dart`)**:
   - `AppConstants.notificationsBoxKey` (`'notifications_v1'`) is already declared.
3. **Safe Storage Pattern**:
   To prevent unhandled VM errors in headless tests, storage access must strictly follow:
   ```dart
   if (!kIsWeb && Hive.isBoxOpen(AppConstants.notificationsBoxKey)) {
     _box = Hive.box(AppConstants.notificationsBoxKey);
   }
   ```
   If `_box == null`, seamlessly fall back to an in-memory `List<NotificationEntity>` with zero crashes.
4. **Current Test Baseline: 911 Tests Passing**:
   Every test must continue passing. The suite must expand to ≥ 935 tests.

---

## 3. Codebase Invariants (NEVER BREAK THESE)

1. **Canonical 5-Tab RootShell**: Do **NOT** add a 6th bottom navigation tab. `RootShell` in `lib/main.dart` strictly maintains its 5 canonical destinations (`0: Home`, `1: Explore`, `2: Create`, `3: Library`, `4: Market`). `NotificationsView` is pushed onto the navigator stack via `Navigator.of(context).push(...)`.
2. **Zero Code Generation:** Never run `build_runner` or introduce `@HiveType` / `@HiveField`. Use clean Map-based JSON serialization.
3. **Zero Raw Hex Colors:** Always resolve colors through `AppColors.*` (`surfaceCanvas`, `surfaceElevated`, `brandPrimary`, `accentElectric`, `accentGold`, `accentSuccess`, etc.).
4. **Platform-Safe Haptics:** Centralize all haptics in `NotificationsHaptics`. Check `!kIsWeb` and catch all exceptions silently. Respect `MediaQuery.of(context).disableAnimations`.
5. **Ergonomic 44×44px Touch Targets:** Every filter chip, action button, search clear icon, and dismiss target must satisfy `BoxConstraints(minHeight: 44, minWidth: 44)` or `EdgeInsets` giving 44×44px hit bounds per WCAG 2.1 AA.
6. **Headless Test Safety:** In-memory fallback allows all widget and unit tests to pass in CI without Hive path initialization errors.
7. **Zero Regressions:** All 911 baseline tests must stay green.

---

## 4. Key Target Files & Implementation Guide for Cline

### Step 1: Extend Domain Model (`NotificationEntity`)
**File:** `apps/vhunambi_client/lib/features/notifications/domain/models/notification_entity.dart`
- Extend `NotificationEntity` with:
  - `category`: `NotificationCategory` enum (`social`, `system`, `creatorActivity`, `algorithmic`). Default to `creatorActivity`.
  - `priority`: `NotificationPriority` enum (`low`, `normal`, `high`, `urgent`). Default to `normal`.
  - `metadata`: `Map<String, dynamic>` (optional, e.g. `{'genre': 'Amapiano', 'deepLinkRoute': '/track/123'}`).
  - `actions`: `List<NotificationAction>` (optional, e.g. label + route).
  - Add `toJson()` and `factory NotificationEntity.fromJson(Map<String, dynamic> json)`.
- **CRITICAL**: Preserve all existing constructors, factory `NotificationEntity.generationReady`, `targetTrackId`, `id`, `title`, `message`, `createdAt`, `isRead` so existing code does not break!

### Step 2: Create Data Repository (`NotificationRepository`)
**File:** `apps/vhunambi_client/lib/features/notifications/data/repositories/notification_repository.dart` (new)
- Methods:
  - `Future<List<NotificationEntity>> getNotifications()`
  - `Future<void> saveNotification(NotificationEntity notification)`
  - `Future<void> saveNotifications(List<NotificationEntity> notifications)`
  - `Future<void> deleteNotification(String id)`
  - `Future<void> clearAll()`
- Use untyped `Box? _box` initialized via `Hive.isBoxOpen(AppConstants.notificationsBoxKey)`. Fall back to in-memory list if not open.

### Step 3: Enhance State Management (`NotificationsNotifier`)
**File:** `apps/vhunambi_client/lib/features/notifications/presentation/providers/notifications_provider.dart`
- Inject or load from `NotificationRepository`.
- Support:
  - `selectedCategoryProvider`: `StateProvider<NotificationCategory?>((ref) => null)` (null = All).
  - `searchQueryProvider`: `StateProvider<String>((ref) => '')`.
  - `filteredNotificationsProvider`: Filters notifications by active category, search query, and sorts `algorithmic` notifications using `creatorDnaProvider` top genres.
  - `addNotification`, `markAsRead`, `markAllAsRead`, `removeNotification`, `clearAll`.

### Step 4: UI Components
1. **`lib/features/notifications/presentation/widgets/notification_category_rail.dart`** (new)
   - Horizontal scrolling chip row for `All`, `Social (🟣)`, `Activity (⚡)`, `System (🟡)`, `Discovery (🟢)`.
   - Kinetic sliding indicator pill (`Curves.easeOutCubic`, 240ms) and bouncing count badge (`scale: 1.0` -> `1.25` -> `1.0`).
   - Each chip has `minHeight: 44`, unread badge count, and token styling.
2. **`lib/features/notifications/presentation/widgets/notification_item_tile.dart`** (new)
   - Swipeable card using `Dismissible(key: Key('notif_tile_${notification.id}'))`.
   - 80px drag threshold triggers `NotificationsHaptics.dismissSnap()` with scaling trash icon (`0.8` -> `1.2` with `Curves.easeOutBack`).
   - Category icon badge, timestamp, unread dot with animated 300ms fade-out, action buttons (min 44px height), tap-to-open deep link.
3. **`lib/features/notifications/presentation/widgets/notification_search_bar.dart`** (new)
   - Text input with search icon, animated container focus border glow (`AppColors.brandPrimary.withOpacity(0.35)`), clear button (`minWidth: 44, minHeight: 44`), and token styling.
4. **`lib/features/notifications/presentation/widgets/notification_empty_state.dart`** (new)
   - Clean illustration/icon and message when no alerts match the active filter.
5. **`lib/features/notifications/presentation/views/notifications_view.dart`** (new)
   - Scaffold with top app bar ("Notifications"), "Mark all read" button with `NotificationsHaptics.markAllReadPulse()`, Category rail, Search bar, and `ListView.builder` of `NotificationItemTile`s.
   - Respects `VhunambiTopBarMetrics` and `VhunambiBottomDockMetrics`.

### Step 5: Dual-Surface Coexistence CTA in `NotificationsPopover`
**File:** `apps/vhunambi_client/lib/features/notifications/presentation/widgets/notifications_popover.dart`
- In the popover footer, add a prominent button:
  - Text: `"View All Alerts in Center ➔"`
  - Key: `const Key('notifications_view_all_btn')`
  - On tap: Closes popover and navigates to `NotificationsView`:
    ```dart
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsView()),
    );
    ```

### Step 6: Kinetic Fluidity & Haptic Choreography ("The Sensory Station")
1. **`lib/features/notifications/presentation/utils/notifications_haptics.dart`** (new):
   - Platform-safe methods: `bellRing()`, `dismissSnap()`, `categorySwitch()`, `markAllReadPulse()`, `itemTap()`.
2. **`lib/features/notifications/presentation/widgets/notification_bell_button.dart`** (modify):
   - Enhance with `WobblingNotificationBell` (3-cycle dampened sine rotation `±14°` over 320ms on tap or high-priority arrival).

### Step 7: Tests to Write
1. `test/features/notifications/data/repositories/notification_repository_test.dart` (5+ tests)
   - Test JSON serialization round-trip.
   - Test in-memory fallback when Hive is closed.
   - Test save, delete, clear.
2. `test/features/notifications/presentation/widgets/notification_category_rail_test.dart` (4+ tests)
   - Test chip taps update selected category.
   - Test 44×44px hit bounds on chips.
3. `test/features/notifications/presentation/widgets/notification_item_tile_test.dart` (5+ tests)
   - Test render of title, message, category badge.
   - Test swipe-to-dismiss triggers `removeNotification` and animates.
4. `test/features/notifications/presentation/views/notifications_view_test.dart` (6+ tests)
   - Test search filtering.
   - Test "Mark all read" action.
   - Test empty state display.
5. `test/features/notifications/presentation/utils/notifications_haptics_test.dart` (3+ tests)
   - Test calling all haptic methods executes cleanly without throwing in headless test runner.
6. Test integration with `creatorDnaProvider`:
   - Test algorithmic category prioritizing DNA top genres.

---

## 5. Verification Commands

```powershell
cd apps/vhunambi_client
flutter analyze
flutter test test/features/notifications/
flutter test
```

- `flutter analyze` MUST return: **No issues found!**
- `flutter test` MUST report: **≥ 935 tests passed (0 failures, 0 regressions)**.

