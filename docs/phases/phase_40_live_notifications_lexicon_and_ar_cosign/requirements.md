# Phase 40 Requirements: Live Notifications, Bantu Lexicon, Fresh Crate A&R Co-Sign & Coin Top-Up

## Track A: Live Reactive Notifications Engine
- **REQ-NOTIF-SEED-01**: `notificationsProvider` must initialize with authentic seeded notifications spanning all 4 canonical categories:
  - `NotificationCategory.social`: Gifting / tips, stems opened, open-verse remix drops.
  - `NotificationCategory.system`: Continuous Phase Audio Engine 44.1 kHz active, VHU-SIG Sound Signature enabled, platform terms.
  - `NotificationCategory.creatorActivity` ("Activity"): Marketplace licensing sales with net coin/ZAR splits, Fresh Crate graduation alerts, render completions.
  - `NotificationCategory.algorithmic` ("Discovery"): Regional genre trends and rising vocal hook analytics.
- **REQ-NOTIF-DISPATCH-01**: The system must provide a helper or directly push notifications into `notificationsProvider` upon:
  - Cultural gift or tip dispatch in `CreatorTippingSheet` / `CreatorWalletNotifier`.
  - Remix creation and publishing in `OpenVerseRemixCockpitSheet`.
  - Marketplace license acquisition in `marketplace_providers.dart` `licenseBeat`.
  - Coin top-up or subscription upgrade in `SubscriptionUpgradeModal`.

## Track B: Expanded 9-Language Bantu Lexicon & Sing-Along
- **REQ-LEX-COV-01**: The curated glossary `kBantuCuratedEntries` in `bantu_lyric_translation_service.dart` must cover 100% of the lyrics present in seeded catalog reels and tracks:
  - `"Ndo Mufuna Matibe Mbilu Yanga"` -> `"I love intensely from the depths of my heart"`
  - `"Ndo mufuna matibe"` -> `"I love you deeply"`
  - `"Mbilu yanga"` -> `"My heart / my soul"`
  - `"Iya Pembelela Woza Amapiano Sgubhu"` -> `"My heart celebrates, come feel the Amapiano log-drum beat"`
  - `"Iya pembelela"` -> `"Celebrating / dancing with joy"`
  - `"Woza amapiano sgubhu"` -> `"Come feel the Amapiano bass groove"`
  - `"Venda Sunrise Ndi Matsheloni Makhado"` -> `"Dawn breaks over Makhado, good morning"`
  - `"Ndi matsheloni makhado"` -> `"Good morning Makhado"`
- **REQ-LEX-ROOTS-02**: Must supply rich root vocabulary covering core greetings, cultural affirmations, natural phenomena, and musical terminology across all 9 constitutional South African Bantu languages (`ve`, `zu`, `xh`, `ss`, `nr`, `nso`, `tn`, `st`, `ts`).
- **REQ-LEX-MATCH-03**: In `translateLine`, if an exact match is missing, token-level lookup must stitch together phrase meanings, preventing unassisted `"meaning unavailable"` results.

## Track C: Fresh Crate "Co-Sign" A&R Graduation Loop
- **REQ-COSIGN-MODEL-01**: `SocialMusicPost` must include `cosignCount` (default 0) and `isCosigned` (default false) with complete serialization and `copyWith` support.
- **REQ-COSIGN-UI-01**: `ExploreSocialPostCard` must render a `Key('post_cosign_btn_${post.id}')` action pill for posts in `DiscoveryStageTier.freshCrate` or `risingBreakout`, displaying `[ 🔥 Co-Sign · ${post.cosignCount}/25 ]` with `PhosphorIconsFill.fire`.
- **REQ-COSIGN-GRAD-02**: Tapping the Co-Sign button increments `cosignCount`. If `cosignCount >= 25`, the post tier evaluates to at least `DiscoveryStageTier.risingBreakout` in `DiscoveryHierarchyRanker.rank(...)`, graduating the creator to the next tier and pushing an activity notification.
- **REQ-COSIGN-SCOUT-03**: Incrementing co-sign awards/progresses the current user's Tastemaker reputation (`arScoutCount` or profile points) in `ArtistProfileEntity` and `OwnerProfileView`.

## Track D: Live ZAR Coin Top-Up in SubscriptionUpgradeModal
- **REQ-TOPUP-UI-01**: `SubscriptionUpgradeModal` must render an **Instant Coin Top-Up (ZAR)** section with selectable packs:
  - 100 Coins · R45 (`Key('coin_topup_pack_100')`)
  - 300 Coins · R120 (`Key('coin_topup_pack_300')`)
  - 1,000 Coins · R350 (`Key('coin_topup_pack_1000')`)
- **REQ-TOPUP-CONFIRM-02**: Pressing the purchase/top-up button (`Key('upgrade_modal_confirm_btn')` or pack button) invokes `ref.read(creatorWalletProvider.notifier).topUpCoins(amount)`, updates the wallet state synchronously, dispatches a receipt notification to `notificationsProvider`, closes the modal, and shows a celebratory SnackBar.

## Track E: Quality & Verification
- **REQ-VERIF-01**: Unit and widget test suite `test/features/explore/phase40_notifications_lexicon_cosign_and_topup_test.dart` passes 100%.
- **REQ-VERIF-02**: Full static analysis reports zero errors/warnings (`dart analyze`).
- **REQ-VERIF-03**: Combined Phase 39 + Phase 40 ARM64 release APK builds and installs seamlessly onto physical test hardware `EPHUT20917014649`.

