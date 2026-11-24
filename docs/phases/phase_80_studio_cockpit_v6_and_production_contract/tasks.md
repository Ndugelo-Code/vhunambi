# Phase 80 Tasks — Studio Cockpit V6 Glass Overhaul, `vhunambi.com` Parity & `StudioGenerationContractV6`

> **Document ID:** `TASKS-PHASE-80`  
> **Phase Folder:** `docs/phases/phase_80_studio_cockpit_v6_and_production_contract/`  
> **Execution Strategy:** Two-Pass Deterministic Stage 4 (`/vhunambi-executioner`) — **Pass 1 (`M80.1`–`M80.2`)** locks the full-stack `StudioGenerationContractV6`, multi-take schema, AI Assist routes, client state/polling, and Glass Shell; **Pass 2 (`M80.3`–`M80.4`)** ships full `vhunambi.com` parity controls, zero-truncation polish, Cinematic 4-Stage Baking Monitor, Past-Song Remix Shelf, and verification gates.

---

## 1. Master Milestone Roadmap

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│ PASS 1 — BACKEND CONTRACT V6, MULTI-TAKE DB & CLIENT GLASS SHELL             │
│  M80.1: Supabase generation_jobs V6 + Worker Routes + Compiler + Webhooks    │
│         [T80.1.1 -> T80.1.5]                                                 │
│  M80.2: Flutter StudioFormState V6 + 18-Min Polling + StudioView Glass Shell │
│         [T80.2.1 -> T80.2.4]                                                 │
├──────────────────────────────────────────────────────────────────────────────┤
│ PASS 2 — VHUNAMBI.COM PARITY, VOICE/CRATE POLISH & FULL VERIFICATION         │
│  M80.3: Prompt AI, Vault Ref Audio (4 Modes), 42 Genres, Lyrics/Bake Deck,   │
│         Multi-Voice Duet Casting, Zero-Truncation Crate/MPC & STD-UIUX-001   │
│         [T80.3.1 -> T80.3.6]                                                 │
│  M80.4: Cinematic 4-Stage Baking Card, Past-Songs Remix Shelf, Tests & Gates │
│         [T80.4.1 -> T80.4.4]                                                 │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Pass 1 — Milestone `M80.1`: Backend `StudioGenerationContractV6`, Multi-Take DB & AI Assist APIs

- [x] **`T80.1.1` — Supabase Multi-Take `generation_jobs` Migration (`REQ-P80-CONTRACT-04`)**
  - **Target:** `supabase/migrations/20261124000002_phase80_generation_jobs_v6_multitake.sql`
  - **Scope:** Add `batch_id`, `batch_count`, `engine_tier`, `resolved_engine`, `audio_mode`, `reference_audio_url`, `visibility`, `attribution_tag`, `lyrics_text`, `cover_url`, `voice_cast_json`, `generation_spec_json`, and `takes_json JSONB NOT NULL DEFAULT '[]'::jsonb`, index `idx_generation_jobs_batch_id`, enable RLS, and create 4 initplan-clean policies using `((SELECT auth.jwt()) ->> 'creator_id') = creator_id`.
  - **Acceptance:** Valid Postgres 17 SQL; `0` Security Advisor & `0` Performance Advisor (`0003_auth_rls_initplan`) warnings when applied.

- [x] **`T80.1.2` — 1:1 `GenerationJob` Types, `job_store.ts`, `vhunambi_db.ts` & `edge_persistence_bridge.ts` (`REQ-P80-CONTRACT-04`, `REQ-P80-CONTRACT-05`)**
  - **Targets:** `apps/vhunambi_api/src/modules/jobs/job_types.ts`, `apps/vhunambi_api/src/modules/jobs/job_store.ts`, `apps/vhunambi_api/src/db/vhunambi_db.ts`, `apps/vhunambi_api/src/db/edge_persistence_bridge.ts`
  - **Scope:** Add `creatorId`, `batchId`, `batchCount`, `engineTier`, `resolvedEngine`, `audioMode`, `referenceAudioUrl`, `visibility`, `attributionTag`, `voiceCast`, `generationSpec`, `takes` (`GenerationTakeRecord[]`), and granular `PipelineStep` values. Mirror all 13 columns 1:1 across SQLite `vhunambi_db.ts` and Edge `edge_persistence_bridge.ts`. Fix `vhunambi_db.ts#updateGenerationJob` so `existing.creatorId` is always preserved.
  - **Acceptance:** `.\node_modules\.bin\tsc.cmd --noEmit` passes with `0` errors; SQLite and Edge bridge persist/round-trip `creatorId` and `takes_json` identically.

- [x] **`T80.1.3` — Multi-Model Compiler, 42-Genre Presets & Duet-Safe Sanitizer (`REQ-P80-CONTRACT-02`, `REQ-P80-CONTRACT-03`)**
  - **Targets:** `apps/vhunambi_api/src/modules/synthesis/constants.ts`, `apps/vhunambi_api/src/modules/lyrics/lyrics_sanitizer.ts`, `apps/vhunambi_api/src/modules/synthesis/prompt_compiler.ts`, `apps/vhunambi_api/src/modules/synthesis/runpod_adapter.ts`
  - **Scope:** Expand `GENRE_PRESETS` for all 42 genres; allow `[Voice A]`/`[Voice B]`/`[Duet]`/`[Choir]`/`[Guitar Solo]`/`[Log Drum Drop]` in `lyrics_sanitizer.ts`; lift 48-char prompt truncation in `buildAceStepStyleTags` (`<= 320` chars in caption + full `richPrompt`); implement `resolveTargetAudioEngine` (routing `isInstrumental` away from `minimax_music_3` to `ace_step_xl_sft`, setting `attributionTag: 'MiniMax-Music3'` on `minimax_music_3`) and `generateUniqueTakeSeeds` (positive non-zero 64-bit seeds); forward full V6 fields in `runpod_adapter.ts`.
  - **Acceptance:** Prompts > 48 chars preserved; duet tags preserved; `batchCount: 4` yields 4 unique positive seeds; `YuE2` absent everywhere.

- [x] **`T80.1.4` — `POST /v1/generations`, Honest Queued-to-Ready Notifications, Webhook Owner Fix & Studio AI Assist Routes (`REQ-P80-CONTRACT-01`, `05`, `06`, `07`)**
  - **Targets:** `apps/vhunambi_api/src/routes/generation_routes.ts`, `apps/vhunambi_api/src/routes/webhook_routes.ts`, `apps/vhunambi_api/src/modules/synthesis/mock_worker.ts`, `apps/vhunambi_api/src/routes/studio_routes.ts` (new), `apps/vhunambi_api/src/routes/lyrics_routes.ts`, `apps/vhunambi_api/src/modules/lyrics/llm_handler.ts`, `apps/vhunambi_api/src/server.ts`
  - **Scope:** Upgrade `SubmitGenerationSchema` to V6; await `upsertGenerationJobAsync` with true `creatorId`; upsert `notif_gen_<generationId>` as `"Studio Bake Queued"` at submit (preserving `phase67_notifications_quota.test.ts#L150`) and upgrade it to unread `"Studio Track Ready"` via `notifyGenerationCompletedOnce(job, c)` on completion in `webhook_routes.ts`, `GET /v1/generations/:id`, and `mock_worker.ts`; raise long-bake `staleUnscheduled` threshold to `15 min`; implement `POST /v1/studio/improve-prompt`, `POST /v1/lyrics/from-photo`, and duet-aware `POST /v1/lyrics/generate`; mount `/v1/studio` and add to `hasScopedReadThrough` in `server.ts`.
  - **Acceptance:** Queued submit emits `"Studio Bake Queued"` (never premature `"Studio Track Ready"`); completed webhook persists true `creatorId` + `takes_json` + upgrades `notif_gen_<id>` to `"Studio Track Ready"`; `/v1/studio/improve-prompt` and `/v1/lyrics/from-photo` return `200 OK`.

- [x] **`T80.1.5` — Backend Phase 80 Contract Test Suite (`G80-01`)**
  - **Target:** `apps/vhunambi_api/test/phase80_studio_contract_v6.test.ts` (new) + `apps/vhunambi_api/package.json` (`test` script registration if explicit)
  - **Scope:** Verify V6 submission, engine routing (`fast_draft`, `studio_bake` vocal -> `minimax_music_3` + `MiniMax-Music3`, `studio_bake` instrumental -> `ace_step_xl_sft`, `sovereign_custom` -> `ace_step_xl_base`), unique 64-bit `takeSeeds`, >48-char prompt preservation, `[Voice A]`/`[Voice B]` sanitization, deferred Ready notification, true `creatorId` webhook persistence, `takes_json` retrieval, `/v1/studio/improve-prompt`, and `/v1/lyrics/from-photo`.
  - **Acceptance:** `.\node_modules\.bin\tsc.cmd --noEmit && npm test` passes `100%` (`0` TS errors, all backend suites green).

---

## 3. Pass 1 — Milestone `M80.2`: Client `StudioFormState` V6, 18-Min Polling & Glass Shell

- [x] **`T80.2.1` — `StudioFormState` V6, `StudioGenreCatalog` (42 Genres) & `StudioFormNotifier` (`REQ-P80-PARITY-03`, `04`)**
  - **Targets:** `apps/vhunambi_client/lib/features/studio/domain/models/studio_form_state.dart`, `apps/vhunambi_client/lib/features/studio/domain/models/studio_genre_catalog.dart` (new), `apps/vhunambi_client/lib/features/studio/presentation/providers/studio_form_provider.dart`
  - **Scope:** Add `StudioEngineTier`, `ReferenceAudioMode`, `batchCount`, `selectedVoiceIds`, `sourcePhotoPath`, `sourcePhotoUrl`, `sourceTrackId`, and `resolvedEnginePreview` to `StudioFormState` + setters (`setAudioMode`, `setEngineTier`, `setBatchCount`, `toggleSelectedVoiceId`, `applyQuickDuet`, `setSourcePhoto`, `applyPastTrackRemix`) on `StudioFormNotifier`. Create `kStudioGenreCatalog` with 42 Phosphor-icon genres across all 5 regions (including 3+ under `'Asia'`).
  - **Acceptance:** Pure Dart domain compiles with zero `flutter/material.dart` bloat; existing `studio_form_test.dart` passes 100%.

- [x] **`T80.2.2` — `StudioAiAssistService` & `GenerationPipelineState` Multi-Take Extensions (`REQ-P80-PARITY-01`, `REQ-P80-BAKE-01`, `REQ-P80-NFR-02`)**
  - **Targets:** `apps/vhunambi_client/lib/features/studio/data/services/studio_ai_assist_service.dart` (new), `apps/vhunambi_client/lib/features/studio/domain/models/generation_pipeline_state.dart`
  - **Scope:** Implement `StudioAiAssistService` (`improvePrompt`, `generateLyricsFromPhoto`, `generateDuetAwareLyrics`) with `FLUTTER_TEST` offline guards without altering `ILyricsGenerationService`. Add `BakeStage`, `GenerationTake`, `resolvedEngine`, `attributionTag`, `takes`, and `activeTakeIndex` to `PipelineSocketEvent` & `GenerationProgressState`.
  - **Acceptance:** Zero existing `ILyricsGenerationService` test doubles broken; `generation_pipeline_state_test.dart` remains 100% green.

- [x] **`T80.2.3` — Lossless V6 Submission & 18-Minute Adaptive Polling (`REQ-P80-CONTRACT-01`, `REQ-P80-BAKE-01`)**
  - **Targets:** `apps/vhunambi_client/lib/features/studio/data/services/http_generation_submission_service.dart`, `apps/vhunambi_client/lib/features/studio/presentation/providers/generation_pipeline_providers.dart`
  - **Scope:** Serialize every `StudioFormState` V6 field (`durationSec`, `region`, `lyricsMode`, `isAutoTitle`, `era`, `songStructure`, `visibility`, `engineTier`, `batchCount`, `audioMode`, `sourcePhotoUrl`, `sourceTrackId`, `voiceCast` including `selectedVoiceIds`, `clonedVoiceReferenceUrl`, and `dialectInflection`) in `submitGeneration` & `submitAndStartGeneration`; lift polling cap from `60` (`90s`) to `380` (`18 min`) adaptive ticks; add `selectActiveTake(int index)`.
  - **Acceptance:** `http_generation_submission_service_test.dart` & `generation_pipeline_providers_test.dart` pass 100%; zero dropped Studio fields.

- [x] **`T80.2.4` — `StudioView` Glass Shell Refactor (`STU-01`, `STU-02`, `REQ-P80-UI-01`, `02`)**
  - **Targets:** `apps/vhunambi_client/lib/features/studio/presentation/views/studio_view.dart`, `apps/vhunambi_client/lib/features/studio/presentation/widgets/studio_action_bar.dart`
  - **Scope:** Swap flat solid-orange `_modeSwitcher` for `VhunambiGlassTabBar(scrollable: false)` preserving `studio_tab_compose`, `studio_tab_voice`, `studio_tab_crate_mpc`; remove permanent `ProgressTrackerWidget` above `IndexedStack` (surface `SongDnaHoverPill` inline inside `Compose`); remove `CockpitQuantumEntanglementRack` from pre-gen `Compose`; apply `AppColors.*Of(context)` + frosted `StudioActionBar` with batch count CTA label & `LyricsMode.fromPhoto` / `myOwn` support.
  - **Acceptance:** `StudioView` renders cleanly in Light & Dark modes with zero pre-gen stem-lock clutter and preserved tab keys.

---

## 4. Pass 2 — Milestone `M80.3`: Full `vhunambi.com` Production Controls, Voice Casting & Truncation Sweep

- [x] **`T80.3.1` — `PromptInputBox` Glass Card + `Improve with AI` (`REQ-P80-PARITY-01`, `REQ-P80-UI-04`)**
  - **Target:** `apps/vhunambi_client/lib/features/studio/presentation/widgets/prompt_input_box.dart`
  - **Scope:** Wrap in `VhunambiGlassSurface` + `AppColors.*Of(context)`; add `Key('studio_improve_prompt_btn')` (`'Improve with AI'`, `>= 44dp`) wired to `studioAiAssistServiceProvider.improvePrompt(...)`.
  - **Acceptance:** Tapping `Improve with AI` populates an enriched prompt; existing `studio_preset_chip_0..2` and `'Inspire Me'` pins pass.

- [x] **`T80.3.2` — `ReferenceAudioDropzone` + Phase 79 `VhunambiMediaVault` + 4 Recreate Modes (`REQ-P80-PARITY-02`, `REQ-P80-NFR-01`)**
  - **Target:** `apps/vhunambi_client/lib/features/studio/presentation/widgets/reference_audio_dropzone.dart`
  - **Scope:** Connect to `mediaUploadQueueProvider` (`Upload Audio`, `From My Uploads`, `Record Tune`, `My Beats`, `Sketchpad`); remove fake `'amapiano_logdrum_ref_01.wav'` cancel fallback; add `SafeAudioOrchestrator`-guarded preview player (`Key('dropzone_preview_audio_btn')`) and 4 `ReferenceAudioMode` tiles (`Key('audio_mode_remix')`, `cover`, `reference`, `inspiration`).
  - **Acceptance:** Cancel never attaches fake filename; picking from `My Uploads` attaches real asset + enables 4 mode tiles + preview safely bypasses native channels in `FLUTTER_TEST`.

- [x] **`T80.3.3` — `RegionalGenreSelector` 42-Genre Catalog + Glass Polish (`REQ-P80-PARITY-03`)**
  - **Target:** `apps/vhunambi_client/lib/features/studio/presentation/widgets/regional_genre_selector.dart`
  - **Scope:** Hydrate from `kStudioGenreCatalog` (`42` genres across all `5` regions including `Asia`), wrap in `VhunambiGlassSurface`, convert static colors to `AppColors.*Of(context)`.
  - **Acceptance:** Every region tab (`South Africa`, `Africa`, `Americas`, `Global`, `Asia`) displays `>= 3` genres with Phosphor icons.

- [x] **`T80.3.4` — New `StudioLyricsAndBakeDeck` & Non-Truncating `AdvancedOptionsAccordion` (`REQ-P80-PARITY-04`, `REQ-P80-UI-03`)**
  - **Targets:** `apps/vhunambi_client/lib/features/studio/presentation/widgets/studio_lyrics_and_bake_deck.dart` (new), `apps/vhunambi_client/lib/features/studio/presentation/widgets/multilingual_language_selector.dart`, `apps/vhunambi_client/lib/features/studio/presentation/widgets/advanced_options_accordion.dart`
  - **Scope:** Build `StudioLyricsAndBakeDeck` exposing `Language`, `Instrumental Only` (`studio_instrumental_switch`), 3-Mode Lyrics `VhunambiGlassTabBar` (`AI writes` | `My own` with `[Voice A]`/`[Voice B]` tag chips | `From photo` with Phase 79 Vault image picker + thumbnail), 3-tier Engine Selector (`Fast Draft` | `Studio Bake` | `Sovereign Custom`), `Song Length` slider (`10s–360s`, keeping `StudioFormState` default `30s` + `5:00 Sweet Spot` hint), `Song Title` (`AI` | `Custom`), and `Number of songs` (`1–4`). Fix `'Advanced Options'` header truncation and `>= 44dp` chips in `AdvancedOptionsAccordion` and `MultilingualLanguageSelector`.
  - **Acceptance:** All controls mutate `studioFormProvider` cleanly with zero `360dp` overflow or label clipping; `studio_form_test.dart` (`durationSeconds == 30` default) passes 100%.

- [x] **`T80.3.5` — `BantuVoiceDeck` Multi-Voice Duet Casting & `LyricsReviewModal` V6 Handoff (`REQ-P80-VOICE-01`, `REQ-P80-UI-03`)**
  - **Targets:** `apps/vhunambi_client/lib/features/studio/presentation/widgets/bantu_voice_deck.dart`, `apps/vhunambi_client/lib/features/studio/presentation/widgets/vocal_identity_picker_sheet.dart`, `apps/vhunambi_client/lib/features/studio/presentation/widgets/lyrics_review_modal.dart`, `apps/vhunambi_client/lib/features/studio/presentation/widgets/live_phonetic_alignment_preview.dart`
  - **Scope:** Glass overhaul + zero truncation on `'24 Regional Voices'` / `'Clone My Voice'` + unclipped timbre cards + `Quick Duet: Female + Male` (`voice_quick_duet_btn`) + multi-select `selectedVoiceIds` (`<= 6`) + `My Cloned Voices` sync. Update `LyricsReviewModal._approveDraft` to pass full V6 state (including `prompt`), style `[VOICE A]`/`[VOICE B]` stanza pills, and fix `Icon(PhosphorIcons.treeStructure(...))` at `#L382`.
  - **Acceptance:** `bantu_voice_deck_test.dart`, `voice_clone_and_picker_sheet_test.dart`, and `lyrics_review_modal_test.dart` pass 100%.

- [x] **`T80.3.6` — `InlineCrateMpcWorkbench`, `MpcSlicerDeck` Real Studio Wiring & `STD-UIUX-001` Sweep (`REQ-P80-UI-03`, `REQ-P80-UI-04`)**
  - **Targets:** `apps/vhunambi_client/lib/features/studio/presentation/widgets/inline_crate_mpc_workbench.dart`, `apps/vhunambi_client/lib/features/studio/presentation/widgets/mpc_slicer_deck.dart`, `apps/vhunambi_client/lib/features/studio/presentation/widgets/guided_lyrics_composer.dart`, `apps/vhunambi_client/lib/features/studio/presentation/widgets/song_dna_node_tree_modal.dart`
  - **Scope:** Adopt scrollable `VhunambiGlassTabBar` preserving `workbench_mode_*` keys; fix `BPM · Stretch` separator and responsive 4x2 MPC pads (`minHeight: 56`); wire `mpc_send_to_studio` to `studioFormProvider` + switch to `Compose`; strip raw dingbat/emoji codepoints (`U+2726`, `U+2794`, `U+26A1`) in `guided_lyrics_composer.dart` and `song_dna_node_tree_modal.dart`.
  - **Acceptance:** `STD-UIUX-001` scan reports `ICONS_VIOLATIONS=0`, `EMOJI_VIOLATIONS=0`.

---

## 5. Pass 2 — Milestone `M80.4`: Cinematic 4-Stage Baking Monitor, Past-Songs Remix Shelf & Verification Gates

- [x] **`T80.4.1` — `GenerationPipelineCard` Cinematic 4-Stage Monitor, Multi-Take Switcher & Attribution (`REQ-P80-BAKE-01`)**
  - **Target:** `apps/vhunambi_client/lib/features/studio/presentation/widgets/generation_pipeline_card.dart`
  - **Scope:** Frosted `VhunambiGlassSurface` overhaul preserving `'Starting up...'` / `'Writing lyrics...'` / `'Producing the beat...'` / `'Your song is ready!'`, `2` `CircularProgressIndicator`s, and `4` `AppIcons.check` glyphs, while adding the 4-pill `BakeStage` telemetry strip (`Planning` · `Composing` · `Vocal Polish` · `Mastering` using `PhosphorIconsFill.checkCircle` / pulse dots), `"Safe to explore — we'll notify you when ready"` banner while baking, multi-take selector (`pipeline_take_chip_0..3`), and visible `"MiniMax-Music3"` attribution pill (`pipeline_minimax_attribution_badge`) when `attributionTag == 'MiniMax-Music3'`.
  - **Acceptance:** `generation_pipeline_card_test.dart` (`13/13`) and `phase64_studio_scroll_and_audio_test.dart` pass 100%; multi-take switcher and MiniMax attribution render cleanly.

- [x] **`T80.4.2` — New `StudioPastSongsRemixShelf` (`REQ-P80-BAKE-01`)**
  - **Target:** `apps/vhunambi_client/lib/features/studio/presentation/widgets/studio_past_songs_remix_shelf.dart` (new)
  - **Scope:** Searchable glass shelf reading `libraryTracksProvider` (non-deleted tracks) with `VhunambiTrackArtwork`, genre/duration badges, and 1-tap `Remix` action calling `studioFormProvider.notifier.applyPastTrackRemix(track)` + scrolling Compose to top.
  - **Acceptance:** Tapping `Remix` on a past track populates `referenceAudioPath`, `audioMode = remix`, `sourceTrackId`, and `genre`.

- [x] **`T80.4.3` — Phase 56 Test Migration & New Phase 80 Comprehensive Widget/Unit Suite (`G80-04`)**
  - **Targets:** `apps/vhunambi_client/test/features/studio/phase56_studio_cockpit_and_mobile_biome_overhaul_test.dart` (update Test #1 for `STU-02`), `apps/vhunambi_client/test/features/studio/phase80_studio_cockpit_v6_test.dart` (new)
  - **Scope:** Verify `360x800` Light & Dark zero overflow, `VhunambiGlassTabBar` switching, zero pre-gen `CockpitQuantumEntanglementRack`, `Improve with AI`, `Reference Audio` 4 Recreate Modes + cancel-safety, `'Asia'` genres non-empty, `Instrumental Only` auto-routing preview, `Song Length` (`10s–360s`), 3-Mode Lyrics, `Batch Count` (`1–4`), `Quick Duet`, `MiniMax-Music3` attribution badge, multi-take switcher, and Past-Songs Remix shelf.
  - **Acceptance:** All `28` Studio test suites pass with `--timeout=60s`.

- [x] **`T80.4.4` — Full Verification Gates, Cloud Deploy & Memory Consolidation (`G80-01` – `G80-06`)**
  - **Scope:** Run every gate below sequentially, apply Supabase migration BEFORE Worker deploy, check Supabase Advisors (`0` warnings), update `memory.md` (`"status": "completed"`), check off Phase 80 in [PHASE_80_PLUS_STUDIO_AND_RUNPOD_MASTER_TRACKER.md](../PHASE_80_PLUS_STUDIO_AND_RUNPOD_MASTER_TRACKER.md), and run `consolidate_memory.mjs`.

---

## 6. Stage 4 Verification Checklist & PowerShell Commands

```powershell
# G80-01: Backend TypeScript & Test Suites (Windows PowerShell safe — no npx hang)
Set-Location c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_api
.\node_modules\.bin\tsc.cmd --noEmit && npm test

# G80-02: Flutter Static Analysis on Modified/New Targets
Set-Location c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_client
flutter analyze --no-pub lib/features/studio test/features/studio

# G80-03: STD-UIUX-001 Icon & Raw Emoji Gate
Set-Location c:\Users\Ndugelo\VHUNAMBI\monorepo
Select-String -Path "apps/vhunambi_client/lib/features/studio/**/*.dart" -Pattern "\bIcons\."
node -e "const fs=require('fs'),path=require('path');let c=0;function w(d){for(const e of fs.readdirSync(d,{withFileTypes:true})){const p=path.join(d,e.name);if(e.isDirectory())w(p);else if(p.endsWith('.dart')){fs.readFileSync(p,'utf8').split('\n').forEach((l,i)=>{if(/[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]/u.test(l)&&!l.trim().startsWith('//')){console.log(p+':'+(i+1)+': '+l.trim());c++;}});}}}w('apps/vhunambi_client/lib/features/studio');console.log('EMOJI_VIOLATIONS='+c);"

# G80-04: Flutter Studio & Cross-Domain Regression Tests
Set-Location c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_client
flutter test --timeout=60s test/features/studio/

# G80-06: Memory Consolidation (ONLY after G80-01..G80-05 pass & memory.md status="completed")
Set-Location c:\Users\Ndugelo\VHUNAMBI\monorepo
node .agents/skills/vhunambi-memory/scripts/consolidate_memory.mjs
node .agents/skills/vhunambi-memory/scripts/query_connectome.mjs --open
```

### Mandatory Stage 4 Anti-Trap Invariants
- [x] `ILyricsGenerationService` abstract interface untouched (zero broken test doubles).
- [x] `vhunambi_db.ts` and `edge_persistence_bridge.ts` mirrored 1:1 with true `creatorId` retention on every update.
- [x] `public.generation_jobs` RLS uses `((SELECT auth.jwt()) ->> 'creator_id') = creator_id` (`0` advisor warnings) and migrates BEFORE Worker deploy.
- [x] `isInstrumental == true` auto-routes away from `minimax_music_3` to `ace_step_xl_sft`; unique non-zero 64-bit `takeSeeds` generated per take; `YuE2` strictly excluded.
- [x] Existing `studio_tab_*`, `workbench_mode_*`, `voice_ensemble_header_card`, and `lyrics_approve` test keys preserved.
- [x] Zero raw Unicode emojis and zero stock `Icons.*` across `features/studio/`.
