import { env } from '../../config/env.js';
import { SongMetadataDNA } from '../dna/dna_types.js';

export const SYSTEM_VISION_PROMPT =
  'You are an expert prompt engineer for SDXL and FLUX.1. Convert the provided song metadata DNA, genre details, and lyrical theme into a visually stunning, single-paragraph album cover prompt in 9:16 vertical ratio. Focus on lighting, environment, cultural authenticity, colors, and camera angle. Output only the prompt text itself without conversational introductory text or quotes.';

/**
 * Deterministic local synthesizer when external LLM is offline or in mock mode.
 * Combines African genre visual aesthetics, mood, and cultural cues.
 */
export function synthesizeLocalVisionPrompt(
  dna: Pick<SongMetadataDNA, 'genre' | 'language' | 'musical' | 'visualTheme'> & {
    title?: string;
    region?: string;
    lyricsSnippet?: string;
  },
): string {
  const genreLower = dna.genre.toLowerCase();
  const moodLower = dna.visualTheme.mood.toLowerCase();

  // Curated genre-specific visual atmosphere tokens
  const atmosphereMap: Record<string, string> = {
    amapiano:
      'cinematic neon reflections of Johannesburg street lamps on wet asphalt, warm ambient Rhodes glow, late-night high-end township lounge aesthetic, 35mm film photography',
    gqom:
      'underground Durban warehouse rave, heavy raw strobes, dark industrial textures, deep shadows with saturated magenta and cyan laser accents, gritty film grain',
    maskandi:
      'scenic sweeping hills of KwaZulu-Natal at sunrise, warm golden hour rays illuminating traditional beadwork patterns, authentic acoustic heritage, majestic landscape photography',
    gospel:
      'celestial golden god rays piercing through dramatic clouds, ethereal volumetric lighting, warm cathedral ambiance, uplifting spiritual glory, hyper-detailed 8k',
    afrobeat:
      'vibrant Lagos street carnival, bold African wax print fabrics, dynamic festive energy, saturated sunset warmth, rich golden backlight, cinematic wide composition',
    afrohouse:
      'tribal electronic festival under a starlit African savanna night sky, glowing geometric body paint, warm firelight reflections, deep tribal ambiance',
  };

  const genreAtmosphere =
    atmosphereMap[genreLower] ||
    `${dna.genre} music aesthetic, vibrant African artistic expressions, warm studio lighting, highly detailed album cover art`;

  const lyricContext = dna.lyricsSnippet
    ? ` inspired by the theme: "${dna.lyricsSnippet.slice(0, 80)}"`
    : '';

  return (
    `Album cover art in 9:16 vertical ratio, ${genreAtmosphere}, ` +
    `evoking a ${moodLower} atmosphere${lyricContext}, ` +
    `ultra-high definition, professional color grading, studio master art quality, 8k resolution.`
  );
}

/**
 * Main prompt synthesizer: uses Claude/Grok if configured, or falls back to local synthesis.
 */
export async function synthesizeVisionPrompt(
  dna: SongMetadataDNA & { lyricsSnippet?: string },
): Promise<string> {
  const userContent =
    `Song Title: "${dna.title}"\n` +
    `Genre: ${dna.genre} (${dna.musical.bpm} BPM, Key: ${dna.musical.key})\n` +
    `Mood: ${dna.visualTheme.mood}\n` +
    `Language & Region: ${dna.language} (${dna.culturalContext?.region || 'Southern Africa'})\n` +
    (dna.lyricsSnippet ? `Lyrical Theme: "${dna.lyricsSnippet}"\n` : '');

  // 1. Anthropic Claude integration
  if (env.ZR_LLM_PROVIDER === 'claude' && env.ANTHROPIC_API_KEY) {
    try {
      const response = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': env.ANTHROPIC_API_KEY,
          'anthropic-version': '2023-06-01',
        },
        body: JSON.stringify({
          model: 'claude-3-5-sonnet-20241022',
          max_tokens: 300,
          system: SYSTEM_VISION_PROMPT,
          messages: [{ role: 'user', content: userContent }],
        }),
      });

      if (response.ok) {
        const data = (await response.json()) as {
          content: Array<{ text: string }>;
        };
        const text = data.content?.[0]?.text?.trim();
        if (text) return text;
      }
    } catch (e) {
      console.warn('[VisionPrompt] Claude API call failed, falling back to local synthesis:', e);
    }
  }

  // 2. xAI Grok integration
  if (env.ZR_LLM_PROVIDER === 'grok' && env.GROK_API_KEY) {
    try {
      const response = await fetch('https://api.x.ai/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${env.GROK_API_KEY}`,
        },
        body: JSON.stringify({
          model: 'grok-beta',
          messages: [
            { role: 'system', content: SYSTEM_VISION_PROMPT },
            { role: 'user', content: userContent },
          ],
          max_tokens: 300,
        }),
      });

      if (response.ok) {
        const data = (await response.json()) as {
          choices: Array<{ message: { content: string } }>;
        };
        const text = data.choices?.[0]?.message?.content?.trim();
        if (text) return text;
      }
    } catch (e) {
      console.warn('[VisionPrompt] Grok API call failed, falling back to local synthesis:', e);
    }
  }

  // 3. Fallback: High-fidelity deterministic local prompt synthesis
  return synthesizeLocalVisionPrompt(dna);
}
