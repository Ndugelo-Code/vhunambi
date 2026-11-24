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
  /^(intro|verse(?:\s*\d+)?|pre-?chorus|chorus(?:\s*\d+)?|bridge|outro|instrumental|hook|voice\s*[a-d]|duet|choir|call|response|guitar\s*solo|sax\s*solo|drop|breakdown)$/;

function normalizeSectionLabel(raw: string): string | null {
  const head = raw.split(/[:\-–—]/)[0]!.trim().toLowerCase().replace(/\s+/g, ' ');
  const label = head
    .replace(/^pre chorus$/, 'pre-chorus')
    .replace(/^prechorus$/, 'pre-chorus');
  return ALLOWED_SECTION.test(label) ? label : null;
}

export function sanitizeLyricsForAceStep(rawLyrics: string): string {
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
      const label = normalizeSectionLabel(wholeTag[1]!);
      if (label) out.push(`[${label}]`);
      continue;
    }

    // Lines that are only a parenthesized stage note are dropped.
    if (/^\([^)]*\)$/.test(line)) continue;

    // Inline tag followed by sung text: "[Voice A] Sing it loud" -> "[voice a]\nSing it loud".
    let rest = line;
    const leadingTag = /^\[([^\]]*)\]\s*(.*)$/.exec(rest);
    if (leadingTag) {
      const label = normalizeSectionLabel(leadingTag[1]!);
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

/** Same cleaning, but UPPERCASE section headers for the Flutter lyrics-review parser. */
export function sanitizeLyricsForClient(rawLyrics: string): string {
  return sanitizeLyricsForAceStep(rawLyrics).replace(
    /^\[([^\]]+)\]$/gm,
    (_m, label: string) => `[${label.toUpperCase()}]`,
  );
}
