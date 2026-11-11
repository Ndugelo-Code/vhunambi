import { resolveMediaUrl } from '../../config/env.js';
import {
  canonicalizeCreatorId,
  vhunambiDb,
} from '../../db/vhunambi_db.js';
import {
  AfricanVoiceRegion,
  CreateVoiceCloneRequest,
  CreatorVoiceCloneProfile,
  PhoneticCalibrationLine,
  PhoneticCalibrationScript,
  RegionalVoiceArchetype,
  VocalDeliveryStyle,
  VocalGender,
} from './voice_types.js';

/**
 * Curated Catalog of 24 Sovereign Regional African Voice Archetypes (REQ-VOC-01, REQ-VOC-02).
 * Prevents generic "2-voice AI fatigue" across Amapiano, Gqom, Maskandi, Afrobeats, Lekompo, and Gospel.
 */
const RAW_REGIONAL_VOICE_CATALOG: RegionalVoiceArchetype[] = [
  {
    id: 'vox_venda_royal_alto',
    name: 'Makhadzi Royal Alto',
    region: 'southern_africa',
    gender: 'female',
    deliveryStyle: 'melodic_soul',
    nativeLanguage: 'Tshivenḓa',
    accentDescription: 'Thohoyandou royal alto with crisp dental plosives (ḓ, ṱ, ṋ) and warm chest resonance',
    vocalRange: 'G3 – E5',
    loraScale: 0.92,
    formantShiftSemitones: -0.4,
    recommendedCleanseFlavor: 'warm_intimate',
    samplePreviewUrl: '/mock-storage/vox_venda_royal_alto.mp3',
  },
  {
    id: 'vox_soweto_piano_falsetto',
    name: 'Soweto Golden Falsetto',
    region: 'southern_africa',
    gender: 'male',
    deliveryStyle: 'melodic_soul',
    nativeLanguage: 'isiZulu',
    accentDescription: 'Silky Private School Amapiano tenor/falsetto with airy vibrato and emotional glide',
    vocalRange: 'C3 – A4',
    loraScale: 0.88,
    formantShiftSemitones: 0.3,
    recommendedCleanseFlavor: 'studio_clean',
    samplePreviewUrl: '/mock-storage/vox_soweto_piano_falsetto.mp3',
  },
  {
    id: 'vox_durban_gqom_mc',
    name: 'Umlazi Warehouse Chant MC',
    region: 'southern_africa',
    gender: 'male',
    deliveryStyle: 'gqom_mc',
    nativeLanguage: 'isiZulu',
    accentDescription: 'Percussive Durban baritone hype MC with razor-sharp click transients (c, q, x)',
    vocalRange: 'G2 – D4',
    loraScale: 0.95,
    formantShiftSemitones: -0.8,
    recommendedCleanseFlavor: 'studio_clean',
    samplePreviewUrl: '/mock-storage/vox_durban_gqom_mc.mp3',
  },
  {
    id: 'vox_zululand_maskandi_story',
    name: 'Nongoma Maskandi Tenor',
    region: 'southern_africa',
    gender: 'male',
    deliveryStyle: 'maskandi_storyteller',
    nativeLanguage: 'isiZulu',
    accentDescription: 'Rapid-fire izibongo praise cadence paired with soaring KwaZulu traditional tenor',
    vocalRange: 'A2 – G4',
    loraScale: 0.94,
    formantShiftSemitones: 0.0,
    recommendedCleanseFlavor: 'studio_clean',
    samplePreviewUrl: '/mock-storage/vox_zululand_maskandi_story.mp3',
  },
  {
    id: 'vox_polokwane_lekompo_lead',
    name: 'Polokwane Lekompo Lead',
    region: 'southern_africa',
    gender: 'male',
    deliveryStyle: 'amapiano_chant',
    nativeLanguage: 'Sepedi',
    accentDescription: 'Energetic Limpopo Bolo/Lekompo lead with bouncy Sepedi cadence and call-and-response',
    vocalRange: 'B2 – F4',
    loraScale: 0.90,
    formantShiftSemitones: 0.1,
    recommendedCleanseFlavor: 'studio_clean',
    samplePreviewUrl: '/mock-storage/vox_polokwane_lekompo_lead.mp3',
  },
  {
    id: 'vox_pretoria_bacardi_soprano',
    name: 'Mamelodi Bacardi Queen',
    region: 'southern_africa',
    gender: 'female',
    deliveryStyle: 'amapiano_chant',
    nativeLanguage: 'Sepedi',
    accentDescription: 'Bright Pitori soprano chant with rhythmic syncopation and infectious township ad-libs',
    vocalRange: 'A3 – F5',
    loraScale: 0.89,
    formantShiftSemitones: 0.4,
    recommendedCleanseFlavor: 'studio_clean',
    samplePreviewUrl: '/mock-storage/vox_pretoria_bacardi_soprano.mp3',
  },
  {
    id: 'vox_eastern_cape_xhosa_velvet',
    name: 'Gqeberha Xhosa Velvet',
    region: 'southern_africa',
    gender: 'female',
    deliveryStyle: 'melodic_soul',
    nativeLanguage: 'isiXhosa',
    accentDescription: 'Rich Afro-Soul mezzo-soprano with effortless isiXhosa lateral & dental click articulation',
    vocalRange: 'F3 – D5',
    loraScale: 0.91,
    formantShiftSemitones: -0.2,
    recommendedCleanseFlavor: 'warm_intimate',
    samplePreviewUrl: '/mock-storage/vox_eastern_cape_xhosa_velvet.mp3',
  },
  {
    id: 'vox_giyani_tsonga_electro',
    name: 'Giyani Shangaan Fire',
    region: 'southern_africa',
    gender: 'female',
    deliveryStyle: 'amapiano_chant',
    nativeLanguage: 'Xitsonga',
    accentDescription: 'High-velocity Xitsonga vocal agility tailored for fast marimba and Amapiano uptempo cuts',
    vocalRange: 'G3 – G5',
    loraScale: 0.93,
    formantShiftSemitones: 0.5,
    recommendedCleanseFlavor: 'studio_clean',
    samplePreviewUrl: '/mock-storage/vox_giyani_tsonga_electro.mp3',
  },
  {
    id: 'vox_maseru_sesotho_crooner',
    name: 'Maseru Mountain Crooner',
    region: 'southern_africa',
    gender: 'male',
    deliveryStyle: 'melodic_soul',
    nativeLanguage: 'Sesotho',
    accentDescription: 'Deep, velvet Sesotho baritone with poetic penultimate vowel elongation',
    vocalRange: 'F2 – E4',
    loraScale: 0.87,
    formantShiftSemitones: -0.6,
    recommendedCleanseFlavor: 'warm_intimate',
    samplePreviewUrl: '/mock-storage/vox_maseru_sesotho_crooner.mp3',
  },
  {
    id: 'vox_mbabane_swati_harmony',
    name: 'Ezulwini Swati Harmony Duet',
    region: 'southern_africa',
    gender: 'duet',
    deliveryStyle: 'choir_harmony',
    nativeLanguage: 'siSwati',
    accentDescription: 'Blended male/female siSwati fifth-interval duet with lush breathy texture',
    vocalRange: 'G2 – E5',
    loraScale: 0.90,
    formantShiftSemitones: 0.0,
    recommendedCleanseFlavor: 'wide_anthem',
    samplePreviewUrl: '/mock-storage/vox_mbabane_swati_harmony.mp3',
  },
  {
    id: 'vox_gaborone_tswana_breeze',
    name: 'Gaborone Jazz-Piano Silk',
    region: 'southern_africa',
    gender: 'female',
    deliveryStyle: 'melodic_soul',
    nativeLanguage: 'Setswana',
    accentDescription: 'Intimate Setswana neo-soul voice designed for Rhodes-heavy Private School progressions',
    vocalRange: 'G3 – E5',
    loraScale: 0.86,
    formantShiftSemitones: 0.2,
    recommendedCleanseFlavor: 'warm_intimate',
    samplePreviewUrl: '/mock-storage/vox_gaborone_tswana_breeze.mp3',
  },
  {
    id: 'vox_ndebele_royal_choir',
    name: 'KwaNdebele Zion Choir',
    region: 'southern_africa',
    gender: 'choir',
    deliveryStyle: 'choir_harmony',
    nativeLanguage: 'isiNdebele',
    accentDescription: '12-voice stadium call-and-response Bantu choir with thunderous four-part harmony',
    vocalRange: 'E2 – G5',
    loraScale: 0.96,
    formantShiftSemitones: 0.0,
    recommendedCleanseFlavor: 'wide_anthem',
    samplePreviewUrl: '/mock-storage/vox_ndebele_royal_choir.mp3',
  },
  {
    id: 'vox_lagos_afrobeats_smooth',
    name: 'Victoria Island Afro-Fusion',
    region: 'west_africa',
    gender: 'male',
    deliveryStyle: 'afrobeats_smooth',
    nativeLanguage: 'Yorùbá',
    accentDescription: 'Laid-back Lagos mid-range vocal with Yorùbá tonal inflections and Pidgin pocket',
    vocalRange: 'A2 – F4',
    loraScale: 0.89,
    formantShiftSemitones: -0.2,
    recommendedCleanseFlavor: 'warm_intimate',
    samplePreviewUrl: '/mock-storage/vox_lagos_afrobeats_smooth.mp3',
  },
  {
    id: 'vox_lekki_siren_soprano',
    name: 'Lekki Celestial Siren',
    region: 'west_africa',
    gender: 'female',
    deliveryStyle: 'afrobeats_smooth',
    nativeLanguage: 'Yorùbá',
    accentDescription: 'Feather-light West African R&B soprano with glossy air sheen and honeyed runs',
    vocalRange: 'A3 – G5',
    loraScale: 0.88,
    formantShiftSemitones: 0.4,
    recommendedCleanseFlavor: 'studio_clean',
    samplePreviewUrl: '/mock-storage/vox_lekki_siren_soprano.mp3',
  },
  {
    id: 'vox_accra_highlife_gold',
    name: 'Accra Highlife-Drill Baritone',
    region: 'west_africa',
    gender: 'male',
    deliveryStyle: 'afrobeats_smooth',
    nativeLanguage: 'Twi',
    accentDescription: 'Warm Ghanaian Twi baritone bridging classic Highlife melodies with modern Afro-Swing',
    vocalRange: 'G2 – E4',
    loraScale: 0.87,
    formantShiftSemitones: -0.5,
    recommendedCleanseFlavor: 'warm_intimate',
    samplePreviewUrl: '/mock-storage/vox_accra_highlife_gold.mp3',
  },
  {
    id: 'vox_enugu_ogene_tenor',
    name: 'Enugu High-Life Tenor',
    region: 'west_africa',
    gender: 'male',
    deliveryStyle: 'melodic_soul',
    nativeLanguage: 'Igbo',
    accentDescription: 'Resonant Eastern Nigerian Igbo tenor with commanding vibrato and celebratory projection',
    vocalRange: 'B2 – G4',
    loraScale: 0.91,
    formantShiftSemitones: 0.1,
    recommendedCleanseFlavor: 'studio_clean',
    samplePreviewUrl: '/mock-storage/vox_enugu_ogene_tenor.mp3',
  },
  {
    id: 'vox_dakar_mbalax_griot',
    name: 'Dakar Teranga Griot',
    region: 'west_africa',
    gender: 'male',
    deliveryStyle: 'maskandi_storyteller',
    nativeLanguage: 'Wolof',
    accentDescription: 'Soaring Senegalese Wolof griot tenor with intricate Sahelian melisma',
    vocalRange: 'C3 – A4',
    loraScale: 0.93,
    formantShiftSemitones: 0.3,
    recommendedCleanseFlavor: 'studio_clean',
    samplePreviewUrl: '/mock-storage/vox_dakar_mbalax_griot.mp3',
  },
  {
    id: 'vox_nairobi_swahili_silk',
    name: 'Nairobi Arbantone Silk',
    region: 'east_africa',
    gender: 'female',
    deliveryStyle: 'melodic_soul',
    nativeLanguage: 'Kiswahili',
    accentDescription: 'Smooth Kenyan Kiswahili & Sheng vocal with crystal-clear coastal vowel purity',
    vocalRange: 'G3 – F5',
    loraScale: 0.88,
    formantShiftSemitones: 0.2,
    recommendedCleanseFlavor: 'studio_clean',
    samplePreviewUrl: '/mock-storage/vox_nairobi_swahili_silk.mp3',
  },
  {
    id: 'vox_dar_bongo_flava_star',
    name: 'Dar es Salaam Bongo Crooner',
    region: 'east_africa',
    gender: 'male',
    deliveryStyle: 'afrobeats_smooth',
    nativeLanguage: 'Kiswahili',
    accentDescription: 'Romantic Tanzanian Bongo Flava & Singeli-fusion tenor with coastal Taarab ornamentation',
    vocalRange: 'A2 – F4',
    loraScale: 0.89,
    formantShiftSemitones: 0.0,
    recommendedCleanseFlavor: 'warm_intimate',
    samplePreviewUrl: '/mock-storage/vox_dar_bongo_flava_star.mp3',
  },
  {
    id: 'vox_kampala_afro_dancehall',
    name: 'Kampala Fire Baritone',
    region: 'east_africa',
    gender: 'male',
    deliveryStyle: 'gqom_mc',
    nativeLanguage: 'Luganda',
    accentDescription: 'Gritty Ugandan Luganda dancehall/electronic toaster with chest-rattling low end',
    vocalRange: 'F2 – D4',
    loraScale: 0.92,
    formantShiftSemitones: -0.7,
    recommendedCleanseFlavor: 'studio_clean',
    samplePreviewUrl: '/mock-storage/vox_kampala_afro_dancehall.mp3',
  },
  {
    id: 'vox_addis_tizita_alto',
    name: 'Addis Tizita Pentatonic Alto',
    region: 'east_africa',
    gender: 'female',
    deliveryStyle: 'melodic_soul',
    nativeLanguage: 'Amharic',
    accentDescription: 'Hypnotic Ethiopian Amharic alto with signature Tizita pentatonic pitch bends',
    vocalRange: 'F3 – D5',
    loraScale: 0.91,
    formantShiftSemitones: -0.1,
    recommendedCleanseFlavor: 'warm_intimate',
    samplePreviewUrl: '/mock-storage/vox_addis_tizita_alto.mp3',
  },
  {
    id: 'vox_kinshasa_rumba_sebene',
    name: 'Kinshasa Rumba-Sebene Duet',
    region: 'central_africa',
    gender: 'duet',
    deliveryStyle: 'choir_harmony',
    nativeLanguage: 'Lingala',
    accentDescription: 'Sweet Congolese Lingala parallel-thirds duet with animated Sebene atalaku shouts',
    vocalRange: 'A2 – F5',
    loraScale: 0.94,
    formantShiftSemitones: 0.2,
    recommendedCleanseFlavor: 'wide_anthem',
    samplePreviewUrl: '/mock-storage/vox_kinshasa_rumba_sebene.mp3',
  },
  {
    id: 'vox_douala_makossa_soul',
    name: 'Douala Makossa Groove',
    region: 'central_africa',
    gender: 'female',
    deliveryStyle: 'melodic_soul',
    nativeLanguage: 'Duala',
    accentDescription: 'Velvety Cameroonian vocal combining Franco-Bantu jazz phrasing with deep groove',
    vocalRange: 'G3 – E5',
    loraScale: 0.87,
    formantShiftSemitones: 0.0,
    recommendedCleanseFlavor: 'warm_intimate',
    samplePreviewUrl: '/mock-storage/vox_douala_makossa_soul.mp3',
  },
  {
    id: 'vox_london_afro_house_diva',
    name: 'South London Afro-Tech Diva',
    region: 'diaspora',
    gender: 'female',
    deliveryStyle: 'melodic_soul',
    nativeLanguage: 'English',
    accentDescription: 'Powerhouse Afro-House & UK Funky soul vocalist with stadium-ready belt and air sheen',
    vocalRange: 'G3 – G5',
    loraScale: 0.90,
    formantShiftSemitones: 0.1,
    recommendedCleanseFlavor: 'wide_anthem',
    samplePreviewUrl: '/mock-storage/vox_london_afro_house_diva.mp3',
  },
];

export const REGIONAL_VOICE_CATALOG: RegionalVoiceArchetype[] =
  RAW_REGIONAL_VOICE_CATALOG.map((arch) => ({
    ...arch,
    samplePreviewUrl: resolveMediaUrl(arch.samplePreviewUrl),
  }));

const DIACRITIC_REGEX = /[ḓṱṋḽṅḒṰṊḼṄ]/g;
const CLUSTER_REGEX = /\b\w*(tsh|dz|pf|bv|hl|dl|kh|ph|th|ng|nk|ny|sh|zh)\w*\b/gi;
const CULTURAL_IDIOMS = [
  'ndaa',
  'aa',
  'yebo',
  'ahee',
  'siyabonga',
  'kea leboga',
  'eish',
  'yoh',
  'bathong',
  'haibo',
  'shapa',
  'khuza',
  'woza',
  'ashu',
  'tsha',
  'mbilu',
  'vhunambi',
];

const FALLBACK_CALIBRATION_LINES: Record<string, string[]> = {
  ve: [
    'Ndaa! Mbilu yanga i khoulidza ngoma dza Vhunambi na ḓuvha ḽa मुṱa.',
    'Ri tshimbila kha ṋaledzi dza vhusiku, ri imba nga lufuno lwa vhukuma.',
    'Ahee! Kha vha ḓe ri ṱangane tshilombe tsha Amapiano.',
  ],
  zu: [
    'Yebo! Siyabonga kakhulu, inhliziyo yami ishaya isigqi se-Amapiano.',
    'Woza la! Amagagasi olwandle athetha ingoma yaseThekwini.',
    'Haibo! Hlala phansi ulalele uMaskandi oqotho.',
  ],
  default: [
    'Ndaa! Mbilu yanga i khou tshina kha ngoma dza Vhunambi.',
    'Yebo! Hlala phansi ulalele isigqi saseMzansi esishisayo.',
    'Ahee! Kea leboga, re bina koša ya Amapiano bosigo kamoka.',
  ],
};

/**
 * Filters the 24+ Regional African Voice Catalog by optional query parameters (REQ-VOC-03).
 */
export function filterVoiceCatalog(query: {
  region?: AfricanVoiceRegion | string;
  gender?: VocalGender | string;
  language?: string;
  style?: VocalDeliveryStyle | string;
  q?: string;
}): RegionalVoiceArchetype[] {
  return REGIONAL_VOICE_CATALOG.filter((arch) => {
    if (query.region && arch.region !== query.region) return false;
    if (query.gender && arch.gender !== query.gender) return false;
    if (query.style && arch.deliveryStyle !== query.style) return false;
    if (
      query.language &&
      !arch.nativeLanguage.toLowerCase().includes(query.language.toLowerCase())
    ) {
      return false;
    }
    if (query.q && query.q.trim().length > 0) {
      const needle = query.q.toLowerCase().trim();
      const hay =
        `${arch.name} ${arch.nativeLanguage} ${arch.accentDescription} ${arch.region}`.toLowerCase();
      if (!hay.includes(needle)) return false;
    }
    return true;
  });
}

/**
 * Scores a single lyric line using the deterministic Bantu Phonetic Density formula (REQ-VOC-04):
 * S_line = 3.0 * N_diacritics + 2.5 * N_clusters + 2.0 * N_idioms + 1.0 * clamp(wordCount / 6, 0, 2)
 */
export function scoreLyricLinePhonetics(line: string): {
  score: number;
  highlightedTokens: string[];
} {
  const trimmed = line.trim();
  if (!trimmed || trimmed.startsWith('[')) {
    return { score: 0, highlightedTokens: [] };
  }

  const diacriticMatches = trimmed.match(DIACRITIC_REGEX) ?? [];
  const words = trimmed.split(/\s+/).filter(Boolean);
  const highlighted = new Set<string>();

  let clusterCount = 0;
  let idiomCount = 0;

  for (const rawWord of words) {
    const cleanWord = rawWord.replace(/[.,!?;:"'()]/g, '');
    if (!cleanWord) continue;

    if (DIACRITIC_REGEX.test(cleanWord)) {
      highlighted.add(cleanWord);
    }
    DIACRITIC_REGEX.lastIndex = 0;

    if (CLUSTER_REGEX.test(cleanWord)) {
      clusterCount++;
      highlighted.add(cleanWord);
    }
    CLUSTER_REGEX.lastIndex = 0;

    const lower = cleanWord.toLowerCase();
    if (CULTURAL_IDIOMS.includes(lower)) {
      idiomCount++;
      highlighted.add(cleanWord);
    }
  }

  const wordFactor = Math.min(2.0, Math.max(0.0, words.length / 6.0));
  const rawScore =
    3.0 * diacriticMatches.length +
    2.5 * clusterCount +
    2.0 * idiomCount +
    1.0 * wordFactor;

  return {
    score: Number(rawScore.toFixed(2)),
    highlightedTokens: Array.from(highlighted).slice(0, 6),
  };
}

/**
 * Extracts the top 3 phonetically dense lines from user lyrics for 20-second voice calibration (REQ-VOC-05, REQ-VOC-06).
 */
export function extractPhoneticCalibrationScript(
  lyrics: string,
  language: string = 've',
): PhoneticCalibrationScript {
  const rawLines = lyrics
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => l.length > 3 && !l.startsWith('['));

  // Deduplicate while preserving order
  const uniqueLines = Array.from(new Set(rawLines));

  const scored = uniqueLines
    .map((text) => {
      const { score, highlightedTokens } = scoreLyricLinePhonetics(text);
      return { text, score, highlightedTokens };
    })
    .sort((a, b) => b.score - a.score);

  const selected = scored.slice(0, 3);

  // Pad with culturally authentic fallback sentences if lyrics had fewer than 3 lines
  const langKey = language.toLowerCase().startsWith('zu')
    ? 'zu'
    : language.toLowerCase().startsWith('ve') || language.toLowerCase().includes('venda')
      ? 've'
      : 'default';
  const fallbacks = FALLBACK_CALIBRATION_LINES[langKey] ?? FALLBACK_CALIBRATION_LINES.default;

  let fbIdx = 0;
  while (selected.length < 3 && fbIdx < fallbacks.length) {
    const fbText = fallbacks[fbIdx++];
    if (!selected.some((s) => s.text === fbText)) {
      const { score, highlightedTokens } = scoreLyricLinePhonetics(fbText);
      selected.push({ text: fbText, score, highlightedTokens });
    }
  }

  const lines: PhoneticCalibrationLine[] = selected.map((item, idx) => {
    const words = item.text.split(/\s+/).filter(Boolean).length;
    const estSec = Math.max(4, Math.min(8, Math.round(words * 0.65)));
    return {
      lineIndex: idx,
      text: item.text,
      phoneticScore: item.score,
      highlightedTokens:
        item.highlightedTokens.length > 0
          ? item.highlightedTokens
          : item.text.split(/\s+/).slice(0, 2),
      estimatedDurationSec: estSec,
    };
  });

  const totalEstimatedDurationSec = lines.reduce(
    (acc, l) => acc + l.estimatedDurationSec,
    0,
  );

  return {
    language,
    lines,
    totalEstimatedDurationSec,
  };
}

export function registerVoiceCloneProfile(
  req: CreateVoiceCloneRequest,
): CreatorVoiceCloneProfile {
  const id = `vclone_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
  const seed = req.creatorName.length + req.calibrationLines.join('').length;

  // Deterministic 8-float preview of the 256-D speaker timbre embedding
  const timbreEmbeddingPreview = Array.from({ length: 8 }, (_, i) => {
    const val = Math.sin(seed * (i + 1) * 0.37) * 0.85;
    return Number(val.toFixed(4));
  });

  const totalWords = req.calibrationLines
    .join(' ')
    .split(/\s+/)
    .filter(Boolean).length;
  const durationMin = Math.max(0.1, req.recordingDurationSec / 60.0);
  const cadenceWpm = Math.round(Math.min(180, Math.max(75, totalWords / durationMin)));
  const creatorId = canonicalizeCreatorId(req.creatorId || 'creator_cern');

  const profile: CreatorVoiceCloneProfile = {
    id,
    creatorId,
    creatorName: req.creatorName,
    nativeLanguage: req.nativeLanguage,
    timbreEmbeddingPreview,
    cadenceWpm,
    clarityScore: 0.94,
    r2ReferenceUrl: resolveMediaUrl(
      req.r2ReferenceUrl ?? `https://r2.vhunambi.com/voice-clones/${id}_ref.wav`,
    ),
    recommendedCleanseFlavor: 'studio_clean',
    createdAtIso: new Date().toISOString(),
  };

  vhunambiDb.upsertVoiceClone({
    ...profile,
    voiceId: id,
    creatorId,
    displayName: req.creatorName,
    consentVerified: true,
    referenceAudioDurationSec: req.recordingDurationSec,
    timbreEmbedding: timbreEmbeddingPreview,
    createdAt: profile.createdAtIso,
  });
  return profile;
}

export function getVoiceCloneProfile(id: string): CreatorVoiceCloneProfile | undefined {
  const row = vhunambiDb.getVoiceCloneById(id);
  return row ? (row as CreatorVoiceCloneProfile) : undefined;
}

export const createZeroShotVoiceClone = registerVoiceCloneProfile;
export const getClonedVoiceById = getVoiceCloneProfile;

/** Registry of Sovereign Sound Signatures (Phase 35 / Design 8.2, Phase 62 Persistent) */
export function registerSoundSignature(data: any): any {
  const now = new Date().toISOString();
  const creatorId = canonicalizeCreatorId(data.creatorId || 'creator_cern');
  const record = {
    ...data,
    creatorId,
    recipe: data.recipe ?? {},
    r2AudioKey: `signatures/${data.id}/raw.wav`,
    createdAtIso: now,
    updatedAtIso: now,
    createdAt: now,
    updatedAt: now,
  };
  vhunambiDb.upsertSoundSignature({
    ...record,
    name: data.displayCode || data.name || 'Sound Signature',
  });
  return record;
}

export function getSoundSignature(id: string): any | undefined {
  return vhunambiDb.getSoundSignatureById(id) ?? undefined;
}

export function updateSoundSignatureRecipe(id: string, recipeUpdate: any): any | undefined {
  const existing = getSoundSignature(id);
  if (!existing) return undefined;
  const now = new Date().toISOString();
  const updated = {
    ...existing,
    recipe: { ...(existing.recipe ?? {}), ...recipeUpdate },
    updatedAtIso: now,
    updatedAt: now,
  };
  vhunambiDb.upsertSoundSignature({
    ...updated,
    name: updated.displayCode || updated.name || 'Sound Signature',
  });
  return updated;
}

export function deleteSoundSignature(id: string): boolean {
  return vhunambiDb.deleteSoundSignature(id);
}

export const createSoundSignatureRecord = registerSoundSignature;
export const getSoundSignatureRecord = getSoundSignature;
export const updateSoundSignatureRecord = updateSoundSignatureRecipe;
export const deleteSoundSignatureRecord = deleteSoundSignature;


