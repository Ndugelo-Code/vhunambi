# Phase 34: Track Details & Collections Split-Sheet ZAR Royalty Convergence — Blueprint
**Document Version:** 1.0.0  
**Status:** Approved for Implementation  
**Target Subsystems:**
- `TrackDetailView` (`/track/:id`)
- `StemSeparationLab` & `StemMixerNotifier`
- `CollectionDetailView` (`/collection/:id`) & `SplitSheetModal`
- `CreatorWalletNotifier` & `RoyaltyDistributionService`

---

## 1. Vision & Architecture Scope

Phase 34 unifies the last two legacy silo surfaces of the Vhunambi platform:
1. **Track Details Cockpit (`TrackDetailView`)**: Bridges Phase 7's static/simulated stem separation with Phase 24's live multi-stem engine (`JustAudioMultiStemEngine`) and Phase 21/25's mixer and mastering sessions (`StemMixerNotifier`, `MasteringSessionNotifier`). Eliminates all raw text emojis in `EmojiReactionDeck` in strict accordance with `STD-UIUX-001`. Adds direct Video Reel Export (`VideoExportModal`).
2. **Collections Split-Sheets & Royalty Convergence (`CollectionDetailView` & `CreatorWallet`)**: Transforms static EP/Album split sheets into an active financial settlement engine. Multi-collaborator songs automatically distribute incoming tips, marketplace beat purchases, and stream royalties into each collaborator's `CreatorWallet` (ZAR & Cultural Coins) with exact conservation ($\sum = 100\%$) and zero monetary leakage.

---

## 2. High-Level System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                             TRACK DETAILS COCKPIT                           │
│                      TrackDetailView (/track/:id)                           │
└──────────────────────┬───────────────────────────────┬──────────────────────┘
                       │                               │
                       ▼                               ▼
       ┌───────────────────────────────┐ ┌───────────────────────────────────┐
       │      StemSeparationLab        │ │        EmojiReactionDeck          │
       │   - Binds to StemMixerState   │ │   - 5 Rounded Phosphor Badges     │
       │   - Real DSP Mute/Solo        │ │   - STD-UIUX-001 Compliant        │
       │   - JustAudioMultiStemEngine  │ │   - 44dp Touch Targets            │
       └───────────────┬───────────────┘ └───────────────────────────────────┘
                       │
                       ▼
       ┌───────────────────────────────┐
       │   Unified Audio Engineering   │
       │   - StemMixerDeck             │
       │   - MasteringSessionNotifier  │
       │   - VideoExportModal          │
       └───────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                          COLLECTION SPLIT-SHEET ENGINE                      │
│                    CollectionDetailView (/collection/:id)                   │
└──────────────────────┬──────────────────────────────────────────────────────┘
                       │
                       ▼
       ┌──────────────────────────────────────────────────────────────┐
       │                 RoyaltyDistributionService                   │
       │   - Resolves Collection for Track                            │
       │   - Validates Split Sheet: sum(sharePercent) == 100.0%       │
       │   - Calculates Proportional ZAR & Coin Distributions        │
       │   - Attributes Rounding Dust to Primary Producer             │
       └──────────────────────────────┬───────────────────────────────┘
                                      │
                                      ▼
       ┌──────────────────────────────────────────────────────────────┐
       │                    CreatorWalletNotifier                     │
       │   - distributeSplitPayout()                                  │
       │   - Credits balances: balanceZar & balanceCoins              │
       │   - Appends immutable SplitLedgerEntry to transactions       │
       └──────────────────────────────────────────────────────────────┘
```

---

## 3. Core Milestones

- **M1: Audio Separation Modernization:** Replace mock timer in `track_providers.dart` with binding to `StemMixerNotifier`. Enable live mute/solo toggling in `StemSeparationLab`.
- **M2: Design Token & Iconography Compliance:** Refactor `EmojiReactionDeck`, `TrackActionsBar`, and `UtilityToolDock` to use rounded Phosphor vector icons with $\ge 44\text{dp}$ touch boundaries. Integrate `VideoExportModal` entrypoint.
- **M3: Split-Sheet Participant Identity Expansion:** Upgrade `SplitParticipant` to include `creatorId`, `handle`, and `walletAddress`. Provide creator handle lookup in `AddParticipantDialog`.
- **M4: Automated Royalty & Tip Distribution Engine:** Implement `RoyaltyDistributionService` and extend `CreatorWalletNotifier` with proportional ZAR and Coin multi-party distribution.
- **M5: Track Details Tipping Integration:** Connect `_showTipModal` in `TrackDetailView` to execute real tips via `CreatorWalletNotifier`, splitting proceeds across collaborators when the track belongs to a collection.
- **M6: Verification & Zero-Regression Assurance:** Execute all unit, widget, and integration tests ensuring 100% pass rate.

