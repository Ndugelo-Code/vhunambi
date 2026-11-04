# Phase 39 Requirements: Creator Identity, Discovery Hierarchy & Talent Marketplace

**Document Version:** 1.0.0  
**Status:** Approved for Implementation  
**Predecessor:** Phase 38 Requirements  
**Target:** `apps/vhunambi_client` (Profile, Explore, Studio, Marketplace) & `apps/vhunambi_api`  

---

## 1. Track B: Sovereign Creator Identity & Provenance Requirements

### REQ-ID-ARCH-01: Creator Archetype Enumeration & Default
`ArtistProfileEntity` MUST support `CreatorIdentityArchetype archetype` with values:
- `dawProducer` ("DAW Producer")
- `naturalVocalist` ("Natural Vocalist")
- `liveInstrumentalist` ("Live Instrumentalist")
- `kineticPerformer` ("Kinetic Performer")
- `aiSonicArchitect` ("AI Sonic Architect")  
Default value MUST be `CreatorIdentityArchetype.aiSonicArchitect` so existing serialized profiles and tests compile and run untouched.

### REQ-ID-ARCH-02: Monthly Listeners Pill
`ArtistProfileEntity` MUST support `int monthlyListenersCount` (default `14200`). Both `OwnerProfileView` and `ArtistProfileView` MUST display the Archetype badge and Monthly Listeners pill (`Key('creator_monthly_listeners_pill')`) using `AppColors.textPrimaryOf(context)` and `AppColors.surfaceSecondaryOf(context)`.

### REQ-ID-ARCH-03: Editable Archetype in Profile Edit
`EditProfileSheet` MUST include an archetype selector allowing creators to toggle their craft sovereignty and save it to `profileStateProvider`.

### REQ-ID-PROV-01: Audio Provenance Type
`Track` and `SocialMusicPost` MUST support `AudioProvenanceType provenanceType` with values:
- `humanDawMaster` ("Human DAW Master", icon: `slidersHorizontal`)
- `liveVocalRecording` ("100% Live Vocal", icon: `microphone`)
- `liveInstrumentStem` ("Live Instrument", icon: `guitar` / `musicNote`)
- `hybridCoCreation` ("Hybrid Co-Creation", icon: `gitFork`)
- `aiGenerated` ("Vhunambi AI", icon: `sparkle`)  
Default value MUST be `AudioProvenanceType.hybridCoCreation`.

### REQ-ID-PROV-02: Visual Provenance Badge
`ExploreSocialPostCard` and `TrackCard` MUST render the Provenance Badge in the creator header or sonic capsule with dynamic context colors.

### REQ-UPL-01: Direct DAW & Vocal Uploader Sheet
`DirectDawVocalUploadSheet` MUST be mountable via `Key('open_daw_vocal_uploader_btn')` on `OwnerProfileView` and `Key('studio_daw_uploader_btn')` on `StudioView`.

### REQ-UPL-02: Three Upload Workflows
The uploader MUST provide 3 selectable workflows:
1. **DAW Master Import:** Selects `.wav`/`.mp3` audio, title, genre, BPM, key, tags as `humanDawMaster`, and publishes to Vault + Explore.
2. **Natural Vocal / Live Instrument Stem:** Selects audio/mic input, tags as `liveVocalRecording` or `liveInstrumentStem`, and allows 1-click listing on `/market` for 85% ZAR royalties.
3. **Performance Reel:** Launches camera video capture for `KineticReelsModal`.

---

## 2. Track C: 3-Stage Scalable Discovery Hierarchy Requirements

### REQ-DISC-RANK-01: Discovery Hierarchy Ranker
`DiscoveryHierarchyRanker` MUST evaluate social feed posts and score them according to:
- 30% Completion / Play Velocity
- 25% Co-Creation Remix / Repost Pull
- 20% Creator Influence / Monthly Listeners
- 15% Follower Graph Affinity
- 10% Human Craft / Provenance Bonus (`humanDawMaster` and `liveVocalRecording` receive +15 points).

### REQ-DISC-TIER-01: Three Discovery Stage Tiers
`DiscoveryStageTier` MUST define:
- `mainstage`: High-scoring tracks (score $\ge 70$)
- `risingBreakout`: Rapidly climbing grooves (score $40 - 69$)
- `freshCrate`: Newly dropped takes and open verse invitations (score $< 40$).

### REQ-DISC-UI-01: Discovery Stage Selector on Explore
`ExploreView` MUST mount a Discovery Stage Selector (`Key('explore_stage_tier_selector')`) allowing listeners to filter by `Mainstage`, `Rising Breakout`, and `Fresh Crate` while preserving all existing tabs (`For You`, `Following`, `All Songs`).

---

## 3. Track D: 4-Pillar Multi-Talent Marketplace Requirements

### REQ-MKT-CAT-01: Marketplace Category Enumeration
`MarketplaceAssetCategory` MUST support:
- `all` ("All Assets")
- `beats` ("Beats & Instrumentals")
- `vocals` ("Vocal Hooks & Acapellas")
- `liveInstruments` ("Live Guitars, Sax & Loops")
- `voiceDnaAndPacks` ("Voice DNA & Sound Packs").

### REQ-MKT-ENT-01: Asset Listing Extension
`BeatListingEntity` MUST include:
- `MarketplaceAssetCategory assetCategory` (default `MarketplaceAssetCategory.beats`)
- `AudioProvenanceType provenanceType` (default `AudioProvenanceType.humanDawMaster`).

### REQ-MKT-UI-01: Horizontal Category Pill Switcher
`MarketplaceView` MUST render horizontal category tabs (`Key('market_category_tab_${cat.name}')`) using `AppColors.surfaceElevatedOf(context)` and `AppColors.textPrimaryOf(context)`.

### REQ-MKT-ROYALTY-01: 85% ZAR Royalty & Vault Bridge
Purchasing any asset (vocal, live instrument, or beat) MUST route 85% net royalties to the creator via `CreatorWalletNotifier` and instantly save the licensed asset to the buyer's Library Vault (`libraryTracksProvider`) with valid provenance.

---

## 4. Track E: Verification & Hardware Requirements

### REQ-VERIFY-01: Strict Contrast & Theming
All newly introduced UI components MUST use `AppColors.*Of(context)` without hardcoded hex or invariant colors, ensuring flawless legibility in Light ("Warm African Daylight") and Dark ("Obsidian Studio") themes.

### REQ-VERIFY-02: Zero Regression Suite
All existing 1,150+ tests MUST remain green. New tests in `phase39_identity_discovery_and_talent_market_test.dart` MUST verify Tracks B, C, and D.

