import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/models/published_clip.dart';
import '../providers/creator_wallet_provider.dart';
import '../../../profile/presentation/providers/profile_providers.dart';

/// TikTok-style cultural micro-gifting sheet for supporting a creator
/// (REQ-GFT-01 / REQ-GFT-02 / Phase 30 REQ-PROF-TIP-01). Sends African cultural gifts via the coin wallet.
class CreatorTippingSheet extends ConsumerStatefulWidget {
  final PublishedClip? clip;
  final String? creatorId;
  final String? creatorDisplayName;
  final String? creatorUsername;
  final String? creatorAvatarUrl;

  const CreatorTippingSheet({
    super.key,
    this.clip,
    this.creatorId,
    this.creatorDisplayName,
    this.creatorUsername,
    this.creatorAvatarUrl,
  });

  static Future<void> show(
    BuildContext context, {
    PublishedClip? clip,
    String? creatorId,
    String? creatorName,
    String? creatorUsername,
    String? creatorAvatarUrl,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreatorTippingSheet(
        clip: clip,
        creatorId: creatorId ?? clip?.creatorId,
        creatorDisplayName: creatorName ?? clip?.creatorDisplayName,
        creatorUsername: creatorUsername ?? clip?.creatorUsername,
        creatorAvatarUrl: creatorAvatarUrl ?? clip?.creatorAvatarUrl,
      ),
    );
  }

  @override
  ConsumerState<CreatorTippingSheet> createState() =>
      _CreatorTippingSheetState();
}

class _CreatorTippingSheetState extends ConsumerState<CreatorTippingSheet> {
  CulturalGift _selected = kCulturalGifts.first;
  final TextEditingController _messageController = TextEditingController();

  String get _effectiveCreatorId =>
      widget.creatorId ?? widget.clip?.creatorId ?? '';

  String get _effectiveUsername =>
      widget.creatorUsername ?? widget.clip?.creatorUsername ?? 'artist';

  String get _effectiveClipId =>
      widget.clip?.id ?? 'profile_$_effectiveCreatorId';

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

    if (ref.read(creatorWalletProvider).userCoinsBalance <
        _selected.coinPrice) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Not enough coins — top up to send this gift.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final owner = ref.read(ownerProfileProvider);
    final ok = await wallet.sendGift(
      clipId: _effectiveClipId,
      recipientCreatorId: _effectiveCreatorId,
      senderUsername: owner.username.isNotEmpty ? owner.username : 'ndugelo_musician',
      senderDisplayName: owner.displayName.isNotEmpty ? owner.displayName : 'Ndugelo Musician',
      gift: _selected,
      message: _messageController.text.trim(),
    );
    final splits = widget.clip?.coCreationSplits;
    if (splits != null && splits.isNotEmpty) {
      await wallet.distributeTrackTip(
        trackId: widget.clip?.trackId ?? _effectiveClipId,
        trackTitle: widget.clip?.title ?? 'Remix Track',
        creatorId: _effectiveCreatorId,
        creatorName: widget.clip?.creatorDisplayName ?? _effectiveUsername,
        credits: _selected.coinPrice,
        coCreationSplits: splits,
      );
    }

    if (!ok || !mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Sent ${_selected.emoji} ${_selected.name} to @$_effectiveUsername!',
        ),
        backgroundColor: AppColors.brandPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(creatorWalletProvider);

    return Container(
      decoration: BoxDecoration(
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
                child: Text(
                  'Support @$_effectiveUsername',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                key: const Key('tip_coin_balance'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PhosphorIcon(AppIcons.coin, size: 14, color: AppColors.coinGold),
                    const SizedBox(width: 5),
                    Text(
                      '${state.userCoinsBalance}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.coinGold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.clip?.coCreationSplits.isNotEmpty == true) ...[
            Container(
              key: const Key('co_creation_split_pill'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withValues(alpha: 0.12),
                borderRadius: AppRadius.pillBorder,
                border: Border.all(
                  color: AppColors.brandPrimary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PhosphorIcon(
                    PhosphorIconsRegular.gitFork,
                    size: 14,
                    color: AppColors.brandPrimary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.clip!.coCreationSplits
                        .map((s) => '${s.sharePercent.toStringAsFixed(0)}% ${s.handle ?? s.name}')
                        .join(' · '),
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.brandPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
              hintStyle: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
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
                borderRadius: AppRadius.inputBorder,
              ),
            ),
            child: Text(
              'Send ${_selected.name} (${_selected.coinPrice} 🪙)',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.brandContrast,
                fontWeight: FontWeight.bold,
              ),
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
  const _GiftCard({
    required this.gift,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('gift_${gift.id}'),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.surfaceSecondary
              : AppColors.surfaceElevated,
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
            Text(
              gift.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              '${gift.coinPrice} 🪙 (R${gift.zarPrice.toStringAsFixed(0)})',
              style: AppTypography.caption.copyWith(color: AppColors.coinGold),
            ),
            const SizedBox(height: 2),
            Flexible(
              child: Text(
                gift.culturalMeaning,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 9,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
