# Phase 18 · Tasks — Social Creator Network & In-House Kinetic Reels Discovery

> **Phase:** 18  
> **Codename:** `social-creator-network`  
> **Status:** 🟡 READY FOR EXECUTION  
> **Target Apps:** `apps/vhunambi_client` & `apps/vhunambi_api`  
> **Architecture Standard:** Dual-Agent Pair Programming Standard ([`docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md))  

---

## 1. Pre-Flight Verification & Baselines

Before running any task:
- [ ] Confirm Git tree clean on `origin/main` (`git status`).
- [ ] Verify `apps/vhunambi_client`: `dart analyze lib test` reports **0 issues**.
- [ ] Verify baseline test suite passes 100%.

---

## 2. Sequenced Implementation Checklist

### Track A: Backend Social Endpoints (`apps/vhunambi_api`)
- [ ] **T1.1**: Define TypeScript interfaces in `src/modules/social/social_types.ts` (`PublishedClipDto`, `PublishClipRequest`, `ClipFeedQuery`).
- [ ] **T1.2**: Implement in-memory clip repository and service in `src/modules/social/social_service.ts`.
- [ ] **T1.3**: Wire Express router endpoints in `src/routes/social_routes.ts` (`POST /api/social/publish`, `GET /api/social/feed`, `GET /api/creators/:id/clips`, `POST /api/social/clips/:id/like`).
- [ ] **T1.4**: Add automated suite in `test/social.test.ts` verifying all social routes.

### Track B: Client Domain & In-House Publishing Pipeline (`apps/vhunambi_client`)
- [ ] **T2.1**: Implement `PublishedClip` domain model in `lib/features/social/domain/models/published_clip.dart`.
- [ ] **T2.2**: Implement `PublishClipModal` in `lib/features/content_studio/presentation/widgets/publish_clip_modal.dart` (captions, tag pills, thumbnail preview).
- [ ] **T2.3**: Wire `"Publish to Profile"` primary button in `export_action_sheet.dart` and `content_studio_dock_view.dart`.
- [ ] **T2.4**: Add `publishClipToProfile()` method to `ContentStudioProvider` with optimistic local injection.

### Track C: Social State Management & Riverpod Providers
- [ ] **T3.1**: Implement `SocialFeedNotifier` & `socialFeedProvider` in `lib/features/social/presentation/providers/social_feed_provider.dart` with cursor pagination and like toggling.
- [ ] **T3.2**: Implement `creatorClipsFamilyProvider` in `lib/features/social/presentation/providers/creator_clips_provider.dart`.

### Track D: Tri-Modal Creator Profile Redesign
- [ ] **T4.1**: Upgrade `ArtistProfileView` to a sliver-based multi-tab layout:
  - Tab 1: 🎬 **Clips & Reels Grid** (3-column mobile, 4-column desktop).
  - Tab 2: 🎵 **Discography & Tracks** (Top songs + albums).
  - Tab 3: 🛍️ **Beats & Community** (Commercial beats, stems, tip leaderboard).
- [ ] **T4.2**: Implement `CreatorReelThumbnailCard` with 9:16 aspect ratio, artwork cover, play count badge, and animated waveform indicator.
- [ ] **T4.3**: Mirror enhancements to `OwnerProfileView` for authenticated user profile self-management.

### Track E: Full-Screen Vertical Kinetic Reels Player
- [ ] **T5.1**: Implement `KineticReelsModal` with vertical `PageView.builder` and recycled controller pool.
- [ ] **T5.2**: Implement `KineticReelItem` rendering zero-video native `KineticPreviewCanvas` synchronized with audio stream at 60/120 FPS.
- [ ] **T5.3**: Build right-hand social action rail (Avatar + Follow, ❤️ Like, 💬 Reaction, ⚡ Tip, ↗️ Share).
- [ ] **T5.4**: Build bottom HUD with track metadata and spinning vinyl sound pill.
- [ ] **T5.5**: Wire "Use Sound / Remix in Studio" button to pre-populate Studio Creation Wizard with track parameters.

### Track F: Quality Gates & Verification
- [ ] **T6.1**: Create unit test suite `test/features/social/published_clip_test.dart`.
- [ ] **T6.2**: Create widget test suite `test/features/social/kinetic_reels_modal_test.dart`.
- [ ] **T6.3**: Create widget test suite `test/features/profile/artist_profile_tabs_test.dart`.
- [ ] **T6.4**: Run full static analysis (`dart analyze lib test`) -> **0 issues**.
- [ ] **T6.5**: Run complete test suite (`flutter test`) -> **100% pass**.

---

## 3. Trap Warnings & Mitigations

| Trap | Risk | Mitigation |
| :--- | :--- | :--- |
| **Video Player Memory Explosion** | Instantiating native video controllers in a grid crashes mobile devices. | **Strictly prohibited**. Grid is 100% image thumbnails; full-screen player uses native Flutter vector `KineticPreviewCanvas` + audio stream. |
| **Audio Session Conflicts** | Reels audio overlapping with existing background player dock. | Tapping a reel must cleanly pause or yield `playerProvider` audio, restoring state on dismissal. |
| **Timer / Loop Leaks in Widget Tests** | Spinning vinyl animation or particle loops causing `!timersPending` in tests. | Stop or isolate continuous animation controllers during tests, or use `tester.pump()` instead of infinite `pumpAndSettle()`. |
| **Design Token Violations** | Hardcoding colors like `#111` or `#F97316` on social buttons. | Always use `AppColors.surfaceElevated`, `AppColors.brandPrimary`, `AppRadius.cardBorder`. |
