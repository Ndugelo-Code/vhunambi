# Phase 34: Track Details & Collections Split-Sheet ZAR Royalty Convergence — Requirements
**Document Version:** 1.0.0  
**Status:** Approved for Implementation  

---

## 1. Functional Requirements

### 1.1 Stem Separation & Audio Engine Binding
- **REQ-TRK-STEM-01 (Real Engine Integration):** The `StemSeparationLab` widget must bind directly to `stemMixerProvider` (`StemMixerNotifier`). Activating "Separate" must load the track into the multi-stem engine with 4 channels (`vocals`, `drums`, `bass`, `melody`/`instrumental`).
- **REQ-TRK-STEM-02 (Live Mute & Solo):** Tapping MUTE or SOLO in `StemSeparationLab` must invoke `StemMixerNotifier.toggleMute(StemType)` and `toggleSolo(StemType)` in real time, affecting active playback in `JustAudioMultiStemEngine`.
- **REQ-TRK-STEM-03 (Unified Engineering Flow):** `StemSeparationLab` must provide 1-tap entrypoints to open the full `StemMixerDeck` and the `MasteringSessionNotifier` (`DesktopMasteringStudioView` or `MobileQuickMasterSheet`).

### 1.2 Iconography & Design System (`STD-UIUX-001`)
- **REQ-TRK-UI-01 (Vector Cultural Reactions):** `EmojiReactionDeck` must replace all 5 raw text emojis (`🔥`, `❤️`, `🎵`, `🙌`, `🌍`) with rounded Phosphor vector icons (`PhosphorIconsRegular.fire`, `PhosphorIconsRegular.heart`, `PhosphorIconsRegular.musicNotes`, `PhosphorIconsRegular.handsClapping`, `PhosphorIconsRegular.globeHemisphereWest`).
- **REQ-TRK-UI-02 (Touch Boundary Compliance):** All reaction chips, toolbar actions, and interactive controls must have touch target boundaries $\ge 44 \times 44\text{dp}$.
- **REQ-TRK-UI-03 (Modern Toolbar Icons):** Material `Icons.*_rounded` in `TrackActionsBar` and `UtilityToolDock` must be replaced with `AppIcons` and rounded Phosphor icons.
- **REQ-TRK-UI-04 (Video Reel Export Entrypoint):** `UtilityToolDock` must feature an "Export Video Reel" tool chip that opens `VideoExportModal` (Phase 27).

### 1.3 Split Sheet & Creator Identity Model
- **REQ-COL-SPLIT-01 (Participant Creator Identity):** `SplitParticipant` must support optional `creatorId` (e.g. `creator_cern`, `creator_fifi`), `handle` (e.g. `@cern`, `@fifi`), and `walletAddress`.
- **REQ-COL-SPLIT-02 (Collaborator Lookup):** `AddParticipantDialog` must allow entering or selecting a platform creator handle, auto-filling their name and linking their creator identity.

### 1.4 Automated Royalty & Tip Distribution Engine
- **REQ-ROY-SPLIT-01 (100% Share Conservation):** A collection's split sheet is valid for automated payouts if and only if:
  $$|\sum_{i=1}^{n} s_i - 100.0| \le 0.01$$
- **REQ-ROY-SPLIT-02 (Proportional ZAR Distribution):** When a track belonging to a valid collection earns ZAR (from beat sales, licensing, or streaming), each participant's `CreatorWallet` is credited:
  $$\text{Payout}_{\text{ZAR}}(p_i) = \text{round}_2\left(G_{\text{ZAR}} \times \frac{s_i}{100.0}\right)$$
  Residual 1-cent rounding drift $\Delta_{\text{ZAR}}$ is credited to the primary project owner ($p_1$).
- **REQ-ROY-SPLIT-03 (Proportional Cultural Coin Distribution):** When a track belonging to a valid collection receives a Cultural Coin tip, each participant's `CreatorWallet` is credited:
  $$\text{Payout}_{\text{Coins}}(p_i) = \left\lfloor G_{\text{Coins}} \times \frac{s_i}{100.0} \right\rfloor$$
  Remainder coins $\Delta_{\text{coins}}$ are attributed to the primary project owner ($p_1$).
- **REQ-ROY-SPLIT-04 (Ledger Immutability):** Every split payout must generate an immutable transaction entry in each participant's wallet ledger with project attribution (`collectionTitle`, `trackTitle`, `role`, `sharePercent`).
- **REQ-ROY-SPLIT-05 (Single Track Fallback):** If a track does NOT belong to a collection with a valid split sheet, 100% of tips and earnings route directly to the track's primary creator.

---

## 2. Non-Functional Requirements
- **NFR-PERF-01 (Zero Latency DSP):** Mute and solo toggles in `StemSeparationLab` must update audio state within $< 16\text{ms}$ (single frame).
- **NFR-FIN-01 (Zero Monetary Leakage):** Sum of distributed collaborator shares must equal 100.00% of gross distributed funds.
- **NFR-TEST-01 (Zero Regressions):** Existing 80 unit/widget tests in `test/features/track` and `test/features/collections` must pass without breaking changes.

