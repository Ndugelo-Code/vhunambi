# Master Handoff Prompt: Phase 7 — Track Details & Creator Profiles (`/track/:id`, `/profile/:id`, `/profile/me`)

> **To be executed by:** Cline (DeepSeek V4 Flash / 1M Context Window) OR Antigravity IDE  
> **Working Directory:** `apps/vhunambi_client/`  
> **Source Blueprint:** `docs/foundation_blueprints/06_TRACK_AND_CREATOR_PROFILES_SPEC.md`  
> **Phase 4-Doc Suite:** `docs/phases/phase_07_track_profiles/` (`blueprint.md`, `requirements.md`, `design.md`, `tasks.md`)  
> **Architecture Standard:** `docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`

---

## Pre-Flight Status & Guardrails

1. **Baseline Status:** `dart analyze .` reports **0 issues**. `flutter test` reports **127 of 127 tests passing cleanly (100%)**.
2. **Brand Identity:** Name is strictly **`vhunambi`** (with an **i**, from Tshivenḓa for *"the talent or ability to sing"*). Never use `vhunamba`.
3. **Design Tokens:** Strictly utilize `AppColors`, `AppGradients`, `AppTypography`, `AppRadius`, and `AppSpacing` from `package:vhunambi_client/core/theme/`. **NEVER hardcode raw hex values or ad-hoc border radii.**
4. **Collision Safety:** Do NOT import `RepeatMode` from Flutter; our audio repeat enum is `AudioRepeatMode`.
5. **Responsive Utilities:** Use `ResponsiveUtils.isDesktop(context)` (> 1024px) vs `ResponsiveUtils.isMobile(context)` (< 768px).
6. **Layer Hygiene:** Presentation widgets depend on Riverpod providers; providers manipulate immutable domain state models; UI never mutates state directly.
7. **Audio Player Integration:** When playing tracks or auditioning stems, interact with `ref.read(playerStateProvider.notifier).playTrack(track)` so audio plays continuously in the persistent dock.

---

## Phase 7 Implementation Goal

Build out the complete Track Details dissection suite and Creator Profile ecosystem:
1. **The Track Details Cockpit (`TrackDetailView`)** under `lib/features/track/` for `/track/:id`.
2. **The Public Artist Profile (`ArtistProfileView`)** under `lib/features/profile/` for `/profile/:id`.
3. **The Account Owner Creator Studio Profile (`OwnerProfileView`)** under `lib/features/profile/` for `/profile/me`.

---

## Step-by-Step Task Sequence

### 1. Domain Models
- **Track Details Models** (`lib/features/track/domain/models/track_detail_models.dart`):
  - `LicenseType` enum (`personal`, `commercial`).
  - `StemTrackEntity`: `id`, `name` (`'Vocals'`, `'Drums'`, `'Bass'`, `'Instrumental'`), `audioUrl`, `duration`, `isMuted`, `isSoloed`, `volume`, `copyWith`.
  - `StemSeparationStatus` enum (`idle`, `isolatingVocals`, `isolatingDrums`, `isolatingBass`, `isolatingInstrumental`, `ready`, `error`).
  - `StemSeparationState`: `status`, `progress` (0.0 to 1.0), `stems` (List), `errorMessage`, `isProcessing`, `stepLabel`, `copyWith`.
  - `TrackDetailEntity`: `id`, `title`, `genre`, `language`, `duration`, `creatorId`, `creatorName`, `creatorHandle`, `licenseType`, `isLiked`, `likesCount`, `playCount`, `reactions` (`Map<String, int>`), `userReactions` (`Set<String>`), `lyrics`, `prompt`, `stemState`, `copyWith`.
  - `CommentEntity`: `id`, `trackId`, `authorName`, `authorHandle`, `content`, `createdAt`, `likesCount`, `isLiked`.
- **Profile Models** (`lib/features/profile/domain/models/profile_models.dart`):
  - `SupporterEntity`: `id`, `name`, `handle`, `totalCreditsTipped`, `rank` (1, 2, 3), `rankBadge` (`'🥇 Gold'`, `'🥈 Silver'`, `'🥉 Bronze'`).
  - `TipRecordEntity`: `id`, `senderName`, `senderHandle`, `recipientName`, `amountCredits`, `trackTitle`, `timestamp`, `isReceived`.
  - `ReleaseType` enum (`single`, `ep`, `album`).
  - `MusicReleaseEntity`: `id`, `title`, `releaseType`, `trackCount`, `releaseDate`, `genre`, `typeLabel`.
  - `ArtistProfileEntity`: `id`, `username`, `displayName`, `monogram`, `bio`, `isVerified`, `songCount`, `likeCount`, `playCount`, `followerCount`, `dayStreak`, `isFollowing`, `tipsEnabled`, `topGenres`, `topSupporters`, `releases`, `tipHistory`, `copyWith`.

### 2. Riverpod State Providers
- **Track Providers** (`lib/features/track/presentation/providers/track_providers.dart`):
  - Seed catalog with rich metadata tracks:
    1. `'seed-01'`: *"Ndo Mufuna Matibe"*, Amapiano, Tshivenḓa, 3:18, Creator: Fifi (`@fifi`), Seed Prompt: *"Ndo mufuna Matibe deep amapiano with atmospheric Rhodes and heavy log drums"*, Complete Tshivenḓa lyrics with `[Verse 1]`, `[Pre-Chorus]`, `[Chorus]`.
    2. `'track_default_1'`: *"Grateful in the Light"*, Amapiano, English, 3:29, Creator: Sigwa & Inaf (`@sigwa`).
    3. `'exp_track_001'`: *"Township Funk"*, Kwaito, isiZulu, 3:12, Creator: DJ Vibe (`@djvibe`).
  - `TrackDetailNotifier` and `trackDetailFamilyProvider`:
    - `toggleLike()`: Optimistic toggle on `isLiked` and `likesCount`.
    - `toggleReaction(String key)`: Supports `'fire'`, `'love'`, `'rhythm'`, `'hands'`, `'globe'`.
    - `separateStems()`: Async multi-step simulation transitioning through `isolatingVocals` $\rightarrow$ `isolatingDrums` $\rightarrow$ `isolatingBass` $\rightarrow$ `isolatingInstrumental` $\rightarrow$ `ready` (generating 4 `StemTrackEntity` items).
    - `toggleMuteStem(String id)` & `toggleSoloStem(String id)`.
  - `trackCommentsProvider`: Seeded comments list with `addComment(String content)`.
- **Profile Providers** (`lib/features/profile/presentation/providers/profile_providers.dart`):
  - Seeded profiles:
    1. `'fifi'` / `'creator_001'`: Fifi (Monogram `FI`, Verified, 8 Songs, 1,240 Likes, 45,200 Plays, 1,820 Followers, 🔥 4 Day Streak, Top Genres: Amapiano, House, Afro Soul, 3 top supporters: Sipho_M [500], LeratoK [350], DJThabo [200]).
    2. `'me'`: cern (Monogram `CE`, Owner Studio Profile, 7 Songs, Top Genres: House [1], Amapiano [4], Maskandi [2], Tip history received 120 credits, sent 35 credits).
  - `ArtistProfileNotifier` and `artistProfileFamilyProvider`:
    - `toggleFollow()`, `tipArtist(int credits)`.
  - `ownerProfileProvider`:
    - `toggleTipsEnabled()`, `addRelease(MusicReleaseEntity release)`, `toggleTrackVisibility(String trackId)`.

### 3. Track Details UI Components (`lib/features/track/presentation/widgets/`)
- **`track_hero_section.dart`**:
  - Centered 1:1 artwork card (`280x280px` desktop / `220x220px` mobile) with `AppGradients.forGenre(track.genre)`.
  - Ambient amber glow shadow: `BoxShadow(color: Color(0x3DF97316), blurRadius: 40, spreadRadius: -8)`.
  - Track Title (`28px` bold), metadata line (`${genre} • ${language} • ${duration}`), license pill badge (`[ 🛡️ Personal Use ]` / `[ ⚖️ Commercial Use ]`).
  - Ownership notice banner: *"This track is 100% royalty-free and owned by you..."*.
  - Creator byline with link routing to `ArtistProfileView`.
- **`track_actions_bar.dart`**:
  - Primary row: `❤️ Like` with live tally, `▶ Plays`, `🔀 Remix` (routes to Studio with prompt pre-filled), `💰 Tip` (opens in-app tipping modal).
- **`utility_tool_dock.dart`**:
  - Horizontal scrollable strip: `⬇ Download` (MP3/WAV options), `➕ Playlist`, `📻 Radio` (launches radio in player), `📝 Lyrics` (scrolls down), `🔀 Variation` (Studio 2-take), `💬 Comments`, `</> Embed` (copies iframe snippet).
- **`emoji_reaction_deck.dart`**:
  - 5 cultural reaction pills: `🔥 Fire`, `❤️ Love`, `🎵 Rhythm`, `🙌 Praise`, `🌍 African Unity`.
  - Tapping toggles user selection, updates tally, and toggles `AppColors.brandPrimary` border.
- **`waveform_scrubber.dart`**:
  - High-resolution amplitude waveform spanning container width.
  - Active duration painted in `AppColors.brandPrimary`, remaining in `AppColors.borderSubtle`.
  - Interactive tap-to-seek and drag scrub wired into `playerStateProvider`.
- **`lyrics_teleprompter.dart`**:
  - Section header `"LYRICS"`.
  - Bracketed structural tags (`[Verse 1]`, `[Chorus]`, etc.) in `AppColors.brandPrimary` (`13px`, bold).
  - 16px white lyrical lines with line height `1.6`.
- **`stem_separation_lab.dart`**:
  - Card with `"Stem Separation"` and description.
  - Action button `"🎛️ Separate Stems"`.
  - Shows progress spinner with step description during isolation.
  - Once ready, renders 4 stem cards (`Vocals`, `Drums`, `Bass`, `Instrumental`) with Solo, Mute, Volume, and `"Download Stem"` buttons.
- **`prompt_attribution_card.dart`**:
  - Section header `"PROMPT"`.
  - Inset container displaying seed prompt string and `"Remix Prompt ✨"` button that writes to `studioFormProvider` and navigates to Studio Cockpit.
- **`comments_section.dart`**:
  - Section header `"Comments (${comments.length})"`.
  - Input field `"Add a comment..."` with send button.
  - Renders comment tiles with author avatar, handle, text, time-ago, and like button.
- **`more_like_this_shelf.dart`**:
  - Shelf of related tracks in same genre with one-tap play audition buttons.

### 4. Track Details Screen Assembly (`lib/features/track/presentation/views/track_detail_view.dart`)
- Sticky top app bar with `< Back`, `VHUNAMBI`, and `Share`.
- Centered container (max-width `860px` on Desktop).
- Assembles Hero Section, Actions Bar, Utility Dock, Emoji Deck, Waveform Scrubber, Lyrics Teleprompter, Stem Lab, Prompt Card, Comments, and More Like This shelf.

### 5. Creator Profile UI Components (`lib/features/profile/presentation/widgets/`)
- **`profile_banner_header.dart`**:
  - Ambient cover banner (`180px` desktop / `140px` mobile) with radial bronze-amber gradient and floating instrument watermark glyphs.
  - Monogram avatar circle (`84x84px`) with `4px solid #0A0A0C` perimeter cutout and bold black initials.
  - Artist name, verified badge (`Icons.verified_rounded`, `#3B82F6`), bio text.
  - Action row: `Follow / Following` pill button, `💰 Tip Artist` button, `Share`, and `Report`.
- **`profile_stats_grid.dart`**:
  - Responsive 5-metric grid: `🎵 Songs`, `❤️ Likes`, `▶ Plays`, `👥 Followers`, `🔥 Day Streak`.
- **`top_supporters_leaderboard.dart`**:
  - Leaderboard cards for top tipping supporters (`🥇 Gold`, `🥈 Silver`, `🥉 Bronze`).
- **`releases_manager_card.dart`**:
  - Discography manager card with `+ New Release` button and release cards.
- **`tip_history_ledger.dart`**:
  - `Tips on` master switch.
  - `Received` vs `Sent` tabs displaying transaction history ledger.
- **`profile_referral_card.dart`**:
  - `"Share your profile"` card with one-tap `"🔗 Copy Profile Link"` copying URL to clipboard.

### 6. Profile Views Assembly
- **`artist_profile_view.dart`** (`lib/features/profile/presentation/views/artist_profile_view.dart`):
  - Public artist profile for `/profile/:id`.
  - Top bar with `< Back`, `VHUNAMBI`, and notification bell.
  - Composes Banner Header, 5-Metric Grid, Top Songs shelf with play buttons, Top Supporters Leaderboard, and Recent Activity feed.
- **`owner_profile_view.dart`** (`lib/features/profile/presentation/views/owner_profile_view.dart`):
  - Creator Studio Profile for `/profile/me`.
  - Composes Owner Header with `Edit Profile`, `Pin Song`, `Studio Analytics`, Top Genres chips, Your Songs manager with inline Public/Private visibility switches, Releases manager, Tip History ledger, and Referral card.

### 7. Inter-Feature Navigation Wiring
- Update track list tiles and cards in `ExploreView` (`lib/features/explore/`), `HomeDashboardView` (`lib/features/home/`), and `LibraryView` (`lib/features/library/`) so tapping the title/card navigates to `TrackDetailView(trackId: track.id)`.
- Update creator handles/avatars so tapping navigates to `ArtistProfileView(artistId: track.creatorId)`.
- Wire avatar tap on app bars to navigate to `OwnerProfileView()`.

### 8. Automated Test Suite
- **Track Unit Tests** (`test/features/track/track_notifier_test.dart`):
  - Test initial track details resolution.
  - Test `toggleLike()` count increments and decrements.
  - Test `toggleReaction()` for all 5 emoji reactions.
  - Test `separateStems()` 4-step pipeline transitions and stem generation.
  - Test `toggleMuteStem()` and `toggleSoloStem()`.
- **Profile Unit Tests** (`test/features/profile/profile_notifier_test.dart`):
  - Test initial artist profile stats and supporters.
  - Test `toggleFollow()` updates count and following flag.
  - Test `toggleTipsEnabled()` updates setting.
  - Test `addRelease()` appends new discography entry.
- **Widget Tests**:
  - `test/features/track/track_detail_view_test.dart`: Renders artwork, title, reactions, scrubber, lyrics, and stem lab.
  - `test/features/profile/artist_profile_view_test.dart`: Renders banner, monogram, 5 stats, and top supporters.
  - `test/features/profile/owner_profile_view_test.dart`: Renders studio controls, top genres chips, releases, and tip ledger.

---

## Verification Criteria

Inside `apps/vhunambi_client/`:
```powershell
# 1. Static Analysis Gate
dart analyze .
# MUST report: No issues found! (0 issues)

# 2. Automated Test Suite
flutter test
# MUST pass 100% of all tests (127 baseline + new Phase 7 tests)
```
