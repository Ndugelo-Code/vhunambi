# Phase 24 · Tasks & Implementation Checklist — Multi-Stem Audio Engine & Offline Frame Renderer

> **Phase:** 24 — split into **24A (Audio Engine)** and **24B (Frame Renderer)**  
> **Target Apps:** `apps/vhunambi_client`  
> **Standard:** Vhunambi Autonomous Engineering Standard ([`docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md))  
> **Revision:** 2 — incorporates the adversarial review. See [`design.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_24_multi_stem_and_frame_renderer/design.md) §0 for verified constraints.  

---

## 1. Pre-Flight Verification Checklist

- [x] `dart analyze .` → **No issues found!**
- [x] `flutter test` → **1,100 passing** at the start of Phase 24 foundations.
- [x] `pnpm test` (`apps/vhunambi_api`) → **7/7 suites passing**.

---

## 2. Decision Gates (RESOLVED)

- [x] **G1 — Encoder strategy (Option 1: Server-Side Cloud Worker — The MMO Way).**
  - Resolved: Dispatches MMO manifest to RunPod GPU worker (`handler.py` v2 / NVENC). Zero Flutter app bloat, zero device thermal strain on budget smartphones.
- [x] **G2 — Sync target.** Confirmed ≤40 ms measured audition drift with automatic resync.

---

## 3. Sequenced Implementation Tasks

### 24A — Audio Engine

#### Track A: Contracts & Bounce
- [x] **T1: `IMultiStemAudioEngine`** — `lib/features/player/domain/services/i_multi_stem_audio_engine.dart` (done).
- [x] **T1b: Extend the contract** — add `hasRealStems`, `measuredDrift`, `loadFromManifest(...)`; remove loose `loadStems(...)`; update `HeadlessMultiStemEngine` and its tests (done).
- [x] **T2: `StemMixBounceService`** — pure Dart, injected `WavFileWriter`, returns `BounceResult{isSimulated:true}`, throws on failure (done; **simulated** until real decoding exists).
- [~] **T3: Frame contracts** — `offline_video_frame_renderer.dart` exists with a parallel `VideoExportProgress`. **Rework in 24B** to the `FrameSource` design and fold progress into `VideoExportState`.

#### Track B: Engine Implementation
- [x] **T4: `HeadlessMultiStemEngine`** (done).
- [x] **T5: `JustAudioMultiStemEngine`** — `lib/features/player/data/services/just_audio_multi_stem_engine.dart` (done). Four `AudioPlayer`s, master-only fallback, drift measurement and resync when divergence > 40 ms, `audio_session` interruption handling. **No pan.**
- [x] **T6: Providers** — `multi_stem_audio_provider.dart` (done, **JustAudio default**, engine → mixer one-way) and `stem_mixer_provider.dart` (done: guarded, `path_provider`-based `bounceMasterMix` returning `BounceResult`). All tests passing.
- [x] **T6b: Transport ownership** — pause master `VhunambiAudioHandler` when the stem deck is active; restore on exit (done).

#### Track D1: UI (24A)
- [x] **T9: `StemMixerDeck`** — `lib/features/player/presentation/widgets/stem_mixer_deck.dart` (done): play/pause key, measured-drift badge, master-only banner (controls disabled), bounce labelled "Preview bounce", `Semantics` on all controls.

### 24B — Cloud MMO Video Export Pipeline (RESOLVED via Gate G1: Option 1)

#### Track Cloud: Server-Side GPU Worker Pipeline (The MMO Way)
- [x] **T7-API: Server Video Rendering Endpoint** — `apps/vhunambi_api/src/routes/vision_routes.ts` (`POST /v1/vision/render-video`) consumes 50 KB MMO manifest, produces 1080x1920 60 FPS MP4 via RunPod NVENC GPU worker. Unit tested in `test/vision.test.ts`.
- [x] **T8-Client: `CloudVideoExportService`** — `apps/vhunambi_client/lib/features/content_studio/data/services/cloud_video_export_service.dart` dispatches MMO manifest and streams progress to Cloudflare R2 video URL. Tested in `cloud_video_export_service_test.dart`.
- [x] **T10: `VideoExportModal` & `KineticPreviewCanvas`** — 60 FPS real-time interactive preview on mobile without thermal throttling or APK bloat.

### Track E: Tests & Gates
- [x] **T11: Engine unit tests** — `test/features/player/multi_stem_audio_engine_test.dart` (7/7 passing).
- [x] **T12: Bounce tests** — `test/features/player/stem_mix_bounce_test.dart` (4/4 passing; asserts file exists, simulated flag, failure propagation, duration clamp).
- [x] **T13: Cloud Export unit tests** — `test/features/content_studio/data/services/cloud_video_export_service_test.dart` (2/2 passing; MMO manifest consumption).
- [x] **T14: Deck widget tests** — `test/features/player/widgets/stem_mixer_deck_test.dart` (7/7 passing; master-only banner disables controls; play/pause; drift badge; bounce path).
- [x] **T15: Final gate** — `dart analyze .` = 0 issues across entire client; `Test-Path C:\vault` = False (zero filesystem pollution); API 7/7 suites passing.

---

## 4. Known Traps & Mitigations

| ID | Trap | Mitigation |
| :--- | :--- | :--- |
| TRAP-24-01 | `toImage` before first paint. | `await WidgetsBinding.instance.endOfFrame`; retry. **Do not use `debugNeedsPaint`** — debug-only, unsafe in release. |
| TRAP-24-02 | `ui.Image` GPU memory growth at 60 fps. | `dispose()` right after the encoder consumes the image. |
| TRAP-24-03 | Multi-player drift on long tracks. | Measure; resync slaves to master when drift > 40 ms. |
| TRAP-24-04 | Timer leaks from `just_audio` in tests. | Inject `HeadlessMultiStemEngine` via provider override. |
| TRAP-24-05 | Hardcoded `/vault/...` paths (previously **violated** by the foundation code and polluted `C:\vault`). | `path_provider`; tests use `Directory.systemTemp`. |
| TRAP-24-06 | `toImage` hangs under FakeAsync. | `tester.runAsync`. |
| TRAP-24-07 | 60 fps timestamp rounding picks the wrong curve index. | Integer frame→index math (design §1.4). |
| TRAP-24-08 | Wall-clock animations make frames non-reproducible. | Export-mode canvas (T0.1). |
| TRAP-24-09 | Cover art not loaded at capture. | `precacheImage` (T0.2). |
| TRAP-24-10 | Silent write failures masked as success. | Services throw; UI handles. |
| TRAP-24-11 | Provider cycle (engine ↔ mixer). | One-way: engine listens to mixer. |
| TRAP-24-12 | App backgrounded mid-render. | Foreground-only + wake lock + checkpoint. |
