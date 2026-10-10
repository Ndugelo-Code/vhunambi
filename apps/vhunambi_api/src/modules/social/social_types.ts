/**
 * Phase 18 · Social Creator Network — domain types.
 *
 * These DTOs mirror the Dart `PublishedClip` entity
 * (`lib/features/social/domain/models/published_clip.dart`) so the client's
 * `PublishedClip.fromJson` maps 1:1 onto these payloads, and match the REST
 * contract in `docs/phases/phase_18_social_creator_network/design.md §5`.
 */

/** Clip visibility selector (REQ-SOC-02). */
export type ClipVisibility = 'public' | 'followers';

/** Request body for `POST /api/social/publish` (design.md §5.1). */
export interface PublishClipRequest {
  trackId: string;
  title: string;
  caption: string;
  tags: string[];
  visibility: ClipVisibility;
  /** Immutable SongMetadataDNA powering zero-video vector canvas playback. */
  dna: Record<string, unknown>;
  /** Optional publisher identity — defaults to the demo owner when omitted. */
  creatorId?: string;
  creatorUsername?: string;
  creatorDisplayName?: string;
  creatorAvatarUrl?: string;
  isCreatorVerified?: boolean;
  /** Optional media references — synthesized placeholders when omitted. */
  audioUrl?: string;
  coverUrl?: string;
}

/** Wire DTO for a published clip (design.md §1.1 PublishedClip). */
export interface PublishedClipDto {
  id: string;
  trackId: string;
  creatorId: string;
  creatorUsername: string;
  creatorDisplayName: string;
  creatorAvatarUrl: string | null;
  isCreatorVerified: boolean;
  title: string;
  caption: string;
  tags: string[];
  genre: string;
  audioUrl: string;
  coverUrl: string;
  dna: Record<string, unknown>;
  playCount: number;
  likeCount: number;
  commentCount: number;
  remixCount: number;
  isLikedByMe: boolean;
  isSavedByMe: boolean;
  publishedAt: string;
}

/** Cursor-paginated feed response (design.md §5.2). */
export interface ClipFeedPage {
  clips: PublishedClipDto[];
  nextCursor: string | null;
}
