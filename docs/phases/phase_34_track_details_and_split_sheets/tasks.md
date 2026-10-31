# Phase 34: Track Details & Collections Split-Sheet ZAR Royalty Convergence — Implementation Tasks
**Document Version:** 1.0.0  
**Status:** COMPLETED ✅  

---

## Task Matrix

### Task 1: Domain Models & Royalty Distribution Service
- [x] Extend `SplitParticipant` in `features/collections/domain/models/collection_entity.dart` with `creatorId`, `handle`, and `walletAddress`.
- [x] Create `RoyaltyDistributionService` in `features/collections/domain/services/royalty_distribution_service.dart` implementing the proportional ZAR and Coin split algorithms with 1-cent/coin dust conservation.
- [x] Unit test `RoyaltyDistributionService` in `test/features/collections/domain/services/royalty_distribution_service_test.dart` (balanced, unbalanced, dust attribution, edge cases).

### Task 2: CreatorWallet Integration & Split Payout Execution
- [x] Extend `CreatorWalletNotifier` in `features/social/presentation/providers/creator_wallet_provider.dart` with `distributeSplitPayout(...)` and `distributeTrackTip(...)`.
- [x] Record split transactions into `CreatorWalletState.transactions` with collection, track, role, and percentage attribution.
- [x] Update `_showTipModal` in `features/track/presentation/views/track_detail_view.dart` to deduct coins from `userCoinsBalance` and credit the creator(s) via `CreatorWalletNotifier`.

### Task 3: Stem Separation Lab Live Audio Engine Convergence
- [x] Connect `StemSeparationLab` in `features/track/presentation/widgets/stem_separation_lab.dart` to `stemMixerProvider`.
- [x] Bind Mute and Solo buttons directly to `ref.read(stemMixerProvider.notifier).toggleMute(StemType)` and `toggleSolo(StemType)`.
- [x] Modernize stem channel icons to Phosphor vector icons (`AppIcons.microphone`, `AppIcons.disc`, `AppIcons.waveSine`, `AppIcons.piano`).
- [x] Harmonize entrypoints between the on-page lab, `_FrostedStemMixerSheet`, and `MasteringSessionNotifier`.

### Task 4: UI/UX & Design Tokens Modernization (`STD-UIUX-001`)
- [x] Refactor `EmojiReactionDeck` (`features/track/presentation/widgets/emoji_reaction_deck.dart`) to render 5 rounded Phosphor vector icons with pill boundaries and $\ge 44\text{dp}$ touch targets (replacing `🔥`, `❤️`, `🎵`, `🙌`, `🌍`).
- [x] Replace Material `Icons.*_rounded` in `TrackActionsBar` and `UtilityToolDock` with `AppIcons` and rounded Phosphor icons.
- [x] Add the `Video Export Reel` tool chip to `UtilityToolDock` opening `VideoExportModal` (Phase 27).
- [x] Modernize icon buttons in `CollectionDetailView` and `SplitSheetModal`.

### Task 5: Verification & Zero-Regression Test Suite
- [x] Run all existing tests in `test/features/track/` and `test/features/collections/` to ensure zero regressions.
- [x] Add `track_stem_real_engine_test.dart` verifying live audio engine binding.
- [x] Add `track_detail_tip_split_integration_test.dart` verifying multi-collaborator wallet split distribution.
- [x] Verify clean `dart analyze .` (0 warnings, 0 errors).

