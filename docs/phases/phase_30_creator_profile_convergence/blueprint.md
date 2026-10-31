# Blueprint 30: V4.1 Creator Profile Convergence (`/profile/:id` & `/profile/me`)
## Cultural Tipping, Live Beats Marketplace, Producer Studio Cockpit, Bantu Voice Showcase & Scoped Creator DNA

> **Phase:** 30 — V4.1 Creator Profile Convergence  
> **Target Apps:** `apps/vhunambi_client`, `apps/vhunambi_api`  
> **Route Paths:** Public Artist Profile (`/profile/:id` · `ArtistProfileView`), Owner Creator Studio (`/profile/me` · `OwnerProfileView`)  
> **Status:** 🟡 SPECIFICATION (Drafted per `VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`)  
> **Predecessor Blueprints:** `07_TRACK_AND_CREATOR_PROFILES.md`, `18_SOCIAL_CREATOR_NETWORK.md`, `20_BANTU_VOICE_AND_CREATOR_GIFTING.md`, `28_MARKETPLACE_VAULT_ECONOMY.md`, `29_SOCIAL_EXPLORE_REDESIGN.md`  
> **Audit References:** `docs/audits/CREATOR_PROFILE_COMPREHENSIVE_AUDIT.md` (AUDIT-PROF-002), `docs/audits/BEATS_MARKETPLACE_AND_LIBRARY_AUDIT.md` (AUDIT-BEAT-MKT-001)  

---

## 1. Executive Summary & Cultural Vision

The **Vhunambi Creator Profile System** serves as the twin anchors of African music sovereignty:
1. **Public Artist Profile (`/profile/:id` · `ArtistProfileView`)**: The public cultural showcase where fans and fellow musicians arrive from Explore, Kinetic Reels, and social feeds to experience an artist's discography, audition beats, inspect their musical DNA, and offer cultural support.
2. **Owner Creator Studio (`/profile/me` · `OwnerProfileView`)**: The private self-sovereign creator cockpit where artists and beatmakers manage discography releases, track real-time ZAR royalty cashouts, configure beatstore licensing tiers, and monitor sound intelligence.

While earlier modernization sprints gave the profile subsystem resilient skeleton screens, local Hive caching, and responsive layouts, **the profile subsystem became isolated from the breakthrough features of the V4.1 engine**. Specifically, Phase 20 introduced the **Cultural Coin Gifting Economy**, Phase 26 introduced **Bantu Voice Cloning & 24 Sovereign Archetypes**, Phase 28 built the **Dual-Rail Marketplace & Beats Vault Bridge**, and Phase 29 launched the **Social Explore Feed & Kinetic Reels**.

Phase 30 bridges these subsystems into a unified, high-velocity creator ecosystem by executing the four strategic decisions approved for Phase 30:

1. **Cultural Coin Tipping Convergence**:
   - Replaces the isolated legacy credit dialog (`_showTipDialog`) in `ArtistProfileView` with the canonical `CreatorTippingSheet`, enabling fans to send the 4 African cultural gifts (👏 10 Coins Virtual Applause, ☕ 50 Coins Virtual Coffee, 🎛️ 100 Coins Studio Beats, 👑 500 Coins Producer Crown).
   - Deducts from user coin balances and routes 85% of real ZAR value directly into the receiving artist's `creatorWalletProvider` ledger.

2. **Live Beats Marketplace Catalog & Audition Bridge**:
   - Transforms the cosmetic, static Tab 2 ("Beats") on `ArtistProfileView` into a live commercial storefront querying `marketplaceBeatsProvider` filtered by `creatorId`.
   - Equips visiting creators with 1-tap waveform auditioning via the persistent audio dock and instantaneous commercial licensing via `BeatLicenseModal` (with automatic routing to the buyer's Library Beats Vault).

3. **Producer Studio Beatstore Cockpit (`/profile/me`)**:
   - Upgrades `OwnerProfileView` with a sleek 3-segment switcher: `[ 🎵 Songs | 💿 Releases | 🎛️ My Beatstore ]`.
   - The "My Beatstore" segment provides an integrated producer dashboard: live beat listings, stem package upload indicators, licensing tier pricing controls (Standard Lease / Trackout Stems / Unlimited Commercial), and beat sales analytics.

4. **Scoped Creator DNA & Sovereign Vocal Identity**:
   - Parameterizes `CreatorDnaProfileCard` with an optional `CreatorDna? customDna` parameter, enabling public artist profiles to showcase the artist's genuine cultural sound fingerprint and genre attunements without displaying the viewer's device state.
   - Embeds a dedicated **Bantu Voice Identity Showcase** badge on `ArtistProfileView` with an interactive audition preview and a direct `"🎤 Remix in Studio with this Voice"` CTA.

5. **Elimination of Navigation Orphaning & Double-Prefix Query Bug**:
   - Fixes the double-prefix bug in `artist_profile_view.dart#L128` where `'creator_${profile.id}'` broke query lookups for IDs already prefixed with `creator_`.
   - Wires `_UserAvatar` in `ExploreTopBar` directly to `OwnerProfileView` (`/profile/me`), providing effortless 1-tap navigation to the creator cockpit on all viewports.

---

## 2. System Topology & Data Flow

```mermaid
flowchart TD
    subgraph Navigation & Discovery
        ExploreTopBar[ExploreTopBar / DesktopExploreTopBar] -->|Tap _UserAvatar| OPV[OwnerProfileView /profile/me]
        ReelFeed[KineticReelsModal / ExploreSocialPostCard] -->|Tap @handle / avatar| APV[ArtistProfileView /profile/:id]
    end

    subgraph Public Artist Profile (/profile/:id)
        APV --> Banner[ProfileBannerHeader: Ambient Glow + Monogram]
        Banner -->|Tap Tip Artist| CTS[CreatorTippingSheet: 4 Cultural Gifts]
        CTS -->|Coin / ZAR Deduction| WalletNotifier[CreatorWalletNotifier: 85% Royalty Route]
        
        APV --> TabBar[Pinned Tri-Modal TabBar: Clips | Music | Beats]
        
        TabBar -->|Tab 0: Clips| NormalizedClips[creatorClipsFamilyProvider: Normalized ID Lookup]
        NormalizedClips --> ReelGrid[CreatorReelThumbnailCard Grid -> KineticReelsModal]
        
        TabBar -->|Tab 1: Music| Discography[Top Songs + Discography Releases + DNA Card]
        Discography --> ScopedDNA[CreatorDnaProfileCard with customDna]
        Discography --> VoiceShowcase[BantuVoiceProfileCard: Audition + Remix in Studio CTA]
        
        TabBar -->|Tab 2: Beats| CreatorBeats[creatorBeatsFamilyProvider: Filtered by creatorId]
        CreatorBeats --> BeatTiles[ProducerBeatListingTile: Waveform + BPM + Key + Price]
        BeatTiles -->|Tap Audition| PlayerDock[auditionBeat: Persistent Audio Player]
        BeatTiles -->|Tap License| LicenseModal[BeatLicenseModal: Dual-Rail Coin/ZAR Checkout]
        LicenseModal --> VaultBridge[Add to Buyer Library Vault + Credit Producer Wallet]
    end

    subgraph Owner Creator Studio (/profile/me)
        OPV --> SegmentControl[3-Segment Selector: Songs | Releases | My Beatstore]
        SegmentControl -->|Segment 0: Songs| OwnerTracks[Your Songs + Public/Private Visibility Toggle]
        SegmentControl -->|Segment 1: Releases| ReleasesMgr[ReleasesManagerCard: New Release Dialog]
        SegmentControl -->|Segment 2: My Beatstore| BeatstoreCockpit[Producer Beatstore Dashboard: Stems + Pricing + Sales]
        OPV --> WalletDeck[CreatorWalletDeck: Coin Balance + ZAR Earnings + Cashout]
        OPV --> DNAOwner[CreatorDnaProfileCard: Owner Sound Intelligence + Privacy Status]
    end
```

---

## 3. Core Architectural Subsystems

### 3.1 Cultural Micro-Tipping Migration (Finding PROF-001)
- **Problem**: `ArtistProfileView#_showTipDialog` tipped in legacy "credits" (`⚡ 10`, `⚡ 25`, `⚡ 50`), failing to credit the artist's real ZAR balance, ignoring `CreatorTippingSheet`, and skipping celebration comments.
- **Solution**:
  - `CreatorTippingSheet` is extended with a flexible constructor supporting direct creator tipping:
    ```dart
    static Future<void> show(
      BuildContext context, {
      PublishedClip? clip,
      String? creatorId,
      String? creatorName,
      String? creatorAvatarUrl,
    });
    ```
  - `ProfileBannerHeader.onTipArtist` calls `CreatorTippingSheet.show(context, creatorId: profile.id, creatorName: profile.displayName, creatorAvatarUrl: profile.avatarUrl)`.
  - The 4 cultural gifts (Virtual Applause, Virtual Coffee, Studio Beats, Producer Crown) are presented with their Coin and ZAR equivalents.
  - Transactions update `creatorWalletProvider` and append a `GiftTransaction` to the artist's ledger.

### 3.2 Double-Prefix ID Normalization (Finding PROF-002)
- **Problem**: `artist_profile_view.dart#L128` queried `creatorClipsFamilyProvider('creator_${profile.id}')`. When `profile.id` was already `'creator_sigwa'` or `'creator_makhadzi'`, it looked up `'creator_creator_sigwa'`, returning zero clips.
- **Solution**:
  - Introduce an idempotent helper function:
    ```dart
    String normalizeCreatorId(String id) {
      if (id.isEmpty) return id;
      return id.startsWith('creator_') ? id : 'creator_$id';
    }
    String extractRawCreatorId(String id) {
      if (id.startsWith('creator_')) return id.substring(8);
      return id;
    }
    ```
  - `final normalizedCreatorId = normalizeCreatorId(profile.id);`
  - `final clips = ref.watch(creatorClipsFamilyProvider(normalizedCreatorId));`

### 3.3 Public Beats Tab Marketplace Integration (Finding PROF-003)
- **Problem**: The public "Beats" tab was a static placeholder card (`_BeatLicenseCard`) with hashtags and no audio or checkout.
- **Solution**:
  - Expose `creatorBeatsFamilyProvider(String creatorId)` in `marketplace_providers.dart`:
    ```dart
    final creatorBeatsFamilyProvider = Provider.family<List<BeatListingEntity>, String>((ref, creatorId) {
      final beats = ref.watch(marketplaceBeatsProvider);
      final normalized = normalizeCreatorId(creatorId);
      final raw = extractRawCreatorId(creatorId);
      return beats.where((b) =>
        b.producerId == normalized ||
        b.producerId == raw ||
        b.producerHandle.toLowerCase() == '@$raw'.toLowerCase()
      ).toList();
    });
    ```
  - In `ArtistProfileView._beatsCommunityTab`:
    - Renders a responsive list of `ProducerBeatListingTile` widgets.
    - Each tile presents: beat title, genre badge, BPM, musical key, price in Coins & ZAR (`50 Coins · R45`), 1-tap "Audition 🎧" button (playing preview via `auditionBeat(ref, beat)`), and "License 🛒" button (launching `BeatLicenseModal`).
    - If the artist has zero published beats, displays a sleek empty state: `"No beats listed yet by this producer."` with a shortcut to browse the global `/market`.
    - Retains `TopSupportersLeaderboard` below the beat listings.

### 3.4 Owner Studio Cockpit: "My Beatstore" Tab (Finding PROF-004)
- **Problem**: `OwnerProfileView` had no beat management controls, forcing producers to navigate away to configure licensing.
- **Solution**:
  - Introduce a 3-segment switcher in `OwnerProfileView`:
    ```dart
    enum OwnerStudioTab { songs, releases, beatstore }
    ```
  - When `OwnerStudioTab.beatstore` is active, render `OwnerBeatstoreCockpit`:
    - **Header Summary**: Total Beats Listed, Total Sales, Gross Beat Revenue (in ZAR & Coins).
    - **Action Bar**: `[ ➕ Upload / Publish Beat ]` button (opening beat publisher modal).
    - **Producer Beat Cards**: List of owner's beats with status badges (`Active on Marketplace`, `Draft`, `Stems Attached`), licensing tier badges (`Lease: 50 Coins`, `Stems: 150 Coins`, `Exclusive: 500 Coins`), total sales counter, and quick action toggle (`Unpublish` / `Edit Tiers`).

### 3.5 Scoped Creator DNA Presentation (Finding PROF-005)
- **Problem**: `CreatorDnaProfileCard` unconditionally watched the viewer's device state (`creatorDnaProvider`).
- **Solution**:
  - Update `CreatorDnaProfileCard`:
    ```dart
    class CreatorDnaProfileCard extends ConsumerWidget {
      final bool isOwner;
      final CreatorDna? customDna;
      const CreatorDnaProfileCard({super.key, this.isOwner = true, this.customDna});
      ...
      final dna = customDna ?? ref.watch(creatorDnaProvider);
    ```
  - Expose `artistDnaFamilyProvider(String artistId)` returning the artist's sound identity (genre affinities, top BPM, signature scales).
  - In `ArtistProfileView`, mount `CreatorDnaProfileCard(isOwner: false, customDna: artistDna)` inside the Music tab, showcasing the artist's genuine sound fingerprint while suppressing owner-only reset buttons.

### 3.6 Sovereign Bantu Voice Archetype Showcase (Finding PROF-006)
- **Problem**: Visiting an artist profile offered no insight into their registered Bantu vocal models or zero-shot clones from Phase 26.
- **Solution**:
  - Create `ArtistVoiceShowcaseCard`:
    - Renders the artist's sovereign archetype (e.g., `"Venda Royal Matriarch"`, `"Zulu Maskandi Tenor"`, `"Xhosa Praisesmith"`).
    - Displays linguistic origin, vocal timbre characteristics, and a 10-second audition audio sample button.
    - Provides a primary CTA: `[ 🎤 Remix with this Voice in Studio ]` which routes to the Create Studio with the voice model pre-selected.

### 3.7 Top-Bar Navigation Convergence (Finding PROF-007)
- **Problem**: `_UserAvatar` in `ExploreTopBar` was non-interactive; mobile top bar lacked a direct route to `/profile/me`.
- **Solution**:
  - Wrap `_UserAvatar` in `DesktopExploreTopBar` with an `InkWell` navigating to `OwnerProfileView`:
    ```dart
    InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const OwnerProfileView()),
      ),
      borderRadius: BorderRadius.circular(18),
      child: const _UserAvatar(),
    )
    ```
  - On `MobileExploreTopBar`, add a profile avatar action button adjacent to the notifications bell, ensuring mobile users can access their studio in 1 step.

### 3.8 Creator Seed Registry & Repository Integration (Finding PROF-008)
- **Problem**: `ProfileRepositoryImpl` only had 5 hardcoded profiles and lacked recent featured artists (`makhadzi`, `khakhathi`, `asake`).
- **Solution**:
  - Expand `seededArtistProfiles` in `profile_repository_impl.dart` to include all featured artists with rich metadata, top songs, discography releases, and linked marketplace beats.
  - Wire network fallback methods to `GET /api/creators/:id` and `POST /api/creators/:id/follow` in `apps/vhunambi_api/src/routes/social_routes.ts`.

---

## 4. Architectural Invariants (Non-Negotiable)

1. **Zero Breaking Changes to `ArtistProfileEntity` Provider Return Type**:
   - `artistProfileFamilyProvider` and `ownerProfileProvider` **MUST continue to emit `ArtistProfileEntity`**.
   - Do NOT wrap state in breaking wrappers or rename `ArtistProfileNotifier`. Existing tests depend on reading `ArtistProfileEntity` directly.
2. **Design Token Discipline (No Hardcoded Colors)**:
   - All surfaces, borders, and text MUST utilize tokens from `AppColors`, `AppTypography`, `AppRadius`, and `AppSpacing`.
   - **CRITICAL**: Never use `AppColors.brandContrast` (#000000) over dark translucent glass surfaces. Use `AppColors.textPrimary` (white) for active tabs and text over dark glass.
3. **Apple HIG & WCAG 2.1 AA Touch Targets**:
   - Every interactive control (Tip button, Audition play button, License button, Tab switcher pills, Follow button) MUST satisfy $\ge 44 \times 44\text{dp}$ touch bounding boxes.
4. **Headless Test Safety**:
   - All async timers and controllers MUST be safely disposed in `dispose()`.
   - Safe fallbacks MUST prevent crashes when network or Hive boxes are uninitialized.

