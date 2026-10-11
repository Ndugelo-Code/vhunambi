# Phase 22 · Architectural Blueprint — Heritage Crate Digging & Native Video Muxer

> **Phase:** 22  
> **Codename:** `heritage-crate-and-video-muxer`  
> **Target Apps:** `apps/vhunambi_client`  
> **Dual Track Focus:**  
> - **Track A (Audio Production):** Indigenous Heritage Sound Archives & AI 8-Pad MPC Sample Slicer  
> - **Track B (Social Syndication):** Native Hardware Video Muxer & TikTok/Instagram Auto-Export Rail  
> **Standard:** Vhunambi Autonomous Engineering Standard ([`docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md))

---

## 1. Executive Architectural Vision

### Track A: Heritage Crate Digging & AI MPC Sample Slicer
Amapiano, Maskandi, and Afrobeat music production is anchored in the fusion of modern digital synthesis with ancestral acoustic percussion, polyrhythmic chants, and indigenous instrumentation. Phase 22 equips African producers with:
1. **Heritage Crate Browser (`/studio?tab=crate` & Studio Drawer):** An interactive 3D-inspired spinning vinyl crate filled with royalty-free, high-fidelity indigenous African samples (Mbira, Kora, Marimba, Talking Drum, Uhadi Bow, Chants, Flutes).
2. **8-Pad AI MPC Slicer:** 1-tap transient detection and zero-crossing beat slicing that decomposes any heritage sample, stem, or user recording into 8 responsive tactile pads (`MpcPadEntity`).
3. **Real-Time Pitch & Reverse Engine:** Per-pad chromatic semitone shifting (−12 to +12 semitones), reverse playback, and time-stretching ratios (0.5× to 2.0×).
4. **Direct Studio Bridges:** 1-tap "Send to Stem Mixer" (loads sliced chops into the pocket DAW) and "Record into Studio" (routes MPC patterns into the generative prompt context).

```
┌────────────────────────────────────────────────────────────────────────┐
│                        HERITAGE CRATE BROWSER                          │
│  [🔍 Search indigenous...] [Categories: All | Percussion | Strings...] │
│  ┌───────────────────────┐  ┌────────────────────────────────────────┐ │
│  │  (💿 Spinning Vinyl)  │  │ Mbira DzaVadzimu (112 BPM · Key: F#)   │ │
│  │   Authentic Shona     │  │ Region: Zimbabwe / Great Zimbabwe      │ │
│  │     Mbira Loop        │  │ [▶ Audition] [✂ Slice in MPC] [⭐ Fav]  │ │
│  └───────────────────────┘  └────────────────────────────────────────┘ │
├────────────────────────────────────────────────────────────────────────┤
│                       8-PAD AI MPC SAMPLE SLICER                       │
│  Source: "Mbira DzaVadzimu" (112 BPM)   Stretch: 1.0x   Pitch: 0 st    │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐   │
│  │ PAD 1 [0.0s] │ │ PAD 2 [0.5s] │ │ PAD 3 [1.0s] │ │ PAD 4 [1.5s] │   │
│  │ Pitch: 0 st  │ │ Pitch: +2 st │ │ Pitch: 0 st  │ │ REV: [ON]    │   │
│  ├──────────────┤ ├──────────────┤ ├──────────────┤ ├──────────────┤   │
│  │ PAD 5 [2.0s] │ │ PAD 6 [2.5s] │ │ PAD 7 [3.0s] │ │ PAD 8 [3.5s] │   │
│  │ Pitch: -3 st │ │ Pitch: 0 st  │ │ Pitch: +5 st │ │ Vol: 1.2x    │   │
│  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘   │
│  [🔄 Re-Slice Stems]   [🎹 Send to Stem Mixer]   [🎙️ Record into Studio]│
└────────────────────────────────────────────────────────────────────────┘
```

---

### Track B: Native Hardware Video Muxing & Direct Social Syndication
While Phase 17 and 18 built the 60 FPS kinetic preview canvas, creators currently lack high-speed hardware video compilation and direct 1-tap syndication to global video networks. Phase 22 bridges:
1. **Native Hardware Video Muxer (`VideoExportNotifier`):** Hardware-accelerated background renderer that compiles 9:16 vertical (1080×1920) or 1:1 square (1080×1080) MP4s combining kinetic lyrics, animated album art, waveform audio reactives, and high-fidelity 320 kbps AAC stem audio.
2. **Direct Social Share Rail:** 1-tap integration buttons for:
   - 🎵 **TikTok** (`ShareTarget.tiktok`)
   - 📸 **Instagram Reels / Stories** (`ShareTarget.instagramReels`)
   - ▶️ **YouTube Shorts** (`ShareTarget.youtubeShorts`)
   - 💾 **Save to Camera Roll / DCIM** (`ShareTarget.cameraRoll`)
3. **Automated Viral Metadata & Lineage Stamping:** Auto-generates captions with African genre hashtags (`#Amapiano #Vhunambi #Afrobeats #LogDrum`), remix attribution lineages, and creator tags.
4. **Holographic Audio Stamp & Watermark:** Animated glowing Vhunambi watermark overlay with custom toggle.

```
┌────────────────────────────────────────────────────────────────────────┐
│                   NATIVE VIDEO EXPORT & SYNDICATION                    │
│  Preview: "Makhado Sunrise" (9:16 · 1080x1920 @ 60 FPS · 15.0s)        │
│  Progress: [██████████████████████████████████████] 100% Complete      │
│  Watermark: [X] Holographic Vhunambi Stamp   Preset: Kinetic Amber Glow│
├────────────────────────────────────────────────────────────────────────┤
│  Generated Caption:                                                    │
│  "Makhado Sunrise 🌅 ft. @makhadzi. Remixed on Vhunambi AI.            │
│   #Amapiano #Vhunambi #Afrobeats #LogDrum #AfricanMusic"   [📋 Copy]   │
├────────────────────────────────────────────────────────────────────────┤
│                       DIRECT SOCIAL SHARE RAIL                         │
│  [🎵 Share to TikTok]      [📸 Instagram Reels]                        │
│  [▶️ YouTube Shorts]        [💾 Save to Gallery]                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Component Layout & Breakpoint Geometries

| Viewport | Layout Strategy |
|:---|:---|
| **Mobile (< 768px)** | - Crate Browser: Vertical card stack with rotating vinyl badge at top.<br>- 8-Pad MPC: 4×2 compact grid (each pad 76×76px) with bottom sheet pad tweak drawer.<br>- Export Rail: Bottom sheet modal with horizontal social share buttons. |
| **Desktop (> 1024px)** | - Crate Browser: Split-pane view (3D spinning vinyl deck on left, filterable sample table on right).<br>- 8-Pad MPC: Full-width console with prominent wave visualizer, live pad knobs, and pitch sliders.<br>- Export Rail: Embedded preview dock side-by-side with export render progress & share cards. |

---

## 3. Design Token Adherence Matrix
All visual components must strictly consume design tokens from `package:vhunambi_client/core/theme/`:
- **Pads & Crate Surfaces:** `AppColors.surfaceSecondary`, `AppColors.surfaceElevated`, `AppColors.surfaceCanvas`.
- **Pad Active / Triggered State:** `AppColors.brandPrimary` glow with `AppColors.coinGold` accents.
- **Reverse & Pitch Badges:** `AppColors.badgeCyan` and `AppColors.accent`.
- **Borders & Radii:** `AppRadius.cardBorder`, `AppRadius.inputBorder`, `AppRadius.thumbBorder`.
- **Typography:** `AppTypography.headlineMedium`, `AppTypography.titleMedium`, `AppTypography.bodyMedium`, `AppTypography.caption`.
- **NO RAW HEX CODES:** Zero raw color values permitted.
