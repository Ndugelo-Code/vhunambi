# Phase 9 Tasks: Production Audio Engine Hardware Bridge & Platform Services

> **Target Package:** `apps/vhunambi_client`  
> **Parent Foundation Blueprint:** [`docs/foundation_blueprints/07_AUDIO_TRANSPORT_AND_PIPELINE_MODALS_SPEC.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/foundation_blueprints/07_AUDIO_TRANSPORT_AND_PIPELINE_MODALS_SPEC.md)  
> **Architectural Blueprint:** [`docs/phases/phase_09_hardware_audio_bridge/blueprint.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_09_hardware_audio_bridge/blueprint.md)  
> **Requirements Reference:** [`docs/phases/phase_09_hardware_audio_bridge/requirements.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_09_hardware_audio_bridge/requirements.md)  
> **Design Reference:** [`docs/phases/phase_09_hardware_audio_bridge/design.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_09_hardware_audio_bridge/design.md)  

---

## Pre-Flight Check

- [x] Run `dart analyze .` in `apps/vhunambi_client` $\rightarrow$ 0 issues found.
- [x] Run `flutter test` $\rightarrow$ 207/207 baseline tests passing (100%).
- [x] Verify dependencies: `audio_service`, `audio_session`, and `just_audio` present in `pubspec.yaml`.

---

## Implementation Tasks

### T9.1: Audio Domain & Service Contracts
- [x] Create `lib/features/player/domain/models/audio_session_events.dart`:
  - `AudioInterruptionType` enum (`pause`, `duck`).
  - `AudioInterruptionEvent` model (`isInterrupted`, `type`, `shouldResume`).
  - `BecomingNoisyEvent` model.
- [x] Define abstract service contracts:
  - `IVhunambiAudioHandler` in `lib/features/player/data/services/vhunambi_audio_handler.dart`.
  - `IAudioSessionManager` in `lib/features/player/data/services/audio_session_manager.dart`.
  - `IAudioSourceResolver` in `lib/features/player/data/services/audio_source_resolver.dart`.

### T9.2: Audio Source Resolver (Hybrid Offline/Cloud Pipeline)
- [x] Implement `AudioSourceResolver` in `lib/features/player/data/services/audio_source_resolver.dart`:
  - Connect to Phase 8 `IOfflineStorageService`.
  - Check local disk availability for `cachedLocally` vault tracks.
  - Return `ResolvedAudioSource` (`uri`, `isLocalFile`, `localFilePath`).
  - Fallback to remote CDN stream when file is not cached locally.
  - Wrap with `DeferredAudioSourceResolver` to prevent eager Hive boot in test harnesses.

### T9.3: Audio Session Lifecycle Manager
- [x] Implement `AudioSessionManager` in `lib/features/player/data/services/audio_session_manager.dart`:
  - Configure `AudioSession.instance` for music playback.
  - Interruption listener: pause on incoming calls, set `wasPlayingBeforeInterruption`, auto-resume when call clears.
  - "Becoming Noisy" listener: immediate pause on headphone/bluetooth disconnect.
- [x] Implement `TestAudioSessionManager` for headless and unit test environments.

### T9.4: Platform Audio Handler Implementation
- [x] Implement `VhunambiAudioHandler` extending `BaseAudioHandler`:
  - Register notification channel and metadata mappings (`Track` $\rightarrow$ `MediaItem`).
  - Sync `PlaybackStatus` and position to `PlaybackState`.
  - Handle remote actions: `play`, `pause`, `stop`, `seek`, `skipToNext`, `skipToPrevious`, `setSpeed`, `setRepeatMode`, `setVhunambiRepeatMode`.
- [x] Implement `TestVhunambiAudioHandler` providing complete in-memory behavior for headless test runners.
- [x] Implement `bootstrapPlatformAudioHandler` with `MissingPluginException` fallback.
- [x] Configure native platforms: Android manifest & activity, iOS `Info.plist` background modes.

### T9.5: Riverpod Providers & `PlayerNotifier` Integration
- [x] Create `lib/features/player/presentation/providers/audio_bridge_providers.dart`:
  - `audioSourceResolverProvider`
  - `audioSessionManagerProvider`
  - `audioHandlerProvider`
- [x] Update `PlayerNotifier` in `lib/features/player/presentation/providers/player_provider.dart`:
  - Accept `IVhunambiAudioHandler` dependency (with default fallback for backwards compatibility).
  - Subscribe to `audioHandler.playbackState` and `audioHandler.mediaItem`.
  - Delegate user UI controls (play, pause, seek, skip) to `audioHandler`.
  - Synchronous UI mutations + unawaited hardware dispatch + echo-suppression.

### T9.6: Automated Testing Suite
- [x] Create `test/features/player/audio_source_resolver_test.dart` (9 tests):
  - Local cached path resolution vs. remote stream fallback, forced offline failure.
- [x] Create `test/features/player/audio_session_manager_test.dart` (13 tests):
  - Interruption handling, telephony state tracking, becoming noisy auto-pause.
- [x] Create `test/features/player/vhunambi_audio_handler_test.dart` (17 tests):
  - MediaItem mapping, playback state emissions, queue navigation, repeat mode mapping.
- [x] Create `test/features/player/player_hardware_bridge_test.dart` (8 tests):
  - Bi-directional sync between Riverpod and audio handler, seek tolerance.

### T9.7: Verification Gates & Handoff Sign-off
- [x] Run `dart analyze .` $\rightarrow$ 0 issues found.
- [x] Run `flutter test` $\rightarrow$ 254/254 passing tests (207 baseline + 47 new tests, 100%).
- [x] Update `docs/AGENT_HANDOFF_BIBLE.md` and `README.md`.
- [x] Create `docs/phases/phase_09_hardware_audio_bridge/walkthrough.md`.
