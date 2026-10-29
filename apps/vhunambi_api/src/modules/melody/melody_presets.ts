import { TransientEvent } from '../dna/dna_types.js';
import {
  AfricanScaleMode,
  MelodyPatternManifest,
  SketchpadInstrument,
} from './melody_types.js';

/**
 * Semitone ladders for the 4 Sovereign African Scale Modes (REQ-SKP-02).
 * Every row (0..7) is guaranteed in-key across 1 octave + 9th.
 */
export const SCALE_SEMITONE_LADDERS: Record<AfricanScaleMode, readonly number[]> = {
  minor_pentatonic: [0, 3, 5, 7, 10, 12, 15, 17],
  natural_minor: [0, 2, 3, 5, 7, 8, 10, 12],
  maskandi_hexatonic: [0, 2, 4, 5, 7, 9, 12, 14],
  gqom_phrygian_dark: [0, 1, 5, 7, 8, 10, 12, 13],
};

const ROOT_NOTE_OFFSETS: Record<string, number> = {
  C: 0,
  'C#': 1,
  Db: 1,
  D: 2,
  'D#': 3,
  Eb: 3,
  E: 4,
  F: 5,
  'F#': 6,
  Gb: 6,
  G: 7,
  'G#': 8,
  Ab: 8,
  A: 9,
  'A#': 10,
  Bb: 10,
  B: 11,
};

/**
 * Resolves the exact fundamental frequency (Hz) for a given root key, scale mode, and row (0..7).
 * Log drums anchor in the sub-bass/knock octave (C2 = MIDI 36), melodic instruments anchor at C4 (MIDI 60).
 */
export function resolveScaleFrequencyHz(
  musicalKey: string,
  scaleMode: AfricanScaleMode,
  scaleRow: number,
  instrument: SketchpadInstrument = 'amapiano_log_drum',
): number {
  const cleanRoot = musicalKey.replace(/m(in(or)?)?$/i, '').trim();
  const rootSemitone = ROOT_NOTE_OFFSETS[cleanRoot] ?? 6; // Default F#
  const baseMidi = instrument === 'amapiano_log_drum' ? 36 : 60;
  const ladder = SCALE_SEMITONE_LADDERS[scaleMode] ?? SCALE_SEMITONE_LADDERS.minor_pentatonic;
  const clampedRow = Math.max(0, Math.min(7, scaleRow));
  const midiNote = baseMidi + rootSemitone + ladder[clampedRow];
  const freq = 440.0 * Math.pow(2.0, (midiNote - 69.0) / 12.0);
  return Number(freq.toFixed(2));
}

/**
 * 6 Iconic African Starter Melody & Log-Drum Patterns (REQ-SKP-04).
 */
export const STARTER_MELODY_PATTERNS: MelodyPatternManifest[] = [
  {
    id: 'kabza_logdrum_bounce',
    name: 'Soweto Log-Drum Knock & Slide',
    genre: 'Amapiano',
    instrument: 'amapiano_log_drum',
    musicalKey: 'F#m',
    scaleMode: 'minor_pentatonic',
    bpm: 113,
    conditioningStrength: 0.72,
    notes: [
      { stepIndex: 0, scaleRow: 0, velocity: 0.95, hasGlide: false, durationSteps: 1 },
      { stepIndex: 3, scaleRow: 2, velocity: 0.90, hasGlide: true, durationSteps: 2 },
      { stepIndex: 6, scaleRow: 0, velocity: 0.85, hasGlide: false, durationSteps: 1 },
      { stepIndex: 8, scaleRow: 3, velocity: 0.98, hasGlide: false, durationSteps: 1 },
      { stepIndex: 11, scaleRow: 4, velocity: 1.0, hasGlide: true, durationSteps: 2 },
      { stepIndex: 14, scaleRow: 1, velocity: 0.88, hasGlide: false, durationSteps: 1 },
    ],
  },
  {
    id: 'private_school_rhodes_lush',
    name: 'Kelvin-Style Soulful Rhodes 7ths',
    genre: 'Private School Amapiano',
    instrument: 'private_school_rhodes',
    musicalKey: 'Am',
    scaleMode: 'natural_minor',
    bpm: 112,
    conditioningStrength: 0.65,
    notes: [
      { stepIndex: 0, scaleRow: 0, velocity: 0.82, hasGlide: false, durationSteps: 4 },
      { stepIndex: 4, scaleRow: 3, velocity: 0.78, hasGlide: false, durationSteps: 4 },
      { stepIndex: 8, scaleRow: 5, velocity: 0.85, hasGlide: false, durationSteps: 4 },
      { stepIndex: 12, scaleRow: 4, velocity: 0.80, hasGlide: false, durationSteps: 4 },
    ],
  },
  {
    id: 'maskandi_ukupika_turnaround',
    name: 'KZN Ukupika Acoustic Guitar Picking',
    genre: 'Maskandi',
    instrument: 'maskandi_guitar',
    musicalKey: 'G',
    scaleMode: 'maskandi_hexatonic',
    bpm: 124,
    conditioningStrength: 0.75,
    notes: [
      { stepIndex: 0, scaleRow: 0, velocity: 0.92, hasGlide: false, durationSteps: 1 },
      { stepIndex: 2, scaleRow: 2, velocity: 0.84, hasGlide: false, durationSteps: 1 },
      { stepIndex: 4, scaleRow: 4, velocity: 0.90, hasGlide: false, durationSteps: 1 },
      { stepIndex: 6, scaleRow: 5, velocity: 0.86, hasGlide: false, durationSteps: 1 },
      { stepIndex: 8, scaleRow: 7, velocity: 0.95, hasGlide: false, durationSteps: 1 },
      { stepIndex: 10, scaleRow: 4, velocity: 0.84, hasGlide: false, durationSteps: 1 },
      { stepIndex: 12, scaleRow: 2, velocity: 0.88, hasGlide: false, durationSteps: 1 },
      { stepIndex: 14, scaleRow: 1, velocity: 0.82, hasGlide: false, durationSteps: 1 },
    ],
  },
  {
    id: 'venda_domba_mbira',
    name: 'Vhembe Royal Mbira Ostinato',
    genre: 'Afro Soul',
    instrument: 'venda_mbira',
    musicalKey: 'Dm',
    scaleMode: 'minor_pentatonic',
    bpm: 108,
    conditioningStrength: 0.68,
    notes: [
      { stepIndex: 0, scaleRow: 4, velocity: 0.88, hasGlide: false, durationSteps: 1 },
      { stepIndex: 3, scaleRow: 2, velocity: 0.82, hasGlide: false, durationSteps: 1 },
      { stepIndex: 6, scaleRow: 5, velocity: 0.90, hasGlide: false, durationSteps: 1 },
      { stepIndex: 8, scaleRow: 0, velocity: 0.94, hasGlide: false, durationSteps: 1 },
      { stepIndex: 11, scaleRow: 3, velocity: 0.85, hasGlide: false, durationSteps: 1 },
      { stepIndex: 14, scaleRow: 6, velocity: 0.89, hasGlide: false, durationSteps: 1 },
    ],
  },
  {
    id: 'gqom_dark_sub_pulse',
    name: 'eThekwini Broken-Beat Sub Pulse',
    genre: 'Gqom',
    instrument: 'amapiano_log_drum',
    musicalKey: 'Cm',
    scaleMode: 'gqom_phrygian_dark',
    bpm: 127,
    conditioningStrength: 0.78,
    notes: [
      { stepIndex: 0, scaleRow: 0, velocity: 1.0, hasGlide: false, durationSteps: 1 },
      { stepIndex: 3, scaleRow: 1, velocity: 0.95, hasGlide: true, durationSteps: 2 },
      { stepIndex: 7, scaleRow: 0, velocity: 0.92, hasGlide: false, durationSteps: 1 },
      { stepIndex: 10, scaleRow: 3, velocity: 0.96, hasGlide: true, durationSteps: 2 },
      { stepIndex: 13, scaleRow: 1, velocity: 0.90, hasGlide: false, durationSteps: 1 },
    ],
  },
  {
    id: 'afro_house_marimba_arp',
    name: 'Horizon Wooden Marimba Arpeggio',
    genre: 'Afro House',
    instrument: 'marimba_wood',
    musicalKey: 'Em',
    scaleMode: 'minor_pentatonic',
    bpm: 120,
    conditioningStrength: 0.64,
    notes: [
      { stepIndex: 0, scaleRow: 0, velocity: 0.86, hasGlide: false, durationSteps: 1 },
      { stepIndex: 2, scaleRow: 3, velocity: 0.80, hasGlide: false, durationSteps: 1 },
      { stepIndex: 4, scaleRow: 4, velocity: 0.90, hasGlide: false, durationSteps: 1 },
      { stepIndex: 7, scaleRow: 6, velocity: 0.88, hasGlide: false, durationSteps: 1 },
      { stepIndex: 10, scaleRow: 4, velocity: 0.82, hasGlide: false, durationSteps: 1 },
      { stepIndex: 12, scaleRow: 2, velocity: 0.85, hasGlide: false, durationSteps: 1 },
      { stepIndex: 15, scaleRow: 5, velocity: 0.91, hasGlide: false, durationSteps: 1 },
    ],
  },
];

export function filterMelodyPresets(query: {
  genre?: string;
  instrument?: string;
}): MelodyPatternManifest[] {
  return STARTER_MELODY_PATTERNS.filter((p) => {
    if (
      query.genre &&
      !p.genre.toLowerCase().includes(query.genre.toLowerCase())
    ) {
      return false;
    }
    if (query.instrument && p.instrument !== query.instrument) {
      return false;
    }
    return true;
  });
}

/**
 * Extracts deterministic MMO `TransientEvent[]` timestamps from a 16-step `MelodyPatternManifest`
 * so `KineticPreviewCanvas` snaps its camera zoom on the user's exact programmed notes (REQ-SKP-13).
 */
export function extractMelodyPatternTransients(
  pattern: MelodyPatternManifest,
  totalDurationSec: number = 16,
): TransientEvent[] {
  const stepSec = 60.0 / pattern.bpm / 4.0; // 16th-note step duration
  const loopSec = stepSec * 16.0;
  const events: TransientEvent[] = [];

  const isLogDrum = pattern.instrument === 'amapiano_log_drum';
  const eventType = isLogDrum ? 'log_drum_drop' : 'harmonic_turnaround';
  const stemRole = isLogDrum ? 'bass' : 'melodic';

  const maxLoops = Math.min(8, Math.max(1, Math.floor(totalDurationSec / loopSec)));

  for (let loopIdx = 0; loopIdx < maxLoops; loopIdx++) {
    const loopOffsetSec = loopIdx * loopSec;
    for (const note of pattern.notes) {
      const timeSec = loopOffsetSec + note.stepIndex * stepSec;
      if (timeSec >= totalDurationSec) continue;

      events.push({
        timestampMs: Math.round(timeSec * 1000),
        type: eventType,
        intensity: Number(
          Math.min(1.0, note.velocity * (note.hasGlide ? 1.08 : 1.0)).toFixed(2),
        ),
        stem: stemRole,
        durationMs: isLogDrum ? (note.hasGlide ? 280 : 220) : 180,
      });
    }
  }

  return events.sort((a, b) => a.timestampMs - b.timestampMs);
}

/**
 * Synthesizes a compact 44-byte RIFF/WAVE PCM Base64 preview & R2 conditioning reference
 * for a submitted `MelodyPatternManifest` (REQ-SKP-12).
 */
export function renderMelodyReferencePayload(pattern: MelodyPatternManifest): {
  patternId: string;
  r2ReferenceUrl: string;
  wavBase64Preview: string;
  stepDurationMs: number;
  loopDurationSec: number;
  resolvedFrequenciesHz: number[];
  transientEvents: TransientEvent[];
} {
  const stepSec = 60.0 / pattern.bpm / 4.0;
  const loopDurationSec = Number((stepSec * 16.0).toFixed(3));

  const resolvedFrequenciesHz = pattern.notes.map((n) =>
    resolveScaleFrequencyHz(
      pattern.musicalKey,
      pattern.scaleMode,
      n.scaleRow,
      pattern.instrument,
    ),
  );

  // Build valid 44-byte RIFF/WAVE + 128-sample PCM preview
  const sampleCount = 128;
  const dataBytes = sampleCount * 2;
  const buf = Buffer.alloc(44 + dataBytes);
  buf.write('RIFF', 0, 'ascii');
  buf.writeUInt32LE(36 + dataBytes, 4);
  buf.write('WAVEfmt ', 8, 'ascii');
  buf.writeUInt32LE(16, 16);
  buf.writeUInt16LE(1, 20); // PCM
  buf.writeUInt16LE(1, 22); // Mono
  buf.writeUInt32LE(22050, 24);
  buf.writeUInt32LE(44100, 28);
  buf.writeUInt16LE(2, 32);
  buf.writeUInt16LE(16, 34);
  buf.write('data', 36, 'ascii');
  buf.writeUInt32LE(dataBytes, 40);

  const baseFreq = resolvedFrequenciesHz[0] ?? 92.5;
  for (let i = 0; i < sampleCount; i++) {
    const t = i / 22050.0;
    const sample = Math.round(Math.sin(2 * Math.PI * baseFreq * t) * 14000);
    buf.writeInt16LE(sample, 44 + i * 2);
  }

  return {
    patternId: pattern.id,
    r2ReferenceUrl: `https://r2.vhunambi.com/sketchpad-refs/${pattern.id}_loop.wav`,
    wavBase64Preview: buf.toString('base64'),
    stepDurationMs: Math.round(stepSec * 1000),
    loopDurationSec,
    resolvedFrequenciesHz,
    transientEvents: extractMelodyPatternTransients(pattern, loopDurationSec * 2),
  };
}
