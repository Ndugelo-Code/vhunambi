# Requirements Specification: Phase 30
## V4.1 Creator Profile Convergence (`/profile/:id` & `/profile/me`)

> **Document ID:** `REQ-PHASE-30-PROFILE`  
> **Status:** 🟡 SPECIFICATION  
> **Standard:** RFC 2119 & EARS (Easy Approach to Requirements Syntax)  
> **Target Apps:** `apps/vhunambi_client`, `apps/vhunambi_api`  

---

## 1. Executive Summary & RFC 2119 Imperatives

This document specifies the formal, testable acceptance criteria for **Phase 30: V4.1 Creator Profile Convergence**. All requirements are tagged with unique identifiers and categorized under functional groups. Statements strictly adhere to RFC 2119 imperatives (`MUST`, `SHALL`, `SHOULD`, `MAY`).

---

## 2. EARS Requirements Matrix

### Category 1: Cultural Micro-Tipping Migration (`REQ-PROF-TIP`)

* **`REQ-PROF-TIP-01` (Tipping Trigger & Cultural Modal Invocation)**:
  WHEN the user taps the `"Tip Artist"` button (`Key('profile_tip_artist_btn')`) on `ArtistProfileView`, the system MUST invoke `CreatorTippingSheet` via a modal bottom sheet, presenting the 4 canonical African cultural gifts (Virtual Applause, Virtual Coffee, Studio Beats, Producer Crown). The system MUST NOT display the legacy 4-credit numerical dialog.
* **`REQ-PROF-TIP-02` (Dual-Rail Coin & ZAR Display)**:
  The `CreatorTippingSheet` SHALL display both the Coin price and the ZAR equivalent for each gift (10 Coins / R9, 50 Coins / R45, 100 Coins / R90, 500 Coins / R450).
* **`REQ-PROF-TIP-03` (Direct Creator Tipping Support)**:
  WHEN `CreatorTippingSheet` is invoked from `ArtistProfileView` without an active `PublishedClip`, the system MUST support direct creator tipping using `recipientCreatorId` (`profile.id`) and synthetic clip reference `profile_${profile.id}`.
* **`REQ-PROF-TIP-04` (Ledger & Wallet Routing)**:
  WHEN a cultural gift is confirmed, the system MUST deduct the coin amount from the sender's `userCoinsBalance` and credit 85% of the ZAR equivalent to the recipient's `creatorEarnedZar` via `creatorWalletProvider`.
* **`REQ-PROF-TIP-05` (Transaction Record Generation)**:
  WHEN a tip is successfully dispatched, the system SHALL prepend a `GiftTransaction` to the transactions list with the recipient's creator ID, gift emoji, and optional supportive message.

---

### Category 2: Public Profile Kinetic Reels & ID Normalization (`REQ-PROF-REELS`)

* **`REQ-PROF-REELS-01` (Idempotent Creator ID Normalization)**:
  WHEN querying `creatorClipsFamilyProvider` in `ArtistProfileView`, the system MUST normalize the lookup ID such that query strings with or without the `creator_` prefix resolve to the exact canonical creator clip key (e.g., both `'sigwa'` and `'creator_sigwa'` MUST resolve to `'creator_sigwa'`). The system MUST NOT produce double-prefixed keys like `'creator_creator_sigwa'`.
* **`REQ-PROF-REELS-02` (Populated Kinetic Reels Grid)**:
  WHEN the visiting artist has published reels, the "Clips" tab MUST render a responsive 3-column (mobile) or 4-column (desktop) grid of `CreatorReelThumbnailCard` widgets showing play counts and sound titles.
* **`REQ-PROF-REELS-03` (Reels Modal Launch)**:
  WHEN a user taps any thumbnail in the reels grid, the system MUST launch `KineticReelsModal` centered on the tapped clip with 60 FPS lyric video playback and full-screen interaction controls.
* **`REQ-PROF-REELS-04` (Graceful Empty State)**:
  WHEN an artist has zero published reels, the system SHALL render a sleek empty state (`Key('artist_profile_empty_clips')`) with an encouraging message.

---

### Category 3: Public Profile Live Beats Catalog & Audition Bridge (`REQ-PROF-BEAT-CAT`)

* **`REQ-PROF-BEAT-CAT-01` (Real Marketplace Catalog Binding)**:
  WHEN the user selects the "Beats" tab on `ArtistProfileView`, the system MUST query `creatorBeatsFamilyProvider(profile.id)` to retrieve all active beat listings produced by that artist from `marketplaceBeatsProvider`. The system MUST NOT display the static non-interactive `_BeatLicenseCard` mockup.
* **`REQ-PROF-BEAT-CAT-02` (Producer Beat Listing Tile Presentation)**:
  Each beat listing tile SHALL display:
  1. Beat title and genre badge.
  2. Tempo (BPM) and musical key.
  3. Price in Coins and ZAR equivalent (e.g., `50 Coins (R45)`).
  4. Audio audition button (`Key('beat_tile_audition_btn_${beat.id}')`).
  5. License purchase button (`Key('beat_tile_license_btn_${beat.id}')`).
* **`REQ-PROF-BEAT-CAT-03` (Persistent Dock Auditioning)**:
  WHEN the user taps the audition button on any beat tile, the system MUST route the preview audio track to `auditionBeat(ref, beat)` and initiate playback through the bottom persistent player dock without navigating away from the profile.
* **`REQ-PROF-BEAT-CAT-04` (Beat Licensing Modal Trigger)**:
  WHEN the user taps the license button on any beat tile, the system MUST open `BeatLicenseModal` for that specific beat, enabling licensing via Coins or Credits.
* **`REQ-PROF-BEAT-CAT-05` (Automatic Vault Bridge on License Purchase)**:
  WHEN a beat is successfully licensed from the artist's profile, the system MUST add the beat to the buyer's Library Vault (`libraryTracksProvider`) under `isInstrumental = true` and credit the producer's wallet.
* **`REQ-PROF-BEAT-CAT-06` (Supporters Leaderboard Preservation)**:
  The "Beats" tab SHALL display the `TopSupportersLeaderboard` beneath the beat listings, recognizing the artist's top cultural patrons.

---

### Category 4: Owner Creator Studio "My Beatstore" Cockpit (`REQ-PROF-STUDIO`)

* **`REQ-PROF-STUDIO-01` (3-Segment Studio Switcher)**:
  The `OwnerProfileView` SHALL feature a segmented control allowing the creator to switch between three studio views:
  `[ 🎵 Songs | 💿 Releases | 🎛️ My Beatstore ]`.
* **`REQ-PROF-STUDIO-02` (Beatstore Metrics Banner)**:
  WHEN the "My Beatstore" segment is active, the system SHALL render a summary metrics banner showing:
  - Total beats listed on `/market`.
  - Total beats sold.
  - Gross earnings in ZAR and Coins.
* **`REQ-PROF-STUDIO-03` (Owner Beat Management Tiles)**:
  The system SHALL render a list of the owner's beats with real-time indicators:
  - Marketplace visibility status (`Active` / `Draft` / `Unlisted`).
  - Stems package attachment indicator (`Stems Zip Attached` / `Missing Stems`).
  - Available licensing tiers and prices.
* **`REQ-PROF-STUDIO-04` (New Beat Publisher Entrypoint)**:
  The "My Beatstore" segment SHALL feature a prominent `[ ➕ Upload / Publish Beat ]` button (`Key('owner_upload_beat_btn')`) to publish new instrumental productions to the marketplace.
* **`REQ-PROF-STUDIO-05` (Marketplace Synchronization)**:
  WHEN the owner toggles a beat's visibility or edits pricing, changes MUST synchronize immediately with `marketplaceBeatsProvider` and `beatsProvider`.
* **`REQ-PROF-STUDIO-06` (Wallet Cashout Integration)**:
  The `OwnerProfileView` SHALL render `CreatorWalletDeck` displaying current ZAR royalty balance and providing a 1-tap cashout request button.

---

### Category 5: Scoped Creator DNA Presentation (`REQ-PROF-DNA`)

* **`REQ-PROF-DNA-01` (Custom DNA Parameterization)**:
  The `CreatorDnaProfileCard` widget MUST accept an optional `CreatorDna? customDna` parameter. WHEN `customDna` is provided, the card MUST render the metrics and genre affinities from `customDna` rather than falling back to `ref.watch(creatorDnaProvider)`.
* **`REQ-PROF-DNA-02` (Public Profile Embedding)**:
  In `ArtistProfileView` (inside the "Music" tab), the system SHALL render `CreatorDnaProfileCard(isOwner: false, customDna: artistDna)`.
* **`REQ-PROF-DNA-03` (Viewer Protection & Reset Concealment)**:
  WHEN `isOwner` is false, the system MUST NOT render the `"Reset Profile DNA"` button or on-device privacy toggles, preserving owner-only sovereignty.
* **`REQ-PROF-DNA-04` (Cultural Sound Signature Metrics)**:
  The card SHALL display the artist's dominant African genre affinities, average tempo attunement (BPM), and harmonic key preferences.

---

### Category 6: Sovereign Bantu Vocal Archetype Showcase (`REQ-PROF-VOICE`)

* **`REQ-PROF-VOICE-01` (Vocal Identity Archetype Badge)**:
  WHEN an artist profile has an associated sovereign vocal model (e.g., from Phase 26 Voice Cloning), the system SHALL render an `ArtistVoiceShowcaseCard` in the "Music" tab displaying the archetype title (e.g., `"Venda Royal Matriarch"`, `"Zulu Maskandi Tenor"`).
* **`REQ-PROF-VOICE-02` (Vocal Timbre & Heritage Tags)**:
  The card SHALL display cultural linguistic origin (e.g., `Tshivenḓa`, `isiZulu`, `isiXhosa`) and vocal characteristics (e.g., `Resonant Alto`, `Vibrato`, `Traditional Praise`).
* **`REQ-PROF-VOICE-03` (Audition Voice Snippet)**:
  The card SHALL include an audio preview button (`Key('voice_audition_btn')`) that plays a 10-second vocal sample through the audio engine.
* **`REQ-PROF-VOICE-04` (Remix in Studio CTA)**:
  The card SHALL feature a primary action button: `[ 🎤 Remix with this Voice in Studio ]` (`Key('voice_remix_studio_btn')`). Tapping it SHALL navigate to the Create Studio with the artist's voice model pre-selected as the active vocal preset.

---

### Category 7: Top-Bar Navigation & Direct View Routing (`REQ-PROF-NAV`)

* **`REQ-PROF-NAV-01` (Desktop Top-Bar Profile Shortcut)**:
  WHEN the user clicks `_UserAvatar` (`Key('explore_desktop_user_avatar')`) on `DesktopExploreTopBar`, the system MUST navigate directly to `OwnerProfileView` (`/profile/me`) via `Navigator.push`.
* **`REQ-PROF-NAV-02` (Mobile Top-Bar Profile Shortcut)**:
  The system SHALL provide a profile avatar action button (`Key('explore_mobile_user_avatar_btn')`) on `MobileExploreTopBar` that navigates directly to `OwnerProfileView` on mobile viewports.
* **`REQ-PROF-NAV-03` (Apple HIG Touch Compliance)**:
  All avatar navigation triggers MUST provide a minimum touch bounding box of $44 \times 44\text{dp}$.

---

### Category 8: Remote Data Sync & Enriched Creator Registry (`REQ-PROF-DATA`)

* **`REQ-PROF-DATA-01` (Enriched Seeded Creators)**:
  `ProfileRepositoryImpl.seededArtistProfiles` SHALL include comprehensive profiles for featured African artists: `sigwa`, `fifi`, `makhadzi`, `khakhathi`, `asake`, and `ndugelo` with real African genres, top songs, releases, and linked beat listings.
* **`REQ-PROF-DATA-02` (HTTP Fallback Connectivity)**:
  `ProfileRepositoryImpl` SHALL implement network fetch calls to `GET /api/creators/:id` and `POST /api/creators/:id/follow` against `vhunambi_api`.
* **`REQ-PROF-DATA-03` (Zero-Breaking Compatibility)**:
  All entity expansions SHALL remain backward-compatible with existing JSON structures and Riverpod provider signatures.

