# Phase 37 Requirements: Open-Verse Challenges, Stem-Flip Chains & Co-Creation Royalties

**Document Version:** 1.0.0  
**Status:** Approved  
**Standards:** STD-UIUX-001

---

## 1. Functional Requirements

### Track A: Real 44.1 kHz PCM Mixdown Engine (`StemMixBounceService`)
- **REQ-MIX-01 (Real PCM Summing):** `StemMixBounceService.bounceStemMix` MUST sum real 16-bit 44,100 Hz stereo PCM audio samples rather than zero-filled arrays. `isSimulated` MUST be set to `false` when valid audio data is processed.
- **REQ-MIX-02 (Groove & Vocal Integration):** The engine MUST be capable of summing:
  1. 5-channel backing groove from `MelodyWavSynthesizer` (drums, bass, melodic stems).
  2. Vocal take buffer from `SoundSignatureResynthesizer` (or synthesized test tone phrase if no vocal is present).
  3. Channel fader gains and pan laws from `StemMixerState`.
- **REQ-MIX-03 (Master Bus DSP & Limiter):** The master mix MUST pass through `MasterBusDsp`:
  - Peak ceiling clamped to $\le -1.0\text{ dBFS}$ without digital clipping.
  - Sub-bass harmonic saturation for log-drum weight.
  - Return a valid RIFF/WAVE header (44 bytes) followed by non-zero audio payload.

### Track B: Remix Lineage Graph & Co-Creation Split Economics
- **REQ-RMX-MODEL-01 (Lineage Metadata):** `StemRemixContext`, `PublishedClip`, and `SocialMusicPost` MUST carry:
  - `creationMode`: `RemixCreationMode` (`openVerseVocal`, `beatStemFlip`, `aiStudioRemix`).
  - `parentClipId`: ID of the parent clip/track.
  - `parentTrackTitle`: Title of the parent track.
  - `parentCreatorId` & `parentCreatorHandle`: Attribution of the originator.
  - `remixGenerationDepth`: Integer depth (1 for direct children, 2 for grand-children).
  - `coCreationSplits`: List of `SplitParticipant` with default 70% Remixer / 30% Originator.
- **REQ-RMX-TREE-01 (Remix Lineage Provider):** `remixLineageTreeProvider(String rootOrChildId)` MUST resolve the root ancestor and all descendant remix nodes across published clips and posts.
- **REQ-RMX-ROYALTY-01 (Automatic Tip Distribution):** When tipping a remixed track/clip via `CreatorTippingSheet`, `distributeTrackTip` MUST allocate 70% to the remixer and 30% to the originator.
- **REQ-RMX-ROYALTY-02 (Split UI Transparency):** `CreatorTippingSheet` MUST render a split disclosure pill (`70% @remixer · 30% @originator`).

### Track C: 3-Mode Co-Creation Remix Cockpit (`OpenVerseRemixCockpitSheet`)
- **REQ-COCKPIT-01 (Trigger & Launch):** Tapping the Remix button on `ExploreSocialPostCard` or `KineticReelsModal` MUST launch `OpenVerseRemixCockpitSheet`.
- **REQ-COCKPIT-02 (Mode A - Drop Open Verse):**
  - Allow 1-bar count-in and microphone recording over parent instrumental.
  - Automatically configure `VocalIdealizer` locked to parent key and scale mode.
  - Provide `Audition Mix` toggle and `Publish Open-Verse Reel` button.
- **REQ-COCKPIT-03 (Mode B - Flip Beat & Log-Drum):**
  - Instant macro-switching across 6 regional genres (Amapiano, Gqom, Hip-Hop 808, Afrobeats, Deep House, Maskandi) while locked to parent BPM and Key.
  - Button to open full 5-channel `MelodySketchpadModal`.
  - 1-tap `Bounce & Publish Beat-Flip`.
- **REQ-COCKPIT-04 (Mode C - Full Studio Handoff):**
  - Pre-load `stemRemixProvider` with parent metadata and route to Studio tab (index 2).

### Track D: Feed Participation Chips & Lineage Tree Sheet
- **REQ-FEED-01 (Remix Lineage Pill):** Every card on Explore and reel in `KineticReelsModal` MUST display an interactive lineage pill (`Open Stems · N Remixes` or `Remix of @originator`).
- **REQ-TREE-01 (RemixLineageTreeSheet):** Tapping the lineage pill opens `RemixLineageTreeSheet`, rendering the visual family tree with 1-tap play buttons and "Drop Your Verse on This Chain".
- **REQ-BANNER-01 (Studio Active Remix Banner):** When `stemRemixProvider` is active, `StudioView` MUST render `ActiveRemixLineageBanner` with parent info and a 1-tap clear button.

---

## 2. Non-Functional & Quality Requirements
- **REQ-QA-01 (Zero Static Analysis Warnings):** `dart analyze lib test` = 0 issues.
- **REQ-QA-02 (Test Coverage):** 100% green tests in `phase37_open_verse_and_remix_chains_test.dart` and existing suites.
- **REQ-QA-03 (UI Ergonomics):** All interactive targets $\ge 44\times 44\text{dp}$, Phosphor icons only, zero raw emojis/hex.
- **REQ-QA-04 (Release Size Budget):** Release APK size $\le 200\text{ MB}$.

