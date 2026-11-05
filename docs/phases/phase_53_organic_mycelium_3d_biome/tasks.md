# Engineering Tasks & Milestone Plan: Phase 53 — 3D Organic Mycelium Biome

This document delineates the step-by-step engineering tasks, architectural milestones (M1–M6), concrete method signatures, target files, acceptance criteria, and automated verification gates for implementing the 3D Organic Mycelium Biome ("A Song as a Living Ecosystem").

---

## 1. Master Milestone Roadmap & Dependency Graph

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                           PHASE 53 MILESTONE ROADMAP                           │
├────────────────────────────────────────────────────────────────────────────────┤
│ M1: Procedural 3D Mycelium & Mushroom Mesh Generator                           │
│     ├── Domain models (Cluster, Leaf, Vector3D)                                │
│     └── Truncated cone stem + hemispherical cap + 32 radial gills generator    │
│                                       ▼                                        │
│ M2: Organic Node, Hyphal Filament & Synaptic Pulse Animation                   │
│     ├── Inter-cluster quadratic Bezier conduits                                │
│     └── Energy spore photon particles with 60 FPS cycling                      │
│                                       ▼                                        │
│ M3: 6 Musical Clusters, Domain Modeling & Decoupled Graph Provider             │
│     ├── Seed graph initialization (Melody, Rhythm, Vocal, Harmony, etc.)      │
│     └── Riverpod state notifier reactive synchronization                       │
│                                       ▼                                        │
│ M4: 3D Terrain Camera, Fixed Scale/Orbit Gestures & Inspector Drawer           │
│     ├── Gimbal-lock-free spherical camera controller                           │
│     ├── Pointer-count isolated gestures (N=1 orbit, N>=2 pinch/pan)            │
│     └── BiomeClusterInspectorPanel with live waveform & metric gauges          │
│                                       ▼                                        │
│ M5: Organic Growth State Machine & Song Journey Audio-Reactive Scrubber        │
│     ├── 4-phase biological growth state machine                                │
│     ├── Song Journey timeline scrubber (Intro -> Verse -> Chorus -> Outro)     │
│     └── Section-to-Luminosity matrix modulation                                │
│                                       ▼                                        │
│ M6: Real Audio Analysis, MMO Integration, Benchmark & Release Delivery         │
│     ├── MMO stem feature mapping & Hive binary serialization                   │
│     ├── Full-screen route navigation from Studio Cockpit                       │
│     └── Physical ARM64 device verification (Huawei JNY-LX1) & release APK      │
└────────────────────────────────────────────────────────────────────────────────┘
```

| Milestone | Description | Target Files | Dependencies | Test Gate |
| :--- | :--- | :--- | :--- | :--- |
| **M1** | Procedural 3D Mesh Generator | `lib/features/studio/domain/models/mycelium_*.dart` | None | Unit tests for 3D math & mesh |
| **M2** | Hyphae & Synaptic Pulse | `lib/features/studio/domain/models/mycelium_hypha.dart` | M1 | Spore Bezier path tests |
| **M3** | 6 Musical Clusters & State | `lib/features/studio/presentation/providers/*` | M1, M2 | Graph synchronization tests |
| **M4** | 3D Camera & Inspector Drawer | `lib/features/studio/presentation/widgets/biome/*` | M3 | Gesture & drawer widget tests |
| **M5** | Timeline & Audio Modulation | `lib/features/studio/presentation/widgets/biome/*` | M3, M4 | Scrubber & lighting tests |
| **M6** | MMO Sync, Route & ARM64 APK | `lib/features/studio/presentation/views/*` | M1–M5 | Physical device 60 FPS profiling |

---

## 2. Milestone M1: Procedural 3D Mycelium & Mushroom Mesh Generator

### Task 1.1: Core Domain Entities & Mathematical Types
- **Target File**: `lib/features/studio/domain/models/mycelium_cluster.dart`
- **Specification**:
  - Implement immutable domain classes: `MyceliumCluster`, `MyceliumLeaf`, and `Vector3D`.
  - Properties: `id`, `clusterType`, `title`, `roleDescription`, `positionX`, `positionY`, `positionZ`, `stemHeight`, `capRadius`, `hexColor`, `intensity`, `complexity`, `influence`, `childLeaves`, and `connectedClusterIds`.
  - Factory constructor: `MyceliumCluster.fromJson(Map<String, dynamic> json)`.
  - Serialization: `Map<String, dynamic> toJson()`.
  - Value equality: Override `operator ==` and `hashCode`.
- **Acceptance Criteria**:
  - Zero dependencies on Flutter UI (`dart:ui` or `package:flutter`) in pure domain layer.
  - Serialization round-trip maintains exact double floating-point precision.

### Task 1.2: Procedural 3D Mushroom Mesh Generator
- **Target File**: `lib/features/studio/presentation/painters/mushroom_mesh_generator.dart`
- **Method Signatures**:
  ```dart
  class MushroomMeshGenerator {
    static Path generateCapPath({
      required Offset screenCenter,
      required double radiusX,
      required double radiusY,
      required double curvature,
    });

    static List<Offset> generateStemPolygon({
      required Offset basePoint,
      required Offset apexPoint,
      required double baseRadius,
      required double topRadius,
    });

    static List<Offset> generateRadialGillRims({
      required Offset apexPoint,
      required double radiusX,
      required double radiusY,
      required int gillCount,
    });
  }
  ```
- **Acceptance Criteria**:
  - Generates 32 evenly distributed radial gill points around the elliptical rim.
  - Generates smooth parabolic cap curvature with zero apex vertex pinching.

### Task 1.3: Automated Test Verification (M1 Gate)
- **Target File**: `test/features/studio/domain/mycelium_cluster_test.dart`
- **Coverage**:
  - 100% line coverage of domain entity instantiation, JSON serialization, and mesh vertex counts.

---

## 3. Milestone M2: Organic Node, Hyphal Filament & Synaptic Pulse Animation

### Task 2.1: Inter-Cluster Hyphal Conduits & Bezier Spline Models
- **Target File**: `lib/features/studio/domain/models/mycelium_hypha.dart`
- **Specification**:
  - Model attributes: `id`, `sourceClusterId`, `targetClusterId`, `weight`, `isActive`, `curvatureOffset`, `activeSpores`.
  - Quadratic Bezier midpoint calculation taking into account vertical terrain sag and organic perturbation.
  - Method: `Offset evaluateQuadraticBezier(Offset p0, Offset p1, Offset p2, double t)`.

### Task 2.2: Synaptic Energy Spore & Particle Simulation
- **Target File**: `lib/features/studio/domain/models/mycelium_spore.dart`
- **Specification**:
  - Properties: `id`, `hyphaId`, `normalizedProgress`, `speed`, `colorHex`, `glowRadius`.
  - Continuous cycling method: `MyceliumSpore advance(double deltaProgress)`.
  - Velocity modulation based on song tempo (BPM) and transient energy.

### Task 2.3: Automated Test Verification (M2 Gate)
- **Target File**: `test/features/studio/domain/mycelium_hypha_test.dart`
- **Coverage**:
  - Verification that parameter $t=0.0 \to p_0$ and $t=1.0 \to p_2$ within $10^{-6}$ precision.
  - Validation of continuous cycle wrap-around when `progress >= 1.0`.

---

## 4. Milestone M3: 6 Musical Clusters, Domain Modeling & Decoupled Graph Provider

### Task 3.1: Seed Ecosystem Graph Factory
- **Target File**: `lib/features/studio/domain/factories/mycelium_seed_graph_factory.dart`
- **Specification**:
  - Produce the canonical 6-cluster musical ecosystem:
    1. 🎵 `melodyCore` ($X: 0, Y: 0, Z: 0$, Gold `#FF9E00`)
    2. 🥁 `rhythmNetwork` ($X: -140, Y: 0, Z: 100$, Cyan `#00B4D8`)
    3. 🎤 `vocalNetwork` ($X: -150, Y: -20, Z: -120$, Violet `#9D4EDD`)
    4. 🎼 `harmonyNetwork` ($X: 150, Y: 0, Z: -110$, Emerald `#10B981`)
    5. 💗 `emotionNetwork` ($X: 160, Y: 10, Z: 80$, Magenta `#F72585`)
    6. 🎚️ `productionNetwork` ($X: 0, Y: -10, Z: 160$, Aqua `#06D6A0`)
  - Construct 15 pairwise connecting hyphae with calibrated biological weights.

### Task 3.2: Riverpod Reactive Graph Notifier
- **Target File**: `lib/features/studio/presentation/providers/mycelium_biome_provider.dart`
- **Signatures**:
  ```dart
  class MyceliumBiomeGraphNotifier extends StateNotifier<MusicalDnaGraph> {
    void updateClusterIntensity(String clusterId, double intensity);
    void mutateLeafParameter(String clusterId, String leafId, dynamic value);
    void triggerSynapticImpulse(String sourceClusterId, String targetClusterId);
    void synchronizeWithStudioForm(StudioFormState formState);
  }
  ```

### Task 3.3: Automated Test Verification (M3 Gate)
- **Target File**: `test/features/studio/presentation/providers/mycelium_biome_provider_test.dart`
- **Coverage**:
  - Test Studio form mutation immediately reflects in cluster metrics and hyphae luminosities.

---

## 5. Milestone M4: 3D Terrain Camera, Fixed Scale/Orbit Gestures & Inspector Drawer

### Task 4.1: Gimbal-Lock-Free Spherical Orbit Camera Controller
- **Target File**: `lib/features/studio/presentation/controllers/biome_camera_controller.dart`
- **Specification**:
  - State variables: `targetX`, `targetY`, `targetZ`, `yaw`, `pitch`, `distance`, `zoom`.
  - Strict hardware bounds: $\text{pitch} \in [15^\circ, 80^\circ]$, $\text{distance} \in [180.0, 750.0]$.
  - Smooth canopy glide method: `Future<void> glideToCluster(MyceliumCluster cluster)`.
  - Overview reset method: `Future<void> returnToOverview()`.

### Task 4.2: Gesture Pointer-Count Separation Handler
- **Target File**: `lib/features/studio/presentation/widgets/biome/biome_gesture_boundary.dart`
- **Specification**:
  - Pointer count $N = 1$: Handle orbit yaw/pitch without touching distance/scale.
  - Pointer count $N \ge 2$: Handle pinch-to-zoom distance scaling and 2-finger target pan without triggering orbit deltas.
  - Zero canvas freeze or touch contention across multi-touch transitions.

### Task 4.3: `BiomeClusterInspectorPanel` Drawer Widget
- **Target File**: `lib/features/studio/presentation/widgets/biome/biome_cluster_inspector_panel.dart`
- **Components**:
  - Animated live FFT frequency spectrum canvas (24 bars).
  - Metric arc indicators: `Intensity`, `Complexity`, `Influence`.
  - Connected node quick-jump chips.
  - Direct Studio Cockpit mutation action button.

### Task 4.4: Automated Test Verification (M4 Gate)
- **Target File**: `test/features/studio/presentation/widgets/biome_camera_and_drawer_test.dart`
- **Coverage**:
  - Widget test verifying tap on parent mushroom head invokes `glideToCluster` and displays `BiomeClusterInspectorPanel`.

---

## 6. Milestone M5: Organic Growth State Machine & Song Journey Audio-Reactive Scrubber

### Task 5.1: Biological Growth State Machine
- **Target File**: `lib/features/studio/domain/models/biome_growth_state.dart`
- **Specification**:
  - Enums: `sporeFormation`, `hyphalExtension`, `primordiumFruiting`, `matureCanopy`.
  - Growth progression interpolation parameter $\alpha_{growth} \in [0.0, 1.0]$.
  - Stem height and cap radius scale according to Sigmoid growth curve:
    $$S(\alpha) = \frac{1}{1 + e^{-10(\alpha - 0.5)}}$$

### Task 5.2: `SongJourneyTimelineScrubber` Widget
- **Target File**: `lib/features/studio/presentation/widgets/biome/song_journey_timeline_scrubber.dart`
- **Specification**:
  - 5 formal song sections: `Intro`, `Verse`, `Chorus`, `Bridge`, `Outro`.
  - Real-time scrubbing callback: `onSeek(double positionSeconds)`.
  - Section marker highlight and active position pulse beacon.

### Task 5.3: Section-to-Luminosity Lighting Matrix Coupling
- **Target File**: `lib/features/studio/presentation/controllers/song_journey_notifier.dart`
- **Specification**:
  - Compute cluster illumination vector $\mathbf{L}(t)$ dynamically based on active song section and audio RMS energy.
  - Chorus excitation: All 6 mushroom fruiting bodies fire at 100% saturation and emit bursting synaptic spores.

### Task 5.4: Automated Test Verification (M5 Gate)
- **Target File**: `test/features/studio/presentation/widgets/song_journey_timeline_test.dart`
- **Coverage**:
  - Verify seeking to Chorus activates 100% illumination across all 6 clusters.

---

## 7. Milestone M6: Real Audio Analysis, MMO Integration, Benchmark & Release Delivery

### Task 6.1: MasterMediaObject (MMO) & Hive Binary Serialization
- **Target File**: `lib/features/studio/data/repositories/mycelium_cache_repository.dart`
- **Specification**:
  - Hive Box `mycelium_biome_cache_v1`.
  - Binary encoding/decoding of graph state, cluster positions, and cached spectral envelopes.
  - Fallback to procedural generation if cached MMO is unavailable.

### Task 6.2: Full-Screen Biome Route & Cockpit Hovering Pill
- **Target Files**:
  - `lib/features/studio/presentation/views/organic_mycelium_3d_world_view.dart`
  - `lib/features/studio/presentation/widgets/cockpit/song_dna_hover_pill.dart`
- **Specification**:
  - Tapping `SongDnaHoverPill` in Studio Cockpit opens `OrganicMycelium3DWorldView` with smooth scale/fade transition.
  - Return button in top transport bar pops route back to Studio Cockpit with zero loss of state.

### Task 6.3: ARM64 Device Profiling & 60 FPS Verification
- **Target Device**: Huawei JNY-LX1 (`EPHUT20917014649`, Android 12)
- **Benchmarking Protocol**:
  - Run Flutter DevTools performance profile for 120 seconds of continuous 3D camera orbit and canopy diving.
  - Verify: Average build + raster frame duration $\le 12.8\text{ ms}$ (locked 60 FPS).
  - Verify: Zero frame drops during pointer-count transitions ($N=1 \leftrightarrow N=2$).

### Task 6.4: Full Test Suite, Static Analysis & Production APK Build
- **Target Commands**:
  - `flutter test` (Verify 100% pass across all existing and new test suites).
  - `flutter analyze` (Verify 0 issues found).
  - `flutter build apk --release` (Compile ARM64 production APK).
  - Install and launch on target device (`EPHUT20917014649`).

---

## 8. Milestone Traceability Matrix

| Requirement ID | Requirement Description | Milestone | Verified By Test |
| :--- | :--- | :--- | :--- |
| **REQ-MYC-001** | Sovereign 3D Abyssal Void & Terrain Grid | M1, M4 | `organic_mycelium_3d_painter_test.dart` |
| **REQ-MYC-002** | 6 Distinct Mushroom Fruiting Clusters | M1, M3 | `mycelium_cluster_test.dart` |
| **REQ-MYC-003** | Inter-Cluster Hyphal Conduits & Synaptic Spores | M2 | `mycelium_hypha_test.dart` |
| **REQ-MYC-004** | Clean Overview Icon Badges (Zero Ghost Collisions) | M1, M4 | `organic_mycelium_3d_painter_test.dart` |
| **REQ-MYC-005** | Smooth Camera Glide on Mushroom Head Tap | M4 | `biome_camera_and_drawer_test.dart` |
| **REQ-MYC-006** | Satellite Leaf Node Unfurling at Canopy | M1, M4 | `biome_camera_and_drawer_test.dart` |
| **REQ-MYC-007** | Floating Frosted Glass Inspector Drawer | M4 | `biome_cluster_inspector_panel_test.dart` |
| **REQ-MYC-008** | Live 24-Bar Audio Spectrum FFT Canvas | M4 | `biome_cluster_inspector_panel_test.dart` |
| **REQ-MYC-009** | Triple Metric Gauges (Intensity, Complexity, Influence) | M3, M4 | `mycelium_biome_provider_test.dart` |
| **REQ-MYC-010** | Connected Node Conduits & Inter-Cluster Glide | M2, M4 | `biome_camera_and_drawer_test.dart` |
| **REQ-MYC-011** | Song Journey Timeline Scrubber | M5 | `song_journey_timeline_test.dart` |
| **REQ-MYC-012** | Dynamic Section-to-Luminosity Audio Lighting | M5 | `song_journey_timeline_test.dart` |
| **REQ-MYC-013** | Top Transport Bar & Studio Exit Sync | M4, M6 | `organic_mycelium_3d_world_view_test.dart` |
| **REQ-MYC-014** | MasterMediaObject (MMO) & Hive Binary Caching | M6 | `mycelium_cache_repository_test.dart` |
| **REQ-MYC-015** | Mathematical Gimbal-Lock & Pointer-Count Isolation | M4 | `biome_camera_controller_test.dart` |
| **REQ-MYC-016** | 60 FPS Locked ARM64 Performance Budget | M6 | Physical device benchmark profiling |
