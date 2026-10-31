# Tasks: Phase 30
## V4.1 Creator Profile Convergence (`/profile/:id` & `/profile/me`)

> **Document ID:** `TASKS-PHASE-30-PROFILE`  
> **Status:** 🟡 SPECIFICATION  
> **Prerequisites:** `blueprint.md`, `requirements.md`, `design.md`, `docs/audits/CREATOR_PROFILE_COMPREHENSIVE_AUDIT.md`  

---

## 1. Pre-Flight Verification Checklist

Before starting implementation:
- [ ] Working tree clean or properly stashed (`git status`).
- [ ] Static analysis baseline (`cmd /c "cd apps\vhunambi_client && dart analyze lib test"` returns 0 issues).
- [ ] Backend test baseline (`cmd /c "cd apps\vhunambi_api && pnpm test"` passes 11/11 suites).
- [ ] Profile test baseline (`flutter test test/features/profile` passes 5/5 suites).

---

## 2. Sequenced Implementation Tracks

### Track A: Domain Models, Utilities & Riverpod Providers

- [ ] **Task 30.1 (Creator ID Utilities & Helper Functions)**:
  - Create `apps/vhunambi_client/lib/core/utils/creator_id_utils.dart` implementing:
    - `String normalizeCreatorId(String id)` (idempotent prefix normalizer).
    - `String extractRawCreatorId(String id)` (strips `'creator_'` prefix).
  - Add unit tests in `test/core/utils/creator_id_utils_test.dart` verifying all permutations (`'sigwa'`, `'creator_sigwa'`, `'creator_creator_sigwa'`).

- [ ] **Task 30.2 (Domain Models Expansion)**:
  - Update `apps/vhunambi_client/lib/features/profile/domain/models/profile_models.dart`:
    - Extend `TipRecordEntity` with optional `amountCoins`, `amountZar`, `giftEmoji`, `giftName` while preserving `amountCredits`.
    - Declare `enum OwnerStudioTab { songs, releases, beatstore }` with user-friendly labels.
    - Extend `ArtistProfileEntity` with optional `vocalArchetypeTitle`, `vocalArchetypeLanguage`, `vocalSampleUrl`, and `creatorDna`.

- [ ] **Task 30.3 (Riverpod Providers for Scoped Beats & DNA)**:
  - In `apps/vhunambi_client/lib/features/marketplace/presentation/providers/marketplace_providers.dart`:
    - Add `creatorBeatsFamilyProvider = Provider.family<List<BeatListingEntity>, String>((ref, creatorId) => ...)` matching against normalized or raw producer IDs.
  - In `apps/vhunambi_client/lib/features/creator_dna/presentation/providers/creator_dna_provider.dart`:
    - Add `artistDnaFamilyProvider = Provider.family<CreatorDna, String>((ref, artistId) => ...)` returning curated sound signatures for featured creators.

---

### Track B: Cultural Micro-Tipping & ID Normalization

- [ ] **Task 30.4 (Adapt `CreatorTippingSheet` for Direct Artist Tipping)**:
  - In `apps/vhunambi_client/lib/features/social/presentation/widgets/creator_tipping_sheet.dart`:
    - Update constructor and `CreatorTippingSheet.show(...)` to accept optional `clip`, plus `creatorId`, `creatorName`, and `creatorAvatarUrl`.
    - When `clip` is null, set `clipId` to `'profile_${widget.creatorId}'` and send the gift directly via `ref.read(creatorWalletProvider.notifier).sendGift(...)`.
    - Verify coin deductions and 85% ZAR royalty routing into the creator's wallet.

- [ ] **Task 30.5 (`ArtistProfileView` Tipping & Double-Prefix Bug Fix)**:
  - In `apps/vhunambi_client/lib/features/profile/presentation/views/artist_profile_view.dart`:
    - **Fix Finding PROF-002**: Replace `ref.watch(creatorClipsFamilyProvider('creator_${profile.id}'))` with `ref.watch(creatorClipsFamilyProvider(normalizeCreatorId(profile.id)))`.
    - **Fix Finding PROF-001**: Replace `_showTipDialog` call in `ProfileBannerHeader.onTipArtist` with:
      ```dart
      CreatorTippingSheet.show(
        context,
        creatorId: profile.id,
        creatorName: profile.displayName,
        creatorAvatarUrl: profile.avatarUrl,
      );
      ```
    - Remove the deprecated `_showTipDialog` helper method from `ArtistProfileView`.

---

### Track C: Public Profile Live Beats Catalog & Audition Bridge

- [ ] **Task 30.6 (`ProducerBeatListingTile` Component)**:
  - Create `apps/vhunambi_client/lib/features/profile/presentation/widgets/producer_beat_listing_tile.dart`:
    - 44×44dp Play/Pause Audition button with genre gradient and loading indicator.
    - Beat title, genre badge, BPM, and musical key.
    - Price badge (`${beat.priceInCredits} Coins`) and "License" action button (`Key('beat_tile_license_btn_${beat.id}')`).
    - High contrast text conforming to WCAG 2.1 AA.

- [ ] **Task 30.7 (`_beatsCommunityTab` Marketplace Integration)**:
  - In `apps/vhunambi_client/lib/features/profile/presentation/views/artist_profile_view.dart`:
    - Replace `_BeatLicenseCard` with live list from `ref.watch(creatorBeatsFamilyProvider(profile.id))`.
    - Map each beat to `ProducerBeatListingTile` with `auditionBeat(ref, beat)` and `BeatLicenseModal.show(context, beat: beat)`.
    - Render a sleek empty state if no beats are listed: `"No beats listed yet by this producer."`
    - Retain `TopSupportersLeaderboard` below beat listings.

---

### Track D: Owner Creator Studio Cockpit & "My Beatstore" Tab

- [ ] **Task 30.8 (3-Segment Studio Switcher in `OwnerProfileView`)**:
  - In `apps/vhunambi_client/lib/features/profile/presentation/views/owner_profile_view.dart`:
    - Add `OwnerStudioTab _activeTab = OwnerStudioTab.songs;` state.
    - Render a sleek 3-segment switcher: `[ 🎵 Songs | 💿 Releases | 🎛️ My Beatstore ]` with 44dp touch targets.
    - Conditionally render content based on active segment:
      - `songs`: "Your Songs" list with public/private switches.
      - `releases`: `ReleasesManagerCard`.
      - `beatstore`: `OwnerBeatstoreCockpit`.

- [ ] **Task 30.9 (`OwnerBeatstoreCockpit` Widget)**:
  - Create `apps/vhunambi_client/lib/features/profile/presentation/widgets/owner_beatstore_cockpit.dart`:
    - Header revenue card: Total beats listed, total sales, gross ZAR/Coins earned.
    - Action bar with `[ ➕ Upload / Publish Beat ]` button (`Key('owner_upload_beat_btn')`).
    - List of owner's beats from `creatorBeatsFamilyProvider('creator_ndugelo')` with stem status badges, licensing tier pricing, and unpublish toggle.

---

### Track E: Scoped Creator DNA & Sovereign Voice Identity Showcase

- [ ] **Task 30.10 (Parameterize `CreatorDnaProfileCard`)**:
  - In `apps/vhunambi_client/lib/features/creator_dna/presentation/widgets/creator_dna_profile_card.dart`:
    - Add `final CreatorDna? customDna;` to constructor parameters.
    - Compute `final dna = customDna ?? ref.watch(creatorDnaProvider);`.
    - When `!isOwner`, conceal the "Reset Profile DNA" button and on-device privacy toggles.
  - In `ArtistProfileView._discographyTab`:
    - Mount `CreatorDnaProfileCard(isOwner: false, customDna: ref.watch(artistDnaFamilyProvider(profile.id)))`.

- [ ] **Task 30.11 (`ArtistVoiceShowcaseCard` Component)**:
  - Create `apps/vhunambi_client/lib/features/profile/presentation/widgets/artist_voice_showcase_card.dart`:
    - Archetype badge (e.g., `"Venda Royal Matriarch"`, `"Zulu Maskandi Tenor"`).
    - Language tag and vocal characteristics description.
    - 10-second audition play button (`Key('voice_audition_btn')`).
    - Primary CTA: `[ 🎤 Remix with this Voice in Studio ]` (`Key('voice_remix_studio_btn')`).
  - Embed in `ArtistProfileView._discographyTab`.

---

### Track F: Top-Bar Navigation Convergence & Repository Enrichment

- [ ] **Task 30.12 (Top-Bar `_UserAvatar` Navigation)**:
  - In `apps/vhunambi_client/lib/features/explore/presentation/widgets/explore_top_bar.dart`:
    - Wrap `_UserAvatar` in `DesktopExploreTopBar` with `InkWell` to push `OwnerProfileView` (`/profile/me`).
    - Add mobile avatar button to `MobileExploreTopBar` trailing action row (`Key('explore_mobile_user_avatar_btn')`).

- [ ] **Task 30.13 (Enrich `ProfileRepositoryImpl` & Social Routes)**:
  - In `apps/vhunambi_client/lib/features/profile/data/repositories/profile_repository_impl.dart`:
    - Add featured artist profiles to `_seededProfiles`: `makhadzi`, `sigwa`, `khakhathi`, `asake`.
    - Connect `fetchProfile` to `GET /api/creators/:id` with in-memory fallback.

---

### Track G: Comprehensive Test Suites & Verification

- [ ] **Task 30.14 (Phase 30 Test Suite & Regression Verification)**:
  - Update `test/features/profile/artist_profile_view_test.dart`:
    - Verify tapping "Tip Artist" opens `CreatorTippingSheet` (renders 4 cultural gifts).
  - Update `test/features/profile/artist_profile_tabs_test.dart`:
    - Verify "Beats" tab renders `ProducerBeatListingTile` widgets, audition button, and license modal trigger.
    - Verify "Clips" tab correctly displays reels for `creator_sigwa` without double-prefix failure.
  - Update `test/features/profile/owner_profile_view_test.dart`:
    - Verify 3-segment switcher (`[ 🎵 Songs | 💿 Releases | 🎛️ My Beatstore ]`).
    - Verify switching to "My Beatstore" displays beat metrics and `Key('owner_upload_beat_btn')`.
  - Create `test/features/profile/phase30_creator_profile_convergence_test.dart`:
    - End-to-end integration test validating all 8 audit findings.
  - Run full verification:
    - `dart analyze lib test` (0 errors, 0 warnings, 0 hints).
    - `flutter test test/features/profile` (all tests passing 100%).
    - `pnpm test` in `apps/vhunambi_api` (11/11 suites passing).

