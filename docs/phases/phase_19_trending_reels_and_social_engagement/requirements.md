# Phase 19 · Requirements — Trending Reels Discovery & TikTok Community Engagement

> **Phase:** 19  
> **Codename:** `trending-reels-and-social-engagement`  
> **Status:** 🟡 SPECIFICATION  
> **Target App:** `apps/vhunambi_client`  
> **Standard:** EARS / RFC 2119 Specification Standard  

---

## 1. RFC 2119 Keywords
The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in RFC 2119.

---

## 2. Functional Requirements (Trending Reels Shelf)

### REQ-TRD-01: Shelf Visibility in Discovery Surfaces
- The application **MUST** mount a dedicated horizontal scrollable "Trending Kinetic Reels" shelf in both `ExploreView` (`/explore`) and `HomeDashboardView` (`/home`).
- The shelf **MUST** render before or between major content blocks to ensure high-visibility discovery for visitor and listener onboarding.

### REQ-TRD-02: 9:16 Aspect Visual Cards
- Each card on the trending shelf **MUST** display in a vertical 9:16 aspect ratio.
- Each card **MUST** display:
  1. The creator's avatar monogram or image and handle (`@username`).
  2. Verified badge if `isCreatorVerified == true`.
  3. The track title and genre tag.
  4. Formatted play count (`▶ 14.2K`) and like count (`❤️ 1.2K`).
  5. Genre-specific background gradient (`AppGradients.forGenre(...)`) and cover art thumbnail.

### REQ-TRD-03: Zero-Video Player Invariant
- The trending cards **MUST NOT** instantiate any video decoders, MP4 controllers, or heavy streaming pipelines.
- Cards **SHALL** render using lightweight cached cover images and typography, keeping CPU/GPU memory footprint minimal.

### REQ-TRD-04: Genre Filter Pills
- The trending shelf **MUST** provide horizontal genre filter pills: `All`, `#Amapiano`, `#Gqom`, `#Maskandi`, `#AfroHouse`.
- Tapping a genre pill **SHALL** filter the displayed cards without triggering a full page reload or layout shift.

### REQ-TRD-05: 1-Tap Launch into Kinetic Reels Modal
- Tapping any card in the trending shelf **MUST** immediately launch `KineticReelsModal` centered on the tapped reel.
- Swiping vertically in the modal **SHALL** smoothly traverse adjacent reels matching the active filter context.

---

## 3. Functional Requirements (TikTok-Style Comments & Reactions)

### REQ-COM-01: Comment Drawer Trigger
- In `KineticReelsModal`, tapping the 💬 comment button on the action rail **MUST** open a spring-animated modal bottom sheet (`ReelsCommentSheet`).
- The bottom sheet **MUST** include a top drag handle, a header with total comment count, and an exit button.

### REQ-COM-02: TikTok-Familiar Comment Feed
- Each comment in the drawer **MUST** display:
  1. Commenter's avatar or initial monogram.
  2. Username (`@handle`) and relative timestamp (e.g. `2h ago`).
  3. Creator badge if the commenter is the reel's author.
  4. Honest community badge indicating how many times the user reacted/loved the reel (e.g. `5x ❤️`).
  5. Multi-line comment text body.
  6. Comment-level heart button and like count on the trailing edge.

### REQ-COM-03: Comment-Level Love Toggling
- Tapping the heart on any comment **MUST** toggle its like state and increment/decrement its like count optimistically.

### REQ-COM-04: Multi-Tap Honest Love Reaction Engine
- The reel action rail and comment sheet **MUST** support repeated love taps (up to 20 taps per session).
- Each tap **SHALL** increment `clip.likeCount` and increment `userReactionCount` for the current user.
- The UI **MUST** display visual feedback (e.g., floating heart burst particles and a count badge such as `"Loved 5x! ❤️"`).
- In the creator view and top of the comment sheet, the system **SHALL** highlight top lovers (e.g. `Top supporter: @lerato loved 5x ❤️`).

### REQ-COM-05: 1-Tap African Cultural Reaction Chips
- The comment sheet composer **MUST** provide quick 1-tap African cultural reaction emojis:
  - 🔥 Fire
  - 👑 Royalty
  - 🇿🇦 Heritage / South Africa
  - 🎹 Log Drum
  - 🐐 GOAT
  - ❤️ Love
- Tapping an emoji chip **SHALL** immediately insert it into the composer input field.

### REQ-COM-06: 1-Tap Quick Praise Chips
- The comment sheet composer **MUST** offer quick praise pills:
  - `"This log drum hits different! 🎹"`
  - `"Makhado sunrise vibe 🌅"`
  - `"Top tier production 🔥"`
  - `"Proudly South African 🇿🇦"`
- Tapping a praise chip **SHALL** fill or append the phrase to the input field.

### REQ-COM-07: Optimistic Comment Submission
- Submitting a comment **MUST** immediately append the comment to the reel's comment thread with the active user's credentials and reaction badge.
- The input field **MUST** clear immediately upon send, and the list **SHALL** scroll to reveal the newly posted comment.

---

## 4. Performance & Token Strictness Requirements

### REQ-PRF-01: Design Token Discipline
- Zero raw hex values (`#FFFFFF`, `0xFF...`) are permitted in new components.
- All styles **MUST** resolve through `AppColors`, `AppRadius`, `AppTypography`, and `AppSpacing`.

### REQ-PRF-02: Responsive Viewport Parity
- The shelf and drawer **MUST** adapt smoothly to both Mobile (< 768px) and Desktop (> 1024px) screen widths without rendering overflow or clipping text.
