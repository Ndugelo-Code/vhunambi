import { Hono } from 'hono';
import { resolveMediaUrl } from '../config/env.js';
import { MelodyPatternManifestSchema } from '../modules/melody/melody_types.js';
import {
  filterMelodyPresets,
  renderMelodyReferencePayload,
  STARTER_MELODY_PATTERNS,
} from '../modules/melody/melody_presets.js';
import { uploadBytesToR2 } from '../modules/synthesis/r2_storage.js';
import type { VhunambiWorkerEnv } from '../types/cloudflare_worker_types.js';

export const melodyRoutes = new Hono<{ Bindings: VhunambiWorkerEnv }>();

function buildDeterministicReferenceWavBytes(
  _patternId: string,
  bpm: number,
): Uint8Array {
  const numSamples = 400;
  const dataSize = numSamples * 2;
  const buffer = new ArrayBuffer(44 + dataSize);
  const view = new DataView(buffer);
  const writeAscii = (offset: number, str: string) => {
    for (let i = 0; i < str.length; i++) {
      view.setUint8(offset + i, str.charCodeAt(i));
    }
  };
  writeAscii(0, 'RIFF');
  view.setUint32(4, 36 + dataSize, true);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true); // PCM
  view.setUint16(22, 1, true); // Mono
  view.setUint32(24, 22050, true);
  view.setUint32(28, 44100, true);
  view.setUint16(32, 2, true);
  view.setUint16(34, 16, true);
  writeAscii(36, 'data');
  view.setUint32(40, dataSize, true);

  const freq = Math.max(55, Math.min(440, bpm * 1.5));
  for (let i = 0; i < numSamples; i++) {
    const sample = Math.sin((2 * Math.PI * freq * i) / 22050) * 12000;
    view.setInt16(44 + i * 2, sample, true);
  }
  return new Uint8Array(buffer);
}

/**
 * GET /v1/melodies/presets
 * Returns the 6 Iconic African Starter Melody & Log-Drum Patterns (REQ-SKP-04, REQ-SKP-12).
 */
melodyRoutes.get('/presets', (c) => {
  const genre = c.req.query('genre');
  const instrument = c.req.query('instrument');

  const presets = filterMelodyPresets({ genre, instrument });
  return c.json({
    totalCount: STARTER_MELODY_PATTERNS.length,
    filteredCount: presets.length,
    presets,
  });
});

/**
 * GET /v1/melodies/sound-packs
 * Returns the catalog of official native and expansion sound packs (Phase 32).
 */
melodyRoutes.get('/sound-packs', (c) => {
  return c.json({
    totalCount: 6,
    soundPacks: [
      {
        id: 'pack_vhunambi_core_native',
        title: 'Vhunambi Core Studio Kit',
        subtitle: '18 Native Instruments & 6 Genre Drum Racks',
        genre: 'African Heritage & Studio Universal',
        sizeMb: 0.0,
        isBundledNative: true,
        instrumentNames: [
          'Concert Grand Piano',
          'Private School Rhodes',
          'Amapiano Log Drum',
          'Nylon Guitar',
          'Bamboo Flute',
          'Soprano Sax',
          '808 Sub',
          'Amapiano Drum Kit',
        ],
        downloadUrl: '',
      },
      {
        id: 'pack_private_school_vip',
        title: 'Kabza & Kelvin Private School VIP',
        subtitle: 'Warm DX10 Log-Drums & Vintage Rhodes MK8',
        genre: 'Private School Amapiano',
        sizeMb: 14.2,
        isBundledNative: false,
        instrumentNames: [
          'VIP Log Drum (Soweto Deep)',
          'Rhodes MK8 Bell Tines',
          'Vocal Chants & Hype Stabs',
          'Kabza Shaker Matrix',
        ],
        downloadUrl: resolveMediaUrl('packs/private_school_vip.tar.gz', c),
      },
      {
        id: 'pack_grand_piano_strings',
        title: 'FL Producer Grand Piano & Strings',
        subtitle: 'Steinway D Concert Grand & Symphonic Violin Ensemble',
        genre: 'Classical & Cinematic',
        sizeMb: 16.4,
        isBundledNative: false,
        instrumentNames: [
          'Steinway Concert Grand D',
          'Symphonic Violins & Cello',
          'Warm String Pad',
        ],
        downloadUrl: resolveMediaUrl('packs/grand_piano_strings.tar.gz', c),
      },
      {
        id: 'pack_soweto_horns_flute',
        title: 'Soweto Live Sax, Flute & Jazz Horns',
        subtitle: 'Authentic South African Brass & Reed Session Recordings',
        genre: 'Afro Jazz & Soul',
        sizeMb: 12.8,
        isBundledNative: false,
        instrumentNames: [
          'Tenor Saxophone (Growl)',
          'Bamboo Flute (High)',
          'Brass Section Stabs',
        ],
        downloadUrl: resolveMediaUrl('packs/soweto_horns.tar.gz', c),
      },
      {
        id: 'pack_808_gqom_drums',
        title: '808 Trap & Durban Gqom Heavy Drums',
        subtitle: 'Distorted 808s, Warehouse Tones & Saturated Kicks',
        genre: 'Trap & Gqom',
        sizeMb: 11.5,
        isBundledNative: false,
        instrumentNames: [
          'Overdriven 808 Boom',
          'eThekwini Dark Tom',
          'Trap Hi-Hat Rolls',
        ],
        downloadUrl: resolveMediaUrl('packs/808_gqom_drums.tar.gz', c),
      },
      {
        id: 'pack_lagos_afrobeats_hitmaker',
        title: 'Lagos Afrobeats & House Hitmaker',
        subtitle: 'Punchy Afrobeats Snares, Talking Drum & 909 Groove',
        genre: 'Afrobeats & Deep House',
        sizeMb: 13.0,
        isBundledNative: false,
        instrumentNames: [
          'Lagos Talking Drum',
          'Afrobeats Rim Clack',
          'Deep House 909 Punch',
        ],
        downloadUrl: resolveMediaUrl('packs/lagos_afrobeats.tar.gz', c),
      },
    ],
  });
});

/**
 * POST /v1/melodies/render-reference
 * Validates a 16-step MelodyPatternManifest, synthesizes its WAV reference payload,
 * and returns extracted MMO transient events (`log_drum_drop` / `harmonic_turnaround`) (REQ-SKP-12).
 */
melodyRoutes.post('/render-reference', async (c) => {
  try {
    const body = await c.req.json();
    const parsed = MelodyPatternManifestSchema.safeParse(body);

    if (!parsed.success) {
      return c.json(
        { error: 'INVALID_MELODY_PATTERN', details: parsed.error.flatten() },
        400,
      );
    }

    const rendered = renderMelodyReferencePayload(parsed.data);
    const referenceId = `${rendered.patternId}_${Date.now()}`;
    const wavBytes = buildDeterministicReferenceWavBytes(
      parsed.data.id,
      parsed.data.bpm,
    );
    const r2Key = `sketchpad-refs/${referenceId}.wav`;
    const stored = await uploadBytesToR2(r2Key, wavBytes, 'audio/wav', c);

    return c.json({
      success: true,
      ...rendered,
      referenceId,
      r2ObjectKey: stored.key,
      r2ReferenceUrl: resolveMediaUrl(stored.url, c),
    });
  } catch (err) {
    return c.json(
      { error: 'MELODY_RENDER_FAILED', message: String(err) },
      500,
    );
  }
});

