# Blueprint 06: Track Details & Creator Profiles Specification (`06_TRACK_AND_CREATOR_PROFILES_SPEC.md`)

> **Target Platform:** Flutter 3.x+ / Dart 3.x+ (Windows, macOS, Android, iOS, Web)  
> **Route Paths:**  
> - `/track/:id` (Track Details & Studio Breakdown)  
> - `/profile/:id` (Public Artist Profile)  
> - `/profile/me` (Account Owner Creator Studio Profile)  
> **State Management:** Flutter Riverpod 2.x+  
> **Source Origin:** Production Web Client (`https://vhunambi.com/track/:id`, `https://vhunambi.com/profile/:id`)

---

## 1. Track Details View Specification (`/track/:id`)

The Track Details view provides an in-depth dissection of a specific musical generation, integrating social playback metrics, lyrics teleprompter, AI stem isolation, prompt reverse-engineering, and commercial licensing rights.

```
┌────────────────────────────────────────────────────────────────────────┐
│ [ < ] (🎵) VHUNAMBI                                           [ Share ]│ <-- Top Bar
└────────────────────────────────────────────────────────────────────────┘
│                                                                        │
│                              ┌──────────┐                              │
│                              │   🎹     │   <-- 1:1 Cover Art Showcase │
│                              └──────────┘       (Ambient Amber Glow)   │
│                                                                        │
│                          Ndo Mufuna Matibe                             │
│                      Amapiano • English • 3:18                         │
│                          [ 🛡️ Personal Use ]                            │
│  This track is 100% royalty-free and owned by you. Commercial usage    │
│            depends on your subscription plan and licensing.            │
│                              👤 Fifi                                   │
│                                                                        │
│    [❤️ 1]    [▶ 5]    [🔀 Remix]    [💰 Tip]                          │
│                                                                        │
│    [⬇ Download]   [➕ Add to Playlist]   [📻 Radio]   [📝 Lyrics]      │
│    [🔀 Variation]  [💬 0]   [🏳️]   [</> Embed]                         │
│                                                                        │
│            [🔥 0]    [❤️ 1]    [🎵 0]    [🙌 0]    [🌍 0]              │ <-- Reactions
│                                                                        │
│    [ ılılıllı|ı|ı|lılıl|lılıllı|ı|ı|lılıl|lılıllı|ı|ı|lılıllı|ı|ı ]    │ <-- Scrubber
│    0:00                                                           3:18 │
│                                                                        │
│    LYRICS                                                              │
│    [Verse 1]                                                           │
│    Moonlight falls on your shoulder...                                 │
│    [Pre-Chorus]                                                        │
│    Come closer, don't hide your fire...                                │
│    [Chorus]                                                            │
│    Ndo mufuna Matibe...                                                │
│                                                                        │
│ ┌────────────────────────────────────────────────────────────────────┐ │
│ │ 🎵 Stem Separation                                [ Separate Stems]│ │
│ │ Split this song into individual stems — vocals, instrumentals,      │ │
│ │ drums, and bass. Each stem can be downloaded separately.           │ │
│ └────────────────────────────────────────────────────────────────────┘ │
│                                                                        │
│ PROMPT                                                                 │
│ "Ndo mufuna Matibe"                                                    │
│                                                                        │
│ 💬 Comments                                                            │
│ [ Add a comment...                                                ✈️ ] │
│                         No comments yet. Be the first!                 │
│                                                                        │
│ More Like This (Amapiano)                                              │
│ [ 🎹 ] Grateful in the Light • Sigwa & Inaf • 3:36             ❤️ 1002 │
└────────────────────────────────────────────────────────────────────────┘
```

---

### 1.1 Hero Section & Ownership Callout
* **Artwork Showcase:**
  * Container: `1:1` aspect ratio card (`radius: 20px`), centered horizontally.
  * Size: `280x280px` on desktop, `220x220px` on mobile.
  * Drop Shadow: `BoxShadow(color: Color(0x3DF97316), blurRadius: 40, spreadRadius: -8)`.
* **Metadata Hierarchy:**
  * Title: `"Ndo Mufuna Matibe"` (`fontSize: 28`, `fontWeight: FontWeight.bold`, `#FFFFFF`).
  * Subtitle: `"Amapiano • English • 3:18"` (`fontSize: 14`, `color: #9CA3AF`).
  * License Pill Badge: `[ 🛡️ Personal Use ]` (or `[ ⚖️ Commercial Use ]`), background `#1B1B22`, border `1px solid #2D2D38`.
  * Royalty Callout Banner:
    * Text: *"This track is 100% royalty-free and owned by you. Commercial usage depends on your subscription plan and licensing terms."* (`fontSize: 12`, `color: #6B7280`, max-width `460px`, centered).
  * Creator Byline: `Icons.person_outline_rounded` + `"Fifi"` (tappable route to `/profile/:id`).

---

### 1.2 Social Engagement, Production Utilities & Emoji Deck
* **Primary Engagement Row:**
  * `❤️ Like`: Heart icon + live tally (`❤️ 1`).
  * `▶ Plays`: Play glyph + total play count (`▶ 5`).
  * `🔀 Remix`: Pill button (`#141418`, border `#2D2D38`) navigating to Studio Cockpit pre-populated with this track's melody/stems.
  * `💰 Tip`: Amber pill button (`#141418`, border `1px solid rgba(249,115,22,0.4)`, text `#F59E0B`).
* **Secondary Utility Deck (Scrollable Tool Bar):**
  * `⬇ Download` (MP3 / WAV export).
  * `➕ Add to Playlist` (Invokes playlist picker modal).
  * `📻 Radio` (Starts endless genre station based on this track).
  * `📝 Lyrics` (Scrolls viewport directly to lyrics anchor).
  * `🔀 Variation` (Generates 2 new variations in Studio).
  * `💬 Comments` (Comments anchor jump).
  * `🏳️ Report` (Content moderation flag).
  * `</> Embed` (Generates iframe embed code snippet).
* **Emoji Reaction Pill Deck:**
  * Row of 5 cultural and sonic reaction pills:
    1. `🔥 Fire` (Tally: `0`)
    2. `❤️ Love` (Tally: `1`, active orange highlight)
    3. `🎵 Rhythm` (Tally: `0`)
    4. `🙌 Praise / Hands` (Tally: `0`)
    5. `🌍 African Unity / Globe` (Tally: `0`)
  * Touch Behavior: Instant optimistic counter increment with micro-haptic click.

---

### 1.3 Interactive Waveform Scrubber
* Profile: High-resolution amplitude waveform spanning the full width of the container.
* Active State: Completed duration painted in solid `#F97316`, remaining in `#2D2D38`.
* Scrubber Head: Circular thumb (`12x12px`, `#F97316`) draggable along the progress axis.
* Timestamps: Left: `0:00`, Right: `3:18` (`fontSize: 12`, `#9CA3AF`).

---

### 1.4 Synchronized Lyrics Teleprompter
* Section Header: `"LYRICS"` (`fontSize: 12`, `fontWeight: FontWeight.bold`, `#9CA3AF`, uppercase tracking `+1.0`).
* Structure & Verse Formatting:
  * Structural tags wrapped in brackets (`[Verse 1]`, `[Pre-Chorus]`, `[Chorus]`, `[Verse 2]`, `[Bridge]`, `[Outro]`) styled in `#F97316` (`fontSize: 13`, `fontWeight: FontWeight.bold`).
  * Lyrical Stanzas: `fontSize: 16`, `color: #FFFFFF`, `height: 1.6`, `fontWeight: FontWeight.w400`.
  * Active Line Sync: When playing, active vocal line transitions to pure white with subtle scale pulse, while inactive lines remain dimmed (`#6B7280`).

---

### 1.5 Stem Separation Module
* Container: Background `#141418`, border `1px solid #2D2D38`, border-radius `14px`, padding `16px 20px`.
* Left Content:
  * Title: `Icons.music_note_rounded` + `"Stem Separation"` (`fontSize: 15`, `fontWeight: FontWeight.w600`, `#FFFFFF`).
  * Description: *"Split this song into individual stems — vocals, instrumentals, drums, and bass. Each stem can be downloaded separately."* (`fontSize: 12`, `#9CA3AF`).
* Action Button:
  * Solid orange/amber pill `"🎛️ Separate Stems"` (`background: #3A2508`, border `1px solid #F97316`, text `#F97316`, `fontWeight: FontWeight.bold`).
  * Processing State: Progress indicator spinner with status `"Extracting 4-stem stems on GPU..."`.

---

### 1.6 Prompt Attribution, Discussion & Related Recommendations
* **Generative Prompt Card:**
  * Label: `"PROMPT"` (`fontSize: 11`, `#9CA3AF`).
  * Card: Inset container (`#1B1B22`, border `#2D2D38`, radius `10px`, padding `12px`), displaying literal seed text: `"Ndo mufuna Matibe"`.
* **Comments Section:**
  * Title: `Icons.chat_bubble_outline_rounded` + `"Comments"`.
  * Composer Input: Field hint `"Add a comment..."` with trailing send arrow (`#F97316`).
  * Empty State: Centered text *"No comments yet. Be the first!"* (`color: #6B7280`).
  * Promotion Box: *"Create your own AI songs for free"* + Button `Make music with VHUNAMBI` (`#F97316`).
* **"More Like This" Shelf:**
  * Header: `"More Like This"` + Genre Badge (`Amapiano`).
  * List: Vertical `TrackListTile` rows with live playback triggers (`Grateful in the Light`, `Luhle`, `Tshili`, `EThekwini Kuze Kuse`).

---

## 2. Public Artist Profile View (`/profile/:id`)

The public creator profile view displays an artist's catalog, verified achievements, and community support leaderboard as viewed by fans and external listeners.

```
┌────────────────────────────────────────────────────────────────────────┐
│ [ < Back ] (🎵) VHUNAMBI                                          [🔔] │
├────────────────────────────────────────────────────────────────────────┤
│ ┌────────────────────────────────────────────────────────────────────┐ │
│ │  🎵           🎹                🎸                🎵               │ │ <-- Ambient Cover Banner
│ │                                                                    │ │
│ │  ┌─────────┐                                                       │ │
│ │  │   FI    │                                                       │ │ <-- Monogram Circle (84x84)
│ └──┴─────────┴───────────────────────────────────────────────────────┘ │
│                                                                        │
│ Fifi                                                                   │
│ [ Follow ]    [ 💰 Tip ]    [ 🔗 Share ]    [ 🏳️ Report ]              │
│                                                                        │
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌────────────────┐  │
│ │   🎵 0       │ │   ❤️ 0       │ │   ▶ 9        │ │   👥 0         │  │ <-- 5-Metric Stat Grid
│ │   Songs      │ │   Likes      │ │   Plays      │ │   Followers    │  │
│ └──────────────┘ └──────────────┘ └──────────────┘ └────────────────┘  │
│ ┌──────────────┐                                                       │
│ │   🔥 1       │                                                       │
│ │   Day Streak │                                                       │
│ └──────────────┘                                                       │
│                                                                        │
│ Top Songs                                                              │
│                      [ ♪ ] No songs yet                                │
│                                                                        │
│ 🏆 Top Supporters                                                      │
│           No supporters yet — be the first to tip!                     │
│                                                                        │
│ Recent Activity                                                        │
│ [ 🎹 ] Ndo Mufuna Matibe • Created about 2 hours ago • Amapiano        │
│ [ 🎵 ] Ndo Mufuna Matibe • Created about 2 hours ago • Rnb             │
└────────────────────────────────────────────────────────────────────────┘
```

---

### 2.1 Profile Banner & Monogram Identity
* **Ambient Header Banner:**
  * Height: `180px` desktop / `140px` mobile.
  * Background: Smooth radial gradient (`#78350F` bronze-amber into `#141418` dark canvas).
  * Watermark Glyphs: Low-opacity vector musical symbols (notes, electric guitar, keyboards, saxophones) drifting in the background.
* **Monogram Avatar Circle:**
  * Size: `84x84px` (`BorderRadius.circular(9999)`).
  * Surface: Solid `#F97316` amber/orange with `4px solid #0A0A0C` perimeter cutout.
  * Monogram Initials: `FI` (Fifi) in bold black typography (`fontSize: 28`, `fontWeight: FontWeight.bold`, `#000000`).
* **Artist Name & Fan Actions:**
  * Display Name: `"Fifi"` (`fontSize: 26`, `fontWeight: FontWeight.bold`, `#FFFFFF`).
  * Action Bar:
    1. `Follow` (Solid orange pill button `#F97316`, text `#000000`, `fontWeight: FontWeight.bold`).
    2. `💰 Tip` (Elevated pill button `#141418`, border `#2D2D38`, gold coin glyph + text).
    3. `Share` (Circular icon button `#141418`, `Icons.share_rounded`).
    4. `Report` (Circular icon button `#141418`, `Icons.flag_outlined`).

---

### 2.2 5-Metric Stat Grid

| Metric | Icon Glyph | Counter Value | Semantic Role |
| :---: | :--- | :---: | :--- |
| **Songs** | `Icons.music_note_rounded` | `0` | Public active discography count |
| **Likes** | `Icons.favorite_rounded` | `0` | Cumulative likes across all creations |
| **Plays** | `Icons.play_arrow_rounded` | `9` | Total aggregate streams |
| **Followers** | `Icons.people_outline_rounded`| `0` | Fan subscriber base |
| **Day Streak**| `Icons.local_fire_department_rounded`| `🔥 1` | Continuous daily studio creation streak |

* **Tile Styling:** Surface `#141418`, border `1px solid #2D2D38`, border-radius `12px`, padding `14px`.

---

### 2.3 Public Content Sections
1. **Top Songs:**
   * Populated: 2-column or list shelf ranked by play count.
   * Empty State: Centered musical note squircle + `"No songs yet"`.
2. **🏆 Top Supporters Leaderboard:**
   * Trophy icon + `"Top Supporters"`.
   * Displays ranked fan avatars with cumulative tip badges (`Gold 🥇`, `Silver 🥈`, `Bronze 🥉`).
   * Empty Fallback: *"No supporters yet — be the first to tip!"* (`color: #6B7280`).
3. **Recent Activity Feed:**
   * Chronological stream of tracks released or updated:
     * Leading instrument badge (`40x40px`).
     * Track title + `"Created about 2 hours ago"`.
     * Trailing genre tag (`Amapiano`, `Rnb`).

---

## 3. Account Owner Profile View (`/profile/me`)

The Account Owner view transforms the public profile into a **Creator Studio Cockpit**, furnishing monetization toggles, release management, and deep analytics.

```
┌────────────────────────────────────────────────────────────────────────┐
│ [ < Back ] (🎵) VHUNAMBI                                           [🔔]│
├────────────────────────────────────────────────────────────────────────┤
│  ┌─────────┐                                                           │
│  │   CE    │  cern     [ ✏️ Edit Profile ] [ 📌 Pin Song ] [ 📊 Analytics ]│
│  └─────────┘                                                           │
│                                                                        │
│  TOP GENRES                                                            │
│  [ 🎵 House (1) ]                                                      │
│                                                                        │
│  Your Songs                                                    1 total │
│  ┌────────────────────────┐                                            │
│  │ [1]                    │                                            │
│  │          [ 🎵 ]        │  ZaYN • House • 3:20 • ▶ 4 • ❤️ 0          │
│  └────────────────────────┘                                            │
│                                                                        │
│  💿 Releases                                           [ + New Release ]│
│                       ( 💿 ) No releases yet                           │
│     Group your songs into an Album, EP, or Single — your artist        │
│                         discography starts here.                       │
│                      [ Create your first release ]                     │
│                                                                        │
│  🏆 Top Supporters                                                     │
│             No supporters yet — be the first to tip!                   │
│                                                                        │
│  💰 Tip History                                       Tips on: [ ● ]   │
│  [ Received ]   [ Sent ]                                               │
│                     You haven't received any tips yet.                 │
│                                                                        │
│  Recent Activity                                                       │
│  [ 🎵 ] ZaYN • Created 1 minute ago • House                            │
│                                                                        │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │ Share your profile                           [ 🔗 Copy Profile Link ]│
│  │ Let the world discover your music                                 │ │
│  └───────────────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────────────┘
```

---

### 3.1 Owner Management Scaffolding
* **Identity Row:**
  * Avatar: Monogram `CE` (cern).
  * Display Name: `"cern"`.
  * Management Action Strip:
    * `✏️ Edit Profile`: Opens bio, handle, social links, and avatar modal.
    * `📌 Pin Song`: Selects a highlight track pinned to the top of the profile.
    * `📊 Analytics`: Opens creator metrics dashboard (listeners, countries, revenue).
    * `Share`: Native share sheet trigger.
* **Top Genres Analytics Chips:**
  * Real-time distribution of generated music styles: `[ 🎵 House (1) ]`, `[ 🎹 Amapiano (0) ]`.

---

### 3.2 Creator Asset Controls (`Your Songs` & `Releases Manager`)
* **Your Songs Shelf:**
  * Item count indicator: `"1 total"`.
  * Track Cards: Displaying cover art, rank badge `[1]`, title `"ZaYN"`, metadata `"House • 3:20 • ▶ 4 • ❤️ 0"`, and inline visibility controls (`Public` / `Private`).
* **💿 Releases Manager (Albums, EPs & Singles):**
  * Header: `Releases` + Solid button `+ New Release`.
  * Value Proposition: Organize standalone singles into structured discography packages.
  * Empty State: Disc icon + *"Group your songs into an Album, EP, or Single — your artist discography starts here."* + CTA `Create your first release` (`#F97316`).

---

### 3.3 Financial & Monetization Suite (`Tip History`)
* **Tips Master Toggle:**
  * Label: `Tips on` with active orange Cupertino/Material switch (`activeColor: #F97316`).
  * Enables or disables direct fan monetization on public tracks.
* **Tip History Ledger:**
  * Sub-Tabs: `Received` (Active: `#3A2508`, text `#F59E0B`) vs `Sent` (Inactive: `#141418`, text `#9CA3AF`).
  * Empty State: *"You haven't received any tips yet."*
  * Populated Ledger: Fan avatar, username, tip amount in credits or ZAR/USD, transaction timestamp, and optional thank-you note.

---

### 3.4 Footer Referral Bar
* Surface: Elevated card `#141418`, border `1px solid #2D2D38`, radius `14px`, padding `18px 24px`.
* Text Column:
  * Title: `"Share your profile"` (`fontSize: 16`, `fontWeight: FontWeight.bold`, `#FFFFFF`).
  * Subtitle: `"Let the world discover your music"` (`fontSize: 13`, `color: #9CA3AF`).
* Action Button:
  * Solid pill button `🔗 Copy Profile Link` (`background: #3A2508`, border `1px solid #F97316`, text `#F97316`, `fontWeight: FontWeight.bold`).
  * Action: Copies `https://vhunambi.com/profile/cern` to system clipboard with toast confirmation.

---

## 4. Riverpod State Providers & Data Entities

```dart
// lib/features/profile/domain/models/profile_entities.dart
import 'package:flutter/foundation.dart';

@immutable
class TrackDetailEntity {
  final String id;
  final String title;
  final String genre;
  final String language;
  final Duration duration;
  final String coverUrl;
  final String audioUrl;
  final String creatorId;
  final String creatorName;
  final String licenseType;
  final int likesCount;
  final int playCount;
  final Map<String, int> reactions; // {'fire': 0, 'love': 1, 'note': 0, 'hands': 0, 'globe': 0}
  final String lyrics;
  final String prompt;
  final bool hasStems;
  final List<String> stemUrls;

  const TrackDetailEntity({
    required this.id,
    required this.title,
    required this.genre,
    required this.language,
    required this.duration,
    required this.coverUrl,
    required this.audioUrl,
    required this.creatorId,
    required this.creatorName,
    this.licenseType = 'Personal Use',
    this.likesCount = 0,
    this.playCount = 0,
    this.reactions = const {},
    this.lyrics = '',
    this.prompt = '',
    this.hasStems = false,
    this.stemUrls = const [],
  });
}

@immutable
class ArtistProfileEntity {
  final String id;
  final String username;
  final String displayName;
  final String monogram;
  final String bio;
  final int songCount;
  final int likeCount;
  final int playCount;
  final int followerCount;
  final int dayStreak;
  final bool isFollowing;
  final bool tipsEnabled;
  final List<String> topGenres;

  const ArtistProfileEntity({
    required this.id,
    required this.username,
    required this.displayName,
    required this.monogram,
    this.bio = '',
    this.songCount = 0,
    this.likeCount = 0,
    this.playCount = 0,
    this.followerCount = 0,
    this.dayStreak = 1,
    this.isFollowing = false,
    this.tipsEnabled = true,
    this.topGenres = const [],
  });
}
```

### Riverpod Providers Contract

```dart
// lib/features/profile/presentation/providers/profile_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/profile_entities.dart';

final trackDetailProvider = FutureProvider.family<TrackDetailEntity, String>((ref, trackId) async {
  // Fetch track details, lyrics, and stems from Supabase
  throw UnimplementedError();
});

final artistProfileProvider = FutureProvider.family<ArtistProfileEntity, String>((ref, artistId) async {
  // Fetch public artist profile stats and top supporters
  throw UnimplementedError();
});

final ownerProfileProvider = FutureProvider<ArtistProfileEntity>((ref) async {
  // Fetch authenticated creator profile, releases, and tip history
  throw UnimplementedError();
});
```
