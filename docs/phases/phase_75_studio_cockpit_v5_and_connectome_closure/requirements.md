# VHUNAMBI PHASE 75: FORMAL REQUIREMENTS SPECIFICATION (EARS / RFC-2119)

**Document ID:** `VHUNAMBI-SPEC-P75-REQUIREMENTS-V1`  
**Phase:** `75`  
**Status:** `ARGON-HARDENED`  
**Grounding Audit:** `AUDIT-P75-STUDIO-CONNECTOME-001`  
**Conventions:** Requirements follow EARS patterns (`WHEN`, `WHILE`, `IF ... THEN`, `WHERE`, `SHALL`) and RFC-2119 normative verbs (`SHALL`, `MUST`, `MUST NOT`, `SHOULD`).

---

## 1. Document Scope & Architectural Invariants

This specification governs **Pass 1 (`M75.1`–`M75.2`)** and **Pass 2 (`M75.3`–`M75.4`)** of Phase 75: closing the final `4` `OPEN` Connectome endpoints (`EP-P66-LYRICS-REFINE-STORY`, `EP-P27-MELODY-PRESETS-PACKS`, `EP-P26-VOICE-CALIBRATION-RECIPE`, `EP-P25-GEN-MASTER-PRESETS`), achieving 100% Cloudflare Worker scoped SWR isolation, unifying all creation-to-reels flows into `KineticReelStudioView`, and completing `STD-UIUX-001` + Glass parity across Studio, Mastering, and Track Cockpit.

---

## 2. Backend Worker SWR & Route Hardening (`REQ-P75-BE-*`)

### `REQ-P75-BE-01` — 12-Second Voice Clones & Sound Signatures SWR (`syncVoicesFromCloud`)
- `WHEN` any voice clone or sound signature lookup/mutation route (`GET /v1/voices/clone/:id`, `GET /v1/voices/signatures/:id`, `PATCH /v1/voices/signatures/:id/recipe`, `DELETE /v1/voices/signatures/:id`, `POST /v1/voices/signatures/:id/analyze`) executes in a Cloudflare Worker isolate (`!isNodeSqliteAvailable()`), the backend `SHALL` invoke `await vhunambiDb.syncVoicesFromCloud(false, c)` before reading isolate memory.
- `syncVoicesFromCloud(force = false, cOrEnv?)` `SHALL` hydrate both `voice_clones` and `sound_signatures` from Supabase via `EdgeIsolateDatabaseEngine.withTimeoutResult(..., 3500)` with `DEFAULT_SWR_TTL_MS = 12_000`, coalescing concurrent in-flight promises under key `'voices:global'` and stamping `domainHydratedAtMs.set('voices:global', Date.now())` **ONLY** when both selects succeed.
- `VhunambiDatabase` (`vhunambi_db.ts`) `SHALL` expose exact 1:1 proxy signatures for `syncVoicesFromCloud`, `upsertVoiceCloneAsync`, `upsertSoundSignatureAsync`, `deleteSoundSignatureAsync`, and `updateGenerationJobAsync`.

### `REQ-P75-BE-02` — Awaited Voice & Signature Write-Through + Client Voice ID Parity
- `WHEN` `POST /v1/voices/clone`, `POST /v1/voices/signatures`, `PATCH /v1/voices/signatures/:id/recipe`, or `DELETE /v1/voices/signatures/:id` mutates state, the Worker `SHALL` persist via `awaitWriteThrough(...)` before returning HTTP `200`/`201`.
- `CreateVoiceCloneRequestSchema` (`voice_types.ts`) `SHALL` accept an optional validated `id` (`z.string().min(4).max(96).optional()`) so the server preserves the client-generated `vclone_*` ID whenever provided instead of minting an unreferenced random ID.
- `registerVoiceCloneProfile` (`voice_catalog.ts`) `MUST NOT` emit dead `https://r2.vhunambi.com/...` URLs; it `SHALL` resolve relative keys through `resolveMediaUrl(..., c)`.

### `REQ-P75-BE-03` — Mastering Bake Cross-Isolate SWR & Awaited Persistence (`MST-01`)
- `WHEN` `POST /v1/generations/:id/master` executes in `generation_routes.ts` and `getJob(id)` is empty in the current Worker isolate, the route `SHALL` call `await vhunambiDb.syncGenerationJobFromCloud(id, c)` before returning `404 NOT_FOUND`.
- `WHEN` a generation job is mastered, the route `SHALL` persist the enriched `MasterMediaObjectManifest` and mastered asset URLs via `await vhunambiDb.updateGenerationJobAsync(id, ..., c)` so subsequent `GET /v1/generations/:id/manifest` calls on any isolate observe the baked mastering recipe.

### `REQ-P75-BE-04` — 100% Scoped Read-Through Isolation in `server.ts`
- `hasScopedReadThrough` in `apps/vhunambi_api/src/server.ts` `SHALL` preserve all existing prefixes (`/api/notifications`, `/api/wallet`, `/api/explore`, `/api/social`, `/api/library`, `/api/playlists`, `/api/marketplace`, `/v1/generations`, `/v1/vision`, `/v1/webhooks` and their `/api/v1/*` aliases) and append `/v1/voices`, `/v1/melodies`, and `/v1/lyrics` so read/LLM/preset calls never stall on a 21-table `ensureColdStartHydrated` scan.

---

## 3. Connectome Closure: Lyrics, Sketchpad, Voice & Mastering Clients (`REQ-P75-CON-*`)

### `REQ-P75-CON-01` — Line-Level AI Refinement & Story-to-Lyrics (`EP-P66-LYRICS-REFINE-STORY`)
- `ILyricsGenerationService` and `HttpLyricsGenerationService` `SHALL` implement:
  - `refineLyrics({ required String currentLyrics, required String refinementInstruction, String? idiomToInsert, String? genre, String? language })` calling `POST /v1/lyrics/refine` and parsing `data['rawLyrics']`.
  - `transformStoryToLyrics({ required String storyText, required String genre, required String language, List<String>? targetCognateLanguages, List<String>? mood })` calling `POST /v1/lyrics/story-transform` and parsing `data['structuredLyrics']`.
- `HttpLyricsGenerationService` `SHALL` normalize Flutter display language names (e.g., `'Tshivenḓa'` $\to$ `'ve'`, `'isiZulu'` $\to$ `'zu'`, `'isiXhosa'` $\to$ `'xh'`, `'Sesotho'` $\to$ `'st'`, `'Setswana'` $\to$ `'tn'`, `'Sepedi'` $\to$ `'nso'`, `'Xitsonga'` $\to$ `'ts'`, `'siSwati'` $\to$ `'ss'`, `'isiNdebele'` $\to$ `'nr'`, `'English'` $\to$ `'en'`) and map non-story genres (`Afro House`, `Afrobeats`, `Lekompo`, etc.) onto valid `STORY_GENRES` (`amapiano` default) before posting.
- `LyricsReviewModal`:
  - `WHEN` `Key('lyrics_story_mode_toggle')` is active, it `SHALL` continue displaying `'Story-to-Lyrics Mode Active'` (backward test compatibility) AND render an interactive story text field (`Key('lyrics_story_input')`) plus a transform action (`Key('lyrics_story_transform_btn')`) that requires $\ge 20$ trimmed characters and invokes `LyricsReviewNotifier.transformStory(...)`.
  - Each `_LyricsSectionCard` `SHALL` provide a compact AI Polish button (`Key('stanza_refine_${section.id}')`, minimum $44 \times 44\text{dp}$ touch target) invoking `LyricsReviewNotifier.refineSection(...)` via `POST /v1/lyrics/refine`.

### `REQ-P75-CON-02` — Dynamic Sketchpad Presets & Real Sound Pack Catalog (`EP-P27-MELODY-PRESETS-PACKS`)
- `MelodySketchpadNotifier` `SHALL` expose `Future<void> syncStarterPresetsFromCloud({String? genre})` fetching `GET /v1/melodies/presets` and updating `state.starterPresets` while retaining `kStarterMelodyPatterns` on offline error or headless `FLUTTER_TEST` without injected HTTP client.
- `SoundPackManagerNotifier` `SHALL` expose `Future<void> syncSoundPacksFromCloud()` fetching `GET /v1/melodies/sound-packs` (preserving existing Hive `isInstalled` flags by pack ID).
- `WHEN` `downloadSoundPack(packId)` runs in production mode with a non-empty HTTPS `pack.downloadUrl` (outside `FLUTTER_TEST` or with an injected `Dio`), it `SHALL` perform a real HTTP `GET` request with `onReceiveProgress` updates rather than relying solely on a hardcoded `30ms` fake loop, degrading gracefully with deterministic progress only in headless test/offline fallback mode.

### `REQ-P75-CON-03` — Voice Calibration Extraction & Sound Signature Recipe Cloud Sync (`EP-P26-VOICE-CALIBRATION-RECIPE`)
- `VocalIdentityNotifier` `SHALL` expose:
  - `Future<PhoneticCalibrationScript> prepareCalibrationFromLyricsAsync(String lyrics, {String language})` calling `POST /v1/voices/extract-calibration` with instant local `PhoneticCalibrationExtractor` fallback offline or in `FLUTTER_TEST`.
  - `Future<void> syncCatalogFromCloud()` calling `GET /v1/voices/catalog` with `kRegionalVoiceCatalog` fallback.
- `PreGenR2UploadService.uploadVoiceCloneReference(...)` `SHALL` forward `'id': profileId` and `'creatorId': creatorId` to `POST /v1/voices/clone`.
- `SoundSignatureRepository` `SHALL` implement:
  - `Future<bool> updateRecipeInCloud({required String signatureId, required SoundIdealizerRecipe recipe, Dio? dio})` calling `PATCH /v1/voices/signatures/$signatureId/recipe`.
  - `Future<SoundSignatureDna?> fetchSignatureFromCloud(String signatureId, {Dio? dio})` calling `GET /v1/voices/signatures/$signatureId`.
  - `Future<bool> deleteSignatureInCloud(String signatureId, {Dio? dio})` calling `DELETE /v1/voices/signatures/$signatureId`.
- `CrossModuleSynergyDeck` (`cross_module_synergy_deck.dart#L121`) `SHALL` wire `onSaveRecipe`, `onUseAsVoiceClone`, and `onDelete` callbacks on `SoundSignatureIdealizerSheet` so recipe edits persist both locally in Hive (`saveSignature`) and remotely via `PATCH /v1/voices/signatures/:id/recipe`.

### `REQ-P75-CON-04` — Server Mastering Presets, Honest Error Handling & Real Manifest Stems (`EP-P25-GEN-MASTER-PRESETS`)
- `GenreMasterPreset` (`stem_mastering_recipe.dart`) `SHALL` provide `factory GenreMasterPreset.fromJson(Map<String, dynamic> json)` using `JsonSafe`-grade defensive parsing.
- `MasteringSessionState` `SHALL` hold `List<GenreMasterPreset> availablePresets` (defaulting to `kGenreMasterPresets`), and `MasteringSessionNotifier` `SHALL` expose `Future<void> syncMasteringPresetsFromCloud({String? genre})` fetching `GET /v1/generations/mastering/presets`.
- `WHEN` `bakeProductionMaster(...)` receives a non-2xx HTTP status or network error outside `FLUTTER_TEST` with no injected mock client, it `MUST NOT` fabricate `/mock-storage/${trackId}_mastered.mp3` with `hasBakedMaster: true`; it `SHALL` set `isBaking: false`, `hasBakedMaster: false`, and a clear `errorMessage` and return `false`.
- `TrackDetailNotifier` (`track_providers.dart`) `SHALL` expose `Future<bool> loadManifestFromCloud({http.Client? client})` calling `GET /v1/generations/$trackId/manifest` to hydrate real R2 `stemUrls` (`vocals`, `drums`, `bass`, `other`/`instrumental`) into `StemSeparationState` (preserving canonical IDs `'${trackId}_vocals'`, `'${trackId}_drums'`, `'${trackId}_bass'`, `'${trackId}_inst'` and names `['Vocals', 'Drums', 'Bass & Log Drums', 'Instrumental']`).
- `TrackDetailNotifier.separateStems()` `SHALL` query `loadManifestFromCloud()` first before falling back to normalized R2 URLs (`AppConstants.resolveMediaBaseUrl()`) — never emitting dead `https://cdn.vhunambi.com/...` URLs.
- `TrackDetailView`'s `onDownloadStem` (`#L705-713`) `SHALL` dispatch real stem downloads via `ref.read(stemDownloadServiceProvider).downloadStems(stem.audioUrl)` instead of a `SnackBar`-only dead-end.

---

## 4. Direct Creation-to-Viral Bridge & Teleprompter Sanitizer (`REQ-P75-BRIDGE-*`)

### `REQ-P75-BRIDGE-01` — Unified 1-Tap Launch into `KineticReelStudioView` (`EP-P74-REELS-STUDIO-PIPELINE`)
- `WHEN` a creator taps:
  1. `Key('pipeline_create_reel_btn')` inside `GenerationPipelineCard` (`_ReadyTrackCard`),
  2. `'Export Reel'` inside `TrackDetailView` (`UtilityToolDock`),
  3. `'Create Lyric Reel'` inside `TrackActionsSheet`, or
  4. The Create Reel action inside `ExpandedCockpitModal` (`_openContentStudio`),
  the app `SHALL` launch `KineticReelStudioView.show(context, initialTrack: libraryTrack)` pre-loaded with the track's normalized R2 audio URL, cover art, genre, mood, and lyrics—never opening legacy `ContentStudioDockView.open(...)` or `VideoExportModal` with dead `r2.vhunambi.com`/`cdn.vhunambi.com` URLs.

### `REQ-P75-BRIDGE-02` — Sanitized Track Teleprompter (`EP-P74-KARAOKE-LYRIC-SANITIZER`)
- `LyricKaraokeSanitizer` (`lyric_karaoke_sanitizer.dart`) `SHALL` expose `static String cleanLyricsForTeleprompter(String rawLyrics)` that preserves readable structural stanza headers (`[Intro]`, `[Verse 1]`, `[Chorus]`, `[Pre-Chorus]`, `[Bridge]`, `[Outro]`, `[Hook]`) while stripping metadata headers (`Title:`, `Genre:`, `BPM:`), long instrumental cue brackets (`[Crisp soft shakers, airy synth pads]`), and parenthetical cues (`(x2)`, `(Repeat)`).
- `LyricsTeleprompter` (`lyrics_teleprompter.dart`) `SHALL` pass `widget.track.lyrics` through `LyricKaraokeSanitizer.cleanLyricsForTeleprompter(...)` prior to rendering and translation.

---

## 5. `STD-UIUX-001`, Glass Parity & Non-Functional Requirements (`REQ-P75-UI-*`, `REQ-P75-NFR-*`)

### `REQ-P75-UI-01` — Zero Stock `Icons.*` & Zero Raw Unicode Emojis (`STD-UIUX-001`)
- All Phase 75 target presentation files (`desktop_mastering_studio_view.dart`, `mobile_quick_master_sheet.dart`, `lyrics_review_modal.dart`, `generation_pipeline_card.dart`, `bantu_voice_deck.dart`, `vocal_identity_picker_sheet.dart`, `voice_clone_recorder_sheet.dart`, `studio_view.dart`, `mpc_slicer_deck.dart`, `crate_browser_deck.dart`, `guided_lyrics_composer.dart`, `prompt_input_box.dart`, `prompt_intelligence_overlay.dart`, `reference_audio_dropzone.dart`, `regional_genre_selector.dart`, `multilingual_language_selector.dart`, `bantu_language_switcher.dart`, `direct_daw_vocal_upload_sheet.dart`, `studio_session_recovery_banner.dart`, `live_phonetic_alignment_preview.dart`, `option_preview_chip.dart`) `MUST` replace every stock `Icon(Icons.*)` with `PhosphorIcon(AppIcons.*)` / `PhosphorIconsRegular.*` / `PhosphorIconsFill.*` and purge every raw Unicode emoji (`🎙️`, `🪵`, `🥁`, `🎹`, `🔥`, `🧬`, `🌐`, `🚀`, `🔒`, etc.) from rendered UI strings.
- Inline text inputs inside `LyricsReviewModal` (`#L685`, `#L785`) `SHALL` declare explicit `focusedBorder: InputBorder.none` and `enabledBorder: InputBorder.none` to prevent Phase 73 orange focus-box leakage.

### `REQ-P75-UI-02` — Glass Surface Parity & Dynamic Theme Tokens
- `DesktopMasteringStudioView`, `MobileQuickMasterSheet`, `LyricsReviewModal`, and `StudioView` action/card containers `SHALL` adopt `VhunambiGlassSurface` (with `enableLiveBlur: false` on repeating/scrollable cards) and dynamic `AppColors.*Of(context)` getters for clean Light and Dark mode contrast.
- All interactive buttons and icon targets added or refactored in Phase 75 `SHALL` meet the $\ge 44 \times 44\text{dp}$ minimum hit area invariant and render cleanly at `360x800` without `RenderFlex` overflow.

### `REQ-P75-NFR-01` — Headless Test Isolation, `JsonSafe` & Backward Test Preservation
- All newly introduced network calls (`syncStarterPresetsFromCloud`, `syncSoundPacksFromCloud`, `prepareCalibrationFromLyricsAsync`, `syncCatalogFromCloud`, `syncMasteringPresetsFromCloud`, `loadManifestFromCloud`, `updateRecipeInCloud`) `SHALL` detect `FLUTTER_TEST` and short-circuit cleanly unless a custom `Dio`/`http.Client` is injected by tests.
- Defensive deserialization in `sound_signature_dna.dart` and `phonetic_articulation_profile.dart` `SHALL` guard map/list casts with `JsonSafe` helpers (`JsonSafe.asMap`, `JsonSafe.asList`) so corrupt records never throw `TypeError`.

---

## 6. Requirement-to-Verification Traceability Matrix

| Requirement ID | Primary Implementation Anchor(s) | Verification Test Case |
| :--- | :--- | :--- |
| `REQ-P75-BE-01..02` | `edge_persistence_bridge.ts`, `vhunambi_db.ts`, `voice_routes.ts`, `voice_types.ts` | `phase75_studio_connectome_closure.test.ts`: Voice & Signature 12s SWR across isolates + client `id` preservation |
| `REQ-P75-BE-03..04` | `generation_routes.ts`, `server.ts` | `phase75_studio_connectome_closure.test.ts`: Cross-isolate `POST /:id/master` hydration + `hasScopedReadThrough` bypass |
| `REQ-P75-CON-01` | `http_lyrics_generation_service.dart`, `lyrics_review_provider.dart`, `lyrics_review_modal.dart` | `phase75_studio_connectome_closure_test.dart`: `refineLyrics` + `transformStoryToLyrics` (`structuredLyrics`) + Story drawer UI |
| `REQ-P75-CON-02` | `melody_sketchpad_provider.dart`, `sound_pack_manager_provider.dart` | `phase75_studio_connectome_closure_test.dart`: Cloud presets sync + sound packs catalog & Dio download |
| `REQ-P75-CON-03` | `vocal_identity_provider.dart`, `pre_gen_r2_upload_service.dart`, `sound_signature_repository.dart`, `cross_module_synergy_deck.dart` | `phase75_studio_connectome_closure_test.dart`: `extract-calibration` + `PATCH /signatures/:id/recipe` from Idealizer save |
| `REQ-P75-CON-04` | `stem_mastering_recipe.dart`, `mastering_session_provider.dart`, `track_providers.dart`, `track_detail_view.dart` | `phase75_studio_connectome_closure_test.dart`: Cloud mastering presets + honest error on 500 + `/manifest` 4-stem hydration |
| `REQ-P75-BRIDGE-01..02` | `generation_pipeline_card.dart`, `track_detail_view.dart`, `track_actions_sheet.dart`, `expanded_cockpit_modal.dart`, `lyric_karaoke_sanitizer.dart`, `lyrics_teleprompter.dart` | `phase75_studio_connectome_closure_test.dart`: 1-tap `KineticReelStudioView` launch + teleprompter cue sanitization |
| `REQ-P75-UI-01..02` | `mastering/`, `studio/`, `track/` | Static `Select-String` hygiene audit (`0` stock `Icons.*`, `0` raw emojis) + `360x800` dark/light widget tests |
