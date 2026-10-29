import { getGenrePreset } from '../synthesis/constants.js';
import { getLanguageContext, MUSIC_LANGUAGES } from '../bantu/language_context.js';
import {
  SongMetadataDNA,
  LyricWordTimestamp,
  LyricWordTimestampV2,
  MasterMediaObjectManifest,
  StemRole,
  TransientEvent,
  MpcPadSliceManifest,
  SongSectionBlueprint,
} from './dna_types.js';
import { MelodyPatternManifest } from '../melody/melody_types.js';
import { extractMelodyPatternTransients } from '../melody/melody_presets.js';

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
  alignment?: LyricWordTimestampV2[] | LyricWordTimestamp[];
  seed?: number;
}

export interface CompileManifestInput extends CompileDnaInput {
  masterMp3Url?: string;
  masterWavUrl?: string;
  coverArt9x16Url?: string;
  coverArt1x1Url?: string;
  stemsZipUrl?: string;
  stemUrls?: Partial<Record<StemRole, string>>;
  provenance?: 'measured' | 'synthesized';
  melodyPattern?: MelodyPatternManifest;
}

/**
 * Helper to clamp MPC pad slice boundaries within track duration
 * and prevent boundary overruns.
 */
export function clampSliceBounds(
  rawStartSec: number,
  durationSec: number,
  trackTotalSec: number,
): { startSec: number; endSec: number } {
  const safeTotal = Math.max(4.0, trackTotalSec);
  const wrappedStart =
    rawStartSec + durationSec <= safeTotal
      ? rawStartSec
      : rawStartSec % Math.max(1.0, safeTotal - durationSec);
  const startSec = Number(Math.max(0, wrappedStart).toFixed(3));
  const endSec = Number(Math.min(safeTotal, startSec + durationSec).toFixed(3));
  return { startSec, endSec };
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
    alignment: (input.alignment as LyricWordTimestamp[]) || [],
  };
}

/**
 * Helper to compute transient envelope with 1-frame attack and exponential release
 */
function computeHitEnergy(fRel: number, k: number, aPeak = 1.0): number {
  if (fRel < 0) return 0.0;
  if (fRel === 0) return 0.65 * aPeak;
  return aPeak * Math.exp(-k * (fRel - 1));
}

/**
 * Compiles an Executable Master Media Object (MMO v2.0) Manifest.
 * Generates BPM-locked 60Hz Uint8 curves via authentic African genre beat grids,
 * discrete transient events, and an 8-pad role-stratified MPC kit.
 */
export function compileMasterMediaObjectManifest(
  input: CompileManifestInput | SongMetadataDNA,
): MasterMediaObjectManifest {
  const dna = 'musical' in input ? (input as SongMetadataDNA) : compileSongMetadataDNA(input);
  const bpm = dna.musical.bpm;
  const durationSec = dna.musical.durationSec;
  const durationMs = durationSec * 1000;
  const genreLower = dna.genre.toLowerCase();

  const isAmapiano = genreLower.includes('amapiano');
  const isGqom = genreLower.includes('gqom');

  const beatSec = 60 / bpm;
  const barSec = 4 * beatSec;
  const stepSec = barSec / 16;

  // 1. Structure sections
  const totalBars = Math.max(4, Math.floor(durationSec / barSec));
  const introBars = Math.min(8, Math.max(1, Math.floor(totalBars * 0.15)));
  const buildBars = Math.min(8, Math.max(1, Math.floor(totalBars * 0.20)));
  const dropBars = Math.max(2, Math.floor(totalBars * 0.40));
  const bridgeBars = Math.max(1, Math.floor(totalBars * 0.13));

  const sections: SongSectionBlueprint[] = [
    {
      name: 'Intro',
      startMs: 0,
      endMs: Math.round(introBars * barSec * 1000),
      barsCount: introBars,
      dominantStem: 'drums',
      visualPresetOverride: 'subtle_drift',
    },
    {
      name: 'Log Drum Build',
      startMs: Math.round(introBars * barSec * 1000),
      endMs: Math.round((introBars + buildBars) * barSec * 1000),
      barsCount: buildBars,
      dominantStem: 'melodic',
      visualPresetOverride: 'logdrum_punch',
    },
    {
      name: 'The Drop',
      startMs: Math.round((introBars + buildBars) * barSec * 1000),
      endMs: Math.round((introBars + buildBars + dropBars) * barSec * 1000),
      barsCount: dropBars,
      dominantStem: 'bass',
      visualPresetOverride: 'hyperkinetic',
    },
    {
      name: 'Bridge',
      startMs: Math.round((introBars + buildBars + dropBars) * barSec * 1000),
      endMs: Math.round((introBars + buildBars + dropBars + bridgeBars) * barSec * 1000),
      barsCount: bridgeBars,
      dominantStem: 'vocals',
      visualPresetOverride: 'subtle_drift',
    },
    {
      name: 'Outro',
      startMs: Math.round((introBars + buildBars + dropBars + bridgeBars) * barSec * 1000),
      endMs: durationMs,
      barsCount: Math.max(1, totalBars - (introBars + buildBars + dropBars + bridgeBars)),
      dominantStem: 'drums',
      visualPresetOverride: 'subtle_drift',
    },
  ];

  // 2. Compute 60 Hz Modulation Curves
  const sampleRateHz = 60;
  const frameCount = Math.max(1, Math.floor((durationMs * sampleRateHz) / 1000));
  const masterRmsBytes = new Uint8Array(frameCount);
  const vocalsBytes = new Uint8Array(frameCount);
  const drumsBytes = new Uint8Array(frameCount);
  const bassBytes = new Uint8Array(frameCount);
  const melodicBytes = new Uint8Array(frameCount);

  const alignmentV2: LyricWordTimestampV2[] = (dna.alignment || []).map((w, idx) => ({
    ...w,
    phoneticStress: (w as LyricWordTimestampV2).phoneticStress ?? (idx % 2 === 0 ? 0.75 : 0.5),
    isCulturalIdiom:
      (w as LyricWordTimestampV2).isCulturalIdiom ??
      (w.word.toLowerCase().includes('woza') ||
        w.word.toLowerCase().includes('yebo') ||
        w.word.toLowerCase().includes('shisa') ||
        w.word.toLowerCase().includes('aa') ||
        w.word.toLowerCase().includes('ndu')),
  }));

  for (let f = 0; f < frameCount; f++) {
    const t = f / sampleRateHz;
    const tMs = t * 1000;

    // Find active section
    let activeSection = sections[0].name;
    for (let s = 0; s < sections.length; s++) {
      if (tMs >= sections[s].startMs && tMs < sections[s].endMs) {
        activeSection = sections[s].name;
        break;
      }
    }
    const isTheDrop = activeSection === 'The Drop';
    const isBuild = activeSection === 'Log Drum Build';
    const isIntro = activeSection === 'Intro';
    const isBridge = activeSection === 'Bridge';

    const beatTime = t % barSec;
    const stepIndex = Math.floor(beatTime / stepSec) % 16;
    const stepOnset = stepIndex * stepSec;
    const timeSinceStep = beatTime - stepOnset;
    const fRel = Math.floor(timeSinceStep * sampleRateHz);

    // --- DRUMS ---
    let drumsPeak = 0.0;
    if (isAmapiano) {
      if (stepIndex === 0 || stepIndex === 4 || stepIndex === 8 || stepIndex === 12) {
        drumsPeak = 1.0; // 4-on-the-floor kick
      } else if (stepIndex === 4 || stepIndex === 12) {
        drumsPeak = 0.9; // Snare/clap
      } else if (isTheDrop && (stepIndex === 2 || stepIndex === 6 || stepIndex === 10 || stepIndex === 14)) {
        drumsPeak = 0.45; // Shaker syncopation
      }
    } else if (isGqom) {
      if (stepIndex === 0 || stepIndex === 3 || stepIndex === 6 || stepIndex === 10 || stepIndex === 12) {
        drumsPeak = 1.0; // Broken beat kick/tom
      }
    } else {
      if (stepIndex % 4 === 0) drumsPeak = 0.95;
    }

    const eHitDrums = drumsPeak > 0 ? computeHitEnergy(fRel, 0.48, drumsPeak) : 0.0;
    const bDrums = isTheDrop ? 0.08 : 0.02;
    drumsBytes[f] = Math.min(255, Math.max(0, Math.round(255 * (bDrums + (1 - bDrums) * eHitDrums))));

    // --- BASS (LOG DRUM) ---
    let bassPeak = 0.0;
    if (isAmapiano) {
      if (isTheDrop || isBuild) {
        // Amapiano log drum syncopation on steps 3, 6, 11, 14
        if (stepIndex === 3 || stepIndex === 6 || stepIndex === 11 || stepIndex === 14) {
          bassPeak = 1.0;
        } else if (stepIndex === 0) {
          bassPeak = 0.85;
        }
      }
    } else if (isGqom) {
      if (stepIndex === 0 || stepIndex === 3 || stepIndex === 6 || stepIndex === 10) {
        bassPeak = 0.95;
      }
    } else {
      if (stepIndex === 0 || stepIndex === 8) bassPeak = 0.8;
    }

    const eHitBass = bassPeak > 0 ? computeHitEnergy(fRel, 0.22, bassPeak) : 0.0;
    const bBass = isTheDrop ? 0.18 : isBuild ? 0.10 : 0.0;
    bassBytes[f] = Math.min(255, Math.max(0, Math.round(255 * (bBass + (1 - bBass) * eHitBass))));

    // --- MELODIC ---
    let melPeak = 0.0;
    if (stepIndex === 2 || stepIndex === 6 || stepIndex === 8 || stepIndex === 14) {
      melPeak = 0.85;
    }
    const eHitMel = melPeak > 0 ? computeHitEnergy(fRel, 0.16, melPeak) : 0.0;
    const bMel = isTheDrop ? 0.22 : isIntro || isBridge ? 0.12 : 0.16;
    melodicBytes[f] = Math.min(255, Math.max(0, Math.round(255 * (bMel + (1 - bMel) * eHitMel))));

    // --- VOCALS ---
    let vocalEnergy = 0.0;
    for (let w = 0; w < alignmentV2.length; w++) {
      const word = alignmentV2[w];
      if (t >= word.start && t <= word.end) {
        const pWord = (t - word.start) / Math.max(0.05, word.end - word.start);
        const stress = word.phoneticStress ?? 0.5;
        vocalEnergy =
          Math.pow(Math.sin(Math.PI * Math.min(1.0, Math.max(0.0, pWord))), 0.7) *
          (0.55 + 0.45 * stress);
        break;
      }
    }
    vocalsBytes[f] = Math.min(255, Math.max(0, Math.round(255 * vocalEnergy)));

    // --- MASTER RMS ---
    masterRmsBytes[f] = Math.min(
      255,
      Math.max(
        0,
        Math.round(
          0.35 * bassBytes[f] +
            0.25 * drumsBytes[f] +
            0.20 * vocalsBytes[f] +
            0.20 * melodicBytes[f],
        ),
      ),
    );
  }

  // 3. Transient Events Telemetry
  const transientEvents: TransientEvent[] = [];

  // Section change transients
  for (let s = 0; s < sections.length; s++) {
    transientEvents.push({
      timestampMs: sections[s].startMs,
      type: 'section_change',
      stem: sections[s].dominantStem,
      intensity: 0.9,
      durationMs: 240,
    });
  }

  // Bar-level beat transients
  for (let bar = 0; bar < totalBars; bar++) {
    const barTimeMs = Math.round(bar * barSec * 1000);
    if (barTimeMs >= durationMs) break;

    const isDropBar = bar >= introBars + buildBars && bar < introBars + buildBars + dropBars;

    // Kick downbeat at step 0
    transientEvents.push({
      timestampMs: barTimeMs,
      type: 'kick',
      stem: 'drums',
      intensity: 0.88,
      durationMs: 160,
    });

    // Snare/clap at step 4
    const snareTimeMs = Math.round((bar * barSec + 4 * stepSec) * 1000);
    if (snareTimeMs < durationMs) {
      transientEvents.push({
        timestampMs: snareTimeMs,
        type: 'snare_clap',
        stem: 'drums',
        intensity: 0.75,
        durationMs: 160,
      });
    }

    // Amapiano log drum drops during drop sections
    if (isDropBar && isAmapiano) {
      const dropSteps = [3, 6, 11, 14];
      for (let ds = 0; ds < dropSteps.length; ds++) {
        const logTimeMs = Math.round((bar * barSec + dropSteps[ds] * stepSec) * 1000);
        if (logTimeMs < durationMs) {
          transientEvents.push({
            timestampMs: logTimeMs,
            type: 'log_drum_drop',
            stem: 'bass',
            intensity: 0.95,
            durationMs: 220,
          });
        }
      }
    }

    // Melodic turnaround every 4 bars
    if (bar % 4 === 3) {
      const turnTimeMs = Math.round((bar * barSec + 12 * stepSec) * 1000);
      if (turnTimeMs < durationMs) {
        transientEvents.push({
          timestampMs: turnTimeMs,
          type: 'harmonic_turnaround',
          stem: 'melodic',
          intensity: 0.72,
          durationMs: 200,
        });
      }
    }
  }

  // Vocal onset transients
  for (let w = 0; w < alignmentV2.length; w++) {
    transientEvents.push({
      timestampMs: Math.round(alignmentV2[w].start * 1000),
      type: 'vocal_onset',
      stem: 'vocals',
      intensity: 0.8,
      durationMs: 200,
    });
  }

  // Phase 27: Merge custom Melody & Log-Drum Sketchpad transients into MMO modulationBus
  const maybeMelodyPattern = (input as CompileManifestInput).melodyPattern;
  if (maybeMelodyPattern) {
    const sketchpadTransients = extractMelodyPatternTransients(
      maybeMelodyPattern,
      durationSec,
    );
    transientEvents.push(...sketchpadTransients);
  }

  transientEvents.sort((a, b) => a.timestampMs - b.timestampMs);

  // 4. Role-Stratified 8-Pad MPC Kit
  const idiomWord = alignmentV2.find((w) => w.isCulturalIdiom);
  const firstWord = alignmentV2[0];

  const mpcKitPads: MpcPadSliceManifest[] = [
    // Pad 0: Kick Downbeat (drums, Bar 1 Beat 1)
    {
      padIndex: 0,
      label: 'Kick Downbeat',
      sourceStem: 'drums',
      ...clampSliceBounds(0.0 * barSec, 1 * beatSec, durationSec),
      peakIntensity: 0.92,
      recommendedSemitoneShift: 0,
    },
    // Pad 1: Syncopated Clap (drums, Bar 2 Beat 2)
    {
      padIndex: 1,
      label: 'Syncopated Clap',
      sourceStem: 'drums',
      ...clampSliceBounds(1.0 * barSec + 1.0 * beatSec, 2 * beatSec, durationSec),
      peakIntensity: 0.82,
      recommendedSemitoneShift: 0,
    },
    // Pad 2: Log Drum Drop (bass, Bar 16 Beat 1)
    {
      padIndex: 2,
      label: 'Log Drum Drop',
      sourceStem: 'bass',
      ...clampSliceBounds(15.0 * barSec, 2 * beatSec, durationSec),
      peakIntensity: 0.98,
      recommendedSemitoneShift: 0,
    },
    // Pad 3: Sub-Bass Glide (bass, Bar 16 Beat 3)
    {
      padIndex: 3,
      label: 'Sub-Bass Glide',
      sourceStem: 'bass',
      ...clampSliceBounds(15.0 * barSec + 2.0 * beatSec, 4 * beatSec, durationSec),
      peakIntensity: 0.88,
      recommendedSemitoneShift: -2,
    },
    // Pad 4: Guitar Turnaround (melodic, Bar 9 Beat 1)
    {
      padIndex: 4,
      label: 'Guitar Turnaround',
      sourceStem: 'melodic',
      ...clampSliceBounds(8.0 * barSec, 4 * beatSec, durationSec),
      peakIntensity: 0.78,
      recommendedSemitoneShift: 0,
    },
    // Pad 5: Harmonic Stab (melodic, Bar 12 Beat 1)
    {
      padIndex: 5,
      label: 'Harmonic Stab',
      sourceStem: 'melodic',
      ...clampSliceBounds(11.0 * barSec, 2 * beatSec, durationSec),
      peakIntensity: 0.84,
      recommendedSemitoneShift: 0,
    },
    // Pad 6: Vocal Chant Hook (vocals, first word or Bar 17 Beat 1)
    {
      padIndex: 6,
      label: 'Vocal Chant Hook',
      sourceStem: 'vocals',
      ...clampSliceBounds(firstWord ? firstWord.start : 16.0 * barSec, 4 * beatSec, durationSec),
      peakIntensity: 0.9,
      recommendedSemitoneShift: 0,
    },
    // Pad 7: Bantu Idiom Ad-Lib (vocals, idiom word or Bar 18 Beat 3)
    {
      padIndex: 7,
      label: 'Bantu Idiom Ad-Lib',
      sourceStem: 'vocals',
      ...clampSliceBounds(
        idiomWord ? idiomWord.start : 17.0 * barSec + 2.0 * beatSec,
        2 * beatSec,
        durationSec,
      ),
      peakIntensity: 0.95,
      recommendedSemitoneShift: 0,
    },
  ];

  // 5. Assets Map
  const manifestInput = input as CompileManifestInput;
  const trackId = dna.id;
  const masterMp3Url =
    manifestInput.masterMp3Url || `/mock-storage/${trackId}_master.mp3`;
  const coverArt9x16Url =
    manifestInput.coverArt9x16Url || `https://assets.vhunambi.com/covers/${trackId}_9x16.jpg`;

  const stemUrls: Record<StemRole, string> = {
    vocals: manifestInput.stemUrls?.vocals || `/mock-storage/${trackId}_vocals.mp3`,
    drums: manifestInput.stemUrls?.drums || `/mock-storage/${trackId}_drums.mp3`,
    bass: manifestInput.stemUrls?.bass || `/mock-storage/${trackId}_bass.mp3`,
    melodic: manifestInput.stemUrls?.melodic || `/mock-storage/${trackId}_melodic.mp3`,
  };

  return {
    id: dna.id,
    title: dna.title,
    genre: dna.genre,
    language: dna.language,
    culturalContext: dna.culturalContext,
    musical: dna.musical,
    vocals: dna.vocals,
    visualTheme: dna.visualTheme,
    alignment: alignmentV2,

    schemaVersion: '2.0',
    provenance: manifestInput.provenance || 'synthesized',

    assets: {
      masterMp3Url,
      masterWavUrl: manifestInput.masterWavUrl,
      coverArt9x16Url,
      coverArt1x1Url: manifestInput.coverArt1x1Url,
      stemsZipUrl: manifestInput.stemsZipUrl,
      stemUrls,
    },

    modulationBus: {
      sampleRateHz,
      durationMs,
      frameCount,
      encodedCurvesBase64: {
        masterRms: Buffer.from(masterRmsBytes).toString('base64'),
        vocals: Buffer.from(vocalsBytes).toString('base64'),
        drums: Buffer.from(drumsBytes).toString('base64'),
        bass: Buffer.from(bassBytes).toString('base64'),
        melodic: Buffer.from(melodicBytes).toString('base64'),
      },
      transientEvents,
    },

    mpcKitPads,
    structure: {
      sections,
    },
  };
}

