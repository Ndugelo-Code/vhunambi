import { getGenrePreset, hasGenrePreset } from './constants.js';
import { sanitizeLyricsForAceStep } from '../lyrics/lyrics_sanitizer.js';
import {
  generateLocalMockLyrics,
  planSonicArrangementFromPrompt,
} from '../lyrics/llm_handler.js';
import { MelodyPatternManifest } from '../melody/melody_types.js';
import { renderMelodyReferencePayload } from '../melody/melody_presets.js';
import type {
  ReferenceAudioMode,
  ResolvedAudioEngine,
  StudioEngineTier,
} from '../jobs/job_types.js';

export interface VoiceCastInput {
  ensemble?: 'solo' | 'duet' | 'choir';
  gender?: 'male' | 'female' | 'mixed';
  deliveryMode?: 'auto' | 'melodic' | 'rap' | 'spokenWord' | 'choir';
  energy?: 'soft' | 'mid' | 'intense';
  selectedVoiceIds?: string[];
  clonedVoiceProfileId?: string;
  clonedVoiceReferenceUrl?: string;
  dialectInflection?: {
    vowelElongation?: number;
    vibratoDepth?: number;
    callAndResponseIntensity?: number;
    adLibFrequency?: number;
  };
}

export interface SongSpecInput {
  trackTitle: string;
  isAutoTitle?: boolean;
  prompt?: string;
  genre: string;
  region?: string;
  language: string;
  lyricsMode?: 'ai_writes' | 'my_own' | 'from_photo' | 'instrumental';
  lyrics?: string;
  sourcePhotoUrl?: string;
  isInstrumental?: boolean;
  mood?: string;
  era?: string;
  songStructure?: 'standard' | 'extended' | 'freestyle' | 'loop';
  tempoBpm?: number;
  musicalKey?: string;
  durationSec?: number;
  engineTier?: StudioEngineTier;
  batchCount?: number;
  audioMode?: ReferenceAudioMode;
  visibility?: 'public' | 'private';
  voiceCast?: VoiceCastInput;
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
  richPrompt?: string;
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
  engineTier: StudioEngineTier;
  resolvedEngine: ResolvedAudioEngine;
  attributionTag: string | null;
  batchCount: number;
  takeSeeds: number[];
  audioMode: ReferenceAudioMode;
  visibility: 'public' | 'private';
  voiceCast?: VoiceCastInput;
  metadata: {
    bpm: number;
    key: string;
    timeSignature: string;
    durationSec: number;
    /** Canonical genre key (e.g. "amapiano", "gqom") — required by handler.py song_spec */
    genre: string;
    region: string;
    /** Mood descriptor (e.g. "energetic", "melancholic") — required by handler.py song_spec */
    mood: string;
    era?: string;
    songStructure?: string;
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

/**
 * Deterministically selects the optimal audio synthesis engine while enforcing
 * MiniMax Music 3.0 serving and attribution rules:
 * - `fast_draft` -> `ace_step_xl_turbo`
 * - `sovereign_custom` or Reference Audio / Cloned Voice -> `ace_step_xl_base`
 * - `studio_bake` with `isInstrumental == true` -> `ace_step_xl_sft` (prevents sglang-omni 400 on empty lyrics)
 * - `studio_bake` vocal/duet -> `minimax_music_3` (`MiniMax-Music3` attribution required)
 */
export function resolveTargetAudioEngine(input: {
  engineTier?: StudioEngineTier;
  isInstrumental?: boolean;
  audioMode?: ReferenceAudioMode;
  referenceAudioUrl?: string;
  clonedVoiceProfileId?: string;
}): {
  resolvedEngine: ResolvedAudioEngine;
  attributionTag: string | null;
} {
  const tier = input.engineTier ?? 'studio_bake';
  const hasReference =
    Boolean(input.referenceAudioUrl?.trim()) &&
    (input.audioMode ?? 'none') !== 'none';
  const hasVoiceClone = Boolean(input.clonedVoiceProfileId?.trim());

  if (tier === 'fast_draft') {
    return { resolvedEngine: 'ace_step_xl_turbo', attributionTag: null };
  }
  if (tier === 'sovereign_custom' || hasReference || hasVoiceClone) {
    return { resolvedEngine: 'ace_step_xl_base', attributionTag: null };
  }
  if (input.isInstrumental) {
    return { resolvedEngine: 'ace_step_xl_sft', attributionTag: null };
  }
  return { resolvedEngine: 'minimax_music_3', attributionTag: 'MiniMax-Music3' };
}

/**
 * Generates `batchCount` unique non-zero 53-bit positive integer seeds so
 * MiniMax Music 3.0's `sglang-omni` server (`seed = 0` default) never emits identical takes.
 */
export function generateUniqueTakeSeeds(batchCount: number): number[] {
  const count = Math.max(1, Math.min(4, Math.round(batchCount || 1)));
  const seeds = new Set<number>();
  while (seeds.size < count) {
    const buf = new Uint32Array(2);
    crypto.getRandomValues(buf);
    const hi = (buf[0]! & 0x001fffff) * 0x100000000;
    const candidate = hi + buf[1]!;
    if (candidate > 0) {
      seeds.add(candidate);
    }
  }
  return [...seeds];
}

/**
 * Builds acoustic/arrangement tags from cockpit selections and rich user prompts.
 * Phase 80 lifts the legacy 48-char truncation cap (STU-10) so detailed descriptions
 * up to 320 chars enrich captions, while `richPrompt` carries the full 4000-char brief.
 */
export function buildAceStepStyleTags(opts: {
  genre: string;
  language: string;
  bpm: number;
  key: string;
  mood?: string;
  era?: string;
  songStructure?: string;
  prompt?: string;
  isInstrumental?: boolean;
  voiceCast?: VoiceCastInput;
}): string {
  const preset = getGenrePreset(opts.genre);
  const known = hasGenrePreset(opts.genre);
  const genreLabel = opts.genre.trim().toLowerCase();
  const tags: string[] = [];
  const push = (t?: string) => {
    const v = (t ?? '').trim().toLowerCase();
    if (v && !tags.includes(v)) tags.push(v);
  };

  push(known ? `south african ${genreLabel}` : genreLabel);
  push(`${opts.bpm} bpm`);
  push(opts.key);
  preset.characteristicStyle
    .split(',')
    .slice(0, 4)
    .forEach((t) => push(t.replace(/\(.*?\)/g, '')));
  preset.instruments.slice(0, 4).forEach((i) => push(i.replace(/_/g, ' ')));
  (opts.mood || preset.defaultMood).split(/&|,|\/|\band\b/i).forEach((m) => push(m));
  if (opts.era && opts.era.trim()) {
    push(opts.era.replace(/([A-Z])/g, ' $1').trim());
  }
  if (opts.songStructure && opts.songStructure !== 'standard') {
    push(`${opts.songStructure} arrangement`);
  }

  if (opts.isInstrumental) {
    push('instrumental');
    push('no vocals');
  } else {
    const cast = opts.voiceCast;
    if (cast?.ensemble === 'duet') {
      push(
        cast.gender === 'mixed'
          ? 'male and female vocal duet, call and response harmonies'
          : `${cast.gender ?? 'expressive'} vocal duet`,
      );
    } else if (cast?.ensemble === 'choir') {
      push('layered african gospel choir harmonies');
    } else {
      push(
        cast?.gender && cast.gender !== 'mixed'
          ? `${cast.gender} lead vocal`
          : 'soulful african lead vocal',
      );
    }
    if (cast?.deliveryMode && cast.deliveryMode !== 'auto') {
      push(`${cast.deliveryMode} vocal delivery`);
    }
    if (cast?.energy === 'intense') {
      push('high energy passionate vocal projection');
    } else if (cast?.energy === 'soft') {
      push('intimate warm velvet vocal tone');
    }
    if ((cast?.dialectInflection?.vibratoDepth ?? 0) >= 0.7) {
      push('rich expressive vibrato');
    }
    if ((cast?.dialectInflection?.callAndResponseIntensity ?? 0) >= 0.7) {
      push('backing call and response');
    }
  }

  // Extract clean phrases up to 320 characters instead of discarding prompts > 48 chars
  const userPrompt = (opts.prompt ?? '').replace(/[\[\]()]/g, ' ').replace(/\s+/g, ' ').trim();
  if (userPrompt) {
    const clipped = userPrompt.slice(0, 320);
    for (const seg of clipped.split(/[.;,]/)) {
      const phrase = seg.trim();
      if (phrase.length >= 3) push(phrase);
    }
  }
  push('warm clean studio mix');
  return tags.join(', ');
}

export function compileSongSpec(input: SongSpecInput): CompiledSynthesisPrompt {
  const preset = getGenrePreset(input.genre);
  const promptSeed = (input.prompt || input.trackTitle || input.genre).trim();

  const bpm = input.tempoBpm || preset.defaultBpm;
  const key = input.musicalKey || preset.defaultKey;
  const durationSec = Math.max(10, Math.min(360, Math.round(input.durationSec || 180)));
  const engineTier: StudioEngineTier = input.engineTier ?? 'studio_bake';
  const audioMode: ReferenceAudioMode =
    input.audioMode ?? (input.referenceAudioUrl ? 'remix' : 'none');
  const batchCount = Math.max(1, Math.min(4, Math.round(input.batchCount ?? 1)));
  const visibility: 'public' | 'private' = input.visibility ?? 'public';

  const effectiveCloneId =
    input.voiceCast?.clonedVoiceProfileId ?? input.clonedVoiceProfileId;
  const effectiveVoiceId =
    input.voiceCast?.selectedVoiceIds?.[0] ?? input.selectedVoiceId;
  const effectiveCloneRefUrl =
    input.clonedVoiceReferenceUrl ?? input.voiceCast?.clonedVoiceReferenceUrl;

  const { resolvedEngine, attributionTag } = resolveTargetAudioEngine({
    engineTier,
    isInstrumental: Boolean(input.isInstrumental),
    audioMode,
    referenceAudioUrl: input.referenceAudioUrl,
    clonedVoiceProfileId: effectiveCloneId,
  });
  const takeSeeds = generateUniqueTakeSeeds(batchCount);

  // Stage-1 Musical Planner: sonic tags, arrangement structure & LoRA pairing
  const plan = planSonicArrangementFromPrompt(
    promptSeed,
    input.genre,
    input.language,
    bpm,
    key,
  );

  const caption = buildAceStepStyleTags({
    genre: input.genre,
    language: input.language,
    bpm,
    key,
    mood: input.mood,
    era: input.era,
    songStructure: input.songStructure,
    prompt: input.prompt,
    isInstrumental: input.isInstrumental,
    voiceCast: input.voiceCast,
  });

  const resolvedLyrics = input.isInstrumental
    ? ''
    : sanitizeLyricsForAceStep(
      input.lyrics && input.lyrics.trim().length > 0
        ? input.lyrics
        : generateLocalMockLyrics(promptSeed, input.genre, input.language).rawLyrics,
    );

  const svcConfig = effectiveCloneId
    ? {
      mode: 'zero_shot_clone' as const,
      voiceId: effectiveCloneId,
      f0Method: 'rmvpe' as const,
      protectConsonants: 0.42,
      ...(effectiveCloneRefUrl ? { r2ReferenceUrl: effectiveCloneRefUrl } : {}),
    }
    : effectiveVoiceId
      ? {
        mode: 'catalog_archetype' as const,
        voiceId: effectiveVoiceId,
        f0Method: 'rmvpe' as const,
        protectConsonants: 0.35,
      }
      : undefined;

  const melodyRendered = input.melodyPattern
    ? renderMelodyReferencePayload(input.melodyPattern)
    : undefined;

  const melodyConditioning =
    input.melodyPattern && melodyRendered
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
    ...(input.prompt?.trim() ? { richPrompt: input.prompt.trim().slice(0, 4000) } : {}),
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
      inferSteps: resolvedEngine === 'ace_step_xl_turbo' ? 12 : 60,
      guidanceScale: 12.0,
      scheduler: 'euler',
    },
    engineTier,
    resolvedEngine,
    attributionTag,
    batchCount,
    takeSeeds,
    audioMode,
    visibility,
    ...(input.voiceCast ? { voiceCast: input.voiceCast } : {}),
    metadata: {
      bpm,
      key,
      timeSignature: '4/4',
      durationSec,
      genre: input.genre.toLowerCase(),
      region: input.region?.trim() || 'South Africa',
      mood: input.mood?.trim().toLowerCase() || preset.defaultMood,
      ...(input.era ? { era: input.era } : {}),
      ...(input.songStructure ? { songStructure: input.songStructure } : {}),
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
