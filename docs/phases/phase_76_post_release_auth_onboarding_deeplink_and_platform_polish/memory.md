```json vhunambi-memory
{
  "phase_id": "P76",
  "memory_key": "MEM-P76-POST-RELEASE-AUTH-ONBOARDING-DEEPLINK-POLISH",
  "title": "Post-Release Live Device Theme Stability, Release Auth Security, Auth/Settings/Onboarding Glass, Full Notification Deep-Link Coverage & Platform Hygiene",
  "status": "completed",
  "completed_at": "2026-11-22T21:56:00Z",
  "predecessor_keys": [
    "MEM-P65-FOUNDATION-CRASH-IMMUNITY",
    "MEM-P67-NOTIFICATIONS-QUOTA",
    "MEM-P70-SONG-COCKPIT-VISITOR-PROFILE",
    "MEM-P72-ASSET-VAULT-OWNER-PROFILE-GLASS",
    "MEM-P73-KPOST-CHROMATIC-REACTIONS-HYGIENE",
    "MEM-P74-KINETIC-REELS-STUDIO-V4",
    "MEM-P75-STUDIO-COCKPIT-V5-CONNECTOME-CLOSURE"
  ],
  "concept_hubs": [
    "identity_role",
    "ui_surface_std",
    "social_graph",
    "sync_outbox",
    "quota_economy"
  ],
  "consumes": [
    "EP-P61-IDENTITY-UTILS",
    "EP-P67-DEEPLINK-ROUTER",
    "EP-P67-NOTIF-BELL",
    "EP-P70-GLASS-SURFACE",
    "EP-P72-BUYER-LICENSES-HTTP",
    "EP-P73-PROFILE-ROUTER",
    "EP-P74-REELS-STUDIO-PIPELINE"
  ],
  "endpoints": [
    {
      "id": "EP-P76-AUTH-RELEASE-GATE",
      "kind": "client_security_and_ui",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["identity_role", "ui_surface_std"],
      "spec_anchor": "docs/phases/phase_76_post_release_auth_onboarding_deeplink_and_platform_polish/design.md#22-appsvhunambi_clientlibcoreauthauth_providersdart--compile-time-release-gate-auth-01-req-p76-core-02",
      "code_anchor": "apps/vhunambi_client/lib/core/auth/auth_providers.dart",
      "summary": "Compile-time kEnableDemoCreatorQuickSwitch gate disabling demo studio creator quick-switch chips and offline tenant spoofing in production --release builds, paired with VhunambiGlassSurface Auth & Settings drawers and zero-unmount theme switching in main.dart.",
      "consumers": [
        "P76:SovereignAuthSheet",
        "P76:AuthSessionNotifier",
        "P76:ProfileSettingsDrawer",
        "P76:VhunambiApp"
      ],
      "open_opportunities": "Reuse kEnableDemoCreatorQuickSwitch to gate any future QA/staging diagnostic shortcuts out of store release APKs"
    },
    {
      "id": "EP-P76-DEEPLINK-COVERAGE",
      "kind": "client_routing_and_notifications",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["social_graph", "identity_role", "quota_economy", "ui_surface_std"],
      "spec_anchor": "docs/phases/phase_76_post_release_auth_onboarding_deeplink_and_platform_polish/design.md#31-appsvhunambi_clientlibfeaturesnotificationspresentationutilsnotification_deep_link_routerdart-dl-02-dl-03",
      "code_anchor": "apps/vhunambi_client/lib/features/notifications/presentation/utils/notification_deep_link_router.dart",
      "summary": "Full NotificationDeepLinkRouter + Bell Popover delegation covering cold-start /reel/:clipId hydration, /license/:id & /certificate/:id LicenseCertificateSheet routing, /profile & /@:handle Profile routing, and all 5 RootShell tab routes.",
      "consumers": [
        "P76:NotificationsPopover",
        "P76:NotificationDetailBottomSheet",
        "P76:BeatCheckoutNotifier"
      ],
      "open_opportunities": "Bind Android App Links / Universal Links intent handler directly into NotificationDeepLinkRouter.navigateDirect for external share URLs"
    },
    {
      "id": "EP-P76-ONBOARDING-GLASS-STD",
      "kind": "ui_surface_and_hygiene",
      "state": "CONNECTED_EXTENSIBLE",
      "hubs": ["ui_surface_std", "identity_role"],
      "spec_anchor": "docs/phases/phase_76_post_release_auth_onboarding_deeplink_and_platform_polish/design.md#4-pass-2-m764--onboarding-std-uiux-001--dual-theme-glass-polish",
      "code_anchor": "apps/vhunambi_client/lib/features/onboarding/presentation/widgets/role_carousel_widget.dart",
      "summary": "100% STD-UIUX-001 compliance across onboarding/ (0 stock Icons.*, 0 raw Unicode emojis via RoleOption.resolvedIcon & PhosphorIcon badges), VhunambiGlassSurface(enableLiveBlur: false), and Light/Dark contrast parity, paired with clean API dist/ prebuild and parallel cached Gradle config.",
      "consumers": [
        "P76:AppTourOverlay",
        "P76:RoleCarouselWidget",
        "P76:GenreColorChip",
        "P76:CreatorDnaHelixFinale",
        "P76:OnboardingAct3RootsDeck"
      ],
      "open_opportunities": "Extend VhunambiGlassSurface + *Of(context) Light/Dark audit to remaining legacy marketplace modals"
    }
  ],
  "edges": [
    {
      "from": "apps/vhunambi_client/lib/features/notifications/presentation/widgets/notifications_popover.dart",
      "relation": "DELEGATES_TO",
      "to": "EP-P67-DEEPLINK-ROUTER",
      "note": "Popover taps with effectiveRoute delegate to NotificationDeepLinkRouter.handleCardTap instead of checking targetTrackId only"
    },
    {
      "from": "apps/vhunambi_client/lib/features/notifications/presentation/utils/notification_deep_link_router.dart",
      "relation": "ROUTES_TO",
      "to": "EP-P73-PROFILE-ROUTER",
      "note": "Routes /profile, /profile/:id, /creator/:id, and /@:handle through navigateToCreatorProfile"
    },
    {
      "from": "apps/vhunambi_client/lib/features/notifications/presentation/utils/notification_deep_link_router.dart",
      "relation": "CONSUMES",
      "to": "EP-P72-BUYER-LICENSES-HTTP",
      "note": "Resolves /license/:id and /certificate/:id from licenseCertificatesProvider / libraryTracksProvider and launches showLicenseCertificateSheet"
    },
    {
      "from": "apps/vhunambi_client/lib/features/auth/presentation/widgets/sovereign_auth_sheet.dart",
      "relation": "CONSUMES",
      "to": "EP-P70-GLASS-SURFACE",
      "note": "Wraps SovereignAuthSheet, ProfileSettingsDrawer, NotificationsPopover, and Onboarding cards in VhunambiGlassSurface(enableLiveBlur: false)"
    }
  ],
  "breakthroughs": [
    "Stage 4 verification passed 100%: apps/vhunambi_api clean prebuild dist/ wipe + tsc --noEmit + 31/31 backend suites; apps/vhunambi_client dart analyze (0 issues), STD-UIUX-001 regex scan (0 violations), 79/79 auth+profile tests, and 148/148 Phase 76 + notifications + onboarding tests.",
    "Eliminated the P0 live theme toggle Navigator reset in main.dart, gated demo creator quick-switching out of release APKs via kEnableDemoCreatorQuickSwitch, upgraded Auth/Settings/Notifications/Onboarding to VhunambiGlassSurface + AppColors.*Of(context), and closed cold-start /reel, /license, /profile, /@handle, and shell tab deep-links."
  ],
  "gotchas": [
    "NotificationsPopover CTA button with an inline Row ('View All Alerts in Center' + PhosphorIcon) overflowed by 20px inside the 360px Dialog under Flutter's Ahem test font unless the label Text is wrapped in Flexible(..., overflow: TextOverflow.ellipsis).",
    "DesignTokenRegistry is a process-wide singleton across a test file isolate; multi-test setUp blocks calling TokenRegistration.registerAllTokens() must guard with if (!DesignTokenRegistry.isSealed).",
    "SovereignAuthException requires named parameters (statusCode:, code:, message:); CreativeRole enum values are producer, vocalist, songwriter, multiHyphenate, musicLover (not dj or artist).",
    "Huawei JNY_LX1 was detached during Stage 4 (adb.exe devices -l returned 0 devices). Because Supabase project cbnruevwrqwjnnoscgsz is on the FREE tier where HIBP Leaked Password Protection is Pro-only, full-stack password complexity (min 8 chars + uppercase, lowercase, digit, symbol) and a deterministic common-breached password blocklist were enforced in apps/vhunambi_api/src/security/password_policy.ts and apps/vhunambi_client/lib/core/auth/sovereign_password_policy.dart."
  ]
}
```

# Phase 76 Session Memory & Breakthroughs (Completed)

## 1. Core Architectural Scope
- **P0 Runtime Stability:** Removed `KeyedSubtree(key: ValueKey<Brightness>(effectiveBrightness))` wrapping `MaterialApp.builder`'s `?child` (`Navigator`) in `main.dart` so Light/Dark/System theme toggling repaints seamlessly with zero Drawer/Navigator loss.
- **P1 Security & Platform Hygiene:** Gated `QUICK STUDIO CREATORS` & offline tenant spoofing out of `--release` APKs (`kEnableDemoCreatorQuickSwitch`); enforced 8+ char 4-class complexity + common breached-password rejection (`password_policy.ts` & `sovereign_password_policy.dart`) with a live 5-pill checklist in `SovereignAuthSheet`; added cross-platform `prebuild` `dist/` wipe in `apps/vhunambi_api/package.json` eliminating stale `dist/phase67_notifications_quota.test.js`; tuned `android/gradle.properties` (`-Xmx4096m`, `parallel=true`, `caching=true`, `workers.max=4`).
- **P1 Deep-Link Closure:** Delegated `NotificationsPopover` taps with `effectiveRoute` to `NotificationDeepLinkRouter`, added cold-start `/reel/:clipId` hydration, `/license/:id` & `/certificate/:id` (`showLicenseCertificateSheet` + `BeatCheckoutNotifier` emitter), `/profile` / `/@:handle`, and all 5 `RootShell` tab routes.
- **P2 Glass & `STD-UIUX-001` Parity:** Upgraded `SovereignAuthSheet`, `ProfileSettingsDrawer` (+ 3 diagnostic cards), `NotificationsPopover`/`NotificationsView`, and all 9 `onboarding/` widgets to `VhunambiGlassSurface(enableLiveBlur: false)`, `AppColors.*Of(context)`, `>= 44dp` touch targets, `0` stock `Icons.*`, and `0` raw Unicode emojis.

## 2. Verification Summary
- **Backend (`apps/vhunambi_api`):** `npm run build && npx tsc --noEmit && npm test` passed (`31/31` suites, `0` `*.test.js` in `dist/`).
- **Client (`apps/vhunambi_client`):** `dart analyze` `0` issues; `STD-UIUX-001` regex scan `0` violations; `79/79` (`auth/` + `profile/`) and `148/148` (`phase76_auth_onboarding_deeplink_polish_test.dart` + `notifications/` + `onboarding/`) passed under `--no-pub --timeout=60s`.
