# Phase 24 · Requirements Specification — Multi-Stem Audio Engine & Offline Frame Renderer

> **Phase:** 24  
> **Codename:** `multi-stem-and-frame-renderer`  
> **Target Apps:** `apps/vhunambi_client`  
> **Standard:** Vhunambi Autonomous Engineering Standard ([`docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md))  
> **Conventions:** RFC 2119 & EARS (Easy Approach to Requirements Syntax)  
> **Date:** October 2026  

---

## 1. Multi-Stem Audio Engine Requirements (`REQ-STEM-AUDIO`)

### `REQ-STEM-AUDIO-01` (Ubiquitous — 4-Channel Sync)
WHEN real stems are loaded, the system **SHALL** maintain four stem playback channels (`StemType.vocals`, `drums`, `bass`, `melody`), **measure** inter-channel drift continuously, and **resynchronize** any channel whose drift exceeds $40\text{ ms}$. The measured value SHALL be exposed via `measuredDrift`; the UI SHALL display the measured value, never a constant. *(Supersedes the earlier 15 / 25 / 5 ms figures, which separate `AudioPlayer` instances cannot guarantee. See Gate G2.)*

### `REQ-STEM-AUDIO-02` (Event-Driven — Dynamic Volume & Mute Matrix)
WHEN a channel's gain, mute, or solo state is altered in `StemMixerNotifier`, the audio engine **SHALL** immediately update that channel's output volume using:
$$V_{\text{audible}} = \text{effectiveVolume}(\text{anySoloActive})$$
WHERE `effectiveVolume` computes $0.0$ if muted (or if another channel is soloed and this channel is not soloed), and `gain.clamp(0.0, 1.5)` otherwise. Per-channel **pan is NOT applied during live audition** (`just_audio` provides no stereo pan); it is honoured only by the offline bounce.

### `REQ-STEM-AUDIO-03` (Event-Driven — Coordinated Transport Scrubbing)
WHEN `seek(Duration position)` is dispatched from the transport bar or scrubber, the audio engine **SHALL** command all four active stem channels to seek to the specified position simultaneously and buffer before resuming playback.

### `REQ-STEM-AUDIO-04` (Unwanted / Error — Master-Only Mode)
IF stem audio is unavailable (the **normal production case** until the Tier 2 GPU worker returns stems), THEN the audio engine **SHALL** enter master-only mode without throwing: `hasRealStems == false`, master transport remains functional, per-stem gain/mute/solo controls are **disabled**, and the UI SHALL show "Real stems need the Tier 2 GPU worker". The engine **SHALL NOT** approximate stems via EQ or any other synthetic filtering (dual-provenance honesty).

### `REQ-STEM-AUDIO-05` (State-Driven — Bounce)
WHILE in the bouncing state (`isBouncing == true`), the system **SHALL** write a valid 16-bit 44.1 kHz stereo WAV file under the `path_provider` application documents directory (`bounces/master_mix_<timestamp>.wav`) and return a `BounceResult`. Until real stem decoding exists the result **SHALL** carry `isSimulated == true` and the UI SHALL label it "Preview bounce". The system **SHALL** reject a second concurrent bounce, **SHALL** throw (not return a path) on any write failure, and **SHALL NOT** use hardcoded absolute paths.

### `REQ-STEM-AUDIO-06` (Ubiquitous — Headless CI/CD Test Safety)
The system **SHALL** provide an abstract `IMultiStemAudioEngine` interface with both a production implementation (`JustAudioMultiStemEngine`) and a headless test implementation (`HeadlessMultiStemEngine`), ensuring unit and widget tests run deterministically with zero unmanaged asynchronous timers or native hardware dependencies.

---

## 2. Deterministic Offline Video Frame Renderer Requirements (`REQ-VIDEO-RENDER`) — **24B, BLOCKED on Gate G1 (encoder strategy)**

### `REQ-VIDEO-RENDER-01` (Ubiquitous — Deterministic Time Stepping)
The offline video export pipeline **SHALL** compute frame *i* using **integer arithmetic** (`frameTime = start + (i·10^6 ÷ FPS) µs`; `curveIndex = (i·60 ÷ FPS) + startOffset`), WHERE $\text{FPS} \in \{30, 60\}$, with no wall-clock timers, no cumulative float addition, and no rounding of the timestamp to whole milliseconds before sampling the 60 Hz curve. The exported canvas SHALL derive **all** animation phase from the supplied position (no free-running `AnimationController`).

### `REQ-VIDEO-RENDER-02` (State-Driven — MMO Modulation Telemetry Coupling)
WHILE stepping each frame at timestamp $t_i = \text{startSec} + (i \cdot \Delta t)$, the renderer **SHALL** inject the exact telemetry state from `masterMediaObjectProvider` into `KineticPreviewCanvas`, ensuring particle emissions, camera snap-zooms, and typography bloom radii match the playback experience identically.

### `REQ-VIDEO-RENDER-03` (Event-Driven — RepaintBoundary Frame Capture)
WHEN a frame is painted at timestamp $t_i$, the renderer **SHALL** await `WidgetsBinding.instance.endOfFrame` and capture via `RenderRepaintBoundary.toImage(pixelRatio: 1080 / boundary.size.width)` so output is exactly the target resolution (e.g. 1080×1920). Cover art SHALL be pre-cached before frame 0 and the export stage SHALL exclude the play overlay, shadow and rounded corners.

### `REQ-VIDEO-RENDER-04` (Ubiquitous — Memory-Bounded Garbage Collection)
The frame capture loop **SHALL** explicitly call `.dispose()` on each captured `ui.Image` instance immediately after encoding to prevent GPU/RAM memory exhaustion during 60 FPS renders.

### `REQ-VIDEO-RENDER-05` (Event-Driven — Progress & Telemetry Emission)
WHEN each frame $i$ of $N$ is captured, the renderer **SHALL** report progress through the existing `onProgress(double)` / `VideoExportState` (extended with the fields below; no parallel progress type):
- `progress`: $i / N$ ($0.0 \dots 1.0$)
- `currentFrame`: $i$
- `totalFrames`: $N$
- `estimatedSecondsRemaining`: calculated via rolling average frame render time.

### `REQ-VIDEO-RENDER-06` (Event-Driven — User Cancellation)
WHEN the user taps "Cancel Render", the renderer **SHALL** abort at the next frame boundary (cancellation is polled per frame), release all offscreen frame buffers, delete any temporary partial artifacts, and reset `VideoExportState` to idle.

### `REQ-VIDEO-RENDER-07` (State-Driven — Audio Muxing & Vault Persistence)
WHILE finalizing the export job, the renderer **SHALL** stream captured frames (never buffering the full sequence) into the encoder selected at Gate G1, mux the corresponding audio segment, and persist a valid video file under the `path_provider` documents directory (`reels/vhunambi_reel_<preset>_<timestamp>.mp4`). Export SHALL run foreground-only with a wake lock and SHALL checkpoint the frame index so an interrupted job can resume. The system SHALL NOT synthesize substitute frames on capture failure; it SHALL abort and report the error.

### `REQ-VIDEO-RENDER-08` (Touch & Ergonomics — 44x44px Minimum Hit Area)
Every interactive button, slider thumb, and toggle switch within `StemMixerDeck` and `VideoExportModal` **MUST** adhere to a minimum interactive bounding box of $44 \times 44\text{ dp}$ in compliance with Apple HIG and WCAG 2.1 AA.

---

## 3. Requirements Traceability Matrix

| Requirement ID | Target Components | Test Type | Verification Gate |
| :--- | :--- | :--- | :--- |
| `REQ-STEM-AUDIO-01` | `IMultiStemAudioEngine`, `MultiStemAudioPlayer` | Unit / Mock | `flutter test test/features/player/multi_stem_audio_engine_test.dart` |
| `REQ-STEM-AUDIO-02` | `StemMixerNotifier`, `StemChannel` | Unit / Widget | `flutter test test/features/player/stem_mixer_provider_test.dart` |
| `REQ-STEM-AUDIO-03` | `StemMixerDeck`, `IVhunambiAudioHandler` | Widget | `flutter test test/features/player/widgets/stem_mixer_deck_test.dart` |
| `REQ-STEM-AUDIO-04` | `SyntheticStemSource`, `MultiStemAudioEngine` | Unit | `flutter test test/features/player/multi_stem_fallback_test.dart` |
| `REQ-STEM-AUDIO-05` | `StemMixBounceService` | Unit | `flutter test test/features/player/stem_mix_bounce_test.dart` |
| `REQ-STEM-AUDIO-06` | `HeadlessMultiStemEngine` | Unit | `dart analyze .` & `flutter test` (0 timer leaks) |
| `REQ-VIDEO-RENDER-01` | `OfflineVideoFrameRenderer` | Unit | `flutter test test/features/content_studio/offline_frame_renderer_test.dart` |
| `REQ-VIDEO-RENDER-02` | `KineticPreviewCanvas`, `MasterMediaObject` | Widget | `flutter test test/features/content_studio/presentation/widgets/kinetic_preview_canvas_mmo_test.dart` |
| `REQ-VIDEO-RENDER-03` | `LocalVideoExportService` | Unit | `flutter test test/features/content_studio/local_video_export_service_test.dart` |
| `REQ-VIDEO-RENDER-04` | `RepaintBoundaryFrameCapture` | Unit | Memory leak test (0 leaked `ui.Image` handles) |
| `REQ-VIDEO-RENDER-05` | `VideoExportNotifier`, `VideoExportModal` | Widget | `flutter test test/features/content_studio/video_export_modal_test.dart` |
| `REQ-VIDEO-RENDER-06` | `VideoExportState`, `CancellationToken` | Unit / Widget | Cancellation test assertions |
| `REQ-VIDEO-RENDER-07` | `LocalVideoExportService` | Integration / Mock | Valid file existence in `/vault/reels/` |
| `REQ-VIDEO-RENDER-08` | `StemMixerDeck`, `VideoExportModal` | Widget | Bounding box $\ge 44 \times 44\text{ dp}$ audit |
