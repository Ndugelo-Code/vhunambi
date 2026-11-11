import { z } from 'zod';
import { VocalCleanseFlavorSchema } from '../mastering/mastering_types.js';

export const VocalGenderSchema = z.enum(['male', 'female', 'duet', 'choir']);
export type VocalGender = z.infer<typeof VocalGenderSchema>;

export const AfricanVoiceRegionSchema = z.enum([
  'southern_africa',
  'west_africa',
  'east_africa',
  'central_africa',
  'diaspora',
]);
export type AfricanVoiceRegion = z.infer<typeof AfricanVoiceRegionSchema>;

export const VocalDeliveryStyleSchema = z.enum([
  'melodic_soul',
  'amapiano_chant',
  'gqom_mc',
  'maskandi_storyteller',
  'afrobeats_smooth',
  'choir_harmony',
]);
export type VocalDeliveryStyle = z.infer<typeof VocalDeliveryStyleSchema>;

export const RegionalVoiceArchetypeSchema = z.object({
  id: z.string(),
  name: z.string(),
  region: AfricanVoiceRegionSchema,
  gender: VocalGenderSchema,
  deliveryStyle: VocalDeliveryStyleSchema,
  nativeLanguage: z.string(),
  accentDescription: z.string(),
  vocalRange: z.string(),
  loraScale: z.number().min(0.1).max(1.5),
  formantShiftSemitones: z.number().min(-4).max(4),
  recommendedCleanseFlavor: VocalCleanseFlavorSchema,
  samplePreviewUrl: z.string(),
});
export type RegionalVoiceArchetype = z.infer<typeof RegionalVoiceArchetypeSchema>;

export const PhoneticCalibrationLineSchema = z.object({
  lineIndex: z.number().int().min(0),
  text: z.string(),
  phoneticScore: z.number(),
  highlightedTokens: z.array(z.string()),
  estimatedDurationSec: z.number().min(2).max(15),
});
export type PhoneticCalibrationLine = z.infer<typeof PhoneticCalibrationLineSchema>;

export const PhoneticCalibrationScriptSchema = z.object({
  language: z.string(),
  lines: z.array(PhoneticCalibrationLineSchema).length(3),
  totalEstimatedDurationSec: z.number(),
});
export type PhoneticCalibrationScript = z.infer<typeof PhoneticCalibrationScriptSchema>;

export const CreateVoiceCloneRequestSchema = z.object({
  creatorId: z.string().optional(),
  creatorName: z.string().min(1).default('Sovereign Creator'),
  nativeLanguage: z.string().default('Tshivenḓa'),
  calibrationLines: z.array(z.string()).min(1).max(5),
  recordingDurationSec: z.number().min(3).max(60).default(18),
  audioBase64: z.string().optional(),
  r2ReferenceUrl: z.string().optional(),
});
export type CreateVoiceCloneRequest = z.infer<typeof CreateVoiceCloneRequestSchema>;

export const CreatorVoiceCloneProfileSchema = z.object({
  id: z.string(),
  creatorId: z.string().optional(),
  creatorName: z.string(),
  nativeLanguage: z.string(),
  timbreEmbeddingPreview: z.array(z.number()).length(8),
  cadenceWpm: z.number(),
  clarityScore: z.number().min(0).max(1),
  r2ReferenceUrl: z.string(),
  recommendedCleanseFlavor: VocalCleanseFlavorSchema,
  createdAtIso: z.string(),
  signatureId: z.string().optional(),
});
export type CreatorVoiceCloneProfile = z.infer<typeof CreatorVoiceCloneProfileSchema>;

export const SoundIdealizerRecipeSchema = z.object({
  pitchScaleLock: z.number().min(0).max(1).default(0.9),
  vibratoAndSustainPolish: z.number().min(0).max(1).default(0.75),
  formantDepthShiftSemitones: z.number().min(-3).max(3).default(0.0),
  chestPowerAndAirBoost: z.number().min(0).max(1).default(0.8),
  quantizePocketStrength: z.number().min(0).max(1).default(0.85),
  hybridArchetypeId: z.string().nullable().optional(),
  hybridBlendMix: z.number().min(0).max(0.75).default(0.25),
  referenceCleanup: z.number().min(0).max(1).default(0.7),
});
export type SoundIdealizerRecipe = z.infer<typeof SoundIdealizerRecipeSchema>;

export const RegisterSoundSignatureSchema = z.object({
  id: z.string().min(1),
  creatorId: z.string().optional(),
  displayCode: z.string().min(1),
  source: z.enum(['live', 'imported']),
  durationSec: z.number().min(1).max(180),
  recipe: SoundIdealizerRecipeSchema.optional().default({}),
  descriptor16: z.array(z.number()).length(16),
  formants4: z.array(z.number()).length(4),
  consentAtIso: z.string().optional(),
  consentConfirmed: z.boolean().optional(),
});
export type RegisterSoundSignatureRequest = z.infer<typeof RegisterSoundSignatureSchema>;

export const SoundSignatureRecordSchema = z.object({
  id: z.string(),
  displayCode: z.string(),
  source: z.enum(['live', 'imported']),
  durationSec: z.number(),
  recipe: SoundIdealizerRecipeSchema,
  descriptor16: z.array(z.number()),
  formants4: z.array(z.number()),
  consentAtIso: z.string().optional(),
  cloudEmbeddingRef: z.string().optional(),
  r2AudioKey: z.string().optional(),
  createdAtIso: z.string(),
  updatedAtIso: z.string(),
});
export type SoundSignatureRecord = z.infer<typeof SoundSignatureRecordSchema>;


