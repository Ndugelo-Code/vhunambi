# Phase 46 Requirements: Kinetic Reels V3, Live Delta Sync Coordinator, RunPod GPU V2 Router & Video UI Sweeps

> **Target Workspaces:** `apps/vhunambi_client`, `apps/vhunambi_api`, `tools/zr-studio-gpu`  
> **Status:** 🟡 SPECIFICATION & ACCEPTANCE CRITERIA  
> **Standard:** RFC 2119 & EARS Compliant

---

## 1. Exhaustive Domain Glossary

- **Kinetic_Reel**: A vertical 9:16 interactive audio performance format powered by 60 FPS Song DNA canvas and multi-stem audio playback.
- **KineticReelsModal**: Full-screen Flutter modal managing the vertical reel swipe feed, audio pool lifecycle, and on-reel interactions.
- **Split_Screen_Duet**: Visual composition displaying two co-creators (Originator and Remixer) simultaneously with audio-reactive avatars and royalty split metrics.
- **Originator**: The creator who authored the original song, vocal hook, or stem composition.
- **Co_Creator**: The artist who remixed, added an open-verse vocal, or flipped stems on an existing composition.
- **Co_Creation_Split**: Transparent royalty distribution badge (e.g. 70% Originator / 30% Remixer) calculated from track provenance.
- **Stem_Isolation_Bar**: Translucent 4-pill overlay above track info in Kinetic Reels allowing viewers to solo or mute individual audio stems in real time.
- **Stem_Pill**: Interactive pill control representing one of four separated audio stems: Vocals, Log-Drum/Bass, Drums, or Chords/Melodic.
- **StemMixerNotifier**: Global Riverpod state notifier managing gains, mute flags, solo flags, and DSP effects across audio channels.
- **Vhunambi_Vision_Stage**: Procedural and textured background canvas featuring heritage crate art, bass-reactive radial pulse rings, and cinema vignettes.
- **Bass_Reactive_Pulse**: Visual radial glow that dynamically expands and contracts in response to low-frequency MMO modulation curves.
- **EdgeSyncCoordinator**: Client-side background coordinator that synchronizes local state notifiers with backend SQLite WAL persistence.
- **SyncOutboxService**: Durable local Hive queue recording user mutations before network transmission.
- **SyncMutationRecord**: Immutable record containing an idempotency key, entity type, action, payload, and retry count.
- **Delta_Seq_Cursor**: Monotonically increasing sequence integer representing the client's current synchronization frontier.
- **Idempotency_Key**: Unique UUID/SHA string preventing duplicate entity creation or double-tipping on network retries.
- **ETag**: HTTP cache header derived from SQLite WAL sequence number enabling HTTP 304 Not Modified responses.
- **RunPod_V2_Master_Router**: Central Python entrypoint (`tools/zr-studio-gpu/handler.py`) orchestrating all 5 stages of music synthesis.
- **ACE_Step_Synthesis**: Stage 1 audio generation producing base master audio from structured song specifications and sketchpad audio.
- **Demucs_Stem_Separation**: Stage 2 audio processing splitting master audio into 4 discrete stems (vocals, drums, bass, other) via `htdemucs`.
- **Seed_VC_Voice_Conversion**: Stage 3 zero-shot vocal cloning applying Bantu timbre profiles and formant shifts to isolated vocals.
- **Stem_Mastering_DSP**: Stage 4 commercial mastering applying regional presets, sub-harmonic log-drum synthesis, and LUFS limiting.
- **MMO_Telemetry_Extraction**: Stage 5 feature extraction generating 60 Hz quantized `Uint8` Base64 modulation curves and transient events.
- **Stage_Metrics**: Structured array of verifiable stage timing, execution flags, and cryptographic input/output hashes.
- **Cinema_Dark_Lock**: Architectural rule forcing full-screen media overlays into `AppTheme.darkTheme` with white text dropshadows.
- **Touch_Ergonomics**: Requirement that all interactive elements have minimum 44×44px hit bounds.

---

## 2. Requirements Specification

### 2.1 Track A: Residual Video UI Defect Eradication

#### Requirement 1: Profile Banner Header Share Button Contrast
**User Story:** As a user browsing artist profiles in Light Mode, I want the Share button to be clearly visible, so that I can easily share artist profiles to social networks.
##### Acceptance Criteria
1. `REQ-P46-UI-01.1`: THE `ProfileBannerHeader` share button SHALL bind its icon color to `AppColors.textPrimaryOf(context)` and border to `AppColors.borderSubtleOf(context)`.
2. `REQ-P46-UI-01.2`: THE `ArtistProfileView` top app bar share action button SHALL bind its icon color to `AppColors.textPrimaryOf(context)`.
3. `REQ-P46-UI-01.3`: WHEN rendered in Light Mode, THE share button icon SHALL maintain a minimum contrast ratio of 4.5:1 against `AppColors.surfaceElevatedOf(context)`.

#### Requirement 2: CreateKineticPostSheet 80×80 Image Preview Offline Fallback
**User Story:** As a creator attaching photos to a Kinetic Post while offline, I want the thumbnail preview to look polished, so that I never see broken-image placeholders.
##### Acceptance Criteria
1. `REQ-P46-UI-02.1`: THE `CreateKineticPostSheet` attached image thumbnail SHALL render an offline procedural Vhunambi Vision container when image loading fails.
2. `REQ-P46-UI-02.2`: THE offline fallback container SHALL display a vibrant gradient (`AppColors.brandPrimary` to `AppColors.badgeCyan`), `AppAssets.heritageCrateCover` at low opacity, and a centered Phosphor sparkle icon.
3. `REQ-P46-UI-02.3`: THE thumbnail delete button (`Key('kpost_image_delete_$idx')`) SHALL remain positioned at top-right with a 44×44px hit target.

#### Requirement 3: Co-Sign Milestone Pill Unclipped Placement
**User Story:** As a fan exploring the social feed, I want the Co-Sign milestone badge to be fully legible, so that I can see community voting progress without truncated text.
##### Acceptance Criteria
1. `REQ-P46-UI-03.1`: THE `ExploreSocialPostCard` SHALL place `_buildCosignButton` (`Key('post_cosign_btn_${post.id}')`) in a dedicated horizontal `Wrap` row alongside `Open Stems · N Remixes` below the caption.
2. `REQ-P46-UI-03.2`: THE author header subtitle row SHALL NOT contain the Co-Sign button.
3. `REQ-P46-UI-03.3`: WHEN the viewport width is as narrow as 360dp, THE Co-Sign button SHALL display full text `'🔥 Co-Sign · 18/25'` or `'🔥 Graduated · 25'` without truncation or ellipsis.

---

### 2.2 Track B: Kinetic Reels V3 (Duets, Vision Stage & Stem Bar)

#### Requirement 4: Vhunambi Vision Animated Stage
**User Story:** As a music video viewer, I want Kinetic Reels to feature a rich, dynamic background, so that the music experience feels visually immersive rather than an empty dark void.
##### Acceptance Criteria
1. `REQ-P46-REEL-01`: THE `KineticReelsModal` SHALL render a `VhunambiVisionAnimatedStage` behind the 60 FPS kinetic lyrics canvas.
2. `REQ-P46-REEL-02`: THE stage SHALL incorporate `AppAssets.heritageCrateCover` rendered with a maximum opacity of 24% blended over the genre background gradient.
3. `REQ-P46-REEL-03`: THE stage SHALL render a radial pulse ring whose scale and glow intensity modulate dynamically with low-frequency audio telemetry from `frameModulationSnapshotProvider`.

#### Requirement 5: Split-Screen Open-Verse Duet Layout
**User Story:** As a creator viewing a remixed open-verse reel, I want to see both the original creator and remixer side-by-side, so that collaboration and royalty splits are celebrated.
##### Acceptance Criteria
1. `REQ-P46-REEL-04`: WHEN viewing a `PublishedClip` with `parentCreatorHandle != null` OR `remixGenerationDepth > 0`, THE `KineticReelsModal` SHALL render `ReelDuetSplitStage` (`Key('reel_duet_split_stage_${clip.id}')`).
2. `REQ-P46-REEL-05`: THE `ReelDuetSplitStage` SHALL display both Originator and Co-Creator avatars with audio-reactive pulse borders and their respective creator handles.
3. `REQ-P46-REEL-06`: THE `ReelDuetSplitStage` SHALL display a `CoCreationSplitBadge` showing the transparent royalty distribution (e.g. `'70/30 Co-Creation Split'`).

#### Requirement 6: On-Reel Interactive 4-Stem Isolation Bar
**User Story:** As an Amapiano listener, I want to solo or mute the log-drum or vocals while watching a reel, so that I can analyze production stems in real time.
##### Acceptance Criteria
1. `REQ-P46-REEL-07`: THE `KineticReelsModal` SHALL render `ReelStemToggleBar` (`Key('reel_stem_toggle_bar')`) positioned above the bottom track info.
2. `REQ-P46-REEL-08`: THE `ReelStemToggleBar` SHALL display 4 interactive stem pills:
   - `[ Vocals ]` (`Key('reel_stem_pill_vocals')`)
   - `[ Log-Drum ]` (`Key('reel_stem_pill_bass')`)
   - `[ Drums ]` (`Key('reel_stem_pill_drums')`)
   - `[ Chords ]` (`Key('reel_stem_pill_melodic')`)
3. `REQ-P46-REEL-09`: WHEN a user taps a stem pill, THE system SHALL toggle mute/solo for that stem channel via `stemMixerProvider.notifier`.
4. `REQ-P46-REEL-10`: WHEN a stem is muted, THE stem pill SHALL render with reduced opacity (40%) and a strikethrough or muted icon indicator.

---

### 2.3 Track C: Live Bi-Directional Client $\leftrightarrow$ SQLite Delta Sync Coordinator

#### Requirement 7: Client Mutation Auto-Enqueueing
**User Story:** As an artist using Vhunambi on mobile, I want my posts, co-signs, and wallet transactions to be safely preserved, so that no work is lost if my network drops.
##### Acceptance Criteria
1. `REQ-P46-SYNC-01`: WHEN `SocialFeedPostsNotifier.addPost()`, `repostPost()`, or `cosignPost()` is called, THE system SHALL enqueue an idempotent `SyncMutationRecord` into `SyncOutboxService`.
2. `REQ-P46-SYNC-02`: WHEN `CreatorWalletNotifier.sendGift()`, `topUpCoins()`, or `requestPayout()` is called, THE system SHALL enqueue an idempotent `SyncMutationRecord` into `SyncOutboxService`.
3. `REQ-P46-SYNC-03`: WHEN `MarketplaceBeatsNotifier.licenseBeat()` is called, THE system SHALL enqueue an idempotent `SyncMutationRecord` into `SyncOutboxService`.

#### Requirement 8: EdgeSyncCoordinator & Sync Now Trigger
**User Story:** As a user in settings, I want to see my sync status and manually trigger synchronization, so that I know my profile and earnings are up to date on all devices.
##### Acceptance Criteria
1. `REQ-P46-SYNC-04`: THE `EdgeSyncCoordinator.syncNow()` SHALL flush all pending outbox mutations to `POST /api/v1/sync/mutations`.
2. `REQ-P46-SYNC-05`: FOLLOWING a successful flush, `EdgeSyncCoordinator` SHALL fetch incremental server deltas from `GET /api/v1/sync/delta?since_seq=<lastSeq>` and apply updated entities to local state.
3. `REQ-P46-SYNC-06`: IF the device is offline or the backend server is unreachable, `syncNow()` SHALL gracefully return an offline status without throwing unhandled exceptions.
4. `REQ-P46-SYNC-07`: THE `ProfileSettingsDrawer` SHALL render an interactive `[ Sync Now ]` button (`Key('settings_sync_now_btn')`) adjacent to the Edge-Sync badge that invokes `EdgeSyncCoordinator.syncNow()`.

---

### 2.4 Track D: Unified RunPod GPU V2 Master Pipeline Router

#### Requirement 9: 5-Stage Sequential GPU Orchestration
**User Story:** As a sound engineer, I want all GPU generation jobs to execute full vocal conversion, stem separation, and mastering, so that songs sound commercially competitive.
##### Acceptance Criteria
1. `REQ-P46-GPU-01`: THE `runpod_handler` in `tools/zr-studio-gpu/handler.py` SHALL orchestrate 5 sequential stages:
   - `Stage 1: ace_step_synthesis`
   - `Stage 2: demucs_stem_separation`
   - `Stage 3: seed_vc_voice_conversion`
   - `Stage 4: stem_mastering_dsp`
   - `Stage 5: mmo_telemetry_extraction`
2. `REQ-P46-GPU-02`: WHEN `svc_config` or `sound_signature_dna` is present in `job_input`, `handler.py` SHALL execute Stage 3 via `convert_vocal_stem_with_seed_vc`.
3. `REQ-P46-GPU-03`: `handler.py` SHALL execute Stage 4 via `master_stems_to_commercial_target` applying the Phase 25 regional mastering recipe and limiting to target LUFS (-9.5 club / -14.0 streaming).
4. `REQ-P46-GPU-04`: `handler.py` SHALL record verifiable `stage_metrics` containing `name`, `executed` (boolean), `duration_ms` (integer), `input_sha256`, and `output_sha256` for every stage.
5. `REQ-P46-GPU-05`: `handler.py` SHALL upload the master audio, separated stems, stems ZIP archive, and Master Media Object v2.0 manifest to Cloudflare R2 and notify the API webhook.

---

### 2.5 Non-Negotiable Invariants

- **`REQ-P46-TOUCH-01`**: All stem pills, share buttons, sync buttons, and duet cards SHALL maintain minimum 44×44px interactive hit bounding boxes.
- **`REQ-P46-CINEMA-01`**: All `KineticReelsModal` overlays, stem bars, and duet headers SHALL be locked into `AppTheme.darkTheme` with white text drop shadows.
- **`REQ-P46-PERF-01`**: The animated vision stage and stem mixer integration SHALL sustain 60 FPS without memory leaks or unmanaged animation ticker timers.

---

## 3. Requirements Traceability Matrix

| Requirement ID | Capability Description | Target Code Files | Target Test File | Verification Gate |
|---|---|---|---|---|
| `REQ-P46-UI-01` | Light Mode Profile Share Button Contrast | `profile_banner_header.dart`, `artist_profile_view.dart` | `phase46_reels_v3_and_edge_sync_test.dart` | Widget test in Light Mode |
| `REQ-P46-UI-02` | Offline Vision Thumbnail Fallback | `create_kinetic_post_sheet.dart` | `phase46_reels_v3_and_edge_sync_test.dart` | Error image fallback test |
| `REQ-P46-UI-03` | Unclipped Co-Sign Milestone Pill | `explore_social_post_card.dart` | `phase46_reels_v3_and_edge_sync_test.dart` | Narrow viewport card test |
| `REQ-P46-REEL-01..03` | Vhunambi Vision Animated Stage | `kinetic_reels_modal.dart` | `phase46_reels_v3_and_edge_sync_test.dart` | Modal visual background test |
| `REQ-P46-REEL-04..06` | Split-Screen Duet Stage | `kinetic_reels_modal.dart` | `phase46_reels_v3_and_edge_sync_test.dart` | Remixed clip duet header test |
| `REQ-P46-REEL-07..10` | 4-Stem Toggle Isolation Bar | `kinetic_reels_modal.dart` | `phase46_reels_v3_and_edge_sync_test.dart` | Stem solo/mute tap test |
| `REQ-P46-SYNC-01..07` | Client Mutation Sync & Settings Trigger | `edge_sync_coordinator.dart`, `profile_settings_drawer.dart` | `phase46_reels_v3_and_edge_sync_test.dart` | Outbox enqueue & syncNow test |
| `REQ-P46-GPU-01..05` | RunPod 5-Stage GPU Master Router | `tools/zr-studio-gpu/handler.py`, `apps/vhunambi_api` | `phase46_gpu_pipeline_and_sync.test.ts` | Backend node test |

