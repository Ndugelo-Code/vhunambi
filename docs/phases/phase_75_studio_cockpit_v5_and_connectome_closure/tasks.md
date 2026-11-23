# VHUNAMBI PHASE 75: DETERMINISTIC TWO-PASS EXECUTION PLAN & VERIFICATION GATES

**Document ID:** `VHUNAMBI-SPEC-P75-TASKS-V1`  
**Phase:** `75`  
**Status:** `READY FOR STAGE 4 EXECUTION (/vhunambi-executioner)`  
**Execution Model:** Two Sequential Self-Contained Passes (`Pass 1: M75.1–M75.2` $\to$ `Pass 2: M75.3–M75.4`)

---

## Pass 1 — Worker Voice/Mastering SWR & 100% `OPEN` Connectome Closure (`M75.1` – `M75.2`)

> **Pass 1 Self-Containment Rule:** Pass 1 (`M75.1`–`M75.2`) MUST compile and pass all backend TypeScript/test suites (`31/31`) and Flutter analyzer + unit/provider tests with zero dependency on Pass 2 (`M75.3`–`M75.4`) UI overhaul edits.

### Milestone `M75.1`: Backend Voice/Mastering 12s SWR, Awaited Write-Through & Route Isolation (`apps/vhunambi_api`)
- [x] **T75.1.1**: Extend `CreateVoiceCloneRequestSchema` in `apps/vhunambi_api/src/modules/voices/voice_types.ts` with optional validated `id: z.string().min(4).max(96).optional()`.
- [x] **T75.1.2**: Upgrade `apps/vhunambi_api/src/db/edge_persistence_bridge.ts` and `apps/vhunambi_api/src/db/vhunambi_db.ts` (1:1 `VhunambiDatabase` proxy parity):
  - Add `hydrateVoiceCloneRows`, `hydrateSoundSignatureRows`, and 12-second SWR `syncVoicesFromCloud(force = false, cOrEnv?)` coalesced under `'voices:global'` (stamping `domainHydratedAtMs` only when both `voice_clones` and `sound_signatures` selects succeed).
  - Add `upsertVoiceCloneAsync`, `upsertSoundSignatureAsync`, `deleteSoundSignatureAsync`, and `updateGenerationJobAsync` backed by `awaitWriteThrough(...)`.
- [x] **T75.1.3**: Update `apps/vhunambi_api/src/modules/voices/voice_catalog.ts` and `apps/vhunambi_api/src/routes/voice_routes.ts`:
  - Honor optional client `req.id` in `registerVoiceCloneProfile`, eliminate dead `https://r2.vhunambi.com` / `/mock-storage/` URLs via `resolveMediaUrl(..., c)`, add `*Async` CRUD wrappers, and call `await vhunambiDb.syncVoicesFromCloud(false, c)` inside `GET /clone/:id`, `POST /signatures/:id/analyze`, `PATCH /signatures/:id/recipe`, `GET /signatures/:id`, and `DELETE /signatures/:id`.
- [x] **T75.1.4**: Update `apps/vhunambi_api/src/routes/generation_routes.ts` (`POST /:id/master`) to hydrate cold isolates via `await vhunambiDb.syncGenerationJobFromCloud(id, c)` and persist the enriched mastering manifest via `await vhunambiDb.updateGenerationJobAsync(...)`.
- [x] **T75.1.5**: Update `apps/vhunambi_api/src/server.ts` (`hasScopedReadThrough`) preserving all existing prefixes and appending `/v1/voices`, `/v1/melodies`, and `/v1/lyrics`.
- [x] **T75.1.6**: Create `apps/vhunambi_api/test/phase75_studio_connectome_closure.test.ts` and register it in `apps/vhunambi_api/package.json` (`31/31` suites green).

### Milestone `M75.2`: Client Connectome Closure Engines (`EP-P66`, `EP-P27`, `EP-P26`, `EP-P25`)
- [x] **T75.2.1** (`EP-P66`): Extend `ILyricsGenerationService`, `FakeLyricsGenerationService`, `HttpLyricsGenerationService`, and `LyricsReviewNotifier` with `refineLyrics` (`POST /v1/lyrics/refine` $\to$ `rawLyrics`) and `transformStoryToLyrics` (`POST /v1/lyrics/story-transform` $\to$ **`structuredLyrics`**) with Bantu display-name $\to$ ISO code & `STORY_GENRES` normalization.
- [x] **T75.2.2** (`EP-P27`): Add `syncStarterPresetsFromCloud` (`GET /v1/melodies/presets`) to `MelodySketchpadNotifier` and `syncSoundPacksFromCloud` (`GET /v1/melodies/sound-packs`) + real Dio byte progress download (with `FLUTTER_TEST`/offline fallback) to `SoundPackManagerNotifier` + trigger sync on `StudioSoundPackSheet` open.
- [x] **T75.2.3** (`EP-P26`): Add `prepareCalibrationFromLyricsAsync` (`POST /v1/voices/extract-calibration`) and `syncCatalogFromCloud` (`GET /v1/voices/catalog`) to `VocalIdentityNotifier`; forward client `id` + canonical `creatorId` in `PreGenR2UploadService.uploadVoiceCloneReference`; add `updateRecipeInCloud` (`PATCH /v1/voices/signatures/:id/recipe`), `fetchSignatureFromCloud`, and `deleteSignatureInCloud` to `SoundSignatureRepository`; wire `onSaveRecipe`, `onUseAsVoiceClone`, and `onDelete` in `CrossModuleSynergyDeck`.
- [x] **T75.2.4** (`EP-P25`): Add `GenreMasterPreset.fromJson` (`stem_mastering_recipe.dart`), `availablePresets` + `syncMasteringPresetsFromCloud` (`GET /v1/generations/mastering/presets`) in `MasteringSessionNotifier`, remove silent `/mock-storage/` masking on HTTP errors in `bakeProductionMaster`, add `loadManifestFromCloud` (`GET /v1/generations/:id/manifest`) to `TrackDetailNotifier` (`separateStems()` preserving canonical stem IDs/names), and wire `TrackDetailView`'s `onDownloadStem` to `stemDownloadServiceProvider`.

### Pass 1 Verification Gate (`M75.1` – `M75.2`)
```powershell
# 1. Backend TypeScript & 31-Suite Gate
Push-Location c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_api
.\node_modules\.bin\tsc.cmd --noEmit
npm test
Pop-Location

# 2. Client Pass 1 Analyzer & Provider Regression Gate
Push-Location c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_client
dart analyze lib/features/studio lib/features/sound_signature lib/features/mastering lib/features/track lib/features/home
flutter test --no-pub --timeout=60s test/features/mastering/ test/features/sound_signature/ test/features/track/track_notifier_test.dart
Pop-Location
```

---

## Pass 2 — Direct-to-Reels Bridge, Teleprompter Sanitizer, `STD-UIUX-001` Glass Polish, Test Suite & SLEEP (`M75.3` – `M75.4`)

### Milestone `M75.3`: Direct Creation-to-Viral Bridge & Track Teleprompter Hygiene
- [x] **T75.3.1**: Upgrade `LyricsReviewModal` (`lyrics_review_modal.dart`) with interactive Story-to-Lyrics composer (`Key('lyrics_story_input')`, `Key('lyrics_story_transform_btn')`, keeping `'Story-to-Lyrics Mode Active'` visible for `lyrics_review_modal_test.dart#L370`), per-stanza AI Polish button (`Key('stanza_refine_${section.id}')`), and explicit `focusedBorder: InputBorder.none` on inline editors.
- [x] **T75.3.2**: Redirect all 4 legacy Reel entrypoints into `KineticReelStudioView.show(context, initialTrack: ...)`:
  - `apps/vhunambi_client/lib/features/studio/presentation/widgets/generation_pipeline_card.dart#L653-666` (`Key('pipeline_create_reel_btn')`)
  - `apps/vhunambi_client/lib/features/track/presentation/views/track_detail_view.dart#L415-425` (`_openVideoExport` + fix dead `cdn.vhunambi.com` WAV URL at `#L392`)
  - `apps/vhunambi_client/lib/features/library/presentation/widgets/track_actions_sheet.dart#L198-208`
  - `apps/vhunambi_client/lib/features/player/presentation/widgets/expanded_cockpit_modal.dart#L945-968`
- [x] **T75.3.3**: Add `LyricKaraokeSanitizer.cleanLyricsForTeleprompter(String rawLyrics)` in `lyric_karaoke_sanitizer.dart` and wire it into `LyricsTeleprompter` (`lyrics_teleprompter.dart#L25`).

### Milestone `M75.4`: `STD-UIUX-001` Icon/Emoji Purge, Glass Parity, Phase 75 Test Suite & SLEEP
- [x] **T75.4.1**: Purge all stock `Icons.*` and raw Unicode emojis across `mastering/` (`desktop_mastering_studio_view.dart`, `mobile_quick_master_sheet.dart`) and wrap channel strips / cards in `VhunambiGlassSurface(enableLiveBlur: false)` with `AppColors.*Of(context)`.
- [x] **T75.4.2**: Purge stock `Icons.*` and raw Unicode emojis across `studio/` (`generation_pipeline_card.dart`, `lyrics_review_modal.dart`, `bantu_voice_deck.dart`, `vocal_identity_picker_sheet.dart`, `voice_clone_recorder_sheet.dart`, `crate_browser_deck.dart`, `mpc_slicer_deck.dart`, `guided_lyrics_composer.dart`, `prompt_input_box.dart`, `prompt_intelligence_overlay.dart`, `reference_audio_dropzone.dart`, `regional_genre_selector.dart`, `multilingual_language_selector.dart`, `bantu_language_switcher.dart`, `direct_daw_vocal_upload_sheet.dart`, `song_dna_node_tree_modal.dart`, `option_preview_chip.dart`, `studio_session_recovery_banner.dart`, `live_phonetic_alignment_preview.dart`, `lyrics_section_scaffold.dart`, `melody_sketchpad_models.dart`, `heritage_crate_models.dart`, `option_preview_descriptor.dart`, `bantu_voice_profile.dart`, `studio_form_state.dart`, `fake_generation_socket_service.dart`), guard unsafe casts in `sound_signature_dna.dart` & `phonetic_articulation_profile.dart` via `JsonSafe`, and update `generation_pipeline_card_test.dart#L130,143,236` (`Icons.check` $\to$ `AppIcons.check`).
- [x] **T75.4.3**: Create `apps/vhunambi_client/test/features/phase75_studio_connectome_closure_test.dart` covering all 4 closed `OPEN` endpoints, honest Mastering error handling, Direct-to-Reels launch, and `cleanLyricsForTeleprompter`.
- [x] **T75.4.4** (`SLEEP` Memory Consolidation): **ONLY AFTER** all Pass 1 and Pass 2 verification gates exit `0`, check off `tasks.md`, update `docs/phases/phase_75_studio_cockpit_v5_and_connectome_closure/memory.md` to `"status": "completed"` with `"completed_at"` ISO timestamp, and run `node .agents/skills/vhunambi-memory/scripts/consolidate_memory.mjs` confirming **`0 OPEN`** endpoints across the monorepo.

### Pass 2 & Final Verification Gate (`M75.3` – `M75.4`)
```powershell
# 1. Static Analysis Gate (0 issues)
Push-Location c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_client
dart analyze lib/features/studio lib/features/sound_signature lib/features/mastering lib/features/track lib/features/home lib/features/library lib/features/player test/features/phase75_studio_connectome_closure_test.dart

# 2. Full Phase 75 + Studio + Sound Signature + Mastering + Track Regression Gate
flutter test --no-pub --timeout=60s test/features/phase75_studio_connectome_closure_test.dart test/features/studio/ test/features/sound_signature/ test/features/mastering/ test/features/track/

# 3. STD-UIUX-001 Zero-Stock-Icon & Zero-Raw-Emoji Audit
Get-ChildItem -Path "lib\features\mastering","lib\features\studio\presentation\widgets","lib\features\studio\presentation\views" -Recurse -Filter "*.dart" | Select-String -Pattern "(?<![A-Za-z])Icons\.|[\uD83C-\uDBFF][\uDC00-\uDFFF]"
Pop-Location
```

---

## Stage 4 Anti-Trap Checklist
1. **`POST /v1/lyrics/story-transform` returns `structuredLyrics`**, NOT `rawLyrics`; normalize display language names to 2-letter ISO codes (`ve`, `zu`, `xh`, `st`, `tn`, `nso`, `ts`, `ss`, `nr`, `en`) before posting.
2. **Preserve `'Story-to-Lyrics Mode Active'`** inside `LyricsReviewModal`'s Story Mode header (`lyrics_review_modal_test.dart#L370`).
3. **Update `generation_pipeline_card_test.dart#L130,143,236`** when replacing `Icons.check` with `AppIcons.check`.
4. **Preserve canonical stem IDs/names** in `TrackDetailNotifier.separateStems()` (`'${trackId}_vocals'`, `['Vocals', 'Drums', 'Bass & Log Drums', 'Instrumental']`) for `track_notifier_test.dart#L171-195`.
5. **1:1 `VhunambiDatabase` Proxy Parity**: Every async method added to `EdgeIsolateDatabaseEngine` must be proxied on `VhunambiDatabase` (`vhunambi_db.ts`).
6. **`FLUTTER_TEST` Network Guards**: New cloud hydration helpers must skip live HTTP when `FLUTTER_TEST` is active unless a mock `Dio`/`http.Client` is injected.
