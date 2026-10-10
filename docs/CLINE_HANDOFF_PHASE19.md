# Master Prompt: Phase 19 — Trending Reels Discovery & TikTok Community Engagement

> **Execution Standard:** Dual-Agent Pair Programming Standard ([`docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md))  
> **Working Directory:** `apps/vhunambi_client`  
> **Specification Reference:** [`docs/phases/phase_19_trending_reels_and_social_engagement/`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/phases/phase_19_trending_reels_and_social_engagement/)  
> **Current Baseline:** `flutter analyze` reports `No issues found!`; all 26/26 social feature tests pass 100%.  

---

## 1. Objectives & Executive Summary

You are the Workhorse Agent implementing the UI components and screen integrations for **Phase 19** of Vhunambi. The architectural foundation, domain models, and Riverpod state notifiers have already been designed, implemented, and verified by Antigravity (Chief Architect):
- `ReelComment` domain model (`lib/features/social/domain/models/reel_comment.dart`)
- `PublishedClip.userReactionCount` multi-tap love tracker
- `reelsCommentsProvider` & `clipCommentsFamilyProvider` (`lib/features/social/presentation/providers/reels_comments_provider.dart`)
- `trendingReelsProvider` & `trendingReelsGenreProvider` (`lib/features/social/presentation/providers/trending_reels_provider.dart`)
- `SocialFeedNotifier.recordLove(clipId)` multi-tap love method

Your task is to implement the **visual presentation layer**, wire the reactive user interactions, integrate the shelves into `ExploreView` and `HomeDashboardView`, and write comprehensive widget tests.

---

## 2. Guardrails & Repo Rules

1. **Brand Identity**: Strictly `vhunambi` (with an **i**).
2. **Design Tokens**: Strictly use `AppColors`, `AppRadius`, `AppTypography`, `AppSpacing`, and `AppGradients` from `package:vhunambi_client/core/theme/`. **Never hardcode raw hex values or ad-hoc border radii.**
3. **Responsive Helpers**: Use `ResponsiveUtils.isDesktop(context)` (> 1024px) vs `ResponsiveUtils.isMobile(context)` (< 768px).
4. **Zero Heavy Video Invariant**: Trending cards and preview shelves must render using cover images and genre gradients — never instantiate video decoders or MP4 stream players.
5. **Widget Test Safety**: Set `tester.view.physicalSize = const Size(1280, 2400)` and use `await tester.pumpAndSettle()` for modal sheets to avoid assertion failures.

---

## 3. Concrete Implementation Tasks

### Task 1: Build `TrendingReelCard` & `TrendingReelsShelf`
**Target File:** `lib/features/social/presentation/widgets/trending_reels_shelf.dart`

1. **`TrendingReelCard`** (Stateless or ConsumerWidget):
   - 9:16 aspect ratio (e.g. width 140px, height 248px on mobile; width 160px on desktop).
   - Card container with `AppRadius.cardBorder` (12px), `BoxDecoration` with `AppGradients.forGenre(clip.genre)`, and subtle border `AppColors.borderSubtle`.
   - If `clip.coverUrl.isNotEmpty`, render cached network image with `BoxFit.cover`.
   - Subtle dark gradient overlay at bottom (`Colors.transparent` to `Colors.black87`).
   - Top-left or bottom-left metadata:
     - Creator Avatar (24x24) + `@${clip.creatorUsername}` with verified check icon if `clip.isCreatorVerified`.
     - Song title (1 line, `AppTypography.bodySmall`, bold).
     - Viral metrics row: `▶ ${formatLikes(clip.playCount)}` and `❤️ ${formatLikes(clip.likeCount)}`.
   - Tapping the card:
     - Launches `KineticReelsModal(clips: reels, initialIndex: index)` via `Navigator.of(context).push(MaterialPageRoute(...))`.

2. **`TrendingReelsShelf`** (ConsumerWidget):
   - Top header row:
     - Title: `'Trending Kinetic Reels 🎬'` (`AppTypography.titleMedium` / `AppTypography.titleLarge`).
     - Subtitle / badge: `'Discover African Creators'`.
     - Right: `'View all ->'` text button that launches `KineticReelsModal` with the full trending list.
   - Horizontal genre filter pills row:
     - Chips for `kTrendingGenres`: `['All', '#Amapiano', '#Gqom', '#Maskandi', '#AfroHouse']`.
     - Highlight active pill with `AppColors.brandPrimary` background and `AppColors.brandContrast` text; inactive with `AppColors.surfaceSecondary`.
     - Tapping a pill updates `ref.read(trendingReelsGenreProvider.notifier).state = genre`.
   - Horizontal scrollable list:
     - `ListView.separated` with `scrollDirection: Axis.horizontal`, height ~260-280px.
     - Renders `TrendingReelCard` for each clip in `ref.watch(trendingReelsProvider)`.

---

### Task 2: Build TikTok-Style `ReelsCommentSheet`
**Target File:** `lib/features/social/presentation/widgets/reels_comment_sheet.dart`

1. **Sheet Structure**:
   - Static entry method: `static Future<void> show(BuildContext context, {required PublishedClip clip})`.
   - Opens via `showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: ...)`.
   - Container with `AppColors.surfaceModal`, rounded top corners (`BorderRadius.vertical(top: Radius.circular(20))`), max height ~75% screen height.
   - Top center drag handle (`width: 40, height: 4`, `AppColors.borderSubtle`).
   - Header row:
     - Title: `'Comments (${comments.length})'` (`AppTypography.titleMedium`, bold).
     - Close `IconButton(icon: Icons.close_rounded, onPressed: () => Navigator.of(context).pop())`.
   - Pinned Top Supporter Banner:
     - If any comment or user has `userReelLoves >= 3`, render a banner:
       `'🔥 Honest Community: @${topUser} loved this reel ${topLoves}x ❤️'` in `AppColors.surfaceElevated` with gold/flame accent.
   - Comment List:
     - `ListView.separated` of comments from `ref.watch(clipCommentsFamilyProvider(clip.id))`.
     - Each tile:
       - Left: Avatar circle (32x32) with monogram or initials.
       - Center Column:
         - Row with `@${comment.username}`, optional `[Creator]` badge if `comment.isCreator`, optional `[Loved ${comment.userReelLoves}x ❤️]` badge, and `comment.timeAgo`.
         - Comment text body (`AppTypography.bodySmall`, selectable or wrapped).
         - Small `'Reply'` button text.
       - Right: Heart icon (`Icons.favorite_rounded` if `comment.isLikedByMe` else `Icons.favorite_border_rounded`), color `AppColors.brandPrimary` or `AppColors.textTertiary`, and like count below.
       - Tapping heart calls `ref.read(reelsCommentsProvider.notifier).toggleCommentLike(clipId: clip.id, commentId: comment.id)`.
   - Quick Cultural Reaction & Praise Row:
     - Horizontal chips above text field:
       - Emojis: `['🔥', '👑', '🇿🇦', '🎹', '🐐', '❤️']`
       - Praise pills: `['Hits different! 🎹', 'Makhado sunrise 🌅', 'Top tier production 🔥', 'Proudly SA 🇿🇦']`
       - Tapping emoji or praise pill inserts the text into the `TextEditingController`.
   - Sticky Composer:
     - Bottom `Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 12), ...)`
     - `TextField` with `hintText: 'Add a comment for @${clip.creatorUsername}...'`, `hintStyle: TextStyle(color: AppColors.textTertiary)`.
     - Send button (`Icons.arrow_upward_rounded` inside circular primary container).
     - Submitting calls `ref.read(reelsCommentsProvider.notifier).addComment(clipId: clip.id, text: text, userReelLoves: clip.userReactionCount)`.

---

### Task 3: Enhance `KineticReelsModal` Action Rail
**Target File:** `lib/features/social/presentation/widgets/kinetic_reels_modal.dart`

1. **Wire Comment Button**:
   - In `_ActionRail`, wire the comment button (`Icons.mode_comment_outlined`):
     ```dart
     _RailButton(
       key: const Key('reel_comment_btn'),
       icon: Icons.mode_comment_outlined,
       color: AppColors.textPrimary,
       label: '${clip.commentCount}',
       onTap: () => ReelsCommentSheet.show(context, clip: clip),
     ),
     ```
2. **Multi-Tap Love Reaction Engine**:
   - When tapping the like button (`reel_like_btn`), call `ref.read(socialFeedProvider.notifier).recordLove(clip.id)`.
   - If `clip.userReactionCount > 0`, display a floating badge or toast: `"Loved ${clip.userReactionCount}x! ❤️"`.
   - Update `label: formatLikes(clip.likeCount)`.

---

### Task 4: Integrate `TrendingReelsShelf` into Explore & Home
1. **In `ExploreView` (`lib/features/explore/presentation/views/explore_view.dart`)**:
   - Add a `SliverToBoxAdapter` mounting `TrendingReelsShelf()` between the African Music Charts hero banner and the Hero Grid / Rising section.
2. **In `HomeDashboardView` (`lib/features/home/presentation/views/home_dashboard_view.dart`)**:
   - Add a `SliverToBoxAdapter` mounting `TrendingReelsShelf()` right after the Quick Actions Grid or before Daily Rhythm Spotlight.

---

### Task 5: Tests & Verification Gates
1. Create `test/features/social/trending_reels_shelf_test.dart`:
   - Verifies header, genre pills, horizontal scrolling cards, and tapping a card launches `KineticReelsModal`.
2. Create `test/features/social/reels_comment_sheet_test.dart`:
   - Verifies comment sheet renders seeded comments, tapping heart toggles comment like, tapping cultural reaction chip inputs text, and submitting adds a comment optimistically.
3. Update `test/features/social/kinetic_reels_modal_test.dart`:
   - Verifies tapping comment button opens `ReelsCommentSheet`.
4. Run:
   ```bash
   flutter analyze
   flutter test test/features/social
   flutter test test/features/explore
   flutter test test/features/home
   ```
   **Threshold:** `0 static issues` and `100% test pass rate`.
