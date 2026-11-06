# Engineering Tasks & Milestone Plan: Phase 54 — 2D Studio Cockpit & 3D Mycelium Biome Bi-Directional Quantum Entanglement

This document delineates the step-by-step engineering tasks, architectural milestones (M1–M6), concrete method signatures, target file paths under `apps/vhunambi_client/`, acceptance criteria, and automated verification gates for implementing **Phase 54: 2D Studio Cockpit & 3D Mycelium Biome Bi-Directional Quantum Entanglement ("One Living Musical Organism Across Two Dimensional Planes")**.

---

## 1. Master Milestone Roadmap & Dependency Graph

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              PHASE 54 MILESTONE ROADMAP                                │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ M1: Pure Dart Domain Extensions & Canonical Stem-Lock Dictionary Unification           │
│     ├── CockpitWorkspaceTab enum, studioBranchKey, legacyBranchAliasKey, targetTab     │
│     └──MushroomFruitingBody.liveTelemetrySummary & StudioFormState key parity          │
│                                           ▼                                            │
│ M2: Bi-Directional StudioFormNotifier & Non-Destructive 5-Provider Entanglement Engine │
│     ├── studioCockpitTabProvider, cycleClusterStemLockMode, cycleSonicVibeDice         │
│     └── MyceliumBiomeGraphNotifier.reconcileWithCockpitState() via ref.listen          │
│                                           ▼                                            │
│ M3: 2D Studio Cockpit Quantum Entanglement & Stem Authority Rack (Tab 0)               │
│     ├── CockpitQuantumEntanglementRack (6 Domain Cards + Stem Lock Cycle + 3D Dive)    │
│     └── Sonic Vibe Shuffle Dice button & zero raw emojis in StudioView                 │
│                                           ▼                                            │
│ M4: Inline Groove, Heritage Crate, 8-Pad MPC & 5-Ch Sketchpad Workbench (Tab 2)        │
│     ├── InlineCrateMpcWorkbench (3-Mode Segmented Hardware Rack)                       │
│     └── Inline 8-Pad MPC trigger grid, Crate chop-to-MPC, and Beat Stem Lock toggle    │
│                                           ▼                                            │
│ M5: 3D Biome Inspector Stem-Lock Strip & 3D -> 2D Deep-Link Teleport Router            │
│     ├── BiomeClusterInspectorPanel (biome_inspector_stem_lock_btn + live telemetry)    │
│     └── SongDnaNodeTreeModal (initialFocusedDomain & onExploreDetails tab teleport)    │
│                                           ▼                                            │
│ M6: Comprehensive Automated Test Suite, 5-Phase Regression Gate & ARM64 Release APK    │
│     ├── phase54_cockpit_biome_quantum_entanglement_test.dart (8+ tests)                │
│     └── 100% pass across Phases 50–54, 0 issues on flutter analyze & device install    │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

| Milestone | Description | Target Files (`apps/vhunambi_client/`) | Dependencies | Verification Test Gate |
| :--- | :--- | :--- | :--- | :--- |
| **M1** | Pure Dart Domain & Stem-Lock Key Parity | `lib/features/studio/domain/models/mycelium_biome_models.dart`, `studio_form_state.dart` | None | `M1-DomainKeyParityTest` |
| **M2** | Non-Destructive 5-Provider Entanglement | `lib/features/studio/presentation/providers/studio_form_provider.dart`, `mycelium_biome_provider.dart` | M1 | `M2-NonDestructiveSyncTest` |
| **M3** | 2D Cockpit Quantum Entanglement Rack | `lib/features/studio/presentation/widgets/cockpit_quantum_entanglement_rack.dart` | M1, M2 | `M3-QuantumRackWidgetTest` |
| **M4** | Inline Crate, 8-Pad MPC & Sketchpad Rack | `lib/features/studio/presentation/widgets/inline_crate_mpc_workbench.dart` | M1, M2 | `M4-InlineWorkbenchTest` |
| **M5** | 3D Inspector Stem-Lock & 2D Teleport | `lib/features/studio/presentation/widgets/biome/biome_cluster_inspector_panel.dart`, `song_dna_node_tree_modal.dart`, `studio_view.dart` | M1–M4 | `M5-TeleportAndInspectorTest` |
| **M6** | 5-Phase Automated Test Suite & APK Build | `test/features/studio/phase54_cockpit_biome_quantum_entanglement_test.dart` | M1–M5 | `phase54_cockpit_biome_quantum_entanglement_test.dart` |

---

## 2. Milestone M1: Pure Dart Domain Extensions & Canonical Stem-Lock Dictionary Unification

### Task 1.1: `CockpitWorkspaceTab` & `MyceliumClusterDomain` Entanglement Metadata
- **Target File**: `apps/vhunambi_client/lib/features/studio/domain/models/mycelium_biome_models.dart`
- **Specification**:
  - Add pure Dart `enum CockpitWorkspaceTab { compose, voice, crateAndMpc }` with `.label` getter.
  - Update `MyceliumClusterDomain.studioBranchKey` to map to canonical primary keys (`'node_sketchpad_groove'`, `'node_beat_tempo'`, `'node_vocal_persona'`, `'node_harmony_chords'`, `'node_emotion_mood'`, `'node_spatial_atmosphere'`).
  - Add `String get legacyBranchAliasKey` and `CockpitWorkspaceTab get targetCockpitTab` on `MyceliumClusterDomain`.
  - Add `final String liveTelemetrySummary;` field to `MushroomFruitingBody` and its `copyWith` method.
- **Acceptance Criteria**:
  - Zero `package:flutter` or `dart:ui` imports in `mycelium_biome_models.dart`.

### Task 1.2: Unified Default `branchStemLockModes` in `StudioFormState`
- **Target File**: `apps/vhunambi_client/lib/features/studio/domain/models/studio_form_state.dart`
- **Specification**:
  - Populate default `branchStemLockModes` with all 10 canonical and legacy alias keys so initial lock state is 100% consistent across 2D and 3D views.
  - Replace raw unicode emojis in `StemLockMode.fullLabel` with clean text labels (`'Stem-Locked (Pure 44.1 kHz)'`, `'Guided AI Inpaint'`, `'AI Style Re-Imagine'`).

---

## 3. Milestone M2: Bi-Directional `StudioFormNotifier` & Non-Destructive 5-Provider Entanglement Engine

### Task 2.1: `studioCockpitTabProvider` & Atomic Stem-Lock / Vibe Mutators
- **Target File**: `apps/vhunambi_client/lib/features/studio/presentation/providers/studio_form_provider.dart`
- **Method Signatures**:
  ```dart
  final studioCockpitTabProvider =
      StateProvider<CockpitWorkspaceTab>((ref) => CockpitWorkspaceTab.compose);

  // Inside StudioFormNotifier:
  void setBranchStemLockMode(String branchId, StemLockMode mode);
  void setClusterStemLockMode(MyceliumClusterDomain domain, StemLockMode mode);
  StemLockMode cycleClusterStemLockMode(MyceliumClusterDomain domain);
  void cycleSonicVibeDice();
  ```
- **Acceptance Criteria**:
  - Calling `setBranchStemLockMode('node_beat_tempo', mode)` or `setClusterStemLockMode(MyceliumClusterDomain.rhythmNetwork, mode)` atomically updates both `'node_beat_tempo'` and `'node_branch_beat'` in `StudioFormState.branchStemLockModes`.

### Task 2.2: Non-Destructive `MyceliumBiomeGraphNotifier.reconcileWithCockpitState()`
- **Target File**: `apps/vhunambi_client/lib/features/studio/presentation/providers/mycelium_biome_provider.dart`
- **Specification**:
  - Replace `final formState = ref.watch(studioFormProvider);` in `myceliumBiomeGraphProvider` with `ref.listen` subscriptions across `studioFormProvider`, `melodySketchpadProvider`, `mpcSlicerProvider`, `heritageCrateProvider`, and `vocalIdentityProvider`.
  - Implement `void reconcileWithCockpitState()` to dynamically compute:
    - Normalized domain energy $\mathcal{E}_k$ and complexity $\mathcal{C}_k$ from all 5 providers.
    - Dynamic `stipeHeight`, `capRadius`, `intensityPercent`, `complexityPercent`, `influencePercent`, `isStemLocked`, and `liveTelemetrySummary`.
    - Live child leaves (`MyceliumChildNode`) reflecting active genre, BPM, MPC source title, voice profile, language, LoRA scale, sketchpad instrument/scale, mood, vocal energy, and stem-lock count.
    - Preservation of `focusedDomain`, `selectedChildNodeId`, `activeSection`, `activeLayers`, `isCompareModeActive`, `isAnalyseOverlayActive`, and `_customHarmonyLeaves`.

---

## 4. Milestone M3: 2D Studio Cockpit Quantum Entanglement & Stem Authority Rack

### Task 3.1: Implement `CockpitQuantumEntanglementRack`
- **Target File**: `apps/vhunambi_client/lib/features/studio/presentation/widgets/cockpit_quantum_entanglement_rack.dart`
- **Specification**:
  - Root key: `Key('cockpit_quantum_entanglement_rack')`.
  - Header button: `Key('cockpit_rack_open_3d_biome_btn')`.
  - Renders 6 domain cards (`Key('cockpit_domain_card_${domain.name}')`), each with:
    - Live `intensityPercent` badge and `liveTelemetrySummary`.
    - 1-tap Stem Lock cycle button (`Key('cockpit_stem_lock_${domain.name}')`).
    - 1-tap 3D Cluster Dive button (`Key('cockpit_jump_3d_${domain.name}')`) opening `SongDnaNodeTreeModal` focused on `domain`.

---

## 5. Milestone M4: Inline Groove, Heritage Crate, 8-Pad MPC & Sketchpad Workbench

### Task 4.1: Implement `InlineCrateMpcWorkbench`
- **Target File**: `apps/vhunambi_client/lib/features/studio/presentation/widgets/inline_crate_mpc_workbench.dart`
- **Specification**:
  - Root key: `Key('cockpit_inline_crate_mpc_workbench')`.
  - Beat Stem Lock toggle: `Key('workbench_lock_beat_btn')`.
  - 3 segmented mode tabs: `Key('workbench_mode_crate')`, `Key('workbench_mode_mpc')`, `Key('workbench_mode_sketchpad')`.
  - Inline 8-Pad MPC grid (`Key('workbench_mpc_pad_0')` .. `Key('workbench_mpc_pad_7')`), inline Crate sample list with `Chop to MPC` actions (`Key('workbench_chop_sample_${sample.id}')`), and 5-Channel Sketchpad summary with `Key('workbench_open_sketchpad_btn')`.

---

## 6. Milestone M5: 3D Inspector Stem-Lock Strip, Deep-Link Teleport & `StudioView` Wiring

### Task 5.1: Wire `BiomeClusterInspectorPanel` Stem-Lock & Telemetry
- **Target File**: `apps/vhunambi_client/lib/features/studio/presentation/widgets/biome/biome_cluster_inspector_panel.dart`
- **Specification**:
  - Render `cluster.liveTelemetrySummary` and interactive Stem-Lock control (`Key('biome_inspector_stem_lock_btn')`) wired to `onToggleStemLock`.

### Task 5.2: Wire `SongDnaNodeTreeModal` Initial Focus & `onExploreDetails` Teleport
- **Target File**: `apps/vhunambi_client/lib/features/studio/presentation/widgets/song_dna_node_tree_modal.dart`
- **Specification**:
  - Add `final MyceliumClusterDomain? initialFocusedDomain;` to `SongDnaNodeTreeModal` and `SongDnaNodeTreeModal.show(...)`.
  - Wire `onExploreDetails` on `BiomeClusterInspectorPanel` to update `studioCockpitTabProvider` to `activeDomain.targetCockpitTab` and pop the modal back to `StudioView`.

### Task 5.3: Wire `StudioView` to `studioCockpitTabProvider`, Quantum Rack & Inline Workbench
- **Target File**: `apps/vhunambi_client/lib/features/studio/presentation/views/studio_view.dart`
- **Specification**:
  - Bind `_modeSwitcher()` to `studioCockpitTabProvider` with keys `Key('cockpit_tab_compose')`, `Key('cockpit_tab_voice')`, `Key('cockpit_tab_crateAndMpc')`.
  - Replace raw unicode emoji in `_DnaSuggestionChip` with `PhosphorIcon(PhosphorIconsBold.dna)` and add Sonic Vibe Shuffle Dice button (`Key('cockpit_sonic_vibe_dice_btn')`).
  - Embed `CockpitQuantumEntanglementRack` in Tab 0 (`Compose`) and `InlineCrateMpcWorkbench` in Tab 2 (`Crate & MPC`).

---

## 7. Milestone M6: Automated Test Suite, 5-Phase Regression Gate & ARM64 Release APK

### Task 6.1: Author `phase54_cockpit_biome_quantum_entanglement_test.dart`
- **Target File**: `apps/vhunambi_client/test/features/studio/phase54_cockpit_biome_quantum_entanglement_test.dart`
- **Test Cases**:
  1. Canonical & legacy stem-lock key parity across `StudioFormState`, `SongDnaGraphNotifier`, and `MyceliumBiomeGraphNotifier`.
  2. Non-destructive 5-provider reconciliation preserves `focusedDomain`, `activeSection`, `activeLayers`, and custom instrument leaves when 2D state mutates.
  3. Live 2D $\to$ 3D child leaf and telemetry morphing (changing genre, tempo, voice profile, language, MPC slices, and sketchpad steps updates 3D fruiting body heights, radii, percentages, and leaf labels).
  4. `CockpitQuantumEntanglementRack` renders 6 domain cards, cycles stem lock modes in-place, and launches 3D Biome focused on the tapped cluster.
  5. `BiomeClusterInspectorPanel` renders `biome_inspector_stem_lock_btn`, toggles stem lock without losing cluster focus, and `biome_explore_details_btn` teleports `StudioView` to the target `CockpitWorkspaceTab`.
  6. `InlineCrateMpcWorkbench` switches across Crate, 8-Pad MPC, and 5-Ch Sketchpad modes, slices crate samples into MPC pads, and toggles Beat Stem Lock.
  7. Sonic Vibe Shuffle Dice (`cockpit_sonic_vibe_dice_btn`) cycles curated African DNA presets and updates both 2D and 3D states.

---

## 8. Stage 4 Execution Verification Checklist

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                       STAGE 4 EXECUTION VERIFICATION CHECKLIST                         │
├──────┬─────────────────────────────────────────────────────────────────────────────────┤
│ [ ]  │ 1. Non-Destructive Reconciliation: Mutating 2D state never resets               │
│      │    `focusedDomain`, `activeSection`, `activeLayers`, or custom leaves in 3D.    │
├──────┼─────────────────────────────────────────────────────────────────────────────────┤
│ [ ]  │ 2. Canonical Key Parity: `node_beat_tempo` <-> `node_branch_beat` and all       │
│      │    6 cluster stem-lock keys stay 100% synchronized across 2D and 3D.            │
├──────┼─────────────────────────────────────────────────────────────────────────────────┤
│ [ ]  │ 3. Dynamic 2D -> 3D Telemetry: Fruiting body heights, radii, %, and child       │
│      │    leaves dynamically reflect live Prompt, Genre, BPM, MPC, Sketchpad & Voice.  │
├──────┼─────────────────────────────────────────────────────────────────────────────────┤
│ [ ]  │ 4. 2D Quantum Rack & 3D Dive: `CockpitQuantumEntanglementRack` cycles locks     │
│      │    and deep-links into specific 3D mushroom clusters.                           │
├──────┼─────────────────────────────────────────────────────────────────────────────────┤
│ [ ]  │ 5. 3D Inspector Stem-Lock & Teleport: `biome_inspector_stem_lock_btn` and       │
│      │    `biome_explore_details_btn` are wired and tested.                            │
├──────┼─────────────────────────────────────────────────────────────────────────────────┤
│ [ ]  │ 6. Inline Crate & MPC Workbench: `InlineCrateMpcWorkbench` is live on Tab 2     │
│      │    with zero raw unicode emojis (`STD-UIUX-001`).                               │
├──────┼─────────────────────────────────────────────────────────────────────────────────┤
│ [ ]  │ 7. Full 5-Phase Regression Suite & Analyzer: Phases 50–54 tests pass 100%       │
│      │    and `flutter analyze` reports `No issues found!`.                            │
└──────┴─────────────────────────────────────────────────────────────────────────────────┘
```

### Verification Commands for Stage 4 Execution Agent
1. **Phase 54 Test Suite**:
   `cd apps/vhunambi_client; flutter test test/features/studio/phase54_cockpit_biome_quantum_entanglement_test.dart`
2. **Full 5-Phase Studio Regression Suite (Phases 50–54)**:
   `cd apps/vhunambi_client; flutter test test/features/studio/phase50_quantum_song_dna_3d_tree_test.dart test/features/studio/phase51_bioluminescent_organelle_3d_test.dart test/features/studio/phase52_macro_organelle_and_stem_lock_test.dart test/features/studio/phase53_organic_mycelium_3d_biome_test.dart test/features/studio/phase54_cockpit_biome_quantum_entanglement_test.dart`
3. **Static Analysis Gate**:
   `cd apps/vhunambi_client; flutter analyze lib/features/studio test/features/studio/phase54_cockpit_biome_quantum_entanglement_test.dart`
4. **Physical ARM64 Release Build & Deployment**:
   `cd apps/vhunambi_client; flutter build apk --release --target-platform android-arm64`
   Install onto Huawei JNY-LX1 (`EPHUT20917014649`).

