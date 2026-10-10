# Phase 18 · Requirements — Social Creator Network & In-House Kinetic Reels Discovery

> **Phase:** 18  
> **Codename:** `social-creator-network`  
> **Status:** 🟡 SPECIFICATION  
> **Target Apps:** `apps/vhunambi_client` & `apps/vhunambi_api`  
> **Standard:** RFC 2119 (`MUST`, `SHALL`, `SHOULD`, `MAY`) & EARS Syntax  

---

## 1. Traceability Matrix & Requirements Index

| Requirement ID | Subsystem | Description | Priority |
| :--- | :--- | :--- | :--- |
| `REQ-SOC-01` | Content Studio | In-House "Publish to Profile" primary CTA | P0 |
| `REQ-SOC-02` | Content Studio | Publish metadata dialog (caption, tags, visibility) | P0 |
| `REQ-SOC-03` | Content Studio | SongMetadataDNA serialization for social feed | P0 |
| `REQ-SOC-04` | Content Studio | Optimistic local profile injection upon publishing | P1 |
| `REQ-SOC-05` | Content Studio | Toast & celebration feedback upon publish completion | P1 |
| `REQ-SOC-06` | Creator Profile | Tri-modal tab architecture (Reels, Music, Beats/Bio) | P0 |
| `REQ-SOC-07` | Creator Profile | 9:16 Kinetic Reels grid with play counts & waveforms | P0 |
| `REQ-SOC-08` | Creator Profile | Follow / Unfollow interactive state with reactive count | P0 |
| `REQ-SOC-09` | Creator Profile | Direct tipping integration with token modal | P0 |
| `REQ-SOC-10` | Creator Profile | Responsive grid layout (3-column mobile, 4-column desktop) | P1 |
| `REQ-SOC-11` | Kinetic Reels Feed | Full-screen vertical swipe reel player | P0 |
| `REQ-SOC-12` | Kinetic Reels Feed | Real-time synchronized KineticPreviewCanvas playback | P0 |
| `REQ-SOC-13` | Kinetic Reels Feed | Like / Favorite toggle with micro-animation | P0 |
| `REQ-SOC-14` | Kinetic Reels Feed | Spinning vinyl "Use Sound" / "Remix in Studio" CTA | P0 |
| `REQ-SOC-15` | Kinetic Reels Feed | Single-tap pause/play and progress scrubber HUD | P1 |
| `REQ-SOC-16` | Social Graph | Social feed provider with cursor pagination | P0 |
| `REQ-SOC-17` | Social Graph | Deep link sharing (`vhunambi.com/@username/reels/:id`) | P1 |
| `REQ-SOC-18` | Social Graph | Top Supporters leaderboard integration on profile | P1 |
| `REQ-SOC-19` | Social Graph | Audio session isolation with global `playerProvider` | P0 |
| `REQ-SOC-20` | Social Graph | Remix stem attribution badge linking original creator | P1 |
| `REQ-SOC-21` | Backend API | `POST /api/social/publish` endpoint | P0 |
| `REQ-SOC-22` | Backend API | `GET /api/social/feed` with cursor pagination | P0 |
| `REQ-SOC-23` | Backend API | `GET /api/creators/:id/clips` endpoint | P0 |
| `REQ-SOC-24` | Backend API | `POST /api/social/clips/:id/like` endpoint | P0 |
| `REQ-SOC-25` | Backend API | `POST /api/creators/:id/follow` endpoint | P0 |
| `REQ-SOC-26` | Performance | Zero heavy MP4 streaming in-house (vector DNA playback) | P0 |
| `REQ-SOC-27` | Performance | Virtual controller pool (max 3 active controllers) | P0 |
| `REQ-SOC-28` | Performance | Memory ceiling under 80MB during extended reel browsing | P0 |
| `REQ-SOC-29` | Performance | 60/120 FPS render guarantee on canvas layers | P0 |
| `REQ-SOC-30` | Architecture | Zero raw hex values; 100% token discipline | P0 |

---

## 2. In-House Publishing Pipeline (`REQ-SOC-01` – `REQ-SOC-05`)

### REQ-SOC-01: Publish to Profile Primary Action
- **Clause**: The [`ExportActionSheet`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/content_studio/presentation/widgets/export_action_sheet.dart) and [`ContentStudioDockView`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/content_studio/presentation/views/content_studio_dock_view.dart) **MUST** provide a primary action button labeled `"Publish to Profile"`.
- **EARS**: *When* the user taps "Publish to Profile", the system *SHALL* open the `PublishClipModal` without requiring an offline MP4 render.

### REQ-SOC-02: Publish Metadata Dialog
- **Clause**: The `PublishClipModal` **SHALL** allow the creator to specify:
  1. Clip caption / title (max 140 chars).
  2. Music tags & dialect labels (e.g., `#Amapiano`, `#Tshivenḓa`, `#PrivateSchool`).
  3. Visibility toggle (`Public` vs `Unlisted`).
- **EARS**: *While* editing the metadata, the modal *SHALL* display a compact 9:16 preview thumbnail of the clip.

### REQ-SOC-03: SongMetadataDNA Serialization
- **Clause**: The publishing request **MUST** bundle the track's [`SongMetadataDNA`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/content_studio/domain/models/song_metadata_dna.dart) JSON payload, including selected typography preset, lyric timestamps, and visual mood theme.

### REQ-SOC-04: Optimistic Profile Injection
- **Clause**: Upon submitting publish, the client *SHALL* immediately prepend the new clip to the current user's profile reels collection optimistically prior to remote network confirmation.

### REQ-SOC-05: Celebration Feedback
- **Clause**: When the API confirms clip publication, the system *SHALL* display a celebratory snackbar with a 1-tap `"View on Profile"` action.

---

## 3. Tri-Modal Creator Profile (`REQ-SOC-06` – `REQ-SOC-10`)

### REQ-SOC-06: Tri-Modal Tab Architecture
- **Clause**: The [`ArtistProfileView`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/profile/presentation/views/artist_profile_view.dart) and [`OwnerProfileView`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/profile/presentation/views/owner_profile_view.dart) **MUST** feature 3 primary tabs:
  1. 🎬 **Clips & Reels** (Default tab)
  2. 🎵 **Discography & Tracks**
  3. 🛍️ **Beats & Community**

### REQ-SOC-07: 9:16 Kinetic Reels Grid
- **Clause**: The Reels tab **SHALL** render a grid of 9:16 aspect ratio cards. Each card **MUST** display:
  - High-resolution cover artwork with subtle atmospheric gradient.
  - Video play count badge (e.g. `▶ 24.5K`).
  - Animated mini-waveform pill indicator on hover/tap.
  - Track title and genre pill.

### REQ-SOC-08: Reactive Follow / Unfollow
- **Clause**: The profile header **MUST** render a primary Follow button that reactively toggles between `+ Follow` (`AppColors.brandPrimary`) and `Following` (`AppColors.surfaceSecondary`), instantly updating follower count stats.

### REQ-SOC-09: Direct Tipping Integration
- **Clause**: Tapping the `⚡ Tip` button **MUST** invoke the existing Vhunambi coin tip sheet, allowing supporters to tip credits (10, 25, 50, 100) directly to the creator with ledger recording.

### REQ-SOC-10: Responsive Grid Parity
- **Clause**: The reels grid **SHALL** render:
  - 3 columns on Mobile (< 768px).
  - 4 columns on Desktop (> 1024px).

---

## 4. Full-Screen Kinetic Reels Feed (`REQ-SOC-11` – `REQ-SOC-15`)

### REQ-SOC-11: Vertical Swipe Gesture
- **Clause**: Tapping any clip in the profile grid **MUST** open the full-screen `KineticReelsModal`. Users **SHALL** navigate between clips using vertical swipe gestures (`PageView.builder` with `Axis.vertical`).

### REQ-SOC-12: Zero-Video Native Canvas Playback
- **Clause**: The reel viewer **MUST NOT** instantiate a video player. It **MUST** render the clip using [`KineticPreviewCanvas`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/apps/vhunambi_client/lib/features/content_studio/presentation/widgets/kinetic_preview_canvas.dart) synchronized to the audio stream at 60/120 FPS.

### REQ-SOC-13: Social Actions Overlay
- **Clause**: The right-hand side HUD **MUST** display:
  - Creator Avatar with + Follow badge.
  - ❤️ Like button with reactive heart animation and count.
  - 💬 Comments / Reaction sheet trigger.
  - ⚡ Tip creator button.
  - ↗️ Share clip link.

### REQ-SOC-14: Viral Sound Loop ("Remix in Studio")
- **Clause**: The bottom HUD **MUST** feature a spinning vinyl record showing the track title and artist name.
- **EARS**: *When* the user taps "Use Sound" or "Remix in Studio", the system *SHALL* launch the Studio Creation Wizard pre-populated with the track's genre, BPM, and stem references.

### REQ-SOC-15: Single-Tap Play/Pause HUD
- **Clause**: Tapping the center canvas **SHALL** toggle playback state with a spring-animated Play/Pause icon indicator.

---

## 5. Performance & Safety Invariants (`REQ-SOC-26` – `REQ-SOC-30`)

### REQ-SOC-26: Zero Heavy Video Files
- **Clause**: In-house clips **MUST** stream only audio (`.mp3` / `.aac`) + JSON (`SongMetadataDNA`), reserving MP4 generation exclusively for external exports.

### REQ-SOC-27: Virtual Controller Pool
- **Clause**: The feed **MUST** recycle animation controllers and limit concurrent audio streams to exactly 1 active stream.

### REQ-SOC-28: Memory Ceiling
- **Clause**: Memory allocation during a 50-clip reel browsing session **SHALL NOT** exceed 80MB above baseline.

### REQ-SOC-29: 60/120 FPS Guarantee
- **Clause**: The canvas rendering **MUST NOT** drop frames during lyric transitions or particle drift on standard hardware.

### REQ-SOC-30: Strict Token Discipline
- **Clause**: All social components **MUST** resolve colors, typography, borders, and animations through `AppColors`, `AppTypography`, `AppRadius`, and `lib/motion-config.ts`.
