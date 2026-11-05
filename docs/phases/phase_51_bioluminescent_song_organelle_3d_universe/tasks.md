# Phase 51: Implementation Tasks & Verification Matrix

## Task Checklist

### Track A: Hardware Forensic Bug Fixes
- [ ] **TASK-P51-A1:** Update `InteractiveIdentityCardStack` in `interactive_identity_card_stack.dart`: sort card stack children by `relativeDepth` descending so `_activeIndex` is always the final child rendered at the top of the `Stack`. Ensure opaque card fill.
- [ ] **TASK-P51-A2:** In `onboarding_act1_showcase.dart`, expand clearance between subtitle and 4 showcase pills to `18dp`, add `Curves.easeOutCubic` slide transition on entrance.
- [ ] **TASK-P51-A3:** In `song_dna_node_tree_modal.dart`, configure route as 100% opaque full-screen surface (`#020813` to `#041424`), suppress `MiniPlayerHost`. In `melody_sketchpad_modal.dart`, verify 100% opaque surface fill.
- [ ] **TASK-P51-A4:** In `song_dna_node_tree_modal.dart`, wire `Key('song_dna_synthesize_btn')` to call `generationProgressProvider.notifier.submitAndStartGeneration(...)` and `studioFormProvider.notifier.triggerGeneration()`. Wrap CTA label in `FittedBox` to prevent two-line wrapping.

### Track B & C: Sovereign 3D Bioluminescent Organelle Environment
- [ ] **TASK-P51-BC1:** Implement `_Organelle3DBackdropPainter` with abyssal void radial gradient, 4 blurred depth-of-field bokeh satellite organelles, and subtle holographic bio-telemetry horizon lines.
- [ ] **TASK-P51-BC2:** Implement `_OrganelleCellularPainter` with deformable 3D geodesic cyan filamentous membrane mesh ($8\times 14 = 112$ vertices) displaced by 3D harmonic wave mathematics with Fresnel rim lighting.
- [ ] **TASK-P51-BC3:** Implement inner blazing amber nucleus with 4 internal vesicles and curved 3D cubic-Bézier neural filaments pulsing at song BPM.

### Track D: Multi-Jointed Molecular Dendrite Chains & Decluttered HUD
- [ ] **TASK-P51-D1:** Expand `song_dna_graph_models.dart` and `song_dna_graph_provider.dart` to support 4 multi-jointed dendrite arms with 24+ interactive sub-nodes and receptors.
- [ ] **TASK-P51-D2:** Render nodes as stippled bioluminescent 3D spheres surrounded by precision outer rings (`◎`), with glowing bond tubes and photon particles.
- [ ] **TASK-P51-D3:** Replace giant overlapping rectangular pills with decluttered holographic micro-tags and thin leader lines. Keep all `Key('song_dna_bubble_${node.id}')` accessible for touch and test hit-testing.
- [ ] **TASK-P51-D4:** Implement 6-DOF camera controls: 1-finger orbit, 2-finger pan/zoom, tap-to-focus dive, and camera reset button.

### Track E: Verification Gates & Hardware Deployment
- [ ] **TASK-P51-E1:** Update existing tests (`phase50_quantum_song_dna_3d_tree_test.dart`, `phase49_mmorpg_dna_and_generation_onboarding_test.dart`) and author `test/features/studio/phase51_bioluminescent_organelle_3d_test.dart`.
- [ ] **TASK-P51-E2:** Update `docs/AGENT_HANDOFF_BIBLE.md` with Phase 48, 49, 50, and 51 records.
- [ ] **TASK-P51-E3:** Verify `dart analyze` reports **0 issues**.
- [ ] **TASK-P51-E4:** Verify all tests pass (100% green).
- [ ] **TASK-P51-E5:** Build release ARM64 APK, stream install to `EPHUT20917014649`, launch, commit and push to Git.

