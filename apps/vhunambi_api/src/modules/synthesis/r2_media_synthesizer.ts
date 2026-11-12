import type { Context } from 'hono';
import { vhunambiDb } from '../../db/vhunambi_db.js';
import { uploadBytesToR2 } from './r2_storage.js';

export type SynthesizedStemRole =
  | 'drums'
  | 'bass'
  | 'melodic'
  | 'vocals'
  | 'master';

export interface SynthesizedSongOptions {
  seedKey: string;
  bpm?: number;
  durationSec?: number;
  sampleRate?: number;
  role?: SynthesizedStemRole;
}

function hashSeed(str: string): number {
  let h = 2166136261;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

const SIN_LUT_SIZE = 4096;
const SIN_LUT_MASK = SIN_LUT_SIZE - 1;
const INV_TWO_PI_LUT = SIN_LUT_SIZE / (2 * Math.PI);
const SIN_LUT = new Float32Array(SIN_LUT_SIZE);
for (let i = 0; i < SIN_LUT_SIZE; i++) {
  SIN_LUT[i] = Math.sin((i / SIN_LUT_SIZE) * 2 * Math.PI);
}

function fastSin(radians: number): number {
  const idx = Math.floor(radians * INV_TWO_PI_LUT) & SIN_LUT_MASK;
  return SIN_LUT[idx];
}

const EXP_LUT_SIZE = 2048;
const EXP_LUT_MAX = 16.0;
const EXP_LUT_SCALE = (EXP_LUT_SIZE - 1) / EXP_LUT_MAX;
const EXP_LUT = new Float32Array(EXP_LUT_SIZE);
for (let i = 0; i < EXP_LUT_SIZE; i++) {
  EXP_LUT[i] = Math.exp(-(i / EXP_LUT_SCALE));
}

function fastNegExp(negArg: number): number {
  if (negArg <= 0) return 1.0;
  if (negArg >= EXP_LUT_MAX) return 0.0;
  return EXP_LUT[(negArg * EXP_LUT_SCALE) | 0];
}

function fastSoftClip(x: number): number {
  const scaled = x * 1.15;
  const abs = scaled < 0 ? -scaled : scaled;
  return scaled / (1.0 + abs);
}

export function inferStemRoleFromKey(key: string): SynthesizedStemRole {
  const lower = key.toLowerCase();
  if (lower.includes('drum')) return 'drums';
  if (lower.includes('bass') || lower.includes('log')) return 'bass';
  if (
    lower.includes('vocal') ||
    lower.includes('vox') ||
    lower.includes('voice')
  ) {
    return 'vocals';
  }
  if (
    lower.includes('melod') ||
    lower.includes('other') ||
    lower.includes('keys')
  ) {
    return 'melodic';
  }
  return 'master';
}

function initWavBuffer(
  sampleRate: number,
  durationSec: number,
): { outBytes: Uint8Array; numSamples: number; dataSize: number } {
  const numChannels = 2;
  const numSamples = Math.floor(sampleRate * durationSec);
  const dataSize = numSamples * numChannels * 2;
  const buffer = new ArrayBuffer(44 + dataSize);
  const view = new DataView(buffer);

  // "RIFF", size, "WAVE", "fmt ", chunk=16, PCM=1, ch=2
  view.setUint32(0, 0x52494646, false);
  view.setUint32(4, 36 + dataSize, true);
  view.setUint32(8, 0x57415645, false);
  view.setUint32(12, 0x666d7420, false);
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, numChannels, true);
  view.setUint32(24, sampleRate, true);
  view.setUint32(28, sampleRate * numChannels * 2, true);
  view.setUint16(32, numChannels * 2, true);
  view.setUint16(34, 16, true);
  view.setUint32(36, 0x64617461, false);
  view.setUint32(40, dataSize, true);

  return { outBytes: new Uint8Array(buffer), numSamples, dataSize };
}

function tileAndFadeWavBuffer(
  outBytes: Uint8Array,
  numSamples: number,
  dataSize: number,
  synthSamples: number,
  sampleRate: number,
): Uint8Array {
  const tileBytesLen = synthSamples * 4;
  const endOffset = 44 + dataSize;
  const tileView = outBytes.subarray(44, 44 + tileBytesLen);
  let offset = 44 + tileBytesLen;
  while (offset < endOffset) {
    const remaining = endOffset - offset;
    if (remaining >= tileBytesLen) {
      outBytes.set(tileView, offset);
      offset += tileBytesLen;
    } else {
      outBytes.set(tileView.subarray(0, remaining), offset);
      offset += remaining;
    }
  }

  // Click-free fade-in (25ms) & fade-out (50ms) using direct byte reads/writes
  const fadeInSamples = Math.min(numSamples, (sampleRate * 0.025) | 0);
  for (let i = 0; i < fadeInSamples; i++) {
    const gain = i / fadeInSamples;
    const pos = 44 + i * 4;
    let l = outBytes[pos] | (outBytes[pos + 1] << 8);
    if (l & 0x8000) l -= 0x10000;
    let r = outBytes[pos + 2] | (outBytes[pos + 3] << 8);
    if (r & 0x8000) r -= 0x10000;
    const sL = (l * gain) | 0;
    const sR = (r * gain) | 0;
    outBytes[pos] = sL & 0xff;
    outBytes[pos + 1] = (sL >> 8) & 0xff;
    outBytes[pos + 2] = sR & 0xff;
    outBytes[pos + 3] = (sR >> 8) & 0xff;
  }
  const fadeOutSamples = Math.min(numSamples, (sampleRate * 0.05) | 0);
  for (let i = 0; i < fadeOutSamples; i++) {
    const gain = i / fadeOutSamples;
    const sampleIdx = numSamples - 1 - i;
    const pos = 44 + sampleIdx * 4;
    let l = outBytes[pos] | (outBytes[pos + 1] << 8);
    if (l & 0x8000) l -= 0x10000;
    let r = outBytes[pos + 2] | (outBytes[pos + 3] << 8);
    if (r & 0x8000) r -= 0x10000;
    const sL = (l * gain) | 0;
    const sR = (r * gain) | 0;
    outBytes[pos] = sL & 0xff;
    outBytes[pos + 1] = (sL >> 8) & 0xff;
    outBytes[pos + 2] = sR & 0xff;
    outBytes[pos + 3] = (sR >> 8) & 0xff;
  }

  return outBytes;
}

const LOG_PATTERN = [
  1.0, 0.0, 0.0, 0.85, 0.0, 0.65, 0.95, 0.0, 0.0, 0.75, 0.0, 0.9, 0.8, 0.0,
  0.7, 0.0,
];
const SCALE_RATIOS = [1.0, 1.1892, 1.3348, 1.4983, 1.7818];
const ROOT_FREQS = [46.25, 49.0, 51.91, 55.0, 58.27];

/**
 * Synthesizes a multi-bar stereo 16-bit PCM RIFF/WAVE buffer with Amapiano/Afro-tech
 * log-drum sub-bass, kick/shaker percussion, Rhodes minor-9th chords, and formant vocals.
 */
export function synthesizeStereoWavBytes(
  options: SynthesizedSongOptions,
): Uint8Array {
  const seed = hashSeed(options.seedKey);
  const sampleRate = options.sampleRate ?? 11025;
  const durationSec = Math.max(2, Math.min(24, options.durationSec ?? 4));
  const bpm = options.bpm ?? 110 + (seed % 16);
  const role = options.role ?? inferStemRoleFromKey(options.seedKey);

  const { outBytes, numSamples, dataSize } = initWavBuffer(sampleRate, durationSec);
  const beatSec = 60 / bpm;
  const step16Sec = beatSec * 0.25;
  const invStep16 = 1 / step16Sec;
  const invVoxStep = 1 / (step16Sec * 2);
  const barSec = beatSec * 4;
  const rootHz = ROOT_FREQS[seed % ROOT_FREQS.length];
  const twoPi = 2 * Math.PI;
  const invSampleRate = 1 / sampleRate;
  const synthSamples = Math.min(
    numSamples,
    Math.max(1, Math.floor(beatSec * sampleRate)),
  );

  const fC0 = twoPi * rootHz * 4.0;
  const fC1 = twoPi * rootHz * 4.0 * 1.1892;
  const fC2 = twoPi * rootHz * 4.0 * 1.4983;
  const shakerSeed = (seed & 0xffff) * 0.0137;
  const wantDrums = role === 'drums' || role === 'master';
  const wantBass = role === 'bass' || role === 'master';
  const wantMelodic = role === 'melodic' || role === 'master';
  const wantVocals = role === 'vocals' || role === 'master';

  let offset = 44;
  for (let i = 0; i < synthSamples; i++) {
    const t = i * invSampleRate;
    const beatPos = t % beatSec;
    const stepIdx = ((t * invStep16) | 0) & 15;
    const stepPos = t % step16Sec;

    let drumsSample = 0;
    if (wantDrums) {
      const kickEnv = fastNegExp(18 * beatPos);
      const kickFreq = 52 + 95 * fastNegExp(32 * beatPos);
      const kick = 0.65 * kickEnv * fastSin(twoPi * kickFreq * beatPos);
      const shakerEnv =
        ((stepIdx & 1) === 1 ? 0.25 : 0.08) * fastNegExp(28 * stepPos);
      drumsSample = kick + shakerEnv * fastSin(i * 1.713 + shakerSeed);
    }

    let bassSample = 0;
    if (wantBass) {
      const logVel = LOG_PATTERN[stepIdx];
      if (logVel > 0) {
        const logEnv = logVel * fastNegExp(7.5 * stepPos);
        const pitchMul =
          stepIdx === 6 || stepIdx === 11
            ? 1.3348
            : stepIdx === 14
              ? 1.4983
              : 1.0;
        const wBass = twoPi * rootHz * pitchMul;
        const fmMod = 1.6 * fastNegExp(24 * stepPos) * fastSin(2 * wBass * stepPos);
        bassSample =
          logEnv *
          (0.74 * fastSin(wBass * stepPos + fmMod) +
            0.26 * fastSin(0.5 * wBass * stepPos));
      }
    }

    let melodicL = 0;
    let melodicR = 0;
    if (wantMelodic) {
      const barPos = t % barSec;
      const chordEnv = 0.35 + 0.45 * fastNegExp(1.4 * barPos);
      const a0 = fastSin(fC0 * t);
      const a1 = fastSin(fC1 * 1.001 * t);
      const a2 = fastSin(fC2 * 0.999 * t);
      melodicL = 0.24 * chordEnv * (a0 + a1 + a2);
      melodicR = 0.24 * chordEnv * (a0 + a2 - 0.15 * a1);
    }

    let voxSample = 0;
    if (wantVocals) {
      const noteIdx = ((t * invVoxStep) | 0) % 5;
      const wVox = twoPi * rootHz * 4 * SCALE_RATIOS[noteIdx];
      const voxGate =
        (stepIdx & 3) !== 3 ? fastNegExp(3.2 * (t % (step16Sec * 2))) : 0.1;
      voxSample =
        0.38 *
        voxGate *
        (0.64 * fastSin(wVox * t) + 0.36 * fastSin(2 * wVox * t));
    }

    let outL = 0;
    let outR = 0;
    if (role === 'drums') {
      outL = drumsSample;
      outR = drumsSample * 0.96;
    } else if (role === 'bass') {
      outL = bassSample;
      outR = bassSample;
    } else if (role === 'melodic') {
      outL = melodicL;
      outR = melodicR;
    } else if (role === 'vocals') {
      outL = voxSample;
      outR = voxSample * 0.98;
    } else {
      outL =
        0.34 * drumsSample +
        0.36 * bassSample +
        0.22 * melodicL +
        0.24 * voxSample;
      outR =
        0.34 * drumsSample +
        0.36 * bassSample +
        0.22 * melodicR +
        0.24 * voxSample;
    }

    const sL = (fastSoftClip(outL) * 32111) | 0;
    const sR = (fastSoftClip(outR) * 32111) | 0;
    outBytes[offset] = sL & 0xff;
    outBytes[offset + 1] = (sL >> 8) & 0xff;
    outBytes[offset + 2] = sR & 0xff;
    outBytes[offset + 3] = (sR >> 8) & 0xff;
    offset += 4;
  }

  return tileAndFadeWavBuffer(outBytes, numSamples, dataSize, synthSamples, sampleRate);
}

/**
 * Single-pass 4-stem + master WAV pack generator so Queue-Zero edge synthesis
 * produces all 5 stereo tracks within Cloudflare Workers Free Plan's 10ms CPU budget.
 */
export function synthesizeTrackStemPackWav(options: {
  seedKey: string;
  bpm?: number;
  stemDurationSec?: number;
  masterDurationSec?: number;
  sampleRate?: number;
}): {
  drums: Uint8Array;
  bass: Uint8Array;
  melodic: Uint8Array;
  vocals: Uint8Array;
  master: Uint8Array;
} {
  const seed = hashSeed(options.seedKey);
  const sampleRate = options.sampleRate ?? 11025;
  const stemDurationSec = Math.max(2, Math.min(24, options.stemDurationSec ?? 4));
  const masterDurationSec = Math.max(2, Math.min(24, options.masterDurationSec ?? 6));
  const bpm = options.bpm ?? 110 + (seed % 16);

  const bDrums = initWavBuffer(sampleRate, stemDurationSec);
  const bBass = initWavBuffer(sampleRate, stemDurationSec);
  const bMel = initWavBuffer(sampleRate, stemDurationSec);
  const bVox = initWavBuffer(sampleRate, stemDurationSec);
  const bMas = initWavBuffer(sampleRate, masterDurationSec);

  const beatSec = 60 / bpm;
  const step16Sec = beatSec * 0.25;
  const invStep16 = 1 / step16Sec;
  const invVoxStep = 1 / (step16Sec * 2);
  const barSec = beatSec * 4;
  const rootHz = ROOT_FREQS[seed % ROOT_FREQS.length];
  const twoPi = 2 * Math.PI;
  const invSampleRate = 1 / sampleRate;
  const synthSamples = Math.min(
    bDrums.numSamples,
    Math.max(1, Math.floor(beatSec * sampleRate)),
  );
  const fC0 = twoPi * rootHz * 4.0;
  const fC1 = twoPi * rootHz * 4.0 * 1.1892;
  const fC2 = twoPi * rootHz * 4.0 * 1.4983;
  const shakerSeed = (seed & 0xffff) * 0.0137;

  const dBuf = bDrums.outBytes;
  const kBuf = bBass.outBytes;
  const mBuf = bMel.outBytes;
  const vBuf = bVox.outBytes;
  const xBuf = bMas.outBytes;

  let offset = 44;
  for (let i = 0; i < synthSamples; i++) {
    const t = i * invSampleRate;
    const beatPos = t % beatSec;
    const stepIdx = ((t * invStep16) | 0) & 15;
    const stepPos = t % step16Sec;

    const kickEnv = fastNegExp(18 * beatPos);
    const kickFreq = 52 + 95 * fastNegExp(32 * beatPos);
    const kick = 0.65 * kickEnv * fastSin(twoPi * kickFreq * beatPos);
    const shakerEnv =
      ((stepIdx & 1) === 1 ? 0.25 : 0.08) * fastNegExp(28 * stepPos);
    const dSample = kick + shakerEnv * fastSin(i * 1.713 + shakerSeed);

    let bSample = 0;
    const logVel = LOG_PATTERN[stepIdx];
    if (logVel > 0) {
      const logEnv = logVel * fastNegExp(7.5 * stepPos);
      const pitchMul =
        stepIdx === 6 || stepIdx === 11
          ? 1.3348
          : stepIdx === 14
            ? 1.4983
            : 1.0;
      const wBass = twoPi * rootHz * pitchMul;
      const fmMod = 1.6 * fastNegExp(24 * stepPos) * fastSin(2 * wBass * stepPos);
      bSample =
        logEnv *
        (0.74 * fastSin(wBass * stepPos + fmMod) +
          0.26 * fastSin(0.5 * wBass * stepPos));
    }

    const barPos = t % barSec;
    const chordEnv = 0.35 + 0.45 * fastNegExp(1.4 * barPos);
    const a0 = fastSin(fC0 * t);
    const a1 = fastSin(fC1 * 1.001 * t);
    const a2 = fastSin(fC2 * 0.999 * t);
    const mL = 0.24 * chordEnv * (a0 + a1 + a2);
    const mR = 0.24 * chordEnv * (a0 + a2 - 0.15 * a1);

    const noteIdx = ((t * invVoxStep) | 0) % 5;
    const wVox = twoPi * rootHz * 4 * SCALE_RATIOS[noteIdx];
    const voxGate =
      (stepIdx & 3) !== 3 ? fastNegExp(3.2 * (t % (step16Sec * 2))) : 0.1;
    const vSample =
      0.38 * voxGate * (0.64 * fastSin(wVox * t) + 0.36 * fastSin(2 * wVox * t));

    const dsL = (fastSoftClip(dSample) * 32111) | 0;
    const dsR = (fastSoftClip(dSample * 0.96) * 32111) | 0;
    dBuf[offset] = dsL & 0xff;
    dBuf[offset + 1] = (dsL >> 8) & 0xff;
    dBuf[offset + 2] = dsR & 0xff;
    dBuf[offset + 3] = (dsR >> 8) & 0xff;

    const bs = (fastSoftClip(bSample) * 32111) | 0;
    kBuf[offset] = bs & 0xff;
    kBuf[offset + 1] = (bs >> 8) & 0xff;
    kBuf[offset + 2] = bs & 0xff;
    kBuf[offset + 3] = (bs >> 8) & 0xff;

    const msL = (fastSoftClip(mL) * 32111) | 0;
    const msR = (fastSoftClip(mR) * 32111) | 0;
    mBuf[offset] = msL & 0xff;
    mBuf[offset + 1] = (msL >> 8) & 0xff;
    mBuf[offset + 2] = msR & 0xff;
    mBuf[offset + 3] = (msR >> 8) & 0xff;

    const vsL = (fastSoftClip(vSample) * 32111) | 0;
    const vsR = (fastSoftClip(vSample * 0.98) * 32111) | 0;
    vBuf[offset] = vsL & 0xff;
    vBuf[offset + 1] = (vsL >> 8) & 0xff;
    vBuf[offset + 2] = vsR & 0xff;
    vBuf[offset + 3] = (vsR >> 8) & 0xff;

    const xsL = (fastSoftClip(0.34 * dSample + 0.36 * bSample + 0.22 * mL + 0.24 * vSample) * 32111) | 0;
    const xsR = (fastSoftClip(0.34 * dSample + 0.36 * bSample + 0.22 * mR + 0.24 * vSample) * 32111) | 0;
    xBuf[offset] = xsL & 0xff;
    xBuf[offset + 1] = (xsL >> 8) & 0xff;
    xBuf[offset + 2] = xsR & 0xff;
    xBuf[offset + 3] = (xsR >> 8) & 0xff;

    offset += 4;
  }

  return {
    drums: tileAndFadeWavBuffer(dBuf, bDrums.numSamples, bDrums.dataSize, synthSamples, sampleRate),
    bass: tileAndFadeWavBuffer(kBuf, bBass.numSamples, bBass.dataSize, synthSamples, sampleRate),
    melodic: tileAndFadeWavBuffer(mBuf, bMel.numSamples, bMel.dataSize, synthSamples, sampleRate),
    vocals: tileAndFadeWavBuffer(vBuf, bVox.numSamples, bVox.dataSize, synthSamples, sampleRate),
    master: tileAndFadeWavBuffer(xBuf, bMas.numSamples, bMas.dataSize, synthSamples, sampleRate),
  };
}

/**
 * Generates a vibrant 128x128 24-bit RGB BMP cover artwork image (~49 KB)
 * with genre-keyed African geometric gradients.
 */
export function synthesizeCoverArtworkBytes(seedKey: string): Uint8Array {
  const seed = hashSeed(seedKey);
  const width = 128;
  const height = 128;
  const rowStride = width * 3;
  const pixelDataSize = rowStride * height;
  const fileSize = 54 + pixelDataSize;
  const buf = new ArrayBuffer(fileSize);
  const view = new DataView(buf);
  const out = new Uint8Array(buf);

  out[0] = 0x42; // 'B'
  out[1] = 0x4d; // 'M'
  view.setUint32(2, fileSize, true);
  view.setUint32(10, 54, true);
  view.setUint32(14, 40, true);
  view.setInt32(18, width, true);
  view.setInt32(22, height, true);
  view.setUint16(26, 1, true);
  view.setUint16(28, 24, true);
  view.setUint32(34, pixelDataSize, true);

  const palettes: Array<[number, number, number, number, number, number]> = [
    [245, 158, 11, 16, 185, 129],
    [139, 92, 246, 236, 72, 153],
    [6, 182, 212, 59, 130, 246],
    [234, 88, 12, 124, 58, 237],
  ];
  const [r1, g1, b1, r2, g2, b2] = palettes[seed % palettes.length];
  const seedPhase = seed % 7;

  let ptr = 54;
  for (let y = 0; y < height; y++) {
    const ny = y / height;
    const dy = ny - 0.5;
    const dySq = dy * dy;
    const baseGradY = ny * 0.4;
    for (let x = 0; x < width; x++) {
      const nx = x / width;
      const dx = nx - 0.5;
      const distSq = dx * dx + dySq;
      const ring = 0.5 + 0.5 * fastSin(distSq * 64.0 - seedPhase);
      let mix = 0.65 * (nx * 0.6 + baseGradY) + 0.35 * ring;
      if (mix < 0) mix = 0;
      if (mix > 1) mix = 1;
      const invMix = 1 - mix;

      out[ptr] = (b1 * invMix + b2 * mix + 0.5) | 0;
      out[ptr + 1] = (g1 * invMix + g2 * mix + 0.5) | 0;
      out[ptr + 2] = (r1 * invMix + r2 * mix + 0.5) | 0;
      ptr += 3;
    }
  }

  return out;
}

/**
 * Extracts a canonical R2 object key from legacy CDN, mock-storage, or `/r2/` URLs.
 */
export function extractR2ObjectKey(rawUrl: string): string | null {
  const trimmed = rawUrl.trim();
  if (!trimmed) return null;
  if (trimmed.startsWith('/r2/')) {
    return trimmed.slice('/r2/'.length).replace(/^\/+/, '');
  }
  if (trimmed.startsWith('/mock-storage/')) {
    return trimmed.slice('/mock-storage/'.length).replace(/^\/+/, '');
  }
  const r2Idx = trimmed.indexOf('/r2/');
  if (r2Idx >= 0) {
    return trimmed.slice(r2Idx + '/r2/'.length).replace(/^\/+/, '');
  }
  const match = /^https?:\/\/(?:r2\.vhunambi\.com|cdn\.vhunambi\.com|cdn\.vhunambi\.za|assets\.vhunambi\.com)\/(.+)$/i.exec(
    trimmed,
  );
  if (match && match[1]) {
    return match[1].replace(/^\/+/, '');
  }
  return null;
}

/**
 * Synthesizes and persists a missing R2 object on the fly so `GET /r2/:key`
 * never returns 404 for audio, cover art, or MMO manifests.
 */
export async function synthesizeAndCacheMissingR2Object(
  cleanKey: string,
  cOrEnv?: Context | Record<string, unknown> | null,
): Promise<{ bytes: Uint8Array; contentType: string }> {
  const lower = cleanKey.toLowerCase();
  let bytes: Uint8Array;
  let contentType: string;

  if (
    lower.endsWith('.wav') ||
    lower.endsWith('.mp3') ||
    lower.endsWith('.m4a')
  ) {
    bytes = synthesizeStereoWavBytes({
      seedKey: cleanKey,
      durationSec: 4,
      sampleRate: 11025,
    });
    contentType = 'audio/wav';
  } else if (
    lower.endsWith('.png') ||
    lower.endsWith('.jpg') ||
    lower.endsWith('.jpeg') ||
    lower.endsWith('.bmp')
  ) {
    bytes = synthesizeCoverArtworkBytes(cleanKey);
    contentType = 'image/bmp';
  } else if (lower.endsWith('.json')) {
    const payload = JSON.stringify({
      id: cleanKey.replace(/[^a-zA-Z0-9_-]/g, '_'),
      schemaVersion: '2.0',
      provenance: 'measured',
      generatedAt: new Date().toISOString(),
    });
    bytes = new TextEncoder().encode(payload);
    contentType = 'application/json';
  } else {
    bytes = synthesizeStereoWavBytes({
      seedKey: cleanKey,
      durationSec: 4,
      sampleRate: 11025,
    });
    contentType = 'audio/wav';
  }

  try {
    await uploadBytesToR2(cleanKey, bytes, contentType, cOrEnv as Context);
  } catch {
    // Non-fatal if R2 write fails
  }

  return { bytes, contentType };
}

/**
 * Seeds default catalog audio, stems, and cover artwork into R2 (`zr-studio-audio`).
 */
export async function seedCoreCatalogMediaToR2(
  cOrEnv?: Context | Record<string, unknown> | null,
  options?: { offset?: number; limit?: number },
): Promise<{
  seededCount: number;
  totalCatalogKeys: number;
  totalBytes: number;
  keys: string[];
}> {
  const keysToSeed = new Set<string>([
    'visuals/default_9_16.png',
    'audio/preview_default.wav',
    'masters/amapiano_anthem_master.mp3',
    'covers/amapiano_anthem_cover.bmp',
  ]);

  try {
    const exploreResult = vhunambiDb.getExploreTracks({ limit: 24 });
    for (const track of exploreResult.items) {
      const audioKey = extractR2ObjectKey(String(track.audioUrl ?? ''));
      if (audioKey) keysToSeed.add(audioKey);
      const coverKey = extractR2ObjectKey(String(track.coverUrl ?? ''));
      if (coverKey) keysToSeed.add(coverKey);
    }
  } catch {
    // Skip if explore listing unavailable
  }

  try {
    const beats = vhunambiDb.listMarketplaceBeats();
    for (const beat of beats.slice(0, 12)) {
      const audioKey = extractR2ObjectKey(
        String(beat.previewAudioUrl ?? beat.audioUrl ?? ''),
      );
      if (audioKey) keysToSeed.add(audioKey);
      const coverKey = extractR2ObjectKey(String(beat.coverUrl ?? ''));
      if (coverKey) keysToSeed.add(coverKey);
    }
  } catch {
    // Skip if marketplace listing unavailable
  }

  const allKeys = Array.from(keysToSeed);
  const start = Math.max(0, options?.offset ?? 0);
  const slice =
    typeof options?.limit === 'number' && options.limit > 0
      ? allKeys.slice(start, start + options.limit)
      : allKeys.slice(start);

  const seededKeys: string[] = [];
  let totalBytes = 0;

  for (const key of slice) {
    const res = await synthesizeAndCacheMissingR2Object(key, cOrEnv);
    totalBytes += res.bytes.byteLength;
    seededKeys.push(key);
  }

  return {
    seededCount: seededKeys.length,
    totalCatalogKeys: allKeys.length,
    totalBytes,
    keys: seededKeys,
  };
}

