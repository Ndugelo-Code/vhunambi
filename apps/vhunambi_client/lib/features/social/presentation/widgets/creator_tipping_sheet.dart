import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/cultural_gift.dart';
import '../../domain/models/published_clip.dart';
import '../providers/creator_wallet_provider.dart';

/// TikTok-style cultural micro-gifting sheet for supporting a creator
/// (REQ-GFT-01 / REQ-GFT-02). Sends African cultural gifts via the coin wallet.
class CreatorTippingSheet extends ConsumerStatefulWidget {
  final PublishedClip clip;
  const CreatorTippingSheet({super.key, required this.clip});

  static Future<void> show(
    BuildContext context, {
    required PublishedClip clip,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreatorTippingSheet(clip: clip),
    );
  }

  @override
  ConsumerState<CreatorTippingSheet> createState() =>
      _CreatorTippingSheetState();
}

class _CreatorTippingSheetState extends ConsumerState<CreatorTippingSheet> {
  CulturalGift _selected = kCulturalGifts.first;
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    HapticFeedback.mediumImpact();
    final wallet = ref.read(creatorWalletProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final clip = widget.clip;

    if (ref.read(creatorWalletProvider).userCoinsBalance < _selected.coinPrice) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Not enough coins — top up to send this gift.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final ok = await wallet.sendGift(
      clipId: clip.id,
      recipientCreatorId: clip.creatorId,
      senderUsername: 'ndugelo_musician',
      senderDisplayName: 'Ndugelo Musician',
      gift: _selected,
      message: _messageController.text.trim(),
    );

    if (!ok || !mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
            'Sent ${_selected.emoji} ${_selected.name} to @${clip.creatorUsername}!'),
        backgroundColor: AppColors.brandPrimary,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final state = ref.watch(creatorWalletProvider);
    final clip = widget.clip;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceModal,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.sm,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text('Support @${clip.creatorUsername}',
                    style: AppTypography.titleMedium
                        .copyWith(fontWeight: FontWeight.bold)),
              ),
              Container(
                key: const Key('tip_coin_balance'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Text('🪙 ${state.userCoinsBalance}',
                    style: AppTypography.bodySmall.copyWith(
                        color: AppColors.coinGold,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: kCulturalGifts.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.25,
            ),
            itemBuilder: (context, i) {
              final gift = kCulturalGifts[i];
              return _GiftCard(
                gift: gift,
                isActive: gift.id == _selected.id,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selected = gift);
                },
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _messageController,
            style: AppTypography.bodySmall,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Leave an encouraging praise note...',
              hintStyle:
                  AppTypography.caption.copyWith(color: AppColors.textTertiary),
              filled: true,
              fillColor: AppColors.surfaceSecondary,
              border: const OutlineInputBorder(
                borderRadius: AppRadius.inputBorder,
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(
            key: const Key('tip_send_btn'),
            onPressed: _send,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPrimary,
              minimumSize: const Size.fromHeight(50),
              shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.inputBorder),
            ),
            child: Text(
              'Send ${_selected.name} (${_selected.coinPrice} 🪙)',
              style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.brandContrast, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _GiftCard extends StatelessWidget {
  final CulturalGift gift;
  final bool isActive;
  final VoidCallback onTap;
  const _GiftCard(
      {required this.gift, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('gift_${gift.id}'),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.surfaceSecondary : AppColors.surfaceElevated,
          borderRadius: AppRadius.inputBorder,
          border: Border.all(
            color: isActive ? AppColors.coinGold : AppColors.borderSubtle,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(gift.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 4),
            Text(gift.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                    color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('${gift.coinPrice} 🪙 (R${gift.zarPrice.toStringAsFixed(0)})',
                style: AppTypography.caption.copyWith(color: AppColors.coinGold)),
            const SizedBox(height: 2),
            Flexible(
              child: Text(gift.culturalMeaning,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textTertiary, fontSize: 9)),
            ),
          ],
        ),
      ),
    );
  }
}
