# Phase 56 Requirements Specification: Studio Cockpit Compaction, Layout Crash Fixes & Mobile-First 3D Biome Camera/Tooltip Overhaul

- **Phase Identifier**: `phase_56_studio_cockpit_and_mobile_biome_overhaul`
- **Target Application**: `apps/vhunambi_client`
- **Architecture Blueprint**: [`docs/phases/phase_56_studio_cockpit_and_mobile_biome_overhaul/blueprint.md`](./blueprint.md)
- **Forensic Video Reference**: `SVID_20261106_132743_1.mp4` (`598x1280`, `238.46s`, Physical Device `EPHUT20917014649`)
- **Prerequisite Specifications**:
  - [`docs/phases/phase_53_organic_mycelium_3d_biome/requirements.md`](../phase_53_organic_mycelium_3d_biome/requirements.md)
  - [`docs/phases/phase_54_cockpit_biome_quantum_entanglement/requirements.md`](../phase_54_cockpit_biome_quantum_entanglement/requirements.md)
  - [`docs/phases/phase_55_audio_reactive_biome_player/requirements.md`](../phase_55_audio_reactive_biome_player/requirements.md)

---

## 1. Document Scope, Coordinate Standard & EARS / RFC-2119 Conventions

### 1.1 Scope
This document specifies the functional, layout, camera-physics, state-synchronization, and non-functional requirements for **Phase 56: Studio Cockpit Compaction, Layout Crash Fixes & Mobile-First 3D Biome Camera/Tooltip Overhaul**. It resolves all ten visual collisions, 1-character vertical text squashes, stuck skeleton cards, mini-player intrusions, and 3D camera freezes observed on mobile portrait hardware (`SVID_20261106_132743_1.mp4`) while preserving **100% backward compatibility** with all existing Phase 50–55 and Studio widget tests.

### 1.2 Coordinate System Convention
All 3D spatial coordinates, mushroom fruiting body loci, and camera dolly-zoom trajectories strictly obey **Right-Handed 3D Y-Up World Space**:
- **$X$-Axis**: Lateral horizontal axis ($+X$ right, $-X$ left).
- **$Y$-Axis**: Vertical elevation axis ($+Y$ upward toward canopy apex, $Y_{\text{root}, k} = h(X_k, Z_k) \ge 0$ rooted on the contoured terrain surface).
- **$Z$-Axis**: Foreground depth axis ($+Z$ toward camera, $-Z$ background depth).
- **Screen Projection**: Positive $+Y$ world elevation projects upward on screen ($Y_{\text{screen}} = H/2 - y_{\text{eye}} \cdot \text{scale}$).

### 1.3 EARS & RFC-2119 Requirement Syntax
All requirements follow **Easy Approach to Requirements Syntax (EARS)** paired with **RFC-2119** normative keywords (`SHALL`, `SHALL NOT`, `MUST`, `SHOULD`):
- **Ubiquitous**: `The <system/component> SHALL <response>.`
- **Event-Driven**: `WHEN <trigger event>, the <system/component> SHALL <response>.`
- **State-Driven**: `WHILE <system state>, the <system/component> SHALL <response>.`
- **Unwanted Behavior**: `IF <unwanted condition>, THEN the <system/component> SHALL <mitigation>.`

---

## 2. Track A Functional Requirements: `Compose` Station Compaction & Prompt-First Hierarchy

### `REQ-P56-COMP-01` — Prompt-First Hierarchy in Tab 0 (`Compose`) (`00:00–00:08` Video Fix)
- **Statement**: **WHEN** `StudioView` (`apps/vhunambi_client/lib/features/studio/presentation/views/studio_view.dart`) renders Tab 0 (`CockpitWorkspaceTab.compose`), the scroll column **SHALL** order its children so that `StudioSessionRecoveryBanner`, the unified `_DnaSuggestionChip` (`Key('dna_studio_suggestion_chip')` + `Key('cockpit_sonic_vibe_dice_btn')`), `ActiveRemixLineageBanner`, `PromptInputBox` (`find.text('Describe your song')`), and `ReferenceAudioDropzone` (`find.text('Reference Audio (optional)')`) appear **above** `CockpitQuantumEntanglementRack`.
- **Acceptance Criteria**:
  1. `PromptInputBox` is visible immediately at `0.0s` upon opening `StudioView` on a `360x780dp` mobile viewport without vertical scrolling.
  2. `PromptInputBox`'s `TextField` remains the first `TextField` in `StudioView` so `studio_view_test.dart` (`find.byType(TextField).first`) passes 100%.
  3. `ProgressTrackerWidget` renders the completeness ratio bar, `'9 / 9'` counter, and `SongDnaHoverPill` (`Key('studio_song_dna_hover_pill')`) in a single compact row (`height <= 36dp`).

### `REQ-P56-COMP-02` — Collapsible 2×3 Compact Quantum Stem Matrix (`cockpit_quantum_entanglement_rack.dart`)
- **Statement**: `CockpitQuantumEntanglementRack` (`Key('cockpit_quantum_entanglement_rack')`) **SHALL** render a Always-2-Column × 3-Row compact grid (even on mobile viewports $\ge 300\text{dp}$, using `cardWidth = (constraints.maxWidth - 8) / 2`) with a collapsible header toggle (`Key('cockpit_rack_collapse_toggle_btn')`, defaulting to `_isExpanded = true` so all 6 domain tiles are immediately mounted for widget tests).
- **Acceptance Criteria**:
  1. Each of the 6 compact domain tiles (`height <= 74dp`) **MUST** preserve `Key('cockpit_domain_card_${domain.name}')`, `Key('cockpit_stem_lock_${domain.name}')`, and `Key('cockpit_jump_3d_${domain.name}')`.
  2. By rendering 2 columns × 3 rows instead of 6 stacked full-width cards, total rack height on mobile shrinks from `564dp` to `<= 256dp` when expanded and `52dp` when collapsed.
  3. The header button `Key('cockpit_rack_open_3d_biome_btn')` launches `SongDnaNodeTreeModal.show(context)`.

### `REQ-P56-COMP-03` — Non-Truncated Two-Tier `ReferenceAudioDropzone` (`00:22–00:48` Video Fix)
- **Statement**: `ReferenceAudioDropzone` (`apps/vhunambi_client/lib/features/studio/presentation/widgets/reference_audio_dropzone.dart`) **SHALL** separate its header label `'Reference Audio (optional)'` onto Row 1 (giving it full horizontal width so it is never truncated to `"Refer..."`) and render a compact 3-pill action strip on Row 2:
  1. `[ Upload Audio ]` (`Key('dropzone_upload_audio_btn')`) — triggers `AudioImportService().pickAndDecodeAudioFile()` directly or toggles the collapsible upload inspector.
  2. `[ My Beats ]` (`Key('dropzone_load_licensed_beat_btn')`) — opens the licensed/produced beat picker sheet.
  3. `[ Sketchpad ]` (`Key('dropzone_open_sketchpad_btn')`) — opens `MelodySketchpadModal.show(context)`.
- **Acceptance Criteria**:
  1. `find.text('Reference Audio (optional)')` matches 100% with zero horizontal ellipsis clipping on `360dp` mobile screens.
  2. `Key('dropzone_active_sketchpad_badge')` renders cleanly when a groove pattern is attached, using `PhosphorIcon(PhosphorIconsBold.waveform)` instead of raw emojis.

### `REQ-P56-COMP-04` — Compact Multi-Column Wrap Chips for Languages, Moods & Song Structure (`00:50–01:28` Video Fix)
- **Statement**: `MultilingualLanguageSelector` and `AdvancedOptionsAccordion` **SHALL** render Language pills, Mood pills, and Song Structure pills using compact multi-column `Wrap` layouts (`minHeight: 36dp`, horizontal padding `10dp`, vertical padding `6dp`, spacing `6dp`) so that 3 pills fit per row on a `360dp` mobile viewport.
- **Acceptance Criteria**:
  1. All 11 South African official languages, 10 moods, and 4 song structures remain selectable via their exact text labels (`'Tshivenḓa'`, `'isiZulu'`, `'Uplifting'`, `'Standard'`, `'Extended (DJ)'`, `'Freestyle'`, `'Loop'`).
  2. Vertical scroll height of expanded `MultilingualLanguageSelector` and `AdvancedOptionsAccordion` is reduced by $\ge 55\%$.

---

## 3. Track B Functional Requirements: `Voice` & `Crate & MPC` Consolidation + Crash Fixes

### `REQ-P56-VOX-01` — Vocal Ensemble & Delivery Header in Tab 1 (`Voice`) (`01:16–01:23` Video Fix)
- **Statement**: `BantuVoiceDeck` (`apps/vhunambi_client/lib/features/studio/presentation/widgets/bantu_voice_deck.dart`) **SHALL** mount a compact `Vocal Ensemble & Delivery` section (`Key('voice_ensemble_header_card')`) at the top of Tab 1 (`Voice`) providing 1-tap segmented pill selectors for:
  1. **Voices**: `Solo` (`VocalVoices.solo`), `Duet` (`VocalVoices.duet`), `Choir` (`VocalVoices.choir`).
  2. **Vocal Gender**: `Male` (`VocalGender.male`), `Female` (`VocalGender.female`), `Mixed` (`VocalGender.mixed`).
  3. **Vocal Energy**: `Soft` (`VocalEnergy.soft`), `Mid` (`VocalEnergy.mid`), `Intense` (`VocalEnergy.intense`).
- **Acceptance Criteria**:
  1. Selecting any pill updates `studioFormProvider` via `setVocalVoices`, `setVocalGender`, or `setVocalEnergy`.
  2. `AdvancedOptionsAccordion` in Tab 0 (`Compose`) removes the duplicate multi-row `Voices`, `Vocal Gender`, and `Vocal Energy` sections (or collapses them into a single summary link to the `Voice` tab), eliminating `220dp` of redundant vertical scroll in `Compose`.

### `REQ-P56-VOX-02` — Compact 2×2 Dialect Inflection Grid in `BantuVoiceDeck` (`02:06–02:26` Video Fix)
- **Statement**: `BantuVoiceDeck` **SHALL** arrange the 4 Bantu dialect inflection sliders (`Syllable Stretch`, `Ancestral Vibrato`, `Call-and-Response`, `Cultural Ad-Libs`) inside a compact **2-Column × 2-Row Grid** (`Key('voice_dialect_grid_card')`, using `Wrap` with `tileWidth = (constraints.maxWidth - 10) / 2` when `constraints.maxWidth >= 300`).
- **Acceptance Criteria**:
  1. All 4 slider labels (`'Syllable Stretch'`, `'Ancestral Vibrato'`, `'Call-and-Response'`, `'Cultural Ad-Libs'`) and percentage readouts remain present and functional.
  2. Raw unicode emoji fallbacks in `_TimbreCard` are replaced with `PhosphorIcon(PhosphorIconsBold.microphoneStage)` when an image asset is unavailable.

### `REQ-P56-CRATE-01` — Fix 1-Character Vertical Text Crash in `CrateBrowserDeck` (`02:42–02:46` Video Fix)
- **Statement**: In `CrateBrowserDeck` (`apps/vhunambi_client/lib/features/studio/presentation/widgets/crate_browser_deck.dart`), the top header `Row` **SHALL**:
  1. Reduce `_VinylDiskWidget` diameter on mobile from `84px` to `52px` (`AppSpacing.sm` gap).
  2. Wrap the title `Column` (`'Heritage Crate Digging'`, `'Indigenous Sound Archive'`) in `Expanded` with `maxLines: 1` and `overflow: TextOverflow.ellipsis` (removing the raw `💿` emoji).
  3. Constrain `Key('crate_open_sketchpad_btn')` to a compact pill (`'Sketchpad'`, `PhosphorIconsBold.pianoKeys`, `maxWidth: 112dp`) so the title column always retains $\ge 150\text{dp}$ of horizontal width on a `360dp` screen.
- **Acceptance Criteria**:
  1. Rendering `CrateBrowserDeck` inside a `360x780dp` viewport produces zero 1-character vertical text wrapping (`'Heritage Crate Digging'` renders on a single horizontal line).
  2. `Key('crate_open_sketchpad_btn')` and `Key('crate_search_field')` remain present and functional.

### `REQ-P56-CRATE-02` — Unified 4-Mode `InlineCrateMpcWorkbench` & Deduplicated Tab 2 (`02:27–02:42` Video Fix)
- **Statement**: `InlineCrateMpcWorkbench` (`apps/vhunambi_client/lib/features/studio/presentation/widgets/inline_crate_mpc_workbench.dart`) **SHALL** provide a 4-segment mode selector with concise non-truncating labels:
  - Segment 0 (`Key('workbench_mode_crate')`): `'Crate'` (`PhosphorIconsBold.vinylRecord`) + header action `Key('studio_open_crate_btn')` (`'Full Crate'`) to open the full crate modal sheet.
  - Segment 1 (`Key('workbench_mode_mpc')`): `'8-Pad MPC'` (`PhosphorIconsBold.squaresFour`).
  - Segment 2 (`Key('workbench_mode_sketchpad')`): `'5-Ch Groove'` (`PhosphorIconsBold.pianoKeys`).
  - Segment 3 (`Key('workbench_mode_daw_upload')`): `'DAW Upload'` (`PhosphorIconsBold.uploadSimple`), which renders an inline stem/vocal upload launcher (`Key('studio_daw_uploader_btn')` calling `DirectDawVocalUploadSheet.show(context)`).
- **Acceptance Criteria**:
  1. `StudioView` Tab 2 removes the two duplicate standalone full-width buttons below `InlineCrateMpcWorkbench`, while preserving `Key('studio_open_crate_btn')` and `Key('studio_daw_uploader_btn')` inside the unified workbench so all existing tests pass.

---

## 4. Track C Functional Requirements: Non-Blocking Generation, Cognate Tag Fix & Studio Mini-Player Suppression

### `REQ-P56-GEN-01` — Eliminate Stuck Empty `"Result"` Skeleton Card (`02:04–02:48` Video Fix)
- **Statement**:
  1. `StudioFormNotifier` **SHALL** provide a `cancelLyricsReview()` method that resets `phase` to `GenerationPhase.idle` whenever `state.phase == GenerationPhase.generatingLyrics || state.phase == GenerationPhase.reviewingLyrics`.
  2. **WHEN** `LyricsReviewModal.show(context)` returns in `StudioActionBar._handleGenerate` (or when `LyricsReviewModal._handleClose` is invoked), **IF** `ref.read(studioFormProvider).phase == GenerationPhase.reviewingLyrics`, the system **SHALL** invoke `cancelLyricsReview()` so `phase` returns to `GenerationPhase.idle`.
  3. **WHILE** `generationProgressProvider == null` **AND** `phase == GenerationPhase.reviewingLyrics`, `StudioView` **SHALL NOT** render `GenerationPipelineCard`.
  4. **WHEN** `GenerationPipelineCard` is rendered (only on Tab 0 `Compose` when `generationProgress != null` or `phase` is `queued`/`generatingAudio`/`completed`/`error`), it **SHALL** wire `onNewSong` and a dismiss icon button (`Key('generation_pipeline_dismiss_btn')`) to reset both `generationProgressProvider` and `studioFormProvider` phase to `idle`.

### `REQ-P56-LYR-01` — Strip Bracketed Section Tags in Bantu Cognate Finder (`01:54` Video Fix)
- **Statement**: **WHEN** `LyricsReviewModal._openCognateFinder` extracts lyric words from `LyricsReviewDraft`, it **SHALL** read from `draft.allLines.join(' ')` AND strip any bracketed metadata tags matching `RegExp(r'\[[^\]]*\]')` and structural section keywords (`intro`, `verse`, `chorus`, `bridge`, `outro`, `hook`) before selecting candidate Bantu words.
- **Acceptance Criteria**:
  1. Opening the Bantu Cognate & Rhyme Finder (`Key('lyrics_cognate_finder_btn')`) on a draft beginning with `[Intro]\nNdi khou vha fhululedza` **NEVER** outputs `intro (ve) ➔ intro (zu)`; instead it analyzes actual lyric words (`fhululedza`, `vhutshilo`, `vhuthu`, `mbilu`, `takala`).

### `REQ-P56-MINI-01` — Suppress `MiniPlayerHost` in Studio Tab & Studio Modals (`03:01–03:22` Video Fix)
- **Statement**:
  1. `MiniPlayerHost._shouldHide` (`apps/vhunambi_client/lib/features/player/presentation/widgets/mini_player_host.dart`) **SHALL** watch `appNavigationTabProvider` and return `true` whenever `activeTab == 2` (the Studio Cockpit tab).
  2. `MelodySketchpadModal` and `LyricsReviewModal` **SHALL** increment `modalSheetOpenCountProvider` in `initState` (via `addPostFrameCallback`) and decrement it in `dispose` (guarded against `< 0`), matching `SongDnaNodeTreeModal`.
- **Acceptance Criteria**:
  1. `MiniPlayerHost` renders `SizedBox.shrink()` whenever the user is on Tab 2 (`StudioView`) or inside `MelodySketchpadModal`, `LyricsReviewModal`, or `SongDnaNodeTreeModal`.

---

## 5. Track D Functional Requirements: Mobile-First 3D Biome Overhaul (`SongDnaNodeTreeModal`)

### `REQ-P56-BIOME-01` — Fix `BiomeTopBar` 1-Letter Vertical Squash (`00:09–00:15` & `03:22` Video Fix)
- **Statement**: In `BiomeTopBar` (`apps/vhunambi_client/lib/features/studio/presentation/widgets/biome/biome_top_bar.dart`):
  1. The left title `Column` (`'SONG DNA QUANTUM TREE'`, `'3D BIOME'`, `'Explore the Living DNA of Music'`) **SHALL** wrap its inner `Row` and `Text` widgets with `Flexible` / `maxLines: 1` / `overflow: TextOverflow.ellipsis`.
  2. The right `Now Playing` transport capsule **SHALL** be constrained via `ConstrainedBox(constraints: BoxConstraints(maxWidth: isMobile ? 148 : 240))` and wrap its inner title `Column` (`'Now Playing'`, `trackTitle`) in `Flexible` with `maxLines: 1` and `overflow: TextOverflow.ellipsis`.
- **Acceptance Criteria**:
  1. Passing a 120-character prompt as `trackTitle` on a `360dp`-wide mobile viewport never causes `'SONG DNA QUANTUM TREE'` or `'Explore the Living DNA of Music'` to wrap vertically character-by-character.

### `REQ-P56-BIOME-02` — Mobile On-Demand Tooltip Popovers for `Controls` and `Layers` (`03:22–03:56` Video Fix)
- **Statement**:
  1. **WHILE** `SongDnaNodeTreeModal` is rendered on a mobile viewport (`constraints.maxWidth < 680`) in Overview Mode (`_focusedBranchRootId == null`), `BiomeInteractiveControlsBar` (`Key('biome_controls_bar')`) and `BiomeNetworkLayersFilter` (`Key('biome_network_layers_filter')`) **SHALL NOT** be permanently stacked over the 3D mushroom canvas.
  2. Instead, the top HUD overlay bar (`top: 10, left: 12, right: 12`) **SHALL** render two compact toggle pills:
     - **`Controls`** (`Key('biome_controls_popover_btn')`, `PhosphorIconsBold.compass`) — toggles `_showMobileControlsPopover`.
     - **`Layers`** (`Key('biome_layers_popover_btn')`, `PhosphorIconsBold.stack`) — toggles `_showMobileLayersPopover`.
  3. **WHEN** a popover is closed on mobile, the underlying `BiomeInteractiveControlsBar` / `BiomeNetworkLayersFilter` **SHALL** be kept mounted inside an `Offstage` (or zero-hit popover container when open) so that only the active popover card floats below the top bar, and tapping the 3D canvas automatically dismisses any open popover.
  4. **WHILE** on a desktop viewport (`constraints.maxWidth >= 680`), `BiomeInteractiveControlsBar`, `BiomeNetworkLayersFilter`, and `SongJourneyTimelineScrubber` **SHALL** remain visible in their corner docks so all existing desktop widget tests (`Size(1280, 1024)`) pass without modification.

### `REQ-P56-BIOME-03` — Single Unified Bottom Inspector Sheet & Clean Overview Canvas (`00:09–00:15` & `03:33` Video Fix)
- **Statement**:
  1. **WHILE** in Overview Mode (`_focusedBranchRootId == null`), `_buildDeclutteredReceptorTarget` **SHALL** render a translucent hit-box (`Container(color: Colors.transparent)` with `HitTestBehavior.translucent`) for all `Key('song_dna_bubble_${node.id}')` nodes so that **zero legacy rectangular text pills** (`Amapiano • MEDIUM`, `Venda Folk Elder`, `+ Attach Groove`) float over the 6 circular mushroom badges (`Key('biome_cluster_badge_${domain.name}')`), while keeping all `Key('song_dna_bubble_${node.id}')` findable and tappable for Phase 51/52 tests.
  2. **WHEN** a mushroom cluster or branch node is focused on a mobile viewport (`constraints.maxWidth < 680`), `SongDnaNodeTreeModal` **SHALL** render **ONE** unified, scrollable bottom inspector container (`maxHeight: 232dp`) housing both `BiomeClusterInspectorPanel` (`Key('biome_cluster_inspector_panel')`) and the quick-action mutators (`Key('song_dna_quick_action_card')`) rather than stacking a top-right panel and a bottom card simultaneously over the 3D canvas.

### `REQ-P56-CAM-01` — Unified 6-DOF Camera Orbit, Pinch-Zoom, Auto-Rotate & 450ms Dolly-Zoom (`03:35–03:56` Video Fix)
- **Statement**:
  1. `_zoomIn()` (`Key('song_dna_zoom_in_btn')`), `_zoomOut()` (`Key('song_dna_zoom_out_btn')`), and `_resetCamera()` (`Key('song_dna_reset_camera_btn')`) **SHALL** directly update `biomeCameraProvider.notifier` (`setDistance` / `resetOverview`) in addition to legacy projection state.
  2. The 3D canvas `GestureDetector` **SHALL** implement `onScaleStart` and `onScaleUpdate`:
     - When `details.pointerCount == 1`, it **SHALL** call `biomeCameraProvider.notifier.addOrbitDelta(deltaYaw: -details.focalPointDelta.dx * 0.0085, deltaPitch: details.focalPointDelta.dy * 0.0075)`.
     - When `details.pointerCount >= 2`, it **SHALL** call `biomeCameraProvider.notifier.setDistance((_scaleStartDistance / details.scale).clamp(180.0, 650.0))`.
  3. **WHILE** `biomeCamera.isAutoRotating == true`, `_biomeAnimationController` **SHALL** advance `biomeCameraProvider.notifier.stepAutoRotate(0.0065)` on every animation tick.
  4. **WHEN** `_focusBiomeCluster(domain)` or `_returnToOverview()` is triggered, `SongDnaNodeTreeModal` **SHALL** animate `BiomeCameraState` smoothly over `450ms` (`Curves.easeOutCubic`) from the current `(target, yaw, pitch, distance)` to the target mushroom's 3D apex $(\mathbf{T}_k^*, \theta_k^*, \phi_k^*, R_k^* = 190.0)$.

---

## 6. Non-Functional & Governance Requirements (`REQ-P56-NFR-*`)

- **`REQ-P56-NFR-01` (60 FPS Mobile Frame Budget)**: All 3D Biome camera dolly-zoom interpolations, auto-rotate ticks, and Studio Cockpit scroll transitions **SHALL** execute within $\le 5.5\text{ms}$ per frame on ARM64 mobile hardware (`<= 16.6ms` 60 FPS budget).
- **`REQ-P56-NFR-02` (Zero Raw Emojis — `STD-UIUX-001`)**: All refactored widgets in `CrateBrowserDeck`, `ReferenceAudioDropzone`, `BantuVoiceDeck`, `InlineCrateMpcWorkbench`, and `SongDnaNodeTreeModal` **SHALL** use authentic `PhosphorIcon` glyphs (`package:phosphor_icons/phosphor_icons.dart`), preserving only the single test-locked string `'⚡ Synthesize Song from 3D DNA'` required by `phase51_bioluminescent_organelle_3d_test.dart` line 231.
- **`REQ-P56-NFR-03` (100% Legacy Test Suite Parity)**: All existing tests in `studio_view_test.dart`, `phase51_bioluminescent_organelle_3d_test.dart`, `phase52_macro_organelle_and_stem_lock_test.dart`, `phase53_organic_mycelium_3d_biome_test.dart`, `phase54_cockpit_biome_quantum_entanglement_test.dart`, and `phase55_audio_reactive_biome_player_test.dart` **SHALL** pass 100% without removing any existing test assertions.

---

## 7. Granular Requirement-to-Test Traceability Matrix

```
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                         PHASE 56 REQUIREMENT-TO-TEST TRACEABILITY MATRIX                                 │
├────────────────────┬──────────────────────────────────────────────┬──────────────────────────────────────┤
│ Requirement ID     │ Primary Implementation File                  │ Automated Verification Test Case     │
├────────────────────┼──────────────────────────────────────────────┼──────────────────────────────────────┤
│ REQ-P56-COMP-01    │ `studio_view.dart`, `progress_tracker.dart`  │ `phase56_test.dart`: Test 1 (Prompt- │
│ REQ-P56-COMP-02    │ `cockpit_quantum_entanglement_rack.dart`     │  First hierarchy & 2x3 Stem Matrix)  │
├────────────────────┼──────────────────────────────────────────────┼──────────────────────────────────────┤
│ REQ-P56-COMP-03    │ `reference_audio_dropzone.dart`              │ `phase56_test.dart`: Test 2 (Non-    │
│ REQ-P56-COMP-04    │ `multilingual_language_selector.dart`,       │  truncated Reference Audio bar &     │
│                    │ `advanced_options_accordion.dart`            │  compact 3-col Language/Mood chips)  │
├────────────────────┼──────────────────────────────────────────────┼──────────────────────────────────────┤
│ REQ-P56-VOX-01     │ `bantu_voice_deck.dart`                      │ `phase56_test.dart`: Test 3 (Voice   │
│ REQ-P56-VOX-02     │ `advanced_options_accordion.dart`            │  Ensemble header & 2x2 dialect grid) │
├────────────────────┼──────────────────────────────────────────────┼──────────────────────────────────────┤
│ REQ-P56-CRATE-01   │ `crate_browser_deck.dart`,                   │ `phase56_test.dart`: Test 4 (360dp   │
│ REQ-P56-CRATE-02   │ `inline_crate_mpc_workbench.dart`            │  CrateBrowserDeck zero vertical wrap │
│                    │                                              │  & 4-mode InlineCrateMpcWorkbench)   │
├────────────────────┼──────────────────────────────────────────────┼──────────────────────────────────────┤
│ REQ-P56-GEN-01     │ `studio_form_provider.dart`,                 │ `phase56_test.dart`: Test 5 (Closing │
│ REQ-P56-LYR-01     │ `studio_action_bar.dart`,                    │  LyricsReviewModal resets phase to   │
│                    │ `lyrics_review_modal.dart`,                  │  idle & Cognate Finder strips `[..]`)│
│                    │ `generation_pipeline_card.dart`              │                                      │
├────────────────────┼──────────────────────────────────────────────┼──────────────────────────────────────┤
│ REQ-P56-MINI-01    │ `mini_player_host.dart`,                     │ `phase56_test.dart`: Test 6 (Mini-   │
│                    │ `melody_sketchpad_modal.dart`                │  player hidden in Tab 2 & Sketchpad) │
├────────────────────┼──────────────────────────────────────────────┼──────────────────────────────────────┤
│ REQ-P56-BIOME-01   │ `biome_top_bar.dart`,                        │ `phase56_test.dart`: Test 7 (360dp   │
│ REQ-P56-BIOME-02   │ `song_dna_node_tree_modal.dart`              │  BiomeTopBar ellipsis, mobile        │
│ REQ-P56-BIOME-03   │ `biome_cluster_inspector_panel.dart`         │  Controls/Layers popovers & single   │
│                    │                                              │  bottom inspector drawer)            │
├────────────────────┼──────────────────────────────────────────────┼──────────────────────────────────────┤
│ REQ-P56-CAM-01     │ `biome_camera_controller.dart`,              │ `phase56_test.dart`: Test 8 (6-DOF   │
│ REQ-P56-NFR-01..03 │ `song_dna_node_tree_modal.dart`              │  orbit, pinch-zoom, auto-rotate &    │
│                    │                                              │  450ms dolly-zoom into mushroom apex)│
└────────────────────┴──────────────────────────────────────────────┴──────────────────────────────────────┘
```

---

## 8. Error Resilience, Boundary Clamping & Edge-Case Guards (`REQ-P56-ERR-*`)

### `REQ-P56-ERR-01` — Gimbal Lock & Camera Distance Boundary Clamping
- **IF** a 1-finger vertical tilt gesture (`deltaPitch`) attempts to rotate $\phi_{\text{pitch}}$ beyond $[15^\circ, 75^\circ]$ ($[0.2618\text{ rad}, 1.3090\text{ rad}]$), **THEN** `BiomeCameraState.copyWith` **SHALL** clamp $\phi_{\text{pitch}}$ strictly within $[15^\circ, 75^\circ]$ so the camera never flips upside-down or dips beneath the $Y = h(X, Z) \ge 0$ terrain surface.
- **IF** a 2-finger pinch-zoom gesture (`details.scale`) produces an extreme scale factor ($s \to 0$ or $s \to \infty$), **THEN** `BiomeCameraState` **SHALL** clamp `distance` strictly within $[180.0\text{dp}, 650.0\text{dp}]$ and `zoom` within $[0.65, 2.20]$.

### `REQ-P56-ERR-02` — Modal Sheet Disposal Race & Negative Reference Count Guard
- **WHEN** `MelodySketchpadModal`, `LyricsReviewModal`, or `SongDnaNodeTreeModal` is disposed, the decrement of `modalSheetOpenCountProvider` **SHALL** be wrapped in a `try { ... } catch (_) {}` block and clamped via `math.max(0, current - 1)` so widget test teardown (`ProviderContainer.dispose()`) never throws a `StateError` or produces a negative count.

### `REQ-P56-ERR-03` — Extreme Narrow Viewport & Long String Overflow Guard
- **IF** a user enters a 250-character prompt or selects a long regional genre/sample name on a narrow `320dp`–`360dp` screen, **THEN**:
  1. `BiomeTopBar` **SHALL** constrain its right `Now Playing` capsule to `maxWidth: 148dp` on mobile (`< 680dp`) and truncate `trackTitle` with `TextOverflow.ellipsis` (`maxLines: 1`).
  2. `CrateBrowserDeck` **SHALL** constrain its right Sketchpad action pill to `maxWidth: 112dp` and render `'Heritage Crate Digging'` with `maxLines: 1` and `TextOverflow.ellipsis`, preventing any multi-line character-by-character vertical text wrapping.

### `REQ-P56-ERR-04` — Empty or Bracket-Only Lyrics Cognate Fallback
- **IF** `LyricsReviewDraft` contains only bracketed headers (`[Intro]`, `[Verse 1]`) or words shorter than 3 characters, **THEN** `_openCognateFinder` **SHALL** fall back to seeding canonical Bantu lyric stems (`vhutshilo`, `vhuthu`, `mbilu`, `fhululedza`, `takala`) for the active `BantuLanguage` so the Cognate Finder sheet always displays meaningful cross-branch Bantu phonetic correspondences.

---

## 9. Legacy Regression Preservation Matrix (Phases 50–55 & Studio)

```
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                     LEGACY TEST SUITE COMPATIBILITY & INVARIANT PRESERVATION TABLE                       │
├────────────────────────────────────────────────────┬─────────────────────────────────────────────────────┤
│ Existing Test Suite File                           │ Protected Invariants & Keys in Phase 56             │
├────────────────────────────────────────────────────┼─────────────────────────────────────────────────────┤
│ `test/features/studio/studio_view_test.dart`       │ • `find.text('Describe your song')` at top of Tab 0 │
│                                                    │ • `find.text('Inspire Me')` populates first         │
│                                                    │   `TextField` (`PromptInputBox`)                    │
│                                                    │ • `find.text('Reference Audio (optional)')` intact  │
│                                                    │ • `find.text('Genre')`, `'Language'`, `'Advanced    │
│                                                    │   Options'`, `'Write Lyrics First'`, `'Public'`     │
├────────────────────────────────────────────────────┼─────────────────────────────────────────────────────┤
│ `test/features/studio/`                            │ • `Key('song_dna_3d_tree_modal')` opaque `#020710`  │
│ `phase51_bioluminescent_organelle_3d_test.dart`    │ • `modalSheetOpenCountProvider > 0` while open      │
│                                                    │ • `Key('song_dna_synthesize_btn')` with exact label │
│                                                    │   `'⚡ Synthesize Song from 3D DNA'`                 │
│                                                    │ • `Key('song_dna_bubble_node_inst_logdrum')` hit    │
│                                                    │   target selects node & shows `QuickActionCard`     │
├────────────────────────────────────────────────────┼─────────────────────────────────────────────────────┤
│ `test/features/studio/`                            │ • `Key('song_dna_bubble_node_beat_tempo')`,         │
│ `phase52_macro_organelle_and_stem_lock_test.dart`  │   `node_vocal_persona`, `node_sketchpad_groove`,    │
│                                                    │   `node_spatial_atmosphere` present in Overview     │
│                                                    │ • `Key('song_dna_return_overview_btn')` in Focus    │
│                                                    │ • `Key('song_dna_add_instrument_leaf_btn')` &       │
│                                                    │   `Key('song_dna_stem_lock_selector')` intact       │
├────────────────────────────────────────────────────┼─────────────────────────────────────────────────────┤
│ `test/features/studio/`                            │ • `Key('biome_top_bar')`, `Key('biome_controls_bar')│
│ `phase53_organic_mycelium_3d_biome_test.dart`      │ • `Key('biome_network_layers_filter')`              │
│                                                    │ • `Key('biome_song_journey_scrubber')`              │
│                                                    │ • 6 `Key('biome_cluster_badge_${domain.name}')`     │
│                                                    │ • `Key('biome_cluster_inspector_panel')`            │
├────────────────────────────────────────────────────┼─────────────────────────────────────────────────────┤
│ `test/features/studio/`                            │ • `Key('cockpit_quantum_entanglement_rack')`        │
│ `phase54_cockpit_biome_quantum_entanglement_test`  │ • 6 `Key('cockpit_domain_card_${domain.name}')`,    │
│                                                    │   `Key('cockpit_stem_lock_${domain.name}')`, and    │
│                                                    │   `Key('cockpit_jump_3d_${domain.name}')`           │
│                                                    │ • `Key('cockpit_inline_crate_mpc_workbench')`       │
├────────────────────────────────────────────────────┼─────────────────────────────────────────────────────┤
│ `test/features/player/`                            │ • `Key('player_hero_mode_selector')`,               │
│ `phase55_audio_reactive_biome_player_test.dart`    │   `Key('player_living_biome_viewport')`,            │
│                                                    │   `Key('stem_mixer_biome_strip')`, and              │
│                                                    │   `Key('track_detail_living_biome_card')` untouched │
└────────────────────────────────────────────────────┴─────────────────────────────────────────────────────┘
```
