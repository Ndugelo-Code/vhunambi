# Phase 10 Master Handoff: Audio Generation Pipeline Real-Time WebSocket Bridge & Result Panel

> **Document Purpose:** Single authoritative handoff guide for any agent (Antigravity / Cline / Cursor) implementing Phase 10. Read this first — it captures exact requirements, architectural invariants, full class designs, and the execution checklist.
>
> **Generated At:** 2026-09-26T14:28:00+02:00  
> **Lead Architect:** Antigravity (Dual-Agent Symbiosis Protocol)  
> **Repository Root:** `c:\Users\Ndugelo\VHUNAMBI\monorepo\`  
> **Client Workspace:** `apps/vhunambi_client/`  
> **Current Health:** `flutter analyze` = **0 issues** | `flutter test` = **254/254 passing (100%)**  
> **Target Test Count:** **≥ 308 tests (54 new tests)**

---

## 1. Phase 10 Objectives & Scope

Wire the Studio Cockpit's static generation UI to a live backend audio synthesis pipeline:

1. **WebSocket Client Bridge** — Persistent, auto-reconnecting `GenerationSocketService` targeting `wss://api.vhunambi.com/ws/generation`, with exponential-backoff reconnection (max 5 attempts) and 25-second heartbeat pings.
2. **Live `GenerationPipelineCard`** — Refactor the existing `StatefulWidget` (Phase 3) to `ConsumerStatefulWidget`, driven by `generationProgressProvider` instead of static constructor props.
3. **`GenerationPipelineNotifier`** — `StateNotifier` that owns the 5-step pipeline FSM, consumes `PipelineSocketEvent` stream, coordinates stem download and notification dispatch on completion.
4. **Stem Download Orchestrator** — `StemDownloadService` that streams the MP3 master via HTTP into the device temp directory, emitting `StemDownloadProgress` events; registers file with `AudioSourceResolver` for offline playback (Phase 8 integration).
5. **In-App Notification Entity** — `NotificationEntity` model + `notificationsProvider`; on generation completion, a new notification is prepended to the list.

---

## 2. Specification Documents (Single Source of Truth)

Read and adhere to all 4 documents in `docs/phases/phase_10_generation_pipeline_bridge/`:

- [`blueprint.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_10_generation_pipeline_bridge/blueprint.md)
- [`requirements.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_10_generation_pipeline_bridge/requirements.md)
- [`design.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_10_generation_pipeline_bridge/design.md)
- [`tasks.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_10_generation_pipeline_bridge/tasks.md)

---

## 3. Codebase Invariants (NEVER BREAK THESE)

1. **Zero Raw Hex Values:** Always use `AppColors.*`, `AppTypography.*`, `AppRadius.*`, `AppSpacing.*`. No `Color(0xFF...)` literals.
2. **Riverpod 2.x only:** `StateNotifierProvider`, `StateProvider`, `Provider`. No `ChangeNotifier`, no `provider` package.
3. **Interface-First:** Every network/IO service MUST have an abstract `I`-prefix interface in `domain/services/`. Fake implementations live in `data/services/` (not under `test/`) so they compile in production builds.
4. **Headless Test Safety (CRITICAL):** No test may make a real WebSocket or HTTP connection. All socket and download interactions are simulated via `FakeGenerationSocketService` and `FakeStemDownloadService` using `ProviderScope` overrides.
5. **`PipelineStep` ≠ `GenerationPhase`:** These are deliberately separate enums. `PipelineStep` lives in `generation_pipeline_state.dart` and drives the 4-step card. `GenerationPhase` lives in `studio_form_state.dart` and drives the form FSM. Do NOT merge or rename either.
6. **`@immutable` + `copyWith`:** All domain models must be `@immutable` with a complete `copyWith` covering every field.
7. **Zero Regressions:** All 254 baseline tests must continue to pass cleanly.

---

## 4. File Map — Everything to Create/Modify

### New files to CREATE

```
lib/features/studio/domain/models/generation_pipeline_state.dart   ← T10.1
lib/features/studio/domain/models/stem_download_progress.dart       ← T10.1 / T10.5
lib/features/studio/domain/services/i_generation_socket_service.dart ← T10.2
lib/features/studio/domain/services/i_stem_download_service.dart     ← T10.5
lib/features/studio/data/services/generation_socket_service.dart     ← T10.2
lib/features/studio/data/services/fake_generation_socket_service.dart ← T10.2 (test double)
lib/features/studio/data/services/stem_download_service.dart         ← T10.5
lib/features/studio/data/services/fake_stem_download_service.dart    ← T10.5 (test double)
lib/features/studio/presentation/providers/generation_pipeline_providers.dart ← T10.3
lib/features/studio/presentation/providers/stem_download_provider.dart ← T10.5
lib/features/notifications/domain/models/notification_entity.dart    ← T10.6

test/features/studio/domain/models/generation_pipeline_state_test.dart ← T10.1
test/features/studio/data/services/generation_socket_service_test.dart ← T10.2
test/features/studio/presentation/providers/generation_pipeline_providers_test.dart ← T10.3
test/features/studio/presentation/widgets/generation_pipeline_card_test.dart ← T10.4
test/features/studio/data/services/stem_download_service_test.dart   ← T10.5
test/features/notifications/domain/models/notification_entity_test.dart ← T10.6
```

### Existing files to MODIFY

```
lib/features/studio/presentation/widgets/generation_pipeline_card.dart  ← T10.4
  StatefulWidget → ConsumerStatefulWidget
  Static props removed; replaced by ref.watch(generationProgressProvider)
```

### Existing files — DO NOT TOUCH

```
lib/features/studio/domain/models/studio_form_state.dart      ← Phase 3, untouched
lib/features/studio/presentation/providers/studio_form_provider.dart ← Phase 3, untouched
lib/features/player/*                                          ← Phase 9, untouched
```

---

## 5. Key Class Signatures (Quick Reference)

### `PipelineStep` enum
```dart
enum PipelineStep { startingUp, writingLyrics, producingBeat, ready, failed }
```

### `PipelineSocketEvent` (domain model — T10.1)
```dart
@immutable class PipelineSocketEvent {
  final String generationId;
  final PipelineStep step;
  final int stepIndex;         // 1–4
  final double progressPercent; // 0.0–1.0
  final String statusMessage;
  final String? generatedLyrics;
  final TrackEntity? completedTrack;
  final String? error;
  factory PipelineSocketEvent.fromJson(Map<String, dynamic> json) { ... }
  PipelineSocketEvent copyWith({ ... });
}
```

### `GenerationProgressState` (domain model — T10.1)
```dart
@immutable class GenerationProgressState {
  final String generationId;
  final String trackTitle;
  final String genre;
  final PipelineStep currentStep;
  final String statusMessage;
  final double progressPercent;
  final String? generatedLyrics;
  final TrackEntity? completedTrack;
  final String? errorMessage;

  bool get isGenerating => currentStep != PipelineStep.ready && currentStep != PipelineStep.failed;
  bool get isReady      => currentStep == PipelineStep.ready;
  bool get hasFailed    => currentStep == PipelineStep.failed;
}
```

### `IGenerationSocketService` (interface — T10.2)
```dart
abstract class IGenerationSocketService {
  Stream<PipelineSocketEvent> connect(String generationId);
  Future<void> disconnect();
  bool get isConnected;
}
```

### `FakeGenerationSocketService` (test double — T10.2)
Emits 4 events in order: `startingUp (0.15)` → `writingLyrics (0.40)` → `producingBeat (0.72)` → `ready (1.00)`.  
Default step delay: 200 ms. No imports from `flutter_test` — compilable in prod.

### `generationProgressProvider`
```dart
StateNotifierProvider<GenerationPipelineNotifier, GenerationProgressState?>
```
Initial state: `null`. Non-null = active or completed pipeline session.

### `GenerationPipelineNotifier` (T10.3)
```dart
Future<void> startGeneration({required String generationId, required String trackTitle, required String genre});
void reset(); // → state = null
@override void dispose(); // → socketService.disconnect()
```

### `notificationsProvider`
```dart
StateProvider<List<NotificationEntity>>  // initialized to []
```
On completion: **prepend** (not append) new `NotificationEntity`.

### `NotificationEntity` (T10.6)
```dart
@immutable class NotificationEntity {
  final String id;
  final String title;           // pattern: 'Your song "<title>" is ready!'
  final String message;
  final String? targetTrackId;
  final DateTime createdAt;
  final bool isRead;            // default: false
}
```

### `StemDownloadProgress` (T10.5)
```dart
@immutable class StemDownloadProgress {
  final String url;
  final int receivedBytes;
  final int totalBytes;
  final String? localPath;
  final String? error;
  double get progress;    // receivedBytes / totalBytes (0.0 when totalBytes==0)
  bool get isComplete;    // localPath != null
  bool get hasError;      // error != null
}
```

---

## 6. WebSocket Protocol (Summary)

| Frame | Direction | Details |
|:------|:----------|:--------|
| Connect | Client→Srv | `wss://api.vhunambi.com/ws/generation?id=<generationId>` |
| PING | Client→Srv | Every 25 s |
| PONG | Srv→Client | Within 10 s of PING, else reconnect |
| `pipeline_event` | Srv→Client | JSON frame — primary data |
| ERROR | Srv→Client | Emits `PipelineStep.failed` event |
| DISCONNECT | Either | Triggers exponential-backoff reconnect (1/2/4/8/16 s, max 5) |

`pipeline_event` JSON:
```json
{
  "type": "pipeline_event",
  "generation_id": "gen_abc123",
  "step": "producing_beat",
  "step_index": 3,
  "progress_percent": 0.72,
  "status_message": "Laying down the drums... feel it building 🥁",
  "generated_lyrics": null,
  "completed_track": null,
  "error": null
}
```

`_stepFromString` mapping:
- `"starting_up"` → `PipelineStep.startingUp`
- `"writing_lyrics"` → `PipelineStep.writingLyrics`
- `"producing_beat"` → `PipelineStep.producingBeat`
- `"ready"` → `PipelineStep.ready`
- any other → `PipelineStep.failed`

---

## 7. `GenerationPipelineCard` Widget Changes (T10.4)

```dart
// BEFORE (Phase 3):
class GenerationPipelineCard extends StatefulWidget {
  final String title;
  final String genre;
  final int currentStep;
  final String statusMessage;
  final VoidCallback? onNewSong;
}

// AFTER (Phase 10):
class GenerationPipelineCard extends ConsumerStatefulWidget {
  final VoidCallback? onNewSong;
  const GenerationPipelineCard({super.key, this.onNewSong});
}
```

**Behavioral changes:**
- `ref.watch(generationProgressProvider)` replaces all props.
- Null state → `_PipelineSkeletonLoader` (4 pulsing placeholder rows).
- `state.hasFailed` → inline `_ErrorBanner` with `errorMessage` + Retry button.
- Equalizer `_equalizerController` pauses when `state?.isGenerating == false`.
- `Show lyrics` toggle only visible when `state?.generatedLyrics != null`.
- `AnimatedSwitcher(duration: 300ms)` wraps body, keyed on `state?.currentStep`.

**Preserve unchanged:**
- 11-bar equalizer animation math (sine-wave, `_equalizerController`).
- `_buildStep()` helper signature and visual logic.
- All `AppColors.*` references.

---

## 8. Verification Gates

### Per-task gates (run after each task)
```pwsh
# T10.1
flutter test test/features/studio/domain/models/generation_pipeline_state_test.dart

# T10.2
flutter test test/features/studio/data/services/generation_socket_service_test.dart

# T10.3
flutter test test/features/studio/presentation/providers/generation_pipeline_providers_test.dart

# T10.4
flutter test test/features/studio/presentation/widgets/generation_pipeline_card_test.dart

# T10.5
flutter test test/features/studio/data/services/stem_download_service_test.dart

# T10.6
flutter test test/features/notifications/domain/models/notification_entity_test.dart
```

### Phase 10 final gate
```pwsh
flutter analyze          # must output: No issues found!
flutter test             # must output: ≥ 308 tests passed, 0 failures
flutter test test/features/studio
flutter test test/features/notifications
```

### Test count target

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
| **Phase gate total** | **≥ 308** |

---

## 9. Cline Prompt for Execution

```
You are executing Phase 10 of the Vhunambi Flutter client (apps/vhunambi_client):
Audio Generation Pipeline Real-Time WebSocket Bridge & Result Panel.

PRE-FLIGHT STATUS:
- Working directory: apps/vhunambi_client
- flutter analyze → 0 issues found
- flutter test → 254 of 254 tests passed (100%)

SPECIFICATIONS:
Read all 4 documents in docs/phases/phase_10_generation_pipeline_bridge/:
  blueprint.md, requirements.md, design.md, tasks.md

Use docs/CLINE_HANDOFF_PHASE10.md as your master execution reference.

TASKS TO EXECUTE (in order — run per-task gate before proceeding):

T10.1 — Create domain models:
  lib/features/studio/domain/models/generation_pipeline_state.dart
  lib/features/studio/domain/models/stem_download_progress.dart
  test/features/studio/domain/models/generation_pipeline_state_test.dart

T10.2 — Create WebSocket service layer:
  lib/features/studio/domain/services/i_generation_socket_service.dart
  lib/features/studio/data/services/generation_socket_service.dart
  lib/features/studio/data/services/fake_generation_socket_service.dart
  test/features/studio/data/services/generation_socket_service_test.dart

T10.3 — Create Riverpod provider layer:
  lib/features/studio/presentation/providers/generation_pipeline_providers.dart
  lib/features/studio/presentation/providers/stem_download_provider.dart
  lib/features/notifications/domain/models/notification_entity.dart (placeholder — full model in T10.6)
  test/features/studio/presentation/providers/generation_pipeline_providers_test.dart

T10.4 — Refactor GenerationPipelineCard to live ConsumerStatefulWidget:
  MODIFY lib/features/studio/presentation/widgets/generation_pipeline_card.dart
  test/features/studio/presentation/widgets/generation_pipeline_card_test.dart

T10.5 — Create stem download orchestrator:
  lib/features/studio/domain/services/i_stem_download_service.dart
  lib/features/studio/data/services/stem_download_service.dart
  lib/features/studio/data/services/fake_stem_download_service.dart
  test/features/studio/data/services/stem_download_service_test.dart

T10.6 — Finalize notification entity:
  lib/features/notifications/domain/models/notification_entity.dart
  test/features/notifications/domain/models/notification_entity_test.dart

CRITICAL INVARIANTS:
- Zero raw hex values (use AppColors.*)
- Riverpod 2.x only (StateNotifierProvider, StateProvider, Provider)
- Every network service has an I-prefix interface in domain/services/
- Fake doubles live in data/services/ (NOT under test/) — no flutter_test imports
- PipelineStep != GenerationPhase — these are distinct enums, never merge them
- All models @immutable with copyWith covering every field
- All 254 baseline tests must keep passing (zero regressions)
- FakeGenerationSocketService and FakeStemDownloadService used for ALL socket/HTTP tests

VERIFICATION GATES:
- flutter analyze (0 issues)
- flutter test (≥ 308 passing tests, 0 failures)
```
