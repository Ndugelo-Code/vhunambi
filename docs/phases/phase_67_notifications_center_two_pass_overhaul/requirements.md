# Phase 67 Requirements: Notifications Center Two-Pass Overhaul

**Document ID:** `VHUNAMBI-SPEC-P67-REQUIREMENTS-V1`  
**Phase:** `Phase 67` (`phase_67_notifications_center_two_pass_overhaul`)  
**Standard:** EARS (Easy Approach to Requirements Syntax) + RFC-2119 + `STD-UIUX-001`  
**Companion Blueprint:** [`blueprint.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_67_notifications_center_two_pass_overhaul/blueprint.md)

---

## 1. Document Scope & EARS / RFC-2119 Conventions

This document defines the mandatory functional, visual, deep-linking, quota, and persistence requirements for **Phase 67**, split cleanly into **Overhaul Pass 1 (`M67.1`–`M67.2`)** and **Overhaul Pass 2 (`M67.3`–`M67.5`)**.

The keywords **SHALL**, **MUST**, **MUST NOT**, **SHOULD**, and **MAY** are to be interpreted as described in RFC-2119. All requirements follow EARS syntax (`WHEN`, `WHILE`, `IF...THEN`, `WHERE`).

---

## 2. Overhaul Pass 1 Requirements (`M67.1` – `M67.2`)

### 2.1 Mock Purge, Starter DNA Calibration & 3 Beginner Onboarding Notifications (`REQ-P67-MOCK-*` / `REQ-P67-ONB-*`)

- **`REQ-P67-MOCK-01` (Complete Demo Mock Eradication & Legacy Hive Disk Scrubber)**:
  THE SYSTEM SHALL remove `phase40SeededNotifications`, `seededNotifications`, `_autoSeedPending`, `shouldAutoSeedDemoAlerts`, and `seedDemoAlerts()` from `apps/vhunambi_client/lib/features/notifications/presentation/providers/notifications_provider.dart`, `apps/vhunambi_client/lib/main.dart`, and `apps/vhunambi_client/lib/features/notifications/presentation/views/notifications_view.dart`. Furthermore, `NotificationRepository` and `NotificationsNotifier` SHALL automatically filter out and delete any persisted legacy demo keys matching `notif_p40_*` or `notif_seed_*` from the `notifications_v1` Hive box on synchronous read and async hydration so upgraded physical devices immediately boot with a clean inbox.
- **`REQ-P67-MOCK-02` (Zero Empty-Inbox Respawn)**:
  WHEN a user deletes all notifications or calls `clearAll()`, THE SYSTEM SHALL display `NotificationEmptyState` (`Key('notification_empty_title')`, `"Nothing here yet"`) and SHALL NOT re-seed any demo or onboarding notifications for that creator.
- **`REQ-P67-MOCK-03` (Suppression of Unverified Local Top-Up Alerts)**:
  WHEN a user taps a coin top-up pack in `SubscriptionUpgradeModal`, THE SYSTEM SHALL initiate the PayFast checkout notice without fabricating an immediate local `"Coins Credited! (R450)"` notification prior to payment settlement verification.
- **`REQ-P67-ONB-01` (Dynamic `6%–10%` Starter Creator DNA Calibration)**:
  WHEN `OnboardingView._finishOnboarding()` seeds `CreatorDnaNotifier.seedFromOnboarding(...)`, THE SYSTEM SHALL compute starter `completeness` dynamically in $[0.14, 0.26]$ based on selected genres, languages, and moods so that `CreatorDnaProfile.strengthPercent` evaluates within the **$6\%–10\%$** range for a brand-new user with `totalBehaviorEvents == 0`.
- **`REQ-P67-ONB-02` (Idempotent 3 Beginner Onboarding Notifications & Reactive Account-Switch Seeding)**:
  WHEN a creator completes onboarding (`OnboardingView._finishOnboarding`), registers a new account (`AuthSessionNotifier.signUp`), switches accounts (`currentCreatorIdProvider` listener inside `RootShell.build`), or mounts `RootShell` for the first time with no recorded onboarding seed flag (`onboarding_notifs_seeded_v1_<creatorId>`), `OnboardingNotificationsService` SHALL idempotently persist exactly three notifications into `notificationsProvider` without requiring an app restart:
  1. **`notif_onboard_welcome_<creatorId>`**:
     - `title`: `'Welcome to Vhunambi, @<username>'`
     - `message`: `'Your sovereign African music studio is live. Compose original tracks, split stems, and publish kinetic reels.'`
     - `category`: `NotificationCategory.system`, `subtype`: `'welcome'`, `targetRoute`: `'/studio'`, `ctaLabel`: `'Open Studio Cockpit'`.
  2. **`notif_onboard_dna_<creatorId>`**:
     - `title`: `'Creator DNA Calibrated at <X>%'` (where `<X>` is `dnaProfile.strengthPercent` $\in [6, 10]$)
     - `message`: `'Your foundational sound identity is recorded. Complete vocal calibration and add reference tracks to unlock deeper personalization.'`
     - `category`: `NotificationCategory.system`, `subtype`: `'dna_calibration'`, `targetRoute`: `'/creator-dna'`, `ctaLabel`: `'Calibrate Creator DNA'`, `metadata`: `{'dnaPercent': X, 'recordedTraits': [...], 'uncalibratedTraits': [...]}`.
  3. **`notif_onboard_quota_<creatorId>`**:
     - `title`: `'10 Free Monthly Song Generations Ready'`
     - `message`: `'Your Free Creator account includes 10 AI song generations per month. Each full track uses 1 generation credit from your monthly allowance.'`
     - `category`: `NotificationCategory.system`, `subtype`: `'monthly_quota'`, `targetRoute`: `'/wallet'`, `ctaLabel`: `'View Balance & Usage'`, `metadata`: `{'freeSongsTotal': 10, 'freeSongsRemaining': 10, 'planTier': 'free'}`.
- **`REQ-P67-ONB-03` (Unread Count Partition Invariant)**:
  WHILE notifications are loaded, filtered, hydrated from Hive, or mutated, `unreadNotificationsCountProvider` SHALL equal the exact sum of `unreadCountByCategoryProvider.values`, and `NotificationEntity.==` / `hashCode` SHALL include `id`, `isRead`, `category`, `subtype`, `title`, `message`, and `targetRoute`.

### 2.2 Refined LODA Visual Hierarchy, Semantic Accents & Keyboard/Rail Ergonomics (`REQ-P67-UI-*`)

- **`REQ-P67-UI-01` (5-Color Semantic Category & Subtype Palette)**:
  `NotificationCategoryStyle` SHALL resolve semantic accent colors and pill labels using `(category, subtype)`:
  - `system` (`'welcome'`, `'monthly_quota'`, `'credits'`): `AppColors.coinGold` (`#F59E0B`)
  - `dna_calibration` / `dna_milestone`: `AppColors.success` (`#10B981`)
  - `creatorActivity`: `AppColors.brandPrimary` (`#F97316`)
  - `social`: `AppColors.accentElectric` (`#8B5CF6`)
  - `algorithmic` (`Discovery`): `AppColors.badgeCyan` (`#22D3EE`)
- **`REQ-P67-UI-02` (Refined Directional Left-Edge Glow Card)**:
  `NotificationItemTile` SHALL render each card with:
  1. An obsidian base surface (`AppColors.darkSurfaceCanvas` / `#121215` when read; `AppColors.darkSurfaceElevated` / `#17171C` when unread) with a `1px` border (`accent.withValues(alpha: 0.28)` when unread; `AppColors.borderSubtle` when read).
  2. A `3px` vertical left-edge accent bar (`Key('notification_left_glow_bar_${notification.id}')`) paired with a horizontal `LinearGradient` wash from `accent.withValues(alpha: isRead ? 0.05 : 0.13)` on the left to `Colors.transparent` at `48%` width.
  3. An inline timestamp row (`<timeAgo>`) with a `7x7dp` semantic category-colored unread dot (`Key('notification_unread_dot')`) immediately adjacent to the timestamp.
  4. A compact in-card semantic category pill badge (`Key('notification_category_pill_${notification.id}')`, e.g., `'System • Welcome'`, `'Creator DNA'`, `'Free Tier Quota'`, `'Studio Render'`, `'Social'`, `'Discovery'`) below the message body.
  5. A trailing `PhosphorIcon(PhosphorIconsRegular.caretRight, size: 16)` (`Key('notification_trailing_chevron_${notification.id}')`) indicating tap interactivity.
- **`REQ-P67-UI-03` (`STD-UIUX-001` 100% Phosphor Icon Compliance)**:
  THE SYSTEM SHALL replace all 14 stock Material `Icons.*` occurrences across `lib/features/notifications/` with `PhosphorIcon` glyphs from `AppIcons` / `PhosphorIconsRegular` / `PhosphorIconsFill`. Zero `Icons.*` or raw Unicode emojis SHALL remain in `lib/features/notifications/`.
- **`REQ-P67-UI-04` (Automatic Keyboard Unfocus & Unclipped Category Rail)**:
  WHEN the user taps any category chip in `NotificationCategoryRail`, taps any `NotificationItemTile`, or drags the `NotificationsView` scroll view (`ScrollViewKeyboardDismissBehavior.onDrag`), THE SYSTEM SHALL invoke `FocusManager.instance.primaryFocus?.unfocus()` to dismiss the soft keyboard immediately. `NotificationCategoryRail` SHALL apply a right-edge `ShaderMask` fade and scroll the active chip into view via `Scrollable.ensureVisible`.

---

## 3. Overhaul Pass 2 Requirements (`M67.3` – `M67.5`)

### 3.1 Universal Detail Bottom Sheet, Deep-Link Router & Track Resolution (`REQ-P67-ROUTE-*`)

- **`REQ-P67-ROUTE-01` (Universal `NotificationDetailBottomSheet`)**:
  WHEN a user taps any notification card whose `subtype` is informational/milestone (`'welcome'`, `'dna_calibration'`, `'monthly_quota'`, `'credits'`, `'reel_render'`, `'social_share'`) OR whose target entity cannot be resolved directly, THE SYSTEM SHALL open `NotificationDetailBottomSheet` (`Key('notification_detail_bottom_sheet')`) displaying:
  - Semantic category icon, category pill badge (`Key('detail_sheet_category_pill')`), and formatted timestamp.
  - Full notification title (`Key('detail_sheet_title')`) and message (`Key('detail_sheet_message')`).
  - Contextual breakdown card (`Key('detail_sheet_breakdown_card')`) rendering DNA trait calibration progress, Free Tier `10 / 10` song allowance meter, or track/social metadata.
  - Primary CTA button (`Key('detail_sheet_primary_cta')`, minimum $44 \times 48\text{dp}$) that executes the deep-link route.
- **`REQ-P67-ROUTE-02` (Typed `NotificationDeepLinkRouter`)**:
  WHEN `NotificationDeepLinkRouter.navigate(context, ref, notification)` executes, THE SYSTEM SHALL route deterministically:
  - `'/studio'` $\to$ Pop to root shell and set `ref.read(appNavigationTabProvider.notifier).state = 2`.
  - `'/creator-dna'` $\to$ Open `CreatorDnaHelixLabSheet.show(context)`.
  - `'/wallet'` $\to$ Open `SubscriptionUpgradeModal.show(context)`.
  - `'/track/:id'` $\to$ Push `TrackDetailView(trackId: id)`.
  - `'/reel/:clipId'` $\to$ Open `KineticReelsModal.show(context, clips: clips, initialClipId: clipId)`.
  - `'/creator/:id'` $\to$ Push `ArtistProfileView(creatorId: id)` (or `OwnerProfileView` if self).
- **`REQ-P67-ROUTE-03` (Eradication of `"Unknown Melody (@fifi)"` Track Lookup Bug)**:
  WHEN `TrackDetailNotifier` resolves a `trackId` in `track_providers.dart`, THE SYSTEM SHALL search `libraryTracksProvider` and `exploreTracksProvider` before checking `seededTrackDetails`, mapping any matching `LibraryTrack` or `Track` into a complete `TrackDetailEntity` with its real title, creator name/handle, genre, language, duration, and lyrics.

### 3.2 Backend Persistence, 10-Song Monthly Quota & Live Event Producers (`REQ-P67-API-*` / `REQ-P67-EVT-*`)

- **`REQ-P67-API-01` (Dual-Engine `notifications` & `creator_quotas` Tables)**:
  THE SYSTEM SHALL define `notifications` and `creator_quotas` (`free_monthly_songs_limit INTEGER DEFAULT 10`, `free_monthly_songs_used INTEGER DEFAULT 0`, `cycle_reset_at TEXT`) in both `apps/vhunambi_api/src/db/vhunambi_db.ts` (SQLite) and `supabase/migrations/20261116000001_phase67_notifications_and_quotas.sql` (Postgres), bridged via `edge_persistence_bridge.ts` for Cloudflare `workerd` isolate safety.
- **`REQ-P67-API-02` (`/api/notifications` & `/api/wallet/allowance` Endpoints)**:
  `apps/vhunambi_api` SHALL expose:
  - `GET /api/notifications` (returns tenant-scoped notifications + unread counts + quota summary)
  - `POST /api/notifications` (idempotent upsert of client/onboarding/event notifications)
  - `PATCH /api/notifications/:id/read` & `POST /api/notifications/mark-all-read`
  - `DELETE /api/notifications/:id`
  - `GET /api/wallet/allowance` (returns `{ planTier, freeMonthlySongsLimit: 10, freeMonthlySongsUsed, freeMonthlySongsRemaining, cycleResetAt }`)
- **`REQ-P67-EVT-01` (Unified Home & Global `NotificationBellButton`)**:
  `HomeDashboardView` (`home_dashboard_view.dart#L310-L333`) SHALL replace its raw `PhosphorIcon(AppIcons.bell)` with `NotificationBellButton(key: const Key('home_notifications_btn'))`, and `NotificationBellButton` SHALL use `PhosphorIcon(AppIcons.bell)` with a pill-shaped (`BorderRadius.circular(10)`) unread badge.
- **`REQ-P67-EVT-02` (Live Social, Studio & Quota Event Producers)**:
  THE SYSTEM SHALL emit real persisted `NotificationEntity` records (and sync them to `/api/notifications` when online) when:
  1. A user loves a reel (`KineticReelsModal._recordLove` / `SocialFeedNotifier.recordLove`) $\to$ `category: social`, `subtype: 'reel_love'`, `targetRoute: '/reel/<clipId>'`.
  2. A user reposts a post (`RepostKineticPostSheet._submitRepost`) $\to$ `category: social`, `subtype: 'repost'`, `targetRoute: '/creator/<creatorId>'`.
  3. A user posts a reel comment (`ReelsCommentsNotifier.addComment`) $\to$ `category: social`, `subtype: 'comment'`, `targetRoute: '/reel/<clipId>'`.
  4. A user sends a cultural gift (`CreatorWalletNotifier.sendGift`) $\to$ `category: social`, `subtype: 'gift'`, `targetRoute: '/reel/<clipId>'`.
  5. A song generation completes (`GenerationPipelineNotifier._onGenerationComplete` & `POST /v1/generations`) $\to$ `category: creatorActivity`, `subtype: 'studio_render'`, `targetRoute: '/track/<trackId>'`, plus quota decrement and low-quota alert when remaining free songs reach `3`, `1`, or `0`.

---

## 4. Non-Functional Requirements (`REQ-P67-NFR-*`)

- **`REQ-P67-NFR-01` (60 FPS Mobile Rendering & Zero Unbounded `pumpAndSettle`)**:
  All card gradients and animations SHALL render within $\le 16.6\text{ms}$ on Android ARM64 without `BackdropFilter` per-card overhead, and all widget tests SHALL use bounded `tester.pump(const Duration(milliseconds: 300))` steps (`--timeout=60s`).
- **`REQ-P67-NFR-02` ($44 \times 44\text{dp}$ Touch Target Ergonomics)**:
  All interactive chips, bell buttons, clear buttons, and detail sheet CTAs SHALL maintain a minimum $44 \times 44\text{dp}$ hit target.
- **`REQ-P67-NFR-03` (Multi-Tenant Isolation)**:
  `SovereignHiveAccountSanitizer.purgeTenantPrivateBoxes` SHALL continue clearing `notifications_v1`, and `OnboardingNotificationsService` SHALL scope its seeded marker by `creatorId`.

---

## 5. Requirement-to-Test Traceability Matrix

| Requirement ID | Overhaul Pass | Target Implementation File(s) | Verification Test File |
| :--- | :---: | :--- | :--- |
| `REQ-P67-MOCK-01..03` | Pass 1 (`M67.1`) | `notifications_provider.dart`, `main.dart`, `notifications_view.dart`, `subscription_upgrade_modal.dart` | `test/features/notifications/phase67_pass1_notifications_overhaul_test.dart` |
| `REQ-P67-ONB-01..03` | Pass 1 (`M67.1`) | `onboarding_notifications_service.dart`, `onboarding_view.dart`, `creator_dna_profile.dart` | `test/features/notifications/phase67_pass1_notifications_overhaul_test.dart` |
| `REQ-P67-UI-01..04` | Pass 1 (`M67.2`) | `notification_category_style.dart`, `notification_item_tile.dart`, `notification_category_rail.dart`, `notification_search_bar.dart` | `test/features/notifications/phase67_pass1_notifications_overhaul_test.dart` |
| `REQ-P67-ROUTE-01..03` | Pass 2 (`M67.3`) | `notification_detail_bottom_sheet.dart`, `notification_deep_link_router.dart`, `track_providers.dart` | `test/features/notifications/phase67_pass2_routing_and_events_test.dart` |
| `REQ-P67-API-01..02` | Pass 2 (`M67.4`) | `vhunambi_db.ts`, `edge_persistence_bridge.ts`, `notification_routes.ts`, `wallet_routes.ts`, `generation_routes.ts` | `apps/vhunambi_api/src/phase67_notifications_quota.test.ts` |
| `REQ-P67-EVT-01..02` | Pass 2 (`M67.5`) | `home_dashboard_view.dart`, `notification_bell_button.dart`, `kinetic_reels_modal.dart`, `repost_kinetic_post_sheet.dart`, `reels_comments_provider.dart`, `creator_wallet_provider.dart` | `test/features/notifications/phase67_pass2_routing_and_events_test.dart` |
