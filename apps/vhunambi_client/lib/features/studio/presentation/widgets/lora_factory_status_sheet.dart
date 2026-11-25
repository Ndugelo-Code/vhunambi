import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:vhunambi_client/core/theme/app_colors.dart';
import 'package:vhunambi_client/core/theme/app_dimensions.dart';
import 'package:vhunambi_client/core/theme/app_typography.dart';
import 'package:vhunambi_client/core/widgets/vhunambi_glass_surface.dart';
import 'package:vhunambi_client/features/studio/domain/models/studio_form_state.dart';
import 'package:vhunambi_client/features/studio/presentation/providers/studio_lora_registry_provider.dart';

/// Phase 85 Sovereign Cloud LoRA Factory Sheet (`EP-P85-LORA-FACTORY-UI`).
/// Strictly adheres to `STD-UIUX-001` (Phosphor icons only, zero raw emojis, `>= 44dp` touch targets).
class LoraFactoryStatusSheet extends ConsumerStatefulWidget {
  const LoraFactoryStatusSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.9,
        child: LoraFactoryStatusSheet(),
      ),
    );
  }

  @override
  ConsumerState<LoraFactoryStatusSheet> createState() =>
      _LoraFactoryStatusSheetState();
}

class _LoraFactoryStatusSheetState
    extends ConsumerState<LoraFactoryStatusSheet> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(studioLoraRegistryProvider.notifier).refreshFactory(),
    );
  }

  (String label, Color color) _statusBadge(
    AfricanLoraPackOption pack,
    Color mutedColor,
  ) {
    if (pack.isActive) return ('ACTIVE', AppColors.success);
    if (pack.isTraining) {
      return (pack.registryStatus.toUpperCase(), AppColors.badgeCyan);
    }
    if (pack.registryStatus == 'ready_to_train') {
      return ('CURATED READY', AppColors.coinGold);
    }
    if (pack.hasEnoughSourceTracks) {
      return ('READY TO PREP', AppColors.brandPrimary);
    }
    if (pack.registryStatus == 'failed') {
      return ('RETRY NEEDED', AppColors.error);
    }
    return ('NEEDS TRACKS', mutedColor);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studioLoraRegistryProvider);
    final notifier = ref.read(studioLoraRegistryProvider.notifier);
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    final isDesktop = MediaQuery.sizeOf(context).width >= 600;
    final packs = state.filteredPacks;

    return Container(
      key: const Key('lora_factory_status_sheet'),
      decoration: BoxDecoration(
        color: AppColors.surfaceModalOf(context),
        borderRadius: AppRadius.modalBorder,
        border: Border.all(color: AppColors.borderSubtleOf(context)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtleOf(context),
                  borderRadius: AppRadius.pillBorder,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: Row(
                children: [
                  IconButton(
                    key: const Key('lora_factory_close_btn'),
                    icon: PhosphorIcon(
                      PhosphorIconsRegular.x,
                      color: textPrimary,
                      size: 20,
                    ),
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sovereign Cloud LoRA Factory',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleMedium.copyWith(
                            color: textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${state.totalSourceTracks} Cloud R2 Tracks · RunPod L40S PEFT Pipeline',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('lora_factory_refresh_btn'),
                    icon: const PhosphorIcon(
                      PhosphorIconsBold.arrowsClockwise,
                      color: AppColors.brandPrimary,
                      size: 18,
                    ),
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    onPressed: state.isLoading ? null : () => notifier.refreshFactory(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
              child: Row(
                children: [
                  for (final item in const <(String, String)>[
                    ('all', 'All (11)'),
                    ('ready', 'Ready'),
                    ('active', 'Active'),
                  ]) ...[
                    if (item.$1 != 'all') const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        key: Key('lora_factory_filter_${item.$1}'),
                        borderRadius: AppRadius.pillBorder,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          notifier.setFilter(item.$1);
                        },
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: state.activeFilter == item.$1
                                ? AppColors.brandPrimary.withValues(alpha: 0.18)
                                : AppColors.surfaceSecondaryOf(context),
                            borderRadius: AppRadius.pillBorder,
                            border: Border.all(
                              color: state.activeFilter == item.$1
                                  ? AppColors.brandPrimary
                                  : AppColors.borderSubtleOf(context),
                            ),
                          ),
                          child: Text(
                            item.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: state.activeFilter == item.$1
                                  ? AppColors.brandPrimary
                                  : textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                child: Row(
                  children: [
                    const PhosphorIcon(
                      PhosphorIconsBold.warningCircle,
                      color: AppColors.error,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        state.errorMessage!,
                        style: AppTypography.caption.copyWith(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            if (state.noticeMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                child: Row(
                  children: [
                    const PhosphorIcon(
                      PhosphorIconsBold.checkCircle,
                      color: AppColors.success,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        state.noticeMessage!,
                        style: AppTypography.caption.copyWith(color: AppColors.success),
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(AppSpacing.md),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isDesktop ? 2 : 1,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                  mainAxisExtent: 158,
                ),
                itemCount: packs.length,
                itemBuilder: (context, index) {
                  final pack = packs[index];
                  final badge = _statusBadge(pack, textSecondary);
                  final progressRatio =
                      (pack.readyTrackCount / pack.recommendedTracks.clamp(1, 100))
                          .clamp(0.0, 1.0);
                  final isBusy = state.activeDispatchLoraId == pack.loraId;

                  return VhunambiGlassSurface(
                    key: Key('lora_factory_card_${pack.loraId}'),
                    variant: VhunambiGlassVariant.card,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                pack.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.titleSmall.copyWith(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: badge.$2.withValues(alpha: 0.16),
                                borderRadius: AppRadius.pillBorder,
                                border: Border.all(color: badge.$2),
                              ),
                              child: Text(
                                badge.$1,
                                style: AppTypography.badge.copyWith(
                                  color: badge.$2,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${pack.region} · ${pack.readyTrackCount}/${pack.minTracks} min R2 tracks · ${pack.curatedTrackCount} curated',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(color: textSecondary),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: AppRadius.pillBorder,
                          child: LinearProgressIndicator(
                            value: progressRatio,
                            minHeight: 6,
                            backgroundColor: AppColors.surfaceSecondaryOf(context),
                            color: badge.$2,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: OutlinedButton.icon(
                                  key: Key('lora_prep_btn_${pack.loraId}'),
                                  onPressed: (!pack.hasEnoughSourceTracks || isBusy)
                                      ? null
                                      : () => notifier.triggerDatasetPrep(pack.loraId),
                                  icon: const PhosphorIcon(
                                    PhosphorIconsBold.waveform,
                                    size: 14,
                                  ),
                                  label: Text(
                                    'Prep',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.caption.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: ElevatedButton.icon(
                                  key: Key('lora_train_btn_${pack.loraId}'),
                                  onPressed: (pack.curatedTrackCount < pack.minTracks || isBusy)
                                      ? null
                                      : () => notifier.triggerCloudTraining(pack.loraId),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.brandPrimary,
                                    foregroundColor: AppColors.brandContrast,
                                  ),
                                  icon: const PhosphorIcon(
                                    PhosphorIconsBold.cpu,
                                    size: 14,
                                  ),
                                  label: Text(
                                    'Train PEFT',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.brandContrast,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
