# Phase 18 Master Handoff: Social Creator Network & In-House Kinetic Reels Discovery

> **Document Purpose:** Single authoritative handoff guide for any agent (Antigravity / Cline / Cursor) implementing Phase 18 under the Dual-Agent Symbiosis Protocol. Read this first — it captures exact requirements, architectural invariants, code designs, and the execution checklist.
>
> **Generated At:** 2026-10-10T22:15:00+02:00  
> **Lead Architect:** Antigravity (Lead Architect & QA)  
> **Repository Root:** `c:\Users\Ndugelo\VHUNAMBI\monorepo\`  
> **Client Workspace:** `apps/vhunambi_client/`  
> **Backend Workspace:** `apps/vhunambi_api/`  
> **Specification Suite:** [`docs/phases/phase_18_social_creator_network/`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_18_social_creator_network/)  

---

## 1. Phase 18 Objectives & Scope

Phase 18 bridges **synthesis**, **playback**, and **content creation** into a **self-sustaining in-house social network** with familiar Spotify / Instagram / TikTok interactions:

1. **"Publish to Profile" 1-Tap Pipeline (`ContentStudioDockView`):**
   - Along with external MP4 export, creators can 1-tap publish their video clip directly to their Vhunambi profile.
   - Includes caption, tags (`#Amapiano`, `#Tshivenḓa`), and visibility.
   - Sends immutable `SongMetadataDNA` JSON for zero-video in-house playback.

2. **Tri-Modal Creator Profiles (`@username`):**
   - 🎬 **Clips & Reels Grid**: 9:16 aspect ratio thumbnail cards with play counts, hover waveforms, and tap-to-watch.
   - 🎵 **Discography**: Full songs, EPs, top tracks with direct cockpit player integration.
   - 🛍️ **Beats & Community**: Commercial beat licensing, stem packs, and top supporters leaderboard with direct tipping.

3. **Zero-Video Native Kinetic Reels Player (`KineticReelsModal`):**
   - Vertical swipe feed (`PageView.builder(scrollDirection: Axis.vertical)`).
   - Renders live at 60/120 FPS using native Flutter `KineticPreviewCanvas` synchronized with streaming audio.
   - 90% bandwidth reduction and zero video decoder strain compared to streaming MP4s.
   - Social HUD: Creator avatar (+ Follow), ❤️ Like toggle, 💬 Reactions, ⚡ Tip credits, ↗️ Share link.

4. **Viral Sound Loop ("Use Sound / Remix in Studio"):**
   - Spinning vinyl sound pill at the bottom of every reel.
   - 1-tap "Use Sound / Remix in Studio" button pre-populates the Studio Creation Wizard with that song's genre, BPM, and stem references, creating an infinite viral creation loop.

---

## 2. Specification Documents (Single Source of Truth)

Read and adhere to all 4 documents in `docs/phases/phase_18_social_creator_network/`:
- [`blueprint.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_18_social_creator_network/blueprint.md)
- [`requirements.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_18_social_creator_network/requirements.md)
- [`design.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_18_social_creator_network/design.md)
- [`tasks.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_18_social_creator_network/tasks.md)

---

## 3. Codebase Invariants (NEVER BREAK THESE)

1. **Zero Raw Hex Values:** Always use `AppColors.*`, `AppGradients.*`, `AppTypography.*`, `AppRadius.*`, `AppSpacing.*`.
2. **Zero Video Player Memory Bloat:** Profile grids use image thumbnails. Full-screen reels use native `KineticPreviewCanvas` + audio streaming. Max 3 recycled controllers in the feed pool.
3. **Audio Session Isolation:** Interacting with a reel cleanly coordinates with `playerProvider`, pausing background playback and avoiding overlapping audio channels.
4. **Collision-Safe Enums:** Always use `AudioRepeatMode` (`off`, `all`, `one`), never `RepeatMode`.
5. **Quality Gates:** `dart analyze lib test` must report 0 issues. All test suites must pass 100%.

---

## 4. Execution Sequence

Follow `docs/phases/phase_18_social_creator_network/tasks.md`:
- **Track A**: Backend social endpoints (`/api/social/publish`, `/api/social/feed`, `/api/creators/:id/clips`, `/api/social/clips/:id/like`).
- **Track B**: Client domain model (`PublishedClip`) and in-house publishing dialog (`PublishClipModal`).
- **Track C**: Social feed and creator clips Riverpod providers.
- **Track D**: Tri-modal `ArtistProfileView` upgrade (Reels grid, Discography, Beats & Community).
- **Track E**: Full-screen vertical `KineticReelsModal` with viral sound loop ("Remix in Studio").
- **Track F**: Automated test suites and verification gate.
