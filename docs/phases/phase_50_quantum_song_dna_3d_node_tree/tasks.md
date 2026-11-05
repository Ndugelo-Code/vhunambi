# Phase 50 Tasks: Quantum-Entangled 3D Song DNA Node Tree & Hovering Cockpit Pill

## Pre-Flight Verification
- [x] Phase 49 committed (`ba8101b`) and pushed to `origin/fix/studio-cockpit-bugs-vh001-vh006`.
- [x] `flutter analyze` reports `No issues found!`.
- [x] All 12 onboarding and motion tests green.

---

## Track A: Living 3D Hover Pill & Mini-Player Clearance

### T1.1 Create `SongDnaHoverPill`
- [ ] Create `apps/vhunambi_client/lib/features/studio/presentation/widgets/song_dna_hover_pill.dart` with `Key('studio_song_dna_hover_pill')`.
- [ ] Implement vertical sine levitation ($\pm 2.5\text{dp}$, `2.6s`), 3D specular rim highlight, soft shadow, and micro-particle halo.
- [ ] Wire multi-spectrum glow: Amber (Beat), Cyan (Vocal), Emerald (Instruments), Electric Violet (Invasive).
- [ ] On tap: trigger `HapticFeedback.mediumImpact()` and present `SongDnaNodeTreeModal`.

### T1.2 Replace Static Badge in `ProgressTrackerWidget`
- [ ] In `apps/vhunambi_client/lib/features/studio/presentation/widgets/progress_tracker.dart`, replace the static `DNA XX%` chip with `SongDnaHoverPill`.

### T1.3 Fix Mini-Player Clearance in `StudioView`
- [ ] Update `StudioView` and `MiniPlayerController` to ensure the mini-player never obscures `StudioActionBar`.

---

## Track B: Quantum-Entangled Graph State & 4-Class Taxonomy

### T2.1 Define Domain Models
- [ ] Create `apps/vhunambi_client/lib/features/studio/domain/models/song_dna_graph_models.dart`:
  - `SongDnaNodeCategory` (`beatCore`, `vocalLyrics`, `instrumentsHarmony`, `invasiveThirdParty`).
  - `Vector3D`, `SongDnaSubNode`, `SongDnaNode`.
  - `SongDnaGraphState`.

### T2.2 Create `SongDnaGraphNotifier` & Provider
- [ ] Create `apps/vhunambi_client/lib/features/studio/presentation/providers/song_dna_graph_provider.dart`:
  - Listen to `studioFormProvider`, `vocalIdentityProvider`, `melodySketchpadProvider`, and `stemRemixProvider`.
  - Compute active nodes, branch progress, and glow color.
  - Expose mutations: `updateGenre`, `updateTempo`, `updateVocalPersona`, `updateLanguage`, `updateLyrics`, `updateMood`, `detachInvasiveNode`.

---

## Track C: Full-Screen 3D Navigable Node Tree & Floating Cue Bubbles

### T3.1 Create `SongDnaNodeTreeModal`
- [ ] Create `apps/vhunambi_client/lib/features/studio/presentation/widgets/song_dna_node_tree_modal.dart` with `Key('song_dna_3d_tree_modal')`.
- [ ] Implement 3D spherical camera orbit drag (Yaw & Pitch) with inertia damping.
- [ ] Add camera HUD buttons: `Key('song_dna_zoom_in_btn')`, `Key('song_dna_zoom_out_btn')`, `Key('song_dna_reset_camera_btn')`.
- [ ] Implement `_SongDna3DPainter` with depth sorting, flowing energy conduits, and symbiotic lightning tethers for invasive nodes.

### T3.2 Implement Floating Billboarded Cue Bubbles
- [ ] Render interactive Cue Bubbles (`Key('song_dna_bubble_${node.id}')`) anchored 28dp above each node.
- [ ] Tap on bubble or node focuses camera and opens Quick-Action Card.

---

## Track D: Sleek Quick-Action Mutation Cards & Quantum Entanglement

### T4.1 Implement Quick-Action Mutation Card
- [ ] In `song_dna_node_tree_modal.dart`, render `Key('song_dna_quick_action_card')`:
  - For `node_genre_tempo`: Instant genre chips + tempo bracket pills.
  - For `node_vocal_persona`: Regional voice archetype selector + clone trigger.
  - For `node_language_lyrics`: Language chips + lyrics mode toggle.
  - For `node_mood_energy`: Mood & vocal energy pills.
  - For `node_sketchpad_groove`: Additive 5-channel satellite sub-nodes + preset attach.
  - For invasive nodes: Detach button `Key('song_dna_detach_node_btn')`.
  - Sticky CTA: `[ ⚡ Synthesize Song from 3D DNA ]` (`Key('song_dna_synthesize_btn')`).

### T4.2 Verify Bi-Directional Quantum Entanglement
- [ ] Mutations inside the 3D tree immediately update `studioFormProvider`, `vocalIdentityProvider`, `melodySketchpadProvider`.

---

## Track E: Verification Gates & Hardware Deployment

### T5.1 Author Phase 50 Test Suite
- [ ] Create `apps/vhunambi_client/test/features/studio/phase50_quantum_song_dna_3d_tree_test.dart` testing:
  - `SongDnaHoverPill` renders and opens modal on tap.
  - All 4 node categories render with cue bubbles and branch progress.
  - Quantum Entanglement round-trip (mutations in 3D modal update studio form).
  - Invasive node detachment dissolves node.

### T5.2 Static Analysis & Test Verification Gates
- [ ] Run `flutter analyze` across modified/new files $\rightarrow$ 0 issues found!
- [ ] Run `flutter test test/features/studio/` $\rightarrow$ 100% green.

### T5.3 Release Build & Device Deployment
- [ ] Build ARM64 release APK (`flutter build apk --release --target-platform android-arm64 --no-pub`).
- [ ] Stream-install via ADB to `EPHUT20917014649`.
- [ ] Launch application on device.
- [ ] Update `docs/AGENT_HANDOFF_BIBLE.md` with Section 26.
- [ ] Git commit and push to `origin/fix/studio-cockpit-bugs-vh001-vh006`.

