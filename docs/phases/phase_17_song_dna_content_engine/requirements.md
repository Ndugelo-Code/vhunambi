# Phase 17 · Requirements — Song Metadata DNA & Lyric Video Content Engine

> **Phase:** 17  
> **Codename:** `song-dna-content-dock`  
> **Status:** 🟡 SPECIFICATION  
> **Standard:** EARS (Easy Approach to Requirements Syntax) + RFC 2119 modal verbs  

---

## 1. Song Metadata DNA Requirements

### REQ-DNA-01: Canonical DNA Compilation
**[SHALL]** When a user triggers generation from the Studio Creation Wizard (`/create`), the system SHALL compile both basic form inputs (genre, mood, tempo bracket) and advanced options (vocal energy, gender, linguistic dialect, duration, LoRAs) into a single canonical `SongMetadataDna` object.

### REQ-DNA-02: Lossless Persistence & Traceability
**[SHALL]** The `SongMetadataDna` record SHALL be persisted alongside the generated track entity in local cache (Hive) and backend storage.
**[SHALL NOT]** Any generation stage SHALL NOT discard or strip advanced parameters during synthesis handoffs.

### REQ-DNA-03: Preset Testing Profiles
**[SHALL]** The system SHALL provide at least 4 pre-configured, tested DNA sample presets in the Studio Wizard:
1. **Private School Piano** (Amapiano, 112 BPM, Soulful, Melodic vocals, Tshivenḓa/Zulu).
2. **Durban Dark Gqom** (Gqom, 126 BPM, Intense, Spoken word/chant, Zulu).
3. **Venda Traditional Soul** (Indigenous/Afro-Soul, 98 BPM, Peaceful, Choir, Tshivenḓa).
4. **Lagos Afro-Pop** (Afrobeats, 106 BPM, Uplifting, Duet, English/Pidgin).

### REQ-DNA-04: Ground-Truth Conditioning
**[SHALL]** When the Vision Engine or Content Engine is activated for a track, it SHALL read directly from the song's `SongMetadataDna` as the single source of truth for prompts, colors, tempo sync, and lyric alignment.

---

## 2. Vision Engine & ComfyUI 9:16 Artwork Requirements

### REQ-VISION-01: Headless ComfyUI 9:16 Payload Dispatch
**[SHALL]** `apps/vhunambi_api` SHALL support dispatching headless generation requests to a RunPod ComfyUI endpoint adhering to the state machine defined in [`docs/comfyui-sdxl-blueprint-1.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/comfyui-sdxl-blueprint-1.md).
**[SHALL]** Node `5` (`EmptyLatentImage`) SHALL be parameterized to native vertical 9:16 aspect ratio:
- Width: `768`, Height: `1344` (for FLUX.1 [schnell]) OR
- Width: `1024`, Height: `1820` (for SDXL 1.0 base).

### REQ-VISION-02: Automated LLM Visual Prompt Translation
**[SHALL]** Before dispatching to ComfyUI, `apps/vhunambi_api` SHALL pass the `SongMetadataDna` through an LLM prompt synthesizer that outputs an optimized, single-paragraph image prompt into Node `6` (`inputs.text`).
**[SHALL NOT]** The system SHALL NOT require the end-user to manually write SDXL/FLUX diffusion prompt strings.

### REQ-VISION-03: Commercial License Guardrails
**[SHALL]** The vision pipeline SHALL exclusively load open-weight checkpoints licensed for unrestricted commercial monetization (Apache 2.0 or Permissive Open-Weights):
- **FLUX.1 [schnell]** (Apache 2.0)
- **Stable Diffusion XL 1.0 Base** (Permissive Commercial Open-Weights)
**[SHALL NOT]** The production container SHALL NOT load non-commercial models (`FLUX.1 [dev]` or restricted tiers).

### REQ-VISION-04: Instant Visual Re-roll
**[WHEN]** A user clicks "Re-roll 9:16 Artwork" in the Content Studio Dock,
**[SHALL]** The system SHALL generate a new pseudorandom seed (Node `10`) and dispatch a background ComfyUI call, updating the visual layer without modifying the existing audio or lyric files.

---

## 3. Lyric Synchronization & Alignment Requirements

### REQ-ALIGN-01: Word-Level Timestamp Schema
**[SHALL]** The alignment service SHALL produce or consume a lightweight word-level timestamp contract:
```json
{
  "trackId": "string",
  "words": [
    { "word": "Ndi", "start": 1.25, "end": 1.55, "stanzaIndex": 0 },
    { "word": "mufunwa", "start": 1.58, "end": 2.10, "stanzaIndex": 0 }
  ]
}
```

### REQ-ALIGN-02: Zero-Video Legacy Abandonment
**[SHALL NOT]** The alignment and rendering pipeline SHALL NOT require video inputs, 10-second boomerang looping, or external video stitching.

---

## 4. Flutter Content Studio Dock Requirements

### REQ-DOCK-01: Universal Multiplatform Dock Entry
**[SHALL]** A user SHALL be able to launch the Content Studio Dock from:
1. The `GenerationPipelineCard` upon successful track synthesis.
2. The `TrackDetailCockpitView` (`/track/:id`) action bar.
3. The `LibraryVaultView` contextual track action sheet.

### REQ-DOCK-02: 60 FPS Real-Time Kinetic Preview
**[SHALL]** The Content Studio Dock SHALL render the composite preview (9:16 image + synchronized karaoke subtitles + audio-reactive waveform) at 60 FPS purely within the client widget tree using `CustomPainter` and hardware-accelerated canvas animations.
**[SHALL NOT]** The preview SHALL NOT stream or transcode pre-rendered MP4 video files over the network.

### REQ-DOCK-03: Responsive Layout Adaptability
**[SHALL]** On desktop screens ($> 1024\text{px}$), the Dock SHALL render a split-screen cockpit (left: 9:16 vertical preview, right: control panel).
**[SHALL]** On mobile screens ($< 768\text{px}$), the Dock SHALL render a single-column layout with a pinned preview and segmented control panels (`Duration`, `Typography`, `Effects`).

### REQ-DOCK-04: Lyric Typography Presets
**[SHALL]** The Dock SHALL provide at least 4 selectable visual typography presets:
1. `Kinetic Bounce`: 1.15x scale pop on active word with Brand Amber accent (`AppColors.brandPrimary`).
2. `Luminous Glow`: Ambient radial blur glow with title case lettering.
3. `Minimal Subtitle`: Bottom-aligned glass container with crisp yellow highlight sweep.
4. `Bantu Calligraphy`: Stylized editorial serif with fluid underline progress.

### REQ-DOCK-05: Clip Trimming & Scrubber Controls
**[SHALL]** The user SHALL be able to select pre-set duration brackets (`15s Hook`, `30s Reel`, `Full Track`) or drag range sliders to set custom `startSec` and `endSec` clip bounds.

### REQ-DOCK-06: Atmospheric Effects Layer
**[SHALL]** The user MAY toggle additional decorative overlay shaders:
- 35mm subtle film grain overlay.
- Audio-reactive bass pulse (subtle image scale bounce matched to low frequencies).
- Subtle Ken Burns drift (1.05x zoom in / pan over clip duration).

---

## 5. Export & Sharing Requirements

### REQ-EXPORT-01: Local Hardware-Accelerated MP4 Export
**[SHALL]** On desktop (Windows/macOS) and mobile (Android/iOS), clicking "Export MP4" SHALL invoke local hardware-accelerated video composition (`ffmpeg_kit_flutter` or platform video muxer), generating a pristine H.264 $1080 \times 1920$ MP4 file.

### REQ-EXPORT-02: Native Share & Download Bridge
**[SHALL]** Once exported, the user SHALL be presented with options to:
1. Save the MP4 to their device's local photo library / downloads folder.
2. Trigger the platform native share sheet (for direct sharing to TikTok, Instagram Reels, YouTube Shorts).

### REQ-EXPORT-03: Web Client Cloud Fallback
**[WHEN]** The client is running in a web browser without native hardware encoder access,
**[SHALL]** The client SHALL dispatch an export request to `POST /v1/video/export` on `vhunambi_api`, which renders the MP4 in a background worker and returns a direct Cloudflare R2 download URL.
