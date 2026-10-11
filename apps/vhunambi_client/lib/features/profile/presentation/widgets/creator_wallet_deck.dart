import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../social/presentation/providers/creator_wallet_provider.dart';

/// Creator cultural wallet & micro-gifting dashboard (REQ-WAL-01 … REQ-WAL-03).
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

    final method = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceModal,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
        title: Text('Cash Out Royalties',
            style: AppTypography.titleMedium
                .copyWith(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Withdraw ${_formatZar(state.creatorEarnedZar)} via:',
                style: AppTypography.bodyMuted),
            const SizedBox(height: AppSpacing.sm),
            for (final m in ['Ozow', 'Capitec Pay', 'EFT'])
              ListTile(
                leading: const Icon(Icons.account_balance_rounded,
                    color: AppColors.brandPrimary),
                title: Text(m, style: AppTypography.bodyLarge),
                onTap: () => Navigator.of(ctx).pop(m),
              ),
          ],
        ),
      ),
    );

    if (method == null) return;
    final ok = await ref
        .read(creatorWalletProvider.notifier)
        .requestPayout(amountZar: state.creatorEarnedZar, payoutMethod: method);
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.read(creatorWalletProvider).payoutStatusMessage ??
              'Payout initiated!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(creatorWalletProvider);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded,
                  color: AppColors.coinGold, size: 20),
              const SizedBox(width: 8),
              Text('Creator Wallet',
                  style: AppTypography.titleMedium
                      .copyWith(fontWeight: FontWeight.bold)),
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
                Text('Lifetime Earnings',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.brandContrast)),
                Text(_formatZar(state.creatorEarnedZar),
                    style: AppTypography.displayMedium
                        .copyWith(color: AppColors.brandContrast)),
                const SizedBox(height: 4),
                Text(
                    '${_formatInt(state.creatorReceivedCoins)} 🪙 cultural coins received',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.brandContrast)),
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
                  borderRadius: AppRadius.inputBorder),
            ),
            icon: const Icon(Icons.payments_rounded,
                color: AppColors.brandContrast, size: 18),
            label: Text('Request Payout (Ozow / Capitec Pay / EFT)',
                style: AppTypography.bodySmall.copyWith(
                    color: AppColors.brandContrast,
                    fontWeight: FontWeight.bold)),
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

  String _medal(int rank) =>
      switch (rank) { 1 => '🥇', 2 => '🥈', 3 => '🥉', _ => '🎖️' };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Top Supporters',
            style: AppTypography.bodyLarge
                .copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSpacing.xs),
        if (supporters.isEmpty)
          Text('No supporters yet.', style: AppTypography.bodyMuted)
        else
          for (final s in supporters)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: AppRadius.inputBorder,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Text(_medal(s.rank), style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('@${s.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textPrimary)),
                  ),
                  Text('${s.topGiftEmoji} ${s.totalCoins} 🪙',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.coinGold)),
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
        Text('Recent Gifts',
            style: AppTypography.bodyLarge
                .copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSpacing.xs),
        if (transactions.isEmpty)
          Text('No gifts received yet.', style: AppTypography.bodyMuted)
        else
          for (final tx in transactions)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: AppRadius.inputBorder,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Text(tx.gift.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('@${tx.senderUsername} sent ${tx.gift.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall
                                .copyWith(color: AppColors.textPrimary)),
                        if (tx.message != null && tx.message!.isNotEmpty)
                          Text('"${tx.message}"',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.textSecondary)),
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
