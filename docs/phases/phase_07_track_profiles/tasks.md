# Phase 7 Tasks & Execution Checklist: Track Details & Creator Profiles

> **Target Package:** `apps/vhunambi_client`  
> **Route Paths:** `/track/:id`, `/profile/:id`, `/profile/me`  
> **Pre-Flight Baseline:** `dart analyze .` $\rightarrow$ 0 issues | `flutter test` $\rightarrow$ 127/127 passing tests (100%)  
> **Standard:** [Dual-Agent Pair Programming Protocol](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md)

---

## Pre-Flight Verification Gate

Before writing code for Phase 7, the executing agent **MUST** confirm the repository baseline:

```powershell
cd c:\Users\Ndugelo\VHUNAMBI\monorepo\apps\vhunambi_client
dart analyze .
# Result MUST be: No issues found!

flutter test
# Result MUST be: 127 of 127 tests passed!
```

---

## Sequenced Implementation Tasks

### Task 7.1: Domain Entities & Immutable Models
- [x] Create `lib/features/track/domain/models/track_detail_models.dart`:
  - `LicenseType` enum (`personal`, `commercial`).
  - `StemTrackEntity` (id, name, audioUrl, duration, isMuted, isSoloed, volume).
  - `StemSeparationStatus` enum and immutable `StemSeparationState` (status, progress, stems list, stepLabel).
  - `TrackDetailEntity` (id, title, genre, language, duration, creatorId, creatorName, creatorHandle, licenseType, isLiked, likesCount, playCount, reactions, userReactions, lyrics, prompt, stemState).
  - `CommentEntity` (id, trackId, authorName, authorHandle, content, createdAt, likesCount, isLiked).
- [x] Create `lib/features/profile/domain/models/profile_models.dart`:
  - `SupporterEntity` (id, name, handle, totalCreditsTipped, rank, rankBadge).
  - `TipRecordEntity` (id, senderName, senderHandle, recipientName, amountCredits, trackTitle, timestamp, isReceived).
  - `ReleaseType` enum (`single`, `ep`, `album`) and `MusicReleaseEntity` (id, title, releaseType, trackCount, releaseDate, genre).
  - `ArtistProfileEntity` (id, username, displayName, monogram, bio, isVerified, songCount, likeCount, playCount, followerCount, dayStreak, isFollowing, tipsEnabled, topGenres, topSupporters, releases, tipHistory).

### Task 7.2: Riverpod State Notifiers & Providers
- [x] Create `lib/features/track/presentation/providers/track_providers.dart`:
  - Seeded catalog with detailed tracks (including `seed-01` *"Ndo Mufuna Matibe"*, `track_default_1` *"Grateful in the Light"*, `exp_track_001` *"Township Funk"*).
  - `TrackDetailNotifier` and `trackDetailFamilyProvider` managing like toggle, emoji reaction toggle, 4-step stem separation simulation, solo/mute stem controls.
  - `trackCommentsProvider` with seeded comments and add-comment action.
- [x] Create `lib/features/profile/presentation/providers/profile_providers.dart`:
  - Seeded profiles for `fifi`, `cern`, `sigwa_inaf`, `dj_vibe`.
  - `ArtistProfileNotifier` and `artistProfileFamilyProvider` managing follow toggle and tipping.
  - `ownerProfileProvider` managing creator release creation, tipping toggle, and tip history.

### Task 7.3: Track Details Sub-Widgets
- [x] Create `lib/features/track/presentation/widgets/`:
  - `track_hero_section.dart`: 1:1 artwork showcase (`280x280px` desktop / `220x220px` mobile), `AppGradients.forGenre`, ambient amber glow shadow (`BoxShadow(0x3DF97316)`), title, metadata row, personal/commercial license badge, ownership notice, and creator byline route.
  - `track_actions_bar.dart`: Primary engagement row (`❤️ Like`, `▶ Plays`, `🔀 Remix` routing to Studio, `💰 Tip` modal trigger).
  - `utility_tool_dock.dart`: Horizontally scrollable dock with `⬇ Download` MP3/WAV, `➕ Playlist`, `📻 Radio` endless station, `📝 Lyrics` scroll, `🔀 Variation`, `💬 Comments`, `</> Embed`.
  - `emoji_reaction_deck.dart`: 5 reaction pills (`🔥`, `❤️`, `🎵`, `🙌`, `🌍`) with real-time toggle counters.
  - `waveform_scrubber.dart`: High-resolution amplitude waveform with active brand fill and interactive tap-to-seek wired to `playerStateProvider`.
  - `lyrics_teleprompter.dart`: Formatted lyrical stanzas with bracketed structural tags in `brandPrimary`.
  - `stem_separation_lab.dart`: 4-stem extraction FSM card, stem cards with Solo/Mute audition and individual download.
  - `prompt_attribution_card.dart`: Seed prompt container with `"Remix Prompt ✨"` action button.
  - `comments_section.dart`: Comments list and input composer field.

### Task 7.4: Track Details Screen Assembly
- [x] Create `lib/features/track/presentation/views/track_detail_view.dart`:
  - Sticky top app bar with `< Back`, `VHUNAMBI`, and `Share`.
  - Max-width `860px` centered desktop layout.
  - Assembles Hero Section, Actions Bar, Utility Dock, Emoji Deck, Scrubber, Lyrics, Stem Lab, Prompt Card, Comments, and "More Like This" recommendations.

### Task 7.5: Creator Profile Sub-Widgets
- [x] Create `lib/features/profile/presentation/widgets/`:
  - `profile_banner_header.dart`: Ambient cover banner (`180px` desktop / `140px` mobile) with musical watermark glyphs, `84x84px` monogram avatar with `4px` cutout, verified badge, bio, and follow/tip action strip.
  - `profile_stats_grid.dart`: 5-metric statistical grid (`Songs`, `Likes`, `Plays`, `Followers`, `Day Streak`).
  - `top_supporters_leaderboard.dart`: Top tipping fans with `🥇 Gold`, `🥈 Silver`, `🥉 Bronze` badges.
  - `releases_manager_card.dart`: Album, EP, Single discography manager with "Create First Release" CTA.
  - `tip_history_ledger.dart`: Master tips switch, `Received` vs `Sent` tabs.
  - `profile_referral_card.dart`: One-tap profile referral copy card with clipboard confirmation.

### Task 7.6: Profile Views Assembly
- [x] Create `lib/features/profile/presentation/views/artist_profile_view.dart`:
  - Public artist profile for `/profile/:id`: Header banner, monogram, 5-metric grid, Top Songs shelf with audio playback triggers, Top Supporters leaderboard, Recent Activity feed.
- [x] Create `lib/features/profile/presentation/views/owner_profile_view.dart`:
  - Creator Studio Profile for `/profile/me`: Header with `Edit Profile`, `Pin Song`, `Studio Analytics`, top genres distribution chips, Your Songs shelf with public/private toggle, Releases manager, Tip History ledger, and Referral card.

### Task 7.7: Navigation & Inter-Feature Route Wiring
- [x] Update track cards across `ExploreView`, `HomeDashboardView`, and `LibraryView` to support tapping to open `TrackDetailView`.
- [x] Update creator bylines/avatars to navigate to `ArtistProfileView`.
- [x] Support opening `OwnerProfileView` from creator avatar in top bar or profile shortcut.

### Task 7.8: Automated Test Verification
- [x] Create unit tests in `test/features/track/track_notifier_test.dart`:
  - Initial track state and metadata resolution.
  - Like count toggle.
  - Emoji reaction toggles (increment/decrement).
  - 4-stem separation FSM progression (`idle` $\rightarrow$ `isolating` $\rightarrow$ `ready`).
  - Stem solo and mute state mutations.
- [x] Create unit tests in `test/features/profile/profile_notifier_test.dart`:
  - Initial artist profile state and 5 metrics.
  - Follow/unfollow toggle.
  - Tipping master toggle and release creation.
- [x] Create widget tests:
  - `test/features/track/track_detail_view_test.dart` (hero, reactions, lyrics, stems, prompt).
  - `test/features/profile/artist_profile_view_test.dart` (banner, monogram, 5 stats, top supporters).
  - `test/features/profile/owner_profile_view_test.dart` (management buttons, releases, tip ledger).
- [x] Execute `dart analyze .` $\rightarrow$ must report **0 issues**.
- [x] Execute `flutter test` $\rightarrow$ must pass **100% of all tests (127 baseline + new Phase 7 tests)**.

---

## Invariant Guardrails & Risk Mitigations

1. **No Raw Hex Values or Ad-Hoc Radii:** Use `AppColors`, `AppGradients`, `AppTypography`, `AppRadius`, and `AppSpacing` exclusively.
2. **Audio Repeat Enum Collision:** Always name audio repeat mode `AudioRepeatMode`, never `RepeatMode` (collides with Flutter 3.44).
3. **No Breaking Regressions:** The 127 existing automated tests must continue passing without modifications.
4. **Idempotent Stem Lab:** The stem separation simulation must be clean and not leak background timers in widget tests.
