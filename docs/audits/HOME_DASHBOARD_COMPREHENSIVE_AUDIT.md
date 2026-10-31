# Vhunambi Creator Home Dashboard: Comprehensive Architectural & UX Audit
**Audit ID:** AUDIT-HOME-003  
**Date:** October 31, 2026  
**Scope:** `apps/vhunambi_client/lib/features/home/` & associated feature bridges (`studio`, `library`, `profile`, `creator_dna`, `social`, `marketplace`)  
**Target:** Creator Home Dashboard (`/` · Tab 0 · `HomeDashboardView`)  
**Ecosystem Alignment:** V4.1 Sovereign African Studio Ecosystem (Creator DNA, 24 Voice Archetypes, Stem Mastering Lab, Melody Sketchpad, Beats Marketplace, Kinetic Reels, Coin & ZAR Royalty Wallet)

---

## 1. Executive Summary

The **Home Dashboard (`HomeDashboardView`)** is the entry gateway, emotional anchor, and creative cockpit of Vhunambi. Mounted at **Tab 0** inside the root navigation shell (`RootShell`), it welcomes creators with an indigenous African greeting, reports their daily creative momentum, and serves as the launchpad into composition, licensing, and audio manipulation.

While the conceptual vision of `HomeDashboardView` is culturally resonant (featuring authentic time-bracketed African greetings, streak indicators, and quick prompts), **a rigorous line-by-line inspection reveals that the Home Dashboard has become severely stranded from the modern V4.1 Vhunambi ecosystem**. 

Over the past 14 development phases, Vhunambi launched the **Coin & ZAR cultural creator economy**, **24 Sovereign Voice Archetypes**, **6-Preset Stem Mastering**, the **Log-Drum & Melody Sketchpad**, the **Beats Marketplace**, and **MMO 2.0 stem slicing**. However, `HomeDashboardView` still runs on legacy mock implementations from an earlier prototype era:

1. **Hardcoded Currency & Streak Counters**: The header displays a hardcoded `'10 left'` bolt icon (`Icons.bolt_rounded`) and `'2 Streak'` pill, completely detached from `creatorWalletProvider` (user coins & ZAR royalties) and `ownerProfile.dayStreak`.
2. **The "Fake" Jump Back In Card**: The "Jump Back In" recent session card watches `exploreTracksProvider` and renders `exploreTracks.first`—presenting a stranger's public track from the Explore catalog as the user's personal unfinished studio project!
3. **Severe Mobile Layout Cramping (360dp)**: The 4-card Quick Actions grid squeezes `AI Studio`, `Beats Market`, `Asset Vault`, and `Stem Lab` into a single rigid horizontal `Row`, crushing card inner widths down to ~54dp on standard mobile devices and forcing awkward text truncation.
4. **Missing Modern Studio Tools**: The Quick Action strip provides no direct entry into **Voice Cloning**, **Melody Sketchpad**, **Stem Mastering**, or the **Beatstore Cockpit**.
5. **Static Rhythm Spotlight**: The "Daily Rhythm Spotlight" is hardcoded to "Maskandi Acoustic Folk Tuning" every day of the week, without dynamic rotation or genre preset injection into the Studio.
6. **Fake "Trending in Your Genres"**: The feed displays the user's onboarding genres in the subtitle, but maps the raw, unfiltered `exploreTracks` catalog in the list below.
7. **Zero In-Flight Generation Visibility**: If a creator triggers an AI generation in the Studio or Cloud GPU and switches to Home, there is no active job status pill or progress banner.

---

## 2. Current Architecture & Component Hierarchy

```mermaid
graph TD
    subgraph Root Navigation Shell
        RootShell["RootShell (IndexedStack - Tab 0)"]
    end

    subgraph HomeDashboardView [HomeDashboardView (CustomScrollView)]
        TopHeader["1. Top Header Bar (Avatar, Greeting, Streak, Credits)"]
        DnaBanner["1b. Creator DNA Insight Card (DnaInsightCard)"]
        PromptCard["2. Quick Studio Creation Prompt Card (Input + 3 Chips)"]
        ActionGrid["3. 4-Card Quick Actions Grid (Row: Studio, Market, Vault, Stem)"]
        JumpBackIn["4. Jump Back In Recent Session Card (exploreTracks.first)"]
        ReelsShelf["4.5. Trending Kinetic Reels Shelf (TrendingReelsShelf)"]
        RhythmSpotlight["5. Daily Heritage Spotlight Banner (Maskandi Hardcoded)"]
        GenreTrending["6. Trending in Your Genres (Unfiltered exploreTracks)"]
        ProBanner["7. Pro Subscription Upgrade Banner (SubscriptionUpgradeModal)"]
    end

    subgraph Disconnected Real State
        WalletState["CreatorWalletState (userCoinsBalance, creatorEarnedZar)"]
        OwnerProfile["ArtistProfileEntity (dayStreak, topGenres)"]
        LibraryVault["LibraryTracksNotifier (user's real drafts & WAV stems)"]
        GenerationEngine["StudioFormNotifier & GenerationJobStore (in-flight jobs)"]
    end

    RootShell --> HomeDashboardView
    HomeDashboardView --> TopHeader
    HomeDashboardView --> DnaBanner
    HomeDashboardView --> PromptCard
    HomeDashboardView --> ActionGrid
    HomeDashboardView --> JumpBackIn
    HomeDashboardView --> ReelsShelf
    HomeDashboardView --> RhythmSpotlight
    HomeDashboardView --> GenreTrending
    HomeDashboardView --> ProBanner

    TopHeader -.->|MISSING WIRE: Hardcoded 10 left| WalletState
    TopHeader -.->|MISSING WIRE: Hardcoded 2 Streak| OwnerProfile
    JumpBackIn -.->|FATAL BUG: Reads Explore Feed instead| LibraryVault
    HomeDashboardView -.->|MISSING WIDGET: No Progress Bar| GenerationEngine
```

---

## 3. Component-by-Component Deep Dive & Forensic Audit

### 3.1. Dashboard Top Header Bar (`home_dashboard_view.dart:85-194`)
- **Built For**: Welcoming the creator with an authentic cultural greeting, displaying creator identity, current creative streak, and available creation currency.
- **Current Implementation**:
  - `CreatorAvatar` (44×44dp): Monogram avatar, `onTap` opens `OwnerProfileView`, `onLongPress` opens `AvatarCustomizationModal`.
  - `Expanded(child: Text('$greetingText $timeGlyph'))`: Cultural time-bracketed greeting (e.g. *"Ndi matsheloni 🌅"*) resolved via `AfricanGreetingResolver` based on `onboardingState.selectedLanguages.first`.
  - `Streak Badge`: Hardcoded `Text('2 Streak')` inside an `AppColors.surfaceSecondary` container with `Text('🔥')`.
  - `Credit Chip`: Hardcoded `Text('10 left')` with `Icons.bolt_rounded`, wrapped in a `GestureDetector` that opens `SubscriptionUpgradeModal`.
- **Architectural & UX Flaws**:
  1. **Hardcoded Mock Tokens**: Neither the streak count nor the credit count is wired to live Riverpod state. In `ownerProfileProvider`, the property `dayStreak` is live. In `creatorWalletProvider`, `userCoinsBalance` is live. Displaying `'10 left'` and `'2 Streak'` erodes user trust and disconnects Home from the rest of the application.
  2. **360dp Horizontal Flex Collisions**: On a 360dp phone viewport with 16dp horizontal padding (328dp available), the elements require:
     - Avatar: 44dp + 12dp margin = 56dp.
     - Streak Pill: ~80dp.
     - Credit Chip: ~85dp.
     - Spacing: 8dp.
     - Total non-text width: $56 + 80 + 85 + 8 = 229\text{dp}$.
     - Remaining space for the greeting: $328 - 229 = 99\text{dp}$!
     - In languages with longer greetings (e.g. *Dumela mo motshegareng ☀️* [Setswana] or *Sawubona kusihlwa 🌙* [isiZulu]), the greeting is severely truncated to *"Dumela mo..."*, destroying the cultural elegance of the greeting.
  3. **No Social/Notification Access**: The Home header has no notification bell, no quick search icon, and no Discovery Drawer trigger.

---

### 3.2. Creator DNA Insight Card (`home_dashboard_view.dart:197-218`)
- **Built For**: Highlighting the creator's sound signature attunement and reminding them to reinforce under-represented sonic dimensions.
- **Current Implementation**:
  - Checks `ref.watch(creatorDnaProvider)`.
  - If `dna.dnaInsightCardDismissed` or `strengthPercent == 0`, collapses to `SizedBox.shrink()`.
  - Otherwise renders `DnaInsightCard(animatedMeter: true)`.
- **Architectural & UX Flaws**:
  - Does not offer an actionable 1-tap preset button (e.g. *"Your Amapiano signature is 82% — Tap to audition a 115 BPM Private School log-drum pattern in Studio"*).
  - Once dismissed, it disappears forever from Home with no quick re-engagement tile.

---

### 3.3. Quick Studio Creation Prompt Card (`home_dashboard_view.dart:220-330`)
- **Built For**: Enabling frictionless zero-click song generation from the Home dashboard.
- **Current Implementation**:
  - `Container` with shadow, rounded corners, and header *"What are you feeling today?"* with `Icons.auto_awesome`.
  - Input field (`TextField`) with hint *"Describe a vibe, story, or melody..."* and an orange *"Create ✨"* button.
  - Submitting copies prompt text to `studioFormProvider.notifier.updatePrompt(text)` and invokes `widget.onNavigateToStudio?.call()`.
  - Three horizontal action chips:
    - `Amapiano Late-Night Log Drum`
    - `Maskandi Acoustic Folk Story`
    - `Soweto Deep Soul Anthem`
- **Architectural & UX Flaws**:
  1. **Static, Unpersonalized Preset Chips**: The 3 chips are hardcoded strings. They do not adapt to the user's selected genres or Creator DNA affinities. An Afro-Tech or Gqom creator still sees Maskandi folk and Soweto soul.
  2. **Excessive Vertical Footprint**: The card consumes ~210dp of vertical height above the fold, pushing active creative work ("Jump Back In") below the viewport.
  3. **One-Dimensional Generation**: The prompt bar only accepts raw text. It doesn't let creators attach a voice clone, pick an instrument sketch, or select a backing beat.

---

### 3.4. 4-Card Quick Actions Grid (`home_dashboard_view.dart:332-383`)
- **Built For**: Direct navigation to Vhunambi's primary creator studios and tools.
- **Current Implementation**:
  - A rigid horizontal `Row` with 4 `Expanded` tiles:
    1. `AI Studio` (`Icons.auto_awesome_rounded` · 'Compose track') -> `onNavigateToStudio`
    2. `Beats Market` (`Icons.shopping_bag_outlined` · 'License beats') -> `onNavigateToMarket`
    3. `Asset Vault` (`Icons.library_music_outlined` · 'Your tracks') -> `onNavigateToLibrary`
    4. `Stem Lab` (`Icons.layers_outlined` · 'Split 4 tracks') -> `onNavigateToStudio`
- **Architectural & UX Flaws**:
  1. **Severe 360dp Screen Crushing**:
     - Available width: $360 - 32 = 328\text{dp}$.
     - 3 gaps of 10dp = 30dp.
     - Available per card: $298 / 4 = 74.5\text{dp}$.
     - Inside each card: 10dp padding on each side ($74.5 - 20 = 54.5\text{dp}$).
     - Subtitles like "License beats" and "Split 4 tracks" are forced into 10px micro-fonts that wrap awkwardly or clip with ellipsis.
  2. **Redundant & Phantom Navigation**:
     - `Asset Vault` merely switches to Tab 3 (`/library`), which is already permanently accessible in the bottom dock.
     - `Stem Lab` calls `onNavigateToStudio`—the exact same handler as `AI Studio`! It does not open the Stem Mastering Console (`MasteringConsoleModal`), Pocket DAW stem slicer, or vocal isolator.
  3. **Missing V4 Modern Studio Hubs**:
     - No shortcut for **Voice Cloning** (`VoiceCloningModal`).
     - No shortcut for **Melody Sketchpad** (`MelodySketchpadModal`).
     - No shortcut for **Stem Mastering** (`MasteringConsoleModal`).
     - No shortcut for **Beatstore Cockpit** (`OwnerProfileView` Tab 2).

---

### 3.5. "Jump Back In" Recent Session Card (`home_dashboard_view.dart:385-440`)
- **Built For**: Enabling creators to resume editing, mastering, or playing their most recent studio project.
- **Current Implementation**:
  - Watches `exploreTracksProvider`.
  - Renders `exploreTracks.first` (or fallback `'seed-01'`).
  - Tapping title pushes `TrackDetailView`.
  - Tapping play button triggers `playerStateProvider.notifier.playTrack(...)`.
- **Architectural & UX Flaws**:
  1. **FATAL FAKE DATA BUG (AUDIT-HOME-BUG-01)**:
     - `exploreTracksProvider` is the **public community catalog**!
     - The user's actual projects reside in `libraryTracksProvider` (`LibraryTrack`).
     - Presenting an unknown artist's track from the public feed under the heading "Jump Back In" is jarring and breaks the mental model of a personal workspace.
  2. **No Studio Resume Action**:
     - The card only offers audio playback or view detail. There is no button to "Edit in Studio", "Open Stems", or "Master Song".

---

### 3.6. Trending Kinetic Reels Shelf (`home_dashboard_view.dart:442-444`)
- **Built For**: Showcasing high-performing short-form video clips created with Vhunambi audio.
- **Current Implementation**:
  - Mounts `TrendingReelsShelf()` directly between "Jump Back In" and "Daily Rhythm Spotlight".
- **Architectural & UX Flaws**:
  - Duplicates the exact primary surface of Tab 1 (`ExploreView`).
  - Lacks a creator context (e.g. *"Sounds trending from creators in your city"* or *"Reels featuring your beats"*).

---

### 3.7. Daily Heritage Spotlight Banner (`home_dashboard_view.dart:446-523`)
- **Built For**: Introducing creators to regional African rhythms, scales, and ethnic instruments on a daily rotating basis.
- **Current Implementation**:
  - Hardcoded banner styled with `AppGradients.forGenre('Maskandi')`.
  - Static title: *"DAILY RHYTHM SPOTLIGHT"*.
  - Static subtitle: *"Maskandi Acoustic Folk Tuning"*.
  - Static copy: *"Explore Zulu finger-picking syncopation with native acoustic presets."*.
  - Button *"Try Rhythm"* calls generic `onNavigateToStudio`.
- **Architectural & UX Flaws**:
  1. **Completely Static**: Shows the exact same Maskandi text 365 days a year. It never rotates to Amapiano, Gqom, Malombo, Kwaito, Chimurenga, Gengetone, or Mbalax.
  2. **Dead Handoff**: Tapping *"Try Rhythm"* navigates to Studio without configuring the genre, prompt, or BPM ladder for Maskandi.

---

### 3.8. "Trending in Your Genres" Horizontal Feed (`home_dashboard_view.dart:525-570`)
- **Built For**: Recommending popular drops that match the genres chosen during onboarding.
- **Current Implementation**:
  - Subtitle displays `onboardingState.selectedGenres.take(2).join(' • ')`.
  - ListView renders raw `exploreTracks`.
- **Architectural & UX Flaws**:
  1. **Broken Genre Filtering (AUDIT-HOME-BUG-02)**:
     - The subtitle claims to show the user's genres, but the ListView underneath renders `exploreTracks` without any `.where((t) => userGenres.contains(t.genre))` filter!
     - A user who selected only "Gqom" and "Maskandi" sees Amapiano and Afro-Pop tracks.
  2. **Featureless Track Cards**:
     - The horizontal cards (`140dp` wide) contain only a genre gradient box with play button, title, genre, and duration.
     - Lacks like button, creator handle, key/BPM pill, or tap-to-audition overlay.

---

### 3.9. Pro Subscription Upgrade Banner (`home_dashboard_view.dart:571-638`)
- **Built For**: Driving conversions to Vhunambi Creator and Pro subscription tiers.
- **Current Implementation**:
  - Static card with crown icon, value proposition, and *"View Plans"* button opening `SubscriptionUpgradeModal`.
- **Architectural & UX Flaws**:
  - Always visible even if the user is already on a paid plan.
  - Does not highlight Coin top-ups (e.g. *"Need coins to tip artists or license beats? Top up now"*).

---

## 4. Comprehensive Inventory of Architectural & UX Flaws

| Finding ID | Severity | Category | Description | Source File & Line |
| :--- | :--- | :--- | :--- | :--- |
| **HOME-001** | **Critical** | State & Economy | Hardcoded `'10 left'` credit chip and `'2 Streak'` pill; disconnected from `creatorWalletProvider` and `ownerProfile.dayStreak`. | `home_dashboard_view.dart:148, 181` |
| **HOME-002** | **Critical** | Functional Integrity | "Jump Back In" card queries public `exploreTracksProvider` instead of the user's private `libraryTracksProvider`, showing stranger tracks as recent sessions. | `home_dashboard_view.dart:423-438` |
| **HOME-003** | **High** | UI / Responsive | 4-card Quick Actions grid squeezes into a single unscrollable `Row`, causing severe text crushing and illegible labels on 360dp viewports. | `home_dashboard_view.dart:339-381` |
| **HOME-004** | **High** | Feature Completeness | Action tiles lack shortcuts to modern V4.1 creation modules: Voice Cloning, Melody Sketchpad, Stem Mastering, and Beatstore. | `home_dashboard_view.dart:341-380` |
| **HOME-005** | **Medium** | Cultural Experience | "Daily Rhythm Spotlight" is 100% hardcoded to Maskandi; never dynamically rotates across South African and continental genres. | `home_dashboard_view.dart:455-520` |
| **HOME-006** | **High** | Data Accuracy | "Trending in Your Genres" claims to scope to the user's genres in header text, but maps unfiltered `exploreTracks` directly into the ListView. | `home_dashboard_view.dart:544, 561` |
| **HOME-007** | **High** | Real-Time Feedback | Zero in-flight generation tracker; users navigating back to Home while a track generates see no progress bar or completion indicator. | `home_dashboard_view.dart` (Absent) |
| **HOME-008** | **Medium** | Layout / HIG | Top header squishes African greeting text down to <100dp on 360dp screens due to rigid streak and credit chips; lacks search and notification actions. | `home_dashboard_view.dart:118-191` |

---

## 5. Modern V4.1 Target Architecture Blueprint

### 5.1. Top Header Bar: 2-Tier Adaptive Architecture
To eliminate greeting squishing while maintaining 44×44dp touch targets:
- **Tier 1 (Brand & Creator Status)**:
  - Left: `CreatorAvatar` (44×44dp) with tap to `OwnerProfileView` and long-press to avatar customization.
  - Middle: Authentic greeting + celestial time glyph (`$greetingText $timeGlyph`), given full flex width (`Expanded`).
  - Right: Action triad:
    - `🔥 Day Streak` compact pill: Reads `ownerProfile.dayStreak`.
    - `🪙 Coins / Credits` pill: Reads `creatorWallet.userCoinsBalance` (tapping opens unified top-up & plan sheet).
    - `🔔 Notifications` icon: 1-tap opens `NotificationCenterModal`.
- **Tier 2 (In-Flight Generation Bar - Conditional)**:
  - When an AI generation or stem mastering job is active in the background, a sleek frosted glass pill animates below the top bar:
    `[ ⚡ Generating "Bantu Log Drum" • 65% | Tap to View ]`

### 5.2. Adaptive Creation Hub: 2-Row Grid or Horizontal Carousel
Instead of 4 cramped tiles in a single rigid row:
- Transition to a **2-row × 3-column micro-hub** or a **smooth-scrolling 6-card horizontal rail**:
  1. `🎤 AI Studio`: Full composition DAW (`onNavigateToStudio`).
  2. `🎙️ Voice Clone`: 24 Sovereign African Voice Archetypes (`VoiceCloningModal.show`).
  3. `🎹 Melody & Chords`: Scale-locked Log-Drum & Piano Sketchpad (`MelodySketchpadModal.show`).
  4. `🎚️ Stem Mastering`: 6 regional African mastering presets (`MasteringConsoleModal.show`).
  5. `🛍️ Beats Market`: Instrumentals & sync licensing (`onNavigateToMarket`).
  6. `🎛️ My Beatstore`: Producer studio & royalty cashouts (`OwnerProfileView` Tab 2).

### 5.3. Real "Jump Back In" Session Engine
- Watch `libraryTracksProvider`.
- Filter out deleted tracks, sort by `createdAt` descending.
- If vault has tracks:
  - Render the latest track with:
    - Genuine title, genre gradient, creation timestamp (*"Created 2 hours ago"*).
    - Stem count badge (*"4 Stems Available"* if mastered).
    - Dual Actions: `[ ▶ Play Preview ]` and `[ 🎚️ Open in Studio / Pocket DAW ]`.
- If vault is empty:
  - Render an inspiring onboarding card: *"Start your first African masterpiece — Tap to compose in Studio"*.

### 5.4. Dynamic Day-of-Week Indigenous Rhythm Matrix
A rotation utility (`african_rhythm_matrix.dart`) mapping day-of-week and time-of-day to authentic indigenous presets:
- **Monday**: *Amapiano Private School (113 BPM · F# Minor · Deep Rhodes)*
- **Tuesday**: *Durban Gqom Quantum (127 BPM · C Minor · Broken Beat Kick)*
- **Wednesday**: *Tshivenḓa Malende Pulse (108 BPM · G Minor · Ngoma & Phala)*
- **Thursday**: *Maskandi Folk Syncopation (122 BPM · D Major · Acoustic Fingerpicking)*
- **Friday**: *Soweto Kwaito Groove (110 BPM · A Minor · Heavy Bassline)*
- **Saturday**: *Afro-Tech Lagos Energy (124 BPM · E Minor · Synth Stabs)*
- **Sunday**: *African Gospel & Choral Harmonies (78 BPM · C Major · Rich Polyphony)*
- **Action**: Tapping *"Try Rhythm"* populates `studioFormProvider` with the exact genre, BPM, scale, and inspirational prompt, navigating seamlessly to Studio.

### 5.5. Real "Trending in Your Genres" Filter
- Extract user's active genres from `onboardingState.selectedGenres`.
- If user has selected genres, filter `exploreTracks.where((t) => userGenres.contains(t.genre))`.
- If empty or none selected, gracefully fall back to top trending tracks across all regional genres.

---

## 6. Phased Implementation Roadmap & Testing Guardrails

### Track A: Economy, State & Currency Convergence (Task 31.1 – 31.3)
- Wire top header streak pill directly to `ref.watch(ownerProfileProvider).dayStreak`.
- Wire credit chip directly to `ref.watch(creatorWalletProvider).userCoinsBalance` with gold coin icon `🪙`.
- Add notification bell action button to Home header.

### Track B: Real Session Vault "Jump Back In" Engine (Task 31.4 – 31.6)
- Connect "Jump Back In" card to `libraryTracksProvider`.
- Display real creation metadata, stem badges, and "Open in Studio" routing.
- Provide graceful empty state for brand-new users.

### Track C: V4.1 Creation Hub Redesign (Task 31.7 – 31.9)
- Replace cramped 4-tile `Row` with a responsive, overflow-safe horizontal carousel or 2×3 grid.
- Add direct launch triggers for **Voice Cloning**, **Melody Sketchpad**, **Stem Mastering**, and **Beatstore**.

### Track D: Dynamic Rhythm Matrix & Genre Scoping (Task 31.10 – 31.12)
- Implement `AfricanRhythmMatrix` rotation based on day of week.
- Wire "Try Rhythm" button to inject genre, scale, and BPM into `studioFormProvider`.
- Fix genre filter in "Trending in Your Genres" ListView.

### Track E: In-Flight Generation Status Banner (Task 31.13)
- Add animated in-flight generation status banner below header when jobs are active.

### Track F: Test Suite & Accessibility Verification (Task 31.14)
- Update and expand `test/features/home/home_dashboard_view_test.dart` to cover:
  - Live streak & coin balance rendering.
  - Real vault project resolution in "Jump Back In".
  - Responsive layout validation at 360dp width.
  - Navigation handlers for all 6 studio tools.
  - Day-of-week rhythm rotation and studio preset injection.

---

## 7. Rigid Test Pins & Backward Compatibility Constraints

Any modernization of `HomeDashboardView` MUST preserve the following existing test pins from `home_dashboard_view_test.dart`:
1. `find.byKey(const Key('home_avatar_btn'))` -> exactly 1 widget.
2. `find.byKey(const Key('home_greeting_text'))` -> exactly 1 widget.
3. `find.text('What are you feeling today?')` -> exactly 1 widget.
4. `find.text('Create ✨')` -> exactly 1 widget.
5. `find.text('AI Studio')` -> exactly 1 widget.
6. `find.text('Beats Market')` -> exactly 1 widget.
7. `find.text('Jump Back In')` -> exactly 1 widget.
8. `SubscriptionUpgradeModal` opens on credit/coin chip tap.
9. Tapping play on "Jump Back In" triggers `playerStateProvider.notifier.playTrack(...)`.
10. `onNavigateToStudio`, `onNavigateToMarket`, and `onNavigateToLibrary` callbacks fire reliably.

