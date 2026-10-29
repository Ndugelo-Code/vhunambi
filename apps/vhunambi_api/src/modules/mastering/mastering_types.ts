import { z } from 'zod';

/**
 * mastering_types.ts — Canonical Phase 25 Stem Mastering Data Contract
 * Shared between TypeScript Backend API, RunPod Python Worker, and Flutter Client.
 */

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
  midFreqHz: z.number().min(50).max(8000),
  airGainDb: z.number().min(-12).max(12),
});
export type StemEqBands = z.infer<typeof StemEqBandsSchema>;

export const StemMasteringRecipeSchema = z.object({
  presetId: z.string().default('amapiano_club_knock'),
  targetLufs: z.union([z.literal(-9.5), z.literal(-14.0)]).default(-9.5),
  sketchpadLayerMix: z.number().min(0).max(1).default(0.0).optional(),
  vocals: z.object({
    flavor: VocalCleanseFlavorSchema.default('studio_clean'),
    neuralDenoiseStrength: z.number().min(0).max(1).default(0.85),
    neuralDereverbStrength: z.number().min(0).max(1).default(0.65),
    compressionAmount: z.number().min(0).max(1).default(0.6),
    eq: StemEqBandsSchema,
  }),
  bass: z.object({
    flavor: BassCharacterFlavorSchema.default('heavy_wooden_knock'),
    subHarmonicMix: z.number().min(0).max(1).default(0.55),
    knockDriveDb: z.number().min(0).max(9).default(4.5),
    sidechainDuckDb: z.number().min(-6).max(0).default(-3.5),
    eq: StemEqBandsSchema,
  }),
  drums: z.object({
    flavor: DrumCharacterFlavorSchema.default('crisp_shakers'),
    transientAttackSnap: z.number().min(-1).max(1).default(0.45),
    parallelCrushMix: z.number().min(0).max(1).default(0.3),
    eq: StemEqBandsSchema,
  }),
  melodic: z.object({
    flavor: MelodicCharacterFlavorSchema.default('wide_stereo_pocket'),
    midVocalPocketCutDb: z.number().min(-6).max(0).default(-2.5),
    stereoWidthBoost: z.number().min(0).max(1).default(0.35),
    eq: StemEqBandsSchema,
  }),
});
export type StemMasteringRecipe = z.infer<typeof StemMasteringRecipeSchema>;

export interface GenreMasterPresetDescriptor {
  id: string;
  name: string;
  genre: string;
  description: string;
  recipe: StemMasteringRecipe;
}

