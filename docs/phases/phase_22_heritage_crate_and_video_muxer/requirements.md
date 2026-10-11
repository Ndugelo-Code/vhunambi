# Phase 22 · Requirements Specification — Heritage Crate Digging & Native Video Muxer

> **Phase:** 22  
> **Codename:** `heritage-crate-and-video-muxer`  
> **Target Apps:** `apps/vhunambi_client`  
> **Standard:** RFC 2119 (`MUST`, `SHALL`, `SHOULD`, `MAY`) & EARS Syntax

---

## 1. Track A: Heritage Crate Digging & AI MPC Sample Slicer

### REQ-CRATE-01: Heritage Sound Archive Catalog
- The system **MUST** provide a curated catalog of authentic, royalty-free African indigenous instruments (`HeritageSampleEntity`), including at least:
  1. *Mbira DzaVadzimu* (Shona / Zimbabwe)
  2. *Kora Griot Pluck* (Mande / West Africa)
  3. *Talking Drum Poly-Rhythm* (Yoruba / Nigeria)
  4. *Marimba Forest Melody* (Southern & East Africa)
  5. *Uhadi Resonance Bow* (Xhosa / South Africa)
  6. *Pygmy / Zulu Folk Chants*
- Each sample entity **MUST** specify `id`, `name`, `instrument`, `cultureRegion`, `bpm`, `rootKey`, `durationSec`, `tags`, and `waveformPeaks`.

### REQ-CRATE-02: Vinyl Crate Audition & Dynamic Rotation
- The UI **MUST** present an interactive spinning vinyl record preview (`CrateVinylPlayer`).
- When playing or auditioning a sample, the vinyl graphic **MUST** smoothly rotate.
- Pausing or selecting a new sample **MUST** gracefully halt rotation.
- Tapping the favorite toggle **MUST** update `isFavorite` in `HeritageCrateNotifier`.

### REQ-CRATE-03: Category & Regional Filter Rail
- The crate browser **MUST** support filtering by `HeritageCrateCategory`:
  - `all`, `percussion`, `pluckedStrings`, `melodicIdiophones`, `traditionalPipes`, `chants`.
- Search queries **MUST** match against sample titles, instrument names, and culture/region tags.

### REQ-MPC-01: 8-Pad AI MPC Transient Slicing
- When a user taps "Chop in MPC" or provides a stem URL, the system **MUST** partition the audio segment into exactly 8 distinct temporal slices (`MpcPadEntity` index 0..7).
- Each pad slice **MUST** record `startSec`, `endSec`, `label`, `pitchShiftSemitones` (default 0), `isReversed` (default false), `volume` (default 1.0), and `isMuted` (default false).

### REQ-MPC-02: Pad Triggering & Tactile Feedback
- Tapping an MPC pad (`key: Key('mpc_pad_$index')`) **MUST** trigger audio playback and visually toggle `isTriggered` for tactile feedback.
- The UI **MUST** highlight active pads using `AppColors.brandPrimary` and `AppColors.coinGold`.

### REQ-MPC-03: Semitone Pitch & Reverse Modulation
- The system **MUST** provide per-pad pitch modulation from −12 to +12 semitones.
- Tapping the reverse toggle on an individual pad **MUST** reverse audio buffer playback.
- The global time-stretch ratio **MUST** support scaling from 0.5× to 2.0× tempo.

### REQ-MPC-04: Pocket DAW & Studio Bridge
- The slicer **MUST** include a "Send to Stem Mixer" action button (`key: Key('mpc_send_to_mixer')`), configuring sliced chops into the active session.
- The slicer **MUST** include a "Record into Studio" action button (`key: Key('mpc_send_to_studio')`), bridging chop metadata into the generative prompt.

---

## 2. Track B: Native Hardware Video Muxing & Direct Social Syndication

### REQ-MUX-01: Video Export Job Configuration
- The system **MUST** maintain a typed `VideoExportJob` model supporting:
  - Resolution: 9:16 vertical (1080×1920) or 1:1 square (1080×1080).
  - Framerate: 30 FPS or 60 FPS.
  - Video bitrate: 12 Mbps to 20 Mbps.
  - Audio bitrate: 320 kbps AAC.
  - Holographic watermark toggle (`includeHolographicWatermark`).

### REQ-MUX-02: Background Muxing & Progress State
- Calling `startExport(job)` on `videoExportProvider.notifier` **MUST** transition state through `idle` → `muxing` (with `progress` 0.0 to 1.0) → `completed` (with `outputPath`).
- In case of rendering abort or failure, the state **MUST** transition to `failed` with descriptive `errorMessage`.

### REQ-MUX-03: Direct Social Share Rail
- The UI **MUST** render dedicated 1-tap action buttons for:
  - 🎵 **TikTok** (`key: Key('share_tiktok_btn')`)
  - 📸 **Instagram Reels** (`key: Key('share_instagram_btn')`)
  - ▶️ **YouTube Shorts** (`key: Key('share_shorts_btn')`)
  - 💾 **Save to Camera Roll** (`key: Key('share_gallery_btn')`)
- Tapping a share button **MUST** invoke `shareToSocial(target)` and display confirmation feedback.

### REQ-MUX-04: Automated Viral Metadata & Hashtags
- The system **MUST** auto-generate viral captions containing:
  - Track title & featured artists.
  - African genre hashtags (`#Amapiano`, `#Vhunambi`, `#Afrobeats`, `#LogDrum`, `#BantuMusic`).
  - Remix lineage attribution if the source clip was remixed.
- A 1-tap "Copy Caption" button **MUST** copy the text to the system clipboard.

### REQ-MUX-05: Holographic Watermark Overlay
- The exported video canvas **MUST** support an optional holographic Vhunambi animated logo and audio watermark stamp in the lower quadrant.
- Users **MAY** toggle this on or off before export.
