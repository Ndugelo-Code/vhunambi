# Phase 76 — Deterministic 2-Pass Execution Task Plan (`tasks.md`)

**Document ID:** `SPEC-P76-TASKS`  
**Phase Folder:** `docs/phases/phase_76_post_release_auth_onboarding_deeplink_and_platform_polish/`  
**Execution Mode:** Strictly **2 Sequential Passes** (`Pass 1: M76.1–M76.2` -> Pass 1 Gates -> `Pass 2: M76.3–M76.4` -> Full Gates `G76-01`–`G76-06` -> `SLEEP`).

---

## 1. Master Milestone Roadmap & Dependency Graph

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ PASS 1: PLATFORM HYGIENE & CORE RUNTIME / AUTH / SETTINGS STABILITY                    │
│  [M76.1] API prebuild dist/ clean + Gradle tuning + Supabase Auth HIBP verification    │
│     └──► [M76.2] main.dart Navigator fix + Auth release gate/Glass + Settings Glass    │
│             └──► PASS 1 GATE (G76-01 + G76-02 MUST PASS 100% BEFORE PASS 2)            │
├──────────────────────────────────────────┬─────────────────────────────────────────────┤
│                                          ▼                                             │
│ PASS 2: FULL DEEP-LINK ROUTING, ONBOARDING GLASS POLISH, TESTS & SLEEP                 │
│  [M76.3] NotificationDeepLinkRouter + BeatCheckout route + Bell Popover Glass/Routing  │
│     └──► [M76.4] Onboarding STD-UIUX-001/Glass + Phase 76 tests + ADB check + SLEEP    │
│             └──► FINAL GATES (G76-01 .. G76-06 + consolidate_memory.mjs 0 OPEN)        │
└──────────────────────────────────────────┴─────────────────────────────────────────────┘
```

| Milestone | Pass | Tasks | Primary Targets |
| :---: | :---: | :---: | :--- |
| **`M76.1`** | Pass 1 | `T76.1.1` – `T76.1.3` | `apps/vhunambi_api/package.json`, `apps/vhunambi_client/android/gradle.properties`, Supabase `cbnruevwrqwjnnoscgsz` |
| **`M76.2`** | Pass 1 | `T76.2.1` – `T76.2.3` | `main.dart`, `auth_providers.dart`, `sovereign_auth_sheet.dart`, `profile_settings_drawer.dart` + 3 cards |
| **`M76.3`** | Pass 2 | `T76.3.1` – `T76.3.3` | `notification_deep_link_router.dart`, `notification_detail_bottom_sheet.dart`, `beat_checkout_provider.dart`, `notifications_popover.dart` + 3 notification views/widgets |
| **`M76.4`** | Pass 2 | `T76.4.1` – `T76.4.4` | 9 `onboarding/` files, `phase76_auth_onboarding_deeplink_polish_test.dart`, optional Huawei `JNY_LX1` ADB telemetry, `memory.md` + `consolidate_memory.mjs` |

---

## 2. Pass 1 — `M76.1`: Platform Hygiene (`API dist/`, `Android Gradle`, `Supabase Auth HIBP`)

- [x] **T76.1.1 — Clean API `dist/` & Add Cross-Platform `prebuild` Hook (`REQ-P76-PLAT-01`)**
  - **Target:** [`apps/vhunambi_api/package.json`](../../../apps/vhunambi_api/package.json)
  - **Action:** Add `"prebuild": "node -e \"const fs=require('fs'); fs.rmSync('dist', {recursive: true, force: true});\""` to `scripts`; run `npm run build && npx tsc --noEmit && npm test`.
  - **Acceptance:** `apps/vhunambi_api/dist/phase67_notifications_quota.test.js` no longer exists; zero `*.test.js` files exist in `dist/`; `tsc --noEmit` exits `0`; `31/31` API tests pass.

- [x] **T76.1.2 — Optimize Android Gradle Build Config (`REQ-P76-PLAT-02`)**
  - **Target:** [`apps/vhunambi_client/android/gradle.properties`](../../../apps/vhunambi_client/android/gradle.properties)
  - **Action:** Apply `design.md §1.2` (`-Xmx4096m -XX:MaxMetaspaceSize=1024m -XX:ReservedCodeCacheSize=512m -Dfile.encoding=UTF-8`, `org.gradle.workers.max=4`, `org.gradle.parallel=true`, `org.gradle.caching=true`, `org.gradle.daemon=true`, preserving `android.useAndroidX=true`, `android.newDsl=false`, `android.builtInKotlin=false`). Audit `flutter pub outdated` for safe Kotlin plugin warnings without breaking `pubspec.lock`.
  - **Acceptance:** `gradle.properties` matches `design.md §1.2`; Android Gradle configuration remains valid.

- [x] **T76.1.3 — Verify / Enable Supabase Auth Leaked Password Protection (`REQ-P76-PLAT-03`)**
  - **Target:** Supabase project `cbnruevwrqwjnnoscgsz` (`supabase_mcp`)
  - **Action:** Check available Supabase MCP/CLI path to toggle HIBP leaked password protection; re-run `supabase_mcp:get_advisors(project_id: "cbnruevwrqwjnnoscgsz", type: "security")`. If Dashboard-only toggle is required by user privileges, record exact one-click Dashboard path (`Authentication -> Attack Protection -> Prevent use of leaked passwords`) transparently in the Pass 1 report without misreporting advisor state.
  - **Acceptance:** Live `get_advisors(security)` output verified and documented accurately.

---

## 3. Pass 1 — `M76.2`: Core Runtime Stability, Release Auth Security & Settings Glass

- [x] **T76.2.1 — Fix Live Theme Toggle Navigator Reset (`BOOT-01`, `REQ-P76-CORE-01`)**
  - **Target:** [`apps/vhunambi_client/lib/main.dart`](../../../apps/vhunambi_client/lib/main.dart#L118-L132)
  - **Action:** Remove `KeyedSubtree(key: ValueKey<Brightness>(effectiveBrightness), ...)` around `?child` in `VhunambiApp.build` and return `Stack(children: [?child, const MiniPlayerHost()])` directly after `AppColors.syncWithBrightness(effectiveBrightness)`.
  - **Acceptance:** Switching `themeModeProvider` preserves active `Navigator` stack, open modal sheets, and `RootShell` `_currentIndex`/`_tabHistory`.

- [x] **T76.2.2 — Release-Gate Demo Creator Quick-Switch & Upgrade `SovereignAuthSheet` Glass (`AUTH-01/02`, `REQ-P76-CORE-02/03`)**
  - **Targets:**
    - [`apps/vhunambi_client/lib/core/auth/auth_providers.dart`](../../../apps/vhunambi_client/lib/core/auth/auth_providers.dart)
    - [`apps/vhunambi_client/lib/features/auth/presentation/widgets/sovereign_auth_sheet.dart`](../../../apps/vhunambi_client/lib/features/auth/presentation/widgets/sovereign_auth_sheet.dart)
  - **Action:**
    - Export `kEnableDemoCreatorQuickSwitch = kDebugMode || bool.fromEnvironment('ENABLE_DEMO_CREATOR_SWITCH')` in `auth_providers.dart`.
    - Add `bool allowDemoSwitch = kEnableDemoCreatorQuickSwitch` to `AuthSessionNotifier.switchToSeededCreator`, failing closed with `SovereignAuthException(..., code: 'DEMO_SWITCH_DISABLED_IN_RELEASE', statusCode: 403)` when `false`.
    - Add `@visibleForTesting final bool? enableDemoQuickSwitchOverride;` to `SovereignAuthSheet`, hide `QUICK STUDIO CREATORS` when disabled, wrap modal chrome/mode pill/error banner in `VhunambiGlassSurface(enableLiveBlur: false)`, and enforce `44x44dp` constraints + `AppColors.textPrimaryOf(context)` on Close & eye toggle buttons.
  - **Acceptance:** All existing tests in `test/features/auth/` pass 100%; release-mode gate hides quick-switch chips and rejects offline spoofing.

- [x] **T76.2.3 — Upgrade `ProfileSettingsDrawer` & 3 Diagnostic Cards to Dual-Theme Glass (`SET-01/02`, `REQ-P76-CORE-04`)**
  - **Targets:**
    - [`apps/vhunambi_client/lib/features/profile/presentation/widgets/profile_settings_drawer.dart`](../../../apps/vhunambi_client/lib/features/profile/presentation/widgets/profile_settings_drawer.dart)
    - [`apps/vhunambi_client/lib/features/profile/presentation/widgets/account_identity_security_card.dart`](../../../apps/vhunambi_client/lib/features/profile/presentation/widgets/account_identity_security_card.dart)
    - [`apps/vhunambi_client/lib/features/profile/presentation/widgets/hive_brain_telemetry_card.dart`](../../../apps/vhunambi_client/lib/features/profile/presentation/widgets/hive_brain_telemetry_card.dart)
    - [`apps/vhunambi_client/lib/features/profile/presentation/widgets/cloud_stack_diagnostic_card.dart`](../../../apps/vhunambi_client/lib/features/profile/presentation/widgets/cloud_stack_diagnostic_card.dart)
  - **Action:** Migrate all 4 files to `VhunambiGlassSurface(enableLiveBlur: false)`, replace 100% of static Dark-Mode `AppColors.*` references with `AppColors.*Of(context)` (fixing Light-Mode ghost tabs in `_buildThemeOption`), and raise `settings_sync_now_btn`, `hive_compact_now_btn`, and `hive_sync_now_btn` `minimumSize` to `const Size(0, 44)`.
  - **Acceptance:** `dart analyze` `0` issues; Light & Dark modes both exhibit crisp contrast; `test/features/profile/` passes 100%.

### Pass 1 Gate Checkpoint (MUST PASS 100% BEFORE STARTING PASS 2)
```powershell
Push-Location c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_api
npm run build; if ($LASTEXITCODE -ne 0) { exit 1 }
npx tsc --noEmit; if ($LASTEXITCODE -ne 0) { exit 1 }
npm test; if ($LASTEXITCODE -ne 0) { exit 1 }
Get-ChildItem -Path "dist" -Recurse -Filter "*.test.js"
Pop-Location

Push-Location c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_client
dart analyze lib/main.dart lib/core/auth lib/features/auth lib/features/profile
flutter test --no-pub --timeout=60s test/features/auth/ test/features/profile/
Pop-Location
```

---

## 4. Pass 2 — `M76.3`: Full `NotificationDeepLinkRouter` Coverage & Bell Popover Glass

- [x] **T76.3.1 — Expand `NotificationDeepLinkRouter` & `NotificationDetailBottomSheet` (`DL-02/03`, `REQ-P76-DL-02/03`)**
  - **Targets:**
    - [`apps/vhunambi_client/lib/features/notifications/presentation/utils/notification_deep_link_router.dart`](../../../apps/vhunambi_client/lib/features/notifications/presentation/utils/notification_deep_link_router.dart)
    - [`apps/vhunambi_client/lib/features/notifications/presentation/widgets/notification_detail_bottom_sheet.dart`](../../../apps/vhunambi_client/lib/features/notifications/presentation/widgets/notification_detail_bottom_sheet.dart)
  - **Action:**
    - Verify `PublishedClip` exact required fields in `published_clip.dart` first, then implement cold-start `/reel/:clipId` `refreshFeed()` + fallback `PublishedClip` hydration.
    - Add `/license/:id` & `/certificate/:id` -> `showLicenseCertificateSheet`, `/profile`, `/profile/:id`, `/@:handle` -> `navigateToCreatorProfile`, and `/home`, `/explore`, `/library`, `/vault`, `/licenses`, `/marketplace`, `/market` -> `appNavigationTabProvider` switching.
    - Expand `_defaultCtaLabel` in `notification_detail_bottom_sheet.dart` for all new route prefixes.
  - **Acceptance:** Every route in `blueprint.md §4` resolves cleanly with zero silent drops.

- [x] **T76.3.2 — Emit License Deep-Link Route from Marketplace Checkout (`REQ-P76-DL-03`)**
  - **Target:** [`apps/vhunambi_client/lib/features/marketplace/presentation/providers/beat_checkout_provider.dart`](../../../apps/vhunambi_client/lib/features/marketplace/presentation/providers/beat_checkout_provider.dart#L367-L379)
  - **Action:** Attach `subtype: 'license_acquired'`, `targetRoute: '/license/${cert.certificateId}'`, `targetEntityId: cert.certificateId`, `ctaLabel: 'View License Deed'`, and `metadata` (`certificateId`, `vaultTrackId`, `beatId`, `beatTitle`, `tier`) to the checkout notification.
  - **Acceptance:** Purchasing a beat emits a deep-linkable certificate alert opening `LicenseCertificateSheet` on tap.

- [x] **T76.3.3 — Delegate Bell Popover to `NotificationDeepLinkRouter` & Upgrade Notifications Glass (`DL-01`, `NOTIF-UI-01`, `REQ-P76-DL-01/04`)**
  - **Targets:**
    - [`apps/vhunambi_client/lib/features/notifications/presentation/widgets/notifications_popover.dart`](../../../apps/vhunambi_client/lib/features/notifications/presentation/widgets/notifications_popover.dart)
    - [`apps/vhunambi_client/lib/features/notifications/presentation/views/notifications_view.dart`](../../../apps/vhunambi_client/lib/features/notifications/presentation/views/notifications_view.dart)
    - [`apps/vhunambi_client/lib/features/notifications/presentation/widgets/notification_search_bar.dart`](../../../apps/vhunambi_client/lib/features/notifications/presentation/widgets/notification_search_bar.dart)
    - [`apps/vhunambi_client/lib/features/notifications/presentation/widgets/notification_empty_state.dart`](../../../apps/vhunambi_client/lib/features/notifications/presentation/widgets/notification_empty_state.dart)
  - **Action:**
    - Delegate `_openNotification` (when `effectiveRoute != null`) to `NotificationDeepLinkRouter.handleCardTap(hostContext, ref, notification)` after capturing `navigator.context` and popping; dismiss-only when `effectiveRoute == null` (preserving `notifications_popover_test.dart`).
    - Wrap `NotificationsPopover` in `VhunambiGlassSurface(enableLiveBlur: false)`, replace `'View All Alerts in Center ➔'` with `Row` + `PhosphorIcon(AppIcons.arrowRight)`, and migrate all 4 files to `AppColors.*Of(context)`.
  - **Acceptance:** `test/features/notifications/` passes 100% with zero regressions.

---

## 5. Pass 2 — `M76.4`: Onboarding `STD-UIUX-001`/Glass Polish, Phase 76 Regression Tests, Device Check & `SLEEP`

- [x] **T76.4.1 — Purge 7 `Icons.*`, 3 Emoji Surfaces & Hardcoded Hex Cards Across `onboarding/` (`ONB-01..06`, `REQ-P76-ONB-01/02`)**
  - **Targets:**
    - [`apps/vhunambi_client/lib/features/onboarding/presentation/views/onboarding_view.dart`](../../../apps/vhunambi_client/lib/features/onboarding/presentation/views/onboarding_view.dart)
    - [`apps/vhunambi_client/lib/features/onboarding/presentation/widgets/app_tour_overlay.dart`](../../../apps/vhunambi_client/lib/features/onboarding/presentation/widgets/app_tour_overlay.dart)
    - [`apps/vhunambi_client/lib/features/onboarding/presentation/widgets/role_carousel_widget.dart`](../../../apps/vhunambi_client/lib/features/onboarding/presentation/widgets/role_carousel_widget.dart)
    - [`apps/vhunambi_client/lib/features/onboarding/presentation/widgets/genre_color_chip.dart`](../../../apps/vhunambi_client/lib/features/onboarding/presentation/widgets/genre_color_chip.dart)
    - [`apps/vhunambi_client/lib/features/onboarding/presentation/widgets/mood_color_chip.dart`](../../../apps/vhunambi_client/lib/features/onboarding/presentation/widgets/mood_color_chip.dart)
    - [`apps/vhunambi_client/lib/features/onboarding/presentation/widgets/creator_dna_helix_finale.dart`](../../../apps/vhunambi_client/lib/features/onboarding/presentation/widgets/creator_dna_helix_finale.dart)
    - [`apps/vhunambi_client/lib/features/onboarding/presentation/widgets/onboarding_act1_showcase.dart`](../../../apps/vhunambi_client/lib/features/onboarding/presentation/widgets/onboarding_act1_showcase.dart)
    - [`apps/vhunambi_client/lib/features/onboarding/presentation/widgets/onboarding_act3_roots_deck.dart`](../../../apps/vhunambi_client/lib/features/onboarding/presentation/widgets/onboarding_act3_roots_deck.dart)
    - [`apps/vhunambi_client/lib/features/onboarding/presentation/widgets/interactive_identity_card_stack.dart`](../../../apps/vhunambi_client/lib/features/onboarding/presentation/widgets/interactive_identity_card_stack.dart)
  - **Action:** Apply `design.md §4.1–§4.4`, preserving `RoleOption(..., this.emoji = '', this.icon)` compatibility, `AppTourOverlay` card titles/keys, and `GenreColorChip` `44x44dp` + `Semantics`.
  - **Acceptance:** `STD-UIUX-001` regex scan returns `0` matches; `test/features/onboarding/` passes 100%.

- [x] **T76.4.2 — Author & Pass Phase 76 Regression Test Suite (`G76-05`)**
  - **Target:** [`apps/vhunambi_client/test/features/phase76_auth_onboarding_deeplink_polish_test.dart`](../../../apps/vhunambi_client/test/features/phase76_auth_onboarding_deeplink_polish_test.dart)
  - **Action:** Implement all 6 regression groups specified in `design.md §5`.
  - **Acceptance:** `flutter test --no-pub --timeout=60s test/features/phase76_auth_onboarding_deeplink_polish_test.dart` passes 100%.

- [x] **T76.4.3 — Full Verification Gates (`G76-01`–`G76-05`) & Optional Physical `JNY_LX1` ADB Check**
  - **Action:** Run full static analysis, `STD-UIUX-001` regex audit, targeted + full client & API tests; run `C:\Users\Ndugelo\AppData\Local\Android\Sdk\platform-tools\adb.exe devices -l` — if Huawei `JNY_LX1` (`EPHUT20917014649`) is connected, build release arm64 APK, install, and capture live startup `logcat` errors (`0` fatal exceptions); if disconnected, record `0 devices attached` transparently.
  - **Acceptance:** All automated gates `G76-01`–`G76-05` pass 100%.

- [x] **T76.4.4 — Hippocampus `SLEEP` & Connectome Consolidation (`G76-06`)**
  - **Target:** [`docs/phases/phase_76_post_release_auth_onboarding_deeplink_and_platform_polish/memory.md`](./memory.md)
  - **Action:** Update `"status": "completed"` and `"completed_at"` to live UTC ISO timestamp, record any new Stage 4 gotchas, run `node .agents/skills/vhunambi-memory/scripts/consolidate_memory.mjs`, and verify `node .agents/skills/vhunambi-memory/scripts/query_connectome.mjs --open` reports `0` OPEN endpoints.
  - **Acceptance:** `CORTEX_INDEX.md` reflects `Latest Completed: P76` with `0 OPEN` endpoints.

---

## 6. Stage 4 Execution Anti-Trap Checklist & Final Gate Commands

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ STAGE 4 ANTI-TRAP CHECKLIST (VERIFY BEFORE MARKING PHASE 76 COMPLETED)                 │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ [x] 1. main.dart has NO KeyedSubtree(ValueKey<Brightness>) wrapping ?child Navigator.  │
│ [x] 2. kEnableDemoCreatorQuickSwitch hides chips & blocks local spoof in --release     │
│        while keeping sovereign_auth_hud_widget_test.dart 100% green in kDebugMode.     │
│ [x] 3. Every VhunambiGlassSurface uses enableLiveBlur: false, tintAccent &             │
│        borderColorOverride (NEVER tintColor or borderColor).                           │
│ [x] 4. NotificationsPopover delegates effectiveRoute alerts to DeepLinkRouter AND      │
│        preserves bare-alert dismiss + bellSlash + AppIcons.close test assertions.      │
│ [x] 5. RoleOption keeps optional `this.emoji = ''` so role_carousel_widget_test.dart   │
│        compiles cleanly while rendering PhosphorIcon(role.resolvedIcon) only.          │
│ [x] 6. Zero stock Icons.* and zero raw Unicode emojis across auth/, onboarding/,       │
│        notifications/, and profile_settings_drawer.dart (STD-UIUX-001).                │
│ [x] 7. Zero *.test.js files inside apps/vhunambi_api/dist/ after npm run build.        │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

### Final Verification Gate Commands (`G76-01` – `G76-06`)
```powershell
# G76-01: Backend Clean Build & Tests
Push-Location c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_api
npm run build && npx tsc --noEmit && npm test
Get-ChildItem -Path "dist" -Recurse -Filter "*.test.js"
Pop-Location

# G76-02..G76-05: Client Analysis, STD-UIUX-001 Audit & Regression Suites
Push-Location c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_client
dart analyze lib/main.dart lib/core/auth lib/features/auth lib/features/onboarding lib/features/notifications lib/features/profile lib/features/marketplace/presentation/providers/beat_checkout_provider.dart test/features/phase76_auth_onboarding_deeplink_polish_test.dart
Get-ChildItem -Path "lib\features\auth","lib\features\onboarding","lib\features\notifications","lib\features\profile\presentation\widgets\profile_settings_drawer.dart" -Recurse -Filter "*.dart" |
  Select-String -CaseSensitive -Pattern "(?<![A-Za-z])Icons\.|[\uD83C-\uDBFF][\uDC00-\uDFFF]"
flutter test --no-pub --timeout=60s test/features/auth/ test/features/profile/ test/features/notifications/ test/features/onboarding/ test/features/phase76_auth_onboarding_deeplink_polish_test.dart
Pop-Location

# Optional Live Device Check
& "C:\Users\Ndugelo\AppData\Local\Android\Sdk\platform-tools\adb.exe" devices -l

# G76-06: SLEEP Consolidation
node .agents/skills/vhunambi-memory/scripts/consolidate_memory.mjs
node .agents/skills/vhunambi-memory/scripts/query_connectome.mjs --open
```
