import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/vhunambi_glass_surface.dart';
import '../../../home/presentation/providers/creator_allowance_provider.dart';
import '../../../home/presentation/widgets/subscription_upgrade_modal.dart';
import '../../../social/presentation/providers/creator_wallet_provider.dart';
import 'payout_details_sheet.dart';

/// Creator cultural wallet & micro-gifting dashboard (REQ-WAL-01 … REQ-WAL-03, REQ-P72-OP-07).
class CreatorWalletDeck extends ConsumerWidget {
  const CreatorWalletDeck({super.key});

  String _formatZar(double amount) {
    final cents = amount.toStringAsFixed(2).split('.');
    final whole = cents[0].replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'),
          (m) => '${m[1]},',
        );
    return 'R$whole.${cents[1]}';
  }

  String _formatInt(int amount) {
    return amount.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'),
          (m) => '${m[1]},',
        );
  }

  Future<void> _openPayout(BuildContext context, WidgetRef ref) async {
    final state = ref.read(creatorWalletProvider);
    if (state.creatorEarnedZar < 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimum payout is R50. Keep creating to earn more!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    await PayoutDetailsSheet.show(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(creatorWalletProvider);
    final allowance = ref.watch(creatorAllowanceProvider);
    final quotaProgress = allowance.isPaidUnlimited ||
            allowance.freeMonthlySongsLimit <= 0
        ? 1.0
        : (allowance.freeMonthlySongsRemaining /
                allowance.freeMonthlySongsLimit)
            .clamp(0.0, 1.0);

    return VhunambiGlassSurface(
      variant: VhunambiGlassVariant.card,
      enableLiveBlur: false,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PhosphorIcon(
                PhosphorIconsFill.wallet,
                color: AppColors.coinGold,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Creator Wallet',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.textPrimaryOf(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.coinGold,
                  AppColors.brandPrimary,
                  AppColors.streakFire,
                ],
              ),
              borderRadius: AppRadius.inputBorder,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lifetime Earnings',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.brandContrast,
                  ),
                ),
                Text(
                  _formatZar(state.creatorEarnedZar),
                  style: AppTypography.displayMedium.copyWith(
                    color: AppColors.brandContrast,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const PhosphorIcon(
                      PhosphorIconsFill.coins,
                      size: 14,
                      color: AppColors.brandContrast,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${_formatInt(state.creatorReceivedCoins)} cultural coins received',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.brandContrast,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            key: const Key('wallet_monthly_allowance_card'),
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceSecondaryOf(context),
              borderRadius: AppRadius.inputBorder,
              border: Border.all(
                color: allowance.isLowQuota
                    ? AppColors.brandPrimary
                    : AppColors.borderSubtleOf(context),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const PhosphorIcon(
                      PhosphorIconsFill.musicNotes,
                      size: 16,
                      color: AppColors.brandPrimary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        allowance.isPaidUnlimited
                            ? 'Studio Unlimited Plan'
                            : 'Monthly Free Songs (${allowance.freeMonthlySongsRemaining}/${allowance.freeMonthlySongsLimit} left)',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => SubscriptionUpgradeModal.show(context),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: Text(
                        allowance.isPaidUnlimited ? 'Manage' : 'Upgrade',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.brandPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: AppRadius.pillBorder,
                  child: LinearProgressIndicator(
                    value: quotaProgress,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceElevatedOf(context),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.brandPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ElevatedButton.icon(
            key: const Key('wallet_payout_btn'),
            onPressed: () => _openPayout(context, ref),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              minimumSize: const Size.fromHeight(46),
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.inputBorder,
              ),
            ),
            icon: const PhosphorIcon(
              PhosphorIconsRegular.creditCard,
              color: AppColors.brandContrast,
              size: 18,
            ),
            label: Text(
              'Request Payout (Ozow / Capitec Pay / EFT)',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.brandContrast,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SupportersSection(supporters: state.topSupporters.take(4).toList()),
          const SizedBox(height: AppSpacing.md),
          _RecentGifts(transactions: state.transactions.take(4).toList()),
        ],
      ),
    );
  }
}

class _SupportersSection extends StatelessWidget {
  final List<SupporterRank> supporters;
  const _SupportersSection({required this.supporters});

  Color _medalColor(int rank) => switch (rank) {
    1 => AppColors.coinGold,
    2 => const Color(0xFFC0C6D0),
    3 => const Color(0xFFCD7F32),
    _ => AppColors.brandPrimary,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Supporters',
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.textPrimaryOf(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (supporters.isEmpty)
          Text(
            'No supporters yet.',
            style: AppTypography.bodyMuted.copyWith(
              color: AppColors.textSecondaryOf(context),
            ),
          )
        else
          for (final s in supporters)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondaryOf(context),
                borderRadius: AppRadius.inputBorder,
                border: Border.all(color: AppColors.borderSubtleOf(context)),
              ),
              child: Row(
                children: [
                  PhosphorIcon(
                    s.rank <= 3
                        ? PhosphorIconsFill.trophy
                        : PhosphorIconsFill.medal,
                    size: 18,
                    color: _medalColor(s.rank),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '#${s.rank}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondaryOf(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '@${s.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PhosphorIcon(
                        PhosphorIconsFill.coins,
                        size: 13,
                        color: AppColors.coinGold,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${s.totalCoins} coins',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.coinGold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _RecentGifts extends StatelessWidget {
  final List<GiftTransaction> transactions;
  const _RecentGifts({required this.transactions});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Gifts',
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.textPrimaryOf(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (transactions.isEmpty)
          Text(
            'No gifts received yet.',
            style: AppTypography.bodyMuted.copyWith(
              color: AppColors.textSecondaryOf(context),
            ),
          )
        else
          for (final tx in transactions)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondaryOf(context),
                borderRadius: AppRadius.inputBorder,
                border: Border.all(color: AppColors.borderSubtleOf(context)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.coinGold.withAlpha(24),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: PhosphorIcon(
                        PhosphorIconsFill.gift,
                        size: 15,
                        color: AppColors.coinGold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '@${tx.senderUsername} sent ${tx.gift.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textPrimaryOf(context),
                          ),
                        ),
                        if (tx.message != null && tx.message!.isNotEmpty)
                          Text(
                            '"${tx.message}"',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondaryOf(context),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
