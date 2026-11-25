/**
 * Edge-compatible weak FNV-1a 32-bit ETag helper (zero Node crypto/Buffer).
 */
export function computeEdgeEtag(payload: string): string {
  const bytes = new TextEncoder().encode(payload);
  let hash = 0x811c9dc5;
  for (let i = 0; i < bytes.length; i++) {
    hash ^= bytes[i];
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return `W/"${hash.toString(16).padStart(8, '0')}-${bytes.byteLength}"`;
}

export function isIfNoneMatchHit(
  ifNoneMatchHeader: string | undefined,
  currentEtag: string,
): boolean {
  if (!ifNoneMatchHeader) return false;
  const trimmed = ifNoneMatchHeader.trim();
  if (trimmed === '*') return true;
  const normalize = (tag: string) => tag.trim().replace(/^W\//i, '');
  const target = normalize(currentEtag);
  return trimmed.split(',').some((candidate) => normalize(candidate) === target);
}
