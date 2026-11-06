# Phase 54 Requirements Specification: 2D Studio Cockpit & 3D Mycelium Biome Bi-Directional Quantum Entanglement

- **Phase Identifier**: `phase_54_cockpit_biome_quantum_entanglement`
- **Target Application**: `apps/vhunambi_client`
- **Architecture Blueprint**: [`docs/phases/phase_54_cockpit_biome_quantum_entanglement/blueprint.md`](./blueprint.md)
- **Parent Audit Reference**: [`docs/audits/STUDIO_COCKPIT_AND_2D_SONG_CREATION_FLOW_AUDIT.md`](../../audits/STUDIO_COCKPIT_AND_2D_SONG_CREATION_FLOW_AUDIT.md)

---

## 1. Document Scope, Coordinate Standard & EARS / RFC-2119 Conventions

### 1.1 Scope
This document specifies the functional, mathematical, state-synchronization, and non-functional requirements for **Phase 54: 2D Studio Cockpit & 3D Mycelium Biome Bi-Directional Quantum Entanglement**. It governs how the 2D Studio Cockpit (`StudioView`, `StudioFormNotifier`, `MelodySketchpadNotifier`, `MpcSlicerNotifier`, `HeritageCrateNotifier`, `VocalIdentityNotifier`) and the 3D Organic Mycelium Biome (`MyceliumBiomeGraphNotifier`, `SongDnaNodeTreeModal`, `BiomeClusterInspectorPanel`) synchronize state, stem locks, child node telemetry, and deep-link navigation in real time.

### 1.2 Coordinate System Convention
All 3D spatial coordinates and fruiting body elevations in this specification strictly obey **Right-Handed 3D Y-Up World Space**:
- **$X$-Axis**: Lateral horizontal axis ($+X$ right, $-X$ left).
- **$Y$-Axis**: Vertical elevation axis ($+Y$ upward toward canopy apex, $Y_{\text{root}} = h(X, Z) \ge 0$ rooted on the contoured terrain surface).
- **$Z$-Axis**: Depth axis ($+Z$ foreground toward camera, $-Z$ background depth).
- **Screen Projection**: Positive $+Y$ world elevation projects upward on screen ($Y_{\text{screen}} = H/2 - y_{\text{eye}} \cdot \text{scale}$).

### 1.3 EARS & RFC-2119 Requirement Syntax
Every requirement in this specification uses the **Easy Approach to Requirements Syntax (EARS)** paired with **RFC-2119** normative keywords (`SHALL`, `MUST`, `SHOULD`, `MAY`):
- **Ubiquitous**: `The <system> SHALL <response>.`
- **Event-Driven**: `WHEN <trigger>, the <system> SHALL <response>.`
- **State-Driven**: `WHILE <state>, the <system> SHALL <response>.`
- **Unwanted Behavior**: `IF <condition>, THEN the <system> SHALL <response>.`

---

## 2. Canonical Stem Authority & Non-Destructive Entanglement Requirements (`REQ-P54-SYNC-*`)

### `REQ-P54-SYNC-01`: Non-Destructive Multi-Provider Entanglement Listener
- **Statement**: `WHEN` `myceliumBiomeGraphProvider` is initialized in Riverpod, the provider factory `SHALL` instantiate `MyceliumBiomeGraphNotifier` once and attach non-destructive `ref.listen` subscriptions to `studioFormProvider`, `melodySketchpadProvider`, `mpcSlicerProvider`, `heritageCrateProvider`, and `vocalIdentityProvider` rather than calling `ref.watch(studioFormProvider)`.
- **State Preservation Invariant**: `WHEN` any 2D Studio parameter or stem lock is mutated while a 3D cluster is focused (`focusedDomain != null`), `MyceliumBiomeGraphNotifier.reconcileWithCockpitState(...)` `SHALL` update cluster heights, radii, metrics, stem locks, and child leaves in-place while strictly preserving `focusedDomain`, `selectedChildNodeId`, `activeSection`, `activeLayers`, `isCompareModeActive`, `isAnalyseOverlayActive`, and user-added custom instrument leaves.

### `REQ-P54-SYNC-02`: Unified Canonical & Legacy Stem-Lock Key Dictionary
- **Statement**: The system `SHALL` unify stem-lock authority keys across `MyceliumClusterDomain`, `StudioFormState.branchStemLockModes`, and `SongDnaGraphNotifier` using the canonical mapping below:
  1. `MyceliumClusterDomain.melodyCore` $\longleftrightarrow$ primary `'node_sketchpad_groove'`, alias `'node_branch_instruments'` (Default: `StemLockMode.lockedPure44k`).
  2. `MyceliumClusterDomain.rhythmNetwork` $\longleftrightarrow$ primary `'node_beat_tempo'`, alias `'node_branch_beat'` (Default: `StemLockMode.lockedPure44k`).
  3. `MyceliumClusterDomain.vocalNetwork` $\longleftrightarrow$ primary `'node_vocal_persona'`, alias `'node_branch_vocal'` (Default: `StemLockMode.harmonicInpaint`).
  4. `MyceliumClusterDomain.harmonyNetwork` $\longleftrightarrow$ primary `'node_harmony_chords'`, alias `'node_sketchpad_groove'` (Default: `StemLockMode.lockedPure44k`).
  5. `MyceliumClusterDomain.emotionNetwork` $\longleftrightarrow$ primary `'node_emotion_mood'`, alias `'node_vocal_persona'` (Default: `StemLockMode.harmonicInpaint`).
  6. `MyceliumClusterDomain.productionNetwork` $\longleftrightarrow$ primary `'node_spatial_atmosphere'`, alias `'node_branch_sfx'` (Default: `StemLockMode.harmonicInpaint`).
- **Bi-Directional Write Guarantee**: `WHEN` `setBranchStemLockMode(branchId, mode)` or `setClusterStemLockMode(domain, mode)` is called, `StudioFormNotifier` `SHALL` synchronize both the primary key and its alias key so that 2D Cockpit widgets, 3D Mycelium clusters, and Phase 52 Quick-Action Cards read identical `StemLockMode` states at all times.

### `REQ-P54-SYNC-03`: Live 2D-to-3D Child Leaf Telemetry Synthesis
- **Statement**: `WHEN` `MyceliumBiomeGraphNotifier` builds or reconciles the 6 `MushroomFruitingBody` clusters, the child leaves (`List<MyceliumChildNode>`) `SHALL` dynamically reflect the live 2D Cockpit state rather than static hardcoded strings:
  - **`melodyCore`**: Leaf `node_mel_lead_hook` reflects `melodySketchpadProvider.activePattern.instrument.label` and active lead step count; leaf `node_mel_call_response` reflects prompt summary or `'Bantu ancestral phrase duality'`.
  - **`rhythmNetwork`**: Leaf `node_rhy_log_drum` reflects `${form.genre} Log-Drum` (or `${mpcSlicer.sourceTitle}` when chopped); leaf `node_rhy_tempo_pocket` reflects `${form.tempo.label}` and `${mpcSlicer.bpm} BPM`.
  - **`vocalNetwork`**: Leaf `node_vox_timbre_elder` reflects `form.selectedVoiceProfile.name` (or `vocalIdentity.activeVoiceDisplayLabel` when cloned); leaf `node_vox_linguistic_dialect` reflects `${form.language} Dialect`; leaf `node_vox_lora_weight` reflects `LoRA Adaptation ${(form.selectedVoiceProfile.loraScale * 100).round()}%`.
  - **`harmonyNetwork`**: Leaf `node_harm_rhodes_chords` reflects active chords/instrument configuration; leaf `node_harm_bantu_scale` reflects `${sketchpad.activePattern.rootKey} ${sketchpad.activePattern.scale.label}`.
  - **`emotionNetwork`**: Leaf `node_emo_soulful_warmth` reflects `form.mood` and `Vocal ${form.vocalEnergy.name.toUpperCase()}`; leaf `node_emo_energy_surge` reflects `form.songStructure.name.toUpperCase()` arrangement.
  - **`productionNetwork`**: Leaf `node_prod_stem_lock_pure` reflects the current `StemLockMode.displayName` and locked cluster count (`$lockedCount/6 Stems Locked`).

### `REQ-P54-SYNC-04`: Parametric 3D Fruiting Body Morphing & Inspector Percentages
- **Statement**: `WHEN` 2D Cockpit parameters change, `MyceliumBiomeGraphNotifier` `SHALL` recompute each cluster's normalized energy $\mathcal{E}_k \in [0.30, 1.0]$ and complexity $\mathcal{C}_k \in [0.40, 1.0]$ to morph:
  - `stipeHeight`: $H_{\text{stipe}, k} = H_{\text{base}, k} \cdot (0.82 + 0.28 \mathcal{E}_k)$ along $+Y$ above $Y_{\text{root}, k} = h(X_k, Z_k)$.
  - `capRadius`: $R_{\text{cap}, k} = R_{\text{base}, k} \cdot (0.85 + 0.22 \mathcal{E}_k)$.
  - `intensityPercent`, `complexityPercent`, and `influencePercent` in $[30, 99]\%$.

---

## 3. 2D Studio Cockpit Quantum Entanglement Rack Requirements (`REQ-P54-RACK-*`)

### `REQ-P54-RACK-01`: `CockpitQuantumEntanglementRack` on Compose Tab
- **Statement**: The `StudioView` Compose tab (`CockpitWorkspaceTab.compose`) `SHALL` render the `CockpitQuantumEntanglementRack` widget (`Key('cockpit_quantum_entanglement_rack')`) displaying all 6 entangled Mycelium domains (`melodyCore`, `rhythmNetwork`, `vocalNetwork`, `harmonyNetwork`, `emotionNetwork`, `productionNetwork`).

### `REQ-P54-RACK-02`: Per-Domain Live Telemetry, Stem-Lock Cycle & 3D Dive Controls
- **Statement**: Each domain card inside `CockpitQuantumEntanglementRack` (`Key('cockpit_domain_card_${domain.name}')`) `SHALL` display:
  1. The domain title, signature bioluminescent accent color, and live `intensityPercent` badge.
  2. A 1-line live 2D telemetry summary (e.g., `'Amapiano • Medium (112-115 BPM)'`, `'Venda Folk Elder • English'`).
  3. An interactive Stem Authority pill (`Key('cockpit_stem_lock_${domain.name}')`) that cycles through `StemLockMode.lockedPure44k` $\to$ `StemLockMode.harmonicInpaint` $\to$ `StemLockMode.elasticResynth` on tap.
  4. A 1-tap 3D Cluster Dive button (`Key('cockpit_jump_3d_${domain.name}')`) that opens `SongDnaNodeTreeModal` pre-focused onto that exact 3D mushroom fruiting body (`focusedDomain == domain`).

### `REQ-P54-RACK-03`: Sonic Vibe Shuffle Dice in DNA Suggestion Header
- **Statement**: The Studio Compose tab `SHALL` provide a 1-tap Sonic Vibe Shuffle button (`Key('cockpit_sonic_vibe_dice_btn')`) using `PhosphorIconsBold.diceFive` (zero raw unicode emojis) that cycles through curated African DNA presets (`Private School Piano`, `Durban Dark Gqom`, `Venda Traditional Soul`, `Lagos Afro-Pop`) and immediately synchronizes both the 2D form and the 3D Mycelium Biome.

---

## 4. 3D Inspector Stem-Lock & 3D $\to$ 2D Deep-Link Teleportation (`REQ-P54-TELE-*`)

### `REQ-P54-TELE-01`: Interactive Stem Authority Strip in `BiomeClusterInspectorPanel`
- **Statement**: `BiomeClusterInspectorPanel` `SHALL` render an interactive Stem Authority control button (`Key('biome_inspector_stem_lock_btn')`) displaying the active `StemLockMode` (`Lock Pure 44.1k`, `Guided Inpaint`, or `AI Re-Imagine`) for the inspected cluster and invoking `onToggleStemLock` when tapped.

### `REQ-P54-TELE-02`: Riverpod-Driven 2D Cockpit Tab State (`studioCockpitTabProvider`)
- **Statement**: The active tab of `StudioView` (`CockpitWorkspaceTab.compose`, `CockpitWorkspaceTab.voice`, `CockpitWorkspaceTab.crateAndMpc`) `SHALL` be managed by `studioCockpitTabProvider` (`StateProvider<CockpitWorkspaceTab>`) so that both 2D tab buttons (`Key('cockpit_tab_compose')`, `Key('cockpit_tab_voice')`, `Key('cockpit_tab_crateAndMpc')`) and 3D deep-link actions can deterministically read and switch the active 2D workspace tab.

### `REQ-P54-TELE-03`: 3D $\to$ 2D Deep-Link Teleportation on `onExploreDetails`
- **Statement**: `WHEN` the user taps the `Explore Details` button (`Key('biome_explore_details_btn')`) inside `BiomeClusterInspectorPanel`, the system `SHALL`:
  1. Map the active `MyceliumClusterDomain` to its target `CockpitWorkspaceTab`:
     - `melodyCore`, `emotionNetwork`, `productionNetwork` $\longrightarrow$ `CockpitWorkspaceTab.compose`
     - `vocalNetwork` $\longrightarrow$ `CockpitWorkspaceTab.voice`
     - `rhythmNetwork`, `harmonyNetwork` $\longrightarrow$ `CockpitWorkspaceTab.crateAndMpc`
  2. Update `studioCockpitTabProvider` to the target tab, select the corresponding legacy branch node in `songDnaGraphProvider` so in-modal quick actions remain synchronized, and if `closeModalOnExplore` is triggered or requested, return the user directly to the target 2D Cockpit surface.

---

## 5. Inline Crate, 8-Pad MPC & Sketchpad Workbench on Tab 2 (`REQ-P54-WORK-*`)

### `REQ-P54-WORK-01`: `InlineCrateMpcWorkbench` on Tab 2 (`Crate & MPC`)
- **Statement**: Tab 2 (`CockpitWorkspaceTab.crateAndMpc`) of `StudioView` `SHALL` render `InlineCrateMpcWorkbench` (`Key('cockpit_inline_crate_mpc_workbench')`) directly inline beneath the existing `studio_daw_uploader_btn` and `studio_open_crate_btn` action buttons (preserving 100% backward compatibility with existing widget tests).

### `REQ-P54-WORK-02`: 3-Mode Segmented Hardware Rack (`Crate`, `8-Pad MPC`, `5-Ch Sketchpad`)
- **Statement**: `InlineCrateMpcWorkbench` `SHALL` provide 3 segmented mode tabs:
  1. `Key('workbench_mode_crate')`: Inline Heritage Crate sample selector with 1-tap `Chop into MPC` action.
  2. `Key('workbench_mode_mpc')`: Inline 8-Pad MPC transient trigger grid (`Key('workbench_mpc_pad_0')` .. `Key('workbench_mpc_pad_7')`), time-stretch readout, and 1-tap Beat Stem Lock toggle (`Key('workbench_lock_beat_btn')`).
  3. `Key('workbench_mode_sketchpad')`: Inline 5-Channel Groove summary card showing active channels (`Lead`, `Chords`, `Bass`, `Drums`, `Hats`), active scale/key, and a 1-tap launcher (`Key('workbench_open_sketchpad_btn')`) for `MelodySketchpadModal`.

---

## 6. Non-Functional & Governance Requirements (`REQ-P54-NFR-*`)

### `REQ-P54-NFR-01`: 60 FPS Frame Budget & Zero Allocation During Reconciliation
- **Statement**: Reconciling the 6-cluster `MusicalDnaGraph` on 2D form edits `SHALL` execute in $\le 1.5\text{ms}$ on mobile ARM64 without dropping below 60 FPS ($\le 16.6\text{ms}$ per frame).

### `REQ-P54-NFR-02`: Zero Raw Emojis Law (`STD-UIUX-001`)
- **Statement**: All newly authored or updated widgets (`StudioView`, `_DnaSuggestionChip`, `CockpitQuantumEntanglementRack`, `InlineCrateMpcWorkbench`, `BiomeClusterInspectorPanel`) `SHALL` use `PhosphorIcon(PhosphorIconsBold.*)` and `SHALL NOT` contain raw unicode emojis.

### `REQ-P54-NFR-03`: 100% Regression Compatibility Across Phases 50–53
- **Statement**: All existing widget keys and behavioral contracts tested in `phase50_quantum_song_dna_3d_tree_test.dart`, `phase51_bioluminescent_organelle_3d_test.dart`, `phase52_macro_organelle_and_stem_lock_test.dart`, and `phase53_organic_mycelium_3d_biome_test.dart` `SHALL` remain 100% green.

---

## 7. Granular Requirement-to-Test Traceability Matrix

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                  PHASE 54 REQUIREMENT-TO-TEST TRACEABILITY MATRIX                      │
├──────────────────────┬───────────────────────────────────┬─────────────────────────────┤
│ Requirement ID       │ Target Implementation File        │ Automated Verification Test │
├──────────────────────┼───────────────────────────────────┼─────────────────────────────┤
│ REQ-P54-SYNC-01      │ mycelium_biome_provider.dart      │ Test 1: Non-destructive     │
│                      │                                   │ focus & layer retention     │
├──────────────────────┼───────────────────────────────────┼─────────────────────────────┤
│ REQ-P54-SYNC-02      │ studio_form_state.dart            │ Test 2: Canonical & alias   │
│                      │ studio_form_provider.dart         │ stem-lock key parity        │
├──────────────────────┼───────────────────────────────────┼─────────────────────────────┤
│ REQ-P54-SYNC-03      │ mycelium_biome_provider.dart      │ Test 3: Live 2D -> 3D child │
│                      │                                   │ leaf & telemetry sync       │
├──────────────────────┼───────────────────────────────────┼─────────────────────────────┤
│ REQ-P54-SYNC-04      │ mycelium_biome_provider.dart      │ Test 4: Parametric stipe    │
│                      │                                   │ height, cap radius & %      │
├──────────────────────┼───────────────────────────────────┼─────────────────────────────┤
│ REQ-P54-RACK-01..03  │ cockpit_quantum_entanglement_     │ Test 5: 2D Quantum Rack     │
│                      │ rack.dart & studio_view.dart      │ stem-lock cycle & 3D dive   │
├──────────────────────┼───────────────────────────────────┼─────────────────────────────┤
│ REQ-P54-TELE-01..03  │ biome_cluster_inspector_panel.dart│ Test 6: 3D Inspector stem   │
│                      │ song_dna_node_tree_modal.dart     │ lock & 2D tab teleport      │
├──────────────────────┼───────────────────────────────────┼─────────────────────────────┤
│ REQ-P54-WORK-01..02  │ inline_crate_mpc_workbench.dart   │ Test 7: Inline Crate, 8-Pad │
│                      │ studio_view.dart                  │ MPC & Sketchpad workbench   │
├──────────────────────┼───────────────────────────────────┼─────────────────────────────┤
│ REQ-P54-NFR-01..03   │ All Phase 50–54 Studio files      │ Full 5-Phase Test Suite +   │
│                      │                                   │ flutter analyze (0 issues)  │
└──────────────────────┴───────────────────────────────────┴─────────────────────────────┘
```

