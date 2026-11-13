# Phase 65: Foundation Stability, Crash Immunity & 5-Layer Fault-Containment Architecture — Tasks

**Document ID**: `VHUNAMBI-SPEC-P65-TASKS-V1`  
**Phase**: `Phase 65`  
**Status**: `APPROVED FOR STAGE 4 EXECUTION (/vhunambi-executioner)`  
**Audit Reference**: `docs/audits/PHASE65_FOUNDATION_STABILITY_AND_ERROR_HANDLING_AUDIT.md`  
**Companion Specifications**: `blueprint.md` (`VHUNAMBI-SPEC-P65-BLUEPRINT-V1`), `requirements.md` (`VHUNAMBI-SPEC-P65-REQUIREMENTS-V1`), `design.md` (`VHUNAMBI-SPEC-P65-DESIGN-V1`)  
**Target Branch**: `fix/studio-cockpit-bugs-vh001-vh006`  
**Target Physical Device**: `EPHUT20917014649` (`Huawei JNY_LX1`)

---

## 1. Master Milestone Roadmap & Dependency Graph

```text
+---------------------------------------------------------------------------------------------------+
| PHASE 65 MASTER EXECUTION ROADMAP (M65.1 -> M65.5)                                                |
+---------------------------------------------------------------------------------------------------+
|                                                                                                   |
|  [M65.1: Layer 1 — Native Android Notification Fix & VhunambiCrashShield]                         |
|     |-- Task 65.1.1: Create drawable/ic_stat_music.xml & update AndroidManifest.xml (P1-01)       |
|     |-- Task 65.1.2: Author VhunambiCrashShield, BreadcrumbBuffer, ProviderObserver & SafeCard    |
|     +-- Task 65.1.3: Wire VhunambiCrashShield.run() & guardStartup() in main.dart (P1-02..P1-06)  |
|                                      |                                                            |
|                                      v                                                            |
|  [M65.2: Layer 2 — SafeAudioOrchestrator & Duration/Ticker State Machine]                         |
|     |-- Task 65.2.1: Author SafeAudioOrchestrator hardware audio slot mutex (P2-01, P2-06)        |
|     |-- Task 65.2.2: Wire VhunambiAudioHandler, JustAudioMultiStemEngine, ReelPool & Sketchpad    |
|     +-- Task 65.2.3: Fix eager 5-player preload, paused track_default_1, durationStream & ticker  |
|                                      |                                                            |
|                                      v                                                            |
|  [M65.3: Layer 3 — SafeNotifierMixin, 14 Async Notifiers & SafeNetworkAvatar]                     |
|     |-- Task 65.3.1: Unify _RootShellState with appNavigationTabProvider & modal safety (P3-01)   |
|     |-- Task 65.3.2: Author SafeNotifierMixin & apply mounted guards to 14 async StateNotifiers   |
|     +-- Task 65.3.3: Author SafeNetworkAvatar & replace unguarded Image.network calls (P2-07)     |
|                                      |                                                            |
|                                      v                                                            |
|  [M65.4: Layer 4 — JsonSafe, Per-Record Hive Quarantine, WS Timeout & DioException Mapping]       |
|     |-- Task 65.4.1: Author JsonSafe & refactor SovereignDomainRepositories / HttpSocialRepository|
|     +-- Task 65.4.2: Harden GenerationSocketService (8s timeout + atomic teardown) & ErrorHandler |
|                                      |                                                            |
|                                      v                                                            |
|  [M65.5: Layer 5 — Backend GlobalErrorBoundary, True PNG/WAV Parity, Studio Fidelity & Gates]     |
|     |-- Task 65.5.1: Register app.onError & app.notFound on Hono router in server.ts (P5-01)      |
|     |-- Task 65.5.2: Implement RFC-2083 PNG cover synth & 24s stereo WAV tiling (P5-02, P5-03)    |
|     |-- Task 65.5.3: Enforce StudioFormState priority in Enhance, non-echoing lyrics & GPU logs   |
|     +-- Task 65.5.4: Execute Vitest + Flutter test suites, deploy Worker, install APK & verify    |
|                                                                                                   |
+---------------------------------------------------------------------------------------------------+
```

| Milestone | Layer | Tasks | Primary Requirements Covered | Verification Gate |
| :--- | :--- | :--- | :--- | :--- |
| **`M65.1`** | Layer 1 — Native Android & Root Isolate | `65.1.1` – `65.1.3` | `REQ-P65-L1-01` .. `REQ-P65-L1-04` | `G-65-01`, `G-65-05` |
| **`M65.2`** | Layer 2 — Hardware Audio Mutex & Playback | `65.2.1` – `65.2.3` | `REQ-P65-L2-01` .. `REQ-P65-L2-04` | `G-65-02`, `G-65-05` |
| **`M65.3`** | Layer 3 — Riverpod Notifier & Widget Safety | `65.3.1` – `65.3.3` | `REQ-P65-L2-05`, `REQ-P65-L3-01` .. `REQ-P65-L3-04`, `REQ-P65-NFR-01`, `REQ-P65-NFR-03` | `G-65-03`, `G-65-05` |
| **`M65.4`** | Layer 4 — Network, WS & Storage Resilience | `65.4.1` – `65.4.2` | `REQ-P65-L4-01` .. `REQ-P65-L4-04` | `G-65-05` |
| **`M65.5`** | Layer 5 — Backend API, Studio Fidelity & Verification | `65.5.1` – `65.5.4` | `REQ-P65-L5-01` .. `REQ-P65-L5-05`, `REQ-P65-NFR-02` | `G-65-04`, `G-65-05`, `G-65-06` |

---

## 2. Milestone M65.1: Layer 1 — Native Android Notification Fix & `VhunambiCrashShield`

### [x] Task 65.1.1: Create `drawable/ic_stat_music.xml` & Register Default Notification Icon in `AndroidManifest.xml`
- **Audit Findings Resolved**: `P1-01` (All 7 physical device crashes on `JNY_LX1` caused by `java.lang.IllegalArgumentException: Invalid notification (no valid small icon)` in `AudioService.updateNotification`).
- **Requirements**: `REQ-P65-L1-01`
- **Design Reference**: `design.md` §1.1, §1.2
- **Target Files**:
  - `[NEW]` `apps/vhunambi_client/android/app/src/main/res/drawable/ic_stat_music.xml`
  - `[MOD]` `apps/vhunambi_client/android/app/src/main/AndroidManifest.xml`
- **Implementation Instructions**:
  1. Create `apps/vhunambi_client/android/app/src/main/res/drawable/ic_stat_music.xml` with the exact 24dp x 24dp monochrome white (`#FFFFFF`) vector drawable defined in `design.md` §1.1 (`pathData="M12,3v10.55c-0.59,-0.34 -1.27,-0.55 -2,-0.55 -2.21,0 -4,1.79 -4,4s1.79,4 4,4 4,-1.79 4,-4V7h4V3h-6z"`).
  2. Update `apps/vhunambi_client/android/app/src/main/AndroidManifest.xml` as specified in `design.md` §1.2 to register `<meta-data android:name="com.google.firebase.messaging.default_notification_icon" android:resource="@drawable/ic_stat_music" />` inside `<application>`.
- **Acceptance Criteria**:
  - `drawable/ic_stat_music.xml` exists on disk and parses as valid Android vector XML.
  - `AndroidManifest.xml` contains the `@drawable/ic_stat_music` metadata entry alongside `AudioServiceActivity` and `AudioService`.

### [x] Task 65.1.2: Author `VhunambiCrashShield`, `CrashBreadcrumbBuffer`, `VhunambiProviderObserver` & `VhunambiSafeErrorCard`
- **Audit Findings Resolved**: `P1-02`, `P1-03`, `P1-04`, `P1-05`
- **Requirements**: `REQ-P65-L1-02`, `REQ-P65-L1-03`, `REQ-P65-NFR-01`, `REQ-P65-NFR-03`
- **Design Reference**: `design.md` §1.3
- **Target Files**:
  - `[NEW]` `apps/vhunambi_client/lib/core/resilience/vhunambi_crash_shield.dart`
- **Implementation Instructions**:
  1. Create `apps/vhunambi_client/lib/core/resilience/vhunambi_crash_shield.dart` exactly as specified in `design.md` §1.3.
  2. Ensure `CrashBreadcrumbBuffer` maintains a bounded 50-entry ring buffer (`maxEntries = 50`).
  3. Ensure `VhunambiCrashShield.installGlobalHandlers()` registers `FlutterError.onError`, `PlatformDispatcher.instance.onError` (returning `true`), and `ErrorWidget.builder` rendering `VhunambiSafeErrorCard` (`Key('vhunambi_safe_error_card')`, `Key('vhunambi_safe_error_card_title')`, `Key('vhunambi_safe_error_card_subtitle')`) using `PhosphorIcons.warningCircleBold`, `AppColors`, and `AppTypography` with zero raw emojis.
  4. Ensure `VhunambiCrashShield.guardStartup<T>` wraps each cold-boot step in `Future.timeout(timeout)` (default 4 seconds) and catches errors without aborting app startup.
- **Acceptance Criteria**:
  - `flutter analyze lib/core/resilience/vhunambi_crash_shield.dart` reports zero issues.
  - Tests `T1`, `T2`, `T3`, and `T4` in `phase65_foundation_crash_immunity_test.dart` pass.

### [x] Task 65.1.3: Wire `VhunambiCrashShield.run()` & `guardStartup()` in `main.dart`
- **Audit Findings Resolved**: `P1-02`, `P1-06`
- **Requirements**: `REQ-P65-L1-02`, `REQ-P65-L1-04`
- **Design Reference**: `design.md` §1.4
- **Target Files**:
  - `[MOD]` `apps/vhunambi_client/lib/main.dart`
- **Implementation Instructions**:
  1. Import `package:vhunambi_client/core/resilience/vhunambi_crash_shield.dart` in `apps/vhunambi_client/lib/main.dart`.
  2. Replace `void main() async` with `void main()` invoking `VhunambiCrashShield.run(() async { ... })` as specified in `design.md` §1.4.
  3. Wrap `Hive.initFlutter()`, `SovereignStorageService().initialize()`, `Supabase.initialize(...)`, and `initAudioService()` inside `VhunambiCrashShield.guardStartup(...)` with a 4-second timeout per step.
  4. Attach `observers: const [VhunambiProviderObserver()]` to `ProviderScope`.
- **Acceptance Criteria**:
  - Cold boot never hangs on a Black Screen of Death even if Hive, Supabase, or `AudioService.init` throws or times out.

---

## 3. Milestone M65.2: Layer 2 — `SafeAudioOrchestrator` & Duration/Ticker State Machine

### [x] Task 65.2.1: Author `SafeAudioOrchestrator` Hardware Audio Slot Mutex
- **Audit Findings Resolved**: `P2-01`, `P2-06`
- **Requirements**: `REQ-P65-L2-01`, `REQ-P65-L2-04`, `REQ-P65-NFR-02`
- **Design Reference**: `design.md` §2.1
- **Target Files**:
  - `[NEW]` `apps/vhunambi_client/lib/core/resilience/safe_audio_orchestrator.dart`
- **Implementation Instructions**:
  1. Create `apps/vhunambi_client/lib/core/resilience/safe_audio_orchestrator.dart` exactly as specified in `design.md` §2.1.
  2. Define `enum AudioEngineSlot { masterPlayer, stemMixer, reelPool, sketchpad }`.
  3. Implement `acquireSlot(AudioEngineSlot slot)` using an async `Completer<void>` lock so acquiring a new slot atomically suspends the previous active slot before returning.
  4. Implement `guardAudioOp<T>` with a 5-second timeout and specific handling for `PlayerInterruptedException`, `PlayerException`, `PlatformException`, and `TimeoutException`, recording all failures in `VhunambiCrashShield.breadcrumbs`.
- **Acceptance Criteria**:
  - `flutter analyze lib/core/resilience/safe_audio_orchestrator.dart` reports zero issues.
  - Tests `T5` and `T6` in `phase65_foundation_crash_immunity_test.dart` pass.

### [x] Task 65.2.2: Wire `VhunambiAudioHandler`, `JustAudioMultiStemEngine`, `RealReelAudioPoolService` & `RealSketchpadAudioPlayerService` into `SafeAudioOrchestrator`
- **Audit Findings Resolved**: `P2-01`, `P2-05`, `P2-06`
- **Requirements**: `REQ-P65-L2-01`, `REQ-P65-L2-03`, `REQ-P65-L2-04`
- **Design Reference**: `design.md` §2.3, §2.4
- **Target Files**:
  - `[MOD]` `apps/vhunambi_client/lib/core/services/vhunambi_audio_handler.dart`
  - `[MOD]` `apps/vhunambi_client/lib/features/studio/services/just_audio_multi_stem_engine.dart`
  - `[MOD]` `apps/vhunambi_client/lib/features/explore/services/reel_audio_pool_service.dart`
  - `[MOD]` `apps/vhunambi_client/lib/features/sketchpad/services/sketchpad_audio_player_service.dart`
- **Implementation Instructions**:
  1. In `vhunambi_audio_handler.dart`:
     - Register `AudioEngineSlot.masterPlayer` with `SafeAudioOrchestrator.instance.registerSlot(AudioEngineSlot.masterPlayer, () => _player.pause())`.
     - Add `StreamSubscription<Duration?>? _durationSubscription` listening to `_player.durationStream` (`onError:` guarded) to update `mediaItem` when hardware duration resolves (`d != null && d > Duration.zero`).
     - Add `onError:` callbacks to `_playbackEventSubscription` and `_playerStateSubscription`.
     - Wrap `loadTrackUrl`, `play()`, `pause()`, `stop()`, and `seek()` in `SafeAudioOrchestrator.instance.guardAudioOp(...)` and acquire `AudioEngineSlot.masterPlayer` before loading/playing.
     - Cancel `_durationSubscription`, `_playbackEventSubscription`, and `_playerStateSubscription` in `dispose()`.
  2. In `just_audio_multi_stem_engine.dart`:
     - Register `AudioEngineSlot.stemMixer` with `SafeAudioOrchestrator.instance.registerSlot(AudioEngineSlot.stemMixer, pause)`.
     - Acquire `AudioEngineSlot.stemMixer` inside `loadFromManifest` and `play()`.
     - Add `onError:` handlers to `_posSub`, `_stateSub`, and `_durSub` in `_bindMasterListeners()`.
     - Wrap player `setUrl`, `play`, `pause`, `stop`, and `seek` operations inside `SafeAudioOrchestrator.instance.guardAudioOp(...)`.
  3. In `reel_audio_pool_service.dart` and `sketchpad_audio_player_service.dart`:
     - Register `AudioEngineSlot.reelPool` and `AudioEngineSlot.sketchpad` respectively with `SafeAudioOrchestrator.instance`, acquiring the slot before playback and wrapping `setUrl`/`play`/`pause`/`stop` in `guardAudioOp`.
- **Acceptance Criteria**:
  - Active hardware `just_audio.AudioPlayer` count never exceeds 5 (`N_active_decoders <= 5`).
  - Zero unhandled stream errors escape from `_player.playbackEventStream`, `playerStateStream`, or `durationStream`.

### [x] Task 65.2.3: Remove Eager 5-Player Stem Preload, Boot `track_default_1` Paused & Couple Position Ticker to Hardware Playback
- **Audit Findings Resolved**: `P2-02`, `P2-03`, `P2-04`
- **Requirements**: `REQ-P65-L2-01`, `REQ-P65-L2-02`, `REQ-P65-L2-03`
- **Design Reference**: `design.md` §2.2, §2.5, §2.6
- **Target Files**:
  - `[MOD]` `apps/vhunambi_client/lib/core/constants/app_constants.dart`
  - `[MOD]` `apps/vhunambi_client/lib/features/player/providers/player_provider.dart`
  - `[MOD]` `apps/vhunambi_client/lib/features/studio/providers/generation_pipeline_providers.dart`
- **Implementation Instructions**:
  1. In `app_constants.dart`, update `normalizeCloudMediaUrl` regex from `r'^https?:\/\/(cdn\.vhunambi\.co\.za|storage\.vhunambi\.dev)\/'` to `r'^https?:\/\/(cdn\.vhunambi\.co\.za|storage\.vhunambi\.dev|vhunambi\.com|www\.vhunambi\.com)\/'` as shown in `design.md` §2.2.
  2. In `player_provider.dart` (`design.md` §2.5):
     - Change `_defaultTrack` (`track_default_1`, `"Grateful in the Light"`) to include `audioUrl: 'https://r2.vhunambi.com/explore/track_default_1.wav'` and boot `PlayerState` with `status: PlaybackStatus.paused` and `position: Duration.zero` instead of `PlaybackStatus.playing` at `Duration(seconds: 42)`.
     - Remove `_startPositionTicker()` from the `PlayerNotifier` constructor.
     - Add `_durationSub` listening to `handler.mediaItem.stream` (`onError:` guarded) so hardware-decoded duration updates `state.currentTrack.duration`.
     - Add `onError:` callbacks to `_positionSub` and `_stateSub`.
     - Ensure `_startPositionTicker()` cancels `_positionTimer` immediately whenever `state.status != PlaybackStatus.playing`, and advances position only when `_audioHandler == null`.
  3. In `generation_pipeline_providers.dart` (`design.md` §2.6):
     - Remove the eager `unawaited(_ref.read(multiStemAudioEngineProvider).loadFromManifest(stemManifest))` call from `_onGenerationComplete` so stem decoders are only allocated when the user opens the Stem Mixer UI.
     - Wrap `playerNotifier.playTrack(generatedTrack)` in `SafeAudioOrchestrator.instance.guardAudioOp('generationComplete.playTrack', ...)`.
- **Acceptance Criteria**:
  - Tests `T7`, `T8`, and `T9` in `phase65_foundation_crash_immunity_test.dart` pass.
  - Cold boot starts `"Grateful in the Light"` in `PlaybackStatus.paused` at `0:00` with zero running timers.

---

## 4. Milestone M65.3: Layer 3 — `SafeNotifierMixin`, 14 Async Notifiers & `SafeNetworkAvatar`

### [x] Task 65.3.1: Unify `_RootShellState` with `appNavigationTabProvider` & Harden Modal / Bottom-Sheet Lifecycle
- **Audit Findings Resolved**: `P3-01`, `P3-03`
- **Requirements**: `REQ-P65-L3-01`, `REQ-P65-L3-03`
- **Design Reference**: `design.md` §1.4, §3.4, §3.5
- **Target Files**:
  - `[MOD]` `apps/vhunambi_client/lib/main.dart`
  - `[MOD]` `apps/vhunambi_client/lib/features/studio/widgets/studio_action_bar.dart`
  - `[MOD]` `apps/vhunambi_client/lib/features/studio/widgets/expanded_cockpit_modal.dart`
- **Implementation Instructions**:
  1. In `apps/vhunambi_client/lib/main.dart` (`_RootShellState`, `design.md` §1.4):
     - Remove private `int _currentIndex = 0;` and derive `final currentIndex = ref.watch(appNavigationTabProvider).index;`.
     - Update `_onTabSelected(int index)` to write `ref.read(appNavigationTabProvider.notifier).state = AppNavigationTab.values[index];` so `MiniPlayerHost` (`currentTab != AppNavigationTab.studio`) always matches the visible bottom navigation tab.
  2. In `studio_action_bar.dart` (`design.md` §3.4) and `expanded_cockpit_modal.dart` (`design.md` §3.5):
     - Guard post-await `Navigator.of(context)` / `showModalBottomSheet` calls with `if (!context.mounted) return;`.
- **Acceptance Criteria**:
  - Test `T10` in `phase65_foundation_crash_immunity_test.dart` passes (`MiniPlayerHost` is hidden whenever the Studio tab is selected via bottom navigation).

### [x] Task 65.3.2: Author `SafeNotifierMixin` & Apply `if (!mounted) return;` Guards Across All 14 Async `StateNotifier` Files
- **Audit Findings Resolved**: `P3-02`
- **Requirements**: `REQ-P65-L3-02`
- **Design Reference**: `design.md` §3.1, §3.2
- **Target Files**:
  - `[NEW]` `apps/vhunambi_client/lib/core/resilience/safe_notifier_mixin.dart`
  - `[MOD]` `apps/vhunambi_client/lib/features/studio/providers/generation_pipeline_providers.dart`
  - `[MOD]` `apps/vhunambi_client/lib/features/studio/providers/lyrics_review_provider.dart`
  - `[MOD]` `apps/vhunambi_client/lib/features/studio/providers/generation_request_notifier.dart`
  - `[MOD]` `apps/vhunambi_client/lib/features/beats/providers/beat_checkout_provider.dart`
  - `[MOD]` `apps/vhunambi_client/lib/features/profile/providers/profile_operation_notifier.dart`
  - `[MOD]` `apps/vhunambi_client/lib/features/explore/providers/reels_comments_provider.dart`
  - `[MOD]` `apps/vhunambi_client/lib/features/explore/providers/social_feed_provider.dart`
  - `[MOD]` `apps/vhunambi_client/lib/core/providers/offline_providers.dart`
  - `[MOD]` `apps/vhunambi_client/lib/features/beats/providers/beats_provider.dart`
  - `[MOD]` `apps/vhunambi_client/lib/features/collections/providers/collections_provider.dart`
  - `[MOD]` `apps/vhunambi_client/lib/features/dna/providers/creator_dna_provider.dart`
  - `[MOD]` `apps/vhunambi_client/lib/features/explore/providers/explore_providers.dart`
  - `[MOD]` `apps/vhunambi_client/lib/features/notifications/providers/notifications_provider.dart`
  - `[MOD]` `apps/vhunambi_client/lib/features/wallet/providers/creator_wallet_provider.dart`
  - `[MOD]` `apps/vhunambi_client/lib/features/vocal_id/providers/vocal_identity_provider.dart`
- **Implementation Instructions**:
  1. Create `apps/vhunambi_client/lib/core/resilience/safe_notifier_mixin.dart` as specified in `design.md` §3.1 (`setStateIfMounted`, `guardAsync`, `guardFireAndForget`).
  2. Apply `with SafeNotifierMixin<...>` and/or explicit `if (!mounted) return;` guards before every post-`await` `state = ...` assignment across all 14 async `StateNotifier` files + `vocal_identity_provider.dart` as detailed in `design.md` §3.2 (`generation_pipeline_providers.dart`, `lyrics_review_provider.dart`, `generation_request_notifier.dart`, `beat_checkout_provider.dart`, `profile_operation_notifier.dart`, `reels_comments_provider.dart`, `social_feed_provider.dart`, `offline_providers.dart`, `beats_provider.dart`, `collections_provider.dart`, `creator_dna_provider.dart`, `explore_providers.dart`, `notifications_provider.dart`, `creator_wallet_provider.dart`, `vocal_identity_provider.dart`).
- **Acceptance Criteria**:
  - Disposing any `StateNotifier` while an async HTTP/Hive/timer Future is in flight never throws `Bad state: Tried to use <Notifier> after dispose was called`.
  - Test `T11` in `phase65_foundation_crash_immunity_test.dart` passes.

### [x] Task 65.3.3: Author `SafeNetworkAvatar` & Replace Unguarded `Image.network` / `NetworkImage` Calls
- **Audit Findings Resolved**: `P2-07`, `P3-04`
- **Requirements**: `REQ-P65-L2-05`, `REQ-P65-L3-04`, `REQ-P65-NFR-01`, `REQ-P65-NFR-03`
- **Design Reference**: `design.md` §3.3, §3.4, §3.5
- **Target Files**:
  - `[NEW]` `apps/vhunambi_client/lib/core/widgets/safe_network_avatar.dart`
  - `[MOD]` `apps/vhunambi_client/lib/features/explore/widgets/explore_social_post_card.dart`
  - `[MOD]` `apps/vhunambi_client/lib/features/studio/widgets/pill_form.dart`
  - `[MOD]` `apps/vhunambi_client/lib/features/studio/widgets/studio_action_bar.dart`
  - `[MOD]` `apps/vhunambi_client/lib/features/studio/widgets/expanded_cockpit_modal.dart`
- **Implementation Instructions**:
  1. Create `apps/vhunambi_client/lib/core/widgets/safe_network_avatar.dart` (`Key('safe_network_avatar')`, `Key('safe_network_avatar_fallback')`) exactly as specified in `design.md` §3.3.
  2. Replace unguarded `CircleAvatar(backgroundImage: NetworkImage(...))` and `Image.network(...)` without `errorBuilder:` in `explore_social_post_card.dart` (line 396), `pill_form.dart` (line 111), `studio_action_bar.dart` (line 226), and `expanded_cockpit_modal.dart` (line 122) with `SafeNetworkAvatar` as shown in `design.md` §3.4 and §3.5.
- **Acceptance Criteria**:
  - Zero `Image.network` calls without `errorBuilder:` and zero `CircleAvatar(backgroundImage: NetworkImage(...))` without `onBackgroundImageError:` remain in `apps/vhunambi_client/lib/`.
  - Test `T12` in `phase65_foundation_crash_immunity_test.dart` passes.

---

## 5. Milestone M65.4: Layer 4 — `JsonSafe`, Per-Record Hive Quarantine, WebSocket Timeout & `DioException` Classification

### [x] Task 65.4.1: Author `JsonSafe` & Refactor `SovereignDomainRepositories` / `HttpSocialRepository`
- **Audit Findings Resolved**: `P4-02`, `P4-03`
- **Requirements**: `REQ-P65-L4-02`, `REQ-P65-L4-03`
- **Design Reference**: `design.md` §4.1, §4.2
- **Target Files**:
  - `[NEW]` `apps/vhunambi_client/lib/core/utils/json_safe.dart`
  - `[MOD]` `apps/vhunambi_client/lib/core/services/sovereign_domain_repositories.dart`
  - `[MOD]` `apps/vhunambi_client/lib/features/explore/repositories/http_social_repository.dart`
- **Implementation Instructions**:
  1. Create `apps/vhunambi_client/lib/core/utils/json_safe.dart` (`asString`, `asInt`, `asDouble`, `asBool`, `asMap`, `asList`, `parseRecordList`) exactly as specified in `design.md` §4.1.
  2. Refactor `loadWalletSnapshot()` in `apps/vhunambi_client/lib/core/services/sovereign_domain_repositories.dart` (`design.md` §4.2) so each `tx_` Hive record is parsed inside an individual `try / catch` block using `JsonSafe`. When a corrupt record is encountered, delete only that key (`await txBox.delete(key)`) and preserve all sibling valid transactions.
  3. Update `apps/vhunambi_client/lib/features/explore/repositories/http_social_repository.dart` to use `JsonSafe` when parsing social feed items and comments.
- **Acceptance Criteria**:
  - Tests `T13` and `T14` in `phase65_foundation_crash_immunity_test.dart` pass.

### [x] Task 65.4.2: Harden `GenerationSocketService` (8s Connect Timeout + Atomic Cleanup) & `NetworkErrorHandler.classify`
- **Audit Findings Resolved**: `P4-01`, `P4-04`
- **Requirements**: `REQ-P65-L4-01`, `REQ-P65-L4-04`
- **Design Reference**: `design.md` §4.3, §4.4
- **Target Files**:
  - `[MOD]` `apps/vhunambi_client/lib/features/studio/services/generation_socket_service.dart`
  - `[MOD]` `apps/vhunambi_client/lib/core/network/error_handler.dart`
- **Implementation Instructions**:
  1. Refactor `apps/vhunambi_client/lib/features/studio/services/generation_socket_service.dart` (`design.md` §4.3):
     - Add `static const Duration connectTimeout = Duration(seconds: 8);` to `WebSocket.connect(wsUrl).timeout(connectTimeout)`.
     - Store `StreamSubscription<dynamic>? _socketSubscription;` and cancel it atomically alongside `_pingTimer` inside `_cleanupSocket()` before every reconnect or `dispose()`.
     - Guard `socket.add(jsonEncode({'type': 'ping'}))` in `try / catch` so a closed socket immediately triggers `_scheduleReconnect()`.
  2. Refactor `apps/vhunambi_client/lib/core/network/error_handler.dart` (`design.md` §4.4):
     - Import `package:dio/dio.dart` and inspect `if (error is DioException)` at the top of `NetworkErrorHandler.classify(Object error)` to map `connectionTimeout`/`sendTimeout`/`receiveTimeout` -> `ErrorType.timeout`, `connectionError` -> `ErrorType.offline`, `cancel` -> `ErrorType.cancelled`, and `badResponse` status codes (`401`/`403` -> `unauthorized`, `404` -> `notFound`, `429` -> `rateLimited`, `>=500` -> `serverError`).
- **Acceptance Criteria**:
  - Tests `T15` and `T16` in `phase65_foundation_crash_immunity_test.dart` pass.

---

## 6. Milestone M65.5: Layer 5 — Backend `GlobalErrorBoundary`, True PNG/WAV Parity, Studio Parameter Fidelity & Verification

### [x] Task 65.5.1: Register Global `app.onError` and `app.notFound` Handlers in `server.ts`
- **Audit Findings Resolved**: `P5-01`
- **Requirements**: `REQ-P65-L5-01`
- **Design Reference**: `design.md` §5.1
- **Target Files**:
  - `[MOD]` `apps/vhunambi_api/src/server.ts`
- **Implementation Instructions**:
  1. In `apps/vhunambi_api/src/server.ts`, register `app.notFound` and `app.onError` on the root Hono instance as specified in `design.md` §5.1.
  2. Ensure every unhandled route error returns a structured JSON envelope `{ status: "error", code, message, requestId, timestamp }` with CORS headers (`Access-Control-Allow-Origin: *`) and HTTP status `400` for JSON syntax errors or `500` for unexpected exceptions.
- **Acceptance Criteria**:
  - Backend tests `B1` (`404 ROUTE_NOT_FOUND` with CORS) and `B2` (`400 INVALID_JSON_PAYLOAD` with CORS) in `phase65_foundation_resilience.test.ts` pass.

### [x] Task 65.5.2: Implement RFC-2083 PNG Cover Synthesis & 24-Second Stereo WAV Tiling
- **Audit Findings Resolved**: `P5-02`, `P5-03`
- **Requirements**: `REQ-P65-L5-02`, `REQ-P65-L5-03`
- **Design Reference**: `design.md` §5.2
- **Target Files**:
  - `[MOD]` `apps/vhunambi_api/src/modules/storage/r2_media_synthesizer.ts`
  - `[MOD]` `apps/vhunambi_api/src/routes/vision_routes.ts`
- **Implementation Instructions**:
  1. In `apps/vhunambi_api/src/modules/storage/r2_media_synthesizer.ts` (`design.md` §5.2):
     - Import `deflateSync` from `node:zlib`.
     - Implement IEEE 802.3 `crc32`, `buildPngChunk`, and `synthesizeCoverPngBytes(seedText, width = 256, height = 256)` producing valid RFC-2083 PNG bytes starting with `\x89PNG\r\n\x1a\n` (`89 50 4E 47 0D 0A 1A 0A`).
     - Retain `synthesizeCoverBmpBytes` as a backward-compatible alias forwarding to `synthesizeCoverPngBytes`.
     - Upgrade `synthesizePlayableWavBytes` default `durationSec` from `6` to `24` seconds (`2,116,844` bytes at 22,050 Hz 16-bit stereo), synthesizing the 6-second harmonic master loop and block-copying (`result.set`) across the 24-second buffer with fade-in/fade-out envelopes.
     - Ensure `resolveFallbackMediaAsset` serves `image/png` with `\x89PNG\r\n\x1a\n` bytes for `.png`, `.jpg`, `.jpeg`, `.webp`, and `.bmp` paths.
  2. In `apps/vhunambi_api/src/routes/vision_routes.ts`, verify cover uploads call `synthesizeCoverPngBytes` with `contentType: 'image/png'`.
- **Acceptance Criteria**:
  - Backend tests `B3` (`\x89PNG\r\n\x1a\n` header + `IHDR` + `IEND` verification) and `B4` (24-second RIFF/WAVE header + `2,116,844` byte length + non-zero PCM verification) in `phase65_foundation_resilience.test.ts` pass.

### [x] Task 65.5.3: Enforce Active `StudioFormState` Priority in Prompt Enhance, Non-Echoing Lyrics Fallback & GPU Warning Logs
- **Audit Findings Resolved**: `P5-04`, `P5-05`, `P6-01`, `P6-02`, `P6-03`
- **Requirements**: `REQ-P65-L5-04`, `REQ-P65-L5-05`
- **Design Reference**: `design.md` §5.3, §5.4, §5.5, §5.6
- **Target Files**:
  - `[MOD]` `apps/vhunambi_client/lib/features/studio/services/studio_prompt_intelligence.dart`
  - `[MOD]` `apps/vhunambi_client/lib/features/studio/widgets/prompt_input_box.dart`
  - `[MOD]` `apps/vhunambi_api/src/modules/lyrics/llm_handler.ts`
  - `[MOD]` `tools/zr-studio-gpu/model_utils.py`
  - `[MOD]` `tools/zr-studio-gpu/mmo_extractor.py`
- **Implementation Instructions**:
  1. In `studio_prompt_intelligence.dart` (`design.md` §5.3), add optional `StudioFormState? currentForm` to `StudioPromptIntelligence.enhance` and resolve `activeGenre`, `activeBpm`, `activeKey`, and `activeLanguages` using `currentForm` selections first before falling back to `CreatorDnaProfile`.
  2. In `prompt_input_box.dart` (`design.md` §5.4), pass `currentForm: formState` into `StudioPromptIntelligence.enhance(...)` inside `_handleEnhancePrompt()`.
  3. In `apps/vhunambi_api/src/modules/lyrics/llm_handler.ts` (`design.md` §5.5), refactor `generateLocalMockLyrics` to strip directive/instruction prefixes (`make`, `create`, `generate`, `write`, `produce`, `compose`, `build`, `track`, `song`, `beat`, `music`, `with`, `about`) via `extractThematicMotif(rawPrompt)` so the raw user prompt string is never echoed verbatim into `[Verse 1]` or `[Chorus]`.
  4. In `tools/zr-studio-gpu/model_utils.py` and `tools/zr-studio-gpu/mmo_extractor.py` (`design.md` §5.6), replace silent `except Exception: pass` / `return 0.0` blocks with explicit `print(f"[ZR-WARN] ...", flush=True)` structured diagnostic logs.
- **Acceptance Criteria**:
  - Flutter tests `T17` and `T18` in `phase65_foundation_crash_immunity_test.dart` pass (`Tshivenda` + `90s Kwaito` selections preserved; zero `English` or `Afro Soul` injection).
  - Backend test `B5` in `phase65_foundation_resilience.test.ts` passes (zero verbatim prompt echoing in fallback lyrics).

### [x] Task 65.5.4: Create Verification Suites, Run Automated Tests, Deploy Worker & Verify on Physical Device `EPHUT20917014649`
- **Requirements**: `REQ-P65-L1-01` .. `REQ-P65-NFR-03`
- **Design Reference**: `design.md` §6.1, §6.2
- **Target Files**:
  - `[NEW]` `apps/vhunambi_client/test/phase65_foundation_crash_immunity_test.dart`
  - `[NEW]` `apps/vhunambi_api/src/__tests__/phase65_foundation_resilience.test.ts`
- **Implementation Instructions**:
  1. Create `apps/vhunambi_client/test/phase65_foundation_crash_immunity_test.dart` (`T1`–`T18`) exactly as specified in `design.md` §6.1.
  2. Create `apps/vhunambi_api/src/__tests__/phase65_foundation_resilience.test.ts` (`B1`–`B5`) exactly as specified in `design.md` §6.2.
  3. Run backend TypeScript and Vitest verification in `apps/vhunambi_api`:
     - `npx tsc --noEmit`
     - `npx vitest run src/__tests__/phase65_foundation_resilience.test.ts src/__tests__/phase64_production_pipeline.test.ts`
  4. Run Flutter static analysis and test suites in `apps/vhunambi_client`:
     - `flutter analyze`
     - `flutter test test/phase65_foundation_crash_immunity_test.dart`
  5. Deploy the updated Cloudflare Worker (`npx wrangler deploy` in `apps/vhunambi_api`).
  6. Build and install the release APK onto connected physical device `EPHUT20917014649` (`Huawei JNY_LX1`), clear crash logs (`adb -s EPHUT20917014649 logcat -b crash -c`), launch the app, exercise audio playback/notification creation, and verify `adb -s EPHUT20917014649 logcat -b crash -d` outputs zero lines.
- **Acceptance Criteria**:
  - All 6 Phase 65 Verification Gates (`G-65-01` through `G-65-06`) pass with zero errors.

---

## 7. Complete File Inventory & Requirement Traceability

| # | File Path | Action | Milestone | Task | Requirements |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | `apps/vhunambi_client/android/app/src/main/res/drawable/ic_stat_music.xml` | `[NEW]` | `M65.1` | `65.1.1` | `REQ-P65-L1-01` |
| 2 | `apps/vhunambi_client/android/app/src/main/AndroidManifest.xml` | `[MOD]` | `M65.1` | `65.1.1` | `REQ-P65-L1-01` |
| 3 | `apps/vhunambi_client/lib/core/resilience/vhunambi_crash_shield.dart` | `[NEW]` | `M65.1` | `65.1.2` | `REQ-P65-L1-02`, `REQ-P65-L1-03`, `REQ-P65-NFR-01` |
| 4 | `apps/vhunambi_client/lib/main.dart` | `[MOD]` | `M65.1`, `M65.3` | `65.1.3`, `65.3.1` | `REQ-P65-L1-02`, `REQ-P65-L1-04`, `REQ-P65-L3-01` |
| 5 | `apps/vhunambi_client/lib/core/resilience/safe_audio_orchestrator.dart` | `[NEW]` | `M65.2` | `65.2.1` | `REQ-P65-L2-01`, `REQ-P65-L2-04`, `REQ-P65-NFR-02` |
| 6 | `apps/vhunambi_client/lib/core/constants/app_constants.dart` | `[MOD]` | `M65.2` | `65.2.3` | `REQ-P65-L2-02` |
| 7 | `apps/vhunambi_client/lib/core/services/vhunambi_audio_handler.dart` | `[MOD]` | `M65.2` | `65.2.2` | `REQ-P65-L2-01`, `REQ-P65-L2-03`, `REQ-P65-L2-04` |
| 8 | `apps/vhunambi_client/lib/features/studio/services/just_audio_multi_stem_engine.dart` | `[MOD]` | `M65.2` | `65.2.2` | `REQ-P65-L2-01`, `REQ-P65-L2-04` |
| 9 | `apps/vhunambi_client/lib/features/explore/services/reel_audio_pool_service.dart` | `[MOD]` | `M65.2` | `65.2.2` | `REQ-P65-L2-01`, `REQ-P65-L2-04` |
| 10 | `apps/vhunambi_client/lib/features/sketchpad/services/sketchpad_audio_player_service.dart` | `[MOD]` | `M65.2` | `65.2.2` | `REQ-P65-L2-01`, `REQ-P65-L2-04` |
| 11 | `apps/vhunambi_client/lib/features/player/providers/player_provider.dart` | `[MOD]` | `M65.2` | `65.2.3` | `REQ-P65-L2-02`, `REQ-P65-L2-03`, `REQ-P65-L2-04` |
| 12 | `apps/vhunambi_client/lib/features/studio/providers/generation_pipeline_providers.dart` | `[MOD]` | `M65.2`, `M65.3` | `65.2.3`, `65.3.2` | `REQ-P65-L2-01`, `REQ-P65-L3-02` |
| 13 | `apps/vhunambi_client/lib/core/resilience/safe_notifier_mixin.dart` | `[NEW]` | `M65.3` | `65.3.2` | `REQ-P65-L3-02` |
| 14 | `apps/vhunambi_client/lib/features/studio/providers/lyrics_review_provider.dart` | `[MOD]` | `M65.3` | `65.3.2` | `REQ-P65-L3-02` |
| 15 | `apps/vhunambi_client/lib/features/studio/providers/generation_request_notifier.dart` | `[MOD]` | `M65.3` | `65.3.2` | `REQ-P65-L3-02` |
| 16 | `apps/vhunambi_client/lib/features/beats/providers/beat_checkout_provider.dart` | `[MOD]` | `M65.3` | `65.3.2` | `REQ-P65-L3-02` |
| 17 | `apps/vhunambi_client/lib/features/profile/providers/profile_operation_notifier.dart` | `[MOD]` | `M65.3` | `65.3.2` | `REQ-P65-L3-02` |
| 18 | `apps/vhunambi_client/lib/features/explore/providers/reels_comments_provider.dart` | `[MOD]` | `M65.3` | `65.3.2` | `REQ-P65-L3-02` |
| 19 | `apps/vhunambi_client/lib/features/explore/providers/social_feed_provider.dart` | `[MOD]` | `M65.3` | `65.3.2` | `REQ-P65-L3-02` |
| 20 | `apps/vhunambi_client/lib/core/providers/offline_providers.dart` | `[MOD]` | `M65.3` | `65.3.2` | `REQ-P65-L3-02` |
| 21 | `apps/vhunambi_client/lib/features/beats/providers/beats_provider.dart` | `[MOD]` | `M65.3` | `65.3.2` | `REQ-P65-L3-02` |
| 22 | `apps/vhunambi_client/lib/features/collections/providers/collections_provider.dart` | `[MOD]` | `M65.3` | `65.3.2` | `REQ-P65-L3-02` |
| 23 | `apps/vhunambi_client/lib/features/dna/providers/creator_dna_provider.dart` | `[MOD]` | `M65.3` | `65.3.2` | `REQ-P65-L3-02` |
| 24 | `apps/vhunambi_client/lib/features/explore/providers/explore_providers.dart` | `[MOD]` | `M65.3` | `65.3.2` | `REQ-P65-L3-02` |
| 25 | `apps/vhunambi_client/lib/features/notifications/providers/notifications_provider.dart` | `[MOD]` | `M65.3` | `65.3.2` | `REQ-P65-L3-02` |
| 26 | `apps/vhunambi_client/lib/features/wallet/providers/creator_wallet_provider.dart` | `[MOD]` | `M65.3` | `65.3.2` | `REQ-P65-L3-02` |
| 27 | `apps/vhunambi_client/lib/features/vocal_id/providers/vocal_identity_provider.dart` | `[MOD]` | `M65.3` | `65.3.2` | `REQ-P65-L3-02` |
| 28 | `apps/vhunambi_client/lib/core/widgets/safe_network_avatar.dart` | `[NEW]` | `M65.3` | `65.3.3` | `REQ-P65-L2-05`, `REQ-P65-L3-04`, `REQ-P65-NFR-01` |
| 29 | `apps/vhunambi_client/lib/features/explore/widgets/explore_social_post_card.dart` | `[MOD]` | `M65.3` | `65.3.3` | `REQ-P65-L2-05`, `REQ-P65-L3-04` |
| 30 | `apps/vhunambi_client/lib/features/studio/widgets/pill_form.dart` | `[MOD]` | `M65.3` | `65.3.3` | `REQ-P65-L2-05`, `REQ-P65-L3-04` |
| 31 | `apps/vhunambi_client/lib/features/studio/widgets/studio_action_bar.dart` | `[MOD]` | `M65.3` | `65.3.1`, `65.3.3` | `REQ-P65-L2-05`, `REQ-P65-L3-03`, `REQ-P65-L3-04` |
| 32 | `apps/vhunambi_client/lib/features/studio/widgets/expanded_cockpit_modal.dart` | `[MOD]` | `M65.3` | `65.3.1`, `65.3.3` | `REQ-P65-L2-05`, `REQ-P65-L3-03`, `REQ-P65-L3-04` |
| 33 | `apps/vhunambi_client/lib/core/utils/json_safe.dart` | `[NEW]` | `M65.4` | `65.4.1` | `REQ-P65-L4-02`, `REQ-P65-L4-03` |
| 34 | `apps/vhunambi_client/lib/core/services/sovereign_domain_repositories.dart` | `[MOD]` | `M65.4` | `65.4.1` | `REQ-P65-L4-02` |
| 35 | `apps/vhunambi_client/lib/features/explore/repositories/http_social_repository.dart` | `[MOD]` | `M65.4` | `65.4.1` | `REQ-P65-L4-03` |
| 36 | `apps/vhunambi_client/lib/features/studio/services/generation_socket_service.dart` | `[MOD]` | `M65.4` | `65.4.2` | `REQ-P65-L4-01` |
| 37 | `apps/vhunambi_client/lib/core/network/error_handler.dart` | `[MOD]` | `M65.4` | `65.4.2` | `REQ-P65-L4-04` |
| 38 | `apps/vhunambi_api/src/server.ts` | `[MOD]` | `M65.5` | `65.5.1` | `REQ-P65-L5-01` |
| 39 | `apps/vhunambi_api/src/modules/storage/r2_media_synthesizer.ts` | `[MOD]` | `M65.5` | `65.5.2` | `REQ-P65-L5-02`, `REQ-P65-L5-03` |
| 40 | `apps/vhunambi_api/src/routes/vision_routes.ts` | `[MOD]` | `M65.5` | `65.5.2` | `REQ-P65-L5-02` |
| 41 | `apps/vhunambi_client/lib/features/studio/services/studio_prompt_intelligence.dart` | `[MOD]` | `M65.5` | `65.5.3` | `REQ-P65-L5-04` |
| 42 | `apps/vhunambi_client/lib/features/studio/widgets/prompt_input_box.dart` | `[MOD]` | `M65.5` | `65.5.3` | `REQ-P65-L5-04` |
| 43 | `apps/vhunambi_api/src/modules/lyrics/llm_handler.ts` | `[MOD]` | `M65.5` | `65.5.3` | `REQ-P65-L5-05` |
| 44 | `tools/zr-studio-gpu/model_utils.py` | `[MOD]` | `M65.5` | `65.5.3` | `REQ-P65-L5-01` |
| 45 | `tools/zr-studio-gpu/mmo_extractor.py` | `[MOD]` | `M65.5` | `65.5.3` | `REQ-P65-L5-01` |
| 46 | `apps/vhunambi_client/test/phase65_foundation_crash_immunity_test.dart` | `[NEW]` | `M65.5` | `65.5.4` | `T1` – `T18` |
| 47 | `apps/vhunambi_api/src/__tests__/phase65_foundation_resilience.test.ts` | `[NEW]` | `M65.5` | `65.5.4` | `B1` – `B5` |

---

## 8. Stage 4 Execution Verification Checklist (`/vhunambi-executioner`)

```text
+---------------------------------------------------------------------------------------------------+
| STAGE 4 FORENSIC ANTI-TRAP VERIFICATION CHECKLIST                                                 |
+---------------------------------------------------------------------------------------------------+
| [x] 1. ZERO LAZY PLACEHOLDERS: Zero "// TODO", "// ...", or unimplemented stubs in any file.     |
| [x] 2. ZERO RAW EMOJIS (STD-UIUX-001): All icons use PhosphorIcons; zero raw unicode emojis.      |
| [x] 3. SURGICAL DIFF DISCIPLINE: Existing files modified via edit_file without destructive wipes. |
| [x] 4. NATIVE DRAWABLE VERIFIED: drawable/ic_stat_music.xml exists and compiles into APK.         |
| [x] 5. BACKEND TESTS GREEN: B1-B5 pass in phase65_foundation_resilience.test.ts + Phase 64 suite. |
| [x] 6. FLUTTER TESTS & ANALYZE GREEN: Phase 65 crash immunity test suite & targeted analyze pass. |
| [x] 7. PHYSICAL DEVICE CRASH LOG EMPTY: adb -s EPHUT20917014649 logcat -b crash -d is 0 lines.    |
+---------------------------------------------------------------------------------------------------+
```

### Stage 4 Verification Commands (PowerShell)

```powershell
# 1. Backend TypeScript & Vitest Verification
Set-Location c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_api
npx tsc --noEmit
npx vitest run src/__tests__/phase65_foundation_resilience.test.ts src/__tests__/phase64_production_pipeline.test.ts

# 2. Deploy Cloudflare Worker
npx wrangler deploy

# 3. Flutter Static Analysis & Phase 65 Resilience Suite
Set-Location c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_client
flutter analyze
flutter test test/phase65_foundation_crash_immunity_test.dart

# 4. Physical Device APK Build, Install & Crash Buffer Verification (Huawei JNY_LX1)
flutter build apk --release
adb -s EPHUT20917014649 logcat -b crash -c
adb -s EPHUT20917014649 install -r build\app\outputs\flutter-apk\app-release.apk
adb -s EPHUT20917014649 shell monkey -p com.vhunambi.app -c android.intent.category.LAUNCHER 1
adb -s EPHUT20917014649 logcat -b crash -d
```

