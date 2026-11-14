/**
 * ACE-Step lyric sanitizer.
 *
 * ACE-Step tokenizes every non-structural word in the `lyrics` field as a word
 * to be SUNG. Production notes / stage directions such as
 * `[Log drum drop: heavy sub-808]` or `(Listen... hear that horn)` therefore get
 * vocalized. This keeps only the structural section tags ACE-Step understands
 * and strips every other bracketed / parenthesized fragment.
 */

const ALLOWED_SECTION =
  /^(intro|verse(?:\s*\d+)?|pre-?chorus|chorus(?:\s*\d+)?|bridge|outro|instrumental|hook)$/;

function normalizeSectionLabel(raw: string): string | null {
  // "[INTRO: 8 bars percussive shaker]" -> "intro"; "[Verse 1]" -> "verse 1"
  const head = raw.split(/[:\-–—]/)[0]!.trim().toLowerCase().replace(/\s+/g, ' ');
  const label = head.replace(/^pre chorus$/, 'pre-chorus').replace(/^prechorus$/, 'pre-chorus');
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

    // Lines that are only a parenthesized note are dropped entirely.
    if (/^\([^)]*\)$/.test(line)) continue;

    // Inline tag followed by sung text: "[CHORUS] Sing it loud" -> header + text.
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

  // Trim leading/trailing blank lines and collapse duplicates.
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
