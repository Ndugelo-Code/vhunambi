# Phase 24 · Technical Design Specification — Multi-Stem Audio Engine & Offline Frame Renderer

> **Phase:** 24 (split: **24A Audio Engine** · **24B Cloud MMO Video Export Pipeline**)  
> **Codename:** `multi-stem-and-frame-renderer`  
> **Target Apps:** `apps/vhunambi_client`, `apps/vhunambi_api`  
> **Standard:** Vhunambi Autonomous Engineering Standard ([`docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md))  
> **Revision:** 3 — Gate G1 RESOLVED: Option 1 (Server-Side Cloud Worker — The MMO Way).  
> **Date:** October 2026  

> [!NOTE]
> **GATE G1 RESOLVED (Option 1 — Server-Side Cloud Worker):**  
> To honor Vhunambi's lightweight client philosophy and support budget smartphones across Africa without app bloat, MP4 encoding is handled server-side via the RunPod GPU worker (`CloudVideoExportService` + MMO manifest). The Flutter client remains featherweight (< 80 MB) with zero C++ dependencies.

---

## 0. Reality Constraints (verified against the codebase)

| Fact | Evidence | Consequence for design |
| :--- | :--- | :--- |
| Production has **no real stems** | Webhook sets `stemsZipUrl: undefined`; worker `handler.py` v1 returns only `audio_url` | Master-only mode is the **normal** path; stems are an upgrade, not a given |
| `just_audio` has volume/speed/pitch but **no stereo pan** (verify before relying on it) | `pubspec.yaml` → `just_audio ^0.9.36` | No live per-channel pan; pan is bounce-only |
| Separate `AudioPlayer`s **cannot guarantee ≤15 ms** drift | Platform start/seek jitter | Target **≤40 ms**, measured, with resync |
| No ffmpeg / encoder / `archive` dep | `pubspec.yaml` | MP4 and zip-stem extraction are unavailable |
| `KineticPreviewCanvas` animates from a **wall-clock** `AnimationController.repeat()` | `kinetic_preview_canvas.dart` L37–54 | Needs an export mode (Track 0) before deterministic capture |
| `video_export_modal.dart` lives in **`features/social`** | `expanded_cockpit_modal.dart` import | All paths below use the real location |
| Real tokens: `AppColors.surfaceElevated`, `borderSubtle`, `accentGold`, `success`, `error`, `brandPrimary`, `surfaceCanvas` | `app_colors.dart` | No `surfaceCard`, `AppSpacing.touchTarget`, or `AppGradients.primarySunset` |

---

## 1. Domain Models & Contracts

### 1.1 `IMultiStemAudioEngine` — **implemented** (`lib/features/player/domain/services/i_multi_stem_audio_engine.dart`)

Unchanged. Additions required by the review (T1b):

```dart
/// Whether real stems are loaded. When false the engine is in master-only mode
/// and per-stem gain/mute/solo have no audible effect.
bool get hasRealStems;

/// Most recent measured inter-channel drift (null in master-only mode).
Duration? get measuredDrift;

/// Load from the MMO. Reads `mmo.stemUrls`; absent entries => master-only mode.
Future<void> loadFromManifest({
  required Map<StemType, String> stemUrls,
  required String masterUrl,
});
```

`loadStems(...)` with four loose URLs is **replaced** by `loadFromManifest` — the MMO already carries `stemUrls` ([master_media_object.dart](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/content_studio/domain/models/master_media_object.dart#L345-L346)).

### 1.2 `StemMixBounceService` — **implemented, revised** (`.../data/services/stem_mix_bounce_service.dart`)

- Pure Dart (no `dart:io`); file I/O injected as `WavFileWriter`; default `writeWavToFile` in `wav_file_writer_io.dart`.
- Returns `BounceResult { path, isSimulated, duration }`. **`isSimulated` is always `true` until real decoding exists**; UI MUST label it "Preview bounce (no real stems yet)".
- **Throws on write failure** — never returns a phantom path.
- Duration clamped to `maxDuration` (3 min) to bound memory until streaming write exists.
- Production path comes from `path_provider` (`getApplicationDocumentsDirectory()/bounces/...`); never a hardcoded absolute path. Tests use a temp dir.

### 1.3 Cloud MMO Video Export Pipeline (24B — Option 1: Server-Side Cloud Worker)

With Gate G1 resolved to **Option 1**, the client delegates heavy 1080×1920 60 FPS video encoding to the RunPod GPU cluster. The phone client stays featherweight (< 80 MB) with zero battery strain or C++ dependencies:

1. **Client Dispatch (`CloudVideoExportService`)**:
   - The client takes the local `MasterMediaObject` manifest (with 60 Hz curves, typography styling, and audio balance).
   - Dispatches a lightweight payload to `POST /v1/vision/render-video` with `mmoManifest` and export options.
2. **Backend Gateway (`apps/vhunambi_api`)**:
   - Validates the request with Zod schema and queues a RunPod video render job.
3. **GPU Worker Execution (`zr-studio-gpu/handler.py` v2)**:
   - Worker receives the MMO manifest, renders visual layers with GPU acceleration (Nvidia NVENC), muxes master audio, and uploads `vhunambi_reel_<timestamp>.mp4` to Cloudflare R2 bucket (`vhunambi-audio`).
4. **Client Progress & Download**:
   - `CloudVideoExportService` streams progress updates to `videoExportProvider` (`VideoExportState`) and provides the final Cloudflare R2 download URL.


### 1.4 Frame timing math (fixes a 60 fps off-by-one)

Never round the timestamp to integer ms before sampling the 60 Hz curve (frame 1 at 16.67 ms → 16 ms → index 0, wrong).

```dart
// Integer-exact, no float accumulation:
int curveIndex(int frame, int fps, int startOffsetFrames60) =>
    ((frame * 60) ~/ fps) + startOffsetFrames60;       // fps ∈ {30, 60}
Duration frameTime(int frame, int fps, Duration start) =>
    start + Duration(microseconds: (frame * 1000000) ~/ fps);
```

The renderer calls a **pure** `sampleFrame(mmo, mixer, curveIndex)` function — **not** `frameModulationSnapshotProvider` (an `autoDispose.family` keyed by `positionMs` would instantiate ~10,800 providers for 180 s).

---

## 2. State Management

### 2.1 One-way dependency (engine → mixer), no cycle

```dart
final multiStemAudioEngineProvider = Provider<IMultiStemAudioEngine>((ref) {
  final engine = JustAudioMultiStemEngine();           // PRODUCTION default
  ref.listen<StemMixerState>(stemMixerProvider,
      (_, next) => engine.applyMixerState(next), fireImmediately: true);
  ref.onDispose(engine.dispose);
  return engine;
});
// Tests: ProviderScope(overrides: [multiStemAudioEngineProvider.overrideWith(
//   (ref) => HeadlessMultiStemEngine())])
```

- `StemMixerNotifier` does **not** hold an engine. UI transport calls `ref.read(multiStemAudioEngineProvider)` directly. This removes the cycle and the "engine is null so play is a no-op" bug.
- The engine provider must be **read by the deck** (`ref.watch` in `StemMixerDeck`) or the listener never attaches.

### 2.2 `StemMixerNotifier.bounceMasterMix` (modify, **no `@override`**)

```dart
Future<BounceResult> bounceMasterMix() async {
  if (state.isBouncing) throw StateError('Bounce already in progress'); // M10 guard
  state = state.copyWith(isBouncing: true);
  try {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/bounces/master_mix_${DateTime.now().millisecondsSinceEpoch}.wav';
    final result = await _bounceService.bounceMixToFile(mixerState: state, targetPath: path);
    state = state.copyWith(lastBouncedAudioPath: result.path);
    return result;
  } finally {
    state = state.copyWith(isBouncing: false);
  }
}
```

The current simulated-string implementation stays until this is wired; the return type change must update `stem_mixer_provider_test.dart` and `stem_mixer_deck_test.dart`. Add a `clearBounce` flag (or sentinel) to `copyWith` so `lastBouncedAudioPath` can be cleared.

### 2.3 Transport ownership (resolves M8)

Entering the stem deck **pauses `VhunambiAudioHandler`'s master player**; leaving it restores the previous state. The OS notification mirrors exactly one source. All four stem players pause together on audio-session interruption (calls, focus loss) via `audio_session`.

---

## 3. Presentation

### 3.1 Keys

| Widget / Control | Key | Touch bounds |
| :--- | :--- | :--- |
| Stem audition Play/Pause | `const Key('stem_mixer_play_pause_btn')` | ≥ 48 × 48 dp |
| Gain slider (per stem) | `const Key('stem_gain_slider_<stem>')` | ≥ 44 dp height |
| Solo / Mute (per stem) | `const Key('stem_solo_<stem>')` / `const Key('stem_mute_<stem>')` | ≥ 44 × 44 dp |
| Bounce | `const Key('stem_mixer_bounce_btn')` | ≥ 48 dp height |
| Master-only banner | `const Key('stem_master_only_banner')` | — |
| **Export stage boundary (24B)** | **`GlobalKey`** `exportBoundaryKey` (a `ValueKey` cannot locate a `RenderRepaintBoundary`) | offscreen |

All sliders/toggles expose `Semantics` (label, value, `toggled`).

### 3.2 Master-only mode UX (honest fallback)

When `!engine.hasRealStems`: show `stem_master_only_banner` ("Real stems need the Tier 2 GPU worker"), **disable** per-stem sliders/solo/mute, keep master transport + bounce preview. Never approximate stems with EQ.

### 3.3 Export stage (24B)

- Lives in `features/social/presentation/widgets/video_export_modal.dart` (**not** `content_studio`).
- Uses a dedicated **export-mode** canvas (Track 0): no play overlay, shadow, or rounded corners; animation phase derived from position; `precacheImage` before frame 0.
- Fixed logical size (e.g. 360 × 640) inside `FittedBox`; capture with `pixelRatio = 1080 / boundary.size.width` (never `1.0`).
- Capture sequence per frame: set position → `await WidgetsBinding.instance.endOfFrame` → `boundary.toImage(pixelRatio: …)` → hand to encoder → `image.dispose()` immediately.
- Ignore the user's reduce-motion setting inside the export stage so output doesn't vary by device preference.

---

## 4. Responsive Strategy

- **Mobile (< 768 px):** vertical 4-card stack, 52 px sliders.
- **Desktop (> 1024 px):** 4-column console with vertical faders. Use `ResponsiveUtils.isDesktop(context)`.

---

## 5. Error Recovery & Offline Degradation

1. **No stems / 404:** master-only mode (§3.2). Never throw.
2. **Write failure:** bounce/export throw; the UI shows an error and offers retry. No silent success.
3. **Frame capture exception:** abort the job, release buffers, delete partial output, surface the error. (Earlier "procedural fallback frames" idea is **removed** — it would silently produce a wrong video.)
4. **Cancellation:** checked **per frame**; guarantee is "within one frame", not 100 ms.
5. **Background / interruption (24B):** `toImage` needs a live GPU surface. Export is **foreground-only** with a wake lock; on backgrounding, pause and checkpoint (frame index) for resume.
6. **Concurrency:** one bounce and one export at a time; pause live playback during export.

---

## 6. Security & Robustness

- Stem/manifest URLs: **HTTPS only**, host **allow-list** (R2), size and duration caps.
- If `stemsZipUrl` extraction is ever added (needs an `archive` dependency): guard **zip-slip** and decompression bombs.
- Sanitize any user-derived text used in file names (currently timestamp-only).
- Check free disk space before bounce/export.
