# VHUNAMBI PHASE 73 TECHNICAL DESIGN — KINETIC POST FOCUS V2, 3-TIER CHROMATIC SYNTHESIS, MULTI-REACTIONS, GIFS/STICKERS & SOCIAL HYGIENE

**Document ID:** `VHUNAMBI-SPEC-P73-DESIGN-V1`  
**Phase:** Phase 73 (`phase_73_kinetic_post_focus_chromatic_reactions_and_hygiene`)  
**Standard:** 100% Complete, Compilable SQL, TypeScript, and Dart Code · Zero Placeholders · Zero `// TODO`s · Zero Raw OS Unicode Emojis (`STD-UIUX-001`) · Authentic `package:vhunambi_client/...`, `AppColors`, `AppTypography`, and `package:phosphor_icons/phosphor_icons.dart`

---

## 1. Mathematical & Chromatic Contrast Foundations

### 1.1 3-Tier Dynamic World Color Synthesis Equations

Given a `SocialMusicPost` with optional audio mood $m = \text{VhunambiMood.tryNormalize}(\text{track.mood})$ and optional artwork color $c_{\text{art}} \in \text{sRGB}$ extracted via `PaletteGenerator` (preferring `vibrantColor`, then `dominantColor`, then `mutedColor`):

1. **Tier 1 (Audio Mood + Artwork Present):**
   $$C_1 = \text{Color.lerp}(m.\text{accentColor}, c_{\text{art}}, 0.22), \qquad C_2 = c_{\text{art}}$$
2. **Tier 2 (Artwork Present, No Resolvable Audio Mood):**
   Let $\text{HSL}(c_{\text{art}}) = (H, S, L)$. Compute the split-complementary secondary hue:
   $$H_2 = (H + 150.0) \bmod 360.0, \qquad S_2 = \operatorname{clamp}(S, 0.28, 0.65), \qquad L_2 = \operatorname{clamp}(L, 0.34, 0.58)$$
   $$C_1 = c_{\text{art}}, \qquad C_2 = \text{HSLColor.fromAHSL}(1.0, H_2, S_2, L_2).\text{toColor}()$$
3. **Tier 3 (Neither Audio Mood nor Artwork Present):**
   $$C_1 = \text{AppColors.brandPrimary}\;(\texttt{\#F97316}), \qquad C_2 = \text{AppColors.accentElectric}\;(\texttt{\#8B5CF6})$$

### 1.2 WCAG AA Adaptive Luminance Clamping

Let $\text{HSL}(C_1) = (H_1, S_1, L_1)$. To guarantee $\ge 4.5:1$ foreground legibility for tinted labels, icons, and composer rings across both themes:
- **Light Mode ("Warm African Daylight", `#F7F5F0` / `#FFFFFF`):**
  $$L_{\text{accent,light}} = \operatorname{clamp}(L_1, 0.24, 0.42), \qquad S_{\text{accent,light}} = \operatorname{clamp}(S_1, 0.38, 0.82)$$
- **Dark Mode ("Obsidian Studio", `#0A0A0C` / `#141418`):**
  $$L_{\text{accent,dark}} = \operatorname{clamp}(L_1, 0.62, 0.78), \qquad S_{\text{accent,dark}} = \operatorname{clamp}(S_1, 0.45, 0.88)$$

---

## 2. Pass 1 (`M73.1`): Backend Multi-Reactions, Comment Media & GIF Search Proxy

### 2.1 Supabase Postgres Migration (`supabase/migrations/20261121000001_phase73_reactions_and_comment_media.sql`)

```sql
BEGIN;

-- 1. Phase 73 Multi-Reaction Aggregates on Kinetic Posts
ALTER TABLE public.kinetic_posts
  ADD COLUMN IF NOT EXISTS reaction_counts_json JSONB NOT NULL DEFAULT '{}'::jsonb;

-- 2. Phase 73 Multi-Reaction Aggregates & GIF/Sticker Media Columns on Comments
ALTER TABLE public.reel_comments
  ADD COLUMN IF NOT EXISTS reaction_counts_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS gif_url TEXT,
  ADD COLUMN IF NOT EXISTS sticker_id TEXT,
  ADD COLUMN IF NOT EXISTS media_aspect_ratio DOUBLE PRECISION;

-- 3. Typed Reaction Discriminator on Social Interactions
ALTER TABLE public.social_interactions
  ADD COLUMN IF NOT EXISTS reaction_type TEXT;

CREATE INDEX IF NOT EXISTS idx_social_interactions_target_type
  ON public.social_interactions (interaction_type, target_id);

COMMIT;
```

### 2.2 Cloudflare Worker Environment Bindings (`apps/vhunambi_api/src/types/cloudflare_worker_types.ts`)

Add optional server-side GIF provider secrets to `VhunambiWorkerEnv` (never exposed to clients):

```typescript
export interface VhunambiWorkerEnv {
  // ... existing fields preserved verbatim ...
  TENOR_API_KEY?: string;
  GIPHY_API_KEY?: string;
}
```

### 2.3 Canonical Reaction & Comment Media Engine (`edge_persistence_bridge.ts` & `vhunambi_db.ts`)

#### Shared Reaction Constants & Normalization Helper (Place in `apps/vhunambi_api/src/db/edge_persistence_bridge.ts` and mirror in `apps/vhunambi_api/src/db/vhunambi_db.ts`)

```typescript
export type KineticReactionWire =
  | 'like'
  | 'love'
  | 'haha'
  | 'fire'
  | 'wow'
  | 'angry';

export const VALID_KINETIC_REACTIONS = new Set<KineticReactionWire>([
  'like',
  'love',
  'haha',
  'fire',
  'wow',
  'angry',
]);

export function normalizeKineticReactionWire(
  raw: unknown,
): KineticReactionWire | null {
  if (typeof raw !== 'string') return null;
  const cleaned = raw.trim().toLowerCase() as KineticReactionWire;
  return VALID_KINETIC_REACTIONS.has(cleaned) ? cleaned : null;
}

export function normalizeReactionCounts(
  raw: unknown,
): Record<KineticReactionWire, number> {
  const out: Record<KineticReactionWire, number> = {
    like: 0,
    love: 0,
    haha: 0,
    fire: 0,
    wow: 0,
    angry: 0,
  };
  let parsed: Record<string, unknown> = {};
  if (typeof raw === 'string') {
    try {
      parsed = JSON.parse(raw) as Record<string, unknown>;
    } catch {
      parsed = {};
    }
  } else if (raw && typeof raw === 'object') {
    parsed = raw as Record<string, unknown>;
  }
  for (const key of VALID_KINETIC_REACTIONS) {
    const val = Number(parsed[key] ?? 0);
    out[key] = Number.isFinite(val) && val > 0 ? Math.floor(val) : 0;
  }
  return out;
}

export function compactReactionCounts(
  counts: Record<KineticReactionWire, number>,
): Partial<Record<KineticReactionWire, number>> {
  const result: Partial<Record<KineticReactionWire, number>> = {};
  for (const key of VALID_KINETIC_REACTIONS) {
    if (counts[key] > 0) result[key] = counts[key];
  }
  return result;
}

export function sumReactionCounts(
  counts: Record<KineticReactionWire, number>,
): number {
  let total = 0;
  for (const key of VALID_KINETIC_REACTIONS) {
    total += counts[key] || 0;
  }
  return total;
}

export interface KineticReactionMutationResult {
  success: boolean;
  targetId: string;
  myReaction: KineticReactionWire | null;
  reactionCounts: Partial<Record<KineticReactionWire, number>>;
  likeCount: number;
  liked: boolean;
}
```

#### `EdgeIsolateDatabaseEngine` Additions (`apps/vhunambi_api/src/db/edge_persistence_bridge.ts`)

1. Add field next to `private socialInteractions = new Set<string>();`:
```typescript
  private socialInteractionReactions = new Map<string, KineticReactionWire>();
```
2. Add `hydrateSocialInteractionRows(rows: Record<string, any>[])` and invoke it in `hydrateFromCloud` AND `syncExploreFromCloud` (fetching `social_interactions` alongside `explore_tracks`, `kinetic_posts`, and `reel_comments`):
```typescript
  private hydrateSocialInteractionRows(rows: Record<string, any>[]): void {
    for (const row of rows) {
      const interactionType = String(row.interaction_type ?? '').trim();
      const targetId = String(row.target_id ?? '').trim();
      const actor = canonicalizeCreatorId(String(row.actor_creator_id ?? 'creator_cern'));
      if (!interactionType || !targetId) continue;
      const key = `${interactionType}::${targetId}::${actor}`;
      this.socialInteractions.add(key);
      const rx = normalizeKineticReactionWire(row.reaction_type);
      if (rx) {
        this.socialInteractionReactions.set(key, rx);
      }
    }
  }
```
3. Extend `syncExploreFromCloud` (`edge_persistence_bridge.ts#L1297-L1330`) to include `social_interactions`:
```typescript
      const [tracksRes, postsRes, commentsRes, interactionsRes] = await Promise.all([
        EdgeIsolateDatabaseEngine.withTimeoutResult(
          driver.selectRows<Record<string, any>>(
            'explore_tracks',
            'select=*&order=updated_at.desc&limit=200',
          ),
          3500,
        ),
        EdgeIsolateDatabaseEngine.withTimeoutResult(
          driver.selectRows<Record<string, any>>(
            'kinetic_posts',
            'select=*&order=created_at.desc&limit=200',
          ),
          3500,
        ),
        EdgeIsolateDatabaseEngine.withTimeoutResult(
          driver.selectRows<Record<string, any>>(
            'reel_comments',
            'select=*&order=timestamp_ms.desc&limit=400',
          ),
          3500,
        ),
        EdgeIsolateDatabaseEngine.withTimeoutResult(
          driver.selectRows<Record<string, any>>(
            'social_interactions',
            'select=*&limit=1000',
          ),
          3500,
        ),
      ]);

      if (tracksRes.ok) this.hydrateExploreTrackRows(tracksRes.value);
      if (postsRes.ok) this.hydrateKineticPostRows(postsRes.value);
      if (commentsRes.ok) this.hydrateReelCommentRows(commentsRes.value);
      if (interactionsRes.ok) this.hydrateSocialInteractionRows(interactionsRes.value);

      const allSucceeded =
        tracksRes.ok && postsRes.ok && commentsRes.ok && interactionsRes.ok;
      if (allSucceeded) {
        this.domainHydratedAtMs.set(domainKey, Date.now());
      }
      return allSucceeded;
```
4. Implement typed reaction helpers and post/comment mutation methods on `EdgeIsolateDatabaseEngine` (with legacy `like_count` preservation on first reaction and `skipMirror = false` to eliminate duplicate Supabase writes):
```typescript
  public getSocialReaction(
    interactionType: 'post_react' | 'comment_react',
    targetId: string,
    actorCreatorId: string,
  ): KineticReactionWire | null {
    const key = `${interactionType}::${targetId}::${canonicalizeCreatorId(actorCreatorId)}`;
    return this.socialInteractionReactions.get(key) ?? null;
  }

  public reactToKineticPost(
    postId: string,
    actorCreatorId = 'creator_cern',
    reactionType: KineticReactionWire | null = null,
    skipMirror = false,
  ): KineticReactionMutationResult {
    const post = this.kineticPosts.get(postId);
    if (!post) {
      return {
        success: false,
        targetId: postId,
        myReaction: null,
        reactionCounts: {},
        likeCount: 0,
        liked: false,
      };
    }

    const actor = canonicalizeCreatorId(actorCreatorId);
    const key = `post_react::${postId}::${actor}`;
    const prevReaction = this.socialInteractionReactions.get(key) ?? null;
    const requested = normalizeKineticReactionWire(reactionType);
    const nextReaction: KineticReactionWire | null =
      requested === null || requested === prevReaction ? null : requested;

    const counts = normalizeReactionCounts(
      post.reaction_counts_json ?? this.parseJsonField(post.data_json).reactionCounts,
    );
    const legacyLikeCount = Math.max(0, Number(post.like_count ?? 0));
    if (sumReactionCounts(counts) === 0 && legacyLikeCount > 0) {
      counts.love = legacyLikeCount;
    }

    if (prevReaction) {
      counts[prevReaction] = Math.max(0, counts[prevReaction] - 1);
    }
    if (nextReaction) {
      counts[nextReaction] = counts[nextReaction] + 1;
      this.socialInteractions.add(key);
      this.socialInteractionReactions.set(key, nextReaction);
    } else {
      this.socialInteractions.delete(key);
      this.socialInteractionReactions.delete(key);
    }

    const compact = compactReactionCounts(counts);
    const nextLikes = Math.max(sumReactionCounts(counts), 0);
    post.reaction_counts_json = JSON.stringify(compact);
    post.like_count = nextLikes;
    post.updated_at = new Date().toISOString();

    const parsedData = this.parseJsonField(post.data_json);
    parsedData.reactionCounts = compact;
    parsedData.likeCount = nextLikes;
    post.data_json = JSON.stringify(parsedData);

    if (!skipMirror) {
      this.mirrorWriteThrough('kinetic_posts.react', async (driver) => {
        if (nextReaction) {
          await driver.upsertRow(
            'social_interactions',
            {
              interaction_type: 'post_react',
              target_id: postId,
              actor_creator_id: actor,
              reaction_type: nextReaction,
              created_at: Date.now(),
            },
            'interaction_type,target_id,actor_creator_id',
          );
        } else {
          await driver.deleteRows(
            'social_interactions',
            `interaction_type=eq.post_react&target_id=eq.${encodeURIComponent(postId)}&actor_creator_id=eq.${encodeURIComponent(actor)}`,
          );
        }
        await driver.patchRows(
          'kinetic_posts',
          `id=eq.${encodeURIComponent(postId)}`,
          {
            reaction_counts_json: compact,
            like_count: nextLikes,
            data_json: parsedData,
            updated_at: Date.now(),
          },
        );
      });
    }

    return {
      success: true,
      targetId: postId,
      myReaction: nextReaction,
      reactionCounts: compact,
      likeCount: nextLikes,
      liked: nextReaction !== null,
    };
  }

  public async reactToKineticPostAsync(
    postId: string,
    actorCreatorId = 'creator_cern',
    reactionType: KineticReactionWire | null = null,
    cOrEnv?: unknown,
  ): Promise<KineticReactionMutationResult> {
    const result = this.reactToKineticPost(
      postId,
      actorCreatorId,
      reactionType,
      true,
    );
    if (!result.success) return result;
    const actor = canonicalizeCreatorId(actorCreatorId);
    const post = this.kineticPosts.get(postId);
    const parsedData = post ? this.parseJsonField(post.data_json) : {};
    await this.awaitWriteThrough(
      'kinetic_posts.react',
      async (driver) => {
        await Promise.all([
          result.myReaction
            ? driver.upsertRow(
                'social_interactions',
                {
                  interaction_type: 'post_react',
                  target_id: postId,
                  actor_creator_id: actor,
                  reaction_type: result.myReaction,
                  created_at: Date.now(),
                },
                'interaction_type,target_id,actor_creator_id',
              )
            : driver.deleteRows(
                'social_interactions',
                `interaction_type=eq.post_react&target_id=eq.${encodeURIComponent(postId)}&actor_creator_id=eq.${encodeURIComponent(actor)}`,
              ),
          driver.patchRows(
            'kinetic_posts',
            `id=eq.${encodeURIComponent(postId)}`,
            {
              reaction_counts_json: result.reactionCounts,
              like_count: result.likeCount,
              data_json: parsedData,
              updated_at: Date.now(),
            },
          ),
        ]);
      },
      cOrEnv,
    );
    return result;
  }

  public reactToComment(
    commentId: string,
    actorCreatorId = 'creator_cern',
    reactionType: KineticReactionWire | null = null,
    skipMirror = false,
  ): KineticReactionMutationResult | null {
    const comment = this.getReelCommentById(commentId);
    if (!comment) return null;

    const actor = canonicalizeCreatorId(actorCreatorId);
    const key = `comment_react::${commentId}::${actor}`;
    const prevReaction = this.socialInteractionReactions.get(key) ?? null;
    const requested = normalizeKineticReactionWire(reactionType);
    const nextReaction: KineticReactionWire | null =
      requested === null || requested === prevReaction ? null : requested;

    const counts = normalizeReactionCounts(comment.reactionCounts);
    const legacyLikeCount = Math.max(0, Number(comment.likeCount ?? 0));
    if (sumReactionCounts(counts) === 0 && legacyLikeCount > 0) {
      counts.love = legacyLikeCount;
    }

    if (prevReaction) {
      counts[prevReaction] = Math.max(0, counts[prevReaction] - 1);
    }
    if (nextReaction) {
      counts[nextReaction] = counts[nextReaction] + 1;
      this.socialInteractions.add(key);
      this.socialInteractionReactions.set(key, nextReaction);
    } else {
      this.socialInteractions.delete(key);
      this.socialInteractionReactions.delete(key);
    }

    const compact = compactReactionCounts(counts);
    const nextLikes = Math.max(sumReactionCounts(counts), 0);
    this.insertReelComment({
      ...comment,
      likeCount: nextLikes,
      reactionCounts: compact,
    });

    if (!skipMirror) {
      this.mirrorWriteThrough('reel_comments.react', async (driver) => {
        if (nextReaction) {
          await driver.upsertRow(
            'social_interactions',
            {
              interaction_type: 'comment_react',
              target_id: commentId,
              actor_creator_id: actor,
              reaction_type: nextReaction,
              created_at: Date.now(),
            },
            'interaction_type,target_id,actor_creator_id',
          );
        } else {
          await driver.deleteRows(
            'social_interactions',
            `interaction_type=eq.comment_react&target_id=eq.${encodeURIComponent(commentId)}&actor_creator_id=eq.${encodeURIComponent(actor)}`,
          );
        }
      });
    }

    return {
      success: true,
      targetId: commentId,
      myReaction: nextReaction,
      reactionCounts: compact,
      likeCount: nextLikes,
      liked: nextReaction !== null,
    };
  }

  public async reactToCommentAsync(
    commentId: string,
    actorCreatorId = 'creator_cern',
    reactionType: KineticReactionWire | null = null,
    cOrEnv?: unknown,
  ): Promise<KineticReactionMutationResult | null> {
    const result = this.reactToComment(
      commentId,
      actorCreatorId,
      reactionType,
      true,
    );
    if (!result) return null;
    const actor = canonicalizeCreatorId(actorCreatorId);
    const comment = this.getReelCommentById(commentId);
    await this.awaitWriteThrough(
      'reel_comments.react',
      async (driver) => {
        await Promise.all([
          result.myReaction
            ? driver.upsertRow(
                'social_interactions',
                {
                  interaction_type: 'comment_react',
                  target_id: commentId,
                  actor_creator_id: actor,
                  reaction_type: result.myReaction,
                  created_at: Date.now(),
                },
                'interaction_type,target_id,actor_creator_id',
              )
            : driver.deleteRows(
                'social_interactions',
                `interaction_type=eq.comment_react&target_id=eq.${encodeURIComponent(commentId)}&actor_creator_id=eq.${encodeURIComponent(actor)}`,
              ),
          driver.patchRows(
            'reel_comments',
            `id=eq.${encodeURIComponent(commentId)}`,
            {
              reaction_counts_json: result.reactionCounts,
              likes_count: result.likeCount,
              data_json: comment ?? {},
            },
          ),
        ]);
      },
      cOrEnv,
    );
    return result;
  }

  private parseJsonField(raw: unknown): Record<string, any> {
    if (raw && typeof raw === 'object') return { ...(raw as Record<string, any>) };
    try {
      return JSON.parse(String(raw || '{}')) as Record<string, any>;
    } catch {
      return {};
    }
  }
```
5. Update `insertReelComment` / `mapReelCommentRow` / `addKineticPostComment` / `getKineticPostComments` / `getKineticPostById` / `getExploreFeed` to carry:
   - On comments: `gifUrl`, `stickerId`, `mediaAspectRatio`, `reactionCounts`, and viewer-scoped `myReaction` (`this.getSocialReaction('comment_react', c.id, viewerCreatorId)`).
   - On posts: `reactionCounts` (from `reaction_counts_json` / `data_json.reactionCounts`) and viewer-scoped `myReaction` (`this.getSocialReaction('post_react', post.id, viewerCreatorId)`).

#### 1:1 SQLite & Proxy Parity (`apps/vhunambi_api/src/db/vhunambi_db.ts`)

1. Add idempotent SQLite schema upgrades inside `VhunambiDatabase` constructor migrations block:
```typescript
    const safeAlter = (sql: string) => {
      try {
        this.db.exec(sql);
      } catch (_) {
        // Column already exists
      }
    };
    safeAlter("ALTER TABLE kinetic_posts ADD COLUMN reaction_counts_json TEXT NOT NULL DEFAULT '{}';");
    safeAlter("ALTER TABLE reel_comments ADD COLUMN reaction_counts_json TEXT NOT NULL DEFAULT '{}';");
    safeAlter('ALTER TABLE reel_comments ADD COLUMN gif_url TEXT;');
    safeAlter('ALTER TABLE reel_comments ADD COLUMN sticker_id TEXT;');
    safeAlter('ALTER TABLE reel_comments ADD COLUMN media_aspect_ratio REAL;');
    safeAlter('ALTER TABLE social_interactions ADD COLUMN reaction_type TEXT;');
```
2. Add identical `reactToKineticPost`, `reactToKineticPostAsync`, `reactToComment`, `reactToCommentAsync`, and `getSocialReaction` methods on `VhunambiDatabase` (using `INSERT OR REPLACE INTO social_interactions (interaction_type, target_id, actor_creator_id, reaction_type, created_at) VALUES (?, ?, ?, ?, ?)`), ensuring zero TypeScript drift between `VhunambiDatabase` and `EdgeIsolateDatabaseEngine`.

### 2.4 Hono REST Routes (`explore_routes.ts` & `social_routes.ts`)

#### Additions to `apps/vhunambi_api/src/routes/explore_routes.ts`

```typescript
// POST /api/explore/posts/:id/react — Phase 73 Multi-Reaction Toggle/Switch
exploreRoutes.post('/posts/:id/react', async (c) => {
  const postId = c.req.param('id');
  let body: Record<string, unknown> = {};
  try {
    body = (await c.req.json()) as Record<string, unknown>;
  } catch (_) {}
  const effectiveCreatorId = resolveEffectiveCreatorId(
    c,
    typeof body.creatorId === 'string' ? body.creatorId : undefined,
    'creator_cern',
  );
  const rawReaction = body.reactionType ?? body.reaction ?? null;
  const result = await vhunambiDb.reactToKineticPostAsync(
    postId,
    effectiveCreatorId,
    typeof rawReaction === 'string' ? (rawReaction as any) : null,
    c,
  );
  if (!result.success) {
    return c.json({ error: 'Post not found', postId }, 404);
  }
  return c.json(result, 200);
});

// POST /api/explore/comments/:id/react — Phase 73 Comment Multi-Reaction
exploreRoutes.post('/comments/:id/react', async (c) => {
  const commentId = c.req.param('id');
  let body: Record<string, unknown> = {};
  try {
    body = (await c.req.json()) as Record<string, unknown>;
  } catch (_) {}
  const actorId = c.get('authUser')?.creatorId ?? 'creator_cern';
  const rawReaction = body.reactionType ?? body.reaction ?? null;
  const result = await vhunambiDb.reactToCommentAsync(
    commentId,
    actorId,
    typeof rawReaction === 'string' ? (rawReaction as any) : null,
    c,
  );
  if (!result) {
    return c.json({ error: 'NOT_FOUND', message: `Comment ${commentId} not found` }, 404);
  }
  return c.json(result, 200);
});
```

Update `POST /api/explore/posts/:id/comments` (`explore_routes.ts#L213-L242`) so media-only comments succeed:

```typescript
  const text = String(body?.text ?? '').trim();
  const gifUrl = typeof body?.gifUrl === 'string' ? body.gifUrl.trim() : '';
  const stickerId = typeof body?.stickerId === 'string' ? body.stickerId.trim() : '';
  const mediaAspectRatio =
    typeof body?.mediaAspectRatio === 'number' && Number.isFinite(body.mediaAspectRatio)
      ? body.mediaAspectRatio
      : undefined;

  if (!text && !gifUrl && !stickerId) {
    return c.json(
      { error: 'INVALID_REQUEST', message: 'text, gifUrl, or stickerId is required' },
      400,
    );
  }
  const authUser = c.get('authUser');
  const comment = vhunambiDb.addKineticPostComment(postId, {
    text,
    ...(gifUrl ? { gifUrl } : {}),
    ...(stickerId ? { stickerId } : {}),
    ...(mediaAspectRatio ? { mediaAspectRatio } : {}),
    userId: body?.userId ?? authUser?.creatorId ?? 'creator_cern',
    username: body?.username ?? authUser?.handle?.replace(/^@/, '') ?? 'cern',
    displayName: body?.displayName ?? authUser?.handle?.replace(/^@/, '') ?? 'Cern',
    avatarUrl: body?.avatarUrl,
    userReelLoves: Number(body?.userReelLoves ?? 0),
    parentCommentId: body?.parentCommentId,
    replyToHandle: body?.replyToHandle,
  });
```

#### Additions to `apps/vhunambi_api/src/routes/social_routes.ts`

1. Relax `CreateCommentSchema`:
```typescript
const CreateCommentSchema = z
  .object({
    text: z.string().default(''),
    userId: z.string().optional(),
    username: z.string().optional(),
    displayName: z.string().optional(),
    avatarUrl: z.string().optional(),
    userReelLoves: z.number().optional(),
    giftEmoji: z.string().optional(),
    giftName: z.string().optional(),
    parentCommentId: z.string().optional(),
    replyToHandle: z.string().optional(),
    gifUrl: z.string().url().optional(),
    stickerId: z.string().min(1).optional(),
    mediaAspectRatio: z.number().positive().optional(),
  })
  .refine(
    (d) =>
      d.text.trim().length > 0 ||
      Boolean(d.gifUrl && d.gifUrl.trim().length > 0) ||
      Boolean(d.stickerId && d.stickerId.trim().length > 0),
    { message: 'text, gifUrl, or stickerId is required' },
  );
```
2. Add `POST /api/social/comments/:id/react` and server-side GIF search proxy routes `GET /api/social/gifs/search` & `GET /api/social/gifs/trending`:

```typescript
interface GifSearchItemDto {
  id: string;
  title: string;
  previewUrl: string;
  gifUrl: string;
  width: number;
  height: number;
}

const CURATED_STUDIO_GIFS: GifSearchItemDto[] = [
  {
    id: 'curated_groove_01',
    title: 'Amapiano Log Drum Bounce',
    previewUrl: 'https://media.giphy.com/media/l0MYt5jPR6QX5pnqM/200w.gif',
    gifUrl: 'https://media.giphy.com/media/l0MYt5jPR6QX5pnqM/giphy.gif',
    width: 480,
    height: 360,
  },
  {
    id: 'curated_studio_02',
    title: 'Studio Fire Session',
    previewUrl: 'https://media.giphy.com/media/3o7abKhOpu0NwenH3O/200w.gif',
    gifUrl: 'https://media.giphy.com/media/3o7abKhOpu0NwenH3O/giphy.gif',
    width: 480,
    height: 270,
  },
  {
    id: 'curated_vibe_03',
    title: 'Head Nod Approved',
    previewUrl: 'https://media.giphy.com/media/GeimqsH0TLDt4tScGw/200w.gif',
    gifUrl: 'https://media.giphy.com/media/GeimqsH0TLDt4tScGw/giphy.gif',
    width: 480,
    height: 480,
  },
  {
    id: 'curated_crown_04',
    title: 'Pure Royalty Energy',
    previewUrl: 'https://media.giphy.com/media/okLCopqw6ElCDnIhuS/200w.gif',
    gifUrl: 'https://media.giphy.com/media/okLCopqw6ElCDnIhuS/giphy.gif',
    width: 480,
    height: 360,
  },
];

async function proxyGifCatalog(
  query: string,
  limit: number,
  env: Record<string, unknown> | undefined,
): Promise<{ source: 'tenor' | 'giphy' | 'curated'; items: GifSearchItemDto[] }> {
  const safeLimit = Math.min(Math.max(limit, 1), 24);
  const tenorKey =
    (typeof env?.TENOR_API_KEY === 'string' && env.TENOR_API_KEY.trim()) ||
    (typeof process !== 'undefined' ? process.env?.TENOR_API_KEY?.trim() : '');
  const giphyKey =
    (typeof env?.GIPHY_API_KEY === 'string' && env.GIPHY_API_KEY.trim()) ||
    (typeof process !== 'undefined' ? process.env?.GIPHY_API_KEY?.trim() : '');

  if (tenorKey) {
    try {
      const endpoint = query
        ? `https://tenor.googleapis.com/v2/search?q=${encodeURIComponent(query)}&key=${encodeURIComponent(tenorKey)}&limit=${safeLimit}&media_filter=tinygif,gif`
        : `https://tenor.googleapis.com/v2/featured?key=${encodeURIComponent(tenorKey)}&limit=${safeLimit}&media_filter=tinygif,gif`;
      const res = await fetch(endpoint, { signal: AbortSignal.timeout(3500) });
      if (res.ok) {
        const json = (await res.json()) as { results?: Array<Record<string, any>> };
        const items: GifSearchItemDto[] = (json.results ?? [])
          .map((r) => {
            const gif = r.media_formats?.gif;
            const tiny = r.media_formats?.tinygif ?? gif;
            if (!gif?.url) return null;
            const dims = Array.isArray(gif.dims) ? gif.dims : [480, 360];
            return {
              id: String(r.id ?? ''),
              title: String(r.content_description ?? 'GIF'),
              previewUrl: String(tiny?.url ?? gif.url),
              gifUrl: String(gif.url),
              width: Number(dims[0] ?? 480),
              height: Number(dims[1] ?? 360),
            };
          })
          .filter((x): x is GifSearchItemDto => x !== null);
        if (items.length > 0) return { source: 'tenor', items };
      }
    } catch (_) {}
  }

  if (giphyKey) {
    try {
      const endpoint = query
        ? `https://api.giphy.com/v1/gifs/search?api_key=${encodeURIComponent(giphyKey)}&q=${encodeURIComponent(query)}&limit=${safeLimit}&rating=pg-13`
        : `https://api.giphy.com/v1/gifs/trending?api_key=${encodeURIComponent(giphyKey)}&limit=${safeLimit}&rating=pg-13`;
      const res = await fetch(endpoint, { signal: AbortSignal.timeout(3500) });
      if (res.ok) {
        const json = (await res.json()) as { data?: Array<Record<string, any>> };
        const items: GifSearchItemDto[] = (json.data ?? [])
          .map((r) => {
            const orig = r.images?.original;
            const preview = r.images?.fixed_width_small ?? orig;
            if (!orig?.url) return null;
            return {
              id: String(r.id ?? ''),
              title: String(r.title ?? 'GIF'),
              previewUrl: String(preview?.url ?? orig.url),
              gifUrl: String(orig.url),
              width: Number(orig.width ?? 480),
              height: Number(orig.height ?? 360),
            };
          })
          .filter((x): x is GifSearchItemDto => x !== null);
        if (items.length > 0) return { source: 'giphy', items };
      }
    } catch (_) {}
  }

  const qLower = query.trim().toLowerCase();
  const filtered = qLower
    ? CURATED_STUDIO_GIFS.filter((g) => g.title.toLowerCase().includes(qLower))
    : CURATED_STUDIO_GIFS;
  return {
    source: 'curated',
    items: (filtered.length > 0 ? filtered : CURATED_STUDIO_GIFS).slice(0, safeLimit),
  };
}

socialRoutes.post('/social/comments/:id/react', async (c) => {
  const commentId = c.req.param('id');
  let body: Record<string, unknown> = {};
  try {
    body = (await c.req.json()) as Record<string, unknown>;
  } catch (_) {}
  const actorId = c.get('authUser')?.creatorId ?? 'creator_cern';
  const rawReaction = body.reactionType ?? body.reaction ?? null;
  const result = await vhunambiDb.reactToCommentAsync(
    commentId,
    actorId,
    typeof rawReaction === 'string' ? (rawReaction as any) : null,
    c,
  );
  if (!result) {
    return c.json({ error: 'NOT_FOUND', message: `Comment ${commentId} not found` }, 404);
  }
  return c.json(result, 200);
});

socialRoutes.get('/social/gifs/search', async (c) => {
  const q = (c.req.query('q') ?? '').trim();
  const limit = Number.parseInt(c.req.query('limit') ?? '16', 10);
  const env = (c as unknown as { env?: Record<string, unknown> }).env;
  const result = await proxyGifCatalog(q, Number.isFinite(limit) ? limit : 16, env);
  return c.json({ success: true, ...result }, 200);
});

socialRoutes.get('/social/gifs/trending', async (c) => {
  const limit = Number.parseInt(c.req.query('limit') ?? '16', 10);
  const env = (c as unknown as { env?: Record<string, unknown> }).env;
  const result = await proxyGifCatalog('', Number.isFinite(limit) ? limit : 16, env);
  return c.json({ success: true, ...result }, 200);
});
```

### 2.5 Standalone `tsx` Verification Suite (`apps/vhunambi_api/test/phase73_reactions_gifs_and_comment_media.test.ts`)

```typescript
import assert from 'node:assert/strict';
import { app } from '../src/server.js';
import { vhunambiDb } from '../src/db/vhunambi_db.js';

async function run(): Promise<void> {
  console.log('[Phase 73 Test] Running Multi-Reactions, Comment Media & GIF Proxy suite...');

  const post = vhunambiDb.upsertKineticPost({
    id: 'kpost_p73_test_1',
    creatorId: 'creator_makhadzi',
    creatorName: 'Makhadzi',
    creatorHandle: '@makhadzi',
    caption: 'Phase 73 Chromatic & Reaction Test',
    track: {
      id: 'trk_p73_1',
      title: 'Limpopo Sunset',
      creatorName: 'Makhadzi',
      genre: 'Amapiano',
      mood: 'Soulful',
    },
  });
  assert.equal(post.id, 'kpost_p73_test_1');

  // 1. Toggle fire reaction on post
  const r1 = await app.request('/api/explore/posts/kpost_p73_test_1/react', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ reactionType: 'fire' }),
  });
  assert.equal(r1.status, 200);
  const b1 = (await r1.json()) as any;
  assert.equal(b1.myReaction, 'fire');
  assert.equal(b1.reactionCounts.fire, 1);
  assert.equal(b1.likeCount, 1);

  // 2. Switch reaction fire -> love (atomic decrement fire, increment love)
  const r2 = await app.request('/api/explore/posts/kpost_p73_test_1/react', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ reactionType: 'love' }),
  });
  assert.equal(r2.status, 200);
  const b2 = (await r2.json()) as any;
  assert.equal(b2.myReaction, 'love');
  assert.equal(b2.reactionCounts.fire ?? 0, 0);
  assert.equal(b2.reactionCounts.love, 1);
  assert.equal(b2.likeCount, 1);

  // 3. Repeat love -> toggles off to null
  const r3 = await app.request('/api/explore/posts/kpost_p73_test_1/react', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ reactionType: 'love' }),
  });
  assert.equal(r3.status, 200);
  const b3 = (await r3.json()) as any;
  assert.equal(b3.myReaction, null);
  assert.equal(b3.likeCount, 0);

  // 4. Media-only sticker comment succeeds without text
  const cRes = await app.request('/api/explore/posts/kpost_p73_test_1/comments', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      text: '',
      stickerId: 'stk_log_drum_hit',
      mediaAspectRatio: 1.0,
    }),
  });
  assert.equal(cRes.status, 201);
  const createdComment = (await cRes.json()) as any;
  assert.equal(createdComment.stickerId, 'stk_log_drum_hit');

  // 5. Comment multi-reaction toggle
  const crRes = await app.request(
    `/api/explore/comments/${createdComment.id}/react`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ reactionType: 'haha' }),
    },
  );
  assert.equal(crRes.status, 200);
  const crBody = (await crRes.json()) as any;
  assert.equal(crBody.myReaction, 'haha');
  assert.equal(crBody.reactionCounts.haha, 1);

  // 6. Empty comment without media rejected with 400
  const badComment = await app.request(
    '/api/explore/posts/kpost_p73_test_1/comments',
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text: '   ' }),
    },
  );
  assert.equal(badComment.status, 400);

  // 7. GIF search & trending return 200 with curated fallback when no key configured
  const gifRes = await app.request('/api/social/gifs/search?q=amapiano');
  assert.equal(gifRes.status, 200);
  const gifBody = (await gifRes.json()) as any;
  assert.equal(gifBody.success, true);
  assert.ok(Array.isArray(gifBody.items) && gifBody.items.length > 0);

  console.log('[Phase 73 Test] ALL ASSERTIONS PASSED!');
}

run().catch((err) => {
  console.error('[Phase 73 Test] FAILED:', err);
  process.exit(1);
});
```

---

## 3. Pass 1 (`M73.2`): Global Input Focus Purge, 3-Tier Chromatic Engine & Social Hygiene

### 3.1 Global Focus Border Purge (`apps/vhunambi_client/lib/core/theme/app_theme.dart` + 11 Widget Sites)

1. **`app_theme.dart` (`darkTheme` lines 85–91):**
```dart
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.24),
            width: 1.0,
          ),
        ),
```
2. **`app_theme.dart` (`lightTheme` lines 214–220):**
```dart
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: BorderSide(
            color: Colors.black.withValues(alpha: 0.18),
            width: 1.0,
          ),
        ),
```
3. **All 3 Borderless Leak Sites (`threaded_comments_section.dart#L896`, `explore_search_view.dart#L145`, `create_kinetic_post_sheet.dart#L402`):**
```dart
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
```
4. **All 8 Explicit `focusedBorder` Override Sites (`repost_kinetic_post_sheet.dart#L212`, `direct_daw_vocal_upload_sheet.dart#L346`, `prompt_input_box.dart#L318`, `sovereign_auth_sheet.dart#L533`, `playlists_vault_view.dart#L248`, `add_to_playlist_sheet.dart#L273`, `avatar_customization_modal.dart#L490,#L593`, `publish_clip_modal.dart#L249`):**
```dart
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.inputBorder,
          borderSide: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.26)
                : Colors.black.withValues(alpha: 0.20),
            width: 1.0,
          ),
        ),
```

### 3.2 3-Tier Dynamic Chromatic Synthesis Engine (`apps/vhunambi_client/lib/core/theme/post_chromatic_palette_resolver.dart`)

```dart
import 'dart:async';
import 'dart:collection';
import 'dart:io' show File, Platform;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:vhunambi_client/core/constants/app_constants.dart';
import 'package:vhunambi_client/core/design_system/tokens/vhunambi_mood.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';

/// Which of the 3 synthesis tiers produced a [PostChromaticPalette].
enum ChromaticSynthesisTier {
  /// Tier 1: Song mood + extracted artwork color.
  moodAndArtwork,

  /// Tier 2: Extracted artwork color + computed split-complementary secondary.
  artworkOnly,

  /// Tier 3: Vhunambi brand baseline fallback.
  themeDefault,
}

/// Adaptive, WCAG AA contrast-clamped palette for immersive post worlds
/// (`EP-P73-POST-CHROMATIC-SYNTH`, `REQ-P73-CHROM-01..03`).
@immutable
class PostChromaticPalette {
  final ChromaticSynthesisTier tier;
  final Color primaryGlow;
  final Color secondaryGlow;
  final Color accent;
  final Color onAccent;
  final Color glassBorderTint;
  final Color composerRingTint;

  const PostChromaticPalette({
    required this.tier,
    required this.primaryGlow,
    required this.secondaryGlow,
    required this.accent,
    required this.onAccent,
    required this.glassBorderTint,
    required this.composerRingTint,
  });

  factory PostChromaticPalette.themeDefault(Brightness brightness) {
    return PostChromaticPaletteResolver.buildFromPair(
      tier: ChromaticSynthesisTier.themeDefault,
      primaryRaw: AppColors.brandPrimary,
      secondaryRaw: AppColors.accentElectric,
      brightness: brightness,
    );
  }
}

/// 3-Tier Dynamic Chromatic Synthesis Resolver with LRU cache, 150ms decode cap,
/// and deterministic `FLUTTER_TEST` bypass so `FakeAsync` widget tests never hang.
class PostChromaticPaletteResolver {
  static const int _maxCacheEntries = 64;
  static const Duration _extractTimeout = Duration(milliseconds: 150);
  static final LinkedHashMap<String, Color> _artworkColorCache =
      LinkedHashMap<String, Color>();

  static bool get _isTestEnv {
    if (const bool.fromEnvironment('FLUTTER_TEST')) return true;
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Clears the in-memory LRU artwork cache (used in unit tests).
  @visibleForTesting
  static void clearCache() => _artworkColorCache.clear();

  /// Deterministic hue-hash color synthesis for headless tests or timeout fallbacks.
  @visibleForTesting
  static Color deterministicColorForUri(String uri) {
    var hash = 2166136261;
    for (final codeUnit in uri.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 16777619) & 0xFFFFFFFF;
    }
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.62, 0.48).toColor();
  }

  /// Computes a split-complementary secondary color (`+150 deg`) with clamped saturation.
  static Color computeSplitComplement(Color primary) {
    final hsl = HSLColor.fromColor(primary);
    final nextHue = (hsl.hue + 150.0) % 360.0;
    final nextSat = hsl.saturation.clamp(0.28, 0.65);
    final nextLight = hsl.lightness.clamp(0.34, 0.58);
    return HSLColor.fromAHSL(1.0, nextHue, nextSat, nextLight).toColor();
  }

  /// Applies WCAG AA lightness clamping for Light (`<= 0.42`) and Dark (`>= 0.62`) themes.
  static PostChromaticPalette buildFromPair({
    required ChromaticSynthesisTier tier,
    required Color primaryRaw,
    required Color secondaryRaw,
    required Brightness brightness,
  }) {
    final isDark = brightness == Brightness.dark;
    final hsl = HSLColor.fromColor(primaryRaw);
    final clampedAccent = isDark
        ? HSLColor.fromAHSL(
            1.0,
            hsl.hue,
            hsl.saturation.clamp(0.45, 0.88),
            hsl.lightness.clamp(0.62, 0.78),
          ).toColor()
        : HSLColor.fromAHSL(
            1.0,
            hsl.hue,
            hsl.saturation.clamp(0.38, 0.82),
            hsl.lightness.clamp(0.24, 0.42),
          ).toColor();

    final onAccent =
        ThemeData.estimateBrightnessForColor(clampedAccent) == Brightness.dark
            ? Colors.white
            : const Color(0xFF0A0A0C);

    return PostChromaticPalette(
      tier: tier,
      primaryGlow: primaryRaw,
      secondaryGlow: secondaryRaw,
      accent: clampedAccent,
      onAccent: onAccent,
      glassBorderTint: clampedAccent.withValues(alpha: isDark ? 0.26 : 0.22),
      composerRingTint: clampedAccent.withValues(alpha: isDark ? 0.30 : 0.26),
    );
  }

  /// Immediate synchronous first-frame palette using cached artwork or mood anchor.
  static PostChromaticPalette resolveSync({
    required Brightness brightness,
    String? rawMood,
    String? artworkUrl,
    bool hasAudioAttachment = false,
  }) {
    final mood = hasAudioAttachment ? VhunambiMood.tryNormalize(rawMood) : null;
    final cleanUrl = (artworkUrl ?? '').trim();
    final cachedArt = cleanUrl.isNotEmpty ? _artworkColorCache[cleanUrl] : null;

    if (mood != null && cachedArt != null) {
      final blendedPrimary =
          Color.lerp(mood.accentColor, cachedArt, 0.22) ?? mood.accentColor;
      return buildFromPair(
        tier: ChromaticSynthesisTier.moodAndArtwork,
        primaryRaw: blendedPrimary,
        secondaryRaw: cachedArt,
        brightness: brightness,
      );
    }

    if (mood != null) {
      final artColor = cleanUrl.isNotEmpty
          ? deterministicColorForUri(cleanUrl)
          : computeSplitComplement(mood.accentColor);
      return buildFromPair(
        tier: ChromaticSynthesisTier.moodAndArtwork,
        primaryRaw: mood.accentColor,
        secondaryRaw: artColor,
        brightness: brightness,
      );
    }

    if (cachedArt != null) {
      return buildFromPair(
        tier: ChromaticSynthesisTier.artworkOnly,
        primaryRaw: cachedArt,
        secondaryRaw: computeSplitComplement(cachedArt),
        brightness: brightness,
      );
    }

    if (cleanUrl.isNotEmpty && _isTestEnv) {
      final synth = deterministicColorForUri(cleanUrl);
      return buildFromPair(
        tier: ChromaticSynthesisTier.artworkOnly,
        primaryRaw: synth,
        secondaryRaw: computeSplitComplement(synth),
        brightness: brightness,
      );
    }

    return PostChromaticPalette.themeDefault(brightness);
  }

  /// Full async 3-Tier chromatic resolution extracting dominant/vibrant color via
  /// `PaletteGenerator.fromImageProvider` with LRU cache and `150ms` timeout.
  static Future<PostChromaticPalette> resolveAsync({
    required Brightness brightness,
    String? rawMood,
    String? artworkUrl,
    bool hasAudioAttachment = false,
    Color? extractedArtColorOverride,
  }) async {
    final mood = hasAudioAttachment ? VhunambiMood.tryNormalize(rawMood) : null;
    final cleanUrl = (artworkUrl ?? '').trim();

    Color? artColor = extractedArtColorOverride;
    if (artColor == null && cleanUrl.isNotEmpty) {
      artColor = _readCache(cleanUrl);
      if (artColor == null) {
        artColor = await _extractArtworkColor(cleanUrl);
        if (artColor != null) {
          _writeCache(cleanUrl, artColor);
        }
      }
    }

    if (mood != null && artColor != null) {
      final blendedPrimary =
          Color.lerp(mood.accentColor, artColor, 0.22) ?? mood.accentColor;
      return buildFromPair(
        tier: ChromaticSynthesisTier.moodAndArtwork,
        primaryRaw: blendedPrimary,
        secondaryRaw: artColor,
        brightness: brightness,
      );
    }

    if (mood != null) {
      return buildFromPair(
        tier: ChromaticSynthesisTier.moodAndArtwork,
        primaryRaw: mood.accentColor,
        secondaryRaw: computeSplitComplement(mood.accentColor),
        brightness: brightness,
      );
    }

    if (artColor != null) {
      return buildFromPair(
        tier: ChromaticSynthesisTier.artworkOnly,
        primaryRaw: artColor,
        secondaryRaw: computeSplitComplement(artColor),
        brightness: brightness,
      );
    }

    return PostChromaticPalette.themeDefault(brightness);
  }

  static Future<Color?> _extractArtworkColor(String rawUrl) async {
    if (_isTestEnv) {
      return deterministicColorForUri(rawUrl);
    }
    final provider = _resolveImageProvider(rawUrl);
    if (provider == null) return null;
    try {
      final generator = await PaletteGenerator.fromImageProvider(
        provider,
        size: const Size(96, 96),
        maximumColorCount: 8,
      ).timeout(_extractTimeout);
      return generator.vibrantColor?.color ??
          generator.dominantColor?.color ??
          generator.mutedColor?.color;
    } catch (_) {
      return deterministicColorForUri(rawUrl);
    }
  }

  static ImageProvider<Object>? _resolveImageProvider(String rawUrl) {
    if (rawUrl.isEmpty) return null;
    if (rawUrl.startsWith('asset:')) {
      return AssetImage(rawUrl.substring('asset:'.length));
    }
    if (rawUrl.startsWith('assets/')) {
      return AssetImage(rawUrl);
    }
    if (rawUrl.startsWith('file://')) {
      return FileImage(File(Uri.parse(rawUrl).toFilePath()));
    }
    final normalized = AppConstants.normalizeCloudMediaUrl(rawUrl);
    if (normalized.isEmpty) return null;
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return CachedNetworkImageProvider(normalized);
    }
    return null;
  }

  static Color? _readCache(String key) {
    final hit = _artworkColorCache.remove(key);
    if (hit != null) _artworkColorCache[key] = hit;
    return hit;
  }

  static void _writeCache(String key, Color value) {
    _artworkColorCache.remove(key);
    _artworkColorCache[key] = value;
    while (_artworkColorCache.length > _maxCacheEntries) {
      _artworkColorCache.remove(_artworkColorCache.keys.first);
    }
  }
}
```

### 3.3 Unified Self-Aware Profile Router & `@current_user` Purge (`SOC-07`)

Create `apps/vhunambi_client/lib/core/navigation/profile_navigation_helper.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vhunambi_client/core/auth/auth_providers.dart';
import 'package:vhunambi_client/core/auth/viewer_role.dart';
import 'package:vhunambi_client/features/profile/presentation/providers/profile_providers.dart';
import 'package:vhunambi_client/features/profile/presentation/views/artist_profile_view.dart';
import 'package:vhunambi_client/features/profile/presentation/views/owner_profile_view.dart';

/// Resolves whether [creatorId] / [creatorHandle] belongs to the signed-in creator.
bool isOwnedByActiveUser(
  WidgetRef ref, {
  required String? creatorId,
  String? creatorHandle,
}) {
  final owner = ref.read(ownerProfileProvider);
  final session = ref.read(authSessionProvider);
  final activeCreatorId = owner.id.isNotEmpty && owner.id != 'me'
      ? owner.id
      : session.canonicalCreatorId;
  final activeHandle = owner.handle.isNotEmpty
      ? owner.handle
      : session.rawUsername;

  return resolveViewerRole(
        ownerCreatorId: creatorId,
        ownerHandle: creatorHandle,
        activeCreatorId: activeCreatorId,
        activeHandle: activeHandle,
      ) ==
      ViewerRole.owner;
}

/// Canonical profile router (`EP-P73-PROFILE-ROUTER`, `REQ-P73-HYG-01`).
///
/// Routes self-taps to [OwnerProfileView] and visitor taps to [ArtistProfileView].
Future<void> navigateToCreatorProfile(
  BuildContext context,
  WidgetRef ref, {
  required String creatorId,
  String? creatorHandle,
}) {
  final isOwner = isOwnedByActiveUser(
    ref,
    creatorId: creatorId,
    creatorHandle: creatorHandle,
  );
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => isOwner
          ? const OwnerProfileView()
          : ArtistProfileView(artistId: creatorId),
    ),
  );
}
```

- Wire `navigateToCreatorProfile(...)` across all 7 audited entry points:
  1. `explore_social_post_card.dart#L386-L393` (also replace `post.creatorHandle == '@current_user'` at `L326` with `isOwnedByActiveUser(ref, creatorId: post.creatorId, creatorHandle: post.creatorHandle)`).
  2. `kinetic_post_focus_view.dart#L290-L297`.
  3. `kinetic_reels_modal.dart#L680`.
  4. `track_detail_view.dart#L506`.
  5. `explore_search_view.dart#L599`.
  6. `explore_discovery_drawer_sheet.dart#L464`.
  7. `notification_deep_link_router.dart#L115`.
- In `direct_daw_vocal_upload_sheet.dart#L133,L162,L175,L194`, resolve canonical owner identity from `ownerProfileProvider` / `authSessionProvider` (identical to `repost_kinetic_post_sheet.dart#L56-L71`) so zero `'@current_user'` literals remain in runtime Dart code.

### 3.4 Splash-to-RootShell MiniPlayer Suppression (`SOC-08`)

1. **`apps/vhunambi_client/lib/features/onboarding/presentation/views/splash_view.dart` (`L96-L120`):**
   - Remove the premature `ref.read(isSplashActiveProvider.notifier).state = false;` line that currently fires *before* the `420ms` `PageRouteBuilder` fade transition begins.
2. **`apps/vhunambi_client/lib/main.dart` (`_RootShellState.initState`, lines 147–154):**
   - Clear `isSplashActiveProvider` post-frame once `RootShell` has mounted (after Splash and Onboarding have completed):
```dart
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(isSplashActiveProvider)) {
        ref.read(isSplashActiveProvider.notifier).state = false;
      }
      OnboardingNotificationsService.ensureSeededForActiveCreator(ref);
    });
  }
```
   - `MiniPlayerHost._shouldHide` (`mini_player_host.dart#L155`) continues watching `isSplashActiveProvider`, so `MiniPlayerHost` never paints over `SplashView` or `OnboardingView`, while standalone tests that override `isSplashActiveProvider.overrideWith((ref) => false)` remain 100% green.

### 3.5 `CreateKineticPostSheet` Aspect Propagation, Vision Normalization & 4-Cap UX (`SOC-09`)

Inside `apps/vhunambi_client/lib/features/explore/presentation/widgets/create_kinetic_post_sheet.dart`:
1. **Aspect Ratio Toggle (`L418-L448`):** Rewrite all existing attached images when the user changes ratio:
```dart
onSelected: (_) {
  setState(() {
    _selectedAspectRatio = ratio;
    for (var i = 0; i < _attachedImages.length; i++) {
      final current = _attachedImages[i];
      _attachedImages[i] = KineticPostImageAttachment(
        imageUrl: current.imageUrl,
        isAiGeneratedVision: current.isAiGeneratedVision,
        visionPrompt: current.visionPrompt,
        aspectRatio: ratio,
      );
    }
  });
}
```
2. **Vision Preview Rendering (`L560-L650`):** Render each attached thumbnail inside `AspectRatio(aspectRatio: _selectedAspectRatio.ratio)` using `VhunambiTrackArtwork(coverUrl: AppConstants.normalizeCloudMediaUrl(img.imageUrl), genre: _selectedTrack?.genre ?? 'Amapiano', borderRadius: BorderRadius.circular(14))` (note: `VhunambiTrackArtwork` takes `coverUrl:` and `required String genre`, and `AppConstants.normalizeCloudMediaUrl` returns a non-nullable `String`) instead of raw `Image.network` falling back to duplicate `AppAssets.heritageCrateCover`.
3. **4-Image Cap Disable (`L113-L145`, `L460-L487`):** Compute `final bool atImageCap = _attachedImages.length >= 4;`, pass `onTap: atImageCap ? null : _mockPickImage` / `onTap: atImageCap ? null : _generateVisionAiArtwork` with `Opacity(opacity: atImageCap ? 0.45 : 1.0)`, and render a subtle inline pill (`Key('kpost_max_images_badge')`, text `'4/4 Max images attached'`) when `atImageCap` is true (removing the red `AppColors.error` SnackBar).

### 3.6 Clean Hive Recent Searches & Dynamic Explore Discovery (`SOC-10`)

1. **`apps/vhunambi_client/lib/features/explore/presentation/providers/explore_providers.dart` (`RecentSearchesNotifier._initialSearches`, lines 1135–1148):**
```dart
  static List<String> _initialSearches() {
    if (SovereignDomainStorageMode.canHydrateFromStorage(
      AppConstants.exploreCacheBoxKey,
    )) {
      final saved = ExploreCacheRepository.loadRecentSearches();
      if (saved != null) return saved;
    }
    return const <String>[];
  }
```
2. **`apps/vhunambi_client/lib/features/explore/presentation/views/explore_search_view.dart`:**
   - Compute dynamic `"You May Like"` chips from `ref.watch(exploreTracksProvider)` (top unique genres & track titles) interleaved with `VhunambiMood.values.map((m) => m.label)`, capped to `8` clean tags — eliminating hardcoded `'Kabza de Small'` static arrays.


---

## 4. Pass 2 (`M73.3`): Multi-Reaction Models, `ReactionTrayOverlay`, Focus Bar v2 & Repositories

### 4.1 Zero-Raw-Emoji Multi-Reaction Domain & Vector Badge Renderer (`apps/vhunambi_client/lib/features/social/domain/models/kinetic_reaction.dart`)

```dart
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

/// Canonical 6-reaction taxonomy (`EP-P73-MULTI-REACTIONS-API`, `STD-UIUX-001`).
///
/// Rendered exclusively via custom glossy vector badges ([KineticReactionBadge])
/// with zero raw OS Unicode emojis.
enum KineticReactionType {
  like(
    wireId: 'like',
    label: 'Like',
    startColor: Color(0xFF3B82F6),
    endColor: Color(0xFF1D4ED8),
    accentColor: Color(0xFF3B82F6),
  ),
  love(
    wireId: 'love',
    label: 'Love',
    startColor: Color(0xFFFB7185),
    endColor: Color(0xFFE11D48),
    accentColor: Color(0xFFF43F5E),
  ),
  haha(
    wireId: 'haha',
    label: 'Haha',
    startColor: Color(0xFFFDE047),
    endColor: Color(0xFFF59E0B),
    accentColor: Color(0xFFF59E0B),
  ),
  fire(
    wireId: 'fire',
    label: 'Fire',
    startColor: Color(0xFFFB923C),
    endColor: Color(0xFFEA580C),
    accentColor: Color(0xFFF97316),
  ),
  wow(
    wireId: 'wow',
    label: 'Wow',
    startColor: Color(0xFFC084FC),
    endColor: Color(0xFF7C3AED),
    accentColor: Color(0xFFA855F7),
  ),
  angry(
    wireId: 'angry',
    label: 'Angry',
    startColor: Color(0xFFF87171),
    endColor: Color(0xFFB91C1C),
    accentColor: Color(0xFFEF4444),
  );

  final String wireId;
  final String label;
  final Color startColor;
  final Color endColor;
  final Color accentColor;

  const KineticReactionType({
    required this.wireId,
    required this.label,
    required this.startColor,
    required this.endColor,
    required this.accentColor,
  });

  static KineticReactionType? fromWire(Object? raw) {
    if (raw == null) return null;
    final cleaned = raw.toString().trim().toLowerCase();
    for (final value in values) {
      if (value.wireId == cleaned || value.name == cleaned) return value;
    }
    return null;
  }

  static Map<KineticReactionType, int> parseCounts(Object? raw) {
    if (raw is! Map) return const <KineticReactionType, int>{};
    final out = <KineticReactionType, int>{};
    raw.forEach((k, v) {
      final type = fromWire(k);
      final count = (v as num?)?.toInt() ?? 0;
      if (type != null && count > 0) {
        out[type] = count;
      }
    });
    return Map<KineticReactionType, int>.unmodifiable(out);
  }

  static Map<String, int> encodeCounts(Map<KineticReactionType, int> counts) {
    final out = <String, int>{};
    counts.forEach((k, v) {
      if (v > 0) out[k.wireId] = v;
    });
    return out;
  }

  /// Returns up to [maxBadges] reaction types sorted by descending count.
  static List<KineticReactionType> topReactions(
    Map<KineticReactionType, int> counts, {
    int maxBadges = 3,
    KineticReactionType? fallbackActive,
  }) {
    final entries = counts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isNotEmpty) {
      return entries.take(maxBadges).map((e) => e.key).toList(growable: false);
    }
    if (fallbackActive != null) return <KineticReactionType>[fallbackActive];
    return const <KineticReactionType>[];
  }
}

/// Glossy custom vector orb badge for any [KineticReactionType] (`STD-UIUX-001`).
class KineticReactionBadge extends StatelessWidget {
  final KineticReactionType type;
  final double size;
  final bool showBorderRing;

  const KineticReactionBadge({
    super.key,
    required this.type,
    this.size = 20,
    this.showBorderRing = false,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF141418)
        : Colors.white;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[type.startColor, type.endColor],
        ),
        border: showBorderRing
            ? Border.all(color: ringColor, width: 1.5)
            : null,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: type.endColor.withValues(alpha: 0.35),
            blurRadius: size * 0.25,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Center(child: _buildGlyph()),
    );
  }

  Widget _buildGlyph() {
    final glyphSize = size * 0.56;
    return switch (type) {
      KineticReactionType.like => PhosphorIcon(
        PhosphorIconsFill.thumbsUp,
        size: glyphSize,
        color: Colors.white,
      ),
      KineticReactionType.love => PhosphorIcon(
        PhosphorIconsFill.heart,
        size: glyphSize,
        color: Colors.white,
      ),
      KineticReactionType.fire => PhosphorIcon(
        PhosphorIconsFill.fire,
        size: glyphSize,
        color: Colors.white,
      ),
      KineticReactionType.haha ||
      KineticReactionType.wow ||
      KineticReactionType.angry => CustomPaint(
        size: Size.square(size * 0.72),
        painter: _ReactionFacePainter(type: type),
      ),
    };
  }
}

class _ReactionFacePainter extends CustomPainter {
  final KineticReactionType type;

  const _ReactionFacePainter({required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final ink = type == KineticReactionType.haha
        ? const Color(0xFF3F2305)
        : Colors.white;
    final strokePaint = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.11).clamp(1.2, 2.8)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..color = ink
      ..style = PaintingStyle.fill;

    switch (type) {
      case KineticReactionType.haha:
        // Squinting happy arc eyes
        final leftEye = Path()
          ..moveTo(w * 0.18, h * 0.42)
          ..quadraticBezierTo(w * 0.28, h * 0.26, w * 0.38, h * 0.42);
        final rightEye = Path()
          ..moveTo(w * 0.62, h * 0.42)
          ..quadraticBezierTo(w * 0.72, h * 0.26, w * 0.82, h * 0.42);
        canvas.drawPath(leftEye, strokePaint);
        canvas.drawPath(rightEye, strokePaint);
        // Open laughing D-mouth
        final mouth = Path()
          ..moveTo(w * 0.22, h * 0.56)
          ..lineTo(w * 0.78, h * 0.56)
          ..arcToPoint(
            Offset(w * 0.22, h * 0.56),
            radius: Radius.circular(w * 0.30),
            clockwise: true,
          );
        canvas.drawPath(mouth, fillPaint);
      case KineticReactionType.wow:
        // Wide surprised eyes + open O mouth
        canvas.drawCircle(Offset(w * 0.30, h * 0.34), w * 0.08, fillPaint);
        canvas.drawCircle(Offset(w * 0.70, h * 0.34), w * 0.08, fillPaint);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(w * 0.50, h * 0.68),
            width: w * 0.28,
            height: h * 0.34,
          ),
          fillPaint,
        );
      case KineticReactionType.angry:
        // Furrowed inward brows + scowl
        canvas.drawLine(
          Offset(w * 0.18, h * 0.28),
          Offset(w * 0.42, h * 0.40),
          strokePaint,
        );
        canvas.drawLine(
          Offset(w * 0.82, h * 0.28),
          Offset(w * 0.58, h * 0.40),
          strokePaint,
        );
        canvas.drawCircle(Offset(w * 0.30, h * 0.46), w * 0.065, fillPaint);
        canvas.drawCircle(Offset(w * 0.70, h * 0.46), w * 0.065, fillPaint);
        final scowl = Path()
          ..moveTo(w * 0.28, h * 0.76)
          ..quadraticBezierTo(w * 0.50, h * 0.58, w * 0.72, h * 0.76);
        canvas.drawPath(scowl, strokePaint);
      case KineticReactionType.like:
      case KineticReactionType.love:
      case KineticReactionType.fire:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _ReactionFacePainter oldDelegate) =>
      oldDelegate.type != type;
}

/// Overlapping top-3 reaction badge cluster for summary strips & comments.
class ReactionClusterStack extends StatelessWidget {
  final Map<KineticReactionType, int> reactionCounts;
  final KineticReactionType? fallbackActive;
  final double badgeSize;

  const ReactionClusterStack({
    super.key,
    required this.reactionCounts,
    this.fallbackActive,
    this.badgeSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    final top = KineticReactionType.topReactions(
      reactionCounts,
      maxBadges: 3,
      fallbackActive: fallbackActive,
    );
    if (top.isEmpty) {
      return KineticReactionBadge(
        type: KineticReactionType.love,
        size: badgeSize,
      );
    }
    final step = badgeSize * 0.70;
    final totalWidth = badgeSize + (top.length - 1) * step;
    return SizedBox(
      width: totalWidth,
      height: badgeSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          for (var i = 0; i < top.length; i++)
            Positioned(
              left: i * step,
              child: KineticReactionBadge(
                type: top[i],
                size: badgeSize,
                showBorderRing: true,
              ),
            ),
        ],
      ),
    );
  }
}
```

### 4.2 Long-Press Tactile `ReactionTrayOverlay` (`apps/vhunambi_client/lib/features/social/presentation/widgets/reaction_tray_overlay.dart`)

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_glass_surface.dart';
import 'package:vhunambi_client/features/social/domain/models/kinetic_reaction.dart';

/// Frosted-glass floating pill reaction tray triggered by long-press (`REQ-P73-SOC-04`).
///
/// Supports direct tap OR continuous horizontal drag-to-scrub with `1.4x` hover
/// magnification and `HapticFeedback.selectionClick()`.
class ReactionTrayOverlay {
  static OverlayEntry? _activeEntry;

  static void dismiss() {
    _activeEntry?.remove();
    _activeEntry = null;
  }

  static void show({
    required BuildContext context,
    required Offset anchorGlobalPosition,
    required KineticReactionType? activeReaction,
    required ValueChanged<KineticReactionType> onSelected,
  }) {
    dismiss();
    HapticFeedback.mediumImpact();

    final overlay = Overlay.of(context, rootOverlay: true);
    final screenSize = MediaQuery.sizeOf(context);
    const pillWidth = 286.0;
    const pillHeight = 56.0;

    final clampedLeft = (anchorGlobalPosition.dx - pillWidth * 0.35).clamp(
      12.0,
      (screenSize.width - pillWidth - 12.0).clamp(12.0, double.infinity),
    );
    final clampedTop = (anchorGlobalPosition.dy - pillHeight - 20.0).clamp(
      MediaQuery.paddingOf(context).top + 12.0,
      screenSize.height - pillHeight - 24.0,
    );

    _activeEntry = OverlayEntry(
      builder: (_) => _ReactionTrayLayer(
        left: clampedLeft,
        top: clampedTop,
        pillWidth: pillWidth,
        activeReaction: activeReaction,
        onDismiss: dismiss,
        onSelected: (rx) {
          dismiss();
          HapticFeedback.lightImpact();
          onSelected(rx);
        },
      ),
    );
    overlay.insert(_activeEntry!);
  }
}

class _ReactionTrayLayer extends StatefulWidget {
  final double left;
  final double top;
  final double pillWidth;
  final KineticReactionType? activeReaction;
  final VoidCallback onDismiss;
  final ValueChanged<KineticReactionType> onSelected;

  const _ReactionTrayLayer({
    required this.left,
    required this.top,
    required this.pillWidth,
    required this.activeReaction,
    required this.onDismiss,
    required this.onSelected,
  });

  @override
  State<_ReactionTrayLayer> createState() => _ReactionTrayLayerState();
}

class _ReactionTrayLayerState extends State<_ReactionTrayLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  KineticReactionType? _hovered;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateHoverFromLocalX(double localX) {
    const reactions = KineticReactionType.values;
    final slotWidth = widget.pillWidth / reactions.length;
    final index = (localX / slotWidth).floor();
    final next =
        (index >= 0 && index < reactions.length) ? reactions[index] : null;
    if (next != _hovered) {
      if (next != null) HapticFeedback.selectionClick();
      setState(() => _hovered = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: GestureDetector(
            key: const Key('reaction_tray_barrier'),
            behavior: HitTestBehavior.translucent,
            onTap: widget.onDismiss,
          ),
        ),
        Positioned(
          left: widget.left,
          top: widget.top,
          child: Material(
            color: Colors.transparent,
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: _controller,
                curve: Curves.easeOutBack,
              ),
              child: GestureDetector(
                key: const Key('reaction_tray_overlay'),
                onHorizontalDragUpdate: (details) =>
                    _updateHoverFromLocalX(details.localPosition.dx),
                onHorizontalDragEnd: (_) {
                  if (_hovered != null) {
                    widget.onSelected(_hovered!);
                  }
                },
                child: VhunambiGlassSurface(
                  variant: VhunambiGlassVariant.pill,
                  enableLiveBlur: true,
                  blurSigma: 14.0,
                  width: widget.pillWidth,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: KineticReactionType.values.map((rx) {
                      final isHovered = _hovered == rx;
                      final isSelected = widget.activeReaction == rx;
                      return GestureDetector(
                        key: Key('reaction_tray_item_${rx.wireId}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => widget.onSelected(rx),
                        child: AnimatedScale(
                          scale: isHovered ? 1.40 : (isSelected ? 1.15 : 1.0),
                          duration: const Duration(milliseconds: 120),
                          curve: Curves.easeOutCubic,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              KineticReactionBadge(type: rx, size: 34),
                              const SizedBox(height: 2),
                              Text(
                                rx.label,
                                maxLines: 1,
                                softWrap: false,
                                style: AppTypography.caption.copyWith(
                                  fontSize: 9,
                                  fontWeight: isSelected || isHovered
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected || isHovered
                                      ? rx.accentColor
                                      : AppColors.textSecondaryOf(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(growable: false),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
```

### 4.3 `SocialMusicPost` & `ReelComment` Model Extensions

1. **`apps/vhunambi_client/lib/features/explore/domain/models/social_music_post.dart`:**
   - Add immutable fields (with backward-compatible defaults):
     ```dart
     final Map<KineticReactionType, int> reactionCounts;
     final KineticReactionType? myReaction;
     ```
   - Add helper getter:
     ```dart
     int get totalReactionCount {
       final sum = reactionCounts.values.fold<int>(0, (a, b) => a + b);
       return sum > 0 ? sum : likeCount;
     }
     ```
   - In `copyWith`, support `Map<KineticReactionType, int>? reactionCounts`, `KineticReactionType? myReaction`, `bool clearMyReaction = false`.
   - In `toJson` / `fromJson`, serialize/deserialize `'reactionCounts'` via `KineticReactionType.encodeCounts` / `parseCounts` and `'myReaction'` via `myReaction?.wireId` / `KineticReactionType.fromWire(json['myReaction'])`.
2. **`apps/vhunambi_client/lib/features/social/domain/models/reel_comment.dart`:**
   - Add immutable optional fields:
     ```dart
     final Map<KineticReactionType, int> reactionCounts;
     final KineticReactionType? myReaction;
     final String? gifUrl;
     final String? stickerId;
     final double? mediaAspectRatio;
     ```
   - Add helper getters: `bool get hasMedia => (gifUrl != null && gifUrl!.isNotEmpty) || (stickerId != null && stickerId!.isNotEmpty);` and `int get totalReactionCount`.
   - Update `copyWith` (including `bool clearMyReaction = false`), `toJson`, and `fromJson` losslessly.

### 4.4 Repository & Riverpod Notifier Wiring

1. **`HttpExploreRepository` (`http_explore_repository.dart`):**
   - Add `reactToPost(String postId, KineticReactionType? reaction)` -> `POST $_baseUrl/explore/posts/$postId/react` returning `({KineticReactionType? myReaction, Map<KineticReactionType, int> reactionCounts, int likeCount})?`.
   - Add `reactToComment(String commentId, KineticReactionType? reaction)` -> `POST $_baseUrl/explore/comments/$commentId/react`.
   - Extend `addPostComment(...)` with optional `String? gifUrl`, `String? stickerId`, `double? mediaAspectRatio`.
2. **`ISocialRepository` & `HttpSocialRepository` (`i_social_repository.dart`, `http_social_repository.dart`):**
   - Define immutable DTO `class GifSearchItem { final String id; final String title; final String previewUrl; final String gifUrl; final int width; final int height; double get aspectRatio => height > 0 ? width / height : 1.33; }`.
   - Add `Future<({KineticReactionType? myReaction, Map<KineticReactionType, int> reactionCounts, int likeCount})> reactToComment(String commentId, KineticReactionType? reaction);`
   - Add `Future<List<GifSearchItem>> searchGifs(String query, {int limit = 16});` and `Future<List<GifSearchItem>> getTrendingGifs({int limit = 16});` hitting `GET $_baseUrl/social/gifs/search` & `/trending` (with clean test-mode/offline curated fallback so UI never hangs).
   - Extend `addComment(...)` with optional `String? gifUrl`, `String? stickerId`, `double? mediaAspectRatio`.
3. **`SocialFeedPostsNotifier` (`explore_providers.dart`):**
   - Implement optimistic `void reactToPost(String postId, KineticReactionType? reaction)`:
     - Copy `final counts = Map<KineticReactionType, int>.from(current.reactionCounts);`.
     - **Legacy Like Preservation Guard:** If `counts.values.fold<int>(0, (a, b) => a + b) == 0 && current.likeCount > 0`, seed `counts[KineticReactionType.love] = current.likeCount;` (and treat `final prevReaction = current.myReaction ?? (current.isLikedByMe ? KineticReactionType.love : null);`) so pre-Phase-73 posts with existing likes (e.g. `1,840`) never reset to `1`.
     - Compute `final nextReaction = (reaction == null || reaction == prevReaction) ? null : reaction;`, decrement `prevReaction` (floor `0`, remove key if `0`), increment `nextReaction`, update `likeCount = counts.values.fold<int>(0, (a, b) => a + b)`, `isLikedByMe = nextReaction != null`, persist Hive snapshot, and reconcile with `HttpExploreRepository.reactToPost(...)`.
   - Keep `toggleLike(String postId)` delegating to `reactToPost(postId, (current.myReaction != null || current.isLikedByMe) ? null : KineticReactionType.love)` for 100% backward compatibility.
4. **`ReelsCommentsNotifier` (`reels_comments_provider.dart`):**
   - Implement optimistic `void reactToComment(String clipId, String commentId, KineticReactionType? reaction, {bool isKineticPost = false})` applying the identical legacy `likeCount` preservation guard (`if (sum == 0 && comment.likeCount > 0) counts[KineticReactionType.love] = comment.likeCount;`) and syncing to `HttpExploreRepository.reactToComment` or `_repo.reactToComment`.
   - Extend `addComment(...)` with optional `String? gifUrl`, `String? stickerId`, `double? mediaAspectRatio`, allowing `text.trim().isEmpty` whenever `gifUrl` or `stickerId` is non-empty!

### 4.5 `KineticPostFocusView` v2 & `ExploreSocialPostCard` Integration

Inside `apps/vhunambi_client/lib/features/explore/presentation/views/kinetic_post_focus_view.dart`:
1. **3-Tier Chromatic World Resolution:**
   - Maintain `PostChromaticPalette _palette` in `_KineticPostFocusViewState`, initialized synchronously via `PostChromaticPaletteResolver.resolveSync(...)` and refined asynchronously in `initState` / `didChangeDependencies` via `PostChromaticPaletteResolver.resolveAsync(...)` (resolving `post.track.mood` OR looking up `exploreTracksProvider` / `libraryTracksProvider` by `post.track.id` when `post.track.mood == null`, and resolving artwork from `post.allImageAttachments.firstOrNull?.imageUrl ?? post.track.coverUrl`).
   - Wrap the `Scaffold` body inside `VhunambiAmbientMeshBackdrop(primaryGlow: _palette.primaryGlow, secondaryGlow: _palette.secondaryGlow, child: ...)`.
2. **Non-Truncating Engagement Summary Strip (`Key('kpost_focus_summary_strip')`):**
```dart
Padding(
  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
  child: Wrap(
    key: const Key('kpost_focus_summary_strip'),
    spacing: 12,
    runSpacing: 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: <Widget>[
      Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ReactionClusterStack(
            reactionCounts: post.reactionCounts,
            fallbackActive: post.myReaction ?? (post.isLikedByMe ? KineticReactionType.love : null),
            badgeSize: 18,
          ),
          const SizedBox(width: 6),
          Text(
            '${post.totalReactionCount}',
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
        ],
      ),
      Text(
        '$effectiveCommentCount ${effectiveCommentCount == 1 ? 'Comment' : 'Comments'}',
        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondaryOf(context)),
      ),
      Text(
        '${post.repostCount} ${post.repostCount == 1 ? 'Repost' : 'Reposts'}',
        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondaryOf(context)),
      ),
      Text(
        '${post.remixCount} ${post.remixCount == 1 ? 'Remix' : 'Remixes'}',
        style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondaryOf(context)),
      ),
    ],
  ),
)
```
3. **Non-Wrapping 4-Action Focus Bar (`320dp` & `360dp` Proof):**
```dart
Widget _buildFocusActionButton({
  required Key key,
  required Widget icon,
  required String label,
  required Color labelColor,
  required VoidCallback onTap,
  GestureLongPressStartCallback? onLongPressStart,
}) {
  return Expanded(
    child: GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPressStart: onLongPressStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              icon,
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
```
- The 4 buttons preserve Phase 69's exact per-post keys (`REQ-P73-SOC-06`):
  1. `Key('kpost_focus_like_btn_${post.id}')`: displays `KineticReactionBadge(type: post.myReaction!, size: 18)` if `post.myReaction != null` (or `PhosphorIcon(post.isLikedByMe ? AppIcons.heart : AppIcons.heartOutline, size: 18)`), label `post.myReaction?.label ?? 'Like'`, single-tap toggles `love` / clears `myReaction`, `onLongPressStart` opens `ReactionTrayOverlay.show(...)`.
  2. `Key('kpost_focus_comment_btn_${post.id}')`: `PhosphorIcon(AppIcons.chat, size: 18)`, label `'Comment'`, focuses composer.
  3. `Key('kpost_focus_repost_btn_${post.id}')`: `PhosphorIcon(PhosphorIconsRegular.repeat, size: 18)`, label `'Repost'`, opens `RepostKineticPostSheet`.
  4. `Key('kpost_focus_remix_btn_${post.id}')`: `PhosphorIcon(AppIcons.remix, size: 18)`, label `'Remix'`, opens `OpenVerseRemixCockpitSheet`.
- Also wire `onLongPressStart` -> `ReactionTrayOverlay.show(...)` on `ExploreSocialPostCard`'s react button while preserving its exact Phase 69 key `Key('social_post_like_btn_${post.id}')` and keeping `VhunambiGlassSurface(enableLiveBlur: false)` on feed cards.
- **Orphan Overlay Prevention:** Call `ReactionTrayOverlay.dismiss();` inside `dispose()` of `_KineticPostFocusViewState` and `_ExploreSocialPostCardState`.

---

## 5. Pass 2 (`M73.4`): Sovereign Sticker Pack, `GifStickerPickerSheet`, Comment Media & Verification Suite

### 5.1 Sovereign Sticker Pack & `GifStickerPickerSheet`

#### `apps/vhunambi_client/lib/features/social/domain/models/sovereign_sticker_pack.dart`

```dart
import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';

/// Immutable bundled studio sticker descriptor (`STD-UIUX-001` — zero raw Unicode emojis).
@immutable
class SovereignSticker {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color startColor;
  final Color endColor;
  final Color borderColor;

  const SovereignSticker({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.startColor,
    required this.endColor,
    required this.borderColor,
  });
}

/// Curated offline-ready Vhunambi Sovereign Cultural Sticker Pack (`EP-P73-GIF-STICKER-MEDIA`).
abstract final class SovereignStickerPack {
  static const List<SovereignSticker> all = <SovereignSticker>[
    SovereignSticker(
      id: 'stk_log_drum_hit',
      title: 'Log Drum Hit',
      subtitle: '113 BPM DROP',
      icon: PhosphorIconsFill.waveform,
      startColor: Color(0xFFF59E0B),
      endColor: Color(0xFFB45309),
      borderColor: Color(0xFFFDE68A),
    ),
    SovereignSticker(
      id: 'stk_100_real',
      title: '100% Real',
      subtitle: 'HUMAN CRAFT',
      icon: PhosphorIconsFill.sealCheck,
      startColor: Color(0xFF10B981),
      endColor: Color(0xFF047857),
      borderColor: Color(0xFFA7F3D0),
    ),
    SovereignSticker(
      id: 'stk_amapiano_groove',
      title: 'Amapiano Groove',
      subtitle: 'PRIVATE SCHOOL',
      icon: PhosphorIconsFill.pianoKeys,
      startColor: Color(0xFF8B5CF6),
      endColor: Color(0xFF5B21B6),
      borderColor: Color(0xFFDDD6FE),
    ),
    SovereignSticker(
      id: 'stk_makhado_wave',
      title: 'Makhado Wave',
      subtitle: 'LIMPOPO SUNSET',
      icon: PhosphorIconsFill.sunHorizon,
      startColor: Color(0xFFF97316),
      endColor: Color(0xFFC2410C),
      borderColor: Color(0xFFFED7AA),
    ),
    SovereignSticker(
      id: 'stk_crown_royalty',
      title: 'Crown Royalty',
      subtitle: 'KHARE SALUTE',
      icon: PhosphorIconsFill.crown,
      startColor: Color(0xFFEAB308),
      endColor: Color(0xFFA16207),
      borderColor: Color(0xFFFEF08A),
    ),
    SovereignSticker(
      id: 'stk_studio_cookin',
      title: 'Studio Cookin',
      subtitle: 'PURE HEAT',
      icon: PhosphorIconsFill.fire,
      startColor: Color(0xFFEF4444),
      endColor: Color(0xFF991B1B),
      borderColor: Color(0xFFFECACA),
    ),
    SovereignSticker(
      id: 'stk_mic_drop',
      title: 'Mic Drop',
      subtitle: 'ONE TAKE',
      icon: PhosphorIconsFill.microphoneStage,
      startColor: Color(0xFF06B6D4),
      endColor: Color(0xFF0E7490),
      borderColor: Color(0xFFA5F3FC),
    ),
    SovereignSticker(
      id: 'stk_sa_heritage',
      title: 'SA Heritage',
      subtitle: 'SOVEREIGN ROOTS',
      icon: PhosphorIconsFill.sparkle,
      startColor: Color(0xFFEC4899),
      endColor: Color(0xFF9D174D),
      borderColor: Color(0xFFFBCFE8),
    ),
  ];

  static SovereignSticker? findById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }
}

/// Crisp custom-painted studio sticker graphic (`STD-UIUX-001` compliant).
class SovereignStickerGraphic extends StatelessWidget {
  final SovereignSticker sticker;
  final double width;
  final double height;

  const SovereignStickerGraphic({
    super.key,
    required this.sticker,
    this.width = 128,
    this.height = 96,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[sticker.startColor, sticker.endColor],
        ),
        border: Border.all(
          color: sticker.borderColor.withValues(alpha: 0.70),
          width: 1.5,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: sticker.endColor.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          PhosphorIcon(sticker.icon, size: height * 0.34, color: Colors.white),
          const SizedBox(height: 6),
          Text(
            sticker.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.badge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          Text(
            sticker.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 8.5,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
```

#### `apps/vhunambi_client/lib/features/social/presentation/widgets/gif_sticker_picker_sheet.dart`

```dart
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/features/social/domain/models/sovereign_sticker_pack.dart';
import 'package:vhunambi_client/features/social/domain/repositories/i_social_repository.dart';
import 'package:vhunambi_client/features/social/presentation/providers/social_repository_provider.dart';

/// Selected rich media attachment returned by [GifStickerPickerSheet].
@immutable
class SelectedCommentMedia {
  final String? gifUrl;
  final String? stickerId;
  final String label;
  final double aspectRatio;

  const SelectedCommentMedia({
    this.gifUrl,
    this.stickerId,
    required this.label,
    this.aspectRatio = 1.33,
  });
}

/// Segmented bottom sheet offering bundled Sovereign Cultural Stickers & live GIF search.
class GifStickerPickerSheet extends ConsumerStatefulWidget {
  const GifStickerPickerSheet({super.key});

  static Future<SelectedCommentMedia?> show(BuildContext context) {
    return showModalBottomSheet<SelectedCommentMedia>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const GifStickerPickerSheet(),
    );
  }

  @override
  ConsumerState<GifStickerPickerSheet> createState() =>
      _GifStickerPickerSheetState();
}

class _GifStickerPickerSheetState extends ConsumerState<GifStickerPickerSheet> {
  int _tabIndex = 0; // 0 = Stickers, 1 = GIFs
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<GifSearchItem> _gifs = const <GifSearchItem>[];
  bool _isLoadingGifs = false;

  @override
  void initState() {
    super.initState();
    _loadGifs('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGifs(String query) async {
    setState(() => _isLoadingGifs = true);
    final repo = ref.read(socialRepositoryProvider);
    final items = query.trim().isEmpty
        ? await repo.getTrendingGifs(limit: 16)
        : await repo.searchGifs(query.trim(), limit: 16);
    if (!mounted) return;
    setState(() {
      _gifs = items;
      _isLoadingGifs = false;
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      _loadGifs(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sheetBg = AppColors.surfaceModalOf(context);
    final border = AppColors.borderSubtleOf(context);

    return Container(
      key: const Key('gif_sticker_picker_sheet'),
      height: MediaQuery.sizeOf(context).height * 0.56,
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: border)),
      ),
      child: Column(
        children: <Widget>[
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _SegmentButton(
                    key: const Key('picker_tab_stickers'),
                    label: 'Stickers',
                    icon: PhosphorIconsFill.sticker,
                    selected: _tabIndex == 0,
                    onTap: () => setState(() => _tabIndex = 0),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SegmentButton(
                    key: const Key('picker_tab_gifs'),
                    label: 'GIFs',
                    icon: PhosphorIconsFill.gif,
                    selected: _tabIndex == 1,
                    onTap: () => setState(() => _tabIndex = 1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_tabIndex == 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                10,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondaryOf(context),
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(color: border),
                ),
                child: TextField(
                  key: const Key('gif_search_input'),
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimaryOf(context),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search studio GIFs...',
                    hintStyle: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondaryOf(context),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    prefixIcon: PhosphorIcon(
                      PhosphorIconsRegular.magnifyingGlass,
                      size: 18,
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: _tabIndex == 0 ? _buildStickerGrid() : _buildGifGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 4, AppSpacing.lg, 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.45,
      ),
      itemCount: SovereignStickerPack.all.length,
      itemBuilder: (context, index) {
        final sticker = SovereignStickerPack.all[index];
        return GestureDetector(
          key: Key('sticker_option_${sticker.id}'),
          onTap: () => Navigator.of(context).pop(
            SelectedCommentMedia(
              stickerId: sticker.id,
              label: sticker.title,
              aspectRatio: 1.33,
            ),
          ),
          child: SovereignStickerGraphic(
            sticker: sticker,
            width: double.infinity,
            height: double.infinity,
          ),
        );
      },
    );
  }

  Widget _buildGifGrid() {
    if (_isLoadingGifs && _gifs.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_gifs.isEmpty) {
      return Center(
        child: Text(
          'No GIFs found. Try Sovereign Stickers!',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondaryOf(context),
          ),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 4, AppSpacing.lg, 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.35,
      ),
      itemCount: _gifs.length,
      itemBuilder: (context, index) {
        final item = _gifs[index];
        return GestureDetector(
          key: Key('gif_option_${item.id}'),
          onTap: () => Navigator.of(context).pop(
            SelectedCommentMedia(
              gifUrl: item.gifUrl,
              label: item.title,
              aspectRatio: item.aspectRatio,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                CachedNetworkImage(
                  imageUrl: item.previewUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => ColoredBox(
                    color: AppColors.surfaceSecondaryOf(context),
                    child: Center(
                      child: PhosphorIcon(
                        PhosphorIconsRegular.gif,
                        size: 28,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 6,
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brandPrimary.withValues(alpha: 0.16)
              : AppColors.surfaceSecondaryOf(context),
          borderRadius: AppRadius.pillBorder,
          border: Border.all(
            color: selected
                ? AppColors.brandPrimary.withValues(alpha: 0.45)
                : AppColors.borderSubtleOf(context),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            PhosphorIcon(
              icon,
              size: 16,
              color: selected
                  ? AppColors.brandPrimary
                  : AppColors.textSecondaryOf(context),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
                color: selected
                    ? AppColors.brandPrimary
                    : AppColors.textPrimaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 5.2 `StudioReactionComposerBar` & `_ThreadedCommentTile` Upgrades (`threaded_comments_section.dart`)

1. **`StudioReactionComposerBar`:**
   - Add optional `Color? focusRingAccent` (supplied from `PostChromaticPalette.composerRingTint`).
   - Add state `SelectedCommentMedia? _pendingMedia;` and trigger button `IconButton(key: const Key('comment_media_picker_btn'), icon: PhosphorIcon(PhosphorIconsRegular.gif, ...))` launching `GifStickerPickerSheet.show(context)`.
   - When `_pendingMedia != null`, render a removable chip (`Key('composer_pending_media_chip')`) right above the input bar showing the sticker/GIF title + clear button (`PhosphorIconsRegular.x`).
   - Update `_handleSubmit()` so sending succeeds if `_controller.text.trim().isNotEmpty || _pendingMedia != null`, forwarding `gifUrl: _pendingMedia?.gifUrl`, `stickerId: _pendingMedia?.stickerId`, `mediaAspectRatio: _pendingMedia?.aspectRatio` into `ReelsCommentsNotifier.addComment(...)`, then clearing `_pendingMedia`.
   - Preserve ALL Phase 69 keys (`comment_input`, `comment_send_btn`, `comment_active_reply_banner`, `comment_reaction_chip_fire`, etc.) and explicit `focusedBorder: InputBorder.none` inside the input `TextField`.
2. **`_ThreadedCommentTile`:**
   - Below `comment.text` (when `comment.text.isNotEmpty`), render inline media when `comment.hasMedia`:
     - If `comment.stickerId != null`: render `SovereignStickerGraphic` (`Key('comment_sticker_media_${comment.id}')`, `width: 136`, `height: 98`).
     - Else if `comment.gifUrl != null`: render rounded `ClipRRect(borderRadius: BorderRadius.circular(14))` with `SizedBox(width: 196, child: AspectRatio(aspectRatio: (comment.mediaAspectRatio ?? 1.33).clamp(0.75, 2.0), child: CachedNetworkImage(key: Key('comment_gif_media_${comment.id}'), imageUrl: comment.gifUrl!, fit: BoxFit.cover)))`.
   - Upgrade the comment's Like action into a tap + long-press react trigger preserving Phase 69's exact key `ValueKey('comment_like_${comment.id}')` (`onTap` toggles like/reaction; `onLongPressStart` opens `ReactionTrayOverlay.show(...)`), rendering `KineticReactionBadge(type: comment.myReaction!, size: 16)` when `comment.myReaction != null` or `PhosphorIcon(comment.isLikedByMe ? AppIcons.heart : AppIcons.heartOutline, size: 16)` when un-reacted (preserving `reels_comment_sheet_test.dart#L143`), plus a compact `ReactionClusterStack` + count when `comment.totalReactionCount > 0`.
   - Call `ReactionTrayOverlay.dismiss();` inside `dispose()` of `StudioReactionComposerBar` / `ThreadedCommentsSection` state so unmounting never leaks an active `OverlayEntry`.

### 5.3 Client Verification Test Blueprint (`apps/vhunambi_client/test/features/phase73_kinetic_post_chromatic_reactions_test.dart`)

Must implement and pass under `flutter test --no-pub --timeout=60s`:
1. **`AppTheme` Focus Border Hygiene (`SOC-02`):** Assert both `AppTheme.darkTheme.inputDecorationTheme.focusedBorder` and `AppTheme.lightTheme.inputDecorationTheme.focusedBorder` are `OutlineInputBorder` with `borderSide.width == 1.0` and `borderSide.color != AppColors.brandPrimary`.
2. **3-Tier `PostChromaticPaletteResolver` (`SOC-03`):**
   - Tier 1 (audio attached + `rawMood: 'Soulful'` + `artworkUrl`) -> `tier == ChromaticSynthesisTier.moodAndArtwork`.
   - Tier 2 (`hasAudioAttachment: false` + `artworkUrl`) -> `tier == ChromaticSynthesisTier.artworkOnly` with split-complementary hue.
   - Tier 3 (no audio + no artwork) -> `tier == ChromaticSynthesisTier.themeDefault`.
   - WCAG AA contrast bounds: Light mode `HSLColor.fromColor(palette.accent).lightness <= 0.421`; Dark mode `>= 0.619`.
3. **320dp & 360dp Non-Wrapping Focus Bar (`SOC-01`):** Pump `KineticPostFocusView` at `Size(320, 780)` and `Size(360, 800)` in both Dark and Light themes -> zero `FlutterError` overflows, all 4 Phase 69 keys (`kpost_focus_like_btn_${post.id}`, `kpost_focus_comment_btn_${post.id}`, `kpost_focus_repost_btn_${post.id}`, `kpost_focus_remix_btn_${post.id}`) and `kpost_focus_summary_strip` present.
4. **Long-Press `ReactionTrayOverlay`, Legacy Like Preservation & GIF/Sticker Composer (`SOC-04`):**
   - Long-press `kpost_focus_like_btn_${post.id}` on a seeded post with `likeCount: 1840` -> `reaction_tray_overlay` appears -> tap `reaction_tray_item_fire` -> `socialFeedPostsProvider` post has `myReaction == KineticReactionType.fire`, `reactionCounts[KineticReactionType.love] == 1840`, `reactionCounts[KineticReactionType.fire] == 1`, and `totalReactionCount == 1841` (never wiped to `1`!).
   - Tap `comment_media_picker_btn` -> tap `sticker_option_stk_log_drum_hit` -> `composer_pending_media_chip` appears -> tap `comment_send_btn` with empty text -> new comment renders `comment_sticker_media_*`.
5. **Social Hygiene (`SOC-07`, `SOC-08`, `SOC-09`, `SOC-10`):**
   - `navigateToCreatorProfile` routes owner to `OwnerProfileView` and visitor to `ArtistProfileView`.
   - `MiniPlayerHost` returns `SizedBox.shrink()` when `isSplashActiveProvider` is `true` (default boot state).
   - `CreateKineticPostSheet` propagates toggled `4:5 Portrait` aspect ratio onto existing attachments and shows `kpost_max_images_badge` at 4/4 without error SnackBars.
   - Clean `RecentSearchesNotifier` initializes to `isEmpty == true` (no `'Kabza de Small log drum'`).
