# Phase 50 Requirements: Quantum-Entangled 3D Song DNA Node Tree & Hovering Cockpit Pill

## 1. Domain Glossary

- **SongDnaHoverPill**: Interactive, session-reactive hovering capsule in `StudioView` replacing the static progress tracker chip (`Key('studio_song_dna_hover_pill')`).
- **SongDnaNodeTreeModal**: Full-screen 3D spatial modal rendering the song's hierarchical genomic tree with camera orbit and zoom controls (`Key('song_dna_3d_tree_modal')`).
- **Conduit Branch**: Directional energy line connecting a child node to the song core, carrying a real-time `branchUnlockProgress` ($0.0$ to $1.0$).
- **Floating Cue Bubble**: Billboarded screen-space widget anchored above each 3D node displaying a Phosphor icon, status dot, and live value label (`Key('song_dna_bubble_${node.id}')`).
- **Invasive Node**: External or 3rd-party genomic locus (User Cloned Voice `VHU-SIG`, Reference Audio, Direct DAW Upload, or Parent Remix) rendered with electric violet double rings and detachable via 1-tap.
- **Quantum Entanglement**: Bi-directional synchronous state binding between `SongDnaGraphState` and Studio state providers (`studioFormProvider`, `vocalIdentityProvider`, `melodySketchpadProvider`, `stemRemixProvider`).

---

## 2. RFC-2119 Key Requirements

### Track A: Hovering 3D Song DNA Pill & Mini-Player Clearance (`REQ-P50-PILL-##`)

1. **REQ-P50-PILL-01**: `StudioView` and `ProgressTrackerWidget` SHALL replace the static `DNA XX%` badge with `SongDnaHoverPill` carrying `Key('studio_song_dna_hover_pill')`.
2. **REQ-P50-PILL-02**: `SongDnaHoverPill` SHALL animate with 60 FPS vertical sine levitation ($\pm 2.5\text{dp}$ over a 2.6-second duration) and specular rim highlights.
3. **REQ-P50-PILL-03**: `SongDnaHoverPill` SHALL dynamically blend its orbital glow and border accent color based on active Studio state:
   - Amber (`#F97316`) when beat, genre, or tempo are active.
   - Cyan (`#06B6D4`) when vocal identity, language, or lyrics are active.
   - Emerald (`#10B981`) when 5-channel sketchpad or MPC chops are active.
   - Electric Violet (`#D946EF`) when any Invasive Node (user voice, reference audio, remix context) is attached.
4. **REQ-P50-PILL-04**: Tapping `SongDnaHoverPill` SHALL trigger haptic feedback (`HapticFeedback.mediumImpact()`) and present `SongDnaNodeTreeModal` in full screen.
5. **REQ-P50-PILL-05**: When `StudioView` is active, `MiniPlayerHost` SHALL NOT obscure the sticky `StudioActionBar` (`Write Lyrics First` / `Generate` buttons). If docked in bar mode, it SHALL dock strictly above `studio_action_bar` with at least 8dp padding.

---

### Track B: Quantum-Entangled Graph State & 4-Class Taxonomy (`REQ-P50-GRAPH-##`)

1. **REQ-P50-GRAPH-01**: The system SHALL model four hierarchical node categories via `SongDnaNodeCategory`:
   - `beatCore` (African Amber `#F97316`): `node_core`, `node_genre_tempo`.
   - `vocalLyrics` (Sovereign Cyan `#06B6D4`): `node_vocal_persona`, `node_language_lyrics`, `node_mood_energy`.
   - `instrumentsHarmony` (Vibrant Emerald `#10B981`): `node_sketchpad_groove`, `node_heritage_mpc`.
   - `invasiveThirdParty` (Electric Magenta-Violet `#D946EF`): `node_invasive_voice_clone`, `node_invasive_reference`, `node_invasive_remix_lineage`.
2. **REQ-P50-GRAPH-02**: Each node SHALL compute a normalized `branchUnlockProgress` ($0.0..1.0$):
   - `0.0`: Unconfigured / dormant conduit.
   - `0.5`: Partially configured.
   - `1.0`: Fully configured with streaming energy particles along the branch.
3. **REQ-P50-GRAPH-03**: `node_sketchpad_groove` SHALL support additive satellite sub-nodes corresponding to active Sketchpad channels (`Lead`, `Chords`, `Log Drum`, `Drums`, `Hats`).
4. **REQ-P50-GRAPH-04**: Invasive nodes SHALL render with a distinct counter-rotating double ring and lightning tether to visually denote external human or 3rd-party audio injection.
5. **REQ-P50-GRAPH-05**: `songDnaGraphProvider` SHALL automatically update in real time upon changes to `studioFormProvider`, `vocalIdentityProvider`, `melodySketchpadProvider`, or `stemRemixProvider`.

---

### Track C: Full-Screen 3D Navigable Node Tree (`REQ-P50-TREE-##`)

1. **REQ-P50-TREE-01**: `SongDnaNodeTreeModal` SHALL render full-screen with key `Key('song_dna_3d_tree_modal')` against an obsidian dark backdrop with ambient cosmic grid particles.
2. **REQ-P50-TREE-02**: The 3D canvas SHALL support 1-finger drag orbit rotation across azimuth (yaw $\theta$) and elevation (pitch $\phi$) with inertia damping.
3. **REQ-P50-TREE-03**: The 3D canvas SHALL provide explicit camera controls:
   - Zoom In: `Key('song_dna_zoom_in_btn')`
   - Zoom Out: `Key('song_dna_zoom_out_btn')`
   - Reset Camera: `Key('song_dna_reset_camera_btn')`
4. **REQ-P50-TREE-04**: Nodes and conduits SHALL be rendered using perspective projection and depth-sorted using the painter's algorithm ($Z$-buffering) so near elements occlude far elements.
5. **REQ-P50-TREE-05**: Each 3D node SHALL be surmounted by a billboarded floating Cue Bubble (`Key('song_dna_bubble_${node.id}')`) displaying its Phosphor icon, status dot, and live value label.
6. **REQ-P50-TREE-06**: Tapping any 3D node sphere or its floating Cue Bubble SHALL center the camera on that node and open the Quick-Action Card.

---

### Track D: Quick-Action Mutation Cards & Quantum Entanglement (`REQ-P50-CARD-##`)

1. **REQ-P50-CARD-01**: Tapping a node or Cue Bubble SHALL reveal the glassmorphic Quick-Action Card (`Key('song_dna_quick_action_card')`) at the bottom of the modal.
2. **REQ-P50-CARD-02**: For `node_genre_tempo`, the card SHALL provide instant chips to select regional genres (`Amapiano`, `Gqom`, `Maskandi`, `Afro House`, `Kwaito`, `Afrobeats`) and tempo brackets (`Slow`, `Medium`, `Fast`, `Very Fast`), immediately mutating `studioFormProvider`.
3. **REQ-P50-CARD-03**: For `node_vocal_persona`, the card SHALL provide instant voice archetype selectors and an action to inject cloned vocal signatures.
4. **REQ-P50-CARD-04**: For `node_language_lyrics`, the card SHALL provide language selector pills (`Tshivenḓa`, `isiZulu`, `isiXhosa`, `English`) and lyrics mode toggles (`AI Writes` vs `My Lyrics`).
5. **REQ-P50-CARD-05**: For `node_sketchpad_groove`, the card SHALL allow adding/editing 5-channel sketchpad grooves or applying presets (`Soweto Log-Drum Knock`, `Maskandi Turnaround`), spawning satellite sub-nodes on the 3D tree.
6. **REQ-P50-CARD-06**: For invasive nodes, the card SHALL display a `[ Detach Invasive Node ]` button (`Key('song_dna_detach_node_btn')`) which purges reference audio or voice clone and dissolves the violet branch.
7. **REQ-P50-CARD-07**: The modal SHALL include a sticky CTA button `[ Synthesize Song from 3D DNA ]` (`Key('song_dna_synthesize_btn')`) which closes the modal and executes song generation.

---

### Track E: Verification & Release Invariants (`REQ-P50-INV-##`)

1. **REQ-P50-INV-01**: Zero new plugins in `pubspec.yaml`.
2. **REQ-P50-INV-02**: `dart analyze lib test` MUST report **`0 issues found!`** (Zero errors, zero warnings, zero hints).
3. **REQ-P50-INV-03**: All widget tests in `test/features/studio/` MUST pass **100% green**.
4. **REQ-P50-INV-04**: Compile ARM64 release APK and stream-install to device `EPHUT20917014649`.
5. **REQ-P50-INV-05**: Preserve backward compatibility with all Phase 44–49 sync, video, and onboarding features.

---

## 3. Traceability Matrix

| Requirement ID | Description | Component | Test Target |
|---|---|---|---|
| `REQ-P50-PILL-01..05` | 3D Hover Pill & Mini-player clearance | `song_dna_hover_pill.dart`, `progress_tracker.dart`, `studio_view.dart` | `phase50_quantum_song_dna_3d_tree_test.dart` (Test 1) |
| `REQ-P50-GRAPH-01..05` | 4-Class Node Hierarchy & Graph State | `song_dna_graph_models.dart`, `song_dna_graph_provider.dart` | `phase50_quantum_song_dna_3d_tree_test.dart` (Test 2) |
| `REQ-P50-TREE-01..06` | Full-Screen 3D Spatial Canvas & Cue Bubbles | `song_dna_node_tree_modal.dart` | `phase50_quantum_song_dna_3d_tree_test.dart` (Test 3) |
| `REQ-P50-CARD-01..07` | Quick-Action Cards & Quantum Entanglement | `song_dna_node_tree_modal.dart` | `phase50_quantum_song_dna_3d_tree_test.dart` (Test 4) |
| `REQ-P50-INV-01..05` | Zero plugins, clean analyze, release APK | All components | `flutter analyze` & `flutter test` |

