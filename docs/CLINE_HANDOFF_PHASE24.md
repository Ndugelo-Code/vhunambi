# 🚀 CLINE & ANTIGRAVITY HANDOFF: PHASE 24A — MULTI-STEM AUDIO ENGINE (24B BLOCKED)

> **Revision 2** — rewritten after the adversarial review. **Cline executes 24A only.** 24B (frame renderer / MP4) is **blocked on Gate G1 (encoder strategy)** and MUST NOT be started.  
> **Standard:** [`docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md)  
> **Specs:** [`docs/phases/phase_24_multi_stem_and_frame_renderer/`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_24_multi_stem_and_frame_renderer/) — `blueprint.md`, `requirements.md`, `design.md` (read **§0 Reality Constraints** first), `tasks.md`.

---

## 1. Guardrails & Invariants

1. **Brand:** `vhunambi` (with an **i**).
2. **Real tokens only** (verify in `lib/core/theme/app_colors.dart` / `app_dimensions.dart`): `AppColors.surfaceCanvas`, `surfaceElevated`, `borderSubtle`, `brandPrimary`, `accentGold`, `success`, `error`; `AppSpacing`, `AppRadius`, `AppTypography`. **These do not exist — do not use:** `surfaceCard`, `surfaceGlass`, `AppSpacing.touchTarget`, `AppGradients.primarySunset`. Zero raw hex.
3. **Naming:** `AudioRepeatMode`, never `RepeatMode`.
4. **Stems:** reuse `StemType` from `features/player/domain/models/stem_mixer_state.dart`; consume `mmo.stemUrls` (already on `MasterMediaObject`).
5. **Touch targets:** ≥ 44×44 dp.
6. **Honesty (dual-provenance):** production has **no real stems**. Master-only mode is the normal path. **Never** fake stems with EQ. The bounce is **simulated** (`isSimulated: true`) and MUST be labelled "Preview bounce".
7. **No filesystem pollution:** never hardcode `/vault/...`. Use `path_provider` in app code and `Directory.systemTemp` in tests. A previous run wrote `C:\vault\...`; do not repeat it. Services **throw** on failure — never swallow errors or return a phantom path.
8. **Test safety:** override `multiStemAudioEngineProvider` with `HeadlessMultiStemEngine` in tests; no unmanaged timers.
9. **Provider graph:** engine → mixer one-way. `StemMixerNotifier` holds no engine. Production default is `JustAudioMultiStemEngine`, **not** the headless engine.
10. **No live pan** (`just_audio` has none). Sync target is **≤ 40 ms measured**, with auto-resync.

---

## 2. Already Done (do not redo)

- `IMultiStemAudioEngine`, `HeadlessMultiStemEngine` (+5 tests)
- `StemMixBounceService` (pure; injected `WavFileWriter`; `BounceResult`), `wav_file_writer_io.dart` (+4 tests, temp-dir based)

## 3. Cline's Tasks (24A, in order — see `tasks.md`)

1. **T1b** — extend `IMultiStemAudioEngine`: `hasRealStems`, `measuredDrift`, `loadFromManifest(...)`; remove `loadStems`; update the headless engine + tests.
2. **T5** — `JustAudioMultiStemEngine` (4 `AudioPlayer`s, master-only fallback, drift measurement + resync > 40 ms, `audio_session` interruption pause-all).
3. **T6** — `multi_stem_audio_provider.dart` (new) and `stem_mixer_provider.dart` (guarded, `path_provider`-based `bounceMasterMix` returning `BounceResult`, `isBouncing` re-entry guard). Update `stem_mixer_provider_test.dart` / `stem_mixer_deck_test.dart` for the new return type.
4. **T6b** — pause the master `VhunambiAudioHandler` while the stem deck is active; restore on exit.
5. **T9** — `stem_mixer_deck.dart`: `Key('stem_mixer_play_pause_btn')`, measured-drift badge, `Key('stem_master_only_banner')` with per-stem controls disabled, "Preview bounce" label, `Semantics` on every control.
6. **T14** — widget tests (banner disables controls; play/pause; bounce error path).

## 4. Verification (run before declaring done)

```powershell
cd apps/vhunambi_client
dart analyze .                       # must be: No issues found!
flutter test                         # must be 100% green
Test-Path C:\vault                   # must be False (no files outside repo/temp)
```

## 5. Out of Scope — BLOCKED

T0.x (canvas export mode), T7, T8, T10 (frame renderer, encoder, export modal) wait for **Gate G1**. Do not add encoder dependencies or touch `video_export_modal.dart` until the encoder strategy is decided.
