# Phase 76 — Requirements Specification (`requirements.md`)

**Document ID:** `SPEC-P76-REQUIREMENTS`  
**Phase Folder:** `docs/phases/phase_76_post_release_auth_onboarding_deeplink_and_platform_polish/`  
**Source Forensic Audit:** [`docs/audits/PHASE76_POST_RELEASE_AUTH_ONBOARDING_DEEPLINK_AND_PLATFORM_AUDIT.md`](../../audits/PHASE76_POST_RELEASE_AUTH_ONBOARDING_DEEPLINK_AND_PLATFORM_AUDIT.md)  
**Conventions:** EARS (`WHEN`, `WHILE`, `IF...THEN`, `WHERE`) & RFC-2119 (`SHALL`, `MUST`, `SHOULD`, `MAY`).

---

## 1. Document Scope & Standards

This specification defines all functional, security, UX contrast (`STD-UIUX-001`), routing, platform hygiene, and verification requirements for Phase 76 across:
- **Flutter Client (`apps/vhunambi_client`):** `lib/main.dart`, `lib/core/auth/`, `lib/features/auth/`, `lib/features/profile/presentation/widgets/`, `lib/features/notifications/`, `lib/features/onboarding/`, `lib/features/marketplace/presentation/providers/beat_checkout_provider.dart`, and `android/gradle.properties`.
- **Cloudflare Worker API (`apps/vhunambi_api`):** `package.json` clean build lifecycle and `dist/` hygiene.
- **Supabase Cloud (`cbnruevwrqwjnnoscgsz`):** Auth Attack Protection (HIBP Leaked Password Protection).

All UI specifications conform to:
- **Dual-Theme Contrast Parity:** Light Mode ("Morning Mist") & Dark Mode ("Obsidian Night") via `AppColors.*Of(context)`.
- **`STD-UIUX-001` Vector Law:** Zero stock Material `Icons.*` and zero raw Unicode emojis in production UI widgets; exclusively `PhosphorIcon(AppIcons.* / PhosphorIcons*)`.
- **Touch Ergonomics:** All interactive buttons, chips, and icon controls MUST enforce at least `44x44dp` touch targets.
- **60 FPS Mobile ARM64 Glass Law (`REQ-P70-GLASS-02`):** Every `VhunambiGlassSurface` inside scrollable sheets, lists, or drawers MUST set `enableLiveBlur: false`.

---

## 2. Platform Hygiene & Security Requirements (`REQ-P76-PLAT-*`, `M76.1`)

### `REQ-P76-PLAT-01` — Clean API `dist/` Prebuild & Zero Orphan Test JS Artifacts
- **WHEN** `npm run build` is executed in `apps/vhunambi_api`, **THE SYSTEM SHALL** remove the existing `dist/` directory via a cross-platform Node `"prebuild"` script (`node -e "const fs=require('fs'); fs.rmSync('dist', {recursive: true, force: true});"`) before invoking `tsc`.
- **THE SYSTEM SHALL** ensure zero `*.test.js` files (specifically `dist/phase67_notifications_quota.test.js`) exist inside `apps/vhunambi_api/dist/` after building, while preserving `npx tsc --noEmit` exit `0` and all `31/31` test suites passing in `npm test`.

### `REQ-P76-PLAT-02` — Android Gradle Performance & Build Hygiene
- **THE SYSTEM SHALL** optimize `apps/vhunambi_client/android/gradle.properties` for parallel cached Android builds on Windows/ARM64 targets:
  - Raise JVM heap to `-Xmx4096m -XX:MaxMetaspaceSize=1024m -XX:ReservedCodeCacheSize=512m`.
  - Enable `org.gradle.parallel=true`, `org.gradle.caching=true`, `org.gradle.daemon=true`, and `org.gradle.workers.max=4`.
  - Preserve `android.useAndroidX=true`, `android.newDsl=false`, and `android.builtInKotlin=false` unless all transitive plugins (`camera_android_camerax`, `record_android`, `share_plus`) compile cleanly without AGP/Kotlin DSL breakage.
- **WHERE** `flutter pub outdated` identifies non-breaking patch/minor plugin updates that eliminate Kotlin Gradle Plugin / Build-Tools warnings, Stage 4 **MAY** evaluate them only if `dart analyze` and `flutter test` remain 100% green; otherwise preserve pinned `pubspec.lock` stability and document any upstream plugin constraint.

### `REQ-P76-PLAT-03` — Supabase Auth Leaked Password Protection (HIBP)
- **THE SYSTEM SHALL** remediate the live `WARN` security advisor `auth_leaked_password_protection` on Supabase project `cbnruevwrqwjnnoscgsz` (`Ndugelo-Code's vhunambi`) by enabling HaveIBeenPwned (HIBP) compromised password rejection in Supabase Auth settings (via Management API or Dashboard Auth -> Attack Protection) and verifying via `supabase_mcp:get_advisors(project_id: "cbnruevwrqwjnnoscgsz", type: "security")`.
- **IF** automated Management API credentials are unavailable in the local workspace sandbox, **THEN** Stage 4 **SHALL** document the exact one-click Supabase Dashboard remediation path and keep the `21` `INFO` `rls_enabled_no_policy` notices explicitly documented as intentional service-role Worker isolation.

---

## 3. Core Runtime Stability, Release Auth Security & Settings Glass (`REQ-P76-CORE-*`, `M76.2`)

### `REQ-P76-CORE-01` — Zero-Unmount Theme Switching (`BOOT-01`, `P0`)
- **WHEN** the user toggles `themeModeProvider` (`ThemeMode.system`, `ThemeMode.light`, `ThemeMode.dark`) while any route or modal (including `ProfileSettingsDrawer`) is open, **THE SYSTEM SHALL NOT** unmount `MaterialApp.builder`'s `?child` (`Navigator`).
- **THE SYSTEM SHALL** remove `KeyedSubtree(key: ValueKey<Brightness>(effectiveBrightness), ...)` from `apps/vhunambi_client/lib/main.dart` and return `Stack(children: [?child, const MiniPlayerHost()])` directly after calling `AppColors.syncWithBrightness(effectiveBrightness)`.
- **Acceptance Invariant:** Switching `ThemeMode.dark -> ThemeMode.light -> ThemeMode.dark` MUST keep `ProfileSettingsDrawer` mounted and preserve `RootShell`'s active `_currentIndex` and `_tabHistory`.

### `REQ-P76-CORE-02` — Release-Mode Gate for Demo Creator Quick-Switch (`AUTH-01`, `P1`)
- **THE SYSTEM SHALL** define a compile-time constant in `apps/vhunambi_client/lib/core/auth/auth_providers.dart`:
  ```dart
  const bool kEnableDemoCreatorQuickSwitch =
      kDebugMode || bool.fromEnvironment('ENABLE_DEMO_CREATOR_SWITCH');
  ```
- **WHEN** `kEnableDemoCreatorQuickSwitch` is `false` (all standard `--release` builds):
  1. `SovereignAuthSheet` **SHALL NOT** render the `QUICK STUDIO CREATORS` section or any `Key('auth_quick_chip_*')` chip.
  2. `AuthSessionNotifier.switchToSeededCreator` **SHALL NOT** execute the offline local tenant-spoofing fallback (`usr_studio_$raw`); if `/api/auth/login` fails or is unreachable, it **SHALL** throw `SovereignAuthException(code: 'DEMO_SWITCH_DISABLED_IN_RELEASE', statusCode: 403, message: 'Quick studio demo switching is disabled in release builds. Sign in with your creator credentials.')`.
- **WHILE** `kEnableDemoCreatorQuickSwitch` is `true` (debug builds, `flutter test`, or explicit `--dart-define=ENABLE_DEMO_CREATOR_SWITCH=true` staging builds), existing quick-switch chips and `sovereign_auth_hud_widget_test.dart` behavior **SHALL** remain 100% operational.
- **THE SYSTEM SHALL** support an optional `@visibleForTesting final bool? enableDemoQuickSwitchOverride;` parameter on `SovereignAuthSheet` (default `null`, falling back to `kEnableDemoCreatorQuickSwitch`) so automated tests can verify both debug and release states cleanly.

### `REQ-P76-CORE-03` — `SovereignAuthSheet` Glassmorphism & Touch Target Hardening (`AUTH-02`, `P2`)
- **THE SYSTEM SHALL** present `SovereignAuthSheet.show` with `backgroundColor: Colors.transparent` and wrap its sheet chrome inside `VhunambiGlassSurface(variant: VhunambiGlassVariant.chrome, borderRadius: AppRadius.modalBorder, enableLiveBlur: false)`.
- **THE SYSTEM SHALL** wrap the 2-way `[Sign In | Create Account]` selector and error banner (`Key('auth_error_banner')`) in `VhunambiGlassSurface(enableLiveBlur: false)` using `AppColors.*Of(context)`.
- **THE SYSTEM SHALL** enforce `constraints: const BoxConstraints(minWidth: 44, minHeight: 44)` and `color: AppColors.textPrimaryOf(context)` on the Close `IconButton` and password visibility toggle `IconButton`.

### `REQ-P76-CORE-04` — `ProfileSettingsDrawer` & Diagnostic Cards Light/Dark Glass Parity (`SET-01`, `SET-02`, `P1`/`P2`)
- **THE SYSTEM SHALL** migrate `ProfileSettingsDrawer.show` to `backgroundColor: Colors.transparent` and wrap the drawer surface, segmented Theme Mode selector (`[System | Light | Dark]`), Audio Engine Specifications card, and Edge-Sync card in `VhunambiGlassSurface(enableLiveBlur: false)`.
- **THE SYSTEM SHALL** replace **100%** of static Dark-Mode `AppColors.{surfaceModal,surfaceElevated,surfaceSecondary,borderSubtle,textPrimary,textSecondary}` calls in `profile_settings_drawer.dart` with their dynamic `*Of(context)` getters so Light Mode ("Morning Mist") renders dark legible text on light frosted cards with zero white-on-white ghost tabs.
- **THE SYSTEM SHALL** upgrade `AccountIdentitySecurityCard`, `HiveBrainTelemetryCard`, and `CloudStackDiagnosticCard` outer card shells to `VhunambiGlassSurface(enableLiveBlur: false)` with `AppColors.*Of(context)` contrast parity.
- **THE SYSTEM SHALL** raise button heights on `Key('settings_sync_now_btn')`, `Key('hive_compact_now_btn')`, and `Key('hive_sync_now_btn')` from `36dp` to `minimumSize: const Size(0, 44)`.

---

## 4. Full Notification Deep-Link Coverage & Bell Popover Glass (`REQ-P76-DL-*`, `M76.3`)

### `REQ-P76-DL-01` — Bell Popover Full Deep-Link Delegation (`DL-01`, `P1`)
- **WHEN** a user taps any notification card inside `NotificationsPopover`:
  1. **THE SYSTEM SHALL** mark the notification as read (`notifier.markAsRead(notification.id)`), capture the host `BuildContext` (`Navigator.of(context).context`) before popping the dialog, and pop `NotificationsPopover`.
  2. **IF** `notification.effectiveRoute != null`, **THEN** **THE SYSTEM SHALL** delegate asynchronously to `NotificationDeepLinkRouter.handleCardTap(hostContext, ref, notification)` so `/track/:id`, `/reel/:id`, `/post/:id`, `/creator/:id`, `/profile`, `/@:handle`, `/license/:id`, `/certificate/:id`, `/creator-dna`, `/wallet`, and all shell tabs route identically to `NotificationsView`.
  3. **IF** `notification.effectiveRoute == null`, **THEN** **THE SYSTEM SHALL** mark read and dismiss cleanly without pushing a route (preserving legacy `notifications_popover_test.dart` behavior for bare route-less alerts).

### `REQ-P76-DL-02` — Cold-Start Reel Hydration (`/reel/:clipId`, `DL-02`, `P1`)
- **WHEN** `NotificationDeepLinkRouter.navigateDirect` handles `/reel/:clipId`:
  1. **IF** `ref.read(socialFeedProvider).clips` is empty, **THEN** **THE SYSTEM SHALL** call `await ref.read(socialFeedProvider.notifier).refreshFeed()` and re-read `clips`.
  2. **IF** `clips` is still empty AND `clipId.isNotEmpty` AND `context.mounted`, **THEN** **THE SYSTEM SHALL** synthesize a defensive fallback `PublishedClip` from `notification.metadata` (`title`, `creatorId`, `creatorName`, `creatorHandle`, `audioUrl`, `videoUrl`, `genre`) so `KineticReelsModal.show` launches instead of silently degrading to a text sheet.

### `REQ-P76-DL-03` — License Certificate, Profile & Shell Tab Deep Links (`DL-03`, `P1`)
- **THE SYSTEM SHALL** extend `NotificationDeepLinkRouter.navigateDirect` to route:
  - `/license/:certId` and `/certificate/:certId`:
    1. Search `ref.read(licenseCertificatesProvider)` for matching `certificateId == certId` (or `vaultTrackId == certId` / `beatId == certId`).
    2. If found, invoke `showLicenseCertificateSheet(context, certificate: matchedCert)`.
    3. Else search `ref.read(libraryTracksProvider)` by `licenseCertificateIdOverride == certId`, `id == certId`, or `id == metadata['vaultTrackId']`; if found, invoke `showLicenseCertificateSheet(context, track: matchedTrack)`.
    4. Else if `certId.isNotEmpty`, switch to Asset Vault tab (`appNavigationTabProvider = 3`) and `popUntil((r) => r.isFirst)`.
  - `/licenses`, `/vault`, `/library`: set `appNavigationTabProvider = 3` and `popUntil((r) => r.isFirst)`.
  - `/home`: set `appNavigationTabProvider = 0` and `popUntil((r) => r.isFirst)`.
  - `/explore`: set `appNavigationTabProvider = 1` and `popUntil((r) => r.isFirst)`.
  - `/marketplace`, `/market`: set `appNavigationTabProvider = 4` and `popUntil((r) => r.isFirst)`.
  - `/profile`: invoke `navigateToCreatorProfile(context, ref, creatorId: ref.read(currentCreatorIdProvider))`.
  - `/profile/:id`: invoke `navigateToCreatorProfile(context, ref, creatorId: id)`.
  - `/@:handle`: invoke `navigateToCreatorProfile(context, ref, creatorId: canonicalizeCreatorId(handle), creatorHandle: '@$handle')`.
- **THE SYSTEM SHALL** update `BeatCheckoutNotifier.purchaseBeat` (`beat_checkout_provider.dart#L367-L379`) to attach `subtype: 'license_acquired'`, `targetRoute: '/license/${cert.certificateId}'`, `targetEntityId: cert.certificateId`, `ctaLabel: 'View License Deed'`, and `metadata: {'certificateId': cert.certificateId, 'vaultTrackId': vaultTrackId, 'beatTitle': beat.title, 'tier': tier.displayName}` to its emitted Marketplace License notification.
- **THE SYSTEM SHALL** update `NotificationDetailBottomSheet._defaultCtaLabel` to return human-readable labels for `/license/`, `/certificate/`, `/licenses`, `/profile`, `/@`, `/post/`, `/home`, `/explore`, `/library`, `/vault`, and `/marketplace`.

### `REQ-P76-DL-04` — Notifications Surface Dual-Theme & Glass Parity (`NOTIF-UI-01`, `P2`)
- **THE SYSTEM SHALL** wrap `NotificationsPopover` in `VhunambiGlassSurface(variant: VhunambiGlassVariant.chrome, borderRadius: BorderRadius.circular(16), enableLiveBlur: false)` and convert all colors in `notifications_popover.dart`, `notifications_view.dart`, `notification_search_bar.dart`, and `notification_empty_state.dart` from static Dark-Mode `AppColors.*` to `AppColors.*Of(context)`.
- **THE SYSTEM SHALL** replace `'View All Alerts in Center ➔'` in `notifications_popover.dart#L183` with a `Row` pairing `'View All Alerts in Center'` and `PhosphorIcon(AppIcons.arrowRight, size: 14, color: AppColors.brandContrast)` (zero Unicode arrows/emojis).

---

## 5. Onboarding `STD-UIUX-001` & Dual-Theme Glass Requirements (`REQ-P76-ONB-*`, `M76.4`)

### `REQ-P76-ONB-01` — Zero Stock `Icons.*` & Zero Raw Unicode Emojis in `onboarding/`
- **THE SYSTEM SHALL** eliminate all **7 stock Material `Icons.*`** occurrences across `apps/vhunambi_client/lib/features/onboarding/`:
  - `app_tour_overlay.dart`: `Icons.auto_awesome` -> `AppIcons.sparkle`, `Icons.edit_note` -> `AppIcons.edit`, `Icons.mic` -> `AppIcons.mic`, `Icons.music_note` -> `AppIcons.songs`, `Icons.folder` -> `PhosphorIconsRegular.folder`, rendered with `PhosphorIcon(...)`.
  - `genre_color_chip.dart`: `Icons.check_circle` -> `PhosphorIcon(AppIcons.checkCircle, size: 18, color: accent)`.
  - `role_carousel_widget.dart`: `Icons.check_circle` -> `PhosphorIcon(AppIcons.checkCircle, size: 20, color: AppColors.brandPrimary)`.
- **THE SYSTEM SHALL** eliminate all **3 raw Unicode emoji UI surfaces** across `onboarding/`:
  - `role_carousel_widget.dart`: Add optional `IconData? icon` and `IconData get resolvedIcon` to `RoleOption` (keeping `this.emoji = ''` optional for backward-compatible tests) and render `PhosphorIcon(role.resolvedIcon)` inside a tinted glass icon badge instead of `Text(role.emoji)`.
  - `creator_dna_helix_finale.dart#L465`: Replace `'🔒 Quest: ...'` with a `Row` containing `PhosphorIcon(PhosphorIconsBold.lock, size: 12, color: ...)` + `'Quest: ${node.questInstruction}'`.
  - `onboarding_act3_roots_deck.dart#L516`: Replace `'✨ Era Match'` with a `Row` containing `PhosphorIcon(AppIcons.sparkle, size: 10, color: ...)` + `'Era Match'`.

### `REQ-P76-ONB-02` — Onboarding `VhunambiGlassSurface` & Light/Dark Token Migration
- **THE SYSTEM SHALL** migrate non-canvas card, chip, and modal containers across `onboarding_view.dart`, `app_tour_overlay.dart`, `role_carousel_widget.dart`, `genre_color_chip.dart`, `mood_color_chip.dart`, `creator_dna_helix_finale.dart`, `onboarding_act1_showcase.dart`, `onboarding_act3_roots_deck.dart`, and `interactive_identity_card_stack.dart` to `VhunambiGlassSurface(enableLiveBlur: false)` and `AppColors.*Of(context)` (`surfaceCanvasOf`, `surfaceElevatedOf`, `surfaceSecondaryOf`, `surfaceModalOf`, `borderSubtleOf`, `textPrimaryOf`, `textSecondaryOf`), eliminating raw dark hex fills (`Color(0xFF141418)`, `Color(0xFF15151D)`, `Color(0xFF16161C)`, `Color(0xFF1C1C24)`, and hardcoded `Colors.white` / `Colors.grey.shade100` card backgrounds).
- **THE SYSTEM SHALL** preserve all existing `Key(...)` widget identifiers, `Semantics` labels, `44x44dp` minimum touch targets, and `SharedPreferences` persistence keys (`has_completed_app_tour`).

---

## 6. Non-Functional Requirements (`REQ-P76-NFR-*`)

| ID | Category | Requirement |
| :--- | :--- | :--- |
| **`REQ-P76-NFR-01`** | 60 FPS Mobile Performance | Zero `BackdropFilter` inside repeating list/carousel items; every Phase 76 `VhunambiGlassSurface` defaults `enableLiveBlur: false`. |
| **`REQ-P76-NFR-02`** | Anti-Hang Test Hygiene | All Flutter tests execute via `flutter test --no-pub --timeout=60s` using bounded `tester.pump(Duration)` loops wherever repeating animations exist. |
| **`REQ-P76-NFR-03`** | Zero Breaking Regression | All pre-existing suites in `test/features/auth/`, `test/features/profile/`, `test/features/notifications/`, `test/features/onboarding/`, and all `31/31` API test suites MUST pass 100%. |
| **`REQ-P76-NFR-04`** | Authentic Telemetry | Physical device verification uses `C:\Users\Ndugelo\AppData\Local\Android\Sdk\platform-tools\adb.exe`; zero simulated or fabricated `logcat` output is ever recorded. |

---

## 7. Granular Requirement-to-Test Traceability Matrix

```
┌──────────────────┬────────────────────────────────────────────────────────┬───────────────────────────────────────────────────────────────┐
│ Requirement ID   │ Target Production File(s)                              │ Verification Gate / Automated Test Case                       │
├──────────────────┼────────────────────────────────────────────────────────┼───────────────────────────────────────────────────────────────┤
│ REQ-P76-PLAT-01  │ apps/vhunambi_api/package.json + dist/                 │ G76-01: npm run build -> 0 *.test.js in dist + npm test 31/31 │
│ REQ-P76-PLAT-02  │ apps/vhunambi_client/android/gradle.properties         │ G76-05: gradle.properties parallel/caching/heap verified      │
│ REQ-P76-PLAT-03  │ Supabase Auth (cbnruevwrqwjnnoscgsz)                   │ G76-05: supabase_mcp:get_advisors(security) HIBP check        │
│ REQ-P76-CORE-01  │ apps/vhunambi_client/lib/main.dart                     │ phase76 test: 'theme toggle preserves Navigator & Drawer'     │
│ REQ-P76-CORE-02  │ core/auth/auth_providers.dart, sovereign_auth_sheet    │ phase76 test: 'release mode hides demo chips & blocks spoof'  │
│ REQ-P76-CORE-03  │ features/auth/presentation/widgets/sovereign_auth_sheet│ phase76 test: 'SovereignAuthSheet glass & 44dp close/eye'     │
│ REQ-P76-CORE-04  │ profile_settings_drawer.dart + 3 diagnostic cards      │ phase76 test: 'ProfileSettingsDrawer Light Mode contrast/44dp'│
│ REQ-P76-DL-01    │ notifications_popover.dart                             │ phase76 test: 'Bell Popover routes /reel, /license, /profile' │
│ REQ-P76-DL-02    │ notification_deep_link_router.dart                     │ phase76 test: 'cold-start /reel/:clipId hydrates & opens'     │
│ REQ-P76-DL-03    │ notification_deep_link_router.dart, beat_checkout, etc │ phase76 test: '/license, /profile, /@handle, /vault, /market' │
│ REQ-P76-DL-04    │ popover, notifications_view, search_bar, empty_state   │ G76-04 + phase76 test: 'Notifications Light Mode glass'       │
│ REQ-P76-ONB-01   │ features/onboarding/presentation/{views,widgets}/*     │ G76-04: regex scan 0 Icons.* & 0 raw emojis in onboarding/    │
│ REQ-P76-ONB-02   │ features/onboarding/presentation/{views,widgets}/*     │ phase76 test + existing onboarding tests (100% Light/Dark)    │
└──────────────────┴────────────────────────────────────────────────────────┴───────────────────────────────────────────────────────────────┘
```
