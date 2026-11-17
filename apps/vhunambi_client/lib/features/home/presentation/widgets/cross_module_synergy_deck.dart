import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../sound_signature/presentation/widgets/sound_signature_idealizer_sheet.dart';
import '../../../studio/presentation/widgets/melody_sketchpad_modal.dart';
import '../../domain/models/studio_synergy_context.dart';
import '../providers/cross_module_synergy_provider.dart';

/// Cross-Module Diagnostic Gap -> Fix Deck (Phase 36 REQ-BANTU-SYN-04 & doc 05 §5).
///
/// Surfaces smart data-driven recommendation cards derived from real measured values
/// (pitch stability, room SNR, reverb decay, key confidence, grid timing).
///
/// Hides completely when no real measurements exist (no placeholder cards).
class CrossModuleSynergyDeck extends ConsumerWidget {
  const CrossModuleSynergyDeck({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(crossModuleSynergyProvider);

    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpacing.sm : AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: [
              PhosphorIcon(
                PhosphorIconsFill.sparkle,
                size: 16,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'STUDIO SYNERGY',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withAlpha(25),
                  borderRadius: AppRadius.pillBorder,
                ),
                child: Text(
                  '${cards.length} Actionable',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpacing.sm : AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          itemCount: cards.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final card = cards[index];
            return _SynergyCard(
              card: card,
              compact: compact,
              onDismiss: () => ref
                  .read(crossModuleSynergyProvider.notifier)
                  .dismissCard(card.id),
              onAction: () => _handleCardAction(context, card),
            );
          },
        ),
      ],
    );
  }

  void _handleCardAction(BuildContext context, SynergyCardItem card) {
    HapticFeedback.lightImpact();

    if (card.context.gapKind == SynergyGapKind.signatureUnusedInSketchpad) {
      MelodySketchpadModal.show(context);
      return;
    }

    final signature = card.context.signature;
    if (signature != null) {
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.surfaceModal,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.modalBorder,
          side: BorderSide(color: AppColors.borderSubtle),
        ),
        builder: (ctx) => FractionallySizedBox(
          heightFactor: 0.9,
          child: SoundSignatureIdealizerSheet(
            signature: signature,
            initialRecipe: card.context.suggestedRecipe,
          ),
        ),
      );
    }
  }
}

class _SynergyCard extends StatelessWidget {
  const _SynergyCard({
    required this.card,
    required this.compact,
    required this.onDismiss,
    required this.onAction,
  });

  final SynergyCardItem card;
  final bool compact;
  final VoidCallback onDismiss;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevatedOf(context),
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.borderSubtleOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xxs),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const PhosphorIcon(
                  PhosphorIconsRegular.magicWand,
                  size: 16,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  card.title,
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.textPrimaryOf(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondaryOf(context),
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(color: AppColors.borderSubtleOf(context)),
                ),
                child: Text(
                  card.metricSummary,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xxs),
              // Dismiss touch target >= 48x48dp (STD-UIUX-001)
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  key: Key('synergy_dismiss_${card.id}'),
                  tooltip: 'Dismiss suggestion',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  icon: PhosphorIcon(
                    PhosphorIconsRegular.x,
                    size: 16,
                    color: AppColors.textSecondaryOf(context),
                  ),
                  onPressed: onDismiss,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            card.subtitle,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                key: Key('synergy_action_${card.id}'),
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: AppColors.brandContrast,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.pillBorder,
                  ),
                ),
                icon: const PhosphorIcon(
                  PhosphorIconsBold.arrowRight,
                  size: 16,
                  color: AppColors.brandContrast,
                ),
                label: Text(
                  card.actionLabel,
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandContrast,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
