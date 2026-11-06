# Phase 55 Implementation Tasks: Audio-Reactive Living Mycelium Player, Real-Time Stem Visualizer & 3D Playback Universe

- **Phase Identifier**: `phase_55_audio_reactive_biome_player`
- **Target Application**: `apps/vhunambi_client`
- **Architecture Blueprint**: [`docs/phases/phase_55_audio_reactive_biome_player/blueprint.md`](./blueprint.md)
- **Requirements Specification**: [`docs/phases/phase_55_audio_reactive_biome_player/requirements.md`](./requirements.md)
- **Technical Design Specification**: [`docs/phases/phase_55_audio_reactive_biome_player/design.md`](./design.md)
- **Parent Audit Reference**: [`docs/audits/PLAYER_STEMS_MIXER_AND_AUDIO_REACTIVE_3D_BIOME_AUDIT.md`](../../audits/PLAYER_STEMS_MIXER_AND_AUDIO_REACTIVE_3D_BIOME_AUDIT.md)

---

## 1. Master Milestone Roadmap & Dependency Graph

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│              PHASE 55 EXECUTION ROADMAP: 6 SEQUENTIAL ENGINEERING MILESTONES           │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ MILESTONE M55.1: Pure Dart Audio-Biome Modulation Domain & Icon Hygiene                │
│  └── Task 55.1.1: Add `PlayerHeroMode` & `AudioBiomeModulationState` to domain         │
│  └── Task 55.1.2: Add `StemType.iconIdentifier` & optional `emoji` default             │
├───────────────────────────────────────────┬────────────────────────────────────────────┤
│                                           ▼                                            │
│ MILESTONE M55.2: Real-Time 60 FPS Audio-to-Biome Bridge Provider                       │
│  └── Task 55.2.1: Create `audio_reactive_biome_provider.dart`                          │
│  └── Task 55.2.2: Implement `primaryStemForCluster` & `playerHeroModeProvider`         │
├───────────────────────────────────────────┬────────────────────────────────────────────┤
│                                           ▼                                            │
│ MILESTONE M55.3: 3D Mycelium Painter Audio-Reactive DSP & Solo Spotlight Rendering     │
│  └── Task 55.3.1: Wire `AudioBiomeModulationState` into `OrganicMycelium3DPainter`     │
│  └── Task 55.3.2: Wire `audioReactiveBiomeModulationProvider` into `SongDnaNodeTreeModal`│
├───────────────────────────────────────────┬────────────────────────────────────────────┤
│                                           ▼                                            │
│ MILESTONE M55.4: 3-Way Hero Deck & `PlayerLivingBiomeHeroViewport` in Now Playing      │
│  └── Task 55.4.1: Create `player_living_biome_hero_viewport.dart` & `QuickMixHud`      │
│  └── Task 55.4.2: Upgrade `ExpandedCockpitModal` to 3-Way Hero Deck & Phosphor icons   │
├───────────────────────────────────────────┬────────────────────────────────────────────┤
│                                           ▼                                            │
│ MILESTONE M55.5: Stem Mixer Entanglement Strip & Track Detail Living Biome Card        │
│  └── Task 55.5.1: Add `StemMixerBiomeEntanglementStrip` to `StemMixerDeck`             │
│  └── Task 55.5.2: Create `TrackLivingBiomePreviewCard` & mount in `TrackDetailView`    │
├───────────────────────────────────────────┬────────────────────────────────────────────┤
│                                           ▼                                            │
│ MILESTONE M55.6: Phase 55 Verification Suite, Full Regression & Release APK Build      │
│  └── Task 55.6.1: Author `phase55_audio_reactive_biome_player_test.dart` (8 tests)     │
│  └── Task 55.6.2: Run `flutter analyze` (0 issues) & Phase 50–55 + Player test suite   │
│  └── Task 55.6.3: Build release APK & update `walkthrough.md` + `AGENT_HANDOFF_BIBLE`  │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

| Milestone | Title | Target Files | Key Requirements Covered |
| :--- | :--- | :--- | :--- |
| **M55.1** | Pure Dart Audio-Biome Modulation Domain & Hygiene | `mycelium_biome_models.dart`, `stem_mixer_state.dart` | `REQ-P55-DSP-01`, `REQ-P55-NFR-01` |
| **M55.2** | Real-Time 60 FPS Audio-to-Biome Bridge Provider | `audio_reactive_biome_provider.dart` | `REQ-P55-DSP-03`, `REQ-P55-STEM-01` |
| **M55.3** | 3D Mycelium Painter Audio-Reactive DSP Upgrade | `organic_mycelium_3d_painter.dart`, `song_dna_node_tree_modal.dart` | `REQ-P55-DSP-02` |
| **M55.4** | 3-Way Hero Deck & `PlayerLivingBiomeHeroViewport` | `player_living_biome_hero_viewport.dart`, `expanded_cockpit_modal.dart` | `REQ-P55-HERO-01`, `REQ-P55-HERO-02`, `REQ-P55-STEM-01` |
| **M55.5** | Stem Mixer Entanglement & Track Detail Biome Card | `stem_mixer_deck.dart`, `track_living_biome_preview_card.dart`, `track_detail_view.dart` | `REQ-P55-STEM-02`, `REQ-P55-TRK-01` |
| **M55.6** | Phase 55 Test Suite, Regression & Release Build | `phase55_audio_reactive_biome_player_test.dart` | `G-55-01` .. `G-55-06` |

---

## 2. Milestone M55.1: Pure Dart Audio-Biome Modulation Domain & Icon Hygiene

### Task 55.1.1: Add `PlayerHeroMode` & `AudioBiomeModulationState` to `mycelium_biome_models.dart`
- **Target File**: `apps/vhunambi_client/lib/features/studio/domain/models/mycelium_biome_models.dart`
- **Action**:
  - Define `enum PlayerHeroMode { artwork, biome3d, lyrics }` with `String get label`.
  - Define `class AudioBiomeModulationState` with fields `isPlaying`, `positionMs`, `durationMs`, `bassEnergy`, `drumsEnergy`, `melodicEnergy`, `vocalGlow`, `logDrumSnapZoom`, `clusterAudibleGains`, `soloedDomains`, `mutedDomains`.
  - Implement `progressRatio`, `synchronizedJourneySection`, `isDomainDormant`, `isDomainSoloed`, `domainEnergyFor`, `capScaleMultiplierFor`, `luminosityMultiplierFor`, `stipeHeaveFor`, `photonSpeedMultiplier`, `cameraSnapZoomMultiplier`, `sporeCloudAlpha`, `==`, and `hashCode`.
- **Acceptance Criteria**: Compiles with zero `package:flutter` or `dart:ui` imports (`REQ-P55-DSP-01`).

### Task 55.1.2: Add Semantic `iconIdentifier` to `StemType` & `StemChannel`
- **Target File**: `apps/vhunambi_client/lib/features/player/domain/models/stem_mixer_state.dart`
- **Action**:
  - Add `String get iconIdentifier` on `StemType` (`'vocals'`, `'drums'`, `'bass'`, `'melody'`).
  - Add `String get iconIdentifier => type.iconIdentifier;` on `StemChannel` and give `this.emoji = ''` a default value in `StemChannel` constructor so existing callers and JSON tests remain 100% compatible (`REQ-P55-NFR-01`).

---

## 3. Milestone M55.2: Real-Time 60 FPS Audio-to-Biome Bridge Provider

### Task 55.2.1: Create `audio_reactive_biome_provider.dart`
- **Target File**: `apps/vhunambi_client/lib/features/player/presentation/providers/audio_reactive_biome_provider.dart`
- **Action**:
  - Implement `playerHeroModeProvider` (`StateProvider<PlayerHeroMode>`).
  - Implement `StemType primaryStemForCluster(MyceliumClusterDomain domain)`.
  - Implement `audioReactiveBiomeModulationProvider` (`Provider.autoDispose<AudioBiomeModulationState>`) combining `playerStateProvider`, `stemMixerProvider`, and `frameModulationSnapshotProvider`.
- **Acceptance Criteria**: Emits deterministic 60 FPS `AudioBiomeModulationState` reflecting stem gains, solos, mutes, and playback position (`REQ-P55-DSP-03`).

---

## 4. Milestone M55.3: 3D Mycelium Painter Audio-Reactive DSP & Solo Spotlight Rendering

### Task 55.3.1: Upgrade `OrganicMycelium3DPainter` with `audioModulation`
- **Target File**: `apps/vhunambi_client/lib/features/studio/presentation/widgets/biome/organic_mycelium_3d_painter.dart`
- **Action**:
  - Add optional `final AudioBiomeModulationState? audioModulation;` parameter to `OrganicMycelium3DPainter`.
  - Apply `cameraSnapZoomMultiplier` to camera zoom when `logDrumSnapZoom > 0.01`.
  - Apply `photonSpeedMultiplier` ($1.0\times \to 5.0\times$) to arterial hypha synaptic photons in `_draw3DMyceliumRootWeb`.
  - Apply `capScaleMultiplierFor(domain)`, `stipeHeaveFor(domain)`, and `luminosityMultiplierFor(domain)` in `_draw3DFruitingBody`.
  - Render golden bioluminescent spotlight halo (`0xFFFFD166`) around soloed fruiting bodies (`isDomainSoloed(domain) == true`).
  - Include `oldDelegate.audioModulation != audioModulation` in `shouldRepaint`.
- **Acceptance Criteria**: 3D mushroom caps, stipes, gills, and synaptic photons visibly respond to `AudioBiomeModulationState` (`REQ-P55-DSP-02`).

### Task 55.3.2: Wire `audioReactiveBiomeModulationProvider` into `SongDnaNodeTreeModal`
- **Target File**: `apps/vhunambi_client/lib/features/studio/presentation/widgets/song_dna_node_tree_modal.dart`
- **Action**:
  - Watch `audioReactiveBiomeModulationProvider` inside `SongDnaNodeTreeModal` and pass `audioModulation` into `OrganicMycelium3DPainter`.
- **Acceptance Criteria**: Full-screen 3D Biome modal also breathes with real-time audio playback (`REQ-P55-NFR-01`).

---

## 5. Milestone M55.4: 3-Way Hero Deck & `PlayerLivingBiomeHeroViewport` in Now Playing

### Task 55.4.1: Create `PlayerLivingBiomeHeroViewport` & `PlayerBiomeQuickMixHud`
- **Target File**: `apps/vhunambi_client/lib/features/player/presentation/widgets/player_living_biome_hero_viewport.dart`
- **Action**:
  - Implement `PlayerLivingBiomeHeroViewport` (`Key('player_living_biome_viewport')`) with `OrganicMycelium3DPainter`, orbit pan gestures, synchronous `BiomeProjectionEngine.hitTestCluster`, and 6 semantic `Positioned` cluster hit targets (`Key('player_biome_cluster_${domain.name}')`).
  - Implement `PlayerBiomeQuickMixHud` (`Key('player_biome_quick_mix_hud')`) with `Key('biome_quick_solo_${domain.name}')` and `Key('biome_quick_mute_${domain.name}')` wired to `stemMixerProvider.notifier`.
  - Implement 5-section playback-synchronized Song Journey scrubber (`Key('player_biome_journey_bar')`, `Key('player_biome_section_${section.name}')`) calling `playerStateProvider.notifier.seekByRatio(...)`.
  - Implement `Key('player_open_full_3d_biome_btn')` launching `SongDnaNodeTreeModal.show(context)`.
- **Acceptance Criteria**: Tapping clusters reveals Quick-Mix HUD; Solo/Mute buttons update `stemMixerProvider`; tapping Song Journey sections seeks audio (`REQ-P55-HERO-02`, `REQ-P55-STEM-01`).

### Task 55.4.2: Upgrade `ExpandedCockpitModal` to 3-Way Hero Deck & Phosphor Icons
- **Target File**: `apps/vhunambi_client/lib/features/player/presentation/widgets/expanded_cockpit_modal.dart`
- **Action**:
  - Replace `bool _showLyrics = false;` with `PlayerHeroMode _heroMode = PlayerHeroMode.artwork;`.
  - Add the 3-way segmented hero selector (`Key('player_hero_mode_selector')`) with segments `Key('player_hero_segment_artwork')`, `Key('player_hero_segment_biome3d')`, and `Key('player_hero_segment_lyrics')`.
  - Preserve `Key('player_lyrics_toggle')` and `Key('player_lyrics_btn')` toggling between `PlayerHeroMode.lyrics` and `PlayerHeroMode.artwork`.
  - Add `Key('player_biome_btn')` (`3D DNA`) in the Track Utility Tray to switch to `PlayerHeroMode.biome3d`.
  - Replace `Icons.piano_rounded` and `Icons.favorite_rounded` / `Icons.favorite_border_rounded` with `PhosphorIcon(AppIcons.piano, ...)` and `PhosphorIcon(AppIcons.heart / AppIcons.heartOutline, ...)`.
- **Acceptance Criteria**: All existing `expanded_cockpit_modal_test.dart` tests pass 100%, and switching to `3D Biome` renders `PlayerLivingBiomeHeroViewport` (`REQ-P55-HERO-01`, `REQ-P55-NFR-01`).

---

## 6. Milestone M55.5: Stem Mixer Entanglement Strip & Track Detail Living Biome Card

### Task 55.5.1: Add `StemMixerBiomeEntanglementStrip` to `StemMixerDeck`
- **Target File**: `apps/vhunambi_client/lib/features/player/presentation/widgets/stem_mixer_deck.dart`
- **Action**:
  - Implement `StemMixerBiomeEntanglementStrip` (`Key('stem_mixer_biome_strip')`) with 6 interactive cluster pills (`Key('stem_mixer_cluster_pill_${domain.name}')`).
  - Mount `StemMixerBiomeEntanglementStrip` inside `StemMixerDeck` above the 4 channel strips.
- **Acceptance Criteria**: Tapping a cluster pill toggles solo on its mapped stem channel; soloing/muting a channel strip updates the cluster pill's opacity and badge (`REQ-P55-STEM-02`).

### Task 55.5.2: Create `TrackLivingBiomePreviewCard` & Mount in `TrackDetailView`
- **Target Files**:
  - `apps/vhunambi_client/lib/features/track/presentation/widgets/track_living_biome_preview_card.dart`
  - `apps/vhunambi_client/lib/features/track/presentation/views/track_detail_view.dart`
- **Action**:
  - Implement `TrackLivingBiomePreviewCard` (`Key('track_detail_living_biome_card')`) with `Key('track_detail_open_3d_biome_btn')`.
  - Mount `TrackLivingBiomePreviewCard` inside `TrackDetailView` immediately below `StemSeparationLab`, and replace `Icon(Icons.tune_rounded)` on `Key('track_open_mixer_btn')` with `PhosphorIcon(AppIcons.sliders, ...)`.
- **Acceptance Criteria**: `TrackDetailView` renders the Living 3D Song DNA Biome card and opens `SongDnaNodeTreeModal` when tapped (`REQ-P55-TRK-01`).

---

## 7. Milestone M55.6: Phase 55 Verification Suite, Full Regression & Release APK Build

### Task 55.6.1: Author `phase55_audio_reactive_biome_player_test.dart`
- **Target File**: `apps/vhunambi_client/test/features/player/phase55_audio_reactive_biome_player_test.dart`
- **Action**:
  - Write 8 comprehensive unit and widget tests covering Gates `G-55-01` through `G-55-05` (`REQ-P55-DSP-01..03`, `REQ-P55-HERO-01..02`, `REQ-P55-STEM-01..02`, `REQ-P55-TRK-01`).

### Task 55.6.2: Run Analyzer & Multi-Phase Regression Suite
- **Action**:
  - Run `flutter analyze` across `apps/vhunambi_client` (`0` errors/warnings).
  - Run `phase55_audio_reactive_biome_player_test.dart`, `expanded_cockpit_modal_test.dart`, `phase33_adaptive_mini_player_test.dart`, and Phases 50–54 studio tests.

### Task 55.6.3: Build Release APK & Update Handoff Documentation
- **Action**:
  - Build release APK (`flutter build apk --release`).
  - Create `docs/phases/phase_55_audio_reactive_biome_player/walkthrough.md` and update `docs/AGENT_HANDOFF_BIBLE.md`.

---

## 8. Forensic Anti-Trap Verification Checklist (Argon Gate)

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                       ARGON STAGE 3 FORENSIC VERIFICATION CHECKLIST                    │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ [x] 1. Theory-to-Code Fidelity: `design.md` §5 implements the exact radial cap         │
│        dilation, stipe heave, solo spotlight halo, and photon velocity from §2.        │
│ [x] 2. Unified 3D Coordinate Convention: Strictly Right-Handed 3D Y-Up World Space     │
│        (X right, +Y vertical elevation up, +Z foreground depth).                       │
│ [x] 3. Authentic Monorepo Imports & Tokens: Uses `package:vhunambi_client/...`,        │
│        `package:phosphor_icons/phosphor_icons.dart`, and valid `AppColors` /           │
│        `AppTypography` tokens.                                                         │
│ [x] 4. Synchronous Hit-Testing & Semantic Test Keys: Both `BiomeProjectionEngine`      │
│        hit-testing and `Positioned` `Key('player_biome_cluster_${domain.name}')` exist.│
│ [x] 5. Backward-Compatible Player Keys: Preserves `Key('player_lyrics_toggle')` and    │
│        `Key('player_lyrics_btn')` behavior for existing Mission 14/15 tests.           │
│ [x] 6. Deterministic Test-Safe Animation Phase: `PlayerLivingBiomeHeroViewport` derives│
│        `animationProgress` from `positionMs` so `tester.pumpAndSettle()` never hangs.  │
│ [x] 7. Zero Raw Unicode Emojis (`STD-UIUX-001`): 100% Phosphor iconography.            │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

