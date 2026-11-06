# PHASE 53 REQUIREMENTS: THE 3D ORGANIC MYCELIUM BIOME
## Formal EARS / RFC-2119 Requirements Specification & Verification Traceability Matrix

---

### 1. Document Scope, Coordinate Standard & Specification Conventions

This specification establishes the formal functional, mathematical, aesthetic, and performance requirements for **Phase 53: The 3D Organic Mycelium Biome** ("A Song as a Living Ecosystem").

All spatial requirements strictly obey the **Right-Handed 3D Y-Up World Space Convention**:
* **$X$-Axis (Horizontal)**: Left ($-X$) to Right ($+X$), range $X \in [-320, +320]\text{dp}$.
* **$Y$-Axis (Vertical Elevation — UP is $+Y$)**: Subterranean floor ($Y = 0$) upward to canopy sky ($+Y$), range $Y \in [0, +240]\text{dp}$. Every mushroom cluster $k$ roots into the contoured terrain mound at $Y_{\text{root}, k} = h(X_k, Z_k) \ge 0$ and rises to cap apex $Y_{\text{apex}, k} = Y_{\text{root}, k} + H_{\text{stipe}, k}$.
* **$Z$-Axis (Depth)**: Background horizon ($-Z$, deeper into screen) to Foreground ($+Z$, closer to viewer), range $Z \in [-260, +260]\text{dp}$.

All requirements adhere to the **Easy Approach to Requirements Syntax (EARS)** and **RFC-2119 terminology** (`SHALL`, `MUST`, `SHOULD`, `MAY`):
* **Ubiquitous**: `THE SYSTEM SHALL <system response>`
* **Event-Driven**: `WHEN <trigger>, THE SYSTEM SHALL <system response>`
* **State-Driven**: `WHILE <state>, THE SYSTEM SHALL <system response>`
* **Unwanted Behavior**: `IF <condition>, THEN THE SYSTEM SHALL <system response>`
* **Optional**: `WHERE <feature is enabled>, THE SYSTEM SHALL <system response>`

---

### 2. Functional Requirements: The 6 Mushroom Fruiting Bodies (`MushroomFruitingBody`)

#### REQ-P53-CORE-01: Dominant Central Melody Core Fruiting Body (`melodyCore`)
* **Statement**: The system SHALL position the primary `melodyCore` Mushroom Fruiting Body at horizontal planar origin $(X = 0, Z = 0)$, rooted on the central terrain mound at $Y_{\text{root}} = 32\text{dp}$ with stipe height $H_{\text{stipe}} = 108\text{dp}$ (cap apex at $(0, 140, 0)$) and a golden-amber palette (`#FF9E00`), representing the foundational melodic identity, motifs, pitch contours, and vocal hooks of the composition.
* **3D Mesh Geometry**: The `melodyCore` pileus SHALL be rendered as a 3D multi-ring fluted parametric dome ($R_{\text{cap}} = 56\text{dp}$, $H_{\text{cap}} = 34\text{dp}$, 5 concentric rings $\times$ 24 radial segments via `ui.Vertices`) with a 12-fold scalloped bioluminescent margin, 32 3D under-cap radial lamellae gills, and an 8-ring flared hyperboloid stalk.
* **Child Nodes**: When focused, the `melodyCore` canopy SHALL unfurl 5 `MyceliumChildNode` leaves: `Lead Hook Motif`, `Motif Repetition`, `Pitch Contour`, `Counter-Melody`, and `Bantu Call-and-Response`.

#### REQ-P53-CORE-02: Foreground-Left Rhythm Network Fruiting Body (`rhythmNetwork`)
* **Statement**: The system SHALL position the `rhythmNetwork` Mushroom Fruiting Body at foreground-left planar coordinate $(X = -195, Z = +95)$, rooted at $Y_{\text{root}} = 22\text{dp}$ with stipe height $H_{\text{stipe}} = 74\text{dp}$ (cap apex at $(-195, 96, +95)$) and an electric blue-cyan palette (`#00B4D8`), representing track tempo (BPM), log-drum sub-bass, syncopated shakers, and percussion grooves.
* **3D Mesh Geometry**: The `rhythmNetwork` pileus ($R_{\text{cap}} = 42\text{dp}$, $H_{\text{cap}} = 25\text{dp}$) SHALL feature stepped concentric 3D rings and 32 radial gills that dynamically emit outward shockwave ripples synchronized to beat onsets.
* **Child Nodes**: When focused, the `rhythmNetwork` canopy SHALL unfurl 5 `MyceliumChildNode` leaves: `Log-Drum Sub-Bass`, `Syncopated Shaker 16ths`, `Rim & Woodblock`, `Tempo Feel (BPM)`, and `Conga Polyrhythms`.

#### REQ-P53-CORE-03: Upper-Left Vocal Network Fruiting Body (`vocalNetwork`)
* **Statement**: The system SHALL position the `vocalNetwork` Mushroom Fruiting Body at upper-left coordinate $(X = -155, Z = -90)$, rooted at $Y_{\text{root}} = 26\text{dp}$ with stipe height $H_{\text{stipe}} = 94\text{dp}$ (cap apex at $(-155, 120, -90)$) and a bioluminescent violet palette (`#9D4EDD`), representing lead Bantu vocal timbre, ancestral oral cadences, choir harmonies, and LoRA voice cloning.
* **3D Mesh Geometry**: The `vocalNetwork` pileus ($R_{\text{cap}} = 47\text{dp}$, $H_{\text{cap}} = 28\text{dp}$) SHALL feature a translucent 3D bell-shaped dome with 32 radial gills emitting ascending spore particles along $+Y$.
* **Child Nodes**: When focused, the `vocalNetwork` canopy SHALL unfurl 5 `MyceliumChildNode` leaves: `Venda Folk Elder (Timbre)`, `Tshivenda Dialect Tongue`, `Choir Backing Call-Response`, `Voice LoRA (85%)`, and `Traditional Ad-Libs`.

#### REQ-P53-CORE-04: Upper-Right Harmony Network Fruiting Body (`harmonyNetwork`)
* **Statement**: The system SHALL position the `harmonyNetwork` Mushroom Fruiting Body at upper-right coordinate $(X = +165, Z = -85)$, rooted at $Y_{\text{root}} = 25\text{dp}$ with stipe height $H_{\text{stipe}} = 90\text{dp}$ (cap apex at $(+165, 115, -85)$) and a vibrant emerald palette (`#10B981`), representing chords, modal African scales, Rhodes electric piano voicings, and brass harmonics.
* **3D Mesh Geometry**: The `harmonyNetwork` pileus ($R_{\text{cap}} = 45\text{dp}$, $H_{\text{cap}} = 27\text{dp}$) SHALL feature a multi-tiered crystalline 3D dome with 32 radial gills.
* **Child Nodes**: When focused, the `harmonyNetwork` canopy SHALL unfurl 5 `MyceliumChildNode` leaves: `Private School Rhodes 9ths`, `African Pentatonic Scale`, `Root Bass Progression`, `Brass Chord Stabs`, and `Flute Counter-Harmony`.

#### REQ-P53-CORE-05: Right-Midground Emotion Network Fruiting Body (`emotionNetwork`)
* **Statement**: The system SHALL position the `emotionNetwork` Mushroom Fruiting Body at right-midground coordinate $(X = +190, Z = +75)$, rooted at $Y_{\text{root}} = 21\text{dp}$ with stipe height $H_{\text{stipe}} = 75\text{dp}$ (cap apex at $(+190, 96, +75)$) and a magenta-rose palette (`#F72585`), representing emotional energy, mood valence, dynamic tension, and atmospheric warmth.
* **3D Mesh Geometry**: The `emotionNetwork` pileus ($R_{\text{cap}} = 41\text{dp}$, $H_{\text{cap}} = 25\text{dp}$) SHALL feature a pulsating 3D dome and 32 radial gills that modulate coronal glow radius in proportion to track dynamic intensity.
* **Child Nodes**: When focused, the `emotionNetwork` canopy SHALL unfurl 4 `MyceliumChildNode` leaves: `Soulful & Uplifting Energy`, `Dynamic Tension Build`, `Nostalgic Minor Transition`, and `Acoustic Harmonic Warmth`.

#### REQ-P53-CORE-06: Foreground Lower-Center Production Network Fruiting Body (`productionNetwork`)
* **Statement**: The system SHALL position the `productionNetwork` Mushroom Fruiting Body at foreground lower-center coordinate $(X = -35, Z = +155)$, rooted at $Y_{\text{root}} = 18\text{dp}$ with stipe height $H_{\text{stipe}} = 64\text{dp}$ (cap apex at $(-35, 82, +155)$) and a teal-aqua palette (`#06D6A0`), representing spatial room reverb, Demucs stem isolation, Phase 25 mastering limits, and Stem-Lock authority.
* **3D Mesh Geometry**: The `productionNetwork` pileus ($R_{\text{cap}} = 39\text{dp}$, $H_{\text{cap}} = 22\text{dp}$) SHALL feature a dual-ring 3D dome with 32 radial gills.
* **Child Nodes**: When focused, the `productionNetwork` canopy SHALL unfurl 5 `MyceliumChildNode` leaves: `3D Plate Reverb Room`, `Stem-Lock Mode (Pure 44.1k)`, `Sidechain Ducking Envelope`, `Stereo Binaural Field`, and `Master Ceiling Limiter`.

---

### 3. Functional Requirements: Subterranean Mycelium Web & Sprout Mushrooms

#### REQ-P53-MYCEL-01: 15 Interconnected Cross-Cluster Arterial Hyphal Conduits (`MyceliumHyphaEdge`)
* **Statement**: The system SHALL generate 15 cross-cluster subterranean hyphal conduits (8 primary high-conductivity arterial pathways + 7 secondary bridges) that physically weave across the 3D terrain contour $Y = h(X, Z) + 1.5\text{dp}$ using 9-waypoint 3D Catmull-Rom splines.
* **Primary Arterial Pathways**:
  1. `melodyCore` $\leftrightarrow$ `vocalNetwork` (Vocal topline melody)
  2. `melodyCore` $\leftrightarrow$ `harmonyNetwork` (Melodic-harmonic alignment)
  3. `melodyCore` $\leftrightarrow$ `rhythmNetwork` (Rhythmic phrasing of hooks)
  4. `melodyCore` $\leftrightarrow$ `emotionNetwork` (Melodic emotional valence)
  5. `rhythmNetwork` $\leftrightarrow$ `productionNetwork` (Drum compression and stem lock)
  6. `rhythmNetwork` $\leftrightarrow$ `harmonyNetwork` (Log-drum pitch tuning)
  7. `harmonyNetwork` $\leftrightarrow$ `productionNetwork` (Reverb acoustics on chords)
  8. `vocalNetwork` $\leftrightarrow$ `emotionNetwork` (Vocal expressive urgency)

#### REQ-P53-MYCEL-02: Space-Colonization Rootlet Web (`MyceliumRootTendril`)
* **Statement**: In addition to the 15 inter-cluster arterial conduits, the system SHALL generate 72 branching secondary/tertiary rootlet tendrils (12 radiating and bifurcating from each of the 6 mushroom root bases) driven by a deterministic 31-bit song fingerprint seed.
* **Determinism**: Identical song parameters SHALL generate identical 3D hyphal and rootlet geometry across all sessions.

#### REQ-P53-MYCEL-03: Traveling Synaptic Nutrient Photons
* **Statement**: The system SHALL render traveling bioluminescent photon packets along active 3D hyphal spline waypoints using additive blending (`BlendMode.plus`).
* **Velocity Modulation**: Photon transit speed along each conduit SHALL scale linearly with track tempo (BPM) and current playhead section energy ($v = v_{\text{base}} \cdot (\text{BPM} / 120.0) \cdot E_{\text{section}}$).

#### REQ-P53-MYCEL-04: Network Junctions & 16 3D Sprout / Pinhead Mushrooms (`MyceliumSproutNode`)
* **Statement**: At 16 major hyphal junctions across the terrain floor $Y = h(X_s, Z_s)$, the system SHALL spawn miniature 3D bioluminescent sprout/pinhead mushrooms ($H = 9\text{dp}-18\text{dp}$, $R_{\text{cap}} = 5\text{dp}-11\text{dp}$) rendered with a 3D miniature cap dome, stalk, and basal glow halo, adding biological depth matching `3D Biome: Living Music Ecosystem.png` without creating UI text pill clutter.

#### REQ-P53-MYCEL-05: Crystalline Stem-Lock Sheathing
* **Statement**: WHEN a cluster or channel is set to `StemLockMode.lockedPure44k`, its corresponding hyphal conduits and root stipe SHALL be enveloped in a double-walled crystalline golden-cyan sheath (`#00F5D4` / `#FFD166`), visually confirming that untouched 44.1 kHz audio bypasses AI diffusion re-synthesis.

#### REQ-P53-MYCEL-06: Contextual Action-Potential Wave Surges
* **Statement**: WHEN a user selects or focuses any Mushroom Fruiting Body, the system SHALL trigger an action-potential luminescent wave that surges down that mushroom's stipe and races outward through all connected hyphae, temporarily elevating connected conduits to 100% additive brilliance.

---

### 4. Functional Requirements: 3D Camera, Gestures, Hit-Testing & Spatial Hierarchy

#### REQ-P53-CAM-01: Right-Handed Y-Up Perspective Terrain Camera
* **Statement**: The system SHALL render the 3D Biome using a perspective projection camera anchored in spherical coordinates $(r, \theta, \phi)$ looking toward target focal center $(T_x, T_y, T_z)$ in Y-Up world space.
* **Pitch Constraint**: The camera pitch angle $\phi$ SHALL be strictly clamped to $[15^\circ, 75^\circ]$ above the horizontal $XZ$ ground plane, mathematically eliminating gimbal lock and preventing clipping underneath the terrain grid.

#### REQ-P53-CAM-02: Pointer-Count Isolated 1-Finger Orbit & 2-Finger Pinch Zoom
* **Statement**: The viewport SHALL enforce strict pointer-count separation in `onScaleUpdate`:
  * **Single Pointer ($N = 1$)**: Horizontal drag SHALL orbit azimuth $\theta$ continuously through $360^\circ$ ($\Delta \theta = -\Delta x \cdot 0.007\text{ rad/px}$); vertical drag SHALL adjust elevation pitch $\phi \in [15^\circ, 75^\circ]$ ($\Delta \phi = \Delta y \cdot 0.007\text{ rad/px}$).
  * **Dual Pointers ($N \ge 2$)**: Pinch gesture SHALL scale camera distance $r \in [180\text{dp}, 650\text{dp}]$ without polluting single-finger orbit angles.

#### REQ-P53-CAM-03: Zero-Overlap Circular Icon Badges in Overview Mode
* **Statement**: In Overview Mode, the system SHALL render circular icon badges ONLY directly above the 6 Parent Mushroom Caps (zero child leaf pills displayed on the global landscape).

#### REQ-P53-CAM-04: Deterministic 3D Hit-Testing & Canopy Dive Glide Animation
* **Statement**: The system SHALL resolve touch taps via both synchronous 2D screen-space projection hit-testing (`BiomeProjectionEngine.hitTest(...)`) and semantic overlay targets (`Key('biome_cluster_badge_${domain.name}')`).
* **Canopy Dive**: WHEN a user taps any of the 6 Parent Mushroom Heads or its floating badge, the system SHALL smoothly glide the camera over $450\text{ms}$ into that mushroom's canopy ($r = 210\text{dp}$, focal target shifted to the mushroom's 3D cap apex) and unfurl its attached `MyceliumChildNode` leaves radially around the cap perimeter.

#### REQ-P53-CAM-05: Floating Return to Surface Overview Button
* **Statement**: WHILE the camera is focused on a mushroom canopy, the system SHALL display a floating `[ Surface Overview ]` compass pill (`Key('biome_return_overview_btn')`).
* **Return Trigger**: WHEN the user taps `Key('biome_return_overview_btn')`, the system SHALL glide the camera back to the global overview perspective $(r = 420\text{dp}, \theta = 0^\circ, \phi = 32^\circ, \vec{T} = (0, 55, 0))$ and stow the child leaf nodes.

#### REQ-P53-CAM-06: Decoupled Gesture Layering
* **Statement**: The background orbit gesture detector SHALL reside on a dedicated `Positioned.fill` layer placed behind interactive HUD decks and semantic badge targets so tapping any HUD button executes immediately without triggering canvas drag deltas.

---

### 5. Functional Requirements: 5-Stage Organic Growth Engine

#### REQ-P53-GROWTH-01: Nucleus Seed Stage ($\tau \in [0.0, 0.12]$)
* **Statement**: WHEN a new song is initialized or reset, the system SHALL spawn a high-intensity golden nucleus point at $(0, 32, 0)$ that pulses with particle shimmer while surrounding terrain remains in deep shadow.

#### REQ-P53-GROWTH-02: Primary Cluster Seed Eruption ($\tau \in [0.12, 0.30]$)
* **Statement**: Across $\tau \in [0.12, 0.30]$, 6 radial energy beams SHALL project outward from the central nucleus to the 6 cluster root mound loci $(X_k, h(X_k, Z_k), Z_k)$, igniting the primary cluster seed nodes.

#### REQ-P53-GROWTH-03: Hyphal Web Colonization ($\tau \in [0.30, 0.62]$)
* **Statement**: Across $\tau \in [0.30, 0.62]$, the 15 arterial hyphae, 72 rootlet tendrils, and 16 pinhead sprout mushrooms SHALL branch outward across the contoured terrain $Y = h(X, Z)$.

#### REQ-P53-GROWTH-04: Fruiting Body Stipe & Cap Expansion ($\tau \in [0.62, 0.90]$)
* **Statement**: Across $\tau \in [0.62, 0.90]$, the 6 Mushroom Stipes SHALL erupt vertically along $+Y$ from their root mounds, expanding their 3D fluted umbrella caps and 32 radial gills.

#### REQ-P53-GROWTH-05: Ecosystem Maturity & Persistent Identity ($\tau \in [0.90, 1.00]$)
* **Statement**: At $\tau \ge 0.90$, the ecosystem SHALL enter the mature living state with gentle 60 FPS breathing oscillations ($2.5\text{dp}$ vertical sine bob on caps, travelling nutrient pulses).
* **State Persistence**: WHEN audio playback is paused, the 3D Biome SHALL retain its exact 3D geometric configuration without collapsing or scrambling.

---

### 6. Functional Requirements: Flutter HUD & Interactive Decks

#### REQ-P53-HUD-01: Top Bar & Mini Transport Capsule (`BiomeTopBar`)
* **Statement**: The system SHALL render a top bar (`Key('biome_top_bar')`) featuring the sovereign Vhunambi DNA Helix emblem (`PhosphorIconsBold.dna`), title `3D Biome — Explore the Living DNA of Music`, a right-docked `Now Playing` capsule displaying track title, animated mini-waveform, `Play/Pause` (`Key('biome_play_pause_btn')`), `Mute` (`Key('biome_mute_btn')`), and Close `X` (`Key('biome_close_btn')`).

#### REQ-P53-HUD-02: Biome Cluster Inspector Panel (`BiomeClusterInspectorPanel`)
* **Statement**: WHEN any Mushroom Head is focused, the system SHALL display `BiomeClusterInspectorPanel` (`Key('biome_cluster_inspector_panel')`) containing:
  1. Domain Phosphor Icon, Cluster Title, and Close `X` button (`Key('biome_inspector_close_btn')`).
  2. One-line domain role description.
  3. Live animated 28-bar audio frequency waveform canvas (`Key('biome_inspector_waveform')`).
  4. 3 numeric metrics: `Intensity %`, `Complexity %`, `Influence %`.
  5. Related Intersecting Nodes chips (`Key('biome_related_chip_${partner.name}')`) that glide the camera across the connecting hypha to that partner cluster when tapped.
  6. Interactive child leaf mutator chips & `[ Explore Details -> ]` studio mutator trigger (`Key('biome_explore_details_btn')`).
  7. High-voltage `[ Synthesize Song ]` CTA button (`Key('biome_synthesize_btn')`).

#### REQ-P53-HUD-03: Song Journey Timeline Scrubber (`SongJourneyTimelineScrubber`)
* **Statement**: The system SHALL render an interactive horizontal scrubber (`Key('biome_song_journey_scrubber')`) at the bottom center of the screen featuring the 5 chronological song sections: `Intro`, `Verse`, `Chorus`, `Bridge`, and `Outro` (`Key('biome_section_${section.name}')`).
* **Audio-Visual Modulation**: Tapping any section on the scrubber SHALL update `activeSection` and modulate the bioluminescent intensity across all 6 clusters:
  * `Intro`: Boosts `rhythmNetwork` and `productionNetwork`; softens `vocalNetwork`.
  * `Verse`: Boosts `vocalNetwork` and `rhythmNetwork`.
  * `Chorus`: Boosts all 6 clusters (`melodyCore`, `vocalNetwork`, `emotionNetwork`, `rhythmNetwork`, `harmonyNetwork`, `productionNetwork`) to peak brilliance ($95\% - 100\%$) and accelerates synaptic photon flow by $1.4\times$.
  * `Bridge`: Boosts `harmonyNetwork` and `emotionNetwork`.
  * `Outro`: Softens clusters to gentle ambient decay ($35\% - 55\%$).

#### REQ-P53-HUD-04: Interactive Controls Bar (`BiomeInteractiveControlsBar`)
* **Statement**: The system SHALL render the bottom-left Interactive Controls deck (`Key('biome_controls_bar')`) with 5 vector action buttons matching `3D Biome: Living Music Ecosystem.png`:
  1. `Rotate` (`Key('biome_ctrl_rotate')`): Toggles continuous gentle auto-orbit rotation ($0.22\text{ rad/s}$).
  2. `Zoom` (`Key('biome_ctrl_zoom')`): Cycles camera distance between Overview ($420\text{dp}$) and Macro Canopy ($210\text{dp}$).
  3. `Focus` (`Key('biome_ctrl_focus')`): Centers and focuses the camera on `melodyCore` (or resets to Overview).
  4. `Compare` (`Key('biome_ctrl_compare')`): Toggles Stem-Lock vs. AI-Diffused visual comparison highlighting.
  5. `Analyse` (`Key('biome_ctrl_analyse')`): Toggles the acoustic telemetry diagnostic overlay.

#### REQ-P53-HUD-05: Network Layers Filter Toggles (`BiomeNetworkLayersFilter`)
* **Statement**: The system SHALL render the Network Layers filter deck (`Key('biome_network_layers_filter')`) with 4 toggleable layer pills:
  1. `Core Elements` (`Key('biome_layer_coreElements')`, Orange `#FF9E00` indicator): Controls visibility/emphasis of `melodyCore` and `rhythmNetwork`.
  2. `Supporting Elements` (`Key('biome_layer_supportingElements')`, Cyan `#00B4D8` indicator): Controls `harmonyNetwork` and `productionNetwork`.
  3. `Atmosphere` (`Key('biome_layer_atmosphere')`, Violet `#9D4EDD` indicator): Controls sprout mushrooms, atmospheric spores, and spatial reverb tendrils.
  4. `Emotional Layer` (`Key('biome_layer_emotionalLayer')`, Emerald `#10B981` indicator): Controls `emotionNetwork` and `vocalNetwork`.
* **Filter Behavior**: Toggling a layer off SHALL smoothly attenuate non-selected clusters/hyphae to $12\%$ opacity so active layers stand out with crystal clarity.

#### REQ-P53-HUD-06: Bidirectional Studio Cockpit Mutators
* **Statement**: WHEN a creator adjusts a parameter in `BiomeClusterInspectorPanel` (e.g., changes genre, adjusts tempo BPM, selects a Bantu voice profile, changes scale/mood, or toggles `StemLockMode`), the mutation SHALL immediately update `studioFormProvider` / `melodySketchpadProvider` AND synchronously update the 3D `MusicalDnaGraph`.

---

### 7. Non-Functional & Performance Requirements

#### REQ-P53-NFR-01: 60 FPS Mobile Hardware Frame Budget
* **Statement**: The 3D Mycelium Biome rendering pipeline SHALL maintain a continuous 60 frames per second ($\le 16.6\text{ms}$ per frame total build + raster time) on the target Huawei ARM64 test hardware (`EPHUT20917014649`).

#### REQ-P53-NFR-02: Built-In Flutter GPU Mesh & Vector Math Law (Zero Unverified Third-Party 3D Plugins)
* **Statement**: Phase 53 SHALL NOT add external WebView or third-party native OpenGL packages to `pubspec.yaml`. All 3D matrix transformations and hardware-accelerated triangle meshes SHALL utilize Flutter's built-in SDK libraries: `dart:ui` (`ui.Vertices`, `VertexMode.triangles`, `BlendMode.plus`, `MaskFilter.blur`), `dart:math`, `dart:typed_data` (`Float32List`, `Int32List`, `Uint16List`), and `package:vector_math/vector_math_64.dart` (`Matrix4`, `Vector3`, `Vector4`).

#### REQ-P53-NFR-03: Zero Raw Emojis Standard (`STD-UIUX-001`)
* **Statement**: All UI elements, HUD cards, inspector headers, and billboard badges SHALL exclusively utilize `package:phosphor_icons/phosphor_icons.dart` (`PhosphorIconsBold.*`, `PhosphorIconsRegular.*`, `PhosphorIconsFill.*`) or custom vector canvas painters. Strictly 0 raw unicode emojis SHALL be present in Dart source or test files.

#### REQ-P53-NFR-04: Headless Domain Testability
* **Statement**: The `MusicalDnaGraph` domain models and space-colonization algorithms in `mycelium_biome_models.dart` SHALL be 100% executable and testable in headless Dart VM unit tests.

---

### 8. Functional Requirements: MasterMediaObject & Synthesis Pipeline Integration

#### REQ-P53-INT-01: Song Spec Compilation with 3D Mycelium Topology Manifest
* **Statement**: WHEN the user triggers synthesis from the Biome (`Key('biome_synthesize_btn')`), the system SHALL invoke `studioFormProvider.notifier.triggerGeneration()` and start the live `GenerationPipelineNotifier` FSM while preserving all cluster parameters and `branchStemLockModes`.

#### REQ-P53-INT-02: Pre-Generation Stem-Lock Authority Sync
* **Statement**: Toggling Stem-Lock inside `BiomeClusterInspectorPanel` SHALL directly invoke `studioFormProvider.notifier.toggleBranchStemLock(branchId)`, synchronizing `StemLockMode.lockedPure44k` vs `StemLockMode.aiDiffused` between the 3D Mycelium Biome and the Studio Cockpit.

---

### 9. Ergonomics, Haptics & Accessibility Requirements

#### REQ-P53-ACC-01: Tactile Micro-Haptic Confirmation
* **Statement**: WHEN the user taps any Mushroom Head, layer filter, or Song Journey section, the system SHALL trigger `HapticFeedback.selectionClick()`. Tapping `[ Synthesize Song ]` SHALL trigger `HapticFeedback.heavyImpact()`.

#### REQ-P53-ACC-02: Responsive Mobile Portrait vs. Desktop Landscape Adaptation
* **Statement**: On viewports with width $< 600\text{dp}$, the HUD SHALL arrange `BiomeNetworkLayersFilter` and `BiomeInteractiveControlsBar` into a compact non-occluding dock strip and slide `BiomeClusterInspectorPanel` as a bottom-right modal sheet so the 3D mushroom landscape remains unobstructed. On viewports $\ge 600\text{dp}$, all 5 HUD decks SHALL render in the full multi-panel workstation layout.

#### REQ-P53-ACC-03: Screen-Reader Semantics & Deterministic Widget Test Keys
* **Statement**: Each of the 6 Mushroom Fruiting Bodies and visible child leaf nodes SHALL expose a positioned `Semantics` + `GestureDetector` target with deterministic keys (`Key('biome_cluster_badge_${domain.name}')` and `Key('biome_child_leaf_${leaf.id}')`).

---

### 10. Requirements Traceability Matrix

| Requirement ID | Architectural Subsystem in `design.md` | Verification Test Gate |
| :--- | :--- | :--- |
| **REQ-P53-CORE-01..06** | §2.2–§2.4 & §3.1: 6 3D Mushroom Fruiting Bodies (`ui.Vertices`) | `Test: M1-3DMushroomMesh & M3-6Clusters` |
| **REQ-P53-MYCEL-01..06** | §2.5 & §4: 15 Arterial Hyphae, 72 Rootlets & 16 3D Sprouts | `Test: M2-MyceliumWebAndSprouts` |
| **REQ-P53-CAM-01..06** | §2.6–§2.7 & §5: Y-Up Camera, Pointer Isolation & 3D Hit-Test | `Test: M4-CameraGestureAndHitTest` |
| **REQ-P53-GROWTH-01..05**| §6: 5-Stage Biological Growth State Machine | `Test: M5-BiologicalGrowthFSM` |
| **REQ-P53-HUD-01..06** | §9–§11: TopBar, Inspector, Scrubber, Controls & Layer Filters | `Test: M4-HudDecks & M5-SongJourney` |
| **REQ-P53-NFR-01..04** | §7–§8: 60 FPS Zero-Allocation Painter & Zero Emojis | `Test: M6-PerformanceAndZeroEmojis` |
| **REQ-P53-INT-01..02** | §12: Studio Cockpit & Stem-Lock Bidirectional Entanglement | `Test: M6-CockpitEntanglement` |
| **REQ-P53-ACC-01..03** | §9 & §11: Responsive Layout, Haptics & Semantic Keys | `Test: M4-ResponsiveAndSemantics` |


---

### 11. Error Handling, Edge-Case Resilience & Degradation Requirements

#### REQ-P53-ERR-01: Near-Plane Clipping & Off-Screen Projection Guard
* **Statement**: IF any 3D vertex projects to an eye-space depth $d_{\text{eye}} \le 15.0\text{dp}$ (behind or dangerously close to the camera pinhole), THEN `BiomeProjectionEngine.project3D` SHALL return `null` and the painter SHALL gracefully skip that primitive without throwing `NaN` or `Infinity` canvas exceptions.

#### REQ-P53-ERR-02: Zero-Size Viewport Guard
* **Statement**: IF `OrganicMycelium3DPainter.paint(Canvas canvas, Size size)` is invoked with `size.width <= 0` or `size.height <= 0` during initial route layout, THEN the painter SHALL return immediately without allocating `ui.Vertices` buffers.

#### REQ-P53-ERR-03: Missing or Empty Studio Prompt Fallback
* **Statement**: IF `StudioFormState.prompt` is empty when entering the 3D Biome, THEN the deterministic seed generator SHALL fall back to hashing `(genre + tempoBracket + language + voiceProfile)` so the 3D Mycelium network always renders a rich, non-degenerate landscape.

#### REQ-P53-ERR-04: Multitouch Pointer Transition Stability
* **Statement**: WHEN the user transitions between 1-finger orbit ($N = 1$) and 2-finger pinch-to-zoom ($N = 2$) mid-gesture, the gesture handler SHALL update `_previousFocalPoint` cleanly without introducing instantaneous azimuth/pitch jumps.

---

### 12. Granular Requirement-to-Test Verification Matrix

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                     GRANULAR REQUIREMENT-TO-TEST TRACEABILITY                          │
├───────────────────┬────────────────────────────────────┬───────────────────────────────┤
│ REQUIREMENT ID    │ TARGET COMPONENT / CLASS           │ AUTOMATED TEST CASE           │
├───────────────────┼────────────────────────────────────┼───────────────────────────────┤
│ REQ-P53-CORE-01   │ MushroomFruitingBody (melodyCore)  │ test('melodyCore at 0,140,0') │
│ REQ-P53-CORE-02   │ MushroomFruitingBody (rhythmNet)   │ test('rhythmNet at -195,96,95')│
│ REQ-P53-CORE-03   │ MushroomFruitingBody (vocalNet)    │ test('vocalNet at -155,120,-90')│
│ REQ-P53-CORE-04   │ MushroomFruitingBody (harmonyNet)  │ test('harmonyNet at 165,115,-85')│
│ REQ-P53-CORE-05   │ MushroomFruitingBody (emotionNet)  │ test('emotionNet at 190,96,75')│
│ REQ-P53-CORE-06   │ MushroomFruitingBody (prodNet)     │ test('prodNet at -35,82,155') │
├───────────────────┼────────────────────────────────────┼───────────────────────────────┤
│ REQ-P53-MYCEL-01  │ MyceliumHyphaEdge (15 conduits)    │ test('15 arterial/sub hyphae')│
│ REQ-P53-MYCEL-02  │ MyceliumRootTendril (72 rootlets)  │ test('72 branching rootlets') │
│ REQ-P53-MYCEL-03  │ Synaptic Photon sampleAt(t)        │ test('spline photon transit') │
│ REQ-P53-MYCEL-04  │ MyceliumSproutNode (16 sprouts)    │ test('16 3D sprout pinheads') │
│ REQ-P53-MYCEL-05  │ Crystalline Stem-Lock Sheathing    │ test('stemLock sheath render')│
├───────────────────┼────────────────────────────────────┼───────────────────────────────┤
│ REQ-P53-CAM-01    │ BiomeProjectionEngine Y-Up Math    │ test('Y-Up elevation project')│
│ REQ-P53-CAM-02    │ Pointer-Isolated Orbit & Pinch     │ test('1-finger orbit vs zoom')│
│ REQ-P53-CAM-03    │ Overview Mode Zero Child Clutter   │ test('overview 6 badges only')│
│ REQ-P53-CAM-04    │ Canopy Dive & Child Leaf Unfurl    │ test('tap badge dives canopy')│
│ REQ-P53-CAM-05    │ Return to Surface Overview Button  │ test('return overview resets')│
├───────────────────┼────────────────────────────────────┼───────────────────────────────┤
│ REQ-P53-HUD-01    │ BiomeTopBar & NowPlayingCapsule    │ test('top bar transport controls')│
│ REQ-P53-HUD-02    │ BiomeClusterInspectorPanel         │ test('inspector metrics & nav')│
│ REQ-P53-HUD-03    │ SongJourneyTimelineScrubber        │ test('scrubber section glow') │
│ REQ-P53-HUD-04    │ BiomeInteractiveControlsBar        │ test('5 interactive controls')│
│ REQ-P53-HUD-05    │ BiomeNetworkLayersFilter           │ test('4 network layer filters')│
│ REQ-P53-HUD-06    │ Studio Cockpit Bidirectional Sync  │ test('cockpit mutator sync')  │
└───────────────────┴────────────────────────────────────┴───────────────────────────────┘
```
