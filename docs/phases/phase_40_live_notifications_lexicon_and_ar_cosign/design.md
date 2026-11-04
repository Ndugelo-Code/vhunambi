# Phase 40 Design: Live Notifications, Bantu Lexicon, Fresh Crate A&R Co-Sign & Coin Top-Up

## §1. Notifications Taxonomy & Seed State (§ Track A)
### 1.1 Default Initial State in `NotificationsNotifier`
Instead of defaulting to `const <NotificationEntity>[]`, `NotificationsNotifier` initializes with `seededNotifications`.

```dart
List<NotificationEntity> get seededNotifications => [
  NotificationEntity(
    id: 'notif_seed_soc_1',
    title: 'New Cultural Gift Received!',
    message: '@lerato_piano sent Royal Venda Crown (200 Coins)',
    category: NotificationCategory.social,
    priority: NotificationPriority.high,
    createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
    metadata: {'sender': '@lerato_piano', 'coins': 200},
  ),
  NotificationEntity(
    id: 'notif_seed_soc_2',
    title: 'Open Stems Collaboration',
    message: '@makhadzi opened stems on "Ndo Mufuna Matibe"',
    category: NotificationCategory.social,
    priority: NotificationPriority.normal,
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
  ),
  NotificationEntity(
    id: 'notif_seed_soc_3',
    title: 'New Open-Verse Remix',
    message: '@fifi dropped an energetic remix on your Private School beat',
    category: NotificationCategory.social,
    priority: NotificationPriority.normal,
    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
  ),
  NotificationEntity(
    id: 'notif_seed_act_1',
    title: 'Marketplace License Sold!',
    message: 'Beat license sold: Township Heat (+42 Coins / R38)',
    category: NotificationCategory.creatorActivity,
    priority: NotificationPriority.high,
    createdAt: DateTime.now().subtract(const Duration(hours: 4)),
  ),
  NotificationEntity(
    id: 'notif_seed_act_2',
    title: 'Fresh Crate Graduation Alert!',
    message: 'Your track reached 25/25 A&R Co-Signs and graduated to Rising Breakout!',
    category: NotificationCategory.creatorActivity,
    priority: NotificationPriority.high,
    createdAt: DateTime.now().subtract(const Duration(hours: 8)),
  ),
  NotificationEntity(
    id: 'notif_seed_act_3',
    title: 'Studio Render Complete',
    message: 'Your song "ZaYN" is ready! House • 3:20 (44.1 kHz 24-bit WAV)',
    category: NotificationCategory.creatorActivity,
    priority: NotificationPriority.normal,
    targetTrackId: 'trk_pipeline_001',
    createdAt: DateTime.now().subtract(const Duration(hours: 12)),
  ),
  NotificationEntity(
    id: 'notif_seed_sys_1',
    title: 'VHU-SIG Continuous Phase DSP Active',
    message: 'High-fidelity audio engine tuned with 44.1 kHz continuous phase synthesis',
    category: NotificationCategory.system,
    priority: NotificationPriority.normal,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
  NotificationEntity(
    id: 'notif_seed_sys_2',
    title: 'Welcome to Vhunambi Creator Suite!',
    message: 'Start generating high-fidelity African regional music and licensing sound stems.',
    category: NotificationCategory.system,
    priority: NotificationPriority.normal,
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    isRead: true,
  ),
  NotificationEntity(
    id: 'notif_seed_alg_1',
    title: 'Regional Trend Alert',
    message: 'Maskandi & Private School Amapiano trending in Gauteng (+420% plays)',
    category: NotificationCategory.algorithmic,
    priority: NotificationPriority.normal,
    createdAt: DateTime.now().subtract(const Duration(hours: 6)),
  ),
  NotificationEntity(
    id: 'notif_seed_alg_2',
    title: 'Sonic DNA Affinity',
    message: 'Your vocal timbres match 94% with Tshivenḓa traditional folk and Afro-house rhythms',
    category: NotificationCategory.algorithmic,
    priority: NotificationPriority.normal,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
];
```

---

## §2. Expanded 9-Language Bantu Sing-Along Lexicon (§ Track B)
`kBantuCuratedEntries` is expanded to include comprehensive phrases and vocabularies across all 9 constitutional South African Bantu languages.

```dart
// Core catalog lines:
BantuGlossaryEntry(
  phrase: 'ndo mufuna matibe mbilu yanga',
  meaning: 'I love intensely from the depths of my heart (Tshivenḓa)',
  language: BantuLanguage.ve,
),
BantuGlossaryEntry(
  phrase: 'ndo mufuna matibe',
  meaning: 'I love you deeply (Tshivenḓa)',
  language: BantuLanguage.ve,
),
BantuGlossaryEntry(
  phrase: 'mbilu yanga',
  meaning: 'my heart / my soul (Tshivenḓa)',
  language: BantuLanguage.ve,
),
BantuGlossaryEntry(
  phrase: 'iya pembelela woza amapiano sgubhu',
  meaning: 'My heart celebrates, come feel the Amapiano log-drum beat (Tshivenḓa / isiZulu)',
  language: BantuLanguage.ve,
),
BantuGlossaryEntry(
  phrase: 'iya pembelela',
  meaning: 'celebrating / dancing with joy (Tshivenḓa)',
  language: BantuLanguage.ve,
),
BantuGlossaryEntry(
  phrase: 'woza amapiano sgubhu',
  meaning: 'come feel the Amapiano bass groove (isiZulu)',
  language: BantuLanguage.zu,
),
BantuGlossaryEntry(
  phrase: 'venda sunrise ndi matsheloni makhado',
  meaning: 'Dawn breaks over Makhado, good morning (Tshivenḓa)',
  language: BantuLanguage.ve,
),
...
```

---

## §3. Fresh Crate Co-Sign Loop (§ Track C)
1. Add `cosignCount` (int, default 0) and `isCosigned` (bool, default false) to `SocialMusicPost`.
2. Add `void cosignPost(String postId)` to `SocialFeedPostsNotifier`.
3. In `DiscoveryHierarchyRanker.rank(post)`:
   If `post.cosignCount >= 25`, ensure the post tier is promoted to at least `DiscoveryStageTier.risingBreakout` and award score $+30$.
4. In `ExploreSocialPostCard`:
   If the post's tier is `freshCrate` or `risingBreakout`, render:
   ```dart
   InkWell(
     key: Key('post_cosign_btn_${widget.post.id}'),
     onTap: () => ref.read(socialFeedPostsProvider.notifier).cosignPost(widget.post.id),
     child: Container(
       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
       decoration: BoxDecoration(
         color: widget.post.isCosigned ? AppColors.brandPrimary.withValues(alpha: 0.15) : AppColors.surfaceSecondaryOf(context),
         borderRadius: BorderRadius.circular(16),
         border: Border.all(
           color: widget.post.isCosigned ? AppColors.brandPrimary : AppColors.borderSubtleOf(context),
         ),
       ),
       child: Row(
         mainAxisSize: MainAxisSize.min,
         children: [
           PhosphorIcon(
             PhosphorIconsFill.fire,
             size: 13,
             color: widget.post.isCosigned ? AppColors.coinGold : AppColors.textSecondaryOf(context),
           ),
           const SizedBox(width: 4),
           Text(
             widget.post.cosignCount >= 25
                 ? '🔥 Graduated · ${widget.post.cosignCount}'
                 : '🔥 Co-Sign · ${widget.post.cosignCount}/25',
             style: AppTypography.caption.copyWith(
               fontSize: 10.5,
               fontWeight: FontWeight.bold,
               color: widget.post.isCosigned ? AppColors.brandPrimary : AppColors.textPrimaryOf(context),
             ),
           ),
         ],
       ),
     ),
   );
   ```

---

## §4. Live Coin Top-Up in `SubscriptionUpgradeModal` (§ Track D)
1. In `SubscriptionUpgradeModal`, render a dedicated **Instant Coin Top-Up (ZAR)** section above or alongside subscription tiers:
   - 100 Coins · R45
   - 300 Coins · R120
   - 1,000 Coins · R350
2. Selecting a pack or confirming:
   - Invokes `ref.read(creatorWalletProvider.notifier).topUpCoins(pack.coins)`.
   - Posts a receipt notification:
     ```dart
     ref.read(notificationsProvider.notifier).addNotification(
       NotificationEntity(
         id: 'notif_topup_${DateTime.now().millisecondsSinceEpoch}',
         title: 'Coins Credited!',
         message: 'Successfully topped up ${pack.coins} Coins via Ozow / Capitec Pay.',
         category: NotificationCategory.system,
         priority: NotificationPriority.high,
         createdAt: DateTime.now(),
       ),
     );
     ```
   - Closes modal with celebratory feedback SnackBar.

