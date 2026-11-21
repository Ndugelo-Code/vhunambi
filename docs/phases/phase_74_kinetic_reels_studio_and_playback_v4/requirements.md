# VHUNAMBI PHASE 74 REQUIREMENTS SPECIFICATION — EARS / RFC-2119 CONTRACTS & TRACEABILITY MATRIX

**Document ID:** `VHUNAMBI-SPEC-P74-REQUIREMENTS-V1`  
**Phase:** Phase 74 (`phase_74_kinetic_reels_studio_and_playback_v4`)  
**Paired Blueprint:** [`blueprint.md`](./blueprint.md) (`VHUNAMBI-SPEC-P74-BLUEPRINT-V1`)  
**Paired Design:** [`design.md`](./design.md) (`VHUNAMBI-SPEC-P74-DESIGN-V1`)

---

## 1. Document Scope & EARS / RFC-2119 Conventions

The keywords **MUST**, **MUST NOT**, **REQUIRED**, **SHALL**, **SHALL NOT**, **SHOULD**, and **MAY** in this document are to be interpreted as described in RFC-2119. All functional requirements follow the **EARS** (Easy Approach to Requirements Syntax) standard (`WHEN`, `WHILE`, `IF...THEN`, `WHERE`).

---

## 2. Backend Social Cloud SWR, Clip Multi-Reactions, R2 Media Upload & Supabase Hardening (`REQ-P74-BE-*`)

### `REQ-P74-BE-01`: Idempotent Supabase Schema & Pre-Existing Advisor Hardening
- **WHEN** `supabase/migrations/20261121000002_phase74_reels_studio_and_rpc_hardening.sql` is applied to Supabase Postgres 17, the migration **SHALL** idempotently (`ADD COLUMN IF NOT EXISTS`) add `video_url TEXT`, `media_kind TEXT NOT NULL DEFAULT 'artwork'`, `audio_start_ms INTEGER NOT NULL DEFAULT 0`, `audio_end_ms INTEGER NOT NULL DEFAULT 30000`, `effect_preset TEXT`, `effect_intensity DOUBLE PRECISION NOT NULL DEFAULT 0.65`, `typography_preset TEXT`, `speed_rate DOUBLE PRECISION NOT NULL DEFAULT 1.0`, `sticker_id TEXT`, and `reaction_counts_json JSONB NOT NULL DEFAULT '{}'::jsonb` to `public.published_clips`.
- **WHEN** the migration executes, it **SHALL** also pin `SET search_path = public, pg_temp` on `execute_atomic_payout`, `record_beat_license_atomic`, `send_cultural_tip_atomic`, and `custom_access_token_hook` (via `pg_proc` existence check), revoke `EXECUTE` from `PUBLIC, anon, authenticated` and grant `EXECUTE` exclusively to `service_role` on those three atomic financial RPCs, and create `idx_auth_sessions_creator_id` on `public.auth_sessions (creator_id)`.

### `REQ-P74-BE-02`: Multi-Isolate Social Cloud SWR (`syncSocialFromCloud`)
- **WHEN** any social read endpoint (`GET /api/social/feed`, `GET /api/social/clips/:id`, `GET /api/social/clips/:id/comments`, `GET /api/social/clips/:id/remixes`) is invoked on a Cloudflare Worker isolate, `social_routes.ts` **SHALL** await `vhunambiDb.syncSocialFromCloud(false, c)` with a 12-second SWR freshness window (`social:global`), hydrating `published_clips`, `reel_comments`, and `social_interactions` from Supabase with a `3500ms` timeout guard.
- **IF** any of the three Supabase table queries times out or errors, `syncSocialFromCloud` **SHALL NOT** stamp `domainHydratedAtMs.set('social:global', Date.now())`, ensuring subsequent requests retry cloud hydration.
- **WHERE** `server.ts` evaluates `hasScopedReadThrough`, it **SHALL** include `p.startsWith('/api/social') || p.startsWith('/api/v1/social')` so social routes bypass the monolithic 21-table cold-start barrier.

### `REQ-P74-BE-03`: Awaited Publish & Clip Multi-Reaction Write-Through (`POST /api/social/clips/:id/react`)
- **WHEN** `POST /api/social/publish` is called, the Worker **SHALL** persist the clip via `await vhunambiDb.upsertPublishedClipAsync(clip, c)` (`skipMirror = true` on local upsert followed by `awaitWriteThrough`) so the newly published clip is immediately queryable by other Worker isolates without duplicate Supabase writes.
- **WHEN** `POST /api/social/clips/:id/react` is called with `{ reactionType: 'like' | 'love' | 'haha' | 'fire' | 'wow' | 'angry' | null }`, `vhunambiDb.reactToClipAsync(clipId, actorId, reactionType, c)` **SHALL** toggle or switch the caller's reaction in `social_interactions` (`interaction_type = 'clip_react'`), seed `counts.love = legacyLikeCount` when `sumReactionCounts(counts) === 0 && legacyLikeCount > 0` so pre-existing clip likes (e.g. `1,840`) are never wiped to `1`, update `published_clips.reaction_counts_json` and `likes_count`, and return `{ success: true, targetId, myReaction, reactionCounts, likeCount, liked }`.
- **WHERE** `EdgeIsolateDatabaseEngine` defines `syncSocialFromCloud`, `upsertPublishedClipAsync`, `reactToClip`, or `reactToClipAsync`, `VhunambiDatabase` (`vhunambi_db.ts`) **SHALL** implement 1:1 matching method signatures.

### `REQ-P74-BE-04`: Authenticated R2 Social Media Upload (`POST /api/social/media/upload`)
- **WHEN** an authenticated client sends `POST /api/social/media/upload` (gated by `sovereignAuthMiddleware`), the endpoint **SHALL** validate the MIME type against the allowlist (`video/mp4`, `video/quicktime`, `video/webm`, `image/jpeg`, `image/png`, `image/webp`, `audio/mpeg`, `audio/mp4`), reject payloads exceeding `25 MB` (`26,214,400` bytes) with HTTP `413` (`PAYLOAD_TOO_LARGE`) or invalid MIME types with HTTP `415` (`UNSUPPORTED_MEDIA_TYPE`), store the bytes in `VHUNAMBI_VAULT` under `social/<canonicalCreatorId>/<timestamp>_<nanoid>.<ext>` via `uploadBytesToR2`, and return HTTP `201` with `{ success: true, key, url: '/r2/social/...', contentType, size }`.

---

## 3. Karaoke Lyric Sanitizer & Artwork Normalization (`REQ-P74-LYR-*`, `REQ-P74-ART-*`)

### `REQ-P74-LYR-01`: Production Bracket & Stage-Direction Stripping (`LyricKaraokeSanitizer`)
- **WHEN** `SongMetadataDna.fromTrackInfo` or `PublishedClip.effectiveLyrics` processes lyric text or alignment tokens, `LyricKaraokeSanitizer.cleanLyricTextForKaraoke(String rawLyrics)` **SHALL** strip all square-bracket tags (`[Intro]`, `[Verse 1]`, `[Chorus]`, `[Bridge]`, `[Outro]`, `[Crisp soft shakers, airy synth pads]`) and standalone parenthetical stage directions `(...)` before splitting into `AlignedWord` (`word`, `startSec`, `endSec`) tokens.
- **IF** `dna.alignment` already contains bracketed tokens from legacy saved drafts, `LyricKaraokeSanitizer.sanitizeAlignment(List<AlignedWord> words)` **SHALL** filter and strip bracket blocks cleanly; if zero vocal words remain after sanitization, `PublishedClip.effectiveLyrics` **SHALL** fall back to rhythm-locked African karaoke tokens.

### `REQ-P74-ART-01`: `VhunambiTrackArtwork` Adoption in `KineticPreviewCanvas` & `TrendingReelsShelf`
- **WHEN** `KineticPreviewCanvas` or `TrendingReelCard` (`trending_reels_shelf.dart`) renders cover artwork, it **SHALL** use `VhunambiTrackArtwork` (`EP-P68-TRACK-ARTWORK`) with `AppConstants.normalizeCloudMediaUrl`, supporting `asset:assets/...`, `/r2/...`, and `https://...` URIs.
- **WHERE** `KineticPreviewCanvas` or `TrendingReelsShelf` previously rendered `'VHUNAMBI 9:16 COVER'` text or stock `Icons.music_note_rounded` / `Icons.play_arrow_rounded` / `Icons.favorite_rounded` / `Icons.verified_rounded`, those widgets **SHALL** be replaced by `VhunambiTrackArtwork` and `PhosphorIcon` (`STD-UIUX-001`).

---

## 4. Instagram-Benchmark Full-Screen `KineticReelStudioView` (`REQ-P74-STU-*`)

### `REQ-P74-STU-01`: Full-Screen Lifecycle & MiniPlayer Suppression
- **WHILE** `KineticReelStudioView` is mounted, it **SHALL** increment `pushedFullScreenOverlayCountProvider` (`EP-P68-MINIPLAYER-SUPPRESS`) post-frame in `initState` and decrement it in `dispose()` so `MiniPlayerHost` never overlaps the 9:16 creation studio.
- **WHEN** the user taps `Key('explore_post_kinetic_reel_card')` (`+ Post Reel` on `TrendingReelsShelf`), it **SHALL** launch `KineticReelStudioView.show(context)` directly.

### `REQ-P74-STU-02`: Stage 1 — 9:16 Capture & Backdrop Source Stage
- **WHEN** `KineticReelStudioView` opens in Stage 1 (`Key('reel_studio_stage_capture')`), it **SHALL** render:
  1. **9:16 Live Canvas:** Native `CameraPreview` when camera hardware is active, device gallery photo/video (`image_picker`), or chromatic song/Vision backdrop (`PostChromaticPaletteResolver` + `VhunambiTrackArtwork`) with a deterministic headless/desktop fallback (`Key('reel_studio_camera_fallback_canvas')`) when running under `FLUTTER_TEST` or without hardware cameras.
  2. **Translucent Top Floating Chrome:** Close button `Key('reel_studio_close_btn')`, Audio selector pill `Key('reel_studio_audio_pill')`, Flash toggle `Key('reel_studio_flash_btn')`, Speed selector toggle `Key('reel_studio_speed_btn')` (`0.5x`, `1x`, `1.5x`, `2x`), Timer cycle button `Key('reel_studio_timer_btn')` (`None`, `3s`, `5s`, `10s`), and Rail side swapper `Key('reel_studio_rail_side_btn')` (`Left` / `Right`).
  3. **Collapsible Floating Tool Rail (`Key('reel_studio_tool_rail')`):** `Audio` (`Key('reel_rail_audio_btn')`), `Effects` (`Key('reel_rail_effects_btn')`), `Backdrop` (`Key('reel_rail_backdrop_btn')` cycling `Camera`, `Artwork`, `Vision AI`), `Lyrics` (`Key('reel_rail_lyrics_btn')`), and `Length` (`Key('reel_rail_length_btn')` cycling `15s`, `30s`, `60s`, `90s`), plus a vertical `0–100` Effect Intensity slider (`Key('reel_studio_intensity_slider')`).
  4. **Bottom Capture Deck:** Gallery picker button `Key('reel_studio_gallery_btn')`, scrollable Visual Preset Orbs (`Kinetic Gold`, `Super 8mm`, `Amapiano Pulse`, `Noir Studio`, `Makhado Warm` — `Key('reel_preset_orb_<id>')`), central shutter button `Key('reel_studio_shutter_btn')` (triggering `3... 2... 1...` countdown overlay `Key('reel_studio_countdown_hud')` when timer > 0), Camera flip `Key('reel_studio_flip_camera_btn')`, and `Key('reel_studio_next_to_editor_btn')`.

### `REQ-P74-STU-03`: Audio Picker Sheet & Glowing Waveform Hook Trimmer
- **WHEN** the user taps `Key('reel_studio_audio_pill')` or `Key('reel_rail_audio_btn')`, `ReelAudioPickerSheet` (`Key('reel_audio_picker_sheet')`) **SHALL** open with a borderless-focus search field (`Key('reel_audio_search_input')`), `[Import]` local audio trigger (`Key('reel_audio_import_btn')`), and 4 tabs: `My Vault` (`libraryTracksProvider`), `Trending` (`exploreTracksProvider`), `Saved`, and `Vibes` (`VhunambiMood` filter pills).
- **WHEN** a track is selected or `Trim` is tapped, `ReelAudioTrimmerSheet` (`Key('reel_audio_trimmer_sheet')`) **SHALL** render a glowing multi-bar waveform window + `DurationTrimScrubber` (`15s`, `30s`, `60s`, `90s`) allowing the creator to drag the hook window (`audioStartMs`..`audioEndMs`) and confirm via `Key('reel_audio_trimmer_done_btn')`.

### `REQ-P74-STU-04`: Stage 2 — Full-Screen 9:16 Studio Editor
- **WHEN** the studio transitions to Stage 2 (`Key('reel_studio_stage_editor')`), it **SHALL** composite the active video/photo/artwork with `KineticPreviewCanvas` (rendering sanitized karaoke lyrics), optional draggable/toggleable `SovereignStickerGraphic` overlay (`EP-P73-GIF-STICKER-MEDIA`), and bottom studio tool drawers for `TypographyPresetPicker`, `AtmosphericEffectsDeck`, `Stickers` (`Key('reel_editor_tab_stickers')`), and `Audio Trim` (`Key('reel_editor_tab_trim')`), advancing to Stage 3 via `Key('reel_editor_next_to_publish_btn')`.

### `REQ-P74-STU-05`: Stage 3 — Full-Screen Publish Screen & 2.5s Action-Free Toast
- **WHEN** the studio transitions to Stage 3 (`KineticReelPublishView`, `Key('reel_studio_stage_publish')`), it **SHALL** display a 9:16 cover preview, a caption `TextField` (`Key('reel_publish_caption_input')`, zero bright orange focus box), `#Hashtag` suggestion chips, Audience selector (`Key('reel_publish_visibility_public')` / `Key('reel_publish_visibility_followers')`), and an opt-in switch `"Also share to Explore Feed"` (`Key('reel_publish_share_to_explore_switch')`) that **MUST default to `false`**.
- **WHEN** `Key('reel_publish_submit_btn')` is tapped:
  1. If custom media bytes exist, upload them via `ISocialRepository.uploadReelMedia`.
  2. Build and prepend the `PublishedClip` (including `videoUrl`, `mediaKind`, `audioStartMs`, `audioEndMs`, `effectPreset`, `effectIntensity`, `typographyPreset`, `speedRate`, `stickerId`) to `socialFeedProvider` and call `POST /api/social/publish`.
  3. **ONLY IF** `"Also share to Explore Feed"` is explicitly `true`, add a `SocialMusicPost` to `socialFeedPostsProvider` using the creator's actual caption (or track title if caption is empty — **NEVER** `'New track drop 🔥'`).
  4. Pop back to the caller and show a `2.5s` floating toast (`Duration(milliseconds: 2500)`) **WITHOUT** any `SnackBarAction`.

---

## 5. `KineticReelsModal` Playback V4 & Light-Mode Legibility (`REQ-P74-PLAY-*`)

### `REQ-P74-PLAY-01`: High-Contrast White Theatre Tabs in Light & Dark Modes
- **WHEN** `KineticReelsModal` renders `_ReelTopFilterTab` (`Trending`, `For You`, `Following`, `Newest`), the active tab text color **SHALL** be explicit `Colors.white` (`FontWeight.w800`) and inactive tab text color **SHALL** be `Colors.white70` (`FontWeight.w500`) inside a frosted dark header scrim, guaranteeing high contrast regardless of whether the host app is in Light Mode or Dark Mode.

### `REQ-P74-PLAY-02`: VideoPlayer Backing Layer, Canvas Sticker & Multi-Reaction Tray
- **WHEN** `KineticReelsModal` displays a `PublishedClip` with a non-empty `videoUrl` (and `!isTestEnv`), it **SHALL** initialize and loop a `VideoPlayerController` underneath `KineticPreviewCanvas`; in `FLUTTER_TEST`, it **SHALL** render a deterministic non-platform-channel video indicator (`Key('reel_video_backing_layer_${clip.id}')`).
- **IF** `clip.stickerId` matches a `SovereignStickerPack` item, `KineticReelsModal` **SHALL** render `SovereignStickerGraphic` (`Key('reel_canvas_sticker_${clip.id}')`) on the 9:16 stage.
- **WHEN** the user long-presses `Key('reel_like_btn')`, `KineticReelsModal` **SHALL** open `ReactionTrayOverlay.show(...)` (`EP-P73-MULTI-REACTIONS-API`), invoke `socialFeedProvider.notifier.reactToClip(clip.id, reaction)`, and dismiss any active overlay in `dispose()`.
- **WHERE** `KineticReelsModal` previously contained raw Unicode emojis (`'❤️'`, `'🔥'`, `'👑'`, `'🇿🇦'`, `'🎹'`, `'🎵'`) or stock `Icons.close_rounded`, all such sites **SHALL** be replaced by `PhosphorIcon` and `KineticReactionBadge` vector graphics (`STD-UIUX-001`).

---

## 6. Requirement-to-Test Traceability Matrix

| Requirement ID | Primary Implementation File(s) | Verification Test Case |
| :--- | :--- | :--- |
| `REQ-P74-BE-01` | `supabase/migrations/20261121000002_phase74_reels_studio_and_rpc_hardening.sql` | `phase74_reels_studio_swr_and_media.test.ts` + Supabase migration check |
| `REQ-P74-BE-02` | `edge_persistence_bridge.ts`, `vhunambi_db.ts`, `social_routes.ts`, `server.ts` | `phase74_reels_studio_swr_and_media.test.ts` (`cross-isolate syncSocialFromCloud`) |
| `REQ-P74-BE-03` | `edge_persistence_bridge.ts`, `vhunambi_db.ts`, `social_routes.ts` | `phase74_reels_studio_swr_and_media.test.ts` (`POST /api/social/clips/:id/react` & legacy likes) |
| `REQ-P74-BE-04` | `social_routes.ts` (`POST /api/social/media/upload`) | `phase74_reels_studio_swr_and_media.test.ts` (`R2 upload auth, MIME & 25MB guard`) |
| `REQ-P74-LYR-01` | `lyric_karaoke_sanitizer.dart`, `song_metadata_dna.dart`, `published_clip.dart` | `phase74_reels_studio_and_playback_v4_test.dart` (`strips [Intro] and (...)`) |
| `REQ-P74-ART-01` | `kinetic_preview_canvas.dart`, `trending_reels_shelf.dart` | `phase74_reels_studio_and_playback_v4_test.dart` + `kinetic_preview_canvas_test.dart` |
| `REQ-P74-STU-01..05` | `kinetic_reel_studio_view.dart`, `reel_audio_picker_sheet.dart`, `reel_audio_trimmer_sheet.dart`, `kinetic_reel_publish_view.dart` | `phase74_reels_studio_and_playback_v4_test.dart` (`4-stage flow, opt-in Explore toggle = false, MiniPlayer suppression`) |
| `REQ-P74-PLAY-01..02` | `kinetic_reels_modal.dart`, `social_feed_provider.dart` | `phase74_reels_studio_and_playback_v4_test.dart` + `kinetic_reels_modal_test.dart` |
