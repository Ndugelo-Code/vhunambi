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
  creatorName: z.string(),
  nativeLanguage: z.string(),
  timbreEmbeddingPreview: z.array(z.number()).length(8),
  cadenceWpm: z.number(),
  clarityScore: z.number().min(0).max(1),
  r2ReferenceUrl: z.string(),
  recommendedCleanseFlavor: VocalCleanseFlavorSchema,
  createdAtIso: z.string(),
});
export type CreatorVoiceCloneProfile = z.infer<typeof CreatorVoiceCloneProfileSchema>;

