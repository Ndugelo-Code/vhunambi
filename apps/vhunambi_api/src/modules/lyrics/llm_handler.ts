import type { Context } from 'hono';
import { resolveRuntimeEnv } from '../../config/env.js';
import type { VhunambiWorkerEnv } from '../../types/cloudflare_worker_types.js';
import { getLanguageContext } from '../bantu/language_context.js';
import { VENDA_IDIOMS, VENDA_MUSICAL_TERMS } from '../bantu/tshi_venda.js';
import { getGenrePreset } from '../synthesis/constants.js';

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

export interface SonicPromptPlan {
  expandedCaption: string;
  sonicTags: string[];
  arrangementStructure: string[];
  recommendedLoRA: {
    loraId: string;
    r2Key: string;
    weight: number;
  };
  llmEngine: string;
}

const STOP_WORDS = new Set([
  'the', 'and', 'for', 'with', 'about', 'that', 'this', 'from', 'into',
  'your', 'song', 'track', 'beat', 'music', 'make', 'create', 'write',
  'a', 'an', 'in', 'on', 'of', 'to', 'at', 'by', 'is', 'are', 'our', 'my',
]);

function hashPromptSeed(text: string): number {
  let h = 2166136261;
  for (let i = 0; i < text.length; i++) {
    h ^= text.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function extractPromptMotifs(prompt: string, genre: string): {
  primaryPhrase: string;
  keywords: string[];
} {
  const cleaned = prompt
    .replace(/[\r\n]+/g, ' ')
    .replace(/[^\p{L}\p{N}\s'-]/gu, ' ')
    .trim();
  const words = cleaned
    .split(/\s+/)
    .map((w) => w.trim())
    .filter((w) => w.length >= 3 && !STOP_WORDS.has(w.toLowerCase()));

  const unique: string[] = [];
  for (const w of words) {
    if (!unique.some((u) => u.toLowerCase() === w.toLowerCase())) {
      unique.push(w);
    }
    if (unique.length >= 6) break;
  }

  const primaryPhrase =
    cleaned.length > 0
      ? cleaned.slice(0, 68)
      : `${genre} Ubuntu celebration`;
  const keywords =
    unique.length > 0 ? unique : [genre, 'heritage', 'sunrise', 'rhythm'];

  return { primaryPhrase, keywords };
}

/**
 * Resolves and invokes the Sovereign Open-Source LLM deployed on RunPod Serverless
 * (`Qwen/Qwen2.5-7B-Instruct` / `meta-llama/Llama-3.1-8B-Instruct` via OpenAI-compatible vLLM API).
 */
export async function callRunPodOpenSourceLLM(
  systemPrompt: string,
  userMessage: string,
  cOrEnv?: Context | VhunambiWorkerEnv | Record<string, unknown> | null,
  temperature: number = 0.72,
  maxTokens: number = 1500,
): Promise<string | null> {
  const runtimeEnv = resolveRuntimeEnv(cOrEnv);
  if (runtimeEnv.ZR_LLM_PROVIDER === 'mock') {
    return null;
  }

  let endpointUrl = '';
  if (runtimeEnv.RUNPOD_LLM_URL) {
    const trimmed = runtimeEnv.RUNPOD_LLM_URL.replace(/\/+$/, '');
    if (trimmed.endsWith('/chat/completions')) {
      endpointUrl = trimmed;
    } else if (trimmed.endsWith('/v1')) {
      endpointUrl = `${trimmed}/chat/completions`;
    } else {
      endpointUrl = `${trimmed}/v1/chat/completions`;
    }
  } else if (runtimeEnv.RUNPOD_API_KEY && runtimeEnv.RUNPOD_LLM_ENDPOINT_ID) {
    endpointUrl = `https://api.runpod.ai/v2/${runtimeEnv.RUNPOD_LLM_ENDPOINT_ID}/openai/v1/chat/completions`;
  } else {
    return null;
  }

  try {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
    };
    if (runtimeEnv.RUNPOD_API_KEY) {
      headers['Authorization'] = `Bearer ${runtimeEnv.RUNPOD_API_KEY}`;
    }

    const response = await fetch(endpointUrl, {
      method: 'POST',
      headers,
      signal: AbortSignal.timeout(8000),
      body: JSON.stringify({
        model: runtimeEnv.RUNPOD_LLM_MODEL || 'Qwen/Qwen2.5-7B-Instruct',
        temperature,
        max_tokens: maxTokens,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userMessage },
        ],
      }),
    });

    if (!response.ok) {
      return null;
    }

    const data = (await response.json()) as {
      choices?: Array<{ message?: { content?: string }; text?: string }>;
      output?: {
        text?: string;
        choices?: Array<{ message?: { content?: string }; text?: string }>;
      };
    };

    const text =
      data.choices?.[0]?.message?.content?.trim() ||
      data.choices?.[0]?.text?.trim() ||
      data.output?.choices?.[0]?.message?.content?.trim() ||
      data.output?.text?.trim() ||
      '';
    return text.length > 0 ? text : null;
  } catch (error) {
    console.warn(
      '[Lyrics] RunPod Open-Source vLLM request failed, using deterministic composer:',
      error,
    );
    return null;
  }
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
 * Deterministic prompt-reactive Bantu & English multi-section lyric composer.
 * Distinct prompts reliably produce unique, culturally rooted verses, hooks, and imagery
 * even when external/RunPod vLLM workers are scaled down.
 */
export function generateLocalMockLyrics(
  prompt: string,
  genre: string,
  language: string,
): GeneratedLyricsResult {
  const langCtx = getLanguageContext(language);
  const preset = getGenrePreset(genre);
  const { primaryPhrase, keywords } = extractPromptMotifs(prompt, genre);
  const seed = hashPromptSeed(`${prompt}|${genre}|${language}`);

  const kw0 = keywords[0] ?? genre;
  const kw1 = keywords[1] ?? kw0;
  const kw2 = keywords[2] ?? langCtx.languageName;
  const kw3 = keywords[3] ?? preset.defaultMood;

  const langLower = language.toLowerCase();
  const idiomBank = langLower.startsWith('ve')
    ? VENDA_IDIOMS.map((item) => item.phrase)
    : langLower.startsWith('zu') || langLower.startsWith('xh')
      ? [
        'Ubuntu ngumuntu ngabantu',
        'Indlela ibuzwa kwabaphambili',
        'Izandla ziyagezana emculweni',
        'Ukhanya njengelanga ebusuku',
      ]
      : langLower.startsWith('st') ||
        langLower.startsWith('nso') ||
        langLower.startsWith('tn')
        ? [
          'Motho ke motho ka batho',
          'Pula ya medupe e na ka kgotso',
          'Kopano ke matla mo pineng ya rona',
          'Lesedi le bonesa tsela ya rona',
        ]
        : [
          'Ri a takala namusi, rhythm in unity',
          'Muthu ndi muthu nga vhathu',
          'From Limpopo hills to the glowing skyline',
          'Lwendo lu vhavhaho lu fhedza nga dakalo',
        ];

  const chosenIdiom = idiomBank[seed % idiomBank.length];
  const secondaryIdiom = idiomBank[(seed + 1) % idiomBank.length];
  const adLib0 = langCtx.adLibs[0] || 'Yebo!';
  const adLib1 = langCtx.adLibs[1] || 'Woza!';
  const adLib2 = langCtx.adLibs[2 % langCtx.adLibs.length] || adLib0;
  const adLib3 = langCtx.adLibs[3 % langCtx.adLibs.length] || adLib1;

  const grooveDescriptors = [
    'log-drum thunder shaking the warm red earth',
    'velvet Rhodes keys floating over midnight streets',
    'fingerpicked strings singing across mountain valleys',
    'syncopated percussion calling dancers into the circle',
  ];
  const grooveLine = grooveDescriptors[seed % grooveDescriptors.length];
  const chorusRefrain = `${chosenIdiom} — ${kw0} & ${kw1} in the ${genre} groove`;

  const rawLyrics = `[INTRO]
${adLib0}
${adLib1}
Vhunambi (${VENDA_MUSICAL_TERMS.ngoma}) — ${langCtx.nativeName} ${genre} Session

[VERSE 1]
Step into the ${kw0} light, carried on a ${preset.defaultBpm} BPM tide
${kw1} and ${kw2} moving side by side
${chosenIdiom}
With ${grooveLine}

[PRE-CHORUS]
Feel ${kw2} rising in the chest, every heartbeat tuned in ${preset.defaultKey}
Hold onto ${kw3} till the dawn breaks bright and new
${adLib2}

[CHORUS]
${chorusRefrain}
Every voice answering together: ${secondaryIdiom}
From ${kw0} to the stars, we lift the ${genre} crown
Sing it in ${langCtx.nativeName}, let the ancestral groove stay deep

[VERSE 2]
Yesterday's echoes turn to ${kw2} gold inside the sound
${kw1} footsteps drumming sacred patterns on the ground
${secondaryIdiom}
Voices woven strong in ${langCtx.nativeName} harmony

[BRIDGE]
Strip it back to breath and sub-bass pulse (${kw3})
Hear ${kw0} whispering through the choir and the drums
${adLib3}

[OUTRO]
${adLib0} (${kw0} forever...)
${chosenIdiom} — the rhythm remains in motion.`;

  return {
    rawLyrics,
    stanzas: parseStanzas(rawLyrics),
    vocalInstructions: `${langCtx.vocalStyleAdvice} Theme: ${primaryPhrase}. Groove: ${grooveLine}.`,
    detectedLanguage: langCtx.languageName,
    moodAnalysis: [preset.defaultMood, kw3.toLowerCase(), 'uplifting', 'authentic'],
    cultureTags: [
      'ubuntu',
      genre.toLowerCase().replace(/\s+/g, '_'),
      kw0.toLowerCase(),
      'heritage',
    ],
  };
}

/**
 * Two-Stage Prompt Expansion & LoRA Matcher for ACE-Step 1.5 (Phase 64).
 * Expands concise user prompts into rich musical captions, sonic tags, structure,
 * and regional .safetensors LoRA selection.
 */
export function planSonicArrangementFromPrompt(
  prompt: string,
  genre: string,
  language: string,
  bpm: number,
  musicalKey: string,
): SonicPromptPlan {
  const preset = getGenrePreset(genre);
  const langCtx = getLanguageContext(language);
  const cleanPrompt = prompt.trim() || `${genre} sunset groove`;
  const gNorm = (genre || 'amapiano').toLowerCase().replace(/[^a-z]/g, '');

  const loraMap: Record<
    string,
    { loraId: string; r2Key: string; weight: number }
  > = {
    amapiano: {
      loraId: 'amapiano_logdrum_v1',
      r2Key: 'loras/amapiano_logdrum_v1.safetensors',
      weight: 0.85,
    },
    privateschoolamapiano: {
      loraId: 'amapiano_logdrum_v1',
      r2Key: 'loras/amapiano_logdrum_v1.safetensors',
      weight: 0.85,
    },
    gqom: {
      loraId: 'gqom_durban_v1',
      r2Key: 'loras/gqom_durban_v1.safetensors',
      weight: 0.88,
    },
    maskandi: {
      loraId: 'maskandi_picking_v1',
      r2Key: 'loras/maskandi_picking_v1.safetensors',
      weight: 0.82,
    },
    venda: {
      loraId: 'venda_malende_v1',
      r2Key: 'loras/venda_malende_v1.safetensors',
      weight: 0.85,
    },
    afrobeats: {
      loraId: 'afrobeats_lagos_v1',
      r2Key: 'loras/afrobeats_lagos_v1.safetensors',
      weight: 0.80,
    },
    kwaito: {
      loraId: 'kwaito_township_v1',
      r2Key: 'loras/kwaito_township_v1.safetensors',
      weight: 0.82,
    },
    gospel: {
      loraId: 'afro_gospel_choir_v1',
      r2Key: 'loras/afro_gospel_choir_v1.safetensors',
      weight: 0.84,
    },
    afrohouse: {
      loraId: 'afrohouse_ancestral_v1',
      r2Key: 'loras/afrohouse_ancestral_v1.safetensors',
      weight: 0.85,
    },
  };
  const recommendedLoRA = loraMap[gNorm] ?? loraMap.amapiano;

  const sonicTags = [
    genre.toLowerCase(),
    `${bpm} bpm`,
    musicalKey.toLowerCase(),
    ...preset.instruments.map((i) => i.toLowerCase()),
    langCtx.languageName.toLowerCase(),
    '44.1khz stereo master',
    '-9.5 lufs commercial loudness',
  ];

  const arrangementStructure = [
    '[INTRO: 8 bars percussive shaker & atmospheric pad]',
    '[VERSE 1: 16 bars warm harmonic pocket & lead vocal entry]',
    '[CHORUS: 16 bars full log-drum sub-bass drop & call-and-response hook]',
    '[VERSE 2: 16 bars syncopated counter-melody & polyrhythmic groove]',
    '[BRIDGE: 8 bars stripped vocal & bass breakdown]',
    '[OUTRO: 8 bars dj-friendly stem fade]',
  ];

  const expandedCaption = [
    `Prompt theme: ${cleanPrompt}.`,
    `Genre: ${genre}.`,
    `Style: ${preset.characteristicStyle}.`,
    `Instruments: ${preset.instruments.join(', ')}.`,
    `Tempo: ${bpm} BPM. Key: ${musicalKey}.`,
    `Vocal direction: ${langCtx.vocalStyleAdvice}`,
    `Arrangement: ${arrangementStructure.join(' -> ')}.`,
    'High fidelity studio master, 320kbps production quality.',
  ].join(' ');

  return {
    expandedCaption,
    sonicTags,
    arrangementStructure,
    recommendedLoRA,
    llmEngine: 'runpod_qwen2_5_7b_open_source_planner',
  };
}

/**
 * Optional async Stage-1 Open-Source RunPod vLLM prompt expansion with immediate local fallback.
 */
export async function expandPromptWithOpenSourceLLM(
  prompt: string,
  genre: string,
  language: string,
  bpm: number,
  musicalKey: string,
  cOrEnv?: Context | VhunambiWorkerEnv | Record<string, unknown> | null,
): Promise<SonicPromptPlan> {
  const basePlan = planSonicArrangementFromPrompt(
    prompt,
    genre,
    language,
    bpm,
    musicalKey,
  );
  const sys =
    'You are an African music producer expanding a brief song idea into a concise single-paragraph ACE-Step acoustic production tag prompt including tempo, key, instrumentation, and vocal timbre.';
  const usr = `Expand this prompt for ${genre} in ${language} (${bpm} BPM, ${musicalKey}): "${prompt}"`;

  const llmExpanded = await callRunPodOpenSourceLLM(sys, usr, cOrEnv, 0.55, 220);
  if (llmExpanded && llmExpanded.length >= 24) {
    return {
      ...basePlan,
      expandedCaption: `${llmExpanded} Genre: ${genre}. Tempo: ${bpm} BPM. Key: ${musicalKey}.`,
    };
  }
  return basePlan;
}

/**
 * Main LLM Dispatcher (Sovereign RunPod Open-Source vLLM -> optional Grok/Claude -> Prompt-Reactive Composer)
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

  // 1. Sovereign Open-Source RunPod vLLM (Qwen2.5-7B-Instruct / Llama-3.1-8B-Instruct)
  const runpodLyrics = await callRunPodOpenSourceLLM(
    systemPrompt,
    userMessage,
    cOrEnv,
    0.72,
    1500,
  );
  if (runpodLyrics) {
    const langCtx = getLanguageContext(language);
    return {
      rawLyrics: runpodLyrics,
      stanzas: parseStanzas(runpodLyrics),
      vocalInstructions: langCtx.vocalStyleAdvice,
      detectedLanguage: langCtx.languageName,
      moodAnalysis: ['uplifting', 'authentic'],
      cultureTags: ['african_music', genre.toLowerCase(), 'runpod_open_source_llm'],
    };
  }

  // 2. Optional legacy xAI Grok Provider (api.x.ai)
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

  // 3. Optional legacy Anthropic Claude Provider (api.anthropic.com)
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

  // 4. Prompt-reactive offline composer
  return generateLocalMockLyrics(prompt, genre, language);
}

/**
 * LLM-backed Lyric Refinement (Sovereign RunPod vLLM -> optional Grok/Claude -> offline idiom insert).
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

  // 1. Sovereign Open-Source RunPod vLLM
  const runpodRefined = await callRunPodOpenSourceLLM(
    systemPrompt,
    userMessage,
    cOrEnv,
    0.65,
    1500,
  );
  if (runpodRefined) {
    return {
      rawLyrics: runpodRefined,
      stanzas: parseStanzas(runpodRefined),
      provider: 'runpod_vllm',
    };
  }

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

  if (runtimeEnv.ANTHROPIC_API_KEY && runtimeEnv.ZR_LLM_PROVIDER === 'claude') {
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
