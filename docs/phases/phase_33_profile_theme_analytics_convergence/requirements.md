# Phase 33: Multi-Dimensional Creator Profile Hub, Adaptive Light/Dark Theme Engine & Synchronized Platform Analytics — Requirements

**Document Version:** 1.0.0  
**Status:** Canonical Engineering Specification  
**Document ID:** `PHASE-33-REQUIREMENTS`  
**Standard Reference:** `STD-UIUX-001`  

---

## 1. Functional Requirements

### Pillar 1: Adaptive Light & Dark Theme Engine

- **REQ-THM-01: Tri-State Theme Mode Management**
  The platform MUST support three distinct theme modes:
  1. `ThemeMode.system` (Default): Automatically tracks the host operating system's dark/light appearance setting.
  2. `ThemeMode.light`: Locks the application into the "Warm African Daylight" light mode palette.
  3. `ThemeMode.dark`: Locks the application into the "Obsidian Studio" dark mode palette.

- **REQ-THM-02: Hive Preference Persistence**
  User theme selection MUST be stored in the dedicated Hive box (`AppConstants.themePrefsBoxKey = 'vhunambi_theme_prefs_box'`). In headless test environments where Hive is uninitialized, the provider MUST gracefully fall back to in-memory state without crashing.

- **REQ-THM-03: Dynamic Palette Dual-Resolution**
  `AppColors` MUST provide dynamic resolution for surface and text tokens:
  - `surfaceCanvas`: Dark `#0A0A0C` vs. Light `#F7F5F0` (Warm Ivory)
  - `surfaceElevated`: Dark `#141418` vs. Light `#FFFFFF` (Crisp Card White)
  - `surfaceSecondary`: Dark `#1B1B22` vs. Light `#EDEAE2` (Soft Sand)
  - `surfaceModal`: Dark `#16161C` vs. Light `#FAF8F5`
  - `textPrimary`: Dark `#FFFFFF` vs. Light `#121216` (Deep Charcoal)
  - `textSecondary`: Dark `#A1A1AA` vs. Light `#52525E` (Slate)
  - `borderSubtle`: Dark `#2D2D38` vs. Light `#DFDBD0` (Warm Stone)
  - `brandPrimary` (`#F97316`) and accents MUST maintain high visual punch in both modes.

- **REQ-THM-04: Glare-Free Themed SnackBars**
  `AppTheme` MUST configure `snackBarTheme` for both light and dark themes with `elevation: 4`, `behavior: SnackBarBehavior.floating`, and `backgroundColor: AppColors.surfaceElevated`, preventing default white rectangles in Dark Mode.

---

### Pillar 2: Synchronized Cross-Platform Analytics Engine

- **REQ-ANA-01: Multi-Provider Live Aggregation**
  `synchronizedAnalyticsProvider` MUST reactively watch:
  - `libraryTracksProvider`: Active tracks, total play counts, like counts, and duration.
  - `socialFeedProvider` & `socialFeedPostsProvider`: Published Kinetic Reels, reel views, likes, and remix derivations.
  - `beatsProvider` & `marketplaceBeatsProvider`: Commercial beats listed, sales, and conversion rate.
  - `creatorWalletProvider`: Realized ZAR royalties, user coin balance, and cultural gifts.
  - `vocalIdentityProvider`: Cloned voice profiles created.
  - `melodySketchpadProvider`: Saved multi-track groove sketches in the local vault.

- **REQ-ANA-02: Real-Time Dynamic Top Genres Calculation**
  The analytics engine MUST compute a real-time `genreDistributionMap` (e.g. `{ 'Amapiano': 6, 'Afro House': 3, 'Maskandi': 2 }`) sorted descending by count, dynamically updating `TOP GENRES` chips on `OwnerProfileView` whenever a track or beat is added or removed.

- **REQ-ANA-03: Interactive Studio Analytics Console Sheet**
  Tapping `Studio Analytics` on `OwnerProfileView` (`Key('owner_analytics_btn')`) OR the Analytics action in `LibraryAppBar` MUST open `StudioAnalyticsConsoleSheet.show(context)`:
  - Exposes period filters: `7 Days`, `30 Days`, and `All Time`.
  - Displays 4 core KPI metric cards: Total Streams (Audio + Reels), Net ZAR & Coin Revenue, Viral Reel Remixes, and Beatstore Licenses Sold.
  - Renders a custom bezier area velocity chart (`CustomPainter`) plotting plays vs. earnings.
  - Lists the top performing songs, reels, and beats in a ranked leaderboard.

---

### Pillar 3: Multi-Dimensional Sovereign Creator Profile

- **REQ-PRF-01: Zero-Stub Profile Actions**
  All placeholder SnackBars on `OwnerProfileView` MUST be permanently eliminated:
  - `Edit Profile` opens `EditProfileSheet`.
  - `Pin Song` opens `PinSongSelectorSheet`.
  - `Studio Analytics` opens `StudioAnalyticsConsoleSheet`.

- **REQ-PRF-02: Real Profile Identity Editing (`EditProfileSheet`)**
  `EditProfileSheet` MUST allow creators to modify:
  - Display Name (`displayName`)
  - Username (`@username`)
  - Bio (`bio`)
  - Primary Signature Genres
  Saving changes MUST update `ownerProfileProvider`, persist to Hive (`AppConstants.profileBoxKey`), and immediately reflect across the profile header.

- **REQ-PRF-03: Pinned Spotlight Anthem Card**
  `PinSongSelectorSheet` MUST list the creator's songs and beats. Selecting an item sets `pinnedTrackId` on `ArtistProfileEntity` and renders a prominent spotlight card (`Key('profile_pinned_spotlight_card')`) above the studio tabs on both `OwnerProfileView` and `ArtistProfileView` with 1-tap playback.

- **REQ-PRF-04: 5-Dimension Owner Studio Vault Tabs**
  `OwnerStudioTab` MUST be expanded to 5 tabs:
  1. `songs`: User's master audio catalog with Public/Private visibility toggling.
  2. `reels`: User's published 9:16 Kinetic Reels grid with shortcut to post a new reel.
  3. `beatstore`: `OwnerBeatstoreCockpit` displaying listed beats, stems status, and pricing.
  4. `voicesAndMelodies` (`Key('owner_studio_tab_voices_melodies')`): Displays Cloned Vocal DNA Profiles (Phase 26) and Saved Multi-Track Melody Grooves (Phase 32) with 1-tap preview audition and `"Open in Studio"` routing.
  5. `releases`: EP, album, and single release packages.

- **REQ-PRF-05: Appearance & Settings Drawer**
  `OwnerProfileView` MUST feature a Settings action pill and header icon opening `ProfileSettingsDrawer`:
  - Contains a 3-way segmented theme mode controller: `[ 📱 System | ☀️ Light | 🌙 Dark ]` with keys `Key('theme_mode_system')`, `Key('theme_mode_light')`, and `Key('theme_mode_dark')`.
  - Exposes audio caching and privacy preferences.

- **REQ-PRF-06: Strict Phosphor Vector Compliance (`STD-UIUX-001`)**
  All raw emojis in action pills (`✨`, `✏️`, `📌`, `📊`) MUST be replaced with official compile-time `AppIcons` or `PhosphorIcon` constants.

- **REQ-PRF-07: Mini-Player Docking Inset Safeguard**
  The profile viewport MUST reserve sufficient bottom padding (`kBottomNavigationBarHeight + 80`) when the audio player is active, ensuring the floating mini-player docks above navigation and never collides with the `CreatorDnaProfileCard`.

---

## 2. Non-Functional & Reliability Requirements

- **NFR-01: Zero Static Analyzer Warnings**
  `dart analyze lib test` in `apps/vhunambi_client` MUST pass with `0 issues found!`.
- **NFR-02: Test Suite Preservation**
  Existing tests in `owner_profile_view_test.dart` and `artist_profile_view_test.dart` MUST continue to pass 100% green.
- **NFR-03: APK Size Budget**
  The release APK must remain under **200.0 MB** on Android ARM64.

