/**
 * dna_types.ts — Canonical Song Metadata DNA Schema
 * Aligned with Flutter domain models in lib/features/content_studio/domain/models/
 */

export interface LyricWordTimestamp {
  word: string;
  start: number; // seconds (e.g. 1.25)
  end: number;   // seconds (e.g. 1.65)
  stanzaIndex: number;
}

export interface CulturalContextDNA {
  region: string;
  idioms: string[];
  phoneticGuidelines: string;
}

export interface MusicalDNA {
  bpm: number;
  key: string;
  timeSignature: '4/4' | '3/4' | '6/8';
  energyBracket: 'soft' | 'mid' | 'intense';
  structure: 'standard' | 'extended' | 'freestyle';
  durationSec: number;
}

export interface VocalsDNA {
  deliveryMode: 'melodic' | 'rap' | 'spokenWord' | 'choir';
  gender: 'male' | 'female' | 'duet' | 'choir';
  energy: 'soft' | 'mid' | 'intense';
  loras: Array<{ path: string; weight: number }>;
}

export interface VisualThemeDNA {
  mood: string;
  colorPalette: string[];
  aspectRatio: '9:16' | '1:1';
  comfyPrompt: string;
  negativePrompt: string;
  seed: number;
}

export interface SongMetadataDNA {
  id: string;
  version: '1.0';
  title: string;
  genre: string;
  language: string;
  culturalContext?: CulturalContextDNA;
  musical: MusicalDNA;
  vocals: VocalsDNA;
  visualTheme: VisualThemeDNA;
  alignment: LyricWordTimestamp[];
}
