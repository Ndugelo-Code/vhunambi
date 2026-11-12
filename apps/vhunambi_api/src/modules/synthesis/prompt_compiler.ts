import { getGenrePreset } from './constants.js';
import {
  generateLocalMockLyrics,
  planSonicArrangementFromPrompt,
} from '../lyrics/llm_handler.js';
import { MelodyPatternManifest } from '../melody/melody_types.js';
import { renderMelodyReferencePayload } from '../melody/melody_presets.js';

export interface SongSpecInput {
  trackTitle: string;
  prompt?: string;
  genre: string;
  language: string;
  lyrics?: string;
  isInstrumental?: boolean;
  tempoBpm?: number;
  musicalKey?: string;
  durationSec?: number;
  selectedVoiceId?: string;
  clonedVoiceProfileId?: string;
  melodyPattern?: MelodyPatternManifest;
  melodyReferenceId?: string;
  referenceAudioUrl?: string;
  clonedVoiceReferenceUrl?: string;
  pregenStemLocks?: Record<string, 'lockedPure44k' | 'harmonicInpaint' | 'elasticResynth'>;
  lockedStemsPayload?: Record<string, string>;
}

export interface CompiledSynthesisPrompt {
  caption: string;
  lyrics: string;
  sonicTags?: string[];
  arrangementStructure?: string[];
  loras?: Array<{
    loraId?: string;
    path: string;
    weight: number;
  }>;
  inferenceConfig?: {
    precision: 'bf16' | 'fp16' | 'fp32';
    inferSteps: number;
    guidanceScale: number;
    scheduler: 'euler' | 'heun';
  };
  metadata: {
    bpm: number;
    key: string;
    timeSignature: string;
    durationSec: number;
    /** Canonical genre key (e.g. "amapiano", "gqom") — required by handler.py song_spec */
    genre: string;
    /** Mood descriptor (e.g. "energetic", "melancholic") — required by handler.py song_spec */
    mood: string;
    /** Language identifier (e.g. "tshivenda", "zulu") — required by handler.py song_spec */
    language: string;
    /** Optional track title */
    title?: string;
    /** Pre-generation stem locks for hybrid inpainting (REQ-P52-PIPE-02) */
    pregenStemLocks?: Record<string, string>;
  };
  referenceAudioUrl?: string;
  pregenStemLocks?: Record<string, string>;
  lockedStemsPayload?: Record<string, string>;
  svcConfig?: {
    mode: 'catalog_archetype' | 'zero_shot_clone';
    voiceId: string;
    f0Method: 'rmvpe';
    protectConsonants: number;
    r2ReferenceUrl?: string;
  };
  melodyConditioning?: {
    patternId: string;
    instrument: string;
    bpm: number;
    musicalKey: string;
    scaleMode: string;
    conditioningStrength: number;
    r2ReferenceUrl: string;
    referenceWavBase64: string;
  };
}

export function compileSongSpec(input: SongSpecInput): CompiledSynthesisPrompt {
  const preset = getGenrePreset(input.genre);
  const promptSeed = (input.prompt || input.trackTitle || input.genre).trim();

  const bpm = input.tempoBpm || preset.defaultBpm;
  const key = input.musicalKey || preset.defaultKey;
  const durationSec = input.durationSec || 180;

  // Stage-1 Musical Planner: sonic tags, arrangement structure & LoRA pairing
  const plan = planSonicArrangementFromPrompt(
    promptSeed,
    input.genre,
    input.language,
    bpm,
    key,
  );

  const vocalDescription = input.isInstrumental
    ? 'Instrumental only, no vocals, pure rhythm and melody'
    : `Vocals enabled`;

  const caption = `${plan.expandedCaption} ${vocalDescription}.`;
  const resolvedLyrics = input.isInstrumental
    ? ''
    : input.lyrics && input.lyrics.trim().length > 0
      ? input.lyrics
      : generateLocalMockLyrics(promptSeed, input.genre, input.language).rawLyrics;

  const svcConfig = input.clonedVoiceProfileId
    ? {
        mode: 'zero_shot_clone' as const,
        voiceId: input.clonedVoiceProfileId,
        f0Method: 'rmvpe' as const,
        protectConsonants: 0.42,
        ...(input.clonedVoiceReferenceUrl
          ? { r2ReferenceUrl: input.clonedVoiceReferenceUrl }
          : {}),
      }
    : input.selectedVoiceId
      ? {
          mode: 'catalog_archetype' as const,
          voiceId: input.selectedVoiceId,
          f0Method: 'rmvpe' as const,
          protectConsonants: 0.35,
        }
      : undefined;

  const melodyRendered = input.melodyPattern
    ? renderMelodyReferencePayload(input.melodyPattern)
    : undefined;

  const melodyConditioning = input.melodyPattern && melodyRendered
    ? {
        patternId: input.melodyPattern.id,
        instrument: input.melodyPattern.instrument,
        bpm: input.melodyPattern.bpm,
        musicalKey: input.melodyPattern.musicalKey,
        scaleMode: input.melodyPattern.scaleMode,
        conditioningStrength: input.melodyPattern.conditioningStrength,
        r2ReferenceUrl: melodyRendered.r2ReferenceUrl,
        referenceWavBase64: melodyRendered.wavBase64Preview,
      }
    : undefined;

  return {
    caption,
    lyrics: resolvedLyrics,
    sonicTags: plan.sonicTags,
    arrangementStructure: plan.arrangementStructure,
    loras: [
      {
        loraId: plan.recommendedLoRA.loraId,
        path: plan.recommendedLoRA.r2Key,
        weight: plan.recommendedLoRA.weight,
      },
    ],
    inferenceConfig: {
      precision: 'bf16',
      inferSteps: 45,
      guidanceScale: 15.0,
      scheduler: 'euler',
    },
    metadata: {
      bpm,
      key,
      timeSignature: '4/4',
      durationSec,
      genre: input.genre.toLowerCase(),
      mood: preset.defaultMood,
      language: input.language,
      title: input.trackTitle || undefined,
      pregenStemLocks: input.pregenStemLocks,
    },
    ...(input.referenceAudioUrl ? { referenceAudioUrl: input.referenceAudioUrl } : {}),
    ...(svcConfig ? { svcConfig } : {}),
    ...(melodyConditioning ? { melodyConditioning } : {}),
    ...(input.pregenStemLocks ? { pregenStemLocks: input.pregenStemLocks } : {}),
    ...(input.lockedStemsPayload ? { lockedStemsPayload: input.lockedStemsPayload } : {}),
  };
}
