# Phase 9 Master Handoff: Production Audio Engine Hardware Bridge & Platform Services

> **Document Purpose:** Single authoritative handoff guide for any agent (Antigravity / Cline / Cursor) implementing Phase 9. Read this first — it captures exact requirements, architectural invariants, code designs, and the execution checklist.
>
> **Generated At:** 2026-09-26T01:32:00+02:00  
> **Lead Architect:** Antigravity (Dual-Agent Symbiosis Protocol)  
> **Repository Root:** `c:\Users\Ndugelo\VHUNAMBI\monorepo\`  
> **Client Workspace:** `apps/vhunambi_client/`  
> **Current Health:** `dart analyze .` = **0 issues** | `flutter test` = **207/207 passing (100%)**  
> **Target Test Count:** **225+ tests (18+ new tests)**  

---

## 1. Phase 9 Objectives & Scope

Bridge Vhunambi's persistent audio player into native operating system media services:
1. **Platform Audio Service Handler (`BaseAudioHandler`):**
   - Android `MediaSession` & `NotificationCompat.MediaStyle` controls with album artwork.
   - iOS `MPNowPlayingInfoCenter` & `MPRemoteCommandCenter` controls.
   - Desktop (Windows / macOS) SMTC & media key integration.
2. **Audio Session Lifecycle & Focus Management (`audio_session`):**
   - Music playback configuration (`AudioSessionConfiguration.music()`).
   - Interruption handling (pause during incoming telephony calls, auto-resume after call ends).
   - "Becoming Noisy" protection (immediate pause when headphones or bluetooth audio disconnects).
3. **Hybrid Audio Source Resolution:**
   - Seamless routing to local decrypted files cached in Phase 8's Hive vault (`IOfflineStorageService`), with fallback to remote streaming URLs.
4. **Bi-directional Riverpod Integration:**
   - `playerStateProvider` delegates transport commands (`play`, `pause`, `seek`, `skip`) to `IVhunambiAudioHandler`.
   - OS lockscreen/headphone remote events update `PlayerState` reactively.

---

## 2. Specification Documents (Single Source of Truth)

Read and adhere to all 4 documents in `docs/phases/phase_09_hardware_audio_bridge/`:
- [`blueprint.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_09_hardware_audio_bridge/blueprint.md)
- [`requirements.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_09_hardware_audio_bridge/requirements.md)
- [`design.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_09_hardware_audio_bridge/design.md)
- [`tasks.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_09_hardware_audio_bridge/tasks.md)

---

## 3. Codebase Invariants (NEVER BREAK THESE)

1. **Zero Raw Hex Values:** Always use `AppColors.*`, `AppGradients.*`, `AppTypography.*`, `AppRadius.*`, `AppSpacing.*`.
2. **`AudioRepeatMode` not `RepeatMode`:** Flutter 3.44 exports a conflicting `RepeatMode` enum.
3. **Headless Test Safety (CRITICAL):**
   - `AudioService.init()` and native platform channels throw `MissingPluginException` in headless `flutter test`.
   - You **MUST** provide `TestVhunambiAudioHandler` and `TestAudioSessionManager` as clean in-memory fallbacks so tests never fail due to platform channels.
4. **Zero Regressions:** All 207 baseline tests must continue to pass cleanly.
5. **Immutable State:** Domain models are `@immutable` and updated exclusively via `copyWith`.

---

## 4. Implementation Steps by Task

### T9.1: Audio Domain & Service Contracts
* File: `lib/features/player/domain/models/audio_session_events.dart`
  - `enum AudioInterruptionType { pause, duck }`
  - `class AudioInterruptionEvent { final bool isInterrupted; final AudioInterruptionType type; final bool shouldResume; ... }`
  - `class BecomingNoisyEvent { final DateTime timestamp; ... }`

### T9.2: Audio Source Resolver
* File: `lib/features/player/data/services/audio_source_resolver.dart`
  - `abstract class IAudioSourceResolver`
  - `class ResolvedAudioSource` (`uri`, `isLocalFile`, `localFilePath`)
  - `class AudioSourceResolver implements IAudioSourceResolver`: queries `offlineStorage.isTrackCachedLocally(track.id)` and verifies `File(localPath).existsSync()`.

### T9.3: Audio Session Lifecycle Manager
* File: `lib/features/player/data/services/audio_session_manager.dart`
  - `abstract class IAudioSessionManager`
  - `class AudioSessionManager implements IAudioSessionManager`: wraps `AudioSession.instance`, sets `AudioSessionConfiguration.music()`, listens to `interruptionEventStream` and `becomingNoisyEventStream`.
  - `class TestAudioSessionManager implements IAudioSessionManager`: headless test safe in-memory simulator.

### T9.4: Platform Audio Handler
* File: `lib/features/player/data/services/vhunambi_audio_handler.dart`
  - `abstract class IVhunambiAudioHandler`
  - `class VhunambiAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler implements IVhunambiAudioHandler`
  - `class TestVhunambiAudioHandler implements IVhunambiAudioHandler`: complete in-memory behavior avoiding platform channels.

### T9.5: Riverpod Providers & `PlayerNotifier` Hardware Bridge
* File: `lib/features/player/presentation/providers/audio_bridge_providers.dart`:
  - `audioSourceResolverProvider = Provider<IAudioSourceResolver>(...)`
  - `audioSessionManagerProvider = Provider<IAudioSessionManager>(...)`
  - `audioHandlerProvider = Provider<IVhunambiAudioHandler>(...)`
* File: `lib/features/player/presentation/providers/player_provider.dart`:
  - Update `PlayerNotifier` constructor to accept optional `IVhunambiAudioHandler` (defaulting to `TestVhunambiAudioHandler()` when null).
  - Sync playback states and wire UI controls to audio handler.

### T9.6: Automated Testing Suite
* Create: `test/features/player/audio_source_resolver_test.dart` (5+ tests)
* Create: `test/features/player/audio_session_manager_test.dart` (5+ tests)
* Create: `test/features/player/vhunambi_audio_handler_test.dart` (7+ tests)
* Create: `test/features/player/player_hardware_bridge_test.dart` (5+ tests)

### T9.7: Verification Gates & Sign-Off
* Run `dart analyze .` $\rightarrow$ 0 issues found.
* Run `flutter test` $\rightarrow$ 225+ tests passing (100%).

---

## 5. Cline Prompt for Execution

```
You are executing Phase 9 of the Vhunambi client (apps/vhunambi_client): Production Audio Engine Hardware Bridge & Platform Services.

PRE-FLIGHT STATUS:
- Working directory: apps/vhunambi_client
- dart analyze . -> 0 issues found
- flutter test -> 207 of 207 tests passed (100%)

SPECIFICATIONS:
Read docs/phases/phase_09_hardware_audio_bridge/blueprint.md, requirements.md, design.md, tasks.md.

TASKS TO EXECUTE:
1. Create lib/features/player/domain/models/audio_session_events.dart (T9.1)
2. Create lib/features/player/data/services/audio_source_resolver.dart (T9.2)
3. Create lib/features/player/data/services/audio_session_manager.dart (T9.3)
4. Create lib/features/player/data/services/vhunambi_audio_handler.dart (T9.4)
5. Create lib/features/player/presentation/providers/audio_bridge_providers.dart and update player_provider.dart (T9.5)
6. Create test suite in test/features/player/ (T9.6):
   - audio_source_resolver_test.dart
   - audio_session_manager_test.dart
   - vhunambi_audio_handler_test.dart
   - player_hardware_bridge_test.dart

CRITICAL INVARIANTS:
- Zero raw hex values (use AppColors.*)
- AudioRepeatMode not RepeatMode
- Test safety: TestVhunambiAudioHandler and TestAudioSessionManager must be headless safe with zero MissingPluginException
- All 207 baseline tests must keep passing (zero regressions)

VERIFICATION GATES:
- dart analyze . (0 issues)
- flutter test (225+ passing tests)
```
