# Phase 55 Requirements Specification: Audio-Reactive Living Mycelium Player, Real-Time Stem Visualizer & 3D Playback Universe

- **Phase Identifier**: `phase_55_audio_reactive_biome_player`
- **Target Application**: `apps/vhunambi_client`
- **Architecture Blueprint**: [`docs/phases/phase_55_audio_reactive_biome_player/blueprint.md`](./blueprint.md)
- **Parent Audit Reference**: [`docs/audits/PLAYER_STEMS_MIXER_AND_AUDIO_REACTIVE_3D_BIOME_AUDIT.md`](../../audits/PLAYER_STEMS_MIXER_AND_AUDIO_REACTIVE_3D_BIOME_AUDIT.md)

---

## 1. Document Scope, Coordinate Standard & EARS / RFC-2119 Conventions

### 1.1 Scope
This document specifies the functional, mathematical, state-entanglement, and non-functional requirements for **Phase 55: Audio-Reactive Living Mycelium Player, Real-Time Stem Visualizer & 3D Playback Universe**. It governs how the Now Playing Cockpit (`ExpandedCockpitModal`), the 60 FPS Audio Modulation Bus (`frameModulationSnapshotProvider`), the Pocket 4-Channel Stem Mixer (`StemMixerDeck`, `stemMixerProvider`), the Track Detail View (`TrackDetailView`), and the 3D Mycelium Rendering Engine (`OrganicMycelium3DPainter`, `MyceliumBiomeGraphNotifier`, `SongDnaNodeTreeModal`) synchronize in real time.

### 1.2 Coordinate System Convention
All 3D spatial coordinates and fruiting body elevations strictly obey **Right-Handed 3D Y-Up World Space**:
- **$X$-Axis**: Lateral horizontal axis ($+X$ right, $-X$ left).
- **$Y$-Axis**: Vertical elevation axis ($+Y$ upward toward canopy apex, $Y_{\text{root}, k} = h(X_k, Z_k) \ge 0$ rooted on the contoured terrain surface).
- **$Z$-Axis**: Foreground depth axis ($+Z$ toward camera, $-Z$ background depth).
- **Screen Projection**: Positive $+Y$ world elevation projects upward on screen ($Y_{\text{screen}} = H/2 - y_{\text{eye}} \cdot \text{scale}$).

### 1.3 EARS & RFC-2119 Requirement Syntax
Every requirement in this specification uses the **Easy Approach to Requirements Syntax (EARS)** paired with **RFC-2119** normative keywords (`SHALL`, `MUST`, `SHOULD`, `MAY`):
- **Ubiquitous**: `The <system> SHALL <response>.`
- **Event-Driven**: `WHEN <trigger>, the <system> SHALL <response>.`
- **State-Driven**: `WHILE <state>, the <system> SHALL <response>.`
- **Unwanted Behavior**: `IF <condition>, THEN the <system> SHALL <response>.`

---

## 2. Real-Time Audio-to-Biome DSP Modulation Requirements (`REQ-P55-DSP-*`)

### `REQ-P55-DSP-01`: Pure Dart `AudioBiomeModulationState` & Domain Energy Transfer Functions
- **Statement**: The Pure Dart domain layer (`mycelium_biome_models.dart`) `SHALL` define an immutable `AudioBiomeModulationState` value class with zero `package:flutter` or `dart:ui` imports that encapsulates:
  - `isPlaying` (`bool`), `positionMs` (`int`), `durationMs` (`int`)
  - `bassEnergy`, `drumsEnergy`, `melodicEnergy`, `vocalGlow`, `logDrumSnapZoom` (each `double` in $[0.0, 1.0]$)
  - `clusterAudibleGains` (`Map<MyceliumClusterDomain, double>`), `soloedDomains` (`Set<MyceliumClusterDomain>`), `mutedDomains` (`Set<MyceliumClusterDomain>`)
- **Domain Energy Mapping**: `WHEN` `domainEnergyFor(MyceliumClusterDomain domain)` is evaluated on `AudioBiomeModulationState`, it `SHALL` compute:
  1. `melodyCore`: $\text{clamp}(E_{\text{melodic}}, 0.0, 1.0)$
  2. `rhythmNetwork`: $\text{clamp}(0.60 \cdot E_{\text{bass}} + 0.40 \cdot E_{\text{drums}}, 0.0, 1.0)$
  3. `vocalNetwork`: $\text{clamp}(E_{\text{vocal}}, 0.0, 1.0)$
  4. `harmonyNetwork`: $\text{clamp}(0.50 \cdot E_{\text{melodic}} + 0.50 \cdot E_{\text{bass}}, 0.0, 1.0)$
  5. `productionNetwork`: $\text{clamp}(0.50 \cdot E_{\text{drums}} + 0.50 \cdot E_{\text{melodic}}, 0.0, 1.0)$
  6. `emotionNetwork`: $\text{clamp}(1.40 \cdot E_{\text{melodic}} \cdot E_{\text{vocal}}, 0.0, 1.0)$

### `REQ-P55-DSP-02`: Mushroom Cap Radial Dilation, Luminosity & Synaptic Photon Velocity
- **Statement**: `WHILE` `AudioBiomeModulationState` is supplied to `OrganicMycelium3DPainter`, the painter `SHALL` modulate each 3D mushroom fruiting body $k$ and arterial hypha edge as follows:
  - **Dormant / Muted Contraction**: `IF` `isDomainDormant(domain)` is `true` (the domain is in `mutedDomains` OR `soloedDomains.isNotEmpty && !soloedDomains.contains(domain)`), `THEN` `capScaleMultiplierFor(domain)` `SHALL` return `0.86` and `luminosityMultiplierFor(domain)` `SHALL` return `0.20`.
  - **Active / Soloed Radial Dilation**: `IF` `isDomainDormant(domain)` is `false`, `THEN` `capScaleMultiplierFor(domain)` `SHALL` return $\text{clamp}(1.0 + 0.18 \cdot E_{D_k} \cdot G_k + (isSolo ? 0.08 : 0.0), 0.85, 1.32)$ and `luminosityMultiplierFor(domain)` `SHALL` return $\text{clamp}(1.15 + 0.20 \cdot E_{D_k}, 1.00, 1.35)$ when soloed or $\text{clamp}(0.85 + 0.30 \cdot E_{D_k}, 0.50, 1.25)$ otherwise.
  - **Solo Spotlight Corona Ring**: `WHEN` `soloedDomains.contains(domain)` is `true`, `OrganicMycelium3DPainter` `SHALL` render a golden bioluminescent spotlight halo (`0xFFFFD166`) around that fruiting body's cap apex.
  - **Synaptic Photon Acceleration**: `photonSpeedMultiplier` `SHALL` evaluate to $\text{clamp}(1.0 + 2.5 \cdot E_{\text{melodic}} + 1.5 \cdot E_{\text{drums}}, 1.0, 5.0)$.
  - **Log-Drum Camera Snap-Zoom**: `cameraSnapZoomMultiplier` `SHALL` evaluate to $\text{clamp}(1.0 + 0.065 \cdot S_{\text{snap}}, 1.0, 1.065)$.

### `REQ-P55-DSP-03`: Live 60 FPS `audioReactiveBiomeModulationProvider` Bridge
- **Statement**: The system `SHALL` provide `audioReactiveBiomeModulationProvider` (`Provider<AudioBiomeModulationState>`) in `features/player/presentation/providers/audio_reactive_biome_provider.dart` that watches `playerStateProvider`, `stemMixerProvider`, and `frameModulationSnapshotProvider` (keyed by the active track's `SongMetadataDna` and `playerState.position.inMilliseconds`) and outputs an up-to-date `AudioBiomeModulationState`.
- **Playback-Synchronized Song Journey Section**: `AudioBiomeModulationState.synchronizedJourneySection` `SHALL` deterministically map playback progress ratio $r = \text{positionMs} / \max(1, \text{durationMs})$ into `SongJourneySection.intro` ($[0.0, 0.15)$), `verse` ($[0.15, 0.40)$), `chorus` ($[0.40, 0.70)$), `bridge` ($[0.70, 0.85)$), and `outro` ($[0.85, 1.00]$).

---

## 3. Expanded Cockpit 3-Way Hero Deck Requirements (`REQ-P55-HERO-*`)

### `REQ-P55-HERO-01`: 3-Way Segmented Hero Mode Selector (`PlayerHeroMode`)
- **Statement**: `ExpandedCockpitModal` `SHALL` render a 3-way segmented pill controller (`Key('player_hero_mode_selector')`) above the hero surface with three interactive segments:
  1. **Artwork** (`Key('player_hero_segment_artwork')`, `PlayerHeroMode.artwork`)
  2. **3D Biome** (`Key('player_hero_segment_biome3d')`, `PlayerHeroMode.biome3d`)
  3. **Lyrics** (`Key('player_hero_segment_lyrics')`, `PlayerHeroMode.lyrics`)
- **Backward Compatibility Invariant**: Tapping the top-bar button `Key('player_lyrics_toggle')` or the utility tray button `Key('player_lyrics_btn')` `SHALL` toggle between `PlayerHeroMode.lyrics` and `PlayerHeroMode.artwork` so all existing Mission 14/15 widget tests continue to pass 100%. Tapping the utility tray button `Key('player_biome_btn')` `SHALL` switch directly to `PlayerHeroMode.biome3d`.

### `REQ-P55-HERO-02`: Interactive 3D Living Biome Player Viewport (`PlayerLivingBiomeHeroViewport`)
- **Statement**: `WHILE` `PlayerHeroMode.biome3d` is active in `ExpandedCockpitModal`, the hero slot `SHALL` render `PlayerLivingBiomeHeroViewport` (`Key('player_living_biome_viewport')`), displaying:
  1. The interactive 3D Mycelium Ecosystem rendered by `OrganicMycelium3DPainter` wired to `audioReactiveBiomeModulationProvider`.
  2. Semantic hit-target buttons (`Key('player_biome_cluster_${domain.name}')`) positioned at each of the 6 projected mushroom cap apexes.
  3. A top-left live DSP badge (`Key('player_biome_dsp_badge')`) and a top-right expand button (`Key('player_open_full_3d_biome_btn')`) that opens `SongDnaNodeTreeModal` in full-screen audio-reactive mode.
  4. A compact 5-section playback-synchronized Song Journey bar (`Key('player_biome_journey_bar')`) where tapping any section (`Key('player_biome_section_${section.name}')`) seeks the audio player to `section.normalizedPosition` via `playerStateProvider.notifier.seekByRatio(...)`.

---

## 4. Bidirectional Stem Mixer & 3D Biome Entanglement Requirements (`REQ-P55-STEM-*`)

### `REQ-P55-STEM-01`: Canonical Stem-to-Cluster Mapping & Quick-Mix HUD in Player
- **Statement**: Each `MyceliumClusterDomain` `SHALL` map to its primary `StemType` via `primaryStemForCluster(MyceliumClusterDomain domain)`:
  - `vocalNetwork` $\to$ `StemType.vocals`
  - `rhythmNetwork` $\to$ `StemType.drums`
  - `harmonyNetwork` $\to$ `StemType.bass`
  - `melodyCore` $\to$ `StemType.melody`
  - `emotionNetwork` $\to$ `StemType.vocals`
  - `productionNetwork` $\to$ `StemType.drums`
- **Quick-Mix HUD Interaction**: `WHEN` the user taps a 3D mushroom cluster (`Key('player_biome_cluster_${domain.name}')`) inside `PlayerLivingBiomeHeroViewport`, the viewport `SHALL` display `PlayerBiomeQuickMixHud` (`Key('player_biome_quick_mix_hud')`) exposing:
  - The cluster's display name, mapped stem name, live gain dB readout, and instantaneous energy percentage.
  - A **Solo** toggle button (`Key('biome_quick_solo_${domain.name}')`) that invokes `stemMixerProvider.notifier.toggleSolo(primaryStem)`.
  - A **Mute** toggle button (`Key('biome_quick_mute_${domain.name}')`) that invokes `stemMixerProvider.notifier.toggleMute(primaryStem)`.

### `REQ-P55-STEM-02`: `StemMixerBiomeEntanglementStrip` in `StemMixerDeck`
- **Statement**: `StemMixerDeck` `SHALL` render `StemMixerBiomeEntanglementStrip` (`Key('stem_mixer_biome_strip')`) above the 4 channel strips, displaying 6 interactive cluster pills (`Key('stem_mixer_cluster_pill_${domain.name}')`) with their real-time audible luminosity, solo/mute status badge, and energy percentage.
- **Interactive Sync**: Tapping a cluster pill (`Key('stem_mixer_cluster_pill_${domain.name}')`) in `StemMixerBiomeEntanglementStrip` `SHALL` toggle solo on its mapped `StemType` via `stemMixerProvider.notifier.toggleSolo(...)`, and long-pressing it `SHALL` toggle mute via `stemMixerProvider.notifier.toggleMute(...)`.

---

## 5. Track Detail View Living DNA Integration & Hygiene (`REQ-P55-TRK-*` & `REQ-P55-NFR-*`)

### `REQ-P55-TRK-01`: `TrackLivingBiomePreviewCard` in `TrackDetailView`
- **Statement**: `TrackDetailView` (`features/track/presentation/views/track_detail_view.dart`) `SHALL` render `TrackLivingBiomePreviewCard` (`Key('track_detail_living_biome_card')`) immediately below `StemSeparationLab`, displaying a live 6-cluster mycelium preview, active stem separation telemetry, and an action button (`Key('track_detail_open_3d_biome_btn')`) that opens `SongDnaNodeTreeModal.show(context)`.

### `REQ-P55-NFR-01`: Design System & Zero-Emoji Compliance (`STD-UIUX-001`)
- **Statement**:
  1. `ExpandedCockpitModal` `SHALL` replace `Icons.piano_rounded` and `Icons.favorite_rounded` / `Icons.favorite_border_rounded` with `PhosphorIcon(AppIcons.piano, ...)` and `PhosphorIcon(AppIcons.heart / AppIcons.heartOutline, ...)`.
  2. `TrackDetailView` `SHALL` replace `Icons.tune_rounded` on `Key('track_open_mixer_btn')` with `PhosphorIcon(AppIcons.sliders, ...)`.
  3. `StemChannel` (`stem_mixer_state.dart`) `SHALL` expose a semantic `String get iconIdentifier` getter (`'vocals'`, `'drums'`, `'bass'`, `'melody'`) and default `this.emoji = ''` so zero raw unicode emojis are required while maintaining 100% backward compatibility with existing JSON serialization tests.
  4. `SongDnaNodeTreeModal` `SHALL` also watch `audioReactiveBiomeModulationProvider` and pass `audioModulation` into `OrganicMycelium3DPainter` so full-screen 3D Biome inspection reacts to live audio playback at 60 FPS.

---

## 6. Granular Requirement-to-Test Traceability Matrix

```
┌────────────────────┬──────────────────────────────────────────────┬──────────────────────────────────────────────────────────┐
│ Requirement ID     │ Target Implementation File / Class           │ Verification Test Case (`phase55_..._test.dart`)         │
├────────────────────┼──────────────────────────────────────────────┼──────────────────────────────────────────────────────────┤
│ REQ-P55-DSP-01     │ `mycelium_biome_models.dart`                 │ `Test 1: AudioBiomeModulationState computes 6 domain     │
│                    │ (`AudioBiomeModulationState`)                │  energies, cap scales, and synchronized journey section` │
├────────────────────┼──────────────────────────────────────────────┼──────────────────────────────────────────────────────────┤
│ REQ-P55-DSP-02     │ `organic_mycelium_3d_painter.dart`           │ `Test 2: Soloed and muted stems modulate cluster cap     │
│                    │ (`OrganicMycelium3DPainter`)                 │  dilation, luminosity (0.20x vs 1.35x), and photon speed`│
├────────────────────┼──────────────────────────────────────────────┼──────────────────────────────────────────────────────────┤
│ REQ-P55-DSP-03     │ `audio_reactive_biome_provider.dart`         │ `Test 3: audioReactiveBiomeModulationProvider bridges    │
│                    │ (`audioReactiveBiomeModulationProvider`)     │  PlayerState, StemMixerState, and FrameModulationSnapshot`│
├────────────────────┼──────────────────────────────────────────────┼──────────────────────────────────────────────────────────┤
│ REQ-P55-HERO-01    │ `expanded_cockpit_modal.dart`                │ `Test 4: ExpandedCockpitModal 3-Way Hero Deck switches   │
│                    │ (`ExpandedCockpitModal`)                     │  Artwork <-> 3D Biome <-> Lyrics & preserves legacy key` │
├────────────────────┼──────────────────────────────────────────────┼──────────────────────────────────────────────────────────┤
│ REQ-P55-HERO-02    │ `player_living_biome_hero_viewport.dart`     │ `Test 5: PlayerLivingBiomeHeroViewport renders 6 3D      │
│                    │ (`PlayerLivingBiomeHeroViewport`)            │  clusters and seeks audio when Song Journey node tapped` │
├────────────────────┼──────────────────────────────────────────────┼──────────────────────────────────────────────────────────┤
│ REQ-P55-STEM-01    │ `player_living_biome_hero_viewport.dart`     │ `Test 6: Tapping 3D mushroom in Player opens QuickMixHud │
│                    │ (`PlayerBiomeQuickMixHud`)                   │  and Solo/Mute buttons mutate stemMixerProvider`         │
├────────────────────┼──────────────────────────────────────────────┼──────────────────────────────────────────────────────────┤
│ REQ-P55-STEM-02    │ `stem_mixer_deck.dart`                       │ `Test 7: StemMixerBiomeEntanglementStrip syncs with      │
│                    │ (`StemMixerBiomeEntanglementStrip`)          │  channel strips and toggles stem solo on pill tap`       │
├────────────────────┼──────────────────────────────────────────────┼──────────────────────────────────────────────────────────┤
│ REQ-P55-TRK-01     │ `track_detail_view.dart`                     │ `Test 8: TrackDetailView renders                         │
│ REQ-P55-NFR-01     │ (`TrackLivingBiomePreviewCard`)              │  TrackLivingBiomePreviewCard and launches 3D Biome modal`│
└────────────────────┴──────────────────────────────────────────────┴──────────────────────────────────────────────────────────┘
```

