# Phase 80 Requirements — Studio Cockpit V6 Glass Overhaul, `vhunambi.com` Parity & `StudioGenerationContractV6`

> **Document ID:** `REQ-PHASE-80`  
> **Phase Folder:** `docs/phases/phase_80_studio_cockpit_v6_and_production_contract/`  
> **Predecessor Audit:** [`PHASE80_STUDIO_COCKPIT_V6_AND_PRODUCTION_CONTRACT_AUDIT.md`](../../audits/PHASE80_STUDIO_COCKPIT_V6_AND_PRODUCTION_CONTRACT_AUDIT.md)  
> **Conventions:** EARS (`WHEN`, `WHILE`, `IF...THEN`, `WHERE`) and RFC-2119 (`SHALL`, `MUST`, `SHOULD`, `MAY`).

---

## 1. Document Scope & Core Invariants

This document specifies all verifiable functional, API contract, database persistence, visual ergonomics, and testability requirements for **Phase 80**.

1. **Zero Throwaway Work:** Every UI knob introduced in Phase 80 SHALL serialize losslessly into `POST /v1/generations` (`StudioGenerationContractV6`), persist in Supabase `public.generation_jobs` & SQLite `vhunambi_db.ts`, and forward cleanly into `runpod_adapter.ts` for Phase 81 (`MiniMax Music 3.0` + `ACE-Step 1.5 XL` on RunPod `L40S 48GB`) and Phase 82 (`BS-RoFormer` + Neural `Seed-VC` + `Matchering 2.0`).
2. **Commercial Compliance Invariant:** `YuE2` (`CC BY-NC 4.0`) SHALL NOT appear in any enum, route, or payload. Any job routed to `minimax_music_3` MUST carry `attributionTag: 'MiniMax-Music3'` through DB persistence, API response, and UI credit badge rendering.
3. **Zero Regression Invariant:** Existing Studio test keys (`studio_tab_compose`, `studio_tab_voice`, `studio_tab_crate_mpc`, `workbench_mode_*`, `voice_ensemble_header_card`, `voice_config_*`, `dropzone_upload_audio_btn`, `studio_preset_chip_0..2`, `lyrics_approve`, etc.) and `ILyricsGenerationService` method signatures MUST remain backward-compatible.

---

## 2. Backend Contract, Persistence & Async Reliability Requirements (`REQ-P80-CONTRACT-*`)

### `REQ-P80-CONTRACT-01` — Lossless `StudioGenerationContractV6` Request Schema
**WHEN** a client submits `POST /v1/generations`, the Worker (`generation_routes.ts`) **SHALL** validate and accept `SubmitGenerationV6Schema` supporting all V6 fields (`contractVersion`, `trackTitle`, `isAutoTitle`, `prompt` up to `4000` chars, `genre`, `region`, `language`, `lyricsMode`, `lyrics` up to `12000` chars, `sourcePhotoUrl`, `isInstrumental`, `durationSec` in `10..360`, `tempoBpm`, `musicalKey`, `mood`, `era`, `songStructure`, `visibility`, `engineTier`, `batchCount` in `1..4`, `audioMode`, `referenceAudioUrl`, `sourceTrackId`, and `voiceCast`) while remaining `100%` backward-compatible with legacy V5 flat payloads (`selectedVoiceId`, `clonedVoiceProfileId`, `melodyPattern`, `pregenStemLocks`).

### `REQ-P80-CONTRACT-02` — Deterministic Engine Resolution & MiniMax Serving Guardrails
**WHEN** `compileSongSpec` compiles a `StudioGenerationContractV6` request, it **SHALL** deterministically resolve:
1. `engineTier == 'fast_draft'` -> `resolvedEngine = 'ace_step_xl_turbo'`, `attributionTag = null`.
2. `engineTier == 'studio_bake'` AND `isInstrumental == false` AND `audioMode == 'none'` AND `!referenceAudioUrl` AND `!clonedVoiceProfileId` -> `resolvedEngine = 'minimax_music_3'`, `attributionTag = 'MiniMax-Music3'`.
3. `engineTier == 'studio_bake'` AND `isInstrumental == true` AND `!referenceAudioUrl` -> `resolvedEngine = 'ace_step_xl_sft'`, `attributionTag = null` (preventing `sglang-omni` HTTP `400` empty-lyric rejections).
4. `engineTier == 'sovereign_custom'` OR (`referenceAudioUrl != null` AND `audioMode != 'none'`) OR `clonedVoiceProfileId != null` -> `resolvedEngine = 'ace_step_xl_base'`, `attributionTag = null`.
5. `takeSeeds`: an array of length `batchCount` (`1..4`) containing unique positive random integers (`> 0`), defeating `sglang-omni`'s `seed = 0` deterministic default.

### `REQ-P80-CONTRACT-03` — Rich Prompt & Duet Tag Preservation
1. `buildAceStepStyleTags` (`prompt_compiler.ts`) **SHALL NOT** drop user prompts exceeding `48` characters; it SHALL extract structured acoustic/mood phrases up to `320` characters into `caption` and forward the full `richPrompt` (`<= 4000` chars) to `song_spec.rich_prompt`.
2. `sanitizeLyricsForAceStep` and `sanitizeLyricsForClient` (`lyrics_sanitizer.ts`) **SHALL** preserve duet and musical cue tags (`[Voice A]`, `[Voice B]`, `[Duet]`, `[Choir]`, `[Call]`, `[Response]`, `[Guitar Solo]`, `[Sax Solo]`, `[Log Drum Drop]`) alongside standard structural tags (`[Intro]`, `[Verse 1]`, `[Pre-Chorus]`, `[Chorus]`, `[Bridge]`, `[Outro]`, `[Hook]`, `[Instrumental]`), while still stripping arbitrary prose stage directions.

### `REQ-P80-CONTRACT-04` — Multi-Take `public.generation_jobs` Schema & 1:1 Edge/SQLite Parity
1. Migration `supabase/migrations/20261124000002_phase80_generation_jobs_v6_multitake.sql` **SHALL** add `batch_id`, `batch_count`, `engine_tier`, `resolved_engine`, `audio_mode`, `reference_audio_url`, `visibility`, `attribution_tag`, `lyrics_text`, `cover_url`, `voice_cast_json`, `generation_spec_json`, and `takes_json JSONB NOT NULL DEFAULT '[]'::jsonb` to `public.generation_jobs` with an index on `batch_id` (`WHERE batch_id IS NOT NULL`).
2. Every RLS policy on `public.generation_jobs` **MUST** use `((SELECT auth.jwt()) ->> 'creator_id') = creator_id` (wrapping ONLY `auth.jwt()` in `SELECT`) so Supabase Security & Performance Advisors report `0` warnings (`0003_auth_rls_initplan`).
3. `vhunambi_db.ts` (Node SQLite) and `edge_persistence_bridge.ts` (Cloudflare Worker SWR) **SHALL** mirror all 13 additive columns 1:1, and `GenerationJob` (`job_types.ts`) **SHALL** store `creatorId`, `batchId`, `batchCount`, `engineTier`, `resolvedEngine`, `audioMode`, `visibility`, `attributionTag`, `voiceCast`, `generationSpec`, and `takes`.

### `REQ-P80-CONTRACT-05` — True Owner Persistence & Honest Queued-to-Ready Notifications
1. `POST /v1/generations` **SHALL** resolve `creatorId` BEFORE `createJob(...)`, persist the queued job asynchronously via `await vhunambiDb.upsertGenerationJobAsync(job, creatorId, 'audio_synthesis', c)`, and upsert `id: 'notif_gen_' + generationId` with **honest queued wording** (`title: 'Studio Bake Queued: "<trackTitle>"'`, `targetRoute: '/studio'`) rather than claiming `"Studio Track Ready"` while `status == 'queued'` (preserving `phase67_notifications_quota.test.ts#L150`'s `notif_gen_` ID check without lying to the user).
2. `vhunambi_db.ts#updateGenerationJob` **SHALL** preserve `existing.creatorId` instead of defaulting to `'creator_cern'`.
3. `POST /v1/webhooks/ace-step` (`webhook_routes.ts`), `GET /v1/generations/:id` RunPod completion sync, and `mock_worker.ts` **SHALL** hydrate the existing job (including Supabase cloud SWR `syncGenerationJobFromCloud`), preserve its true `creatorId`, persist `takes_json` and `attribution_tag`, and upgrade `notif_gen_<generationId>` to unread `title: 'Studio Track Ready: "<trackTitle>"'` (`targetRoute: '/track/' + generationId`) ONLY when the job transitions to `succeeded`.

### `REQ-P80-CONTRACT-06` — Studio AI Assist & Duet/Photo Lyrics Endpoints
1. `POST /v1/studio/improve-prompt` (`studio_routes.ts`, mounted in `server.ts` + added to `hasScopedReadThrough`) **SHALL** expand a short prompt (`prompt`, `genre`, `language`, `mood`, `ensemble`) into a rich, genre-authentic instrumentation & vocal phrasing prompt using `callRunPodOpenSourceLLM` with a rich deterministic African-music fallback when LLM workers are offline.
2. `POST /v1/lyrics/generate` (`lyrics_routes.ts`) **SHALL** accept optional `ensemble` (`solo` | `duet` | `choir`), `voiceCast`, and `mood` fields and emit `[VOICE A]` / `[VOICE B]` / `[DUET]` / `[CHOIR]` structured stanzas when `ensemble == 'duet'` or `'choir'`.
3. `POST /v1/lyrics/from-photo` (`lyrics_routes.ts`) **SHALL** accept `{ photoUrl, captionHint?, genre, language, mood?, ensemble? }` and return a structured `rawLyrics` + `stanzas` draft grounded in the photo's visual mood.

### `REQ-P80-CONTRACT-07` — Long-Bake Resilience (5–15 Minute RunPod Bakes)
1. `GET /v1/generations/:id` **SHALL NOT** trigger `simulateSynthesisPipeline` fallback when RunPod reports `workersInitializing > 0`, `workersRunning > 0`, or before `900000ms` (`15 min`) for `studio_bake` / `sovereign_custom` jobs (while retaining fast `max === 0` disabled-endpoint protection).
2. `POST /v1/webhooks/ace-step` **SHALL** accept granular stage names (`planning_lyrics`, `synthesizing`, `separating_stems`, `converting_vocals`, `mastering`, `uploading`, `completed`, `failed`) and broadcast them via `GenerationSessionDO` without collapsing all stages into `'synthesizing'`.

---

## 3. Studio Cockpit UI/UX & Glass Synergy Requirements (`REQ-P80-UI-*`)

### `REQ-P80-UI-01` — Unified Glass Tab Navigation & Compact Chrome (`STU-01`)
1. `StudioView` **SHALL** replace its flat solid-orange `_modeSwitcher` with `VhunambiGlassTabBar(scrollable: false)` preserving exact keys `Key('studio_tab_compose')`, `Key('studio_tab_voice')`, and `Key('studio_tab_crate_mpc')`.
2. `ProgressTrackerWidget` (`8/9 | Song DNA 83%`) **SHALL NOT** occupy permanent chrome above the `IndexedStack` across all 3 tabs; `SongDnaHoverPill` SHALL be surfaced as a compact contextual pill inside the `Compose` header row.

### `REQ-P80-UI-02` — Relocate Premature Pre-Gen Quantum Stem Authority (`STU-02`)
**WHILE** the creator is in pre-generation `Compose`, `StudioView` **SHALL NOT** mount `CockpitQuantumEntanglementRack` (`Lock | Inpaint | Resynth` 6-card grid). `CockpitQuantumEntanglementRack` SHALL remain intact in the codebase for post-generation Track/Remix mode (Phase 83) and standalone unit/widget tests (`phase54`).

### `REQ-P80-UI-03` — Zero Truncation, Zero Clipping & `>= 44dp` Ergonomics (`STU-03`)
At `360x800dp` (1.0x and 1.15x text scale) across all 3 tabs:
1. `'Advanced Options'` in `AdvancedOptionsAccordion` **SHALL NOT** truncate (`Advanced Opti...`).
2. `'24 Regional Voices'` and `'Clone My Voice'` in `BantuVoiceDeck` **SHALL NOT** truncate (`24 Regional Vol...`), and timbre cards **SHALL NOT** clip on the left/right edges.
3. `InlineCrateMpcWorkbench` **SHALL** replace its cramped 4-column `Row` with `VhunambiGlassTabBar(scrollable: true)` preserving `Key('workbench_mode_crate')`, `Key('workbench_mode_mpc')`, `Key('workbench_mode_sketchpad')`, and `Key('workbench_mode_daw_upload')`.
4. MPC header **SHALL** render `'${bpm} BPM · Stretch ${ratio}x'` with explicit spacing, the 8-pad grid **SHALL** use a responsive 4-column `LayoutBuilder` layout with `>= 44dp` tap height and zero bottom clipping of `PAD 7` / `PAD 8`, and `mpc_send_to_studio` **SHALL** attach the active chop context to `studioFormProvider` and switch to `Compose` (eliminating the SnackBar dead-end).

### `REQ-P80-UI-04` — Full Dual-Theme Glass & `STD-UIUX-001` Compliance (`STU-14`)
1. All Studio cards and sheets touched in Phase 80 **SHALL** use `VhunambiGlassSurface(enableLiveBlur: false)` and theme-adaptive `AppColors.*Of(context)` tokens (zero hardcoded dark-only `AppColors.surfaceElevated` / `AppColors.surfaceCanvas` breaking Light Mode).
2. `apps/vhunambi_client/lib/features/studio/` **SHALL** have `0` stock `Icons.*` references, `0` `Icon(PhosphorIcons.*)` wrappers (always `PhosphorIcon`), and `0` raw Unicode emojis/dingbat symbols (`U+2726`, `U+2794`, `U+26A1`).

---

## 4. `vhunambi.com/create` Feature Parity Requirements (`REQ-P80-PARITY-*`)

### `REQ-P80-PARITY-01` — Prompt Assist (`Improve with AI` + `Inspire Me` + Starters)
`PromptInputBox` **SHALL** expose `Key('studio_improve_prompt_btn')` (`'Improve with AI'`) alongside existing `'Inspire Me'`, `'Use My DNA'`, and `studio_preset_chip_0..2`. Tapping `'Improve with AI'` calls `StudioAiAssistService.improvePrompt(...)` and updates `studioFormProvider.prompt` with loading feedback and offline fallback.

### `REQ-P80-PARITY-02` — Reference Audio, Phase 79 `VhunambiMediaVault` & 4 Recreate Modes
1. `ReferenceAudioDropzone` **SHALL** wire into Phase 79's `mediaUploadQueueProvider` (`EP-P79-MEDIA-UPLOAD-ENGINE`) offering:
   - `Key('dropzone_upload_audio_btn')` (`Upload Audio` — real file picker staged in `VhunambiMediaVault`; canceling SHALL NOT attach a fake `'amapiano_logdrum_ref_01.wav'`!),
   - `Key('dropzone_from_uploads_btn')` (`From My Uploads` — picks from creator's persisted audio assets in `mediaUploadQueueProvider`),
   - `Key('dropzone_record_tune_btn')` (`Record Sound/Tune`),
   - `Key('dropzone_load_licensed_beat_btn')` (`My Beats`), and
   - `Key('dropzone_open_sketchpad_btn')` (`Sketchpad`).
2. **WHEN** reference audio is attached, `ReferenceAudioDropzone` **SHALL** render a `SafeAudioOrchestrator`-guarded audition play/pause button (`Key('dropzone_preview_audio_btn')`) and the **4 Recreate Mode tiles**: `Key('audio_mode_remix')`, `Key('audio_mode_cover')`, `Key('audio_mode_reference')`, `Key('audio_mode_inspiration')`.

### `REQ-P80-PARITY-03` — 42-Genre Catalog Across All 5 Populated Regions
`RegionalGenreSelector` **SHALL** hydrate from `StudioGenreCatalog` (`42` genres across `South Africa`, `Africa`, `Americas`, `Global`, and `Asia`), ensuring every region tab returns `>= 3` genres (specifically fixing `'Asia'`), using `PhosphorIcon` glyphs only.

### `REQ-P80-PARITY-04` — Instrumental Toggle, Song Length (`10s–360s`), 3-Mode Lyrics, Title, Batch (`1–4`) & Bake Tier
`Compose` **SHALL** render glassmorphic controls backed by `studioFormProvider`:
1. `Key('studio_instrumental_switch')` (`Instrumental Only` toggle — hides Lyrics Mode selector when enabled).
2. `Key('studio_lyrics_mode_bar')` (`VhunambiGlassTabBar` with `Key('lyrics_mode_ai')`, `Key('lyrics_mode_own')`, `Key('lyrics_mode_photo')`):
   - `My own lyrics`: renders multiline `Key('studio_custom_lyrics_input')` with quick-insert `[Voice A]`, `[Voice B]`, `[Chorus]`, `[Bridge]` chips.
   - `From photo`: renders `Key('studio_photo_lyrics_pick_btn')` picking an image from gallery or Phase 79 `VhunambiMediaVault`, displaying a local thumbnail preview (`Image.file` / `VhunambiTrackArtwork`), and generating lyrics via `POST /v1/lyrics/from-photo`.
3. `Key('studio_engine_tier_selector')` with 3 tiles: `Key('engine_tier_fast_draft')` (`Fast Draft`), `Key('engine_tier_studio_bake')` (`Studio Bake`), and `Key('engine_tier_sovereign_custom')` (`Sovereign Custom`).
4. `Key('studio_duration_slider')` spanning `10` to `360` seconds (retaining constructor default `30` in `const StudioFormState()` so `studio_form_test.dart#L19` and `studio_session_repository_test.dart#L64` remain green), with quick presets (`30s`, `1:30`, `3:00`, `5:00 Sweet Spot`, `6:00`) rendered with Phosphor icons (zero raw star/emoji literals).
5. `Key('studio_title_mode_toggle')` (`AI picks title` vs. `I'll name it` revealing `Key('studio_custom_title_input')`) and `Key('studio_batch_count_selector')` (`Key('batch_count_1')`..`Key('batch_count_4')`).

---

## 5. Multi-Voice Duet Casting & Cinematic Baking Requirements (`REQ-P80-VOICE-*`, `REQ-P80-BAKE-*`)

### `REQ-P80-VOICE-01` — Unified Voice Casting & Quick Duet (`STU-04`)
1. `BantuVoiceDeck` **SHALL** preserve `'Bantu Voice LoRA Engine'`, `'5 Native Dialects'`, all 5 `ValueKey('timbre_<id>')` cards, and the `4` `Slider` widgets asserted by `bantu_voice_deck_test.dart`, while unifying Ensemble (`Solo | Duet | Choir`), Gender (`Male | Female | Mixed`), Delivery Mode (`Auto | Melodic | Rap | Spoken | Choir`), Energy (`Soft | Mid | Intense`), a 1-tap `Key('voice_quick_duet_btn')` (`Quick Duet: Female + Male`), multi-select Curated AI Voices (`selectedVoiceIds`, up to `6`), and `My Cloned Voices` (hydrating `clonedVoiceReferenceUrl` for Seed-VC).
2. Expressive Nuance sliders (`DialectInflectionConfig`) **SHALL** serialize inside `voiceCast.dialectInflection` on `POST /v1/generations` and compile into prompt/LLM vocal directives.
3. `LyricsReviewModal` **SHALL** support `[VOICE A]` / `[VOICE B]` / `[DUET]` / `[CHOIR]` stanza badges, pass full `StudioFormState` V6 (including `prompt`, `durationSec`, `engineTier`, `batchCount`, `voiceCast`) in `_approveDraft`, and preserve existing `lyrics_approve` / `lyrics_regenerate` / `lyrics_toggle_raw` keys.

### `REQ-P80-BAKE-01` — Cinematic 4-Stage Baking Monitor, 18-Min Polling & Past-Song Remix Shelf
1. `HttpGenerationSubmissionService.pollGenerationProgress` **SHALL** poll adaptively up to `18 minutes` (`380` ticks: `2s` for first `30` ticks, then `3s`) and parse `bakeStage`, `resolvedEngine`, `attributionTag`, and `takes[]`.
2. `GenerationPipelineCard` **SHALL** render a frosted `VhunambiGlassSurface` preserving the 4 canonical step titles (`'Starting up...'`, `'Writing lyrics...'`, `'Producing the beat...'`, `'Your song is ready!'`), the `2` active `CircularProgressIndicator` instances, and the `4` `AppIcons.check` completion icons asserted by `generation_pipeline_card_test.dart`, while adding a 4-pill `BakeStage` telemetry strip (`Planning` · `Composing` · `Vocal Polish` · `Mastering` using `PhosphorIconsFill.checkCircle` / pulse dots), a `"Safe to explore — we'll notify you when ready"` banner, a multi-take switcher (`Key('pipeline_take_chip_0')`..`3`) when `takes.length > 1`, and a visible `"Engine: MiniMax-Music3"` attribution badge (`Key('pipeline_minimax_attribution_badge')`) whenever `attributionTag == 'MiniMax-Music3'`.
3. `StudioPastSongsRemixShelf` (`Key('studio_past_songs_remix_shelf')`) **SHALL** render at the bottom of `Compose`, listing searchable tracks from `libraryTracksProvider` with 1-tap `Remix` action that populates `referenceAudioPath`, sets `audioMode = ReferenceAudioMode.remix`, sets `genre`, and scrolls to the top.

---

## 6. Non-Functional Requirements (`REQ-P80-NFR-*`)

| ID | Category | Requirement |
| :--- | :--- | :--- |
| **`REQ-P80-NFR-01`** | **Audio Safety** | Any new audio preview inside `ReferenceAudioDropzone` MUST acquire `AudioEngineSlot.studioPreview` via `SafeAudioOrchestrator`, bypass platform channels under `FLUTTER_TEST`, and release in `dispose()`. |
| **`REQ-P80-NFR-02`** | **Test Isolation** | `StudioAiAssistService` and `HttpGenerationSubmissionService` MUST skip live network calls under `FLUTTER_TEST` unless a custom `Dio` is explicitly injected (zero hanging HTTP timers in `pumpAndSettle`). |
| **`REQ-P80-NFR-03`** | **Compact Viewport** | Zero `RenderFlex` overflow at `360x800dp` (Light & Dark) across Compose, Voice, Crate & MPC, and `LyricsReviewModal`. |
| **`REQ-P80-NFR-04`** | **Worker Edge Safety** | All new Hono routes (`/v1/studio/*`, `/v1/lyrics/from-photo`) MUST remain `workerd` V8 isolate safe (`hasScopedReadThrough`, zero `node:fs` / `node:sqlite` direct calls). |

---

## 7. Requirement-to-Test Traceability Matrix

| Requirement ID | Primary Implementation Target(s) | Verification Test Case |
| :--- | :--- | :--- |
| `REQ-P80-CONTRACT-01..03` | `generation_routes.ts`, `prompt_compiler.ts`, `lyrics_sanitizer.ts`, `constants.ts` | `phase80_studio_contract_v6.test.ts` (Zod V6 validation, engine routing, >48-char prompt, `[Voice A]`/`[Voice B]` preservation, unique 64-bit seeds) |
| `REQ-P80-CONTRACT-04..05` | `20261124000002_phase80_generation_jobs_v6_multitake.sql`, `vhunambi_db.ts`, `edge_persistence_bridge.ts`, `webhook_routes.ts` | `phase80_studio_contract_v6.test.ts` (multi-take `takes_json` round-trip, true `creatorId` retention, deferred Ready notification only on completion) |
| `REQ-P80-CONTRACT-06..07` | `studio_routes.ts`, `lyrics_routes.ts`, `server.ts`, `generation_routes.ts` | `phase80_studio_contract_v6.test.ts` (`/v1/studio/improve-prompt`, `/v1/lyrics/from-photo`, duet `/v1/lyrics/generate`, granular webhook stages) |
| `REQ-P80-UI-01..04` | `studio_view.dart`, `advanced_options_accordion.dart`, `bantu_voice_deck.dart`, `inline_crate_mpc_workbench.dart`, `mpc_slicer_deck.dart` | `phase80_studio_cockpit_v6_test.dart` (`360x800` Light/Dark zero overflow, `VhunambiGlassTabBar` keys, zero pre-gen `CockpitQuantumEntanglementRack`, `STD-UIUX-001` regex scan) |
| `REQ-P80-PARITY-01..04` | `prompt_input_box.dart`, `reference_audio_dropzone.dart`, `regional_genre_selector.dart`, `studio_lyrics_and_bake_deck.dart` | `phase80_studio_cockpit_v6_test.dart` (Improve AI, 4 Recreate Modes, Asia genres non-empty, Instrumental/Length/LyricsMode/Title/Batch/BakeTier + lossless submit DTO check) |
| `REQ-P80-VOICE-01` & `BAKE-01` | `bantu_voice_deck.dart`, `lyrics_review_modal.dart`, `generation_pipeline_card.dart`, `studio_past_songs_remix_shelf.dart`, `http_generation_submission_service.dart` | `phase80_studio_cockpit_v6_test.dart` (Quick Duet, multi-select `<= 6`, 4-stage baking monitor, MiniMax attribution badge, multi-take switcher, Past Songs 1-tap Remix) |
