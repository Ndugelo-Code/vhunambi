import '../../../onboarding/presentation/views/onboarding_view.dart';
import '../../../../core/sync/edge_sync_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/design_system/tokens/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_provider.dart';

/// Settings drawer providing appearance / theme mode controls and system preferences.
class ProfileSettingsDrawer extends ConsumerWidget {
  const ProfileSettingsDrawer({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceModal,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.modalBorder,
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      builder: (_) => const ProfileSettingsDrawer(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeThemeMode = ref.watch(themeModeProvider);
    final syncState = ref.watch(edgeSyncCoordinatorProvider);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const PhosphorIcon(
                      PhosphorIconsRegular.gear,
                      color: AppColors.brandPrimary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Appearance & Preferences',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const PhosphorIcon(AppIcons.close, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Theme Mode Section Header
            Text(
              'APPLICATION THEME',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),

            // 3-Way Segmented Theme Controller [ System | Light | Dark ]
            Container(
              height: 46,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: AppRadius.pillBorder,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  _buildThemeOption(
                    context: context,
                    ref: ref,
                    label: 'System',
                    icon: PhosphorIconsRegular.deviceMobile,
                    mode: ThemeMode.system,
                    key: const Key('theme_mode_system'),
                    isSelected: activeThemeMode == ThemeMode.system,
                  ),
                  _buildThemeOption(
                    context: context,
                    ref: ref,
                    label: 'Light',
                    icon: PhosphorIconsRegular.sun,
                    mode: ThemeMode.light,
                    key: const Key('theme_mode_light'),
                    isSelected: activeThemeMode == ThemeMode.light,
                  ),
                  _buildThemeOption(
                    context: context,
                    ref: ref,
                    label: 'Dark',
                    icon: PhosphorIconsRegular.moon,
                    mode: ThemeMode.dark,
                    key: const Key('theme_mode_dark'),
                    isSelected: activeThemeMode == ThemeMode.dark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Audio Fidelity Preference
            Text(
              'AUDIO ENGINE SPECIFICATIONS',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: AppRadius.cardBorder,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.brandPrimary.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: const PhosphorIcon(
                      AppIcons.waveform,
                      color: AppColors.brandPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '44.1 kHz Studio Sampling Rate',
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Anti-glitch continuous phase accumulator active',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PhosphorIcon(
                    PhosphorIconsFill.checkCircle,
                    color: AppColors.success,
                    size: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Edge-Synced Mutation Outbox Durability Badge (REQ-P44-SYNC-06, REQ-P46-SYNC-07)
            Container(
              key: const Key('settings_edge_sync_card'),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: AppRadius.cardBorder,
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.badgeCyan.withAlpha(25),
                          shape: BoxShape.circle,
                        ),
                        child: const PhosphorIcon(
                          PhosphorIconsRegular.cloudCheck,
                          color: AppColors.badgeCyan,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edge-Synced • All creations backed up',
                              style: AppTypography.bodySmall.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Durable offline mutation outbox active (Hive WAL)',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PhosphorIcon(
                        PhosphorIconsFill.checkCircle,
                        color: AppColors.badgeCyan,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const Key('settings_sync_now_btn'),
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        final success = await ref
                            .read(edgeSyncCoordinatorProvider.notifier)
                            .syncNow();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? 'Edge-Sync complete! All mutations saved to SQLite WAL ⚡'
                                    : 'Offline sync pending • Queued for next connection',
                              ),
                              backgroundColor: success
                                  ? AppColors.brandPrimary
                                  : AppColors.surfaceSecondary,
                            ),
                          );
                        }
                      },
                      icon: const PhosphorIcon(
                        PhosphorIconsRegular.arrowsClockwise,
                        size: 14,
                        color: AppColors.badgeCyan,
                      ),
                      label: Text(
                        'Sync Now',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppColors.badgeCyan.withValues(alpha: 0.5),
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.pillBorder,
                        ),
                        minimumSize: const Size(0, 36),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Edge-Sync status row: dead-letter count + latency
            Row(
              children: [
                Container(
                  key: const Key('settings_dead_letter_count'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: syncState.deadLetterCount > 0
                        ? AppColors.surfaceSecondary
                        : AppColors.brandPrimary.withValues(alpha: 0.1),
                    borderRadius: AppRadius.pillBorder,
                    border: Border.all(
                      color: syncState.deadLetterCount > 0
                          ? AppColors.surfaceSecondary
                          : AppColors.brandPrimary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PhosphorIcon(
                        PhosphorIconsRegular.warning,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Dead-Letter: ${syncState.deadLetterCount}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  key: const Key('settings_sync_latency_ms'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: AppRadius.pillBorder,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PhosphorIcon(
                        PhosphorIconsRegular.clock,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Latency: ${syncState.lastSyncLatencyMs}ms',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondaryOf(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSubtleOf(context)),
              ),
              child: ListTile(
                key: const Key('settings_replay_onboarding_btn'),
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const PhosphorIcon(
                    PhosphorIconsRegular.sparkle,
                    color: AppColors.brandPrimary,
                    size: 18,
                  ),
                ),
                title: Text(
                  'Replay Interactive Onboarding',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                subtitle: Text(
                  'Experience the 4-act motion canvas & DNA genesis',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
                trailing: PhosphorIcon(
                  PhosphorIconsRegular.caretRight,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const OnboardingView()),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required WidgetRef ref,
    required String label,
    required IconData icon,
    required ThemeMode mode,
    required Key key,
    required bool isSelected,
  }) {
    return Expanded(
      child: InkWell(
        key: key,
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(themeModeProvider.notifier).setThemeMode(mode);
        },
        borderRadius: AppRadius.pillBorder,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.brandPrimary : Colors.transparent,
            borderRadius: AppRadius.pillBorder,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PhosphorIcon(
                icon,
                size: 16,
                color: isSelected
                    ? AppColors.brandContrast
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? AppColors.brandContrast
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
