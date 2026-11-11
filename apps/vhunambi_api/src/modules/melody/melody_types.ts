import { z } from 'zod';

/**
 * melody_types.ts — Phase 27 In-Key 16-Step Melody, Chord & Log-Drum Sketchpad Schemas
 */

export const SketchpadInstrumentSchema = z.enum([
  'amapiano_log_drum',
  'private_school_rhodes',
  'maskandi_guitar',
  'venda_mbira',
  'marimba_wood',
  'concert_grand_piano',
  'classic_piano',
  'nylon_guitar',
  'electric_guitar',
  'bamboo_flute',
  'soprano_sax',
  'solo_violin',
  'hiphop_808_sub',
  'gqom_dark_sub',
  'neo_soul_pad',
  'mbaqanga_organ',
]);
export type SketchpadInstrument = z.infer<typeof SketchpadInstrumentSchema>;

export const AfricanScaleModeSchema = z.enum([
  'minor_pentatonic',
  'natural_minor',
  'maskandi_hexatonic',
  'gqom_phrygian_dark',
]);
export type AfricanScaleMode = z.infer<typeof AfricanScaleModeSchema>;

export const MelodyStepNoteSchema = z.object({
  stepIndex: z.number().int().min(0).max(15),
  scaleRow: z.number().int().min(0).max(7),
  velocity: z.number().min(0.05).max(1.0).default(0.85),
  hasGlide: z.boolean().default(false),
  durationSteps: z.number().int().min(1).max(4).default(1),
});
export type MelodyStepNote = z.infer<typeof MelodyStepNoteSchema>;

export const MelodyPatternManifestSchema = z.object({
  id: z.string().min(1),
  name: z.string().min(1),
  genre: z.string().default('Amapiano'),
  instrument: SketchpadInstrumentSchema.default('amapiano_log_drum'),
  musicalKey: z.string().default('F#m'),
  scaleMode: AfricanScaleModeSchema.default('minor_pentatonic'),
  bpm: z.number().int().min(60).max(180).default(113),
  conditioningStrength: z.number().min(0.1).max(1.0).default(0.65),
  notes: z.array(MelodyStepNoteSchema),
});
export type MelodyPatternManifest = z.infer<typeof MelodyPatternManifestSchema>;

