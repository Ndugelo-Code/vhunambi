# Phase 26 Design: African Vocal Identity Catalog & Post-Lyrics Zero-Shot Voice Cloning

> **Phase:** 26 (`phase_26_vocal_identity_cloning`)  
> **Status:** `✅ COMPLETE`

---

## 1. Domain Contracts & Schemas

### 1.1 Backend Zod Schemas (`apps/vhunambi_api/src/modules/voices/voice_types.ts`)
- `VocalGenderSchema`: `z.enum(['male', 'female', 'duet', 'choir'])`
- `AfricanVoiceRegionSchema`: `z.enum(['southern_africa', 'west_africa', 'east_africa', 'central_africa', 'diaspora'])`
- `VocalDeliveryStyleSchema`: `z.enum(['melodic_soul', 'amapiano_chant', 'gqom_mc', 'maskandi_storyteller', 'afrobeats_smooth', 'choir_harmony'])`
- `RegionalVoiceArchetypeSchema`: Full metadata for each of the 24+ sovereign vocal archetypes, including `recommendedCleanseFlavor` (`'studio_clean' | 'warm_intimate' | 'wide_anthem'`).
- `PhoneticCalibrationLineSchema` & `PhoneticCalibrationScriptSchema`: Extracted 3-line calibration script with `phoneticScore`, `highlightedTokens`, and `estimatedDurationSec`.
- `CreatorVoiceCloneProfileSchema`: Cloned voice profile containing `id`, `creatorName`, `nativeLanguage`, `timbreEmbeddingPreview` (8 summary floats representing the 256-D speaker vector), `cadenceWpm`, `clarityScore`, `r2ReferenceUrl`, and `recommendedCleanseFlavor`.

### 1.2 Client Immutable Domain Models (`lib/features/studio/domain/models/vocal_identity_models.dart`)
- `VocalGender`, `AfricanVoiceRegion`, `VocalDeliveryStyle` enums with `.wireValue`, `.label`, and `.fromWire(...)`.
- `@immutable class RegionalVoiceArchetype` + `kRegionalVoiceCatalog` (24 curated African vocal archetypes).
- `@immutable class PhoneticCalibrationLine` & `@immutable class PhoneticCalibrationScript`.
- `@immutable class CreatorVoiceCloneProfile` with `toJson()` and `fromJson()`.

---

## 2. Services & State Management

### 2.1 `PhoneticCalibrationExtractor` (`lib/features/studio/domain/services/phonetic_calibration_extractor.dart`)
- Pure, deterministic service computing $S_{\text{line}}$ for every lyric line in a draft or raw string.
- Extracts diacritics (`ḓ`, `ṱ`, `ṋ`, `ḽ`, `ṅ`), clusters (`tsh`, `dz`, `pf`, `bv`, `hl`, `dl`, `kh`, `ph`, `th`, `ng`, `nk`, `ny`), and cultural idioms.
- Guarantees exactly 3 calibration lines by supplementing with native dialect pangrams when input lyrics have fewer than 3 lines.

### 2.2 `IVoiceCalibrationRecorder` (`lib/features/studio/domain/services/i_voice_calibration_recorder.dart`)
- Interface methods: `startRecording()`, `stopRecording()`, `cancelRecording()`, `amplitudeStream`, `isRecording`, `dispose()`.
- `DeterministicVoiceCalibrationRecorder`: Uses a clean periodic stream only while actively recording (or deterministic step ticks) and immediately cancels on `stopRecording()` / `dispose()` so widget tests never suffer from pending timer leaks.

### 2.3 `VocalIdentityNotifier` (`lib/features/studio/presentation/providers/vocal_identity_provider.dart`)
- Manages:
  - `catalog`: List of 24+ `RegionalVoiceArchetype` items.
  - `selectedRegionFilter`, `selectedGenderFilter`, `searchQuery`.
  - `selectedArchetype`: Currently active catalog voice.
  - `clonedProfiles`: List of user's saved `CreatorVoiceCloneProfile` items persisted in Hive (`AppConstants.voiceProfilesBoxKey`) with in-memory fallback.
  - `activeClonedProfile`: Non-null when the user's own cloned voice is active for synthesis.
  - `isRecording`, `recordedDurationSec`, `currentAmplitude`, `isSynthesizingClone`.
- Couples with `masteringSessionProvider` (Phase 25): Selecting a voice archetype or cloned profile automatically applies its `recommendedCleanseFlavor` to `masteringSessionProvider.notifier.setVocalFlavor(...)`.

---

## 3. Widget Decomposition & Mandatory Automation Keys

| Widget File | Class Name | Mandatory Automation Keys |
| :--- | :--- | :--- |
| `lib/features/studio/presentation/widgets/voice_clone_recorder_sheet.dart` | `VoiceCloneRecorderSheet` | `Key('voice_clone_recorder_sheet')`, `Key('calibration_line_0')`, `Key('calibration_line_1')`, `Key('calibration_line_2')`, `Key('voice_clone_name_input')`, `Key('voice_clone_record_toggle_btn')`, `Key('voice_clone_finalize_btn')`, `Key('voice_clone_ready_badge')` |
| `lib/features/studio/presentation/widgets/vocal_identity_picker_sheet.dart` | `VocalIdentityPickerSheet` | `Key('vocal_identity_picker_sheet')`, `Key('vocal_catalog_search_input')`, `Key('vocal_region_filter_${region.name}')`, `Key('vocal_gender_filter_${gender.name}')`, `Key('vocal_archetype_card_${arch.id}')`, `Key('vocal_tab_catalog')`, `Key('vocal_tab_cloned')` |
| `lib/features/studio/presentation/widgets/lyrics_review_modal.dart` | `LyricsReviewModal` | `Key('lyrics_review_clone_voice_btn')`, `Key('lyrics_review_pick_voice_btn')` |
| `lib/features/studio/presentation/widgets/bantu_voice_deck.dart` | `BantuVoiceDeck` | `Key('open_vocal_identity_catalog_btn')`, `Key('open_voice_clone_recorder_btn')` |

