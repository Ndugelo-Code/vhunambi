import { getGenrePreset } from '../synthesis/constants.js';
import { getLanguageContext, MUSIC_LANGUAGES } from '../bantu/language_context.js';
import { SongMetadataDNA, LyricWordTimestamp } from './dna_types.js';

export interface CompileDnaInput {
  id?: string;
  title?: string;
  genre: string;
  language: string;
  mood?: string;
  bpm?: number;
  key?: string;
  durationSec?: number;
  deliveryMode?: 'melodic' | 'rap' | 'spokenWord' | 'choir';
  gender?: 'male' | 'female' | 'duet' | 'choir';
  energy?: 'soft' | 'mid' | 'intense';
  region?: string;
  prompt?: string;
  alignment?: LyricWordTimestamp[];
  seed?: number;
}

/**
 * Compiles raw user inputs, genre presets, and Bantu linguistic context
 * into an immutable, canonical SongMetadataDNA record.
 */
export function compileSongMetadataDNA(input: CompileDnaInput): SongMetadataDNA {
  const genreKey = input.genre.toLowerCase();
  const preset = getGenrePreset(genreKey);

  // Match language by code ('ve'), name ('Tshivenḓa'), or native name
  const normalizedLang = input.language.toLowerCase().trim();
  const langCtx =
    MUSIC_LANGUAGES.find(
      (l) =>
        l.languageCode.toLowerCase() === normalizedLang ||
        l.languageName.toLowerCase() === normalizedLang ||
        l.nativeName.toLowerCase() === normalizedLang,
    ) || getLanguageContext(input.language);

  const bpm = input.bpm || preset.defaultBpm;
  const key = input.key || preset.defaultKey;
  const mood = input.mood || preset.defaultMood;
  const durationSec = input.durationSec || 180;
  const title = input.title || `${input.genre} Expression`;
  const seed = input.seed || Math.floor(Math.random() * 100000000);

  const deliveryMode = input.deliveryMode || 'melodic';
  const gender = input.gender || 'male';
  const energy = input.energy || (preset.defaultMood === 'intense' ? 'intense' : 'mid');

  const comfyPrompt = input.prompt
    ? `${input.genre} album cover art, ${input.prompt}, ${mood} aesthetic, cinematic studio lighting, 8k resolution, 9:16 vertical ratio`
    : `${preset.characteristicStyle} album cover art, ${mood} mood, vibrant African visual aesthetics, cinematic studio lighting, 8k resolution, 9:16 vertical ratio`;

  return {
    id: input.id || `dna_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`,
    version: '1.0',
    title,
    genre: input.genre,
    language: langCtx.languageName,
    culturalContext: {
      region: input.region || 'Southern Africa',
      idioms: langCtx.adLibs,
      phoneticGuidelines: langCtx.phoneticNotes,
    },
    musical: {
      bpm,
      key,
      timeSignature: '4/4',
      energyBracket: energy,
      structure: 'standard',
      durationSec,
    },
    vocals: {
      deliveryMode,
      gender,
      energy,
      loras: [],
    },
    visualTheme: {
      mood,
      colorPalette: ['#FFB300', '#141418', '#FF8F00'],
      aspectRatio: '9:16',
      comfyPrompt,
      negativePrompt:
        'blurry, low quality, watermark, text, signature, bad anatomy, frame, border',
      seed,
    },
    alignment: input.alignment || [],
  };
}
