/**
 * VHUNAMBI Phase 84 — Pure Edge ID3v2.3 / ID3v2.4 Metadata & APIC Cover Extractor
 *
 * Uses exclusively Uint8Array, DataView, and TextDecoder (zero Node fs/Buffer)
 * so it runs natively inside Cloudflare Workers isolates.
 */

export type SupportedCoverMime = 'image/jpeg' | 'image/png' | 'image/webp';

export interface ApicExtraction {
  imageData: Uint8Array;
  mimeType: SupportedCoverMime;
  ext: 'jpg' | 'png' | 'webp';
}

export interface Id3v2MetadataResult {
  version: 3 | 4;
  tagByteLength: number;
  title?: string;
  artist?: string;
  album?: string;
  genre?: string;
  bpm?: number;
  lyrics?: string;
  apic: ApicExtraction | null;
}

export const ID3_INITIAL_RANGE_BYTES = 262_144; // 256 KiB
export const ID3_MAX_RANGE_BYTES = 2_097_152; // 2 MiB hard isolate cap

function readSynchSafeInt(data: Uint8Array, offset: number): number {
  return (
    ((data[offset] & 0x7f) << 21) |
    ((data[offset + 1] & 0x7f) << 14) |
    ((data[offset + 2] & 0x7f) << 7) |
    (data[offset + 3] & 0x7f)
  );
}

function readBigEndianUint32(data: Uint8Array, offset: number): number {
  return (
    (((data[offset] & 0xff) << 24) |
      ((data[offset + 1] & 0xff) << 16) |
      ((data[offset + 2] & 0xff) << 8) |
      (data[offset + 3] & 0xff)) >>>
    0
  );
}

function decodeEncodedBytes(bytes: Uint8Array, encoding: number): string {
  if (bytes.length === 0) return '';
  if (encoding === 1) {
    if (bytes.length >= 2 && bytes[0] === 0xfe && bytes[1] === 0xff) {
      return new TextDecoder('utf-16be').decode(bytes.subarray(2));
    }
    if (bytes.length >= 2 && bytes[0] === 0xff && bytes[1] === 0xfe) {
      return new TextDecoder('utf-16le').decode(bytes.subarray(2));
    }
    return new TextDecoder('utf-16le').decode(bytes);
  }
  if (encoding === 2) {
    return new TextDecoder('utf-16be').decode(bytes);
  }
  if (encoding === 3) {
    return new TextDecoder('utf-8').decode(bytes);
  }
  return new TextDecoder('iso-8859-1').decode(bytes);
}

function readNullTerminatedString(
  data: Uint8Array,
  offset: number,
  encoding: number,
): { value: string; bytesConsumed: number } {
  if (encoding === 1 || encoding === 2) {
    let end = offset;
    while (end + 1 < data.length) {
      if (data[end] === 0x00 && data[end + 1] === 0x00) {
        break;
      }
      end += 2;
    }
    const slice = data.subarray(offset, end);
    const value = decodeEncodedBytes(slice, encoding);
    const consumed = Math.min(data.length - offset, end - offset + 2);
    return { value, bytesConsumed: consumed };
  }

  let end = offset;
  while (end < data.length && data[end] !== 0x00) {
    end++;
  }
  const slice = data.subarray(offset, end);
  const value = decodeEncodedBytes(slice, encoding);
  const consumed = Math.min(data.length - offset, end - offset + 1);
  return { value, bytesConsumed: consumed };
}

function normalizeApicMime(rawMime: string): {
  mimeType: SupportedCoverMime;
  ext: 'jpg' | 'png' | 'webp';
} | null {
  const cleaned = rawMime.trim().toLowerCase();
  if (cleaned === 'image/jpeg' || cleaned === 'image/jpg' || cleaned === 'jpg') {
    return { mimeType: 'image/jpeg', ext: 'jpg' };
  }
  if (cleaned === 'image/png' || cleaned === 'png') {
    return { mimeType: 'image/png', ext: 'png' };
  }
  if (cleaned === 'image/webp' || cleaned === 'webp') {
    return { mimeType: 'image/webp', ext: 'webp' };
  }
  return null;
}

function detectMimeFromMagicBytes(imageData: Uint8Array): {
  mimeType: SupportedCoverMime;
  ext: 'jpg' | 'png' | 'webp';
} | null {
  if (
    imageData.length >= 3 &&
    imageData[0] === 0xff &&
    imageData[1] === 0xd8 &&
    imageData[2] === 0xff
  ) {
    return { mimeType: 'image/jpeg', ext: 'jpg' };
  }
  if (
    imageData.length >= 8 &&
    imageData[0] === 0x89 &&
    imageData[1] === 0x50 &&
    imageData[2] === 0x4e &&
    imageData[3] === 0x47
  ) {
    return { mimeType: 'image/png', ext: 'png' };
  }
  if (
    imageData.length >= 12 &&
    imageData[0] === 0x52 &&
    imageData[1] === 0x49 &&
    imageData[2] === 0x46 &&
    imageData[3] === 0x46 &&
    imageData[8] === 0x57 &&
    imageData[9] === 0x45 &&
    imageData[10] === 0x42 &&
    imageData[11] === 0x50
  ) {
    return { mimeType: 'image/webp', ext: 'webp' };
  }
  return null;
}

function parseApicFrameData(frameData: Uint8Array): ApicExtraction | null {
  if (frameData.length < 4) return null;
  let pos = 0;
  const encoding = frameData[pos++];
  const mimeResult = readNullTerminatedString(frameData, pos, 0);
  pos += mimeResult.bytesConsumed;
  if (pos >= frameData.length) return null;

  pos++; // picture type byte
  if (pos >= frameData.length) return null;

  const descResult = readNullTerminatedString(frameData, pos, encoding);
  pos += descResult.bytesConsumed;
  if (pos >= frameData.length) return null;

  const imageData = frameData.slice(pos);
  if (imageData.length < 16) return null;

  const resolvedMime =
    normalizeApicMime(mimeResult.value) ?? detectMimeFromMagicBytes(imageData);
  if (!resolvedMime) return null;

  return {
    imageData,
    mimeType: resolvedMime.mimeType,
    ext: resolvedMime.ext,
  };
}

function parseTextFrame(frameData: Uint8Array): string {
  if (frameData.length < 2) return '';
  const encoding = frameData[0];
  let end = frameData.length;
  if (encoding === 1 || encoding === 2) {
    // Strip only complete 2-byte UTF-16 NUL terminators so ASCII low bytes (e.g. [0x69, 0x00]) stay intact
    while (
      end >= 3 &&
      frameData[end - 1] === 0x00 &&
      frameData[end - 2] === 0x00
    ) {
      end -= 2;
    }
  } else {
    while (end > 1 && frameData[end - 1] === 0x00) {
      end--;
    }
  }
  const decoded = decodeEncodedBytes(frameData.subarray(1, end), encoding);
  return decoded.replace(/\u0000+/g, '').trim().normalize('NFC');
}

function parseUsltFrame(frameData: Uint8Array): string {
  if (frameData.length < 6) return '';
  const encoding = frameData[0];
  let pos = 4;
  const desc = readNullTerminatedString(frameData, pos, encoding);
  pos += desc.bytesConsumed;
  if (pos >= frameData.length) return '';
  const raw = decodeEncodedBytes(frameData.subarray(pos), encoding);
  return raw.replace(/\u0000+/g, '').trim().normalize('NFC');
}

function cleanGenreTag(raw: string): string {
  const stripped = raw.replace(/^\(\d+\)\s*/, '').trim();
  return stripped || raw.trim();
}

export function readId3TagByteLength(data: Uint8Array): number | null {
  if (data.length < 10) return null;
  if (data[0] !== 0x49 || data[1] !== 0x44 || data[2] !== 0x33) return null;
  const majorVersion = data[3];
  if (majorVersion !== 3 && majorVersion !== 4) return null;
  const tagSize = readSynchSafeInt(data, 6);
  return 10 + tagSize;
}

export function extractId3v2Metadata(
  data: Uint8Array,
): Id3v2MetadataResult | null {
  const tagByteLength = readId3TagByteLength(data);
  if (tagByteLength === null) return null;

  const majorVersion = data[3] as 3 | 4;
  const flags = data[5];
  const hasExtendedHeader = (flags & 0x40) !== 0;
  const tagEnd = Math.min(data.length, tagByteLength);

  let offset = 10;
  if (hasExtendedHeader) {
    if (offset + 4 > tagEnd) return null;
    const extHeaderSize =
      majorVersion === 4
        ? readSynchSafeInt(data, offset)
        : readBigEndianUint32(data, offset);
    offset += majorVersion === 4 ? extHeaderSize : 4 + extHeaderSize;
  }

  const result: Id3v2MetadataResult = {
    version: majorVersion,
    tagByteLength,
    apic: null,
  };

  const asciiDecoder = new TextDecoder('iso-8859-1');

  while (offset + 10 <= tagEnd) {
    if (data[offset] === 0x00) break;

    const frameId = asciiDecoder.decode(data.subarray(offset, offset + 4));
    offset += 4;

    const frameSize =
      majorVersion === 4
        ? readSynchSafeInt(data, offset)
        : readBigEndianUint32(data, offset);
    offset += 4;

    offset += 2; // frame flags

    if (frameSize <= 0) continue;
    if (offset + frameSize > tagEnd) break;

    const frameData = data.subarray(offset, offset + frameSize);

    if (frameId === 'APIC' && result.apic === null) {
      result.apic = parseApicFrameData(frameData);
    } else if (frameId === 'TIT2' && !result.title) {
      const val = parseTextFrame(frameData);
      if (val) result.title = val;
    } else if (frameId === 'TPE1' && !result.artist) {
      const val = parseTextFrame(frameData);
      if (val) result.artist = val;
    } else if (frameId === 'TALB' && !result.album) {
      const val = parseTextFrame(frameData);
      if (val) result.album = val;
    } else if (frameId === 'TCON' && !result.genre) {
      const val = cleanGenreTag(parseTextFrame(frameData));
      if (val) result.genre = val;
    } else if (frameId === 'TBPM' && result.bpm === undefined) {
      const parsedBpm = Math.round(Number.parseFloat(parseTextFrame(frameData)));
      if (Number.isFinite(parsedBpm) && parsedBpm >= 30 && parsedBpm <= 300) {
        result.bpm = parsedBpm;
      }
    } else if (frameId === 'USLT' && !result.lyrics) {
      const val = parseUsltFrame(frameData);
      if (val) result.lyrics = val;
    }

    offset += frameSize;
  }

  return result;
}

export function extractApicFrame(data: Uint8Array): ApicExtraction | null {
  return extractId3v2Metadata(data)?.apic ?? null;
}
