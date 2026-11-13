# Phase 65 — Requirements Specification (`VHUNAMBI-SPEC-P65-REQUIREMENTS-V1`)

**Document ID**: `VHUNAMBI-SPEC-P65-REQUIREMENTS-V1`  
**Phase**: `Phase 65`  
**Companion Blueprint**: [`blueprint.md`](./blueprint.md)  
**Companion Design**: [`design.md`](./design.md)  
**Companion Tasks**: [`tasks.md`](./tasks.md)

---

## 1. Document Scope, EARS Syntax & RFC-2119 Conventions

This specification defines the normative engineering requirements for **Phase 65: Full-Stack 5-Layer Fault-Containment Architecture, Android Notification Crash Fix, Safe Audio Orchestrator & Studio Parameter Fidelity** across `apps/vhunambi_client`, `apps/vhunambi_api`, and `tools/zr-studio-gpu`.

All requirements use **EARS (Easy Approach to Requirements Syntax)** patterns combined with **RFC-2119** keywords (`SHALL`, `SHALL NOT`, `MUST`, `SHOULD`, `MAY`):
- **Ubiquitous**: `The <system> SHALL <response>.`
- **Event-Driven**: `WHEN <trigger>, the <system> SHALL <response>.`
- **State-Driven**: `WHILE <state>, the <system> SHALL <response>.`
- **Unwanted Behavior (Fault Containment)**: `IF <fault condition>, THEN the <system> SHALL <mitigation>.`

---

## 2. Layer 1 Requirements — Native Android Notification Icon & `VhunambiCrashShield` (`REQ-P65-L1-*`)

### `REQ-P65-L1-01` — Android Small Notification Vector Drawable (`P1-01`)
The Android application bundle **SHALL** include a valid monochrome vector drawable at `apps/vhunambi_client/android/app/src/main/res/drawable/ic_stat_music.xml` with `android:width="24dp"`, `android:height="24dp"`, `android:viewportWidth="24"`, `android:viewportHeight="24"`, and `#FFFFFF` path fill matching `kAudioNotificationIcon = 'drawable/ic_stat_music'` in `vhunambi_audio_handler.dart`, AND `AndroidManifest.xml` **SHALL** declare `<meta-data android:name="com.google.firebase.messaging.default_notification_icon" android:resource="@drawable/ic_stat_music" />` so `NotificationManager.fixNotification` never throws `java.lang.IllegalArgumentException: Invalid notification (no valid small icon)`.

### `REQ-P65-L1-02` — Root Isolate & Platform Error Containment (`P1-02`)
WHEN `main()` is invoked in `apps/vhunambi_client/lib/main.dart`, the application **SHALL** execute inside `VhunambiCrashShield.run(...)` using `runZonedGuarded`, binding `FlutterError.onError = VhunambiCrashShield.recordFlutterError` and `PlatformDispatcher.instance.onError = VhunambiCrashShield.recordPlatformError` (which **SHALL** return `true` after recording the breadcrumb so uncaught asynchronous plugin or network exceptions do not terminate the OS process).

### `REQ-P65-L1-03` — Subtree Widget Error Recovery Boundary (`P1-02`)
IF any Flutter widget subtree throws an unhandled exception during `build`, `layout`, or `paint`, THEN `ErrorWidget.builder` **SHALL** render `VhunambiSafeErrorCard` (`Key('vhunambi_safe_error_card')`) styled with `AppColors` and `PhosphorIcons` and exposing a retry action (`Key('vhunambi_safe_error_retry_btn')`) instead of the default red `ErrorWidget`.

### `REQ-P65-L1-04` — Bounded Pre-`runApp` Startup Guards & Breadcrumb Ring Buffer (`P1-03`)
WHEN `main()` initializes `SovereignHiveBootstrapService.ensureInitialized()`, `SharedPreferences.getInstance()`, and `bootstrapPlatformAudioHandler()`, each asynchronous step **SHALL** be wrapped in `VhunambiCrashShield.guardStartup<T>(stepName, action, timeout: const Duration(seconds: 4), fallback: ...)` so that a hung or failing storage/audio plugin logs to `CrashBreadcrumbBuffer` (bounded at `maxEntries = 100`) and proceeds to `runApp()` without hanging on the native launch screen.

---

## 3. Layer 2 Requirements — `SafeAudioOrchestrator`, Decoder Mutex & Duration/Ticker State Machine (`REQ-P65-L2-*`)

### `REQ-P65-L2-01` — Single-Active-Engine Hardware Audio Mutex (`P2-01`, `P2-06`)
The client **SHALL** provide `SafeAudioOrchestrator` (`apps/vhunambi_client/lib/core/resilience/safe_audio_orchestrator.dart`) managing four mutually exclusive `AudioEngineSlot` values (`masterPlayer`, `stemMixer`, `reelPool`, `sketchpad`). WHEN any engine acquires its slot via `SafeAudioOrchestrator.instance.acquireSlot(slot, onPreempt: ...)`, the orchestrator **SHALL** serialize the transition through a FIFO async lock and invoke the registered preemption pause callback of any previously active slot before starting playback.

### `REQ-P65-L2-02` — Elimination of Eager 5-Player Stem Preload on Generation Complete (`P2-01`)
WHEN `GenerationPipelineNotifier._onGenerationComplete` (`generation_pipeline_providers.dart`) processes a completed generation job, it **SHALL NOT** invoke `multiStemAudioEngineProvider.loadFromManifest(...)` concurrently with `playerStateProvider.notifier.playTrack(...)`. The 4-stem `JustAudioMultiStemEngine` **SHALL** only load stems lazily when the user explicitly initiates playback inside the Stem Mixer deck.

### `REQ-P65-L2-03` — Exception-Guarded Multi-Stem Hardware Operations (`P2-02`)
WHEN `JustAudioMultiStemEngine` executes `loadFromManifest`, `play`, `pause`, `seek`, or `applyMixerState` (`setVolume`), every underlying `AudioPlayer` call **SHALL** be wrapped in `SafeAudioOrchestrator.guardAudioOp(...)` catching `PlayerException`, `PlayerInterruptedException`, `PlatformException`, and `TimeoutException` without propagating unhandled exceptions to the UI isolate.

### `REQ-P65-L2-04` — Cold-Boot Default Track State & Legacy URL Normalization (`P2-03`)
WHEN `PlayerNotifier` initializes its default state (`track_default_1`, `"Grateful in the Light"`), it **SHALL** initialize `playbackStatus: PlaybackStatus.paused` and `position: Duration.zero` (never `PlaybackStatus.playing` on cold boot) with `audioUrl: 'https://r2.vhunambi.com/explore/track_default_1.wav'`, AND `AppConstants.normalizeCloudMediaUrl` **SHALL** include `vhunambi.com` in its legacy hostname rewrite regex so `https://vhunambi.com/audio/...` rewrites cleanly to the active `/r2/` media origin.

### `REQ-P65-L2-05` — Real Hardware Duration Propagation & State-Coupled Position Ticker (`P2-04`, `P2-05`)
WHEN `VhunambiAudioHandler` wires `_player` streams, it **SHALL** subscribe to `player.durationStream` (with `onError:`) and update `mediaItem` whenever a positive decoded duration is emitted. WHILE `PlayerNotifier.state.playbackStatus != PlaybackStatus.playing`, `PlayerNotifier` **SHALL** immediately cancel `_positionTimer` so synthetic progress never advances past paused, buffering, completed, or errored hardware states, and all 6 audio stream `.listen(...)` sites across `vhunambi_audio_handler.dart`, `just_audio_multi_stem_engine.dart`, and `player_provider.dart` **SHALL** attach explicit `onError:` handlers.

---

## 4. Layer 3 Requirements — Navigation Sync, `SafeNotifierMixin` & `SafeNetworkAvatar` (`REQ-P65-L3-*`)

### `REQ-P65-L3-01` — Unified Root Tab Navigation Authority (`P3-01`)
WHEN `_RootShellState._switchTab(int index)`, `_handleSystemBack()`, or `_handleSearchShortcut()` executes in `apps/vhunambi_client/lib/main.dart`, it **SHALL** synchronize `ref.read(appNavigationTabProvider.notifier).state = index` so that `MiniPlayerHost._shouldHide` (`activeTab == 2`) deterministically hides the mini-player whenever the user is on the Studio tab (`index == 2`), including after navigating `Studio -> Library -> Studio`.

### `REQ-P65-L3-02` — Modal & Action Bar Post-`await` Mounted Guards (`P3-02`, `P3-03`)
WHEN `ExpandedCockpitModal.dispose()` schedules `setNowPlayingOpen(false)` or `StudioActionBar._handleGenerate()` resumes after `await ref.read(lyricsReviewProvider.notifier).loadGeneratedLyrics(...)`, the code **SHALL** verify `mounted` / `context.mounted` before mutating any Riverpod notifier or invoking `Navigator` / `ScaffoldMessenger`.

### `REQ-P65-L3-03` — `SafeNotifierMixin` Rollout Across All 14 Async `StateNotifier`s (`P4-03`)
The client **SHALL** define `SafeNotifierMixin<T> on StateNotifier<T>` (`apps/vhunambi_client/lib/core/resilience/safe_notifier_mixin.dart`) and **SHALL** guard every post-`await` `state = ...` assignment with `if (!mounted) return;` (or `setStateIfMounted`) across all 14 async `StateNotifier` files identified in the Phase 65 audit:
1. `generation_pipeline_providers.dart`
2. `lyrics_review_provider.dart`
3. `generation_request_notifier.dart`
4. `beat_checkout_provider.dart`
5. `profile_operation_notifier.dart`
6. `reels_comments_provider.dart`
7. `social_feed_provider.dart`
8. `offline_providers.dart`
9. `beats_provider.dart`
10. `collections_provider.dart`
11. `creator_dna_provider.dart`
12. `explore_providers.dart`
13. `notifications_provider.dart`
14. `creator_wallet_provider.dart` and `vocal_identity_provider.dart`

### `REQ-P65-L3-04` — Error-Guarded `SafeNetworkAvatar` & Palette Extraction (`P4-01`, `P4-02`)
The client **SHALL** provide `SafeNetworkAvatar` (`apps/vhunambi_client/lib/core/widgets/safe_network_avatar.dart`) that normalizes image URLs via `AppConstants.normalizeCloudMediaUrl`, attaches `onBackgroundImageError` to `CircleAvatar`, and falls back to initial letters or a `PhosphorIcon` (`Key('safe_network_avatar_fallback')`) on decode/network failure. `explore_social_post_card.dart:396` **SHALL** use `SafeNetworkAvatar`, and `pill_form.dart:111` **SHALL** normalize `track.coverUrl` and bound `PaletteGenerator.fromImageProvider` with a 4-second timeout and `onError` listener.

---

## 5. Layer 4 Requirements — `JsonSafe`, Per-Record Hive Quarantine, WebSocket Timeout & `DioException` Classification (`REQ-P65-L4-*`)

### `REQ-P65-L4-01` — `JsonSafe` Defensive Parsing Utility (`P5-02`)
The client **SHALL** provide `JsonSafe` (`apps/vhunambi_client/lib/core/utils/json_safe.dart`) exposing `decodeMap`, `decodeList`, `asMap`, `asList`, `asString`, `asInt`, `asDouble`, and `asBool` that never throw `FormatException` or `TypeError` on `null`, primitive, or mismatched JSON values.

### `REQ-P65-L4-02` — Per-Record Hive Box Quarantine (`P5-03`)
WHEN `WalletLedgerRepository.loadWalletSnapshot()`, `SocialReelsCacheRepository`, or `MarketplaceCatalogCacheRepository` in `sovereign_domain_repositories.dart` iterates over stored Hive records, each individual record (`tx_*`, `reel_comments_*`, `listing_*`) **SHALL** be decoded inside its own per-record `try/catch` via `JsonSafe.decodeMap` so that a single corrupted Hive entry is quarantined and skipped without aborting the rest of the wallet or catalog snapshot.

### `REQ-P65-L4-03` — Bounded WebSocket Handshake & Atomic Subscription Cleanup (`P5-01`)
WHEN `GenerationSocketService._doConnect(generationId)` opens a WebSocket connection, it **SHALL** atomically cancel any prior `_socketSubscription` and `_pingTimer` before connecting, apply a `connectTimeout = const Duration(seconds: 8)` to `WebSocket.connect(...)`, and wrap the periodic heartbeat `socket.add(...)` call inside a `try/catch` block that schedules a clean reconnect on socket write failure.

### `REQ-P65-L4-04` — Direct `DioException` Classification in `NetworkErrorHandler` (`P5-04`)
WHEN `NetworkErrorHandler.classify(Object error)` (`error_handler.dart`) evaluates an exception, it **SHALL** accept `Object` (not only `Exception`) and directly map `DioException` types (`connectionTimeout`, `sendTimeout`, `receiveTimeout` -> `ErrorType.timeout`; `connectionError` -> `ErrorType.noConnection`; `badResponse` status codes `401`, `403`, `404`, `4xx`, `5xx`) into their corresponding `ErrorType` values.

---

## 6. Layer 5 Requirements — Backend `GlobalErrorBoundary`, True PNG/WAV MIME Parity & Studio Parameter Fidelity (`REQ-P65-L5-*`)

### `REQ-P65-L5-01` — Hono Global `onError` & `notFound` JSON Envelope (`P6-01`)
In `apps/vhunambi_api/src/server.ts`, the Hono `app` instance **SHALL** register `app.onError((err, c) => ...)` and `app.notFound((c) => ...)` returning a structured JSON envelope `{ success: false, errorCode, message, path, timestamp }` with appropriate HTTP status (`500` or `statusCode` from error, and `404` for unknown routes).

### `REQ-P65-L5-02` — True RFC-2083 PNG Synthesis & 24-Second Tiled Stereo WAV Parity (`P6-02`)
WHEN `synthesizeAndCacheMissingR2Object(cleanKey)` (`r2_media_synthesizer.ts`) or `visionRoutes` (`vision_routes.ts`) serves a `.png` key, it **SHALL** return genuine RFC-2083 PNG bytes (`\x89PNG\r\n\x1a\n` magic bytes with valid CRC32-checked `IHDR`, `zlib.deflateSync` `IDAT`, and `IEND` chunks) with `Content-Type: image/png`. WHEN `synthesizeAndCacheMissingR2Object` or `synthesizeTrackStemPackWav` generates master/preview audio, it **SHALL** tile the synthesized stereo WAV buffer to **24 seconds** (`masterDurationSec = 24`) so tracks do not cut off after 3–4 seconds.

### `REQ-P65-L5-03` — Active Studio Form Priority Over Creator DNA Defaults (`P6-03`)
WHEN `StudioPromptIntelligence.enhance(String rawPrompt, {CreatorDnaProfile? dna, StudioFormState? currentForm})` is invoked from `PromptInputBox._runPromptIntelligence()` or `_applyDnaPrefill()`, any genre, language, or mood selected in `currentForm` (such as `90s Kwaito` or `Tshivenda` / `Tshivenḓa`) **SHALL** take precedence over `CreatorDnaProfile` fallback defaults (`Afro Soul` / `English`), and `StudioView._applyDnaDefaults()` **SHALL** only backfill fields when the user has not modified the form in the current session.

### `REQ-P65-L5-04` — Authentic Cultural Lyrics Synthesis Without Raw Prompt Echoing (`P6-04`)
WHEN `generateLocalMockLyrics(prompt, genre, language)` executes in `apps/vhunambi_api/src/modules/lyrics/llm_handler.ts`, it **SHALL** compose singable, culturally grounded stanzas (`[INTRO]`, `[VERSE 1]`, `[PRE-CHORUS]`, `[CHORUS]`, `[VERSE 2]`, `[BRIDGE]`, `[OUTRO]`) in the requested language (`Tshivenḓa`, `isiZulu`, `isiXhosa`, `Sesotho`, `Sepedi`, `Setswana`, `Xitsonga`, `Swahili`, `Shona`, or `English`) and **SHALL NOT** interpolate the user's raw prompt instruction string verbatim into stanza lines.

### `REQ-P65-L5-05` — GPU LoRA & FFmpeg Diagnostic Telemetry (`P6-05`)
WHEN `tools/zr-studio-gpu/model_utils.py` or `tools/zr-studio-gpu/mmo_extractor.py` encounters a LoRA download/load failure or an `ffmpeg` MP3 encoding error, it **SHALL** log a structured `[ZR-WARN]` diagnostic message rather than swallowing the exception silently with `pass`.

---

## 7. Non-Functional & Performance Requirements (`REQ-P65-NFR-*`)

- **`REQ-P65-NFR-01` (Cloudflare Worker CPU Budget)**: Synthesizing a 64×64 or 128×128 compressed PNG cover and a 24-second tiled stereo WAV buffer in `r2_media_synthesizer.ts` **SHALL** complete in $< 8\text{ ms}$ combined CPU time via lookup tables and block `Uint8Array.set` copies.
- **`REQ-P65-NFR-02` (Zero Raw Emojis — `STD-UIUX-001`)**: All new Phase 65 Dart widgets (`VhunambiSafeErrorCard`, `SafeNetworkAvatar`) **SHALL** use `PhosphorIcon` vector glyphs and `AppColors` / `AppTypography` tokens with zero raw unicode emojis.
- **`REQ-P65-NFR-03` (Headless Test Determinism)**: All Phase 65 Dart and TypeScript resilience components **SHALL** be 100% testable in headless `flutter test` and `vitest` environments without requiring live hardware codecs or external network access.

---

## 8. Requirement-to-Test Traceability Matrix

```
+-------------------+-----------------------------------------------+---------------------------------------------------+
| Requirement ID    | Target Implementation File(s)                 | Automated Verification Test Case                  |
+-------------------+-----------------------------------------------+---------------------------------------------------+
| REQ-P65-L1-01     | res/drawable/ic_stat_music.xml, Manifest      | phase65_foundation_crash_immunity_test.dart (T1)  |
| REQ-P65-L1-02     | vhunambi_crash_shield.dart, main.dart         | phase65_foundation_crash_immunity_test.dart (T2)  |
| REQ-P65-L1-03     | vhunambi_crash_shield.dart                    | phase65_foundation_crash_immunity_test.dart (T3)  |
| REQ-P65-L1-04     | vhunambi_crash_shield.dart, main.dart         | phase65_foundation_crash_immunity_test.dart (T4)  |
| REQ-P65-L2-01     | safe_audio_orchestrator.dart                  | phase65_foundation_crash_immunity_test.dart (T5)  |
| REQ-P65-L2-02     | generation_pipeline_providers.dart            | phase65_foundation_crash_immunity_test.dart (T6)  |
| REQ-P65-L2-03     | just_audio_multi_stem_engine.dart             | phase65_foundation_crash_immunity_test.dart (T7)  |
| REQ-P65-L2-04     | player_provider.dart, app_constants.dart      | phase65_foundation_crash_immunity_test.dart (T8)  |
| REQ-P65-L2-05     | vhunambi_audio_handler.dart, player_provider  | phase65_foundation_crash_immunity_test.dart (T9)  |
| REQ-P65-L3-01     | main.dart, mini_player_host.dart              | phase65_foundation_crash_immunity_test.dart (T10) |
| REQ-P65-L3-02     | expanded_cockpit_modal.dart, studio_action    | phase65_foundation_crash_immunity_test.dart (T11) |
| REQ-P65-L3-03     | safe_notifier_mixin.dart + 14 Notifiers       | phase65_foundation_crash_immunity_test.dart (T12) |
| REQ-P65-L3-04     | safe_network_avatar.dart, explore_social_post | phase65_foundation_crash_immunity_test.dart (T13) |
| REQ-P65-L4-01     | json_safe.dart                                | phase65_foundation_crash_immunity_test.dart (T14) |
| REQ-P65-L4-02     | sovereign_domain_repositories.dart            | phase65_foundation_crash_immunity_test.dart (T15) |
| REQ-P65-L4-03     | generation_socket_service.dart                | phase65_foundation_crash_immunity_test.dart (T16) |
| REQ-P65-L4-04     | error_handler.dart                            | phase65_foundation_crash_immunity_test.dart (T17) |
| REQ-P65-L5-01     | apps/vhunambi_api/src/server.ts               | phase65_foundation_resilience.test.ts (B1)        |
| REQ-P65-L5-02     | r2_media_synthesizer.ts, vision_routes.ts     | phase65_foundation_resilience.test.ts (B2, B3)    |
| REQ-P65-L5-03     | studio_prompt_intelligence.dart, prompt_input | phase65_foundation_crash_immunity_test.dart (T18) |
| REQ-P65-L5-04     | apps/vhunambi_api/src/modules/lyrics/llm_*.ts | phase65_foundation_resilience.test.ts (B4)        |
| REQ-P65-L5-05     | tools/zr-studio-gpu/model_utils.py, mmo_*.py  | phase65_foundation_resilience.test.ts (B5)        |
+-------------------+-----------------------------------------------+---------------------------------------------------+
```

