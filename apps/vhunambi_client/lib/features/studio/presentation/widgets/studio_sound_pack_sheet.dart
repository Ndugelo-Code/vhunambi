import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/sound_pack_manager_provider.dart';

/// In-App Sound Pack Expansion Manager Sheet (Phase 32 / STD-UIUX-001).
class StudioSoundPackSheet extends ConsumerWidget {
  const StudioSoundPackSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceModal,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.modalBorder,
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.85,
        child: StudioSoundPackSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(soundPackManagerProvider);
    final notifier = ref.read(soundPackManagerProvider.notifier);

    return SafeArea(
      key: const Key('studio_sound_pack_sheet'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary.withAlpha(25),
                    borderRadius: AppRadius.inputBorder,
                    border: Border.all(
                      color: AppColors.brandPrimary.withAlpha(90),
                    ),
                  ),
                  child: const Center(
                    child: PhosphorIcon(
                      PhosphorIconsRegular.package,
                      color: AppColors.brandPrimary,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sound Pack Expansion Store',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Native Core Kit bundled (0 MB) • Expansion packs cached locally',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('sound_pack_close_btn'),
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const PhosphorIcon(
                    PhosphorIconsRegular.x,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Packs List
            Expanded(
              child: ListView.separated(
                itemCount: state.packs.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final pack = state.packs[index];
                  final isDownloading = state.isDownloading(pack.id);
                  final progress = state.getProgress(pack.id);

                  return Container(
                    key: Key('sound_pack_card_${pack.id}'),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: AppRadius.cardBorder,
                      border: Border.all(
                        color: pack.isInstalled
                            ? AppColors.brandPrimary.withAlpha(60)
                            : AppColors.borderSubtle,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        pack.title,
                                        style: AppTypography.bodyMedium.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (pack.isBundledNative)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.coinGold.withAlpha(28),
                                            borderRadius: AppRadius.pillBorder,
                                            border: Border.all(
                                              color: AppColors.coinGold.withAlpha(80),
                                            ),
                                          ),
                                          child: Text(
                                            'Core Native',
                                            style: AppTypography.caption.copyWith(
                                              color: AppColors.coinGold,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    pack.subtitle,
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${pack.genre} • ${pack.sizeMb == 0 ? "0 MB (Bundled)" : "${pack.sizeMb.toStringAsFixed(1)} MB"}',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.brandPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Action Button
                            if (pack.isInstalled)
                              Container(
                                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                                alignment: Alignment.center,
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    PhosphorIcon(
                                      PhosphorIconsRegular.checkCircle,
                                      color: AppColors.success,
                                      size: 18,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Active',
                                      style: TextStyle(
                                        color: AppColors.success,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (isDownloading)
                              SizedBox(
                                width: 88,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    LinearProgressIndicator(
                                      value: progress,
                                      backgroundColor: AppColors.surfaceSecondary,
                                      color: AppColors.brandPrimary,
                                      minHeight: 4,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${(progress * 100).toInt()}%',
                                      style: AppTypography.caption.copyWith(
                                        fontSize: 10,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ElevatedButton.icon(
                                key: Key('sound_pack_download_${pack.id}'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.surfaceSecondary,
                                  foregroundColor: AppColors.brandPrimary,
                                  side: const BorderSide(color: AppColors.brandPrimary),
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: AppRadius.pillBorder,
                                  ),
                                  splashFactory: NoSplash.splashFactory,
                                  minimumSize: const Size(44, 44),
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                ),
                                onPressed: () => notifier.downloadSoundPack(pack.id),
                                icon: const PhosphorIcon(
                                  PhosphorIconsRegular.downloadSimple,
                                  size: 16,
                                ),
                                label: const Text('Get'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: pack.instrumentNames.map((inst) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSecondary,
                                borderRadius: AppRadius.pillBorder,
                              ),
                              child: Text(
                                inst,
                                style: AppTypography.caption.copyWith(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            );
                          }).toList(),
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

