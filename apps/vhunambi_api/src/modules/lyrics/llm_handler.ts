import type { Context } from 'hono';
import { resolveRuntimeEnv } from '../../config/env.js';
import type { VhunambiWorkerEnv } from '../../types/cloudflare_worker_types.js';
import { getLanguageContext } from '../bantu/language_context.js';
import { VENDA_IDIOMS } from '../bantu/tshi_venda.js';

export interface StanzaItem {
  type: string;
  header: string;
  lines: string[];
}

export interface GeneratedLyricsResult {
  rawLyrics: string;
  stanzas: StanzaItem[];
  vocalInstructions: string;
  detectedLanguage: string;
  moodAnalysis: string[];
  cultureTags: string[];
}

/**
 * Parses raw text with bracketed headers into structured stanzas
 */
export function parseStanzas(rawText: string): StanzaItem[] {
  const lines = rawText.split('\n');
  const stanzas: StanzaItem[] = [];
  let currentHeader = '[INTRO]';
  let currentLines: string[] = [];

  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      if (currentLines.length > 0) {
        stanzas.push({
          type: currentHeader.toLowerCase().replace(/[^a-z]/g, ''),
          header: currentHeader,
          lines: currentLines,
        });
        currentLines = [];
      }
      currentHeader = trimmed;
    } else if (trimmed.length > 0) {
      currentLines.push(trimmed);
    }
  }

  if (currentLines.length > 0) {
    stanzas.push({
      type: currentHeader.toLowerCase().replace(/[^a-z]/g, ''),
      header: currentHeader,
      lines: currentLines,
    });
  }

  return stanzas;
}

/**
 * High-fidelity offline generator for African music lyrics
 */
export function generateLocalMockLyrics(
  prompt: string,
  genre: string,
  language: string,
): GeneratedLyricsResult {
  const langCtx = getLanguageContext(language);
  const idiom =
    language.toLowerCase().startsWith('ve')
      ? VENDA_IDIOMS[0].phrase
      : 'Ubuntu ngumuntu ngabantu';

  const rawLyrics = `[INTRO]
${langCtx.adLibs[0] || 'Yebo!'}
${langCtx.adLibs[1] || 'Woza!'}
Vhunambi ha musika, the sound of the soil

[VERSE 1]
Walking through the morning mist where memories stay
Listening to the elders teaching us the ancient way
${idiom}
A rhythm born of resilience that never fades away

[PRE-CHORUS]
Hear the bassline speaking through the night
Every heart is beating with the morning light
${langCtx.adLibs[2] || 'Shisa!'}

[CHORUS]
This is our song, this is our sacred beat
Vhunambi rising strong on every township street
Sing it loud across the mountains, feel the groove so deep
A promise to our ancestors that we will always keep

[VERSE 2]
Through every trial and shadow we still rise and sing
With unity and love in every word we bring
${idiom}
The spirit of our heritage in everything

[OUTRO]
${langCtx.adLibs[3] || 'Aa!'}
Vhunambi musika...
The song remains forever.`;

  return {
    rawLyrics,
    stanzas: parseStanzas(rawLyrics),
    vocalInstructions: `${langCtx.vocalStyleAdvice} Rich harmonies and syncopated rhythmic ad-libs.`,
    detectedLanguage: langCtx.languageName,
    moodAnalysis: ['soulful', 'uplifting', 'resilient', 'celebratory'],
    cultureTags: ['ubuntu', 'township_culture', 'heritage', 'ancestral_resilience'],
  };
}

/**
 * Main LLM Dispatcher (Claude / xAI Grok / Mock)
 */
export async function generateLyricsFromLLM(
  prompt: string,
  genre: string,
  language: string,
  systemPrompt: string,
  cOrEnv?: Context | VhunambiWorkerEnv | Record<string, unknown> | null,
): Promise<GeneratedLyricsResult> {
  const runtimeEnv = resolveRuntimeEnv(cOrEnv);
  const userMessage = `Create authentic ${genre} lyrics based on prompt: "${prompt}". Requested language: ${language}. Maintain bracketed headers [INTRO], [VERSE 1], [CHORUS], etc.`;

  // 1. xAI Grok Provider (api.x.ai)
  if (runtimeEnv.ZR_LLM_PROVIDER === 'grok' && runtimeEnv.GROK_API_KEY) {
    try {
      const response = await fetch('https://api.x.ai/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${runtimeEnv.GROK_API_KEY}`,
        },
        body: JSON.stringify({
          model: 'grok-2-latest',
          temperature: 0.7,
          max_tokens: 1500,
          messages: [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: userMessage },
          ],
        }),
      });

      if (response.ok) {
        const data = (await response.json()) as {
          choices?: Array<{ message?: { content?: string } }>;
        };
        const rawLyrics = data.choices?.[0]?.message?.content?.trim() || '';
        if (rawLyrics) {
          const langCtx = getLanguageContext(language);
          return {
            rawLyrics,
            stanzas: parseStanzas(rawLyrics),
            vocalInstructions: langCtx.vocalStyleAdvice,
            detectedLanguage: langCtx.languageName,
            moodAnalysis: ['uplifting', 'authentic'],
            cultureTags: ['african_music', genre.toLowerCase()],
          };
        }
      }
    } catch (error) {
      console.warn(
        '[Lyrics] xAI Grok API call failed, falling back to local synthesis generator:',
        error,
      );
    }
  }

  // 2. Anthropic Claude Provider (api.anthropic.com)
  if (
    runtimeEnv.ANTHROPIC_API_KEY &&
    (runtimeEnv.ZR_LLM_PROVIDER === 'claude' || runtimeEnv.ZR_LLM_PROVIDER === 'grok')
  ) {
    try {
      const response = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': runtimeEnv.ANTHROPIC_API_KEY,
          'anthropic-version': '2023-06-01',
        },
        body: JSON.stringify({
          model: 'claude-3-5-sonnet-20241022',
          max_tokens: 1500,
          temperature: 0.7,
          system: systemPrompt,
          messages: [
            {
              role: 'user',
              content: userMessage,
            },
          ],
        }),
      });

      if (response.ok) {
        const data = (await response.json()) as {
          content: Array<{ text: string }>;
        };
        const rawLyrics = data.content[0]?.text || '';
        if (rawLyrics) {
          const langCtx = getLanguageContext(language);
          return {
            rawLyrics,
            stanzas: parseStanzas(rawLyrics),
            vocalInstructions: langCtx.vocalStyleAdvice,
            detectedLanguage: langCtx.languageName,
            moodAnalysis: ['uplifting', 'authentic'],
            cultureTags: ['african_music', genre.toLowerCase()],
          };
        }
      }
    } catch (error) {
      console.warn(
        '[Lyrics] Claude API call failed, falling back to local synthesis generator:',
        error,
      );
    }
  }

  // 3. Graceful local synthesis generator
  return generateLocalMockLyrics(prompt, genre, language);
}

/**
 * LLM-backed Lyric Refinement (Claude / xAI Grok) with deterministic offline idiom fallback.
 */
export async function refineLyricsWithLLM(
  params: {
    currentLyrics: string;
    refinementInstruction: string;
    idiomToInsert?: string;
    genre?: string;
    language?: string;
  },
  cOrEnv?: Context | VhunambiWorkerEnv | Record<string, unknown> | null,
): Promise<{ rawLyrics: string; stanzas: StanzaItem[]; provider: string }> {
  const runtimeEnv = resolveRuntimeEnv(cOrEnv);
  const systemPrompt =
    'You are an African lyric editor for VHUNAMBI Studio. Preserve bracketed section headers ([INTRO], [VERSE 1], [CHORUS], etc.) and refine the lyrics strictly according to the instruction.';
  const userMessage = [
    `Current lyrics:\n${params.currentLyrics}`,
    `\nRefinement instruction: ${params.refinementInstruction}`,
    params.idiomToInsert
      ? `\nIncorporate this authentic idiom naturally: ${params.idiomToInsert}`
      : '',
  ].join('');

  if (runtimeEnv.ZR_LLM_PROVIDER === 'grok' && runtimeEnv.GROK_API_KEY) {
    try {
      const response = await fetch('https://api.x.ai/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${runtimeEnv.GROK_API_KEY}`,
        },
        body: JSON.stringify({
          model: 'grok-2-latest',
          temperature: 0.65,
          max_tokens: 1500,
          messages: [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: userMessage },
          ],
        }),
      });
      if (response.ok) {
        const data = (await response.json()) as {
          choices?: Array<{ message?: { content?: string } }>;
        };
        const refined = data.choices?.[0]?.message?.content?.trim();
        if (refined) {
          return { rawLyrics: refined, stanzas: parseStanzas(refined), provider: 'grok' };
        }
      }
    } catch {
      // Fallback below
    }
  }

  if (runtimeEnv.ANTHROPIC_API_KEY && runtimeEnv.ZR_LLM_PROVIDER !== 'mock') {
    try {
      const response = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': runtimeEnv.ANTHROPIC_API_KEY,
          'anthropic-version': '2023-06-01',
        },
        body: JSON.stringify({
          model: 'claude-3-5-sonnet-20241022',
          max_tokens: 1500,
          temperature: 0.65,
          system: systemPrompt,
          messages: [{ role: 'user', content: userMessage }],
        }),
      });
      if (response.ok) {
        const data = (await response.json()) as {
          content: Array<{ text: string }>;
        };
        const refined = data.content[0]?.text?.trim();
        if (refined) {
          return { rawLyrics: refined, stanzas: parseStanzas(refined), provider: 'claude' };
        }
      }
    } catch {
      // Fallback below
    }
  }

  // Deterministic offline fallback
  let updatedLyrics = params.currentLyrics.trim();
  if (params.idiomToInsert && !updatedLyrics.includes(params.idiomToInsert)) {
    updatedLyrics = `${updatedLyrics}\n${params.idiomToInsert}`;
  }
  return {
    rawLyrics: updatedLyrics,
    stanzas: parseStanzas(updatedLyrics),
    provider: 'local_deterministic',
  };
}
