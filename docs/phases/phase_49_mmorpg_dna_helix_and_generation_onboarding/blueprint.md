# Phase 49 Blueprint: MMORPG Creator DNA Helix & Generation-Aware Onboarding V2

## 1. Metadata Header

- **Phase Code:** PHASE-49
- **Phase Title:** MMORPG Creator DNA Helix, Generation-Aware Roots Deck & Onboarding V2 Polish
- **Status:** 🟡 IN EXECUTION
- **Target Workspaces:** `apps/vhunambi_client`
- **Upstream Dependencies:** Phase 47 (Motion Graphics Onboarding & DNA Genesis), Phase 48 (Edge Sync Production Hardening), Phase 35 (Sound Signature Engine)
- **Downstream Consumers:** `OwnerProfileView`, `ArtistProfileView`, `HomeDashboardView`, `ExploreDiscoveryFeed`

---

## 2. Executive Summary & African Musical Context

Phase 49 resolves the visual, structural, and behavioral issues exposed during physical device testing of Vhunambi's 4-Act motion onboarding (`SVID_20261104_154958_1.mp4`), while upgrading the 3D Creator DNA from a passive visual ornament into a **persistent, interactive MMORPG-style genomic progression tree** that bridges Onboarding directly into the main application.

### Cultural & Generational Sonic Context
African music production is deeply generational and dialect-driven:
1. **Generational Sonic Roots:**
   - **1960–1989 (80s Heritage & Golden Era):** Characterized by Mbaqanga brass riffs, Bubblegum pop synths, Marabi piano chords, Maskandi acoustic finger-picking, and traditional African Gospel harmonies (Mahlatini, Brenda Fassie, Stimela, Busi Mhlongo).
   - **1990–1999 (90s Kwaito & House Era):** Characterized by slowed-down Chicago house grooves (110–115 BPM), punchy Kwaito kick-and-snare patterns, township call-and-response vocals, and early South African Hip-Hop (TKZee, Arthur Mafokate, Boom Shaka, Oskido).
   - **2000–2010 (2000s Piano & Gqom Wave):** Characterized by soulful Rhodes piano keys, jazzy deep house progressions, early broken-beat Gqom raw sub-bass (Durban underground), and contemporary continental Afrobeats (Black Coffee, Culoe De Song, DJ Mujava, Wizkid, 2Face).
   - **2011–2026+ (Next-Gen Kinetic & Sgija Era):** Modern Amapiano log drums, private school piano horn flourishes, high-tempo Shangaan Electro, experimental 3-step electronic beats, and TikTok-native Open-Verse remix culture (Kabza De Small, Kelvin Momo, Tyler ICU, Tyla, Uncle Waffles).
2. **Generational Alignment in Studio & Explore:**
   - Capturing the creator's birth year unlocks zero-friction personal tuning: an artist born in 1994 immediately receives 90s Kwaito & Afro House era tags, pre-highlighted in the Genre deck and pre-tuning their discovery feed on `/explore`.
3. **The MMORPG Creator DNA Tree:**
   - The user's creative identity is not a static form submission. It is a living, 8-node double-helix strand.
   - Nodes 1–4 are sequenced and calibrated during onboarding (Craft Persona, Generation Era, Cultural Tongue, Sonic Genre Core).
   - Nodes 5–8 represent quest-driven mastery (Voice DNA conversion, 5-channel groove composition, viral remix lineage, A&R crate curation). Each completed quest increases DNA power by +15% and unlocks new studio synthesis capabilities.

---

## 3. Forensic Defect & Root Cause Matrix (`SVID_20261104_154958_1.mp4`)

| Timestamp / Act | Defect Caught on Screen | Root Cause (File & Line) | Architectural Solution | Regression Defense |
|---|---|---|---|---|
| **00:05–00:16**<br>(Act 1: Welcome) | Orbiting constellation nodes pass directly behind `"Welcome to Vhunambi"` and body copy, reducing contrast and legibility. Standard Inter text looks flat. | `onboarding_procedural_canvas.dart:104` allowed random particle $Y$ positions from $0.0$ to $1.0\times H$, overlapping typography. | 1. Restrict primary orbiters to $Y \in [0.18H, 0.38H]$ around the emblem.<br>2. Add soft radial vignette mask behind text.<br>3. Introduce `AppTypography.bouncyDisplayLarge` with Outfit/Plus Jakarta Sans. | Test asserts text zone exclusion bounds in painter unit test. |
| **00:17–00:26**<br>(Act 2: Claim Your Craft) | **Ghost-Stacking Bug:** All 5 tarot cards are semi-transparent and stacked tightly. All 5 titles and body paragraphs bleed through into an unreadable mess. | `interactive_identity_card_stack.dart:249` used `withValues(alpha: 0.94)` on all cards without suppressing background card text. | 1. Active front card (`depth == 0`) gets 100% opaque surface (`alpha: 1.0`).<br>2. Background cards (`depth > 0`) set inner content opacity to `0.0`, leaving only top colored rim visible in 3D fan.<br>3. Add explicit horizontal navigation arrows. | Widget test verifies `Opacity == 0.0` for card body at `depth > 0`. |
| **00:32–00:53**<br>(Act 3: African Roots) | Cluttered vertical scroll with 12 genre cards, 4 redundant tempo boxes ("Vibe Energy"), and 10 language chips. No generation era capture. | `onboarding_act3_roots_deck.dart:104` jammed redundant tempo form into single view; missing birth year signal. | Replace with 3-Tier non-scrolling deck:<br>1. Birth Year Drum Dial (`1960..2018`) + Generation Badge.<br>2. Cultural & Dialect Orbs.<br>3. Era-Recommended Genre Cards (`✨ Era Match`). | Widget test verifies birth year updates `SonicGenerationEra` and highlights matching genres. |
| **00:54–01:13**<br>(Act 4: DNA Genesis) | Tapping 3D DNA nodes does nothing (only shows white touch ripple). Bottom trait pill prints raw enum string `MUSICLOVER`. | `creator_dna_helix_finale.dart:112` handled drag offset only; no node raycast/hit-test or inspector card. Enum used `.name.toUpperCase()`. | 1. Implement 8-Node MMORPG Genomic Model (`CreatorDnaNode`).<br>2. Tap-to-inspect hit-testing opens `dna_node_inspector_card` with quest info.<br>3. Map `CreativeRole` to friendly title.<br>4. Embed 3D Mini-Helix and `open_3d_dna_lab_btn` in main app. | Test verifies node tap opens inspector and friendly label is rendered. |

---

## 4. System Topology & Cross-Layer Data Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          ACT 3: ROOTS & GENERATION                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  [ Interactive Birth Year Wheel (1960..2018) ]                              │
│         │                                                                   │
│         ▼                                                                   │
│  SonicGenerationEra.fromBirthYear(year)                                     │
│         ├── 1960–1989: 80s Heritage Era  ──► [Mbaqanga, Maskandi, Gospel]  │
│         ├── 1990–1999: 90s Kwaito Era    ──► [Kwaito, Afro House, Hip-Hop]  │
│         ├── 2000–2010: 2000s Piano Wave  ──► [Amapiano, Private School, Gqom│
│         └── 2011+:     Next-Gen Kinetic  ──► [Amapiano, Shangaan, Afrobeats]│
│                                                                             │
│  [ Cultural Tongues Orbs ] ──► Tshivenḓa, isiZulu, Kiswahili, etc.         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                 ACT 4 & MAIN APP: MMORPG CREATOR DNA HELIX                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  [ 8-Node Genomic Progression Strand ]                                      │
│    ├── Node 1: Craft Persona          [🟢 SEQUENCED] (e.g. Kinetic Creator) │
│    ├── Node 2: Generation Era         [🟢 SEQUENCED] (e.g. 2003 Piano Wave) │
│    ├── Node 3: Cultural Dialect       [🟢 SEQUENCED] (e.g. Tshivenḓa/Zulu)  │
│    ├── Node 4: Genre Resonance        [🟢 SEQUENCED] (e.g. Amapiano/Gqom)   │
│    ├── Node 5: Sovereign Voice DNA    [🔒 LOCKED] (+15% DNA) ──► Studio Take│
│    ├── Node 6: 5-Channel Groove       [🔒 LOCKED] (+15% DNA) ──► Sketchpad  │
│    ├── Node 7: Open-Verse Lineage     [🔒 LOCKED] (+15% DNA) ──► Remix Post │
│    └── Node 8: A&R Tastemaker         [🔒 LOCKED] (+15% DNA) ──► Co-Sign    │
│                                                                             │
│  [ Tap-to-Inspect Hit-Testing ] ──► [ dna_node_inspector_card ]             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        MAIN APPLICATION INTEGRATION                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  [ HomeDashboardView / OwnerProfileView / ArtistProfileView ]               │
│    └── [ CreatorDnaProfileCard ]                                            │
│          ├── Interactive 3D Mini-Helix Preview                              │
│          └── [ 🧬 Open 3D DNA Lab ] (Key: open_3d_dna_lab_btn)             │
│                └── Launches CreatorDnaHelixLabSheet (Full 3D Lab & Quests)  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Dual-Viewport Layout Geometries (ASCII Wireframes)

### A. Act 2: Opaque 3D Card Fan (Desktop 1440dp vs Mobile 360dp)

#### Desktop (1440dp)
```
┌────────────────────────────────────────────────────────────────────────────┐
│                       Claim Your Creative Craft                            │
│           Select the primary superpower you bring to the studio            │
│                                                                            │
│                           ┌────────────────────┐                           │
│                           │  [Top Edge Rim 2]  │                           │
│                      ┌────┴────────────────────┴────┐                      │
│                      │      [Top Edge Rim 1]        │                      │
│                 ┌────┴──────────────────────────────┴────┐                 │
│    [ ◀ Prev ]   │  ● PRODUCER & BEATMAKER               │   [ Next ▶ ]     │
│                 │  Crafting log-drums, chords & grooves │                  │
│                 │  ───────────────────────────────────  │                  │
│                 │  [ 4-Track Step Sequencer & MIDI ]    │                  │
│                 │  [ 100% OPAQUE SURFACE - NO BLEED ]   │                  │
│                 └────────────────────────────────────────┘                 │
│                                                                            │
│                           ( ● ) ( ○ ) ( ○ ) ( ○ ) ( ○ )                    │
└────────────────────────────────────────────────────────────────────────────┘
```

#### Mobile (360dp)
```
┌──────────────────────────────────┐
│     Claim Your Craft             │
│                                  │
│         ┌──────────────┐         │
│         │ [Top Edge 2] │         │
│       ┌─┴──────────────┴─┐       │
│       │  [Top Edge 1]    │       │
│  ┌────┴──────────────────┴────┐  │
│  │ ◀ ● PRODUCER & BEATMAKER ▶ │  │
│  │   Crafting log drums...    │  │
│  │   [ 100% Opaque Surface ]  │  │
│  └────────────────────────────┘  │
│         (●) (○) (○) (○) (○)      │
└──────────────────────────────────┘
```

---

### B. Act 3: 3-Tier Roots & Generation Deck (Mobile 360dp)

```
┌──────────────────────────────────┐
│ Your Roots & Sonic Era           │
│                                  │
│ [1. BIRTH YEAR & GENERATION]     │
│ ┌──────────────────────────────┐ │
│ │ 1999  2001 [ 2003 ] 2005 2007│ │
│ │ ✨ 2000s Piano & Gqom Wave   │ │
│ └──────────────────────────────┘ │
│                                  │
│ [2. CULTURAL TONGUES]            │
│ (● Tshivenḓa) (● Zulu) (Xhosa)   │
│ (Sepedi) (Sesotho) (Kiswahili)   │
│                                  │
│ [3. ERA-MATCHED GENRES]          │
│ ┌──────────────┐┌──────────────┐ │
│ │✨ Amapiano   ││✨ Gqom       │ │
│ └──────────────┘└──────────────┘ │
│ ┌──────────────┐┌──────────────┐ │
│ │Maskandi      ││Afro House    │ │
│ └──────────────┘└──────────────┘ │
└──────────────────────────────────┘
```

---

### C. Act 4 & Main App: MMORPG 3D DNA Helix & Node Inspector Card

```
┌──────────────────────────────────┐
│      Your Creator DNA is Live    │
│                                  │
│          /────────\              │
│         /  [● N1]  \             │
│        |    \  /    |            │
│         \    \/    /             │
│          \ [● N2] /              │
│          /   /\   \              │
│         |   /  \   |             │
│         \  [🔒 N5] /             │
│          \────────/              │
│                                  │
│ ┌──────────────────────────────┐ │
│ │ [🟢 SEQUENCED LVL 1]         │ │
│ │ Node 2: Generation Era       │ │
│ │ Born 2003 • 2000s Piano Wave │ │
│ │ Pre-tunes Explore & Studio   │ │
│ │ +15% DNA Attunement          │ │
│ └──────────────────────────────┘ │
│                                  │
│ [ ⚡ ACTIVATE MY CREATOR DNA ── ]│
└──────────────────────────────────┘
```

---

## 6. Design Token Matrix (`AppColors` & `AppTypography`)

| Element | Dark Mode Token | Light Mode Token | Typography Token |
|---|---|---|---|
| Act 1 Hero Title | `AppColors.darkTextPrimary` (`#FFFFFF`) | `AppColors.lightTextPrimary` (`#121216`) | `AppTypography.bouncyDisplayLarge` (28sp, w900, -0.6ls) |
| Act 1 Subtitle | `AppColors.darkTextSecondary` | `AppColors.lightTextSecondary` | `AppTypography.bodyMedium` (14sp, w500) |
| Card Front Surface | `AppColors.darkSurfaceElevated` (`#16161C`) | `AppColors.lightSurfaceElevated` (`#FFFFFF`) | Alpha: 1.0 (Strictly Opaque) |
| Card Accent Glow | Card's dedicated color at 24% alpha | Card's dedicated color at 16% alpha | 2.0dp border |
| Background Card Rim | `card.accentColor.withValues(alpha: 0.65)` | `card.accentColor.withValues(alpha: 0.65)` | Inner text hidden (`Opacity(0.0)`) |
| Generation Era Badge | `AppColors.badgeCyan` (`#06B6D4`) | `AppColors.badgeCyanBg` | `AppTypography.bouncyBadge` (11sp, w800) |
| Era-Match Glow Chip | `AppColors.brandPrimary` (`#F97316`) | `AppColors.brandPrimary` | Amber 2dp outline + sparkle |
| Unlocked DNA Node | Node's chromatic color (`#F97316`, `#06B6D4`, etc.) | Node's chromatic color | Glowing core + floating label |
| Locked Quest Node | `Color(0xFF64748B)` (Slate wireframe) | `Color(0xFF94A3B8)` | Padlock glyph + dashed target ring |
| Node Inspector Surface | `AppColors.surfaceModalOf(context)` | `AppColors.surfaceModalOf(context)` | Card with 20dp rounded corners |

---

## 7. Safe-Area & Gesture Invariants

1. **Touch Targets:** All interactive drum pills, language orbs, card navigation arrows, and DNA nodes must satisfy a minimum **44×44dp touch target boundary**.
2. **Hit-Testing Proximity Threshold:** A tap on the 3D double-helix selects a node if the distance between touch coordinate $(x_t, y_t)$ and projected node coordinate $(x_n, y_n)$ is $\le 28.0\text{dp}$.
3. **Card Stacking Depth Clamping:** Background cards never exceed 4 levels of depth rendering to prevent GPU overdraw.
4. **Zero-Scroll Constraint on Act 3:** All 3 tiers in Act 3 must fit completely inside a 640dp viewport without vertical scroll bars on standard 360×640dp Android devices.

