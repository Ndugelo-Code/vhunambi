# Phase 9 Requirements: Production Audio Engine Hardware Bridge & Platform Services

> **Target Package:** `apps/vhunambi_client`  
> **Standard:** EARS (Easy Approach to Requirements Syntax) & RFC 2119 (`MUST`, `SHALL`, `SHOULD`, `MAY`)  
> **Parent Foundation Blueprint:** [`docs/foundation_blueprints/07_AUDIO_TRANSPORT_AND_PIPELINE_MODALS_SPEC.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/foundation_blueprints/07_AUDIO_TRANSPORT_AND_PIPELINE_MODALS_SPEC.md)  
> **Architectural Blueprint:** [`docs/phases/phase_09_hardware_audio_bridge/blueprint.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_09_hardware_audio_bridge/blueprint.md)  

---

## 1. Platform Audio Handler Requirements

### REQ-AUD-01: BaseAudioHandler Platform Registration & Initialization
* The system **MUST** provide an implementation of `audio_service`'s `BaseAudioHandler` named `VhunambiAudioHandler` implementing `IVhunambiAudioHandler`.
* The initialization process **MUST** register the audio handler with the host OS platform service using `AudioService.init()`.
* The service **MUST** define notification channel properties:
  - Channel ID: `com.vhunambi.app.audio`
  - Channel Name: `"Vhunambi Music Playback"`
  - Channel Description: `"African AI Music Synthesis & Creator Playback"`
  - Android Notification Icon: `drawable/ic_stat_music` or fallback standard icon.

### REQ-AUD-02: Headless & Automated Test Safety
* The audio handler **MUST** provide safe execution during automated unit tests (`flutter test`) and headless CI environments where native platform channels are absent.
* In environments where `AudioService.init()` fails due to `MissingPluginException` or headless test execution, the system **MUST** automatically activate an in-memory test handler fallback (`TestVhunambiAudioHandler`) without throwing unhandled exceptions.
* The test handler **MUST** fulfill all contract methods of `IVhunambiAudioHandler` and emit reactive state updates through Dart streams.

---

## 2. Audio Metadata & Playback State Synchronization Requirements

### REQ-AUD-03: MediaItem Metadata Synchronization
* When a track begins playback or is loaded into the active player slot, the system **MUST** publish an updated `MediaItem` to `audio_service`.
* The `MediaItem` **MUST** include:
  1. `id`: The unique Vhunambi track identifier.
  2. `title`: The track title.
  3. `artist`: The creator's name or handle.
  4. `album`: The regional genre (e.g. `"Amapiano"`, `"Gqom"`, `"Afro House"`).
  5. `duration`: The duration of the track.
  6. `artUri`: URI pointing to local artwork or CDN thumbnail.
  7. `displayTitle`: Formatted title with regional attribution.
  8. `displaySubtitle`: Genre and language metadata string.

### REQ-AUD-04: OS PlaybackState Synchronization
* The system **MUST** publish real-time `PlaybackState` events to the operating system whenever playback status, position, or speed changes.
* The published `PlaybackState` **MUST** specify:
  1. `processingState`: Mapped cleanly from Vhunambi's `PlaybackStatus` (`idle`, `buffering`, `ready`, `completed`, `error`).
  2. `playing`: Boolean indicating whether audio is currently rendering.
  3. `updatePosition`: Current playback timestamp.
  4. `bufferedPosition`: Current buffered media position.
  5. `speed`: Current playback rate multiplier (`0.75x`, `1.0x`, `1.25x`, `1.5x`).
  6. `controls`: Supported transport action controls (Play, Pause, Skip Next, Skip Previous, Stop, Seek).

---

## 3. Remote Control Command Dispatch Requirements

### REQ-AUD-05: Native OS Remote Command Execution
* When an external control event is triggered from the Android Notification Shade, iOS Lock Screen, Apple Watch, or Desktop SMTC, the system **MUST** process the command and dispatch it to the audio engine:
  - `play()`: Resume or start audio playback.
  - `pause()`: Suspend audio playback.
  - `stop()`: Halt audio playback and dismiss the active notification session.
  - `skipToNext()`: Advance to the next track in the current playlist queue.
  - `skipToPrevious()`: Return to the previous track or restart the current track if elapsed $> 3$ seconds.
  - `seek(Duration position)`: Seek audio playback to the specified timestamp.
  - `setSpeed(double speed)`: Adjust playback rate.
  - `setRepeatMode(AudioServiceRepeatMode repeatMode)`: Adjust repeat mode.

---

## 4. Hardware Audio Session & Interruption Management Requirements

### REQ-AUD-06: Audio Session Configuration & Priority
* The system **MUST** initialize and configure `AudioSession.instance` before initiating audio output.
* The audio session configuration **MUST** specify:
  - Category: `AudioSessionCategory.playback` (music playback).
  - Mode: `AudioSessionMode.default`.
  - Android Audio Attributes: `AndroidAudioAttributes(contentType: AndroidAudioContentType.music, usage: AndroidAudioUsage.media)`.
  - Will duck others: `false` (music is primary audio, not background chime).

### REQ-AUD-07: Audio Interruption Handling (Telephony & System Alerts)
* The system **MUST** listen to `session.interruptionEventStream` and respond dynamically:
  - When an interruption begins (e.g. incoming cellular phone call, VoIP call, Siri activation):
    - If audio was playing, the system **MUST** pause playback and mark an internal flag `wasPlayingBeforeInterruption = true`.
  - When the interruption ends:
    - If `wasPlayingBeforeInterruption == true` and the interruption type indicates resumption is permitted, the system **MUST** automatically resume playback.

### REQ-AUD-08: "Becoming Noisy" Protection (Headphone Disconnect)
* The system **MUST** subscribe to `session.becomingNoisyEventStream`.
* When a wired headphone is unplugged or a bluetooth audio peripheral disconnects:
  - The system **MUST** immediately pause audio playback.
  - The system **MUST NOT** auto-resume until the user explicitly triggers a play action, preventing accidental loud broadcast in public environments.

---

## 5. Hybrid Audio Source Resolution Requirements

### REQ-AUD-09: Offline Vault Priority Resolution
* When requested to play a track, the `AudioSourceResolver` **MUST** check Phase 8's `IOfflineStorageService`:
  - If the track exists in the local Hive cache and the local decrypted binary file is present on disk, the system **MUST** create a local `AudioSource.file(localPath)`.
  - If the track is not cached locally or the file is missing, the system **MUST** resolve to `AudioSource.uri(remoteUrl)`.
* In offline mode (`isOfflineModeForced == true`), attempting to play an uncached track **MUST** emit a clean `AudioSourceException` with clear user feedback rather than freezing or crashing.

---

## 6. Presentation State Integration Requirements

### REQ-AUD-10: Bi-directional Riverpod Synchronization
* The system **MUST** keep `playerStateProvider` (`PlayerNotifier`) bi-directionally synchronized with `VhunambiAudioHandler`:
  - UI user actions in `MobileMiniPlayer`, `DesktopTransportBar`, or `ExpandedCockpitModal` **MUST** delegate to the audio handler.
  - Hardware transport events from the lockscreen or bluetooth remotes **MUST** update `playerStateProvider`, causing UI controls to immediately reflect the new state.
