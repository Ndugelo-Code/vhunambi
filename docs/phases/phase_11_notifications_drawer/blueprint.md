# Phase 11 · Blueprint — Notifications Drawer & Real-Time In-App Alert System

> **Phase:** 11  
> **Codename:** `notifications-drawer`  
> **Status:** 🟡 SPECIFICATION  
> **Target App:** `apps/vhunambi_client`  
> **Flutter / Dart:** 3.x+ / 3.x+  
> **State Management:** Riverpod 2.x (`StateNotifierProvider`, `Provider`)  
> **Foundation Blueprints:**  
> — `docs/foundation_blueprints/07_AUDIO_TRANSPORT_AND_PIPELINE_MODALS_SPEC.md` (§4 — In-App Notifications Drawer / Popover, §5 — Riverpod State Models)  
> — `docs/foundation_blueprints/00_SYSTEM_DESIGN_TOKENS.md` (Design tokens, surfaces, typography, radii)

---

## 1. Purpose & Scope

Phase 11 implements the interactive Notifications Drawer & Real-Time Alert System across Vhunambi. While Phase 10 established the `NotificationEntity` model and automatic completion dispatch in `generationProgressProvider`, Phase 11 brings the user-facing alert surface to life:

1. **State-Driven Notification Drawer (`NotificationsPopover`)** — Replaces the static Phase 2 placeholder with a live, Riverpod-connected drawer/popover displaying in-app alerts, relative timestamps, read/unread states, and empty states.
2. **Interactive Alert Management** — Dedicated `NotificationsNotifier` supporting `markAsRead`, `markAllAsRead`, `removeNotification`, and `clearAll`.
3. **Deep-Link Navigation** — Tapping a notification automatically marks it as read, closes the popover, and deep-links directly to the completed track detail view (`TrackDetailView(trackId: targetTrackId)`).
4. **Real-Time Notification Bell & Unread Counter** — A reusable `NotificationBellButton` widget showing a dynamic unread counter badge (`[ N ]`), integrated across all top app bars (`ExploreTopBar`, `LibraryAppBar`, `MarketplaceTopBar`, and `StudioView`).
5. **Zero-Regression Guarantee** — Preserves Phase 10's generation completion dispatch contract without breaking existing tests.

---

## 2. System Context & Data Flow

```
┌────────────────────────────────────────────────────────────────────────┐
│                      Flutter Client (Riverpod)                         │
│                                                                        │
│   GenerationPipelineNotifier                                           │
│       │ (on synthesis complete)                                        │
│       ▼                                                                │
│   notificationsProvider (StateNotifierProvider) ◄────────────────┐    │
│       │                                                          │    │
│       ├──► unreadNotificationsCountProvider                      │    │
│       │        │                                                 │    │
│       │        ▼                                                 │    │
│       │    NotificationBellButton (all top bars)                 │    │
│       │        │ tap                                             │    │
│       │        ▼                                                 │    │
│       └──► NotificationsPopover (dialog / popover)               │    │
│                │                                                 │    │
│                ├── "Mark all read" ──► markAllAsRead() ──────────┤    │
│                ├── "Clear all"    ──► clearAll() ───────────────┤    │
│                └── tap item ────────► markAsRead(id) ────────────┘    │
│                         │                                             │
│                         ▼ (if targetTrackId != null)                  │
│                    TrackDetailView(trackId: id)                       │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Component Architecture & Visual Layout

### 3.1 Popover Geometry & Layout Wireframe

```
┌────────────────────────────────────────────────────────┐
│ 🔔 Notifications  [ 2 ]                    ✓ Mark all read │ <-- Header
├────────────────────────────────────────────────────────┤
│ ┌────────────────────────────────────────────────────┐ │
│ │ ┌───┐  Your song "rave" is ready!                ● │ │ <-- Unread Item
│ │ │ 🎵│  Gqom • 3:29 • 2 minutes ago                 │ │
│ │ └───┘                                              │ │
│ └────────────────────────────────────────────────────┘ │
│ ┌────────────────────────────────────────────────────┐ │
│ │ ┌───┐  Your song "ZaYN" is ready!                  │ │ <-- Read Item
│ │ │ 🎵│  Amapiano • 4:12 • 1 hour ago                │ │
│ │ └───┘                                              │ │
│ └────────────────────────────────────────────────────┘ │
├────────────────────────────────────────────────────────┤
│ Clear all                                        Close │ <-- Footer
└────────────────────────────────────────────────────────┘
```

### 3.2 Visual & Design Token Bindings

* **Popover Container:**
  * Width: `360px` (or `MediaQuery.of(context).size.width - 32` on mobile).
  * Background: `AppColors.surfaceModal` (`#121216`).
  * Border: `1px solid AppColors.borderSubtle` (`#2D2D38`).
  * Border Radius: `AppRadius.cardBorder` (`16px`).
  * Shadow: `BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 8))`.
* **Header:**
  * Bell icon: `Icons.notifications_outlined`, `20px`, color `AppColors.brandPrimary`.
  * Title: `"Notifications"` (`AppTypography.titleMedium`).
  * Counter Badge: Solid circle with `AppColors.brandPrimary` background, black text, font size 11, bold. Hidden when `unreadCount == 0`.
  * Action: `"Mark all read"` (`AppTypography.caption`, color `AppColors.textSecondary`).
* **Notification Card Item:**
  * Background: `AppColors.surfaceElevated` (`#141418`).
  * Leading Icon: `36x36px` circle with `AppColors.surfaceSecondary` fill, `Icons.music_note_rounded` in `AppColors.brandPrimary`.
  * Title: `AppTypography.bodySmall`, semi-bold, `AppColors.textPrimary`.
  * Subtitle / Message: `AppTypography.caption`, `AppColors.textSecondary`, displaying genre, duration, and formatted relative timestamp.
  * Trailing Unread Dot: `8x8px` circle with `AppColors.brandPrimary` fill when `!notification.isRead`.
* **Empty State:**
  * Rendered when `notifications.isEmpty`.
  * Icon: `Icons.notifications_off_outlined`, `44px`, color `AppColors.textTertiary`.
  * Title: `"No notifications yet"`, `AppTypography.bodyLarge`, bold.
  * Message: `"Your generation alerts and music updates will appear here."`, centered, `AppTypography.caption`.
* **Footer:**
  * Left: `"Clear all"` text button (`AppColors.error` or `AppColors.textSecondary`).
  * Right: `"Close"` button (`AppColors.textPrimary`).

---

## 4. Top Bar Integration Points

The unread badge and notification trigger must be uniformly accessible from every primary screen:

1. **`ExploreTopBar`** (`lib/features/explore/presentation/widgets/explore_top_bar.dart`):
   - Replace standalone `_HeaderIconButton` with `NotificationBellButton`.
2. **`LibraryAppBar`** (`lib/features/library/presentation/widgets/library_app_bar.dart`):
   - Desktop and Mobile headers wired to `NotificationBellButton`.
3. **`MarketplaceTopBar`** (`lib/features/marketplace/presentation/widgets/marketplace_top_bar.dart`):
   - Header action wired to `NotificationBellButton`.
4. **`StudioView`** (`lib/features/studio/presentation/views/studio_view.dart`):
   - App bar action wired to `NotificationBellButton`.

---

## 5. Relative Time Formatting

Timestamps on notifications format dynamically:
- `< 1 minute`: `"Just now"`
- `< 60 minutes`: `"${minutes}m ago"`
- `< 24 hours`: `"${hours}h ago"`
- `< 7 days`: `"${days}d ago"`
- `≥ 7 days`: Formatted date (e.g., `"${month} ${day}"`)
