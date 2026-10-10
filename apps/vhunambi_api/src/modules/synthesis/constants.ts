/**
 * African Regional Music Genres & Synthesis Parameters
 */

export interface GenreSynthesisSpec {
  bpmRange: [number, number];
  defaultBpm: number;
  defaultKey: string;
  defaultMood: string;
  instruments: string[];
  characteristicStyle: string;
}

export const GENRE_PRESETS: Record<string, GenreSynthesisSpec> = {
  amapiano: {
    bpmRange: [108, 116],
    defaultBpm: 112,
    defaultKey: 'A minor',
    defaultMood: 'euphoric',
    instruments: ['log_drum', 'shakers', 'jazzy_piano_stabs', 'deep_sub_bass'],
    characteristicStyle: 'Private School Amapiano, warm syncopated shakers, iconic bouncy log drum, lush electric piano Rhodes chords',
  },
  maskandi: {
    bpmRange: [120, 138],
    defaultBpm: 128,
    defaultKey: 'D minor',
    defaultMood: 'energetic',
    instruments: ['acoustic_guitar_picking', 'concertina', 'bass_guitar', 'hand_claps'],
    characteristicStyle: 'Fast fingerpicked acoustic guitar intro (izihlabo), rhythmic concertina, energetic percussive footwork',
  },
  gqom: {
    bpmRange: [124, 130],
    defaultBpm: 128,
    defaultKey: 'F minor',
    defaultMood: 'intense',
    instruments: ['heavy_distorted_sub', 'raw_kick', 'syncopated_woodblocks', 'dark_drones'],
    characteristicStyle: 'Raw Durban minimal club energy, aggressive syncopated broken beat kick, dark hypnotic tension',
  },
  gospel: {
    bpmRange: [90, 125],
    defaultBpm: 105,
    defaultKey: 'C major',
    defaultMood: 'uplifting',
    instruments: ['organ', 'grand_piano', 'brass_section', 'drum_kit', 'choral_choir'],
    characteristicStyle: 'South African Afro-Gospel praise, uplifting Hammond organ runs, brass fanfares, mass choral harmonies',
  },
  kwaito: {
    bpmRange: [95, 105],
    defaultBpm: 100,
    defaultKey: 'G minor',
    defaultMood: 'relaxed',
    instruments: ['slow_house_kick', 'deep_sub', 'snare_clap', 'synths'],
    characteristicStyle: 'Slowed 90s house tempo, conversational call-and-response, heavy township bounce',
  },
  afrohouse: {
    bpmRange: [120, 126],
    defaultBpm: 123,
    defaultKey: 'E minor',
    defaultMood: 'spiritual',
    instruments: ['tribal_percussion', 'congas', 'djembe', 'synth_pads'],
    characteristicStyle: 'Deep ancestral afro house, rolling congas, spiritual synthesizer pads, progressive percussive build',
  },
};

export function getGenrePreset(genre: string): GenreSynthesisSpec {
  const key = genre.toLowerCase().replace(/[^a-z]/g, '');
  return GENRE_PRESETS[key] || GENRE_PRESETS['amapiano'];
}
