# Phase 38 Tasks: Kinetic Posts Architecture & Non-Invasive Sonic Feed

**Document Version:** 1.0.0  
**Status:** Completed  

---

## Track A: Domain Models, Strict No-MP4 Guard & Repost Sovereignty
- [x] **T-A1** Define `KineticPostAspectRatio`, `KineticPostImageAttachment`, `KineticAudioSourceType`, and `KineticPostAudioAttachment` models.
- [x] **T-A2** Extend `SocialMusicPost` with image attachment, audio attachment, repost lineage (`repostedFromPostId`, `repostedFromCreatorHandle`, `quoteComment`), and repost count.
- [x] **T-A3** Implement `isAllowedKineticPostMedia(String pathOrMime)` strict No-MP4 guard (`REQ-KPOST-NO-MP4`).
- [x] **Gate A:** Model serialization and No-MP4 guard unit tests pass.

## Track B: Redesigned Feed Card & Non-Invasive Frosted Sonic Pill
- [x] **T-B1** Build `KineticPostSonicPill` with frosted-glass overlay on artwork and 44dp slim capsule for text-only posts.
- [x] **T-B2** Wire 1-tap Play/Pause toggle to `playerStateProvider` with `clipStartSec` seeking and live micro-equalizer animation.
- [x] **T-B3** Redesign `ExploreSocialPostCard` using the 4-zone editorial hierarchy with resizable visual canvas (`1:1`, `4:5`, `16:9`).
- [x] **T-B4** Add `Key('social_post_repost_btn_${post.id}')` action and modal.
- [x] **Gate B:** Widget tests verify visual aspect-ratios, frosted sonic pill docking, and mini-player handshake.

## Track C: Feed Composer Bar & Authoring Workstation Sheet
- [x] **T-C1** Build `KineticPostComposerBar` and mount it on Explore feed below mode filter pills.
- [x] **T-C2** Build `CreateKineticPostSheet` with caption editor, image upload/Vhunambi Vision generator, aspect-ratio resizer, and 4-tab universal vault audio picker with duration trimming (15s/30s/60s/Full).
- [x] **T-C3** Connect composer submit action to prepend new post to `socialFeedPostsProvider`.
- [x] **Gate C:** Composer workflow tests verify post creation with image, aspect ratio, and trimmed audio attachment.

## Track D: Verification Gates & Hardware Deployment
- [x] **T-D1** Author `test/features/explore/phase38_kinetic_posts_and_vision_test.dart`.
- [x] **T-D2** Run `dart analyze lib test` → 0 issues found.
- [x] **T-D3** Run `flutter test` across all explore and social test suites → 100% green (134/134 passed).
- [x] **T-D4** Build release ARM64 APK (41.5 MB $\le 200\text{ MB}$) and install to `EPHUT20917014649`.
- [x] **Gate D (Phase Exit):** All above gates green.
