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

export type StemRole = 'vocals' | 'drums' | 'bass' | 'melodic';

export type TransientEventType =
  | 'kick'
  | 'log_drum_drop'
  | 'snare_clap'
  | 'vocal_onset'
  | 'harmonic_turnaround'
  | 'section_change';

export interface LyricWordTimestampV2 extends LyricWordTimestamp {
  phoneticStress?: number;   // 0.0 to 1.0 (defaults to 0.5)
  isCulturalIdiom?: boolean; // highlights Bantu ad-libs in brandPrimary
}

export interface TransientEvent {
  timestampMs: number;
  type: TransientEventType;
  stem: StemRole;
  intensity: number;         // 0.0 to 1.0
  durationMs?: number;       // default decay window 180ms
}

export interface MpcPadSliceManifest {
  padIndex: number;          // 0 to 7 mapping to mpc_pad_0..7
  label: string;             // e.g. "Kick Downbeat", "Log Drum Drop"
  sourceStem: StemRole;
  startSec: number;
  endSec: number;
  peakIntensity: number;     // 0.0 to 1.0
  recommendedSemitoneShift: number; // default 0 (-12..+12)
}

export interface SongSectionBlueprint {
  name: 'Intro' | 'Vocal Chant' | 'Log Drum Build' | 'The Drop' | 'Bridge' | 'Outro';
  startMs: number;
  endMs: number;
  barsCount: number;
  dominantStem: StemRole;
  visualPresetOverride?: 'subtle_drift' | 'logdrum_punch' | 'hyperkinetic';
}

export interface MasterMediaObjectManifest extends Omit<SongMetadataDNA, 'version' | 'alignment'> {
  schemaVersion: '2.0';
  version?: string;
  provenance: 'measured' | 'synthesized';
  alignment: LyricWordTimestampV2[];

  assets: {
    masterMp3Url: string;
    masterWavUrl?: string;
    coverArt9x16Url: string;
    coverArt1x1Url?: string;
    stemsZipUrl?: string;
    stemUrls: Record<StemRole, string>;
  };

  modulationBus: {
    sampleRateHz: 60;
    durationMs: number;
    frameCount: number;
    encodedCurvesBase64: {
      masterRms: string;     // 60Hz Uint8 curve Base64
      vocals: string;
      drums: string;
      bass: string;          // Dedicated Amapiano log-drum / sub-bass
      melodic: string;
    };
    transientEvents: TransientEvent[];
  };

  mpcKitPads: MpcPadSliceManifest[];
  structure: {
    sections: SongSectionBlueprint[];
  };
}

