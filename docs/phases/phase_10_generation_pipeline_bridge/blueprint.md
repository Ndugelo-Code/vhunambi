# Phase 10 · Blueprint — Audio Generation Pipeline Real-Time WebSocket Bridge & Result Panel

> **Phase:** 10  
> **Codename:** `generation-pipeline-bridge`  
> **Status:** 🟡 SPECIFICATION  
> **Target App:** `apps/vhunambi_client`  
> **Flutter / Dart:** 3.x+ / 3.x+  
> **State Management:** Riverpod 2.x (`StateNotifierProvider`, `StreamProvider`)  
> **Foundation Blueprints:**  
> — `docs/foundation_blueprints/03_CREATE_STUDIO_SPEC.md` (§4 — State Machine & Payload)  
> — `docs/foundation_blueprints/07_AUDIO_TRANSPORT_AND_PIPELINE_MODALS_SPEC.md` (§3 — Result Panel, §5 — Provider Contracts)

---

## 1. Purpose & Scope

Phase 10 closes the loop between the Studio Cockpit form submission and the backend audio synthesis pipeline. After Phase 3 delivered the static Studio UI and Phase 9 wired hardware audio session management, Phase 10 adds:

1. **WebSocket Client Bridge** — persistent, auto-reconnecting connection to the Vhunambi backend synthesis gateway that emits real-time pipeline progress events.
2. **Live `GenerationPipelineCard` Integration** — the existing card widget (currently driven by static props) is re-driven by Riverpod `GenerationProgressState`, so every WebSocket event causes an immediate reactive UI update.
3. **`GenerationPipelineNotifier`** — a `StateNotifier` that owns the full generation lifecycle FSM, consumes socket events, and coordinates with `StudioFormNotifier`.
4. **Audio Stem Download Orchestrator** — `StemDownloadService` that, once the pipeline reaches `PipelineStep.ready`, downloads the MP3 master (and optional WAV stems) via HTTP with progress tracking.
5. **Notification Dispatch** — on generation completion, a `NotificationEntity` is appended to `notificationsProvider` with a tap action that routes to the finished track.

---

## 2. System Context Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                    Flutter Client (Dart/Riverpod)                │
│                                                                  │
│  StudioView                                                      │
│     │ tap "Write Lyrics / Generate"                              │
│     ▼                                                            │
│  StudioFormNotifier ─── triggerGeneration() ──────────────────┐  │
│                                                               │  │
│  GenerationPipelineNotifier ◄──────────────────────────────── ┘  │
│     │                                                            │
│     │ startSocket(generationId)                                  │
│     ▼                                                            │
│  GenerationSocketService  ◄───────── WebSocket ──────────────►  │
│     │                              wss://api.vhunambi.com        │
│     │  stream: PipelineSocketEvent                               │
│     ▼                                                            │
│  GenerationPipelineNotifier (updates state)                      │
│     │                                                            │
│     ├──► generationProgressProvider  (UI re-renders card)        │
│     ├──► notificationsProvider       (on complete)               │
│     └──► StemDownloadService         (on complete)               │
│              │ HTTP GET (download stream)                         │
│              └──► stemDownloadProvider                            │
└──────────────────────────────────────────────────────────────────┘
```

---

## 3. Feature Architecture (Clean Layers)

```
lib/features/studio/
├── domain/
│   ├── models/
│   │   ├── studio_form_state.dart           ← EXISTING (Phase 3)
│   │   └── generation_pipeline_state.dart   ← NEW T10.1
│   └── services/
│       ├── i_generation_socket_service.dart  ← NEW T10.2 (interface)
│       └── i_stem_download_service.dart      ← NEW T10.5 (interface)
├── data/
│   └── services/
│       ├── generation_socket_service.dart    ← NEW T10.2 (impl)
│       └── stem_download_service.dart        ← NEW T10.5 (impl)
└── presentation/
    ├── providers/
    │   ├── studio_form_provider.dart         ← EXISTING (Phase 3)
    │   ├── generation_pipeline_providers.dart ← NEW T10.3
    │   └── stem_download_provider.dart       ← NEW T10.5
    └── widgets/
        └── generation_pipeline_card.dart     ← MODIFIED T10.4 (live binding)

lib/features/notifications/
└── domain/
    └── models/
        └── notification_entity.dart          ← NEW T10.6
```

> **Note:** `data/` lives at:  
> `apps/vhunambi_client/lib/features/studio/data/services/`

---

## 4. WebSocket Protocol Contract

The Vhunambi synthesis gateway sends JSON frames over a persistent WebSocket connection keyed by `generationId`.

### 4.1 Connection Lifecycle

| Event            | Direction      | Description                                          |
|:-----------------|:---------------|:-----------------------------------------------------|
| `CONNECT`        | Client → Srv   | Upgrade; query param `?id=<generationId>`            |
| `PING`           | Client → Srv   | Heartbeat every 25 s                                 |
| `PONG`           | Srv → Client   | Heartbeat acknowledgement                            |
| `pipeline_event` | Srv → Client   | Progress update (primary data frame)                 |
| `DISCONNECT`     | Either         | Clean close; client schedules exponential reconnect  |
| `ERROR`          | Srv → Client   | Terminal pipeline failure frame                      |

### 4.2 `pipeline_event` Frame Schema

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

| Field              | Type            | Description                                                              |
|:-------------------|:----------------|:-------------------------------------------------------------------------|
| `type`             | `String`        | Always `"pipeline_event"`                                                |
| `generation_id`    | `String`        | Links frame to the active generation session                             |
| `step`             | `String` (enum) | `starting_up` / `writing_lyrics` / `producing_beat` / `ready` / `failed`|
| `step_index`       | `int` (1–4)     | Numeric step index for UI state machine                                  |
| `progress_percent` | `double` (0–1)  | Overall pipeline progress                                                |
| `status_message`   | `String`        | Dynamic contextual string for the Result card display                    |
| `generated_lyrics` | `String?`       | Populated when lyrics generation completes                               |
| `completed_track`  | `TrackEntity?`  | Populated when `step == "ready"`                                         |
| `error`            | `String?`       | Populated when `step == "failed"`                                        |

### 4.3 Reconnection Policy

- Max reconnect attempts: **5**
- Backoff strategy: **exponential** (1 s → 2 s → 4 s → 8 s → 16 s)
- On `maxAttempts` exhausted → notifier transitions to `PipelineStep.failed`

---

## 5. State Machine — GenerationProgressState

Full lifecycle FSM from `03_CREATE_STUDIO_SPEC.md §4`:

```
[idle]
  │ triggerGeneration()
  ▼
[generatingLyrics]      ← only when lyricsMode == aiWrite
  │ socket event: step=writing_lyrics done
  ▼
[reviewingLyrics]       ← user reviews/edits (Phase 11 UI)
  │ user confirms
  ▼
[queued]                ← payload dispatched to RunPod
  │ socket event: step=starting_up
  ▼
[processingAudio]       ← socket emits intermediate steps
  │ socket event: step=ready (completedTrack populated)
  ▼
[ready]                 ← StemDownloadService starts
  OR
[failed]                ← from any step on error / maxAttempts
```

---

## 6. Stem Download Architecture

`StemDownloadService` is invoked immediately upon `PipelineStep.ready`. It streams HTTP response bytes into a platform temp directory, emitting `StemDownloadProgress` events.

**Priority order:**
1. `completedTrack.masterMp3Url` — primary MP3 master (always)
2. `completedTrack.stemsZipUrl` — optional; only when user requests stems

**On success:** local file path passed to `AudioSourceResolver` for immediate playback; `VaultService` (Phase 8) indexes the file into the local Hive cache.

---

## 7. Headless Test Strategy

All network-dependent code is hidden behind interfaces, enabling test-safe overrides:

| Production class          | Test double                  | Injection point             |
|:--------------------------|:-----------------------------|:----------------------------|
| `GenerationSocketService` | `FakeGenerationSocketService`| `socketServiceProvider` override |
| `StemDownloadService`     | `FakeStemDownloadService`    | `stemDownloadServiceProvider` override |

`FakeGenerationSocketService` emits a deterministic `PipelineSocketEvent` sequence via `StreamController` with configurable step delays — enabling state-machine unit tests without network access.

---

## 8. Constraints & Non-Goals

| Constraint | Detail |
|:-----------|:-------|
| No raw hex colors | All colors via `AppColors.*` |
| Riverpod 2.x only | No `ChangeNotifier`, no `provider` package |
| Interface-first | Every network service has an `I`-prefix interface in `domain/services/` |
| `copyWith` immutability | All state models are `@immutable` with full `copyWith` |
| Collision-safe enums | `PipelineStep` (this phase) vs `GenerationPhase` (Phase 3) are distinct types in separate files |

**Non-Goals for Phase 10:**
- Lyrics review/edit UI (Phase 11)
- Full audio cockpit Result panel routing (separate phase)
- FCM push notification integration (backend concern)
- RunPod API authentication / token management (backend concern)
