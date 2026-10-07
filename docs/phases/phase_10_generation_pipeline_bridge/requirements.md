# Phase 10 · Requirements — Audio Generation Pipeline Real-Time WebSocket Bridge & Result Panel

> **Phase:** 10  
> **Format:** EARS (Easy Approach to Requirements Syntax) + RFC 2119 (`SHALL` / `SHOULD` / `MAY`)  
> **Gating:** All requirements below are verified by tasks T10.1–T10.6; any failing test blocks the phase gate.

---

## FR-10.1 — Domain State Model (`generation_pipeline_state.dart`)

**FR-10.1.1** — The system SHALL define `PipelineStep` as an enum with exactly five values:  
`startingUp`, `writingLyrics`, `producingBeat`, `ready`, `failed`.

**FR-10.1.2** — The system SHALL define `PipelineSocketEvent` as an `@immutable` value class with fields:  
`generationId (String)`, `step (PipelineStep)`, `stepIndex (int)`, `progressPercent (double)`,  
`statusMessage (String)`, `generatedLyrics (String?)`, `completedTrack (TrackEntity?)`, `error (String?)`.

**FR-10.1.3** — `PipelineSocketEvent` SHALL implement `==`, `hashCode`, and `copyWith`.

**FR-10.1.4** — The system SHALL define `GenerationProgressState` as an `@immutable` value class with fields:  
`generationId`, `trackTitle`, `genre`, `currentStep (PipelineStep)`, `statusMessage`, `progressPercent`,  
`generatedLyrics (String?)`, `completedTrack (TrackEntity?)`, `errorMessage (String?)`.

**FR-10.1.5** — `GenerationProgressState` SHALL expose the following computed getters:  
- `bool get isGenerating` → `currentStep` is not `ready` and not `failed`  
- `bool get isReady` → `currentStep == PipelineStep.ready`  
- `bool get hasFailed` → `currentStep == PipelineStep.failed`

**FR-10.1.6** — `GenerationProgressState` SHALL implement `==`, `hashCode`, and full `copyWith`.

---

## FR-10.2 — WebSocket Service Interface & Implementation

**FR-10.2.1** — The system SHALL define `IGenerationSocketService` in `domain/services/` with:  
```dart
abstract class IGenerationSocketService {
  Stream<PipelineSocketEvent> connect(String generationId);
  Future<void> disconnect();
  bool get isConnected;
}
```

**FR-10.2.2** — `GenerationSocketService` (in `data/services/`) SHALL implement `IGenerationSocketService`  
using `dart:io`'s `WebSocket` API targeting `wss://api.vhunambi.com/ws/generation`.

**FR-10.2.3** — The service SHALL append the query parameter `?id=<generationId>` to the WebSocket URL on connection.

**FR-10.2.4** — WHEN the connection is established, the service SHALL begin sending a heartbeat `PING` frame  
every 25 seconds using a `Timer.periodic`.

**FR-10.2.5** — WHEN a `PONG` frame is not received within 10 seconds of a `PING`, the service SHALL close  
the socket and initiate a reconnection attempt.

**FR-10.2.6** — WHEN the socket disconnects unexpectedly, the service SHALL automatically reconnect using  
exponential backoff: delays of 1 s, 2 s, 4 s, 8 s, 16 s, for a maximum of **5 attempts**.

**FR-10.2.7** — AFTER 5 failed reconnection attempts, the service SHALL close the stream with an error  
carrying the message `"MaxReconnectAttemptsExceeded"`.

**FR-10.2.8** — WHEN a raw WebSocket frame is received, the service SHALL parse it as JSON and emit  
a `PipelineSocketEvent` only when `type == "pipeline_event"`. All other frame types SHALL be silently  
discarded (except `ERROR` frames which SHALL emit a `failed`-step event).

**FR-10.2.9** — The service SHALL expose `disconnect()` as a graceful close that cancels the heartbeat timer  
and closes the underlying `WebSocket` connection with code `1000`.

**FR-10.2.10** — `FakeGenerationSocketService` SHALL implement `IGenerationSocketService` and emit a fixed  
sequence of `PipelineSocketEvent` objects on a `StreamController` with configurable per-step delays  
(defaulting to 200 ms between events).

---

## FR-10.3 — Riverpod Provider Layer (`generation_pipeline_providers.dart`)

**FR-10.3.1** — The system SHALL define `socketServiceProvider` as a `Provider<IGenerationSocketService>`,  
defaulting to `GenerationSocketService()`, overridable in tests with `FakeGenerationSocketService`.

**FR-10.3.2** — The system SHALL define `generationProgressProvider` as a  
`StateNotifierProvider<GenerationPipelineNotifier, GenerationProgressState?>`.

**FR-10.3.3** — `GenerationPipelineNotifier` SHALL expose the method:  
```dart
Future<void> startGeneration({
  required String generationId,
  required String trackTitle,
  required String genre,
});
```

**FR-10.3.4** — WHEN `startGeneration` is called, the notifier SHALL:  
1. Set state to `GenerationProgressState(currentStep: PipelineStep.startingUp, ...)`  
2. Call `socketService.connect(generationId)`  
3. Listen to the returned `Stream<PipelineSocketEvent>` and call `_applyEvent(event)` for each emission.

**FR-10.3.5** — `_applyEvent(PipelineSocketEvent)` SHALL update `state` via `copyWith` to reflect the  
event's `step`, `statusMessage`, `progressPercent`, `generatedLyrics`, and `completedTrack`.

**FR-10.3.6** — WHEN `event.step == PipelineStep.ready`, the notifier SHALL:  
1. Update state to `isReady = true`  
2. Call `ref.read(stemDownloadServiceProvider).downloadMaster(completedTrack.masterMp3Url)`  
3. Append a `NotificationEntity` to `ref.read(notificationsProvider.notifier).state`  

**FR-10.3.7** — WHEN `event.step == PipelineStep.failed` OR the stream closes with an error, the notifier  
SHALL set `currentStep = PipelineStep.failed` and populate `errorMessage`.

**FR-10.3.8** — The notifier SHALL call `socketService.disconnect()` in its `dispose()` override to prevent  
socket leaks.

**FR-10.3.9** — The system SHALL define `notificationsProvider` as a  
`StateProvider<List<NotificationEntity>>` initialized with an empty list `[]`.

---

## FR-10.4 — Live `GenerationPipelineCard` Widget Binding

**FR-10.4.1** — `GenerationPipelineCard` SHALL be converted from a `StatefulWidget` with manually passed  
props to a `ConsumerStatefulWidget` that watches `generationProgressProvider`.

**FR-10.4.2** — WHEN `generationProgressProvider` is `null`, the card SHALL display a skeleton loading state  
(pulsing `AppColors.borderSubtle` bars at each step row).

**FR-10.4.3** — WHEN `state.currentStep` changes, the card's 4-step pipeline section SHALL update reactively  
without requiring a full widget rebuild (use `ref.watch`).

**FR-10.4.4** — The animated equalizer bars SHALL animate ONLY when `state.isGenerating == true` and SHALL  
pause (controller.stop()) when `state.isReady || state.hasFailed`.

**FR-10.4.5** — WHEN `state.isReady == true`, the Generation Badge SHALL change from `🔄 Generating`  
(amber spinner pill) to a `✅ Ready` (green filled pill with `AppColors.brandPrimary` border).

**FR-10.4.6** — WHEN `state.hasFailed == true`, the card SHALL display an inline error banner below the  
4-step section with the `errorMessage` text and a `🔄 Retry` button that calls `notifier.reset()`.

**FR-10.4.7** — The `⌄ Show lyrics` / `⌃ Hide lyrics` toggle SHALL only be visible WHEN  
`state.generatedLyrics != null`, displaying the actual `state.generatedLyrics` value (not hardcoded stub text).

**FR-10.4.8** — The card SHOULD apply a smooth `AnimatedSwitcher` (duration: 300 ms) when transitioning  
between the `isGenerating`, `isReady`, and `hasFailed` visual states.

---

## FR-10.5 — Stem Download Orchestrator

**FR-10.5.1** — The system SHALL define `IStemDownloadService` in `domain/services/` with:
```dart
abstract class IStemDownloadService {
  Stream<StemDownloadProgress> downloadMaster(String url);
  Stream<StemDownloadProgress> downloadStems(String url);
  Future<void> cancelDownload(String url);
}
```

**FR-10.5.2** — The system SHALL define `StemDownloadProgress` as an `@immutable` value class with fields:  
`url (String)`, `receivedBytes (int)`, `totalBytes (int)`, `localPath (String?)`, `error (String?)`.

**FR-10.5.3** — `StemDownloadProgress` SHALL expose:  
- `double get progress` → `receivedBytes / totalBytes` (0.0 when `totalBytes == 0`)  
- `bool get isComplete` → `localPath != null`  
- `bool get hasError` → `error != null`

**FR-10.5.4** — `StemDownloadService` SHALL write downloaded bytes to  
`(await getTemporaryDirectory()).path/vhunambi_downloads/<filename>`, creating directories as needed.

**FR-10.5.5** — WHEN `isComplete == true`, the service SHALL call  
`AudioSourceResolver.cacheLocalPath(url, localPath)` to register the file for offline playback.

**FR-10.5.6** — The system SHALL define `stemDownloadProvider` as a  
`Provider<IStemDownloadService>`, overridable in tests with `FakeStemDownloadService`.

**FR-10.5.7** — `FakeStemDownloadService.downloadMaster` SHALL emit 3 progress events  
(25 %, 75 %, 100 % complete) with a fake local path, within 50 ms total.

---

## FR-10.6 — In-App Notification Entity

**FR-10.6.1** — The system SHALL define `NotificationEntity` in  
`lib/features/notifications/domain/models/notification_entity.dart` as:
```dart
@immutable
class NotificationEntity {
  final String id;
  final String title;
  final String message;
  final String? targetTrackId;
  final DateTime createdAt;
  final bool isRead;
}
```

**FR-10.6.2** — `NotificationEntity` SHALL implement `==`, `hashCode`, and `copyWith`.

**FR-10.6.3** — WHEN a generation completes, the notifier SHALL prepend (not append) a new  
`NotificationEntity` to the `notificationsProvider` state list, so new notifications appear at the top.

**FR-10.6.4** — The notification `title` SHALL follow the pattern: `'Your song "<trackTitle>" is ready!'`

**FR-10.6.5** — The notification `targetTrackId` SHALL be set to `completedTrack.id`.

---

## NFR-10 — Non-Functional Requirements

**NFR-10.1** — All new Dart code SHALL pass `flutter analyze` with zero issues before phase gate.

**NFR-10.2** — The test suite SHALL maintain ≥ 254 passing tests. Phase 10 SHALL add ≥ 35 new tests.

**NFR-10.3** — No test SHALL make a real network connection. `FakeGenerationSocketService` and  
`FakeStemDownloadService` are mandatory for all socket and download tests.

**NFR-10.4** — `GenerationPipelineNotifier.dispose()` SHALL be verified by a test that confirms  
`socketService.disconnect()` is called when the provider is disposed.

**NFR-10.5** — All `@immutable` model classes SHALL have 100 % field coverage in their `copyWith` tests  
(every field exercised at least once across the test suite for that class).

**NFR-10.6** — The `GenerationPipelineCard` widget tests SHALL NOT require a real `WebSocket` — all socket  
interactions SHALL be simulated via `FakeGenerationSocketService` provider overrides.
