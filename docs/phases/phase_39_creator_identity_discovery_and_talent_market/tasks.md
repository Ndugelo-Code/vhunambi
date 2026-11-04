# Phase 39 Tasks: Creator Identity, Discovery Hierarchy & Talent Marketplace

**Document Version:** 1.0.0  
**Status:** In Execution  

---

## Task Map

### Track A: Pre-Flight Visual & Ergonomic Verification (COMPLETED)
- [x] **T-A1:** Resolve Light Mode Top Bar contrast in `MobileExploreTopBar` (`explore_top_bar.dart`).
- [x] **T-A2:** Replace hardcoded `color: Colors.white` in `PillForm` (`pill_form.dart`).
- [x] **T-A3:** Fix floating mini player position clamping and bottom dock clearance (`mini_player_controller.dart`, `mini_player_host.dart`).
- [x] **T-A4:** Replace broken-image placeholder with Procedural African Vision Canvas (`explore_social_post_card.dart`).
- [x] **T-A5:** Eliminate action bar truncation on mobile screens (`explore_social_post_card.dart`).
- [x] **T-A6:** Verify 30/30 unit & widget tests pass and 0 analyzer issues found.

---

### Track B: Sovereign Creator Identity Archetypes & Direct Uploader
- [ ] **T-B1:** Add `CreatorIdentityArchetype` and `monthlyListenersCount` to `ArtistProfileEntity` (`profile_models.dart`).
- [ ] **T-B2:** Add `AudioProvenanceType` to `Track` and `SocialMusicPost`.
- [ ] **T-B3:** Mount Archetype Badge + Monthly Listeners Pill on `OwnerProfileView` and `ArtistProfileView`.
- [ ] **T-B4:** Add Archetype editor selector to `EditProfileSheet`.
- [ ] **T-B5:** Render Provenance Badge on `ExploreSocialPostCard`.
- [ ] **T-B6:** Build `DirectDawVocalUploadSheet` with 3 flows (DAW Master, Live Vocal/Stem, Dance Reel) and mount triggers on `OwnerProfileView` and `StudioView`.

---

### Track C: 3-Stage Scalable Discovery Hierarchy
- [ ] **T-C1:** Build `DiscoveryHierarchyRanker` (`discovery_hierarchy_ranker.dart`) with `DiscoveryStageTier` (`mainstage`, `risingBreakout`, `freshCrate`).
- [ ] **T-C2:** Mount Discovery Stage Selector (`Key('explore_stage_tier_selector')`) on `ExploreView` without disturbing existing test keys.

---

### Track D: 4-Pillar Multi-Talent & Stem Marketplace
- [ ] **T-D1:** Add `MarketplaceAssetCategory` to `marketplace_models.dart`.
- [ ] **T-D2:** Extend `BeatListingEntity` with `assetCategory` and `provenanceType`.
- [ ] **T-D3:** Seed authentic listings across all 4 categories in `marketplace_providers.dart`.
- [ ] **T-D4:** Add Category Pill Switcher to `MarketplaceView`.
- [ ] **T-D5:** Update `BeatFormDialog` / `PublishBeatModal` to support listing vocals & live instruments for 85% ZAR royalties.

---

### Track E: Verification & Hardware Deployment
- [ ] **T-E1:** Author `test/features/explore/phase39_identity_discovery_and_talent_market_test.dart`.
- [ ] **T-E2:** Run `dart analyze lib test` → 0 issues.
- [ ] **T-E3:** Run `flutter test` across all feature test suites → 100% green.
- [ ] **T-E4:** Build release APK (`flutter build apk --release --target-platform android-arm64 --no-pub`).
- [ ] **T-E5:** Install APK to physical hardware `EPHUT20917014649` via ADB.
- [ ] **T-E6:** Update `docs/AGENT_HANDOFF_BIBLE.md`.

