# Dual-Agent Master Handoff — Phase 22: Heritage Crate Digging & Native Video Muxer

> **Phase:** 22  
> **Codename:** `heritage-crate-and-video-muxer`  
> **Target Apps:** `apps/vhunambi_client`  
> **Baseline Status:** `dart analyze` = **0 issues** | Foundation unit tests: **17/17 passing (100%)**  
> **Branch:** `main`

---

## 1. Executive Summary & Architecture

Phase 22 delivers two integrated flagship subsystems:
- **Track A (Audio Production):** **Indigenous Heritage Sound Archives & 8-Pad AI MPC Sample Slicer**
  - **Heritage Crate Browser:** Interactive spinning vinyl browser with authentic royalty-free African folk instruments (Mbira, Kora, Talking Drum, Marimba, Uhadi Bow, Venda Chants).
  - **8-Pad AI MPC Slicer:** 1-tap transient detection auto-slicing samples/stems into 8 responsive tactile pads (`MpcPadEntity`), with chromatic semitone shifting (−12..+12), reverse playback, time-stretching (0.5×..2.0×), and direct DAW bounce bridges.
- **Track B (Social Syndication):** **Native Hardware Video Muxer & Direct Social Export Rail**
  - **Video Export Engine:** Background hardware renderer compiling 9:16 vertical (1080×1920) or 1:1 square (1080×1080) MP4s with 30/60 FPS and holographic watermark toggle.
  - **Direct Social Share Rail:** 1-tap syndication to 🎵 **TikTok**, 📸 **Instagram Reels**, ▶️ **YouTube Shorts**, and 💾 **Save to Camera Roll**.
  - **Viral Metadata Generator:** Automated African genre hashtags (`#Amapiano #Vhunambi #Afrobeats #LogDrum`) and creator lineage attribution.

---

## 2. Foundations Already Implemented & Verified by Chief Architect

All domain models, immutable state objects, Riverpod notifiers, and unit tests are already in place:
1. **`lib/features/studio/domain/models/heritage_crate_models.dart`**
   - `HeritageCrateCategory` (`all`, `percussion`, `pluckedStrings`, `melodicIdiophones`, `traditionalPipes`, `chants`)
   - `HeritageSampleEntity` & `kSeededHeritageSamples` (6 authentic seeded instruments with waveforms & cultural metadata)
   - `MpcPadEntity` (0..7 index, label, slice start/end, pitch shift, isReversed, volume, isTriggered)
   - `MpcSlicerState` (pads, selectedPadIndex, sourceTitle, bpm, timeStretchRatio, lastBouncedChopPath)
2. **`lib/features/studio/presentation/providers/heritage_crate_provider.dart`**
   - `heritageCrateProvider` (`HeritageCrateNotifier`): `setCategory`, `setSearchQuery`, `toggleFavorite`, `startAudition`, `stopAudition`, `filteredSamples`.
   - `mpcSlicerProvider` (`MpcSlicerNotifier`): `sliceSample(sample)`, `selectPad(index)`, `triggerPad(index)`, `releasePad(index)`, `setPitchShift(index, semitones)`, `toggleReverse(index)`, `setPadVolume(index, vol)`, `setTimeStretch(ratio)`, `bounceChops()`.
3. **`lib/features/social/domain/models/video_export_job.dart`**
   - `VideoExportResolution` (`vertical9x16`, `square1x1`)
   - `SocialShareTarget` (`tiktok`, `instagramReels`, `youtubeShorts`, `cameraRoll`)
   - `VideoExportStatus` (`idle`, `muxing`, `completed`, `failed`)
   - `VideoExportJob` & `VideoExportState`
4. **`lib/features/social/presentation/providers/video_export_provider.dart`**
   - `videoExportProvider` (`VideoExportNotifier`): `prepareJob(job)`, `setResolution(res)`, `setFps(fps)`, `toggleWatermark(enabled)`, `generateViralCaption(...)`, `startMuxing()`, `shareTo(target)`, `reset()`.
5. **Architect Verification Suites:**
   - `test/features/studio/heritage_crate_provider_test.dart` (12/12 passing)
   - `test/features/social/video_export_provider_test.dart` (5/5 passing)

---

## 3. Cline's UI Implementation Tasks

### Task 1: `CrateBrowserDeck` (Spinning Vinyl & Sample Explorer)
**File:** `lib/features/studio/presentation/widgets/crate_browser_deck.dart` (new)
- **Header:** "Heritage Crate Digging 💿" + "Indigenous Sound Archive" subtitle.
- **Spinning Vinyl Graphic (`_VinylDiskWidget`):** 80×80 (or 100×100) circular dark vinyl record graphic with spinning animation (`RotationTransition` or `AnimatedBuilder`) active when `state.auditioningSampleId != null`.
- **Search Bar:** Input with search icon to filter by instrument, region, or tags via `ref.read(heritageCrateProvider.notifier).setSearchQuery(v)`.
- **Category Filter Rail:** Horizontal scrolling chips for `HeritageCrateCategory.values`:
  - Label with emoji (`all`, `percussion`, `pluckedStrings`, etc.).
  - Active chip has `AppColors.brandPrimary` background and `AppColors.brandContrast` text.
  - Tapping calls `ref.read(heritageCrateProvider.notifier).setCategory(cat)`.
- **Sample List Tiles (`_SampleTile`):**
  - Displays instrument emoji, title, culture/region, BPM pill, Key pill.
  - Audition play/pause button (`key: Key('audition_${sample.id}')`):
    - Tapping calls `startAudition(sample.id)` if not playing, or `stopAudition()` if playing.
  - Favorite toggle heart (`key: Key('fav_${sample.id}')`):
    - Tapping calls `toggleFavorite(sample.id)`.
  - **"✂ Chop in MPC" Button (`key: Key('chop_${sample.id}')`):**
    - Calls `ref.read(mpcSlicerProvider.notifier).sliceSample(sample)` and switches active view/sheet to `MpcSlicerDeck`.

### Task 2: `MpcSlicerDeck` (8-Pad AI MPC Tactile Slicer)
**File:** `lib/features/studio/presentation/widgets/mpc_slicer_deck.dart` (new)
- **Header:** Displays `state.sourceTitle` + `${state.bpm} BPM`.
  - Time-stretch slider (0.5× to 2.0×) labeled `Stretch: ${state.timeStretchRatio.toStringAsFixed(1)}x`.
- **8-Pad Tactile Grid (4×2 Grid):**
  - 8 pads (`key: Key('mpc_pad_$index')`, for index 0..7).
  - Each pad shows:
    - Pad index label (`PAD 1`, `PAD 2`...).
    - Slice time range (`${pad.startSec.toStringAsFixed(1)}s`).
    - Pitch shift pill if non-zero (`+2 st`, `-3 st`).
    - Reverse icon pill if `isReversed`.
    - Active glow styling when `pad.isTriggered` or `index == state.selectedPadIndex`.
  - Tapping a pad calls `ref.read(mpcSlicerProvider.notifier).triggerPad(index)` (and schedules `releasePad` or triggers audition).
- **Selected Pad Modulation Deck:**
  - Semitone Pitch Slider (`key: const Key('mpc_pitch_slider')`): −12 to +12 semitones via `setPitchShift(selectedPadIndex, val)`.
  - Reverse Toggle (`key: const Key('mpc_reverse_toggle')`): flips `toggleReverse(selectedPadIndex)`.
  - Pad Volume Slider (`key: const Key('mpc_vol_slider')`): 0.0 to 1.5 via `setPadVolume(selectedPadIndex, val)`.
- **Action Buttons:**
  - **"🎹 Send to Stem Mixer" (`key: const Key('mpc_send_to_mixer')`): bounces chop kit via `bounceChops()` and shows celebration SnackBar.
  - **"🎙️ Record into Studio" (`key: const Key('mpc_send_to_studio')`): displays SnackBar that chop kit has been routed into generative prompt context.

### Task 3: Mount Crate & MPC Decks in Studio
**File:** `lib/features/studio/presentation/views/studio_view.dart`
- In `StudioView`, add a button or drawer trigger ("Heritage Crate & MPC Slicer" with icon `Icons.album_rounded`) opening `CrateBrowserDeck` and `MpcSlicerDeck` in a modal sheet (`showModalBottomSheet` with `AppRadius.modalBorder`).

### Task 4: `VideoExportModal` (Hardware Video Muxer & Social Share Rail)
**File:** `lib/features/social/presentation/widgets/video_export_modal.dart` (new)
- Can be invoked statically via `VideoExportModal.show(context, {required VideoExportJob job})`.
- Initializes `videoExportProvider.notifier.prepareJob(job)`.
- **Top Bar:** "Native Video Muxer" + "1080p 60 FPS" badge.
- **Configuration Controls:**
  - Resolution selector: `9:16 Kinetic Reel` vs `1:1 Cover Art` (`key: Key('res_${res.name}')`).
  - Framerate selector: `30 FPS` vs `60 FPS` (`key: Key('fps_$fps')`).
  - Holographic Watermark Switch (`key: const Key('watermark_switch')`): toggles watermark.
- **Render Button (`key: const Key('export_render_btn')`):**
  - Calls `ref.read(videoExportProvider.notifier).startMuxing()`.
  - Shows animated linear progress bar with percentage readout while `state.isMuxing`.
- **Post-Render Panel (visible when `state.isCompleted`):**
  - Generated viral caption container with `#Amapiano #Vhunambi #Afrobeats #LogDrum` tags.
  - 1-tap "Copy Caption" button (`key: const Key('copy_caption_btn')`).
  - **`SocialShareRail`:** 4 action buttons:
    - 🎵 `TikTok` (`key: const Key('share_tiktok_btn')`) -> `shareTo(SocialShareTarget.tiktok)`.
    - 📸 `Instagram` (`key: const Key('share_instagram_btn')`) -> `shareTo(SocialShareTarget.instagramReels)`.
    - ▶️ `Shorts` (`key: const Key('share_shorts_btn')`) -> `shareTo(SocialShareTarget.youtubeShorts)`.
    - 💾 `Save to Gallery` (`key: const Key('share_gallery_btn')`) -> `shareTo(SocialShareTarget.cameraRoll)`.
    - Shows SnackBar on successful share tap.

### Task 5: Mount `VideoExportModal` Trigger
**File:** `lib/features/player/presentation/widgets/expanded_cockpit_modal.dart` and/or `lib/features/content_studio/presentation/views/content_studio_dock_view.dart`
- In `ExpandedCockpitModal` (or `ContentStudioDockView`), wire the Export action to open `VideoExportModal.show(...)`.

### Task 6: Widget Tests
1. **`test/features/studio/widgets/crate_browser_deck_test.dart`** (new)
   - Renders search input, category chips, and sample cards.
   - Tapping a category filters samples.
   - Tapping audition flips playing state.
   - Tapping Chop calls `sliceSample` and triggers callback.
2. **`test/features/studio/widgets/mpc_slicer_deck_test.dart`** (new)
   - Renders 8 MPC pads (`Key('mpc_pad_0')` to `Key('mpc_pad_7')`).
   - Tapping pad triggers activation.
   - Tapping pitch slider adjusts semitones.
   - Tapping reverse toggle flips reverse flag.
   - Tapping Send to Stem Mixer invokes `bounceChops`.
3. **`test/features/social/widgets/video_export_modal_test.dart`** (new)
   - Renders job title, resolution chips, and watermark switch.
   - Tapping Render Button executes muxing loop and displays 100% progress.
   - Renders `SocialShareRail` with TikTok, Instagram, Shorts, Gallery buttons.
   - Tapping share button executes `shareTo`.

---

## 4. Guardrails & Token Discipline

1. **Colors & Theming:** Use `AppColors` and `AppTypography`. Never hardcode raw hex colors.
2. **Radii & Spacing:** Use `AppRadius.cardBorder`, `AppRadius.inputBorder`, `AppRadius.modalBorder`, `AppSpacing.md`, `AppSpacing.sm`.
3. **Constructor Keys:** All custom widgets must pass `super.key` properly:
   ```dart
   const CrateBrowserDeck({super.key});
   ```
4. **Layout Safety:** Wrap modal and deck bodies in `SingleChildScrollView` to prevent `RenderFlex` overflow on small screens.
5. **Test Timer Safety:** For SnackBar notifications or animated progress bars, drain timers in tests using `await tester.pump(const Duration(seconds: 4));`.
6. **Analyze Cleanliness:** After completing UI code, run:
   ```powershell
   dart analyze lib/features/studio lib/features/social test/features/studio test/features/social
   flutter test test/features/studio test/features/social
   ```
