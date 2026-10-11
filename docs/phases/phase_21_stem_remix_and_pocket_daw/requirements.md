# Phase 21 · Requirements — Audio-Stem Social Remixing & Pocket 4-Channel Stem Mixer

> **Phase:** 21  
> **Codename:** `stem-remix-and-pocket-daw`  
> **Status:** 🟡 SPECIFICATION  
> **Target Apps:** `apps/vhunambi_client`  
> **Architecture Standard:** Dual-Agent Pair Programming Standard ([`docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md))  

---

## 1. Functional Requirements

### Track A: Social Stem Remixing & Viral Lineage

- **REQ-RMX-01 (Reel Remix Action)**: In [`KineticReelsModal`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/social/presentation/widgets/kinetic_reels_modal.dart), the action rail MUST include a `Remix` button (`Icons.alt_route_rounded` or `Icons.transform_rounded`, key: `reel_remix_btn`).
- **REQ-RMX-02 (Context Extraction)**: Tapping Remix MUST package the clip's track stems, metadata, and attribution into a `StemRemixContext` (`parentClipId`, `parentCreatorUsername`, `parentTrackTitle`, `parentCoverArtUrl`, `stems`).
- **REQ-RMX-03 (Attribution Lineage Metadata)**:
  - The `PublishedClip` model MUST support `remixedFromClipId` (optional String) and `remixAttribution` (optional String, e.g., `"🔁 Remixed from @makhadzi's 'Makhado Sunrise'"`).
  - When publishing a remixed reel, this lineage metadata MUST be saved.
- **REQ-RMX-04 (Lineage UI Badge)**:
  - On `KineticReelsModal` and `TrendingReelCard`, if a clip is a remix, a stylized lineage pill MUST be displayed beneath the title.
  - Tapping the lineage pill MUST navigate or highlight the parent reel.

---

### Track B: Pocket 4-Channel Stem Mixer & Master Bus DSP Console

- **REQ-MIX-01 (4-Channel Strip Model)**:
  - The mixer MUST represent 4 independent audio channels:
    1. 🎤 **Vocals**
    2. 🥁 **Drums**
    3. 🎹 **Bass / Log Drum**
    4. 🎸 **Melody / Instruments**
  - Each channel MUST have:
    - `gain`: 0.0 to 1.5 (default 1.0)
    - `pan`: -1.0 (hard left) to +1.0 (hard right) (default 0.0)
    - `isMuted`: boolean (default false)
    - `isSolo`: boolean (default false)
- **REQ-MIX-02 (Solo & Mute Logic)**:
  - If any channel has `isSolo == true`, only soloed channels are active.
  - If a channel is muted (`isMuted == true`), its effective volume is 0.0 (unless unmuted).
  - Solo overrides mute for active playback calculation.
- **REQ-MIX-03 (Bantu Master Bus DSP)**:
  - The master bus MUST provide 4 customizable DSP parameters:
    1. `logDrumSaturation`: 0.0 to 1.0 (harmonic distortion & low-end warmth)
    2. `vocalPlateReverb`: 0.0 to 1.0 (spatial room tail)
    3. `sidechainCompression`: 0.0 to 1.0 (pumping ducking effect)
    4. `stereoWidth`: 0.0 to 1.5 (stereo imaging expansion)
- **REQ-MIX-04 (Tactile Pocket Mixer Deck)**:
  - Provide `StemMixerDeck` widget:
    - 4 vertical fader columns with volume sliders, dB readouts, pan sliders, and M/S toggle buttons.
    - Master Bus DSP section with 4 dials/sliders and quick presets: *"Amapiano Club Banger"*, *"Deep Maskandi Acoustic"*, *"Clean Vocal Duet"*.
    - Visual peak meter simulation with responsive layout.
- **REQ-MIX-05 (Master Bounce & Content Studio Bridge)**:
  - Provide a **"Bounce Master"** button that renders the current balance into an updated master mix and provides 1-tap handoff to the Content Studio (`/content-studio`) or Publish Clip Modal.

---

## 2. Non-Functional & Token Discipline

- **NFR-TOK-01**: Zero raw hex colors. Strictly use `AppColors`, `AppRadius`, `AppTypography`, `AppSpacing`, and `AppGradients`.
- **NFR-RSP-01**: Complete responsiveness across mobile (< 768px) and desktop (> 1024px) with zero `RenderFlex` overflow errors.
- **NFR-TST-01**: 100% test pass rate across all new and existing test suites.
