/**
 * Bantu Language Context & Phonetic Guidelines for African Audio Synthesis
 *
 * Provides phonetic guides, cultural context, and vocal styling rules
 * across 9 official South African indigenous languages.
 */

export interface MusicLanguageContext {
  languageCode: string; // ISO 639-1 / BCP-47 base: 've', 'zu', 'xh', etc.
  languageName: string;
  nativeName: string;
  vocalStyleAdvice: string;
  phoneticNotes: string;
  adLibs: string[];
}

export const MUSIC_LANGUAGES: MusicLanguageContext[] = [
  {
    languageCode: 've',
    languageName: 'Tshivenḓa',
    nativeName: 'Tshivenḓa',
    vocalStyleAdvice: 'Melodic, rhythmic storytelling with warm vocal inflection, polyrhythmic chanting and traditional call-and-response.',
    phoneticNotes: 'Venda dental consonants (ḓ, ṱ, ṋ, ḽ) require clean articulation; open vowels (a, e, i, o, u) sustain naturally.',
    adLibs: ['Ndi zwone!', 'Aa!', 'Kha ri tshimbile!', 'Vhukuma!'],
  },
  {
    languageCode: 'zu',
    languageName: 'isiZulu',
    nativeName: 'isiZulu',
    vocalStyleAdvice: 'Resonant, powerful delivery with deep rhythmic cadences, syncopated ad-libs, and soulful choral harmonies.',
    phoneticNotes: 'Click consonants (c, q, x) are percussive accents; penultimate syllable lengthening anchors the groove.',
    adLibs: ['Yebo!', 'Woza!', 'Shisa!', 'Wena!'],
  },
  {
    languageCode: 'xh',
    languageName: 'isiXhosa',
    nativeName: 'isiXhosa',
    vocalStyleAdvice: 'Lyrical, emotionally evocative delivery with crisp rhythmic phrasing and dynamic call-and-response.',
    phoneticNotes: 'Crisp articulation of lateral and alveolar clicks; soft aspiration on dental consonants.',
    adLibs: ['Ewe!', 'He ke!', 'Camagu!', 'Masambe!'],
  },
  {
    languageCode: 'nso',
    languageName: 'Sepedi',
    nativeName: 'Sesotho sa Leboa',
    vocalStyleAdvice: 'Grounded, storytelling-focused delivery with melodic praise poetry cadences and rich harmonic layering.',
    phoneticNotes: 'Clear vowel tones; gentle lateral fricatives (hl, tl).',
    adLibs: ['Agee!', 'Aowa!', 'Taba ke yeo!'],
  },
  {
    languageCode: 'st',
    languageName: 'Sesotho',
    nativeName: 'Sesotho',
    vocalStyleAdvice: 'Smooth, poetic, melodic storytelling with rich harmonic phrasing and traditional call-and-response.',
    phoneticNotes: '7-vowel harmony with distinct open-mid and close-mid vowels; sharp lateral affricates.',
    adLibs: ['Helele!', 'Ee!', 'Ke nnete!'],
  },
  {
    languageCode: 'tn',
    languageName: 'Setswana',
    nativeName: 'Setswana',
    vocalStyleAdvice: 'Lyrical folk cadences, rhythmic praise poetry, and expressive vocal dynamics.',
    phoneticNotes: 'Vowel height harmony, aspirated plosives (tlh, ph, th), and penultimate syllable elongation.',
    adLibs: ['Ahee!', 'Dumelang!', 'Gontse jalo!'],
  },
  {
    languageCode: 'ss',
    languageName: 'Siswati',
    nativeName: 'Siswati',
    vocalStyleAdvice: 'Passionate melodic delivery with royal praise chant cadences and syncopated choral backing.',
    phoneticNotes: 'Depressor consonant pitch lowering, dental/alveolar clicks, and warm vocal resonance.',
    adLibs: ['Yebo!', 'Woza!', 'Maye!'],
  },
  {
    languageCode: 'nr',
    languageName: 'isiNdebele',
    nativeName: 'isiNdebele',
    vocalStyleAdvice: 'Proud, rhythmic traditional chants with polyphonic chorus responses.',
    phoneticNotes: 'Click consonants, nasal noun prefixes, and strong penultimate syllable elongation.',
    adLibs: ['Iye!', 'Lotani!', 'Kunjalo!'],
  },
  {
    languageCode: 'ts',
    languageName: 'Xitsonga',
    nativeName: 'Xitsonga',
    vocalStyleAdvice: 'High-energy, fast-paced syncopation, vibrant vocal shouts, and bright melodic hooks.',
    phoneticNotes: 'Affricate combinations (pf, bv, ts) provide percussive drive in fast BPM arrangements.',
    adLibs: ['Inkomu!', 'Ahee!', 'Hi swona!'],
  },
];

export function getLanguageContext(langCode: string): MusicLanguageContext {
  const code = langCode.toLowerCase().split('-')[0];
  return (
    MUSIC_LANGUAGES.find((l) => l.languageCode === code) || {
      languageCode: code,
      languageName: 'African Dialect',
      nativeName: 'African Dialect',
      vocalStyleAdvice: 'Soulful African vocal delivery with authentic rhythm and regional warmth.',
      phoneticNotes: 'Natural speech rhythm adhering to authentic tone and cadence.',
      adLibs: ['Yebo!', 'Woza!', 'Eish!'],
    }
  );
}
