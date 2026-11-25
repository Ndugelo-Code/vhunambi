/**
 * Edge-compatible base64url keyset cursor encoder/decoder (zero Node Buffer).
 */
export interface ExploreCursorPayload {
  sortKey: string | number;
  id: string;
}

export function encodeExploreCursor(payload: ExploreCursorPayload): string {
  const bytes = new TextEncoder().encode(JSON.stringify(payload));
  let binary = '';
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

export function decodeExploreCursor(
  raw: string | undefined | null,
): ExploreCursorPayload | null {
  if (!raw || typeof raw !== 'string') return null;
  try {
    const padded = raw
      .replace(/-/g, '+')
      .replace(/_/g, '/')
      .padEnd(raw.length + ((4 - (raw.length % 4)) % 4), '=');
    const binary = atob(padded);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }
    const parsed = JSON.parse(new TextDecoder().decode(bytes)) as Record<
      string,
      unknown
    >;
    if (
      parsed &&
      typeof parsed === 'object' &&
      typeof parsed.id === 'string' &&
      parsed.id.length > 0 &&
      (typeof parsed.sortKey === 'string' || typeof parsed.sortKey === 'number')
    ) {
      return { sortKey: parsed.sortKey, id: parsed.id };
    }
    return null;
  } catch {
    return null;
  }
}
