import { getGenrePreset } from './constants.js';
import { getLanguageContext } from '../bantu/language_context.js';

export interface SongSpecInput {
  trackTitle: string;
  genre: string;
  language: string;
  lyrics?: string;
  isInstrumental?: boolean;
  tempoBpm?: number;
  musicalKey?: string;
  durationSec?: number;
}

export interface CompiledSynthesisPrompt {
  caption: string;
  lyrics: string;
  metadata: {
    bpm: number;
    key: string;
    timeSignature: string;
    durationSec: number;
  };
}

export function compileSongSpec(input: SongSpecInput): CompiledSynthesisPrompt {
  const preset = getGenrePreset(input.genre);
  const langCtx = getLanguageContext(input.language);

  const bpm = input.tempoBpm || preset.defaultBpm;
  const key = input.musicalKey || preset.defaultKey;
  const durationSec = input.durationSec || 180;

  // Build descriptive prompt caption
  const instrumentation = preset.instruments.join(', ');
  const vocalDescription = input.isInstrumental
    ? 'Instrumental only, no vocals, pure rhythm and melody'
    : `Vocal delivery: ${langCtx.vocalStyleAdvice}`;

  const caption = `${preset.characteristicStyle}. Instruments: ${instrumentation}. Tempo: ${bpm} BPM. Key: ${key}. ${vocalDescription}. High fidelity studio master, 320kbps production quality.`;

  return {
    caption,
    lyrics: input.isInstrumental ? '' : input.lyrics || '',
    metadata: {
      bpm,
      key,
      timeSignature: '4/4',
      durationSec,
    },
  };
}
