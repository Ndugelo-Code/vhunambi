# Phase 76 — Argon-Hardened Technical Design Specification (`design.md`)

**Document ID:** `SPEC-P76-DESIGN`  
**Phase Folder:** `docs/phases/phase_76_post_release_auth_onboarding_deeplink_and_platform_polish/`  
**Verified Baseline:** Flutter `3.44.4` / Dart `3.12.2` · Hono TypeScript (`apps/vhunambi_api`) · Supabase `cbnruevwrqwjnnoscgsz`  
**Audit Laws Enforced:** Authentic `package:vhunambi_client/...` imports, `package:phosphor_icons/phosphor_icons.dart`, `AppColors.*Of(context)`, `VhunambiGlassSurface(enableLiveBlur: false, tintAccent: ..., borderColorOverride: ...)`, zero stock `Icons.*`, zero raw Unicode emojis (`STD-UIUX-001`).

---

## 1. Pass 1 (`M76.1`) — Platform Hygiene Design

### 1.1 `apps/vhunambi_api/package.json` — Clean `dist/` Prebuild Hook (`REQ-P76-PLAT-01`)

Add a cross-platform Node `"prebuild"` lifecycle script right above `"build"` so `npm run build` wipes stale artifacts (such as orphaned `dist/phase67_notifications_quota.test.js`) before TypeScript emits fresh output:

```json
  "scripts": {
    "dev": "tsx watch src/index.ts",
    "prebuild": "node -e \"const fs=require('fs'); fs.rmSync('dist', {recursive: true, force: true});\"",
    "build": "tsc",
    "start": "node dist/index.js",
    "test": "..."
  }
```

**Verification invariant:** After `npm run build`, `apps/vhunambi_api/dist/` contains zero `*.test.js` files while `npx tsc --noEmit` exits `0` and `npm test` passes all `31/31` test files.

### 1.2 `apps/vhunambi_client/android/gradle.properties` — Parallel Cached Gradle Tuning (`REQ-P76-PLAT-02`)

Replace the throttled 8-line configuration (`-Xmx2048m`, `workers.max=2`, `parallel=false`, no build cache) with:

```properties
org.gradle.jvmargs=-Xmx4096m -XX:MaxMetaspaceSize=1024m -XX:ReservedCodeCacheSize=512m -Dfile.encoding=UTF-8
org.gradle.workers.max=4
org.gradle.parallel=true
org.gradle.caching=true
org.gradle.daemon=true
android.useAndroidX=true
# Keep Flutter AGP 8.11 / Kotlin 2.2 compatibility flags explicit until transitive
# plugins (camera_android_camerax, record_android, share_plus) migrate to AGP 9 DSL.
android.newDsl=false
android.builtInKotlin=false
```

**Guardrail:** Do **not** blindly flip `android.builtInKotlin=true` or `android.newDsl=true` unless `flutter build apk --release --target-platform android-arm64` succeeds cleanly against `camera_android_camerax`, `record_android`, and `share_plus`. Also check `app/build.gradle.kts#L10` (`buildToolsVersion = "36.0.0"`) — keep it consistent with installed SDK Build-Tools to avoid unnecessary re-downloads.

### 1.3 Supabase Auth Leaked Password Protection (`REQ-P76-PLAT-03`)

- **Project:** `cbnruevwrqwjnnoscgsz` (`Ndugelo-Code's vhunambi`, `eu-west-1`).
- **Target Remediation:** Enable **Prevent use of leaked passwords** (`password_hibp_enabled = true`) in Supabase Auth -> Attack Protection.
- **Verification:** Re-run `supabase_mcp:get_advisors(project_id: "cbnruevwrqwjnnoscgsz", type: "security")` in Stage 4 to confirm `auth_leaked_password_protection` clears (`0 WARN`), or if dashboard auth is required by the user, record the exact action item in the Stage 4 report without claiming it is enabled until `get_advisors` confirms it.

---

## 2. Pass 1 (`M76.2`) — Core Runtime Stability, Release Auth Security & Settings Glass

### 2.1 `apps/vhunambi_client/lib/main.dart` — Eliminate Navigator Unmount on Theme Switch (`BOOT-01`, `REQ-P76-CORE-01`)

**Current Defect (`main.dart#L118-L132`):**
```dart
      builder: (context, child) {
        final platformBrightness = MediaQuery.platformBrightnessOf(context);
        final effectiveBrightness = switch (themeMode) {
          ThemeMode.light => Brightness.light,
          ThemeMode.dark => Brightness.dark,
          ThemeMode.system => platformBrightness,
        };
        AppColors.syncWithBrightness(effectiveBrightness);

        return KeyedSubtree(
          key: ValueKey<Brightness>(effectiveBrightness),
          child: Stack(children: [?child, const MiniPlayerHost()]),
        );
      },
```

**Replacement Implementation:**
```dart
      builder: (context, child) {
        // Synchronize dynamic AppColors with active platform/theme brightness
        // without keying the Navigator subtree, so live Light <-> Dark toggles
        // preserve active modal drawers, pushed routes, and RootShell tab history.
        final platformBrightness = MediaQuery.platformBrightnessOf(context);
        final effectiveBrightness = switch (themeMode) {
          ThemeMode.light => Brightness.light,
          ThemeMode.dark => Brightness.dark,
          ThemeMode.system => platformBrightness,
        };
        AppColors.syncWithBrightness(effectiveBrightness);

        return Stack(children: [?child, const MiniPlayerHost()]);
      },
```

**Why this works cleanly:** `MaterialApp` already propagates `ThemeData` via `AnimatedTheme` down the widget tree whenever `themeMode` changes. Every widget calling `Theme.of(context)` or `AppColors.*Of(context)` subscribes to `Theme` `InheritedWidget` and repaints in place on the next frame without destroying `NavigatorState` or `_RootShellState`.

---

### 2.2 `apps/vhunambi_client/lib/core/auth/auth_providers.dart` — Compile-Time Release Gate (`AUTH-01`, `REQ-P76-CORE-02`)

Add `import 'package:flutter/foundation.dart' show kDebugMode;` and expose the canonical gate constant:

```dart
/// Compile-time security gate controlling demo studio creator quick-switching
/// (`REQ-P76-CORE-02`).
///
/// Always `true` in debug builds and `flutter test` (`kDebugMode == true`).
/// Always `false` in production `--release` APKs unless explicitly opted in via
/// `--dart-define=ENABLE_DEMO_CREATOR_SWITCH=true` for internal QA builds.
const bool kEnableDemoCreatorQuickSwitch =
    kDebugMode || bool.fromEnvironment('ENABLE_DEMO_CREATOR_SWITCH');
```

Update `AuthSessionNotifier.switchToSeededCreator` with an explicit optional `bool allowLocalFallbackOverride` (defaulting to `kEnableDemoCreatorQuickSwitch`) so unit tests can also assert the fail-closed release path directly:

```dart
  /// Switches to one of the seeded studio demo creators (`@cern`, `@makhadzi`, `@sigwa`, ...).
  ///
  /// Uses live `/api/auth/login` first; falls back deterministically ONLY when
  /// [kEnableDemoCreatorQuickSwitch] is enabled (debug / headless tests).
  /// Production `--release` builds fail closed with [SovereignAuthException].
  Future<SovereignAuthSession> switchToSeededCreator({
    required String handle,
    String? displayName,
    String password = defaultSeededPassword,
    bool allowDemoSwitch = kEnableDemoCreatorQuickSwitch,
  }) async {
    if (!allowDemoSwitch) {
      throw const SovereignAuthException(
        statusCode: 403,
        code: 'DEMO_SWITCH_DISABLED_IN_RELEASE',
        message:
            'Quick studio demo switching is disabled in release builds. '
            'Sign in with your creator credentials.',
      );
    }

    final prevCreatorId = state.canonicalCreatorId;
    try {
      return await signIn(identifier: handle, password: password);
    } on SovereignAuthException catch (e) {
      if (e.code != 'AUTH_OFFLINE' && e.statusCode != 503) {
        rethrow;
      }
    } catch (_) {
      // Network unreachable in debug/test: continue with local studio profile switch below.
    }

    final canonical = canonicalizeCreatorId(handle);
    final raw = extractRawCreatorId(canonical);
    final seeded = seededStudioCreators[raw];
    final resolvedDisplay =
        (displayName != null && displayName.trim().isNotEmpty)
        ? displayName.trim()
        : (seeded?.displayName ?? raw);
    final localSession = SovereignAuthSession(
      userId: 'usr_studio_$raw',
      creatorId: seeded?.creatorId ?? canonical,
      handle: handleFromCreatorId(canonical),
      displayName: resolvedDisplay,
      email: '$raw@vhunambi.za',
      role: 'creator',
      sessionId: 'studio_local_$raw',
      accessToken: '',
      refreshToken: '',
      expiresAt: null,
      isGuest: false,
    );

    if (prevCreatorId != localSession.canonicalCreatorId) {
      await SovereignHiveAccountSanitizer.purgeTenantPrivateBoxes(
        clearAuthSession: false,
      );
    }
    await _repo.saveSession(localSession);
    if (mounted) {
      state = localSession;
    }
    return localSession;
  }
```

---

### 2.3 `apps/vhunambi_client/lib/features/auth/presentation/widgets/sovereign_auth_sheet.dart` — Glass Chrome, Release Gate & `44dp` Buttons (`AUTH-01/02`, `REQ-P76-CORE-02/03`)

Key surgical changes (preserving every existing `Key('auth_*')` widget key):
1. Import `package:vhunambi_client/core/widgets/vhunambi_glass_surface.dart`.
2. Add optional `@visibleForTesting final bool? enableDemoQuickSwitchOverride;` constructor parameter (default `null`). Resolve `final showDemoQuickSwitch = widget.enableDemoQuickSwitchOverride ?? kEnableDemoCreatorQuickSwitch;`.
3. Update `SovereignAuthSheet.show(BuildContext context)` to pass `backgroundColor: Colors.transparent` and wrap the sheet body in:
   ```dart
   VhunambiGlassSurface(
     key: const Key('sovereign_auth_glass_surface'),
     variant: VhunambiGlassVariant.chrome,
     borderRadius: AppRadius.modalBorder,
     enableLiveBlur: false,
     borderColorOverride: AppColors.borderSubtleOf(context),
     child: SafeArea(
       top: false,
       child: SingleChildScrollView( ... ),
     ),
   )
   ```
4. Wrap the `[Sign In | Create Account]` segmented mode bar in `VhunambiGlassSurface(variant: VhunambiGlassVariant.pill, height: 44, padding: const EdgeInsets.all(4), enableLiveBlur: false, ...)`.
5. Guard the `QUICK STUDIO CREATORS` block with `if (showDemoQuickSwitch) ...[ ... ]`.
6. Wrap `Key('auth_error_banner')` in `VhunambiGlassSurface(key: const Key('auth_error_banner'), variant: VhunambiGlassVariant.card, borderRadius: AppRadius.inputBorder, padding: const EdgeInsets.all(10), tintAccent: AppColors.error, borderColorOverride: AppColors.error.withValues(alpha: 0.45), enableLiveBlur: false, ...)`.
7. Upgrade Close `IconButton` and password eye `IconButton` with `constraints: const BoxConstraints(minWidth: 44, minHeight: 44)` and explicit `color: AppColors.textPrimaryOf(context)` / `AppColors.textSecondaryOf(context)`.

---

### 2.4 `ProfileSettingsDrawer` & Child Settings Cards (`SET-01`, `SET-02`, `REQ-P76-CORE-04`)

#### A. `apps/vhunambi_client/lib/features/profile/presentation/widgets/profile_settings_drawer.dart`
1. `ProfileSettingsDrawer.show(BuildContext context)`:
   ```dart
   static Future<void> show(BuildContext context) {
     return showModalBottomSheet<void>(
       context: context,
       isScrollControlled: true,
       backgroundColor: Colors.transparent,
       builder: (_) => const ProfileSettingsDrawer(),
     );
   }
   ```
2. Root widget inside `build(...)`: wrap `SafeArea` inside `VhunambiGlassSurface(key: const Key('profile_settings_glass_surface'), variant: VhunambiGlassVariant.chrome, borderRadius: AppRadius.modalBorder, enableLiveBlur: false, borderColorOverride: AppColors.borderSubtleOf(context), child: ...)`.
3. Convert **every** static `AppColors.*` reference across lines 54–504 to `*Of(context)`:
   - Drag handle: `AppColors.textSecondaryOf(context).withValues(alpha: 0.32)`.
   - Header title `'Appearance & Preferences'`: `color: AppColors.textPrimaryOf(context)`.
   - Close `IconButton`: `constraints: const BoxConstraints(minWidth: 44, minHeight: 44)`, icon `PhosphorIcon(AppIcons.close, size: 20, color: AppColors.textPrimaryOf(context))`.
   - Section labels (`'APPLICATION THEME'`, `'AUDIO ENGINE SPECIFICATIONS'`, `'EDGE-SYNC & OFFLINE OUTBOX'`, etc.): `color: AppColors.textSecondaryOf(context)`.
   - 3-way Theme Mode pill container: `VhunambiGlassSurface(variant: VhunambiGlassVariant.pill, height: 46, padding: const EdgeInsets.all(4), enableLiveBlur: false, borderColorOverride: AppColors.borderSubtleOf(context), ...)`.
   - `_buildThemeOption` (`#L455-L504`):
     ```dart
     final foreground = isSelected
         ? AppColors.brandContrast
         : AppColors.textPrimaryOf(context);
     ```
     (Fixes Light-Mode ghost text where `#F8FAFC` rendered on `#FFFFFF`!)
   - Audio Engine Specs card & Edge-Sync card: `VhunambiGlassSurface(variant: VhunambiGlassVariant.card, padding: const EdgeInsets.all(12), enableLiveBlur: false, ...)`.
   - Status pills (Pending/Dead-Letter/Latency): `AppColors.surfaceSecondaryOf(context)` + `AppColors.borderSubtleOf(context)` + `AppColors.textPrimaryOf(context)` / `AppColors.textSecondaryOf(context)`.
   - `Key('settings_sync_now_btn')`: raise `minimumSize: const Size(0, 44)` (from `36`).

#### B. Child Cards (`account_identity_security_card.dart`, `hive_brain_telemetry_card.dart`, `cloud_stack_diagnostic_card.dart`)
- Wrap each card's outer `Container` in `VhunambiGlassSurface(variant: VhunambiGlassVariant.card, padding: const EdgeInsets.all(12), enableLiveBlur: false, borderColorOverride: AppColors.borderSubtleOf(context), ...)`.
- Audit all nested labels/icons/borders to ensure `*Of(context)` tokens are used (no static `AppColors.textPrimary`, `AppColors.surfaceElevated`, or `AppColors.borderSubtle`).
- In `hive_brain_telemetry_card.dart#L240,270`: raise `Key('hive_compact_now_btn')` and `Key('hive_sync_now_btn')` `minimumSize` from `const Size(0, 36)` to `const Size(0, 44)`.

---

## 3. Pass 2 (`M76.3`) — Full Notification Deep-Link Coverage & Bell Popover Glass

### 3.1 `apps/vhunambi_client/lib/features/notifications/presentation/utils/notification_deep_link_router.dart` (`DL-02`, `DL-03`)

Complete, compilable replacement implementation for `NotificationDeepLinkRouter`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/navigation/navigation_providers.dart';
import 'package:vhunambi_client/core/navigation/profile_navigation_helper.dart';
import 'package:vhunambi_client/core/utils/creator_id_utils.dart';
import 'package:vhunambi_client/features/explore/domain/models/social_music_post.dart';
import 'package:vhunambi_client/features/explore/presentation/providers/explore_providers.dart';
import 'package:vhunambi_client/features/explore/presentation/views/kinetic_post_focus_view.dart';
import 'package:vhunambi_client/features/home/presentation/widgets/subscription_upgrade_modal.dart';
import 'package:vhunambi_client/features/library/domain/models/library_models.dart';
import 'package:vhunambi_client/features/library/presentation/providers/library_providers.dart';
import 'package:vhunambi_client/features/marketplace/domain/models/licensing_models.dart';
import 'package:vhunambi_client/features/marketplace/presentation/providers/beat_checkout_provider.dart';
import 'package:vhunambi_client/features/marketplace/presentation/widgets/license_certificate_sheet.dart';
import 'package:vhunambi_client/features/profile/presentation/widgets/creator_dna_helix_lab_sheet.dart';
import 'package:vhunambi_client/features/social/domain/models/published_clip.dart';
import 'package:vhunambi_client/features/social/presentation/providers/social_feed_provider.dart';
import 'package:vhunambi_client/features/social/presentation/widgets/kinetic_reels_modal.dart';
import 'package:vhunambi_client/features/track/presentation/views/track_detail_view.dart';
import '../../domain/models/notification_entity.dart';
import '../widgets/notification_detail_bottom_sheet.dart';

/// Deterministic deep-link router for notification cards, Bell Popover & CTAs
/// (`EP-P67-DEEPLINK-ROUTER`, extended in `Phase 76` `EP-P76-DEEPLINK-COVERAGE`).
abstract final class NotificationDeepLinkRouter {
  /// Primary entry point when a user taps a notification card.
  /// Opens [NotificationDetailBottomSheet] for milestone/informational alerts
  /// or routes directly when targeting a specific media/entity screen.
  static Future<void> handleCardTap(
    BuildContext context,
    WidgetRef ref,
    NotificationEntity notification,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (notification.opensDetailSheetFirst) {
      await NotificationDetailBottomSheet.show(context, notification);
      return;
    }
    await navigateDirect(context, ref, notification);
  }

  /// Executes direct navigation for [notification.effectiveRoute], falling back
  /// to [NotificationDetailBottomSheet] so zero taps are silent no-ops.
  static Future<void> navigateDirect(
    BuildContext context,
    WidgetRef ref,
    NotificationEntity notification,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final route = notification.effectiveRoute?.trim();
    if (route == null || route.isEmpty) {
      await NotificationDetailBottomSheet.show(context, notification);
      return;
    }

    // 1. Core RootShell tab destinations
    final tabDestination = _resolveShellTabIndex(route);
    if (tabDestination != null) {
      ref.read(appNavigationTabProvider.notifier).state = tabDestination;
      if (context.mounted) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
      return;
    }

    // 2. Creator DNA & Wallet modals
    if (route == '/creator-dna') {
      await CreatorDnaHelixLabSheet.show(context);
      return;
    }
    if (route == '/wallet') {
      await SubscriptionUpgradeModal.show(context);
      return;
    }

    // 3. Track Cockpit
    if (route.startsWith('/track/')) {
      final trackId = route.substring('/track/'.length).trim();
      if (trackId.isNotEmpty) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TrackDetailView(trackId: trackId),
          ),
        );
        return;
      }
    }

    // 4. Kinetic Reels (with cold-start hydration + metadata fallback, REQ-P76-DL-02)
    if (route.startsWith('/reel/')) {
      final clipId = route.substring('/reel/'.length).trim();
      var clips = ref.read(socialFeedProvider).clips;
      if (clips.isEmpty) {
        await ref.read(socialFeedProvider.notifier).refreshFeed();
        if (!context.mounted) return;
        clips = ref.read(socialFeedProvider).clips;
      }
      if (clips.isEmpty && clipId.isNotEmpty) {
        clips = <PublishedClip>[
          _buildFallbackReelClip(clipId, notification),
        ];
      }
      if (clips.isNotEmpty) {
        await KineticReelsModal.show(
          context,
          clips: clips,
          initialClipId: clipId.isEmpty ? null : clipId,
        );
        return;
      }
    }

    // 5. Kinetic Post Focus
    if (route.startsWith('/post/')) {
      final postId = route.substring('/post/'.length).trim();
      if (postId.isNotEmpty) {
        final posts = ref.read(socialFeedPostsProvider);
        SocialMusicPost? matched;
        for (final p in posts) {
          if (p.id == postId) {
            matched = p;
            break;
          }
        }
        await KineticPostFocusView.show(
          context,
          postId: postId,
          initialPost: matched,
        );
        return;
      }
    }

    // 6. Cryptographic License Certificates (/license/:id, /certificate/:id)
    if (route.startsWith('/license/') || route.startsWith('/certificate/')) {
      final certId = route.startsWith('/license/')
          ? route.substring('/license/'.length).trim()
          : route.substring('/certificate/'.length).trim();
      if (certId.isNotEmpty) {
        final cert = _findLicenseCertificate(ref, certId, notification);
        if (cert != null) {
          await showLicenseCertificateSheet(context, certificate: cert);
          return;
        }
        final track = _findLicensedLibraryTrack(ref, certId, notification);
        if (track != null) {
          await showLicenseCertificateSheet(context, track: track);
          return;
        }
        // Certificate not cached locally yet -> jump cleanly into Asset Vault tab.
        ref.read(appNavigationTabProvider.notifier).state = 3;
        if (context.mounted) {
          Navigator.of(context).popUntil((r) => r.isFirst);
        }
        return;
      }
    }

    // 7. Profiles (/profile, /profile/:id, /creator/:id, /@:handle)
    if (route == '/profile') {
      final activeCreatorId = ref.read(currentCreatorIdProvider);
      await navigateToCreatorProfile(
        context,
        ref,
        creatorId: activeCreatorId,
      );
      return;
    }

    if (route.startsWith('/profile/')) {
      final creatorId = route.substring('/profile/'.length).trim();
      if (creatorId.isNotEmpty) {
        await navigateToCreatorProfile(context, ref, creatorId: creatorId);
        return;
      }
    }

    if (route.startsWith('/creator/')) {
      final artistId = route.substring('/creator/'.length).trim();
      if (artistId.isNotEmpty) {
        await navigateToCreatorProfile(context, ref, creatorId: artistId);
        return;
      }
    }

    if (route.startsWith('/@')) {
      final rawHandle = route.substring('/@'.length).trim();
      if (rawHandle.isNotEmpty) {
        final normalizedHandle = rawHandle.startsWith('@')
            ? rawHandle
            : '@$rawHandle';
        await navigateToCreatorProfile(
          context,
          ref,
          creatorId: canonicalizeCreatorId(rawHandle),
          creatorHandle: normalizedHandle,
        );
        return;
      }
    }

    await NotificationDetailBottomSheet.show(context, notification);
  }

  static int? _resolveShellTabIndex(String route) {
    return switch (route) {
      '/home' => 0,
      '/explore' => 1,
      '/studio' => 2,
      '/library' || '/vault' || '/licenses' => 3,
      '/marketplace' || '/market' => 4,
      _ => null,
    };
  }

  static SovereignLicenseCertificate? _findLicenseCertificate(
    WidgetRef ref,
    String certId,
    NotificationEntity notification,
  ) {
    final certs = ref.read(licenseCertificatesProvider);
    final metaCertId = (notification.metadata['certificateId'] as String?)?.trim();
    final metaVaultTrackId =
        (notification.metadata['vaultTrackId'] as String?)?.trim();
    for (final c in certs) {
      if (c.certificateId == certId ||
          (metaCertId != null && c.certificateId == metaCertId) ||
          c.vaultTrackId == certId ||
          c.beatId == certId ||
          (metaVaultTrackId != null && c.vaultTrackId == metaVaultTrackId)) {
        return c;
      }
    }
    return null;
  }

  static LibraryTrack? _findLicensedLibraryTrack(
    WidgetRef ref,
    String certId,
    NotificationEntity notification,
  ) {
    final tracks = ref.read(libraryTracksProvider);
    final metaVaultTrackId =
        (notification.metadata['vaultTrackId'] as String?)?.trim();
    for (final t in tracks) {
      if (t.licenseCertificateIdOverride == certId ||
          t.licenseCertificateId == certId ||
          t.id == certId ||
          (metaVaultTrackId != null && t.id == metaVaultTrackId)) {
        return t;
      }
    }
    return null;
  }

  static PublishedClip _buildFallbackReelClip(
    String clipId,
    NotificationEntity notification,
  ) {
    final meta = notification.metadata;
    final creatorId = (meta['creatorId'] as String?)?.trim();
    final creatorName = (meta['creatorName'] as String?)?.trim();
    final creatorHandle = (meta['creatorHandle'] as String?)?.trim();
    final title = (meta['title'] as String?)?.trim();
    final genre = (meta['genre'] as String?)?.trim();
    return PublishedClip(
      id: clipId,
      creatorId: (creatorId != null && creatorId.isNotEmpty)
          ? creatorId
          : 'creator_vhunambi',
      creatorName: (creatorName != null && creatorName.isNotEmpty)
          ? creatorName
          : 'Vhunambi Creator',
      creatorHandle: (creatorHandle != null && creatorHandle.isNotEmpty)
          ? creatorHandle
          : '@creator',
      title: (title != null && title.isNotEmpty) ? title : notification.title,
      caption: notification.message,
      genre: (genre != null && genre.isNotEmpty) ? genre : 'Amapiano',
      audioUrl: (meta['audioUrl'] as String?) ?? '',
      videoUrl: meta['videoUrl'] as String?,
      publishedAt: notification.createdAt,
    );
  }
}
```

*(Stage 4 Verification Note: Check `PublishedClip` exact required constructor fields in `apps/vhunambi_client/lib/features/social/domain/models/published_clip.dart` before finalizing `_buildFallbackReelClip` so every required field matches 100%.)*

---

### 3.2 `apps/vhunambi_client/lib/features/notifications/presentation/widgets/notification_detail_bottom_sheet.dart`

Update `_defaultCtaLabel(String? route)` (`#L206-L215`):

```dart
  String _defaultCtaLabel(String? route) {
    if (route == null) return 'Done';
    if (route == '/home') return 'Go to Home';
    if (route == '/explore') return 'Explore Feed';
    if (route.startsWith('/studio')) return 'Open Studio Cockpit';
    if (route == '/library' || route == '/vault' || route == '/licenses') {
      return 'Open Asset Vault';
    }
    if (route == '/marketplace' || route == '/market') {
      return 'Open Marketplace';
    }
    if (route.startsWith('/creator-dna')) return 'Calibrate Creator DNA';
    if (route.startsWith('/wallet')) return 'View Balance & Usage';
    if (route.startsWith('/track/')) return 'Open Track Cockpit';
    if (route.startsWith('/reel/')) return 'Watch Kinetic Reel';
    if (route.startsWith('/post/')) return 'View Kinetic Post';
    if (route.startsWith('/license/') || route.startsWith('/certificate/')) {
      return 'View License Deed';
    }
    if (route == '/profile') return 'Open My Profile';
    if (route.startsWith('/profile/') ||
        route.startsWith('/creator/') ||
        route.startsWith('/@')) {
      return 'View Creator Profile';
    }
    return 'Continue';
  }
```

### 3.3 `apps/vhunambi_client/lib/features/marketplace/presentation/providers/beat_checkout_provider.dart`

Enhance lines `#L367-L379` so real Marketplace license purchases emit a deep-linkable certificate alert:

```dart
      _ref
          .read(notificationsProvider.notifier)
          .addNotification(
            NotificationEntity(
              id: 'notif_mkt_${nowUtc.millisecondsSinceEpoch}',
              title: 'Marketplace License Acquired!',
              message:
                  'Unlocked "${beat.title}" (${tier.displayName}) — Certificate ${cert.certificateId} & 44.1 kHz assets saved to Vault.',
              category: NotificationCategory.creatorActivity,
              priority: NotificationPriority.high,
              subtype: 'license_acquired',
              targetRoute: '/license/${cert.certificateId}',
              targetEntityId: cert.certificateId,
              ctaLabel: 'View License Deed',
              metadata: <String, dynamic>{
                'certificateId': cert.certificateId,
                'vaultTrackId': vaultTrackId,
                'beatId': beat.id,
                'beatTitle': beat.title,
                'tier': tier.displayName,
              },
              createdAt: nowUtc.toLocal(),
            ),
          );
```

### 3.4 `apps/vhunambi_client/lib/features/notifications/presentation/widgets/notifications_popover.dart` + Light/Dark Notifications Polish (`DL-01`, `NOTIF-UI-01`)

1. **Bell Popover Delegation (`_openNotification`):**
   ```dart
   void _openNotification(
     BuildContext context,
     WidgetRef ref,
     NotificationsNotifier notifier,
     NotificationEntity notification,
   ) {
     final navigator = Navigator.of(context);
     final hostContext = navigator.context;
     final effectiveRoute = notification.effectiveRoute;

     notifier.markAsRead(notification.id);
     navigator.pop();

     if (effectiveRoute == null || effectiveRoute.isEmpty) {
       return;
     }

     NotificationDeepLinkRouter.handleCardTap(hostContext, ref, notification);
   }
   ```
   **Why this satisfies both `DL-01` and `TRAP-76-03`:**
   - Bare alerts like `notif_b` (`targetTrackId: null`, `targetRoute: null`) return immediately after marking read and popping -> `notifications_popover_test.dart` stays 100% green.
   - Track alerts (`targetTrackId: 'seed-01'` -> `effectiveRoute == '/track/seed-01'`, `opensDetailSheetFirst == false`) push `TrackDetailView(trackId: 'seed-01')` directly -> `notifications_popover_test.dart` stays 100% green.
   - Every Reel (`/reel/:id`), Post (`/post/:id`), License (`/license/:id`), Profile (`/profile`, `/@:handle`), Creator DNA, Wallet, Studio, and Vault alert now routes cleanly through `NotificationDeepLinkRouter`!
2. **Popover Glass & Dual-Theme:**
   - Wrap outer container in `VhunambiGlassSurface(key: const Key('notifications_popover_glass'), variant: VhunambiGlassVariant.chrome, borderRadius: BorderRadius.circular(16), enableLiveBlur: false, borderColorOverride: AppColors.borderSubtleOf(context), ...)`.
   - Convert all static `AppColors.{surfaceModal,surfaceElevated,surfaceSecondary,borderSubtle,textPrimary,textSecondary}` in `notifications_popover.dart`, `notifications_view.dart`, `notification_search_bar.dart`, and `notification_empty_state.dart` to `AppColors.*Of(context)`.
   - Replace `'View All Alerts in Center ➔'` (`notifications_popover.dart#L183`) with:
     ```dart
     Row(
       mainAxisAlignment: MainAxisAlignment.center,
       mainAxisSize: MainAxisSize.min,
       children: [
         Text(
           'View All Alerts in Center',
           style: AppTypography.caption.copyWith(
             color: AppColors.brandContrast,
             fontWeight: FontWeight.w700,
           ),
         ),
         const SizedBox(width: 6),
         const PhosphorIcon(
           AppIcons.arrowRight,
           size: 14,
           color: AppColors.brandContrast,
         ),
       ],
     )
     ```
   - Preserve `PhosphorIconsRegular.bellSlash` in `_EmptyNotificationsState` and `AppIcons.close` on each card's dismiss control (`notifications_popover_test.dart#L118,187`).

---

## 4. Pass 2 (`M76.4`) — Onboarding `STD-UIUX-001` & Dual-Theme Glass Polish

### 4.1 `RoleOption` Backward-Compatible Phosphor Upgrade (`role_carousel_widget.dart`, `ONB-03`, `TRAP-76-02`)

```dart
@immutable
class RoleOption {
  final CreativeRole role;
  final String label;

  /// Deprecated legacy emoji string kept optional so historical tests compile;
  /// never rendered in production UI (`STD-UIUX-001`).
  final String emoji;

  /// Explicit Phosphor vector icon override. Falls back to [_defaultIconForRole].
  final IconData? icon;
  final String description;

  const RoleOption({
    required this.role,
    required this.label,
    this.emoji = '',
    this.icon,
    required this.description,
  });

  IconData get resolvedIcon => icon ?? _defaultIconForRole(role);

  static IconData _defaultIconForRole(CreativeRole role) {
    return switch (role) {
      CreativeRole.producer => AppIcons.beatstore,
      CreativeRole.vocalist => AppIcons.vocals,
      CreativeRole.songwriter => AppIcons.edit,
      CreativeRole.dj => AppIcons.releases,
      CreativeRole.listener => PhosphorIconsFill.headphones,
      CreativeRole.artist => AppIcons.songs,
      _ => AppIcons.sparkle,
    };
  }
}
```

*(Stage 4 Verification Note: Read `apps/vhunambi_client/lib/features/creator_dna/domain/entities/creator_dna_profile.dart` to match exact `CreativeRole` enum values cleanly without dead default branches!)*

Inside `RoleCarouselWidget`:
- Wrap each role card in `VhunambiGlassSurface(variant: VhunambiGlassVariant.card, enableLiveBlur: false, tintAccent: isSelected ? AppColors.brandPrimary : null, borderColorOverride: isSelected || isCenter ? AppColors.brandPrimary : AppColors.borderSubtleOf(context), borderWidth: isSelected || isCenter ? 2.0 : 1.0, ...)`.
- Render `PhosphorIcon(role.resolvedIcon, size: 22, color: isSelected || isCenter ? AppColors.brandPrimary : AppColors.textPrimaryOf(context))` inside a `40x40` rounded tinted badge instead of `Text(role.emoji)`.
- Replace `Icon(Icons.check_circle, ...)` with `const PhosphorIcon(AppIcons.checkCircle, color: AppColors.brandPrimary, size: 20)`.
- Use `AppColors.textPrimaryOf(context)` and `AppColors.textSecondaryOf(context)`.

### 4.2 `app_tour_overlay.dart` (`ONB-02`, `TRAP-76-05`)

- Import `package:phosphor_icons/phosphor_icons.dart`, `package:vhunambi_client/core/design_system/tokens/app_icons.dart`, and `package:vhunambi_client/core/widgets/vhunambi_glass_surface.dart`.
- Replace all 5 `Icons.*` on `_cards`:
  1. `'Compose'`: `AppIcons.sparkle`
  2. `'Write Lyrics First'`: `AppIcons.edit`
  3. `'Voice'`: `AppIcons.mic`
  4. `'Crate & MPC'`: `AppIcons.songs`
  5. `'Credits & Library'`: `PhosphorIconsRegular.folder`
- Replace `Icon(card.icon, size: 48, color: AppColors.brandPrimary)` with `PhosphorIcon(card.icon, size: 48, color: AppColors.brandPrimary)`.
- Replace `Scaffold(backgroundColor: AppColors.surfaceCanvas)` with `AppColors.surfaceCanvasOf(context)`.
- Replace the `140x140` preview box with `VhunambiGlassSurface(width: 164, height: 152, padding: const EdgeInsets.all(14), tintAccent: AppColors.brandPrimary, enableLiveBlur: false, ...)`.
- Convert all `AppColors.textPrimary` / `textSecondary` / `borderSubtle` to `*Of(context)` and keep all 5 card titles, `AnimatedContainer` indicator dots, and keys (`app_tour_skip`, `app_tour_continue`, `app_tour_get_started`) intact.

### 4.3 `genre_color_chip.dart` & `mood_color_chip.dart` (`ONB-04`, `TRAP-76-06`)

- In `genre_color_chip.dart`:
  - Replace `Icon(Icons.check_circle, color: accent, size: 18)` with `PhosphorIcon(AppIcons.checkCircle, color: accent, size: 18)`.
  - Use `AppColors.surfaceElevatedOf(context)`, `AppColors.borderSubtleOf(context)`, and `AppColors.textPrimaryOf(context)` while maintaining `constraints: const BoxConstraints(minHeight: 44, minWidth: 44)` and existing `Semantics` wrapper.
- In `mood_color_chip.dart`:
  - Convert static `AppColors.surfaceElevated`, `AppColors.borderSubtle`, and `AppColors.textPrimary` to `*Of(context)`.

### 4.4 `creator_dna_helix_finale.dart`, `onboarding_act3_roots_deck.dart`, `onboarding_act1_showcase.dart`, `interactive_identity_card_stack.dart`, `onboarding_view.dart` (`ONB-01`, `ONB-05`, `ONB-06`)

- **`onboarding_view.dart`:** Replace static `AppColors.surfaceCanvas` / `AppColors.textSecondary` / `Colors.white` / `Colors.white24` / `Colors.black12` with `AppColors.surfaceCanvasOf(context)`, `AppColors.textSecondaryOf(context)`, `AppColors.borderSubtleOf(context)`, and `AppColors.brandContrast`.
- **`creator_dna_helix_finale.dart`:**
  - Replace `'🔒 Quest: ${node.questInstruction}'` (`#L465`) with a `Row` containing `PhosphorIcon(PhosphorIconsBold.lock, size: 12, color: accent)` + `const SizedBox(width: 6)` + `Expanded(child: Text('Quest: ${node.questInstruction}', ...))`.
  - Replace hardcoded `Color(0xFF15151D)` / `Colors.white` card fill (`#L338`) with `VhunambiGlassSurface(variant: VhunambiGlassVariant.card, enableLiveBlur: false, ...)` + `AppColors.*Of(context)`.
- **`onboarding_act3_roots_deck.dart`:**
  - Replace `'✨ Era Match'` (`#L516`) with a `Row(mainAxisSize: MainAxisSize.min, children: [PhosphorIcon(AppIcons.sparkle, size: 10, color: ...), const SizedBox(width: 4), Text('Era Match', ...)])`.
  - Replace hardcoded `Color(0xFF141418)` / `Color(0xFF16161C)` / `Colors.white` card containers with `VhunambiGlassSurface(enableLiveBlur: false)` + `AppColors.*Of(context)`.
- **`onboarding_act1_showcase.dart` & `interactive_identity_card_stack.dart`:**
  - Replace hardcoded `Color(0xFF14141A)` / `Color(0xFF1C1C24)` / `Colors.white` / `Colors.grey.shade100` card fills with `VhunambiGlassSurface(enableLiveBlur: false)` and `AppColors.surfaceModalOf(context)` / `AppColors.surfaceElevatedOf(context)` / `AppColors.textPrimaryOf(context)` / `AppColors.textSecondaryOf(context)`.

---

## 5. Dedicated Phase 76 Regression Test Suite (`test/features/phase76_auth_onboarding_deeplink_polish_test.dart`)

Must cover all 6 deterministic verification groups using bounded `tester.pump(const Duration(milliseconds: ...))` loops (`--timeout=60s` safe):

1. **Theme Toggle Navigator Preservation (`REQ-P76-CORE-01`):**
   - Mount `VhunambiApp(initialHome: const _ThemeTestHost())` inside `ProviderScope`.
   - Open `ProfileSettingsDrawer.show(context)`.
   - Tap `Key('theme_mode_light')`, then `Key('theme_mode_dark')`, then `Key('theme_mode_system')`.
   - Assert `find.byType(ProfileSettingsDrawer)` remains mounted (`findsOneWidget`) across every brightness transition!
2. **Release-Mode Demo Quick-Switch Gate (`REQ-P76-CORE-02`):**
   - Render `SovereignAuthSheet(enableDemoQuickSwitchOverride: false)` -> assert `find.text('QUICK STUDIO CREATORS')` `findsNothing` and `find.byKey(const Key('auth_quick_chip_makhadzi'))` `findsNothing`.
   - Call `AuthSessionNotifier.switchToSeededCreator(handle: '@makhadzi', allowDemoSwitch: false)` -> throws `SovereignAuthException` with `code == 'DEMO_SWITCH_DISABLED_IN_RELEASE'` and `statusCode == 403`.
   - Render `SovereignAuthSheet(enableDemoQuickSwitchOverride: true)` -> assert `VhunambiGlassSurface` present and quick chips visible.
3. **ProfileSettingsDrawer Light Mode Glass & `44dp` Touch Targets (`REQ-P76-CORE-04`):**
   - Render `ProfileSettingsDrawer` under `AppTheme.lightTheme`.
   - Verify `find.byKey(const Key('profile_settings_glass_surface'))` finds `VhunambiGlassSurface`.
   - Verify `settings_sync_now_btn`, `hive_compact_now_btn`, `hive_sync_now_btn` height `>= 44.0`.
4. **NotificationDeepLinkRouter Full Coverage (`REQ-P76-DL-02`, `REQ-P76-DL-03`):**
   - `/reel/clip_cold_99` with empty `SocialFeedNotifier` -> hydrates/synthesizes and launches `KineticReelsModal`.
   - `/license/CERT-P76-001` with seeded `SovereignLicenseCertificate` -> opens `LicenseCertificateSheet` showing `'Sovereign License Deed'`.
   - `/profile`, `/profile/creator_makhadzi`, `/@makhadzi` -> pushes `OwnerProfileView` (for self) and `ArtistProfileView` (for visitor).
   - `/home`, `/explore`, `/studio`, `/vault`, `/licenses`, `/marketplace` -> mutates `appNavigationTabProvider` to `0, 1, 2, 3, 3, 4`.
5. **Bell Popover Delegation (`REQ-P76-DL-01`, `REQ-P76-DL-04`):**
   - Open `NotificationsPopover` with a `/license/CERT-P76-001` alert and a `/studio` alert.
   - Tapping `/studio` alert marks read, dismisses popover, and updates `appNavigationTabProvider` to `2`.
   - Verify `VhunambiGlassSurface` wraps popover and `'View All Alerts in Center'` renders without `'➔'`.
6. **Onboarding `STD-UIUX-001` & Light/Dark Glass (`REQ-P76-ONB-01/02`):**
   - Render `AppTourOverlay`, `RoleCarouselWidget`, and `GenreColorChip` under `AppTheme.lightTheme`.
   - Assert zero `Icon` widgets using Material `Icons.*` fontFamily (`'MaterialIcons'`), presence of `PhosphorIcon` and `VhunambiGlassSurface`, and `RoleOption(role: CreativeRole.producer, label: 'Producer', emoji: '...', description: '...')` renders `PhosphorIcon` without displaying the emoji string.
