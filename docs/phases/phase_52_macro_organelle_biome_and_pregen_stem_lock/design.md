# Phase 52 Technical Design: Macro-Canopy 3D Organelle Biome & Pre-Generation Stem-Lock Engine

## 1. 3D Spatial Geometry & Macro-Canopy Viewport

### 1.1 Mathematical Formulation of Mucus-Membrane Sheaths

A standard straight line between node $A$ and node $B$ fails to evoke organic biological tissue. Phase 52 constructs a closed parametric surface contour bounded by two flared meniscus curves:

Let $P_0$ be the center of the source organelle (or parent branch root) and $P_3$ be the target node center.
The centerline Bézier curve is:
$$B(t) = (1-t)^3 P_0 + 3(1-t)^2 t P_1 + 3(1-t) t^2 P_2 + t^3 P_3$$
where control points $P_1$ and $P_2$ are displaced perpendicular to the chord $\vec{D} = P_3 - P_0$ by a gentle harmonic sine offset $w \cdot \vec{N}$ ($\vec{N}$ is the unit normal in screen space).

The outer boundary profile $R(t)$ implements smooth-min meniscus webbing:
$$R(t) = R_{\text{start}} (1-t)^2 \cdot 1.45 + R_{\text{waist}} \cdot 4 t (1-t) + R_{\text{end}} t^2 \cdot 1.35$$
This creates wide, liquid meniscus attachment cones at the organelle and branch joints, tapering down into a flexible biological stalk.

### 1.2 Additive Light Blending & Internal Neural Filaments

Inside the translucent sheath, 3 internal sinusoidal neural fibers are rendered using `BlendMode.plus`:
$$F_k(t) = B(t) + \vec{N} \cdot A_k \sin(2\pi \cdot f_k \cdot t + \phi_k)$$
where $k \in \{0, 1, 2\}$, $A_k$ is the oscillation amplitude ($2.5\text{dp}$ to $4.5\text{dp}$), and $\phi_k = \frac{2\pi k}{3}$ yields a 3-strand helical braid. Under `BlendMode.plus`, overlapping fibers accumulate luminous energy, producing a hot core flare.

### 1.3 3 Tilted Elliptical Orbital Energy Rings

Surrounding the cyan membrane mesh are 3 elliptical rings tilted at Euler angles:
- Ring 1: Pitch $+28^\circ$, Yaw $+15^\circ$, radius $1.42 R_{\text{core}}$
- Ring 2: Pitch $-35^\circ$, Yaw $-40^\circ$, radius $1.65 R_{\text{core}}$
- Ring 3: Pitch $+12^\circ$, Yaw $-65^\circ$, radius $1.85 R_{\text{core}}$

Each ring rotates at a distinct orbital rate ($\omega_1 = 1.0\times, \omega_2 = -0.7\times, \omega_3 = 0.5\times$) and carries glowing satellite beads.

---

## 2. 2-Tier Spatial Hierarchy & Camera Animation

```
                       [ Overview Mode ]
                   Camera: Zoom 1.0x, R = 320dp
            Hovering right above Orange Nucleus surface
             4 Primary Branch Roots with Glass Pills:
      [ Beat & Groove ] ── [ Vocal Soul ] ── [ Instruments ] ── [ Spatial Room ]
                                │
               Tap Branch Root / Bubble (e.g. Instruments)
                                ▼
                   [ Branch Canopy Focus Mode ]
                   Camera: Zoom 2.25x, R = 220dp
            Focused directly on "Instruments & Harmony" Root
            Surrounded at arm's reach by Leaf Nodes:
   [ Lead Synth ] [ Rhodes ] [ Bamboo Flute ] [ Maskandi Guitar ] [ Log-Drum ]
                                │
              Tap [ 🔭 Surface Overview ] (`Key(...)`)
                                ▼
                       [ Overview Mode ]
```

---

## 3. Pre-Generation Stem-Lock & Hybrid Inpainting

### 3.1 Data Flow

```
[ 5-Channel Sketchpad ] / [ DAW Audio ]
   │
   ├─► Drums & Percussion (lockedPure44k) ──┐
   ├─► Log-Drum DX10 Sub (lockedPure44k)  ──┤ Export clean 44.1 kHz WAVs
   │                                        │
[ 3D Organelle Biome: StemLockMode ]        ▼
   │                              [ pregenStemLocks Manifest ]
   ▼                                        │
[ Synthesize from 3D DNA ]                  ▼
   │                              [ apps/vhunambi_api ]
   │                                        │
   ▼                                        ▼
[ RunPod Worker handler.py ] ◄──────────────┘
   │
   ├─► Stage 1: ACE-Step generates ONLY harmonicInpaint stems (Vocals, missing instruments)
   ├─► Stage 2: Demucs stem separation isolates AI accompaniment/vocals
   ├─► Stage 3: Seed-VC vocal timbre conversion
   ├─► Stage 4: Stem Replacement: AI's re-synthesized drums & bass are REPLACED
   │            with the 100% pure 44.1 kHz locked stems!
   └─► Stage 5: Commercial Studio Master DSP (-9.5 LUFS)
```

