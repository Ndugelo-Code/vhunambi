# Engineering Tasks & Milestone Plan: Phase 53 — 3D Organic Mycelium Biome

This document delineates the step-by-step engineering tasks, architectural milestones (M1–M6), concrete method signatures, target file paths under `apps/vhunambi_client/`, acceptance criteria, and automated verification gates for implementing **Phase 53: The 3D Organic Mycelium Biome ("A Song as a Living Ecosystem")**.

---

## 1. Master Milestone Roadmap & Dependency Graph

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              PHASE 53 MILESTONE ROADMAP                                │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ M1: Pure Dart 3D Y-Up Domain Models & Terrain Elevation Math                           │
│     ├── MyceliumClusterDomain, MushroomFruitingBody, MyceliumChildNode, Vector3D       │
│     └── BiomeTerrainMath.heightAt(x, z) & 5-stage BiomeGrowthPhase                     │
│                                           ▼                                            │
│ M2: Space-Colonization Mycelium Web, 16 3D Sprout Mushrooms & Synaptic Photons         │
│     ├── 15 Arterial MyceliumHyphaEdge 9-waypoint 3D splines on Y = h(X, Z) + 1.5       │
│     ├── 72 Branching MyceliumRootTendril sub-filaments                                 │
│     └── 16 Miniature 3D Bioluminescent MyceliumSproutNode pinhead mushrooms            │
│                                           ▼                                            │
│ M3: 6 Musical Clusters Seed Factory & Entangled Riverpod Graph Notifier                │
│     ├── Canonical Y-Up 3D coordinates for Melody, Rhythm, Vocal, Harmony, Emo, Prod    │
│     └── Bidirectional sync with StudioFormProvider & StemLockMode                      │
│                                           ▼                                            │
│ M4: 3D Vertices Mesh Painter, Y-Up Camera, Hit-Testing & Full 5-Deck HUD               │
│     ├── OrganicMycelium3DPainter (ui.Vertices 3D Cap + 32 3D Gills + 8-Ring Stipe)     │
│     ├── BiomeProjectionEngine.hitTest + Pointer-Isolated Orbit/Zoom Camera             │
│     └── BiomeTopBar, BiomeClusterInspectorPanel, Controls Bar & Layer Filter Decks     │
│                                           ▼                                            │
│ M5: 5-Stage Organic Growth FSM & Song Journey Audio-Reactive Timeline Scrubber         │
│     ├── Growth progression tau in [0.0, 1.0] (Nucleus -> Hyphae -> Stipe -> Mature)    │
│     └── SongJourneyTimelineScrubber (Intro -> Verse -> Chorus -> Bridge -> Outro)      │
│                                           ▼                                            │
│ M6: Studio Cockpit Integration, Comprehensive Widget Tests & ARM64 APK Verification    │
│     ├── Full-screen opaque route via SongDnaNodeTreeModal                              │
│     └── 100% pass on flutter test, 0 issues on flutter analyze & physical device test  │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

| Milestone | Description | Target Files (`apps/vhunambi_client/`) | Dependencies | Verification Test Gate |
| :--- | :--- | :--- | :--- | :--- |
| **M1** | Pure Dart 3D Y-Up Domain & Terrain Math | `lib/features/studio/domain/models/mycelium_biome_models.dart` | None | `M1-DomainAndTerrainTest` |
| **M2** | Space-Colonization Web & 16 3D Sprouts | `lib/features/studio/domain/models/mycelium_biome_models.dart` | M1 | `M2-MyceliumWebAndSproutsTest` |
| **M3** | 6 Clusters Factory & Riverpod Provider | `lib/features/studio/presentation/providers/mycelium_biome_provider.dart` | M1, M2 | `M3-GraphProviderSyncTest` |
| **M4** | 3D Vertices Painter, Camera & 5 HUD Decks | `lib/features/studio/presentation/widgets/biome/*.dart` | M1–M3 | `M4-PainterCameraAndHudTest` |
| **M5** | 5-Stage Growth & Song Journey Scrubber | `lib/features/studio/presentation/widgets/biome/song_journey_*.dart` | M3, M4 | `M5-GrowthAndJourneyTest` |
| **M6** | Cockpit Route Wiring & Hardware Release | `lib/features/studio/presentation/widgets/song_dna_node_tree_modal.dart` | M1–M5 | `phase53_organic_mycelium_3d_biome_test.dart` |

---

## 2. Milestone M1: Pure Dart 3D Y-Up Domain Models & Terrain Elevation Math

### Task 1.1: Core Domain Entities & Enumerations
- **Target File**: `apps/vhunambi_client/lib/features/studio/domain/models/mycelium_biome_models.dart`
- **Specification**:
  - Implement pure Dart enums:
    - `MyceliumClusterDomain` (`melodyCore`, `rhythmNetwork`, `vocalNetwork`, `harmonyNetwork`, `emotionNetwork`, `productionNetwork`)
    - `MyceliumNetworkLayer` (`coreElements`, `supportingElements`, `atmosphere`, `emotionalLayer`)
    - `SongJourneySection` (`intro`, `verse`, `chorus`, `bridge`, `outro`)
    - `BiomeGrowthPhase` (`nucleusSeed`, `primaryNodesEmerge`, `hyphaeBranching`, `fruitingBodiesSprout`, `ecosystemMature`)
  - Implement immutable classes:
    - `Vector3D` (Right-Handed Y-Up: $X$ right, $+Y$ elevation up, $+Z$ foreground depth)
    - `MushroomFruitingBody` (with `capApexPosition => Vector3D(rootPosition.x, rootPosition.y + stipeHeight, rootPosition.z)`)
    - `MyceliumChildNode`
    - `MusicalDnaGraph`
- **Acceptance Criteria**:
  - Zero imports of `package:flutter` or `dart:ui` in `mycelium_biome_models.dart` (`REQ-P53-NFR-04`).

### Task 1.2: 3D Y-Up Contoured Terrain Elevation Math (`BiomeTerrainMath`)
- **Target File**: `apps/vhunambi_client/lib/features/studio/domain/models/mycelium_biome_models.dart`
- **Method Signatures**:
  ```dart
  class BiomeTerrainMath {
    static double heightAt(double x, double z);
    static Vector3D normalAt(double x, double z);
  }
  ```
- **Acceptance Criteria**:
  - `heightAt(x, z)` evaluates the 6 Gaussian cluster mounds plus micro-undulations and strictly satisfies $Y = h(X, Z) \ge 0$ across $(X, Z) \in [-320, 320] \times [-260, 260]$.

---

## 3. Milestone M2: Space-Colonization Mycelium Web, 16 3D Sprout Mushrooms & Synaptic Photons

### Task 2.1: 15 Cross-Cluster Arterial Hyphal Conduits (`MyceliumHyphaEdge`)
- **Target File**: `apps/vhunambi_client/lib/features/studio/domain/models/mycelium_biome_models.dart`
- **Specification**:
  - Implement `MyceliumHyphaEdge` with 9 3D spline waypoints locked to terrain elevation $Y(t) = h(X(t), Z(t)) + 1.5\text{dp}$.
  - Implement `Vector3D sampleAt(double t)` for continuous 3D photon position evaluation along $t \in [0.0, 1.0]$.

### Task 2.2: 72 Branching Rootlet Tendrils & 16 3D Sprout Mushrooms
- **Target File**: `apps/vhunambi_client/lib/features/studio/domain/models/mycelium_biome_models.dart`
- **Specification**:
  - Implement `MyceliumRootTendril` (12 radiating 5-step branching rootlets per cluster hugging $Y = h(X, Z) + 0.8\text{dp}$).
  - Implement `MyceliumSproutNode` (16 miniature 3D bioluminescent pinhead mushrooms at hyphal junctions with $H \in [9, 18]\text{dp}$ and $R_{\text{cap}} \in [5, 11]\text{dp}$).

---

## 4. Milestone M3: 6 Musical Clusters Seed Factory & Entangled Riverpod Graph Notifier

### Task 3.1: Canonical 6-Cluster Y-Up Ecosystem Factory
- **Target File**: `apps/vhunambi_client/lib/features/studio/presentation/providers/mycelium_biome_provider.dart`
- **Specification**:
  - Construct the 6 `MushroomFruitingBody` clusters in Right-Handed 3D Y-Up World Space:
    1. `melodyCore`: Planar $(0, 0)$, $Y_{\text{root}} = h(0, 0) \approx 32\text{dp}$, $H_{\text{stipe}} = 108\text{dp} \implies$ Apex $(0, 140, 0)$, $R_{\text{cap}} = 56\text{dp}$, Gold `#FF9E00`, 5 child leaves.
    2. `rhythmNetwork`: Planar $(-195, +95)$, $Y_{\text{root}} \approx 22\text{dp}$, $H_{\text{stipe}} = 74\text{dp} \implies$ Apex $(-195, 96, +95)$, $R_{\text{cap}} = 42\text{dp}$, Cyan `#00B4D8`, 5 child leaves.
    3. `vocalNetwork`: Planar $(-155, -90)$, $Y_{\text{root}} \approx 26\text{dp}$, $H_{\text{stipe}} = 94\text{dp} \implies$ Apex $(-155, 120, -90)$, $R_{\text{cap}} = 47\text{dp}$, Violet `#9D4EDD`, 5 child leaves.
    4. `harmonyNetwork`: Planar $(+165, -85)$, $Y_{\text{root}} \approx 25\text{dp}$, $H_{\text{stipe}} = 90\text{dp} \implies$ Apex $(+165, 115, -85)$, $R_{\text{cap}} = 45\text{dp}$, Emerald `#10B981`, 5 child leaves.
    5. `emotionNetwork`: Planar $(+190, +75)$, $Y_{\text{root}} \approx 21\text{dp}$, $H_{\text{stipe}} = 75\text{dp} \implies$ Apex $(+190, 96, +75)$, $R_{\text{cap}} = 41\text{dp}$, Magenta `#F72585`, 4 child leaves.
    6. `productionNetwork`: Planar $(-35, +155)$, $Y_{\text{root}} \approx 18\text{dp}$, $H_{\text{stipe}} = 64\text{dp} \implies$ Apex $(-35, 82, +155)$, $R_{\text{cap}} = 39\text{dp}$, Aqua `#06D6A0`, 5 child leaves.

### Task 3.2: Riverpod `MyceliumBiomeGraphNotifier` & Bidirectional Studio Entanglement
- **Target File**: `apps/vhunambi_client/lib/features/studio/presentation/providers/mycelium_biome_provider.dart`
- **Method Signatures**:
  ```dart
  class MyceliumBiomeGraphNotifier extends StateNotifier<MusicalDnaGraph> {
    void focusCluster(MyceliumClusterDomain? domain);
    void selectChildLeaf(String? leafId);
    void toggleNetworkLayer(MyceliumNetworkLayer layer);
    void selectSongJourneySection(SongJourneySection section);
    void setGrowthProgress(double progress);
    void toggleCompareMode();
    void toggleAnalyseOverlay();
  }
  ```

---

## 5. Milestone M4: 3D Vertices Mesh Painter, Y-Up Camera, Hit-Testing & Full 5-Deck HUD

### Task 4.1: `BiomeProjectionEngine` & `BiomeCameraNotifier`
- **Target File**: `apps/vhunambi_client/lib/features/studio/presentation/controllers/biome_camera_controller.dart`
- **Specification**:
  - Implement `BiomeProjectionEngine.project3D(Vector3D worldPt, BiomeCameraState camera, Size viewportSize)`.
  - Implement synchronous `BiomeProjectionEngine.hitTest(...)` resolving taps on unfurled child leaves and parent mushroom caps/badges.
  - Enforce pitch clamp $\phi \in [15^\circ, 75^\circ]$ and distance clamp $R \in [180\text{dp}, 650\text{dp}]$.

### Task 4.2: True 3D Mesh CustomPainter (`OrganicMycelium3DPainter`)
- **Target File**: `apps/vhunambi_client/lib/features/studio/presentation/widgets/biome/organic_mycelium_3d_painter.dart`
- **Specification**:
  - Render 5-ring $\times$ 24-segment fluted 3D umbrella cap domes via `ui.Vertices.raw(ui.VertexMode.triangles, ...)` and `canvas.drawVertices(..., BlendMode.plus, _meshPaint)`.
  - Render 32 3D arched under-cap radial lamellae gills + sub-cap core bloom.
  - Render 8-ring curved fibrous hyperboloid stalks rooted at $Y_{\text{root}} = h(X_k, Z_k)$.
  - Render 20$\times$20 3D terrain grid, 72 rootlet tendrils, 15 arterial hyphae, traveling photons, and 16 3D sprout mushrooms.

### Task 4.3: `BiomeClusterInspectorPanel` Right Drawer Widget
- **Target File**: `apps/vhunambi_client/lib/features/studio/presentation/widgets/biome/biome_cluster_inspector_panel.dart`
- **Specification**:
  - Key: `Key('biome_cluster_inspector_panel')`.
  - 32-bar animated live frequency waveform (`Key('biome_inspector_waveform')`), 3 metric readouts (`Intensity %`, `Complexity %`, `Influence %`), related node jump chips (`Key('biome_related_chip_${partner.name}')`), and Studio Cockpit mutator controls.

### Task 4.4: `BiomeTopBar`, `BiomeInteractiveControlsBar` & `BiomeNetworkLayersFilter`
- **Target Files**:
  - `apps/vhunambi_client/lib/features/studio/presentation/widgets/biome/biome_top_bar.dart`
  - `apps/vhunambi_client/lib/features/studio/presentation/widgets/biome/biome_hud_decks.dart`
- **Specification**:
  - `BiomeTopBar` (`Key('biome_top_bar')`) with `Now Playing` capsule (`Key('biome_play_pause_btn')`, `Key('biome_mute_btn')`, `Key('biome_close_btn')`).
  - `BiomeInteractiveControlsBar` (`Key('biome_controls_bar')`) with `Rotate`, `Zoom`, `Focus`, `Compare`, and `Analyse` buttons.
  - `BiomeNetworkLayersFilter` (`Key('biome_network_layers_filter')`) with `Core Elements`, `Supporting Elements`, `Atmosphere`, and `Emotional Layer` toggles.
  - Semantic positioned badge overlays (`Key('biome_cluster_badge_${domain.name}')`) for 100% deterministic widget test tapping and screen-reader accessibility.

---

## 6. Milestone M5: 5-Stage Organic Growth FSM & Song Journey Audio-Reactive Scrubber

### Task 5.1: 5-Stage Organic Growth Animation Controller
- **Target File**: `apps/vhunambi_client/lib/features/studio/presentation/widgets/song_dna_node_tree_modal.dart`
- **Specification**:
  - Drive `growthProgress` $\tau \in [0.0, 1.0]$ across the 5 `BiomeGrowthPhase` stages (`nucleusSeed` $\to$ `primaryNodesEmerge` $\to$ `hyphaeBranching` $\to$ `fruitingBodiesSprout` $\to$ `ecosystemMature`).

### Task 5.2: `SongJourneyTimelineScrubber` Widget
- **Target File**: `apps/vhunambi_client/lib/features/studio/presentation/widgets/biome/song_journey_timeline_scrubber.dart`
- **Specification**:
  - Key: `Key('biome_song_journey_scrubber')`.
  - Interactive section nodes (`Key('biome_section_intro')`, `verse`, `chorus`, `bridge`, `outro`) modulating cluster luminosities and photon velocities.

---

## 7. Milestone M6: Studio Cockpit Integration, Comprehensive Widget Tests & ARM64 APK Verification

### Task 6.1: Upgrade `SongDnaNodeTreeModal` to Sovereign 3D Mycelium Biome Universe
- **Target File**: `apps/vhunambi_client/lib/features/studio/presentation/widgets/song_dna_node_tree_modal.dart`
- **Specification**:
  - Integrate `OrganicMycelium3DPainter`, pointer-isolated gesture handling, semantic mushroom cap badges, `BiomeTopBar`, `BiomeClusterInspectorPanel`, `SongJourneyTimelineScrubber`, `BiomeInteractiveControlsBar`, `BiomeNetworkLayersFilter`, and `[ Synthesize Song ]` CTA while preserving backwards-compatible keys required by existing studio regression tests.

### Task 6.2: Comprehensive Automated Test Suite (`phase53_organic_mycelium_3d_biome_test.dart`)
- **Target File**: `apps/vhunambi_client/test/features/studio/phase53_organic_mycelium_3d_biome_test.dart`
- **Coverage**:
  - Headless domain & Y-Up terrain elevation tests ($Y = h(X, Z) \ge 0$).
  - 6 Mushroom Fruiting Bodies, 15 arterial hyphae, 72 rootlets, and 16 sprout mushrooms verification.
  - Deterministic 3D projection & hit-testing verification (`BiomeProjectionEngine.hitTest`).
  - Widget tests for tapping mushroom badges, opening `BiomeClusterInspectorPanel`, jumping across related node chips, toggling `Network Layers`, toggling `Interactive Controls`, scrubbing `Song Journey` sections, and mutating Studio Cockpit state.
  - Regression pass on Phase 50, 51, and 52 test suites.

---

## 8. Milestone Traceability Matrix

| Requirement ID | Requirement Description | Milestone | Verified By Test |
| :--- | :--- | :--- | :--- |
| **REQ-P53-CORE-01..06** | 6 3D Mushroom Fruiting Bodies (`ui.Vertices` + 32 Gills + Stipe) | M1, M3, M4 | `phase53_organic_mycelium_3d_biome_test.dart` |
| **REQ-P53-MYCEL-01..06** | 15 Arterial Hyphae + 72 Rootlets + 16 3D Sprout Mushrooms | M2, M4 | `phase53_organic_mycelium_3d_biome_test.dart` |
| **REQ-P53-CAM-01..06** | Y-Up Camera, Pointer-Count Isolation & 3D Hit-Testing | M4 | `phase53_organic_mycelium_3d_biome_test.dart` |
| **REQ-P53-GROWTH-01..05**| 5-Stage Biological Growth State Machine | M5 | `phase53_organic_mycelium_3d_biome_test.dart` |
| **REQ-P53-HUD-01..06** | TopBar, Inspector Drawer, Song Journey, Controls & Layers | M4, M5 | `phase53_organic_mycelium_3d_biome_test.dart` |
| **REQ-P53-NFR-01..04** | 60 FPS Budget, Built-in `ui.Vertices` Law & Zero Raw Emojis | M1–M6 | `flutter analyze` & Hardware Profile |


---

## 9. Detailed Engineering Acceptance Checklist & Verification Gates

Before Phase 53 is marked complete in Stage 5 execution, the implementation agent MUST verify every item in the checklist below:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                       STAGE 5 EXECUTION VERIFICATION CHECKLIST                         │
├──────┬─────────────────────────────────────────────────────────────────────────────────┤
│ [x]  │ 1. Zero 2D Oval Lollipops: OrganicMycelium3DPainter uses ui.Vertices.raw        │
│      │    (VertexMode.triangles) for 5-ring x 24-seg fluted 3D mushroom caps.          │
├──────┼─────────────────────────────────────────────────────────────────────────────────┤
│ [x]  │ 2. 32 3D Under-Cap Gills & 8-Ring Hyperboloid Stipes: Every fruiting body       │
│      │    renders 32 arched 3D gill ribs + inner core bloom + fibrous curved stalk.    │
├──────┼─────────────────────────────────────────────────────────────────────────────────┤
│ [x]  │ 3. Dense Mycelium Web & 16 Sprouts: 15 arterial hyphae + 72 branching rootlet   │
│      │    tendrils + 16 3D bioluminescent sprout/pinhead mushrooms on Y = h(X, Z).     │
├──────┼─────────────────────────────────────────────────────────────────────────────────┤
│ [x]  │ 4. Strict Right-Handed 3D Y-Up Space: All 6 clusters root at Y_root = h(X_k,Z_k)│
│      │    and rise along +Y to Y_apex = Y_root + H_stipe.                              │
├──────┼─────────────────────────────────────────────────────────────────────────────────┤
│ [x]  │ 5. Complete 5-Deck HUD: BiomeTopBar, BiomeClusterInspectorPanel,                │
│      │    SongJourneyTimelineScrubber, BiomeInteractiveControlsBar, and                │
│      │    BiomeNetworkLayersFilter are all wired and interactive.                      │
├──────┼─────────────────────────────────────────────────────────────────────────────────┤
│ [x]  │ 6. Deterministic Hit-Testing & Keys: Both BiomeProjectionEngine.hitTest and     │
│      │    semantic keys (`biome_cluster_badge_*`, `biome_related_chip_*`) work 100%.   │
├──────┼─────────────────────────────────────────────────────────────────────────────────┤
│ [x]  │ 7. Authentic Imports & Tokens: Uses `package:vhunambi_client/...`,              │
│      │    `package:phosphor_icons/phosphor_icons.dart`, `AppColors.darkSurfaceElevated`│
│      │    and valid `AppTypography` getters with zero raw emojis.                      │
└──────┴─────────────────────────────────────────────────────────────────────────────────┘
```

### Verification Commands for Stage 5 Execution Agent
1. **Headless & Widget Test Suite**:
   `flutter test test/features/studio/phase53_organic_mycelium_3d_biome_test.dart`
2. **Regression Test Suite across Phases 50–52**:
   `flutter test test/features/studio/phase50_song_dna_quantum_tree_test.dart test/features/studio/phase51_bioluminescent_organelle_3d_test.dart test/features/studio/phase52_macro_canopy_and_stem_lock_test.dart`
3. **Static Analysis Gate**:
   `flutter analyze` (Must report `No issues found!`).
4. **Physical ARM64 Release Build & Deployment**:
   `flutter build apk --release` and install onto Huawei JNY-LX1 (`EPHUT20917014649`).
