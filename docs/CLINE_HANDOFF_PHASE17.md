# Phase 17 Master Handoff: Song Metadata DNA & Lyric Video Content Engine

> **Document Purpose:** Single authoritative handoff guide for any agent (Antigravity / Cline / Cursor) implementing Phase 17. Read this first — it captures exact requirements, architectural invariants, code designs, and the execution checklist.
>
> **Generated At:** 2026-10-10T00:58:00+02:00  
> **Lead Architect:** Antigravity (Dual-Agent Symbiosis Protocol)  
> **Repository Root:** `c:\Users\Ndugelo\VHUNAMBI\monorepo\`  
> **Client Workspace:** `apps/vhunambi_client/`  
> **Backend Workspace:** `apps/vhunambi_api/`  
> **Specification Suite:** [`docs/phases/phase_17_song_dna_content_engine/`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_17_song_dna_content_engine/)  

---

## 1. Phase 17 Objectives & Scope

Phase 17 integrates the **Song Metadata DNA** pipeline and the **Lyric Video Content Studio Dock** into the Vhunambi ecosystem, eliminating fragmented workflows and empowering creators to transform AI-generated music into social-ready video content:

1. **Song Metadata DNA Pipeline:**
   - Both simple wizard inputs and advanced options (vocal energy, gender, linguistic dialect, LoRAs) compile into an immutable canonical `SongMetadataDna` object.
   - Provides 4 tested DNA presets: *Private School Piano*, *Durban Dark Gqom*, *Venda Traditional Soul*, *Lagos Afro-Pop*.
   - Informs both RunPod audio generation and ComfyUI vision generation without manual prompt engineering.

2. **RunPod ComfyUI 9:16 Headless Visual Pipeline (`apps/vhunambi_api`):**
   - Dispatches headless generation requests to ComfyUI on RunPod with native 9:16 vertical resolution ($768 \times 1344$ or $1024 \times 1820$).
   - Automated LLM Prompt Synthesizer converts song DNA into single-paragraph diffusion prompts.
   - Re-roll capability allowing instant visual regeneration with zero changes to audio or lyrics.

3. **Content Studio Dock (Flutter Client):**
   - Responsive multiplatform dock view accessible from Studio completion, Track Details (`/track/:id`), and Library Vault.
   - 60 FPS real-time kinetic preview canvas:
     - 9:16 vertical artwork with subtle Ken Burns drift.
     - Word-level karaoke subtitle synchronization.
     - 4 typography presets: `Kinetic Bounce`, `Luminous Glow`, `Minimal Subtitle`, `Bantu Calligraphy`.
     - Duration trimming scrubber (`15s Hook`, `30s Reel`, `Full Track`).
     - Atmospheric effect toggles (35mm film grain, bass pulse, Ken Burns).

4. **Hardware-Accelerated Video Exporter:**
   - Local client-side composition into pristine $1080 \times 1920$ H.264 MP4 with zero cloud video rendering costs.
   - Direct trigger for native device sharing (TikTok, Reels, Shorts).
   - Cloud export fallback for web clients.

---

## 2. Specification Documents (Single Source of Truth)

Read and adhere to all 4 documents in `docs/phases/phase_17_song_dna_content_engine/`:
- [`blueprint.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_17_song_dna_content_engine/blueprint.md)
- [`requirements.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_17_song_dna_content_engine/requirements.md)
- [`design.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_17_song_dna_content_engine/design.md)
- [`tasks.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_17_song_dna_content_engine/tasks.md)

---

## 3. Codebase Invariants (NEVER BREAK THESE)

1. **Zero Raw Hex Values:** Always use `AppColors.*`, `AppGradients.*`, `AppTypography.*`, `AppRadius.*`, `AppSpacing.*`.
2. **Animation & Hydration Safety:** Use `lib/motion-config.ts` variants when targeting web SSR; use Flutter `CustomPainter` with `TickerProviderStateMixin` or `AnimationController` for 60fps kinetic canvas.
3. **Headless Test Safety:** Native platform channels or FFmpeg binaries must be mocked or injected via interfaces (`IVideoExportService`) so `flutter test` executes headless without platform exceptions.
4. **Commercial License Guardrails:** FLUX.1 [schnell] (Apache 2.0) and SDXL 1.0 (Permissive Open-Weights) only. Never load FLUX.1 [dev].
5. **Zero Regressions:** Existing test suites in `apps/vhunambi_client` and `apps/vhunambi_api` must continue to pass cleanly.

---

## 4. Execution Roadmap by Task

* **Part A (Foundation & Domain):** ✅ **COMPLETE (T1 – T3)** — Dart domain models (`SongMetadataDna`, `LyricWordTimestamp`, `ContentStudioPreset`), Studio Form State compilation & 4 DNA presets, API Gateway DNA compiler.
* **Part B (Vision Engine):** ✅ **COMPLETE (T4 – T5)** — RunPod ComfyUI 9:16 state machine graph (`comfyui_adapter.ts`), LLM Vision Prompt Synthesizer (`prompt_synthesizer.ts`), and 5 passing API test suites.
* **Part C (Flutter Content Studio Presentation):** ✅ **COMPLETE (T6 – T9)**
  - **T6**: Riverpod Content Studio State & Notifier (`content_studio_provider.dart`) with Genre-Aware Smart Defaults.
  - **T7**: 60 FPS Kinetic Preview Canvas (`kinetic_preview_canvas.dart`) with 4 kinetic typography styles, frequency waveforms, and Ken Burns drift.
  - **T8**: Preset Pickers & Scrubber Panels (`typography_preset_picker.dart`, `duration_trim_scrubber.dart`, `atmospheric_effects_deck.dart`).
  - **T9**: Content Studio Dock Responsive View (`content_studio_dock_view.dart`) with mobile and desktop layouts.
* **Part D (Export & Verification):** ✅ **COMPLETE (T10 – T11)**
  - **T10**: Video Export Bridges (`LocalVideoExportService`, `CloudVideoExportService`) and modal action sheet (`export_action_sheet.dart`).
  - **T11**: End-to-end verification — 19/19 Content Studio tests pass, 0 analyzer issues, full monorepo green.
  - **Bonus Integration**: One-click entrypoint wiring from `GenerationPipelineCard` (`_ReadyTrackCard`), `TrackActionsSheet`, and `ExpandedCockpitModal`.
* **Walkthrough Report:** [`docs/phases/phase_17_song_dna_content_engine/walkthrough.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_17_song_dna_content_engine/walkthrough.md)
