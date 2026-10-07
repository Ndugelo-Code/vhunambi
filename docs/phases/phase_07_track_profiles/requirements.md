# Phase 7 Requirements: Track Details & Creator Profiles (`/track/:id`, `/profile/:id`, `/profile/me`)

> **Target Package:** `apps/vhunambi_client`  
> **Route Paths:** `/track/:id`, `/profile/:id`, `/profile/me`  
> **Standard:** EARS (Easy Approach to Requirements Syntax) & RFC 2119 (`MUST`, `SHALL`, `SHOULD`)  
> **Parent Blueprint:** [`docs/foundation_blueprints/06_TRACK_AND_CREATOR_PROFILES_SPEC.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/foundation_blueprints/06_TRACK_AND_CREATOR_PROFILES_SPEC.md)

---

## 1. Track Details Cockpit Requirements (`/track/:id`)

### REQ-TRK-01: Track Details Scaffolding & Top Bar
* The system **MUST** provide a scrollable Track Details Cockpit view for route `/track/:id`.
* The view **MUST** feature a top bar containing a `< Back` button returning to the prior route or root shell, centered `VHUNAMBI` brand wordmark, and a `Share` action button invoking the native share sheet or clipboard copier.
* On desktop viewports (> 1024px), the cockpit content **MUST** be horizontally centered with a maximum width of `860px`.

### REQ-TRK-02: 1:1 Cover Art Showcase & Ambient Glow
* The view **MUST** render a prominent `1:1` aspect ratio artwork card centered at the top of the content stream.
* The artwork card **MUST** measure `280x280px` on desktop (> 1024px) and `220x220px` on mobile (< 768px) with `AppRadius.cardBorder` (16px).
* The artwork card **MUST** cast an ambient amber glow shadow using `BoxShadow(color: Color(0x3DF97316), blurRadius: 40, spreadRadius: -8)`.
* The card surface **MUST** render the regional genre gradient via `AppGradients.forGenre(genre)` and display an iconic instrument glyph.

### REQ-TRK-03: Metadata & Ownership Legal Callout
* The view **MUST** display the track title (`28px` bold on desktop, `24px` on mobile) followed by metadata: `${genre} • ${language} • ${duration}`.
* The view **MUST** display a license pill badge: `[ 🛡️ Personal Use ]` or `[ ⚖️ Commercial Use ]` depending on the track's license state.
* The view **MUST** display an ownership notice banner: *"This track is 100% royalty-free and owned by you. Commercial usage depends on your subscription plan and licensing terms."* styled in `AppColors.textTertiary` (`12px`, max-width `460px`).
* The creator byline **MUST** display `Icons.person_outline_rounded` and the creator's name/handle, functioning as an interactive link routing to `/profile/:id`.

### REQ-TRK-04: Primary Social Engagement Row
* The view **MUST** render a horizontal primary engagement row:
  1. `❤️ Like`: Displays a heart icon and live tally. Tapping toggles like state and optimistically updates the count.
  2. `▶ Plays`: Displays total play count.
  3. `🔀 Remix`: Routes the user to the Studio Cockpit (`/create`) with this track's prompt, genre, and duration pre-populated.
  4. `💰 Tip`: Amber-outlined button (`AppColors.coinGold`) opening the artist tipping modal.

### REQ-TRK-05: Secondary Utility Toolbar
* The view **MUST** render a horizontally scrollable utility dock containing:
  - `⬇ Download`: Opens download options for MP3 (320kbps) and lossless WAV.
  - `➕ Add to Playlist`: Opens playlist selection modal.
  - `📻 Radio`: Enqueues an endless radio station seeded with this track's genre and tempo into the persistent audio player.
  - `📝 Lyrics`: Smoothly scrolls the viewport to the lyrics teleprompter.
  - `🔀 Variation`: Triggers 2-take variation generation in Studio.
  - `💬 Comments`: Smoothly scrolls the viewport to the discussion section.
  - `</> Embed`: Copies an HTML iframe embed snippet to the clipboard.

### REQ-TRK-06: 5-Glyph Cultural Emoji Reaction Dock
* The view **MUST** display a row of 5 emoji reaction pills:
  1. `🔥 Fire`
  2. `❤️ Love`
  3. `🎵 Rhythm`
  4. `🙌 Praise / Hands`
  5. `🌍 African Unity / Globe`
* Each pill **MUST** display the emoji glyph and its current count.
* Tapping a reaction **MUST** optimistically increment its count and apply an active `AppColors.brandPrimary` border highlight; tapping again **MUST** decrement the count and remove the highlight.

### REQ-TRK-07: Amplitude Waveform Scrubber
* The view **MUST** render a high-resolution amplitude waveform scrubber.
* Completed duration **MUST** be filled in `AppColors.brandPrimary`, with remaining duration in `AppColors.borderSubtle`.
* The scrubber **MUST** display elapsed time on the left (`0:00`) and total duration on the right (`3:18`).
* Dragging or tapping the scrubber **MUST** seek playback within `playerStateProvider`.

### REQ-TRK-08: Synchronized Lyrics Teleprompter
* The view **MUST** render a lyrics teleprompter section introduced by header `"LYRICS"`.
* Structural tags (`[Verse 1]`, `[Pre-Chorus]`, `[Chorus]`, `[Bridge]`, `[Outro]`) **MUST** be highlighted in `AppColors.brandPrimary` (`13px`, bold).
* Lyric stanzas **MUST** be rendered in `16px` white text with a line height of `1.6`.
* When audio is actively playing, the currently singing line **SHOULD** pulse or highlight while inactive lines remain dimmed (`AppColors.textSecondary`).

### REQ-TRK-09: 4-Stem Separation Lab
* The view **MUST** feature a Stem Separation container with title `"Stem Separation"` and description *"Split this song into individual stems — vocals, instrumentals, drums, and bass. Each stem can be downloaded separately."*
* The container **MUST** feature a `"🎛️ Separate Stems"` button.
* When triggered, the system **MUST** transition through a 4-step synthesis pipeline:
  1. Isolating Vocals
  2. Isolating Drums
  3. Isolating Bass
  4. Isolating Instrumental
* Once complete, the view **MUST** render 4 individual stem cards with Solo/Mute audition controls and individual stem download buttons.

### REQ-TRK-10: Generative Prompt Attribution
* The view **MUST** render a `"PROMPT"` section displaying the original prompt text used to generate the track.
* The prompt container **MUST** include a `"Remix Prompt ✨"` action button that pre-fills `studioFormProvider` and navigates to the Studio Cockpit.

### REQ-TRK-11: Discussion Thread & Recommendations
* The view **MUST** display a `"Comments"` section with count indicator.
* The view **MUST** include a comment input composer field with hint `"Add a comment..."` and a trailing send button.
* The view **MUST** render existing comments or a clean empty state: *"No comments yet. Be the first!"*
* Below comments, the view **MUST** render a `"More Like This"` recommendation shelf featuring tracks sharing the same genre.

---

## 2. Public Artist Profile Requirements (`/profile/:id`)

### REQ-TRK-12: Artist Profile Header & Monogram Identity
* The system **MUST** render a public artist profile view for route `/profile/:id`.
* The header **MUST** feature an ambient cover banner (`180px` desktop / `140px` mobile) with musical watermark glyphs.
* The profile **MUST** display an `84x84px` circular monogram avatar with a `4px` canvas border cutout and the artist's initials in bold typography.
* The profile **MUST** display the artist's display name, verified artist badge (`✓ Verified Artist`), and a short biography.
* The profile **MUST** feature an action strip with `Follow / Following` toggle, `💰 Tip Artist` button, `Share`, and `Report`.

### REQ-TRK-13: 5-Metric Artist Statistical Grid
* The profile **MUST** render a 5-metric statistical grid displaying:
  1. `Songs`: Active public discography count.
  2. `Likes`: Aggregate likes received.
  3. `Plays`: Total streams.
  4. `Followers`: Total follower count.
  5. `Day Streak`: Continuous daily creation streak (`🔥 N`).
* Each metric tile **MUST** be styled using `AppColors.surfaceElevated` and `AppRadius.cardBorder`.

### REQ-TRK-14: Public Discography & Supporter Leaderboard
* The profile **MUST** render a `"Top Songs"` shelf displaying the artist's top tracks ranked by play count.
* The profile **MUST** render a `"🏆 Top Supporters"` leaderboard displaying top tipping fans with badges:
  - `🥇 Gold Supporter`
  - `🥈 Silver Supporter`
  - `🥉 Bronze Supporter`
* The profile **MUST** render a `"Recent Activity"` chronological feed showing recent releases and updates.

---

## 3. Account Owner Creator Studio Profile Requirements (`/profile/me`)

### REQ-TRK-15: Creator Studio Scaffolding & Releases Manager
* The system **MUST** render an authenticated creator management console for route `/profile/me`.
* The management strip **MUST** include `✏️ Edit Profile`, `📌 Pin Song`, and `📊 Studio Analytics` buttons.
* The profile **MUST** display `"TOP GENRES"` analytics chips indicating music style distribution (e.g., `[ 🎵 House (1) ]`, `[ 🎹 Amapiano (4) ]`).
* The profile **MUST** feature a `"Your Songs"` shelf with inline `Public / Private` visibility toggle controls.
* The profile **MUST** include a `"💿 Discography Releases"` manager allowing creators to bundle tracks into Albums, EPs, or Singles.

### REQ-TRK-16: Tip History Ledger & Referral Link Bar
* The profile **MUST** include a `"💰 Tip History"` module with a master `Tips on` switch.
* The ledger **MUST** provide `Received` and `Sent` sub-tabs displaying transaction history, tipping fans, and credit amounts.
* The profile **MUST** feature a `"Share your creator profile"` footer card with a `"🔗 Copy Profile Link"` button copying `https://vhunambi.com/profile/:username` to the clipboard with confirmation feedback.
