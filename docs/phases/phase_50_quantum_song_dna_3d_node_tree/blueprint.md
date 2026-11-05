# Phase 50 Blueprint: Quantum-Entangled 3D Song DNA Tree & Hovering Cockpit Pill

## 1. Executive Forensic Architecture

In physical device recordings (`SVID_20261104_154958_1.mp4` and `SVID_20261105_001712.mp4`), the static `DNA 67%` badge in `StudioView` (`ProgressTrackerWidget`) remained completely unresponsive when tapped at timestamps `00:08` and `00:18`. Simultaneously, the Now Playing transport bar overlapped the sticky `StudioActionBar` (`00:04–00:20`), obscuring prompt input and action buttons.

Phase 50 transforms the Studio Cockpit from a one-sided scrolling form into a **Quantum-Entangled Dual Interface**:
1. **The Living 3D Hover Pill (`SongDnaHoverPill`)**: Elevated, 60 FPS levitating capsule with dynamic multi-spectrum orbital glow indicating active acoustic layers.
2. **Full-Screen 3D Navigable Song DNA Tree (`SongDnaNodeTreeModal`)**: Interactive 3D spatial node architecture with pitch/yaw orbit drag, pinch zoom, depth-sorted energy conduits, and billboarded cue bubbles.
3. **Sleek Floating Quick-Action Card**: Glassmorphic mutation dock enabling immediate bi-directional synchronization with `studioFormProvider`, `vocalIdentityProvider`, `melodySketchpadProvider`, and `stemRemixProvider`.
4. **Studio Mini-Player Clearance**: Automatic obstacle offset enforcement preventing playback controls from overlapping sticky studio actions.

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│      PHASE 50: QUANTUM-ENTANGLED 3D SONG DNA TREE & HOVERING COCKPIT PILL        │
├──────────────────────────────────────────────────────────────────────────────────┤
│ 1. THE LIVING 3D HOVER PILL (`SongDnaHoverPill` in Studio Cockpit)               │
│    • Gentle 60 FPS vertical levitation (2.5dp sine bob) + 3D bevel/rim depth.    │
│    • Multi-spectrum orbital glow that shifts color as you build the song:        │
│      - Amber (#F97316): Beat & Groove active                                     │
│      - Cyan (#06B6D4): Vocal & Bantu Lyrics active                               │
│      - Emerald (#10B981): Instruments & MPC Chops active                         │
│      - Electric Violet (#D946EF): INVASIVE NODE grafted (User Voice / Ref Audio) │
├────────────────────────────────────────┬─────────────────────────────────────────┤
│                                        │ (Tap Pill -> Portal Expand)             │
│                                        ▼                                         │
│ 2. FULL-SCREEN 3D NAVIGABLE SONG DNA TREE (`SongDnaNodeTreeModal`)               │
│    • 3D Pitch/Yaw Orbit Drag + Pinch Zoom + Perspective Depth Sorting (Z-Buffer) │
│    • LIVING CONDUIT BRANCHES: Branches fill with flowing energy particles        │
│      (0% -> 100%) showing exact progress toward unlocking/completing each node.  │
│                                                                                  │
│                       [ 💬 "Amapiano • 113 BPM" ] ◄── Floating Cue Bubble        │
│                                   (●) BEAT NODE                                  │
│                                    ║  (Flowing Energy Conduit)                   │
│     [ 💬 "Makhado Alto" ] (●)══════╬══════(●) [ 💬 "Rhodes + Log Drum" ]         │
│         VOCAL NODE                 ║              INSTRUMENT NODE                │
│                                (◈ CORE)                                          │
│                                    ║                                             │
│                                   (❖) ◄── INVASIVE / 3RD-PARTY NODE              │
│                       [ 💬 "My Recorded Voice (VHU-SIG)" ]                       │
├────────────────────────────────────────┬─────────────────────────────────────────┤
│                                        │ (Tap Any Floating Bubble / Node)        │
│                                        ▼                                         │
│ 3. SLEEK FLOATING QUICK-ACTION CARD (Bi-Directional Quantum Entanglement)        │
│    • Appears with rounded corners right below the focused 3D node.               │
│    • Instant Actions: [ Swap / Change ]  [ + Add Sub-Layer ]  [ Detach / Reset ] │
│    • Every edit immediately mutates `studioFormProvider`, `vocalIdentityProvider`│
│      `melodySketchpadProvider`, and `mpcSlicerProvider` in real time!            │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. The 4 Hierarchical Node Classes & Visual Taxonomy

Every node and conduit branch belongs to one of four distinct visual classes with specific geometric shapes, colors, and unlock rules:

| Node Class | Color & Token | Geometry | Contained Nodes | Progression & Unlock Rules |
|---|---|---|---|---|
| **1. Beat & Core** | African Amber (`#F97316`) | Octagonal Core + Pulsing Beat Spheres | • `node_core`: Song Genesis Core (Prompt & Song Title)<br>• `node_genre_tempo`: Genre & Tempo Pulse (`Amapiano • 113 BPM`) | Conduit glows at 50% when default genre is active; surges to 100% streaming particles once prompt and custom tempo/bracket are locked in. |
| **2. Vocal & Lyrics** | Sovereign Cyan (`#06B6D4`) | Crystalline Acoustic Diamond Nodes | • `node_vocal_persona`: Vocal Identity & Timbre (`Makhado Royal Alto`)<br>• `node_language_lyrics`: Bantu Dialect & Lyrics (`Tshivenḓa`, AI vs Custom)<br>• `node_mood_energy`: Emotional Mood & Vocal Energy | Branch progressively illuminates as the creator selects regional voice archetypes, indigenous dialects, and lyrics input. |
| **3. Instruments & Harmony** | Vibrant Emerald (`#10B981`) | Harmonic Ring Nodes (Additive Satellites) | • `node_sketchpad_groove`: 5-Channel Sketchpad Pattern (`Lead`, `Chords`, `Log Drum`, `Drums`, `Hats`)<br>• `node_heritage_mpc`: Heritage Crate Slices & MPC Chops | Supports additive sub-nodes. Attaching a 5-channel pattern spawns a constellation of small orbiting satellite sub-nodes around the instrument branch. |
| **4. Invasive / 3rd-Party** | Electric Magenta-Violet (`#D946EF`) | Spiked Counter-Rotating Double-Ring Nodes | • `node_invasive_voice_clone`: User Recorded Voice (`VHU-SIG`)<br>• `node_invasive_reference`: External Reference Audio / Custom Beat<br>• `node_invasive_remix_lineage`: Parent Remix Lineage (`StemRemixContext`) | Visually distinct external grafting. Renders counter-rotating outer ring and high-frequency lightning tethers, showing external human or 3rd-party audio grafted onto the song genome. Can be detached via 1-tap. |

---

## 3. Mathematical Foundations: 3D Projection & Orbit Physics

### 3.1 3D Camera Spherical Coordinates
The 3D Song DNA space is navigated via spherical camera angles:
- Azimuth angle (Yaw): $\theta \in [-\pi, \pi]$
- Polar angle (Pitch): $\phi \in [-0.4\pi, 0.4\pi]$ (clamped to prevent gimbal flipping)
- Camera distance (Zoom): $R_{\text{cam}} \in [240.0, 680.0]\text{dp}$, default $420.0\text{dp}$

Coordinate transformation matrix for node $i$ with local coordinates $(X_i, Y_i, Z_i)$:

$$\begin{bmatrix} X'_i \\ Y'_i \\ Z'_i \end{bmatrix} = \begin{bmatrix} \cos\theta & 0 & -\sin\theta \\ -\sin\phi\sin\theta & \cos\phi & -\sin\phi\cos\theta \\ \cos\phi\sin\theta & \sin\phi & \cos\phi\cos\theta \end{bmatrix} \begin{bmatrix} X_i \\ Y_i \\ Z_i \end{bmatrix}$$

### 3.2 Perspective Projection to Screen Coordinates
For viewport size $(W, H)$ with center $(c_x, c_y) = (W/2, H/2)$ and focal length $F = 380.0$:

$$\text{scale}_i = \frac{F}{F + Z'_i + R_{\text{cam}}}$$

$$x_{\text{screen}, i} = c_x + X'_i \cdot \text{scale}_i$$

$$y_{\text{screen}, i} = c_y + Y'_i \cdot \text{scale}_i$$

$$\text{projectedRadius}_i = R_{\text{node}} \cdot \text{scale}_i$$

### 3.3 Flowing Conduit Energy Particles
Along each conduit branch between Core $(x_0, y_0, z_0)$ and Node $i$ $(x_i, y_i, z_i)$, energy particles stream at phase speed:

$$t_p = \left(t_{\text{sec}} \cdot 1.2 + \frac{p}{N_p}\right) \pmod{1.0} \quad \text{for } p \in [0..N_p - 1]$$

$$\vec{P}(t_p) = (1 - t_p) \vec{P}_{\text{core}} + t_p \vec{P}_i$$

Particle alpha is gated by `branchUnlockProgress`:

$$\alpha_p = \text{progress}_i \cdot \sin(\pi \cdot t_p)$$

---

## 4. UI Architecture & Responsive Wireframes

### 4.1 Mobile Viewport (360dp – 420dp)

```
┌────────────────────────────────────────┐
│  [ ✕ Close ]   SONG DNA LAB   [ ⚙ ↺ ]  │
├────────────────────────────────────────┤
│                                        │
│          [ 💬 Amapiano • 113 ]         │
│                   (●)                  │
│                    ║                   │
│  [ 💬 Makhado ]   (◈)   [ 💬 Rhodes ]  │
│        (●)═════════╬═════════(●)       │
│                    ║                   │
│                   (❖)                  │
│       [ 💬 Invasive: VHU-SIG ]         │
│                                        │
├────────────────────────────────────────┤
│ [ - Zoom ]  [ ⌖ Focus ]  [ + Zoom ]    │
├────────────────────────────────────────┤
│ ┌────────────────────────────────────┐ │
│ │ 🥁 GENRE & TEMPO NODE              │ │
│ │ Amapiano • Medium 113 BPM          │ │
│ │ ┌──────────┐ ┌─────────┐ ┌───────┐ │ │
│ │ │ Amapiano │ │  Gqom   │ │ Mask. │ │ │
│ │ └──────────┘ └─────────┘ └───────┘ │ │
│ │ Tempo: [ Slow ] [ Medium ] [ Fast] │ │
│ └────────────────────────────────────┘ │
│ [ ⚡ Synthesize Song from 3D DNA ]     │
└────────────────────────────────────────┘
```

### 4.2 Desktop Viewport (1440dp)

```
┌────────────────────────────────────────────────────────────────────────┐
│  [ ✕ Close ]       VHUNAMBI QUANTUM SONG DNA TREE          [ Reset ⌖ ] │
├─────────────────────────────────────────┬──────────────────────────────┤
│                                         │ FOCUSED NODE INSPECTOR       │
│                [ 💬 Amapiano • 113 ]    │                              │
│                         (●)             │ 🎤 VOCAL PERSONA NODE        │
│                          ║              │ Makhado Royal Alto (Female)  │
│      [ 💬 Makhado ]     (◈)     [ 💬 ]  │ Sovereign Bantu Timbre       │
│            (●)═══════════╬════════(●)   │                              │
│                          ║              │ Quick Swapper:               │
│                         (❖)             │ [ Venda Elder ] [ Zulu Alto] │
│             [ 💬 Invasive: VHU-SIG ]    │ [ Pedi Tenor  ] [ Xhosa Bass]│
│                                         │                              │
│                                         │ Bantu Lyrics Dialect:        │
│                                         │ [ Tshivenḓa ] [ isiZulu ]    │
│                                         │                              │
│                                         │ [ + Inject Cloned Voice ]    │
├─────────────────────────────────────────┼──────────────────────────────┤
│ Navigation: Orbit Drag • Scroll Zoom    │ [ Synthesize Song from DNA ] │
└─────────────────────────────────────────┴──────────────────────────────┘
```

---

## 5. MiniPlayerHost Obstacle Resolution

When Tab 2 (`StudioView`) is active:
1. `StudioView` mounts `PlayerObstacle(id: 'studio_action_bar')` wrapping the sticky dock.
2. `MiniPlayerController.calculateAutoPosition()` reads registered dock obstacles.
3. If `studio_action_bar` is registered, target $Y$ docks cleanly at:

$$Y_{\text{dock}} = Y_{\text{obstacle\_top}} - H_{\text{player}} - 8.0\text{dp}$$

4. When height constrained on small viewports ($< 700\text{dp}$), `MiniPlayerHost` collapses to compact pill mode in the top-right corner to preserve 100% touch usability for prompt input and synthesis buttons.

