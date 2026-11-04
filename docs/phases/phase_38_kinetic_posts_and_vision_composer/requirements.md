# Phase 38 Requirements: Kinetic Posts, Vhunambi Vision Composer & Non-Invasive Sonic Experience

**Document Version:** 1.0.0  
**Status:** Approved  
**Standards:** STD-UIUX-001

---

## 1. Functional Requirements

### Track A: Domain Models, Strict No-MP4 Guard & Repost Sovereignty
- **REQ-KPOST-MODEL-01 (Image Attachment):** `SocialMusicPost` MUST support optional `KineticPostImageAttachment`:
  - `imageUrl` / `localImagePath`: String reference.
  - `isAiGeneratedVision`: boolean flag indicating creation via Vhunambi Vision AI.
  - `visionPrompt`: optional prompt used during generation.
  - `aspectRatio`: `KineticPostAspectRatio` (`square1x1`, `portrait4x5`, `landscape16x9`).
- **REQ-KPOST-MODEL-02 (Universal Vault Audio Attachment & Trimming):** `SocialMusicPost` MUST support optional `KineticPostAudioAttachment`:
  - `sourceType`: `KineticAudioSourceType` (`librarySong`, `beatListing`, `voiceSignature`, `sketchpadGroove`).
  - `clipStartSec`: double offset into the source audio.
  - `clipDurationSec`: double duration (`15.0`, `30.0`, `60.0`, or full track duration).
  - `originalCreatorId` & `originalCreatorHandle`: attribution of the audio author.
  - `allowSoundReuse`: boolean flag (defaults to true).
  - `allowRepost`: boolean flag (defaults to true).
- **REQ-KPOST-NO-MP4 (Strict Video Rejection Invariant):** The system MUST reject video files (`.mp4`, `.mov`, `.webm`, `.mkv`) on Kinetic Posts. A helper `isAllowedKineticPostMedia(String filenameOrMime)` MUST strictly return false for video extensions and guide the user to Kinetic Reels.
- **REQ-KPOST-REPOST-01 (Repost Sovereignty & Audio Immutability):** When a user reposts or quote-reposts a Kinetic Post:
  - Reposter may append their own top commentary (`quoteComment`).
  - The original post's image, attached audio source, start offset, snippet duration, and creator attribution MUST remain 100% immutable and un-editable by the reposter.

### Track B: Redesigned Feed Card & Non-Invasive Frosted Sonic Pill
- **REQ-KPOST-CARD-01 (Slim Non-Invasive Sonic Pill):**
  - When an image is present, `KineticPostSonicPill` MUST float over the bottom edge of the image with a translucent frosted glass blur (`BackdropFilter`).
  - When no image is present, `KineticPostSonicPill` MUST render as a compact 44dp capsule bar (never causing vertical card overflow).
  - Sonic Pill MUST display:
    1. 1-tap Play/Pause toggle `Key('social_post_play_btn_${post.id}')`.
    2. Track title and original creator handle.
    3. Source badge (`Song`, `Beat`, `Voice DNA`, `Groove`).
    4. Trim duration badge (e.g. `0:30 Hook`, `0:15 Drop`).
    5. Animated micro equalizer bars when active.
- **REQ-KPOST-MINI-01 (Mini-Player Handshake):** Tapping Play on `KineticPostSonicPill` MUST dispatch `playTrack` to `playerStateProvider` with `clipStartSec`, delegating transport control to the global Mini Player.
- **REQ-KPOST-CARD-02 (Repost Action):** Add `Key('social_post_repost_btn_${post.id}')` alongside Like, Comment, Remix, Tip, and Share.

### Track C: Composer Bar & Authoring Workstation Sheet
- **REQ-KPOST-COMP-01 (Feed Composer Bar):** `KineticPostComposerBar` (`Key('explore_create_kinetic_post_bar')`) MUST be mounted at the top of the Explore feed displaying avatar, placeholder `"Share a kinetic post, studio photo, or sound..."`, and quick icons for Photo/Vision, Audio, and Post.
- **REQ-KPOST-SHEET-01 (CreateKineticPostSheet Workstation):**
  - Multi-line caption input `Key('kpost_caption_input')`.
  - Image Deck with `[ Upload Photo ]` `Key('kpost_upload_image_btn')`, `[ Vhunambi Vision AI ]` `Key('kpost_generate_vision_btn')`, and Aspect-Ratio Resizer `Key('kpost_aspect_ratio_selector')` (`1:1`, `4:5`, `16:9`).
  - Universal Vault Audio Picker with 4 tabs (`Songs`, `Beats`, `Voice DNA`, `Grooves`) and snippet duration selector (`15s`, `30s`, `60s`, `Full`).
  - One-tap `Publish Kinetic Post` button `Key('kpost_publish_submit_btn')`.

---

## 2. Non-Functional Requirements
- **REQ-QA-01:** `dart analyze lib test` = 0 issues.
- **REQ-QA-02:** 100% green tests in `test/features/explore/phase38_kinetic_posts_and_vision_test.dart`.
- **REQ-QA-03:** Touch targets $\ge 44\times 44\text{dp}$, Phosphor icons only, zero raw emojis/hex.
- **REQ-QA-04:** Release APK $\le 200\text{ MB}$.

