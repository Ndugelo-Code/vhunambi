# Phase 37 Tasks: Open-Verse Challenges, Stem-Flip Chains & Co-Creation Royalties

**Document Version:** 1.0.0  
**Status:** In Progress  

Legend: `[ ]` Not started · `[x]` Completed · **Gate** = Must pass before phase exit.

---

## Track A: Real 44.1 kHz PCM Mixdown Engine (`StemMixBounceService` Upgrade)
- [ ] **T-A1** Upgrade `StemMixBounceService` to sum real 44,100 Hz 16-bit Stereo PCM samples (`MelodyWavSynthesizer` groove + `SoundSignatureResynthesizer` vocal take).
- [ ] **T-A2** Apply channel faders, pan laws, and `MasterBusDsp` soft-knee peak limiting ($\le -1.0\text{ dBFS}$).
- [ ] **T-A3** Ensure `isSimulated` is `false` when valid PCM samples are processed; return playable WAV bytes and URI.
- [ ] **Gate A:** Unit tests confirm non-silent audio output with proper RIFF header.

## Track B: Remix Lineage Graph & Co-Creation Split Economics
- [ ] **T-B1** Define `RemixCreationMode` enum and extend `StemRemixContext`, `PublishedClip`, and `SocialMusicPost` models.
- [ ] **T-B2** Implement `remixLineageTreeProvider` seeded with a 3-node remix chain on `@makhadzi`'s *"Ndo Mufuna Matibe"*.
- [ ] **T-B3** Update `CreatorTippingSheet` and `CreatorWalletNotifier` to route tips through 70% Remixer / 30% Originator co-creation split.
- [ ] **T-B4** Update backend routes (`/api/social/clips/:id/remixes`, publish, tip) to support remix lineage and 70/30 split.
- [ ] **Gate B:** Royalty split tests pass; lineage resolution returns valid tree structure.

## Track C: The 3-Mode Co-Creation Remix Cockpit (`OpenVerseRemixCockpitSheet`)
- [ ] **T-C1** Build `OpenVerseRemixCockpitSheet` adhering to `STD-UIUX-001` with parent track header and 70/30 split pill.
- [ ] **T-C2** Implement Mode A (`openVerseVocal`): Backing beat waveform, 1-bar count-in recorder, auto-scale-locked `VocalIdealizer`, audition mix, and publish.
- [ ] **T-C3** Implement Mode B (`beatStemFlip`): 6-genre kit macro switcher, Euclidean density dial, Sketchpad launcher, and groove bounce.
- [ ] **T-C4** Implement Mode C (`aiStudioRemix`): Pre-load `stemRemixProvider` with parent metadata and route to Studio tab.
- [ ] **Gate C:** Widget tests verify all 3 mode switches, recording, auditioning, and publishing.

## Track D: Feed Participation Chips, `RemixLineageTreeSheet` & Studio Banner
- [ ] **T-D1** Wire `Key('social_post_remix_btn_${post.id}')` and `Key('reel_remix_btn')` to open `OpenVerseRemixCockpitSheet`.
- [ ] **T-D2** Add interactive `Key('post_remix_tree_btn_${post.id}')` and `Key('reel_remix_tree_btn')` lineage pills to posts and reels.
- [ ] **T-D3** Build `RemixLineageTreeSheet` with visual genealogical tree and 1-tap playback/branching.
- [ ] **T-D4** Build `ActiveRemixLineageBanner` in `StudioView` with parent info and 1-tap clear button.
- [ ] **Gate D:** UI integration tests confirm lineage pill navigation and studio banner interactions.

## Track E: Verification Gates & Hardware Installation (`EPHUT20917014649`)
- [ ] **T-E1** Author `test/features/social/phase37_open_verse_and_remix_chains_test.dart` covering Tracks A–D.
- [ ] **T-E2** Run `dart analyze lib test` → 0 issues found.
- [ ] **T-E3** Run `flutter test` across all feature test suites → 100% green.
- [ ] **T-E4** Run `pnpm test` in `apps/vhunambi_api` → 100% green.
- [ ] **T-E5** Build release ARM64 APK ($\le 200\text{ MB}$) and stream-install to `EPHUT20917014649`.
- [ ] **T-E6** Update `AGENT_HANDOFF_BIBLE.md` Phase 37 status to Complete.
- [ ] **Gate E (Phase Exit):** All above gates green.

