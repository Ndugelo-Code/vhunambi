# Phase 10 · Tasks — Audio Generation Pipeline Real-Time WebSocket Bridge & Result Panel

> **Phase:** 10  
> **Total Tasks:** 6 (T10.1 – T10.6)  
> **Execution order:** Sequential (each task's test gate must be green before the next begins)  
> **Phase Gate:** `flutter analyze` (0 issues) + `flutter test` (≥ 289 tests passed, 0 regressions)

---

## Pre-flight Checklist

Run these before writing any code:

```pwsh
# In apps/vhunambi_client/
flutter analyze
flutter test
```

Expected baseline: **0 issues / 254 tests passing**.

---

## T10.1 — Domain Models: `PipelineSocketEvent` & `GenerationProgressState`

**Files to create:**
- `lib/features/studio/domain/models/generation_pipeline_state.dart`
- `lib/features/studio/domain/models/stem_download_progress.dart`

**Files to create (tests):**
- `test/features/studio/domain/models/generation_pipeline_state_test.dart`

### Implementation Steps

1. Create `generation_pipeline_state.dart` with exact class signatures from `design.md §T10.1`.
2. Create `stem_download_progress.dart` with exact class signatures from `design.md §T10.5`.
3. Ensure `PipelineStep` enum values: `startingUp`, `writingLyrics`, `producingBeat`, `ready`, `failed`.
4. Ensure both models are `@immutable` with `==`, `hashCode`, `copyWith`.
5. Do NOT modify `studio_form_state.dart` — `PipelineStep` is a separate enum from `GenerationPhase`.

### Test Cases (≥ 12 tests)

```
PipelineSocketEvent:
  ✓ fromJson parses all fields correctly (step=starting_up)
  ✓ fromJson parses step=ready with completedTrack populated
  ✓ fromJson maps unknown step string to PipelineStep.failed
  ✓ copyWith returns new instance with changed step
  ✓ == true for same generationId + step + stepIndex + progressPercent
  ✓ == false when progressPercent differs

GenerationProgressState:
  ✓ isGenerating true for startingUp / writingLyrics / producingBeat
  ✓ isGenerating false for ready
  ✓ isGenerating false for failed
  ✓ isReady true only for ready
  ✓ hasFailed true only for failed
  ✓ copyWith updates currentStep without altering other fields

StemDownloadProgress:
  ✓ progress = 0.0 when totalBytes == 0
  ✓ progress = receivedBytes / totalBytes
  ✓ isComplete true when localPath != null
  ✓ hasError true when error != null
```

### T10.1 Gate

```pwsh
flutter test test/features/studio/domain/models/generation_pipeline_state_test.dart
```

---

## T10.2 — WebSocket Service Interface & Implementation

**Files to create:**
- `lib/features/studio/domain/services/i_generation_socket_service.dart`
- `lib/features/studio/data/services/generation_socket_service.dart`
- `lib/features/studio/data/services/fake_generation_socket_service.dart`

**Files to create (tests):**
- `test/features/studio/data/services/generation_socket_service_test.dart`

### Implementation Steps

1. Create `IGenerationSocketService` interface exactly as specified in `design.md §T10.2`.
2. Create `GenerationSocketService` with `WebSocket.connect`, heartbeat timer, reconnection logic.
3. Create `FakeGenerationSocketService` that emits the 4-step deterministic sequence (see `design.md §T10.2`).
4. Verify `_stepFromString` handles all 5 step values including the `default → failed` fallback.

### Implementation Notes

- Import `dart:io` for `WebSocket`. Add `dart:async` and `dart:convert`.
- The `data/` directory must be created: `lib/features/studio/data/services/`.
- `FakeGenerationSocketService` lives in `lib/features/studio/data/services/` NOT under `test/` — it is shared by both widget and unit tests.
- The `fake_generation_socket_service.dart` file MUST remain compilable in production builds (no `flutter_test` imports).

### Test Cases (≥ 8 tests)

```
FakeGenerationSocketService:
  ✓ connect() emits exactly 4 events in order: startingUp → writingLyrics → producingBeat → ready
  ✓ first event has progressPercent == 0.15
  ✓ last event has step == PipelineStep.ready
  ✓ isConnected becomes false after stream completes
  ✓ disconnect() sets isConnected to false immediately

GenerationSocketService (unit tests with mock WebSocket — use mockito or manual mock):
  ✓ connect() calls WebSocket.connect with correct URL including ?id= param
  ✓ _stepFromString('unknown') returns PipelineStep.failed
  ✓ after maxAttempts exceeded, stream emits addError
```

### T10.2 Gate

```pwsh
flutter test test/features/studio/data/services/generation_socket_service_test.dart
```

---

## T10.3 — Riverpod Provider Layer (`generation_pipeline_providers.dart`)

**Files to create:**
- `lib/features/studio/presentation/providers/generation_pipeline_providers.dart`
- `lib/features/studio/presentation/providers/stem_download_provider.dart`

**Files to create (tests):**
- `test/features/studio/presentation/providers/generation_pipeline_providers_test.dart`

### Implementation Steps

1. Create `generation_pipeline_providers.dart` with exact signatures from `design.md §T10.3`.
2. Create `stem_download_provider.dart` (single `Provider<IStemDownloadService>` line).
3. Create `notificationsProvider` as `StateProvider<List<NotificationEntity>>` initialized to `[]`.
4. Wire `GenerationPipelineNotifier.dispose()` → `socketService.disconnect()`.
5. Wire `_onGenerationComplete` → `stemDownloadServiceProvider.downloadMaster()` + notification prepend.

### Test Cases (≥ 10 tests)

```
GenerationPipelineNotifier:
  ✓ initial state is null
  ✓ startGeneration sets state to currentStep=startingUp
  ✓ after FakeSocketService emits writingLyrics event, state.currentStep == writingLyrics
  ✓ after FakeSocketService emits ready event, state.isReady == true
  ✓ after FakeSocketService emits ready event, notificationsProvider has 1 entry
  ✓ notification title matches pattern 'Your song "<title>" is ready!'
  ✓ notification.targetTrackId matches completedTrack.id
  ✓ stream error → state.hasFailed == true
  ✓ reset() sets state back to null
  ✓ dispose() calls socketService.disconnect() — verified via FakeSocketService.isConnected
```

### T10.3 Gate

```pwsh
flutter test test/features/studio/presentation/providers/generation_pipeline_providers_test.dart
```

---

## T10.4 — Live `GenerationPipelineCard` Widget Binding

**Files to modify:**
- `lib/features/studio/presentation/widgets/generation_pipeline_card.dart`

**Files to create (tests):**
- `test/features/studio/presentation/widgets/generation_pipeline_card_test.dart`

### Implementation Steps

1. Change `GenerationPipelineCard` from `StatefulWidget` to `ConsumerStatefulWidget`.
2. Change `_GenerationPipelineCardState` to `ConsumerState<GenerationPipelineCard>`.
3. Remove `title`, `genre`, `currentStep`, `statusMessage` constructor params — read from `ref.watch(generationProgressProvider)`.
4. Add `_PipelineSkeletonLoader` private widget: 4 `Container` rows with `AppColors.borderSubtle` background and `animate-pulse-slow` equivalent via `AnimationController`.
5. Add `_ErrorBanner` private widget rendered when `state.hasFailed`: error text + Retry `TextButton` calling `ref.read(generationProgressProvider.notifier).reset()`.
6. Pause `_equalizerController` when `state?.isGenerating == false`.
7. Wrap the card body in `AnimatedSwitcher(duration: const Duration(milliseconds: 300))` keyed on `state?.currentStep`.
8. The `Show lyrics` / `Hide lyrics` row: only rendered when `state?.generatedLyrics != null`.
9. Keep `onNewSong` callback as the only constructor parameter.

### Critical: Preserve Existing Behavior

- The equalizer animation logic (11 bars, sine-wave, `_equalizerController`) MUST be preserved exactly.
- All `AppColors.*` references MUST remain — no raw hex values.
- The 4-step `_buildStep` helper MUST remain structurally identical.

### Test Cases (≥ 10 tests)

```
Widget tests (all use ProviderScope with FakeGenerationSocketService override):
  ✓ renders skeleton when generationProgressProvider is null
  ✓ renders 'Result' header text
  ✓ renders track title from state.trackTitle
  ✓ renders genre badge from state.genre
  ✓ 'Generating' badge visible when state.isGenerating
  ✓ 'Ready' badge visible when state.isReady
  ✓ 'Show lyrics' toggle NOT visible when generatedLyrics is null
  ✓ 'Show lyrics' toggle IS visible when generatedLyrics is non-null
  ✓ tapping 'Show lyrics' expands lyrics container showing state.generatedLyrics text
  ✓ _ErrorBanner visible when state.hasFailed, contains errorMessage text
```

### T10.4 Gate

```pwsh
flutter test test/features/studio/presentation/widgets/generation_pipeline_card_test.dart
```

---

## T10.5 — Stem Download Orchestrator

**Files to create:**
- `lib/features/studio/domain/services/i_stem_download_service.dart`
- `lib/features/studio/data/services/stem_download_service.dart`
- `lib/features/studio/data/services/fake_stem_download_service.dart`

**Files to create (tests):**
- `test/features/studio/data/services/stem_download_service_test.dart`

### Implementation Steps

1. Create `IStemDownloadService` interface from `design.md §T10.5`.
2. Create `StemDownloadService`:
   - Use `http` package for `Client().send(Request('GET', Uri.parse(url)))`.
   - Stream response bytes into `(await getTemporaryDirectory()).path/vhunambi_downloads/<filename>`.
   - Emit `StemDownloadProgress` events (receivedBytes, totalBytes, localPath on completion).
   - On success: call `AudioSourceResolver` cache registration (if available via `ref`).
3. Create `FakeStemDownloadService`: emits 3 events (25%, 75%, 100%) within 50 ms; uses `/tmp/fake_track.mp3` as `localPath`.

### pubspec.yaml dependency check

Verify `http` and `path_provider` are already in `pubspec.yaml`. If not, add them.

### Test Cases (≥ 5 tests)

```
FakeStemDownloadService:
  ✓ downloadMaster emits exactly 3 events
  ✓ final event has isComplete == true
  ✓ final event has localPath set
  ✓ progress increases monotonically (0.25 → 0.75 → 1.0)
  ✓ cancelDownload completes without error
```

### T10.5 Gate

```pwsh
flutter test test/features/studio/data/services/stem_download_service_test.dart
```

---

## T10.6 — In-App Notification Entity

**Files to create:**
- `lib/features/notifications/domain/models/notification_entity.dart`

**Files to create (tests):**
- `test/features/notifications/domain/models/notification_entity_test.dart`

### Implementation Steps

1. Create `notification_entity.dart` with the exact class from `design.md §T10.6`.
2. Verify that `GenerationPipelineNotifier._onGenerationComplete` correctly builds and prepends a `NotificationEntity` (integration already covered in T10.3 tests).

### Test Cases (≥ 5 tests)

```
NotificationEntity:
  ✓ default isRead is false
  ✓ copyWith(isRead: true) returns new instance with isRead true
  ✓ == true for same id and isRead
  ✓ == false when isRead differs (same id)
  ✓ targetTrackId nullable: null by default, settable via copyWith
```

### T10.6 Gate

```pwsh
flutter test test/features/notifications/domain/models/notification_entity_test.dart
```

---

## Phase 10 Final Gate

Run both commands; both must pass with **zero issues / zero failures**:

```pwsh
# Full analyzer check
flutter analyze

# Full test suite — expected: ≥ 289 tests passing (254 baseline + 50 new)
flutter test
```

Expected test count breakdown:

| Task | New Tests |
|:-----|:---------:|
| T10.1 — Domain models | 16 |
| T10.2 — Socket service | 8 |
| T10.3 — Provider layer | 10 |
| T10.4 — Widget binding | 10 |
| T10.5 — Stem download | 5 |
| T10.6 — Notification entity | 5 |
| **Total new** | **54** |
| **Baseline** | **254** |
| **Phase 10 gate total** | **≥ 308** |

> A count higher than 308 is acceptable. A count lower than 308 or any failure requires investigation before the gate is declared green.

---

## Post-Phase Documentation

After both gates are green:

1. Update `docs/AGENT_HANDOFF_BIBLE.md`:
   - Set Phase 10 status to `✅ COMPLETE`
   - Record final test count
   - Note any deviations from spec

2. Create `docs/phases/phase_10_generation_pipeline_bridge/walkthrough.md` with the delivery report.

3. Update `README.md` road map table — Phase 10 row → `✅`.
