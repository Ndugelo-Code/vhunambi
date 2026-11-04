# Phase 40 Tasks: Live Notifications, Bantu Lexicon, Fresh Crate A&R Co-Sign & Coin Top-Up

- [ ] **Track A: Live Notifications Engine**
  - [ ] **T-A1**: Seed `notificationsProvider` with authentic items across all 4 categories (`social`, `system`, `creatorActivity`, `algorithmic`) in `notifications_provider.dart`.
  - [ ] **T-A2**: Wire reactive notification dispatches in `creator_wallet_provider.dart` (`distributeTrackTip`, `sendCulturalGift`), `marketplace_providers.dart` (`licenseBeat`), and `open_verse_remix_cockpit_sheet.dart`.

- [ ] **Track B: Expanded 9-Language Bantu Sing-Along Lexicon**
  - [ ] **T-B1**: Add complete lyric lines for Vhunambi catalog tracks (`"Ndo Mufuna Matibe Mbilu Yanga"`, `"Iya Pembelela Woza Amapiano Sgubhu"`, `"Venda Sunrise Ndi Matsheloni Makhado"`) in `bantu_lyric_translation_service.dart`.
  - [ ] **T-B2**: Expand `kBantuCuratedEntries` with 150+ high-frequency cultural and musical roots across all 9 constitutional South African Bantu languages.
  - [ ] **T-B3**: Enhance `translateLine` with composite phrase matching fallback so 100% of catalog lines produce non-empty translated meanings.

- [ ] **Track C: Fresh Crate Co-Sign A&R Graduation Loop**
  - [ ] **T-C1**: Add `cosignCount` and `isCosigned` to `SocialMusicPost` domain model.
  - [ ] **T-C2**: Update `DiscoveryHierarchyRanker.rank` to factor in co-signs and guarantee promotion to `risingBreakout` when `cosignCount >= 25`.
  - [ ] **T-C3**: Add `cosignPost(String id)` method to `SocialFeedPostsNotifier`.
  - [ ] **T-C4**: Mount `[ 🔥 Co-Sign · ${cosignCount}/25 ]` pill (`Key('post_cosign_btn_${post.id}')`) on `ExploreSocialPostCard`.

- [ ] **Track D: Live ZAR Coin Top-Up in SubscriptionUpgradeModal**
  - [ ] **T-D1**: Add selectable **Instant Coin Top-Up (ZAR)** cards (100 Coins / R45, 300 Coins / R120, 1000 Coins / R350) and `Key('upgrade_modal_confirm_btn')` in `subscription_upgrade_modal.dart`.
  - [ ] **T-D2**: Wire immediate credit to `creatorWalletProvider.notifier.topUpCoins(...)` and post receipt to `notificationsProvider`.

- [ ] **Track E: Verification, Single Combined Release APK Build & Hardware Install**
  - [ ] **T-E1**: Author `test/features/explore/phase40_notifications_lexicon_cosign_and_topup_test.dart`.
  - [ ] **T-E2**: Run `dart analyze lib test` → 0 issues.
  - [ ] **T-E3**: Run `flutter test` across modified suites → 100% green.
  - [ ] **T-E4**: Build ARM64 release APK (`flutter build apk --release --target-platform android-arm64 --no-pub`).
  - [ ] **T-E5**: Install APK to physical hardware `EPHUT20917014649` via ADB and launch app.
  - [ ] **T-E6**: Update `docs/AGENT_HANDOFF_BIBLE.md` and commit to Git.

