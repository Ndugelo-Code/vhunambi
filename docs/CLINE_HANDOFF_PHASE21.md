# Phase 21 Master Handoff: Audio-Stem Social Remixing & Pocket 4-Channel Stem Mixer

> **Phase:** 21  
> **Codename:** `stem-remix-and-pocket-daw`  
> **Working Directory:** `apps/vhunambi_client`  
> **Architecture Standard:** [`docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md)  
> **Spec Suite:** [`docs/phases/phase_21_stem_remix_and_pocket_daw/`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_21_stem_remix_and_pocket_daw/)  
> **Baseline:** `dart analyze apps/vhunambi_client` = 0 issues; all foundation tests passing.  

---

## 1. Executive Summary & Accomplished Foundation

The Lead Architect (Antigravity) has established the complete specification suite and core state management architecture for Phase 21:

1. **Track A — Audio-Stem Social Remixing & Lineage**:
   - [`StemRemixContext`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/social/domain/models/stem_remix_context.dart): Encapsulates parent clip ID, creator username, track title, artwork, and `SongMetadataDna`. Generates formatted lineage string: `🔁 Remixed from @creator's "Track Title"`.
   - [`PublishedClip`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/social/domain/models/published_clip.dart): Extended with `remixedFromClipId`, `remixAttribution`, and `bool get isRemix`. Full JSON serialization and `copyWith` supported.
   - [`StemRemixNotifier` & `stemRemixProvider`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/social/presentation/providers/stem_remix_provider.dart): Coordinates remix initiation from kinetic reels and resets the mixer balance.
   - Comprehensive unit tests in [`test/features/social/stem_remix_context_test.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/test/features/social/stem_remix_context_test.dart) (100% passing).

2. **Track B — Pocket 4-Channel Stem Mixer & Master Bus DSP Console**:
   - [`StemChannel`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/player/domain/models/stem_mixer_state.dart): 4 distinct audio channels:
     1. 🎤 **Vocals**
     2. 🥁 **Drums**
     3. 🎹 **Log Drum / Bass**
     4. 🎸 **Melody / Synth**
     - Controls: `gain` (0.0 to 1.5), `pan` (-1.0 to 1.0), `isMuted`, `isSolo`.
     - Decibel readout helper (`gainDecibels`, e.g. `+0.0 dB`, `-3.5 dB`, `-inf dB`).
     - Priority-safe `effectiveVolume(anySoloActive)` calculation.
   - [`MasterBusDsp`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/player/domain/models/stem_mixer_state.dart): Master bus DSP suite:
     - `logDrumSaturation` (0.0 to 1.0)
     - `vocalPlateReverb` (0.0 to 1.0)
     - `sidechainCompression` (0.0 to 1.0)
     - `stereoWidth` (0.0 to 1.5)
   - [`StemMixerNotifier` & `stemMixerProvider`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/player/presentation/providers/stem_mixer_provider.dart):
     - `setChannelGain`, `setChannelPan`, `toggleMute`, `toggleSolo`.
     - `applyPreset`: *"Amapiano Club Banger"*, *"Deep Maskandi Acoustic"*, *"Clean Vocal Duet"*.
     - `bounceMasterMix`: Renders active balance into a master audio file.
   - Comprehensive unit tests in [`test/features/player/stem_mixer_provider_test.dart`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/test/features/player/stem_mixer_provider_test.dart) (100% passing).

---

## 2. Cline Implementation Assignments (Presentation Layer)

Cline is tasked with building the tactile UI widgets and wiring them into the client views.

### Task 1: `StemMixerDeck` (Pocket DAW Console)
**Target File:** `lib/features/player/presentation/widgets/stem_mixer_deck.dart`
- **Component Layout:**
  - **Header:** Title `"Pocket Stem Mixer"` + subtitle `"4-Channel Console & Master DSP"` + `"Reset"` text button.
  - **4 Channel Strips:**
    - Displayed side-by-side (using `SingleChildScrollView(scrollDirection: Axis.horizontal)` on mobile < 768px, or expanded row on desktop > 1024px).
    - Each strip contains:
      - Icon & name (e.g., `🎤 Vocals`, `🎹 Log Drum`)
      - Decibel indicator pill (e.g., `+0.0 dB`)
      - Vertical gain slider (value: `channel.gain`, range: 0.0 to 1.5, key: `Key('fader_${channel.type.name}')`)
      - Pan slider (value: `channel.pan`, range: -1.0 to 1.0, key: `Key('pan_${channel.type.name}')`) with labels `L` / `C` / `R`
      - M (Mute) & S (Solo) buttons (`key: Key('mute_${channel.type.name}')`, `key: Key('solo_${channel.type.name}')`):
        - Active Mute: `AppColors.error` background
        - Active Solo: `AppColors.coinGold` background with dark text
  - **Master Bus DSP Suite:**
    - 4 horizontal sliders or rotary dials:
      1. Log Drum Saturation
      2. Vocal Plate Reverb
      3. Sidechain Compression
      4. Stereo Width
    - Preset chips: *"Amapiano Club Banger"*, *"Deep Maskandi Acoustic"*, *"Clean Vocal Duet"* (tap dispatches `applyPreset`).
  - **Action Footer:**
    - `"Bounce Master Mix"` button (`key: const Key('mixer_bounce_btn')`):
      - Tapping triggers `ref.read(stemMixerProvider.notifier).bounceMasterMix()`.
      - Shows celebratory `SnackBar` (`"Master mix bounced to /vault/bounces! Ready for Content Studio."`).
- **Mounting:** Mount in `apps/vhunambi_client/lib/features/track/presentation/views/track_detail_view.dart` inside the 4-stem lab section, and offer as a modal bottom sheet / dialog.

---

### Task 2: `RemixAttributionBadge` & Reel Action Rail Wire-Up
**Target File 1:** `lib/features/social/presentation/widgets/remix_attribution_badge.dart`
- **Visuals:** Stylized pill badge:
  - Icon: `Icons.alt_route_rounded` / `Icons.transform_rounded` (`AppColors.badgeCyan` or `AppColors.coinGold`)
  - Text: `clip.remixAttribution` (e.g., `"🔁 Remixed from @makhadzi's 'Makhado Sunrise'"`)
  - If `!clip.isRemix`, returns `const SizedBox.shrink()`.
- **Mounting:**
  - Inside [`KineticReelsModal`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/social/presentation/widgets/kinetic_reels_modal.dart) under the title / creator username.
  - Inside [`TrendingReelCard`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/social/presentation/widgets/trending_reels_shelf.dart).

**Target File 2:** Wire Remix button in `KineticReelsModal`
- In `_ActionRail` inside `kinetic_reels_modal.dart`:
  - Locate the Remix button (`Icons.alt_route_rounded` or add with key `const Key('reel_remix_btn')`).
  - Tapping:
    ```dart
    ref.read(stemRemixProvider.notifier).initiateRemix(clip);
    // Show StemMixer bottom sheet or navigate to studio
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.85,
        child: StemMixerDeck(title: 'Remixing: ${clip.title}'),
      ),
    );
    ```

---

### Task 3: Widget Tests
1. **`test/features/player/widgets/stem_mixer_deck_test.dart`**:
   - Renders all 4 channel strips with faders and M/S controls.
   - Tapping mute toggles channel mute state.
   - Tapping solo toggles channel solo state.
   - Tapping a preset chip updates master DSP.
   - Tapping "Bounce Master Mix" calls bounce logic.
2. **`test/features/social/remix_attribution_badge_test.dart`**:
   - Renders lineage attribution when `clip.isRemix == true`.
   - Returns empty widget when `clip.isRemix == false`.
   - Tapping badge executes tap callback.

---

## 3. Strict Quality Invariants

- **Token Discipline**: Use `AppColors`, `AppRadius`, `AppTypography`, `AppSpacing`. Never hardcode raw hex colors (`0xFF...`).
- **Responsive Layout**: Wrap fader strips in `SingleChildScrollView(scrollDirection: Axis.horizontal)` on narrow viewports to eliminate all `RenderFlex` overflow errors.
- **Verification Rule**: `dart analyze apps/vhunambi_client` must report **0 issues**, and all test suites must pass 100%.
