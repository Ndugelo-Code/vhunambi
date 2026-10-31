# 🎛️ Comprehensive Architectural Audit: Track Details & Collections Split-Sheet ZAR Royalty Convergence
**Document Identifier:** `AUDIT-TRK-COL-034`  
**Target Systems:** Track Details Cockpit (`/track/:id`), Stem Separation Lab, Collections Split-Sheet Engine (`/collection/:id`), Creator Wallet & Royalty Splitter  
**Flutter SDK:** 3.44.4 (Dart 3.12.2)  
**Standard Adherence:** `STD-UIUX-001` (Phosphor Vector Iconography & $\ge 44\text{dp}$ Touch Boundaries)  
**Status:** Complete Audit — Ready for Architectural Alignment  

---

## 1. Executive Summary & Problem Diagnosis

Vhunambi has successfully converged Studio (Phases 3, 21, 24–27), Marketplace (Phases 6, 14, 28), Reels & Social (Phases 18–20), Explore (Phase 29), Creator Profiles & Wallet (Phases 30, 31), and the Adaptive Mini-Player with Bin Dismiss (Phases 33–35).

However, an exhaustive audit reveals that **Track Details (`TrackDetailView` — Phase 7)** and **Collections Split-Sheets (`CollectionDetailView` — Phase 13)** remain isolated as legacy silos disconnected from the modern production audio engine and financial payout infrastructure:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                 THE CURRENT DISCONNECT                                 │
├──────────────────────────────────────────┬─────────────────────────────────────────────┤
│ 1. TrackDetailView & Stem Separation:    │ 2. Collection Split-Sheets & CreatorWallet: │
│    - StemSeparationLab runs mock timer   │    - SplitParticipant has name/role/share   │
│    - Empty audio URLs in StemTrackEntity │    - Missing creatorId / wallet linkage     │
│    - Disconnected from JustAudioStemEngine│    - Tips & Beat sales do NOT split funds    │
│    - Disconnected from StemMixerNotifier │    - CreatorWallet balances remain unlinked │
│    - 5 raw text emojis in reactions      │    - Zero automatic ZAR/Coin distribution   │
│    - Sharp Material Icons.* across docks │    - SplitSheetModal is purely static text  │
└──────────────────────────────────────────┴─────────────────────────────────────────────┘
```

### The Two Critical Gaps:
1. **Stem Separation Simulation Gap:**
   In `apps/vhunambi_client/lib/features/track/presentation/widgets/stem_separation_lab.dart` and `track_providers.dart:62-116`, the stem separation pipeline relies on a simulated 4-step timer (`Future.delayed(40ms)`) that creates dummy stem records with empty audio strings (`audioUrl: ''`). Toggling Mute/Solo merely flips local booleans in `StemTrackEntity` without generating or altering audio. Meanwhile, Phase 24's `JustAudioMultiStemEngine` and Phase 21/25's `StemMixerNotifier` provide real 4-stem DSP isolation, synchronized audio playback, channel gain/pan, and WAV bouncing. Two disconnected stem experiences exist on the track detail screen: the on-screen simulated lab, and an isolated bottom sheet modal (`_FrostedStemMixerSheet`).
2. **Royalty Split-Sheet Disconnection Gap:**
   In `apps/vhunambi_client/lib/features/collections/domain/models/collection_entity.dart`, producers can specify collaborator split percentages (e.g., 60% Producer `@cern`, 40% Vocalist `@fifi`). However, `SplitParticipant` does not bind to actual creator IDs, and there is no financial execution bridge between collections and Phase 28/30's `CreatorWalletNotifier` (`creator_wallet_provider.dart`). When fans tip a track in `TrackDetailView` (`_showTipModal`), or when a beat license is purchased in the Marketplace, 0% of the funds are routed through the collection's split sheet. The tip dialog merely shows an ephemeral SnackBar (`Tipped 10 credits to Fifi! 🪙`).

---

## 2. Dimension 1: Track Details Cockpit Architecture & Stem Separation Gap

### 2.1 The Simulated Timer Trap in `track_providers.dart`
Lines 61–116 of `apps/vhunambi_client/lib/features/track/presentation/providers/track_providers.dart`:
```dart
Future<void> separateStems() async {
  if (state.stemState.isProcessing) return;

  Future<void> advance(StemSeparationStatus status, double progress) async {
    state = state.copyWith(
      stemState: state.stemState.copyWith(status: status, progress: progress),
    );
    await Future<void>.delayed(const Duration(milliseconds: 40));
  }

  await advance(StemSeparationStatus.isolatingVocals, 0.25);
  await advance(StemSeparationStatus.isolatingDrums, 0.50);
  await advance(StemSeparationStatus.isolatingBass, 0.75);
  await advance(StemSeparationStatus.isolatingInstrumental, 0.90);

  state = state.copyWith(
    stemState: StemSeparationState(
      status: StemSeparationStatus.ready,
      progress: 1.0,
      stems: [
        StemTrackEntity(id: '${trackId}_vocals', name: 'Vocals', audioUrl: '', duration: state.duration),
        StemTrackEntity(id: '${trackId}_drums', name: 'Drums', audioUrl: '', duration: state.duration),
        StemTrackEntity(id: '${trackId}_bass', name: 'Bass & Log Drums', audioUrl: '', duration: state.duration),
        StemTrackEntity(id: '${trackId}_inst', name: 'Instrumental', audioUrl: '', duration: state.duration),
      ],
    ),
  );
}
```

### 2.2 Why This Undermines the Platform
- **No Real Audio:** `audioUrl` is empty. The user cannot hear individual stems when clicking SOLO or MUTE.
- **Redundant Separation Controls:**
  - `StemSeparationLab` sits directly in the scroll view (lines 406–429).
  - Immediately below it (lines 432–458), an OutlinedButton opens `_FrostedStemMixerSheet` hosting `StemMixerDeck`.
  - Immediately below that (lines 462–512), another OutlinedButton opens `MobileQuickMasterSheet` / `DesktopMasteringStudioView`.
- **Target Convergence Architecture:**
  - Unify `StemSeparationLab` directly with `stemMixerProvider` (`StemMixerNotifier`) and `multiStemAudioEngineProvider` (`JustAudioMultiStemEngine`).
  - When the user taps "Separate Stems" in `StemSeparationLab`:
    1. Initialize `stemMixerProvider` for the active track.
    2. Populate real stem channel manifests (Vocals, Drums, Bass, Melody/Instrumental) with remote CDN stems or procedural stems.
    3. The inline Mute and Solo toggles directly call `ref.read(stemMixerProvider.notifier).toggleMute(StemType)` and `toggleSolo(StemType)`.
    4. Provide direct entrypoints to "Open Advanced Mixer" and "Master Audio (Studio Polisher)" seamlessly.

---

## 3. Dimension 2: Split Sheet Architecture & The Missing Payout Splitter

### 3.1 Data Model Analysis in `collection_entity.dart`
Current implementation:
```dart
@immutable
class SplitParticipant {
  final String name;
  final String role;
  final double sharePercent; // e.g. 60.0
}
```

#### Deficiencies:
1. **Missing Creator Identity:** There is no `creatorId` (e.g. `creator_cern`, `creator_fifi`) or `handle` (e.g. `@cern`, `@fifi`). Without this, the system cannot look up the recipient's `CreatorWallet`!
2. **Missing Wallet Address / Payout Tag:** No identifier linking to local or remote ledger accounts.
3. **No Track-to-Collection Inversion Index:** A track entity (`TrackDetailEntity` or `Track`) only carries `id`, `creatorId`, `creatorName`. It has no reference to whether it belongs to a collection (EP or Album).
   - *Solution:* Introduce `collectionForTrackProvider(trackId)` or query `collectionsProvider` to locate which collection bundles `trackId`.

### 3.2 Mathematical Formulation of Split Distribution

Let $G_{\text{ZAR}}$ be the gross ZAR payout and $G_{\text{Coins}}$ be the gross Cultural Coins from a tip or beat sale.  
Let $P = \{p_1, p_2, \dots, p_n\}$ be the set of participants in the collection's split sheet, where each participant has a share percentage $s_i \in (0, 100]$.

#### Invariant 1: Conservation of Shares (Split Balance)
$$\sum_{i=1}^{n} s_i = 100.0\% \quad (\pm 0.01\% \text{ tolerance})$$
If $|\sum s_i - 100.0| > 0.01$, the split sheet is **Unbalanced / Unvalidated**. Payouts MUST NOT be split into unvalidated sheets. Instead, 100% is credited to the primary collection owner, or held in escrow with a pending warning.

#### Invariant 2: Conservation of Monetary Value (Zero Leakage)
For ZAR calculations:
$$\text{Payout}_{\text{ZAR}}(p_i) = \text{round}_2\left(G_{\text{ZAR}} \times \frac{s_i}{100.0}\right)$$
To eliminate 1-cent rounding drift where $\sum \text{Payout}_{\text{ZAR}} \ne G_{\text{ZAR}}$, any residual rounding difference $\Delta = G_{\text{ZAR}} - \sum \text{Payout}_{\text{ZAR}}(p_i)$ is attributed to the primary producer ($p_1$ with $\max(s_i)$).

For Cultural Coins:
$$\text{Payout}_{\text{Coins}}(p_i) = \left\lfloor G_{\text{Coins}} \times \frac{s_i}{100.0} \right\rfloor$$
Any remainder coins $\Delta_{\text{coins}} = G_{\text{Coins}} - \sum \text{Payout}_{\text{Coins}}(p_i)$ are assigned to the primary producer ($p_1$).

---

## 4. Dimension 3: End-to-End Monetization Convergence

### 4.1 Track Tip Modal Overhaul (`_showTipModal`)
Currently, `_showTipModal` in `track_detail_view.dart`:
```dart
onPressed: () {
  Navigator.of(context).pop();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Tipped $credits credits to ${track.creatorName}! 🪙')),
  );
}
```
This is a purely superficial mock.

#### Target Implementation:
1. Connect `_showTipModal` to `creatorWalletProvider`:
   - Inspect user's `userCoinsBalance`.
   - If insufficient coins, provide a "Top Up Coins" action.
   - If sufficient coins, invoke:
     ```dart
     ref.read(creatorWalletProvider.notifier).distributeTrackTip(
       trackId: track.id,
       trackTitle: track.title,
       creatorId: track.creatorId,
       credits: credits,
       collection: matchedCollection, // null if single
     );
     ```
2. When `matchedCollection` is present and `matchedCollection.isSplitBalanced` is true:
   - Calculate each collaborator's share.
   - Post an immutable `TipRecordEntity` or `GiftTransaction` to each recipient's ledger.
   - Show a celebratory confirmation:
     `Tipped 50 Coins! Split across 2 collaborators: Fifi (60%), Sipho (40%) ✨`

---

## 5. Dimension 4: UI/UX & App-Wide Modern Iconography (`STD-UIUX-001`)

### 5.1 Emoji Reaction Deck Refactor
In `apps/vhunambi_client/lib/features/track/presentation/widgets/emoji_reaction_deck.dart`:
```dart
// CURRENT VIOLATION:
static const Map<String, String> reactionGlyphs = {
  'fire': '🔥',
  'love': '❤️',
  'rhythm': '🎵',
  'hands': '🙌',
  'globe': '🌍',
};
```
Text emojis violate `STD-UIUX-001`. They render with platform-inconsistent colors, lack theme adaptation, and have uneven baselines.

#### Modern Phosphor Vector Mapping:
| Key | Legacy Emoji | Phosphor Vector Icon (`PhosphorIconsRegular` / `PhosphorIconsFill`) | Color Token |
| :--- | :--- | :--- | :--- |
| `fire` | `🔥` | `PhosphorIconsRegular.fire` / `AppIcons.flame` | `AppColors.brandPrimary` |
| `love` | `❤️` | `PhosphorIconsRegular.heart` / `AppIcons.heart` | `AppColors.accentCrimson` |
| `rhythm` | `🎵` | `PhosphorIconsRegular.musicNotes` / `AppIcons.disc` | `AppColors.brandSecondary` |
| `hands` | `🙌` | `PhosphorIconsRegular.handsClapping` | `AppColors.coinGold` |
| `globe` | `🌍` | `PhosphorIconsRegular.globeHemisphereWest` / `AppIcons.globe` | `AppColors.accentBlue` |

Each reaction chip must maintain:
- Height $\ge 44\text{dp}$.
- Rounded pill border (`AppRadius.pillBorder`).
- Subtle background tint when selected (`color.withAlpha(25)`).
- Circular touch feedback boundary.

### 5.2 Iconography Audit Across Track & Collection Widgets:
- `TrackActionsBar`:
  - `Icons.favorite_rounded` $\to$ `AppIcons.heart`
  - `Icons.play_arrow_rounded` $\to$ `AppIcons.play`
  - `Icons.shuffle_rounded` $\to$ `AppIcons.remix` (`PhosphorIconsRegular.shuffle`)
  - `Icons.monetization_on_rounded` $\to$ `AppIcons.coinGold` (`PhosphorIconsRegular.coin`)
- `UtilityToolDock`:
  - `Icons.download_rounded` $\to$ `AppIcons.download`
  - `Icons.playlist_add_rounded` $\to$ `AppIcons.playlist`
  - `Icons.radio_rounded` $\to$ `AppIcons.radio`
  - `Icons.lyrics_rounded` $\to$ `PhosphorIconsRegular.textT`
  - `Icons.alt_route_rounded` $\to$ `PhosphorIconsRegular.gitFork`
  - `Icons.chat_bubble_outline_rounded` $\to$ `AppIcons.chat`
  - `Icons.code_rounded` $\to$ `PhosphorIconsRegular.code`
  - **NEW FEATURE CHIP:** Add `Video Export Reel` chip (`PhosphorIconsRegular.videoCamera`) directly opening `VideoExportModal` (Phase 27).
- `_SplitParticipantsSection` & `SplitSheetModal`:
  - Replace `Icons.edit_rounded`, `Icons.close_rounded`, `Icons.person_add_alt_1_rounded`, `Icons.copy_rounded` with `AppIcons` and rounded Phosphor equivalents.

---

## 6. Dimension 5: Responsive Ergonomics & Navigation Layout

### 6.1 Desktop Cockpit ($W \ge 1024\text{dp}$)
- Two-column split layout:
  - **Left Column (420dp):** 1:1 Cover Art Showcase, Social Actions, Utility Dock, Waveform Scrubber, Split-Sheet Contributor Ledger.
  - **Right Column (Flex):** 4-Stem Live Synchronized Mixer, Teleprompter Lyrics, Discussion Thread.
- Sticky frosted glass app-bar with title cross-fade and back navigation.

### 6.2 Mobile Layout ($W < 768\text{dp}$)
- Single-column fluid scroll.
- Bottom clearance for the floating adaptive mini-player using `VhunambiBottomDockMetrics.scrollInset(hasActiveTrack: playerState.hasActiveTrack)`.
- Touch target compliance ($\ge 44 \times 44\text{dp}$) on all interactive chips, sliders, and buttons.

---

## 7. Dimension 6: Test Suite & Verification Roadmap

### Existing Test Baseline:
- `test/features/track/`: 2 test files, 15 tests (all passing).
- `test/features/collections/`: 5 test files, 65 tests (all passing).
- **Total Existing Baseline:** 80/80 tests passing 100%.

### Required New Test Coverage:
1. `test/features/track/track_stem_real_engine_test.dart`:
   - Verifies `StemSeparationLab` binds to `JustAudioMultiStemEngine` and `StemMixerNotifier`.
   - Verifies Mute/Solo directly updates mixer channels without mock timers.
2. `test/features/collections/domain/services/royalty_distribution_service_test.dart`:
   - Verifies mathematical precision of ZAR and Coin splits.
   - Verifies 100% share conservation and rounding dust assignment.
   - Verifies unbalanced split sheets are rejected.
3. `test/features/track/track_detail_vector_icons_test.dart`:
   - Verifies all 5 cultural reaction chips render rounded Phosphor icons.
   - Verifies 0 emojis exist in `EmojiReactionDeck`.
   - Verifies touch target constraints ($\ge 44\text{dp}$).
4. `test/features/track/track_detail_tip_split_integration_test.dart`:
   - Verifies tipping a track belonging to a collection credits each collaborator's `CreatorWallet` according to their split percentage.

---

## 8. Summary Table of Architecture Changes

| Component | Current Phase 7/13 Legacy State | Phase 34 Converged State |
| :--- | :--- | :--- |
| **Stem Isolation Engine** | Simulated 4-step timer (`40ms` delays), dummy empty URLs | Real `JustAudioMultiStemEngine` + `StemMixerNotifier` |
| **Stem Mute/Solo** | Local boolean flip in `StemTrackEntity` (silent) | Active DSP muting/soloing via `StemMixerNotifier` |
| **Stem Separation UI** | Disconnected on-screen lab + separate bottom sheet | Unified inline 4-stem lab with 1-tap "Open Full Mixer" |
| **Cultural Reactions** | Raw Unicode emojis (`🔥`, `❤️`, `🎵`, `🙌`, `🌍`) | Soft rounded Phosphor vector icons (`STD-UIUX-001`) |
| **Toolbar Icons** | Material `Icons.*_rounded` | `AppIcons` + rounded Phosphor icons ($\ge 44\text{dp}$) |
| **Video Reel Export** | Missing from Track Details | Integrated `Export Video Reel` chip $\to$ `VideoExportModal` |
| **Split Participant Model**| `name`, `role`, `sharePercent` only | Adds `creatorId`, `handle`, `walletAddress` |
| **Royalty Distribution** | Completely unlinked from wallets; dummy snackbar | Proportional ZAR & Coin splitter into `CreatorWallet` |
| **Split Sheet Validation** | Visual error text only | Mathematical $\sum\% = 100\%$ gate for automated payouts |

