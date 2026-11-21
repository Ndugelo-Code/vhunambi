# VHUNAMBI PHASE 74: DETERMINISTIC TWO-PASS EXECUTION PLAN & VERIFICATION GATES
**Document ID**: `VHUNAMBI-SPEC-P74-TASKS-V1`  
**Phase**: `74`  
**Status**: `READY FOR STAGE 4 EXECUTION (/vhunambi-executioner)`  
**Execution Model**: Two Sequential Self-Contained Passes (`Pass 1: M74.1–M74.2` $\to$ `Pass 2: M74.3–M74.4`)  

---

## Pass 1 — Backend Cloud SWR, R2 Media Upload, Supabase RPC Hardening, Lyric Karaoke Sanitizer & Artwork Foundation (`M74.1` – `M74.2`)

> **Pass 1 Self-Containment Rule**: Pass 1 (`M74.1`–`M74.2`) MUST compile and pass all backend TypeScript/test suites and Flutter static analysis + Pass 1 widget tests with zero dependency on Pass 2 (`M74.3`–`M74.4`) files. In `M74.2`, upgrade `trending_reels_shelf.dart` to `VhunambiTrackArtwork` and `PhosphorIcon`; wire `_PostKineticReelCard` to `KineticReelStudioView.show(context)` in `M74.3` when `kinetic_reel_studio_view.dart` is created.

### Milestone `M74.1`: Supabase Migration, Social Reels Cloud SWR, Clip Multi-Reactions & R2 Media Upload
- [x] **T74.1.1**: Create `supabase/migrations/20261121000002_phase74_reels_studio_and_rpc_hardening.sql` adding `video_url`, `media_kind` (`CHECK (media_kind IN ('artwork','camera_video','gallery_video','gallery_photo','vision'))`), `audio_start_ms`, `audio_end_ms`, `effect_preset`, `effect_intensity`, `typography_preset`, `speed_rate`, `sticker_id`, and `reaction_counts_json JSONB NOT NULL DEFAULT '{}'::jsonb` to `public.published_clips`, creating `idx_auth_sessions_creator_id`, and hardening `execute_atomic_payout`, `record_beat_license_atomic`, `send_cultural_tip_atomic`, and `custom_access_token_hook` with `SET search_path = public, pg_temp;` and `service_role` execute permissions.
- [x] **T74.1.2**: Extend `PublishClipRequest` and `PublishedClipDto` in `apps/vhunambi_api/src/modules/social/social_types.ts` with Phase 74 studio, video/photo, and multi-reaction properties.
- [x] **T74.1.3**: Upgrade `apps/vhunambi_api/src/db/edge_persistence_bridge.ts` and `apps/vhunambi_api/src/db/vhunambi_db.ts` (1:1 method parity) using live `EdgeIsolateDatabaseEngine` primitives (`resolveCloudDriver`, `withTimeoutResult`, `domainHydratedAtMs`, `domainInFlightPromises`, `DEFAULT_SWR_TTL_MS`, `mirrorWriteThrough`, `awaitWriteThrough`, `KineticReactionWire`, `VALID_KINETIC_REACTIONS`):
  - `hydratePublishedClipRows(clipsRows)` + 12-second SWR `syncSocialFromCloud(force, cOrEnv)` hydrating `published_clips`, `reel_comments`, and `social_interactions` (stamping `domainHydratedAtMs.set('social:global', Date.now())` ONLY when all three succeed).
  - Timestamp-descending `listPublishedClipRows()` (`Date.parse(b.created_at) - Date.parse(a.created_at)`).
  - `upsertPublishedClip(clip, skipMirror)` and `upsertPublishedClipAsync(clip, cOrEnv)`.
  - `reactToClip(clipId, actorCreatorId, reactionType, skipMirror)` and `reactToClipAsync(...)` storing per-user reactions in `social_interactions` (`interaction_type = 'clip_react'`) and seeding `counts.love = legacyLikeCount` when `sumReactionCounts(counts) === 0 && legacyLikeCount > 0`.
- [x] **T74.1.4**: Update `apps/vhunambi_api/src/modules/social/social_service.ts` to hydrate all Phase 74 fields and `myReaction` (`clip_react`) in `orderedClips(viewerCreatorId)`, add `getClipById`, add `publishClipAsync`, and add `reactToClipAsync`.
- [x] **T74.1.5**: Update `apps/vhunambi_api/src/server.ts` (`hasScopedReadThrough` at `L53-68`) preserving all existing prefixes (`/api/notifications`, `/api/wallet`, `/api/explore`, `/api/library`, `/api/playlists`, `/api/marketplace`, `/v1/generations`, `/v1/vision`, `/v1/webhooks`) and appending `/api/social` and `/api/v1/social`.
- [x] **T74.1.6**: Update `apps/vhunambi_api/src/routes/social_routes.ts` to make social read routes `async` with `await vhunambiDb.syncSocialFromCloud(false, c)`, update `POST /api/social/publish` to `await publishClipAsync(..., c)`, add `POST /api/social/clips/:id/react`, and add authenticated (`sovereignAuthMiddleware`) `POST /api/social/media/upload` allowing `video/mp4`, `video/quicktime`, `video/webm`, `image/jpeg`, `image/png`, `image/webp`, `audio/mpeg`, `audio/mp4` with HTTP `413` (`> 25 MB`) and HTTP `415` (`UNSUPPORTED_MEDIA_TYPE`) guards.
- [x] **T74.1.7**: Create `apps/vhunambi_api/test/phase74_reels_studio_swr_and_media.test.ts` and register it in `apps/vhunambi_api/package.json` (`30/30` backend suites).

### Milestone `M74.2`: Media Packages, Lyric Karaoke Sanitizer, `PublishedClip` Schema & Artwork Parity
- [x] **T74.2.1**: Add `camera: ^0.11.0+2`, `image_picker: ^1.1.2`, and `video_player: ^2.9.2` to `apps/vhunambi_client/pubspec.yaml`, add camera/media permissions to `apps/vhunambi_client/android/app/src/main/AndroidManifest.xml`, and run `flutter pub get`.
- [x] **T74.2.2**: Create `apps/vhunambi_client/lib/features/content_studio/domain/utils/lyric_karaoke_sanitizer.dart` (`LyricKaraokeSanitizer.cleanLyricTextForKaraoke` and `LyricKaraokeSanitizer.sanitizeAlignment`) and wire it into `SongMetadataDna.fromTrackInfo` / `fromJson` (`song_metadata_dna.dart`) and `PublishedClip.effectiveLyrics` (`published_clip.dart`).
- [x] **T74.2.3**: Extend `DurationPreset` in `apps/vhunambi_client/lib/features/content_studio/domain/models/content_studio_preset.dart` with `reel60s` (`60s`) and `reel90s` (`90s`).
- [x] **T74.2.4**: Extend `PublishedClip` in `apps/vhunambi_client/lib/features/social/domain/models/published_clip.dart` with `videoUrl`, `mediaKind`, `audioStartMs`, `audioEndMs`, `effectPreset`, `effectIntensity`, `typographyPreset`, `speedRate`, `stickerId`, `reactionCounts`, `myReaction`, `totalReactionCount`, and `clearMyReaction` in `copyWith`.
- [x] **T74.2.5**: Add `reactToClip` and `uploadReelMedia` to `ISocialRepository` (`i_social_repository.dart`) and implement them with offline/test fallbacks in `HttpSocialRepository` (`http_social_repository.dart`).
- [x] **T74.2.6**: Upgrade `KineticPreviewCanvas` (`kinetic_preview_canvas.dart`) to render `VhunambiTrackArtwork` instead of `'VHUNAMBI 9:16 COVER'`, replace `Icons.play_arrow_rounded` with `PhosphorIcon(AppIcons.play, ...)`, support `transparentBackground`, and update `test/features/content_studio/presentation/widgets/kinetic_preview_canvas_test.dart#L32` to assert `find.byType(VhunambiTrackArtwork)`.
- [x] **T74.2.7**: Upgrade `TrendingReelCard` and `TrendingReelsShelf` (`trending_reels_shelf.dart`) to render `VhunambiTrackArtwork` and replace all stock `Icons.*` with `PhosphorIcon(AppIcons.*)`.

### Pass 1 Verification Gate (`M74.1` – `M74.2`)
```powershell
# 1. Backend TypeScript & 30-Suite Gate
Push-Location c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_api
.\node_modules\.bin\tsc.cmd --noEmit
npm test
Pop-Location

# 2. Client Analyzer & Pass 1 Widget Gate
Push-Location c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_client
flutter analyze --no-pub
flutter test --no-pub --timeout=60s test/features/content_studio/presentation/widgets/kinetic_preview_canvas_test.dart test/features/content_studio/presentation/widgets/publish_clip_modal_test.dart
Pop-Location
```

---

## Pass 2 — Full-Screen 4-Stage `KineticReelStudioView`, `KineticReelsModal` V4, Phase 74 Test Suite & SLEEP (`M74.3` – `M74.4`)

### Milestone `M74.3`: Full-Screen 4-Stage `KineticReelStudioView`, Audio Picker, Waveform Trimmer & Publish View
- [x] **T74.3.1**: Create `apps/vhunambi_client/lib/features/content_studio/presentation/widgets/reel_audio_picker_sheet.dart` (`ReelAudioPickerSheet` + `ReelStudioAudioSelection`) with search bar `Key('reel_audio_search_input')`, `[Import]` (`file_picker`, `Key('reel_audio_import_btn')`), and 4 tabs (`My Vault`, `Trending`, `Saved`, `Vibes` via `VhunambiMood`).
- [x] **T74.3.2**: Create `apps/vhunambi_client/lib/features/content_studio/presentation/widgets/reel_audio_trimmer_sheet.dart` (`ReelAudioTrimmerSheet`) with `15s / 30s / 60s / 90s` duration pills, glowing 48-bar waveform trim scrubber, and `Key('reel_audio_trimmer_done_btn')`.
- [x] **T74.3.3**: Create `apps/vhunambi_client/lib/features/content_studio/presentation/views/kinetic_reel_publish_view.dart` (`KineticReelPublishView`, `Key('reel_studio_stage_publish')`) with 9:16 preview card, `Key('reel_publish_caption_input')`, hashtag chips, visibility selector (`Key('reel_publish_visibility_public')` / `Key('reel_publish_visibility_followers')`), opt-in `"Also share to Explore Feed"` switch (`Key('reel_publish_share_to_explore_switch')`, **defaulting to `false`**), `Key('reel_publish_submit_btn')`, R2 media upload hook, and 2.5s auto-dismissing action-free toast.
- [x] **T74.3.4**: Create `apps/vhunambi_client/lib/features/content_studio/presentation/views/kinetic_reel_studio_view.dart` (`KineticReelStudioView`, `Key('kinetic_reel_studio_view')`) with `pushedFullScreenOverlayCountProvider` ref-counting, `PostChromaticPaletteResolver` backdrop tint, `FLUTTER_TEST` hardware guards (`Key('reel_studio_camera_fallback_canvas')`), collapsible Left/Right rail swap (`Key('reel_studio_rail_side_btn')`), 5 Visual Preset Orbs (`Kinetic Gold`, `Super 8mm`, `Amapiano Pulse`, `Noir Studio`, `Makhado Warm`), vertical `0–100` Effect Intensity slider (`Key('reel_studio_intensity_slider')`), countdown HUD (`Key('reel_studio_countdown_hud')`), Stage 2 Editor with `SovereignStickerPack.all` / `SovereignStickerGraphic(..., width: 96, height: 74)`, and Stage 3 transition to `KineticReelPublishView`.
- [x] **T74.3.5**: Wire `_PostKineticReelCard` (`Key('explore_post_kinetic_reel_card')`) in `trending_reels_shelf.dart` and add `Key('content_studio_open_full_reel_studio_btn')` in `content_studio_dock_view.dart` to launch `KineticReelStudioView.show(context)`.
- [x] **T74.3.6**: Replace remaining stock `Icons.*` in `duration_trim_scrubber.dart`, `atmospheric_effects_deck.dart`, `typography_preset_picker.dart`, and `publish_clip_modal.dart` with `PhosphorIcon`, and gate `socialFeedPostsProvider.notifier.addPost(...)` in `publish_clip_modal.dart` behind `_alsoShareToExplore` (`false` by default, zero `'New track drop 🔥'` spam, 2.5s action-free toast).

### Milestone `M74.4`: `KineticReelsModal` V4 Playback, Multi-Reactions, Contrast Fix, Test Suite & SLEEP
- [x] **T74.4.1**: Add `prependPublishedClip` (if missing) and `reactToClip(String clipId, KineticReactionType? reaction)` to `SocialFeedNotifier` in `apps/vhunambi_client/lib/features/social/presentation/providers/social_feed_provider.dart` preserving unindexed legacy `likeCount`.
- [x] **T74.4.2**: Upgrade `apps/vhunambi_client/lib/features/social/presentation/widgets/kinetic_reels_modal.dart`:
  - Fix `_ReelTopFilterTab` (`Trending | For You`) text color to explicit `Colors.white` / `Colors.white70` (`SOC-06a`).
  - Add `_ReelVideoBackingLayer` (`Key('reel_video_backing_layer_${clip.id}')`) and optional `SovereignStickerGraphic(..., width: 96, height: 74)` (`Key('reel_canvas_sticker_${clip.id}')`).
  - Wire long-press on `Key('reel_like_btn')` to `ReactionTrayOverlay.show(..., activeReaction: clip.myReaction, onSelected: ...)` -> `socialFeedProvider.notifier.reactToClip(clip.id, rx)` and call `ReactionTrayOverlay.dismiss()` in `dispose()`.
  - Purge all raw OS Unicode emojis (`_burstEmoji`, `_culturalEmojis`, `'🎵'`) in favor of `KineticReactionBadge(type: ..., size: ...)` (`STD-UIUX-001`) and update `test/features/social/kinetic_reels_modal_test.dart#L144`.
- [x] **T74.4.3**: Create `apps/vhunambi_client/test/features/phase74_reels_studio_and_playback_v4_test.dart` covering `LyricKaraokeSanitizer`, `KineticPreviewCanvas` `VhunambiTrackArtwork`, `KineticReelStudioView` 4-stage flow + rail swap + Visual Preset Orbs + `MiniPlayerHost` auto-hide + opt-in Explore cross-post (`false` default), and `KineticReelsModal` V4 white tab contrast + 6-type reaction long-press + video backing layer.
- [x] **T74.4.4** (`SLEEP` Memory Consolidation): **ONLY AFTER** all Pass 1 and Pass 2 verification gates exit `0`, update `docs/phases/phase_74_kinetic_reels_studio_and_playback_v4/memory.md` to `"status": "completed"` with `"completed_at"` ISO timestamp and run `node .agents/skills/vhunambi-memory/scripts/consolidate_memory.mjs`.

### Pass 2 & Final Phase 74 Verification Gate (`M74.3` – `M74.4`)
```powershell
# 1. Static Analysis Gate (0 issues)
Push-Location c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_client
flutter analyze --no-pub

# 2. Phase 74 + Phase 73 + Content Studio + Social + Explore Regression Gate
flutter test --no-pub --timeout=60s test/features/phase74_reels_studio_and_playback_v4_test.dart test/features/phase73_kinetic_post_chromatic_reactions_test.dart test/features/social/ test/features/explore/ test/features/content_studio/

# 3. STD-UIUX-001 Zero-Raw-Emoji & Zero-Stock-Icons Audit on Phase 74 Files
Get-ChildItem -Path "lib\features\content_studio" -Recurse -Filter "*.dart" | Select-String -Pattern "Icons\.|🔥|❤️|👑|🇿🇦|🎹|🎵"
Select-String -Path "lib\features\social\presentation\widgets\kinetic_reels_modal.dart","lib\features\social\presentation\widgets\trending_reels_shelf.dart" -Pattern "Icons\.|🔥|❤️|👑|🇿🇦|🎹|🎵"
Pop-Location
```

---

## Stage 4 Anti-Trap Checklist
1. **Live Phase 71–73 Backend Engine Primitives**: Use `resolveCloudDriver(cOrEnv)`, `EdgeIsolateDatabaseEngine.withTimeoutResult(...)`, `mirrorWriteThrough('label', ...)`, `awaitWriteThrough('label', ..., cOrEnv)`, `KineticReactionWire`, and `VALID_KINETIC_REACTIONS`.
2. **Live Phase 73 Dart Symbols**: Use `SovereignStickerPack.all`, `SovereignStickerPack.findById(...)`, `SovereignStickerGraphic(..., width: 96, height: 74)`, `KineticReactionBadge(type: ..., size: ...)`, and `ReactionTrayOverlay.show(..., activeReaction: ..., onSelected: ...)`.
3. **Zero Blind `.reverse()` on `published_clips`**: `listPublishedClipRows()` MUST sort by `Date.parse(b.created_at) - Date.parse(a.created_at)`.
4. **Legacy `likeCount` Preservation on Clip Multi-Reactions**: Seed `counts.love = legacyLikeCount` when `sumReactionCounts(counts) === 0 && legacyLikeCount > 0`, and preserve `unindexedLegacyLikes` on the client.
5. **`FLUTTER_TEST` Hardware Channel Safety**: Never invoke native `availableCameras()`, `CameraController.initialize()`, or `VideoPlayerController.initialize()` when `FLUTTER_TEST` is active.
6. **Preserve `AppIcons.heart` on Default Like State**: Keep `AppIcons.heart` when `clip.isLikedByMe && (clip.myReaction == null || clip.myReaction == KineticReactionType.love)` so `kinetic_reels_modal_test.dart#L123` passes.
