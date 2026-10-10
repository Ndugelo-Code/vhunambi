# Phase 19 · Tasks — Trending Reels Discovery & TikTok Community Engagement

> **Phase:** 19  
> **Codename:** `trending-reels-and-social-engagement`  
> **Status:** ✅ COMPLETE — 100% implemented & verified  
> **Target App:** `apps/vhunambi_client`  
> **Standard:** Dual-Agent Pair Programming Standard ([`docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md))  

---

## Pre-Flight Check Matrix

- [x] Baseline static analysis passes with 0 issues (`flutter analyze`).
- [x] Baseline social test suites pass 100% (17/17 tests passing).
- [x] Working tree is clean on `main`.

---

## Sequenced Implementation Tasks

### T1: Domain Entities & Model Enhancements
- [x] Add `ReelComment` domain model in `lib/features/social/domain/models/reel_comment.dart` with support for commenter identity, text, like count, `userReelLoves` honest community counter, and relative timestamp.
- [x] Extend `PublishedClip` in `lib/features/social/domain/models/published_clip.dart` with `userReactionCount` (default 0) to track multi-tap loves by current user.
- [x] Update `PublishedClip` `copyWith`, `toJson`, and `fromJson`.
- **Verification**: `flutter test test/features/social/published_clip_test.dart` (4/4 passing).

### T2: Riverpod Providers for Comments & Trending Feed
- [x] Implement `reelsCommentsProvider` and `ReelsCommentsNotifier` in `lib/features/social/presentation/providers/reels_comments_provider.dart` with seeded South African comments, optimistic addition, and comment-level like toggling.
- [x] Enhance `SocialFeedNotifier` in `lib/features/social/presentation/providers/social_feed_provider.dart` with `recordLove(String clipId)` to support multi-tap love increments and optimistic reaction counting.
- [x] Implement `trendingReelsProvider` and `trendingReelsGenreProvider` in `lib/features/social/presentation/providers/trending_reels_provider.dart`.
- **Verification**: `flutter test test/features/social/social_providers_test.dart` (9/9 passing).

### T3: TikTok-Style `ReelsCommentSheet` Component
- [x] Build `ReelsCommentSheet` in `lib/features/social/presentation/widgets/reels_comment_sheet.dart`:
  - Drag handle and header with comment count & close button.
  - Pinned Top Supporter banner when user has high reaction count.
  - Comment tile with avatar, handle, relative timestamp, honest love count badge, and comment heart button.
  - African cultural quick emoji badges (🔥, 👑, 🇿🇦, 🎹, 🐐, ❤️).
  - Quick praise chips (`"This log drum hits different! 🎹"`, `"Makhado sunrise vibe 🌅"`, `"Top tier production 🔥"`, `"Proudly South African 🇿🇦"`).
  - Sticky composer with auto-clearing text input.
- **Verification**: `flutter test test/features/social/reels_comment_sheet_test.dart` (4/4 passing).

### T4: `TrendingReelsShelf` & `TrendingReelCard` Component
- [x] Build `TrendingReelCard` and `TrendingReelsShelf` in `lib/features/social/presentation/widgets/trending_reels_shelf.dart`:
  - 9:16 aspect ratio card with creator avatar, handle, verified badge, play count, like count.
  - Zero-video lightweight design token presentation with genre gradients.
  - Genre filter chips: `All`, `#Amapiano`, `#Gqom`, `#Maskandi`, `#AfroHouse`.
  - Tapping card opens `KineticReelsModal` centered at tapped index.
- **Verification**: `flutter test test/features/social/trending_reels_shelf_test.dart` (3/3 passing).

### T5: Integration into Discovery & Action Rail
- [x] In `KineticReelsModal`:
  - Wire 💬 comment button on the action rail to launch `ReelsCommentSheet`.
  - Wire ❤️ like button to support multi-tap love bursts with floating particle animation and counter badge.
- [x] In `ExploreView`:
  - Mount `TrendingReelsShelf` as a dedicated discovery section.
- [x] In `HomeDashboardView`:
  - Mount `TrendingReelsShelf` for instant front-door discovery.
- **Verification**: `flutter test test/features/social test/features/explore test/features/home` (77/77 passing).

### T6: Verification, Static Analysis & Documentation
- [x] Run `flutter analyze` ensuring 0 issues (`No issues found!`).
- [x] Run all targeted `flutter test` suites ensuring 100% pass rate (77/77 passing).
- [x] Commit atomically on `main` with standard conventional commit message.
- [x] Update `docs/AGENT_HANDOFF_BIBLE.md` and `README.md`.
