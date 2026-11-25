/**
 * Canonical Sovereign African LoRA Pack Registry (Phase 83)
 * Single source of truth shared across llm_handler.ts, prompt_compiler.ts,
 * runpod_adapter.ts, studio_routes.ts, and synchronized with model_utils.py.
 */

export interface AfricanLoraPackDescriptor {
  loraId: string;
  label: string;
  genre: string;
  region: string;
  r2Key: string;
  defaultWeight: number;
  compatibleGenres: string[];
  description: string;
  tier: 'sovereign_custom';
  packType?: 'genre' | 'language';
}

export const AFRICAN_LORA_PACKS: readonly AfricanLoraPackDescriptor[] = [
  {
    loraId: 'amapiano_logdrum_v1',
    label: 'Amapiano Log Drum',
    genre: 'Amapiano',
    region: 'Gauteng / South Africa',
    r2Key: 'loras/amapiano_logdrum_v1.safetensors',
    defaultWeight: 0.85,
    compatibleGenres: ['amapiano'],
    description:
      'Iconic resonant South African log-drum sub pocket & syncopated shakers.',
    tier: 'sovereign_custom',
  },
  {
    loraId: 'amapiano_private_school_v1',
    label: 'Private School Rhodes',
    genre: 'Private School Amapiano',
    region: 'Johannesburg / South Africa',
    r2Key: 'loras/amapiano_private_school_v1.safetensors',
    defaultWeight: 0.85,
    compatibleGenres: [
      'privateschoolamapiano',
      'afrojazz',
      'afrosoul',
      'lofichill',
      'afroasianlofi',
      'rb',
    ],
    description:
      'Lush Rhodes electric piano jazz voicings, warm sax fills & smooth log-drum glide.',
    tier: 'sovereign_custom',
  },
  {
    loraId: 'sgija_bacardi_v1',
    label: 'Sgija & Bacardi Bounce',
    genre: 'Sgija',
    region: 'Pretoria / Tshwane',
    r2Key: 'loras/sgija_bacardi_v1.safetensors',
    defaultWeight: 0.86,
    compatibleGenres: ['sgija', 'bacardi'],
    description:
      'Staccato Pretoria Sgija log-drum stabs and high-energy Tshwane Bacardi brass.',
    tier: 'sovereign_custom',
  },
  {
    loraId: 'gqom_durban_v1',
    label: 'Durban Gqom Sub',
    genre: 'Gqom',
    region: 'KwaZulu-Natal / Durban',
    r2Key: 'loras/gqom_durban_v1.safetensors',
    defaultWeight: 0.88,
    compatibleGenres: ['gqom', 'kuduro', 'afrodrill'],
    description:
      'Dark hypnotic broken-beat Durban club kicks & distorted sub drones.',
    tier: 'sovereign_custom',
  },
  {
    loraId: 'maskandi_picking_v1',
    label: 'Maskandi Acoustic Picking',
    genre: 'Maskandi',
    region: 'KwaZulu-Natal / South Africa',
    r2Key: 'loras/maskandi_picking_v1.safetensors',
    defaultWeight: 0.82,
    compatibleGenres: ['maskandi', 'mbaqanga', 'marabi', 'chimurenga'],
    description:
      'Fast Zulu fingerpicked acoustic guitar izihlabo and bright concertina runs.',
    tier: 'sovereign_custom',
  },
  {
    loraId: 'venda_malende_v1',
    label: 'Venda Malende & Lekompo',
    genre: 'Malende',
    region: 'Limpopo / Venda',
    r2Key: 'loras/venda_malende_v1.safetensors',
    defaultWeight: 0.85,
    compatibleGenres: ['venda', 'malende', 'lekompo', 'tshigombela'],
    description:
      'Polyrhythmic Tshivenḓa Malende drums, Limpopo Lekompo bounce & communal call-and-response.',
    tier: 'sovereign_custom',
  },
  {
    loraId: 'afrobeats_lagos_v1',
    label: 'Lagos Afrobeats Groove',
    genre: 'Afrobeats',
    region: 'West & Pan-Africa',
    r2Key: 'loras/afrobeats_lagos_v1.safetensors',
    defaultWeight: 0.80,
    compatibleGenres: [
      'afrobeats',
      'afrofusion',
      'highlife',
      'rumba',
      'soukous',
      'bongoflava',
      'gengetone',
      'coupedecale',
      'pop',
      'kpop',
      'bollywoodfusion',
    ],
    description:
      'Clean interlocking Afrobeats guitars, talking drums & crisp shekere rimshot pocket.',
    tier: 'sovereign_custom',
  },
  {
    loraId: 'kwaito_township_v1',
    label: 'Township Kwaito Tape',
    genre: 'Kwaito',
    region: 'Soweto / South Africa',
    r2Key: 'loras/kwaito_township_v1.safetensors',
    defaultWeight: 0.82,
    compatibleGenres: ['kwaito', 'bubblegum', 'hiphop', 'dancehall', 'reggae'],
    description:
      'Warm 90s slowed house bass bounce and vintage Soweto street groove.',
    tier: 'sovereign_custom',
  },
  {
    loraId: 'afro_gospel_choir_v1',
    label: 'Afro-Gospel Mass Choir',
    genre: 'Gospel',
    region: 'Southern Africa',
    r2Key: 'loras/afro_gospel_choir_v1.safetensors',
    defaultWeight: 0.84,
    compatibleGenres: ['gospel', 'gospelsoul', 'isicathamiya', 'mbube'],
    description:
      'Soaring Hammond organ swells, brass fanfares & lush 4-part South African choral harmonies.',
    tier: 'sovereign_custom',
  },
  {
    loraId: 'afrohouse_ancestral_v1',
    label: 'Ancestral Afro House',
    genre: 'Afro House',
    region: 'Southern & East Africa',
    r2Key: 'loras/afrohouse_ancestral_v1.safetensors',
    defaultWeight: 0.85,
    compatibleGenres: ['afrohouse', 'electronic', 'ethiojazz', 'kizomba', 'samba', 'afrocuban'],
    description:
      'Rolling tribal congas, progressive spiritual pads & deep four-on-the-floor pulse.',
    tier: 'sovereign_custom',
    packType: 'genre',
  },
];

/**
 * Language Specialist LoRA Pack (Phase 85).
 * Kept separate from AFRICAN_LORA_PACKS so GET /v1/studio/loras preserves totalCount === 10
 * backward compatibility while exposing bilingual/Bantu vocal conditioning packs.
 */
export const LANGUAGE_LORA_PACKS: readonly AfricanLoraPackDescriptor[] = [
  {
    loraId: 'bantu_vocals_v1',
    label: 'Bantu Vocals & Phonetics',
    genre: 'Bantu Vocals',
    region: '11 South African Languages',
    r2Key: 'loras/bantu_vocals_v1.safetensors',
    defaultWeight: 0.88,
    compatibleGenres: [
      'bantuvocals',
      'venda',
      'zulu',
      'xhosa',
      'sepedi',
      'sesotho',
      'setswana',
      'xitsonga',
    ],
    description:
      'BS-RoFormer vocal-isolated South African Bantu tonal phrasing, click onsets & diacritic clarity.',
    tier: 'sovereign_custom',
    packType: 'language',
  },
];

export const ALL_SOVEREIGN_LORA_PACKS: readonly AfricanLoraPackDescriptor[] = [
  ...AFRICAN_LORA_PACKS,
  ...LANGUAGE_LORA_PACKS,
];

export function findLoraPackById(
  loraIdOrPath: string,
): AfricanLoraPackDescriptor | undefined {
  const clean = loraIdOrPath.trim().toLowerCase();
  return ALL_SOVEREIGN_LORA_PACKS.find(
    (p) =>
      p.loraId.toLowerCase() === clean ||
      p.r2Key.toLowerCase() === clean ||
      p.label.toLowerCase() === clean,
  );
}

export function resolveRecommendedLoraForGenre(
  genre: string,
): AfricanLoraPackDescriptor {
  const norm = (genre || 'amapiano').toLowerCase().replace(/[^a-z]/g, '');
  const exact = AFRICAN_LORA_PACKS.find((p) =>
    p.compatibleGenres.includes(norm),
  );
  if (exact) return exact;

  // Fuzzy longest-match across compatible genre slugs (e.g. "90s Kwaito" -> kwaito)
  let best: AfricanLoraPackDescriptor | undefined;
  let bestLen = 0;
  for (const pack of AFRICAN_LORA_PACKS) {
    for (const slug of pack.compatibleGenres) {
      if (norm.includes(slug) && slug.length > bestLen) {
        best = pack;
        bestLen = slug.length;
      }
    }
  }
  return best ?? AFRICAN_LORA_PACKS[0]!;
}

export function normalizeRequestedLoraSpecs(
  genre: string,
  explicit?: Array<{
    loraId?: string;
    lora_id?: string;
    path?: string;
    weight?: number;
  }>,
): Array<{ loraId: string; path: string; weight: number }> {
  const rawList: Array<{ loraId: string; path: string; weight: number }> = [];
  if (Array.isArray(explicit) && explicit.length > 0) {
    for (const item of explicit.slice(0, 3)) {
      if (!item) continue;
      const lookupId = item.loraId ?? item.lora_id ?? item.path ?? '';
      const matched = lookupId ? findLoraPackById(lookupId) : undefined;
      const path = item.path || matched?.r2Key || '';
      if (!path) continue;
      const rawWeight =
        typeof item.weight === 'number'
          ? item.weight
          : (matched?.defaultWeight ?? 0.85);
      const clampedWeight = Math.max(0.1, Math.min(1.2, rawWeight));
      rawList.push({
        loraId:
          matched?.loraId ??
          item.loraId ??
          item.lora_id ??
          path.split('/').pop() ??
          'custom_lora',
        path,
        weight: Number(clampedWeight.toFixed(4)),
      });
    }
  }
  if (rawList.length === 0) {
    const rec = resolveRecommendedLoraForGenre(genre);
    rawList.push({
      loraId: rec.loraId,
      path: rec.r2Key,
      weight: rec.defaultWeight,
    });
  }

  const totalWeight = rawList.reduce((acc, x) => acc + x.weight, 0);
  if (totalWeight > 1.35 && totalWeight > 0) {
    const scale = 1.35 / totalWeight;
    for (const item of rawList) {
      item.weight = Number((item.weight * scale).toFixed(4));
    }
  }
  return rawList;
}
