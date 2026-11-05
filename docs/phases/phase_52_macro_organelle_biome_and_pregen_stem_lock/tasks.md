# Phase 52 Tasks: Macro-Canopy 3D Organelle Biome & Pre-Generation Stem-Lock Engine

## Task List

- [ ] **Track A: Macro-Canopy Camera Traversal & 2-Tier Hierarchy**
  - [ ] **T1.1**: Update `SongDnaNode` and `song_dna_graph_models.dart` with `StemLockMode`, `isBranchRoot`, and helper constructors.
  - [ ] **T1.2**: Upgrade `SongDnaNodeTreeModal` camera state to 2-tier spatial hierarchy (`Overview Mode` $\leftrightarrow$ `Branch Canopy Focus Mode`).
  - [ ] **T1.3**: Implement smooth camera animation along stem bridges when focusing a branch root.
  - [ ] **T1.4**: In Overview Mode, show text pills exclusively on the 4 primary branch roots to prevent collision.
  - [ ] **T1.5**: In Branch Canopy Focus Mode, render child leaf bubbles with micro-tags and double-ring receptors (`◎`) fanning out at arm's reach.
  - [ ] **T1.6**: Add floating `[ 🔭 Surface Overview ]` pill button (`Key('song_dna_return_overview_btn')`) to return to Overview Mode.

- [ ] **Track B: Organic Mucus-Membrane Stem Bridges & Additive Glow**
  - [ ] **T2.1**: Implement `_paintMucusMembraneBridge` in `_BioluminescentOrganelle3DPainter` with flared smooth-min meniscus webbing, cubic-Bézier closed tube paths, and specular highlight.
  - [ ] **T2.2**: Render 3 intertwined internal neural filaments using `BlendMode.plus` with traveling synaptic photon packets.
  - [ ] **T2.3**: Render multi-layered additive plasma core with radial gradient blending (`#FFFFFF` to `#FFB703` to `#FB5607`) using `BlendMode.plus`.
  - [ ] **T2.4**: Implement 3 tilted elliptical orbital energy rings rotating in 3D space with glowing satellite beads.
  - [ ] **T2.5**: Implement calm idle breathing (30% resting luminosity) vs contextual network surge (100% active luminance on focused branch).

- [ ] **Track C: Pre-Generation Stem Ingestion & Per-Branch `StemLockMode`**
  - [ ] **T3.1**: Add `StemLockMode` enum (`lockedPure44k`, `harmonicInpaint`, `elasticResynth`) to `studio_form_state.dart` and `branchStemLockModes` map.
  - [ ] **T3.2**: Add 3-way **Stem Authority Selector Pill** (`Key('song_dna_stem_lock_selector')`) to the Quick-Action Card.
  - [ ] **T3.3**: Render crystalline golden-cyan double-sheath on stems in `StemLockMode.lockedPure44k`.
  - [ ] **T3.4**: Add `[ + Add Instrument Leaf ]` button (`Key('song_dna_add_instrument_leaf_btn')`) on the Instruments & Harmony branch to dynamically spawn/swap instrument leaves.

- [ ] **Track D: Hybrid Stem-Lock Synthesis Pipeline**
  - [ ] **T4.1**: In client `song_dna_graph_provider.dart` / `stem_mix_bounce_service.dart`, package `pregenStemLocks` manifest and export locked stems.
  - [ ] **T4.2**: In `apps/vhunambi_api/src/modules/synthesis/prompt_compiler.ts`, add `pregenStemLocks` to `SongSpecInput` and synthesis metadata.
  - [ ] **T4.3**: In `tools/zr-studio-gpu/handler.py`, process `pregen_stem_locks` to substitute pure 44.1 kHz audio before Stage 4 mastering, bypassing AI re-synthesis on locked stems.

- [ ] **Track E: Verification Gates & Hardware Deployment**
  - [ ] **T5.1**: Author `test/features/studio/phase52_macro_organelle_and_stem_lock_test.dart` covering macro dive, stem bridge rendering, `StemLockMode` toggling, and leaf additions.
  - [ ] **T5.2**: Run `dart analyze lib test` → 0 issues found.
  - [ ] **T5.3**: Run `flutter test` across all studio tests → 100% green.
  - [ ] **T5.4**: Run API tests in `apps/vhunambi_api` → 100% green.
  - [ ] **T5.5**: Build ARM64 release APK (`flutter build apk --release --target-platform android-arm64 --no-pub`).
  - [ ] **T5.6**: Stream-install to physical hardware `EPHUT20917014649` and launch.
  - [ ] **T5.7**: Update `docs/AGENT_HANDOFF_BIBLE.md` and git commit/push.

