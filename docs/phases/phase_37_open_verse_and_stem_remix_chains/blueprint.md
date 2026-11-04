# Phase 37 Blueprint: Participatory Open-Verse Challenges, Interactive Stem-Flip Chains & Co-Creation Royalties

**Document Version:** 1.0.0  
**Status:** Approved for Implementation  
**Target Platform:** Mobile (Android ARM64 / iOS) & Desktop  
**Design Standards:** STD-UIUX-001 (Phosphor only, $\ge 44\times 44\text{dp}$ touch targets, dynamic `AppColors`, zero raw emojis/hex)

---

## 1. Executive Summary & Vision

Phase 37 transforms Vhunambi from an isolated music generation workbench into **Africa's First Participatory Sonic-Visual Social Network**.

In South Africa and across the African continent, music is not a static, finished file consumed passively—it is a participatory cultural conversation. An Amapiano track or Gqom beat dropped by an originator creator (like `@makhadzi`) is an open invitation for vocalists to drop verses, producers to flip log drums, and choreographers to dance in community remix chains.

Until Phase 37, tapping "Remix" merely copied a prompt string into the Studio form. Phase 37 unifies:
1. **Phase 35/36 Sound Signature & Vocal Idealizer** (mic capture, pitch scaling, Bantu depressor/tone guards).
2. **Phase 32 5-Channel Multi-Track Sketchpad** (44.1 kHz PCM groove engine, Euclidean rhythms, log-drum slides).
3. **Phase 21 Stem Remix Context** (BPM/Key locked track lineage).
4. **Phase 34 Royalty Distribution Engine** (automatic 70% Remixer / 30% Originator ZAR/Coin split-sheets).
5. **Real 44.1 kHz PCM Mixdown** in `StemMixBounceService` (eliminating the silent zero-byte stub from Category F #1).

---

## 2. Architecture & System Flow

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                           PHASE 37 CO-CREATION FLYWHEEL                                 │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                         │
│  [ ExploreSocialPostCard / KineticReelsModal ]                                          │
│        │                                                                                │
│        ├─► [ 🎤 Drop Open Verse ]  ─┐                                                   │
│        ├─► [ 🥁 Flip Log-Drum ]    ─┼─► Opens OpenVerseRemixCockpitSheet                │
│        └─► [ 🌿 Remix Tree (14) ]  ─┴─► Opens RemixLineageTreeSheet                     │
│                                                                                         │
│  [ OpenVerseRemixCockpitSheet ]                                                         │
│        │                                                                                │
│        ├─► Mode A: Drop Open Verse                                                      │
│        │     • Live backing track playback (113 BPM • Am)                               │
│        │     • 1-bar count-in + mic capture via IAudioIntakeRecorder                    │
│        │     • Real-time VocalIdealizer pitch snap (AfricanScaleMode.minorPentatonic)   │
│        │     • Bantu consonant depressor + tone polarity guards                         │
│        │     • Audition Mix A/B toggle                                                  │
│        │                                                                                │
│        ├─► Mode B: Flip Beat & Log-Drum                                                 │
│        │     • Locked to parent BPM (113) and Root Key (Am)                             │
│        │     • 6-genre kit macro switcher (Amapiano, Gqom, Hip-Hop 808, Afrobeats, etc) │
│        │     • Euclidean rhythm density dial                                            │
│        │     • Deep link into full 5-channel MelodySketchpadModal                       │
│        │                                                                                │
│        └─► Mode C: Full Studio Handoff                                                  │
│              • Mounts ActiveRemixLineageBanner in StudioView                            │
│              • Pre-populates stemRemixProvider with parent metadata                     │
│                                                                                         │
│  [ Real 44.1 kHz Audio Mixdown ]                                                        │
│        │                                                                                │
│        └─► StemMixBounceService:                                                        │
│              • Sums 5-channel backing groove PCM from MelodyWavSynthesizer              │
│              • Sums user vocal take PCM from SoundSignatureResynthesizer                │
│              • Applies channel gains + MasterBusDsp (tube drive, limiter, mid-side)     │
│              • Generates non-silent, playable 44,100 Hz Stereo WAV file                 │
│                                                                                         │
│  [ Publication & Automatic 70/30 Royalty Routing ]                                      │
│        │                                                                                │
│        ├─► Prepends remixed post to socialFeedProvider & socialFeedPostsProvider        │
│        ├─► Attaches CoCreationSplits (70% Remixer / 30% Originator)                     │
│        └─► Fan tipping in CreatorTippingSheet automatically splits ZAR & Coins          │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Four Core Pillars

### Pillar 1: Real 44.1 kHz PCM Stem Summing Engine
Resolves Audit Category F #1: `StemMixBounceService` is upgraded from writing a zero-filled simulated buffer (`isSimulated: true`) to performing genuine 16-bit 44.1 kHz stereo PCM sample summing. It combines the multi-track groove from `MelodyWavSynthesizer` with the vocal take from `SoundSignatureResynthesizer`, applies soft-knee limiting at `-1.0 dBFS`, and outputs real playable audio.

### Pillar 2: 3-Mode Co-Creation Remix Cockpit (`OpenVerseRemixCockpitSheet`)
A bottom sheet launched when tapping "Remix" on any social card or full-screen kinetic reel.
- **Header:** Parent track artwork, title, `@handle`, key/BPM badge, and the `70% You · 30% Originator` split indicator.
- **Tab 1: Drop Open Verse:** Live mic recording over parent instrumental, automated scale-locking via `VocalIdealizer`, audition mix, and 1-tap publish.
- **Tab 2: Flip Beat & Log-Drum:** Instant genre kit swap (e.g. Amapiano to Gqom), log drum pattern reconfiguration, and groove bounce.
- **Tab 3: Full Studio Handoff:** Sets up studio session with persistent lineage banner and locks to parent BPM/Key.

### Pillar 3: Visual Remix Lineage Tree (`RemixLineageTreeSheet`)
Displays the genealogical tree of musical co-creations:
- Root node: Originator song (`@makhadzi` - *"Ndo Mufuna Matibe"*).
- Branch nodes: Child open-verse takes and beat flips created by community artists.
- Interactive actions: Audition any node in 1 tap, inspect split-sheet shares, or branch directly from any remix node.

### Pillar 4: Automatic Co-Creation Split-Sheet Economy
Whenever a remixed clip or post receives tips via `CreatorTippingSheet`:
$$\text{Remixer Share} = \text{round}(0.70 \times \text{Net Proceeds})$$
$$\text{Originator Share} = \text{round}(0.30 \times \text{Net Proceeds})$$
Processed atomically through `RoyaltyDistributionService` with transparent ledger entries for Capitec Pay / Ozow settlements.

