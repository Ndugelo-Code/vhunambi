import { z } from 'zod';

/**
 * Pure Edge LoRA Training Dataset Contract (Phase 85).
 * Ported cleanly from Zania Explore training-dataset.ts with zero React/Next/D1 deps.
 */
export const VhunambiLoraIdSchema = z.enum([
  'amapiano_logdrum_v1',
  'amapiano_private_school_v1',
  'sgija_bacardi_v1',
  'gqom_durban_v1',
  'maskandi_picking_v1',
  'venda_malende_v1',
  'afrobeats_lagos_v1',
  'kwaito_township_v1',
  'afro_gospel_choir_v1',
  'afrohouse_ancestral_v1',
  'bantu_vocals_v1',
]);

export type VhunambiLoraId = z.infer<typeof VhunambiLoraIdSchema>;

export const TrainingGenreSchema = z.enum([
  'amapiano',
  'private_school_amapiano',
  'sgija',
  'gqom',
  'maskandi',
  'venda_malende',
  'afrobeats',
  'kwaito',
  'gospel',
  'afro_house',
  'bantu_vocals',
]);

export type TrainingGenre = z.infer<typeof TrainingGenreSchema>;

export const BantuLanguageSchema = z.enum([
  'zu-ZA',
  'xh-ZA',
  'nso-ZA',
  've-ZA',
  'tn-ZA',
  'st-ZA',
  'ts-ZA',
  'ss-ZA',
  'nr-ZA',
  'af-ZA',
  'en-ZA',
  'mixed',
]);

export type BantuLanguage = z.infer<typeof BantuLanguageSchema>;

export const AudioSpecSchema = z.object({
  duration_sec: z.number().min(30).max(300),
  sample_rate: z.union([z.literal(44100), z.literal(48000)]),
  bit_depth: z.union([z.literal(16), z.literal(24)]),
  channels: z.union([z.literal(1), z.literal(2)]).default(2),
});

export const MusicalKeySchema = z.object({
  tonic: z.enum([
    'C', 'C#', 'Db', 'D', 'D#', 'Eb', 'E', 'F',
    'F#', 'Gb', 'G', 'G#', 'Ab', 'A', 'A#', 'Bb', 'B',
  ]),
  mode: z.enum(['major', 'minor', 'dorian', 'mixolydian', 'unknown']),
});

export const TrainingTrackMetadataSchema = z.object({
  title: z.string().min(1).max(160),
  lora_id: VhunambiLoraIdSchema,
  genre: TrainingGenreSchema,
  sub_genre: z.string().min(1).max(64).optional(),
  bpm: z.number().int().min(60).max(200),
  key: MusicalKeySchema.optional(),
  time_signature: z.enum(['4/4', '3/4', '6/8', '12/8']).default('4/4'),
  language: BantuLanguageSchema.default('en-ZA'),
  lyrics: z.string().max(12000).default(''),
  instrumental: z.boolean().default(false),
  instrumentation: z.array(z.string().min(1).max(48)).min(1).max(30),
  avoid_instrumentation: z.array(z.string().min(1).max(48)).max(10).default([]),
  mood: z.array(z.string().min(1).max(32)).max(10).default([]),
  energy: z.enum(['low', 'medium', 'high']).default('medium'),
  cultural_notes: z.string().max(1000).default(''),
  audio: AudioSpecSchema.optional(),
  license: z.enum(['royalty_free', 'cc0', 'cc_by', 'owned', 'licensed']).default('owned'),
  attribution: z.string().max(300).optional(),
  training_weight: z.number().min(0.1).max(3.0).default(1.0),
  exclude_from_training: z.boolean().default(false),
  source_r2_key: z.string().max(512).optional(),
  source_sha256: z.string().max(128).optional(),
});

export type TrainingTrackMetadata = z.infer<typeof TrainingTrackMetadataSchema>;

export const LoraRegistryStatusSchema = z.enum([
  'untrained',
  'preparing',
  'ready_to_train',
  'queued',
  'training',
  'validating',
  'active',
  'failed',
  'deprecated',
]);

export type LoraRegistryStatus = z.infer<typeof LoraRegistryStatusSchema>;

export interface LoraHyperparamDefaults {
  loraRank: number;
  loraAlpha: number;
  epochs: number;
  batchSize: number;
  gradAccumSteps: number;
  learningRate: number;
  warmupSteps: number;
  minTracks: number;
  recommendedTracks: number;
  extractVocals: boolean;
  defaultInstrumentation: string[];
}

export function getTrainingHyperparamDefaults(loraId: VhunambiLoraId): LoraHyperparamDefaults {
  switch (loraId) {
    case 'bantu_vocals_v1':
      return {
        loraRank: 32,
        loraAlpha: 64,
        epochs: 20,
        batchSize: 1,
        gradAccumSteps: 4,
        learningRate: 5e-5,
        warmupSteps: 120,
        minTracks: 8,
        recommendedTracks: 15,
        extractVocals: true,
        defaultInstrumentation: ['lead_vocals', 'backing_harmonies', 'bantu_phonetics'],
      };
    case 'amapiano_logdrum_v1':
    case 'amapiano_private_school_v1':
      return {
        loraRank: 32,
        loraAlpha: 64,
        epochs: 12,
        batchSize: 2,
        gradAccumSteps: 2,
        learningRate: 1.5e-4,
        warmupSteps: 50,
        minTracks: 8,
        recommendedTracks: 15,
        extractVocals: false,
        defaultInstrumentation: ['log_drum', 'shaker', 'rhodes_piano', 'sub_bass'],
      };
    case 'maskandi_picking_v1':
    case 'venda_malende_v1':
    case 'afro_gospel_choir_v1':
      return {
        loraRank: 32,
        loraAlpha: 64,
        epochs: 14,
        batchSize: 1,
        gradAccumSteps: 4,
        learningRate: 1e-4,
        warmupSteps: 60,
        minTracks: 8,
        recommendedTracks: 15,
        extractVocals: false,
        defaultInstrumentation: ['acoustic_guitar', 'traditional_percussion', 'vocal_choir'],
      };
    default:
      return {
        loraRank: 16,
        loraAlpha: 32,
        epochs: 10,
        batchSize: 2,
        gradAccumSteps: 2,
        learningRate: 1.2e-4,
        warmupSteps: 40,
        minTracks: 8,
        recommendedTracks: 15,
        extractVocals: false,
        defaultInstrumentation: ['drums', 'bass', 'percussion', 'synth'],
      };
  }
}

export function getTrainingGenreForLoraId(loraId: VhunambiLoraId): TrainingGenre {
  switch (loraId) {
    case 'amapiano_logdrum_v1':
      return 'amapiano';
    case 'amapiano_private_school_v1':
      return 'private_school_amapiano';
    case 'sgija_bacardi_v1':
      return 'sgija';
    case 'gqom_durban_v1':
      return 'gqom';
    case 'maskandi_picking_v1':
      return 'maskandi';
    case 'venda_malende_v1':
      return 'venda_malende';
    case 'afrobeats_lagos_v1':
      return 'afrobeats';
    case 'kwaito_township_v1':
      return 'kwaito';
    case 'afro_gospel_choir_v1':
      return 'gospel';
    case 'afrohouse_ancestral_v1':
      return 'afro_house';
    case 'bantu_vocals_v1':
      return 'bantu_vocals';
  }
}

export interface SourceTrackCandidate {
  id: string;
  title: string;
  genre: string;
  subGenre?: string;
  audioUrl: string;
  contentSha256?: string;
  bpm?: number;
  lyricsText?: string;
  sourceOrigin?: string;
}

export function extractR2KeyFromAudioUrl(audioUrl: string): string | null {
  const trimmed = (audioUrl || '').trim();
  if (!trimmed) return null;
  if (trimmed.startsWith('/r2/')) return trimmed.slice(4).replace(/^\/+/, '');
  const idx = trimmed.indexOf('/r2/');
  if (idx !== -1) return trimmed.slice(idx + 4).replace(/^\/+/, '');
  if (/^(media|training-data|audio|stems)\//i.test(trimmed)) return trimmed;
  return null;
}

export function selectSourceTracksForLoraPack(
  loraId: VhunambiLoraId,
  tracks: SourceTrackCandidate[],
): SourceTrackCandidate[] {
  const seen = new Set<string>();
  const matches: SourceTrackCandidate[] = [];

  for (const t of tracks) {
    const r2Key = extractR2KeyFromAudioUrl(t.audioUrl);
    if (!r2Key) continue;
    const dedupeKey = (t.contentSha256 || r2Key).toLowerCase();
    if (seen.has(dedupeKey)) continue;

    const g = (t.genre || '').toLowerCase();
    const sg = (t.subGenre || '').toLowerCase();
    const hasLyrics = (t.lyricsText || '').trim().length >= 24;

    let ok = false;
    switch (loraId) {
      case 'amapiano_logdrum_v1':
        ok = g.includes('amapiano') || sg.includes('amapiano');
        break;
      case 'amapiano_private_school_v1':
        ok = g.includes('amapiano') || g.includes('jazz') || sg.includes('private school');
        break;
      case 'afrobeats_lagos_v1':
        ok = g.includes('afrobeats') || g.includes('afro fusion') || sg.includes('afro');
        break;
      case 'afrohouse_ancestral_v1':
        ok = g.includes('afro house') || g.includes('house');
        break;
      case 'bantu_vocals_v1':
        ok = hasLyrics;
        break;
      case 'venda_malende_v1':
        ok = g.includes('venda') || g.includes('malende') || g.includes('lekompo') || sg.includes('venda');
        break;
      case 'sgija_bacardi_v1':
        ok = g.includes('sgija') || g.includes('bacardi') || sg.includes('sgija') || sg.includes('bacardi');
        break;
      case 'gqom_durban_v1':
        ok = g.includes('gqom') || sg.includes('gqom');
        break;
      case 'maskandi_picking_v1':
        ok = g.includes('maskandi') || g.includes('mbaqanga');
        break;
      case 'kwaito_township_v1':
        ok = g.includes('kwaito') || g.includes('hip hop');
        break;
      case 'afro_gospel_choir_v1':
        ok = g.includes('gospel') || g.includes('isicathamiya') || g.includes('mbube');
        break;
    }

    if (ok) {
      seen.add(dedupeKey);
      matches.push(t);
    }
  }
  return matches;
}
