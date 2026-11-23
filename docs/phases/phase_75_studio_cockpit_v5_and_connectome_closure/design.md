# VHUNAMBI PHASE 75: ARGON-HARDENED TECHNICAL DESIGN SPECIFICATION

**Document ID:** `VHUNAMBI-SPEC-P75-DESIGN-V1`  
**Phase:** `75`  
**Status:** `ARGON-HARDENED (100% VERIFIED AGAINST LIVE CODEBASE)`  
**Grounding Audit:** [`docs/audits/PHASE75_STUDIO_COCKPIT_V5_AND_CONNECTOME_CLOSURE_AUDIT.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/audits/PHASE75_STUDIO_COCKPIT_V5_AND_CONNECTOME_CLOSURE_AUDIT.md)

---

## 1. Live Codebase Verification & Pre-Caught Spec/Test Landmines

Every backend helper, Dart model constructor, icon token, and existing test file below was verified directly against commit `63441ff`:

1. **Live `EdgeIsolateDatabaseEngine` Primitives (`edge_persistence_bridge.ts`):**
   - `this.resolveCloudDriver(cOrEnv)` (`#L525`)
   - `EdgeIsolateDatabaseEngine.withTimeoutResult(promise, timeoutMs)` (`#L637`)
   - `this.mirrorWriteThrough('label', async (driver) => ...)` (`#L660`)
   - `this.awaitWriteThrough('label', async (driver) => ..., cOrEnv)` (`#L688`)
   - `this.domainHydratedAtMs`, `this.domainInFlightPromises`, `EdgeIsolateDatabaseEngine.DEFAULT_SWR_TTL_MS` (`12_000`)
   - `this.upsertGenerationJobAsync(job, creatorId, jobKind, cOrEnv)` (`#L6616`) already exists!
   - Every new async method added to `EdgeIsolateDatabaseEngine` **MUST** have a matching proxy method on `VhunambiDatabase` (`vhunambi_db.ts`) for `tsc --noEmit` parity.
2. **Exact Wire Field Names Verified Against Disk:**
   - `POST /v1/lyrics/refine` (`lyrics_routes.ts#L94-100`) returns `{ success: true, rawLyrics, stanzas, refinementApplied, provider }`.
   - `POST /v1/lyrics/story-transform` (`story_transform.ts#L305-317`) returns `{ success: true, structuredLyrics, stanzas, hookLine, genre, genreStructureUsed, vocalInstructions, compiledCaption, language, cognateTargets, storyLineCount, version }` — note **`structuredLyrics`**, NOT `rawLyrics`!
   - `GET /v1/melodies/presets` (`melody_routes.ts#L58-62`) returns `{ totalCount, filteredCount, presets }` matching `MelodyPatternEntity.fromJson`.
   - `GET /v1/melodies/sound-packs` (`melody_routes.ts#L70-164`) returns `{ totalCount, soundPacks }` matching `StudioSoundPackEntity.fromJson`.
   - `POST /v1/voices/extract-calibration` (`voice_routes.ts#L79-82`) returns `{ success: true, script }` matching `PhoneticCalibrationScript`.
   - `GET /v1/generations/mastering/presets` (`generation_routes.ts#L238-243`) returns `{ recommended?, presets }` matching `GenreMasterPreset`.
   - `GET /v1/generations/:id/manifest` (`generation_routes.ts#L350-366`) returns `MasterMediaObjectManifest` with `assets: { masterMp3Url, stemsZipUrl, stemUrls: { vocals, drums, bass, other/instrumental } }`.
3. **4 Pre-Caught Legacy Test Landmines (Must Preserve or Update Cleanly):**
   - `test/features/studio/presentation/widgets/generation_pipeline_card_test.dart#L130,143,236` asserts `find.byIcon(Icons.check)` — update to `AppIcons.check` when replacing `Icons.check` in `generation_pipeline_card.dart#L385`.
   - `test/features/studio/presentation/widgets/lyrics_review_modal_test.dart#L370` asserts `expect(find.textContaining('Story-to-Lyrics Mode Active'), findsOneWidget)` — retain `'Story-to-Lyrics Mode Active'` in the upgraded Story composer panel header.
   - `test/features/track/track_notifier_test.dart#L171-195` asserts `notifier.separateStems()` on `'seed-01'` produces `4` stems named `['Vocals', 'Drums', 'Bass & Log Drums', 'Instrumental']` with ID `'seed-01_vocals'` — keep those exact canonical IDs and labels when hydrating from `/manifest` or R2 fallback.
   - `test/features/mastering/mastering_session_provider_test.dart#L275` constructs `MasteringSessionNotifier(ref, httpClient: mockClient)` — preserve that exact constructor signature.

---

## 2. Pass 1 (`M75.1`) — Cloudflare Worker Voice/Mastering SWR & Route Isolation (`apps/vhunambi_api`)

### 2.1 `apps/vhunambi_api/src/modules/voices/voice_types.ts`
Extend `CreateVoiceCloneRequestSchema` (`#L58-66`) with an optional validated client ID so client-generated `vclone_*` IDs stay 1:1 with R2 keys and Supabase `voice_clones.voice_id`:

```ts
export const CreateVoiceCloneRequestSchema = z.object({
  id: z.string().min(4).max(96).optional(),
  creatorId: z.string().optional(),
  creatorName: z.string().min(1).default('Sovereign Creator'),
  nativeLanguage: z.string().default('Tshivenḓa'),
  calibrationLines: z.array(z.string()).min(1).max(5),
  recordingDurationSec: z.number().min(3).max(60).default(18),
  audioBase64: z.string().optional(),
  r2ReferenceUrl: z.string().optional(),
});
```

### 2.2 `apps/vhunambi_api/src/db/edge_persistence_bridge.ts` & `apps/vhunambi_api/src/db/vhunambi_db.ts` (1:1 Parity)

Add dedicated hydration helpers, 12-second SWR `syncVoicesFromCloud`, awaited voice/signature write-throughs, and `updateGenerationJobAsync`:

```ts
// Inside EdgeIsolateDatabaseEngine (edge_persistence_bridge.ts):

private hydrateVoiceCloneRows(voiceRows: Array<Record<string, any>>): void {
  for (const vc of voiceRows) {
    if (!vc.voice_id) continue;
    const id = String(vc.voice_id);
    const createdAt = String(vc.created_at ?? new Date().toISOString());
    this.voiceClones.set(id, {
      id,
      voiceId: id,
      creatorId: canonicalizeCreatorId(String(vc.creator_id ?? 'creator_cern')),
      displayName: String(vc.display_name ?? 'Cloned Voice'),
      creatorName: String(vc.display_name ?? 'Cloned Voice'),
      consentVerified: Boolean(vc.consent_verified ?? true),
      referenceAudioDurationSec: Number(vc.reference_audio_duration_sec ?? 15.0),
      r2ReferenceUrl: String(vc.r2_reference_url ?? ''),
      pitchRangeHz: vc.pitch_range_hz_json ?? [110, 660],
      timbreEmbedding: vc.timbre_embedding_json ?? [],
      timbreEmbeddingPreview: vc.timbre_embedding_json ?? [],
      createdAt,
      createdAtIso: createdAt,
    });
  }
}

private hydrateSoundSignatureRows(signaturesRows: Array<Record<string, any>>): void {
  for (const ss of signaturesRows) {
    if (!ss.id) continue;
    const parsedData =
      ss.data_json && typeof ss.data_json === 'object'
        ? (ss.data_json as Record<string, any>)
        : {};
    this.soundSignatures.set(String(ss.id), {
      ...parsedData,
      id: String(ss.id),
      creatorId: canonicalizeCreatorId(String(ss.creator_id ?? parsedData.creatorId ?? 'creator_cern')),
      name: String(ss.name ?? parsedData.displayCode ?? 'Sound Signature'),
      category: String(ss.category ?? 'vocal_DNA'),
      status: String(ss.status ?? 'awaiting_upload'),
      r2AudioKey: String(ss.r2_audio_key ?? parsedData.r2AudioKey ?? ''),
      recipe: ss.recipe_json ?? parsedData.recipe ?? {},
      embedding: ss.embedding_json ?? parsedData.embedding ?? [],
      consentAtIso: String(ss.consent_at_iso ?? parsedData.consentAtIso ?? ''),
    });
  }
}

public async syncVoicesFromCloud(
  force = false,
  cOrEnv?: unknown,
): Promise<boolean> {
  const driver = this.resolveCloudDriver(cOrEnv);
  if (!driver.isConfigured()) return false;

  const domainKey = 'voices:global';
  const lastHydrated = this.domainHydratedAtMs.get(domainKey) ?? 0;
  if (
    !force &&
    lastHydrated > 0 &&
    Date.now() - lastHydrated < EdgeIsolateDatabaseEngine.DEFAULT_SWR_TTL_MS
  ) {
    return true;
  }

  const inflight = this.domainInFlightPromises.get(domainKey);
  if (inflight) return (await inflight) as boolean;

  const task = (async (): Promise<boolean> => {
    const [voicesRes, sigsRes] = await Promise.all([
      EdgeIsolateDatabaseEngine.withTimeoutResult(
        driver.selectRows<Record<string, any>>('voice_clones', 'select=*&limit=200'),
        3500,
      ),
      EdgeIsolateDatabaseEngine.withTimeoutResult(
        driver.selectRows<Record<string, any>>('sound_signatures', 'select=*&limit=200'),
        3500,
      ),
    ]);

    if (voicesRes.ok) this.hydrateVoiceCloneRows(voicesRes.value);
    if (sigsRes.ok) this.hydrateSoundSignatureRows(sigsRes.value);

    const allOk = voicesRes.ok && sigsRes.ok;
    if (allOk) {
      this.domainHydratedAtMs.set(domainKey, Date.now());
    }
    return allOk;
  })().finally(() => {
    this.domainInFlightPromises.delete(domainKey);
  });

  this.domainInFlightPromises.set(domainKey, task);
  return task;
}

public async upsertVoiceCloneAsync(
  profile: Record<string, any>,
  cOrEnv?: unknown,
): Promise<void> {
  const voiceId = String(profile.voiceId || profile.id);
  const mergedProfile = { ...profile, id: voiceId, voiceId };
  this.voiceClones.set(voiceId, mergedProfile);
  await this.awaitWriteThrough(
    'voice_clones.upsert',
    async (driver) => {
      await driver.upsertRow(
        'voice_clones',
        {
          voice_id: voiceId,
          creator_id: canonicalizeCreatorId(String(profile.creatorId || 'creator_cern')),
          display_name: String(profile.displayName || profile.creatorName || 'Cloned Voice'),
          consent_verified: Boolean(profile.consentVerified ?? true),
          reference_audio_duration_sec: Number(profile.referenceAudioDurationSec ?? 15.0),
          r2_reference_url: String(profile.r2ReferenceUrl || ''),
          pitch_range_hz_json: profile.pitchRangeHz ?? [110, 660],
          timbre_embedding_json: profile.timbreEmbedding ?? profile.timbreEmbeddingPreview ?? [],
          created_at: String(profile.createdAt || profile.createdAtIso || new Date().toISOString()),
        },
        'voice_id',
      );
    },
    cOrEnv,
  );
}

public async upsertSoundSignatureAsync(
  sig: Record<string, any>,
  cOrEnv?: unknown,
): Promise<void> {
  const id = String(sig.id);
  this.soundSignatures.set(id, { ...sig });
  await this.awaitWriteThrough(
    'sound_signatures.upsert',
    async (driver) => {
      await driver.upsertRow(
        'sound_signatures',
        {
          id,
          creator_id: canonicalizeCreatorId(String(sig.creatorId || 'creator_cern')),
          name: String(sig.name || sig.displayCode || 'Sound Signature'),
          category: String(sig.category || 'vocal_DNA'),
          status: String(sig.status || 'awaiting_upload'),
          r2_audio_key: String(sig.r2AudioKey || ''),
          recipe_json: sig.recipe ?? {},
          embedding_json: sig.embedding ?? [],
          consent_at_iso: String(sig.consentAtIso || ''),
          data_json: sig,
          updated_at: Date.now(),
        },
        'id',
      );
    },
    cOrEnv,
  );
}

public async deleteSoundSignatureAsync(
  sigId: string,
  cOrEnv?: unknown,
): Promise<boolean> {
  const deleted = this.soundSignatures.delete(sigId);
  if (deleted) {
    await this.awaitWriteThrough(
      'sound_signatures.delete',
      async (driver) => {
        await driver.deleteRows('sound_signatures', `id=eq.${encodeURIComponent(sigId)}`);
      },
      cOrEnv,
    );
  }
  return deleted;
}

public async updateGenerationJobAsync(
  generationId: string,
  updates: Partial<GenerationJob>,
  cOrEnv?: unknown,
): Promise<GenerationJob | null> {
  const entry = this.generationJobs.get(generationId);
  if (!entry) return null;
  const merged: GenerationJob = {
    ...entry.job,
    ...updates,
    updatedAt: new Date(),
  };
  await this.upsertGenerationJobAsync(merged, entry.creatorId, entry.jobKind, cOrEnv);
  return this.getGenerationJob(generationId);
}
```

In `vhunambi_db.ts` (`VhunambiDatabase`), expose matching methods delegating to `EdgeIsolateDatabaseEngine` when `!this.db` and executing synchronous SQLite `upsertVoiceClone` / `upsertSoundSignature` / `deleteSoundSignature` / `updateGenerationJob` when SQLite is active (and `syncVoicesFromCloud` returning `false` on local SQLite).

### 2.3 `apps/vhunambi_api/src/modules/voices/voice_catalog.ts` & `voice_routes.ts`
- In `voice_catalog.ts`:
  - Update `registerVoiceCloneProfile` to honor `req.id?.trim()` when provided, resolve `r2ReferenceUrl` via `resolveMediaUrl(req.r2ReferenceUrl ?? \`voice-clones/${id}_ref.wav\`, c)` (zero dead `https://r2.vhunambi.com` URLs!), and add async variants `registerVoiceCloneProfileAsync`, `registerSoundSignatureAsync`, `updateSoundSignatureRecipeAsync`, and `deleteSoundSignatureAsync` backed by the `*Async` DB methods.
  - Replace `/mock-storage/vox_*.mp3` preview paths in `RAW_REGIONAL_VOICE_CATALOG` with `voices/previews/vox_*.mp3` resolved via `resolveMediaUrl(...)`.
- In `voice_routes.ts`:
  - Convert `GET /clone/:id`, `GET /signatures/:id` to `async` and call `await vhunambiDb.syncVoicesFromCloud(false, c)` inside `GET /clone/:id`, `POST /signatures/:id/analyze`, `PATCH /signatures/:id/recipe`, `GET /signatures/:id`, and `DELETE /signatures/:id`.
  - Use `registerVoiceCloneProfileAsync`, `registerSoundSignatureAsync`, `updateSoundSignatureRecipeAsync`, and `deleteSoundSignatureAsync` so every write awaits Supabase before returning HTTP `200`/`201`.

### 2.4 `apps/vhunambi_api/src/routes/generation_routes.ts` & `apps/vhunambi_api/src/server.ts`
- In `generation_routes.ts` (`POST /:id/master`, `#L374-439`):
  ```ts
  generationRoutes.post('/:id/master', async (c) => {
    const id = c.req.param('id');
    let job = getJob(id);
    if (!isNodeSqliteAvailable() && !job) {
      job = (await vhunambiDb.syncGenerationJobFromCloud(id, c)) ?? undefined;
    }
    const isSeededTrack = id.startsWith('trk_') || id.startsWith('seed_');
    if (!job && !isSeededTrack) {
      return c.json({ error: 'NOT_FOUND', message: `Generation job ${id} not found` }, 404);
    }
    // ... validate StemMasteringRecipeSchema & build enrichedManifest ...
    if (job) {
      await vhunambiDb.updateGenerationJobAsync(
        id,
        {
          status: 'succeeded',
          step: 'ready',
          progressPct: 100,
          masterMp3Url: enrichedManifest.assets.masterMp3Url,
          stemsZipUrl: enrichedManifest.assets.stemsZipUrl,
          stemUrls: enrichedManifest.assets.stemUrls,
          durationSec: job.durationSec || 180,
          manifestUrl: `/v1/generations/${id}/manifest`,
          manifest: enrichedManifest,
        },
        c,
      );
    }
    // ... return 200 ...
  });
  ```
- In `server.ts#L53-70` (`hasScopedReadThrough`): append:
  ```ts
      p.startsWith('/v1/voices') ||
      p.startsWith('/v1/melodies') ||
      p.startsWith('/v1/lyrics')
  ```

---

## 3. Pass 1 (`M75.2`) — Client Connectome Closure Engines (`apps/vhunambi_client`)

### 3.1 `EP-P66-LYRICS-REFINE-STORY` — Lyrics Service, Notifier & Story/Refine UI

#### `i_lyrics_generation_service.dart`, `fake_lyrics_generation_service.dart`, `http_lyrics_generation_service.dart`
Add two methods to `ILyricsGenerationService` with concrete implementations in both `FakeLyricsGenerationService` and `HttpLyricsGenerationService`:

```dart
abstract class ILyricsGenerationService {
  Future<LyricsReviewDraft> generateLyrics({
    required String prompt,
    required String genre,
    required String language,
  });

  Future<LyricsReviewDraft> refineLyrics({
    required String currentLyrics,
    required String refinementInstruction,
    String? idiomToInsert,
    required String genre,
    required String language,
    String prompt = '',
  });

  Future<LyricsReviewDraft> transformStoryToLyrics({
    required String storyText,
    required String genre,
    required String language,
    List<String>? targetCognateLanguages,
    List<String>? mood,
  });

  List<String> getCulturalIdioms(String language);
}
```

Canonical language & genre normalizers in `HttpLyricsGenerationService`:
- `normalizeLanguageCode(String raw)` maps `'tshivenda'`/`'tshivenḓa'`/`'venda'` $\to$ `'ve'`, `'isizulu'`/`'zulu'` $\to$ `'zu'`, `'isixhosa'`/`'xhosa'` $\to$ `'xh'`, `'sesotho'`/`'sotho'` $\to$ `'st'`, `'setswana'`/`'tswana'` $\to$ `'tn'`, `'sepedi'`/`'northern sotho'` $\to$ `'nso'`, `'xitsonga'`/`'tsonga'` $\to$ `'ts'`, `'siswati'`/`'swati'` $\to$ `'ss'`, `'isindebele'`/`'ndebele'` $\to$ `'nr'`, `'kiswahili'`/`'swahili'` $\to$ `'sw'`, `'yoruba'` $\to$ `'yo'`, `'igbo'` $\to$ `'ig'`, `'english'` $\to$ `'en'`, defaulting to `'zu'`.
- `normalizeStoryGenre(String raw)` maps lowercase genre to one of `{'amapiano', 'maskandi', 'gqom', 'gospel', 'kwaito', 'hiphop'}` (mapping `'hip-hop'`/`'hip hop'` $\to$ `'hiphop'`, and other African dance genres to `'amapiano'`).
- `refineLyrics(...)` POSTs to `'$_baseUrl/lyrics/refine'` and parses `data['rawLyrics']`.
- `transformStoryToLyrics(...)` POSTs to `'$_baseUrl/lyrics/story-transform'` with `storyText`, `genre: normalizeStoryGenre(genre)`, `baseLanguage: normalizeLanguageCode(language)`, and parses **`data['structuredLyrics'] as String? ?? ''`**!
- Both degrade safely to `FakeLyricsGenerationService` offline or when `FLUTTER_TEST` has no injected custom `Dio`.

#### `lyrics_review_provider.dart`
Add `Future<bool> refineSection(String sectionId, String instruction)` and `Future<bool> transformStory({required String storyText, List<String>? mood})` onto `LyricsReviewNotifier`, guarding state updates with `if (!mounted) return false;`.

#### `lyrics_review_modal.dart`
- When `_storyMode` is true, preserve the exact text `'Story-to-Lyrics Mode Active'` inside the panel header (`lyrics_review_modal_test.dart#L370`), add a `TextField` (`Key('lyrics_story_input')`, `border: InputBorder.none`, `focusedBorder: InputBorder.none`) + `'Transform Story'` `ElevatedButton` (`Key('lyrics_story_transform_btn')`, enabled when `text.trim().length >= 20`) calling `notifier.transformStory(...)`.
- On each `_LyricsSectionCard`, add a compact `$44\times44\text{dp}$` AI Polish button (`Key('stanza_refine_${section.id}')`, `PhosphorIcon(AppIcons.sparkle)`) invoking `notifier.refineSection(section.id, 'Tighten rhythm, imagery, and authentic cadence')`.
- Add explicit `focusedBorder: InputBorder.none` & `enabledBorder: InputBorder.none` on `#L683` and `#L784`, and replace all `11` stock `Icons.*` + literal `'➔'` (`#L883`) with `PhosphorIcon(AppIcons.*)`.

### 3.2 `EP-P27-MELODY-PRESETS-PACKS` — Sketchpad Presets & Real Sound Pack Fetching

- In `melody_sketchpad_provider.dart`:
  - Add optional `Dio? dio` constructor parameter (defaulting to `Dio` with `authDioInterceptorProvider` in `melodySketchpadProvider`).
  - Add `Future<List<MelodyPatternEntity>> syncStarterPresetsFromCloud({String? genre})` calling `GET ${AppConstants.apiBaseUrl}/melodies/presets` (skipped in `FLUTTER_TEST` unless custom `Dio` injected), parsing `presets` defensively via `MelodyPatternEntity.fromJson`, updating `state.starterPresets` while retaining `kStarterMelodyPatterns` fallback.
- In `sound_pack_manager_provider.dart`:
  - Add optional `Dio? dio` and `bool? isTestMode` parameters (default constructor `SoundPackManagerNotifier()` remains backward compatible for existing tests!).
  - Add `Future<void> syncSoundPacksFromCloud()` calling `GET ${AppConstants.apiBaseUrl}/melodies/sound-packs`, merging server `StudioSoundPackEntity` items with locally persisted `isInstalled` flags in Hive.
  - Upgrade `downloadSoundPack(String packId)`: when `pack.downloadUrl.startsWith('http') && !_shouldSkipNetwork`, execute `_dio.get<List<int>>(pack.downloadUrl, options: Options(responseType: ResponseType.bytes), onReceiveProgress: ...)` updating `downloadProgress[packId]` cleanly before marking `isInstalled = true`; fall back cleanly to deterministic stepped progress in `FLUTTER_TEST` / offline mode.
  - Invoke `syncSoundPacksFromCloud()` once on `StudioSoundPackSheet` open (via `ConsumerStatefulWidget` `initState` post-frame).

### 3.3 `EP-P26-VOICE-CALIBRATION-RECIPE` — Voice Calibration & Sound Signature Cloud Sync

- In `vocal_identity_provider.dart`:
  - Add `Future<PhoneticCalibrationScript> prepareCalibrationFromLyricsAsync(String lyrics, {String language = 'Tshivenḓa', Dio? dio})` hitting `POST ${AppConstants.apiBaseUrl}/voices/extract-calibration`, parsing `data['script']` into `PhoneticCalibrationScript` with immediate fallback to `PhoneticCalibrationExtractor.extractScript(...)` when offline or in `FLUTTER_TEST` without injected `Dio`.
  - Add `Future<void> syncCatalogFromCloud({Dio? dio})` hitting `GET ${AppConstants.apiBaseUrl}/voices/catalog`.
  - In `finalizeVoiceClone(...)`, pass `creatorId: _ref.read(authSessionProvider).canonicalCreatorId` into `PreGenR2UploadService.uploadVoiceCloneReference(...)` and adopt the server-returned `profile.id` if present.
- In `pre_gen_r2_upload_service.dart#L117-156`:
  - Accept optional `String? creatorId` and include `'id': profileId` and `if (creatorId != null && creatorId.isNotEmpty) 'creatorId': creatorId` in `POST $_v1BaseUrl/voices/clone`.
- In `sound_signature_repository.dart`:
  - Add:
    - `Future<bool> updateRecipeInCloud({required String signatureId, required SoundIdealizerRecipe recipe, Dio? dio, Interceptor? authInterceptor})` calling `PATCH ${AppConstants.apiBaseUrl}/voices/signatures/$signatureId/recipe`.
    - `Future<SoundSignatureDna?> fetchSignatureFromCloud(String signatureId, {Dio? dio, Interceptor? authInterceptor})` calling `GET ${AppConstants.apiBaseUrl}/voices/signatures/$signatureId`.
    - `Future<bool> deleteSignatureInCloud(String signatureId, {Dio? dio, Interceptor? authInterceptor})` calling `DELETE ${AppConstants.apiBaseUrl}/voices/signatures/$signatureId`.
- In `cross_module_synergy_deck.dart#L121-125`:
  - Convert `CrossModuleSynergyDeck` action handler to pass `WidgetRef ref` so `SoundSignatureIdealizerSheet` wires:
    - `onSaveRecipe: (updatedRecipe)` $\to$ saves `signature.copyWith(recipe: updatedRecipe)` via `soundSignatureRepositoryProvider.saveSignature(...)` + unawaited `updateRecipeInCloud(...)`.
    - `onDelete: ()` $\to$ pops sheet, deletes via `soundSignatureRepositoryProvider.deleteSignature(signature.id)` + unawaited `deleteSignatureInCloud(signature.id)`.

### 3.4 `EP-P25-GEN-MASTER-PRESETS` — Server Mastering Presets & Real Manifest Stems

- In `stem_mastering_recipe.dart`:
  - Add `factory GenreMasterPreset.fromJson(Map<String, dynamic> json)` parsing `id`, `name`, `genre`, `description`, and `recipe: StemMasteringRecipe.fromJson(...)` safely.
- In `mastering_session_provider.dart`:
  - Add `final List<GenreMasterPreset> availablePresets;` (defaulting to `kGenreMasterPresets`) to `MasteringSessionState`.
  - Add `Future<void> syncMasteringPresetsFromCloud({String? genre, String? apiBaseUrl})` calling `GET $resolvedBaseUrl/v1/generations/mastering/presets` (skipping live network in `FLUTTER_TEST` unless custom `httpClient` was injected!).
  - Fix `bakeProductionMaster(...)` (`#L485-516`):
    - Keep `200..299` parsing intact (using `JsonSafe.asMap(jsonDecode(response.body))`).
    - On non-2xx or network exception: surface honest failure (`isBaking: false`, `hasBakedMaster: false`, `errorMessage: 'Studio master bake failed (HTTP ${response.statusCode})'`) and return `false` — **NEVER** write `/mock-storage/${state.trackId}_mastered.mp3`!
- In `track_providers.dart` & `track_detail_models.dart`:
  - Add optional `final String? audioUrl;` to `TrackDetailEntity` (populated from `LibraryTrack.remoteAudioUrl` / `Track.audioUrl` in `_lookupInitialTrack`).
  - Add `Future<List<StemTrackEntity>?> loadManifestFromCloud({http.Client? client})` on `TrackDetailNotifier` calling `GET ${AppConstants.resolveApiRootUrl()}/v1/generations/$trackId/manifest` (skipped in `FLUTTER_TEST` unless custom `client` is injected), parsing `assets.stemUrls` into the 4 canonical `StemTrackEntity` records (`${trackId}_vocals`, `${trackId}_drums`, `${trackId}_bass`, `${trackId}_inst` with normalized R2 URLs via `AppConstants.normalizeCloudMediaUrl`).
  - Update `separateStems()` to call `loadManifestFromCloud()` during the 4-step FSM; if cloud manifest returns real stems, use them verbatim; if offline/seeded, build normalized R2 URLs (`'${AppConstants.resolveMediaBaseUrl()}/stems/${trackId}_vocals.wav'`, etc.) with zero dead `cdn.vhunambi.com` strings.
- In `track_detail_view.dart`:
  - Replace hardcoded `https://cdn.vhunambi.com/audio/${track.id}.wav` (`#L392`) with `track.audioUrl ?? '${AppConstants.resolveMediaBaseUrl()}/audio/${track.id}.wav'`.
  - Replace `onDownloadStem` SnackBar dead-end (`#L705-713`) with `ref.read(stemDownloadServiceProvider).downloadStems(stem.audioUrl)` + short 2.5s auto-dismissing floating toast (`SnackBar` with zero `SnackBarAction`).

---

## 4. Pass 2 (`M75.3` – `M75.4`) — Direct-to-Reels Bridge, Teleprompter Sanitizer & `STD-UIUX-001` Glass Overhaul

### 4.1 Direct Creation-to-Viral Bridge (`EP-P74-REELS-STUDIO-PIPELINE`)
Wire all **4 legacy creation entrypoints** straight into `KineticReelStudioView.show(context, initialTrack: libraryTrack)`:
1. **`generation_pipeline_card.dart#L652-686`** (`Key('pipeline_create_reel_btn')`): Construct `LibraryTrack` from `track` (`id`, `title`, `creatorName`, `genre`, `language`, `durationSeconds`, `remoteAudioUrl: AppConstants.normalizeCloudMediaUrl(track.masterMp3Url)`, `coverImageUrl`, `lyrics`) and call `KineticReelStudioView.show(context, initialTrack: libTrack)`.
2. **`track_detail_view.dart#L415-425`** (`_openVideoExport`): Construct `LibraryTrack` from `TrackDetailEntity` and launch `KineticReelStudioView.show(context, initialTrack: libTrack)`.
3. **`track_actions_sheet.dart#L198-208`** (`handleCreateLyricReel`): Replace `ContentStudioDockView.open(...)` with `KineticReelStudioView.show(hostContext ?? context, initialTrack: track)`.
4. **`expanded_cockpit_modal.dart#L945-968`** (`_openContentStudio`): Resolve `LibraryTrack` from `libraryTracksProvider` (or construct from `Track`) and launch `KineticReelStudioView.show(context, initialTrack: resolvedTrack)`.

### 4.2 `LyricKaraokeSanitizer.cleanLyricsForTeleprompter`
Extend `lyric_karaoke_sanitizer.dart` with:
```dart
static final RegExp _structuralHeaderOnly = RegExp(
  r'^\[\s*(?:intro|verse(?:\s*\d+)?|pre[-\s]*chorus|chorus|post[-\s]*chorus|bridge|hook|outro|interlude|solo\s*verse(?:\s*\d+)?|call\s*and\s*response|drop(?:\s*\d+)?|final\s*drop)\s*\]$',
  caseSensitive: false,
);

/// Preserves clean structural stanza headers (`[Verse 1]`, `[Chorus]`) for
/// multi-line teleprompters while stripping metadata lines (`Title:`, `BPM:`),
/// instrumental cue brackets (`[Crisp soft shakers]`), and stage cues (`(x2)`).
static String cleanLyricsForTeleprompter(String rawLyrics) {
  if (rawLyrics.trim().isEmpty) return '';
  final out = <String>[];
  for (final rawLine in rawLyrics.replaceAll('\r\n', '\n').split('\n')) {
    final trimmed = rawLine.trim();
    if (trimmed.isEmpty) {
      if (out.isNotEmpty && out.last.isNotEmpty) out.add('');
      continue;
    }
    if (_metadataHeaderLine.hasMatch(trimmed)) continue;
    if (_structuralHeaderOnly.hasMatch(trimmed)) {
      out.add(trimmed);
      continue;
    }
    final cleaned = cleanLyricTextForKaraoke(trimmed);
    if (cleaned.isNotEmpty) out.add(cleaned);
  }
  return out.join('\n').trim();
}
```
Wire into `lyrics_teleprompter.dart#L25`:
`final lyrics = LyricKaraokeSanitizer.cleanLyricsForTeleprompter(widget.track.lyrics);`

### 4.3 `STD-UIUX-001` Icon/Emoji Purge & Glass Parity (`M75.4`)
- **Mastering (`desktop_mastering_studio_view.dart`, `mobile_quick_master_sheet.dart`):**
  - Replace all `12` stock `Icons.*` with `PhosphorIcon(AppIcons.*)` / `PhosphorIconsRegular.info` / `PhosphorIconsFill.lightning`.
  - Replace all `8` stem header emojis (`'🎙️'`, `'🪵'`, `'🥁'`, `'🎹'`) with leading `PhosphorIcon` badges (`AppIcons.vocals`, `AppIcons.waveform`, `AppIcons.drums`, `AppIcons.piano`) + clean plain text titles (`'Vocals Cleanse'`, `'Log Drum & Sub'`, `'Drum Bus Snap'`, `'Melodic & Keys'`).
  - Wrap `DesktopMasteringStudioView` strips and `MobileQuickMasterSheet` cards in `VhunambiGlassSurface(enableLiveBlur: false)` using `AppColors.*Of(context)`.
- **Studio Widgets & Models:**
  - Replace stock `Icons.*` across `generation_pipeline_card.dart`, `lyrics_review_modal.dart`, `bantu_voice_deck.dart`, `vocal_identity_picker_sheet.dart`, `voice_clone_recorder_sheet.dart`, `crate_browser_deck.dart`, `mpc_slicer_deck.dart`, `guided_lyrics_composer.dart`, `prompt_input_box.dart`, `prompt_intelligence_overlay.dart`, `reference_audio_dropzone.dart`, `regional_genre_selector.dart`, `multilingual_language_selector.dart`, `option_preview_chip.dart`, `studio_session_recovery_banner.dart`, and `live_phonetic_alignment_preview.dart` with `PhosphorIcon` tokens.
  - Purge raw Unicode emojis from `lyrics_section_scaffold.dart`, `melody_sketchpad_models.dart`, `heritage_crate_models.dart`, `regional_genre_selector.dart`, `option_preview_descriptor.dart`, `mpc_slicer_deck.dart`, `song_dna_node_tree_modal.dart`, `bantu_language_switcher.dart`, `prompt_input_box.dart`, `direct_daw_vocal_upload_sheet.dart`, `bantu_voice_profile.dart`, `studio_form_state.dart`, and `fake_generation_socket_service.dart`, replacing rendered icon glyphs with semantic `IconData` (`PhosphorIcon`) tokens.
  - Replace unsafe direct `as Map<String, dynamic>` / `as List<dynamic>` casts in `sound_signature_dna.dart` and `phonetic_articulation_profile.dart` with `JsonSafe.asMap` / `JsonSafe.asList`.
  - Update `generation_pipeline_card_test.dart#L130,143,236` (`Icons.check` $\to$ `AppIcons.check`).

---

## 5. Verification Strategy & Automated Test Architecture

### 5.1 Backend Suite (`apps/vhunambi_api/test/phase75_studio_connectome_closure.test.ts`)
1. `syncVoicesFromCloud` (12s SWR): writes a voice clone & sound signature on Isolate A, reads & patches recipe on fresh Isolate B (same mock `SupabaseCloudDriver`), verifies `200`, client `id` preservation, and `12_000 ms` TTL cache hit (no redundant second Supabase select within TTL).
2. `POST /v1/generations/:id/master` cross-isolate SWR: inserts generation job into mock Supabase, calls `POST /v1/generations/:id/master` on cold Isolate B, verifies `200` (not `404`), enriched `manifest`, and awaited Supabase write-through.
3. `hasScopedReadThrough`: verifies `/v1/voices/catalog`, `/v1/melodies/presets`, `/v1/melodies/sound-packs`, and `/v1/lyrics/story-transform` do not trigger 21-table cold-start hydration.

### 5.2 Client Suite (`apps/vhunambi_client/test/features/phase75_studio_connectome_closure_test.dart`)
1. `EP-P66`: `HttpLyricsGenerationService.refineLyrics` & `transformStoryToLyrics` (verifying `structuredLyrics` parsing + `'Tshivenḓa'` $\to$ `'ve'` ISO normalization) + `LyricsReviewModal` Story input & Stanza Polish trigger.
2. `EP-P27`: `MelodySketchpadNotifier.syncStarterPresetsFromCloud` & `SoundPackManagerNotifier.syncSoundPacksFromCloud` + Dio byte download progress.
3. `EP-P26`: `VocalIdentityNotifier.prepareCalibrationFromLyricsAsync` (`POST /v1/voices/extract-calibration`) + `SoundSignatureRepository.updateRecipeInCloud` (`PATCH /v1/voices/signatures/:id/recipe`) triggered from `SoundSignatureIdealizerSheet` save.
4. `EP-P25`: `MasteringSessionNotifier.syncMasteringPresetsFromCloud`, honest failure on HTTP `500` (zero `/mock-storage/` poisoning), and `TrackDetailNotifier.separateStems` hydrating real R2 URLs from `GET /v1/generations/:id/manifest`.
5. Direct Creation-to-Reels Bridge (`GenerationPipelineCard` -> `KineticReelStudioView`) + `LyricKaraokeSanitizer.cleanLyricsForTeleprompter` preserving `[Chorus]` while stripping `[Crisp soft shakers]` & `Title:`.
