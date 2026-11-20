export type VhunambiMoodId =
  | 'uplifting'
  | 'soulful'
  | 'energetic'
  | 'chill'
  | 'hypnotic'
  | 'romantic';

export const VHUNAMBI_MOOD_IDS: readonly VhunambiMoodId[] = [
  'uplifting',
  'soulful',
  'energetic',
  'chill',
  'hypnotic',
  'romantic',
] as const;

const MOOD_ALIAS_MAP: Record<string, VhunambiMoodId> = {
  uplifting: 'uplifting',
  vibrant: 'uplifting',
  joyful: 'uplifting',
  happy: 'uplifting',
  celebratory: 'uplifting',
  soulful: 'soulful',
  'soulful & nostalgic': 'soulful',
  nostalgic: 'soulful',
  melancholic: 'soulful',
  warm: 'soulful',
  reflective: 'soulful',
  energetic: 'energetic',
  electrifying: 'energetic',
  party: 'energetic',
  hype: 'energetic',
  club: 'energetic',
  chill: 'chill',
  peaceful: 'chill',
  calm: 'chill',
  relaxed: 'chill',
  'laid-back': 'chill',
  hypnotic: 'hypnotic',
  deep: 'hypnotic',
  dark: 'hypnotic',
  atmospheric: 'hypnotic',
  minimal: 'hypnotic',
  romantic: 'romantic',
  sensual: 'romantic',
  intimate: 'romantic',
  love: 'romantic',
};

/**
 * Normalizes any legacy display mood string or alias to one of the 6 canonical
 * VhunambiMood slugs (`REQ-P70-MOOD-01`, `REQ-P70-API-02`).
 */
export function normalizeVhunambiMoodId(raw?: string | null): VhunambiMoodId {
  const cleaned = (raw ?? '').trim().toLowerCase();
  if (!cleaned) return 'uplifting';
  if (MOOD_ALIAS_MAP[cleaned]) return MOOD_ALIAS_MAP[cleaned];
  if (
    cleaned.includes('soul') ||
    cleaned.includes('nostalg') ||
    cleaned.includes('melanchol')
  ) {
    return 'soulful';
  }
  if (
    cleaned.includes('energ') ||
    cleaned.includes('party') ||
    cleaned.includes('electr')
  ) {
    return 'energetic';
  }
  if (
    cleaned.includes('chill') ||
    cleaned.includes('calm') ||
    cleaned.includes('peace')
  ) {
    return 'chill';
  }
  if (
    cleaned.includes('hypno') ||
    cleaned.includes('deep') ||
    cleaned.includes('dark') ||
    cleaned.includes('atmos')
  ) {
    return 'hypnotic';
  }
  if (cleaned.includes('roman')) {
    return 'romantic';
  }
  return 'uplifting';
}
