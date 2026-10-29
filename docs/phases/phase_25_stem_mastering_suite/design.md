# Phase 25 Design: Stem Polisher, Adobe-Style Vocal Cleanse & Mobile/Desktop Mastering Suite

> **Phase:** 25 (`phase_25_stem_mastering_suite`)  
> **Status:** `✅ COMPLETE`

---

## 1. Domain Models & Immutable Entities

### 1.1 Backend TypeScript & Zod Schema (`apps/vhunambi_api/src/modules/mastering/mastering_types.ts`)

```typescript
import { z } from 'zod';

export const VocalCleanseFlavorSchema = z.enum([
  'off',
  'studio_clean',
  'warm_intimate',
  'wide_anthem',
]);
export type VocalCleanseFlavor = z.infer<typeof VocalCleanseFlavorSchema>;

export const BassCharacterFlavorSchema = z.enum([
  'natural',
  'heavy_wooden_knock',
  'deep_sub_808',
  'smooth_glide',
]);
export type BassCharacterFlavor = z.infer<typeof BassCharacterFlavorSchema>;

export const DrumCharacterFlavorSchema = z.enum([
  'natural',
  'crisp_shakers',
  'club_punch',
  'vintage_warm',
]);
export type DrumCharacterFlavor = z.infer<typeof DrumCharacterFlavorSchema>;

export const MelodicCharacterFlavorSchema = z.enum([
  'natural',
  'wide_stereo_pocket',
  'warm_rhodes',
  'bright_acoustic',
]);
export type MelodicCharacterFlavor = z.infer<typeof MelodicCharacterFlavorSchema>;

export const StemEqBandsSchema = z.object({
  highpassHz: z.number().min(20).max(250),
  lowGainDb: z.number().min(-12).max(12),
  midGainDb: z.number().min(-12).max(12),
  midFreqHz: z.number().min(250).max(5000),
  airGainDb: z.number().min(-12).max(12),
});
export type StemEqBands = z.infer<typeof StemEqBandsSchema>;

export const StemMasteringRecipeSchema = z.object({
  presetId: z.string().default('amapiano_club_knock'),
  targetLufs: z.union([z.literal(-9.5), z.literal(-14.0)]).default(-9.5),
  vocals: z.object({
    flavor: VocalCleanseFlavorSchema,
    neuralDenoiseStrength: z.number().min(0).max(1),
    neuralDereverbStrength: z.number().min(0).max(1),
    compressionAmount: z.number().min(0).max(1),
    eq: StemEqBandsSchema,
  }),
  bass: z.object({
    flavor: BassCharacterFlavorSchema,
    subHarmonicMix: z.number().min(0).max(1),
    knockDriveDb: z.number().min(0).max(9),
    sidechainDuckDb: z.number().min(-6).max(0),
    eq: StemEqBandsSchema,
  }),
  drums: z.object({
    flavor: DrumCharacterFlavorSchema,
    transientAttackSnap: z.number().min(-1).max(1),
    parallelCrushMix: z.number().min(0).max(1),
    eq: StemEqBandsSchema,
  }),
  melodic: z.object({
    flavor: MelodicCharacterFlavorSchema,
    midVocalPocketCutDb: z.number().min(-6).max(0),
    stereoWidthBoost: z.number().min(0).max(1),
    eq: StemEqBandsSchema,
  }),
});
export type StemMasteringRecipe = z.infer<typeof StemMasteringRecipeSchema>;
```

### 1.2 Client Dart Domain Model (`lib/features/mastering/domain/models/stem_mastering_recipe.dart`)

- `VocalCleanseFlavor` (`off`, `studioClean`, `warmIntimate`, `wideAnthem`) with `.wireValue` & `.fromWire(...)`
- `BassCharacterFlavor` (`natural`, `heavyWoodenKnock`, `deepSub808`, `smoothGlide`)
- `DrumCharacterFlavor` (`natural`, `crispShakers`, `clubPunch`, `vintageWarm`)
- `MelodicCharacterFlavor` (`natural`, `wideStereoPocket`, `warmRhodes`, `brightAcoustic`)
- `@immutable class StemEqBands`
- `@immutable class VocalsMasteringConfig`, `BassMasteringConfig`, `DrumsMasteringConfig`, `MelodicMasteringConfig`
- `@immutable class StemMasteringRecipe` with `toJson()`, `fromJson()`, `copyWith()`, and preview multiplier getters (`vocalGainMultiplier`, `bassGainMultiplier`, `drumsGainMultiplier`, `melodicGainMultiplier`, `estimatedIntegratedLufs`, `estimatedTruePeakDbtp`).
- `kGenreMasterPresets` (6 regional studio presets) + `StemMasteringRecipe.forGenre(String genre)`.

---

## 2. State Management & Riverpod Coupling (`lib/features/mastering/presentation/providers/mastering_session_provider.dart`)

### 2.1 `MasteringSessionState` & `MasteringSessionNotifier`

```dart
@immutable
class MasteringSessionState {
  final String trackId;
  final String trackTitle;
  final String genre;
  final StemMasteringRecipe recipe;
  final bool isMasteredPreviewActive; // Tier A A/B Toggle
  final bool isBaking;                // Tier B Cloud Bake in progress
  final bool hasBakedMaster;
  final String? masteredMp3Url;
  final String? masteredWavUrl;
  final String? errorMessage;
}
```

### 2.2 Bidirectional Synergy with `stemMixerProvider` & `frameModulationSnapshotProvider`

1. When `MasteringSessionNotifier` updates `recipe` or toggles `isMasteredPreviewActive`:
   - If `isMasteredPreviewActive == true`:
     - Updates `stemMixerProvider.notifier` channel gains (`vocals`, `drums`, `bass`, `melody`) using the recipe's computed gain multipliers.
     - Updates `stemMixerProvider.notifier.updateMasterDsp(...)` with mapped `MasterBusDsp` values (`logDrumSaturation`, `vocalPlateReverb`, `sidechainCompression`, `stereoWidth`) so even when `IMultiStemAudioEngine.hasRealStems == false` (Master-Only mode), the user gets immediate macro DSP feedback.
   - If `isMasteredPreviewActive == false` (Raw AI Bypass):
     - Restores unity channel gains (`1.0`) and default `MasterBusDsp` on `stemMixerProvider`.
2. In `frameModulationSnapshotProvider` (`master_media_object_provider.dart`):
   - Watches `masteringSessionProvider` and scales `effectiveBassEnergy`, `effectiveDrumsEnergy`, `effectiveMelodicEnergy`, `effectiveVocalGlow`, and `logDrumSnapZoom` when `isMasteredPreviewActive == true`.

---

## 3. Widget Decomposition & Mandatory Keys

| Widget File | Class Name | Mandatory Automation Keys |
| :--- | :--- | :--- |
| `lib/features/mastering/presentation/widgets/mobile_quick_master_sheet.dart` | `MobileQuickMasterSheet` | `Key('mobile_quick_master_sheet')`, `Key('mastering_master_only_notice')`, `Key('mastering_ab_toggle')`, `Key('mastering_preset_${preset.id}')`, `Key('vocal_flavor_${flavor.name}')`, `Key('bass_flavor_${flavor.name}')`, `Key('drum_flavor_${flavor.name}')`, `Key('melodic_flavor_${flavor.name}')`, `Key('mastering_lufs_club')`, `Key('mastering_lufs_stream')`, `Key('mastering_bake_btn')` |
| `lib/features/mastering/presentation/views/desktop_mastering_studio_view.dart` | `DesktopMasteringStudioView` | `Key('desktop_mastering_studio_view')`, `Key('mastering_master_only_notice')`, `Key('desktop_mastering_ab_toggle')`, `Key('desktop_lufs_toggle')`, `Key('desktop_mastering_bake_btn')`, `Key('eq_curve_vocals')`, `Key('eq_curve_bass')`, `Key('eq_curve_drums')`, `Key('eq_curve_melodic')`, `Key('slider_vocal_denoise')`, `Key('slider_bass_sub_harmonic')`, `Key('slider_bass_knock_drive')`, `Key('slider_bass_sidechain_duck')` |
| `lib/features/player/presentation/widgets/stem_mixer_deck.dart` | `StemMixerDeck` | `Key('stem_mixer_open_mastering_btn')` |
| `lib/features/track/presentation/views/track_detail_view.dart` | `TrackDetailView` | `Key('track_detail_open_mastering_btn')` |

