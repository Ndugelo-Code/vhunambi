import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../landing/domain/models/landing_models.dart';
import '../../../landing/presentation/providers/landing_providers.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../social/presentation/providers/creator_wallet_provider.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../notifications/domain/models/notification_entity.dart';
import '../../../notifications/domain/models/notification_enums.dart';


class SubscriptionUpgradeModal extends ConsumerWidget {
  const SubscriptionUpgradeModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SubscriptionUpgradeModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billingCycle = ref.watch(pricingBillingCycleProvider);
    final tiers = ref.watch(pricingTiersProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Drag handle
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderSubtle,
              borderRadius: AppRadius.pillBorder,
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Creator Plans & Credits',
                        style: AppTypography.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Unlock unlimited stems, high-bitrate WAVs & 100% commercial ownership',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Monthly / Yearly billing cycle toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondary,
              borderRadius: AppRadius.pillBorder,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildToggleTab(
                  ref: ref,
                  label: 'Monthly',
                  isActive: billingCycle == BillingCycle.monthly,
                  cycle: BillingCycle.monthly,
                ),
                const SizedBox(width: 4),
                _buildToggleTab(
                  ref: ref,
                  label: 'Yearly (-20%)',
                  isActive: billingCycle == BillingCycle.yearly,
                  cycle: BillingCycle.yearly,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),


          // Instant Coin Top-Up Section (REQ-TOPUP-UI-01)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondaryOf(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSubtleOf(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const PhosphorIcon(
                        PhosphorIconsFill.coins,
                        color: AppColors.coinGold,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Instant Coin Top-Up (ZAR)',
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Instant Ozow / Capitec Pay credits for tips, stems & licenses',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTopUpPack(
                          context,
                          ref,
                          keyName: 'coin_topup_pack_500',
                          packId: 'pack_starter_500',
                          coins: 500,
                          priceZar: 55,
                          badge: null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTopUpPack(
                          context,
                          ref,
                          keyName: 'coin_topup_pack_1500',
                          packId: 'pack_producer_1500',
                          coins: 1500,
                          priceZar: 150,
                          badge: '+15%',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTopUpPack(
                          context,
                          ref,
                          keyName: 'coin_topup_pack_5000',
                          packId: 'pack_mogul_5000',
                          coins: 5000,
                          priceZar: 450,
                          badge: 'POPULAR',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Tier cards list/grid
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              itemCount: tiers.length,
              separatorBuilder: (context, index) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final tier = tiers[index];
                return _buildTierCard(context, ref, tier, billingCycle);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTab({
    required WidgetRef ref,
    required String label,
    required bool isActive,
    required BillingCycle cycle,
  }) {
    return GestureDetector(
      onTap: () {
        ref.read(pricingBillingCycleProvider.notifier).state = cycle;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.brandPrimary : Colors.transparent,
          borderRadius: AppRadius.pillBorder,
        ),
        child: Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: isActive ? AppColors.brandContrast : AppColors.textSecondary,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }


  Widget _buildTopUpPack(
    BuildContext context,
    WidgetRef ref, {
    required String keyName,
    required String packId,
    required int coins,
    required int priceZar,
    String? badge,
  }) {
    return InkWell(
      key: Key(keyName),
      onTap: () {
        final walletNotifier = ref.read(creatorWalletProvider.notifier);
        walletNotifier.topUpCoins(coins);
        walletNotifier.dispatchPayFastCheckoutNotice(packId);
        ref.read(notificationsProvider.notifier).addNotification(
          NotificationEntity(
            id: 'notif_topup_${DateTime.now().millisecondsSinceEpoch}',
            title: 'Coins Credited!',
            message: 'Successfully topped up $coins Coins via PayFast ZAR / Instant EFT (R$priceZar).',
            category: NotificationCategory.system,
            priority: NotificationPriority.high,
            createdAt: DateTime.now(),
          ),
        );
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully credited $coins Cultural Coins!'),
            backgroundColor: AppColors.brandPrimary,
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevatedOf(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: badge != null ? AppColors.brandPrimary : AppColors.borderSubtleOf(context),
            width: badge != null ? 1.2 : 0.8,
          ),
        ),
        child: Column(
          children: [
            if (badge != null)
              Container(
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const PhosphorIcon(
                  PhosphorIconsBold.coins,
                  size: 13,
                  color: AppColors.brandPrimary,
                ),
                const SizedBox(width: 4),
                Text(
                  '$coins',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'R$priceZar',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 10,
                color: AppColors.brandPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierCard(
    BuildContext context,
    WidgetRef ref,
    PricingTier tier,
    BillingCycle cycle,
  ) {
    final price = tier.priceFor(cycle);
    final isPopular = tier.isPopular;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isPopular ? AppColors.surfaceSecondary : AppColors.surfaceCanvas,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPopular ? AppColors.brandPrimary : AppColors.borderSubtle,
          width: isPopular ? 1.5 : 1,
        ),
        boxShadow: isPopular
            ? [
                BoxShadow(
                  color: AppColors.brandPrimary.withAlpha(25),
                  blurRadius: 16,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                tier.name,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isPopular ? AppColors.brandPrimary : AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (isPopular)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary,
                    borderRadius: AppRadius.pillBorder,
                  ),
                  child: Text(
                    'MOST POPULAR',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.brandContrast,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '\$$price',
                style: AppTypography.displayLarge.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                ),
              ),
              Text(
                '/month',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                tier.songAllowance,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.brandPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: AppColors.borderSubtle, height: 1),
          const SizedBox(height: 12),
          ...tier.features.take(3).map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.brandPrimary, size: 15),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        f,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('upgrade_modal_confirm_btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isPopular ? AppColors.brandPrimary : AppColors.surfaceElevated,
                foregroundColor:
                    isPopular ? AppColors.brandContrast : AppColors.textPrimary,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.pillBorder,
                ),
                elevation: 0,
              ),
              onPressed: () {
                ref.read(creatorWalletProvider.notifier).topUpCoins(500);
                ref.read(notificationsProvider.notifier).addNotification(
                  NotificationEntity(
                    id: 'notif_plan_${DateTime.now().millisecondsSinceEpoch}',
                    title: '${tier.name} Plan Activated!',
                    message: 'Your ${tier.name} subscription is active with full commercial ownership.',
                    category: NotificationCategory.system,
                    priority: NotificationPriority.high,
                    createdAt: DateTime.now(),
                  ),
                );
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Activated ${tier.name} plan! Credited 500 Coins.'),
                    backgroundColor: AppColors.brandPrimary,
                  ),
                );
              },
              child: Text(
                tier.ctaLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
