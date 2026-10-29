# Phase 23 · Requirements Specification — The Executable Master Media Object (MMO v2.0)

> **Phase:** 23  
> **Codename:** `master-media-object-v2`  
> **Target Apps:** `apps/vhunambi_api`, `apps/vhunambi_client`  
> **Standard:** RFC 2119 & EARS (Easy Approach to Requirements Syntax)  
> **Parent Blueprint:** [`docs/phases/phase_23_master_media_object/blueprint.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_23_master_media_object/blueprint.md)  

---

## 1. Canonical Schema & Dual-Provenance Requirements

* **REQ-MMO-01 (Canonical Schema Superset):**
  The backend (`apps/vhunambi_api/src/modules/dna/dna_types.ts`) and client (`apps/vhunambi_client`) SHALL define `MasterMediaObjectManifest` (`schemaVersion: '2.0'`) as an immutable backward-compatible superset of `SongMetadataDNA`.

* **REQ-MMO-02 (Provenance Declaration):**
  Every `MasterMediaObjectManifest` SHALL include a top-level `provenance` field with values `'measured'` or `'synthesized'`:
  - When compiled without rendered audio PCM, `provenance` SHALL be `'synthesized'`.
  - When produced via GPU worker audio analysis (Demucs + Librosa), `provenance` SHALL be `'measured'`.

* **REQ-MMO-03 (Quantized Base64 Stem Modulation Curves):**
  The manifest SHALL store 5 discrete amplitude modulation curves (`masterRms`, `vocals`, `drums`, `bass`, `melodic`):
  - Curves SHALL be normalized to integers in the range `0..255` (`Uint8`).
  - Curves SHALL be serialized as Base64-encoded strings (`encodedCurvesBase64`).
  - At 60 Hz across a 180-second track, each encoded curve string SHALL NOT exceed 15 KB of payload data.

* **REQ-MMO-04 (Discrete Transient Event Telemetry):**
  The manifest SHALL include `modulationBus.transientEvents` containing timestamped events (`timestampMs`):
  - Event types SHALL include: `'kick'`, `'log_drum_drop'`, `'snare_clap'`, `'vocal_onset'`, `'harmonic_turnaround'`, `'section_change'`.
  - Each event SHALL be tagged with its originating `StemRole` and normalized `intensity` (`0.0..1.0`).
  - Events SHALL be sorted chronologically by `timestampMs` to enable binary search lookups.

* **REQ-MMO-05 (Role-Stratified 8-Pad MPC Kit Manifest):**
  The manifest SHALL provide an explicit 8-element `mpcKitPads` array (`padIndex: 0..7`):
  - Pads 0–1 SHALL represent the `drums` stem (Kick & Snare/Clap).
  - Pads 2–3 SHALL represent the `bass` stem (Log Drum Attack & Sub-Bass Glide).
  - Pads 4–5 SHALL represent the `melodic` stem (Guitar Turnaround & Chord Stab).
  - Pads 6–7 SHALL represent the `vocals` stem (Chant Hook & Cultural Idiom).
  - Each pad entry SHALL define `startSec`, `endSec`, `peakIntensity`, and `recommendedSemitoneShift`.

* **REQ-MMO-06 (Bantu Phonetic Stress & Cultural Ad-Libs):**
  The manifest's `LyricWordTimestamp` entries SHALL support optional `phoneticStress` (`double`, `0.0..1.0`, default `0.5`) and `isCulturalIdiom` (`bool`, default `false`) to trigger specialized kinetic typography rendering.

---

## 2. Backend API & Webhook Requirements

* **REQ-MMO-07 (Manifest REST Endpoint):**
  The backend gateway SHALL expose `GET /v1/generations/:id/manifest`:
  - If the generation exists in `job_store.ts`, it SHALL return status `200` with the `MasterMediaObjectManifest`.
  - If the job is completed with mock/fallback assets, it SHALL synthesize a valid manifest with `provenance: 'synthesized'`.
  - If the generation ID is unknown, it SHALL return status `404` with `{ error: 'NOT_FOUND' }`.

* **REQ-MMO-08 (Measured Webhook Ingestion Contract):**
  `apps/vhunambi_api/src/routes/webhook_routes.ts` SHALL accept optional `manifest_url` in the HMAC-SHA256 authenticated `POST /v1/webhooks/ace-step` callback payload, attaching it to the completed job record.

---

## 3. Client Domain & Hive Persistence Requirements

* **REQ-MMO-09 (O(1) Client Telemetry Hydration):**
  Upon receiving or synthesizing a `MasterMediaObjectManifest`, the Flutter client SHALL decode the Base64 stem curves once into `Uint8List` byte buffers inside `ModulationTelemetryBus`, providing $O(1)$ zero-allocation index lookups by playback position in milliseconds.

* **REQ-MMO-10 (Hive Offline Cache & Test Safety):**
  The client SHALL persist hydrated `MasterMediaObject` records in Hive under `AppConstants.mmoBoxKey`:
  - When Hive is uninitialized (in unit/widget tests), the repository SHALL degrade gracefully to in-memory caching without throwing `HiveError`.
  - If a track lacks a remote manifest, the client SHALL deterministically synthesize a valid `MasterMediaObject` from `SongMetadataDna` via `MasterMediaObject.fromSongMetadataDna(dna)`.

---

## 4. UI Coupling & Presentation Requirements

* **REQ-MMO-11 (Live Pocket DAW $\leftrightarrow$ Video Coupling):**
  When rendering frames in `KineticPreviewCanvas`, the client SHALL dynamically weight the active stem curves (`vocals`, `drums`, `bass`, `melodic`) by the corresponding channel volume and solo/mute state from `stemMixerProvider` (`StemMixerState`).

* **REQ-MMO-12 (Log-Drum Exponential Snap-Zoom):**
  When playback position is within `180ms` of a `log_drum_drop` transient event (and the `bass` stem is not muted in `StemMixerState`), `KineticPreviewCanvas` SHALL apply an exponential camera zoom impulse ($e^{-4.5 \times t_{\text{progress}}}$) scaled by event intensity.

* **REQ-MMO-13 (Bantu Vocal Bloom & Idiom Highlight):**
  `KineticPreviewCanvas` typography renderer SHALL scale word glow radius proportionally to `vocals` stem amplitude multiplied by `phoneticStress`, rendering words marked `isCulturalIdiom == true` in `AppColors.brandPrimary` (`#F97316`).

* **REQ-MMO-14 (Zero Regression & Verification Standards):**
  All modifications MUST maintain:
  - `dart analyze apps/vhunambi_client` = `0 issues found!`.
  - `flutter test` = $\ge 1030$ tests passing (100% green).
  - `pnpm test` in `apps/vhunambi_api` = 100% pass across all test suites.
  - Zero hardcoded hex colors or raw border radii.
