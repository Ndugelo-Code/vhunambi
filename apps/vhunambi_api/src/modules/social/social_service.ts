import { nanoid } from 'nanoid';
import {
  ClipFeedPage,
  PublishClipRequest,
  PublishedClipDto,
} from './social_types.js';

/**
 * In-memory social store (Phase 18). Mirrors the `job_store` Map pattern —
 * the Flutter client treats the feed as the network source of truth, so a
 * durable store (Postgres / D1) is a drop-in replacement behind these fns.
 *
 * Map preserves insertion order, so the feed is materialised newest-first by
 * reversing the value iterator at read time.
 */
const clips = new Map<string, PublishedClipDto>();

/** Follower counts per creator id (REQ-SOC-08 / REQ-SOC-25). */
const followerCounts = new Map<string, number>();

/**
 * Single-demo-user follow graph. Production keys this by the authenticated
 * follower id; the API ships without auth yet, so we model one local follower
 * ("me") to drive the reactive Follow / Unfollow toggle + count.
 */
const following = new Set<string>();
const ME = 'vhunambi_user';

/** Demo owner used when a publish request omits explicit identity. */
const DEFAULT_CREATOR = {
  creatorId: 'creator_makhadzi',
  creatorUsername: 'makhadzi',
  creatorDisplayName: 'Makhadzi',
  creatorAvatarUrl: null as string | null,
  isCreatorVerified: true,
};

/** Newest-first ordered view of all clips. */
function orderedClips(): PublishedClipDto[] {
  return [...clips.values()].reverse();
}

/**
 * Normalizes a (possibly partial) client DNA payload into the canonical
 * `SongMetadataDna` JSON shape so the Flutter client's
 * `SongMetadataDna.fromJson` never crashes on missing `musical` / `vocals` /
 * `visualTheme` sub-objects (design.md §1.1 / content_studio model contract).
 */
function normalizeDna(
  partial: Record<string, unknown> | undefined,
  title: string,
  genre: string,
): Record<string, unknown> {
  const p = partial ?? {};
  const num = (v: unknown, fallback: number): number =>
    typeof v === 'number' && Number.isFinite(v) ? v : fallback;
  const str = (v: unknown, fallback: string): string =>
    typeof v === 'string' && v.length > 0 ? v : fallback;
  return {
    id: str(p.id, `dna_${title.replaceAll(/\s+/g, '_').toLowerCase()}`),
    version: str(p.version, '1.0'),
    title,
    genre,
    language: str(p.language, 'Tshivenḓa'),
    culturalContext: p.culturalContext ?? null,
    musical: {
      bpm: num((p.musical as { bpm?: unknown } | undefined)?.bpm, num(p.bpm, 112)),
      key: str((p.musical as { key?: unknown } | undefined)?.key, 'Am'),
      energyBracket: str(
        (p.musical as { energyBracket?: unknown } | undefined)?.energyBracket,
        'mid',
      ),
      durationSec: num(
        (p.musical as { durationSec?: unknown } | undefined)?.durationSec,
        180,
      ),
    },
    vocals: {
      deliveryMode: str(
        (p.vocals as { deliveryMode?: unknown } | undefined)?.deliveryMode,
        'melodic',
      ),
      gender: str((p.vocals as { gender?: unknown } | undefined)?.gender, 'male'),
      energy: str((p.vocals as { energy?: unknown } | undefined)?.energy, 'mid'),
      loras: (p.vocals as { loras?: unknown } | undefined)?.loras ?? [],
    },
    visualTheme: {
      mood: str((p.visualTheme as { mood?: unknown } | undefined)?.mood, str(p.mood, 'Cinematic')),
      comfyPrompt: str(
        (p.visualTheme as { comfyPrompt?: unknown } | undefined)?.comfyPrompt,
        `${genre} aesthetic, vibrant, cinematic`,
      ),
      negativePrompt: str(
        (p.visualTheme as { negativePrompt?: unknown } | undefined)
            ?.negativePrompt,
        'blurry, low quality, watermark, text, signature',
      ),
      seed: num((p.visualTheme as { seed?: unknown } | undefined)?.seed, 42),
      aspectRatio: str(
        (p.visualTheme as { aspectRatio?: unknown } | undefined)?.aspectRatio,
        '9:16',
      ),
    },
    alignment: Array.isArray(p.alignment) ? p.alignment : [],
  };
}

function makeClip(req: PublishClipRequest, id: string): PublishedClipDto {
  const creator = {
    creatorId: req.creatorId ?? DEFAULT_CREATOR.creatorId,
    creatorUsername: req.creatorUsername ?? DEFAULT_CREATOR.creatorUsername,
    creatorDisplayName:
        req.creatorDisplayName ?? DEFAULT_CREATOR.creatorDisplayName,
    creatorAvatarUrl: req.creatorAvatarUrl ?? DEFAULT_CREATOR.creatorAvatarUrl,
    isCreatorVerified: req.isCreatorVerified ?? DEFAULT_CREATOR.isCreatorVerified,
  };
  const genre = ((req.dna?.genre as string | undefined) ?? 'Amapiano');
  const dna = normalizeDna(req.dna, req.title, genre);
  const base = 'https://cdn.vhunambi.com/social';
  return {
    id,
    trackId: req.trackId,
    ...creator,
    title: req.title,
    caption: req.caption ?? '',
    tags: req.tags ?? [],
    genre,
    audioUrl: req.audioUrl ?? `${base}/${req.trackId}.mp3`,
    coverUrl: req.coverUrl ?? `${base}/${req.trackId}.jpg`,
    dna,
    playCount: 0,
    likeCount: 0,
    commentCount: 0,
    remixCount: 0,
    isLikedByMe: false,
    isSavedByMe: false,
    publishedAt: new Date().toISOString(),
  };
}

/** Publishes a clip and returns the share descriptor (design.md §5.1 response). */
export function publishClip(req: PublishClipRequest): {
  clipId: string;
  shareUrl: string;
  publishedAt: string;
} {
  const clipId = `clip_pub_${nanoid(8)}`;
  const clip = makeClip(req, clipId);
  clips.set(clipId, clip);
  if (!followerCounts.has(clip.creatorId)) {
    followerCounts.set(clip.creatorId, 0);
  }
  return {
    clipId,
    shareUrl: `https://vhunambi.com/@${clip.creatorUsername}/reels/${clipId}`,
    publishedAt: clip.publishedAt,
  };
}

/** Cursor-paginated newest-first feed (design.md §5.2). */
export function getFeed(cursor?: string, limit = 20): ClipFeedPage {
  const all = orderedClips();
  const offset = parseOffset(cursor);
  const size = clampLimit(limit);
  const page = all.slice(offset, offset + size);
  const nextIndex = offset + size;
  return {
    clips: page,
    nextCursor: nextIndex < all.length ? String(nextIndex) : null,
  };
}

/** All clips authored by a creator, newest-first (T1.3). */
export function getClipsByCreator(creatorId: string): PublishedClipDto[] {
  return orderedClips().filter((clip) => clip.creatorId === creatorId);
}

/** Toggles the demo user's like on a clip; returns null when not found. */
export function likeClip(
  clipId: string,
): { liked: boolean; likeCount: number } | null {
  const clip = clips.get(clipId);
  if (!clip) return null;
  clip.isLikedByMe = !clip.isLikedByMe;
  clip.likeCount = Math.max(0, clip.likeCount + (clip.isLikedByMe ? 1 : -1));
  return { liked: clip.isLikedByMe, likeCount: clip.likeCount };
}

/** Toggles the demo user's follow on a creator; returns state + count. */
export function followCreator(creatorId: string): {
  following: boolean;
  followerCount: number;
} {
  const key = `${ME}:${creatorId}`;
  const base = followerCounts.get(creatorId) ?? 0;
  const nowFollowing = !following.has(key);
  if (nowFollowing) following.add(key);
  else following.delete(key);
  const count = Math.max(0, base + (nowFollowing ? 1 : -1));
  followerCounts.set(creatorId, count);
  return { following: nowFollowing, followerCount: count };
}

/** Test/observability helper — total stored clips. */
export function countClips(): number {
  return clips.size;
}

function parseOffset(cursor?: string): number {
  if (!cursor) return 0;
  const n = Number.parseInt(cursor, 10);
  return Number.isFinite(n) && n > 0 ? n : 0;
}

function clampLimit(limit: number): number {
  if (!Number.isFinite(limit) || limit <= 0) return 20;
  return Math.min(limit, 50);
}


/**
 * Seeds a small catalogue so the feed & creator grids are never empty on a
 * cold start. Idempotent (guarded by store size) so repeated imports — e.g.
 * across test files in one process — do not duplicate entries.
 */
export function seedSocialClips(): void {
  if (clips.size > 0) return;

  publishClip({
    trackId: 'track_amapiano_101',
    title: 'Ndo Mufuna Matibe',
    caption:
        'New late-night piano vibe featuring indigenous live percussion! 🎹🔥',
    tags: ['Amapiano', 'Tshivenḓa', 'DeepSoul'],
    visibility: 'public',
    dna: {
      genre: 'Amapiano',
      bpm: 113,
      mood: 'Uplifting',
      paletteId: 'sunsetGold',
      typographyPreset: 'karaokeBounce',
      timestamps: [],
    },
  });
  publishClip({
    trackId: 'track_gqom_204',
    title: 'Township Log Drum Heat',
    caption: 'Durban energy, straight from the shins. #Gqom',
    tags: ['Gqom', 'Durban'],
    visibility: 'public',
    dna: {
      genre: 'Gqom',
      bpm: 127,
      mood: 'Intense',
      paletteId: 'neonNight',
      typographyPreset: 'boldPunch',
      timestamps: [],
    },
  });
  publishClip({
    trackId: 'track_afrohouse_77',
    title: 'Sunset Gold Sessions',
    caption: 'Afro House for golden hour drives 🌅',
    tags: ['AfroHouse', 'Sunset'],
    visibility: 'public',
    dna: {
      genre: 'Afro House',
      bpm: 122,
      mood: 'Dreamy',
      paletteId: 'sunsetGold',
      typographyPreset: 'softGlow',
      timestamps: [],
    },
  });

  // Pre-set engagement on the newest seed so the demo feed looks alive.
  const first = orderedClips()[0];
  if (first) {
    first.playCount = 24500;
    first.likeCount = 1840;
    first.commentCount = 96;
    first.remixCount = 12;
  }
}

seedSocialClips();
