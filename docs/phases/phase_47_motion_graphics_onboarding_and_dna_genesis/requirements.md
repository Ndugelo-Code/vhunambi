# Phase 47: Motion-Graphics Onboarding Engine, 3D Stacked Vector Cards & Double-Helix DNA Genesis

> **Document Type:** Requirements Specification (Revision 2.1 — Zero-Summarization Law)  
> **Status:** APPROVED FOR IMPLEMENTATION  
> **Target Package:** `apps/vhunambi_client`  
> **Target Release:** Vhunambi V4.7 (Phase 47)  

---

## 1. Domain Glossary

| Term | Formal Definition | Architectural Implementation |
| :--- | :--- | :--- |
| **Constellation Morphing** | Continuous procedural deformation of 4 primary color nodes across bezier orbital pathways with particle fission and fusion. | Driven by `OnboardingProceduralBackdropCanvas` with an infinite loop `AnimationController` and page offset interpolation. |
| **Satellite Particle** | Microscopic sub-nodes (2–4dp radius) shed by primary chromatic nodes that orbit in retrograde trajectories. | Calculated inside `ConstellationPainter` using harmonic trigonometric orbits (`sin(wt + phi)`, `cos(wt + phi)`). |
| **Pill Capsule Geometry** | Directional elongation of spherical nodes into rounded capsules along movement velocity vectors. | Implemented via `RRect.fromRectAndRadius` rotated along tangential velocity vectors. |
| **3D Card Stack (Tarot Deck)** | A fanned, layered physical card deck in 3D perspective space where unselected cards recede into background depth. | Utilizes `Matrix4.identity()..setEntry(3, 2, 0.001)..translate(...)..rotateY(...)..scale(...)`. |
| **Tactile Genre Card** | Interactive card featuring dedicated programmatically drawn African vector iconography and dynamic dancing equalizer bars. | Replaces obsolete `GenreColorChip` enum coupling; guarantees 100% unique genre rendering. |
| **Dancing Equalizer Bar** | Miniature 3-band vertical equalizer indicator that animates in height when a genre is selected. | Animated via `CurvedAnimation` loop rendering 3 vertical rounded bars. |
| **Vibe Energy Orb** | Continuous horizontal draggable controller replacing stacked radio buttons for rhythmic tempo and mood intensity. | Renders interactive slider track with glowing thumb orb controlling visualizer wave oscillation rate. |
| **Double-Helix DNA Strand** | Rotating 3D double-helix structure with depth-sorted rungs representing user's selected genres, languages, and craft identity. | Implemented via `CreatorDnaHelixPainter` with 3D projection, depth sorting, and particle glow halos. |
| **Particle Vortex Reveal** | High-energy 400ms transition effect emitting expanding particle rings outward before switching to `RootShell`. | Triggered upon tapping `onboarding_launch_studio_btn`. |
| **MiniPlayerHost Guard** | Global suppression rule ensuring the floating mini-player pill never mounts over Splash or Onboarding viewports. | Wired to `onboardingStateProvider.hasCompletedOnboarding` and `isSplashActiveProvider`. |
| **Replay Onboarding** | Ability to re-enter and experience the 4-act onboarding journey anytime without wiping saved data. | Triggered via `ProfileSettingsDrawer` action item `settings_replay_onboarding_btn`. |

---

## 2. Formal User Stories

1. **US-P47-01 (Immersive Non-Form Onboarding):** As a new or returning African music creator, I want an onboarding experience that feels like a living musical performance rather than an administrative settings questionnaire, so that I feel immediately inspired to synthesize music on Vhunambi.
2. **US-P47-02 (Zero Duplicate Chips):** As an artist exploring regional genres and moods, I want every displayed genre card and mood orb to represent a distinct cultural style without repeated names, so that I can accurately configure my acoustic roots.
3. **US-P47-03 (3D Tactile Identity Selection):** As a beatmaker, vocalist, or live instrumentalist, I want to flip through high-craft 3D studio cards with custom vector artwork, so that I can claim my creative role with physical feedback.
4. **US-P47-04 (Distraction-Free Splash & Onboarding):** As a user launching Vhunambi, I never want a mini-player pill or stale track to obstruct the splash logo or onboarding cards.
5. **US-P47-05 (Showstopping DNA Finale):** As an onboarded creator, I want to see my chosen genres, tongues, and vibe reflected in a spinning 3D DNA double-helix that launches into the studio with a particle portal.

---

## 3. Numbered Requirements (RFC-2119 / EARS)

### 3.1 Track A: Defect Eradication & Global Guards

* **REQ-P47-BUG-01 (MiniPlayerHost Splash/Onboarding Suppression):** The system **MUST** suppress `MiniPlayerHost` rendering (returning `const SizedBox.shrink()`) whenever `ref.watch(onboardingStateProvider).hasCompletedOnboarding == false` or `ref.watch(isSplashActiveProvider) == true`.
* **REQ-P47-BUG-02 (12× Unique Genre Catalog):** The onboarding genre catalog **MUST** render exactly 12 distinct African genres (`Amapiano`, `Private School Piano`, `Gqom`, `Maskandi`, `Afro House`, `Kwaito`, `Afrobeats`, `SA Hip-Hop`, `African Gospel`, `Mbaqanga`, `Shangaan Electro`, `Bongo Flava`), each with its own accent color and distinct label. The system **SHALL NOT** map unrecognized genres to `"Amapiano"`.
* **REQ-P47-BUG-03 (Retire Radio Buttons & 5× Duplicate Moods):** The system **MUST** eradicate the stacked radio-button questionnaire (`Tempo Feel` / `Vocal Energy`) and the duplicate `"Energetic"` mood chips. In their place, the system **SHALL** provide a continuous `VibeEnergySlider` and distinct mood pills (`Soulful`, `Acoustic`, `Energetic`, `Club Groove`, `Spiritual`).
* **REQ-P47-BUG-04 (Unclipped Full-Width CTA):** The final activation CTA button (`onboarding_launch_studio_btn`) **MUST** render with full viewport width minus safe horizontal padding (`double.infinity`), ensuring text such as `"Activate My Creator DNA"` or `"Enter Vhunambi Studio"` never truncates on 360dp mobile viewports.
* **REQ-P47-BUG-05 (Replay Onboarding Action):** The system **MUST** provide a `"Replay Interactive Onboarding"` tile in `ProfileSettingsDrawer` (`Key('settings_replay_onboarding_btn')`) allowing users to launch the 4-act experience at any time.

### 3.2 Track B: Living Procedural Canvas (`OnboardingProceduralBackdropCanvas`)

* **REQ-P47-CANVAS-01 (60 FPS Performance):** The procedural backdrop canvas **MUST** render at a continuous 60 frames per second using Flutter's `CustomPainter` without allocating new `Paint` objects inside the `paint` method loop.
* **REQ-P47-CANVAS-02 (4-Node Constellation):** The canvas **MUST** render 4 chromatic nodes orbiting in harmonic ellipses:
  - Node 1: Amber (`AppColors.brandPrimary`, `#F97316`)
  - Node 2: Cyan (`AppColors.badgeCyan`, `#06B6D4`)
  - Node 3: Emerald (`AppColors.badgeGreen`, `#10B981`)
  - Node 4: Gold (`AppColors.badgeAmber`, `#F59E0B`)
* **REQ-P47-CANVAS-03 (Pill Capsule Stretching):** When the active onboarding page changes, the nodes **MUST** interpolate along the swipe velocity vector, stretching from circular orbs into rounded pill capsules with a dynamic aspect ratio between 1.0 and 3.2.
* **REQ-P47-CANVAS-04 (Floating Parallax Glyphs):** The canvas **MUST** render at least 6 translucent Phosphor vector glyphs (`musicNotes`, `waveform`, `vinylRecord`, `microphoneStage`, `sparkle`, `dna`) drifting across 3 depth planes with parallax shift synchronized with page scrolling.
* **REQ-P47-CANVAS-05 (Touch Acoustic Waves):** When a user taps or drags on any onboarding card, the canvas **MUST** emit concentric circular acoustic ripple waves that dissipate outward over 800ms.

### 3.3 Track C: 3D Stacked Interactive Vector Cards (Acts 1–3)

* **REQ-P47-ACT1-01 (Act 1 Living Sonic Showcase):** Act 1 (`Key('onboarding_act_1_showcase')`) **MUST** present an interactive constellation showcasing Vhunambi's 4 core pillars (*AI Studio & Stems*, *Sovereign Voice DNA*, *5-Channel Groove*, *Kinetic Social & 85% ZAR Market*) orbiting the central emblem. Tapping any pillar **SHALL** expand its benefit card.
* **REQ-P47-ACT2-01 (Act 2 3D Stacked Identity Deck):** Act 2 (`Key('onboarding_act_2_identity_deck')`) **MUST** render a fanned 3D stack of 5 studio craft cards (`Producer & Beatmaker`, `Natural Vocalist`, `DAW Master & Artist`, `Live Instrumentalist`, `Kinetic Creator & Curator`).
* **REQ-P47-ACT2-02 (Zero Raw Emojis):** Each identity card **MUST** feature dedicated programmatically drawn vector graphics (`CustomPainter`: vinyl turntable, studio condenser mic, electric/acoustic guitar, step sequencer grid) and Phosphor icons. Raw emojis are strictly prohibited.
* **REQ-P47-ACT2-03 (3D Card Physics):** Swiping or tapping a card in the stack **MUST** animate its `Matrix4` transform with perspective (`setEntry(3, 2, 0.001)`), rotating up to 14 degrees and scaling to 1.0 while receding unselected cards to scale 0.88 and opacity 0.5.
* **REQ-P47-ACT3-01 (Act 3 Tactile Genre Grid):** Act 3 (`Key('onboarding_act_3_roots_deck')`) **MUST** render a scrollable/paginated grid of tactile genre cards. Tapping a card **SHALL** toggle its selection in `onboardingStateProvider.selectedGenres` and activate animated equalizer bars.
* **REQ-P47-ACT3-02 (Act 3 Vibe Energy Slider):** Act 3 **MUST** render a tactile continuous energy slider (`Key('onboarding_vibe_slider')`) updating `tempoPreference` (`'slow'`, `'medium'`, `'fast'`, `'hyperspeed'`) and modulating the background visualizer frequency.
* **REQ-P47-ACT3-03 (Act 3 Indigenous Language Orbs):** Act 3 **MUST** display selectable pill orbs for indigenous languages (`Tshivenḓa`, `isiZulu`, `isiXhosa`, `Sepedi`, `Sesotho`, `Setswana`, `Xitsonga`, `Kiswahili`, `Yorùbá`, `English`).

### 3.4 Track D: Act 4 Double-Helix DNA Genesis Finale

* **REQ-P47-ACT4-01 (3D Double-Helix DNA Canvas):** Act 4 (`Key('onboarding_act_4_dna_finale')`) **MUST** render an interactive 3D rotating double-helix DNA strand with at least 14 base-pair rungs.
* **REQ-P47-ACT4-02 (Trait Labeling & Chromatic Mapping):** The DNA rungs **MUST** be procedurally textured with colors and labels representing the user's selected Genres, Languages, and Creative Role from Acts 2 and 3.
* **REQ-P47-ACT4-03 (Interactive Spin & Drag):** Horizontal touch dragging across the DNA helix **MUST** alter the rotational angular velocity with inertia damping.
* **REQ-P47-ACT4-04 (Particle Vortex Reveal):** Tapping `Key('onboarding_launch_studio_btn')` **MUST** trigger a 400ms particle explosion animation before navigating to `RootShell`.

---

## 4. Requirements Traceability Matrix

| Requirement ID | Component / File | Verification Method |
| :--- | :--- | :--- |
| `REQ-P47-BUG-01` | `mini_player_host.dart` & `splash_view.dart` | Automated Widget Test: `MiniPlayerHost` renders `SizedBox.shrink()` during onboarding |
| `REQ-P47-BUG-02` | `onboarding_view.dart` & `onboarding_models.dart` | Automated Unit Test: 12 distinct genres with 0 duplicate "Amapiano" entries |
| `REQ-P47-BUG-03` | `onboarding_view.dart` & `vibe_energy_slider.dart` | Automated Widget Test: Zero radio buttons rendered, distinct mood orbs present |
| `REQ-P47-BUG-04` | `creator_dna_helix_finale.dart` | Narrow Viewport Test (360dp width): CTA button text never truncated |
| `REQ-P47-BUG-05` | `profile_settings_drawer.dart` | Widget Test: Tapping `settings_replay_onboarding_btn` pushes `OnboardingView` |
| `REQ-P47-CANVAS-01..05` | `onboarding_procedural_canvas.dart` | CustomPainter unit tests & Golden smoke tests |
| `REQ-P47-ACT1-01` | `onboarding_act1_showcase.dart` | Widget Test: Tapping pillars expands showcase card |
| `REQ-P47-ACT2-01..03` | `interactive_identity_card_stack.dart` | Widget Test: Swiping cards updates `creativeRole` with 3D transform |
| `REQ-P47-ACT3-01..03` | `onboarding_act3_roots_deck.dart` | Widget Test: Selecting genres and dragging vibe slider |
| `REQ-P47-ACT4-01..04` | `creator_dna_helix_finale.dart` | Widget Test: Renders 3D helix, taps launch button |

