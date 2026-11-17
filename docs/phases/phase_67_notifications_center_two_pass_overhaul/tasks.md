# Phase 67 Tasks & Execution Roadmap: Notifications Center Two-Pass Overhaul

**Document ID:** `VHUNAMBI-SPEC-P67-TASKS-V1`  
**Phase:** `Phase 67` (`phase_67_notifications_center_two_pass_overhaul`)  
**Execution Skill:** [`/vhunambi-executioner`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/.agents/skills/vhunambi-executioner/SKILL.md)  
**Companion Docs:** [`blueprint.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_67_notifications_center_two_pass_overhaul/blueprint.md) · [`requirements.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_67_notifications_center_two_pass_overhaul/requirements.md) · [`design.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_67_notifications_center_two_pass_overhaul/design.md)

---

## 1. Master Milestone Roadmap & Two-Pass Execution Gate

```
┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
│                        PHASE 67 TWO-PASS EXECUTION ROADMAP (M67.1 -> M67.5)                      │
├──────────────────────────────────────────────────────────────────────────────────────────────────┤
│ OVERHAUL PASS 1: UI/UX GLOW DESIGN, MOCK PURGE & 3 BEGINNER ONBOARDING NOTIFICATIONS             │
│  ├── [M67.1] Mock Purge, Dynamic 6%–10% Starter DNA & OnboardingNotificationsService             │
│  └── [M67.2] Refined LODA Directional Glow Cards, 5 Semantic Accents, Phosphor & Keyboard Fix    │
│  >>> HARDWARE GATE 1: Verify Pass 1 Visually on Physical Device Before Proceeding to Pass 2 <<<  │
├──────────────────────────────────────────────────────────────────────────────────────────────────┤
│ OVERHAUL PASS 2: DETAIL SHEET, DEEP-LINK ROUTER, 10-SONG QUOTA & LIVE EVENT WIRING               │
│  ├── [M67.3] NotificationDetailBottomSheet, NotificationDeepLinkRouter & Track Lookup Fix        │
│  ├── [M67.4] Backend `notifications` + `creator_quotas` (10 Songs/Mo) & `/api/notifications`     │
│  └── [M67.5] Live Social/Studio Event Producers, Unified Home Bell Badge & Full E2E Tests        │
└──────────────────────────────────────────────────────────────────────────────────────────────────┘
```

| Milestone | Overhaul Pass | Target Package(s) | Core Deliverable | Verification Gate |
| :--- | :---: | :--- | :--- | :--- |
| **`M67.1`** | **Pass 1** | `apps/vhunambi_client` | Purge `phase40SeededNotifications` & `seedDemoAlerts`; dynamic `6%–10%` starter DNA; `OnboardingNotificationsService` (3 beginner alerts). | `dart analyze` + Pass 1 unit tests |
| **`M67.2`** | **Pass 1** | `apps/vhunambi_client` | 3px left bar + 13% directional wash cards, 5 semantic colors, category pill + `›` chevron, 100% Phosphor icons, keyboard unfocus & rail fade. | `flutter test test/features/notifications/ --timeout=60s` |
| **`M67.3`** | **Pass 2** | `apps/vhunambi_client` | `NotificationDetailBottomSheet`, `NotificationDeepLinkRouter`, and `TrackDetailNotifier` Library/Explore resolution (fixes `@fifi` bug). | Widget routing & detail sheet tests |
| **`M67.4`** | **Pass 2** | `apps/vhunambi_api`, `supabase/` | SQLite + Postgres `notifications` & `creator_quotas` (`10 free songs/month`) tables + `/api/notifications` & `/api/wallet/allowance`. | `npm run build` + node API tests |
| **`M67.5`** | **Pass 2** | `apps/vhunambi_client` | Unified `NotificationBellButton` on `HomeDashboardView` + live event producers (Reel Love, Repost, Comment, Gift, Studio Render, Quota). | Full client + API test suite + APK deploy |

---

## 2. OVERHAUL PASS 1 (`M67.1` – `M67.2`): UI/UX Design Overhaul, Mock Purge & 3 Beginner Notifications

### Milestone `M67.1` — Complete Mock Purge, Dynamic `6%–10%` Starter DNA & 3 Idempotent Onboarding Notifications (`REQ-P67-MOCK-01..03`, `REQ-P67-ONB-01..03`)

- [x] **Task 67.1.1 — Extend `NotificationEntity` with `subtype`, `targetRoute`, `targetEntityId`, and `ctaLabel`**:
  - **Target File:** `apps/vhunambi_client/lib/features/notifications/domain/models/notification_entity.dart`
  - **Action:** Add `subtype`, `targetRoute`, `targetEntityId`, `ctaLabel`, `effectiveRoute`, and `opensDetailSheetFirst` as specified in `design.md` §1.1. Update `toJson()`, `fromJson()`, `copyWith()`, and `==`/`hashCode`.
- [x] **Task 67.1.2 — Purge Hardcoded Demo Mocks, Add Legacy Hive Disk Scrubber & Remove Auto-Seed Hooks**:
  - **Target Files:**
    - `apps/vhunambi_client/lib/features/notifications/data/repositories/notification_repository.dart`
    - `apps/vhunambi_client/lib/features/notifications/presentation/providers/notifications_provider.dart`
    - `apps/vhunambi_client/lib/main.dart`
    - `apps/vhunambi_client/lib/features/notifications/presentation/views/notifications_view.dart`
    - `apps/vhunambi_client/lib/features/home/presentation/widgets/subscription_upgrade_modal.dart`
  - **Action:**
    1. In `notification_repository.dart`, add `NotificationRepository.isLegacyDemoMockId(String id)` (`id.startsWith('notif_p40_') || id.startsWith('notif_seed_')`) and `scrubLegacyDemoMocks()` (`design.md` §1.3) so any pre-existing `notif_p40_*` or `notif_seed_*` keys persisted on physical devices in `notifications_v1` are filtered out on synchronous read and deleted on async hydration.
    2. Remove `phase40SeededNotifications`, `seededNotifications`, `_autoSeedPending`, `shouldAutoSeedDemoAlerts`, and `seedDemoAlerts()` from `notifications_provider.dart`, and watch `currentCreatorIdProvider` inside `notificationsProvider`.
    3. Derive `unreadNotificationsCountProvider` directly from `unreadCountByCategoryProvider.values` (`design.md` §1.3).
    4. Remove `seedDemoAlerts()` from `NotificationsView.build` (`notifications_view.dart#L31-L41`).
    5. Remove the unverified local `"Coins Credited!"` emission in `SubscriptionUpgradeModal._buildTopUpPack` (`subscription_upgrade_modal.dart#L261-L270`).
- [x] **Task 67.1.3 — Dynamic `6%–10%` Starter Creator DNA Completeness, `OnboardingNotificationsService` & Reactive `RootShell` Account-Switch Listener**:
  - **Target Files:**
    - `apps/vhunambi_client/lib/features/notifications/domain/services/onboarding_notifications_service.dart` *(New)*
    - `apps/vhunambi_client/lib/features/onboarding/presentation/views/onboarding_view.dart`
    - `apps/vhunambi_client/lib/main.dart`
  - **Action:**
    1. Implement `OnboardingNotificationsService` (`design.md` §1.2) generating `notif_onboard_welcome_<cid>`, `notif_onboard_dna_<cid>` (`6%–10%`), and `notif_onboard_quota_<cid>` (`10 Free Monthly Song Generations Ready`).
    2. In `OnboardingView._finishOnboarding()` (`onboarding_view.dart#L85`), replace `completeness: 1.0` with `OnboardingNotificationsService.computeStarterCompleteness(...)` and invoke `OnboardingNotificationsService.ensureSeededForActiveCreator(ref, force: true)`.
    3. In `_RootShellState.initState()` (`main.dart#L148-L150`), replace `seedDemoAlerts()` with `OnboardingNotificationsService.ensureSeededForActiveCreator(ref)`.
    4. In `_RootShellState.build()` (`main.dart`), add `ref.listen<String>(currentCreatorIdProvider, ...)` (`design.md` §1.3) so registering a new account or switching accounts while `RootShell` is mounted immediately seeds the active creator's 3 beginner onboarding notifications without requiring an app restart.

### Milestone `M67.2` — Refined LODA Directional Glow Cards, 5 Semantic Colors, `STD-UIUX-001` Phosphor Migration & Keyboard/Rail Polish (`REQ-P67-UI-01..04`)

- [x] **Task 67.2.1 — 5-Color Semantic `NotificationCategoryStyle` & Phosphor Icons**:
  - **Target File:** `apps/vhunambi_client/lib/features/notifications/presentation/utils/notification_category_style.dart`
  - **Action:** Implement `entityColor(notification)` (`coinGold` Amber Gold for System/Quota, `success` Emerald Teal for Creator DNA, `brandPrimary` Ember Orange for Studio/Activity, `accentElectric` Violet for Social, `badgeCyan` Cyan for Discovery), `entityIcon(notification)`, and `pillLabel(notification)` using 100% Phosphor icons (`design.md` §2.1).
- [x] **Task 67.2.2 — Upgrade `NotificationItemTile` with Directional Left-Edge Glow, Category Pill & `›` Chevron**:
  - **Target File:** `apps/vhunambi_client/lib/features/notifications/presentation/widgets/notification_item_tile.dart`
  - **Action:** Implement `_NotificationCardBody` (`design.md` §2.2) with 3px left glow bar (`Key('notification_left_glow_bar_${notification.id}')`), 13%/5% horizontal gradient wash, 28% unread tinted border, category-colored `_UnreadDot` next to timestamp, `_CategoryPillBadge` (`Key('notification_category_pill_${notification.id}')`), trailing `PhosphorIconsRegular.caretRight` (`Key('notification_trailing_chevron_${notification.id}')`), Phosphor trash icon, and `FocusManager.instance.primaryFocus?.unfocus()` on tap.
- [x] **Task 67.2.3 — Keyboard Auto-Unfocus, Rail `ShaderMask` & Remaining Phosphor Migrations**:
  - **Target Files:**
    - `apps/vhunambi_client/lib/features/notifications/presentation/widgets/notification_category_rail.dart`
    - `apps/vhunambi_client/lib/features/notifications/presentation/widgets/notification_search_bar.dart`
    - `apps/vhunambi_client/lib/features/notifications/presentation/widgets/notification_empty_state.dart`
    - `apps/vhunambi_client/lib/features/notifications/presentation/widgets/notification_bell_button.dart`
    - `apps/vhunambi_client/lib/features/notifications/presentation/views/notifications_view.dart`
    - `apps/vhunambi_client/lib/features/notifications/presentation/widgets/notifications_popover.dart`
  - **Action:**
    1. Upgrade `NotificationCategoryRail` with `ShaderMask` right-edge fade, `Scrollable.ensureVisible`, `FocusManager.instance.primaryFocus?.unfocus()`, and `PhosphorIconsRegular.tray` (`design.md` §2.3).
    2. Add `keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag` to `ListView.builder` in `notifications_view.dart` and replace `Icons.done_all_rounded` with `PhosphorIconsRegular.checks`.
    3. Replace all remaining `Icons.*` in `notification_search_bar.dart`, `notification_empty_state.dart`, `notification_bell_button.dart` (plus `BorderRadius.circular(10)` badge), and `notifications_popover.dart`.
- [x] **Task 67.2.4 — Pass 1 Verification Suite (`phase67_pass1_notifications_overhaul_test.dart`)**:
  - **Target Files:**
    - `apps/vhunambi_client/test/features/notifications/phase67_pass1_notifications_overhaul_test.dart` *(New)*
    - Update `test/features/explore/phase40_notifications_lexicon_cosign_and_topup_test.dart` and `test/features/notifications/presentation/widgets/notification_item_tile_test.dart` for Phosphor icons and onboarding seed.

---

## 3. OVERHAUL PASS 2 (`M67.3` – `M67.5`): Detail Sheet, Deep-Link Router, 10-Song Quota & Live Event Wiring

### Milestone `M67.3` — Universal `NotificationDetailBottomSheet`, `NotificationDeepLinkRouter` & Track Lookup Fix (`REQ-P67-ROUTE-01..03`)

- [x] **Task 67.3.1 — Implement `NotificationDetailBottomSheet`**:
  - **Target File:** `apps/vhunambi_client/lib/features/notifications/presentation/widgets/notification_detail_bottom_sheet.dart` *(New)*
  - **Action:** Implement `NotificationDetailBottomSheet` (`design.md` §3.1) with DNA calibration progress breakdown, Free Tier `10 / 10` song allowance meter, and primary CTA button.
- [x] **Task 67.3.2 — Implement `NotificationDeepLinkRouter` & Wire `NotificationsView.openNotification`**:
  - **Target Files:**
    - `apps/vhunambi_client/lib/features/notifications/presentation/utils/notification_deep_link_router.dart` *(New)*
    - `apps/vhunambi_client/lib/features/notifications/presentation/views/notifications_view.dart`
  - **Action:** Route `/studio`, `/creator-dna`, `/wallet`, `/track/:id`, `/reel/:clipId`, and `/creator/:id` (`design.md` §3.2) and delegate `openNotification` in `notifications_view.dart` to `NotificationDeepLinkRouter.handleCardTap(context, ref, notification)`.
- [x] **Task 67.3.3 — Fix `"Unknown Melody (@fifi)"` Track Lookup in `track_providers.dart`**:
  - **Target File:** `apps/vhunambi_client/lib/features/track/presentation/providers/track_providers.dart`
  - **Action:** Update `TrackDetailNotifier` (`#L33`, `#L202-L219`) to resolve tracks from `libraryTracksProvider` and `exploreTracksProvider` before `seededTrackDetails` (`design.md` §3.3).

### Milestone `M67.4` — Backend `notifications` + `creator_quotas` (`10 Free Songs/Month`) & `/api/notifications` (`REQ-P67-API-01..02`)

- [x] **Task 67.4.1 — Add `notifications` & `creator_quotas` Tables to SQLite, Postgres & Edge Bridge**:
  - **Target Files:**
    - `supabase/migrations/20261116000001_phase67_notifications_and_quotas.sql` *(New)*
    - `apps/vhunambi_api/src/db/vhunambi_db.ts`
    - `apps/vhunambi_api/src/db/edge_persistence_bridge.ts`
  - **Action:** Add DDL and CRUD methods (`listNotifications`, `upsertNotification`, `markNotificationRead`, `markAllNotificationsRead`, `deleteNotification`, `getCreatorQuota`, `consumeFreeMonthlySongQuota`).
- [x] **Task 67.4.2 — Mount `/api/notifications`, `/api/wallet/allowance` & Generation Quota Hook**:
  - **Target Files:**
    - `apps/vhunambi_api/src/routes/notification_routes.ts` *(New)*
    - `apps/vhunambi_api/src/routes/wallet_routes.ts`
    - `apps/vhunambi_api/src/routes/generation_routes.ts`
    - `apps/vhunambi_api/src/server.ts`
  - **Action:** Mount `/api/notifications` and `/api/v1/notifications`, add `GET /api/wallet/allowance`, and decrement monthly free song allowance + emit server notification on `POST /v1/generations`.

### Milestone `M67.5` — Live Event Producers, Unified Home Bell Badge & E2E Verification (`REQ-P67-EVT-01..02`)

- [x] **Task 67.5.1 — Upgrade `HomeDashboardView` to `NotificationBellButton`**:
  - **Target File:** `apps/vhunambi_client/lib/features/home/presentation/views/home_dashboard_view.dart`
  - **Action:** Replace raw `PhosphorIcon(AppIcons.bell)` (`#L310-L333`) with `NotificationBellButton(key: const Key('home_notifications_btn'))` (`design.md` §5.1).
- [x] **Task 67.5.2 — Wire Live Social, Studio & Wallet Notification Producers**:
  - **Target Files:**
    - `apps/vhunambi_client/lib/features/social/presentation/widgets/kinetic_reels_modal.dart` (`_recordLove`)
    - `apps/vhunambi_client/lib/features/explore/presentation/widgets/repost_kinetic_post_sheet.dart` (`_submitRepost`)
    - `apps/vhunambi_client/lib/features/social/presentation/providers/reels_comments_provider.dart` (`addComment`)
    - `apps/vhunambi_client/lib/features/social/presentation/providers/creator_wallet_provider.dart` (`sendGift`, `recordMarketplaceRoyalty`)
    - `apps/vhunambi_client/lib/features/social/presentation/widgets/video_export_modal.dart` (`export_render_btn`)
  - **Action:** Emit structured `NotificationEntity` records with valid `subtype`, `targetRoute`, `targetEntityId`, and `ctaLabel` (`design.md` §5.2–5.4).
- [x] **Task 67.5.3 — Pass 2 Verification Suite (`phase67_pass2_routing_and_events_test.dart` & `phase67_notifications_quota.test.ts`)**:
  - **Target Files:**
    - `apps/vhunambi_client/test/features/notifications/phase67_pass2_routing_and_events_test.dart` *(New)*
    - `apps/vhunambi_api/src/phase67_notifications_quota.test.ts` *(New)*

---

## 4. Stage 4 Execution Verification Checklist (`/vhunambi-executioner`)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [x] 1. Zero Demo Mocks: phase40SeededNotifications & seedDemoAlerts purged   │
│ [x] 2. Starter DNA: Onboarding completeness lands initial DNA in 6%–10%      │
│ [x] 3. 3 Beginner Alerts: Welcome, DNA Calibrated, 10 Free Songs seeded once │
│ [x] 4. STD-UIUX-001: 0 stock Material Icons.* or raw emojis in notifications │
│ [x] 5. Keyboard & Rail: PrimaryFocus.unfocus() on tap/drag + ShaderMask rail │
│ [x] 6. Zero @fifi Fallback: Library & Explore tracks resolve in TrackDetail  │
│ [x] 7. Bounded Tests: All Flutter tests pass with --timeout=60s & 0 issues   │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Verification Commands
```powershell
# Pass 1 Gate
cd apps/vhunambi_client
dart analyze lib/features/notifications lib/features/onboarding lib/main.dart
flutter test test/features/notifications/ --timeout=60s

# Pass 2 Gate
dart analyze lib/features/notifications lib/features/track lib/features/home lib/features/social lib/features/explore
flutter test test/features/notifications/ test/features/explore/phase40_notifications_lexicon_cosign_and_topup_test.dart --timeout=60s
cd ../vhunambi_api
npm run build
node --import tsx --test src/phase67_notifications_quota.test.ts
```
