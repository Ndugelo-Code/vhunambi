import { MasterMediaObjectManifest } from '../dna/dna_types.js';
import {
  GenreMasterPresetDescriptor,
  StemMasteringRecipe,
} from './mastering_types.js';

/**
 * mastering_presets.ts — 6 Regional African Studio Mastering Presets & MMO Curve Enricher
 */

export const GENRE_MASTER_PRESETS: GenreMasterPresetDescriptor[] = [
  {
    id: 'amapiano_club_knock',
    name: 'Amapiano Club Knock',
    genre: 'Amapiano',
    description: 'Chest-rattling 45Hz sub-octave log drum, -3.5dB kick sidechain, and crisp shaker sheen.',
    recipe: {
      presetId: 'amapiano_club_knock',
      targetLufs: -9.5,
      vocals: {
        flavor: 'studio_clean',
        neuralDenoiseStrength: 0.85,
        neuralDereverbStrength: 0.65,
        compressionAmount: 0.65,
        eq: { highpassHz: 95, lowGainDb: 0.5, midGainDb: 1.5, midFreqHz: 2400, airGainDb: 3.5 },
      },
      bass: {
        flavor: 'heavy_wooden_knock',
        subHarmonicMix: 0.55,
        knockDriveDb: 4.5,
        sidechainDuckDb: -3.5,
        eq: { highpassHz: 30, lowGainDb: 3.5, midGainDb: 3.0, midFreqHz: 165, airGainDb: 1.0 },
      },
      drums: {
        flavor: 'crisp_shakers',
        transientAttackSnap: 0.45,
        parallelCrushMix: 0.3,
        eq: { highpassHz: 45, lowGainDb: 1.0, midGainDb: -2.5, midFreqHz: 320, airGainDb: 2.5 },
      },
      melodic: {
        flavor: 'wide_stereo_pocket',
        midVocalPocketCutDb: -2.5,
        stereoWidthBoost: 0.35,
        eq: { highpassHz: 110, lowGainDb: -1.5, midGainDb: -2.0, midFreqHz: 1800, airGainDb: 2.0 },
      },
    },
  },
  {
    id: 'private_school_warmth',
    name: 'Private School Soul',
    genre: 'Private School Amapiano',
    description: 'Lush Kelvin Momo-style Rhodes warmth, smooth sub-bass glide, and intimate vocal air.',
    recipe: {
      presetId: 'private_school_warmth',
      targetLufs: -14.0,
      vocals: {
        flavor: 'warm_intimate',
        neuralDenoiseStrength: 0.8,
        neuralDereverbStrength: 0.5,
        compressionAmount: 0.55,
        eq: { highpassHz: 85, lowGainDb: 1.5, midGainDb: 1.0, midFreqHz: 2000, airGainDb: 2.5 },
      },
      bass: {
        flavor: 'smooth_glide',
        subHarmonicMix: 0.45,
        knockDriveDb: 2.5,
        sidechainDuckDb: -2.5,
        eq: { highpassHz: 28, lowGainDb: 2.5, midGainDb: 1.5, midFreqHz: 150, airGainDb: 0.0 },
      },
      drums: {
        flavor: 'vintage_warm',
        transientAttackSnap: 0.25,
        parallelCrushMix: 0.2,
        eq: { highpassHz: 40, lowGainDb: 1.5, midGainDb: -1.5, midFreqHz: 350, airGainDb: 1.5 },
      },
      melodic: {
        flavor: 'warm_rhodes',
        midVocalPocketCutDb: -2.0,
        stereoWidthBoost: 0.45,
        eq: { highpassHz: 95, lowGainDb: 1.5, midGainDb: 1.0, midFreqHz: 1200, airGainDb: 2.0 },
      },
    },
  },
  {
    id: 'gqom_warehouse_sub',
    name: 'Gqom Warehouse Sub',
    genre: 'Gqom',
    description: 'Relentless Durban warehouse sub-808 pressure, aggressive club punch, and dark atmosphere.',
    recipe: {
      presetId: 'gqom_warehouse_sub',
      targetLufs: -9.5,
      vocals: {
        flavor: 'wide_anthem',
        neuralDenoiseStrength: 0.75,
        neuralDereverbStrength: 0.4,
        compressionAmount: 0.75,
        eq: { highpassHz: 105, lowGainDb: 0.0, midGainDb: 2.0, midFreqHz: 2600, airGainDb: 3.0 },
      },
      bass: {
        flavor: 'deep_sub_808',
        subHarmonicMix: 0.7,
        knockDriveDb: 5.5,
        sidechainDuckDb: -4.5,
        eq: { highpassHz: 25, lowGainDb: 4.5, midGainDb: 2.0, midFreqHz: 140, airGainDb: 0.5 },
      },
      drums: {
        flavor: 'club_punch',
        transientAttackSnap: 0.65,
        parallelCrushMix: 0.45,
        eq: { highpassHz: 38, lowGainDb: 2.5, midGainDb: -3.0, midFreqHz: 300, airGainDb: 2.0 },
      },
      melodic: {
        flavor: 'wide_stereo_pocket',
        midVocalPocketCutDb: -3.0,
        stereoWidthBoost: 0.4,
        eq: { highpassHz: 120, lowGainDb: -2.0, midGainDb: -1.5, midFreqHz: 1800, airGainDb: 1.5 },
      },
    },
  },
  {
    id: 'maskandi_acoustic_clarity',
    name: 'Maskandi Acoustic Clarity',
    genre: 'Maskandi',
    description: 'Crystal-clear ukuvamba acoustic guitar picking, natural vocal front-presence, and tight bass.',
    recipe: {
      presetId: 'maskandi_acoustic_clarity',
      targetLufs: -14.0,
      vocals: {
        flavor: 'studio_clean',
        neuralDenoiseStrength: 0.9,
        neuralDereverbStrength: 0.75,
        compressionAmount: 0.6,
        eq: { highpassHz: 90, lowGainDb: 0.5, midGainDb: 2.0, midFreqHz: 2200, airGainDb: 4.0 },
      },
      bass: {
        flavor: 'natural',
        subHarmonicMix: 0.25,
        knockDriveDb: 2.0,
        sidechainDuckDb: -2.0,
        eq: { highpassHz: 35, lowGainDb: 2.0, midGainDb: 2.5, midFreqHz: 180, airGainDb: 1.0 },
      },
      drums: {
        flavor: 'crisp_shakers',
        transientAttackSnap: 0.35,
        parallelCrushMix: 0.2,
        eq: { highpassHz: 45, lowGainDb: 1.0, midGainDb: -2.0, midFreqHz: 320, airGainDb: 2.5 },
      },
      melodic: {
        flavor: 'bright_acoustic',
        midVocalPocketCutDb: -2.0,
        stereoWidthBoost: 0.3,
        eq: { highpassHz: 100, lowGainDb: 0.0, midGainDb: 2.5, midFreqHz: 2800, airGainDb: 3.5 },
      },
    },
  },
  {
    id: 'afro_house_horizon',
    name: 'Afro House Horizon',
    genre: 'Afro House',
    description: 'Panoramic festival stereo width, driving four-on-the-floor kick punch, and soaring vocals.',
    recipe: {
      presetId: 'afro_house_horizon',
      targetLufs: -9.5,
      vocals: {
        flavor: 'wide_anthem',
        neuralDenoiseStrength: 0.85,
        neuralDereverbStrength: 0.55,
        compressionAmount: 0.65,
        eq: { highpassHz: 95, lowGainDb: 0.0, midGainDb: 1.5, midFreqHz: 2500, airGainDb: 4.0 },
      },
      bass: {
        flavor: 'deep_sub_808',
        subHarmonicMix: 0.5,
        knockDriveDb: 3.5,
        sidechainDuckDb: -4.0,
        eq: { highpassHz: 28, lowGainDb: 3.5, midGainDb: 1.5, midFreqHz: 150, airGainDb: 0.5 },
      },
      drums: {
        flavor: 'club_punch',
        transientAttackSnap: 0.5,
        parallelCrushMix: 0.35,
        eq: { highpassHz: 40, lowGainDb: 2.0, midGainDb: -2.5, midFreqHz: 310, airGainDb: 3.0 },
      },
      melodic: {
        flavor: 'wide_stereo_pocket',
        midVocalPocketCutDb: -2.5,
        stereoWidthBoost: 0.5,
        eq: { highpassHz: 115, lowGainDb: -1.0, midGainDb: -2.0, midFreqHz: 1800, airGainDb: 2.5 },
      },
    },
  },
  {
    id: 'kwaito_golden_tape',
    name: 'Kwaito Golden Tape',
    genre: 'Kwaito',
    description: '90s Soweto analog tape saturation, heavy slowed-down bass groove, and punchy vocal cadence.',
    recipe: {
      presetId: 'kwaito_golden_tape',
      targetLufs: -9.5,
      vocals: {
        flavor: 'warm_intimate',
        neuralDenoiseStrength: 0.8,
        neuralDereverbStrength: 0.6,
        compressionAmount: 0.7,
        eq: { highpassHz: 88, lowGainDb: 1.0, midGainDb: 2.0, midFreqHz: 2100, airGainDb: 2.5 },
      },
      bass: {
        flavor: 'heavy_wooden_knock',
        subHarmonicMix: 0.5,
        knockDriveDb: 4.0,
        sidechainDuckDb: -3.0,
        eq: { highpassHz: 30, lowGainDb: 3.5, midGainDb: 2.5, midFreqHz: 160, airGainDb: 0.5 },
      },
      drums: {
        flavor: 'vintage_warm',
        transientAttackSnap: 0.4,
        parallelCrushMix: 0.35,
        eq: { highpassHz: 42, lowGainDb: 2.0, midGainDb: -1.5, midFreqHz: 330, airGainDb: 1.5 },
      },
      melodic: {
        flavor: 'warm_rhodes',
        midVocalPocketCutDb: -2.0,
        stereoWidthBoost: 0.25,
        eq: { highpassHz: 100, lowGainDb: 1.0, midGainDb: 0.5, midFreqHz: 1500, airGainDb: 1.5 },
      },
    },
  },
];

/**
 * Resolves the best-matching GenreMasterPresetDescriptor for a given genre string.
 */
export function getMasteringPresetForGenre(genre: string): GenreMasterPresetDescriptor {
  const g = genre.toLowerCase().trim();
  if (g.includes('private')) return GENRE_MASTER_PRESETS[1]!;
  if (g.includes('gqom')) return GENRE_MASTER_PRESETS[2]!;
  if (g.includes('maskandi') || g.includes('mbaqanga')) return GENRE_MASTER_PRESETS[3]!;
  if (g.includes('house')) return GENRE_MASTER_PRESETS[4]!;
  if (g.includes('kwaito') || g.includes('bubblegum') || g.includes('marabi')) {
    return GENRE_MASTER_PRESETS[5]!;
  }
  return GENRE_MASTER_PRESETS[0]!;
}

/**
 * Scales a Base64-encoded Uint8 curve by a gain factor and clamps to [0..255].
 */
function scaleBase64Uint8Curve(base64Curve: string, multiplier: number): string {
  const buf = Buffer.from(base64Curve, 'base64');
  const out = Buffer.alloc(buf.length);
  for (let i = 0; i < buf.length; i++) {
    const scaled = Math.round(buf[i]! * multiplier);
    out[i] = Math.max(0, Math.min(255, scaled));
  }
  return out.toString('base64');
}

/**
 * Applies non-destructive StemMasteringRecipe dynamics to an existing MasterMediaObjectManifest,
 * producing boosted 60Hz Uint8 modulation curves and mastered asset URLs.
 */
export function enrichManifestWithMasteringRecipe(
  manifest: MasterMediaObjectManifest,
  recipe: StemMasteringRecipe,
): MasterMediaObjectManifest {
  const voxBoost =
    1.0 +
    recipe.vocals.neuralDenoiseStrength * 0.12 +
    Math.max(0, recipe.vocals.eq.airGainDb) * 0.025;
  const bassBoost =
    1.0 +
    recipe.bass.subHarmonicMix * 0.25 +
    (recipe.bass.knockDriveDb / 9.0) * 0.2;
  const drumsBoost =
    1.0 +
    Math.max(0, recipe.drums.transientAttackSnap) * 0.18 +
    recipe.drums.parallelCrushMix * 0.15;
  const melodicBoost = 1.0 + recipe.melodic.stereoWidthBoost * 0.15;
  const lufsBoost = recipe.targetLufs === -9.5 ? 1.18 : 1.08;

  const baseId = manifest.id;
  const masteredMp3Url = `/mock-storage/${baseId}_mastered.mp3`;
  const masteredWavUrl = `/mock-storage/${baseId}_mastered.wav`;

  const curves = manifest.modulationBus.encodedCurvesBase64;

  return {
    ...manifest,
    provenance: 'measured',
    assets: {
      ...manifest.assets,
      masterMp3Url: masteredMp3Url,
      masterWavUrl: masteredWavUrl,
      stemUrls: {
        vocals: `/mock-storage/${baseId}_vocals_mastered.wav`,
        drums: `/mock-storage/${baseId}_drums_mastered.wav`,
        bass: `/mock-storage/${baseId}_bass_mastered.wav`,
        melodic: `/mock-storage/${baseId}_melodic_mastered.wav`,
      },
    },
    modulationBus: {
      ...manifest.modulationBus,
      encodedCurvesBase64: {
        masterRms: scaleBase64Uint8Curve(curves.masterRms, lufsBoost),
        vocals: scaleBase64Uint8Curve(curves.vocals, voxBoost),
        drums: scaleBase64Uint8Curve(curves.drums, drumsBoost),
        bass: scaleBase64Uint8Curve(curves.bass, bassBoost),
        melodic: scaleBase64Uint8Curve(curves.melodic, melodicBoost),
      },
    },
  };
}

