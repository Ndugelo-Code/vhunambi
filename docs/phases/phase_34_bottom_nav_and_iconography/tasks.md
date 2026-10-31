# 📋 Phase 34 Task Breakdown: Mobile Bottom Navigation & Phosphor Iconography

**Phase Identifier:** `PHASE-34-NAV-ICON`  
**Status:** Completed & Field-Verified on Device (`EPHUT20917014649`)

---

## Task Inventory

- [x] **Task 34.1: Install `phosphor_icons: ^3.0.1`**
  - Add `phosphor_icons: ^3.0.1` to `apps/vhunambi_client/pubspec.yaml`.
  - Run `flutter pub get`.
  - Verify dependency resolution.

- [x] **Task 34.2: Author `AppIcons` Design Token Registry**
  - Create `apps/vhunambi_client/lib/core/design_system/tokens/app_icons.dart`.
  - Map navigation, status, audio, and player semantic tokens with style-specific classes for compile-time tree shaking.
  - Export `AppIcons` through `design_system.dart`.

- [x] **Task 34.3: Author Unit Tests for `AppIcons` Tokens**
  - Create `apps/vhunambi_client/test/core/design_system/app_icons_test.dart`.
  - Verify all icon tokens resolve to valid `IconData` codePoints across navigation, gamification, DAW, media transport, and common UI actions.

- [x] **Task 34.4: Implement `VhunambiMobileBottomNav`**
  - Create `apps/vhunambi_client/lib/core/widgets/vhunambi_mobile_bottom_nav.dart`.
  - Build zero-flash touch surfaces (`splashColor: Colors.transparent`, `highlightColor: Colors.transparent`).
  - Implement smooth capsule indicator (`Curves.easeOutCubic`, 220ms), elevated center "Create" hero orb with `AppGradients.primaryButton`, and single-channel haptics (`HapticsService().selectionClick()`).
  - Tag tabs with `Key('mobile_nav_tab_0')` .. `Key('mobile_nav_tab_4')`.

- [x] **Task 34.5: Author Unit & Widget Tests for `VhunambiMobileBottomNav`**
  - Create `apps/vhunambi_client/test/core/widgets/vhunambi_mobile_bottom_nav_test.dart`.
  - Assert zero `InkResponse` highlight, active tab capsule animation, haptic invocation, and tab selection callbacks (2/2 tests pass).

- [x] **Task 34.6: Integrate `VhunambiMobileBottomNav` into `main.dart`**
  - Replace stock `BottomNavigationBar` in `lib/main.dart` with `VhunambiMobileBottomNav`.
  - Wire `onTap: _switchTab` and `currentIndex: _currentIndex`.
  - Verify root app smoke test (`test/widget_test.dart`).

- [x] **Task 34.7: Migrate Home Dashboard Emojis & Stock Icons to Phosphor Vectors**
  - In `lib/features/home/presentation/views/home_dashboard_view.dart`:
    - Replace `Text('🔥')` with `PhosphorIcon(AppIcons.flame)`.
    - Replace `Text('🪙')` with `PhosphorIcon(AppIcons.coin)`.
    - Replace `Icons.notifications_outlined` with `PhosphorIcon(AppIcons.bell)`.
    - Replace `Icons.arrow_forward_ios_rounded` with `PhosphorIcon(AppIcons.caretRight)`.
    - Replace `Icons.auto_awesome` with `PhosphorIcon(AppIcons.sparkle)`.
    - Replace `Icons.album_rounded` with `PhosphorIcon(AppIcons.disc)`.
    - Replace `Icons.workspace_premium_rounded` with `PhosphorIcon(AppIcons.crown)`.
    - Upgrade 6 Creation Hub tiles to Phosphor glyphs (`AppIcons.magicWand`, `AppIcons.voiceClone`, `AppIcons.piano`, `AppIcons.mastering`, `AppIcons.navMarket`, `AppIcons.songs`).
    - Upgrade Jump Back In controls to `AppIcons.songs`, `AppIcons.beatstore`, and `AppIcons.play` / `AppIcons.pause`.

- [x] **Task 34.8: Migrate Profile & Wallet Emojis to Phosphor Vectors**
  - In `lib/features/profile/presentation/views/owner_profile_view.dart`: Replace tab segment emojis (`🎵`, `💿`, `🎛️`) with `AppIcons.songs`, `AppIcons.releases`, `AppIcons.beatstore` wrapped in `FittedBox`.
  - In `lib/features/profile/presentation/widgets/top_supporters_leaderboard.dart`: Replace `🏆`, `🪙`, `⚡` with `AppIcons.trophy`, `AppIcons.coin`, and `AppIcons.coin`.
  - In `lib/features/profile/presentation/widgets/creator_wallet_deck.dart`: Replace `Icons.payments_rounded` with `PhosphorIconsRegular.creditCard` and coin emojis with vector pills.
  - In `lib/features/social/presentation/widgets/creator_tipping_sheet.dart`: Replace coin emojis with `AppIcons.coin`.

- [x] **Task 34.9: App-Wide Primary Surface Iconography Sweep**
  - **Explore Top Bar (`explore_top_bar.dart`):** Replaced search, discovery hub, close, lightning, and create buttons with Phosphor glyphs (`squaresFour`, `magnifyingGlass`, `close`, `lightning`, `plus`).
  - **Explore Social Post Card (`explore_social_post_card.dart`):** Replaced action rail with `AppIcons.heart` / `heartOutline`, `AppIcons.chat`, `AppIcons.remix`, `AppIcons.coin`, `AppIcons.share`, `AppIcons.waveform`, and `AppIcons.verified`.
  - **Kinetic Reels Modal (`kinetic_reels_modal.dart`):** Replaced right-rail action buttons, burst heart, verified badge, sound pill, and top controls with Phosphor glyphs.
  - **Stem Mixer Deck (`stem_mixer_deck.dart`):** Replaced stem channel icons (`vocals`, `drums`, `piano`, `guitar`), transport controls, drift indicators, and action buttons.
  - **Player Transport Bar & Mini-Player (`desktop_transport_bar.dart`, `mobile_mini_player.dart`, `card_form.dart`, `expanded_cockpit_modal.dart`):** Replaced transport, shuffle, repeat, volume, expand, dismiss, and waveform icons with rounded Phosphor glyphs.
  - **Beats & Marketplace Cards (`features/beats/presentation/widgets/beat_card.dart`, `features/marketplace/presentation/widgets/beat_card.dart`, `marketplace_view.dart`):** Upgraded waveform, audition play/pause, more actions, and verified badges.

- [x] **Task 34.10: Comprehensive Phase 34 Verification Suite**
  - Authored `apps/vhunambi_client/test/features/navigation/phase34_bottom_nav_and_iconography_test.dart` (8/8 tests pass).
  - Verified all core criteria: zero flash glow, capsule animations, tab selection, haptic triggers, emoji deprecation, and 360×800 responsiveness.

- [x] **Task 34.11: Full Verification & Physical Device Field Test**
  - Static Analyzer: `dart analyze lib test` in `apps/vhunambi_client` $\rightarrow$ **0 issues**.
  - All test suites passing: Navigation (8/8), Home (18/18), Explore (45/45), Social (27/27), Marketplace & Beats (115/115).
  - Release APK compiled with 98%+ Phosphor font tree-shaking reduction (`flutter build apk --release --target-platform android-arm64 --no-pub` $\rightarrow$ 41.5MB).
  - Installed and field-tested on physical Android device (`EPHUT20917014649`) with 100% verified UI touch physics, smooth capsule transitions, single-channel tactile haptics, and soft rounded vector iconography.
