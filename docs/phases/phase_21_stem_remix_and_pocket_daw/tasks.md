# Phase 21 · Tasks — Audio-Stem Social Remixing & Pocket 4-Channel Stem Mixer

> **Phase:** 21  
> **Codename:** `stem-remix-and-pocket-daw`  
> **Status:** 🟢 COMPLETED  
> **Target Apps:** `apps/vhunambi_client`  
> **Standard:** Dual-Agent Pair Programming Standard ([`docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md`](file:///c:/Users/Ndugelo/VHUNAMBI/monorepo/docs/VHUNAMBI_AGENT_WORKFLOW_STANDARD.md))  

---

## Pre-Flight Check Matrix

- [x] Baseline static analysis passes with 0 issues (`dart analyze apps/vhunambi_client`).
- [x] Baseline test suites pass 100% (84/84 tests passing).
- [x] Working tree is clean on `main` at `9b0956a`.

---

## Sequenced Implementation Tasks

### T1: Foundation — Pocket Stem Mixer Domain & State Provider
- [x] Implement `StemChannel`, `MasterBusDsp`, `StemMixerState` in `lib/features/player/domain/models/stem_mixer_state.dart`.
- [x] Implement `StemMixerNotifier` and `stemMixerProvider` in `lib/features/player/presentation/providers/stem_mixer_provider.dart`.
- [x] **Verification**: Unit tests for gain/pan calculation, solo/mute prioritization, and DSP preset mutations (`stem_mixer_provider_test.dart` passing).

### T2: Foundation — Stem Remix Context & Lineage Attribution
- [x] Implement `StemRemixContext` in `lib/features/social/domain/models/stem_remix_context.dart`.
- [x] Extend `PublishedClip` with `remixedFromClipId` and `remixAttribution`.
- [x] Implement `StemRemixNotifier` and `stemRemixProvider` in `lib/features/social/presentation/providers/stem_remix_provider.dart`.
- [x] **Verification**: Unit tests verifying serialization and remix context extraction (`stem_remix_context_test.dart` passing).

### T3: UI — Pocket 4-Channel Stem Mixer Deck & Master DSP Rack
- [x] Implement `StemMixerDeck` in `lib/features/player/presentation/widgets/stem_mixer_deck.dart`.
- [x] Implement responsive layout (horizontal scroll on mobile < 768px, split-console on desktop > 1024px).
- [x] Mount in `TrackDetailView` and/or Studio Cockpit.
- [x] **Verification**: Widget tests verifying fader drag, mute/solo toggles, and master bounce trigger (`stem_mixer_deck_test.dart` passing).

### T4: UI — Kinetic Reels Remix Button & Lineage Attribution Badge
- [x] Implement `RemixAttributionBadge` in `lib/features/social/presentation/widgets/remix_attribution_badge.dart`.
- [x] Wire the `Remix` button on `KineticReelsModal` action rail (`key: Key('reel_remix_btn')`).
- [x] Mount `RemixAttributionBadge` in `KineticReelsModal` and `TrendingReelCard`.
- [x] **Verification**: Widget tests verifying button tap launches remix flow and badge renders lineage (`remix_attribution_badge_test.dart` passing).

### T5: Quality Gates, Static Analysis & Documentation
- [x] Run `dart analyze apps/vhunambi_client` ensuring 0 issues (`No issues found!`).
- [x] Run all targeted `flutter test` suites ensuring 100% pass rate (149/149 tests passing).
- [x] Update `docs/AGENT_HANDOFF_BIBLE.md` and `README.md`.
- [x] Atomic git commit on `main`.
