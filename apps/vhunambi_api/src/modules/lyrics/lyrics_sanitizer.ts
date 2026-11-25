/**
 * Lyric sanitizer for ACE-Step 1.5 XL & MiniMax Music 3.0.
 *
 * ACE-Step tokenizes non-structural words in brackets/parens as sung text unless
 * they are recognized arrangement or voice-turn cue headers. Phase 80 expands the
 * allowed tags to preserve `[Voice A]`, `[Voice B]`, `[Duet]`, `[Choir]`,
 * `[Call]`, `[Response]`, and solo breaks (`[Guitar Solo]`, `[Sax Solo]`,
 * `[Log Drum Drop]`) while still stripping arbitrary prose directions.
 */

const ALLOWED_SECTION =
  /^(intro|verse(?:\s*\d+)?|pre-?chorus|chorus(?:\s*\d+)?|bridge|outro|instrumental|hook|voice\s*[a-d]|duet|choir|call|response|guitar\s*solo|sax\s*solo|piano\s*solo|drum\s*solo|solo|drop|breakdown)$/;

const ALLOWED_MINIMAX_SECTION =
  /^(intro|verse(?:\s*\d+)?|pre-?chorus|chorus(?:\s*\d+)?|bridge|outro|instrumental|hook|voice\s*[a-d]|duet|choir|call|response|guitar\s*solo|sax\s*solo|piano\s*solo|drum\s*solo|solo|log\s*drum\s*drop|drop|breakdown)$/;

function toTitleCaseTag(label: string): string {
  return label
    .split(/(\s+|-)/)
    .map((part) =>
      /^[a-z]/.test(part)
        ? part.charAt(0).toUpperCase() + part.slice(1)
        : part,
    )
    .join('');
}

function normalizeSectionLabel(
  raw: string,
  allowedPattern: RegExp = ALLOWED_SECTION,
): string | null {
  const head = raw.split(/[:\-–—]/)[0]!.trim().toLowerCase().replace(/\s+/g, ' ');
  const label = head
    .replace(/^pre chorus$/, 'pre-chorus')
    .replace(/^prechorus$/, 'pre-chorus');
  return allowedPattern.test(label) ? label : null;
}

function sanitizeLyricsWithPattern(
  rawLyrics: string,
  allowedPattern: RegExp,
): string {
  if (!rawLyrics) return '';
  const out: string[] = [];

  for (const originalLine of rawLyrics.replace(/\r/g, '').split('\n')) {
    const line = originalLine.trim();
    if (!line) {
      if (out.length > 0 && out[out.length - 1] !== '') out.push('');
      continue;
    }

    const wholeTag = /^\[([^\]]*)\]$/.exec(line);
    if (wholeTag) {
      const label = normalizeSectionLabel(wholeTag[1]!, allowedPattern);
      if (label) out.push(`[${label}]`);
      continue;
    }

    // Lines that are only a parenthesized stage note are dropped.
    if (/^\([^)]*\)$/.test(line)) continue;

    // Inline tag followed by sung text: "[Voice A] Sing it loud" -> "[voice a]\nSing it loud".
    let rest = line;
    const leadingTag = /^\[([^\]]*)\]\s*(.*)$/.exec(rest);
    if (leadingTag) {
      const label = normalizeSectionLabel(leadingTag[1]!, allowedPattern);
      if (label) out.push(`[${label}]`);
      rest = leadingTag[2]!;
    }

    const cleaned = rest
      .replace(/\[[^\]]*\]/g, ' ')
      .replace(/\([^)]*\)/g, ' ')
      .replace(/\s{2,}/g, ' ')
      .trim();
    if (cleaned) out.push(cleaned);
  }

  while (out.length > 0 && out[0] === '') out.shift();
  while (out.length > 0 && out[out.length - 1] === '') out.pop();
  return out.join('\n');
}

export function sanitizeLyricsForAceStep(rawLyrics: string): string {
  return sanitizeLyricsWithPattern(rawLyrics, ALLOWED_SECTION);
}

/** Same cleaning, but UPPERCASE section headers for the Flutter lyrics-review parser. */
export function sanitizeLyricsForClient(rawLyrics: string): string {
  return sanitizeLyricsForAceStep(rawLyrics).replace(
    /^\[([^\]]+)\]$/gm,
    (_m, label: string) => `[${label.toUpperCase()}]`,
  );
}

/**
 * Formats cleaned lyrics specifically for the resolved synthesis engine.
 * MiniMax Music 3.0 preserves Title-Case duet & arrangement tags (`[Voice A]`,
 * `[Log Drum Drop]`, `[Guitar Solo]`), while ACE-Step strips `[Log drum drop]`
 * and uses canonical lowercase tags.
 */
export function formatLyricsForEngine(
  rawLyrics: string,
  resolvedEngine?: string,
): string {
  if (resolvedEngine === 'minimax_music_3') {
    return sanitizeLyricsWithPattern(rawLyrics, ALLOWED_MINIMAX_SECTION).replace(
      /^\[([^\]]+)\]$/gm,
      (_m, label: string) => `[${toTitleCaseTag(label)}]`,
    );
  }
  return sanitizeLyricsForAceStep(rawLyrics);
}
