/**
 * Story-to-Lyrics (ZR-STORYLYRICS-001) deterministic transformer — Phase 36 Track B.
 *
 * v1 is intentionally deterministic and LLM-free: it restructures the creator's
 * OWN words into an authentic genre song form (section markers, hook placement,
 * ad-lib framing) and compiles a language-neutral genre DNA + language context
 * caption for ACE-Step. It does not invent or translate lyrics.
 *
 * Cultural law (from Zania Explore): Genre DNA and Language Context are kept
 * strictly separate. Genre DNA templates must never mention a language.
 */
import { MUSIC_LANGUAGES, getLanguageContext, type MusicLanguageContext } from '../bantu/language_context.js';
import { parseStanzas, type StanzaItem } from './llm_handler.js';

export const STORY_GENRES = ['amapiano', 'maskandi', 'gqom', 'gospel', 'kwaito', 'hiphop'] as const;
export type StoryGenre = (typeof STORY_GENRES)[number];

interface SectionSpec {
  tag: string;
  lines: number;
  /** Section is filled with the hook line (repeated). */
  hook?: boolean;
  /** Section is framed with an ad-lib when story lines run out. */
  adLibFill?: boolean;
}

export interface GenreDna {
  id: StoryGenre;
  name: string;
  bpm: number;
  /** Language-neutral production description. */
  promptTemplate: string;
  vocalStyle: string;
  structure: SectionSpec[];
  structureId: string;
}

export const GENRE_DNA: Record<StoryGenre, GenreDna> = {
  amapiano: {
    id: 'amapiano',
    name: 'Private School Amapiano',
    bpm: 114,
    promptTemplate:
      'Private School Amapiano, 114 BPM, heavy log drum bass, jazzy piano chords, rolling percussion, soulful vocal chops, deep sub bass',
    vocalStyle: 'soulful lead vocal chops with emotional ad-libs',
    structureId: 'amapiano_hook_driven',
    structure: [
      { tag: 'INTRO', lines: 2, adLibFill: true },
      { tag: 'VERSE 1', lines: 4 },
      { tag: 'PRE-CHORUS', lines: 2 },
      { tag: 'CHORUS', lines: 4, hook: true },
      { tag: 'VERSE 2', lines: 4 },
      { tag: 'CHORUS', lines: 4, hook: true },
      { tag: 'BRIDGE', lines: 2 },
      { tag: 'OUTRO', lines: 2, adLibFill: true },
    ],
  },
  maskandi: {
    id: 'maskandi',
    name: 'Maskandi',
    bpm: 128,
    promptTemplate:
      'Maskandi, 128 BPM, fingerpicked acoustic guitar (ukupika), concertina, walking bassline, stamping 4/4 rhythm, traditional storytelling lead with backing harmonies',
    vocalStyle: 'powerful storytelling lead with backing harmonies, no autotune',
    structureId: 'maskandi_storytelling',
    structure: [
      { tag: 'IZIHLABO / INTRO', lines: 3, adLibFill: true },
      { tag: 'VERSE 1', lines: 8 },
      { tag: 'INTERLUDE', lines: 1, adLibFill: true },
      { tag: 'VERSE 2', lines: 8 },
      { tag: 'CHORUS / REFRAIN', lines: 2, hook: true },
      { tag: 'VERSE 3', lines: 6 },
      { tag: 'OUTRO', lines: 2, adLibFill: true },
    ],
  },
  gqom: {
    id: 'gqom',
    name: 'Durban Gqom',
    bpm: 126,
    promptTemplate:
      'Durban Gqom, 126 BPM, heavy distorted kick drums, dark ambient drone synths, syncopated toms, frantic shaker patterns, aggressive chant vocals',
    vocalStyle: 'raw aggressive chanted vocals, call-and-response',
    structureId: 'gqom_chant_drops',
    structure: [
      { tag: 'DROP / CHANT 1', lines: 2, hook: true },
      { tag: 'BUILD-UP', lines: 1 },
      { tag: 'DROP 2', lines: 2, hook: true },
      { tag: 'BREAKDOWN', lines: 2, adLibFill: true },
      { tag: 'FINAL DROP', lines: 4, hook: true },
    ],
  },
  gospel: {
    id: 'gospel',
    name: 'South African Gospel',
    bpm: 96,
    promptTemplate:
      'South African Gospel, 96 BPM, Hammond organ, grand piano, brass accents, four-part choir harmonies, syncopated bass, spiritual crescendo',
    vocalStyle: 'solo testimony with full choir response, emotional crescendo',
    structureId: 'gospel_call_response',
    structure: [
      { tag: 'INTRO', lines: 2, adLibFill: true },
      { tag: 'SOLO VERSE 1', lines: 4 },
      { tag: 'CHORUS', lines: 4, hook: true },
      { tag: 'CALL AND RESPONSE', lines: 4 },
      { tag: 'CRESCENDO', lines: 2 },
      { tag: 'OUTRO / VAMP', lines: 2, hook: true },
    ],
  },
  kwaito: {
    id: 'kwaito',
    name: 'Kwaito',
    bpm: 100,
    promptTemplate:
      'Kwaito, 100 BPM, slow house-derived township bounce, deep bass, laid-back drum machine groove, chanted spoken-sung vocals',
    vocalStyle: 'laid-back spoken-sung township delivery with chanted hooks',
    structureId: 'kwaito_township_bounce',
    structure: [
      { tag: 'INTRO', lines: 2, adLibFill: true },
      { tag: 'VERSE 1', lines: 8 },
      { tag: 'HOOK', lines: 4, hook: true },
      { tag: 'VERSE 2', lines: 8 },
      { tag: 'HOOK', lines: 4, hook: true },
      { tag: 'OUTRO', lines: 2, adLibFill: true },
    ],
  },
  hiphop: {
    id: 'hiphop',
    name: 'SA Hip Hop',
    bpm: 98,
    promptTemplate:
      'South African hip hop, 98 BPM, punchy 808 bass, crisp snares, sampled keys, rhythmic bar-driven vocals',
    vocalStyle: 'confident bar-driven rap delivery with wordplay and hooks',
    structureId: 'hiphop_bars_hook',
    structure: [
      { tag: 'INTRO', lines: 2, adLibFill: true },
      { tag: 'VERSE 1', lines: 12 },
      { tag: 'HOOK', lines: 4, hook: true },
      { tag: 'VERSE 2', lines: 12 },
      { tag: 'HOOK', lines: 4, hook: true },
      { tag: 'OUTRO', lines: 2, adLibFill: true },
    ],
  },
};

export function normalizeGenre(input: string): StoryGenre | null {
  const k = input.trim().toLowerCase().replace(/[^a-z]/g, '');
  if (k === 'hiphop' || k === 'sahiphop' || k === 'rap') return 'hiphop';
  return (STORY_GENRES as readonly string[]).includes(k) ? (k as StoryGenre) : null;
}

/** Returns offending language names found in genre DNA text (empty = language-neutral). */
export function validateLanguageNeutrality(text: string): string[] {
  const lower = text.toLowerCase();
  const offenders: string[] = [];
  for (const l of MUSIC_LANGUAGES) {
    for (const name of new Set([l.languageName, l.nativeName])) {
      if (lower.includes(name.toLowerCase())) offenders.push(name);
    }
  }
  return offenders;
}

/** Splits free-form narrative into singable lines (own words, never rewritten). */
export function splitStoryIntoLines(story: string): string[] {
  const rough = story
    .replace(/\r/g, '')
    .split(/\n+|(?<=[.!?;])\s+/)
    .map((s) => s.trim())
    .filter((s) => s.length > 0);

  const lines: string[] = [];
  for (const seg of rough) {
    const words = seg.split(/\s+/);
    if (words.length <= 9) {
      lines.push(seg);
      continue;
    }
    // Long segment: break on commas first, then hard-chunk by 8 words.
    const parts = seg.split(/,\s*/).map((p) => p.trim()).filter(Boolean);
    for (const part of parts) {
      const w = part.split(/\s+/);
      if (w.length <= 9) {
        lines.push(part);
      } else {
        for (let i = 0; i < w.length; i += 8) lines.push(w.slice(i, i + 8).join(' '));
      }
    }
  }
  return lines;
}

/** Picks a hook: the shortest line with 2-8 words (fallback: first line). */
export function pickHookLine(lines: string[]): string {
  const candidates = lines.filter((l) => {
    const n = l.split(/\s+/).length;
    return n >= 2 && n <= 8;
  });
  const pool = candidates.length > 0 ? candidates : lines;
  return pool.reduce((best, l) => (l.length < best.length ? l : best), pool[0]);
}

export function compileAceStepCaption(
  genre: GenreDna,
  language: MusicLanguageContext,
  moods: string[],
): string {
  const parts = [
    genre.promptTemplate,
    `${genre.vocalStyle} in ${language.languageName}`,
    'culturally authentic South African production',
  ];
  if (moods.length > 0) parts.push(`${moods.join(', ')} mood`);
  return parts.join(', ');
}

export interface StoryTransformInput {
  storyText: string;
  genre: StoryGenre;
  baseLanguage: string;
  targetCognateLanguages?: string[];
  mood?: string[];
}

export interface StoryTransformOutput {
  structuredLyrics: string;
  stanzas: StanzaItem[];
  hookLine: string;
  genre: StoryGenre;
  genreStructureUsed: string;
  vocalInstructions: string;
  compiledCaption: string;
  language: { code: string; name: string };
  cognateTargets: string[];
  storyLineCount: number;
  version: 1;
}

export function transformStoryToLyrics(input: StoryTransformInput): StoryTransformOutput {
  const genre = GENRE_DNA[input.genre];
  const language = getLanguageContext(input.baseLanguage);

  const all = splitStoryIntoLines(input.storyText);
  if (all.length === 0) throw new Error('EMPTY_STORY');

  const hook = pickHookLine(all);
  const hookIdx = all.indexOf(hook);
  const narrative = all.filter((_, i) => i !== hookIdx);

  // Proportional allocation of narrative lines across non-hook sections.
  const narrativeSections = genre.structure.filter((s) => !s.hook);
  const slots = narrativeSections.reduce((n, s) => n + s.lines, 0);
  const ratio = Math.min(1, narrative.length / Math.max(1, slots));

  let cursor = 0;
  const adLibs = language.adLibs.length > 0 ? language.adLibs : ['Yebo!'];
  let adLibIdx = 0;
  const nextAdLib = () => adLibs[adLibIdx++ % adLibs.length];

  const blocks: string[] = [];
  for (const section of genre.structure) {
    const out: string[] = [];
    if (section.hook) {
      for (let i = 0; i < Math.min(section.lines, 2); i++) out.push(hook);
      // Alternate hook with an ad-lib to avoid pure repetition on long hooks.
      for (let i = 2; i < section.lines; i++) out.push(i % 2 === 0 ? hook : nextAdLib());
    } else {
      const take = Math.max(
        section.adLibFill ? 0 : 1,
        Math.round(section.lines * ratio),
      );
      const chunk = narrative.slice(cursor, cursor + take);
      cursor += chunk.length;
      if (section.adLibFill) out.push(nextAdLib());
      out.push(...chunk);
      if (out.length === 0) out.push(nextAdLib());
    }
    blocks.push(`[${section.tag}]\n${out.join('\n')}`);
  }

  // Any unplaced narrative lines are appended so no part of the creator's
  // story is silently dropped.
  if (cursor < narrative.length) {
    const rest = narrative.slice(cursor);
    let appended = false;
    for (let i = blocks.length - 1; i >= 0; i--) {
      if (/^\[(VERSE|SOLO VERSE|CALL AND RESPONSE|BUILD-UP|BREAKDOWN)/.test(blocks[i])) {
        blocks[i] = `${blocks[i]}\n${rest.join('\n')}`;
        appended = true;
        break;
      }
    }
    if (!appended && blocks.length > 0) {
      blocks[blocks.length - 1] = `${blocks[blocks.length - 1]}\n${rest.join('\n')}`;
    }
  }

  const structuredLyrics = blocks.join('\n\n');
  const moods = input.mood ?? [];

  const knownCodes = new Set(MUSIC_LANGUAGES.map((l) => l.languageCode));
  const cognateTargets = (input.targetCognateLanguages ?? []).filter(
    (c) => knownCodes.has(c) && c !== language.languageCode,
  );

  return {
    structuredLyrics,
    stanzas: parseStanzas(structuredLyrics),
    hookLine: hook,
    genre: input.genre,
    genreStructureUsed: genre.structureId,
    vocalInstructions: `${genre.vocalStyle} in ${language.languageName}. ${language.vocalStyleAdvice}`,
    compiledCaption: compileAceStepCaption(genre, language, moods),
    language: { code: language.languageCode, name: language.languageName },
    cognateTargets,
    storyLineCount: all.length,
    version: 1,
  };
}

